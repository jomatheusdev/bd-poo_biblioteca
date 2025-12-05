const pool = require('../config/db');

// ============================================================================
// CRUD DE EMPRÉSTIMOS
// ============================================================================

// Listar todos os empréstimos
exports.listarEmprestimos = async (req, res) => {
  try {
    const resultado = await pool.query(
      `SELECT e.*, 
              u.nome AS usuario_nome,
              ex.codigo_exemplar,
              l.titulo AS livro_titulo
       FROM emprestimo e
       JOIN usuario u ON e.usuario_id = u.usuario_id
       JOIN exemplar ex ON e.exemplar_id = ex.exemplar_id
       JOIN livro l ON ex.livro_id = l.livro_id
       ORDER BY e.emprestimo_id DESC`
    );

    res.json({
      sucesso: true,
      total: resultado.rows.length,
      dados: resultado.rows
    });
  } catch (erro) {
    console.error('Erro ao listar empréstimos:', erro);
    res.status(500).json({
      sucesso: false,
      mensagem: 'Erro ao listar empréstimos',
      erro: erro.message
    });
  }
};

// Buscar empréstimo por ID
exports.buscarEmprestimoPorId = async (req, res) => {
  try {
    const { id } = req.params;
    const resultado = await pool.query(
      `SELECT e.*, 
              u.nome AS usuario_nome,
              u.email AS usuario_email,
              ex.codigo_exemplar,
              ex.estado AS exemplar_estado,
              l.titulo AS livro_titulo,
              l.isbn AS livro_isbn
       FROM emprestimo e
       JOIN usuario u ON e.usuario_id = u.usuario_id
       JOIN exemplar ex ON e.exemplar_id = ex.exemplar_id
       JOIN livro l ON ex.livro_id = l.livro_id
       WHERE e.emprestimo_id = $1`,
      [id]
    );
    
    if (resultado.rows.length === 0) {
      return res.status(404).json({
        sucesso: false,
        mensagem: 'Empréstimo não encontrado'
      });
    }

    res.json({
      sucesso: true,
      dados: resultado.rows[0]
    });
  } catch (erro) {
    console.error('Erro ao buscar empréstimo:', erro);
    res.status(500).json({
      sucesso: false,
      mensagem: 'Erro ao buscar empréstimo',
      erro: erro.message
    });
  }
};

// Criar novo empréstimo (DISPARA A TRIGGER DE VALIDAÇÃO)
exports.criarEmprestimo = async (req, res) => {
  try {
    const { usuario_id, exemplar_id, dias_emprestimo = 14 } = req.body;

    // Validação básica
    if (!usuario_id || !exemplar_id) {
      return res.status(400).json({
        sucesso: false,
        mensagem: 'Campos obrigatórios: usuario_id, exemplar_id'
      });
    }

    // Calcula data prevista de devolução
    const dataPrevista = new Date();
    dataPrevista.setDate(dataPrevista.getDate() + dias_emprestimo);

    // A trigger trg_emprestimo_validacao será disparada aqui
    // Ela valida: usuário ativo, exemplar disponível, multas abertas
    const resultado = await pool.query(
      `INSERT INTO emprestimo (usuario_id, exemplar_id, data_prevista_devolucao) 
       VALUES ($1, $2, $3) 
       RETURNING *`,
      [usuario_id, exemplar_id, dataPrevista.toISOString().split('T')[0]]
    );

    res.status(201).json({
      sucesso: true,
      mensagem: 'Empréstimo criado com sucesso. Trigger de validação foi executada.',
      dados: resultado.rows[0]
    });
  } catch (erro) {
    console.error('Erro ao criar empréstimo:', erro);
    
    // Mensagens de erro das triggers
    if (erro.message.includes('inativo')) {
      return res.status(400).json({
        sucesso: false,
        mensagem: 'Empréstimo negado: ' + erro.message
      });
    }

    if (erro.message.includes('disponível') || erro.message.includes('multas')) {
      return res.status(400).json({
        sucesso: false,
        mensagem: 'Empréstimo negado: ' + erro.message
      });
    }

    res.status(500).json({
      sucesso: false,
      mensagem: 'Erro ao criar empréstimo',
      erro: erro.message
    });
  }
};

// Atualizar empréstimo (pode disparar trigger de auditoria)
exports.atualizarEmprestimo = async (req, res) => {
  try {
    const { id } = req.params;
    const { data_devolucao } = req.body;

    const resultado = await pool.query(
      `UPDATE emprestimo 
       SET data_devolucao = $1
       WHERE emprestimo_id = $2
       RETURNING *`,
      [data_devolucao, id]
    );

    if (resultado.rows.length === 0) {
      return res.status(404).json({
        sucesso: false,
        mensagem: 'Empréstimo não encontrado'
      });
    }

    res.json({
      sucesso: true,
      mensagem: 'Empréstimo atualizado. Trigger de auditoria registrou a operação.',
      dados: resultado.rows[0]
    });
  } catch (erro) {
    console.error('Erro ao atualizar empréstimo:', erro);
    res.status(500).json({
      sucesso: false,
      mensagem: 'Erro ao atualizar empréstimo',
      erro: erro.message
    });
  }
};

