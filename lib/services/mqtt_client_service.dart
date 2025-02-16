import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:typed_data/typed_data.dart';

const String mqttBroker = 'broke3.io';
const int mqttPort = 21321;

class MqttClientService {
  late final MqttServerClient _client;
  final ValueNotifier<String> receivedMessageNotifier = ValueNotifier<String>('');
  Function(String)? onMessageReceived;

  MqttClientService() {
    _initializeClient();
  }

  void _initializeClient() {
    _client = MqttServerClient.withPort(
      mqttBroker,
      'uniqueClientID_${DateTime.now().millisecondsSinceEpoch}',
      mqttPort,
    )
      ..logging(on: true)
      ..autoReconnect = true
      ..resubscribeOnAutoReconnect = true
      ..keepAlivePeriod = 60
      ..setProtocolV311()
      ..onConnected = onConnected
      ..onDisconnected = onDisconnected
      ..onUnsubscribed = onUnsubscribed
      ..onSubscribed = onSubscribed
      ..onSubscribeFail = onSubscribeFail
      ..pongCallback = pong;
  }

  void onConnected() => debugPrint('MQTT_LOGS:: Connected');
  void onDisconnected() => debugPrint('MQTT_LOGS:: Disconnected');
  void onSubscribed(String topic) => debugPrint('MQTT_LOGS:: Subscribed to topic: $topic');
  void onSubscribeFail(String topic) => debugPrint('MQTT_LOGS:: Failed to subscribe $topic');
  void onUnsubscribed(String? topic) => debugPrint('MQTT_LOGS:: Unsubscribed from topic: $topic');
  void pong() => debugPrint('MQTT_LOGS:: Ping response client callback invoked');

  Future<void> connect() async {
    _client.connectionMessage = MqttConnectMessage()
        .withWillTopic('willtopic')
        .withWillMessage('Will message')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    debugPrint('MQTT_LOGS:: Connecting...');
    try {
      await _client.connect();
      if (_client.connectionStatus?.state != MqttConnectionState.connected) {
        debugPrint('MQTT_LOGS:: Connection failed - disconnecting.');
        _client.disconnect();
      }
    } catch (e) {
      debugPrint('Exception: $e');
      _client.disconnect();
    }
  }

  void disconnect() {
    if (_client.connectionStatus?.state == MqttConnectionState.connected) {
      _client.disconnect();
      debugPrint('MQTT_LOGS:: Disconnected');
    }
  }

  void subscribe(String topic) {
    debugPrint('MQTT_LOGS:: Subscribing to: $topic');
    _client.subscribe(topic, MqttQos.atMostOnce);
    _client.updates?.listen(_handleReceivedMessage);
  }

  void _handleReceivedMessage(List<MqttReceivedMessage<MqttMessage?>>? messages) {
    if (messages == null || messages.isEmpty) return;

    final recMess = messages.first.payload as MqttPublishMessage;
    final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
    onMessageReceived?.call(payload);
    receivedMessageNotifier.value = payload;

    debugPrint('MQTT_LOGS:: New data - topic: ${messages.first.topic}, payload: $payload');

    try {
      jsonDecode(payload);
    } catch (e) {
      debugPrint('Failed to decode JSON: $e');
    }
  }

  void publishMessage(String topic, Uint8List payload) {
    if (_client.connectionStatus?.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder()
        ..addBuffer(Uint8Buffer()..addAll(payload));
      _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!, retain: false);
      debugPrint('Message published to: $topic');
    } else {
      debugPrint('Cannot publish: MQTT client not connected.');
    }
  }

  void publish(String topic, String message) {
    if (_client.connectionStatus?.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder()..addString(message);
      _client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!, retain: true);
      debugPrint('MQTT_LOGS:: Published message: $message');
    }
  }
}
