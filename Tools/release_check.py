#!/usr/bin/env python3
"""App Store'a göndermeden önce kalan eksikleri listeler.

Kullanım:  python3 Tools/release_check.py

✗ satırları yüklemeyi engeller; • satırları hatırlatmadır. Uygulamaya özel kontrolleri buraya ekle.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
problems, notes = [], []

project = (ROOT / "project.yml").read_text()
if "ITSAppUsesNonExemptEncryption" not in project:
    notes.append("project.yml: ITSAppUsesNonExemptEncryption yok (TestFlight'ta şifreleme sorusu çıkar)")

import subprocess
if subprocess.run([sys.executable, str(ROOT / "Tools/validate_strings.py"), "--strict"], capture_output=True).returncode:
    notes.append("Çeviriler eksik (python3 Tools/validate_strings.py --strict ile listele)")

for page in ("docs/support.html", "docs/privacy.html"):
    path = ROOT / page
    if not path.exists():
        problems.append(f"{page} yok (Tools/build_docs.py ile üret)")
    elif "SUPPORT_EMAIL" in path.read_text():
        problems.append(f"{page}: SUPPORT_EMAIL yer tutucusu duruyor")

# Sıradaki güncelleme için not alınan, henüz yapılmamış işler (hatırlatma; yüklemeyi durdurmaz)
todo = ROOT / "Planning/Guncelleme-Listesi.md"
if todo.exists():
    for item in re.findall(r"^- \[ \] \*{0,2}(.+?)(?:\*\*|$)", todo.read_text(), re.M):
        notes.append(f"Güncelleme listesi: {item.strip()}")

for problem in problems:
    print(f"✗ {problem}")
for note in notes:
    print(f"• {note}")
print("✓ Yüklemeye hazır" if not problems else f"\n{len(problems)} eksik var")
sys.exit(1 if problems else 0)
