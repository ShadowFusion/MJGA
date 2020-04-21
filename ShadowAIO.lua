----------------------------------------------------------------------

local Heroes = {"MasterYi", "LeeSin", "Elise", "Jinx", "Leona", "Braum", "Blitzcrank", "Nami", "Sona", "DrMundo"}								

if not table.contains(Heroes, myHero.charName) then                 -- < ----- On first lines you must check your supported Champs,,,
	print('Shadow AIO does not support ' .. myHero.charName)				-- otherwise all functions will be loaded until the first champ check although no champ is supported
return end
----------------------------------------------------------------------
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
local ItemHotKey = {[ITEM_1] = HK_ITEM_1, [ITEM_2] = HK_ITEM_2,[ITEM_3] = HK_ITEM_3, [ITEM_4] = HK_ITEM_4, [ITEM_5] = HK_ITEM_5, [ITEM_6] = HK_ITEM_6, [ITEM_7] = HK_ITEM_7,}
-- [ AutoUpdate ] --
do
    
    local Version = 0.3
    
    local Files = {
        Lua = {
            Path = SCRIPT_PATH,
            Name = "ShadowAIO.lua",
            Url = "https://raw.githubusercontent.com/ShadowFusion/MJGA/master/ShadowAIO.lua"
        },
        Version = {
            Path = SCRIPT_PATH,
            Name = "ShadowAIO.version",
            Url = "https://raw.githubusercontent.com/ShadowFusion/MJGA/master/ShadowAIO.version"    -- check if Raw Adress correct pls.. after you have create the version file on Github
        }
    }
    
    local function AutoUpdate()
        
        local function DownloadFile(url, path, fileName)
            DownloadFileAsync(url, path .. fileName, function() end)
            while not FileExist(path .. fileName) do end
        end
        
        local function ReadFile(path, fileName)
            local file = io.open(path .. fileName, "r")
            local result = file:read()
            file:close()
            return result
        end
        
        DownloadFile(Files.Version.Url, Files.Version.Path, Files.Version.Name)
        local textPos = myHero.pos:To2D()
        local NewVersion = tonumber(ReadFile(Files.Version.Path, Files.Version.Name))
        if NewVersion > Version then
            DownloadFile(Files.Lua.Url, Files.Lua.Path, Files.Lua.Name)
            print("New ShadowAIO Vers. Press 2x F6")     -- <-- you can change the massage for users here !!!!
        else
            print(Files.Version.Name .. ": No Updates Found")   --  <-- here too
        end
    
    end
    
    AutoUpdate()

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

    if FileExist(COMMON_PATH .. "PremiumPrediction.lua") then
        require('PremiumPrediction');
    else
        print("Requires PremiumPrediction please download the file thanks!");
        return
    end

    require('damagelib')
    --require('PremiumPrediction')
    --require('2DGeometry')

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

local function MinionsNear(pos,range)
    local pos = pos.pos
    local N = 0
        for i = 1, Game.MinionCount() do 
        local Minion = Game.Minion(i)
        local Range = range * range
        if IsValid(Minion, 800) and Minion.team == TEAM_ENEMY and GetDistanceSqr(pos, Minion.pos) < Range then
            N = N + 1
        end
    end
    return N    
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

function GetDistanceSqr(p1, p2)
    if not p1 then return math.huge end
    p2 = p2 or myHero
    local dx = p1.x - p2.x
    local dz = (p1.z or p1.y) - (p2.z or p2.y)
    return dx*dx + dz*dz
end

function CountEnemiesNear(pos, range)
    local pos = pos.pos
    local N = 0
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if (IsValid(hero, range) and hero.isEnemy and GetDistanceSqr(pos, hero.pos) < range * range) then
            N = N + 1
        end
    end
    return N
end

function GetCastLevel(unit, slot)
    return unit:GetSpellData(slot).level == 0 and 1 or unit:GetSpellData(slot).level
end

local function GetStatsByRank(slot1, slot2, slot3, spell)
    local slot1 = 0
    local slot2 = 0
    local slot3 = 0
    return (({slot1, slot2, slot3})[myHero:GetSpellData(spell).level or 1])
end
--[[----------------------------------------------------------------------------------------------------------------------------------------------
   _   _   _   _   _      
  / \ / \ / \ / \ / \     
 ( S | T | A | R | T )    
  \_/ \_/ \_/ \_/ \_/     
   _   _                  
  / \ / \                 
 ( O | F )                
  \_/ \_/                 
   _   _   _   _   _   _  
  / \ / \ / \ / \ / \ / \ 
 ( J | U | N | G | L | E )
  \_/ \_/ \_/ \_/ \_/ \_/ 
]]---------------------------------------------------------------------------------------------------------------------------------------------------


--[[
   _   _   _   _   _   _   _   _  
  / \ / \ / \ / \ / \ / \ / \ / \ 
 ( M | a | s | t | e | r | Y | i )
  \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/  
                                                                    
]]


--local Heroes = {"MasterYi"}											<--- remove this 2 lines,,, you end this script with this, if myHero not MasterYi
--if not table.contains(Heroes, myHero.charName) then return end       		  I have added check on line 1 with explain why i do this....
        
class "MasterYi"
function MasterYi:__init()
    
    self.Q = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Radius = 0, Range = 600, Speed = 4000, Collision = false}
    

    OnAllyHeroLoad(function(hero)
        Allys[hero.networkID] = hero
    end)
    
    OnEnemyHeroLoad(function(hero)
        Enemys[hero.networkID] = hero
    end)    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    
    orbwalker:OnPreMovement(function(args)
        if lastMove + 180 > GetTickCount() then
            args.Process = false
        else
            args.Process = true
            lastMove = GetTickCount()
        end
    end)
end

