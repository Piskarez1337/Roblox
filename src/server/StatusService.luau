--!nonstrict
local Registry = require(script.Parent.Registry)
local Status = {}
function Status:Root(state, seconds, now)
	if not Registry:Alive(state) or state.Model:FindFirstChildOfClass("ForceField") then return false end
	state.RootedUntil = math.max(state.RootedUntil, now + math.min(seconds, 2.5))
	state.RootAnchor = state.Root.Position
	state.CastGeneration += 1
	state.Generation += 1
	state.Blocking = false
	state.Model:SetAttribute("CastSpell", "")
	state.Model:SetAttribute("AttackStart", 0)
	return true
end
function Status:Grab(state, position, seconds, now)
	self:Root(state, seconds, now)
	if not state.Root.Anchored then state.GrabPosition, state.GrabUntil = position, now + seconds end
end
function Status:Step(now)
	for _, state in Registry.Actors do
		if not Registry:Alive(state) then continue end
		if state.Shield and now >= state.Shield.Until then state.Shield = nil; state.Model:SetAttribute("ShieldVisual", "") end
		if now < state.RootedUntil then
			if not state.Root.Anchored then
				state.Root:SetNetworkOwner(nil)
				state.ControlOwned = true
				local anchor = state.RootAnchor or state.Root.Position
				local point = state.GrabPosition and now < (state.GrabUntil or 0) and state.GrabPosition
					or Vector3.new(anchor.X, state.Root.Position.Y, anchor.Z)
				state.Root.CFrame = CFrame.new(point) * state.Root.CFrame.Rotation
				state.Root.AssemblyLinearVelocity = Vector3.new(0, state.GrabPosition and 0 or state.Root.AssemblyLinearVelocity.Y, 0)
				state.MotionGrace = now + .3
			end
		elseif state.ControlOwned then
			state.ControlOwned, state.GrabPosition = nil, nil
			if state.Player and not state.DashDirection and not state.FlightConstraint and not state.Root.Anchored then state.Root:SetNetworkOwnershipAuto() end
		end
	end
end
return Status
