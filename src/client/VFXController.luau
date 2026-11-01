--!nonstrict
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Config = require(game:GetService("ReplicatedStorage").BlackClover.Shared.Config)
local VFX = { Active = 0, Actors = {}, Shake = 0 }
local gold = Color3.fromRGB(255, 213, 128)
local mint = Color3.fromRGB(112, 246, 222)

function VFX:Anchor(position, lifetime)
	if self.Active >= 72 then return nil end
	self.Active += 1
	local part = Instance.new("Part")
	part.Name = "LocalEffect"
	part.Size = Vector3.one * 0.15
	part.CFrame = CFrame.new(position)
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
	part.Transparency = 1
	part.Parent = self.Folder
	Debris:AddItem(part, lifetime)
	task.delay(lifetime, function() self.Active -= 1 end)
	return part
end

function VFX:Sound(name, parent, pitch)
	local id = Config.Audio[name]
	if not id or id == "" or not parent then return end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = name == "Swing" and 0.15 or 0.3
	sound.PlaybackSpeed = pitch or 1
	sound.RollOffMinDistance, sound.RollOffMaxDistance = 7, 65
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 2)
end

function VFX:Burst(position, color, strong)
	local anchor = self:Anchor(position, 1.3)
	if not anchor then return end
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	particles.LightEmission = 0.85
	particles.Lifetime = NumberRange.new(0.15, 0.4)
	particles.Speed = NumberRange.new(8, strong and 24 or 15)
	particles.Drag = 5
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.32), NumberSequenceKeypoint.new(1, 0) })
	particles.Rate = 0
	particles.Parent = anchor
	particles:Emit(strong and 22 or 12)
	local flash = Instance.new("PointLight")
	flash.Color, flash.Brightness, flash.Range = color, 3, strong and 12 or 7
	flash.Parent = anchor
	TweenService:Create(flash, TweenInfo.new(0.2), { Brightness = 0 }):Play()
	-- A short planar expanding pulse; its geometry stays cosmetic and non-queryable.
	local pulse = Instance.new("Part")
	pulse.Shape = Enum.PartType.Ball
	pulse.Material = Enum.Material.Neon
	pulse.Color, pulse.Transparency = color, 0.55
	pulse.Size = Vector3.new(0.3, 0.3, 0.3)
	pulse.CFrame = CFrame.new(position)
	pulse.Anchored, pulse.CanCollide, pulse.CanQuery, pulse.CanTouch = true, false, false, false
	pulse.Parent = anchor
	TweenService:Create(pulse, TweenInfo.new(0.2), { Size = Vector3.one * (strong and 4.5 or 2.3), Transparency = 1 }):Play()
	return anchor
end

function VFX:Damage(position, damage, color, text)
	local anchor = self:Anchor(position + Vector3.new(0, 2.5, 0), 0.85)
	if not anchor then return end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(130, 45)
	gui.AlwaysOnTop = true
	gui.Adornee, gui.Parent = anchor, anchor
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	label.Font, label.TextSize = Enum.Font.GothamBold, 24
	label.TextColor3, label.TextStrokeTransparency = color, 0.6
	label.Text = text or tostring(math.floor(damage + 0.5))
	label.Parent = gui
	TweenService:Create(anchor, TweenInfo.new(0.8), { Position = anchor.Position + Vector3.new(0, 2, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.15),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end

local function makeTrail(part, color, name, wide)
	local a, b = Instance.new("Attachment"), Instance.new("Attachment")
	a.Name, b.Name = name .. "A", name .. "B"
	a.Position, b.Position = Vector3.new(0, wide, 0), Vector3.new(0, -wide, 0)
	a.Parent, b.Parent = part, part
	local trail = Instance.new("Trail")
	trail.Name = name
	trail.Attachment0, trail.Attachment1 = a, b
	trail.Color = ColorSequence.new(color)
	trail.Lifetime, trail.MinLength, trail.LightEmission = 0.13, 0.05, 0.7
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 1) })
	trail.Enabled = false
	trail.Parent = part
	return trail, a, b
