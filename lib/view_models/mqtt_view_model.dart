import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:battery_plus/battery_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:geolocator/geolocator.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_info2/system_info2.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:digital_signage/models/compaign_model.dart';
import 'package:digital_signage/models/intractivity_model.dart';
import 'package:digital_signage/models/play_list_model.dart';
import 'package:digital_signage/utils/globle_variable.dart';
import 'package:digital_signage/view_models/system_apply_settings_vm.dart';

import '../data/api_repository/api_repository.dart';
import '../services/mqtt_client_service.dart';
import '../utils/constants.dart';

enum MqttState {
  initial,
  success,
  failure,
  noContent,
  campaignScreen,
  connectionScreen,
  noInternet,
  downloading,
  pairedScreen,
  playlistScreen
}

class MqttViewModel extends ChangeNotifier {
  final MqttClientService _mqttClientService;
  final DeviceSettingsViewModel deviceSettings = DeviceSettingsViewModel();

  MqttState _state = MqttState.initial;
  Map<String, dynamic> devicesinfo = deviceInfoMap;

  Map<String, dynamic>? _deviceInfo;
  List<dynamic> _mediaList = [];

  Map<String, dynamic>? get deviceInfo => _deviceInfo;
  static const _channel = MethodChannel('com.example/device_info');
  static const platform = MethodChannel('com.example/network');
  List<dynamic> get mediaList => _mediaList;
  MqttState get state => _state;
  String _topic = "";
  String get topic => _topic;

  PlayListModel? _playListModel;

  PlayListModel? get playListModel => _playListModel;

  CampaignModel? _campaignModel;

  CampaignModel? get campaignModel => _campaignModel;

  InteractivityModel? _interactivityModel;

  InteractivityModel? get interactivityModel => _interactivityModel;

  Map<String, String?> macAddresses = {
    'wlan0': null,
    'eth0': null,
  };
  Map<String, dynamic> storedJsonObj = {};
  Future<void> _loadStoredJsonObj() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? jsonString = prefs.getString('jsonObj');

