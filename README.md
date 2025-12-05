# Sistema de Biblioteca Universitária - Fase 2
## Backend com Triggers, Functions e Procedures

![Node.js](https://img.shields.io/badge/Node.js-v18+-green)
![Express](https://img.shields.io/badge/Express-5.x-blue)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14+-blue)

---

## 📋 Sobre o Projeto

Este projeto implementa a **Fase 2** do Sistema de Biblioteca Universitária, integrando:

- ✅ **2 Triggers**: validação de empréstimos + auditoria automática
- ✅ **2 Functions**: cálculo de multas + total de multas abertas
- ✅ **1 Procedure**: registro de devolução com cálculo automático de multa
- ✅ **CRUD Completo**: Usuários e Empréstimos
- ✅ **Backend**: Node.js + Express + PostgreSQL

---

## 🗂️ Estrutura do Projeto

```
server/
├── src/
│   ├── config/
│   │   └── db.js                 # Configuração de conexão PostgreSQL
│   ├── controllers/
│   │   ├── usuarioController.js  # Lógica de negócio para usuários
│   │   └── emprestimoController.js # Lógica de negócio para empréstimos
│   ├── routes/
│   │   ├── usuarioRoutes.js      # Rotas CRUD de usuários
│   │   └── emprestimoRoutes.js   # Rotas CRUD de empréstimos
│   ├── database/
│   │   └── schema.sql            # Script completo do banco (tabelas + triggers + functions + procedures)
│   ├── app.js                    # Configuração do Express
│   └── server.js                 # Inicialização do servidor
├── .env.example                  # Exemplo de variáveis de ambiente
├── package.json
└── README.md
```

---

## 🚀 Instalação e Configuração

### 1. Pré-requisitos

- **Node.js** v18 ou superior
- **PostgreSQL** 14 ou superior
- **npm** ou **yarn**

### 2. Instalar Dependências

```powershell
npm install
```

Isso instalará:
- `express` - Framework web
- `pg` - Driver PostgreSQL
- `dotenv` - Variáveis de ambiente

### 3. Configurar Banco de Dados

#### 3.1. Criar o banco no PostgreSQL

```sql
-- No terminal psql ou pgAdmin:
CREATE DATABASE biblioteca_universitaria;
```

#### 3.2. Executar o script de criação

```powershell
# No terminal PowerShell (Windows):
psql -U postgres -d biblioteca_universitaria -f src/database/schema.sql
```

Ou execute manualmente o conteúdo de `src/database/schema.sql` no pgAdmin.

### 4. Configurar Variáveis de Ambiente

Copie o arquivo `.env.example` para `.env`:

```powershell
Copy-Item .env.example .env
```

Edite o arquivo `.env` com suas credenciais:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=biblioteca_universitaria
DB_USER=postgres
DB_PASSWORD=sua_senha_aqui

PORT=3000
NODE_ENV=development
```

### 5. Instalar o driver PostgreSQL

```powershell
npm install pg dotenv
```

---

## ▶️ Executar o Projeto

### Modo de Produção

```powershell
npm start
```

### Modo de Desenvolvimento (com watch)

```powershell
npm run dev
```

O servidor estará disponível em: **http://localhost:3000**

---

## 📡 Endpoints da API

### 🏠 Raiz

```
GET http://localhost:3000/
```

Retorna documentação dos endpoints disponíveis.

---

### 👤 Usuários (CRUD Completo)

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/api/usuarios` | Listar todos os usuários |
| GET | `/api/usuarios/:id` | Buscar usuário por ID |
| POST | `/api/usuarios` | Criar novo usuário |
| PUT | `/api/usuarios/:id` | Atualizar usuário |
| DELETE | `/api/usuarios/:id` | Deletar usuário |

#### 🎯 Endpoint que chama FUNCTION

```
GET /api/usuarios/:id/multas/total
```

**Descrição**: Retorna o total de multas abertas de um usuário.  
**Function SQL**: `fn_total_multas_abertas_usuario()`

**Exemplo de Resposta**:
```json
{
  "sucesso": true,
  "usuario_id": 1,
  "total_multas_abertas": 25.50,
  "mensagem": "Total de multas abertas calculado pela função do banco"
}
```

---

### 📚 Empréstimos (CRUD Completo)

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/api/emprestimos` | Listar todos os empréstimos |
| GET | `/api/emprestimos/:id` | Buscar empréstimo por ID |
| POST | `/api/emprestimos` | Criar novo empréstimo **(DISPARA TRIGGER)** |
| PUT | `/api/emprestimos/:id` | Atualizar empréstimo |
| DELETE | `/api/emprestimos/:id` | Deletar empréstimo |

#### 🎯 Endpoint que chama FUNCTION

```
GET /api/emprestimos/:id/multa
```

**Descrição**: Calcula o valor da multa por atraso.  
**Function SQL**: `fn_calcular_multa_atraso()`

**Exemplo de Resposta**:
```json
{
  "sucesso": true,
  "emprestimo_id": 5,
  "valor_multa": 12.50,
  "mensagem": "Multa calculada pela função do banco (R$ 2,50/dia)"
}
```

#### 🎯 Endpoint que chama PROCEDURE

```
POST /api/emprestimos/:id/devolucao
```

**Descrição**: Registra a devolução de um empréstimo.  
**Procedure SQL**: `prc_registrar_devolucao()`

**Body (opcional)**:
```json
{
  "usuario_responsavel": "api_backend"
}
```

**O que a procedure faz**:
1. Atualiza `data_devolucao` (dispara trigger de auditoria)
2. Calcula multa automaticamente usando `fn_calcular_multa_atraso()`
3. Registra multa se houver atraso
4. Atualiza estado do exemplar para "disponível"

**Exemplo de Resposta**:
```json
{
  "sucesso": true,
  "mensagem": "Devolução registrada com sucesso pela procedure do banco",
  "emprestimo": { ... },
  "multa_gerada": {
    "multa_id": 3,
    "valor": 7.50,
    "status": "aberta"
  }
}
```

#### 🔍 Auditoria (gerada por TRIGGER)

```
GET /api/emprestimos/auditoria/logs
```

**Descrição**: Lista os últimos 50 logs de auditoria.  
**Trigger**: `trg_emprestimo_auditoria`

---

## 🔧 Funcionalidades da Fase 2

### 🔴 Trigger 1: `trg_emprestimo_validacao` (BEFORE INSERT)

**Regras de Negócio Implementadas**:
- ❌ Impede empréstimo se usuário estiver **inativo**
- ❌ Impede empréstimo se exemplar **não estiver disponível**
- ❌ Impede empréstimo se usuário tiver **multas em aberto**

**Como testar**:
```bash
# Tente criar um empréstimo com usuário inativo:
POST /api/emprestimos
{
  "usuario_id": 3,  # usuário inativo
  "exemplar_id": 1
}

# Resposta esperada:
{
  "sucesso": false,
  "mensagem": "Empréstimo negado: Usuário 3 está inativo e não pode realizar empréstimo."
}
```

---

### 🟢 Trigger 2: `trg_emprestimo_auditoria` (AFTER INSERT OR UPDATE)

**Regras de Negócio Implementadas**:
- 📝 Registra **log de auditoria** em todas as operações
- 🔄 Atualiza **estado do exemplar** automaticamente:
  - `emprestado` ao criar empréstimo
  - `disponivel` ao devolver

**Como testar**:
```bash
# 1. Crie um empréstimo
POST /api/emprestimos
{
  "usuario_id": 1,
  "exemplar_id": 1
}

# 2. Verifique os logs de auditoria
GET /api/emprestimos/auditoria/logs

# Resposta incluirá:
{
  "acao": "INSERIR",
  "quando": "2025-12-03T10:30:00Z",
  "usuario_responsavel": "postgres"
}
```

---

### 🟦 Function 1: `fn_calcular_multa_atraso`

**Parâmetro**: `emprestimo_id`  
**Retorno**: Valor da multa (R$ 2,50/dia de atraso)

**Chamada via backend**:
```bash
GET /api/emprestimos/1/multa
```

---

### 🟦 Function 2: `fn_total_multas_abertas_usuario`

**Parâmetro**: `usuario_id`  
**Retorno**: Soma de todas as multas abertas

**Chamada via backend**:
```bash
GET /api/usuarios/1/multas/total
```

---

### 🟪 Procedure: `prc_registrar_devolucao`

**Parâmetros**: `emprestimo_id`, `usuario_responsavel`  
**Ações**:
1. Atualiza `data_devolucao`
2. Calcula multa automaticamente
3. Registra multa se houver atraso
4. Dispara trigger de auditoria

**Chamada via backend**:
```bash
POST /api/emprestimos/1/devolucao
{
  "usuario_responsavel": "api_backend"
}
```

---

## 🧪 Exemplos de Uso com cURL

### Criar Usuário

```bash
curl -X POST http://localhost:3000/api/usuarios \
  -H "Content-Type: application/json" \
  -d '{
    "nome": "Carlos Silva",
    "email": "carlos@universidade.edu.br",
    "cpf": "123.456.789-00",
    "tipo": "aluno"
  }'
```

### Criar Empréstimo (dispara trigger de validação)

```bash
curl -X POST http://localhost:3000/api/emprestimos \
  -H "Content-Type: application/json" \
  -d '{
    "usuario_id": 1,
    "exemplar_id": 1,
    "dias_emprestimo": 14
  }'
