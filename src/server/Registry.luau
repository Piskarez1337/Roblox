--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.BlackClover.Shared.Config)
local Rules = require(ReplicatedStorage.BlackClover.Shared.Rules)
local CollectionService = game:GetService("CollectionService")

local Registry = { Actors = {}, ByPlayer = {} }

function Registry:Add(model, player, kind)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	assert(humanoid and root, "Combat actor needs Humanoid and HumanoidRootPart")
	local now = workspace:GetServerTimeNow()
	local state = {
		Model = model, Humanoid = humanoid, Root = root, Player = player, Kind = kind,
		Level = 1, Mana = Config.Player.Mana, MaxMana = Config.Player.Mana,
		Guard = Config.Combat.GuardMax, Blocking = false, Sprinting = false,
		Combo = 0, LastAttack = -math.huge, BusyUntil = 0, StunUntil = 0,
		DashUntil = 0, DashReady = 0, LastDamage = now, LastManaUse = 0, LastGuard = 0,
		LastPosition = root.Position, LastCFrame = root.CFrame, LastMotion = now,
		MotionGrace = now + 1, Generation = 0, Connections = {},
	}
	humanoid.MaxHealth = kind == "Dummy" and Config.Training.DummyHealth
		or (kind == "Enemy" and Config.Training.EnemyHealth or Config.Player.Health)
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = Config.Movement.Walk
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.Movement.Jump
	humanoid.BreakJointsOnDeath = false
	model:SetAttribute("ActorKind", kind)
	model:SetAttribute("Level", 1)
	model:SetAttribute("MagicName", "Без магии")
	model:SetAttribute("AttackStart", 0)
	model:SetAttribute("AttackIndex", 0)
	model:SetAttribute("DashUntil", 0)
	self.Actors[model] = state
	if player then self.ByPlayer[player] = state end
	CollectionService:AddTag(model, "BCActor")
	self:Publish(state)
	return state
end

function Registry:Remove(model)
	local state = self.Actors[model]
	if not state then return end
	state.Generation += 1
	for _, connection in state.Connections do connection:Disconnect() end
	if state.DashConstraint then state.DashConstraint:Destroy() end
	if state.DashAttachment then state.DashAttachment:Destroy() end
	self.Actors[model] = nil
	if state.Player and self.ByPlayer[state.Player] == state then self.ByPlayer[state.Player] = nil end
	CollectionService:RemoveTag(model, "BCActor")
end

function Registry:Alive(state)
	return state and self.Actors[state.Model] == state and state.Model.Parent ~= nil
		and state.Root.Parent ~= nil and state.Humanoid.Health > 0
end

function Registry:Publish(state)
	local model = state.Model
	model:SetAttribute("Mana", state.Mana)
	model:SetAttribute("MaxMana", state.MaxMana)
	model:SetAttribute("Guard", state.Guard)
	model:SetAttribute("Blocking", state.Blocking)
	model:SetAttribute("Sprinting", state.Sprinting)
	model:SetAttribute("StunUntil", state.StunUntil)
	model:SetAttribute("DashReady", state.DashReady)
end

function Registry:FromPart(part)
	local current = part
	while current and current ~= workspace do
		if self.Actors[current] then return self.Actors[current] end
		current = current.Parent
	end
	return nil
end

function Registry:Step(dt, now)
	for _, state in self.Actors do
		if not self:Alive(state) then continue end
		state.MaxMana = Rules.maxMana(Config.Player.Mana, Config.Player.ManaPerLevel, state.Level)
		local manaDt = math.min(dt, math.max(0, now - state.LastManaUse - Config.Player.ManaRegenDelay))
		state.Mana = Rules.regenerate(state.Mana, state.MaxMana, Config.Player.ManaRegen, manaDt)
		if not state.Blocking and now - state.LastGuard >= Config.Combat.GuardRegenDelay then
			local guardDt = math.min(dt, math.max(0, now - state.LastGuard - Config.Combat.GuardRegenDelay))
			state.Guard = Rules.regenerate(state.Guard, Config.Combat.GuardMax, Config.Combat.GuardRegen, guardDt)
		end
		local delay = state.Kind == "Dummy" and 3 or Config.Player.HealthRegenDelay
		if now - state.LastDamage >= delay then
			local rate = state.Kind == "Dummy" and 35 or Config.Player.HealthRegen
			local healthDt = math.min(dt, math.max(0, now - state.LastDamage - delay))
			state.Humanoid.Health = Rules.regenerate(state.Humanoid.Health, state.Humanoid.MaxHealth, rate, healthDt)
		end
	end
end

return Registry
