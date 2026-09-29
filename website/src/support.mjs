import { layout, mail, mailScript, badge, VERSION } from './shared.mjs';

const copy = {
  en: {
    title: 'Lunet Support',
    description: 'Get help with Lunet: camera access, joining Wi-Fi, Apple Wallet passes, Face ID lock, exporting history, languages and moving over from Fast QR & Barcode.',
    h1: 'Support',
    lede: 'Answers to common questions, and a real person when you need one.',
    contactH: 'Contact',
    contactP: 'Questions, bugs, ideas or a code that Lunet read wrong? Write anytime — include your iPhone model and iOS version, and a screenshot if it helps. You’ll usually hear back within two business days.',
    write: 'Write to support',
    noscript: 'Email: rovapin (at) gmail (dot) com',
    faqH: 'Troubleshooting',
    faq: [
      ['The camera shows a black screen or won’t start', `
        <p>Lunet needs permission to use the camera. Open <kbd>Settings</kbd> › <kbd>Apps</kbd> › <kbd>Lunet</kbd> and turn on <strong>Camera</strong>. On iOS 17, it’s <kbd>Settings</kbd> › <kbd>Lunet</kbd>.</p>
        <p>If it’s already on, check <kbd>Settings</kbd> › <kbd>Screen Time</kbd> › <kbd>Content &amp; Privacy Restrictions</kbd> isn’t blocking the camera, and close any app that might be using it (like a video call). You can always scan from a photo or screenshot instead.</p>`],
      ['Join Network doesn’t connect to the Wi-Fi', `
        <p>When you tap <strong>Join Network</strong>, iOS asks for confirmation — tap <strong>Join</strong>. If it still fails:</p>
        <ul>
          <li>Make sure you’re in range of the network, and that the name matches exactly (it’s case-sensitive).</li>
          <li>If you’ve joined this network before with a different password, open <kbd>Settings</kbd> › <kbd>Wi-Fi</kbd>, tap <strong>ⓘ</strong> next to it, choose <strong>Forget This Network</strong>, and try again.</li>
          <li>Enterprise networks (WPA-Enterprise, captive portals) can’t be joined from a code. Use <strong>Copy Password</strong> and join from Settings.</li>
          <li>If the code was made by a router or another app, the password inside may be out of date — ask the owner to confirm it.</li>
        </ul>`],
      ['Add to Apple Wallet isn’t working', `
        <p>Lunet builds a Wallet pass from the boarding pass barcode and has it signed by its pass service, so you need an internet connection. If adding fails, wait a minute and try again — the service limits how many passes can be made per hour to prevent abuse.</p>
        <p>The pass is made by Lunet from the code you scanned; it isn’t issued by your airline and won’t update with gate changes. Keep your airline’s official pass handy, and use <strong>Add to Calendar</strong> or <strong>Your codes</strong> as alternatives.</p>`],
      ['Setting up the Face ID lock', `
        <p>In Lunet, open <kbd>Settings</kbd> › <kbd>History</kbd> and turn on <strong>Require Face ID</strong> (or <strong>Require Passcode</strong>). Your iPhone needs a passcode first; Face ID is optional and the passcode always works as a fallback.</p>
        <p>If Face ID never appears, check <kbd>Settings</kbd> › <kbd>Apps</kbd> › <kbd>Lunet</kbd> › <strong>Face ID</strong> is allowed, or <kbd>Settings</kbd> › <kbd>Face ID &amp; Passcode</kbd> › <kbd>Other Apps</kbd>.</p>`],
      ['Exporting my history', `
        <p>In Lunet, open <kbd>Settings</kbd> › <kbd>History</kbd> › <strong>Export CSV</strong>. You can also tap <strong>Select</strong> in History and export just the scans you pick. The file includes the date, kind, format, content, title and place (if you saved places), and opens in Numbers, Excel or Google Sheets.</p>`],
      ['Changing Lunet’s language', `
        <p>Lunet follows your iPhone’s language. To use a different one just for Lunet, open <kbd>Settings</kbd> › <kbd>Apps</kbd> › <kbd>Lunet</kbd> › <strong>Language</strong>. On iOS 17, it’s <kbd>Settings</kbd> › <kbd>Lunet</kbd> › <strong>Preferred Language</strong>. Lunet is available in 39 languages.</p>`],
      ['Where is my history from Fast QR & Barcode?', `
        <p>Lunet is the new version of Fast QR &amp; Barcode. When you update from the App Store, Lunet brings your scan and creation history — and your settings — over automatically the first time it opens. Everything happens on your iPhone.</p>
        <p>History was only ever stored on your device, so if the old app was deleted before updating, its history can’t be recovered — unless you restore an iPhone backup made while it was installed, then update to Lunet.</p>`],
      ['Lunet flagged a link I trust', `
        <p>Lunet makes <strong>Don’t Open</strong> the default when a link looks dangerous, but you can still tap <strong>Open Anyway…</strong>. Check the address it shows under <em>Where it really goes</em>. If you’re sure it’s a mistake, please write to us with the link so we can improve the check.</p>
        <p>You can also change this behavior in Lunet’s <kbd>Settings</kbd> › <kbd>Safety</kbd>.</p>`],
      ['A code won’t scan', `
        <p>Fill most of the frame with the code, avoid glare, and hold steady for a moment. Tiny or damaged codes often scan better from a photo taken a little further away, then zoomed. Very low-contrast or heavily styled codes may not be readable by any scanner.</p>`],
    ],
    versionH: 'Version',
    version: [
      ['Current version', `Lunet ${VERSION}`],
      ['Requires', 'iOS 17 or later (designed for iOS 26)'],
      ['Devices', 'iPhone and iPad'],
      ['Languages', '39'],
      ['Price', 'Free — no ads, no account'],
    ],
    versionNote: 'Release notes for each update are on the App Store.',
  },
  es: {
    title: 'Soporte de Lunet',
    description: 'Ayuda con Lunet: acceso a la cámara, conectarse al Wi-Fi, pases de Apple Wallet, bloqueo con Face ID, exportar el historial, idiomas y la migración desde Fast QR & Barcode.',
    h1: 'Soporte',
    lede: 'Respuestas a las dudas más comunes, y una persona real cuando la necesites.',
    contactH: 'Contacto',
    contactP: '¿Preguntas, errores, ideas o un código que Lunet leyó mal? Escríbenos cuando quieras; incluye el modelo de tu iPhone, la versión de iOS y una captura si ayuda. Normalmente respondemos en un máximo de dos días hábiles.',
    write: 'Escribir a soporte',
    noscript: 'Correo: rovapin (arroba) gmail (punto) com',
    faqH: 'Solución de problemas',
    faq: [
      ['La cámara se ve negra o no arranca', `
        <p>Lunet necesita permiso para usar la cámara. Abre <kbd>Configuración</kbd> › <kbd>Apps</kbd> › <kbd>Lunet</kbd> y activa <strong>Cámara</strong>. En iOS 17 es <kbd>Configuración</kbd> › <kbd>Lunet</kbd>.</p>
        <p>Si ya está activada, revisa que <kbd>Configuración</kbd> › <kbd>Tiempo en pantalla</kbd> › <kbd>Restricciones de contenido y privacidad</kbd> no bloquee la cámara, y cierra cualquier app que la esté usando (como una videollamada). También puedes escanear desde una foto o captura.</p>`],
      ['Conectarse a la red no se conecta al Wi-Fi', `
        <p>Al tocar <strong>Conectarse a la red</strong>, iOS pide confirmación: toca <strong>Conectar</strong>. Si aun así falla:</p>
        <ul>
          <li>Asegúrate de estar al alcance de la red y de que el nombre coincida exactamente (distingue mayúsculas).</li>
          <li>Si antes te conectaste a esa red con otra contraseña, abre <kbd>Configuración</kbd> › <kbd>Wi-Fi</kbd>, toca <strong>ⓘ</strong> junto a ella, elige <strong>Omitir esta red</strong> e inténtalo de nuevo.</li>
          <li>Las redes empresariales (WPA-Enterprise, portales cautivos) no se pueden unir desde un código. Usa <strong>Copiar contraseña</strong> y conéctate desde Configuración.</li>
          <li>Si el código lo generó un router u otra app, la contraseña puede estar desactualizada: pide al dueño que la confirme.</li>
        </ul>`],
      ['Agregar a Apple Wallet no funciona', `
        <p>Lunet arma un pase de Wallet a partir del código del pase de abordar y lo firma con su servicio de pases, así que necesitas conexión a internet. Si falla, espera un minuto e inténtalo de nuevo: el servicio limita cuántos pases se pueden crear por hora para evitar abusos.</p>
        <p>El pase lo crea Lunet a partir del código que escaneaste; no lo emite tu aerolínea y no se actualiza con cambios de puerta. Ten a la mano el pase oficial de tu aerolínea y usa <strong>Agregar a Calendario</strong> o <strong>Tus códigos</strong> como alternativa.</p>`],
      ['Configurar el bloqueo con Face ID', `
        <p>En Lunet, abre <kbd>Configuración</kbd> › <kbd>Historial</kbd> y activa <strong>Requerir Face ID</strong> (o <strong>Requerir código</strong>). Tu iPhone necesita primero un código; Face ID es opcional y el código siempre funciona como respaldo.</p>
        <p>Si Face ID nunca aparece, revisa que esté permitido en <kbd>Configuración</kbd> › <kbd>Apps</kbd> › <kbd>Lunet</kbd> › <strong>Face ID</strong>, o en <kbd>Configuración</kbd> › <kbd>Face ID y código</kbd> › <kbd>Otras apps</kbd>.</p>`],
      ['Exportar mi historial', `
        <p>En Lunet, abre <kbd>Configuración</kbd> › <kbd>Historial</kbd> › <strong>Exportar CSV</strong>. También puedes tocar <strong>Seleccionar</strong> en el Historial y exportar solo los escaneos que elijas. El archivo incluye fecha, tipo, formato, contenido, título y lugar (si guardas lugares), y se abre en Numbers, Excel o Google Sheets.</p>`],
      ['Cambiar el idioma de Lunet', `
        <p>Lunet usa el idioma de tu iPhone. Para usar otro solo en Lunet, abre <kbd>Configuración</kbd> › <kbd>Apps</kbd> › <kbd>Lunet</kbd> › <strong>Idioma</strong>. En iOS 17 es <kbd>Configuración</kbd> › <kbd>Lunet</kbd> › <strong>Idioma preferido</strong>. Lunet está disponible en 39 idiomas.</p>`],
      ['¿Dónde está mi historial de Fast QR & Barcode?', `
        <p>Lunet es la nueva versión de Fast QR &amp; Barcode. Al actualizar desde el App Store, Lunet trae tu historial de escaneos y de códigos creados —y tus ajustes— automáticamente la primera vez que se abre. Todo ocurre en tu iPhone.</p>
        <p>El historial siempre se guardó solo en tu dispositivo, así que si la app anterior se borró antes de actualizar, no se puede recuperar, a menos que restaures un respaldo del iPhone hecho cuando estaba instalada y después actualices a Lunet.</p>`],
      ['Lunet marcó un enlace en el que confío', `
        <p>Cuando un enlace parece peligroso, Lunet deja <strong>No abrir</strong> como opción predeterminada, pero aún puedes tocar <strong>Abrir de todos modos…</strong>. Revisa la dirección que aparece en <em>Adónde lleva en realidad</em>. Si estás seguro de que es un error, escríbenos con el enlace para mejorar la revisión.</p>
        <p>También puedes cambiar este comportamiento en <kbd>Configuración</kbd> › <kbd>Seguridad</kbd> dentro de Lunet.</p>`],
      ['Un código no se escanea', `
        <p>Llena casi todo el recuadro con el código, evita reflejos y mantén el iPhone quieto un momento. Los códigos muy pequeños o dañados a veces se leen mejor desde una foto tomada un poco más lejos y luego ampliada. Los códigos con muy poco contraste o demasiado estilizados pueden no ser legibles para ningún escáner.</p>`],
    ],
    versionH: 'Versión',
    version: [
      ['Versión actual', `Lunet ${VERSION}`],
      ['Requiere', 'iOS 17 o posterior (diseñado para iOS 26)'],
      ['Dispositivos', 'iPhone y iPad'],
      ['Idiomas', '39'],
      ['Precio', 'Gratis, sin anuncios ni cuenta'],
    ],
    versionNote: 'Las notas de cada actualización están en el App Store.',
  },
};

