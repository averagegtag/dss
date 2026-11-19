-- Doors OP v2 | LinoriaLib
-- Merged base + Abysall features + extras

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library     = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager  = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

-- ─── Services ────────────────────────────────────────────────────────────────
local Players          = game:GetService('Players')
local RunService       = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local TweenService     = game:GetService('TweenService')
local Lighting         = game:GetService('Lighting')
local VirtualUser      = game:GetService('VirtualUser')
local CoreGui          = game:GetService('CoreGui')
local Debris           = game:GetService('Debris')

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- ─── Game refs ───────────────────────────────────────────────────────────────
local ReplicatedStorage   = game:GetService('ReplicatedStorage')
local GameData            = ReplicatedStorage:WaitForChild('GameData', 15)
local FloorValue          = GameData and GameData:FindFirstChild('Floor')
local Floor               = FloorValue and FloorValue.Value or 'Hotel'
local LatestRoom          = GameData and GameData:FindFirstChild('LatestRoom')
local RemotesFolder       = ReplicatedStorage:FindFirstChild('RemotesFolder')
    or ReplicatedStorage:FindFirstChild('EntityInfo')
    or ReplicatedStorage:FindFirstChild('Bricks')
local LiveModifiers       = ReplicatedStorage:FindFirstChild('LiveModifiers') or Instance.new('Folder')
local FloorReplicated     = ReplicatedStorage:FindFirstChild('FloorReplicated') or Instance.new('Folder')
local CurrentRooms        = workspace:FindFirstChild('CurrentRooms')
local Drops               = workspace:FindFirstChild('Drops')

-- floor detection fixup
if Floor == 'Hotel' and RemotesFolder and RemotesFolder.Name == 'Bricks' then
    Floor = 'OldHotel'
end

-- ─── Character ───────────────────────────────────────────────────────────────
local Character, Humanoid, RootPart
local CollisionPart  -- used for crouching detection on new floors

local function RefreshCharacter(Char)
    Character = Char or LocalPlayer.Character
    if Character then
        Humanoid = Character:FindFirstChildOfClass('Humanoid')
        RootPart = Character:FindFirstChild('HumanoidRootPart')
        for _, Part in Character:GetDescendants() do
            if Part:IsA('BasePart') and Part.CollisionGroup then
                CollisionPart = Part
                break
            end
        end
    end
end
RefreshCharacter()
LocalPlayer.CharacterAdded:Connect(function(Char)
    task.wait(0.5)
    RefreshCharacter(Char)
end)

-- ─── Object tables ───────────────────────────────────────────────────────────
local Objects = {
    Entities        = {},
    Items           = {},
    Doors           = {},
    HidingSpots     = {},
    Prompts         = {},
    Obstructions    = {},
    SeekObs         = {},
    SeekObstructions = {},
    SeekBridges     = {},
    Chests          = {},
    Currency        = {},
    Ladders         = {},
    Objectives      = {},
}

local EntityNames = {
    RushMoving=true, AmbushMoving=true, BashMoving=true, BackdoorRush=true,
    GlitchRush=true, GlitchAmbush=true, A60=true, A120=true, Scribbles=true,
    DronesStampede=true, CustomEntity=true, Eyes=true, Lookman=true,
    BackdoorLookman=true, FigureRig=true, Figure=true, GiggleCeiling=true,
    NoiseModel=true, Creak=true, TellerRig=true, SallyMoving=true,
    MonumentEntity=true, GloombatSwarm=true, JeffTheKiller=true,
    Groundskeeper=true, Weaveling=true, FrozenAmbush=true,
    TV_Stand=true, StemsEntity=true, Drones=true, Alma=true,
    -- traps
    DoorFake=true, FakeDoor=true, SideroomSpace=true, Snare=true, BananaPeel=true,
}

local EntityAliasMap = {
    RushMoving='Rush', AmbushMoving='Ambush', BashMoving='Bash',
    BackdoorRush='Blitz', GlitchRush='RNIUSHCG==', GlitchAmbush='AR0xMBUSH',
    A60='A-60', A120='A-120', Scribbles='Scribbles', DronesStampede='DronesStampede',
    Eyes='Eyes', Lookman='Lookman', BackdoorLookman='Lookman', Groundskeeper='Groundskeeper',
    MonumentEntity='Monument', JeffTheKiller='Jeff', GloombatSwarm='Gloombat',
    SallyMoving='Sally', Weaveling='Weaveling', FrozenAmbush='FrozenAmbush',
}

local EntityDetectDist = {
    RushMoving=85, AmbushMoving=150, BashMoving=150, BackdoorRush=85,
    GlitchRush=90, GlitchAmbush=175, A60=125, A120=85,
    Scribbles=100, DronesStampede=100, CustomEntity=85,
}

local EntityNotifyMessages = {
    RushMoving     = { Title='Rush has spawned',           Body='Find a hiding spot.' },
    AmbushMoving   = { Title='Ambush has spawned',         Body='Find a hiding spot.' },
    BashMoving     = { Title='Bash has spawned',           Body='Find a hiding spot.' },
    BackdoorRush   = { Title='Blitz has spawned',          Body='Find a hiding spot.' },
    GlitchRush     = { Title='RNIUSHCG== has spawned',     Body='Find a hiding spot.' },
    GlitchAmbush   = { Title='AR0xMBUSH has spawned',      Body='Find a hiding spot.' },
    A60            = { Title='A-60 has spawned',           Body='Find a hiding spot.' },
    A120           = { Title='A-120 has spawned',          Body='Find a hiding spot.' },
    Scribbles      = { Title='Scribbles has spawned',      Body='Find a hiding spot.' },
    DronesStampede = { Title='Drones Stampede has spawned',Body='Find a hiding spot.' },
    Eyes           = { Title='Eyes has spawned',           Body='Avoid looking at it.' },
    Lookman        = { Title='Lookman has spawned',        Body='Avoid looking at its eyes.' },
    BackdoorLookman= { Title='Lookman has spawned',        Body='Avoid looking at its eyes.' },
    MonumentEntity = { Title='Monument has spawned',       Body="It can't move while you look at it." },
    JeffTheKiller  = { Title='Jeff the Killer has spawned',Body='Avoid touching him.' },
    GloombatSwarm  = { Title='Gloombat Swarm has spawned', Body='Keep light sources off.' },
    Groundskeeper  = { Title='Groundskeeper has spawned',  Body='Avoid stepping on grass.' },
    SallyMoving    = { Title='Sally has spawned',          Body='Find her horse.' },
    Weaveling      = { Title='Weaveling has spawned',      Body='Try to grab it.' },
    Creak          = { Title='Creak has spawned',          Body="Don't touch him." },
    FrozenAmbush   = { Title='Frozen Ambush has spawned',  Body='Find a hiding spot.' },
    CustomEntity   = { Title='Custom Entity has spawned',  Body='Find a hiding spot.' },
}

-- ─── ESP (Highlight) ─────────────────────────────────────────────────────────
local ESPObjects = {}

local function AddESP(Object, FillColor, OutlineColor)
    if not Object or not Object.Parent then return end
    if ESPObjects[Object] then
        ESPObjects[Object].FillColor    = FillColor    or ESPObjects[Object].FillColor
        ESPObjects[Object].OutlineColor = OutlineColor or ESPObjects[Object].OutlineColor
        return
    end
    local Hl = Instance.new('Highlight')
    Hl.FillColor          = FillColor    or Color3.fromRGB(255, 50, 50)
    Hl.OutlineColor       = OutlineColor or Color3.fromRGB(255, 150, 150)
    Hl.FillTransparency   = 0.5
    Hl.OutlineTransparency = 0
    Hl.DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop
    Hl.Adornee            = Object
    Hl.Parent             = Camera
    ESPObjects[Object]    = Hl
    pcall(function()
        Object.Destroying:Once(function()
            if Hl and Hl.Parent then Hl:Destroy() end
            ESPObjects[Object] = nil
        end)
    end)
end

local function RemoveESP(Object)
    if ESPObjects[Object] then
        ESPObjects[Object]:Destroy()
        ESPObjects[Object] = nil
    end
end

local function ClearESPGroup(Group)
    for Obj in pairs(ESPObjects) do
        if table.find(Group, Obj) then RemoveESP(Obj) end
    end
end

-- ─── Object scanning ─────────────────────────────────────────────────────────
local function RegisterPrompt(Prompt)
    if table.find(Objects.Prompts, Prompt) then return end
    Prompt:SetAttribute('MaxActivationDistance_Old', Prompt.MaxActivationDistance)
    Prompt:SetAttribute('HoldDuration_Old',          Prompt.HoldDuration)
    Prompt:SetAttribute('RequiresLineOfSight_Old',   Prompt.RequiresLineOfSight)
    table.insert(Objects.Prompts, Prompt)
    Prompt.Destroying:Once(function()
        local i = table.find(Objects.Prompts, Prompt)
        if i then table.remove(Objects.Prompts, i) end
    end)
end

local function ScanRoom(Room)
    for _, Obj in Room:GetDescendants() do
        if Obj:IsA('ProximityPrompt') then
            RegisterPrompt(Obj)
        end
        if Obj.Name == 'Door' and Obj:IsA('Model') and not table.find(Objects.Doors, Obj) then
            table.insert(Objects.Doors, Obj)
            Obj:SetAttribute('ParentRoom', tonumber(Room.Name))
            Obj.Destroying:Once(function()
                local i = table.find(Objects.Doors, Obj) if i then table.remove(Objects.Doors, i) end
            end)
        end
        local LN = Obj.Name:lower()
        if (Obj.Name == 'HidingSpot' or LN:find('hidingspot') or LN:find('hiding_spot'))
            and Obj:IsA('Model') and not table.find(Objects.HidingSpots, Obj) then
            table.insert(Objects.HidingSpots, Obj)
            Obj.Destroying:Once(function()
                local i = table.find(Objects.HidingSpots, Obj) if i then table.remove(Objects.HidingSpots, i) end
            end)
        end
        if Obj.Name == 'Chest' and Obj:IsA('Model') and not table.find(Objects.Chests, Obj) then
            table.insert(Objects.Chests, Obj)
            Obj.Destroying:Once(function()
                local i = table.find(Objects.Chests, Obj) if i then table.remove(Objects.Chests, i) end
            end)
        end
        if (Obj.Name == 'Lava' or Obj.Name == 'ScaryWall') and not table.find(Objects.Obstructions, Obj) then
            table.insert(Objects.Obstructions, Obj)
        end
        if Obj:GetAttribute('SeekObstruction') and Obj:IsA('BasePart') and not table.find(Objects.SeekObs, Obj) then
            table.insert(Objects.SeekObs, Obj)
        end
        -- seek bridges (from Abysall)
        if Obj:GetAttribute('SeekBridge') and Obj:IsA('BasePart') and not table.find(Objects.SeekBridges, Obj) then
            table.insert(Objects.SeekBridges, Obj)
        end
        -- currency
        if (Obj.Name == 'Gold' or Obj.Name == 'Coin' or Obj:GetAttribute('IsCurrency'))
            and not table.find(Objects.Currency, Obj) then
            table.insert(Objects.Currency, Obj)
            Obj.Destroying:Once(function()
                local i = table.find(Objects.Currency, Obj) if i then table.remove(Objects.Currency, i) end
            end)
        end
    end
