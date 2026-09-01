import 'package:flutter/foundation.dart';

import '../constants/supabase_constants.dart';

/// LINK-01 (Fase 2, Plano 02-01): montagem do link compartilhável de qualquer
/// tela do app (evento, inscrição, grupo, reunião, grupo de estudo, post da
/// comunidade).
///
/// O resultado é SEMPRE uma URL absoluta, nas duas plataformas, sem `#` e sem
/// query/fragment herdados da sessão atual.
class ShareLinkUtils {
  static String buildShareUrl(String path) {
    final cleanPath = path.startsWith('/') ? path : '/$path';

    // No web o host vem da própria página (preserva ambientes de preview da
    // Vercel e o localhost do `flutter run -d chrome`); no mobile não existe
    // `Uri.base` útil, então o host sai da constante canônica.
    //
    // Bug corrigido aqui: o ramo mobile devolvia `cleanPath` cru
    // ("/events/<id>"). Quem compartilhava pelo WhatsApp mandava um texto que
    // não era link nenhum — o bug mais visível da fase. O domínio usado é o
    // mesmo que vai para o `assetlinks.json`/AASA dos App Links e Universal
    // Links (Planos 06/07), por isso vem de `SupabaseConstants.appWebBaseUrl` e
    // não de um literal local.
    final base = kIsWeb ? Uri.base : Uri.parse(SupabaseConstants.appWebBaseUrl);

    // Montagem por construção explícita em vez de `base.replace(...)`: em Dart,
    // `replace(query: null, fragment: null)` PRESERVA os valores originais em
    // vez de limpá-los. Passar só os componentes desejados para `Uri(...)` é a
    // única forma de garantir que a query e o fragmento da sessão atual (ex.:
    // `?redirect=`, tokens de auth que o Supabase devolve no fragmento) não
    // vazem para dentro do link enviado no WhatsApp (T-02-02).
    //
    // Não há mais ramo de `base.fragment`: com `usePathUrlStrategy()` ativo
    // (main.dart), `Uri.base` já é path-based, e App Links/Universal Links não
    // verificam fragmento.
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: cleanPath,
    ).toString();
  }
}
