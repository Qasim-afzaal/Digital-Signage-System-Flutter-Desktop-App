import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:screen_brightness/screen_brightness.dart';

import 'package:digital_signage/services/mqtt_client_service.dart';
import 'package:digital_signage/utils/globle_variable.dart';

MqttClientService mqttClientService = MqttClientService();

class DeviceSettingsViewModel with ChangeNotifier {
  Future<void> setVolumeForIOS(double value) async {
    const platform = MethodChannel('com.example/device_info');

    try {
      final result = await platform.invokeMethod('setVolume', {'value': value});
      print(result);
    } on PlatformException catch (e) {
      print("Failed to set volume: '${e.message}'.");
    }
  }

  Future<void> setBrightnessForIOS(double value) async {
    const platform = MethodChannel('com.example/device_info');

    try {
      final result =
          await platform.invokeMethod('setScreenBrightness', {'value': value});
      print(result);
    } on PlatformException catch (e) {
      print("Failed to set brightness: '${e.message}'.");
    }
  }

  Future<String> rebootDeviceForLinux() async {
    print("Attempting to restart the device...");

    // Execute the reboot command
    final result = await Process.run('pkexec', ['systemctl', 'reboot']);

    print('Exit code: ${result.exitCode}');
    print('Stdout: ${result.stdout}');
    print('Stderr: ${result.stderr}');

    if (result.exitCode != 0) {
      return 'Error: ${result.stderr}';
    }

    return 'Reboot command executed successfully';
  }

  Future<void> rebootDeviceForWindows() async {
    try {
      mqttClientService.publish(globleTopic, "success");
      final result = await Process.run(
          'powershell', ['-Command', 'Restart-Computer -Force']);

      if (result.exitCode != 0) {
        print('Error: ${result.stderr}');
      } else {
        print('Device is rebooting...');
      }
    } catch (e) {
      print('An error occurred: $e');
    }
  }

  Future<void> rebootDeviceForAndroid() async {
    print("reboot$globleTopic");
    try {
      mqttClientService.publish(globleTopic, "success");
      await platform.invokeMethod('rebootDevice');
    } on PlatformException catch (e) {
      print("Failed to reboot device: ${e.message}");
    }
  }

  Future<void> rebootDeviceForMacOS() async {
    try {
      mqttClientService.publish(globleTopic, "success");
      final String result = await platformMacOS.invokeMethod('rebootDevice');
      print(result);
    } on PlatformException catch (e) {
      print("Failed to reboot the device: '${e.message}'.");
    }
  }

  Future<String> changeVolumeForLinux(String volumePercentage) async {
    final result = await Process.run(
        'bash', ['-c', 'amixer set Master $volumePercentage%']);

    // Log command output and errors
    print('Command: amixer set Master $volumePercentage%');
    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');

    if (result.exitCode != 0) {
      return 'Error: ${result.stderr}';
    }

    return 'Volume changed to $volumePercentage%';
  }

  Future<String> getActiveOutputForLinux() async {
    final result = await Process.run(
        'bash', ['-c', 'xrandr | grep " connected" | awk \'{print \$1}\'']);

    if (result.exitCode != 0) {
      return 'Error: ${result.stderr}';
    }

    return result.stdout.trim();
  }

  Future<String> changeBrightnessForLinux(String brightnessLevel) async {
    String displayOutput = await getActiveOutputForLinux();

    // Check if an output was found
    if (displayOutput.isEmpty) {
      return 'No connected display found.';
    }

    final result = await Process.run('bash',
        ['-c', 'xrandr --output $displayOutput --brightness $brightnessLevel']);

    print(
        'Command: xrandr --output $displayOutput --brightness $brightnessLevel');
    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');

    if (result.exitCode != 0) {
      return 'Error: ${result.stderr}';
    }

    return 'Brightness changed to $brightnessLevel on $displayOutput';
  }

