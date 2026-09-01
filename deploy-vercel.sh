#!/usr/bin/env bash
# Deploy do Church360 (Flutter Web) para a Vercel — app.church360.com.br
# Uso: ./deploy-vercel.sh
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$root"

echo "==> Buildando Flutter web (release)..."
flutter build web --release

web_dir="$root/build/web"
mkdir -p "$web_dir/.vercel"

echo "==> Restaurando link do projeto Vercel (apagado a cada build)..."
cp "$root/.vercel/project.json" "$web_dir/.vercel/project.json"

# LINK-02: NAO gerar vercel.json aqui. A config e versionada em `web/vercel.json` e o
# `flutter build web` a copia para `build/web/vercel.json`. Reescrever o arquivo aqui
# apaga os headers de Content-Type de `.well-known/` e quebra a verificacao de dominio.
#
# A copia abaixo NAO e uma segunda fonte de verdade — e uma garantia de entrega da unica
# fonte (`web/`). Motivo verificado em 2026-09-01: o cache incremental do build system do
# Flutter nao detecta ARQUIVOS NOVOS em `web/`. Num `build/` quente, `web/vercel.json` e
# `web/.well-known/` recem-criados NAO sao copiados e o arquivo antigo sobrevive. Na CI o
# checkout e limpo e o problema nao existe; aqui, na maquina do dev, existe.
echo "==> Garantindo a config versionada e o .well-known em build/web..."
cp "$root/web/vercel.json" "$web_dir/vercel.json"
rm -rf "$web_dir/.well-known"
if [ -d "$root/web/.well-known" ]; then
  cp -R "$root/web/.well-known" "$web_dir/.well-known"
fi

echo "==> Deploy de producao na Vercel..."
(cd "$web_dir" && vercel deploy --prod --yes)

echo "==> Pronto: https://app.church360.com.br"
