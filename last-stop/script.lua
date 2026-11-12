--[[
    ========================================================================
    LAST STOP [BETA] — STREAMLINED TACTICAL & SURVIVAL SUITE
    ========================================================================
    Game: Last Stop [Beta] - Game
    PlaceId: 122776220269735
    UniverseId: 10759337137
    PlaceVersion: 81
    Engine: Knit Modular Client-Server Architecture + Red / ReplicaService
    Target: Universal Luau Roblox Executor
    
    Optimized Architecture:
      1. Zero-Shake Combat Engine (Kill Aura + Smooth Sticky Auto-Lock)
      2. Integrated Survival & Bus Automation Hub (Auto-Revive, Auto-Fuel, Anti-Starve)
      3. Agile Movement & Physics Engine (Speed, Flight, Noclip, Infinite Jump)
      4. Tactical ESP & Fast Travel Network (Hostile/Item/Bus Visuals, Essential Waypoints)
      5. Streamlined 4-Tab Dark HUD + Floating Mobile Pill
      6. Zero-Leak Destructor & Background Anti-AFK
]]

-- ========================================================================
-- RE-ENTRANCY & CLEANUP LIFECYCLE
-- ========================================================================
if getgenv().LastStopSuite_Loaded then
    if typeof(getgenv().LastStopSuite_Unload) == "function" then
        pcall(getgenv().LastStopSuite_Unload)
    end
end
getgenv().LastStopSuite_Loaded = true

-- Core Roblox Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Centralized Registry for Zero-Leak Unload
local Connections = {}
local ManagedInstances = {}
local OriginalHitboxSizes = {}
local OriginalCameraMethods = {}

local function RegisterConnection(conn)
    if conn then
        table.insert(Connections, conn)
    end
    return conn
end

local function RegisterInstance(inst)
    if inst then
        table.insert(ManagedInstances, inst)
    end
    return inst
end

-- ========================================================================
-- KNIT & GAME ENVIRONMENT HANDSHAKE
-- ========================================================================
local Knit
pcall(function()
    Knit = require(ReplicatedStorage.ClientSource.Mutual.Packages.Knit)
end)

local ItemService = Knit and Knit.GetService("ItemService")
local InventoryService = Knit and Knit.GetService("InventoryService")
local ReviveService = Knit and Knit.GetService("ReviveService")
local GameService = Knit and Knit.GetService("GameService")
local VaultService = Knit and Knit.GetService("VaultService")
local CutsceneService = Knit and Knit.GetService("CutsceneService")
local SiegeService = Knit and Knit.GetService("SiegeService")

local CharacterController = Knit and Knit.GetController("CharacterController")
local ItemController = Knit and Knit.GetController("ItemController")
local SprintController = Knit and Knit.GetController("SprintController")
local EntityController = Knit and Knit.GetController("EntityController")
local CameraController = Knit and Knit.GetController("CameraController")
local InterfaceController = Knit and Knit.GetController("InterfaceController")
local CutsceneController = Knit and Knit.GetController("CutsceneController")

-- Shared Survival Timers
local LastSurvivalCheck = 0
local LastBusCheck = 0

-- Game Workspace Containers
local EntityContainer = Workspace:WaitForChild("ENTITY_CONTAINER", 10)
local ItemContainer = Workspace:WaitForChild("ITEM_CONTAINER", 10)
local ChunksContainer = Workspace:WaitForChild("CHUNKS_CONTAINER", 10)
local PlayerContainer = Workspace:WaitForChild("PLAYER_CONTAINER", 10)

-- ========================================================================
-- CONFIGURATION & STATE REPOSITORY
-- ========================================================================
local Config = {
    -- Combat
    KillAura = false,
    AuraRadius = 35,
    AuraAttackDelay = 0.15,
    AuraTargetMode = "Closest", -- "Closest", "LowestHP", "All"
    VaultVampireSword = false,
    VaultVampireReturnDelay = 0.5,
    AutoLock = false,
    LockRadius = 60,
    HitboxExpander = false,
    HitboxSize = 25,
    NoCameraShake = true,

    -- Ticket Auto Farm (Checkpoint 1 & 2)
    AutoFarmTicket = false,
    AutoFarmTargetCheckpoint = 2, -- 1 = CP1 only, 2 = Both CP1 & CP2 (Full Farm)
    UnderneathHover = true,
    UnderneathOffset = 5.0,
    TicketFarmWaveOnly = true,
    AntiVoid = true,
    AntiVoidMinAltitude = 75, -- Instant rescue if character falls below Y=75
    AutoStoreSwordOnFinish = false, -- Storing sword removed: immediately return to lobby
    AutoLoopNewGame = true,        -- Automatically start new game / loop farm after match
    LoopRestartMethod = "ReturnLobby", -- "ReturnLobby" (Safely bank tickets and restart match from lobby)
    AutoStartFarmOnLoad = true,    -- Automatically start auto-farm upon entering fresh match
    AutoSkipIntro = true,          -- Automatically skip match intro cutscenes, tutorial, and wait timer

    -- Survival & Bus Hub
    AutoRevive = true,
    AutoReviveAll = false,
    AutoHeal = true,
    HealThreshold = 95,
    EmergencySkyRetreat = true,
    EmergencyRetreatThreshold = 50, -- Escape to sky when HP < 50%
    EmergencyRecoverThreshold = 90, -- Return to fight when HP >= 90%
    EmergencySkyAltitude = 350,     -- Safe flight altitude (studs)
    EmergencyStoreSword = false,    -- Storing sword removed
    AutoEat = true,
    EatThreshold = 75,
    InfiniteSprint = true,
    AutoFuel = false,
    FuelThreshold = 80,
    HornSpam = false,

    -- Movement & Physics
    SpeedEnabled = false,
    WalkSpeed = 35,
    JumpPowerEnabled = false,
    JumpPower = 80,
    InfiniteJump = false,
    Noclip = false,
    FlyEnabled = false,
    FlySpeed = 65,

    -- Visuals & Fast Travel
    HostileESP = true,
    FriendlyESP = false,
    ItemESP = true,
    BusESP = true,
    ESPMaxDistance = 800,
    ClickToTeleport = false,

    -- UI & System
    AntiAFK = true,
    UIVisible = true,
    UIKeybind = Enum.KeyCode.RightShift,
}

local CONFIG_FILE = "last_stop_config.json"

local function SaveConfig()
    if writefile then
        pcall(function()
            writefile(CONFIG_FILE, HttpService:JSONEncode(Config))
        end)
    end
end

local function LoadConfig()
    if isfile and readfile and isfile(CONFIG_FILE) then
        pcall(function()
            local decoded = HttpService:JSONDecode(readfile(CONFIG_FILE))
            if type(decoded) == "table" then
                for k, v in pairs(decoded) do
                    if Config[k] ~= nil and type(Config[k]) == type(v) then
                        Config[k] = v
                    end
                end
            end
        end)
    end
end

LoadConfig()

local ToggleUpdaters = {}
local function SetToggleState(configKey, val)
    Config[configKey] = val
    if ToggleUpdaters[configKey] then
        pcall(function() ToggleUpdaters[configKey](val) end)
    end
end

-- ========================================================================
-- PLAYER HELPERS
-- ========================================================================
local function GetCharacter()
    return LocalPlayer.Character or (PlayerContainer and PlayerContainer:FindFirstChild(LocalPlayer.Name))
end

local function GetHRP()
    local char = GetCharacter()
    return char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
end

local function GetHumanoid()
    local char = GetCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetPlayerComponent()
    if Knit and Knit.Components and Knit.Components.Player then
        return Knit.Components.Player:FromInstance(LocalPlayer)
    end
    return nil
end

local function GetPlayerReplicaData()
    local comp = GetPlayerComponent()
    return comp and comp.Replica and comp.Replica.Data
end

local function TeleportToCFrame(targetCF)
    local hrp = GetHRP()
    local hum = GetHumanoid()
    if hrp and targetCF then
        if hum and hum.Sit then
            hum.Sit = false
            task.wait(0.05)
        end
        local cf = typeof(targetCF) == "CFrame" and targetCF or CFrame.new(targetCF)
        pcall(function()
            hrp.CFrame = cf + Vector3.new(0, 3, 0)
            hrp.Velocity = Vector3.zero
            hrp.RotVelocity = Vector3.zero
            if hrp.AssemblyLinearVelocity then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
        end)
    end
end

-- ========================================================================
-- ANTI-SCREEN SHAKE & CAMERA STABILITY ENGINE
-- ========================================================================
local function ApplyNoScreenShake(enabled)
    if not CameraController then return end

    if enabled then
        if not OriginalCameraMethods.Recoil then
            OriginalCameraMethods.Recoil = CameraController.Recoil
            OriginalCameraMethods.Shake = CameraController.Shake
            OriginalCameraMethods.ShakeOnce = CameraController.ShakeOnce
            local cs = CameraController.CameraShaker
            if cs then
                OriginalCameraMethods.CSUpdate = cs.Update
                OriginalCameraMethods.CSShake = cs.Shake
                OriginalCameraMethods.CSShakeOnce = cs.ShakeOnce
                OriginalCameraMethods.CSShakeSustain = cs.ShakeSustain
            end
        end

        pcall(function()
            CameraController:SetShakeEnabled(false)
            CameraController.Recoil = function() end
            CameraController.Shake = function() end
            CameraController.ShakeOnce = function() end

            local cs = CameraController.CameraShaker
            if cs then
                cs._posAddShake = Vector3.zero
                cs._rotAddShake = Vector3.zero
                cs.Update = function() return CFrame.identity end
                cs.Shake = function() end
                cs.ShakeOnce = function() end
                cs.ShakeSustain = function() end
                if type(cs._camShakeInstances) == "table" then
                    table.clear(cs._camShakeInstances)
                end
            end
        end)
    else
        pcall(function()
            CameraController:SetShakeEnabled(true)
            if OriginalCameraMethods.Recoil then
                CameraController.Recoil = OriginalCameraMethods.Recoil
                CameraController.Shake = OriginalCameraMethods.Shake
                CameraController.ShakeOnce = OriginalCameraMethods.ShakeOnce
            end
            local cs = CameraController.CameraShaker
            if cs and OriginalCameraMethods.CSUpdate then
                cs.Update = OriginalCameraMethods.CSUpdate
                cs.Shake = OriginalCameraMethods.CSShake
                cs.ShakeOnce = OriginalCameraMethods.CSShakeOnce
                cs.ShakeSustain = OriginalCameraMethods.CSShakeSustain
            end
        end)
    end
end

ApplyNoScreenShake(Config.NoCameraShake)

RegisterConnection(RunService.RenderStepped:Connect(function()
    if Config.NoCameraShake and CameraController then
        local cs = CameraController.CameraShaker
        if cs then
            cs._posAddShake = Vector3.zero
            cs._rotAddShake = Vector3.zero
            if type(cs._camShakeInstances) == "table" and #cs._camShakeInstances > 0 then
                table.clear(cs._camShakeInstances)
            end
        end
    end
end))

-- ========================================================================
-- 1. COMBAT & THREAT ANNIHILATION ENGINE
-- ========================================================================
local function IsEntityHostile(model)
    if not model or not model.Parent then return false end
    if not CollectionService:HasTag(model, "Entity") then return false end
    
    if EntityController and EntityController.Entities then
        local ent = EntityController.Entities[model] or EntityController.Entities[model.Name]
        if ent and ent.Replica and ent.Replica.Data then
            if ent.Replica.Data.Friendly == true then return false end
            if ent.Replica.Data.Active == false then return false end
            if ent.Replica.Data.Health and ent.Replica.Data.Health <= 0 then return false end
        end
    end

    local entType = model:GetAttribute("Type")
    if entType == "ShopKeeper" or entType == "Guard" then return false end
    if model:GetAttribute("Friendly") == true then return false end

    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then return false end

    return true
end

local CachedHostiles = {}
local LastHostileScanTime = 0

local function GetHostileEntities()
    local now = os.clock()
    if now - LastHostileScanTime < 0.08 and #CachedHostiles > 0 then
        local valid = true
        for _, ent in ipairs(CachedHostiles) do
            if not ent.Model or not ent.Model.Parent then
                valid = false
                break
            end
        end
        if valid then return CachedHostiles end
    end
    LastHostileScanTime = now

    local hostiles = {}
    local hrp = GetHRP()
    if not hrp then return hostiles end

    local tagged = CollectionService:GetTagged("Entity")
    for _, model in ipairs(tagged) do
        if model:IsA("Model") and IsEntityHostile(model) then
            local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model.PrimaryPart
            if root then
                local dist = (hrp.Position - root.Position).Magnitude
                table.insert(hostiles, {
                    Model = model,
                    Root = root,
                    Distance = dist,
                    Type = model:GetAttribute("Type") or "Monster"
                })
            end
        end
    end

    CachedHostiles = hostiles
    return hostiles
end

-- ========================================================================
-- VAULT VAMPIRE SWORD DYNAMIC FETCH/STORE CONTROLLER
-- ========================================================================
local VaultAuraState = {
    IsHoldingVampireFromVault = false,
    CurrentSwordToolId = nil,
    PreviousEquippedTool = nil,
    LastHostileSeen = 0,
    IsUnstoring = false,
    IsStoring = false,
    VaultHasNoVampire = false,
}

local function ResolveItemObject(toolInstance)
    if not toolInstance then return nil end
    local toolId = toolInstance.Name
    if ItemController then
        -- 1. Direct replica from ItemController (supports all un-stored weapons)
        if ItemController.GetItemReplica then
            local rep = ItemController:GetItemReplica(toolId)
            if rep then
                return {
                    Replica = rep,
                    Config = rep.Tags,
                    Instance = toolInstance
                }
            end
        end
        if ItemController.TryGetItemReplica then
            local rep = ItemController:TryGetItemReplica(toolId)
            if rep then
                return {
                    Replica = rep,
                    Config = rep.Tags,
                    Instance = toolInstance
                }
            end
        end
        if ItemController.GetItemByInstance then
            local obj = ItemController:GetItemByInstance(toolInstance)
            if obj then return obj end
        end
        if ItemController.Cache and ItemController.Cache.Items then
            local obj = ItemController.Cache.Items[toolId]
            if obj then return obj end
        end
        if ItemController.GetHoldingItem then
            local holding = ItemController:GetHoldingItem()
            if holding and holding.Name == toolId then
                return holding
            end
        end
    end
    if Knit and Knit.Components and Knit.Components.Item then
        local obj = Knit.Components.Item:FromId(toolId)
        if obj then return obj end
    end
    return nil
end

local function IsSwordItem(tool, itemObj)
    if not tool then return false end
    local tName = tool.Name:lower()
    if tName:find("sword") or tName:find("vampire") or tName:find("katana") or tName:find("blade") or tName:find("saber") then
        return true
    end
    local tag = itemObj and itemObj.Replica and itemObj.Replica.Tags and itemObj.Replica.Tags.Name
    if tag then
        local tagName = tostring(tag):lower()
        if tagName:find("sword") or tagName:find("vampire") or tagName:find("katana") or tagName:find("blade") or tagName:find("saber") then
            return true
        end
    end
    local cName = itemObj and itemObj.Config and itemObj.Config.Name
    if cName then
        local cfgName = tostring(cName):lower()
        if cfgName:find("sword") or cfgName:find("vampire") or cfgName:find("katana") or cfgName:find("blade") or cfgName:find("saber") then
            return true
        end
    end
    return false
end

local function IsUtilityTool(tool, itemObj)
    if not tool then return false end
    local tName = tool.Name:lower()
    if tName:find("hammer") or tName:find("shovel") or tName:find("wrench") or tName:find("torch") or tName:find("wood") or tName:find("fuel") then
        return true
    end
    local tag = itemObj and itemObj.Replica and itemObj.Replica.Tags and itemObj.Replica.Tags.Name
    if tag then
        local tagName = tostring(tag):lower()
        if tagName:find("hammer") or tagName:find("shovel") or tagName:find("wrench") then
            return true
        end
    end
    return false
end

local function GetItemNameAndObj(id)
    if not id then return nil, nil end
    local itemObj = (ItemController and ItemController.Cache and ItemController.Cache.Items and ItemController.Cache.Items[id])
        or (Knit and Knit.Components and Knit.Components.Item and Knit.Components.Item:FromId(id))
    if itemObj and itemObj.Replica and itemObj.Replica.Tags then
        return itemObj.Replica.Tags.Name, itemObj
    end
    return nil, nil
end

local function IsValidActiveTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    local rep = ItemController and ItemController:GetItemReplica(tool.Name)
    if rep and rep.IsActive and not rep:IsActive() then
        pcall(function() tool:Destroy() end)
        return false
    end
    return true
end

local function FindVampireSwordInInventory()
    local char = GetCharacter()
    local bp = LocalPlayer:FindFirstChild("Backpack")

    -- 1. Check Character for equipped sword
    if char then
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") and IsValidActiveTool(child) then
                local obj = ResolveItemObject(child)
                local name = obj and obj.Config and obj.Config.Name or GetItemNameAndObj(child.Name)
                if (name and (name == "VampireSword" or name:lower():find("sword") or name:lower():find("vampire"))) or IsSwordItem(child, obj) then
                    return child, obj, true
                end
            end
        end
    end

    -- 2. Check Backpack for any sword (Vampire Sword has top priority)
    if bp then
        -- Pass A: Exact Vampire Sword
        for _, child in ipairs(bp:GetChildren()) do
            if child:IsA("Tool") and IsValidActiveTool(child) then
                local obj = ResolveItemObject(child)
                local name = obj and obj.Config and obj.Config.Name or GetItemNameAndObj(child.Name)
                if (name and name == "VampireSword") or (name and name:lower():find("vampire")) or child.Name:lower():find("vampire") then
                    return child, obj, false
                end
            end
        end
        -- Pass B: Any other Sword / Katana / Blade
        for _, child in ipairs(bp:GetChildren()) do
            if child:IsA("Tool") and IsValidActiveTool(child) then
                local obj = ResolveItemObject(child)
                local name = obj and obj.Config and obj.Config.Name or GetItemNameAndObj(child.Name)
                if (name and name:lower():find("sword")) or IsSwordItem(child, obj) then
                    return child, obj, false
                end
            end
        end
    end

    return nil, nil, false
