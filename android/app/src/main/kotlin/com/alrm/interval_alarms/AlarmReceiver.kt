package com.alrm.interval_alarms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.util.Log
import androidx.core.content.ContextCompat
import org.json.JSONArray

class AlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val ctx = context.applicationContext
        // Hold the CPU awake until the ringing service has taken over.
        val wl = ctx.getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "alrm:receiver")
        wl.acquire(30_000)
        try {
            if (intent.action == Scheduler.ACTION_FIRE) onFire(ctx) else onSystemEvent(ctx, intent.action)
        } catch (e: Exception) {
            Log.e(TAG, "receiver failure", e)
            // Never leave the schedule disarmed.
            try { Scheduler.reschedule(ctx) } catch (_: Exception) {}
        } finally {
            if (wl.isHeld) wl.release()
        }
    }

    private fun onFire(ctx: Context) {
        val now = System.currentTimeMillis()
        val target = Store.target(ctx)
        if (target != null && target.optLong("at") <= now + 5_000) {
            val at = target.getLong("at")
            Store.setLastFiredAt(ctx, maxOf(at, Store.lastFiredAt(ctx)))
            val fires = target.optJSONArray("fires") ?: JSONArray()
            // Consume snoozes that just fired.
            if (fires.length() > 0) {
                val sn = Store.snoozes(ctx); val keep = JSONArray()
                for (i in 0 until sn.length()) {
                    val s = sn.getJSONObject(i)
                    var used = false
                    for (j in 0 until fires.length()) {
                        val f = fires.getJSONObject(j)
                        if (f.optBoolean("snooze") && f.optLong("alarmId") == s.optLong("alarmId") &&
                            f.optLong("at") == s.optLong("at")) used = true
                    }
                    if (!used) keep.put(s)
                }
                Store.setSnoozes(ctx, keep)
                val f = Fire.of(fires.getJSONObject(0))
                if (Store.alarm(ctx, f.alarmId) != null) startRing(ctx, f, preview = false)
            }
        }
        Scheduler.reschedule(ctx)
    }

    private fun onSystemEvent(ctx: Context, action: String?) {
        Log.i(TAG, "system event $action")
        val now = System.currentTimeMillis()
        if (action == Intent.ACTION_TIME_CHANGED || action == Intent.ACTION_TIMEZONE_CHANGED) {
            // Clock moved backwards? Don't let a "future" lastFiredAt suppress real alarms.
            if (Store.lastFiredAt(ctx) > now) Store.setLastFiredAt(ctx, now)
        }
        val target = Store.target(ctx)
        val ringing = Store.activeRing(ctx) != null
        if (target != null && target.optLong("at") < now - 1_000 && !ringing) {
            val missedBy = now - target.getLong("at")
            val fires = target.optJSONArray("fires") ?: JSONArray()
            if (missedBy <= CATCH_UP_WINDOW_MS && fires.length() > 0) {
                // Device was off / rebooting when the alarm was due: ring now.
                Scheduler.armCatchUp(ctx, fires)
                return
            }
            if (fires.length() > 0) Notifs.missed(ctx, Fire.of(fires.getJSONObject(0)), late = true)
            Store.setLastFiredAt(ctx, now)
        }
        Scheduler.reschedule(ctx)
    }

    companion object {
        private const val TAG = "AlarmReceiver"
        const val CATCH_UP_WINDOW_MS = 15 * 60_000L

        fun startRing(ctx: Context, f: Fire, preview: Boolean) {
            val i = Intent(ctx, AlarmService::class.java)
                .setAction(AlarmService.ACTION_RING)
                .putExtra("fire", f.json().toString())
                .putExtra("preview", preview)
            ContextCompat.startForegroundService(ctx, i)
        }
    }
}
