package com.example.itchao

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File
import java.io.IOException

/**
 * Installs APKs so Android records [Context.getPackageName] as the installing app.
 * Uses [PackageInstaller] sessions (preferred); falls back to [Intent.ACTION_INSTALL_PACKAGE].
 */
object ApkInstaller {
    fun ensureCanInstall(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return true
        }
        return context.packageManager.canRequestPackageInstalls()
    }

    fun openInstallPermissionSettings(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val intent =
            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        context.startActivity(intent)
    }

    @Throws(IOException::class)
    fun install(
        context: Context,
        apkPath: String,
        gameId: Int,
        packageName: String?,
    ) {
        if (!ensureCanInstall(context)) {
            openInstallPermissionSettings(context)
            throw IOException(
                "Разрешите установку приложений для itchao в настройках Android",
            )
        }

        val file = File(apkPath)
        if (!file.isFile) {
            throw IOException("APK not found: $apkPath")
        }

        try {
            installWithPackageInstaller(context, file, gameId, packageName)
        } catch (e: IOException) {
            throw e
        } catch (e: Exception) {
            installWithIntent(context, file)
        }
    }

    private fun installWithPackageInstaller(
        context: Context,
        file: File,
        gameId: Int,
        packageName: String?,
    ) {
        val packageInstaller = context.packageManager.packageInstaller
        val targetPackage = readArchivePackageName(context, file.absolutePath)

        val params =
            PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
                setSize(file.length())
                if (targetPackage != null) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        setAppPackageName(targetPackage)
                    }
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    setPackageSource(PackageInstaller.PACKAGE_SOURCE_DOWNLOADED_FILE)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val originating =
                        FileProvider.getUriForFile(
                            context,
                            "${context.packageName}.fileprovider",
                            file,
                        )
                    setOriginatingUri(originating)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    setInstallReason(PackageManager.INSTALL_REASON_USER)
                }
            }

        val sessionId = packageInstaller.createSession(params)
        val session = packageInstaller.openSession(sessionId)
        try {
            file.inputStream().use { input ->
                session.openWrite("base.apk", 0, file.length()).use { output ->
                    input.copyTo(output)
                    session.fsync(output)
                }
            }

            val callback =
                Intent(context, InstallStatusReceiver::class.java).apply {
                    action = ACTION_INSTALL_COMMIT
                    setPackage(context.packageName)
                    putExtra(EXTRA_GAME_ID, gameId)
                    if (!packageName.isNullOrBlank()) {
                        putExtra(EXTRA_PACKAGE_NAME, packageName)
                    }
                }
            val pendingFlags =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
            val statusReceiver =
                PendingIntent.getBroadcast(
                    context,
                    sessionId,
                    callback,
                    pendingFlags,
                )
            session.commit(statusReceiver.intentSender)
        } finally {
            session.close()
        }
    }

    private fun installWithIntent(context: Context, file: File) {
        val uri =
            FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                file,
            )
        val intent =
            Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
                data = uri
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
                    putExtra(Intent.EXTRA_RETURN_RESULT, false)
                }
            }
        context.startActivity(intent)
    }

    private fun readArchivePackageName(context: Context, path: String): String? {
        @Suppress("DEPRECATION")
        val info = context.packageManager.getPackageArchiveInfo(path, 0) ?: return null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            info.applicationInfo?.sourceDir = path
        } else {
            @Suppress("DEPRECATION")
            info.applicationInfo?.sourceDir = path
        }
        return info.packageName
    }

    const val ACTION_INSTALL_COMMIT = "com.example.itchao.INSTALL_COMMIT"
    const val EXTRA_GAME_ID = "com.example.itchao.EXTRA_GAME_ID"
    const val EXTRA_PACKAGE_NAME = "com.example.itchao.EXTRA_PACKAGE_NAME"
}