  Future<void> restartNetworkAdapterForWindows() async {
    try {
      // PowerShell command to list all network adapters and get their names and descriptions
      String listAdaptersCommand = '''
      Get-NetAdapter | Where-Object { \$_.Status -eq 'Up' } | Select-Object -Property Name, InterfaceDescription
    ''';

      // Execute PowerShell command to list active adapters
      final listResult =
          await Process.run('powershell', ['-Command', listAdaptersCommand]);

      if (listResult.exitCode != 0 || listResult.stdout.trim().isEmpty) {
        print('Error: No active network adapters found.');
        return;
      }

      // Split the output into lines and process each adapter
      List<String> adapterLines = listResult.stdout
          .trim()
          .split('\n')
          .skip(1)
          .toList(); // Skip header row

      if (adapterLines.isEmpty) {
        print('No active adapters found.');
        return;
      }

      for (var line in adapterLines) {
        List<String> adapterDetails =
            line.trim().split(RegExp(r'\s{2,}')); // Split by multiple spaces

        if (adapterDetails.length >= 2) {
          String adapterName = adapterDetails[0];
          String adapterDescription = adapterDetails[1];

          // Determine if it's Wi-Fi or Ethernet by checking the description
          if (adapterDescription.toLowerCase().contains('wi-fi') ||
              adapterDescription.toLowerCase().contains('wireless')) {
            print('Found Wi-Fi adapter: $adapterName ($adapterDescription)');
          } else if (adapterDescription.toLowerCase().contains('ethernet')) {
            print('Found Ethernet adapter: $adapterName ($adapterDescription)');
          } else {
            print('Skipping unknown adapter type: $adapterDescription');
            continue;
          }

          // PowerShell command to restart the network adapter
          String restartCommand =
              'Restart-NetAdapter -Name "$adapterName" -Confirm:\$false';

          // Execute PowerShell command to restart the adapter
          final restartResult = await Process.run('powershell', [
            '-Command',
            'Start-Process PowerShell -ArgumentList \'-NoProfile -ExecutionPolicy Bypass -Command "$restartCommand"\' -Verb RunAs'
          ]);

          // Check the output of the restart process
          print('Restart Output for $adapterName: ${restartResult.stdout}');
          print('Restart Error for $adapterName: ${restartResult.stderr}');
          if (restartResult.exitCode != 0) {
            print(
                'Error restarting adapter $adapterName: ${restartResult.stderr}');
          } else {
            print('Adapter "$adapterName" restarted successfully.');
          }
        }
      }
    } catch (e) {
      print('An error occurred: $e');
    }
  }

  static Future<void> setOrientationForAndroid(int orientation) async {
    try {
      const MethodChannel _channel = MethodChannel('com.example/network');

      await _channel
          .invokeMethod('setOrientation', {'orientation': orientation});
    } on PlatformException catch (e) {
      print("Failed to set orientation: '${e.message}'.");
    }
  }

  Future<String> restartNetworkForMac() async {
    const MethodChannel _channel = MethodChannel('com.example/networkControl');

    final String result = await _channel.invokeMethod('restartNetwork');
    return result;
  }

  Future<String> unmuteVolumeForLinux() async {
    final result =
        await Process.run('bash', ['-c', 'amixer set Master unmute']);

    // Log command output and errors
    print('Command: amixer set Master unmute');
    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');

    if (result.exitCode != 0) {
      return 'Error: ${result.stderr}';
    }

    return 'Volume unmuted';
  }

  Future<String> muteVolumeForLinux() async {
    final result = await Process.run('bash', ['-c', 'amixer set Master mute']);

    // Log command output and errors
    print('Command: amixer set Master mute');
    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');

    if (result.exitCode != 0) {
      return 'Error: ${result.stderr}';
    }

    return 'Volume muted';
  }

  Future<void> adjustBrightnessForWindows(int brightness) async {
    try {
      // Ensure brightness is between 0-100
      if (brightness < 0) brightness = 0;
      if (brightness > 100) brightness = 100;

      // Prepare the PowerShell command to adjust the brightness
      String command =
          '(Get-WmiObject -Namespace root/wmi -Class WmiMonitorBrightnessMethods).WmiSetBrightness(1, $brightness)';

      // Execute PowerShell command with RunAs for elevation
      final result = await Process.run('powershell', [
        '-Command',
        'Start-Process PowerShell -ArgumentList \'-NoProfile -ExecutionPolicy Bypass -Command "$command"\' -Verb RunAs'
      ]);

      // Check the output
      print('Output: ${result.stdout}');
      print('Error: ${result.stderr}');
      if (result.exitCode != 0) {
        print('Error adjusting brightness: ${result.stderr}');
      } else {
        print('Brightness changed to $brightness%');
      }
    } catch (e) {
      print('An error occurred: $e');
    }
  }

