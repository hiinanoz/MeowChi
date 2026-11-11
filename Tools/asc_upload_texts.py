#!/usr/bin/env python3
"""Writes the store texts in fastlane/metadata/<locale>/ to an App Store version with the API.

Used when fastlane can't run its metadata step (first version without App Review contact details).
Version texts: description, keywords, promotional text, marketing and support URLs (and "What's New"
after the first version). App info texts: name, subtitle, privacy URL. Never submits for review.
Usage: python3 Tools/asc_upload_texts.py 1.0
"""
import sys
from pathlib import Path

from asc_api import BUNDLE_ID, call

ROOT = Path(__file__).resolve().parent.parent / "fastlane/metadata"
version = sys.argv[1]
first_version = version in ("1.0", "1.0.0")


def text(locale, field):
    path = ROOT / locale / f"{field}.txt"
    return path.read_text().strip() if path.exists() else None


app_id = call("GET", f"/apps?filter[bundleId]={BUNDLE_ID}")["data"][0]["id"]
version_id = call("GET", f"/apps/{app_id}/appStoreVersions?filter[versionString]={version}")["data"][0]["id"]
version_locs = {l["attributes"]["locale"]: l["id"]
                for l in call("GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=50")["data"]}
info_id = call("GET", f"/apps/{app_id}/appInfos")["data"][0]["id"]
info_locs = {l["attributes"]["locale"]: l["id"]
             for l in call("GET", f"/appInfos/{info_id}/appInfoLocalizations?limit=50")["data"]}

for folder in sorted(p for p in ROOT.iterdir() if p.is_dir() and p.name != "review_information"):
    locale = folder.name
    attributes = {"description": text(locale, "description"), "keywords": text(locale, "keywords"),
                  "promotionalText": text(locale, "promotional_text"), "marketingUrl": text(locale, "marketing_url"),
                  "supportUrl": text(locale, "support_url")}
    if not first_version:
        attributes["whatsNew"] = text(locale, "release_notes")
    attributes = {k: v for k, v in attributes.items() if v}
    if locale in version_locs:
        call("PATCH", f"/appStoreVersionLocalizations/{version_locs[locale]}",
             {"data": {"type": "appStoreVersionLocalizations", "id": version_locs[locale], "attributes": attributes}})
    else:
        call("POST", "/appStoreVersionLocalizations", {"data": {
            "type": "appStoreVersionLocalizations", "attributes": {"locale": locale, **attributes},
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}}}})
    info = {"name": text(locale, "name"), "subtitle": text(locale, "subtitle"), "privacyPolicyUrl": text(locale, "privacy_url")}
    info = {k: v for k, v in info.items() if v}
    if locale in info_locs:
        call("PATCH", f"/appInfoLocalizations/{info_locs[locale]}",
             {"data": {"type": "appInfoLocalizations", "id": info_locs[locale], "attributes": info}})
    else:
        call("POST", "/appInfoLocalizations", {"data": {
            "type": "appInfoLocalizations", "attributes": {"locale": locale, **info},
            "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info_id}}}}})
    print(f"✓ {locale}")