end

local function FindVampireSwordInVault()
    local vaultComp = InterfaceController and InterfaceController.GetComponent and InterfaceController:GetComponent("Vault")
    local rep = vaultComp and vaultComp.GetReplica and vaultComp:GetReplica()
    local items = rep and rep.Data and rep.Data.Vault and rep.Data.Vault.Items
    if items then
        -- Pass A: Exact Vampire Sword
        for slotIdx, item in ipairs(items) do
            if item.Name == "VampireSword" or tostring(item.Name):lower():find("vampire") then
                return slotIdx, item.Id
            end
        end
        -- Pass B: Any Sword / Katana / Blade in Vault
        for slotIdx, item in ipairs(items) do
            local iName = tostring(item.Name or ""):lower()
            if iName:find("sword") or iName:find("katana") or iName:find("blade") then
                return slotIdx, item.Id
            end
        end
    end
    return nil, nil
end

local function PullVampireSwordFromVault()
    if VaultAuraState.IsUnstoring or VaultAuraState.IsStoring then return false end
    if not VaultService then return false end

    -- Already in inventory?
    local existingTool, existingObj, isEquipped = FindVampireSwordInInventory()
    if existingTool then
        if not isEquipped then
            local hum = GetHumanoid()
            if hum then hum:EquipTool(existingTool) end
        end
        return true
    end

    local slotIdx, itemId = FindVampireSwordInVault()
    if not slotIdx then
        local vaultComp = InterfaceController and InterfaceController.GetComponent and InterfaceController:GetComponent("Vault")
        local rep = vaultComp and vaultComp.GetReplica and vaultComp:GetReplica()
        if rep and rep.Data and rep.Data.Vault and rep.Data.Vault.Items then
            VaultAuraState.VaultHasNoVampire = true
        end
        return false
    end

    local char = GetCharacter()
    if char then
        local equipped = char:FindFirstChildOfClass("Tool")
        if equipped and equipped.Name ~= itemId then
            VaultAuraState.PreviousEquippedTool = equipped
        end
    end

    VaultAuraState.IsUnstoring = true
    pcall(function()
        VaultService:UnstoreItem(tonumber(slotIdx))
    end)

    local t0 = os.clock()
    local tool, toolObj = nil, nil
    while os.clock() - t0 < 1.5 do
        tool, toolObj = FindVampireSwordInInventory()
        if tool then break end
        task.wait(0.05)
    end

    VaultAuraState.IsUnstoring = false

    if tool then
        VaultAuraState.IsHoldingVampireFromVault = true
        VaultAuraState.CurrentSwordToolId = tool.Name
        local hum = GetHumanoid()
        if hum and tool.Parent ~= GetCharacter() then
            hum:EquipTool(tool)
        end
        return true
    end

    return false
end

local function GetVaultPart()
    local container = workspace:FindFirstChild("CHUNKS_CONTAINER")
    if container then
        for _, desc in ipairs(container:GetDescendants()) do
            if desc.Name == "Vault" and desc:IsA("BasePart") then
                return desc
            end
        end
    end
    return nil
end

local function GetInventorySwords()
    local list = {}
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local char = GetCharacter()

    local function check(tool)
        if not tool or not tool:IsA("Tool") then return end
        local toolId = tool.Name

        local rep = ItemController and ItemController:GetItemReplica(toolId)
        if not rep and ItemController and ItemController.TryGetItemReplica then
            rep = ItemController:TryGetItemReplica(toolId)
        end
        if rep and rep.IsActive and not rep:IsActive() then
            pcall(function() tool:Destroy() end)
            return
        end

        local realName = nil
        if rep then
            realName = (rep.Tags and rep.Tags.Name) or (rep.Data and rep.Data.Item and rep.Data.Item.Name)
        end
        if not realName then
            local obj = ResolveItemObject(tool)
            if obj and obj.Config and obj.Config.Name then
                realName = obj.Config.Name
            elseif obj and obj.Replica and obj.Replica.Tags then
                realName = obj.Replica.Tags.Name
            end
        end
        if not realName then
            for _, attr in ipairs({"ItemName", "Name", "ToolName", "ItemType", "WeaponType"}) do
                local val = tool:GetAttribute(attr)
                if val and tostring(val) ~= "" then realName = tostring(val) break end
            end
        end
        if not realName then
            realName = (tool.ToolTip and tool.ToolTip ~= "") and tool.ToolTip or tool.Name
        end

        local rLower = tostring(realName):lower()
        local isUtility = rLower:find("shovel") or rLower:find("hammer") or rLower:find("wrench") or rLower:find("torch") or rLower:find("wood") or rLower:find("fuel")

        local isSword = (not isUtility) and (
            (toolId == VaultAuraState.CurrentSwordToolId) or
            rLower:find("sword") or
            rLower:find("vampire") or
            rLower:find("blade") or
            rLower:find("katana") or
            rLower:find("saber") or
            rLower:find("dagger") or
            IsSwordItem(tool, ResolveItemObject(tool))
        )

        if isSword then
            table.insert(list, tool)
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

