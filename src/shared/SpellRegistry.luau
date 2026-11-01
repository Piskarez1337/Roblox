--!strict
-- Each entry is a complete spell contract. Executors implement mechanics by Kind.
export type Spell = {
	Id: string, ElementType: string, Slot: string, Awakened: boolean, Name: string, Kind: string,
	ManaCost: number, Cooldown: number, CastTime: number, Recovery: number, Damage: number,
	ClashPower: number, Range: number, HitboxSize: number, Radius: number, Style: string,
	Flavor: number, Speed: number, Duration: number, Tick: number, Count: number, Stun: number,
	Knockback: number, Visual: string, Channel: number, Reflectable: boolean,
	RootTime: number?, [string]: any,
}
type Group = { Base: { [string]: string }, Awakened: { [string]: string } }
local Registry = { All = {} :: { [string]: Spell }, ByMagic = {} :: { [string]: Group } }
local serial = 0
local function spell(element: string, slot: string, awakened: boolean, name: string, kind: string, mana: number, cooldown: number,
	cast: number, damage: number, power: number, range: number, radius: number, style: string, extra: { [string]: any }?)
	serial += 1
	local id = element .. "_" .. (awakened and "A" or "") .. slot
	local definition: Spell = { Id = id, ElementType = element, Slot = slot, Awakened = awakened, Name = name,
		Kind = kind, ManaCost = mana, Cooldown = cooldown, CastTime = cast, Recovery = 0.22,
		Damage = damage, ClashPower = power, Range = range, HitboxSize = radius * 2, Radius = radius,
		Style = style, Flavor = serial, Speed = 85, Duration = 3, Tick = 0.5, Count = 1,
		Stun = 0.15, Knockback = 10, Visual = kind, Channel = 0, Reflectable = true }
	for key, value in extra or {} do definition[key] = value end
	Registry.All[id] = definition
	Registry.ByMagic[element] = Registry.ByMagic[element] or { Base = {}, Awakened = {} }
	local group = Registry.ByMagic[element]
	local slots = awakened and group.Awakened or group.Base
	slots[slot] = id
end

spell("Water", "Z", false, "Водяной шар", "Projectile", 12, 3, .35, 24, 24, 100, 1.4, "Bolt", { Visual = "WaterOrb", Explosion = 6 })
spell("Water", "X", false, "Гнездо морского дракона", "Shield", 18, 10, .45, 0, 42, 0, 6, "Raise", { Duration = 6, Reduction = .45, ShieldHP = 110, Visual = "WaterDome" })
spell("Water", "C", false, "Рёв морского дракона", "Projectile", 24, 8, .7, 36, 48, 115, 3.2, "Dragon", { Visual = "Dragon", Speed = 62, Pierce = true, Stun = .3 })
spell("Water", "V", false, "Копьё морского рыцаря", "DashStrike", 18, 6, .4, 32, 36, 26, 3.5, "Thrust", { Weapon = "WaterSpear", Duration = .3, Speed = 87 })
spell("Water", "Z", true, "Небесный выпад Валькирии", "DashStrike", 20, 5, .28, 58, 70, 44, 5, "Thrust", { Weapon = "WaterSpear", Duration = .38, Speed = 116 })
spell("Water", "X", true, "Танец морских копий", "Spin", 26, 10, .4, 12, 70, 0, 14, "Spin", { Duration = 2.4, Tick = .4, Channel = 2.4, Visual = "SpearDance" })
spell("Water", "C", true, "Божественный дракон", "Dive", 30, 14, .9, 78, 95, 140, 5, "Summon", { Visual = "Dragon", Explosion = 15, Speed = 85 })
spell("Water", "V", true, "Приговор морской богини", "Judgment", 38, 22, 1.1, 12, 110, 110, 24, "Judgment", { Count = 12, Duration = 2.5, Channel = 2.5, FinalDamage = 65, Visual = "SpearJudgment" })

