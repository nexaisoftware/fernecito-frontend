-- Cartelera local cards: match por aliases de ciudad (Córdoba ↔ Córdoba capital)
-- y top global entre todas las ciudades pedidas (tope 12).

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
    SELECT DISTINCT public._normalizar_texto_ubicacion(c) AS ciudad_norm
    FROM unnest(COALESCE(p_ciudades, ARRAY[]::text[])) AS c
    WHERE NULLIF(TRIM(c), '') IS NOT NULL
  ),
  pide_cordoba AS (
    SELECT EXISTS (
      SELECT 1 FROM ciudades_norm cn
      WHERE public._grupo_ciudad_cordoba(cn.ciudad_norm)
    ) AS si
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
  CROSS JOIN pide_cordoba pc
  WHERE clc.activo = true
    AND clc.semana_inicio = s.inicio
    AND clc.semana_fin = s.fin
    AND (
      public._normalizar_texto_ubicacion(clc.ciudad) IN (SELECT ciudad_norm FROM ciudades_norm)
      OR (
        pc.si
        AND public._grupo_ciudad_cordoba(public._normalizar_texto_ubicacion(clc.ciudad))
      )
    )
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

COMMENT ON FUNCTION public.cartelera_local_cards_por_ubicacion(text[], integer) IS
  'Top hasta 12 cards semanales entre las ciudades del filtro (aliases Córdoba incluidos).';
