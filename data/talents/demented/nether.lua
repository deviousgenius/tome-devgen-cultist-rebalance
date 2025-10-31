local Talents = require "engine.interface.ActorTalents"

t_netherblast = Talents.talents_def.T_NETHERBLAST

t_netherblast.target = function(self, t)
    local eff = self:hasEffect(self.EFF_HALO_OF_RUIN)
    if eff and eff.charges==5 then
        --return {type="beam", range=self:getTalentRange(t), friendlyfire=false, talent=t}
        return {type="cone", cone_angle = 75, range=0, talent=t, stop_block = true, friendlyfire=true, radius=self:getTalentRange(t), display_line_step=false, display={particle="netherblast"}}
    else
        local ff = false
        if game.zone.short_name == "cults+ft-cultist" then ff = true end  -- This zone needs NB to be FF and making an entirely separate talent seems silly
        return {type="bolt", range=self:getTalentRange(t), talent=t, friendlyblock = ff, display={particle="netherblast"}}
        
    end
end

t_netherblast.action = function(self, t)
    local tg = self:getTalentTarget(t)
    local x, y = self:getTarget(tg)
    if not x or not y then return nil end

    local dam = self:spellCrit(t.getDamage(self,t))
    local eff = self:hasEffect(self.EFF_HALO_OF_RUIN)
    
    if eff and eff.charges == 5 then

        local tgts = {}
		self:project(tg, x, y, function(px, py)
			local target = game.level.map(px, py, engine.Map.ACTOR)
			if not target then return end
			tgts[#tgts+1] = target
		end)

        local tgt_cnt = #tgts
        if tgt_cnt > 0 then
            local count = tgt_cnt
            while count > 0 and #tgts > 0 do
                local tgt, id = rng.table(tgts)
                if tgt then
                    self:projectile(
                        {type="bolt", range=self:getTalentRange(t), talent=t, display={particle="netherblast"}},
                        tgt.x, tgt.y,
                        DamageType.VOID,
                        dam,
                        {type="voidblast"}
                    )
                    count = count - 1
                    table.remove(tgts, id)
                end
            end
        end
    
    else
        self:projectile(tg, x, y, DamageType.VOID, dam, {type="voidblast"})
        game:playSoundNear(self, "talents/netherblast")    
    end

    if self.in_combat then
			self:setEffect(self.EFF_ENTROPIC_WASTING, 8, {src=self, power=t.getBacklash(self, t) / 8})
		end
    return true
        
end
