-- Cartelera: cards semanales de locales recomendados (aditivo, no rompe cartelera actual).
-- La app consulta vía RPC; la generación corre semanalmente por Edge Function.

-- ---------------------------------------------------------------------------
-- Score de completitud de perfil (base para ranking semanal por ciudad)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calcular_score_perfil_local(p_local_id uuid)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v record;
  v_score numeric := 0;
  v_fotos int := 0;
  v_carta int := 0;
  v_eventos int := 0;
  v_promos int := 0;
BEGIN
  SELECT
    pl.id,
    pl.nombre_local,
    pl.descripcion_local,
    pl.foto_perfil_url,
    pl.url_foto_banner,
    pl.foto_local_1,
    pl.foto_local_2,
    pl.foto_local_3,
    pl.foto_local_4,
    pl.foto_local_5,
    pl.rubro,
    pl.ciudad,
    pl.provincia,
    pl.direccion,
    pl.url_maps,
    pl.horarios_json,
    pl.url_instagram,
    pl.url_tiktok,
    pl.url_website,
    pl.telefono_whatsapp,
    pl.local_verificado,
    pl.es_pionero,
    pl.calificacion_promedio,
    pl.calificacion_cantidad,
    pl.plan_suscripcion,
    pl.estado_cuenta
  INTO v
  FROM public.perfiles_locales pl
  WHERE pl.id = p_local_id;

  IF NOT FOUND OR COALESCE(v.estado_cuenta, '') <> 'activa' THEN
    RETURN 0;
  END IF;

  IF NULLIF(TRIM(v.nombre_local), '') IS NOT NULL THEN v_score := v_score + 8; END IF;
  IF NULLIF(TRIM(v.descripcion_local), '') IS NOT NULL THEN v_score := v_score + 10; END IF;
  IF NULLIF(TRIM(v.foto_perfil_url), '') IS NOT NULL THEN v_score := v_score + 12; END IF;
  IF NULLIF(TRIM(v.url_foto_banner), '') IS NOT NULL THEN v_score := v_score + 8; END IF;

  IF NULLIF(TRIM(v.foto_local_1), '') IS NOT NULL THEN v_fotos := v_fotos + 1; END IF;
  IF NULLIF(TRIM(v.foto_local_2), '') IS NOT NULL THEN v_fotos := v_fotos + 1; END IF;
  IF NULLIF(TRIM(v.foto_local_3), '') IS NOT NULL THEN v_fotos := v_fotos + 1; END IF;
  IF NULLIF(TRIM(v.foto_local_4), '') IS NOT NULL THEN v_fotos := v_fotos + 1; END IF;
  IF NULLIF(TRIM(v.foto_local_5), '') IS NOT NULL THEN v_fotos := v_fotos + 1; END IF;
  v_score := v_score + LEAST(v_fotos, 5) * 3;

  IF v.rubro IS NOT NULL AND (
    (v.rubro IS NOT NULL AND v.rubro::text <> '' AND v.rubro::text <> '[]')
  ) THEN v_score := v_score + 6; END IF;

  IF NULLIF(TRIM(v.ciudad), '') IS NOT NULL THEN v_score := v_score + 5; END IF;
  IF NULLIF(TRIM(v.provincia), '') IS NOT NULL THEN v_score := v_score + 3; END IF;
  IF NULLIF(TRIM(v.direccion), '') IS NOT NULL THEN v_score := v_score + 4; END IF;
  IF NULLIF(TRIM(v.url_maps), '') IS NOT NULL THEN v_score := v_score + 3; END IF;
  IF v.horarios_json IS NOT NULL AND v.horarios_json::text NOT IN ('null', '{}', '[]') THEN
    v_score := v_score + 6;
  END IF;

  IF NULLIF(TRIM(v.url_instagram), '') IS NOT NULL THEN v_score := v_score + 2; END IF;
  IF NULLIF(TRIM(v.url_tiktok), '') IS NOT NULL THEN v_score := v_score + 1; END IF;
  IF NULLIF(TRIM(v.url_website), '') IS NOT NULL THEN v_score := v_score + 2; END IF;
  IF NULLIF(TRIM(v.telefono_whatsapp), '') IS NOT NULL THEN v_score := v_score + 3; END IF;

  IF COALESCE(v.calificacion_cantidad, 0) > 0 THEN
    v_score := v_score + LEAST(COALESCE(v.calificacion_promedio, 0), 5) * 2;
    v_score := v_score + LEAST(COALESCE(v.calificacion_cantidad, 0), 50) * 0.2;
  END IF;

  IF v.local_verificado IS TRUE THEN v_score := v_score + 15; END IF;
  IF v.es_pionero IS TRUE THEN v_score := v_score + 25; END IF;
  IF COALESCE(LOWER(TRIM(v.plan_suscripcion)), 'gratis') NOT IN ('gratis', '', 'free', 'none') THEN
    v_score := v_score + 12;
  END IF;

  SELECT COUNT(*)::int INTO v_carta
  FROM public.locales_carta_items ci
  WHERE ci.id_local = p_local_id AND COALESCE(ci.activo, true) = true;

  IF v_carta > 0 THEN v_score := v_score + LEAST(v_carta, 10) * 1.5; END IF;

  SELECT COUNT(*)::int INTO v_eventos
  FROM public.eventos e
  WHERE e.id_local = p_local_id
    AND e.estado_publicacion = 'publicado'
    AND (e.fecha_fin_publicacion IS NULL OR e.fecha_fin_publicacion > now());

  IF v_eventos > 0 THEN v_score := v_score + LEAST(v_eventos, 5) * 2; END IF;

  SELECT COUNT(*)::int INTO v_promos
  FROM public.promociones p
  WHERE p.id_local = p_local_id
    AND COALESCE(p.estado_promocion, '') = 'activa'
    AND (p.fecha_fin IS NULL OR p.fecha_fin > now());

  IF v_promos > 0 THEN v_score := v_score + LEAST(v_promos, 3) * 2; END IF;

  RETURN ROUND(v_score, 2);
