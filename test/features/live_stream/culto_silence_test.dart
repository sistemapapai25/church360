import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:church360_app/features/live_stream/presentation/widgets/culto_silence_row.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('church360/dnd');
  late bool granted;
  late bool on;
  late List<String> calls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    granted = true;
    on = false;
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          switch (call.method) {
            case 'granted':
              return granted;
            case 'isOn':
              return on;
            case 'set':
              on = call.arguments == true;
              return true;
          }
          return null;
        });
  });

  test('liga no culto e desliga no fim', () async {
    expect(await CultoSilence.turnOn(), isTrue);
    expect(on, isTrue);
    await CultoSilence.restore();
    expect(on, isFalse);
  });

  test('já estava em Não perturbe: o fim do culto não desliga', () async {
    on = true;
    expect(await CultoSilence.turnOn(), isTrue);
    await CultoSilence.restore();
    expect(on, isTrue);
  });

  test('sem acesso: abre as configurações e não liga', () async {
    granted = false;
    expect(await CultoSilence.turnOn(), isFalse);
    expect(calls, contains('openSettings'));
    expect(on, isFalse);
  });
}
