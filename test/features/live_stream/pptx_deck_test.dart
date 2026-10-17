import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:church360_app/features/live_stream/data/pptx_deck.dart';
import 'package:flutter_test/flutter_test.dart';

const _ns =
    'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
    'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"';

String _pic(String rId, int x) =>
    '<p:pic><p:blipFill><a:blip r:embed="$rId"/></p:blipFill><p:spPr><a:xfrm>'
    '<a:off x="$x" y="0"/><a:ext cx="100" cy="50"/></a:xfrm></p:spPr></p:pic>';

Uint8List _pptx(List<String> slideTrees) {
  final zip = Archive();
  void add(String path, String text) {
    final bytes = utf8.encode(text);
    zip.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  // Ordem da apresentação ao contrário da numeração dos arquivos.
  final ids = [for (var i = slideTrees.length; i >= 1; i--) i];
  add(
    'ppt/presentation.xml',
    '<p:presentation $_ns><p:sldIdLst>'
        '${ids.map((i) => '<p:sldId id="${255 + i}" r:id="rId$i"/>').join()}'
        '</p:sldIdLst><p:sldSz cx="1600" cy="900"/></p:presentation>',
  );
  add(
    'ppt/_rels/presentation.xml.rels',
    '<Relationships>${[for (var i = 1; i <= slideTrees.length; i++) '<Relationship Id="rId$i" Target="slides/slide$i.xml"/>'].join()}</Relationships>',
  );
  for (var i = 1; i <= slideTrees.length; i++) {
    add(
      'ppt/slides/slide$i.xml',
      '<p:sld $_ns><p:cSld><p:bg><p:bgPr><a:solidFill><a:srgbClr val="112233"/>'
          '</a:solidFill></p:bgPr></p:bg><p:spTree><p:nvGrpSpPr/><p:grpSpPr/>'
          '${slideTrees[i - 1]}</p:spTree></p:cSld></p:sld>',
    );
    add(
      'ppt/slides/_rels/slide$i.xml.rels',
      '<Relationships><Relationship Id="rIdImg" Target="../media/img$i.png"/></Relationships>',
    );
    zip.addFile(ArchiveFile('ppt/media/img$i.png', 1, [i]));
  }
  return Uint8List.fromList(ZipEncoder().encode(zip));
}

void main() {
  test('lê slides na ordem da apresentação, com imagens e fundo', () {
    final deck = PptxDeck.tryParse(
      _pptx([_pic('rIdImg', 10), _pic('rIdImg', 20)]),
    )!;
    expect((deck.width, deck.height), (1600, 900));
    expect(deck.slides, hasLength(2));
    // sldIdLst lista o slide2.xml primeiro.
    expect(deck.slides.first.pictures.single.bytes, [2]);
    expect(deck.slides.first.pictures.single.x, 20);
    expect(deck.slides.first.background, '112233');
  });

  test('slide com texto ou forma cai no visualizador do Office', () {
    final withText = _pptx([
      _pic('rIdImg', 0),
      '<p:sp><p:txBody><a:p><a:r><a:t>Oi</a:t></a:r></a:p></p:txBody></p:sp>',
    ]);
    expect(PptxDeck.tryParse(withText), isNull);
    expect(PptxDeck.tryParse(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
