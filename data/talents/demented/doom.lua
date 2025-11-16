local Talents = require "engine.interface.ActorTalents"
local DamageType = require "engine.DamageType"
local damDesc = Talents.damDesc

T_PROPHECY_OF_RUIN = Talents.talents_def.T_PROPHECY_OF_RUIN
T_PROPHECY_OF_MADNESS = Talents.talents_def.T_PROPHECY_OF_MADNESS
T_PROPHECY_OF_TREASON = Talents.talents_def.T_PROPHECY_OF_TREASON

T_PROPHECY_OF_RUIN.no_energy = true
T_PROPHECY_OF_MADNESS.no_energy = true
T_PROPHECY_OF_TREASON.no_energy = true