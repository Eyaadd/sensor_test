import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:http/http.dart' as http;

class SensorSample {
  final double time;
  final double ax, ay, az;
  final double wx, wy, wz;

  SensorSample(this.time, this.ax, this.ay, this.az, this.wx, this.wy, this.wz);

  Map<String, dynamic> toJson() => {
    'time': time,
    'ax': ax,
    'ay': ay,
    'az': az,
    'wx': wx,
    'wy': wy,
    'wz': wz,
  };
}

Future<void> collectAndSendSensorData() async {
  final List<SensorSample> samples = [];
  double startTime = DateTime.now().millisecondsSinceEpoch.toDouble();

  AccelerometerEvent? accEvent;
  GyroscopeEvent? gyroEvent;

  final accSub = accelerometerEvents.listen((event) {
    accEvent = event;
  });

  final gyroSub = gyroscopeEvents.listen((event) {
    gyroEvent = event;
  });

  while (samples.length < 100) {
    await Future.delayed(Duration(milliseconds: 20));
    if (accEvent != null && gyroEvent != null) {
      final now = DateTime.now().millisecondsSinceEpoch.toDouble();
      final time = (now - startTime) / 1000.0;

      samples.add(SensorSample(
        time,
        accEvent!.x,
        accEvent!.y,
        accEvent!.z,
        gyroEvent!.x,
        gyroEvent!.y,
        gyroEvent!.z,
      ));
    }
  }

  await accSub.cancel();
  await gyroSub.cancel();

  final payload = {
    "sensor_data": samples.map((s) => s.toJson()).toList(),
  };

  final uri = Uri.parse("http://192.168.1.65:8000/predict");
  final response = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(payload),
  );

  if (response.statusCode == 200) {
    print("✅ Prediction result:");
    print(response.body);
  } else if (response.statusCode == 307 || response.statusCode == 308) {
    final redirectedUri = Uri.parse(response.headers['location']!);
    print("🔁 Redirected to: $redirectedUri");

    final redirectedResponse = await http.post(
      redirectedUri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (redirectedResponse.statusCode == 200) {
      print("✅ Prediction result after redirect:");
      print(redirectedResponse.body);
    } else {
      print("❌ Redirected error: ${redirectedResponse.statusCode}");
      print(redirectedResponse.body);
    }
  } else {
    print("❌ Error: ${response.statusCode}");
    print(response.body);
  }
}

// Trigger this when the app starts
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Call the function after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      collectAndSendSensorData();
    });

    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Collecting Sensor Data...'),
        ),
      ),
    );
  }
}
