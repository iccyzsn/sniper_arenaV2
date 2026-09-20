--=========================================================================
--  EGG FARMER MOD MENU  |  Place 124216119978534
--  Draggable, tabbed panel. RightShift = open/close.
--=========================================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")
local UIS        = game:GetService("UserInputService")
local Tween      = game:GetService("TweenService")
local Lighting   = game:GetService("Lighting")
local CoreGui    = game:GetService("CoreGui")

local LP      = Players.LocalPlayer
local Camera  = Workspace.CurrentCamera
local Mouse   = LP:GetMouse()

-------------------------------------------------------------------------
-- CLEAN OLD INSTANCE
-------------------------------------------------------------------------
if CoreGui:FindFirstChild("EggFarmerMenu") then
    CoreGui.EggFarmerMenu:Destroy()
end

-------------------------------------------------------------------------
-- STATE
-------------------------------------------------------------------------
local State = {
    -- Visuals
    EggESP        = false,
    EggDist       = true,
    EggTracers    = false,
    SpawnESP      = false,
    SpawnTracers  = false,
    PlayerESP     = false,
    Fullbright    = false,
    MaxDistance   = 2500,
    EspColorMode  = "Rarity",  -- "Rarity" or "Static"

    -- Movement
    Speed         = false,
    SpeedVal      = 60,
    Jump          = false,
    JumpVal       = 120,
    Fly           = false,
    FlySpeed      = 80,
    Noclip        = false,
    InfiniteJump  = false,

    -- Auto
    AutoCollect   = false,
    CollectRange  = 25,
}

-------------------------------------------------------------------------
-- RARITY DATA (from DEX dump)
-------------------------------------------------------------------------
local EGG_RARITY = {
    ["White Egg"]     = "Common",
    ["Brown Egg"]     = "Common",
    ["Cracked Egg"]   = "Common",
    ["Stone Egg"]     = "Uncommon",
    ["Leaf Egg"]      = "Uncommon",
    ["Ice Egg"]       = "Uncommon",
    ["Slime Egg"]     = "Uncommon",
    ["Mushroom Egg"]  = "Uncommon",
    ["Glass Egg"]     = "Rare",
    ["Golden Egg"]    = "Rare",
    ["Easter Egg"]    = "Rare",
    ["Skull Egg"]     = "Epic",
    ["Soul Egg"]      = "Epic",
    ["Sinister Egg"]  = "Epic",
    ["Aurora Egg"]    = "Legendary",
    ["Galaxy Egg"]    = "Legendary",
    ["Blackhole Egg"] = "Legendary",
    ["Dominus Egg"]   = "Mythic",
}
local RC = {
    ["Common"]    = Color3.fromRGB(210,210,210),
    ["Uncommon"]  = Color3.fromRGB(0, 220, 90),
    ["Rare"]      = Color3.fromRGB(0, 170, 255),
    ["Epic"]      = Color3.fromRGB(170, 85, 255),
    ["Legendary"] = Color3.fromRGB(255, 170, 0),
    ["Mythic"]    = Color3.fromRGB(255, 50, 120),
    ["Divine"]    = Color3.fromRGB(255, 255, 160),
    ["Spawn"]     = Color3.fromRGB(255, 100, 100),
    ["Unknown"]   = Color3.fromRGB(255, 255, 255),
}
local function classify(inst)
    local a = inst:GetAttribute("A_OrigRarity")
    if typeof(a) == "string" and RC[a] then return a, RC[a] end
    local r = EGG_RARITY[inst.Name]
    if r then return r, RC[r] end
    if inst:HasTag("AutoEggSpawn") then return "Spawn", RC.Spawn end
    return "Unknown", RC.Unknown
end
local function getPos(inst)
    if inst:IsA("Model") then
        if inst.PrimaryPart then return inst.PrimaryPart.Position end
        local ok, piv = pcall(function() return inst:GetPivot() end)
        if ok then return piv.Position end
    elseif inst:IsA("BasePart") then
        return inst.Position
    end
end

-------------------------------------------------------------------------
-- THEME
-------------------------------------------------------------------------
local Theme = {
    BG          = Color3.fromRGB(18, 18, 22),
    BG2         = Color3.fromRGB(26, 26, 32),
    BG3         = Color3.fromRGB(34, 34, 42),
    Stroke      = Color3.fromRGB(50, 50, 60),
    Accent      = Color3.fromRGB(0, 170, 255),
    Accent2     = Color3.fromRGB(170, 85, 255),
    Text        = Color3.fromRGB(235, 235, 240),
    TextDim     = Color3.fromRGB(150, 150, 160),
    Green       = Color3.fromRGB(0, 220, 100),
    Red         = Color3.fromRGB(255, 70, 90),
}

