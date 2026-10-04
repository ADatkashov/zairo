package com.zairo.business_admin

// FlutterFragmentActivity, not plain FlutterActivity — required by local_auth's
// BiometricPrompt (it needs a FragmentActivity), same as the consumer app.
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