end

local function RegisterEntity(Obj)
    if not EntityNames[Obj.Name] then return end
    if table.find(Objects.Entities, Obj) then return end
    table.insert(Objects.Entities, Obj)
    -- entity spawn notification
    local Msg = EntityNotifyMessages[Obj.Name]
    if Msg then
        Library:Notify({ Title = Msg.Title, Description = Msg.Body, Time = 5 })
    end
    Obj.Destroying:Once(function()
        local i = table.find(Objects.Entities, Obj) if i then table.remove(Objects.Entities, i) end
        RemoveESP(Obj)
    end)
end

local function RegisterItem(Obj)
    if table.find(Objects.Items, Obj) then return end
    table.insert(Objects.Items, Obj)
    Obj.Destroying:Once(function()
        local i = table.find(Objects.Items, Obj) if i then table.remove(Objects.Items, i) end
        RemoveESP(Obj)
    end)
end

if CurrentRooms then
    for _, Room in CurrentRooms:GetChildren() do task.spawn(ScanRoom, Room) end
    CurrentRooms.ChildAdded:Connect(function(Room) task.wait(0.5) ScanRoom(Room) end)
end

for _, Child in workspace:GetChildren() do RegisterEntity(Child) end
workspace.ChildAdded:Connect(RegisterEntity)

if Drops then
    for _, Item in Drops:GetChildren() do RegisterItem(Item) end
    Drops.ChildAdded:Connect(RegisterItem)
end

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local function FireRemote(Name, ...)
    if not RemotesFolder then return end
    local R = RemotesFolder:FindFirstChild(Name)
    if R then pcall(function() R:FireServer(...) end) end
end

local function IsCrouching()
    if Floor == 'Fools' or Floor == 'OldHotel' then
        return Character and Character:GetAttribute('Crouching')
    end
    return CollisionPart and CollisionPart.CollisionGroup == 'PlayerCrouching'
end

local function GetNearestThreat()
    for _, E in Objects.Entities do
        if not E or not E.Parent then continue end
        local Alias = EntityAliasMap[E.Name]
        if not Alias then continue end
        local IgnoreList = Options.AutoClosetIgnoreList and Options.AutoClosetIgnoreList.Value or {}
        if IgnoreList[Alias] then continue end
        local PrimaryPart = E.PrimaryPart or E:FindFirstChildOfClass('BasePart')
        if not PrimaryPart then continue end
        local Dist = LocalPlayer:DistanceFromCharacter(PrimaryPart.Position)
        if Dist < (EntityDetectDist[E.Name] or 85) then return E end
    end
end

local function GetNearestHidingSpot()
    local Best, BestDist = nil, math.huge
    local LastHide = Character and Character:FindFirstChild('LastHideSpot')

    for _, Spot in Objects.HidingSpots do
        if not Spot or not Spot.Parent then continue end
        local Part = Spot.PrimaryPart or Spot:FindFirstChildOfClass('BasePart')
        if not Part then continue end
        local Prompt = Spot:FindFirstChild('HidePrompt', true) or Spot:FindFirstChild('HidingPrompt', true)
        if not Prompt then continue end
        local Dist = LocalPlayer:DistanceFromCharacter(Part.Position)
        local Persistent = Floor == 'Mines' or Floor == 'Ripple' or Floor == 'Party'
            or (LiveModifiers:FindFirstChild('HideLevel2') ~= nil)
        if Dist < (Prompt.MaxActivationDistance or 10) and Dist < BestDist then
            if not Persistent or not LastHide or LastHide.Value ~= Spot then
                BestDist = Dist
                Best = Spot
            end
        end
    end
    return Best
end

local function GetNextClosedDoor()
    if not Character then return nil, nil end
    local StartRoom = LatestRoom and LatestRoom.Value or 0
    local Best, BestNum = nil, math.huge
    if CurrentRooms then
        for _, Room in CurrentRooms:GetChildren() do
            local Num  = tonumber(Room.Name)
            if not Num or Num == 100 or Num < StartRoom or Num >= BestNum then continue end
            local Door = Room:FindFirstChild('Door')
            if Door and Door:IsA('Model') then
                local Open = Door:GetAttribute('Open')
                if Open == false or Open == nil then
                    BestNum = Num
                    Best = Door
                end
            end
        end
    end
    return Best, BestNum
end

-- ─── Fake-remote intercepts (Screech / Shade / A90 / Surge) ──────────────────
local function HookFakeRemotes()
    local FakeScreenchRemote = Instance.new('RemoteEvent')
    FakeScreenchRemote.Name = 'Screech'
    local FakeShadeRemote = Instance.new('RemoteEvent')
    FakeShadeRemote.Name = 'ShadeResult'

    if RemotesFolder then
        local RealScreech = RemotesFolder:FindFirstChild('Screech')
        local RealShade   = RemotesFolder:FindFirstChild('ShadeResult')
        if RealScreech then
            RealScreech.OnClientEvent:Connect(function(...)
                if Toggles.BypassScreech and Toggles.BypassScreech.Value then return end
                FakeScreenchRemote:FireServer(...)
            end)
        end
        if RealShade then
            RealShade.OnClientEvent:Connect(function(...)
                if Toggles.BypassShade and Toggles.BypassShade.Value then return end
                FakeShadeRemote:FireServer(...)
            end)
        end
        -- remove fake footstep remote if present
        local FakeFootstep = RemotesFolder:FindFirstChild('FootstepRemoteThatWeNeed')
        if FakeFootstep then
            FakeFootstep:Destroy()
            local NewFake = Instance.new('RemoteEvent', RemotesFolder)
            NewFake.Name = 'FootstepRemoteThatWeNeed'
        end
    end
end
task.spawn(HookFakeRemotes)

-- ═════════════════════════════════════════════════════════════════════════════
--  WINDOW + TABS
-- ═════════════════════════════════════════════════════════════════════════════
local Window = Library:CreateWindow({
    Title       = 'avDoors',
    Center      = true,
    AutoShow    = true,
    TabPadding  = 8,
    MenuFadeTime = 0.2,
})

local Tabs = {
    Movement   = Window:AddTab('Movement'),
    Self       = Window:AddTab('Self'),
    Auto       = Window:AddTab('Auto'),
    Bypass     = Window:AddTab('Bypass'),
    Visuals    = Window:AddTab('Visuals'),
    Archives   = Window:AddTab('Archives'),
    Stairwell  = Window:AddTab('Stairwell'),
    Settings   = Window:AddTab('Settings'),
}

local Toggles = Library.Toggles
local Options  = Library.Options

-- ═════════════════════════════════════════════════════════════════════════════
--  MOVEMENT
-- ═════════════════════════════════════════════════════════════════════════════
local MovLeft  = Tabs.Movement:AddLeftGroupbox('Character')
local MovRight = Tabs.Movement:AddRightGroupbox('Movement')

MovLeft:AddSlider('SpeedAmount', {
    Text = 'Speed Boost', Default = 0, Min = 0, Max = 150, Rounding = 0, Compact = true,
})
MovLeft:AddToggle('SpeedBoost', { Text = 'Enable Speed Boost', Default = false })
MovLeft:AddDivider()
MovLeft:AddToggle('InfiniteJumps',    { Text = 'Infinite Jumps',    Default = false })
MovLeft:AddToggle('EnableJump',       { Text = 'Enable Jumping',    Default = false })
MovLeft:AddToggle('EnableSlide',      { Text = 'Enable Sliding',    Default = false })
MovLeft:AddDivider()
MovLeft:AddToggle('RemoveClosetDelay',   { Text = 'Remove Closet Delay',  Default = false })
MovLeft:AddToggle('RemoveAcceleration',  { Text = 'Remove Acceleration',  Default = false })
MovLeft:AddDivider()
MovLeft:AddToggle('LowGravity',   { Text = 'Low Gravity',   Default = false })
MovLeft:AddSlider('GravityAmount', {
    Text = 'Gravity', Default = 25, Min = 1, Max = 196, Rounding = 0, Compact = true,
})

MovRight:AddToggle('FlyToggle', { Text = 'Fly', Default = false })
Toggles.FlyToggle:AddKeyPicker('FlyKeybind', {
    Default = 'F', Mode = 'Toggle', Text = 'Fly', SyncToggleState = true,
})
MovRight:AddSlider('FlySpeed', {
    Text = 'Fly Speed', Default = 25, Min = 5, Max = 150, Rounding = 0, Compact = true,
})
MovRight:AddDivider()
MovRight:AddToggle('NoclipToggle', { Text = 'Noclip', Default = false })
Toggles.NoclipToggle:AddKeyPicker('NoclipKeybind', {
    Default = 'N', Mode = 'Toggle', Text = 'Noclip', SyncToggleState = true,
})
MovRight:AddDivider()
MovRight:AddToggle('TpNextDoorToggle', { Text = 'Auto TP Next Door', Default = false })
MovRight:AddToggle('SpectateEntityToggle', {
    Text = 'Spectate Entity',
    Default = false,
    Tooltip = 'Spectates the nearest entity while auto hiding.',
})

-- ═════════════════════════════════════════════════════════════════════════════
--  SELF
-- ═════════════════════════════════════════════════════════════════════════════
local SelfLeft  = Tabs.Self:AddLeftGroupbox('Interaction')
local SelfRight = Tabs.Self:AddRightGroupbox('Player')

