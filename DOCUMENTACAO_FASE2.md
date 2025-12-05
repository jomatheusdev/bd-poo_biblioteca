# FASE 2 – LÓGICA DE NEGÓCIO NO BANCO + BACKEND + DEMONSTRAÇÃO EM VÍDEO

## DOCUMENTO TÉCNICO – SISTEMA DE BIBLIOTECA UNIVERSITÁRIA

---

## 1. INTRODUÇÃO

Este documento apresenta a implementação da **Fase 2** do projeto de Banco de Dados e Programação Orientada a Objetos, seguindo os requisitos estabelecidos para lógica de negócio no banco, construção de triggers, procedures e funções e consumo via backend.

O tema utilizado é **Sistema de Biblioteca Universitária**, mantendo o mesmo banco desenvolvido na Fase 1.

---

## 2. EVOLUÇÕES DA FASE 2

Nesta fase, foram implementadas rotinas de banco diretamente relacionadas às regras de negócio do sistema, além de um backend capaz de consumir essas rotinas.

### Evoluções realizadas:

- Criação de **2 triggers** de validação e auditoria  
- Implementação de **1 procedure** que executa processo completo  
- Criação de **2 funções** que retornam valores relevantes de negócio  
- Backend com **CRUD completo** para 2 entidades principais  
- Chamada de **funções e procedure** via endpoints REST  
- Atualização da documentação e DER  

---

## 3. REGRAS DE NEGÓCIO IMPLEMENTADAS

As rotinas foram desenvolvidas para suportar as seguintes regras:

| Código | Descrição | Implementação |
|--------|-----------|---------------|
| **RB06** | Usuário precisa estar ativo para realizar empréstimos | `trg_emprestimo_validacao` |
| **RB07** | Usuário com multas em aberto não pode realizar novos empréstimos | `trg_emprestimo_validacao` |
| **RB08** | Exemplar precisa estar com estado "disponível" | `trg_emprestimo_validacao` |
| **RF10** | Sistema deve manter registros de auditoria | `trg_emprestimo_auditoria` |
| **RNF05** | Mudanças no estado do exemplar devem ocorrer automaticamente | `trg_emprestimo_auditoria` |

---

## 4. ROTINAS CRIADAS NO BANCO

### 4.1. TRIGGER 1 – Validação de Empréstimo

**Nome:** `trg_emprestimo_validacao`  
**Tipo:** Trigger de validação (BEFORE INSERT)  
**Tabela:** `emprestimo`  
**Momento:** Antes de inserir um novo empréstimo  
**Regras Implementadas:** RB06, RB07, RB08  

**Objetivo:**  
Impedir empréstimos inválidos antes que sejam registrados no banco, verificando:
- Se o usuário está ativo
- Se o exemplar está disponível
- Se o usuário possui multas em aberto

**Código SQL:**

```sql
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
        RAISE EXCEPTION 'Exemplar % não está disponível (estado: %).', 
                        NEW.exemplar_id, v_estado_exemplar;
    END IF;

    -- Verifica se há multas em aberto
    SELECT COALESCE(SUM(valor), 0)
      INTO v_total_multas
      FROM multa
     WHERE usuario_id = NEW.usuario_id
       AND status = 'aberta';

    IF v_total_multas > 0 THEN
        RAISE EXCEPTION 'Usuário % possui R$ % em multas em aberto.', 
                        NEW.usuario_id, v_total_multas;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_emprestimo_validacao
BEFORE INSERT ON emprestimo
FOR EACH ROW
EXECUTE FUNCTION trg_emprestimo_validacao();
```

**Exemplo de uso:**
```sql
-- Tentativa de empréstimo com usuário inativo (será bloqueada)
INSERT INTO emprestimo (usuario_id, exemplar_id, data_prevista_devolucao)
VALUES (3, 1, '2025-12-17');

-- Erro: "Usuário 3 está inativo e não pode realizar empréstimo."
```

---

