#!/usr/bin/env python3
"""App Store Connect API için ortak yardımcı (diğer Tools/asc_*.py betikleri kullanır).

Ortam değişkenleri (GitHub sırlarından): ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY.
Uygulamanın paket kimliği: APP_BUNDLE_ID ortam değişkeni ya da aşağıdaki varsayılan.
Gerekenler: pip install pyjwt cryptography
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

import jwt

BUNDLE_ID = os.environ.get("APP_BUNDLE_ID", "com.othinks.Meowchi")
API = "https://api.appstoreconnect.apple.com/v1"


def token():
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"},
        os.environ["ASC_PRIVATE_KEY"], algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"]})


def call(method, path, body=None, tolerant=False):
    request = urllib.request.Request(
        path if path.startswith("http") else API + path, method=method,
        data=json.dumps(body).encode() if body else None,
        headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        if tolerant:
            return {"error": error.code}
        sys.exit(f"{method} {path} → {error.code}\n{error.read().decode()}")
