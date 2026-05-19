import 'package:url_launcher/url_launcher.dart';

/// Resultado da tentativa de abrir o WhatsApp via wa.me.
enum WhatsAppLaunchResult {
  /// URL aberta com sucesso.
  launched,

  /// Telefone vazio ou só com caracteres não-numéricos.
  invalidPhone,

  /// Sistema não conseguiu abrir a URL (sem WhatsApp instalado / browser).
  cannotLaunch,
}

/// Abre o WhatsApp do dispositivo via `https://wa.me/<phone>?text=<msg>`.
///
/// Convenção do app é números brasileiros — se o telefone limpo não começar
/// com [defaultCountryCode] (`55` por padrão) e tiver 10-11 dígitos, prepende
/// automaticamente. Telefones já no formato internacional (12+ dígitos
/// começando com `55`) são respeitados como estão.
///
/// `mode: externalApplication` força abrir o app nativo do WhatsApp em vez
/// de in-app browser (UX melhor pra disparar mensagem).
Future<WhatsAppLaunchResult> launchWhatsAppMessage({
  required String? phone,
  String? message,
  String defaultCountryCode = '55',
}) async {
  if (phone == null) return WhatsAppLaunchResult.invalidPhone;
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return WhatsAppLaunchResult.invalidPhone;

  final fullPhone =
      digits.startsWith(defaultCountryCode) && digits.length >= 12
          ? digits
          : '$defaultCountryCode$digits';

  final base = 'https://wa.me/$fullPhone';
  final uri = (message == null || message.trim().isEmpty)
      ? Uri.parse(base)
      : Uri.parse('$base?text=${Uri.encodeComponent(message)}');

  if (!await canLaunchUrl(uri)) {
    return WhatsAppLaunchResult.cannotLaunch;
  }
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  return ok ? WhatsAppLaunchResult.launched : WhatsAppLaunchResult.cannotLaunch;
}
