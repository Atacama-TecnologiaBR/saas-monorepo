# SaaS Monorepo

**LastSaaS** (auth, billing, admin) + **BrightBean Studio** (social media management) rodando juntos como um SaaS completo.

## Arquitetura

```
                        ┌─────────────────────────┐
                        │       nginx :80          │
                        └──┬────────┬────────┬─────┘
                           │        │        │
                    /api/  │  /social/│       │ /
                           ▼        ▼        ▼
               ┌──────────────┐ ┌──────────┐ ┌──────────────┐
               │ LastSaaS Go  │ │BrightBean│ │ React SPA    │
               │   :4290      │ │ Django   │ │   :3000      │
               │              │ │  :8000   │ │              │
               └──────┬───────┘ └────┬─────┘ └──────────────┘
                      │              │
                      ▼              ▼
               ┌──────────┐  ┌──────────────┐
               │ MongoDB  │  │  PostgreSQL  │
               └──────────┘  └──────────────┘
```

### Fluxo de autenticação (SSO)

1. Usuário faz login no React (LastSaaS) → recebe JWT
2. Clica em **Social Media** no nav
3. React redireciona para `/social/sso/?token=<jwt>`
4. Django valida o JWT com a mesma chave `JWT_ACCESS_SECRET`
5. Django cria sessão local e redireciona ao dashboard do BrightBean

## Início rápido

```bash
git clone <este-repo>
cd saas-monorepo
chmod +x setup.sh
./setup.sh
```

Acesse: **http://localhost**

## Estrutura

```
saas-monorepo/
├── lastsaas/          # SaaS infrastructure (Go + React)
├── brightbean/        # Social media product (Django + HTMX)
├── nginx/
│   └── nginx.conf     # Reverse proxy unificado
├── docker-compose.yml # Orquestração de todos os serviços
├── .env.example       # Variáveis de ambiente (copie para .env)
└── setup.sh           # Script de inicialização
```

## Variáveis de ambiente importantes

| Variável | Usado por | Descrição |
|---|---|---|
| `JWT_ACCESS_SECRET` | Go + Django | **Compartilhada** — assina/valida tokens SSO |
| `MONGODB_URI` | Go | Banco do LastSaaS |
| `DATABASE_URL` | Django | Banco do BrightBean (auto-configurado) |
| `STRIPE_SECRET_KEY` | Go | Billing (opcional) |
| `RESEND_API_KEY` | Go | Envio de e-mails |

## Comandos úteis

```bash
# Subir tudo
docker compose up -d

# Ver logs
docker compose logs -f lastsaas
docker compose logs -f brightbean

# Migrations do Django
docker compose run --rm brightbean python manage.py migrate

# Criar superuser Django (acesso ao /admin do BrightBean)
docker compose run --rm brightbean python manage.py createsuperuser

# Parar tudo
docker compose down
```

## Licenças

- **LastSaaS**: MIT
- **BrightBean Studio**: AGPL-3.0
