import 'package:flutter/material.dart';
import '../core/widgets/pearl_button.dart';
import '../core/widgets/navigation/pearl_glass_dock.dart';

/// Entry point isolado só para validar visualmente o PearlButton refinado,
/// sem tocar em nenhuma tela real do app.
///
/// Rodar com:
///   flutter run -d chrome --web-port 3005 -t lib/dev/pearl_button_playground.dart
void main() {
  runApp(const PearlPlaygroundApp());
}

class PearlPlaygroundApp extends StatelessWidget {
  const PearlPlaygroundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pearl Button Playground',
      theme: ThemeData(useMaterial3: true),
      home: const PearlButtonPlaygroundScreen(),
    );
  }
}

class _NavColorSample {
  final String label;
  final Color color;
  final IconData icon;

  const _NavColorSample({
    required this.label,
    required this.color,
    required this.icon,
  });
}

class PearlButtonPlaygroundScreen extends StatefulWidget {
  const PearlButtonPlaygroundScreen({super.key});

  // Cores-base pensadas já em par claro/escuro: o PearlButton refinado
  // deriva sozinho a versão "milky" (claro) e "smoked" (escuro) a partir
  // dessa MESMA cor de identidade — não são duas paletas diferentes.
  static const _items = [
    _NavColorSample(label: 'Home', color: Color(0xFF2F80ED), icon: Icons.home_rounded),
    _NavColorSample(label: 'Bíblia', color: Color(0xFF9B51E0), icon: Icons.menu_book_rounded),
    _NavColorSample(label: 'Igreja', color: Color(0xFF1F3C88), icon: Icons.church_rounded),
    _NavColorSample(label: 'Cursos', color: Color(0xFF27AE60), icon: Icons.school_rounded),
    _NavColorSample(label: 'Mais', color: Color(0xFFF2994A), icon: Icons.more_horiz_rounded),
  ];

  // Mesma cor/tamanho aprovados do CTA real (home_screen.dart) — o
  // posicionamento (canto + overflow) está sendo revisado no
  // _ContribuaCardDemo abaixo.
  static const _ctaColor = Color(0xFF1E7A3E);
  static const _ctaSize = 48.0;

  @override
  State<PearlButtonPlaygroundScreen> createState() => _PearlButtonPlaygroundScreenState();
}

