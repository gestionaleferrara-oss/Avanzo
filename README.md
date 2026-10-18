# Avanzo

Quanto puoi spendere fino allo stipendio.

| Cartella | Cosa contiene |
| --- | --- |
| `sito/` | Pagina di vendita con la prevendita Fondatori (`index.html`) e informativa privacy |
| `sito/app/` | La web app installabile: oggi versione gratuita, dati nel browser |

Il sito si pubblica così com'è su Cloudflare Pages o Netlify, scegliendo `sito` come cartella da pubblicare. Non serve nessun comando di build.

## Prossime tappe

1. Prevendita Fondatori con un link di pagamento Stripe
2. Login e sincronizzazione con Supabase (server in UE)
3. Abbonamenti Plus con Stripe
4. Spese inviate dalle scorciatoie direttamente al server
5. Riepiloghi del lunedì e di fine mese
6. Importazione facoltativa da Wallet