-------------------------------------------------------------------------
-- UTIL BUILDERS
-------------------------------------------------------------------------
local function new(class, props, children)
    local i = Instance.new(class)
    for k,v in pairs(props or {}) do i[k] = v end
    for _,c in ipairs(children or {}) do c.Parent = i end
    return i
end
local function corner(p, r)
    new("UICorner", {CornerRadius = UDim.new(0, r or 8), Parent = p})
end
local function stroke(p, c, t)
    new("UIStroke", {
        Color = c or Theme.Stroke, Thickness = t or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p
    })
end
local function pad(p, n)
    new("UIPadding", {
        PaddingTop=UDim.new(0,n), PaddingBottom=UDim.new(0,n),
        PaddingLeft=UDim.new(0,n), PaddingRight=UDim.new(0,n), Parent=p
    })
end
local function label(parent, text, size, color, bold)
    return new("TextLabel", {
        BackgroundTransparency=1, Text=text, TextSize=size or 13,
        TextColor3=color or Theme.Text, Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left, Size=UDim2.new(1,0,0,size and size+4 or 18),
        Parent=parent
    })
end

-------------------------------------------------------------------------
-- NOTIFICATIONS
-------------------------------------------------------------------------
local NotifyHolder = new("Frame", {
    Name="NotifHolder", Parent=CoreGui.EggFarmerMenu or CoreGui,
    BackgroundTransparency=1, Size=UDim2.new(0,300,0,400),
    Position=UDim2.new(1,-320,0,20), AnchorPoint=Vector2.new(1,0)
})
NotifyHolder.Parent = nil  -- will be reparented later

local function Notify(title, msg, color)
    color = color or Theme.Accent
    local holder = CoreGui:FindFirstChild("EggFarmerMenu")
    if not holder then return end
    local n = new("Frame", {
        Size=UDim2.new(0,280,0,64), BackgroundColor3=Theme.BG2,
        BorderSizePixel=0, Position=UDim2.new(1,-20,1,-20), AnchorPoint=Vector2.new(1,1),
        Parent = holder.Push
    })
    corner(n,10); stroke(n, color, 1.5)
    local bar = new("Frame", {
        Size=UDim2.new(0,4,1,0), BackgroundColor3=color, BorderSizePixel=0, Parent=n
    })
    corner(bar,2)
    label(n, title, 14, color, true).Position = UDim2.new(0,14,0,8)
    local m = label(n, msg, 12, Theme.TextDim); m.Position = UDim2.new(0,14,0,30); m.Size=UDim2.new(1,-20,0,28); m.TextWrapped=true
    pad(n, 8)
    task.spawn(function()
        task.wait(2.6)
        local t = Tween:Create(n, TweenInfo.new(0.35), {BackgroundTransparency=1})
        local t2 = Tween:Create(bar, TweenInfo.new(0.35), {BackgroundTransparency=1})
        t:Play(); t2:Play()
        for _,ch in ipairs(n:GetDescendants()) do
            if ch:IsA("TextLabel") then Tween:Create(ch, TweenInfo.new(0.35), {TextTransparency=1}):Play() end
        end
        task.wait(0.4); n:Destroy()
    end)
end

-------------------------------------------------------------------------
-- MAIN WINDOW
-------------------------------------------------------------------------
local Screen = new("ScreenGui", {
    Name="EggFarmerMenu", Parent=CoreGui,
    ResetOnSpawn=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling
})

local Main = new("Frame", {
    Name="Main", Parent=Screen, Size=UDim2.new(0,560,0,380),
    Position=UDim2.new(0.5,-280,0.5,-190), BackgroundColor3=Theme.BG,
    BorderSizePixel=0, Active=true, Draggable=true
})
corner(Main, 12); stroke(Main, Theme.Stroke, 1)

-- Push (notification stack)
local Push = new("Frame", {Name="Push", Parent=Main,
    Size=UDim2.new(0,300,1,0), Position=UDim2.new(1,-300,0,0),
    BackgroundTransparency=1, ZIndex=10})

-- Title bar
local TitleBar = new("Frame", {Parent=Main, Size=UDim2.new(1,0,0,44),
    BackgroundColor3=Theme.BG2, BorderSizePixel=0})
corner(TitleBar, 12)
new("Frame", {Parent=TitleBar, Size=UDim2.new(1,0,0,14),
    Position=UDim2.new(0,0,1,-14), BackgroundColor3=Theme.BG2, BorderSizePixel=0})
label(TitleBar, "🥚  EGG FARMER", 17, Theme.Accent, true).Position = UDim2.new(0,16,0,0)
label(TitleBar, "MOD MENU", 11, Theme.TextDim, true).Position = UDim2.new(0,170,0,6)
local BuildTag = label(TitleBar, "ID 124216119978534", 10, Theme.TextDim)
BuildTag.Position = UDim2.new(0,170,0,22)

