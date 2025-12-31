enum TripState {
  idle,       // Initial state, ready to start
  recording,  // Actively logging GPS points
  paused,     // Temporarily stopped, can resume
  processing, // Computing statistics after stop
  saved,      // Trip saved successfully
  error,      // Error state (permission denied, GPS issues)
}
