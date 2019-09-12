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
local HITCHANCE_NORMAL = 2
local HITCHANCE_HIGH = 3
local HITCHANCE_IMMOBILE = 4

local Enemys = {}
local Allys = {}

local orbwalker
local TargetSelector

local Champions = {
    ["Urgot"] = true, 
    ["LeeSin"] = true, 
    ["MasterYi"] = true, 
    --["Ezreal"] = true, -- ADC
    --["Pyke"] = true, -- Sup
}

--Checking Champion 
if Champions[myHero.charName] == nil then
    print('Shadow AIO does not support ' .. myHero.charName) return
end


Callback.Add("Load", function()
    orbwalker = _G.SDK.Orbwalker
    TargetSelector = _G.SDK.TargetSelector
    if FileExist(COMMON_PATH .. "GamsteronPrediction.lua") then
        require('GamsteronPrediction');
    else
        print("Requires GamsteronPrediction please download the file thanks!");
        return
    end
    local _IsHero = _G[myHero.charName]();
    _IsHero:LoadMenu();
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

local function GetAllyHeroes() 
	AllyHeroes = {}
	for i = 1, Game.HeroCount() do
		local Hero = Game.Hero(i)
		if Hero.isAlly and not Hero.isMe then
			table.insert(AllyHeroes, Hero)
		end
	end
	return AllyHeroes
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
if myHero.charName == "Urgot" then
class "Urgot"
function Urgot:__init()
    
    self.Q = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 60, Range = 800, Speed = 1400, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
    self.W = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 800, Range = 800, Speed = 1400, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
    self.E = {Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 0, Range = 475, Speed = 0, Collision = true, MaxCollision = 1, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
    self.R = {Type = _G.SPELLTYPE_LINE, Delay = 0.50, Radius = 0, Range = 2500, Speed = 3200, Collision = true, MaxCollision = 1, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
    
    
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

function Urgot:LoadMenu()
    self.shadowMenu = MenuElement({type = MENU, id = "shadowUrgot", name = "Shadow Urgot"})
    self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenu.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true})
    self.shadowMenu.combo:MenuElement({id = "W", name = "Use W in Combo(Recomended Disabled)", value = false})
    self.shadowMenu.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true})
    self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
    self.shadowMenu.jungleclear:MenuElement({id = "UseQ", name = "Use Q in Jungle Clear", value = true})
    self.shadowMenu.jungleclear:MenuElement({id = "UseE", name = "Use E in Jungle Clear", value = true})
    self.shadowMenu:MenuElement({type = MENU, id = "autor", name = "Auto R"})
    self.shadowMenu.autor:MenuElement({id = "AutoR", name = "Auto R", value = true})
    --self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
end

function Urgot:Draw()
    
end

function Urgot:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    self:AutoR()
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
        self:jungleclear()
    end
end

function Urgot:AutoR()
    local target = TargetSelector:GetTarget(self.R.Range, 1)
    if Ready(_R) and target and IsValid(target) and (target.health <= target.maxHealth / 4) and self.shadowMenu.autor.AutoR:Value() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        print(Pred.Hitchance)
            --Control.CastSpell(HK_Q, target)
            self:CastR(target)
    end
end


function Urgot:Combo()
    local QPred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.combo.Q:Value() then
            --Control.CastSpell(HK_Q, target)
            self:CastQ(target)
        end
    end

    local Wactive = false;
    if myHero:GetSpellData(_W).name == 'UrgotW2' then
    Wactive = true
    else
    Wactive = false
    end
    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if Ready(_W) and target and IsValid(target) and Wactive == false then
        if self.shadowMenu.combo.W:Value() then
            Control.KeyDown(HK_W)
            Control.KeyUp(HK_W)
        end
    end
    
    local target = TargetSelector:GetTarget(self.E.Range - 100, 1)
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.combo.E:Value() then
            Control.CastSpell(HK_E, target)
            --self:CastSpell(HK_Etarget)
        end
    end

end

function Urgot:jungleclear()
if self.shadowMenu.jungleclear.UseQ:Value() then 
    for i = 1, Game.MinionCount() do
        local obj = Game.Minion(i)
        if obj.team ~= myHero.team then
            if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                if Ready(_Q) and self.shadowMenu.jungleclear.UseQ:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < 800) then
                    Control.CastSpell(HK_Q, obj);
                end
            end
        end
        if Ready(_E) and self.shadowMenu.jungleclear.UseE:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 125 + myHero.boundingRadius then
            Control.CastSpell(HK_E, obj);
        end
    end
end
end

function Urgot:CastQ(target)
    if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_Q, Pred.CastPosition)
            lastQ = GetTickCount()
        end
    end
end

function Urgot:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end
end
if myHero.charName == "LeeSin" then
    class "LeeSin"
