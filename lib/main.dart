import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(SensorApp());
}

class SensorApp extends StatefulWidget {
  @override
  _SensorAppState createState() => _SensorAppState();
}

class _SensorAppState extends State<SensorApp> {
  List<List<double>> sensorData = [];
  StreamSubscription? _accelerometerSubscription;
  StreamSubscription? _gyroscopeSubscription;
  List<double> latestAccelerometer = [0.0, 0.0, 0.0];
  List<double> latestGyroscope = [0.0, 0.0, 0.0];
  String apiResponse = ""; // Variable to store the API response

  @override
  void initState() {
    super.initState();
    collectSensorData();
  }

  void collectSensorData() {
    List<double>? previousAccelerometer; // Store previous readings

    _accelerometerSubscription = accelerometerEvents.listen((event) {
      latestAccelerometer = [event.x, event.y, event.z];
    });

    _gyroscopeSubscription = gyroscopeEvents.listen((event) {
      latestGyroscope = [event.x, event.y, event.z];

      if (previousAccelerometer != null) {
        if (sensorData.length < 100) {
          sensorData.add([
            latestAccelerometer[0], latestAccelerometer[1], latestAccelerometer[2], // Current readings
            latestAccelerometer[0] - previousAccelerometer![0], // ΔX
            latestAccelerometer[1] - previousAccelerometer![1], // ΔY
            latestAccelerometer[2] - previousAccelerometer![2]  // ΔZ
          ]);
        } else {
          _accelerometerSubscription?.cancel();
          _gyroscopeSubscription?.cancel();
          sendDataToAPI();
        }
      }
      previousAccelerometer = List.from(latestAccelerometer); // Update previous readings
    }, onError: (error) {
      print("Error: $error");
    }, cancelOnError: false);
  }

  Future<void> sendDataToAPI() async {
    final url = Uri.parse("http://192.168.1.37:8000/predict/");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"features": sensorData}),
      );

      print("Response Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      // Update the state with the API response
      setState(() {
        apiResponse = "Status Code: ${response.statusCode}\nResponse Body: ${response.body}";
      });
    } catch (error) {
      print("Error sending data: $error");

      // Update the state with the error message
      setState(() {
        apiResponse = "Error sending data: $error";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text("Sensor Data Collector")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (sensorData.length < 100)
                Text("Collecting Data... (${sensorData.length}/100)")
              else
                Text("Data Sent Successfully!"),
              if (apiResponse.isNotEmpty) // Display the API response if available
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    apiResponse,
                    style: TextStyle(fontSize: 16, color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    super.dispose();
  }
}