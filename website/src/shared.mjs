// Shared layout pieces for the Lunet site. `node build.mjs` renders every page into ./public.

export const SITE = 'https://lunet.vallepinto.com';
export const APP_STORE = 'https://apps.apple.com/app/id6758315540';
export const VERSION = '2.0';

// SF Symbols–like line icons, 24×24, drawn for this site.
const I = (d, extra = '') =>
  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"${extra}>${d}</svg>`;
export const icon = {
  shield: I('<path d="M12 3 4.5 6v5.5c0 4.6 3.1 8.3 7.5 9.5 4.4-1.2 7.5-4.9 7.5-9.5V6L12 3Z"/><path d="m8.8 12.2 2.2 2.2 4.3-4.6"/>'),
  shieldX: I('<path d="M12 3 4.5 6v5.5c0 4.6 3.1 8.3 7.5 9.5 4.4-1.2 7.5-4.9 7.5-9.5V6L12 3Z"/><path d="m9.5 9.5 5 5m0-5-5 5"/>'),
  route: I('<circle cx="6" cy="18" r="2.2"/><circle cx="18" cy="6" r="2.2"/><path d="M8.2 18H15a3 3 0 0 0 0-6H9a3 3 0 0 1 0-6h6.8"/>'),
  clock: I('<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>'),
  eye: I('<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12Z"/><circle cx="12" cy="12" r="2.8"/>'),
  at: I('<circle cx="12" cy="12" r="3.6"/><path d="M15.6 12v1.6a2.4 2.4 0 0 0 4.8 0V12a8.4 8.4 0 1 0-3.3 6.7"/>'),
  lockOpen: I('<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8.5 10.5V7.5a3.5 3.5 0 0 1 6.8-1.2"/>'),
  lock: I('<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8.5 10.5V7.5a3.5 3.5 0 0 1 7 0v3"/>'),
  wifi: I('<path d="M2.8 9a13.5 13.5 0 0 1 18.4 0"/><path d="M6 12.4a9 9 0 0 1 12 0"/><path d="M9.2 15.7a4.5 4.5 0 0 1 5.6 0"/><circle cx="12" cy="19" r=".9" fill="currentColor"/>'),
  plane: I('<path d="M21 15.5v-1.8l-7.5-4.7V4a1.5 1.5 0 0 0-3 0v5l-7.5 4.7v1.8l7.5-2.3V18l-2 1.5V21l3.5-1 3.5 1v-1.5l-2-1.5v-4.8l7.5 2.3Z"/>'),
  person: I('<circle cx="12" cy="8.5" r="3.8"/><path d="M4.5 20.5c.9-3.7 3.9-5.8 7.5-5.8s6.6 2.1 7.5 5.8"/>'),
  calendar: I('<rect x="3.5" y="5" width="17" height="15.5" rx="3"/><path d="M3.5 10h17M8 3v4M16 3v4"/>'),
  barcode: I('<path d="M4 5v14M7 5v14M10.5 5v14M13 5v14M16.5 5v14M20 5v14" /><path d="M8.6 5v14M18.2 5v14" stroke-width="1"/>'),
  box: I('<path d="m12 3 8 4.5v9L12 21l-8-4.5v-9L12 3Z"/><path d="m4 7.5 8 4.5 8-4.5M12 12v9"/>'),
  envelope: I('<rect x="3" y="5.5" width="18" height="13" rx="2.5"/><path d="m3.5 7 8.5 6 8.5-6"/>'),
  pin: I('<path d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11Z"/><circle cx="12" cy="10" r="2.4"/>'),
  coin: I('<circle cx="12" cy="12" r="8.5"/><path d="M14.8 9.3c-.4-1-1.5-1.6-2.8-1.6-1.6 0-2.8.8-2.8 2.1 0 2.9 5.8 1.5 5.8 4.4 0 1.3-1.2 2.1-2.9 2.1-1.4 0-2.5-.6-2.9-1.7M12 6v1.7M12 16.3V18"/>'),
  search: I('<circle cx="10.5" cy="10.5" r="6"/><path d="m15 15 5.5 5.5"/>'),
  faceid: I('<path d="M4 8V6.5A2.5 2.5 0 0 1 6.5 4H8M16 4h1.5A2.5 2.5 0 0 1 20 6.5V8M20 16v1.5a2.5 2.5 0 0 1-2.5 2.5H16M8 20H6.5A2.5 2.5 0 0 1 4 17.5V16"/><path d="M9 9v1.2M15 9v1.2M12 9v4h-1M9.3 15.5a4 4 0 0 0 5.4 0"/>'),
  table: I('<rect x="3.5" y="4.5" width="17" height="15" rx="2.5"/><path d="M3.5 9.5h17M3.5 14.5h17M10 9.5v10"/>'),
  sparkle: I('<path d="M12 3.5 13.9 9 19.5 11 13.9 13 12 18.5 10.1 13 4.5 11 10.1 9 12 3.5Z"/><path d="M19 3v3M17.5 4.5h3"/>'),
  check: I('<circle cx="12" cy="12" r="8.5"/><path d="m8.3 12.3 2.5 2.5 5-5.3"/>'),
  palette: I('<path d="M12 3.5a8.5 8.5 0 1 0 0 17c1.2 0 1.8-.8 1.8-1.7 0-1.2-1-1.5-1-2.6 0-1 .8-1.7 1.8-1.7h2.2a3.7 3.7 0 0 0 3.7-3.7c0-4.1-3.8-7.3-8.5-7.3Z"/><circle cx="7.8" cy="11.5" r="1.1" fill="currentColor"/><circle cx="10.5" cy="7.6" r="1.1" fill="currentColor"/><circle cx="15" cy="7.8" r="1.1" fill="currentColor"/>'),
  qr: I('<rect x="4" y="4" width="6" height="6" rx="1.2"/><rect x="14" y="4" width="6" height="6" rx="1.2"/><rect x="4" y="14" width="6" height="6" rx="1.2"/><path d="M14 14h2.5v2.5H14zM17.5 17.5H20V20h-2.5zM14 19v1M20 14v1"/>'),
  sliders: I('<path d="M5 4v16M12 4v16M19 4v16"/><circle cx="5" cy="14" r="2.2" fill="var(--card)"/><circle cx="12" cy="8" r="2.2" fill="var(--card)"/><circle cx="19" cy="15.5" r="2.2" fill="var(--card)"/>'),
  action: I('<rect x="7" y="2.5" width="10" height="19" rx="3"/><path d="M4 7.5v4" stroke-width="2.4"/>'),
  widget: I('<rect x="3.5" y="3.5" width="7.5" height="7.5" rx="2"/><rect x="13" y="3.5" width="7.5" height="7.5" rx="2"/><rect x="3.5" y="13" width="17" height="7.5" rx="2"/>'),
  island: I('<rect x="2.5" y="7.5" width="19" height="9" rx="4.5"/><circle cx="17" cy="12" r="1.6" fill="currentColor"/>'),
  wave: I('<path d="M4 12h1.5M8 8v8M11.5 5v14M15 9v6M18.5 11v2"/>'),
  lockscreen: I('<rect x="6" y="2.5" width="12" height="19" rx="3"/><path d="M9.5 6.5h5M10 17.5h4"/><circle cx="12" cy="11.5" r="2.2"/>'),
  controls: I('<rect x="3.5" y="3.5" width="7.5" height="7.5" rx="3.75"/><rect x="13" y="3.5" width="7.5" height="7.5" rx="3.75"/><rect x="3.5" y="13" width="7.5" height="7.5" rx="3.75"/><rect x="13" y="13" width="7.5" height="7.5" rx="3.75"/>'),
  photo: I('<rect x="3.5" y="4.5" width="17" height="15" rx="3"/><circle cx="9" cy="9.5" r="1.7"/><path d="m4 17 4.8-4.5 3.5 3.2 2.7-2.4 5 4.2"/>'),
  globe: I('<circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5c2.3 2.4 3.4 5.2 3.4 8.5s-1.1 6.1-3.4 8.5c-2.3-2.4-3.4-5.2-3.4-8.5S9.7 5.9 12 3.5Z"/>'),
  wallet: I('<rect x="3.5" y="5" width="17" height="14.5" rx="3"/><path d="M3.5 9.5h17M15 14.5h2.5"/>'),
  camera: I('<path d="M4 8.5A2.5 2.5 0 0 1 6.5 6h1.8l1.5-2h4.4l1.5 2h1.8A2.5 2.5 0 0 1 20 8.5v9a2.5 2.5 0 0 1-2.5 2.5h-11A2.5 2.5 0 0 1 4 17.5v-9Z"/><circle cx="12" cy="12.8" r="3.5"/>'),
  arrow: I('<path d="M5 12h14m-5-5 5 5-5 5"/>'),
};

