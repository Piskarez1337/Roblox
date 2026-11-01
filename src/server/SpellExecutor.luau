--!nonstrict
local Registry = require(script.Parent.Registry)
local Hitbox = require(script.Parent.MagicHitboxService)
local Projectiles = require(script.Parent.ProjectileService)
local Fields = require(script.Parent.FieldService)
local Constructs = require(script.Parent.ConstructService)
local Motion = require(script.Parent.MagicMotionService)
local Summons = require(script.Parent.SummonService)
local World = require(script.Parent.MagicWorld)
local Config = require(game:GetService("ReplicatedStorage").BlackClover.Shared.MagicConfig)
local Executor = { Handlers = {} }
local H = Executor.Handlers
local projectileKinds = { Projectile = true, Dive = true, Volley = true, Rain = true, Judgment = true }
local fieldKinds = { Spikes = true, Tornado = true, Prison = true, Hand = true, Domain = true, Spin = true, Judgment = true }
function Executor:Reserve(context)
	local spell = context.Spell
	if projectileKinds[spell.Kind] and not Projectiles:Reserve(context, spell.Count) then return false end
	local amount = (spell.Kind == "Spikes" or spell.Kind == "Tornado") and spell.Count or 1
	if fieldKinds[spell.Kind] and not Fields:Reserve(context, amount) then Projectiles:Release(context); return false end
	return true
end
function Executor:Release(context) Projectiles:Release(context); Fields:Release(context) end
function Executor:Delay(context, delay, callback)
	task.delay(delay, function()
		if not Registry:Alive(context.Owner) or context.Owner.MagicEpoch ~= context.Epoch then self:Release(context); return end
		callback()
	end)
end
function Executor:Execute(context)
	local handler = H[context.Spell.Kind]
	assert(handler, "Unimplemented spell kind: " .. context.Spell.Kind)
	context.Now = workspace:GetServerTimeNow()
	return handler(context) ~= false
end
H.Projectile = function(ctx)
	local origin = ctx.Owner.Root.Position + Vector3.new(0, 1, 0) + ctx.Direction * 2.5
	return Projectiles:Create(ctx, origin, ctx.Direction) ~= nil
end
H.Dive = function(ctx)
	local ground = Hitbox:Ground(ctx.Point, ctx.Owner)
	if not ground then return false end
	local origin = ground + Vector3.new(0, 45, 0) - ctx.Direction * 16
	return Projectiles:Create(ctx, origin, (ground - origin).Unit, { Range = 80 }) ~= nil
end
H.Volley = function(ctx)
	for i = 1, ctx.Spell.Count do
		Executor:Delay(ctx, (i - 1) * ctx.Spell.Interval, function()
			local spread = (i - (ctx.Spell.Count + 1) / 2) / math.max(1, ctx.Spell.Count - 1) * ctx.Spell.Spread
			local direction = (CFrame.fromAxisAngle(Vector3.yAxis, math.rad(spread)) * ctx.Direction).Unit
			Projectiles:Create(ctx, ctx.Owner.Root.Position + Vector3.new(0, 1, 0) + direction * 2.5, direction)
		end)
	end
end
H.Shield = function(ctx)
	local spell, state = ctx.Spell, ctx.Owner
	state.Shield = { Until = ctx.Now + spell.Duration, HP = spell.ShieldHP, Reduction = spell.Reduction }
	state.Model:SetAttribute("ShieldVisual", spell.Visual)
	state.Model:SetAttribute("ShieldUntil", state.Shield.Until)
	World:Pulse("Shield", state.Root.Position, spell.ElementType, spell.Radius)
end
H.DashStrike = function(ctx) return Motion:Dash(ctx) end
H.Teleport = function(ctx) return Motion:Teleport(ctx) end
H.Wall = function(ctx) return Constructs:Wall(ctx) ~= nil end
H.Summon = function(ctx) return Summons:Create(ctx) end
H.Parry = function(ctx)
	ctx.Owner.ParryUntil = ctx.Now + ctx.Spell.Duration + Config.Passives.AntiParryBonus
	ctx.Owner.Model:SetAttribute("ParryUntil", ctx.Owner.ParryUntil)
	World:Pulse("ParryReady", ctx.Owner.Root.Position, "Anti", 5)
