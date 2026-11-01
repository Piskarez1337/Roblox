--!nonstrict
local Config = require(game:GetService("ReplicatedStorage").BlackClover.Shared.Config)
local Rules = require(game:GetService("ReplicatedStorage").BlackClover.Shared.Rules)
local Registry = require(script.Parent.Registry)
local Hitbox = require(script.Parent.Hitbox)
local Movement = require(script.Parent.MovementSystem)
local Combat = {}

function Combat:Block(state, enabled, now)
	if not enabled then state.Blocking = false; Registry:Publish(state); return true end
	if not Registry:Alive(state) or not Rules.canAct(state.Humanoid.Health, now, state.BusyUntil, state.StunUntil)
		or state.Guard < 8 then return false end
	state.Blocking = true
	state.Sprinting = false
	Registry:Publish(state)
	return true
end

function Combat:ApplyHit(source, target, definition, index, now, fx)
	if not Registry:Alive(source) or not Registry:Alive(target) then return end
	if target.Model:FindFirstChildOfClass("ForceField") then return end
	local delta = source.Root.Position - target.Root.Position
	local direction = delta.Magnitude > 0.01 and delta.Unit or target.Root.CFrame.LookVector
	local guarding = target.Blocking and target.Root.CFrame.LookVector:Dot(direction) >= Config.Combat.BlockFacingDot
	local damage, broken = definition.Damage, false
	if guarding then
		damage, target.Guard, broken = Rules.guardHit(damage, target.Guard, definition.Guard, Config.Combat.BlockDamageFactor)
		target.LastGuard = now
	end
	target.LastDamage = now
	source.LastDamage = now -- health recovery pauses for both sides of a fight
	if not guarding or broken then
		target.Blocking = false
		target.StunUntil = math.max(target.StunUntil, now + (broken and Config.Combat.GuardBreakStun or definition.Stun))
		target.Generation += 1 -- cancel the victim's pending attack windows
		target.Model:SetAttribute("AttackStart", 0)
		target.Model:SetAttribute("HitAt", now)
		Movement:StopDash(target)
		if not target.Root.Anchored then
			target.MotionGrace = now + 0.7
			target.Root:SetNetworkOwner(nil)
			local push = -Vector3.new(direction.X, 0, direction.Z)
			local velocity = push * definition.Knockback + Vector3.new(0, index == 4 and 7 or 0, 0)
			target.Root:ApplyImpulse(velocity * target.Root.AssemblyMass)
			task.delay(0.25, function()
				if Registry:Alive(target) and target.Player and not target.DashDirection then
					target.Root:SetNetworkOwnershipAuto()
				end
			end)
		end
	end
	target.Humanoid:TakeDamage(damage)
	Registry:Publish(target)
	fx:FireAllClients(broken and "GuardBreak" or (guarding and "Block" or "Hit"), target.Model,
		target.Root.Position, damage, source.Model, index)
end

function Combat:Attack(state, now, fx)
	if not Registry:Alive(state) or not Rules.canAct(state.Humanoid.Health, now, state.BusyUntil, state.StunUntil)
		or state.Blocking then return false end
	state.Combo = Rules.nextCombo(state.Combo, state.LastAttack, now, Config.Combat.ComboReset)
	state.LastAttack = now
	local index = state.Combo
	local definition = Config.Combat.Attacks[index]
	state.BusyUntil = now + definition.Recovery
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
			for _, target in Hitbox:Find(state) do
				if hitOnce[target] then continue end
				hitOnce[target] = true
				self:ApplyHit(state, target, definition, index, current, fx)
			end
		end)
	end
	return true
end

return Combat
