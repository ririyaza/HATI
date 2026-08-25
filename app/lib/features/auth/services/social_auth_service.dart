import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// The Firebase project's web OAuth client id (from google-services.json,
/// `oauth_client` entry with `client_type: 3`). Android needs this as the
/// `serverClientId` so the id token Google issues is accepted by Firebase.
const _webClientId =
    '523234567617-majj93tuv1tvdjrmo9e00k14jdupqdgq.apps.googleusercontent.com';

const _iosClientId =
    '523234567617-mlj5pksd0kv9dhm8r2lki7nsils7pj7s.apps.googleusercontent.com';

/// Thrown when the user backs out of a social sign-in flow, so callers can
/// treat it as a silent no-op instead of an error to display.
class SocialSignInCancelledException implements Exception {}

/// Wraps Google and Facebook sign-in so both funnel into the same Firebase
/// [FirebaseAuth] session and Firestore user document that email/password
/// auth creates.
class SocialAuthService {
  SocialAuthService._();

  static Future<void>? _googleInitFuture;

  static Future<void> _ensureGoogleSignInInitialized() {
    return _googleInitFuture ??= GoogleSignIn.instance.initialize(
      serverClientId: _webClientId,
      clientId: defaultTargetPlatform == TargetPlatform.iOS ? _iosClientId : null,
    );
  }

  static Future<UserCredential> signInWithGoogle() async {
    await _ensureGoogleSignInInitialized();

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw SocialSignInCancelledException();
      }
      rethrow;
    }

    final credential = GoogleAuthProvider.credential(
      idToken: account.authentication.idToken,
    );

    final userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);
    await _ensureUserDocument(userCredential.user);
    return userCredential;
  }

  static Future<UserCredential> signInWithFacebook() async {
    final result = await FacebookAuth.instance.login(
      permissions: const ['email', 'public_profile'],
    );

    switch (result.status) {
      case LoginStatus.success:
        break;
      case LoginStatus.cancelled:
        throw SocialSignInCancelledException();
      case LoginStatus.failed:
      case LoginStatus.operationInProgress:
        throw FirebaseAuthException(
          code: 'facebook-login-failed',
          message: result.message ?? 'Facebook sign-in failed.',
        );
    }

    final credential =
        FacebookAuthProvider.credential(result.accessToken!.tokenString);

    final userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);
    await _ensureUserDocument(userCredential.user);
    return userCredential;
  }

  /// Social providers don't hit our signup form, so create the same
  /// Firestore profile doc here on a user's first sign-in.
  static Future<void> _ensureUserDocument(User? user) async {
    if (user == null) return;
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