  Future<void> changeVolumeForWindows(int volume) async {
    try {
      // Ensure volume is between 0-100
      if (volume < 0) volume = 0;
      if (volume > 100) volume = 100;

      // Run PowerShell command to set the volume
      final result = await Process.run('powershell',
          ['-Command', 'Set-AudioDevice -PlaybackVolume $volume']);

      if (result.exitCode != 0) {
        print('Error changing volume: ${result.stderr}');
      } else {
        print('Volume changed to $volume%');
      }
    } catch (e) {
      print('An error occurred: $e');
    }
  }

  Future<void> unmuteVolumeForWindows() async {
    try {
      // Run PowerShell command to set the playback volume to 50% (unmute)
      final result = await Process.run(
          'powershell', ['-Command', 'Set-AudioDevice -PlaybackVolume 50']);

      if (result.exitCode != 0) {
        print('Error unmuting volume: ${result.stderr}');
      } else {
        print('Volume is unmuted (50%).');
      }
    } catch (e) {
      print('An error occurred: $e');
    }
  }

  Future<void> muteVolumeForWindows() async {
    try {
      // Run PowerShell command to mute the volume
      final result = await Process.run(
          'powershell', ['-Command', 'Set-AudioDevice -PlaybackVolume 0']);

      if (result.exitCode != 0) {
        print('Error muting volume: ${result.stderr}');
      } else {
        print('Volume is muted.');
      }
    } catch (e) {
      print('An error occurred: $e');
    }
  }

  Future<void> setVolumeForMac(int volume) async {
    const platform = MethodChannel('com.example/volumeControl');
    try {
      await platform.invokeMethod('setVolume', {'volume': volume});
    } on PlatformException catch (e) {
      print("Failed to set volume: ${e.message}");
    }
  }

  Future<void> _muteVolumeForMac() async {
    const platform = MethodChannel('com.example/volumeControl');
    try {
      await platform.invokeMethod('muteVolume');
    } on PlatformException catch (e) {
      print("Failed to mute volume: ${e.message}");
    }
  }

  Future<void> setVolumeForAndroid(int level) async {
    const MethodChannel _channel = MethodChannel('com.example/network');

    await _channel.invokeMethod('setVolume', {'level': level});
  }

  Future<void> setAppBrightnessForAndroid(double brightness) async {
    try {
      double currentBrightnesss = await ScreenBrightness().current;

      // Log the current brightness to verify
      print('Current brightness is: $currentBrightnesss');
      // Log the brightness value before setting
      print('Attempting to set brightness to: $brightness');

      // Set the application screen brightness
      await ScreenBrightness().setScreenBrightness(brightness);

      // Get the current brightness after setting
      double currentBrightness = await ScreenBrightness().current;

      // Log the current brightness to verify
      print('Current brightness is: $currentBrightness');
    } catch (e) {
      // Handle any errors
      print('Failed to set brightness: $e');
    }
  }

  Future<void> muteVolumeForAndroid() async {
    try {
      const platform = MethodChannel('com.example/network');

      final result = await platform.invokeMethod('muteVolume');
      print(
          result); // Prints "Volume muted" or the success message from Android
    } on PlatformException catch (e) {
      print("Failed to mute volume: '${e.message}'.");
    }
  }

  Future<void> unmuteVolumeForAndroid() async {
    const platform = MethodChannel('com.example/network');
    try {
      await platform.invokeMethod('unmuteVolume');
      print('Volume unmuted');
    } on PlatformException catch (e) {
      print('Failed to unmute volume: ${e.message}');
    }
  }

  Future<void> muteVolumeForMac() async {
    const platform = MethodChannel('com.example/volumeControl');
    try {
      await platform.invokeMethod('muteVolume');
      mqttClientService.publish(globleTopic, "success");
    } on PlatformException catch (e) {
      print("Failed to mute volume: ${e.message}");
    }
  }

  Future<String> unmuteVolumeForMac() async {
    const MethodChannel _channel = MethodChannel('com.example/volumeControl');
    final String result = await _channel.invokeMethod('unmuteVolume');
    return result;
  }

  Future<void> restartNetworkForAndroid() async {
    try {
      final result = await platform.invokeMethod('restartNetwork');
      print(result); // Prints "Wi-Fi restarted" or success message from Android
    } on PlatformException catch (e) {
      print("Failed to restart Wi-Fi: '${e.message}'.");
    }
  }
}
