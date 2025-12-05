-- =====================================================================
-- TESTES COMPLETOS DO PROJETO – BIBLIOTECA UNIVERSITÁRIA - FASE 2
-- Inclui testes de: Funções, Triggers, Procedure e Integridade
-- =====================================================================
-- 
-- INSTRUÇÕES DE USO:
-- 1. Execute o schema.sql primeiro para criar as tabelas e dados iniciais
-- 2. Execute este arquivo no pgAdmin para testar todas as funcionalidades
-- 3. Analise os resultados esperados vs obtidos
--
-- =====================================================================

-- ============================================================
-- 1. TESTE DA FUNÇÃO: fn_calcular_multa_atraso
-- Objetivo: Garantir que a função calcula R$ 2,50/dia de atraso
-- ============================================================

-- 1.1 Criar um empréstimo em atraso (data prevista no passado)
INSERT INTO emprestimo (usuario_id, exemplar_id, data_emprestimo, data_prevista_devolucao, data_devolucao)
VALUES (1, 1, '2025-11-01', '2025-11-15', '2025-11-20');
-- Esperado: 5 dias de atraso (20 - 15)

-- 1.2 Ver o valor da multa calculada pela função
SELECT fn_calcular_multa_atraso(1) AS valor_multa_calculada;
-- Esperado: 12.50 (5 dias * R$ 2,50)

-- 1.3 Testar com empréstimo sem atraso
INSERT INTO emprestimo (usuario_id, exemplar_id, data_emprestimo, data_prevista_devolucao, data_devolucao)
VALUES (2, 2, '2025-11-01', '2025-11-15', '2025-11-10');

SELECT fn_calcular_multa_atraso(2) AS valor_multa_sem_atraso;
-- Esperado: 0.00 (sem atraso)

-- 1.4 Testar com empréstimo ainda não devolvido (usa CURRENT_DATE)
INSERT INTO emprestimo (usuario_id, exemplar_id, data_emprestimo, data_prevista_devolucao)
VALUES (1, 3, '2025-11-01', '2025-11-15');

SELECT fn_calcular_multa_atraso(3) AS valor_multa_emprestimo_aberto;
-- Esperado: Calcula atraso até hoje (variável conforme data atual)


-- ============================================================
-- 2. TESTE DA FUNÇÃO: fn_total_multas_abertas_usuario
-- Objetivo: Confirmar o total de multas abertas de um usuário
-- ============================================================

-- 2.1 Criar multas para o usuário 1
INSERT INTO multa (usuario_id, emprestimo_id, motivo, valor, status)
VALUES (1, 1, 'Atraso na devolução', 50.00, 'aberta');

INSERT INTO multa (usuario_id, emprestimo_id, motivo, valor, status)
VALUES (1, 1, 'Livro danificado', 30.00, 'aberta');

INSERT INTO multa (usuario_id, emprestimo_id, motivo, valor, status)
VALUES (1, 1, 'Multa antiga', 20.00, 'paga');

-- 2.2 Ver total de multas abertas do usuário 1
SELECT fn_total_multas_abertas_usuario(1) AS total_multas_abertas;
-- Esperado: 80.00 (50 + 30, ignorando a multa paga)

-- 2.3 Testar usuário sem multas
SELECT fn_total_multas_abertas_usuario(2) AS total_multas_usuario2;
-- Esperado: 0.00


-- ============================================================
-- 3. TESTE DA TRIGGER: trg_emprestimo_validacao
-- Objetivo: Impedir empréstimos inválidos
-- ============================================================

-- 3.1 Cenário 1: Usuário INATIVO tentando fazer empréstimo
-- O usuário 3 (Pedro Oliveira) está inativo
INSERT INTO emprestimo (usuario_id, exemplar_id, data_emprestimo, data_prevista_devolucao)
VALUES (3, 4, CURRENT_DATE, CURRENT_DATE + 14);
-- Esperado: ERRO
-- "Usuário 3 está inativo e não pode realizar empréstimo."

-- 3.2 Cenário 2: Exemplar INDISPONÍVEL (já emprestado)
-- Primeiro, criar um empréstimo válido
INSERT INTO emprestimo (usuario_id, exemplar_id, data_emprestimo, data_prevista_devolucao)
VALUES (1, 4, CURRENT_DATE, CURRENT_DATE + 14);
-- Esperado: SUCESSO (exemplar fica "emprestado" pela trigger de auditoria)

