enum TripState {
  idle,          // Initial state, ready to start
  autoMonitoring, // Auto-detection enabled, monitoring speed
  recording,     // Actively logging GPS points
  paused,        // Temporarily stopped, can resume
  processing,    // Computing statistics after stop
  saved,         // Trip saved successfully
  error,         // Error state (permission denied, GPS issues)
}