local Icons = {
    ["MasterYiIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/7/73/Master_Yi_OriginalSquare.png",
    ["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/e6/Alpha_Strike.png",
    ["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/61/Meditate.png",
    ["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/7/74/Wuju_Style.png",
    ["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/3/34/Highlander.png",
    ["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
    ["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
    }

function MasterYi:LoadMenu()
    self.shadowMenu = MenuElement({type = MENU, id = "shadowMasterYi", name = "Shadow MasterYi", leftIcon = Icons["MasterYiIcon"]})


    -- COMBO --
    self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenu.combo:MenuElement({id = "useq", name = "Use [Q] in combo", value = true, leftIcon = Icons.Q})
    self.shadowMenu.combo:MenuElement({id = "usee", name = "Use [E] in combo", value = true, leftIcon = Icons.E})
    self.shadowMenu.combo:MenuElement({id = "user", name = "Use [R] in combo", value = true, leftIcon = Icons.R})
    self.shadowMenu.combo:MenuElement({id = "userrange", name = "Use [R] only if out of [Q] range?", value = true, leftIcon = Icons.R})

    -- AUTO W --
    self.shadowMenu:MenuElement({type = MENU, id = "autow", name = "Auto W"})
    self.shadowMenu.autow:MenuElement({id = "usew", name = "Use [W] automatically", value = true, leftIcon = Icons.W})
    self.shadowMenu.autow:MenuElement({id = "usewhealth", name = "Min health to auto [W]", value = 30, min = 0, max = 100, identifier = "%"})

    -- JUNGLE CLEAR --
    self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
    self.shadowMenu.jungleclear:MenuElement({id = "useq", name = "Use [Q] in clear", value = true})
    self.shadowMenu.jungleclear:MenuElement({id = "usee", name = "Use [E] in clear", value = true})


    -- DRAWING SETTINGS --
    self.shadowMenu:MenuElement({type = MENU, id = "drawings", name = "Drawing Settings"})
    self.shadowMenu.drawings:MenuElement({id = "drawAutoW", name = "Draw if auto [W] is on", value = true})
    self.shadowMenu.drawings:MenuElement({id = "drawRSettings", name = "Draw if only [R] on combo if out of [Q] range is on", value = true})

end


function MasterYi:Draw()

    if self.shadowMenu.drawings.drawAutoW:Value() then
        Draw.Text("Auto Use W: ", 18, 200, 30, Draw.Color(255, 225, 255, 255))
            if self.shadowMenu.autow.usew:Value() then
                Draw.Text("ON", 18, 290, 30, Draw.Color(255, 0, 255, 0))
                else
                    Draw.Text("OFF", 18, 290, 30, Draw.Color(255, 255, 0, 0))
            end 
    end

    if self.shadowMenu.drawings.drawAutoW:Value() then
        Draw.Text("Use [R] if out of range: ", 18, 200, 60, Draw.Color(255, 225, 255, 255))
            if self.shadowMenu.combo.userrange:Value() then
                Draw.Text("ON", 18, 370, 60, Draw.Color(255, 0, 255, 0))
                else
                    Draw.Text("OFF", 18, 370, 60, Draw.Color(255, 255, 0, 0))
            end 
    end
end

function MasterYi:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    self:autoW()
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
        self:jungleclear()
    elseif orbwalker.Modes[1] then
        
    end
end

function MasterYi:autoW()
  	
        if self.shadowMenu.autow.usew:Value() and Ready(_W) then
            if myHero.health/myHero.maxHealth <= self.shadowMenu.autow.usewhealth:Value()/100 then
                Control.CastSpell(HK_W)
            end
        end

end

function MasterYi:jungleclear()

        for i = 1, Game.MinionCount() do
            local obj = Game.Minion(i)
            if obj.team ~= myHero.team then
                if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                    if Ready(_Q) and self.shadowMenu.jungleclear.useq:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
                        Control.CastSpell(HK_Q, obj)
                    end
                    if Ready(_E) and self.shadowMenu.jungleclear.usee:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
                        Control.CastSpell(HK_E);
                    end
                end
            end
            
        end

end


function MasterYi:Combo()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then return end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.combo.useq:Value() then
           self:CastQ(target)
        end														
    end

    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then return end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.combo.usee:Value() then
           Control.CastSpell(HK_E)
        end														
    end

    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then return end
        if Ready(_R) and target and IsValid(target) then
            if self.shadowMenu.combo.user:Value() then
                Control.CastSpell(HK_R)
            end
        end   

end


function MasterYi:GotBuff(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.name == buffname and buff.count > 0 then return buff.count end
    end
    return 0
end

function MasterYi:CastQ(target)
    if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_Q, Pred.CastPosition)
            lastQ = GetTickCount()
        end
    end
end
--[[
   _   _   _   _   _   _  
  / \ / \ / \ / \ / \ / \ 
 ( L | e | e | S | i | n )
  \_/ \_/ \_/ \_/ \_/ \_/ 

--]]
   
class "LeeSin"
function LeeSin:__init()
    
    self.Q = {_G.SPELLTYPE_LINE, Delay = 0.225, Radius = 60, Range = 1200, Speed = 1800, Collision = true, MaxCollision = 1, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO, _G.COLLISION_YASUOWALL}}
    self.Q2 = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Range = 1300}

    self.W = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Range = 700, Speed = 1500}
    self.W2 = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Range = 350, Speed = 1500}

    self.E = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Range = 425, Speed = 0}
    self.E2 = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Range = 575, Speed = 0}

    self.R = {_G.SPELLTYPE_CIRCLE, Delay = 0.225, Range = 375, Speed = 1500}

    OnAllyHeroLoad(function(hero)
        Allys[hero.networkID] = hero
    end)
    
    OnEnemyHeroLoad(function(hero)
        Enemys[hero.networkID] = hero
    end)    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    
    orbwalker:OnPreMovement(function(args)
        if lastMove + 180 > GetTickCount() then
            args.Process = false
        else
            args.Process = true
            lastMove = GetTickCount()
        end
    end)
end

local Icons = {
    ["LeeSinIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/1/16/Lee_Sin_OriginalSquare.png",
    ["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/7/74/Sonic_Wave.png",
    ["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f1/Safeguard.png",
    ["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/b/bb/Tempest.png",
    ["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/a/aa/Dragon%27s_Rage.png",
    ["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
    ["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
    }

function LeeSin:LoadMenu()
    self.shadowMenu = MenuElement({type = MENU, id = "shadowLeeSin", name = "Shadow LeeSin", leftIcon = Icons["LeeSinIcon"]})


    -- COMBO --
    self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenu.combo:MenuElement({id = "useq", name = "Use [Q] in combo", value = true, leftIcon = Icons.Q})
    self.shadowMenu.combo:MenuElement({id = "usee", name = "Use [E] in combo", value = true, leftIcon = Icons.E})

    -- AUTO W --
    self.shadowMenu:MenuElement({type = MENU, id = "autow", name = "Auto W"})
    self.shadowMenu.autow:MenuElement({id = "usew", name = "Use [W] automatically", value = true, leftIcon = Icons.W})
    self.shadowMenu.autow:MenuElement({id = "usewhealth", name = "Min health to auto [W]", value = 30, min = 0, max = 100, identifier = "%"})

    -- AUTO R --
    self.shadowMenu:MenuElement({type = MENU, id = "autor", name = "Auto R"})
    self.shadowMenu.autor:MenuElement({id = "user", name = "Use [R] automatically", value = true, leftIcon = Icons.W})
    self.shadowMenu.autor:MenuElement({id = "useronks", name = "Use [R] on killable", value = true})
    self.shadowMenu.autor:MenuElement({id = "userpanic", name = "Use [R] on panic", value = true})
    self.shadowMenu.autor:MenuElement({id = "userpanichealth", name = "Min health to auto [R] on panic", value = 30, min = 0, max = 100, identifier = "%"})

    -- JUNGLE CLEAR --
    self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
    self.shadowMenu.jungleclear:MenuElement({id = "useq", name = "Use [Q] in clear", value = true})
    self.shadowMenu.jungleclear:MenuElement({id = "usee", name = "Use [E] in clear", value = true})


    -- DRAWING SETTINGS --
    self.shadowMenu:MenuElement({type = MENU, id = "drawings", name = "Drawing Settings"})
    self.shadowMenu.drawings:MenuElement({id = "drawAutoW", name = "Draw if auto [W] is on", value = true})
    self.shadowMenu.drawings:MenuElement({id = "drawAutoRkillable", name = "Draw if auto [R] on killable is on", value = true})
    self.shadowMenu.drawings:MenuElement({id = "drawAutoRpanic", name = "Draw if auto [R] on low hp", value = true})

end


function LeeSin:Draw()

    if self.shadowMenu.drawings.drawAutoW:Value() then
        Draw.Text("Auto Use W: ", 18, 200, 30, Draw.Color(255, 225, 255, 255))
            if self.shadowMenu.autow.usew:Value() then
                Draw.Text("ON", 18, 370, 30, Draw.Color(255, 0, 255, 0))
                else
                    Draw.Text("OFF", 18, 370, 30, Draw.Color(255, 255, 0, 0))
            end 
    end

    if self.shadowMenu.drawings.drawAutoRkillable:Value() then
        Draw.Text("Use [R] if killable: ", 18, 200, 60, Draw.Color(255, 225, 255, 255))
            if self.shadowMenu.autor.useronks:Value() then
                Draw.Text("ON", 18, 370, 60, Draw.Color(255, 0, 255, 0))
                else
                    Draw.Text("OFF", 18, 370, 60, Draw.Color(255, 255, 0, 0))
            end 
    end

    if self.shadowMenu.drawings.drawAutoRpanic:Value() then
        Draw.Text("Use [R] to save self: ", 18, 200, 90, Draw.Color(255, 225, 255, 255))
            if self.shadowMenu.autor.userpanic:Value() then
                Draw.Text("ON", 18, 370, 90, Draw.Color(255, 0, 255, 0))
                else
                    Draw.Text("OFF", 18, 370, 90, Draw.Color(255, 255, 0, 0))
            end 
    end
end

function LeeSin:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    self:autoW()
    self:autoR()
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
        self:jungleclear()
    elseif orbwalker.Modes[1] then
        
    end
end


function LeeSin:autoW()
  	
        if self.shadowMenu.autow.usew:Value() and Ready(_W) then
            if myHero.health/myHero.maxHealth <= self.shadowMenu.autow.usewhealth:Value()/100 then
                Control.CastSpell(HK_W, myHero.pos)
            end
        end

end

function LeeSin:autoR()
local target = TargetSelector:GetTarget(self.R.Range, 1)
    if target and IsValid(target)then
        local rdmg = getdmg("R", target, myHero)
        if self.shadowMenu.autor.user:Value() and Ready(_R) then
            if self.shadowMenu.autor.useronks:Value() and rdmg > target.health then
                self:CastR(target)
            end
        end
    end
end

function LeeSin:jungleclear()

        for i = 1, Game.MinionCount() do
            local obj = Game.Minion(i)
            if obj.team ~= myHero.team then
                if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                    if Ready(_Q) and self.shadowMenu.jungleclear.useq:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
                        Control.CastSpell(HK_Q, obj)
                    end
                    if Ready(_E) and self.shadowMenu.jungleclear.usee:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.E.Range) then
                        Control.CastSpell(HK_E);
                    end
                end
            end
            
        end

end


function LeeSin:Combo()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then return end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.combo.useq:Value() then
           self:CastQ(target)
        end														
    end

    local target = TargetSelector:GetTarget(self.E.Range, 1)
    if target == nil then return end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.combo.usee:Value() then
           self:CastE(target)
        end														
    end


end


function LeeSin:GotBuff(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.name == buffname and buff.count > 0 then return buff.count end
    end
    return 0
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
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end

function LeeSin:CastE(target)
    if Ready(_E) and lastE + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.E, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_E, Pred.CastPosition)
            lastE = GetTickCount()
        end
    end
end

--[[
   _   _   _   _   _  
  / \ / \ / \ / \ / \ 
 ( E | L | I | S | E )
  \_/ \_/ \_/ \_/ \_/ 
]]

class "Elise"
function Elise:__init()
    
    self.QH = {Type = _G.SPELLTYPE_CIRCLE, Range = 625, Radius = 0, Speed = 2200, Collision = false}
    self.WH = {Type = _G.SPELLTYPE_LINE, Range = 950, Radius = 100, Speed = 5000, Collision = true, MaxCollision = 1, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_YASUOWALL, _G.COLLISION_ENEMY}}
    self.EH = {Type = _G.SPELLTYPE_LINE, Range = 1075, Radius = 55, Speed = 1600, Collision = true, MaxCollision = 1, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_YASUOWALL, _G.COLLISION_ENEMY}}

    self.QS = {Type = _G.SPELLTYPE_CIRCLE, Range = 475, Radius = 0, Speed = 20, Collision = false}
    self.ES = {Type = _G.SPELLTYPE_LINE, Range = 750, Radius = 0, Speed = 20}
    

    OnAllyHeroLoad(function(hero)
        Allys[hero.networkID] = hero
    end)
    
    OnEnemyHeroLoad(function(hero)
        Enemys[hero.networkID] = hero
    end)    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    
    orbwalker:OnPreMovement(function(args)
        if lastMove + 180 > GetTickCount() then
            args.Process = false
        else
            args.Process = true
            lastMove = GetTickCount()
        end
    end)
end

local Icons = {
    ["EliseIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/1/1b/Elise_OriginalSquare.png",
    ["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/2b/Neurotoxin.png",
    ["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/60/Volatile_Spiderling.png",
    ["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/0/02/Cocoon.png",
    ["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/2b/Spider_Form.png",
    ["EXH"] = "https://vignette2.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png"
    }

function Elise:LoadMenu()
    self.shadowMenu = MenuElement({type = MENU, id = "shadowElise", name = "Shadow Elise", leftIcon = Icons["EliseIcon"]})


    -- COMBO --
    self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenu.combo:MenuElement({id = "combo1", name = "Use Human E > W > Q > Spider E > Q > W", value = true})
    self.shadowMenu.combo:MenuElement({id = "combor", name = "Switch to R manually after human combo done?", value = true})

    -- Auto Stun --
    self.shadowMenu:MenuElement({type = MENU, id = "autostun", name = "Auto Stun Setting"})
    self.shadowMenu.autostun:MenuElement({id = "useautostun", name = "Use auto stun?", value = true})
    self.shadowMenu.autostun:MenuElement({id = "changeform", name = "Automatically change from spdier form?", value = true})

    -- Manual Stun --
    self.shadowMenu:MenuElement({type = MENU, id = "manualstun", name = "Manual Stun Setting"})
    self.shadowMenu.manualstun:MenuElement({id = "usemanualstun", name = "Use manual stun?", value = true})


    -- JUNGLE CLEAR --
    self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
    self.shadowMenu.jungleclear:MenuElement({id = "combo1", name = "Use Human E > W > Q > Spider E > Q > W", value = true})

     -- JUNGLE KILLSTEAL --
    self.shadowMenu:MenuElement({type = MENU, id = "junglekillsteal", name = "Jungle Steal"})
    self.shadowMenu.junglekillsteal:MenuElement({id = "W", name = "Use W in Jungle Steal", value = true, leftIcon = Icons.W})

    -- DRAWING SETTINGS --
    self.shadowMenu:MenuElement({type = MENU, id = "drawings", name = "Drawing Settings"})
    self.shadowMenu.drawings:MenuElement({id = "drawAutoE", name = "Draw if auto [E] is on", value = true})
    self.shadowMenu.drawings:MenuElement({id = "drawAutoForm", name = "Draw if auto [R] is on with Auto stun", value = true})
    self.shadowMenu.drawings:MenuElement({id = "drawManualE", name = "Draw if manual [E] is on", value = true})

end


function Elise:Draw()

    if self.shadowMenu.drawings.drawAutoE:Value() then
        Draw.Text("Auto Use E: ", 18, 200, 30, Draw.Color(255, 225, 255, 255))
            if self.shadowMenu.autostun.useautostun:Value() then
                Draw.Text("ON", 18, 285, 30, Draw.Color(255, 0, 255, 0))
                else
                    Draw.Text("OFF", 18, 285, 30, Draw.Color(255, 255, 0, 0))
            end 
    end

    if self.shadowMenu.drawings.drawAutoForm:Value() then
        Draw.Text("Auto Use R if can stun: ", 18, 200, 55, Draw.Color(255, 225, 255, 255))
            if self.shadowMenu.autostun.changeform:Value() then
                Draw.Text("ON", 18, 365, 55, Draw.Color(255, 0, 255, 0))
                else
                    Draw.Text("OFF", 18, 365, 55, Draw.Color(255, 255, 0, 0))
            end 
    end

    if self.shadowMenu.drawings.drawManualE:Value() then
        Draw.Text("Manual E with Harass Key: ", 18, 200, 80, Draw.Color(255, 225, 255, 255))
            if self.shadowMenu.manualstun.usemanualstun:Value() then
                Draw.Text("ON", 18, 390, 80, Draw.Color(255, 0, 255, 0))
                else
                    Draw.Text("OFF", 18, 390, 80, Draw.Color(255, 255, 0, 0))
            end 
    end

end

function Elise:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    --self:junglekillsteal()
        self:autostun()
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
        self:jungleclear()
    elseif orbwalker.Modes[1] then
        self:manualstun()
    end
end

function Elise:autostun()
    local target = TargetSelector:GetTarget(self.EH.Range, 1)
    if target and IsValid(target) then
    local d = myHero.pos:DistanceTo(target.pos)
    if Ready(_R) and self.shadowMenu.autostun.changeform:Value() and self.shadowMenu.autostun.useautostun:Value() and (myHero:GetSpellData(_Q).name == "EliseSpiderQCast")then
        Control.CastSpell(HK_R)
    end
    if Ready(_E) and self.shadowMenu.autostun.useautostun:Value() and self.shadowMenu.autostun.changeform:Value() and d < 1075 then
        self:CastEH(target)
    end
    end

end

function Elise:manualstun()
    local target = TargetSelector:GetTarget(self.EH.Range, 1)
    if target and IsValid(target) then
    local d = myHero.pos:DistanceTo(target.pos)
    if Ready(_E) and self.shadowMenu.manualstun.usemanualstun:Value() and d < 1075 then
        self:CastEH(target)
    end
    end
end

function Elise:jungleclear()

   -- if (myHero:GetSpellData(_R).name == "EliseRSpider") 

    if self.shadowMenu.jungleclear.combo1:Value() then 
        for i = 1, Game.MinionCount() do
            local obj = Game.Minion(i)
            if obj.team ~= myHero.team then
                if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                    if Ready(_E) and self.shadowMenu.jungleclear.combo1:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.EH.Range) then
                        Control.CastSpell(HK_E, obj);
                    end
                    if Ready(_W) and self.shadowMenu.jungleclear.combo1:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.WH.Range) then
                        Control.CastSpell(HK_W, obj);
                    end
                    if Ready(_Q) and self.shadowMenu.jungleclear.combo1:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.QH.Range) then
                        Control.CastSpell(HK_Q, obj);
                    end
                    if Ready(_R) and self.shadowMenu.jungleclear.combo1:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.QH.Range) then
                        Control.CastSpell(HK_R);
                    end
                    if Ready(_E) and self.shadowMenu.jungleclear.combo1:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.ES.Range) then
                        Control.CastSpell(HK_E);
                        Control.CastSpell(HK_E, target);
                    end
                end
            end
            
        end
    end

end


function Elise:Combo()
    local target = TargetSelector:GetTarget(self.EH.Range, 1)
    if target == nil then return end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.combo.combo1:Value() and (myHero:GetSpellData(_E).name == "EliseHumanE") then
           self:CastEH(target)
        end														
    end

    local target = TargetSelector:GetTarget(self.WH.Range, 1)
    if target == nil then return end
    local d = myHero.pos:DistanceTo(target.pos)
    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenu.combo.combo1:Value() and (myHero:GetSpellData(_W).name == "EliseHumanW") then
           self:CastWH(target)
        end														
    end

    local target = TargetSelector:GetTarget(self.QH.Range, 1)
    if target == nil then return end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.combo.combo1:Value() and (myHero:GetSpellData(_Q).name == "EliseHumanQ") then
           Control.CastSpell(HK_Q, target)
        end														
    end

    if Ready(_R) then
        if self.shadowMenu.combo.combor:Value() and (myHero:GetSpellData(_R).name == "EliseR") then
            Control.KeyDown(HK_R)
        end
    end 

 -- SPIDER --

    local target = TargetSelector:GetTarget(self.ES.Range, 1)
    if target == nil then return end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.combo.combo1:Value() and (myHero:GetSpellData(_E).name == "EliseSpiderEInitial") then
            Control.KeyDown(HK_E)
            Control.CastSpell(HK_E, target)
        end														
    end

    
    local target = TargetSelector:GetTarget(self.QS.Range, 1)
    if target == nil then return end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.combo.combo1:Value() and (myHero:GetSpellData(_Q).name == "EliseSpiderQCast") then
            Control.CastSpell(HK_Q, target)
        end														
    end

    local target = TargetSelector:GetTarget(self.QS.Range, 1)
    if target == nil then return end
    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenu.combo.combo1:Value() and (myHero:GetSpellData(_W).name == "EliseSpiderW") then
            Control.KeyDown(HK_W)
        end														
    end



end

function Elise:junglekillsteal()
    if self.shadowMenu.junglekillsteal.W:Value() then 
        for i = 1, Game.MinionCount() do
            local obj = Game.Minion(i)
            if obj.team ~= myHero.team then
                if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                    local wdmg = getdmg("W", obj, myHero, 1)
                    if Ready(_W) and self.shadowMenu.junglekillsteal.W:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.W.Range and obj.health < wdmg) then
                        Control.CastSpell(HK_W, obj);
                    end
                end
            end
        end
    end
end

function Elise:GotBuff(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.name == buffname and buff.count > 0 then return buff.count end
    end
    return 0
end

function Elise:CastWH(target)
    if Ready(_W) and lastW + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.WH, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_W, Pred.CastPosition)
            lastW = GetTickCount()
        end
    end
end

-- HUMAN CASTS --
function Elise:CastEH(target)
    if Ready(_E) and lastE + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.EH, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_E, Pred.CastPosition)
            lastE = GetTickCount()
        end
    end
end

function Elise:CastWS(target)
    if Ready(_W) and lastW + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.WS, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_W, Pred.CastPosition)
            lastW = GetTickCount()
        end
    end
end


-- SPIDER CASTS --
function Elise:CastES(target)
    if Ready(_E) and lastE + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.ES, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_E, Pred.CastPosition)
            lastE = GetTickCount()
        end
    end
end

function Elise:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end

--[[
   _   _   _   _   _   _   _   _  
  / \ / \ / \ / \ / \ / \ / \ / \ 
 ( D | r | . | M | u | n | d | o )
  \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ 
]]
class "DrMundo"
function DrMundo:__init()
    
    self.Q = {Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 60, Range = 975, Speed = 1850, Collision = true, MaxCollision = 1, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO, _G.COLLISION_YASUOWALL}}
    self.W = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 162.5, Range = 800, Speed = 0}
    

    OnAllyHeroLoad(function(hero)
        Allys[hero.networkID] = hero
    end)
    
    OnEnemyHeroLoad(function(hero)
        Enemys[hero.networkID] = hero
    end)    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    
    orbwalker:OnPreMovement(function(args)
        if lastMove + 180 > GetTickCount() then
            args.Process = false
        else
            args.Process = true
            lastMove = GetTickCount()
        end
    end)