// Apple's "Download on the App Store" badge (black, #A6A6A6 hairline), per the App Store marketing guidelines.
const appleLogo =
  'M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701';
export function badge(lang, size = '') {
  const top = lang === 'es' ? 'Descárgalo en el' : 'Download on the';
  const label = lang === 'es' ? 'Descárgalo en el App Store' : 'Download on the App Store';
  const w = lang === 'es' ? 126 : 120;
  return `<a class="badge${size ? ' ' + size : ''}" href="${APP_STORE}">` +
    `<svg viewBox="0 0 ${w} 40" width="${w * 1.35}" height="54" role="img" aria-label="${label}">` +
    `<rect x=".5" y=".5" width="${w - 1}" height="39" rx="6.5" fill="#000" stroke="#A6A6A6"/>` +
    `<path transform="translate(9.5 7.6) scale(1.02)" fill="#fff" d="${appleLogo}"/>` +
    `<text x="38.5" y="15.6" fill="#fff" font-family="-apple-system,BlinkMacSystemFont,'SF Pro Text','Helvetica Neue',Arial,sans-serif" font-size="8" letter-spacing=".05">${top}</text>` +
    `<text x="37.8" y="31" fill="#fff" font-family="-apple-system,BlinkMacSystemFont,'SF Pro Display','Helvetica Neue',Arial,sans-serif" font-size="17.2" font-weight="600" letter-spacing="-.45">App Store</text>` +
    `</svg></a>`;
}

