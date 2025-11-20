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
    
    local eff = self:hasEffect(self.EFF_HALO_OF_RUIN)

    if eff and eff.charges == 5 then

        local tg = self:getTalentTarget(t)
        local dam = self:spellCrit(t.getDamage(self,t))
        local eff = self:hasEffect(self.EFF_HALO_OF_RUIN)
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
        local shots

        if self:getTalentLevel(t) >= 5 then
            shots = 2
        else
            shots = 1
        end
        
        for i = 1, shots do
            local tg = {type="bolt", range=self:getTalentRange(t), talent=t, friendlyblock=false, display={particle="netherblast"}}
            local x, y = self:getTarget(tg)

            if i == 1 and (not x or not y) then return nil end

            local tg = self:getTalentTarget(t)
            local dam = self:spellCrit(t.getDamage(self,t))
            
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
        
You fire an additional shot at talent level 5.
        
The damage will increase with your Spellpower.]]):
		tformat(damDesc(self, DamageType.DARKNESS, dam), damDesc(self, DamageType.TEMPORAL, dam), backlash)
end

-- Rift Cutter

T_RIFT_CUTTER.getPin = function(self, t) return math.floor(self:combatTalentLimit(t, 10, 2, 8)) end

T_RIFT_CUTTER.action = function(self, t)
    
    local dam = self:spellCrit(t.getDamage(self, t))
    local edam = 0
    local pin = t.getPin(self, t)
    local rad = 1
    local eff = self:hasEffect(self.EFF_HALO_OF_RUIN)

    -- number of shots: 2 if halo active (charges == 5), otherwise 1
    local shots = 1
    if eff and eff.charges == 5 then
        shots = 2
        self.turn_procs.halo_of_ruin = true
        edam = self:spellCrit(self:callTalent(self.T_HALO_OF_RUIN, "getRiftDamage"))
        rad = rad + self:callTalent(self.T_HALO_OF_RUIN, "getRiftRadius")
        self:removeEffect(self.EFF_HALO_OF_RUIN)
    end

    for i = 1, shots do
        local tg = self:getTalentTarget(t)
        local x, y = self:getTarget(tg)
        if not x or not y then return nil end
        local grids = self:project(tg, x, y, DamageType.DARKNESS, dam)

        for gx, ys in pairs(grids) do
            for gy, _ in pairs(ys) do
                local target = game.level.map(gx, gy, engine.Map.ACTOR)
                if target then
                    if target:hasEffect(target.EFF_PINNED) and target:canBe("silence") then
                    target:setEffect(target.EFF_SILENCED, pin, {
                        apply_power = self:combatSpellpower()
                    })
                    end

                    if target:hasEffect(target.EFF_BLINDED) and target:canBe("stun") then
                    target:setEffect(target.EFF_STUNNED, pin, {
                        apply_power = self:combatSpellpower()
                    })
                    end

                    if target:hasEffect(target.EFF_CONFUSED) and target:canBe("disarm") then
                    target:setEffect(target.EFF_DISARMED, pin, {
                        apply_power = self:combatSpellpower()
                    })
                    end

                    -- Apply pin first
                    target:setEffect(target.EFF_PINNED, pin, {power=pin_power, src=self, talent=t})
                    
                end
            end
        end

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
    end

    if self.in_combat then
        self:setEffect(self.EFF_ENTROPIC_WASTING, 8, {src=self, power=t.getBacklash(self, t) / 8})
    end
    game:playSoundNear(self, "talents/slime")
    return true
end


T_RIFT_CUTTER.info = function(self, t)
		return ([[Fire a beam of energy that rakes across the ground, dealing %0.2f darkness damage to enemies within and leaving behind an unstable rift. After 3 turns the rift detonates, dealing %0.2f temporal damage to adjacent enemies.
		Targets cannot be struck by more than a single instance of a rift explosion at once (Still works if you cast multiple).
        Those in the rift will be pinned.
        If the target is pinned, they will be silenced.
        If the target is blinded, they will be stunned.
        If the target is confused, they will be disarmed.
        All effects will be applied for %d turns.
		The power of this spell inflicts entropic backlash on you, causing you to take %d damage over 8 turns. This damage counts as entropy for the purpose of Entropic Gift.
		The damage will increase with your Spellpower.]]):
		tformat(damDesc(self, DamageType.DARKNESS, t.getDamage(self,t)), damDesc(self, DamageType.TEMPORAL, t.getDamage(self,t)), t.getPin(self, t), t.getBacklash(self, t))
	end

-- Spatial Distortion

T_SPATIAL_DISTORTION.getSpatialDuration = function(self, t) return math.ceil(self:combatTalentScale(t, 3.5, 5.5)) end