end

local Icons = {
    ["DrMundoIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/c/c3/Dr._Mundo_OriginalSquare.png",
    ["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f2/Infected_Cleaver.png",
    ["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/5/5d/Burning_Agony.png",
    ["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/95/Masochism.png",
    ["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/8/81/Sadism.png",
    ["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
    ["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
    }

function DrMundo:LoadMenu()
    self.shadowMenu = MenuElement({type = MENU, id = "shadowDrMundo", name = "Shadow DrMundo", leftIcon = Icons["DrMundoIcon"]})


    -- COMBO --
    self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenu.combo:MenuElement({id = "useq", name = "Use [Q] in combo", value = true, leftIcon = Icons.Q})
    self.shadowMenu.combo:MenuElement({id = "usew", name = "Use [W] in combo", value = true, leftIcon = Icons.W})
    self.shadowMenu.combo:MenuElement({id = "usee", name = "Use [E] in combo", value = true, leftIcon = Icons.E})
    self.shadowMenu.combo:MenuElement({id = "user", name = "Use [R] in combo", value = true, leftIcon = Icons.R})
    self.shadowMenu.combo:MenuElement({id = "userhp", name = "Minimum HP to use [R]", value = 30, min = 0, max = 100, identifier = "%"})

    -- AUTO Q --
    self.shadowMenu:MenuElement({type = MENU, id = "autoq", name = "Auto Q"})
    self.shadowMenu.autoq:MenuElement({id = "useq", name = "Use [Q] automatically", value = true, leftIcon = Icons.Q})
    self.shadowMenu.autoq:MenuElement({id = "useqmanual", name = "Use [Q] on keydown", key = string.byte("T"), value = true})


    -- JUNGLE CLEAR --
    self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
    self.shadowMenu.jungleclear:MenuElement({id = "useq", name = "Use [Q] in clear", value = true})
    self.shadowMenu.jungleclear:MenuElement({id = "usee", name = "Use [E] in clear", value = true})
    self.shadowMenu.jungleclear:MenuElement({id = "usew", name = "Use [W] in clear", value = true})

    -- AUTO R --
    self.shadowMenu:MenuElement({type = MENU, id = "autor", name = "Auto R Settings"})
    self.shadowMenu.autor:MenuElement({id = "useautor", name = "Use auto [R] ?", value = true, leftIcon = Icons.R})
    self.shadowMenu.autor:MenuElement({id = "autorhp", name = "Activate R when at what % HP", value = 30, min = 0, max = 100, identifier = "%"})

    -- DRAWING SETTINGS --
    self.shadowMenu:MenuElement({type = MENU, id = "drawings", name = "Drawing Settings"})
    self.shadowMenu.drawings:MenuElement({id = "drawAutoQ", name = "Draw if auto [Q] is on", value = true})
    self.shadowMenu.drawings:MenuElement({id = "drawManualQ", name = "Draw if manual [Q] is on", value = true})

    -- SUMMONER SETTINGS --
    self.shadowMenu:MenuElement({type = MENU, id = "SummonerSettings", name = "Summoner Settings"})
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true, leftIcon = Icons.IGN})
    elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true, leftIcon = Icons.IGN}) 
    end

    if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true, leftIcon = Icons.EXH})
    elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true, leftIcon = Icons.EXH}) 
    end