    if (jsonString != null) {
      print('Retrieved JSON from SharedPreferences: $jsonString');
      storedJsonObj = jsonDecode(jsonString);
      print('Loaded JSON Object: $storedJsonObj');
      notifyListeners();
    } else {
      print('No JSON Object found in SharedPreferences.');
    }
  }

  bool? storeState;
  Future<void> getStoredState() async {
    final prefs = await SharedPreferences.getInstance();

    // Retrieve the 'storeState' value
    storeState = prefs.getBool('storeState');

    if (storeState != null) {
      debugPrint("Stored State: $storeState");
      // Use the value as needed
    } else {
      debugPrint("No 'storeState' value found.");
    }
  }

  Future<Map<String, dynamic>?> retrieveStoredResponse() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('apiResponse');

    if (jsonString != null) {
      final jsonResponse = jsonDecode(jsonString) as Map<String, dynamic>;
      print('Retrieved stored response: $jsonResponse');
      _topic = jsonResponse["player_code"];
      debugPrint("This is the response from the$topic API: $jsonResponse");
      globleTopic = _topic;
      return jsonResponse;
    } else {
      print('No stored response found.');
      return null;
    }
  }

  Future<void> loadDeviceInfoFromSharedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('deviceInfoMap');
    prefs.clear();
    if (jsonString != null) {
      // Decode the JSON string back to a Map
      deviceInfoMap = Map<String, dynamic>.from(jsonDecode(jsonString));
      print('Loaded device info from SharedPreferences: $deviceInfoMap');
    } else {
      print('No device info found in SharedPreferences.');
    }
  }

  MqttViewModel(this._mqttClientService) {
    _mqttClientService.receivedMessageNotifier.addListener(_updateMessage);
    _mqttClientService.onMessageReceived = _handleIncomingMessage;

    fetchAllInfo();
    _initializeBasedOnPlatform();
    _monitorConnectivity();
  }

  Future<void> captureAndSendScreenshot(String topic) async {
    try {
      // Find the render boundary for the widget
      RenderRepaintBoundary boundary = boundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      if (boundary.debugNeedsPaint) {
        debugPrint("Widget not rendered yet. Waiting for rendering...");
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Capture the screenshot as an image with lower pixel ratio
      final image =
          await boundary.toImage(pixelRatio: 0.5); // Reduce pixel ratio

      // Convert the image to byte data
      final ByteData? byteData = await image.toByteData(
          format: ImageByteFormat.png); // Use PNG for better quality

      if (byteData != null) {
        final Uint8List imageBytes = byteData.buffer.asUint8List();
        debugPrint("Original image size: ${imageBytes.length}");

        // Compress the image further
        final compressedImageBytes = await _compressImage(imageBytes);
        debugPrint("Compressed image size: ${compressedImageBytes.length}");

        // Convert to Base64 string
        final base64String = base64Encode(compressedImageBytes);

        // Publish the Base64-encoded string
        Map<String, dynamic> sendLog = {
          "action": "screenShot",
          "name": "screenshot",
          "type": "screenShot",
          "dateTime": DateTime.now()
              .toIso8601String(), // Current date and time in ISO 8601 format
        };

        _mqttClientService.publish(topic, jsonEncode(sendLog));
        _mqttClientService.publishMessage(topic, utf8.encode(base64String));
      } else {
        debugPrint("Failed to capture screenshot: ByteData is null.");
      }
    } catch (error) {
      debugPrint("Error capturing or sending screenshot: $error");
    }
  }

  Future<Uint8List> _compressImage(Uint8List imageBytes) async {
    // Compress the image further by lowering quality and size
    final compressedBytes = await FlutterImageCompress.compressWithList(
      imageBytes,
      minWidth: 400,
      minHeight: 300,
      quality: 5,
      format: CompressFormat.jpeg,
    );
    return compressedBytes;
  }

  // Monitor connectivity changes and reinitialize MQTT on connection recovery
  Future<void> _monitorConnectivity() async {
    await _loadStoredJsonObj();
    await getStoredState();
    await retrieveStoredResponse();
    await loadDeviceInfoFromSharedPreferences();
    InternetConnectionChecker().onStatusChange.listen((status) async {
      final hasConnection = status == InternetConnectionStatus.connected;

      if (hasConnection) {
        print("this is data $storedJsonObj");

        if (storedJsonObj["action"] == "publish_playlist") {
          await _mqttClientService.connect();

          subsibeMessage(_topic);
          publishMessage(globleTopic, jsonEncode(deviceInfoMap));
          _playListModel = playListModelFromJson(jsonEncode(storedJsonObj));

          for (var playlist in _playListModel!.data.playlist) {
            // Check if the playlist contains any media
            if (playlist.media != null && playlist.media!.isNotEmpty) {
              for (var media in playlist.media!) {
                print("Media URL: ${media.mediaUrl}");

                // Start downloading for each media item
                _startDownloadingForPlaylist();
              }
            }
          }
        } else if (storedJsonObj["action"] == "publish_campaign") {
          await _mqttClientService.connect();

          subsibeMessage(_topic);

          publishMessage(globleTopic, jsonEncode(deviceInfoMap));
          _campaignModel = campaignModelFromJson(jsonEncode(storedJsonObj));

          print(_mediaList);
          for (var campaign in _campaignModel!.data.playerCampaigns) {
            for (var zone in campaign.zones) {
              for (var media in zone.mediaItems) {
                print("Media URL: ${media.mediaUrl}");
                _startDownloadingForCampaign();
              }
            }
          }
        } else {
          print("elssssssssssssssssssssse caseeeeeee}");
          _mqttConnection();
        }
      } else {
        if (storedJsonObj["action"] == "publish_playlist") {
          _playListModel = playListModelFromJson(jsonEncode(storedJsonObj));
          print(_mediaList);
          for (var playlist in _playListModel!.data.playlist) {
            // Check if the playlist contains any media
            if (playlist.media != null && playlist.media!.isNotEmpty) {
              for (var media in playlist.media!) {
                print("Media URL: ${media.mediaUrl}");

                // Start downloading for each media item
                _startDownloadingForPlaylist();
              }
            }
          }
        } else if (storedJsonObj["action"] == "publish_campaign") {
          _campaignModel = campaignModelFromJson(jsonEncode(storedJsonObj));

          for (var campaign in _campaignModel!.data.playerCampaigns) {
            for (var zone in campaign.zones) {
              for (var media in zone.mediaItems) {
                print("Media URL: ${media.mediaUrl}");
                _startDownloadingForCampaign();
              }
            }
          }
        } else {
          _state = MqttState.noInternet;
          notifyListeners();
        }
      }
    });
  }

  Future<void> checkAndRequestPermissions() async {
    final status = await Permission.location.status;
    if (!status.isGranted) {
      await Permission.location.request();
    }
  }

  Future<void> fetchNetworkInfo() async {
    final NetworkInfo networkInfo = NetworkInfo();

    try {
      // Fetch network information
      final networkName = await networkInfo.getWifiName();
      final ipAddress = await networkInfo.getWifiIP();
      devicesinfo["last_ip_address"] = ipAddress;

      devicesinfo["network_name"] = networkName ?? "";

      print('Network Name (SSID): $networkName');
      print('IP Address: $ipAddress');
    } catch (e) {
      print('Failed to get network info: ${e.toString()}');
    }
  }

  Future<void> fetchBatteryInfo() async {
    final Battery battery = Battery();

    try {
      // Fetch battery information
      final batteryLevel = await battery.batteryLevel;
      print(batteryLevel);
    } catch (e) {
      print('Failed to get battery level: ${e.toString()}');
    }
  }

  String uniqueid = "";
  Future<String> getDeviceID() async {
    final result = await Process.run('powershell', [
      '-Command',
      'Get-WmiObject -Class Win32_ComputerSystemProduct | Select-Object -ExpandProperty UUID'
    ]);

    if (result.exitCode != 0) {
      return 'Error: ${result.stderr}';
    }

    return result.stdout.trim();
  }

  Future<void> fetchSystemInfo() async {
    try {
      // Common System Information
      final kernelArchitecture = SysInfo.kernelArchitecture.toString();
      print('Kernel Architecture: $kernelArchitecture');

      final kernelBitness = SysInfo.kernelBitness;
      print('Kernel Bitness: $kernelBitness');

      final kernelName = SysInfo.kernelName;
      print('Kernel Name: $kernelName');

      final kernelVersion = SysInfo.kernelVersion;
      print('Kernel Version: $kernelVersion');
      devicesinfo["android_version"] = kernelVersion;
      final operatingSystemName = SysInfo.operatingSystemName;
      print('Operating System Name: $operatingSystemName');

      final operatingSystemVersion = SysInfo.operatingSystemVersion;
      print('Operating System Version: $operatingSystemVersion');

      final userDirectory = SysInfo.userDirectory;
      print('User Directory: $userDirectory');

      final userId = SysInfo.userId;
      print('User ID: $userId');

      final userName = SysInfo.userName;
      print('User Name: $userName');

      final userSpaceBitness = SysInfo.userSpaceBitness;
      print('User Space Bitness: $userSpaceBitness');

      // Memory Information
      final totalPhysicalMemory = SysInfo.getTotalPhysicalMemory();
      print('Total Physical Memory: $totalPhysicalMemory bytes');

      final freePhysicalMemory = SysInfo.getFreePhysicalMemory();
      print('Free Physical Memory: $freePhysicalMemory bytes');

      final totalVirtualMemory = SysInfo.getTotalVirtualMemory();
      print('Total Virtual Memory: $totalVirtualMemory bytes');

      final freeVirtualMemory = SysInfo.getFreeVirtualMemory();
      print('Free Virtual Memory: $freeVirtualMemory bytes');
    } catch (e) {
      print("Failed to get system info: '${e.toString()}'.");
    }
  }

  Future<void> fetchAllInfo() async {
    await fetchNetworkInfo();
    await fetchBatteryInfo();
    await fetchSystemInfo();
  }

  Future<void> _initializeMacAddresses() async {
    final macAddressesMap = await getListOfMacAddresses();
    if (macAddressesMap != null) {
      final List<dynamic> macList = macAddressesMap['macAddress'];
      for (var item in macList) {
        final interface = item['interface'] as String?;
        final mac = item['mac'] as String?;
        if (interface != null && mac != null) {
          macAddresses[interface] = mac;
        }
      }

      print("Fetched MAC addresses: $macAddresses");
      devicesinfo["mac_address"]["macAddress"][0]["interface"] = "wlan0";
      devicesinfo["mac_address"]["macAddress"][1]["interface"] = "eth0";
      if (devicesinfo["mac_address"]["macAddress"][0]["interface"] == "wlan0") {
        devicesinfo["mac_address"]["macAddress"][0]["mac"] =
            macAddresses["wlan0"] ?? "";
      } else {
        devicesinfo["mac_address"]["macAddress"][1]["mac"] =
            macAddresses["eth0"] ?? "";
      }
      debugPrint("this is object$deviceInfoMap");
    } else {
      print("No MAC addresses found.");
    }
  }

  static Future<Map<String, dynamic>?> getListOfMacAddresses() async {
    final String? macAddressesJson =
        await platform.invokeMethod('getListOfMacAddresses');
    if (macAddressesJson != null) {
      return jsonDecode(macAddressesJson);
    }
    return null;
  }

  static Future<String?> getWifiMacAddress() async {
    return await _channel.invokeMethod('getWifiMacAddress');
  }

  static Future<String?> getEthernetMacAddress() async {
    return await _channel.invokeMethod('getEthernetMacAddress');
  }

  Future<void> _initializeBasedOnPlatform() async {
    if (Platform.isAndroid) {
      await _initializeMacAddresses();
      getDeviceInfoAndroid();
    } else if (Platform.isIOS) {
      final identifier =
          await _channel.invokeMethod<String>('getDeviceIdentifier');
      print('iOS Device Identifier: $identifier');
      devicesinfo["mac_address"]["platform"] = "IOS";
      devicesinfo["mac_address"]["macAddress"][0]["interface"] = "wlan0";
      if (devicesinfo["mac_address"]["macAddress"][0]["interface"] == "wlan0") {
        devicesinfo["mac_address"]["macAddress"][0]["mac"] = identifier;
      }
      getDeviceInfo();
    } else if (Platform.isMacOS) {
      await getDeviceIdentifiersForMac();
    } else if (Platform.isWindows) {
      await getSystemDataForWindows();
    } else if (Platform.isLinux) {
      await getDataForLinux();
    }
  }

  Future<void> getDeviceInfoAndroid() async {
    try {
      final String? result = await platform.invokeMethod('getSystemData');
      if (result != null) {
        print("Device Info from Android: $result");

        // Parse the JSON result
        final Map<String, dynamic> deviceInfo = jsonDecode(result);
        devicesinfo["device_info"] = deviceInfo;

        // Extract and parse the `cpu_detailed_information` field
        final cpuDetailedInfo =
            deviceInfo["cpu_detailed_information"] as String?;
        if (cpuDetailedInfo != null) {
          // Split the string by double newlines to separate processor blocks
          final processorBlocks = cpuDetailedInfo.trim().split('\n\n');

          final List<Map<String, String>> processorsList = [];

          for (var block in processorBlocks) {
            final lines = block.split('\n');
            final Map<String, String> processorMap = {};

            for (var line in lines) {
              final parts = line.split(':');
              if (parts.length == 2) {
                final key =
                    parts[0].trim().replaceAll(' ', '_').replaceAll('\t', '');
                final value = parts[1].trim();
                processorMap[key] = value;
              }
            }
            processorsList.add(processorMap);
          }

          // Update `cpu_detailed_information` in the device info map
          deviceInfo["cpu_detailed_information"] = processorsList;
        }

        debugPrint("this is ${deviceInfo["cpu_detailed_information"]}");
        devicesinfo["sender"] = "android";
        devicesinfo["android_version"] = deviceInfo["android_version"];
        devicesinfo["last_seen"] = deviceInfo["last_seen"];
        devicesinfo["device_model"] = deviceInfo["device_model"];
        devicesinfo["network_name"] = deviceInfo["network_name"];
        devicesinfo["time_zone"] = deviceInfo["time_zone"];
        devicesinfo["last_ip_address"] = deviceInfo["last_ip_address"];
        devicesinfo["cpu_information"]["processor"] =
            deviceInfo["cpu_information"]["processor"];
        devicesinfo["cpu_information"]["count_cores"] =
            deviceInfo["cpu_information"]["count_cores"];
        devicesinfo["memory_information"]["total_memory"] =
            int.parse(deviceInfo["memory_information"]["total_memory"]);
        devicesinfo["memory_information"]["available_memory"] =
            int.parse(deviceInfo["memory_information"]["available_memory"]);
        devicesinfo["memory_information"]["used_memory"] =
            int.parse(deviceInfo["memory_information"]["used_memory"]);
        devicesinfo["battery_information"]["battery_percentage"] = num.tryParse(
                deviceInfo["battery_information"]["battery_percentage"]
                        as String? ??
                    '') ??
            0;
        devicesinfo["battery_information"]["formatted_voltage"] = num.tryParse(
                deviceInfo["battery_information"]["formatted_voltage"]
                        as String? ??
                    '') ??
            0;

        devicesinfo["battery_information"]["formatted_temperature"] =
            num.tryParse(deviceInfo["battery_information"]
                        ["formatted_temperature"] as String? ??
                    '') ??
                0;
        devicesinfo["cpu_detailed_information"]["cpu_detailed_information"] =
            deviceInfo["cpu_detailed_information"];
        devicesinfo["hardware_details"] = deviceInfo["hardware_details"];
        devicesinfo["storage_info"]["total_storage"] =
            deviceInfo["storage_info"]["total_storage"];
        devicesinfo["storage_info"]["available_storage"] =
            deviceInfo["storage_info"]["available_storage"];
        devicesinfo["ram_info"] = deviceInfo["ram_info"];
        devicesinfo["device_resolution"]["width"] =
            deviceInfo["device_resolution"]["width"];
        devicesinfo["device_resolution"]["height"] =
            deviceInfo["device_resolution"]["height"];
        devicesinfo["camera_details"] =
            deviceInfo["camera_details"]["lens_facing"];
        debugPrint("this is full object$deviceInfoMap");
        _fetchCurrentLocation();
        notifyListeners();
      } else {
        print("Failed to get device info");
      }
    } on PlatformException catch (e) {
      print("Failed to get device info: '${e.message}'.");
    }
  }

  // Method to check and request location permissions
  Future<void> _getLocation() async {
    final status = await Permission.location.status;
    if (status.isGranted) {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      print(
          'location Latitude: ${position.latitude}, Longitude: ${position.longitude}');
    } else if (status.isDenied) {
      // Handle permission denied case
    } else if (status.isPermanentlyDenied) {
      // Handle permission permanently denied case
    }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      await _getLocation();

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      devicesinfo["latitude"] = position.latitude;
      devicesinfo["longitude"] = position.longitude;

      print('sadasdasasda$deviceInfoMap');
    } catch (e) {
      print('Error fetching location: $e');
    }
  }

  Future<void> getDeviceInfo() async {
    try {
      final Map<dynamic, dynamic>? result =
          await _channel.invokeMethod('getDeviceInfo');

      if (result != null) {
        print("this is result$result");
        _deviceInfo = Map<String, dynamic>.from(result);
        print('Device Info: $_deviceInfo');
        devicesinfo["sender"] = "ios";
        devicesinfo["android_version"] = _deviceInfo!["ios_version"];
        devicesinfo["storage_info"]["total_storage"] =
            _deviceInfo!["storage_info"]["total_storage"];
        devicesinfo["storage_info"]["available_storage"] =
            _deviceInfo!["storage_info"]["free_storage"];
        devicesinfo["cpu_information"]["count_cores"] =
            _deviceInfo!["cpu_information"]["processor_count"];
        devicesinfo["time_zone"] = _deviceInfo!["time_zone"];
        devicesinfo["battery_information"]["battery_percentage"] =
            _deviceInfo!["battery_information"]["battery_level"];
        devicesinfo["device_model"] = _deviceInfo!["name"];
        debugPrint("this is dzzata$deviceInfoMap");
        _fetchCurrentLocation();
      } else {
        _deviceInfo = null;
      }

      notifyListeners();
    } on PlatformException catch (e) {
      print("Failed to get device info: '${e.message}'.");
    }
  }

  double _screenWidth = 0;
  double _screenHeight = 0;

  double get screenWidth => _screenWidth;
  double get screenHeight => _screenHeight;

  void setScreenSize(double width, double height) {
    _screenWidth = width;
    _screenHeight = height;
    devicesinfo["device_resolution"] = "$_screenWidth x $screenHeight";

    notifyListeners();
  }

  Future<void> getSystemDataForWindows() async {
    try {
      final result = await getAllSystemInfo();
      if (result.exitCode == 0) {
        final output = result.stdout.trim();

        final Map<String, dynamic> systemInfo = jsonDecode(output);
        devicesinfo["sender"] = "windows";
        devicesinfo["time_zone"] = systemInfo["TimeZone"];
        devicesinfo["mac_address"]["platform"] = "Windows";
        devicesinfo["mac_address"]["macAddress"][0]["interface"] = "wlan0";
        if (devicesinfo["mac_address"]["macAddress"][0]["interface"] ==
            "wlan0") {
          devicesinfo["mac_address"]["macAddress"][0]["mac"] =
              systemInfo["DeviceID"];
        }
        devicesinfo["ram_info"] = systemInfo["InstalledRAM"].toString();

        devicesinfo["hardware_details"]["model"] = systemInfo["DeviceName"];
        print(systemInfo["TimeZone"]);
        devicesinfo["hardware_details"]["device_id"] = systemInfo["DeviceID"];
        devicesinfo["storage_info"]["total_storage"] =
            systemInfo["Drives"][0]["TotalSpaceGB"].toString();

        devicesinfo["storage_info"]["available_storage"] =
            systemInfo["Drives"][0]["FreeSpaceGB"].toString();
        print(systemInfo["TimeZone"]);
        devicesinfo["hardware_details"]["ram"] = systemInfo["InstalledRAM"];
        devicesinfo["cpu_information"]["cpu_architecture"] =
            systemInfo["CPUArchitecture"];
        devicesinfo["cpu_information"]["processor"] = systemInfo["CPUInfo"];
        systemInfo.forEach((key, value) {
          print('$key: $value');
        });

        _fetchCurrentLocation();
        await _checkPairingStatus();
      } else {
        print('Error: ${result.stderr}');
      }
    } catch (e) {
      print('An error occurred: $e');
    }
  }

  Future<ProcessResult> getAllSystemInfo() {
    return Process.run('powershell', [
      '-Command',
      '''
    # Get drive information
    \$drives = Get-WmiObject -Class Win32_LogicalDisk | ForEach-Object {
      [PSCustomObject]@{
        "DriveLetter" = \$_."DeviceID"
        "TotalSpaceGB" = [math]::round(\$_."Size" / 1GB, 2)
        "FreeSpaceGB" = [math]::round(\$_."FreeSpace" / 1GB, 2)
        "FileSystem" = \$_."FileSystem"
      }
    }

    # Get other system information
    \$info = @{
      "CPUInfo" = (Get-WmiObject -Class Win32_Processor | Select-Object -ExpandProperty Name);
      "CPUArchitecture" = (Get-WmiObject -Class Win32_Processor | Select-Object -ExpandProperty Architecture);
      "AvailableMemory" = (Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty FreePhysicalMemory);
      "TimeZone" = (Get-TimeZone).Id;
      
      "DeviceName" = (Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty Name);
      "InstalledRAM" = (Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty TotalPhysicalMemory);
      "DeviceID" = (Get-WmiObject -Class Win32_ComputerSystemProduct | Select-Object -ExpandProperty UUID);
      "Drives" = \$drives
    }

    # Output the information as JSON
    \$info | ConvertTo-Json
    '''
    ]);
  }

  Future<void> getDataForLinux() async {
    try {
      final result = await getAllSystemInfoFLinux();
      if (result.exitCode == 0) {
        final output = result.stdout.trim();

        // Parse the JSON output
        final Map<String, dynamic> systemInfo = jsonDecode(output);

        devicesinfo["sender"] = "Linux";
        devicesinfo["time_zone"] = systemInfo["TimeZone"];
        devicesinfo["mac_address"]["platform"] = "Linux";
        devicesinfo["mac_address"]["macAddress"][0]["interface"] = "wlan0";
        if (devicesinfo["mac_address"]["macAddress"][0]["interface"] ==
            "wlan0") {
          devicesinfo["mac_address"]["macAddress"][0]["mac"] =
              systemInfo["MacAddress"];
        }
        devicesinfo["ram_info"] = systemInfo["InstalledRAM"].toString();

        devicesinfo["hardware_details"]["model"] = systemInfo["DeviceName"];
        print(systemInfo["TimeZone"]);
        devicesinfo["hardware_details"]["device_id"] = systemInfo["MacAddress"];
        devicesinfo["storage_info"]["total_storage"] =
            systemInfo["DiskCapacity"].toString();

        print(systemInfo["TimeZone"]);
        devicesinfo["hardware_details"]["ram"] = systemInfo["InstalledRAM"];
        devicesinfo["cpu_information"]["cpu_architecture"] =
            systemInfo["CPUArchitecture"];
        devicesinfo["cpu_information"]["processor"] = systemInfo["CPUInfo"];

        // Print all the system information
        systemInfo.forEach((key, value) {
          print('$key: $value');
        });

        _fetchCurrentLocation();
        await _checkPairingStatus();
      } else {
        print('Error: ${result.stderr}');
      }
    } catch (e) {
      print('An error occurred: $e');
    }
  }

  Future<String> getDeviceIDForLinux() async {
    final result =
        await Process.run('bash', ['-c', 'sudo dmidecode -s system-uuid']);

    if (result.exitCode != 0) {
      return 'Error: ${result.stderr}';
    }

    return result.stdout.trim();
  }

  Future<ProcessResult> getAllSystemInfoFLinux() {
    return Process.run('bash', [
      '-c',
      '''
    # Get system information
    mac_address=\$(ip addr show | grep 'link/ether' | awk '{print \$2}' | head -n 1)
    serial_number=\$(sudo dmidecode -s system-serial-number)
    os_version=\$(uname -r)
    cpu_info=\$(lscpu | grep 'Model name' | awk -F: '{print \$2}' | xargs)
    cpu_architecture=\$(uname -m)
    available_memory=\$(free -m | grep 'Mem:' | awk '{print \$7}')
    ram_info=\$(sudo dmidecode -t memory | grep -A16 'Memory Device' | grep -E 'Size|Manufacturer|Speed' | grep -v 'No Module Installed')
    network_adapters=\$(ip link show | awk -F: '/^[0-9]+:/{print \$2}' | xargs)
    time_zone=\$(timedatectl | grep 'Time zone' | awk '{print \$3}')
    device_name=\$(hostname)
    installed_ram=\$(free -m | grep 'Mem:' | awk '{print \$2}')
    product_id=\$(sudo dmidecode -s system-product-name)
    disk_capacity=\$(df -h --total | grep 'total' | awk '{print \$2}')

    # Create JSON structure including Disk Capacity
    info=\$(cat <<EOF
    {
      "MacAddress": "\$mac_address",
      "SerialNumber": "\$serial_number",
      "OSVersion": "\$os_version",
      "CPUInfo": "\$cpu_info",
      "CPUArchitecture": "\$cpu_architecture",
      "AvailableMemory": "\$available_memory MB",
      "RAMInfo": "\$ram_info",
      "NetworkAdapters": "\$network_adapters",
      "TimeZone": "\$time_zone",
      "DeviceName": "\$device_name",
      "InstalledRAM": "\$installed_ram MB",
      "ProductID": "\$product_id",
      "DiskCapacity": "\$disk_capacity"
    }
EOF
    )

    # Output JSON
    echo "\$info"
    '''
    ]);
  }

  Future<Map<String, dynamic>?> getDeviceIdentifiersForMac() async {
    try {
      const channel = MethodChannel('com.example/systemInfo');

      // Fetch all system info (as a Map)
      final Map<dynamic, dynamic>? systemInfo =
          await channel.invokeMethod('getSystemInfo');
      // final battery = Battery();
      // final batteryLevel = await battery.batteryLevel;
      // final batteryStatus = await battery.batteryState;
      // final batteryPlugged = await battery.onBatteryStateChanged;
      // print(
      //     "this is batterydata $batteryLevel....$batteryPlugged...$batteryStatus");
      if (systemInfo != null) {
        // devicesinfo["mac_address"]["platform"] = "iOS";
        // devicesinfo["battery_information"]["battery_percentage"] = batteryLevel;
        devicesinfo["mac_address"]["macAddress"][0]["interface"] = "wlan0";
        if (devicesinfo["mac_address"]["macAddress"][0]["interface"] ==
            "wlan0") {
          devicesinfo["mac_address"]["macAddress"][0]["mac"] =
              systemInfo["uuid"];
        }
        print("System Info: $systemInfo");
        devicesinfo["android_version"] = systemInfo["os_version"];
        devicesinfo["platform"] = "macos";
        devicesinfo["device_resolution"] = systemInfo["device_resolution"];
        devicesinfo["time_zone"] = systemInfo["time_zone"];
        devicesinfo["cpu_information"] = systemInfo["cpu_information"];
        devicesinfo["memory_information"] = systemInfo["memory_information"];
        devicesinfo["storage_info"] = systemInfo["storage_info"];

        _fetchCurrentLocation();
        return Map<String, dynamic>.from(systemInfo);
      } else {
        print("Failed to retrieve system info.");
        return null;
      }
    } on PlatformException catch (e) {
      print("Failed to get device identifier: '${e.message}'.");
      return null;
    }
  }

  static Future<String?> getDeviceIdentifiers() async {
    try {
      final String? identifier =
          await _channel.invokeMethod('getDeviceIdentifier');
      print("Unique ID: $identifier");
      return identifier;
    } on PlatformException catch (e) {
      print("Failed to get device identifier: '${e.message}'.");
      return null;
    }
  }

  String get receivedMessage =>
      _mqttClientService.receivedMessageNotifier.value;

  Future<void> _mqttConnection() async {
    try {
      debugPrint("Attempting to reconnect to MQTT.");
      await _mqttClientService.connect();
      _state = MqttState.connectionScreen;
      notifyListeners();
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        await _checkPairingStatus();
      }
    } catch (error) {
      _state = MqttState.noInternet;
      notifyListeners();
      debugPrint("Error during MQTT reinitialization: $error");
    }
  }

  double _progress = 0.0;
  bool _isDownloading = false;
  String _downloadedFilePath = '';

  double get progress => _progress;
  bool get isDownloading => _isDownloading;
  String get downloadedFilePath => _downloadedFilePath;

  int _downloadCount = 0;
  double _overallProgress = 0.0;
  double get overallProgress => _overallProgress;

  final Map<String, List<String>> _mediaPath = {};
  Map<String, List<String>> get mediaPath => _mediaPath;

  void _startDownloadingForPlaylist() async {
    if (_state == MqttState.downloading) {
      print("Downloads are already in progress.");
      return;
    }

    _downloadCount = _playListModel!.data.playlist.fold(
      0,
      (count, playlist) => count + (playlist.media?.length ?? 0),
    );

    Map<String, dynamic> sendLog = {
      "action": "player_logs",
      "log": "Download Playlist",
      "name": "Player ${deviceInfo?["hardware_details"]["model"] ?? ""}",
      "type": "info",
      "date_time": DateTime.now().toIso8601String(),
    };
    _mqttClientService.publish(topic, jsonEncode(sendLog));
    print("Total media files to download: $_downloadCount");

    if (_downloadCount > 0) {
      _state = MqttState.downloading;
      notifyListeners();
    } else {
      _state = MqttState.noContent;
      notifyListeners();
      return;
    }

    int completedDownloads = 0;
    _overallProgress = 0.0;

    for (var playlist in _playListModel!.data.playlist) {
      _mediaPath[playlist.id] = [];

      for (var media in playlist.media!) {
        String mediaUrl = media.mediaUrl;
        String filename = _extractFilename(mediaUrl);
        Directory? directory = await _getDirectory();
        if (directory == null) {
          print('Unable to determine directory');
          throw Exception('Unable to determine directory');
        }

        String filePath = '${directory.path}/$filename';
        bool fileExists = await File(filePath).exists();

        if (fileExists) {
          _mediaPath[playlist.id]!.add(filePath);
          completedDownloads++;
          _updateOverallProgress(completedDownloads);
        } else {
          try {
            await downloadFileForPlaylist(mediaUrl, playlist.id);
            _mediaPath[playlist.id]!.add(filePath);
            completedDownloads++;
            _updateOverallProgress(completedDownloads);
          } catch (error) {
            print("Error downloading file: $error");
            Map<String, dynamic> errorLog = {
              "action": "player_logs",
              "log": "Download Playlist",
              "name":
                  "Player ${deviceInfo?["hardware_details"]["model"] ?? ""}",
              "type": "error",
              "date_time": DateTime.now().toIso8601String(),
            };

            _mqttClientService.publish(topic, jsonEncode(errorLog));
            _state = MqttState.failure;
            notifyListeners();
          }
        }
      }
    }

    if (completedDownloads == _downloadCount) {
      print("All media files for all playlists have been downloaded.");
      _updateMediaModelForPlaylist(); // Update model with local file paths
      _state = MqttState.playlistScreen;
      notifyListeners();
    }
  }

  void _updateOverallProgress(int completedDownloads) {
    _overallProgress = completedDownloads / _downloadCount;
    print('Overall progress: ${(_overallProgress * 100).toStringAsFixed(2)}%');
    notifyListeners();
  }

  void _updateMediaModelForPlaylist() {
    if (_playListModel != null) {
      for (var playlist in _playListModel!.data.playlist) {
        if (_mediaPath.containsKey(playlist.id)) {
          List<String> playlistMediaPaths = _mediaPath[playlist.id]!;
          for (int i = 0; i < playlist.media!.length; i++) {
            if (i < playlistMediaPaths.length) {
              String localPath = playlistMediaPaths[i];
              if (File(localPath).existsSync()) {
                playlist.media![i].mediaUrl = localPath; // Update to local path
              } else {
                print("File not found: $localPath");
              }
            }
          }
        }
      }
      _playListModel!.data.playlist.forEach((playlist) {
        playlist.media!.forEach((media) {
          print("Updated Media URL: ${media.mediaUrl}");
        });
      });
      notifyListeners();
    }
  }

  Future<void> downloadFileForPlaylist(String url, String playlistId,
      {int retries = 3}) async {
    int attempt = 0;
    while (attempt < retries) {
      try {
        attempt++;
        String filename = _extractFilename(url);
        Directory? directory = await _getDirectory();
        if (directory == null) {
          print('Unable to determine directory');
          throw Exception('Unable to determine directory');
        }

        String filePath = '${directory.path}/$filename';
        print('Downloading from URL: $url to $filePath');

        Dio dio = Dio();
        await dio.download(
          url,
          filePath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              double progress = received / total;
              print(
                  'Download progress: ${(progress * 100).toStringAsFixed(2)}%');
            }
          },
        );

        _mediaPath[playlistId]?.add(filePath);
        print('Download complete: $filePath');
        return; // Exit on successful download
      } catch (e) {
        print('Download attempt $attempt failed: $e');
        if (attempt >= retries) {
          print('Maximum retry attempts reached. Download failed.');
          throw Exception('Download failed after $retries attempts: $e');
        } else {
          print('Retrying download...');
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
  }

  final Map<String, List<String>> _mediaPaths =
      {}; // Change the key to a String

  void _startDownloadingForCampaign() async {
    if (_state == MqttState.downloading) {
      print("Downloads are already in progress.");
      return;
    }

    Map<String, dynamic> sendLog = {
      "action": "player_logs",
      "log": "Download Campaign",
      "name": "Player ${deviceInfo?["hardware_details"]["model"] ?? ""}",
      "type": "info",
      "date_time": DateTime.now().toIso8601String(),
    };

    _mqttClientService.publish(topic, jsonEncode(sendLog));

    // Calculate the total number of files to download from all zones
    _downloadCount = _campaignModel!.data.playerCampaigns
        .expand((campaign) => campaign.zones)
        .expand((zone) => zone.mediaItems)
        .length;

    print("Total files to download: $_downloadCount");

    if (_downloadCount > 0) {
      _state = MqttState.downloading;
      notifyListeners();
    } else {
      _state = MqttState.noContent;
      notifyListeners();
      return;
    }

    int completedDownloads = 0;
    _overallProgress = 0.0;

    for (var campaign in _campaignModel!.data.playerCampaigns) {
      for (var zone in campaign.zones) {
        String uniqueKey =
            '${campaign.campaignId}_${zone.id}'; // Unique key based on campaign_id and zone.id
        _mediaPaths[uniqueKey] = [];

        for (var media in zone.mediaItems) {
          String mediaUrl = media.mediaUrl;
          print("Starting download check for Media URL: $mediaUrl");

          String filename = _extractFilename(mediaUrl);
          print('Extracted filename: $filename');

          Directory? directory = await _getDirectory();
          if (directory == null) {
            print('Unable to determine directory');
            throw Exception('Unable to determine directory');
          }
          print('Download directory: ${directory.path}');

          String filePath = '${directory.path}/$filename';

          bool fileExists = await File(filePath).exists();
          if (fileExists) {
            print('File already exists: $filePath');
            _mediaPaths[uniqueKey]!.add(filePath);
            _updateMediaModelForCampaign();
            completedDownloads++;
            _overallProgress = completedDownloads / _downloadCount;
            print(
                'Overall progress: ${(_overallProgress * 100).toStringAsFixed(2)}%');

            notifyListeners();
          } else {
            await downloadFileForCampaign(mediaUrl, uniqueKey).then((_) {
              _mediaPaths[uniqueKey]!.add(filePath);
              completedDownloads++;
              _overallProgress = completedDownloads / _downloadCount;
              print(
                  'Overall progress: ${(_overallProgress * 100).toStringAsFixed(2)}%');
              notifyListeners();
            }).catchError((error) {
              print("Error downloading file: $error");
              Map<String, dynamic> sendLog = {
                "action": "player_logs",
                "log": "Download Campaign",
                "name":
                    "Player ${deviceInfo?["hardware_details"]["model"] ?? ""}",
                "type": "inerrorfo",
                "date_time": DateTime.now().toIso8601String(),
              };

              _mqttClientService.publish(topic, jsonEncode(sendLog));
              _state = MqttState.failure;
              notifyListeners();
            });
          }

          if (completedDownloads == _downloadCount) {
            print("All files processed.");

            _state = MqttState.campaignScreen;
            notifyListeners();
          }
        }
      }
    }
  }

  void _updateMediaModelForCampaign() {
    if (_campaignModel != null) {
      for (var campaign in _campaignModel!.data.playerCampaigns) {
        for (var zone in campaign.zones) {
          String uniqueKey = '${campaign.campaignId}_${zone.id}'; // Unique key
          if (_mediaPaths.containsKey(uniqueKey)) {
            List<String> zoneMediaPaths = _mediaPaths[uniqueKey]!;
            for (int i = 0;
                i < zone.mediaItems.length && i < zoneMediaPaths.length;
                i++) {
              zone.mediaItems[i].mediaUrl = zoneMediaPaths[i];
            }
          }
        }
        notifyListeners();
      }
    }
  }

  Future<void> downloadFileForCampaign(String url, String uniqueKey,
      {int retries = 3}) async {
    int attempt = 0;
    while (attempt < retries) {
      try {
        attempt++;
        String filename = _extractFilename(url);
        Directory? directory = await _getDirectory();
        if (directory == null) {
          print('Unable to determine directory');
          throw Exception('Unable to determine directory');
        }

        String filePath = '${directory.path}/$filename';

        Dio dio = Dio();
        print(
            'Attempt $attempt: Starting download from URL: $url to $filePath');

        await dio.download(
          url,
          filePath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              double progress = received / total;
              print(
                  'Download progress: ${(progress * 100).toStringAsFixed(2)}%');
            }
          },
        );

        _mediaPaths[uniqueKey]?.add(filePath);
        _updateMediaModelForCampaign();

        print('File downloaded to: $filePath');
        return; // Exit on successful download
      } catch (e) {
        print("Error: $e");
        // Handle error logic
      }
    }
  }

  Future<void> requestStoragePermission() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      var result = await Permission.storage.request();
      if (result.isGranted) {
        print('Storage permission granted');
      } else {
        print('Storage permission denied');
        throw Exception('Storage permission not granted');
      }
    }

    // For Android 11 and above
    if (Platform.isAndroid &&
        await Permission.manageExternalStorage.isGranted == false) {
      var result = await Permission.manageExternalStorage.request();
      if (result.isGranted) {
        print('External storage management permission granted');
      } else {
        print('External storage management permission denied');
        throw Exception('External storage management permission not granted');
      }
    }
  }

  String _extractFilename(String url, {String? mediaType}) {
    String decodedUrl = Uri.decodeFull(url);
    String filename = decodedUrl.split('/').last.split('?').first;
    if (mediaType != null) {
      switch (mediaType) {
        case 'audio/mpeg':
          filename += '.mp3';
          break;
        case 'audio/mp4':
          filename += '.m4a';
          break;
        case 'video/mp4':
          filename += '.mp4';
          break;
        case 'image/jpeg':
        case 'image/png':
        case 'image/gif':
          filename += '.jpg';
          break;
        default:
          break;
      }
    } else {
      if (url.contains('images')) {
        filename += '.jpg';
      }
    }

    return filename;
  }

  Future<Directory?> _getDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) {
      // Use the application documents directory for Android and iOS
      return await getApplicationDocumentsDirectory();
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // For desktop platforms, we can use getDownloadsDirectory() or application documents
      try {
        // Check if a method for getting downloads directory exists for the platform
        // For Windows/Linux/macOS, this may not exist, so fallback to applicationDocumentsDirectory
        return await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
      } catch (e) {
        // Fallback if getDownloadsDirectory doesn't work
        print(
            'Error getting downloads directory, falling back to applicationDocumentsDirectory: $e');
        return await getApplicationDocumentsDirectory();
      }
    }
    return null;
  }

  Future<void> _checkPairingStatus() async {
    Map<String, dynamic> requestBody;

    if (Platform.isAndroid) {
      requestBody = {
        "platform": "android",
        "macAddress": [
          {"mac": macAddresses['wlan0'] ?? "123123", "interface": "wlan0"},
          {"mac": macAddresses['eth0'] ?? "123213", "interface": "eth0"}
        ]
      };
    } else if (Platform.isIOS || Platform.isMacOS) {
      final uuid = Platform.isIOS
          ? await getDeviceIdentifiers()
          : (await getDeviceIdentifiersForMac())?["uuid"];

      requestBody = {"platform": "ios", "uuid": uuid ?? "unknown"};
      print(requestBody);
    } else if (Platform.isWindows) {
      requestBody = {"platform": "windows", "uuid": await getDeviceID()};
      print("windows$requestBody");
    } else if (Platform.isLinux) {
      requestBody = {"platform": "linux", "uuid": await getDeviceIDForLinux()};
      print("windows$requestBody");
    } else {
      debugPrint("Unsupported platform");

      return;
    }

    debugPrint("Request body: $requestBody");

    try {
      final response = await ApiRepository().postData(
        "3002/player/connection/",
        requestBody,
        null,
      );
      final jsonResponse = jsonEncode(response);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isSaved = await prefs.setString('apiResponse', jsonResponse);
      print("check status ::::$isSaved");

      _topic = response["player_code"];

      globleTopic = _topic;
      subsibeMessage(topic);
      await prefs.setString('deviceInfoMap', jsonEncode(deviceInfoMap));
      publishMessage(globleTopic, jsonEncode(deviceInfoMap));

      // await captureAndSendScreenshot(globleTopic);
      if (response["paired"] == false) {
        print("this is state screeen ${response["paired"]}");
        await prefs.setBool('storeState', response["paired"]);

        _state = MqttState.pairedScreen;
      } else if (response["paired"] == true) {
        // Start capturing screenshots every second
        // Timer.periodic(Duration(seconds: 1), (timer) async {
        //   await captureAndSendScreenshot(globleTopic);
        // });

        _state = MqttState.noContent;
      } else {
        _state = MqttState.failure;
      }
      notifyListeners();
    } catch (error) {
      _state = MqttState.failure;
      debugPrint("Error: $error");
    }

    notifyListeners();
  }

  void subsibeMessage(String topic) {
    _mqttClientService.subscribe(topic);
  }

  void publishMessage(String topic, String message) {
    _mqttClientService.publish(topic, message);
  }

  Future<void> restartApp() async {
    try {
      await _channel.invokeMethod('com.example/restartApp');
    } on PlatformException catch (e) {
      print("Failed to restart app: ${e.message}");
    }
  }

  String? _msg;
  String? get msg => _msg;
  String? _key;
  String? get key => _key;
  double? tapX;
  double? tapY;

  void setTapPosition(double x, double y) {
    tapX = x;
    tapY = y;
    // if(tapX==_interactivityModel!.data.interactivity[].regionX ||  tapY==_interactivityModel!.data.interactivity[].regionY){
    // print("i am in intractivity by region");

    // }
    notifyListeners();
  }

  void getKey(String keydata) {
    _key = keydata;
    notifyListeners();
    // Check if any key in the interactivity list matches _key (case-insensitive)
    bool keyFound = _interactivityModel?.data.interactivity.any(
            (interactivity) => interactivity.keyPress
                .any((key) => key.toUpperCase() == _key!.toUpperCase())) ??
        false;
    print("this is key data $keydata");
    if (keyFound) {
      print("I am in interactivity by key");
    } else {
      print("Key not found in interactivity");
    }
  }

  void _handleIncomingMessage(String message) async {
    print('Received message in ViewModel: $message');

    print('Received message in store state: $storeState');
    print('i am in recive msgss:');
// await restartApp();
    final jsonObj = jsonDecode(message);

    print('Saving JSON Object: $jsonObj');

    if (jsonObj["action"] == "publish_playlist" ||
        jsonObj["action"] == "publish_campaign") {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isSaved = await prefs.setString('jsonObj', jsonEncode(jsonObj));

      if (isSaved) {
        print('Data successfully saved to SharedPreferences');
      } else {
        print('Failed to save data to SharedPreferences');
      }
    }
    print(jsonObj["action"]);
    if (jsonObj["action"] == "action_reboot") {
      print("action rebooot");
      Map<String, dynamic> sendLog = {
        "action": "Action Reboot",
        "name": "Player ${deviceInfo!["hardware_details"]["model"]}",
        "type": "info",
        "dateTime": DateTime.now().toIso8601String(),
      };

      _mqttClientService.publish(topic, jsonEncode(sendLog));
      var data = {"success": true};
      publishMessage(globleTopic, jsonEncode(data));

      if (Platform.isMacOS) {
        deviceSettings.rebootDeviceForMacOS();
      } else if (Platform.isAndroid) {
        print("i am here for andorind");
        deviceSettings.rebootDeviceForAndroid();
      } else if (Platform.isWindows) {
        deviceSettings.rebootDeviceForWindows();
      } else if (Platform.isLinux) {
        deviceSettings.rebootDeviceForLinux();
      }
    } else if (jsonObj["action"] == "action_setup_player") {
      Map<String, dynamic> sendLog = {
        "action": "Action Setup Player",
        "name": "Player ${deviceInfo?["hardware_details"]["model"] ?? ""}",
        "type": "info",
        "dateTime": DateTime.now().toIso8601String(),
      };

      _mqttClientService.publish(topic, jsonEncode(sendLog));
      if (storeState != null) {
        if (storeState == false) {
          await _checkPairingStatus();
        }
      }
      // print("action mute${jsonObj["settings"]["mute_audio"]}");
      if (jsonObj["settings"]["mute_audio"] == true) {
        Map<String, dynamic> sendLog = {
          "action": "player_logs",
          "log": "Mute Audio",
          "name": "Player ${deviceInfo!["hardware_details"]["model"]}",
          "type": "info",
          "date_time": DateTime.now().toIso8601String(),
        };

        _mqttClientService.publish(topic, jsonEncode(sendLog));
        if (Platform.isMacOS) {
          deviceSettings.muteVolumeForMac();
        } else if (Platform.isAndroid) {
          print("i am here for andorind");
          deviceSettings.muteVolumeForAndroid();
        } else if (Platform.isWindows) {
          deviceSettings.muteVolumeForWindows();
        } else if (Platform.isLinux) {
          deviceSettings.muteVolumeForLinux();
        }
      } else if (jsonObj["settings"]["mute_audio"] == false) {
        Map<String, dynamic> sendLog = {
          "action": "player_logs",
          "log": "Unmute Audio",
          "name": "Player $globleTopic}",
          "type": "info",
          "date_time": DateTime.now().toIso8601String(),
        };

        _mqttClientService.publish(topic, jsonEncode(sendLog));
        if (Platform.isMacOS) {
          deviceSettings.unmuteVolumeForMac();
        } else if (Platform.isAndroid) {
          print("i am here for andorind");
          deviceSettings.unmuteVolumeForAndroid();
        } else if (Platform.isWindows) {
          deviceSettings.unmuteVolumeForWindows();
        } else if (Platform.isLinux) {
          deviceSettings.unmuteVolumeForLinux();
        }
      } else if (jsonObj["settings"]["brightness"]['value'] != null) {
        Map<String, dynamic> sendLog = {
          "action": "player_logs",
          "log": "brightness",
          "name": "Player ${deviceInfo?["hardware_details"]["model"] ?? ""}",
          "type": "info",
          "date_time": DateTime.now().toIso8601String(),
        };

        _mqttClientService.publish(topic, jsonEncode(sendLog));
        if (Platform.isMacOS) {
          print("No brightness For Mac");
          deviceSettings.unmuteVolumeForMac();
        } else if (Platform.isAndroid) {
          print("i am here for andorind");
          var value = jsonObj["settings"]["brightness"]['value'];
          deviceSettings.setAppBrightnessForAndroid(value);
        } else if (Platform.isWindows) {
          var res = jsonObj["settings"]["brightness"]['value'];
          deviceSettings.adjustBrightnessForWindows(res);
        } else if (Platform.isLinux) {
          var res = jsonObj["settings"]["brightness"]['value'];
          deviceSettings.changeBrightnessForLinux(res);
        }
      } else if (jsonObj["settings"]["volume"] != null) {
        Map<String, dynamic> sendLog = {
          "action": "player_logs",
          "log": "Volume",
          "name": "Player ${deviceInfo!["hardware_details"]["model"]}",
          "type": "info",
          "date_time": DateTime.now().toIso8601String(),
        };

        _mqttClientService.publish(topic, jsonEncode(sendLog));
        if (Platform.isMacOS) {
          print("No Volue For Mac");
          var res = jsonObj["settings"]["volume"];
          deviceSettings.setVolumeForMac(res);
        } else if (Platform.isAndroid) {
          print("i am here for andorind");
          var value = jsonObj["settings"]["volume"];
          deviceSettings.setVolumeForAndroid(value);
        } else if (Platform.isWindows) {
          var res = jsonObj["settings"]["volume"];
          deviceSettings.adjustBrightnessForWindows(res);
        } else if (Platform.isLinux) {
          var res = jsonObj["settings"]["brightness"];
          deviceSettings.changeBrightnessForLinux(res);
        }
      }
      var data = {"success": true};
      publishMessage(globleTopic, jsonEncode(data));
    } else if (jsonObj["action"] == "action click") {
      print(" i am in action  click");
    } else if (jsonObj["action"] == "publish_playlist") {
      Map<String, dynamic> sendLog = {
        "action": "player_logs",
        "log": "Publish Playlist",
        "name": "Player ${deviceInfo?["hardware_details"]["model"] ?? ""}",
        "type": "info",
        "date_time": DateTime.now().toIso8601String(),
      };

      _mqttClientService.publish(topic, jsonEncode(sendLog));
// Deserialize the JSON into the model
      // await _checkPairingStatus();
      _playListModel = playListModelFromJson(jsonEncode(jsonObj));
      // if (_playListModel!.data.playlist.isEmpty) {
      //   debugPrint("remove playlist and update screen");
      //   Map<String, dynamic> sendLog = {
      //     "action": "player_logs",
      //     "log": "Remove Campaign",
      //     "name": "Player ${deviceInfo?["hardware_details"]["model"] ?? ""}",
      //     "type": "info",
      //     "date_time": DateTime.now().toIso8601String(),
      //   };

      //   _mqttClientService.publish(topic, jsonEncode(sendLog));
      //   SharedPreferences prefs = await SharedPreferences.getInstance();
      //   prefs.clear();
      //   await _checkPairingStatus();
      // }
      print("model data ${_playListModel!.data.playlist}");

      for (var playlist in _playListModel!.data.playlist) {
        // Check if the playlist contains any media
        if (playlist.media != null && playlist.media!.isNotEmpty) {
          for (var media in playlist.media!) {
            print("Media URL: ${media.mediaUrl}");

            // Start downloading for each media item
            _startDownloadingForPlaylist();
          }
        }
      }
    } else if (jsonObj["action"] == "publish_campaign") {
      Map<String, dynamic> sendLog = {
        "action": "player_logs",
        "log": "Publish Campaign",
        "name": "Player ${deviceInfo?["hardware_details"]["model"] ?? ""}",
        "type": "info",
        "date_time": DateTime.now().toIso8601String(),
      };

      _mqttClientService.publish(topic, jsonEncode(sendLog));
      _msg = jsonObj["action"];
      _campaignModel = campaignModelFromJson(jsonEncode(jsonObj));
      print(
          "checking media on model ${_campaignModel!.data.playerCampaigns[0].zones[0].mediaItems[0].mediaUrl}");
      // if (_campaignModel!.data.playerCampaigns.isEmpty) {
      //   debugPrint("remove playlist and update screen");
      //   Map<String, dynamic> sendLog = {
      //     "action": "player_logs",
      //     "log": "Remove Campaign",
      //     "name": "Player ${deviceInfo?["hardware_details"]["model"] ?? ""}",
      //     "type": "info",
      //     "date_time": DateTime.now().toIso8601String(),
      //   };

      //   _mqttClientService.publish(topic, jsonEncode(sendLog));
      //   SharedPreferences prefs = await SharedPreferences.getInstance();
      //   prefs.clear();
      //   await _checkPairingStatus();
      // }

      print("i am in ccccccc");

      // await _checkPairingStatus();
      for (var campaign in _campaignModel!.data.playerCampaigns) {
        for (var zone in campaign.zones) {
          for (var media in zone.mediaItems) {
            print("Media URL: ${media.mediaUrl}");
            _startDownloadingForCampaign();
          }
        }
      }
    } else if (jsonObj["action"] == "publish_interactivity") {
      _interactivityModel = interactivityModelFromJson(jsonEncode(jsonObj));
      print("i am in intractvity");
    } else if (jsonObj["action"] == "remove_playlist") {
      debugPrint("remove playlist and update screen");
      Map<String, dynamic> sendLog = {
        "action": "player_logs",
        "log": "Remove Playlist",
        "name": "Player ${deviceInfo?["hardware_details"]["model"] ?? ""}",
        "type": "info",
        "date_time": DateTime.now().toIso8601String(),
      };

      _mqttClientService.publish(topic, jsonEncode(sendLog));
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.clear();

      await _checkPairingStatus();
    } else if (jsonObj["action"] == "action_delete") {
      Map<String, dynamic> sendLog = {
        "action": "player_logs",
        "log": "Action Delete",
        "name": "Player ${deviceInfo?["hardware_details"]["model"] ?? ""}",
        "type": "info",
        "date_time": DateTime.now().toIso8601String(),
      };

      _mqttClientService.publish(topic, jsonEncode(sendLog));
      debugPrint("remove playlist and update screen");
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.clear();
      await _checkPairingStatus();
      await getStoredState();
    } else if (jsonObj["action"] == "remove_campaign") {
      debugPrint("remove playlist and update screen");
      Map<String, dynamic> sendLog = {
        "action": "player_logs",
        "log": "Remove Campaign",
        "name": "Player ${deviceInfo?["hardware_details"]["model"] ?? ""}",
        "type": "info",
        "date_time": DateTime.now().toIso8601String(),
      };

      _mqttClientService.publish(topic, jsonEncode(sendLog));
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.clear();
      await _checkPairingStatus();
    }
    notifyListeners();
  }

  int _currentIndexOfCapmaign = 0;
  Timer? _timerOfCampaign;

  int get currentIndexOfCapmaign => _currentIndexOfCapmaign;

  int get currentDurationOfCampaign {
    final currentCampaign =
        campaignModel!.data.playerCampaigns[_currentIndexOfCapmaign];
    final campaignSchedule = currentCampaign.campaignSchedule;

    int durationcampagin = 0;

    // Check if the item is in the schedule or should always play
    if (campaignSchedule.alwaysPlay ||
        _isPlaylistDateInRangeForCampagin(
                DateTime.parse(campaignSchedule.period!.date.start),
                DateTime.parse(campaignSchedule.period!.date.end!)) &&
            _isCurrentDayAllowedForCampain(
              campaignSchedule.period!.days,
              DateTime.now(),
            ) &&
            _isTimeInRangeForCampaign(
              campaignSchedule.period!.time.from,
              campaignSchedule.period!.time.to,
            )) {
      durationcampagin = int.parse(currentCampaign.campaignSettings.duration);
    }

    // Log the state
    print(
        "Current Index: $_currentIndexOfCapmaign, Duration: $durationcampagin seconds, Always Play: ${campaignSchedule.alwaysPlay}");

    return durationcampagin;
  }

  void startPlaylistTimerForCampaign() {
    _timerOfCampaign?.cancel();

    // If the duration is 0, directly update the index and skip the timer setup
    if (currentDurationOfCampaign == 0) {
      _updateIndexForCampain();
      print("Playlist item not in schedule, skipping timer setup.");
    } else {
      // Only start the timer if the duration is greater than 0
      _timerOfCampaign = Timer(
          Duration(seconds: currentDurationOfCampaign), _updateIndexForCampain);
    }
  }

  void publishLogsForPlayList(String name) {
    Map<String, dynamic> sendLog = {
      "action": "Playlist",
      "name": "$name",
      "type": "info",
      "dateTime": DateTime.now().toIso8601String(),
    };

    _mqttClientService.publish(topic, jsonEncode(sendLog));
  }

  void publishLogsForCampaign(String name) {
    Map<String, dynamic> sendLog = {
      "action": "Campaign",
      "name": "$name",
      "type": "info",
      "dateTime": DateTime.now().toIso8601String(),
    };

    _mqttClientService.publish(topic, jsonEncode(sendLog));
  }

  void _updateIndexForCampain() {
    _currentIndexOfCapmaign = (_currentIndexOfCapmaign + 1) %
        campaignModel!.data.playerCampaigns.length;
    Map<String, dynamic> sendLog = {
      "action": "player_logs",
      "log": "Current Campaign",
      "name":
          _campaignModel?.data.playerCampaigns[_currentIndex].campaignName ??
              "",
      "type": "info",
      "date_time": DateTime.now().toIso8601String(),
    };

    _mqttClientService.publish(topic, jsonEncode(sendLog));
    notifyListeners();
    startPlaylistTimerForCampaign();
  }

  void resetTimerForCapmpain() {
    _timerOfCampaign?.cancel();
    notifyListeners();
  }

  bool _isPlaylistDateInRangeForCampagin(DateTime startDate, DateTime endDate) {
    DateTime now = DateTime.now();
    return now.isAfter(startDate) &&
        now.isBefore(endDate.add(const Duration(days: 1)));
  }

  bool _isCurrentDayAllowedForCampain(dynamic days, DateTime now) {
    switch (now.weekday) {
      case 1:
        return days.monday ?? false;
      case 2:
        return days.tuesday ?? false;
      case 3:
        return days.wednesday ?? false;
      case 4:
        return days.thursday ?? false;
      case 5:
        return days.friday ?? false;
      case 6:
        return days.saturday ?? false;
      case 7:
        return days.sunday ?? false;
      default:
        return false;
    }
  }

  bool _isTimeInRangeForCampaign(String timeFrom, String timeTo) {
    DateTime currentTime = DateTime.now();
    DateTime fromTime = DateTime.now().copyWith(
      hour: int.parse(timeFrom.split(':')[0]),
      minute: int.parse(timeFrom.split(':')[1]),
    );

    DateTime toTime = DateTime.now().copyWith(
      hour: int.parse(timeTo.split(':')[0]),
      minute: int.parse(timeTo.split(':')[1]),
    );

    return currentTime.isAfter(fromTime) && currentTime.isBefore(toTime);
  }

  void _updateMessage() {
    notifyListeners();
  }

  void reloadApp(BuildContext context) {
    Phoenix.rebirth(context); // App restart
  }

  int _currentIndex = 0;
  Timer? _timer;

  int get currentIndex => _currentIndex;

  int get currentDuration {
    final currentPlaylist = playListModel!.data.playlist[_currentIndex];
    final playlistSchedule = currentPlaylist.playlistSchedule;

    int duration = 2;

    // Check if the item is in the schedule or should always play
    if (playlistSchedule!.alwaysPlay ||
        _isPlaylistDateInRange(
              playlistSchedule.period!.date.start,
              playlistSchedule.period!.date.end,
            ) &&
            _isCurrentDayAllowed(
              playlistSchedule.period!.days,
              DateTime.now(),
            ) &&
            _isTimeInRange(
              playlistSchedule.period!.time.from,
              playlistSchedule.period!.time.to,
            )) {
      duration = int.parse(currentPlaylist.playlistDefault!.duration);
    }

    // Log the state
    print(
        "Current Index: $_currentIndex, Duration: $duration seconds, Always Play: ${playlistSchedule.alwaysPlay}");

    return duration;
  }

  void startPlaylistTimer() {
    _timer?.cancel();
    print("this is duration$currentDuration");
    // If the duration is 0, directly update the index and skip the timer setup
    if (currentDuration == 2) {
      _updateIndex();
      print("Playlist item not in schedule, skipping timer setup.");
    } else {
      // Only start the timer if the duration is greater than 0
      _timer = Timer(Duration(seconds: currentDuration), _updateIndex);
    }
  }

  void _updateIndex() {
    _currentIndex = (_currentIndex + 1) % playListModel!.data.playlist.length;
    print(
        "current playlist ${_playListModel!.data.playlist[_currentIndex].name} ");

    Map<String, dynamic> sendLog = {
      "action": "player_logs",
      "log": "Current Playlist",
      "name": "${_playListModel!.data.playlist[_currentIndex].name}",
      "type": "info",
      "date_time": DateTime.now().toIso8601String(),
    };

    _mqttClientService.publish(topic, jsonEncode(sendLog));

    notifyListeners();
    startPlaylistTimer();
  }

  void resetTimer() {
    _timer?.cancel();
    notifyListeners();
  }

