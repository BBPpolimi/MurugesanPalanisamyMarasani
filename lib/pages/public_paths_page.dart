import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/bike_path.dart';
import '../models/path_quality_report.dart';
import '../services/providers.dart';
import 'contribution_details_page.dart';

/// Filter options for public path browsing
enum PathStatusFilter {
  all('All Statuses'),
  optimal('Optimal'),
  medium('Medium'),
  sufficient('Sufficient'),
  requiresMaintenance('Requires Maintenance');

  final String label;
  const PathStatusFilter(this.label);
}

/// Public browsing page for viewing community-shared bike paths
/// Accessible by all users (including anonymous/guest users)
class PublicPathsPage extends ConsumerStatefulWidget {
  const PublicPathsPage({super.key});

  @override
  ConsumerState<PublicPathsPage> createState() => _PublicPathsPageState();
}

class _PublicPathsPageState extends ConsumerState<PublicPathsPage> {
  PathStatusFilter _statusFilter = PathStatusFilter.all;
  String _cityFilter = '';
  final TextEditingController _citySearchController = TextEditingController();
  bool _showMapView = false;
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _citySearchController.dispose();
    super.dispose();
  }

  List<BikePath> _applyFilters(List<BikePath> paths) {
    return paths.where((path) {
      // Status filter
      if (_statusFilter != PathStatusFilter.all) {
        final statusMatch = switch (_statusFilter) {
          PathStatusFilter.optimal => path.status == PathRateStatus.optimal,
          PathStatusFilter.medium => path.status == PathRateStatus.medium,
          PathStatusFilter.sufficient => path.status == PathRateStatus.sufficient,
          PathStatusFilter.requiresMaintenance => path.status == PathRateStatus.requiresMaintenance,
          PathStatusFilter.all => true,
        };
        if (!statusMatch) return false;
      }
      
      // City filter
      if (_cityFilter.isNotEmpty) {
        final cityMatch = path.city?.toLowerCase().contains(_cityFilter.toLowerCase()) ?? false;
        if (!cityMatch) return false;
      }
      
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final publicPathsAsync = ref.watch(publicBikePathsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Bike Paths'),
        actions: [
          IconButton(
            icon: Icon(_showMapView ? Icons.list : Icons.map),
            onPressed: () => setState(() => _showMapView = !_showMapView),
            tooltip: _showMapView ? 'Show List' : 'Show Map',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters section
          _buildFilterBar(),
          
          // Content
          Expanded(
            child: publicPathsAsync.when(
              data: (paths) {
                final filteredPaths = _applyFilters(paths);
                
                if (filteredPaths.isEmpty) {
                  return _buildEmptyState(paths.isEmpty);
                }
                
                return _showMapView 
                  ? _buildMapView(filteredPaths)
                  : _buildListView(filteredPaths);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading paths: $e'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(publicBikePathsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Status filter dropdown
              Expanded(
                child: DropdownButtonFormField<PathStatusFilter>(
                  value: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  items: PathStatusFilter.values
                      .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _statusFilter = v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              // City search
              Expanded(
                child: TextField(
                  controller: _citySearchController,
                  decoration: InputDecoration(
                    labelText: 'City',
                    hintText: 'Filter by city...',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                    suffixIcon: _cityFilter.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _citySearchController.clear();
                              setState(() => _cityFilter = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _cityFilter = v),
                ),
              ),
            ],
          ),
          if (_statusFilter != PathStatusFilter.all || _cityFilter.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  const Text('Active filters: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  if (_statusFilter != PathStatusFilter.all)
                    Chip(
                      label: Text(_statusFilter.label, style: const TextStyle(fontSize: 11)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => setState(() => _statusFilter = PathStatusFilter.all),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (_cityFilter.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Chip(
                      label: Text(_cityFilter, style: const TextStyle(fontSize: 11)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () {
                        _citySearchController.clear();
                        setState(() => _cityFilter = '');
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool noPathsAtAll) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            noPathsAtAll ? Icons.explore_off : Icons.filter_alt_off,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            noPathsAtAll 
              ? 'No public paths yet' 
              : 'No paths match your filters',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            noPathsAtAll
              ? 'Be the first to share a bike path with the community!'
              : 'Try adjusting your filters or clear them',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          if (!noPathsAtAll) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                _citySearchController.clear();
                setState(() {
                  _statusFilter = PathStatusFilter.all;
                  _cityFilter = '';
                });
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Filters'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListView(List<BikePath> paths) {
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(publicBikePathsProvider),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: paths.length,
        itemBuilder: (context, index) => _buildPathCard(paths[index]),
      ),
    );
  }

  Widget _buildPathCard(BikePath path) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContributionDetailsPage(path: path, isPublicView: true),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      path.name ?? 'Untitled Path',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _buildStatusChip(path.status),
                ],
              ),
              if (path.city != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      path.city!,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.route, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${path.segments.length} segments',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.straighten, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${(path.distanceMeters / 1000).toStringAsFixed(2)} km',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  if (path.obstacles.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.warning_amber, size: 16, color: Colors.orange.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${path.obstacles.length} obstacles',
                      style: TextStyle(color: Colors.orange.shade600),
                    ),
                  ],
                ],
              ),
              // Tags
              if (path.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: path.tags.take(4).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(tag.icon, size: 12, color: Colors.blue.shade700),
                          const SizedBox(width: 4),
                          Text(
                            tag.label,
                            style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Updated ${_formatDate(path.updatedAt)}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(PathRateStatus status) {
    Color color;
    switch (status) {
      case PathRateStatus.optimal:
        color = Colors.green;
        break;
      case PathRateStatus.medium:
        color = Colors.blue;
        break;
      case PathRateStatus.sufficient:
        color = Colors.orange;
        break;
      case PathRateStatus.requiresMaintenance:
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildMapView(List<BikePath> paths) {
    // Calculate center from all paths
    if (paths.isEmpty || paths.every((p) => p.segments.isEmpty)) {
      return const Center(child: Text('No path data for map'));
    }

    final allPoints = paths
        .expand((p) => p.segments)
        .map((s) => LatLng(s.lat, s.lng))
        .toList();

    if (allPoints.isEmpty) {
      return const Center(child: Text('No location data available'));
    }

    double avgLat = allPoints.map((p) => p.latitude).reduce((a, b) => a + b) / allPoints.length;
    double avgLng = allPoints.map((p) => p.longitude).reduce((a, b) => a + b) / allPoints.length;

    final markers = <Marker>{};
    for (final path in paths) {
      if (path.segments.isNotEmpty) {
        final firstSeg = path.segments.first;
        markers.add(Marker(
          markerId: MarkerId(path.id),
          position: LatLng(firstSeg.lat, firstSeg.lng),
          infoWindow: InfoWindow(
            title: path.name ?? 'Bike Path',
            snippet: '${path.status.label} • ${path.segments.length} segments',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ContributionDetailsPage(path: path, isPublicView: true),
                ),
              );
            },
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            switch (path.status) {
              PathRateStatus.optimal => BitmapDescriptor.hueGreen,
              PathRateStatus.medium => BitmapDescriptor.hueAzure,
              PathRateStatus.sufficient => BitmapDescriptor.hueOrange,
              PathRateStatus.requiresMaintenance => BitmapDescriptor.hueRed,
            },
          ),
        ));
      }
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(avgLat, avgLng),
        zoom: 12,
      ),
      markers: markers,
      onMapCreated: (controller) => _mapController = controller,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes} min ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
