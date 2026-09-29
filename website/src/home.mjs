import { icon, badge, phone, layout, SITE, APP_STORE } from './shared.mjs';

const copy = {
  en: {
    title: 'Lunet — QR & Barcode Scanner that checks links first',
    description: 'Scan any QR code or barcode and know where it really goes before you open it. Join Wi-Fi, add boarding passes to Wallet, save contacts. Free, private, no account.',
    eyebrow: 'QR & barcode scanner for iPhone',
    h1a: 'Scan anything.', h1b: 'Know before you go.',
    lede: 'Lunet reads any QR code or barcode in an instant and checks where a link really goes before it opens. Then it does the right thing — joins the Wi-Fi, adds the boarding pass, saves the contact.',
    fine: '<b>Free</b> · No account · No ads · No tracking',
    alts: {
      home: 'Lunet Home with a boarding pass and Wi-Fi card under Your codes, and recent scans',
      danger: 'Lunet warning that a code for n0rthbank-login.co isn’t what it says',
      wifi: 'Lunet result for a Wi-Fi code with a Join Network button',
      travel: 'Lunet result for a boarding pass from Mexico City to San Francisco',
      show: 'A Wi-Fi code shown full screen at full brightness',
      studio: 'The Lunet Studio styling a Wi-Fi QR code, verified to scan',
      history: 'Lunet History with pinned scans and filters',
    },
    safety: {
      kicker: 'Safety first',
      h2: 'That code on the parking meter <span class="dim">might not be what it says.</span>',
      p: 'QR phishing — “quishing” — is surging: a sticker over a real code, a link that looks almost right. Lunet checks every link before it opens, and when something’s off, <strong>Don’t Open</strong> is the default.',
      real: 'The real one', fake: 'On the sticker',
      note: 'One character apart. Lunet catches lookalikes like this, follows every redirect to the real destination, and tells you in plain words why it’s worried.',
      points: [
        ['route', 'The real destination', 'Follows each redirect and shortener, so you see where you’ll actually land.'],
        ['clock', 'Domain age', 'A site registered last week asking for your bank login is a red flag. Lunet checks.'],
        ['eye', 'Lookalikes & homographs', 'n0rthbank isn’t northbank — and letters from other alphabets can’t hide either.'],
        ['at', '@-tricks', 'Everything before an “@” in a link is ignored. Lunet shows you the address that really opens.'],
        ['lockOpen', 'Insecure links', 'Unencrypted pages and bare IP addresses are called out before you tap.'],
      ],
      verdicts: ['Safe', 'Be careful', 'Danger'],
    },
    answers: {
      kicker: 'Every code gets its own answer',
      h2: 'Not just a link. <span class="dim">The right next step.</span>',
      p: 'Lunet understands what’s inside a code and puts the useful action first — no copying, pasting or typing a password off a tiny card.',
      kinds: [
        ['wifi', 'k-wifi', 'Wi-Fi', 'Join the network in one tap.'],
        ['plane', 'k-travel', 'Boarding passes', 'Add to Apple Wallet or your calendar.'],
        ['person', 'k-contact', 'Contacts', 'Save the card straight to Contacts.'],
        ['calendar', 'k-event', 'Events', 'Add it to your calendar, time zone and all.'],
        ['barcode', 'k-product', 'Products', 'Look it up, with the check digit verified.'],
        ['box', 'k-ship', 'Packages', 'Track it with the right carrier.'],
        ['envelope', 'k-link', 'Email & messages', 'Open a draft, ready to send.'],
        ['pin', 'k-map', 'Places', 'Open the spot in Maps.'],
        ['coin', 'k-crypto', 'Crypto addresses', 'Copy it — with a reminder to double-check.'],
      ],
      formats: 'Reads 19 formats — QR, Aztec, PDF417, Data Matrix, EAN, UPC, Code 128 and more — from the camera, a photo or a screenshot. Multi-scan catches several codes at once.',
    },
    codes: {
      kicker: 'Your codes, one tap away',
      h2: 'Your Wi-Fi. Your card. <span class="dim">Your flight.</span>',
      p: 'Keep the codes you share most as Wallet-style cards right on Home. One tap shows them full screen at full brightness — ready for a friend’s camera or the gate scanner.',
      points: [
        ['search', 'History that finds things', 'Search, filter by kind, and pin the scans you come back to.'],
        ['faceid', 'Locked with Face ID', 'Keep History behind Face ID or your passcode.'],
        ['pin', 'Where you scanned', 'Optionally remember the place — it never leaves your iPhone.'],
        ['table', 'Yours to export', 'Export History as a CSV whenever you like.'],
      ],
    },
    studio: {
      kicker: 'Make it yours',
      h2: 'Codes that look like you. <span class="dim">And still scan.</span>',
      p: 'Create a code for your Wi-Fi, a link, a contact card, an event, a place, a product barcode and more. Then style it in the Studio — and Lunet checks on your iPhone that it still scans.',
      points: [
        ['sliders', 'Dots, corners, colors', 'Shape the modules and eyes, pick colors or a gradient, add your logo and a frame.'],
        ['sparkle', 'Presets to start from', 'Classic, Soft, Lagoon, Forest, Berry — then make them your own.'],
        ['check', 'Verified before you share', 'Every design is scanned on-device, with its contrast, so what you print works.'],
        ['qr', '15 barcode symbologies', 'From QR to EAN-13, Code 128, PDF417 and Aztec.'],
      ],
    },
    everywhere: {
      kicker: 'Everywhere',
      h2: 'Scan from anywhere. <span class="dim">Even the Lock Screen.</span>',
      p: 'Lunet is there before you’ve even unlocked your iPhone.',
      tiles: [
        ['controls', 'Control Center', 'Add the Scan control and it’s a swipe away.'],
        ['lockscreen', 'Lock Screen', 'Scan straight from the Lock Screen, no unlocking first.'],
        ['action', 'Action button', 'Press and hold to scan on iPhone 15 Pro and later.'],
        ['widget', 'Widgets', 'A Scan widget, and My Code to keep your Wi-Fi or card on Home Screen.'],
        ['island', 'Live Activity', 'Multi-scan keeps count on the Lock Screen and in the Dynamic Island.'],
        ['wave', 'Siri & Shortcuts', 'Say “Scan a code with Lunet,” or read codes in an image from any shortcut.'],
      ],
    },
    privacy: {
      h2: 'Private by design.',
      p: 'Your scans are yours. History stays on your iPhone, and Lunet only goes online when a feature truly needs to.',
      nos: ['No account', 'No ads', 'No tracking', 'No analytics'],
      net: [
        ['Link deep check', 'Contacts the link’s own server to follow redirects, and a public registry for the domain’s age. Nothing is sent to Lunet.'],
        ['Product lookup', 'Sends only the barcode number to the open Open Food Facts database.'],
        ['Add to Apple Wallet', 'Pass details go to Lunet’s signing service to create the pass. Nothing is stored.'],
      ],
      more: 'Read the privacy policy',
    },
    faqTitle: 'Questions',
    faq: [
      ['Is Lunet free?', '<p>Yes. Lunet is free to download, with no ads and no account.</p>'],
      ['I used Fast QR & Barcode. What happens?', '<p>Lunet is its next version. When you update, your scan and creation history comes along automatically, right on your iPhone.</p>'],
      ['How does Lunet know a link is dangerous?', '<p>It checks the link on your iPhone for lookalike names, homographs, @-tricks, shorteners and insecure connections. With Deep check on, it also follows redirects to the final destination and looks up how old the domain is. You get a clear verdict — Safe, Be careful or Danger — with the reasons.</p><p>No checker is perfect, so Lunet always shows you the real address and leaves the final call to you.</p>'],
      ['Does it work offline?', '<p>Scanning, creating, the Studio and History all work offline. Deep link checks, product lookups and Add to Apple Wallet need a connection.</p>'],
      ['Can I scan a code in a photo or screenshot?', '<p>Yes — pick an image from Photos, or use the Read a Code in an Image action in Shortcuts.</p>'],
      ['Which devices and languages?', '<p>iPhone and iPad with iOS 17 or later, designed for iOS 26 and Liquid Glass. Lunet speaks 39 languages and supports Dynamic Type, VoiceOver and dark mode.</p>'],
    ],
    finalH: 'Scan with confidence.',
    finalP: 'Free on the App Store for iPhone and iPad.',
  },
  es: {
    title: 'Lunet — Escáner QR y de códigos que revisa los enlaces',
    description: 'Escanea cualquier código QR o de barras y sabe a dónde lleva antes de abrirlo. Conéctate al Wi-Fi, agrega pases de abordar a Wallet, guarda contactos. Gratis, privado y sin cuenta.',
    eyebrow: 'Escáner QR y de códigos de barras para iPhone',
    h1a: 'Escanea lo que sea.', h1b: 'Sabe antes de abrir.',
    lede: 'Lunet lee cualquier código QR o de barras al instante y revisa a dónde lleva un enlace antes de abrirlo. Luego hace lo correcto: se conecta al Wi-Fi, agrega el pase de abordar, guarda el contacto.',
    fine: '<b>Gratis</b> · Sin cuenta · Sin anuncios · Sin rastreo',
    alts: {
      home: 'Inicio de Lunet con un pase de abordar y una tarjeta de Wi-Fi en Tus códigos, y escaneos recientes',
      danger: 'Lunet advierte que un código de n0rthbank-login.co no es lo que dice ser',
      wifi: 'Resultado de Lunet para un código de Wi-Fi con el botón Conectarse a la red',
      travel: 'Resultado de Lunet para un pase de abordar de Ciudad de México a San Francisco',
      show: 'Un código de Wi-Fi en pantalla completa con el brillo al máximo',
      studio: 'El Estudio de Lunet dando estilo a un QR de Wi-Fi, verificado',
      history: 'Historial de Lunet con escaneos fijados y filtros',
    },
    safety: {
      kicker: 'Primero, tu seguridad',
      h2: 'Ese código en el parquímetro <span class="dim">quizá no sea lo que dice.</span>',
      p: 'El phishing con QR —“quishing”— va en aumento: una calcomanía sobre el código real, un enlace que se ve casi igual. Lunet revisa cada enlace antes de abrirlo y, si algo no cuadra, <strong>No abrir</strong> es la opción predeterminada.',
      real: 'El real', fake: 'En la calcomanía',
      note: 'Un solo carácter de diferencia. Lunet detecta imitaciones así, sigue cada redirección hasta el destino real y te explica en palabras claras qué le preocupa.',
      points: [
        ['route', 'El destino real', 'Sigue cada redirección y acortador para que veas a dónde vas a llegar de verdad.'],
        ['clock', 'Antigüedad del dominio', 'Un sitio registrado la semana pasada que pide los datos de tu banco es mala señal. Lunet lo revisa.'],
        ['eye', 'Imitaciones y homógrafos', 'n0rthbank no es northbank, y las letras de otros alfabetos tampoco pueden esconderse.'],
        ['at', 'Trucos con @', 'Todo lo que va antes de una “@” en un enlace se ignora. Lunet te muestra la dirección que de verdad se abre.'],
        ['lockOpen', 'Enlaces inseguros', 'Las páginas sin cifrar y las direcciones IP sueltas se señalan antes de que toques.'],
      ],
      verdicts: ['Seguro', 'Ten cuidado', 'Peligro'],
    },
    answers: {
      kicker: 'Cada código tiene su respuesta',
      h2: 'No es solo un enlace. <span class="dim">Es el siguiente paso.</span>',
      p: 'Lunet entiende lo que hay dentro de un código y pone primero la acción útil: nada de copiar, pegar ni teclear una contraseña de una tarjetita.',
      kinds: [
        ['wifi', 'k-wifi', 'Wi-Fi', 'Conéctate a la red con un toque.'],
        ['plane', 'k-travel', 'Pases de abordar', 'Agrégalos a Apple Wallet o a tu calendario.'],
        ['person', 'k-contact', 'Contactos', 'Guarda la tarjeta directo en Contactos.'],
        ['calendar', 'k-event', 'Eventos', 'Agrégalo a tu calendario, con todo y zona horaria.'],
        ['barcode', 'k-product', 'Productos', 'Búscalo, con el dígito verificador comprobado.'],
        ['box', 'k-ship', 'Paquetes', 'Rastréalo con la paquetería correcta.'],
        ['envelope', 'k-link', 'Correo y mensajes', 'Abre un borrador listo para enviar.'],
        ['pin', 'k-map', 'Lugares', 'Abre el sitio en Mapas.'],
        ['coin', 'k-crypto', 'Direcciones cripto', 'Cópiala, con un recordatorio para verificarla.'],
      ],
      formats: 'Lee 19 formatos —QR, Aztec, PDF417, Data Matrix, EAN, UPC, Code 128 y más— con la cámara, una foto o una captura de pantalla. El escaneo múltiple detecta varios códigos a la vez.',
    },
    codes: {
      kicker: 'Tus códigos, a un toque',
      h2: 'Tu Wi-Fi. Tu tarjeta. <span class="dim">Tu vuelo.</span>',
      p: 'Guarda los códigos que más compartes como tarjetas estilo Wallet en Inicio. Un toque los muestra en pantalla completa con el brillo al máximo, listos para la cámara de un amigo o el lector de la puerta de embarque.',
      points: [
        ['search', 'Un historial que encuentra', 'Busca, filtra por tipo y fija los escaneos a los que vuelves.'],
        ['faceid', 'Protegido con Face ID', 'Mantén el Historial detrás de Face ID o tu código.'],
        ['pin', 'Dónde escaneaste', 'Si quieres, recuerda el lugar. Nunca sale de tu iPhone.'],
        ['table', 'Tuyo para exportar', 'Exporta el Historial en CSV cuando quieras.'],
      ],
    },
    studio: {
      kicker: 'Hazlo tuyo',
      h2: 'Códigos con tu estilo. <span class="dim">Y que sí se escanean.</span>',
      p: 'Crea un código para tu Wi-Fi, un enlace, una tarjeta de contacto, un evento, un lugar, un código de producto y más. Luego dale estilo en el Estudio, y Lunet comprueba en tu iPhone que se siga escaneando.',
      points: [
        ['sliders', 'Puntos, esquinas, colores', 'Da forma a los módulos y a los ojos, elige colores o un degradado, agrega tu logo y un marco.'],
        ['sparkle', 'Estilos para empezar', 'Clásico, Suave, Laguna, Bosque, Mora… y luego hazlos tuyos.'],
        ['check', 'Verificado antes de compartir', 'Cada diseño se escanea en el dispositivo, con su contraste, para que lo que imprimas funcione.'],
        ['qr', '15 simbologías', 'De QR a EAN-13, Code 128, PDF417 y Aztec.'],
      ],
    },
    everywhere: {
      kicker: 'En todas partes',
      h2: 'Escanea desde donde sea. <span class="dim">Hasta en la pantalla bloqueada.</span>',
      p: 'Lunet está ahí incluso antes de desbloquear tu iPhone.',
      tiles: [
        ['controls', 'Centro de control', 'Agrega el control Escanear y lo tienes a un deslizamiento.'],
        ['lockscreen', 'Pantalla bloqueada', 'Escanea directo desde la pantalla bloqueada, sin desbloquear.'],
        ['action', 'Botón de acción', 'Mantén presionado para escanear en iPhone 15 Pro y posteriores.'],
        ['widget', 'Widgets', 'Un widget para escanear y Mi código para tener tu Wi-Fi o tarjeta en la pantalla de inicio.'],
        ['island', 'Actividad en vivo', 'El escaneo múltiple lleva la cuenta en la pantalla bloqueada y en la Dynamic Island.'],
        ['wave', 'Siri y Atajos', 'Pídele a Siri que escanee con Lunet, o lee los códigos de una imagen desde cualquier atajo.'],
      ],
    },
    privacy: {
      h2: 'Privado desde el diseño.',
      p: 'Tus escaneos son tuyos. El Historial se queda en tu iPhone y Lunet solo se conecta cuando una función de verdad lo necesita.',
      nos: ['Sin cuenta', 'Sin anuncios', 'Sin rastreo', 'Sin analíticas'],
      net: [
        ['Revisión a fondo de enlaces', 'Contacta al propio servidor del enlace para seguir redirecciones, y un registro público para la antigüedad del dominio. No se envía nada a Lunet.'],
        ['Búsqueda de productos', 'Envía solo el número del código de barras a la base abierta Open Food Facts.'],
        ['Agregar a Apple Wallet', 'Los datos del pase van al servicio de firma de Lunet para crear el pase. No se guarda nada.'],
      ],
      more: 'Lee el aviso de privacidad',
    },
    faqTitle: 'Preguntas',
    faq: [
      ['¿Lunet es gratis?', '<p>Sí. Lunet se descarga gratis, sin anuncios y sin cuenta.</p>'],
      ['Usaba Fast QR & Barcode. ¿Qué pasa?', '<p>Lunet es su nueva versión. Al actualizar, tu historial de escaneos y de códigos creados se pasa solo, directo en tu iPhone.</p>'],
      ['¿Cómo sabe Lunet que un enlace es peligroso?', '<p>Revisa el enlace en tu iPhone en busca de nombres que imitan a otros, homógrafos, trucos con @, acortadores y conexiones inseguras. Con la Revisión a fondo, además sigue las redirecciones hasta el destino final y consulta la antigüedad del dominio. Recibes un veredicto claro —Seguro, Ten cuidado o Peligro— con sus motivos.</p><p>Ningún verificador es perfecto, así que Lunet siempre te muestra la dirección real y la decisión final es tuya.</p>'],
      ['¿Funciona sin conexión?', '<p>Escanear, crear, el Estudio y el Historial funcionan sin conexión. La revisión a fondo de enlaces, la búsqueda de productos y Agregar a Apple Wallet necesitan internet.</p>'],
      ['¿Puedo escanear un código en una foto o captura?', '<p>Sí: elige una imagen de Fotos o usa la acción de Lunet para leer códigos en una imagen en Atajos.</p>'],
      ['¿En qué dispositivos e idiomas?', '<p>iPhone y iPad con iOS 17 o posterior, diseñado para iOS 26 y Liquid Glass. Lunet habla 39 idiomas y es compatible con Texto dinámico, VoiceOver y modo oscuro.</p>'],
    ],
    finalH: 'Escanea con confianza.',
    finalP: 'Gratis en el App Store para iPhone y iPad.',
  },
};

