/// Converts raw exception messages into user-friendly error strings.
String friendlyError(dynamic error) {
  final msg = error.toString().toLowerCase();

  // Network / connectivity errors
  if (msg.contains('socketexception') ||
      msg.contains('connection reset') ||
      msg.contains('connection refused') ||
      msg.contains('connection closed') ||
      msg.contains('network is unreachable') ||
      msg.contains('no address associated') ||
      msg.contains('failed host lookup') ||
      msg.contains('errno = 101') ||
      msg.contains('errno = 104') ||
      msg.contains('errno = 111')) {
    return 'No internet connection. Please check your network and try again.';
  }

  // Timeout
  if (msg.contains('timed out') || msg.contains('timeout')) {
    return 'Request timed out. Please check your connection and try again.';
  }

  // Supabase / server errors
  if (msg.contains('500') || msg.contains('internal server error')) {
    return 'Something went wrong on our end. Please try again in a moment.';
  }

  // Rate limit (already has a friendly message from the Edge Function)
  if (msg.contains('scan_limit_reached') || msg.contains('429')) {
    // Pass through — the Edge Function returns a readable message
    final cleaned = error.toString().replaceFirst('Exception: ', '');
    return cleaned;
  }

  // ClientException (generic http errors)
  if (msg.contains('clientexception')) {
    return 'Connection error. Please check your internet and try again.';
  }

  // Fallback: strip "Exception: " prefix and return
  return error.toString().replaceFirst('Exception: ', '');
}