-- Agora tentar emprestar o mesmo exemplar novamente
INSERT INTO emprestimo (usuario_id, exemplar_id, data_emprestimo, data_prevista_devolucao)
VALUES (2, 4, CURRENT_DATE, CURRENT_DATE + 14);
-- Esperado: ERRO
-- "Exemplar 4 não está disponível (estado: emprestado)."

-- 3.3 Cenário 3: Usuário com MULTAS EM ABERTO
-- Usuário 1 já tem multas (criadas no teste anterior)
INSERT INTO emprestimo (usuario_id, exemplar_id, data_emprestimo, data_prevista_devolucao)
VALUES (1, 5, CURRENT_DATE, CURRENT_DATE + 14);
-- Esperado: ERRO
-- "Usuário 1 possui R$ 80.00 em multas em aberto."


-- ============================================================
-- 4. TESTE DA TRIGGER: trg_emprestimo_auditoria
-- Objetivo: Verificar logs automáticos e atualização do estado do exemplar
-- ============================================================

-- 4.1 Verificar auditoria após INSERT
-- A trigger já foi disparada nos empréstimos anteriores
SELECT * FROM auditoria_emprestimo WHERE acao = 'INSERIR' ORDER BY quando DESC LIMIT 5;
-- Esperado: Registros com ação='INSERIR' e payload contendo dados do empréstimo

-- 4.2 Verificar se o exemplar foi marcado como "emprestado"
SELECT exemplar_id, codigo_exemplar, estado 
FROM exemplar 
WHERE exemplar_id = 4;
-- Esperado: estado = 'emprestado'

-- 4.3 Atualizar empréstimo (registrar devolução manual)
UPDATE emprestimo 
SET data_devolucao = CURRENT_DATE 
WHERE emprestimo_id = 4;

-- 4.4 Verificar auditoria após UPDATE (devolução)
SELECT * FROM auditoria_emprestimo WHERE acao = 'DEVOLVER' ORDER BY quando DESC LIMIT 1;
-- Esperado: Registro com ação='DEVOLVER'

-- 4.5 Verificar se o exemplar voltou a ficar "disponível"
SELECT exemplar_id, codigo_exemplar, estado 
FROM exemplar 
WHERE exemplar_id = 4;
-- Esperado: estado = 'disponivel'


-- ============================================================
-- 5. TESTE DA PROCEDURE: prc_registrar_devolucao
-- Objetivo: Registrar devolução e calcular multa automaticamente
-- ============================================================

-- 5.1 Limpar multas do usuário 1 para teste limpo
DELETE FROM multa WHERE usuario_id = 1;

-- 5.2 Criar empréstimo em atraso
INSERT INTO emprestimo (usuario_id, exemplar_id, data_emprestimo, data_prevista_devolucao)
VALUES (2, 5, '2025-11-01', '2025-11-20')
RETURNING emprestimo_id;
-- Suponha que retornou emprestimo_id = 5

-- 5.3 Executar a procedure de devolução
CALL prc_registrar_devolucao(5, 'bibliotecario_joao');
-- Esperado:
-- - data_devolucao preenchida com CURRENT_DATE
-- - Multa criada automaticamente (se houver atraso)
-- - Mensagem: "Multa de R$ X registrada para o usuário 2" OU "Devolução realizada sem multas"

-- 5.4 Validar resultado
SELECT * FROM emprestimo WHERE emprestimo_id = 5;
-- Esperado: data_devolucao preenchida

SELECT * FROM multa WHERE emprestimo_id = 5;
-- Esperado: Multa registrada (se data atual > 2025-11-20)

-- 5.5 Verificar auditoria
SELECT * FROM auditoria_emprestimo WHERE emprestimo_id = 5 ORDER BY quando DESC;
-- Esperado: Registro de DEVOLVER

-- 5.6 Testar erro: tentar devolver novamente
CALL prc_registrar_devolucao(5, 'bibliotecario_maria');
-- Esperado: ERRO
-- "Empréstimo 5 já foi devolvido em [data]."


-- ============================================================
-- 6. TESTE DE INTEGRIDADE DE DADOS
-- Validar constraints CHECK, FK, UNIQUE
-- ============================================================

-- 6.1 Tentar inserir EMAIL duplicado
INSERT INTO usuario (nome, email, cpf, tipo)
VALUES ('Teste Duplicado', 'joao.silva@universidade.edu.br', '999.888.777-66', 'aluno');
-- Esperado: ERRO UNIQUE CONSTRAINT (email já existe)

