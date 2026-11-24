package com.example.life_os

import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var graphDocuments: GraphDocuments
    private var syncDevice: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        graphDocuments = GraphDocuments(this, messenger)
        syncDevice = MethodChannel(messenger, "pulse/sync_device").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "name") result.success(syncDeviceName())
                else result.notImplemented()
            }
        }
    }

    private fun syncDeviceName(): String {
        val configured = try {
            Settings.Global.getString(contentResolver, "device_name")?.trim()
        } catch (_: SecurityException) {
            null
        }
        if (!configured.isNullOrEmpty()) return configured
        val model = Build.MODEL.trim()
        val manufacturer = Build.MANUFACTURER.trim()
        return if (model.startsWith(manufacturer, ignoreCase = true)) model
        else listOf(manufacturer, model).filter { it.isNotEmpty() }.joinToString(" ")
    }

    @Deprecated("Activity results are delivered by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!::graphDocuments.isInitialized || !graphDocuments.onActivityResult(requestCode, resultCode, data)) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        syncDevice?.setMethodCallHandler(null)
        syncDevice = null
        if (::graphDocuments.isInitialized) graphDocuments.dispose()
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
