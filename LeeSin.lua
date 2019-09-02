local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero

local myHero = myHero
local LocalGameTimer = Game.Timer
local GameMissile = Game.Missile
local GameMissileCount = Game.MissileCount

local lastQ = 0

local lastW = 0
local lastE = 0
local lastR = 0
local lastIG = 0
local lastMove = 0

local Enemys = {}
local Allys = {}

local orbwalker
local TargetSelector
if (myHero.charName ~= "Thresh" or "Leesin") then 
    print("ShadowAIO - " .. myHero.charName .. " has loaded!")
end


Callback.Add("Load", function()
    if FileExist(COMMON_PATH .. "GamsteronPrediction.lua") then
        require('GamsteronPrediction');
    else
        print("Requires GamsteronPrediction please download the file thanks!");
        return
    end
    orbwalker = _G.SDK.Orbwalker
    TargetSelector = _G.SDK.TargetSelector
    LeeSin()
end)

local function IsValid(unit)
    if (unit
        and unit.valid
        and unit.isTargetable
        and unit.alive
        and unit.visible
        and unit.networkID
        and unit.health > 0
        and not unit.dead
    ) then
    return true;
end
return false;
end

local function Ready(spell)
    return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0
end

local function OnAllyHeroLoad(cb)
    for i = 1, GameHeroCount() do
        local obj = GameHero(i)
        if obj.isAlly then
            cb(obj)
        end
    end
end

local function OnEnemyHeroLoad(cb)
    for i = 1, GameHeroCount() do
        local obj = GameHero(i)
        if obj.isEnemy then
            cb(obj)
        end
    end
end

class "LeeSin"
function LeeSin:__init()
    print("LeeSin Init Loaded")
    
    self.Q = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 60, Range = 1200, Speed = 1750, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
    self.Q2 = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 60, Range = 1300, Speed = 1400, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
    self.W = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 800, Range = 700, Speed = 1400, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
    self.E = {Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 350, Range = 303, Speed = 0, Collision = true, MaxCollision = 1, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
    self.R = {Type = _G.SPELLTYPE_LINE, Delay = 0.50, Radius = 0, Range = 375, Speed = 3200, Collision = true, MaxCollision = 1, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
    
    self:LoadMenu()
    
    OnAllyHeroLoad(function(hero)
        Allys[hero.networkID] = hero
    end)
    
    OnEnemyHeroLoad(function(hero)
        Enemys[hero.networkID] = hero
    end)
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    
    orbwalker:OnPreMovement(
        function(args)
            if lastMove + 180 > GetTickCount() then
                args.Process = false
            else
                args.Process = true
                lastMove = GetTickCount()
            end
        end
    )
end

function LeeSin:LoadMenu()
    self.shadowMenuLee = MenuElement({type = MENU, id = "shadowLeeSin", name = "Shadow Lee"})
    self.shadowMenuLee:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenuLee.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true})
    self.shadowMenuLee.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true})
    self.shadowMenuLee:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
    self.shadowMenuLee.jungleclear:MenuElement({id = "UseQ", name = "Use Q in Jungle Clear", value = true})
    self.shadowMenuLee.jungleclear:MenuElement({id = "UseW", name = "Use W in Jungle Clear", value = true})
    self.shadowMenuLee.jungleclear:MenuElement({id = "UseE", name = "Use E in Jungle Clear", value = true})
    self.shadowMenuLee:MenuElement({type = MENU, id = "killsteal", name = "Kill Steal"})
    self.shadowMenuLee.killsteal:MenuElement({id = "AutoR", name = "Auto R", value = true})
    self.shadowMenuLee.killsteal:MenuElement({id = "AutoQ", name = "Auto Q", value = true})
end

function LeeSin:Draw()
    
end

function LeeSin:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    self:killsteal()
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
        self:jungleclear()
    end
end

function LeeSin:killsteal() 
    local target = TargetSelector:GetTarget(self.R.Range, 1)
    if target ~= nil then
        local rdmg = (({150, 375, 600})[myHero:GetSpellData(_R).level] + (myHero.bonusDamage * 2))
        if Ready(_R) and target and IsValid(target) and (target.health <= rdmg) and self.shadowMenuLee.killsteal.AutoR:Value() then
            --Control.CastSpell(HK_Q, target)
            self:CastR(target)
        end
    end
    target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target ~= nil then
        local qdmg = (({55, 80, 105, 130, 155})[myHero:GetSpellData(_Q).level] + myHero.bonusDamage) * (2 - target.health / target.maxHealth)
        if Ready(_Q) and target and IsValid(target) and (target.health <= qdmg) and self.shadowMenuLee.killsteal.AutoQ:Value() then
            --Control.CastSpell(HK_Q, target)
            self:CastQ(target)
        end
    end
end

function LeeSin:Combo()
    print(myHero:GetSpellData(_Q).name)
    local qishit = myHero:GetSpellData(_Q).toggleState
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenuLee.combo.Q:Value() then
            --Control.CastSpell(HK_Q, target)
            self:CastQ(target)
        end
        if myHero:GetSpellData(_Q).name == BlindMonkQTwo then
            self:CastQ()
        end
    end
    

    local target = TargetSelector:GetTarget(self.E.Range, 1)
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenuLee.combo.E:Value() then
            Control.KeyDown(HK_E)
            --self:CastSpell(HK_Etarget)
        end
    end

end

function LeeSin:jungleclear()
if self.shadowMenuLee.jungleclear.UseQ:Value() then 
    for i = 1, Game.MinionCount() do
        local obj = Game.Minion(i)
        if obj.team ~= myHero.team then
            if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                if Ready(_Q) and self.shadowMenuLee.jungleclear.UseQ:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                    Control.CastSpell(HK_Q, obj);
                end
            end
        end
        if Ready(_W) and self.shadowMenuLee.jungleclear.UseW:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 125 + myHero.boundingRadius then
            Control.CastSpell(HK_W);
        end
        if Ready(_E) and self.shadowMenuLee.jungleclear.UseE:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 125 + myHero.boundingRadius then
            Control.CastSpell(HK_E);
        end
    end
end
end

function LeeSin:CastQ(target)
    if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_Q, Pred.CastPosition)
            lastQ = GetTickCount()
        end
    end
end

function LeeSin:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end