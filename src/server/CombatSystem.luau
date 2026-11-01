--!nonstrict
local Config = require(game:GetService("ReplicatedStorage").BlackClover.Shared.Config)
local Rules = require(game:GetService("ReplicatedStorage").BlackClover.Shared.Rules)
local Registry = require(script.Parent.Registry)
local Hitbox = require(script.Parent.Hitbox)
local Movement = require(script.Parent.MovementSystem)
local Damage = require(script.Parent.DamageService)
local Combat = {}

function Combat:Block(state, enabled, now)
	if not enabled then state.Blocking = false; Registry:Publish(state); return true end
	if not Registry:Alive(state) or not Rules.canAct(state.Humanoid.Health, now, state.BusyUntil, state.StunUntil)
		or state.Guard < 8 or now < state.RootedUntil then return false end
	state.Blocking = true
	state.Sprinting = false
	Registry:Publish(state)
	return true
end

function Combat:ApplyHit(source, target, definition, index, now, fx)
	local multiplier = source.MagicId == "Anti" and 1.15 or (source.MagicId == "Water" and source.Awakened and 1.1 or 1)
	return Damage:Apply(source, target, { Damage = definition.Damage * multiplier, Guard = definition.Guard,
		Stun = definition.Stun, Knockback = definition.Knockback, Lift = index == 4 and 7 or 0, Index = index }, now, fx)
end

function Combat:Attack(state, now, fx)
	if not Registry:Alive(state) or not Rules.canAct(state.Humanoid.Health, now, state.BusyUntil, state.StunUntil)
		or state.Blocking or now < state.RootedUntil or now < state.AttackReady then return false end
	state.Combo = Rules.nextCombo(state.Combo, state.LastAttack, now, Config.Combat.ComboReset)
	state.LastAttack = now
	local index = state.Combo
	local definition = Config.Combat.Attacks[index]
	state.BusyUntil = now + definition.Recovery
	state.AttackReady = state.BusyUntil
	state.Generation += 1
	local generation = state.Generation
	state.Model:SetAttribute("AttackIndex", index)
	state.Model:SetAttribute("AttackStart", now)
	fx:FireAllClients("Swing", state.Model, state.Root.Position, index)
	local hitOnce = {}
	-- Three short overlap samples form one active window. Each victim is hit once.
	for sample = 0, 2 do
		task.delay(definition.Windup + definition.Active * sample / 2, function()
			if not Registry:Alive(state) or state.Generation ~= generation then return end
			local current = workspace:GetServerTimeNow()
			if current < state.StunUntil or not Movement:ValidateMotion(state, current) then return end
			local reach = state.MagicId == "Anti" and 9 or (state.MagicId == "Water" and state.Awakened and 10 or nil)
			for _, target in Hitbox:Find(state, reach) do
				if hitOnce[target] then continue end
				hitOnce[target] = true
				self:ApplyHit(state, target, definition, index, current, fx)
			end
			if self.MagicHook then self.MagicHook(state, definition, hitOnce, current) end
		end)
	end
	return true
end

return Combat
