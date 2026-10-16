import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/live_stream/presentation/widgets/slides_viewer.dart';

void main() {
  group('slidesEmbedUrl', () {
    test('link "Publicar na web" do Google Slides vira /embed', () {
      expect(
        slidesEmbedUrl(
          'https://docs.google.com/presentation/d/e/2PACX-1vAbC_d-e/pub?start=false&loop=false&delayms=3000',
        ),
        'https://docs.google.com/presentation/d/e/2PACX-1vAbC_d-e/embed?start=false&loop=false',
      );
    });

    test('link de edição vira /embed (funciona se o deck for público)', () {
      expect(
        slidesEmbedUrl(
          'https://docs.google.com/presentation/d/1AbC_d-e/edit#slide=id.p',
        ),
        'https://docs.google.com/presentation/d/1AbC_d-e/embed?start=false&loop=false',
      );
    });

    test('link /embed com outros parâmetros é normalizado', () {
      expect(
        slidesEmbedUrl(
          '  https://docs.google.com/presentation/d/1AbC/embed?start=true ',
        ),
        'https://docs.google.com/presentation/d/1AbC/embed?start=false&loop=false',
      );
    });

    test('PowerPoint enviado vai pelo visualizador do Office', () {
      const pptx = 'https://x.test/storage/culto/20261016/1.PPTX';
      expect(
        slidesEmbedUrl(' $pptx '),
        'https://view.officeapps.live.com/op/embed.aspx?src='
        '${Uri.encodeComponent(pptx)}',
      );
      expect(isPowerPoint('https://x.test/a.ppt?x=1'), isTrue);
      expect(isPowerPoint('https://x.test/a.pdf'), isFalse);
    });

    test('PDF ou outro link fica como está (só tira espaços)', () {
      expect(
        slidesEmbedUrl(' https://x.test/culto.pdf '),
        'https://x.test/culto.pdf',
      );
    });
  });

  group('slidesNativeUrl', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('Android: PDF passa pelo visualizador do Google', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        slidesNativeUrl('https://x.test/culto.pdf'),
        'https://docs.google.com/gview?embedded=true&url='
        '${Uri.encodeComponent('https://x.test/culto.pdf')}',
      );
    });

    test('Android: Google Slides vai direto no /embed', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        slidesNativeUrl('https://docs.google.com/presentation/d/1AbC/edit'),
        'https://docs.google.com/presentation/d/1AbC/embed?start=false&loop=false',
      );
    });

    test('Android: PowerPoint vai direto no Office', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        slidesNativeUrl('https://x.test/culto.pptx'),
        startsWith('https://view.officeapps.live.com/op/embed.aspx?src='),
      );
    });

    test('iOS: PDF vai direto', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(
        slidesNativeUrl('https://x.test/culto.pdf'),
        'https://x.test/culto.pdf',
      );
    });
  });
}
