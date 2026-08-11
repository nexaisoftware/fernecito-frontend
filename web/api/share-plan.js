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
  const appUrl = `${base}/?plan=${encodeURIComponent(id)}`;
  const publicUrl = `${base}/share-plan?id=${encodeURIComponent(id)}`;

  if (!isSocialCrawler(req.headers['user-agent'])) {
    res.writeHead(302, {
      Location: appUrl,
      'Cache-Control': 'public, max-age=120',
    });
    res.end();
    return;
  }

  const title = 'Plan en Fernecito';
  const description = 'Sumate a este plan en Fernecitoapp';
  const html = `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8" />
  <title>${title}</title>
  <meta property="og:title" content="${title}" />
  <meta property="og:description" content="${description}" />
  <meta property="og:url" content="${publicUrl}" />
  <meta property="og:type" content="website" />
  <meta name="twitter:card" content="summary" />
  <link rel="canonical" href="${appUrl}" />
  <meta http-equiv="refresh" content="0;url=${appUrl}" />
</head>
<body>
  <p><a href="${appUrl}">Abrir plan</a></p>
</body>
</html>`;

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 'public, max-age=600');
  res.status(200).send(html);
}