// A screenshot in a device frame; swaps to the dark-mode capture when the visitor is in dark mode.
export function phone(lang, name, alt, cls = '', eager = false, sizes = '(max-width: 600px) 72vw, 300px') {
  const dir = lang === 'es' ? '/shots/es/' : '/shots/';
  const load = eager ? 'fetchpriority="high"' : 'loading="lazy"';
  const set = (m) => `${dir}${name}-${m}-480.webp 480w, ${dir}${name}-${m}.webp 640w`;
  return `<div class="phone ${cls}"><picture>` +
    `<source srcset="${set('dark')}" sizes="${sizes}" media="(prefers-color-scheme: dark)">` +
    `<img src="${dir}${name}-light.webp" srcset="${set('light')}" sizes="${sizes}" width="640" height="1391" alt="${alt}" ${load} decoding="async">` +
    `</picture></div>`;
}

const paths = { home: { en: '/', es: '/es/' }, support: { en: '/support', es: '/es/support' }, privacy: { en: '/privacy', es: '/es/privacy' } };

const t = {
  en: {
    skip: 'Skip to content', features: 'Features', privacy: 'Privacy', support: 'Support', get: 'Get Lunet',
    other: 'es', otherLabel: 'Español', switchLabel: 'Ver en español', home: 'Lunet home',
    footer: 'Lunet is free on the App Store for iPhone and iPad.', made: 'Made with care in Mexico.',
    nav: 'Main',
  },
  es: {
    skip: 'Ir al contenido', features: 'Funciones', privacy: 'Privacidad', support: 'Soporte', get: 'Obtener Lunet',
    other: 'en', otherLabel: 'English', switchLabel: 'View in English', home: 'Inicio de Lunet',
    footer: 'Lunet es gratis en el App Store para iPhone y iPad.', made: 'Hecho con cuidado en México.',
    nav: 'Principal',
  },
};

