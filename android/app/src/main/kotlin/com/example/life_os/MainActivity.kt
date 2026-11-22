package com.example.life_os

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private lateinit var graphDocuments: GraphDocuments

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        graphDocuments = GraphDocuments(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    @Deprecated("Activity results are delivered by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!::graphDocuments.isInitialized || !graphDocuments.onActivityResult(requestCode, resultCode, data)) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        if (::graphDocuments.isInitialized) graphDocuments.dispose()
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
