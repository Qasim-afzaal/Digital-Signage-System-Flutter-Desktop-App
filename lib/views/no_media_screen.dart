import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:digital_signage/view_models/mqtt_view_model.dart';
import 'package:digital_signage/widgets/text_widget.dart';

class NoMediaAvailableView extends StatefulWidget {
  const NoMediaAvailableView({super.key});

  @override
  State<NoMediaAvailableView> createState() => _NoMediaAvailableViewState();
}

class _NoMediaAvailableViewState extends State<NoMediaAvailableView> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mqttViewModel = Provider.of<MqttViewModel>(context, listen: false);

    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _onKey,
      child: Scaffold(
        body: GestureDetector(
          onTapDown: (details) {
            mqttViewModel.setTapPosition(details.localPosition.dx, details.localPosition.dy);
          },
          child: Container(
            color: Colors.blueGrey[900],
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language, size: 100, color: Colors.white),
                const SimpleText(
                  text: "No Content Available",
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                GestureDetector(
                  onTap: () => mqttViewModel.launchUrl(''),
                  child: const SimpleText(
                    text: "Visit our website to upload content or adjust settings.",
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      Provider.of<MqttViewModel>(context, listen: false).getKey(event.logicalKey.debugName!);
    }
  }
}