export function layout({ lang, page, title, description, body, jsonld = '', scripts = '' }) {
  const s = t[lang];
  const url = SITE + paths[page][lang];
  const other = s.other;
  const home = paths.home[lang];
  const cur = (p) => (p === page ? ' aria-current="page"' : '');
  const ogLocale = lang === 'es' ? 'es_MX' : 'en_US';
  return `<!doctype html>
<html lang="${lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${title}</title>
<meta name="description" content="${description}">
<link rel="canonical" href="${url}">
<link rel="alternate" hreflang="en" href="${SITE + paths[page].en}">
<link rel="alternate" hreflang="es" href="${SITE + paths[page].es}">
<link rel="alternate" hreflang="x-default" href="${SITE + paths[page].en}">
<meta name="theme-color" content="#fbfbfd" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#000000" media="(prefers-color-scheme: dark)">
<meta name="color-scheme" content="light dark">
<meta name="apple-itunes-app" content="app-id=6758315540">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Lunet">
<meta property="og:locale" content="${ogLocale}">
<meta property="og:title" content="${title}">
<meta property="og:description" content="${description}">
<meta property="og:url" content="${url}">
<meta property="og:image" content="${SITE}/og${lang === 'es' ? '-es' : ''}.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="${lang === 'es' ? 'Lunet — Escanea lo que sea. Sabe antes de abrir.' : 'Lunet — Scan anything. Know before you go.'}">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" href="/favicon.ico" sizes="32x32">
<link rel="icon" href="/favicon-32.png" sizes="32x32" type="image/png">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="manifest" href="/site.webmanifest">
<link rel="stylesheet" href="/assets/site.css?v=1">
${jsonld}</head>
<body>
<a class="skip" href="#main">${s.skip}</a>
<header class="nav">
  <div class="wrap">
    <a class="brand" href="${home}" aria-label="${s.home}"><picture><source srcset="/img/icon-dark-256.webp" media="(prefers-color-scheme: dark)"><img src="/img/icon-default-256.webp" width="28" height="28" alt=""></picture>Lunet</a>
    <nav aria-label="${s.nav}">
      <ul>
        ${page === 'home' ? `<li class="hide-sm"><a href="#safety">${s.features}</a></li>` : `<li class="hide-sm"><a href="${home}">${s.features}</a></li>`}
        <li><a href="${paths.privacy[lang]}"${cur('privacy')}>${s.privacy}</a></li>
        <li><a href="${paths.support[lang]}"${cur('support')}>${s.support}</a></li>
      </ul>
    </nav>
    <a class="lang" href="${paths[page][other]}" hreflang="${other}" lang="${other}" title="${s.switchLabel}">${other.toUpperCase()}</a>
    <a class="get" href="${APP_STORE}">${s.get}</a>
  </div>
</header>
<main id="main">
${body}
</main>
<footer>
  <div class="wrap">
    <p>© 2026 Lunet. ${s.footer}</p>
    <nav aria-label="Footer">
      <a href="${home}">Lunet</a>
      <a href="${paths.privacy[lang]}">${s.privacy}</a>
      <a href="${paths.support[lang]}">${s.support}</a>
      <a href="${paths[page][other]}" hreflang="${other}" lang="${other}">${s.otherLabel}</a>
    </nav>
  </div>
</footer>
${scripts}</body>
</html>
`;
}

// Email assembled in the browser so the address never appears whole in the HTML.
export function mail(lang, cls = 'mail') {
  const fallback = lang === 'es' ? 'rovapin (arroba) gmail (punto) com' : 'rovapin (at) gmail (dot) com';
  return `<a class="${cls}" data-u="rovapin" data-d="gmail.com" href="#contact">${fallback}</a>`;
}
export const mailScript = '<script src="/assets/mail.js" defer></script>\n';
