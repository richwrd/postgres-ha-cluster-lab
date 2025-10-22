"""
Gerenciador de operações Docker
"""
import subprocess
from typing import Optional, List


class DockerManager:
    """Gerencia operações com containers Docker"""
    
    @classmethod
    def stop_container(cls, container_name: str, timeout: int = 30, graceful: bool = True) -> bool:
        """
        Para um container
        
        Args:
            container_name: Nome do container
            timeout: Timeout em segundos (padrão 30s para parada graceful)
            graceful: Se True, usa timeout de 10s. Se False, mata imediatamente (timeout 0)
            
        Returns:
            True se sucesso
        """
        try:
            stop_timeout = "10" if graceful else "0"
            result = subprocess.run(
                ["docker", "stop", "-t", stop_timeout, container_name],
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
            else:
                # Imprime informações de erro para debug
                print(f"❌ Comando docker exec falhou (exit code: {result.returncode})")
                print(f"   Container: {container_name}")
                print(f"   Comando: {' '.join(command)}")
                if result.stdout:
                    print(f"   STDOUT: {result.stdout}")
                if result.stderr:
                    print(f"   STDERR: {result.stderr}")
                return None
                
        except subprocess.TimeoutExpired as e:
            print(f"❌ Timeout ao executar comando no container '{container_name}'")
            print(f"   Timeout: {timeout}s")
            print(f"   Comando: {' '.join(command)}")
            if e.stdout:
                print(f"   Output parcial (stdout): {e.stdout.decode() if isinstance(e.stdout, bytes) else e.stdout}")
            if e.stderr:
                print(f"   Error parcial (stderr): {e.stderr.decode() if isinstance(e.stderr, bytes) else e.stderr}")
            return None
            
        except Exception as e:
            print(f"❌ Exceção ao executar comando no container '{container_name}'")
            print(f"   Tipo: {type(e).__name__}")
            print(f"   Mensagem: {str(e)}")
            print(f"   Comando: {' '.join(command)}")
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
    
    @classmethod
    def kill_container(cls, container_name: str, signal: str = "SIGKILL") -> bool:
        """
        Mata um container imediatamente com sinal específico
        
        Simula falha catastrófica instantânea (queda de energia, kernel panic, etc.)
        Mais realista para testes de RTO pois não dá tempo de shutdown graceful.
        
        Args:
            container_name: Nome do container
            signal: Sinal a enviar (SIGKILL, SIGTERM, SIGINT, SIGSTOP)
                   - SIGKILL: Mata instantaneamente (padrão, mais agressivo)
                   - SIGTERM: Termina gracefully (similar a docker stop)
                   - SIGSTOP: Congela o processo (similar a pause, mas a nível de SO)
            
        Returns:
            True se sucesso
            
        Examples:
            >>> # Simula queda de energia (instantâneo)
            >>> DockerManager.kill_container("patroni-postgres-1", "SIGKILL")
            
            >>> # Simula perda de rede (congela sem matar)
            >>> DockerManager.kill_container("patroni-postgres-1", "SIGSTOP")
        """
        try:
            result = subprocess.run(
                ["docker", "kill", "--signal", signal, container_name],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode != 0:
                print(f"❌ Erro ao matar {container_name} com {signal}:")
                print(f"   stdout: {result.stdout}")
                print(f"   stderr: {result.stderr}")
                return False
            return True
        except Exception as e:
            print(f"❌ Exceção ao matar {container_name}: {e}")
            return False
    
    @classmethod
    def get_stats(cls, container_names: List[str], no_stream: bool = True) -> Optional[dict]:
        """
        Obtém estatísticas de containers
        
        Args:
            container_names: Lista de nomes dos containers
            no_stream: Se True, retorna apenas uma leitura
            
        Returns:
            Dict com estatísticas parseadas ou None se erro
        """
        try:
            cmd = ["docker", "stats", "--no-trunc", "--format", 
                   "{{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"]
            
            if no_stream:
                cmd.append("--no-stream")
            
            cmd.extend(container_names)
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode != 0:
                return None
            
            # Parse output
            stats = {}
            for line in result.stdout.strip().split('\n'):
                if not line:
                    continue
                    
                parts = line.split('\t')
                if len(parts) < 6:
                    continue
                
                container = parts[0]
                cpu_perc = parts[1].replace('%', '').strip()
                mem_usage = parts[2].strip()  # e.g., "1.5GiB / 16GiB"
                mem_perc = parts[3].replace('%', '').strip()
                net_io = parts[4].strip()  # e.g., "1.2MB / 3.4MB"
                block_io = parts[5].strip()  # e.g., "5.6MB / 7.8MB"
                
                stats[container] = {
                    'cpu_percent': float(cpu_perc) if cpu_perc else 0.0,
                    'memory_usage': mem_usage,
                    'memory_percent': float(mem_perc) if mem_perc else 0.0,
                    'network_io': net_io,
                    'block_io': block_io
                }
            
            return stats
            
        except Exception as e:
            print(f"❌ Erro ao obter stats: {e}")
            return None
    
    @classmethod
    def parse_bytes(cls, value: str) -> float:
        """
        Parse valores de bytes (e.g., "1.5GiB", "256MB") para bytes
        
        Args:
            value: String com valor e unidade
            
        Returns:
            Valor em bytes
        """
        value = value.strip()
        # Ordem importa! Unidades maiores primeiro para evitar match parcial
        # Ex: "356.4MiB" deve fazer match com "MiB" antes de "B"
        units = [
            ('TiB', 1024**4),
            ('GiB', 1024**3),
            ('MiB', 1024**2),
            ('KiB', 1024),
            ('TB', 1000**4),
            ('GB', 1000**3),
            ('MB', 1000**2),
            ('KB', 1000),
            ('B', 1),
        ]
        
        for unit, multiplier in units:
            if value.endswith(unit):
                try:
                    num = float(value[:-len(unit)])
                    return num * multiplier
                except ValueError:
                    return 0.0
        
        # Se não tem unidade, assume bytes
        try:
            return float(value)
        except ValueError:
            return 0.0
