package dev.theolm.smartnotes

import java.io.File
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class AppUpdateRecoveryTest {
    @get:Rule val temporary = TemporaryFolder()

    @Test fun `promoted APK is reused after interruption before ready or worker success`() {
        for (persistedState in listOf("verifying", "ready")) {
            val apk = temporary.newFile("$persistedState.apk").apply { writeText("verified APK") }
            var state = persistedState
            val events = mutableListOf<String>()
            val recovered = recoverPromotedUpdate(apk,
                validate = { assertEquals("verified APK", it.readText()); events.add("validated") },
                publishReady = { state = "ready"; events.add("published") })
            assertTrue(recovered)
            assertEquals("ready", state)
            assertEquals(listOf("validated", "published"), events)
            assertTrue(apk.exists())
        }
    }

    @Test fun `partial file alone continues normal download recovery`() {
        temporary.newFile("update.part").writeText("partial")
        assertFalse(recoverPromotedUpdate(File(temporary.root, "update.apk"),
            validate = { fail("No final APK to validate") },
            publishReady = { fail("Partial APK must not be published") }))
    }

    @Test fun `invalid final APK is not published or silently downloaded again`() {
        val apk = temporary.newFile("invalid.apk")
        assertThrows(IllegalArgumentException::class.java) {
            recoverPromotedUpdate(apk,
                validate = { throw IllegalArgumentException("checksum") },
                publishReady = { fail("Invalid APK must not be published") })
        }
    }

    @Test fun `interruption during validation prevents publication`() {
        val apk = temporary.newFile("cancelled.apk")
        assertThrows(java.util.concurrent.CancellationException::class.java) {
            recoverPromotedUpdate(apk,
                validate = { throw java.util.concurrent.CancellationException() },
                publishReady = { fail("Cancelled validation must not publish") })
        }
    }
}
