import 'dart:io';
class MyPlatform {
  static const tvMode = String.fromEnvironment('TV_MODE', defaultValue: 'OFF');

  static bool get isTv => tvMode == 'ON';

  static bool get isIOS => !isTv && Platform.isIOS;
  static bool get isAndroid => !isTv && Platform.isAndroid;
  static bool get isMacOS => !isTv && Platform.isMacOS;

  static bool get isTVOS => isTv && Platform.isIOS;
  static bool get isAndroidTV => isTv && Platform.isAndroid;

  static bool get isMobile => isIOS || isAndroid;
  static bool get isDesktop => isMacOS;
}
