// Avanzo: riceve le notifiche di Stripe e registra gli acquisti.
// Segreti necessari (Supabase › Edge Functions › Secrets): STRIPE_WEBHOOK_SECRET.
// SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY sono già disponibili.
// Va pubblicata con "Verify JWT" disattivato: Stripe non manda token, la firma la controlliamo qui.

const SEGRETO = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";
const SB_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SB_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const TOLLERANZA_S = 300;

const enc = new TextEncoder();
const hex = (buf: ArrayBuffer) => [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
function uguali(a: string, b: string) {
  if (a.length !== b.length) return false;
  let r = 0;
  for (let i = 0; i < a.length; i++) r |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return r === 0;
}

async function firmaValida(corpo: string, intestazione: string) {
  if (!SEGRETO || !intestazione) return false;
  const parti = intestazione.split(",").map((p) => p.trim().split("="));
  const t = parti.find(([k]) => k === "t")?.[1];
  const firme = parti.filter(([k]) => k === "v1").map(([, v]) => v);
  if (!t || !firme.length) return false;
  if (Math.abs(Date.now() / 1000 - Number(t)) > TOLLERANZA_S) return false;
  const chiave = await crypto.subtle.importKey("raw", enc.encode(SEGRETO), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const attesa = hex(await crypto.subtle.sign("HMAC", chiave, enc.encode(`${t}.${corpo}`)));
  return firme.some((f) => uguali(f, attesa));
}

function db(percorso: string, init: RequestInit & { prefer?: string }) {
  return fetch(`${SB_URL}/rest/v1/${percorso}`, {
    ...init,
    headers: {
      apikey: SB_KEY,
      Authorization: `Bearer ${SB_KEY}`,
      "Content-Type": "application/json",
      Prefer: init.prefer ?? "return=minimal",
    },
  });
}

const risposta = (stato: number, dati: unknown) =>
  new Response(JSON.stringify(dati), { status: stato, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method !== "POST") return risposta(200, { ok: true });
  const corpo = await req.text();
  if (!(await firmaValida(corpo, req.headers.get("stripe-signature") ?? ""))) {
    return risposta(400, { errore: "firma non valida" });
  }
  const ev = JSON.parse(corpo);

  if (ev.type === "checkout.session.completed" || ev.type === "checkout.session.async_payment_succeeded") {
    const s = ev.data.object;
    if (s.payment_status !== "paid") return risposta(200, { ignorato: "pagamento non ancora concluso" });
    if (s.mode !== "payment") return risposta(200, { ignorato: "abbonamenti gestiti al lancio" });
    const email = String(s.customer_details?.email ?? s.customer_email ?? "").trim().toLowerCase();
    if (!email) return risposta(200, { ignorato: "email mancante" });
    const r = await db("acquisti?on_conflict=stripe_session", {
      method: "POST",
      prefer: "resolution=merge-duplicates,return=minimal",
      body: JSON.stringify({
        email,
        piano: "plus_vita",
        stripe_session: s.id,
        stripe_payment_intent: s.payment_intent ?? null,
        stripe_customer: s.customer ?? null,
        importo: s.amount_total ?? null,
        valuta: s.currency ?? null,
        ref: typeof s.client_reference_id === "string" ? s.client_reference_id.slice(0, 40) : null,
      }),
    });
    if (!r.ok) return risposta(500, { errore: "salvataggio non riuscito", dettaglio: await r.text() });
    return risposta(200, { registrato: true });
  }

  if (ev.type === "charge.refunded") {
    const c = ev.data.object;
    if (!c.refunded || !c.payment_intent) return risposta(200, { ignorato: "rimborso parziale" });
    const r = await db(`acquisti?stripe_payment_intent=eq.${encodeURIComponent(c.payment_intent)}`, {
      method: "PATCH",
      body: JSON.stringify({ rimborsato: true }),
    });
    if (!r.ok) return risposta(500, { errore: "aggiornamento non riuscito" });
    return risposta(200, { rimborsato: true });
  }

  return risposta(200, { ignorato: ev.type });
});
