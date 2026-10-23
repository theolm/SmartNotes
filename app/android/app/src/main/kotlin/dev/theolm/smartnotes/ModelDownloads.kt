package dev.theolm.smartnotes

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.*
import java.io.File
import java.net.URL
import java.security.MessageDigest
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import okhttp3.Call
import okhttp3.OkHttpClient
import okhttp3.Request

/** Durable journal shared by the activity, worker and notification receiver. */
class ModelDownloads(private val context: Context) {
    private val preferences = context.getSharedPreferences("model_downloads", Context.MODE_PRIVATE)
    private val work = WorkManager.getInstance(context)

    private fun createChannel(record: JSONObject) {
        if (Build.VERSION.SDK_INT >= 26) {
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL, record.getJSONObject("notification").getString("channel"), NotificationManager.IMPORTANCE_LOW)
            )
        }
    }

    fun record(id: String): JSONObject? = synchronized(lock) {
        preferences.getString(id, null)?.let { JSONObject(it) }
    }

    fun status(): List<Map<String, Any?>> = synchronized(lock) {
        preferences.all.keys.mapNotNull { id -> record(id)?.let { json ->
            mapOf("id" to id, "state" to json.getString("state"),
                "received" to json.getLong("received"), "bytes" to json.getLong("bytes"),
                "token" to json.optString("token"),
                "verification" to json.optJSONObject("verification")?.let { receipt ->
                    receipt.keys().asSequence().associateWith { receipt.get(it) }
                },
                "error" to json.optString("error").takeUnless { it == "null" || it.isEmpty() },
                "retained" to File(context.filesDir, "${json.getString("folder")}/${json.getString("fileName")}.part").length())
        } }
    }

    fun save(record: JSONObject) = synchronized(lock) {
        check(preferences.edit().putString(record.getString("id"), record.toString()).commit())
    }

    fun <T> withAttempt(id: String, token: String, operation: () -> T): T = synchronized(lock) {
        val record = record(id)
        if (record == null || record.optString("token") != token || record.optString("state") == "cancelled") {
            throw java.util.concurrent.CancellationException()
        }
        operation()
    }

    fun update(id: String, state: String, received: Long? = null, error: String? = null, token: String? = null) = synchronized(lock) {
        val record = record(id) ?: return@synchronized
        // Cancellation is authoritative, even when racing a progress callback.
        if (record.optString("state") == "cancelled") return@synchronized
        if (token != null && record.optString("token") != token) return@synchronized
        record.put("state", state)
        received?.let { record.put("received", it) }
        record.put("error", error ?: JSONObject.NULL)
        save(record)
    }

    fun start(request: JSONObject) = synchronized(lock) {
        val id = request.getString("id")
        createChannel(request)
        require(request.getString("folder").matches(Regex("[a-z_]+")))
        require(File(request.getString("fileName")).name == request.getString("fileName"))
        require(URL(request.getString("url")).protocol == "https")
        require(request.getLong("bytes") > 0 && request.getString("sha256").matches(Regex("[a-f0-9]{64}")))
        val existing = record(id)
        val destination = File(context.filesDir, "${request.getString("folder")}/${request.getString("fileName")}")
        if (existing?.optString("state") == "completed" && !request.optBoolean("repair") &&
            destination.length() == request.getLong("bytes")) return@synchronized
        if (existing != null && existing.optString("state") in active) {
            // Re-enqueue KEEP also repairs death between persisting and enqueueing.
            enqueue(id)
            return@synchronized
        }
        check(status().none { it["state"] in active }) { "Another model is downloading." }
        val partial = File(context.filesDir, "${request.getString("folder")}/${request.getString("fileName")}.part")
        request.put("received", partial.length()).put("state", "queued").put("error", JSONObject.NULL)
            .put("token", java.util.UUID.randomUUID().toString())
        existing?.optString("token")?.let { oldToken ->
            calls.remove(oldToken)?.cancel()
        }
        save(request)
        context.getSystemService(NotificationManager::class.java).cancel(notificationId(id) xor 0x40000000)
        enqueue(id, replace = true)
    }

    private fun enqueue(id: String, replace: Boolean = false) {
        work.enqueueUniqueWork("model:$id", if (replace) ExistingWorkPolicy.REPLACE else ExistingWorkPolicy.KEEP,
            OneTimeWorkRequestBuilder<ModelDownloadWorker>()
                .setInputData(workDataOf("id" to id, "token" to record(id)!!.getString("token")))
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, java.util.concurrent.TimeUnit.SECONDS)
                .build())
    }

    fun cancel(id: String) = synchronized(lock) {
        val record = record(id)
        record?.let { save(it.put("state", "cancelled")) }
        work.cancelUniqueWork("model:$id")
        // Call.cancel is thread-safe and remembers cancellation before execute.
        record?.optString("token")?.let { token ->
            calls.remove(token)?.cancel()
        }
        record?.optString("token")?.let {
            context.getSystemService(NotificationManager::class.java).cancel(foregroundNotificationId(id, it))
        }
        context.getSystemService(NotificationManager::class.java).cancel(notificationId(id) xor 0x40000000)
    }

    fun notification(id: String, state: String, received: Long): Notification {
        val record = record(id)!!
        createChannel(record)
        val copy = record.getJSONObject("notification")
        val running = state in active
        val builder = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(record.getString("name"))
            .setContentText(copy.getString(if (state in setOf("completed", "failed", "verifying")) state else "running"))
            .setOnlyAlertOnce(true).setOngoing(running).setAutoCancel(!running)
        context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
            builder.setContentIntent(PendingIntent.getActivity(context, 0, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
        }
        if (running) {
            builder.setProgress(100, (received * 100 / record.getLong("bytes")).toInt().coerceIn(0, 100), state == "verifying")
            val intent = Intent(context, ModelDownloadCancelReceiver::class.java).putExtra("id", id)
            builder.addAction(0, copy.getString("cancel"), PendingIntent.getBroadcast(context, notificationId(id), intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
        }
        return builder.build()
    }

    fun complete(id: String, candidate: File, destination: File, token: String): Boolean = synchronized(lock) {
        val record = record(id) ?: return@synchronized false
        if (record.optString("state") == "cancelled" || record.optString("token") != token) return@synchronized false
        if (candidate != destination) check(candidate.renameTo(destination)) { "Could not install model." }
        record.put("verification", JSONObject().put("version", 1)
            .put("token", token).put("modelId", id)
            .put("folder", record.getString("folder")).put("fileName", record.getString("fileName"))
            .put("digest", record.getString("sha256")).put("size", destination.length())
            .put("modified", destination.lastModified()))
        save(record)
        update(id, "completed", record.getLong("bytes"))
        true
    }

    fun notifyEnd(id: String, state: String, bytes: Long) = synchronized(lock) {
        if (record(id)?.optString("state") != state) return@synchronized
        // Separate ID: WorkManager removes its foreground notification on exit.
        try {
            context.getSystemService(NotificationManager::class.java)
                .notify(notificationId(id) xor 0x40000000, notification(id, state, bytes))
        } catch (_: SecurityException) { /* Permission denial must not stop work. */ }
    }

    companion object {
        private val lock = Any()
        val calls = java.util.concurrent.ConcurrentHashMap<String, Call>()
        val active = setOf("queued", "downloading", "verifying")
        const val CHANNEL = "model_downloads"
        fun notificationId(id: String) = id.hashCode() and 0x3fffffff
        fun foregroundNotificationId(id: String, token: String) = (31 * id.hashCode() + token.hashCode()) and 0x3fffffff
    }
}

class ModelDownloadCancelReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        intent.getStringExtra("id")?.let { ModelDownloads(context).cancel(it) }
    }
}

