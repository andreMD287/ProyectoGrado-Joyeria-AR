package co.edu.javeriana.jewelry_ar

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// ar_flutter_plugin_2 usa PlatformViews que exigen que la Activity host
// extienda FragmentActivity. La FlutterActivity por defecto no lo hace y
// provoca errores al crear el ARView.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Seguimiento del cuello para collares y de la cabeza para aretes (ver
        // NeckTracker). Los resultados de la cabeza salen por su EventChannel.
        val tracker = NeckTracker(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jewelry_ar/neck")
            .setMethodCallHandler(tracker)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "jewelry_ar/head_results")
            .setStreamHandler(tracker)
    }
}
