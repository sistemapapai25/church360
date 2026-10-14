import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/app_icons.dart';
import '../theme/app_theme.dart';
import 'pearl_fab.dart';

/// B6 (roadmap Home/culto/Dashboard, 14/10/2026): botão flutuante do Leitor
/// de QR Code sobre o corpo da Dashboard, só para quem tem `events.checkin`
/// (o gate fica em quem monta a tela).
///
/// Arrasta para onde quiser. Solto para fora de uma lateral, ou segurado,
/// vira uma aba na borda mais próxima; tocar na aba traz o botão de volta.
/// Posição e estado ficam em `SharedPreferences`: é preferência do aparelho
/// ou navegador, não dado da igreja, então não vai ao banco.
///
/// Monta como filho **não posicionado** de um `Stack` que cobre o corpo:
/// ocupa a área toda mas só o botão recebe toques.
class QrScannerFab extends StatefulWidget {
  const QrScannerFab({super.key, this.onTap});

  /// Padrão: abre `/qr-scanner`. Os testes passam o próprio.
  final VoidCallback? onTap;

  static const double size = 56;
  static const double margin = 16;
  static const double tabWidth = 28;
  static const double tabHeight = 56;

  static const String prefX = 'qr_fab_x';
  static const String prefY = 'qr_fab_y';
  static const String prefHidden = 'qr_fab_hidden';

  @override
  State<QrScannerFab> createState() => _QrScannerFabState();
}

class _QrScannerFabState extends State<QrScannerFab> {
  Offset? _pos;
  bool _hidden = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final x = prefs.getDouble(QrScannerFab.prefX);
      final y = prefs.getDouble(QrScannerFab.prefY);
      if (!mounted) return;
      setState(() {
        if (x != null && y != null) _pos = Offset(x, y);
        _hidden = prefs.getBool(QrScannerFab.prefHidden) ?? false;
        _loaded = true;
      });
    } catch (_) {
      // Sem armazenamento (janela anônima etc.): botão no lugar padrão.
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pos = _pos;
      if (pos != null) {
        await prefs.setDouble(QrScannerFab.prefX, pos.dx);
        await prefs.setDouble(QrScannerFab.prefY, pos.dy);
      }
      await prefs.setBool(QrScannerFab.prefHidden, _hidden);
    } catch (_) {
      // Preferência de conveniência: perder não quebra nada.
    }
  }

  Offset _clamp(Offset p, BoxConstraints c) {
    const s = QrScannerFab.size;
    return Offset(
      p.dx.clamp(0.0, (c.maxWidth - s).clamp(0.0, double.infinity)),
      p.dy.clamp(0.0, (c.maxHeight - s).clamp(0.0, double.infinity)),
    );
  }

  void _hide() {
    setState(() => _hidden = true);
    _save();
  }

  void _show(BoxConstraints c, {required bool onLeft}) {
    final y = (_pos ?? _defaultPos(c)).dy;
    setState(() {
      _hidden = false;
      _pos = _clamp(
        Offset(
          onLeft
              ? QrScannerFab.margin
              : c.maxWidth - QrScannerFab.size - QrScannerFab.margin,
          y,
        ),
        c,
      );
    });
    _save();
  }

  /// Canto inferior esquerdo: o canto direito é do Menu de Gestão.
  Offset _defaultPos(BoxConstraints c) => Offset(
        QrScannerFab.margin,
        c.maxHeight - QrScannerFab.size - QrScannerFab.margin,
      );

  void _open() {
    final onTap = widget.onTap;
    if (onTap != null) return onTap();
    context.push('/qr-scanner');
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) {
        final pos = _clamp(_pos ?? _defaultPos(c), c);
        final onLeft = pos.dx + QrScannerFab.size / 2 < c.maxWidth / 2;

        if (_hidden) {
          return Stack(
            children: [
              Positioned(
                top: pos.dy,
                left: onLeft ? 0 : null,
                right: onLeft ? null : 0,
                child: _EdgeTab(
                  onLeft: onLeft,
                  onTap: () => _show(c, onLeft: onLeft),
                ),
              ),
            ],
          );
        }

        return Stack(
          children: [
            Positioned(
              left: pos.dx,
              top: pos.dy,
              child: GestureDetector(
                // `down`: o botão acompanha o dedo desde o primeiro pixel.
                dragStartBehavior: DragStartBehavior.down,
                onPanUpdate: (d) {
                  final next = pos + d.delta;
                  // Passou da lateral: vira aba.
                  final limit = QrScannerFab.size / 3;
                  if (next.dx < -limit ||
                      next.dx > c.maxWidth - QrScannerFab.size + limit) {
                    _pos = _clamp(next, c);
                    _hide();
                    return;
                  }
                  setState(() => _pos = _clamp(next, c));
                },
                onPanEnd: (_) => _save(),
                onLongPress: _hide,
                // Tooltip só no mouse: no toque, segurar é "esconder" (o
                // Tooltip padrão disputaria o long press).
                child: Tooltip(
                  message: 'Leitor de QR Code (arraste; segure para esconder)',
                  triggerMode: TooltipTriggerMode.manual,
                  child: PearlFab(onPressed: _open, icon: AppIcons.qrCode),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Aba na borda: a ponta do botão escondido.
class _EdgeTab extends StatelessWidget {
  const _EdgeTab({required this.onLeft, required this.onTap});

  final bool onLeft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = Radius.circular(QrScannerFab.tabHeight / 2);
    return Tooltip(
      message: 'Mostrar o Leitor de QR Code',
      child: Material(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.horizontal(
          left: onLeft ? Radius.zero : radius,
          right: onLeft ? radius : Radius.zero,
        ),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: QrScannerFab.tabWidth,
            height: QrScannerFab.tabHeight,
            child: Icon(
              onLeft ? Icons.chevron_right : Icons.chevron_left,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
