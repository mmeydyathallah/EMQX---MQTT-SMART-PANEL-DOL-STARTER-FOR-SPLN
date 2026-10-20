import 'dart:convert';
import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  MqttService({
    required this.host,
    required this.port,
    this.username,
    this.password,
  });

  final String host;
  final int port;
  final String? username;
  final String? password;
  MqttServerClient? _client;
  void Function(Map<String, dynamic> status)? onStatus;
  void Function()? onDisconnect;
  bool _manualDisconnect = false;

  static const String statusTopic = 'dol/starter/status';
  static const String commandTopic = 'dol/starter/command';

  bool get isConnected => _client?.connectionStatus?.state == MqttConnectionState.connected;

  Future<void> connect() async {
    _manualDisconnect = true;
    _client?.disconnect();
    final clientId = 'dol-mobile-${DateTime.now().millisecondsSinceEpoch}';
    final client = port == 8084
        ? MqttServerClient('wss://$host/mqtt', clientId)
        : MqttServerClient.withPort(host, clientId, port)
      ..logging(on: false)
      ..keepAlivePeriod = 10
      ..connectTimeoutPeriod = 10000
      ..autoReconnect = false
      ..onDisconnected = () { if (!_manualDisconnect) onDisconnect?.call(); };
    client.setProtocolV31();
    if (port == 8084) {
      client.port = 8084;
      client.useWebSocket = true;
      client.useAlternateWebSocketImplementation = true;
      client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
    } else if (port == 8883) {
      client.secure = true;
      client.securityContext = SecurityContext.defaultContext;
    }

    final message = MqttConnectMessage()
        .withClientIdentifier(client.clientIdentifier)
        .startClean();
    client.connectionMessage = message;
    _client = client;
    _manualDisconnect = false;

    try {
      await client.connect(username, password);
    } catch (error) {
      final returnCode = client.connectionStatus?.returnCode;
      client.disconnect();
      throw Exception('Koneksi MQTT gagal${returnCode == null ? '' : ' ($returnCode)'}: $error');
    }
    if (!isConnected) {
      final returnCode = client.connectionStatus?.returnCode;
      client.disconnect();
      throw Exception('Broker tidak menerima koneksi${returnCode == null ? '' : ' ($returnCode)'}');
    }
    client.subscribe(statusTopic, MqttQos.atLeastOnce);
    client.updates?.listen((events) {
      for (final event in events) {
        final message = event.payload;
        if (message is MqttPublishMessage) {
          final raw = MqttPublishPayload.bytesToStringAsString(message.payload.message);
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map<String, dynamic>) onStatus?.call(decoded);
          } catch (_) {}
        }
      }
    });
  }

  Future<void> testConnection() async {
    await connect();
    disconnect();
  }

  void publishCommand(String topic, Map<String, dynamic> payload) {
    final client = _client;
    if (client == null || !isConnected) return;
    final builder = MqttClientPayloadBuilder()..addString(jsonEncode(payload));
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void disconnect() {
    _manualDisconnect = true;
    _client?.disconnect();
  }
}
