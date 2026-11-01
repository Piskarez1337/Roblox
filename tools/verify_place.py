"""Validate the build and source placement; this does NOT emulate Roblox Studio."""
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
PLACE = Path(sys.argv[1])
xml = ET.parse(PLACE).getroot()
assert xml.tag == "roblox" and xml.attrib["version"] == "4"
paths = {}


def visit(node, prefix=""):
    for obj in node.findall("Item"):
        name = obj.findtext("Properties/string[@name='Name']")
        path = prefix + "/" + str(name)
        assert path not in paths, f"Duplicate path: {path}"
        paths[path] = obj
        # Asset models legitimately contain repeated decorative names.
        if path in ("/Workspace", "/StarterPlayer/StarterCharacter", "/ServerStorage/Actors") or path.startswith("/ReplicatedStorage/BlackClover/ArtTemplates/"):
            continue
        visit(obj, path)


visit(xml)
expected = {}
for group, prefix in {
    "shared": "/ReplicatedStorage/BlackClover/Shared",
    "server": "/ServerScriptService/BlackCloverServer",
    "client": "/StarterPlayer/StarterPlayerScripts/BlackCloverClient",
    "character": "/StarterPlayer/StarterCharacterScripts",
    "tests": "/ServerStorage",
}.items():
    for file in (ROOT / "src" / group).glob("*.luau"):
        name = file.name.removesuffix(".luau").removesuffix(".server").removesuffix(".client")
        path = prefix + "/" + name
        cls = "Script" if ".server." in file.name else ("LocalScript" if ".client." in file.name else "ModuleScript")
        expected[path] = (file, cls)
for path, (file, cls) in expected.items():
    assert path in paths, f"Missing {path}"
    obj = paths[path]
    assert obj.attrib["class"] == cls, f"Wrong script type: {path}"
    source = next(p.text or "" for p in obj.find("Properties") if p.attrib["name"] == "Source")
    assert source == file.read_text(), f"Changed source: {path}"
    assert len(source.encode()) < 100_000, f"Oversized module: {path}"

for name in ("StarterCharacter", "Dummy", "Enemy", "Golem"):
    path = ROOT / "assets" / f"{name}.rbxmx"
    root = ET.parse(path).getroot()
    refs = {obj.attrib["referent"]: obj for obj in root.iter("Item")}
    motors = [obj for obj in refs.values() if obj.attrib["class"] == "Motor6D"]
    assert len(motors) == 15
    for motor in motors:
        for prop in ("Part0", "Part1"):
            assert motor.findtext(f"Properties/Ref[@name='{prop}']") in refs
        # Validate world-space bind points on both sides of each Motor6D.
        worlds = []
        for n in (0, 1):
            body = refs[motor.findtext(f"Properties/Ref[@name='Part{n}']")]
            p = body.find("Properties/CoordinateFrame[@name='CFrame']")
            c = motor.find(f"Properties/CoordinateFrame[@name='C{n}']")
            worlds.append([float(p.findtext(axis)) + float(c.findtext(axis)) for axis in ("X", "Y", "Z")])
        assert all(abs(a - b) < 1e-5 for a, b in zip(*worlds)), "Disconnected bind pose"
    humanoid = next(obj for obj in refs.values() if obj.attrib["class"] == "Humanoid")
    assert humanoid.findtext("Properties/token[@name='RigType']") == "1"

art = ROOT / "assets" / "magic"
models = list(art.glob("*.rbxmx"))
assert len(models) == 43, "Missing art template"
for file in models:
    root = ET.parse(file).getroot()
    items = list(root.iter("Item"))
    refs = {obj.attrib["referent"]: obj for obj in items}
    assert len(refs) == len(items), f"Duplicate reference: {file}"
    model = root.find("Item")
    assert model.attrib["class"] == "Model"
    assert model.findtext("Properties/Ref[@name='PrimaryPart']") in refs
    assert not any(obj.attrib["class"] in ("Script", "LocalScript", "ModuleScript") for obj in items), f"Unexpected executable art: {file}"
    assert (ROOT / "meshes" / (file.stem + ".obj")).is_file()
    assert (ROOT / "meshes" / (file.stem + ".mtl")).is_file()
    assert f"/ReplicatedStorage/BlackClover/ArtTemplates/{file.stem}" in paths
assert paths["/ReplicatedStorage/BlackClover/Remotes/MagicFX"].attrib["class"] == "RemoteEvent"
print(f"PASS: XML v4; {len(expected)} exact script sources; four connected R15 rigs; 43 script-free art models + OBJ/MTL sources; {PLACE.stat().st_size:,} bytes")