SelfLeft:AddToggle('DoorReach',     { Text = 'Door Reach',           Default = false, Tooltip = 'Open doors from further away.' })
SelfLeft:AddToggle('InstantPrompts',{ Text = 'Instant Prompts',      Default = false, Tooltip = 'No hold time on any prompt.'    })
SelfLeft:AddToggle('PromptClip',    { Text = 'Prompt Clip',          Default = false, Tooltip = 'Interact through walls.'        })
SelfLeft:AddDivider()
SelfLeft:AddSlider('PromptReach', {
    Text = 'Prompt Reach Multiplier', Default = 1, Min = 1, Max = 5, Rounding = 1, Compact = true,
})
SelfLeft:AddDivider()
SelfLeft:AddToggle('EntityNotify',  { Text = 'Entity Notifications', Default = true,  Tooltip = 'Notify when an entity spawns.'  })
SelfLeft:AddToggle('AntiScreech',   { Text = 'Anti Screech',         Default = false, Tooltip = 'Prevents Screech from hurting you.' })
SelfLeft:AddToggle('AntiShade',     { Text = 'Anti Shade',           Default = false, Tooltip = 'Prevents Shade from hurting you.' })

SelfRight:AddToggle('DisableIdleKick', { Text = 'Disable Idle Kick', Default = false })
SelfRight:AddToggle('RemoveFog',       { Text = 'Remove Fog',        Default = false })
SelfRight:AddToggle('FullBright',      { Text = 'Full Bright',       Default = false, Tooltip = 'Removes all darkness from the game.' })
SelfRight:AddDivider()
SelfRight:AddToggle('CollectCurrency', { Text = 'Auto Collect Gold',  Default = false, Tooltip = 'Automatically picks up gold/coins.' })
SelfRight:AddSlider('CollectCurrencyDist', {
    Text = 'Gold Collect Distance', Default = 15, Min = 5, Max = 60, Rounding = 0, Compact = true,
})

-- ═════════════════════════════════════════════════════════════════════════════
--  AUTO
-- ═════════════════════════════════════════════════════════════════════════════
local AutoLeft  = Tabs.Auto:AddLeftGroupbox('Entity')
local AutoRight = Tabs.Auto:AddRightGroupbox('Puzzles / Items')

AutoLeft:AddToggle('AutoCloset', { Text = 'Auto Closet', Default = false, Tooltip = 'Hides in nearby closet when entity is close.' })
Toggles.AutoCloset:AddKeyPicker('AutoClosetKeybind', {
    Default = 'Q', Mode = 'Toggle', Text = 'Auto Closet', SyncToggleState = true,
})
AutoLeft:AddDropdown('AutoClosetIgnoreList', {
    Values   = { 'Rush','Ambush','Bash','Blitz','DronesStampede','Scribbles','A-60','A-120','RNIUSHCG==','AR0xMBUSH' },
    Default  = 1,
    Multi    = true,
    AllowNull = true,
    Text     = 'Entity Ignore List',
})
AutoLeft:AddDivider()
AutoLeft:AddToggle('AutoInteract', { Text = 'Auto Interact', Default = false })
Toggles.AutoInteract:AddKeyPicker('AutoInteractKeybind', {
    Default = 'R', Mode = 'Toggle', Text = 'Auto Interact', SyncToggleState = true,
})

AutoRight:AddToggle('AutoBreakerBox', { Text = 'Auto Breaker Box',    Default = false })
AutoRight:AddToggle('AutoPadlock',    { Text = 'Auto Unlock Padlock', Default = false })
AutoRight:AddSlider('PadlockDist', {
    Text = 'Padlock Distance', Default = 10, Min = 1, Max = 50, Rounding = 0, Compact = true,
})
AutoRight:AddDivider()
AutoRight:AddToggle('AutoCollect', { Text = 'Auto Collect Items', Default = false })
AutoRight:AddSlider('AutoCollectDist', {
    Text = 'Collect Distance', Default = 20, Min = 5, Max = 100, Rounding = 0, Compact = true,
})
AutoRight:AddDivider()
AutoRight:AddToggle('AutoLibrary',       { Text = 'Auto Library (Room 50)',     Default = false, Tooltip = 'Automatically collects books and hint paper.' })
AutoRight:AddToggle('AutoSolveAnchors',  { Text = 'Auto Solve Anchors (Mines)', Default = false, Tooltip = 'Automatically solves mine anchors.' })
AutoRight:AddDivider()
AutoRight:AddToggle('SkipSeekHotel',     { Text = 'Skip Seek (Hotel)',           Default = false, Tooltip = 'Skips Seek sections in Hotel.' })
AutoRight:AddToggle('AutoBreakerRoom',   { Text = 'Auto Breaker Room 100',       Default = false, Tooltip = 'Automates the room 100 breaker sequence.' })
AutoRight:AddDivider()
AutoRight:AddToggle('AutoHotel',         { Text = 'Auto Hotel',                  Default = false, Tooltip = 'Auto-progresses through the hotel floor.' })
AutoRight:AddToggle('AutoHotelIgnoreEntities', { Text = 'Ignore Entities (Auto Hotel)', Default = false })
AutoRight:AddToggle('AutoLibraryGuess',  { Text = 'Guess Library Code',          Default = false, Tooltip = 'Attempts to guess the library padlock code.' })

-- ═════════════════════════════════════════════════════════════════════════════
--  BYPASS
-- ═════════════════════════════════════════════════════════════════════════════
local BypassLeft  = Tabs.Bypass:AddLeftGroupbox('Entity Bypass')
local BypassRight = Tabs.Bypass:AddRightGroupbox('World Bypass')

BypassLeft:AddToggle('BypassEyes',    { Text = 'Bypass Eyes',         Default = false })
BypassLeft:AddToggle('BypassLookman', { Text = 'Bypass Lookman',      Default = false })
BypassLeft:AddToggle('BypassGiggle',  { Text = 'Bypass Giggle',       Default = false })
BypassLeft:AddToggle('BypassDupe',    { Text = 'Bypass Dupe',         Default = false })
BypassLeft:AddToggle('BypassSnare',   { Text = 'Bypass Snare',        Default = false })
BypassLeft:AddToggle('BypassBanana',  { Text = 'Bypass Banana Peel',  Default = false })
BypassLeft:AddToggle('BypassJeff',    { Text = 'Bypass Jeff',         Default = false })
BypassLeft:AddDivider()
BypassLeft:AddToggle('BypassScreech', { Text = 'Bypass Screech',      Default = false })
BypassLeft:AddToggle('BypassShade',   { Text = 'Bypass Shade',        Default = false })
BypassLeft:AddToggle('BypassMonument',{ Text = 'Bypass Monument',     Default = false, Tooltip = 'Look at Monument freely without damage.' })
BypassLeft:AddToggle('BypassGroundskeeper', { Text = 'Bypass Groundskeeper', Default = false })

BypassRight:AddToggle('BypassKillbricks',  { Text = 'Bypass Killbricks',      Default = false })
BypassRight:AddToggle('BypassSeekingWall', { Text = 'Bypass Seeking Wall',    Default = false })
BypassRight:AddToggle('BypassSeekObs',     { Text = 'Bypass Seek Obstacles',  Default = false })
BypassRight:AddToggle('BypassVacuum',      { Text = 'Bypass Vacuum Doors',    Default = false })
BypassRight:AddToggle('BypassGloombat',    { Text = 'Bypass Gloombat Eggs',   Default = false })
BypassRight:AddDivider()
BypassRight:AddToggle('BypassWater',       { Text = 'Bypass Electric Water',  Default = false, Tooltip = 'Archives water floor bypass.' })
BypassRight:AddToggle('BypassAlma',        { Text = 'Bypass Alma',            Default = false, Tooltip = 'Destroys Alma on spawn.' })
BypassRight:AddToggle('BypassDrones',      { Text = 'Bypass Drones',          Default = false, Tooltip = 'Prevents Drones from triggering.' })
BypassRight:AddToggle('AntiScribbles',     { Text = 'Anti Scribbles',         Default = false, Tooltip = 'Removes Scribbles exploit-warning part.' })
BypassRight:AddToggle('AntiRansom',        { Text = 'Anti Ransom',            Default = false, Tooltip = 'Destroys Ransom on spawn.' })
BypassRight:AddToggle('AntiClosetTrash',   { Text = 'Anti Closet Trash',      Default = false, Tooltip = 'Prevents binder/shelf clutter from spawning.' })

-- ═════════════════════════════════════════════════════════════════════════════
--  VISUALS
-- ═════════════════════════════════════════════════════════════════════════════
local VisLeft  = Tabs.Visuals:AddLeftGroupbox('ESP')
local VisRight = Tabs.Visuals:AddRightGroupbox('Colors')

VisLeft:AddToggle('EntityESP', { Text = 'Entity ESP',      Default = false })
VisLeft:AddToggle('ItemESP',   { Text = 'Item ESP',        Default = false })
VisLeft:AddToggle('DoorESP',   { Text = 'Door ESP',        Default = false })
VisLeft:AddToggle('ChestESP',  { Text = 'Chest ESP',       Default = false })
VisLeft:AddToggle('ClosetESP', { Text = 'Hiding Spot ESP', Default = false })
VisLeft:AddToggle('CurrencyESP',{ Text = 'Gold/Coin ESP',  Default = false })
VisLeft:AddDivider()
VisLeft:AddToggle('CreakAggressionMeter', { Text = 'Creak Aggression Meter', Default = false,
    Tooltip = 'Draws aggression % above Creak using Drawing API.' })

VisRight:AddLabel('Entity Color'):AddColorPicker('EntityESPColor', {
    Default = Color3.fromRGB(255, 50, 50),  Title = 'Entity ESP Color'
})
VisRight:AddLabel('Item Color'):AddColorPicker('ItemESPColor', {
    Default = Color3.fromRGB(50, 255, 100), Title = 'Item ESP Color'
})
VisRight:AddLabel('Door Color'):AddColorPicker('DoorESPColor', {
    Default = Color3.fromRGB(100, 150, 255),Title = 'Door ESP Color'
})
VisRight:AddLabel('Chest Color'):AddColorPicker('ChestESPColor', {
    Default = Color3.fromRGB(255, 215, 0),  Title = 'Chest ESP Color'
})
VisRight:AddLabel('Closet Color'):AddColorPicker('ClosetESPColor', {
    Default = Color3.fromRGB(0, 200, 255),  Title = 'Closet ESP Color'
})
VisRight:AddLabel('Gold Color'):AddColorPicker('CurrencyESPColor', {
    Default = Color3.fromRGB(255, 230, 50), Title = 'Gold ESP Color'
})

