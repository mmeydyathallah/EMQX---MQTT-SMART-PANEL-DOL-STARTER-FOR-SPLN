/*
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'mqtt_service.dart';

class StitchDashboardApp extends StatelessWidget {
  const StitchDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SPLN Motor Control - DOL Starter',
      theme: base.copyWith(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB61722)),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
      ),
      home: const StitchControlPage(),
    );
  }
}

class StitchControlPage extends StatefulWidget {
  const StitchControlPage({super.key});

  @override
  State<StitchControlPage> createState() => _StitchControlPageState();
}

class _StitchControlPageState extends State<StitchControlPage> with SingleTickerProviderStateMixin {
  late final MqttService mqtt;
  late final AnimationController rotor;
  bool connected = true;
  String state = 'running';

  @override
  void initState() {
    super.initState();
    mqtt = MqttService(
      host: const String.fromEnvironment('EMQX_HOST', defaultValue: 'broker.emqx.io'),
      port: const int.fromEnvironment('EMQX_PORT', defaultValue: 1883),
      username: const String.fromEnvironment('EMQX_USERNAME'),
      password: const String.fromEnvironment('EMQX_PASSWORD'),
    );
    rotor = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    rotor.dispose();
    mqtt.disconnect();
    super.dispose();
  }

  void setMotorState(String next) {
    setState(() => state = next);
    mqtt.publishCommand('dol/starter/command', {'command': next == 'running' ? 'START' : 'STOP'});
  }

  @override
  Widget build(BuildContext context) {
    final running = state == 'running';
    final auto = state == 'auto';
    final accent = running ? const Color(0xFF008A5B) : auto ? const Color(0xFF0284C7) : const Color(0xFFB61722);
    return Scaffold(
      appBar: PreferredSize(preferredSize: const Size.fromHeight(62), child: _TopBar(connected: connected)),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
              children: [
                _MotorInfoCard(),
                const SizedBox(height: 16),
                _StatusCard(state: state, accent: accent, rotor: rotor),
                const SizedBox(height: 18),
                _ActionButton(label: 'START MOTOR', icon: Icons.play_circle, color: const Color(0xFF10B981), onTap: () => setMotorState('running')),
                const SizedBox(height: 12),
                _ActionButton(label: 'PUSH TO STOP', icon: Icons.back_hand, color: const Color(0xFFEF4444), onTap: () => setMotorState('stopped')),
                const SizedBox(height: 12),
                _ActionButton(label: 'MODE OTOMATIS (AUTO)', icon: Icons.autorenew, color: const Color(0xFF0F172A), iconColor: const Color(0xFF38BDF8), onTap: () => setMotorState('auto')),
                if (auto) ...[
                  const SizedBox(height: 12),
                  const Text('Otomasi PLC & Level Sensor Berjalan', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _BottomNav(activeSettings: false, onSettings: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()))),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) => Container(
        height: 62,
        decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Image.asset('assets/spln_logo.png', height: 28, width: 88, fit: BoxFit.contain),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFECFDF5), border: Border.all(color: const Color(0xFFA7F3D0)), borderRadius: BorderRadius.circular(20)), child: Row(children: [Icon(Icons.circle, size: 9, color: connected ? const Color(0xFF059669) : Colors.grey), const SizedBox(width: 6), Text(connected ? 'EMQX CONNECTED' : 'EMQX OFFLINE', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF047857)))])),
              ]),
            ),
          ),
        ),
      );
}

class _MotorInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF1F5F9)), boxShadow: const [BoxShadow(color: Color(0x080F172A), blurRadius: 5)]), child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFFE4E6))), child: const Icon(Icons.bolt, color: Color(0xFFE11D48)),), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text('DOL STARTER MOTOR', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))), const SizedBox(width: 8), const Icon(Icons.circle, size: 8, color: Color(0xFF10B981))]), const SizedBox(height: 3), const Text('Pompa Transfer 01 • 15 kW • Substation A', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500))]))]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(6, 10, 6, 0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Row(children: [Icon(Icons.verified_user, size: 17, color: Color(0xFF059669)), SizedBox(width: 6), Text('Sistem Terproteksi • Interlock Aktif', style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600))]), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFBAE6FD))), child: const Text('MODE REMOTE', style: TextStyle(fontSize: 10, color: Color(0xFF0369A1), fontWeight: FontWeight.w700, letterSpacing: 1.0)))])),
      ]);
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state, required this.accent, required this.rotor});
  final String state;
  final Color accent;
  final AnimationController rotor;

  @override
  Widget build(BuildContext context) {
    final running = state == 'running';
    final label = running ? 'MOTOR RUNNING' : state == 'auto' ? 'MODE AUTO AKTIF' : 'MOTOR STOPPED';
    final tag = running ? 'STATUS AKTIF' : state == 'auto' ? 'AUTO SENSOR' : 'SIAGA';
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF1F5F9)), boxShadow: const [BoxShadow(color: Color(0x080F172A), blurRadius: 5)]), child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: accent.withOpacity(.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: accent.withOpacity(.18))), child: running || state == 'auto' ? RotationTransition(turns: rotor, child: Icon(state == 'auto' ? Icons.sync : Icons.rotate_right, color: accent)) : Icon(Icons.pause_circle, color: accent)), const SizedBox(width: 14), Expanded(child: Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w700, color: accent))), Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: accent.withOpacity(.1), borderRadius: BorderRadius.circular(20)), child: Text(tag, style: TextStyle(fontSize: 10, color: accent, fontWeight: FontWeight.w800, letterSpacing: 1.0)))]));
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap, this.iconColor = Colors.white});
  final String label;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(height: 60, child: ElevatedButton.icon(onPressed: onTap, icon: Icon(icon, color: iconColor, size: 24), label: Text(label), style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, elevation: 5, shadowColor: color.withOpacity(.25), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), textStyle: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: .4))));
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.activeSettings, required this.onSettings});
  final bool activeSettings;
  final VoidCallback onSettings;

  @override
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        boxShadow: [BoxShadow(color: Color(0x080F172A), blurRadius: 10)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavItem(icon: Icons.power_settings_new, label: 'Kontrol', active: !activeSettings, onTap: () => Navigator.popUntil(context, (route) => route.isFirst)),
          _NavItem(icon: Icons.tune, label: 'Pengaturan', active: activeSettings, onTap: onSettings),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFFBE123C) : const Color(0xFF64748B);
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Container(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 7), decoration: active ? BoxDecoration(color: const Color(0xFFFFE4E6), borderRadius: BorderRadius.circular(16)) : null, child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 22), Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w400))])));
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(preferredSize: const Size.fromHeight(62), child: _TopBar(connected: true)),
      body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 112), children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Pengaturan', style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w700, color: const Color(0xFF131B2E))), const Text('Konfigurasi Telemetri SCADA & Broker', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))]), Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.tune, color: Color(0xFFB61722)))]),
        const SizedBox(height: 24),
        const _SettingsSectionTitle(icon: Icons.cloud_sync, label: 'KONEKSI BROKER MQTT (EMQX)', trailing: '24ms Latensi'),
        const SizedBox(height: 10),
        _BrokerCard(),
        const SizedBox(height: 24),
        const _SettingsSectionTitle(icon: Icons.info, label: 'INFORMASI APLIKASI'),
        const SizedBox(height: 10),
        _InfoCard(),
        const SizedBox(height: 18),
        const Center(child: Text('PT. SAPTA PUSAKA LISTRIK NUSANTARA', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), letterSpacing: .5))),
        const SizedBox(height: 4),
        const Center(child: Text('Sistem Kendali Motor Listrik Industri Tegangan Tinggi', style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1))),),
      ])))),
      bottomNavigationBar: _BottomNav(activeSettings: true, onSettings: () {}),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle({required this.icon, required this.label, this.trailing});
  final IconData icon;
  final String label;
  final String? trailing;
  @override
  Widget build(BuildContext context) => Row(children: [Icon(icon, color: const Color(0xFFB61722), size: 18), const SizedBox(width: 6), Text(label, style: const TextStyle(fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w700, color: Color(0xFF131B2E))), const Spacer(), if (trailing != null) Text(trailing!, style: const TextStyle(fontSize: 10, color: Color(0xFF006C49), fontWeight: FontWeight.w700))]);
}

class _BrokerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.fromLTRB(16, 16, 16, 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E7FF)), boxShadow: const [BoxShadow(color: Color(0x0C0F172A), blurRadius: 5)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('BROKER HOST', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), letterSpacing: 1)), const SizedBox(height: 3), Text('broker.emqx.io', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF131B2E))), const SizedBox(height: 2), const Text('SPLN Dedicated Enterprise Gateway', style: TextStyle(fontSize: 11, color: Color(0xFF64748B)))]), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFA7F3D0))), child: const Text('●  Terhubung', style: TextStyle(fontSize: 10, color: Color(0xFF065F46), fontWeight: FontWeight.w700)))]), const Divider(height: 26), Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('PORT & PROTOKOL', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), letterSpacing: 1)), SizedBox(height: 4), Text('8883 (MQTTS)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)), SizedBox(height: 3), Text('SSL / TLS v1.3 Aktif', style: TextStyle(fontSize: 10, color: Color(0xFF006C49), fontWeight: FontWeight.w700))])), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('CLIENT ID', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), letterSpacing: 1)), const SizedBox(height: 4), const Text('spln-mobile-app-9481', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(height: 3), const Text('QoS Level 1 (Guaranteed)', style: TextStyle(fontSize: 10, color: Color(0xFF64748B)))])]), const Divider(height: 26), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.network_ping, size: 16, color: Color(0xFF006C49)), label: const Text('Uji Koneksi', style: TextStyle(color: Color(0xFF131B2E), fontSize: 11)))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.edit, size: 16, color: Color(0xFFB61722)), label: const Text('Edit Konfigurasi', style: TextStyle(color: Color(0xFF131B2E), fontSize: 11))))])])))
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E7FF))), child: Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xFFF2F3FF), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.terminal, size: 18, color: Color(0xFFB61722))), const SizedBox(width: 10), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Versi Aplikasi', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))), SizedBox(height: 3), Text('v26.10.0 (SPLN IoT V1)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))])), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), color: const Color(0xFFE2E7FF), child: const Text('Build 2026.10', style: TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w600)))]));
}
*/
