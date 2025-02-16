# Digital Signage System

The **Digital Signage System** is a powerful solution for remote content management. It enables administrators to send media playlists and campaigns to specific zones on player devices using MQTT-based communication. The system ensures scheduled playback with smooth transitions and animations, dynamically updating content based on predefined settings.

## Features
- **Remote Content Management**: Send and manage media content remotely via an admin panel.
- **MQTT-based Communication**: Ensures efficient real-time updates and synchronization.
- **Dynamic Content Scheduling**: Playlists and campaigns are scheduled for automated playback.
- **Native Hardware Controls**:
  - Fetching device data
  - Shutdown, volume control, and brightness handling
- **Real-time Content Updates**: Seamlessly updates content based on predefined rules.
- **Designed for Rooted Devices**: Optimized for direct hardware communication.

## Technologies Used
- **Languages**: Kotlin (Android), Swift (iOS), C++ (Native)
- **Frameworks & Tools**: Flutter for UI and cross-platform management
- **Networking & Communication**: MQTT for messaging, Dio & HTTP for API requests
- **Storage & Preferences**: SharedPreferences, PathProvider
- **Hardware Integrations**: Geolocator, Battery Plus, Screen Brightness

## Dependencies
The project relies on several Flutter and Dart packages:

```yaml
  cupertino_icons: ^1.0.8
  mqtt_client: ^9.6.3
  provider: ^6.1.2
  dio: ^5.7.0
  url_launcher: ^6.1.0
  http: ^1.1.0
  path_provider:
  shared_preferences: ^2.0.5
  permission_handler:
  connectivity_plus: ^6.0.5
  internet_connection_checker: ^1.0.0
  video_player: ^2.3.0
  geolocator: ^9.0.1
  battery_plus: ^6.0.3
  network_info_plus: ^6.0.1
  webview_flutter: ^4.10.0
  screen_brightness: ^1.0.1
  animations: ^2.0.0
  image_compression_flutter: ^1.0.4
  flutter_image_compress: ^2.3.0
  intl: ^0.19.0
  typed_data: ^1.3.0
  screenshot: ^3.0.0
  webview_flutter_plus:
  flutter_widget_from_html_core: ^0.15.2
  flutter_inappwebview_macos: ^1.1.2
  flutter_inappwebview: ^6.1.5
  flutter_html: ^3.0.0-beta.2
  flutter_phoenix: ^1.1.1
  restartfromos: ^0.0.3
```

## Installation

1. Clone the repository:
   ```sh
   git clone https://github.com/your-repo/digital-signage-system.git
   cd digital-signage-system
   ```
2. Install dependencies:
   ```sh
   flutter pub get
   ```
3. Run the app:
   ```sh
   flutter run
   ```

## Usage
- **Admin Panel**: Manage content remotely.
- **Media Playback**: Schedule and update content dynamically.
- **Hardware Control**: Adjust brightness, volume, and shutdown device remotely.

## Contribution
Feel free to contribute by opening issues or submitting pull requests.

## License
This project is licensed under the MIT License.