local function ForceStoreSwordToVault()
    local swords = GetInventorySwords()
    if #swords == 0 then
        VaultAuraState.IsHoldingVampireFromVault = false
        VaultAuraState.CurrentSwordToolId = nil
        VaultAuraState.VaultHasNoVampire = false
        return true, "No swords in inventory (Already stored)"
    end

    if not VaultService then
        warn("[Vault] VaultService not available")
        return false, "VaultService not available"
    end

    local hrp = GetHRP()
    local hum = GetHumanoid()
    if not hrp or not hum then
        return false, "Character not ready"
    end

    -- 1. Restore physics & teleport to known Start Terminal Vault coordinates to stream Chunk 1
    local char = GetCharacter()
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                if part.Name ~= "HumanoidRootPart" then part.CanCollide = true end
                part.Velocity = Vector3.zero
                if part.AssemblyLinearVelocity then part.AssemblyLinearVelocity = Vector3.zero end
            end
        end
    end
    hrp.CFrame = CFrame.new(330.62, 107.5, 315.28)
    task.wait(0.4) -- Wait for Chunk 1 to stream in

    -- 2. Locate dynamic Vault Part and align
    local vaultPart = GetVaultPart()
    if vaultPart then
        hrp.CFrame = CFrame.new(vaultPart.Position + Vector3.new(0, 2.5, 2))
    end
    task.wait(0.2)

    -- 3. Unequip any held tools
    hum:UnequipTools()
    task.wait(0.15)

    -- 4. Trigger proximity prompt to establish server focus
    if vaultPart then
        local prompt = vaultPart:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            pcall(function() fireproximityprompt(prompt, 0) end)
        end
    end
    task.wait(0.2)

    VaultAuraState.IsStoring = true

    -- Store each sword
    for _, sTool in ipairs(swords) do
        local toolId = sTool.Name
        pcall(function() VaultService:StoreItem(toolId) end)
        pcall(function()
            local rf = ReplicatedStorage.ClientSource.Mutual.Packages.Knit.Services.VaultService.RF.StoreItem
            if rf then rf:InvokeServer(toolId) end
        end)
        task.wait(0.2)
    end

    -- Verification loop up to 5.0 seconds
    local t0 = os.clock()
    while os.clock() - t0 < 5.0 do
        local rem = GetInventorySwords()
        if #rem == 0 then break end
        hum:UnequipTools()
        for _, remTool in ipairs(rem) do
            pcall(function() VaultService:StoreItem(remTool.Name) end)
            pcall(function()
                local rf = ReplicatedStorage.ClientSource.Mutual.Packages.Knit.Services.VaultService.RF.StoreItem
                if rf then rf:InvokeServer(remTool.Name) end
            end)
        end
        task.wait(0.25)
    end

    VaultAuraState.IsStoring = false
    VaultAuraState.IsHoldingVampireFromVault = false
    VaultAuraState.CurrentSwordToolId = nil
    VaultAuraState.VaultHasNoVampire = false

    local finalRem = GetInventorySwords()
    if #finalRem == 0 then
        pcall(function()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if pg and pg.Main and pg.Main:FindFirstChild("Container") and pg.Main.Container:FindFirstChild("Vault") then
                pg.Main.Container.Vault.Visible = false
            end
        end)
        return true, "All swords safely stored in Vault"
    else
        return false, string.format("%d swords could not be stored", #finalRem)
    end
end

local function StoreVampireSwordToVault()
    return ForceStoreSwordToVault()
end

local function SetupAutoReexec()
    if not queue_on_teleport then return end
    pcall(function()
        queue_on_teleport([[
            repeat task.wait(0.5) until game:IsLoaded() and game.Players.LocalPlayer
            task.wait(2.0)
            if game.PlaceId == 85967844112283 then
                -- IN LOBBY: Auto-create Nightmare room & press Start
                if isfile and isfile("last_stop_loader.lua") then
                    loadstring(readfile("last_stop_loader.lua"))()
                end
            elseif game.PlaceId == 122776220269735 then
                -- IN GAME MATCH: Run auto-farm suite
                if isfile and isfile("last_stop_auto_farm.lua") then
                    loadstring(readfile("last_stop_auto_farm.lua"))()
                elseif isfile and isfile("lua/games/last-stop/script.lua") then
                    loadstring(readfile("lua/games/last-stop/script.lua"))()
                end
            end
        ]])
    end)
end

local function TriggerNewGameRestart()
    AutoFarmState.StatusMessage = "Loop Farm: Returning to Lobby..."
    
    Config.AutoRevive = false
    Config.AutoHeal = false
    Config.AntiVoid = false
    
    -- If verified return_to_lobby.lua is present, execute it directly
    if isfile and isfile("return_to_lobby.lua") then
        local ok = pcall(function()
            local mod = loadstring(readfile("return_to_lobby.lua"))()
            if type(mod) == "table" and mod.Execute then
                mod.Execute({ StoreSword = false })
            end
        end)
        if ok then return end
    end

    SetupAutoReexec()

    -- Embedded identical execution from return_to_lobby.lua
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
end

-- ========================================================================
-- AUTOMATIC INTRO, CUTSCENE & WAIT TIMER AUTO-SKIP ENGINE
-- ========================================================================
local function UnfreezePlayer()
    -- 1. CharacterController unlock
    pcall(function()
        local cc = Knit and Knit.GetController("CharacterController")
        if cc then
            if cc.Lock then cc:Lock(false) end
            local pInfo = cc.Get and cc:Get()
            if pInfo then
                pInfo.Locked = false
                if pInfo.Humanoid then
                    pInfo.Humanoid.WalkSpeed = (Config.SpeedEnabled and Config.WalkSpeed) or (cc.DEFAULT_WALKSPEED or 16)
                    pInfo.Humanoid.JumpPower = cc.DEFAULT_JUMP_POWER or 50
                    pInfo.Humanoid.AutoRotate = true
                    pcall(function() pInfo.Humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
                end
                if pInfo.HumanoidRootPart then
                    pInfo.HumanoidRootPart.Anchored = false
                end
            end
        end
    end)

    -- 2. Direct Humanoid & HRP restoration
    pcall(function()
        local char = GetCharacter()
        local hum = GetHumanoid()
        local hrp = GetHRP()
        if hrp then hrp.Anchored = false end
        if hum then
            hum.WalkSpeed = (Config.SpeedEnabled and Config.WalkSpeed) or 16
            hum.JumpPower = 50
            hum.AutoRotate = true
            hum.PlatformStand = false
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
        end
    end)

    -- 3. Camera restoration from Scriptable to Custom
    pcall(function()
        local cam = workspace.CurrentCamera
        if cam then
            cam.CameraType = Enum.CameraType.Custom
            local hum = GetHumanoid()
            if hum then cam.CameraSubject = hum end
        end
        local cameraClaim = require(ReplicatedStorage.ClientSource.Mutual.Shared.CameraClaim)
        if cameraClaim and cameraClaim.Release then
            if CutsceneController and CutsceneController.Managers then
                for mgrKey, mgrVal in pairs(CutsceneController.Managers) do
                    pcall(function() cameraClaim.Release(mgrVal.Manager or mgrKey) end)
                end
            end
        end
    end)

    -- 4. Unsuppress HUD
    pcall(function()
        local ic = Knit and Knit.GetController("InterfaceController")
        if ic and ic.SuppressHUD then
            ic:SuppressHUD(false)
        end
    end)
end

local function PerformCutsceneAndIntroSkip()
    if not Config.AutoSkipIntro then return end

    -- 1. Knit CutsceneController: destroy managers and notify server with exact IDs
    pcall(function()
        if CutsceneController then
            if CutsceneController.Managers then
                for id, j in pairs(CutsceneController.Managers) do
                    j.Skippable = true
                    pcall(function()
                        local cs = CutsceneService or (Knit and Knit.GetService("CutsceneService"))
                        if cs and cs.SkipCutscene and cs.SkipCutscene.Fire then
                            cs.SkipCutscene:Fire(id)
                        end
                        local re = ReplicatedStorage:FindFirstChild("CutsceneService", true)
                        local skipRe = re and re:FindFirstChild("SkipCutscene", true)
                        if skipRe and skipRe:IsA("RemoteEvent") then
                            skipRe:FireServer(id)
                        end
                    end)
                    if j.Manager and not j.Manager.Finished then
                        pcall(function() j.Manager:Destroy() end)
                    end
                end
            end
            if CutsceneController.Skip then
                CutsceneController:Skip()
            end
        end
    end)

    -- 2. Knit CutsceneService RemoteEvent general fallback
    pcall(function()
        local cs = CutsceneService or (Knit and Knit.GetService("CutsceneService"))
        if cs and cs.RE and cs.RE:FindFirstChild("SkipCutscene") then
            cs.RE.SkipCutscene:FireServer()
        end
        if cs and cs.SkipCutscene and cs.SkipCutscene.Fire then
            cs.SkipCutscene:Fire()
        end
    end)

    -- 3. SiegeService VoteSkip (skip the match start countdown wait)
    pcall(function()
        local ss = SiegeService or (Knit and Knit.GetService("SiegeService"))
        if ss and ss.RF and ss.RF:FindFirstChild("VoteSkip") then
            ss.RF.VoteSkip:InvokeServer()
        end
    end)

    -- 4. Dialogue dismissal
    pcall(function()
        local ds = Knit and Knit.GetService("DialogueService")
        if ds and ds.RF and ds.RF:FindFirstChild("DialogueEnded") then
            ds.RF.DialogueEnded:InvokeServer()
        end
    end)

    -- 5. Click GUI Skip Buttons
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        local function click(btn)
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

        -- Target A: Main.CutsceneSkip
        pcall(function()
            local cs = pg:FindFirstChild("Main") and pg.Main:FindFirstChild("CutsceneSkip")
            if cs and cs:IsA("GuiButton") and cs.Visible then
                click(cs)
            end
        end)

        -- Target B: Main.HUD.BusRushTutorial.Skip (Skip 7-step intro tutorial)
        pcall(function()
            local br = pg:FindFirstChild("Main") and pg.Main:FindFirstChild("HUD") and pg.Main.HUD:FindFirstChild("BusRushTutorial")
            local brSkip = br and br:FindFirstChild("Skip", true)
            if br and br.Visible and brSkip and brSkip:IsA("GuiButton") then
                click(brSkip)
            end
        end)

        -- Target C: Main.HUD.SiegeControls.Skip ("SKIP WAIT")
        pcall(function()
            local sc = pg:FindFirstChild("Main") and pg.Main:FindFirstChild("HUD") and pg.Main.HUD:FindFirstChild("SiegeControls")
            local scSkip = sc and sc:FindFirstChild("Skip", true)
            if sc and sc.Visible and scSkip and scSkip:IsA("GuiButton") then
                click(scSkip)
            end
        end)

        -- Target D: Any visible button containing "skip"
        pcall(function()
            for _, desc in ipairs(pg:GetDescendants()) do
                if desc:IsA("GuiButton") and desc.Visible then
                    local n = desc.Name:lower()
                    local t = ""
                    if desc:IsA("TextButton") then
                        t = desc.Text:lower()
                    else
                        local lbl = desc:FindFirstChildOfClass("TextLabel")
                        if lbl then t = lbl.Text:lower() end
                    end
                    if n:find("skip") or t:find("skip") then
                        click(desc)
                    end
                end
            end
        end)
    end

    -- 6. Immediately unfreeze the character, unlock controls, restore camera & HUD
    UnfreezePlayer()
end

-- Active match-start skip watcher (runs aggressively for the first 35 seconds of match load)
task.spawn(function()
    local t0 = os.clock()
    while os.clock() - t0 < 35.0 do
        if Config.AutoSkipIntro then
            PerformCutsceneAndIntroSkip()
            UnfreezePlayer()
        end
        task.wait(0.2)
    end
end)

-- Continuous event-driven listeners for mid-match cutscenes (bosses, transitions)
pcall(function()
    if CutsceneController and CutsceneController.CutsceneStarted then
        CutsceneController.CutsceneStarted:Connect(function()
            if Config.AutoSkipIntro then
                task.wait(0.05)
                PerformCutsceneAndIntroSkip()
                UnfreezePlayer()
            end
        end)
    end
end)

pcall(function()
    local cs = CutsceneService or (Knit and Knit.GetService("CutsceneService"))
    if cs and cs.RE and cs.RE:FindFirstChild("BeginCutscene") then
        cs.RE.BeginCutscene.OnClientEvent:Connect(function()
            if Config.AutoSkipIntro then
                task.wait(0.05)
                PerformCutsceneAndIntroSkip()
                UnfreezePlayer()
            end
        end)
    end
end)

pcall(function()
    local pg = LocalPlayer:WaitForChild("PlayerGui", 10)
    if pg then
        pg.DescendantAdded:Connect(function(desc)
            if Config.AutoSkipIntro and desc:IsA("GuiButton") then
                local n = desc.Name:lower()
                if n:find("skip") then
                    task.wait(0.05)
                    PerformCutsceneAndIntroSkip()
                    UnfreezePlayer()
                end
            end
        end)
    end
end)

-- Continuous Anti-Freeze Guard: guarantees character is never paralyzed while AutoSkipIntro is enabled
task.spawn(function()
    while true do
        task.wait(0.3)
        if Config.AutoSkipIntro then
            local shouldUnfreeze = false
            pcall(function()
                local cc = Knit and Knit.GetController("CharacterController")
                if cc then
                    if cc.IsLocked and cc:IsLocked() then
                        shouldUnfreeze = true
                    else
                        local pInfo = cc.Get and cc:Get()
                        if pInfo and pInfo.Locked then
                            shouldUnfreeze = true
                        end
                    end
                end
            end)
            pcall(function()
                local cam = workspace.CurrentCamera
                if cam and cam.CameraType == Enum.CameraType.Scriptable then
                    shouldUnfreeze = true
                end
            end)
            if shouldUnfreeze then
                PerformCutsceneAndIntroSkip()
                UnfreezePlayer()
            end
        end
    end
end)

local function GetActiveWeaponObject()
    local char = GetCharacter()
    if not char then return nil, nil end

    -- Priority 1: Vampire Sword / Any Sword
    local swordTool, swordObj, isEquipped = FindVampireSwordInInventory()
    if swordTool then
        if not isEquipped then
            local hum = GetHumanoid()
            if hum then hum:EquipTool(swordTool) end
        end
        return swordObj or ResolveItemObject(swordTool), swordTool
    end

    -- Priority 2: Currently equipped non-utility weapon
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            local itemObj = ResolveItemObject(child)
            if not IsUtilityTool(child, itemObj) then
                if itemObj and itemObj.Replica then
                    return itemObj, child
                end
            end
        end
    end

    -- Priority 3: Backpack Melee / Firearm (non-utility)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        local hum = GetHumanoid()
        for _, child in ipairs(backpack:GetChildren()) do
            if child:IsA("Tool") then
                local itemObj = ResolveItemObject(child)
                if not IsUtilityTool(child, itemObj) then
                    if itemObj and itemObj.Config and (itemObj.Config.Type == "Melee" or itemObj.Config.Type == "Firearm") then
                        if hum then hum:EquipTool(child) end
                        return itemObj, child
                    end
                end
            end
        end
    end

    -- Priority 4: Last resort - utility tool in hand (Hammer/Shovel)
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            local itemObj = ResolveItemObject(child)
            if itemObj and itemObj.Replica then
                return itemObj, child
            end
        end
    end

    return nil, nil
end

local function EnsureEquippedCombatWeapon()
    local char = GetCharacter()
    local hum = GetHumanoid()
    if not char or not hum then return nil, nil end

    -- 1. If currently equipped tool in Character is ALREADY a Sword, return it immediately
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            local itemObj = ResolveItemObject(child)
            if IsSwordItem(child, itemObj) then
                return itemObj, child
            end
        end
    end

    -- 2. If Vampire Sword (or any sword) exists in inventory/backpack, equip it immediately!
    local vTool, vObj, vEquipped = FindVampireSwordInInventory()
    if vTool then
        if not vEquipped then
            hum:EquipTool(vTool)
        end
        return vObj or ResolveItemObject(vTool), vTool
    end

    -- 3. If VaultVampireSword enabled and vault hasn't been confirmed empty, check vault
    if Config.VaultVampireSword and not VaultAuraState.VaultHasNoVampire then
        local slotIdx, itemId = FindVampireSwordInVault()
        if slotIdx then
            if not VaultAuraState.IsUnstoring and not VaultAuraState.IsStoring then
                task.spawn(PullVampireSwordFromVault)
            end
            local cur = char:FindFirstChildOfClass("Tool")
            if cur then
                return ResolveItemObject(cur), cur
            end
        else
            local vaultComp = InterfaceController and InterfaceController.GetComponent and InterfaceController:GetComponent("Vault")
            local rep = vaultComp and vaultComp.GetReplica and vaultComp:GetReplica()
            if rep and rep.Data and rep.Data.Vault and rep.Data.Vault.Items then
                VaultAuraState.VaultHasNoVampire = true
            end
        end
    end

    -- 4. If currently equipped tool is a non-utility combat weapon (e.g. Firearm), return it
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            local itemObj = ResolveItemObject(child)
            if not IsUtilityTool(child, itemObj) then
                if itemObj and itemObj.Replica then
                    return itemObj, child
                end
            end
        end
    end

    -- 5. Equip best combat weapon from Backpack (Non-utility: Firearm, Melee, etc.)
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, child in ipairs(bp:GetChildren()) do
            if child:IsA("Tool") then
                local itemObj = ResolveItemObject(child)
                if not IsUtilityTool(child, itemObj) then
                    if itemObj and itemObj.Config and (itemObj.Config.Type == "Melee" or itemObj.Config.Type == "Firearm") then
                        hum:EquipTool(child)
                        return itemObj, child
                    end
                end
            end
        end
    end

    -- 6. Last resort: If the player ONLY has utility tools (Hammer, Shovel), use what is available
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            local itemObj = ResolveItemObject(child)
            if itemObj and itemObj.Replica then
                return itemObj, child
            end
        end
    end

    if bp then
        for _, child in ipairs(bp:GetChildren()) do
            if child:IsA("Tool") then
                local itemObj = ResolveItemObject(child)
                if itemObj and itemObj.Replica then
                    hum:EquipTool(child)
                    return itemObj, child
                end
            end
        end
    end

    return nil, nil
end

local function GetEnemyDimensions(targetRoot)
    if not targetRoot or not targetRoot.Parent then
        local p = targetRoot and targetRoot.Position or Vector3.new(0, 100, 0)
        return p.Y - 2.5, 5.0, 3.0, 3.0
    end
    local model = targetRoot:FindFirstAncestorOfClass("Model") or targetRoot.Parent
    local height = 5.0
    local depth = 3.0
    local width = 3.0
    local bottomY = targetRoot.Position.Y - 2.5

    if model and model:IsA("Model") then
        local ok, cf, size = pcall(function() return model:GetBoundingBox() end)
        if ok and size and size.Y > 0 then
            height = size.Y
            depth = size.Z
            width = size.X
            bottomY = cf.Position.Y - (size.Y * 0.5)
        end
    end
    return bottomY, height, depth, width
end

local function DispatchStrike(targetRoot)
    if not targetRoot or not targetRoot.Parent then return end
    local weaponObj, tool = GetActiveWeaponObject()
    if not weaponObj then return end

    local bottomY, enemyHeight = GetEnemyDimensions(targetRoot)
    local hrp = GetHRP()
    local origin = hrp and hrp.Position or Camera.CFrame.Position

    -- Hit target at its lower extremity / feet so distance is within valid melee reach:
    local hitY = math.clamp(bottomY + 1.2, origin.Y + 0.5, targetRoot.Position.Y)
    local hitPos = Vector3.new(targetRoot.Position.X, hitY, targetRoot.Position.Z)
    local hitNormal = Vector3.new(0, 1, 0)
    local hitMaterial = Enum.Material.Plastic

    pcall(function()
        if weaponObj.Replica then
            if weaponObj.Config and weaponObj.Config.Type == "Firearm" then
                weaponObj.Replica:FireServer("Firearm", "Fire", targetRoot.Position, {targetRoot.Position}, nil)
            else
                local viewDir = (hitPos - origin).Unit
                weaponObj.Replica:FireServer("Melee", "Attack", viewDir, 1)
                weaponObj.Replica:FireServer("Melee", "Hit", targetRoot, hitPos, hitNormal, hitMaterial)
            end
        end
    end)
end

local LastUnderneathCollisionDisable = 0

local function ApplyUnderneathPosition(targetRoot)
    if not targetRoot or not targetRoot.Parent then return end
    local char = GetCharacter()
    local hrp = GetHRP()
    local hum = GetHumanoid()
    if not char or not hrp or not hum then return end

    local now = os.clock()
    -- Noclip, Touch Immunity & Spatial Query Disabling (Throttled to 0.5s instead of every frame):
    if now - LastUnderneathCollisionDisable > 0.5 then
        LastUnderneathCollisionDisable = now
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
                part.CanTouch = false
                part.CanQuery = false
            end
        end
    end

    local bottomY, enemyHeight, enemyDepth = GetEnemyDimensions(targetRoot)
    local mName = (targetRoot.Parent and targetRoot.Parent.Name) or ""
    local mType = (targetRoot.Parent and targetRoot.Parent:GetAttribute("Type")) or ""
    local isGiant = enemyHeight > 6.5 
        or mName:find("Big") or mName:find("Ogre") or mName:find("Mutant") or mName:find("Juggernaut") or mName:find("Bloater")
        or mType:find("Big") or mType:find("Ogre") or mType:find("Mutant") or mType:find("Juggernaut") or mType:find("Bloater")

    local lookDir = targetRoot.CFrame.LookVector
    if lookDir.Magnitude < 0.1 then lookDir = Vector3.new(0, 0, -1) end
    local flatLook = Vector3.new(lookDir.X, 0, lookDir.Z).Unit

    local targetPos, finalCF
    if isGiant then
        -- REAR BLIND SPOT ANCHOR FOR GIANTS/BOSSES:
        -- Monster attack hitboxes (GroundSmash, GroundCrush, Melee) are strictly forward-facing (Offset = (0,0,-14..-32))
        -- We place the player 3.8 studs behind the monster's rear surface and 3.5 studs below feet level
        -- Total distance to strike feet point is ~7.5 studs, well within Vampire Sword's 10-stud reach
        local backDistance = (enemyDepth * 0.5) + 3.8
        local targetY = math.max(bottomY - 3.5, 96.0)
        targetPos = Vector3.new(targetRoot.Position.X, targetY, targetRoot.Position.Z) - (flatLook * backDistance)
        finalCF = CFrame.lookAt(targetPos, targetPos + flatLook)
    else
        -- STANDARD MOB UNDERGROUND HOVER:
        -- Clamp depth between 2.5 and 5.5 studs and never drop below Y = 96.0 (anti-void protection)
        local offset = math.clamp(Config.UnderneathOffset or 5.0, 2.5, 5.5)
        local targetY = math.max(bottomY - offset, 96.0)
        targetPos = Vector3.new(targetRoot.Position.X, targetY, targetRoot.Position.Z) - (flatLook * 1.8)
        finalCF = CFrame.lookAt(targetPos, targetPos + flatLook)
    end

    hrp.CFrame = finalCF
    hrp.Velocity = Vector3.zero
    hrp.RotVelocity = Vector3.zero
    if hrp.AssemblyLinearVelocity then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
    if hum:GetState() ~= Enum.HumanoidStateType.Physics then
        hum:ChangeState(Enum.HumanoidStateType.Physics)
    end
end

-- Kill Aura Loop (Pure math dispatch, 0 screen shake, dynamic Vault Vampire Sword cycling)
-- Forward declarations: assigned later in the Ticket Auto-Farm section
local GetCheckpointWaveEntities
local AutoFarmState
local LastAuraAttack = 0
RegisterConnection(RunService.Heartbeat:Connect(function()
    local now = os.clock()

    if not Config.KillAura then
        -- Return Vampire Sword to safe vault if holding one from vault
        if Config.VaultVampireSword and not Config.AutoFarmTicket and VaultAuraState.IsHoldingVampireFromVault and not VaultAuraState.IsStoring and not VaultAuraState.IsUnstoring then
            task.spawn(StoreVampireSwordToVault)
        end
        return
    end

    -- If AutoFarmTicket is actively running combat, delegate strikes to AutoFarm to prevent duplicate remote spam
    if Config.AutoFarmTicket and AutoFarmState and AutoFarmState.Running and (AutoFarmState.CurrentStep == "COMBAT_CP1" or AutoFarmState.CurrentStep == "COMBAT_CP2") then
        return
    end

    local hostiles
    if Config.AutoFarmTicket and Config.TicketFarmWaveOnly then
        hostiles = GetCheckpointWaveEntities(AutoFarmState.ActiveCheckpoint)
    else
        hostiles = GetHostileEntities()
    end
    local inRange = {}
    for _, ent in ipairs(hostiles) do
        if ent.Distance <= Config.AuraRadius then
            table.insert(inRange, ent)
        end
    end

    if #inRange > 0 then
        VaultAuraState.LastHostileSeen = now

        -- Ensure combat weapon is equipped (Vampire Sword, Shovel, Hammer, Katana, etc.)
        EnsureEquippedCombatWeapon()

        -- Underneath / Blind Spot Hover (Standalone Kill Aura mode)
        if Config.UnderneathHover and not Config.AutoFarmTicket then
            local primeTarget = inRange[1].Root
            for _, ent in ipairs(inRange) do
                local _, h = GetEnemyDimensions(ent.Root)
                if h > 6.5 then
                    primeTarget = ent.Root
                    break
                end
            end
            ApplyUnderneathPosition(primeTarget)
        end

        if now - LastAuraAttack < Config.AuraAttackDelay then return end

        if Config.AuraTargetMode == "Closest" then
            table.sort(inRange, function(a, b)
                local _, aHeight = GetEnemyDimensions(a.Root)
                local _, bHeight = GetEnemyDimensions(b.Root)
                local aIsGiant = aHeight > 6.5 or a.Type:find("Big") or a.Type:find("Ogre") or a.Type:find("Mutant") or a.Type:find("Juggernaut") or a.Type:find("Bloater")
                local bIsGiant = bHeight > 6.5 or b.Type:find("Big") or b.Type:find("Ogre") or b.Type:find("Mutant") or b.Type:find("Juggernaut") or b.Type:find("Bloater")
                if aIsGiant and not bIsGiant then
                    return true
                elseif not aIsGiant and bIsGiant then
                    return false
                else
                    return a.Distance < b.Distance
                end
            end)
            DispatchStrike(inRange[1].Root)
            -- Cleave nearby targets within reach
            local pHrp = GetHRP()
            if pHrp then
                for i = 2, math.min(#inRange, 3) do
                    local other = inRange[i]
                    if other and other.Root and (other.Root.Position - pHrp.Position).Magnitude <= 10.5 then
                        DispatchStrike(other.Root)
                    end
                end
            end
        elseif Config.AuraTargetMode == "LowestHP" then
            table.sort(inRange, function(a, b)
                local hA = a.Model:FindFirstChildOfClass("Humanoid")
                local hB = b.Model:FindFirstChildOfClass("Humanoid")
                local hpA = hA and hA.Health or 100
                local hpB = hB and hB.Health or 100
                return hpA < hpB
            end)
            DispatchStrike(inRange[1].Root)
        elseif Config.AuraTargetMode == "All" then
            for _, ent in ipairs(inRange) do
                DispatchStrike(ent.Root)
            end
        end

        LastAuraAttack = now
    else
        -- Hostiles cleared or none in range -> return Vampire Sword back to vault (ONLY when outside AutoFarmTicket)
        if Config.VaultVampireSword and not Config.AutoFarmTicket and VaultAuraState.IsHoldingVampireFromVault then
            if now - VaultAuraState.LastHostileSeen >= Config.VaultVampireReturnDelay then
                if not VaultAuraState.IsStoring and not VaultAuraState.IsUnstoring then
                    task.spawn(StoreVampireSwordToVault)
                end
            end
        end
    end
end))

-- ========================================================================
-- CHECKPOINT 1 & 2 TICKET AUTO-FARM ENGINE
-- ========================================================================
local function GetGameReplicaData()
    local rep = game:GetService("ReplicatedStorage")
    local repMod = rep:FindFirstChild("ClientSource") 
        and rep.ClientSource:FindFirstChild("Mutual") 
        and rep.ClientSource.Mutual:FindFirstChild("Packages") 
        and rep.ClientSource.Mutual.Packages:FindFirstChild("Modules") 
        and rep.ClientSource.Mutual.Packages.Modules:FindFirstChild("Replica") 
        and rep.ClientSource.Mutual.Packages.Modules.Replica:FindFirstChild("ReplicaController")

    if repMod then
        local ok, ReplicaController = pcall(require, repMod)
        if ok and ReplicaController and ReplicaController._replicas then
            for _, r in pairs(ReplicaController._replicas) do
                if r.Class == "GameReplica" then
                    return r.Data
                end
            end
        end
    end
    return nil
end

local function GetCheckpointInfo(cpIndex)
    local cpName = "Checkpoint" .. tostring(cpIndex)
    local gameData = GetGameReplicaData()
    local startZ = gameData and gameData.StartPosition and gameData.StartPosition.Z or 747.969
    local startX = gameData and gameData.StartPosition and gameData.StartPosition.X or 299.918
    local startY = gameData and gameData.StartPosition and gameData.StartPosition.Y or 101.5

    if gameData and gameData.BusStopProgressList then
        for _, stop in ipairs(gameData.BusStopProgressList) do
            if stop.Name == cpName then
                return {
                    Name = cpName,
                    Id = stop.Id,
                    Progress = stop.Progress,
                    TargetPos = Vector3.new(startX, startY, startZ - stop.Progress),
                    MaxCombatRadius = 350
                }
            end
        end
    end

    -- Fallback static world positions if replica is not yet available
    local fallbackZ = (cpIndex == 1) and -14356 or -44308
    return {
        Name = cpName,
        Id = nil,
        Progress = (cpIndex == 1) and 15104 or 45056,
        TargetPos = Vector3.new(299.918, 101.5, fallbackZ),
        MaxCombatRadius = 350
    }
end

local function FindLoadedCheckpoint(cpIndex)
    local cpInfo = GetCheckpointInfo(cpIndex)
    local cpName = "Checkpoint" .. tostring(cpIndex)
    local targetId = cpInfo and cpInfo.Id

    -- 1. Check Knit Component MapObject
    if targetId and Knit and Knit.Components and Knit.Components.MapObject then
        local comp = Knit.Components.MapObject:FromId(targetId)
        if comp and comp.Instance then
            return comp.Instance, comp
        end
    end

    -- 2. Check CollectionService Tagged MapObjects
    local tagged = CollectionService:GetTagged("MapObject")
    for _, inst in ipairs(tagged) do
        local nameAttr = inst:GetAttribute("Name")
        if (targetId and inst.Name == targetId) or (nameAttr == cpName) or (inst.Name:find(cpName)) then
            return inst, nil
        end
    end

    -- 3. Check Workspace CHUNKS_CONTAINER
    if ChunksContainer then
        for _, chunk in ipairs(ChunksContainer:GetChildren()) do
            local found = chunk:FindFirstChild(cpName, true)
            if found then return found, nil end
            if targetId then
                local foundById = chunk:FindFirstChild(targetId, true)
                if foundById then return foundById, nil end
            end
        end
    end

    return nil, nil
end

local function GetCheckpointMapObject(cpIndex)
    return FindLoadedCheckpoint(cpIndex)
end

local function IsCheckpointWaveEntity(model, targetCpIndex)
    if not IsEntityHostile(model) then return false end

    local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model.PrimaryPart
    if not root then return false end

    local cpIndices = {}
    if targetCpIndex == 1 or targetCpIndex == 2 then
        table.insert(cpIndices, targetCpIndex)
    else
        table.insert(cpIndices, 1)
        table.insert(cpIndices, 2)
    end

    for _, idx in ipairs(cpIndices) do
        local cpInfo = GetCheckpointInfo(idx)
        local cpInst = FindLoadedCheckpoint(idx)
        local cpPos = cpInst and cpInst:GetPivot().Position or (cpInfo and cpInfo.TargetPos or Vector3.new(299.9, 102, -14356))

        local dist = (root.Position - cpPos).Magnitude
        if dist <= (cpInfo and cpInfo.MaxCombatRadius or 350) then
            return true, idx, dist
        end
    end

    return false, nil, 0
end

local CachedWaveEntities = {}
local LastWaveEntityScanTime = 0
local LastWaveEntityCp = 0

function GetCheckpointWaveEntities(targetCpIndex)
    local now = os.clock()
    if targetCpIndex == LastWaveEntityCp and (now - LastWaveEntityScanTime < 0.08) and #CachedWaveEntities > 0 then
        local valid = true
        for _, ent in ipairs(CachedWaveEntities) do
            if not ent.Model or not ent.Model.Parent then
                valid = false
                break
            end
        end
        if valid then return CachedWaveEntities end
    end
    LastWaveEntityCp = targetCpIndex
    LastWaveEntityScanTime = now

    local waveHostiles = {}
    local hrp = GetHRP()
    if not hrp then return waveHostiles end

    local tagged = CollectionService:GetTagged("Entity")
    for _, model in ipairs(tagged) do
        if model:IsA("Model") then
            local isWave, cpIdx, cpDist = IsCheckpointWaveEntity(model, targetCpIndex)
            if isWave then
                local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model.PrimaryPart
                if root then
                    local pDist = (hrp.Position - root.Position).Magnitude
                    table.insert(waveHostiles, {
                        Model = model,
                        Root = root,
                        Distance = pDist,
                        CpDistance = cpDist,
                        CheckpointIndex = cpIdx,
                        Type = model:GetAttribute("Type") or "WaveEntity"
                    })
                end
            end
        end
    end

    table.sort(waveHostiles, function(a, b)
        local _, aHeight = GetEnemyDimensions(a.Root)
        local _, bHeight = GetEnemyDimensions(b.Root)
        local aIsGiant = aHeight > 6.5 
            or a.Type:find("Big") or a.Type:find("Ogre") or a.Type:find("Mutant") or a.Type:find("Juggernaut") or a.Type:find("Bloater")
        local bIsGiant = bHeight > 6.5 
            or b.Type:find("Big") or b.Type:find("Ogre") or b.Type:find("Mutant") or b.Type:find("Juggernaut") or b.Type:find("Bloater")

        if aIsGiant and not bIsGiant then
            return true -- Eliminate giant/boss threats first so they cannot slam from above
        elseif not aIsGiant and bIsGiant then
            return false
        else
            return a.Distance < b.Distance
        end
    end)
    CachedWaveEntities = waveHostiles
    return waveHostiles
end

local function TeleportToCheckpoint(cpIndex)
    local cpInfo = GetCheckpointInfo(cpIndex)
    local cpInst = FindLoadedCheckpoint(cpIndex)
    local pos = cpInst and (cpInst:GetPivot().Position + Vector3.new(0, 5, 0)) or (cpInfo and cpInfo.TargetPos + Vector3.new(0, 5, 0))
    if pos then
        TeleportToCFrame(CFrame.new(pos))
        return true
    end
    return false
end

local LastCheckpointInteractTime = 0
local IsInteractingCheckpoint = false

local function TryInteractWithCheckpointObjects(cpIndex)
    local now = os.clock()
    if IsInteractingCheckpoint or (now - LastCheckpointInteractTime < 2.0) then
        return
    end
    LastCheckpointInteractTime = now
    IsInteractingCheckpoint = true

    task.spawn(function()
        local ok, err = pcall(function()
            local cpInst = FindLoadedCheckpoint(cpIndex)
            if not cpInst then return end

            local char = GetCharacter()
            local hrp = GetHRP()
            if not char or not hrp then return end

            local savedPos = hrp.Position

            -- Check if Key is present and untouched
            local key = cpInst:FindFirstChild("Key", true)
            if key and key:IsA("BasePart") then
                hrp.CFrame = key.CFrame
                task.wait(0.12)
                for _, prompt in ipairs(key:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") then
                        pcall(function() fireproximityprompt(prompt) end)
                    end
                end
            end

            -- Check if Lock / Cage is present
            local lock = cpInst:FindFirstChild("Lock", true)
            if lock and lock:IsA("BasePart") then
                hrp.CFrame = lock.CFrame
                task.wait(0.12)
                for _, prompt in ipairs(lock:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") then
                        pcall(function() fireproximityprompt(prompt) end)
                    end
                end
            end

            -- Check any prompts on the Checkpoint model
            for _, prompt in ipairs(cpInst:GetDescendants()) do
                if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                    pcall(function() fireproximityprompt(prompt) end)
                end
            end

            local cpInfo = GetCheckpointInfo(cpIndex)
            local safePos = cpInst and (cpInst:GetPivot().Position + Vector3.new(0, 4, 0)) or (cpInfo and cpInfo.TargetPos + Vector3.new(0, 4, 0))
            if safePos then
                TeleportToCFrame(CFrame.new(safePos))
            else
                TeleportToCFrame(CFrame.new(savedPos.X, math.max(savedPos.Y, 104), savedPos.Z))
            end
            RestoreCharacterPhysics()
        end)
        IsInteractingCheckpoint = false
    end)
end

local function RestoreCharacterPhysics()
    local char = GetCharacter()
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if part.Name == "HumanoidRootPart" then
                part.CanCollide = false
            else
                part.CanCollide = true
            end
            part.CanTouch = true
            part.CanQuery = true
        end
    end
    local hum = GetHumanoid()
    if hum and hum.Health > 0 then
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.Ragdoll then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end
end

-- ========================================================================
-- ANTI-VOID GUARDIAN (ZERO FALL-THROUGH-MAP PROTECTION)
-- ========================================================================
local LastSafeGroundCF = nil
local LastAntiVoidRescue = 0

RegisterConnection(RunService.Heartbeat:Connect(function()
    if not Config.AntiVoid then return end

    local char = GetCharacter()
    local hrp = GetHRP()
    local hum = GetHumanoid()
    if not char or not hrp or not hum or hum.Health <= 0 then return end

    local pos = hrp.Position
    local now = os.clock()

    -- Continuously record valid, safe ground locations (between Y=95 and Y=180 while not falling rapidly)
    local isRetreatingInSky = AutoFarmState and AutoFarmState.CurrentStep == "EMERGENCY_RETREAT"
    if pos.Y >= 95 and pos.Y <= 180 and not isRetreatingInSky then
        local velY = hrp.AssemblyLinearVelocity and hrp.AssemblyLinearVelocity.Y or hrp.Velocity.Y
        if math.abs(velY) < 30 then
            LastSafeGroundCF = hrp.CFrame
        end
    end

    -- Trigger condition: Character drops below minimum safe terrain height (Y < 75)
    local triggerThreshold = Config.AntiVoidMinAltitude or 75
    local isFallingThroughMap = (pos.Y < triggerThreshold)

    if isFallingThroughMap and (now - LastAntiVoidRescue > 0.4) then
        LastAntiVoidRescue = now

        -- Zero out all momentum to immediately stop downward physics acceleration
        hrp.Velocity = Vector3.zero
        hrp.RotVelocity = Vector3.zero
        if hrp.AssemblyLinearVelocity then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end

        -- Determine the best recovery target CFrame
        local rescueCF = nil
        if AutoFarmState and AutoFarmState.Running then
            local activeCP = AutoFarmState.ActiveCheckpoint or 1
            local cpInst = FindLoadedCheckpoint(activeCP)
            local cpInfo = GetCheckpointInfo(activeCP)
            local center = cpInst and (cpInst:GetPivot().Position + Vector3.new(0, 5, 0)) or (cpInfo and cpInfo.TargetPos + Vector3.new(0, 5, 0))
            if center then
                rescueCF = CFrame.new(center)
            end
        end

        if not rescueCF then
            if LastSafeGroundCF and LastSafeGroundCF.Position.Y >= 95 then
                rescueCF = LastSafeGroundCF + Vector3.new(0, 4, 0)
            else
                local bus = GetBusModel()
                if bus then
                    rescueCF = bus:GetPivot() + Vector3.new(0, 5, 0)
                else
                    rescueCF = CFrame.new(299.918, 106.5, pos.Z)
                end
            end
        end

        hrp.CFrame = rescueCF
        RestoreCharacterPhysics()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        warn(string.format("[AntiVoid] Rescued character from falling out of map! (Y was %.1f, recovered to Y=%.1f)", pos.Y, rescueCF.Position.Y))
    end
end))

local function GetBusModel()
    return ItemContainer and ItemContainer:FindFirstChild("Bus")
end

local function ReturnToBus()
    local bus = GetBusModel()
    if bus then
        local busCF = bus:GetPivot()
        TeleportToCFrame(busCF + Vector3.new(0, 5, 0))
    else
        local gameData = GetGameReplicaData()
        local startPos = gameData and gameData.StartPosition or Vector3.new(299.918, 102, 747.969)
        TeleportToCFrame(CFrame.new(startPos + Vector3.new(0, 4, 0)))
    end
    task.delay(0.2, RestoreCharacterPhysics)
end

local function GetCheckpointWaveState(cpIndex)
    local cpInst, cpComp = FindLoadedCheckpoint(cpIndex)
    local waveFeature = cpComp and cpComp.Features and cpComp.Features.Wave
    local repData = cpComp and cpComp.Replica and cpComp.Replica.Data

    local currentWave = repData and repData.CurrentWave
    local totalWaves = repData and repData.TotalWaves
    local remaining = repData and repData.RemainingEntities
    local isRunning = false

    if waveFeature then
        if typeof(waveFeature.IsWaveRunning) == "function" then
            local ok, running = pcall(function() return waveFeature:IsWaveRunning() end)
            if ok and running ~= nil then isRunning = running end
        elseif waveFeature.WaveRunning ~= nil then
            isRunning = (waveFeature.WaveRunning == true)
        end
    end

    local hud = Knit and Knit.UI and Knit.UI.HUD and Knit.UI.HUD.Checkpoint
    local hudVisible = hud and (hud.Visible == true)

    if hud then
        local waveLabel = hud:FindFirstChild("Wave")
        if waveLabel and waveLabel.Text then
            local c, t = waveLabel.Text:match("(%d+)%s*/%s*(%d+)")
            if c and t then
                currentWave = currentWave or tonumber(c)
                totalWaves = totalWaves or tonumber(t)
            end
        end
        local remLabel = hud:FindFirstChild("RemainingEntities")
        if remLabel and remLabel.Text then
            local r = remLabel.Text:match("(%d+)")
            if r then remaining = remaining or tonumber(r) end
        end
    end

    if hudVisible then isRunning = true end

    -- Checkpoint 1 has at least 2 waves; Checkpoint 2 has at least 3 waves
    local minTotal = (cpIndex == 2) and 3 or 2
    local finalTotal = math.max(totalWaves or minTotal, minTotal)
    local finalCurrent = math.clamp(currentWave or 1, 1, finalTotal)

    return {
        CurrentWave = finalCurrent,
        TotalWaves = finalTotal,
        Remaining = remaining or 0,
        IsRunning = isRunning,
        HudVisible = hudVisible,
    }
end

-- ========================================================================
-- AUTONOMOUS 1-CLICK TICKET AUTO-FARM STATE MACHINE (1 RUN PER MATCH)
-- ========================================================================
AutoFarmState = {
    Running = false,
    CurrentStep = "IDLE", -- "IDLE", "SEARCH_CP1", "COMBAT_CP1", "SEARCH_CP2", "COMBAT_CP2", "EMERGENCY_RETREAT", "FINISH_MATCH"
    ActiveCheckpoint = 1,
    CombatStarted = false,
    StepStartTime = 0,
    LastStepTime = 0,
    LastAttackTime = 0,
    LastHostileSeenTime = 0,
    WaveIntermissionStartTime = 0,
    WaitWaveDuration = 5.0,
    IntermissionGracePeriod = 6.0, -- Seconds to wait between waves or after wave empties
    StepIncrement = 1200, -- Studs advanced per incremental road step
    StepInterval = 0.22,  -- Delay between road steps to allow chunk streaming
    CP1_Cleared = false,
    CP2_Cleared = false,
    MatchCleared = false, -- Constraint: in 1 match, only clear once
    StatusMessage = "Idle",
    PreRetreatStep = "COMBAT_CP1",
    PreRetreatCFrame = nil,
    EmergencyRetreatStartTime = 0,
}

local function ResetAutoFarmMatch()
    AutoFarmState.CP1_Cleared = false
    AutoFarmState.CP2_Cleared = false
    AutoFarmState.MatchCleared = false
    AutoFarmState.CurrentStep = "IDLE"
    AutoFarmState.CombatStarted = false
    AutoFarmState.Running = false
    AutoFarmState.LastHostileSeenTime = 0
    AutoFarmState.WaveIntermissionStartTime = 0
    AutoFarmState.PreRetreatStep = "COMBAT_CP1"
    AutoFarmState.PreRetreatCFrame = nil
    AutoFarmState.EmergencyRetreatStartTime = 0
    AutoFarmState.StatusMessage = "Match status reset. Ready to run."
end

local function StepAutoFarmTicket()
    if not Config.AutoFarmTicket then
        if AutoFarmState.Running then
            AutoFarmState.Running = false
            AutoFarmState.CombatStarted = false
            AutoFarmState.CurrentStep = "IDLE"
            AutoFarmState.StatusMessage = "Stopped"
            RestoreCharacterPhysics()
            if VaultAuraState.IsHoldingVampireFromVault and not VaultAuraState.IsStoring and not VaultAuraState.IsUnstoring then
                task.spawn(StoreVampireSwordToVault)
            end
        end
        return
    end

    -- If finishing routine is actively storing sword or restarting to lobby, yield and let it run!
    if AutoFarmState.CurrentStep == "FINISHING_ROUTINE" then
        return
    end

    local now = os.clock()
    local hrp = GetHRP()
    if not hrp then return end

    local char = GetCharacter()
    local hum = GetHumanoid()
    local pData = GetPlayerReplicaData()
    local currentHP = hum and hum.Health or (pData and pData.Health) or 100
    local maxHP = hum and hum.MaxHealth or (pData and pData.MaxHealth) or 100
    local hpPct = (maxHP > 0) and ((currentHP / maxHP) * 100) or 100

    -- ------------------------------------------------------------------------
    -- EMERGENCY SKY RETREAT (< 50% HP): Escape immediately, store sword & heal
    -- ------------------------------------------------------------------------
    if Config.EmergencySkyRetreat and hpPct < Config.EmergencyRetreatThreshold then
        if AutoFarmState.CurrentStep ~= "EMERGENCY_RETREAT" and AutoFarmState.CurrentStep ~= "IDLE" and AutoFarmState.CurrentStep ~= "FINISH_MATCH" then
            AutoFarmState.PreRetreatStep = AutoFarmState.CurrentStep
            if hrp.Position.Y < 180 then
                AutoFarmState.PreRetreatCFrame = hrp.CFrame
            end
            AutoFarmState.CurrentStep = "EMERGENCY_RETREAT"
            AutoFarmState.EmergencyRetreatStartTime = now
            AutoFarmState.EmergencySwordStored = false
            AutoFarmState.EmergencyStoringInProgress = false

            AutoFarmState.StatusMessage = string.format("⚠️ Emergency Retreat: HP %.0f%% < 50%%! Flying to sky...", hpPct)
            local skyAlt = math.max(Config.EmergencySkyAltitude, 350)
            TeleportToCFrame(CFrame.new(hrp.Position.X, skyAlt, hrp.Position.Z))
            return
        end
    end

    -- ------------------------------------------------------------------------
    -- STEP: EMERGENCY_RETREAT (Hover high in sky & auto-heal until HP >= 90%)
    -- ------------------------------------------------------------------------
    if AutoFarmState.CurrentStep == "EMERGENCY_RETREAT" then
        -- If still actively depositing sword into vault, let the store task finish
        if AutoFarmState.EmergencyStoringInProgress then
            return
        end

        local skyAlt = math.max(Config.EmergencySkyAltitude, 350)
        local safeSkyPos = Vector3.new(hrp.Position.X, skyAlt, hrp.Position.Z)

        pcall(function()
            hrp.CFrame = CFrame.new(safeSkyPos)
            hrp.Velocity = Vector3.zero
            hrp.RotVelocity = Vector3.zero
            if hrp.AssemblyLinearVelocity then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
            if hum then hum:ChangeState(Enum.HumanoidStateType.Physics) end
        end)

        pcall(function()
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)

        -- Active Emergency Healing in Sky
        if ReviveService and (now - (LastSurvivalCheck or 0)) > 0.25 then
            pcall(function()
                if ReviveService:CanHeal() then
                    ReviveService:Heal()
                    LastSurvivalCheck = now
                end
            end)
        end

        AutoFarmState.StatusMessage = string.format("Recovering in Sky: HP %.0f%% / 100%% (Wait for %.0f%%)", hpPct, Config.EmergencyRecoverThreshold)

        -- Health recovered OR timeout (prevent infinite sky hang) -> Return to battle
        local retreatElapsed = now - (AutoFarmState.EmergencyRetreatStartTime or now)
        local shouldResume = (hpPct >= Config.EmergencyRecoverThreshold) or (retreatElapsed > 8.0)

        if shouldResume then
            AutoFarmState.StatusMessage = string.format("✅ HP Recovered (%.0f%%)! Resuming combat...", hpPct)

            RestoreCharacterPhysics()
            local resumeStep = AutoFarmState.PreRetreatStep
            if not resumeStep or resumeStep == "EMERGENCY_RETREAT" or resumeStep == "IDLE" then
                resumeStep = (AutoFarmState.ActiveCheckpoint == 2) and "COMBAT_CP2" or "COMBAT_CP1"
            end
            AutoFarmState.CurrentStep = resumeStep
            AutoFarmState.LastAttackTime = now

            if AutoFarmState.PreRetreatCFrame and AutoFarmState.PreRetreatCFrame.Position.Y < 180 then
                TeleportToCFrame(AutoFarmState.PreRetreatCFrame)
            else
                local cpIdx = AutoFarmState.ActiveCheckpoint or 1
                TeleportToCheckpoint(cpIdx)
            end
            return
        end
        return
    end

    -- Check 1-run per match constraint (Ignored when AutoLoopNewGame is active)
    if AutoFarmState.MatchCleared and not Config.AutoLoopNewGame then
        SetToggleState("AutoFarmTicket", false)
        AutoFarmState.Running = false
        AutoFarmState.CurrentStep = "IDLE"
        AutoFarmState.StatusMessage = "Match ticket farm already completed (1/1 run)."
        return
    end

    -- Bootstrap run
    if not AutoFarmState.Running then
        AutoFarmState.Running = true
        AutoFarmState.StepStartTime = now
        AutoFarmState.LastStepTime = 0
        AutoFarmState.CombatStarted = false
        AutoFarmState.LastHostileSeenTime = 0
        AutoFarmState.WaveIntermissionStartTime = 0

        if not AutoFarmState.CP1_Cleared then
            AutoFarmState.ActiveCheckpoint = 1
            AutoFarmState.CurrentStep = "SEARCH_CP1"
            AutoFarmState.StatusMessage = "Searching incrementally for Checkpoint 1..."
        elseif not AutoFarmState.CP2_Cleared then
            AutoFarmState.ActiveCheckpoint = 2
            AutoFarmState.CurrentStep = "SEARCH_CP2"
            AutoFarmState.StatusMessage = "Searching incrementally for Checkpoint 2..."
        else
            AutoFarmState.CurrentStep = "FINISH_MATCH"
        end
    end

    -- ------------------------------------------------------------------------
    -- STEP: SEARCH_CP1 (Incremental road step-warp until Checkpoint 1 streams)
    -- ------------------------------------------------------------------------
    if AutoFarmState.CurrentStep == "SEARCH_CP1" then
        AutoFarmState.ActiveCheckpoint = 1
        UnfreezePlayer()
        local cpInfo = GetCheckpointInfo(1)
        local cpInst = FindLoadedCheckpoint(1)
        local targetZ = cpInfo.TargetPos.Z

        -- Check if Checkpoint 1 MapObject is already loaded into Workspace
        if cpInst then
            local cpPos = cpInst:GetPivot().Position + Vector3.new(0, 5, 0)
            TeleportToCFrame(CFrame.new(cpPos))
            AutoFarmState.CurrentStep = "COMBAT_CP1"
            AutoFarmState.StepStartTime = now
            AutoFarmState.CombatStarted = false
            AutoFarmState.LastHostileSeenTime = 0
            AutoFarmState.WaveIntermissionStartTime = 0
            AutoFarmState.StatusMessage = "Checkpoint 1 reached! Engaging combat..."
            return
        end

        -- Check if close enough to target Z for streaming to trigger
        if math.abs(hrp.Position.Z - targetZ) <= 180 then
            AutoFarmState.StatusMessage = "Near CP1! Waiting for chunk streaming..."
            if now - AutoFarmState.StepStartTime > 2.5 then
                TeleportToCFrame(CFrame.new(cpInfo.TargetPos + Vector3.new(0, 5, 0)))
                AutoFarmState.CurrentStep = "COMBAT_CP1"
                AutoFarmState.StepStartTime = now
                AutoFarmState.CombatStarted = false
                AutoFarmState.LastHostileSeenTime = 0
                AutoFarmState.WaveIntermissionStartTime = 0
            end
            return
        end

        -- Step forward along road towards negative Z
        if now - AutoFarmState.LastStepTime >= AutoFarmState.StepInterval then
            AutoFarmState.LastStepTime = now
            local currentZ = hrp.Position.Z
            local nextZ = math.max(currentZ - AutoFarmState.StepIncrement, targetZ)
            AutoFarmState.StatusMessage = string.format("Warp-stepping to CP1: Z=%.0f -> %.0f", currentZ, nextZ)
            TeleportToCFrame(CFrame.new(299.918, 102.5, nextZ))
        end
        return
    end

    -- ------------------------------------------------------------------------
    -- STEP: COMBAT_CP1 (Hover underneath & strike wave entities with Vampire Sword)
    -- Clears ALL waves of Checkpoint 1 before advancing
    -- ------------------------------------------------------------------------
    if AutoFarmState.CurrentStep == "COMBAT_CP1" then
        AutoFarmState.ActiveCheckpoint = 1
        local waveHostiles = GetCheckpointWaveEntities(1)
        local waveState = GetCheckpointWaveState(1)

        if #waveHostiles > 0 then
            AutoFarmState.CombatStarted = true
            AutoFarmState.LastHostileSeenTime = now
            AutoFarmState.WaveIntermissionStartTime = 0

            AutoFarmState.StatusMessage = string.format("Fighting CP1 Wave %d/%d (%d enemies left)", waveState.CurrentWave, waveState.TotalWaves, #waveHostiles)

            -- Ensure combat weapon is equipped (Vampire Sword, Shovel, Hammer, Katana, etc.)
            EnsureEquippedCombatWeapon()

            -- Hover underneath target for zero incoming damage
            local target = waveHostiles[1]
            if Config.UnderneathHover then
                ApplyUnderneathPosition(target.Root)
            end

            -- Strike target & cleave nearby wave hostiles
            if now - AutoFarmState.LastAttackTime >= Config.AuraAttackDelay then
                DispatchStrike(target.Root)
                local pHrp = GetHRP()
                if pHrp then
                    for i = 2, math.min(#waveHostiles, 3) do
                        local other = waveHostiles[i]
                        if other and other.Root and (other.Root.Position - pHrp.Position).Magnitude <= 10.5 then
                            DispatchStrike(other.Root)
                        end
                    end
                end
                AutoFarmState.LastAttackTime = now
            end
        else
            -- 0 wave hostiles currently visible in combat radius: immediately restore physics & safe elevation
            RestoreCharacterPhysics()
            local cpInst = FindLoadedCheckpoint(1)
            local cpInfo = GetCheckpointInfo(1)
            local center = cpInst and (cpInst:GetPivot().Position + Vector3.new(0, 5, 0)) or (cpInfo and cpInfo.TargetPos + Vector3.new(0, 5, 0))

            if center and (hrp.Position.Y < (center.Y - 1) or (hrp.Position - center).Magnitude > 35) then
                TeleportToCFrame(CFrame.new(center))
            end

            if AutoFarmState.CombatStarted then
                local minWaves = 2
                local totalExpected = math.max(waveState.TotalWaves, minWaves)
                local hasMoreWaves = (waveState.CurrentWave < minWaves) or (waveState.CurrentWave < waveState.TotalWaves)

                if AutoFarmState.WaveIntermissionStartTime == 0 then
                    AutoFarmState.WaveIntermissionStartTime = now
                end

                local elapsedSinceEmpty = now - AutoFarmState.WaveIntermissionStartTime

                if hasMoreWaves then
                    AutoFarmState.StatusMessage = string.format("CP1 Wave %d/%d cleared! Waiting for Wave %d (%.1fs)...", waveState.CurrentWave, totalExpected, waveState.CurrentWave + 1, math.max(0, AutoFarmState.IntermissionGracePeriod - elapsedSinceEmpty))

                    task.spawn(function()
                        TryInteractWithCheckpointObjects(1)
                    end)
                else
                    -- ALL waves of Checkpoint 1 are officially cleared! (Must be Wave 2 or higher)
                    if elapsedSinceEmpty >= 3.0 then
                        AutoFarmState.StatusMessage = "CP1 ALL Waves Cleared! Advancing to CP2..."
                        task.spawn(function()
                            TryInteractWithCheckpointObjects(1)
                        end)
                        AutoFarmState.CP1_Cleared = true
                        AutoFarmState.CombatStarted = false
                        AutoFarmState.WaveIntermissionStartTime = 0

                        if Config.AutoFarmTargetCheckpoint == 1 then
                            AutoFarmState.CurrentStep = "FINISH_MATCH"
                        else
                            AutoFarmState.CurrentStep = "SEARCH_CP2"
                            AutoFarmState.ActiveCheckpoint = 2
                            AutoFarmState.StepStartTime = now
                            AutoFarmState.LastStepTime = 0
                        end
                    else
                        AutoFarmState.StatusMessage = string.format("CP1 Cleared! Collecting items (%.1fs)...", 3.0 - elapsedSinceEmpty)
                        task.spawn(function()
                            TryInteractWithCheckpointObjects(1)
                        end)
                    end
                end
            else
                -- Just arrived at CP1, anchor and wait for bus & Wave 1 to spawn (allow up to 45s for bus travel)
                if center and ((hrp.Position - center).Magnitude > 60 or hrp.Position.Y < (center.Y - 1)) then
                    TeleportToCFrame(CFrame.new(center))
                end

                local cpWaitLimit = 45.0
                local waitLeft = math.max(0, cpWaitLimit - (now - AutoFarmState.StepStartTime))
                AutoFarmState.StatusMessage = string.format("Waiting for bus & CP1 wave spawn (%.1fs)...", waitLeft)
                if (now - AutoFarmState.StepStartTime > cpWaitLimit) and not waveState.IsRunning and #waveHostiles == 0 then
                    AutoFarmState.StatusMessage = "CP1 timeout/empty! Advancing to CP2..."
                    task.spawn(function()
                        TryInteractWithCheckpointObjects(1)
                    end)
                    AutoFarmState.CP1_Cleared = true
                    AutoFarmState.CombatStarted = false
                    AutoFarmState.WaveIntermissionStartTime = 0

                    if Config.AutoFarmTargetCheckpoint == 1 then
                        AutoFarmState.CurrentStep = "FINISH_MATCH"
                    else
                        AutoFarmState.CurrentStep = "SEARCH_CP2"
                        AutoFarmState.ActiveCheckpoint = 2
                        AutoFarmState.StepStartTime = now
                        AutoFarmState.LastStepTime = 0
                    end
                end
            end
        end
        return
    end

    -- ------------------------------------------------------------------------
    -- STEP: SEARCH_CP2 (Incremental road step-warp until Checkpoint 2 streams)
    -- ------------------------------------------------------------------------
    if AutoFarmState.CurrentStep == "SEARCH_CP2" then
        AutoFarmState.ActiveCheckpoint = 2
        local cpInfo = GetCheckpointInfo(2)
        local cpInst = FindLoadedCheckpoint(2)
        local targetZ = cpInfo.TargetPos.Z

        -- Check if Checkpoint 2 MapObject is already loaded into Workspace
        if cpInst then
            local cpPos = cpInst:GetPivot().Position + Vector3.new(0, 5, 0)
            TeleportToCFrame(CFrame.new(cpPos))
            AutoFarmState.CurrentStep = "COMBAT_CP2"
            AutoFarmState.StepStartTime = now
            AutoFarmState.CombatStarted = false
            AutoFarmState.LastHostileSeenTime = 0
            AutoFarmState.WaveIntermissionStartTime = 0
            AutoFarmState.StatusMessage = "Checkpoint 2 reached! Engaging combat..."
            return
        end

        -- Check if close enough to target Z for streaming to trigger
        if math.abs(hrp.Position.Z - targetZ) <= 180 then
            AutoFarmState.StatusMessage = "Near CP2! Waiting for chunk streaming..."
            if now - AutoFarmState.StepStartTime > 2.5 then
                TeleportToCFrame(CFrame.new(cpInfo.TargetPos + Vector3.new(0, 5, 0)))
                AutoFarmState.CurrentStep = "COMBAT_CP2"
                AutoFarmState.StepStartTime = now
                AutoFarmState.CombatStarted = false
                AutoFarmState.LastHostileSeenTime = 0
                AutoFarmState.WaveIntermissionStartTime = 0
            end
            return
        end

        -- Step forward along road towards negative Z
        -- Fly slightly above the road (Y = 112) so unstreamed collision meshes never cause void falls
        local safeRoadY = 112.0
        if now - AutoFarmState.LastStepTime >= AutoFarmState.StepInterval then
            AutoFarmState.LastStepTime = now
            local currentZ = hrp.Position.Z
            local nextZ = math.max(currentZ - AutoFarmState.StepIncrement, targetZ)
            AutoFarmState.StatusMessage = string.format("Gliding to CP2: Z=%.0f -> %.0f", currentZ, nextZ)
            TeleportToCFrame(CFrame.new(299.918, safeRoadY, nextZ))
        end

        -- Keep linear velocity zeroed to prevent gravity fall between step intervals
        hrp.Velocity = Vector3.zero
        if hrp.AssemblyLinearVelocity then
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
        return
    end

    -- ------------------------------------------------------------------------
    -- STEP: COMBAT_CP2 (Hover underneath & strike wave entities with Vampire Sword)
    -- Clears ALL waves of Checkpoint 2 before returning to Bus
    -- ------------------------------------------------------------------------
    if AutoFarmState.CurrentStep == "COMBAT_CP2" then
        AutoFarmState.ActiveCheckpoint = 2
        local waveHostiles = GetCheckpointWaveEntities(2)
        local waveState = GetCheckpointWaveState(2)

        if #waveHostiles > 0 then
            AutoFarmState.CombatStarted = true
            AutoFarmState.LastHostileSeenTime = now
            AutoFarmState.WaveIntermissionStartTime = 0

            AutoFarmState.StatusMessage = string.format("Fighting CP2 Wave %d/%d (%d enemies left)", waveState.CurrentWave, waveState.TotalWaves, #waveHostiles)

            -- Ensure combat weapon is equipped (Vampire Sword, Shovel, Hammer, Katana, etc.)
            EnsureEquippedCombatWeapon()

            -- Hover underneath target for zero incoming damage
            local target = waveHostiles[1]
            if Config.UnderneathHover then
                ApplyUnderneathPosition(target.Root)
            end

            -- Strike target & cleave nearby wave hostiles
            if now - AutoFarmState.LastAttackTime >= Config.AuraAttackDelay then
                DispatchStrike(target.Root)
                local pHrp = GetHRP()
                if pHrp then
                    for i = 2, math.min(#waveHostiles, 3) do
                        local other = waveHostiles[i]
                        if other and other.Root and (other.Root.Position - pHrp.Position).Magnitude <= 10.5 then
                            DispatchStrike(other.Root)
                        end
                    end
                end
                AutoFarmState.LastAttackTime = now
            end
        else
            -- 0 wave hostiles currently visible in combat radius: immediately restore physics & safe elevation
            RestoreCharacterPhysics()
            local cpInst = FindLoadedCheckpoint(2)
            local cpInfo = GetCheckpointInfo(2)
            local center = cpInst and (cpInst:GetPivot().Position + Vector3.new(0, 5, 0)) or (cpInfo and cpInfo.TargetPos + Vector3.new(0, 5, 0))

            if center and (hrp.Position.Y < (center.Y - 1) or (hrp.Position - center).Magnitude > 35) then
                TeleportToCFrame(CFrame.new(center))
            end

            if AutoFarmState.CombatStarted then
                local minWaves = 3
                local totalExpected = math.max(waveState.TotalWaves, minWaves)
                local hasMoreWaves = (waveState.CurrentWave < minWaves) or (waveState.CurrentWave < waveState.TotalWaves)

                if AutoFarmState.WaveIntermissionStartTime == 0 then
                    AutoFarmState.WaveIntermissionStartTime = now
                end

                local elapsedSinceEmpty = now - AutoFarmState.WaveIntermissionStartTime

                if hasMoreWaves then
                    AutoFarmState.StatusMessage = string.format("CP2 Wave %d/%d cleared! Waiting for Wave %d (%.1fs)...", waveState.CurrentWave, totalExpected, waveState.CurrentWave + 1, math.max(0, AutoFarmState.IntermissionGracePeriod - elapsedSinceEmpty))

                    task.spawn(function()
                        TryInteractWithCheckpointObjects(2)
                    end)
                else
                    -- ALL waves of Checkpoint 2 are officially cleared! (Must be Wave 3 or higher)
                    if elapsedSinceEmpty >= 3.0 then
                        AutoFarmState.StatusMessage = "CP2 ALL Waves Cleared! Finishing Match & Storing Sword..."
                        task.spawn(function()
                            TryInteractWithCheckpointObjects(2)
                        end)
                        AutoFarmState.CP2_Cleared = true
                        AutoFarmState.CombatStarted = false
                        AutoFarmState.WaveIntermissionStartTime = 0
                        AutoFarmState.CurrentStep = "FINISH_MATCH"
                        AutoFarmState.StepStartTime = now
                    else
                        AutoFarmState.StatusMessage = string.format("CP2 Cleared! Collecting tickets (%.1fs)...", 3.0 - elapsedSinceEmpty)
                        task.spawn(function()
                            TryInteractWithCheckpointObjects(2)
                        end)
                    end
                end
            else
                -- Just arrived at CP2, anchor and wait for bus & Wave 1 to spawn (allow up to 60s for bus travel from CP1)
                if center and ((hrp.Position - center).Magnitude > 60 or hrp.Position.Y < (center.Y - 1)) then
                    TeleportToCFrame(CFrame.new(center))
                end

                local cpWaitLimit = 60.0
                local waitLeft = math.max(0, cpWaitLimit - (now - AutoFarmState.StepStartTime))
                AutoFarmState.StatusMessage = string.format("Waiting for bus & CP2 wave spawn (%.1fs)...", waitLeft)
                if (now - AutoFarmState.StepStartTime > cpWaitLimit) and not waveState.IsRunning and #waveHostiles == 0 then
                    AutoFarmState.StatusMessage = "CP2 timeout/empty! Finishing match..."
                    task.spawn(function()
                        TryInteractWithCheckpointObjects(2)
                    end)
                    AutoFarmState.CP2_Cleared = true
                    AutoFarmState.CombatStarted = false
                    AutoFarmState.WaveIntermissionStartTime = 0
                    AutoFarmState.CurrentStep = "FINISH_MATCH"
                    AutoFarmState.StepStartTime = now
                end
            end
        end
        return
    end

    -- ------------------------------------------------------------------------
    -- STEP: FINISH_MATCH (Farm completed, immediately return to Lobby)
    -- ------------------------------------------------------------------------
    if AutoFarmState.CurrentStep == "FINISH_MATCH" then
        AutoFarmState.MatchCleared = true
        AutoFarmState.Running = false
        AutoFarmState.CurrentStep = "FINISHING_ROUTINE"
        AutoFarmState.StatusMessage = "Ticket Farm Complete! Returning to Lobby..."

        task.spawn(function()
            if Config.AutoLoopNewGame then
                -- Direct delegation to verified return_to_lobby.lua module
                if isfile and isfile("return_to_lobby.lua") then
                    pcall(function()
                        local mod = loadstring(readfile("return_to_lobby.lua"))()
                        if type(mod) == "table" and mod.Execute then
                            mod.Execute({ StoreSword = false })
                        end
                    end)
                else
                    pcall(function()
                        local lp = LocalPlayer
                        local pg = lp and lp:FindFirstChild("PlayerGui")
                        if pg and pg.Main and pg.Main:FindFirstChild("Container") and pg.Main.Container:FindFirstChild("Vault") then
                            pg.Main.Container.Vault.Visible = false
                        end
                    end)
                    TriggerNewGameRestart()
                end
            else
                ReturnToBus()
                SetToggleState("AutoFarmTicket", false)
                AutoFarmState.StatusMessage = "Farm finished. Resting at Bus."
                AutoFarmState.CurrentStep = "IDLE"
            end
        end)
        return
    end
end

local LastAutoFarmError = nil
RegisterConnection(RunService.Heartbeat:Connect(function()
    local ok, err = pcall(StepAutoFarmTicket)
    if not ok and err ~= LastAutoFarmError then
        LastAutoFarmError = err
        warn("[LastStop] AutoFarm step error: " .. tostring(err))
    end
end))

-- ========================================================================
-- DIRECT HARD TARGET LOCK ENGINE (INSTANT 1:1, ZERO SHAKE)
-- ========================================================================
local LockedTargetModel = nil

local function AcquireLockTarget()
    local currentCp = AutoFarmState.ActiveCheckpoint or 1
    -- Sticky lock: keep target locked until dead or out of range
    if LockedTargetModel and LockedTargetModel.Parent then
        local root = LockedTargetModel:FindFirstChild("HumanoidRootPart") or LockedTargetModel:FindFirstChild("Torso") or LockedTargetModel.PrimaryPart
        local hum = LockedTargetModel:FindFirstChildOfClass("Humanoid")
        local hrp = GetHRP()
        local isValid = root and hrp and (not hum or hum.Health > 0) and IsEntityHostile(LockedTargetModel)
        if isValid and Config.TicketFarmWaveOnly then
            local isWave = IsCheckpointWaveEntity(LockedTargetModel, currentCp)
            if not isWave then isValid = false end
        end

        if isValid then
            local dist = (hrp.Position - root.Position).Magnitude
            if dist <= Config.LockRadius then
                -- Stable root-anchored head position (immune to walk animation bobbing)
                return root.Position + Vector3.new(0, 1.4, 0)
            end
        end
    end

    LockedTargetModel = nil
    local hostiles
    if Config.TicketFarmWaveOnly then
        hostiles = GetCheckpointWaveEntities(currentCp)
    else
        hostiles = GetHostileEntities()
    end
    if #hostiles == 0 then return nil end

    local hrp = GetHRP()
    if not hrp then return nil end

    local bestModel = nil
    local bestScore = math.huge

    for _, ent in ipairs(hostiles) do
        if ent.Distance <= Config.LockRadius then
            local root = ent.Root
            local aimPos = root.Position + Vector3.new(0, 1.4, 0)
            local screenPos, onScreen = Camera:WorldToViewportPoint(aimPos)
            if onScreen then
                local mousePos = UserInputService:GetMouseLocation()
                local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                if dist2D < bestScore then
                    bestScore = dist2D
                    bestModel = ent.Model
                end
            elseif not bestModel and ent.Distance < bestScore then
                bestScore = ent.Distance
                bestModel = ent.Model
            end
        end
    end

    if bestModel then
        LockedTargetModel = bestModel
        local root = bestModel:FindFirstChild("HumanoidRootPart") or bestModel:FindFirstChild("Torso") or bestModel.PrimaryPart
        if root then
            return root.Position + Vector3.new(0, 1.4, 0)
        end
    end

    return nil
end

-- Bound specifically AFTER Roblox camera step for 1:1 hard lock with zero camera fight
RunService:BindToRenderStep("LastStop_AutoLock", Enum.RenderPriority.Camera.Value + 1, function()
    if not Config.AutoLock then
        LockedTargetModel = nil
        return
    end

    local targetPos = AcquireLockTarget()
    if targetPos then
        local camPos = Camera.CFrame.Position
        Camera.CFrame = CFrame.lookAt(camPos, targetPos)
    else
        LockedTargetModel = nil
    end
end)

-- Hitbox Expander Loop
RegisterConnection(RunService.Heartbeat:Connect(function()
    if not Config.HitboxExpander then return end
    local hostiles = GetHostileEntities()

    for _, ent in ipairs(hostiles) do
        local root = ent.Root
        if root and root:IsA("BasePart") then
            if not OriginalHitboxSizes[root] then
                OriginalHitboxSizes[root] = root.Size
            end
            root.Size = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
            root.CanCollide = false
            root.Transparency = 0.75
        end
    end
end))

local function RestoreHitboxes()
    for part, size in pairs(OriginalHitboxSizes) do
        if part and part.Parent then
            pcall(function()
                part.Size = size
                part.Transparency = 1
            end)
        end
    end
    OriginalHitboxSizes = {}
end

-- ========================================================================
-- 2. SURVIVAL & BUS AUTOMATION HUB
-- ========================================================================
local function GetBusComponent()
    local bus = GetBusModel()
    if bus and Knit and Knit.Components and Knit.Components.Item then
        return Knit.Components.Item:FromInstance(bus)
    end
    return nil
end

local function GetBusReplicaData()
    local comp = GetBusComponent()
    return comp and comp.Replica and comp.Replica.Data
end

local StandaloneRetreatState = {
    IsRetreating = false,
    PreRetreatCFrame = nil,
    RetreatStartTime = 0,
}

local function ProcessSurvivalAndBus()
    local now = os.clock()
    local hum = GetHumanoid()
    local pData = GetPlayerReplicaData()

    -- Standalone Emergency Sky Retreat (< 50% HP, active outside AutoFarmTicket)
    if Config.EmergencySkyRetreat and not Config.AutoFarmTicket then
        local currentHP = hum and hum.Health or (pData and pData.Health) or 100
        local maxHP = hum and hum.MaxHealth or (pData and pData.MaxHealth) or 100
        local hpPct = (maxHP > 0) and ((currentHP / maxHP) * 100) or 100
        local hrp = GetHRP()

        if hrp and not StandaloneRetreatState.IsRetreating and hpPct < Config.EmergencyRetreatThreshold then
            StandaloneRetreatState.IsRetreating = true
            StandaloneRetreatState.PreRetreatCFrame = hrp.CFrame
            StandaloneRetreatState.RetreatStartTime = now
            StandaloneRetreatState.SwordStored = false

            local skyAlt = math.max(Config.EmergencySkyAltitude, hrp.Position.Y + 250)
            TeleportToCFrame(CFrame.new(hrp.Position.X, skyAlt, hrp.Position.Z))
        elseif hrp and StandaloneRetreatState.IsRetreating then
            local skyAlt = math.max(Config.EmergencySkyAltitude, 350)
            local safeSkyPos = Vector3.new(hrp.Position.X, skyAlt, hrp.Position.Z)
            pcall(function()
                hrp.CFrame = CFrame.new(safeSkyPos)
                hrp.Velocity = Vector3.zero
                hrp.RotVelocity = Vector3.zero
                if hrp.AssemblyLinearVelocity then
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end
                if hum then hum:ChangeState(Enum.HumanoidStateType.Physics) end
            end)

            local char = GetCharacter()
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        pcall(function() part.CanCollide = false end)
                    end
                end
            end

            -- When health recovered or timeout (8s), return to original position
            local retreatElapsed = now - (StandaloneRetreatState.RetreatStartTime or now)
            if hpPct >= Config.EmergencyRecoverThreshold or retreatElapsed > 8.0 then
                if StandaloneRetreatState.PreRetreatCFrame then
                    TeleportToCFrame(StandaloneRetreatState.PreRetreatCFrame)
                end
                StandaloneRetreatState.IsRetreating = false
                StandaloneRetreatState.SwordStored = false
            end
        end
    end

    -- Auto-Revive
    if Config.AutoRevive and ReviveService then
        local isDead = false
        pcall(function() isDead = ReviveService:IsPlayerDead() end)
        if isDead or (hum and hum.Health <= 0) then
            pcall(function() ReviveService:ReviveSelf() end)
        end
    end

    if Config.AutoReviveAll and ReviveService then
        pcall(function() ReviveService:ReviveAll() end)
    end

    -- Instant Auto-Heal (Zero-latency damage response)
    if Config.AutoHeal and ReviveService and now - LastSurvivalCheck > 0.2 then
        local currentHP = hum and hum.Health or (pData and pData.Health) or 100
        local maxHP = hum and hum.MaxHealth or (pData and pData.MaxHealth) or 100
        if (currentHP / maxHP) * 100 <= Config.HealThreshold then
            pcall(function()
                if ReviveService:CanHeal() then
                    ReviveService:Heal()
                    LastSurvivalCheck = now
                end
            end)
        end
    end

    -- Auto-Eat
    if now - LastBusCheck > 1.5 then
        if Config.AutoEat and ItemService then
            local hunger = pData and pData.Hunger or 100
            local maxHunger = pData and pData.MaxHunger or 100
            if (hunger / maxHunger) * 100 <= Config.EatThreshold then
                local backpack = LocalPlayer:FindFirstChild("Backpack")
                if backpack then
                    for _, item in ipairs(backpack:GetChildren()) do
                        if item:IsA("Tool") then
                            local itemComp = Knit and Knit.Components and Knit.Components.Item and Knit.Components.Item:FromInstance(item)
                            if itemComp and itemComp.Config and itemComp.Config.Type == "Food" then
                                pcall(function() ItemService:Eat(item) end)
                                break
                            end
                        end
                    end
                end
            end
        end
        LastSurvivalCheck = now
    end

    -- Infinite Sprint
    if Config.InfiniteSprint and SprintController then
        pcall(function()
            if SprintController.BlockReasons then
                table.clear(SprintController.BlockReasons)
            end
            SprintController.Sprinting = true
        end)
    end

    -- Bus Auto-Fuel
    if Config.AutoFuel and now - LastBusCheck > 2.0 then
        local busComp = GetBusComponent()
        local busData = GetBusReplicaData()
        if busComp and busData then
            local fuel = busData.Fuel or 0
            local maxFuel = busData.MaxFuel or 16000
            if (fuel / maxFuel) * 100 <= Config.FuelThreshold then
                local backpack = LocalPlayer:FindFirstChild("Backpack")
                local fuelTool = nil
                if backpack then
                    for _, item in ipairs(backpack:GetChildren()) do
                        if item:IsA("Tool") and (item.Name:find("Coal") or item:GetAttribute("Feature_Fuel")) then
                            fuelTool = item
                            break
                        end
                    end
                end
                if fuelTool and hum then hum:EquipTool(fuelTool) end
                pcall(function() busComp:CallServer("RequestBurn") end)
            end
        end
        LastBusCheck = now
    end

    -- Horn Spam
    if Config.HornSpam then
        local busComp = GetBusComponent()
        if busComp then
            pcall(function()
                busComp:CallServer("Horn", true)
                task.wait(0.04)
                busComp:CallServer("Horn", false)
            end)
        end
    end
end

RegisterConnection(RunService.Heartbeat:Connect(ProcessSurvivalAndBus))

local function SitInBus()
    local bus = GetBusModel()
    if not bus then return false end
    local seat = bus:FindFirstChild("SeatPart")
    local hum = GetHumanoid()
    local hrp = GetHRP()
    if seat and hum and hrp then
        hrp.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
        task.wait(0.08)
        pcall(function() seat:Sit(hum) end)
        return true
    end
    return false
end

local function ResetToBus()
    if GameService then
        pcall(function() GameService:ResetToBus() end)
    else
        local bus = GetBusModel()
        local hrp = GetHRP()
        if bus and hrp then
            local main = bus:FindFirstChild("Main") or bus.PrimaryPart or bus:GetPivot()
            hrp.CFrame = typeof(main) == "CFrame" and main or main.CFrame + Vector3.new(0, 4, 0)
        end
    end
end

-- ========================================================================
-- 3. TACTICAL VISUALS (ESP ENGINE)
-- ========================================================================
local ESPFolder = RegisterInstance(Instance.new("Folder"))
ESPFolder.Name = "LastStop_ESP_Container"
pcall(function() ESPFolder.Parent = CoreGui end)
if not ESPFolder.Parent then ESPFolder.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local ActiveESPEntries = {}

local function ClearESPForTarget(target)
    if ActiveESPEntries[target] then
        for _, inst in ipairs(ActiveESPEntries[target]) do
            pcall(function() inst:Destroy() end)
        end
        ActiveESPEntries[target] = nil
    end
end

local function CreateESPElement(targetPart, text, color, offset)
    if not targetPart or not targetPart.Parent then return nil end

    local bb = Instance.new("BillboardGui")
    bb.Name = "ESP_Tag"
    bb.Adornee = targetPart
    bb.Size = UDim2.new(0, 150, 0, 32)
    bb.StudsOffset = offset or Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = Config.ESPMaxDistance
    bb.Parent = ESPFolder

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0.25
    label.TextStrokeColor3 = Color3.fromRGB(10, 10, 15)
    label.Text = text or ""
    label.Parent = bb

    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Highlight"
    highlight.Adornee = targetPart:IsA("Model") and targetPart or targetPart.Parent
    highlight.FillColor = color or Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.65
    highlight.OutlineColor = color or Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0.1
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = ESPFolder

    local entry = {bb, highlight}
    ActiveESPEntries[targetPart] = entry
    return entry
end

local LastESPUpdate = 0
RegisterConnection(RunService.RenderStepped:Connect(function()
    local now = os.clock()
    if now - LastESPUpdate < 0.25 then return end
    LastESPUpdate = now

    local hrp = GetHRP()
    if not hrp then return end

    -- Hostiles
    if Config.HostileESP then
        local tagged = CollectionService:GetTagged("Entity")
        for _, model in ipairs(tagged) do
            if model:IsA("Model") and IsEntityHostile(model) then
                local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model.PrimaryPart
                if root then
                    local dist = math.floor((hrp.Position - root.Position).Magnitude)
                    if dist <= Config.ESPMaxDistance then
                        local hum = model:FindFirstChildOfClass("Humanoid")
                        local hp = hum and math.floor(hum.Health) or 100
                        local name = model:GetAttribute("Type") or "Monster"
                        local text = string.format("⚔️ %s\n[%d HP] [%dm]", name, hp, dist)
                        if not ActiveESPEntries[root] then
                            CreateESPElement(root, text, Color3.fromRGB(255, 55, 65))
                        else
                            local bb = ActiveESPEntries[root][1]
                            local lbl = bb and bb:FindFirstChildOfClass("TextLabel")
                            if lbl then lbl.Text = text end
                        end
                    else
                        ClearESPForTarget(root)
                    end
                end
            end
        end
    end

    -- Items & Loot
    if Config.ItemESP and ItemContainer then
        for _, item in ipairs(ItemContainer:GetChildren()) do
            if item.Name ~= "Bus" then
                local part = item:FindFirstChildWhichIsA("BasePart", true)
                if part then
                    local dist = math.floor((hrp.Position - part.Position).Magnitude)
                    if dist <= Config.ESPMaxDistance then
                        local comp = Knit and Knit.Components and Knit.Components.Item and Knit.Components.Item:FromInstance(item)
                        local dName = comp and comp.Config and comp.Config.DisplayName or item.Name
                        local iType = comp and comp.Config and comp.Config.Type or "Loot"
                        local forSale = item:GetAttribute("ForSale") == true

                        local col = Color3.fromRGB(0, 220, 255)
                        if iType == "Weapon" or iType == "Melee" or iType == "Firearm" then
                            col = Color3.fromRGB(255, 80, 80)
                        elseif iType == "Ammo" then
                            col = Color3.fromRGB(255, 190, 0)
                        elseif iType == "Fuel" then
                            col = Color3.fromRGB(255, 130, 0)
                        elseif iType == "Medic" then
                            col = Color3.fromRGB(50, 255, 120)
                        elseif iType == "Food" then
                            col = Color3.fromRGB(120, 255, 200)
                        elseif item.Name:find("Wheel") then
                            col = Color3.fromRGB(255, 215, 0)
                        end

                        local text = string.format("%s%s [%dm]", forSale and "[$] " or "", dName, dist)
                        if not ActiveESPEntries[part] then
                            CreateESPElement(part, text, col, Vector3.new(0, 1.5, 0))
                        else
                            local bb = ActiveESPEntries[part][1]
                            local lbl = bb and bb:FindFirstChildOfClass("TextLabel")
                            if lbl then lbl.Text = text end
                        end
                    else
                        ClearESPForTarget(part)
                    end
                end
            end
        end
    end

    -- Bus ESP
    if Config.BusESP then
        local bus = GetBusModel()
        local part = bus and (bus:FindFirstChild("Main") or bus.PrimaryPart)
        if part then
            local dist = math.floor((hrp.Position - part.Position).Magnitude)
            local busData = GetBusReplicaData()
            local fuel = busData and busData.Fuel or 0
            local maxFuel = busData and busData.MaxFuel or 16000
            local fuelPct = math.floor((fuel / maxFuel) * 100)
            local state = busData and busData.State or "Stop"

            local text = string.format("🚌 BUS [%s] Fuel: %d%% [%dm]", state, fuelPct, dist)
            if not ActiveESPEntries[part] then
                CreateESPElement(part, text, Color3.fromRGB(255, 215, 0), Vector3.new(0, 4, 0))
            else
                local bb = ActiveESPEntries[part][1]
                local lbl = bb and bb:FindFirstChildOfClass("TextLabel")
                if lbl then lbl.Text = text end
            end
        end
    end
end))

local function ClearAllESP()
    for target, _ in pairs(ActiveESPEntries) do
        ClearESPForTarget(target)
    end
    ActiveESPEntries = {}
end

-- ========================================================================
-- 4. MOVEMENT & FLIGHT SUITE
-- ========================================================================
RegisterConnection(RunService.Heartbeat:Connect(function()
    local hum = GetHumanoid()
    if not hum then return end

    if Config.SpeedEnabled then
        hum.WalkSpeed = Config.WalkSpeed
        if CharacterController and type(CharacterController.AddWalkSpeedMultiplier) == "function" then
            pcall(function() CharacterController:AddWalkSpeedMultiplier("SuiteSpeed", Config.WalkSpeed / 16) end)
        end
    end

    if Config.JumpPowerEnabled then
        hum.JumpPower = Config.JumpPower
        if CharacterController and type(CharacterController.AddJumpPower) == "function" then
            pcall(function() CharacterController:AddJumpPower("SuiteJump", Config.JumpPower - 50) end)
        end
    end
end))

RegisterConnection(UserInputService.JumpRequest:Connect(function()
    if Config.InfiniteJump then
        local hum = GetHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

RegisterConnection(RunService.Stepped:Connect(function()
    if Config.Noclip then
        local char = GetCharacter()
        if char then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then
                    p.CanCollide = false
                end
            end
        end
    end
end))

local FlyBodyVel, FlyBodyGyro
local function UpdateFlight()
    local hrp = GetHRP()
    local hum = GetHumanoid()
    if not hrp or not hum then return end

    if Config.FlyEnabled then
        if not FlyBodyVel or FlyBodyVel.Parent ~= hrp then
            FlyBodyVel = RegisterInstance(Instance.new("BodyVelocity"))
            FlyBodyVel.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            FlyBodyVel.Velocity = Vector3.zero
            FlyBodyVel.Parent = hrp
        end

        if not FlyBodyGyro or FlyBodyGyro.Parent ~= hrp then
            FlyBodyGyro = RegisterInstance(Instance.new("BodyGyro"))
            FlyBodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
            FlyBodyGyro.P = 10000
            FlyBodyGyro.D = 100
            FlyBodyGyro.CFrame = hrp.CFrame
            FlyBodyGyro.Parent = hrp
        end

        local moveDir = Vector3.zero
        local camCF = Camera.CFrame

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir -= Vector3.new(0, 1, 0) end

        if moveDir.Magnitude > 0 then
            FlyBodyVel.Velocity = moveDir.Unit * Config.FlySpeed
        else
            FlyBodyVel.Velocity = Vector3.zero
        end
        FlyBodyGyro.CFrame = camCF
        hum.PlatformStand = true
    else
        if FlyBodyVel then FlyBodyVel:Destroy(); FlyBodyVel = nil end
        if FlyBodyGyro then FlyBodyGyro:Destroy(); FlyBodyGyro = nil end
        if hum.PlatformStand then hum.PlatformStand = false end
    end
end

RegisterConnection(RunService.Heartbeat:Connect(UpdateFlight))

-- Click To Teleport
RegisterConnection(UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if Config.ClickToTeleport and input.UserInputType == Enum.UserInputType.MouseButton1 then
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
            local mouseLoc = UserInputService:GetMouseLocation()
            local ray = Camera:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = {GetCharacter()}
            local hit = Workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
            if hit then
                local hrp = GetHRP()
                if hrp then hrp.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3, 0)) end
            end
        end
    end
end))

-- Background Anti-AFK (Always Active)
RegisterConnection(LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.zero)
end))

-- ========================================================================
-- WAYPOINTS & TELEPORTS
-- ========================================================================
local function TeleportToChunk(chunkNumber)
    if not ChunksContainer then return false end
    local chunk = ChunksContainer:FindFirstChild("Chunk_" .. tostring(chunkNumber))
    if chunk then
        local road = chunk:FindFirstChild("Road_" .. tostring(chunkNumber)) or chunk:FindFirstChildWhichIsA("BasePart") or chunk:FindFirstChildWhichIsA("Model")
        local pos = road and (road:IsA("BasePart") and road.Position or road:GetPivot().Position)
        if pos then
            TeleportToCFrame(CFrame.new(pos + Vector3.new(0, 5, 0)))
            return true
        end
    end
    return false
end

-- ========================================================================
-- 5. STREAMLINED 4-TAB RESPONSIVE USER INTERFACE
-- ========================================================================
local ScreenGui = RegisterInstance(Instance.new("ScreenGui"))
ScreenGui.Name = "LastStop_Master_Suite"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Main Window Frame (Compact 540x360)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 540, 0, 365)
MainFrame.Position = UDim2.new(0.5, -270, 0.5, -182)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 23)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Visible = Config.UIVisible
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(36, 42, 56)
MainStroke.Thickness = 1.2
MainStroke.Parent = MainFrame

-- Topbar
local Topbar = Instance.new("Frame")
Topbar.Name = "Topbar"
Topbar.Size = UDim2.new(1, 0, 0, 36)
Topbar.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
Topbar.BorderSizePixel = 0
Topbar.Parent = MainFrame

local TopbarCorner = Instance.new("UICorner")
TopbarCorner.CornerRadius = UDim.new(0, 8)
TopbarCorner.Parent = Topbar

local TopbarFix = Instance.new("Frame")
TopbarFix.Size = UDim2.new(1, 0, 0, 8)
TopbarFix.Position = UDim2.new(0, 0, 1, -8)
TopbarFix.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
TopbarFix.BorderSizePixel = 0
TopbarFix.Parent = Topbar

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(0, 320, 1, 0)
TitleText.Position = UDim2.new(0, 14, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 13
TitleText.TextColor3 = Color3.fromRGB(240, 242, 248)
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Text = "LAST STOP // TACTICAL SUITE"
TitleText.Parent = Topbar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -32, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(180, 185, 200)
CloseBtn.TextSize = 11
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = Topbar

local CloseBtnCorner = Instance.new("UICorner")
CloseBtnCorner.CornerRadius = UDim.new(0, 6)
CloseBtnCorner.Parent = CloseBtn

CloseBtn.MouseButton1Click:Connect(function()
    Config.UIVisible = false
    MainFrame.Visible = false
end)

-- Draggable MainFrame
local Dragging, DragInput, DragStart, StartPos
Topbar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        Dragging = true
        DragStart = input.Position
        StartPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then Dragging = false end
        end)
    end
end)
Topbar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        DragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == DragInput and Dragging then
        local delta = input.Position - DragStart
        MainFrame.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + delta.X, StartPos.Y.Scale, StartPos.Y.Offset + delta.Y)
    end
end)

-- Sidebar Tabs (Streamlined to 4 essential tabs)
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 136, 1, -36)
Sidebar.Position = UDim2.new(0, 0, 0, 36)
Sidebar.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local TabContainer = Instance.new("ScrollingFrame")
TabContainer.Size = UDim2.new(1, -10, 1, -12)
TabContainer.Position = UDim2.new(0, 5, 0, 6)
TabContainer.BackgroundTransparency = 1
TabContainer.ScrollBarThickness = 0
TabContainer.Parent = Sidebar

