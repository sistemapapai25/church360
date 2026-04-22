package com.rgagroup.church360_app

import android.util.Log
import com.llfbandit.app_links.AppLinksPlugin
import com.llfbandit.record.RecordPlugin
import com.pichillilorenzo.flutter_inappwebview_android.InAppWebViewFlutterPlugin
import dev.fluttercommunity.plus.share.SharePlusPlugin
import dev.steenbakker.mobile_scanner.MobileScannerPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugins.flutter_plugin_android_lifecycle.FlutterAndroidLifecyclePlugin
import io.flutter.plugins.imagepicker.ImagePickerPlugin
import io.flutter.plugins.pathprovider.PathProviderPlugin
import io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin
import io.flutter.plugins.urllauncher.UrlLauncherPlugin
import io.flutter.plugins.webviewflutter.WebViewFlutterPlugin
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
        registerPlugin(flutterEngine, WebViewFlutterPlugin())
        registerFilePickerPlugin(flutterEngine)
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