end


function DrMundo:Draw()

    if self.shadowMenu.drawings.drawAutoQ:Value() then
        Draw.Text("Auto Use Q: ", 18, 200, 30, Draw.Color(255, 225, 255, 255))
            if self.shadowMenu.autoq.useq:Value() then
                Draw.Text("ON", 18, 370, 30, Draw.Color(255, 0, 255, 0))
                else
                    Draw.Text("OFF", 18, 370, 30, Draw.Color(255, 255, 0, 0))
            end 
    end

end

function DrMundo:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    self:AutoR()
    self:autoQ()
    self:AutoSummoners()
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
        self:jungleclear()
    elseif orbwalker.Modes[1] then
        
    end
end

function DrMundo:AutoR()
    local decimalhealthstring = "." .. self.shadowMenu.autor.autorhp:Value()
    local decimalhealth = myHero.maxHealth * decimalhealthstring

    if self.shadowMenu.autor.useautor:Value() and myHero.health <= decimalhealth and Ready(_R) then
        Control.CastSpell(HK_R)
    end
end

function DrMundo:AutoSummoners()
    -- IGNITE --
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target and IsValid(target) then
        local ignDmg = getdmg("IGNITE", target, myHero)
        if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and (target.health < ignDmg ) then
            Control.CastSpell(HK_SUMMONER_1, target)
        elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and (target.health < ignDmg ) then
            Control.CastSpell(HK_SUMMONER_2, target)
        end
    end
end


function DrMundo:autoQ()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target and IsValid(target) then
        if self.shadowMenu.autoq.useq:Value() and Ready(_Q) then
            self:CastQ(target)
        end

        if self.shadowMenu.autoq.useqmanual:Value() and Ready(_Q) then
            self:CastQ(target)
        end
    end

end

function DrMundo:jungleclear()

        for i = 1, Game.MinionCount() do
            local obj = Game.Minion(i)
            if obj.team ~= myHero.team then
                if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                    if Ready(_Q) and self.shadowMenu.jungleclear.useq:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
                        Control.CastSpell(HK_Q, obj)
                    end
                    if Ready(_E) and self.shadowMenu.jungleclear.usee:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
                        Control.CastSpell(HK_E);
                    end
                    if Ready(_W) and myHero:GetSpellData(_W).toogleState ~= 2 and self.shadowMenu.jungleclear.usew:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.W.Range) then
                        Control.CastSpell(HK_W);
                    end
                end
            end
            
        end

end


function DrMundo:Combo()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then return end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.combo.useq:Value() then
           self:CastQ(target)
        end														
    end

    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if target == nil then return end
    if Ready(_W) and target and IsValid(target) and myHero:GetSpellData(_W).toogleState ~= 2 then
        if self.shadowMenu.combo.usew:Value() then
           Control.KeyDown(HK_W)
        end														
    end

    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then return end
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.combo.usee:Value() then
           Control.CastSpell(HK_E)
        end														
    end


end


function DrMundo:GotBuff(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.name == buffname and buff.count > 0 then return buff.count end
    end
    return 0
end

function DrMundo:CastQ(target)
    if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_Q, Pred.CastPosition)
            lastQ = GetTickCount()
        end
    end
end

function DrMundo:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end

function DrMundo:CastE(target)
    if Ready(_E) and lastE + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.E, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_E, Pred.CastPosition)
            lastE = GetTickCount()
        end
    end
end














--[[-------------------------------------------------------------------------------------------------------------------------
_   _   _              
/ \ / \ / \             
( E | N | D )            
\_/ \_/ \_/             
 _   _                  
/ \ / \                 
( O | F )                
\_/ \_/                 
 _   _   _   _   _   _  
/ \ / \ / \ / \ / \ / \ 
( J | U | N | G | L | E )
\_/ \_/ \_/ \_/ \_/ \_/ 

--]]-------------------------------------------------------------------------------------------------------------------------
--[[
   _   _   _   _  
  / \ / \ / \ / \ 
 ( J | I | N | X )
  \_/ \_/ \_/ \_/ 
]]

