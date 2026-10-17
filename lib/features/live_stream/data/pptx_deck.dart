import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Imagem do slide, em EMU (a unidade do PowerPoint), na ordem de desenho.
class PptxPicture {
  final int x, y, w, h;
  final Uint8List bytes;

  const PptxPicture(this.x, this.y, this.w, this.h, this.bytes);
}

class PptxSlide {
  /// Cor de fundo `RRGGBB` (só `solidFill`); nula = preto.
  final String? background;
  final List<PptxPicture> pictures;

  const PptxSlide(this.background, this.pictures);
}

/// Leitor próprio dos slides do culto. Cobre o PPTX do PreacherLAB (fundo de
/// cor sólida + imagens posicionadas). Qualquer outra coisa — texto, forma,
/// tabela, grupo, recorte — devolve null para a tela cair no visualizador do
/// Office, em vez de mostrar slide pela metade.
class PptxDeck {
  final int width, height;
  final List<PptxSlide> slides;

  const PptxDeck(this.width, this.height, this.slides);

  static PptxDeck? tryParse(Uint8List bytes) {
    try {
      return _parse(ZipDecoder().decodeBytes(bytes));
    } catch (_) {
      return null;
    }
  }

  static const _drawn = {'nvGrpSpPr', 'grpSpPr', 'pic'};

  static PptxDeck? _parse(Archive zip) {
    XmlDocument xml(String path) =>
        XmlDocument.parse(utf8.decode(zip.findFile(path)!.content));
    Map<String, String> rels(String path) => {
      for (final r in xml(path).findAllElements('Relationship'))
        r.getAttribute('Id')!: r.getAttribute('Target')!,
    };

    final pres = xml('ppt/presentation.xml');
    final size = pres.findAllElements('p:sldSz').first;
    final presRels = rels('ppt/_rels/presentation.xml.rels');
    final slides = <PptxSlide>[];

    for (final id in pres.findAllElements('p:sldId')) {
      final path = 'ppt/${presRels[id.getAttribute('r:id')]!}';
      final slide = xml(path).rootElement;
      if (slide.getAttribute('show') == '0') continue;
      final dir = path.substring(0, path.lastIndexOf('/'));
      final name = path.substring(path.lastIndexOf('/') + 1);
      final slideRels = rels('$dir/_rels/$name.rels');

      final tree = slide.findAllElements('p:spTree').first;
      final pictures = <PptxPicture>[];
      for (final el in tree.childElements) {
        if (!_drawn.contains(el.localName)) return null;
        if (el.localName != 'pic') continue;
        final src = el.findAllElements('a:srcRect').firstOrNull;
        if (src != null &&
            src.attributes.any((a) => (int.tryParse(a.value) ?? 0) != 0)) {
          return null;
        }
        final off = el.findAllElements('a:off').first;
        final ext = el.findAllElements('a:ext').first;
        final target =
            slideRels[el
                .findAllElements('a:blip')
                .first
                .getAttribute('r:embed')]!;
        final media = Uri.parse('$dir/').resolve(target).path;
        pictures.add(
          PptxPicture(
            int.parse(off.getAttribute('x')!),
            int.parse(off.getAttribute('y')!),
            int.parse(ext.getAttribute('cx')!),
            int.parse(ext.getAttribute('cy')!),
            Uint8List.fromList(zip.findFile(media)!.content),
          ),
        );
      }
      final bg = slide.findAllElements('p:bg').firstOrNull;
      if (bg != null && bg.findAllElements('a:blipFill').isNotEmpty) {
        return null;
      }
      slides.add(
        PptxSlide(
          bg?.findAllElements('a:srgbClr').firstOrNull?.getAttribute('val'),
          pictures,
        ),
      );
    }
    if (slides.isEmpty) return null;
    return PptxDeck(
      int.parse(size.getAttribute('cx')!),
      int.parse(size.getAttribute('cy')!),
      slides,
    );
  }
}
