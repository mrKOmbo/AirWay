#!/usr/bin/env bash
# AirWay backend · deploy script para atenea.komiia.com
# Uso en el server:  bash deploy.sh
set -euo pipefail

REPO_URL="https://github.com/mrKOmbo/AirWay.git"
REPO_DIR="$HOME/AirWay"
COMPOSE_FILE="backend-api/docker-compose.prod.yml"

echo "▶ AirWay backend deploy"

# 1. Install Docker if missing
if ! command -v docker >/dev/null 2>&1; then
  echo "▶ Instalando Docker..."
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
  echo "⚠ Cierra sesión SSH y vuelve a entrar para que el grupo docker surta efecto."
  echo "   Luego re-ejecuta este script."
  exit 0
fi

# 2. Clone or update repo
if [ ! -d "$REPO_DIR/.git" ]; then
  echo "▶ Clonando repo en $REPO_DIR"
  git clone "$REPO_URL" "$REPO_DIR"
else
  echo "▶ Actualizando repo"
  git -C "$REPO_DIR" fetch origin
  git -C "$REPO_DIR" checkout main
  git -C "$REPO_DIR" pull --ff-only origin main
fi

cd "$REPO_DIR"

# 3. Ensure .env exists
if [ ! -f .env ]; then
  echo "⚠ Falta $REPO_DIR/.env"
  echo "   Crea el archivo con tus secrets (template en .env.prod.example):"
  echo "   cp .env.prod.example .env && nano .env"
  exit 1
fi

# 4. Build & start
echo "▶ Levantando stack con Docker Compose"
docker compose --env-file .env -f "$COMPOSE_FILE" pull || true
docker compose --env-file .env -f "$COMPOSE_FILE" build
docker compose --env-file .env -f "$COMPOSE_FILE" up -d

# 5. Wait for health
echo "▶ Esperando healthcheck..."
for i in $(seq 1 30); do
  if curl -fsS http://localhost:8000/healthz >/dev/null 2>&1; then
    echo "✓ API healthy"
    break
  fi
  sleep 2
  printf "."
done

echo ""
echo "▶ Estado de servicios:"
docker compose --env-file .env -f "$COMPOSE_FILE" ps

echo ""
echo "✓ Deploy listo. Endpoints en http://localhost:8000/"
echo "  Expón con Cloudflare Tunnel → api.atenea.komiia.com → http://localhost:8000"
