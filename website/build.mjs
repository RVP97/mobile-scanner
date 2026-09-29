// Renders the Lunet site into ./public. Run: node build.mjs
import { writeFileSync, mkdirSync } from 'node:fs';
import { home } from './src/home.mjs';
import { support } from './src/support.mjs';
import { privacy } from './src/privacy.mjs';
import { SITE } from './src/shared.mjs';

const out = (path, html) => {
  const file = new URL('./public/' + path, import.meta.url);
  mkdirSync(new URL('.', file), { recursive: true });
  writeFileSync(file, html);
  console.log(`${path.padEnd(18)} ${(Buffer.byteLength(html) / 1024).toFixed(1)} KB`);
};

out('index.html', home('en'));
out('es/index.html', home('es'));
out('support.html', support('en'));
out('es/support.html', support('es'));
out('privacy.html', privacy('en'));
out('es/privacy.html', privacy('es'));

out('404.html', `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Page not found · Lunet</title>
<meta name="robots" content="noindex">
<meta name="color-scheme" content="light dark">
<link rel="icon" href="/favicon.ico" sizes="32x32">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="stylesheet" href="/assets/site.css?v=1">
</head>
<body>
<header class="nav"><div class="wrap"><a class="brand" href="/"><picture><source srcset="/img/icon-dark-256.webp" media="(prefers-color-scheme: dark)"><img src="/img/icon-default-256.webp" width="28" height="28" alt=""></picture>Lunet</a></div></header>
<main class="nf">
  <div class="wrap">
    <picture>
      <source srcset="/img/icon-dark-256.webp" media="(prefers-color-scheme: dark)">
      <img src="/img/icon-default-256.webp" width="96" height="96" alt="">
    </picture>
    <h1>Nothing to scan here.</h1>
    <p>This page doesn’t exist. <span lang="es">Esta página no existe.</span></p>
    <a class="btn" href="/">Go to Lunet</a>
    <p class="fine"><a href="/es/" lang="es">Ir a Lunet en español</a></p>
  </div>
</main>
</body>
</html>
`);

const pages = [['/', '/es/'], ['/support', '/es/support'], ['/privacy', '/es/privacy']];
const today = '2026-09-28';
out('sitemap.xml', `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
${pages.flatMap(([en, es]) => [en, es].map((loc) => `  <url>
    <loc>${SITE}${loc}</loc>
    <lastmod>${today}</lastmod>
    <xhtml:link rel="alternate" hreflang="en" href="${SITE}${en}"/>
    <xhtml:link rel="alternate" hreflang="es" href="${SITE}${es}"/>
    <xhtml:link rel="alternate" hreflang="x-default" href="${SITE}${en}"/>
  </url>`)).join('\n')}
</urlset>
`);
