package com.example.lisku

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TermuxBridge.CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getStatus" -> result.success(
                        mapOf(
                            "installed" to TermuxBridge.isTermuxInstalled(this),
                            "permissionGranted" to hasRunCommandPermission(),
                            "canAskPermission" to canAskPermission(),
                        )
                    )
                    "requestPermission" -> requestRunCommandPermission(result)
                    "runCommand" -> TermuxBridge.runCommand(this, call, result)
                    "openTermux" -> result.success(TermuxBridge.openTermux(this))
                    "openAppSettings" -> {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            .setData(Uri.fromParts("package", packageName, null))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasRunCommandPermission(): Boolean =
        checkSelfPermission(TermuxBridge.PERMISSION) == PackageManager.PERMISSION_GRANTED

    // False berarti user memilih "jangan tanya lagi" (atau belum pernah ditanya,
    // jadi hanya dipakai setelah permintaan pertama ditolak).
    private fun canAskPermission(): Boolean =
        shouldShowRequestPermissionRationale(TermuxBridge.PERMISSION)

    private fun requestRunCommandPermission(result: MethodChannel.Result) {
        if (hasRunCommandPermission()) {
            result.success(true)
            return
        }
        if (!TermuxBridge.isTermuxInstalled(this)) {
            result.error("TERMUX_NOT_INSTALLED", "Termux belum terinstall", null)
            return
        }
        pendingPermissionResult?.success(false)
        pendingPermissionResult = result
        requestPermissions(arrayOf(TermuxBridge.PERMISSION), REQUEST_RUN_COMMAND)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_RUN_COMMAND) return
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
    }

    companion object {
        private const val REQUEST_RUN_COMMAND = 4120
    }
}
