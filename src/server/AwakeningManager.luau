--!nonstrict
local Config = require(game:GetService("ReplicatedStorage").BlackClover.Shared.MagicConfig)
local Registry = require(script.Parent.Registry)
local Awakening = {}
function Awakening:Stop(state, now)
	if not state.Awakened then return end
	state.Awakened = false
	if self.Cancel then self.Cancel(state) end
	state.BusyUntil = math.max(now, state.AttackReady)
	state.LastManaUse = now
	state.Model:SetAttribute("Awakened", false)
	state.Model:SetAttribute("TransformStart", 0)
	state.Model:SetAttribute("MeleeProfile", state.MagicId == "Anti" and "Sword" or "Fist")
end
function Awakening:Toggle(state, now)
	if state.Awakened then self:Stop(state, now); return true end
	local class = Config.Classes[state.MagicId]
	if not class or class.Drain <= 0 or state.Mana < Config.ActivationMinimum or now < state.AwakeningReady
		or now < state.StunUntil or now < state.RootedUntil or now < state.SuppressedUntil or now < state.BusyUntil then return false end
	if self.Cancel then self.Cancel(state) end
	state.Awakened = true
	state.AwakeningReady = now + Config.ToggleCooldown
	state.BusyUntil = now + Config.TransformTime
	state.Blocking = false
	state.Model:SetAttribute("Awakened", true)
	state.Model:SetAttribute("TransformStart", now)
	state.Model:SetAttribute("AwakeningReady", state.AwakeningReady)
	state.Model:SetAttribute("MeleeProfile", state.MagicId == "Anti" and "Sword" or (state.MagicId == "Water" and "Spear" or (state.MagicId == "Wind" and "WindWeapon" or "Fist")))
	return true
end
function Awakening:Step(now)
	for _, state in Registry.Actors do
		if state.Awakened and (not Registry:Alive(state) or state.Mana <= 0 or now < state.SuppressedUntil) then self:Stop(state, now) end
	end
end
return Awakening
