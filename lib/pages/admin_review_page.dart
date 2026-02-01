import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/contribution.dart';
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
  List<Contribution> _allContributions = [];
  List<Contribution> _flaggedContributions = [];
  bool _isLoadingData = false;
  bool _hasLoadedData = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_isLoadingData) return;
    
    setState(() => _isLoadingData = true);
    
    try {
      final userAsync = ref.read(userWithRoleProvider);
      final user = userAsync.asData?.value;
      if (user == null || !user.isAdmin) {
        if (mounted) {
          setState(() => _isLoadingData = false);
        }
        return;
      }
      
      final adminService = ref.read(adminServiceProvider);
      adminService.initialize(user.uid, user.isAdmin, email: user.email);
      
      _allContributions = await adminService.getAllContributions();
      _flaggedContributions = await adminService.getFlaggedContributions();
      _hasLoadedData = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoadingData = false);
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
    final userAsync = ref.watch(userWithRoleProvider);
    
    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (user) {
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

        // Initialize admin service
        final adminService = ref.read(adminServiceProvider);
        adminService.initialize(user.uid, user.isAdmin, email: user.email);
        
        // Load data if not loaded
        if (!_hasLoadedData && !_isLoadingData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadData();
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin Review'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: 'All (${_allContributions.length})'),
            Tab(text: 'Flagged (${_flaggedContributions.length})'),
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
            onPressed: () {
              _hasLoadedData = false;
              _loadData();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _isLoadingData
              ? const Center(child: CircularProgressIndicator())
              : _buildContributionList(_allContributions, showFlagOption: true),
          _isLoadingData
              ? const Center(child: CircularProgressIndicator())
              : _buildContributionList(_flaggedContributions, showUnflagOption: true),
          const AdminUsersTab(),
          const AdminAuditLogTab(),
        ],
      ),
    );
      },
    );
  }

  Widget _buildContributionList(
    List<Contribution> contributions, {
    bool showFlagOption = false,
    bool showUnflagOption = false,
  }) {
    if (contributions.isEmpty) {
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
        itemCount: contributions.length,
        itemBuilder: (context, index) {
          final contribution = contributions[index];
          return _buildAdminCard(
            contribution,
            showFlagOption: showFlagOption,
            showUnflagOption: showUnflagOption,
          );
        },
      ),
    );
  }

  Widget _buildAdminCard(
    Contribution contribution, {
    bool showFlagOption = false,
    bool showUnflagOption = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: _buildStateIcon(contribution.state),
        title: Text(contribution.name ?? 'Untitled Contribution'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User: ${contribution.userId.length > 8 ? contribution.userId.substring(0, 8) : contribution.userId}...'),
            Text(
              '${contribution.sourceLabel} • ${(contribution.distanceMeters / 1000).toStringAsFixed(2)} km',
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
                // Contribution Info
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(contribution.statusRating.label)),
                    Chip(label: Text(contribution.state.name)),
                    if (contribution.city != null) Chip(label: Text(contribution.city!)),
                    Chip(label: Text('v${contribution.version}')),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Score if available
                if (contribution.pathScore != null)
                  Text(
                    'Path Score: ${contribution.pathScore!.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                
                if (contribution.obstacles.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${contribution.obstacles.length} obstacle(s) reported',
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
                    TextButton.icon(
                      onPressed: () => _showBlockUserDialog(contribution.userId),
                      icon: const Icon(Icons.block, color: Colors.purple),
                      label: const Text('Block User', style: TextStyle(color: Colors.purple)),
                    ),
                    if (showFlagOption)
                      TextButton.icon(
                        onPressed: () => _showFlagDialog(contribution),
                        icon: const Icon(Icons.flag, color: Colors.orange),
                        label: const Text('Flag', style: TextStyle(color: Colors.orange)),
                      ),
                    if (showUnflagOption)
                      TextButton.icon(
                        onPressed: () => _unflagContribution(contribution),
                        icon: const Icon(Icons.check, color: Colors.green),
                        label: const Text('Approve', style: TextStyle(color: Colors.green)),
                      ),
                    TextButton.icon(
                      onPressed: () => _confirmRemove(contribution),
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

  Widget _buildStateIcon(ContributionState state) {
    switch (state) {
      case ContributionState.published:
        return const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.public, color: Colors.white, size: 20),
        );
      case ContributionState.archived:
        return const CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(Icons.flag, color: Colors.white, size: 20),
        );
      case ContributionState.privateSaved:
        return CircleAvatar(
          backgroundColor: Colors.grey.shade300,
          child: const Icon(Icons.lock, color: Colors.grey, size: 20),
        );
      case ContributionState.draft:
        return CircleAvatar(
          backgroundColor: Colors.blue.shade200,
          child: const Icon(Icons.edit, color: Colors.white, size: 20),
        );
      case ContributionState.pendingConfirmation:
        return const CircleAvatar(
          backgroundColor: Colors.amber,
          child: Icon(Icons.pending, color: Colors.white, size: 20),
        );
    }
  }

  void _showFlagDialog(Contribution contribution) {
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
              await _flagContribution(contribution, reasonController.text);
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
            Text('Block user: ${userId.length > 12 ? userId.substring(0, 12) : userId}...'),
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

  Future<void> _flagContribution(Contribution contribution, String reason) async {
    try {
      await ref.read(adminServiceProvider).flagContribution(contribution.id, reason);
      _hasLoadedData = false;
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

  Future<void> _unflagContribution(Contribution contribution) async {
    try {
      await ref.read(adminServiceProvider).unflagContribution(contribution.id);
      _hasLoadedData = false;
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

  Future<void> _confirmRemove(Contribution contribution) async {
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
        await ref.read(adminServiceProvider).removeContribution(contribution.id);
        _hasLoadedData = false;
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
