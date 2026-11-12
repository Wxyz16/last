-- Last Stop Autonomous Farming Engine Autoexec Loader
-- Guard: autoexec + queue_on_teleport can both fire; run once per server session
do
    local genv = getgenv and getgenv() or _G
    if genv.LastStopLoader_Job == game.JobId and game.JobId ~= "" then return end
    genv.LastStopLoader_Job = game.JobId
end
task.spawn(function()
    repeat task.wait(0.5) until game:IsLoaded() and game.Players.LocalPlayer
    task.wait(2.5)

    if game.PlaceId == 122776220269735 then
        -- Early rapid auto-skip for match intro cutscene & tutorial
        task.spawn(function()
            local lp = game.Players.LocalPlayer
            local t0 = os.clock()
            while os.clock() - t0 < 25.0 do
                pcall(function()
                    local knit = require(game:GetService("ReplicatedStorage").ClientSource.Mutual.Packages.Knit)
                    local cc = knit.GetController("CutsceneController")
                    if cc and cc.Managers then
                        for id, entry in pairs(cc.Managers) do
                            entry.Skippable = true
                            pcall(function()
                                local cs = knit.GetService("CutsceneService")
                                if cs and cs.SkipCutscene and cs.SkipCutscene.Fire then cs.SkipCutscene:Fire(id) end
                                local re = game:GetService("ReplicatedStorage"):FindFirstChild("CutsceneService", true)
                                local skipRe = re and re:FindFirstChild("SkipCutscene", true)
                                if skipRe and skipRe:IsA("RemoteEvent") then skipRe:FireServer(id) end
                            end)
                            if entry.Manager and not entry.Manager.Finished then
                                pcall(function() entry.Manager:Destroy() end)
                            end
                        end
                    end
                    if cc and cc.Skip then cc:Skip() end
                    local cs = knit.GetService("CutsceneService")
                    if cs and cs.SkipCutscene and cs.SkipCutscene.Fire then cs.SkipCutscene:Fire() end
                    local ss = knit.GetService("SiegeService")
                    if ss and ss.RF and ss.RF:FindFirstChild("VoteSkip") then ss.RF.VoteSkip:InvokeServer() end

                    -- Unfreeze character & restore camera & HUD
                    local charCtrl = knit.GetController("CharacterController")
                    if charCtrl then
                        pcall(function() charCtrl:Lock(false) end)
                        local pInfo = charCtrl.Get and charCtrl:Get()
                        if pInfo then
                            pInfo.Locked = false
                            if pInfo.Humanoid then
                                pInfo.Humanoid.WalkSpeed = 16
                                pInfo.Humanoid.JumpPower = 50
                                pInfo.Humanoid.AutoRotate = true
                            end
                            if pInfo.HumanoidRootPart then
                                pInfo.HumanoidRootPart.Anchored = false
                            end
                        end
                    end
                    local cam = workspace.CurrentCamera
                    if cam and cam.CameraType == Enum.CameraType.Scriptable then
                        cam.CameraType = Enum.CameraType.Custom
                        local char = lp.Character
                        local hum = char and char:FindFirstChildOfClass("Humanoid")
                        if hum then cam.CameraSubject = hum end
                    end
                    local ic = knit.GetController("InterfaceController")
                    if ic and ic.SuppressHUD then ic:SuppressHUD(false) end
                end)
                pcall(function()
                    local pg = lp and lp:FindFirstChild("PlayerGui")
                    local csBtn = pg and pg:FindFirstChild("Main") and pg.Main:FindFirstChild("CutsceneSkip")
                    if csBtn and csBtn:IsA("GuiButton") and csBtn.Visible then
                        for _, c in ipairs(getconnections(csBtn.Activated)) do c:Fire() end
                    end
                    local br = pg and pg:FindFirstChild("Main") and pg.Main:FindFirstChild("HUD") and pg.Main.HUD:FindFirstChild("BusRushTutorial")
                    local brSkip = br and br:FindFirstChild("Skip", true)
                    if br and br.Visible and brSkip then
                        for _, c in ipairs(getconnections(brSkip.Activated)) do c:Fire() end
                    end
                    local sc = pg and pg:FindFirstChild("Main") and pg.Main:FindFirstChild("HUD") and pg.Main.HUD:FindFirstChild("SiegeControls")
                    local scSkip = sc and sc:FindFirstChild("Skip", true)
                    if sc and sc.Visible and scSkip then
                        for _, c in ipairs(getconnections(scSkip.Activated)) do c:Fire() end
                    end
                end)
                task.wait(0.2)
            end
        end)

        -- In Game Match: load suite
        if isfile and isfile("last_stop_auto_farm.lua") then
            loadstring(readfile("last_stop_auto_farm.lua"))()
        elseif isfile and isfile("lua/games/last-stop/script.lua") then
            loadstring(readfile("lua/games/last-stop/script.lua"))()
        end
    elseif game.PlaceId == 85967844112283 then
        -- In Lobby: check if auto-loop is enabled in config
        task.wait(2.0)
        local autoLoop = true
        local targetMode = "Nightmare"
        if isfile and isfile("last_stop_config.json") then
            pcall(function()
                local http = game:GetService("HttpService")
                local cfg = http:JSONDecode(readfile("last_stop_config.json"))
                if cfg.AutoLoopNewGame ~= nil then autoLoop = cfg.AutoLoopNewGame end
                if cfg.LobbyGameMode ~= nil then targetMode = cfg.LobbyGameMode end
            end)
        end

        if autoLoop then
            task.spawn(function()
                local lp = game.Players.LocalPlayer
                local pg = lp:WaitForChild("PlayerGui", 20)

                local function clickBtn(btn)
                    if not btn or not btn:IsA("GuiButton") then return end
                    pcall(function()
                        for _, c in ipairs(getconnections(btn.Activated)) do c:Fire() end
                    end)
                    if btn.MouseButton1Click then
                        pcall(function()
                            for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
                        end)
                    end
                end

                -- 1. Continuously dismiss any blocking dialogs/popups
                local function dismissPopups()
                    pcall(function()
                        local okBtn = pg and pg:FindFirstChild("Main") and pg.Main:FindFirstChild("HUD") and pg.Main.HUD:FindFirstChild("LeveledUp") and pg.Main.HUD.LeveledUp:FindFirstChild("OkButton")
                        if okBtn and okBtn.Visible then clickBtn(okBtn) end
                    end)
                    pcall(function()
                        local rj = pg and pg:FindFirstChild("Main") and pg.Main:FindFirstChild("Container") and pg.Main.Container:FindFirstChild("RejoinLastSession")
                        local closeBtn = rj and (rj:FindFirstChild("CloseButton") or (rj:FindFirstChild("Container") and rj.Container:FindFirstChild("Close")))
                        if closeBtn and closeBtn.Visible then clickBtn(closeBtn) end
                    end)
                end

                dismissPopups()
                task.wait(0.5)

                -- Helper: Press BottomHUD.Play button to open CreateLobby (bypasses zone stepping)
                local function pressPlayButton()
                    dismissPopups()
                    local playBtn = pg and pg:FindFirstChild("Main") and pg.Main:FindFirstChild("HUD") and pg.Main.HUD:FindFirstChild("BottomHUD") and pg.Main.HUD.BottomHUD:FindFirstChild("Play")
                    if playBtn and playBtn:IsA("GuiButton") and playBtn.Visible then
                        clickBtn(playBtn)
                        return true
                    end
                    -- Fallback: Call Knit LobbyController.CreateLobby() directly
                    local called = false
                    pcall(function()
                        local knit = require(game:GetService("ReplicatedStorage").ClientSource.Mutual.Packages.Knit)
                        local lobbyCtrl = knit.GetController("LobbyController")
                        if lobbyCtrl and lobbyCtrl.CreateLobby then
                            lobbyCtrl.CreateLobby()
                            called = true
                        end
                    end)
                    return called
                end

                -- Helper: Configure settings inside CreateLobby and click CreateButton
                local function configureAndCreate()
                    local cl = pg:FindFirstChild("CreateLobby")
                    local mf = cl and cl:FindFirstChild("MainFrame")
                    if not (mf and mf.Visible) then return false end

                    -- 1. Max Players = 1 (Solo)
                    pcall(function()
                        local mp = mf:FindFirstChild("MaxPlayers")
                        local p1 = mp and mp:FindFirstChild("1") and mp["1"]:FindFirstChild("Button")
                        if p1 then clickBtn(p1) end
                    end)
                    task.wait(0.15)

                    -- 2. Game Mode (Nightmare or configured targetMode)
                    pcall(function()
                        local gm = mf:FindFirstChild("GameModes")
                        local sf = gm and gm:FindFirstChild("ScrollingFrame")
                        local modeFrame = sf and (sf:FindFirstChild(targetMode) or sf:FindFirstChild("Nightmare") or sf:FindFirstChild("Classic"))
                        local modeBtn = modeFrame and modeFrame:FindFirstChild("Button")
                        if modeBtn then clickBtn(modeBtn) end
                    end)
                    task.wait(0.15)

                    -- 3. Private Room Toggle (ensures other players cannot enter)
                    pcall(function()
                        local priv = mf:FindFirstChild("Private")
                        if priv and priv:IsA("GuiButton") then
                            local checkmark = priv:FindFirstChild("Check") or priv:FindFirstChild("Active") or priv:FindFirstChild("Selected")
                            if not (checkmark and checkmark.Visible) then
                                clickBtn(priv)
                            end
                        end
                    end)
                    task.wait(0.15)

                    -- 4. Click CreateButton
                    local createBtn = mf:FindFirstChild("CreateButton")
                    if createBtn then
                        clickBtn(createBtn)
                    end

                    -- Direct Knit fallback: LobbyService:LobbyMethod("Create", ...)
                    pcall(function()
                        local knit = require(game:GetService("ReplicatedStorage").ClientSource.Mutual.Packages.Knit)
                        local ls = knit.GetService("LobbyService")
                        if ls and ls.LobbyMethod then
                            ls:LobbyMethod("Create", {Mode = targetMode, MaxPlayers = 1, Private = true})
                        end
                    end)

                    return true
                end

                -- Helper: Check if room has been created (InLobby GUI visible)
                local function isInRoom()
                    local inLobby = pg:FindFirstChild("InLobby")
                    return inLobby and inLobby:FindFirstChild("MainFrame") and inLobby.MainFrame.Visible
                end

                -- ================================================================
                -- ROOM CREATION RETRY LOOP:
                -- Press "Play" repeatedly until room is successfully created.
                -- If room creation fails (e.g. server lobbies full), retries Play until room is open.
                -- ================================================================
                local loopStart = os.clock()
                local lastPressPlay = 0
                local lastCreateClick = 0
                local createLobbyOpenTime = 0

                while os.clock() - loopStart < 180.0 do
                    if isInRoom() then break end

                    dismissPopups()

                    local cl = pg:FindFirstChild("CreateLobby")
                    local mf = cl and cl:FindFirstChild("MainFrame")

                    if mf and mf.Visible then
                        if createLobbyOpenTime == 0 then
                            createLobbyOpenTime = os.clock()
                        end

                        -- If CreateLobby has been stuck open for > 6 seconds without transitioning to InLobby (e.g. room full error), close and re-press Play
                        if os.clock() - createLobbyOpenTime > 6.0 then
                            local closeBtn = mf:FindFirstChild("CloseButton")
                            if closeBtn then clickBtn(closeBtn) end
                            createLobbyOpenTime = 0
                            task.wait(0.5)
                        else
                            -- Configure and click Create Lobby button every 1.2s
                            if os.clock() - lastCreateClick >= 1.2 then
                                lastCreateClick = os.clock()
                                configureAndCreate()
                            end
                        end
                    else
                        createLobbyOpenTime = 0
                        -- CreateLobby GUI not open: press "Play" button every 1.5s until it opens or room enters
                        if os.clock() - lastPressPlay >= 1.5 then
                            lastPressPlay = os.clock()
                            pressPlayButton()
                        end
                    end

                    task.wait(0.3)
                end

                -- ================================================================
                -- IN-LOBBY AUTO-START WATCHER LOOP:
                -- Once room is created, click "Start" until match teleports
                -- ================================================================
                local roomWaitStart = os.clock()
                while os.clock() - roomWaitStart < 60.0 do
                    dismissPopups()

                    local inLobby = pg:FindFirstChild("InLobby")
                    local startBtn = inLobby and inLobby:FindFirstChild("MainFrame") and inLobby.MainFrame:FindFirstChild("Start")

                    if not isInRoom() and os.clock() - roomWaitStart > 5.0 then
                        -- If room was unexpectedly lost, trigger Play again
                        pressPlayButton()
                        task.wait(0.5)
                        configureAndCreate()
                    end

                    if startBtn and startBtn:IsA("GuiButton") and startBtn.Visible then
                        clickBtn(startBtn)
                    end

                    -- Also invoke Knit LobbyService:Play() directly as parallel guarantee
                    pcall(function()
                        local knit = require(game:GetService("ReplicatedStorage").ClientSource.Mutual.Packages.Knit)
                        local ls = knit.GetService("LobbyService")
                        if ls and ls.Play then
                            ls:Play()
                        end
                    end)

                    task.wait(0.5)
                end
            end)
        end
    end
end)
