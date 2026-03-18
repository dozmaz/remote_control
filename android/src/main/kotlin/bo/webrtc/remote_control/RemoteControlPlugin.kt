package bo.webrtc.remote_control

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware as FlutterActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding as FlutterActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.app.Activity as AndroidActivity

class RemoteControlPlugin : FlutterPlugin, MethodCallHandler, FlutterActivityAware {
    private lateinit var remoteChannel: MethodChannel
    private lateinit var nativeChannel: MethodChannel
    private var activity: AndroidActivity? = null
    private var nativeManager: NativeManager? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        remoteChannel = MethodChannel(binding.binaryMessenger, "remote_control")
        remoteChannel.setMethodCallHandler(this)

        nativeChannel = MethodChannel(binding.binaryMessenger, "bo.webrtc.remote_control/native")
        // No crear NativeManager aquí porque aún no tenemos Activity
        nativeChannel.setMethodCallHandler { call, result ->
            nativeManager?.handleMethodCall(call, result) ?: result.notImplemented()
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "getPlatformVersion") {
            result.success("Android ${android.os.Build.VERSION.RELEASE}")
        } else {
            result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        remoteChannel.setMethodCallHandler(null)
        nativeChannel.setMethodCallHandler(null)
    }

    // ActivityAware implementations (evitan ambigüedad usando alias en imports)
    override fun onAttachedToActivity(binding: FlutterActivityPluginBinding) {
        activity = binding.activity
        nativeManager = NativeManager(activity)
        nativeManager?.setMethodChannel(nativeChannel)

        binding.addActivityResultListener { requestCode, resultCode, data ->
            nativeManager?.onActivityResult(requestCode, resultCode, data)
            false
        }

        binding.addRequestPermissionsResultListener { requestCode, permissions, grantResults ->
            nativeManager?.onRequestPermissionsResult(requestCode, permissions, grantResults)
            false
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: FlutterActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activity = null
        nativeManager?.dispose()
        nativeManager = null
    }
}
