-- Last Stop Autonomous Farming Engine Autoexec Loader
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

                -- 2. Zone stepping: iterate available lobby zones until CreateLobby GUI opens
                local char = lp.Character or lp.CharacterAdded:Wait()
                local hrp = char:WaitForChild("HumanoidRootPart", 10)
                local lc = workspace.Map and workspace.Map:FindFirstChild("LoobyCreate")

                local cl = pg:FindFirstChild("CreateLobby")
                local mf = cl and cl:FindFirstChild("MainFrame")

                if not (mf and mf.Visible) then
                    local zoneList = {"Lobby1", "Lobby2", "Lobby3"}
                    for _, zoneName in ipairs(zoneList) do
                        dismissPopups()
                        local lobbyModel = lc and lc:FindFirstChild(zoneName)
                        local zonePart = lobbyModel and lobbyModel:FindFirstChild("Zone")
                        if hrp and zonePart then
                            for _ = 1, 3 do
                                hrp.CFrame = zonePart.CFrame + Vector3.new(0, 3, 0)
                                task.wait(0.25)
                            end

                            -- Check if CreateLobby appeared
                            local tCheck = os.clock()
                            while os.clock() - tCheck < 2.0 do
                                cl = pg:FindFirstChild("CreateLobby")
                                mf = cl and cl:FindFirstChild("MainFrame")
                                if mf and mf.Visible then break end
                                task.wait(0.2)
                            end
                            if mf and mf.Visible then break end
                        end
                    end
                end

                -- Fallback: Call Knit LobbyController.CreateLobby() if zone step did not open GUI
                if not (mf and mf.Visible) then
                    pcall(function()
                        local knit = require(game:GetService("ReplicatedStorage").ClientSource.Mutual.Packages.Knit)
                        local lobbyCtrl = knit.GetController("LobbyController")
                        if lobbyCtrl and lobbyCtrl.CreateLobby then
                            lobbyCtrl.CreateLobby()
                        end
                    end)
                    task.wait(1.0)
                    cl = pg:FindFirstChild("CreateLobby")
                    mf = cl and cl:FindFirstChild("MainFrame")
                end

                -- 3. Configure and click CreateButton
                if mf then
                    -- Select MaxPlayers: 1
                    local p1 = mf.MaxPlayers:FindFirstChild("1") and mf.MaxPlayers["1"]:FindFirstChild("Button")
                    if p1 then
                        clickBtn(p1)
                    end
                    task.wait(0.25)

                    -- Select Game Mode: targetMode or Nightmare or Classic
                    local modeFrame = mf.GameModes.ScrollingFrame:FindFirstChild(targetMode)
                        or mf.GameModes.ScrollingFrame:FindFirstChild("Nightmare")
                        or mf.GameModes.ScrollingFrame:FindFirstChild("Classic")
                    local modeBtn = modeFrame and modeFrame:FindFirstChild("Button")
                    if modeBtn then
                        clickBtn(modeBtn)
                    end
                    task.wait(0.25)

                    -- Click Create Button
                    local createBtn = mf:FindFirstChild("CreateButton")
                    if createBtn then
                        clickBtn(createBtn)
                    end
                end

                -- 4. InLobby Auto-Start Watcher Loop (CRITICAL FIX FOR 1s / DISBAND-START SCREEN STUCK)
                -- Continuously monitors for InLobby / Start button and clicks it until match teleports!
                local roomWaitStart = os.clock()
                while os.clock() - roomWaitStart < 35.0 do
                    -- Direct Target: PlayerGui.InLobby.MainFrame.Start
                    local inLobby = pg:FindFirstChild("InLobby")
                    local startBtn = inLobby and inLobby:FindFirstChild("MainFrame") and inLobby.MainFrame:FindFirstChild("Start")
                    if startBtn and startBtn:IsA("GuiButton") and startBtn.Visible then
                        clickBtn(startBtn)
                    end

                    -- Secondary Target: Any visible Start button across all PlayerGui
                    for _, b in ipairs(pg:GetDescendants()) do
                        if b:IsA("GuiButton") and b.Visible then
                            local n = b.Name:lower()
                            local t = ""
                            if b:IsA("TextButton") then
                                t = b.Text:lower()
                            else
                                local lbl = b:FindFirstChildOfClass("TextLabel")
                                if lbl then t = lbl.Text:lower() end
                            end
                            if n == "start" or n == "startbtn" or t == "start" then
                                clickBtn(b)
                            end
                        end
                    end
                    task.wait(0.5)
                end
            end)
        end
    end
end)
