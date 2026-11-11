#!/usr/bin/env python3
"""Exits 0 if the App Store version already has App Review contact details, 1 if not.

fastlane can't create them without a contact name and phone, which stay out of the repository;
the user fills them in once in App Store Connect. Usage: python3 Tools/asc_review_detail_exists.py 1.0
"""
import sys

from asc_api import BUNDLE_ID, call

version = sys.argv[1]
app_id = call("GET", f"/apps?filter[bundleId]={BUNDLE_ID}")["data"][0]["id"]
versions = call("GET", f"/apps/{app_id}/appStoreVersions?filter[versionString]={version}")["data"]
if not versions:
    sys.exit(f"Sürüm {version} bulunamadı")
detail = call("GET", f"/appStoreVersions/{versions[0]['id']}/appStoreReviewDetail", tolerant=True)
attrs = (detail.get("data") or {}).get("attributes") or {}
ok = bool(attrs.get("contactFirstName") and attrs.get("contactPhone"))
print("İnceleme iletişim bilgileri: " + ("var" if ok else "YOK (App Store Connect'te doldurulmalı)"))
sys.exit(0 if ok else 1)
