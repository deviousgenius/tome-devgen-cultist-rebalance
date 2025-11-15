local Talents = require "engine.interface.ActorTalents"
local DamageType = require "engine.DamageType"
local damDesc = Talents.damDesc

T_NULLMAIL = Talents.talents_def.T_NULLMAIL

T_NULLMAIL.getStunImmune = function(self, t) return math.min(1, self:combatTalentScale(t, 0.05, 0.45, 0.5)) end
T_NULLMAIL.getArmorHardiness = function(self, t)
	return math.max(0, self:combatLimit(self:getTalentLevel(t) * 4, 100, 5.5, 3.75, 47, 37.5))
end

T_NULLMAIL.passives = function(self, t, p)
	self:talentTemporaryValue(p, "combat_armor", t.getArmor(self, t))
    self:talentTemporaryValue(p, "stun_immune", t.getStunImmune(self, t))
    self:talentTemporaryValue(p, "combat_armor_hardiness", t.getArmorHardiness(self, t))
end

T_NULLMAIL.info = function(self, t)
		local armor = t.getArmor(self, t)
		local power = self:getShieldAmount(t.getAbsorb(self, t))
        local hardiness = t.getArmorHardiness(self, t)
        local stunImmunity = t.getStunImmune(self, t)*100
		return ([[Reinforce your armor with countless tiny void stars, increasing armor by %d and armor hardiness by %d%%. Additionally, you gain %d%% stun immunity.
Each time your void stars are fully depleted, you gain a shield absorbing the next %d damage taken within %d turns. This shield cannot trigger again until your void stars are fully restored.]]):
		tformat(armor, hardiness, stunImmunity, power, self:getShieldDuration(4))
	end