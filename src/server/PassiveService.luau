--!nonstrict
local P = require(game:GetService("ReplicatedStorage").BlackClover.Shared.MagicConfig).Passives
local Passive = {}
function Passive:Damage(target, damage, magical)
	if target.MagicId == "Water" then damage *= P.WaterDefense end
	if target.MagicId == "Earth" then damage *= P.EarthDefense end
	if magical and target.MagicId == "Anti" then damage *= P.AntiDefense end
	return damage
end
function Passive:Speed(state, now)
	local multiplier = state.MagicId == "Wind" and P.WindSpeed or 1
	if now < (state.SlowUntil or 0) then multiplier *= 1 - math.min(P.IceStacks, state.SlowStacks or 0) * P.IceSlowPerStack end
	return multiplier
end
function Passive:AfterHit(source, target, damage, element, now)
	if element == "Ice" then
		if now >= target.SlowUntil then target.SlowStacks = 0 end
		target.SlowStacks = math.min(P.IceStacks, target.SlowStacks + 1)
		target.SlowUntil = now + P.IceDuration
		if target.SlowStacks == P.IceStacks and now >= (target.FreezeReady or 0) then
			target.RootedUntil = math.max(target.RootedUntil, now + .6)
			target.RootAnchor = target.Root.Position
			target.CastGeneration += 1
			target.Generation += 1
			target.Model:SetAttribute("CastSpell", "")
			target.Model:SetAttribute("AttackStart", 0)
			target.FreezeReady = now + 4
		end
	end
	if element == "Bone" and source.MagicId == "Bone" and damage > 0 then
		if now - (source.LeechWindow or 0) >= 1 then source.LeechWindow, source.LeechUsed = now, 0 end
		local heal = math.min(damage * P.BoneLeech, P.BoneHealPerSecond - (source.LeechUsed or 0))
		source.LeechUsed = (source.LeechUsed or 0) + heal
		source.Humanoid.Health = math.min(source.Humanoid.MaxHealth, source.Humanoid.Health + heal)
	end
end
function Passive:Knockback(state)
	return state.MagicId == "Earth" and P.EarthKnockback or 1
end
return Passive
