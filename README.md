# infra — Composes, RabbitMQ, Evolution e Terraform

Tudo o que **não é código de aplicação**: orquestração local de desenvolvimento, definição de topologia RabbitMQ, script de instalação da Evolution API e provisionamento de produção (Terraform).

## Estrutura

```
infra/
├── docker-compose.dev.yml          # stack de dev (Postgres, MySQL, RabbitMQ, etc.)
├── rabbitmq/
│   ├── rabbitmq.conf               # load_definitions = ...
│   └── definitions.json            # topologia (exchanges, filas, bindings, DLX)
├── evolution.sh                    # bootstrap da Evolution API em servidor dedicado
└── terraform/
    ├── main.tf                     # módulos: networking, ecr, client-instance (por tenant)
    ├── providers.tf / backend.tf
    ├── variables.tf / outputs.tf
    ├── terraform.tfvars.example
    └── clients/
        ├── bronze.tfvars.example
        ├── platinum.tfvars.example
        └── gold.tfvars.example
```

## Dev — subindo a stack

```bash
cd infra
docker compose -f docker-compose.dev.yml up -d
```

O compose sobe **uma única instância** de cada dependência compartilhada (sem isolamento por tenant — isso é só para desenvolvimento):

| Serviço | Porta host | UI / nota |
|---|---|---|
| `postgres` | 5433 | banco `atendimentos` |
| `mysql` | 3306 | banco `chatbot_db` (schema inicial via `ms-database/`) |
| `erp-db-init` | — | roda `prisma migrate deploy` + seed e sai |
| `rabbitmq` | 5672 / 15672 | management UI em http://localhost:15672 (guest/guest) |

> Quando precisar adicionar `ms-erp-api`, `ms-erp-app`, `ms-chatbot`, etc. ao compose de dev: cada um deve ler `RABBITMQ_URL=amqp://guest:guest@rabbitmq:5672` e usar o hostname interno do compose.

## RabbitMQ — topologia

`rabbitmq.conf` apenas faz `load_definitions = /etc/rabbitmq/definitions.json`. O JSON declara:

- Exchange `erp.events` (topic) — barramento principal
- Exchange `erp.dlx` (fanout) — dead-letter
- 9 filas de domínio (notificacao.*, financeiro.*, erp.*, files.*)
- 9 DLQs (`*.dlq`) com TTL de 24h

A **fonte de verdade lógica** está em `ms-rabbitmq/src/messaging/topology.ts`. Qualquer alteração ali deve ser refletida aqui (e vice-versa). Endpoint `/health/topology` do `ms-rabbitmq` valida runtime.

## Evolution API (planos Gold)

`evolution.sh` instala/configura a Evolution API em uma VPS dedicada por cliente (PostgreSQL próprio + Redis + porta 8081 + API key). Edite as variáveis no topo do script antes de executar — **nunca commitar API key real**.

## Terraform — produção

Cada cliente vira uma instância de `module "client"` em `main.tf`, parametrizada pelo arquivo de tfvars correspondente ao plano (`clients/<plano>.tfvars.example`). Para um novo cliente:

```bash
cd infra/terraform
cp clients/gold.tfvars.example clients/<cliente-slug>.tfvars
# edite domínio, slug, plano, etc.
terraform init
terraform plan -var-file=clients/<cliente-slug>.tfvars
terraform apply -var-file=clients/<cliente-slug>.tfvars
```

Recursos provisionados:
- VPC + subnets + security groups (módulo `networking`)
- ECR por microserviço (módulo `ecr`)
- EC2 + Nginx + DNS por tenant (módulo `client-instance`)

## Próximos itens (do TODO)

- `docker-compose.basic.yml` · `docker-compose.bronze.yml` · `docker-compose.platinum.yml` · `docker-compose.gold.yml` — composes por plano (hoje só existe `docker-compose.dev.yml`)
- `nginx/cliente.conf.template` — template de proxy por tenant (SSL, proxy_pass por container)
- `.github/workflows/ci.yml` — pipeline lint → test → build → deploy
