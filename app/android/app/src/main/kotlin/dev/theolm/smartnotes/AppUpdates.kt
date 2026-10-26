package dev.theolm.smartnotes

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.content.FileProvider
import androidx.work.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.TimeUnit

/** App-owned update files and durable state, intentionally separate from models. */
class AppUpdates(private val context: Context) {
    private val prefs = context.getSharedPreferences("app_updates", Context.MODE_PRIVATE)
    private val work = WorkManager.getInstance(context)
    private val folder get() = File(context.filesDir, "app_updates").apply { mkdirs() }
    fun file(record: JSONObject) = File(folder, "${record.getString("token")}.apk")
    fun partial(record: JSONObject) = File(folder, "${record.getString("token")}.part")
    fun record(): JSONObject? = synchronized(lock) { prefs.getString("record", null)?.let { JSONObject(it) } }
    private fun save(record: JSONObject) { check(prefs.edit().putString("record", record.toString()).commit()) }

    fun update(token: String, state: String, received: Long? = null): Boolean = synchronized(lock) {
        val current = record() ?: return@synchronized false
        if (current.optString("token") != token || current.optString("state") == "cancelled") return@synchronized false
        current.put("state", state)
        received?.let { current.put("received", it) }
        save(current)
        true
    }

    fun status(): Map<String, Any?> = synchronized(lock) {
        val r = record() ?: return@synchronized mapOf("state" to "idle")
        val installed = context.packageManager.getPackageInfo(context.packageName, 0).versionName
        if (alreadyInstalled(r.getString("version"), installed)) {
            work.cancelUniqueWork(WORK)
            file(r).delete(); partial(r).delete()
            prefs.edit().remove("record").commit()
            context.getSystemService(NotificationManager::class.java).cancel(NOTIFICATION)
            context.getSystemService(NotificationManager::class.java).cancel(NOTIFICATION + 1)
            return@synchronized mapOf("state" to "idle")
        }
        // Repair process death between saving the request and enqueueing work.
        if (r.optString("state") in setOf("queued", "downloading", "verifying")) enqueue(r, ExistingWorkPolicy.KEEP)
        mapOf("state" to r.getString("state"), "version" to r.getString("version"),
            "progress" to (r.optLong("received").toDouble() / r.getLong("bytes")).coerceIn(0.0, 1.0))
    }

    private fun alreadyInstalled(version: String, installed: String?): Boolean {
        val pattern = Regex("([0-9]+)\\.([0-9]+)\\.([0-9]+)")
        val current = pattern.matchEntire(installed?.substringBefore('+') ?: "") ?: return false
        val candidate = pattern.matchEntire(version) ?: return false
        for (index in 1..3) {
            val a = current.groupValues[index].toLongOrNull() ?: return false
            val b = candidate.groupValues[index].toLongOrNull() ?: return false
            if (a != b) return a > b
        }
        return true
    }

