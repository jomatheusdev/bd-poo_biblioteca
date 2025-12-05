const pool = require('../config/db');

// ============================================================================
// CRUD DE USUÁRIOS
// ============================================================================

// Listar todos os usuários
exports.listarUsuarios = async (req, res) => {
  try {
    const resultado = await pool.query(
      'SELECT * FROM usuario ORDER BY usuario_id'
    );
    res.json({
      sucesso: true,
      total: resultado.rows.length,
      dados: resultado.rows
    });
  } catch (erro) {
    console.error('Erro ao listar usuários:', erro);
    res.status(500).json({
      sucesso: false,
      mensagem: 'Erro ao listar usuários',
      erro: erro.message
    });
  }
};

// Buscar usuário por ID
exports.buscarUsuarioPorId = async (req, res) => {
  try {
    const { id } = req.params;
    const resultado = await pool.query(
      'SELECT * FROM usuario WHERE usuario_id = $1',
      [id]
    );
    
    if (resultado.rows.length === 0) {
      return res.status(404).json({
        sucesso: false,
        mensagem: 'Usuário não encontrado'
      });
    }

    res.json({
      sucesso: true,
      dados: resultado.rows[0]
    });
  } catch (erro) {
    console.error('Erro ao buscar usuário:', erro);
    res.status(500).json({
      sucesso: false,
      mensagem: 'Erro ao buscar usuário',
      erro: erro.message
    });
  }
};

// Criar novo usuário
exports.criarUsuario = async (req, res) => {
  try {
    const { nome, email, cpf, tipo } = req.body;

    // Validação básica
    if (!nome || !email || !cpf || !tipo) {
      return res.status(400).json({
        sucesso: false,
        mensagem: 'Campos obrigatórios: nome, email, cpf, tipo'
      });
    }

    const resultado = await pool.query(
      `INSERT INTO usuario (nome, email, cpf, tipo) 
       VALUES ($1, $2, $3, $4) 
       RETURNING *`,
      [nome, email, cpf, tipo]
    );

    res.status(201).json({
      sucesso: true,
      mensagem: 'Usuário criado com sucesso',
      dados: resultado.rows[0]
    });
  } catch (erro) {
    console.error('Erro ao criar usuário:', erro);
    
    // Tratamento de erros específicos do PostgreSQL
    if (erro.code === '23505') { // Violação de unique constraint
      return res.status(400).json({
        sucesso: false,
        mensagem: 'Email ou CPF já cadastrado'
      });
    }

    res.status(500).json({
      sucesso: false,
      mensagem: 'Erro ao criar usuário',
      erro: erro.message
    });
  }
};

// Atualizar usuário
exports.atualizarUsuario = async (req, res) => {
  try {
    const { id } = req.params;
    const { nome, email, cpf, tipo, ativo } = req.body;

    const resultado = await pool.query(
      `UPDATE usuario 
       SET nome = COALESCE($1, nome),
           email = COALESCE($2, email),
           cpf = COALESCE($3, cpf),
           tipo = COALESCE($4, tipo),
           ativo = COALESCE($5, ativo)
       WHERE usuario_id = $6
       RETURNING *`,
      [nome, email, cpf, tipo, ativo, id]
    );

    if (resultado.rows.length === 0) {
      return res.status(404).json({
        sucesso: false,
        mensagem: 'Usuário não encontrado'
      });
    }

    res.json({
      sucesso: true,
      mensagem: 'Usuário atualizado com sucesso',
      dados: resultado.rows[0]
    });
  } catch (erro) {
    console.error('Erro ao atualizar usuário:', erro);
    res.status(500).json({
      sucesso: false,
      mensagem: 'Erro ao atualizar usuário',
      erro: erro.message
    });
  }
};

// Deletar usuário
exports.deletarUsuario = async (req, res) => {
  try {
    const { id } = req.params;

    const resultado = await pool.query(
      'DELETE FROM usuario WHERE usuario_id = $1 RETURNING *',
      [id]
    );

    if (resultado.rows.length === 0) {
      return res.status(404).json({
        sucesso: false,
        mensagem: 'Usuário não encontrado'
      });
    }

    res.json({
      sucesso: true,
      mensagem: 'Usuário deletado com sucesso',
      dados: resultado.rows[0]
    });
  } catch (erro) {
    console.error('Erro ao deletar usuário:', erro);
    
    // Tratamento de constraint de integridade referencial
    if (erro.code === '23503') {
      return res.status(400).json({
        sucesso: false,
        mensagem: 'Não é possível deletar usuário com empréstimos ou multas vinculadas'
      });
    }

    res.status(500).json({
      sucesso: false,
      mensagem: 'Erro ao deletar usuário',
      erro: erro.message
    });
  }
};

// ============================================================================
// ENDPOINTS ESPECÍFICOS DA FASE 2 - FUNÇÃO
// ============================================================================

// Obter total de multas abertas de um usuário (usa fn_total_multas_abertas_usuario)
exports.obterTotalMultasAbertas = async (req, res) => {
  try {
    const { id } = req.params;

    // Verifica se o usuário existe
    const usuarioExiste = await pool.query(
      'SELECT usuario_id FROM usuario WHERE usuario_id = $1',
      [id]
    );

    if (usuarioExiste.rows.length === 0) {
      return res.status(404).json({
        sucesso: false,
        mensagem: 'Usuário não encontrado'
      });
    }

    // Chama a função do banco
    const resultado = await pool.query(
      'SELECT fn_total_multas_abertas_usuario($1) AS total',
      [id]
    );

    res.json({
      sucesso: true,
      usuario_id: parseInt(id),
      total_multas_abertas: parseFloat(resultado.rows[0].total),
      mensagem: 'Total de multas abertas calculado pela função do banco'
    });
  } catch (erro) {
    console.error('Erro ao obter total de multas:', erro);
    res.status(500).json({
      sucesso: false,
      mensagem: 'Erro ao obter total de multas abertas',
      erro: erro.message
    });
  }
};