local TabListLayout = Instance.new("UIListLayout")
TabListLayout.Padding = UDim.new(0, 5)
TabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabListLayout.Parent = TabContainer

-- Content Container
local Content = Instance.new("Frame")
Content.Name = "Content"
Content.Size = UDim2.new(1, -144, 1, -44)
Content.Position = UDim2.new(0, 140, 0, 40)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local TabPages = {}
local TabButtons = {}

local function SwitchTab(tabName)
    for name, page in pairs(TabPages) do
        page.Visible = (name == tabName)
    end
    for name, btn in pairs(TabButtons) do
        if name == tabName then
            btn.BackgroundColor3 = Color3.fromRGB(36, 44, 62)
            btn.TextColor3 = Color3.fromRGB(0, 229, 255)
        else
            btn.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
            btn.TextColor3 = Color3.fromRGB(160, 168, 185)
        end
    end
end

local function CreateTab(name, icon)
    local btn = Instance.new("TextButton")
    btn.Name = name .. "TabBtn"
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
    btn.Font = Enum.Font.GothamMedium
    btn.Text = (icon or "") .. " " .. name
    btn.TextColor3 = Color3.fromRGB(160, 168, 185)
    btn.TextSize = 11
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.AutoButtonColor = false
    btn.Parent = TabContainer

    local btnPad = Instance.new("UIPadding")
    btnPad.PaddingLeft = UDim.new(0, 10)
    btnPad.Parent = btn

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

    local page = Instance.new("ScrollingFrame")
    page.Name = name .. "Page"
    page.Size = UDim2.new(1, -8, 1, 0)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Color3.fromRGB(45, 55, 75)
    page.Visible = false
    page.Parent = Content

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.Padding = UDim.new(0, 6)
    pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pageLayout.Parent = page

    pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, pageLayout.AbsoluteContentSize.Y + 12)
    end)

    btn.MouseButton1Click:Connect(function() SwitchTab(name) end)

    TabPages[name] = page
    TabButtons[name] = btn
    return page