local MinBtn = new("TextButton", {Parent=TitleBar, Size=UDim2.new(0,28,0,28),
    Position=UDim2.new(1,-76,0,8), BackgroundColor3=Theme.BG3,
    Text="—", TextColor3=Theme.Text, TextSize=16, Font=Enum.Font.GothamBold,
    BorderSizePixel=0, AutoButtonColor=true})
corner(MinBtn,6)

local CloseBtn = new("TextButton", {Parent=TitleBar, Size=UDim2.new(0,28,0,28),
    Position=UDim2.new(1,-40,0,8), BackgroundColor3=Theme.BG3,
    Text="✕", TextColor3=Theme.Red, TextSize=15, Font=Enum.Font.GothamBold,
    BorderSizePixel=0})
corner(CloseBtn,6)

-- Tab bar
local TabBar = new("Frame", {Parent=Main, Size=UDim2.new(0,130,1,-44),
    Position=UDim2.new(0,0,0,44), BackgroundColor3=Theme.BG, BorderSizePixel=0})

-- Content
local Content = new("Frame", {Parent=Main, Size=UDim2.new(1,-130,1,-44),
    Position=UDim2.new(0,130,0,44), BackgroundColor3=Theme.BG, BorderSizePixel=0})
pad(Content, 12)

-- Divider
new("Frame", {Parent=Main, Size=UDim2.new(0,1,1,-60),
    Position=UDim2.new(0,130,0,52), BackgroundColor3=Theme.Stroke, BorderSizePixel=0})

-------------------------------------------------------------------------
-- DRAG
-------------------------------------------------------------------------
do
    local dragging, dragStart, startPos
    TitleBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = i.Position; startPos = Main.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging=false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X,
                                      startPos.Y.Scale, startPos.Y.Offset+d.Y)
        end
    end)
end

MinBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
    Notify("Minimized", "Press RIGHT SHIFT to open again", Theme.Accent2)
end)
CloseBtn.MouseButton1Click:Connect(function()
    Screen:Destroy()
    NotifyHolder:Destroy()
end)

-------------------------------------------------------------------------
-- TAB SYSTEM
-------------------------------------------------------------------------
local Tabs = {}
local CurrentTab
local TabOrder = {}

local function makeTab(name, icon)
    local btn = new("TextButton", {
        Parent=TabBar, Size=UDim2.new(1,-16,0,34),
        BackgroundColor3=Theme.BG, Text="  "..icon.."  "..name,
        TextColor3=Theme.TextDim, TextSize=13, Font=Enum.Font.GothamMedium,
        TextXAlignment=Enum.TextXAlignment.Left, BorderSizePixel=0, AutoButtonColor=false
    })
    corner(btn, 8)
    btn.Position = UDim2.new(0,8,0,8 + (#TabOrder * 38))

    local container = new("Frame", {Parent=Content, Size=UDim2.new(1,0,1,0),
        BackgroundTransparency=1, Visible=false})
    new("UIListLayout", {Parent=container, Padding=UDim.new(0,8),
        SortOrder=Enum.SortOrder.LayoutOrder})

    local tab = { btn=btn, container=container, name=name }

    local function select()
        if CurrentTab then
            CurrentTab.container.Visible = false
            Tween:Create(CurrentTab.btn, TweenInfo.new(0.15),
                {BackgroundColor3=Theme.BG, TextColor3=Theme.TextDim}):Play()
        end
        CurrentTab = tab
        container.Visible = true
        Tween:Create(btn, TweenInfo.new(0.15),
            {BackgroundColor3=Theme.BG3, TextColor3=Theme.Accent}):Play()
    end

    btn.MouseButton1Click:Connect(select)
    table.insert(TabOrder, tab)
    Tabs[name] = tab
    if #TabOrder == 1 then select() end
    return tab
end

-------------------------------------------------------------------------
-- WIDGETS
-------------------------------------------------------------------------
local function sectionTitle(parent, text)
    local holder = new("Frame", {Parent=parent, Size=UDim2.new(1,0,0,26),
        BackgroundTransparency=1, LayoutOrder=100})
    local bar = new("Frame", {Parent=holder, Size=UDim2.new(0,3,0,16),
        Position=UDim2.new(0,0,0,5), BackgroundColor3=Theme.Accent, BorderSizePixel=0})
    corner(bar,2)
    label(holder, text, 14, Theme.Text, true).Position = UDim2.new(0,12,0,3)
    return holder
end

local function toggle(parent, name, default, callback)
    local state = default
    local holder = new("Frame", {Parent=parent, Size=UDim2.new(1,0,0,38),
        BackgroundColor3=Theme.BG2, BorderSizePixel=0})
    corner(holder, 8); stroke(holder, Theme.Stroke)
    label(holder, name, 13, Theme.Text).Position = UDim2.new(0,12,0,10)

    local btn = new("TextButton", {Parent=holder, Size=UDim2.new(0,44,0,22),
        Position=UDim2.new(1,-56,0,8), BackgroundColor3=state and Theme.Green or Theme.BG3,
        Text="", BorderSizePixel=0, AutoButtonColor=false})
    corner(btn, 11)
    local knob = new("Frame", {Parent=btn, Size=UDim2.new(0,16,0,16),
        Position=state and UDim2.new(1,-20,0,3) or UDim2.new(0,4,0,3),
        BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0})
    corner(knob,8)

    local function set(v)
        state = v
        Tween:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = v and Theme.Green or Theme.BG3}):Play()
        Tween:Create(knob, TweenInfo.new(0.15), {Position = v and UDim2.new(1,-20,0,3) or UDim2.new(0,4,0,3)}):Play()
        if callback then callback(v) end
    end
    btn.MouseButton1Click:Connect(function() set(not state) end)

    return holder, set
