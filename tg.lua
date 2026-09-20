--!nocheck
--[[
    DEX REContinued — Telegram Export Extension
    -------------------------------------------
    Right-click any instance in DEX → "Send to Telegram".
    Or use the small floating panel to Pick from World / Send current selection.

    SETUP:
      1. Create a bot with @BotFather  -> get BOT TOKEN
      2. Get your chat id: message @userinfobot -> it replies with your id
      3. Fill CONFIG.BotToken / CONFIG.ChatId below
      4. Run this AFTER DEX REContinued has loaded
]]


local CONFIG = {
    BotToken = "8305869255:AAEqIdORQUnQgg82LKbVwsj6Rzpfow0tKqo",            -- "123456789:AAaaAAaa..."
    ChatId   = "5798404109",            -- "123456789" or "-1001234567890" for groups/channels
    MaxDepth          = 4,    -- recursion depth when dumping children
    MaxChildren       = 150,  -- max children dumped per node
    IncludeScripts    = true, -- dump Lua source if instance is a script
    IncludeHidden     = true, -- include hidden properties (gethiddenproperty)
    IncludeAttributes = true,
    IncludeTags       = true,
    IncludeChildTree  = true,
    MaxPropsPerInst   = 40,
    ChunkSize         = 3800, -- TG limit is 4096, leave headroom
    Silent            = false,
}

-- ============================================================
-- Executor HTTP
-- ============================================================
local httpRequest =
    (syn and syn.request)
    or (http and http.request)
    or http_request
    or request
    or (fluxus and fluxus.request)
    or (krnl and krnl.request)
    or (request == nil and (function() return nil end)) -- placeholder

if not httpRequest then
    warn("[TG-Export] No HTTP request function on this executor.")
end

local HttpService      = cloneref and cloneref(game:GetService("HttpService"))      or game:GetService("HttpService")
local UserInputService = cloneref and cloneref(game:GetService("UserInputService")) or game:GetService("UserInputService")
local Players          = cloneref and cloneref(game:GetService("Players"))          or game:GetService("Players")
local CollectionService= cloneref and cloneref(game:GetService("CollectionService"))or game:GetService("CollectionService")
local RunService       = cloneref and cloneref(game:GetService("RunService"))       or game:GetService("RunService")

-- ============================================================
-- Helpers
-- ============================================================
local function esc(s)
    return (tostring(s):gsub("[&<>]", { ["&"]="&amp;", ["<"]="&lt;", [">"]="&gt;" }))
end

local function valToStr(v)
    local t = typeof(v)
    if t == "string" then
        return '"' .. v:gsub('"', '\\"') .. '"'
    elseif t == "Instance" then
        return "<" .. v.ClassName .. "> " .. v.Name
    elseif t == "Color3" then
        return string.format("Color3(%d, %d, %d)", math.round(v.R*255), math.round(v.G*255), math.round(v.B*255))
    elseif t == "Vector3" then
        return string.format("Vector3(%g, %g, %g)", v.X, v.Y, v.Z)
    elseif t == "Vector2" then
        return string.format("Vector2(%g, %g)", v.X, v.Y)
    elseif t == "UDim2" then
        return tostring(v)
    elseif t == "UDim" then
        return tostring(v)
    elseif t == "CFrame" then
        return tostring(v)
    elseif t == "EnumItem" then
        return tostring(v)
    elseif t == "BrickColor" then
        return "BrickColor(" .. v.Name .. ")"
    end
    return tostring(v)
end

local function getPath(obj)
    if not obj then return "nil" end
    if obj == game then return "game" end
    local parts = {}
    local cur = obj
    while cur and cur ~= game do
        local name = cur.Name
        local parent = cur.Parent
        if parent and parent:FindFirstChild(name) == cur then
            if name:match("^[%a_][%w_]*$") then
                table.insert(parts, 1, "." .. name)
            else
                table.insert(parts, 1, '["' .. name:gsub('"', '\\"') .. '"]')
            end
        elseif parent then
            local idx = 1
            for i, c in ipairs(parent:GetChildren()) do
                if c == cur then idx = i break end
            end
            table.insert(parts, 1, ":GetChildren()[" .. idx .. "]")
        else
            table.insert(parts, 1, "<nil:" .. name .. ">")
        end
        cur = parent
    end
    return "game" .. table.concat(parts)
