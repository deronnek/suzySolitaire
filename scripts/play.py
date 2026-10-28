# A small Google Play Developer API client for the scripts here: signs in with the service account key at PLAY_KEY_PATH
# (in the environment, or in the git-ignored scripts/play.local.env).  Needs only the standard library and openssl.

import base64, json, os, subprocess, sys, tempfile, time, urllib.error, urllib.parse, urllib.request

API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
UPLOAD = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/"
PACKAGE = "net.dseelig.suzesolitaire"

# Read the settings from scripts/play.local.env when they aren't already in the environment
_settings = os.path.join(os.path.dirname(os.path.abspath(__file__)), "play.local.env")
if os.path.exists(_settings):
    with open(_settings) as f:
        for line in f:
            name, _, value = line.strip().partition("=")
            if value and not name.startswith("#"):
                os.environ.setdefault(name, os.path.expanduser(value.strip("\"'")))

_token = None


def b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def token():
    global _token
    if _token and _token[1] > time.time() + 60:
        return _token[0]
    key_path = os.environ.get("PLAY_KEY_PATH") or sys.exit("Set PLAY_KEY_PATH to the Play Console service account's JSON key")
    with open(os.path.expanduser(key_path)) as f:
        key = json.load(f)
    now = int(time.time())
    header = {"alg": "RS256", "typ": "JWT"}
    claims = {"iss": key["client_email"], "scope": "https://www.googleapis.com/auth/androidpublisher",
              "aud": key["token_uri"], "iat": now, "exp": now + 3600}
    signing_input = b64(json.dumps(header).encode()) + "." + b64(json.dumps(claims).encode())
    # openssl reads the private key from a file only this user can read, removed straight after
    with tempfile.NamedTemporaryFile("w", suffix=".pem") as pem:
        os.chmod(pem.name, 0o600)
        pem.write(key["private_key"])
        pem.flush()
        signature = subprocess.run(["openssl", "dgst", "-sha256", "-sign", pem.name], input=signing_input.encode(),
                                   capture_output=True, check=True).stdout
    assertion = signing_input + "." + b64(signature)
    body = urllib.parse.urlencode({"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion})
    with urllib.request.urlopen(key["token_uri"], data=body.encode()) as response:
        granted = json.loads(response.read())
    _token = (granted["access_token"], now + granted["expires_in"])
    return _token[0]


def _send(request, what):
    try:
        with urllib.request.urlopen(request) as response:
            data = response.read()
            return json.loads(data) if data else None
    except urllib.error.HTTPError as error:
        sys.exit(f"{what} failed ({error.code}): {error.read().decode()}")


def call(method, path, body=None, query=None):
    url = API + PACKAGE + path + ("?" + urllib.parse.urlencode(query) if query else "")
    request = urllib.request.Request(url, method=method, data=json.dumps(body).encode() if body is not None else None,
                                     headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"})
    return _send(request, f"{method} {path}")


def upload(path, file_path, content_type="application/octet-stream"):
    with open(file_path, "rb") as f:
        data = f.read()
    request = urllib.request.Request(UPLOAD + PACKAGE + path + "?uploadType=media", method="POST", data=data,
                                     headers={"Authorization": "Bearer " + token(), "Content-Type": content_type})
    return _send(request, f"Uploading {os.path.basename(file_path)}")
