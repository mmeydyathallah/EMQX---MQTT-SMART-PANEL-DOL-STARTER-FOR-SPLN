import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'mqtt_config.dart';
import 'mqtt_service.dart';
import 'foreground_service.dart';

class FinalApp extends StatelessWidget {
  const FinalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB61722)), textTheme: GoogleFonts.plusJakartaSansTextTheme()),
      home: const ControlScreen(),
    );
  }
}

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});
  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  late MqttService mqtt;
  String motorState = 'STATUS SIAGA';
  bool connected = false;
  bool connecting = false;
  bool espOnline = false;
  bool modeAuto = false;
  int _epoch = 0;
  final List<LogEntry> _logs = [];
  Timer? _confirmTimer;
  String? _pendingCommand;

  void _log(String text, LogKind kind) {
    if (!mounted) return;
    final t = DateTime.now();
    final stamp = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
    setState(() {
      _logs.add(LogEntry(time: stamp, text: text, kind: kind));
      if (_logs.length > 120) _logs.removeAt(0);
    });
  }

  @override
  void initState() {
    super.initState();
    connecting = true;
    MqttConfig.connecting = true;
    mqtt = MqttService(
      host: MqttConfig.host,
      port: MqttConfig.port,
      username: MqttConfig.username,
      password: MqttConfig.password,
    );
    mqtt.onStatus = _onStatus;
    mqtt.onDisconnect = _onDisconnected;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startForeground();
      _connect();
    });
  }

  Future<void> _startForeground() async {
    ForegroundService.init();
    try {
      await ForegroundService.requestPermissions();
    } catch (_) {}
    final ok = await ForegroundService.start();
    if (!mounted) return;
    _log(ok
        ? 'Foreground service aktif (koneksi dijaga saat layar mati)'
        : 'Gagal mengaktifkan foreground service', ok ? LogKind.system : LogKind.error);
  }

  @override
  void dispose() { _confirmTimer?.cancel(); ForegroundService.stop(); mqtt.disconnect(); super.dispose(); }

  Future<void> _connect() async {
    final epoch = ++_epoch;
    setState(() { connecting = true; espOnline = false; MqttConfig.connecting = true; });
    _log('Menghubungkan ke ${MqttConfig.host}:${MqttConfig.port} ...', LogKind.system);
    try {
      await mqtt.connect();
      if (!mounted || epoch != _epoch) return;
      setState(() {
        connected = mqtt.isConnected;
        connecting = false;
        MqttConfig.connected = connected;
        MqttConfig.connecting = false;
      });
      if (connected) {
        _log('Terhubung ke EMQX (${MqttConfig.host}:${MqttConfig.port})', LogKind.system);
        _log('Subscribe dol/starter/status', LogKind.system);
        ForegroundService.updateText('MQTT terhubung ke EMQX');
      }
    } catch (error) {
      if (!mounted || epoch != _epoch) return;
      setState(() {
        connected = false;
        connecting = false;
        MqttConfig.connected = false;
        MqttConfig.connecting = false;
      });
      _log('Gagal connect: ${error.toString().replaceFirst('Exception: ', '')}', LogKind.error);
    }
  }

  void _toggleConnection() {
    if (connected || connecting) {
      _epoch++;
      mqtt.disconnect();
      _confirmTimer?.cancel();
      _pendingCommand = null;
      ForegroundService.stop();
      _log('Koneksi diputus manual', LogKind.system);
      setState(() {
        connected = false;
        connecting = false;
        espOnline = false;
        MqttConfig.connected = false;
        MqttConfig.connecting = false;
      });
    } else {
      _connect();
    }
  }

  Future<void> _openSettings() async {
    final revision = MqttConfig.revision;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
    if (!mounted || revision == MqttConfig.revision) return;
    _epoch++;
    mqtt.disconnect();
    mqtt = MqttService(
      host: MqttConfig.host,
      port: MqttConfig.port,
      username: MqttConfig.username,
      password: MqttConfig.password,
    );
    mqtt.onStatus = _onStatus;
    mqtt.onDisconnect = _onDisconnected;
    _connect();
  }

  void _onStatus(Map<String, dynamic> status) {
    if (!mounted) return;
    _log('RX dol/starter/status ${jsonEncode(status)}', LogKind.rx);
    if (_pendingCommand != null) {
      _confirmTimer?.cancel();
      _log('TX terkonfirmasi oleh ESP32 (${_pendingCommand!})', LogKind.system);
      _pendingCommand = null;
    }
    final online = status['online'] != false;
    setState(() {
      espOnline = online;
      modeAuto = status['auto'] == true;
      if (!online) {
        motorState = 'ESP32 OFFLINE';
      } else if (status['forward'] == true) {
        motorState = 'MOTOR MAJU';
      } else if (status['reverse'] == true) {
        motorState = 'MOTOR MUNDUR';
      } else if (status['manual'] == true) {
        motorState = 'MODE MANUAL';
      } else if (status['auto'] == true) {
        motorState = 'MODE AUTO';
      } else if (status['space'] == true) {
        motorState = 'SPACE AKTIF';
      } else {
        motorState = 'STATUS SIAGA';
      }
    });
  }

  void _onDisconnected() {
    if (!mounted) return;
    _confirmTimer?.cancel();
    _pendingCommand = null;
    _log('Koneksi ke broker terputus (link hilang)', LogKind.error);
    ForegroundService.updateText('MQTT terputus • menunggu koneksi');
    setState(() {
      connected = false;
      connecting = false;
      espOnline = false;
      MqttConfig.connected = false;
      MqttConfig.connecting = false;
    });
  }

  void command(String command, String label) {
    if (!connected) {
      _log('TX ditolak ($command): belum terhubung ke broker', LogKind.error);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Belum terhubung ke broker MQTT • tap chip EMQX untuk koneksi')));
      return;
    }
    setState(() => motorState = label);
    _log('TX (queued) dol/starter/command {"command":"$command"}', LogKind.tx);
    mqtt.publishCommand(MqttService.commandTopic, {'command': command});
    _pendingCommand = command;
    _confirmTimer?.cancel();
    _confirmTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || _pendingCommand != command) return;
      _log('Tidak ada konfirmasi ESP32 untuk $command (8s)', LogKind.error);
      setState(() => motorState = 'MENUNGGU KONFIRMASI');
    });
  }

  void _setMode(bool auto) {
    setState(() => modeAuto = auto);
    command(auto ? 'MODE_AUTO' : 'MODE_MANUAL', auto ? 'MODE AUTO' : 'MODE MANUAL');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(preferredSize: const Size.fromHeight(62), child: AppHeader(connected: connected, connecting: connecting, onToggleConnection: _toggleConnection)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 110), children: [
        const MotorSummary(),
        const SizedBox(height: 16),
        StatusSummary(label: motorState),
        const SizedBox(height: 10),
        Row(children: [
          Icon(espOnline ? Icons.memory : Icons.memory_outlined, size: 15, color: espOnline ? const Color(0xFF059669) : const Color(0xFF94A3B8)),
          const SizedBox(width: 6),
          Text('ESP32 ${espOnline ? 'ONLINE' : 'OFFLINE'}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: espOnline ? const Color(0xFF059669) : const Color(0xFF94A3B8))),
          const Spacer(),
          if (connected) const Text('Telemetri • dol/starter/status', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: ActionButton(label: 'START FORWARD', subtitle: 'RELAY 1 • GPIO13', icon: Icons.arrow_upward, color: const Color(0xFF10B981), onTap: () => command('START_FORWARD', 'MOTOR MAJU'))),
          const SizedBox(width: 12),
          Expanded(child: ActionButton(label: 'START REVERSE', subtitle: 'RELAY 2 • GPIO14', icon: Icons.arrow_downward, color: const Color(0xFF0284C7), onTap: () => command('START_REVERSE', 'MOTOR MUNDUR'))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ActionButton(label: 'STOP', subtitle: 'RELAY 3 • GPIO25', icon: Icons.stop, color: const Color(0xFFEF4444), onTap: () => command('STOP', 'MOTOR STOP'))),
          const SizedBox(width: 12),
          Expanded(child: ActionButton(label: 'SPACE', subtitle: 'RELAY 6 • GPIO32', icon: Icons.space_bar, color: const Color(0xFFD97706), onTap: () => command('SPACE', 'SPACE AKTIF'))),
        ]),
        const SizedBox(height: 12),
        ModeSwitchCard(auto: modeAuto, enabled: connected, onChanged: _setMode),
        const SizedBox(height: 20),
        LogConsole(logs: _logs, onClear: () => setState(() => _logs.clear())),
      ]),
      bottomNavigationBar: BottomNav(settingsActive: false, onSettings: _openSettings),
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({this.connected = false, this.connecting = false, this.onToggleConnection, super.key});
  final bool connected;
  final bool connecting;
  final VoidCallback? onToggleConnection;
  @override
  Widget build(BuildContext context) {
    return Container(height: 62, decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Image.asset('assets/spln_logo.png', height: 28, width: 88), ConnectionChip(connected: connected, connecting: connecting, onTap: onToggleConnection)])));
  }
}

