-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 1. Create the ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CustomModMenu"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- 2. Create the Main Panel (Frame)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainPanel"
mainFrame.Size = UDim2.new(0, 300, 0, 400)
mainFrame.Position = UDim2.new(0.5, -150, 0.5, -200) -- Center of screen
mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui

-- Add rounded corners to the main panel
local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = mainFrame

-- 3. Create the Title Bar
local titleBar = Instance.new("TextLabel")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
titleBar.BorderSizePixel = 0
titleBar.Text = " Admin Panel"
titleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
titleBar.Font = Enum.Font.SourceSansBold
titleBar.TextSize = 20
titleBar.TextXAlignment = Enum.TextXAlignment.Left
titleBar.Parent = mainFrame

-- Round the top corners of the title bar
local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleBar

-- 4. Create a Close Button
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 40, 0, 40)
closeButton.Position = UDim2.new(1, -40, 0, 0)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Font = Enum.Font.SourceSansBold
closeButton.TextSize = 20
closeButton.Parent = titleBar

-- 5. Create an Open Button (for when the panel is closed)
local openButton = Instance.new("TextButton")
openButton.Name = "OpenButton"
openButton.Size = UDim2.new(0, 120, 0, 40)
openButton.Position = UDim2.new(0, 10, 0, 10)
openButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
openButton.Text = "Open Menu"
openButton.TextColor3 = Color3.fromRGB(255, 255, 255)
openButton.Font = Enum.Font.SourceSansBold
openButton.TextSize = 18
openButton.Visible = false
openButton.Parent = screenGui

local openCorner = Instance.new("UICorner")
openCorner.CornerRadius = UDim.new(0, 6)
openCorner.Parent = openButton

-- 6. Create a Content Container (for your buttons/sliders)
local contentArea = Instance.new("Frame")
contentArea.Name = "ContentArea"
contentArea.Size = UDim2.new(1, -20, 1, -60)
contentArea.Position = UDim2.new(0, 10, 0, 50)
contentArea.BackgroundTransparency = 1
contentArea.Parent = mainFrame

-- Example Button 1: Print to Console
local actionButton1 = Instance.new("TextButton")
actionButton1.Size = UDim2.new(1, 0, 0, 40)
actionButton1.Position = UDim2.new(0, 0, 0, 10)
actionButton1.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
actionButton1.Text = "Print Hello World"
actionButton1.TextColor3 = Color3.fromRGB(255, 255, 255)
actionButton1.Font = Enum.Font.SourceSans
actionButton1.TextSize = 18
actionButton1.Parent = contentArea

local btn1Corner = Instance.new("UICorner")
btn1Corner.CornerRadius = UDim.new(0, 6)
btn1Corner.Parent = actionButton1

-- Example Button 2: Change UI Theme
local actionButton2 = Instance.new("TextButton")
actionButton2.Size = UDim2.new(1, 0, 0, 40)
actionButton2.Position = UDim2.new(0, 0, 0, 60)
actionButton2.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
actionButton2.Text = "Toggle Dark/Light Theme"
actionButton2.TextColor3 = Color3.fromRGB(255, 255, 255)
actionButton2.Font = Enum.Font.SourceSans
actionButton2.TextSize = 18
actionButton2.Parent = contentArea

local btn2Corner = Instance.new("UICorner")
btn2Corner.CornerRadius = UDim.new(0, 6)
btn2Corner.Parent = actionButton2

---------------------------------------------------------
-- LOGIC & FUNCTIONALITY
---------------------------------------------------------

-- Toggle Menu Visibility
local function toggleMenu(isOpen)
    mainFrame.Visible = isOpen
    openButton.Visible = not isOpen
end

closeButton.MouseButton1Click:Connect(function()
    toggleMenu(false)
end)

openButton.MouseButton1Click:Connect(function()
    toggleMenu(true)
end)

-- Example Button 1 Logic
actionButton1.MouseButton1Click:Connect(function()
    print("Hello World! Button clicked.")
end)

-- Example Button 2 Logic
local isDarkMode = true
actionButton2.MouseButton1Click:Connect(function()
    isDarkMode = not isDarkMode
    if isDarkMode then
        mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    else
        mainFrame.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
        titleBar.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    end
end)

-- Draggable Panel Logic
local dragging
local dragInput
local dragStart
local startPos

local function update(input)
    local delta = input.Position - dragStart
    mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)
