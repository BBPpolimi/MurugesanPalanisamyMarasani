import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/audit_log.dart';
import '../services/providers.dart';

/// Widget for viewing admin audit logs
class AdminAuditLogTab extends ConsumerStatefulWidget {
  const AdminAuditLogTab({super.key});

  @override
  ConsumerState<AdminAuditLogTab> createState() => _AdminAuditLogTabState();
}

class _AdminAuditLogTabState extends ConsumerState<AdminAuditLogTab> {
  List<AuditLog> _logs = [];
  bool _isLoadingData = false;
  bool _hasLoadedData = false;
  AdminAction? _filterAction;

  Future<void> _loadLogs() async {
    if (_isLoadingData) return; // Prevent multiple simultaneous loads
    
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
      
      // Ensure admin service is initialized
      final adminService = ref.read(adminServiceProvider);
      adminService.initialize(user.uid, user.isAdmin, email: user.email);
      
      _logs = await adminService.getAuditLogs(
        limit: 200,
        filterByAction: _filterAction,
      );
      _hasLoadedData = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading audit logs: $e')),
        );
      }
    }
    if (mounted) {
      setState(() => _isLoadingData = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the user provider - this will trigger rebuild when data is available
    final userAsync = ref.watch(userWithRoleProvider);
    
    return userAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error loading user: $e')),
      data: (user) {
        // User data is now available
        if (user == null || !user.isAdmin) {
          return const Center(child: Text('Admin access required'));
        }
        
        // Initialize admin service with the user
        final adminService = ref.read(adminServiceProvider);
        adminService.initialize(user.uid, user.isAdmin, email: user.email);
        
        // Load data if not already loaded
        if (!_hasLoadedData && !_isLoadingData) {
          // Schedule the load after this build frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadLogs();
          });
        }
        
        if (_isLoadingData) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            // Filter Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('Filter: '),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(null, 'All'),
                          ...AdminAction.values.map((action) => 
                            _buildFilterChip(action, action.label),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      _hasLoadedData = false;
                      _loadLogs();
                    },
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),

            // Logs List
            Expanded(
              child: _logs.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No audit logs found'),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        _hasLoadedData = false;
                        await _loadLogs();
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          return _buildLogCard(_logs[index]);
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(AdminAction? action, String label) {
    final isSelected = _filterAction == action;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (selected) {
          setState(() {
            _filterAction = selected ? action : null;
            _hasLoadedData = false; // Force reload with new filter
          });
          _loadLogs();
        },
      ),
    );
  }

  Widget _buildLogCard(AuditLog log) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm:ss');
    final color = _getActionColor(log.action);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Text(log.action.icon),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color),
              ),
              child: Text(
                log.action.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Target: ${log.targetId.substring(0, 12)}...',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (log.details != null && log.details!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  log.details!,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    log.adminEmail ?? log.adminId.substring(0, 12),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  dateFormat.format(log.timestamp),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: log.details != null && log.details!.isNotEmpty,
      ),
    );
  }

  Color _getActionColor(AdminAction action) {
    switch (action) {
      case AdminAction.blockUser:
        return Colors.red;
      case AdminAction.unblockUser:
        return Colors.green;
      case AdminAction.flagContribution:
        return Colors.orange;
      case AdminAction.unflagContribution:
        return Colors.blue;
      case AdminAction.removeContribution:
        return Colors.red.shade800;
      case AdminAction.setUserRole:
        return Colors.purple;
    }
  }
}