### 4.2. TRIGGER 2 – Auditoria e Atualização Automática

**Nome:** `trg_emprestimo_auditoria`  
**Tipo:** Trigger de auditoria e atualização automática (AFTER INSERT OR UPDATE)  
**Tabela:** `emprestimo`  
**Momento:** Após inserir ou atualizar um empréstimo  
**Regras Implementadas:** RF10, RNF05  

**Objetivo:**
1. Registrar logs de auditoria de todas as operações em `auditoria_emprestimo`
2. Atualizar automaticamente o estado dos exemplares:
   - **INSERT:** marca exemplar como "emprestado"
   - **UPDATE (devolução):** marca exemplar como "disponível"

**Código SQL:**

```sql
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
```

**Exemplo de uso:**
```sql
-- Criar empréstimo (dispara INSERT)
INSERT INTO emprestimo (usuario_id, exemplar_id, data_prevista_devolucao)
VALUES (1, 2, '2025-12-17');

-- Verificar auditoria
SELECT * FROM auditoria_emprestimo ORDER BY quando DESC LIMIT 1;

-- Verificar estado do exemplar (agora "emprestado")
SELECT estado FROM exemplar WHERE exemplar_id = 2;
```

---

### 4.3. FUNÇÕES IMPLEMENTADAS

#### 4.3.1. Função de Cálculo de Multa

**Nome:** `fn_calcular_multa_atraso`  
**Parâmetro:** `p_emprestimo_id BIGINT`  
**Retorno:** `NUMERIC(10,2)`  
**Objetivo:** Retornar o valor da multa de atraso para um empréstimo  
**Regra:** R$ 2,50 por dia de atraso  

**Código SQL:**

```sql
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
```

**Exemplo de uso:**
```sql
-- Calcular multa do empréstimo 1
SELECT fn_calcular_multa_atraso(1) AS valor_multa;
-- Retorna: 12.50 (5 dias de atraso × R$ 2,50)
```

---

#### 4.3.2. Função Total de Multas Abertas

**Nome:** `fn_total_multas_abertas_usuario`  
**Parâmetro:** `p_usuario_id BIGINT`  
**Retorno:** `NUMERIC(10,2)`  
**Objetivo:** Retornar o valor total de multas em aberto de um usuário  

**Código SQL:**

```sql
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
```

**Exemplo de uso:**
```sql
-- Verificar total de multas abertas do usuário 1
SELECT fn_total_multas_abertas_usuario(1) AS total_multas;
-- Retorna: 25.50
```

---

### 4.4. PROCEDURE IMPLEMENTADA

**Nome:** `prc_registrar_devolucao`  
**Parâmetros:**
- `p_emprestimo_id BIGINT` (obrigatório)
- `p_usuario_responsavel VARCHAR` (padrão: 'sistema')

**Objetivo:**  
Implementar o processo completo de devolução de um empréstimo, incluindo:
1. Atualizar a data de devolução
2. Calcular multa automaticamente (usando `fn_calcular_multa_atraso`)
3. Registrar multa na tabela `multa` se houver atraso
4. Disparar a trigger de auditoria automaticamente
5. Atualizar o estado do exemplar para "disponível"

**Código SQL:**

```sql
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
        RAISE EXCEPTION 'Empréstimo % já foi devolvido em %.', 
                        p_emprestimo_id, v_emprestimo.data_devolucao;
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

        RAISE NOTICE 'Multa de R$ % registrada para o usuário %.', 
                     v_valor_multa, v_emprestimo.usuario_id;
    ELSE
        RAISE NOTICE 'Devolução realizada sem multas.';
    END IF;

END;
$$;
```