const pointList = (items) =>
  `<ul class="points">${items.map(([ic, h, p], i) => `<li><span class="ico">${icon[ic]}</span><div><h3>${h}</h3><p>${p}</p></div></li>`).join('')}</ul>`;

export function home(lang) {
  const c = copy[lang];
  const a = c.alts;
  const base = lang === 'es' ? '/es/' : '/';
  const privacyHref = lang === 'es' ? '/es/privacy' : '/privacy';
  const jsonld = `<script type="application/ld+json">${JSON.stringify({
    '@context': 'https://schema.org',
    '@type': 'MobileApplication',
    name: 'Lunet',
    operatingSystem: 'iOS 17.0 or later',
    applicationCategory: 'UtilitiesApplication',
    description: c.description,
    url: SITE + base,
    image: SITE + '/img/icon-default-512.webp',
    installUrl: APP_STORE,
    inLanguage: lang,
    offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
  })}</script>
<script type="application/ld+json">${JSON.stringify({
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: c.faq.map(([q, ans]) => ({ '@type': 'Question', name: q, acceptedAnswer: { '@type': 'Answer', text: ans.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim() } })),
  })}</script>
`;
  const body = `
<section class="hero" aria-labelledby="hero-title">
  <div class="wrap">
    <picture>
      <source srcset="/img/icon-dark-256.webp 1x, /img/icon-dark-512.webp 2x" media="(prefers-color-scheme: dark)">
      <img class="icon" src="/img/icon-default-256.webp" srcset="/img/icon-default-256.webp 1x, /img/icon-default-512.webp 2x" width="128" height="128" alt="Lunet app icon" fetchpriority="high">
    </picture>
    <p class="eyebrow">${c.eyebrow}</p>
    <h1 id="hero-title">${c.h1a}<span>${c.h1b}</span></h1>
    <p class="lede">${c.lede}</p>
    <div class="cta">${badge(lang)}<p class="fine">${c.fine}</p></div>
  </div>
  <div class="hero-phones">
    ${phone(lang, 'result-danger', a.danger, 'side left', false, '260px')}
    ${phone(lang, 'home', a.home, 'center', true, '(max-width: 560px) 72vw, 300px')}
    ${phone(lang, 'result-wifi', a.wifi, 'side right', false, '260px')}
  </div>
</section>

<section id="safety" class="safety" aria-labelledby="safety-title">
  <div class="wrap">
    <div class="section-head center reveal">
      <p class="kicker k-danger">${icon.shieldX}${c.safety.kicker}</p>
      <h2 id="safety-title">${c.safety.h2}</h2>
      <p>${c.safety.p}</p>
    </div>
    <div class="lookalike reveal" role="group" aria-label="${lang === 'es' ? 'Ejemplo de dominio imitador' : 'Lookalike domain example'}">
      <div class="url-row"><span class="tag ok">${c.safety.real}</span><span class="url">northbank.com</span></div>
      <div class="url-row"><span class="tag bad">${c.safety.fake}</span><span class="url">n<mark>0</mark>rthbank<mark>-login.co</mark></span></div>
      <p class="note">${c.safety.note}</p>
    </div>
    <div class="split">
      <div class="reveal">${phone(lang, 'result-danger', a.danger)}</div>
      <div>
        ${pointList(c.safety.points)}
        <div class="verdicts" aria-label="Verdicts"><span class="chip v-safe">${c.safety.verdicts[0]}</span><span class="chip v-caution">${c.safety.verdicts[1]}</span><span class="chip v-danger">${c.safety.verdicts[2]}</span></div>
      </div>
    </div>
  </div>
</section>

<section id="answers" class="alt" aria-labelledby="answers-title">
  <div class="wrap">
    <div class="section-head center reveal">
      <p class="kicker">${icon.sparkle}${c.answers.kicker}</p>
      <h2 id="answers-title">${c.answers.h2}</h2>
      <p>${c.answers.p}</p>
    </div>
    <div class="duo reveal gap-top">
      ${phone(lang, 'result-wifi', a.wifi, '', false, '(max-width: 600px) 42vw, 270px')}
      ${phone(lang, 'result-travel', a.travel, '', false, '(max-width: 600px) 42vw, 270px')}
    </div>
    <ul class="kinds" role="list">
      ${c.answers.kinds.map(([ic, k, h, p]) => `<li class="kind ${k} reveal"><span class="ico">${icon[ic]}</span><h3>${h}</h3><p>${p}</p></li>`).join('\n      ')}
    </ul>
    <p class="formats">${c.answers.formats}</p>
  </div>
</section>

<section id="your-codes" aria-labelledby="codes-title">
  <div class="wrap">
    <div class="section-head reveal">
      <p class="kicker k-travel">${icon.wallet}${c.codes.kicker}</p>
      <h2 id="codes-title">${c.codes.h2}</h2>
      <p>${c.codes.p}</p>
    </div>
    <div class="split rev">
      <div class="duo reveal">${phone(lang, 'show-wifi', a.show, '', false, '(max-width: 600px) 42vw, 270px')}${phone(lang, 'history', a.history, '', false, '(max-width: 600px) 42vw, 270px')}</div>
      <div>${pointList(c.codes.points)}</div>
    </div>
  </div>
</section>

<section id="studio" class="alt studio" aria-labelledby="studio-title">
  <div class="wrap">
    <div class="split">
      <div class="reveal">${phone(lang, 'studio', a.studio)}</div>
      <div>
        <div class="section-head">
          <p class="kicker k-contact">${icon.palette}${c.studio.kicker}</p>
          <h2 id="studio-title">${c.studio.h2}</h2>
          <p>${c.studio.p}</p>
        </div>
        <div class="swatches" aria-hidden="true"><span class="s1"></span><span class="s2"></span><span class="s3"></span><span class="s4"></span><span class="s5"></span><span class="s6"></span></div>
        <div class="gap-top-sm">${pointList(c.studio.points)}</div>
      </div>
    </div>
  </div>
</section>

<section id="everywhere" aria-labelledby="everywhere-title">
  <div class="wrap">
    <div class="section-head center reveal">
      <p class="kicker">${icon.globe}${c.everywhere.kicker}</p>
      <h2 id="everywhere-title">${c.everywhere.h2}</h2>
      <p>${c.everywhere.p}</p>
    </div>
    <ul class="tiles" role="list">
      ${c.everywhere.tiles.map(([ic, h, p]) => `<li class="tile reveal"><span class="glyph">${icon[ic]}</span><h3>${h}</h3><p>${p}</p></li>`).join('\n      ')}
    </ul>
  </div>
</section>

<section id="privacy" class="alt privacy-band" aria-labelledby="privacy-title">
  <div class="wrap">
    <div class="shield" aria-hidden="true">${icon.shield}</div>
    <div class="section-head center">
      <h2 id="privacy-title">${c.privacy.h2}</h2>
      <p>${c.privacy.p}</p>
    </div>
    <ul class="nos">${c.privacy.nos.map((n) => `<li>${n}</li>`).join('')}</ul>
    <div class="net">${c.privacy.net.map(([h, p]) => `<div class="reveal"><h3>${h}</h3><p>${p}</p></div>`).join('')}</div>
    <p class="more"><a href="${privacyHref}">${c.privacy.more} <span aria-hidden="true">›</span></a></p>
  </div>
</section>

<section id="faq" aria-labelledby="faq-title">
  <div class="wrap">
    <div class="section-head center"><h2 id="faq-title">${c.faqTitle}</h2></div>
    <div class="faq">
      ${c.faq.map(([q, ans]) => `<details><summary>${q}</summary><div>${ans}</div></details>`).join('\n      ')}
    </div>
  </div>
</section>

<section class="final alt" aria-labelledby="final-title">
  <div class="wrap">
    <picture>
      <source srcset="/img/icon-dark-256.webp" media="(prefers-color-scheme: dark)">
      <img src="/img/icon-default-256.webp" width="104" height="104" alt="" loading="lazy">
    </picture>
    <h2 id="final-title">${c.finalH}</h2>
    <p>${c.finalP}</p>
    <div class="cta">${badge(lang)}</div>
  </div>
</section>
`;
  return layout({ lang, page: 'home', title: c.title, description: c.description, body, jsonld });
}
