--!nonstrict
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local shared = game:GetService("ReplicatedStorage").BlackClover.Shared
local Config, Spells = require(shared.MagicConfig), require(shared.SpellRegistry)
local Core = require(shared.Config)
local Art = require(script.Parent.MagicArt)
local Geometry = require(script.Parent.MagicGeometry)
local Books = require(script.Parent.GrimoireManager)
local BoneArt = require(script.Parent.BoneAwakeningArt)
-- Only Bone replaces the old compound art; other magic classes are untouched.
local function cloneArmorPiece(magicId, piece)
	if magicId == "Bone" then
		-- Imported GLB variants use the existing ArtMeshes pipeline.
		local meshLibrary = game:GetService("ReplicatedStorage").BlackClover:FindFirstChild("ArtMeshes")
		if meshLibrary and meshLibrary:FindFirstChild("Bone" .. piece) then
			return Art:Clone("Bone" .. piece)
		end
		-- Self-contained Studio fallback: full 3D bone art, no uploaded mesh IDs.
		local generated = BoneArt.Build(piece)
		return generated and Art:Track(generated) or nil
	end
	return Art:Clone(magicId .. piece)
end
local Equipment = { Actors = {} }
local bodies = { "UpperTorso", "LowerTorso", "Head", "LeftUpperArm", "RightUpperArm", "LeftLowerLeg", "RightLowerLeg" }
local function reveal(model, alpha)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "Root" then
			local original = part:GetAttribute("OriginalTransparency")
			if original == nil then original = part.Transparency; part:SetAttribute("OriginalTransparency", original) end
			part.Transparency = 1 - (1 - original) * alpha
		end
	end
end
function Equipment:ClearArmor(entry)
	for _, model in entry.Armor or {} do model:Destroy() end
	entry.Armor, entry.Wings = {}, {}
	for part, color in entry.Colors or {} do if part.Parent then part.Color = color end end
	entry.Colors = {}
end
function Equipment:Remove(character)
	local entry = self.Actors[character]
	if not entry then return end
	self:ClearArmor(entry)
	if entry.Book then entry.Book.Model:Destroy() end
	if entry.Weapon then entry.Weapon:Destroy() end
	if entry.Shield then entry.Shield:Destroy() end
	self.Actors[character] = nil
end
function Equipment:Weapon(entry, character, desired)
	if entry.WeaponName == desired then return end
	if entry.Weapon then entry.Weapon:Destroy(); entry.Weapon = nil end
	entry.WeaponName = desired
	if desired == "" then return end
	local hand = character:FindFirstChild("RightHand")
	local model = hand and Art:Clone(desired)
	if not model then entry.WeaponName = nil; return end
	model.Parent, entry.Weapon = self.Folder, model
	Art:Attach(model, hand, CFrame.new(0, -.05, -.05) * CFrame.Angles(0, 0, math.rad(-30)), false)
	local a, b = Instance.new("Attachment"), Instance.new("Attachment")
	a.Position, b.Position = Vector3.new(0, 1, 0), Vector3.new(0, desired == "AntiSword" and 6 or 5.2, 0)
	a.Parent, b.Parent = model.PrimaryPart, model.PrimaryPart
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1, trail.Lifetime = a, b, .17
	trail.FaceCamera, trail.LightEmission = true, .8
	trail.Color = ColorSequence.new(Art:Color(entry.Magic), Art:Color(entry.Magic, true))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, .15), NumberSequenceKeypoint.new(1, 1) })
	trail.Enabled, trail.Parent = false, model.PrimaryPart
	entry.Trail = trail
end
function Equipment:Armor(entry, character)
	self:ClearArmor(entry)
	local id = entry.Magic
	for _, name in bodies do
		local body = character:FindFirstChild(name)
		local model = body and cloneArmorPiece(id, "Armor" .. name)
		if model then model.Parent = self.Folder; Art:Attach(model, body, CFrame.identity, false); table.insert(entry.Armor, model) end
	end
	local torso = character:FindFirstChild("UpperTorso")
	if torso then
		for _, side in { -1, 1 } do
			local model = cloneArmorPiece(id, "Wing" .. (side == -1 and "Left" or "Right"))
			if model then
				model.Parent = self.Folder
				local hingeOffset = id == "Bone" and CFrame.new(side * .72, .48, .64) or CFrame.new(side * .3, .3, .7)
				local motor = Art:Attach(model, torso, hingeOffset, true)
				table.insert(entry.Armor, model)
				table.insert(entry.Wings, { Motor = motor, Side = side })
			end
		end
	end
	if id == "Bone" or id == "Anti" then
		for _, part in character:GetChildren() do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				entry.Colors[part] = part.Color
				part.Color = id == "Bone" and part.Name == "Head" and Color3.fromRGB(104, 99, 105) or Color3.fromRGB(25, 24, 33)
			end
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local aura = root and Art:Track(Geometry.Circle(id == "Wind" and 7 or 4, Art:Color(id)))
	if aura then
		aura.Parent = self.Folder
		local offset = id == "Wind" and CFrame.new(0, 1, 2) * CFrame.Angles(math.pi / 2, 0, 0) or CFrame.new(0, -2.95, 0)
		local motor = Art:Attach(aura, root, offset, true)
		table.insert(entry.Armor, aura)
		entry.AuraMotor = motor
	end
