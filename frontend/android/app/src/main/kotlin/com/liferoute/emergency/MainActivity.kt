package com.liferoute.emergency

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.liferoute.emergency/sim_info"
    private val SIM_PERMISSION_REQUEST_CODE = 9108

    private var simChannel: MethodChannel? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var simStateReceiver: BroadcastReceiver? = null
    private var subscriptionsListener: SubscriptionManager.OnSubscriptionsChangedListener? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        simChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSimInfo" -> {
                    try {
                        result.success(getSimDetails())
                    } catch (_: Exception) {
                        result.success(
                            mapOf(
                                "hasSim" to false,
                                "hasPermission" to hasAnySimPermission(),
                                "hasNumbersPermission" to hasNumbersPermission(),
                                "simNumber" to null,
                                "simNumbers" to emptyList<String>(),
                                "carrier" to null,
                                "carriers" to emptyList<String>(),
                                "simCount" to 0
                            )
                        )
                    }
                }
                "requestSimPermission" -> {
                    if (hasNumbersPermission() && hasPhoneStatePermission()) {
                        result.success(true)
                        return@setMethodCallHandler
                    }
                    val perms = mutableListOf(Manifest.permission.READ_PHONE_STATE)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        perms.add(Manifest.permission.READ_PHONE_NUMBERS)
                    }
                    pendingPermissionResult?.success(hasAnySimPermission())
                    pendingPermissionResult = result
                    ActivityCompat.requestPermissions(this, perms.toTypedArray(), SIM_PERMISSION_REQUEST_CODE)
                }
                else -> result.notImplemented()
            }
        }

        registerRealtimeSimWatchers()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SIM_PERMISSION_REQUEST_CODE) {
            val granted = hasAnySimPermission()
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
            notifySimChanged()
        }
    }

    private fun registerRealtimeSimWatchers() {
        try {
            if (simStateReceiver == null) {
                simStateReceiver = object : BroadcastReceiver() {
                    override fun onReceive(context: Context?, intent: Intent?) {
                        notifySimChanged()
                    }
                }
                val filter = IntentFilter("android.intent.action.SIM_STATE_CHANGED")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(simStateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
                } else {
                    @Suppress("DEPRECATION")
                    registerReceiver(simStateReceiver, filter)
                }
            }
        } catch (_: Exception) {}

        try {
            if (subscriptionsListener == null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                val subManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
                val listener = object : SubscriptionManager.OnSubscriptionsChangedListener() {
                    override fun onSubscriptionsChanged() {
                        notifySimChanged()
                    }
                }
                subscriptionsListener = listener
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    subManager?.addOnSubscriptionsChangedListener(mainExecutor, listener)
                } else {
                    @Suppress("DEPRECATION")
                    subManager?.addOnSubscriptionsChangedListener(listener)
                }
            }
        } catch (_: Exception) {}
    }

    private fun notifySimChanged() {
        runOnUiThread {
            try {
                simChannel?.invokeMethod("onSimChanged", getSimDetails())
            } catch (_: Exception) {}
        }
    }

    override fun onDestroy() {
        try {
            if (simStateReceiver != null) {
                unregisterReceiver(simStateReceiver)
                simStateReceiver = null
            }
        } catch (_: Exception) {}
        try {
            if (subscriptionsListener != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                val subManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
                subManager?.removeOnSubscriptionsChangedListener(subscriptionsListener)
                subscriptionsListener = null
            }
        } catch (_: Exception) {}
        super.onDestroy()
    }

    private fun hasPhoneStatePermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.READ_PHONE_STATE
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasNumbersPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_PHONE_NUMBERS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            hasPhoneStatePermission()
        }
    }

    private fun hasAnySimPermission(): Boolean {
        return hasPhoneStatePermission() || hasNumbersPermission()
    }

    private fun getSimDetails(): Map<String, Any?> {
        val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        var simNumber: String? = null
        var carrierName: String? = null
        var simCount = 0
        var hasSim = false

        if (telephonyManager != null) {
            carrierName = telephonyManager.simOperatorName.ifBlank { null }
            val simState = telephonyManager.simState
            hasSim = simState == TelephonyManager.SIM_STATE_READY
        }

        val hasPhoneState = hasPhoneStatePermission()
        val hasNumbers = hasNumbersPermission()
        val hasAnyPerm = hasPhoneState || hasNumbers

        val allSimNumbers = ArrayList<String>()
        val allCarriers = ArrayList<String>()

        if (hasAnyPerm) {
            try {
                val subManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
                if (subManager != null) {
                    val activeSubs = subManager.activeSubscriptionInfoList
                    if (!activeSubs.isNullOrEmpty()) {
                        simCount = activeSubs.size
                        hasSim = true
                        for (sub in activeSubs) {
                            val cName = sub.carrierName?.toString()
                            if (!cName.isNullOrBlank() && !allCarriers.contains(cName)) {
                                allCarriers.add(cName)
                            }
                            if (carrierName.isNullOrBlank()) {
                                carrierName = cName
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && hasNumbers) {
                                try {
                                    val num = subManager.getPhoneNumber(sub.subscriptionId)
                                    if (!num.isNullOrBlank() && !allSimNumbers.contains(num)) {
                                        allSimNumbers.add(num)
                                    }
                                } catch (_: Exception) {}
                            }
                            @Suppress("DEPRECATION")
                            val num = sub.number
                            if (!num.isNullOrBlank() && !allSimNumbers.contains(num)) {
                                allSimNumbers.add(num)
                            }
                        }
                        if (simNumber.isNullOrBlank() && allSimNumbers.isNotEmpty()) {
                            simNumber = allSimNumbers[0]
                        }
                    }
                }
            } catch (_: Exception) {}

            if (telephonyManager != null) {
                try {
                    @Suppress("DEPRECATION")
                    val line1 = telephonyManager.line1Number
                    if (!line1.isNullOrBlank() && !allSimNumbers.contains(line1)) {
                        allSimNumbers.add(line1)
                        if (simNumber.isNullOrBlank()) {
                            simNumber = line1
                        }
                    }
                } catch (_: Exception) {}
            }
        }

        return mapOf(
            "hasSim" to hasSim,
            "hasPermission" to hasAnyPerm,
            "hasNumbersPermission" to hasNumbers,
            "simNumber" to simNumber,
            "simNumbers" to allSimNumbers,
            "carrier" to carrierName,
            "carriers" to allCarriers,
            "simCount" to simCount
        )
    }
}