class ConnectionChip extends StatelessWidget {
  const ConnectionChip({this.connected = false, this.connecting = false, this.onTap, super.key});
  final bool connected;
  final bool connecting;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final connectingNow = connecting && !connected;
    final Color color;
    final Color background;
    final Color borderColor;
    final String text;
    if (connected) {
      color = const Color(0xFF059669);
      background = const Color(0xFFECFDF5);
      borderColor = const Color(0xFFA7F3D0);
      text = 'EMQX CONNECTED';
    } else if (connectingNow) {
      color = const Color(0xFFD97706);
      background = const Color(0xFFFFFBEB);
      borderColor = const Color(0xFFFDE68A);
      text = 'MENGHUBUNGKAN...';
    } else {
      color = const Color(0xFF64748B);
      background = const Color(0xFFF1F5F9);
      borderColor = const Color(0xFFE2E8F0);
      text = 'EMQX OFFLINE';
    }
    final chip = Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: background, border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, size: 9, color: color), const SizedBox(width: 6), Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700))]));
    if (onTap == null) return chip;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: chip);
  }
}

class MotorSummary extends StatelessWidget {
  const MotorSummary({super.key});
  @override
  Widget build(BuildContext context) => Column(children: [Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF1F5F9)), boxShadow: const [BoxShadow(color: Color(0x080F172A), blurRadius: 5)]), child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.bolt, color: Color(0xFFE11D48))), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('DOL STARTER MOTOR', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(height: 4), const Text('Pompa Transfer 01 • 15 kW • Substation A', style: TextStyle(fontSize: 11, color: Color(0xFF64748B)))]))])), const SizedBox(height: 10), const Row(children: [Icon(Icons.verified_user, size: 17, color: Color(0xFF059669)), SizedBox(width: 6), Text('Sistem Terproteksi • Interlock Aktif', style: TextStyle(fontSize: 12, color: Color(0xFF475569))), Spacer(), Text('MODE REMOTE', style: TextStyle(fontSize: 10, color: Color(0xFF0369A1), fontWeight: FontWeight.w700))])]);
}

