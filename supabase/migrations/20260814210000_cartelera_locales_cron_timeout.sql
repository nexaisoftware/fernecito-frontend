-- Sube timeout del cron semanal de cartelera locales (IA por ciudad puede >30s).
-- Schedule: lunes 03:10 UTC (= 00:10 ART).

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'generar-cartelera-locales-semanal') THEN
    PERFORM cron.unschedule('generar-cartelera-locales-semanal');
  END IF;

  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron')
     AND EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net')
  THEN
    PERFORM cron.schedule(
      'generar-cartelera-locales-semanal',
      '10 3 * * 1',
      $cron$
      SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url')
          || '/functions/v1/generar_cartelera_locales_semanal',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'cartelera_cron_secret')
        ),
        body := jsonb_build_object('source', 'pg_cron', 'job', 'generar-cartelera-locales-semanal'),
        timeout_milliseconds := 180000
      );
      $cron$
    );
  END IF;
END $$;
