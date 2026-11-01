--!nonstrict
-- Bone Demon v2: visible R15 awakening with no externally uploaded MeshIds.
-- Each item uses body-local coordinates; the caller attaches it with MagicArt.
local G = require(script.Parent.MagicGeometry)
local Bone = {}

local IVORY = Color3.fromRGB(227, 219, 211)
local EDGE = Color3.fromRGB(164, 155, 163)
local SHADOW = Color3.fromRGB(74, 69, 82)
local BLACK = Color3.fromRGB(15, 14, 22)
local FUR = Color3.fromRGB(26, 24, 36)
local MEMBRANE = Color3.fromRGB(24, 22, 33)
local MEMBRANE_EDGE = Color3.fromRGB(32, 29, 41)
local RED = Color3.fromRGB(255, 28, 56)
local GLOW = Color3.fromRGB(255, 229, 236)

local function part(model, name, pos, size, color, material, shape, alpha, orientation)
    local cf = (typeof(pos) == "CFrame" and pos or CFrame.new(pos)) * (orientation or CFrame.identity)
    local p = G.Part(model, name, size, cf, color, material or Enum.Material.SmoothPlastic, shape)
    p.Transparency = alpha or 0
    p.CastShadow = true
    return p
end

local function rod(model, name, a, b, radius, color, material)
    local axis = b - a
    if axis.Magnitude < .04 then return end
    local x = axis.Unit
    local helper = math.abs(x:Dot(Vector3.yAxis)) < .92 and Vector3.yAxis or Vector3.zAxis
    local y = (helper - x * x:Dot(helper)).Unit
    local frame = CFrame.fromMatrix((a + b) * .5, x, y, x:Cross(y))
    return part(model, name, frame, Vector3.new(axis.Magnitude, radius * 2, radius * 2),
        color, material or Enum.Material.SmoothPlastic, "Cylinder")
end

local function chain(model, name, positions, startRadius, color, joints)
    local count = #positions - 1
    for i = 1, count do
        local radius = startRadius * (1 - (i - 1) / math.max(1, count) * .64)
        rod(model, name .. i, positions[i], positions[i + 1], radius, color)
        if joints and i < count then
            part(model, name .. "Knuckle" .. i, positions[i + 1],
                Vector3.one * radius * 2.15, color, nil, "Ball")
        end
    end
end

-- Fill actual wing surfaces. Each arbitrary 3D triangle is split into two
-- triangular WedgeParts rather than a floating rectangular slab.
local function triangle(model, name, a, b, c, color)
    local ab, bc, ca = (b - a).Magnitude, (c - b).Magnitude, (a - c).Magnitude
    if bc > ab and bc >= ca then
        a, b, c = b, c, a
    elseif ca > ab and ca > bc then
        a, b, c = c, a, b
    end
    local edge = b - a
    if edge.Magnitude < .02 then return end
    local dir = edge.Unit
    local foot = a + dir * (c - a):Dot(dir)
    local altitude = c - foot
    if altitude.Magnitude < .025 then return end
    local up = altitude.Unit
    for index, endpoint in { a, b } do
        local flat = endpoint - foot
        if flat.Magnitude > .02 then
            local z = flat.Unit
            local x = up:Cross(z)
            if x.Magnitude > .05 then
                local center = foot + altitude * .5 + flat * .5
                local cf = CFrame.fromMatrix(center, x.Unit, up, z)
                part(model, name .. index, cf, Vector3.new(.085, altitude.Magnitude, flat.Magnitude),
                    color, Enum.Material.SmoothPlastic, "Wedge")
            end
        end
    end
end

local function feather(model, name, x, y, z, size, tilt, color)
    return part(model, name, Vector3.new(x, y, z),
        Vector3.new(size * .48, size, .22),
        color or FUR, Enum.Material.Slate, "Wedge", 0,
        CFrame.Angles(0, 0, tilt))
end

