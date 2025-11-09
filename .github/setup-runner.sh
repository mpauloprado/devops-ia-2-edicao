#!/bin/bash

#####################################################################
# GitHub Actions Self-Hosted Runner Setup Script
# Para Kali Linux
#
# Este script configura um runner do GitHub Actions no Kali Linux
# para executar pipelines CI/CD localmente
#####################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║   GitHub Actions Self-Hosted Runner Setup                ║
║   Para Kali Linux                                         ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Função para print colorido
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se está rodando como root
if [ "$EUID" -eq 0 ]; then
    print_error "Não execute este script como root!"
    print_info "Execute como usuário normal: ./setup-runner.sh"
    exit 1
fi

# Configurações
RUNNER_VERSION="2.311.0"
RUNNER_DIR="$HOME/actions-runner"

# 1. Verificar dependências
print_info "Verificando dependências..."

if ! command -v git &> /dev/null; then
    print_error "Git não instalado. Instalando..."
    sudo apt update && sudo apt install -y git
fi

if ! command -v docker &> /dev/null; then
    print_warn "Docker não encontrado. Recomendado para builds."
fi

if ! command -v kubectl &> /dev/null; then
    print_warn "kubectl não encontrado. Necessário para deploys K8s."
fi

# 2. Solicitar informações do usuário
print_info "Digite as informações do seu repositório GitHub:"
echo ""

read -p "GitHub Username: " GITHUB_USER
read -p "Repository Name: " REPO_NAME
read -p "GitHub Personal Access Token (com repo scope): " -s GITHUB_TOKEN
echo ""

if [ -z "$GITHUB_USER" ] || [ -z "$REPO_NAME" ] || [ -z "$GITHUB_TOKEN" ]; then
    print_error "Todos os campos são obrigatórios!"
    exit 1
fi

REPO_URL="https://github.com/$GITHUB_USER/$REPO_NAME"

# 3. Criar diretório do runner
print_info "Criando diretório do runner em: $RUNNER_DIR"

if [ -d "$RUNNER_DIR" ]; then
    print_warn "Diretório já existe. Removendo..."
    rm -rf "$RUNNER_DIR"
fi

mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

# 4. Baixar o runner
print_info "Baixando GitHub Actions Runner v$RUNNER_VERSION..."

curl -o actions-runner-linux-x64-$RUNNER_VERSION.tar.gz \
    -L https://github.com/actions/runner/releases/download/v$RUNNER_VERSION/actions-runner-linux-x64-$RUNNER_VERSION.tar.gz

if [ $? -ne 0 ]; then
    print_error "Falha ao baixar o runner!"
    exit 1
fi

# 5. Extrair
print_info "Extraindo arquivos..."
tar xzf ./actions-runner-linux-x64-$RUNNER_VERSION.tar.gz
rm ./actions-runner-linux-x64-$RUNNER_VERSION.tar.gz

# 6. Obter registration token
print_info "Obtendo token de registro..."

REGISTRATION_TOKEN=$(curl -s -X POST \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$GITHUB_USER/$REPO_NAME/actions/runners/registration-token" \
    | grep -o '"token": "[^"]*' | cut -d'"' -f4)

if [ -z "$REGISTRATION_TOKEN" ]; then
    print_error "Falha ao obter token de registro!"
    print_error "Verifique se o PAT tem permissão 'repo' e 'admin:org'"
    exit 1
fi

# 7. Configurar o runner
print_info "Configurando o runner..."

./config.sh --url "$REPO_URL" \
    --token "$REGISTRATION_TOKEN" \
    --name "kali-linux-runner" \
    --work "_work" \
    --labels "self-hosted,linux,x64,kali" \
    --unattended \
    --replace

if [ $? -ne 0 ]; then
    print_error "Falha ao configurar o runner!"
    exit 1
fi

# 8. Perguntar se quer instalar como serviço
echo ""
read -p "Deseja instalar o runner como serviço systemd? (y/n): " INSTALL_SERVICE

if [ "$INSTALL_SERVICE" = "y" ] || [ "$INSTALL_SERVICE" = "Y" ]; then
    print_info "Instalando como serviço..."

    sudo ./svc.sh install
    sudo ./svc.sh start

    print_info "Runner instalado e iniciado como serviço!"
    print_info "Comandos úteis:"
    echo "  - Verificar status: sudo ./svc.sh status"
    echo "  - Parar serviço: sudo ./svc.sh stop"
    echo "  - Iniciar serviço: sudo ./svc.sh start"
    echo "  - Desinstalar: sudo ./svc.sh uninstall"
else
    print_info "Para iniciar o runner manualmente, execute:"
    echo "  cd $RUNNER_DIR && ./run.sh"
fi

# 9. Configurar variáveis de ambiente (opcional)
echo ""
read -p "Deseja configurar variáveis de ambiente? (y/n): " CONFIG_ENV

if [ "$CONFIG_ENV" = "y" ] || [ "$CONFIG_ENV" = "Y" ]; then
    print_info "Configurando variáveis de ambiente..."

    # Criar arquivo .env
    cat > "$RUNNER_DIR/.env" << EOF
# Docker Hub Credentials
DOCKER_USERNAME=SEU_DOCKER_USERNAME_AQUI
DOCKER_PASSWORD=SEU_DOCKER_PASSWORD_AQUI

# Digital Ocean
DIGITALOCEAN_ACCESS_TOKEN=SEU_DO_TOKEN_AQUI

# Kubernetes
K8S_CLUSTER_ID=SEU_CLUSTER_ID_AQUI
EOF

    print_warn "Arquivo .env criado em: $RUNNER_DIR/.env"
    print_warn "IMPORTANTE: Edite este arquivo com suas credenciais reais!"
    print_warn "Execute: nano $RUNNER_DIR/.env"
fi

# 10. Verificar instalação
print_info "Verificando instalação..."

if [ -f "$RUNNER_DIR/.runner" ]; then
    print_info "✅ Runner configurado com sucesso!"
else
    print_error "❌ Falha na configuração do runner!"
    exit 1
fi

# 11. Informações finais
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Configuração Concluída!                                 ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
print_info "Runner instalado em: $RUNNER_DIR"
print_info "Repository: $REPO_URL"
print_info "Labels: self-hosted, linux, x64, kali"
echo ""
print_info "Próximos passos:"
echo "  1. Verifique o runner em: https://github.com/$GITHUB_USER/$REPO_NAME/settings/actions/runners"
echo "  2. Modifique seus workflows para usar: runs-on: self-hosted"
echo "  3. Faça um push e veja o runner em ação!"
echo ""

if [ "$INSTALL_SERVICE" != "y" ] && [ "$INSTALL_SERVICE" != "Y" ]; then
    print_warn "Para iniciar o runner agora, execute:"
    echo "  cd $RUNNER_DIR && ./run.sh"
fi

echo ""
print_info "Para mais informações, veja: .github/CICD-SETUP.md"
echo ""
