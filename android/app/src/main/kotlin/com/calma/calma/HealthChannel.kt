package com.calma.calma

import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.ReadRecordsRequest
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
                    if (startMs == null || endMs == null) {
                        result.error("BAD_ARGS", "startMs and endMs required", null)
                        return@setMethodCallHandler
                    }
                    scope.launch {
                        try {
                            result.success(fetchStepsPerDay(startMs, endMs))
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

    /// Reads all StepsRecords in [startMs..endMs] and aggregates per local day.
    /// Paginates through the full result set — a single page is capped at 1000
    /// records, and step providers (Samsung Health etc.) emit many records per
    /// day, so without paging we'd cut off the chart partway through the month.
    private suspend fun fetchStepsPerDay(
        startMs: Long,
        endMs: Long,
    ): List<Map<String, Long>> {
        val client = client()
        val timeRange = TimeRangeFilter.between(
            Instant.ofEpochMilli(startMs),
            Instant.ofEpochMilli(endMs),
        )
        val zone = ZoneId.systemDefault()
        val perDayMillis = mutableMapOf<Long, Long>()

        var pageToken: String? = null
        do {
            val request = if (pageToken == null) {
                ReadRecordsRequest(
                    recordType = StepsRecord::class,
                    timeRangeFilter = timeRange,
                    pageSize = 1000,
                )
            } else {
                ReadRecordsRequest(
                    recordType = StepsRecord::class,
                    timeRangeFilter = timeRange,
                    pageSize = 1000,
                    pageToken = pageToken,
                )
            }
            val response = client.readRecords(request)
            for (record in response.records) {
                val day = record.startTime.atZone(zone).toLocalDate()
                val dayStart = day.atStartOfDay(zone).toInstant().toEpochMilli()
                perDayMillis.merge(dayStart, record.count) { a, b -> a + b }
            }
            pageToken = response.pageToken
        } while (pageToken != null)

        return perDayMillis.entries.map { (dayMs, steps) ->
            mapOf("dateMs" to dayMs, "steps" to steps)
        }
    }

    companion object {
        private const val CHANNEL_NAME = "com.calma.health"
    }
}
