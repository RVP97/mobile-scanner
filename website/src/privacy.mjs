import { layout, mail, mailScript, icon } from './shared.mjs';

const tick = icon.check;

const en = {
  title: 'Lunet Privacy Policy',
  description: 'Lunet collects no personal data. No account, no ads, no tracking. Here is exactly what stays on your device and the three times the app goes online.',
  body: `
<article class="doc">
  <div class="wrap">
    <header>
      <h1>Privacy Policy</h1>
      <p>Lunet is built so that we never need your data. Here’s the short version, then every detail.</p>
      <p class="meta">Effective September 28, 2026</p>
    </header>

    <section class="summary-card" aria-labelledby="short">
      <h2 id="short">In plain language</h2>
      <ul>
        <li>${tick}<span><strong>We don’t collect personal data.</strong> There’s no account, no ads, no analytics and no tracking.</span></li>
        <li>${tick}<span><strong>Your scans stay on your device.</strong> History, your codes and your designs are stored only on your iPhone or iPad.</span></li>
        <li>${tick}<span><strong>Lunet goes online only for three things</strong> — checking a link, looking up a product, and adding a pass to Apple Wallet — and sends only what that feature needs.</span></li>
        <li>${tick}<span><strong>We don’t sell or share anything</strong>, because we don’t have it.</span></li>
      </ul>
    </section>

    <h2 id="who">1. Who we are</h2>
    <p>Lunet (“the app”) is developed and published by Rodrigo Valle Pinto, an independent developer (“we”, “us”). This policy covers the Lunet app for iPhone and iPad and this website, lunet.vallepinto.com. Questions: ${mail('en', 'mail-inline')}<noscript> (rovapin (at) gmail (dot) com)</noscript>.</p>

    <h2 id="device">2. What stays on your device</h2>
    <p>Everything you do in Lunet is stored in the app’s private storage on your device and is never sent to us:</p>
    <ul>
      <li><strong>History</strong> — the content of codes you scan or create, their type and format, the date, and whether you pinned them.</li>
      <li><strong>Places</strong> — only if you turn on <em>Remember where I scanned</em>: the place name and location of each scan.</li>
      <li><strong>Your codes and designs</strong> — codes you keep on Home and styles you create in the Studio.</li>
      <li><strong>Settings</strong> — your preferences.</li>
    </ul>
    <p>This data is included in your device backups (iCloud Backup or a computer backup) under Apple’s terms, like any app’s data. You can delete individual scans, clear History, or remove all of it by deleting the app. When you export History as CSV, the file goes wherever you choose to send it.</p>

    <h2 id="network">3. When Lunet goes online</h2>
    <p>Scanning, creating codes, the Studio and History work fully offline. Lunet connects to the internet only in these cases:</p>

    <h3>a) Link check (“Deep check”)</h3>
    <p>When you scan a link and <em>Deep check</em> is on (you can turn it off in Lunet › Settings › Safety), Lunet:</p>
    <ul>
      <li>contacts the <strong>link’s own server</strong> — and each server it redirects to — to find the final destination, without cookies and without saving anything; and</li>
      <li>asks the public <strong>RDAP domain registry</strong> (through the rdap.org directory) for the domain’s registration date. Only the domain name is sent, for example <em>example.com</em>.</li>
    </ul>
    <p>Nothing is sent to us. As with visiting any website, those servers receive your IP address and the request, and they are operated by third parties under their own policies. The lookalike, homograph and @-trick checks run entirely on your device.</p>

    <h3>b) Product lookup</h3>
    <p>When you scan a product barcode, Lunet sends <strong>only the barcode number</strong> to the open databases <strong>Open Food Facts</strong> and <strong>Open Products Facts</strong> (world.openfoodfacts.org, world.openproductsfacts.org), run by the non-profit Open Food Facts, to show the product’s name, brand and picture. Their servers receive your IP address as part of the connection; see openfoodfacts.org for their policy.</p>

    <h3>c) Add to Apple Wallet</h3>
    <p>Only when you tap <strong>Add to Apple Wallet</strong>, Lunet sends the pass details shown on screen (such as passenger name, flight, date, seat and booking reference) over an encrypted connection to <strong>Lunet’s pass-signing service</strong>, which runs on Cloudflare. The service signs the pass and sends it straight back. <strong>Pass contents are processed in memory only and are never stored or logged.</strong></p>
    <p>To prevent abuse, the service uses Apple’s <em>App Attest</em> to confirm requests come from a genuine copy of Lunet. For this it keeps:</p>
    <ul>
      <li>an anonymous cryptographic key created by your device for Lunet, with a request counter and timestamps — it doesn’t identify you and isn’t linked to your Apple Account; and</li>
      <li>hourly rate-limit counters keyed by a <strong>truncated one-way hash of your IP address</strong>, deleted automatically within two hours.</li>
    </ul>
    <p>Like any hosting provider, Cloudflare processes standard technical data (such as IP addresses) transiently to deliver and protect the service, under its own privacy policy. We don’t use it to identify anyone.</p>

    <h3>d) Apple services and other apps</h3>
    <p>If you turn on <em>Remember where I scanned</em>, iOS may send the location to Apple to find a place name (reverse geocoding), under Apple’s privacy policy. When you choose to open a link, join a Wi-Fi network, open Maps or save a contact or event, that action is handed to iOS or the app you chose.</p>

    <h2 id="permissions">4. Permissions</h2>
    <div class="table-scroll"><table>
      <thead><tr><th scope="col">Permission</th><th scope="col">Why</th></tr></thead>
      <tbody>
        <tr><th scope="row">Camera</th><td>To read codes. The camera feed is processed on your device in real time and is never recorded or uploaded.</td></tr>
        <tr><th scope="row">Photos</th><td>Add-only access, to save codes you create. To scan an image, you pick it in the system photo picker — Lunet sees only the image you choose.</td></tr>
        <tr><th scope="row">Location</th><td>Optional, only for <em>Remember where I scanned</em>. Stored on your device with your History.</td></tr>
        <tr><th scope="row">Face ID</th><td>Optional, to lock History. iOS performs the check; Lunet only learns whether it succeeded and never receives biometric data.</td></tr>
        <tr><th scope="row">Contacts, Calendar</th><td>Lunet doesn’t read your contacts or calendars. When you save a contact or event, iOS shows its own screen for you to confirm.</td></tr>
      </tbody>
    </table></div>
    <p>You can change any permission at any time in Settings › Apps › Lunet.</p>

    <h2 id="dont">5. What we don’t do</h2>
    <ul>
      <li>No accounts, sign-in or profiles.</li>
      <li>No advertising, and no advertising identifier.</li>
      <li>No analytics or third-party SDKs that collect data.</li>
      <li>No tracking across apps or websites, and no data brokers.</li>
      <li>No sale or sharing of personal information.</li>
    </ul>
    <p>If you choose to share crash reports and analytics with app developers in iOS Settings, Apple may provide us with anonymous crash reports, under Apple’s privacy policy. We use them only to fix bugs.</p>

    <h2 id="children">6. Children</h2>
    <p>Lunet is a general-audience utility and isn’t directed at children under 13 (or the minimum age in your country). Because Lunet doesn’t collect personal information from anyone, it doesn’t knowingly collect it from children. If you believe a child has sent us personal information by email, contact us and we will delete it.</p>

    <h2 id="rights">7. Your rights</h2>
    <p>Depending on where you live — including under the GDPR (EU/UK), the CCPA/CPRA (California) and Mexico’s LFPDPPP — you may have rights to access, correct, delete or object to the processing of your personal data. Because we don’t hold personal data about you, your History and other data are already under your control on your device. For the transient processing described in section 3(c), the legal bases are performing the service you asked for and our legitimate interest in preventing abuse. If you email us, we use your message only to reply and delete it when it’s no longer needed. You can contact us about any request, and you may also complain to your local data protection authority.</p>

    <h2 id="security">8. Security and transfers</h2>
    <p>All network connections use HTTPS. The pass-signing service accepts only attested requests from Lunet and keeps nothing beyond what’s described above. Cloudflare operates a global network, so the transient processing in section 3(c) may happen in a data center outside your country.</p>

    <h2 id="website">9. This website</h2>
    <p>lunet.vallepinto.com uses no cookies, no analytics and no third-party scripts or fonts. It’s served by Cloudflare, which processes IP addresses transiently to deliver and protect it.</p>

    <h2 id="changes">10. Changes</h2>
    <p>If this policy changes, we’ll update this page and the effective date above. If a change affects how data is handled, we’ll also mention it in the app’s release notes before it takes effect.</p>

    <h2 id="contact">11. Contact</h2>
    <p>Questions about privacy? Write to ${mail('en', 'mail-inline')}<noscript> (rovapin (at) gmail (dot) com)</noscript>.</p>
  </div>
</article>
`,
};

