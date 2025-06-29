package com.example.run_minder_google

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity: FlutterActivity(), SensorEventListener {
  private lateinit var sensorManager: SensorManager
  private var stepSensor: Sensor? = null
  private var baseStepCount = 0f
  private var eventSink: EventChannel.EventSink? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    EventChannel(flutterEngine.dartExecutor.binaryMessenger, "step_counter_stream")
      .setStreamHandler(object: EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
          eventSink = sink
          sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
          stepSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
          stepSensor?.also { sensor ->
            sensorManager.registerListener(
              this@MainActivity,
              sensor,
              SensorManager.SENSOR_DELAY_NORMAL
            )
          }
        }

        override fun onCancel(arguments: Any?) {
          sensorManager.unregisterListener(this@MainActivity)
          eventSink = null
        }
      })
  }

  override fun onSensorChanged(event: SensorEvent) {
    if (event.sensor.type == Sensor.TYPE_STEP_COUNTER) {
      if (baseStepCount == 0f) {
        baseStepCount = event.values[0]
      }
      val currentSteps = (event.values[0] - baseStepCount).toInt()
      eventSink?.success(currentSteps)
    }
  }

  override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}