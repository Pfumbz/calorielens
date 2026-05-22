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
    return 'No internet connection. Check your network and try again.';
  }

  // Timeout
  if (msg.contains('timed out') || msg.contains('timeout')) {
    return 'Request timed out. Try again — it may work on the next attempt.';
  }

  // Supabase / server errors
  if (msg.contains('500') || msg.contains('internal server error')) {
    return 'Server error — please try again in a moment.';
  }

  // 502 / 503 (edge function cold start or overload)
  if (msg.contains('502') || msg.contains('503') || msg.contains('bad gateway') || msg.contains('service unavailable')) {
    return 'Server is momentarily busy — please try again.';
  }

  // Rate limit (already has a friendly message from the Edge Function)
  if (msg.contains('scan_limit_reached') || msg.contains('chat_limit_reached') || msg.contains('429')) {
    final cleaned = error.toString().replaceFirst('Exception: ', '');
    return cleaned;
  }

  // Auth errors
  if (msg.contains('jwt') || msg.contains('token') || msg.contains('unauthorized') || msg.contains('401')) {
    return 'Session expired. Please sign in again.';
  }

  // AI overloaded
  if (msg.contains('overloaded') || msg.contains('529')) {
    return 'AI is busy right now — please try again in a few seconds.';
  }

  // ClientException (generic http errors)
  if (msg.contains('clientexception')) {
    return 'Connection error. Check your internet and try again.';
  }

  // Fallback: strip "Exception: " prefix and return
  return error.toString().replaceFirst('Exception: ', '');
}
