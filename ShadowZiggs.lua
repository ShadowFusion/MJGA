local Heroes = {"Ziggs"}

if not table.contains(Heroes, myHero.charName) then return end

if not FileExist(COMMON_PATH .. "GamsteronPrediction.lua") then
	print("GsoPred. installed Press 2x F6")
	DownloadFileAsync("https://raw.githubusercontent.com/gamsteron/GOS-EXT/master/Common/GamsteronPrediction.lua", COMMON_PATH .. "GamsteronPrediction.lua", function() end)
	while not FileExist(COMMON_PATH .. "GamsteronPrediction.lua") do end
end
    
require('GamsteronPrediction')


if not FileExist(COMMON_PATH .. "PussyDamageLib.lua") then
	print("PussyDamageLib. installed Press 2x F6")
	DownloadFileAsync("https://raw.githubusercontent.com/Pussykate/GoS/master/PussyDamageLib.lua", COMMON_PATH .. "PussyDamageLib.lua", function() end)
	while not FileExist(COMMON_PATH .. "PussyDamageLib.lua") do end
end
    
require('PussyDamageLib')

local isLoaded = false
function TryLoad()
	if Game.Timer() < 30 then return end
	isLoaded = true	
	if table.contains(Heroes, myHero.charName) then
		_G[myHero.charName]()
	end	
end

function OnLoad()
	Start()
end

class "Start"

function Start:__init()
	Callback.Add("Draw", function() self:Draw() end)
end

function Start:Draw()
local textPos = myHero.dir	
	if not isLoaded then
		TryLoad()
		Draw.Text("Ziggs Menu appear 30Sec Ingame", 30, textPos.x + 600, textPos.y + 100, Draw.Color(255, 255, 0, 0))
	return end

