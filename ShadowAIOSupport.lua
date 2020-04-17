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
        
        local Version = 0.3
        
        local Files = {
            Lua = {
                Path = SCRIPT_PATH,
                Name = "ShadowAIO.lua",
                Url = "https://raw.githubusercontent.com/ShadowFusion/MJGA/master/ShadowAIOSupport.lua"
            },
            Version = {
                Path = SCRIPT_PATH,
                Name = "ShadowAIO.version",
                Url = "https://raw.githubusercontent.com/ShadowFusion/MJGA/master/ShadowAIOSupport.version"    -- check if Raw Adress correct pls.. after you have create the version file on Github
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
        ["Blitzcrank"] = true,
        ["Nami"] = true,
        ["Sona"] = true,
        ["Braum"] = true,
        ["Taric"] = true,
        ["Leona"] = true,
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
    _   _   _   _   _   _   _   _   _   _  
    / \ / \ / \ / \ / \ / \ / \ / \ / \ / \ 
    ( B | L | I | T | Z | C | R | A | N | K )
    \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ 
                                                                        
    ]]

            if myHero.charName == "Blitzcrank" then
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
                end

    --[[
                _   _   _   _  
                / \ / \ / \ / \ 
            ( N | A | M | I )
                \_/ \_/ \_/ \_/ 
    ]]

    if myHero.charName == "Nami" then
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
        end

    --[[
    _   _   _   _  
    / \ / \ / \ / \ 
    ( S | O | N | A )
    \_/ \_/ \_/ \_/ 
    ]]

    if myHero.charName == "Sona" then
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
        end
--[[
   _   _   _   _   _  
  / \ / \ / \ / \ / \ 
 ( B | R | A | U | M )
  \_/ \_/ \_/ \_/ \_/ 
]]

if myHero.charName == "Braum" then
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
    end
--[[
    _   _   _   _   _  
    / \ / \ / \ / \ / \ 
   ( T | A | R | I | C )
    \_/ \_/ \_/ \_/ \_/ 
]]

if myHero.charName == "Leona" then
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
    end