end

-- Reusable UI Builders
local function AddSectionHeader(parent, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextColor3 = Color3.fromRGB(0, 229, 255)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = string.upper(text)
    lbl.Parent = parent
    return lbl
end

local function AddToggle(parent, text, configKey, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 32)
    frame.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
    frame.BorderSizePixel = 0
    frame.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -54, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11
    lbl.TextColor3 = Color3.fromRGB(220, 225, 235)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = text
    lbl.Parent = frame

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 40, 0, 20)
    toggleBtn.Position = UDim2.new(1, -48, 0.5, -10)
    toggleBtn.BackgroundColor3 = Config[configKey] and Color3.fromRGB(0, 200, 140) or Color3.fromRGB(36, 40, 52)
    toggleBtn.Text = ""
    toggleBtn.AutoButtonColor = false
    toggleBtn.Parent = frame

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1, 0)
    toggleCorner.Parent = toggleBtn

    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 16, 0, 16)
    indicator.Position = Config[configKey] and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    indicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    indicator.BorderSizePixel = 0
    indicator.Parent = toggleBtn

    local indCorner = Instance.new("UICorner")
    indCorner.CornerRadius = UDim.new(1, 0)
    indCorner.Parent = indicator

    local function UpdateVisual(val)
        TweenService:Create(toggleBtn, TweenInfo.new(0.18), {
            BackgroundColor3 = val and Color3.fromRGB(0, 200, 140) or Color3.fromRGB(36, 40, 52)
        }):Play()

        TweenService:Create(indicator, TweenInfo.new(0.18), {
            Position = val and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        }):Play()
    end

    ToggleUpdaters[configKey] = UpdateVisual

    toggleBtn.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        local val = Config[configKey]
        UpdateVisual(val)
        if callback then callback(val) end
        SaveConfig()
    end)

    return frame
