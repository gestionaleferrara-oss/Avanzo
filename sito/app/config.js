// Configurazione di Avanzo. Si compila una volta sola (vedi SETUP.md).
// Questi due valori sono pubblici per natura: la protezione dei dati
// la fanno le regole di accesso del database (supabase/schema.sql).
window.AVANZO_CONFIG = {
  supabaseUrl: 'https://toseujvuvalxoelmmows.supabase.co',
  // Link di pagamento Stripe per Plus a vita (prezzo fondatore). In prova finché è un link test_.
  pagamentoFondatore: 'https://buy.stripe.com/test_cNi4gB9lCbTg4mr0WC6kg00',
  supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRvc2V1anZ1dmFseG9lbG1tb3dzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIzMTEwMjUsImV4cCI6MjEwNzg4NzAyNX0.RNZ7ENzTVxOplDdoiD_kPy4gy_RSSaFRkc9BD0H2z4k',
};
