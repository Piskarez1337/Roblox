--!nonstrict
local shared = game:GetService("ReplicatedStorage").BlackClover.Shared
local Config, Spells = require(shared.MagicConfig), require(shared.SpellRegistry)
local Rules = require(shared.MagicRules)
local Registry = require(script.Parent.Registry)
local Mana = require(script.Parent.ManaManager)
local Hitbox = require(script.Parent.MagicHitboxService)
local Executor = require(script.Parent.SpellExecutor)
local Awakening = require(script.Parent.AwakeningManager)
local Projectiles = require(script.Parent.ProjectileService)
local Fields = require(script.Parent.FieldService)
local Constructs = require(script.Parent.ConstructService)
local Summons = require(script.Parent.SummonService)
local Motion = require(script.Parent.MagicMotionService)
local Status = require(script.Parent.StatusService)
local World = require(script.Parent.MagicWorld)
local Manager = { Profiles = {}, Serial = 0, Pending = {} }
function Manager:Cancel(state)
	state.MagicEpoch += 1
	state.CastGeneration += 1
	state.Generation += 1
	local pending = self.Pending[state]
	if pending then Executor:Release(pending); self.Pending[state] = nil end
	Projectiles:RemoveOwner(state)
	Fields:RemoveOwner(state)
	Constructs:RemoveOwner(state)
	Summons:Remove(state)
	Motion:RemoveOwner(state)
	state.Shield, state.ParryUntil = nil, 0
	state.Model:SetAttribute("ShieldVisual", "")
	state.Model:SetAttribute("CastSpell", "")
	state.Model:SetAttribute("WeaponOverride", "")
	state.Model:SetAttribute("ParryUntil", 0)
end
function Manager:Initialize(state)
	local saved = state.Player and self.Profiles[state.Player]
	if saved then self:Select(state, saved, workspace:GetServerTimeNow(), true) end
end
function Manager:Select(state, id, now, restoring)
	if type(id) ~= "string" or not Config.Classes[id] or (not restoring and now < state.SelectReady) then return false end
	Awakening:Stop(state, now)
	self:Cancel(state)
	state.MagicId, state.SelectReady = id, now + Config.SelectCooldown
	state.BusyUntil = math.max(now, state.AttackReady)
	state.Blocking = false
	state.Model:SetAttribute("MagicId", id)
	state.Model:SetAttribute("MagicName", Config.Classes[id].Name)
	state.Model:SetAttribute("MeleeProfile", id == "Anti" and "Sword" or "Fist")
	if state.Player then self.Profiles[state.Player] = id end
	Registry:Publish(state)
	return true
