import 'package:flutter/foundation.dart'; // Required for kIsWeb check
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. Email & Password Authentication
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  // 2. Google Login (Smart Platform Detection)
  /// Google sign-in.
  ///
  /// The two platforms need different flows.
  ///
  /// **Web.** `google_sign_in_web` (0.12.x) does not return an `idToken` from
  /// `signIn()` - the value is always null, because the web implementation moved ID
  /// tokens to the One Tap / renderButton flow. The previous implementation asked for
  /// `idToken` on every platform and therefore always threw "No ID Token found."
  /// in a browser. Supabase's own OAuth redirect is used instead, which needs no
  /// client library at all.
  ///
  /// **Android / iOS.** The native flow does return an ID token, so
  /// `signInWithIdToken` remains correct and avoids a browser round-trip.
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: Uri.base.origin,
        authScreenLaunchMode: LaunchMode.platformDefault,
      );
      // The browser navigates away and returns to the app; the session is restored
      // by supabase_flutter on reload, so there is nothing to await here.
      return;
    }

    const webClientId =
        '317635996644-esu8rvjbn8mu1dmar391gk0eo354jekr.apps.googleusercontent.com';

    final googleSignIn = GoogleSignIn(serverClientId: webClientId);
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw 'Google login cancelled';
    }

    final googleAuth = await googleUser.authentication;
    final accessToken = googleAuth.accessToken;
    final idToken = googleAuth.idToken;

    if (accessToken == null) throw 'No access token returned by Google.';
    if (idToken == null) throw 'No ID token returned by Google.';

    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  // Utility Methods
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  User? get currentUser => _supabase.auth.currentUser;
}