end
H.Spikes = function(ctx)
	if not Hitbox:Ground(ctx.Owner.Root.Position, ctx.Owner) then return false end
	local direction = Vector3.new(ctx.Direction.X, 0, ctx.Direction.Z)
	if direction.Magnitude < .1 then direction = Vector3.new(0, 0, -1) end
	direction = direction.Unit
	local origin = ctx.Owner.Root.Position
	for i = 1, ctx.Spell.Count do
		Executor:Delay(ctx, (i - 1) * ctx.Spell.Interval, function()
			local ground = Hitbox:Ground(origin + direction * (4 + i * 6), ctx.Owner)
			if ground then Fields:Create(ctx, "Spike", ground, { Until = workspace:GetServerTimeNow() + 1.2, Activation = workspace:GetServerTimeNow() + .2 }) end
		end)
	end
	Executor:Delay(ctx, ctx.Spell.Count * ctx.Spell.Interval + .1, function() Fields:Release(ctx) end)
end
H.Tornado = function(ctx)
	local right = ctx.Owner.Root.CFrame.RightVector
	local created = 0
	for i = 1, ctx.Spell.Count do
		local point = ctx.Owner.Root.Position + ctx.Direction * 8 + right * (i - (ctx.Spell.Count + 1) / 2) * 12
		local ground = Hitbox:Ground(point, ctx.Owner)
		if ground and Fields:Create(ctx, "Tornado", ground + Vector3.new(0, 3, 0)) then created += 1 end
	end
	Fields:Release(ctx)
	return created > 0
end
H.Prison = function(ctx)
	local nearest = Hitbox:Nearest(ctx.Owner, ctx.Point, 12)
	local ground = Hitbox:Ground(nearest and nearest.Root.Position or ctx.Point, ctx.Owner)
	if not ground then return false end
	return Fields:Create(ctx, "Prison", ground + Vector3.new(0, 1, 0)) ~= nil
end
H.Hand = function(ctx)
	local ground = Hitbox:Ground(ctx.Point, ctx.Owner)
	if not ground then return false end
	return Fields:Create(ctx, "Hand", ground + Vector3.new(0, 1, 0)) ~= nil
end
H.Domain = function(ctx)
	local ground = Hitbox:Ground(ctx.Point, ctx.Owner)
	if not ground then return false end
	if ctx.Spell.LiftCaster and not ctx.Owner.Root.Anchored then
		ctx.Owner.Root:ApplyImpulse(Vector3.new(0, 52, 0) * ctx.Owner.Root.AssemblyMass)
		ctx.Owner.MotionGrace = ctx.Now + 1
	end
	return Fields:Create(ctx, "Domain", ground + Vector3.new(0, 1, 0)) ~= nil
end
H.Spin = function(ctx) return Fields:Create(ctx, "Spin", ctx.Owner.Root.Position) ~= nil end
H.Rain = function(ctx)
	if not Hitbox:Ground(ctx.Point, ctx.Owner) then return false end
	local random = Random.new(ctx.Serial * 31)
	for i = 1, ctx.Spell.Count do
		local angle, distance = random:NextNumber(0, math.pi * 2), math.sqrt(random:NextNumber()) * ctx.Spell.Radius
		local point = ctx.Point + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		Executor:Delay(ctx, (i - 1) * ctx.Spell.Interval, function()
			local ground = Hitbox:Ground(point, ctx.Owner)
			if ground then Projectiles:Create(ctx, ground + Vector3.new(0, 36, 0), Vector3.new(0, -1, 0), { Radius = 1, Range = 55 }) end
		end)
	end
	Executor:Delay(ctx, ctx.Spell.Count * ctx.Spell.Interval + .1, function() Projectiles:Release(ctx) end)
end
H.Judgment = function(ctx)
	local ground = Hitbox:Ground(ctx.Point, ctx.Owner)
	if not ground then return false end
	Fields:Create(ctx, "Judgment", ground + Vector3.new(0, 1, 0))
	for i = 1, ctx.Spell.Count do
		local angle = i * math.pi * 2 / ctx.Spell.Count
		local origin = ground + Vector3.new(math.cos(angle) * 23, 25, math.sin(angle) * 23)
		Executor:Delay(ctx, .9 + (i % 3) * .04, function()
			Projectiles:Create(ctx, origin, (ground - origin).Unit, { Radius = 1.5, Speed = 100, Range = 60 })
		end)
	end
end
return Executor
