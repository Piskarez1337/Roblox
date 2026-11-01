--!nonstrict
local shared = game:GetService("ReplicatedStorage").BlackClover.Shared
local Config = require(shared.Config)
local MagicConfig = require(shared.MagicConfig)
local Rules = require(shared.Rules)
local MagicRules = require(shared.MagicRules)
local Mana = {}
function Mana:Spend(state, cost, now)
	local ok, value = Rules.spend(state.Mana, cost)
	if ok then state.Mana, state.LastManaUse = value, now end
	return ok
end
function Mana:Step(state, dt, now)
	state.MaxMana = Rules.maxMana(Config.Player.Mana, Config.Player.ManaPerLevel, state.Level)
	local class = MagicConfig.Classes[state.MagicId]
	if state.Awakened and class then
		state.Mana = MagicRules.manaAfter(state.Mana, state.MaxMana, dt, true, class.Drain, 0)
		state.LastManaUse = now
	else
		local eligible = math.min(dt, math.max(0, now - state.LastManaUse - Config.Player.ManaRegenDelay))
		state.Mana = MagicRules.manaAfter(state.Mana, state.MaxMana, eligible, false, 0, Config.Player.ManaRegen)
	end
end
return Mana
