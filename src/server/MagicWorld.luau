--!nonstrict
local CollectionService = game:GetService("CollectionService")
local World = { Serial = 0 }
function World:Init(remote)
	self.Remote = remote
	self.Folder = Instance.new("Folder")
	self.Folder.Name, self.Folder.Parent = "MagicWorld", workspace
end
function World:Create(owner, spell, kind, position, duration)
	self.Serial += 1
	local root = Instance.new("Part")
	root.Name = kind .. "_" .. self.Serial
	root.Size, root.Transparency = Vector3.one * .2, 1
	root.Anchored, root.CanCollide, root.CanTouch, root.CanQuery = true, false, false, false
	root.CFrame = CFrame.new(position)
	root:SetAttribute("EntityId", self.Serial)
	root:SetAttribute("EntityKind", kind)
	root:SetAttribute("SpellId", spell.Id)
	root:SetAttribute("Visual", spell.Visual)
	root:SetAttribute("Element", spell.ElementType)
	root:SetAttribute("Radius", spell.Radius)
	root:SetAttribute("StartTime", workspace:GetServerTimeNow())
	root:SetAttribute("EndTime", workspace:GetServerTimeNow() + duration)
	local reference = Instance.new("ObjectValue")
	reference.Name, reference.Value, reference.Parent = "Owner", owner.Model, root
	root.Parent = self.Folder
	CollectionService:AddTag(root, "BCSpellEntity")
	return root
end
function World:Pulse(kind, position, element, radius, detail)
	if self.Remote then self.Remote:FireAllClients(kind, position, element, radius, detail) end
end
return World
