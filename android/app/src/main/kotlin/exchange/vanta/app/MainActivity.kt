package exchange.vanta.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannels(listOf(
            NotificationChannel("risk", getString(R.string.push_channel_risk), NotificationManager.IMPORTANCE_HIGH),
            NotificationChannel("trade", getString(R.string.push_channel_trade), NotificationManager.IMPORTANCE_DEFAULT),
            NotificationChannel("account", getString(R.string.push_channel_account), NotificationManager.IMPORTANCE_DEFAULT),
            NotificationChannel("announce", getString(R.string.push_channel_announce), NotificationManager.IMPORTANCE_DEFAULT),
        ))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "exchange.vanta.app/push")
            .setMethodCallHandler { call, result ->
                if (call.method != "device") {
                    result.notImplemented()
                } else {
                    val info = if (Build.VERSION.SDK_INT >= 33) {
                        packageManager.getPackageInfo(packageName, android.content.pm.PackageManager.PackageInfoFlags.of(0))
                    } else {
                        @Suppress("DEPRECATION")
                        packageManager.getPackageInfo(packageName, 0)
                    }
                    result.success(mapOf("platform" to "android", "app_id" to packageName,
                        "app_version" to info.versionName))
                }
            }
    }
}
