package dev.theolm.smartnotes

import java.io.File

/** Reconcile a promotion that completed before WorkManager recorded success. */
internal fun recoverPromotedUpdate(
    apk: File,
    validate: (File) -> Unit,
    publishReady: () -> Unit,
): Boolean {
    if (!apk.isFile) return false
    validate(apk)
    publishReady()
    return true
}