/** No Flutter engine needed: transfer, verification and promotion survive death. */
class ModelDownloadWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    private val downloads = ModelDownloads(context)
    private var call: Call? = null
    private val id = inputData.getString("id")!!
    private val token = inputData.getString("token")!!

    private fun checkCancelled() {
        val record = downloads.record(id)
        if (isStopped || record?.optString("state") == "cancelled" || record?.optString("token") != token) {
            throw java.util.concurrent.CancellationException()
        }
    }

    private suspend fun foreground(state: String, bytes: Long) {
        checkCancelled()
        val notification = downloads.notification(id, state, bytes)
        val info = if (Build.VERSION.SDK_INT >= 29) {
            ForegroundInfo(ModelDownloads.foregroundNotificationId(id, token), notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else ForegroundInfo(ModelDownloads.foregroundNotificationId(id, token), notification)
        setForeground(info)
    }

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val record = downloads.record(id) ?: return@withContext Result.failure()
        if (record.optString("state") == "cancelled" || record.optString("token") != token) return@withContext Result.success()
        val total = record.getLong("bytes")
        val file = File(applicationContext.filesDir, "${record.getString("folder")}/${record.getString("fileName")}")
        val partial = File("${file.path}.part")
        // A previous process may have died after rename, before journaling completion.
        val promoted = record.optString("state") in setOf("verifying", "completed") &&
            !partial.exists() && file.length() == total
        val candidate = if (promoted) file else partial
        try {
            foreground("downloading", partial.length())
            file.parentFile!!.mkdirs()
            downloads.withAttempt(id, token) { if (partial.length() > total) partial.delete() }
            var received = partial.length()
            if (received < total && !promoted) {
                check(android.os.StatFs(applicationContext.filesDir.path).availableBytes >= total - received + 64L * 1024 * 1024) {
                    "Not enough storage for the model."
                }
                val request = Request.Builder().url(record.getString("url"))
                    .header("Accept-Encoding", "identity")
                if (received > 0) request.header("Range", "bytes=$received-")
                call = downloads.withAttempt(id, token) {
                    client.newCall(request.build()).also { ModelDownloads.calls[token] = it }
                }
                call!!.execute().use { response ->
                    val code = response.code
                    if (code == 200) received = 0
                    else check(code == 206 && response.header("Content-Range") == "bytes $received-${total - 1}/$total") {
                        "Invalid download response ($code)."
                    }
                    downloads.update(id, "downloading", received, token = token)
                    var lastUpdate = 0L
                    downloads.withAttempt(id, token) { java.io.FileOutputStream(partial, received > 0) }.use { output ->
                        (response.body ?: throw java.io.IOException("Empty response body.")).byteStream().use { input ->
                            val buffer = ByteArray(256 * 1024)
                            while (true) {
                                checkCancelled()
                                val count = input.read(buffer)
                                if (count < 0) break
                                checkCancelled()
                                received += count
                                check(received <= total) { "Invalid model size." }
                                downloads.withAttempt(id, token) { output.write(buffer, 0, count) }
                                if (System.currentTimeMillis() - lastUpdate > 500) {
                                    downloads.update(id, "downloading", received, token = token)
                                    foreground("downloading", received)
                                    lastUpdate = System.currentTimeMillis()
                                }
                            }
                            output.fd.sync()
                        }
                    }
                }
            }
            checkCancelled()
            downloads.update(id, "verifying", received, token = token)
            foreground("verifying", received)
            val digest = MessageDigest.getInstance("SHA-256")
            candidate.inputStream().use { input ->
                val buffer = ByteArray(1024 * 1024)
                while (true) {
                    checkCancelled()
                    val count = input.read(buffer)
                    if (count < 0) break
                    digest.update(buffer, 0, count)
                }
            }
            val hash = digest.digest().joinToString("") { "%02x".format(it) }
            if (candidate.length() != total || hash != record.getString("sha256")) {
                downloads.withAttempt(id, token) { candidate.delete() }
                throw IllegalStateException("Model integrity check failed. Download again.")
            }
            checkCancelled()
            if (!downloads.complete(id, candidate, file, token)) throw java.util.concurrent.CancellationException()
            downloads.notifyEnd(id, "completed", total)
            Result.success()
        } catch (cancelled: java.util.concurrent.CancellationException) {
            throw cancelled
        } catch (error: Exception) {
            if (isStopped || downloads.record(id)?.optString("state") == "cancelled" || downloads.record(id)?.optString("token") != token) return@withContext Result.success()
            if (error is java.io.IOException && runAttemptCount < 5) {
                downloads.update(id, "queued", partial.length(), token = token)
                Result.retry()
            } else {
                downloads.update(id, "failed", partial.length(), error.message ?: "Download failed.", token)
                downloads.notifyEnd(id, "failed", partial.length())
                Result.failure()
            }
        } finally {
            call?.let { ModelDownloads.calls.remove(token, it); it.cancel() }
        }
    }

    companion object {
        private val client = OkHttpClient.Builder()
            .connectTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
            .readTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
            .build()
    }
}
