const express = require('express');
const usuarioRoutes = require('./routes/usuarioRoutes');
const emprestimoRoutes = require('./routes/emprestimoRoutes');

const app = express();

// ============================================================================
// MIDDLEWARES
// ============================================================================

// Parse JSON
app.use(express.json());

// Parse URL-encoded
app.use(express.urlencoded({ extended: true }));

// Logs de requisições
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// ============================================================================
// ROTA RAIZ
// ============================================================================

app.get('/', (req, res) => {
  res.json({
    mensagem: 'API Sistema de Biblioteca Universitária - Fase 2',
    versao: '2.0.0',
    documentacao: {
      usuarios: '/api/usuarios',
      emprestimos: '/api/emprestimos',
      funcoes: [
        'GET /api/usuarios/:id/multas/total - Chama fn_total_multas_abertas_usuario()',
        'GET /api/emprestimos/:id/multa - Chama fn_calcular_multa_atraso()'
      ],
      procedures: [
        'POST /api/emprestimos/:id/devolucao - Chama prc_registrar_devolucao()'
      ],
      triggers: [
        'POST /api/emprestimos - Dispara trg_emprestimo_validacao (validação)',
        'POST/PUT /api/emprestimos - Dispara trg_emprestimo_auditoria (auditoria + atualização de estado)'
      ],
      auditoria: 'GET /api/emprestimos/auditoria/logs'
    }
  });
});

// ============================================================================
// ROTAS DA API
// ============================================================================

app.use('/api/usuarios', usuarioRoutes);
app.use('/api/emprestimos', emprestimoRoutes);

// ============================================================================
// TRATAMENTO DE ERROS 404
// ============================================================================

app.use((req, res) => {
  res.status(404).json({
    sucesso: false,
    mensagem: 'Rota não encontrada',
    rota: req.path
  });
});

// ============================================================================
// TRATAMENTO DE ERROS GERAIS
// ============================================================================

app.use((erro, req, res, next) => {
  console.error('Erro não tratado:', erro);
  res.status(500).json({
    sucesso: false,
    mensagem: 'Erro interno do servidor',
    erro: erro.message
  });
});

module.exports = app;
