# Configuração Centralizada

## Visão Geral

O arquivo `env.sh` foi criado para centralizar todas as variáveis de configuração dos scripts de failover do Pgpool-II. Isso estabelece um **único ponto de verdade** para toda a configuração, facilitando manutenção e evitando duplicação.

## Arquivo de Configuração: `env.sh`

### Variáveis Principais

#### Configurações de Diretórios
- **`LIB_DIR`**: Diretório das bibliotecas (padrão: `/opt/pgpool/bin/scripts/lib`)

#### Configurações de Logging
- **`LOG_FILE_FAILOVER`**: Arquivo de log principal (padrão: `/var/log/pgpool/failover_metrics.log`)

#### Configurações do Pgpool-II PCP
- **`PCP_USER`**: Usuário para comandos PCP (padrão: derivado de `PGPOOL_PCP_USER` ou `pcp_admin`)
- **`PCP_HOST`**: Host do Pgpool-II (padrão: `localhost`)
- **`PCP_PORT`**: Porta do PCP (padrão: `9898`)

#### Configurações do Patroni
- **`PATRONI_API_ENDPOINTS`**: Lista de endpoints da API do Patroni separados por espaço
  - Padrão: `"http://patroni-postgres-1:8008 http://patroni-postgres-2:8008 http://patroni-postgres-3:8008"`

#### Configurações Opcionais
- **`CURL_TIMEOUT`**: Timeout para chamadas curl (padrão: `3`)
- **`API_RETRY_COUNT`**: Número de tentativas para APIs (padrão: `3`)
- **`DEBUG_MODE`**: Modo debug para informações detalhadas (padrão: `false`)

## Como Usar

### Nos Scripts Principais

Todos os scripts principais (`*_main.sh`) agora importam automaticamente as configurações:

```bash
#!/bin/sh
set -e

# --- Importações ---
# Importar configurações centralizadas primeiro
. "/opt/pgpool/bin/scripts/lib/env.sh"

# Depois importar as outras bibliotecas
. "${LIB_DIR}/logging.sh"
# ... outras importações
```

### Personalização

Para personalizar as configurações, você pode:

1. **Definir variáveis de ambiente antes de executar:**
   ```bash
   export PATRONI_API_ENDPOINTS="http://meu-patroni:8008"
   export LOG_FILE_FAILOVER="/var/log/custom/pgpool.log"
   ./failover_main.sh
   ```

2. **Modificar o arquivo `env.sh` diretamente** (não recomendado para ambientes containerizados)

3. **Usar um arquivo `.env` externo** (implementação futura)

## Validações Automáticas

O arquivo `env.sh` inclui validações automáticas que verificam:

- ✅ Se variáveis críticas estão definidas
- ✅ Se o diretório de log existe (cria se necessário)
- ✅ Configuração geral do ambiente

Se alguma validação falhar, o script será interrompido com uma mensagem de erro clara.

## Debug

Para habilitar informações detalhadas de configuração:

```bash
export DEBUG_MODE=true
./failover_main.sh
```

Isso mostrará todas as variáveis de configuração antes da execução.

## Migração

### Antes (Distribuído)
- `LOG_FILE_FAILOVER` definido em `logging.sh`
- `PCP_*` definidos em `pgpool_operations.sh`
- `LIB_DIR` definido em cada script principal
- `PATRONI_API_ENDPOINTS` usado mas não definido

### Depois (Centralizado)
- ✅ Todas as variáveis definidas em `env.sh`
- ✅ Validações automáticas
- ✅ Suporte a debug
- ✅ Configuração via variáveis de ambiente
- ✅ Valores padrão sensatos

## Benefícios

1. **Ponto único de verdade**: Todas as configurações em um local
2. **Facilita manutenção**: Mudanças em um só lugar
3. **Melhor documentação**: Todas as variáveis documentadas
4. **Validação automática**: Detecta problemas de configuração cedo
5. **Flexibilidade**: Suporta personalização via environment variables
6. **Debug integrado**: Informações detalhadas quando necessário