END;
$$;

COMMENT ON FUNCTION public.calcular_score_perfil_local(uuid) IS
  'Score de completitud de perfil para ranking semanal de cartelera de locales.';

-- ---------------------------------------------------------------------------
-- Tabla de cards semanales pre-generadas
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.cartelera_local_cards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  local_id uuid NOT NULL REFERENCES public.perfiles_locales(id) ON DELETE CASCADE,
  ciudad text NOT NULL,
  provincia text NOT NULL,
  ranking_position smallint NOT NULL CHECK (ranking_position BETWEEN 1 AND 12),
  texto_ia text NOT NULL,
  imagenes_urls jsonb NOT NULL DEFAULT '[]'::jsonb,
  avatar_url text,
  nombre_local text NOT NULL,
  rating_promedio numeric(4, 2),
  cantidad_resenas integer NOT NULL DEFAULT 0,
  es_pionero boolean NOT NULL DEFAULT false,
  es_verificado boolean NOT NULL DEFAULT false,
  tiene_plan_activo boolean NOT NULL DEFAULT false,
  score_perfil numeric NOT NULL DEFAULT 0,
  semana_inicio date NOT NULL,
  semana_fin date NOT NULL,
  activo boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT cartelera_local_cards_semana_chk CHECK (semana_fin >= semana_inicio),
  CONSTRAINT cartelera_local_cards_local_semana_uniq UNIQUE (local_id, semana_inicio)
);

CREATE INDEX IF NOT EXISTS idx_cartelera_local_cards_ciudad_semana
  ON public.cartelera_local_cards (ciudad, provincia, semana_inicio DESC, activo)
  WHERE activo = true;

CREATE INDEX IF NOT EXISTS idx_cartelera_local_cards_local_id
  ON public.cartelera_local_cards (local_id);

COMMENT ON TABLE public.cartelera_local_cards IS
  'Cards semanales de locales para rellenar secciones de cartelera cuando hay pocos eventos.';

-- Trigger updated_at
CREATE OR REPLACE FUNCTION public.cartelera_local_cards_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_cartelera_local_cards_updated_at ON public.cartelera_local_cards;
CREATE TRIGGER trg_cartelera_local_cards_updated_at
  BEFORE UPDATE ON public.cartelera_local_cards
  FOR EACH ROW
  EXECUTE FUNCTION public.cartelera_local_cards_set_updated_at();

-- ---------------------------------------------------------------------------
-- RPC: consulta de cards por ubicación (máx 12, semana vigente)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cartelera_local_cards_por_ubicacion(
  p_ciudades text[],
  p_limite integer DEFAULT 12
)
RETURNS TABLE (
  id uuid,
  local_id uuid,
  ciudad text,
  provincia text,
  ranking_position smallint,
  texto_ia text,
  imagenes_urls jsonb,
  avatar_url text,
  nombre_local text,
  rating_promedio numeric,
  cantidad_resenas integer,
  es_pionero boolean,
  es_verificado boolean,
  tiene_plan_activo boolean,
  score_perfil numeric,
  semana_inicio date,
  semana_fin date
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH ciudades_norm AS (
    SELECT DISTINCT TRIM(LOWER(c)) AS ciudad_norm
    FROM unnest(COALESCE(p_ciudades, ARRAY[]::text[])) AS c
    WHERE NULLIF(TRIM(c), '') IS NOT NULL
  ),
  semana AS (
    SELECT
      (date_trunc('week', (now() AT TIME ZONE 'America/Argentina/Cordoba'))::date) AS inicio,
      ((date_trunc('week', (now() AT TIME ZONE 'America/Argentina/Cordoba'))::date) + 6) AS fin
  )
  SELECT
    clc.id,
    clc.local_id,
    clc.ciudad,
    clc.provincia,
    clc.ranking_position,
    clc.texto_ia,
    clc.imagenes_urls,
    clc.avatar_url,
    clc.nombre_local,
    clc.rating_promedio,
    clc.cantidad_resenas,
    clc.es_pionero,
    clc.es_verificado,
    clc.tiene_plan_activo,
    clc.score_perfil,
    clc.semana_inicio,
    clc.semana_fin
  FROM public.cartelera_local_cards clc
  CROSS JOIN semana s
  WHERE clc.activo = true
    AND clc.semana_inicio = s.inicio
    AND clc.semana_fin = s.fin
    AND TRIM(LOWER(clc.ciudad)) IN (SELECT ciudad_norm FROM ciudades_norm)
  ORDER BY
    clc.es_pionero DESC,
    clc.tiene_plan_activo DESC,
    clc.score_perfil DESC,
    clc.ranking_position ASC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limite, 12), 12));
$$;

REVOKE ALL ON FUNCTION public.cartelera_local_cards_por_ubicacion(text[], integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cartelera_local_cards_por_ubicacion(text[], integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cartelera_local_cards_por_ubicacion(text[], integer) TO anon;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.cartelera_local_cards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cartelera_local_cards_select_public ON public.cartelera_local_cards;
CREATE POLICY cartelera_local_cards_select_public
  ON public.cartelera_local_cards
  FOR SELECT
  TO authenticated, anon
  USING (activo = true);

DROP POLICY IF EXISTS cartelera_local_cards_service_all ON public.cartelera_local_cards;
CREATE POLICY cartelera_local_cards_service_all
  ON public.cartelera_local_cards
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
