--!nonstrict
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Pose = require(game:GetService("ReplicatedStorage").BlackClover.Shared:WaitForChild("PoseLibrary"))
local Config = require(game:GetService("ReplicatedStorage").BlackClover.Shared.Config)
local Controller = { Actors = {}, Prediction = nil }

function Controller:Add(model)
	if self.Actors[model] then return end
	local entry = { Motors = {}, Phase = 0, Speed = 0, BrakeAt = 0 }
	self.Actors[model] = entry
	local function addMotor(item)
		if item:IsA("Motor6D") then entry.Motors[item.Name] = item end
	end
	for _, item in model:GetDescendants() do addMotor(item) end
	entry.Connection = model.DescendantAdded:Connect(addMotor)
end

function Controller:Remove(model)
	local entry = self.Actors[model]
	if not entry then return end
	entry.Connection:Disconnect()
	for _, motor in entry.Motors do if motor.Parent then motor.Transform = CFrame.identity end end
	self.Actors[model] = nil
	if self.Prediction and self.Prediction.Model == model then self.Prediction = nil end
end

function Controller:Predict(model, index, now)
	self.Prediction = { Model = model, Index = index, Start = now, Previous = model:GetAttribute("AttackStart") or 0 }
end

function Controller:CancelPrediction() self.Prediction = nil end

function Controller:Start()
	for _, model in CollectionService:GetTagged("BCActor") do self:Add(model) end
	CollectionService:GetInstanceAddedSignal("BCActor"):Connect(function(model) self:Add(model) end)
	CollectionService:GetInstanceRemovedSignal("BCActor"):Connect(function(model) self:Remove(model) end)
	RunService.PreSimulation:Connect(function(dt)
		local now = workspace:GetServerTimeNow()
		for model, entry in self.Actors do
			local root, humanoid = model:FindFirstChild("HumanoidRootPart"), model:FindFirstChildOfClass("Humanoid")
			if not root or not humanoid then continue end
			local camera = workspace.CurrentCamera
			if camera and (root.Position - camera.CFrame.Position).Magnitude > Config.Network.MaxVFXDistance then continue end
			local localVelocity = root.CFrame:VectorToObjectSpace(root.AssemblyLinearVelocity)
			local speed = Vector3.new(localVelocity.X, 0, localVelocity.Z).Magnitude
			if entry.Speed > 18 and speed < 3 then entry.BrakeAt = now end
			entry.Speed = speed
			entry.Phase += dt * (speed > 0.7 and speed * 0.63 or 2)
			local airborne = humanoid.FloorMaterial == Enum.Material.Air and not root.Anchored
			local pose = Pose.Locomotion(speed, model:GetAttribute("Sprinting") == true, airborne, entry.Phase, localVelocity)
			local index, start = model:GetAttribute("AttackIndex") or 0, model:GetAttribute("AttackStart") or 0
			local prediction = self.Prediction
			if prediction and prediction.Model == model then
				if start ~= prediction.Previous or now - prediction.Start > 0.4 then
					self.Prediction = nil
				else
					index, start = prediction.Index, prediction.Start
				end
			end
			local attack = start > 0 and Pose.Attack(index, now - start)
			if humanoid.Health <= 0 then pose = {}
			elseif (model:GetAttribute("StunUntil") or 0) > now then pose = Pose.Stagger(now - (model:GetAttribute("HitAt") or now))
			elseif (model:GetAttribute("DashUntil") or 0) > now then pose = Pose.Dash()
			elseif attack then pose = attack
			elseif model:GetAttribute("Blocking") then pose = Pose.Block()
			elseif now - entry.BrakeAt < 0.24 then pose = Pose.Brake(1 - (now - entry.BrakeAt) / 0.24) end
			local smoothing = 1 - math.exp(-(attack and 42 or 17) * dt)
			for name, motor in entry.Motors do
				if motor.Parent then motor.Transform = motor.Transform:Lerp(pose[name] or CFrame.identity, smoothing) end
			end
		end
	end)
end

return Controller
