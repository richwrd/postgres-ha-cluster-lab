# TCC: Cluster PostgreSQL de Alta Disponibilidade com Patroni e Pgpool-II

Projeto de Trabalho de Conclusão de Curso focado na implementação e análise de uma arquitetura de alta disponibilidade para PostgreSQL usando ferramentas open-source em um ambiente containerizado com Docker.

## 🏛️ Arquitetura (em breve detalhar)

--- 

## 🚀 Sobre o Projeto

Este repositório contém todos os artefatos de código produzidos para o TCC, cujo objetivo é criar e analisar um cluster PostgreSQL resiliente a falhas. A solução utiliza ferramentas open-source em um ambiente totalmente orquestrado via Docker Compose.

A filosofia por trás desta implementação foi manter uma arquitetura com o mínimo de nós possível para facilitar o entendimento e focar a análise no mecanismo de failover do banco de dados.

**Principais Componentes:**
* **Cluster PostgreSQL:** 3 nós gerenciados pelo **Patroni**, responsável pela replicação e pelo processo de failover automático.
* **Serviço de Descoberta:** Uma instância única de **`etcd`**, que atua como o cérebro para o Patroni, armazenando o estado do cluster.
* **Ponto de Acesso:** Uma instância única de **`Pgpool-II`**, que serve como um ponto de entrada para as aplicações, realizando o balanceamento de carga de leitura.

A escolha por instâncias únicas de `etcd` e `Pgpool-II` é proposital, visando isolar o estudo na resiliência do core do banco de dados, tornando o projeto mais acessível e didático.

## Pré-requisitos

* Docker
* Docker Compose
* Python 3.10+
* WireGuard (para acesso seguro ao ambiente na nuvem)
* Acesso a um servidor na nuvem (ex: AWS, DigitalOcean, etc.)
* Para localhost, recomenda-se um hardware com suporte ao watchdog

## 🛠️ Como Executar

1.  **Clone o repositório:**
    ```bash
    git clone [https://github.com/richwrd/postgres-ha-cluster-lab](https://github.com/richwrd/postgres-ha-cluster-lab)
    cd seu-repo
    ```

2.  **Instale as dependências Python:**
    ```bash
    pip install -r scripts/requirements.txt
    ```

3.  **Suba a infraestrutura:**
    *Atenção: Garanta que sua conexão VPN (WireGuard) com o servidor da nuvem esteja ativa.*
    ```bash
    cd infra
    docker-compose up -d
    ```

4.  **Execute os testes:**
    ```bash
    python scripts/run_tests.py
    ```


## 🧠 Para Saber Mais e Exemplos Adicionais

Este projeto serve como uma base focada e didática. Se você estiver interessado em entender melhor o funcionamento interno do cluster e explorar configurações mais avançadas, os seguintes recursos são recomendados:

* **Documentação Oficial:** A leitura da documentação oficial do [Patroni](https://patroni.readthedocs.io/en/latest/) e do [Pgpool-II](https://www.pgpool.net/docs/latest/pt/html/index.html) é fundamental para compreender todos os parâmetros e possibilidades.

* **Experimentação Prática:** A realização de experimentos práticos com diferentes configurações é a melhor forma de solidificar o conhecimento. Você pode usar este repositório como ponto de partida.

* **Exemplo de Arquitetura com HA Completo:** Para uma implementação mais complexa, que inclui alta disponibilidade também nos nós de `etcd` e `Pgpool-II`, um exemplo prático foi produzido e pode ser encontrado no link abaixo:
    * **[https://github.com/richwrd/postgres-ha-monitor](https://github.com/richwrd/postgres-ha-monitor)**