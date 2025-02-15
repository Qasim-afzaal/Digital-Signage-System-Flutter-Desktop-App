import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for keyboard events
import 'package:provider/provider.dart';

import '../services/mqtt_client_service.dart';
import '../view_models/mqtt_view_model.dart';
import '../view_models/system_apply_settings_vm.dart';
import '../views/campaign_view.dart';
import '../views/connecting_view.dart';
import '../views/digivision_view.dart';
import '../views/downloading_screen.dart';
import '../views/no_content_view.dart';
import '../views/no_internet_view.dart';
import '../views/play_list_view.dart';

class MqttProvider extends StatefulWidget {
  final Widget child;

  const MqttProvider({required this.child, super.key});

  @override
  State<MqttProvider> createState() => _MqttProviderState();
}

class _MqttProviderState extends State<MqttProvider> {
  Offset? _lastOffset;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus(); // Request focus once the widget is built
    });
  }

  @override
  void dispose() {
    _focusNode.dispose(); // Clean up FocusNode on dispose
    super.dispose();
  }

  // Callback for touch position
  void _onTap(TapUpDetails details) {
    final position = details.localPosition;
    print("Touched at position: $position");
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MqttViewModel>(
          create: (context) => MqttViewModel(MqttClientService()),
        ),
        ChangeNotifierProvider<DeviceSettingsViewModel>(
          create: (context) => DeviceSettingsViewModel(),
        ),
      ],
      child: Consumer<MqttViewModel>(
        builder: (context, viewModel, child) {
          return RawKeyboardListener(
            focusNode: _focusNode,
            onKey: _onKey,
            child: GestureDetector(
              onTapUp: _onTap,
              child: _getScreenForState(viewModel.state),
            ),
          );
        },
      ),
    );
  }

  // Handle keyboard events
  void _onKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      print("Key pressed: ${event.logicalKey.debugName}");
      // Access viewModel to handle key events
      // final viewModel = Provider.of<MqttViewModel>(context, listen: false);
      // viewModel.getkey(event.logicalKey.debugName!);
    }
  }

  // Return appropriate screen based on MQTT state
  Widget _getScreenForState(MqttState state) {
    switch (state) {
      case MqttState.initial:
        return const ConnectingView();
      case MqttState.noContent:
        return const NoContentView();
      case MqttState.connectionScreen:
        return const ConnectingView();
      case MqttState.downloading:
        return const DownloadingView();
      case MqttState.noInternet:
        return const NoInternetView();
      case MqttState.campaignScreen:
        return const CampaignView();
      case MqttState.pairedScreen:
        return const DigivisionView();
      case MqttState.playlistScreen:
        return const PlaylistScreen();
      default:
        return const Scaffold(
          body: Center(child: Text('Unknown State')),
        );
    }
  }
}
