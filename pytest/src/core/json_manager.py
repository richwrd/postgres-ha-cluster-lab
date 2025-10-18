"""
Gerenciador de arquivos JSONL
"""
import json
from pathlib import Path
from datetime import datetime
from typing import Any, Dict


class JSONLWriter:
    """Escreve dados em formato JSONL (JSON Lines)"""
    
    def __init__(self, output_dir: Path, prefix: str, run_id: str):
        """
        Args:
            output_dir: Diretório para salvar arquivos
            prefix: Prefixo do arquivo (ex: 'rto', 'rpo', 'performance')
            run_id: ID único do run
        """
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        filename = f"{prefix}_{timestamp}_{run_id}.jsonl"
        self.filepath = self.output_dir / filename
    
    def write(self, data: Any) -> None:
        """
        Escreve uma linha JSONL
        
        Args:
            data: Objeto com método to_json() ou dicionário
        """
        with open(self.filepath, 'a') as f:
            if hasattr(data, 'to_json'):
                payload = data.to_json()
            elif isinstance(data, dict):
                payload = data
            else:
                raise ValueError(f"Tipo não suportado: {type(data)}")
            
            f.write(json.dumps(payload, ensure_ascii=False) + '\n')
    
    def write_metadata(self, metadata: Dict[str, Any]) -> None:
        """Escreve metadados do teste"""
        self.write({
            "type": "metadata",
            "timestamp": datetime.utcnow().isoformat(),
            "data": metadata
        })
    
    def get_filepath(self) -> Path:
        """Retorna o caminho do arquivo"""
        return self.filepath


class JSONLReader:
    """Lê arquivos JSONL"""
    
    @staticmethod
    def read_file(filepath: Path) -> list:
        """
        Lê arquivo JSONL completo
        
        Args:
            filepath: Caminho do arquivo
            
        Returns:
            Lista de dicionários
        """
        data = []
        with open(filepath, 'r') as f:
            for line in f:
                data.append(json.loads(line.strip()))
        return data
    
    @staticmethod
    def read_by_type(filepath: Path, data_type: str) -> list:
        """
        Lê apenas linhas de um tipo específico
        
        Args:
            filepath: Caminho do arquivo
            data_type: Tipo a filtrar (ex: 'rto_metrics', 'metadata')
            
        Returns:
            Lista de dicionários filtrados
        """
        data = []
        with open(filepath, 'r') as f:
            for line in f:
                obj = json.loads(line.strip())
                if obj.get('type') == data_type:
                    data.append(obj)
        return data
