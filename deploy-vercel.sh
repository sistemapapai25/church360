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

cat > "$web_dir/vercel.json" << 'EOF'
{
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
EOF

echo "==> Deploy de producao na Vercel..."
(cd "$web_dir" && vercel deploy --prod --yes)

echo "==> Pronto: https://app.church360.com.br"
