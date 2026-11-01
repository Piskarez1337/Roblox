"""Build original, offline Roblox models. No external meshes or asset IDs."""
from pathlib import Path
import math
import random
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
ASSETS.mkdir(exist_ok=True)
random.seed(231)
counter = 0


def item(parent, cls, name):
    global counter
    counter += 1
    obj = ET.SubElement(parent, "Item", {"class": cls, "referent": f"RBX{counter}"})
    ET.SubElement(obj, "Properties")
    prop(obj, "string", "Name", name)
    return obj


def prop(obj, typ, name, value):
    node = ET.SubElement(obj.find("Properties"), typ, {"name": name})
    if typ == "Vector3":
        for key, v in zip(("X", "Y", "Z"), value):
            ET.SubElement(node, key).text = f"{v:.7g}"
    elif typ == "Color3":
        for key, v in zip(("R", "G", "B"), value):
            ET.SubElement(node, key).text = f"{v / 255:.7g}"
    elif typ == "CoordinateFrame":
        position, matrix = value
        for key, v in zip(("X", "Y", "Z"), position):
            ET.SubElement(node, key).text = f"{v:.7g}"
        for i in range(3):
            for j in range(3):
                ET.SubElement(node, f"R{i}{j}").text = f"{matrix[i][j]:.7g}"
    else:
        node.text = str(value).lower() if isinstance(value, bool) else str(value)
    return node


IDENTITY = ((1, 0, 0), (0, 1, 0), (0, 0, 1))


def rotation(x=0, y=0, z=0):
    sx, cx, sy, cy, sz, cz = math.sin(x), math.cos(x), math.sin(y), math.cos(y), math.sin(z), math.cos(z)
    return ((cy * cz, -cy * sz, sy), (cx * sz + sx * sy * cz, cx * cz - sx * sy * sz, -sx * cy),
            (sx * sz - cx * sy * cz, sx * cz + cx * sy * sz, cx * cy))


def part(parent, name, pos, size, color, material=272, matrix=IDENTITY, shape=None,
         cls="Part", anchored=True, collide=True, transparency=0):
    obj = item(parent, cls, name)
    prop(obj, "CoordinateFrame", "CFrame", (pos, matrix))
    prop(obj, "Vector3", "size", size)
    prop(obj, "Color3", "Color", color)
    prop(obj, "token", "Material", material)
    prop(obj, "bool", "Anchored", anchored)
    prop(obj, "bool", "CanCollide", collide)
    prop(obj, "bool", "CanTouch", False)
    prop(obj, "bool", "CanQuery", collide)
    prop(obj, "bool", "CastShadow", transparency < 0.5)
    prop(obj, "float", "Transparency", transparency)
    prop(obj, "token", "TopSurface", 0)
    prop(obj, "token", "BottomSurface", 0)
    if shape is not None:
        prop(obj, "token", "shape", shape)
    return obj


def document():
    root = ET.Element("roblox", {"version": "4"})
    ET.SubElement(root, "External").text = "null"
    ET.SubElement(root, "External").text = "nil"
    return root


def save(root, name):
    ET.indent(root)
    ET.ElementTree(root).write(ASSETS / name, encoding="utf-8", xml_declaration=True)


def weld(parent, a, b):
    joint = item(parent, "WeldConstraint", "DetailWeld")
    prop(joint, "Ref", "Part0", a.attrib["referent"])
    prop(joint, "Ref", "Part1", b.attrib["referent"])


