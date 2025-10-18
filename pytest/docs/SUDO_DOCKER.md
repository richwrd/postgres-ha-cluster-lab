# ⚙️ Configuração Docker

## 🚀 Pré-requisito OBRIGATÓRIO

Antes de executar os testes, você **DEVE** configurar o Docker para rodar sem sudo:

```bash
# 1. Adicionar seu usuário ao grupo docker
sudo usermod -aG docker $USER

# 2. Recarregar os grupos (ou faça logout/login)
newgrp docker

# 3. Testar se funciona
docker ps
```

Se o comando `docker ps` executar sem erros, você está pronto! ✅

## ❌ Por que NÃO usar sudo?

**NÃO rode** `sudo pytest`! Isso causa problemas:

- ❌ Arquivos de output criados como root (você não consegue deletar depois)
- ❌ Conflitos com ambientes virtuais (venv/virtualenv)
- ❌ Riscos de segurança desnecessários

## ✅ Uso Correto

Depois de configurar o Docker, simplesmente execute:

```bash
# Ative seu ambiente virtual (se usar)
source venv/bin/activate

# Execute os testes normalmente
pytest tests/

# Ou testes específicos
pytest tests/resilience/test_rto_primary_failure.py -v
```

## 🔍 Troubleshooting

### Erro: "permission denied while trying to connect to Docker daemon"

Você esqueceu de configurar o grupo docker! Execute os comandos acima.

### Erro: "docker ps" ainda pede sudo após executar newgrp

Faça logout/login ou reinicie o terminal:

```bash
# Opção 1: Reiniciar terminal
exit
# Abra um novo terminal

# Opção 2: Reiniciar sessão
sudo su - $USER
```
