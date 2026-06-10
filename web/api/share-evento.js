const SUPABASE_SHARE_BASE =
  'https://cuzphjyfidttkylfwkdg.supabase.co/functions/v1/share_evento';

function isSocialCrawler(userAgent = '') {
  const ua = userAgent.toLowerCase();
  return [
    'whatsapp',
    'facebookexternalhit',
    'facebot',
    'twitterbot',
    'telegrambot',
    'linkedinbot',
    'slackbot',
    'discordbot',
    'googlebot',
  ].some((token) => ua.includes(token));
}

function absoluteBase(req) {
  const proto = req.headers['x-forwarded-proto'] || 'https';
  const host = req.headers.host || 'appusuarios.fernecitoapp.com';
  return `${proto}://${host}`;
}

export default async function handler(req, res) {
  const id = String(req.query.id || '').trim();
  if (!id) {
    res.status(400).send('Missing id');
    return;
  }

  const base = absoluteBase(req);
  const appUrl = `${base}/?evento=${encodeURIComponent(id)}`;
  const publicUrl = `${base}/share-evento?id=${encodeURIComponent(id)}`;
  const wantsOgImage = String(req.query.og || '') === '1';

  if (wantsOgImage) {
    const imageUrl = `${SUPABASE_SHARE_BASE}?id=${encodeURIComponent(id)}&og=1`;
    const imageRes = await fetch(imageUrl);
    const contentType = imageRes.headers.get('content-type') || 'image/jpeg';
    const cacheControl =
      imageRes.headers.get('cache-control') || 'public, max-age=86400';

    res.setHeader('Content-Type', contentType);
    res.setHeader('Cache-Control', cacheControl);
    res.status(imageRes.ok ? 200 : imageRes.status);
    res.send(Buffer.from(await imageRes.arrayBuffer()));
    return;
  }

  if (!isSocialCrawler(req.headers['user-agent'])) {
    res.writeHead(302, {
      Location: appUrl,
      'Cache-Control': 'public, max-age=120',
    });
    res.end();
    return;
  }

  const edgeUrl = `${SUPABASE_SHARE_BASE}?id=${encodeURIComponent(id)}`;
  const edgeRes = await fetch(edgeUrl, {
    headers: {
      'user-agent': req.headers['user-agent'] || 'WhatsApp',
    },
  });

  let html = await edgeRes.text();
  html = html
    .replaceAll(edgeUrl.replaceAll('&', '&amp;'), publicUrl.replaceAll('&', '&amp;'))
    .replaceAll(edgeUrl, publicUrl)
    .replace(
      /<link rel="canonical" href="[^"]*" \/>/,
      `<link rel="canonical" href="${appUrl}" />`,
    );

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 'public, max-age=600');
  res.status(edgeRes.ok ? 200 : edgeRes.status).send(html);
}