end

-- ============================================================
-- Property / attribute / tag collectors
-- ============================================================
local COMMON_PROPS = {
    "Name","ClassName","Archivable",
    "Position","CFrame","Size","Rotation","Orientation","PivotOffset",
    "Color","BrickColor","Material","Transparency","Reflectance",
    "Anchored","CanCollide","CanTouch","CanQuery","Massless","Locked",
    "Shape","Velocity","AssemblyLinearVelocity","AssemblyAngularVelocity",
    "Value","Text","Image","Texture","SoundId","MeshId","TextureID",
    "Enabled","Visible","Active","Modal","AutoButtonColor",
    "Source","RunContext","Disabled","Enabled",
    "WalkSpeed","JumpPower","JumpHeight","Health","MaxHealth","HipHeight",
    "Team","TeamColor","UserId","DisplayName",
    "Brightness","Ambient","OutdoorAmbient","ClockTime","GlobalShadows",
    "Firing","Fire","Heat","Velocity",
    "Density","Friction","Elasticity","FrictionWeight","ElasticityWeight",
    "Level","Gravity","FogEnd","FogStart","FogColor",
    "CameraType","CameraSubject","FieldOfView",
    "TimePosition","Volume","Loop","Playing","PlaybackSpeed",
    "AutoPlay","PlayOnRemove","RollOffMode",
    "LocalPlayer","Character","PlayerGui","Backpack","PlayerScripts",
    "GameId","PlaceId","PlaceVersion","Workspace",
    "IsStudio","PrivateServerId","CreatorId","CreatorType",
    "PrimaryPart","WorldPivot","ModelStreamingMode",
    "AnimationId","Speed","Weight",
    "CursorIcon","MaxActivationDistance","ActionText","ObjectText",
    "HoldDuration","KeyboardKeyCode","RequiresLineOfSight","Style",
    "Adornee","AlwaysOnTop","LightInfluence","MaxDistance","Face",
    "LineThickness","SurfaceColor3","SurfaceTransparency",
    "Lifetime","Rate","Speed","Drag","Acceleration","SpreadAngle",
    "EmissionDirection","Squash","LightEmission","LightInfluence",
    "Mode","Face","Sizing",
}

