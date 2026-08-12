/// Edge Function semanal: selecciona 12 locales por ciudad, genera texto IA y guarda en DB.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const MAX_POR_CIUDAD = 12;
const MAX_FOTOS_CARD = 4;
const BATCH_IA_MS = 350;

const TEXTOS_FALLBACK = [
  "Un lugar ideal para sumar a tu próxima salida.",
  "Conocé este local y armá tu plan para esta semana.",
  "Buena opción para salir, comer algo y compartir con amigos.",
];

type LocalRow = {
  id: string;
  nombre_local: string | null;
  descripcion_local: string | null;
  foto_perfil_url: string | null;
  url_foto_banner: string | null;
  foto_local_1: string | null;
  foto_local_2: string | null;
  foto_local_3: string | null;
  foto_local_4: string | null;
  foto_local_5: string | null;
  rubro: unknown;
  ciudad: string | null;
  provincia: string | null;
  local_verificado: boolean | null;
  es_pionero: boolean | null;
  calificacion_promedio: number | null;
  calificacion_cantidad: number | null;
  plan_suscripcion: string | null;
  estado_cuenta: string | null;
};

type ContextoLocal = {
  eventos: string[];
  promos: string[];
  carta: string[];
};

function argentinaWeekBounds(d = new Date()): { inicio: string; fin: string } {
  const tz = "America/Argentina/Cordoba";
  const fmt = new Intl.DateTimeFormat("en-CA", {
    timeZone: tz,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  const parts = fmt.formatToParts(d);
  const y = Number(parts.find((p) => p.type === "year")?.value);
  const m = Number(parts.find((p) => p.type === "month")?.value);
  const day = Number(parts.find((p) => p.type === "day")?.value);
  const local = new Date(Date.UTC(y, m - 1, day));
  const dow = local.getUTCDay();
  const diffToMon = dow === 0 ? -6 : 1 - dow;
  const monday = new Date(local);
  monday.setUTCDate(local.getUTCDate() + diffToMon);
  const sunday = new Date(monday);
  sunday.setUTCDate(monday.getUTCDate() + 6);
  const iso = (dt: Date) => dt.toISOString().slice(0, 10);
  return { inicio: iso(monday), fin: iso(sunday) };
}

function contextoFechas(inicio: string, fin: string): string {
  const hints: string[] = [];
  const start = new Date(`${inicio}T12:00:00`);
  const end = new Date(`${fin}T12:00:00`);
  for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
    const mm = d.getMonth() + 1;
    const dd = d.getDate();
    if (mm === 2 && dd === 14) hints.push("San Valentín");
    if (mm === 10 && dd === 31) hints.push("Halloween");
    if (mm === 12 && dd === 25) hints.push("Navidad");
    if (mm === 12 && dd === 31) hints.push("Año Nuevo");
    if (mm === 7 && dd === 20) hints.push("Día del Amigo");
    if (mm === 5 && dd >= 8 && dd <= 14 && d.getDay() === 0) hints.push("Día de la Madre");
    if (mm === 6 && dd >= 15 && dd <= 21 && d.getDay() === 0) hints.push("Día del Padre");
    if (mm === 9 && dd === 21) hints.push("Día de la Primavera");
  }
  const dow = start.getDay();
  if (dow === 5 || dow === 6) hints.push("fin de semana");
  return [...new Set(hints)].join(", ");
}

function shuffle<T>(arr: T[]): T[] {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function publicUrl(sb: ReturnType<typeof createClient>, bucket: string, path: string | null): string | null {
  if (!path || path.startsWith("http")) return path;
  const { data } = sb.storage.from(bucket).getPublicUrl(path);
  return data?.publicUrl ?? null;
}

function recolectarFotos(sb: ReturnType<typeof createClient>, local: LocalRow): string[] {
  const candidatas = [
    publicUrl(sb, "banners_locales", local.url_foto_banner),
    publicUrl(sb, "fotos_locales", local.foto_local_1),
    publicUrl(sb, "fotos_locales", local.foto_local_2),
    publicUrl(sb, "fotos_locales", local.foto_local_3),
    publicUrl(sb, "fotos_locales", local.foto_local_4),
    publicUrl(sb, "fotos_locales", local.foto_local_5),
    publicUrl(sb, "perfiles-locales", local.foto_perfil_url),
  ].filter((u): u is string => !!u && u.trim().length > 0);
  const unicas = [...new Set(candidatas)];
  return shuffle(unicas).slice(0, MAX_FOTOS_CARD);
}

function rubroTexto(rubro: unknown): string {
  if (Array.isArray(rubro) && rubro.length > 0) return String(rubro[0]);
  if (typeof rubro === "string" && rubro.trim()) return rubro.trim();
  return "";
}

function planActivo(plan: string | null): boolean {
  const p = (plan ?? "").trim().toLowerCase();
  return p.length > 0 && !["gratis", "free", "none", "trial"].includes(p);
}

async function cargarContexto(
  sb: ReturnType<typeof createClient>,
  localId: string,
): Promise<ContextoLocal> {
  const ctx: ContextoLocal = { eventos: [], promos: [], carta: [] };
  try {
    const { data: eventos } = await sb
      .from("eventos")
      .select("titulo_evento, tipo_evento, fecha_inicio")
      .eq("id_local", localId)
      .eq("estado_publicacion", "publicado")
      .or("fecha_fin_publicacion.gt.now(),fecha_fin_publicacion.is.null")
      .order("fecha_inicio", { ascending: true })
      .limit(5);
    for (const e of eventos ?? []) {
      const t = (e.titulo_evento as string)?.trim();
      if (t) ctx.eventos.push(t);
    }
  } catch (_) { /* noop */ }

  try {
    const { data: promos } = await sb
      .from("promociones")
      .select("titulo_promocion, descripcion_promocion")
      .eq("id_local", localId)
      .eq("estado_promocion", "activa")
      .or("fecha_fin.gt.now(),fecha_fin.is.null")
      .limit(3);
    for (const p of promos ?? []) {
      const t = ((p.titulo_promocion as string) || (p.descripcion_promocion as string) || "").trim();
      if (t) ctx.promos.push(t);
    }
  } catch (_) { /* noop */ }

  try {
    const { data: carta } = await sb
      .from("locales_carta_items")
      .select("nombre, categoria")
      .eq("id_local", localId)
      .eq("activo", true)
      .limit(6);
    for (const c of carta ?? []) {
      const n = (c.nombre as string)?.trim();
      if (n) ctx.carta.push(n);
    }
  } catch (_) { /* noop */ }

  return ctx;
}

async function generarTextoIa(
  local: LocalRow,
  ctx: ContextoLocal,
  fechasCtx: string,
): Promise<string> {
  const nombre = (local.nombre_local ?? "este local").trim();
  const rubro = rubroTexto(local.rubro);
  const desc = (local.descripcion_local ?? "").trim().slice(0, 400);
  const prompt = `Sos copywriter de Fernecito (app de salidas). Escribí UNA frase corta (100-160 caracteres) para invitar a visitar un local.
Tono: marketinero, buena onda, argentino, sin exagerar ni prometer descuentos/horarios inventados.
${fechasCtx ? `Contexto de fechas de la semana: ${fechasCtx}.` : ""}
Local: ${nombre}
Rubro: ${rubro || "salida"}
Descripción: ${desc || "sin descripción"}
Eventos activos confirmados: ${ctx.eventos.join("; ") || "ninguno"}
Promos confirmadas: ${ctx.promos.join("; ") || "ninguna"}
Ítems de carta destacados: ${ctx.carta.slice(0, 5).join("; ") || "ninguno"}
Reglas: no inventar 2x1, happy hour ni eventos que no estén listados. Podés mencionar eventos/carta solo si están en la lista.
Respondé SOLO con la frase, sin comillas.`;

  const xaiKey = Deno.env.get("XAI_API_KEY");
  const openaiKey = Deno.env.get("OPENAI_API_KEY");
  const apiKey = xaiKey || openaiKey;
  if (!apiKey) return TEXTOS_FALLBACK[Math.floor(Math.random() * TEXTOS_FALLBACK.length)];

  const baseUrl = xaiKey ? "https://api.x.ai/v1/chat/completions" : "https://api.openai.com/v1/chat/completions";
  const model = xaiKey ? (Deno.env.get("XAI_MODEL") ?? "grok-2-latest") : (Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini");

  try {
    const res = await fetch(baseUrl, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        temperature: 0.85,
        max_tokens: 120,
        messages: [
          { role: "system", content: "Respondé solo con el texto final, una sola línea." },
          { role: "user", content: prompt },
        ],
      }),
    });
    if (!res.ok) throw new Error(`IA ${res.status}`);
    const data = await res.json();
    const text = (data?.choices?.[0]?.message?.content ?? "").trim().replace(/^["']|["']$/g, "");
    if (text.length >= 20 && text.length <= 200) return text;
  } catch (e) {
    console.warn("IA fallback:", e);
  }
  return TEXTOS_FALLBACK[Math.floor(Math.random() * TEXTOS_FALLBACK.length)];
}

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
      },
    });
  }

  const cronSecret = Deno.env.get("CARTELERA_CRON_SECRET");
  const authHeader = req.headers.get("authorization") ?? "";
  const cronHeader = req.headers.get("x-cron-secret") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const isService = authHeader === `Bearer ${serviceKey}`;
  const isCron = cronSecret && cronHeader === cronSecret;
  if (!isService && !isCron) {
    return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401 });
  }

  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) {
    return new Response(JSON.stringify({ error: "missing supabase env" }), { status: 500 });
  }

  const sb = createClient(url, key, { auth: { persistSession: false } });
  const { inicio, fin } = argentinaWeekBounds();
  const fechasCtx = contextoFechas(inicio, fin);

  const { data: ciudadesRows, error: errCiudades } = await sb
    .from("perfiles_locales")
    .select("ciudad, provincia")
    .eq("estado_cuenta", "activa")
    .not("ciudad", "is", null);

  if (errCiudades) {
    return new Response(JSON.stringify({ error: errCiudades.message }), { status: 500 });
  }

  const pares = new Map<string, { ciudad: string; provincia: string }>();
  for (const row of ciudadesRows ?? []) {
    const ciudad = (row.ciudad as string)?.trim();
    const provincia = ((row.provincia as string) ?? "Córdoba").trim();
    if (!ciudad) continue;
    const k = `${ciudad.toLowerCase()}|${provincia.toLowerCase()}`;
    if (!pares.has(k)) pares.set(k, { ciudad, provincia });
  }

  let generados = 0;
  let ciudadesProcesadas = 0;

  for (const { ciudad, provincia } of pares.values()) {
    ciudadesProcesadas++;
    const { data: locales, error: errLocales } = await sb
      .from("perfiles_locales")
      .select(
        "id, nombre_local, descripcion_local, foto_perfil_url, url_foto_banner, " +
        "foto_local_1, foto_local_2, foto_local_3, foto_local_4, foto_local_5, " +
        "rubro, ciudad, provincia, local_verificado, es_pionero, " +
        "calificacion_promedio, calificacion_cantidad, plan_suscripcion, estado_cuenta",
      )
      .eq("estado_cuenta", "activa")
      .ilike("ciudad", ciudad);

    if (errLocales || !locales?.length) continue;

    const scored: { local: LocalRow; score: number }[] = [];
    for (const l of locales as LocalRow[]) {
      const { data: score, error: errScore } = await sb.rpc("calcular_score_perfil_local", {
        p_local_id: l.id,
      });
      if (errScore) continue;
      scored.push({ local: l, score: Number(score) || 0 });
    }

    scored.sort((a, b) => b.score - a.score);
    const top = scored.slice(0, MAX_POR_CIUDAD);

    await sb
      .from("cartelera_local_cards")
      .update({ activo: false })
      .eq("ciudad", ciudad)
      .eq("semana_inicio", inicio)
      .neq("activo", false);

    let pos = 1;
    for (const { local, score } of top) {
      const ctx = await cargarContexto(sb, local.id);
      const texto = await generarTextoIa(local, ctx, fechasCtx);
      const fotos = recolectarFotos(sb, local);
      const avatar = publicUrl(sb, "perfiles-locales", local.foto_perfil_url);

      const { error: upsertErr } = await sb.from("cartelera_local_cards").upsert(
        {
          local_id: local.id,
          ciudad,
          provincia,
          ranking_position: pos,
          texto_ia: texto,
          imagenes_urls: fotos,
          avatar_url: avatar,
          nombre_local: (local.nombre_local ?? "Local").trim(),
          rating_promedio: local.calificacion_promedio,
          cantidad_resenas: local.calificacion_cantidad ?? 0,
          es_pionero: local.es_pionero === true,
          es_verificado: local.local_verificado === true,
          tiene_plan_activo: planActivo(local.plan_suscripcion),
          score_perfil: score,
          semana_inicio: inicio,
          semana_fin: fin,
          activo: true,
          metadata: {
            rubro: rubroTexto(local.rubro),
            generado_en: new Date().toISOString(),
          },
        },
        { onConflict: "local_id,semana_inicio" },
      );

      if (!upsertErr) {
        generados++;
        pos++;
      }
      await sleep(BATCH_IA_MS);
    }
  }

  await sb
    .from("cartelera_local_cards")
    .update({ activo: false })
    .lt("semana_fin", inicio)
    .eq("activo", true);

  return new Response(
    JSON.stringify({
      ok: true,
      semana_inicio: inicio,
      semana_fin: fin,
      ciudades_procesadas: ciudadesProcesadas,
      cards_generadas: generados,
    }),
    { headers: { "Content-Type": "application/json" } },
  );
});
