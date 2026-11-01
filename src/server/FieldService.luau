--!nonstrict
local Config = require(game:GetService("ReplicatedStorage").BlackClover.Shared.MagicConfig)
local Registry = require(script.Parent.Registry)
local Hitbox = require(script.Parent.MagicHitboxService)
local Damage = require(script.Parent.DamageService)
local Status = require(script.Parent.StatusService)
local Passive = require(script.Parent.PassiveService)
local Projectiles = require(script.Parent.ProjectileService)
local World = require(script.Parent.MagicWorld)
local Fields = { Items = {}, Reservations = {}, Count = 0, Reserved = 0 }
function Fields:Reserve(context, amount)
	local own = 0
	for _, field in self.Items do if field.Owner == context.Owner then own += 1 end end
	for ctx, n in self.Reservations do if ctx.Owner == context.Owner then own += n end end
	if self.Count + self.Reserved + amount > Config.Limits.Fields or own + amount > Config.Limits.FieldsPerOwner then return false end
	self.Reservations[context] = amount
	self.Reserved += amount
	return true
end
function Fields:Release(context)
	self.Reserved -= self.Reservations[context] or 0
	self.Reservations[context] = nil
end
function Fields:Create(context, kind, position, options)
	local n = self.Reservations[context] or 0
	if n <= 0 then return nil end
	self.Reserved -= 1
	self.Reservations[context] = n > 1 and n - 1 or nil
	if not Registry:Alive(context.Owner) or context.Owner.MagicEpoch ~= context.Epoch then return nil end
	local now, spell = workspace:GetServerTimeNow(), context.Spell
	local field = { Owner = context.Owner, Epoch = context.Epoch, Spell = spell, Context = context, Kind = kind,
		Point = position, Until = now + spell.Duration, Activation = now + (spell.Delay or .15), NextTick = now,
		Pulse = 0, Phase = 0, Bound = {}, Seen = {}, ChannelGeneration = context.CastGeneration }
	for key, value in options or {} do field[key] = value end
	field.Root = World:Create(field.Owner, spell, kind, position, field.Until - now)
	field.Root:SetAttribute("Activation", field.Activation)
	self.Items[field.Root] = field
	self.Count += 1
	return field
end
function Fields:Remove(field, completed)
	if not self.Items[field.Root] then return end
	self.Items[field.Root] = nil
	self.Count -= 1
	local spell, now = field.Spell, workspace:GetServerTimeNow()
	if completed and spell.FinalDamage and Registry:Alive(field.Owner) then
		local final = table.clone(spell)
		final.Damage, final.Knockback, final.Stun = spell.FinalDamage, 30, .35
		for _, target in Hitbox:Area(field.Owner, field.Point, spell.Radius, false) do Damage:Spell(field.Owner, target, final, now, self.FX) end
		World:Pulse("Final", field.Point, spell.ElementType, spell.Radius, spell.Visual)
	end
	if completed and field.Kind == "Tornado" then
		for _, target in Hitbox:Area(field.Owner, field.Point, spell.Radius, false) do
			if not target.Root.Anchored then target.Root:ApplyImpulse(Vector3.new(0, 23, 0) * target.Root.AssemblyMass) end
		end
	end
	for target in field.Bound do
		if target.RootSource == field then target.RootedUntil, target.GrabPosition, target.RootSource = 0, nil, nil end
	end
	field.Root:Destroy()
end
function Fields:Bind(field, target, now, grab)
	if now < (target.RootResistUntil or 0) then return end
	if not Status:Root(target, field.Spell.RootTime, now) then return end
	target.RootSource = field
	target.RootResistUntil = now + field.Spell.RootTime + 1
	field.Bound[target] = true
	if grab and not target.Root.Anchored then
		target.GrabPosition = field.Point + Vector3.new(0, 9, 0)
		target.GrabUntil = now + field.Spell.RootTime
	end
