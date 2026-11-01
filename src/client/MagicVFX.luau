--!nonstrict
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local shared = game:GetService("ReplicatedStorage").BlackClover.Shared
local Config, Spells = require(shared.MagicConfig), require(shared.SpellRegistry)
local Art = require(script.Parent.MagicArt)
local G = require(script.Parent.MagicGeometry)
local VFX = { Entities = {}, Casts = {}, Pool = {}, PoolSize = 0, Retry = {} }
local function emitter(part, color, mist)
	local p = Instance.new("ParticleEmitter")
	p.Texture = mist and "rbxasset://textures/particles/smoke_main.dds" or "rbxasset://textures/particles/sparkles_main.dds"
	p.Color, p.LightEmission = ColorSequence.new(color), mist and .15 or .8
	p.Lifetime, p.Speed = NumberRange.new(.3, .7), NumberRange.new(6, 20)
	p.SpreadAngle, p.Drag = Vector2.new(180, 180), 4
	p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, mist and 2 or .3), NumberSequenceKeypoint.new(1, 0) })
	p.Rate, p.Parent = 0, part
	return p
end
function VFX:Sound(parent, id, pitch)
	if not id or id == "" then return end
	local sound = Instance.new("Sound")
	sound.SoundId, sound.Volume, sound.PlaybackSpeed = id, .23, pitch or 1
	sound.RollOffMinDistance, sound.RollOffMaxDistance = 10, 100
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 3)
end
function VFX:Pulse(kind, position, element, radius, detail)
	if typeof(position) ~= "Vector3" then return end
	local camera = workspace.CurrentCamera
	if camera and (position - camera.CFrame.Position).Magnitude > Config.Limits.VFXDistance then return end
	local slot = table.remove(self.Pool)
	if not slot then
		if self.PoolSize >= 24 then return end
		self.PoolSize += 1
		local part = G.Part(nil, "PooledImpact", Vector3.one * .1, CFrame.identity, Color3.new())
		part.Transparency = 1
		slot = { Part = part, Emitter = emitter(part, Color3.new(1, 1, 1)), Lease = 0 }
	end
	slot.Lease += 1
	local lease = slot.Lease
	slot.Part.CFrame, slot.Part.Parent = CFrame.new(position), self.Folder
	slot.Emitter.Color = ColorSequence.new(Art:Color(element), Art:Color(element, true))
	slot.Emitter.Speed = NumberRange.new(5, math.min(40, radius * 2))
	slot.Emitter:Emit(math.clamp(math.floor(radius * 2), 10, 45))
	self:Sound(slot.Part, element == "Water" and Config.Audio.Water or Config.Audio.Impact, kind == "Final" and .65 or 1.1)
	if kind == "Clash" or kind == "Final" or kind == "Teleport" then
		local circle = Art:Track(G.Circle(math.min(radius, 22), Art:Color(element)))
		if circle then
			circle:PivotTo(CFrame.new(position - Vector3.new(0, kind == "Teleport" and 2.8 or 0, 0)))
			circle.Parent = self.Folder
			for _, part in circle:GetDescendants() do if part:IsA("BasePart") and part.Name ~= "Root" then TweenService:Create(part, TweenInfo.new(.45), { Transparency = 1 }):Play() end end
			Debris:AddItem(circle, .5)
		end
	end
	if kind == "Shatter" then
		local pieces = G.Model("BreakingFragments")
		for i = 1, 9 do
			local part = G.Part(pieces, "Fragment", Vector3.new(.7, 1.2, .7), CFrame.new(position), Art:Color(element), nil, "Wedge")
			local angle = i * math.pi * 2 / 9
			TweenService:Create(part, TweenInfo.new(.6), { CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * 8, -3 + i % 3, math.sin(angle) * 8)) * CFrame.Angles(i, i, 0), Transparency = 1 }):Play()
		end
		if Art:Track(pieces) then pieces.Parent = self.Folder; Debris:AddItem(pieces, .7) end
	end
	task.delay(.85, function()
		if slot.Lease ~= lease then return end
		slot.Emitter:Clear()
		for _, child in slot.Part:GetChildren() do if child:IsA("Sound") then child:Destroy() end end
		slot.Part.Parent = nil
		table.insert(self.Pool, slot)
	end)
