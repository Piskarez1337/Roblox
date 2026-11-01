--!nonstrict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local package = ReplicatedStorage:WaitForChild("BlackClover")
local shared = package:WaitForChild("Shared")
local Config = require(shared:WaitForChild("Config"))
local Rules = require(shared:WaitForChild("Rules"))
local Animation = require(script.Parent:WaitForChild("AnimationController"))
local VFX = require(script.Parent:WaitForChild("VFXController"))
local HUD = require(script.Parent:WaitForChild("HUDController"))
local MagicHUD = require(script.Parent:WaitForChild("MagicHUD"))
local MagicEquipment = require(script.Parent:WaitForChild("MagicEquipment"))
local MagicVFX = require(script.Parent:WaitForChild("MagicVFX"))
local remotes = package:WaitForChild("Remotes")
local action = remotes:WaitForChild("Action")
local attackHeld, queuedUntil, nextAttack = false, 0, 0
local sprintHeld, blockHeld = false, false
local nextBlockTry = 0

Animation:Start()
VFX:Start()
HUD:Start()
MagicEquipment:Start()
remotes:WaitForChild("MagicFX")
MagicHUD:Start(HUD.Canvas, action, remotes)
MagicVFX:Start(remotes.MagicFX)

local function resetInput()
	attackHeld, queuedUntil, nextAttack = false, 0, 0
	sprintHeld, blockHeld = false, false
	action:FireServer("Block", false)
	action:FireServer("Sprint", false)
	Animation:CancelPrediction()
end

local function attack(now)
	if MagicHUD.Menu.Visible then return end
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or now < nextAttack or blockHeld then return end
	if (character:GetAttribute("StunUntil") or 0) > now or (character:GetAttribute("DashUntil") or 0) > now
		or (character:GetAttribute("RootedUntil") or 0) > now
		or (character:GetAttribute("CastSpell") ~= "" and (character:GetAttribute("CastEnd") or 0) > now) then return end
	local index = Rules.nextCombo(character:GetAttribute("AttackIndex") or 0, character:GetAttribute("AttackStart") or 0,
		now, Config.Combat.ComboReset)
	-- The server confirms or rejects this cosmetic prediction. It never grants damage.
	Animation:Predict(character, index, now)
	nextAttack = now + Config.Combat.Attacks[index].Recovery + 0.025
	queuedUntil = 0
	action:FireServer("Attack")
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() or MagicHUD.Menu.Visible then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		attackHeld = true
		queuedUntil = workspace:GetServerTimeNow() + 0.16
		attack(workspace:GetServerTimeNow())
	elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		sprintHeld = true
		action:FireServer("Sprint", true)
	elseif input.KeyCode == Enum.KeyCode.F then
		blockHeld = true
		nextBlockTry = workspace:GetServerTimeNow() + 0.25
		action:FireServer("Block", true)
	elseif input.KeyCode == Enum.KeyCode.Q then
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then action:FireServer("Dash", humanoid.MoveDirection) end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then attackHeld = false
	elseif input.KeyCode == Enum.KeyCode.F then
		blockHeld = false
		action:FireServer("Block", false)
		if sprintHeld then action:FireServer("Sprint", true) end
	elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		sprintHeld = false
		action:FireServer("Sprint", false)
	end
end)
UserInputService.WindowFocusReleased:Connect(resetInput)
UserInputService.TextBoxFocused:Connect(resetInput)
localPlayer.CharacterAdded:Connect(function()
	resetInput()
	HUD.CreatedAt = os.clock()
end)
localPlayer.CharacterRemoving:Connect(resetInput)
MagicHUD.Menu:GetPropertyChangedSignal("Visible"):Connect(function() if MagicHUD.Menu.Visible then resetInput() end end)

remotes:WaitForChild("FX").OnClientEvent:Connect(function(kind, ...)
	if kind == "Rejected" then
		local rejected = ...
		if rejected == "Attack" then Animation:CancelPrediction(); nextAttack = workspace:GetServerTimeNow() + 0.14 end
		return
	end
	VFX:Handle(kind, ...)
end)

RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	if attackHeld or now < queuedUntil then attack(now) end
	local character = localPlayer.Character
	if blockHeld and character and not character:GetAttribute("Blocking") and now >= nextBlockTry then
		nextBlockTry = now + 0.25
		action:FireServer("Block", true)
	end
end)

-- Run before the default camera so CameraOffset is included without cumulative drift.
RunService:BindToRenderStep("BlackCloverPresentation", Enum.RenderPriority.Camera.Value - 1, function(dt)
	HUD:Step(dt)
	VFX:Step(dt)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	if humanoid and camera then
		local t = os.clock() * 58
		humanoid.CameraOffset = Vector3.new(math.sin(t) * VFX.Shake, math.cos(t * 1.17) * VFX.Shake * 0.65, 0)
		local desired = character:GetAttribute("Sprinting") and humanoid.MoveDirection.Magnitude > 0 and 77 or 70
		local age = workspace:GetServerTimeNow() - (character:GetAttribute("TransformStart") or 0)
		if character:GetAttribute("Awakened") and age >= 0 and age < 2.4 then desired = 70 - math.sin(age / 2.4 * math.pi) * 11 end
		camera.FieldOfView += (desired - camera.FieldOfView) * (1 - math.exp(-7 * dt))
	end
end)