-- 6.2 Tentar inserir CPF duplicado
INSERT INTO usuario (nome, email, cpf, tipo)
VALUES ('Outro Teste', 'teste@universidade.edu.br', '123.456.789-01', 'aluno');
-- Esperado: ERRO UNIQUE CONSTRAINT (CPF já existe)

-- 6.3 Tentar inserir tipo de usuário inválido
INSERT INTO usuario (nome, email, cpf, tipo)
VALUES ('Teste Tipo', 'tipo@universidade.edu.br', '555.444.333-22', 'visitante');
-- Esperado: ERRO CHECK CONSTRAINT (tipo deve ser: aluno, professor ou funcionario)

-- 6.4 Tentar inserir email com formato inválido
INSERT INTO usuario (nome, email, cpf, tipo)
VALUES ('Teste Email', 'email_invalido', '666.777.888-99', 'aluno');
-- Esperado: ERRO CHECK CONSTRAINT (email não é válido)

-- 6.5 Tentar inserir ISBN duplicado
INSERT INTO livro (isbn, titulo, editora, ano_publicacao, categoria, total_exemplares)
VALUES ('978-85-359-0277-1', 'Livro Duplicado', 'Editora Teste', 2020, 'Teste', 1);
-- Esperado: ERRO UNIQUE CONSTRAINT (ISBN já existe)

-- 6.6 Tentar inserir ano de publicação inválido
INSERT INTO livro (isbn, titulo, editora, ano_publicacao, categoria, total_exemplares)
VALUES ('978-00-000-0000-0', 'Livro do Futuro', 'Editora Teste', 2030, 'Ficção', 1);
-- Esperado: ERRO CHECK CONSTRAINT (ano > ano atual)

-- 6.7 Tentar inserir livro com ano muito antigo
INSERT INTO livro (isbn, titulo, editora, ano_publicacao, categoria, total_exemplares)
VALUES ('978-11-111-1111-1', 'Livro Antigo', 'Editora Teste', 1400, 'História', 1);
-- Esperado: ERRO CHECK CONSTRAINT (ano < 1500)

-- 6.8 Tentar inserir total_exemplares negativo
INSERT INTO livro (isbn, titulo, editora, ano_publicacao, categoria, total_exemplares)
VALUES ('978-22-222-2222-2', 'Livro Negativo', 'Editora Teste', 2020, 'Teste', -5);
-- Esperado: ERRO CHECK CONSTRAINT (total_exemplares >= 0)

-- 6.9 Tentar inserir multa com valor negativo
INSERT INTO multa (usuario_id, motivo, valor, status)
VALUES (1, 'Teste Negativo', -10.00, 'aberta');
-- Esperado: ERRO CHECK CONSTRAINT (valor >= 0)

-- 6.10 Tentar inserir empréstimo com data prevista menor que data empréstimo
INSERT INTO emprestimo (usuario_id, exemplar_id, data_emprestimo, data_prevista_devolucao)
VALUES (2, 6, '2025-12-10', '2025-12-05');
-- Esperado: ERRO CHECK CONSTRAINT (data_prevista_devolucao > data_emprestimo)

-- 6.11 Tentar inserir estado de exemplar inválido
INSERT INTO exemplar (livro_id, codigo_exemplar, estado)
VALUES (1, 'TEST-999', 'vendido');
-- Esperado: ERRO CHECK CONSTRAINT (estado deve ser: disponivel, emprestado, manutencao ou perdido)

-- 6.12 Tentar inserir status de multa inválido
INSERT INTO multa (usuario_id, motivo, valor, status)
VALUES (1, 'Teste Status', 10.00, 'em_analise');
-- Esperado: ERRO CHECK CONSTRAINT (status deve ser: aberta, paga ou cancelada)


-- ============================================================
-- 7. TESTES DE INTEGRIDADE REFERENCIAL (FOREIGN KEYS)
-- ============================================================

-- 7.1 Tentar criar empréstimo com usuário inexistente
INSERT INTO emprestimo (usuario_id, exemplar_id, data_emprestimo, data_prevista_devolucao)
VALUES (999, 1, CURRENT_DATE, CURRENT_DATE + 14);
-- Esperado: ERRO FK CONSTRAINT (usuario_id não existe)

