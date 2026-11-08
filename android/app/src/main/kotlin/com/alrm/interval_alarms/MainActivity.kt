package com.alrm.interval_alarms

import android.Manifest
import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.media.AudioAttributes
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate

/** Main-thread bridge from the native engine to Flutter (no-op if UI isn't running). */
object Bridge {
    @Volatile var channel: MethodChannel? = null
    private val h = Handler(Looper.getMainLooper())
    fun emit(method: String, arg: Any?) {
        h.post { try { channel?.invokeMethod(method, arg) } catch (_: Exception) {} }
    }
}

class MainActivity : FlutterActivity() {
    private var soundPreview: TonePlayer? = null
    private val h = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyLockScreenMode(intent)
        Notifs.ensureChannels(this)
        // Self-heal: every app open re-arms the schedule.
        Scheduler.reschedule(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        applyLockScreenMode(intent)
        Bridge.emit("ringChanged", null)
    }

    /** Show over the lock screen only while an alarm is ringing. */
    private fun applyLockScreenMode(i: Intent?) {
        val ringing = (i?.getBooleanExtra("ring", false) == true) || Store.activeRing(this) != null
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(ringing); setTurnScreenOn(ringing)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "alrm/engine")
        Bridge.channel = ch
        ch.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getAlarms" -> result.success(if (Store.hasAlarms(this)) Store.alarms(this).toString() else null)
                    "saveAlarms" -> { saveAlarms(JSONArray(call.arguments as String)); result.success(Store.alarms(this).toString()) }
                    "getSettings" -> result.success(Store.settings(this).toString())
                    "saveSettings" -> { Store.setSettings(this, JSONObject(call.arguments as String)); result.success(true) }
                    "getState" -> result.success(JSONObject()
                        .put("ring", Store.activeRing(this) ?: JSONObject.NULL)
                        .put("target", Store.target(this) ?: JSONObject.NULL).toString())
                    "ringAction" -> { ringAction(call.arguments as String); result.success(true) }
                    "ringDone" -> { ringDone(); result.success(true) }
                    "preview" -> { preview((call.arguments as Number).toLong()); result.success(true) }
                    "previewSound" -> { previewSound(call.arguments as String); result.success(true) }
                    "health" -> result.success(health().toString())
                    "fix" -> { fix(call.arguments as String); result.success(true) }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("engine", e.message, null)
            }
        }
    }

    override fun onDestroy() {
        soundPreview?.stop()
        if (Bridge.channel != null) Bridge.channel = null
        super.onDestroy()
    }

    private fun saveAlarms(next: JSONArray) {
        val prev = Store.alarms(this)
        val prevOn = HashMap<Long, Boolean>()
        for (i in 0 until prev.length()) prev.getJSONObject(i).let { prevOn[it.optLong("id")] = it.optBoolean("on") }
        val alive = HashSet<Long>()
        for (i in 0 until next.length()) next.getJSONObject(i).let { if (it.optBoolean("on")) alive.add(it.optLong("id")) }
        // Drop snoozes of alarms that were deleted or switched off by the user.
        val sn = Store.snoozes(this); val keep = JSONArray()
        for (i in 0 until sn.length()) {
            val s = sn.getJSONObject(i); val id = s.optLong("alarmId")
            if (id in alive || prevOn[id] == false) keep.put(s)
        }
        Store.setSnoozes(this, keep)
        Store.setAlarms(this, next)
        Scheduler.reschedule(this)
    }

    private fun ringAction(action: String) {
        val act = when (action) {
            "stop" -> AlarmService.ACTION_STOP
            "snooze" -> AlarmService.ACTION_SNOOZE
            "skipRest" -> AlarmService.ACTION_SKIP_REST
            else -> return
        }
        startService(Intent(this, AlarmService::class.java).setAction(act))
    }

    private fun ringDone() {
        if (Build.VERSION.SDK_INT >= 27) { setShowWhenLocked(false); setTurnScreenOn(false) }
        val km = getSystemService(KeyguardManager::class.java)
        if (km.isKeyguardLocked) moveTaskToBack(true)
    }

    private fun preview(alarmId: Long) {
        val a = Store.alarm(this, alarmId) ?: return
        val now = System.currentTimeMillis()
        val f = Scheduler.nextFor(a, now)
            ?: Fire(alarmId, a.optInt("start"), LocalDate.now().toEpochDay(), now, false)
        AlarmReceiver.startRing(this, f, preview = true)
    }

    private fun previewSound(name: String) {
        soundPreview?.stop()
        soundPreview = TonePlayer(this).also { it.play(name, AudioAttributes.USAGE_ALARM, loop = false) }
        h.removeCallbacksAndMessages("snd")
        h.postAtTime({ soundPreview?.stop() }, "snd", android.os.SystemClock.uptimeMillis() + 3500)
    }

    private fun health(): JSONObject {
        val nm = getSystemService(NotificationManager::class.java)
        val notif = if (Build.VERSION.SDK_INT >= 33)
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
            else nm.areNotificationsEnabled()
        val fsi = if (Build.VERSION.SDK_INT >= 34) nm.canUseFullScreenIntent() else true
        val battery = getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(packageName)
        return JSONObject().put("notifications", notif && nm.areNotificationsEnabled())
            .put("fullScreen", fsi).put("exact", Scheduler.canExact(this)).put("battery", battery)
    }

    private fun fix(key: String) {
        val pkg = Uri.parse("package:$packageName")
        val i: Intent? = when (key) {
            "notifications" -> {
                if (Build.VERSION.SDK_INT >= 33 &&
                    checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED &&
                    !Store.flag(this, "askedNotif")) {
                    Store.setFlag(this, "askedNotif", true)
                    requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1); null
                } else Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
            "fullScreen" -> if (Build.VERSION.SDK_INT >= 34) Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, pkg) else null
            "exact" -> if (Build.VERSION.SDK_INT >= 31) Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, pkg) else null
            "battery" -> Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, pkg)
            else -> null
        }
        if (i != null) {
            try { startActivity(i) } catch (_: Exception) {
                startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg))
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        Bridge.emit("healthChanged", null)
    }
}