end
function Fields:Tick(field, now)
	local spell, source = field.Spell, field.Owner
	field.Pulse += 1
	local point = field.Point
	if field.Kind == "Prison" then
		if field.Phase ~= 0 then return end
		field.Phase = 1
		for _, target in Hitbox:Area(source, point, spell.Radius, false) do
			Damage:Spell(source, target, spell, now, self.FX)
			self:Bind(field, target, now, false)
		end
	elseif field.Kind == "Hand" then
		if field.Phase == 0 then
			field.Phase = 1
			field.SlamAt = now + 1.05
			field.NextTick = field.SlamAt
			for _, target in Hitbox:Area(source, point, spell.Radius, false) do self:Bind(field, target, now, true) end
		elseif field.Phase == 1 and now >= field.SlamAt then
			field.Phase = 2
			for target in field.Bound do
				if not Registry:Alive(target) then continue end
				if target.RootSource == field then
					target.GrabPosition, target.RootedUntil = nil, 0
					local ground = Hitbox:Ground(target.Root.Position, target)
					if ground and not target.Root.Anchored then target.Root.CFrame = CFrame.new(ground + Vector3.new(0, 3, 0)) * target.Root.CFrame.Rotation end
				end
				Damage:Spell(source, target, spell, now, self.FX)
			end
			World:Pulse("Final", point, "Bone", spell.Radius, "BoneHand")
		end
	elseif field.Kind == "Judgment" then
		-- The summoned spear projectiles do the damage; final damage is resolved on expiry.
	elseif field.Kind == "Spike" then
		if field.Phase ~= 0 then return end
		field.Phase = 1
		field.Context.Hits = field.Context.Hits or {}
		for _, target in Hitbox:Area(source, point + Vector3.new(0, 2, 0), spell.Radius, false) do
			if now - (field.Context.Hits[target] or -math.huge) >= .22 then
				field.Context.Hits[target] = now
				Damage:Spell(source, target, spell, now, self.FX)
			end
		end
	else
		local radius = spell.Radius
		if field.Kind == "Domain" and spell.PulseRadius then
			local nearest = Hitbox:Nearest(source, point + Vector3.new(0, 3, 0), spell.Radius)
			if nearest then point = nearest.Root.Position end
			radius = spell.PulseRadius
		end
		for _, target in Hitbox:Area(source, point, radius, false) do
			Damage:Spell(source, target, spell, now, self.FX)
			if field.Kind == "Tornado" and not target.Root.Anchored then
				local delta = field.Point - target.Root.Position
				local horizontal = Vector3.new(delta.X, 0, delta.Z)
				if horizontal.Magnitude > .2 then
					local impulse = horizontal.Unit * spell.Pull + Vector3.new(0, 9, 0)
					target.Root:ApplyImpulse(impulse * target.Root.AssemblyMass)
					target.MotionGrace = now + .6
				end
			end
		end
		if spell.ElementType == "Ice" and field.Kind == "Domain" then
			for _, target in Hitbox:Area(source, field.Point, spell.Radius, false) do Passive:AfterHit(source, target, 0, "Ice", now) end
		end
		if spell.Cut then Projectiles:Cut(source, spell.ClashPower, spell.Radius) end
	end
	field.Root:SetAttribute("Phase", field.Phase)
	field.Root:SetAttribute("PulsePosition", point)
	field.Root:SetAttribute("PulseTime", now)
	field.Root:SetAttribute("Pulse", field.Pulse)
end
function Fields:Step(dt, now)
	for _, field in self.Items do
		local source, spell = field.Owner, field.Spell
		if not Registry:Alive(source) or source.MagicEpoch ~= field.Epoch
			or (spell.Channel > 0 and source.CastGeneration ~= field.ChannelGeneration) then self:Remove(field, false); continue end
		if now >= field.Until then self:Remove(field, true); continue end
		if field.Kind == "Spin" then
			field.Point = source.Root.Position
			field.Root.CFrame = source.Root.CFrame
		elseif field.Kind == "Tornado" then
			local delta = field.Context.Point - field.Point
			local horizontal = Vector3.new(delta.X, 0, delta.Z)
			if horizontal.Magnitude > 1 then field.Point += horizontal.Unit * math.min(horizontal.Magnitude, spell.Speed * dt) end
			field.Root.CFrame = CFrame.new(field.Point)
			Projectiles:Deflect(source, field.Point, spell.Radius, now)
		end
		if now >= field.Activation and now >= field.NextTick then
			field.NextTick = now + spell.Tick
			self:Tick(field, now)
		end
	end
end
function Fields:RemoveOwner(owner)
	for _, field in self.Items do if field.Owner == owner then self:Remove(field, false) end end
	for context in self.Reservations do if context.Owner == owner then self:Release(context) end end
end
return Fields