spell("Wind", "Z", false, "Ветряной клинок", "Projectile", 10, 2.8, .22, 22, 21, 120, 1.6, "Slash", { Visual = "WindBlade", Speed = 120 })
spell("Wind", "X", false, "Торнадо", "Tornado", 22, 10, .55, 6, 36, 75, 9, "Raise", { Duration = 4, Tick = .45, Speed = 11, Pull = 20, Visual = "Tornado" })
spell("Wind", "C", false, "Белый ястреб", "Projectile", 18, 7, .5, 30, 30, 130, 2, "Release", { Visual = "Hawk", Speed = 67, Homing = 5, Explosion = 5 })
spell("Wind", "V", false, "Шторм духа", "Volley", 26, 11, .6, 11, 22, 110, 1.8, "Barrage", { Count = 7, Spread = 22, Interval = .1, Visual = "WindBlade", Speed = 110 })
spell("Wind", "Z", true, "Небесный разрез", "Projectile", 19, 5, .35, 50, 65, 150, 4, "Slash", { Visual = "WindBlade", Speed = 145 })
spell("Wind", "X", true, "Королевский вихрь", "Tornado", 30, 13, .7, 8, 62, 100, 11, "Raise", { Count = 3, Duration = 5, Tick = .45, Speed = 14, Pull = 25, Visual = "Tornado" })
spell("Wind", "C", true, "Духовное копьё", "Projectile", 27, 10, .65, 72, 90, 175, 2.8, "Thrust", { Visual = "WindLance", Speed = 190, Pierce = true })
spell("Wind", "V", true, "Суд небес", "Domain", 35, 22, 1, 13, 110, 110, 26, "Ascend", { Duration = 4, Tick = .5, FinalDamage = 35, LiftCaster = true, Visual = "SkyStorm" })

spell("Earth", "Z", false, "Земляные клыки", "Spikes", 15, 5, .45, 10, 27, 54, 4, "Ground", { Count = 8, Interval = .12, Visual = "EarthSpikes" })
spell("Earth", "X", false, "Земляная стена", "Wall", 20, 10, .5, 0, 70, 12, 9, "Raise", { Duration = 12, WallHP = 180, Visual = "EarthWall" })
spell("Earth", "C", false, "Каменная печать", "Prison", 20, 10, .6, 18, 40, 70, 8, "Bind", { RootTime = 1.8, Duration = 2.5, Visual = "EarthPrison" })
spell("Earth", "V", false, "Буйство матери земли", "Summon", 32, 24, 1, 18, 60, 16, 5, "Summon", { Duration = 30, SummonHP = 320, SlamDamage = 28, Visual = "Golem" })

spell("Ice", "Z", false, "Ледяные клыки", "Spikes", 15, 5, .4, 9, 26, 54, 4, "Ground", { Count = 8, Interval = .12, Visual = "IceSpikes" })
spell("Ice", "X", false, "Ледяной резак", "Volley", 19, 7, .4, 15, 28, 110, 1.8, "Release", { Count = 3, Spread = 10, Interval = .12, Visual = "IceDisc", Speed = 95 })
spell("Ice", "C", false, "Кристальный щит", "Shield", 20, 11, .5, 0, 60, 0, 5, "Raise", { Duration = 5, Reduction = .7, ShieldHP = 100, Visual = "IceShield" })
spell("Ice", "V", false, "Ледниковая катастрофа", "Domain", 32, 17, .85, 9, 65, 95, 22, "Ground", { Duration = 6, Tick = .7, Visual = "Blizzard", PulseRadius = 8 })

