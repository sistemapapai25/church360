import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/supabase_constants.dart';

class AppErrorInfo {
  final String userMessage;
  final String debugMessage;
  final String? code;
  final String? details;
  final String? hint;

  /// true quando [userMessage] já é uma mensagem específica e confiável
  /// (violação conhecida, sessão expirada, exceção de domínio escrita à mão
  /// etc.). Quando false, [userMessage] é só o texto genérico de último
  /// recurso e telas podem preferir seu próprio `fallbackMessage`.
  final bool specific;

  const AppErrorInfo({
    required this.userMessage,
    required this.debugMessage,
    this.code,
    this.details,
    this.hint,
    this.specific = false,
  });
}

/// Padroniza erro para:
/// 1) Mensagem amigável ao usuário
/// 2) Log técnico (código + detalhes) no console
///
/// Objetivo: nunca exibir SQL/stack bruto no app.
class AppErrorHandler {
  static AppErrorInfo map(Object error, {String? feature}) {
    if (error is PostgrestException) {
      final code = (error.code ?? '').trim();
      final message = error.message.trim();
      final details = error.details?.toString().trim();
      final hint = error.hint?.toString().trim();

      String userMessage;
      bool specific = true;
      switch (code) {
        case '23505': // unique_violation
          final msgLower = message.toLowerCase();
          final detailsLower = (details ?? '').toLowerCase();
          final haystack = '$msgLower $detailsLower';
          if (haystack.contains('categories_unique_name')) {
            userMessage =
                'Já existe uma categoria com esse nome. Selecione a existente ou use um nome diferente.';
          } else if (haystack.contains('beneficiaries_unique_name')) {
            userMessage =
                'Já existe um beneficiário com esse nome. Selecione o existente ou use um nome diferente.';
          } else if (haystack.contains('contas_financeiras') ||
              haystack.contains('unique') && haystack.contains('conta')) {
            userMessage =
                'Já existe uma conta com esse nome. Selecione a existente ou use um nome diferente.';
          } else {
            userMessage =
                'Esse item já existe. Verifique os dados e tente novamente.';
          }
          break;
        case '23502': // not_null_violation
          userMessage = 'Preencha os campos obrigatórios e tente novamente.';
          break;
        case '22P02': // invalid_text_representation
          userMessage =
              'Algum dado informado é inválido. Revise e tente novamente.';
          break;
        case '42501': // insufficient_privilege
          userMessage = 'Você não tem permissão para realizar esta ação.';
          break;
        case 'PGRST204': // missing column in schema cache
        case '42P01': // undefined_table
        case '42703': // undefined_column
        case '42883': // undefined_function
          userMessage =
              'O sistema está em atualização. Tente novamente em instantes.';
          break;
        case 'CR001': // K6: ficha limpa, quem inclui vê o motivo
        case 'CR002': // K6: ficha limpa, "existe uma pendência"
          userMessage = message;
          break;
        case 'PGRST116': // single() requested but returned 0+ rows
          userMessage = 'Não foi possível carregar os dados. Tente novamente.';
          break;
        default:
          userMessage = 'Ocorreu um erro. Tente novamente.';
          specific = false;
      }

      return AppErrorInfo(
        userMessage: userMessage,
        debugMessage: message,
        code: code.isEmpty ? null : code,
        details: details?.isEmpty == true ? null : details,
        hint: hint?.isEmpty == true ? null : hint,
        specific: specific,
      );
    }

    if (error is AuthException) {
      final msg = error.message.trim();
      final normalized = msg.toLowerCase();
      final userMessage = switch (normalized) {
        _ when normalized.contains('jwt') && normalized.contains('expired') =>
          'Sessão expirada. Faça login novamente.',
        _
            when normalized.contains('invalid login') ||
                normalized.contains('invalid_credentials') =>
          'E-mail ou senha incorretos. Verifique e tente novamente.',
        _ when normalized.contains('email not confirmed') =>
          'Confirme seu e-mail antes de entrar: abra o link que enviamos '
              'na sua caixa de entrada (veja também o spam).',
        _ when normalized.contains('already registered') =>
          'Este e-mail já tem conta. Entre com sua senha ou use '
              '"Esqueci minha senha".',
        _ when normalized.contains('password should be') =>
          'A senha precisa ter pelo menos 6 caracteres.',
        _
            when normalized.contains('rate limit') ||
                normalized.contains('security purposes') =>
          'Muitas tentativas seguidas. Aguarde alguns minutos e tente de novo.',
        _ => 'Falha de autenticação. Tente novamente.',
      };

      return AppErrorInfo(
        userMessage: userMessage,
        debugMessage: msg,
        specific: true,
      );
    }

    if (error is TimeoutException) {
      return const AppErrorInfo(
        userMessage: 'Tempo esgotado. Tente novamente.',
        debugMessage: 'TimeoutException',
        specific: true,
      );
    }

    if (error is FormatException) {
      return AppErrorInfo(
        userMessage: 'Dados inválidos. Revise e tente novamente.',
        debugMessage: error.message,
        specific: true,
      );
    }

    if (error is Exception) {
      // Exceções de domínio lançadas à mão nos repositórios (ex.: "Sem
      // permissão para editar este membro") já trazem uma mensagem em
      // português pronta para o usuário — preservar em vez de mascarar.
      final raw = error.toString();
      const prefix = 'Exception: ';
      final msg = raw.startsWith(prefix) ? raw.substring(prefix.length) : raw;
      if (msg.trim().isNotEmpty) {
        return AppErrorInfo(
          userMessage: msg.trim(),
          debugMessage: msg.trim(),
          specific: true,
        );
      }
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
    // Mensagens especificas (violacao de unicidade, RLS/permissao, sessao
    // expirada, excecoes de dominio, etc.) sempre prevalecem: o
    // fallbackMessage generico da tela so e usado quando o erro nao pode
    // ser identificado, para nao mascarar a causa real do problema.
    final text = info.specific
        ? info.userMessage
        : (fallbackMessage ?? info.userMessage);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text), backgroundColor: Colors.red));
  }

  /// K6 (ficha limpa): trata o bloqueio do banco ao incluir alguém num
  /// ministério que exige ficha limpa. `CR001` (quem inclui tem a permissão)
  /// abre um popup com o motivo; `CR002` mostra só a pendência e avisa o
  /// pastor. Devolve false quando o erro é outro.
  static Future<bool> handleCleanRecordBlock(
    BuildContext context,
    Object error,
  ) async {
    if (error is! PostgrestException) return false;
    final code = error.code;
    if (code != 'CR001' && code != 'CR002') return false;
    if (code == 'CR002') {
      try {
        final d = jsonDecode(error.details?.toString() ?? '');
        await Supabase.instance.client.rpc(
          'background_check_flag_pending',
          params: {'p_user': d['user_id'], 'p_ministry_id': d['ministry_id']},
        );
      } catch (e) {
        debugPrint('[K6] aviso ao pastor não saiu: $e');
      }
    }
    if (!context.mounted) return true;
    if (code == 'CR001') {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.gpp_maybe_outlined, color: Colors.red),
          title: const Text('Ficha limpa'),
          content: Text(error.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.orange),
      );
    }
    return true;
  }

  static String userMessage(Object error, {String? feature}) {
    return map(error, feature: feature).userMessage;
  }
}