local function wing(side)
    local m = G.Model("BoneWing" .. (side < 0 and "Left" or "Right"))
    local function v(x, y, z) return Vector3.new(x * side, y, z) end
    local shoulder = v(0, .05, 0)
    local elbow = v(1.75, 1.42, .16)
    local wrist = v(4.30, 2.40, .39)
    local tip = v(7.20, 2.95, .65)
    local tips = {
        v(6.75, .66, .93),
        v(5.50, -.78, 1.04),
        v(4.02, -1.77, .94),
        v(2.35, -2.45, .60),
        v(.53, -1.03, .29),
    }
    -- Wide black bat membranes and scalloped edges (not a wireframe).
    triangle(m, "InnerSailA", shoulder, elbow, tips[5], MEMBRANE)
    triangle(m, "InnerSailB", elbow, tips[4], tips[5], MEMBRANE)
    triangle(m, "MainSailA", elbow, wrist, tips[4], MEMBRANE)
    triangle(m, "MainSailB", wrist, tips[3], tips[4], MEMBRANE)
    triangle(m, "MainSailC", wrist, tips[2], tips[3], MEMBRANE)
    triangle(m, "MainSailD", wrist, tips[1], tips[2], MEMBRANE)
    triangle(m, "OuterSail", wrist, tip, tips[1], MEMBRANE)
    -- Thin shadow panels on the back create dark depth and natural folds.
    triangle(m, "FoldA", elbow + v(0, .03, .07), wrist + v(0, .03, .07),
        tips[3] + v(0, 0, .12), MEMBRANE_EDGE)
    chain(m, "Humerus", { shoulder, elbow, wrist, tip }, .19, IVORY, true)
    for i, endpoint in tips do
        local anchor = i < 3 and wrist or elbow
        local mid = anchor:Lerp(endpoint, .51) + v(.12, .16, .16)
        chain(m, "WingFinger" .. i, { anchor, mid, endpoint }, .105, EDGE, i < 3)
        chain(m, "Scallop" .. i, { endpoint, endpoint + v(.18, -.25, .03) }, .07, IVORY)
    end
    chain(m, "TopClaw", { tip, tip + v(.40, .52, 0), tip + v(.14, .85, -.12) }, .11, IVORY)
    chain(m, "JointClaw", { elbow, elbow + v(.23, .57, -.04), elbow + v(.09, .92, -.12) }, .12, IVORY)
    -- Bone ridges along the strong outer edge of each sail.
    chain(m, "OuterEdge", { tip, tips[1] }, .09, EDGE)
    for i = 1, 4 do
        chain(m, "TornEdge" .. i, { tips[i], tips[i + 1] }, .065, SHADOW)
    end
    return m
end

local function head()
    local m = G.Model("BoneArmorHead")
    part(m, "BlackCrown", Vector3.new(0, .28, .13),
        Vector3.new(1.29, .81, 1.22), BLACK, Enum.Material.Slate, "Ball")
    part(m, "FacePlate", Vector3.new(0, -.27, -.62),
        Vector3.new(1.18, .60, .16), SHADOW)
    -- Eleven downward ivory lines form the vertical bone veil.
    for i = -5, 5 do
        local x = i * .105
        local length = .52 + .14 * (1 - math.abs(i) / 6)
        part(m, "MaskFang" .. i, Vector3.new(x, -.28, -.754),
            Vector3.new(.065, length, .09), i % 3 == 0 and EDGE or IVORY,
            Enum.Material.SmoothPlastic)
    end
    for sign = -1, 1, 2 do
        local function v(x, y, z) return Vector3.new(x * sign, y, z) end
        -- Split vivid scarlet eyes and inner pupil illuminate the mask.
        part(m, "EyeSocket", v(.31, .13, -.69),
            Vector3.new(.40, .16, .12), BLACK)
        part(m, "RedEye", v(.31, .13, -.77),
            Vector3.new(.29, .10, .10), RED, Enum.Material.Neon, "Ball")
        part(m, "WhiteEyeFlash", v(.25, .15, -.84),
            Vector3.new(.064, .035, .036), GLOW, Enum.Material.Neon, "Ball")
        -- Two long curling antlers, two upright prongs and swept side horns.
        chain(m, "Antler" .. sign, {
            v(.43, .42, .18), v(.75, .86, .15), v(1.23, 1.35, .10),
            v(1.75, 1.49, .02), v(2.07, 1.40, -.06), v(2.24, 1.75, -.16),
        }, .145, IVORY, true)
        chain(m, "CrownHorn" .. sign, {
            v(.25, .41, .12), v(.22, .98, .06),
            v(.30, 1.56, -.02), v(.54, 1.81, -.09),
        }, .13, EDGE, true)
        chain(m, "TempleHorn" .. sign, {
            v(.53, .18, .03), v(.98, .42, .06),
            v(1.28, .80, .09), v(1.26, 1.06, .02),
        }, .115, IVORY)
        feather(m, "Forelock" .. sign, sign * .35, .48, -.53, .55, sign * -.38, BLACK)
        feather(m, "SideHair" .. sign, sign * .64, -.28, .02, .81, sign * .22, FUR)
    end
    for i = -2, 2 do
        feather(m, "DarkHair" .. i, i * .20, .71, -.20,
            .64 + (2 - math.abs(i)) * .09, i * -.18, FUR)
    end
    return m