class StatusSummary extends StatelessWidget {
  const StatusSummary({required this.label, super.key});
  final String label;
  @override
  Widget build(BuildContext context) {
    final offline = label.contains('OFFLINE');
    final waiting = label.contains('MENUNGGU');
    final running = label.contains('MAJU') || label.contains('MUNDUR');
    final color = offline
        ? const Color(0xFF64748B)
        : waiting
            ? const Color(0xFFD97706)
            : running
                ? const Color(0xFF008A5B)
                : label.contains('AUTO')
                    ? const Color(0xFF0284C7)
                    : label.contains('MANUAL')
                        ? const Color(0xFF7C3AED)
                        : label.contains('SPACE')
                            ? const Color(0xFFD97706)
                            : const Color(0xFFB61722);
    final icon = offline
        ? Icons.cloud_off
        : waiting
            ? Icons.hourglass_top
            : running
                ? Icons.rotate_right
                : label.contains('AUTO')
                    ? Icons.autorenew
                    : label.contains('MANUAL')
                        ? Icons.touch_app
                        : label.contains('SPACE')
                            ? Icons.space_bar
                            : Icons.pause_circle;
    final tag = offline
        ? 'ESP32 TERPUTUS'
        : waiting
            ? 'BELUM DIKONFIRMASI'
            : running
                ? 'STATUS AKTIF'
                : label.contains('AUTO')
                    ? 'AUTO SENSOR'
                    : label.contains('MANUAL')
                        ? 'MANUAL MODE'
                        : label.contains('SPACE')
                            ? 'RELAY 6'
                            : 'SIAGA';
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF1F5F9))), child: Row(children: [Icon(icon, color: color, size: 32), const SizedBox(width: 14), Expanded(child: Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w700, color: color))), Text(tag, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800))]));
  }
}

