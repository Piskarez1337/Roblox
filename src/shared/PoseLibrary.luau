--!nonstrict
-- Original, asset-free R15 poses. Every transform is relative to the rig's bind pose.
local Config = require(script.Parent.Config)
local Pose = {}
local function r(x, y, z) return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0)) end

local windups = {
	{ Waist = r(-4, 22, 5), RightShoulder = r(35, -18, 12), RightElbow = r(95),
		LeftShoulder = r(45, 10, -18), LeftElbow = r(95), RightHip = r(-12), LeftHip = r(12), LeftKnee = r(-15) },
	{ Waist = r(-3, -25, -5), LeftShoulder = r(40, 20, -12), LeftElbow = r(95),
		RightShoulder = r(45, -10, 18), RightElbow = r(95), RightHip = r(14), LeftHip = r(-12), RightKnee = r(-15) },
	{ Root = r(0, 10, 0), Waist = r(-12, 45, 12), RightShoulder = r(40, -45, 40), RightElbow = r(100),
		LeftShoulder = r(35, 0, -25), LeftElbow = r(85), RightHip = r(-25, -10, 5), LeftHip = r(24, 0, -5), LeftKnee = r(-25) },
	{ Root = r(-5, -12, 0), Waist = r(-15, -38, -10), LeftShoulder = r(30, 25, -55), LeftElbow = r(80),
		RightShoulder = r(50, -10, 20), RightElbow = r(80), RightHip = r(30), LeftHip = r(-25), RightKnee = r(-35) },
}
local impacts = {
	{ Waist = r(-10, -25, -4), Neck = r(3, 20), RightShoulder = r(98, 5, -9), RightElbow = r(5), RightWrist = r(0, 0, -8),
		LeftShoulder = r(40, 0, -15), LeftElbow = r(95), RightHip = r(18), LeftHip = r(-12), RightKnee = r(-20) },
	{ Waist = r(-10, 28, 4), Neck = r(3, -20), LeftShoulder = r(100, -5, 9), LeftElbow = r(5), LeftWrist = r(0, 0, 8),
		RightShoulder = r(42, 0, 15), RightElbow = r(95), RightHip = r(-12), LeftHip = r(20), LeftKnee = r(-20) },
	{ Root = r(0, -10, 0), Waist = r(-14, -48, -9), Neck = r(5, 20), RightShoulder = r(90, 12, -38), RightElbow = r(45),
		LeftShoulder = r(45, 0, -15), LeftElbow = r(90), RightHip = r(28, 12), LeftHip = r(-25), RightKnee = r(-28) },
	{ Root = r(-8, 12, 0), Waist = r(-18, 48, 5), Neck = r(10, -25), LeftShoulder = r(105, -12, 25), LeftElbow = r(12),
		RightShoulder = r(35, 0, 30), RightElbow = r(80), RightHip = r(-22), LeftHip = r(30), LeftKnee = r(-25) },
}

local function blend(a, b, t)
	local result = {}
	for key, value in a do result[key] = value:Lerp(b[key] or CFrame.identity, t) end
	for key, value in b do if not result[key] then result[key] = CFrame.identity:Lerp(value, t) end end
	return result
end

function Pose.Attack(index, age)
	local definition = Config.Combat.Attacks[index]
	if not definition or age < 0 or age > definition.Recovery then return nil end
	local load = definition.Windup * 0.52
	if age < load then return blend({}, windups[index], math.sin(age / load * math.pi / 2)) end
	if age < definition.Windup then
		return blend(windups[index], impacts[index], ((age - load) / (definition.Windup - load)) ^ 2)
	end
	local hold = definition.Windup + definition.Active * 0.6
	if age < hold then return impacts[index] end
	return blend(impacts[index], {}, math.clamp((age - hold) / (definition.Recovery - hold), 0, 1))
end

function Pose.Locomotion(speed, sprint, airborne, phase, localVelocity)
	local pose = {}
	local sway = math.sin(phase)
	if airborne then
		return { Waist = r(-7), RightShoulder = r(15, 0, 30), LeftShoulder = r(15, 0, -30),
			RightElbow = r(30), LeftElbow = r(30), RightHip = r(15), LeftHip = r(-10), RightKnee = r(-35), LeftKnee = r(-15) }
	end
	if speed < 0.7 then
		pose.Waist = r(math.sin(phase * 0.35) * 1.5)
		pose.RightShoulder = r(3, 0, 5)
		pose.LeftShoulder = r(3, 0, -5)
		pose.RightElbow, pose.LeftElbow = r(10), r(10)
		return pose
	end
	local amplitude = sprint and 51 or 29
	local stride = sway * amplitude * math.clamp(speed / 10, 0, 1)
	local sideLean = math.clamp(localVelocity.X / 27, -1, 1) * -9
	pose.Root = CFrame.new(0, math.abs(math.cos(phase)) * (sprint and 0.09 or 0.035), 0)
	pose.Waist = r(sprint and -16 or -4, sway * 5, sideLean)
	pose.Neck = r(sprint and 10 or 2, -sway * 3)
	pose.RightHip, pose.LeftHip = r(stride), r(-stride)
	pose.RightKnee = r(-math.max(0, -sway) * (sprint and 75 or 48))
	pose.LeftKnee = r(-math.max(0, sway) * (sprint and 75 or 48))
	pose.RightAnkle, pose.LeftAnkle = r(-stride * 0.25), r(stride * 0.25)
	pose.RightShoulder, pose.LeftShoulder = r(-stride * 0.8, 0, 6), r(stride * 0.8, 0, -6)
	pose.RightElbow, pose.LeftElbow = r(sprint and 80 or 20), r(sprint and 80 or 20)
	return pose
end

function Pose.Block()
	return { Waist = r(-8), Neck = r(8), RightShoulder = r(65, -15, -15), LeftShoulder = r(65, 15, 15),
		RightElbow = r(75), LeftElbow = r(75), RightHip = r(-12), LeftHip = r(12), LeftKnee = r(-20) }
end

function Pose.Dash()
	return { Waist = r(-28), Neck = r(20), RightShoulder = r(-30, 0, 15), LeftShoulder = r(-30, 0, -15),
		RightElbow = r(15), LeftElbow = r(15), RightHip = r(45), RightKnee = r(-65), LeftHip = r(-25), LeftKnee = r(-20) }
end

function Pose.Stagger(age)
	local weight = math.max(0, 1 - age / 0.32)
	return { Waist = r(18 * weight, 5 * weight, 4 * weight), Neck = r(-15 * weight),
		RightShoulder = r(-12 * weight, 0, 20 * weight), LeftShoulder = r(-12 * weight, 0, -20 * weight) }
end

function Pose.Brake(weight)
	return { Waist = r(12 * weight), Neck = r(-8 * weight), RightHip = r(22 * weight), LeftHip = r(-15 * weight),
		RightKnee = r(-25 * weight), RightShoulder = r(25 * weight), LeftShoulder = r(25 * weight) }
end

return Pose