const es = {
  title: 'Aviso de privacidad de Lunet',
  description: 'Lunet no recopila datos personales. Sin cuenta, sin anuncios, sin rastreo. Esto es exactamente lo que se queda en tu dispositivo y las tres ocasiones en que la app se conecta.',
  body: `
<article class="doc">
  <div class="wrap">
    <header>
      <h1>Aviso de privacidad</h1>
      <p>Lunet está hecho para que nunca necesitemos tus datos. Aquí va la versión corta y luego cada detalle.</p>
      <p class="meta">Vigente desde el 28 de septiembre de 2026</p>
    </header>

    <section class="summary-card" aria-labelledby="short">
      <h2 id="short">En pocas palabras</h2>
      <ul>
        <li>${tick}<span><strong>No recopilamos datos personales.</strong> No hay cuenta, anuncios, analíticas ni rastreo.</span></li>
        <li>${tick}<span><strong>Tus escaneos se quedan en tu dispositivo.</strong> El Historial, tus códigos y tus diseños se guardan solo en tu iPhone o iPad.</span></li>
        <li>${tick}<span><strong>Lunet se conecta solo para tres cosas</strong> —revisar un enlace, buscar un producto y agregar un pase a Apple Wallet— y envía únicamente lo que esa función necesita.</span></li>
        <li>${tick}<span><strong>No vendemos ni compartimos nada</strong>, porque no lo tenemos.</span></li>
      </ul>
    </section>

    <h2 id="who">1. Quiénes somos</h2>
    <p>Lunet (“la app”) es desarrollada y publicada por Rodrigo Valle Pinto, desarrollador independiente (“nosotros”). Este aviso cubre la app Lunet para iPhone y iPad y este sitio, lunet.vallepinto.com. Dudas: ${mail('es', 'mail-inline')}<noscript> (rovapin (arroba) gmail (punto) com)</noscript>.</p>

    <h2 id="device">2. Lo que se queda en tu dispositivo</h2>
    <p>Todo lo que haces en Lunet se guarda en el almacenamiento privado de la app en tu dispositivo y nunca se nos envía:</p>
    <ul>
      <li><strong>Historial</strong>: el contenido de los códigos que escaneas o creas, su tipo y formato, la fecha y si los fijaste.</li>
      <li><strong>Lugares</strong>: solo si activas <em>Recordar dónde escaneé</em>, el nombre del lugar y la ubicación de cada escaneo.</li>
      <li><strong>Tus códigos y diseños</strong>: los códigos que guardas en Inicio y los estilos que creas en el Estudio.</li>
      <li><strong>Ajustes</strong>: tus preferencias.</li>
    </ul>
    <p>Estos datos se incluyen en los respaldos de tu dispositivo (Respaldo en iCloud o en una computadora) según los términos de Apple, como los de cualquier app. Puedes borrar escaneos individuales, vaciar el Historial o eliminarlo todo borrando la app. Si exportas el Historial en CSV, el archivo va a donde tú decidas enviarlo.</p>

    <h2 id="network">3. Cuándo se conecta Lunet</h2>
    <p>Escanear, crear códigos, el Estudio y el Historial funcionan por completo sin conexión. Lunet se conecta a internet solo en estos casos:</p>

    <h3>a) Revisión de enlaces (“Revisión a fondo”)</h3>
    <p>Cuando escaneas un enlace y la <em>Revisión a fondo</em> está activada (puedes desactivarla en Lunet › Configuración › Seguridad), Lunet:</p>
    <ul>
      <li>contacta al <strong>propio servidor del enlace</strong> —y a cada servidor al que redirige— para encontrar el destino final, sin cookies y sin guardar nada; y</li>
      <li>consulta al <strong>registro público de dominios RDAP</strong> (a través del directorio rdap.org) la fecha de registro del dominio. Solo se envía el nombre del dominio, por ejemplo <em>ejemplo.com</em>.</li>
    </ul>
    <p>No se nos envía nada. Como al visitar cualquier sitio web, esos servidores reciben tu dirección IP y la solicitud, y los operan terceros bajo sus propias políticas. Las revisiones de imitaciones, homógrafos y trucos con @ se hacen por completo en tu dispositivo.</p>

    <h3>b) Búsqueda de productos</h3>
    <p>Cuando escaneas un código de barras de producto, Lunet envía <strong>solo el número del código</strong> a las bases de datos abiertas <strong>Open Food Facts</strong> y <strong>Open Products Facts</strong> (world.openfoodfacts.org, world.openproductsfacts.org), operadas por la organización sin fines de lucro Open Food Facts, para mostrar el nombre, la marca y la foto del producto. Sus servidores reciben tu dirección IP como parte de la conexión; consulta su política en openfoodfacts.org.</p>

    <h3>c) Agregar a Apple Wallet</h3>
    <p>Solo cuando tocas <strong>Agregar a Apple Wallet</strong>, Lunet envía los datos del pase que ves en pantalla (como nombre del pasajero, vuelo, fecha, asiento y clave de reservación) por una conexión cifrada al <strong>servicio de firma de pases de Lunet</strong>, que funciona en Cloudflare. El servicio firma el pase y lo devuelve de inmediato. <strong>El contenido del pase se procesa solo en memoria y nunca se guarda ni se registra.</strong></p>
    <p>Para evitar abusos, el servicio usa <em>App Attest</em> de Apple para confirmar que las solicitudes vienen de una copia auténtica de Lunet. Para ello conserva:</p>
    <ul>
      <li>una clave criptográfica anónima creada por tu dispositivo para Lunet, con un contador de solicitudes y fechas; no te identifica ni está vinculada a tu cuenta de Apple; y</li>
      <li>contadores de límite por hora identificados con un <strong>hash unidireccional y truncado de tu dirección IP</strong>, que se borran automáticamente en un máximo de dos horas.</li>
    </ul>
    <p>Como cualquier proveedor de alojamiento, Cloudflare procesa de forma transitoria datos técnicos estándar (como direcciones IP) para entregar y proteger el servicio, conforme a su propia política de privacidad. No los usamos para identificar a nadie.</p>

    <h3>d) Servicios de Apple y otras apps</h3>
    <p>Si activas <em>Recordar dónde escaneé</em>, iOS puede enviar la ubicación a Apple para obtener el nombre del lugar (geocodificación inversa), conforme a la política de privacidad de Apple. Cuando decides abrir un enlace, conectarte a un Wi-Fi, abrir Mapas o guardar un contacto o evento, esa acción pasa a iOS o a la app que elegiste.</p>

    <h2 id="permissions">4. Permisos</h2>
    <div class="table-scroll"><table>
      <thead><tr><th scope="col">Permiso</th><th scope="col">Para qué</th></tr></thead>
      <tbody>
        <tr><th scope="row">Cámara</th><td>Para leer códigos. La imagen de la cámara se procesa en tu dispositivo en tiempo real y nunca se graba ni se sube.</td></tr>
        <tr><th scope="row">Fotos</th><td>Acceso solo para agregar, para guardar los códigos que creas. Para escanear una imagen, la eliges en el selector de fotos del sistema: Lunet solo ve la imagen que eliges.</td></tr>
        <tr><th scope="row">Ubicación</th><td>Opcional, solo para <em>Recordar dónde escaneé</em>. Se guarda en tu dispositivo junto con tu Historial.</td></tr>
        <tr><th scope="row">Face ID</th><td>Opcional, para bloquear el Historial. iOS hace la verificación; Lunet solo sabe si tuvo éxito y nunca recibe datos biométricos.</td></tr>
        <tr><th scope="row">Contactos, Calendario</th><td>Lunet no lee tus contactos ni tus calendarios. Cuando guardas un contacto o evento, iOS muestra su propia pantalla para que confirmes.</td></tr>
      </tbody>
    </table></div>
    <p>Puedes cambiar cualquier permiso cuando quieras en Configuración › Apps › Lunet.</p>

    <h2 id="dont">5. Lo que no hacemos</h2>
    <ul>
      <li>Sin cuentas, inicio de sesión ni perfiles.</li>
      <li>Sin publicidad ni identificador de publicidad.</li>
      <li>Sin analíticas ni SDK de terceros que recopilen datos.</li>
      <li>Sin rastreo entre apps o sitios web, y sin intermediarios de datos.</li>
      <li>Sin venta ni intercambio de información personal.</li>
    </ul>
    <p>Si en la Configuración de iOS eliges compartir informes de fallos y análisis con los desarrolladores, Apple puede proporcionarnos informes de fallos anónimos, conforme a su política de privacidad. Los usamos solo para corregir errores.</p>

    <h2 id="children">6. Menores</h2>
    <p>Lunet es una herramienta para público general y no está dirigida a menores de 13 años (o de la edad mínima en tu país). Como Lunet no recopila información personal de nadie, tampoco la recopila de menores a sabiendas. Si crees que un menor nos envió información personal por correo, contáctanos y la borraremos.</p>

    <h2 id="rights">7. Tus derechos</h2>
    <p>Según dónde vivas —incluidos el RGPD (UE/Reino Unido), la CCPA/CPRA (California) y la LFPDPPP de México (derechos ARCO)— puedes tener derecho a acceder, rectificar, cancelar u oponerte al tratamiento de tus datos personales. Como no guardamos datos personales tuyos, tu Historial y demás datos ya están bajo tu control en tu dispositivo. Para el tratamiento transitorio descrito en la sección 3(c), las bases legales son prestar el servicio que pediste y nuestro interés legítimo en prevenir abusos. Si nos escribes, usamos tu mensaje solo para responder y lo borramos cuando ya no se necesita. Puedes contactarnos para cualquier solicitud y también presentar una queja ante la autoridad de protección de datos de tu país.</p>

    <h2 id="security">8. Seguridad y transferencias</h2>
    <p>Todas las conexiones usan HTTPS. El servicio de firma de pases solo acepta solicitudes verificadas de Lunet y no conserva nada más allá de lo descrito arriba. Cloudflare opera una red global, así que el tratamiento transitorio de la sección 3(c) puede ocurrir en un centro de datos fuera de tu país.</p>

    <h2 id="website">9. Este sitio web</h2>
    <p>lunet.vallepinto.com no usa cookies, analíticas ni scripts o tipografías de terceros. Lo sirve Cloudflare, que procesa direcciones IP de forma transitoria para entregarlo y protegerlo.</p>

    <h2 id="changes">10. Cambios</h2>
    <p>Si este aviso cambia, actualizaremos esta página y la fecha de vigencia de arriba. Si un cambio afecta el manejo de datos, también lo mencionaremos en las notas de la versión de la app antes de que entre en vigor.</p>

    <h2 id="contact">11. Contacto</h2>
    <p>¿Dudas sobre privacidad? Escribe a ${mail('es', 'mail-inline')}<noscript> (rovapin (arroba) gmail (punto) com)</noscript>.</p>
    <p class="meta">Si hubiera diferencias entre esta versión y la versión en inglés, prevalece la versión en inglés.</p>
  </div>
</article>
`,
};

export function privacy(lang) {
  const c = lang === 'es' ? es : en;
  return layout({ lang, page: 'privacy', title: c.title, description: c.description, body: c.body, scripts: mailScript });
}
