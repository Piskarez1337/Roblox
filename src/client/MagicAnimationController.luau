--!nonstrict
local shared = game:GetService("ReplicatedStorage").BlackClover.Shared
local Spells = require(shared:WaitForChild("SpellRegistry"))
local Config = require(shared.MagicConfig)
local Core = require(shared.Config)
local Animation = {}
local function r(x, y, z) return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0)) end
local function blend(a, b, t)
	local result = {}
	for key, value in a do result[key] = value:Lerp(b[key] or CFrame.identity, t) end
	for key, value in b do if not result[key] then result[key] = CFrame.identity:Lerp(value, t) end end
	return result
end
local function casting(spell, charge, released, age)
	local side = spell.Flavor % 2 == 0 and 1 or -1
	local nuance = (spell.Flavor % 5 - 2) * 3
	local pose = { Waist = r(-6, side * (8 + nuance), 0), Neck = r(5, -side * 5), RightHip = r(-8), LeftHip = r(12), LeftKnee = r(-14) }
	local style = spell.Style
	if style == "Bolt" or style == "Release" or style == "Dragon" then
		pose.RightShoulder, pose.RightElbow = r(released and 100 or 45 + charge * 20, nuance, -8), r(released and 8 or 80)
		pose.LeftShoulder, pose.LeftElbow = r(style == "Dragon" and 80 or 30, 0, -25), r(65)
		pose.Waist = r(released and -18 or -7, side * 15)
	elseif style == "Raise" or style == "Summon" or style == "Judgment" then
		local height = style == "Judgment" and 165 or (style == "Summon" and 135 or 110)
		pose.RightShoulder, pose.LeftShoulder = r(height * charge, 0, 25 + nuance), r(height * charge, 0, -25 - nuance)
		pose.RightElbow, pose.LeftElbow = r(20), r(20)
		pose.Waist, pose.Neck = r(8 * charge), r(-12 * charge)
		if released then pose.RightShoulder, pose.LeftShoulder, pose.Waist = r(80, 0, 30), r(80, 0, -30), r(-15) end
	elseif style == "Ground" then
		pose.Root = CFrame.new(0, -charge * .6, 0)
		pose.Waist, pose.RightHip, pose.LeftHip = r(-35 * charge), r(40 * charge), r(25 * charge)
		pose.RightKnee, pose.LeftKnee = r(-65 * charge), r(-55 * charge)
		pose.RightShoulder, pose.RightElbow = r(released and 15 or 155 * charge, 0, 10), r(released and 0 or 55)
		pose.LeftShoulder, pose.LeftElbow = r(35, 0, -45), r(25)
	elseif style == "Thrust" or style == "SwordThrust" then
		pose.Waist = r(-18, released and -25 or 25)
		pose.RightShoulder, pose.RightElbow = r(released and 95 or 25, 0, 30), r(released and 0 or 100)
		pose.LeftShoulder, pose.LeftElbow = r(55, 0, -20), r(75)
		pose.RightHip, pose.LeftHip = r(released and 28 or -20), r(released and -25 or 25)
	elseif style == "Slash" or style == "SwordSlash" or style == "SwordCleave" then
		pose.Waist = r(-10, released and -side * 55 or side * 40 * charge)
		pose.RightShoulder, pose.RightElbow = r(style == "SwordCleave" and 165 or 90, released and 20 or -35, released and -40 or 55), r(released and 12 or 70)
		pose.LeftShoulder, pose.LeftElbow = r(55, 0, -20), r(65)
	elseif style == "Spin" then
		pose.Root = r(0, released and age * 700 or -30, 0)
		pose.Waist, pose.RightShoulder, pose.LeftShoulder = r(-8), r(80, 0, 55), r(60, 0, -65)
		pose.RightElbow, pose.LeftElbow = r(15), r(40)
	elseif style == "Bind" then
		pose.RightShoulder, pose.LeftShoulder = r(90, -15 - nuance, -10), r(90, 15 + nuance, 10)
		pose.RightElbow, pose.LeftElbow = r(released and 5 or 70), r(released and 5 or 70)
	elseif style == "Barrage" then
		pose.RightShoulder, pose.LeftShoulder = r(115, 0, 25), r(100 + math.sin(age * 18) * 15, 0, -25)
		pose.RightElbow, pose.LeftElbow = r(30), r(40)
	elseif style == "Teleport" then
		pose.Waist = r(-12, age * 220)
		pose.RightShoulder, pose.LeftShoulder = r(55, 25, -45), r(55, -25, 45)
		pose.RightElbow, pose.LeftElbow = r(100), r(100)
	elseif style == "Parry" then
		pose.RightShoulder, pose.LeftShoulder = r(80, 0, -30), r(70, 0, 20)
		pose.RightElbow, pose.LeftElbow = r(90), r(80)
		pose.Waist = r(-8, 25)
	elseif style == "Ascend" then
		pose.RightShoulder, pose.LeftShoulder = r(145, 0, 30), r(110, 0, -45)
		pose.RightHip, pose.LeftHip, pose.RightKnee = r(35), r(-15), r(-50)
	end
	return pose