end

local function AddSlider(parent, text, configKey, min, max, step, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 44)
    frame.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
    frame.BorderSizePixel = 0
    frame.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -70, 0, 18)
    lbl.Position = UDim2.new(0, 10, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11
    lbl.TextColor3 = Color3.fromRGB(220, 225, 235)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = text
    lbl.Parent = frame

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0, 60, 0, 18)
    valLbl.Position = UDim2.new(1, -70, 0, 4)
    valLbl.BackgroundTransparency = 1
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 11
    valLbl.TextColor3 = Color3.fromRGB(0, 229, 255)
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Text = tostring(Config[configKey])
    valLbl.Parent = frame

    local sliderBg = Instance.new("TextButton")
    sliderBg.Size = UDim2.new(1, -20, 0, 8)
    sliderBg.Position = UDim2.new(0, 10, 0, 26)
    sliderBg.BackgroundColor3 = Color3.fromRGB(36, 40, 52)
    sliderBg.Text = ""
    sliderBg.AutoButtonColor = false
    sliderBg.Parent = frame

    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(1, 0)
    sliderCorner.Parent = sliderBg

    local initRatio = math.clamp((Config[configKey] - min) / (max - min), 0, 1)
    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new(initRatio, 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(0, 229, 255)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBg

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = sliderFill

    local sliding = false
    local function UpdateSlide(x)
        local rel = math.clamp((x - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
        local rawVal = min + (max - min) * rel
        local steppedVal = math.floor((rawVal / step) + 0.5) * step
        steppedVal = math.clamp(steppedVal, min, max)

        Config[configKey] = steppedVal
        valLbl.Text = tostring(steppedVal)
        sliderFill.Size = UDim2.new((steppedVal - min) / (max - min), 0, 1, 0)

        if callback then callback(steppedVal) end
        SaveConfig()
    end

    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            UpdateSlide(input.Position.X)
        end
    end)
    sliderBg.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            UpdateSlide(input.Position.X)
        end
    end)

    return frame
end

local function AddButton(parent, text, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = color or Color3.fromRGB(28, 34, 48)
    btn.Font = Enum.Font.GothamBold
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(240, 245, 255)
    btn.TextSize = 11
    btn.AutoButtonColor = false
    btn.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.08), {BackgroundColor3 = Color3.fromRGB(48, 58, 80)}):Play()
        task.delay(0.1, function()
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = color or Color3.fromRGB(28, 34, 48)}):Play()
        end)
        if callback then callback() end
    end)

    return btn
