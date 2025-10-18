"""
Teste rápido para verificar se Docker com sudo está funcionando
"""
from src.core import DockerManager, config


def test_docker_detection():
    """Testa detecção automática de sudo"""
    docker = DockerManager()
    
    # Força detecção
    needs_sudo = docker._requires_sudo()
    
    print(f"\n{'='*60}")
    print(f"🔍 Detecção de Sudo")
    print(f"{'='*60}")
    print(f"Precisa de sudo? {'SIM ⚠️' if needs_sudo else 'NÃO ✅'}")
    print(f"{'='*60}\n")


def test_docker_commands():
    """Testa comandos básicos do Docker"""
    docker = DockerManager()
    
    print(f"\n{'='*60}")
    print(f"🐳 Testando Comandos Docker")
    print(f"{'='*60}")
    
    # Testa com cada container do cluster
    containers = [
        config.PATRONI1_NAME,
        config.PATRONI2_NAME,
        config.PATRONI3_NAME,
        config.PGPOOL_NAME,
    ]
    
    for container in containers:
        status = docker.is_running(container)
        icon = "✅" if status else "❌"
        print(f"{icon} {container}: {'RUNNING' if status else 'STOPPED'}")
    
    print(f"{'='*60}\n")


def test_container_names_from_env():
    """Verifica se os nomes estão sendo lidos do .env"""
    print(f"\n{'='*60}")
    print(f"📋 Nomes dos Containers (.env)")
    print(f"{'='*60}")
    print(f"PATRONI1: {config.PATRONI1_NAME}")
    print(f"PATRONI2: {config.PATRONI2_NAME}")
    print(f"PATRONI3: {config.PATRONI3_NAME}")
    print(f"PGPOOL:   {config.PGPOOL_NAME}")
    print(f"ETCD1:    {config.ETCD1_NAME}")
    print(f"ETCD2:    {config.ETCD2_NAME}")
    print(f"ETCD3:    {config.ETCD3_NAME}")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    """Executa os testes diretamente"""
    print("\n🧪 TESTE DE CONFIGURAÇÃO DOCKER + SUDO\n")
    
    test_container_names_from_env()
    test_docker_detection()
    test_docker_commands()
    
    print("✅ Testes concluídos!\n")