function LeeSin:__init()
    
    self.Q = {_G.SPELLTYPE_LINE, Delay = 0.25, Radius = 65, Range = 1200, Speed = 1750, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_YASUOWALL}}
    self.W = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 800, Range = 700, Speed = 1400, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
    self.E = {Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 350, Range = 350, Speed = 0, Collision = true, MaxCollision = 1, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
    self.R = {Type = _G.SPELLTYPE_LINE, Delay = 0.50, Radius = 0, Range = 375, Speed = 3200, Collision = true, MaxCollision = 1, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
    
    
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
    self.shadowMenuLee:MenuElement({type = MENU, id = "autow", name = "Auto W settings"})
    self.shadowMenuLee.autow:MenuElement({id = "autows", name = "Auto W yourself", value = true})
    self.shadowMenuLee.autow:MenuElement({id = "selfhealth", name = "Min health to auto w self", value = 30, min = 0, max = 100, identifier = "%"})
    self.shadowMenuLee.autow:MenuElement({id = "autowa", name = "Auto W ally", value = true})
    self.shadowMenuLee.autow:MenuElement({id = "allyhealth", name = "Min health to auto w ally", value = 30, min = 0, max = 100, identifier = "%"})
	self.shadowMenuLee:MenuElement({type = MENU, id = "Drawing", name = "Drawing Settings"})
	self.shadowMenuLee.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = true})
	self.shadowMenuLee.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = true})
	self.shadowMenuLee.Drawing:MenuElement({id = "DrawE", name = "Draw [E] Range", value = true})
    self.shadowMenuLee.Drawing:MenuElement({id = "DrawW", name = "Draw [W] Range", value = true})
end

function LeeSin:Draw()
    if myHero.dead then return end
	if self.shadowMenuLee.Drawing.DrawR:Value() and Ready(_R) then
    Draw.Circle(myHero, 375, 1, Draw.Color(255, 225, 255, 10))
	end                                                 
	if self.shadowMenuLee.Drawing.DrawQ:Value() and Ready(_Q) and myHero:GetSpellData(_Q).name == "BlindMonkQOne" then
    Draw.Circle(myHero, 1200, 1, Draw.Color(225, 225, 0, 10))
	end
	if self.shadowMenuLee.Drawing.DrawE:Value() and Ready(_E) and myHero:GetSpellData(_E).name == "BlindMonkEOne"  then
    Draw.Circle(myHero, 350, 1, Draw.Color(225, 225, 125, 10))
	end
	if self.shadowMenuLee.Drawing.DrawW:Value() and Ready(_W) then
    Draw.Circle(myHero, 700, 1, Draw.Color(225, 225, 125, 10))
	end
end

function LeeSin:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    self:killsteal()
    self:autow()
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
        self:jungleclear()
    end
end

function LeeSin:killsteal() 
    local target = TargetSelector:GetTarget(self.R.Range, 1)
    if target ~= nil then
        local rdmg = (({150, 375, 600})[myHero:GetSpellData(_R).level or 1] + (myHero.bonusDamage * 2))
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
    local TargetSelector = _G.SDK.TargetSelector
    local pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
    local qishit = myHero:GetSpellData(_Q).toggleState
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if myHero:GetSpellData(_Q).name == BlindMonkQTwo and Ready(_Q) then
        Control.KeyDown(_Q)
    end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenuLee.combo.Q:Value() then
            --Control.CastSpell(HK_Q, target)
            self:CastQ(target)
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

function LeeSin:autow()
    local target = TargetSelector:GetTarget(800)     	
    if target == nil then return end	
        
        if self.shadowMenuLee.autow.autows:Value() and Ready(_W) then
            if myHero.health/myHero.maxHealth <= self.shadowMenuLee.autow.selfhealth:Value()/100 then
                Control.CastSpell(HK_W, myHero)
                if myHero:GetSpellData(_W).name == "BlindMonkWTwo" then
                    Control.CastSpell(HK_W)
                end
            end
            for i, ally in pairs(GetAllyHeroes()) do
                if self.shadowMenuLee.autow.autowa:Value() and IsValid(ally,1000) and myHero.pos:DistanceTo(ally.pos) <= 700 and ally.health/ally.maxHealth <= self.shadowMenuLee.autow.allyhealth:Value()/100 then
                    Control.CastSpell(HK_W, ally)
                    if HasBuff(ally, "blindmonkwoneshield") then
                        Control.CastSpell(HK_W)
                    end
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
end

class "MasterYi"
function MasterYi:__init()
    
    self.Q = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Radius = 600, Range = 600, Speed = 1750, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_YASUOWALL}}
    
    
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