**Exemplo de uso:**
```sql
-- Registrar devolução do empréstimo 1
CALL prc_registrar_devolucao(1, 'api_backend');

-- Verificar se houve multa gerada
SELECT * FROM multa WHERE emprestimo_id = 1;

-- Verificar log de auditoria
SELECT * FROM auditoria_emprestimo WHERE emprestimo_id = 1 ORDER BY quando DESC;

-- Verificar estado do exemplar (agora "disponível")
SELECT estado FROM exemplar WHERE exemplar_id = 
    (SELECT exemplar_id FROM emprestimo WHERE emprestimo_id = 1);
```

---

## 5. BACKEND IMPLEMENTADO

### 5.1. Tecnologias Utilizadas

- **Linguagem:** JavaScript (ES6+)
- **Ambiente:** Node.js v18+
- **Framework:** Express 5.x
- **Banco:** PostgreSQL 14+
- **Lib de Conexão:** pg (node-postgres)
- **Gerenciamento de Env:** dotenv

### 5.2. Estrutura do Projeto

```
server/
├── src/
│   ├── config/
│   │   └── db.js                 # Configuração de conexão (pool)
│   ├── controllers/
│   │   ├── usuarioController.js  # Lógica de negócio para usuários
│   │   └── emprestimoController.js # Lógica de negócio para empréstimos
│   ├── routes/
│   │   ├── usuarioRoutes.js      # Rotas CRUD de usuários
│   │   └── emprestimoRoutes.js   # Rotas CRUD de empréstimos
│   ├── database/
│   │   └── schema.sql            # Script SQL completo
│   ├── app.js                    # Configuração do Express
│   └── server.js                 # Inicialização do servidor
├── .env                          # Variáveis de ambiente
├── .env.example                  # Exemplo de configuração
├── .gitignore
├── package.json
└── README.md
```

### 5.3. Endpoints Obrigatórios

#### CRUD Completo para Usuários:

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/api/usuarios` | Listar todos |
| GET | `/api/usuarios/:id` | Buscar por ID |
| POST | `/api/usuarios` | Criar novo |
| PUT | `/api/usuarios/:id` | Atualizar |
| DELETE | `/api/usuarios/:id` | Deletar |

#### CRUD Completo para Empréstimos:

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/api/emprestimos` | Listar todos |
| GET | `/api/emprestimos/:id` | Buscar por ID |
| POST | `/api/emprestimos` | Criar novo (dispara trigger) |
| PUT | `/api/emprestimos/:id` | Atualizar |
| DELETE | `/api/emprestimos/:id` | Deletar |

#### Chamadas Obrigatórias à Fase 2:

**1. Endpoint que chama FUNÇÃO:**
```
GET /api/usuarios/:id/multas/total
```
Chama `fn_total_multas_abertas_usuario()`

**2. Endpoint que chama FUNÇÃO:**
```
GET /api/emprestimos/:id/multa
```
Chama `fn_calcular_multa_atraso()`

**3. Endpoint que chama PROCEDURE:**
```
POST /api/emprestimos/:id/devolucao
```
Chama `prc_registrar_devolucao()`

**4. Endpoint para visualizar auditoria (gerada por TRIGGER):**
```
GET /api/emprestimos/auditoria/logs
```

### 5.4. Exemplo – Chamada da Function no Backend

**Arquivo:** `src/controllers/usuarioController.js`

```javascript
const pool = require('../config/db');

// Obter total de multas abertas de um usuário
exports.obterTotalMultasAbertas = async (req, res) => {
  try {
    const { id } = req.params;

    // Chama a função do banco
    const resultado = await pool.query(
      'SELECT fn_total_multas_abertas_usuario($1) AS total',
      [id]
    );

    res.json({
      sucesso: true,
      usuario_id: parseInt(id),
      total_multas_abertas: parseFloat(resultado.rows[0].total),
      mensagem: 'Total calculado pela função do banco'
    });
  } catch (erro) {
    res.status(500).json({
      sucesso: false,
      mensagem: 'Erro ao obter total de multas',
      erro: erro.message
    });
  }
};
```

### 5.5. Exemplo – Chamada da Procedure no Backend

**Arquivo:** `src/controllers/emprestimoController.js`

