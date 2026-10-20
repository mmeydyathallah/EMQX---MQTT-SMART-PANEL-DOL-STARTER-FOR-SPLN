class MqttConfig {
  static String host =
      const String.fromEnvironment('EMQX_HOST',
          defaultValue: 'YOUR_EMQX_HOST');
  static int port =
      const int.fromEnvironment('EMQX_PORT', defaultValue: 8084);
  static String username =
      const String.fromEnvironment('EMQX_USERNAME', defaultValue: 'YOUR_MQTT_USERNAME');
  static String password =
      const String.fromEnvironment('EMQX_PASSWORD', defaultValue: 'YOUR_MQTT_PASSWORD');

  static int revision = 0;
  static bool connected = false;
  static bool connecting = false;
}
