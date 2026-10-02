import 'dart:async';

/// Returns the Rivium user token for the signed-in user, issued by your
/// server, or null when no user is signed in.
///
/// This is the same token the other Rivium SDKs accept, so the function you
/// already pass to Rivium Chat (`Future<String> Function()`) can be passed
/// here unchanged. Never put the server secret in the app.
typedef RiviumPushTokenProvider = FutureOr<String?> Function();

/// The server refused the user's identity, or the token provider failed.
/// Typically: send the user to login.
///
/// Informational: the request's own error callback is still called as before.
class RiviumPushAuthErrorEvent {
  /// The server rejected the token.
  static const String tokenInvalid = 'token_invalid';

  /// The project requires a user token and none was sent.
  static const String tokenRequired = 'token_required';

  /// The token is expired and no fresh one could be obtained.
  static const String tokenExpired = 'token_expired';

  /// The user id given to the SDK is not the user the token was issued for.
  static const String tokenMismatch = 'token_mismatch';

  /// The token provider threw or did not answer in time. The request was
  /// sent without a token.
  static const String tokenProviderFailed = 'token_provider_failed';

  /// One of the constants above.
  final String code;
  final String message;

  /// What the token provider threw, when [code] is [tokenProviderFailed].
  final Object? error;

  const RiviumPushAuthErrorEvent({
    required this.code,
    required this.message,
    this.error,
  });

  @override
  String toString() => 'RiviumPushAuthErrorEvent($code: $message)';
}
