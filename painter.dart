import 'dart:math';
import 'package:flutter/material.dart';
import 'engine.dart';
import 'models.dart';

Path _star(Offset o, double R) {
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? R : R * .45;
    final a = -pi / 2 + i * pi / 5;
    final pt = o + Offset(cos(a) * r, sin(a) * r);
    i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}

class BoardPainter extends CustomPainter {
  final bool stars;
  const BoardPainter(this.stars);
  @override
  void paint(Canvas c, Size z) {
    final u = z.width / 15;
    final fill = Paint();
    final line = Paint()..style = PaintingStyle.stroke..color = const Color(0xFF3B2316)..strokeWidth = 1.3;
    c.drawRect(Offset.zero & z, fill..color = const Color(0xFFEAD2A6));
    void box(List<int> p, Color? col) {
      final r = Rect.fromLTWH(p[0] * u, p[1] * u, u, u);
      c.drawRect(r, fill..color = col ?? const Color(0xFFF2E1BE));
      c.drawRect(r, line);
    }
    for (final p in kTrack) { box(p, null); }
    for (var s = 0; s < 4; s++) {
      for (final p in kLanes[s]) { box(p, kSeatColors[s]); }
      box(kTrack[kStart[s]], kSeatColors[s]);
      final o = kYard[s];
      final yr = RRect.fromRectAndRadius(Rect.fromLTWH(o[0] * u, o[1] * u, 6 * u, 6 * u), Radius.circular(u * 1.2));
      c.drawRRect(yr, fill..color = kSeatColors[s]);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH((o[0] + 1) * u, (o[1] + 1) * u, 4 * u, 4 * u), Radius.circular(u * .9)), fill..color = const Color(0xFFF4E6C8));
      for (final dx in [2, 4]) {
        for (final dy in [2, 4]) {
          c.drawCircle(Offset((o[0] + dx) * u, (o[1] + dy) * u), u * .62,
              Paint()..style = PaintingStyle.stroke..strokeWidth = u * .14..color = kSeatColors[s]);
        }
      }
    }
    Path tri(double ax, double ay, double bx, double by) =>
        Path()..moveTo(ax * u, ay * u)..lineTo(bx * u, by * u)..lineTo(7.5 * u, 7.5 * u)..close();
    final tris = [tri(6, 9, 9, 9), tri(6, 6, 6, 9), tri(6, 6, 9, 6), tri(9, 6, 9, 9)];
    for (var s = 0; s < 4; s++) {
      c.drawPath(tris[s], fill..color = kSeatColors[s]);
      c.drawPath(tris[s], line);
    }
    if (stars) {
      for (final b in kStart) {
        final p = kTrack[(b + 47) % 52];
        final o = Offset((p[0] + .5) * u, (p[1] + .5) * u);
        c.drawCircle(o, u * .4, fill..color = const Color(0xFF6B5444));
        c.drawPath(_star(o, u * .27), fill..color = Colors.white);
      }
    }
    c.drawRect(Offset.zero & z, line..strokeWidth = 4);
  }

  @override
  bool shouldRepaint(BoardPainter o) => o.stars != stars;
}

class TP {
  final Tok t;
  final Offset o; // in cell units
  final double s;
  TP(this.t, this.o, this.s);
}

class TokenPainter extends CustomPainter {
  final Game g;
  final Animation<double> pulse;
  TokenPainter(this.g, this.pulse) : super(repaint: Listenable.merge([g.tick, pulse]));

