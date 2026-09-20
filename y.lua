-- =========================================================
-- CLIENT SCRIPT
-- Place in: StarterPlayer > StarterPlayerScripts (LocalScript)
--   (or StarterGui as a LocalScript)
-- =========================================================
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local Lighting          = game:GetService("Lighting")
local CoreGui           = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player   = Players.LocalPlayer
local uiParent = (gethui and gethui()) or CoreGui

-- Wait for the server-created remote
local adminRemote = ReplicatedStorage:WaitForChild("AdminAction", 10)

if uiParent:FindFirstChild("HiddenMenu") then
    uiParent.HiddenMenu:Destroy()
end

--// Theme
local Theme = {
    Background = Color3.fromRGB(30, 30, 35),
    Sidebar    = Color3.fromRGB(25, 25, 30),
    TopBar     = Color3.fromRGB(20, 20, 25),
    Button     = Color3.fromRGB(45, 45, 55),
    Accent     = Color3.fromRGB(0, 162, 255),
    Text       = Color3.fromRGB(255, 255, 255),
    SubText    = Color3.fromRGB(150, 150, 150),
    Danger     = Color3.fromRGB(200, 50, 50),
}

--// Core Setup
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "HiddenMenu"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.Parent         = uiParent

local mainFrame = Instance.new("Frame")
mainFrame.Size             = UDim2.new(0, 500, 0, 350)
mainFrame.Position         = UDim2.new(0.5, -250, 0.5, -175)
mainFrame.BackgroundColor3 = Theme.Background
mainFrame.BorderSizePixel  = 0
mainFrame.Parent           = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

--// Top Bar
local topBar = Instance.new("Frame")
topBar.Size             = UDim2.new(1, 0, 0, 40)
topBar.BackgroundColor3 = Theme.TopBar
topBar.Parent           = mainFrame
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)

local topFix = Instance.new("Frame")
topFix.Size             = UDim2.new(1, 0, 0, 10)
topFix.Position         = UDim2.new(0, 0, 1, -10)
topFix.BackgroundColor3 = Theme.TopBar
topFix.Parent           = topBar

local title = Instance.new("TextLabel")
title.Size                   = UDim2.new(1, -20, 1, 0)
title.Position               = UDim2.new(0, 15, 0, 0)
title.BackgroundTransparency = 1
title.Text                   = "LOCAL PANEL"
title.TextColor3             = Theme.Text
title.Font                   = Enum.Font.GothamBold
title.TextSize               = 16
title.TextXAlignment         = Enum.TextXAlignment.Left
title.Parent                 = topBar

--// Sidebar
local sidebar = Instance.new("Frame")
sidebar.Size             = UDim2.new(0, 130, 1, -40)
sidebar.Position         = UDim2.new(0, 0, 0, 40)
sidebar.BackgroundColor3 = Theme.Sidebar
sidebar.Parent           = mainFrame

local sidebarLayout = Instance.new("UIListLayout", sidebar)
sidebarLayout.Padding              = UDim.new(0, 5)
sidebarLayout.HorizontalAlignment  = Enum.HorizontalAlignment.Center

--// Content Area
local contentArea = Instance.new("Frame")
contentArea.Size                 = UDim2.new(1, -140, 1, -50)
contentArea.Position             = UDim2.new(0, 135, 0, 45)
contentArea.BackgroundTransparency = 1
contentArea.Parent               = mainFrame

local pages = {}

local function createTab(name)
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(0.9, 0, 0, 35)
    btn.BackgroundColor3 = Theme.Button
    btn.Text             = name
    btn.TextColor3       = Theme.SubText
    btn.Font             = Enum.Font.GothamSemibold
    btn.TextSize         = 14
    btn.Parent           = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local page = Instance.new("ScrollingFrame")
    page.Size                = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel     = 0
    page.ScrollBarThickness  = 4
    page.Visible             = false
    page.Parent              = contentArea
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize          = UDim2.new(0, 0, 0, 0)

    Instance.new("UIListLayout", page).Padding = UDim.new(0, 8)
    pages[name] = { Button = btn, Page = page }

    btn.MouseButton1Click:Connect(function()
        for _, data in pairs(pages) do
            data.Page.Visible          = false
            data.Button.BackgroundColor3 = Theme.Button
            data.Button.TextColor3       = Theme.SubText
        end
        page.Visible             = true
        btn.BackgroundColor3     = Theme.Accent
        btn.TextColor3           = Theme.Text
    end)
    return page
end

local mainPage  = createTab("Main")
local adminPage = createTab("Admin")

pages["Main"].Button.BackgroundColor3 = Theme.Accent
pages["Main"].Button.TextColor3       = Theme.Text
mainPage.Visible = true

