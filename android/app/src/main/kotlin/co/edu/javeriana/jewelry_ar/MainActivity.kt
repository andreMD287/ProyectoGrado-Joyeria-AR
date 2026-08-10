package co.edu.javeriana.jewelry_ar

import io.flutter.embedding.android.FlutterFragmentActivity

// ar_flutter_plugin_2 usa PlatformViews que exigen que la Activity host
// extienda FragmentActivity. La FlutterActivity por defecto no lo hace y
// provoca errores al crear el ARView.
class MainActivity : FlutterFragmentActivity()