end
local function track(model) return Art:Track(model) end
function VFX:Projectile(root, spell)
	local visual, radius, color = root:GetAttribute("Visual"), root:GetAttribute("Radius") or spell.Radius, Art:Color(spell.ElementType)
	local name = ({ Dragon = "Dragon", Hawk = "Hawk", BoneSpear = "BoneSpear", WindLance = "WindWeapon", SpearJudgment = "WaterSpear" })[visual]
	if name then
		local scale = name == "Dragon" and radius / 3 or (visual == "SpearJudgment" and 1.4 or 1)
		return Art:Clone(name, scale), name:find("Spear") or name == "WindWeapon" and true
	end
	if visual == "WindBlade" or visual == "BlackArc" or visual == "EndMagic" or visual == "BoneArc" then
		local model = G.Arc(math.max(2, radius), color, spell.ElementType == "Anti")
		if visual == "BoneArc" then for i = -2, 2 do G.Bone(model, Vector3.new(i * radius * .35, .4, 0), radius * .6, color) end end
		return track(model), false
	end
	local model = G.Model(visual)
	if visual == "WaterOrb" then
		local core = G.Part(model, "WaterCore", Vector3.one * radius * 1.7, CFrame.identity, color, Enum.Material.Glass, "Ball")
		core.Transparency = .27
		G.Ring(model, radius, 0, Art:Color("Water", true), 12, .08)
		G.Ring(model, radius * .8, radius * .4, color, 10, .065)
	elseif visual == "IceDisc" then
		local disc = G.Part(model, "CrystalDisc", Vector3.new(.25, radius * 2, radius * 2), CFrame.Angles(0, math.pi / 2, 0), color, Enum.Material.Glass, "Cylinder")
		disc.Transparency = .18
		for i = 1, 6 do local a = i * math.pi / 3; G.Crystal(model, Vector3.new(math.cos(a) * radius * .7, math.sin(a) * radius * .7, 0), radius * .5, color) end
	else
		G.Star(model, Vector3.zero, visual == "StarMeteor" and 2.5 or 1.3, Art:Color("Stars", true))
		local core = G.Part(model, "AstralCore", Vector3.one * (visual == "StarMeteor" and 3 or 1), CFrame.identity, color, Enum.Material.Neon, "Ball")
		core.Transparency = .2
	end
	return track(model), false
