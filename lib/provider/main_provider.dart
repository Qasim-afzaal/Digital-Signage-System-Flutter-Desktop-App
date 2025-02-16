import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for keyboard events
import 'package:provider/provider.dart';

import '../services/mqtt_client_service.dart';
import '../view_models/mqtt_view_model.dart';
import '../view_models/system_apply_settings_vm.dart';
import '../views/multi_media_screen.dart';
import '../views/connection_screen.dart';
import '../views/main_view.dart';
import '../views/downloading_screen.dart';
import '../views/no_media_screen.dart';
import '../views/no_internet_view.dart';
import '../views/play_list_view.dart';

class MqttProvider extends StatefulWidget {
  final Widget child;

  const MqttProvider({required this.child, super.key});

  @override
  State<MqttProvider> createState() => _MqttProviderState();
}

class _MqttProviderState extends State<MqttProvider> {

  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus(); 
    });
  }

  @override
  void dispose() {
    _focusNode.dispose(); 
    super.dispose();
  }


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


  void _onKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      print("Key pressed: ${event.logicalKey.debugName}");
      
    }
  }


  Widget _getScreenForState(MqttState state) {
    switch (state) {
      case MqttState.initial:
        return const ConnectingScreen();
      case MqttState.noContent:
        return const NoMediaAvailableView();
      case MqttState.connectionScreen:
        return const ConnectingScreen();
      case MqttState.downloading:
        return const DownloadingScreen();
      case MqttState.noInternet:
        return const ConnectionErrorView();
      case MqttState.campaignScreen:
        return const MultiMediaView();
      case MqttState.pairedScreen:
        return const MainView();
      case MqttState.playlistScreen:
        return const PlaylisMediatScreen();
      default:
        return const Scaffold(
          body: Center(child: Text('Unknown State')),
        );
    }
  }
}
