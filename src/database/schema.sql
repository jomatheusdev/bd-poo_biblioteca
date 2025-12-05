-- =============================================================================
-- SISTEMA DE BIBLIOTECA UNIVERSITÁRIA - FASE 2
-- Schema Completo com Triggers, Functions e Procedures
-- =============================================================================

-- Criação do Banco de Dados
CREATE DATABASE biblioteca_universitaria;

\c biblioteca_universitaria;

-- =============================================================================
-- TABELAS PRINCIPAIS
-- =============================================================================

-- Tabela: Usuario
CREATE TABLE usuario (
    usuario_id BIGSERIAL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    cpf VARCHAR(14) NOT NULL UNIQUE,
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('aluno', 'professor', 'funcionario')),
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    data_cadastro TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_usuario_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Tabela: Autor
CREATE TABLE autor (
    autor_id BIGSERIAL PRIMARY KEY,
    nome VARCHAR(150) NOT NULL,
    nacionalidade VARCHAR(50),
    data_nascimento DATE
);

-- Tabela: Livro
CREATE TABLE livro (
    livro_id BIGSERIAL PRIMARY KEY,
    isbn VARCHAR(20) NOT NULL UNIQUE,
    titulo VARCHAR(200) NOT NULL,
    editora VARCHAR(100),
    ano_publicacao INTEGER CHECK (ano_publicacao > 1500 AND ano_publicacao <= EXTRACT(YEAR FROM CURRENT_DATE)),
    categoria VARCHAR(50) NOT NULL,
    total_exemplares INTEGER NOT NULL DEFAULT 0 CHECK (total_exemplares >= 0)
);

-- Tabela: Livro_Autor (Relacionamento N:N)
CREATE TABLE livro_autor (
    livro_id BIGINT NOT NULL,
    autor_id BIGINT NOT NULL,
    PRIMARY KEY (livro_id, autor_id),
    CONSTRAINT fk_livro_autor_livro FOREIGN KEY (livro_id) REFERENCES livro(livro_id) ON DELETE CASCADE,
    CONSTRAINT fk_livro_autor_autor FOREIGN KEY (autor_id) REFERENCES autor(autor_id) ON DELETE CASCADE
);

-- Tabela: Exemplar
CREATE TABLE exemplar (
    exemplar_id BIGSERIAL PRIMARY KEY,
    livro_id BIGINT NOT NULL,
    codigo_exemplar VARCHAR(30) NOT NULL UNIQUE,
    estado VARCHAR(20) NOT NULL DEFAULT 'disponivel' CHECK (estado IN ('disponivel', 'emprestado', 'manutencao', 'perdido')),
    data_aquisicao DATE NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT fk_exemplar_livro FOREIGN KEY (livro_id) REFERENCES livro(livro_id) ON DELETE CASCADE
);

-- Tabela: Emprestimo
CREATE TABLE emprestimo (
    emprestimo_id BIGSERIAL PRIMARY KEY,
    usuario_id BIGINT NOT NULL,
    exemplar_id BIGINT NOT NULL,
    data_emprestimo DATE NOT NULL DEFAULT CURRENT_DATE,
    data_prevista_devolucao DATE NOT NULL,
    data_devolucao DATE,
    CONSTRAINT fk_emprestimo_usuario FOREIGN KEY (usuario_id) REFERENCES usuario(usuario_id) ON DELETE RESTRICT,
    CONSTRAINT fk_emprestimo_exemplar FOREIGN KEY (exemplar_id) REFERENCES exemplar(exemplar_id) ON DELETE RESTRICT,
    CONSTRAINT ck_emprestimo_datas CHECK (data_prevista_devolucao > data_emprestimo)
);

