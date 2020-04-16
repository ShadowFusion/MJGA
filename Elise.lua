
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
            Name = "Elise.lua",
            Url = "https://raw.githubusercontent.com/ShadowFusion/MJGA/master/Elise.lua"
        },
        Version = {
            Path = SCRIPT_PATH,
            Name = "Elise.version",
            Url = "https://raw.githubusercontent.com/ShadowFusion/MJGA/master/Elise.version"    -- check if Raw Adress correct pls.. after you have create the version file on Github
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
    ["Elise"] = true,
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

function GetCastLevel(unit, slot)
	return unit:GetSpellData(slot).level == 0 and 1 or unit:GetSpellData(slot).level
end

local function GetStatsByRank(slot1, slot2, slot3, spell)
	local slot1 = 0
    local slot2 = 0
    local slot3 = 0
	return (({slot1, slot2, slot3})[myHero:GetSpellData(spell).level or 1])
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

function IsFacing(unit)
    local V = Vector((unit.pos - myHero.pos))
    local D = Vector(unit.dir)
    local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
    if math.abs(Angle) < 80 then 
        return true  
    end
    return false
end


local Heroes = {"Elise"}
if not table.contains(Heroes, myHero.charName) then return end
        
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
