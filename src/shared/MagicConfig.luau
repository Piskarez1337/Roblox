--!strict
-- Serializable balance data: usable by Roblox and the standalone test runner.
export type MagicClass = { Name: string, Color: { number }, Accent: { number }, Passive: string, Drain: number, Awakening: string }
return {
	Order = { "Water", "Wind", "Earth", "Ice", "Bone", "Stars", "Anti" },
	Classes = {
		Water = { Name = "Вода", Color = { 78, 191, 255 }, Accent = { 200, 245, 255 }, Passive = "Защита + восстановление HP вне боя", Drain = 1, Awakening = "Доспехи Валькирии" },
		Wind = { Name = "Ветер", Color = { 90, 240, 158 }, Accent = { 225, 255, 200 }, Passive = "Скорость + воздушный рывок", Drain = 7, Awakening = "Дух ветра" },
		Earth = { Name = "Земля", Color = { 184, 145, 83 }, Accent = { 255, 214, 120 }, Passive = "Снижение урона и отбрасывания", Drain = 0, Awakening = "" },
		Ice = { Name = "Лёд", Color = { 155, 225, 255 }, Accent = { 245, 253, 255 }, Passive = "Накопительное замедление", Drain = 0, Awakening = "" },
		Bone = { Name = "Кости", Color = { 225, 215, 191 }, Accent = { 190, 65, 135 }, Passive = "Восстановление HP от костяных атак", Drain = 5, Awakening = "Костяной демон" },
		Stars = { Name = "Звёзды", Color = { 178, 119, 255 }, Accent = { 255, 216, 111 }, Passive = "Перезарядка телепортации −20%", Drain = 0, Awakening = "" },
		Anti = { Name = "Антимагия", Color = { 245, 64, 82 }, Accent = { 34, 20, 42 }, Passive = "Защита от магии + усиленное парирование", Drain = 7, Awakening = "Чёрный демон" },
	} :: { [string]: MagicClass },
	TransformTime = 2.4, ActivationMinimum = 5, ToggleCooldown = 2, SelectCooldown = 1.5,
	Flight = { Duration = 4, Cooldown = 8, Speed = 37, InputTimeout = 0.45 },
	Limits = { Projectiles = 96, ProjectilesPerOwner = 22, Fields = 64, FieldsPerOwner = 12, VFXParts = 850, VFXDistance = 180 },
	Passives = { WaterDefense = 0.92, WaterRegen = 2, WindSpeed = 1.15, WindAirDash = 1.4,
		EarthDefense = 0.85, EarthKnockback = 0.55, IceSlowPerStack = 0.08, IceStacks = 4, IceDuration = 3.5,
		BoneLeech = 0.12, BoneHealPerSecond = 9, StarsTeleport = 0.8, AntiDefense = 0.75, AntiParryBonus = 0.18 },
	Audio = { Cast = "rbxasset://sounds/action_jump.mp3", Impact = "rbxasset://sounds/action_jump_land.mp3",
		Water = "rbxasset://sounds/impact_water.mp3", Transform = "rbxasset://sounds/action_get_up.mp3" },
}
