-- ========================================================================
-- LAST STOP: STANDALONE RETURN TO LOBBY MODULE
-- ========================================================================
-- Independent, robust module to safely return from a Game Match to the Lobby.
-- Can be run directly via loadstring/executor or required by other scripts.
--
-- Usage:
--   loadstring(readfile("return_to_lobby.lua"))()
--   -- or:
--   local ReturnLobby = loadstring(readfile("return_to_lobby.lua"))()
--   ReturnLobby.Execute({ StoreSword = true })
-- ========================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local ReturnModule = {}

-- Visual status notification on screen
local function ShowStatus(text, color)
    print(string.format("[ReturnLobby] %s", text))
    pcall(function()
        local sg = LocalPlayer.PlayerGui:FindFirstChild("ReturnLobby_Notify") or Instance.new("ScreenGui")
        sg.Name = "ReturnLobby_Notify"
        sg.ResetOnSpawn = false
        sg.Parent = LocalPlayer.PlayerGui

        local lbl = sg:FindFirstChild("StatusLabel") or Instance.new("TextLabel")
        lbl.Name = "StatusLabel"
        lbl.Size = UDim2.new(0, 480, 0, 44)
        lbl.Position = UDim2.new(0.5, -240, 0.15, 0)
        lbl.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
        lbl.BorderSizePixel = 0
        lbl.TextColor3 = color or Color3.fromRGB(0, 229, 255)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 14
        lbl.Text = text
        lbl.Parent = sg

        if not lbl:FindFirstChild("UICorner") then
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, 8)
            c.Parent = lbl
            local s = Instance.new("UIStroke")
            s.Color = color or Color3.fromRGB(0, 229, 255)
            s.Thickness = 1.2
            s.Parent = lbl
        end
    end)
end

-- Resolve tool information (Last Stop names tools with GUIDs)
local function ResolveToolInfo(tool)
    if not tool or not tool:IsA("Tool") then return nil, false end
    local toolId = tool.Name
    local realName = nil
    
    -- Method 1: Knit ItemController
    pcall(function()
        local knitPkg = require(ReplicatedStorage.ClientSource.Mutual.Packages.Knit)
        local ic = knitPkg.GetController("ItemController")
        if ic then
            if ic.GetItemReplica then
                local rep = ic:GetItemReplica(toolId)
                if rep then
                    realName = (rep.Tags and rep.Tags.Name) or (rep.Data and rep.Data.Item and rep.Data.Item.Name)
                end
            end
            if not realName and ic.TryGetItemReplica then
                local rep = ic:TryGetItemReplica(toolId)
                if rep then
                    realName = (rep.Tags and rep.Tags.Name) or (rep.Data and rep.Data.Item and rep.Data.Item.Name)
                end
            end
            if not realName and ic.GetItemByInstance then
                local obj = ic:GetItemByInstance(tool)
                if obj and obj.Config and obj.Config.Name then
                    realName = obj.Config.Name
                end
            end
            if not realName and ic.Cache and ic.Cache.Items and ic.Cache.Items[toolId] then
                local obj = ic.Cache.Items[toolId]
                if obj and obj.Replica and obj.Replica.Tags then
                    realName = obj.Replica.Tags.Name
                elseif obj and obj.Config and obj.Config.Name then
                    realName = obj.Config.Name
                end
            end
        end
    end)
    
    -- Method 2: Knit Components Item
    if not realName then
        pcall(function()
            local knitPkg = require(ReplicatedStorage.ClientSource.Mutual.Packages.Knit)
            if knitPkg.Components and knitPkg.Components.Item then
                local comp = knitPkg.Components.Item:FromId(toolId)
                if comp and comp.Replica and comp.Replica.Tags then
                    realName = comp.Replica.Tags.Name
                end
            end
        end)
    end
    
    -- Method 3: Tool attributes & child values
    if not realName then
        for _, attr in ipairs({"ItemName", "Name", "ToolName", "ItemType", "WeaponType"}) do
            local val = tool:GetAttribute(attr)
            if val and tostring(val) ~= "" then
                realName = tostring(val)
                break
            end
        end
    end
    if not realName then
        for _, childName in ipairs({"ItemName", "Name", "ToolName"}) do
            local val = tool:FindFirstChild(childName)
            if val and (val:IsA("StringValue") or val:IsA("TextLabel")) then
                realName = val.Value or val.Text
                break
            end
        end
    end
    
    -- Method 4: Fallback to ToolTip or tool.Name
    if not realName then
        if tool.ToolTip and tool.ToolTip ~= "" then
            realName = tool.ToolTip
        else
            realName = tool.Name
        end
    end
    
    local rLower = tostring(realName):lower()
    
    -- Filter out permanent utility tools (Shovel, Repair Hammer, Wrench, Torch, etc.)
    local isUtility = rLower:find("shovel") or rLower:find("hammer") or rLower:find("wrench") or rLower:find("torch") or rLower:find("wood") or rLower:find("fuel")
    
    -- Determine if it's a sword or vaultable weapon
    local isSword = (not isUtility) and (
        rLower:find("sword") or 
        rLower:find("vampire") or 
        rLower:find("blade") or 
        rLower:find("katana") or 
        rLower:find("saber") or 
        rLower:find("dagger")
    )
    
    return realName, isSword
