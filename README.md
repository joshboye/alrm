<p align="center">
  <img src="assets/icons/alrm-app-icon.png" width="120" alt="alrm icon">
</p>

<h1 align="center">alrm</h1>

<p align="center">
  An LCD-style alarm clock for Android that can ring <b>once</b> or <b>every few minutes across a time range</b>.<br>
  Built to never miss an alarm.
</p>

---

## What makes it different

Most alarm apps make you create ten separate alarms if you want to be nudged every 10 minutes between 10:00 and 12:00. In alrm that's **one alarm**: pick a start, an end and an interval, then skip any individual times you don't need.

- **Single alarms**: ring once at a time, optionally repeating on chosen days.
- **Interval alarms**: ring every *N* minutes between a start and end time (e.g. hydrate every 10 min from 10:00 to 12:00).
- **Skip individual rings** in a range with a tap.
- **Skip the rest of today's range** right from the ringing screen. Tomorrow is unaffected.

---

## The home screen

| Area | What it shows |
|---|---|
| **Clock** | Current time on a seven-segment display. The line underneath tells you when the next alarm rings. |
| **24-hour bar chart** | Each bar is 30 minutes of the day. Bright bars have an alarm in them; the red line is *now*. |
| **Weekday strip** | Today is highlighted. |
| **Alarm cards** | One card per alarm (see below). Swipe sideways to browse. |
| **Bell button** (bottom left) | Preview how your next alarm will ring. |
| **Finder** (bottom middle) | A scrubbable 24-hour ruler. Drag it to jump to the alarm nearest that time. Swiping the cards moves it too. |
| **+ button** (bottom right) | Create a new alarm. |

### Alarm cards

Each card shows:

- The **time** (or start → end for an interval alarm) and an on/off switch
- A **countdown** such as `IN 2H 14M`, and when it rings next (`TOMORROW 06:30`, `NEXT 10:40 · 7 LEFT TODAY`)
- The **repeat days** (`M T W T F S S`) or `ONE-TIME`
- The **sound** and whether **vibration** is on
- For interval alarms, a strip showing every ring in the range (faded = skipped)
- A small **pixel illustration** that lights up in colour while the alarm is on

**Card gestures**

| Gesture | Action |
|---|---|
| Tap | Turn the alarm on / off |
| Long-press | Menu: **Edit**, **Preview ring**, **Delete** |

The illustration is chosen from the label (e.g. *Hydrate* → water drop, *Workout* → dumbbell, *Meds* → capsule, *Study* → book, *Sleep* → Zzz, *Coffee/Lunch* → cup), otherwise from the time of day (sunrise, coffee, sun, sunset, moon).

---

## Creating an alarm

