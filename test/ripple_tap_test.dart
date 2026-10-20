import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medusa/view/widgets/ripple_tap.dart';

void main() {
  testWidgets('волна появляется по нажатию и не мешает кнопке', (tester) async {
    var pressed = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RippleTap(
              color: Colors.white.withValues(alpha: 0.45),
              child: ElevatedButton(
                onPressed: () => pressed++,
                child: const Text('Жми'),
              ),
            ),
          ),
        ),
      ),
    );

    Finder wave() => find.descendant(
          of: find.byType(RippleTap),
          matching: find.byType(TweenAnimationBuilder<double>),
        );

    expect(wave(), findsNothing);

    await tester.tap(find.text('Жми'));
    await tester.pump();

    // Кнопка получила нажатие, поверх неё живёт волна.
    expect(pressed, 1);
    expect(wave(), findsOneWidget);

    // Волна доиграла и убралась — лишние слои не рисуются.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(wave(), findsNothing);
  });

  testWidgets('не сжимает кнопку внутри SizedBox на всю ширину', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 50,
              child: RippleTap(
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Начать работу'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final button = tester.getSize(find.byType(ElevatedButton));
    expect(button.width, 300,
        reason: 'кнопка должна занимать всю ширину, как без обёртки');
    expect(button.height, 50);
  });

  testWidgets('несколько нажатий подряд дают несколько волн', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RippleTap(
              child: FilledButton(onPressed: () {}, child: const Text('Раз')),
            ),
          ),
        ),
      ),
    );

    Finder wave() => find.descendant(
          of: find.byType(RippleTap),
          matching: find.byType(TweenAnimationBuilder<double>),
        );

    await tester.tap(find.text('Раз'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Раз'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(wave(), findsNWidgets(2));
  });
}
