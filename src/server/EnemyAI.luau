--!nonstrict
local ServerStorage = game:GetService("ServerStorage")
local Config = require(game:GetService("ReplicatedStorage").BlackClover.Shared.Config)
local Registry = require(script.Parent.Registry)
local Combat = require(script.Parent.CombatSystem)
local EnemyAI = { Slots = {}, Folder = nil, FX = nil }

function EnemyAI:Spawn(slot)
	local template = ServerStorage.Actors:FindFirstChild(slot.Kind)
	local model = template:Clone()
	model.Name = slot.Kind == "Dummy" and "Тренировочный манекен" or "Каменный часовой"
	model:PivotTo(slot.CFrame)
	model.Parent = self.Folder
	local state = Registry:Add(model, nil, slot.Kind)
	state.Root:SetNetworkOwner(nil)
	if slot.Kind == "Dummy" then state.Root.Anchored = true end
	slot.State = state
	slot.NextAttack = 0
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then part.CollisionGroup = "BCActors" end
	end
	table.insert(state.Connections, state.Humanoid.Died:Connect(function()
		state.Generation += 1
		task.delay(Config.Training.Respawn, function()
			Registry:Remove(model)
			model:Destroy()
			self:Spawn(slot)
		end)
	end))
end

function EnemyAI:Start(fx)
	self.FX = fx
	self.Folder = Instance.new("Folder")
	self.Folder.Name = "TrainingActors"
	self.Folder.Parent = workspace
	self.Slots = {
		{ Kind = "Dummy", CFrame = CFrame.new(-11, 4, 0) * CFrame.Angles(0, math.pi, 0) },
		{ Kind = "Dummy", CFrame = CFrame.new(11, 4, 0) * CFrame.Angles(0, math.pi, 0) },
		{ Kind = "Enemy", CFrame = CFrame.new(-24, 4, -27) * CFrame.Angles(0, math.pi, 0) },
		{ Kind = "Enemy", CFrame = CFrame.new(24, 4, -27) * CFrame.Angles(0, math.pi, 0) },
	}
	for _, slot in self.Slots do self:Spawn(slot) end
end

function EnemyAI:Step(now)
	for _, slot in self.Slots do
		local state = slot.State
		if slot.Kind ~= "Enemy" or not Registry:Alive(state) or now < state.StunUntil then continue end
		local target, distance = nil, Config.Training.EnemyAggro
		for _, candidate in Registry.Actors do
			if candidate.Kind ~= "Player" and candidate.Kind ~= "Golem" then continue end
			if not Registry:Alive(candidate) then continue end
			if (candidate.Root.Position - slot.CFrame.Position).Magnitude > Config.Training.EnemyLeash then continue end
			local d = (candidate.Root.Position - state.Root.Position).Magnitude
			if d < distance then target, distance = candidate, d end
		end
		if target then
			if distance > 5 then
				state.Humanoid:MoveTo(target.Root.Position)
			else
				state.Humanoid:MoveTo(state.Root.Position)
				if now >= slot.NextAttack and now >= state.BusyUntil then
					local flat = Vector3.new(target.Root.Position.X, state.Root.Position.Y, target.Root.Position.Z)
					if (flat - state.Root.Position).Magnitude > 0.1 then state.Root.CFrame = CFrame.lookAt(state.Root.Position, flat) end
					Combat:Attack(state, now, self.FX)
					slot.NextAttack = now + Config.Training.EnemyAttackGap
				end
			end
		else
			state.Humanoid:MoveTo(slot.CFrame.Position)
		end
	end
end

return EnemyAI
