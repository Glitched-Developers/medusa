import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medusa/view/widgets/blur_fade.dart';

/// Находим Opacity/ImageFiltered именно внутри BlurFade: у MaterialApp
/// могут быть свои служебные слои.
Finder _inside<T extends Widget>() => find.descendant(
      of: find.byType(BlurFade),
      matching: find.byType(T),
    );

void main() {
  testWidgets('содержимое проявляется из размытия', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: BlurFade(child: Text('расписание'))),
    );

    // Первый кадр: почти прозрачно и размыто.
    final startOpacity = tester.widget<Opacity>(_inside<Opacity>()).opacity;
    expect(startOpacity, lessThan(0.1));
    expect(_inside<ImageFiltered>(), findsOneWidget);

    // Середина пути: уже проявилось, но ещё не до конца.
    await tester.pump(const Duration(milliseconds: 260));
    final midOpacity = tester.widget<Opacity>(_inside<Opacity>()).opacity;
    expect(midOpacity, greaterThan(startOpacity));
    expect(midOpacity, lessThan(1.0));

    // Готово: лишних слоёв не остаётся.
    await tester.pump(const Duration(milliseconds: 400));
    expect(_inside<Opacity>(), findsNothing);
    expect(_inside<ImageFiltered>(), findsNothing);
    expect(find.text('расписание'), findsOneWidget);
  });

  testWidgets('задержка откладывает появление', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BlurFade(delay: Duration(milliseconds: 200), child: Text('день')),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<Opacity>(_inside<Opacity>()).opacity, 0.0);

    // Даём тикерам прокрутить кадры: задержка + длительность анимации.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_inside<Opacity>(), findsNothing);
    expect(find.text('день'), findsOneWidget);
  });
}
