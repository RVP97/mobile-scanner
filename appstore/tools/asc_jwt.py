"""Prints a 20-minute App Store Connect API token (ES256), from ~/.appstoreconnect/trail.env.

Usage: python3 appstore/tools/asc_jwt.py   (e.g. as the <jwt-command> for resubmit.py)
"""
import base64, json, os, time, re
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature
env = {}
for line in open(os.path.expanduser("~/.appstoreconnect/trail.env")):
    m = re.match(r'\s*(?:export\s+)?(\w+)=["\']?([^"\'\n]*)', line)
    if m: env[m[1]] = m[2]
key = serialization.load_pem_private_key(open(os.path.expanduser(env["ASC_KEY_PATH"]), "rb").read(), None)
b64 = lambda b: base64.urlsafe_b64encode(b).rstrip(b"=")
h = b64(json.dumps({"alg": "ES256", "kid": env["ASC_KEY_ID"], "typ": "JWT"}).encode())
now = int(time.time())
p = b64(json.dumps({"iss": env["ASC_ISSUER_ID"], "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"}).encode())
r, s = decode_dss_signature(key.sign(h + b"." + p, ec.ECDSA(hashes.SHA256())))
print((h + b"." + p + b"." + b64(r.to_bytes(32, "big") + s.to_bytes(32, "big"))).decode())
