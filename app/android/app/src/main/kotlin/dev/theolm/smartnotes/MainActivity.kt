package dev.theolm.smartnotes

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.StatFs
import android.content.Intent
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : FlutterFragmentActivity() {
    private var notificationResult: MethodChannel.Result? = null
    private var processingChannel: MethodChannel? = null
    private var pendingEntryId: String? = null
    private var preparedUpdate: Triple<String, Long, Long>? = null

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        openEntryFrom(intent)
    }

    private fun openEntryFrom(intent: Intent?) {
        if (intent?.action != ProcessingNotifications.OPEN_ENTRY) return
        val entryId = intent.getStringExtra(ProcessingNotifications.ENTRY_ID) ?: return
        val channel = processingChannel
        if (channel == null) pendingEntryId = entryId
        else channel.invokeMethod("openEntry", entryId)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 85) {
            notificationResult?.success(grantResults.firstOrNull() == android.content.pm.PackageManager.PERMISSION_GRANTED)
            notificationResult = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val updates = AppUpdates(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.theolm.smartnotes/app_updates")
            .setMethodCallHandler { call, result ->
                lifecycleScope.launch {
                    try {
                        when (call.method) {
                            "abi" -> {
                                val supported = Build.SUPPORTED_ABIS.filter {
                                    if (android.os.Process.is64Bit()) it in setOf("arm64-v8a", "x86_64")
                                    else it in setOf("armeabi-v7a", "x86")
                                }
                                result.success(supported.firstOrNull())
                            }
                            "status" -> result.success(withContext(Dispatchers.IO) { updates.status() })
                            "start" -> { withContext(Dispatchers.IO) { updates.start(org.json.JSONObject(call.arguments as Map<*, *>)) }; result.success(null) }
                            "cancel" -> { withContext(Dispatchers.IO) { updates.cancel() }; result.success(null) }
                            "takeOpen" -> {
                                val open = intent?.getBooleanExtra("open_app_updates", false) == true
                                intent?.removeExtra("open_app_updates")
                                result.success(open)
                            }
                            "prepareInstall" -> {
                                preparedUpdate = withContext(Dispatchers.IO) {
                                    val record = updates.record() ?: error("missingUpdate")
                                    val file = updates.file(record)
                                    try { updates.validate(record, file) }
                                    catch (error: Exception) { updates.update(record.getString("token"), "failed"); throw error }
                                    Triple(record.getString("token"), file.length(), file.lastModified())
                                }
                                result.success(null)
                            }
                            "install" -> {
                                // Guard the final platform boundary too: Flutter's
                                // lifecycle can change while the channel call is queued.
                                require(lifecycle.currentState.isAtLeast(androidx.lifecycle.Lifecycle.State.RESUMED)) { "appNotResumed" }
                                val record = updates.record() ?: error("missingUpdate")
                                val file = updates.file(record)
                                require(preparedUpdate == Triple(record.getString("token"), file.length(), file.lastModified()))
                                preparedUpdate = null
                                updates.install(this@MainActivity)
                                result.success(null)
                            }
                            else -> result.notImplemented()
                        }
                    } catch (error: Exception) { result.error("app-update", error.message, null) }
                }
            }
        val downloads = ModelDownloads(applicationContext)
        val processing = ProcessingNotifications(applicationContext)
        openEntryFrom(intent)
        processingChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.theolm.smartnotes/processing_feedback",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "show" -> {
                            processing.show(call.arguments as Map<*, *>)
                            result.success(null)
                        }
                        "dismiss" -> {
                            processing.dismiss()
                            result.success(null)
                        }
                        "notificationsAllowed" -> result.success(
                            androidx.core.app.NotificationManagerCompat.from(this).areNotificationsEnabled()
                        )
                        "requestNotifications" -> {
                            if (Build.VERSION.SDK_INT < 33 || checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                                result.success(androidx.core.app.NotificationManagerCompat.from(this).areNotificationsEnabled())
                            } else if (notificationResult == null) {
                                notificationResult = result
                                requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 85)
                            } else {
                                result.error("busy", "Notification permission request is already open.", null)
                            }
                        }
                        "takePendingEntry" -> {
                            result.success(pendingEntryId)
                            pendingEntryId = null
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("processing-feedback", error.message, null)
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.theolm.smartnotes/model_downloads")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "status" -> result.success(downloads.status())
                        "start" -> {
                            downloads.start(org.json.JSONObject(call.arguments as Map<*, *>))
                            result.success(null)
                        }
                        "cancel" -> {
                            downloads.cancel(call.arguments as String)
                            result.success(null)
                        }
                        "notificationsAllowed" -> result.success(androidx.core.app.NotificationManagerCompat.from(this).areNotificationsEnabled())
                        "requestNotifications" -> {
                            if (Build.VERSION.SDK_INT < 33 || checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                                result.success(androidx.core.app.NotificationManagerCompat.from(this).areNotificationsEnabled())
                            } else if (notificationResult == null) {
                                notificationResult = result
                                requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 85)
                            } else {
                                result.error("busy", "Notification permission request is already open.", null)
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("model-download", error.message, null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.theolm.smartnotes/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "profile" -> {
                        val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        val memory = ActivityManager.MemoryInfo()
                        manager.getMemoryInfo(memory)
                        result.success(mapOf(
                            "memoryBytes" to memory.totalMem,
                            "lowMemory" to manager.isLowRamDevice,
                            "is64Bit" to android.os.Process.is64Bit(),
                            "processors" to Runtime.getRuntime().availableProcessors(),
                            "soc" to if (Build.VERSION.SDK_INT >= 31) Build.SOC_MODEL else Build.HARDWARE
                        ))
                    }
                    "freeStorage" -> result.success(StatFs(filesDir.absolutePath).availableBytes)
                    else -> result.notImplemented()
                }
            }
    }
}
