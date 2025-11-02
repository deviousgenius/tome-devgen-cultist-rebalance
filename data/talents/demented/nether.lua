local Talents = require "engine.interface.ActorTalents"
local DamageType = require "engine.DamageType"
local damDesc = Talents.damDesc

local T_NETHERBLAST = Talents.talents_def.T_NETHERBLAST
local T_RIFT_CUTTER = Talents.talents_def.T_RIFT_CUTTER
local T_SPATIAL_DISTORTION = Talents.talents_def.T_SPATIAL_DISTORTION
local T_HALO_OF_RUIN = Talents.talents_def.T_HALO_OF_RUIN


-- Netherblast

T_NETHERBLAST.direct_hit = true
T_NETHERBLAST.requires_target = false

T_NETHERBLAST.getTargetCount = function(self, t) return math.floor( (self:combatTalentScale(t, 1, 5) - 1) / 2) end
T_HALO_OF_RUIN.getTargetCount = function(self, t) return math.floor(self:combatTalentScale(t, 1, 5)) end



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
			tgts[#tgts+1] = {tgt=target, distance=core.fov.distance(self.x, self.y, target.x, target.y)}
		end)

		if #tgts > 0 then table.sort(tgts, function(a, b)
            return a.distance > b.distance 
        end) else return end


        game.logPlayer(self, "#RED#Debug message 2")

        local count = T_HALO_OF_RUIN.getTargetCount(self, T_HALO_OF_RUIN)
        local i = 1

        while count > 0 and i <= #tgts do
            local entry = tgts[i]
            local target = entry.tgt
            if target and target.x and target.y then
                self:project(
                    {type="beam", range=self:getTalentRange(t), talent=t},
                    target.x, target.y,
                    DamageType.VOIDBURN,
                    {dam=dam, dur=5, perc=perc}
                )

                game.level.map:particleEmitter(self.x, self.y, tg.range, "netherlance",
                    {tx = target.x - self.x, ty = target.y - self.y})

                game:playSoundNear(self, "talents/netherlance")
            end
            count = count - 1
            i = i + 1
        end

        self:removeEffect(self.EFF_HALO_OF_RUIN)
    
    else
        local shots = t.getTargetCount(self, t) + 1 -- +1 to account for the base shot
        
        for i = 1, shots do
            local tg = {type="bolt", range=self:getTalentRange(t), talent=t, friendlyblock=false, display={particle="netherblast"}}
            local x, y = self:getTarget(tg)
            if x and y then
                self:projectile(tg, x, y, DamageType.VOID, dam, {type="voidblast"})
                game:playSoundNear(self, "talents/netherblast")
            end
        end
    end

    if self.in_combat then
			self:setEffect(self.EFF_ENTROPIC_WASTING, 8, {src=self, power=t.getBacklash(self, t) / 8})
		end
    return true
        
end

T_NETHERBLAST.info = function(self, t)
		local dam = t.getDamage(self,t)/2
		local backlash = t.getBacklash(self,t)
		return ([[Fire a burst of unstable void energy, dealing %0.2f darkness and %0.2f temporal damage to the target. The power of this spell inflicts entropic backlash on you, causing you to take %d damage over 8 turns. This damage counts as entropy for the purpose of Entropic Gift.
        
You fire an additional shot at talent level 3, and another at talent level 5.
        
The damage will increase with your Spellpower.]]):
		tformat(damDesc(self, DamageType.DARKNESS, dam), damDesc(self, DamageType.TEMPORAL, dam), backlash)
end

-- Rift Cutter

T_RIFT_CUTTER.getPin = function(self, t) return math.floor(self:combatTalentLimit(t, 10, 2, 8)) end