class ActionButton extends StatelessWidget {
  const ActionButton({required this.label, required this.icon, required this.color, required this.onTap, this.iconColor = Colors.white, this.subtitle, super.key});
  final String label; final IconData icon; final Color color; final Color iconColor; final String? subtitle; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(height: 66, child: ElevatedButton.icon(onPressed: onTap, icon: Icon(icon, color: iconColor, size: 22), label: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700)), if (subtitle != null) Text(subtitle!, style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w500, color: iconColor.withValues(alpha: 0.75)))]), style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))));
}

class ModeSwitchCard extends StatelessWidget {
  const ModeSwitchCard({required this.auto, required this.enabled, required this.onChanged, super.key});
  final bool auto; final bool enabled; final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final accent = auto ? const Color(0xFF0284C7) : const Color(0xFF7C3AED);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE4E4E7))),
      child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)), child: Icon(auto ? Icons.autorenew : Icons.touch_app, size: 20, color: accent)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Text('MODE OPERASI', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(auto ? 'RELAY 5 • GPIO27 • Auto sensor' : 'RELAY 4 • GPIO26 • Kontrol manual', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        ])),
        Text(auto ? 'AUTO' : 'MANUAL', style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700, color: enabled ? accent : const Color(0xFF94A3B8))),
        const SizedBox(width: 8),
        CupertinoSwitch(value: auto, activeTrackColor: const Color(0xFF0284C7), inactiveTrackColor: const Color(0xFFCBD5E1), onChanged: enabled ? onChanged : null),
      ]),
    );
  }
}

enum LogKind { system, tx, rx, error }

class LogEntry {
  const LogEntry({required this.time, required this.text, required this.kind});
  final String time;
  final String text;
  final LogKind kind;
}

class LogConsole extends StatefulWidget {
  const LogConsole({required this.logs, required this.onClear, super.key});
  final List<LogEntry> logs;
  final VoidCallback onClear;
  @override
  State<LogConsole> createState() => _LogConsoleState();
}

class _LogConsoleState extends State<LogConsole> {
  final _controller = ScrollController();

  @override
  void didUpdateWidget(covariant LogConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.logs.length != oldWidget.logs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) _controller.jumpTo(_controller.position.maxScrollExtent);
      });
    }
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE4E4E7))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 8, 6, 6), child: Row(children: [
          const Icon(Icons.terminal, size: 16, color: Color(0xFF71717A)),
          const SizedBox(width: 8),
          Text('MQTT LOG', style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF09090B), letterSpacing: 1.1)),
          const Spacer(),
          Text('${widget.logs.length} pesan', style: const TextStyle(fontSize: 10, color: Color(0xFFA1A1AA))),
          TextButton(onPressed: widget.onClear, style: TextButton.styleFrom(foregroundColor: const Color(0xFF71717A), padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 32)), child: const Text('Bersihkan', style: TextStyle(fontSize: 11))),
        ])),
        const Divider(height: 1, color: Color(0xFFE4E4E7)),
        Expanded(child: widget.logs.isEmpty
            ? const Center(child: Text('Belum ada aktivitas MQTT', style: TextStyle(fontSize: 11, color: Color(0xFFA1A1AA))))
            : ListView.builder(controller: _controller, padding: const EdgeInsets.fromLTRB(12, 12, 12, 6), itemCount: widget.logs.length, itemBuilder: (context, i) => _LogBubble(entry: widget.logs[i]))),
      ]),
    );
  }
}

