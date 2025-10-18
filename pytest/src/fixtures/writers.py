"""
Fixtures de escrita de dados
"""
import pytest
from pathlib import Path
from src.core.json_manager import JSONLWriter


@pytest.fixture(scope="session")
def output_base_dir():
    """Diretório base para outputs"""
    return Path(__file__).parent.parent.parent / "outputs"


@pytest.fixture
def rto_writer(run_id, output_base_dir):
    """Writer JSONL para métricas RTO"""
    output_dir = output_base_dir / "resilience"
    writer = JSONLWriter(output_dir, "rto", run_id)
    
    # Escreve metadados iniciais
    writer.write_metadata({
        "test_type": "resilience_rto",
        "run_id": run_id
    })
    
    return writer


@pytest.fixture
def rpo_writer(run_id, output_base_dir):
    """Writer JSONL para métricas RPO"""
    output_dir = output_base_dir / "resilience"
    writer = JSONLWriter(output_dir, "rpo", run_id)
    
    # Escreve metadados iniciais
    writer.write_metadata({
        "test_type": "resilience_rpo",
        "run_id": run_id
    })
    
    return writer


@pytest.fixture
def performance_writer(run_id, output_base_dir):
    """Writer JSONL para métricas de performance"""
    output_dir = output_base_dir / "performance"
    writer = JSONLWriter(output_dir, "performance", run_id)
    
    # Escreve metadados iniciais
    writer.write_metadata({
        "test_type": "performance",
        "run_id": run_id
    })
    
    return writer