// Deletar empréstimo
exports.deletarEmprestimo = async (req, res) => {
  try {
    const { id } = req.params;

    const resultado = await pool.query(
      'DELETE FROM emprestimo WHERE emprestimo_id = $1 RETURNING *',
      [id]
    );

    if (resultado.rows.length === 0) {
      return res.status(404).json({
        sucesso: false,
        mensagem: 'Empréstimo não encontrado'
      });
    }

    res.json({
      sucesso: true,
      mensagem: 'Empréstimo deletado com sucesso',
      dados: resultado.rows[0]
    });
  } catch (erro) {
    console.error('Erro ao deletar empréstimo:', erro);
    res.status(500).json({
      sucesso: false,
      mensagem: 'Erro ao deletar empréstimo',
      erro: erro.message
    });
  }
};

// ============================================================================
// ENDPOINTS ESPECÍFICOS DA FASE 2
// ============================================================================

// Calcular multa de um empréstimo (usa fn_calcular_multa_atraso)
exports.calcularMultaEmprestimo = async (req, res) => {
  try {
    const { id } = req.params;

    // Verifica se o empréstimo existe
    const emprestimoExiste = await pool.query(
      'SELECT emprestimo_id FROM emprestimo WHERE emprestimo_id = $1',
      [id]
    );

    if (emprestimoExiste.rows.length === 0) {
      return res.status(404).json({
        sucesso: false,
        mensagem: 'Empréstimo não encontrado'
      });
    }

    // Chama a função do banco
    const resultado = await pool.query(
      'SELECT fn_calcular_multa_atraso($1) AS valor_multa',
      [id]
    );

    res.json({
      sucesso: true,
      emprestimo_id: parseInt(id),
      valor_multa: parseFloat(resultado.rows[0].valor_multa),
      mensagem: 'Multa calculada pela função do banco (R$ 2,50/dia)'
    });
  } catch (erro) {
    console.error('Erro ao calcular multa:', erro);
    res.status(500).json({
      sucesso: false,
      mensagem: 'Erro ao calcular multa',
      erro: erro.message
    });
  }
};

// Registrar devolução (CHAMA A PROCEDURE prc_registrar_devolucao)
exports.registrarDevolucao = async (req, res) => {
  try {
    const { id } = req.params;
    const usuario_responsavel = req.body.usuario_responsavel || 'api_backend';

    // Chama a procedure do banco
    // A procedure irá:
    // 1. Atualizar data_devolucao (disparando trigger de auditoria)
    // 2. Calcular multa automaticamente
    // 3. Registrar multa se houver atraso
    await pool.query(
      'CALL prc_registrar_devolucao($1, $2)',
      [id, usuario_responsavel]
    );

    // Busca o empréstimo atualizado
    const resultado = await pool.query(
      `SELECT e.*, 
              u.nome AS usuario_nome,
              ex.codigo_exemplar,
              l.titulo AS livro_titulo
       FROM emprestimo e
       JOIN usuario u ON e.usuario_id = u.usuario_id
       JOIN exemplar ex ON e.exemplar_id = ex.exemplar_id
       JOIN livro l ON ex.livro_id = l.livro_id
       WHERE e.emprestimo_id = $1`,
      [id]
    );

    // Verifica se houve multa gerada
    const multa = await pool.query(
      'SELECT * FROM multa WHERE emprestimo_id = $1 ORDER BY multa_id DESC LIMIT 1',
      [id]
    );

    res.json({
      sucesso: true,
      mensagem: 'Devolução registrada com sucesso pela procedure do banco',
      emprestimo: resultado.rows[0],
      multa_gerada: multa.rows.length > 0 ? multa.rows[0] : null
    });
  } catch (erro) {
    console.error('Erro ao registrar devolução:', erro);
    res.status(500).json({
      sucesso: false,
      mensagem: 'Erro ao registrar devolução',
      erro: erro.message
    });
  }
};

// Listar auditoria de empréstimos
exports.listarAuditoria = async (req, res) => {
  try {
    const resultado = await pool.query(
      `SELECT * FROM auditoria_emprestimo 
       ORDER BY quando DESC 
       LIMIT 50`
    );

    res.json({
      sucesso: true,
      total: resultado.rows.length,
      mensagem: 'Logs gerados automaticamente pela trigger de auditoria',
      dados: resultado.rows
    });
  } catch (erro) {
    console.error('Erro ao listar auditoria:', erro);
    res.status(500).json({
      sucesso: false,
      mensagem: 'Erro ao listar auditoria',
      erro: erro.message
    });
  }
};
