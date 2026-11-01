--!nonstrict
local Rules = require(game:GetService("ReplicatedStorage").BlackClover.Shared.MagicRules)
local World = require(script.Parent.MagicWorld)
local Clash = {}
function Clash:Step(projectiles)
	local list = {}
	for _, p in projectiles.Items do table.insert(list, p) end
	for i = 1, #list do
		local a = list[i]
		if a.Removed then continue end
		for j = i + 1, #list do
			local b = list[j]
			if a.Removed or b.Removed or a.Owner == b.Owner then continue end
			local r = a.Previous - b.Previous
			local v = (a.Next - a.Previous) - (b.Next - b.Previous)
			local collided, t = Rules.sweptHit(r.X, r.Y, r.Z, v.X, v.Y, v.Z, a.Radius + b.Radius)
			if not collided then continue end
			local point = a.Previous:Lerp(a.Next, t)
			local outcome, remaining = Rules.clash(a.Power, b.Power, a.Element, b.Element)
			World:Pulse("Clash", point, outcome == "Equal" and "Stars" or (outcome == "A" and a.Element or b.Element), math.clamp((a.Power + b.Power) / 12, 5, 24))
			if outcome == "Equal" then projectiles:Remove(a); projectiles:Remove(b)
			else
				local winner, loser = outcome == "A" and a or b, outcome == "A" and b or a
				winner.Multiplier *= math.clamp(remaining / math.max(1, winner.Power), .3, .85)
				winner.Power = remaining
				if winner.Element == "Water" and loser.Element == "Ice" then
					winner.Speed *= .7
					winner.Root:SetAttribute("Frosted", true)
				end
				if loser.Element == "Wind" and winner.Element == "Water" then
					local shifted = winner.Direction + loser.Direction * .45
					if shifted.Magnitude > .01 then winner.Direction = shifted.Unit end
				end
				projectiles:Remove(loser)
			end
		end
	end
end
return Clash
