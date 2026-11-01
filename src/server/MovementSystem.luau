--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.BlackClover.Shared.Config)
local Rules = require(ReplicatedStorage.BlackClover.Shared.Rules)
local Registry = require(script.Parent.Registry)
local Movement = {}

function Movement:StopDash(state)
	if state.DashConstraint then state.DashConstraint:Destroy(); state.DashConstraint = nil end
	if state.DashAttachment then state.DashAttachment:Destroy(); state.DashAttachment = nil end
	if state.DashDirection then
		state.DashDirection = nil
		state.DashUntil = 0
		state.Model:SetAttribute("DashUntil", 0)
		if state.Root.Parent and not state.Root.Anchored then
			local velocity = state.Root.AssemblyLinearVelocity
			state.Root.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
			if state.Player then state.Root:SetNetworkOwnershipAuto() end
		end
	end
end

function Movement:ValidateMotion(state, now)
	if not state.Player or not Registry:Alive(state) then return true end
	local elapsed = now - state.LastMotion
	if elapsed < 0.08 then return true end
	local delta = state.Root.Position - state.LastPosition
	local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local allowance = Config.Movement.Sprint * elapsed + 5
	local valid = now <= state.MotionGrace or horizontal <= allowance
	if not valid then
		state.Root.CFrame = state.LastCFrame
		state.Root.AssemblyLinearVelocity = Vector3.zero
		state.StunUntil = math.max(state.StunUntil, now + 0.25)
	end
	state.LastPosition = state.Root.Position
	state.LastCFrame = state.Root.CFrame
	state.LastMotion = now
	return valid
end

function Movement:Dash(state, requested, now, fx)
	if not Registry:Alive(state) or not Rules.canAct(state.Humanoid.Health, now, state.BusyUntil, state.StunUntil)
		or state.Blocking or now < state.DashReady then return false end
	if typeof(requested) ~= "Vector3" or not Rules.finite(requested.X) or not Rules.finite(requested.Y)
		or not Rules.finite(requested.Z) or requested.Magnitude > 2 then return false end
	-- Stage 1 dash is grounded. Air dash is an explicit later system.
	if state.Humanoid.FloorMaterial == Enum.Material.Air then return false end
	local direction = Vector3.new(requested.X, 0, requested.Z)
	if direction.Magnitude < 0.1 then
		local look = state.Root.CFrame.LookVector
		direction = Vector3.new(look.X, 0, look.Z)
	end
	if direction.Magnitude < 0.01 then return false end
	direction = direction.Unit
	local ok, remaining = Rules.spend(state.Mana, Config.Movement.DashMana)
	if not ok then return false end
	state.Mana = remaining
	state.LastManaUse = now
	state.DashUntil = now + Config.Movement.DashDuration
	state.DashReady = now + Config.Movement.DashCooldown
	state.BusyUntil = state.DashUntil
	state.MotionGrace = state.DashUntil + 0.35
	state.DashDirection = direction
	state.Root:SetNetworkOwner(nil)
	local attachment = Instance.new("Attachment")
	attachment.Name = "DashAttachment"
	attachment.Parent = state.Root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "DashVelocity"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.VectorVelocity = direction * Config.Movement.DashSpeed
	velocity.ForceLimitsEnabled = true
	velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	velocity.MaxAxesForce = Vector3.new(80000, 0, 80000)
	velocity.Parent = state.Root
	state.DashAttachment = attachment
	state.DashConstraint = velocity
	state.Model:SetAttribute("DashUntil", state.DashUntil)
	Registry:Publish(state)
	fx:FireAllClients("Dash", state.Model, state.Root.Position)
	return true
end

function Movement:Step(dt, now)
	for _, state in Registry.Actors do
		if not Registry:Alive(state) then self:StopDash(state); continue end
		self:ValidateMotion(state, now)
		local stunned = now < state.StunUntil
		if state.DashDirection then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { state.Model }
			local travel = state.DashDirection * (Config.Movement.DashSpeed * math.min(dt, 0.1) + 2)
			local hit = workspace:Blockcast(state.Root.CFrame, Vector3.new(1.8, 2.8, 1.8), travel, params)
			if now >= state.DashUntil or stunned or hit then self:StopDash(state) end
		end
		local speed = Config.Movement.Walk
		if state.Kind == "Dummy" then speed = 0
		elseif stunned or state.DashDirection then speed = 0
		elseif state.Blocking then speed = Config.Movement.Block
		elseif now < state.BusyUntil then speed = 9
		elseif state.Sprinting then speed = Config.Movement.Sprint end
		state.Humanoid.WalkSpeed = speed
		state.Humanoid.JumpPower = (stunned or state.Blocking or now < state.BusyUntil) and 0 or Config.Movement.Jump
		state.Humanoid.AutoRotate = not state.DashDirection and not stunned
		if stunned then state.Blocking = false end
	end
end

return Movement
