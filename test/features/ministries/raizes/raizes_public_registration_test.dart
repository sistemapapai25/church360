import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/features/ministries/raizes/presentation/screens/raizes_public_registration_screen.dart';

void main() {
  test('erros da RPC pública viram texto para o visitante', () {
    PostgrestException e(String m) => PostgrestException(message: m);
    expect(raizesPublicErrorMessage(e('LGPD_REQUIRED')), contains('concorda'));
    expect(raizesPublicErrorMessage(e('INVALID_PHONE')), contains('DDD'));
    expect(raizesPublicErrorMessage(e('TOO_MANY')), contains('minutos'));
    expect(
      raizesPublicErrorMessage(e('MINISTRY_NOT_FOUND')),
      contains('não existe'),
    );
    expect(raizesPublicErrorMessage(Exception('x')), contains('Tente de novo'));
  });
}
