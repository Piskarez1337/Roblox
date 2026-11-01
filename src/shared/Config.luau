--!strict
-- All balance values for stage 1. Seconds, studs, HP, mana.
return table.freeze({
	Version = "0.2.0 / Magic",
	Player = { Health = 120, Mana = 100, ManaPerLevel = 10, ManaRegen = 7,
		ManaRegenDelay = 0.75, HealthRegen = 4, HealthRegenDelay = 7 },
	Movement = { Walk = 16, Sprint = 27, Block = 7, Jump = 48,
		DashSpeed = 64, DashDuration = 0.19, DashCooldown = 1.15, DashMana = 8 },
	Combat = {
		ComboReset = 1.05, Reach = 7.2, Width = 5, Height = 5.2,
		GuardMax = 60, GuardRegen = 22, GuardRegenDelay = 1.5,
		BlockDamageFactor = 0.2, BlockFacingDot = 0.15, GuardBreakStun = 1.1,
		Attacks = {
			{ Damage = 10, Windup = 0.12, Active = 0.10, Recovery = 0.38, Stun = 0.16, Knockback = 3, Guard = 12 },
			{ Damage = 11, Windup = 0.14, Active = 0.10, Recovery = 0.40, Stun = 0.18, Knockback = 4, Guard = 14 },
			{ Damage = 14, Windup = 0.19, Active = 0.12, Recovery = 0.48, Stun = 0.22, Knockback = 6, Guard = 18 },
			{ Damage = 20, Windup = 0.23, Active = 0.13, Recovery = 0.68, Stun = 0.32, Knockback = 27, Guard = 24 },
		},
	},
	Network = { Rate = 20, Burst = 28, StateInterval = 0.10, MaxVFXDistance = 220 },
	Training = { DummyHealth = 300, EnemyHealth = 110, Respawn = 4, EnemyAggro = 24,
		EnemyLeash = 38, EnemyAttackGap = 0.8, FountainDistance = 12, FountainCooldown = 3 },
	-- Roblox bundled movement sounds for stage 1; replace with owned audio for final art.
	Audio = { Swing = "rbxasset://sounds/action_jump.mp3", Hit = "rbxasset://sounds/action_jump_land.mp3",
		Block = "rbxasset://sounds/action_jump_land.mp3", Dash = "rbxasset://sounds/action_jump.mp3" },
})
