local Talents = require "engine.interface.ActorTalents"
local DamageType = require "engine.DamageType"
local damDesc = Talents.damDesc

T_PROPHECY_OF_RUIN = Talents.talents_def.T_PROPHECY_OF_RUIN
T_PROPHECY_OF_MADNESS = Talents.talents_def.T_PROPHECY_OF_MADNESS
T_PROPHECY_OF_TREASON = Talents.talents_def.T_PROPHECY_OF_TREASON

T_PROPHECY_OF_RUIN.no_energy = true
T_PROPHECY_OF_MADNESS.no_energy = true
T_PROPHECY_OF_TREASON.no_energy = true

-- Store original actions to wrap them later!
local original_ruin_action = T_PROPHECY_OF_RUIN.action
local original_madness_action = T_PROPHECY_OF_MADNESS.action
local original_treason_action = T_PROPHECY_OF_TREASON.action

local function setCooldownOnOtherProphecies(self, used_talent_id)
	local prophecies = {self.T_PROPHECY_OF_RUIN, self.T_PROPHECY_OF_MADNESS, self.T_PROPHECY_OF_TREASON}
	for _, tid in ipairs(prophecies) do
		if tid ~= used_talent_id then
			if not self.talents_cd[tid] or self.talents_cd[tid] <= 0 then
				self.talents_cd[tid] = 1
			end
		end
	end
end

-- Prophecy of Ruin

T_PROPHECY_OF_RUIN.action = function(self, t)
	local result = original_ruin_action(self, t)
	setCooldownOnOtherProphecies(self, self.T_PROPHECY_OF_RUIN)

	return result
end

-- Prophecy of Madness

T_PROPHECY_OF_MADNESS.action = function(self, t)
	local result = original_madness_action(self, t)
	setCooldownOnOtherProphecies(self, self.T_PROPHECY_OF_MADNESS)
	
	return result
end

-- Prophecy of Treason

T_PROPHECY_OF_TREASON.action = function(self, t)
	local result = original_treason_action(self, t)
	setCooldownOnOtherProphecies(self, self.T_PROPHECY_OF_TREASON)

	return result
end