package com.alrm.interval_alarms

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/** One concrete ring: alarm [alarmId], slot minute [slot] (may exceed 1440 for overnight
 *  ranges) relative to local date [day] (epochDay), firing at epoch ms [at]. */
data class Fire(val alarmId: Long, val slot: Int, val day: Long, val at: Long, val snooze: Boolean) {
    fun json(): JSONObject = JSONObject().put("alarmId", alarmId).put("slot", slot)
        .put("day", day).put("at", at).put("snooze", snooze)

    companion object {
        fun of(o: JSONObject) = Fire(o.getLong("alarmId"), o.getInt("slot"), o.getLong("day"),
            o.getLong("at"), o.optBoolean("snooze"))
    }
}

/**
 * Strategy: always keep exactly ONE AlarmManager.setAlarmClock() armed for the earliest
 * upcoming ring across all alarms + snoozes. setAlarmClock is the strongest scheduling
 * primitive Android offers: exact, exempt from Doze/App-Standby, shown in the status bar,
 * and grants a foreground-service start exemption when it fires. After every fire, edit,
 * boot, update or clock change we recompute from scratch, so state can never drift.
 */
object Scheduler {
    private const val TAG = "AlarmScheduler"
    const val ACTION_FIRE = "com.alrm.interval_alarms.FIRE"
    private const val REQ_FIRE = 4100
    private const val REQ_SHOW = 4101

    fun slots(a: JSONObject): List<Int> {
        val start = a.optInt("start")
        if (a.optString("type") != "range" || a.isNull("end")) return listOf(start)
        val end = a.optInt("end")
        val endU = if (end <= start) end + 1440 else end
        val iv = a.optInt("interval", 10).coerceAtLeast(1)
        val r = ArrayList<Int>()
        var t = start
        while (t <= endU) { r.add(t); t += iv }
        return r
    }

    private fun intSet(a: JSONArray?): Set<Int> {
        val s = HashSet<Int>(); if (a == null) return s
        for (i in 0 until a.length()) s.add(a.optInt(i)); return s
    }

    fun epochAt(day: LocalDate, slot: Int, zone: ZoneId): Long =
        day.atStartOfDay().plusMinutes(slot.toLong()).atZone(zone).toInstant().toEpochMilli()

    /** Earliest ring of alarm [a] strictly after [after], or null. */
    fun nextFor(a: JSONObject, after: Long, zone: ZoneId = ZoneId.systemDefault()): Fire? {
        val sl = slots(a)
        val skipped = intSet(a.optJSONArray("skipped"))
        val days = intSet(a.optJSONArray("days"))
        val oneTime = days.isEmpty()
        val armedAt = a.optLong("armedAt", 0L)
        val skipBefore = a.optLong("skipBefore", 0L)
        val id = a.optLong("id")
        val today = Instant.ofEpochMilli(after).atZone(zone).toLocalDate()
        var best: Fire? = null
        for (off in -1L..8L) {
            val d = today.plusDays(off)
            if (!oneTime && (d.dayOfWeek.value - 1) !in days) continue
            // One-time alarms ring only for the first occurrence that ends after they were armed.
            if (oneTime && epochAt(d, sl.last(), zone) <= armedAt) continue
            for (t in sl) {
                if ((t % 1440) in skipped) continue
                val x = epochAt(d, t, zone)
                if (x <= after || x <= skipBefore || (oneTime && x <= armedAt)) continue
                if (best == null || x < best.at) best = Fire(id, t, d.toEpochDay(), x, false)
                break
            }
            if (oneTime) break
        }
        return best
    }

