// Эффект появления текста: буквы проявляются из размытия.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medusa/view/widgets/blur_in_text.dart';

/// Правые края строк отрисованного абзаца: по ним видно, где легли переносы.
List<double> _lineRightEdges(WidgetTester tester) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.byType(RichText).last,
  );
  final length = paragraph.text.toPlainText().length;
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: length),
  );
  final byLine = <double, double>{};
  for (final box in boxes) {
    final current = byLine[box.top] ?? 0;
    if (box.right > current) byLine[box.top] = box.right;
  }
  return byLine.values.toList(growable: false);
}

void main() {
  testWidgets('BlurInText перерисовывает текст и доигрывает анимацию',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: BlurInText(
              'Привет',
              by: BlurInBy.character,
              duration: Duration(milliseconds: 100),
              stagger: Duration(milliseconds: 10),
            ),
          ),
        ),
      ),
    );

    // Сразу после старта текст уже на месте — просто пока размыт.
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Привет'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('BlurInText по словам не теряет текст', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BlurInText(
            'Первое слово и второе',
            by: BlurInBy.word,
            duration: Duration(milliseconds: 100),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Первое'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('буквы не ломают слова при переносе строки', (tester) async {
    const title = 'Студенты НИУ «БелГУ» стали победителями всероссийской '
        'олимпиады по программированию среди вузов';
    const style = TextStyle(fontSize: 24, height: 1.25);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: Text(title, style: style),
          ),
        ),
      ),
    );
    final plain = _lineRightEdges(tester);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: BlurInText(title, style: style),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_lineRightEdges(tester), plain);
  });

  testWidgets('BlurInText уважает системное отключение анимаций',
      (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: BlurInText('Сразу видно', by: BlurInBy.character),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Сразу видно'), findsOneWidget);
  });
}
