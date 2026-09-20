--!nocheck
--[[
    DEX REContinued — Telegram Export Extension (HTML File Edition)
    --------------------------------------------------------------
    Right-click any instance in DEX →
        • "Send to Telegram"        — compiles a single .html file and uploads it
        • "Send to Telegram (Deep)" — same, but for every descendant

    SETUP:
      1. Create a bot with @BotFather  -> get BOT TOKEN
      2. Get your chat id: message @userinfobot -> it replies with your id
      3. Fill CONFIG.BotToken / CONFIG.ChatId below
      4. Run this AFTER DEX REContinued has loaded
]]

local CONFIG = {
    BotToken = "8305869255:AAEqIdORQUnQgg82LKbVwsj6Rzpfow0tKqo",
    ChatId   = "5798404109",
    MaxDepth          = 4,     -- recursion depth when dumping name-only children tree
    MaxChildren       = 150,   -- max children shown per node in the tree
    IncludeScripts    = true,  -- dump Lua source if instance is a script
    IncludeHidden     = true,  -- include hidden properties (gethiddenproperty)
    IncludeAttributes = true,
    IncludeTags       = true,
    IncludeChildTree  = true,  -- name-only tree (only used in shallow mode)
    MaxPropsPerInst   = 40,
    Silent            = false,

    -- Deep mode settings
    MaxDeepCount    = 400,     -- hard cap on how many instances get dumped in deep mode
    DeepPauseEvery  = 5,       -- task.wait() every N instances (yields, keeps game alive)
    DeepIncludeTree = false,   -- also print name-only tree per node in deep mode
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
    or (request == nil and (function() return nil end))

if not httpRequest then
    warn("[TG-Export] No HTTP request function on this executor.")
end

local HttpService       = cloneref and cloneref(game:GetService("HttpService"))       or game:GetService("HttpService")
local UserInputService  = cloneref and cloneref(game:GetService("UserInputService"))  or game:GetService("UserInputService")
local Players           = cloneref and cloneref(game:GetService("Players"))           or game:GetService("Players")
local CollectionService = cloneref and cloneref(game:GetService("CollectionService")) or game:GetService("CollectionService")

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
    "Name","ClassName","Archivable","Position","CFrame","Size","Rotation","Orientation",
    "Color","BrickColor","Material","Transparency","Reflectance","Anchored","CanCollide",
    "CanTouch","CanQuery","Massless","Locked","Shape","Velocity","Value","Text","Image",
    "Texture","SoundId","MeshId","TextureID","Enabled","Visible","Active","Source",
    "RunContext","Disabled","WalkSpeed","JumpPower","JumpHeight","Health","MaxHealth",
    "Team","TeamColor","UserId","DisplayName","Brightness","Ambient","CameraType",
    "FieldOfView","TimePosition","Volume","Loop","Playing","PlaybackSpeed","Character",
    "PlayerGui","Backpack","PlayerScripts","GameId","PlaceId","PlaceVersion","Workspace",
    "PrimaryPart","WorldPivot","AnimationId","Speed","Weight"
}

