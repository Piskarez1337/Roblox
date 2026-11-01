--!strict
local Rules = require("../src/shared/MagicRules")
local Config = require("../src/shared/MagicConfig")
local Spells = require("../src/shared/SpellRegistry")
local Core = require("../src/shared/Rules")
local checks = 0
local function check(condition: boolean, message: string)
	assert(condition, message)
	checks += 1
end
local function near(a: number, b: number): boolean return math.abs(a - b) < 1e-6 end
local expectedDrain: { [string]: number } = { Water = 1, Bone = 5, Wind = 7, Anti = 7 }
local base, awakened = 0, 0
local seen: { [string]: boolean } = {}
for _, element in Config.Order do
	for _, slot in { "Z", "X", "C", "V" } do
		local normal = Spells.Get(element, false, slot)
		check(normal ~= nil, element .. " missing base " .. slot)
		assert(normal)
		local boosted = Spells.Get(element, true, slot)
		check((boosted ~= nil) == (expectedDrain[element] ~= nil), element .. " awakening support")
		if boosted then
			check(boosted.Id ~= normal.Id and boosted.Name ~= normal.Name, "awakening must replace, not reuse, base ability")
		end
	end
end
for id, spell in Spells.All do
	check(not seen[id] and id == spell.Id, "unique ability ID")
	seen[id] = true
	if spell.Awakened then awakened += 1 else base += 1 end
	check(Spells.Get(spell.ElementType, spell.Awakened, spell.Slot) == spell, "registry roundtrip")
	check(spell.ManaCost > 0 and spell.ManaCost <= 100 and spell.Cooldown > 0, "bounded mana and cooldown")
	check(spell.CastTime > 0 and spell.Recovery > 0 and spell.ClashPower > 0, "cast timing and clash power")
	check(spell.Range >= 0 and spell.Range <= 200 and spell.HitboxSize > 0, "bounded targeting geometry")
	check(spell.Visual ~= "" and spell.Style ~= "", "presentation contract")
	check(spell.RootTime == nil or spell.RootTime <= 2.5, "CC duration must stay bounded")
	check(spell.Damage > 0 or spell.Kind == "Shield" or spell.Kind == "Wall" or spell.Kind == "Teleport" or spell.Kind == "Parry", "spell needs damage or real utility")
	local paid, after = Core.spend(100, spell.ManaCost)
	check(paid and after == 100 - spell.ManaCost, "every ability pays its full cost")
	check(not Core.spend(spell.ManaCost - .001, spell.ManaCost), "insufficient mana rejected")
end
check(base == 28 and awakened == 16, "complete 28 + 16 catalog")
check(Spells.Get("Missing", false, "Z") == nil and Spells.Get("Water", false, "M") == nil, "unknown classes/slots rejected")
for element, drain in expectedDrain do
	check(Config.Classes[element].Drain == drain, "exact specified drain " .. element)
	for _, hz in { 15, 30, 60, 144 } do
		local mana = 100
		for _ = 1, hz * 10 do mana = Rules.manaAfter(mana, 100, 1 / hz, true, drain, 1000) end
		check(near(mana, 100 - drain * 10), "drain independent of framerate; regen disabled " .. element)
	end
	local variable = 100
	for _, dt in { .17, .03, .5, .1, .2 } do variable = Rules.manaAfter(variable, 100, dt, true, drain, 7) end
	check(near(variable, 100 - drain), "variable dt " .. element)
	check(Rules.manaAfter(.01, 100, 4, true, drain, 7) == 0, "zero floor for auto-off")
end
check(Rules.manaAfter(10, 100, 2, false, 7, 7) == 24, "regen resumes outside awakening")
check(Rules.manaAfter(99, 100, 9, false, 0, 7) == 100, "regen clamps to capacity")
check(Rules.manaAfter(50, 100, -1, true, 7, 0) == 50, "negative dt cannot create mana")
check(Rules.cooldown(5, "Stars", "Teleport") == 4, "Stars teleport passive")
check(Rules.cooldown(5, "Stars", "Projectile") == 5, "Stars passive only affects teleport")
local outcome, remainder = Rules.clash(40, 40, "Water", "Ice")
check(outcome == "Equal" and remainder == 0, "equal spells cancel")
outcome, remainder = Rules.clash(80, 20, "Water", "Wind")
check(outcome == "A" and remainder > 0 and remainder < 80, "winning spell loses power")
check(Rules.clash(20, 80, "Water", "Wind") == "B", "stronger second spell wins")
check(Rules.clash(40, 40, "Anti", "Water") == "A", "anti magic clash advantage")
check(Rules.clash(25, 180, "Anti", "Water") == "B", "anti magic is not invulnerable")
check(Rules.clash(35, 40, "Water", "Ice") == "Equal", "15 percent tie tolerance")
check(Rules.clash(30, 40, "Water", "Ice") == "B", "outside tie tolerance")
local hit, t = Rules.sweptHit(-100, 0, 0, 200, 0, 0, 2)
check(hit and near(t, .5), "fast opposing projectiles cannot tunnel between frames")
check(not Rules.sweptHit(-100, 3, 0, 200, 0, 0, 2), "nearby parallel miss")
check(Rules.sweptHit(0, 0, 0, 0, 0, 0, 2), "stationary overlapping spheres")
check(not Rules.sweptHit(3, 0, 0, 0, 0, 0, 2), "stationary separated spheres")
check(not Rules.sweptHit(5, 0, 0, 100, 0, 0, 2), "diverging trajectories")
check(Rules.sweptHit(-5, 0, 0, 3, 0, 0, 2), "endpoint grazing collision")
print(string.format("PASS: %d magic assertions; 28 base + 16 awakened spells (no Roblox engine)", checks))
