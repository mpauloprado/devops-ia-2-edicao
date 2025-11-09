# 🚀 CI/CD Pipeline - Setup Guide

Este guia explica como configurar o pipeline CI/CD no GitHub Actions para os projetos DevOps IA.

## 📋 Índice

- [Workflows Criados](#workflows-criados)
- [Configurar Secrets no GitHub](#configurar-secrets-no-github)
- [Como Funciona o Pipeline](#como-funciona-o-pipeline)
- [Conectar Kali Linux ao Pipeline](#conectar-kali-linux-ao-pipeline)
- [Triggers e Eventos](#triggers-e-eventos)
- [Troubleshooting](#troubleshooting)

---

## 🔧 Workflows Criados

### 1. Encontros Tech CI/CD
**Arquivo**: `.github/workflows/encontros-tech-cicd.yaml`

**Stages**:
1. **Test**: Executa testes com pytest
2. **Build**: Constrói imagem Docker e faz push para Docker Hub
3. **Deploy**: Faz deploy no cluster Kubernetes (Digital Ocean)
4. **Notify**: Notifica status do deployment

**Triggers**:
- Push em `main` ou `develop` (pasta `02-encontros-tech/**`)
- Pull Request para `main`
- Manual via `workflow_dispatch`

---

### 2. Conversão Distância CI/CD
**Arquivo**: `.github/workflows/conversao-distancia-cicd.yaml`

**Stages**:
1. **Test**: Executa testes com pytest
2. **Build**: Constrói imagem Docker e faz push para Docker Hub
3. **Notify**: Notifica status do build

**Triggers**:
- Push em `main` ou `develop` (pasta `01-conversao-distancia/**`)
- Pull Request para `main`
- Manual via `workflow_dispatch`

---

## 🔐 Configurar Secrets no GitHub

### Passo 1: Acessar Settings
1. Vá para o repositório no GitHub
2. Clique em **Settings** → **Secrets and variables** → **Actions**
3. Clique em **New repository secret**

### Passo 2: Adicionar Secrets

#### Secrets Obrigatórios:

| Secret Name | Descrição | Como Obter |
|------------|-----------|------------|
| `DOCKER_USERNAME` | Username do Docker Hub | Seu username (ex: `marcospaulo1991`) |
| `DOCKER_PASSWORD` | Senha ou Token do Docker Hub | Senha da sua conta ou Personal Access Token |
| `DIGITALOCEAN_ACCESS_TOKEN` | Token de acesso da Digital Ocean | https://cloud.digitalocean.com/account/api/tokens |
| `K8S_CLUSTER_ID` | ID do cluster Kubernetes | `dae9c6bb-913f-4f25-b601-101b14fed97f` |

#### Como adicionar cada secret:

**1. DOCKER_USERNAME**
```
Name: DOCKER_USERNAME
Secret: SEU_DOCKER_USERNAME_AQUI
```

**2. DOCKER_PASSWORD**
```
Name: DOCKER_PASSWORD
Secret: SEU_DOCKER_PASSWORD_AQUI
```
> ⚠️ **Recomendado**: Use um Personal Access Token em vez da senha
> - Acesse: https://hub.docker.com/settings/security
> - Crie um novo token
> - Use o token como DOCKER_PASSWORD

**3. DIGITALOCEAN_ACCESS_TOKEN**
```
Name: DIGITALOCEAN_ACCESS_TOKEN
Secret: SEU_TOKEN_DIGITALOCEAN_AQUI
```

**4. K8S_CLUSTER_ID**
```
Name: K8S_CLUSTER_ID
Secret: SEU_CLUSTER_ID_AQUI
```

---

## 🔄 Como Funciona o Pipeline

### Workflow: Encontros Tech

```
┌─────────────────┐
│  Push to main   │
│  (02-encontros  │
│    -tech/**)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Run Tests     │
│   (pytest)      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Build Docker   │
│  Push to Hub    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Deploy to K8s    │
│ (Digital Ocean) │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    Verify &     │
│    Notify       │
└─────────────────┘
```

### Detalhes de cada Stage:

**1. Test**
- Instala Python 3.11
- Instala dependências do `requirements.txt`
- Executa `pytest tests/`
- Se falhar, o pipeline para

**2. Build**
- Faz build da imagem Docker
- Cria tags:
  - `latest` (se branch main)
  - `main-<commit-sha>` (com hash do commit)
  - `<branch-name>` (nome da branch)
- Push para Docker Hub
- Usa cache para otimizar builds

**3. Deploy** (só em `main`)
- Conecta no cluster Kubernetes via `doctl`
- Atualiza a imagem do deployment
- Aguarda rollout completar (max 5min)
- Verifica se pods estão rodando
- Testa se aplicação responde

**4. Notify**
- Mostra status do deployment
- Exibe URL da aplicação

---

## 💻 Conectar Kali Linux ao Pipeline

### Opção 1: Self-Hosted Runner (Recomendado para CI/CD local)

#### 1. Instalar Runner no Kali Linux

```bash
# Criar diretório para o runner
mkdir -p ~/actions-runner && cd ~/actions-runner

# Baixar o runner
curl -o actions-runner-linux-x64-2.311.0.tar.gz \
  -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz

# Extrair
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# Configurar o runner
./config.sh --url https://github.com/SEU_USUARIO/SEU_REPO \
  --token SEU_TOKEN_DO_GITHUB
```

#### 2. Obter Token do GitHub
1. Vá em: `https://github.com/SEU_USUARIO/SEU_REPO/settings/actions/runners/new`
2. Copie o token gerado
3. Use no comando `./config.sh` acima

#### 3. Instalar como Serviço

```bash
# Instalar como serviço systemd
sudo ./svc.sh install

# Iniciar o serviço
sudo ./svc.sh start

# Verificar status
sudo ./svc.sh status
```

#### 4. Modificar Workflow para usar Self-Hosted

Edite o workflow e adicione:
```yaml
jobs:
  build:
    runs-on: self-hosted  # Mude de ubuntu-latest para self-hosted
```

---

### Opção 2: Webhook para Deploy Local

Criar um webhook que escuta eventos do GitHub e executa deploy local.

#### 1. Criar Script de Deploy

```bash
#!/bin/bash
# ~/deploy-webhook.sh

PROJECT=$1
BRANCH=$2

echo "Deploying $PROJECT from branch $BRANCH"

cd /home/kali/Downloads/devops-ia-2-edicao-main/$PROJECT

# Pull latest changes
git pull origin $BRANCH

# Build and deploy
docker-compose down
docker-compose build
docker-compose up -d

echo "Deploy completed!"
```

#### 2. Instalar Webhook Server

```bash
# Instalar webhook
sudo apt install webhook -y

# Criar configuração
cat > ~/webhook-config.json <<EOF
[
  {
    "id": "deploy-encontros-tech",
    "execute-command": "/home/kali/deploy-webhook.sh",
    "command-working-directory": "/home/kali",
    "pass-arguments-to-command": [
      {
        "source": "payload",
        "name": "repository.name"
      },
      {
        "source": "payload",
        "name": "ref"
      }
    ],
    "trigger-rule": {
      "match": {
        "type": "payload-hash-sha256",
        "secret": "SEU_SECRET_AQUI",
        "parameter": {
          "source": "header",
          "name": "X-Hub-Signature-256"
        }
      }
    }
  }
]
EOF

# Iniciar webhook
webhook -hooks ~/webhook-config.json -verbose -port 9000
```

#### 3. Configurar Webhook no GitHub

1. Vá em: `https://github.com/SEU_USUARIO/SEU_REPO/settings/hooks`
2. Clique em **Add webhook**
3. Configure:
   - **Payload URL**: `http://SEU_IP:9000/hooks/deploy-encontros-tech`
   - **Content type**: `application/json`
   - **Secret**: SEU_SECRET_AQUI
   - **Events**: Push events

---

## 🎯 Triggers e Eventos

### Quando o Pipeline Executa

#### Encontros Tech:
- ✅ Push em `main` → Build + Deploy
- ✅ Push em `develop` → Build (sem deploy)
- ✅ Pull Request para `main` → Apenas testes
- ✅ Manual (workflow_dispatch) → Build + Deploy
- ❌ Push em outras pastas → Não executa

#### Conversão Distância:
- ✅ Push em `main` → Build
- ✅ Push em `develop` → Build
- ✅ Pull Request para `main` → Apenas testes
- ✅ Manual (workflow_dispatch) → Build

### Executar Manualmente

1. Vá em: **Actions** no GitHub
2. Selecione o workflow desejado
3. Clique em **Run workflow**
4. Escolha a branch
5. Clique em **Run workflow**

---

## 🐛 Troubleshooting

### Pipeline Falha no Build

**Erro**: `Error: buildx failed with: ERROR: failed to solve`

**Solução**:
```bash
# Verificar Dockerfile
cd 02-encontros-tech
docker build -t test .
```

---

### Pipeline Falha no Deploy

**Erro**: `Error from server (NotFound): deployments.apps "encontros-tech" not found`

**Solução**:
```bash
# Aplicar manifesto manualmente primeiro
kubectl apply -f 02-encontros-tech/k8s/deployment.yaml
```

---

### Secrets Não Funcionam

**Erro**: `Error: Username and password required`

**Solução**:
1. Verifique se secrets estão configurados em: `Settings → Secrets and variables → Actions`
2. Nomes devem ser exatamente: `DOCKER_USERNAME`, `DOCKER_PASSWORD`, etc.
3. Não use `${{ secrets.NOME }}` em lugares públicos (logs, etc.)

---

### Rollout Timeout

**Erro**: `error: timed out waiting for the condition`

**Solução**:
```bash
# Verificar pods
kubectl get pods

# Ver logs
kubectl logs -f deployment/encontros-tech

# Verificar eventos
kubectl get events --sort-by='.lastTimestamp'
```

---

## 📚 Recursos Adicionais

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Build Push Action](https://github.com/docker/build-push-action)
- [DigitalOcean doctl](https://docs.digitalocean.com/reference/doctl/)
- [Kubernetes kubectl](https://kubernetes.io/docs/reference/kubectl/)

---

## 🎉 Quick Start

### Para começar agora:

```bash
# 1. Configure os secrets no GitHub (veja seção acima)

# 2. Faça um commit e push
cd /home/kali/Downloads/devops-ia-2-edicao-main
git add .
git commit -m "Add CI/CD pipeline"
git push origin main

# 3. Acompanhe em: https://github.com/SEU_USUARIO/SEU_REPO/actions

# 4. Aguarde o deploy completar

# 5. Acesse: http://159.203.159.62
```

---

**Última atualização**: 2025-11-08