-- Tabela: Multa
CREATE TABLE multa (
    multa_id BIGSERIAL PRIMARY KEY,
    usuario_id BIGINT NOT NULL,
    emprestimo_id BIGINT,
    motivo VARCHAR(200) NOT NULL,
    valor NUMERIC(10,2) NOT NULL CHECK (valor >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'aberta' CHECK (status IN ('aberta', 'paga', 'cancelada')),
    data_multa DATE NOT NULL DEFAULT CURRENT_DATE,
    data_pagamento DATE,
    CONSTRAINT fk_multa_usuario FOREIGN KEY (usuario_id) REFERENCES usuario(usuario_id) ON DELETE RESTRICT,
    CONSTRAINT fk_multa_emprestimo FOREIGN KEY (emprestimo_id) REFERENCES emprestimo(emprestimo_id) ON DELETE SET NULL
);

-- Tabela: Auditoria_Emprestimo (para a Trigger de Auditoria)
CREATE TABLE auditoria_emprestimo (
    auditoria_id BIGSERIAL PRIMARY KEY,
    emprestimo_id BIGINT,
    acao VARCHAR(12) NOT NULL,
    quando TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    usuario_responsavel VARCHAR(100),
    payload JSONB
);

-- =============================================================================
-- ÍNDICES PARA PERFORMANCE
-- =============================================================================

CREATE INDEX idx_usuario_email ON usuario(email);
CREATE INDEX idx_usuario_cpf ON usuario(cpf);
CREATE INDEX idx_livro_isbn ON livro(isbn);
CREATE INDEX idx_exemplar_livro ON exemplar(livro_id);
CREATE INDEX idx_exemplar_estado ON exemplar(estado);
CREATE INDEX idx_emprestimo_usuario ON emprestimo(usuario_id);
CREATE INDEX idx_emprestimo_exemplar ON emprestimo(exemplar_id);
CREATE INDEX idx_multa_usuario ON multa(usuario_id);
CREATE INDEX idx_multa_status ON multa(status);

-- =============================================================================
-- FUNÇÕES (Functions)
-- =============================================================================

-- Função 1: Calcular multa por atraso
CREATE OR REPLACE FUNCTION fn_calcular_multa_atraso(p_emprestimo_id BIGINT)
RETURNS NUMERIC(10,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_prevista DATE;
    v_devolucao DATE;
    v_dias_atraso INTEGER;
BEGIN
    SELECT data_prevista_devolucao,
           COALESCE(data_devolucao, CURRENT_DATE)
      INTO v_prevista, v_devolucao
      FROM emprestimo
     WHERE emprestimo_id = p_emprestimo_id;

    IF NOT FOUND THEN
        RETURN 0;
    END IF;

    v_dias_atraso := GREATEST((v_devolucao - v_prevista), 0);
    
    -- R$ 2,50 por dia de atraso
    RETURN v_dias_atraso * 2.50;
END;
$$;

-- Função 2: Total de multas abertas de um usuário
CREATE OR REPLACE FUNCTION fn_total_multas_abertas_usuario(p_usuario_id BIGINT)
RETURNS NUMERIC(10,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total NUMERIC(10,2);
BEGIN
    SELECT COALESCE(SUM(valor), 0)
      INTO v_total
      FROM multa
     WHERE usuario_id = p_usuario_id
       AND status = 'aberta';

    RETURN v_total;
END;
$$;

-- =============================================================================
-- TRIGGERS
-- =============================================================================

-- TRIGGER 1: Validação de Empréstimo (BEFORE INSERT)
-- Impede empréstimos inválidos (usuário inativo, multas abertas, exemplar indisponível)

CREATE OR REPLACE FUNCTION trg_emprestimo_validacao()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_ativo BOOLEAN;
    v_estado_exemplar VARCHAR(20);
    v_total_multas NUMERIC(10,2);
BEGIN
    -- Verifica se o usuário está ativo
    SELECT u.ativo INTO v_ativo
      FROM usuario u
     WHERE u.usuario_id = NEW.usuario_id;

    IF v_ativo IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'Usuário % está inativo e não pode realizar empréstimo.', NEW.usuario_id;
    END IF;

    -- Verifica se o exemplar está disponível
    SELECT e.estado INTO v_estado_exemplar
      FROM exemplar e
     WHERE e.exemplar_id = NEW.exemplar_id;

    IF v_estado_exemplar <> 'disponivel' THEN
        RAISE EXCEPTION 'Exemplar % não está disponível (estado: %).', NEW.exemplar_id, v_estado_exemplar;
    END IF;

    -- Verifica se há multas em aberto
    SELECT COALESCE(SUM(valor), 0)
      INTO v_total_multas
      FROM multa
     WHERE usuario_id = NEW.usuario_id
       AND status = 'aberta';

    IF v_total_multas > 0 THEN
        RAISE EXCEPTION 'Usuário % possui R$ % em multas em aberto.', NEW.usuario_id, v_total_multas;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_emprestimo_validacao
BEFORE INSERT ON emprestimo
FOR EACH ROW
EXECUTE FUNCTION trg_emprestimo_validacao();

-- TRIGGER 2: Auditoria e Atualização Automática (AFTER INSERT OR UPDATE)
-- Registra logs e atualiza estado dos exemplares automaticamente

CREATE OR REPLACE FUNCTION trg_emprestimo_auditoria()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_acao VARCHAR(12);
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_acao := 'INSERIR';
        
        -- Atualiza exemplar para "emprestado"
        UPDATE exemplar 
           SET estado = 'emprestado'
         WHERE exemplar_id = NEW.exemplar_id;

    ELSIF TG_OP = 'UPDATE' THEN
        -- Detecta devolução
        IF NEW.data_devolucao IS NOT NULL
           AND (OLD.data_devolucao IS NULL OR OLD.data_devolucao <> NEW.data_devolucao) 
        THEN
            v_acao := 'DEVOLVER';
            
            -- Atualiza exemplar para "disponível"
            UPDATE exemplar 
               SET estado = 'disponivel'
             WHERE exemplar_id = NEW.exemplar_id;
        ELSE
            v_acao := 'ATUALIZAR';
        END IF;
    END IF;

    -- Registra na tabela de auditoria
    INSERT INTO auditoria_emprestimo (
        emprestimo_id, 
        acao, 
        quando, 
        usuario_responsavel, 
        payload
    ) VALUES (
        COALESCE(NEW.emprestimo_id, OLD.emprestimo_id),
        v_acao,
        CURRENT_TIMESTAMP,
        current_user,
        to_jsonb(COALESCE(NEW, OLD))
    );

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_emprestimo_auditoria
AFTER INSERT OR UPDATE ON emprestimo
FOR EACH ROW
EXECUTE FUNCTION trg_emprestimo_auditoria();

-- =============================================================================
-- PROCEDURES
-- =============================================================================

-- PROCEDURE: Registrar devolução com cálculo automático de multa
CREATE OR REPLACE PROCEDURE prc_registrar_devolucao(
    p_emprestimo_id BIGINT,
    p_usuario_responsavel VARCHAR DEFAULT 'sistema'
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_emprestimo RECORD;
    v_valor_multa NUMERIC(10,2);
BEGIN
    -- Busca dados do empréstimo
    SELECT * INTO v_emprestimo
      FROM emprestimo
     WHERE emprestimo_id = p_emprestimo_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Empréstimo % não encontrado.', p_emprestimo_id;
    END IF;

    IF v_emprestimo.data_devolucao IS NOT NULL THEN
        RAISE EXCEPTION 'Empréstimo % já foi devolvido em %.', p_emprestimo_id, v_emprestimo.data_devolucao;
    END IF;

    -- Atualiza data de devolução (dispara a trigger de auditoria)
    UPDATE emprestimo
       SET data_devolucao = CURRENT_DATE
     WHERE emprestimo_id = p_emprestimo_id;

    -- Calcula multa automaticamente
    v_valor_multa := fn_calcular_multa_atraso(p_emprestimo_id);

    -- Se houver atraso, registra a multa
    IF v_valor_multa > 0 THEN
        INSERT INTO multa (
            usuario_id, 
            emprestimo_id, 
            motivo, 
            valor, 
            status, 
            data_multa
        ) VALUES (
            v_emprestimo.usuario_id, 
            p_emprestimo_id, 
            'Atraso na devolução', 
            v_valor_multa, 
            'aberta', 
            CURRENT_DATE
        );

        RAISE NOTICE 'Multa de R$ % registrada para o usuário %.', v_valor_multa, v_emprestimo.usuario_id;
    ELSE
        RAISE NOTICE 'Devolução realizada sem multas.';
    END IF;

END;
$$;

-- =============================================================================
-- DADOS DE TESTE
-- =============================================================================

-- Inserir usuários
INSERT INTO usuario (nome, email, cpf, tipo, ativo) VALUES
('João Silva', 'joao.silva@universidade.edu.br', '123.456.789-01', 'aluno', TRUE),
('Maria Santos', 'maria.santos@universidade.edu.br', '987.654.321-02', 'professor', TRUE),
('Pedro Oliveira', 'pedro.oliveira@universidade.edu.br', '111.222.333-44', 'aluno', FALSE);

-- Inserir autores
INSERT INTO autor (nome, nacionalidade, data_nascimento) VALUES
('Machado de Assis', 'Brasileira', '1839-06-21'),
('Clarice Lispector', 'Brasileira', '1920-12-10'),
('Jorge Amado', 'Brasileira', '1912-08-10');

-- Inserir livros
INSERT INTO livro (isbn, titulo, editora, ano_publicacao, categoria, total_exemplares) VALUES
('978-85-359-0277-1', 'Dom Casmurro', 'Editora Nova Fronteira', 1899, 'Romance', 3),
('978-85-254-1926-4', 'A Hora da Estrela', 'Rocco', 1977, 'Romance', 2),
('978-85-325-2186-8', 'Capitães da Areia', 'Companhia das Letras', 1937, 'Romance', 2);

-- Relacionar livros e autores
INSERT INTO livro_autor (livro_id, autor_id) VALUES
(1, 1),
(2, 2),
(3, 3);

-- Inserir exemplares
INSERT INTO exemplar (livro_id, codigo_exemplar, estado) VALUES
(1, 'DOM-001', 'disponivel'),
(1, 'DOM-002', 'disponivel'),
(1, 'DOM-003', 'disponivel'),
(2, 'HOR-001', 'disponivel'),
(2, 'HOR-002', 'disponivel'),
(3, 'CAP-001', 'disponivel'),
(3, 'CAP-002', 'manutencao');

-- =============================================================================
-- FIM DO SCRIPT
-- =============================================================================