end

local function slider(parent, name, min, max, default, callback)
    local holder = new("Frame", {Parent=parent, Size=UDim2.new(1,0,0,54),
        BackgroundColor3=Theme.BG2, BorderSizePixel=0})
    corner(holder,8); stroke(holder, Theme.Stroke)

    label(holder, name, 13, Theme.Text).Position = UDim2.new(0,12,0,6)
    local valueLbl = label(holder, tostring(default), 12, Theme.Accent, true)
    valueLbl.Position = UDim2.new(1,-70,0,7); valueLbl.Size=UDim2.new(0,60,0,16)
    valueLbl.TextXAlignment = Enum.TextXAlignment.Right

    local bar = new("Frame", {Parent=holder, Size=UDim2.new(1,-24,0,8),
        Position=UDim2.new(0,12,0,34), BackgroundColor3=Theme.BG3, BorderSizePixel=0})
    corner(bar,4)
    local fill = new("Frame", {Parent=bar, Size=UDim2.new((default-min)/(max-min),0,1,0),
        BackgroundColor3=Theme.Accent, BorderSizePixel=0})
    corner(fill,4)
    local knob = new("Frame", {Parent=fill, Size=UDim2.new(0,14,0,14),
        Position=UDim2.new(1,-7,0.5,-7), BackgroundColor3=Color3.new(1,1,1),
        BorderSizePixel=0, ZIndex=2})
    corner(knob,7)

    local dragging = false
    local function upd(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local v = math.floor(min + (max-min)*rel + 0.5)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        valueLbl.Text = tostring(v)
        if callback then callback(v) end
    end
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging=true; upd(i.Position.X) end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then upd(i.Position.X) end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging=false end
    end)
    return holder
end

local function button(parent, name, callback, color)
    color = color or Theme.Accent
    local btn = new("TextButton", {Parent=parent, Size=UDim2.new(1,0,0,34),
        BackgroundColor3=Theme.BG2, Text=name, TextColor3=color,
        TextSize=13, Font=Enum.Font.GothamBold, BorderSizePixel=0,
        AutoButtonColor=false})
    corner(btn,8); stroke(btn, Theme.Stroke)
    btn.MouseEnter:Connect(function()
        Tween:Create(btn, TweenInfo.new(0.15), {BackgroundColor3=Theme.BG3}):Play()
    end)
    btn.MouseLeave:Connect(function()
        Tween:Create(btn, TweenInfo.new(0.15), {BackgroundColor3=Theme.BG2}):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        pcall(callback)
    end)
    return btn
end

local function dropdown(parent, name, options, default, callback)
    local holder = new("Frame", {Parent=parent, Size=UDim2.new(1,0,0,38),
        BackgroundColor3=Theme.BG2, BorderSizePixel=0})
    corner(holder,8); stroke(holder, Theme.Stroke)
    label(holder, name, 13, Theme.Text).Position = UDim2.new(0,12,0,10)

    local cur = default or options[1]
    local valLbl = label(holder, cur, 12, Theme.Accent, true)
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Position = UDim2.new(1,-140,0,10); valLbl.Size=UDim2.new(0,128,0,16)

    local btn = new("TextButton", {Parent=holder, Size=UDim2.new(1,0,1,0),
        BackgroundTransparency=1, Text="", ZIndex=2})

    local idx = 1
    for i,o in ipairs(options) do if o == cur then idx = i end end

    btn.MouseButton1Click:Connect(function()
        idx = idx % #options + 1
        cur = options[idx]
        valLbl.Text = cur
        if callback then callback(cur) end
    end)
    return holder