---------------------------------------------------------
-- UI ELEMENT HELPERS
---------------------------------------------------------
local infJumpConn, noclipConn, flyConn, clickTpConn
local isFlying = false

local function createToggle(parent, text, callback)
    local holder = Instance.new("Frame")
    holder.Size             = UDim2.new(1, -10, 0, 40)
    holder.BackgroundColor3 = Theme.Button
    holder.Parent           = parent
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel")
    label.Size                   = UDim2.new(1, -60, 1, 0)
    label.Position               = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text                   = text
    label.TextColor3             = Theme.Text
    label.Font                   = Enum.Font.Gotham
    label.TextSize               = 14
    label.TextXAlignment         = Enum.TextXAlignment.Left
    label.Parent                 = holder

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size             = UDim2.new(0, 40, 0, 20)
    toggleBtn.Position         = UDim2.new(1, -50, 0.5, -10)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(100, 30, 30)
    toggleBtn.Text             = ""
    toggleBtn.Parent           = holder
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)

    local state = false
    toggleBtn.MouseButton1Click:Connect(function()
        state = not state
        toggleBtn.BackgroundColor3 = state and Color3.fromRGB(30, 100, 30) or Color3.fromRGB(100, 30, 30)
        callback(state)
    end)
end

local function createButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(1, -10, 0, 40)
    btn.BackgroundColor3 = Theme.Button
    btn.Text             = text
    btn.TextColor3       = Theme.Text
    btn.Font             = Enum.Font.Gotham
    btn.TextSize         = 14
    btn.Parent           = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    btn.MouseButton1Click:Connect(function()
        callback()
    end)
end

---------------------------------------------------------
-- MAIN TAB — LOCAL MODS
---------------------------------------------------------

-- 1. Infinite Jump
createToggle(mainPage, "Infinite Jump", function(state)
    if state then
        infJumpConn = UserInputService.JumpRequest:Connect(function()
            local char = player.Character
            if char and char:FindFirstChild("Humanoid") then
                char.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    else
        if infJumpConn then infJumpConn:Disconnect() infJumpConn = nil end
    end
end)

-- 2. Noclip
createToggle(mainPage, "Noclip (Walk through walls)", function(state)
    if state then
        noclipConn = RunService.Stepped:Connect(function()
            local char = player.Character
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    end
end)

-- 3. Fly
createToggle(mainPage, "Fly (W A S D)", function(state)
    isFlying = state
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hrp = char.HumanoidRootPart

    if state then
        local bv = Instance.new("BodyVelocity")
        bv.Name     = "FlyVelocity"
        bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.Parent   = hrp

        flyConn = RunService.RenderStepped:Connect(function()
            local cam        = workspace.CurrentCamera
            local moveVector = Vector3.new(0, 0, 0)

            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector = moveVector + cam.CFrame.LookVector  end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector = moveVector - cam.CFrame.LookVector  end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector = moveVector - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector = moveVector + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space)        then moveVector = moveVector + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)  then moveVector = moveVector - Vector3.new(0, 1, 0) end

            if bv and bv.Parent then
                bv.Velocity = moveVector * 100
            end
        end)
    else
        if flyConn then flyConn:Disconnect() flyConn = nil end
        if hrp:FindFirstChild("FlyVelocity") then hrp.FlyVelocity:Destroy() end
    end
end)

-- 4. Click Teleport (fixed: connection is properly cleaned up)
local mouse = player:GetMouse()
createToggle(mainPage, "Click Teleport (Mouse)", function(state)
    if state then
        clickTpConn = mouse.Button1Down:Connect(function()
            local char = player.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
            end
        end)
    else
        if clickTpConn then clickTpConn:Disconnect() clickTpConn = nil end
    end
end)

-- 5. Fullbright
createToggle(mainPage, "Fullbright (Remove Shadows)", function(state)
    if state then
        Lighting.Brightness    = 2
        Lighting.ClockTime     = 14
        Lighting.FogEnd        = 100000
        Lighting.GlobalShadows = false
        Lighting.Ambient       = Color3.fromRGB(178, 178, 178)
    else
        Lighting.Brightness    = 1
        Lighting.ClockTime     = 0
        Lighting.FogEnd        = 100
        Lighting.GlobalShadows = true
        Lighting.Ambient       = Color3.fromRGB(0, 0, 0)
    end
end)

