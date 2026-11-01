--!nonstrict
local shared = game:GetService("ReplicatedStorage").BlackClover.Shared
local Config, Rules = require(shared.Config), require(shared.Rules)
local Registry = require(script.Parent.Registry)
local Movement = require(script.Parent.MovementSystem)
local Passive = require(script.Parent.PassiveService)
local Targeting = require(script.Parent.MagicHitboxService)
local Damage = {}
function Damage:Apply(source, target, info, now, fx)
	if not Targeting:CanHit(source, target) or target.Model:FindFirstChildOfClass("ForceField") then return 0 end
	local delta = (info.Origin or source.Root.Position) - target.Root.Position
	local direction = delta.Magnitude > .01 and delta.Unit or target.Root.CFrame.LookVector
	local guarding = info.Blockable ~= false and target.Blocking and target.Root.CFrame.LookVector:Dot(direction) >= Config.Combat.BlockFacingDot
	local damage, broken = Passive:Damage(target, info.Damage, info.Element ~= nil), false
	if source.MagicId == "Anti" and not info.Element and now < (source.CounterUntil or 0) then
		damage *= 1.2
		source.CounterUntil = 0
	end
	if target.Shield and now < target.Shield.Until then
		local prevented = math.min(target.Shield.HP, damage * target.Shield.Reduction)
		target.Shield.HP -= prevented
		damage -= prevented
		if target.Shield.HP <= 0 then target.Shield = nil; target.Model:SetAttribute("ShieldVisual", "") end
	end
	if guarding then
		damage, target.Guard, broken = Rules.guardHit(damage, target.Guard, info.Guard or math.max(8, info.Damage * .7), Config.Combat.BlockDamageFactor)
		target.LastGuard = now
	end
	target.LastDamage, source.LastDamage = now, now
	if not guarding or broken then
		target.Blocking = false
		local stun = broken and Config.Combat.GuardBreakStun or (info.Stun or .12)
		target.StunUntil = math.max(target.StunUntil, now + stun)
		if stun > 0 then
			target.Generation += 1
			target.CastGeneration += 1
			target.Model:SetAttribute("CastSpell", "")
			target.Model:SetAttribute("AttackStart", 0)
			target.Model:SetAttribute("HitAt", now)
			Movement:StopDash(target)
		end
		if not target.Root.Anchored and now >= target.RootedUntil then
			target.MotionGrace = now + .7
			target.Root:SetNetworkOwner(nil)
			local push = -Vector3.new(direction.X, 0, direction.Z) * (info.Knockback or 0) * Passive:Knockback(target)
			target.Root:ApplyImpulse((push + Vector3.new(0, info.Lift or 0, 0)) * target.Root.AssemblyMass)
			task.delay(.25, function()
				if Registry:Alive(target) and target.Player and not target.DashDirection and not target.FlightConstraint
					and workspace:GetServerTimeNow() >= target.RootedUntil then target.Root:SetNetworkOwnershipAuto() end
			end)
		end
	end
	local before = target.Humanoid.Health
	target.Humanoid:TakeDamage(damage)
	local dealt = before - target.Humanoid.Health
	if dealt > 0 then
		Passive:AfterHit(source, target, dealt, info.Element, now)
		if info.Suppress then target.SuppressedUntil = math.max(target.SuppressedUntil, now + info.Suppress) end
	end
	Registry:Publish(target)
	if fx then fx:FireAllClients(broken and "GuardBreak" or (guarding and "Block" or "Hit"), target.Model,
		target.Root.Position, dealt, source.Model, info.Index or 1, info.Element) end
	return dealt
end
function Damage:Spell(source, target, spell, now, fx, multiplier, origin)
	return self:Apply(source, target, { Damage = spell.Damage * (multiplier or 1), Element = spell.ElementType,
		Stun = spell.Stun, Knockback = spell.Knockback, Suppress = spell.Suppress, Origin = origin, Index = spell.Awakened and 4 or 1 }, now, fx)
end
return Damage
