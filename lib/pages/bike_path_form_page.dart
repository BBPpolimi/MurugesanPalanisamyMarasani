import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';

import '../models/bike_path.dart';
import '../models/street_segment.dart';
import '../models/path_obstacle.dart';
import '../models/path_tag.dart';
import '../models/path_quality_report.dart';
import '../services/providers.dart';
import '../services/geocoding_service.dart';

class BikePathFormPage extends ConsumerStatefulWidget {
  final BikePath? existingPath; // For editing

  const BikePathFormPage({super.key, this.existingPath});

  @override
  ConsumerState<BikePathFormPage> createState() => _BikePathFormPageState();
}

class _BikePathFormPageState extends ConsumerState<BikePathFormPage> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Step 1: Basic Info
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  PathVisibility _visibility = PathVisibility.private;

  // Step 2: Streets
  final List<StreetSegment> _segments = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // Step 3: Status & Tags
  PathRateStatus _status = PathRateStatus.optimal;
  final Set<PathTag> _selectedTags = {};

  // Step 4: Obstacles
  final List<PathObstacle> _obstacles = [];

  // Step 5: Map Preview
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  double _totalPathDistance = 0.0;

  bool get _isEditing => widget.existingPath != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingPath != null) {
      _loadExistingPath(widget.existingPath!);
    }
  }

  void _loadExistingPath(BikePath path) {
    _titleController.text = path.name ?? '';
    _cityController.text = path.city ?? '';
    _visibility = path.visibility;
    _segments.addAll(path.segments);
    _status = path.status;
    _selectedTags.addAll(path.tags);
    _obstacles.addAll(path.obstacles);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _cityController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Validation for each step
  bool _canContinue(int step) {
    switch (step) {
      case 0: // Basic info - always valid (optional fields)
        return true;
      case 1: // Streets - need at least 2
        return _segments.length >= 2;
      case 2: // Status & tags - status is required (always has default)
        return true;
      case 3: // Obstacles - optional
        return true;
      case 4: // Preview - ready to submit
        return _segments.length >= 2;
      default:
        return false;
    }
  }

  String? _getStepError(int step) {
    switch (step) {
      case 1:
        if (_segments.length < 2) {
          return 'Add at least 2 street segments to define your path';
        }
        break;
    }
    return null;
  }

  void _onStepContinue() {
    if (!_canContinue(_currentStep)) {
      final error = _getStepError(_currentStep);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    if (_currentStep < 4) {
      setState(() => _currentStep++);
      if (_currentStep == 4) {
        _recalculateFullRoute();
      }
    } else {
      _submit();
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _onStepTapped(int step) {
    // Allow going back, but validate before going forward
    if (step < _currentStep) {
      setState(() => _currentStep = step);
    } else if (step > _currentStep) {
      // Validate all steps up to the target
      for (int i = _currentStep; i < step; i++) {
        if (!_canContinue(i)) {
          final error = _getStepError(i);
          if (error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error), backgroundColor: Colors.orange),
            );
          }
          return;
        }
      }
      setState(() => _currentStep = step);
    }
  }

  // --- Street Management ---
  void _addSegment(GeocodingResult result) {
    final newSegment = StreetSegment(
      id: const Uuid().v4(),
      streetName: result.formattedAddress.split(',')[0],
      formattedAddress: result.formattedAddress,
      lat: result.location.latitude,
      lng: result.location.longitude,
      order: _segments.length,
      polyline: result.viewport != null
          ? [result.viewport!.southwest, result.viewport!.northeast]
          : null,
    );

    setState(() {
      _segments.add(newSegment);
    });

    _searchController.clear();
  }

  Future<void> _handleSearch(String query) async {
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    
    final result = await ref.read(geocodingServiceProvider).searchAddress(query);
    
    setState(() => _isSearching = false);

    if (result != null) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(result.formattedAddress),
          content: const Text('Add this street to the path?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _addSegment(result);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address not found')),
        );
      }
    }
  }

  // --- Obstacle Management ---
  void _showAddObstacleDialog() {
    PathObstacleType selectedType = PathObstacleType.pothole;
    int severity = 3;
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Obstacle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<PathObstacleType>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: PathObstacleType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedType = v!),
                ),
                const SizedBox(height: 16),
                Text('Severity: $severity'),
                Slider(
                  value: severity.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: severity.toString(),
                  onChanged: (v) => setDialogState(() => severity = v.round()),
                ),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'Additional details...',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final obstacle = PathObstacle(
                  id: const Uuid().v4(),
                  type: selectedType,
                  severity: severity,
                  note: noteController.text.isNotEmpty ? noteController.text : null,
                  createdAt: DateTime.now(),
                );
                setState(() => _obstacles.add(obstacle));
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Map Visualization ---
  Future<void> _recalculateFullRoute() async {
    _markers = {};
    for (int i = 0; i < _segments.length; i++) {
      final seg = _segments[i];
      _markers.add(Marker(
        markerId: MarkerId('seg_$i'),
        position: LatLng(seg.lat, seg.lng),
        infoWindow: InfoWindow(title: '${i + 1}. ${seg.streetName}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }
    setState(() {});

    if (_segments.length < 2) {
      _polylines = {};
      if (_segments.isNotEmpty && _mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(
            LatLng(_segments.first.lat, _segments.first.lng), 14));
      }
      setState(() {});
      return;
    }

    List<LatLng> fullRoutePoints = [];
    double calculatedDistance = 0.0;
    final directionsService = ref.read(directionsServiceProvider);

    for (int i = 0; i < _segments.length - 1; i++) {
      final start = _segments[i];
      final end = _segments[i + 1];

      try {
        var directions = await directionsService.getDirections(
          origin: LatLng(start.lat, start.lng),
          destination: LatLng(end.lat, end.lng),
          mode: 'bicycling',
        );

        if (directions == null) {
          directions = await directionsService.getDirections(
            origin: LatLng(start.lat, start.lng),
            destination: LatLng(end.lat, end.lng),
            mode: 'driving',
          );
        }

        if (directions != null) {
          fullRoutePoints.addAll(directions.polylinePoints);
          calculatedDistance += directions.distanceValue;
        } else {
          fullRoutePoints.add(LatLng(start.lat, start.lng));
          fullRoutePoints.add(LatLng(end.lat, end.lng));
          calculatedDistance += Geolocator.distanceBetween(
              start.lat, start.lng, end.lat, end.lng);
        }
      } catch (e) {
        fullRoutePoints.add(LatLng(start.lat, start.lng));
        fullRoutePoints.add(LatLng(end.lat, end.lng));
        calculatedDistance +=
            Geolocator.distanceBetween(start.lat, start.lng, end.lat, end.lng);
      }
    }

    if (mounted) {
      setState(() {
        _totalPathDistance = calculatedDistance;
        _polylines = {
          Polyline(
            polylineId: const PolylineId('full_bike_path'),
            points: fullRoutePoints,
            color: Colors.blueAccent,
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          )
        };
      });

      if (_mapController != null && fullRoutePoints.isNotEmpty) {
        double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
        for (var p in fullRoutePoints) {
          if (p.latitude < minLat) minLat = p.latitude;
          if (p.latitude > maxLat) maxLat = p.latitude;
          if (p.longitude < minLng) minLng = p.longitude;
          if (p.longitude > maxLng) maxLng = p.longitude;
        }
        _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
            LatLngBounds(
                southwest: LatLng(minLat, minLng),
                northeast: LatLng(maxLat, maxLng)),
            100));
      }
    }
  }

  // --- Submit ---
  void _submit() async {
    if (_segments.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 2 street segments.')),
      );
      return;
    }

    final user = ref.read(authStateProvider).value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Must be logged in.')),
      );
      return;
    }

    final now = DateTime.now();
    final path = BikePath(
      id: widget.existingPath?.id ?? const Uuid().v4(),
      userId: user.uid,
      name: _titleController.text.isNotEmpty ? _titleController.text : null,
      segments: _segments.asMap().entries.map((e) => 
        e.value.copyWith(order: e.key)
      ).toList(),
      status: _status,
      visibility: _visibility,
      obstacles: _obstacles,
      tags: _selectedTags.toList(),
      city: _cityController.text.isNotEmpty ? _cityController.text : null,
      version: (widget.existingPath?.version ?? 0) + 1,
      distanceMeters: _totalPathDistance,
      createdAt: widget.existingPath?.createdAt ?? now,
      updatedAt: now,
      publishedAt: _visibility == PathVisibility.published ? now : null,
    );

    try {
      if (_isEditing) {
        await ref.read(contributeServiceProvider).updateBikePath(path);
      } else {
        await ref.read(contributeServiceProvider).addBikePath(path);
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing 
              ? 'Bike Path Updated!' 
              : 'Bike Path Created Successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Bike Path' : 'Create Bike Path'),
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          type: StepperType.vertical,
          currentStep: _currentStep,
          onStepContinue: _onStepContinue,
          onStepCancel: _onStepCancel,
          onStepTapped: _onStepTapped,
          controlsBuilder: (context, details) {
            final isLastStep = _currentStep == 4;
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _canContinue(_currentStep) 
                      ? details.onStepContinue 
                      : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLastStep ? Colors.green : null,
                    ),
                    child: Text(isLastStep ? 'Submit' : 'Continue'),
                  ),
                  const SizedBox(width: 12),
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('Back'),
                    ),
                ],
              ),
            );
          },
          steps: [
            // Step 1: Basic Info
            Step(
              title: const Text('Basic Info'),
              subtitle: _titleController.text.isNotEmpty 
                ? Text(_titleController.text) 
                : null,
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: _buildBasicInfoStep(),
            ),
            // Step 2: Streets
            Step(
              title: const Text('Streets'),
              subtitle: Text('${_segments.length} segments'),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 
                ? StepState.complete 
                : (_segments.length < 2 ? StepState.error : StepState.indexed),
              content: _buildStreetsStep(),
            ),
            // Step 3: Status & Tags
            Step(
              title: const Text('Status & Tags'),
              subtitle: Text(_status.label),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
              content: _buildStatusTagsStep(),
            ),
            // Step 4: Obstacles
            Step(
              title: const Text('Obstacles'),
              subtitle: Text('${_obstacles.length} reported'),
              isActive: _currentStep >= 3,
              state: _currentStep > 3 ? StepState.complete : StepState.indexed,
              content: _buildObstaclesStep(),
            ),
            // Step 5: Preview & Submit
            Step(
              title: const Text('Preview & Submit'),
              subtitle: Text(
                '${(_totalPathDistance / 1000).toStringAsFixed(2)} km • ${_visibility == PathVisibility.published ? 'Public' : 'Private'}',
              ),
              isActive: _currentStep >= 4,
              state: StepState.indexed,
              content: _buildPreviewStep(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Path Name (optional)',
            hintText: 'e.g., Downtown Loop',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _cityController,
          decoration: const InputDecoration(
            labelText: 'City/Area (optional)',
            hintText: 'e.g., Milan',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Make Public'),
          subtitle: Text(_visibility == PathVisibility.published 
            ? 'Visible to everyone' 
            : 'Only you can see this'),
          value: _visibility == PathVisibility.published,
          onChanged: (v) => setState(() {
            _visibility = v ? PathVisibility.published : PathVisibility.private;
          }),
        ),
      ],
    );
  }

  Widget _buildStreetsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_segments.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Add at least 2 street segments to define your path.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        if (_segments.length == 1)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Add 1 more street to continue'),
                ),
              ],
            ),
          ),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (oldIndex < newIndex) newIndex -= 1;
              final item = _segments.removeAt(oldIndex);
              _segments.insert(newIndex, item);
            });
          },
          children: [
            for (int i = 0; i < _segments.length; i++)
              ListTile(
                key: ValueKey(_segments[i].id),
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: Text('${i + 1}'),
                ),
                title: Text(_segments[i].streetName),
                subtitle: Text(
                  _segments[i].formattedAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() => _segments.removeAt(i));
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search street...',
                  border: const OutlineInputBorder(),
                  suffixIcon: _isSearching 
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => _handleSearch(_searchController.text),
                      ),
                ),
                onSubmitted: _handleSearch,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusTagsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<PathRateStatus>(
          value: _status,
          decoration: const InputDecoration(
            labelText: 'Overall Path Status',
            border: OutlineInputBorder(),
          ),
          items: PathRateStatus.values
              .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
              .toList(),
          onChanged: (v) => setState(() => _status = v!),
        ),
        const SizedBox(height: 24),
        const Text(
          'Tags',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PathTag.values.map((tag) {
            final isSelected = _selectedTags.contains(tag);
            return FilterChip(
              label: Text(tag.label),
              avatar: Icon(tag.icon, size: 18),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedTags.add(tag);
                  } else {
                    _selectedTags.remove(tag);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildObstaclesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Report any obstacles along your path (optional)',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        if (_obstacles.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No obstacles reported',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _obstacles.length,
            itemBuilder: (context, index) {
              final obs = _obstacles[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getSeverityColor(obs.severity),
                    child: Text('${obs.severity}'),
                  ),
                  title: Text(obs.type.label),
                  subtitle: obs.note != null ? Text(obs.note!) : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      setState(() => _obstacles.removeAt(index));
                    },
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _showAddObstacleDialog,
          icon: const Icon(Icons.add),
          label: const Text('Add Obstacle'),
        ),
      ],
    );
  }

  Color _getSeverityColor(int severity) {
    switch (severity) {
      case 1:
        return Colors.green.shade200;
      case 2:
        return Colors.lime.shade200;
      case 3:
        return Colors.yellow.shade300;
      case 4:
        return Colors.orange.shade300;
      case 5:
        return Colors.red.shade300;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPreviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleController.text.isNotEmpty 
                    ? _titleController.text 
                    : 'Untitled Path',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Chip(
                      label: Text(_status.label),
                      backgroundColor: Colors.blue.shade50,
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(_visibility == PathVisibility.published 
                        ? 'Public' 
                        : 'Private'),
                      backgroundColor: _visibility == PathVisibility.published 
                        ? Colors.green.shade50 
                        : Colors.grey.shade200,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${_segments.length} segments • ${(_totalPathDistance / 1000).toStringAsFixed(2)} km'),
                if (_obstacles.isNotEmpty)
                  Text('${_obstacles.length} obstacle(s) reported'),
                if (_selectedTags.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    children: _selectedTags.map((t) => 
                      Chip(
                        label: Text(t.label, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                      )
                    ).toList(),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Map Preview
        SizedBox(
          height: 300,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _segments.isNotEmpty 
                  ? LatLng(_segments.first.lat, _segments.first.lng)
                  : const LatLng(37.7749, -122.4194),
                zoom: 12,
              ),
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (c) {
                _mapController = c;
                if (_segments.length >= 2) {
                  _recalculateFullRoute();
                }
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),
        ),
      ],
    );
  }
}