T_SPATIAL_DISTORTION.action = function(self, t)
    local tg = self:getTalentTarget(t)
    local x, y = self:getTarget(tg)
    if not x or not y then return nil end
    local _ _, _, _, x, y = self:canProject(tg, x, y)
    
    game.logPlayer(self, "Select a teleport location...")
    local tg2 = {type="ball", nolock=true, nowarning=true, range=self:getTalentRange(t), radius=self:getTalentRadius(t)}
    x2, y2 = self:getTarget(tg2)
    if not x2 then return nil end
    _, _, _, x2, y2 = self:canProject(tg, x2, y2)
    local sdur = t.getSpatialDuration(self, t)
    local eff = self:hasEffect(self.EFF_HALO_OF_RUIN)
    
    local dam = self:spellCrit(t.getDamage(self, t))
    self:project(tg, x, y, function(px, py)
        local target = game.level.map(px, py, Map.ACTOR)
        if not target then return end
        game.level.map:particleEmitter(target.x, target.y, 1, "nether_teleport_in", {id=1, radius=tg.radius})
        game.level.map:particleEmitter(target.x, target.y, 1, "nether_teleport_in", {id=2, radius=tg.radius})
        game.level.map:particleEmitter(target.x, target.y, 1, "nether_teleport_in", {id=3, radius=tg.radius})
        game.level.map:particleEmitter(target.x, target.y, 1, "nether_teleport_in", {id=4, radius=tg.radius})
        game.level.map:particleEmitter(target.x, target.y, 1, "nether_teleport_in", {id=5, radius=tg.radius})


        if (self:checkHit(self:combatSpellpower(), target:combatSpellResist() + (target:attr("continuum_destabilization") or 0))) or self:reactionToward(target) >= 0 and target:canBe("teleport") then
            if not target:teleportRandom(x2, y2, 1) then
                game.logSeen(target, "The spell fizzles on %s!", target:getName():capitalize())
            else
                if self:reactionToward(target) < 0 then	target:setEffect(target.EFF_CONTINUUM_DESTABILIZATION, 100, {power=self:combatSpellpower(0.3)}) end
                game.level.map:particleEmitter(target.x, target.y, 1, "nether_teleport_out", {id=1, radius=tg.radius})
                game.level.map:particleEmitter(target.x, target.y, 1, "nether_teleport_out", {id=2, radius=tg.radius})
                game.level.map:particleEmitter(target.x, target.y, 1, "nether_teleport_out", {id=3, radius=tg.radius})
                game.level.map:particleEmitter(target.x, target.y, 1, "nether_teleport_out", {id=4, radius=tg.radius})
                game.level.map:particleEmitter(target.x, target.y, 1, "nether_teleport_out", {id=5, radius=tg.radius})
                
                game.logSeen(target, "#CRIMSON#%s is swallowed by a portal!", target:getName():capitalize())
            end
        else
            game.logSeen(target, "%s resists the warp!", target:getName():capitalize())
        end
        if self:reactionToward(target) < 0 and not target.spatial_distortion then --sanity check
            target.spatial_distortion = true
            DamageType:get(DamageType.VOID).projector(self, target.x, target.y, DamageType.VOID, dam)
        end
    end)
    local x3, y3 = util.findFreeGrid(x2, y2, 3, true, {[Map.ACTOR]=true})

    local NPC = require "mod.class.NPC"
    local m

    if eff and eff.charges==5 then		
        self.turn_procs.halo_of_ruin = true
        self:removeEffect(self.EFF_HALO_OF_RUIN)

        m = NPC.new{
			type = "horror", subtype = "corrupted",
			name = _t"hungering mouth",
			display = "h", color=colors.GREEN, blood_color = colors.GREEN,
			desc = _t[["From below, it devours."]],
			body = { INVEN = 10 },
			faction = self.faction,
			image="npc/hungering_mouth.png",
			level_range = {self.level, self.level}, exp_worth = 0,
			max_life = self:callTalent(self.T_HALO_OF_RUIN, "getLife"), life_rating = 20, fixed_rating = true,
			rank = 3,
			size_category = 3,
			infravision = 10,
			never_move = 1,
			immune_possession = 1,
			no_auto_resists = true,

			resists = {all = math.min(50, self.level)},
			combat_armor = self.level,
			combat_armor_hardiness = 60,
			combat = {dam=1},

			resolvers.talents{
				[self.T_DREM_CALL_OF_AMAKTHEL]=1,
                [Talents.T_TAUNT]=1
			},

			autolevel = "warriormage",
			ai = "summoned", ai_real = "dumb_talented", ai_state = { talent_in=1, },
			summoner = self, summoner_gain_exp=true,
			summon_time = self:callTalent(self.T_HALO_OF_RUIN, "getTime")
		}
    else
        m = NPC.new{
            type = "horror", subtype = "eldritch",
            display = "h", blood_color = colors.BLUE,
            faction = self.faction,
            stats = { str=self:getMag(), dex=self:getMag(), mag=self:getMag(), con=self:getMag(), wil=self:getMag(), cun=self:getMag() },
            infravision = 10,
            no_breath = 1,
            fear_immune = 1,
            knockback_immune = 1,
            never_move = 1,
            name = _t"entropic maw", color=colors.GREY,
            desc = _t"Tendrils lash around the mouth of this gigantic beast, seeking prey to devour.",
            image="npc/entropic_fiend.png",
            level_range = {self.level, self.level}, exp_worth = 0,
            rank = 2,
            size_category = 3,
            autolevel = "warrior",
            life_rating = 20,
            life_regen = 4,
            combat_armor = 16, combat_def = 1,
            combat = { dam=10 + self.level*1.5, damtype=DamageType.VOID, atk=10 + self.level*1.5, apr=25, dammod={str=1.2}, physcrit = 10 },
    
            resists = {all = 30, [DamageType.DARKNESS] = 100, [DamageType.TEMPORAL] = 100},
    
            resolvers.talents{
                [Talents.T_GRASPING_TENDRILS] = 1,								
            },
            resolvers.sustains_at_birth(),
    
            ai = "summoned", ai_real = "tactical", ai_state = { ai_move="move_complex", talent_in=1, ally_compassion=0 },
            no_drops = true,
            faction = self.faction,
            summoner = self, summoner_gain_exp=true,
            summon_time = t.getSpatialDuration(self, t),
        }
    end	
    
    
    if sdur > 0 and x3 then
        -- local NPC = require "mod.class.NPC"

        m:resolve()
        m:resolve(nil, true)		

        game.zone:addEntity(game.level, m, "actor", x3, y3)

        if m.name == _t"hungering mouth" then
            m:forceUseTalent(m.T_TAUNT, {ignore_cd=true, no_talent_fail = true})
        end

    end
    if self.in_combat then
        self:setEffect(self.EFF_ENTROPIC_WASTING, 8, {src=self, power=t.getBacklash(self, t) / 8})
    end
    game:playSoundNear(self, "talents/terminus")

    return true
