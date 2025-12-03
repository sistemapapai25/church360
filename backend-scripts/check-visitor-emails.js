require('dotenv').config({ path: '../.env' });
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL || 'https://heswheljavpcyspuicsi.supabase.co';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseKey) {
  console.error('❌ SUPABASE_SERVICE_ROLE_KEY não encontrada no .env');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkVisitorEmails() {
  console.log('🔍 Verificando emails dos visitantes...\n');

  const { data, error } = await supabase
    .from('user_account')
    .select('id, email, first_name, last_name, status')
    .eq('status', 'visitor');

  if (error) {
    console.error('❌ Erro ao buscar visitantes:', error);
    return;
  }

  console.log(`✅ Encontrados ${data.length} visitantes:\n`);
  
  data.forEach((visitor, index) => {
    console.log(`${index + 1}. Email: "${visitor.email}"`);
    console.log(`   Nome: ${visitor.first_name} ${visitor.last_name}`);
    console.log(`   ID: ${visitor.id}`);
    console.log(`   Status: ${visitor.status}`);
    console.log('');
  });

  // Testar busca específica
  console.log('\n🔍 Testando busca por email específico: gabriel@church360.com\n');
  
  const { data: testData, error: testError } = await supabase
    .from('user_account')
    .select('id, email, first_name, last_name, status')
    .eq('email', 'gabriel@church360.com')
    .eq('status', 'visitor')
    .maybeSingle();

  if (testError) {
    console.error('❌ Erro ao buscar:', testError);
  } else if (testData) {
    console.log('✅ Visitante encontrado:', testData);
  } else {
    console.log('❌ Nenhum visitante encontrado com este email');
  }
}

checkVisitorEmails();

