/*
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'mqtt_service.dart';

class DolApp extends StatelessWidget {
  const DolApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SPLN Motor Control',
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB61722)), useMaterial3: true, textTheme: GoogleFonts.plusJakartaSansTextTheme()),
        home: const ControlPage(),
      );
}

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});
  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> with SingleTickerProviderStateMixin {
  late final MqttService mqtt;
  late final AnimationController rotation;
  String state = 'running';

  @override
  void initState() {
    super.initState();
    mqtt = MqttService(host: const String.fromEnvironment('EMQX_HOST', defaultValue: 'broker.emqx.io'), port: const int.fromEnvironment('EMQX_PORT', defaultValue: 1883));
    rotation = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() { rotation.dispose(); mqtt.disconnect(); super.dispose(); }

  void command(String value) { setState(() => state = value); mqtt.publishCommand('dol/starter/command', {'command': value == 'running' ? 'START' : 'STOP'}); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const PreferredSize(preferredSize: Size.fromHeight(62), child: AppHeader()),
        body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 110), children: [
          const MotorCard(),
          const SizedBox(height: 16),
          StatusCard(state: state, rotation: rotation),
          const SizedBox(height: 18),
          ActionButton(text: 'START MOTOR', icon: Icons.play_circle, color: const Color(0xFF10B981), onTap: () => command('running')),
          const SizedBox(height: 12),
          ActionButton(text: 'PUSH TO STOP', icon: Icons.back_hand, color: const Color(0xFFEF4444), onTap: () => command('stopped')),
          const SizedBox(height: 12),
          ActionButton(text: 'MODE OTOMATIS (AUTO)', icon: Icons.autorenew, color: const Color(0xFF0F172A), iconColor: const Color(0xFF38BDF8), onTap: () => command('auto')),
        ])))),
        bottomNavigationBar: BottomNav(settingsActive: false, onSettings: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()))),
      );
}

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});
  @override
  Widget build(BuildContext context) => Container(height: 62, decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Image.asset('assets/spln_logo.png', height: 28, width: 88), const ConnectionChip()])))));
}

class ConnectionChip extends StatelessWidget {
  const ConnectionChip({super.key});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFECFDF5), border: Border.all(color: const Color(0xFFA7F3D0)), borderRadius: BorderRadius.circular(20)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, size: 9, color: Color(0xFF059669)), SizedBox(width: 6), Text('EMQX CONNECTED', style: TextStyle(fontSize: 11, color: Color(0xFF047857), fontWeight: FontWeight.w700))]));
}

class MotorCard extends StatelessWidget {
  const MotorCard({super.key});
  @override
  Widget build(BuildContext context) => Column(children: [Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF1F5F9)), boxShadow: const [BoxShadow(color: Color(0x080F172A), blurRadius: 5)]), child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.bolt, color: Color(0xFFE11D48))), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text('DOL STARTER MOTOR', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(width: 8), const Icon(Icons.circle, size: 8, color: Color(0xFF10B981))]), const SizedBox(height: 3), const Text('Pompa Transfer 01 • 15 kW • Substation A', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))) ]))])), const Padding(padding: EdgeInsets.only(top: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Icon(Icons.verified_user, size: 17, color: Color(0xFF059669)), SizedBox(width: 6), Text('Sistem Terproteksi • Interlock Aktif', style: TextStyle(fontSize: 12, color: Color(0xFF475569)))]), Text('MODE REMOTE', style: TextStyle(fontSize: 10, color: const Color(0xFF0369A1), fontWeight: FontWeight.w700)))]))]);
}

class StatusCard extends StatelessWidget {
  const StatusCard({required this.state, required this.rotation, super.key});
  final String state;
  final AnimationController rotation;
  @override
  Widget build(BuildContext context) { final active = state == 'running'; final color = active ? const Color(0xFF008A5B) : state == 'auto' ? const Color(0xFF0284C7) : const Color(0xFFB61722); final label = active ? 'MOTOR RUNNING' : state == 'auto' ? 'MODE AUTO AKTIF' : 'MOTOR STOPPED'; return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF1F5F9))), child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(16)), child: active || state == 'auto' ? RotationTransition(turns: rotation, child: Icon(state == 'auto' ? Icons.sync : Icons.rotate_right, color: color)) : Icon(Icons.pause_circle, color: color)), const SizedBox(width: 14), Expanded(child: Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w700, color: color))), Text(active ? 'STATUS AKTIF' : state == 'auto' ? 'AUTO SENSOR' : 'SIAGA', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800))])); }
}

class ActionButton extends StatelessWidget {
  const ActionButton({required this.text, required this.icon, required this.color, required this.onTap, this.iconColor = Colors.white, super.key});
  final String text; final IconData icon; final Color color; final Color iconColor; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(height: 60, child: ElevatedButton.icon(onPressed: onTap, icon: Icon(icon, color: iconColor), label: Text(text), style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), textStyle: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700))));
}

class BottomNav extends StatelessWidget {
  const BottomNav({required this.settingsActive, required this.onSettings, super.key});
  final bool settingsActive; final VoidCallback onSettings;
  @override
  Widget build(BuildContext context) => Container(height: 76, decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF1F5F9))), boxShadow: [BoxShadow(color: Color(0x080F172A), blurRadius: 10)]), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_NavItem(icon: Icons.power_settings_new, label: 'Kontrol', active: !settingsActive, onTap: () => Navigator.popUntil(context, (route) => route.isFirst)), _NavItem(icon: Icons.tune, label: 'Pengaturan', active: settingsActive, onTap: onSettings)]));
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon; final String label; final bool active; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) { final color = active ? const Color(0xFFBE123C) : const Color(0xFF64748B); return InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 7), decoration: active ? BoxDecoration(color: const Color(0xFFFFE4E6), borderRadius: BorderRadius.circular(16)) : null, child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 22), Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w400))]))); }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: const PreferredSize(preferredSize: Size.fromHeight(62), child: AppHeader()), body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 110), children: [Text('Pengaturan', style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w700)), const Text('Konfigurasi Telemetri SCADA & Broker', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))), const SizedBox(height: 24), const Text('KONEKSI BROKER MQTT (EMQX)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)), const SizedBox(height: 10), const BrokerCard(), const SizedBox(height: 24), const Text('INFORMASI APLIKASI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)), const SizedBox(height: 10), const InfoCard()])))), bottomNavigationBar: BottomNav(settingsActive: true, onSettings: () {}));
}

class BrokerCard extends StatelessWidget {
  const BrokerCard({super.key});
  @override
  Widget build(BuildContext context) => Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E7FF))), child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('BROKER HOST', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))), SizedBox(height: 5), Text('broker.emqx.io', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), Text('SPLN Dedicated Enterprise Gateway', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))), Divider(height: 26), Row(children: [Expanded(child: Text('PORT & PROTOKOL\n8883 (MQTTS)\nSSL / TLS v1.3 Aktif', style: TextStyle(fontSize: 11, height: 1.6))), Expanded(child: Text('CLIENT ID\nspln-mobile-app-9481\nQoS Level 1 (Guaranteed)', style: TextStyle(fontSize: 11, height: 1.6)))]), Divider(height: 26), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: null, icon: Icon(Icons.network_ping, size: 16), label: Text('Uji Koneksi'))), SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: null, icon: Icon(Icons.edit, size: 16), label: Text('Edit Konfigurasi')))])])));
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key});
  @override
  Widget build(BuildContext context) => Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E7FF))), child: const Padding(padding: EdgeInsets.all(16), child: Row(children: [Icon(Icons.terminal, color: Color(0xFFB61722)), SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Versi Aplikasi', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))), SizedBox(height: 3), Text('v26.10.0 (SPLN IoT V1)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))])), Text('Build 2026.10', style: TextStyle(fontSize: 10, color: Color(0xFF475569)))])));
}
*/