end

-------------------------------------------------------------------------
-- ==========  ESP SYSTEM  ==========
-------------------------------------------------------------------------
local EspFolder = new("Folder", {Name="ModESP", Parent=Workspace})
local Tracked = {}

local function clearAllESP()
    for inst, rec in pairs(Tracked) do
        pcall(function() rec.hl:Destroy() end)
        pcall(function() rec.bg:Destroy() end)
        pcall(function() rec.beam:Destroy() end)
        pcall(function() rec.a0:Destroy() end)
        pcall(function() rec.a1:Destroy() end)
    end
    Tracked = {}
end

local function addESP(inst, kind)
    if Tracked[inst] then return end
    local pos = getPos(inst); if not pos then return end
    local rarity, color = classify(inst)

    local hl = new("Highlight", {Parent=EspFolder, Adornee=inst, Name="HL",
        FillColor=color, OutlineColor=color, FillTransparency=0.6, OutlineTransparency=0,
        DepthMode=Enum.HighlightDepthMode.AlwaysOnTop, Enabled=false})

    local bg = new("BillboardGui", {Parent=EspFolder, Adornee=inst, Name="BG",
        Size=UDim2.new(0,220,0,32), StudsOffset=Vector3.new(0,3,0),
        AlwaysOnTop=true, ResetOnSpawn=false, Enabled=false})

    local lbl = new("TextLabel", {Parent=bg, Size=UDim2.new(1,0,1,0),
        BackgroundTransparency=1, Text=inst.Name, TextColor3=color,
        Font=Enum.Font.GothamBold, TextSize=14,
        TextStrokeTransparency=0, TextStrokeColor3=Color3.new(0,0,0),
        TextXAlignment=Enum.TextXAlignment.Center})

    local a0 = new("Attachment", {Parent=EspFolder})
    local a1 = new("Attachment", {Parent=EspFolder})
    local beam = new("Beam", {Parent=EspFolder, Attachment0=a0, Attachment1=a1,
        Width0=0.12, Width1=0.12, FaceCamera=true, LightEmission=1, Enabled=false,
        Color=ColorSequence.new(color), Transparency=NumberSequence.new(0.35)})

    Tracked[inst] = {inst=inst, hl=hl, bg=bg, lbl=lbl, beam=beam,
                     a0=a0, a1=a1, color=color, rarity=rarity, kind=kind}

    inst.AncestryChanged:Connect(function(_, p)
        if not p then
            for _,c in ipairs({hl,bg,beam,a0,a1}) do pcall(function() c:Destroy() end) end
            Tracked[inst] = nil
        end
    end)
end

local function scan()
    local eggs = Workspace:FindFirstChild("RenderedEggs")
    local spawns = Workspace:FindFirstChild("EggSpawns")
    if State.EggESP and eggs then
        for _, c in ipairs(eggs:GetChildren()) do
            if c:IsA("Model") then addESP(c, "egg") end
        end
    end
    if State.SpawnESP and spawns then
        for _, c in ipairs(spawns:GetChildren()) do
            if c:IsA("BasePart") and c:HasTag("AutoEggSpawn") then addESP(c, "spawn") end
        end
    end
    if State.PlayerESP then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP and plr.Character then
                local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                if hrp then addESP(hrp, "player") end
            end
        end
    end
end

-- Hook new children
task.spawn(function()
    local eggs = Workspace:WaitForChild("RenderedEggs", 20)
    if eggs then
        eggs.ChildAdded:Connect(function(c)
            if State.EggESP and c:IsA("Model") then
                task.wait(0.12); addESP(c, "egg")
            end
        end)
    end
    local sp = Workspace:FindFirstChild("EggSpawns")
    if sp then
        sp.ChildAdded:Connect(function(c)
            if State.SpawnESP and c:IsA("BasePart") then addESP(c, "spawn") end
        end)
    end
end)

-------------------------------------------------------------------------
-- ==========  MOVEMENT SYSTEM  ==========
-------------------------------------------------------------------------
local function getChar()
    local c = LP.Character or LP.CharacterAdded:Wait()
    return c, c:FindFirstChild("Humanoid"), c:FindFirstChild("HumanoidRootPart")
end

RunService.Heartbeat:Connect(function()
    local _, hum = getChar()
    if not hum then return end
    if State.Speed and hum.WalkSpeed ~= State.SpeedVal then hum.WalkSpeed = State.SpeedVal end
    if State.Jump  and hum.UseJumpPower then hum.JumpPower = State.JumpVal end
end)

