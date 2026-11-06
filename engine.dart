import 'dart:math';
import 'package:flutter/foundation.dart';
import 'models.dart';

class Tok {
  final int seat, i;
  int p = -1; // -1 yard, 0..50 track, 51..55 home lane, 56 home
  Tok(this.seat, this.i);
}

class Move {
  final Tok t;
  final int to;
  Move(this.t, this.to);
}

class Game {
  final Setup s;
  final List<Tok> toks = [];
  final List<int> active = [];
  int turn = 0, dice = 1, sixes = 0, ones = 0;
  bool rolled = false,
      busy = false,
      paused = false,
      over = false,
      rolling = false,
      disposed = false;
  List<Move> moves = [];
  final List<int> ranks = [];
  final List<bool> hasCut = List.filled(4, false);
  String msg = '';
  final tick = ValueNotifier<int>(0);
  void Function(Map<String, dynamic>)? onSave;
  VoidCallback? onOver;
  final _rnd = Random();
  late final Set<int> _safe;

  Game(this.s, [Map<String, dynamic>? saved]) {
    for (var i = 0; i < 4; i++) {
      if (s.seats[i] == 0) continue;
      active.add(i);
      for (var k = 0; k < s.coins; k++) {
        toks.add(Tok(i, k));
      }
    }
    _safe = {
      ...kStart,
      if (s.on('stars')) for (final b in kStart) (b + 47) % 52,
    };
    turn = active.first;
    if (saved != null) {
      final p = List<int>.from(saved['p']);
      for (var i = 0; i < toks.length; i++) {
        toks[i].p = p[i];
      }
      turn = saved['turn'];
      ranks.addAll(List<int>.from(saved['ranks']));
      final hc = List<bool>.from(saved['hc']);
      for (var i = 0; i < 4; i++) {
        hasCut[i] = hc[i];
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'setup': s.toJson(),
        'p': [for (final t in toks) t.p],
        'turn': turn,
        'ranks': ranks,
        'hc': hasCut,
      };

  bool isBot(int seat) => s.seats[seat] == 2;
  int get _step => (260 - s.speed * 220).round();
  int _cell(Tok t) => (kStart[t.seat] + t.p) % 52;

  /// Safe increment — silently no-ops if the notifier is already disposed.
  void notify() {
    if (disposed) return;
    try {
      tick.value++;
    } catch (_) {
      // Disposed between the flag and the notification — ignore.
    }
  }

  /// 0 = waiting for roll, 1 = waiting for tap, 2 = animating/transition, 3 = over
  int get phase {
    if (over) return 3;
    if (rolling || busy) return 2;
    if (rolled && moves.isNotEmpty) return 1;
    if (rolled && moves.isEmpty) return 2;
    return 0;
  }

  void start() {
    notify();
    _kick();
  }

  void dispose() {
    if (disposed) return;
    disposed = true;
    tick.dispose();
  }

  double progress(int seat) {
    var sum = 0;
    for (final t in toks) {
      if (t.seat == seat && t.p > 0) sum += t.p;
    }
    return sum / (s.coins * 56) * 100;
  }

  // ---------------------------------------------------------------------------
  // Async wait (pauses when the pause flag is set)
  // ---------------------------------------------------------------------------

  Future<void> _wait(int ms) async {
    await Future.delayed(Duration(milliseconds: ms));
    while (paused && !disposed) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _kick() async {
    if (over || disposed || !isBot(turn) || rolled || busy) return;
    busy = true;
    await _wait(600);
    busy = false;
    if (disposed || over) return;
    roll();
  }

  // ---------------------------------------------------------------------------
  // Dice roll
  // ---------------------------------------------------------------------------

  bool _shouldForfeitTripleSix() =>
      sixes == 3 && (s.on('tripleSix') || s.on('threeSixOut'));

  Future<void> roll([int? force]) async {
    if (busy || rolled || over || paused || disposed) return;
    busy = true;
    rolled = true;
    rolling = true;
    dice = force ?? _rnd.nextInt(6) + 1;
    msg = '';
    notify();

    await _wait(500);
    if (disposed) return;
    rolling = false;

    final d = dice;
    sixes = d == 6 ? sixes + 1 : 0;
    ones = d == 1 ? ones + 1 : 0;
    notify();

    // ---- Triple-six forfeit ----
    if (_shouldForfeitTripleSix()) {
      if (s.on('threeSixOut')) {
        final y = toks.where((t) => t.seat == turn && t.p < 0).toList();
        if (y.isNotEmpty) {
          y.first.p = 0;
          msg = 'Third 6: coin out';
        }
      } else {
        msg = 'Third 6: turn forfeited';
      }
      notify();
      await _wait(600);
      if (disposed) return;
      return _end();
    }

    // ---- Triple-ones ----
    if (ones == 3 && (s.on('threeOnesCut') || s.on('skipThreeOnes'))) {
      if (s.on('threeOnesCut')) {
        final c = toks
            .where((t) => t.seat == turn && t.p >= 0 && t.p <= 50)
            .toList();
        if (c.isNotEmpty) {
          c.sort((a, b) => b.p.compareTo(a.p));
          c.first.p = -1;
          msg = 'Three 1s: own coin cut';
        }
      }
      notify();
      await _wait(700);
      if (disposed) return;
      return _end();
    }

    // ---- Legal moves ----
    moves = _legal();
    notify();

    // FIXED: was `moves.isEmpty()` — List.isEmpty is a getter, not a method.
    if (moves.isEmpty) {
      msg = 'No move';
      notify();
      await _wait(600);
      if (disposed) return;

      // Kotlin parity: extra turn on 6 even if no coin can move.
      if (d == 6 && s.on('sixExtra')) {
        rolled = false;
        busy = false;
        notify();
        _kick();
      } else {
        _end();
      }
      return;
    }

    if (isBot(turn)) {
      await _wait(400);
      if (disposed) return;
      return _apply(_pick());
    }

    // Auto-play when the only legal source is a single physical position.
    final first = moves.first;
    if (moves.every((m) => m.t.p == first.t.p)) {
      await _wait(350);
      if (disposed) return;
      return _apply(first);
    }
    busy = false;
    notify();
  }

  void tapToken(Tok t) {
    if (busy || !rolled || over || paused || isBot(turn)) return;
    final m = moves.where((m) => m.t == t);
    if (m.isNotEmpty) _apply(m.first);
  }

  // ---------------------------------------------------------------------------
  // Movement legality
  // ---------------------------------------------------------------------------

  bool _barrierAt(int c, int seat) {
    if (!s.on('barrier') || _safe.contains(c)) return false;
    for (var k = 0; k < 4; k++) {
      if (k == seat) continue;
      var n = 0;
      for (final o in toks) {
        if (o.seat == k && o.p >= 0 && o.p <= 50 && _cell(o) == c) n++;
      }
      if (n >= 2) return true;
    }
    return false;
  }

  bool _blocked(int seat, int a, int b) {
    for (var p = a; p <= b && p <= 50; p++) {
      if (_barrierAt((kStart[seat] + p) % 52, seat)) return true;
    }
    return false;
  }

  bool _cuts(Move m) {
    if (m.to > 50) return false;
    final c = (kStart[m.t.seat] + m.to) % 52;
    if (_safe.contains(c)) return false;
    return toks.any((o) =>
        o.seat != m.t.seat && o.p >= 0 && o.p <= 50 && _cell(o) == c);
  }

  List<Move> _legal() {
    final out = <Move>[];
    final d = dice;
    for (final t in toks) {
      if (t.seat != turn || t.p == 56) continue;
      int to;
      if (t.p < 0) {
        if (!(d == s.startAt || (d == 6 && s.on('sixOut')))) continue;
        to = 0;
      } else {
        to = t.p + d;
        if (to > 56) continue;
        if (to > 50 && t.p <= 50 && s.on('cutToEnter') && !hasCut[turn]) {
          continue;
        }
        if (_blocked(t.seat, t.p + 1, min(to, 50))) continue;
      }
      out.add(Move(t, to));
    }
    if (d == 1 && s.on('mustOutOnOne')) {
      final y = out.where((m) => m.t.p < 0).toList();
      if (y.isNotEmpty) return y;
    }
    if (s.on('mustCut')) {
      final c = out.where(_cuts).toList();
      if (c.isNotEmpty) return c;
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // AI
  // ---------------------------------------------------------------------------

  Move _pick() {
    if (s.level == 1 || (s.level == 2 && _rnd.nextBool())) {
      return moves[_rnd.nextInt(moves.length)];
    }
    var best = moves.first;
    var bs = -1e9;
    for (final m in moves) {
      final sc = _score(m) + _rnd.nextDouble();
      if (sc > bs) {
        bs = sc;
        best = m;
      }
    }
    return best;
  }

  double _danger(int c, int seat) {
    if (_safe.contains(c)) return 0;
    var d = 0.0;
    for (final o in toks) {
      if (o.seat == seat || o.p < 0 || o.p > 50) continue;
      final dist = (c - _cell(o) + 52) % 52;
      if (dist >= 1 && dist <= 6) d += 1;
    }
    return d;
  }

  double _score(Move m) {
    final t = m.t;
    if (t.p < 0) return 60 + _rnd.nextDouble() * 10;

    var sc = m.to * 0.5;

    if (m.to == 56) {
      sc += 100;
    } else if (m.to > 50 && t.p <= 50) {
      sc += 30;
    }

    if (m.to <= 50) {
      final c = (kStart[t.seat] + m.to) % 52;
      if (_safe.contains(c)) {
        sc += 30;
      } else {
        if (_cuts(m)) sc += 120;
        final dangerCount = _danger(c, t.seat);
        if (dangerCount > 0) sc -= 40 * dangerCount;
      }
    }

    if (t.p >= 0 && t.p <= 50) {
      final curCell = _cell(t);
      if (!_safe.contains(curCell)) {
        final dangerCount = _danger(curCell, t.seat);
        if (dangerCount > 0) sc += 35 * dangerCount;
      }
    }

    return sc + _rnd.nextDouble() * 10;
  }

  // ---------------------------------------------------------------------------
  // Applying a move
  // ---------------------------------------------------------------------------

  Future<void> _apply(Move m) async {
    busy = true;
    moves = [];
    final t = m.t;
    var extra = false;

    if (t.p < 0) {
      t.p = 0;
      notify();
      await _wait(150);
      if (disposed) return; // <-- added: yard-exit path now checks disposed
    } else {
      while (t.p < m.to) {
        t.p++;
        notify();
        await _wait(_step);
        if (disposed) return;
      }
    }

    // Cutting
    if (t.p <= 50) {
      final c = _cell(t);
      if (!_safe.contains(c)) {
        for (final o in toks) {
          if (o.seat != t.seat && o.p >= 0 && o.p <= 50 && _cell(o) == c) {
            o.p = -1;
            hasCut[t.seat] = true;
            if (s.on('cutExtra')) extra = true;
          }
        }
      }
    }

    if (t.p == 56 && s.on('homeExtra')) extra = true;
    if (dice == 6 && s.on('sixExtra')) extra = true;

    // Win check
    if (toks.where((x) => x.seat == t.seat).every((x) => x.p == 56)) {
      ranks.add(t.seat);
      extra = false;
      msg = '${kSeatNames[t.seat]} finished #${ranks.length}';
      if (ranks.length >= active.length - 1) {
        for (final a in active) {
          if (!ranks.contains(a)) ranks.add(a);
        }
        over = true;
        busy = false;
        notify();
        onOver?.call();
        return;
      }
    }

    notify();
    await _wait(200);
    if (disposed) return;

    if (extra) {
      rolled = false;
      busy = false;
      msg = 'Roll again';
      notify();
      _kick();
    } else {
      _end();
    }
  }

  void _end() {
    if (disposed) return; // <-- added
    sixes = 0;
    ones = 0;
    rolled = false;
    busy = false;
    moves = [];
    var i = active.indexOf(turn);
    do {
      i = (i + 1) % active.length;
    } while (ranks.contains(active[i]));
    turn = active[i];
    msg = '';
    notify();
    onSave?.call(toJson());
    _kick();
  }
}