package com.example.itchao

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        InstallEventBridge.attach(MethodChannel(messenger, INSTALL_EVENTS_CHANNEL))
        MethodChannel(messenger, CHANNEL).setMethodCallHandler {
            call,
            result ->
            when (call.method) {
                "getApkPackageName" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.error("invalid", "path required", null)
                        return@setMethodCallHandler
                    }
                    @Suppress("DEPRECATION")
                    val info = packageManager.getPackageArchiveInfo(path, 0)
                    if (info != null) {
                        info.applicationInfo?.sourceDir = path
                        info.applicationInfo?.publicSourceDir = path
                    }
                    result.success(info?.packageName)
                }
                "canInstallPackages" -> {
                    result.success(ApkInstaller.ensureCanInstall(this))
                }
                "requestInstallPermission" -> {
                    ApkInstaller.openInstallPermissionSettings(this)
                    result.success(null)
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.error("invalid", "path required", null)
                        return@setMethodCallHandler
                    }
                    val gameId = call.argument<Int>("gameId") ?: -1
                    val packageName = call.argument<String>("package")
                    Thread {
                        try {
                            ApkInstaller.install(this, path, gameId, packageName)
                            Handler(Looper.getMainLooper()).post { result.success(null) }
                        } catch (e: Exception) {
                            val code =
                                if (e.message?.contains("настройках") == true) {
                                    "install_permission_required"
                                } else {
                                    "install_failed"
                                }
                            Handler(Looper.getMainLooper()).post {
                                result.error(code, e.message, null)
                            }
                        }
                    }.start()
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("package")
                    if (packageName.isNullOrEmpty()) {
                        result.error("invalid", "package required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        launchApp(packageName)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("launch_failed", e.message, null)
                    }
                }
                "isAppInstalled" -> {
                    val packageName = call.argument<String>("package")
                    if (packageName.isNullOrEmpty()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    result.success(isAppInstalled(packageName))
                }
                "listInstalledByItchao" -> {
                    val apps =
                        InstalledByItchaoScanner.list(this).map {
                            mapOf(
                                "package" to it.packageName,
                                "label" to it.label,
                            )
                        }
                    result.success(apps)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isAppInstalled(packageName: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, 0)
            }
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun launchApp(packageName: String) {
        if (!isAppInstalled(packageName)) {
            throw IllegalStateException("App not installed: $packageName")
        }
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)!!
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(launchIntent)
    }

    companion object {
        private const val CHANNEL = "com.example.itchao/apk"
        private const val INSTALL_EVENTS_CHANNEL = "com.example.itchao/install"
    }
}
