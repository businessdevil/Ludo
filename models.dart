import 'dart:ui';

// ---------------------------------------------------------------------------
// Palette — hex values match the Kotlin reference (LudoView.col / woodLight)
// ---------------------------------------------------------------------------

const kWood = Color(0xFFE9CFA0);
const kGold = Color(0xFFF7C948);

/// Seat order: [green, red, blue, yellow].
/// Hex values taken from the Kotlin `col` array (0xFF59B254, 0xFFE76F51,
/// 0xFF3A73D1, 0xFFF4C03D) and re-ordered to the Dart seat semantics.
const kSeatColors = [
  Color(0xFF59B254), // 0 — green  (Kotlin col[3])
  Color(0xFFE76F51), // 1 — red    (Kotlin col[0], orange-red)
  Color(0xFF3A73D1), // 2 — blue   (Kotlin col[1])
  Color(0xFFF4C03D), // 3 — yellow (Kotlin col[2])
];

const kSeatNames = ['Green', 'Red', 'Blue', 'Yellow'];

// ---------------------------------------------------------------------------
// Board geometry — unchanged, matches the Dart track/painter contract
// ---------------------------------------------------------------------------

const kStart = [0, 13, 26, 39];
const kYard = [[0, 9], [0, 0], [9, 0], [9, 9]];

final List<List<int>> kTrack = _buildTrack();

final List<List<List<int>>> kLanes = [
  [for (var r = 13; r >= 9; r--) [7, r]],
  [for (var c = 1; c <= 5; c++) [c, 7]],
  [for (var r = 1; r <= 5; r++) [7, r]],
  [for (var c = 13; c >= 9; c--) [c, 7]],
];

List<List<int>> _buildTrack() {
  final t = <List<int>>[];
  void a(int c, int r) => t.add([c, r]);
  for (var r = 13; r >= 9; r--) a(6, r);
  for (var c = 5; c >= 0; c--) a(c, 8);
  a(0, 7); a(0, 6);
  for (var c = 1; c <= 5; c++) a(c, 6);
  for (var r = 5; r >= 0; r--) a(6, r);
  a(7, 0); a(8, 0);
  for (var r = 1; r <= 5; r++) a(8, r);
  for (var c = 9; c <= 14; c++) a(c, 6);
  a(14, 7); a(14, 8);
  for (var c = 13; c >= 9; c--) a(c, 8);
  for (var r = 9; r <= 14; r++) a(8, r);
  a(7, 14); a(6, 14);
  return t;
}

// ---------------------------------------------------------------------------
// Rule catalog
// ---------------------------------------------------------------------------

const kRuleLabels = <String, String>{
  'sixExtra': '6 also gives another turn',
  'sixOut': '6 also brings a coin out',
  'stars': 'Show safe cells (stars)',
  'threeOnesCut': '3 consecutive rolls of 1 cuts one own coin',
  'skipThreeOnes': 'Skip a turn on 3 consecutive rolls of 1',
  'threeSixOut': '3 consecutive rolls of 6 brings a coin out',
  'tripleSix': '3 consecutive 6s forfeits the turn',
  'cutExtra': 'Gains another turn on cutting a coin',
  'homeExtra': 'Gains another turn on reaching home',
  'cutToEnter': 'Must cut a coin to enter home lane',
  'mustCut': "Must cut the coin if it's cuttable",
  'mustOutOnOne': 'Must bring a coin out on 1',
  'barrier': '2 coins of same colour form a barrier',
};

const _defaultOn = {
  'sixExtra',
  'stars',
  'threeOnesCut',
  'threeSixOut',
  'tripleSix',
  'cutExtra',
  'homeExtra',
};

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------

class Setup {
  /// Per-seat player type: 0 = none, 1 = human, 2 = bot.
  List<int> seats = [1, 0, 1, 0];

  /// Coins per player (1..4).
  int coins = 2;

  /// AI difficulty: 1 = easy, 2 = medium, 3 = hard.
  int level = 3;

  /// Value required to bring a coin out of the yard (1 or 6).
  /// Corresponds to Kotlin's `startSix` (startSix == true ⇒ 6, else 1).
  int startAt = 1;

  /// Coin animation speed (0.0..1.0).
  double speed = 0.8;

  /// Rule toggles — every key in [kRuleLabels] gets a default from [_defaultOn].
  Map<String, bool> f = {
    for (final k in kRuleLabels.keys) k: _defaultOn.contains(k),
  };

  Setup();

  bool on(String k) => f[k] ?? false;

  Map<String, dynamic> toJson() => {
        'seats': seats,
        'coins': coins,
        'level': level,
        'startAt': startAt,
        'speed': speed,
        'f': f,
      };

  Setup.fromJson(Map j) {
    seats = List<int>.from(j['seats']);
    coins = j['coins'];
    level = j['level'];
    startAt = j['startAt'];
    speed = (j['speed'] as num).toDouble();
    final m = Map<String, dynamic>.from(j['f']);
    for (final k in f.keys) {
      f[k] = m[k] == true;
    }
  }
}