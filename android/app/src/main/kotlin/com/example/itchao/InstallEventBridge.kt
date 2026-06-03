package com.example.itchao

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

/** Sends PackageInstaller session results to Flutter. */
object InstallEventBridge {
    private var channel: MethodChannel? = null

    fun attach(channel: MethodChannel) {
        this.channel = channel
    }

    fun emitInstallSuccess(gameId: Int, packageName: String?) {
        if (gameId <= 0) {
            return
        }
        val payload =
            mapOf(
                "gameId" to gameId,
                "package" to packageName,
            )
        Handler(Looper.getMainLooper()).post {
            channel?.invokeMethod("installSuccess", payload)
        }
    }
}