end

local function torso()
    local m = G.Model("BoneArmorUpperTorso")
    part(m, "Undersuit", Vector3.new(0, 0, -.55),
        Vector3.new(1.95, 1.55, .12), BLACK, Enum.Material.Slate)
    -- Front-facing rib cage and scapulae.
    for i = 1, 7 do
        local y = .58 - (i - 1) * .195
        for sign = -1, 1, 2 do
            local function v(x, yy, z) return Vector3.new(x * sign, yy, z) end
            chain(m, "ChestRib" .. i .. "S" .. sign, {
                v(.105, y, -.675),
                v(.38, y - .03, -.81),
                v(.72 + i * .022, y - .12, -.80),
                v(.96, y - .18, -.47),
            }, .065 + (7 - i) * .004, i % 3 == 0 and EDGE or IVORY)
        end
    end
    for sign = -1, 1, 2 do
        local function v(x, y, z) return Vector3.new(x * sign, y, z) end
        chain(m, "Collar" .. sign, {
            v(.02, .74, -.76), v(.62, .78, -.66),
            v(.99, .64, -.39), v(1.24, .77, -.14),
        }, .127, IVORY, true)
        chain(m, "ShoulderArmor" .. sign, {
            v(.56, .53, -.32), v(.93, .73, .01),
            v(1.30, .58, .25), v(1.56, .36, .25),
        }, .16, EDGE, true)
        for i = 1, 3 do
            feather(m, "BackFur" .. sign .. "_" .. i,
                sign * (1.01 + i * .12), .38 - i * .31, .43,
                .56 + i * .17, sign * -.18, FUR)
        end
    end
    -- Prominent white moon-like core in the sternum.
    part(m, "CoreSocket", Vector3.new(0, .27, -.83),
        Vector3.new(.41, .41, .15), SHADOW, Enum.Material.Slate, "Ball")
    part(m, "BoneHeart", Vector3.new(0, .28, -.94),
        Vector3.new(.22, .22, .085), GLOW, Enum.Material.Neon, "Ball")
    -- Vertebrae and dorsal spine must be BEHIND the torso, never in front.
    for i = 0, 8 do
        local y = .67 - i * .19
        part(m, "BackVertebra" .. i,
            Vector3.new(0, y, .67),
            Vector3.new(.27 - i * .009, .16, .19), IVORY, nil, "Ball")
        if i < 6 then
            chain(m, "DorsalFin" .. i, {
                Vector3.new(0, y, .67), Vector3.new(0, y - .09, .95),
                Vector3.new(0, y - .22, 1.08),
            }, .075, EDGE)
        end
    end
    return m
end

