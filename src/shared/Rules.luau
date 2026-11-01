--!strict
-- Pure simulation rules: exercised by Luau CLI without a Roblox engine.
local Rules = {}

function Rules.finite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function Rules.maxMana(base: number, perLevel: number, level: number): number
	return base + math.max(0, math.floor(level) - 1) * perLevel
end

function Rules.regenerate(value: number, maximum: number, rate: number, dt: number): number
	return math.clamp(value + math.max(0, rate) * math.max(0, dt), 0, maximum)
end

function Rules.spend(value: number, cost: number): (boolean, number)
	if not Rules.finite(cost) or cost < 0 or value < cost then
		return false, value
	end
	return true, value - cost
end

function Rules.nextCombo(previous: number, lastAttack: number, now: number, reset: number): number
	if now - lastAttack > reset then return 1 end
	return previous % 4 + 1
end

function Rules.canAct(health: number, now: number, busyUntil: number, stunUntil: number): boolean
	return health > 0 and now >= busyUntil and now >= stunUntil
end

function Rules.consumeToken(tokens: number, lastTime: number, now: number, rate: number, burst: number): (boolean, number)
	local available = math.min(burst, tokens + math.max(0, now - lastTime) * rate)
	if available < 1 then return false, available end
	return true, available - 1
end

function Rules.guardHit(damage: number, guard: number, cost: number, factor: number): (number, number, boolean)
	local remaining = math.max(0, guard - cost)
	if remaining == 0 then return damage, 0, true end
	return damage * factor, remaining, false
end

return table.freeze(Rules)