function MasterYi:LoadMenu()
    self.shadowMenuYi = MenuElement({type = MENU, id = "shadowMasterYi", name = "Shadow Yi"})
    self.shadowMenuYi:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenuYi.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true})
    self.shadowMenuYi.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true})
    self.shadowMenuYi:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
    self.shadowMenuYi.jungleclear:MenuElement({id = "UseQ", name = "Use Q in Jungle Clear", value = true})
    self.shadowMenuYi.jungleclear:MenuElement({id = "UseW", name = "Use W in Jungle Clear", value = true})
    self.shadowMenuYi.jungleclear:MenuElement({id = "UseE", name = "Use E in Jungle Clear", value = true})
    self.shadowMenuYi:MenuElement({type = MENU, id = "autow", name = "Auto W settings"})
    self.shadowMenuYi.autow:MenuElement({id = "autow", name = "Auto W yourself", value = true})
    self.shadowMenuYi.autow:MenuElement({id = "selfhealth", name = "Min health to auto w", value = 30, min = 0, max = 100, identifier = "%"})
    self.shadowMenuYi:MenuElement({type = MENU, id = "DodgeSetting", name = "Ddoge Settings"})
    self.shadowMenuYi.DodgeSetting:MenuElement({id = "DodgeSpells", name = "Dodge Incoming spells with [Q]", value = true})
    self.shadowMenuYi.DodgeSetting:MenuElement({id = "Follow", name = "Use Q to follow dashes / blinks", value = true})
	self.shadowMenuYi:MenuElement({type = MENU, id = "Drawing", name = "Drawing Settings"})
	self.shadowMenuYi.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = true})
end

function MasterYi:Draw()
    if myHero.dead then return end
end

function MasterYi:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
        self:jungleclear()
    end
    self:autow()
    self:OnRecvSpell(target);
    if target then
        self:FollowDash(target);
    end
end

function MasterYi:Combo()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenuYi.combo.Q:Value() then
            Control.CastSpell(HK_Q, target)
        end
    end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenuYi.combo.E:Value() then
            Control.KeyDown(HK_E)
            --self:CastSpell(HK_Etarget)
        end
    end
end

function MasterYi:jungleclear()
if self.shadowMenuYi.jungleclear.UseQ:Value() then 
    for i = 1, Game.MinionCount() do
        local obj = Game.Minion(i)
        if obj.team ~= myHero.team then
            if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                if Ready(_Q) and self.shadowMenuYi.jungleclear.UseQ:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                    Control.CastSpell(HK_Q, obj);
                end
            end
        end
        if Ready(_E) and self.shadowMenuYi.jungleclear.UseE:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 125 + myHero.boundingRadius then
            Control.CastSpell(HK_E);
        end
    end
end
end

function MasterYi:autow()   	
        if self.shadowMenuYi.autow.autow:Value() and Ready(_W) then
            if myHero.health/myHero.maxHealth <= self.shadowMenuYi.autow.selfhealth:Value()/100 then
                Control.CastSpell(HK_W, myHero)
        end
    end
end

function MasterYi:CastDodge()
    local target = nil
	local bestchamp = { hero = nil, health = math.huge, maxHealth = math.huge }
	if Game.HeroCount() > 0 then
		for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
			if hero.IsEnemy and hero.visible and myHero.pos:DistanceTo(hero.pos) <= 600 then
				if hero.maxHealth < bestchamp.maxHealth then
					bestchamp.hero = hero
					bestchamp.health = hero.health
					bestchamp.maxHealth = hero.maxHealth
				end
			end
		end
		target = bestchamp.hero
	end
	if target then
		local enemiesInRange = 0
		for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
			if hero.IsEnemy and hero.team ~= target.team and target.pos:DistanceTo(hero.pos) < 1000 then
				enemiesInRange = enemiesInRange + 1
			end
		end
		if enemiesInRange > 1 then
            for i = 1, Game.MinionCount() do
                local obj = Game.Minion(i)
                if obj.team ~= myHero.team then
					if obj and myHero.pos:DistanceTo(obj.pos) < 600 then
						target = obj
						break
					end
				end
			end
		end
	else
		for i = 1, Game.MinionCount() do
            local obj = Game.Minion(i)
            if obj.team ~= myHero.team then
				if obj and myHero.pos:DistanceTo(obj.pos) < 600 then
					target = obj
					break
				end
			end
		end
	end
	if target then
		if self.shadowMenuYi.DodgeSetting.DodgeSpells:Value() then
            Control.CastSpell(HK_Q, target);
		end
	end
end

function MasterYi:Dodge()
    local spell = myHero.activeSpell
	if Ready(_Q) and spell and spell.owner and spell.owner.team == myHero.team and not myHero.attackData.state == STATE_ATTACK then
		if spell.target and spell.target == myHero then
			self:CastDodge()
		else
			if myHero.pos:DistanceTo(spell.endPos) <= (150 + myHero.boundingRadius) / 2 then
				self:CastDodge()
			end
		end
	end
end

function MasterYi:FollowDash(target)
    if self.shadowMenuYi.DodgeSetting.Follow:Value() and target and target.visible and not target.dead and target.pathing and target.pathing.hasMovePath and target.pathing.isDashing then
        Control.CastSpell(HK_Q, target);
	end
end



function MasterYi:OnRecvSpell(target)
    self:Dodge();
end

function MasterYi:CastQ(target)
    if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_Q, Pred.CastPosition)
            lastQ = GetTickCount()
        end
    end
end