Color _bubbleColor(LogKind kind) => switch (kind) {
      LogKind.tx => const Color(0xFFB61722),
      LogKind.rx => const Color(0xFFF4F4F5),
      LogKind.error => const Color(0xFFFEF2F2),
      LogKind.system => Colors.white,
    };

Color _bubbleBorder(LogKind kind) => switch (kind) {
      LogKind.tx => const Color(0xFFB61722),
      LogKind.rx => const Color(0xFFE4E4E7),
      LogKind.error => const Color(0xFFFECACA),
      LogKind.system => const Color(0xFFE4E4E7),
    };

Color _bubbleText(LogKind kind) => switch (kind) {
      LogKind.tx => Colors.white,
      LogKind.rx => const Color(0xFF09090B),
      LogKind.error => const Color(0xFFB91C1C),
      LogKind.system => const Color(0xFF52525B),
    };

class _LogBubble extends StatelessWidget {
  const _LogBubble({required this.entry});
  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final outgoing = entry.kind == LogKind.tx;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
      bottomLeft: Radius.circular(outgoing ? 14 : 4),
      bottomRight: Radius.circular(outgoing ? 4 : 14),
    );
    final bubble = Flexible(child: Column(
      crossAxisAlignment: outgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: _bubbleColor(entry.kind), border: Border.all(color: _bubbleBorder(entry.kind)), borderRadius: radius),
          child: Text(entry.text, style: GoogleFonts.spaceMono(fontSize: 10.5, height: 1.4, color: _bubbleText(entry.kind))),
        ),
        const SizedBox(height: 3),
        Text(entry.time, style: const TextStyle(fontSize: 9, color: Color(0xFFA1A1AA))),
      ],
    ));
    final avatar = _LogAvatar(kind: entry.kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: outgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: outgoing ? [bubble, const SizedBox(width: 8), avatar] : [avatar, const SizedBox(width: 8), bubble],
      ),
    );
  }
}

class _LogAvatar extends StatelessWidget {
  const _LogAvatar({required this.kind});
  final LogKind kind;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color bg, Color fg) = switch (kind) {
      LogKind.tx => (Icons.arrow_upward, const Color(0xFFB61722), Colors.white),
      LogKind.rx => (Icons.arrow_downward, const Color(0xFFF4F4F5), const Color(0xFF3F3F46)),
      LogKind.error => (Icons.error_outline, const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
      LogKind.system => (Icons.info_outline, const Color(0xFFF4F4F5), const Color(0xFF71717A)),
    };
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE4E4E7))),
      child: Icon(icon, size: 14, color: fg),
    );
  }
}