end

-- Find all swords / vaultable weapons currently in Backpack or Character
local function GetInventorySwords()
    local list = {}
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local char = LocalPlayer.Character

    local function check(tool)
        if not tool or not tool:IsA("Tool") then return end
        local rName, isSword = ResolveToolInfo(tool)
        if isSword then
            table.insert(list, { Tool = tool, Id = tool.Name, Name = rName or tool.Name })
        end
    end

    if bp then
        for _, t in ipairs(bp:GetChildren()) do check(t) end
    end
    if char then
        for _, t in ipairs(char:GetChildren()) do check(t) end
    end
    return list
end

-- Locate dynamic Vault part in Chunk 1 / Workspace
local function FindVaultPart()
    local container = Workspace:FindFirstChild("CHUNKS_CONTAINER")
    if container then
        for _, desc in ipairs(container:GetDescendants()) do
            if desc.Name == "Vault" and desc:IsA("BasePart") then
                return desc
            end
        end
    end
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc.Name == "Vault" and desc:IsA("BasePart") then
            return desc
        end
    end
    return nil
end

-- Mandatory Store Sword to Vault with verification before returning to Lobby
function ReturnModule.StoreSword()
    ShowStatus("Inspecting inventory for swords...", Color3.fromRGB(255, 200, 80))

    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then
        ShowStatus("Character not ready!", Color3.fromRGB(255, 80, 80))
        return false
    end

    -- Initial sword scan
    local initialSwords = GetInventorySwords()
    if #initialSwords == 0 then
        ShowStatus("No swords in inventory. Safe to proceed to Lobby.", Color3.fromRGB(120, 255, 140))
        return true
    end

    ShowStatus(string.format("Found %d sword(s) to deposit! Teleporting to Vault...", #initialSwords), Color3.fromRGB(255, 220, 50))

    -- Reset velocity and teleport to known Start Terminal Vault position (Chunk 1)
    pcall(function()
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Velocity = Vector3.zero
                if part.AssemblyLinearVelocity then part.AssemblyLinearVelocity = Vector3.zero end
            end
        end
    end)
    hrp.CFrame = CFrame.new(330.62, 107.5, 315.28)
    task.wait(0.35)

    -- Unequip tools so they can be stored
    hum:UnequipTools()
    task.wait(0.15)

    -- Locate Vault part and fire ProximityPrompt to open server Vault session
    local vaultPart = FindVaultPart()
    if vaultPart then
        hrp.CFrame = CFrame.new(vaultPart.Position + Vector3.new(0, 2.5, 2))
        task.wait(0.15)
        local prompt = vaultPart:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            pcall(function() fireproximityprompt(prompt, 0) end)
        end
    end
    task.wait(0.25)

    -- Locate Knit VaultService
    local VaultService = nil
    pcall(function()
        local knitPkg = require(ReplicatedStorage.ClientSource.Mutual.Packages.Knit)
        VaultService = knitPkg.GetService("VaultService")
    end)

    -- Depositing loop with strict verification (up to 6.0 seconds)
    local maxWait = 6.0
    local startTime = os.clock()

    while os.clock() - startTime < maxWait do
        local remaining = GetInventorySwords()
        if #remaining == 0 then
            break
        end

        hum:UnequipTools()
        for _, s in ipairs(remaining) do
            ShowStatus(string.format("Depositing %s into Vault...", s.Name), Color3.fromRGB(0, 229, 255))
            if VaultService and VaultService.StoreItem then
                pcall(function() VaultService:StoreItem(s.Id) end)
            end
            pcall(function()
                local rf = ReplicatedStorage.ClientSource.Mutual.Packages.Knit.Services.VaultService.RF.StoreItem
                if rf then rf:InvokeServer(s.Id) end
            end)
            task.wait(0.15)
        end

        task.wait(0.3)
    end

    -- Final verification check
    local finalRemaining = GetInventorySwords()
    if #finalRemaining == 0 then
        ShowStatus("✓ All swords safely deposited in Vault!", Color3.fromRGB(0, 255, 120))
        task.wait(0.5) -- Wait for server data synchronization
    else
        ShowStatus(string.format("⛔ %d sword(s) could NOT be stored! Aborting Lobby exit to protect your sword!", #finalRemaining), Color3.fromRGB(255, 50, 50))
        return false -- DO NOT EXIT TO LOBBY IF SWORD IS STILL IN INVENTORY!
    end

    -- Close Vault GUI if open
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg and pg.Main and pg.Main:FindFirstChild("Container") and pg.Main.Container:FindFirstChild("Vault") then
            pg.Main.Container.Vault.Visible = false
        end
    end)

    return true
end

-- Primary Return to Lobby Action
function ReturnModule.Execute(options)
    local opts = options or {}
    local shouldStore = (opts.StoreSword == true) -- Default false: no sword storing

    -- If already in lobby, do nothing
    if game.PlaceId == 85967844112283 then
        ShowStatus("Already in Lobby!", Color3.fromRGB(80, 255, 120))
        return true
    end

    -- Step 1: Sword deposit (only if explicitly requested via StoreSword == true)
    if shouldStore then
        local initialSwords = GetInventorySwords()
        if #initialSwords > 0 then
            local storeOk = ReturnModule.StoreSword()
            if not storeOk then
                ShowStatus("⛔ Return aborted: Sword is still in inventory! Protecting weapon.", Color3.fromRGB(255, 50, 50))
                return false
            end
        else
            ShowStatus("No swords in inventory. Safe to proceed to Lobby.", Color3.fromRGB(120, 255, 140))
        end
    end

    -- Step 2: Queue Auto-Loader for when we arrive in Lobby
    if queue_on_teleport then
        pcall(function()
            queue_on_teleport([[
                repeat task.wait(0.5) until game:IsLoaded() and game.Players.LocalPlayer
                task.wait(2.0)
                if game.PlaceId == 85967844112283 then
                    if isfile and isfile("last_stop_loader.lua") then
                        loadstring(readfile("last_stop_loader.lua"))()
                    end
                elseif game.PlaceId == 122776220269735 then
                    if isfile and isfile("last_stop_auto_farm.lua") then
                        loadstring(readfile("last_stop_auto_farm.lua"))()
                    end
                end
            ]])
        end)
    end

    ShowStatus("Returning to Lobby now...", Color3.fromRGB(0, 255, 180))

    -- Step 3: Relentless Multi-Method Return Loop (ONLY runs after sword is verified in vault)
    task.spawn(function()
        local attempts = 0
        while attempts < 30 do
            attempts = attempts + 1

            -- Method A: Game's official green [Teleport] button
            pcall(function()
                local pg = LocalPlayer:FindFirstChild("PlayerGui")
                local rl = pg and pg.Main and pg.Main:FindFirstChild("Container") and pg.Main.Container:FindFirstChild("ReturnLobby")
                local tpBtn = rl and rl:FindFirstChild("TeleportButton")
                if tpBtn then
                    for _, c in ipairs(getconnections(tpBtn.Activated)) do c:Fire() end
                    if tpBtn.MouseButton1Click then
                        for _, c in ipairs(getconnections(tpBtn.MouseButton1Click)) do c:Fire() end
                    end
                end
            end)

            -- Method B: Topbar door exit icon
            pcall(function()
                local pg = LocalPlayer:FindFirstChild("PlayerGui")
                local tb = pg and pg:FindFirstChild("TopbarStandard")
                local icon = tb and tb:FindFirstChild("ReturnLobby", true)
                local click = icon and icon:FindFirstChild("ClickRegion", true)
                if click then
                    for _, c in ipairs(getconnections(click.Activated)) do c:Fire() end
                end
            end)

            -- Method C: Knit GameService:ReturnLobby()
            pcall(function()
                local knitPkg = require(ReplicatedStorage.ClientSource.Mutual.Packages.Knit)
                local gs = knitPkg.GetService("GameService")
                if gs and gs.ReturnLobby then
                    gs:ReturnLobby()
                end
            end)

            -- Method D: Direct RemoteFunction ReturnLobby
            pcall(function()
                local rf = ReplicatedStorage.ClientSource.Mutual.Packages.Knit.Services.GameService.RF.ReturnLobby
                if rf then rf:InvokeServer() end
            end)

            -- Method E: Knit GameService:GoLobby()
            pcall(function()
                local knitPkg = require(ReplicatedStorage.ClientSource.Mutual.Packages.Knit)
                local gs = knitPkg.GetService("GameService")
                if gs and gs.GoLobby then
                    gs:GoLobby()
                end
            end)

            task.wait(0.3)
            if game.PlaceId ~= 122776220269735 then break end
        end
    end)

    return true
end

-- Auto-run on execution if executed standalone
ReturnModule.Execute({ StoreSword = false })

return ReturnModule
