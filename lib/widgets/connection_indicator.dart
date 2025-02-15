import 'package:flutter/material.dart';

class MqttStatusIndicator extends StatelessWidget {
  final bool isConnected;

  const MqttStatusIndicator({super.key, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        isConnected ? 'Connected' : 'Disconnected',
        style: TextStyle(
          fontSize: 24,
          color: isConnected ? Colors.green : Colors.red,
        ),
      ),
    );
  }
}
