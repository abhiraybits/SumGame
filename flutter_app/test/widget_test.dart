import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sum_game/main.dart';

// Helpers ─────────────────────────────────────────────────────────────────────

/// Pump the app and settle all animations / timers in one call.
Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const SumGameApp());
  await tester.pumpAndSettle();
}

/// Navigate from the menu to a [GameScreen] for [mode].
Future<void> goToGame(WidgetTester tester, String buttonLabel) async {
  await pumpApp(tester);
  await tester.tap(find.text(buttonLabel));
  await tester.pumpAndSettle();
}

// ═════════════════════════════════════════════════════════════════════════════
// 1. Menu screen
// ═════════════════════════════════════════════════════════════════════════════

group('MenuScreen', () {
  testWidgets('displays title and subtitle', (tester) async {
    await pumpApp(tester);
    expect(find.text('SUM 10'), findsOneWidget);
    expect(find.textContaining('Freeze numbers'), findsOneWidget);
  });

  testWidgets('shows all three mode buttons', (tester) async {
    await pumpApp(tester);
    expect(find.textContaining('Survival'), findsOneWidget);
    expect(find.textContaining('Campaign'), findsOneWidget);
    expect(find.textContaining('Bouncy'), findsOneWidget);
  });

  testWidgets('each button shows its description', (tester) async {
    await pumpApp(tester);
    expect(find.text('Score as long as you can'), findsOneWidget);
    expect(find.text('Clear every cell to advance'), findsOneWidget);
    expect(find.text('Numbers bounce back 3 times'), findsOneWidget);
  });

  testWidgets('tapping Survival navigates to GameScreen', (tester) async {
    await goToGame(tester, '⚔️  Survival');
    // GameScreen has a back button; confirm we left the menu.
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('SUM 10'), findsNothing);
  });

  testWidgets('tapping Campaign navigates to GameScreen', (tester) async {
    await goToGame(tester, '🗺️  Campaign');
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('tapping Bouncy navigates to GameScreen', (tester) async {
    await goToGame(tester, '🏀  Bouncy');
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// 2. GameScreen – HUD
// ═════════════════════════════════════════════════════════════════════════════

group('GameScreen HUD', () {
  testWidgets('shows SCORE label and initial score of 0', (tester) async {
    await goToGame(tester, '⚔️  Survival');
    expect(find.text('SCORE'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('shows SPEED label', (tester) async {
    await goToGame(tester, '⚔️  Survival');
    expect(find.text('SPEED'), findsOneWidget);
  });

  testWidgets('shows timer starting at 0:00', (tester) async {
    await goToGame(tester, '⚔️  Survival');
    expect(find.text('0:00'), findsOneWidget);
  });

  testWidgets('shows 3 lives (hearts) on start', (tester) async {
    await goToGame(tester, '⚔️  Survival');
    // The hearts are rendered as emoji in a single Text widget, e.g. "❤️❤️❤️"
    expect(find.textContaining('❤️'), findsOneWidget);
  });

  testWidgets('Campaign HUD shows STAGE label', (tester) async {
    await goToGame(tester, '🗺️  Campaign');
    expect(find.textContaining('STAGE'), findsOneWidget);
  });

  testWidgets('Campaign HUD shows cells remaining', (tester) async {
    await goToGame(tester, '🗺️  Campaign');
    expect(find.textContaining('left'), findsOneWidget);
  });

  testWidgets('back button is present', (tester) async {
    await goToGame(tester, '⚔️  Survival');
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('settings icon is present', (tester) async {
    await goToGame(tester, '⚔️  Survival');
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('hint text is visible', (tester) async {
    await goToGame(tester, '⚔️  Survival');
    expect(find.textContaining('Tap to freeze'), findsOneWidget);
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// 3. GameScreen – grid
// ═════════════════════════════════════════════════════════════════════════════

group('GameScreen grid', () {
  testWidgets('renders a 5×5 grid (25 cells)', (tester) async {
    await goToGame(tester, '⚔️  Survival');
    // Each cell is a GestureDetector wrapping an AnimatedContainer.
    // Count the AnimatedContainers; all 25 cells use one.
    expect(find.byType(AnimatedContainer), findsNWidgets(25));
  });

  testWidgets('grid cells contain number text widgets', (tester) async {
    await goToGame(tester, '⚔️  Survival');
    // Each cell with a value shows a Text for 0-10. There should be at least
    // some cells with numbers visible.
    final texts = tester.widgetList<Text>(find.byType(Text));
    final numbers = texts
        .map((t) => t.data ?? '')
        .where((d) => RegExp(r'^\d+$').hasMatch(d))
        .toList();
    expect(numbers.isNotEmpty, isTrue);
  });

  testWidgets('tapping a cell does not throw', (tester) async {
    await goToGame(tester, '⚔️  Survival');
    final cells = find.byType(AnimatedContainer);
    await tester.tap(cells.first, warnIfMissed: false);
    await tester.pump();
    // No exception means the test passes.
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// 4. Settings panel
// ═════════════════════════════════════════════════════════════════════════════

group('Settings panel', () {
  testWidgets('opens when settings icon is tapped', (tester) async {
    await goToGame(tester, '⚔️  Survival');
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('shows Speed multiplier option', (tester) async {
    await goToGame(tester, '⚔️  Survival');
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('Speed multiplier'), findsOneWidget);
  });

  testWidgets('shows Unlimited lives toggle', (tester) async {
    await goToGame(tester, '⚔️  Survival');
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('Unlimited lives'), findsOneWidget);
  });

  testWidgets('shows Speed-up every option in Survival mode', (tester) async {
    await goToGame(tester, '⚔️  Survival');
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('Speed-up every'), findsOneWidget);
  });

  testWidgets('does not show Speed-up option in Campaign mode', (tester) async {
    await goToGame(tester, '🗺️  Campaign');
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('Speed-up every'), findsNothing);
  });

  testWidgets('Back to Menu button closes settings and pops game', (tester) async {
    await goToGame(tester, '⚔️  Survival');
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back to Menu'));
    await tester.pumpAndSettle();
    // Should be back on the menu.
    expect(find.text('SUM 10'), findsOneWidget);
  });

  testWidgets('settings panel has a speed slider', (tester) async {
    await goToGame(tester, '⚔️  Survival');
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsWidgets);
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// 5. Navigation
// ═════════════════════════════════════════════════════════════════════════════

group('Navigation', () {
  testWidgets('back button returns to menu from Survival', (tester) async {
    await goToGame(tester, '⚔️  Survival');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('SUM 10'), findsOneWidget);
  });

  testWidgets('back button returns to menu from Campaign', (tester) async {
    await goToGame(tester, '🗺️  Campaign');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('SUM 10'), findsOneWidget);
  });

  testWidgets('back button returns to menu from Bouncy', (tester) async {
    await goToGame(tester, '🏀  Bouncy');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('SUM 10'), findsOneWidget);
  });

  testWidgets('can navigate to Survival then back then to Campaign', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.textContaining('Survival'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Campaign'));
    await tester.pumpAndSettle();
    expect(find.textContaining('STAGE'), findsOneWidget);
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// 6. Mode-specific behaviour
// ═════════════════════════════════════════════════════════════════════════════

group('Mode differences', () {
  testWidgets('Bouncy mode loads without error', (tester) async {
    await goToGame(tester, '🏀  Bouncy');
    expect(find.text('SCORE'), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNWidgets(25));
  });

  testWidgets('Campaign starts at Stage 1', (tester) async {
    await goToGame(tester, '🗺️  Campaign');
    expect(find.textContaining('STAGE 1'), findsOneWidget);
  });

  testWidgets('Campaign shows 25 cells remaining at start', (tester) async {
    await goToGame(tester, '🗺️  Campaign');
    expect(find.text('25 left'), findsOneWidget);
  });
});
