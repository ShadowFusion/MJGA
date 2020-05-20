
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
            Name = "Shen.lua",
            Url = "https://raw.githubusercontent.com/ShadowFusion/MJGA/master/ShadowAIOV2.lua"
        },
        Version = {
            Path = SCRIPT_PATH,
            Name = "Shen.version",
            Url = "https://raw.githubusercontent.com/ShadowFusion/MJGA/master/ShadowAIOV2.version"    -- check if Raw Adress correct pls.. after you have create the version file on Github
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
    ["Shen"] = true,
    ["Karthus"] = true,
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

function GetItemSlot(unit, id)
    for i = ITEM_1, ITEM_7 do
        if unit:GetItemData(i).itemID == id then
            return i
        end
    end
    return 0
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

function Mode()
    if _G.SDK then
        if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
            return "Combo"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] or Orbwalker.Key.Harass:Value() then
            return "Harass"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] or Orbwalker.Key.Clear:Value() then
            return "LaneClear"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] or Orbwalker.Key.LastHit:Value() then
            return "LastHit"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
            return "Flee"
        end
    else
        return GOS.GetMode()
    end
end

 
class "Shen"
local Item_HK = {}
local target

function Shen:__init()
    
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
    ["ShenIcon"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/8/81/Shen_OriginalSquare.png",
    ["Q"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/7/7c/Twilight_Assault.png",
    ["W"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/5/5e/Spirit%27s_Refuge.png",
    ["E"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/9/92/Shadow_Dash.png",
    ["R"] = "https://vignette.wikia.nocookie.net/leagueoflegends/images/8/85/Stand_United_2.png",
    ["EXH"] = "https://vignette2.wikia.nocookie.net/leagueoflegends/images/4/4a/Exhaust.png"
    }

function Shen:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "SeriesShadowShen", name = "Series Shadow Shen", leftIcon = Icons["ShenIcon"]})


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
    self.Menu.R:MenuElement({id = "RCombo", name = "Use [R] in combo", value = true, leftIcon = Icons.R})
    self.Menu.R:MenuElement({id = "RHarass", name = "Use [R] in harass", value = true, leftIcon = Icons.R})
    self.Menu.R:MenuElement({id = "RAuto", name = "Use [R] in auto", value = true, leftIcon = Icons.R})

end


function Shen:Draw()
--[[
    local target = TargetSelector:GetTarget(20000, 5)
    if target and IsValid(target) then
    local rdmg = getdmg("R", target, myHero)
    if self.shadowMenu.Drawing.drawrkill:Value() and Ready(_R) and target.health < rdmg then
        Draw.Text("Killable with [R]", 18, target.pos2D.x, target.pos2D.y + 50, Draw.Color(255, 225, 255, 255))
    end
    ]]
end

function Shen:Tick()
    if myHero.dead or Game.IsChatOpen() or (ExtLibEvade and ExtLibEvade.Evading == true) then
        return
    end
    target = TargetSelector:GetTarget(2200, 1)
    self:UpdateItems()
    self:Logic()
    self:AutoSummoners()
end

function Shen:UpdateItems()
    Item_HK[ITEM_1] = HK_ITEM_1
    Item_HK[ITEM_2] = HK_ITEM_2
    Item_HK[ITEM_3] = HK_ITEM_3
    Item_HK[ITEM_4] = HK_ITEM_4
    Item_HK[ITEM_5] = HK_ITEM_5
    Item_HK[ITEM_6] = HK_ITEM_6
    Item_HK[ITEM_7] = HK_ITEM_7
end

function Shen:Items1()
    if GetItemSlot(myHero, 3074) > 0 and ValidTarget(target, 300) then --rave 
        if myHero:GetSpellData(GetItemSlot(myHero, 3074)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3074)])
        end
    end
    if GetItemSlot(myHero, 3077) > 0 and ValidTarget(target, 300) then --tiamat
        if myHero:GetSpellData(GetItemSlot(myHero, 3077)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3077)])
        end
    end
    if GetItemSlot(myHero, 3144) > 0 and ValidTarget(target, 550) then --bilge
        if myHero:GetSpellData(GetItemSlot(myHero, 3144)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3144)], target)
        end
    end
    if GetItemSlot(myHero, 3153) > 0 and ValidTarget(target, 550) then -- botrk
        if myHero:GetSpellData(GetItemSlot(myHero, 3153)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3153)], target)
        end
    end
    if GetItemSlot(myHero, 3146) > 0 and ValidTarget(target, 700) then --gunblade hex
        if myHero:GetSpellData(GetItemSlot(myHero, 3146)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3146)], target)
        end
    end
    if GetItemSlot(myHero, 3748) > 0 and ValidTarget(target, 300) then -- Titanic Hydra
        if myHero:GetSpellData(GetItemSlot(myHero, 3748)).currentCd == 0 then
            Control.CastSpell(Item_HK[GetItemSlot(myHero, 3748)])
        end
    end
end

function Shen:Logic()
if target == nil then return end
if Mode() == "Combo" or Mode() == "Harass" and target then
    self:Items1()
    if self:CanCast(_W, 0) and ValidTarget(target, self.W.Range)  then
        self:CastW(target)
    end
    if self:CanCast(_Q, 0) and ValidTarget(target, self.Q.Range)  then
        Control.CastSpell(HK_Q)
    end
    if self:CanCast(_R, 0) and ValidTarget(target, self.R.Range)  then
        Control.CastSpell(HK_R)
    end
end

function Shen:AutoSummoners()
    -- IGNITE --
    if target and IsValid(target) then
        local ignDmg = getdmg("IGNITE", target, myHero)
        if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Ready(SUMMONER_1) and (target.health < ignDmg ) then
            Control.CastSpell(HK_SUMMONER_1, target)
        elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Ready(SUMMONER_2) and (target.health < ignDmg ) then
            Control.CastSpell(HK_SUMMONER_2, target)
        end
    end
end

end

function Shen:CastW(unit)
    if Ready(_W) and lastW + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(unit, self.W, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_W, Pred.CastPosition)
            lastW = GetTickCount()
        end
    end
end

function Shen:CastE(unit)
    if Ready(_E) and lastE + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(unit, self.E, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_NORMAL then
            Control.CastSpell(HK_E, Pred.CastPosition)
            lastE = GetTickCount()
        end
    end
end

function Shen:CastR(unit)
    if Ready(_R) and lastR + 350 < GetTickCount() and orbwalker:CanMove() then
        local Pred = GamsteronPrediction:GetPrediction(unit, self.R, myHero)
        if Pred.Hitchance >= _G.HITCHANCE_HIGH then
            Control.CastSpell(HK_R, Pred.CastPosition)
            lastR = GetTickCount()
        end
    end
end

function Shen:CanCast(spell, mode)
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

