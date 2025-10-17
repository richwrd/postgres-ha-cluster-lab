#!/bin/bash

# Script para testar containers Docker Compose
# Autor: Eduardo Richard

# Configuração do arquivo Docker Compose
COMPOSE_FILE="${COMPOSE_FILE:-./docker-compose.yaml}"

echo "🔧 Script de Teste de Containers"
echo "================================"

# Função para exibir ajuda
show_help() {
    echo "Uso: $0 [OPÇÃO] [SERVIÇOS...]"
    echo ""
    echo "OPÇÕES:"
    echo "  build     - Apenas fazer o build das imagens"
    echo "  run       - Build e executar os containers"
    echo "  restart   - Reiniciar containers "
    echo "  stop      - Parar os containers"
    echo "  clean     - Parar e remover containers/imagens"
    echo "  logs      - Mostrar logs dos containers"
    echo "  status    - Mostrar status dos containers"
    echo "  help      - Mostrar esta ajuda"
    echo ""
    echo "SERVIÇOS:"
    echo "  Se nenhum serviço for especificado, a operação será aplicada a todos."
    echo "  Você pode especificar um ou mais serviços separados por espaço."
    echo ""
    echo "VARIÁVEIS DE AMBIENTE:"
    echo "  COMPOSE_FILE  - Arquivo docker-compose (padrão: $COMPOSE_FILE)"
    echo ""
    echo "EXEMPLOS:"
    echo "  $0 build                                    # Build de todos os serviços"
    echo "  $0 build patroni1 patroni2                  # Build de serviços específicos"
    echo "  $0 run pgpool                               # Executar apenas pgpool"
    echo "  $0 restart pgpool                           # Reiniciar pgpool (passa pelo entrypoint)"
    echo "  $0 logs etcd1 etcd2                         # Ver logs do etcd"
    echo "  $0 stop patroni1                            # Parar apenas patroni1"
    echo "  COMPOSE_FILE=docker-compose.yaml $0 run     # Com arquivo específico"
    echo ""
}

# Função para build
do_build() {
    local services="$@"
    
    if [ -n "$services" ]; then
        echo "🏗️  Fazendo build das imagens dos serviços: $services"
    else
        echo "🏗️  Fazendo build de todas as imagens..."
    fi
    echo "📁 Arquivo: $COMPOSE_FILE"
    
    docker compose -f "$COMPOSE_FILE" build $services
    
    if [ $? -eq 0 ]; then
        echo "✅ Build concluído com sucesso!"
        echo ""
        echo "📋 Imagens criadas:"
        docker images | grep "$(basename "$(dirname "$COMPOSE_FILE")")"
    else
        echo "❌ Erro no build!"
        exit 1
    fi
}

# Função para executar
do_run() {
    local services="$@"
    
    if [ -n "$services" ]; then
        echo "🚀 Iniciando containers dos serviços: $services"
    else
        echo "🚀 Iniciando todos os containers..."
    fi
    echo "📁 Arquivo: $COMPOSE_FILE"
    
    docker compose -f "$COMPOSE_FILE" up -d $services

    if [ $? -eq 0 ]; then
        echo "✅ Containers iniciados com sucesso!"
        echo ""
        echo "📋 Status dos containers:"
        docker compose -f "$COMPOSE_FILE" ps $services
        echo ""
        echo "📝 Para ver os logs: $0 logs ${services}"
        echo "🛑 Para parar: $0 stop ${services}"
    else
        echo "❌ Erro ao iniciar containers!"
        exit 1
    fi
}

# Função para reiniciar
do_restart() {
    local services="$@"
    
    if [ -n "$services" ]; then
        echo "🔄 Reiniciando containers dos serviços: $services"
    else
        echo "🔄 Reiniciando todos os containers..."
    fi
    echo "📁 Arquivo: $COMPOSE_FILE"
    echo "⚠️  O container será parado e iniciado novamente, passando pelo entrypoint."
    
    docker compose -f "$COMPOSE_FILE" restart $services

    if [ $? -eq 0 ]; then
        echo "✅ Containers reiniciados com sucesso!"
        echo ""
        echo "📋 Status dos containers:"
        docker compose -f "$COMPOSE_FILE" ps $services
        echo ""
        echo "📝 Para ver os logs: $0 logs ${services}"
    else
        echo "❌ Erro ao reiniciar containers!"
        exit 1
    fi
}

# Função para parar
do_stop() {
    local services="$@"
    
    if [ -n "$services" ]; then
        echo "🛑 Parando containers dos serviços: $services"
        echo "📁 Arquivo: $COMPOSE_FILE"
        docker compose -f "$COMPOSE_FILE" stop $services
    else
        echo "🛑 Parando todos os containers..."
        echo "📁 Arquivo: $COMPOSE_FILE"
        docker compose -f "$COMPOSE_FILE" down
    fi
    echo "✅ Containers parados!"
}

# Função para limpeza
do_clean() {
    local services="$@"
    
    if [ -n "$services" ]; then
        echo "🧹 Limpando containers dos serviços: $services"
        echo "📁 Arquivo: $COMPOSE_FILE"
        echo "⚠️  Removendo containers..."
        docker compose -f "$COMPOSE_FILE" rm -f -s -v $services
    else
        echo "🧹 Limpando todos os containers e imagens..."
        echo "📁 Arquivo: $COMPOSE_FILE"
        docker compose -f "$COMPOSE_FILE" down --rmi all --volumes
    fi
    echo "✅ Limpeza concluída!"
}

# Função para logs
do_logs() {
    local services="$@"
    
    if [ -n "$services" ]; then
        echo "📋 Logs dos containers dos serviços: $services"
    else
        echo "📋 Logs de todos os containers:"
    fi
    echo "========================"
    echo "📁 Arquivo: $COMPOSE_FILE"
    docker compose -f "$COMPOSE_FILE" logs -f $services
}

# Função para status
do_status() {
    local services="$@"
    
    echo "📊 Status dos containers:"
    echo "========================"
    echo "📁 Arquivo: $COMPOSE_FILE"
    echo ""
    docker compose -f "$COMPOSE_FILE" ps $services
}

# Verificar se docker compose está disponível
if ! command -v docker &> /dev/null; then
    echo "❌ docker não está instalado!"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo "❌ docker compose não está disponível!"
    exit 1
fi

# Verificar se o arquivo compose existe
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Arquivo Docker Compose não encontrado: $COMPOSE_FILE"
    exit 1
fi

# Processar argumentos
ACTION="${1:-help}"
shift

# Capturar serviços adicionais
SERVICES="$@"

case "$ACTION" in
    build)
        do_build $SERVICES
        ;;
    run)
        do_build $SERVICES
        do_run $SERVICES
        ;;
    restart)
        do_restart $SERVICES
        ;;
    stop)
        do_stop $SERVICES
        ;;
    clean)
        do_clean $SERVICES
        ;;
    logs)
        do_logs $SERVICES
        ;;
    status)
        do_status $SERVICES
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "❌ Opção inválida: $ACTION"
        echo ""
        show_help
        exit 1
        ;;
esac
