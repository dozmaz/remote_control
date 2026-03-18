package bo.webrtc.remote_control

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

class ScreenCaptureService : Service() {

    companion object {
        private const val TAG = "ScreenCaptureService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "screen_capture_channel"
        private const val CHANNEL_NAME = "Screen Capture"

        private var instance: ScreenCaptureService? = null
        private var mediaProjection: MediaProjection? = null

        fun isRunning(): Boolean = instance != null

        fun startService(context: Context, resultCode: Int, data: Intent) {
            val intent = Intent(context, ScreenCaptureService::class.java).apply {
                putExtra("resultCode", resultCode)
                putExtra("data", data)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopService(context: Context) {
            // Detener MediaProjection antes de detener el servicio
            releaseMediaProjection()

            val intent = Intent(context, ScreenCaptureService::class.java)
            context.stopService(intent)
        }

        fun getMediaProjection(): MediaProjection? = mediaProjection

        // Método para liberar MediaProjection de forma segura
        fun releaseMediaProjection() {
            try {
                Log.d(TAG, "Releasing MediaProjection...")

                mediaProjection?.let { projection ->
                    try {
                        // Intentar detener el projection
                        projection.stop()
                        Log.d(TAG, "MediaProjection.stop() called successfully")
                    } catch (e: Exception) {
                        Log.e(TAG, "Error calling MediaProjection.stop()", e)
                    }
                }

                // Limpiar referencia
                mediaProjection = null

                // Forzar garbage collection (ayuda a liberar Surface)
                System.gc()

                Log.d(TAG, "MediaProjection released, GC requested")
            } catch (e: Exception) {
                Log.e(TAG, "Error releasing MediaProjection", e)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.d(TAG, "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service started")

        // Crear canal de notificación
        createNotificationChannel()

        // Iniciar foreground service con tipo mediaProjection (Android 10+)
        val notification = createNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ requiere especificar el tipo de servicio
            startForeground(
                NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            )
            Log.d(TAG, "Foreground service started with MEDIA_PROJECTION type")
        } else {
            startForeground(NOTIFICATION_ID, notification)
            Log.d(TAG, "Foreground service started (legacy)")
        }

        // Inicializar MediaProjection
        intent?.let {
            val resultCode = it.getIntExtra("resultCode", -1)
            val data = it.getParcelableExtra<Intent>("data")

            if (resultCode != -1 && data != null) {
                initMediaProjection(resultCode, data)
            }
        }

        return START_STICKY
    }

    private fun initMediaProjection(resultCode: Int, data: Intent) {
        try {
            val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            mediaProjection = projectionManager.getMediaProjection(resultCode, data)

            mediaProjection?.registerCallback(object : MediaProjection.Callback() {
                override fun onStop() {
                    Log.d(TAG, "MediaProjection callback: onStop - waiting for Surface release...")

                    // Limpiar la referencia
                    mediaProjection = null

                    // DELAY LARGO: dar tiempo suficiente para que Flutter libere el Surface
                    android.os.Handler(mainLooper).postDelayed({
                        Log.d(TAG, "Stopping service after delay")
                        stopSelf()
                    }, 1000) // 1 segundo de delay (aumentado de 300ms)
                }
            }, null)

            Log.d(TAG, "MediaProjection initialized successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing MediaProjection", e)
            stopSelf()
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Canal para control remoto de pantalla"
                setShowBadge(false)
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Control Remoto Activo")
            .setContentText("Capturando pantalla...")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        Log.d(TAG, "Service destroying - cleaning up resources")

        try {
            // Detener MediaProjection primero
            mediaProjection?.let {
                it.stop()
                Log.d(TAG, "MediaProjection stopped")
            }
            mediaProjection = null

            // Limpiar instancia
            instance = null

            // Detener foreground
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }

            Log.d(TAG, "Service destroyed successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error during service cleanup", e)
        }

        super.onDestroy()
    }
}

