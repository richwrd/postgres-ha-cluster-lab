# 📄 Configuração do Cluster Patroni PostgreSQL

## 🌟 Visão Geral

Este diretório contém a configuração para implantar um cluster PostgreSQL de **Alta Disponibilidade (HA)** utilizando Patroni e Docker Compose.

A abordagem de configuração foi projetada para ser robusta, segura e extremamente flexível, permitindo o uso em diferentes ambientes (desenvolvimento, produção) com o mínimo de alterações.

## 🏛️ Filosofia de Configuração: Planta e Acabamentos

Este projeto adota uma filosofia de **"Planta e Acabamentos"** para máxima clareza e segurança:

1.  **A "Planta" (`patroni.yml`):**

      * É o **esqueleto arquitetônico** do nosso cluster. Contém todas as configurações estruturais e de performance que são estáveis e compartilhadas entre todos os nós.
      * Este arquivo possui valores padrão seguros, permitindo que funcione "sozinho", mas foi projetado para ser "personalizado" pelos acabamentos.
      * Este arquivo **pode e deve** ser versionado no Git.

2.  **Os "Acabamentos" (Arquivos `.env`):**

      * Contêm os **detalhes, segredos e configurações específicas** do ambiente. É aqui que você define senhas, nomes de cluster e ajusta a performance para um ambiente específico.
      * Estes arquivos **NUNCA** devem ser versionados no Git.

## 📂 Estrutura dos Arquivos

### blueprints `patroni.yml`

  * **Função:** A "Planta" do cluster.
  * **Contém:** Configurações de performance (`shared_buffers`, etc.), regras de bootstrap, `pg_hba` e a estrutura geral do Patroni.
  * **Flexibilidade:** Utiliza a sintaxe `${VARIAVEL:-valor_padrão}`. Isso significa que ele usará um valor padrão seguro, a menos que uma variável de ambiente com o mesmo nome seja fornecida.

### 🔑 `config/.patroni.env`

  * **Função:** Os "Acabamentos" compartilhados por todos os nós do cluster.
  * **Contém:** **Segredos** (senhas de superusuário, replicação, API) e configurações que se aplicam a todos os nós em um ambiente específico (ex: `PATRONI_SCOPE`, `PATRONI_ETCD3_HOSTS`).

### 🐳 `docker-compose.yaml`

  * **Função:** O orquestrador que monta o cluster.
  * **Contém:** A definição dos serviços (nós do Patroni, etcd, etc.). É lá que definimos a **identidade única** de cada nó do cluster (como o nome do contêiner), que não pode ser compartilhada.
  * **Exemplo:** A variável `PATRONI_NAME` é definida na seção `environment` de cada serviço dentro deste arquivo, pois cada nó deve ter um nome exclusivo.

## 🥇 Hierarquia de Configuração (Regra de Prioridade)

É fundamental entender que, se uma configuração for definida em múltiplos lugares, o Patroni sempre priorizará a variável de ambiente. A ordem é:

1.  **Máxima Prioridade:** Variáveis na seção `environment` de um serviço no `docker-compose.yaml`. (Ex: `PATRONI_NAME`).
2.  **Média Prioridade:** Variáveis carregadas pelo `env_file` (seu `config/patroni.env`).
3.  **Baixa Prioridade:** Os valores padrão definidos diretamente no arquivo `patroni.yml`.

Em resumo: **o que está nos arquivos `.env` sempre sobrescreve o que está na "planta" (`patroni.yml`)**.

## 🚀 Como Usar

A utilização é projetada para ser o mais simples possível:

1.  **(Opcional) Revise a "Planta"**: Entenda as configurações padrão e de performance no arquivo `patroni.yml`. Em geral, você não precisará alterá-lo.
2.  **✅ Personalize os "Acabamentos"**: Este é o passo principal. Abra o arquivo `config/.patroni.env` e ajuste as senhas, o nome do cluster (`PATRONI_SCOPE`) e os parâmetros de performance conforme a necessidade do seu ambiente.
3.  **🚀 Implante o Cluster**: Execute o comando para subir os serviços.
    ```bash
    docker-compose up -d
    ```

O Docker Compose cuidará de injetar as variáveis nos contêineres corretos, e o Patroni aplicará a configuração final com a hierarquia correta.