export function support(lang) {
  const c = copy[lang];
  const body = `
<article class="doc">
  <div class="wrap">
    <header>
      <h1>${c.h1}</h1>
      <p>${c.lede}</p>
    </header>

    <section id="contact" class="contact-card" aria-labelledby="contact-title">
      <h2 id="contact-title" class="card-title">${c.contactH}</h2>
      <p>${c.contactP}</p>
      <p class="mail-line">${mail(lang)}</p>
      <noscript><p>${c.noscript}</p></noscript>
      <a class="btn js-mailbtn" data-u="rovapin" data-d="gmail.com" href="#contact" hidden>${c.write}</a>
    </section>

    <h2 id="troubleshooting">${c.faqH}</h2>
    <div class="faq doc-faq">
      ${c.faq.map(([q, a]) => `<details><summary>${q}</summary><div>${a}</div></details>`).join('\n      ')}
    </div>

    <h2 id="version">${c.versionH}</h2>
    <div class="table-scroll"><table>
      <tbody>${c.version.map(([k, v]) => `<tr><th scope="row">${k}</th><td>${v}</td></tr>`).join('')}</tbody>
    </table></div>
    <p>${c.versionNote}</p>
    <div class="gap-top-sm">${badge(lang, 'sm')}</div>
  </div>
</article>
`;
  return layout({ lang, page: 'support', title: c.title, description: c.description, body, scripts: mailScript });
}
