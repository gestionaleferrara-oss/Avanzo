# Mettere online Avanzo

Tempo totale: circa 40 minuti. Si fa una volta sola.

## 1. Supabase (database e accesso)

1. Su [supabase.com](https://supabase.com) crea un progetto: nome `avanzo`, regione **Central EU (Frankfurt)**, una password del database lunga, da salvare nel tuo gestore di password.
2. **SQL Editor › New query**: incolla tutto il file `supabase/schema.sql` e premi **Run**.
3. **Authentication › Sign In / Providers › Email**: lascia attivo Email; attiva "Confirm email".
4. **Authentication › Email Templates › Magic Link**: sostituisci il testo con:

   ```
   <h2>Il tuo codice per Avanzo</h2>
   <p>Inserisci questo codice nell'app: <strong>{{ .Token }}</strong></p>
   <p>Scade tra un'ora. Se non l'hai chiesto tu, ignora questa email.</p>
   ```

   Fai lo stesso per **Confirm signup**. Serve il codice e non il link, perché su iPhone il link si aprirebbe in Safari e non nell'app installata.
5. **Authentication › URL Configuration**: in Site URL metti l'indirizzo del sito (oggi `https://avanzo.me/app/`; tra i Redirect URLs anche `https://avanzo.pages.dev/app/`).
6. **Project Settings › API**: copia **Project URL** e la chiave **anon public** in `sito/app/config.js`.

   Non usare mai la chiave **service_role** nel sito: quella resta solo nei pannelli di Supabase e Cloudflare.

## 2. Cloudflare Pages (sito)

1. Su [dash.cloudflare.com](https://dash.cloudflare.com): **Workers & Pages › Create › Pages › Connect to Git**, scegli il repository `avanzo`.
2. Build command: vuoto. Build output directory: `sito`.
3. Ogni modifica caricata su GitHub viene pubblicata da sola in un minuto.
4. **Custom domains**: collega il tuo dominio.

## 3. Prova

Apri `https://<tuo-sito>/app/`, vai in **Impostazioni › Account**, inserisci la tua email e il codice ricevuto. Aggiungi una spesa, poi apri l'app da un altro telefono con la stessa email: la spesa compare lì.

Le email di Supabase gratuite sono poche all'ora e servono per le prove. Prima della beta configura un servizio di invio email (SMTP) in **Project Settings › Authentication › SMTP**, per esempio Resend.

## Pagamenti (Stripe → Plus automatico)

1. In Supabase › SQL Editor esegui `supabase/acquisti.sql` (tabella acquisti e regole che attivano Plus).
2. Pubblica la funzione `supabase/functions/stripe-webhook` (Edge Functions › Deploy a new function › Via Editor), con **Verify JWT** disattivato.
3. In Stripe › Sviluppatori › Webhook crea una destinazione verso `https://<progetto>.supabase.co/functions/v1/stripe-webhook` con gli eventi `checkout.session.completed`, `checkout.session.async_payment_succeeded`, `charge.refunded`.
4. Copia la chiave di firma (`whsec_…`) in Supabase › Edge Functions › Secrets come `STRIPE_WEBHOOK_SECRET`.
5. Metti il link di pagamento in `sito/app/config.js` (`pagamentoFondatore`) e nei pulsanti di `sito/index.html`.

Quando passi dalla sandbox all'account live di Stripe ripeti i punti 3–5 con il link e la chiave live.
