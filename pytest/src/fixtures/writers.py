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
    output_dir = output_base_dir / "resilience" / "rto"
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
    output_dir = output_base_dir / "resilience" / "rpo"
    writer = JSONLWriter(output_dir, "rpo", run_id)
    
    # Escreve metadados iniciais
    writer.write_metadata({
        "test_type": "resilience_rpo",
        "run_id": run_id
    })
    
    return writer


@pytest.fixture
def performance_writer_baseline(run_id, output_base_dir, request):
    """Writer JSONL para métricas de performance - baseline"""
    
    # Extrai informações do teste
    test_name = request.node.name
    workload_type = None
    client_count = None
    
    # Detecta tipo de workload pelos marcadores
    if request.node.get_closest_marker("baseline_select_only_reconnect"):
        workload_type = "select_only_reconnect"
    elif request.node.get_closest_marker("baseline_select_only"):
        workload_type = "select_only"
    elif request.node.get_closest_marker("baseline_mixed_workload_reconnect"):
        workload_type = "mixed_reconnect"
    elif request.node.get_closest_marker("baseline_mixed_workload"):
        workload_type = "mixed"
    
    # Extrai o número de clientes do parâmetro
    if hasattr(request, 'param'):
        client_count = request.param
    elif 'client_count' in request.node.funcargs:
        client_count = request.node.funcargs['client_count']
    
    # Monta estrutura de diretórios: outputs/performance/baseline/{workload_type}/{client_count}
    output_dir = output_base_dir / "performance" / "baseline"
    subdirs = []
    
    if workload_type:
        subdirs.append(workload_type)
    if client_count:
        subdirs.append(str(client_count))
    
    writer = JSONLWriter(output_dir, "performance", run_id, subdirs=subdirs)
    
    # Escreve metadados iniciais
    writer.write_metadata({
        "test_type": "performance",
        "scenario": "baseline",
        "workload_type": workload_type,
        "client_count": client_count,
        "run_id": run_id
    })
    
    return writer


@pytest.fixture
def performance_writer_cluster(run_id, output_base_dir, request):
    """Writer JSONL para métricas de performance - cluster"""
    
    # Extrai informações do teste
    test_name = request.node.name
    workload_type = None
    client_count = None
    
    # Detecta tipo de workload pelos marcadores
    if request.node.get_closest_marker("cluster_select_only_reconnect"):
        workload_type = "select_only_reconnect"
    elif request.node.get_closest_marker("cluster_select_only"):
        workload_type = "select_only"
    elif request.node.get_closest_marker("cluster_mixed_workload_reconnect"):
        workload_type = "mixed_reconnect"
    elif request.node.get_closest_marker("cluster_mixed_workload"):
        workload_type = "mixed"
    
    # Extrai o número de clientes do parâmetro
    if hasattr(request, 'param'):
        client_count = request.param
    elif 'client_count' in request.node.funcargs:
        client_count = request.node.funcargs['client_count']
    
    # Monta estrutura de diretórios: outputs/performance/cluster/{workload_type}/{client_count}
    output_dir = output_base_dir / "performance" / "cluster"
    subdirs = []
    
    if workload_type:
        subdirs.append(workload_type)
    if client_count:
        subdirs.append(str(client_count))
    
    writer = JSONLWriter(output_dir, "performance", run_id, subdirs=subdirs)
    
    # Escreve metadados iniciais
    writer.write_metadata({
        "test_type": "performance",
        "scenario": "cluster",
        "workload_type": workload_type,
        "client_count": client_count,
        "run_id": run_id
    })
    
    return writer


@pytest.fixture
def docker_stats_writer(run_id, output_base_dir, request):
    """
    Writer JSONL para métricas de Docker Stats
    
    Determina o diretório baseado no tipo de teste (performance/resilience)
    e organiza por workload e client_count quando disponível
    """
    # Detecta tipo de teste pelos marcadores
    test_type = "performance"  # default
    sub_type = "baseline"  # default
    workload_type = None
    client_count = None
    
    if request.node.get_closest_marker("rto") or request.node.get_closest_marker("resilience_rto"):
        test_type = "resilience"
        sub_type = "rto"
    elif request.node.get_closest_marker("rpo") or request.node.get_closest_marker("resilience_rpo"):
        test_type = "resilience"
        sub_type = "rpo"
    elif request.node.get_closest_marker("cluster") or request.node.get_closest_marker("cluster_performance"):
        sub_type = "cluster"
    
    # Para testes de performance, extrai workload e client_count
    if test_type == "performance":
        # Detecta tipo de workload pelos marcadores
        if sub_type == "baseline":
            if request.node.get_closest_marker("baseline_select_only_reconnect"):
                workload_type = "select_only_reconnect"
            elif request.node.get_closest_marker("baseline_select_only"):
                workload_type = "select_only"
            elif request.node.get_closest_marker("baseline_mixed_workload_reconnect"):
                workload_type = "mixed_reconnect"
            elif request.node.get_closest_marker("baseline_mixed_workload"):
                workload_type = "mixed"
        elif sub_type == "cluster":
            if request.node.get_closest_marker("cluster_select_only_reconnect"):
                workload_type = "select_only_reconnect"
            elif request.node.get_closest_marker("cluster_select_only"):
                workload_type = "select_only"
            elif request.node.get_closest_marker("cluster_mixed_workload_reconnect"):
                workload_type = "mixed_reconnect"
            elif request.node.get_closest_marker("cluster_mixed_workload"):
                workload_type = "mixed"
        
        # Extrai o número de clientes do parâmetro
        if hasattr(request, 'param'):
            client_count = request.param
        elif 'client_count' in request.node.funcargs:
            client_count = request.node.funcargs['client_count']
    
    # Monta estrutura de diretórios
    output_dir = output_base_dir / test_type / sub_type
    subdirs = []
    
    if workload_type:
        subdirs.append(workload_type)
    if client_count:
        subdirs.append(str(client_count))
    
    writer = JSONLWriter(output_dir, "docker_stats", run_id, subdirs=subdirs)
    
    # Escreve metadados iniciais
    writer.write_metadata({
        "test_type": f"{test_type}_docker_stats",
        "sub_type": sub_type,
        "workload_type": workload_type,
        "client_count": client_count,
        "run_id": run_id
    })
    
    return writer
