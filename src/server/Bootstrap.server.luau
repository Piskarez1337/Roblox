--!nonstrict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local Config = require(ReplicatedStorage.BlackClover.Shared.Config)
local Rules = require(ReplicatedStorage.BlackClover.Shared.Rules)
local Registry = require(script.Parent.Registry)
local Movement = require(script.Parent.MovementSystem)
local Combat = require(script.Parent.CombatSystem)
local EnemyAI = require(script.Parent.EnemyAI)
local Magic = require(script.Parent.MagicManager)
local remotes = ReplicatedStorage.BlackClover.Remotes
local request, fx = remotes.Action, remotes.FX
local buckets, connections, fountains = {}, {}, {}
Magic:Start(fx, remotes.MagicFX)

PhysicsService:RegisterCollisionGroup("BCActors")
PhysicsService:CollisionGroupSetCollidable("BCActors", "BCActors", false)
Players.RespawnTime = 3

local function characterAdded(player, model)
	local humanoid = model:WaitForChild("Humanoid", 15)
	local root = model:WaitForChild("HumanoidRootPart", 15)
	if not humanoid or not root or player.Character ~= model then return end
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		warn("Black Clover requires R15; use the supplied StarterCharacter")
		return
	end
	local old = Registry.ByPlayer[player]
	if old then Registry:Remove(old.Model) end
	local state = Registry:Add(model, player, "Player")
	Magic:Initialize(state)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then part.CollisionGroup = "BCActors" end
	end
	table.insert(state.Connections, model.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then part.CollisionGroup = "BCActors" end
	end))
	table.insert(state.Connections, humanoid.Died:Connect(function()
		Magic:Death(state)
		state.Generation += 1
		state.Blocking = false
		state.Sprinting = false
		model:SetAttribute("AttackStart", 0)
		Movement:StopDash(state)
		Registry:Publish(state)
	end))
end

local function playerAdded(player)
	buckets[player] = { Tokens = Config.Network.Burst, Time = workspace:GetServerTimeNow() }
	connections[player] = {
		player.CharacterAdded:Connect(function(model) characterAdded(player, model) end),
		player.CharacterRemoving:Connect(function(model) Registry:Remove(model) end),
	}
	if player.Character then task.spawn(characterAdded, player, player.Character) end
end

Players.PlayerAdded:Connect(playerAdded)
Players.PlayerRemoving:Connect(function(player)
	local state = Registry.ByPlayer[player]
	if state then Registry:Remove(state.Model) end
	for _, connection in connections[player] or {} do connection:Disconnect() end
	buckets[player], connections[player], fountains[player] = nil, nil, nil
	Magic.Profiles[player] = nil
end)
for _, player in Players:GetPlayers() do playerAdded(player) end

request.OnServerEvent:Connect(function(player, action, argument)
	if type(action) ~= "string" or #action > 12 then return end
	local state, bucket = Registry.ByPlayer[player], buckets[player]
	if not Registry:Alive(state) or not bucket then return end
	local now = workspace:GetServerTimeNow()
	local allowed
	allowed, bucket.Tokens = Rules.consumeToken(bucket.Tokens, bucket.Time, now, Config.Network.Rate, Config.Network.Burst)
	bucket.Time = now
	if not allowed then return end
	if not Movement:ValidateMotion(state, now) then return end
	local accepted = false
	if action == "Attack" and argument == nil then
		accepted = Combat:Attack(state, now, fx)
	elseif action == "Dash" then
		accepted = Movement:Dash(state, argument, now, fx)
	elseif action == "Block" and type(argument) == "boolean" then
		accepted = Combat:Block(state, argument, now)
	elseif action == "Sprint" and type(argument) == "boolean" then
		state.Sprinting = argument and not state.Blocking
		Registry:Publish(state)
		accepted = true
	else
		accepted = Magic:Request(state, action, argument, now)
	end
	if not accepted then fx:FireClient(player, "Rejected", action) end
end)

local fountain = workspace:WaitForChild("TrainingGround"):FindFirstChild("RecoveryPrompt", true)
if fountain and fountain:IsA("ProximityPrompt") then
	fountain.Triggered:Connect(function(player)
		local state, now = Registry.ByPlayer[player], workspace:GetServerTimeNow()
		if not Registry:Alive(state) or now < (fountains[player] or 0) then return end
		if (state.Root.Position - fountain.Parent.Position).Magnitude > Config.Training.FountainDistance then return end
		state.Humanoid.Health = state.Humanoid.MaxHealth
		state.Mana, state.Guard = state.MaxMana, Config.Combat.GuardMax
		fountains[player] = now + Config.Training.FountainCooldown
		Registry:Publish(state)
		fx:FireClient(player, "Restored", state.Model, state.Root.Position)
	end)
end

EnemyAI:Start(fx)
local publishElapsed, aiElapsed = 0, 0
RunService.Heartbeat:Connect(function(dt)
	local now = workspace:GetServerTimeNow()
	Registry:Step(dt, now)
	Magic:Step(dt, now)
	Movement:Step(dt, now)
	publishElapsed += dt
	aiElapsed += dt
	if aiElapsed >= 0.1 then aiElapsed = 0; EnemyAI:Step(now) end
	if publishElapsed >= Config.Network.StateInterval then
		publishElapsed = 0
		for _, state in Registry.Actors do Registry:Publish(state) end
	end
end)

print("[Black Clover] Core + 7 magic classes / 44 spells initialized. Studio integration checks still required.")