```javascript
const pool = require('../config/db');

// Registrar devolução (chama procedure)
exports.registrarDevolucao = async (req, res) => {
  try {
    const { id } = req.params;
    const usuario_responsavel = req.body.usuario_responsavel || 'api_backend';

    // Chama a procedure do banco
    await pool.query(
      'CALL prc_registrar_devolucao($1, $2)',
      [id, usuario_responsavel]
    );

    // Busca dados atualizados
    const emprestimo = await pool.query(
      'SELECT * FROM emprestimo WHERE emprestimo_id = $1',
      [id]
    );

    // Verifica se houve multa gerada
    const multa = await pool.query(
      'SELECT * FROM multa WHERE emprestimo_id = $1 ORDER BY multa_id DESC LIMIT 1',
      [id]
    );

    res.json({
      sucesso: true,
      mensagem: 'Devolução registrada pela procedure',
      emprestimo: emprestimo.rows[0],
      multa_gerada: multa.rows.length > 0 ? multa.rows[0] : null
    });
  } catch (erro) {
    res.status(500).json({
      sucesso: false,
      mensagem: 'Erro ao registrar devolução',
      erro: erro.message
    });
  }
};
```

---

## 6. DEMONSTRAÇÃO EM VÍDEO (ROTEIRO SUGERIDO)

### Duração: 10-15 minutos

### Roteiro:

**1. Apresentação do Grupo e Tema (1-2 min)**
- Nome do sistema: Sistema de Biblioteca Universitária
- Problema que resolve: gestão de empréstimos, multas e auditoria
- Integrantes e suas responsabilidades

**2. Visão do Banco de Dados (2 min)**
- Mostrar DER atualizado (se houve mudanças)
- Apontar tabelas principais: usuario, exemplar, emprestimo, multa, auditoria_emprestimo
- Explicar onde entram as triggers/functions/procedure

**3. Demonstração das Rotinas no Banco (3-4 min)**

**a) Trigger de Validação:**
```sql
-- Tentar criar empréstimo com usuário inativo
INSERT INTO emprestimo (usuario_id, exemplar_id, data_prevista_devolucao)
VALUES (3, 1, '2025-12-17');
-- Erro: "Usuário 3 está inativo..."
```

**b) Função de Cálculo de Multa:**
```sql
SELECT fn_calcular_multa_atraso(1) AS valor_multa;
```

**c) Procedure de Devolução:**
```sql
CALL prc_registrar_devolucao(1, 'demonstracao_video');
SELECT * FROM auditoria_emprestimo ORDER BY quando DESC LIMIT 5;
```

**4. Demonstração do Backend (4-5 min)**

**a) Mostrar estrutura do código:**
- `src/config/db.js` (conexão)
- `src/controllers/` (lógica)
- `src/routes/` (endpoints)

**b) Iniciar o servidor:**
```powershell
npm start
```

**c) Fazer chamadas via Postman/Insomnia:**

1. **Criar usuário:**
```http
POST http://localhost:3000/api/usuarios
Content-Type: application/json

{
  "nome": "Carlos Silva",
  "email": "carlos@uni.br",
  "cpf": "111.222.333-44",
  "tipo": "aluno"
}
```

2. **Criar empréstimo (dispara trigger):**
```http
POST http://localhost:3000/api/emprestimos
Content-Type: application/json

{
  "usuario_id": 1,
  "exemplar_id": 1,
  "dias_emprestimo": 14
}
```

3. **Consultar multas (chama function):**
```http
GET http://localhost:3000/api/usuarios/1/multas/total
```

4. **Registrar devolução (chama procedure):**
```http
POST http://localhost:3000/api/emprestimos/1/devolucao
Content-Type: application/json

{
  "usuario_responsavel": "api_backend"
}
```

5. **Ver auditoria (gerada por trigger):**
```http
GET http://localhost:3000/api/emprestimos/auditoria/logs
```