end

-- ========================================================================
-- TAB 1: ⚔️ COMBAT (ZERO SHAKE & DIRECT TARGET LOCK)
-- ========================================================================
local combatPage = CreateTab("Combat", "⚔️")
AddSectionHeader(combatPage, "Automated Kill Aura")
AddToggle(combatPage, "Enable Kill Aura", "KillAura")
AddToggle(combatPage, "Vault Vampire Sword Auto-Cycle", "VaultVampireSword")
AddSlider(combatPage, "Aura Radius (Studs)", "AuraRadius", 10, 80, 5)
AddSlider(combatPage, "Attack Delay (Seconds)", "AuraAttackDelay", 0.05, 0.4, 0.05)
AddSlider(combatPage, "Vault Return Delay (s)", "VaultVampireReturnDelay", 0.1, 2.0, 0.1)

AddSectionHeader(combatPage, "Target Lock (Direct 1:1)")
AddToggle(combatPage, "Enable Target Lock", "AutoLock")
AddSlider(combatPage, "Lock Radius (Studs)", "LockRadius", 20, 120, 5)

AddSectionHeader(combatPage, "Hitbox & Stability")
AddToggle(combatPage, "Dynamic Hitbox Expander", "HitboxExpander", function(enabled)
    if not enabled then RestoreHitboxes() end
end)
AddSlider(combatPage, "Hitbox Scale", "HitboxSize", 10, 45, 5)
AddToggle(combatPage, "No Screen Shake (Smooth Camera)", "NoCameraShake", function(enabled)
    ApplyNoScreenShake(enabled)
end)

