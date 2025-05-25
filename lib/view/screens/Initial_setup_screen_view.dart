import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:medusa/view/screens/schedule_screen_view.dart';

class InitialSetupScreenView extends StatelessWidget {
  const InitialSetupScreenView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Text(
                'Введите номер группы:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28),
              ),
              const SizedBox(height: 16),
              TextField(
                textAlign: TextAlign.center,
                style:TextStyle(fontSize:24),
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly
                ],
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelStyle:TextStyle(fontSize:24),
                  hintStyle: TextStyle(fontSize:24),
                ),
              ),
              const Spacer(),
              // Кнопка начала работы
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // Устанавливаем флаг, что приложение было запущено

                    // Переходим на основной экран
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const ScheduleScreenView(),
                      ),
                    );
                  },
                  child: const Text('Начать работу', style: TextStyle(fontSize: 24),),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}