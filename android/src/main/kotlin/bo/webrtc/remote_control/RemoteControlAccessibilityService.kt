package bo.webrtc.remote_control

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.plugin.common.MethodChannel

class RemoteControlAccessibilityService : AccessibilityService() {

    companion object {
        private var instance: RemoteControlAccessibilityService? = null
        private const val TAG = "RemoteAccessibility"

        fun getInstance(): RemoteControlAccessibilityService? = instance

        fun simulateTouch(x: Float, y: Float): Boolean {
            return instance?.performTouch(x, y) ?: false
        }

        fun simulateSwipe(x1: Float, y1: Float, x2: Float, y2: Float, duration: Long): Boolean {
            return instance?.performSwipe(x1, y1, x2, y2, duration) ?: false
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d(TAG, "Accessibility Service conectado")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // No necesitamos procesar eventos para control remoto
    }

    override fun onInterrupt() {
        Log.d(TAG, "Accessibility Service interrumpido")
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }

    private fun performTouch(x: Float, y: Float): Boolean {
        val path = Path()
        path.moveTo(x, y)

        val gestureBuilder = GestureDescription.Builder()
        gestureBuilder.addStroke(GestureDescription.StrokeDescription(path, 0, 50))

        return dispatchGesture(gestureBuilder.build(), object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                Log.d(TAG, "Toque simulado en ($x, $y)")
            }

            override fun onCancelled(gestureDescription: GestureDescription?) {
                Log.e(TAG, "Toque cancelado")
            }
        }, null)
    }

    private fun performSwipe(x1: Float, y1: Float, x2: Float, y2: Float, duration: Long): Boolean {
        val path = Path()
        path.moveTo(x1, y1)
        path.lineTo(x2, y2)

        val gestureBuilder = GestureDescription.Builder()
        gestureBuilder.addStroke(GestureDescription.StrokeDescription(path, 0, duration))

        return dispatchGesture(gestureBuilder.build(), object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                Log.d(TAG, "Swipe completado de ($x1, $y1) a ($x2, $y2)")
            }

            override fun onCancelled(gestureDescription: GestureDescription?) {
                Log.e(TAG, "Swipe cancelado")
            }
        }, null)
    }

    fun inputText(text: String): Boolean {
        return try {
            val rootNode = rootInActiveWindow
            if (rootNode == null) {
                Log.e(TAG, "No hay ventana activa")
                return false
            }

            val focusedNode = rootNode.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            if (focusedNode == null) {
                Log.e(TAG, "No hay campo de texto enfocado")
                rootNode.recycle()
                return false
            }

            val currentText = focusedNode.text?.toString() ?: ""
            var selStart = focusedNode.textSelectionStart
            var selEnd = focusedNode.textSelectionEnd
            if (selStart < 0) selStart = currentText.length
            if (selEnd < 0) selEnd = selStart
            if (selStart > selEnd) {
                val tmp = selStart
                selStart = selEnd
                selEnd = tmp
            }

            var newText = currentText
            var newCursor = selStart

            val key = text
            val isBackspace = key == "\b" || key == "\u0008" ||
                    key.equals("BACKSPACE", ignoreCase = true) ||
                    key.equals("KEYCODE_DEL", ignoreCase = true)
            val isForwardDelete = key.equals("DELETE", ignoreCase = true) ||
                    key.equals("FORWARD_DELETE", ignoreCase = true) ||
                    key.equals("KEYCODE_FORWARD_DEL", ignoreCase = true)

            if (selStart != selEnd) {
                // Si hay selección, Backspace/Delete eliminan la selección; cualquier otra tecla la reemplaza
                if (isBackspace || isForwardDelete) {
                    newText = currentText.removeRange(selStart, selEnd)
                    newCursor = selStart
                } else {
                    newText = currentText.substring(0, selStart) + text + currentText.substring(selEnd)
                    newCursor = selStart + text.length
                }
            } else if (isBackspace) {
                if (selStart > 0) {
                    newText = currentText.substring(0, selStart - 1) + currentText.substring(selStart)
                    newCursor = selStart - 1
                }
            } else if (isForwardDelete) {
                if (selStart < currentText.length) {
                    newText = currentText.substring(0, selStart) + currentText.substring(selStart + 1)
                    newCursor = selStart
                }
            } else {
                // Inserción simple en la posición del cursor
                newText = currentText.substring(0, selStart) + text + currentText.substring(selStart)
                newCursor = selStart + text.length
            }

            val setTextArgs = Bundle().apply {
                putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, newText)
            }
            val successText = focusedNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, setTextArgs)

            // Intentar posicionar el cursor en la nueva posición
            val setSelectionArgs = Bundle().apply {
                putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, newCursor)
                putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, newCursor)
            }
            val successSel = focusedNode.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, setSelectionArgs)

            // liberar recursos
            focusedNode.recycle()
            rootNode.recycle()

            if (successText && successSel) {
                Log.d(TAG, "Texto actualizado: $newText, cursor en $newCursor")
                true
            } else {
                Log.e(TAG, "No se pudo insertar/posicionar el texto")
                successText || successSel
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error al escribir texto: ${e.message}")
            false
        }
    }

    fun performBackButton(): Boolean {
        return performGlobalAction(GLOBAL_ACTION_BACK)
    }

    fun performHomeButton(): Boolean {
        return performGlobalAction(GLOBAL_ACTION_HOME)
    }

    fun performRecentApps(): Boolean {
        return performGlobalAction(GLOBAL_ACTION_RECENTS)
    }
}

