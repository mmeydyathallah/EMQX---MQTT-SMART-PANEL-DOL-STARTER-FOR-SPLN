import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

Future<void> main(List<String> args) async {
  final host = args.isNotEmpty
      ? args[0]
      : 'YOUR_EMQX_HOST';
  final port = args.length > 1 ? int.parse(args[1]) : 8084;
  final user = args.length > 2 ? (args[2] == '-' ? null : args[2]) : 'YOUR_MQTT_USERNAME';
  final pass = args.length > 3 ? (args[3] == '-' ? null : args[3]) : null;
  final mode = args.length > 4 ? args[4] : 'current';

  final clientId = 'dol-probe-${DateTime.now().millisecondsSinceEpoch}';
  final client = port == 8084
      ? MqttServerClient('wss://$host/mqtt', clientId)
      : MqttServerClient.withPort(host, clientId, port)
    ..logging(on: true)
    ..keepAlivePeriod = 30
    ..connectTimeoutPeriod = 10000
    ..autoReconnect = false;

  if (port == 8084) {
    client.port = 8084;
    client.useWebSocket = true;
    if (mode != 'ws-normal') {
      client.useAlternateWebSocketImplementation = true;
    }
    if (mode == 'multi') {
      client.websocketProtocols = MqttClientConstants.protocolsMultipleDefault;
    } else if (mode != 'ws-normal') {
      client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
    }
  } else if (port == 8883) {
    client.secure = true;
    client.securityContext = SecurityContext.defaultContext;
  }

  final message = MqttConnectMessage()
      .withClientIdentifier(client.clientIdentifier)
      .startClean();
  client.connectionMessage = message;

  if (mode == 'v311') {
    client.setProtocolV311();
  } else if (mode == 'v31') {
    client.setProtocolV31();
  }

  try {
    await client.connect(user, pass);
    stdout.writeln('RESULT: connected=${client.connectionStatus?.state} '
        'rc=${client.connectionStatus?.returnCode}');
    client.disconnect();
  } catch (error) {
    stdout.writeln('RESULT: FAILED mode=$mode -> $error  '
        'rc=${client.connectionStatus?.returnCode}');
  }
  exit(0);
}
