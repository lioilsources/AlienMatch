package com.ol1n.alienmatch

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var flyby: FlybyRadio? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flyby = FlybyRadio(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
