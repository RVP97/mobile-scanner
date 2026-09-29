import json, subprocess, sys, time
JWT = sys.argv[1]; A = "https://api.appstoreconnect.apple.com/v1"
APP = "6758315540"; VER = "b68d7da9-717c-4896-9cf1-841dc2af47f1"
def call(method, url, body=None):
    cmd = ["curl", "-g", "-s", "--retry", "5", "--retry-all-errors", "-X", method, url, "-H", f"Authorization: Bearer {JWT}", "-H", "Content-Type: application/json"]
    if body is not None: cmd += ["-d", json.dumps(body)]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    return json.loads(out) if out.strip() else {}
def errs(d):
    out=[]
    def walk(e, ind=""):
        out.append(f"{ind}{e.get('code')}: {e.get('detail')}")
        for lst in (e.get("meta") or {}).get("associatedErrors", {}).values():
            for x in lst: walk(x, ind + "   ")
    for e in d.get("errors", []): walk(e)
    return "\n".join(out)
b = call("GET", f"{A}/appStoreVersions/{VER}/build")
print("attached build:", (b.get("data") or {}).get("attributes", {}).get("version"))
for s in call("GET", f"{A}/apps/{APP}/reviewSubmissions?limit=10").get("data", []):
    print("existing submission", s["id"], s["attributes"]["state"])
sub = call("POST", f"{A}/reviewSubmissions", {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"},
      "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})
if "errors" in sub: sys.exit("create submission failed:\n" + errs(sub))
sid = sub["data"]["id"]; print("new submission", sid)
item = call("POST", f"{A}/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems",
      "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sid}},
                        "appStoreVersion": {"data": {"type": "appStoreVersions", "id": VER}}}}})
if "errors" in item: sys.exit("add version failed:\n" + errs(item))
print("version added to submission")
r = call("PATCH", f"{A}/reviewSubmissions/{sid}", {"data": {"type": "reviewSubmissions", "id": sid, "attributes": {"submitted": True}}})
if "errors" in r: sys.exit("submit failed:\n" + errs(r))
print("SUBMITTED:", r["data"]["attributes"]["state"])
time.sleep(5)
v = call("GET", f"{A}/appStoreVersions/{VER}")
print("version state:", v["data"]["attributes"].get("appStoreState") or v["data"]["attributes"].get("appVersionState"))
