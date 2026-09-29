# Lunet: App Privacy answers (App Store Connect > App Privacy)

**Answer: "No, we do not collect data from this app" -> Data Not Collected.**
Tracking: **No.** Privacy policy URL: https://lunet.vallepinto.com/privacy

## Apple's definition we apply

Apple: *"Collect" refers to transmitting data off the device in a way that allows you and/or your third-party
partners to access it for a period longer than what is necessary to service the transmitted request in real time.*
Data that is processed only on device is not collected. Optional disclosure also allows omitting data that is
sent off device only to service a request in real time and is not retained.

Lunet has no account, no analytics, no crash-reporting SDK, no advertising, and no third-party SDKs (the Xcode
project has no package dependencies). Scan history, created codes, "Your codes", and optional scan locations are
stored only on the device (App Group container) and are never uploaded.

## Every network request, and why it is not "collection"

| Request | What is sent | Who receives it | Retained? | Why not collected |
| --- | --- | --- | --- | --- |
| Link deep check: HEAD/GET to the scanned URL, redirects followed by hand (max 8 hops) | The scanned URL itself | The link's own server (and each redirect's server) | Not by us. Ephemeral URLSession: no cookies, no cache | Equivalent to the user visiting the link they chose to scan; the developer receives nothing. The body is never read. |
| Domain age: `https://rdap.org/domain/<domain>` | The domain name only | RDAP bootstrap and the registry | Not by us | Public registry lookup of a domain, not user data; the developer receives nothing. |
| Product lookup: `world.openfoodfacts.org` / `world.openproductsfacts.org` `/api/v2/product/<barcode>.json` | The product's barcode number (GTIN) | Open Food Facts (open database) | Not by us | A barcode identifies a product, not a person; only sent when the user opens a product result. |
| Add to Apple Wallet: `bloom.vallepinto.com/lens/v1/pass` | The pass fields the user chose to add (e.g. passenger name, flight, seat, the scanned barcode) | Lunet's signing service (Cloudflare Worker, developer-operated) | **No.** The signed `.pkpass` is returned in the same response; the body is never written to storage or logs | Processed only to service the request in real time and discarded, which is outside Apple's definition of collection. |
| App Attest for the signing service: `/lens/v1/challenge`, `/lens/v1/attest` | A random challenge, and the App Attest public key + key ID generated for this install | Lunet's signing service | Public key, key ID, assertion counter and last-used time are stored (D1) for replay protection | See note below. |
| Rate limiting on the signing service | Client IP address (implicit in any request) | Lunet's signing service | Only a truncated SHA-256 of the IP inside an hourly bucket, purged within 2 hours | Not linkable to a person, used only for abuse prevention of the live request, and short-lived. |

Operational logs: `wrangler.toml` enables Cloudflare Workers observability, which keeps request metadata (not
bodies) for Cloudflare's short log retention window. This is standard server operation, not linked to a user. If you
want the strictest reading, set `head_sampling_rate` lower or disable `[observability]` before launch.

Links the user chooses to open (Safari, Maps, carrier tracking pages, web search) are handed to the system or
another app; Lunet does not transmit anything itself.

## Note for the lead: the App Attest key (conservative option)

The App Attest key is a random Secure Enclave key created per install. It is not derived from any hardware
identifier, is not linked to a person, name, or account, and is used only to verify that pass requests come from a
genuine copy of Lunet (fraud prevention). We believe "Data Not Collected" is accurate: the key identifies no user or
device beyond an install-scoped cryptographic credential, and nothing it is stored with is personal data.

If you prefer the most conservative label, declare instead:
**Identifiers > Device ID**, Used for: **App Functionality** (fraud prevention / security), Linked to user: **No**,
Used for tracking: **No**. This produces "Data Not Linked to You: Identifiers" on the product page. Do not declare
anything else; everything else above is either not transmitted to the developer or not retained.

## Permissions shown to users (for consistency with the label)

- Camera: scanning. Frames are processed on device and never leave it.
- Photos (picker): scanning a code from an image; only the picked image is read, on device.
- Location (When In Use): off by default; only if the user turns on "remember where you scanned". Stored on device.
- Face ID: optional History lock, handled by iOS (LocalAuthentication); Lunet never sees biometric data.
- Contacts / Calendar: only when the user taps Save contact / Add event, via system UI.
- Local network / Hotspot configuration: joining a scanned Wi-Fi network via the system prompt.
