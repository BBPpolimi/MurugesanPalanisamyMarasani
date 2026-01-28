import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bike_path.dart';
import '../services/providers.dart';
import 'admin_users_tab.dart';
import 'admin_audit_log_tab.dart';

/// Admin page for reviewing and moderating contributions
class AdminReviewPage extends ConsumerStatefulWidget {
  const AdminReviewPage({super.key});

  @override
  ConsumerState<AdminReviewPage> createState() => _AdminReviewPageState();
}

class _AdminReviewPageState extends ConsumerState<AdminReviewPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<BikePath> _allPaths = [];
  List<BikePath> _flaggedPaths = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final adminService = ref.read(adminServiceProvider);
      _allPaths = await adminService.getAllContributions();
      _flaggedPaths = await adminService.getFlaggedContributions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runMergeJob() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting merge job...')),
    );
    
    try {
      final mergeScheduler = ref.read(mergeSchedulerProvider);
      final processed = await mergeScheduler.runMergeJob();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Merge complete: $processed groups processed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Merge failed: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // Security Check: Ensure user is admin
    final userAsync = ref.watch(userWithRoleProvider);
    
    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (user) {
        // Triple-layer security: must be logged in, not guest, and explicitly admin
        final isAuthorized = user != null && !user.isGuest && user.isAdmin;
        
        if (!isAuthorized) {
          return Scaffold(
            appBar: AppBar(title: const Text('Admin Review')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.gpp_bad, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Access Denied', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('You do not have permission to view this page.'),
                  SizedBox(height: 8),
                  Text('Only administrators can access this area.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin Review'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: 'All (${_allPaths.length})'),
            Tab(text: 'Flagged (${_flaggedPaths.length})'),
            const Tab(text: 'Users'),
            const Tab(text: 'Audit Log'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.merge_type),
            onPressed: () => _runMergeJob(),
            tooltip: 'Run Merge Job',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildPathList(_allPaths, showFlagOption: true),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildPathList(_flaggedPaths, showUnflagOption: true),
          const AdminUsersTab(),
          const AdminAuditLogTab(),
        ],
      ),
    );
      },
    );
  }

  Widget _buildPathList(
    List<BikePath> paths, {
    bool showFlagOption = false,
    bool showUnflagOption = false,
  }) {
    if (paths.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No contributions to review'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: paths.length,
        itemBuilder: (context, index) {
          final path = paths[index];
          return _buildAdminCard(
            path,
            showFlagOption: showFlagOption,
            showUnflagOption: showUnflagOption,
          );
        },
      ),
    );
  }

  Widget _buildAdminCard(
    BikePath path, {
    bool showFlagOption = false,
    bool showUnflagOption = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: _buildVisibilityIcon(path.visibility),
        title: Text(path.name ?? 'Untitled Path'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User: ${path.userId.substring(0, 8)}...'),
            Text(
              '${path.segments.length} segments • ${(path.distanceMeters / 1000).toStringAsFixed(2)} km',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Path Info
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(path.status.label)),
                    if (path.city != null) Chip(label: Text(path.city!)),
                    Chip(label: Text('v${path.version}')),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Streets preview
                Text(
                  'Streets: ${path.segments.map((s) => s.streetName).join(' → ')}',
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                if (path.obstacles.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${path.obstacles.length} obstacle(s) reported',
                      style: TextStyle(color: Colors.orange.shade700),
                    ),
                  ),
                
                const Divider(height: 24),
                
                // Admin Actions
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    // Block User button
                    TextButton.icon(
                      onPressed: () => _showBlockUserDialog(path.userId),
                      icon: const Icon(Icons.block, color: Colors.purple),
                      label: const Text('Block User', style: TextStyle(color: Colors.purple)),
                    ),
                    if (showFlagOption && path.visibility != PathVisibility.flagged)
                      TextButton.icon(
                        onPressed: () => _showFlagDialog(path),
                        icon: const Icon(Icons.flag, color: Colors.orange),
                        label: const Text('Flag', style: TextStyle(color: Colors.orange)),
                      ),
                    if (showUnflagOption)
                      TextButton.icon(
                        onPressed: () => _unflagPath(path),
                        icon: const Icon(Icons.check, color: Colors.green),
                        label: const Text('Approve', style: TextStyle(color: Colors.green)),
                      ),
                    TextButton.icon(
                      onPressed: () => _confirmRemove(path),
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      label: const Text('Remove', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityIcon(PathVisibility visibility) {
    switch (visibility) {
      case PathVisibility.published:
        return const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.public, color: Colors.white, size: 20),
        );
      case PathVisibility.flagged:
        return const CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(Icons.flag, color: Colors.white, size: 20),
        );
      case PathVisibility.private:
      default:
        return CircleAvatar(
          backgroundColor: Colors.grey.shade300,
          child: const Icon(Icons.lock, color: Colors.grey, size: 20),
        );
    }
  }

  void _showFlagDialog(BikePath path) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Flag Contribution'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Provide a reason for flagging this contribution:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'e.g., Inaccurate information, spam, etc.',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _flagPath(path, reasonController.text);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Flag'),
          ),
        ],
      ),
    );
  }

  void _showBlockUserDialog(String userId) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Block user: ${userId.substring(0, 12)}...'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Why is this user being blocked?',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _blockUser(userId, reasonController.text);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  Future<void> _blockUser(String userId, String reason) async {
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason')),
      );
      return;
    }

    try {
      await ref.read(adminServiceProvider).blockUser(userId, reason);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blocked')),
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

  Future<void> _flagPath(BikePath path, String reason) async {
    try {
      await ref.read(adminServiceProvider).flagContribution(path.id, reason);
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contribution flagged')),
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

  Future<void> _unflagPath(BikePath path) async {
    try {
      await ref.read(adminServiceProvider).unflagContribution(path.id);
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contribution approved')),
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

  Future<void> _confirmRemove(BikePath path) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Contribution'),
        content: const Text(
          'This will permanently delete this contribution. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(adminServiceProvider).removeContribution(path.id);
        await _loadData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contribution removed')),
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