```

### Registrar Devolução (chama procedure)

```bash
curl -X POST http://localhost:3000/api/emprestimos/1/devolucao \
  -H "Content-Type: application/json" \
  -d '{
    "usuario_responsavel": "api_backend"
  }'
```

### Consultar Total de Multas (chama function)

```bash
curl http://localhost:3000/api/usuarios/1/multas/total
```

---

## 📊 Testando as Triggers Diretamente no Banco

### Teste 1: Validação de Empréstimo (usuário inativo)

```sql
-- Desative um usuário
UPDATE usuario SET ativo = FALSE WHERE usuario_id = 1;

-- Tente criar empréstimo (será bloqueado pela trigger)
INSERT INTO emprestimo (usuario_id, exemplar_id, data_prevista_devolucao)
VALUES (1, 1, '2025-12-17');

-- Erro esperado: "Usuário 1 está inativo e não pode realizar empréstimo."
```

### Teste 2: Auditoria Automática

```sql
-- Crie um empréstimo
INSERT INTO emprestimo (usuario_id, exemplar_id, data_prevista_devolucao)
VALUES (2, 2, '2025-12-17');

-- Verifique a auditoria
SELECT * FROM auditoria_emprestimo ORDER BY quando DESC LIMIT 5;

-- Verifique que o exemplar foi atualizado
SELECT estado FROM exemplar WHERE exemplar_id = 2;
-- Resultado: 'emprestado'
```

### Teste 3: Procedure de Devolução

```sql
-- Registre devolução
CALL prc_registrar_devolucao(1, 'teste_manual');