-- ═════════════════════════════════════════════════════════════════════════════
--  ARCHIVES
-- ═════════════════════════════════════════════════════════════════════════════
local ArcLeft  = Tabs.Archives:AddLeftGroupbox('Bypasses')
local ArcRight = Tabs.Archives:AddRightGroupbox('Exploits / Anti')

ArcLeft:AddToggle('BypassWaterAlt',       { Text = 'Bypass Electric Water',     Default = false })
ArcLeft:AddToggle('BypassAlmaAlt',        { Text = 'Bypass Alma',               Default = false })
ArcLeft:AddToggle('BypassDronesAlt',      { Text = 'Bypass Drones',             Default = false })
ArcLeft:AddToggle('AntiScribblesAlt',     { Text = 'Bypass Scribbles',          Default = false })

ArcRight:AddToggle('AntiRansomAlt',       { Text = 'Anti Ransom',               Default = false })
ArcRight:AddToggle('AntiClosetTrashAlt',  { Text = 'Anti Closet Trash',         Default = false })
ArcRight:AddToggle('ForgetMeNotSolver',   { Text = 'Forget Me Not Skipper',     Default = false,
    Tooltip = 'Automatically skips Forget Me Not vine doors.' })
ArcRight:AddToggle('TimeShower',          { Text = 'Show Archives Clock',       Default = false,
    Tooltip = 'Displays the Archives clock time on screen.' })
ArcRight:AddToggle('BypassDronesStampede',{ Text = 'Anti Stampede / Stop Time', Default = false,
    Tooltip = 'Fires the clock remote to stall Drones Stampede.' })
ArcRight:AddToggle('HonchoBoxESP',        { Text = 'Honcho Correct Box ESP',    Default = false,
    Tooltip = 'Highlights correct boxes and auto-deposits them.' })

-- ═════════════════════════════════════════════════════════════════════════════
--  STAIRWELL
-- ═════════════════════════════════════════════════════════════════════════════
local StairLeft  = Tabs.Stairwell:AddLeftGroupbox('Stairwell Exploits')
local StairRight = Tabs.Stairwell:AddRightGroupbox('Misc')

StairLeft:AddToggle('BypassNoiseTv',      { Text = 'Noise TV Breaker',           Default = false,
    Tooltip = 'Breaks the Noise TV while holding it.' })
StairLeft:AddToggle('AntiNoise',          { Text = 'Anti Noise (No Sound)',       Default = false,
    Tooltip = 'Disables movement sounds.' })
StairLeft:AddToggle('DroppedItemCount',   { Text = 'Show Item Count',             Default = false,
    Tooltip = 'Shows number of dropped items in watermark.' })
StairLeft:AddToggle('KillAllWithCart',    { Text = 'Kill All (Needs ≥1 Cart)',    Default = false })
StairLeft:AddToggle('FlingCreak',         { Text = 'Bug Out Creak (Needs ≥5 Cart)', Default = false })

-- ═════════════════════════════════════════════════════════════════════════════
--  SETTINGS
-- ═════════════════════════════════════════════════════════════════════════════
local SettingsLeft  = Tabs.Settings:AddLeftGroupbox('Actions')
local SettingsRight = Tabs.Settings:AddRightGroupbox('Debug')

SettingsLeft:AddButton({ Text = 'Play Again',      DoubleClick = true, Func = function() FireRemote('PlayAgain') end })
SettingsLeft:AddButton({ Text = 'Return to Lobby', DoubleClick = true, Func = function() FireRemote('Lobby')     end })
SettingsLeft:AddButton({ Text = 'Revive',          DoubleClick = true, Func = function() FireRemote('Revive')    end })
SettingsLeft:AddButton({ Text = 'Reset Character', DoubleClick = true,
    Func = function()
        if Humanoid then Humanoid.Health = 0 end
    end
})
SettingsLeft:AddButton({ Text = 'Exit Closet',
    Func = function() FireRemote('CamLock') end
})
SettingsLeft:AddButton({ Text = 'Fix Ladder Softlock',
    Func = function() LocalPlayer:SetAttribute('Climbing', false) end
})
SettingsLeft:AddDivider()
SettingsLeft:AddButton({ Text = 'TP Next Door',
    Func = function()
        local Door = GetNextClosedDoor()
        if Door and Character then
            Character:PivotTo(Door:GetPivot() * CFrame.new(0, -1, 0))
        end
    end
})
SettingsLeft:AddButton({ Text = 'Void TP',
    Func = function()
        if not Character then return end
        local P = Character:GetPivot()
        for _ = 1, 20 do Character:PivotTo(CFrame.new(P.Position.X, -120, P.Position.Z)) end
    end
})
SettingsLeft:AddDivider()
SettingsLeft:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', {
    Default = 'End', NoUI = true, Text = 'Toggle menu'
})
Library.ToggleKeybind = Options.MenuKeybind
SettingsLeft:AddButton('Unload', function() Library:Unload() end)

