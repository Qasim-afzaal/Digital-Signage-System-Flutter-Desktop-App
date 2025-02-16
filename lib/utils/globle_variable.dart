import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String globleTopic="";
const platformMacOS = MethodChannel('com.example/deviceControl');
const platform = MethodChannel('com.example/network');
final GlobalKey boundaryKey = GlobalKey();

Map<String, dynamic> deviceInfoMap = {

    "mac_address": {
      "macAddress": [
        {"interface": "", "mac": ""},
        {"interface": "", "mac": ""}
      ],
      "platform": ""
    },
  

  "sender": "",
  "android_version": "",
  "webview_version": "",
  "last_seen": "",
  "device_model": "",
  "network_name": "",
  "time_zone": "",
  "last_ip_address": "",
  "latitude": 0.0,
  "longitude": 0.0,
  "cpu_information": {
    "cpu_architecture": "",
    "processor": "",
    "count_cores": 0
  },
  "memory_information": {
    "total_memory": 0,
    "available_memory": 0,
    "used_memory": 0
  },
  "battery_information": {
    "battery_percentage": 0,
    "formatted_voltage": 0,
    "formated_tempature": 0.0
  },
  "cpu_usage": 0.0,
  "cpu_detailed_information": {
    "cpu_detailed_information": [
      {
        "processor": "",
        "BogoMIPS": "",
        "Features": "",
        "CPU_implementer": "",
        "CPU_architecture": "",
        "CPU_variant": "",
        "CPU_part": "",
        "CPU_revision": ""
      }
    ]
  },
  "hardware_details": {
    "brand": "",
    "device_id": "",
    "model": "",
    "id": "",
    "sdk": 0,
    "manufacturer": "",
    "user": "",
    "type": "",
    "base": 0,
    "incremental": "",
    "board": "",
    "host": "",
    "fingerprint": "",
    "version_code": "",
    "hard_drive": "",
    "ram": ""
  },
  "storage_info": {"total_storage": "", "available_storage": ""},
  "ram_info": "",
  "device_resolution": {"resolution": "", "density": 0},
  "camera_details": ""
};