class "Jinx"
function Jinx:__init()
    
    self.Q = {Type = _G.SPELLTYPE_CIRCLE, Radius = 150}
    self.W = {Type = _G.SPELLTYPE_LINE, Range = 1450, Radius = 40.25, Speed = 3200, Collision = true, MaxCollision = 1, CollisionTypes = {_G.COLLISION_YASUOWALL, _G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
    self.E = {Type = _G.SPELLTYPE_CIRCLE, Delay = 1, Range = 900, Radius = 50}
    self.R = {Type = _G.SPELLTYPE_CIRCLE, Delay = 1, Range = 20000, Radius = 225, Speed = 1500, Collision = true, MaxCollision = 1, CollisionTypes = {2, 3}}

    

    OnAllyHeroLoad(function(hero)
        Allys[hero.networkID] = hero
    end)
    
    OnEnemyHeroLoad(function(hero)
        Enemys[hero.networkID] = hero
    end)
                                      --- you need Load here your Menu        
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    
    orbwalker:OnPreMovement(function(args)
        if lastMove + 180 > GetTickCount() then
            args.Process = false
        else
            args.Process = true
            lastMove = GetTickCount()
        end
    end)
end

local Icons = {
    ["JinxIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/65/Jinx_OriginalSquare.png",
    ["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4d/Pow-Pow.png",
    ["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/7/76/Zap%21.png",
    ["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/b/bb/Flame_Chompers%21.png",
    ["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/a/a8/Super_Mega_Death_Rocket%21.png",
    ["EXH"] = "https://vignette2.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png"
    }

function Jinx:LoadMenu()
    self.shadowMenu = MenuElement({type = MENU, id = "shadowJinx", name = "Shadow Jinx", leftIcon = Icons["JinxIcon"]})


    -- COMBO --
    self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenu.combo:MenuElement({id = "Q", name = "Use [Q] in Combo", value = true, leftIcon = Icons.Q})
    self.shadowMenu.combo:MenuElement({id = "W", name = "Use [W] in Combo", value = true, leftIcon = Icons.W})
    self.shadowMenu.combo:MenuElement({id = "E", name = "Use [E] in  Combo", value = true, leftIcon = Icons.E})
    self.shadowMenu.combo:MenuElement({id = "EONCC", name = "Auto Use [E] on CC Targets", value = true, leftIcon = Icons.E})

    -- R SETTINGS --
    self.shadowMenu:MenuElement({type = MENU, id = "rsettings", name = "R Settings"})
    self.shadowMenu.rsettings:MenuElement({id = "usermanual", name = "Use [R] on keydown", key = string.byte("T"), value = true, toggle = true})
    self.shadowMenu.rsettings:MenuElement({id = "usermanualdistance", name = "Max Distance willing to use [R] at", value = 0, min = 0, max = 20000})


     -- JUNGLE KILLSTEAL --
    self.shadowMenu:MenuElement({type = MENU, id = "junglekillsteal", name = "Jungle Steal"})
    self.shadowMenu.junglekillsteal:MenuElement({id = "W", name = "Use [W] in Jungle Steal", value = true, leftIcon = Icons.W})


    -- KILL STEAL --
    self.shadowMenu:MenuElement({type = MENU, id = "killsteal", name = "Kill Steal"})
    self.shadowMenu.killsteal:MenuElement({id = "killstealw", name = "Kill steal with [W]", value = true, leftIcon = Icons.W})
    self.shadowMenu.killsteal:MenuElement({id = "killstealr", name = "Kill steal with [R]", value = true, leftIcon = Icons.R})
    self.shadowMenu.killsteal:MenuElement({id = "killstealrangemax", name = "Max Distance willing to use R at", value = 0, min = 0, max = 20000})

    -- DRAWINGS --
    self.shadowMenu:MenuElement({type = MENU, id = "Drawing", name = "Draw Settings"})
    self.shadowMenu.Drawing:MenuElement({id = "draww", name = "Draw [W] Range", value = true, leftIcon = Icons.W})
    self.shadowMenu.Drawing:MenuElement({id = "drawe", name = "Draw [E] Range", value = true, leftIcon = Icons.E})
    self.shadowMenu.Drawing:MenuElement({id = "drawr", name = "Draw [R] Range", value = true, leftIcon = Icons.R})
    self.shadowMenu.Drawing:MenuElement({id = "drawrkill", name = "Draw [R] Killable Text", value = true, leftIcon = Icons.R})
    self.shadowMenu.Drawing:MenuElement({id = "drawrtoogle", name = "Draw [R] use toogle", value = true, leftIcon = Icons.R})


end


function Jinx:Draw()

    if self.shadowMenu.Drawing.drawr:Value() and Ready(_R) then
		Draw.Circle(myHero, 1500, 1, Draw.Color(255, 0, 0))
		end                                                 
		if self.shadowMenu.Drawing.drawe:Value() and Ready(_E) then
		Draw.Circle(myHero, 900, 1, Draw.Color(235, 147, 52))
		end
		if self.shadowMenu.Drawing.draww:Value() and Ready(_W) then
		Draw.Circle(myHero, 1450, 1, Draw.Color(0, 212, 250))
        end
        if self.shadowMenu.Drawing.drawrtoogle:Value() then
            Draw.Text("R Useage Toogle: ", 18, myHero.pos2D.x - 50, myHero.pos2D.y + 60, Draw.Color(255, 225, 255, 255))
                if self.shadowMenu.rsettings.usermanual:Value() then
                    Draw.Text("ON", 18, myHero.pos2D.x + 80, myHero.pos2D.y + 60, Draw.Color(255, 0, 255, 0))
                    else
                        Draw.Text("OFF", 18, myHero.pos2D.x + 80, myHero.pos2D.y + 60, Draw.Color(255, 255, 0, 0))
                end 
        end

    
    local target = TargetSelector:GetTarget(20000, 5)
    if target and IsValid(target) then
    local rdmg = getdmg("R", target, myHero)
    if self.shadowMenu.Drawing.drawrkill:Value() and Ready(_R) and target.health < rdmg then
        Draw.Text("Killable with [R]", 18, target.pos2D.x - 50, target.pos2D.y + 60, Draw.Color(255, 225, 255, 255))
    end
end


end

function Jinx:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    self:autor()
    self:autoe()
    self:killsteal()
    self:junglekillsteal()
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
    end
end

function IsImmobileTarget(unit)
	for i = 0, unit.buffCount do
		local buff = unit:GetBuff(i)
		if buff and (buff.type == 5 or buff.type == 11 or buff.type == 29 or buff.type == 24 or buff.name == "recall") and buff.count > 0 then
			return true
		end
	end
	return false	
end

function Jinx:autor()

    local target = TargetSelector:GetTarget(20000, 1)
    if target == nil then return end
    local d = myHero.pos:DistanceTo(target.pos)
    local rdmg = getdmg("R", target, myHero)
    if Ready(_R) and target and IsValid(target)then
        if self.shadowMenu.rsettings.usermanual:Value() then
            
            if (d <= self.shadowMenu.rsettings.usermanualdistance:Value()) and (target.health < rdmg) then
                print(d)
                self:CastR(target)
            end
        end    
    end 

end



function Jinx:autoe()
    local target = TargetSelector:GetTarget(self.E.Range, 1)
    if target and IsValid(target) then
    if Ready(_E) and self.shadowMenu.combo.EONCC:Value() and IsImmobileTarget(target) then
        self:CastE(target)
    end
    end
end
function Jinx:killsteal()
    local target = TargetSelector:GetTarget(self.R.Range, 1)
    if target and IsValid(target) then      
    local d = myHero.pos:DistanceTo(target.pos)
    local wdmg = getdmg("W", target, myHero)
    local rdmg = getdmg("R", target, myHero)
        if Ready(_R) and target and IsValid(target) and (target.health <= rdmg) and self.shadowMenu.killsteal.killstealr:Value() and d > 500 and d < self.shadowMenu.killsteal.killstealrangemax:Value() then
            self:CastR(target)
        end
        if Ready(_W) and target and IsValid(target) and (target.health <= wdmg) and self.shadowMenu.killsteal.killstealw:Value() then
            self:CastW(target)
        end
    end
end

function Jinx:Combo()
    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if target == nil then return end
    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenu.combo.W:Value() then
           self:CastW(target)
            --self:CastSpell(HK_Etarget)
        end														---- you have "end" forget
    end

    local target = TargetSelector:GetTarget(self.E.Range, 1)
    if target == nil then return end
    local facing = _G.PremiumPrediction:IsFacing(myHero, target, 45)
    local posBehind = myHero.pos:Extended(target.pos, target.distance + 100)
    if Ready(_E) and target and IsValid(target) then
        print(facing)
        if self.shadowMenu.combo.E:Value() and facing then
            self:CastE(target)
        end
    end
    
    local distance = target.pos:DistanceTo(myHero.pos) 
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then return end
    if Ready(_Q) and target and IsValid(target)then
        if self.shadowMenu.combo.Q:Value() then
            if distance > 615 and not self:HasSecondQ() or (distance < 615 and self:HasSecondQ()) then
                Control.CastSpell(HK_Q)
            end
        end    
    end 

end

function Jinx:junglekillsteal()
    if self.shadowMenu.junglekillsteal.W:Value() then 
        for i = 1, Game.MinionCount() do
            local obj = Game.Minion(i)
            if obj.team ~= myHero.team then
                if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                    local wdmg = getdmg("W", obj, myHero, 1)
                    if Ready(_W) and self.shadowMenu.junglekillsteal.W:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.W.Range and obj.health < wdmg) then
                        Control.CastSpell(HK_W, obj);
                    end
                end
            end
        end
    end
end

function Jinx:HasSecondQ()
    return Jinx:GotBuff(myHero, "JinxQ") > 0
end

function Jinx:GotBuff(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.name == buffname and buff.count > 0 then return buff.count end
    end
    return 0
end

function Jinx:CastW(target)
    if Ready(_W) and lastW + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.W, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_W, Pred.CastPosition)
            lastW = GetTickCount()
        end
    end
end

function Jinx:CastE(target)
    if Ready(_E) and lastE + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.E, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_E, Pred.CastPosition)
            lastE = GetTickCount()
        end
    end
end

function Jinx:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end

    --[[
    _   _   _   _   _   _   _   _   _   _  
    / \ / \ / \ / \ / \ / \ / \ / \ / \ / \ 
    ( B | L | I | T | Z | C | R | A | N | K )
    \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ 
                                                                        
    ]]

        class "Blitzcrank"
        function Blitzcrank:__init()
            
            self.Q = {Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 140, Range = 1150, Speed = 1800, Collision = true, MaxCollision = 1, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO, _G.COLLISION_YASUOWALL}}
            self.R = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 600, Range = 600, Speed = 0, Collision = false}
            

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
        
        local Icons = {
            ["BlitzIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/a/ac/Blitzcrank_OriginalSquare.png",
            ["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/e2/Rocket_Grab.png",
            ["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/a/ab/Overdrive.png",
            ["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/98/Power_Fist.png",
            ["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/a/a6/Static_Field.png",
            ["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
            ["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
            }


        function Blitzcrank:LoadMenu()
            self.shadowMenu = MenuElement({type = MENU, id = "shadowBlitzcrank", name = "Shadow Blitzcrank", leftIcon = Icons.BlitzIcon})

            -- COMBO --
            self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
            self.shadowMenu.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true, leftIcon = Icons.Q})
            self.shadowMenu.combo:MenuElement({id = "W", name = "Use W in Combo", value = true, leftIcon = Icons.W})
            self.shadowMenu.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true, leftIcon = Icons.E})
            self.shadowMenu.combo:MenuElement({id = "R", name = "Use R in  Combo", value = true, leftIcon = Icons.R})

            -- AUTO R --
            self.shadowMenu:MenuElement({type = MENU, id = "autor", name = "Auto R Settings"})
            self.shadowMenu.autor:MenuElement({id = "useautor", name = "Use auto [R]", value = true})
            self.shadowMenu.autor:MenuElement({id = "autorammount", name = "Activate [R] when x enemies around", value = 1, min = 1, max = 5, identifier = "#"})

            -- SUMMONER SETTINGS --
            self.shadowMenu:MenuElement({type = MENU, id = "SummonerSettings", name = "Summoner Settings"})

            if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
                self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true, leftIcon = Icons.IGN})
            elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
                self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true, leftIcon = Icons.IGN}) 
            end

            
            if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" then
                self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true, leftIcon = Icons.EXH})
            elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
                self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true, leftIcon = Icons.EXH}) 
            end

        end

        
        function Blitzcrank:Draw()
            
        end
        
        function Blitzcrank:Tick()
            if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
                return
            end
            self:AutoR()
            self:AutoSummoners()
            if orbwalker.Modes[0] then
                self:Combo()
            elseif orbwalker.Modes[3] then
            end
        end
        
        
        function Blitzcrank:AutoSummoners()

            -- IGNITE --
            local target = TargetSelector:GetTarget(self.Q.Range, 1)
            if target and IsValid(target) then
            local ignDmg = getdmg("IGNITE", target, myHero)
            if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and (target.health < ignDmg ) then
                Control.CastSpell(HK_SUMMONER_1, target)
            elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and (target.health < ignDmg ) then
                Control.CastSpell(HK_SUMMONER_2, target)
            end


        end


        end
        function Blitzcrank:Combo()
            local QPred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
            local target = TargetSelector:GetTarget(self.Q.Range, 1)
            if Ready(_Q) and target and IsValid(target) then
                if self.shadowMenu.combo.Q:Value() then
                    self:CastQ(target)
                end
            end
            local target = TargetSelector:GetTarget(2000, 1)
            if Ready(_W) and target and IsValid(target) then
                local d = myHero.pos:DistanceTo(target.pos)
                if self.shadowMenu.combo.W:Value() and d >= 1150 then
                    Control.KeyDown(HK_W)
                end
            end
            
            local target = TargetSelector:GetTarget(self.Q.Range, 1)
            if Ready(_E) and target and IsValid(target) then
                if self.shadowMenu.combo.E:Value() then
                    Control.CastSpell(HK_E)
                    --self:CastSpell(HK_Etarget)
                end
            end
        
        end
        
        function Blitzcrank:jungleclear()
        if self.shadowMenu.jungleclear.UseQ:Value() then 
            for i = 1, Game.MinionCount() do
                local obj = Game.Minion(i)
                if obj.team ~= myHero.team then
                    if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                        if Ready(_Q) and self.shadowMenu.jungleclear.UseQ:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < 800) then
                            Control.CastSpell(HK_Q, obj);
                        end
                        if Ready(_E) and self.shadowMenu.jungleclear.UseE:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                            Control.CastSpell(HK_E);
                        end
                        if Ready(_W) and self.shadowMenu.jungleclear.UseW:Value() and myHero:GetSpellData(_W).toogleState ~= 2 and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                            Control.KeyDown(HK_W);
                        end
                    end
                    end
                end
        end
        end

        function Blitzcrank:AutoR()

        local target = TargetSelector:GetTarget(self.R.Range, 1)
            if target and IsValid(target) then
                if self.shadowMenu.autor.useautor:Value() and CountEnemiesNear(target, 600) >= self.shadowMenu.autor.autorammount:Value() and Ready(_R) then
                    Control.CastSpell(HK_R)
                end
            end
        end

        function Blitzcrank:laneclear()
            for i = 1, Game.MinionCount() do
                local minion = Game.Minion(i)
                if minion.team ~= myHero.team then 
                    local dist = myHero.pos:DistanceTo(minion.pos)
                    if self.shadowMenu.laneclear.UseQLane:Value() and Ready(_Q) and dist <= self.Q.Range then 
                        Control.CastSpell(HK_Q, minion.pos)
                    end

                end
            end
        end
        
        function Blitzcrank:CastQ(target)
            if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
                local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
                if Pred.Hitchance >= _G.HITCHANCE_HIGH then
                    Control.CastSpell(HK_Q, Pred.CastPosition)
                    lastQ = GetTickCount()
                end
            end
        end


        
        function Blitzcrank:CastR(target)
            if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
                local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
                if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
                    Control.CastSpell(HK_R, Pred.CastPosition)
                    lastR = GetTickCount()
                end
            end
        end