end
function VFX:Zone(root, spell)
	local kind, visual, radius, color = root:GetAttribute("EntityKind"), spell.Visual, spell.Radius, Art:Color(spell.ElementType)
	if kind == "Hand" then return Art:Clone("BoneHand", 1.5) end
	local model = G.Model(visual)
	if kind == "Wall" then
		for x = -2.5, 2.5, 1 do
			for y = -1, 1 do G.Part(model, "StoneBlock", Vector3.new(2.9, 3.9, 3.1), CFrame.new(x * 3, y * 4, .08 * (y % 2)) * CFrame.Angles(0, 0, .015 * y), color:Lerp(Color3.fromRGB(95, 91, 79), .45), Enum.Material.Slate, "Wedge") end
		end
	elseif kind == "Tornado" then
		for strand = 0, 1 do
			for i = 0, 23 do
				local a, b = i / 24, (i + 1) / 24
				local function point(t)
					local angle = t * math.pi * 5 + strand * math.pi
					local r = 1.5 + t * (radius - 1.5)
					return Vector3.new(math.cos(angle) * r, t * 20 - 2, math.sin(angle) * r)
				end
				local part = G.Rod(model, point(a), point(b), .15 + a * .1, strand == 0 and color or Art:Color("Wind", true), true)
				part.Transparency = .25
			end
		end
	elseif kind == "Spike" then
		for i = -1, 1 do
			if spell.ElementType == "Bone" then G.Bone(model, Vector3.new(i * 1.5, 3, 0), 6 - math.abs(i), color)
			else G.Crystal(model, Vector3.new(i * 1.4, 3, 0), 7 - math.abs(i), color) end
		end
	elseif kind == "Prison" then
		local count = visual == "BoneGrave" and 12 or (visual == "StarPrison" and 6 or 8)
		local height = visual == "BoneGrave" and 16 or 9
		local points = {}
		for i = 1, count do
			local a = i * math.pi * 2 / count
			local position = Vector3.new(math.cos(a) * radius * .78, height / 2, math.sin(a) * radius * .78)
			points[i] = position
			if spell.ElementType == "Bone" then G.Bone(model, position, height, color)
			elseif spell.ElementType == "Stars" then G.Star(model, position, 1, Art:Color("Stars", true))
			else G.Crystal(model, position, height, color) end
		end
		if spell.ElementType == "Stars" then
			for i = 1, count do
				G.Beam(model, points[i], points[i % count + 1], color, .15)
				G.Beam(model, points[i] - Vector3.new(0, 3.8, 0), points[i] + Vector3.new(0, 3.8, 0), color, .1)
			end
		else G.Ring(model, radius * .78, height * .7, color, 16, .15) end
	elseif kind == "Spin" then
		G.Ring(model, radius * .85, 0, color, 24, .15)
		G.Ring(model, radius * .62, .6, Art:Color(spell.ElementType, true), 16, .1)
		if spell.ElementType == "Water" then
			for i = 1, 6 do
				local a = i * math.pi / 3
				G.Rod(model, Vector3.new(math.cos(a) * 6, 0, math.sin(a) * 6), Vector3.new(math.cos(a) * 13, 0, math.sin(a) * 13), .12, color, true)
			end
		end
	else
		G.Ring(model, radius, -1, color, 28, .07)
		if visual == "Blizzard" then
			local ground = G.Part(model, "FrozenGround", Vector3.new(.04, radius * 2, radius * 2), CFrame.new(0, -.94, 0) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.Glass, "Cylinder")
			ground.Transparency = .55
			for i = 1, 6 do local a = i * math.pi / 3; G.Crystal(model, Vector3.new(math.cos(a) * radius * .7, 2, math.sin(a) * radius * .7), 4, color) end
			local mist = emitter(model.PrimaryPart, color, true)
			mist.Rate, mist.Speed, mist.Lifetime = 18, NumberRange.new(6, 15), NumberRange.new(1, 2)
			mist.Size = NumberSequence.new(5)
		elseif visual == "SkyStorm" then
			G.Ring(model, radius * .8, 22, color, 20, .15)
			G.Ring(model, radius * .5, 26, Art:Color("Wind", true), 16, .12)
		elseif visual == "BoneKingdom" then
			for i = 1, 8 do local a = i * math.pi / 4; G.Bone(model, Vector3.new(math.cos(a) * radius * .75, 7, math.sin(a) * radius * .75), 15, color) end
		elseif visual == "SpearJudgment" then
			G.Ring(model, radius * .8, 24, color, 24, .12)
		end
	end
	return track(model)