-- 7.2 Tentar criar empréstimo com exemplar inexistente
INSERT INTO emprestimo (usuario_id, exemplar_id, data_emprestimo, data_prevista_devolucao)
VALUES (1, 999, CURRENT_DATE, CURRENT_DATE + 14);
-- Esperado: ERRO FK CONSTRAINT (exemplar_id não existe)

-- 7.3 Tentar deletar usuário com empréstimos ativos
DELETE FROM usuario WHERE usuario_id = 1;
-- Esperado: ERRO FK CONSTRAINT ON DELETE RESTRICT
-- (não pode deletar usuário com empréstimos)

-- 7.4 Tentar deletar usuário com multas
DELETE FROM usuario WHERE usuario_id = 2;
-- Esperado: ERRO FK CONSTRAINT ON DELETE RESTRICT
-- (não pode deletar usuário com multas)


-- ============================================================
-- 8. TESTES DE CENÁRIOS COMPLETOS (FLUXO REAL)
-- ============================================================

-- 8.1 CENÁRIO: Empréstimo completo com devolução no prazo
-- Ativar usuário 3 para este teste
UPDATE usuario SET ativo = TRUE WHERE usuario_id = 3;

-- Passo 1: Criar empréstimo
INSERT INTO emprestimo (usuario_id, exemplar_id, data_emprestimo, data_prevista_devolucao)
VALUES (3, 6, CURRENT_DATE, CURRENT_DATE + 14)
RETURNING emprestimo_id;
-- Suponha que retornou emprestimo_id = 6

-- Passo 2: Verificar que exemplar ficou emprestado
SELECT estado FROM exemplar WHERE exemplar_id = 6;
-- Esperado: 'emprestado'

-- Passo 3: Registrar devolução dentro do prazo
CALL prc_registrar_devolucao(6, 'bibliotecario_teste');

-- Passo 4: Verificar que NÃO houve multa
SELECT * FROM multa WHERE emprestimo_id = 6;
-- Esperado: 0 registros (nenhuma multa)

-- Passo 5: Verificar que exemplar voltou a disponível
SELECT estado FROM exemplar WHERE exemplar_id = 6;
-- Esperado: 'disponivel'


-- ============================================================
-- 9. CONSULTAS ÚTEIS PARA ANÁLISE
-- ============================================================

-- 9.1 Ver todos os empréstimos com informações completas
SELECT 
    e.emprestimo_id,
    u.nome AS usuario_nome,
    l.titulo AS livro_titulo,
    ex.codigo_exemplar,
    e.data_emprestimo,
    e.data_prevista_devolucao,
    e.data_devolucao,
    CASE 
        WHEN e.data_devolucao IS NULL THEN 'EM ABERTO'
        WHEN e.data_devolucao <= e.data_prevista_devolucao THEN 'NO PRAZO'
        ELSE 'ATRASADO'
    END AS situacao
FROM emprestimo e
JOIN usuario u ON e.usuario_id = u.usuario_id
JOIN exemplar ex ON e.exemplar_id = ex.exemplar_id
JOIN livro l ON ex.livro_id = l.livro_id
ORDER BY e.emprestimo_id;

-- 9.2 Ver todas as multas com informações completas
SELECT 
    m.multa_id,
    u.nome AS usuario_nome,
    m.motivo,
    m.valor,
    m.status,
    m.data_multa,
    m.data_pagamento,
    e.emprestimo_id,
    l.titulo AS livro_titulo
FROM multa m
JOIN usuario u ON m.usuario_id = u.usuario_id
LEFT JOIN emprestimo e ON m.emprestimo_id = e.emprestimo_id
LEFT JOIN exemplar ex ON e.exemplar_id = ex.exemplar_id
LEFT JOIN livro l ON ex.livro_id = l.livro_id
ORDER BY m.multa_id;

-- 9.3 Ver auditoria completa
SELECT 
    auditoria_id,
    emprestimo_id,
    acao,
    quando,
    usuario_responsavel,
    payload->>'usuario_id' AS usuario_id,
    payload->>'exemplar_id' AS exemplar_id
FROM auditoria_emprestimo
ORDER BY quando DESC
LIMIT 20;

-- 9.4 Resumo de empréstimos por usuário
SELECT 
    u.usuario_id,
    u.nome,
    u.tipo,
    COUNT(e.emprestimo_id) AS total_emprestimos,
    COUNT(CASE WHEN e.data_devolucao IS NULL THEN 1 END) AS emprestimos_abertos,
    COUNT(CASE WHEN e.data_devolucao IS NOT NULL THEN 1 END) AS emprestimos_devolvidos
