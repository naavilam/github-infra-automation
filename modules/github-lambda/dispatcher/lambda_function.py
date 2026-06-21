import os
import json
import time
import urllib.request
import urllib.error

import jwt

GITHUB_API = "https://api.github.com"

CORS_ORIGIN = os.environ.get("CORS_ORIGIN", "*")
USER_AGENT = os.environ.get("USER_AGENT", "github-dispatcher")
ORG = os.environ["GITHUB_OWNER"]
REPO = os.environ["GITHUB_REPO"]

_cached_credentials = None


def load_secret():
    global _cached_credentials

    if _cached_credentials is None:
        raw = os.environ["GITHUB_CREDENTIALS"]
        _cached_credentials = json.loads(raw)

    return _cached_credentials


def resp(code, body):
    return {
        "statusCode": code,
        "headers": {
            "content-type": "application/json",
            "access-control-allow-origin": CORS_ORIGIN,
            "access-control-allow-headers": "content-type,x-audit-key",
            "access-control-allow-methods": "POST,OPTIONS",
        },
        "body": json.dumps(body),
    }


def gh(method, url, token, data=None):
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "User-Agent": USER_AGENT,
    }

    payload = None

    if data is not None:
        payload = json.dumps(data).encode("utf-8")
        headers["Content-Type"] = "application/json"

    req = urllib.request.Request(
        url,
        data=payload,
        headers=headers,
        method=method,
    )

    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            txt = r.read().decode("utf-8")
            return r.status, txt
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8")


def handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method", "")

    if method == "OPTIONS":
        return resp(200, {"ok": True})

    headers = {
        k.lower(): v
        for k, v in (event.get("headers") or {}).items()
    }

    if headers.get("x-audit-key") != os.environ.get("dispatch_shared_token"):
        return resp(401, {"ok": False, "error": "unauthorized"})

    try:
        body = json.loads(event.get("body") or "{}")

        workflow = body["workflow"]
        ref = body.get("ref", "main")
        inputs = body.get("inputs", {})

        credentials = load_secret()

        app_id = credentials["app_id"]
        installation_id = credentials["installation_id"]
        private_key_pem = credentials["private_key_pem"]

        now = int(time.time())

        app_jwt = jwt.encode(
            {
                "iat": now - 30,
                "exp": now + 9 * 60,
                "iss": app_id,
            },
            private_key_pem,
            algorithm="RS256",
        )

        st, txt = gh(
            "POST",
            f"{GITHUB_API}/app/installations/{installation_id}/access_tokens",
            app_jwt,
            data={},
        )

        if st not in (200, 201):
            return resp(
                400,
                {
                    "ok": False,
                    "error": "installation token failed",
                    "details": txt,
                },
            )

        token = json.loads(txt)["token"]

        st, txt = gh(
            "POST",
            f"{GITHUB_API}/repos/{ORG}/{REPO}/actions/workflows/{workflow}/dispatches",
            token,
            data={
                "ref": ref,
                "inputs": inputs,
            },
        )

        if st not in (204, 200, 201):
            return resp(
                400,
                {
                    "ok": False,
                    "error": f"dispatch failed {st}",
                    "details": txt,
                },
            )

        return resp(200, {"ok": True, "message": "dispatched"})

    except Exception as e:
        return resp(500, {"ok": False, "error": str(e)})


