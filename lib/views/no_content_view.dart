import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for keyboard events
import 'package:provider/provider.dart';

import 'package:digital_signage/view_models/mqtt_view_model.dart';
import 'package:digital_signage/widgets/center_image_widget.dart';
import 'package:digital_signage/widgets/text_widget.dart';

class NoContentView extends StatefulWidget {
  const NoContentView({super.key});

  @override
  State<NoContentView> createState() => _NoContentViewState();
}

class _NoContentViewState extends State<NoContentView> {
  Offset? _touchPosition;
  late FocusNode _focusNode; // Declare FocusNode

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(); // Initialize FocusNode in initState
  }

  @override
  void dispose() {
    _focusNode.dispose(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urlLauncherViewModel = Provider.of<MqttViewModel>(context, listen: false);

    return RawKeyboardListener(
      focusNode: _focusNode, 
      onKey: _onKey, 
      child: Scaffold(
        body: GestureDetector(
          onTapDown: (details) {
                    // Capture the tap position and store it in the Provider
          final mqttViewModel = Provider.of<MqttViewModel>(context, listen: false);
          mqttViewModel.setTapPosition(details.localPosition.dx, details.localPosition.dy);
          print("Tapped at: x=${details.localPosition.dx}, y=${details.localPosition.dy}");
        },
          child: Stack(
            children: [
              Image.asset(
                "assets/images/background.png",
                fit: BoxFit.cover, 
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CustomImageWidget(
                      imagePath: 'assets/images/Browser.png',
                    ),
                    const SimpleText(
                      text: "No Content Available for Playback",
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    GestureDetector(
                      onTap: () => urlLauncherViewModel.launchUrl(''),
                      child: const SimpleText(
                        text:
                          "Go to our website to publish one or remove restriction.",
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Handle key events
  void _onKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      print("Key pressed: ${event.logicalKey.debugName}");

      // You can add further logic based on the key pressed
      final mqttViewModel = Provider.of<MqttViewModel>(context, listen: false);
      mqttViewModel.getKey(event.logicalKey.debugName!);
    }
  }
}
