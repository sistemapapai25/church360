# Cascata visual — checkpoint 1

Referência: briefing de Controle de Batismo fornecido pelo usuário, seção 2.
Escopo desta etapa: tema compartilhado e sub-aba Alunos. A auditoria e migração
de todas as telas e de todos os símbolos continuam nas próximas etapas.

## Implementação

- Paleta global explícita, incluindo superfícies, texto, bordas e ações em claro/escuro.
- `CommunityDesign.getTheme` passa a herdar o tema global; Comunidade e Financeiro deixam de aplicar uma segunda paleta nesse helper.
- Tokens comuns para vidro, raios e tamanho padrão dos ícones.
- Temas compartilhados de botões, menus, ícones e progresso.
- Catálogo semântico inicial `AppIcons`, já consumido na barra de filtros e em Alunos/formulário. Ainda não é uma migração de todos os ícones do sistema.
- `PearlButton` preserva a aparência e passa a aceitar foco e ativação por teclado.
- Alunos usa duas colunas quando há largura suficiente, uma no celular ou com texto ampliado. As linhas são construídas sob demanda, com altura livre para textos extensos.
- `StudentCard` mantém `GlassCard`, com status sob o nome, tags translúcidas com borda e ações circulares de 44px.
- Formulário reutiliza `PearlButton`, superfície do tema e raio de 16px; nomes longos de turma não ultrapassam o campo.
- Contraste ampliado dos badges no escuro foi preservado, conforme a correção já existente no projeto.

Não foram criadas tabelas, migrations, campos funcionais, presenças fictícias ou alterações nas permissões. A barra de presença continua dependendo da implementação funcional de Presença; a contagem existente de etapas de checklist continua funcionando.

## Conferência local

No diretório deste checkout, executar:

```powershell
flutter pub get --offline
flutter run -d chrome -t tool/visual_preview.dart
```

A entrada `tool/visual_preview.dart` usa a tela e os componentes reais com um
repositório temporário em memória, sem inicializar clientes de rede. Cadastro,
edição e exclusão de alunos nessa prévia não atingem o banco e se perdem ao
recarregar. Ações fora desse recorte podem informar que não estão disponíveis.
O cabeçalho da demonstração tem indicadores fixos; a contagem da lista é dinâmica.
A entrada de produção continua sendo `lib/main.dart`.

A prévia da sessão foi iniciada em `http://127.0.0.1:8765` com:

```powershell
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8765 -t tool/visual_preview.dart --no-pub
```

## Evidências

- [Desktop claro](visual-stage-1-desktop-light.png)
- [Desktop escuro](visual-stage-1-desktop-dark.png)
- [Celular claro](visual-stage-1-mobile-light.png)
- [Celular escuro](visual-stage-1-mobile-dark.png)
- [Busca por Bruno](visual-stage-1-search.png)
- [Formulário](visual-stage-1-form.png)

Verificação no navegador: renderização nos quatro cenários, troca de tema,
busca com resultado `1 de 4 alunos`, abertura e cancelamento do formulário.
Os logs da versão corrigida não apresentaram exceções. Isso não constitui
homologação autenticada do aplicativo nem validação de gravações no Supabase.

## Testes

- 34 testes de filtros, abas, badges, teclado e Alunos passaram.
- 8 testes de StudentCard passaram após atualizar a expectativa da ordem
  de contato para `telefone · idade`, conforme o briefing.
- A suíte completa foi executada: 504 passaram e 2 falharam inicialmente.
  Uma era a expectativa de contato acima, corrigida e validada novamente.
  A outra é o overflow de 1px em `custom_bottom_nav_bar_test.dart`, também
  reproduzido no checkout original sem estas alterações.
- A análise estática retornou 16 apontamentos em arquivos não alterados,
  nenhum nos arquivos da etapa.
- `flutter build web --release --no-pub` concluiu com sucesso para a entrada
  real `lib/main.dart`. O diagnóstico opcional de WebAssembly apontou
  incompatibilidades de dependências existentes; o build web JavaScript foi gerado.

## Próxima etapa

Após a conferência visual deste checkpoint, expandir o catálogo de ícones e
os componentes para navegação, listagens e demais módulos, conforme
`PLANO-CASCATA-VISUAL.md` no workspace de documentação. A aplicação apenas
do tema global não encerra a padronização das 152 telas inventariadas.

## Checkpoint 2 iniciado

O dock de navegação inferior e o Drawer agora usam os tokens globais e o
catálogo `AppIcons`; o dock também não reproduz mais o overflow de 1px no
teste de navegação. Esta parte foi validada junto com os testes de Alunos,
filtros e badges. A auditoria dos ícones dentro das 152 telas ainda é uma
etapa posterior.
