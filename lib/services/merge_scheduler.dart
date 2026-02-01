import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'path_group_service.dart';

/// Service for scheduling and triggering path group merges
class MergeScheduler {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PathGroupService _pathGroupService = PathGroupService();
  
  Timer? _periodicTimer;
  DateTime? _lastMergeTime;
  
  /// Start periodic merge job (runs every [intervalMinutes])
  void startPeriodicMerge({int intervalMinutes = 30}) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => runMergeJob(),
    );
  }
  
  /// Stop periodic merge job
  void stopPeriodicMerge() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }
  
  /// Get last merge timestamp
  DateTime? get lastMergeTime => _lastMergeTime;
  
  /// Run merge job for all stale path groups
  /// Returns number of groups processed
  Future<int> runMergeJob() async {
    int processed = 0;
    
    try {
      // 1. Find all unique normalizedKeys from published bike paths
      final bikePaths = await _firestore
          .collection('bike_paths')
          .where('visibility', isEqualTo: 'published')
          .where('deleted', isEqualTo: false)
          .get();
      
      final uniqueKeys = <String>{};
      for (final doc in bikePaths.docs) {
        final normalizedKey = doc.data()['normalizedKey'] as String?;
        if (normalizedKey != null && normalizedKey.isNotEmpty) {
          uniqueKeys.add(normalizedKey);
        }
      }
      
      // 2. Process each unique key
      for (final key in uniqueKeys) {
        try {
          await _pathGroupService.recomputePathGroupLocally(key);
          processed++;
        } catch (e) {
          // Log error but continue with other keys
          print('Error processing key $key: $e');
        }
      }
      
      _lastMergeTime = DateTime.now();
      
      // 3. Update merge metadata
      await _firestore.collection('system').doc('mergeStatus').set({
        'lastMergeAt': FieldValue.serverTimestamp(),
        'processedGroups': processed,
        'totalKeys': uniqueKeys.length,
      }, SetOptions(merge: true));
      
    } catch (e) {
      print('Merge job failed: $e');
    }
    
    return processed;
  }
  
  /// Run merge for a specific normalized key
  Future<void> mergePathGroup(String normalizedKey) async {
    await _pathGroupService.recomputePathGroupLocally(normalizedKey);
    _lastMergeTime = DateTime.now();
  }
  
  /// Get merge status from Firestore
  Future<Map<String, dynamic>?> getMergeStatus() async {
    final doc = await _firestore.collection('system').doc('mergeStatus').get();
    return doc.data();
  }
}
