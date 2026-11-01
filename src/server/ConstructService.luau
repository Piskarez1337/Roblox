--!nonstrict
local Registry = require(script.Parent.Registry)
local Hitbox = require(script.Parent.MagicHitboxService)
local World = require(script.Parent.MagicWorld)
local TweenService = game:GetService("TweenService")
local Constructs = { Items = {} }
function Constructs:Wall(context)
	local source, spell = context.Owner, context.Spell
	local direction = context.Direction
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < .1 then direction = Vector3.new(0, 0, -1) end
	direction = direction.Unit
	local floor = Hitbox:Ground(source.Root.Position + direction * 10, source)
	if not floor then return end
	local root = World:Create(source, spell, "Wall", floor - Vector3.new(0, 6, 0), spell.Duration)
	root.Size, root.CanCollide, root.CanQuery = Vector3.new(18, 12, 3), true, true
	root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
	local record = { Root = root, Owner = source, Epoch = source.MagicEpoch, Health = spell.WallHP, Until = context.Now + spell.Duration }
	root:SetAttribute("Health", record.Health)
	root:SetAttribute("MaxHealth", record.Health)
	self.Items[root] = record
	TweenService:Create(root, TweenInfo.new(.35, Enum.EasingStyle.Quad), { CFrame = CFrame.lookAt(floor + Vector3.new(0, 6, 0), floor + Vector3.new(0, 6, 0) + direction) }):Play()
	return record
end
function Constructs:Remove(record)
	if not self.Items[record.Root] then return end
	self.Items[record.Root] = nil
	World:Pulse("Shatter", record.Root.Position, "Earth", 10)
	record.Root:Destroy()
end
function Constructs:Damage(part, amount, source)
	local record = self.Items[part]
	if not record then return false end
	if source == record.Owner then return true end
	record.Health = math.max(0, record.Health - amount)
	part:SetAttribute("Health", record.Health)
	if record.Health <= 0 then self:Remove(record) end
	return true
end
function Constructs:Melee(source, damage, seen)
	for part, record in self.Items do
		local delta = part.Position - source.Root.Position
		if source ~= record.Owner and not seen[record] and delta.Magnitude < 13 and source.Root.CFrame.LookVector:Dot(delta.Unit) > .25 then
			seen[record] = true
			self:Damage(part, damage, source)
		end
	end
end
function Constructs:Step(now)
	for _, record in self.Items do
		if now >= record.Until or not Registry:Alive(record.Owner) or record.Owner.MagicEpoch ~= record.Epoch then self:Remove(record) end
	end
end
function Constructs:RemoveOwner(owner)
	for _, record in self.Items do if record.Owner == owner then self:Remove(record) end end
end
return Constructs