    /** All rings due at the earliest upcoming instant. */
    fun computeNext(ctx: Context, after: Long): List<Fire> {
        val all = ArrayList<Fire>()
        val alarms = Store.alarms(ctx)
        val ids = HashSet<Long>()
        for (i in 0 until alarms.length()) {
            val a = alarms.getJSONObject(i)
            ids.add(a.optLong("id"))
            if (!a.optBoolean("on")) continue
            nextFor(a, after)?.let { all.add(it) }
        }
        val sn = Store.snoozes(ctx)
        for (i in 0 until sn.length()) {
            val f = Fire.of(sn.getJSONObject(i)).copy(snooze = true)
            if (f.at > after && f.alarmId in ids) all.add(f)
        }
        if (all.isEmpty()) return emptyList()
        val min = all.minOf { it.at }
        // Snoozes first: they are explicit user intent.
        return all.filter { it.at == min }.sortedBy { if (it.snooze) 0 else 1 }
    }

    /** Turns off one-time alarms that have nothing left to ring. Returns true if changed. */
    private fun expireOneTime(ctx: Context, after: Long): Boolean {
        val alarms = Store.alarms(ctx)
        val ringing = Store.activeRing(ctx)?.optLong("alarmId", -1L) ?: -1L
        var changed = false
        for (i in 0 until alarms.length()) {
            val a = alarms.getJSONObject(i)
            if (!a.optBoolean("on")) continue
            val days = a.optJSONArray("days")
            if (days != null && days.length() > 0) continue
            if (a.optLong("id") == ringing) continue
            if (nextFor(a, after) == null) { a.put("on", false); changed = true }
        }
        if (changed) Store.setAlarms(ctx, alarms)
        return changed
    }

    private fun pruneSnoozes(ctx: Context, after: Long) {
        val sn = Store.snoozes(ctx); val keep = JSONArray()
        for (i in 0 until sn.length()) if (sn.getJSONObject(i).optLong("at") > after) keep.put(sn.getJSONObject(i))
        if (keep.length() != sn.length()) Store.setSnoozes(ctx, keep)
    }

    fun fireIntent(ctx: Context): PendingIntent {
        val i = Intent(ctx, AlarmReceiver::class.java).setAction(ACTION_FIRE)
        return PendingIntent.getBroadcast(ctx, REQ_FIRE, i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun showIntent(ctx: Context): PendingIntent {
        val i = Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return PendingIntent.getActivity(ctx, REQ_SHOW, i,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    /** Arm the OS alarm for [at]. Falls back gracefully if exact alarms are revoked. */
    fun arm(ctx: Context, at: Long) {
        val am = ctx.getSystemService(AlarmManager::class.java)
        val op = fireIntent(ctx)
        try {
            am.setAlarmClock(AlarmManager.AlarmClockInfo(at, showIntent(ctx)), op)
            return
        } catch (e: SecurityException) {
            Log.w(TAG, "setAlarmClock denied, falling back", e)
        }
        try {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, op)
        } catch (e: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, op)
        }
    }

    fun canExact(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT < 31) return true
        return ctx.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
    }

    /** Recompute and arm the next ring. Safe to call any time, from any thread. */
    @Synchronized
    fun reschedule(ctx: Context) {
        val now = System.currentTimeMillis()
        val after = maxOf(now, Store.lastFiredAt(ctx))
        pruneSnoozes(ctx, now)
        val changed = expireOneTime(ctx, after)
        val fires = computeNext(ctx, after)
        val am = ctx.getSystemService(AlarmManager::class.java)
        if (fires.isEmpty()) {
            am.cancel(fireIntent(ctx))
            Store.setTarget(ctx, null)
        } else {
            val at = fires[0].at
            val arr = JSONArray(); fires.forEach { arr.put(it.json()) }
            Store.setTarget(ctx, JSONObject().put("at", at).put("fires", arr))
            arm(ctx, at)
            Log.i(TAG, "Armed ${fires.size} ring(s) at ${Instant.ofEpochMilli(at)}")
        }
        Bridge.emit("scheduleChanged", null)
        if (changed) Bridge.emit("alarmsChanged", null)
    }

    /** Arm an immediate catch-up ring for rings missed while the device was off. */
    fun armCatchUp(ctx: Context, fires: JSONArray) {
        val at = System.currentTimeMillis() + 1500
        Store.setTarget(ctx, JSONObject().put("at", at).put("fires", fires))
        arm(ctx, at)
    }
}