-- Infinite Jump
UIS.JumpRequest:Connect(function()
    if State.InfiniteJump then
        local c, hum = getChar()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- Noclip
RunService.Stepped:Connect(function()
    if State.Noclip and LP.Character then
        for _, p in ipairs(LP.Character:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end
end)

-- Fly
do
    local flyConn, bodyVel, bodyGyro
    local function startFly()
        local c, hum, hrp = getChar()
        if not hrp then return end
        bodyVel = new("BodyVelocity", {Parent=hrp, MaxForce=Vector3.new(1e5,1e5,1e5), P=1250, Velocity=Vector3.zero})
        bodyGyro = new("BodyGyro", {Parent=hrp, MaxTorque=Vector3.new(1e5,1e5,1e5), P=1250, CFrame=hrp.CFrame})
        flyConn = RunService.RenderStepped:Connect(function()
            local c2, h2, hrp2 = getChar()
            if not hrp2 or not bodyVel then return end
            local move = Vector3.zero
            local camCF = Camera.CFrame
            if UIS:IsKeyDown(Enum.KeyCode.W) then move += camCF.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then move -= camCF.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then move -= camCF.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then move += camCF.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0,1,0) end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0,1,0) end
            if move.Magnitude > 0 then move = move.Unit end
            bodyVel.Velocity = move * State.FlySpeed
            bodyGyro.CFrame = camCF
        end)
    end
    local function stopFly()
        if flyConn then flyConn:Disconnect(); flyConn = nil end
        if bodyVel then bodyVel:Destroy(); bodyVel = nil end
        if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end
    end
    State._startFly = startFly
    State._stopFly = stopFly
end

-- Auto collect (touch eggs)
RunService.Heartbeat:Connect(function()
    if not State.AutoCollect then return end
    local _, _, hrp = getChar()
    if not hrp then return end
    local eggs = Workspace:FindFirstChild("RenderedEggs")
    if not eggs then return end
    for _, egg in ipairs(eggs:GetChildren()) do
        if egg:IsA("Model") then
            local p = getPos(egg)
            if p and (p - hrp.Position).Magnitude <= State.CollectRange then
                -- Fires touch signal by moving into it via firetouchinterest if available
                local part = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart")
                if part and firetouchinterest then
                    pcall(function()
                        firetouchinterest(hrp, part, 0)
                        task.wait()
                        firetouchinterest(hrp, part, 1)
                    end)
                end
            end
        end
    end
end)

-------------------------------------------------------------------------
-- ==========  BUILD TABS  ==========
-------------------------------------------------------------------------

--- Visuals Tab
do
    local T = makeTab("Visuals", "👁")
    local C = T.container
    sectionTitle(C, "EGGS")
    toggle(C, "Egg ESP", State.EggESP, function(v)
        State.EggESP = v; scan()
        if not v then
            for inst, rec in pairs(Tracked) do
                if rec.kind == "egg" then
                    for _,c in ipairs({rec.hl, rec.bg, rec.beam}) do c:Destroy() end
                    rec.a0:Destroy(); rec.a1:Destroy()
                    Tracked[inst] = nil
                end
            end
        end
    end)
    toggle(C, "Show Rarity + Distance", State.EggDist, function(v) State.EggDist = v end)
    toggle(C, "Egg Tracers", State.EggTracers, function(v) State.EggTracers = v end)

    sectionTitle(C, "SPAWN POINTS")
    toggle(C, "Spawn Point ESP", State.SpawnESP, function(v)
        State.SpawnESP = v; scan()
        if not v then
            for inst, rec in pairs(Tracked) do
                if rec.kind == "spawn" then
                    for _,c in ipairs({rec.hl, rec.bg, rec.beam}) do c:Destroy() end
                    rec.a0:Destroy(); rec.a1:Destroy()
                    Tracked[inst] = nil
                end
            end
        end
    end)
    toggle(C, "Spawn Tracers", State.SpawnTracers, function(v) State.SpawnTracers = v end)

    sectionTitle(C, "PLAYERS")
    toggle(C, "Player ESP", State.PlayerESP, function(v)
        State.PlayerESP = v; scan()
    end)

    sectionTitle(C, "MISC")
    toggle(C, "Fullbright", State.Fullbright, function(v)
        State.Fullbright = v
        if v then
            Lighting.Brightness = 3
            Lighting.ClockTime = 12
            Lighting.FogEnd = 1e6
            Lighting.GlobalShadows = false
        else
            Lighting.Brightness = 2
            Lighting.GlobalShadows = true
        end
    end)
    slider(C, "Max Render Distance", 200, 8000, State.MaxDistance, function(v) State.MaxDistance = v end)
end

