import UIKit
import CoreLocation
import SystemConfiguration.CaptiveNetwork
import Security
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {

    private let keychainService = "com.example.network"
    private let keychainAccount = "deviceIdentifier"
    private var locationManager: CLLocationManager?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        
        // Setup device info channel
        let deviceInfoChannel = FlutterMethodChannel(
            name: "com.example/device_info",
            binaryMessenger: controller.binaryMessenger
        )
        
        deviceInfoChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "getDeviceInfo":
                let deviceInfo = self.collectDeviceInfo()
                result(deviceInfo)
                // Print all collected device info
                self.printDeviceInfo(deviceInfo)
            case "getDeviceIdentifier":
                if let identifier = self.getOrCreateDeviceIdentifier() {
                    result(identifier)
                } else {
                    result(FlutterError(code: "UNAVAILABLE", message: "Unable to get device identifier", details: nil))
                }
             case "setScreenBrightness":
        if let args = call.arguments as? [String: CGFloat],
           let brightness = args["value"] {
            self.setScreenBrightness(to: brightness)
            result("Brightness set to \(brightness)")
        } else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Brightness value not provided", details: nil))
        }
    case "setVolume":
        if let args = call.arguments as? [String: Float],
           let volume = args["value"] {
            self.setVolume(to: volume)
            result("Volume set to \(volume)")
        } else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Volume value not provided", details: nil))
        }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        print("AppDelegate: didFinishLaunchingWithOptions")
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func collectDeviceInfo() -> [String: Any] {
        print("Collecting device info...")
        var deviceInfo: [String: Any] = [:]
        
        // Collect basic device information
        let device = UIDevice.current
        deviceInfo["name"] = device.name
        deviceInfo["systemName"] = device.systemName
        deviceInfo["systemVersion"] = device.systemVersion
        deviceInfo["model"] = device.model
        deviceInfo["localizedModel"] = device.localizedModel
        
        // Collect additional information
        deviceInfo["sender"] = "ios"
        deviceInfo["ios_version"] = UIDevice.current.systemVersion
        deviceInfo["device_model"] = device.model
        deviceInfo["network_name"] = getNetworkName()
        deviceInfo["time_zone"] = TimeZone.current.identifier
        deviceInfo["latitude"] = getLatitude()
        deviceInfo["longitude"] = getLongitude()
        deviceInfo["cpu_information"] = getCPUInfo()
        deviceInfo["memory_information"] = getMemoryInfo()
        deviceInfo["battery_information"] = getBatteryInfo()
        deviceInfo["cpu_usage"] = getCPUUsage()
        deviceInfo["storage_info"] = getStorageInfo()
        deviceInfo["device_resolution"] = getDeviceResolution()
        deviceInfo["camera_details"] = getCameraDetails()
        
        print("Device info collected.")
        return deviceInfo
    }
    
    private func printDeviceInfo(_ deviceInfo: [String: Any]) {
        print("Device Info:")
        for (key, value) in deviceInfo {
            print("\(key): \(value)")
        }
    }
    
    private func getOrCreateDeviceIdentifier() -> String? {
        print("Getting or creating device identifier...")
        let keychainQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        var itemRef: CFTypeRef?
        let status = SecItemCopyMatching(keychainQuery as CFDictionary, &itemRef)
        
        if status == errSecSuccess, let data = itemRef as? Data, let identifier = String(data: data, encoding: .utf8) {
            print("Device identifier retrieved from keychain.")
            return identifier
        } else {
            let newIdentifier = UUID().uuidString
            let data = newIdentifier.data(using: .utf8)
            
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: keychainAccount,
                kSecValueData as String: data!,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
            ]
            
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus == errSecSuccess {
                print("New device identifier added to keychain.")
                return newIdentifier
            } else {
                print("Failed to add device identifier to keychain.")
                return nil
            }
        }
    }
    
    private func getMacAddress() -> String? {
        // MAC address is not accessible on iOS
        print("MAC address retrieval is not supported on iOS.")
        return nil
    }
    
    private func getNetworkName() -> String? {
        // Wi-Fi SSID requires special entitlements and might not be accessible
        print("Network name retrieval is not supported on iOS.")
        return nil
    }
    
    private func getLastIpAddress() -> String? {
        // IP address is not directly accessible on iOS
        print("IP address retrieval is not supported on iOS.")
        return nil
    }
    
    private func getLatitude() -> Double? {
        if let location = locationManager?.location {
            let latitude = location.coordinate.latitude
            print("Latitude: \(latitude)")
            return latitude
        }
        print("Latitude retrieval failed.")
        return nil
    }
    
    private func getLongitude() -> Double? {
        if let location = locationManager?.location {
            let longitude = location.coordinate.longitude
            print("Longitude: \(longitude)")
            return longitude
        }
        print("Longitude retrieval failed.")
        return nil
    }
    
    private func getCPUInfo() -> [String: Any] {
        let processorCount = ProcessInfo.processInfo.processorCount
        let activeProcessorCount = ProcessInfo.processInfo.activeProcessorCount
        let physicalMemory = ProcessInfo.processInfo.physicalMemory // Bytes
        
        let cpuInfo: [String: Any] = [
            "processor_count": processorCount,
            "active_processor_count": activeProcessorCount,
            "physical_memory": "\(physicalMemory / (1024 * 1024)) MB"
        ]
        print("CPU Info: \(cpuInfo)")
        return cpuInfo
    }
    
    private func getMemoryInfo() -> [String: Any] {
        // Memory information is limited in iOS
        print("Memory information retrieval is limited on iOS.")
        return [:]
    }
    
    private func getBatteryInfo() -> [String: Any] {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel * 100 // Battery level as percentage
        let batteryState = UIDevice.current.batteryState
        let stateString: String
        switch batteryState {
        case .charging:
            stateString = "Charging"
        case .unplugged:
            stateString = "Unplugged"
        case .full:
            stateString = "Full"
        case .unknown:
            stateString = "Unknown"
        @unknown default:
            stateString = "Unavailable"
        }
        let batteryInfo: [String: Any] = [
            "battery_level": batteryLevel,
            "battery_state": stateString
        ]
        print("Battery Info: \(batteryInfo)")
        return batteryInfo
    }
    
    private func getCPUUsage() -> Double? {
        // Detailed CPU usage is not directly available on iOS
        print("CPU usage retrieval is not supported on iOS.")
        return nil
    }
    
    private func getCPUDetailedInfo() -> String? {
        // Detailed CPU information is restricted on iOS
        print("Detailed CPU information retrieval is restricted on iOS.")
        return nil
    }
    
    private func getHardwareDetails() -> String? {
        // Hardware details beyond what is available is restricted on iOS
        print("Hardware details retrieval is restricted on iOS.")
        return nil
    }
    
    private func getStorageInfo() -> [String: Any] {
        var storageInfo: [String: Any] = [:]
        let fileManager = FileManager.default
        if let attributes = try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory()) {
            let totalSize = attributes[.systemSize] as? Int64 ?? 0
            let freeSize = attributes[.systemFreeSize] as? Int64 ?? 0
            storageInfo["total_storage"] = "\(totalSize / (1024 * 1024 * 1024)) GB"
            storageInfo["free_storage"] = "\(freeSize / (1024 * 1024 * 1024)) GB"
            print("Storage Info: \(storageInfo)")
        } else {
            print("Failed to retrieve storage info.")
        }
        return storageInfo
    }
    
    private func getRAMInfo() -> [String: Any] {
        // RAM information is generally limited in iOS
        print("RAM information retrieval is limited on iOS.")
        return [:]
    }
    
    private func getDeviceResolution() -> [String: Any] {
        let screen = UIScreen.main
        let resolution = screen.bounds.size
        let resolutionInfo: [String: Any] = [
            "width": resolution.width,
            "height": resolution.height
        ]
        print("Device Resolution: \(resolutionInfo)")
        return resolutionInfo
    }
    
    private func getCameraDetails() -> [String: Any] {
        // Camera details are not directly accessible
        print("Camera details retrieval is restricted on iOS.")
        return [:]
    }
    
    // CLLocationManagerDelegate methods
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            print("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
    private func setScreenBrightness(to value: CGFloat) {
    UIScreen.main.brightness = value // value should be between 0.0 (dark) and 1.0 (full brightness)
    print("Screen brightness set to \(value)")
}


private func setVolume(to value: Float) {
    let volumeView = MPVolumeView()
    for view in volumeView.subviews {
        if let slider = view as? UISlider {
            slider.value = value // value should be between 0.0 (mute) and 1.0 (max volume)
            break
        }
    }
    print("Volume set to \(value)")
}
}
