--!nonstrict
local Config = require(game:GetService("ReplicatedStorage").BlackClover.Shared.MagicConfig)
local Registry = require(script.Parent.Registry)
local Hitbox = require(script.Parent.MagicHitboxService)
local Movement = require(script.Parent.MovementSystem)
local Damage = require(script.Parent.DamageService)
local Projectiles = require(script.Parent.ProjectileService)
local World = require(script.Parent.MagicWorld)
local Motion = { Dashes = {} }
local function constraint(state, velocity, aerial, name)
	local attachment = Instance.new("Attachment")
	attachment.Name, attachment.Parent = name .. "Attachment", state.Root
	local mover = Instance.new("LinearVelocity")
	mover.Name, mover.Attachment0 = name, attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	mover.ForceLimitsEnabled, mover.ForceLimitMode = true, Enum.ForceLimitMode.PerAxis
	mover.MaxAxesForce = Vector3.new(100000, aerial and 100000 or 0, 100000)
	mover.VectorVelocity, mover.Parent = velocity, state.Root
	state.Root:SetNetworkOwner(nil)
	return mover, attachment
end
function Motion:Dash(context)
	local source, spell, now = context.Owner, context.Spell, workspace:GetServerTimeNow()
	local direction = context.Direction
	if not spell.Aerial then direction = Vector3.new(direction.X, 0, direction.Z) end
	if direction.Magnitude < .01 then direction = source.Root.CFrame.LookVector end
	direction = direction.Unit
	self:StopFlight(source)
	Movement:StopDash(source)
	source.DashDirection, source.DashSpeed = direction, spell.Speed
	source.DashUntil, source.MotionGrace = now + spell.Duration, now + spell.Duration + .5
	source.BusyUntil = math.max(source.BusyUntil, source.DashUntil)
	source.DashConstraint, source.DashAttachment = constraint(source, direction * spell.Speed, spell.Aerial, "MagicDash")
	source.Model:SetAttribute("DashUntil", source.DashUntil)
	self.Dashes[source] = { Context = context, Until = source.DashUntil, Previous = source.Root.Position, Seen = {} }
	return true
end
function Motion:Teleport(context)
	local source = context.Owner
	local ground = Hitbox:Ground(context.Point, source)
	if not ground then return false end
	local elevation = source.Humanoid.HipHeight + source.Root.Size.Y / 2
	local destination = ground + Vector3.new(0, elevation, 0)
	local delta = destination - source.Root.Position
	if delta.Magnitude > context.Spell.Range + 1 or delta.Magnitude < 2 then return false end
	local block = workspace:Blockcast(source.Root.CFrame, Vector3.new(2.2, 4.8, 2.2), delta, Hitbox:WorldParams(source))
	if block then destination = source.Root.Position + delta.Unit * math.max(0, block.Distance - 1.2) end
	if (destination - source.Root.Position).Magnitude < 2 then return false end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = Hitbox:WorldParams(source).FilterDescendantsInstances
	params.RespectCanCollide = true
	for _, part in workspace:GetPartBoundsInBox(CFrame.new(destination), Vector3.new(2, 4.6, 2), params) do
		if part.CanCollide then return false end
	end
	World:Pulse("Teleport", source.Root.Position, "Stars", 6)
	source.Root.CFrame = CFrame.new(destination) * source.Root.CFrame.Rotation
	source.Root.AssemblyLinearVelocity = Vector3.zero
	source.LastPosition, source.LastCFrame = destination, source.Root.CFrame
	source.MotionGrace = workspace:GetServerTimeNow() + .7
	World:Pulse("Teleport", destination, "Stars", 6)
	return true
end
function Motion:StopFlight(state)
	if state.FlightConstraint then state.FlightConstraint:Destroy(); state.FlightConstraint = nil end
	if state.FlightAttachment then state.FlightAttachment:Destroy(); state.FlightAttachment = nil end
	state.FlightUntil = 0
	state.Model:SetAttribute("FlightUntil", 0)
	if Registry:Alive(state) and state.Player and not state.Root.Anchored and not state.DashDirection and not state.ControlOwned then state.Root:SetNetworkOwnershipAuto() end
end
function Motion:Flight(state, input, now)
	if type(input) ~= "table" or type(input.Active) ~= "boolean" then return false end
	if not input.Active then self:StopFlight(state); return true end
	if not Hitbox:PointIsValid(input.Direction) or input.Direction.Magnitude > 1.1 then return false end
	if not state.Awakened or (state.MagicId ~= "Wind" and state.MagicId ~= "Anti") or now < state.StunUntil
		or now < state.RootedUntil or state.DashDirection then return false end
	if not state.FlightConstraint then
		if now < state.FlightReady or now < state.BusyUntil then return false end
		state.FlightUntil, state.FlightReady = now + Config.Flight.Duration, now + Config.Flight.Cooldown
		state.FlightConstraint, state.FlightAttachment = constraint(state, Vector3.zero, true, "AwakeningFlight")
		state.Model:SetAttribute("FlightUntil", state.FlightUntil)
		state.Model:SetAttribute("FlightReady", state.FlightReady)
	end
	state.FlightInput, state.FlightLastInput = input.Direction, now
	return true
end
function Motion:Step(dt, now)
	for source, dash in self.Dashes do
		local context = dash.Context
		if not Registry:Alive(source) or source.MagicEpoch ~= context.Epoch then self.Dashes[source] = nil; Movement:StopDash(source); continue end
		for _, entry in Hitbox:Segment(source, dash.Previous, source.Root.Position, context.Spell.Radius) do
			if not dash.Seen[entry.State] then dash.Seen[entry.State] = true; Damage:Spell(source, entry.State, context.Spell, now, self.FX) end
		end
		if context.Spell.Cut then Projectiles:Cut(source, context.Spell.ClashPower, context.Spell.Radius + 3) end
		dash.Previous = source.Root.Position
		if now >= dash.Until or now < source.StunUntil or not source.DashDirection then self.Dashes[source] = nil; Movement:StopDash(source) end
	end
	for _, state in Registry.Actors do
		if not state.FlightConstraint then continue end
		if not Registry:Alive(state) or not state.Awakened or now >= state.FlightUntil
			or now - (state.FlightLastInput or 0) > Config.Flight.InputTimeout or now < state.StunUntil or now < state.RootedUntil then
			self:StopFlight(state); continue
		end
		local desired = (state.FlightInput or Vector3.zero) * Config.Flight.Speed
		if desired.Magnitude > .1 then
			local hit = workspace:Blockcast(state.Root.CFrame, Vector3.new(2.3, 4.8, 2.3), desired * math.min(dt + .04, .15), Hitbox:WorldParams(state))
			if hit then desired = Vector3.zero end
		end
		state.FlightConstraint.VectorVelocity = desired
		state.MotionGrace = now + .35
	end
end
function Motion:RemoveOwner(owner)
	self.Dashes[owner] = nil
	Movement:StopDash(owner)
	self:StopFlight(owner)
end
return Motion