    fun start(request: JSONObject) = synchronized(lock) {
        val uri = Uri.parse(request.getString("url"))
        require(uri.scheme == "https" && uri.host == "github.com" &&
            uri.path?.startsWith("/theolm/SmartNotes/releases/download/") == true && uri.userInfo == null)
        require(request.getLong("bytes") > 0)
        require(request.getString("sha256").matches(Regex("[a-f0-9]{64}")))
        require(request.getString("version").matches(Regex("[0-9]+\\.[0-9]+\\.[0-9]+")))
        val old = record()
        if (old != null && old.optString("state") in setOf("queued", "downloading", "verifying")) {
            if (old.optString("version") == request.getString("version")) return@synchronized
            cancel()
        }
        if (old != null && old.optString("version") == request.getString("version") &&
            old.optString("state") == "ready" && file(old).exists()) return@synchronized
        old?.let { file(it).delete(); partial(it).delete() }
        context.getSystemService(NotificationManager::class.java).cancel(NOTIFICATION + 1)
        request.put("token", UUID.randomUUID().toString()).put("state", "queued").put("received", 0)
        save(request)
        val strings = request.getJSONObject("notification")
        if (Build.VERSION.SDK_INT >= 26) {
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL, strings.getString("channel"), NotificationManager.IMPORTANCE_LOW))
        }
        enqueue(request, ExistingWorkPolicy.REPLACE)
    }

    private fun enqueue(request: JSONObject, policy: ExistingWorkPolicy) {
        work.enqueueUniqueWork(WORK, policy,
            OneTimeWorkRequestBuilder<AppUpdateWorker>()
                .setInputData(workDataOf("token" to request.getString("token")))
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS).build())
    }

    fun notifyTerminal(token: String, state: String) = synchronized(lock) {
        val current = record() ?: return@synchronized
        if (current.optString("token") == token && current.optString("state") == state) {
            // Notification denial must never turn a verified download into a failure.
            runCatching { context.getSystemService(NotificationManager::class.java)
                .notify(NOTIFICATION + 1, notification(current, state)) }
        }
    }

    fun cancel() = synchronized(lock) {
        record()?.let { save(it.put("state", "cancelled")); partial(it).delete(); file(it).delete() }
        work.cancelUniqueWork(WORK)
        context.getSystemService(NotificationManager::class.java).cancel(NOTIFICATION)
        context.getSystemService(NotificationManager::class.java).cancel(NOTIFICATION + 1)
    }

    fun promote(token: String, received: Long): Boolean = synchronized(lock) {
        val current = record() ?: return@synchronized false
        if (current.optString("token") != token || current.optString("state") == "cancelled") return@synchronized false
        check(partial(current).renameTo(file(current)))
        update(token, "ready", received)
    }

    fun notification(r: JSONObject, state: String): android.app.Notification {
        val strings = r.getJSONObject("notification")
        val active = state in setOf("queued", "downloading", "verifying")
        val open = context.packageManager.getLaunchIntentForPackage(context.packageName)!!
            .putExtra("open_app_updates", true)
        val builder = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle(strings.getString("title"))
            .setContentText(strings.getString(if (state == "queued") "downloading" else state))
            .setOnlyAlertOnce(true).setOngoing(active).setAutoCancel(!active)
            .setContentIntent(PendingIntent.getActivity(context, NOTIFICATION, open,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
        if (active) {
            builder.setProgress(100, (r.optLong("received") * 100 / r.getLong("bytes")).toInt().coerceIn(0, 100), state == "verifying")
            builder.addAction(0, strings.getString("cancel"), PendingIntent.getBroadcast(context, NOTIFICATION,
                Intent(context, AppUpdateCancelReceiver::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
        }
        return builder.build()
    }

    @Suppress("DEPRECATION")
    fun validate(r: JSONObject, apk: File) {
        require(apk.length() == r.getLong("bytes")) { "size" }
        val digest = MessageDigest.getInstance("SHA-256")
        apk.inputStream().buffered().use { input ->
            val buffer = ByteArray(128 * 1024)
            while (true) { val n = input.read(buffer); if (n < 0) break; digest.update(buffer, 0, n) }
        }
        require(digest.digest().joinToString("") { "%02x".format(it) } == r.getString("sha256")) { "checksum" }
        val flags = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
        val archive = context.packageManager.getPackageArchiveInfo(apk.path, flags) ?: error("invalidApk")
        val installed = context.packageManager.getPackageInfo(context.packageName, flags)
        require(archive.packageName == context.packageName && archive.versionName == r.getString("version")) { "package" }
        val remoteCode = if (Build.VERSION.SDK_INT >= 28) archive.longVersionCode else archive.versionCode.toLong()
        val localCode = if (Build.VERSION.SDK_INT >= 28) installed.longVersionCode else installed.versionCode.toLong()
        require(remoteCode > localCode) { "downgrade" }
        fun signatures(info: android.content.pm.PackageInfo): Set<String> {
            val signatures = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners else info.signatures
            return signatures.orEmpty().map { it.toCharsString() }.toSet()
        }
        val currentSigners = signatures(installed)
        require(currentSigners.isNotEmpty() && signatures(archive) == currentSigners) { "signature" }
        // The OS installer independently verifies APK signatures before committing.
    }

    fun install(activity: android.app.Activity) {
        val r = record() ?: error("missingUpdate")
        require(r.getString("state") == "ready")
        if (Build.VERSION.SDK_INT >= 26 && !context.packageManager.canRequestPackageInstalls()) {
            activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${context.packageName}")))
            error("installPermissionRequired")
        }
        // Validation is performed again off the UI thread before reaching here.
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.app_updates", file(r))
        activity.startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
    }

    companion object {
        private val lock = Any()
        const val WORK = "app-update"
        const val CHANNEL = "app-updates"
        const val NOTIFICATION = 7301
    }
}

class AppUpdateCancelReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) { AppUpdates(context).cancel() }
}

class AppUpdateWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val updates = AppUpdates(applicationContext)
        val token = inputData.getString("token") ?: return@withContext Result.failure()
        val r = updates.record() ?: return@withContext Result.failure()
        if (r.getString("token") != token || r.getString("state") == "cancelled") return@withContext Result.success()
        val partial = updates.partial(r)
        try {
            val notification = updates.notification(r, "downloading")
            setForeground(if (Build.VERSION.SDK_INT >= 29) ForegroundInfo(AppUpdates.NOTIFICATION, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
                else ForegroundInfo(AppUpdates.NOTIFICATION, notification))
            check(updates.update(token, "downloading"))
            val expected = r.getLong("bytes")
            if (partial.length() > expected) partial.delete()
            require(android.os.StatFs(partial.parentFile!!.path).availableBytes >=
                (expected - partial.length()).coerceAtLeast(0) + 10L * 1024 * 1024) { "storage" }
            var received = partial.length()
            if (received < expected) {
                val client = OkHttpClient.Builder().followSslRedirects(false)
                    .connectTimeout(30, TimeUnit.SECONDS).readTimeout(60, TimeUnit.SECONDS).build()
                val request = Request.Builder().url(r.getString("url"))
                    .header("Accept-Encoding", "identity")
                    .apply { if (received > 0) header("Range", "bytes=$received-") }.build()
                val call = client.newCall(request)
                try {
                    call.execute().use { response ->
                        require(response.isSuccessful) { "http" }
                        val append = received > 0 && response.code == 206
                        if (append) require(response.header("Content-Range")?.startsWith("bytes $received-") == true)
                        else { require(response.code == 200); received = 0 }
                        val body = response.body
                        body.byteStream().use { input ->
                            java.io.FileOutputStream(partial, append).use { output ->
                                val buffer = ByteArray(128 * 1024)
                                var last = 0L
                                while (true) {
                                    if (isStopped || updates.record()?.optString("state") == "cancelled" || updates.record()?.optString("token") != token)
                                        throw kotlinx.coroutines.CancellationException()
                                    val count = input.read(buffer)
                                    if (count < 0) break
                                    received += count
                                    require(received <= expected) { "size" }
                                    output.write(buffer, 0, count)
                                    if (System.currentTimeMillis() - last > 1000) {
                                        if (!updates.update(token, "downloading", received)) throw kotlinx.coroutines.CancellationException()
                                        r.put("received", received)
                                        val current = updates.notification(r, "downloading")
                                        setForeground(if (Build.VERSION.SDK_INT >= 29) ForegroundInfo(AppUpdates.NOTIFICATION, current, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
                                            else ForegroundInfo(AppUpdates.NOTIFICATION, current))
                                        last = System.currentTimeMillis()
                                    }
                                }
                            }
                        }
                    }
                } finally { call.cancel(); client.connectionPool.evictAll(); client.dispatcher.executorService.shutdown() }
            }
            if (partial.length() < expected) throw java.io.IOException("incomplete")
            check(updates.update(token, "verifying", received))
            updates.validate(r, partial)
            if (isStopped || updates.record()?.optString("token") != token || updates.record()?.optString("state") == "cancelled")
                throw kotlinx.coroutines.CancellationException()
            if (!updates.promote(token, received)) return@withContext Result.success()
            // WorkManager removes its foreground notification. A separate ID survives it.
            updates.notifyTerminal(token, "ready")
            Result.success()
        } catch (cancelled: kotlinx.coroutines.CancellationException) {
            if (updates.record()?.optString("state") == "cancelled") partial.delete()
            throw cancelled
        } catch (error: Exception) {
            if (error is java.io.IOException && runAttemptCount < 4) {
                updates.update(token, "queued", partial.length())
                Result.retry()
            } else {
                partial.delete()
                if (updates.update(token, "failed")) {
                    updates.notifyTerminal(token, "failed")
                }
                Result.failure()
            }
        }
    }
}
