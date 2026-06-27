import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SumGameApp());
}

class SumGameApp extends StatelessWidget {
  const SumGameApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sum 10',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0f0f1a),
      ),
      home: const MenuScreen(),
    );
  }
}

enum GameMode { survival, campaign, bouncy }

// ─── Menu ────────────────────────────────────────────────────────────────────
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('SUM 10',
                    style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 4)),
                const SizedBox(height: 6),
                const Text('Freeze numbers · Match pairs that sum to 10',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                    textAlign: TextAlign.center),
                const SizedBox(height: 40),
                _ModeBtn(
                  label: '⚔️  Survival',
                  desc: 'Score as long as you can',
                  c1: const Color(0xFF8e44ad),
                  c2: const Color(0xFFc0392b),
                  onTap: () => _go(context, GameMode.survival),
                ),
                const SizedBox(height: 14),
                _ModeBtn(
                  label: '🗺️  Campaign',
                  desc: 'Clear every cell to advance',
                  c1: const Color(0xFF2980b9),
                  c2: const Color(0xFF1abc9c),
                  onTap: () => _go(context, GameMode.campaign),
                ),
                const SizedBox(height: 14),
                _ModeBtn(
                  label: '🏀  Bouncy',
                  desc: 'Numbers bounce back 3 times',
                  c1: const Color(0xFF00b894),
                  c2: const Color(0xFF0984e3),
                  onTap: () => _go(context, GameMode.bouncy),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _go(BuildContext ctx, GameMode m) =>
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => GameScreen(mode: m)));
}

class _ModeBtn extends StatelessWidget {
  final String label, desc;
  final Color c1, c2;
  final VoidCallback onTap;
  const _ModeBtn({required this.label, required this.desc, required this.c1, required this.c2, required this.onTap});

  @override
  Widget build(BuildContext ctx) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 260,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [c1, c2]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: c2.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(children: [
            Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ]),
        ),
      );
}

// ─── Game constants ───────────────────────────────────────────────────────────
const int kCols = 5;
const int kRows = 5;
const int kTotal = kCols * kRows;
const int kMaxLives = 3;
const double kGap = 4;
const double kPad = 4;

// ─── Data classes ─────────────────────────────────────────────────────────────
class Mover {
  final int number;
  final List<int> path;
  double progress = 0;
  final int maxBounces;
  int bouncesLeft;
  bool forward = true;
  bool done = false;

  Mover({required this.number, required this.path, required this.maxBounces})
      : bouncesLeft = maxBounces;
}

class Particle {
  final int col, row;
  final double dx, dy;
  final Color color;
  double life;
  Particle({required this.col, required this.row, required this.dx, required this.dy, required this.color, required this.life});
}

// ─── Game Screen ──────────────────────────────────────────────────────────────
class GameScreen extends StatefulWidget {
  final GameMode mode;
  const GameScreen({super.key, required this.mode});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late List<int?> grid;
  final Map<int, int> frozen = {};
  int score = 0, lives = kMaxLives, level = 1, stage = 1, clearedCount = 0, timerSeconds = 0;
  bool running = false, stageClearOverlay = false;
  double flashOpacity = 0;

  final List<Mover> movers = [];
  final List<Particle> particles = [];
  final Random rng = Random();

  Timer? spawnTimer, secondTimer;
  late AnimationController _ticker;

  double speedMult = 1.0;
  int tickInterval = 30;
  bool unlimitedLives = false;

  static const speedLabels = ['Crawl','Slow','Easy','Normal','Steady','Brisk','Fast','Rapid','Blazing','Insane','MAX'];
  static const speedMs = [1800,1600,1400,1200,1050,900,750,550,360,220,120];
  static const spawnMs = [3200,2900,2600,2300,2050,1800,1500,1150,800,500,280];

