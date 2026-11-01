--!nonstrict
local Config = require(game:GetService("ReplicatedStorage").BlackClover.Shared.MagicConfig)
local Registry = require(script.Parent.Registry)
local Hitbox = require(script.Parent.MagicHitboxService)
local Damage = require(script.Parent.DamageService)
local World = require(script.Parent.MagicWorld)
local Constructs = require(script.Parent.ConstructService)
local Clash = require(script.Parent.ClashManager)
local Projectiles = { Items = {}, Reservations = {}, Count = 0, Reserved = 0 }
function Projectiles:Reserve(context, count)
	local own = 0
	for _, p in self.Items do if p.Owner == context.Owner then own += 1 end end
	for ctx, n in self.Reservations do if ctx.Owner == context.Owner then own += n end end
	if self.Count + self.Reserved + count > Config.Limits.Projectiles or own + count > Config.Limits.ProjectilesPerOwner then return false end
	self.Reservations[context] = count
	self.Reserved += count
	return true
end
function Projectiles:Release(context)
	local n = self.Reservations[context] or 0
	self.Reserved -= n
	self.Reservations[context] = nil
end
function Projectiles:Create(context, origin, direction, overrides)
	local reserved = self.Reservations[context] or 0
	if reserved <= 0 then return nil end
	self.Reservations[context] = reserved - 1
	self.Reserved -= 1
	if reserved == 1 then self.Reservations[context] = nil end
	if not Registry:Alive(context.Owner) or context.Owner.MagicEpoch ~= context.Epoch then return nil end
	local spell = context.Spell
	local p = { Owner = context.Owner, Epoch = context.Epoch, Spell = spell, Position = origin, Previous = origin, Next = origin,
		Direction = direction.Unit, Speed = spell.Speed, Radius = spell.Radius, Power = spell.ClashPower, Element = spell.ElementType,
		Range = spell.Range, Traveled = 0, Multiplier = 1, Seen = {}, Born = workspace:GetServerTimeNow(), Reflections = 0,
		Target = spell.Homing and Hitbox:Nearest(context.Owner, context.Point, 22) or nil }
	for key, value in overrides or {} do p[key] = value end
	p.Root = World:Create(p.Owner, spell, "Projectile", origin, p.Range / p.Speed + 2)
	p.Root:SetAttribute("Radius", p.Radius)
	p.Root.CFrame = CFrame.lookAt(origin, origin + p.Direction)
	self.Items[p.Root] = p
	self.Count += 1
	return p
end
function Projectiles:Remove(p)
	if p.Removed then return end
	p.Removed = true
	self.Items[p.Root] = nil
	self.Count -= 1
	p.Root:Destroy()
end
function Projectiles:Impact(p, position, now)
	World:Pulse("Impact", position, p.Element, p.Spell.Explosion or p.Radius * 2, p.Spell.Visual)
	if p.Spell.Explosion then
		for _, target in Hitbox:Area(p.Owner, position, p.Spell.Explosion, false) do
			if not p.Seen[target] then
				p.Seen[target] = true
				Damage:Spell(p.Owner, target, p.Spell, now, self.FX, p.Multiplier)
			end
		end
	end
	self:Remove(p)
end
function Projectiles:Parry(p, target, now)
	if target.MagicId ~= "Anti" or now >= target.ParryUntil then return false end
	if target.Root.CFrame.LookVector:Dot(-p.Direction) < .15 then return false end
	-- A parry never erases an ultimate. It softens one impact and consumes the window.
	if not p.Spell.Reflectable or p.Power > 100 then
		p.Multiplier *= .65
		target.ParryUntil = 0
		World:Pulse("Parry", target.Root.Position, "Anti", 5)
		return false
	elseif p.Reflections >= 1 then
		self:Remove(p)
	else
		local delta = p.Owner.Root.Position - target.Root.Position
		p.Owner, p.Epoch, p.Seen, p.Target = target, target.MagicEpoch, {}, nil
		p.Reflections += 1
		p.Direction = delta.Magnitude > .01 and delta.Unit or -p.Direction
		p.Position = target.Root.Position + p.Direction * (p.Radius + 2.5)
		p.Next, p.Previous = p.Position, p.Position
		p.Traveled = 0
		p.Power *= .85
		p.Multiplier *= .85
		p.Root.Owner.Value = target.Model
	end
	target.CounterUntil = now + 2
	target.Mana = math.min(target.MaxMana, target.Mana + 5)
	World:Pulse("Parry", target.Root.Position, "Anti", 8)
	return true
