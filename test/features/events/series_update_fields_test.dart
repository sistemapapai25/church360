// Bug `serie-visibilidade-rebaixada` (debug session). O que este arquivo trava
// é a metade NÃO ESPELHADA da correção: `seriesUpdateFields` é o símbolo de
// produção que `_aplicarEdicaoATodaASerie` usa para montar o `p_fields` de
// `public.apply_event_series_update`, e ele é exercitado aqui diretamente.
//
// Por que uma função existe só para isto: o mapa `data` do formulário carrega
// SEMPRE `visibility_scope: 'all'` e `registration_scope: 'all'` (Pitfall 1 —
// a policy `AS RESTRICTIVE FOR SELECT` também é avaliada no
// `INSERT/UPDATE ... RETURNING`, e o escopo final só pode ser promovido depois
// que a audiência existe). Esse literal viajava intacto para a RPC, onde as
// duas colunas NÃO estão na `c_excluded` (`20260902000600:158-163`) e o passo
// (7) é deny-list — o que gravava `'all'` em todo o lote, inclusive na âncora.
// E `'all'` é o primeiro termo do `USING` de `event_visibility_restrict`
// (`20260826000400:104-111`): o curto-circuito que libera a linha para qualquer
// autenticado do tenant sem consultar `event_audience`. Rebaixar era expor.
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/events/presentation/utils/series_update_fields.dart';

/// Uma redução do mapa `data` de `_saveEvent` com o que importa para o
/// contrato: campos comuns + os dois literais de escopo.
Map<String, dynamic> _dataDoFormulario() => <String, dynamic>{
  'name': 'Culto de domingo',
  'description': null,
  'start_date': '2026-09-06T19:30:00.000Z',
  'requires_registration': true,
  'status': 'active',
  // Pitfall 1: o mapa nasce sempre com 'all' nos dois escopos.
  'visibility_scope': 'all',
  'registration_scope': 'all',
};

void main() {
  test(
    'o escopo REAL do formulário substitui o literal "all" do mapa data',
    () {
      final campos = seriesUpdateFields(
        base: _dataDoFormulario(),
        visibilityScope: 'restricted',
        registrationScope: 'restricted',
      );

      expect(campos['visibility_scope'], 'restricted');
      expect(campos['registration_scope'], 'restricted');
    },
  );

  test(
    'restrição só de visibilidade não arrasta a inscrição junto (e vice-versa)',
    () {
      final soVisibilidade = seriesUpdateFields(
        base: _dataDoFormulario(),
        visibilityScope: 'restricted',
        registrationScope: 'all',
      );
      expect(soVisibilidade['visibility_scope'], 'restricted');
      expect(soVisibilidade['registration_scope'], 'all');

      final soInscricao = seriesUpdateFields(
        base: _dataDoFormulario(),
        visibilityScope: 'all',
        registrationScope: 'restricted',
      );
      expect(soInscricao['visibility_scope'], 'all');
      expect(soInscricao['registration_scope'], 'restricted');
    },
  );

  test('série aberta continua "all" nos dois escopos — nada é inventado', () {
    final campos = seriesUpdateFields(
      base: _dataDoFormulario(),
      visibilityScope: 'all',
      registrationScope: 'all',
    );

    expect(campos['visibility_scope'], 'all');
    expect(campos['registration_scope'], 'all');
  });

  test('todos os campos comuns do mapa base são preservados', () {
    final base = _dataDoFormulario();
    final campos = seriesUpdateFields(
      base: base,
      visibilityScope: 'restricted',
      registrationScope: 'restricted',
    );

    // Mesmo conjunto de chaves: a função troca valor, nunca acrescenta nem
    // remove campo — o passo (7) é deny-list e qualquer chave nova viraria
    // coluna gravada em dezenas de linhas.
    expect(campos.keys.toSet(), base.keys.toSet());
    expect(campos['name'], 'Culto de domingo');
    expect(campos['start_date'], '2026-09-06T19:30:00.000Z');
    expect(campos['requires_registration'], true);
    expect(campos['status'], 'active');
    // `null` explícito precisa sobreviver: some-lo faria a descrição apagada
    // pelo líder não ser apagada no lote.
    expect(campos.containsKey('description'), isTrue);
    expect(campos['description'], isNull);
  });

  test(
    'o mapa base NÃO é mutado — o caminho de regeneração depende dele intacto',
    () {
      final base = _dataDoFormulario();

      seriesUpdateFields(
        base: base,
        visibilityScope: 'restricted',
        registrationScope: 'restricted',
      );

      // `_aplicarCamposComunsAposRegeneracao` recebe o MESMO `data` e exclui os
      // dois campos de escopo de propósito. Se esta função mutasse o mapa, o
      // caminho de regeneração passaria a carregar 'restricted' de carona por
      // um efeito colateral invisível.
      expect(base['visibility_scope'], 'all');
      expect(base['registration_scope'], 'all');
    },
  );
}
