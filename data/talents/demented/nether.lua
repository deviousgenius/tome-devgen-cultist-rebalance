local Talents = require "engine.interface.ActorTalents"
local DamageType = require "engine.DamageType"
local damDesc = Talents.damDesc

-- Netherblast

local T_NETHERBLAST = Talents.talents_def.T_NETHERBLAST
local T_HALO_OF_RUIN = Talents.talents_def.T_HALO_OF_RUIN

T_NETHERBLAST.direct_hit = true
T_NETHERBLAST.requires_target = false
T_HALO_OF_RUIN.getTargetCount = function(self, t) return math.floor(self:combatTalentScale(t, 1, 5)) end

T_NETHERBLAST.requires_target = function(self, t)
    local eff = self:hasEffect(self.EFF_HALO_OF_RUIN)
    if eff and eff.charges == 5 then
        return false  -- No targeting needed when Halo is at 5 charges
    else
        return true   -- Normal targeting required
    end
end

T_NETHERBLAST.target = function(self, t)
    local eff = self:hasEffect(self.EFF_HALO_OF_RUIN)
    if eff and eff.charges==5 then
        --return {type="beam", range=self:getTalentRange(t), friendlyfire=false, talent=t}
        return {type="ball", range=0, talent=t, selffire = false, friendlyfire=false, radius=self:getTalentRange(t), display_line_step=false, display={particle="netherblast"}}
    else
        local ff = false
        if game.zone.short_name == "cults+ft-cultist" then ff = true end  -- This zone needs NB to be FF and making an entirely separate talent seems silly
        return {type="bolt", range=self:getTalentRange(t), talent=t, friendlyblock = ff, display={particle="netherblast"}}
        
    end
end

T_NETHERBLAST.action = function(self, t)
    local tg = self:getTalentTarget(t)
    local dam = self:spellCrit(t.getDamage(self,t))
    local eff = self:hasEffect(self.EFF_HALO_OF_RUIN)
    
    if eff and eff.charges == 5 then
        game.logPlayer(self, "#RED#Halo of Ruin unleashes its full power!")

        self.turn_procs.halo_of_ruin = true
		local perc = self:callTalent(self.T_HALO_OF_RUIN, "getSpikeDamage")

        local tgts = {}
		self:project(tg, self.x, self.y, function(px, py)
			local target = game.level.map(px, py, engine.Map.ACTOR)
			if not target then return end
			tgts[#tgts+1] = target
		end)
        

		if #tgts <= 0 then return true end

        game.logPlayer(self, "#RED#Debug message 2")

        local count = T_HALO_OF_RUIN.getTargetCount(self, T_HALO_OF_RUIN)
        while count > 0 and #tgts > 0 do
            game.logPlayer(self, "#RED#Top of while loop")
            local tgt, id = rng.table(tgts)

            self:project(
                {type="beam", range=self:getTalentRange(t), talent=t}, 
                tgt.x, tgt.y, 
                DamageType.VOIDBURN, 
                {dam=dam, dur=5, perc=perc}
            )

            game.level.map:particleEmitter(self.x, self.y,tg.range, "netherlance", {tx=tgt.x - self.x, ty=tgt.y - self.y})
            game:playSoundNear(self, "talents/netherlance")
            count = count - 1
            table.remove(tgts, id)
        end

        self:removeEffect(self.EFF_HALO_OF_RUIN)
    
    else
        local x, y = self:getTarget(tg)
        if not x or not y then return nil end
        self:projectile(tg, x, y, DamageType.VOID, dam, {type="voidblast"})
        game:playSoundNear(self, "talents/netherblast")    
    end

    if self.in_combat then
			self:setEffect(self.EFF_ENTROPIC_WASTING, 8, {src=self, power=t.getBacklash(self, t) / 8})
		end
    return true
        
end

T_HALO_OF_RUIN.info = function(self, t)
		return ([[Each time you cast a non-instant Demented spell, a nether spark begins orbiting around you for 10 turns, to a maximum of 5. Each spark increases your critical strike chance by %d%%, and on reaching 5 sparks your next Nether spell will consume all sparks to empower itself:
#PURPLE#Netherblast:#LAST# Becomes a deadly lance of void energy, piercing through %d random enemies and dealing an additional %d%% damage over 5 turns.
#PURPLE#Rift Cutter:#LAST# Those in the rift will be pinned for %d turns, take %0.2f temporal damage each turn, and the rift explosion has %d increased radius.
#PURPLE#Spatial Distortion:#LAST# An Entropic Maw will be summoned at the rift's exit for %d turns, pulling in and taunting nearby targets with it's tendrils.
The damage will increase with your Spellpower.  Entropic Maw stats will increase with level and your Magic stat.]]):
		tformat(t.getCrit(self,t), t.getTargetCount(self,t), t.getSpikeDamage(self,t)*100, t.getPin(self, t), damDesc(self, DamageType.TEMPORAL, t.getRiftDamage(self,t)), t.getRiftRadius(self,t), t.getSpatialDuration(self,t))
end