def rig(filename, name, kind):
    doc = document()
    model = item(doc, "Model", name)
    navy, skin, trim = (36, 54, 65), (226, 188, 151), (211, 175, 106)
    if kind == "Dummy":
        navy, skin, trim = (108, 87, 63), (174, 144, 98), (231, 201, 141)
    if kind == "Enemy":
        navy, skin, trim = (70, 88, 94), (113, 130, 134), (226, 125, 91)
    definitions = {
        "HumanoidRootPart": ((0, 3, 0), (2, 2, 1), navy),
        "LowerTorso": ((0, 3, 0), (1.8, .8, 1), navy),
        "UpperTorso": ((0, 4.05, 0), (2, 1.3, 1), navy),
        "Head": ((0, 5.25, 0), (1.45, 1.15, 1.15), skin),
        "RightUpperArm": ((1.5, 4.0, 0), (.9, 1.3, .9), navy),
        "RightLowerArm": ((1.5, 2.85, 0), (.8, 1, .8), skin),
        "RightHand": ((1.5, 2.1, 0), (.8, .5, .8), skin),
        "LeftUpperArm": ((-1.5, 4.0, 0), (.9, 1.3, .9), navy),
        "LeftLowerArm": ((-1.5, 2.85, 0), (.8, 1, .8), skin),
        "LeftHand": ((-1.5, 2.1, 0), (.8, .5, .8), skin),
        "RightUpperLeg": ((.48, 2.1, 0), (.85, 1.1, .85), navy),
        "RightLowerLeg": ((.48, 1.0, 0), (.8, 1.1, .8), navy),
        "RightFoot": ((.48, .25, -.12), (.85, .5, 1.15), (36, 41, 45)),
        "LeftUpperLeg": ((-.48, 2.1, 0), (.85, 1.1, .85), navy),
        "LeftLowerLeg": ((-.48, 1.0, 0), (.8, 1.1, .8), navy),
        "LeftFoot": ((-.48, .25, -.12), (.85, .5, 1.15), (36, 41, 45)),
    }
    parts = {}
    for pname, (position, size, color) in definitions.items():
        p = part(model, pname, position, size, color, anchored=False,
                 collide=pname in ("UpperTorso", "LowerTorso", "Head"), transparency=1 if pname == "HumanoidRootPart" else 0)
        prop(p, "bool", "Massless", pname != "HumanoidRootPart")
        # Limbs must remain visible to authoritative spatial queries.
        p.find("Properties/bool[@name='CanQuery']").text = "true"
        parts[pname] = p
    mesh = item(parts["Head"], "SpecialMesh", "HeadMesh")
    prop(mesh, "token", "MeshType", 0)
    prop(mesh, "Vector3", "Scale", (1, 1, 1))
    joints = [
        ("Root", "HumanoidRootPart", "LowerTorso", (0, 3, 0)),
        ("Waist", "LowerTorso", "UpperTorso", (0, 3.4, 0)),
        ("Neck", "UpperTorso", "Head", (0, 4.7, 0)),
    ]
    for side, sign in (("Right", 1), ("Left", -1)):
        joints += [
            (side + "Shoulder", "UpperTorso", side + "UpperArm", (sign * 1.0, 4.55, 0)),
            (side + "Elbow", side + "UpperArm", side + "LowerArm", (sign * 1.5, 3.35, 0)),
            (side + "Wrist", side + "LowerArm", side + "Hand", (sign * 1.5, 2.35, 0)),
            (side + "Hip", "LowerTorso", side + "UpperLeg", (sign * .48, 2.65, 0)),
            (side + "Knee", side + "UpperLeg", side + "LowerLeg", (sign * .48, 1.55, 0)),
            (side + "Ankle", side + "LowerLeg", side + "Foot", (sign * .48, .45, 0)),
        ]
    for jname, pname0, pname1, joint_pos in joints:
        joint = item(parts[pname1], "Motor6D", jname)
        for n, pname in enumerate((pname0, pname1)):
            prop(joint, "Ref", f"Part{n}", parts[pname].attrib["referent"])
            relative = tuple(a - b for a, b in zip(joint_pos, definitions[pname][0]))
            prop(joint, "CoordinateFrame", f"C{n}", (relative, IDENTITY))
            attachment = item(parts[pname], "Attachment", jname + "RigAttachment")
            prop(attachment, "CoordinateFrame", "CFrame", (relative, IDENTITY))
    humanoid = item(model, "Humanoid", "Humanoid")
    prop(humanoid, "token", "RigType", 1)
    prop(humanoid, "float", "HipHeight", 2)
    prop(humanoid, "float", "MaxHealth", 120)
    prop(humanoid, "float", "Health", 120)
    prop(humanoid, "bool", "AutomaticScalingEnabled", False)
    prop(humanoid, "bool", "BreakJointsOnDeath", False)
    prop(humanoid, "float", "NameDisplayDistance", 35)
    prop(humanoid, "float", "HealthDisplayDistance", 55)
    prop(humanoid, "string", "DisplayName", "Ученик" if kind == "Player" else ("Манекен" if kind == "Dummy" else "Часовой"))
    item(humanoid, "Animator", "Animator")
    prop(model, "Ref", "PrimaryPart", parts["HumanoidRootPart"].attrib["referent"])

    def detail(pname, dname, position, size, color, shape=None, matrix=IDENTITY, cls="Part"):
        obj = part(model, dname, position, size, color, anchored=False, collide=False, shape=shape, matrix=matrix, cls=cls)
        prop(obj, "bool", "Massless", True)
        weld(obj, parts[pname], obj)
        return obj

    detail("LowerTorso", "WovenBelt", (0, 3.18, -.53), (1.88, .22, .1), trim)
    detail("UpperTorso", "LapelLeft", (-.3, 4.2, -.54), (.12, 1.0, .08), trim, matrix=rotation(z=-.28))
    detail("UpperTorso", "LapelRight", (.3, 4.2, -.54), (.12, 1.0, .08), trim, matrix=rotation(z=.28))
    for dx, dy in ((-.08, 0), (.08, 0), (0, .09), (0, -.09)):
        detail("UpperTorso", "CloverPin", (.57 + dx, 4.38 + dy, -.58), (.14, .14, .055), trim, 0)
    for side, sign in (("Right", 1), ("Left", -1)):
        detail(side + "LowerArm", "WristWrap", (sign * 1.5, 2.5, 0), (.85, .22, .85), trim)
        detail(side + "UpperArm", "ShoulderTrim", (sign * 1.5, 4.5, 0), (.94, .16, .94), trim)
        detail("Head", "Eye", (sign * .28, 5.28, -.565), (.2, .19, .055), (20, 35, 39), 0)
        detail("Head", "Iris", (sign * .28, 5.28, -.6), (.08, .13, .035), trim, 0)
        detail("Head", "Brow", (sign * .28, 5.48, -.55), (.28, .065, .06), (40, 39, 37), matrix=rotation(z=sign * -.15))
    detail("Head", "Mouth", (0, 4.99, -.57), (.19, .035, .03), (93, 66, 61))
    if kind == "Player":
        detail("Head", "HairCrown", (0, 5.76, .03), (1.52, .35, 1.2), (206, 214, 203), 0)
        for i in range(7):
            detail("Head", "HairLock", ((i - 3) * .19, 5.65, -.45), (.27, .55 + (i % 2) * .15, .3),
                   (206, 214, 203), matrix=rotation(y=math.pi, z=(i - 3) * -.12), cls="WedgePart")
    save(doc, filename)


