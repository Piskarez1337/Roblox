--!nonstrict
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").BlackClover.Shared.Config)
local HUD = { Health = 1, Mana = 1, Guard = 1 }
local ink = Color3.fromRGB(12, 23, 29)
local pale = Color3.fromRGB(230, 237, 227)
local gold = Color3.fromRGB(218, 186, 119)
local mint = Color3.fromRGB(102, 222, 202)
local muted = Color3.fromRGB(147, 167, 167)

local function create(class, properties, parent)
	local object = Instance.new(class)
	for key, value in properties do object[key] = value end
	object.Parent = parent
	return object
end
local function label(parent, text, position, size, fontSize, color)
	return create("TextLabel", { BackgroundTransparency = 1, Position = position, Size = size,
		Text = text, TextColor3 = color or pale, Font = Enum.Font.GothamMedium, TextSize = fontSize,
		TextXAlignment = Enum.TextXAlignment.Left }, parent)
end
local function panel(parent, position, size, anchor)
	local frame = create("Frame", { Position = position, Size = size, AnchorPoint = anchor or Vector2.zero,
		BackgroundColor3 = ink, BackgroundTransparency = 0.12, BorderSizePixel = 0 }, parent)
	create("UICorner", { CornerRadius = UDim.new(0, 10) }, frame)
	create("UIStroke", { Color = Color3.fromRGB(78, 99, 98), Transparency = 0.45, Thickness = 1 }, frame)
	return frame
end
local function bar(parent, y, name, color, height)
	local title = label(parent, name, UDim2.fromOffset(18, y), UDim2.fromOffset(285, 18), 11, muted)
	local track = create("Frame", { Position = UDim2.fromOffset(18, y + 22), Size = UDim2.fromOffset(284, height),
		BackgroundColor3 = Color3.fromRGB(36, 51, 57), BorderSizePixel = 0, ClipsDescendants = true }, parent)
	create("UICorner", { CornerRadius = UDim.new(0, 3) }, track)
	local fill = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, track)
	create("UICorner", { CornerRadius = UDim.new(0, 3) }, fill)
	return { Fill = fill, Title = title }
end

function HUD:Start()
	local gui = create("ScreenGui", { Name = "BlackCloverHUD", ResetOnSpawn = false, DisplayOrder = 10,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, Players.LocalPlayer:WaitForChild("PlayerGui"))
	self.Gui = gui
	local canvas = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	self.Canvas = canvas
	local mark = panel(canvas, UDim2.fromOffset(24, 18), UDim2.fromOffset(270, 58))
	label(mark, "♣", UDim2.fromOffset(14, 4), UDim2.fromOffset(42, 46), 38, gold)
	label(mark, "B L A C K   C L O V E R", UDim2.fromOffset(65, 9), UDim2.fromOffset(195, 20), 13, pale)
	label(mark, "ТРЕНИРОВОЧНЫЙ ДВОР  /  01", UDim2.fromOffset(65, 31), UDim2.fromOffset(195, 14), 9, muted)
	local status = panel(canvas, UDim2.new(0, 24, 1, -24), UDim2.fromOffset(320, 200), Vector2.new(0, 1))
	self.Identity = label(status, "УРОВЕНЬ 01  /  БЕЗ МАГИИ", UDim2.fromOffset(18, 12), UDim2.fromOffset(284, 22), 11, gold)
	self.HPBar = bar(status, 45, "ЗДОРОВЬЕ", Color3.fromRGB(217, 122, 115), 12)
	self.MPBar = bar(status, 88, "МАНА", mint, 12)
	self.GuardBar = bar(status, 131, "ЗАЩИТА", gold, 5)
	self.State = label(status, "ГОТОВ К БОЮ", UDim2.fromOffset(18, 171), UDim2.fromOffset(284, 18), 10, muted)
	local actions = panel(canvas, UDim2.new(0.5, 0, 1, -24), UDim2.fromOffset(340, 92), Vector2.new(0.5, 1))
	label(actions, "ЛКМ  /  РУКОПАШНОЕ КОМБО", UDim2.fromOffset(14, 10), UDim2.fromOffset(205, 16), 10, muted)
	self.Pips = {}
	for i = 1, 4 do
		local pip = panel(actions, UDim2.fromOffset(14 + (i - 1) * 39, 35), UDim2.fromOffset(31, 37))
		local number = label(pip, tostring(i), UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), 15, muted)
		number.TextXAlignment = Enum.TextXAlignment.Center
		self.Pips[i] = number
	end
	self.Dash = label(actions, "Q  РЫВОК", UDim2.fromOffset(185, 28), UDim2.fromOffset(140, 22), 13, mint)
	label(actions, "8 маны · 1.15 с", UDim2.fromOffset(185, 53), UDim2.fromOffset(140, 18), 10, muted)
	local help = panel(canvas, UDim2.new(1, -24, 1, -24), UDim2.fromOffset(250, 124), Vector2.new(1, 1))
	label(help, "УПРАВЛЕНИЕ", UDim2.fromOffset(16, 12), UDim2.fromOffset(218, 18), 10, gold)
	label(help, "Shift  Бег     Space  Прыжок\nF  Блок       Q  Рывок\nЛКМ  Удар / удерживать для серии", UDim2.fromOffset(16, 38), UDim2.fromOffset(220, 67), 11, pale)
	self.Hint = label(canvas, "Манекены — впереди. Часовые — у дальних ворот. Источник восстанавливает HP и ману.",
		UDim2.new(0.5, 0, 0, 26), UDim2.fromOffset(670, 42), 12, pale)
	self.Hint.AnchorPoint = Vector2.new(0.5, 0)
	self.Hint.TextXAlignment = Enum.TextXAlignment.Center
	self.Hint.TextWrapped = true
	self.Hint.TextStrokeTransparency = 0.55
	self.Hint.Visible = true
	self.CreatedAt = os.clock()
	self.Dead = label(canvas, "ВЫ ПАЛИ\nВозрождение через несколько секунд", UDim2.fromScale(0.5, 0.4), UDim2.fromOffset(600, 90), 24, pale)
	self.Dead.AnchorPoint, self.Dead.TextXAlignment = Vector2.new(0.5, 0.5), Enum.TextXAlignment.Center
	self.Dead.TextStrokeTransparency, self.Dead.Visible = 0.5, false
	-- Scale the design canvas while retaining edge anchors on narrower displays.
	self.Scale = create("UIScale", { Scale = 1 }, canvas)
