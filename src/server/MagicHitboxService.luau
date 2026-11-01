--!nonstrict
local Registry = require(script.Parent.Registry)
local Rules = require(game:GetService("ReplicatedStorage").BlackClover.Shared.Rules)
local Hitbox = {}
function Hitbox:CanHit(source, target)
	if source == target or not Registry:Alive(source) or not Registry:Alive(target) then return false end
	local owner = source.Owner or source
	if target == owner or target.Owner == owner or source.Owner == target then return false end
	if source.Kind == "Enemy" then return target.Kind == "Player" or target.Kind == "Golem" end
	return true
end
function Hitbox:WorldParams(source)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignored = {}
	for model in Registry.Actors do table.insert(ignored, model) end
	if source and not table.find(ignored, source.Model) then table.insert(ignored, source.Model) end
	params.FilterDescendantsInstances = ignored
	params.RespectCanCollide = true
	return params
end
function Hitbox:PointIsValid(point)
	return typeof(point) == "Vector3" and Rules.finite(point.X) and Rules.finite(point.Y) and Rules.finite(point.Z)
		and math.abs(point.X) < 100000 and math.abs(point.Y) < 100000 and math.abs(point.Z) < 100000
end
function Hitbox:ResolveAim(source, point, range)
	if not self:PointIsValid(point) then return nil end
	local delta = point - source.Root.Position
	if delta.Magnitude < .1 then delta = source.Root.CFrame.LookVector end
	return source.Root.Position + delta.Unit * math.min(delta.Magnitude, range)
end
function Hitbox:Ground(point, source)
	local result = workspace:Raycast(point + Vector3.new(0, 65, 0), Vector3.new(0, -180, 0), self:WorldParams(source))
	return result and result.Position or nil
end
function Hitbox:Visible(source, position, target)
	local params = self:WorldParams(source)
	local delta = position - source.Root.Position
	if delta.Magnitude < .01 then return true end
	local hit = workspace:Raycast(source.Root.Position, delta, params)
	return not hit or (target and hit.Instance:IsDescendantOf(target.Model))
end
function Hitbox:Area(source, center, radius, visibility)
	local found = {}
	for _, target in Registry.Actors do
		if self:CanHit(source, target) and (target.Root.Position - center).Magnitude <= radius + math.max(1.5, target.Root.Size.X * .7) then
			if not visibility or self:Visible(source, target.Root.Position, target) then table.insert(found, target) end
		end
	end
	return found
end
function Hitbox:Nearest(source, point, radius)
	local best, distance = nil, radius
	for _, target in self:Area(source, point, radius, true) do
		local d = (target.Root.Position - point).Magnitude
		if d < distance then best, distance = target, d end
	end
	return best
end
function Hitbox:Segment(source, a, b, radius)
	local result, delta = {}, b - a
	local length2 = delta:Dot(delta)
	for _, target in Registry.Actors do
		if not self:CanHit(source, target) then continue end
		local t = length2 > .001 and math.clamp((target.Root.Position - a):Dot(delta) / length2, 0, 1) or 0
		if (target.Root.Position - (a + delta * t)).Magnitude <= radius + math.max(1.2, target.Root.Size.X * .6) then table.insert(result, { State = target, Time = t }) end
	end
	table.sort(result, function(x, y) return x.Time < y.Time end)
	return result
end
return Hitbox
