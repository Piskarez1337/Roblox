"""Reproduce available offline checks. Roblox Play Mode remains a separate test."""
from pathlib import Path
import argparse
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--bin-dir", type=Path, help="directory containing pinned Luau and Rojo executables")
args = parser.parse_args()


def executable(name):
    return str(args.bin_dir / name) if args.bin_dir else name


def run(command, quiet=False):
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode or not quiet:
        for output in (result.stdout, result.stderr):
            if output:
                print(output.decode("utf-8", errors="replace").strip())
    if result.returncode:
        raise SystemExit(result.returncode)


sources = sorted(ROOT.joinpath("src").rglob("*.luau")) + sorted(ROOT.joinpath("tests").rglob("*.luau"))
for source in sources:
    run([executable("luau-compile"), str(source)], quiet=True)
print(f"PASS: compilation of {len(sources)} Luau files")
run([executable("luau-analyze"), "src/shared/Config.luau", "src/shared/Rules.luau", "src/shared/MagicConfig.luau", "src/shared/MagicRules.luau", "src/shared/SpellRegistry.luau", "tests/rules.spec.luau", "tests/magic.spec.luau"])
print("PASS: strict analysis of engine-independent modules and rule tests")
run([executable("luau"), "tests/rules.spec.luau"])
run([executable("luau"), "tests/magic.spec.luau"])
with tempfile.TemporaryDirectory(prefix="black-clover-check-") as folder:
    place = Path(folder) / "BlackClover_Magic.rbxlx"
    run([executable("rojo"), "build", "default.project.json", "--output", str(place)])
    run([sys.executable, "tools/verify_place.py", str(place)])
print("Offline checks complete. Roblox engine / Play Mode: NOT RUN.")
