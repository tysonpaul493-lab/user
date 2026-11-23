package com.liferoute.emergency

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.liferoute.emergency/sim_info"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSimInfo" -> {
                    try {
                        val simInfo = getSimDetails()
                        result.success(simInfo)
                    } catch (e: Exception) {
                        result.success(mapOf("hasSim" to false, "simNumber" to null, "carrier" to null, "simCount" to 0))
                    }
                }
                else -> result.notImplemented()
            }
        }
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

        val hasPhoneStatePermission = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.READ_PHONE_STATE
        ) == PackageManager.PERMISSION_GRANTED

        val hasNumbersPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_PHONE_NUMBERS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            hasPhoneStatePermission
        }

        val allSimNumbers = ArrayList<String>()
        val allCarriers = ArrayList<String>()

        if (hasPhoneStatePermission || hasNumbersPermission) {
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
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && hasNumbersPermission) {
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
            "simNumber" to simNumber,
            "simNumbers" to allSimNumbers,
            "carrier" to carrierName,
            "carriers" to allCarriers,
            "simCount" to simCount
        )
    }
}
