package com.novatech.hellodimla

import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "hellodimla/app_info"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "info" -> {
                    try {
                        @Suppress("DEPRECATION")
                        val info = packageManager.getPackageInfo(
                            packageName,
                            0
                        )

                        @Suppress("DEPRECATION")
                        val build =
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                info.longVersionCode
                            } else {
                                info.versionCode.toLong()
                            }

                        result.success(
                            mapOf(
                                "version" to (info.versionName ?: ""),
                                "build" to build
                            )
                        )
                    } catch (e: Exception) {
                        result.error(
                            "PACKAGE_INFO",
                            e.message,
                            null
                        )
                    }
                }

                "closeAfterErase" -> {
                    // Dart has awaited every erase operation first.
                    result.success(null)

                    // Restarting later must create fresh Flutter/Firebase state.
                    Handler(Looper.getMainLooper()).postDelayed({
                        finishAndRemoveTask()
                        android.os.Process.killProcess(
                            android.os.Process.myPid()
                        )
                    }, 300)
                }

                else -> result.notImplemented()
            }
        }
    }
}