end

function HUD:Step(dt)
	local camera = workspace.CurrentCamera
	if camera then
		local scale = math.clamp(camera.ViewportSize.X / 1440, 0.55, 1)
		self.Scale.Scale = scale
		self.Canvas.Size = UDim2.fromScale(1 / scale, 1 / scale)
	end
	self.Hint.Visible = os.clock() - self.CreatedAt < 18
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then self.State.Text = "ВОЗРОЖДЕНИЕ…"; return end
	local now = workspace:GetServerTimeNow()
	local health, maxHealth = humanoid.Health, humanoid.MaxHealth
	local mana, maxMana = character:GetAttribute("Mana") or 0, character:GetAttribute("MaxMana") or 100
	local guard = character:GetAttribute("Guard") or 0
	local alpha = 1 - math.exp(-12 * dt)
	self.Health += (health / math.max(1, maxHealth) - self.Health) * alpha
	self.Mana += (mana / math.max(1, maxMana) - self.Mana) * alpha
	self.Guard += (guard / Config.Combat.GuardMax - self.Guard) * alpha
	self.HPBar.Fill.Size = UDim2.fromScale(math.clamp(self.Health, 0, 1), 1)
	self.MPBar.Fill.Size = UDim2.fromScale(math.clamp(self.Mana, 0, 1), 1)
	self.GuardBar.Fill.Size = UDim2.fromScale(math.clamp(self.Guard, 0, 1), 1)
	self.HPBar.Title.Text = string.format("ЗДОРОВЬЕ                                  %d / %d", math.ceil(health), maxHealth)
	self.MPBar.Title.Text = string.format("МАНА                                          %d / %d", math.floor(mana), maxMana)
	self.GuardBar.Title.Text = string.format("ЗАЩИТА                                      %d / %d", math.floor(guard), Config.Combat.GuardMax)
	self.Identity.Text = string.format("УРОВЕНЬ %02d  /  БЕЗ МАГИИ", character:GetAttribute("Level") or 1)
	local cooldown = math.max(0, (character:GetAttribute("DashReady") or 0) - now)
	self.Dash.Text = cooldown > 0 and string.format("Q  %.1f с", cooldown) or "Q  РЫВОК"
	self.Dash.TextColor3 = cooldown > 0 and muted or mint
	local busy = now - (character:GetAttribute("AttackStart") or 0) < Config.Combat.ComboReset
	for i, pip in self.Pips do pip.TextColor3 = busy and i <= (character:GetAttribute("AttackIndex") or 0) and gold or muted end
	local stunned = (character:GetAttribute("StunUntil") or 0) > now
	self.State.Text = stunned and "ОГЛУШЕНИЕ" or (character:GetAttribute("Blocking") and "БЛОК · ЗАЩИТА СПЕРЕДИ"
		or (character:GetAttribute("Sprinting") and "СПРИНТ" or "ГОТОВ К БОЮ"))
	self.Dead.Visible = health <= 0
end

return HUD