end

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
            Name = "Ziggs.lua",
            Url = "https://raw.githubusercontent.com/ShadowFusion/MJGA/master/ShadowZiggs.lua"
        },
        Version = {
            Path = SCRIPT_PATH,
            Name = "Ziggs.version",
            Url = "https://raw.githubusercontent.com/ShadowFusion/MJGA/master/ShadowZiggs.version"    -- check if Raw Adress correct pls.. after you have create the version file on Github
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
        
class "Ziggs"

function Ziggs:__init()
 
	orbwalker = _G.SDK.Orbwalker
    TargetSelector = _G.SDK.TargetSelector	
	self:LoadMenu() 
    self.Q = {Type = _G.SPELLTYPE_CIRCLE, Range = 1400, Radius = 75, Speed = 1700}
    self.W = {Type = _G.SPELLTYPE_CIRCLE, Range = 1000, Radius = 325}
    self.E = {Type = _G.SPELLTYPE_CIRCLE, Range = 900, Radius = 325}
    self.R = {Type = _G.SPELLTYPE_CIRCLE, Range = 5000, Radius = 500, Speed = 1750}

    

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
    ["ZiggsIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/7/72/Ziggs_OriginalSquare.png",
    ["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/5/5d/Bouncing_Bomb.png",
    ["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/3/35/Satchel_Charge.png",
    ["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/3/3a/Hexplosive_Minefield.png",
    ["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/1/11/Mega_Inferno_Bomb.png",
    ["EXH"] = "https://vignette2.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png"
    }

function Ziggs:LoadMenu()
    self.shadowMenu = MenuElement({type = MENU, id = "shadowZiggs", name = "Shadow Ziggs", leftIcon = Icons["ZiggsIcon"]})


    -- COMBO --
    self.shadowMenu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.shadowMenu.combo:MenuElement({id = "Q", name = "Use Q in Combo", value = true, leftIcon = Icons.Q})
    self.shadowMenu.combo:MenuElement({id = "W", name = "Use W in Combo", value = true, leftIcon = Icons.W})
    self.shadowMenu.combo:MenuElement({id = "E", name = "Use E in  Combo", value = true, leftIcon = Icons.E})

    -- JUNGLE CLEAR --
    self.shadowMenu:MenuElement({type = MENU, id = "jungleclear", name = "Jungle Clear"})
    self.shadowMenu.jungleclear:MenuElement({id = "Q", name = "Use Q in Jungle Clear", value = true, leftIcon = Icons.Q})
    self.shadowMenu.jungleclear:MenuElement({id = "W", name = "Use W in Jungle Clear", value = true, leftIcon = Icons.W})
    self.shadowMenu.jungleclear:MenuElement({id = "E", name = "Use E in Jungle Clear", value = true, leftIcon = Icons.E})

     -- JUNGLE KILLSTEAL --
    self.shadowMenu:MenuElement({type = MENU, id = "junglekillsteal", name = "Jungle Steal"})
    self.shadowMenu.junglekillsteal:MenuElement({id = "Q", name = "Use Q in Jungle Steal", value = true, leftIcon = Icons.Q})
    self.shadowMenu.junglekillsteal:MenuElement({id = "W", name = "Use W in Jungle Steal", value = true, leftIcon = Icons.W})
    self.shadowMenu.junglekillsteal:MenuElement({id = "E", name = "Use E in Jungle Steal", value = true, leftIcon = Icons.E})

        -- JUNGLE CLEAR --
        self.shadowMenu:MenuElement({type = MENU, id = "laneclear", name = "Jungle Clear"})
        self.shadowMenu.laneclear:MenuElement({id = "UseQLane", name = "Use Q in Jungle Clear", value = true, leftIcon = Icons.Q})
        self.shadowMenu.laneclear:MenuElement({id = "UseELane", name = "Use E in Jungle Clear", value = true, leftIcon = Icons.E})
        self.shadowMenu.laneclear:MenuElement({id = "UseWLane", name = "Use W in Jungle Clear", value = true, leftIcon = Icons.W})

    -- KILL STEAL --
    self.shadowMenu:MenuElement({type = MENU, id = "killsteal", name = "Kill Steal"})
    self.shadowMenu.killsteal:MenuElement({id = "killstealq", name = "Kill steal with Q", value = true, leftIcon = Icons.Q})
    self.shadowMenu.killsteal:MenuElement({id = "killsteale", name = "Kill steal with E", value = true, leftIcon = Icons.E})
    self.shadowMenu.killsteal:MenuElement({id = "killstealw", name = "Kill steal with W", value = true, leftIcon = Icons.W})
    self.shadowMenu.killsteal:MenuElement({id = "killstealr", name = "Kill steal with R", value = true, leftIcon = Icons.R})
    self.shadowMenu.killsteal:MenuElement({id = "killstealamount", name = "Ammount of people in R range to ", value = 600, min = 1000, max = 5000, identifier = "%"})

end

function Ziggs:Draw()
    
end

function Ziggs:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    self:killsteal()
    self:junglekillsteal()
    if orbwalker.Modes[0] then
        self:Combo()
    elseif orbwalker.Modes[3] then
        self:jungleclear()
        self:laneclear()
    end
end

function Ziggs:killsteal()
    local target = TargetSelector:GetTarget(self.R.Range, 1)
    if target and IsValid(target) then       
    local qdmg = getdmg("Q", target, myHero)
    local edmg = getdmg("E", target, myHero)
    local wdmg = getdmg("W", target, myHero)
    local rdmg = getdmg("R", target, myHero)
        if Ready(_R) and target and IsValid(target) and (target.health <= rdmg) and self.shadowMenu.killsteal.killstealr:Value() then
            self:CastR(target)
        end
        if Ready(_W) and target and IsValid(target) and (target.health <= wdmg) and self.shadowMenu.killsteal.killstealw:Value() then
            self:CastW(target)
        end
        if Ready(_E) and target and IsValid(target) and (target.health <= edmg) and self.shadowMenu.killsteal.killsteale:Value() then
            self:CastE(target)
        end
        if Ready(_Q) and target and IsValid(target) and (target.health <= qdmg) and self.shadowMenu.killsteal.killstealq:Value() then
            self:CastQ(target)
        end
    end
end

function Ziggs:Combo()
    local target = TargetSelector:GetTarget(self.Q.Range, 1)
    if target == nil then return end
    if Ready(_Q) and target and IsValid(target) then
        if self.shadowMenu.combo.Q:Value() then
           self:CastQ(target)
            --self:CastSpell(HK_Etarget)
        end														---- you have "end" forget
    end

    local target = TargetSelector:GetTarget(self.W.Range, 1)
    if target == nil then return end
    local posBehind = myHero.pos:Extended(target.pos, target.distance + 100)
    if Ready(_W) and target and IsValid(target) then
        if self.shadowMenu.combo.W:Value() then
            Control.CastSpell(HK_W, posBehind)
            --self:CastSpell(HK_Etarget)
        end
    end

    local target = TargetSelector:GetTarget(self.E.Range, 1)
    if target == nil then return end
    local posBehind = myHero.pos:Extended(target.pos, target.distance + 200)
    if Ready(_E) and target and IsValid(target) then
        if self.shadowMenu.combo.E:Value() then
            self:CastE(target)
            --self:CastSpell(HK_Etarget)
        end
    end

end

function Ziggs:junglekillsteal()
    if self.shadowMenu.junglekillsteal.W:Value() then 
        for i = 1, Game.MinionCount() do
            local obj = Game.Minion(i)
            if obj.team ~= myHero.team then
                if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                    local qdmg = getdmg("Q", obj, myHero, 1)
                    local wdmg = getdmg("W", obj, myHero, 1)
                    local edmg = getdmg("E", obj, myHero, 1)
                    if Ready(_W) and self.shadowMenu.jungleclear.W:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.W.Range and obj.health < wdmg) then
                        Control.CastSpell(HK_W, obj);
                    end
                    if Ready(_E) and self.shadowMenu.jungleclear.E:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.E.Range and obj.health < edmg) then
                        Control.CastSpell(HK_E, obj);
                    end
                    if Ready(_Q) and self.shadowMenu.jungleclear.Q:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range and obj.health < qdmg) then
                        Control.CastSpell(HK_Q, obj);
                    end
                end
            end
        end
    end
end

function Ziggs:laneclear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion.team ~= myHero.team then 
            local dist = myHero.pos:DistanceTo(minion.pos)
            if self.shadowMenu.laneclear.UseQLane:Value() and Ready(_Q) and dist <= self.Q.Range then 
                Control.CastSpell(HK_Q, minion.pos)
            end
            if self.shadowMenu.laneclear.UseELane:Value() and Ready(_E) and dist <= self.E.Range then 
                Control.CastSpell(HK_E, minion.pos)
            end
        end
    end
end

function Ziggs:jungleclear()
    if self.shadowMenu.jungleclear.Q:Value() then 
        for i = 1, Game.MinionCount() do
            local obj = Game.Minion(i)
            if obj.team ~= myHero.team then
                if obj ~= nil and obj.valid and obj.visible and not obj.dead then
                    if Ready(_W) and self.shadowMenu.jungleclear.W:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.W.Range) then
                        Control.CastSpell(HK_W, obj);
                    end
                    if Ready(_E) and self.shadowMenu.jungleclear.E:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.E.Range) then
                        Control.CastSpell(HK_E, obj);
                    end
                    if Ready(_Q) and self.shadowMenu.jungleclear.Q:Value() and obj and obj.team == 300 and obj.valid and obj.visible and not obj.dead and (obj.pos:DistanceTo(myHero.pos) < self.Q.Range) then
                        Control.CastSpell(HK_Q, obj);
                    end
                end
            end
        end
    end
end

function Ziggs:CastQ(target)
    if Ready(_Q) and lastQ + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.Q, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_Q, Pred.CastPosition)
            lastW = GetTickCount()
        end
    end
end

function Ziggs:CastW(target)
    if Ready(_W) and lastW + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.W, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_W, Pred.CastPosition)
            lastW = GetTickCount()
        end
    end
end

function Ziggs:CastE(target)
    if Ready(_E) and lastE + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.E, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_E, Pred.CastPosition)
            lastE = GetTickCount()
        end
    end
end

function Ziggs:CastR(target)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(target, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end
