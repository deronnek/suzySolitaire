# A small App Store Connect API client for the scripts here: signs a token with the API key in ASC_KEY_ID,
# ASC_ISSUER_ID and optionally ASC_KEY_PATH (default ~/.appstoreconnect/private_keys/AuthKey_<key id>.p8).
# Needs only the standard library and openssl.

import base64, json, os, subprocess, sys, time, urllib.error, urllib.parse, urllib.request

API = "https://api.appstoreconnect.apple.com"

# Read the key settings from scripts/testflight.local.env when they aren't already in the environment
_settings = os.path.join(os.path.dirname(os.path.abspath(__file__)), "testflight.local.env")
if "ASC_KEY_ID" not in os.environ and os.path.exists(_settings):
    with open(_settings) as f:
        for line in f:
            name, _, value = line.strip().partition("=")
            if value and not name.startswith("#"):
                os.environ.setdefault(name, value.strip("\"'"))


def b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def token():
    key_id, issuer = os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"]
    key_path = os.environ.get("ASC_KEY_PATH") or os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{key_id}.p8")
    now = int(time.time())
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    claims = {"iss": issuer, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}
    signing_input = b64(json.dumps(header).encode()) + "." + b64(json.dumps(claims).encode())
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_path], input=signing_input.encode(),
                         capture_output=True, check=True).stdout
    # openssl writes a DER sequence of two integers; a JWT wants them as 32 raw bytes each
    i = 4 if der[1] < 0x80 else 5
    r = der[i:i + der[i - 1]]
    i += len(r) + 2
    s = der[i:i + der[i - 1]]
    return signing_input + "." + b64(r.lstrip(b"\0").rjust(32, b"\0") + s.lstrip(b"\0").rjust(32, b"\0"))


def call(method, path, body=None, query=None):
    url = API + path + ("?" + urllib.parse.urlencode(query) if query else "")
    request = urllib.request.Request(url, method=method, data=json.dumps(body).encode() if body else None,
                                     headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request) as response:
            data = response.read()
            return json.loads(data) if data else None
    except urllib.error.HTTPError as error:
        sys.exit(f"{method} {path} failed ({error.code}): {error.read().decode()}")
