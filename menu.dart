import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_screen.dart';
import 'models.dart';
import 'painter.dart';

const _h = TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -.5, color: Colors.black87);
const _lvl = ['', 'Easy', 'Medium', 'Hard'];

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});
  @override
  State<MenuScreen> createState() => _MenuState();
}

class _MenuState extends State<MenuScreen> {
  Setup s = Setup();
  SharedPreferences? prefs;
  Map<String, dynamic>? saved;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    try {
      final j = p.getString('setup');
      if (j != null) s = Setup.fromJson(jsonDecode(j));
    } catch (_) { s = Setup(); }
    Map<String, dynamic>? g;
    try {
      final j = p.getString('game');
      if (j != null) { g = jsonDecode(j); Setup.fromJson(g!['setup']); }
    } catch (_) { g = null; p.remove('game'); }
    if (mounted) setState(() { prefs = p; saved = g; });
  }

  Future<void> _go(bool resume) async {
    final p = prefs!;
    if (!resume) {
      if (s.seats.where((x) => x != 0).length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least 2 players')));
        return;
      }
      await p.setString('setup', jsonEncode(s.toJson()));
      await p.remove('game');
    }
    if (!mounted) return;
    final st = resume ? Setup.fromJson(saved!['setup']) : s;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(setup: st, saved: resume ? saved : null, prefs: p)));
    _load();
  }

  Widget _section(String t, Widget child) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.only(left: 14),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: const BoxDecoration(color: kGold, borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
          child: Text(t, style: _h),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: kGold, width: 3)),
          child: child,
        ),
      ]);

  Widget _player(int i, Color c) {
    final v = s.seats[i];
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => s.seats[i] = (v + 1) % 3),
        child: Container(
          height: 54, margin: const EdgeInsets.all(4), alignment: Alignment.center,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 2))]),
          child: Text(v == 0 ? 'None' : '${v == 1 ? 'Human' : 'Bot'} ${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }

  Widget _chip(String t, bool sel, VoidCallback f) => GestureDetector(
        onTap: f,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: kGold, shape: t.length == 1 ? BoxShape.circle : BoxShape.rectangle, borderRadius: t.length == 1 ? null : BorderRadius.circular(14),
              border: Border.all(color: sel ? const Color(0xFF2E9B2E) : Colors.transparent, width: 3)),
          child: Text(t, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        ),
      );

  Widget _tick(bool on, VoidCallback f) => GestureDetector(
        onTap: f,
        child: Container(
          width: 46, height: 46,
          decoration: BoxDecoration(shape: BoxShape.circle, color: on ? const Color(0xFF4CAF50) : const Color(0xFFD9423A),
              border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]),
          child: Icon(on ? Icons.check : Icons.close, color: Colors.white, size: 30),
        ),
      );

  Widget _btn(String t, Color c, VoidCallback f) => Expanded(
        child: GestureDetector(
          onTap: f,
          child: Container(
            height: 54, margin: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center,
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 5, offset: Offset(0, 3))]),
            child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
          ),
        ),
      );

  Widget _die(int v) => GestureDetector(
        onTap: () => setState(() => s.startAt = v),
        child: Container(
          margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: s.startAt == v ? const Color(0xFF2E9B2E) : Colors.transparent, width: 3)),
          child: CustomPaint(size: const Size(44, 44), painter: DicePainter(v, kGold)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (prefs == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    const logo = [('L', Color(0xFFE53935)), ('U', Color(0xFF3F6FE0)), ('D', Color(0xFF43A047)), ('O', Color(0xFF43A047))];
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final l in logo) Text(l.$1, style: TextStyle(fontSize: 60, height: 1, fontWeight: FontWeight.w900, color: l.$2, shadows: const [Shadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 3))])),
              ]),
              const Text('Neo-Classic', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(2, 10, 2, 10), children: [
              _section('Select Players:', Column(children: [
                Row(children: [_player(1, const Color(0xFFE8553F)), _player(2, const Color(0xFF3F5FE8))]),
                Row(children: [_player(0, const Color(0xFF5DB85C)), _player(3, const Color(0xFFFFF176))]),
              ])),
              const SizedBox(height: 10),
              _section('Options:', Column(children: [
                Row(children: [
                  const Text('Coins:', style: _h),
                  for (var n = 1; n <= 4; n++) _chip('$n', s.coins == n, () => setState(() => s.coins = n)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  const Text('Diff. Level:', style: _h),
                  _chip(_lvl[s.level], true, () => setState(() => s.level = s.level % 3 + 1)),
                ]),
                Row(children: [
                  const Text('Coin moving speed:', style: _h),
                  Expanded(child: Slider(value: s.speed, activeColor: const Color(0xFF3F9A2F), onChanged: (v) => setState(() => s.speed = v))),
                ]),
              ])),
              const SizedBox(height: 10),
              _section('Game Rules:', Column(children: [
                Row(children: [const Expanded(child: Text('Start coins at:', style: _h)), _die(1), _die(6)]),
                for (final e in kRuleLabels.entries)
                  Container(
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.black12))),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(child: Text(e.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.5))),
                      _tick(s.on(e.key), () => setState(() => s.f[e.key] = !s.on(e.key))),
                    ]),
                  ),
              ])),
            ]),
          ),
          if (saved != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [_btn('Resume', const Color(0xFF3F6FE0), () => _go(true))])),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              _btn('Exit', const Color(0xFFE0503E), () => Navigator.of(context).maybePop().then((_) => SystemNavigator.pop())),
              _btn('Play', const Color(0xFF5DB85C), () => _go(false)),
            ]),
          ),
        ]),
      ),
    );
  }
}
