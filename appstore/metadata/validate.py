#!/usr/bin/env python3
"""Validate App Store metadata (fastlane deliver layout) against App Store Connect limits.

Usage: python3 appstore/metadata/validate.py [locale ...]
Exits non-zero if any locale fails.
"""
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent

LOCALES = [
    "en-US", "es-MX", "es-ES", "fr-FR", "fr-CA", "de-DE", "it", "pt-BR", "pt-PT", "nl-NL",
    "sv", "da", "no", "fi", "pl", "cs", "sk", "hu", "ro", "hr", "el", "tr", "ru", "uk",
    "ar-SA", "he", "hi", "th", "vi", "id", "ms", "ja", "ko", "zh-Hans", "zh-Hant", "ca",
    "en-GB", "en-AU", "en-CA",
]

# field -> (max characters, required)
CHAR_LIMITS = {
    "name.txt": (30, True),
    "subtitle.txt": (30, True),
    "promotional_text.txt": (170, True),
    "description.txt": (4000, True),
    "release_notes.txt": (4000, True),
}
KEYWORD_BYTES = 100
MIN_NAME = 2

URLS = {
    "support_url.txt": "https://lunet.vallepinto.com/support",
    "marketing_url.txt": "https://lunet.vallepinto.com",
    "privacy_url.txt": "https://lunet.vallepinto.com/privacy",
}

# Scripts written without spaces between words: substring checks are used there.
NO_SPACE_LOCALES = {"ja", "zh-Hans", "zh-Hant", "th"}

# Price claims are not allowed in the name/subtitle/keywords.
PRICE_WORDS = {
    "free", "gratis", "gratuit", "gratuite", "gratuito", "gratuita", "kostenlos", "gratuitamente",
    "ilmainen", "darmowy", "darmowa", "zdarma", "zadarmo", "ingyenes", "besplatno", "besplatan",
    "δωρεάν", "ücretsiz", "бесплатно", "бесплатный", "безкоштовно", "مجاني", "חינם", "मुफ्त",
    "ฟรี", "miễn phí", "percuma", "無料", "무료", "免费", "免費", "kostnadsfri", "gratuïta",
}

# Competitor / third-party marks that must not appear in keywords or name/subtitle.
TRADEMARKS = {
    "google", "lens", "kaspersky", "trendmicro", "norton", "scanbot", "qrbot", "gamma",
    "whatsapp", "instagram", "facebook", "tiktok", "paypal", "venmo", "amazon", "walmart",
}

EMOJI_RE = re.compile(
    "[\U0001F300-\U0001FAFF\U00002600-\U000027BF\U0001F000-\U0001F2FF\U0001F900-\U0001F9FF]"
)


def words(text):
    """Lower-cased word tokens (Unicode aware; '&', ':' and punctuation split)."""
    text = unicodedata.normalize("NFC", text).lower()
    return {w for w in re.split(r"[^\wऀ-ॿ฀-๿]+", text) if w}


def read(path):
    return path.read_text(encoding="utf-8") if path.exists() else None


def check_locale(loc):
    errors, notes = [], []
    d = ROOT / loc
    if not d.is_dir():
        return [f"missing folder {d}"], notes

    fields = {}
    for fname, (limit, required) in CHAR_LIMITS.items():
        text = read(d / fname)
        if text is None:
            if required:
                errors.append(f"{fname}: missing")
            continue
        fields[fname] = text
        n = len(unicodedata.normalize("NFC", text))
        if n > limit:
            errors.append(f"{fname}: {n} chars > {limit}")
        if not text.strip():
            errors.append(f"{fname}: empty")
        if text != text.strip() and fname in ("name.txt", "subtitle.txt", "promotional_text.txt"):
            errors.append(f"{fname}: leading/trailing whitespace or newline")
        if EMOJI_RE.search(text):
            errors.append(f"{fname}: contains emoji")
        notes.append(f"{fname.split('.')[0]}={n}")

    name = fields.get("name.txt", "")
    subtitle = fields.get("subtitle.txt", "")
    if name and not name.startswith("Lunet"):
        errors.append("name.txt: must start with 'Lunet'")
    if name and len(name) < MIN_NAME:
        errors.append("name.txt: too short")

    kw = read(d / "keywords.txt")
    if kw is None:
        errors.append("keywords.txt: missing")
        kw = ""
    b = len(kw.encode("utf-8"))
    notes.append(f"kw={b}B")
    if b > KEYWORD_BYTES:
        errors.append(f"keywords.txt: {b} bytes > {KEYWORD_BYTES}")
    if "\n" in kw:
        errors.append("keywords.txt: contains a newline")
    if re.search(r",\s", kw) or re.search(r"\s,", kw):
        errors.append("keywords.txt: space next to a comma")
    terms = [t for t in kw.split(",")]
    if any(not t.strip() for t in terms):
        errors.append("keywords.txt: empty term (double or trailing comma)")
    terms = [unicodedata.normalize("NFC", t.strip()).lower() for t in terms if t.strip()]

    seen = set()
    for t in terms:
        if t in seen:
            errors.append(f"keywords.txt: duplicate term '{t}'")
        seen.add(t)

    # Duplicate single words across multi-word terms are also wasted bytes.
    word_count = {}
    for t in terms:
        for w in words(t):
            word_count[w] = word_count.get(w, 0) + 1
    for w, c in word_count.items():
        if c > 1:
            errors.append(f"keywords.txt: word '{w}' repeated across terms")

    title_words = words(name) | words(subtitle)
    title_blob = (name + " " + subtitle).lower()
    for t in terms:
        for w in words(t):
            if w in title_words:
                errors.append(f"keywords.txt: '{w}' already in name/subtitle")
        if loc in NO_SPACE_LOCALES and t in title_blob:
            errors.append(f"keywords.txt: '{t}' already contained in name/subtitle")
        if t == "lunet":
            errors.append("keywords.txt: app name repeated")

    indexed = " ".join([name, subtitle, kw]).lower()
    for w in PRICE_WORDS:
        if re.search(r"(?<!\w)" + re.escape(w) + r"(?!\w)", indexed):
            errors.append(f"price word '{w}' in name/subtitle/keywords")
    for w in TRADEMARKS:
        if w in words(indexed):
            errors.append(f"third-party mark '{w}' in name/subtitle/keywords")

    for fname, expected in URLS.items():
        text = read(d / fname)
        if text is None:
            errors.append(f"{fname}: missing")
        elif text.strip() != expected:
            errors.append(f"{fname}: '{text.strip()}' != '{expected}'")

    return errors, notes


def main():
    locales = sys.argv[1:] or LOCALES
    extra = sorted(p.name for p in ROOT.iterdir() if p.is_dir() and p.name not in LOCALES and p.name != "review_attachments")
    failed = 0
    for loc in locales:
        errors, notes = check_locale(loc)
        status = "FAIL" if errors else "ok  "
        print(f"{status} {loc:8} {' '.join(notes)}")
        for e in errors:
            print(f"       - {e}")
        failed += bool(errors)
    if extra:
        print(f"note: unexpected folders: {', '.join(extra)}")
    print(f"\n{len(locales) - failed}/{len(locales)} locales pass")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
