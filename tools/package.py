"""Package the magic extension; preserve the Stage 1 release and user-edited assets."""
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
release = "BlackClover_Magic"
place = DIST / (release + ".rbxlx")
subprocess.run([rojo, "build", "default.project.json", "--output", str(place)], cwd=ROOT, check=True)
subprocess.run([sys.executable, "tools/verify_place.py", str(place)], cwd=ROOT, check=True)
for name in ("README_RU.md", "TEST_REPORT_RU.md"):
    shutil.copy2(ROOT / name, DIST / name)

sources = [ROOT / name for name in (".gitattributes", ".gitignore", "default.project.json", "README.md", "README_RU.md", "TEST_REPORT_RU.md")]
for directory in ("src", "assets", "meshes", "docs", "tests", "tools"):
    sources.extend(p for p in (ROOT / directory).rglob("*") if p.is_file() and "__pycache__" not in p.parts)
luau = [p for p in sources if p.suffix == ".luau"]
assert len(luau) == 45, f"Expected 45 Luau files (43 engine + 2 CLI tests), found {len(luau)}"

archive_path = DIST / (release + ".zip")
with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    def add(path, relative):
        # Stable metadata makes repeat builds reproducible; source timestamps are irrelevant.
        info = zipfile.ZipInfo(release + "/" + relative, date_time=(2026, 11, 2, 0, 0, 0))
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
        assert archive.read(release + "/source/" + path.relative_to(ROOT).as_posix()) == path.read_bytes()
    assert archive.read(release + "/" + place.name) == place.read_bytes()
    entry_count = len(archive.infolist())

deliverables = [p for p in DIST.iterdir() if p.is_file() and p.name != "SHA256SUMS.txt"]
lines = [f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}" for path in sorted(deliverables)]
(DIST / "SHA256SUMS.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"PASS: ZIP integrity; {entry_count} entries; all {len(luau)} Luau sources and built place match")
for path in sorted(DIST.iterdir()):
    if path.is_file():
        print(f"{path.name}: {path.stat().st_size:,} bytes")
