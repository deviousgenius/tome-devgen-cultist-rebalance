local Talents = require "engine.interface.ActorTalents"
local damDesc = Talents.damDesc
local Object = require "mod.class.Object"


T_ENTROPIC_GIFT = Talents.talents_def.T_ENTROPIC_GIFT
T_BLACK_HOLE = Talents.talents_def.T_BLACK_HOLE

-- Entropic Gift

T_ENTROPIC_GIFT.getBlindDuration = function(self, t) return  4 end

T_ENTROPIC_GIFT.action = function(self, t)
    local tg = self:getTalentTarget(t)
    local x, y = self:getTarget(tg)
    if not x or not y then return nil end
    local _ _, x, y = self:canProject(tg, x, y)
    local target = game.level.map(x, y, Map.ACTOR)
    if not target then return end

    if target:canBe("blind") then
        target:setEffect(target.EFF_BLINDED, t.getBlindDuration(self, t), {
            apply_power = self:combatSpellpower()
        })
    end
    
    local eff = self:hasEffect(self.EFF_ENTROPIC_WASTING)
    local edam = 0
    if eff then edam = eff.power * eff.dur end
    
    local damage = self:spellCrit( (edam * t.getPower(self,t)/100) )
    local res = 0
    local p = self:isTalentActive(self.T_POWER_OVERWHELMING)
    if p then
        res = p.dambonus	
    end
    self:project(tg, x, y, function(px, py)
        target:setEffect(target.EFF_ENTROPIC_GIFT, 4, {src=self, power=damage/4})
        self:removeEffect(self.EFF_ENTROPIC_WASTING)

        if self:knowTalent(self.T_BLACK_HOLE) then
            local dam = self:callTalent(self.T_BLACK_HOLE, "getDamage")
            local dur = self:callTalent(self.T_BLACK_HOLE, "getDuration")
            local mult = self:callTalent(self.T_BLACK_HOLE, "getEntropyBonus")
            local rad = 1
            local max_radius = self:callTalent(self.T_BLACK_HOLE, "getMaxRadius")
            dam = self:spellCrit(dam + (edam * mult))
                local oe = game.level.map(px, py, Map.TERRAIN+1)
                if (oe and oe.is_maelstrom) or game.level.map:checkEntity(x, y, Map.TERRAIN, "block_move") then return nil end
                
                local e = Object.new{
                    old_feat = oe,
                    type = "void", subtype = "black hole",
                    name = ("%s's black hole"):tformat(self:getName():capitalize()),
                    display = ' ',
                    tooltip = mod.class.Grid.tooltip,
                    always_remember = true,
                    temporary = dur,
                    is_maelstrom = true,
                    x = px, y = py,
                    canAct = false,
                    dam = dam,
                    radius = rad,
                    max_radius = max_radius,
                    rebuild_particles = function(self)
                        if self.particles then game.level.map:removeParticleEmitter(self.particles) end
                        if self.particles2 then game.level.map:removeParticleEmitter(self.particles2) end

                        local particle = engine.Particles.new("generic_vortex", self.radius, {radius=self.radius, rm=255, rM=255, gm=180, gM=255, bm=180, bM=255, am=35, aM=90})
                        local particle2 = engine.Particles.new("image", self.radius, {size=64*self.radius, image="particles_images/black_hole"}) particle2.zdepth = 4
                        if core.shader.allow("distort") then particle:setSub("vortex_distort", self.radius, {radius=self.radius}) end
                        self.particles2 = game.level.map:addParticleEmitter(particle2, self.x, self.y)
                        self.particles = game.level.map:addParticleEmitter(particle, self.x, self.y)
                        game:shakeScreen(10, 3)
                    end,
                    act = function(self)
                        local tgts = {}
                        local DamageType = require "engine.DamageType"
                        local Map = require "engine.Map"
                        if self.radius < self.max_radius then
                            self.radius = math.min(self.max_radius, (self.radius + 1))
                            self:rebuild_particles()
                        end
                        local grids = core.fov.circle_grids(self.x, self.y, self.radius, true)
                        for x, yy in pairs(grids) do for y, _ in pairs(grids[x]) do
                            local Map = require "engine.Map"
                            local target = game.level.map(x, y, Map.ACTOR)
                            local friendlyfire = false
                            if target and not (friendlyfire == false and self.summoner:reactionToward(target) >= 0) then 
                                tgts[#tgts+1] = {actor=target, sqdist=core.fov.distance(self.x, self.y, x, y)}
                            end
                        end end
                        table.sort(tgts, "sqdist")
                        for i, target in ipairs(tgts) do
                            local old_source = self.summoner.__project_source
                            self.summoner.__project_source = self
                            if target.actor:canBe("knockback") then
                                target.actor:pull(self.x, self.y, 1)
                                target.actor.logCombat(self, target.actor, "#Source# pulls #Target# in!")
                            end
                            DamageType:get(DamageType.VOID).projector(self.summoner, target.actor.x, target.actor.y, DamageType.VOID, self.dam)
                            self.summoner.__project_source = old_source
                        end
        
                        self:useEnergy()
                        self.temporary = self.temporary - 1
                        if self.temporary <= 0 then
                            game.level.map:removeParticleEmitter(self.particles)	
                            game.level.map:removeParticleEmitter(self.particles2)
                            if self.old_feat then game.level.map(self.x, self.y, engine.Map.TERRAIN+1, self.old_feat)
                            else game.level.map:remove(self.x, self.y, engine.Map.TERRAIN+1) end
                            game.level:removeEntity(self)
                            game.level.map:updateMap(self.x, self.y)
                            game.nicer_tiles:updateAround(game.level, self.x, self.y)
                        end
                    end,
                    summoner_gain_exp = true,
                    summoner = self,
                }
                e:rebuild_particles()
        
                game.level:addEntity(e)
                game.level.map(x, y, Map.TERRAIN+1, e)
                game.level.map:updateMap(x, y)
        end

    end)

    game:playSoundNear(self, "talents/tidalwave")

    return true
end

T_ENTROPIC_GIFT.info = function(self, t)
		local power = t.getPower(self,t)
		return ([[Your unnatural existence causes the fabric of reality to reject your presence. 25%% of all direct healing received damages you in the form of entropic backlash over 8 turns, which is irresistible and bypasses all shields, but cannot kill you.

You may activate this talent to channel your entropy onto a nearby enemy, removing all entropic backlash to inflict darkness and temporal damage equal to %d%% of your entropy over 4 turns and blinding the target for the same duration.

The damage dealt when applying this to an enemy will increase with your Spellpower.]]):
		tformat(power)
end

-- Black Hole
T_BLACK_HOLE.getDuration = function(self, t) return math.floor(self:combatTalentScale(t, 2, 4.6)) end
T_BLACK_HOLE.getMaxRadius = function(self, t) return math.floor(self:combatTalentLimit(t, 5, 1, 4)) end