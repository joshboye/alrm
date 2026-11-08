package com.alrm.interval_alarms

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.media.Ringtone
import android.media.RingtoneManager
import android.util.Log
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.min
import kotlin.math.sin

/**
 * Synthesized alarm tones (no audio assets). Each tone is a short PCM loop that
 * AudioTrack repeats forever. If AudioTrack fails for any reason, we fall back to
 * the system's default alarm ringtone so the alarm is never silent.
 */
class TonePlayer(private val ctx: Context) {
    private var track: AudioTrack? = null
    private var fallback: Ringtone? = null

    fun play(name: String, usage: Int = AudioAttributes.USAGE_ALARM, loop: Boolean = true) {
        stop()
        try {
            val pcm = Synth.render(name)
            val attrs = AudioAttributes.Builder().setUsage(usage)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
            val fmt = AudioFormat.Builder().setSampleRate(Synth.RATE)
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build()
            val t = AudioTrack(attrs, fmt, pcm.size * 2, AudioTrack.MODE_STATIC, 0)
            t.write(pcm, 0, pcm.size)
            if (loop) t.setLoopPoints(0, pcm.size, -1)
            t.play()
            track = t
        } catch (e: Exception) {
            Log.e("TonePlayer", "synth failed, using system alarm", e)
            playFallback(usage)
        }
    }

    private fun playFallback(usage: Int) {
        try {
            val uri = RingtoneManager.getActualDefaultRingtoneUri(ctx, RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            fallback = RingtoneManager.getRingtone(ctx, uri)?.apply {
                audioAttributes = AudioAttributes.Builder().setUsage(usage).build()
                if (android.os.Build.VERSION.SDK_INT >= 28) isLooping = true
                play()
            }
        } catch (e: Exception) { Log.e("TonePlayer", "fallback failed", e) }
    }

    fun stop() {
        try { track?.stop() } catch (_: Exception) {}
        try { track?.release() } catch (_: Exception) {}
        track = null
        try { fallback?.stop() } catch (_: Exception) {}
        fallback = null
    }
}

object Synth {
    const val RATE = 44100
    private val cache = HashMap<String, ShortArray>()

    @Synchronized
    fun render(name: String): ShortArray = cache.getOrPut(name) {
        when (name) {
            "WAKE UP" -> wakeUp()
            "KIND OF BLUE" -> kindOfBlue()
            "BEEP BEEP" -> beepBeep()
            "RADAR" -> radar()
            "MORNING" -> morning()
            else -> beepBeep()
        }
    }

    private class Buf(seconds: Double) {
        val d = DoubleArray((seconds * RATE).toInt())
        fun tone(start: Double, len: Double, f0: Double, f1: Double = f0, amp: Double = .5,
                 attack: Double = .005, decay: Double = 0.0, harm: Double = 0.0, square: Boolean = false) {
            val s0 = (start * RATE).toInt(); val n = (len * RATE).toInt()
            var ph = 0.0
            for (i in 0 until n) {
                val idx = s0 + i; if (idx >= d.size) break
                val t = i.toDouble() / RATE
                val f = f0 + (f1 - f0) * (i.toDouble() / n)
                ph += 2 * PI * f / RATE
                var env = min(1.0, t / attack) * min(1.0, (len - t) / .01)
                if (decay > 0) env *= exp(-t / decay)
                var v = sin(ph) + harm * sin(2 * ph) + harm * .5 * sin(3 * ph)
                if (square) v = if (sin(ph) >= 0) .6 else -.6
                d[idx] += v * env * amp
            }
        }
        fun pcm(): ShortArray {
            var peak = 1e-9; for (x in d) peak = maxOf(peak, kotlin.math.abs(x))
            val g = .89 / peak
            return ShortArray(d.size) { (d[it] * g * Short.MAX_VALUE).toInt().toShort() }
        }
    }

    // Classic digital-watch double beep ×4, then rest.
    private fun beepBeep(): ShortArray = Buf(2.0).apply {
        for (k in 0 until 4) { tone(k * .2, .09, 2048.0, square = true, amp = .4) }
    }.pcm()

    // Bright rising chirps — insistent.
    private fun wakeUp(): ShortArray = Buf(1.6).apply {
        val notes = doubleArrayOf(784.0, 988.0, 1175.0, 1568.0)
        notes.forEachIndexed { i, f -> tone(i * .14, .13, f, f * 1.02, harm = .3, amp = .45) }
        notes.forEachIndexed { i, f -> tone(.8 + i * .14, .13, f, f * 1.02, harm = .3, amp = .45) }
    }.pcm()

    // Soft jazzy minor-7 arpeggio with bell-like decay.
    private fun kindOfBlue(): ShortArray = Buf(3.2).apply {
        val notes = doubleArrayOf(293.66, 349.23, 440.0, 523.25, 659.25, 523.25, 440.0, 349.23)
        notes.forEachIndexed { i, f -> tone(i * .34, 1.2, f, harm = .25, amp = .35, attack = .01, decay = .45) }
    }.pcm()

    // Sonar-style pings with a downward sweep.
    private fun radar(): ShortArray = Buf(2.4).apply {
        for (k in 0 until 3) tone(k * .3, .26, 1760.0, 1320.0, harm = .15, amp = .5, decay = .12)
        tone(1.2, .5, 880.0, 660.0, harm = .2, amp = .3, decay = .2)
    }.pcm()

    // Gentle ascending pentatonic melody.
    private fun morning(): ShortArray = Buf(3.6).apply {
        val notes = doubleArrayOf(523.25, 587.33, 659.25, 783.99, 880.0, 783.99, 1046.5)
        notes.forEachIndexed { i, f -> tone(i * .38, .7, f, harm = .2, amp = .4, attack = .02, decay = .35) }
    }.pcm()
}
