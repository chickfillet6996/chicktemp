package com.example.chicktemp

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val notificationBridge = "chicktemp/notifications"
    private val fileBridge = "chicktemp/files"
    private val alertChannelId = "chicktemp_alerts"
    private val notificationPermissionRequest = 4107

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationBridge)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> {
                        initializeNotifications()
                        result.success(null)
                    }
                    "showAlert" -> {
                        val id = call.argument<String>("id").orEmpty()
                        val title = call.argument<String>("title").orEmpty()
                        val body = call.argument<String>("body").orEmpty()
                        showAlertNotification(id, title, body)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, fileBridge)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "savePdfToDownloads" -> {
                        val fileName = call.argument<String>("fileName").orEmpty()
                        val bytes = call.argument<ByteArray>("bytes")
                        if (fileName.isBlank() || bytes == null) {
                            result.error("INVALID_PDF", "Missing PDF file name or bytes.", null)
                            return@setMethodCallHandler
                        }

                        try {
                            result.success(savePdfToDownloads(fileName, bytes))
                        } catch (error: Exception) {
                            result.error("SAVE_FAILED", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun initializeNotifications() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                alertChannelId,
                "ChickTemp Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Important ChickTemp farm alerts"
            }
            manager.createNotificationChannel(channel)
        }

        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                notificationPermissionRequest
            )
        }
    }

    private fun showAlertNotification(id: String, title: String, body: String) {
        initializeNotifications()
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)

        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
        val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, pendingFlags)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, alertChannelId)
        } else {
            Notification.Builder(this)
        }

        val notification = builder
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(title.ifBlank { "ChickTemp Alert" })
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(Notification.PRIORITY_HIGH)
            .build()

        manager.notify(stableNotificationId(id), notification)
    }

    private fun stableNotificationId(value: String): Int {
        var hash = 0
        value.forEach { char ->
            hash = (hash * 31 + char.code) and 0x7fffffff
        }
        return if (hash == 0) 1 else hash
    }

    private fun savePdfToDownloads(fileName: String, bytes: ByteArray): String {
        val resolver = contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
        }
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Downloads.EXTERNAL_CONTENT_URI
        } else {
            MediaStore.Files.getContentUri("external")
        }
        val uri = resolver.insert(collection, values)
            ?: throw IllegalStateException("Could not create download file.")

        resolver.openOutputStream(uri)?.use { output ->
            output.write(bytes)
        } ?: throw IllegalStateException("Could not open download file.")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        }

        return uri.toString()
    }
}