--[[
        _   _   _   _  
        / \ / \ / \ / \ 
    ( N | A | M | I )
        \_/ \_/ \_/ \_/ 
]]

class "Nami"
function Nami:__init()
    
    self.Q = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 0, Range = 875, Speed = 1750, Collision = true, MaxCollision = 1, CollisionTypes = {_G.COLLISION_MINION, _G.COLLISION_ENEMYHERO, _G.COLLISION_YASUOWALL}}
    self.W = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 0, Range = 725, Speed = 1800, Collision = true, MaxCollision = 1, CollisionTypes = {_G.COLLISION_ENEMYHERO, _G.COLLISION_YASUOWALL}}
    self.E = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 800, Range = 800, Speed = 1800, Collision = false}
    self.R = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 325, Range = 2750, Speed = 1200, Collision = false}
    

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

local Icons = {
    ["NamiIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/d/dd/Nami_OriginalSquare.png",
    ["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/c/cb/Aqua_Prison.png",
    ["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/48/Ebb_and_Flow.png",
    ["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/a/a4/Tidecaller%27s_Blessing.png",
    ["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/2e/Tidal_Wave.png",
    ["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
    ["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
    }


function Nami:LoadMenu()
    self.shadowMenu = MenuElement({type = MENU, id = "shadowNami", name = "Shadow Nami", leftIcon = Icons.NamiIcon})

    -- COMBO --
    self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenu.combo:MenuElement({id = "Q", name = "Use [Q] in Combo", value = true, leftIcon = Icons.Q})
    self.shadowMenu.combo:MenuElement({id = "W", name = "Use [W] on Ally", value = true, leftIcon = Icons.W})
    self.shadowMenu.combo:MenuElement({id = "wonAlly", name = "Use [W] in Combo", value = true, leftIcon = Icons.W})
    self.shadowMenu.combo:MenuElement({id = "E", name = "Use [E] in  Combo", value = true, leftIcon = Icons.E})
    self.shadowMenu.combo:MenuElement({id = "eonAlly", name = "Use [E] on Ally", value = true, leftIcon = Icons.E})
    self.shadowMenu.combo:MenuElement({id = "R", name = "Use [R] in  Combo", value = true, leftIcon = Icons.R})

    -- AUTO R --
    self.shadowMenu:MenuElement({type = MENU, id = "autor", name = "Auto R Settings"})
    self.shadowMenu.autor:MenuElement({id = "useautor", name = "Use auto [R]", value = true})
    self.shadowMenu.autor:MenuElement({id = "autorammount", name = "Activate [R] when x enemies around", value = 1, min = 1, max = 5, identifier = "#"})

    -- SUMMONER SETTINGS --
    self.shadowMenu:MenuElement({type = MENU, id = "SummonerSettings", name = "Summoner Settings"})

    if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true, leftIcon = Icons.IGN})
    elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true, leftIcon = Icons.IGN}) 
    end

    
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true, leftIcon = Icons.EXH})
    elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true, leftIcon = Icons.EXH}) 
    end

end


function Nami:Draw()
    
end

function Nami:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    self:AutoSummoners()
    self:AutoW()
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
    end
end


function Nami:AutoSummoners()

    -- IGNITE --
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target and IsValid(target) then
    local ignDmg = getdmg("IGNITE", target, myHero)
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and (target.health < ignDmg ) then
        Control.CastSpell(HK_SUMMONER_1, target)
    elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and (target.health < ignDmg ) then
        Control.CastSpell(HK_SUMMONER_2, target)
    end


end

function Nami:AutoW()



end


end
function Nami:Combo()

    local QPred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.combo.Q:Value() then
            self:CastQ(target)
        end
    end

    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if Ready(_W) and target and IsValid(target) then               
        if self.shadowMenu.combo.W:Value() then
            Control.CastSpell(HK_W, target)
        end
    end




    
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.combo.E:Value() then
            Control.CastSpell(HK_E, myHero.pos)
            --self:CastSpell(HK_Etarget)
        end
    end

    local target = TargetSelector:GetTarget(self.R.Range, 1)
    if Ready(_R) and target and IsValid(target) then
        if self.shadowMenu.combo.R:Value() then
            self:CastR(target)
            --self:CastSpell(HK_Etarget)
        end
    end

end

function Nami:jungleclear()
if self.shadowMenu.jungleclear.UseQ:Value() then 
    for i = 1, Game.MinionCount() do
        local obj = Game.Minion(i)
        if obj.team ~= myHero.team then
            if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                if Ready(_Q) and self.shadowMenu.jungleclear.UseQ:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < 800) then
                    Control.CastSpell(HK_Q, obj);
                end
                if Ready(_E) and self.shadowMenu.jungleclear.UseE:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                    Control.CastSpell(HK_E);
                end
                if Ready(_W) and self.shadowMenu.jungleclear.UseW:Value() and myHero:GetSpellData(_W).toogleState ~= 2 and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                    Control.KeyDown(HK_W);
                end
            end
            end
        end
end
end


function Nami:laneclear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion.team ~= myHero.team then 
            local dist = myHero.pos:DistanceTo(minion.pos)
            if self.shadowMenu.laneclear.UseQLane:Value() and Ready(_Q) and dist <= self.Q.Range then 
                Control.CastSpell(HK_Q, minion.pos)
            end

        end
    end
end

function Nami:CastQ(target)
    if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_Q, Pred.CastPosition)
            lastQ = GetTickCount()
        end
    end
end



function Nami:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end

--[[
_   _   _   _  
/ \ / \ / \ / \ 
( S | O | N | A )
\_/ \_/ \_/ \_/ 
]]
class "Sona"
function Sona:__init()
    
    self.Q = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 0, Range = 825, Speed = 1500, Collision = false}
    self.W = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 0, Range = 1000, Speed = 1500, Collision = false}
    self.E = {Type = _G.SPELLTYPE_CIRCLE, Delay = 0, Radius = 0, Range = 430, Speed = 1500, Collision = false}
    self.R = {Type = _G.SPELLTYPE_LINE, Delay = 0, Radius = 140, Range = 900, Speed = 2400, Collision = true, MaxCollision = 3, CollisionTypes = {_G.COLLISION_YASUOWALL}}
    

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