end

function VFX:Attach(model)
	if self.Actors[model] then return self.Actors[model] end
	local left, right, root = model:FindFirstChild("LeftHand"), model:FindFirstChild("RightHand"), model:FindFirstChild("HumanoidRootPart")
	if not left or not right or not root then return nil end
	local entry = { Objects = {}, Fists = {} }
	for _, hand in { right, left } do
		local trail, a, b = makeTrail(hand, gold, "FistTrail", 0.3)
		table.insert(entry.Fists, trail)
		for _, object in { trail, a, b } do table.insert(entry.Objects, object) end
	end
	local trail, a, b = makeTrail(root, mint, "SprintTrail", 0.23)
	a.Position, b.Position = Vector3.new(-0.65, 0, 0.4), Vector3.new(0.65, 0, 0.4)
	entry.Sprint = trail
	for _, object in { trail, a, b } do table.insert(entry.Objects, object) end
	self.Actors[model] = entry
	return entry
end

function VFX:Handle(kind, model, position, value, source, index)
	if kind == "Rejected" then return end
	if typeof(position) ~= "Vector3" then return end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - position).Magnitude > Config.Network.MaxVFXDistance then return end
	if kind == "Swing" then
		local definition = Config.Combat.Attacks[value]
		if not definition then return end
		if model:GetAttribute("MeleeProfile") and model:GetAttribute("MeleeProfile") ~= "Fist" then
			self:Sound("Swing", model:FindFirstChild("HumanoidRootPart"), .85)
			return
		end
		local entry = self:Attach(model)
		if not entry then return end
		local trail = entry.Fists[(value == 2 or value == 4) and 2 or 1]
		task.delay(definition.Windup * 0.55, function()
			if trail.Parent then trail.Enabled = true; self:Sound("Swing", trail.Parent, 1.15 + value * 0.06) end
		end)
		task.delay(definition.Windup + definition.Active, function() if trail.Parent then trail.Enabled = false end end)
	elseif kind == "Dash" then
		local anchor = self:Burst(position - Vector3.new(0, 2, 0), mint, false)
		self:Sound("Dash", anchor, 0.85)
	elseif kind == "Restored" then
		self:Burst(position, mint, true)
		self:Damage(position, 0, mint, "ВОССТАНОВЛЕНО")
	else
		local guarded = kind == "Block"
		local broken = kind == "GuardBreak"
		local color = guarded and mint or (broken and Color3.fromRGB(255, 105, 85) or gold)
		local anchor = self:Burst(position, color, broken or index == 4)
		self:Sound(guarded and "Block" or "Hit", anchor, guarded and 1.7 or 0.85)
		self:Damage(position, value or 0, color, broken and "ЗАЩИТА СЛОМАНА" or nil)
		if model == Players.LocalPlayer.Character or source == Players.LocalPlayer.Character then
			self.Shake = math.max(self.Shake, index == 4 and 0.24 or 0.10)
		end
	end
end

function VFX:Step(dt)
	self.Shake *= math.exp(-14 * dt)
	for _, model in CollectionService:GetTagged("BCActor") do
		local entry = self:Attach(model)
		local root = model:FindFirstChild("HumanoidRootPart")
		if entry and root then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			entry.Sprint.Enabled = humanoid and humanoid.Health > 0 and (model:GetAttribute("Sprinting")
				or (model:GetAttribute("DashUntil") or 0) > workspace:GetServerTimeNow()) and root.AssemblyLinearVelocity.Magnitude > 20
		end
	end
end

function VFX:Start()
	self.Folder = Instance.new("Folder")
	self.Folder.Name, self.Folder.Parent = "LocalVFX", workspace
	CollectionService:GetInstanceRemovedSignal("BCActor"):Connect(function(model)
		local entry = self.Actors[model]
		if entry then for _, object in entry.Objects do object:Destroy() end end
		self.Actors[model] = nil
	end)
end

return VFX
