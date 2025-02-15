import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String globleTopic="";
const platformMacOS = MethodChannel('com.example/deviceControl');
const platform = MethodChannel('com.example/network');
final GlobalKey boundaryKey = GlobalKey();