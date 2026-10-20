import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'mqtt_service.dart';
import 'final_app.dart';

void main() {
  FlutterForegroundTask.initCommunicationPort();
  runApp(const FinalApp());
}

class DolStarterApp extends StatelessWidget {
  const DolStarterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DOL Starter Controller',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F131D),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD32F2F), brightness: Brightness.dark),
        cardTheme: const CardThemeData(color: Color(0xFF171B26), margin: EdgeInsets.zero),
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool running = false;
  bool connected = false;
  late final MqttService mqtt;

  @override
  void initState() {
    super.initState();
    mqtt = MqttService(
      host: const String.fromEnvironment('EMQX_HOST', defaultValue: 'broker.emqx.io'),
      port: const int.fromEnvironment('EMQX_PORT', defaultValue: 1883),
      username: const String.fromEnvironment('EMQX_USERNAME', defaultValue: 'YOUR_MQTT_USERNAME'),
      password: const String.fromEnvironment('EMQX_PASSWORD', defaultValue: 'YOUR_MQTT_PASSWORD'),
    );
  }

  Future<void> toggleConnection() async {
    if (connected) {
      mqtt.disconnect();
      setState(() => connected = false);
      return;
    }
    try {
      await mqtt.connect();
      if (mounted) setState(() => connected = mqtt.isConnected);
    } catch (_) {
      if (mounted) setState(() => connected = false);
    }
  }

  void command(bool nextRunning) {
    setState(() => running = nextRunning);
    mqtt.publishCommand('dol/starter/command', {'command': nextRunning ? 'START' : 'STOP'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SPLN MOTOR CONTROL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Text('DOL STARTER • PANEL 01', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: Colors.white54)),
        ]),
        actions: [IconButton(onPressed: toggleConnection, icon: Icon(connected ? Icons.cloud_done : Icons.cloud_off))],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        _ConnectionBadge(connected: connected, onTap: toggleConnection),
        const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('MOTOR STATUS', style: TextStyle(letterSpacing: 1.4, fontWeight: FontWeight.bold)),
            Text(running ? 'RUNNING' : 'STOPPED', style: TextStyle(color: running ? const Color(0xFF4EDEA3) : Colors.white60, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _Actuator(label: 'START', icon: Icons.play_arrow, color: const Color(0xFF10B981), active: running, onTap: () => command(true)),
            _Actuator(label: 'STOP', icon: Icons.stop, color: const Color(0xFFD32F2F), active: !running, onTap: () => command(false)),
          ]),
        ]))),
        const SizedBox(height: 16),
        const Text('LIVE TELEMETRY', style: TextStyle(letterSpacing: 1.4, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.55, children: const [
          _Metric(label: 'CURRENT', value: '12.8', unit: 'A', color: Color(0xFF93CCFF)),
          _Metric(label: 'VOLTAGE', value: '380', unit: 'V', color: Color(0xFF93CCFF)),
          _Metric(label: 'POWER', value: '7.5', unit: 'kW', color: Color(0xFF4EDEA3)),
          _Metric(label: 'FREQUENCY', value: '50.0', unit: 'Hz', color: Color(0xFFF59E0B)),
        ]),
        const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('FAULT ANNUNCIATORS', style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: const [
            _Fault(label: 'OVERLOAD 49'), _Fault(label: 'PHASE LOSS 46'), _Fault(label: 'EARTH FAULT 50N'), _Fault(label: 'UNDERVOLTAGE 27'),
          ]),
        ]))),
      ]),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.connected, required this.onTap});
  final bool connected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: const Color(0xFF171B26), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF313540))), child: Row(children: [Icon(Icons.circle, size: 10, color: connected ? const Color(0xFF4EDEA3) : const Color(0xFFF59E0B)), const SizedBox(width: 8), Text(connected ? 'MQTT: CONNECTED' : 'MQTT: DISCONNECTED', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)), const Spacer(), const Text('EMQX', style: TextStyle(color: Colors.white54, fontSize: 12))])));
}

class _Actuator extends StatelessWidget {
  const _Actuator({required this.label, required this.icon, required this.color, required this.active, required this.onTap});
  final String label; final IconData icon; final Color color; final bool active; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Column(children: [Container(width: 88, height: 88, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(active ? 1 : .35), boxShadow: [BoxShadow(color: color.withOpacity(active ? .35 : .08), blurRadius: 18)]), child: Icon(icon, size: 42)), const SizedBox(height: 8), Text(label, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold))]));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.unit, required this.color});
  final String label, value, unit; final Color color;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 11, letterSpacing: 1.1, color: Colors.white54)), Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(value, style: TextStyle(fontFamily: 'monospace', fontSize: 25, fontWeight: FontWeight.bold, color: color)), const SizedBox(width: 4), Text(unit, style: TextStyle(color: color, fontWeight: FontWeight.bold))])])));
}

class _Fault extends StatelessWidget {
  const _Fault({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF0A0E18), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFF313540))), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.check_circle, size: 14, color: Color(0xFF4EDEA3)), const SizedBox(width: 6), Text(label, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))]));
}
