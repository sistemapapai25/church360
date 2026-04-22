import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/supabase_constants.dart';

class AppErrorInfo {
  final String userMessage;
  final String debugMessage;
  final String? code;
  final String? details;
  final String? hint;

  const AppErrorInfo({
    required this.userMessage,
    required this.debugMessage,
    this.code,
    this.details,
    this.hint,
  });
}

/// Padroniza erro para:
/// 1) Mensagem amigavel ao usuario
/// 2) Log tecnico (codigo + detalhes) no console
///
/// Objetivo: nunca exibir SQL/stack bruto no app.
class AppErrorHandler {
  static AppErrorInfo map(
    Object error, {
    String? feature,
  }) {
    if (error is PostgrestException) {
      final code = (error.code ?? '').trim();
      final message = error.message.trim();
      final details = error.details?.toString().trim();
      final hint = error.hint?.toString().trim();

      String userMessage;
      switch (code) {
        case '23505': // unique_violation
          userMessage =
              'Esse item ja existe. Verifique os dados e tente novamente.';
          break;
        case '23502': // not_null_violation
          userMessage = 'Preencha os campos obrigatorios e tente novamente.';
          break;
        case '22P02': // invalid_text_representation
          userMessage =
              'Algum dado informado e invalido. Revise e tente novamente.';
          break;
        case '42501': // insufficient_privilege
          userMessage = 'Voce nao tem permissao para realizar esta acao.';
          break;
        case 'PGRST204': // missing column in schema cache
        case '42P01': // undefined_table
        case '42703': // undefined_column
        case '42883': // undefined_function
          userMessage =
              'O sistema esta em atualizacao. Tente novamente em instantes.';
          break;
        case 'PGRST116': // single() requested but returned 0+ rows
          userMessage =
              'Nao foi possivel carregar os dados. Tente novamente.';
          break;
        default:
          userMessage = 'Ocorreu um erro. Tente novamente.';
      }

      return AppErrorInfo(
        userMessage: userMessage,
        debugMessage: message,
        code: code.isEmpty ? null : code,
        details: details?.isEmpty == true ? null : details,
        hint: hint?.isEmpty == true ? null : hint,
      );
    }

    if (error is AuthException) {
      final msg = error.message.trim();
      final normalized = msg.toLowerCase();
      final userMessage = switch (normalized) {
        _ when normalized.contains('jwt') && normalized.contains('expired') =>
          'Sessao expirada. Faca login novamente.',
        _ when normalized.contains('invalid login') ||
                normalized.contains('invalid_credentials') =>
          'Credenciais invalidas. Verifique e tente novamente.',
        _ => 'Falha de autenticacao. Tente novamente.',
      };

      return AppErrorInfo(
        userMessage: userMessage,
        debugMessage: msg,
      );
    }

    if (error is TimeoutException) {
      return const AppErrorInfo(
        userMessage: 'Tempo esgotado. Tente novamente.',
        debugMessage: 'TimeoutException',
      );
    }

    if (error is FormatException) {
      return AppErrorInfo(
        userMessage: 'Dados invalidos. Revise e tente novamente.',
        debugMessage: error.message,
      );
    }

    return AppErrorInfo(
      userMessage: 'Ocorreu um erro. Tente novamente.',
      debugMessage: error.toString(),
    );
  }

  static void log(
    Object error, {
    String? feature,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    final info = map(error, feature: feature);

    final buffer = StringBuffer('[APP_ERROR]');
    if (feature != null && feature.trim().isNotEmpty) {
      buffer.write('[$feature]');
    }

    // Best-effort context for debugging. Must never break the UI.
    try {
      final tenantId = SupabaseConstants.currentTenantId.trim();
      if (tenantId.isNotEmpty) {
        buffer.write(' tenant=$tenantId');
      }
    } catch (_) {}
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null && userId.trim().isNotEmpty) {
        buffer.write(' user=${userId.trim()}');
      }
    } catch (_) {}

    if (info.code != null) {
      buffer.write(' code=${info.code}');
    }
    buffer.write(' message="${info.debugMessage}"');
    if (info.details != null) {
      buffer.write(' details="${info.details}"');
    }
    if (info.hint != null) {
      buffer.write(' hint="${info.hint}"');
    }
    if (context != null && context.isNotEmpty) {
      buffer.write(' ctx=$context');
    }

    debugPrint(buffer.toString());
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  static void showSnackBar(
    BuildContext context,
    Object error, {
    String? feature,
    String? fallbackMessage,
  }) {
    final info = map(error, feature: feature);
    log(error, feature: feature);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(fallbackMessage ?? info.userMessage),
        backgroundColor: Colors.red,
      ),
    );
  }

  static String userMessage(
    Object error, {
    String? feature,
  }) {
    return map(error, feature: feature).userMessage;
  }
}
