--!nonstrict
local ServerStorage = game:GetService("ServerStorage")
local Registry = require(script.Parent.Registry)
local Hitbox = require(script.Parent.MagicHitboxService)
local Damage = require(script.Parent.DamageService)
local World = require(script.Parent.MagicWorld)
local Summons = { Items = {} }
function Summons:Remove(owner)
	local record = self.Items[owner]
	if not record then return end
	self.Items[owner] = nil
	owner.Model:SetAttribute("HasGolem", false)
	World:Pulse("Shatter", record.State.Root.Position, "Earth", 12, "Golem")
	Registry:Remove(record.State.Model)
	record.State.Model:Destroy()
end
function Summons:Create(context)
	local owner, spell = context.Owner, context.Spell
	self:Remove(owner)
	local ground = Hitbox:Ground(owner.Root.Position + context.Direction * 10, owner)
	if not ground then return false end
	local model = ServerStorage.Actors.Golem:Clone()
	model:ScaleTo(2.2)
	model:PivotTo(CFrame.new(ground + Vector3.new(0, 7, 0)))
	model.Name, model.Parent = "Голем матери земли", workspace.TrainingActors
	local state = Registry:Add(model, nil, "Golem")
	state.Owner, state.BaseSpeed = owner, 15
	state.Humanoid.MaxHealth, state.Humanoid.Health = spell.SummonHP, spell.SummonHP
	state.Root:SetNetworkOwner(nil)
	for _, part in model:GetDescendants() do if part:IsA("BasePart") then part.CollisionGroup = "BCActors" end end
	self.Items[owner] = { Owner = owner, State = state, Epoch = owner.MagicEpoch, Spell = spell,
		Until = workspace:GetServerTimeNow() + spell.Duration, NextAttack = 0, Attacks = 0 }
	owner.Model:SetAttribute("HasGolem", true)
	table.insert(state.Connections, state.Humanoid.Died:Connect(function() self:Remove(owner) end))
	World:Pulse("Summon", ground, "Earth", 10, "Golem")
	return true
end
function Summons:Step(now)
	for owner, record in self.Items do
		local state = record.State
		if not Registry:Alive(owner) or not Registry:Alive(state) or owner.MagicEpoch ~= record.Epoch or now >= record.Until then self:Remove(owner); continue end
		if now < state.StunUntil or now < state.RootedUntil then continue end
		local target = Hitbox:Nearest(state, state.Root.Position, 55)
		if not target then state.Humanoid:MoveTo(owner.Root.Position + Vector3.new(6, 0, 6)); continue end
		if (state.Root.Position - owner.Root.Position).Magnitude > 90 then state.Humanoid:MoveTo(owner.Root.Position); continue end
		local delta = target.Root.Position - state.Root.Position
		if delta.Magnitude > 10 then state.Humanoid:MoveTo(target.Root.Position); continue end
		state.Humanoid:MoveTo(state.Root.Position)
		if now < record.NextAttack then continue end
		local flat = Vector3.new(delta.X, 0, delta.Z)
		if flat.Magnitude > .1 then state.Root.CFrame = CFrame.lookAt(state.Root.Position, state.Root.Position + flat) end
		record.Attacks += 1
		local slam = record.Attacks % 4 == 0
		local index = slam and 4 or (record.Attacks % 3 + 1)
		state.Generation += 1
		local generation = state.Generation
		state.BusyUntil, record.NextAttack = now + .8, now + 1.5
		state.Model:SetAttribute("AttackIndex", index)
		state.Model:SetAttribute("AttackStart", now)
		task.delay(slam and .23 or .19, function()
			if not Registry:Alive(state) or state.Generation ~= generation or self.Items[owner] ~= record then return end
			local definition = table.clone(record.Spell)
			definition.Damage, definition.Knockback = slam and record.Spell.SlamDamage or record.Spell.Damage, slam and 24 or 8
			for _, victim in Hitbox:Area(state, state.Root.Position, slam and 17 or 11, true) do
				Damage:Spell(state, victim, definition, workspace:GetServerTimeNow(), self.FX)
			end
			World:Pulse(slam and "Final" or "Impact", state.Root.Position - Vector3.new(0, 5, 0), "Earth", slam and 15 or 5)
		end)
	end
end
return Summons
