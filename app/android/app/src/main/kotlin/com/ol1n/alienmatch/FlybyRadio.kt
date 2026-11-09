package com.ol1n.alienmatch

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.os.SystemClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

/**
 * Layer B fly-by radio (Prompts/01-GPS.md). Advertises the current rolling
 * identifier (RPI) and reports RPIs of nearby AlienMatch phones. No location
 * is read: BLUETOOTH_SCAN is declared with neverForLocation.
 *
 * Android peers carry the RPI in the scan response's service data. iOS peers
 * cannot advertise service data, so their RPI is read from a GATT
 * characteristic (connect, read, disconnect; cached for 5 minutes).
 */
@SuppressLint("MissingPermission")
class FlybyRadio(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var rpi = ByteArray(0)
    private var service: ParcelUuid? = null
    private var characteristic: UUID? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var scanner: BluetoothLeScanner? = null
    private val known = HashMap<String, Pair<ByteArray, Long>>()
    private val lastRead = HashMap<String, Long>()
    private val pending = HashMap<String, BluetoothGatt>()
    private val lastRssi = HashMap<String, Int>()

    init {
        MethodChannel(messenger, "alienmatch/flyby").setMethodCallHandler(this)
        EventChannel(messenger, "alienmatch/flyby/sightings").setStreamHandler(this)
    }

    private fun permissions(): Array<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) arrayOf(
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.BLUETOOTH_ADVERTISE,
            Manifest.permission.BLUETOOTH_CONNECT,
        ) else arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)

    private fun granted() = permissions().all { activity.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val r = call.argument<ByteArray>("rpi")
                val s = call.argument<String>("service")
                val c = call.argument<String>("characteristic")
                if (r == null || s == null || c == null) return result.success(false)
                rpi = r
                service = ParcelUuid(UUID.fromString(s))
                characteristic = UUID.fromString(c)
                if (!granted()) {
                    // Dart retries start() after the user answers the prompt.
                    activity.requestPermissions(permissions(), 4711)
                    return result.success(false)
                }
                result.success(startRadio())
            }
            "updateRpi" -> {
                call.argument<ByteArray>("rpi")?.let { rpi = it }
                // Advertisement payloads are immutable: restart advertising.
                stopAdvertising()
                startAdvertising()
                result.success(null)
            }
            "stop" -> {
                stopRadio()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startRadio(): Boolean {
        val adapter = (activity.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
        if (adapter == null || !adapter.isEnabled) return false
        advertiser = adapter.bluetoothLeAdvertiser
        scanner = adapter.bluetoothLeScanner ?: return false
        startAdvertising()
        val filter = ScanFilter.Builder().setServiceUuid(service).build()
        val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build()
        scanner?.startScan(listOf(filter), settings, scanCallback)
        return true
    }

    private fun stopRadio() {
        stopAdvertising()
        scanner?.stopScan(scanCallback)
        scanner = null
        for (g in pending.values) {
            g.disconnect()
            g.close()
        }
        pending.clear()
    }

    private val advertiseCallback = object : AdvertiseCallback() {}

    private fun startAdvertising() {
        val svc = service ?: return
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .setConnectable(false)
            .build()
        val data = AdvertiseData.Builder().addServiceUuid(svc).setIncludeDeviceName(false).build()
        val response = AdvertiseData.Builder().addServiceData(svc, rpi).setIncludeDeviceName(false).build()
        advertiser?.startAdvertising(settings, data, response, advertiseCallback)
    }

    private fun stopAdvertising() {
        advertiser?.stopAdvertising(advertiseCallback)
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val svc = service ?: return
            val addr = result.device.address
            lastRssi[addr] = result.rssi
            val data = result.scanRecord?.getServiceData(svc)
            if (data != null && data.size == rpi.size) return emit(data, result.rssi)
            val now = SystemClock.elapsedRealtime()
            known[addr]?.let { (value, at) -> if (now - at < 5 * 60_000) return emit(value, result.rssi) }
            if (pending.containsKey(addr)) return
            if ((lastRead[addr] ?: 0L) > now - 30_000) return
            lastRead[addr] = now
            pending[addr] = result.device.connectGatt(activity, false, gattCallback, android.bluetooth.BluetoothDevice.TRANSPORT_LE)
        }
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                gatt.discoverServices()
            } else {
                gatt.close()
                main.post { pending.remove(gatt.device.address) }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            val ch = service?.let { gatt.getService(it.uuid) }?.getCharacteristic(characteristic)
            if (ch == null) gatt.disconnect() else gatt.readCharacteristic(ch)
        }

        override fun onCharacteristicRead(gatt: BluetoothGatt, ch: BluetoothGattCharacteristic, value: ByteArray, status: Int) {
            onRead(gatt, value, status)
        }

        @Deprecated("API < 33")
        @Suppress("DEPRECATION")
        override fun onCharacteristicRead(gatt: BluetoothGatt, ch: BluetoothGattCharacteristic, status: Int) {
            onRead(gatt, ch.value ?: ByteArray(0), status)
        }

        private fun onRead(gatt: BluetoothGatt, value: ByteArray, status: Int) {
            val addr = gatt.device.address
            if (status == BluetoothGatt.GATT_SUCCESS && value.size == rpi.size) {
                main.post {
                    known[addr] = value to SystemClock.elapsedRealtime()
                    emit(value, lastRssi[addr] ?: -70)
                }
            }
            gatt.disconnect()
        }
    }

    private fun emit(value: ByteArray, rssi: Int) {
        main.post { sink?.success(mapOf("rpi" to value, "rssi" to rssi)) }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }
}