class BottomNav extends StatelessWidget {
  const BottomNav({required this.settingsActive, required this.onSettings, super.key});
  final bool settingsActive; final VoidCallback onSettings;
  @override
  Widget build(BuildContext context) => Container(height: 76, decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF1F5F9))), boxShadow: [BoxShadow(color: Color(0x080F172A), blurRadius: 10)]), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_NavButton(label: 'Kontrol', icon: Icons.power_settings_new, active: !settingsActive, onTap: () => Navigator.popUntil(context, (r) => r.isFirst)), _NavButton(label: 'Pengaturan', icon: Icons.tune, active: settingsActive, onTap: onSettings)]));
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.label, required this.icon, required this.active, required this.onTap});
  final String label; final IconData icon; final bool active; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) { final color = active ? const Color(0xFFBE123C) : const Color(0xFF64748B); return InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 7), decoration: active ? BoxDecoration(color: const Color(0xFFFFE4E6), borderRadius: BorderRadius.circular(16)) : null, child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 22), Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w400))]))); }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String host;
  late int port;
  late String username;
  late String password;
  String connectionStatus = 'Belum diuji';
  bool testing = false;

  @override
  void initState() {
    super.initState();
    host = MqttConfig.host;
    port = MqttConfig.port;
    username = MqttConfig.username;
    password = MqttConfig.password;
  }

  Future<void> testConnection() async {
    setState(() { testing = true; connectionStatus = 'Menghubungkan...'; });
    final service = MqttService(host: host, port: port, username: username, password: password);
    try {
      await service.testConnection();
      if (mounted) setState(() => connectionStatus = 'Terhubung • koneksi berhasil');
    } catch (error) {
      if (mounted) setState(() => connectionStatus = 'Gagal terhubung: ${error.toString().replaceFirst('Exception: ', '')}');
    } finally {
      service.disconnect();
      if (mounted) setState(() => testing = false);
    }
  }

  Future<void> editConfiguration() async {
    final hostController = TextEditingController(text: host);
    final portController = TextEditingController(text: port.toString());
    final usernameController = TextEditingController(text: username);
    final passwordController = TextEditingController(text: password);
    bool obscurePassword = true;
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('Edit Konfigurasi MQTT'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: hostController, decoration: const InputDecoration(labelText: 'Broker host')),
          TextField(controller: portController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Port')),
          TextField(controller: usernameController, decoration: const InputDecoration(labelText: 'Username')),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
              ),
            ),
          ),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(context, [hostController.text.trim(), portController.text.trim(), usernameController.text.trim(), passwordController.text]), child: const Text('Simpan'))],
      )),
    );
    if (result == null || result.length != 4 || !mounted) return;
    final parsedPort = int.tryParse(result[1]);
    if (result[0].isEmpty || parsedPort == null || parsedPort < 1 || parsedPort > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Host dan port tidak valid')));
      return;
    }
    setState(() {
      host = result[0];
      port = parsedPort;
      username = result[2];
      password = result[3];
      connectionStatus = 'Konfigurasi berubah • silakan uji koneksi';
      MqttConfig.host = result[0];
      MqttConfig.port = parsedPort;
      MqttConfig.username = result[2];
      MqttConfig.password = result[3];
      MqttConfig.revision++;
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konfigurasi disimpan • koneksi ulang otomatis setelah kembali')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: PreferredSize(preferredSize: const Size.fromHeight(62), child: AppHeader(connected: MqttConfig.connected, connecting: MqttConfig.connecting)), body: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 110), children: [Text('Pengaturan', style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w700)), const Text('Konfigurasi Telemetri SCADA & Broker', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))), const SizedBox(height: 24), const Text('KONEKSI BROKER MQTT (EMQX)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)), const SizedBox(height: 10), BrokerPanel(host: host, port: port, username: username, status: connectionStatus, testing: testing, onTest: testConnection, onEdit: editConfiguration), const SizedBox(height: 24), const Text('INFORMASI APLIKASI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)), const SizedBox(height: 10), const InfoPanel()],), bottomNavigationBar: BottomNav(settingsActive: true, onSettings: () {}));
}

class BrokerPanel extends StatelessWidget {
  const BrokerPanel({required this.host, required this.port, required this.username, required this.status, required this.testing, required this.onTest, required this.onEdit, super.key});
  final String host; final int port; final String username; final String status; final bool testing; final VoidCallback onTest; final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E7FF))), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('BROKER HOST', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))), const SizedBox(height: 5), Text(host, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), const Text('SPLN Dedicated Enterprise Gateway', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))), const Divider(height: 26), Row(children: [Expanded(child: Text('PORT & PROTOKOL\n$port (${port == 8883 ? 'MQTTS' : port == 8084 ? 'WSS' : 'MQTT'})\nSSL / TLS aktif', style: const TextStyle(fontSize: 11, height: 1.6))), Expanded(child: Text('USERNAME\n$username\n$status', style: const TextStyle(fontSize: 11, height: 1.6)))]), const Divider(height: 26), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: testing ? null : onTest, icon: testing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.network_ping, size: 16), label: Text(testing ? 'Menguji...' : 'Uji Koneksi'))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit, size: 16), label: const Text('Edit Konfigurasi')))])])));
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({super.key});
  @override
  Widget build(BuildContext context) => Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE2E7FF))), child: const Padding(padding: EdgeInsets.all(16), child: Row(children: [Icon(Icons.terminal, color: Color(0xFFB61722)), SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Versi Aplikasi', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))), SizedBox(height: 3), Text('v26.10.0 (SPLN IoT V1)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))])), Text('Build 2026.10', style: TextStyle(fontSize: 10, color: Color(0xFF475569)))])));
}
