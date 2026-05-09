#!/usr/bin/env bash
set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════╗"
echo "║        SaaS Monorepo — Setup Inicial         ║"
echo "║  LastSaaS (auth/billing) + BrightBean (social)║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

# ── 1. Verificar dependências ──────────────────────────────────────────────────
echo -e "${BLUE}[1/5] Verificando dependências...${NC}"

check_cmd() {
  if ! command -v "$1" &>/dev/null; then
    echo -e "${RED}  ✗ '$1' não encontrado. Instale-o e tente novamente.${NC}"
    exit 1
  fi
  echo -e "${GREEN}  ✓ $1${NC}"
}

check_cmd docker
check_cmd "docker compose" 2>/dev/null || check_cmd docker-compose

# ── 2. Criar .env a partir do exemplo ─────────────────────────────────────────
echo -e "\n${BLUE}[2/5] Configurando variáveis de ambiente...${NC}"

if [ -f .env ]; then
  echo -e "${YELLOW}  .env já existe — pulando (delete-o para recriar)${NC}"
else
  cp .env.example .env

  # Gerar segredos automaticamente (openssl ou python)
  if command -v openssl &>/dev/null; then
    JWT_ACCESS=$(openssl rand -hex 32)
    JWT_REFRESH=$(openssl rand -hex 32)
    WEBHOOK_KEY=$(openssl rand -hex 32)
    DJANGO_KEY=$(openssl rand -hex 50)
  else
    JWT_ACCESS=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    JWT_REFRESH=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    WEBHOOK_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    DJANGO_KEY=$(python3 -c "import secrets; print(secrets.token_hex(50))")
  fi

  # Substituir placeholders
  sed -i "s|CHANGE_ME_generate_with_openssl_rand_hex_32$|${JWT_ACCESS}|" .env
  sed -i "s|CHANGE_ME_generate_with_openssl_rand_hex_32_other$|${JWT_REFRESH}|" .env
  sed -i "s|CHANGE_ME_generate_with_openssl_rand_hex_32_other2|${WEBHOOK_KEY}|" .env
  sed -i "s|CHANGE_ME_generate_with_python_secrets_token_hex_50|${DJANGO_KEY}|" .env

  echo -e "${GREEN}  ✓ .env criado com segredos gerados automaticamente${NC}"
  echo -e "${YELLOW}  ⚠  Edite .env e preencha: APP_NAME, RESEND_API_KEY, STRIPE_* (opcional)${NC}"
fi

# ── 3. Copiar config do LastSaaS ──────────────────────────────────────────────
echo -e "\n${BLUE}[3/5] Preparando configuração do LastSaaS...${NC}"

if [ ! -f lastsaas/backend/config/dev.yaml ]; then
  cp lastsaas/backend/config/dev.example.yaml lastsaas/backend/config/dev.yaml
  echo -e "${GREEN}  ✓ dev.yaml criado${NC}"
else
  echo -e "${YELLOW}  dev.yaml já existe — pulando${NC}"
fi

# ── 4. Build das imagens ───────────────────────────────────────────────────────
echo -e "\n${BLUE}[4/5] Construindo imagens Docker...${NC}"
docker compose build --parallel
echo -e "${GREEN}  ✓ Imagens construídas${NC}"

# ── 5. Subir serviços e inicializar ───────────────────────────────────────────
echo -e "\n${BLUE}[5/5] Iniciando serviços...${NC}"
docker compose up -d mongodb postgres
echo "  Aguardando bancos de dados ficarem prontos..."
sleep 8

# Migrations do BrightBean
echo "  Rodando migrations do BrightBean (Django)..."
docker compose run --rm brightbean python manage.py migrate --no-input

# Inicializar LastSaaS (cria tenant root + admin)
echo "  Inicializando LastSaaS..."
docker compose run --rm lastsaas /app/lastsaas setup || true

# Subir tudo
docker compose up -d

echo -e "\n${GREEN}╔══════════════════════════════════════════╗"
echo "║           Monorepo no ar!                ║"
echo "╠══════════════════════════════════════════╣"
echo "║  Frontend + SaaS:  http://localhost      ║"
echo "║  Social Media:     http://localhost/social/║"
echo "║  API (Go):         http://localhost/api/ ║"
echo -e "╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Próximos passos:${NC}"
echo "  1. Acesse http://localhost e crie sua conta"
echo "  2. No nav, clique em 'Social Media' para abrir o BrightBean"
echo "  3. Edite .env para configurar Stripe, redes sociais, etc."
echo ""
