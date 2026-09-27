-- Level curve, point budgets and rewards.

local Levels = {}

Levels.MaxLevel = 100
Levels.StatPointsPerLevel = 3

local TITLES = {
	{ 1, "Recruit" },
	{ 5, "Brawler" },
	{ 10, "Gladiator" },
	{ 20, "Champion" },
	{ 35, "Warlord" },
	{ 50, "Ascendant" },
	{ 75, "Mythbreaker" },
	{ 100, "Eternal" },
}

-- XP needed to go from `level` to `level + 1`.
function Levels.XPToNext(level)
	return math.floor(100 * level ^ 1.35)
end

-- Total attribute points a character has earned by `level`.
function Levels.StatPoints(level)
	return (level - 1) * Levels.StatPointsPerLevel
end

-- Total skill points earned by `level`: one per level, plus a bonus every 5 levels.
function Levels.SkillPoints(level)
	return (level - 1) + math.floor(level / 5)
end

-- Coins granted on reaching `level`.
function Levels.LevelReward(level)
	return 50 + level * 25
end

-- Resetting points is free while learning, then costs coins.
function Levels.RespecCost(level)
	return level < 10 and 0 or level * 100
end

function Levels.ClassChangeCost(level)
	return level < 5 and 0 or level * 150
end

function Levels.Title(level)
	local title = TITLES[1][2]
	for _, entry in TITLES do
		if level >= entry[1] then
			title = entry[2]
		end
	end
	return title
end

-- Rewards for knocking out another player.
function Levels.KillReward(victimLevel, victimStreak)
	local xp = 60 + victimLevel * 6
	local coins = 30 + victimLevel * 4
	if victimStreak >= 3 then
		-- Bounty for ending someone's streak.
		coins += victimStreak * 20
	end
	return xp, coins
end

return Levels
