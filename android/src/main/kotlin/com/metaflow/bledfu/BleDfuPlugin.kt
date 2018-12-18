package com.metaflow.bledfu

import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.PluginRegistry.Registrar
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.util.Log
import no.nordicsemi.android.dfu.DfuProgressListenerAdapter
import no.nordicsemi.android.dfu.DfuServiceInitiator
import no.nordicsemi.android.dfu.DfuServiceListenerHelper
import java.net.URL
import java.io.*


class BleDfuPlugin(private val registrar: Registrar) : MethodCallHandler, StreamHandler {

    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val plugin = BleDfuPlugin(registrar)

            val channel = MethodChannel(registrar.messenger(), "ble_dfu")
            channel.setMethodCallHandler(plugin)

            val eventChannel = EventChannel(registrar.messenger(), "ble_dfu_event")
            eventChannel.setStreamHandler(plugin)
        }
    }

    private var eventSink: EventSink? = null

    private val dfuProgressListener = object: DfuProgressListenerAdapter() {
        override fun onDfuAborted(deviceAddress: String?) {
            super.onDfuAborted(deviceAddress)
            eventSink?.error("DA", "Dfu aborted", "Dfu aborted")
        }

        override fun onError(deviceAddress: String?, error: Int, errorType: Int, message: String?) {
            super.onError(deviceAddress, error, errorType, message)
            eventSink?.error("DE", "Error $error", message)
        }

        override fun onDeviceDisconnected(deviceAddress: String?) {
            super.onDeviceDisconnected(deviceAddress)
            eventSink?.error("DD", "Device disconnected", "Device disconnected")
        }

        override fun onProgressChanged(deviceAddress: String?, percent: Int, speed: Float, avgSpeed: Float, currentPart: Int, partsTotal: Int) {
            super.onProgressChanged(deviceAddress, percent, speed, avgSpeed, currentPart, partsTotal)

            Log.d("BleDfuPlugin", "progress changed $percent")
            eventSink?.success("part: $currentPart, outOf: $partsTotal, to: $percent, speed: $avgSpeed")
        }
    }

    /// MethodCallHandler

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "scanForDfuDevice" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")

            "startDfu" -> {
                startDfuService(
                        result,
                        call.argument("deviceAddress")!!,
                        call.argument("deviceName")!!,
                        call.argument("url")!!)
            }

            else -> result.notImplemented()
        }
    }

    /// StreamHandler methods

    override fun onListen(arguments: Any?, events: EventSink) {
        Log.d("BleDfuPlugin", "onListen")
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        Log.d("BleDfuPlugin", "onCancel")
        eventSink = null
    }

    private fun startDfuService(result: Result, deviceAddress: String, deviceName: String, urlString: String) {
        Thread {
            Log.d("BleDfuPlugin", "startDfuService $deviceAddress $deviceName $urlString")

            val uri = downloadFile(urlString, "dfu.zip")

            if (uri == null) {
                result.error("DF", "Download failed", "Download failed")
            }
            else {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    DfuServiceInitiator.createDfuNotificationChannel(registrar.activity())
                }

                val starter = DfuServiceInitiator(deviceAddress)
                    .setDeviceName(deviceName)
                    .setKeepBond(false)

                // In case of a ZIP file, the init packet (a DAT file) must be included inside the ZIP file.
                starter.setZip(uri, null)

                DfuServiceListenerHelper.registerProgressListener(registrar.activity(), dfuProgressListener)

                // You may use the controller to pause, resume or abort the DFU process.
                val controller = starter.start(registrar.activity(), DfuService::class.java)

                result.success("success")
            }

        }.start()
    }

    private fun downloadFile(urlString: String, fileName: String) : Uri? {

        Log.d("BleDfuPlugin", "downloadFile $urlString $fileName")

        var count: Int

        try {
            val url = URL(urlString)
            val connection = url.openConnection()
            connection.connect()

            // input stream to read file - with 8k buffer
            val input = BufferedInputStream(url.openStream(), 8192)

            // External directory path to save file
            val folder = Environment.getExternalStorageDirectory().absolutePath + File.separator + "lumen_dfu"

            // Create lumen dfu folder if it does not exist
            val directory = File(folder)

            if (!directory.exists()) {
                directory.mkdirs()
            }

            val outputFile = File("$folder/$fileName")
            // Output stream to write file
            val output = FileOutputStream(outputFile)
            val data = ByteArray(4096)

            var total = 0
            count = input.read(data)

            while (count != -1) {
                total += count;
//                Log.d("BleDfuPlugin", "Progress: $total out of $lengthOfFile")

                // writing data to file
                output.write(data, 0, count)

                count = input.read(data)
            }

            // flushing output
            output.flush()

            // closing streams
            output.close()
            input.close()

            Log.d("BleDfuPlugin", "Successful download ${outputFile.absolutePath}")

            return Uri.fromFile(outputFile)

        } catch (e: Exception) {
            Log.e("BleDfuPlugin", "got exception $e")
            eventSink?.error("DF", "Download failed", e.message)
        }

        return null
    }
}