local Icons = {
    ["SonaIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/fb/Sona_OriginalSquare.png",
    ["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/e1/Hymn_of_Valor.png",
    ["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/99/Aria_of_Perseverance.png",
    ["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/7/76/Song_of_Celerity.png",
    ["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/b/b1/Crescendo.png",
    ["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
    ["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
    }


function Sona:LoadMenu()
    self.shadowMenu = MenuElement({type = MENU, id = "shadowSona", name = "Shadow Sona", leftIcon = Icons.SonaIcon})

    -- COMBO --
    self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenu.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true, leftIcon = Icons.Q})
    self.shadowMenu.combo:MenuElement({id = "W", name = "Use W in Combo", value = false, leftIcon = Icons.W})
    self.shadowMenu.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true, leftIcon = Icons.E})
    self.shadowMenu.combo:MenuElement({id = "R", name = "Use R in  Combo", value = true, leftIcon = Icons.R})

    -- AUTO R --
    self.shadowMenu:MenuElement({type = MENU, id = "autor", name = "Auto R Settings"})
    self.shadowMenu.autor:MenuElement({id = "useautor", name = "Use auto [R]", value = true})
    self.shadowMenu.autor:MenuElement({id = "autorammount", name = "Activate [R] when x enemies around", value = 1, min = 1, max = 5, identifier = "#"})

    -- AUTO W -- 
    self.shadowMenu:MenuElement({type = MENU, id = "autow", name = "Auto W Settings"})
    self.shadowMenu.autow:MenuElement({id = "useautow", name = "Use auto [W] on ally?", value = true})

    -- SUMMONER SETTINGS --
    self.shadowMenu:MenuElement({type = MENU, id = "SummonerSettings", name = "Summoner Settings"})

    if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true, leftIcon = Icons.IGN})
    elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true, leftIcon = Icons.IGN}) 
    end

    
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true, leftIcon = Icons.EXH})
    elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
        self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true, leftIcon = Icons.EXH}) 
    end

end


function Sona:Draw()
    
end

function Sona:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    self:AutoR()
    self:AutoSummoners()
    self:AutoW()
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
    end
end


function Sona:AutoSummoners()

    -- IGNITE --
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target and IsValid(target) then
    local ignDmg = getdmg("IGNITE", target, myHero)
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and (target.health < ignDmg ) then
        Control.CastSpell(HK_SUMMONER_1, target)
    elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and (target.health < ignDmg ) then
        Control.CastSpell(HK_SUMMONER_2, target)
    end


end

function Sona:AutoW()
local target = TargetSelector:GetTarget(800)     	
if target == nil then return end	

if self.shadowMenu.autow.useautow:Value() and Ready(_W) then
    for i, ally in pairs(GetAllyHeroes()) do
        if self.shadowMenu.autow.useautow:Value() and IsValid(ally,1000) and myHero.pos:DistanceTo(ally.pos) <= 1000 and ally.health < ally.maxHealth then
            Control.CastSpell(HK_W, ally)
        end
    end
end
end


end
function Sona:Combo()
    local QPred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.combo.Q:Value() then
            self:CastQ(target)
        end
    end
    local target = TargetSelector:GetTarget(2000, 1)
    if Ready(_W) and target and IsValid(target) then
        local d = myHero.pos:DistanceTo(target.pos)
        if self.shadowMenu.combo.W:Value() and d >= 1150 then
            Control.KeyDown(HK_W)
        end
    end
    
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.combo.E:Value() then
            Control.CastSpell(HK_E)
            --self:CastSpell(HK_Etarget)
        end
    end

end

function Sona:jungleclear()
if self.shadowMenu.jungleclear.UseQ:Value() then 
    for i = 1, Game.MinionCount() do
        local obj = Game.Minion(i)
        if obj.team ~= myHero.team then
            if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                if Ready(_Q) and self.shadowMenu.jungleclear.UseQ:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < 800) then
                    Control.CastSpell(HK_Q, obj);
                end
                if Ready(_E) and self.shadowMenu.jungleclear.UseE:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                    Control.CastSpell(HK_E);
                end
                if Ready(_W) and self.shadowMenu.jungleclear.UseW:Value() and myHero:GetSpellData(_W).toogleState ~= 2 and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                    Control.KeyDown(HK_W);
                end
            end
            end
        end
end
end

function Sona:AutoR()
local target = TargetSelector:GetTarget(self.R.Range, 1)
    if target and IsValid(target) then
        if self.shadowMenu.autor.useautor:Value() and CountEnemiesNear(target, 900) >= self.shadowMenu.autor.autorammount:Value() and Ready(_R) then
            self:CastR(target)
        end
    end
end

function Sona:laneclear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion.team ~= myHero.team then 
            local dist = myHero.pos:DistanceTo(minion.pos)
            if self.shadowMenu.laneclear.UseQLane:Value() and Ready(_Q) and dist <= self.Q.Range then 
                Control.CastSpell(HK_Q, minion.pos)
            end

        end
    end
end

function Sona:CastQ(target)
    if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_Q, Pred.CastPosition)
            lastQ = GetTickCount()
        end
    end
end



function Sona:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end
--[[
_   _   _   _   _  
/ \ / \ / \ / \ / \ 
( B | R | A | U | M )
\_/ \_/ \_/ \_/ \_/ 
]]
class "Braum"
function Braum:__init()

self.Q = {Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 1000, Speed = 1100, Collision = true, MaxCollision = 1, CollisionTypes = {_G.COLLISION_YASUOWALL, _G.COLLISION_MINION, _G.COLLISION_ENEMYHERO}}
self.R = {Type = _G.SPELLTYPE_LINE, Delay = 0, Radius = 80, Range = 1250, Speed = 1200, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_YASUOWALL}}


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

local Icons = {
["BraumIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/28/Braum_OriginalSquare.png",
["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/c/c2/Winter%27s_Bite.png",
["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/91/Stand_Behind_Me.png",
["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/e/ef/Unbreakable.png",
["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/44/Glacial_Fissure.png",
["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
}


function Braum:LoadMenu()
self.shadowMenu = MenuElement({type = MENU, id = "shadowBraum", name = "Shadow Braum", leftIcon = Icons.BraumIcon})

-- COMBO --
self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
self.shadowMenu.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true, leftIcon = Icons.Q})
self.shadowMenu.combo:MenuElement({id = "W", name = "Use W in Combo", value = false, leftIcon = Icons.W})
self.shadowMenu.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true, leftIcon = Icons.E})
self.shadowMenu.combo:MenuElement({id = "R", name = "Use R in  Combo", value = true, leftIcon = Icons.R})
self.shadowMenu.combo:MenuElement({id = "userammount", name = "Activate [R] when x enemies around", value = 1, min = 1, max = 5, identifier = "#"})

-- AUTO R --
self.shadowMenu:MenuElement({type = MENU, id = "autor", name = "Auto R Settings"})
self.shadowMenu.autor:MenuElement({id = "useautor", name = "Use auto [R]", value = true})
self.shadowMenu.autor:MenuElement({id = "autorammount", name = "Activate [R] when x enemies around", value = 1, min = 1, max = 5, identifier = "#"})

-- AUTO W -- 
self.shadowMenu:MenuElement({type = MENU, id = "autow", name = "Auto Jump on Ally Settings"})
self.shadowMenu.autow:MenuElement({id = "useautow", name = "Use auto [W] and [E] on ally?", value = true})
self.shadowMenu.autow:MenuElement({id = "useautowhp", name = "Use auto [W] and [E] on ally hp %", value = 30, min = 0, max = 100, identifier = "%"})

-- DRAWING SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "drawings", name = "Drawing Settings"})
self.shadowMenu.drawings:MenuElement({id = "drawAutoR", name = "Draw if auto [R] is on", value = true})
self.shadowMenu.drawings:MenuElement({id = "drawAutoWE", name = "Draw if auto [W] and [E] on Ally is on", value = true})


-- SUMMONER SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "SummonerSettings", name = "Summoner Settings"})
if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true, leftIcon = Icons.IGN})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true, leftIcon = Icons.IGN}) 
end

if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true, leftIcon = Icons.EXH})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true, leftIcon = Icons.EXH}) 
end

end


function Braum:Draw()

if self.shadowMenu.drawings.drawAutoR:Value() then
    Draw.Text("Auto Cast R: ", 15, 5, 30, Draw.Color(255, 225, 255, 0))
        if self.shadowMenu.autor.useautor:Value() then
            Draw.Text("ON", 15, 85, 30, Draw.Color(255, 0, 255, 0))
            else
                Draw.Text("OFF", 15, 85, 30, Draw.Color(255, 255, 0, 0))
        end 
end

if self.shadowMenu.drawings.drawAutoWE:Value() then
    Draw.Text("Auto Jump on Ally: ", 15, 5, 60, Draw.Color(255, 225, 255, 0))
        if self.shadowMenu.autow.useautow:Value() then
            Draw.Text("ON", 15, 115, 60, Draw.Color(255, 0, 255, 0))
            else
            Draw.Text("OFF", 15, 115, 60, Draw.Color(255, 255, 0, 0))
        end 
end

end

function Braum:Tick()
if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
    return
end
self:AutoR()
self:AutoSummoners()
self:AutoW()
if orbwalker.Modes[0] then
    self:Combo()
elseif orbwalker.Modes[3] then
end
end


function Braum:AutoSummoners()

-- IGNITE --
local target = TargetSelector:GetTarget(self.Q.Range, 1)
if target and IsValid(target) then
local ignDmg = getdmg("IGNITE", target, myHero)
if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and (target.health < ignDmg ) then
    Control.CastSpell(HK_SUMMONER_1, target)
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and (target.health < ignDmg ) then
    Control.CastSpell(HK_SUMMONER_2, target)
end


end

function Braum:AutoW()
local target = TargetSelector:GetTarget(800)     	
if target == nil then return end	