  int get tick => (widget.mode == GameMode.survival ? timerSeconds ~/ tickInterval : level - 1).clamp(0, speedMs.length - 1);
  int get effSpeed => (speedMs[tick] / speedMult).round().clamp(50, 99999);
  int get effSpawn => (spawnMs[tick] / speedMult).round().clamp(100, 99999);
  String get speedLabel => speedLabels[tick];

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(_frame)
      ..repeat();
    _start();
  }

  void _frame() {
    if (!mounted || !running) return;
    for (final p in particles) p.life -= 0.04;
    particles.removeWhere((p) => p.life <= 0);
    setState(() {});
  }

  void _start() {
    grid = List.generate(kTotal, (_) => rng.nextInt(11));
    frozen.clear(); movers.clear(); particles.clear();
    score = 0; lives = kMaxLives; level = 1;
    stage = 1; clearedCount = 0; timerSeconds = 0;
    running = true; stageClearOverlay = false;
    _startTimers();
  }

  void _startTimers() {
    spawnTimer?.cancel(); secondTimer?.cancel();
    secondTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !running) return;
      setState(() => timerSeconds++);
    });
    _scheduleSpawn();
  }

  void _scheduleSpawn() {
    spawnTimer?.cancel();
    spawnTimer = Timer(Duration(milliseconds: effSpawn), () {
      if (!mounted || !running) return;
      _spawnMover();
      _scheduleSpawn();
    });
  }

  void _spawnMover() {
    final num = rng.nextInt(11);
    final edge = rng.nextInt(4);
    final List<int> path;
    if (edge == 0) {
      final r = rng.nextInt(kRows);
      path = List.generate(kCols, (c) => r * kCols + c);
    } else if (edge == 1) {
      final r = rng.nextInt(kRows);
      path = List.generate(kCols, (c) => r * kCols + (kCols - 1 - c));
    } else if (edge == 2) {
      final c = rng.nextInt(kCols);
      path = List.generate(kRows, (r) => r * kCols + c);
    } else {
      final c = rng.nextInt(kCols);
      path = List.generate(kRows, (r) => (kRows - 1 - r) * kCols + c);
    }

    final comp = 10 - num;
    if (!path.any((i) => grid[i] == comp)) {
      final cands = path.where((i) => !frozen.containsKey(i) && grid[i] != null).toList();
      if (cands.isNotEmpty) grid[cands[rng.nextInt(cands.length)]] = comp;
    }

    final m = Mover(number: num, path: path, maxBounces: widget.mode == GameMode.bouncy ? 3 : 0);
    setState(() => movers.add(m));
    _animateMover(m);
  }

  void _animateMover(Mover mover) {
    final total = effSpeed * mover.path.length;
    final start = DateTime.now();
    Timer.periodic(const Duration(milliseconds: 16), (t) {
      if (!mounted || mover.done) { t.cancel(); return; }
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      final raw = (elapsed / total).clamp(0.0, 1.0);
      mover.progress = mover.forward ? raw : (1.0 - raw);

      final fp = mover.progress * (mover.path.length - 1);
      final ci = fp.round().clamp(0, mover.path.length - 1);
      final gIdx = mover.path[ci];

      if (frozen.containsKey(gIdx)) {
        mover.done = true; t.cancel();
        final sum = mover.number + frozen[gIdx]!;
        setState(() => movers.remove(mover));
        if (sum == 10) _match(gIdx); else _miss(gIdx);
        return;
      }

      if (raw >= 1.0) {
        if (mover.bouncesLeft > 0) {
          mover.bouncesLeft--;
          mover.forward = !mover.forward;
          t.cancel();
          _animateMover(mover);
        } else {
          mover.done = true; t.cancel();
          setState(() => movers.remove(mover));
        }
      }
    });
  }

  void _match(int idx) {
    setState(() {
      score++; frozen.remove(idx); _burst(idx); flashOpacity = 0.3;
      if (widget.mode == GameMode.campaign) {
        grid[idx] = null; clearedCount++;
        if (clearedCount >= kTotal) { _stageClear(); return; }
      } else {
        grid[idx] = rng.nextInt(11);
        final next = score ~/ 15 + 1;
        if (next > level) level = next;
      }
    });
    Future.delayed(const Duration(milliseconds: 200), () { if (mounted) setState(() => flashOpacity = 0); });
  }

  void _miss(int idx) {
    setState(() { frozen.remove(idx); if (!unlimitedLives) lives--; });
    if (!unlimitedLives && lives <= 0) _gameOver();
  }

  void _stageClear() {
    running = false; spawnTimer?.cancel(); secondTimer?.cancel();
    setState(() => stageClearOverlay = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        stage++; level = stage; clearedCount = 0; timerSeconds = 0;
        movers.clear();
        grid = List.generate(kTotal, (_) => rng.nextInt(11));
        frozen.clear(); stageClearOverlay = false; running = true;
      });
      _startTimers();
    });
  }

  void _gameOver() {
    running = false; spawnTimer?.cancel(); secondTimer?.cancel();
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(widget.mode == GameMode.campaign ? 'Stage $stage' : 'Game Over',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$score', style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: Color(0xFFf0c040))),
          Text(widget.mode == GameMode.campaign ? 'cleared · ${_fmt(timerSeconds)}' : 'points · survived ${_fmt(timerSeconds)}',
              style: const TextStyle(color: Colors.white54)),
        ]),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); setState(_start); },
              child: const Text('Play Again', style: TextStyle(color: Color(0xFF8e44ad)))),
          TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); },
              child: const Text('Menu', style: TextStyle(color: Colors.white54))),
        ],
      ),
    );
  }

  void _burst(int idx) {
    final col = idx % kCols, row = idx ~/ kCols;
    final cols = [Colors.green, Colors.yellow, Colors.blue, Colors.red, Colors.purple, Colors.pink];
    for (int i = 0; i < 12; i++) {
      final a = (i / 12) * 2 * pi + rng.nextDouble() * 0.4;
      final d = 20.0 + rng.nextDouble() * 40;
      particles.add(Particle(col: col, row: row, dx: cos(a) * d, dy: sin(a) * d, color: cols[i % cols.length], life: 1.0));
    }
  }

  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  void _tap(int idx) {
    if (!running || grid[idx] == null) return;
    setState(() {
      if (frozen.containsKey(idx)) frozen.remove(idx);
      else frozen[idx] = grid[idx]!;
    });
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (ctx, ss) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Speed multiplier', style: TextStyle(color: Colors.white70)),
            Text('${speedMult.toStringAsFixed(1)}×', style: const TextStyle(color: Color(0xFFf0c040), fontWeight: FontWeight.w800)),
          ]),
          Slider(value: speedMult, min: 0.3, max: 7.5, divisions: 24, activeColor: const Color(0xFF8e44ad),
              onChanged: (v) { ss(() => speedMult = v); setState(() => speedMult = v); }),
          if (widget.mode == GameMode.survival) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Speed-up every', style: TextStyle(color: Colors.white70)),
              Text('${tickInterval}s', style: const TextStyle(color: Color(0xFFf0c040), fontWeight: FontWeight.w800)),
            ]),
            Slider(value: tickInterval.toDouble(), min: 3, max: 60, divisions: 19, activeColor: const Color(0xFF2980b9),
                onChanged: (v) { ss(() => tickInterval = v.round()); setState(() => tickInterval = v.round()); }),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Unlimited lives', style: TextStyle(color: Colors.white70)),
            value: unlimitedLives, activeColor: const Color(0xFF00b894),
            onChanged: (v) { ss(() => unlimitedLives = v); setState(() => unlimitedLives = v); }),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white30), foregroundColor: Colors.white54),
                onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
                child: const Text('Back to Menu'),
              )),
        ]),
      )),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    spawnTimer?.cancel();
    secondTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        if (flashOpacity > 0)
          Positioned.fill(child: IgnorePointer(
              child: Container(color: Colors.green.withOpacity(flashOpacity)))),

        SafeArea(child: Column(children: [
          // HUD
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('SCORE', style: TextStyle(color: Colors.white54, fontSize: 10)),
                Text('$score', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFFf0c040))),
              ]),
              Column(children: [
                Text(List.generate(kMaxLives, (i) => i < lives ? '❤️' : '🖤').join(), style: const TextStyle(fontSize: 14)),
                if (widget.mode == GameMode.campaign)
                  Text('STAGE $stage', style: const TextStyle(color: Color(0xFF7ecfff), fontSize: 10)),
                Text(_fmt(timerSeconds), style: const TextStyle(color: Color(0xFFf0c040), fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('SPEED', style: TextStyle(color: Colors.white54, fontSize: 10)),
                Text(speedLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                if (widget.mode == GameMode.campaign)
                  Text('${kTotal - clearedCount} left', style: const TextStyle(color: Color(0xFF7ecfff), fontSize: 10)),
              ]),
            ]),
          ),

          // Grid — uses Expanded + LayoutBuilder so it fills remaining space
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: LayoutBuilder(builder: (_, box) {
                final size = min(box.maxWidth, box.maxHeight);
                final cellSize = (size - kPad * 2 - kGap * (kCols - 1)) / kCols;

                return Center(
                  child: SizedBox(
                    width: size, height: size,
                    child: Stack(children: [
                      // Cell grid
                      Container(
                        width: size, height: size,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1a1a2e),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.all(kPad),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(kRows, (row) => Padding(
                            padding: EdgeInsets.only(top: row == 0 ? 0 : kGap),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(kCols, (col) {
                                final idx = row * kCols + col;
                                final val = grid[idx];
                                final isF = frozen.containsKey(idx);
                                return Padding(
                                  padding: EdgeInsets.only(left: col == 0 ? 0 : kGap),
                                  child: GestureDetector(
                                    onTap: () => _tap(idx),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      width: cellSize, height: cellSize,
                                      decoration: BoxDecoration(
                                        color: val == null
                                            ? const Color(0xFF0a0a18)
                                            : isF ? const Color(0xFF1e3a5f) : const Color(0xFF12122a),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: isF
                                            ? [const BoxShadow(color: Color(0x664aaff0), blurRadius: 10, spreadRadius: 1)]
                                            : null,
                                      ),
                                      child: Center(child: Text(
                                        val != null ? '$val' : '',
                                        style: TextStyle(
                                          fontSize: cellSize * 0.38,
                                          fontWeight: FontWeight.w900,
                                          color: isF ? const Color(0xFF7ecfff) : Colors.white,
                                        ),
                                      )),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          )),
                        ),
                      ),

                      // Movers
                      ...movers.map((m) {
                        final t = m.progress.clamp(0.0, 1.0);
                        final fp = t * (m.path.length - 1);
                        final ci = fp.floor().clamp(0, m.path.length - 2);
                        final frac = fp - ci;
                        final ia = m.path[ci], ib = m.path[ci + 1];
                        final lx = kPad + ((ia % kCols) + ((ib % kCols) - (ia % kCols)) * frac) * (cellSize + kGap);
                        final ly = kPad + ((ia ~/ kCols) + ((ib ~/ kCols) - (ia ~/ kCols)) * frac) * (cellSize + kGap);
                        final bi = m.maxBounces - m.bouncesLeft;
                        final grads = [
                          [const Color(0xFF8e44ad), const Color(0xFFc0392b)],
                          [const Color(0xFF00b894), const Color(0xFF0984e3)],
                          [const Color(0xFFf0c040), const Color(0xFFe17055)],
                          [const Color(0xFFfd79a8), const Color(0xFF6c5ce7)],
                        ];
                        final gc = grads[bi % grads.length];
                        return Positioned(
                          left: lx, top: ly, width: cellSize, height: cellSize,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: gc, begin: Alignment.topLeft, end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [BoxShadow(color: gc[1].withOpacity(0.55), blurRadius: 10)],
                            ),
                            child: Center(child: Text('${m.number}',
                                style: TextStyle(fontSize: cellSize * 0.38, fontWeight: FontWeight.w900, color: Colors.white))),
                          ),
                        );
                      }),

                      // Particles
                      ...particles.map((p) {
                        final ox = kPad + p.col * (cellSize + kGap) + cellSize / 2;
                        final oy = kPad + p.row * (cellSize + kGap) + cellSize / 2;
                        return Positioned(
                          left: ox + p.dx * (1 - p.life) - 5,
                          top: oy + p.dy * (1 - p.life) - 5,
                          child: Opacity(
                            opacity: p.life.clamp(0.0, 1.0),
                            child: Container(width: 10, height: 10,
                                decoration: BoxDecoration(color: p.color, shape: BoxShape.circle)),
                          ),
                        );
                      }),
                    ]),
                  ),
                );
              }),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text('Tap to freeze · Mover + frozen = 10 → score!',
                style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11)),
          ),
        ])),

        // Stage clear overlay
        if (stageClearOverlay)
          Positioned.fill(child: Container(
            color: Colors.black.withOpacity(0.75),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Stage Clear! 🎉', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFFf0c040))),
              Text('Stage $stage', style: const TextStyle(fontSize: 26, color: Colors.white)),
              Text('Cleared in ${_fmt(timerSeconds)}', style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 12),
              const Text('Get ready…', style: TextStyle(color: Colors.white54)),
            ]),
          )),

        // Back
        Positioned(top: 50, left: 12,
            child: GestureDetector(onTap: () => Navigator.pop(context),
                child: Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.arrow_back, color: Colors.white54, size: 20)))),

        // Settings
        Positioned(top: 50, right: 12,
            child: GestureDetector(onTap: _openSettings,
                child: Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.settings, color: Colors.white54, size: 20)))),
      ]),
    );
  }
}
