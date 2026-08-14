/// Edge Function semanal: selecciona 12 locales por ciudad, genera texto IA y guarda en DB.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const MAX_POR_CIUDAD = 12;
const MAX_FOTOS_CARD = 4;

const TEXTOS_FALLBACK = [
  "Un lugar de tu ciudad para descubrir esta semana.",
  "¿Ya lo conocés? Puede ser tu próxima salida.",
  "Buena excusa para cortar la rutina y salir un rato.",
  "Sumalo a tu lista de lugares para conocer.",
  "Si pinta moverse, este lugar puede entrar en el plan.",
  "Un rincón de la ciudad que merece una visita.",
  "Ideal para una salida simple y distinta.",
  "Los buenos momentos también empiezan en lugares así.",
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
  horarios_json: unknown;
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
};

type LocalConScore = {
  local: LocalRow;
  score: number;
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

async function cargarContextosSemana(
  sb: ReturnType<typeof createClient>,
  localIds: string[],
  inicio: string,
  fin: string,
): Promise<Map<string, ContextoLocal>> {
  const mapa = new Map<string, ContextoLocal>();
  for (const id of localIds) mapa.set(id, { eventos: [], promos: [] });
  if (localIds.length === 0) return mapa;

  const inicioTs = `${inicio}T00:00:00-03:00`;
  const finTs = `${fin}T23:59:59-03:00`;

  try {
    const { data: eventos } = await sb
      .from("eventos")
      .select("id_local, titulo_evento, fecha_inicio, fecha_fin")
      .in("id_local", localIds)
      .eq("estado_publicacion", "publicado")
      .lte("fecha_inicio", finTs)
      .or(`fecha_fin.gte.${inicioTs},fecha_fin.is.null`)
      .order("fecha_inicio", { ascending: true })
      .limit(localIds.length * 3);
    for (const e of eventos ?? []) {
      const localId = (e.id_local as string)?.trim();
      const t = (e.titulo_evento as string)?.trim();
      if (localId && t) mapa.get(localId)?.eventos.push(t);
    }
  } catch (_) { /* noop */ }

  try {
    const { data: promos } = await sb
      .from("promociones")
      .select("id_local, titulo_promocion, descripcion_promocion, fecha_inicio, fecha_fin")
      .in("id_local", localIds)
      .eq("estado_promocion", "activa")
      .lte("fecha_inicio", finTs)
      .gte("fecha_fin", inicioTs)
      .limit(localIds.length * 3);
    for (const p of promos ?? []) {
      const localId = (p.id_local as string)?.trim();
      const t = ((p.titulo_promocion as string) || (p.descripcion_promocion as string) || "").trim();
      if (localId && t) mapa.get(localId)?.promos.push(t);
    }
  } catch (_) { /* noop */ }

  return mapa;
}

function resumirHorarios(horarios: unknown): string {
  if (!horarios) return "";
  const raw = typeof horarios === "string" ? horarios : JSON.stringify(horarios);
  return raw.replace(/\s+/g, " ").slice(0, 180);
}

function fallbackTexto(local: LocalRow, index: number): string {
  const nombre = (local.nombre_local ?? "").trim();
  const desc = (local.descripcion_local ?? "").replace(/\s+/g, " ").trim();
  // Preferí la descripción real del local antes que frases genéricas.
  if (desc.length >= 36) {
    const conNombre = nombre && !desc.toLowerCase().includes(nombre.toLowerCase())
      ? `${nombre}: ${desc}`
      : desc;
    return limitarTextoCard(conNombre);
  }
  const rubro = rubroTexto(local.rubro);
  if (nombre && rubro) {
    return limitarTextoCard(`${nombre}: ${rubro.toLowerCase()} para una salida en tu ciudad esta semana.`);
  }
  const base = TEXTOS_FALLBACK[index % TEXTOS_FALLBACK.length];
  if (!nombre) return base;
  if (index % 3 === 0) return limitarTextoCard(`${nombre}: ${base.charAt(0).toLowerCase()}${base.slice(1)}`);
  return base;
}

function extraerJsonObjeto(raw: string): Record<string, unknown> | null {
  const limpio = raw.trim().replace(/^```(?:json)?/i, "").replace(/```$/i, "").trim();
  try {
    const parsed = JSON.parse(limpio);
    return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed as Record<string, unknown> : null;
  } catch (_) {
    const desde = limpio.indexOf("{");
    const hasta = limpio.lastIndexOf("}");
    if (desde < 0 || hasta <= desde) return null;
    try {
      const parsed = JSON.parse(limpio.slice(desde, hasta + 1));
      return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed as Record<string, unknown> : null;
    } catch (_) {
      return null;
    }
  }
}

async function generarTextosIaCiudad(
  items: LocalConScore[],
  contextos: Map<string, ContextoLocal>,
  fechasCtx: string,
  inicio: string,
  fin: string,
): Promise<Map<string, string>> {
  const resultado = new Map<string, string>();
  for (let i = 0; i < items.length; i++) {
    resultado.set(items[i].local.id, fallbackTexto(items[i].local, i));
  }

  const locales = items.map(({ local, score }) => {
    const ctx = contextos.get(local.id) ?? { eventos: [], promos: [] };
    return {
      id: local.id,
      nombre: (local.nombre_local ?? "Local").trim(),
      rubro: rubroTexto(local.rubro),
      descripcion: (local.descripcion_local ?? "").replace(/\s+/g, " ").trim().slice(0, 220),
      horarios: resumirHorarios(local.horarios_json),
      eventos_semana: ctx.eventos.slice(0, 2),
      promos_semana: ctx.promos.slice(0, 2),
      score: Math.round(score),
    };
  });

  const prompt = `Generá micro-copies para cards de locales de Fernecito, app argentina para descubrir salidas.
Semana: ${inicio} a ${fin}. Fechas especiales: ${fechasCtx || "ninguna"}.

Locales JSON:
${JSON.stringify(locales)}

Devolvé SOLO un JSON objeto con esta forma exacta:
{"items":[{"id":"uuid-del-local","texto":"frase"}]}

Reglas estrictas:
- Un item por cada local recibido, usando el mismo id.
- Cada texto: 45 a 95 caracteres ideal, máximo 105.
- Español argentino, simpático, fresco, con idea de salida.
- Variá los comienzos. Evitá repetir "Armá tu plan", "Vení a", "Che" y "Pasate por".
- No uses más de 2 textos con la misma primera palabra.
- Priorizá la descripción del local; si hay promo/evento de esta semana o fecha especial, podés anclarlo ahí.
- Destacá una sola cosa fuerte: descripción, promo/evento de esta semana, rubro u ocasión.
- No inventes descuentos, comida, tragos, horarios, teléfonos, ranking ni eventos.
- Si mencionás promo/evento, debe estar en promos_semana/eventos_semana.
- No digas "el mejor", "famoso" ni promesas absolutas.
- Sin hashtags, sin comillas, sin saltos de línea dentro del texto.`;

  const xaiKey = Deno.env.get("XAI_API_KEY") ?? Deno.env.get("api_key_de_grok");
  const openaiKey = Deno.env.get("OPENAI_API_KEY");
  const apiKey = xaiKey || openaiKey;
  if (!apiKey) return resultado;

  const baseUrl = xaiKey ? "https://api.x.ai/v1/chat/completions" : "https://api.openai.com/v1/chat/completions";
  const model = xaiKey ? (Deno.env.get("XAI_MODEL") ?? "grok-3-mini") : (Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini");

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 45000);
    const res = await fetch(baseUrl, {
      method: "POST",
      signal: controller.signal,
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        temperature: 0.7,
        max_tokens: 650,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: "Sos un copywriter breve. Respondés únicamente JSON válido, sin markdown." },
          { role: "user", content: prompt },
        ],
      }),
    });
    clearTimeout(timeout);
    if (!res.ok) throw new Error(`IA ${res.status}`);
    const data = await res.json();
    const text = (data?.choices?.[0]?.message?.content ?? "").trim().replace(/^["']|["']$/g, "");
    const parsed = extraerJsonObjeto(text);
    const arr = Array.isArray(parsed?.items) ? parsed!.items : [];
    for (const item of arr) {
      if (!item || typeof item !== "object") continue;
      const id = String((item as Record<string, unknown>).id ?? "").trim();
      const texto = String((item as Record<string, unknown>).texto ?? "").trim();
      if (!id || texto.length < 16) continue;
      if (!resultado.has(id)) continue;
      resultado.set(id, limitarTextoCard(texto));
    }
  } catch (e) {
    console.warn("IA batch fallback:", e);
  }
  return resultado;
}