if self.shadowMenu.autow.useautow:Value() and Ready(_W) then
for i, ally in pairs(GetAllyHeroes()) do
    if self.shadowMenu.autow.useautow:Value() and IsValid(ally,1000) and myHero.pos:DistanceTo(ally.pos) <= 1000 and ally.health / ally.maxHealth < self.shadowMenu.autow.useautowhp:Value() / 100 then
        Control.CastSpell(HK_W, ally)
        Control.KeyDown(HK_E)
    end
end
end
end


end
function Braum:Combo()
local QPred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
local target = TargetSelector:GetTarget(self.Q.Range, 1)
if Ready(_Q) and target and IsValid(target) then
    if self.shadowMenu.combo.Q:Value() then
        self:CastQ(target)
    end
end
local target = TargetSelector:GetTarget(2000, 1)
if Ready(_W) and target and IsValid(target) then
    local d = myHero.pos:DistanceTo(target.pos)
    if self.shadowMenu.combo.W:Value() and d >= 1150 then
        Control.KeyDown(HK_W)
    end
end

local target = TargetSelector:GetTarget(self.Q.Range, 1)
if Ready(_E) and target and IsValid(target) then
    if self.shadowMenu.combo.E:Value() then
        Control.CastSpell(HK_E)
        --self:CastSpell(HK_Etarget)
    end
end

local target = TargetSelector:GetTarget(self.R.Range, 1)
if target and IsValid(target) then
    if self.shadowMenu.combo.R:Value() and CountEnemiesNear(target, 1250) >= self.shadowMenu.combo.userammount:Value() and Ready(_R) then
        self:CastR(target)
    end
end

end

function Braum:jungleclear()
if self.shadowMenu.jungleclear.UseQ:Value() then 
for i = 1, Game.MinionCount() do
    local obj = Game.Minion(i)
    if obj.team ~= myHero.team then
        if obj ~= nil and obj.valid and obj.visible and not obj.dead then
            if Ready(_Q) and self.shadowMenu.jungleclear.UseQ:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < 800) then
                Control.CastSpell(HK_Q, obj);
            end
            if Ready(_E) and self.shadowMenu.jungleclear.UseE:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                Control.CastSpell(HK_E);
            end
            if Ready(_W) and self.shadowMenu.jungleclear.UseW:Value() and myHero:GetSpellData(_W).toogleState ~= 2 and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                Control.KeyDown(HK_W);
            end
        end
        end
    end
end
end

function Braum:AutoR()
local target = TargetSelector:GetTarget(self.R.Range, 1)
if target and IsValid(target) then
    if self.shadowMenu.autor.useautor:Value() and CountEnemiesNear(target, 1250) >= self.shadowMenu.autor.autorammount:Value() and Ready(_R) then
        self:CastR(target)
    end
end
end


function Braum:CastQ(target)
if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
    local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
    if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
        Control.CastSpell(HK_Q, Pred.CastPosition)
        lastQ = GetTickCount()
    end
end
end



function Braum:CastR(target)
if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
    local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
    if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
        Control.CastSpell(HK_R, Pred.CastPosition)
        lastR = GetTickCount()
    end
end
end
--[[
_   _   _   _   _  
/ \ / \ / \ / \ / \ 
( T | A | R | I | C )
\_/ \_/ \_/ \_/ \_/ 
]]
class "Leona"
function Leona:__init()

self.Q = {Type = _G.SPELLTYPE_CIRCLE, Range = 100}
self.W = {Type = _G.SPELLTYPE_CIRCLE, Delay = 3, Range = 450, Speed = 828.5}
self.E = {Type = _G.SPELLTYPE_CIRCLE, Range = 1200, Speed = 20}
self.R = {Type = _G.SPELLTYPE_LINE, Delay = 0, Radius = 80, Range = 1250, Speed = 1200, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_YASUOWALL}}


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

local Icons = {
["LeonaIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/b/ba/Leona_OriginalSquare.png",
["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/c/c6/Shield_of_Daybreak.png",
["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/c/c5/Eclipse.png",
["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/91/Zenith_Blade.png",
["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/5/5c/Solar_Flare.png",
["EXH"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png",
["IGN"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/Ignite.png"
}


function Leona:LoadMenu()
self.shadowMenu = MenuElement({type = MENU, id = "shadowLeona", name = "Shadow Leona", leftIcon = Icons.LeonaIcon})

-- COMBO --
self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
self.shadowMenu.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true, leftIcon = Icons.Q})
self.shadowMenu.combo:MenuElement({id = "W", name = "Use W in Combo", value = false, leftIcon = Icons.W})
self.shadowMenu.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true, leftIcon = Icons.E})
self.shadowMenu.combo:MenuElement({id = "R", name = "Use R in  Combo", value = true, leftIcon = Icons.R})
self.shadowMenu.combo:MenuElement({id = "userammount", name = "Activate [R] when x enemies hit", value = 1, min = 1, max = 5, identifier = "#"})

-- AUTO R --
self.shadowMenu:MenuElement({type = MENU, id = "autor", name = "Auto R Settings"})
self.shadowMenu.autor:MenuElement({id = "useautor", name = "Use auto [R]", value = true})
self.shadowMenu.autor:MenuElement({id = "autorammount", name = "Activate [R] when x enemies hit", value = 1, min = 1, max = 5, identifier = "#"})


-- DRAWING SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "drawings", name = "Drawing Settings"})
self.shadowMenu.drawings:MenuElement({id = "drawAutoR", name = "Draw if auto [R] is on", value = true})


-- SUMMONER SETTINGS --
self.shadowMenu:MenuElement({type = MENU, id = "SummonerSettings", name = "Summoner Settings"})
if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true, leftIcon = Icons.IGN})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseIgnite", name = "Use [Ignite] if killable?", value = true, leftIcon = Icons.IGN}) 
end

if myHero:GetSpellData(SUMMONER_1).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true, leftIcon = Icons.EXH})
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerExhaust" then
    self.shadowMenu.SummonerSettings:MenuElement({id = "UseExhaust", name = "Use [Exhaust] on engage?", value = true, leftIcon = Icons.EXH}) 
end

end


function Leona:Draw()

if self.shadowMenu.drawings.drawAutoR:Value() then
    Draw.Text("Auto Cast R: ", 15, 5, 30, Draw.Color(255, 225, 255, 0))
        if self.shadowMenu.autor.useautor:Value() then
            Draw.Text("ON", 15, 85, 30, Draw.Color(255, 0, 255, 0))
            else
                Draw.Text("OFF", 15, 85, 30, Draw.Color(255, 255, 0, 0))
        end 
end

end

function Leona:Tick()
if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
    return
end
self:AutoR()
self:AutoSummoners()
if orbwalker.Modes[0] then
    self:Combo()
elseif orbwalker.Modes[3] then
end
end


function Leona:AutoSummoners()

-- IGNITE --
local target = TargetSelector:GetTarget(self.Q.Range, 1)
if target and IsValid(target) then
local ignDmg = getdmg("IGNITE", target, myHero)
if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and (target.health < ignDmg ) then
    Control.CastSpell(HK_SUMMONER_1, target)
elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and (target.health < ignDmg ) then
    Control.CastSpell(HK_SUMMONER_2, target)
end
end


end
function Leona:Combo()
local EPred = GamsteronPrediction:GetPrediction(target, self.E, myHero)
local target = TargetSelector:GetTarget(self.E.Range, 1)
if Ready(_E) and target and IsValid(target) then
    if self.shadowMenu.combo.E:Value() then
        self:CastE(target)
    end
end
local target = TargetSelector:GetTarget(self.Q.Range, 1)
if Ready(_Q) and target and IsValid(target) then
    if self.shadowMenu.combo.Q:Value() then
        Control.KeyDown(HK_Q)
    end
end

local target = TargetSelector:GetTarget(self.W.Range, 1)
if Ready(_W) and target and IsValid(target) then
    if self.shadowMenu.combo.W:Value() then
        Control.CastSpell(HK_W)
        --self:CastSpell(HK_Etarget)
    end
end

local target = TargetSelector:GetTarget(self.R.Range, 1)
if target and IsValid(target) then
    if self.shadowMenu.combo.R:Value() and CountEnemiesNear(target, 1250) >= self.shadowMenu.combo.userammount:Value() and Ready(_R) then
        self:CastR(target)
    end
end

end

function Leona:jungleclear()
if self.shadowMenu.jungleclear.UseQ:Value() then 
for i = 1, Game.MinionCount() do
    local obj = Game.Minion(i)
    if obj.team ~= myHero.team then
        if obj ~= nil and obj.valid and obj.visible and not obj.dead then
            if Ready(_Q) and self.shadowMenu.jungleclear.UseQ:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < 800) then
                Control.CastSpell(HK_Q, obj);
            end
            if Ready(_E) and self.shadowMenu.jungleclear.UseE:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                Control.CastSpell(HK_E);
            end
            if Ready(_W) and self.shadowMenu.jungleclear.UseW:Value() and myHero:GetSpellData(_W).toogleState ~= 2 and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and obj.pos:DistanceTo(myHero.pos) < 800 then
                Control.KeyDown(HK_W);
            end
        end
        end
    end
end
end

function Leona:AutoR()
local target = TargetSelector:GetTarget(self.R.Range, 1)
if target and IsValid(target) then
    if self.shadowMenu.autor.useautor:Value() and CountEnemiesNear(target, 1250) >= self.shadowMenu.autor.autorammount:Value() and Ready(_R) then
        self:CastR(target)
    end
end
end

function Leona:CastE(target)
if Ready(_E) and lastE + 350 < GetTickCount() and orbwalker:CanMove() then
    local Pred = GamsteronPrediction:GetPrediction(target, self.E, myHero)
    if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
        Control.CastSpell(HK_E, Pred.CastPosition)
        lastE = GetTickCount()
    end
end
end


function Leona:CastR(target)
if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
    local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
    if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
        Control.CastSpell(HK_R, Pred.CastPosition)
        lastR = GetTickCount()
    end
end
end

