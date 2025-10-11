#!/bin/bash

# Script para testar containers Docker Compose
# Autor: Eduardo Richard

# Configuração do arquivo Docker Compose
COMPOSE_FILE="${COMPOSE_FILE:-./docker-compose.etcd.yaml}"

echo "🔧 Script de Teste de Containers"
echo "================================"

# Função para exibir ajuda
show_help() {
    echo "Uso: $0 [OPÇÃO]"
    echo ""
    echo "OPÇÕES:"
    echo "  build     - Apenas fazer o build das imagens"
    echo "  run       - Build e executar os containers"
    echo "  stop      - Parar os containers"
    echo "  clean     - Parar e remover containers/imagens"
    echo "  logs      - Mostrar logs dos containers"
    echo "  help      - Mostrar esta ajuda"
    echo ""
    echo "VARIÁVEIS DE AMBIENTE:"
    echo "  COMPOSE_FILE  - Arquivo docker-compose (padrão: $COMPOSE_FILE)"
    echo ""
    echo "EXEMPLOS:"
    echo "  $0 build                                    # Build padrão"
    echo "  COMPOSE_FILE=docker-compose.yaml $0 run     # Com arquivo específico"
    echo "  $0 logs                                     # Ver logs"
    echo ""
}

# Função para build
do_build() {
    echo "🏗️  Fazendo build das imagens..."
    echo "📁 Arquivo: $COMPOSE_FILE"
    docker compose -f "$COMPOSE_FILE" build
    
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
    echo "🚀 Iniciando containers..."
    echo "📁 Arquivo: $COMPOSE_FILE"
    docker compose -f "$COMPOSE_FILE" up -d

    if [ $? -eq 0 ]; then
        echo "✅ Containers iniciados com sucesso!"
        echo ""
        echo "📋 Status dos containers:"
        docker compose -f "$COMPOSE_FILE" ps
        echo ""
        echo "📝 Para ver os logs: $0 logs"
        echo "🛑 Para parar: $0 stop"
    else
        echo "❌ Erro ao iniciar containers!"
        exit 1
    fi
}

# Função para parar
do_stop() {
    echo "🛑 Parando containers..."
    echo "📁 Arquivo: $COMPOSE_FILE"
    docker compose -f "$COMPOSE_FILE" down
    echo "✅ Containers parados!"
}

# Função para limpeza
do_clean() {
    echo "🧹 Limpando containers e imagens..."
    echo "📁 Arquivo: $COMPOSE_FILE"
    docker compose -f "$COMPOSE_FILE" down --rmi all --volumes
    echo "✅ Limpeza concluída!"
}

# Função para logs
do_logs() {
    echo "📋 Logs dos containers:"
    echo "========================"
    echo "📁 Arquivo: $COMPOSE_FILE"
    docker compose -f "$COMPOSE_FILE" logs -f
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
case "${1:-help}" in
    build)
        do_build
        ;;
    run)
        do_build
        do_run
        ;;
    stop)
        do_stop
        ;;
    clean)
        do_clean
        ;;
    logs)
        do_logs
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "❌ Opção inválida: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