--- Movement Tab
do
    local T = makeTab("Movement", "⚡")
    local C = T.container
    sectionTitle(C, "SPEED / JUMP")
    toggle(C, "Speed Hack", State.Speed, function(v) State.Speed = v end)
    slider(C, "Speed Value", 16, 400, State.SpeedVal, function(v) State.SpeedVal = v end)
    toggle(C, "Jump Hack", State.Jump, function(v) State.Jump = v end)
    slider(C, "Jump Value", 50, 400, State.JumpVal, function(v) State.JumpVal = v end)

    sectionTitle(C, "FLIGHT")
    toggle(C, "Fly", State.Fly, function(v)
        State.Fly = v
        if v then State._startFly() else State._stopFly() end
    end)
    slider(C, "Fly Speed", 20, 400, State.FlySpeed, function(v) State.FlySpeed = v end)

    sectionTitle(C, "UTILITY")
    toggle(C, "Noclip", State.Noclip, function(v) State.Noclip = v end)
    toggle(C, "Infinite Jump", State.InfiniteJump, function(v) State.InfiniteJump = v end)
end

--- Auto Tab
do
    local T = makeTab("Auto", "🤖")
    local C = T.container
    sectionTitle(C, "AUTO COLLECT")
    toggle(C, "Auto Touch Eggs", State.AutoCollect, function(v) State.AutoCollect = v end)
    slider(C, "Collect Range", 5, 100, State.CollectRange, function(v) State.CollectRange = v end)
    button(C, "Collect ALL RenderedEggs Now", function()
        local eggs = Workspace:FindFirstChild("RenderedEggs")
        if not eggs or not firetouchinterest then
            Notify("Auto Collect", "firetouchinterest not available", Theme.Red); return
        end
        local _, _, hrp = getChar(); if not hrp then return end
        local count = 0
        for _, egg in ipairs(eggs:GetChildren()) do
            if egg:IsA("Model") then
                local part = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart")
                if part then
                    pcall(function()
                        firetouchinterest(hrp, part, 0)
                        task.wait()
                        firetouchinterest(hrp, part, 1)
                    end)
                    count += 1
                    task.wait(0.05)
                end
            end
        end
        Notify("Auto Collect", "Touched "..count.." eggs", Theme.Green)
    end, Theme.Green)
end

--- Teleport Tab
do
    local T = makeTab("Teleport", "📍")
    local C = T.container
    sectionTitle(C, "EGG SPAWNPOINTS")

    local function tpTo(pos, name)
        local _, _, hrp = getChar(); if not hrp then return end
        hrp.CFrame = CFrame.new(pos + Vector3.new(0,4,0))
        Notify("Teleport", name or "Moved", Theme.Accent)
    end

    button(C, "◀ Nearest Egg", function()
        local eggs = Workspace:FindFirstChild("RenderedEggs"); if not eggs then return end
        local _, _, hrp = getChar(); if not hrp then return end
        local best, bestD
        for _, egg in ipairs(eggs:GetChildren()) do
            if egg:IsA("Model") then
                local p = getPos(egg)
                if p then
                    local d = (p - hrp.Position).Magnitude
                    if not bestD or d < bestD then bestD, best = d, p end
                end
            end
        end
        if best then tpTo(best, "Nearest Egg") else Notify("Teleport", "No eggs", Theme.Red) end
    end)

    button(C, "◀ Nearest Rare+ Egg", function()
        local eggs = Workspace:FindFirstChild("RenderedEggs"); if not eggs then return end
        local _, _, hrp = getChar(); if not hrp then return end
        local order = {Rare=3,Epic=4,Legendary=5,Mythic=6,Divine=7}
        local best, bestD, bestR = nil, nil, 0
        for _, egg in ipairs(eggs:GetChildren()) do
            if egg:IsA("Model") then
                local p = getPos(egg)
                local r = EGG_RARITY[egg.Name]
                local lv = r and order[r] or 0
                if p and lv >= 3 then
                    local d = (p - hrp.Position).Magnitude
                    if not bestD or d < bestD then bestD, best, bestR = d, p, lv end
                end
            end
        end
        if best then tpTo(best, "Rare+ Egg") else Notify("Teleport", "None found", Theme.Red) end
    end, Theme.Accent2)

    sectionTitle(C, "STALLS")
    button(C, "Egg Tracker Stall", function()
        local s = Workspace:FindFirstChild("Stalls")
        local t = s and s:FindFirstChild("EggTracker")
        if t then tpTo(t:GetPivot().Position, "Egg Tracker") end
    end)
    button(C, "Food Stall", function()
        local s = Workspace:FindFirstChild("Stalls")
        local t = s and s:FindFirstChild("Food")
        if t then tpTo(t:GetPivot().Position, "Food Stall") end
    end)
    button(C, "Gears Stall", function()
        local s = Workspace:FindFirstChild("Stalls")
        local t = s and s:FindFirstChild("Gears")
        if t then tpTo(t:GetPivot().Position, "Gears Stall") end
    end)
    button(C, "Sell Stall", function()
        local s = Workspace:FindFirstChild("Stalls")
        local t = s and s:FindFirstChild("Sell")
        if t then tpTo(t:GetPivot().Position, "Sell Stall") end
    end)

    sectionTitle(C, "WORLD")
    button(C, "Spawn Point", function()
        local sp = Workspace:FindFirstChild("Spawn")
        if sp then tpTo(sp:GetPivot().Position, "Spawn") end
    end)
    button(C, "World Origin (0,0,0)", function() tpTo(Vector3.zero, "Origin") end)

    sectionTitle(C, "PLAYERS")
    local plrHolder = new("Frame", {Parent=C, Size=UDim2.new(1,0,0,0),
        BackgroundTransparency=1, AutomaticSize=Enum.AutomaticSize.Y})
    new("UIListLayout", {Parent=plrHolder, Padding=UDim.new(0,6)})
    task.spawn(function()
        while T.container.Parent do
            for _, c in ipairs(plrHolder:GetChildren()) do
                if c:IsA("TextButton") then c:Destroy() end
            end
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LP then
                    button(plrHolder, "→ "..plr.Name, function()
                        if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                            tpTo(plr.Character.HumanoidRootPart.Position, plr.Name)
                        end
                    end)
                end
            end
            task.wait(4)
        end
    end)
