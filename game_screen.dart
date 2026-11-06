import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'engine.dart';
import 'models.dart';
import 'painter.dart';

class GameScreen extends StatefulWidget {
  final Setup setup;
  final Map<String, dynamic>? saved;
  final SharedPreferences prefs;

  const GameScreen({
    super.key,
    required this.setup,
    this.saved,
    required this.prefs,
  });

  @override
  State<GameScreen> createState() => _GameState();
}

class _GameState extends State<GameScreen> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _diceCtl;
  late Game _g;

  bool _overShown = false;
  bool _disposed = false;

  // ---- Dice free-drag state ----
  static const double _diceHalf = 1.1;       // half of dice width in board units
  static const double _minFlickSpeed = 15.0; // board units / second (matches Kotlin)
  Offset _dicePos = const Offset(7.5, 7.5);

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _diceCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _startGame(widget.saved);
  }

  @override
  void dispose() {
    _disposed = true;
    _releaseGame();
    _pulse.dispose();
    _diceCtl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Game bootstrapping / teardown
  // ---------------------------------------------------------------------------

  void _startGame(Map<String, dynamic>? saved) {
    if (saved == null) widget.prefs.remove('game');
    _overShown = false;

    _pulse.stop();
    _pulse.value = 0;
    _diceCtl.stop();
    _diceCtl.value = 0;
    _dicePos = const Offset(7.5, 7.5);

    final game = Game(widget.setup, saved)
      ..onSave = ((m) => widget.prefs.setString('game', jsonEncode(m)))
      ..onOver = (() => widget.prefs.remove('game'));

    game.tick.addListener(_onTick);
    _g = game;
    game.start();
  }

  void _releaseGame() {
    _g.tick.removeListener(_onTick);
    _g.dispose();
  }

  // ---------------------------------------------------------------------------
  // Tick handling
  // ---------------------------------------------------------------------------

  void _onTick() {
    if (!mounted || _disposed) return;

    if (_g.rolling) {
      if (!_diceCtl.isAnimating) _diceCtl.repeat();
    } else if (_diceCtl.isAnimating) {
      _diceCtl.stop();
      _diceCtl.value = 0;
    }

    if (_g.moves.isNotEmpty) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }

    if (_g.over && !_overShown) {
      _overShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _disposed) return;
        _showOver();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Dice drag & flick
  // ---------------------------------------------------------------------------

  bool get _canDragDice =>
      !_g.isBot(_g.turn) &&
      !_g.over &&
      !_g.paused &&
      !_g.rolling &&
      !_g.rolled;

  void _onDicePanUpdate(DragUpdateDetails d, double u) {
    if (!_canDragDice) return;
    final next = _dicePos + d.delta / u;
    setState(() {
      _dicePos = Offset(
        next.dx.clamp(_diceHalf, 15 - _diceHalf),
        next.dy.clamp(_diceHalf, 15 - _diceHalf),
      );
    });
  }

  void _onDicePanEnd(DragEndDetails d, double u) {
    if (!_canDragDice) return;
    final v = d.velocity.pixelsPerSecond / u; // board units / sec
    if (v.distance >= _minFlickSpeed) {
      _g.roll();
    }
  }

  // ---------------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------------

  Widget _dlgBtn(BuildContext ctx, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(ctx).pop(value),
            child: Text(label, style: const TextStyle(fontSize: 18)),
          ),
        ),
      );

  Future<void> _pause() async {
    if (!mounted || _g.over) return;
    _g.paused = true;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Paused', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dlgBtn(ctx, 'Resume', 'r'),
              _dlgBtn(ctx, 'Restart', 's'),
              _dlgBtn(ctx, 'Main menu', 'm'),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;

    switch (result) {
      case 's':
        _releaseGame();
        setState(() => _startGame(null));
        break;
      case 'm':
        Navigator.of(context).pop();
        break;
      default:
        _g.paused = false;
    }
  }

  Future<void> _showOver() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Game over', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _g.ranks.length; i++)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: kSeatColors[_g.ranks[i]],
                    child: Text('${i + 1}', style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(
                    '${kSeatNames[_g.ranks[i]]} '
                    '(${_g.isBot(_g.ranks[i]) ? 'Bot' : 'Human'} '
                    '${_g.ranks[i] + 1})',
                  ),
                ),
              _dlgBtn(ctx, 'Play again', 's'),
              _dlgBtn(ctx, 'Main menu', 'm'),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;

    if (result == 's') {
      _releaseGame();
      setState(() => _startGame(null));
    } else if (result == 'm') {
      Navigator.of(context).pop();
    }
  }

  // ---------------------------------------------------------------------------
  // Input
  // ---------------------------------------------------------------------------

  void _tap(Offset localPosition, double u) {
    if (_g.isBot(_g.turn) || _g.moves.isEmpty) return;

    final targets = {for (final m in _g.moves) m.t};
    final point = localPosition / u;

    TP? best;
    var bestDist = 0.9;
    for (final item in TokenPainter.layout(_g)) {
      if (!targets.contains(item.t)) continue;
      final d = (item.o - point).distance;
      if (d < bestDist) {
        bestDist = d;
        best = item;
      }
    }
    if (best != null) _g.tapToken(best.t);
  }

  // ---------------------------------------------------------------------------
  // Widgets
  // ---------------------------------------------------------------------------

  Widget _round(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 62,
          height: 62,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFD66B), Color(0xFFF2A81D)],
            ),
            boxShadow: [
              BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 36),
        ),
      );

  Widget _label(int seat, double u) {
    final origin = kYard[seat];
    final isTop = seat == 1 || seat == 2;

    return ValueListenableBuilder<int>(
      valueListenable: _g.tick,
      builder: (_, __, ___) {
        final active = _g.turn == seat && !_g.over;
        final baseStyle = TextStyle(
          color: Colors.white.withOpacity(active ? 1 : .75),
          fontSize: u * .85,
          fontWeight: FontWeight.w900,
          decoration: active ? TextDecoration.underline : null,
          decorationColor: Colors.white,
        );

        final name = Text(
          '${_g.isBot(seat) ? 'Bot' : 'Human'} ${seat + 1}',
          style: baseStyle,
        );
        final pct = Text(
          '${_g.progress(seat).toStringAsFixed(1)}%',
          style: baseStyle.copyWith(
            decoration: TextDecoration.none,
            fontSize: u * .75,
          ),
        );

        Widget row(double y, Widget child) => Positioned(
              left: origin[0] * u,
              top: y * u,
              width: 6 * u,
              child: Center(
                child: isTop ? Transform.rotate(angle: pi, child: child) : child,
              ),
            );

        return Stack(
          children: [
            row(isTop ? origin[1] + .05 : origin[1] + 5.0, name),
            row(isTop ? origin[1] + 5.0 : origin[1] + .05, pct),
          ],
        );
      },
    );
  }

  /// Dice widget — draggable + flickable, spins on a diagonal 3-axis path.
  Widget _diceWidget(double u) {
    final size = _diceHalf * 2 * u;

    return Positioned(
      left: (_dicePos.dx - _diceHalf) * u,
      top: (_dicePos.dy - _diceHalf) * u,
      width: size,
      height: size,
      child: ValueListenableBuilder<int>(
        valueListenable: _g.tick,
        builder: (_, __, ___) {
          final canDrag = _canDragDice;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: canDrag ? (_) {} : null,
            onPanUpdate: canDrag ? (d) => _onDicePanUpdate(d, u) : null,
            onPanEnd: canDrag ? (d) => _onDicePanEnd(d, u) : null,
            child: AnimatedBuilder(
              animation: _diceCtl,
              builder: (_, __) {
                final a = _diceCtl.value;
                // Diagonal 3-axis tumble with mild perspective.
                final m = Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(a * 4 * pi)
                  ..rotateY(a * 6 * pi)
                  ..rotateZ(a * 3 * pi);
                return Transform(
                  alignment: Alignment.center,
                  transform: m,
                  child: CustomPaint(
                    painter: DicePainter(
                      _g.rolling ? (a * 6).floor() % 6 + 1 : _g.dice,
                      kSeatColors[_g.turn],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final u = width / 15;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pause();
      },
      child: Scaffold(
        backgroundColor: kWood,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(),

              // ----- Board -----
              SizedBox(
                width: width,
                height: width,
                child: Stack(
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        size: Size(width, width),
                        painter: BoardPainter(_g.s.on('stars')),
                      ),
                    ),

                    for (var s = 0; s < 4; s++)
                      if (_g.s.seats[s] != 0) _label(s, u),

                    RepaintBoundary(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) => _tap(d.localPosition, u),
                        child: CustomPaint(
                          size: Size(width, width),
                          painter: TokenPainter(_g, _pulse),
                        ),
                      ),
                    ),

                    // ----- Dice (draggable + flickable) -----
                    _diceWidget(u),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ----- Status text -----
              ValueListenableBuilder<int>(
                valueListenable: _g.tick,
                builder: (_, __, ___) {
                  final String text;
                  if (_g.over) {
                    text = 'Game over';
                  } else if (_g.msg.isNotEmpty) {
                    text = _g.msg;
                  } else if (_g.isBot(_g.turn)) {
                    text = '${kSeatNames[_g.turn]} (bot) is playing…';
                  } else if (_g.moves.isNotEmpty) {
                    text = '${kSeatNames[_g.turn]}: tap a coin to move';
                  } else if (_g.rolling) {
                    text = '${kSeatNames[_g.turn]}: rolling…';
                  } else {
                    text = '${kSeatNames[_g.turn]}: flick the dice to roll';
                  }
                  return Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color.lerp(kSeatColors[_g.turn], Colors.black, .35),
                    ),
                  );
                },
              ),

              const Spacer(),

              // ----- Bottom bar -----
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _round(Icons.arrow_back, _pause),
                    _round(Icons.settings, _pause),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}