class _PearlButtonPlaygroundScreenState extends State<PearlButtonPlaygroundScreen> {
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    final items = PearlButtonPlaygroundScreen._items;
    final bg = _dark ? const Color(0xFF14161D) : const Color(0xFFF3F1EE);
    final fg = _dark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pearl Button — Playground (revisão claro/escuro + moldagem)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: fg),
                ),
                const SizedBox(height: 8),
                Text(
                  'Passe o mouse (sem clicar) para ver o HOVER.\n'
                  'Clique e segure para ver o ACTIVE (afundamento).',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: fg.withValues(alpha: 0.6), height: 1.4),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Claro', style: TextStyle(fontSize: 13, color: fg)),
                    Switch(value: _dark, onChanged: (v) => setState(() => _dark = v)),
                    Text('Escuro', style: TextStyle(fontSize: 13, color: fg)),
                  ],
                ),
                const SizedBox(height: 32),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: items.map((item) {
                    return PearlButton(
                      color: item.color,
                      width: 200,
                      height: 64,
                      dark: _dark,
                      moldingEnabled: true,
                      lightTintBoost: 0.10,
                      onTap: () {},
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item.icon, color: Colors.white, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            item.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 56),
                Text(
                  'Tamanho real da barra inferior (44x30)',
                  style: TextStyle(fontSize: 14, color: fg.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: PearlButton(
                        color: item.color,
                        width: 44,
                        height: 30,
                        borderRadius: BorderRadius.circular(14),
                        dark: _dark,
                        moldingEnabled: true,
                        lightTintBoost: 0.10,
                        onTap: () {},
                        child: Icon(item.icon, color: Colors.white, size: 18),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 56),
                Divider(color: fg.withValues(alpha: 0.15)),
                const SizedBox(height: 24),
                Text(
                  'Dock de vidro — bottom nav (teste)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fg),
                ),
                const SizedBox(height: 8),
                Text(
                  'Os 5 itens agora são sempre da família Pearl — só a intensidade\n'
                  'muda entre repouso, hover e selecionado. Toque num item pra\n'
                  'simular a seleção; passe o mouse pra ver o hover.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: fg.withValues(alpha: 0.6), height: 1.4),
                ),
                const SizedBox(height: 20),
                _PearlDockDemo(dark: _dark),
                const SizedBox(height: 56),
                Divider(color: fg.withValues(alpha: 0.15)),
                const SizedBox(height: 24),
                Text(
                  'CTA "Contribua" — card Comunidade (mesma composição do app real)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fg),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ajuste v2: recuo real (subtração de um círculo maior que o\n'
                  'botão da silhueta do card, não só um raio de canto maior) +\n'
                  'wrapper com espaço reservado nos dois eixos pra o botão\n'
                  'nunca depender de sobra de layout ao redor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: fg.withValues(alpha: 0.6), height: 1.4),
                ),
                const SizedBox(height: 24),
                _ContribuaCardDemo(dark: _dark),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reproduz em miniatura o card "Comunidade" do home_screen.dart real.
///
/// v2 do recuo: a silhueta do card não usa mais "raio de canto maior" (isso
/// só arredonda a quina, não abraça o botão). Agora é uma subtração real —
/// [_CornerHugBorder] tira da silhueta um círculo centrado no botão e maior
/// que ele, então a borda do card literalmente desvia ao redor da forma do
/// botão, com folga, em vez de só ter uma curva genérica no canto.
///
/// O botão continua "parte dentro, parte fora" (mais pra baixo/direita),
/// mas o wrapper agora reserva espaço extra nos DOIS eixos (antes só
/// reservava embaixo) — sem essa reserva, o botão dependia de sobra de
/// espaço do layout ao redor pra não ser cortado, que é exatamente o que
/// faltou no app real.
class _ContribuaCardDemo extends StatelessWidget {
  final bool dark;

  const _ContribuaCardDemo({required this.dark});

  static const _ctaColor = PearlButtonPlaygroundScreen._ctaColor;
  static const _ctaSize = PearlButtonPlaygroundScreen._ctaSize;

  static const _cardRadius = 20.0;
  static const _cardWidth = 340.0;
  static const _cardHeight = 92.0;

  // Quanto do botão fica pra fora do card, pra baixo e pra direita.
  static const _ctaOutX = 12.0;
  static const _ctaOutY = 20.0;

  // Folga do recuo além do raio do próprio botão — é essa folga que faz o
  // card parecer que "abraça" o botão em vez de só encostar nele.
  static const _notchMargin = 16.0;

  @override
  Widget build(BuildContext context) {
    final cardColor = dark ? const Color(0xFF1D2027) : Colors.white;
    final borderColor = dark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);

    const ctaRadius = _ctaSize / 2;
    const buttonLeft = _cardWidth - _ctaSize + _ctaOutX;
    const buttonTop = _cardHeight - _ctaSize + _ctaOutY;
    const notchCenter = Offset(buttonLeft + ctaRadius, buttonTop + ctaRadius);
    const notchRadius = ctaRadius + _notchMargin;

    final shape = _CornerHugBorder(
      cardRadius: _cardRadius,
      notchCenter: notchCenter,
      notchRadius: notchRadius,
      borderColor: borderColor,
    );

    return SizedBox(
      // Reserva espaço extra à DIREITA (novo) e embaixo pro botão nunca
      // ficar fora dos limites do wrapper, mesmo que um ancestral real
      // (Row, ListView, etc.) respeite esses limites em vez do overflow
      // "de graça" do Stack.
      width: _cardWidth + _ctaOutX + 6,
      height: _cardHeight + _ctaOutY + 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: _cardWidth,
            height: _cardHeight,
            child: Container(
              decoration: ShapeDecoration(
                color: cardColor,
                shape: shape,
                shadows: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.35 : 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                shape: shape,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: shape,
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18 + notchRadius * 0.7, 16),
                    child: _ContribuaCardText(dark: dark),
                  ),
                ),
              ),
            ),
          ),
          // Ancorado no canto inferior direito, encaixado exatamente no
          // recuo desenhado por [_CornerHugBorder] acima.
          Positioned(
            left: buttonLeft,
            top: buttonTop,
            child: PearlButton(
              color: _ctaColor,
              width: _ctaSize,
              height: _ctaSize,
              borderRadius: BorderRadius.circular(_ctaSize / 2),
              dark: dark,
              moldingEnabled: true,
              lightTintBoost: 0.22,
              onTap: () {},
              child: const Icon(Icons.volunteer_activism, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContribuaCardText extends StatelessWidget {
  final bool dark;

  const _ContribuaCardText({required this.dark});

  @override
  Widget build(BuildContext context) {
    final titleColor = dark ? Colors.white : Colors.black87;
    final metaColor = dark ? Colors.white.withValues(alpha: 0.6) : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Comunidade',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: titleColor),
        ),
        const SizedBox(height: 4),
        Text(
          'Conecte-se, compartilhe pedidos de oração e testemunhos.',
          style: TextStyle(fontSize: 12, height: 1.3, color: metaColor),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Silhueta do card com um recuo circular real ao redor do CTA — em vez de
/// só arredondar o canto, subtrai da forma um círculo centrado no botão
/// (maior que ele, com folga), então a borda literalmente desvia ao redor
/// da forma do botão. Elevação/sombra e o ripple do InkWell seguem essa
/// mesma silhueta (via [ShapeDecoration.shape] / [InkWell.customBorder]),
/// então tudo — sombra, borda, recorte de toque — seguem o mesmo desenho.
class _CornerHugBorder extends ShapeBorder {
  final double cardRadius;
  final Offset notchCenter;
  final double notchRadius;
  final Color borderColor;

  const _CornerHugBorder({
    required this.cardRadius,
    required this.notchCenter,
    required this.notchRadius,
    required this.borderColor,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final base = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(cardRadius)));
    final notch = Path()
      ..addOval(Rect.fromCircle(center: rect.topLeft + notchCenter, radius: notchRadius));
    return Path.combine(PathOperation.difference, base, notch);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final path = getOuterPath(rect, textDirection: textDirection);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = borderColor,
    );
  }

  @override
  ShapeBorder scale(double t) => this;
}

class _PearlDockDemo extends StatefulWidget {
  final bool dark;

  const _PearlDockDemo({required this.dark});

  @override
  State<_PearlDockDemo> createState() => _PearlDockDemoState();
}

class _PearlDockDemoState extends State<_PearlDockDemo> {
  int _selected = 2; // "Igreja", igual ao exemplo do vídeo do amigo.
  // Nomes desligados por enquanto (pedido explícito) — sem toggle pra não
  // testar duas coisas ao mesmo tempo enquanto ajustamos claro/escuro.
  static const bool _showLabels = false;

  static Widget _fakeContentBlock(bool dark) => Container(
        width: 90,
        height: 34,
        decoration: BoxDecoration(
          color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final items = PearlButtonPlaygroundScreen._items;
    final dark = widget.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        width: 360,
        height: 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? [const Color(0xFF2A3B54), const Color(0xFF14161D)]
                      : [const Color(0xFFDDE6F5), const Color(0xFFF7EFE0)],
                ),
              ),
            ),
            // Blocos simulando conteúdo passando atrás, pra evidenciar o blur.
            Positioned(top: 20, left: 30, child: _fakeContentBlock(dark)),
            Positioned(top: 60, right: 20, child: _fakeContentBlock(dark)),
            Positioned(top: 110, left: 100, child: _fakeContentBlock(dark)),
            Align(
              alignment: Alignment.bottomCenter,
              child: PearlGlassDock(
                dark: dark,
                children: List.generate(items.length, (i) {
                  final item = items[i];
                  return PearlDockItem(
                    contentBuilder: (context, selected, color) =>
                        Icon(item.icon, color: Colors.white, size: 18),
                    label: item.label,
                    color: item.color,
                    selected: _selected == i,
                    showLabel: _showLabels,
                    dark: dark,
                    onTap: () => setState(() => _selected = i),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