1. Tap **+**.
2. Scroll the wheels to the **start time**.
3. Optionally adjust:
   - **Sound**: tap to cycle through the 5 tones (you'll hear a short preview).
   - **Vibrate**: on / off.
   - **Repeat**: No → Weekdays → Daily → Weekends. *No* means it rings once and then switches itself off.
   - **Label**: tap to name it. Quick picks are provided.
4. Tap **✓** to save a single alarm.

### Making it an interval alarm

1. On the new-alarm screen tap **+ SET END TIME**.
2. Choose the **end time** with the wheels, or use the **+30M / +1H / +2H / +3H** shortcuts. Ranges can cross midnight.
3. Tap **✓** to open the **Intervals** screen:
   - Choose how often it rings: **5, 10, 15, 20, 30** minutes, or **CUST** for any interval from 1 to 120 minutes.
   - Every ring time is shown in a grid grouped by hour. **Tap a time to skip it**; tap again to bring it back. **ALL ON** restores everything.
4. Tap **✓** to save. The counter shows how many rings are set (e.g. `11/13`).

To remove the range and go back to a single alarm, tap the **×** next to *ENDS …*.

---

## When an alarm rings

The phone wakes up and alrm takes over the lock screen, even if the app was closed.

| Control | What it does |
|---|---|
| **SNOOZE - 9 MIN** | Rings again in 9 minutes. |
| **Slide to stop** | Drag the thumb all the way right. You'll feel a click when it's far enough. |
| **Skip remaining N in this range** | (Interval alarms) Silences the rest of *today's* rings for this alarm. Future days are untouched. |

For interval alarms the screen shows which ring this is (`3 OF 12`) and when the next one is.

Snooze and Stop are also available as buttons on the notification.

**If you don't respond**, an alarm rings for up to **5 minutes** (or until the next ring in its range), then stops and leaves a **"Missed"** notification.

---

## Settings

**Long-press the big clock** on the home screen to open settings:

- **Theme**: Crimson (default), Cobalt, Amber or LCD green
- **Clock**: 12-hour or 24-hour
- **Default interval**: what new interval alarms start with
- **Reliability**: checks that everything an alarm needs is allowed (see below)

---

## Making sure alarms always ring

alrm uses Android's dedicated alarm-clock system (the same one the built-in Clock app uses), so alarms fire on time even in battery-saving Doze mode. It also:

- **Survives reboots**: alarms are re-armed when the phone restarts, even before you unlock it.
- **Catches up**: if the phone was off when an alarm was due and comes back within 15 minutes, it rings straight away. Otherwise you get a *Missed* notification.
- **Handles clock and time-zone changes**: the schedule is recalculated automatically.
- **Stays audible**: alarms play on the *alarm* volume channel. If that volume is very low or muted, alrm temporarily raises it to 50% for the ring and restores it afterwards.
- **Never goes silent**: if a built-in tone ever fails to play, it falls back to your phone's default alarm sound.

### Permissions to allow

On first launch alrm asks for notification access. If a red **"ALARMS MAY NOT RING — TAP TO FIX"** banner appears on the home screen, tap it, or open **Settings → Reliability** and allow anything marked **FIX**:

| Permission | Why |
|---|---|
| **Notifications** | Needed to show the alarm and its Snooze / Stop buttons. |
| **Full-screen alarm** | Lets the alarm take over the lock screen (Android 14+). |
| **Exact alarms** | Rings on the exact minute. |
| **Unrestricted battery** *(recommended)* | Some phones (Samsung, Xiaomi, OnePlus, Oppo, Vivo…) aggressively close apps. Setting alrm to *Unrestricted* prevents this. |

> **Tip:** Don't "force stop" alrm from Android settings. Android cancels a force-stopped app's alarms until you open it again. Simply opening alrm re-arms everything.

---

## Sounds

| Tone | Character |
|---|---|
| **WAKE UP** | Bright rising chirps |
| **KIND OF BLUE** | Soft, jazzy arpeggio |
| **BEEP BEEP** | Classic digital-watch beeps |
| **RADAR** | Sonar-style pings |
| **MORNING** | Gentle ascending melody |

All tones are generated by the app itself, so no audio files are needed.

---

## FAQ

**Does a one-time alarm delete itself?**
No. After it rings it simply switches off, so you can tap the card to use it again.

**I turned an interval alarm on halfway through its range. What happens?**
It rings for the remaining times today.

**Can a range go past midnight?**
Yes, e.g. 23:00 → 01:00 every 30 minutes. Repeat days refer to the day the range *starts*.

**Will my alarms ring in Do Not Disturb?**
They play on the alarm channel, which Android lets through in Do Not Disturb by default. If you've changed DND to block alarms, they'll be silenced.

**Does it work on iPhone?**
No, alrm is Android-only. iOS doesn't allow third-party apps the alarm guarantees alrm relies on.

---

## For developers

Requirements: Flutter 3.38+, Android SDK 35, a device running **Android 8.0 (API 26)** or newer.

```bash
flutter pub get
flutter run            # debug on a connected device
flutter build apk      # release APK in build/app/outputs/flutter-apk/
flutter test           # scheduling + layout tests
```

**How it's built**

- **UI**: Flutter (`lib/`). Screens live in `lib/screens/`, the alarm model and scheduling rules in `lib/model.dart`, and the pixel illustrations in `lib/pixel_art.dart`.
- **Alarm engine**: native Kotlin (`android/app/src/main/kotlin/…`), so ringing never depends on the Flutter UI being alive:
  - `Scheduler.kt` keeps a single `AlarmManager.setAlarmClock()` armed for the earliest upcoming ring and recomputes it after every change, ring, reboot or clock change.
  - `AlarmReceiver.kt` fires alarms, re-arms after boot/update/time change, and handles catch-up.
  - `AlarmService.kt` is the foreground service that plays the tone, vibrates, shows the full-screen notification and auto-silences after 5 minutes.
  - `Tones.kt` synthesizes the five alarm tones.
  - `Store.kt` persists everything in device-protected storage, so alarms work before first unlock after a reboot.
- The scheduling rules exist in both `lib/model.dart` (for display) and `Scheduler.kt` (for ringing) and must be kept in sync. `test/schedule_test.dart` covers them.

**Changing the app icon:** replace `assets/icons/alrm-app-icon.png` and run `dart run flutter_launcher_icons`.

**Fonts:** [DSEG7 Classic](https://github.com/keshikan/DSEG) and [Geist Mono](https://github.com/vercel/geist-font), both under the SIL Open Font License.
