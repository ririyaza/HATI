import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'features/onboarding/loading_screen.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'shared/audio/hati_audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Explicit, not left to whatever a given Android/OEM build defaults to —
  // without this, some 3-button-nav OEM skins report an inconsistent (or
  // zero) bottom WindowInsets value to Flutter's MediaQuery even though the
  // nav bar visually still occupies that space, which is what let bottom
  // action bars/buttons render underneath it (QA: "Continue button being
  // covered up"). Forcing edgeToEdge makes every system bar transparent and
  // inset-reported consistently, so SafeArea's padding.bottom is reliable.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Play Integrity / App Attest only issue valid verdicts for an app whose
  // package is linked to a Google Play Console account (Play Integrity)
  // or distributed via TestFlight/App Store (App Attest) — neither is true
  // yet for these Firebase App Distribution test builds, so every
  // attestation call 403s with "App attestation failed" regardless of
  // kDebugMode/build type. Forcing the debug provider here too (not just
  // for kDebugMode builds) unblocks that.
  //
  // A fixed, hardcoded debugToken (rather than leaving it unset) means
  // every install of this build — this device, a teammate's, a fresh
  // reinstall — presents the exact same token instead of the provider
  // generating a new random one per install that would need pulling from
  // logcat and registering individually each time. Register this one
  // value once in Firebase Console > App Check > (app) > Manage debug
  // tokens and every install is covered.
  //
  // Shared across every install, so treat it like a secret embedded in
  // the APK (because it is one) — fine for a closed testing group, but
  // revoke it in the Console rather than reusing it for a public release.
  //
  // TODO: once the app is linked in Play Console (see Option B — SHA
  // fingerprint + Play Integrity API enabled) and/or actually ships via
  // Play/App Store, restore this to `kDebugMode ? debug : real provider`
  // so release builds get real attestation instead of the debug provider.
  const testDebugToken = '07961f34-b957-4e91-9360-f26ed72acab3';
  await FirebaseAppCheck.instance.activate(
    providerAndroid: const AndroidDebugProvider(debugToken: testDebugToken),
    providerApple: const AppleDebugProvider(debugToken: testDebugToken),
  );
  // Loads persisted music/SFX on-off + volume before anything can play, so
  // the very first scenario a player opens already respects whatever they
  // last set in Sound & Music instead of a brief flash of default volume.
  await HatiAudioService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Shows up as the app's name in Android's recent-apps/task-switcher
      // card (and iOS's equivalent) — left over from the Flutter starter
      // template, which is why "Flutter Demo" was appearing there instead
      // of the actual app name.
      title: 'HATI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const LoadingScreen(),
    );
  }
}