end

T_SPATIAL_DISTORTION.info = function(self, t)
		local dam = t.getDamage(self,t)/2
		local backlash = t.getBacklash(self,t)
		local dur = t.getSpatialDuration(self,t)
		local rad = self:getTalentRadius(t)
		return ([[Briefly open a radius %d rift in spacetime that teleports those within to the targeted location.
An Entropic Maw will be summoned at the rift's exit for %d turns, pulling in and taunting nearby targets with its tendrils. 
Enemies will take %0.2f darkness and %0.2f temporal damage.
The power of this spell inflicts entropic backlash on you, causing you to take %d damage over 8 turns. This damage counts as entropy for the purpose of Entropic Gift.
The damage will improve with your Spellpower.]]):tformat(rad, dur, damDesc(self, DamageType.DARKNESS, dam), damDesc(self, DamageType.TEMPORAL, dam), backlash)
	end
-- Halo of Ruin

-- Idea: Double crit chance per spark? So at 5 sparks you get 20% crit chance?

T_HALO_OF_RUIN.getTargetCount = function(self, t) 
    local targetCount
    if self:getTalentLevel(self.T_NETHERBLAST) >= 5 then
        targetCount = math.floor(self:combatTalentScale(t, 1, 5)) + 1 -- Extra target at level 5
    else
        targetCount = math.floor(self:combatTalentScale(t, 1, 5))
    end
    return targetCount
end

T_HALO_OF_RUIN.getLife = function(self, t) return self:combatStatScale("con", 70, 800) * (1 + self:getTalentLevel(t) / 5) end
T_HALO_OF_RUIN.getTime = function(self, t) return 4 + math.floor(self:getTalentLevel(t)) end


T_HALO_OF_RUIN.info = function(self, t)
		return ([[Each time you cast a non-instant Demented spell, a nether spark begins orbiting around you for 10 turns, to a maximum of 5. Each spark increases your critical strike chance by %d%%, and on reaching 5 sparks your next Nether spell will consume all sparks to empower itself:
#PURPLE#Netherblast:#LAST# Release a burst of void energy, piercing through %d random enemies (Prioritizing furthermost ones) and dealing an additional %d%% damage over 5 turns. An additional projectile is fired at Netherblast talent level 5.
#PURPLE#Rift Cutter:#LAST# This talent is cast an additional time. Those in the rift will take %0.2f temporal damage each turn, and the rift explosion has %d increased radius. The mouth can draw all enemies in radius 10 for 2 spaces towards itself or taunt nearby enemies with its tendrils.
#PURPLE#Spatial Distortion:#LAST# The Entropic Maw will be replaced with the more powerful hungering mouth that scales with your level and lasts for %d turns.
The damage will increase with your Spellpower.  Entropic Maw stats will increase with level and your Magic stat.]]):
		tformat(t.getCrit(self,t), t.getTargetCount(self,t), t.getSpikeDamage(self,t)*100, damDesc(self, DamageType.TEMPORAL, t.getRiftDamage(self,t)), t.getRiftRadius(self,t), t.getTime(self, t))
end