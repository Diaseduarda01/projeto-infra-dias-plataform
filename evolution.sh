set -e  

PG_USER="evolution"
PG_PASSWORD="Evolution@2024Secure"
PG_DATABASE="evolution_db"

API_PORT="8081"
API_KEY="SuaChaveSecreta123" 

EVOLUTION_VERSION="latest"

INSTALL_DIR="/opt/evolution-api"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERRO]${NC} $1"; }
log_step()    { echo -e "${BLUE}[STEP]${NC} $1"; }

check_command() {
    command -v "$1" &> /dev/null
}

install_dependencies() {
    log_step "Atualizando sistema e instalando dependências..."
    
    sudo apt update -y && sudo apt upgrade -y
    sudo apt install -y curl
    
    if ! check_command docker; then
        log_info "Instalando Docker..."
        curl -fsSL https://get.docker.com | sh
    else
        log_info "Docker já instalado: $(docker --version)"
    fi
    
    if ! docker compose version &> /dev/null; then
        log_info "Instalando Docker Compose plugin..."
        sudo apt install -y docker-compose-plugin
    else
        log_info "Docker Compose já instalado"
    fi
    
    sudo systemctl start docker
    sudo systemctl enable docker
    
    log_info "Dependências instaladas!"
}

setup_environment() {
    log_step "Configurando ambiente..."
    
    sudo mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    if [ -f "docker-compose.yml" ]; then
        log_warn "Instalação anterior encontrada. Removendo..."
        sudo docker compose down -v 2>/dev/null || true
    fi
    
    log_info "Diretório: $INSTALL_DIR"
}

create_env_file() {
    log_step "Criando arquivo .env..."
    
    sudo tee .env > /dev/null << EOF
# ═══ SERVIDOR ═══
SERVER_TYPE=http
SERVER_PORT=8080
SERVER_URL=http://localhost:${API_PORT}

# ═══ SENTRY ═══
SENTRY_DSN=

# ═══ CORS ═══
CORS_ORIGIN=*
CORS_METHODS=GET,POST,PUT,DELETE
CORS_CREDENTIALS=true

# ═══ LOGS ═══
LOG_LEVEL=ERROR,WARN,DEBUG,INFO,LOG,VERBOSE,DARK,WEBHOOKS
LOG_COLOR=true
LOG_BAILEYS=error

# ═══ INSTÂNCIAS ═══
DEL_INSTANCE=false
DEL_TEMP_INSTANCES=true
CLEAN_STORE_CLEANING_INTERVAL=7200
CLEAN_STORE_MESSAGES=true
CLEAN_STORE_MESSAGE_UP_TO_DAYS=30
CLEAN_STORE_CONTACTS=true
CLEAN_STORE_CHATS=true

# ═══ BANCO DE DADOS ═══
DATABASE_ENABLED=true
DATABASE_PROVIDER=postgresql
DATABASE_CONNECTION_URI=postgresql://${PG_USER}:${PG_PASSWORD}@postgres:5432/${PG_DATABASE}?schema=public
DATABASE_CONNECTION_CLIENT_NAME=evolution_client
DATABASE_SAVE_DATA_INSTANCE=true
DATABASE_SAVE_DATA_NEW_MESSAGE=true
DATABASE_SAVE_MESSAGE_UPDATE=true
DATABASE_SAVE_DATA_CONTACTS=true
DATABASE_SAVE_DATA_CHATS=true
DATABASE_SAVE_DATA_LABELS=true
DATABASE_SAVE_DATA_HISTORIC=true

# ═══ CACHE (Redis) ═══
CACHE_REDIS_ENABLED=true
CACHE_REDIS_URI=redis://redis:6379/0
CACHE_REDIS_PREFIX_KEY=evolution
CACHE_REDIS_SAVE_INSTANCES=false
CACHE_LOCAL_ENABLED=false

# ═══ WEBSOCKET ═══
WEBSOCKET_ENABLED=true
WEBSOCKET_GLOBAL_EVENTS=true

# ═══ WEBHOOKS ═══
WEBHOOK_GLOBAL_ENABLED=false
WEBHOOK_GLOBAL_URL=
WEBHOOK_GLOBAL_WEBHOOK_BY_EVENTS=false
WEBHOOK_EVENTS_QRCODE_UPDATED=true
WEBHOOK_EVENTS_MESSAGES_UPSERT=true
WEBHOOK_EVENTS_MESSAGES_UPDATE=true
WEBHOOK_EVENTS_MESSAGES_DELETE=true
WEBHOOK_EVENTS_SEND_MESSAGE=true
WEBHOOK_EVENTS_CONNECTION_UPDATE=true
WEBHOOK_EVENTS_CALL=true

# ═══ WHATSAPP BUSINESS ═══
WA_BUSINESS_TOKEN_WEBHOOK=evolution
WA_BUSINESS_URL=https://graph.facebook.com
WA_BUSINESS_VERSION=v21.0
WA_BUSINESS_LANGUAGE=pt_BR

# ═══ CLIENTE ═══
CONFIG_SESSION_PHONE_CLIENT=Evolution API
CONFIG_SESSION_PHONE_NAME=Chrome
CONFIG_SESSION_PHONE_VERSION=2.3000.1028950586

# ═══ INTEGRAÇÕES ═══
TYPEBOT_ENABLED=true
TYPEBOT_API_VERSION=latest
CHATWOOT_ENABLED=false
RABBITMQ_ENABLED=false
SQS_ENABLED=false
S3_ENABLED=false

# ═══ AUTENTICAÇÃO ═══
AUTHENTICATION_TYPE=apikey
AUTHENTICATION_API_KEY=${API_KEY}
AUTHENTICATION_EXPOSE_IN_FETCH_INSTANCES=true

# ═══ OUTROS ═══
LANGUAGE=pt-BR
EOF

    log_info "Arquivo .env criado!"
}