-- 6. Sliders
local function createSlider(parent, text, min, max, default, callback)
    local holder = Instance.new("Frame")
    holder.Size             = UDim2.new(1, -10, 0, 50)
    holder.BackgroundColor3 = Theme.Button
    holder.Parent           = parent
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel")
    label.Size                   = UDim2.new(1, -20, 0, 20)
    label.Position               = UDim2.new(0, 10, 0, 5)
    label.BackgroundTransparency = 1
    label.Text                   = text .. ": " .. default
    label.TextColor3             = Theme.Text
    label.Font                   = Enum.Font.Gotham
    label.TextSize               = 14
    label.TextXAlignment         = Enum.TextXAlignment.Left
    label.Parent                 = holder

    local bar = Instance.new("Frame")
    bar.Size             = UDim2.new(1, -20, 0, 10)
    bar.Position         = UDim2.new(0, 10, 0, 30)
    bar.BackgroundColor3 = Theme.Background
    bar.Parent           = holder
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size             = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.Parent           = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local dragging = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local relX = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            fill.Size = UDim2.new(relX, 0, 1, 0)
            local val = math.floor(min + (max - min) * relX)
            label.Text = text .. ": " .. val
            callback(val)
        end
    end)
end

createSlider(mainPage, "WalkSpeed", 16, 500, 16, function(val)
    local char = player.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.WalkSpeed = val
    end
end)

createSlider(mainPage, "Jump Power", 50, 500, 50, function(val)
    local char = player.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.UseJumpPower = true
        char.Humanoid.JumpPower    = val
    end
end)

---------------------------------------------------------
-- ADMIN TAB — REMOTE ACTIONS
---------------------------------------------------------
local selectedPlayer = nil

-- "Selected: X" header
local selectedLabel = Instance.new("TextLabel")
selectedLabel.Size             = UDim2.new(1, -10, 0, 25)
selectedLabel.BackgroundTransparency = 1
selectedLabel.Text             = "Selected: None"
selectedLabel.TextColor3       = Theme.Accent
selectedLabel.Font             = Enum.Font.GothamSemibold
selectedLabel.TextSize         = 13
selectedLabel.TextXAlignment   = Enum.TextXAlignment.Left
selectedLabel.Parent           = adminPage

-- Player list
local listFrame = Instance.new("ScrollingFrame")
listFrame.Size               = UDim2.new(1, -10, 0, 130)
listFrame.BackgroundColor3   = Theme.Button
listFrame.BorderSizePixel    = 0
listFrame.ScrollBarThickness = 4
listFrame.CanvasSize         = UDim2.new(0, 0, 0, 0)
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.Parent             = adminPage
Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 6)

local listLayout = Instance.new("UIListLayout", listFrame)
listLayout.Padding = UDim.new(0, 4)

local listPadding = Instance.new("UIPadding", listFrame)
listPadding.PaddingTop    = UDim.new(0, 4)
listPadding.PaddingBottom = UDim.new(0, 4)
listPadding.PaddingLeft   = UDim.new(0, 4)
listPadding.PaddingRight  = UDim.new(0, 4)

local function refreshPlayerList()
    for _, child in ipairs(listFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        local btn = Instance.new("TextButton")
        btn.Size             = UDim2.new(1, 0, 0, 28)
        btn.BackgroundColor3 = Theme.Background
        btn.Text             = plr.Name .. (plr == player and " (You)" or "")
        btn.TextColor3       = Theme.Text
        btn.Font             = Enum.Font.Gotham
        btn.TextSize         = 13
        btn.Parent           = listFrame
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

        btn.MouseButton1Click:Connect(function()
            selectedPlayer       = plr
            selectedLabel.Text   = "Selected: " .. plr.Name
        end)
    end
end

refreshPlayerList()
Players.PlayerAdded:Connect(refreshPlayerList)
Players.PlayerRemoving:Connect(function()
    task.wait()
    refreshPlayerList()
end)

local function fireAdmin(action)
    if not adminRemote then
        warn("[Panel] AdminAction remote not found.")
        return
    end
    if not selectedPlayer then
        warn("[Panel] No player selected.")
        return
    end
    adminRemote:FireServer(action, selectedPlayer)
end

createButton(adminPage, "Kick",              function() fireAdmin("Kick")       end)
createButton(adminPage, "Kill",              function() fireAdmin("Kill")       end)
createButton(adminPage, "Freeze / Unfreeze", function() fireAdmin("Freeze")     end)
createButton(adminPage, "Teleport To",       function() fireAdmin("TeleportTo") end)

---------------------------------------------------------
-- DRAG & KEYBIND
---------------------------------------------------------
local dragging, dragStart, startPos

topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging  = true
        dragStart = input.Position
        startPos  = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.P then
        mainFrame.Visible = not mainFrame.Visible
    end
end)

print("UI Loaded Successfully! Press P to toggle.")