-- Verifique se houve multa
SELECT * FROM multa WHERE emprestimo_id = 1;
```

---

## 🛠️ Tecnologias Utilizadas

- **Node.js** - Ambiente de execução JavaScript
- **Express** - Framework web minimalista
- **PostgreSQL** - Banco de dados relacional
- **pg** - Driver PostgreSQL para Node.js
- **dotenv** - Gerenciamento de variáveis de ambiente

---

## 📝 Regras de Negócio Implementadas

| Código | Descrição | Implementação |
|--------|-----------|---------------|
| RB06 | Usuário deve estar ativo para empréstimos | `trg_emprestimo_validacao` |
| RB07 | Usuário com multas não pode emprestar | `trg_emprestimo_validacao` |
| RB08 | Exemplar deve estar disponível | `trg_emprestimo_validacao` |
| RF10 | Sistema mantém registros de auditoria | `trg_emprestimo_auditoria` |
| RNF05 | Mudanças de estado são automáticas | `trg_emprestimo_auditoria` |

---

## 📹 Demonstração em Vídeo

Para o vídeo, demonstre:

1. ✅ Apresentação do grupo e tema
2. ✅ Mostrar o DER atualizado
3. ✅ Executar script SQL no banco
4. ✅ Testar triggers diretamente no banco
5. ✅ Iniciar o backend (`npm start`)
6. ✅ Demonstrar CRUD via Postman/Insomnia
7. ✅ Chamar endpoint que usa function
8. ✅ Chamar endpoint que usa procedure
9. ✅ Mostrar trigger sendo disparada pelo backend
10. ✅ Verificar logs de auditoria

---

## 👥 Autores

- **Nome do Aluno 1** - Desenvolvimento do banco de dados e triggers
- **Nome do Aluno 2** - Desenvolvimento do backend e controllers
- **Nome do Aluno 3** - Documentação e testes

---

## 📄 Licença

Este projeto é parte da disciplina de Banco de Dados e Programação Orientada a Objetos.

---

## 📞 Suporte

Para dúvidas ou problemas:
- Verifique os logs do servidor no terminal
- Consulte a documentação do PostgreSQL
- Revise os comentários no código-fonte
#   b d - p o o _ b i b l i o t e c a  
 