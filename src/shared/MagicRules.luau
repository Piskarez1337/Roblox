--!strict
local Rules = {}
function Rules.manaAfter(mana: number, maximum: number, dt: number, awakened: boolean, drain: number, regen: number): number
	local change = awakened and -math.max(0, drain) or math.max(0, regen)
	return math.clamp(mana + change * math.max(0, dt), 0, maximum)
end
function Rules.clash(a: number, b: number, elementA: string, elementB: string): (string, number)
	local pa = a * (elementA == "Anti" and elementB ~= "Anti" and 1.3 or 1)
	local pb = b * (elementB == "Anti" and elementA ~= "Anti" and 1.3 or 1)
	if math.abs(pa - pb) <= math.max(pa, pb) * .15 then return "Equal", 0 end
	return pa > pb and "A" or "B", math.max(1, math.abs(pa - pb) * .75)
end
function Rules.sweptHit(rx: number, ry: number, rz: number, vx: number, vy: number, vz: number, radius: number): (boolean, number)
	local vv = vx * vx + vy * vy + vz * vz
	local t = vv > 1e-9 and math.clamp(-(rx * vx + ry * vy + rz * vz) / vv, 0, 1) or 0
	local x, y, z = rx + vx * t, ry + vy * t, rz + vz * t
	return x * x + y * y + z * z <= radius * radius, t
end
function Rules.cooldown(base: number, element: string, kind: string): number
	return base * (element == "Stars" and kind == "Teleport" and .8 or 1)
end
return Rules