end
function VFX:Add(root)
	if self.Entities[root] then return end
	local now = workspace:GetServerTimeNow()
	if now < (self.Retry[root] or 0) then return end
	local spell = Spells.All[root:GetAttribute("SpellId") or ""]
	if not spell then return end
	local kind = root:GetAttribute("EntityKind")
	local model, spear
	if kind == "Projectile" then model, spear = self:Projectile(root, spell) else model = self:Zone(root, spell) end
	if not model then self.Retry[root] = now + .6; return end
	self.Retry[root] = nil
	model.Parent = self.Folder
	local entry = { Root = root, Model = model, Spell = spell, Kind = kind, Spear = spear, Pulse = 0, CFrame = root.CFrame, Sub = {} }
	self.Entities[root] = entry
	if spell.Visual == "Hawk" then
		entry.Feathers = {}
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and (part.Name:match("^WingL_") or part.Name:match("^WingR_")) then
				table.insert(entry.Feathers, { Part = part, Offset = model:GetPivot():ToObjectSpace(part.CFrame), Side = part.Name:match("^WingL_") and -1 or 1 })
			end
		end
	end
	if kind == "Wall" then
		local gui = Instance.new("BillboardGui")
		gui.Size, gui.StudsOffsetWorldSpace, gui.MaxDistance = UDim2.fromOffset(120, 25), Vector3.new(0, 7, 0), 100
		gui.Adornee, gui.Parent = model.PrimaryPart, model
		local label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency, label.TextColor3 = UDim2.fromScale(1, 1), 1, Art:Color("Earth", true)
		label.Font, label.TextSize, label.TextStrokeTransparency, label.Parent = Enum.Font.GothamBold, 13, .3, gui
		entry.HealthLabel = label
	end
	if kind == "Projectile" then
		local a, b = Instance.new("Attachment"), Instance.new("Attachment")
		a.Position, b.Position = Vector3.new(-.3, 0, 0), Vector3.new(.3, 0, 0)
		a.Parent, b.Parent = model.PrimaryPart, model.PrimaryPart
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1, trail.Lifetime = a, b, .25
		trail.Color, trail.LightEmission = ColorSequence.new(Art:Color(spell.ElementType), Art:Color(spell.ElementType, true)), .85
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, .2), NumberSequenceKeypoint.new(1, 1) })
		trail.Parent = model.PrimaryPart
		local particles = emitter(model.PrimaryPart, Art:Color(spell.ElementType))
		particles.Rate, particles.Speed = 9, NumberRange.new(1, 4)
	end
	if spell.Visual == "BoneKingdom" then
		for _, sign in { -1, 1 } do
			local rib = Art:Clone("BoneArmorUpperTorso", 6)
			if rib then rib.Parent = self.Folder; table.insert(entry.Sub, { Model = rib, Offset = CFrame.new(sign * spell.Radius * .45, 9, 0) }) end
		end
	elseif spell.Visual == "SpearJudgment" and kind ~= "Projectile" then
		for i = 1, 12 do
			local a = i * math.pi / 6
			local spearModel = Art:Clone("WaterSpear", 1.3)
			local point = Vector3.new(math.cos(a) * 23, 25, math.sin(a) * 23)
			if spearModel then spearModel.Parent = self.Folder; table.insert(entry.Sub, { Model = spearModel, Offset = CFrame.lookAt(point, Vector3.zero) * CFrame.Angles(-math.pi / 2, 0, 0), Preview = true }) end
		end
	end
end
function VFX:Remove(root)
	self.Retry[root] = nil
	local entry = self.Entities[root]
	if not entry then return end
	entry.Model:Destroy()
	for _, sub in entry.Sub do sub.Model:Destroy() end
	self.Entities[root] = nil
end
function VFX:DomainStrike(spell, point)
	local model
	if spell.ElementType == "Bone" then model = Art:Clone("BoneHand", .65)
	elseif spell.ElementType == "Ice" then
		model = G.Model("FallingIce")
		for i = -1, 1 do G.Crystal(model, Vector3.new(i * 3, 0, 0), 6, Art:Color("Ice")) end
		model = track(model)
	else model = track(G.Arc(8, Art:Color("Wind"))) end
	if not model then return end
	local bone = spell.ElementType == "Bone"
	model.Parent = self.Folder
	model:PivotTo(CFrame.new(point + Vector3.new(0, bone and -8 or 14, 0)))
	local destination = CFrame.new(point + Vector3.new(0, bone and -2 or 0, 0)) * CFrame.Angles(bone and -.5 or .2, 0, 0)
	local origin = model:GetPivot()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(.22, Enum.EasingStyle.Quad), { CFrame = destination * origin:ToObjectSpace(part.CFrame) }):Play()
			task.delay(.25, function() if part.Parent then TweenService:Create(part, TweenInfo.new(.35), { Transparency = 1 }):Play() end end)
		end
	end
	Debris:AddItem(model, .65)
