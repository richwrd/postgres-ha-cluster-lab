-- Cria o usuário com a senha desejada
CREATE USER healthchecker WITH PASSWORD 'strong_password';

-- Permite apenas conectar no banco "postgres"
GRANT CONNECT ON DATABASE postgres TO healthchecker;

-- Permite uso do schema "public" (necessário para SELECT)
GRANT USAGE ON SCHEMA public TO healthchecker;

-- Dá permissão de leitura (SELECT) em todas as tabelas já existentes
GRANT SELECT ON ALL TABLES IN SCHEMA public TO healthchecker;

-- Garante que futuras tabelas no schema "public" também possam ser lidas
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT ON TABLES TO healthchecker;