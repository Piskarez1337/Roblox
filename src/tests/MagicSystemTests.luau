--!nonstrict
-- In Studio Play mode, SERVER Command Bar: require(game.ServerStorage.MagicSystemTests).Run()
-- Uses isolated actors/floor. Does not mutate real players. Requires the running Bootstrap.
local Tests = {}
function Tests.Run()
	assert(game:GetService("RunService"):IsServer(), "Run on the server")
	assert(not Tests.Running, "Magic tests already running")
	Tests.Running = true
	local folder = game:GetService("ServerScriptService").BlackCloverServer
	local Registry = require(folder.Registry)
	local Manager = require(folder.MagicManager)
	local Awakening = require(folder.AwakeningManager)
	local Mana = require(folder.ManaManager)
	local Damage = require(folder.DamageService)
	local Hitbox = require(folder.MagicHitboxService)
	local Executor = require(folder.SpellExecutor)
	local Projectiles = require(folder.ProjectileService)
	local Fields = require(folder.FieldService)
	local Constructs = require(folder.ConstructService)
	local Summons = require(folder.SummonService)
	local Spells = require(game.ReplicatedStorage.BlackClover.Shared.SpellRegistry)
	local Config = require(game.ReplicatedStorage.BlackClover.Shared.MagicConfig)
	local objects, actors, checks = {}, {}, 0
	local function check(value, message) assert(value, message); checks += 1 end
	local function near(a, b) return math.abs(a - b) < .0001 end
	local function spawn(position, anchored)
		local model = game.ServerStorage.Actors.Dummy:Clone()
		model.Name, model.Parent = "MagicTestActor", workspace
		local state = Registry:Add(model, nil, "Player")
		state.Root.CFrame = CFrame.new(position)
		state.Root.Anchored = anchored
		state.Humanoid.MaxHealth, state.Humanoid.Health = 10000, 10000
		for _, part in model:GetDescendants() do if part:IsA("BasePart") then part.CollisionGroup = "BCActors" end end
		table.insert(objects, model); table.insert(actors, state)
		return state
	end
	local function ready(state, id, awake)
		Manager:Cancel(state)
		state.MagicId, state.Awakened, state.Mana = id, awake or false, 100
		state.BusyUntil, state.StunUntil, state.RootedUntil, state.SuppressedUntil = 0, 0, 0, 0
		state.Cooldowns, state.SelectReady, state.AttackReady, state.Blocking = {}, 0, 0, false
		state.Model:SetAttribute("MagicId", id); state.Model:SetAttribute("Awakened", state.Awakened)
	end
	local function context(state, id, point)
		return { Owner = state, Spell = Spells.All[id], Point = point, Direction = (point - state.Root.Position).Unit,
			Epoch = state.MagicEpoch, CastGeneration = state.CastGeneration, Serial = 999, Now = workspace:GetServerTimeNow() }
	end
	local ok, problem = xpcall(function()
		local floor = Instance.new("Part")
		floor.Name, floor.Size, floor.CFrame, floor.Anchored = "MagicTestFloor", Vector3.new(600, 2, 600), CFrame.new(0, 180, 0), true
		floor.Parent = workspace; table.insert(objects, floor)
		local source = spawn(Vector3.new(0, 184, 0), false)
		local target = spawn(Vector3.new(0, 184, -16), true)
		task.wait(.2)
		check(not Hitbox:ResolveAim(source, Vector3.new(0 / 0, 0, 0), 30), "NaN aim rejected")
		check((Hitbox:ResolveAim(source, source.Root.Position + Vector3.new(10000, 0, 0), 30) - source.Root.Position).Magnitude <= 30.001, "range clamped")
		for _, id in Config.Order do
			source.SelectReady, source.Mana = 0, 73
			source.Cooldowns.Water_Z = 12345
			check(Manager:Select(source, id, workspace:GetServerTimeNow()), "select " .. id)
			check(source.Mana == 73 and source.Cooldowns.Water_Z == 12345, "selection cannot refill mana or reset cooldown")
			check(source.Model:GetAttribute("MeleeProfile") == (id == "Anti" and "Sword" or "Fist"), "permanent anti sword profile")
		end
		for id, drain in { Water = 1, Bone = 5, Wind = 7, Anti = 7 } do
			ready(source, id)
			source.AwakeningReady = 0
			check(Awakening:Toggle(source, workspace:GetServerTimeNow()), "G enabled " .. id)
			-- Separate unregistered state avoids concurrent Heartbeat mutations of the exact mana assertion.
			local manaState = { Mana = 100, MaxMana = 100, Level = 1, MagicId = id, Awakened = true, LastManaUse = 0 }
			Mana:Step(manaState, .125, 100)
			check(near(manaState.Mana, 100 - drain * .125), "server exact dt drain " .. id)
			check(Awakening:Toggle(source, workspace:GetServerTimeNow()) and not source.Awakened, "G disabled")
			check(source.Model:GetAttribute("MeleeProfile") == (id == "Anti" and "Sword" or "Fist"), "sword survives G off")
			source.Awakened, source.Mana = true, 0
			Awakening:Step(workspace:GetServerTimeNow())
			check(not source.Awakened, "zero mana automatically stops awakening")
		end
		ready(source, "Water")
		check(not Manager:Cast(source, { Slot = "?", Point = target.Root.Position }, workspace:GetServerTimeNow()), "invalid slot")
		source.Mana = 0
		check(not Manager:Cast(source, { Slot = "Z", Point = target.Root.Position }, workspace:GetServerTimeNow()), "insufficient mana")
		source.Mana, source.SuppressedUntil = 100, workspace:GetServerTimeNow() + 3
		check(not Manager:Cast(source, { Slot = "Z", Point = target.Root.Position }, workspace:GetServerTimeNow()), "suppression rejects magic")
		ready(source, "Water")
		local now, before = workspace:GetServerTimeNow(), target.Humanoid.Health
		target.Shield = { HP = 100, Until = now + 5, Reduction = .7 }
		local dealt = Damage:Spell(source, target, Spells.All.Water_Z, now)
		check(near(dealt, 24 * .3) and near(target.Humanoid.Health, before - dealt), "shield absorbs actual damage")
		target.Shield, target.StunUntil = nil, 0
		local wallContext = context(source, "Earth_X", target.Root.Position)
		local wall = Constructs:Wall(wallContext)
		check(wall and wall.Root.CanCollide and wall.Root.CanQuery, "wall has physical collision")
		Constructs:Damage(wall.Root, 181, target)
		check(not wall.Root.Parent, "wall shatters at zero HP")
		-- An actual swept server projectile resolves against the target and can be reflected.
		local projectileContext = context(source, "Water_Z", target.Root.Position)
		check(Projectiles:Reserve(projectileContext, 1), "reserve projectile")
		local p = Projectiles:Create(projectileContext, source.Root.Position + Vector3.new(0, 0, -3), Vector3.new(0, 0, -1))
		before = target.Humanoid.Health
		task.wait(.35)
		check(p.Removed and target.Humanoid.Health < before, "swept projectile damages target")
		check(Projectiles:Reserve(projectileContext, 1), "reserve reflected projectile")
		p = Projectiles:Create(projectileContext, source.Root.Position, Vector3.new(0, 0, -1))
		target.MagicId, target.ParryUntil = "Anti", workspace:GetServerTimeNow() + 1
		target.Root.CFrame = CFrame.lookAt(target.Root.Position, source.Root.Position)
		check(Projectiles:Parry(p, target, workspace:GetServerTimeNow()) and p.Owner == target and p.Reflections == 1, "parry transfers projectile ownership")
		Projectiles:Remove(p)
		target.MagicId, target.ParryUntil = "", 0
		-- Every catalog entry must route through the real Manager and executor without a release error.
		local ids = {}; for id in Spells.All do table.insert(ids, id) end; table.sort(ids)
		for _, id in ids do
			local spell = Spells.All[id]
			ready(source, spell.ElementType, spell.Awakened)
			source.Root.CFrame, source.Root.AssemblyLinearVelocity = CFrame.new(0, 184, 0), Vector3.zero
			target.Root.CFrame, target.Humanoid.Health = CFrame.new(0, 184, -16), 10000
			target.RootedUntil, target.StunUntil, target.RootResistUntil = 0, 0, 0
			check(Executor.Handlers[spell.Kind] ~= nil, "executor exists " .. id)
			local previousRelease = source.ReleasedSerial
			check(Manager:Cast(source, { Slot = spell.Slot, Point = Vector3.new(0, 181, -16) }, workspace:GetServerTimeNow()), "cast accepted " .. id)
			check(not Manager:Cast(source, { Slot = spell.Slot, Point = target.Root.Position }, workspace:GetServerTimeNow()), "spam rejected " .. id)
			task.wait(spell.CastTime + .12)
			check(source.ReleasedSerial ~= previousRelease and Manager.Pending[source] == nil and (source.Cooldowns[id] or 0) > 0, "release completed without refund " .. id)
			if spell.Kind == "Summon" then check(Summons.Items[source] ~= nil, "live golem registered") end
			Manager:Cancel(source)
		end
		-- Delayed volleys must not outlive a changed class or dead/removed actor.
		ready(source, "Bone")
		local delayed = context(source, "Bone_V", target.Root.Position)
		check(Executor:Reserve(delayed), "reserve delayed rain")
		Executor:Execute(delayed)
		Manager:Cancel(source)
		task.wait(1.9)
		for _, p in Projectiles.Items do check(p.Owner ~= source, "stale projectile removed") end
		for _, f in Fields.Items do check(f.Owner ~= source, "stale field removed") end
		check(Projectiles.Reservations[delayed] == nil and Fields.Reservations[delayed] == nil, "no reservation leak")
	end, debug.traceback)
	for _, state in actors do Registry:Remove(state.Model) end
	for _, object in objects do object:Destroy() end
	Tests.Running = false
	assert(ok, problem)
	print(string.format("[Black Clover] PASS: %d magic Studio integration assertions", checks))
	return checks
end
return Tests