create_docker_compose() {
    log_step "Criando docker-compose.yml..."
    
    sudo tee docker-compose.yml > /dev/null << EOF
services:
  # ═══ EVOLUTION API ═══
  api:
    container_name: evolution_api
    image: evoapicloud/evolution-api:${EVOLUTION_VERSION}
    restart: unless-stopped
    ports:
      - "${API_PORT}:8080"
    volumes:
      - evolution_instances:/evolution/instances
      - evolution_store:/evolution/store
    networks:
      - evolution-net
    env_file:
      - .env
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    command: ['node', './dist/src/main.js']

  # ═══ POSTGRESQL ═══
  postgres:
    container_name: evolution_postgres
    image: postgres:15-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${PG_USER}
      POSTGRES_PASSWORD: ${PG_PASSWORD}
      POSTGRES_DB: ${PG_DATABASE}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - evolution-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${PG_USER} -d ${PG_DATABASE}"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ═══ REDIS ═══
  redis:
    container_name: evolution_redis
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - evolution-net
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  evolution_instances:
  evolution_store:
  postgres_data:
  redis_data:

networks:
  evolution-net:
    driver: bridge
EOF

    log_info "docker-compose.yml criado!"
}

start_containers() {
    log_step "Iniciando containers..."
    
    sudo docker system prune -f 2>/dev/null || true
    
    log_info "Baixando imagens Docker..."
    sudo docker compose pull
    
    log_info "Subindo containers..."
    sudo docker compose up -d
    
    log_info "Aguardando serviços iniciarem..."
    sleep 15
}

show_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           ✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!                 ║${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC}                                                                ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  🌐 ${BLUE}API URL:${NC}       http://localhost:${API_PORT}                     ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  🔑 ${BLUE}API Key:${NC}       ${API_KEY}                        ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  📖 ${BLUE}Manager:${NC}       http://localhost:${API_PORT}/manager             ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  📚 ${BLUE}Swagger:${NC}       http://localhost:${API_PORT}/docs                ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                                ${GREEN}║${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC}  ${YELLOW}COMANDOS ÚTEIS:${NC}                                              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Ver logs:    cd $INSTALL_DIR && docker compose logs -f   ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Reiniciar:   cd $INSTALL_DIR && docker compose restart   ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Parar:       cd $INSTALL_DIR && docker compose down      ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    log_step "Status dos containers:"
    sudo docker compose ps
}

main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║          🚀 EVOLUTION API - INSTALADOR AUTOMÁTICO              ║${NC}"
    echo -e "${BLUE}║                     Versão: ${EVOLUTION_VERSION}                              ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    install_dependencies
    setup_environment
    create_env_file
    create_docker_compose
    start_containers
    show_summary
}

main "$@"
