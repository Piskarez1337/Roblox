--!nonstrict
local Geometry = require(script.Parent.MagicGeometry)
local Art = require(script.Parent.MagicArt)
local Books = {}
local glyphs = { Water = "≈", Wind = "≋", Earth = "◇", Ice = "❄", Bone = "☽", Stars = "✦", Anti = "♣" }
function Books:Create(element, parent)
	local model = Geometry.Model(element .. "Grimoire")
	local color, accent = Art:Color(element), Art:Color(element, true)
	local root = model.PrimaryPart
	local coverColor = color:Lerp(Color3.fromRGB(15, 20, 30), .55)
	local entry = { Model = model, Open = 0, Hinges = {}, Page = nil }
	local glow = Instance.new("PointLight")
	glow.Color, glow.Brightness, glow.Range, glow.Shadows, glow.Parent = color, .35, 5, false, root
	local spine = Geometry.Part(model, "Spine", Vector3.new(.18, 1.6, .26), CFrame.identity, accent)
	spine.Anchored = false
	local spineWeld = Instance.new("WeldConstraint")
	spineWeld.Part0, spineWeld.Part1, spineWeld.Parent = root, spine, spine
	for _, sign in { -1, 1 } do
		local cover = Geometry.Part(model, "EmbossedCover", Vector3.new(1.15, 1.6, .1), CFrame.new(sign * .6, 0, sign * .08), coverColor)
		local page = Geometry.Part(model, "Pages", Vector3.new(1.05, 1.44, .08), cover.CFrame * CFrame.new(0, 0, -.08), Color3.fromRGB(228, 222, 194))
		local pieces = { page }
		local motifs = ({ Water = 3, Wind = 4, Earth = 2, Ice = 6, Bone = 5, Stars = 7, Anti = 1 })[element]
		for i = 1, motifs do
			local angle = i * math.pi * 2 / motifs
			local gem = Geometry.Part(model, "ElementSeal", Vector3.new(.075, .12, .04), cover.CFrame * CFrame.new(math.cos(angle) * .32, math.sin(angle) * .48, .09) * CFrame.Angles(0, 0, angle), color, Enum.Material.Neon, "Wedge")
			table.insert(pieces, gem)
		end
		for _, x in { -.45, .45 } do
			for _, y in { -.65, .65 } do
				table.insert(pieces, Geometry.Part(model, "CornerOrnament", Vector3.new(.2, .18, .05), cover.CFrame * CFrame.new(x, y, .08), accent, Enum.Material.Metal))
			end
		end
		for i = 1, 4 do table.insert(pieces, Geometry.Part(model, "PageEdge", Vector3.new(1.04, .012, .01), cover.CFrame * CFrame.new(0, -.48 + i * .21, -.13), Color3.fromRGB(148, 136, 111))) end
		local surface = Instance.new("SurfaceGui")
		surface.Face, surface.CanvasSize, surface.Parent = Enum.NormalId.Back, Vector2.new(180, 240), cover
		local label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		label.Text, label.Font, label.TextSize = glyphs[element], Enum.Font.GothamBold, 110
		label.TextColor3, label.Parent = accent, surface
		for _, part in pieces do
			part.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1, weld.Parent = cover, part, part
		end
		cover.Anchored = false
		local motor = Instance.new("Motor6D")
		motor.Part0, motor.Part1 = root, cover
		motor.C0, motor.C1 = CFrame.new(0, 0, sign * .08), CFrame.new(-sign * .6, 0, 0)
		motor.Parent = cover
		entry.Hinges[sign] = motor
	end
	local leaf = Geometry.Part(model, "TurningPage", Vector3.new(1.08, 1.44, .012), CFrame.new(.56, 0, -.12), Color3.fromRGB(248, 242, 216))
	leaf.Anchored = false
	local hinge = Instance.new("Motor6D")
	hinge.Part0, hinge.Part1 = root, leaf
	hinge.C0, hinge.C1 = CFrame.new(0, 0, -.14), CFrame.new(-.56, 0, 0)
	hinge.Parent, entry.Page = leaf, hinge
	if not Art:Track(model) then return nil end
	model.Parent = parent
	return entry
end
function Books:Step(entry, character, dt, now)
	local torso = character:FindFirstChild("UpperTorso")
	if not torso then return end
	local casting = character:GetAttribute("CastSpell") ~= "" and (character:GetAttribute("CastEnd") or 0) > now
	entry.Open += ((casting and 1 or 0) - entry.Open) * (1 - math.exp(-12 * dt))
	entry.Model.PrimaryPart.CFrame = torso.CFrame * CFrame.new(-2.5, .5 + math.sin(now * 2.2) * .15, .65) * CFrame.Angles(-.15, math.rad(155), -.12)
	entry.Hinges[-1].Transform = CFrame.Angles(0, math.rad(178 - entry.Open * 165), 0)
	entry.Hinges[1].Transform = CFrame.Angles(0, -entry.Open * .22, 0)
	entry.Page.Transform = CFrame.Angles(0, casting and (now * 7 % math.pi) or 0, 0)
	entry.Page.Part1.Transparency = casting and .1 or 1
end
return Books
