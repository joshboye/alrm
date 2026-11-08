package com.alrm.interval_alarms

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.ServiceCompat
import org.json.JSONObject
import java.time.LocalDate
import java.time.ZoneId

/**
 * Foreground service that owns a ringing alarm: alarm-stream audio, vibration,
 * full-screen notification, wake lock and the auto-silence timeout.
 * Ringing does not depend on the Flutter UI being alive.
 */
class AlarmService : Service() {
    private val h = Handler(Looper.getMainLooper())
    private var tones: TonePlayer? = null
    private var vibrator: Vibrator? = null
    private var wake: PowerManager.WakeLock? = null
    private var focus: AudioFocusRequest? = null
    private var restoreVolume = -1
    private var current: Fire? = null
    private var preview = false
    private val timeout = Runnable { onTimeout() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_RING -> {
                val f = intent.getStringExtra("fire")?.let { Fire.of(JSONObject(it)) }
                if (f == null) { stopRing(); return START_NOT_STICKY }
                ring(f, intent.getBooleanExtra("preview", false))
            }
            ACTION_STOP -> { finish("stop") }
            ACTION_SNOOZE -> { snooze() }
            ACTION_SKIP_REST -> { skipRest() }
            else -> {
                // Restarted by the system after being killed mid-ring: resume if still relevant.
                val r = Store.activeRing(this)
                if (r != null && System.currentTimeMillis() - r.optLong("at") < RING_MAX_MS) {
                    ring(Fire.of(r), r.optBoolean("preview"))
                } else { Store.setActiveRing(this, null); stopRing() }
            }
        }
        return START_STICKY
    }

    private fun ring(f: Fire, isPreview: Boolean) {
        val a = Store.alarm(this, f.alarmId)
        val label = a?.optString("label")?.takeIf { it.isNotBlank() } ?: "Alarm"
        // Must call startForeground promptly (within 5s of startForegroundService).
        val n = Notifs.ringing(this, label, f.at, isPreview)
        try {
            ServiceCompat.startForeground(this, Notifs.RING_ID, n,
                if (Build.VERSION.SDK_INT >= 29) ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK else 0)
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed", e)
        }

        // A new ring replaces any ring in progress.
        if (current != null && !preview) {
            current?.let { if (it.alarmId != f.alarmId || it.at != f.at) Notifs.missed(this, it, late = false) }
        }
        stopOutputs()
        current = f; preview = isPreview
        Store.setActiveRing(this, f.json().put("preview", isPreview))

        if (wake == null) {
            wake = getSystemService(PowerManager::class.java)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "alrm:ringing").apply { setReferenceCounted(false) }
        }
        wake?.acquire(RING_MAX_MS + 60_000)

        startAudio(a?.optString("sound") ?: "BEEP BEEP")
        if (a?.optBoolean("vib", true) != false) startVibration()

        h.removeCallbacks(timeout)
        h.postDelayed(timeout, if (isPreview) PREVIEW_MAX_MS else RING_MAX_MS)

        // Bring up the ringing UI directly too (works when we hold FSI / are in foreground).
        try { startActivity(Notifs.openAppIntent(this)) } catch (_: Exception) {}
        Bridge.emit("ringChanged", null)
    }

    private fun startAudio(sound: String) {
        val am = getSystemService(AudioManager::class.java)
        // Guarantee audibility: if the alarm volume is very low (or muted), raise it to half for this ring.
        try {
            val max = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            val cur = am.getStreamVolume(AudioManager.STREAM_ALARM)
            val floor = (max + 1) / 2
            if (cur < floor) { restoreVolume = cur; am.setStreamVolume(AudioManager.STREAM_ALARM, floor, 0) }
        } catch (e: Exception) { Log.w(TAG, "volume floor failed", e) }
        try {
            val attrs = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
            focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attrs).setOnAudioFocusChangeListener { }.build()
            am.requestAudioFocus(focus!!)
        } catch (_: Exception) {}
        tones = TonePlayer(this).also { it.play(sound) }
    }

    private fun startVibration() {
        val v = if (Build.VERSION.SDK_INT >= 31) getSystemService(VibratorManager::class.java).defaultVibrator
                else @Suppress("DEPRECATION") getSystemService(Vibrator::class.java)
        vibrator = v
        val effect = VibrationEffect.createWaveform(longArrayOf(0, 600, 400, 600, 900), 0)
        try {
            if (Build.VERSION.SDK_INT >= 33) {
                v.vibrate(effect, VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM))
            } else {
                @Suppress("DEPRECATION")
                v.vibrate(effect, AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build())
            }
        } catch (e: Exception) { Log.w(TAG, "vibrate failed", e) }
    }

    private fun stopOutputs() {
        tones?.stop(); tones = null
        try { vibrator?.cancel() } catch (_: Exception) {}
        vibrator = null
        val am = getSystemService(AudioManager::class.java)
        focus?.let { try { am.abandonAudioFocusRequest(it) } catch (_: Exception) {} }
        focus = null
        if (restoreVolume >= 0) {
            try { am.setStreamVolume(AudioManager.STREAM_ALARM, restoreVolume, 0) } catch (_: Exception) {}
            restoreVolume = -1
        }
    }

    private fun onTimeout() {
        val f = current
        if (f != null && !preview) Notifs.missed(this, f, late = false)
        finish("timeout")
    }

    private fun snooze() {
        val f = current ?: Store.activeRing(this)?.let { Fire.of(it) }
        if (f != null && !preview) {
            val at = System.currentTimeMillis() + SNOOZE_MS
            val sn = Store.snoozes(this)
            sn.put(Fire(f.alarmId, f.slot, f.day, at, true).json())
            Store.setSnoozes(this, sn)
        }
        finish("snooze")
    }

    /** Skip the rest of THIS occurrence of a range alarm (future days are unaffected). */
    private fun skipRest() {
        val f = current ?: Store.activeRing(this)?.let { Fire.of(it) }
        if (f != null && !preview) {
            val a = Store.alarm(this, f.alarmId)
            if (a != null) {
                val last = Scheduler.slots(a).last()
                val end = Scheduler.epochAt(LocalDate.ofEpochDay(f.day), last, ZoneId.systemDefault())
                Store.updateAlarm(this, f.alarmId) { it.put("skipBefore", end) }
                // Also drop any snooze for this alarm.
                val sn = Store.snoozes(this); val keep = org.json.JSONArray()
                for (i in 0 until sn.length()) if (sn.getJSONObject(i).optLong("alarmId") != f.alarmId) keep.put(sn.getJSONObject(i))
                Store.setSnoozes(this, keep)
                Bridge.emit("alarmsChanged", null)
            }
        }
        finish("skip")
    }

    private fun finish(reason: String) {
        Log.i(TAG, "ring finished: $reason")
        stopRing()
        Scheduler.reschedule(this)
    }

    private fun stopRing() {
        h.removeCallbacks(timeout)
        stopOutputs()
        current = null; preview = false
        Store.setActiveRing(this, null)
        try { wake?.release() } catch (_: Exception) {}
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
        Bridge.emit("ringChanged", null)
    }

    override fun onDestroy() {
        h.removeCallbacks(timeout)
        stopOutputs()
        try { wake?.release() } catch (_: Exception) {}
        super.onDestroy()
    }

    companion object {
        private const val TAG = "AlarmService"
        const val ACTION_RING = "com.alrm.interval_alarms.RING"
        const val ACTION_STOP = "com.alrm.interval_alarms.STOP"
        const val ACTION_SNOOZE = "com.alrm.interval_alarms.SNOOZE"
        const val ACTION_SKIP_REST = "com.alrm.interval_alarms.SKIP_REST"
        const val RING_MAX_MS = 5 * 60_000L
        const val PREVIEW_MAX_MS = 30_000L
        const val SNOOZE_MS = 9 * 60_000L
    }
}
