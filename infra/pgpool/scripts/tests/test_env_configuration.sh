#!/bin/sh
# ------------------------------------------------------------------------------------
# SCRIPT DE TESTE: test_env_configuration.sh
# Propósito: Testar se a configuração centralizada está funcionando corretamente
# ------------------------------------------------------------------------------------

set -e

echo "🧪 TESTE DE CONFIGURAÇÃO CENTRALIZADA"
echo "====================================="

# Função para testar importação de bibliotecas
test_library_import() {
    local lib_name="$1"
    local lib_path="/opt/pgpool/bin/scripts/lib/${lib_name}"
    
    echo -n "🔍 Testando importação de ${lib_name}... "
    
    if [ -f "$lib_path" ]; then
        if . "$lib_path" 2>/dev/null; then
            echo "✅ OK"
            return 0
        else
            echo "❌ ERRO: Falha ao importar"
            return 1
        fi
    else
        echo "❌ ERRO: Arquivo não encontrado"
        return 1
    fi
}

# Função para testar variáveis de ambiente
test_environment_variables() {
    echo "🔍 Testando variáveis de ambiente..."
    
    local errors=0
    
    # Testar variáveis críticas
    for var in LIB_DIR LOG_FILE_FAILOVER PCP_USER PCP_HOST PCP_PORT PATRONI_API_ENDPOINTS; do
        if eval "[ -z \"\$$var\" ]"; then
            echo "❌ ERRO: Variável $var não está definida"
            errors=$((errors + 1))
        else
            echo "✅ $var: $(eval echo \"\$$var\")"
        fi
    done
    
    return $errors
}

# Função para testar estrutura de diretórios
test_directory_structure() {
    echo "🔍 Testando estrutura de diretórios..."
    
    local errors=0
    
    # Testar diretório de bibliotecas
    if [ ! -d "$LIB_DIR" ]; then
        echo "❌ ERRO: Diretório LIB_DIR não existe: $LIB_DIR"
        errors=$((errors + 1))
    else
        echo "✅ LIB_DIR existe: $LIB_DIR"
    fi
    
    # Testar diretório de log
    local log_dir=$(dirname "$LOG_FILE_FAILOVER")
    if [ ! -d "$log_dir" ]; then
        echo "⚠️  AVISO: Diretório de log não existe: $log_dir (será criado automaticamente)"
    else
        echo "✅ Diretório de log existe: $log_dir"
    fi
    
    return $errors
}

# Função para testar funções das bibliotecas
test_library_functions() {
    echo "🔍 Testando funções das bibliotecas..."
    
    local errors=0
    
    # Testar função de logging
    if command -v log_metric >/dev/null 2>&1; then
        echo "✅ Função log_metric disponível"
        log_metric "Teste de logging - configuração centralizada funcionando"
    else
        echo "❌ ERRO: Função log_metric não encontrada"
        errors=$((errors + 1))
    fi
    
    # Testar função de timestamp
    if command -v get_timestamp >/dev/null 2>&1; then
        echo "✅ Função get_timestamp disponível"
        local timestamp=$(get_timestamp)
        echo "   Timestamp gerado: $timestamp"
    else
        echo "❌ ERRO: Função get_timestamp não encontrada"
        errors=$((errors + 1))
    fi
    
    return $errors
}

# INÍCIO DOS TESTES
echo "Iniciando testes de configuração centralizada..."
echo ""

if [ ! -f "$ENV_PATH" ]; then
    ENV_PATH="/opt/pgpool/bin/scripts/lib/env.sh"
fi

# Importar configuração centralizada
echo "📦 Importando configuração centralizada de: $ENV_PATH"
if ! . "$ENV_PATH"; then
    echo "❌ FALHA CRÍTICA: Não foi possível importar env.sh"
    exit 1
fi
echo "✅ Configuração centralizada importada com sucesso"
echo ""

# Executar testes
total_errors=0

# Teste 1: Variáveis de ambiente
test_environment_variables
total_errors=$((total_errors + $?))
echo ""

# Teste 2: Estrutura de diretórios
test_directory_structure
total_errors=$((total_errors + $?))
echo ""

# Teste 3: Importação de bibliotecas
test_library_import "logging.sh"
test_library_import "patroni_operations.sh"
test_library_import "pgpool_operations.sh"
test_library_import "config_generator.sh"
echo ""

# Teste 4: Funções das bibliotecas
test_library_functions
total_errors=$((total_errors + $?))
echo ""

# Resultado final
echo "🎯 RESULTADO FINAL"
echo "=================="
if [ $total_errors -eq 0 ]; then
    echo "✅ TODOS OS TESTES PASSARAM!"
    echo "   A configuração centralizada está funcionando corretamente."
    exit 0
else
    echo "❌ $total_errors ERRO(S) ENCONTRADO(S)"
    echo "   Verifique as mensagens de erro acima."
    exit 1
fi