spell("Bone", "Z", false, "Костяные пики", "Spikes", 15, 5, .4, 10, 28, 54, 4, "Ground", { Count = 8, Interval = .12, Visual = "BoneSpikes" })
spell("Bone", "X", false, "Костяная темница", "Prison", 23, 11, .65, 20, 42, 80, 8, "Bind", { RootTime = 2, Duration = 3, Delay = .45, Visual = "BonePrison" })
spell("Bone", "C", false, "Костяное копьё", "DashStrike", 18, 6, .4, 35, 38, 24, 3.5, "Thrust", { Weapon = "BoneSpear", Duration = .3, Speed = 80 })
spell("Bone", "V", false, "Костяной дождь", "Rain", 27, 12, .7, 10, 22, 100, 16, "Barrage", { Count = 14, Interval = .12, Explosion = 3.5, Visual = "BoneSpear", Speed = 105 })
spell("Bone", "Z", true, "Демонический разрез", "Projectile", 19, 5, .4, 49, 68, 115, 4, "Slash", { Visual = "BoneArc", Speed = 95, Pierce = true })
spell("Bone", "X", true, "Могила тысячи костей", "Prison", 29, 13, .9, 44, 80, 100, 17, "Bind", { RootTime = 2.4, Duration = 4, Delay = .5, Visual = "BoneGrave" })
spell("Bone", "C", true, "Рука костяного владыки", "Hand", 28, 12, .75, 68, 85, 100, 12, "Summon", { Duration = 2, RootTime = 1.1, Visual = "BoneHand", Knockback = 35 })
spell("Bone", "V", true, "Королевство мёртвых костей", "Domain", 35, 23, 1.1, 14, 110, 100, 28, "Judgment", { Duration = 5, Tick = .65, Visual = "BoneKingdom", PulseRadius = 13 })

spell("Stars", "Z", false, "Звёздный выстрел", "Projectile", 12, 3.5, .25, 26, 25, 130, 1.2, "Bolt", { Visual = "Star", Speed = 135, Explosion = 5 })
spell("Stars", "X", false, "Звёздная телепортация", "Teleport", 16, 5, .2, 0, 10, 36, 2, "Teleport", { Visual = "StarGate" })
spell("Stars", "C", false, "Астральная тюрьма", "Prison", 21, 10, .6, 21, 40, 85, 8, "Bind", { RootTime = 1.8, Duration = 2.5, Visual = "StarPrison" })
spell("Stars", "V", false, "Падение созвездия", "Rain", 32, 15, .85, 21, 42, 115, 19, "Summon", { Count = 7, Interval = .22, Explosion = 6, Visual = "StarMeteor", Speed = 90 })

spell("Anti", "Z", false, "Чёрный разрез", "Projectile", 13, 4, .35, 27, 34, 110, 2.5, "SwordSlash", { Visual = "BlackArc", Speed = 100 })
spell("Anti", "X", false, "Демонический рывок", "DashStrike", 18, 6, .25, 35, 52, 32, 4.5, "SwordThrust", { Duration = .32, Speed = 100, Cut = true })
spell("Anti", "C", false, "Отражение магии", "Parry", 8, 5, .1, 0, 80, 0, 7, "Parry", { Duration = .35 })
spell("Anti", "V", false, "Чёрный ураган", "Spin", 27, 12, .3, 10, 62, 0, 12, "Spin", { Duration = 2, Tick = .33, Channel = 2, Cut = true, Visual = "BlackHurricane" })
spell("Anti", "Z", true, "Чёрный разделитель", "Projectile", 22, 6, .5, 62, 105, 140, 5, "SwordSlash", { Visual = "BlackArc", Speed = 110, Pierce = true })
spell("Anti", "X", true, "Демонический полёт", "DashStrike", 25, 10, .35, 56, 95, 48, 6, "Ascend", { Duration = .45, Speed = 107, Aerial = true, Cut = true })
spell("Anti", "C", true, "Абсолютное рассечение", "Projectile", 30, 13, .8, 85, 135, 140, 6, "SwordCleave", { Visual = "BlackArc", Speed = 180, Pierce = true, ConstructDamage = 250 })
spell("Anti", "V", true, "Конец магии", "Projectile", 38, 24, 1.4, 100, 180, 150, 9, "Judgment", { Visual = "EndMagic", Speed = 90, Pierce = true, Explosion = 18, Suppress = 5, ConstructDamage = 400, Reflectable = false })

function Registry.Get(element: string?, awakened: boolean?, slot: string): Spell?
	if not element then return nil end
	local group = Registry.ByMagic[element]
	if not group then return nil end
	local slots = awakened and group.Awakened or group.Base
	local id = slots[slot]
	return id and Registry.All[id] or nil
end
return Registry
