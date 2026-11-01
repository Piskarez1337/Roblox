--!nonstrict
-- Run manually in Studio Play mode's SERVER Command Bar:
-- require(game.ServerStorage.Stage1Tests).Run()
local Tests = {}

function Tests.Run()
	assert(game:GetService("RunService"):IsServer(), "Run on the server, not a client")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerStorage = game:GetService("ServerStorage")
	local folder = game:GetService("ServerScriptService").BlackCloverServer
	local Registry = require(folder.Registry)
	local Combat = require(folder.CombatSystem)
	local Hitbox = require(folder.Hitbox)
	local Movement = require(folder.MovementSystem)
	local Config = require(ReplicatedStorage.BlackClover.Shared.Config)
	local objects, actors, checks = {}, {}, 0
	local function check(value, message)
		assert(value, message)
		checks += 1
	end
	local function spawn(cf)
		local model = ServerStorage.Actors.Dummy:Clone()
		model.Name = "IntegrationTestActor"
		model:PivotTo(cf)
		model.Parent = workspace
		table.insert(objects, model)
		local state = Registry:Add(model, nil, "Dummy")
		state.Root.Anchored = true
		table.insert(actors, model)
		return state
	end
	local ok, problem = xpcall(function()
		check(ReplicatedStorage.BlackClover.Remotes.Action:IsA("RemoteEvent"), "Action remote missing")
		check(workspace.TrainingGround:FindFirstChild("RecoveryPrompt", true) ~= nil, "recovery fountain missing")
		local source = spawn(CFrame.new(0, 180, 0))
		local target = spawn(CFrame.new(0, 180, -4) * CFrame.Angles(0, math.pi, 0))
		-- Player is a combat category here; no real user is mutated.
		source.Kind = "Player"
		check(source.Humanoid.RigType == Enum.HumanoidRigType.R15, "R15 rig flag")
		local motors = 0
		for _, object in source.Model:GetDescendants() do
			if object:IsA("Motor6D") then
				motors += 1
				check(object.Part0 and object.Part1, "unbound motor " .. object.Name)
			end
		end
		check(motors == 15, "R15 needs 15 connected motors")
		check(#Hitbox:Find(source) == 1, "nearby target ahead should be found once")
		target.Model:PivotTo(CFrame.new(0, 180, 4))
		check(#Hitbox:Find(source) == 0, "target behind must not be hit")
		target.Model:PivotTo(CFrame.new(0, 180, -12))
		check(#Hitbox:Find(source) == 0, "distant target must not be hit")
		target.Model:PivotTo(CFrame.new(0, 180, -4) * CFrame.Angles(0, math.pi, 0))
		local wall = Instance.new("Part")
		wall.Anchored = true
		wall.Size = Vector3.new(8, 10, 0.5)
		wall.Position = Vector3.new(0, 180, -2)
		wall.Parent = workspace
		table.insert(objects, wall)
		check(#Hitbox:Find(source) == 0, "wall must block melee")
		wall:Destroy()
		local events = 0
		local sink = { FireAllClients = function() events += 1 end }
		local now = workspace:GetServerTimeNow()
		local before = target.Humanoid.Health
		Combat:ApplyHit(source, target, Config.Combat.Attacks[1], 1, now, sink)
		check(target.Humanoid.Health == before - 10, "server hit damage")
		check(target.StunUntil > now, "hit stun")
		target.StunUntil, target.Blocking, target.Guard = 0, true, 60
		before = target.Humanoid.Health
		Combat:ApplyHit(source, target, Config.Combat.Attacks[1], 1, now, sink)
		check(target.Humanoid.Health == before - 2, "front-facing block")
		target.Root.CFrame = CFrame.new(0, 180, -4)
		before = target.Humanoid.Health
		Combat:ApplyHit(source, target, Config.Combat.Attacks[1], 1, now, sink)
		check(target.Humanoid.Health == before - 10, "rear hit bypasses guard")
		target.Root.CFrame = CFrame.new(0, 180, -4) * CFrame.Angles(0, math.pi, 0)
		target.Guard, target.Blocking, target.StunUntil = 8, true, 0
		Combat:ApplyHit(source, target, Config.Combat.Attacks[1], 1, now, sink)
		check(target.Guard == 0 and not target.Blocking, "guard break clears block")
		check(target.StunUntil >= now + Config.Combat.GuardBreakStun, "guard break stun duration")
		check(events == 4, "one VFX notification per resolved hit")
		check(not Movement:Dash(source, Vector3.new(0 / 0, 0, 0), now, sink), "NaN dash rejected")
		check(not Movement:Dash(source, "forward", now, sink), "non-vector dash rejected")
		target.Blocking, target.StunUntil = false, 0
		target.Humanoid.Health = target.Humanoid.MaxHealth
		check(Combat:Attack(source, now, sink), "first attack accepted")
		for _ = 1, 100 do check(not Combat:Attack(source, now, sink), "attack spam accepted during recovery") end
		task.wait(Config.Combat.Attacks[1].Recovery + 0.1)
		check(target.Humanoid.Health == target.Humanoid.MaxHealth - 10, "three overlap samples must damage once")
		before = target.Humanoid.Health
		check(Combat:Attack(source, workspace:GetServerTimeNow(), sink), "attack after recovery accepted")
		Registry:Remove(source.Model)
		task.wait(Config.Combat.Attacks[2].Recovery + 0.1)
		check(target.Humanoid.Health == before, "removed actor must not land a pending hit")
	end, debug.traceback)
	for _, model in actors do Registry:Remove(model) end
	for _, object in objects do object:Destroy() end
	assert(ok, problem)
	print(string.format("[Black Clover] PASS: %d Studio integration assertions", checks))
	return checks
end

return Tests
