/// Constantes do Supabase
/// Credenciais para conexão com o backend
class SupabaseConstants {
  // URL do projeto Supabase
  static const String supabaseUrl = 'https://heswheljavpcyspuicsi.supabase.co';
  
  // Anon Key (chave pública - seguro para expor no app)
  static const String supabaseAnonKey = 
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhlc3doZWxqYXZwY3lzcHVpY3NpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk3NDc4NDMsImV4cCI6MjA2NTMyMzg0M30.JcGUOFynclGhrLRuZbiGMXsNviMLLBSLZ4l89HgDvNg';
  
  // ⚠️ NUNCA exponha o service_role key no app!
  // Ele deve ser usado apenas em scripts backend
}

