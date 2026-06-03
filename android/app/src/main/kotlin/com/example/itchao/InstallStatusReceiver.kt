package com.example.itchao

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import android.util.Log

/** Receives commit status from [ApkInstaller] PackageInstaller sessions. */
class InstallStatusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
        val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
        when (status) {
            PackageInstaller.STATUS_SUCCESS -> {
                Log.i(TAG, "APK install session succeeded")
                val gameId = intent.getIntExtra(ApkInstaller.EXTRA_GAME_ID, -1)
                val packageName =
                    intent.getStringExtra(ApkInstaller.EXTRA_PACKAGE_NAME)
                        ?: intent.getStringExtra(PackageInstaller.EXTRA_PACKAGE_NAME)
                InstallEventBridge.emitInstallSuccess(gameId, packageName)
            }
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                val confirm =
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(Intent.EXTRA_INTENT)
                    }
                if (confirm != null) {
                    confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(confirm)
                }
            }
            else -> Log.w(TAG, "APK install session failed: $status $message")
        }
    }

    companion object {
        private const val TAG = "ItchaoInstall"
    }
}
