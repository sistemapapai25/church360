#!/usr/bin/env bash
# Confere se toda rota do app_router.dart tem entrada no mapa do suporte (screen-map.ts do church360-supabase).
# Uso: bash tool/check_support_map.sh <caminho/do/screen-map.ts>
set -euo pipefail
map="$1"
router="lib/core/navigation/app_router.dart"

# Sem caminho de toque (abertura, login, link de e-mail) ou só redireciona para outra rota mapeada.
ignore='^/$|^/splash$|^/reset-password$|^/bible$|^/study-groups$'

# Parâmetros (:id, ids reais, <id>, {id}) viram :x dos dois lados.
norm() { sed -E 's#/:[^/]+#/:x#g; s#/[0-9a-f-]{8,}#/:x#g; s#<[^>]+>#:x#g; s#\{[^}]+\}#:x#g' | sort -u; }

# Rota filha (path relativo) herda o path absoluto anterior: '/financial' + 'contas' = '/financial/contas'.
app_routes=$(awk -v q="'" '
  match($0, "path: *" q "[^" q "]*" q) {
    p = substr($0, RSTART, RLENGTH); sub("path: *" q, "", p); sub(q "$", "", p)
    if (p ~ /^\//) { parent = p; print p } else { print parent "/" p }
  }' "$router" | grep -vE "$ignore" | norm)

map_routes=$(grep -oE 'route: *"[^"]+"' "$map" | sed -E 's/route: *"//; s/"$//; s/\?.*//' | norm)

missing=$(comm -23 <(echo "$app_routes") <(echo "$map_routes"))
if [ -n "$missing" ]; then
  echo "::error::Rotas do app sem entrada no mapa do suporte (functions/support-chat/screen-map.ts):"
  echo "$missing"
  echo "Adicione cada uma ao screen-map.ts num PR do church360-supabase e cite church360-supabase#N na descrição deste PR."
  exit 1
fi
echo "Mapa do suporte em dia: $(echo "$app_routes" | wc -l) rotas conferidas."
