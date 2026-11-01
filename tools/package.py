"""Build and package Stage 1 without regenerating user-edited model assets."""
from pathlib import Path
import argparse
import hashlib
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"
parser = argparse.ArgumentParser()
parser.add_argument("--bin-dir", type=Path, help="directory containing pinned Luau and Rojo executables")
args = parser.parse_args()
DIST.mkdir(exist_ok=True)
rojo = str(args.bin_dir / "rojo") if args.bin_dir else "rojo"
place = DIST / "BlackClover_Stage1.rbxlx"
subprocess.run([rojo, "build", "default.project.json", "--output", str(place)], cwd=ROOT, check=True)
subprocess.run([sys.executable, "tools/verify_place.py", str(place)], cwd=ROOT, check=True)
for name in ("README_RU.md", "TEST_REPORT_RU.md"):
    shutil.copy2(ROOT / name, DIST / name)

sources = [ROOT / name for name in (".gitattributes", ".gitignore", "default.project.json", "README.md", "README_RU.md", "TEST_REPORT_RU.md")]
for directory in ("src", "assets", "tests", "tools"):
    sources.extend(p for p in (ROOT / directory).rglob("*") if p.is_file() and "__pycache__" not in p.parts)
luau = [p for p in sources if p.suffix == ".luau"]
assert len(luau) == 17, f"Expected 17 Luau files, found {len(luau)}"

archive_path = DIST / "BlackClover_Stage1.zip"
with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    def add(path, relative):
        # Stable metadata makes repeat builds reproducible; source timestamps are irrelevant.
        info = zipfile.ZipInfo("BlackClover_Stage1/" + relative, date_time=(2026, 11, 1, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o644 << 16
        archive.writestr(info, path.read_bytes())
    for name in (place.name, "README_RU.md", "TEST_REPORT_RU.md"):
        add(DIST / name, name)
    for path in sorted(sources):
        add(path, "source/" + path.relative_to(ROOT).as_posix())

with zipfile.ZipFile(archive_path) as archive:
    assert archive.testzip() is None, "ZIP integrity failure"
    for path in sources:
        assert archive.read("BlackClover_Stage1/source/" + path.relative_to(ROOT).as_posix()) == path.read_bytes()
    assert archive.read("BlackClover_Stage1/" + place.name) == place.read_bytes()
    entry_count = len(archive.infolist())

deliverables = [place, archive_path, DIST / "README_RU.md", DIST / "TEST_REPORT_RU.md"]
lines = [f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}" for path in sorted(deliverables)]
(DIST / "SHA256SUMS.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"PASS: ZIP integrity; {entry_count} entries; all 17 Luau sources and built place match")
for path in sorted(DIST.iterdir()):
    if path.is_file():
        print(f"{path.name}: {path.stat().st_size:,} bytes")
