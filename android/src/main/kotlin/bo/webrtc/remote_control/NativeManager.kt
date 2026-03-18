package bo.webrtc.remote_control

import android.app.Activity
import android.app.Instrumentation
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.UnsupportedEncodingException
import java.nio.charset.Charset
import java.util.ArrayList
import java.util.HashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class NativeManager(private val context: Context?) {
    private val TAG = "NativeManager"

    private val executorService: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler: Handler = Handler(Looper.getMainLooper())
    private var methodChannel: MethodChannel? = null


    private val REQUEST_MEDIA_PROJECTION = 1001
    private val REQUEST_NOTIFICATION_PERMISSION = 1002
    private var dpm: DevicePolicyManager? = null
    private var adminComponent: ComponentName? = null
    private var mediaProjectionResult: MethodChannel.Result? = null
    private var mediaProjectionResultCode: Int = 0
    private var mediaProjectionData: Intent? = null

    init {
        // Inicializar objetos dependientes del context si está disponible
        context?.let {
            dpm = it.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
            adminComponent = ComponentName(it, MyDeviceAdminReceiver::class.java)
        }
    }

    fun setMethodChannel(methodChannel: MethodChannel) {
        this.methodChannel = methodChannel
    }

    fun handleMethodCall(call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "isDeviceOwner" -> {
                val pkg = context?.packageName ?: ""
                result.success(dpm?.isDeviceOwnerApp(pkg) ?: false)
            }
            "isAccessibilityEnabled" -> {
                result.success(isAccessibilityServiceEnabled())
            }
            "openAccessibilitySettings" -> {
                context?.let {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    it.startActivity(intent)
                    result.success(true)
                } ?: result.error("NO_CONTEXT", "Context is null", null)
            }
            "requestMediaProjection" -> {
                requestMediaProjectionPermission(result)
            }
            "startScreenCapture" -> {
                if (ScreenCaptureService.isRunning()) {
                    result.success(true)
                } else if (mediaProjectionData != null) {
                    context?.let { ctx ->
                        ScreenCaptureService.startService(ctx, mediaProjectionResultCode, mediaProjectionData!!)
                        result.success(true)
                    } ?: result.error("NO_CONTEXT", "Context is null", null)
                } else {
                    result.error("NO_PERMISSION", "MediaProjection permission not granted", null)
                }
            }
            "stopScreenCapture" -> {
                // Primero liberar MediaProjection
                ScreenCaptureService.releaseMediaProjection()
                // Luego detener el servicio
                context?.let { ctx ->
                    ScreenCaptureService.stopService(ctx)
                    result.success(true)
                } ?: result.error("NO_CONTEXT", "Context is null", null)
            }
            "releaseMediaProjection" -> {
                // Método explícito para liberar solo MediaProjection
                ScreenCaptureService.releaseMediaProjection()
                result.success(true)
            }
            "isScreenCaptureRunning" -> {
                result.success(ScreenCaptureService.isRunning())
            }
            "simulateTouch" -> {
                val x = (call.argument<Double>("x") ?: 0.0).toFloat()
                val y = (call.argument<Double>("y") ?: 0.0).toFloat()
                val success = RemoteControlAccessibilityService.simulateTouch(x, y)
                result.success(success)
            }
            "simulateSwipe" -> {
                val x1 = (call.argument<Double>("x1") ?: 0.0).toFloat()
                val y1 = (call.argument<Double>("y1") ?: 0.0).toFloat()
                val x2 = (call.argument<Double>("x2") ?: 0.0).toFloat()
                val y2 = (call.argument<Double>("y2") ?: 0.0).toFloat()
                val duration = (call.argument<Int>("duration") ?: 300).toLong()
                val success = RemoteControlAccessibilityService.simulateSwipe(x1, y1, x2, y2, duration)
                result.success(success)
            }
            "pressBack" -> {
                val success = RemoteControlAccessibilityService.getInstance()?.performBackButton() ?: false
                result.success(success)
            }
            "pressHome" -> {
                val success = RemoteControlAccessibilityService.getInstance()?.performHomeButton() ?: false
                result.success(success)
            }
            "pressRecents" -> {
                val success = RemoteControlAccessibilityService.getInstance()?.performRecentApps() ?: false
                result.success(success)
            }
            "changeSettings" -> {
                val setting = call.argument<String>("setting")
                val value = call.argument<String>("value")
                changeSystemSettings(setting, value, result)
            }
            "lockDevice" -> {
                dpm?.lockNow()
                result.success(true)
            }
            "inputText" -> {
                val text = call.argument<String>("text")
                if (text != null) {
                    val success = RemoteControlAccessibilityService.getInstance()?.inputText(text) ?: false
                    result.success(success)
                } else {
                    result.error("INVALID_ARGUMENT", "text is null", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val pkg = context?.packageName ?: return false
//        val service = "$pkg/${RemoteControlAccessibilityService::class.java.canonicalName}"
        val service = "$pkg"
        val enabledServices = Settings.Secure.getString(
            context?.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        )
        return enabledServices?.contains(service) == true
    }

    private fun requestMediaProjectionPermission(result: MethodChannel.Result) {
        // Verificar permiso de notificaciones en Android 13+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (context?.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)
                != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                if (context is Activity) {
                    context.requestPermissions(
                        arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                        REQUEST_NOTIFICATION_PERMISSION
                    )
                }
            }
        }

        mediaProjectionResult = result
        val activity = context as? Activity
        if (activity == null) {
            result.error("NO_ACTIVITY", "Context is not an Activity, cannot request MediaProjection", null)
            return
        }

        val projectionManager = activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        activity.startActivityForResult(projectionManager.createScreenCaptureIntent(), REQUEST_MEDIA_PROJECTION)
    }

    // Estos métodos deben ser invocados desde la Activity que contiene el plugin
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_MEDIA_PROJECTION) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                // Guardar datos para el servicio
                mediaProjectionResultCode = resultCode
                mediaProjectionData = data

                // Iniciar foreground service
                context?.let { ctx ->
                    ScreenCaptureService.startService(ctx, resultCode, data)
                    mediaProjectionResult?.success(true)
                } ?: run {
                    mediaProjectionResult?.error("NO_CONTEXT", "Context is null", null)
                }

            } else {
                mediaProjectionResult?.success(false)
            }
            mediaProjectionResult = null
        }
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == REQUEST_NOTIFICATION_PERMISSION) {
            // Continuar con MediaProjection después de permisos (si necesario)
        }
    }

    fun changeSystemSettings(setting: String?, value: String?, result: MethodChannel.Result) {
        val pkg = context?.packageName ?: ""
        if (dpm?.isDeviceOwnerApp(pkg) != true) {
            result.error("NOT_DEVICE_OWNER", "App no es Device Owner", null)
            return
        }

        try {
            when (setting) {
                "bluetooth_on" -> {
                    adminComponent?.let { dpm?.setGlobalSetting(it, Settings.Global.BLUETOOTH_ON, value) }
                }
                "wifi_on" -> {
                    adminComponent?.let { dpm?.setGlobalSetting(it, Settings.Global.WIFI_ON, value) }
                }
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }

//    // Escribir texto usando AccessibilityService
//    fun inputText(text: String): Boolean {
//        return try {
//            val accessibilityService = RemoteControlAccessibilityService.getinstance
//            if (accessibilityService != null) {
//                // Método 1: Usando AccessibilityNodeInfo (recomendado)
//                val rootNode = accessibilityService.rootInActiveWindow
//                val focusedNode = rootNode?.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
//
//                if (focusedNode != null) {
//                    val arguments = Bundle()
//                    arguments.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
//                    focusedNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
//                    focusedNode.recycle()
//                    true
//                } else {
//                    // Método 2: Simular tecleo con eventos de teclado (fallback)
//                    simulateKeyPresses(text)
//                }
//            } else {
//                Log.e(TAG, "AccessibilityService no disponible")
//                false
//            }
//        } catch (e: Exception) {
//            Log.e(TAG, "Error al escribir texto: ${e.message}")
//            false
//        }
//    }
//
//    // Método alternativo: Simular presión de teclas
//    fun simulateKeyPresses(text: String): Boolean {
//        return try {
//            val instrumentation = Instrumentation()
//            for (char in text) {
//                val keyCode = getKeyCodeForChar(char)
//                if (keyCode != -1) {
//                    instrumentation.sendKeyDownUpSync(keyCode)
//                }
//            }
//            true
//        } catch (e: Exception) {
//            Log.e("simulateKeyPresses", "Error simulando teclas: ${e.message}")
//            false
//        }
//    }
//
//    // Mapear caracteres a KeyCodes
//    fun getKeyCodeForChar(char: Char): Int {
//        return when (char) {
//            in 'a'..'z' -> KeyEvent.KEYCODE_A + (char - 'a')
//            in 'A'..'Z' -> KeyEvent.KEYCODE_A + (char - 'A')
//            in '0'..'9' -> KeyEvent.KEYCODE_0 + (char - '0')
//            ' ' -> KeyEvent.KEYCODE_SPACE
//            '.' -> KeyEvent.KEYCODE_PERIOD
//            ',' -> KeyEvent.KEYCODE_COMMA
//            '@' -> KeyEvent.KEYCODE_AT
//            else -> -1 // No soportado
//        }
//    }

    fun dispose() {
        executorService.shutdown()
    }
}