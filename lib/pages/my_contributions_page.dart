import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bike_path.dart';
import '../services/providers.dart';
import 'bike_path_form_page.dart';
import 'contribution_details_page.dart';

class MyContributionsPage extends ConsumerStatefulWidget {
  const MyContributionsPage({super.key});

  @override
  ConsumerState<MyContributionsPage> createState() => _MyContributionsPageState();
}

class _MyContributionsPageState extends ConsumerState<MyContributionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Contributions'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.black.withOpacity(0.7),
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Drafts/Private'),
            Tab(text: 'Published'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDraftsList(),
          _buildPublishedList(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BikePathFormPage()),
          ).then((_) {
            ref.refresh(myDraftPathsProvider);
            ref.refresh(myPublishedPathsProvider);
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('New Path'),
      ),
    );
  }

  Widget _buildDraftsList() {
    final draftsAsync = ref.watch(myDraftPathsProvider);

    return draftsAsync.when(
      data: (paths) {
        if (paths.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.drafts, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No drafts yet', style: TextStyle(color: Colors.grey)),
                SizedBox(height: 8),
                Text('Create a new path to get started'),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.refresh(myDraftPathsProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: paths.length,
            itemBuilder: (context, index) => _buildPathCard(paths[index]),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildPublishedList() {
    final publishedAsync = ref.watch(myPublishedPathsProvider);

    return publishedAsync.when(
      data: (paths) {
        if (paths.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.public, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No published paths', style: TextStyle(color: Colors.grey)),
                SizedBox(height: 8),
                Text('Publish a draft to share with the community'),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.refresh(myPublishedPathsProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: paths.length,
            itemBuilder: (context, index) => _buildPathCard(paths[index]),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildPathCard(BikePath path) {
    final isPublished = path.visibility == PathVisibility.published;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContributionDetailsPage(path: path),
            ),
          ).then((_) {
            ref.refresh(myDraftPathsProvider);
            ref.refresh(myPublishedPathsProvider);
          });
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
                  _buildStatusBadge(path.visibility),
                ],
              ),
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
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Updated ${_formatDate(path.updatedAt)}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _editPath(path),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                  ),
                  TextButton.icon(
                    onPressed: () => _togglePublish(path),
                    icon: Icon(
                      isPublished ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                    label: Text(isPublished ? 'Unpublish' : 'Publish'),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmDelete(path),
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(PathVisibility visibility) {
    Color color;
    String label;
    IconData icon;

    switch (visibility) {
      case PathVisibility.published:
        color = Colors.green;
        label = 'Public';
        icon = Icons.public;
        break;
      case PathVisibility.flagged:
        color = Colors.orange;
        label = 'Flagged';
        icon = Icons.flag;
        break;
      case PathVisibility.private:
      default:
        color = Colors.blue;
        label = 'Private';
        icon = Icons.lock;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
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

  void _editPath(BikePath path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BikePathFormPage(existingPath: path),
      ),
    ).then((_) {
      ref.refresh(myDraftPathsProvider);
      ref.refresh(myPublishedPathsProvider);
    });
  }

  Future<void> _togglePublish(BikePath path) async {
    final isPublished = path.visibility == PathVisibility.published;
    
    try {
      await ref.read(contributeServiceProvider).togglePublish(path.id, !isPublished);
      ref.refresh(myDraftPathsProvider);
      ref.refresh(myPublishedPathsProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPublished 
              ? 'Path moved to drafts' 
              : 'Path published successfully!'),
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

  Future<void> _confirmDelete(BikePath path) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Path'),
        content: const Text(
          'Are you sure you want to delete this path? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(contributeServiceProvider).deleteBikePath(path.id);
        ref.refresh(myDraftPathsProvider);
        ref.refresh(myPublishedPathsProvider);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Path deleted')),
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
  }
}
