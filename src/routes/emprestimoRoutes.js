const express = require('express');
const router = express.Router();
const emprestimoController = require('../controllers/emprestimoController');

// ============================================================================
// ROTAS CRUD DE EMPRÉSTIMOS
// ============================================================================

// Listar todos os empréstimos
router.get('/', emprestimoController.listarEmprestimos);

// Buscar empréstimo por ID
router.get('/:id', emprestimoController.buscarEmprestimoPorId);

// Criar novo empréstimo (DISPARA TRIGGER DE VALIDAÇÃO)
router.post('/', emprestimoController.criarEmprestimo);

// Atualizar empréstimo
router.put('/:id', emprestimoController.atualizarEmprestimo);

// Deletar empréstimo
router.delete('/:id', emprestimoController.deletarEmprestimo);

// ============================================================================
// ROTAS ESPECÍFICAS DA FASE 2
// ============================================================================

// Calcular multa de um empréstimo (usa fn_calcular_multa_atraso)
router.get('/:id/multa', emprestimoController.calcularMultaEmprestimo);

// Registrar devolução (CHAMA PROCEDURE prc_registrar_devolucao)
router.post('/:id/devolucao', emprestimoController.registrarDevolucao);

// Listar auditoria (gerada por TRIGGER)
router.get('/auditoria/logs', emprestimoController.listarAuditoria);

module.exports = router;
