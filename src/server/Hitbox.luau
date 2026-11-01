--!nonstrict
local Config = require(game:GetService("ReplicatedStorage").BlackClover.Shared.Config)
local Registry = require(script.Parent.Registry)
local Targeting = require(script.Parent.MagicHitboxService)
local Hitbox = {}

function Hitbox:Find(source, requestedReach)
	local reach = requestedReach or Config.Combat.Reach
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { source.Model }
	params.MaxParts = 0 -- no cap that could hide a nearby target among cosmetic parts
	local box = source.Root.CFrame * CFrame.new(0, 0, -(reach - 1) / 2)
	local parts = workspace:GetPartBoundsInBox(box, Vector3.new(Config.Combat.Width, Config.Combat.Height, reach - 1), params)
	local seen, results = {}, {}
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = { source.Model }
	for _, part in parts do
		local target = Registry:FromPart(part)
		if not target or target == source or seen[target] or not Registry:Alive(target) then continue end
		seen[target] = true
		if not Targeting:CanHit(source, target) then continue end
		local delta = target.Root.Position - source.Root.Position
		if delta.Magnitude > reach or delta.Magnitude < 0.01 then continue end
		if source.Root.CFrame.LookVector:Dot(delta.Unit) < 0.2 then continue end
		local obstruction = workspace:Raycast(source.Root.Position, delta, ray)
		if obstruction and not obstruction.Instance:IsDescendantOf(target.Model) then continue end
		table.insert(results, target)
	end
	return results
end

return Hitbox
