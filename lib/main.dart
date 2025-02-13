import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_phoenix/flutter_phoenix.dart';

import 'package:digital_signage/provider/main_provider.dart';
import 'package:digital_signage/utils/globle_variable.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
void main() {
   HttpOverrides.global = MyHttpOverrides();
  runApp(
    Phoenix(
      child: MaterialApp(
        home: RepaintBoundary(
        key: boundaryKey,child:  MqttProvider(
          child: MyHomePage(), 
        ),
      )),
    )
  );
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MQTT App')),
      body: const Center(child: Text('Welcome to the MQTT App!')),
    );
  }
}