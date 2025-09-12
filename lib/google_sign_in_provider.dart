import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInProvider {
  static final GoogleSignInProvider _instance = GoogleSignInProvider._internal();
  factory GoogleSignInProvider() => _instance;
  GoogleSignInProvider._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  GoogleSignIn get instance => _googleSignIn;

  Future<void> initialize({ required String serverClientId }) async {
    await _googleSignIn.initialize(serverClientId: serverClientId);
  }

  /// Request authorization for extra scopes (will show UI if necessary).
  /// Returns the access token string or null on failure.
  Future<String?> requestScopes(List<String> scopes) async {
    // Use the authorizationClient on the GoogleSignIn instance
    final client = _googleSignIn.authorizationClient;
    final authz = await client.authorizeScopes(scopes); // may throw GoogleSignInException
    return authz.accessToken;
  }

  /// Try to obtain an access token without prompting the user (returns null if not available)
  Future<String?> authorizationForScopes(List<String> scopes) async {
    final client = _googleSignIn.authorizationClient;
    final authz = await client.authorizationForScopes(scopes); // returns null if not authorized
    return authz?.accessToken;
  }
}