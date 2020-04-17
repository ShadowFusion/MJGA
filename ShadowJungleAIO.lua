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

-- [ AutoUpdate ] --
do
    
    local Version = 0.1
    
    local Files = {
        Lua = {
            Path = SCRIPT_PATH,
            Name = "ShadowAIO.lua",
            Url = "https://raw.githubusercontent.com/ShadowFusion/MJGA/master/ShadowJungleAIO.lua"
        },
        Version = {
            Path = SCRIPT_PATH,
            Name = "ShadowAIO.version",
            Url = "https://raw.githubusercontent.com/ShadowFusion/MJGA/master/ShadowJungleAIO.version"    -- check if Raw Adress correct pls.. after you have create the version file on Github
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

local Champions = {
    ["MasterYi"] = true,
    ["LeeSin"] = true,
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
    require('damagelib')

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



--[[
   _   _   _   _   _   _   _   _  
  / \ / \ / \ / \ / \ / \ / \ / \ 
 ( M | a | s | t | e | r | Y | i )
  \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/  
                                                                    
]]
local Heroes = {"MasterYi"}
if not table.contains(Heroes, myHero.charName) then return end
        
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

local Heroes = {"LeeSin"}
if not table.contains(Heroes, myHero.charName) then return end
        
class "LeeSin"
function LeeSin:__init()
    
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


function LeeSin:Draw()

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

function LeeSin:Tick()
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

function LeeSin:autoW()
  	
        if self.shadowMenu.autow.usew:Value() and Ready(_W) then
            if myHero.health/myHero.maxHealth <= self.shadowMenu.autow.usewhealth:Value()/100 then
                Control.CastSpell(HK_W)
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
                    if Ready(_E) and self.shadowMenu.jungleclear.usee:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
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
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_Q, Pred.CastPosition)
            lastQ = GetTickCount()
        end
    end
end