// Clean up timer
  @override
  void dispose() {
    _timerOfCampaign?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  bool _isPlaylistDateInRange(DateTime startDate, DateTime endDate) {
    DateTime now = DateTime.now();
    return now.isAfter(startDate) &&
        now.isBefore(endDate.add(const Duration(days: 1)));
  }

  bool _isCurrentDayAllowed(dynamic days, DateTime now) {
    switch (now.weekday) {
      case 1:
        return days.monday ?? false;
      case 2:
        return days.tuesday ?? false;
      case 3:
        return days.wednesday ?? false;
      case 4:
        return days.thursday ?? false;
      case 5:
        return days.friday ?? false;
      case 6:
        return days.saturday ?? false;
      case 7:
        return days.sunday ?? false;
      default:
        return false;
    }
  }

  bool _isTimeInRange(String timeFrom, String timeTo) {
    DateTime currentTime = DateTime.now();
    DateTime fromTime = DateTime.now().copyWith(
      hour: int.parse(timeFrom.split(':')[0]),
      minute: int.parse(timeFrom.split(':')[1]),
      second: int.parse(timeFrom.split(':')[2]),
    );

    DateTime toTime = DateTime.now().copyWith(
        hour: int.parse(timeTo.split(':')[0]),
        minute: int.parse(timeTo.split(':')[1]),
        second: int.parse(timeFrom.split(':')[2]));

    return currentTime.isAfter(fromTime) && currentTime.isBefore(toTime);
  }

  Future<void> launchUrl(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}
