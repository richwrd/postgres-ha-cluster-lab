"""
Gerenciador de operações Docker
"""
import subprocess
from typing import Optional, List


class DockerManager:
    """Gerencia operações com containers Docker"""
    
    @classmethod
    def stop_container(cls, container_name: str, timeout: int = 30) -> bool:
        """
        Para um container
        
        Args:
            container_name: Nome do container
            timeout: Timeout em segundos (padrão 30s para parada graceful)
            
        Returns:
            True se sucesso
        """
        try:
            result = subprocess.run(
                ["docker", "stop", "-t", "10", container_name],
                capture_output=True,
                text=True,
                timeout=timeout
            )
            if result.returncode != 0:
                print(f"❌ Erro ao parar {container_name}:")
                print(f"   stdout: {result.stdout}")
                print(f"   stderr: {result.stderr}")
                return False
            return True
        except subprocess.TimeoutExpired as e:
            print(f"❌ Timeout ao parar {container_name}: {e}")
            return False
        except Exception as e:
            print(f"❌ Exceção ao parar {container_name}: {e}")
            return False
    
    @classmethod
    def start_container(cls, container_name: str, timeout: int = 30) -> bool:
        """
        Inicia um container
        
        Args:
            container_name: Nome do container
            timeout: Timeout em segundos
            
        Returns:
            True se sucesso
        """
        try:
            result = subprocess.run(
                ["docker", "start", container_name],
                capture_output=True,
                text=True,
                timeout=timeout
            )
            if result.returncode != 0:
                print(f"❌ Erro ao iniciar {container_name}:")
                print(f"   stdout: {result.stdout}")
                print(f"   stderr: {result.stderr}")
                return False
            return True
        except subprocess.TimeoutExpired as e:
            print(f"❌ Timeout ao iniciar {container_name}: {e}")
            return False
        except Exception as e:
            print(f"❌ Exceção ao iniciar {container_name}: {e}")
            return False
    
    @classmethod
    def restart_container(cls, container_name: str, timeout: int = 10) -> bool:
        """
        Reinicia um container
        
        Args:
            container_name: Nome do container
            timeout: Timeout em segundos
            
        Returns:
            True se sucesso
        """
        try:
            result = subprocess.run(
                ["docker", "restart", container_name],
                capture_output=True,
                text=True,
                timeout=timeout
            )
            return result.returncode == 0
        except Exception:
            return False
    
    @classmethod
    def exec_command(cls, container_name: str, command: List[str], timeout: int = 10, exec_options: Optional[List[str]] = None) -> Optional[str]:
        """
        Executa comando dentro do container
        
        Args:
            container_name: Nome do container
            exec_options: Opções do docker exec (ex: ['-it'], ['-e', 'VAR=value'])
            command: Comando a executar (lista)
            timeout: Timeout em segundos
            
        Returns:
            Output do comando ou None se falhar
        """
        try:
            cmd = ["docker", "exec"]
            if exec_options:
                cmd.extend(exec_options)
            cmd.append(container_name)
            cmd.extend(command)
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            if result.returncode == 0:
                return result.stdout
            return None
        except Exception:
            return None

    
    @classmethod
    def is_running(cls, container_name: str) -> bool:
        """
        Verifica se container está rodando
        
        Args:
            container_name: Nome do container
            
        Returns:
            True se está rodando
        """
        try:
            result = subprocess.run(
                ["docker", "inspect", "-f", "{{.State.Running}}", container_name],
                capture_output=True,
                text=True,
                timeout=5
            )
            return result.stdout.strip() == "true"
        except Exception:
            return False
    
    @classmethod
    def pause_container(cls, container_name: str) -> bool:
        """Pausa um container (simula congelamento)"""
        try:
            result = subprocess.run(
                ["docker", "pause", container_name],
                capture_output=True,
                timeout=5
            )
            return result.returncode == 0
        except Exception:
            return False
    
    @classmethod
    def unpause_container(cls, container_name: str) -> bool:
        """Despausa um container"""
        try:
            result = subprocess.run(
                ["docker", "unpause", container_name],
                capture_output=True,
                timeout=5
            )
            return result.returncode == 0
        except Exception:
            return False
