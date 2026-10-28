import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const env = (k: string) => Deno.env.get(k) ?? "";
const allowed = (env("ALLOWED_ORIGINS") || "https://taha-k.dev").split(",").map((s) => s.trim());
const sb = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"));

async function sha256(t: string) {
  const b = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(env("IP_SALT") + t));
  return [...new Uint8Array(b)].map((x) => x.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  const origin = req.headers.get("origin") ?? "";
  const h = {
    "Access-Control-Allow-Origin": allowed.includes(origin) ? origin : allowed[0],
    "Access-Control-Allow-Headers": "authorization, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
  const out = (b: unknown, s = 200) =>
    new Response(JSON.stringify(b), { status: s, headers: { ...h, "Content-Type": "application/json" } });

  if (req.method === "OPTIONS") return new Response(null, { headers: h });
  if (req.method !== "POST") return out({ error: "method" }, 405);
  if (!allowed.includes(origin)) return out({ error: "origin" }, 403);

  let b: Record<string, unknown>;
  try { b = await req.json(); } catch { return out({ error: "bad request" }, 400); }
  if (b.website) return out({ ok: true }); // honeypot: pretend success

  const name = String(b.name ?? "").replace(/[\r\n]+/g, " ").trim();
  const email = String(b.email ?? "").trim();
  const message = String(b.message ?? "").trim();
  if (name.length < 1 || name.length > 80 || email.length > 120 || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) ||
      message.length < 10 || message.length > 3000) return out({ error: "invalid" }, 400);

  const ip = (req.headers.get("x-forwarded-for") ?? "unknown").split(",")[0].trim();

  if (env("TURNSTILE_SECRET")) {
    const r = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
      method: "POST",
      body: new URLSearchParams({ secret: env("TURNSTILE_SECRET"), response: String(b.token ?? ""), remoteip: ip }),
    });
    if (!(await r.json()).success) return out({ error: "spam check failed" }, 400);
  }

  const ipHash = await sha256(ip);
  const since = new Date(Date.now() - 3600_000).toISOString();
  const { count } = await sb.from("messages").select("id", { count: "exact", head: true })
    .eq("ip_hash", ipHash).gte("created_at", since);
  if ((count ?? 0) >= 3) return out({ error: "rate limited" }, 429);

  await sb.from("messages").insert({ name, email, message, ip_hash: ipHash });

  const r = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${env("RESEND_API_KEY")}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      from: env("CONTACT_FROM"), to: [env("CONTACT_TO")], reply_to: email,
      subject: `Portfolio message from ${name}`, text: `From: ${name} <${email}>\n\n${message}`,
    }),
  });
  if (!r.ok) { console.error("resend", r.status); return out({ error: "send failed" }, 502); }
  return out({ ok: true });
});
