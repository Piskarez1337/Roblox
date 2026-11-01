--!nonstrict
local package = game:GetService("ReplicatedStorage"):WaitForChild("BlackClover")
local Config = require(package.Shared.MagicConfig)
local Geometry = require(script.Parent.MagicGeometry)
local Art = { Parts = 0, TemplateCounts = {} }
function Art:Track(model)
	local count = 0
	for _, part in model:GetDescendants() do if part:IsA("BasePart") then count += 1 end end
	if self.Parts + count > Config.Limits.VFXParts then model:Destroy(); return nil end
	self.Parts += count
	model.Destroying:Connect(function() self.Parts -= count end)
	return model
end
function Art:Clone(name, scale)
	local originals = package:WaitForChild("ArtTemplates")
	local template = originals:FindFirstChild(name)
	if not template then return nil end
	local imported = package:WaitForChild("ArtMeshes"):FindFirstChild(name)
	if not imported then
		if not self.TemplateCounts[name] then
			local count = 0
			for _, part in template:GetDescendants() do if part:IsA("BasePart") then count += 1 end end
			self.TemplateCounts[name] = count
		end
		if self.Parts + self.TemplateCounts[name] > Config.Limits.VFXParts then return nil end
	end
	local model
	if imported and (imported:IsA("Model") or imported:IsA("BasePart")) then
		local geometry = imported:Clone()
		model = Geometry.Model(name)
		geometry.Parent = model
		if geometry:IsA("Model") then
			local expectedCF, expectedSize = template:GetBoundingBox()
			local _, actualSize = geometry:GetBoundingBox()
			geometry:ScaleTo(geometry:GetScale() * expectedSize.Magnitude / math.max(.01, actualSize.Magnitude))
			local actualCF = geometry:GetBoundingBox()
			geometry:PivotTo(CFrame.new(expectedCF.Position - actualCF.Position) * geometry:GetPivot())
		else
			local expectedCF, expectedSize = template:GetBoundingBox()
			geometry.Size, geometry.CFrame = expectedSize, expectedCF
		end
	else model = template:Clone() end
	for _, item in model:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("JointInstance") or item:IsA("Constraint") or item:IsA("Humanoid")
			or item:IsA("Sound") or item:IsA("ParticleEmitter") then item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery, item.Massless = true, false, false, false, true
		end
	end
	if scale and scale ~= 1 then model:ScaleTo(scale) end
	return self:Track(model)
end
function Art:Attach(model, body, offset, animated)
	if not model or not body then return nil end
	local root = model.PrimaryPart
	model:PivotTo(body.CFrame * offset)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored, part.Massless = false, true
			if part ~= root then
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1, weld.Parent = root, part, part
			end
		end
	end
	if animated then
		local motor = Instance.new("Motor6D")
		motor.Name = "MagicWingHinge"
		motor.Part0, motor.Part1, motor.C0 = body, root, offset
		motor.Parent = root
		return motor
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1, weld.Parent = body, root, root
	return weld
end
function Art:Color(element, accent)
	local data = Config.Classes[element] or Config.Classes.Water
	local c = accent and data.Accent or data.Color
	return Color3.fromRGB(c[1], c[2], c[3])
end
return Art
