// Регрессия: на задачу нельзя набрать больше студентов, чем нужно.
// Раньше кнопка «Взять задачу» оставалась активной и получалось «4 из 3».
import 'package:flutter_test/flutter_test.dart';
import 'package:medusa/controllers/help_controller.dart';
import 'package:medusa/models/help_request.dart';
import 'package:medusa/services/help_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<HelpController> _controller() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final service = HelpService();
  await service.init();
  final controller = HelpController(service);
  // Даём контроллеру загрузить профиль и запросы.
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Лимит участников задачи', () {
    test('нужно трое — четвёртый уже не берёт', () async {
      final help = await _controller();
      final request = await help.createRequest(
        title: 'Перетащить коробки',
        authorName: 'Ковалёва И. П.',
        category: HelpCategory.moving,
        needed: 3,
      );

      for (var i = 1; i <= 3; i++) {
        await help.setProfile(name: 'Студент $i', role: 'student');
        final taken = await help.takeTask(
          request.id,
          statusKey: 'ready',
          statusText: '',
        );
        expect(taken, isTrue, reason: 'место $i из 3 должно быть свободно');
      }

      final full = help.requestById(request.id)!;
      expect(full.takenCount, 3);
      expect(full.isFull, isTrue);

      // Четвёртый студент: задачу взять нельзя, счётчик не растёт.
      await help.setProfile(name: 'Студент 4', role: 'student');
      final taken = await help.takeTask(
        request.id,
        statusKey: 'ready',
        statusText: '',
      );
      expect(taken, isFalse, reason: 'мест больше нет');
      expect(help.requestById(request.id)!.takenCount, 3,
          reason: 'не должно появляться «4 из 3»');

      // Свой статус человек может менять, даже когда мест нет.
      await help.setProfile(name: 'Студент 2', role: 'student');
      final updated = await help.takeTask(
        request.id,
        statusKey: 'at_gate',
        statusText: '',
      );
      expect(updated, isTrue);
      expect(help.requestById(request.id)!.takenCount, 3);
    });

    test('освободилось место после отказа — можно взять снова', () async {
      final help = await _controller();
      final request = await help.createRequest(
        title: 'Настроить проектор',
        authorName: 'Сидоров А. Н.',
        category: HelpCategory.tech,
        needed: 1,
      );

      await help.setProfile(name: 'Первый', role: 'student');
      await help.takeTask(request.id, statusKey: 'ready', statusText: '');

      await help.setProfile(name: 'Второй', role: 'student');
      expect(
        await help.takeTask(request.id, statusKey: 'ready', statusText: ''),
        isFalse,
      );

      await help.setProfile(name: 'Первый', role: 'student');
      await help.leaveTask(request.id);
      expect(help.requestById(request.id)!.isFull, isFalse);

      await help.setProfile(name: 'Второй', role: 'student');
      expect(
        await help.takeTask(request.id, statusKey: 'ready', statusText: ''),
        isTrue,
      );
    });
  });
}