function limitarTextoCard(texto: string, max = 108): string {
  const limpio = texto.replace(/\s+/g, " ").trim();
  if (limpio.length <= max) return limpio;
  const corte = limpio.slice(0, max - 1);
  const ultimoEspacio = corte.lastIndexOf(" ");
  const base = ultimoEspacio > 80 ? corte.slice(0, ultimoEspacio) : corte;
  return `${base.replace(/[.,;:!?¡¿-]+$/g, "").trim()}…`;
}

function jwtRole(token: string): string {
  try {
    const parts = token.split(".");
    if (parts.length < 2) return "";
    const payload = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = payload.padEnd(payload.length + ((4 - payload.length % 4) % 4), "=");
    const json = atob(padded);
    const data = JSON.parse(json);
    return String(data?.role ?? "");
  } catch (_) {
    return "";
  }
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

  const cronSecret = Deno.env.get("CARTELERA_CRON_SECRET") ?? Deno.env.get("CRON_SECRET");
  const authHeader = req.headers.get("authorization") ?? "";
  const cronHeader = req.headers.get("x-cron-secret") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const bearer = authHeader.startsWith("Bearer ") ? authHeader.slice(7).trim() : "";
  const isService = authHeader === `Bearer ${serviceKey}` || jwtRole(bearer) === "service_role";
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
        "rubro, horarios_json, ciudad, provincia, local_verificado, es_pionero, " +
        "calificacion_promedio, calificacion_cantidad, plan_suscripcion, estado_cuenta",
      )
      .eq("estado_cuenta", "activa")
      .ilike("ciudad", ciudad);

    if (errLocales || !locales?.length) continue;

    const scored: LocalConScore[] = [];
    // Preferir score = puntos_base (fijo) + métricas semanales del cache.
    const { data: rankingRows } = await sb
      .from("locales_ranking_cache")
      .select("id_local, score, puntos_base, puntos_semana")
      .in("id_local", (locales as LocalRow[]).map((l) => l.id));
    const rankingMap = new Map<string, number>();
    for (const r of rankingRows ?? []) {
      rankingMap.set(String(r.id_local), Number(r.score) || 0);
    }
    for (const l of locales as LocalRow[]) {
      let score = rankingMap.get(l.id);
      if (score == null) {
        const { data: baseScore, error: errScore } = await sb.rpc(
          "calcular_score_perfil_local",
          { p_local_id: l.id },
        );
        if (errScore) continue;
        score = Number(baseScore) || 0;
      }
      scored.push({ local: l, score });
    }

    scored.sort((a, b) => b.score - a.score);
    const top = scored.slice(0, MAX_POR_CIUDAD);
    const topIds = top.map((t) => t.local.id);
    const contextos = await cargarContextosSemana(sb, topIds, inicio, fin);
    const textosPorLocal = await generarTextosIaCiudad(top, contextos, fechasCtx, inicio, fin);

    await sb
      .from("cartelera_local_cards")
      .update({ activo: false })
      .eq("ciudad", ciudad)
      .eq("semana_inicio", inicio)
      .neq("activo", false);

    let pos = 1;
    for (const { local, score } of top) {
      const texto = textosPorLocal.get(local.id) ?? fallbackTexto(local, pos);
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