local function hips()
    local m = G.Model("BoneArmorLowerTorso")
    part(m, "Waistband", Vector3.new(0, .31, -.54),
        Vector3.new(1.70, .31, .18), SHADOW)
    for sign = -1, 1, 2 do
        for i = 1, 4 do
            local x = sign * (.17 + (i - 1) * .24)
            feather(m, "SkirtFeather" .. sign .. "_" .. i,
                x, -.50 - (i % 2) * .16, -.43,
                1.04 + (i % 3) * .22, sign * .11, FUR)
        end
        chain(m, "PelvisRidge" .. sign, {
            Vector3.new(sign * .18, .34, -.69),
            Vector3.new(sign * .62, .15, -.71),
            Vector3.new(sign * .86, -.23, -.60),
            Vector3.new(sign * .70, -.72, -.66),
        }, .115, IVORY, true)
        for i = 1, 3 do
            chain(m, "HipFang" .. sign .. i, {
                Vector3.new(sign * (.53 + i * .13), -.10 - i * .12, -.60),
                Vector3.new(sign * (.56 + i * .12), -.37 - i * .17, -.66),
            }, .083, EDGE)
        end
    end
    for i = -2, 2 do
        feather(m, "BackSkirt" .. i,
            i * .26, -.53 - math.abs(i) * .07, .51, 1.05, i * .10, BLACK)
    end
    return m
end

local function arm(side)
    local name = side < 0 and "LeftUpperArm" or "RightUpperArm"
    local m = G.Model("BoneArmor" .. name)
    part(m, "DarkArmWrap", Vector3.new(0, .05, -.39),
        Vector3.new(.96, 1.19, .22), BLACK, Enum.Material.Slate)
    for i = 1, 4 do
        local y = .43 - (i - 1) * .30
        chain(m, "ArmRidge" .. i, {
            Vector3.new(-.36, y, -.52),
            Vector3.new(0, y - .09, -.60),
            Vector3.new(.38, y - .14, -.38),
        }, .09, i % 2 == 0 and EDGE or IVORY)
    end
    chain(m, "ShoulderTusk", {
        Vector3.new(side * .22, .34, .08),
        Vector3.new(side * .65, .63, .10),
        Vector3.new(side * .92, 1.02, .10),
        Vector3.new(side * 1.03, 1.21, .02),
    }, .16, IVORY, true)
    -- Layered black jagged fur surrounding the forearm.
    for i = 1, 7 do
        local angle = i * math.pi * 2 / 7
        local x, z = math.cos(angle) * .51, math.sin(angle) * .48
        feather(m, "Shag" .. i, x, -.31 + (i % 3) * .12, z,
            .68 + (i % 3) * .16, math.cos(angle) * .29, i % 2 == 0 and BLACK or FUR)
    end
    return m
end

local function shin(side)
    local name = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
    local m = G.Model("BoneArmor" .. name)
    part(m, "ShinShadow", Vector3.new(0, .04, -.40),
        Vector3.new(.77, 1.21, .14), BLACK, Enum.Material.Slate)
    chain(m, "ShinBlade", {
        Vector3.new(0, .58, -.53),
        Vector3.new(0, .20, -.62),
        Vector3.new(0, -.40, -.58),
        Vector3.new(0, -.70, -.48),
    }, .14, IVORY)
    for sign = -1, 1, 2 do
        chain(m, "CalfSpikes" .. sign, {
            Vector3.new(sign * .35, .42, -.31),
            Vector3.new(sign * .48, .14, -.40),
            Vector3.new(sign * .41, -.32, -.34),
        }, .09, EDGE)
    end
    return m
end

function Bone.Build(piece)
    if piece == "ArmorHead" then return head() end
    if piece == "ArmorUpperTorso" then return torso() end
    if piece == "ArmorLowerTorso" then return hips() end
    if piece == "ArmorLeftUpperArm" then return arm(-1) end
    if piece == "ArmorRightUpperArm" then return arm(1) end
    if piece == "ArmorLeftLowerLeg" then return shin(-1) end
    if piece == "ArmorRightLowerLeg" then return shin(1) end
    if piece == "WingLeft" then return wing(-1) end
    if piece == "WingRight" then return wing(1) end
    return nil
end

return Bone