T_RIFT_CUTTER.action = function(self, t)
    local tg = self:getTalentTarget(t)
    local x, y = self:getTarget(tg)
    if not x or not y then return nil end
    local dam = self:spellCrit(t.getDamage(self, t))
    local edam = 0
    local pin = t.getPin(self, t)
    local rad = 1
    local eff = self:hasEffect(self.EFF_HALO_OF_RUIN)
    if eff and eff.charges==5 then
        self.turn_procs.halo_of_ruin = true
        edam = self:spellCrit(self:callTalent(self.T_HALO_OF_RUIN, "getRiftDamage"))
        rad = rad + self:callTalent(self.T_HALO_OF_RUIN, "getRiftRadius")
        self:removeEffect(self.EFF_HALO_OF_RUIN)
    end
    local grids = self:project(tg, x, y, DamageType.DARKNESS, dam)
    local _ _, x, y = self:canProject(tg, x, y)
    game.level.map:particleEmitter(self.x, self.y, math.max(math.abs(x-self.x), math.abs(y-self.y)), "shadow_beam", {tx=x-self.x, ty=y-self.y})

    game.level.map:addEffect(self, self.x, self.y, 4,
        engine.DamageType.RIFT,
        {
            dam = dam, edam = edam,
            pin = pin,
            radius = 1, self = self, talent = t
        },
        0, 5, grids,
        MapEffect.new{
            zdepth=6,
            color_br=12, color_bg=12, color_bb=12,
            effect_shader="shader_images/unstable_rift_ground.png"
        },
        function(e, update_shape_only)
            if not update_shape_only and e.duration == 1 then
                local DamageType = require("engine.DamageType") --block_path means that it will always hit the tile we've targeted here

                for px, ys in pairs(e.grids) do for py, _ in pairs(ys) do
                    local aoe = {type="ball", radius = rad, friendlyfire=false, talent=e.dam.talent, block_path = function(self, t) return false, true, true end}
                    e.src:projectSource(aoe, px, py, DamageType.RIFT_EXPLOSION, e.dam.dam, nil, e.dam.talent)
                    game.level.map:particleEmitter(px, py, 1, "unstable_rift_explosion", {id=1, radius=rad})
                    game.level.map:particleEmitter(px, py, 1, "unstable_rift_explosion", {id=2, radius=rad})
                    game.level.map:particleEmitter(px, py, 1, "unstable_rift_explosion", {id=3, radius=rad})
                    game.level.map:particleEmitter(px, py, 1, "unstable_rift_explosion", {id=4, radius=rad})
                end end
                e.duration = 0

                game:playSoundNear(self, "talents/fireflash")
                --I'll let map remove it
            end						
        end
    )
    if self.in_combat then
        self:setEffect(self.EFF_ENTROPIC_WASTING, 8, {src=self, power=t.getBacklash(self, t) / 8})
    end
    game:playSoundNear(self, "talents/slime")
    return true
end

T_RIFT_CUTTER.info = function(self, t)
		return ([[Fire a beam of energy that rakes across the ground, dealing %0.2f darkness damage to enemies within and leaving behind an unstable rift. After 3 turns the rift detonates, dealing %0.2f temporal damage to adjacent enemies.
		Targets cannot be struck by more than a single rift explosion at once. Those in the rift will be pinned for %d turns.
		The power of this spell inflicts entropic backlash on you, causing you to take %d damage over 8 turns. This damage counts as entropy for the purpose of Entropic Gift.
		The damage will increase with your Spellpower.]]):
		tformat(damDesc(self, DamageType.DARKNESS, t.getDamage(self,t)), damDesc(self, DamageType.TEMPORAL, t.getDamage(self,t)), t.getPin(self, t), t.getBacklash(self, t))
	end


-- Halo of Ruin

-- Idea: Double crit chance per spark? So at 5 sparks you get 20% crit chance?

T_HALO_OF_RUIN.info = function(self, t)
		return ([[Each time you cast a non-instant Demented spell, a nether spark begins orbiting around you for 10 turns, to a maximum of 5. Each spark increases your critical strike chance by %d%%, and on reaching 5 sparks your next Nether spell will consume all sparks to empower itself:
#PURPLE#Netherblast:#LAST# Release a burst of void energy, piercing through %d random enemies (Prioritizing furthermost ones) and dealing an additional %d%% damage over 5 turns.
#PURPLE#Rift Cutter:#LAST# Those in the rift will be pinned for %d turns, take %0.2f temporal damage each turn, and the rift explosion has %d increased radius.
#PURPLE#Spatial Distortion:#LAST# An Entropic Maw will be summoned at the rift's exit for %d turns, pulling in and taunting nearby targets with it's tendrils.
The damage will increase with your Spellpower.  Entropic Maw stats will increase with level and your Magic stat.]]):
		tformat(t.getCrit(self,t), t.getTargetCount(self,t), t.getSpikeDamage(self,t)*100, t.getPin(self, t), damDesc(self, DamageType.TEMPORAL, t.getRiftDamage(self,t)), t.getRiftRadius(self,t), t.getSpatialDuration(self,t))
end