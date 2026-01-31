import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contribution.dart';
import '../services/providers.dart';
import 'bike_path_form_page.dart';
import 'contribution_details_page.dart';
import '../models/path_quality_report.dart'; // Needed for PathRateStatus

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
          unselectedLabelColor: Colors.black.withValues(alpha: 0.7),
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
            ref.refresh(myDraftContributionsProvider);
            ref.refresh(myPublishedContributionsProvider);
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('New Path'),
      ),
    );
  }

  Widget _buildDraftsList() {
    final draftsAsync = ref.watch(myDraftContributionsProvider);

    return draftsAsync.when(
      data: (contributions) {
        if (contributions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.drafts, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No drafts yet', style: TextStyle(color: Colors.grey)),
                SizedBox(height: 8),
                Text('Create a new path or record a trip to get started'),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.refresh(myDraftContributionsProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: contributions.length,
            itemBuilder: (context, index) => _buildContributionCard(contributions[index]),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildPublishedList() {
    final publishedAsync = ref.watch(myPublishedContributionsProvider);

    return publishedAsync.when(
      data: (contributions) {
        if (contributions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.public, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No published contributions', style: TextStyle(color: Colors.grey)),
                SizedBox(height: 8),
                Text('Publish a draft to share with the community'),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.refresh(myPublishedContributionsProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: contributions.length,
            itemBuilder: (context, index) => _buildContributionCard(contributions[index]),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildContributionCard(Contribution contribution) {
    final isPublished = contribution.isPublished;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContributionDetailsPage(contribution: contribution),
            ),
          ).then((_) {
            ref.refresh(myDraftContributionsProvider);
            ref.refresh(myPublishedContributionsProvider);
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and badges row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      contribution.name ?? 'Untitled Path',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _buildSourceBadge(contribution.source),
                  const SizedBox(width: 8),
                  if (contribution.pathScore != null)
                    _buildScoreBadge(contribution.pathScore!),
                ],
              ),
              const SizedBox(height: 8),
              
              // Stats row
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (contribution.segments.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.route, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${contribution.segments.length} segments',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.straighten, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${(contribution.distanceMeters / 1000).toStringAsFixed(2)} km',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(contribution.statusRating),
                        size: 16,
                        color: _getStatusColor(contribution.statusRating),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        contribution.statusRating.label,
                        style: TextStyle(color: _getStatusColor(contribution.statusRating)),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 4),
              Text(
                'Updated ${_formatDate(contribution.updatedAt)}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              
              const Divider(height: 24),
              
              // Actions row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (contribution.source == ContributionSource.manual)
                    TextButton.icon(
                      onPressed: () => _editContribution(contribution),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                    ),
                  TextButton.icon(
                    onPressed: () => _togglePublish(contribution),
                    icon: Icon(
                      isPublished ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                    label: Text(isPublished ? 'Unpublish' : 'Publish'),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmDelete(contribution),
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

  Widget _buildSourceBadge(ContributionSource source) {
    final isManual = source == ContributionSource.manual;
    final color = isManual ? Colors.blue : Colors.purple;
    final icon = isManual ? Icons.edit_road : Icons.gps_fixed;
    final label = isManual ? 'Manual' : 'Auto';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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

  Widget _buildScoreBadge(double score) {
    Color color;
    if (score >= 75) {
      color = Colors.green;
    } else if (score >= 50) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            score.toStringAsFixed(0),
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(PathRateStatus status) {
    switch (status) {
      case PathRateStatus.optimal:
        return Icons.thumb_up;
      case PathRateStatus.medium:
        return Icons.thumbs_up_down;
      case PathRateStatus.sufficient:
        return Icons.warning_amber;
      case PathRateStatus.requiresMaintenance:
        return Icons.report;
    }
  }

  Color _getStatusColor(PathRateStatus status) {
    switch (status) {
      case PathRateStatus.optimal:
        return Colors.green;
      case PathRateStatus.medium:
        return Colors.blue;
      case PathRateStatus.sufficient:
        return Colors.orange;
      case PathRateStatus.requiresMaintenance:
        return Colors.red;
    }
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

  void _editContribution(Contribution contribution) {
    // For manual contributions, edit uses BikePathFormPage
    // Need to convert contribution back to form - this is a TODO
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BikePathFormPage(existingContribution: contribution),
      ),
    ).then((_) {
      ref.refresh(myDraftContributionsProvider);
      ref.refresh(myPublishedContributionsProvider);
    });
  }

  Future<void> _togglePublish(Contribution contribution) async {
    final isPublished = contribution.isPublished;
    
    try {
      await ref.read(contributionServiceProvider).togglePublish(contribution.id, !isPublished);
      ref.refresh(myDraftContributionsProvider);
      ref.refresh(myPublishedContributionsProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPublished 
              ? 'Contribution moved to drafts' 
              : 'Contribution published successfully!'),
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

  Future<void> _confirmDelete(Contribution contribution) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contribution'),
        content: const Text(
          'Are you sure you want to delete this contribution? This action cannot be undone.',
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
        await ref.read(contributionServiceProvider).archiveContribution(contribution.id);
        ref.refresh(myDraftContributionsProvider);
        ref.refresh(myPublishedContributionsProvider);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contribution deleted')),
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