def scene():
    doc = document()
    model = item(doc, "Model", "TrainingGround")
    stone, light, gold, mint = (74, 91, 92), (148, 159, 151), (194, 164, 104), (91, 211, 186)
    part(model, "Meadow", (0, -2.5, 0), (420, 3, 420), (71, 102, 81), 1280)
    part(model, "ArenaFoundation", (0, -.15, 0), (2, 116, 116), stone, 800, rotation(z=math.pi / 2), 2)
    part(model, "Courtyard", (0, .9, 0), (.2, 110, 110), light, 816, rotation(z=math.pi / 2), 2)

    def ring(radius, y, color, thickness=.13, pieces=96, material=1088):
        for n in range(pieces):
            a = (n + .5) * math.tau / pieces
            length = 2 * radius * math.sin(math.pi / pieces) * 1.015
            part(model, "InlaidRing", (math.cos(a) * radius, y, math.sin(a) * radius), (length, .035, thickness),
                 color, material, rotation(y=-a - math.pi / 2), collide=False)

    ring(53.4, 1.025, gold, .23)
    ring(48.2, 1.03, stone, .14)
    ring(22, 1.035, gold, .17)
    ring(21.2, 1.035, stone, .09)
    ring(7, 1.04, gold, .2, 64)
    for r, count in ((31, 40), (41, 52), (51, 64)):
        for n in range(count):
            a = n * math.tau / count
            shade = tuple(v + random.randint(-8, 8) for v in light)
            part(model, "CutFlagstone", (r * math.cos(a), 1.008, r * math.sin(a)), (3.9, .018, 6.4),
                 shade, 816, rotation(y=-a), collide=False)
    for x, z in ((-2, -2), (2, -2), (-2, 2), (2, 2)):
        part(model, "CloverInlay", (x, 1.05, z), (.025, 5.2, 5.2), stone, 784, rotation(z=math.pi / 2), 2, collide=False)
    part(model, "CloverStem", (0, 1.05, 4.6), (.6, .025, 3.5), stone, 784, rotation(y=.3), collide=False)

    for n in range(16):
        a = n * math.tau / 16
        x, z = 58 * math.cos(a), 58 * math.sin(a)
        if abs(x) < 12:
            continue
        part(model, "ColumnFoot", (x, 1.6, z), (4.5, 1.2, 4.5), stone, 800)
        part(model, "ColumnBase", (x, 2.4, z), (3.3, .5, 3.3), gold, 816)
        part(model, "FlutedColumn", (x, 7, z), (8.8, 2.5, 2.5), light, 784, rotation(z=math.pi / 2), 2)
        part(model, "ColumnCapital", (x, 11.6, z), (3.6, .7, 3.6), stone, 800)
        part(model, "ColumnCrown", (x, 12.2, z), (4.3, .5, 4.3), gold, 816)
        for angle in (0, math.pi / 2, math.pi, math.pi * 1.5):
            part(model, "Flute", (x + math.sin(angle) * 1.24, 7, z + math.cos(angle) * 1.24), (.12, 8.1, .12),
                 stone, 800, collide=False)
        if n % 2 == 0:
            flame = part(model, "Lantern", (x, 13.1, z), (.65, 1.3, .65), mint, 288, shape=0, collide=False)
            lamp = item(flame, "PointLight", "LanternGlow")
            prop(lamp, "Color3", "Color", mint)
            prop(lamp, "float", "Brightness", 1.5)
            prop(lamp, "float", "Range", 19)

    def arch(z, color):
        for x in (-9, 9):
            part(model, "GatePillar", (x, 5, z), (3, 8, 3), stone, 800)
            part(model, "GatePlinth", (x, 1.5, z), (4.5, 1, 4.5), gold, 816)
            part(model, "GateCap", (x, 9.4, z), (4, .8, 4), gold, 816)
            banner = part(model, "Banner", (x * .73, 6.2, z - .3), (2, 4.5, .12), color, 272, collide=False)
            part(model, "BannerHem", (x * .73, 4, z - .37), (2, .2, .06), gold, collide=False)
            part(model, "BannerSigil", (x * .73, 6.4, z - .4), (1, 1, .08), gold, matrix=rotation(z=math.pi / 4), collide=False)
        for i in range(17):
            a = i * math.pi / 16
            part(model, "ArchVoussoir", (9 * math.cos(a), 9 + 9 * math.sin(a), z), (1.8, 2, 3),
                 light if i % 2 else stone, 800, rotation(z=a + math.pi / 2))
        part(model, "Keystone", (0, 18.6, z - .2), (2.2, 2.6, 3.4), gold, 816)

    arch(54, (48, 105, 97))
    arch(-54, (97, 62, 62))
    for side in (-1, 1):
        for step in range(3):
            part(model, "GateStep", (0, .65 - step * .5, side * (59 + step * 2)), (17, .7, 2.4), light, 816)

    spawn = part(model, "Spawn", (0, 1.1, 41), (6, .2, 6), mint, 784, cls="SpawnLocation", transparency=1, collide=False)
    prop(spawn, "bool", "Neutral", True)
    prop(spawn, "float", "Duration", 2)
    # This spawn is physically supported by Courtyard; its marker is an inlaid rosette.
    for a in range(8):
        t = a * math.tau / 8
        part(model, "ArrivalRosette", (math.cos(t) * 3, 1.06, 41 + math.sin(t) * 3), (1.1, .03, 1.1), gold,
             matrix=rotation(y=t), collide=False)

    fx, fz = 17, 40
    part(model, "FountainBase", (fx, 1.4, fz), (.8, 7, 7), stone, 800, rotation(z=math.pi / 2), 2)
    part(model, "FountainBasin", (fx, 2.1, fz), (.8, 5.3, 5.3), light, 784, rotation(z=math.pi / 2), 2)
    water = part(model, "RecoverySource", (fx, 2.54, fz), (.05, 4.6, 4.6), mint, 288, rotation(z=math.pi / 2), 2, collide=False)
    prompt = item(water, "ProximityPrompt", "RecoveryPrompt")
    prop(prompt, "string", "ActionText", "Восстановить HP и ману")
    prop(prompt, "string", "ObjectText", "Источник клевера")
    prop(prompt, "float", "HoldDuration", .35)
    prop(prompt, "float", "MaxActivationDistance", 10)
    prop(prompt, "bool", "RequiresLineOfSight", False)
    part(model, "SourceCrystal", (fx, 4, fz), (1.1, 2.7, 1.1), mint, 288, rotation(z=.4), cls="WedgePart", collide=False)

    for x, z, color in ((-11, 0, gold), (11, 0, gold), (-24, -27, (180, 111, 92)), (24, -27, (180, 111, 92))):
        part(model, "TrainingMark", (x, 1.065, z), (.04, 8, 8), stone, 800, rotation(z=math.pi / 2), 2, collide=False)
        for i in range(8):
            a = i * math.tau / 8
            part(model, "TrainingMarkTrim", (x + 4 * math.cos(a), 1.09, z + 4 * math.sin(a)), (1.5, .03, .13),
                 color, matrix=rotation(y=-a - math.pi / 2), collide=False)

    # Background cliffs, layered boulders and stylized trees use original geometry.
    for n in range(34):
        a = n * math.tau / 34
        radius = random.uniform(92, 160)
        x, z = math.cos(a) * radius, math.sin(a) * radius
        h = random.uniform(18, 42)
        part(model, "DistantCliff", (x, h / 2 - 1, z), (random.uniform(24, 42), h, random.uniform(23, 39)),
             (77, 100, 100), 800, rotation(y=a), cls="WedgePart")
    for n in range(18):
        a = n * math.tau / 18 + .12
        x, z = math.cos(a) * 77, math.sin(a) * 77
        if abs(x) < 12:
            continue
        h = random.uniform(11, 16)
        part(model, "TreeTrunk", (x, h / 2 - 1, z), (h, 1.1, 1.1), (72, 71, 57), 512, rotation(z=math.pi / 2), 2)
        for dy, radius in ((0, 10), (3.5, 8), (6.4, 5)):
            part(model, "TreeCanopy", (x, h + dy, z), (radius, 6, radius), (60 + n % 3 * 8, 99 + n % 4 * 6, 75),
                 1280, shape=0, collide=False)
    save(doc, "TrainingGround.rbxmx")


if __name__ == "__main__":
    rig("StarterCharacter.rbxmx", "StarterCharacter", "Player")
    rig("Dummy.rbxmx", "Dummy", "Dummy")
    rig("Enemy.rbxmx", "Enemy", "Enemy")
    scene()
    print(f"Built four original models in {ASSETS}")
