import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/blocked_user.dart';
import '../services/providers.dart';

/// Widget for managing blocked users
class AdminUsersTab extends ConsumerStatefulWidget {
  const AdminUsersTab({super.key});

  @override
  ConsumerState<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<AdminUsersTab> {
  List<BlockedUser> _blockedUsers = [];
  bool _isLoadingData = false;
  bool _hasLoadedData = false;
  final _userIdController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _userIdController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadBlockedUsers() async {
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
      
      _blockedUsers = await adminService.getBlockedUsers();
      _hasLoadedData = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading blocked users: $e')),
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
            _loadBlockedUsers();
          });
        }
        
        if (_isLoadingData) {
          return const Center(child: CircularProgressIndicator());
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Block User Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Block a User',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _userIdController,
                        decoration: const InputDecoration(
                          labelText: 'User ID',
                          hintText: 'Enter the user ID to block',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _reasonController,
                        decoration: const InputDecoration(
                          labelText: 'Reason',
                          hintText: 'Why is this user being blocked?',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.warning),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _blockUser,
                        icon: const Icon(Icons.block),
                        label: const Text('Block User'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Blocked Users List
              Text(
                'Blocked Users (${_blockedUsers.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              Expanded(
                child: _blockedUsers.isEmpty
                    ? const Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                              SizedBox(height: 16),
                              Text('No blocked users'),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadBlockedUsers,
                        child: ListView.builder(
                          itemCount: _blockedUsers.length,
                          itemBuilder: (context, index) {
                            final user = _blockedUsers[index];
                            return _buildBlockedUserCard(user);
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBlockedUserCard(BlockedUser user) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.red,
          child: Icon(Icons.block, color: Colors.white),
        ),
        title: Text(user.displayName ?? user.email ?? user.userId),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user.email != null) Text(user.email!, style: TextStyle(color: Colors.grey.shade600)),
            Text('ID: ${user.userId.substring(0, 12)}...', style: const TextStyle(fontSize: 11)),
            Text('Reason: ${user.reason}', style: TextStyle(color: Colors.red.shade700)),
            Text('Blocked: ${dateFormat.format(user.blockedAt)}', style: const TextStyle(fontSize: 11)),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.lock_open, color: Colors.green),
          tooltip: 'Unblock',
          onPressed: () => _confirmUnblock(user),
        ),
      ),
    );
  }

  Future<void> _blockUser() async {
    final userId = _userIdController.text.trim();
    final reason = _reasonController.text.trim();

    if (userId.isEmpty || reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both User ID and Reason')),
      );
      return;
    }

    try {
      await ref.read(adminServiceProvider).blockUser(userId, reason);
      _userIdController.clear();
      _reasonController.clear();
      _hasLoadedData = false; // Force reload
      await _loadBlockedUsers();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blocked successfully')),
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

  Future<void> _confirmUnblock(BlockedUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unblock User'),
        content: Text('Are you sure you want to unblock ${user.displayName ?? user.userId}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(adminServiceProvider).unblockUser(user.userId);
        _hasLoadedData = false; // Force reload
        await _loadBlockedUsers();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User unblocked')),
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
