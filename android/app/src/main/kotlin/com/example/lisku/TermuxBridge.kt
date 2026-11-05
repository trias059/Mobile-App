package com.example.lisku

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

/**
 * Jembatan ke Termux lewat RUN_COMMAND intent.
 * Dokumentasi: https://github.com/termux/termux-app/wiki/RUN_COMMAND-Intent
 *
 * Hasil eksekusi dikirim balik oleh Termux lewat PendingIntent ke
 * [TermuxResultReceiver], lalu diteruskan ke Dart sebagai hasil `runCommand`.
 */
object TermuxBridge {
    const val CHANNEL = "com.example.lisku/termux"
    const val PERMISSION = "com.termux.permission.RUN_COMMAND"

    private const val TERMUX_PACKAGE = "com.termux"
    private const val RUN_COMMAND_SERVICE = "com.termux.app.RunCommandService"
    private const val ACTION_RUN_COMMAND = "com.termux.RUN_COMMAND"

    private const val EXTRA_PATH = "com.termux.RUN_COMMAND_PATH"
    private const val EXTRA_ARGUMENTS = "com.termux.RUN_COMMAND_ARGUMENTS"
    private const val EXTRA_WORKDIR = "com.termux.RUN_COMMAND_WORKDIR"
    private const val EXTRA_BACKGROUND = "com.termux.RUN_COMMAND_BACKGROUND"
    private const val EXTRA_SESSION_ACTION = "com.termux.RUN_COMMAND_SESSION_ACTION"
    private const val EXTRA_LABEL = "com.termux.RUN_COMMAND_COMMAND_LABEL"
    private const val EXTRA_DESCRIPTION = "com.termux.RUN_COMMAND_COMMAND_DESCRIPTION"
    private const val EXTRA_PENDING_INTENT = "com.termux.RUN_COMMAND_PENDING_INTENT"

    // Kunci bundle hasil dari Termux (TermuxConstants.TERMUX_SERVICE).
    private const val RESULT_BUNDLE = "result"
    const val EXTRA_EXECUTION_ID = "lisku_execution_id"

    private val nextId = AtomicInteger(1000)
    private val pendingResults = ConcurrentHashMap<Int, MethodChannel.Result>()
    private val mainHandler = Handler(Looper.getMainLooper())

    fun isTermuxInstalled(context: Context): Boolean = try {
        context.packageManager.getPackageInfo(TERMUX_PACKAGE, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    fun openTermux(context: Context): Boolean {
        val intent = context.packageManager.getLaunchIntentForPackage(TERMUX_PACKAGE)
            ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        return true
    }

    fun runCommand(context: Context, call: MethodCall, result: MethodChannel.Result) {
        if (!isTermuxInstalled(context)) {
            result.error("TERMUX_NOT_INSTALLED", "Termux belum terinstall", null)
            return
        }

        val path = call.argument<String>("path") ?: "/data/data/com.termux/files/usr/bin/bash"
        val arguments = call.argument<List<String>>("arguments") ?: emptyList()
        val background = call.argument<Boolean>("background") ?: true
        val waitForResult = call.argument<Boolean>("waitForResult") ?: true
        val executionId = nextId.incrementAndGet()

        val intent = Intent().apply {
            component = ComponentName(TERMUX_PACKAGE, RUN_COMMAND_SERVICE)
            action = ACTION_RUN_COMMAND
            putExtra(EXTRA_PATH, path)
            putExtra(EXTRA_ARGUMENTS, arguments.toTypedArray())
            putExtra(EXTRA_WORKDIR, call.argument<String>("workdir") ?: "/data/data/com.termux/files/home")
            putExtra(EXTRA_BACKGROUND, background)
            call.argument<String>("sessionAction")?.let { putExtra(EXTRA_SESSION_ACTION, it) }
            call.argument<String>("label")?.let { putExtra(EXTRA_LABEL, it) }
            call.argument<String>("description")?.let { putExtra(EXTRA_DESCRIPTION, it) }
        }

        if (waitForResult) {
            val resultIntent = Intent(context, TermuxResultReceiver::class.java)
                .putExtra(EXTRA_EXECUTION_ID, executionId)
            var flags = PendingIntent.FLAG_ONE_SHOT
            // Termux perlu menambahkan extras hasil, jadi PendingIntent harus mutable.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) flags = flags or PendingIntent.FLAG_MUTABLE
            val pendingIntent = PendingIntent.getBroadcast(context, executionId, resultIntent, flags)
            intent.putExtra(EXTRA_PENDING_INTENT, pendingIntent)
            pendingResults[executionId] = result
        }

        try {
            try {
                context.startService(intent)
            } catch (e: IllegalStateException) {
                // Aplikasi sedang di background: Android 8+ butuh startForegroundService.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    throw e
                }
            }
            if (!waitForResult) result.success(mapOf("sent" to true))
        } catch (e: SecurityException) {
            pendingResults.remove(executionId)
            result.error("PERMISSION_DENIED", e.message ?: "Izin RUN_COMMAND ditolak", null)
        } catch (e: Exception) {
            pendingResults.remove(executionId)
            result.error("START_FAILED", e.message ?: e.toString(), null)
        }
    }

    fun deliverResult(intent: Intent) {
        val executionId = intent.getIntExtra(EXTRA_EXECUTION_ID, -1)
        val result = pendingResults.remove(executionId) ?: return
        val bundle = intent.getBundleExtra(RESULT_BUNDLE)
        val payload = mapOf(
            "sent" to true,
            "stdout" to (bundle?.getString("stdout") ?: ""),
            "stderr" to (bundle?.getString("stderr") ?: ""),
            "exitCode" to (bundle?.let { if (it.containsKey("exitCode")) it.getInt("exitCode") else null }),
            "err" to (bundle?.let { if (it.containsKey("err")) it.getInt("err") else null }),
            "errmsg" to (bundle?.getString("errmsg") ?: ""),
        )
        mainHandler.post { result.success(payload) }
    }
}

class TermuxResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        TermuxBridge.deliverResult(intent)
    }
}
