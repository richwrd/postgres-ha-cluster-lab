"""
Configuração global do pytest - Importa fixtures de src/fixtures
"""
import pytest
import sys
from pathlib import Path

# Adiciona src ao path para imports
src_path = Path(__file__).parent / "src"
sys.path.insert(0, str(src_path))

# Importa todas as fixtures
from src.fixtures.cluster import *
from src.fixtures.collectors import *
from src.fixtures.writers import *


@pytest.fixture(scope="session")
def run_id():
    """ID único para esta sessão de testes"""
    import uuid
    from datetime import datetime
    
    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    short_id = str(uuid.uuid4())[:8]
    return f"{timestamp}_{short_id}"
