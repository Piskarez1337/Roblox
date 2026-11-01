--!nonstrict
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local shared = game:GetService("ReplicatedStorage").BlackClover.Shared
local Config, Spells = require(shared.MagicConfig), require(shared.SpellRegistry)
local Art = require(script.Parent.MagicArt)
local UI = { Cards = {}, LastFlight = 0 }
local function object(class, parent, props)
	local item = Instance.new(class)
	for key, value in props do item[key] = value end
	item.Parent = parent
	return item
end
local function text(parent, value, position, size, fontSize, color)
	return object("TextLabel", parent, { Text = value, Position = position, Size = size, BackgroundTransparency = 1,
		TextColor3 = color or Color3.fromRGB(228, 237, 236), Font = Enum.Font.GothamMedium, TextSize = fontSize,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
end
local function panel(parent, position, size, anchor, button)
	local frame = object(button and "TextButton" or "Frame", parent, { Position = position, Size = size,
		AnchorPoint = anchor or Vector2.zero, BackgroundColor3 = Color3.fromRGB(12, 22, 31), BackgroundTransparency = .08, BorderSizePixel = 0 })
	if button then frame.Text = ""; frame.AutoButtonColor = true end
	object("UICorner", frame, { CornerRadius = UDim.new(0, 9) })
	object("UIStroke", frame, { Color = Color3.fromRGB(83, 111, 117), Transparency = .25 })
	return frame
end
function UI:Notice(message)
	self.Toast.Text, self.ToastUntil = message, os.clock() + 3
end
function UI:Cast(slot)
	local character = Players.LocalPlayer.Character
	if not character or self.Menu.Visible then return end
	local spell = Spells.Get(character:GetAttribute("MagicId"), character:GetAttribute("Awakened"), slot)
	if not spell then self:Notice("Сначала выберите магию: M"); return end
	local now = workspace:GetServerTimeNow()
	local recall = spell.Kind == "Summon" and character:GetAttribute("HasGolem")
	if not recall and (character:GetAttribute("Mana") or 0) < spell.ManaCost then self:Notice("Недостаточно маны"); return end
	if not recall and (character:GetAttribute("CD_" .. spell.Id) or 0) > now then self:Notice("Способность восстанавливается"); return end
	self.Action:FireServer("Cast", { Slot = slot, Point = self.Mouse.Hit.Position })
end
function UI:Awakening()
	local character = Players.LocalPlayer.Character
	local class = character and Config.Classes[character:GetAttribute("MagicId")]
	if not class or class.Drain <= 0 then self:Notice("Пробуждение есть у Воды, Ветра, Костей и Антимагии"); return end
	self.Action:FireServer("Awakening")
end
function UI:FlightDirection()
	local camera = workspace.CurrentCamera
	if not camera then return Vector3.zero end
	local direction = Vector3.zero
	if Input:IsKeyDown(Enum.KeyCode.W) then direction += camera.CFrame.LookVector end
	if Input:IsKeyDown(Enum.KeyCode.S) then direction -= camera.CFrame.LookVector end
	if Input:IsKeyDown(Enum.KeyCode.D) then direction += camera.CFrame.RightVector end
	if Input:IsKeyDown(Enum.KeyCode.A) then direction -= camera.CFrame.RightVector end
	if Input:IsKeyDown(Enum.KeyCode.Space) then direction += Vector3.yAxis end
	if Input:IsKeyDown(Enum.KeyCode.LeftControl) then direction -= Vector3.yAxis end
	return direction.Magnitude > 1 and direction.Unit or direction
end
function UI:StopFlight()
	self.WantsFlight = false
	self.Action:FireServer("Flight", { Active = false })
end
function UI:Start(parent, action, remotes)
	self.Action, self.Mouse = action, Players.LocalPlayer:GetMouse()
	local choose = panel(parent, UDim2.new(1, -24, 0, 18), UDim2.fromOffset(225, 58), Vector2.new(1, 0), true)
	self.Selected = text(choose, "M  ВЫБРАТЬ МАГИЮ", UDim2.fromOffset(16, 8), UDim2.fromOffset(195, 22), 12)
	text(choose, "Гримуар · способности · пробуждение", UDim2.fromOffset(16, 32), UDim2.fromOffset(195, 17), 9, Color3.fromRGB(158, 180, 183))
	self.Menu = panel(parent, UDim2.fromScale(.5, .43), UDim2.fromOffset(730, 400), Vector2.new(.5, .5))
	self.Menu.Visible = false
	self.Menu.ZIndex = 20
	text(self.Menu, "ВЫБЕРИТЕ СВОЙ ГРИМУАР", UDim2.fromOffset(24, 18), UDim2.fromOffset(650, 32), 20)
	text(self.Menu, "Смена магии сохраняет ману и перезарядки.  M — закрыть", UDim2.fromOffset(24, 52), UDim2.fromOffset(650, 24), 11, Color3.fromRGB(163, 185, 185))
	for i, id in Config.Order do
		local column, row = (i - 1) % 4, math.floor((i - 1) / 4)
		local card = panel(self.Menu, UDim2.fromOffset(24 + column * 174, 95 + row * 137), UDim2.fromOffset(162, 122), nil, true)
		card.ZIndex = 21
		local class = Config.Classes[id]
		local title = text(card, class.Name, UDim2.fromOffset(12, 8), UDim2.fromOffset(140, 27), 17, Art:Color(id))
		title.ZIndex = 22
		local passive = text(card, class.Passive, UDim2.fromOffset(12, 40), UDim2.fromOffset(138, 44), 11)
		passive.ZIndex = 22
		local description = text(card, class.Drain > 0 and ("G · −" .. class.Drain .. " маны/с") or "4 базовых заклинания", UDim2.fromOffset(12, 91), UDim2.fromOffset(140, 20), 10, Color3.fromRGB(176, 194, 190))
		description.ZIndex = 22
		card.Activated:Connect(function() self.Action:FireServer("SelectMagic", id); self.Menu.Visible = false end)
	end
	choose.Activated:Connect(function() self.Menu.Visible = not self.Menu.Visible end)
	local strip = panel(parent, UDim2.new(.5, 0, 1, -130), UDim2.fromOffset(560, 85), Vector2.new(.5, 1))
	for i, slot in { "Z", "X", "C", "V" } do
		local card = panel(strip, UDim2.fromOffset(8 + (i - 1) * 108, 7), UDim2.fromOffset(102, 71), nil, true)
		local key = text(card, slot, UDim2.fromOffset(9, 4), UDim2.fromOffset(21, 20), 16)
		local cost = text(card, "", UDim2.fromOffset(35, 4), UDim2.fromOffset(60, 20), 10)
		local name = text(card, "Выберите магию", UDim2.fromOffset(9, 27), UDim2.fromOffset(88, 34), 10)
		self.Cards[slot] = { Frame = card, Key = key, Cost = cost, Name = name }
		card.Activated:Connect(function() self:Cast(slot) end)
	end
	local awakening = panel(strip, UDim2.fromOffset(442, 7), UDim2.fromOffset(110, 71), nil, true)
	self.AwakeningText = text(awakening, "G\nПРОБУЖДЕНИЕ", UDim2.fromOffset(8, 5), UDim2.fromOffset(94, 60), 11)
	awakening.Activated:Connect(function() self:Awakening() end)
	self.Toast = text(parent, "", UDim2.new(.5, 0, .16, 0), UDim2.fromOffset(620, 44), 15, Color3.fromRGB(248, 212, 143))
	self.Toast.AnchorPoint, self.Toast.TextXAlignment = Vector2.new(.5, 0), Enum.TextXAlignment.Center
	self.Toast.TextStrokeTransparency = .5
	Input.InputBegan:Connect(function(input, processed)
		if processed or Input:GetFocusedTextBox() then return end
		local key = input.KeyCode.Name
		if key == "M" then self.Menu.Visible = not self.Menu.Visible; return end
		if self.Menu.Visible then return end
		if self.Cards[key] then self:Cast(key)
		elseif key == "G" then self:Awakening()
		elseif key == "R" then
			if self.WantsFlight then self:StopFlight()
			else self.WantsFlight = true; self.FlightRequested = workspace:GetServerTimeNow(); self.Action:FireServer("Flight", { Active = true, Direction = self:FlightDirection() }) end
		end
	end)
	Input.WindowFocusReleased:Connect(function() self:StopFlight() end)
	Input.TextBoxFocused:Connect(function() self:StopFlight() end)
	Players.LocalPlayer.CharacterAdded:Connect(function() self:StopFlight(); self.OpenedFor = nil end)
	remotes.MagicFX.OnClientEvent:Connect(function(kind, message) if kind == "Notice" then self:Notice(message) end end)
	remotes.FX.OnClientEvent:Connect(function(kind, rejected)
		if kind ~= "Rejected" then return end
		if rejected == "Flight" then self.WantsFlight = false; self:Notice("Полёт доступен в пробуждении Ветра и Антимагии: до 4 с, R")
		elseif rejected == "Cast" or rejected == "Awakening" or rejected == "SelectMagic" then self:Notice("Действие недоступно: проверьте ману, перезарядку и состояние персонажа") end
	end)
	RunService.RenderStepped:Connect(function() self:Step() end)
end
function UI:Step()
	local character = Players.LocalPlayer.Character
	if not character then return end
	local id = character:GetAttribute("MagicId") or ""
	local class = Config.Classes[id]
	local now, awakened = workspace:GetServerTimeNow(), character:GetAttribute("Awakened") == true
	if not class and self.OpenedFor ~= character then self.Menu.Visible = true; self.OpenedFor = character end
	self.Selected.Text = "M  " .. (class and string.upper(class.Name) or "ВЫБРАТЬ МАГИЮ")
	for slot, card in self.Cards do
		local spell = Spells.Get(id, awakened, slot)
		card.Frame.UIStroke.Color = class and Art:Color(id) or Color3.fromRGB(83, 111, 117)
		if spell then
			local remaining = math.max(0, (character:GetAttribute("CD_" .. spell.Id) or 0) - now)
			local recall = spell.Kind == "Summon" and character:GetAttribute("HasGolem")
			card.Name.Text = recall and "Отозвать голема" or spell.Name
			card.Cost.Text = recall and "ОТОЗВАТЬ" or (remaining > 0 and string.format("%.1f с", remaining) or (tostring(spell.ManaCost) .. " маны"))
			card.Key.TextColor3 = remaining > 0 and Color3.fromRGB(112, 131, 139) or Art:Color(id)
		end
	end
	self.AwakeningText.Text = awakened and class and ("G · ОТКЛЮЧИТЬ\n−" .. class.Drain .. " маны/с")
		or (class and class.Drain > 0 and "G\nПРОБУЖДЕНИЕ" or "G\n—")
	self.AwakeningText.TextColor3 = class and Art:Color(id) or Color3.fromRGB(112, 131, 139)
	self.Toast.Visible = os.clock() < (self.ToastUntil or 0)
	if self.WantsFlight then
		local untilTime = character:GetAttribute("FlightUntil") or 0
		if now > (self.FlightRequested or 0) + .65 and untilTime <= now then self.WantsFlight = false
		elseif now - self.LastFlight >= .1 then
			self.LastFlight = now
			self.Action:FireServer("Flight", { Active = true, Direction = self:FlightDirection() })
		end
	end
end
return UI