**5. Conclusão (1 min)**
- Resumir o que foi implementado
- Destacar a integração entre banco e backend
- Agradecer

---

## 7. DOCUMENTAÇÃO ATUALIZADA

### 7.1. Modelo Entidade-Relacionamento (DER)

**Entidades principais:**
- USUARIO
- AUTOR
- LIVRO
- EXEMPLAR
- EMPRESTIMO
- MULTA
- AUDITORIA_EMPRESTIMO (nova, para a trigger)

**Relacionamentos:**
- USUARIO realiza EMPRESTIMO (1:N)
- USUARIO possui MULTA (1:N)
- EXEMPLAR vinculado a EMPRESTIMO (1:N)
- LIVRO possui EXEMPLAR (1:N)
- LIVRO escrito por AUTOR (N:N)

### 7.2. Mapeamento Relacional

```sql
usuario (
  usuario_id PK,
  nome,
  email UNIQUE,
  cpf UNIQUE,
  tipo,
  ativo,
  data_cadastro
)

livro (
  livro_id PK,
  isbn UNIQUE,
  titulo,
  editora,
  ano_publicacao,
  categoria,
  total_exemplares
)

exemplar (
  exemplar_id PK,
  livro_id FK -> livro,
  codigo_exemplar UNIQUE,
  estado,
  data_aquisicao
)

emprestimo (
  emprestimo_id PK,
  usuario_id FK -> usuario,
  exemplar_id FK -> exemplar,
  data_emprestimo,
  data_prevista_devolucao,
  data_devolucao
)

multa (
  multa_id PK,
  usuario_id FK -> usuario,
  emprestimo_id FK -> emprestimo,
  motivo,
  valor,
  status,
  data_multa,
  data_pagamento
)

auditoria_emprestimo (
  auditoria_id PK,
  emprestimo_id,
  acao,
  quando,
  usuario_responsavel,
  payload JSONB
)
```

---

## 8. CONCLUSÃO

Com esta Fase 2, o Sistema de Biblioteca Universitária passa a funcionar como um **ambiente completo** de regras de negócio implementadas diretamente no banco de dados e consumidas via backend REST API, garantindo:

- **Integridade:** Triggers impedem operações inválidas  
- **Rastreabilidade:** Auditoria automática de todas as operações  
- **Automação:** Estados de exemplares atualizados automaticamente  
- **Reuso:** Functions e procedures centralizadas no banco  
- **Manutenibilidade:** Código organizado com separação de responsabilidades  

---

## ANEXOS

### A. Como Executar o Projeto

1. Instalar PostgreSQL e Node.js
2. Criar o banco: `CREATE DATABASE biblioteca_universitaria;`
3. Executar script: `psql -U postgres -d biblioteca_universitaria -f src/database/schema.sql`
4. Configurar `.env` com credenciais
5. Instalar dependências: `npm install pg dotenv`
6. Iniciar servidor: `npm start`
7. Testar endpoints via Postman/Insomnia

### B. Requisitos Cumpridos

| Requisito | Status | Implementação |
|-----------|--------|---------------|
| Mínimo 2 triggers | OK | `trg_emprestimo_validacao`, `trg_emprestimo_auditoria` |
| Mínimo 2 functions | OK | `fn_calcular_multa_atraso`, `fn_total_multas_abertas_usuario` |
| Mínimo 1 procedure | OK | `prc_registrar_devolucao` |
| CRUD para 2 entidades | OK | Usuarios, Emprestimos |
| Chamada de procedure | OK | `POST /api/emprestimos/:id/devolucao` |
| Chamada de function | OK | `GET /api/usuarios/:id/multas/total` |
| Triggers acionadas pelo backend | OK | `POST /api/emprestimos` |
| Tratamento de erros | OK | Try/catch em todos os endpoints |
| Documentação atualizada | OK | README.md + este documento |

---

**Data:** 03 de dezembro de 2025  
**Versão:** 2.0  
**Status:** Completo
