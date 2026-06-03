package com.example.itchao

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build

data class ItchaoInstalledApp(
    val packageName: String,
    val label: String,
)

object InstalledByItchaoScanner {
    fun list(context: Context): List<ItchaoInstalledApp> {
        val pm = context.packageManager
        val self = context.packageName
        val packages =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getInstalledPackages(PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                pm.getInstalledPackages(0)
            }

        val result = mutableListOf<ItchaoInstalledApp>()
        for (info in packages) {
            val pkg = info.packageName
            if (pkg == self) {
                continue
            }
            val installer =
                when {
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.R -> {
                        try {
                            val source = pm.getInstallSourceInfo(pkg)
                            source.installingPackageName
                                ?: source.initiatingPackageName
                        } catch (_: Exception) {
                            null
                        }
                    }
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.N -> {
                        @Suppress("DEPRECATION")
                        pm.getInstallerPackageName(pkg)
                    }
                    else -> null
                }
            if (installer != self) {
                continue
            }
            val appInfo = info.applicationInfo ?: continue
            val label =
                pm.getApplicationLabel(appInfo)?.toString()?.trim().orEmpty().ifEmpty { pkg }
            result.add(ItchaoInstalledApp(packageName = pkg, label = label))
        }
        return result.sortedBy { it.label.lowercase() }
    }
}
