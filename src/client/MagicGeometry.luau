--!nonstrict
local Geometry = {}
function Geometry.Part(parent, name, size, cframe, color, material, shape)
	local part = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
	part.Name, part.Size, part.CFrame = name, size, cframe
	part.Color, part.Material = color, material or Enum.Material.SmoothPlastic
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
	if shape == "Ball" then part.Shape = Enum.PartType.Ball elseif shape == "Cylinder" then part.Shape = Enum.PartType.Cylinder end
	part.Parent = parent
	return part
end
function Geometry.Model(name)
	local model = Instance.new("Model")
	model.Name = name
	local root = Geometry.Part(model, "Root", Vector3.one * .1, CFrame.identity, Color3.new())
	root.Transparency = 1
	model.PrimaryPart = root
	return model
end
function Geometry.Rod(parent, a, b, radius, color, neon)
	local delta = b - a
	if delta.Magnitude < .01 then return nil end
	return Geometry.Part(parent, "Flow", Vector3.new(radius * 2, radius * 2, delta.Magnitude),
		CFrame.lookAt((a + b) / 2, b), color, neon and Enum.Material.Neon or Enum.Material.SmoothPlastic)
end
function Geometry.Ring(parent, radius, y, color, segments, thickness)
	segments = segments or 20
	for i = 1, segments do
		local a, b = i * math.pi * 2 / segments, (i + 1) * math.pi * 2 / segments
		Geometry.Rod(parent, Vector3.new(math.cos(a) * radius, y, math.sin(a) * radius),
			Vector3.new(math.cos(b) * radius, y, math.sin(b) * radius), thickness or .055, color, true)
	end
end
function Geometry.Circle(radius, color)
	local model = Geometry.Model("MagicCircle")
	Geometry.Ring(model, radius, 0, color, 20)
	Geometry.Ring(model, radius * .76, 0, color, 12, .035)
	for i = 1, 5 do
		local a, b = i * math.pi * 2 / 5, (i + 2) * math.pi * 2 / 5
		Geometry.Rod(model, Vector3.new(math.cos(a), 0, math.sin(a)) * radius * .65,
			Vector3.new(math.cos(b), 0, math.sin(b)) * radius * .65, .035, color, true)
	end
	return model
end
function Geometry.Crystal(parent, position, height, color)
	for i = 1, 4 do
		local part = Geometry.Part(parent, "Crystal", Vector3.new(height * .35, height, height * .35),
			CFrame.new(position) * CFrame.Angles(0, i * math.pi / 2, math.pi), color, Enum.Material.Glass, "Wedge")
		part.Transparency = .17
	end
end
function Geometry.Bone(parent, position, height, color)
	Geometry.Part(parent, "BoneShaft", Vector3.new(height, height * .14, height * .14),
		CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color, nil, "Cylinder")
	Geometry.Part(parent, "BoneJoint", Vector3.one * height * .23, CFrame.new(position - Vector3.new(0, height * .42, 0)), color, nil, "Ball")
	Geometry.Part(parent, "BoneTip", Vector3.new(height * .2, height * .4, height * .2),
		CFrame.new(position + Vector3.new(0, height * .5, 0)) * CFrame.Angles(0, 0, math.pi), color, nil, "Wedge")
end
function Geometry.Star(parent, position, size, color)
	for i = 1, 5 do
		Geometry.Part(parent, "StarRay", Vector3.new(size * .45, size, size * .15),
			CFrame.new(position) * CFrame.Angles(0, 0, i * math.pi * 2 / 5) * CFrame.new(0, size * .28, 0), color, Enum.Material.Neon, "Wedge")
	end
end
function Geometry.Arc(radius, color, dark)
	local model = Geometry.Model("CuttingArc")
	for i = 0, 11 do
		local a = -.5 * math.pi + i * math.pi / 12
		local b = -.5 * math.pi + (i + 1) * math.pi / 12
		local p = Vector3.new(math.sin(a) * radius, math.cos(a) * radius * .35, 0)
		local q = Vector3.new(math.sin(b) * radius, math.cos(b) * radius * .35, 0)
		Geometry.Rod(model, p, q, dark and .18 or .1, color, true)
		if dark then Geometry.Rod(model, p + Vector3.new(0, -.2, .15), q + Vector3.new(0, -.2, .15), .28, Color3.fromRGB(22, 13, 30), false) end
	end
	return model
end
function Geometry.Beam(parent, a, b, color, width)
	local pa = Geometry.Part(parent, "BeamEnd", Vector3.one * .1, CFrame.new(a), color)
	local pb = Geometry.Part(parent, "BeamEnd", Vector3.one * .1, CFrame.new(b), color)
	pa.Transparency, pb.Transparency = 1, 1
	local aa, ab = Instance.new("Attachment"), Instance.new("Attachment")
	aa.Parent, ab.Parent = pa, pb
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = aa, ab
	beam.Width0, beam.Width1, beam.FaceCamera = width or .1, width or .1, true
	beam.Color, beam.LightEmission = ColorSequence.new(color), .9
	beam.Parent = pa
	return beam
end
return Geometry
