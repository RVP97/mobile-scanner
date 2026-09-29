import json, subprocess, sys, os, hashlib, glob
JWT = sys.argv[1]; LOC = sys.argv[2]; DIR = sys.argv[3]
A = "https://api.appstoreconnect.apple.com/v1"
def call(method, url, body=None):
    cmd = ["curl", "-s", "--retry", "5", "--retry-all-errors", "-X", method, url, "-H", f"Authorization: Bearer {JWT}", "-H", "Content-Type: application/json"]
    if body is not None: cmd += ["-d", json.dumps(body)]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    return json.loads(out) if out.strip() else {}
TYPES = {"iPhone69": "APP_IPHONE_67", "iPadPro13": "APP_IPAD_PRO_3GEN_129"}
sets = {s["attributes"]["screenshotDisplayType"]: s["id"] for s in call("GET", f"{A}/appStoreVersionLocalizations/{LOC}/appScreenshotSets?limit=50").get("data", [])}
for key, dtype in TYPES.items():
    files = sorted(glob.glob(os.path.join(DIR, f"*_{key}_*.png")))
    if not files: continue
    if dtype in sets:  # replace whatever is there
        call("DELETE", f"{A}/appScreenshotSets/{sets[dtype]}")
    sid = call("POST", f"{A}/appScreenshotSets", {"data": {"type": "appScreenshotSets", "attributes": {"screenshotDisplayType": dtype},
        "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": LOC}}}}})["data"]["id"]
    for f in files:
        data = open(f, "rb").read()
        r = call("POST", f"{A}/appScreenshots", {"data": {"type": "appScreenshots", "attributes": {"fileName": os.path.basename(f), "fileSize": len(data)},
            "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sid}}}}})["data"]
        for op in r["attributes"]["uploadOperations"]:
            chunk = data[op["offset"]:op["offset"] + op["length"]]
            hdrs = sum([["-H", f'{h["name"]}: {h["value"]}'] for h in op.get("requestHeaders", [])], [])
            subprocess.run(["curl", "-s", "--retry", "5", "--retry-all-errors", "-X", op["method"], op["url"], *hdrs, "--data-binary", "@-"], input=chunk, capture_output=True)
        done = call("PATCH", f"{A}/appScreenshots/{r['id']}", {"data": {"type": "appScreenshots", "id": r["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
        print(dtype, os.path.basename(f), "ok" if "data" in done else done.get("errors"))
