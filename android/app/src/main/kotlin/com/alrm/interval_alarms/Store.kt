package com.alrm.interval_alarms

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * Single source of truth for alarms, kept in device-protected storage so the
 * schedule can be read (and alarms can ring) after a reboot before first unlock.
 *
 * Alarm JSON shape (shared with Dart):
 *  id, type ("single"|"range"), start (min of day), end (min of day | null), interval (min),
 *  skipped [min-of-day], label, on, days [0=MON..6=SUN], sound, vib,
 *  armedAt (epoch ms, when it was last switched on — used for one-time alarms),
 *  skipBefore (epoch ms — "skip remaining in this range" for one occurrence only)
 */
object Store {
    private const val FILE = "alarm_engine"
    private val lock = Any()

    private fun prefs(ctx: Context): SharedPreferences {
        val dp = ctx.applicationContext.createDeviceProtectedStorageContext()
        return dp.getSharedPreferences(FILE, Context.MODE_PRIVATE)
    }

    private fun arr(ctx: Context, key: String): JSONArray =
        try { JSONArray(prefs(ctx).getString(key, "[]")) } catch (_: Exception) { JSONArray() }

    private fun obj(ctx: Context, key: String): JSONObject? =
        prefs(ctx).getString(key, null)?.let { try { JSONObject(it) } catch (_: Exception) { null } }

    private fun put(ctx: Context, key: String, v: String?) {
        // commit() (synchronous) — we may be in a receiver about to be killed.
        prefs(ctx).edit().apply { if (v == null) remove(key) else putString(key, v) }.commit()
    }

    fun alarms(ctx: Context): JSONArray = synchronized(lock) { arr(ctx, "alarms") }
    fun setAlarms(ctx: Context, a: JSONArray) = synchronized(lock) { put(ctx, "alarms", a.toString()) }
    fun hasAlarms(ctx: Context): Boolean = prefs(ctx).contains("alarms")

    fun alarm(ctx: Context, id: Long): JSONObject? {
        val a = alarms(ctx)
        for (i in 0 until a.length()) if (a.getJSONObject(i).optLong("id") == id) return a.getJSONObject(i)
        return null
    }

    fun updateAlarm(ctx: Context, id: Long, fn: (JSONObject) -> Unit) = synchronized(lock) {
        val a = arr(ctx, "alarms")
        for (i in 0 until a.length()) {
            val o = a.getJSONObject(i)
            if (o.optLong("id") == id) fn(o)
        }
        put(ctx, "alarms", a.toString())
    }

    /** Snoozes: [{alarmId, slot, day, at}] */
    fun snoozes(ctx: Context): JSONArray = synchronized(lock) { arr(ctx, "snoozes") }
    fun setSnoozes(ctx: Context, a: JSONArray) = synchronized(lock) { put(ctx, "snoozes", a.toString()) }

    /** The pending AlarmManager target: {at, fires:[{alarmId, slot, day, at, snooze}]} */
    fun target(ctx: Context): JSONObject? = synchronized(lock) { obj(ctx, "target") }
    fun setTarget(ctx: Context, t: JSONObject?) = synchronized(lock) { put(ctx, "target", t?.toString()) }

    /** Epoch ms of the last fire we handled — nothing at or before this fires again. */
    fun lastFiredAt(ctx: Context): Long = prefs(ctx).getLong("lastFiredAt", 0L)
    fun setLastFiredAt(ctx: Context, v: Long) { prefs(ctx).edit().putLong("lastFiredAt", v).commit() }

    /** Currently ringing alarm: {alarmId, slot, day, at, preview} */
    fun activeRing(ctx: Context): JSONObject? = synchronized(lock) { obj(ctx, "ring") }
    fun setActiveRing(ctx: Context, r: JSONObject?) = synchronized(lock) { put(ctx, "ring", r?.toString()) }

    fun settings(ctx: Context): JSONObject = obj(ctx, "settings") ?: JSONObject()
    fun setSettings(ctx: Context, s: JSONObject) = put(ctx, "settings", s.toString())

    fun flag(ctx: Context, k: String) = prefs(ctx).getBoolean(k, false)
    fun setFlag(ctx: Context, k: String, v: Boolean) { prefs(ctx).edit().putBoolean(k, v).commit() }
}
