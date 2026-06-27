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

// ── Game Mode ──────────────────────────────────────────────────────────────────
enum GameMode { survival, campaign, bouncy }

// ── Menu Screen ───────────────────────────────────────────────────────────────
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('SUM 10',
                style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 4)),
            const SizedBox(height: 8),
            const Text('Freeze numbers · Match pairs that sum to 10',
                style: TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 40),
            _ModeButton(
              label: '⚔️  Survival',
              desc: 'Score as long as you can',
              color1: const Color(0xFF8e44ad),
              color2: const Color(0xFFc0392b),
              onTap: () => _start(context, GameMode.survival),
            ),
            const SizedBox(height: 14),
            _ModeButton(
              label: '🗺️  Campaign',
              desc: 'Clear every cell to advance',
              color1: const Color(0xFF2980b9),
              color2: const Color(0xFF1abc9c),
              onTap: () => _start(context, GameMode.campaign),
            ),
            const SizedBox(height: 14),
            _ModeButton(
              label: '🏀  Bouncy',
              desc: 'Numbers bounce back 3 times',
              color1: const Color(0xFF00b894),
              color2: const Color(0xFF0984e3),
              onTap: () => _start(context, GameMode.bouncy),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  void _start(BuildContext context, GameMode mode) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => GameScreen(mode: mode)));
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final String desc;
  final Color color1;
  final Color color2;
  final VoidCallback onTap;

  const _ModeButton(
      {required this.label,
      required this.desc,
      required this.color1,
      required this.color2,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color1, color2]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: color2.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(desc,
                style:
                    const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

// ── Game Screen ───────────────────────────────────────────────────────────────
const int kCols = 5;
const int kRows = 5;
const int kTotal = kCols * kRows;
const int kMaxLives = 3;

class Mover {
  final int number;
  final List<int> path;
  double progress;
  final int maxBounces;
  int bouncesLeft;
  bool forward;
  bool collided;

  Mover({required this.number, required this.path, required this.maxBounces})
      : progress = 0,
        bouncesLeft = maxBounces,
        forward = true,
        collided = false;
}

class _Particle {
  final int col;
  final int row;
  final double dx;
  final double dy;
  final Color color;
  double life;

  _Particle(
      {required this.col,
      required this.row,
      required this.dx,
      required this.dy,
      required this.color,
      required this.life});
}

class GameScreen extends StatefulWidget {
  final GameMode mode;
  const GameScreen({super.key, required this.mode});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  late List<int?> grid;
  late Map<int, int> frozen;
  int score = 0;
  int lives = kMaxLives;
  int level = 1;
  int stage = 1;
  int clearedCount = 0;
  int timerSeconds = 0;
  bool gameRunning = false;
  String speedLabel = 'Crawl';
  bool _showStageClear = false;
  double _flashOpacity = 0;

  // Dev / settings
  double devSpeedMultiplier = 1.0;
  int speedTickInterval = 30;
  bool unlimitedLives = false;

  final List<Mover> movers = [];
  final List<_Particle> _particles = [];
  final Random _rng = Random();

  Timer? _spawnTimer;
  Timer? _secondTimer;
  late AnimationController _animCtrl;

  static const List<String> kSpeedLabels = [
    'Crawl', 'Slow', 'Easy', 'Normal', 'Steady',
    'Brisk', 'Fast', 'Rapid', 'Blazing', 'Insane', 'MAX'
  ];
  static const List<int> kSpeedMs = [
    1800, 1600, 1400, 1200, 1050, 900, 750, 550, 360, 220, 120
  ];
  static const List<int> kSpawnMs = [
    3200, 2900, 2600, 2300, 2050, 1800, 1500, 1150, 800, 500, 280
  ];

  int get _tick {
    final t = widget.mode == GameMode.survival
        ? timerSeconds ~/ speedTickInterval
        : level - 1;
    return t.clamp(0, kSpeedMs.length - 1);
  }

  int get _effectiveSpeedMs => (kSpeedMs[_tick] / devSpeedMultiplier).round();
  int get _effectiveSpawnMs => (kSpawnMs[_tick] / devSpeedMultiplier).round();

  @override
  void initState() {
    super.initState();
    _animCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 16))
          ..addListener(_onTick)
          ..repeat();
    _startGame();
  }

  void _onTick() {
    if (!mounted || !gameRunning) return;
    for (final p in _particles) { p.life -= 0.04; }
    _particles.removeWhere((p) => p.life <= 0);
    setState(() {});
  }

  void _startGame() {
    grid = List.generate(kTotal, (_) => _rng.nextInt(11));
    frozen = {};
    score = 0; lives = kMaxLives; level = 1;
    stage = 1; clearedCount = 0; timerSeconds = 0;
    movers.clear(); _particles.clear();
    gameRunning = true;
    _showStageClear = false;
    _startTimers();
  }

  void _startTimers() {
    _spawnTimer?.cancel();
    _secondTimer?.cancel();

    _secondTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !gameRunning) return;
      setState(() {
        timerSeconds++;
        speedLabel = kSpeedLabels[_tick];
      });
    });

    _scheduleNext();
  }

  void _scheduleNext() {
    _spawnTimer?.cancel();
    _spawnTimer = Timer(Duration(milliseconds: _effectiveSpawnMs), () {
      if (!mounted || !gameRunning) return;
      _launchMover();
      _scheduleNext();
    });
  }

  void _launchMover() {
    final num = _rng.nextInt(11);
    final edge = _rng.nextInt(4);
    List<int> path;

    if (edge == 0) {
      final row = _rng.nextInt(kRows);
      path = List.generate(kCols, (c) => row * kCols + c);
    } else if (edge == 1) {
      final row = _rng.nextInt(kRows);
      path = List.generate(kCols, (c) => row * kCols + (kCols - 1 - c));
    } else if (edge == 2) {
      final col = _rng.nextInt(kCols);
      path = List.generate(kRows, (r) => r * kCols + col);
    } else {
      final col = _rng.nextInt(kCols);
      path = List.generate(kRows, (r) => (kRows - 1 - r) * kCols + col);
    }

    final complement = 10 - num;
    final alreadyPresent = path.any((i) => grid[i] == complement);
    if (!alreadyPresent) {
      final candidates =
          path.where((i) => !frozen.containsKey(i) && grid[i] != null).toList();
      if (candidates.isNotEmpty) {
        grid[candidates[_rng.nextInt(candidates.length)]] = complement;
      }
    }

    final mover = Mover(
      number: num,
      path: path,
      maxBounces: widget.mode == GameMode.bouncy ? 3 : 0,
    );
    setState(() => movers.add(mover));
    _animateMover(mover);
  }

  void _animateMover(Mover mover) {
    final speedPerCell = _effectiveSpeedMs;
    final totalMs = speedPerCell * mover.path.length;
    final start = DateTime.now();

    Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted || !gameRunning || mover.collided) { timer.cancel(); return; }

      final elapsed = DateTime.now().difference(start).inMilliseconds;
      final raw = (elapsed / totalMs).clamp(0.0, 1.0);
      mover.progress = mover.forward ? raw : (1.0 - raw);

      // Collision detection
      final fp = mover.progress * (mover.path.length - 1);
      final ci = fp.round().clamp(0, mover.path.length - 1);
      final gridIdx = mover.path[ci];

      if (frozen.containsKey(gridIdx)) {
        final sum = mover.number + frozen[gridIdx]!;
        mover.collided = true;
        timer.cancel();
        setState(() => movers.remove(mover));
        if (sum == 10) _handleMatch(gridIdx);
        else _handleMiss(gridIdx);
        return;
      }

      if (raw >= 1.0) {
        if (mover.bouncesLeft > 0) {
          mover.bouncesLeft--;
          mover.forward = !mover.forward;
          timer.cancel();
          _animateMover(mover);
        } else {
          timer.cancel();
          setState(() => movers.remove(mover));
        }
      }
    });
  }

  void _handleMatch(int idx) {
    setState(() {
      score++;
      frozen.remove(idx);
      _spawnParticles(idx);
      _flashOpacity = 0.3;

      if (widget.mode == GameMode.campaign) {
        grid[idx] = null;
        clearedCount++;
        if (clearedCount >= kTotal) { _stageClear(); return; }
      } else {
        grid[idx] = _rng.nextInt(11);
        final nextLevel = score ~/ 15 + 1;
        if (nextLevel > level) level = nextLevel;
      }
    });

    Future.delayed(const Duration(milliseconds: 200),
        () { if (mounted) setState(() => _flashOpacity = 0); });
  }

  void _handleMiss(int idx) {
    setState(() {
      frozen.remove(idx);
      if (!unlimitedLives) lives--;
    });
    if (!unlimitedLives && lives <= 0) _endGame();
  }

  void _stageClear() {
    gameRunning = false;
    _spawnTimer?.cancel();
    _secondTimer?.cancel();
    setState(() => _showStageClear = true);

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        stage++; level = stage; clearedCount = 0;
        movers.clear();
        grid = List.generate(kTotal, (_) => _rng.nextInt(11));
        frozen = {}; _showStageClear = false;
        gameRunning = true; timerSeconds = 0;
      });
      _startTimers();
    });
  }

  void _endGame() {
    gameRunning = false;
    _spawnTimer?.cancel();
    _secondTimer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text(
          widget.mode == GameMode.campaign ? 'Stage $stage' : 'Game Over',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
        ),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$score',
              style: const TextStyle(
                  fontSize: 56, fontWeight: FontWeight.w900, color: Color(0xFFf0c040))),
          Text(
            widget.mode == GameMode.campaign
                ? 'cleared · ${_fmt(timerSeconds)}'
                : 'points · survived ${_fmt(timerSeconds)}',
            style: const TextStyle(color: Colors.white54),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); setState(() => _startGame()); },
            child: const Text('Play Again', style: TextStyle(color: Color(0xFF8e44ad))),
          ),
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text('Menu', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  void _spawnParticles(int idx) {
    final col = idx % kCols;
    final row = idx ~/ kCols;
    final colors = [Colors.green, Colors.yellow, Colors.blue, Colors.red, Colors.purple, Colors.pink];
    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * pi + _rng.nextDouble() * 0.4;
      final dist = 20.0 + _rng.nextDouble() * 40;
      _particles.add(_Particle(
        col: col, row: row,
        dx: cos(angle) * dist, dy: sin(angle) * dist,
        color: colors[i % colors.length], life: 1.0,
      ));
    }
  }

  String _fmt(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 24),

            // Speed multiplier
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Speed multiplier', style: TextStyle(color: Colors.white70)),
              Text('${devSpeedMultiplier.toStringAsFixed(1)}×',
                  style: const TextStyle(color: Color(0xFFf0c040), fontWeight: FontWeight.w800)),
            ]),
            Slider(
              value: devSpeedMultiplier,
              min: 0.3, max: 7.5,
              divisions: 24,
              activeColor: const Color(0xFF8e44ad),
              onChanged: (v) {
                setSheet(() => devSpeedMultiplier = v);
                setState(() => devSpeedMultiplier = v);
              },
            ),

            const SizedBox(height: 12),

            // Speed tick interval (survival only)
            if (widget.mode == GameMode.survival) ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Speed-up every', style: TextStyle(color: Colors.white70)),
                Text('${speedTickInterval}s',
                    style: const TextStyle(color: Color(0xFFf0c040), fontWeight: FontWeight.w800)),
              ]),
              Slider(
                value: speedTickInterval.toDouble(),
                min: 3, max: 60,
                divisions: 19,
                activeColor: const Color(0xFF2980b9),
                onChanged: (v) {
                  setSheet(() => speedTickInterval = v.round());
                  setState(() => speedTickInterval = v.round());
                },
              ),
              const SizedBox(height: 12),
            ],

            // Unlimited lives
            SwitchListTile(
              title: const Text('Unlimited lives', style: TextStyle(color: Colors.white70)),
              value: unlimitedLives,
              activeColor: const Color(0xFF00b894),
              onChanged: (v) {
                setSheet(() => unlimitedLives = v);
                setState(() => unlimitedLives = v);
              },
            ),

            const SizedBox(height: 12),

            // Back to menu
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white30),
                  foregroundColor: Colors.white54,
                ),
                onPressed: () {
                  Navigator.pop(ctx); // close sheet
                  Navigator.pop(context); // back to menu
                },
                child: const Text('Back to Menu'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _toggle(int idx) {
    if (!gameRunning || grid[idx] == null) return;
    setState(() {
      if (frozen.containsKey(idx)) frozen.remove(idx);
      else frozen[idx] = grid[idx]!;
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _spawnTimer?.cancel();
    _secondTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final gridSize = size.width * 0.92;
    final cellSize = (gridSize - 8 - 4 * 4) / kCols;

    return Scaffold(
      body: Stack(children: [
        if (_flashOpacity > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(color: Colors.green.withOpacity(_flashOpacity)),
            ),
          ),

        SafeArea(
          child: SingleChildScrollView(
            child: Column(children: [
            // HUD
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('SCORE', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    Text('$score',
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFf0c040))),
                  ]),
                  Column(children: [
                    Text(
                      List.generate(kMaxLives, (i) => i < lives ? '❤️' : '🖤').join(),
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (widget.mode == GameMode.campaign)
                      Text('STAGE $stage',
                          style: const TextStyle(color: Color(0xFF7ecfff), fontSize: 11)),
                    Text(_fmt(timerSeconds),
                        style: const TextStyle(
                            color: Color(0xFFf0c040), fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('SPEED', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    Text(speedLabel,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                    if (widget.mode == GameMode.campaign)
                      Text('${kTotal - clearedCount} left',
                          style: const TextStyle(color: Color(0xFF7ecfff), fontSize: 11)),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Grid + movers
            Center(
              child: SizedBox(
                width: gridSize,
                height: gridSize,
                child: Stack(children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1a1a2e),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: kCols,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                      ),
                      itemCount: kTotal,
                      itemBuilder: (_, idx) {
                        final val = grid[idx];
                        final isFrozen = frozen.containsKey(idx);
                        return GestureDetector(
                          onTap: () => _toggle(idx),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: val == null
                                  ? const Color(0xFF0d0d1a)
                                  : isFrozen
                                      ? const Color(0xFF1e3a5f)
                                      : const Color(0xFF12122a),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: isFrozen
                                  ? [const BoxShadow(
                                      color: Color(0x664aaff0),
                                      blurRadius: 12, spreadRadius: 1)]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                val != null ? '$val' : '',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: isFrozen
                                      ? const Color(0xFF7ecfff)
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Movers
                  ...movers.map((mover) {
                    final t = mover.progress.clamp(0.0, 1.0);
                    final fp = t * (mover.path.length - 1);
                    final ci = fp.floor().clamp(0, mover.path.length - 2);
                    final frac = fp - ci;
                    final idxA = mover.path[ci];
                    final idxB = mover.path[ci + 1];
                    final lx = ((idxA % kCols) + ((idxB % kCols) - (idxA % kCols)) * frac) *
                            (cellSize + 4) + 4;
                    final ly = ((idxA ~/ kCols) + ((idxB ~/ kCols) - (idxA ~/ kCols)) * frac) *
                            (cellSize + 4) + 4;

                    final bIdx = mover.maxBounces - mover.bouncesLeft;
                    final gradients = [
                      [const Color(0xFF8e44ad), const Color(0xFFc0392b)],
                      [const Color(0xFF00b894), const Color(0xFF0984e3)],
                      [const Color(0xFFf0c040), const Color(0xFFe17055)],
                      [const Color(0xFFfd79a8), const Color(0xFF6c5ce7)],
                    ];
                    final gc = gradients[bIdx % gradients.length];

                    return Positioned(
                      left: lx, top: ly,
                      width: cellSize, height: cellSize,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: gc,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(color: gc[1].withOpacity(0.5), blurRadius: 10)
                          ],
                        ),
                        child: Center(
                          child: Text('${mover.number}',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                        ),
                      ),
                    );
                  }),

                  // Particles
                  ..._particles.map((p) {
                    final lx = (p.col * (cellSize + 4) + 4 + cellSize / 2) +
                        p.dx * (1 - p.life);
                    final ly = (p.row * (cellSize + 4) + 4 + cellSize / 2) +
                        p.dy * (1 - p.life);
                    return Positioned(
                      left: lx - 5, top: ly - 5,
                      child: Opacity(
                        opacity: p.life.clamp(0.0, 1.0),
                        child: Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                              color: p.color, shape: BoxShape.circle),
                        ),
                      ),
                    );
                  }),
                ]),
              ),
            ),

            const SizedBox(height: 12),
            const Text('Tap to freeze · Mover hits → sum 10 = score!',
                style: TextStyle(color: Color(0xFF444466), fontSize: 12)),
          ]),
          ),
        ),

        // Stage clear overlay
        if (_showStageClear)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.75),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Stage Clear!',
                    style: TextStyle(
                        fontSize: 40, fontWeight: FontWeight.w900, color: Color(0xFFf0c040))),
                Text('Stage $stage',
                    style: const TextStyle(fontSize: 28, color: Colors.white)),
                Text('Cleared in ${_fmt(timerSeconds)}',
                    style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 12),
                const Text('Get ready…', style: TextStyle(color: Colors.white54)),
              ]),
            ),
          ),

        // Back button
        Positioned(
          top: 50, left: 12,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white10, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.arrow_back, color: Colors.white54, size: 20),
            ),
          ),
        ),

        // Settings button
        Positioned(
          top: 50, right: 12,
          child: GestureDetector(
            onTap: _openSettings,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white10, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.settings, color: Colors.white54, size: 20),
            ),
          ),
        ),
      ]),
    );
  }
}