-- ========================================================================
-- TAB 2: 🤖 AUTO FARM (TICKET & CHECKPOINT WAVE CLEAR)
-- ========================================================================
local autoFarmPage = CreateTab("Auto Farm", "🤖")

AddSectionHeader(autoFarmPage, "1-Click Ticket Auto-Farm (CP1 -> CP2)")
local autoFarmStatusLbl = AddSectionHeader(autoFarmPage, "Status: Idle")
autoFarmStatusLbl.TextColor3 = Color3.fromRGB(255, 200, 80)
autoFarmStatusLbl.TextSize = 10
local lastRenderedAutoFarmStatus = ""
RegisterConnection(RunService.Heartbeat:Connect(function()
    if autoFarmStatusLbl and autoFarmStatusLbl.Parent then
        local newStatus = "STATUS: " .. string.upper(AutoFarmState.StatusMessage)
        if newStatus ~= lastRenderedAutoFarmStatus then
            lastRenderedAutoFarmStatus = newStatus
            autoFarmStatusLbl.Text = newStatus
        end
    end
end))

AddToggle(autoFarmPage, "1-Click Ticket Auto-Farm (All Waves)", "AutoFarmTicket", function(enabled)
    if enabled then
        AutoFarmState.MatchCleared = false
        AutoFarmState.CP1_Cleared = false
        AutoFarmState.CP2_Cleared = false
        AutoFarmState.CurrentStep = "IDLE"
        Config.UnderneathHover = true
        Config.TicketFarmWaveOnly = true
        Config.VaultVampireSword = true
        Config.AutoHeal = true
        Config.HealThreshold = 95
    end
end)

AddButton(autoFarmPage, "Reset Match Run Status", Color3.fromRGB(180, 80, 50), function()
    ResetAutoFarmMatch()
end)

AddSectionHeader(autoFarmPage, "Evasion & Anti-Damage")
AddToggle(autoFarmPage, "Anti-Void Guardian (Fall Prevention)", "AntiVoid")
AddToggle(autoFarmPage, "Underneath Hover (Anti-Damage)", "UnderneathHover")
AddSlider(autoFarmPage, "Underneath Distance", "UnderneathOffset", 3.0, 7.0, 0.5)
AddToggle(autoFarmPage, "Emergency Sky Retreat (< 50% HP)", "EmergencySkyRetreat")
AddToggle(autoFarmPage, "Store Sword on Low HP (< 50%)", "EmergencyStoreSword")
AddSlider(autoFarmPage, "Retreat HP Threshold (%)", "EmergencyRetreatThreshold", 20, 80, 5)
AddSlider(autoFarmPage, "Recover HP Threshold (%)", "EmergencyRecoverThreshold", 60, 100, 5)
AddSlider(autoFarmPage, "Sky Flight Altitude", "EmergencySkyAltitude", 200, 600, 25)

AddSectionHeader(autoFarmPage, "Farming Weapon & Targets")
AddToggle(autoFarmPage, "Wave Enemies Only Focus", "TicketFarmWaveOnly")
AddToggle(autoFarmPage, "Vault Vampire Sword Auto-Cycle", "VaultVampireSword")
AddSlider(autoFarmPage, "Attack Delay (Seconds)", "AuraAttackDelay", 0.05, 0.4, 0.05)

AddSectionHeader(autoFarmPage, "Vault Storage & Auto-Loop New Game")
AddToggle(autoFarmPage, "Auto-Store Sword on Finish (Mandatory)", "AutoStoreSwordOnFinish")
AddToggle(autoFarmPage, "Auto-Loop New Game (Continuous Farm)", "AutoLoopNewGame")
AddToggle(autoFarmPage, "Auto-Start Farm on Game Load", "AutoStartFarmOnLoad")
AddToggle(autoFarmPage, "Auto-Skip Intro & Cutscenes", "AutoSkipIntro")

local methodBtn = AddButton(autoFarmPage, "Restart Mode: " .. tostring(Config.LoopRestartMethod or "PlayAgain"), Color3.fromRGB(70, 110, 150), function() end)
methodBtn.MouseButton1Click:Connect(function()
    if Config.LoopRestartMethod == "PlayAgain" then
        Config.LoopRestartMethod = "ReturnLobby"
    else
        Config.LoopRestartMethod = "PlayAgain"
    end
    SaveConfig()
    methodBtn.Text = "Restart Mode: " .. tostring(Config.LoopRestartMethod)
end)

AddButton(autoFarmPage, "Deposit All Swords to Vault Now", Color3.fromRGB(130, 90, 180), function()
    task.spawn(function()
        autoFarmStatusLbl.Text = "STATUS: STORING ALL SWORDS TO VAULT..."
        local ok, msg = ForceStoreSwordToVault()
        autoFarmStatusLbl.Text = "STATUS: " .. string.upper(msg or "COMPLETE")
    end)
end)

AddButton(autoFarmPage, "Store Sword & Start New Game Now", Color3.fromRGB(180, 60, 60), function()
    task.spawn(function()
        autoFarmStatusLbl.Text = "STATUS: STORING SWORD BEFORE RESTART..."
        local ok, msg = ForceStoreSwordToVault()
        if not ok then
            autoFarmStatusLbl.Text = "STATUS: " .. string.upper(msg or "FAILED TO STORE SWORD! ABORTED")
            return
        end
        autoFarmStatusLbl.Text = "STATUS: SWORD SECURED. RETURNING TO LOBBY..."
        task.wait(0.5)
        TriggerNewGameRestart()
    end)
end)

AddSectionHeader(autoFarmPage, "Manual Teleports & Bus Return")
AddButton(autoFarmPage, "Teleport to Checkpoint 1 (Wave 1)", Color3.fromRGB(50, 140, 80), function()
    TeleportToCheckpoint(1)
end)
AddButton(autoFarmPage, "Teleport to Checkpoint 2 (Wave 2)", Color3.fromRGB(40, 100, 160), function()
    TeleportToCheckpoint(2)
end)
AddButton(autoFarmPage, "Return to Bus (Safe Area)", Color3.fromRGB(150, 120, 40), function()
    ReturnToBus()
end)

-- ========================================================================
-- TAB 3: 🛡️ SURVIVAL & BUS (STREAMLINED ESSENTIALS)
-- ========================================================================
local survivalPage = CreateTab("Survival & Bus", "🛡️")
AddSectionHeader(survivalPage, "Godmode & Medical")
AddToggle(survivalPage, "Instant Auto-Revive (Self)", "AutoRevive")
AddToggle(survivalPage, "Auto-Revive All Teammates", "AutoReviveAll")
AddToggle(survivalPage, "Auto-Heal Health", "AutoHeal")
AddSlider(survivalPage, "Heal Threshold (%)", "HealThreshold", 20, 95, 5)
AddToggle(survivalPage, "Auto-Eat (Anti-Starve)", "AutoEat")
AddSlider(survivalPage, "Eat Threshold (%)", "EatThreshold", 30, 95, 5)
AddToggle(survivalPage, "Infinite Sprint (No Stamina Limit)", "InfiniteSprint")

AddSectionHeader(survivalPage, "Emergency Sky Retreat (< 50% HP)")
AddToggle(survivalPage, "Anti-Void Guardian (Fall Prevention)", "AntiVoid")
AddToggle(survivalPage, "Emergency Sky Retreat", "EmergencySkyRetreat")
AddToggle(survivalPage, "Store Sword on Low HP (< 50%)", "EmergencyStoreSword")
AddSlider(survivalPage, "Retreat HP Threshold (%)", "EmergencyRetreatThreshold", 20, 80, 5)
AddSlider(survivalPage, "Recover HP Threshold (%)", "EmergencyRecoverThreshold", 60, 100, 5)
AddSlider(survivalPage, "Sky Flight Altitude", "EmergencySkyAltitude", 200, 600, 25)

AddSectionHeader(survivalPage, "Bus Automation")
AddToggle(survivalPage, "Auto-Feed Furnace (Auto-Fuel)", "AutoFuel")
AddSlider(survivalPage, "Fuel Refill Threshold (%)", "FuelThreshold", 20, 90, 5)
AddToggle(survivalPage, "Rapid Horn Spam", "HornSpam")

AddSectionHeader(survivalPage, "Immediate Actions")
AddButton(survivalPage, "Revive Self Immediately", Color3.fromRGB(0, 150, 100), function()
    if ReviveService then pcall(function() ReviveService:ReviveSelf() end) end
end)
AddButton(survivalPage, "Board Driver Seat Instantly", Color3.fromRGB(190, 130, 10), function()
    SitInBus()
end)
AddButton(survivalPage, "Reset / Teleport To Bus", Color3.fromRGB(150, 90, 20), function()
    ResetToBus()
end)
AddButton(survivalPage, "Honk Bus Horn Once", Color3.fromRGB(50, 60, 80), function()
    local busComp = GetBusComponent()
    if busComp then
        pcall(function()
            busComp:CallServer("Horn", true)
            task.delay(0.18, function() busComp:CallServer("Horn", false) end)
        end)
    end
end)

-- ========================================================================
-- TAB 3: ⚡ MOVEMENT
-- ========================================================================
-- TAB 4: ⚡ MOVEMENT
-- ========================================================================
local movePage = CreateTab("Movement", "⚡")
AddSectionHeader(movePage, "Speed & Jump")
AddToggle(movePage, "Custom WalkSpeed", "SpeedEnabled")
AddSlider(movePage, "WalkSpeed Value", "WalkSpeed", 16, 120, 2)
AddToggle(movePage, "Custom JumpPower", "JumpPowerEnabled")
AddSlider(movePage, "JumpPower Value", "JumpPower", 50, 160, 5)
AddToggle(movePage, "Infinite Jump", "InfiniteJump")

AddSectionHeader(movePage, "Physics Overrides")
AddToggle(movePage, "NoClip (Walk Through Walls)", "Noclip")
AddToggle(movePage, "3D Flight Engine (WASD + Space/Shift)", "FlyEnabled", function(enabled)
    if not enabled and FlyBodyVel then
        FlyBodyVel:Destroy()
        FlyBodyVel = nil
    end
end)
AddSlider(movePage, "Flight Speed", "FlySpeed", 20, 180, 5)

-- ========================================================================
-- TAB 5: 👁️ VISUALS & FAST TRAVEL
-- ========================================================================
local visualsPage = CreateTab("Visuals & TP", "👁️")
AddSectionHeader(visualsPage, "ESP Overlays")
AddToggle(visualsPage, "Hostile Entities ESP (Red)", "HostileESP")
AddToggle(visualsPage, "Items & Loot ESP (Categorized)", "ItemESP")
AddToggle(visualsPage, "Bus Telemetry ESP (Gold)", "BusESP")
AddSlider(visualsPage, "Max Render Distance", "ESPMaxDistance", 100, 2000, 100)

AddSectionHeader(visualsPage, "Fast Travel Network")
AddButton(visualsPage, "Teleport To Bus Cabin", Color3.fromRGB(180, 120, 20), function()
    ResetToBus()
end)
AddButton(visualsPage, "Teleport To Start Terminal & Shop", Color3.fromRGB(40, 120, 160), function()
    TeleportToChunk(1)
end)
AddButton(visualsPage, "Teleport To Checkpoint 1 (Wave 1)", Color3.fromRGB(50, 140, 80), function()
    TeleportToCheckpoint(1)
end)
AddButton(visualsPage, "Teleport To Checkpoint 2 (Wave 2)", Color3.fromRGB(40, 100, 160), function()
    TeleportToCheckpoint(2)
end)
AddButton(visualsPage, "Teleport To Last Stop (Chunk 47)", Color3.fromRGB(140, 60, 180), function()
    TeleportToChunk(47)
end)
AddButton(visualsPage, "Teleport To Nearest Hostile", Color3.fromRGB(160, 40, 40), function()
    local hostiles = GetHostileEntities()
    if #hostiles > 0 then
        table.sort(hostiles, function(a, b) return a.Distance < b.Distance end)
        TeleportToCFrame(hostiles[1].Root.CFrame + Vector3.new(0, 3, 5))
    end
end)
AddToggle(visualsPage, "Ctrl + Click To Teleport", "ClickToTeleport")

AddSectionHeader(visualsPage, "Script Management")
AddButton(visualsPage, "Unload Script Suite Safely", Color3.fromRGB(160, 30, 40), function()
    if typeof(getgenv().LastStopSuite_Unload) == "function" then
        getgenv().LastStopSuite_Unload()
    end
end)

-- Default Active Tab
SwitchTab("Combat")

-- ========================================================================
-- FLOATING MOBILE TOGGLE PILL
-- ========================================================================
local MobilePill = RegisterInstance(Instance.new("TextButton"))
MobilePill.Name = "LastStop_MobilePill"
MobilePill.Size = UDim2.new(0, 42, 0, 42)
MobilePill.Position = UDim2.new(0, 14, 0.5, -21)
MobilePill.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
MobilePill.Font = Enum.Font.GothamBold
MobilePill.Text = "LS"
MobilePill.TextColor3 = Color3.fromRGB(0, 229, 255)
MobilePill.TextSize = 13
MobilePill.AutoButtonColor = false
MobilePill.Parent = ScreenGui

local PillCorner = Instance.new("UICorner")
PillCorner.CornerRadius = UDim.new(1, 0)
PillCorner.Parent = MobilePill

local PillStroke = Instance.new("UIStroke")
PillStroke.Color = Color3.fromRGB(0, 229, 255)
PillStroke.Thickness = 1.2
PillStroke.Parent = MobilePill

local PillDragging, PillDragStart, PillStartPos
MobilePill.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        PillDragging = true
        PillDragStart = input.Position
        PillStartPos = MobilePill.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then PillDragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if PillDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - PillDragStart
        MobilePill.Position = UDim2.new(PillStartPos.X.Scale, PillStartPos.X.Offset + delta.X, PillStartPos.Y.Scale, PillStartPos.Y.Offset + delta.Y)
    end
end)
MobilePill.MouseButton1Click:Connect(function()
    Config.UIVisible = not Config.UIVisible
    MainFrame.Visible = Config.UIVisible
end)

-- Keyboard Toggle
RegisterConnection(UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Config.UIKeybind or input.KeyCode == Enum.KeyCode.Insert then
        Config.UIVisible = not Config.UIVisible
        MainFrame.Visible = Config.UIVisible
    end
end))

-- ========================================================================
-- DESTRUCTOR & ZERO-LEAK UNLOAD
-- ========================================================================
getgenv().LastStopSuite_Unload = function()
    -- Unbind AutoLock RenderStep
    pcall(function() RunService:UnbindFromRenderStep("LastStop_AutoLock") end)

    -- Disconnect all events
    for _, conn in ipairs(Connections) do
        if conn and conn.Disconnect then
            pcall(function() conn:Disconnect() end)
        end
    end
    Connections = {}

    -- Restore Hitboxes & Camera Shake
    RestoreHitboxes()
    ApplyNoScreenShake(false)

    -- Safely return Vampire Sword to vault if held
    if VaultAuraState and VaultAuraState.IsHoldingVampireFromVault then
        pcall(StoreVampireSwordToVault)
    end

    -- Clear ESP
    ClearAllESP()

    -- Destroy flight physics
    if FlyBodyVel then pcall(function() FlyBodyVel:Destroy() end) end
    if FlyBodyGyro then pcall(function() FlyBodyGyro:Destroy() end) end

    -- Restore Humanoid properties
    local hum = GetHumanoid()
    if hum then
        pcall(function()
            hum.WalkSpeed = 16
            hum.JumpPower = 50
            hum.PlatformStand = false
        end)
    end

    if CharacterController and type(CharacterController.RemoveWalkSpeedMultiplier) == "function" then
        pcall(function()
            CharacterController:RemoveWalkSpeedMultiplier("SuiteSpeed")
            CharacterController:RemoveJumpPower("SuiteJump")
        end)
    end

    -- Destroy UI instances
    for _, inst in ipairs(ManagedInstances) do
        if inst and inst.Destroy then
            pcall(function() inst:Destroy() end)
        end
    end
    ManagedInstances = {}

    getgenv().LastStopSuite_Loaded = false
    print("[LastStopSuite] Teardown complete. All hooks and instances unallocated.")
end

-- Proactive queue on teleport setup
SetupAutoReexec()

-- If running in game and AutoLoop + AutoStart is enabled, auto-start farming after load
task.spawn(function()
    task.wait(4.0)
    if Config.AutoLoopNewGame and Config.AutoStartFarmOnLoad and (game.PlaceId == 122776220269735) then
        AutoFarmState.MatchCleared = false
        AutoFarmState.CP1_Cleared = false
        AutoFarmState.CP2_Cleared = false
        if not AutoFarmState.Running then
            print("[LastStopSuite] AutoLoop enabled: Auto-starting AutoFarm for new match...")
            SetToggleState("AutoFarmTicket", true)
        end
    end
end)

print("[LastStopSuite] Streamlined suite initialized successfully for Last Stop [Beta] - Game")
