# Scripts de Failover - Estrutura Modular Elegante

## Visão Geral

Esta estrutura refatorada segue os princípios **DRY (Don't Repeat Yourself)** e **Separação de Responsabilidades**, organizando TODAS as funções auxiliares em uma biblioteca centralizada para evitar duplicação e melhorar a manutenibilidade.

## Estrutura de Diretórios (Otimizada)

```
scripts/
├── README.md                      # Esta documentação
├── lib/                               # 🎯 BIBLIOTECA CENTRALIZADA
│   ├── logging.sh                     # Sistema de logging padronizado
│   ├── patroni_operations.sh          # TODAS as operações do Patroni
│   ├── pgpool_operations.sh           # TODAS as operações do Pgpool-II
│   └── config_generator.sh            # Geração de configurações
├── failover/                          # Scripts específicos de failover
│   ├── failover_main.sh              # Script principal de failover
│   ├── follow_primary_main.sh         # Script principal pós-failover
│   └── test_structure.sh             # Testes da estrutura
├── hooks/                             # Scripts de hook (interfaces)
│   ├── failover.sh                   # Hook que delega para failover_main.sh
│   └── follow_primary.sh             # Hook que delega para follow_primary_main.sh
├── helpers/                          # Compatibilidade (delegam para lib/)
│   ├── find_active_patroni_endpoint.sh  # ⚠️  OBSOLETO - usar lib/patroni_operations.sh
│   └── generate_backend_config.sh       # Atualizado para usar lib/config_generator.sh
└── startup/                          # Scripts de inicialização
    ├── 01_wait_for_patroni.sh
    ├── 02_generate_pgpool_config.sh
    └── 03_generate_passwords.sh
```

## Principais Melhorias da Reestruturação

### 🧩 **Biblioteca Centralizada (`lib/`)**
```bash
lib/
├── logging.sh              # Funções de log padronizadas
├── patroni_operations.sh   # find_active_endpoint + validações + descoberta de líder
├── pgpool_operations.sh    # Operações de nós, promoção, status
└── config_generator.sh     # Geração de configurações do Pgpool-II
```

### 🔄 **Eliminação Total de Duplicação**
- ✅ Operações do Pgpool-II centralizadas
- ✅ Geração de configuração modularizada

## Bibliotecas Disponíveis

### 📊 `lib/logging.sh`
```bash
log_metric "Mensagem geral"
log_error "Erro não crítico"
log_critical "Erro crítico que requer atenção"
log_success "Operação bem-sucedida"
log_warning "Aviso importante"
log_start "NOME_DO_PROCESSO"
log_end "NOME_DO_PROCESSO" "$start_time"
get_timestamp                    # Para medir duração
```

### 🐘 `lib/patroni_operations.sh`
```bash
find_active_patroni_endpoint        # Encontra endpoint ativo
get_new_primary_host "$endpoint"     # Descobre novo líder
validate_patroni_cluster "$endpoint" # Valida estado do cluster
get_cluster_state "$endpoint"        # Estado completo do cluster
```

### ⚙️ `lib/pgpool_operations.sh`
```bash
get_pgpool_node_id "$host"                    # Encontra Node ID
promote_pgpool_node "$node_id" "$host"        # Promove nó
get_node_status "$node_id"                    # Status do nó
list_all_nodes                               # Lista todos os nós
```

### 🔧 `lib/config_generator.sh`
```bash
generate_backend_config              # Gera config de backend
validate_backend_config "$config"    # Valida configuração gerada
get_cluster_state "$endpoint"        # Estado do cluster para config
```

## Vantagens da Estrutura

1. **🎯 Coesão**: Funcionalidades relacionadas estão juntas
2. **🔄 DRY**: Zero duplicação de código
3. **🧩 Modularidade**: Cada biblioteca tem responsabilidade específica
4. **📚 Reutilização**: Qualquer script pode usar qualquer biblioteca
5. **🧪 Testabilidade**: Cada módulo pode ser testado independentemente
6. **📖 Legibilidade**: Estrutura clara e intuitiva
7. **🔧 Manutenibilidade**: Mudanças em um lugar afetam todos os usos

## Configuração

As bibliotecas respeitam variáveis de ambiente:

```bash
# Logging
LOG_FILE_FAILOVER="/var/log/pgpool/failover_metrics.log"

# Pgpool-II  
PGPOOL_PCP_USER="pcp_admin"
PCP_HOST="localhost"
PCP_PORT="9898"

# Patroni
PATRONI_API_ENDPOINTS="http://patroni-1:8008 http://patroni-2:8008 http://patroni-3:8008"
```

Uma arquitetura muito mais elegante e manutenível! 🎉
