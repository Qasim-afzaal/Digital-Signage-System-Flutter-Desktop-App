import Cocoa
import FlutterMacOS
import IOKit
import SystemConfiguration

@main
class AppDelegate: FlutterAppDelegate {
    
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    override func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = self.mainFlutterWindow?.contentViewController as! FlutterViewController
        
        // System Info Channel
        let systemInfoChannel = FlutterMethodChannel(name: "com.example/systemInfo", binaryMessenger: controller.engine.binaryMessenger)
        systemInfoChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            if call.method == "getSystemInfo" {
                result(self.getSystemInformation())
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        
        // Reboot Device Channel
        let rebootChannel = FlutterMethodChannel(name: "com.example/deviceControl", binaryMessenger: controller.engine.binaryMessenger)
        rebootChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            if call.method == "rebootDevice" {
                self.rebootDevice()
                result("Reboot initiated")
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

     // Brightness Control Channel
            let brightnessChannel = FlutterMethodChannel(name: "com.example/brightnessControl", binaryMessenger: controller.engine.binaryMessenger)
        brightnessChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            if call.method == "setBrightness", let args = call.arguments as? [String: Any],
               let brightness = args["brightness"] as? Float {
                self.setBrightnessLevel(level: brightness)
                result("Brightness set to \(brightness)")
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        let reloadChannel = FlutterMethodChannel(name: "com.example/reloadApp", binaryMessenger: controller.engine.binaryMessenger)
        reloadChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            if call.method == "reloadApp" {
                self.reloadApp()
                result("App reload initiated")
            } else {
                result(FlutterMethodNotImplemented)
            }
        }


    // Volume Control Channel (new)

    let volumeChannel = FlutterMethodChannel(name: "com.example/volumeControl", binaryMessenger: controller.engine.binaryMessenger)
    volumeChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "setVolume", let args = call.arguments as? [String: Any],
           let volume = args["volume"] as? Int {
            self.setVolume(volume: volume)
            result("Volume set to \(volume)%")
        } else if call.method == "muteVolume" {
            self.muteVolume()
            result("Volume muted")
        } else if call.method == "unmuteVolume" {
            self.unmuteVolume()
            result("Volume unmuted")
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    let networkChannel = FlutterMethodChannel(name: "com.example/networkControl", binaryMessenger: controller.engine.binaryMessenger)
        networkChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            if call.method == "restartNetwork" {
                self.restartNetwork()
                result("Network restart initiated")
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }

  
    func setBrightnessLevel(level: Float) {
    var iterator: io_iterator_t = 0
    print("Setting brightness to \(level)")

    if IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IODisplayConnect"), &iterator) == kIOReturnSuccess {
        var service: io_object_t = 1
        var count = 0 // To track the number of displays

        while service != 0 {
            service = IOIteratorNext(iterator)
            IODisplaySetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, level)
            IOObjectRelease(service)
            count += 1
        }
        print("Number of displays adjusted: \(count)")
    } else {
        print("Failed to get matching services")
    }
}
func unmuteVolume() {
    let appleScript = """
    set volume output muted false
    """
    var error: NSDictionary?
    if let scriptObject = NSAppleScript(source: appleScript) {
        scriptObject.executeAndReturnError(&error)
        if let error = error {
            print("AppleScript error: \(error)")
        }
    } else {
        print("Failed to create AppleScript object")
    }
}

func reloadApp() {
        // Programmatically restart the app
        let appleScript = """
        do shell script "killall -9 \(ProcessInfo.processInfo.processName)"
        """
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: appleScript) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error: \(error)")
            }
        } else {
            print("Failed to create AppleScript object")
        }
    }

        func muteVolume() {
        let appleScript = """
        set volume output muted true
        """
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: appleScript) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error: \(error)")
            }
        } else {
            print("Failed to create AppleScript object")
        }
    }

    // Reboot macOS function
   func rebootDevice() {
    let appleScript = """
    do shell script "shutdown -r now" with administrator privileges
    """
    var error: NSDictionary?
    if let scriptObject = NSAppleScript(source: appleScript) {
        scriptObject.executeAndReturnError(&error)
        if let error = error {
            print("AppleScript error: \(error)")
        }
    } else {
        print("Failed to create AppleScript object")
    }
}

  // Restart Network function
    func restartNetwork() {
        let appleScript = """
        do shell script "networksetup -setnetworkserviceenabled Wi-Fi off; networksetup -setnetworkserviceenabled Wi-Fi on" with administrator privileges
        """
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: appleScript) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error: \(error)")
            }
        } else {
            print("Failed to create AppleScript object")
        }
    }

    // Fetch system information
    private func getSystemInformation() -> [String: Any] {
        var systemInfo = [String: Any]()
        
        systemInfo["os_version"] = getOSVersion()
        systemInfo["device_model"] = getDeviceModel()
        systemInfo["network_name"] = getNetworkSSID()
        systemInfo["time_zone"] = getTimeZone()
        systemInfo["cpu_information"] = getCpuInformation()
        systemInfo["memory_information"] = getMemoryInfo()
        systemInfo["storage_info"] = getStorageInfo()
        systemInfo["device_resolution"] = getDeviceResolution()
        systemInfo["battery_information"] = getBatteryInfo()
        systemInfo["camera_details"] = getCameraDetails()
        systemInfo["uuid"] = getUUID()

        return systemInfo
    }

    // Fetch the OS version
    private func getOSVersion() -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
    }

    // Fetch device model
    private func getDeviceModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    // Network SSID (not available on macOS, placeholder value)
    private func getNetworkSSID() -> String {
        return "Not Available"
    }

    // Fetch timezone
    private func getTimeZone() -> String {
        return TimeZone.current.identifier
    }

    // Fetch CPU information (architecture, processor, core count)
    private func getCpuInformation() -> [String: Any] {
        return [
            "cpu_architecture": getCPUArchitecture(),
            "processor": getProcessorName(),
            "count_cores": getCoreCount()
        ]
    }


    func setVolume(volume: Int) {
        let appleScript = """
        set volume output volume \(volume)
        """
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: appleScript) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error: \(error)")
            }
        } else {
            print("Failed to create AppleScript object")
        }
    }

    private func getCPUArchitecture() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }

    private func getProcessorName() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var cpuName = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &cpuName, &size, nil, 0)
        return String(cString: cpuName)
    }

    private func getCoreCount() -> Int {
        var coreCount: Int = 0
        var size = MemoryLayout<Int>.size
        sysctlbyname("hw.physicalcpu", &coreCount, &size, nil, 0)
        return coreCount
    }

    // Fetch memory information (total, available, used)
    private func getMemoryInfo() -> [String: Any] {
        var vmStat = vm_statistics_data_t()
        var count = UInt32(MemoryLayout<vm_statistics_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &vmStat) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_VM_INFO, $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            let pagesize = sysconf(_SC_PAGESIZE)
            let totalMemory = ProcessInfo.processInfo.physicalMemory
            let freeMemory = UInt64(vmStat.free_count) * UInt64(pagesize)
            let usedMemory = totalMemory - freeMemory
            return [
                "total_memory": totalMemory,
                "available_memory": freeMemory,
                "used_memory": usedMemory
            ]
        }
        return [
            "total_memory": 0,
            "available_memory": 0,
            "used_memory": 0
        ]
    }

    // Fetch storage information (total, available)
    private func getStorageInfo() -> [String: Any] {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory() as String)
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            return [
                "total_storage": values.volumeTotalCapacity ?? 0,
                "available_storage": values.volumeAvailableCapacity ?? 0
            ]
        } catch {
            return ["total_storage": 0, "available_storage": 0]
        }
    }

    // Fetch device resolution and pixel density
    private func getDeviceResolution() -> [String: Any] {
        let screen = NSScreen.main
        let resolution = screen?.frame.size ?? NSSize.zero
        let density = screen?.backingScaleFactor ?? 1.0
        return [
            "resolution": "\(Int(resolution.width))x\(Int(resolution.height))",
            "density": density
        ]
    }

    // Fetch battery information
    private func getBatteryInfo() -> [String: Any] {
        var batteryInfo = [
            "battery_percentage": "Not Available",
            "formatted_voltage": "Not Available",
            "formatted_temperature": "Not Available"
        ]

        guard let powerSourceInfo = IOPSCopyPowerSourcesInfo()?.takeUnretainedValue() as? NSDictionary else {
            print("Failed to get power source info")
            return batteryInfo
        }
        
        guard let powerSourcesList = IOPSCopyPowerSourcesList(powerSourceInfo)?.takeUnretainedValue() as? [CFTypeRef] else {
            print("Failed to get power sources list")
            return batteryInfo
        }
        
        for powerSource in powerSourcesList {
            guard let powerSourceDetails = IOPSGetPowerSourceDescription(powerSourceInfo, powerSource)?.takeUnretainedValue() as? [String: Any] else {
                print("Failed to get power source description for \(powerSource)")
                continue
            }
            
            // Extract battery percentage
            if let currentCapacity = powerSourceDetails[kIOPSCurrentCapacityKey as String] as? Int,
               let maxCapacity = powerSourceDetails[kIOPSMaxCapacityKey as String] as? Int {
                let batteryPercentage = Double(currentCapacity) / Double(maxCapacity) * 100
                batteryInfo["battery_percentage"] = String(format: "%.0f%%", batteryPercentage)
            } else {
                print("Battery capacity info is not available")
            }
            
            // Extract voltage and temperature if available
            if let voltage = powerSourceDetails[kIOPSVoltageKey as String] as? Double {
                batteryInfo["formatted_voltage"] = String(format: "%.2f V", voltage)
            }
            
            if let temperature = powerSourceDetails[kIOPSTemperatureKey as String] as? Double {
                batteryInfo["formatted_temperature"] = String(format: "%.2f °C", temperature)
            }
        }

        return batteryInfo
    }

    // Fetch camera details (Currently not available for macOS, placeholder)
    private func getCameraDetails() -> String {
        return "Not Available"
    }

    // Fetch UUID
    private func getUUID() -> String {
        if let uuid = getPlatformUUID() {
            return uuid
        }
        return UUID().uuidString // Fallback to a generated UUID if system UUID isn't available
    }

    private func getPlatformUUID() -> String? {
        let platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard platformExpert != 0 else {
            return nil
        }
        
        let uuidData = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)
        IOObjectRelease(platformExpert)
        return uuidData?.takeUnretainedValue() as? String
    }
}