end

--- Settings Tab
do
    local T = makeTab("Settings", "⚙")
    local C = T.container
    sectionTitle(C, "PANEL")
    button(C, "Reset Panel Position", function()
        Main.Position = UDim2.new(0.5,-280,0.5,-190)
    end)
    button(C, "Re-scan ESP Targets", function()
        scan(); Notify("Scanner", "Re-scanned folders", Theme.Accent)
    end)
    button(C, "Clear ALL ESP", function()
        clearAllESP(); Notify("Scanner", "Cleared all ESP", Theme.Red)
    end, Theme.Red)

    sectionTitle(C, "ABOUT")
    local info = label(C, "Egg Farmer Mod Menu\nPlace ID: 124216119978534\nToggle panel: RIGHT SHIFT", 12, Theme.TextDim)
    info.Size = UDim2.new(1,0,0,60); info.TextWrapped=true
    info.Position = UDim2.new(0,6,0,0); info.LayoutOrder = 100

    sectionTitle(C, "STATS")
    local statLbl = label(C, "Tracked: 0", 12, Theme.Accent, true)
    task.spawn(function()
        while T.container.Parent do
            local n = 0
            for _ in pairs(Tracked) do n = n + 1 end
            statLbl.Text = "Tracked ESP targets: "..n
            task.wait(1)
        end
    end)
end

-------------------------------------------------------------------------
-- ESP UPDATE LOOP
-------------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
    local camPos = Camera.CFrame.Position
    local origin = (Camera.CFrame * CFrame.new(0,-2,-1)).Position

    for inst, rec in pairs(Tracked) do
        if not inst.Parent then
            for _,c in ipairs({rec.hl, rec.bg, rec.beam}) do pcall(function() c:Destroy() end) end
            pcall(function() rec.a0:Destroy() end)
            pcall(function() rec.a1:Destroy() end)
            Tracked[inst] = nil
        else
            local p = getPos(inst)
            if p then
                local dist = (camPos - p).Magnitude
                local visible = dist <= State.MaxDistance

                local wantHL     = State.EggESP and rec.kind == "egg" or State.SpawnESP and rec.kind == "spawn" or State.PlayerESP and rec.kind == "player"
                local wantBeam   = (State.EggTracers and rec.kind=="egg") or (State.SpawnTracers and rec.kind=="spawn")

                rec.hl.Enabled   = visible and wantHL
                rec.bg.Enabled   = visible and wantHL
                rec.beam.Enabled = visible and wantBeam

                if State.EggDist then
                    rec.lbl.Text = string.format("%s [%s] • %dm", inst.Name, rec.rarity, math.floor(dist))
                else
                    rec.lbl.Text = string.format("%s [%s]", inst.Name, rec.rarity)
                end
                if wantBeam then
                    rec.a0.WorldPosition = origin
                    rec.a1.WorldPosition = p
                end
            end
        end
    end
end)

-------------------------------------------------------------------------
-- KEYBINDS
-------------------------------------------------------------------------
UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        Main.Visible = not Main.Visible
    end
end)

-------------------------------------------------------------------------
-- BOOT MESSAGE
-------------------------------------------------------------------------
task.wait(0.6)
Notify("Egg Farmer", "Mod menu loaded. RIGHT SHIFT to toggle.", Theme.Accent)
task.wait(0.4)
Notify("Features", "18 egg types tracked | 4 stalls | TP + Fly", Theme.Accent2)