SettingsRight:AddButton({ Text = 'Get Current Floor',
    Func = function()
        Library:Notify({ Title = 'Current Floor: ' .. Floor, Time = 4 })
    end
})
SettingsRight:AddButton({ Text = 'Get Current Room',
    Func = function()
        local Room = LocalPlayer:GetAttribute('CurrentRoom')
        Library:Notify({ Title = 'Current Room: ' .. tostring(Room), Time = 4 })
    end
})
SettingsRight:AddButton({ Text = 'Count Entities',
    Func = function()
        Library:Notify({ Title = tostring(#Objects.Entities) .. ' entities tracked', Time = 4 })
    end
})

-- ═════════════════════════════════════════════════════════════════════════════
--  CALLBACKS
-- ═════════════════════════════════════════════════════════════════════════════

-- ── Movement ──────────────────────────────────────────────────────────────────
Toggles.SpeedBoost:OnChanged(function(Value)
    if Humanoid then
        Humanoid.WalkSpeed = Value and (16 + Options.SpeedAmount.Value) or 16
    end
end)
Options.SpeedAmount:OnChanged(function(Value)
    if Toggles.SpeedBoost.Value and Humanoid then
        Humanoid.WalkSpeed = 16 + Value
    end
end)

Toggles.EnableJump:OnChanged(function(Value)
    if Character then Character:SetAttribute('CanJump', Value) end
end)
Toggles.EnableSlide:OnChanged(function(Value)
    if Character then Character:SetAttribute('CanSlide', Value) end
end)

Toggles.FlyToggle:OnChanged(function(Value)
    if not Value then
        if Character then
            for _, Part in Character:GetDescendants() do
                if Part:IsA('BodyVelocity') and Part.Name == '_FlyBV' then Part:Destroy() end
            end
        end
        if Humanoid then Humanoid.PlatformStand = false end
    end
end)

Toggles.NoclipToggle:OnChanged(function() end)

Toggles.LowGravity:OnChanged(function(Value)
    workspace.Gravity = Value and (Options.GravityAmount and Options.GravityAmount.Value or 25) or 196
end)
Options.GravityAmount:OnChanged(function(Value)
    if Toggles.LowGravity and Toggles.LowGravity.Value then
        workspace.Gravity = Value
    end
end)

Toggles.DisableIdleKick:OnChanged(function(Value)
    if getconnections then
        for _, Conn in getconnections(LocalPlayer.Idled) do
            if Value then pcall(Conn.Disable, Conn) else pcall(Conn.Enable, Conn) end
        end
    end
end)

Toggles.RemoveFog:OnChanged(function(Value)
    Lighting.FogEnd = Value and 1e9 or 1000
    for _, Obj in Lighting:GetChildren() do
        if Obj:IsA('Atmosphere') then
            if not Obj:GetAttribute('Density_Old') then Obj:SetAttribute('Density_Old', Obj.Density) end
            Obj.Density = Value and 0 or Obj:GetAttribute('Density_Old')
        end
    end
end)

Toggles.FullBright:OnChanged(function(Value)
    Lighting.Ambient                    = Value and Color3.new(1,1,1) or Color3.fromRGB(0, 0, 0)
    Lighting.OutdoorAmbient             = Value and Color3.new(1,1,1) or Color3.fromRGB(70, 70, 70)
    Lighting.Brightness                 = Value and 2 or 1
    for _, Obj in Lighting:GetChildren() do
        if Obj:IsA('BloomEffect') or Obj:IsA('ColorCorrectionEffect') then
            Obj.Enabled = not Value
        end
    end
end)

Toggles.DoorReach:OnChanged(function(Value)
    for _, Door in Objects.Doors do
        for _, Prompt in Door:GetDescendants() do
            if Prompt:IsA('ProximityPrompt') then
                Prompt.MaxActivationDistance = Value and 32 or 10
            end
        end
    end
end)

Toggles.InstantPrompts:OnChanged(function(Value)
    for _, Prompt in Objects.Prompts do
        Prompt.HoldDuration = Value and 0 or (Prompt:GetAttribute('HoldDuration_Old') or 1)
    end
end)

Toggles.PromptClip:OnChanged(function(Value)
    for _, Prompt in Objects.Prompts do
        Prompt.RequiresLineOfSight = not Value
    end
end)

Options.PromptReach:OnChanged(function(Value)
    for _, Prompt in Objects.Prompts do
        local Old = Prompt:GetAttribute('MaxActivationDistance_Old')
        if Old then Prompt.MaxActivationDistance = Old * Value end
    end
end)

-- ── Bypass: Entity ────────────────────────────────────────────────────────────
local EyesConn, LookmanConn
local function StartMotorSpoof(ConnRef, ToggleKey)
    if ConnRef then ConnRef:Disconnect() end
    if not Toggles[ToggleKey] or not Toggles[ToggleKey].Value then return nil end
    if not RemotesFolder then return nil end
    local Remote = RemotesFolder:FindFirstChild('MotorReplication')
    if not Remote then return nil end
    return RunService.Heartbeat:Connect(function()
        if not Toggles[ToggleKey] or not Toggles[ToggleKey].Value then return end
        pcall(function() Remote:FireServer(-650) end)
    end)
end

Toggles.BypassEyes:OnChanged(function()
    EyesConn = StartMotorSpoof(EyesConn, 'BypassEyes')
end)
Toggles.BypassLookman:OnChanged(function()
    LookmanConn = StartMotorSpoof(LookmanConn, 'BypassLookman')
end)

Toggles.BypassGiggle:OnChanged(function(Value)
    for _, E in Objects.Entities do
        if E.Name == 'GiggleCeiling' then
            local Hitbox = E:FindFirstChild('Hitbox')
            if Hitbox then Hitbox.CanTouch = not Value end
        end
    end
end)

Toggles.BypassDupe:OnChanged(function(Value)
    for _, E in Objects.Entities do
        if E.Name == 'DoorFake' or E.Name == 'FakeDoor' then
            local Hidden = E:FindFirstChild('Hidden')
            if Hidden then Hidden.CanTouch = not Value end
        end
    end
end)

Toggles.BypassSnare:OnChanged(function(Value)
    for _, E in Objects.Entities do
        if E.Name == 'Snare' then
            for _, Part in E:GetDescendants() do
                if Part:IsA('BasePart') then Part.CanTouch = not Value end
            end
        end
    end
end)

Toggles.BypassBanana:OnChanged(function(Value)
    for _, E in Objects.Entities do
        if E.Name == 'BananaPeel' then
            local Part = E:IsA('BasePart') and E or E:FindFirstChildOfClass('BasePart')
            if Part then Part.CanTouch = not Value end
        end
    end
end)

Toggles.BypassJeff:OnChanged(function(Value)
    for _, E in Objects.Entities do
        if E.Name == 'JeffTheKiller' then
            for _, Part in E:GetDescendants() do
                if Part:IsA('BasePart') then
                    Part.CanCollide = not Value
                    Part.CanTouch   = not Value
                end
            end
        end
    end
end)

Toggles.BypassMonument:OnChanged(function(Value)
    for _, E in Objects.Entities do
        if E.Name == 'MonumentEntity' then
            for _, Part in E:GetDescendants() do
                if Part:IsA('BasePart') then Part.CanTouch = not Value end
            end
        end
    end
end)

Toggles.BypassGroundskeeper:OnChanged(function(Value)
    for _, E in Objects.Entities do
        if E.Name == 'Groundskeeper' then
            for _, Part in E:GetDescendants() do
                if Part:IsA('BasePart') then Part.CanTouch = not Value end
            end
        end
    end
end)

-- ── Bypass: World ─────────────────────────────────────────────────────────────
Toggles.BypassKillbricks:OnChanged(function(Value)
    for _, Obj in Objects.Obstructions do
        if Obj.Name == 'Lava' then
            local Part = Obj:IsA('BasePart') and Obj or Obj:FindFirstChildOfClass('BasePart')
            if Part then Part.CanTouch = not Value end
        end
    end
end)

Toggles.BypassSeekingWall:OnChanged(function(Value)
    for _, Obj in Objects.Obstructions do
        if Obj.Name == 'ScaryWall' then
            for _, Part in Obj:GetDescendants() do
                if Part:IsA('BasePart') then
                    Part.CanTouch   = not Value
                    Part.CanCollide = not Value
                end
            end
        end
    end
end)

Toggles.BypassSeekObs:OnChanged(function(Value)
    for _, Obj in Objects.SeekObs do
        Obj.CanTouch = not Value
        if Obj.Name == 'SeekFloodline' then Obj.CanCollide = Value end
    end
    for _, Obj in Objects.SeekBridges do
        Obj.CanCollide = Value
    end
end)

Toggles.BypassVacuum:OnChanged(function(Value)
    for _, E in Objects.Entities do
        if E.Name == 'SideroomSpace' then
            local Col = E:FindFirstChild('Collision')
            if Col then Col.CanCollide = Value Col.CanTouch = not Value end
        end
    end
end)

Toggles.BypassGloombat:OnChanged(function(Value)
    for _, E in Objects.Entities do
        if E.Name:find('Gloombat') then
            for _, Part in E:GetDescendants() do
                if Part:IsA('BasePart') then Part.CanTouch = not Value end
            end
        end
    end
end)

-- ── Archives Bypasses ─────────────────────────────────────────────────────────
local WaterParts       = {}
local WaterBypassConn
local AlmaConn
local DroneConn
local DroneWalkedIntoParents = {}
local AntiScribblesConn
local AntiRansomConn
local AntiClosetTrashConn

local function DoBypassWater(Value)
    if WaterBypassConn then WaterBypassConn:Disconnect() WaterBypassConn = nil end
    if not Value then
        for _, P in pairs(WaterParts) do if P and P.Parent then P:Destroy() end end
        table.clear(WaterParts)
        return
    end
    local function ProcessWaterRoom(Room)
        if not tonumber(Room.Name) then return end
        task.wait(3)
        local Water = Room:FindFirstChild('Water')
        if not Water or WaterParts[Water] then return end
        local Part = Instance.new('Part')
        Part.Name           = 'WaterBypass'
        Part.Anchored       = true
        Part.CanCollide     = true
        Part.CanTouch       = false
        Part.CanQuery       = false
        Part.Transparency   = 0.4
        Part.Color          = Color3.fromRGB(0, 150, 255)
        Part.Material       = Enum.Material.ForceField
        local CF, Sz
        if Water:IsA('BasePart') then
            Sz = Water.Size CF = Water.CFrame
        elseif Water:IsA('Model') then
            CF, Sz = Water:GetBoundingBox()
        else
            Sz = Vector3.new(10, 1.5, 10) CF = Water:GetPivot()
        end
        Part.Size  = Sz + Vector3.new(0, 0.5, 0)
        Part.CFrame = CF * CFrame.new(0, 0.25, 0)
        if Part.Size.Y > 3 then Part:Destroy() return end
        Part.Parent = Room
        WaterParts[Water] = Part
    end
    if CurrentRooms then
        local Latest = LatestRoom and LatestRoom.Value or 0
        for Num = math.max(0, Latest - 4), Latest do
            local Room = CurrentRooms:FindFirstChild(tostring(Num))
            if Room then task.spawn(ProcessWaterRoom, Room) end
        end
        WaterBypassConn = CurrentRooms.ChildAdded:Connect(function(Room) task.spawn(ProcessWaterRoom, Room) end)
    end
end
Toggles.BypassWater:OnChanged(DoBypassWater)
Toggles.BypassWaterAlt:OnChanged(DoBypassWater)

local function DoBypassAlma(Value)
    if AlmaConn then AlmaConn:Disconnect() AlmaConn = nil end
    if Value then
        for _, Child in workspace:GetChildren() do
            if Child.Name == 'Alma' then Child:Destroy() end
        end
        AlmaConn = workspace.ChildAdded:Connect(function(Child)
            if Child.Name == 'Alma' then Child:Destroy() end
        end)
    end
end
Toggles.BypassAlma:OnChanged(DoBypassAlma)
Toggles.BypassAlmaAlt:OnChanged(DoBypassAlma)

local function DoBypassDrones(Value)
    local RS = ReplicatedStorage
    local function Process(Drones)
        local WI = Drones:FindFirstChild('WalkedInto') or Drones:WaitForChild('WalkedInto', 3)
        if WI and not DroneWalkedIntoParents[WI] then
            DroneWalkedIntoParents[WI] = Drones
            WI.Parent = RS
        end
    end
    if Value then
        for _, Child in workspace:GetChildren() do if Child.Name == 'Drones' then Process(Child) end end
        if DroneConn then DroneConn:Disconnect() end
        DroneConn = workspace.ChildAdded:Connect(function(Child)
            if Child.Name == 'Drones' then Process(Child) end
        end)
    else
        for WI, Parent in pairs(DroneWalkedIntoParents) do
            if WI and WI.Parent and Parent and Parent.Parent then WI.Parent = Parent end
        end
        table.clear(DroneWalkedIntoParents)
        if DroneConn then DroneConn:Disconnect() DroneConn = nil end
    end
end
Toggles.BypassDrones:OnChanged(DoBypassDrones)
Toggles.BypassDronesAlt:OnChanged(DoBypassDrones)

local function DoAntiScribbles(Value)
    if AntiScribblesConn then AntiScribblesConn:Disconnect() AntiScribblesConn = nil end
    if not Value then return end
    AntiScribblesConn = workspace.ChildAdded:Connect(function(Child)
        if Child.Name == 'Scribbles' then
            local W = Child:FindFirstChild('IfYoureExploitingDeleteThis')
            if W then W:Destroy() end
        end
    end)
end
Toggles.AntiScribbles:OnChanged(DoAntiScribbles)
Toggles.AntiScribblesAlt:OnChanged(DoAntiScribbles)

local function DoAntiRansom(Value)
    if AntiRansomConn then AntiRansomConn:Disconnect() AntiRansomConn = nil end
    if not Value then return end
    AntiRansomConn = workspace.ChildAdded:Connect(function(Child)
        if Child.Name == 'Ransom' then Child:Destroy() end
    end)
end
Toggles.AntiRansom:OnChanged(DoAntiRansom)
Toggles.AntiRansomAlt:OnChanged(DoAntiRansom)

local function DoAntiClosetTrash(Value)
    if AntiClosetTrashConn then AntiClosetTrashConn:Disconnect() AntiClosetTrashConn = nil end
    if not Value then return end
    AntiClosetTrashConn = workspace.ChildAdded:Connect(function(Child)
        local N = Child.Name
        if N:sub(1,6) == 'Binder' or N:sub(1,4) == 'Shoe' or N:sub(1,5) == 'Shelf' then
            Child:Destroy()
        end
    end)
end
Toggles.AntiClosetTrash:OnChanged(DoAntiClosetTrash)
Toggles.AntiClosetTrashAlt:OnChanged(DoAntiClosetTrash)

-- ── Auto Breaker Box ──────────────────────────────────────────────────────────
Toggles.AutoBreakerBox:OnChanged(function(Value)
    if not Value or not RemotesFolder then return end
    if CurrentRooms and CurrentRooms:FindFirstChild('ElevatorBreaker', true) then
        local Remote = RemotesFolder:FindFirstChild('EBF')
        if Remote then pcall(function() Remote:FireServer() end) end
    end
end)

-- ── Forget Me Not Solver ──────────────────────────────────────────────────────
local ForgetMeNotConn
local ForgetMeNotRunning = false
local ForgetMeNotProcessing = {}

Toggles.ForgetMeNotSolver:OnChanged(function(Value)
    if ForgetMeNotConn then ForgetMeNotConn:Disconnect() ForgetMeNotConn = nil end
    ForgetMeNotRunning = false
    table.clear(ForgetMeNotProcessing)
    if not Value then return end
    ForgetMeNotRunning = true

    local function GetChar() return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait() end

    local function FireLookAts(Room)
        for i = 1, 6 do
            local Obj = Room:FindFirstChild(tostring(i))
            if Obj then
                local LookAt = Obj:FindFirstChild('LookAt')
                if LookAt then pcall(function() LookAt:FireServer() end) end
            end
        end
    end

    local function GetNextRoom(Number)
        while ForgetMeNotRunning do
            for Num = Number + 1, Number + 5 do
                local Next = CurrentRooms and CurrentRooms:FindFirstChild(tostring(Num))
                if Next then return Next end
            end
            task.wait(0.1)
        end
    end

    local function VoidChar()
        local Char = GetChar()
        if not Char then return end
        local VCF = CFrame.new(0, -120, 0)
        local T = tick()
        while ForgetMeNotRunning and tick() - T < 2 do
            Char:PivotTo(VCF)
            task.wait(0.1)
        end
    end

    local function Run(Room)
        local RoomNum = tonumber(Room.Name)
        if not RoomNum or not ForgetMeNotRunning or ForgetMeNotProcessing[RoomNum] then return end
        if not Room:FindFirstChild('ForgetMeNotVineDoors', true) then return end
        ForgetMeNotProcessing[RoomNum] = true

        while ForgetMeNotRunning and Room.Parent do
            FireLookAts(Room)
            local NextRoom = GetNextRoom(RoomNum)
            if not NextRoom then task.wait(0.4) continue end
            local Door = NextRoom:FindFirstChild('Door')
            if not Door then
                local Char = GetChar()
                if Char then
                    local Target = NextRoom:FindFirstChildWhichIsA('BasePart') or NextRoom
                    if Target:IsA('BasePart') then
                        Char:PivotTo(Target.CFrame + Vector3.new(0, 3, 0))
                    else
                        Char:PivotTo(CFrame.new(NextRoom:GetPivot().Position + Vector3.new(0, 5, 0)))
                    end
                end
                break
            end
            if Door:GetAttribute('Opened') == true then VoidChar() break end
            local Hidden = Door:FindFirstChild('Hidden') or Door:WaitForChild('Hidden', 2)
            if not Hidden then task.wait(0.3) continue end
            while ForgetMeNotRunning and Room.Parent and NextRoom.Parent and Door.Parent
                and Door:GetAttribute('Opened') ~= true do
                local Char = GetChar()
                if Char then
                    if Hidden:IsA('BasePart') then Char:PivotTo(Hidden.CFrame)
                    elseif Hidden:IsA('Model') then Char:PivotTo(Hidden:GetPivot()) end
                end
                pcall(function() Door.ClientOpen:Fire() end)
                task.wait()
            end
            if ForgetMeNotRunning and Door.Parent and Door:GetAttribute('Opened') == true then VoidChar() end
            break
        end
        ForgetMeNotProcessing[RoomNum] = nil
    end

    local function Check()
        local Latest = LatestRoom and tonumber(LatestRoom.Value) or 0
        for Num = math.max(0, Latest - 3), Latest do
            local Room = CurrentRooms and CurrentRooms:FindFirstChild(tostring(Num))
            if Room and not ForgetMeNotProcessing[Num] then task.spawn(Run, Room) end
        end
    end

    if CurrentRooms then
        ForgetMeNotConn = CurrentRooms.ChildAdded:Connect(function(Room)
            if not tonumber(Room.Name) then return end
            task.spawn(function()
                task.wait(1)
                if ForgetMeNotRunning and Room.Parent then task.spawn(Run, Room) end
            end)
        end)
    end

    task.spawn(function()
        while ForgetMeNotRunning do Check() task.wait(1) end
    end)
    Check()
end)

-- ── Time Shower ───────────────────────────────────────────────────────────────
local TimeShowerLabel
local TimeShowerConn
local TimeShowerToken = 0
local TimeShowerSourceLabel

do
    local Sg = Instance.new('ScreenGui')
    Sg.Name = 'DoorsOPTimeShower'
    Sg.DisplayOrder = 100
    Sg.ResetOnSpawn = false
    Sg.Parent = CoreGui
    TimeShowerLabel = Instance.new('TextLabel')
    TimeShowerLabel.AnchorPoint = Vector2.new(0, 1)
    TimeShowerLabel.Position = UDim2.new(0, 12, 1, -12)
    TimeShowerLabel.Size = UDim2.new(0, 180, 0, 32)
    TimeShowerLabel.BackgroundTransparency = 1
    TimeShowerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TimeShowerLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    TimeShowerLabel.TextStrokeTransparency = 0.35
    TimeShowerLabel.Font = Enum.Font.GothamBold
    TimeShowerLabel.TextSize = 18
    TimeShowerLabel.TextXAlignment = Enum.TextXAlignment.Left
    TimeShowerLabel.Text = 'Time: --:--'
    TimeShowerLabel.Visible = false
    TimeShowerLabel.Parent = Sg
end

local function GetArchivesClockLabel(Room)
    local Assets = Room and Room:FindFirstChild('Assets', true)
    local Clock  = Assets and Assets:FindFirstChild('ArchivesClock', true)
    local Time   = Clock  and Clock:FindFirstChild('Time', true)
    local Label  = Time   and Time:FindFirstChild('TextLabel')
    return (Label and Label:IsA('TextLabel')) and Label or nil
end

local function ResolveClockLabel()
    if TimeShowerSourceLabel and TimeShowerSourceLabel.Parent and TimeShowerSourceLabel:IsDescendantOf(game) then
        return TimeShowerSourceLabel
    end
    if not CurrentRooms then return nil end
    local Rooms = {}
    for _, Room in CurrentRooms:GetChildren() do
        local N = tonumber(Room.Name)
        if N then table.insert(Rooms, { room = Room, num = N }) end
    end
    table.sort(Rooms, function(A, B) return A.num > B.num end)
    for I = 1, math.min(6, #Rooms) do
        local Label = GetArchivesClockLabel(Rooms[I].room)
        if Label then TimeShowerSourceLabel = Label return Label end
    end
    return nil
end

local function ResolveClockRemote()
    local Label = ResolveClockLabel()
    if not Label then return nil end
    local Clock = Label:FindFirstAncestor('ArchivesClock')
    if not Clock then return nil end
    local Remote = Clock:FindFirstChild('LookedAtRemote', true)
    return (Remote and Remote:IsA('RemoteEvent')) and Remote or nil
end

Toggles.TimeShower:OnChanged(function(Value)
    TimeShowerToken += 1
    if TimeShowerConn then TimeShowerConn:Disconnect() TimeShowerConn = nil end
    TimeShowerLabel.Visible = Value
    if not Value then return end
    local Token = TimeShowerToken
    TimeShowerConn = RunService.Heartbeat:Connect(function()
        if Token ~= TimeShowerToken then return end
        local L = ResolveClockLabel()
        TimeShowerLabel.Text = L and ('Time: ' .. L.Text) or 'Time: --:--'
    end)
end)

-- ── Bypass Drones Stampede ────────────────────────────────────────────────────
local BypassStampedeConn
Toggles.BypassDronesStampede:OnChanged(function(Value)
    if BypassStampedeConn then task.cancel(BypassStampedeConn) BypassStampedeConn = nil end
    if not Value then return end
    BypassStampedeConn = task.spawn(function()
        while Toggles.BypassDronesStampede.Value do
            local Remote = ResolveClockRemote()
            if Remote then Remote:FireServer() task.wait(0.5)
            else task.wait(0.25) end
        end
    end)
end)

-- ── Honcho Correct Box ESP ────────────────────────────────────────────────────
local HonchoESPObjects    = {}
local HonchoProcessedRooms = {}
local HonchoDepositCache  = {}
local HonchoCorrectBoxConn
local HonchoAutoDepositConn

local function ClearHonchoESP()
    if HonchoCorrectBoxConn then HonchoCorrectBoxConn:Disconnect() HonchoCorrectBoxConn = nil end
    if HonchoAutoDepositConn then HonchoAutoDepositConn:Disconnect() HonchoAutoDepositConn = nil end
    for _, Obj in pairs(HonchoESPObjects) do if Obj and Obj.Parent then RemoveESP(Obj) end end
    table.clear(HonchoESPObjects) table.clear(HonchoProcessedRooms) table.clear(HonchoDepositCache)
end

Toggles.HonchoBoxESP:OnChanged(function(Value)
    ClearHonchoESP()
    if not Value or not CurrentRooms then return end

    local function AddHonchoESP(Obj, Color)
        AddESP(Obj, Color, Color)
        table.insert(HonchoESPObjects, Obj)
        Obj.Destroying:Once(function()
            RemoveESP(Obj)
            local P = table.find(HonchoESPObjects, Obj) if P then table.remove(HonchoESPObjects, P) end
        end)
    end

    local function ProcessRoom(Room)
        if not tonumber(Room.Name) or not Room.Parent or HonchoProcessedRooms[Room] then return end
        HonchoProcessedRooms[Room] = true
        task.wait(3)
        if not Toggles.HonchoBoxESP.Value or not Room.Parent then HonchoProcessedRooms[Room] = nil return end
        local HonchoRoom = Room:FindFirstChild('ArchivesHonchoRoom', true)
        if not HonchoRoom then HonchoProcessedRooms[Room] = nil return end
        local BoxIDs = {}
        local RoomNum = tonumber(Room.Name)
        for _, Desc in Room:GetDescendants() do
            local N = Desc.Name
            if N == 'ArchivesPackageDeposit' or N:match('^ArchivesPackageDeposit') then
                local ID = Desc:GetAttribute('BoxID')
                if ID ~= nil then
                    local IDStr = tostring(ID)
                    BoxIDs[IDStr] = true
                    HonchoDepositCache[IDStr] = Desc
                    AddHonchoESP(Desc, Color3.fromRGB(0, 255, 100))
                    Desc.Destroying:Once(function()
                        if HonchoDepositCache[IDStr] == Desc then HonchoDepositCache[IDStr] = nil end
                    end)
                end
            end
        end
        if not next(BoxIDs) then HonchoProcessedRooms[Room] = nil return end
        for _, Child in HonchoRoom:GetDescendants() do
            if Child.Name == 'ArchivesStorageBox' then
                local ToolID = Child:GetAttribute('Tool_BoxID')
                if ToolID ~= nil and BoxIDs[tostring(ToolID)] then
                    if not Child:GetAttribute('ParentRoom') then Child:SetAttribute('ParentRoom', RoomNum) end
                    Child.Name = 'ArchivesStorageBoxCorrect'
                    AddHonchoESP(Child, Color3.fromRGB(255, 215, 0))
                end
            end
        end
    end

    for _, Room in CurrentRooms:GetChildren() do task.spawn(ProcessRoom, Room) end
    HonchoCorrectBoxConn = CurrentRooms.ChildAdded:Connect(function(Room) task.spawn(ProcessRoom, Room) end)

    local LastCheck = 0
    HonchoAutoDepositConn = RunService.Heartbeat:Connect(function()
        if not Toggles.HonchoBoxESP.Value then return end
        local Now = os.clock()
        if Now - LastCheck < 0.1 then return end
        LastCheck = Now
        if not Character or not RootPart then return end
        local BoxCandidates = {}
        for _, Obj in Character:GetChildren() do
            if (Obj:IsA('Tool') or Obj:IsA('Model')) and
                (Obj.Name == 'ArchivesStorageBox' or Obj.Name == 'ArchivesStorageBoxCorrect') then
                table.insert(BoxCandidates, Obj)
            end
        end
        if Drops then
            for _, Obj in Drops:GetChildren() do
                if Obj.Name == 'ArchivesStorageBox' or Obj.Name == 'ArchivesStorageBoxCorrect' then
                    table.insert(BoxCandidates, Obj)
                end
            end
        end
        for _, Box in BoxCandidates do
            if not (Box and Box.Parent) then continue end
            local BoxID = Box:GetAttribute('Tool_BoxID') or Box:GetAttribute('BoxID')
            if BoxID == nil then continue end
            local Deposit = HonchoDepositCache[tostring(BoxID)]
            if not Deposit or not Deposit.Parent then continue end
            if Box.Parent == Drops and not Box:GetAttribute('HonchoESP') then
                Box:SetAttribute('HonchoESP', true)
                AddHonchoESP(Box, Color3.fromRGB(255, 215, 0))
            end
            if Box.Parent == Character then
                local DP = Deposit:IsA('BasePart') and Deposit or Deposit:FindFirstChildWhichIsA('BasePart', true)
                if DP and (RootPart.Position - DP.Position).Magnitude <= 10 then
                    local Prompt = Deposit:FindFirstChildWhichIsA('ProximityPrompt', true)
                    if Prompt and fireproximityprompt then fireproximityprompt(Prompt) end
                end
            end
        end
    end)
end)

-- ── Creak Aggression Meter ────────────────────────────────────────────────────
local CreakMeters = {}

local function CleanupCreakMeter(Creak)
    local Data = CreakMeters[Creak]
    if not Data then return end
    CreakMeters[Creak] = nil
    if Data.Conn then Data.Conn:Disconnect() end
    for _, D in Data.Drawings do pcall(function() D:Remove() end) end
end

local function GetCreakAggression(Creak)
    local Animator = Creak:FindFirstChildOfClass('Animator')
        or (Creak:FindFirstChild('AnimationController')
            and Creak.AnimationController:FindFirstChildOfClass('Animator'))
    if not Animator then return nil end
    for _, Track in Animator:GetPlayingAnimationTracks() do
        if Track.Name == 'CreakGraph' or (Track.Animation and Track.Animation.Name == 'CreakGraph') then
            local OK, Val = pcall(Track.GetParameter, Track, 'Aggression')
            if OK and type(Val) == 'number' then return math.clamp(Val, 0, 1) end
        end
    end
    return nil
end

local function AddCreakMeter(Creak)
    if not Toggles.CreakAggressionMeter or not Toggles.CreakAggressionMeter.Value then return end
    if Creak.Name ~= 'Creak' or CreakMeters[Creak] then return end
    local Head = Creak:FindFirstChild('Head')
    if not Head or not Head:IsA('BasePart') then return end

    local Drawings = {}
    local function D(T) local d = Drawing.new(T) table.insert(Drawings, d) return d end

    local Title = D('Text')
    Title.Text  = 'Aggression --%'
    Title.Size  = 16
    Title.Font  = Drawing.Fonts.Plex
    Title.Color = Color3.fromRGB(255, 255, 255)
    Title.Center = true
    Title.Outline = true
    Title.Visible = false

    local BG = D('Square')
    BG.Size    = Vector2.new(112, 6)
    BG.Filled  = true
    BG.Color   = Color3.fromRGB(50, 50, 55)
    BG.Visible = false

    local Fill = D('Square')
    Fill.Size    = Vector2.new(0, 6)
    Fill.Filled  = true
    Fill.Visible = false

    local Data = { Drawings = Drawings }

    Data.Conn = RunService.RenderStepped:Connect(function()
        if not Toggles.CreakAggressionMeter or not Toggles.CreakAggressionMeter.Value
            or not Creak.Parent or not Head.Parent then
            CleanupCreakMeter(Creak)
            return
        end
        local ScreenPos, OnScreen = Camera:WorldToViewportPoint(Head.Position + Vector3.new(0, 1.85, 0))
        if not OnScreen or ScreenPos.Z <= 0 then
            Title.Visible = false BG.Visible = false Fill.Visible = false
            return
        end
        local SP = Vector2.new(ScreenPos.X, ScreenPos.Y)
        Title.Position = SP - Vector2.new(0, 28)
        BG.Position    = SP - Vector2.new(56, 6)
        Fill.Position  = BG.Position

        local Agg = GetCreakAggression(Creak)
        if not Agg then
            Title.Text  = 'Aggression --%'
            Fill.Size   = Vector2.new(0, 6)
            Title.Color = Color3.fromRGB(180, 180, 180)
        else
            local Pct = math.floor(Agg * 100 + 0.5)
            Title.Text  = 'Aggression ' .. Pct .. '%'
            Fill.Size   = Vector2.new(math.floor(112 * Agg), 6)
            -- color ramps green → yellow → red
            Fill.Color  = Color3.fromRGB(math.floor(255 * Agg), math.floor(255 * (1 - Agg)), 0)
            Title.Color = Fill.Color
        end
        Title.Visible = true BG.Visible = true Fill.Visible = true
    end)

    CreakMeters[Creak] = Data
end

Toggles.CreakAggressionMeter:OnChanged(function(Value)
    if not Value then
        for Creak in pairs(CreakMeters) do CleanupCreakMeter(Creak) end
    else
        for _, E in Objects.Entities do
            if E.Name == 'Creak' then AddCreakMeter(E) end
        end
    end
end)

-- hook into entity registration so future Creaks get meters too
local OrigRegister = RegisterEntity
RegisterEntity = function(Obj)
    OrigRegister(Obj)
    if Obj.Name == 'Creak' and Toggles.CreakAggressionMeter and Toggles.CreakAggressionMeter.Value then
        task.defer(AddCreakMeter, Obj)
    end
end

-- ═════════════════════════════════════════════════════════════════════════════
--  RUNTIME LOOPS
-- ═════════════════════════════════════════════════════════════════════════════

-- Fly
local FlyBV
RunService.RenderStepped:Connect(function()
    if not Toggles.FlyToggle or not Toggles.FlyToggle.Value then
        if FlyBV and FlyBV.Parent then FlyBV:Destroy() FlyBV = nil end
        return
    end
    if not RootPart or not Humanoid then return end
    if not FlyBV or not FlyBV.Parent then
        FlyBV = Instance.new('BodyVelocity')
        FlyBV.Name     = '_FlyBV'
        FlyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        FlyBV.Velocity = Vector3.zero
        FlyBV.Parent   = RootPart
        Humanoid.PlatformStand = true
    end
    local Speed   = Options.FlySpeed and Options.FlySpeed.Value or 25
    local CamCF   = Camera.CFrame
    local MoveDir = Humanoid.MoveDirection
    local Horiz   = Vector3.zero
    if MoveDir.Magnitude > 0 then
        local Flat  = Vector3.new(CamCF.LookVector.X, 0, CamCF.LookVector.Z).Unit
        local Frame = CFrame.new(Vector3.zero, Flat)
        Horiz = (Frame * CFrame.new(Frame:VectorToObjectSpace(MoveDir))).Position.Unit * Speed
    end
    local Vert = 0
    if UserInputService:IsKeyDown(Enum.KeyCode.Space)      then Vert =  Speed
    elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then Vert = -Speed end
    FlyBV.Velocity = Vector3.new(Horiz.X, Vert, Horiz.Z)
end)

-- Noclip
RunService.Stepped:Connect(function()
    if not Toggles.NoclipToggle or not Toggles.NoclipToggle.Value then return end
    if not Character then return end
    for _, Part in Character:GetDescendants() do
        if Part:IsA('BasePart') and Part.CanCollide then Part.CanCollide = false end
    end
end)

-- Remove acceleration
RunService.Stepped:Connect(function()
    if not Toggles.RemoveAcceleration or not Toggles.RemoveAcceleration.Value then return end
    if not RootPart or not Humanoid then return end
    if Humanoid.MoveDirection == Vector3.zero then
        local V = RootPart.AssemblyLinearVelocity
        RootPart.AssemblyLinearVelocity = Vector3.new(0, V.Y, 0)
    end
end)

-- Infinite jumps
UserInputService.JumpRequest:Connect(function()
    if Toggles.InfiniteJumps and Toggles.InfiniteJumps.Value and Humanoid then
        Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- Idle kick bypass fallback
LocalPlayer.Idled:Connect(function()
    if Toggles.DisableIdleKick and Toggles.DisableIdleKick.Value then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- Auto Closet loop
task.spawn(function()
    while true do
        task.wait(0.1)
        if not (Toggles.AutoCloset and Toggles.AutoCloset.Value) then continue end
        if not GetNearestThreat() then continue end
        local Spot = GetNearestHidingSpot()
        if not Spot then continue end
        local Prompt = Spot:FindFirstChild('HidePrompt', true) or Spot:FindFirstChild('HidingPrompt', true)
        if Prompt and fireproximityprompt then fireproximityprompt(Prompt) end
    end
end)

-- Spectate Entity (while auto-hiding)
task.spawn(function()
    while true do
        task.wait(0.2)
        if not (Toggles.SpectateEntityToggle and Toggles.SpectateEntityToggle.Value) then continue end
        local Threat = GetNearestThreat()
        if not Threat then continue end
        local Part = Threat.PrimaryPart or Threat:FindFirstChildOfClass('BasePart')
        if not Part then continue end
        Camera.CameraType = Enum.CameraType.Scriptable
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, Part.Position)
    end
end)

-- Auto Interact
task.spawn(function()
    while true do
        task.wait(0.15)
        if not (Toggles.AutoInteract and Toggles.AutoInteract.Value) then continue end
        if not RootPart then continue end
        for _, Prompt in Objects.Prompts do
            if not Prompt or not Prompt.Parent or not Prompt.Enabled then continue end
            local Part = Prompt.Parent
            if not Part or not Part:IsA('BasePart') then continue end
            if (RootPart.Position - Part.Position).Magnitude <= Prompt.MaxActivationDistance then
                if fireproximityprompt then fireproximityprompt(Prompt) end
            end
        end
    end
end)

-- Auto Collect Items
task.spawn(function()
    while true do
        task.wait(0.5)
        if not (Toggles.AutoCollect and Toggles.AutoCollect.Value) then continue end
        if not RootPart then continue end
        local MaxDist = Options.AutoCollectDist and Options.AutoCollectDist.Value or 20
        for _, Item in Objects.Items do
            if not Item or not Item.Parent then continue end
            local Part = Item:IsA('BasePart') and Item or Item:FindFirstChildOfClass('BasePart')
            if not Part then continue end
            if (RootPart.Position - Part.Position).Magnitude > MaxDist then continue end
            for _, Prompt in Item:GetDescendants() do
                if Prompt:IsA('ProximityPrompt') and Prompt.Enabled then
                    RootPart.CFrame = Part.CFrame
                    if fireproximityprompt then fireproximityprompt(Prompt) end
                end
            end
        end
    end
end)

-- Auto Collect Currency
task.spawn(function()
    while true do
        task.wait(0.4)
        if not (Toggles.CollectCurrency and Toggles.CollectCurrency.Value) then continue end
        if not RootPart then continue end
        local MaxDist = Options.CollectCurrencyDist and Options.CollectCurrencyDist.Value or 15
        for _, Coin in Objects.Currency do
            if not Coin or not Coin.Parent then continue end
            local Part = Coin:IsA('BasePart') and Coin or Coin:FindFirstChildOfClass('BasePart')
            if not Part then continue end
            if (RootPart.Position - Part.Position).Magnitude > MaxDist then continue end
            for _, Prompt in Coin:GetDescendants() do
                if Prompt:IsA('ProximityPrompt') and Prompt.Enabled then
                    if fireproximityprompt then fireproximityprompt(Prompt) end
                end
            end
        end
    end
end)

-- Auto TP Next Door
local TpNextDoorConn
Toggles.TpNextDoorToggle:OnChanged(function(Value)
    if TpNextDoorConn then task.cancel(TpNextDoorConn) TpNextDoorConn = nil end
    if not Value then return end
    TpNextDoorConn = task.spawn(function()
        while Toggles.TpNextDoorToggle.Value do
            local Door = GetNextClosedDoor()
            if Door and Character then
                Character:PivotTo(Door:GetPivot() * CFrame.new(0, -1, 0))
            end
            task.wait(0.15)
        end
    end)
end)

-- ESP heartbeat
RunService.Heartbeat:Connect(function()
    local function Tick(Toggle, Group, ColorOpt, Fallback)
        if Toggles[Toggle] and Toggles[Toggle].Value then
            local Col = Options[ColorOpt] and Options[ColorOpt].Value or Fallback
            for _, Obj in Group do
                if Obj and Obj.Parent and not ESPObjects[Obj] then AddESP(Obj, Col) end
            end
        else
            ClearESPGroup(Group)
        end
    end
    Tick('EntityESP',  Objects.Entities,  'EntityESPColor',   Color3.fromRGB(255, 50,  50))
    Tick('ItemESP',    Objects.Items,      'ItemESPColor',     Color3.fromRGB(50,  255, 100))
    Tick('DoorESP',    Objects.Doors,      'DoorESPColor',     Color3.fromRGB(100, 150, 255))
    Tick('ChestESP',   Objects.Chests,     'ChestESPColor',    Color3.fromRGB(255, 215, 0))
    Tick('ClosetESP',  Objects.HidingSpots,'ClosetESPColor',   Color3.fromRGB(0,   200, 255))
    Tick('CurrencyESP',Objects.Currency,   'CurrencyESPColor', Color3.fromRGB(255, 230, 50))
end)

-- ── Auto Hotel ────────────────────────────────────────────────────────────────
local AutoHotelConn
local AutoHotelEntityNames = {
    RushMoving=true, Scribbles=true, BashMoving=true, DronesStampede=true,
    AmbushMoving=true, A60=true, A120=true, GlitchRush=true,
    GlitchAmbush=true, BackdoorRush=true, CustomEntity=true,
}

local function AHEntityPresent()
    if Toggles.AutoHotelIgnoreEntities and Toggles.AutoHotelIgnoreEntities.Value then return false end
    for _, E in Objects.Entities do
        if AutoHotelEntityNames[E.Name] then return true end
    end
    return false
end

local function AHWaitEntities(Secs)
    if Toggles.AutoHotelIgnoreEntities and Toggles.AutoHotelIgnoreEntities.Value then return end
    task.wait(Secs or 5)
    while AHEntityPresent() do task.wait(0.15) end
end

local function AHHandleKey(RoomNum)
    if not CurrentRooms then return false end
    local Room = CurrentRooms:FindFirstChild(tostring(RoomNum))
    if not Room then return false end
    local Door = Room:FindFirstChild('Door')
    if not Door or not Door:FindFirstChild('Lock') then return false end
    local KeyObtain
    for _, D in Room:GetDescendants() do
        if D.Name == 'KeyObtain' then KeyObtain = D break end
    end
    if not KeyObtain then return false end
    local Start = tick()
    while tick() - Start < 12 do
        if LocalPlayer.Backpack:FindFirstChild('Key') or (Character and Character:FindFirstChild('Key')) then return true end
        if Character then Character:PivotTo(KeyObtain:GetPivot()) end
        for _, D in KeyObtain:GetDescendants() do
            if D:IsA('ProximityPrompt') then if fireproximityprompt then fireproximityprompt(D) end end
        end
        task.wait(0.12)
    end
    return false
end

Toggles.AutoHotel:OnChanged(function(Value)
    if AutoHotelConn then task.cancel(AutoHotelConn) AutoHotelConn = nil end
    if not Value then return end

    AutoHotelConn = task.spawn(function()
        while Toggles.AutoHotel.Value do
            if AHEntityPresent() then
                while AHEntityPresent() and Toggles.AutoHotel.Value do task.wait(0.15) end
            end
            local Door, RoomNum = GetNextClosedDoor()
            if Door and RoomNum and Character then
                AHHandleKey(RoomNum)
                if Character then
                    Character:PivotTo(Door:GetPivot() * CFrame.new(0, -1, 0))
                end
            end
            task.wait(0.15)
        end
    end)
end)

-- ── Skip Seek (Hotel) ─────────────────────────────────────────────────────────
Toggles.SkipSeekHotel:OnChanged(function(Value)
    if not Value then return end
    task.spawn(function()
        local LastTriggerRoom = nil
        while Toggles.SkipSeekHotel.Value do
            if not CurrentRooms then task.wait(0.2) continue end
            local TriggerNum = nil
            for _, Room in CurrentRooms:GetChildren() do
                local N = tonumber(Room.Name)
                if N and N ~= LastTriggerRoom and
                    (Room:FindFirstChild('TriggerEventCollision') or Room:FindFirstChild('TriggerEventCollision', true)) then
                    TriggerNum = N break
                end
            end
            if not TriggerNum then task.wait(0.15) continue end
            LastTriggerRoom = TriggerNum

            local RoomNum = TriggerNum
            while Toggles.SkipSeekHotel.Value do
                RoomNum += 1
                local Room
                repeat
                    if not Toggles.SkipSeekHotel.Value then return end
                    Room = CurrentRooms and CurrentRooms:FindFirstChild(tostring(RoomNum))
                    task.wait(0.1)
                until Room

                local HasSeekArm = false
                local Assets = Room:FindFirstChild('Assets')
                if Assets then
                    for _, Child in Assets:GetChildren() do
                        if Child.Name == 'Seek_Arm' then HasSeekArm = true break end
                    end
                end

                local Door
                repeat
                    if not Toggles.SkipSeekHotel.Value then return end
                    Door = Room:FindFirstChild('Door', true)
                    task.wait(0.1)
                until Door

                repeat
                    if not Toggles.SkipSeekHotel.Value then return end
                    if Character then Character:PivotTo(Door:GetPivot()) end
                    task.wait()
                until Door:GetAttribute('Opened') == true

                if HasSeekArm then
                    local VoidCF = Character:GetPivot() + Vector3.new(0, -2500, 0)
                    task.wait(0.25)
                    for _ = 1, 20 do Character:PivotTo(VoidCF) task.wait() end
                    task.wait(0.3)
                    for _ = 1, 15 do Character:PivotTo(VoidCF) task.wait() end
                    break
                end
            end
        end
    end)
end)

-- ═════════════════════════════════════════════════════════════════════════════
--  THEME / SAVE
-- ═════════════════════════════════════════════════════════════════════════════
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
ThemeManager:SetFolder('DoorsOP')
SaveManager:SetFolder('DoorsOP/config')
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

Library:SetWatermark('avDoors | ' .. Floor)
Library:SetWatermarkVisibility(true)
Library.KeybindFrame.Visible = true