end
function VFX:Cast(character, spell, now)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local state = self.Casts[character]
	for _, model in state.Models or {} do model:Destroy() end
	state.Models = {}
	local circle = track(G.Circle(2.6 + spell.Flavor % 3 * .2, Art:Color(spell.ElementType)))
	if circle then
		circle.Parent = self.Folder
		Art:Attach(circle, root, CFrame.new(0, -2.9, 0), false)
		table.insert(state.Models, circle)
		self:Sound(circle.PrimaryPart, Config.Audio.Cast, .8 + spell.Flavor % 7 * .08)
		Debris:AddItem(circle, math.max(.1, (character:GetAttribute("CastRelease") or now) - now) + .2)
	end
	local hand = character:FindFirstChild("RightHand")
	if hand and (spell.Kind == "Projectile" or spell.Kind == "Volley" or spell.Kind == "Dive") then
		local charge, spear = self:Projectile({ GetAttribute = function(_, key)
			if key == "Visual" then return spell.Visual elseif key == "Radius" then return math.min(spell.Radius, 1) end
		end }, spell)
		if charge then
			charge:ScaleTo(charge:GetScale() * (spell.Visual == "Hawk" and .35 or .5))
			charge.Parent = self.Folder
			Art:Attach(charge, hand, CFrame.new(0, -.4, -.8) * (spear and CFrame.Angles(-math.pi / 2, 0, 0) or CFrame.identity), false)
			table.insert(state.Models, charge)
			Debris:AddItem(charge, math.max(.05, (character:GetAttribute("CastRelease") or now) - now))
		end
	end