FROM usuario u
LEFT JOIN emprestimo e ON u.usuario_id = e.usuario_id
GROUP BY u.usuario_id, u.nome, u.tipo
ORDER BY total_emprestimos DESC;

-- 9.5 Resumo de multas por usuário
SELECT 
    u.usuario_id,
    u.nome,
    COUNT(m.multa_id) AS total_multas,
    SUM(CASE WHEN m.status = 'aberta' THEN m.valor ELSE 0 END) AS total_multas_abertas,
    SUM(CASE WHEN m.status = 'paga' THEN m.valor ELSE 0 END) AS total_multas_pagas
FROM usuario u
LEFT JOIN multa m ON u.usuario_id = m.usuario_id
GROUP BY u.usuario_id, u.nome
ORDER BY total_multas_abertas DESC;

-- 9.6 Livros mais emprestados
SELECT 
    l.livro_id,
    l.titulo,
    l.isbn,
    COUNT(e.emprestimo_id) AS total_emprestimos
FROM livro l
JOIN exemplar ex ON l.livro_id = ex.livro_id
LEFT JOIN emprestimo e ON ex.exemplar_id = e.exemplar_id
GROUP BY l.livro_id, l.titulo, l.isbn
ORDER BY total_emprestimos DESC;

-- 9.7 Disponibilidade de exemplares
SELECT 
    l.titulo,
    COUNT(*) AS total_exemplares,
    COUNT(CASE WHEN ex.estado = 'disponivel' THEN 1 END) AS disponiveis,
    COUNT(CASE WHEN ex.estado = 'emprestado' THEN 1 END) AS emprestados,
    COUNT(CASE WHEN ex.estado = 'manutencao' THEN 1 END) AS em_manutencao,
    COUNT(CASE WHEN ex.estado = 'perdido' THEN 1 END) AS perdidos
FROM livro l
JOIN exemplar ex ON l.livro_id = ex.livro_id
GROUP BY l.livro_id, l.titulo
ORDER BY l.titulo;


-- ============================================================
-- 10. LIMPEZA DO AMBIENTE DE TESTES (OPCIONAL)
-- Execute apenas se quiser resetar o banco para novos testes
-- ============================================================

/*
-- ATENÇÃO: Isso apaga TODOS os dados!

-- Desabilitar triggers temporariamente para facilitar limpeza
SET session_replication_role = 'replica';

-- Apagar dados na ordem correta (respeitando FKs)
DELETE FROM auditoria_emprestimo;
DELETE FROM multa;
DELETE FROM emprestimo;
DELETE FROM exemplar;
DELETE FROM livro_autor;
DELETE FROM livro;
DELETE FROM autor;
DELETE FROM usuario;

-- Resetar sequences
ALTER SEQUENCE usuario_usuario_id_seq RESTART WITH 1;
ALTER SEQUENCE autor_autor_id_seq RESTART WITH 1;
ALTER SEQUENCE livro_livro_id_seq RESTART WITH 1;
ALTER SEQUENCE exemplar_exemplar_id_seq RESTART WITH 1;
ALTER SEQUENCE emprestimo_emprestimo_id_seq RESTART WITH 1;
ALTER SEQUENCE multa_multa_id_seq RESTART WITH 1;
ALTER SEQUENCE auditoria_emprestimo_auditoria_id_seq RESTART WITH 1;

-- Reabilitar triggers
SET session_replication_role = 'origin';

-- Recriar dados iniciais executando novamente o schema.sql
-- (a partir da seção "DADOS DE TESTE")
*/


-- ============================================================
-- FIM DOS TESTES
-- ============================================================
-- 
-- RESUMO DO QUE FOI TESTADO:
-- ✓ Função fn_calcular_multa_atraso (cálculo de R$ 2,50/dia)
-- ✓ Função fn_total_multas_abertas_usuario
-- ✓ Trigger trg_emprestimo_validacao (validações de negócio)
-- ✓ Trigger trg_emprestimo_auditoria (logs e atualização de estado)
-- ✓ Procedure prc_registrar_devolucao (devolução + multa automática)
-- ✓ Constraints CHECK (validações de domínio)
-- ✓ Constraints UNIQUE (email, cpf, isbn)
-- ✓ Constraints FOREIGN KEY (integridade referencial)
-- ✓ Cenários completos de uso real
-- ✓ Consultas de análise e relatórios
--
-- ============================================================
