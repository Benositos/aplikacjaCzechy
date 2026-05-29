package com.calma.calma

import android.app.Activity
import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlin.math.max
import kotlin.math.min

/// Screen time channel — hybrid event/aggregate strategy.
///
/// `queryEvents` (raw FG/BG events) gives us precise, tz-aware millisecond
/// clipping to the requested window, which is what we need to honor the
/// user's chosen time zone. But some apps (Gmail in particular, plus apps
/// launched from notifications or foreground services) don't emit standard
/// activity lifecycle events on every device — so `queryEvents` silently
/// drops them.
///
/// `queryAndAggregateUsageStats` is Android's internal aggregate that
/// supplements raw events with foreground services, notification opens, and
/// other heuristics — it catches those missing apps, but at the cost of
/// being bucket-aligned to the device's system local midnight (so the time
/// it reports is approximate when we're querying in a non-system tz).
///
/// Strategy: trust `queryEvents` for any app that fired events (precise tz),
/// and fall back to `queryAndAggregateUsageStats` only for apps that events
/// missed entirely (coverage > precision for the missing ones).
class UsageChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    fun register() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(checkPermission())
                "openSettings" -> {
                    openUsageSettings()
                    result.success(null)
                }
                "queryUsage" -> {
                    val startMs = call.argument<Long>("startMs")
                    val endMs = call.argument<Long>("endMs")
                    if (startMs == null || endMs == null) {
                        result.error("BAD_ARGS", "startMs and endMs required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(queryUsage(startMs, endMs))
                    } catch (t: Throwable) {
                        result.error("QUERY_FAILED", t.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun checkPermission(): Boolean {
        val appOps = activity.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                activity.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                activity.packageName,
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        activity.startActivity(intent)
    }

    private fun queryUsage(startMs: Long, endMs: Long): List<Map<String, Any?>> {
        val usm = activity.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val isCurrentWindow = now in startMs..endMs

        val eventsTotals = computeEventsTotals(usm, startMs, endMs)

        // Stats supplement only for the current (today) window. For historical
        // queries `queryAndAggregateUsageStats` leaks data from the still-open
        // today bucket into past windows when the user's chosen tz differs
        // from system tz (the Lisbon-yesterday query overlaps the Polish-today
        // bucket, and Android attributes today's running totals to the past
        // window — empty days inherited full-day usage from today, the 24h
        // bug we hit and reverted). Historical days fall back to events-only;
        // missing Gmail-from-notification on history is accepted as the cost
        // of avoiding the leak.
        //
        // Within the today supplement:
        //   events < SUPPLEMENT_THRESHOLD_MS → trust stats. Either events
        //     didn't see the app or only saw a brief glitch resume/pause
        //     that the Dart <5s noise filter would drop anyway.
        //   events ≥ SUPPLEMENT_THRESHOLD_MS → take max(events, stats).
        //     Events is precise and tz-clipped, but Samsung One UI drops
        //     PAUSED events under battery throttling. When stats is higher
        //     for an app events captured substantially, the delta is
        //     recovered foreground time, not bucket-slop noise.
        val merged = mutableMapOf<String, Long>()
        merged.putAll(eventsTotals)
        if (isCurrentWindow) {
            val statsTotals = computeStatsTotals(usm, startMs, endMs)
            for ((pkg, statsMs) in statsTotals) {
                val eventsMs = merged[pkg] ?: 0L
                if (eventsMs < SUPPLEMENT_THRESHOLD_MS) {
                    merged[pkg] = statsMs
                } else if (statsMs > eventsMs) {
                    merged[pkg] = statsMs
                }
            }
        }

        val pm = activity.packageManager
        return merged
            .filterValues { it > 0 }
            .map { (pkg, ms) ->
                mapOf(
                    "package" to pkg,
                    "label" to resolveLabel(pm, pkg),
                    "millis" to ms,
                )
            }
    }

    /// Walks foreground/background events in a window widened 24h backwards,
    /// then clips each FG interval to the requested [startMs, endMs]. Precise
    /// to the millisecond and honors the caller's tz window — but only sees
    /// apps that emit standard activity lifecycle events.
    private fun computeEventsTotals(
        usm: UsageStatsManager,
        startMs: Long,
        endMs: Long,
    ): Map<String, Long> {
        val now = System.currentTimeMillis()
        val queryStart = startMs - ONE_DAY_MS
        val queryEnd = min(endMs, now)

        val events = usm.queryEvents(queryStart, queryEnd)
        val totals = mutableMapOf<String, Long>()
        val event = UsageEvents.Event()

        var currentPkg: String? = null
        var currentStart: Long = 0L

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName ?: continue
            val ts = event.timeStamp

            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED,
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    if (currentPkg != null && currentPkg != pkg) {
                        addClipped(totals, currentPkg!!, currentStart, ts, startMs, endMs)
                    }
                    currentPkg = pkg
                    currentStart = ts
                }

                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.MOVE_TO_BACKGROUND,
                UsageEvents.Event.ACTIVITY_STOPPED -> {
                    if (currentPkg == pkg) {
                        addClipped(totals, currentPkg!!, currentStart, ts, startMs, endMs)
                        currentPkg = null
                    }
                }
            }
        }

        // Tail-credit the still-open session only when its RESUMED event
        // fired inside the requested window (currentStart >= startMs). This
        // covers two cases correctly:
        //   - today: the user is currently in an app whose PAUSED hasn't
        //     fired yet → credit from RESUMED to queryEnd (= now).
        //   - historical day with a session crossing midnight (RESUMED at
        //     22:00 day D, PAUSED at 00:30 day D+1): day D's query won't
        //     see the PAUSED, but RESUMED is inside the window → credit
        //     22:00 to D_end = 2h on day D.
        // And avoids the "empty days show 24h" bug: if the still-open
        // session's RESUMED was in the 24h backfill region (before
        // startMs), the app wasn't really active in the queried window —
        // crediting it would invent up to a full day of foreground time.
        if (currentPkg != null && currentStart >= startMs) {
            addClipped(totals, currentPkg!!, currentStart, queryEnd, startMs, endMs)
        }

        return totals.filterValues { it > 0 }
    }

    /// Android's internal aggregate. Bucket-aligned to system midnight, so
    /// the returned ms count for the same wall-clock window may differ by
    /// up to the system-vs-target tz offset (typically ≤1h) when the user's
    /// chosen tz differs from device tz. Used as a coverage/correction
    /// supplement to events — catches apps events missed entirely (Gmail
    /// via notification) and recovers ms that events lost to dropped
    /// PAUSED events (Samsung One UI battery throttling).
    private fun computeStatsTotals(
        usm: UsageStatsManager,
        startMs: Long,
        endMs: Long,
    ): Map<String, Long> {
        val aggregated = usm.queryAndAggregateUsageStats(startMs, endMs)
        val map = mutableMapOf<String, Long>()
        for ((pkg, stats) in aggregated) {
            val ms = stats.totalTimeInForeground
            if (ms > 0) map[pkg] = ms
        }
        return map
    }

    private fun addClipped(
        totals: MutableMap<String, Long>,
        pkg: String,
        intervalStart: Long,
        intervalEnd: Long,
        windowStart: Long,
        windowEnd: Long,
    ) {
        val clipStart = max(intervalStart, windowStart)
        val clipEnd = min(intervalEnd, windowEnd)
        val delta = clipEnd - clipStart
        if (delta <= 0) return
        totals[pkg] = (totals[pkg] ?: 0L) + delta
    }

    private fun resolveLabel(pm: PackageManager, pkg: String): String? {
        return try {
            val info = pm.getApplicationInfo(pkg, 0)
            pm.getApplicationLabel(info).toString()
        } catch (_: Throwable) {
            null
        }
    }

    companion object {
        private const val CHANNEL_NAME = "com.calma.usage"
        private const val ONE_DAY_MS = 24L * 60 * 60 * 1000

        /// Below this, an app's events-derived total is treated as noise and
        /// replaced with the aggregate stats value. 60s lets a quick genuine
        /// use (a dictionary lookup, a settings toggle) count as events-precise,
        /// while catching apps whose brief events would mask a real foreground
        /// session that lives only in stats (Gmail via notification, Spotify
        /// resume-then-background, etc.).
        private const val SUPPLEMENT_THRESHOLD_MS = 60_000L
    }
}