local function collectProperties(inst, maxProps)
    local out, count, used = {}, 0, {}
    local hiddenProps = {}
    if CONFIG.IncludeHidden and gethiddenproperty then
        -- nothing to enumerate upfront; we try per prop
    end

    -- Try getproperties if executor supports it
    if getproperties then
        local ok, props = pcall(getproperties, inst)
        if ok and type(props) == "table" then
            local keys = {}
            for k in pairs(props) do keys[#keys+1] = k end
            table.sort(keys)
            for _, k in ipairs(keys) do
                if count >= maxProps then break end
                if not used[k] then
                    used[k] = true
                    local v = props[k]
                    if typeof(v) ~= "function" then
                        count = count + 1
                        out[#out+1] = { name = k, value = v }
                    end
                end
            end
            return out
        end
    end

    -- Fallback: try common list
    for _, k in ipairs(COMMON_PROPS) do
        if count >= maxProps then break end
        if not used[k] then
            used[k] = true
            local ok, v = pcall(function() return inst[k] end)
            if not ok and CONFIG.IncludeHidden and gethiddenproperty then
                local ok2, hv = pcall(gethiddenproperty, inst, k)
                if ok2 and hv ~= nil then ok, v = true, hv end
            end
            if ok and v ~= nil and typeof(v) ~= "function" then
                count = count + 1
                out[#out+1] = { name = k, value = v }
            end
        end
    end
    return out
end

local function collectAttributes(inst)
    local out = {}
    local ok, attrs = pcall(function() return inst:GetAttributes() end)
    if ok and type(attrs) == "table" then
        for k, v in pairs(attrs) do
            out[#out+1] = { name = k, value = v }
        end
    end
    return out
end

local function collectTags(inst)
    local out = {}
    local ok, tags = pcall(function() return CollectionService:GetTags(inst) end)
    if ok and type(tags) == "table" then
        for _, t in ipairs(tags) do out[#out+1] = t end
    end
    return out
end

local function collectSource(inst)
    if not CONFIG.IncludeScripts then return nil end
    if not inst:IsA("LuaSourceContainer") then return nil end
    if typeof(decompile) ~= "function" then return nil end
    local ok, src = pcall(decompile, inst)
    if ok and type(src) == "string" and #src > 0 then return src end
    return nil
end

-- ============================================================
-- Markdown/HTML builders
-- ============================================================
local function childrenTree(inst, depth, maxDepth, maxChildren, prefix)
    if depth > maxDepth then return "" end
    local children = inst:GetChildren()
    local n = #children
    local shown = math.min(n, maxChildren)
    local lines = {}
    for i = 1, shown do
        local c = children[i]
        local last = (i == shown and n <= maxChildren)
        local branch = last and "└── " or "├── "
        lines[#lines+1] = prefix .. branch .. c.Name .. "  [" .. c.ClassName .. "]"
        local np = prefix .. (last and "    " or "│   ")
        local sub = childrenTree(c, depth+1, maxDepth, maxChildren, np)
        if sub ~= "" then lines[#lines+1] = sub end
    end
    if n > maxChildren then
        lines[#lines+1] = prefix .. "└── … " .. (n - maxChildren) .. " more"
    end
    return table.concat(lines, "\n")
end

local function buildInstanceChunk(inst)
    local parts = {}
    parts[#parts+1] = "<b>📦 " .. esc(inst.ClassName) .. "</b>  <code>" .. esc(inst.Name) .. "</code>"
    parts[#parts+1] = "<i>Path:</i> <code>" .. esc(getPath(inst)) .. "</code>"

    -- Properties
    local props = collectProperties(inst, CONFIG.MaxPropsPerInst)
    if #props > 0 then
        local lines = {}
        for _, p in ipairs(props) do
            lines[#lines+1] = p.name .. " = " .. valToStr(p.value)
        end
        parts[#parts+1] = "<b>🔑 Properties (" .. #props .. ")</b>\n<pre>" .. esc(table.concat(lines, "\n")) .. "</pre>"
    end

    -- Attributes
    if CONFIG.IncludeAttributes then
        local attrs = collectAttributes(inst)
        if #attrs > 0 then
            local lines = {}
            for _, a in ipairs(attrs) do
                lines[#lines+1] = a.name .. " = " .. valToStr(a.value)
            end
            parts[#parts+1] = "<b>🏷️ Attributes (" .. #attrs .. ")</b>\n<pre>" .. esc(table.concat(lines, "\n")) .. "</pre>"
        end
    end

    -- Tags
    if CONFIG.IncludeTags then
        local tags = collectTags(inst)
        if #tags > 0 then
            parts[#parts+1] = "<b>🔖 Tags</b>\n<code>" .. esc(table.concat(tags, ", ")) .. "</code>"
        end
    end

    -- Children tree
    if CONFIG.IncludeChildTree then
        local tree = childrenTree(inst, 1, CONFIG.MaxDepth, CONFIG.MaxChildren, "")
        local count = #inst:GetChildren()
        if count > 0 then
            parts[#parts+1] = "<b>👶 Children (" .. count .. ")</b>\n<pre>" .. esc(tree) .. "</pre>"
        end
    end

    -- Script source
    local src = collectSource(inst)
    if src then
        -- truncate very large sources so we don't blow up TG
        if #src > 12000 then
            src = src:sub(1, 12000) .. "\n\n-- …truncated (" .. (#src - 12000) .. " more chars)"
        end
        parts[#parts+1] = "<b>📜 Script Source</b>\n<pre>" .. esc(src) .. "</pre>"
    end

    return table.concat(parts, "\n\n")
end

-- ============================================================
-- Telegram sender
-- ============================================================
local function chunkMessage(msg, max)
    max = max or CONFIG.ChunkSize
    local chunks, current = {}, ""
    for para in (msg .. "\n\n"):gmatch("(.-)\n\n") do
        if #current + #para + 2 > max then
            if #current > 0 then
                chunks[#chunks+1] = current
                current = ""
            end
            while #para > max do
                chunks[#chunks+1] = para:sub(1, max)
                para = para:sub(max+1)
            end
        end
        current = (#current > 0) and (current .. "\n\n" .. para) or para
    end
    if #current > 0 then chunks[#chunks+1] = current end
    return chunks
end

local function tgSend(text)
    if not CONFIG.BotToken or CONFIG.BotToken == "" then
        return false, "BotToken is empty"
    end
    if not CONFIG.ChatId or CONFIG.ChatId == "" then
        return false, "ChatId is empty"
    end

    local url = "https://api.telegram.org/bot" .. CONFIG.BotToken .. "/sendMessage"
    local body = HttpService:JSONEncode({
        chat_id = CONFIG.ChatId,
        text = text,
        parse_mode = "HTML",
        disable_web_page_preview = true,
    })
    local ok, res = pcall(httpRequest, {
        Url = url,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = body,
    })
    if not ok then return false, tostring(res) end
    if not res or not res.Body then return false, "no response" end
    if res.StatusCode and res.StatusCode ~= 200 then
        return false, "HTTP " .. res.StatusCode .. " " .. tostring(res.Body)
    end
    return true
end

local function sendChunked(fullText)
    local chunks = chunkMessage(fullText, CONFIG.ChunkSize)
    local total = #chunks
    for i, chunk in ipairs(chunks) do
        if total > 1 then
            chunk = chunk .. "\n\n<i>— part " .. i .. "/" .. total .. " —</i>"
        end
        local ok, err = tgSend(chunk)
        if not ok then
            warn("[TG-Export] Failed chunk " .. i .. ": " .. tostring(err))
            return false, err
        end
        if i < total then task.wait(0.35) end -- rate-limit friendly
    end
    return true
end

-- ============================================================
-- Toast notifications
-- ============================================================
local toastGui, toastLabel
local function toast(msg, isError)
    if not toastGui then
        local sg = Instance.new("ScreenGui")
        sg.Name = "DEXTGToast"
        sg.IgnoreGuiInset = true
        sg.ResetOnSpawn = false
        sg.DisplayOrder = 1e6
        if gethui then pcall(function() sg.Parent = gethui() end)
        else sg.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end
        if syn and syn.protect_gui then pcall(syn.protect_gui, sg) end
        toastGui = sg
        toastLabel = Instance.new("TextLabel", sg)
        toastLabel.AnchorPoint = Vector2.new(0.5, 0)
        toastLabel.Position = UDim2.new(0.5, 0, 0, 20)
        toastLabel.Size = UDim2.new(0, 380, 0, 30)
        toastLabel.BackgroundColor3 = Color3.fromRGB(30,30,30)
        toastLabel.TextColor3 = Color3.fromRGB(240,240,240)
        toastLabel.TextStrokeTransparency = 0.6
        toastLabel.Font = Enum.Font.Gotham
        toastLabel.TextSize = 14
        toastLabel.TextWrapped = true
        toastLabel.Visible = false
        local corner = Instance.new("UICorner", toastLabel)
        corner.CornerRadius = UDim.new(0, 6)
        local stroke = Instance.new("UIStroke", toastLabel)
        stroke.Thickness = 1
        stroke.Color = Color3.fromRGB(60,60,60)
    end
    toastLabel.Text = msg
    toastLabel.BackgroundColor3 = isError and Color3.fromRGB(90,25,25) or Color3.fromRGB(25,60,35)
    toastLabel.Visible = true
    toastLabel.TextTransparency = 0
    toastLabel.BackgroundTransparency = 0
    task.delay(3, function()
        for i = 1, 20 do
            toastLabel.TextTransparency = i / 20
            toastLabel.BackgroundTransparency = i / 20
            task.wait(0.03)
        end
        toastLabel.Visible = false
    end)
end

-- ============================================================
-- Public API
-- ============================================================
local function sendInstances(instances)
    if type(instances) ~= "table" or #instances == 0 then
        toast("[TG-Export] Nothing selected.", true)
        return
    end
    toast("[TG-Export] Building dump…")
    task.spawn(function()
        local chunks = {}
        local header = "<b>🧩 DEX REContinued Export</b>\n<i>Place:</i> <code>" .. esc(tostring(game.PlaceId)) .. "</code>\n<i>Count:</i> " .. #instances
        chunks[#chunks+1] = header
        for i, inst in ipairs(instances) do
            if typeof(inst) == "Instance" then
                chunks[#chunks+1] = "━━━━━━━━━━━━━━━━━━━━\n" .. buildInstanceChunk(inst)
            end
            if i % 2 == 0 then task.wait() end
        end
        local full = table.concat(chunks, "\n\n")
        local ok, err = sendChunked(full)
        if ok then
            if not CONFIG.Silent then
                toast("[TG-Export] Sent " .. #instances .. " instance(s).")
            end
        else
            toast("[TG-Export] Failed: " .. tostring(err), true)
        end
    end)
end

_G.SendInstanceToTelegram = sendInstances

-- ============================================================
-- DEX hook — find Explorer table and inject context menu item
-- ============================================================
local function findExplorerTable()
    local getgc = getgc or get_gc_objects
    if not getgc then return nil end
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" then
            local sr  = rawget(v, "ShowRightClick")
            local ctx = rawget(v, "RightClickContext")
            local sel = rawget(v, "Selection")
            if sr and ctx and sel and type(sel) == "table" and rawget(sel, "List") then
                return v
            end
        end
    end
    return nil
end

local function hookDEX()
    local Explorer
    for i = 1, 120 do
        Explorer = findExplorerTable()
        if Explorer then break end
        task.wait(0.5)
    end
    if not Explorer then
        return false, "Could not find DEX Explorer table"
    end

    local ctx = rawget(Explorer, "RightClickContext")
    if not ctx then return false, "No RightClickContext" end

    local function onClick()
        local sList = Explorer.Selection.List
        local objs = {}
        for i = 1, #sList do
            local node = sList[i]
            if node and node.Obj then objs[#objs+1] = node.Obj end
        end
        sendInstances(objs)
    end

    -- Register our custom item
    pcall(function()
        ctx:Register("SEND_TO_TG", {
            Name = "Send to Telegram",
            Icon = "rbxassetid://113955252013201", -- paper-plane-ish; swap for anything you like
            OnClick = onClick,
        })
    end)

    -- Hook Show so our item is re-added after ShowRightClick clears the menu
    if not rawget(ctx, "__dextg_hooked") then
        rawset(ctx, "__dextg_hooked", true)
        local oldShow = ctx.Show  -- resolved from metatable on first read
        ctx.Show = function(self, x, y)
            if not self.Registered or not self.Registered["SEND_TO_TG"] then
                self:Register("SEND_TO_TG", {
                    Name = "Send to Telegram",
                    Icon = "rbxassetid://113955252013201",
                    OnClick = onClick,
                })
            end
            self:AddRegistered("SEND_TO_TG")
            return oldShow(self, x, y)
        end
    end

    return true, Explorer
end

-- ============================================================
-- Floating fallback panel
-- ============================================================
local function buildFallbackPanel()
    local pg = (gethui and gethui()) or Players.LocalPlayer:WaitForChild("PlayerGui")
    local sg = Instance.new("ScreenGui")
    sg.Name = "DEXTGPanel"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 5e5
    sg.Parent = pg
    if syn and syn.protect_gui then pcall(syn.protect_gui, sg) end

    local frame = Instance.new("Frame", sg)
    frame.Size = UDim2.new(0, 240, 0, 120)
    frame.Position = UDim2.new(0, 20, 0.5, -60)
    frame.BackgroundColor3 = Color3.fromRGB(28,28,28)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true

    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(60,60,60)
    stroke.Thickness = 1

    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, -30, 0, 24)
    title.Position = UDim2.new(0, 6, 0, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextColor3 = Color3.fromRGB(240,240,240)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "TG Export"

    local close = Instance.new("TextButton", frame)
    close.Size = UDim2.new(0, 20, 0, 20)
    close.Position = UDim2.new(1, -24, 0, 2)
    close.BackgroundTransparency = 1
    close.Font = Enum.Font.GothamBold
    close.TextSize = 14
    close.TextColor3 = Color3.fromRGB(200,200,200)
    close.Text = "×"
    close.MouseButton1Click:Connect(function() sg:Destroy() end)

    local function mkBtn(text, y, cb)
        local b = Instance.new("TextButton", frame)
        b.Size = UDim2.new(1, -16, 0, 24)
        b.Position = UDim2.new(0, 8, 0, y)
        b.BackgroundColor3 = Color3.fromRGB(45,45,45)
        b.BorderSizePixel = 0
        b.Font = Enum.Font.Gotham
        b.TextSize = 13
        b.TextColor3 = Color3.fromRGB(230,230,230)
        b.Text = text
        local c = Instance.new("UICorner", b)
        c.CornerRadius = UDim.new(0, 4)
        b.MouseEnter:Connect(function() b.BackgroundColor3 = Color3.fromRGB(60,60,60) end)
        b.MouseLeave:Connect(function() b.BackgroundColor3 = Color3.fromRGB(45,45,45) end)
        b.MouseButton1Click:Connect(cb)
        return b
    end

    mkBtn("Pick from world", 30, function()
        toast("[TG-Export] Click a part in the world…")
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                conn:Disconnect()
                local mouse = Players.LocalPlayer:GetMouse()
                local target = mouse.Target
                if target then
                    sendInstances({ target })
                else
                    toast("[TG-Export] Nothing under cursor.", true)
                end
            end
        end)
    end)

    mkBtn("Send DEX selection", 58, function()
        -- Try to pull from the DEX Explorer table if found
        local Explorer = findExplorerTable()
        if Explorer and Explorer.Selection and Explorer.Selection.List then
            local objs = {}
            for i = 1, #Explorer.Selection.List do
                local n = Explorer.Selection.List[i]
                if n and n.Obj then objs[#objs+1] = n.Obj end
            end
            sendInstances(objs)
        else
            toast("[TG-Export] Could not read DEX selection.", true)
        end
    end)

    mkBtn("Send Workspace", 86, function()
        sendInstances({ workspace })
    end)
end

-- ============================================================
-- Boot
-- ============================================================
task.spawn(function()
    if not CONFIG.BotToken or CONFIG.BotToken == "" or not CONFIG.ChatId or CONFIG.ChatId == "" then
        toast("[TG-Export] Fill BotToken & ChatId in CONFIG.", true)
        warn("[TG-Export] BotToken / ChatId empty — nothing will send.")
    end

    local ok, explorerOrErr = hookDEX()
    if ok then
        print("[TG-Export] Hooked into DEX context menu ✔")
    else
        warn("[TG-Export] DEX hook failed: " .. tostring(explorerOrErr))
    end

    -- Always show the fallback panel so there's something usable
    buildFallbackPanel()
end)
