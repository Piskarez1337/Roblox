--!strict
local Rules = require("../src/shared/Rules")
local Config = require("../src/shared/Config")
local passed = 0
local function check(condition: boolean, message: string)
	assert(condition, message)
	passed += 1
end
local function near(a: number, b: number): boolean return math.abs(a - b) < 0.00001 end

check(Rules.maxMana(100, 10, 1) == 100, "level 1 mana")
check(Rules.maxMana(100, 10, 11) == 200, "mana growth")
check(Rules.maxMana(100, 10, -20) == 100, "negative level bounded")
check(Rules.finite(0) and Rules.finite(-12), "finite values")
check(not Rules.finite(0 / 0) and not Rules.finite(math.huge), "NaN and infinity rejected")
check(not Rules.finite("8"), "numeric strings rejected")
local ok, value = Rules.spend(8, 8)
check(ok and value == 0, "exact mana payment")
ok, value = Rules.spend(7.99, 8)
check(not ok and value == 7.99, "overspending rejected atomically")
ok, value = Rules.spend(50, -8)
check(not ok and value == 50, "negative costs cannot add mana")
ok, value = Rules.spend(50, 0 / 0)
check(not ok and value == 50, "NaN cost rejected")
check(Rules.regenerate(98, 100, 7, 10) == 100, "regen clamps to maximum")
check(Rules.regenerate(60, 100, 7, -1) == 60, "backwards time cannot drain")
local mana = 0
for _ = 1, 600 do mana = Rules.regenerate(mana, 1000, 7, 1 / 60) end
check(near(mana, Rules.regenerate(0, 1000, 7, 10)), "regen invariant at 60 Hz")
mana = 0
for _, dt in { .1, .04, .26, .3, .3 } do mana = Rules.regenerate(mana, 1000, 7, dt) end
check(near(mana, 7), "variable frame duration")
check(Rules.nextCombo(0, -math.huge, 5, 1.05) == 1, "first strike")
check(Rules.nextCombo(1, 5, 5.5, 1.05) == 2, "combo advances")
check(Rules.nextCombo(4, 5, 5.7, 1.05) == 1, "combo wraps after fourth")
check(Rules.nextCombo(3, 5, 6.1, 1.05) == 1, "idle resets combo")
check(not Rules.canAct(100, 1, 1.1, 0), "recovery prevents repeated hits")
check(not Rules.canAct(100, 1, 0, 1.1), "stun prevents actions")
check(not Rules.canAct(0, 1, 0, 0), "dead actors cannot act")
check(Rules.canAct(100, 1, 1, 1), "exact cooldown boundary")

local tokens, accepted = Config.Network.Burst, 0
for _ = 1, 1000 do
	local allowed
	allowed, tokens = Rules.consumeToken(tokens, 10, 10, Config.Network.Rate, Config.Network.Burst)
	if allowed then accepted += 1 end
end
check(accepted == Config.Network.Burst and tokens == 0, "remote burst bounded under 1000-request flood")
local allowed
allowed, tokens = Rules.consumeToken(tokens, 10, 10.5, Config.Network.Rate, Config.Network.Burst)
check(allowed and near(tokens, 9), "rate limiter recovers after half a second")
allowed, tokens = Rules.consumeToken(0, 10, 9, 20, 28)
check(not allowed and tokens == 0, "backwards time grants no request tokens")
allowed, tokens = Rules.consumeToken(0, 10, 1000, 20, 28)
check(allowed and tokens == 27, "long idle capped at burst")

local damage, guard, broken = Rules.guardHit(20, 60, 24, .2)
check(damage == 4 and guard == 36 and not broken, "front guard reduces damage")
damage, guard, broken = Rules.guardHit(20, 24, 24, .2)
check(damage == 20 and guard == 0 and broken, "depleted guard breaks and takes full damage")
local total = 0
guard = Config.Combat.GuardMax
for i, attack in Config.Combat.Attacks do
	check(attack.Windup + attack.Active < attack.Recovery, "active window fits recovery " .. i)
	damage, guard, broken = Rules.guardHit(attack.Damage, guard, attack.Guard, Config.Combat.BlockDamageFactor)
	total += damage
end
check(broken and guard == 0 and total > 20, "full four-hit chain breaks continuous guard")
check(Config.Movement.DashDuration < Config.Movement.DashCooldown, "dash cannot overlap itself")
check(Config.Movement.DashMana > 0 and Config.Player.ManaRegen > 0, "mana spend and recovery configured")
check(Config.Training.EnemyAttackGap + 0.15 < Config.Combat.ComboReset, "AI chain survives its scheduling interval")
print(string.format("PASS: %d pure-rule assertions (Luau CLI; no Roblox engine)", passed))
