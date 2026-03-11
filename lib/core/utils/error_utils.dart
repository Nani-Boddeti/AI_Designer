/// Converts raw exceptions into user-safe messages.
///
/// Maps known Supabase / auth / network errors to friendly strings.
/// Unknown errors get a generic fallback — never expose internal details.
String userFriendlyError(dynamic error) {
  final msg = error.toString().toLowerCase();

  // Auth errors
  if (msg.contains('email not confirmed')) {
    return 'Please confirm your email first.';
  }
  if (msg.contains('invalid login credentials')) {
    return 'Incorrect email or password.';
  }
  if (msg.contains('user already registered')) {
    return 'An account with this email already exists.';
  }
  if (msg.contains('email rate limit')) {
    return 'Too many attempts. Please wait a moment.';
  }

  // Network errors
  if (msg.contains('socketexception') ||
      msg.contains('network') ||
      msg.contains('connection refused') ||
      msg.contains('handshake')) {
    return 'Network error — please check your connection.';
  }
  if (msg.contains('timeout')) {
    return 'Request timed out. Please try again.';
  }

  // Household
  if (msg.contains('invite code') ||
      (msg.contains('invite') && msg.contains('not found'))) {
    return 'Invalid invite code.';
  }
  if (msg.contains('duplicate') || msg.contains('unique') ||
      msg.contains('already exists') || msg.contains('23505')) {
    return 'You already have an account set up. Please sign in instead.';
  }

  // Generic fallback — never expose raw error
  return 'Something went wrong. Please try again.';
}