  static List<TP> layout(Game g) {
    final out = <TP>[];
    final groups = <int, List<Tok>>{};
    for (final t in g.toks) {
      if (t.p < 0) {
        final y = kYard[t.seat];
        out.add(TP(t, Offset(y[0] + 2.0 + (t.i % 2) * 2, y[1] + 2.0 + (t.i ~/ 2) * 2), 1));
      } else if (t.p == 56) {
        const dirs = [Offset(0, 1), Offset(-1, 0), Offset(0, -1), Offset(1, 0)];
        final d = dirs[t.seat];
        final k = (t.i - (g.s.coins - 1) / 2) * .3;
        out.add(TP(t, const Offset(7.5, 7.5) + d * .95 + Offset(-d.dy, d.dx) * k, .55));
      } else {
        final cell = t.p <= 50 ? kTrack[(kStart[t.seat] + t.p) % 52] : kLanes[t.seat][t.p - 51];
        groups.putIfAbsent(cell[0] * 20 + cell[1], () => []).add(t);
      }
    }
    groups.forEach((key, list) {
      final base = Offset(key ~/ 20 + .5, key % 20 + .5);
      final n = list.length;
      for (var k = 0; k < n; k++) {
        if (n == 1) { out.add(TP(list[k], base, 1)); }
        else {
          final a = 2 * pi * k / n - pi / 4;
          out.add(TP(list[k], base + Offset(cos(a), sin(a)) * .22, n > 2 ? .55 : .62));
        }
      }
    });
    return out;
  }

  @override
  void paint(Canvas c, Size z) {
    final u = z.width / 15;
    final mv = {for (final m in g.moves) m.t};
    final items = layout(g)..sort((a, b) => (mv.contains(a.t) ? 1 : 0) - (mv.contains(b.t) ? 1 : 0));
    for (final it in items) {
      final o = it.o * u;
      final r = u * .4 * it.s;
      final col = kSeatColors[it.t.seat];
      c.drawCircle(o + Offset(0, r * .15), r, Paint()..color = const Color(0x55000000));
      c.drawCircle(o, r, Paint()..color = const Color(0xFFD8C3A0));
      c.drawCircle(o, r * .72, Paint()..color = Color.lerp(col, Colors.black, .25)!);
      c.drawCircle(o, r * .5, Paint()..color = col);
      if (mv.contains(it.t)) {
        c.drawCircle(o, r * (1.12 + .14 * pulse.value),
            Paint()..style = PaintingStyle.stroke..strokeWidth = u * .09..color = const Color(0xFFFFE082));
      }
    }
  }

  @override
  bool shouldRepaint(TokenPainter o) => false;
}

class DicePainter extends CustomPainter {
  final int v;
  final Color color;
  const DicePainter(this.v, this.color);

  // Smaller "l"/"h" keeps the bigger dots nicely inside the face.
  static const _l = .30, _m = .50, _h = .70;
  static const _pos = {
    1: [[_m, _m]],
    2: [[_l, _l], [_h, _h]],
    3: [[_l, _l], [_m, _m], [_h, _h]],
    4: [[_l, _l], [_h, _l], [_l, _h], [_h, _h]],
    5: [[_l, _l], [_h, _l], [_m, _m], [_l, _h], [_h, _h]],
    6: [[_l, _l], [_h, _l], [_l, _m], [_h, _m], [_l, _h], [_h, _h]],
  };

  @override
  void paint(Canvas c, Size z) {
    final w = z.width;

    // ---- Permanent 30° tilt around the dice centre ----
    c.save();
    c.translate(w / 2, w / 2);
    c.rotate(pi / 6);           // 30 degrees
    c.translate(-w / 2, -w / 2);

    final r = RRect.fromRectAndRadius(Offset.zero & z, Radius.circular(w * .2));
    c.drawRRect(r.shift(Offset(0, w * .04)), Paint()..color = const Color(0x55000000));
    c.drawRRect(r, Paint()..color = color);
    c.drawRRect(
      r.deflate(w * .03),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .05
        ..color = Color.lerp(color, Colors.white, .35)!,
    );

    // ---- Bigger pips (radius 0.14 × width, up from 0.08) ----
    final pipPaint = Paint()..color = Colors.white;
    for (final p in _pos[v.clamp(1, 6)]!) {
      c.drawCircle(Offset(p[0] * w, p[1] * w), w * .14, pipPaint);
    }

    c.restore();
  }

  @override
  bool shouldRepaint(DicePainter o) => o.v != v || o.color != color;
}