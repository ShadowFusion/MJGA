
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
    
    local Version = 0.01
    
    local Files = {
        Lua = {
            Path = SCRIPT_PATH,
            Name = "Camille.lua",
            Url = "https://raw.githubusercontent.com/ShadowFusion/MJGA/master/Camille.lua"
        },
        Version = {
            Path = SCRIPT_PATH,
            Name = "Camille.version",
            Url = "https://raw.githubusercontent.com/ShadowFusion/MJGA/master/Camille.version"    -- check if Raw Adress correct pls.. after you have create the version file on Github
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
            print("New Series Shadow Vers. Press 2x F6")
        else
            print(Files.Version.Name .. ": No Updates Found")
        end
    
    end
    
    AutoUpdate()

end

local Champions = {
    ["Camille"] = true,
}

--Checking Champion 
if Champions[myHero.charName] == nil then
    print('Series Shadow does not support ' .. myHero.charName) return
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

local function ValidTarget(unit, range)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        if range then
            if (unit.pos:DistanceTo(myHero.pos) < range) then
                return true;
            end
        else
            return true
        end
    end
    return false;
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


local Heroes = {"Camille"}
if not table.contains(Heroes, myHero.charName) then return end
        
class "Camille"

function Camille:__init()
    
    self.Q = {Type = _G.SPELLTYPE_CIRCLE, Range = 325, Speed = 20, Collision = false}
    self.W = {Type = _G.SPELLTYPE_CONE, Range = 610, Radius = 100, Speed = 1750, Collision = false}
    self.E = {Type = _G.SPELLTYPE_CIRCLE, Range = 800, Speed = 500}
    self.R = {Type = _G.SPELLTYPE_CIRCLE, Range = 475, Speed = 1200}

    

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
    ["CamilleIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/0/0d/Camille_OriginalSquare.png",
    ["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/4/4c/Precision_Protocol.png",
    ["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/6/64/Tactical_Sweep.png",
    ["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/2/24/Hookshot.png",
    ["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/f/f4/The_Hextech_Ultimatum.png",
    ["EXH"] = "https://vignette2.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png"
    }

function Camille:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "SeriesShadowCamille", name = "Series Shadow Camille", leftIcon = Icons["CamilleIcon"]})


    -- Q --
    self.Menu:MenuElement({type = MENU, id = "Q", name = "Q"})
    self.Menu.Q:MenuElement({id = "QCombo", name = "Use [Q] in combo", value = true, leftIcon = Icons.Q})
    self.Menu.Q:MenuElement({id = "QHarass", name = "Use [Q] in harass", value = true, leftIcon = Icons.Q})
    self.Menu.Q:MenuElement({id = "QAuto", name = "Use [Q] in auto", value = true, leftIcon = Icons.Q})

    -- W --
    self.Menu:MenuElement({type = MENU, id = "W", name = "W"})
    self.Menu.W:MenuElement({id = "WCombo", name = "Use [W] in combo", value = true, leftIcon = Icons.W})
    self.Menu.W:MenuElement({id = "WHarass", name = "Use [W] in harass", value = true, leftIcon = Icons.W})
    self.Menu.W:MenuElement({id = "WAuto", name = "Use [W] in auto", value = true, leftIcon = Icons.W})

    -- E --
    self.Menu:MenuElement({type = MENU, id = "E", name = "E"})
    self.Menu.E:MenuElement({id = "ECombo", name = "Use [E] in combo", value = true, leftIcon = Icons.E})
    self.Menu.E:MenuElement({id = "EHarass", name = "Use [E] in harass", value = true, leftIcon = Icons.E})
    self.Menu.E:MenuElement({id = "EAuto", name = "Use [E] in auto", value = true, leftIcon = Icons.E})

    -- R --
    self.Menu:MenuElement({type = MENU, id = "R", name = "R"})
    self.Menu.E:MenuElement({id = "RCombo", name = "Use [E] in combo", value = true, leftIcon = Icons.E})
    self.Menu.E:MenuElement({id = "RHarass", name = "Use [E] in harass", value = true, leftIcon = Icons.E})
    self.Menu.E:MenuElement({id = "RAuto", name = "Use [E] in auto", value = true, leftIcon = Icons.E})

end


function Camille:Draw()
--[[
    local target = TargetSelector:GetTarget(20000, 5)
    if target and IsValid(target) then
    local rdmg = getdmg("R", target, myHero)
    if self.shadowMenu.Drawing.drawrkill:Value() and Ready(_R) and target.health < rdmg then
        Draw.Text("Killable with [R]", 18, target.pos2D.x, target.pos2D.y + 50, Draw.Color(255, 225, 255, 255))
    end
    ]]
end

function Camille:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    self:Logic()
end



function Camille:Logic()
    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if target == nil then return end
    if self:CanCast(_W, 0) and ValidTarget(target, self.W.Range)  then
        self:CastW(target)
    end

    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then return end
    if self:CanCast(_Q, 0) and ValidTarget(target, self.Q.Range)  then
        Control.CastSpell(HK_Q)
    end
end

function Camille:CastW(target)
    if Ready(_W) and lastW + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.W, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_W, Pred.CastPosition)
            lastW = GetTickCount()
        end
    end
end

function Camille:CastE(target)
    if Ready(_E) and lastE + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.E, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_E, Pred.CastPosition)
            lastE = GetTickCount()
        end
    end
end

function Camille:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end

function Camille:CanCast(spell, mode)
    if spell == _Q then
        if Ready(spell) and mode == 0 and self.Menu.Q.QCombo:Value() then
            return true
        end
        if Ready(spell) and mode == 1 and self.Menu.Q.QHarass:Value()then
            return true
        end
        if Ready(spell) and mode == 10 and self.Menu.Q.QAuto:Value()then
            return true
        end
    end

    if spell == _W then
        if Ready(spell) and mode == 0 and self.Menu.W.WCombo:Value() then
            return true
        end
        if Ready(spell) and mode == 1 and self.Menu.W.WHarass:Value()then
            return true
        end
        if Ready(spell) and mode == 10 and self.Menu.W.WAuto:Value()then
            return true
        end
    end

    if spell == _E then
        if Ready(spell) and mode == 0 and self.Menu.E.ECombo:Value() then
            return true
        end
        if Ready(spell) and mode == 1 and self.Menu.E.EHarass:Value()then
            return true
        end
        if Ready(spell) and mode == 10 and self.Menu.E.EAuto:Value()then
            return true
        end
    end

    if spell == _R then
        if Ready(spell) and mode == 0 and self.Menu.R.RCombo:Value() then
            return true
        end
        if Ready(spell) and mode == 1 and self.Menu.R.RHarass:Value()then
            return true
        end
        if Ready(spell) and mode == 10 and self.Menu.R.RAuto:Value()then
            return true
        end
    end
    return false
end
