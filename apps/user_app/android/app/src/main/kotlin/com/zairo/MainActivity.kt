package com.zairo

// FlutterFragmentActivity, not plain FlutterActivity — required by
// local_auth_android (see docs/authentication.md's "Biometric
// architecture" section): its biometric prompt is built on
// androidx.biometric.BiometricPrompt, which needs a FragmentActivity host.
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
