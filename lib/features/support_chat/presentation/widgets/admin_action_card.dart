import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/widgets/pearl_button.dart';
import '../../domain/admin_action.dart';

/// Botão em pílula (PearlButton, animação de 180ms) com altura compacta.
class AdminPillButton extends StatelessWidget {
  const AdminPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = const Color(0xFF2563EB),
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: PearlButton(
        color: color,
        height: 34,
        width: (label.length * 8.0 + 32).clamp(96.0, 260.0),
        onTap: onTap,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Card do `[[ADMIN_ACTION]]` no chat do Moisés. Quem decide se pode é o banco;
/// o card só chama as RPCs com o login do usuário.
class AdminActionCard extends StatefulWidget {
  const AdminActionCard({super.key, required this.action});

  final AdminAction action;

  /// Ids já resolvidos nesta sessão -> texto do resultado. Sobrevive ao
  /// rebuild da lista do chat: não oferece de novo uma ação já decidida.
  static final Map<String, String> _resolvidas = {};

  @override
  State<AdminActionCard> createState() => _AdminActionCardState();
}

class _AdminActionCardState extends State<AdminActionCard> {
  bool _busy = false;
  String? _erro;

  Future<void> _rodar(String rpc, Map<String, dynamic> params) async {
    setState(() {
      _busy = true;
      _erro = null;
    });
    try {
      final r = await Supabase.instance.client.rpc(rpc, params: params);
      final texto = adminActionResultText(r is Map ? r : const {});
      AdminActionCard._resolvidas[widget.action.id] = texto;
    } on PostgrestException catch (e) {
      _erro = e.message;
    } catch (_) {
      _erro = 'Não consegui falar com o servidor. Tente de novo.';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    final feito = AdminActionCard._resolvidas[a.id];
    final id = {'p_id': a.id};
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        border: Border.all(color: const Color(0xFFBFDBFE)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            a.resumo,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          if (!a.pode && (a.motivo ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              a.motivo!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF1F2937)),
            ),
          ],
          const SizedBox(height: 8),
          if (feito != null)
            Text(
              feito,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            )
          else ...[
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  _erro!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (a.pode)
                  AdminPillButton(
                    label: 'Confirmar',
                    onTap: _busy
                        ? null
                        : () => _rodar('admin_action_confirm', id),
                  )
                else
                  for (final ap in a.aprovadores)
                    AdminPillButton(
                      label: 'Pedir a ${ap.nome}',
                      onTap: _busy
                          ? null
                          : () => _rodar('admin_action_request_approval', {
                              ...id,
                              'p_approver': ap.id,
                            }),
                    ),
                AdminPillButton(
                  label: 'Cancelar',
                  color: const Color(0xFF6B7280),
                  onTap: _busy ? null : () => _rodar('admin_action_reject', id),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