end
function Equipment:Shield(entry, character, visual)
	if entry.ShieldName == visual then return end
	if entry.Shield then entry.Shield:Destroy(); entry.Shield = nil end
	entry.ShieldName = visual
	if visual == "" then return end
	local body = character:FindFirstChild("UpperTorso")
	if not body then return end
	local model = Geometry.Model(visual)
	local color = Art:Color(visual == "IceShield" and "Ice" or "Water")
	if visual == "IceShield" then
		for i = 1, 6 do
			local angle = i * math.pi / 3
			Geometry.Crystal(model, Vector3.new(math.cos(angle) * 3, -.5, math.sin(angle) * 3), 5.5, color)
		end
		Geometry.Ring(model, 3.6, 0, color, 12)
	else
		local dome = Geometry.Part(model, "WaterVolume", Vector3.new(10, 10, 10), CFrame.new(0, -1, 0), color, Enum.Material.Glass, "Ball")
		dome.Transparency = .86
		for i = -1, 1 do Geometry.Ring(model, 4.4 - math.abs(i) * .4, i * 2 - 1, color, 16, .075) end
	end
	if not Art:Track(model) then entry.ShieldName = nil; return end
	model.Parent, entry.Shield = self.Folder, model
	entry.ShieldMotor = Art:Attach(model, body, CFrame.identity, true)
	if visual == "WaterDome" then
		for _, sign in { -1, 1 } do
			local dragon = Art:Clone("Dragon", .3)
			if dragon then dragon.Parent = model; Art:Attach(dragon, model.PrimaryPart, CFrame.new(sign * 4, -.5, 0) * CFrame.Angles(0, sign * math.pi / 2, 0), false) end
		end
	end
end
function Equipment:Step(character, dt, now)
	local root, humanoid = character:FindFirstChild("HumanoidRootPart"), character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return end
	local camera = workspace.CurrentCamera
	local tooFar = camera and (camera.CFrame.Position - root.Position).Magnitude > 115 and character ~= Players.LocalPlayer.Character
	local id = character:GetAttribute("MagicId") or ""
	if tooFar or humanoid.Health <= 0 or not Config.Classes[id] then self:Remove(character); return end
	local entry = self.Actors[character]
	if entry and entry.Magic ~= id then self:Remove(character); entry = nil end
	if not entry then entry = { Magic = id, Armor = {}, Wings = {}, Colors = {} }; self.Actors[character] = entry end
	if not entry.Book and now >= (entry.BookRetry or 0) then entry.Book = Books:Create(id, self.Folder); entry.BookRetry = now + 1 end
	if entry.Book then Books:Step(entry.Book, character, dt, now) end
	local awakened = character:GetAttribute("Awakened") == true
	if entry.Awakened ~= awakened then
		entry.Awakened = awakened
		if awakened then self:Armor(entry, character) else self:ClearArmor(entry) end
	end
	local weapon = id == "Anti" and "AntiSword" or (awakened and id == "Water" and "WaterSpear" or (awakened and id == "Wind" and "WindWeapon" or ""))
	if weapon == "" and (character:GetAttribute("WeaponUntil") or 0) > now then weapon = character:GetAttribute("WeaponOverride") or "" end
	self:Weapon(entry, character, weapon)
	local castId = character:GetAttribute("CastSpell") or ""
	local spell = Spells.All[castId]
	if entry.Weapon and weapon == "AntiSword" then
		local scale = castId == "Anti_AV" and 1.55 or (awakened and 1.12 or 1)
		if entry.WeaponScale ~= scale then entry.Weapon:ScaleTo(scale); entry.WeaponScale = scale end
	end
	if entry.Trail and entry.Trail.Parent then
		local definition = Core.Combat.Attacks[character:GetAttribute("AttackIndex") or 0]
		local age = now - (character:GetAttribute("AttackStart") or 0)
		entry.Trail.Enabled = (definition and age >= definition.Windup * .5 and age < definition.Windup + definition.Active)
			or (spell and (spell.Kind == "Spin" or spell.Kind == "DashStrike")) or false
	end
	local elapsed = now - (character:GetAttribute("TransformStart") or 0)
	if awakened then
		for i, model in entry.Armor do reveal(model, math.clamp((elapsed - i * .08) / .7, 0, 1)) end
		local opened = math.clamp((elapsed - .75) / 1.1, 0, 1)
		for _, wing in entry.Wings do
			wing.Motor.Transform = CFrame.Angles(0, -wing.Side * ((1 - opened) * 1.25 + .12), wing.Side * math.sin(now * 2.8) * .15 * opened)
		end
		if entry.AuraMotor and entry.AuraMotor.Parent then entry.AuraMotor.Transform = CFrame.Angles(0, now * .4, 0) end
	end
	self:Shield(entry, character, character:GetAttribute("ShieldVisual") or "")
	if entry.ShieldMotor and entry.ShieldMotor.Parent then entry.ShieldMotor.Transform = CFrame.Angles(0, now * .8, 0) end
end
function Equipment:Start()
	self.Folder = Instance.new("Folder")
	self.Folder.Name, self.Folder.Parent = "LocalMagicEquipment", workspace
	CollectionService:GetInstanceRemovedSignal("BCActor"):Connect(function(character) self:Remove(character) end)
	RunService.PreSimulation:Connect(function(dt)
		local now = workspace:GetServerTimeNow()
		local own = Players.LocalPlayer.Character
		if own then self:Step(own, dt, now) end
		for _, actor in CollectionService:GetTagged("BCActor") do if actor ~= own then self:Step(actor, dt, now) end end
	end)
end
return Equipment