end
function VFX:Step(dt)
	local now, camera = workspace:GetServerTimeNow(), workspace.CurrentCamera
	for _, root in CollectionService:GetTagged("BCSpellEntity") do
		if not camera or (camera.CFrame.Position - root.Position).Magnitude <= Config.Limits.VFXDistance then self:Add(root)
		else self:Remove(root) end
	end
	for root, entry in self.Entities do
		if not root.Parent then self:Remove(root); continue end
		local age = now - (root:GetAttribute("StartTime") or now)
		local cf = root.CFrame
		if entry.Kind == "Projectile" then
			entry.CFrame = entry.CFrame:Lerp(cf, 1 - math.exp(-28 * dt))
			cf = entry.CFrame
			if entry.Spear then cf *= CFrame.Angles(-math.pi / 2, 0, 0)
			elseif entry.Spell.Visual ~= "Dragon" and entry.Spell.Visual ~= "Hawk" then cf *= CFrame.Angles(0, 0, age * 8) end
		elseif entry.Kind == "Tornado" or entry.Kind == "Spin" then
			if entry.Kind == "Spin" then local owner = root:FindFirstChild("Owner"); local body = owner and owner.Value and owner.Value:FindFirstChild("HumanoidRootPart"); if body then cf = body.CFrame end end
			cf *= CFrame.Angles(0, age * 5, 0)
		elseif entry.Kind == "Spike" then cf *= CFrame.new(0, -8 * (1 - math.clamp(age / .2, 0, 1)), 0)
		elseif entry.Kind == "Prison" then
			local falling = entry.Spell.ElementType == "Bone"
			cf *= CFrame.new(0, (falling and 22 or -10) * (1 - math.clamp(age / (falling and (entry.Spell.Delay or .45) or .2), 0, 1)), 0)
		elseif entry.Kind == "Hand" then cf *= CFrame.new(0, -14 * (1 - math.clamp(age / .3, 0, 1)), 0) * CFrame.Angles((root:GetAttribute("Phase") or 0) == 2 and -.6 or 0, 0, 0) end
		entry.Model:PivotTo(cf)
		for _, feather in entry.Feathers or {} do
			local hinge = CFrame.new(feather.Side * .65, 0, 0)
			feather.Part.CFrame = cf * hinge * CFrame.Angles(0, 0, feather.Side * math.sin(age * 13) * .3) * hinge:Inverse() * feather.Offset
		end
		if root:GetAttribute("Frosted") and not entry.Frosted then
			entry.Frosted = true
			for _, part in entry.Model:GetDescendants() do if part:IsA("BasePart") and part.Name ~= "Root" then part.Color = part.Color:Lerp(Art:Color("Ice", true), .7); part.Material = Enum.Material.Ice end end
		end
		if entry.HealthLabel then entry.HealthLabel.Text = string.format("СТЕНА · %d / %d", root:GetAttribute("Health") or 0, root:GetAttribute("MaxHealth") or 180) end
		local endTime = root:GetAttribute("EndTime") or now + 1
		if entry.Kind ~= "Projectile" and now > endTime - .25 and not entry.Fading then
			entry.Fading = true
			for _, part in entry.Model:GetDescendants() do if part:IsA("BasePart") then TweenService:Create(part, TweenInfo.new(.25), { Transparency = 1 }):Play() end end
		end
		for _, sub in entry.Sub do
			if sub.Preview and age > .9 then sub.Model:Destroy()
			elseif sub.Model.Parent then sub.Model:PivotTo(root.CFrame * sub.Offset) end
		end
		local pulse = root:GetAttribute("Pulse") or 0
		if pulse ~= entry.Pulse then
			entry.Pulse = pulse
			local point = root:GetAttribute("PulsePosition") or root.Position
			if entry.Kind == "Domain" then
				self:Pulse("Impact", point, entry.Spell.ElementType, entry.Spell.PulseRadius or entry.Spell.Radius)
				self:DomainStrike(entry.Spell, point)
			end
		end
	end
	for _, character in CollectionService:GetTagged("BCActor") do
		local castStart = character:GetAttribute("CastStart") or 0
		local spell = Spells.All[character:GetAttribute("CastSpell") or ""]
		local state = self.Casts[character] or {}
		self.Casts[character] = state
		local body = character:FindFirstChild("HumanoidRootPart")
		local nearby = body and (not camera or (body.Position - camera.CFrame.Position).Magnitude <= Config.Limits.VFXDistance)
		if spell and state.Start ~= castStart then state.Start = castStart; if nearby then self:Cast(character, spell, now) end end
		if not spell then for _, model in state.Models or {} do model:Destroy() end; state.Models = {} end
		local transform = character:GetAttribute("TransformStart") or 0
		if transform > 0 and transform ~= state.Transform then
			state.Transform = transform
			if nearby and now - transform < Config.TransformTime then self:Pulse("Final", body.Position - Vector3.new(0, 2.8, 0), character:GetAttribute("MagicId"), 12); self:Sound(body, Config.Audio.Transform, .7) end
		end
	end
end
function VFX:Start(remote)
	self.Folder = Instance.new("Folder")
	self.Folder.Name, self.Folder.Parent = "LocalMagicVFX", workspace
	CollectionService:GetInstanceRemovedSignal("BCSpellEntity"):Connect(function(root) self:Remove(root) end)
	CollectionService:GetInstanceRemovedSignal("BCActor"):Connect(function(character)
		local state = self.Casts[character]
		if state then for _, model in state.Models or {} do model:Destroy() end end
		self.Casts[character] = nil
	end)
	remote.OnClientEvent:Connect(function(kind, ...) if kind ~= "Notice" then self:Pulse(kind, ...) end end)
	RunService.RenderStepped:Connect(function(dt) self:Step(dt) end)
end
return VFX
