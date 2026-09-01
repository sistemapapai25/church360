// LINK-01 (Fase 2, Plano 02-01): trava do formato da URL de compartilhamento.
//
// O bug corrigido: no mobile `buildShareUrl` devolvia um path relativo
// ("/events/<id>"), e quem compartilhava pelo WhatsApp mandava um texto que
// nao era link nenhum. Estes testes travam o contrato publico da funcao — URL
// absoluta, sem `#`, sem query/fragment herdados da sessao atual (T-02-02).
//
// Rodam na VM (`kIsWeb == false`), entao exercitam o ramo mobile, que e o ramo
// que estava quebrado. O ramo web depende de `Uri.base` do navegador e nao e
// observavel em teste puro de unidade.
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/core/constants/supabase_constants.dart';
import 'package:church360_app/core/utils/share_link_utils.dart';

void main() {
  group('ShareLinkUtils', () {
    test('devolve URL absoluta no host canonico fora do web', () {
      final url = ShareLinkUtils.buildShareUrl('/events/abc');

      expect(url, 'https://church360-app.vercel.app/events/abc');
    });

    test('normaliza path sem barra inicial para o mesmo resultado', () {
      expect(
        ShareLinkUtils.buildShareUrl('events/abc'),
        ShareLinkUtils.buildShareUrl('/events/abc'),
      );
      expect(
        ShareLinkUtils.buildShareUrl('events/abc'),
        'https://church360-app.vercel.app/events/abc',
      );
    });

    test('nunca contem `#` (App Links nao verificam fragmento)', () {
      for (final path in <String>[
        '/events/abc',
        'events/abc',
        '/events/abc/register',
        '/community/post/xyz',
        '/groups/g1/meetings/m1',
      ]) {
        expect(ShareLinkUtils.buildShareUrl(path), isNot(contains('#')));
      }
    });

    test('nunca comeca com `/` (nunca e um path solto)', () {
      for (final path in <String>[
        '/events/abc',
        'events/abc',
        '/study-groups/s1',
      ]) {
        final url = ShareLinkUtils.buildShareUrl(path);
        expect(url.startsWith('/'), isFalse);
        expect(url.startsWith('https://'), isTrue);
      }
    });

    test('nao vaza query nem fragment da sessao atual (T-02-02)', () {
      final parsed = Uri.parse(ShareLinkUtils.buildShareUrl('/events/abc'));

      expect(parsed.hasQuery, isFalse);
      expect(parsed.hasFragment, isFalse);
      expect(parsed.query, isEmpty);
      expect(parsed.fragment, isEmpty);
    });

    test('monta sobre a constante unica de host, sem barra dupla', () {
      final url = ShareLinkUtils.buildShareUrl('/events/abc');
      final host = Uri.parse(SupabaseConstants.appWebBaseUrl);

      expect(Uri.parse(url).host, host.host);
      expect(Uri.parse(url).scheme, host.scheme);
      expect(url, isNot(contains('//events')));
      expect(url.endsWith('/'), isFalse);
    });
  });
}
