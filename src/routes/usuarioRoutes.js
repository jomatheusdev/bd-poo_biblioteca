const express = require('express');
const router = express.Router();
const usuarioController = require('../controllers/usuarioController');

// ============================================================================
// ROTAS CRUD DE USUÁRIOS
// ============================================================================

// Listar todos os usuários
router.get('/', usuarioController.listarUsuarios);

// Buscar usuário por ID
router.get('/:id', usuarioController.buscarUsuarioPorId);

// Criar novo usuário
router.post('/', usuarioController.criarUsuario);

// Atualizar usuário
router.put('/:id', usuarioController.atualizarUsuario);

// Deletar usuário
router.delete('/:id', usuarioController.deletarUsuario);

// ============================================================================
// ROTA ESPECÍFICA DA FASE 2 - FUNÇÃO
// ============================================================================

// Obter total de multas abertas (usa fn_total_multas_abertas_usuario)
router.get('/:id/multas/total', usuarioController.obterTotalMultasAbertas);

module.exports = router;
