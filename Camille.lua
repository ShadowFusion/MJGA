
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
    
    local Version = 0.10
    
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

local function CanCast(spell, mode)
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


local Heroes = {"Camille"}
if not table.contains(Heroes, myHero.charName) then return end
        
class "Camille"
function Camille:__init()
    
    self.Q = {Type = _G.SPELLTYPE_CIRCLE, Radius = 150}
    self.W = {Type = _G.SPELLTYPE_LINE, Range = 1450, Radius = 40.25, Speed = 3200, Collision = true, MaxCollision = 1, CollisionTypes = {_G.COLLISION_YASUOWALL, _G.COLLISION_MINION}}
    self.E = {Type = _G.SPELLTYPE_CIRCLE, Range = 900, Radius = 50}
    self.R = {Type = _G.SPELLTYPE_CIRCLE, Range = 20000, Radius = 225, Speed = 1500, Collision = true, MaxCollision = 1, CollisionTypes = {2, 3}}

    

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

    if self.shadowMenu.Drawing.drawr:Value() and Ready(_R) then
		Draw.Circle(myHero, 1500, 1, Draw.Color(255, 0, 0))
		end                                                 
		if self.shadowMenu.Drawing.drawe:Value() and Ready(_E) then
		Draw.Circle(myHero, 900, 1, Draw.Color(235, 147, 52))
		end
		if self.shadowMenu.Drawing.draww:Value() and Ready(_W) then
		Draw.Circle(myHero, 1450, 1, Draw.Color(0, 212, 250))
        end

    
    local target = TargetSelector:GetTarget(20000, 5)
    if target and IsValid(target) then
    local rdmg = getdmg("R", target, myHero)
    if self.shadowMenu.Drawing.drawrkill:Value() and Ready(_R) and target.health < rdmg then
        Draw.Text("Killable with [R]", 18, target.pos2D.x, target.pos2D.y + 50, Draw.Color(255, 225, 255, 255))
    end
end


end

function Camille:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    self:autoe()
    self:killsteal()
    self:junglekillsteal()
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
    end
end

function Camille:autoe()
    local target = TargetSelector:GetTarget(self.E.Range, 1)
    if target and IsValid(target) then
    if Ready(_E) and self.shadowMenu.combo.EONCC:Value() and IsImmobileTarget(target) then
        self:CastE(target)

    end
    end
end
function Camille:killsteal()
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

function Camille:Combo()
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
    local posBehind = myHero.pos:Extended(target.pos, target.distance + 100)
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.combo.E:Value() then
            self:CastE(target)
            --self:CastSpell(HK_Etarget)
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

function Camille:junglekillsteal()
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

function Camille:HasSecondQ()
    return Camille:GotBuff(myHero, "CamilleQ") > 0
end

function Camille:GotBuff(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.name == buffname and buff.count > 0 then return buff.count end
    end
    return 0
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
