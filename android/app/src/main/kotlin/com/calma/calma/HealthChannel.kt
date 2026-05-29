package com.calma.calma

import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId

/// Direct Health Connect integration via `androidx.health.connect.client`.
/// We don't use the `health` package — its API contract on Android (especially
/// `requestAuthorization` returning before the user actually clicks Allow) was
/// the cause of the permission flakiness in v1.
///
/// Channel methods:
///   sdkStatus         → Int. 1 = SDK_UNAVAILABLE, 2 = PROVIDER_UPDATE_REQUIRED, 3 = AVAILABLE.
///   hasPermission     → Bool
///   requestPermission → Bool (suspends until user picks in Health Connect UI)
///   getStepsForRange  → List<Map<dateMs, steps>>, one entry per day with data
class HealthChannel(
    private val activity: ComponentActivity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val permissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class)
    )

    private var pendingPermissionResult: MethodChannel.Result? = null

    /// Launcher MUST be registered before the activity reaches STARTED state.
    /// We register lazily on first `register()` call, which happens from
    /// `configureFlutterEngine` (called inside onCreate, before onStart).
    private val permissionLauncher: ActivityResultLauncher<Set<String>> =
        activity.registerForActivityResult(
            PermissionController.createRequestPermissionResultContract()
        ) { granted ->
            val pending = pendingPermissionResult
            pendingPermissionResult = null
            pending?.success(granted.containsAll(permissions))
        }

    fun register() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "sdkStatus" -> {
                    try {
                        result.success(HealthConnectClient.getSdkStatus(activity))
                    } catch (t: Throwable) {
                        result.error("SDK_STATUS_FAILED", t.message, null)
                    }
                }
                "hasPermission" -> {
                    scope.launch {
                        try {
                            val granted = client().permissionController.getGrantedPermissions()
                            result.success(granted.containsAll(permissions))
                        } catch (t: Throwable) {
                            result.error("CHECK_FAILED", t.message, null)
                        }
                    }
                }
                "requestPermission" -> {
                    if (pendingPermissionResult != null) {
                        result.error("BUSY", "Permission request already in flight", null)
                        return@setMethodCallHandler
                    }
                    pendingPermissionResult = result
                    try {
                        permissionLauncher.launch(permissions)
                    } catch (t: Throwable) {
                        pendingPermissionResult = null
                        result.error("LAUNCH_FAILED", t.message, null)
                    }
                }
                "getStepsForRange" -> {
                    val startMs = call.argument<Long>("startMs")
                    val endMs = call.argument<Long>("endMs")
                    val zoneId = call.argument<String>("zoneId")
                    if (startMs == null || endMs == null) {
                        result.error("BAD_ARGS", "startMs and endMs required", null)
                        return@setMethodCallHandler
                    }
                    scope.launch {
                        try {
                            result.success(fetchStepsPerDay(startMs, endMs, zoneId))
                        } catch (t: Throwable) {
                            result.error("READ_FAILED", t.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun client(): HealthConnectClient = HealthConnectClient.getOrCreate(activity)

    /// Step total per local day in [zoneId], one [client.aggregate] call per day.
    ///
    /// We deliberately do NOT sum raw StepsRecords from `readRecords` here:
    /// Health Connect is a shared store, and on most phones two providers
    /// (e.g. Samsung Health AND the Google/Health-Connect platform) both log
    /// the same physical steps. Summing every record double-counts them — the
    /// tell-tale symptom is every day's total coming out exactly 2× (always an
    /// even number). The `aggregate` API resolves overlapping data from
    /// different origins with Health Connect's own priority/de-dup rules, so
    /// each physical step is counted once.
    ///
    /// `aggregate` doesn't slice by calendar day in an arbitrary zone, so we
    /// walk day-by-day in [zoneId] and aggregate each day's window separately.
    /// Each window is clipped to [startMs, endMs] so a partial first/last day
    /// (e.g. "today" ending at `now`) isn't over-counted. `dateMs` is midnight
    /// of that day in [zoneId] — the same key the Dart side writes under.
    private suspend fun fetchStepsPerDay(
        startMs: Long,
        endMs: Long,
        zoneId: String?,
    ): List<Map<String, Long>> {
        val client = client()
        val zone = try {
            if (zoneId.isNullOrEmpty()) ZoneId.systemDefault() else ZoneId.of(zoneId)
        } catch (_: Throwable) {
            ZoneId.systemDefault()
        }

        val rangeStart = Instant.ofEpochMilli(startMs)
        val rangeEnd = Instant.ofEpochMilli(endMs)

        val out = mutableListOf<Map<String, Long>>()
        var day = rangeStart.atZone(zone).toLocalDate()
        val lastDay = rangeEnd.atZone(zone).toLocalDate()

        while (!day.isAfter(lastDay)) {
            val dayStartInstant = day.atStartOfDay(zone).toInstant()
            val dayEndInstant = day.plusDays(1).atStartOfDay(zone).toInstant()

            val clipStart = if (dayStartInstant.isBefore(rangeStart)) rangeStart else dayStartInstant
            val clipEnd = if (dayEndInstant.isAfter(rangeEnd)) rangeEnd else dayEndInstant

            if (clipStart.isBefore(clipEnd)) {
                val response = client.aggregate(
                    AggregateRequest(
                        metrics = setOf(StepsRecord.COUNT_TOTAL),
                        timeRangeFilter = TimeRangeFilter.between(clipStart, clipEnd),
                    )
                )
                val count = response[StepsRecord.COUNT_TOTAL]
                if (count != null && count > 0) {
                    out.add(
                        mapOf(
                            "dateMs" to dayStartInstant.toEpochMilli(),
                            "steps" to count,
                        )
                    )
                }
            }
            day = day.plusDays(1)
        }
        return out
    }

    companion object {
        private const val CHANNEL_NAME = "com.calma.health"
    }
}