end
function Animation:GetPose(character, now)
	local transformation = character:GetAttribute("TransformStart") or 0
	if character:GetAttribute("Awakened") and transformation > 0 and now - transformation < Config.TransformTime then
		local t = math.clamp((now - transformation) / Config.TransformTime, 0, 1)
		local id = character:GetAttribute("MagicId")
		local folded = { Waist = r(-20), Neck = r(10), RightShoulder = r(55, 20, -35), LeftShoulder = r(55, -20, 35), RightElbow = r(100), LeftElbow = r(100), RightHip = r(15), LeftHip = r(15), RightKnee = r(-25), LeftKnee = r(-25) }
		local opened = { Waist = r(8), Neck = r(-10), RightShoulder = r(id == "Anti" and 165 or 75, 0, 70), LeftShoulder = r(id == "Water" and 135 or 75, 0, -70), RightElbow = r(20), LeftElbow = r(20) }
		return blend(folded, opened, math.clamp((t - .3) / .5, 0, 1))
	end
	local spell = Spells.All[character:GetAttribute("CastSpell") or ""]
	if spell and now < (character:GetAttribute("CastEnd") or 0) then
		local age = now - (character:GetAttribute("CastStart") or now)
		local charge = math.clamp(age / math.max(.01, spell.CastTime), 0, 1)
		return casting(spell, charge, age >= spell.CastTime, age)
	end
	return nil
end
function Animation:Melee(character, index, age)
	local profile = character:GetAttribute("MeleeProfile")
	local definition = Core.Combat.Attacks[index]
	if profile == nil or profile == "Fist" or not definition or age < 0 or age > definition.Recovery then return nil end
	local style = profile == "Spear" and "Thrust" or (index == 4 and "SwordCleave" or "SwordSlash")
	local spell = { Style = style, Flavor = index }
	local pose = casting(spell, math.clamp(age / definition.Windup, 0, 1), age >= definition.Windup, age)
	if profile == "Spear" and index % 2 == 0 then pose.Waist = r(-12, index == 4 and 50 or -40) end
	local fade = math.clamp((age - definition.Windup - definition.Active) / math.max(.01, definition.Recovery - definition.Windup - definition.Active), 0, 1)
	return blend(pose, {}, fade)
end
function Animation:Stance(character, pose, speed, now)
	local profile = character:GetAttribute("MeleeProfile")
	if profile == "Sword" then
		pose.RightShoulder, pose.RightElbow = r(speed > 18 and -25 or 5, 15, 30), r(25)
		pose.Waist = pose.Waist * r(-4, -5)
	elseif profile == "Spear" or profile == "WindWeapon" then
		pose.RightShoulder, pose.RightElbow = r(15, 0, 22), r(35)
	end
	if (character:GetAttribute("FlightUntil") or 0) > now then
		pose.Waist, pose.RightHip, pose.LeftHip = r(-20), r(12), r(-20)
		pose.RightKnee, pose.LeftKnee, pose.LeftShoulder = r(-25), r(-25), r(-15, 0, -45)
	end
	return pose
end
return Animation
