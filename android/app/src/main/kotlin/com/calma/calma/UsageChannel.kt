package com.calma.calma

import android.app.Activity
import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/// Screen time channel.
///
/// Routes per type of window:
///   - "today" (now ∈ [startMs..endMs]) → queryAndAggregateUsageStats
///     (covers the still-open daily bucket; aggregate APIs work fine when
///     the window contains the current moment)
///   - historical → queryUsageStats(INTERVAL_DAILY) + firstTimeStamp filter
///     (clean closed buckets, no cross-bucket leakage)
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

        val totals: MutableMap<String, Long> = if (now in startMs..endMs) {
            val aggregated = usm.queryAndAggregateUsageStats(startMs, endMs)
            val map = mutableMapOf<String, Long>()
            for ((pkg, stats) in aggregated) {
                val ms = stats.totalTimeInForeground
                if (ms > 0) map[pkg] = ms
            }
            map
        } else {
            val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startMs, endMs)
            val map = mutableMapOf<String, Long>()
            for (s in stats) {
                val pkg = s.packageName ?: continue
                if (s.firstTimeStamp < startMs) continue
                if (s.firstTimeStamp >= endMs) continue
                val ms = s.totalTimeInForeground
                if (ms <= 0) continue
                map.merge(pkg, ms) { a, b -> a + b }
            }
            map
        }

        val pm = activity.packageManager
        return totals.map { (pkg, ms) ->
            mapOf(
                "package" to pkg,
                "label" to resolveLabel(pm, pkg),
                "millis" to ms,
            )
        }
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
    }
}
