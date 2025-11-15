local Talents = require "engine.interface.ActorTalents"
local DamageType = require "engine.DamageType"
local damDesc = Talents.damDesc

T_ACCELERATE = Talents.talents_def.T_ACCELERATE
T_SWITCH = Talents.talents_def.T_SWITCH

-- Accelerate

T_ACCELERATE.getPassiveSpeed = function(self, t) return self:combatTalentScale(t, 0.08, 0.4, 0.7) end
T_ACCELERATE.passives = function(self, t, p)
		self:talentTemporaryValue(p, "movement_speed", t.getPassiveSpeed(self, t))
end

T_ACCELERATE.getSpeed = function(self, t) return self:combatTalentScale(t, 100, 500) end

T_ACCELERATE.info = function(self, t)
		local radius = self:getTalentRadius(t)
		local dur = t.getDuration(self, t)
		local speed = t.getSpeed(self, t)
        local passiveSpeed = t.getPassiveSpeed(self, t)
		return ([[Distorting spacetime around yourself, you reduce the movement speed of all enemies in radius %d by 50%% for %d turns.
You use the siphoned speed to grant yourself incredible quickness for 1 turn, increasing movement speed by %d%%, increased by a further %d%% for each enemy slowed, to a maximum of 4.
Any actions other than movement will cancel the effect.

Additionally, your passive movement speed is increased by %d%%.]]):
		tformat(radius, dur, speed, speed/8, passiveSpeed*100)
	end

-- Switch

T_SWITCH.no_energy = true