end
function Manager:Cast(state, input, now)
	if type(input) ~= "table" or type(input.Slot) ~= "string" or #input.Slot ~= 1 then return false end
	local spell = Spells.Get(state.MagicId, state.Awakened, input.Slot)
	if not spell or now < state.StunUntil or now < state.RootedUntil or now < state.SuppressedUntil or now < state.BusyUntil or state.Blocking then return false end
	if spell.Kind == "Summon" and Summons.Items[state] then Summons:Remove(state); return true end
	if now < (state.Cooldowns[spell.Id] or 0) or state.Mana < spell.ManaCost then return false end
	local point = Hitbox:ResolveAim(state, input.Point, spell.Range)
	if not point then return false end
	local delta = point - state.Root.Position
	local direction = delta.Magnitude > .1 and delta.Unit or state.Root.CFrame.LookVector
	self.Serial += 1
	local context = { Owner = state, Spell = spell, Point = point, Direction = direction, Epoch = state.MagicEpoch,
		Serial = self.Serial, Now = now, CastGeneration = state.CastGeneration + 1 }
	if not Executor:Reserve(context) then return false end
	if not Mana:Spend(state, spell.ManaCost, now) then Executor:Release(context); return false end
	state.CastGeneration = context.CastGeneration
	state.Generation += 1
	state.BusyUntil = now + spell.CastTime + spell.Channel + spell.Recovery
	state.Cooldowns[spell.Id] = now + Rules.cooldown(spell.Cooldown, spell.ElementType, spell.Kind)
	state.Model:SetAttribute("CD_" .. spell.Id, state.Cooldowns[spell.Id])
	state.Model:SetAttribute("CastStart", now)
	state.Model:SetAttribute("CastRelease", now + spell.CastTime)
	state.Model:SetAttribute("CastEnd", state.BusyUntil)
	state.Model:SetAttribute("CastAim", point)
	state.Model:SetAttribute("CastSpell", spell.Id)
	if spell.Weapon then state.Model:SetAttribute("WeaponOverride", spell.Weapon); state.Model:SetAttribute("WeaponUntil", state.BusyUntil + spell.Duration + .4) end
	self.Pending[state] = context
	Registry:Publish(state)
	task.delay(spell.CastTime, function()
		if self.Pending[state] == context then self.Pending[state] = nil end
		if not Registry:Alive(state) or state.CastGeneration ~= context.CastGeneration or state.MagicEpoch ~= context.Epoch
			or workspace:GetServerTimeNow() < state.StunUntil or workspace:GetServerTimeNow() < state.RootedUntil
			or (spell.Awakened and not state.Awakened) then Executor:Release(context); return end
		if not Executor:Execute(context) then
			Executor:Release(context)
			state.Mana = math.min(state.MaxMana, state.Mana + spell.ManaCost)
			state.Cooldowns[spell.Id] = 0
			state.Model:SetAttribute("CD_" .. spell.Id, 0)
			state.Model:SetAttribute("CastSpell", "")
			state.BusyUntil = workspace:GetServerTimeNow()
			if state.Player then self.Remote:FireClient(state.Player, "Notice", "Здесь нельзя применить эту способность") end
		else
			state.ReleasedSerial = context.Serial
		end
	end)
	return true
end
function Manager:Request(state, action, input, now)
	if action == "SelectMagic" then return self:Select(state, input, now)
	elseif action == "Cast" then return self:Cast(state, input, now)
	elseif action == "Awakening" and input == nil then return Awakening:Toggle(state, now)
	elseif action == "Flight" then return Motion:Flight(state, input, now)
	end
	return false
end
function Manager:Start(fx, remote)
	self.Remote = remote
	World:Init(remote)
	Projectiles.FX, Fields.FX, Summons.FX, Motion.FX = fx, fx, fx, fx
	Awakening.Cancel = function(state) self:Cancel(state) end
	Registry.OnRemoving = function(state) self:Cancel(state) end
	require(script.Parent.CombatSystem).MagicHook = function(state, definition, seen)
		if state.MagicId == "Anti" then Projectiles:Cut(state, state.Awakened and 52 or 28, 9) end
		Constructs:Melee(state, definition.Damage, seen)
	end
end
function Manager:Death(state)
	Awakening:Stop(state, workspace:GetServerTimeNow())
	self:Cancel(state)
	state.Awakened = false
	state.Model:SetAttribute("Awakened", false)
end
function Manager:Step(dt, now)
	Awakening:Step(now)
	for _, state in Registry.Actors do
		if now < state.SuppressedUntil and state.LastSuppression ~= state.SuppressedUntil then
			state.LastSuppression = state.SuppressedUntil
			self:Cancel(state)
		end
		if (state.Model:GetAttribute("CastEnd") or 0) <= now and state.Model:GetAttribute("CastSpell") ~= "" then state.Model:SetAttribute("CastSpell", "") end
	end
	Status:Step(now)
	Motion:Step(dt, now)
	Projectiles:Step(dt, now)
	Fields:Step(dt, now)
	Constructs:Step(now)
	self.AITime = (self.AITime or 0) + dt
	if self.AITime >= .1 then self.AITime = 0; Summons:Step(now) end
end
return Manager
