"""Wait for a build to process, attach it to the editable version, refresh review notes, and (re)submit.

Usage: python3 resubmit.py <jwt-command> <build-number> <notes-file>
<jwt-command> is a shell command that prints a fresh App Store Connect JWT (tokens expire after 20 min).
"""
import json, subprocess, sys, time
JWT_CMD, BUILD, NOTES = sys.argv[1], sys.argv[2], sys.argv[3]
_tok = {"v": None, "t": 0}
def jwt():
    if time.time() - _tok["t"] > 600:
        _tok["v"] = subprocess.run(JWT_CMD, shell=True, capture_output=True, text=True).stdout.strip()
        _tok["t"] = time.time()
    return _tok["v"]
A = "https://api.appstoreconnect.apple.com/v1"; APP = "6758315540"

def call(method, url, body=None):
    cmd = ["curl", "-g", "-s", "--retry", "5", "--retry-all-errors", "-X", method, url,
           "-H", f"Authorization: Bearer {jwt()}", "-H", "Content-Type: application/json"]
    if body is not None: cmd += ["-d", json.dumps(body)]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    return json.loads(out) if out.strip() else {}

def errs(d):
    out = []
    def walk(e, ind=""):
        out.append(f"{ind}{e.get('code')}: {e.get('detail')}")
        for lst in (e.get("meta") or {}).get("associatedErrors", {}).values():
            for x in lst: walk(x, ind + "   ")
    for e in d.get("errors", []): walk(e)
    return "\n".join(out)

# 1. wait for the build
build_id = None
for _ in range(60):
    d = call("GET", f"{A}/builds?filter[app]={APP}&filter[version]={BUILD}&limit=1")
    b = (d.get("data") or [None])[0]
    state = b and b["attributes"]["processingState"]
    print(time.strftime("%H:%M:%S"), f"build {BUILD}:", state or "not visible yet", flush=True)
    if state == "VALID": build_id = b["id"]; break
    if state in ("INVALID", "FAILED"): sys.exit("build failed processing")
    time.sleep(30)
if not build_id: sys.exit("timed out waiting for build")

# 2. attach build + notes to the editable version
v = call("GET", f"{A}/apps/{APP}/appStoreVersions?filter[platform]=IOS&limit=5")["data"]
ver = next(x for x in v if x["attributes"]["appStoreState"] in
           ("PREPARE_FOR_SUBMISSION", "REJECTED", "METADATA_REJECTED", "DEVELOPER_REJECTED", "INVALID_BINARY"))
vid = ver["id"]; print("version", ver["attributes"]["versionString"], ver["attributes"]["appStoreState"])
r = call("PATCH", f"{A}/appStoreVersions/{vid}/relationships/build", {"data": {"type": "builds", "id": build_id}})
if r.get("errors"): sys.exit("attach build failed:\n" + errs(r))
print("attached build", BUILD)
rd = call("GET", f"{A}/appStoreVersions/{vid}/appStoreReviewDetail").get("data")
if rd:
    r = call("PATCH", f"{A}/appStoreReviewDetails/{rd['id']}", {"data": {"type": "appStoreReviewDetails", "id": rd["id"],
             "attributes": {"notes": open(NOTES).read()}}})
    print("review notes updated" if not r.get("errors") else "notes update failed:\n" + errs(r))

# 3. resubmit: prefer resolving the open submission, else start a fresh one
subs = call("GET", f"{A}/apps/{APP}/reviewSubmissions?limit=20").get("data", [])
open_sub = next((s for s in subs if s["attributes"]["state"] == "UNRESOLVED_ISSUES"), None)
if open_sub:
    r = call("PATCH", f"{A}/reviewSubmissions/{open_sub['id']}", {"data": {"type": "reviewSubmissions", "id": open_sub["id"], "attributes": {"submitted": True}}})
    if not r.get("errors"):
        sys.exit(print("RESUBMITTED:", r["data"]["attributes"]["state"]))
    print("resolve-in-place refused, starting a fresh submission:\n" + errs(r))
    call("PATCH", f"{A}/reviewSubmissions/{open_sub['id']}", {"data": {"type": "reviewSubmissions", "id": open_sub["id"], "attributes": {"canceled": True}}})
    for _ in range(20):
        s = call("GET", f"{A}/reviewSubmissions/{open_sub['id']}")["data"]["attributes"]["state"]
        if s != "CANCELING": break
        time.sleep(5)
sub = call("POST", f"{A}/reviewSubmissions", {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"},
      "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})
if sub.get("errors"): sys.exit("create submission failed:\n" + errs(sub))
sid = sub["data"]["id"]
r = call("POST", f"{A}/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
      "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sid}},
      "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
if r.get("errors"): sys.exit("add version failed:\n" + errs(r))
r = call("PATCH", f"{A}/reviewSubmissions/{sid}", {"data": {"type": "reviewSubmissions", "id": sid, "attributes": {"submitted": True}}})
if r.get("errors"): sys.exit("submit failed:\n" + errs(r))
print("SUBMITTED:", r["data"]["attributes"]["state"])
