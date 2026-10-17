package com.rgagroup.church360_app

import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
import com.llfbandit.app_links.AppLinksPlugin
import com.llfbandit.record.RecordPlugin
import com.pichillilorenzo.flutter_inappwebview_android.InAppWebViewFlutterPlugin
import dev.fluttercommunity.plus.share.SharePlusPlugin
import dev.steenbakker.mobile_scanner.MobileScannerPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.flutter_plugin_android_lifecycle.FlutterAndroidLifecyclePlugin
import io.flutter.plugins.imagepicker.ImagePickerPlugin
import io.flutter.plugins.pathprovider.PathProviderPlugin
import io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin
import io.flutter.plugins.urllauncher.UrlLauncherPlugin
import net.nfet.flutter.printing.PrintingPlugin
import xyz.luan.audioplayers.AudioplayersPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        registerPlugin(flutterEngine, AppLinksPlugin())
        registerPlugin(flutterEngine, AudioplayersPlugin())
        registerPlugin(flutterEngine, InAppWebViewFlutterPlugin())
        registerPlugin(flutterEngine, FlutterAndroidLifecyclePlugin())
        registerPlugin(flutterEngine, ImagePickerPlugin())
        registerPlugin(flutterEngine, MobileScannerPlugin())
        registerPlugin(flutterEngine, PathProviderPlugin())
        registerPlugin(flutterEngine, PrintingPlugin())
        registerPlugin(flutterEngine, RecordPlugin())
        registerPlugin(flutterEngine, SharePlusPlugin())
        registerPlugin(flutterEngine, SharedPreferencesPlugin())
        registerPlugin(flutterEngine, UrlLauncherPlugin())
        registerFilePickerPlugin(flutterEngine)
        registerDndChannel(flutterEngine)
    }

    // "Nao perturbe" no culto (CultoSilence no Dart). Abaixo do Android 6
    // nao existe: responde como sem acesso.
    private fun registerDndChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "church360/dnd")
            .setMethodCallHandler { call, result ->
                val nm = getSystemService(NotificationManager::class.java)
                val ok = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && nm != null
                when (call.method) {
                    "granted" -> result.success(ok && nm!!.isNotificationPolicyAccessGranted)
                    "isOn" -> result.success(
                        ok && nm!!.currentInterruptionFilter >
                            NotificationManager.INTERRUPTION_FILTER_ALL,
                    )
                    "openSettings" -> {
                        if (ok) {
                            startActivity(
                                Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS),
                            )
                        }
                        result.success(null)
                    }
                    "set" -> {
                        if (!ok || !nm!!.isNotificationPolicyAccessGranted) {
                            result.success(false)
                        } else {
                            nm.setInterruptionFilter(
                                if (call.arguments == true) {
                                    NotificationManager.INTERRUPTION_FILTER_PRIORITY
                                } else {
                                    NotificationManager.INTERRUPTION_FILTER_ALL
                                },
                            )
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun registerPlugin(
        flutterEngine: FlutterEngine,
        plugin: FlutterPlugin,
    ) {
        if (flutterEngine.plugins.has(plugin::class.java)) return
        flutterEngine.plugins.add(plugin)
    }

    private fun registerFilePickerPlugin(flutterEngine: FlutterEngine) {
        try {
            val pluginClass =
                Class.forName("com.mr.flutter.plugin.filepicker.FilePickerPlugin")
            val plugin = pluginClass.getDeclaredConstructor().newInstance()
            if (plugin is FlutterPlugin &&
                !flutterEngine.plugins.has(plugin.javaClass)
            ) {
                flutterEngine.plugins.add(plugin)
            }
        } catch (error: Throwable) {
            Log.e(TAG, "Error registering plugin file_picker", error)
        }
    }

    companion object {
        private const val TAG = "MainActivity"
    }
}
