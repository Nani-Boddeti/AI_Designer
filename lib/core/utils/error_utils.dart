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
  if (msg.contains('invalid login credentials') ||
      msg.contains('invalid credentials') ||
      msg.contains('wrong password') ||
      msg.contains('authapierror') ||
      msg.contains('auth api') ||
      (msg.contains('invalid') && msg.contains('password'))) {
    return 'Incorrect email or password.';
  }
  if (msg.contains('user already registered')) {
    return 'An account with this email already exists.';
  }
  if (msg.contains('email rate limit') ||
      msg.contains('rate limit') ||
      msg.contains('too many requests')) {
    return 'Too many attempts. Please wait a moment.';
  }
  if (msg.contains('user not found') ||
      (msg.contains('no user') && msg.contains('found'))) {
    return 'No account found with this email.';
  }
  if (msg.contains('not_authenticated') || msg.contains('not authenticated')) {
    return 'Session expired. Please sign in again.';
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

  // Permission / RLS errors
  if (msg.contains('permission denied') ||
      msg.contains('insufficient privilege') ||
      msg.contains('row level security') ||
      msg.contains('rls') ||
      msg.contains('not authorized') ||
      msg.contains('42501')) {
    return 'You don\'t have permission to do that.';
  }

  // Storage errors
  if (msg.contains('storage') && msg.contains('not found')) {
    return 'Image not found. Please try again.';
  }
  if (msg.contains('payload too large') ||
      msg.contains('file too large') ||
      msg.contains('413')) {
    return 'Image is too large. Please choose a smaller file.';
  }

  // AI / Gemini errors
  if (msg.contains('quota') ||
      msg.contains('resource_exhausted') ||
      (msg.contains('429') && !msg.contains('rate limit'))) {
    return 'AI service is busy. Please try again in a moment.';
  }
  if (msg.contains('safety') || msg.contains('blocked')) {
    return 'This content couldn\'t be processed. Please try a different image.';
  }

  // Generic fallback — never expose raw error
  return 'Something went wrong. Please try again.';
}
