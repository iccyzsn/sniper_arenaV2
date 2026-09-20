local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

--// Hide UI from Anti-Cheat
-- gethui() is a special executor function. If it doesn't exist, we use CoreGui.
local uiParent = (gethui and gethui()) or CoreGui

-- Remove old UI if it exists
if uiParent:FindFirstChild("HiddenMenu") then
    uiParent.HiddenMenu:Destroy()
end

--// Theme
local Theme = {
    Background = Color3.fromRGB(30, 30, 35),
    Sidebar = Color3.fromRGB(25, 25, 30),
    TopBar = Color3.fromRGB(20, 20, 25),
    Button = Color3.fromRGB(45, 45, 55),
    Accent = Color3.fromRGB(0, 162, 255),
    Text = Color3.fromRGB(255, 255, 255),
    SubText = Color3.fromRGB(150, 150, 150),
    Danger = Color3.fromRGB(200, 50, 50)
}

--// Core Setup
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HiddenMenu"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true -- Prevents it from hiding behind the top bar
screenGui.Parent = uiParent -- Hidden inside CoreGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 500, 0, 350)
mainFrame.Position = UDim2.new(0.5, -250, 0.5, -175)
mainFrame.BackgroundColor3 = Theme.Background
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

--// Top Bar
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 40)
topBar.BackgroundColor3 = Theme.TopBar
topBar.Parent = mainFrame
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)

local topFix = Instance.new("Frame")
topFix.Size = UDim2.new(1, 0, 0, 10)
topFix.Position = UDim2.new(0, 0, 1, -10)
topFix.BackgroundColor3 = Theme.TopBar
topFix.Parent = topBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 1, 0)
title.Position = UDim2.new(0, 15, 0, 0)
title.BackgroundTransparency = 1
title.Text = "LOCAL PANEL"
title.TextColor3 = Theme.Text
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

--// Sidebar
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 130, 1, -40)
sidebar.Position = UDim2.new(0, 0, 0, 40)
sidebar.BackgroundColor3 = Theme.Sidebar
sidebar.Parent = mainFrame

local sidebarLayout = Instance.new("UIListLayout", sidebar)
sidebarLayout.Padding = UDim.new(0, 5)
sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

--// Content Area
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -140, 1, -50)
contentArea.Position = UDim2.new(0, 135, 0, 45)
contentArea.BackgroundTransparency = 1
contentArea.Parent = mainFrame

local pages = {}

local function createTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 35)
    btn.BackgroundColor3 = Theme.Button
    btn.Text = name
    btn.TextColor3 = Theme.SubText
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 14
    btn.Parent = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.Visible = false
    page.Parent = contentArea

    Instance.new("UIListLayout", page).Padding = UDim.new(0, 8)
    pages[name] = {Button = btn, Page = page}

    btn.MouseButton1Click:Connect(function()
        for _, data in pairs(pages) do
            data.Page.Visible = false
            data.Button.BackgroundColor3 = Theme.Button
            data.Button.TextColor3 = Theme.SubText
        end
        page.Visible = true
        btn.BackgroundColor3 = Theme.Accent
        btn.TextColor3 = Theme.Text
    end)
    return page
end

local mainPage = createTab("Local")
local playersPage = createTab("Players")

pages["Local"].Button.BackgroundColor3 = Theme.Accent
pages["Local"].Button.TextColor3 = Theme.Text
mainPage.Visible = true

---------------------------------------------------------
-- UI ELEMENTS
---------------------------------------------------------
local infJumpConn = nil

local function createToggle(parent, text, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -10, 0, 40)
    holder.BackgroundColor3 = Theme.Button
    holder.Parent = parent
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Theme.Text
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = holder

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 40, 0, 20)
    toggleBtn.Position = UDim2.new(1, -50, 0.5, -10)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(100, 30, 30)
    toggleBtn.Text = ""
    toggleBtn.Parent = holder
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)

    local state = false
    toggleBtn.MouseButton1Click:Connect(function()
        state = not state
        toggleBtn.BackgroundColor3 = state and Color3.fromRGB(30, 100, 30) or Color3.fromRGB(100, 30, 30)
        callback(state)
    end)
end

local function createSlider(parent, text, min, max, default, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -10, 0, 50)
    holder.BackgroundColor3 = Theme.Button
    holder.Parent = parent
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 20)
    label.Position = UDim2.new(0, 10, 0, 5)
    label.BackgroundTransparency = 1
    label.Text = text .. ": " .. default
    label.TextColor3 = Theme.Text
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = holder

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -20, 0, 10)
    bar.Position = UDim2.new(0, 10, 0, 30)
    bar.BackgroundColor3 = Theme.Background
    bar.Parent = holder
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local dragging = false
    bar.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end end)
    UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
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

---------------------------------------------------------
-- POPULATE MENU
---------------------------------------------------------
createToggle(mainPage, "Infinite Jump", function(state)
    if state then
        infJumpConn = UserInputService.JumpRequest:Connect(function()
            local char = player.Character
            if char and char:FindFirstChild("Humanoid") then
                char.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    else
        if infJumpConn then
            infJumpConn:Disconnect()
            infJumpConn = nil
        end
    end
end)

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
        char.Humanoid.JumpPower = val
    end
end)

-- Just list players for visual purposes
local function updatePlayerList()
    for _, child in pairs(playersPage:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    for _, p in pairs(Players:GetPlayers()) do
        local pLabel = Instance.new("TextLabel")
        pLabel.Size = UDim2.new(1, -10, 0, 30)
        pLabel.BackgroundColor3 = Theme.Button
        pLabel.Text = " " .. p.Name
        pLabel.TextColor3 = Theme.Text
        pLabel.Font = Enum.Font.Gotham
        pLabel.TextSize = 14
        pLabel.TextXAlignment = Enum.TextXAlignment.Left
        pLabel.Parent = playersPage
        Instance.new("UICorner", pLabel).CornerRadius = UDim.new(0, 6)
    end
end

Players.PlayerAdded:Connect(updatePlayerList)
Players.PlayerRemoving:Connect(updatePlayerList)
updatePlayerList()

---------------------------------------------------------
-- DRAG & KEYBIND
---------------------------------------------------------
local dragging, dragInput, dragStart, startPos

topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.P then
        mainFrame.Visible = not mainFrame.Visible
    end
end)

print("UI Loaded Successfully! Press P to toggle.")