end
function Projectiles:Cut(source, power, radius)
	for _, p in self.Items do
		if p.Owner == source then continue end
		local delta = p.Position - source.Root.Position
		if delta.Magnitude < radius and (delta.Magnitude < .1 or source.Root.CFrame.LookVector:Dot(delta.Unit) > -.1) then
			if p.Power <= power then World:Pulse("Clash", p.Position, "Anti", 5); self:Remove(p) end
		end
	end
end
function Projectiles:Deflect(source, center, radius, now)
	for _, p in self.Items do
		local delta = p.Position - center
		if p.Owner ~= source and p.Element ~= "Anti" and delta.Magnitude < radius and now >= (p.DeflectReady or 0) then
			local tangent = Vector3.new(-delta.Z, .1, delta.X)
			if tangent.Magnitude > .01 then p.Direction = (p.Direction + tangent.Unit * .65).Unit end
			p.DeflectReady = now + .7
			p.Power *= .9
		end
	end
end
function Projectiles:Step(dt, now)
	for _, p in self.Items do
		if not Registry:Alive(p.Owner) or p.Owner.MagicEpoch ~= p.Epoch then self:Remove(p); continue end
		if p.Traveled >= p.Range or now - p.Born > 12 then self:Impact(p, p.Position, now); continue end
		if p.Target and Registry:Alive(p.Target) then
			local offset = p.Target.Root.Position - p.Position
			if offset.Magnitude > .01 then p.Direction = p.Direction:Lerp(offset.Unit, math.min(1, dt * p.Spell.Homing)).Unit end
		end
		p.Previous = p.Position
		p.Next = p.Position + p.Direction * math.min(p.Range - p.Traveled, p.Speed * dt)
		local travel = p.Next - p.Previous
		p.Obstacle = travel.Magnitude > .001 and workspace:Spherecast(p.Previous, math.min(p.Radius, 8), travel, Hitbox:WorldParams(p.Owner)) or nil
		if p.Obstacle then p.Next = p.Previous + travel.Unit * p.Obstacle.Distance end
	end
	Clash:Step(self)
	for _, p in self.Items do
		local move = p.Next - p.Previous
		local obstacle = p.Obstacle
		if move.Magnitude < .001 and not obstacle then continue end
		local finish = p.Next
		local parried = false
		for _, entry in Hitbox:Segment(p.Owner, p.Previous, finish, p.Radius) do
			local target = entry.State
			if p.Seen[target] then continue end
			if self:Parry(p, target, now) then parried = true; break end
			p.Seen[target] = true
			Damage:Spell(p.Owner, target, p.Spell, now, self.FX, p.Multiplier, p.Previous)
			if not p.Spell.Pierce then self:Impact(p, target.Root.Position, now); break end
		end
		if p.Removed then continue end
		if parried then p.Root.CFrame = CFrame.lookAt(p.Position, p.Position + p.Direction); continue end
		if obstacle then
			Constructs:Damage(obstacle.Instance, p.Spell.ConstructDamage or p.Spell.Damage * p.Multiplier, p.Owner)
			self:Impact(p, finish, now)
			continue
		end
		p.Traveled += move.Magnitude
		p.Position = p.Next
		p.Root.CFrame = CFrame.lookAt(p.Position, p.Position + p.Direction)
	end
end
function Projectiles:RemoveOwner(owner)
	for _, p in self.Items do if p.Owner == owner then self:Remove(p) end end
	for context in self.Reservations do if context.Owner == owner then self:Release(context) end end
end
return Projectiles
