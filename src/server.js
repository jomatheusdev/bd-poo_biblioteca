require('dotenv').config();
const app = require('./app');
const pool = require('./config/db');

const PORT = process.env.PORT || 3000;

// ============================================================================
// INICIALIZAÇÃO DO SERVIDOR
// ============================================================================

const iniciarServidor = async () => {
  try {
    // Testa conexão com o banco
    await pool.query('SELECT NOW()');
    console.log('✅ Conexão com PostgreSQL estabelecida');

    // Inicia o servidor
    app.listen(PORT, () => {
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      console.log('🚀 Servidor rodando na porta ' + PORT);
      console.log('📚 Sistema de Biblioteca Universitária - Fase 2');
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      console.log('');
      console.log('📌 Endpoints principais:');
      console.log(`   http://localhost:${PORT}/`);
      console.log(`   http://localhost:${PORT}/api/usuarios`);
      console.log(`   http://localhost:${PORT}/api/emprestimos`);
      console.log('');
      console.log('🔧 Fase 2 - Funcionalidades implementadas:');
      console.log('   ✓ 2 Triggers (validação + auditoria)');
      console.log('   ✓ 2 Functions (calcular multa + total multas)');
      console.log('   ✓ 1 Procedure (registrar devolução)');
      console.log('   ✓ CRUD completo (Usuários e Empréstimos)');
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    });
  } catch (erro) {
    console.error('❌ Erro ao iniciar servidor:', erro.message);
    process.exit(1);
  }
};

// ============================================================================
// TRATAMENTO DE ENCERRAMENTO GRACIOSO
// ============================================================================

process.on('SIGTERM', async () => {
  console.log('⚠️  SIGTERM recebido, encerrando servidor...');
  await pool.end();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('\n⚠️  SIGINT recebido, encerrando servidor...');
  await pool.end();
  process.exit(0);
});

// Inicia o servidor
iniciarServidor();