local function collectProperties(inst, maxProps)
    local out, count, used = {}, 0, {}
    if getproperties then
        local ok, props = pcall(getproperties, inst)
        if ok and type(props) == "table" then
            local keys = {}
            for k in pairs(props) do if type(k) == "string" then keys[#keys+1] = k end end
            pcall(table.sort, keys)
            for _, k in ipairs(keys) do
                if count >= maxProps then break end
                if not used[k] then
                    used[k] = true
                    local vok, v = pcall(function() return props[k] end)
                    if vok and v ~= nil and typeof(v) ~= "function" then
                        count = count + 1
                        out[#out+1] = { name = k, value = v }
                    end
                end
            end
            if count > 0 then return out end
        end
    end

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
        for k, v in pairs(attrs) do out[#out+1] = { name = k, value = v } end
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

-- ============================================================
-- HTML Builders
-- ============================================================
local function buildInstanceHtml(inst, isDeep)
    local parts = {}
    parts[#parts+1] = string.format(
        '<div class="instance"><div class="header"><b>%s</b> <span>"%s"</span></div>', 
        esc(inst.ClassName), esc(inst.Name)
    )
    parts[#parts+1] = string.format('<div class="path">Path: %s</div>', esc(getPath(inst)))
    
    if not isDeep and CONFIG.IncludeChildTree then
        local tree = childrenTree(inst, 1, CONFIG.MaxDepth, CONFIG.MaxChildren, "")
        local count = #inst:GetChildren()
        if count > 0 then
            parts[#parts+1] = string.format(
                '<div class="section"><h3>Children (%d)</h3><pre>%s</pre></div>', 
                count, esc(tree)
            )
        end
    elseif isDeep then
        local count = #inst:GetChildren()
        if count > 0 then
            parts[#parts+1] = string.format('<div class="section"><i>Children Count: %d</i></div>', count)
        end
    end
    
    local props = collectProperties(inst, CONFIG.MaxPropsPerInst)
    if #props > 0 then
        local rows = {}
        for _, p in ipairs(props) do
            rows[#rows+1] = string.format('<tr><td>%s</td><td>%s</td></tr>', esc(p.name), esc(valToStr(p.value)))
        end
        parts[#parts+1] = string.format('<div class="section"><h3>Properties (%d)</h3><table>%s</table></div>', #props, table.concat(rows, ""))
    end

    if CONFIG.IncludeAttributes then
        local attrs = collectAttributes(inst)
        if #attrs > 0 then
            local rows = {}
            for _, a in ipairs(attrs) do
                rows[#rows+1] = string.format('<tr><td>%s</td><td>%s</td></tr>', esc(a.name), esc(valToStr(a.value)))
            end
            parts[#parts+1] = string.format('<div class="section"><h3>Attributes (%d)</h3><table>%s</table></div>', #attrs, table.concat(rows, ""))
        end
    end

    if CONFIG.IncludeTags then
        local tags = collectTags(inst)
        if #tags > 0 then
            parts[#parts+1] = string.format('<div class="section"><h3>Tags</h3><code>%s</code></div>', esc(table.concat(tags, ", ")))
        end
    end

    local src = collectSource(inst)
    if src then
        if #src > 12000 then
            src = src:sub(1, 12000) .. "\n\n-- …truncated (" .. (#src - 12000) .. " more chars)"
        end
        parts[#parts+1] = string.format('<div class="section"><h3>Script Source</h3><pre>%s</pre></div>', esc(src))
    end
    
    parts[#parts+1] = '</div>'
    return table.concat(parts, "\n")
end

local function collectAllDescendants(root, out, cap)
    local queue = { root }
    local head = 1
    while head <= #queue do
        local cur = queue[head]; head = head + 1
        out[#out+1] = cur
        if #out >= cap then return end
        local kids = cur:GetChildren()
        for i = 1, #kids do queue[#queue+1] = kids[i] end
    end
end

local function compileHtmlFile(instances, isDeep)
    local htmlParts = {}
    htmlParts[#htmlParts+1] = [[
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>DEX Export</title>
<style>
  body { font-family: Consolas, 'Courier New', monospace; background: #1e1e1e; color: #d4d4d4; margin: 0; padding: 20px; }
  h1 { color: #ffffff; border-bottom: 1px solid #333; padding-bottom: 10px; margin-top: 0; }
  .meta { color: #888; margin-bottom: 20px; font-size: 14px; }
  .instance { margin-bottom: 15px; border: 1px solid #3c3c3c; border-radius: 4px; background: #252526; overflow: hidden; }
  .header { background: #2d2d2d; padding: 8px 12px; border-bottom: 1px solid #3c3c3c; font-size: 16px; }
  .header b { color: #4ec9b0; }
  .header span { color: #ce9178; }
  .path { padding: 6px 12px; color: #dcdcaa; border-bottom: 1px solid #2d2d2d; font-size: 12px; }
  .section { padding: 10px 12px; border-top: 1px solid #2d2d2d; }
  .section h3 { margin: 0 0 8px 0; color: #c586c0; font-size: 13px; text-transform: uppercase; }
  table { width: 100%; border-collapse: collapse; }
  td { padding: 4px 12px; border-bottom: 1px solid #2d2d2d; vertical-align: top; }
  td:first-child { color: #9cdcfe; width: 35%; }
  td:last-child { color: #ce9178; }
  pre { background: #1e1e1e; border: 1px solid #3c3c3c; padding: 10px; border-radius: 4px; white-space: pre-wrap; word-wrap: break-word; font-size: 12px; max-height: 600px; overflow-y: auto; }
  code { color: #b5cea8; }
</style>
</head>
<body>
    ]]
    
    local modeStr = isDeep and "Deep" or "Shallow"
    htmlParts[#htmlParts+1] = string.format(
        '<h1>🧩 DEX Explorer Export</h1><div class="meta">Place ID: %s | Mode: %s | Roots: %d</div>', 
        tostring(game.PlaceId), modeStr, #instances
    )

    if isDeep then
        local flat = {}
        local cap = CONFIG.MaxDeepCount or 400
        for _, inst in ipairs(instances) do
            if typeof(inst) == "Instance" then
                collectAllDescendants(inst, flat, cap)
            end
            if #flat >= cap then break end
        end
        
        htmlParts[#htmlParts+1] = string.format('<div class="meta">Total Descendants Dumped: %d</div>', #flat)
        
        for i, inst in ipairs(flat) do
            local cok, html = pcall(buildInstanceHtml, inst, true)
            if cok then htmlParts[#htmlParts+1] = html end
            if i % CONFIG.DeepPauseEvery == 0 then task.wait() end
        end
    else
        for i, inst in ipairs(instances) do
            if typeof(inst) == "Instance" then
                local cok, html = pcall(buildInstanceHtml, inst, false)
                if cok then htmlParts[#htmlParts+1] = html end
            end
            if i % 2 == 0 then task.wait() end
        end
    end

    htmlParts[#htmlParts+1] = "</body></html>"
    return table.concat(htmlParts, "\n")
end

-- ============================================================
-- Telegram File Sender
-- ============================================================
local function tgSendFile(htmlContent, filename)
    if not CONFIG.BotToken or CONFIG.BotToken == "" then
        return false, "BotToken is empty"
    end
    if not CONFIG.ChatId or CONFIG.ChatId == "" then
        return false, "ChatId is empty"
    end

    local url = "https://api.telegram.org/bot" .. CONFIG.BotToken .. "/sendDocument"
    local boundary = "----DEXExportBoundary" .. tostring(math.random(10000000, 99999999))
    local CRLF = "\r\n"
    
    local caption = "🧩 DEX Export | Place: " .. tostring(game.PlaceId)
    
    -- Build multipart/form-data manually
    local body = "--" .. boundary .. CRLF ..
        'Content-Disposition: form-data; name="chat_id"' .. CRLF .. CRLF ..
        tostring(CONFIG.ChatId) .. CRLF ..
        "--" .. boundary .. CRLF ..
        'Content-Disposition: form-data; name="caption"' .. CRLF .. CRLF ..
        caption .. CRLF ..
        "--" .. boundary .. CRLF ..
        'Content-Disposition: form-data; name="parse_mode"' .. CRLF .. CRLF ..
        "HTML" .. CRLF ..
        "--" .. boundary .. CRLF ..
        'Content-Disposition: form-data; name="document"; filename="' .. filename .. '"' .. CRLF ..
        "Content-Type: text/html" .. CRLF .. CRLF ..
        htmlContent .. CRLF ..
        "--" .. boundary .. "--" .. CRLF

    local ok, res = pcall(httpRequest, {
        Url = url,
        Method = "POST",
        Headers = { 
            ["Content-Type"] = "multipart/form-data; boundary=" .. boundary
        },
        Body = body,
    })
    
    if not ok then return false, tostring(res) end
    if not res or not res.Body then return false, "no response" end
    if res.StatusCode and res.StatusCode ~= 200 then
        return false, "HTTP " .. res.StatusCode .. " " .. tostring(res.Body)
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
    toast("[TG-Export] Compiling HTML file…")
    task.spawn(function()
        local ok, err = pcall(function()
            local htmlContent = compileHtmlFile(instances, false)
            local filename = "DEX_Export_" .. tostring(os.time()) .. ".html"
            local sok, serr = tgSendFile(htmlContent, filename)
            if not sok then error(serr) end
        end)
        if ok then
            if not CONFIG.Silent then toast("[TG-Export] ✔ HTML file sent.") end
        else
            toast("[TG-Export] Failed: " .. tostring(err), true)
            warn("[TG-Export] " .. tostring(err))
        end
    end)
end

local function sendInstancesDeep(instances)
    if type(instances) ~= "table" or #instances == 0 then
        toast("[TG-Export] Nothing selected.", true)
        return
    end
    toast("[TG-Export] Compiling Deep HTML file…")
    task.spawn(function()
        local ok, err = pcall(function()
            local htmlContent = compileHtmlFile(instances, true)
            local filename = "DEX_DeepExport_" .. tostring(os.time()) .. ".html"
            local sok, serr = tgSendFile(htmlContent, filename)
            if not sok then error(serr) end
        end)
        if ok then
            if not CONFIG.Silent then toast("[TG-Export] ✔ Deep HTML file sent.") end
        else
            toast("[TG-Export] ❌ Deep failed: " .. tostring(err), true)
            warn("[TG-Export] " .. tostring(err))
        end
    end)
end

_G.SendInstanceToTelegram     = sendInstances
_G.SendInstanceToTelegramDeep = sendInstancesDeep

-- ============================================================
-- DEX hook — find Explorer table and inject context menu items
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
    if not Explorer then return false, "Could not find DEX Explorer table" end

    local ctx = rawget(Explorer, "RightClickContext")
    if not ctx then return false, "No RightClickContext" end

    local ICON = "rbxassetid://113955252013201"

    local function getSelectedObjs()
        local sList = Explorer.Selection.List
        local objs = {}
        for i = 1, #sList do
            local node = sList[i]
            if node and node.Obj then objs[#objs+1] = node.Obj end
        end
        return objs
    end

    pcall(function()
        ctx:Register("SEND_TO_TG", {
            Name = "Send to Telegram (HTML)",
            Icon = ICON,
            OnClick = function() sendInstances(getSelectedObjs()) end,
        })
        ctx:Register("SEND_TO_TG_DEEP", {
            Name = "Send to Telegram (Deep HTML)",
            Icon = ICON,
            OnClick = function() sendInstancesDeep(getSelectedObjs()) end,
        })
    end)

    if not rawget(ctx, "__dextg_hooked") then
        rawset(ctx, "__dextg_hooked", true)
        local oldShow = ctx.Show
        ctx.Show = function(self, x, y)
            if not self.Registered or not self.Registered["SEND_TO_TG"] then
                self:Register("SEND_TO_TG", { Name = "Send to Telegram (HTML)", Icon = ICON, OnClick = function() sendInstances(getSelectedObjs()) end })
            end
            if not self.Registered or not self.Registered["SEND_TO_TG_DEEP"] then
                self:Register("SEND_TO_TG_DEEP", { Name = "Send to Telegram (Deep HTML)", Icon = ICON, OnClick = function() sendInstancesDeep(getSelectedObjs()) end })
            end
            self:AddRegistered("SEND_TO_TG")
            self:AddRegistered("SEND_TO_TG_DEEP")
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
    frame.Size = UDim2.new(0, 240, 0, 176)
    frame.Position = UDim2.new(0, 20, 0.5, -88)
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
    title.Text = "TG Export (.html)"

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
    end

    mkBtn("Pick from world", 30, function()
        toast("[TG-Export] Click a part in the world…")
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                conn:Disconnect()
                local mouse = Players.LocalPlayer:GetMouse()
                local target = mouse.Target
                if target then sendInstances({ target })
                else toast("[TG-Export] Nothing under cursor.", true) end
            end
        end)
    end)

    mkBtn("Send DEX selection", 58, function()
        local Explorer = findExplorerTable()
        if Explorer and Explorer.Selection and Explorer.Selection.List then
            local objs = {}
            for i = 1, #Explorer.Selection.List do
                local n = Explorer.Selection.List[i]
                if n and n.Obj then objs[#objs+1] = n.Obj end
            end
            sendInstances(objs)
        else toast("[TG-Export] Could not read DEX selection.", true) end
    end)

    mkBtn("Send Workspace", 86, function() sendInstances({ workspace }) end)

    mkBtn("Send DEX selection (Deep)", 114, function()
        local Explorer = findExplorerTable()
        if Explorer and Explorer.Selection and Explorer.Selection.List then
            local objs = {}
            for i = 1, #Explorer.Selection.List do
                local n = Explorer.Selection.List[i]
                if n and n.Obj then objs[#objs+1] = n.Obj end
            end
            sendInstancesDeep(objs)
        else toast("[TG-Export] Could not read DEX selection.", true) end
    end)

    mkBtn("Send Workspace (Deep)", 142, function() sendInstancesDeep({ workspace }) end)
end

-- ============================================================
-- Boot
-- ============================================================
task.spawn(function()
    if not CONFIG.BotToken or CONFIG.BotToken == "" or not CONFIG.ChatId or CONFIG.ChatId == "" then
        toast("[TG-Export] Fill BotToken & ChatId in CONFIG.", true)
    end
    local ok, explorerOrErr = hookDEX()
    if ok then print("[TG-Export] Hooked into DEX context menu ✔")
    else warn("[TG-Export] DEX hook failed: " .. tostring(explorerOrErr)) end
    buildFallbackPanel()
end)
