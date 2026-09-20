--!nocheck
--[[
    DEX REContinued — Telegram Export Extension (Ultimate HTML Edition)
    ------------------------------------------------------------------
    Right-click any instance/folder in DEX → "Send to Telegram (HTML)"
    - Automatically gets ALL items inside the selection (deep).
    - Compiles a beautifully styled .html file with paths, properties, 
      attributes, tags, and scripts.
    - Uploads the single .html file to your Telegram chat.

    SETUP:
      1. Create a bot with @BotFather -> get BOT TOKEN
      2. Get your chat id: message @userinfobot -> it replies with your id
      3. Fill CONFIG.BotToken / CONFIG.ChatId below
      4. Run this AFTER DEX REContinued has loaded
]]

local CONFIG = {
    BotToken = "8305869255:AAEqIdORQUnQgg82LKbVwsj6Rzpfow0tKqo",
    ChatId   = "5798404109",
    
    IncludeScripts    = true,  -- dump Lua source if instance is a script
    IncludeHidden     = true,  -- include hidden properties
    IncludeAttributes = true,
    IncludeTags       = true,
    MaxPropsPerInst   = 60,    -- max properties to list per item
    MaxDeepCount      = 5000,  -- hard cap on how many items to get (safety)
    DeepPauseEvery    = 20,    -- yield every N items to prevent crash
    Silent            = false,
}

-- ============================================================
-- Executor HTTP
-- ============================================================
local httpRequest =
    (syn and syn.request) or (http and http.request) or http_request or request or
    (fluxus and fluxus.request) or (krnl and krnl.request) or
    (request == nil and (function() return nil end))

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
    elseif t == "UDim2" then
        return string.format("UDim2(%d, %d, %d, %d)", v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
    elseif t == "BrickColor" then
        return "BrickColor.new(\"" .. v.Name .. "\")"
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
-- Property Collectors
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

-- ============================================================
-- HTML Builders
-- ============================================================
local function buildInstanceHtml(inst)
    local parts = {}
    parts[#parts+1] = '<div class="instance">'
    parts[#parts+1] = string.format(
        '<div class="header"><span class="icon">📦</span> <span class="cls">%s</span> <span class="nm">"%s"</span></div>', 
        esc(inst.ClassName), esc(inst.Name)
    )
    parts[#parts+1] = string.format('<div class="path">🛤️ %s</div>', esc(getPath(inst)))
    
    local props = collectProperties(inst, CONFIG.MaxPropsPerInst)
    if #props > 0 then
        local rows = {}
        for _, p in ipairs(props) do
            rows[#rows+1] = string.format('<tr><td class="pn">%s</td><td class="pv">%s</td></tr>', esc(p.name), esc(valToStr(p.value)))
        end
        parts[#parts+1] = string.format('<details class="section" open><summary>⚙️ Properties (%d)</summary><table><tbody>%s</tbody></table></details>', #props, table.concat(rows, ""))
    end

    if CONFIG.IncludeAttributes then
        local attrs = collectAttributes(inst)
        if #attrs > 0 then
            local rows = {}
            for _, a in ipairs(attrs) do
                rows[#rows+1] = string.format('<tr><td class="pn">%s</td><td class="pv">%s</td></tr>', esc(a.name), esc(valToStr(a.value)))
            end
            parts[#parts+1] = string.format('<details class="section"><summary>🏷️ Attributes (%d)</summary><table><tbody>%s</tbody></table></details>', #attrs, table.concat(rows, ""))
        end
    end

    if CONFIG.IncludeTags then
        local tags = collectTags(inst)
        if #tags > 0 then
            parts[#parts+1] = string.format('<details class="section"><summary>🔖 Tags (%d)</summary><div class="tags-box">%s</div></details>', #tags, esc(table.concat(tags, " · ")))
        end
    end

    local src = collectSource(inst)
    if src then
        if #src > 15000 then
            src = src:sub(1, 15000) .. "\n\n-- …truncated (" .. (#src - 15000) .. " more chars)"
        end
        parts[#parts+1] = string.format('<details class="section"><summary>📜 Script Source</summary><pre><code>%s</code></pre></details>', esc(src))
    end
    
    parts[#parts+1] = '</div>'
    return table.concat(parts, "\n")
end

local function compileHtmlFile(instances)
    local htmlParts = {}
    htmlParts[#htmlParts+1] = [[
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>DEX Explorer Export</title>
<style>
  * { box-sizing: border-box; }
  body { font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f0f0f; color: #e0e0e0; margin: 0; padding: 24px; }
  h1 { color: #fff; font-size: 24px; border-bottom: 2px solid #007acc; padding-bottom: 16px; margin-top: 0; }
  .meta { background: #1a1a1a; padding: 16px; border-radius: 8px; margin-bottom: 24px; border: 1px solid #333; font-size: 14px; }
  .meta span { color: #4ec9b0; font-weight: bold; }
  .container { display: grid; grid-template-columns: repeat(auto-fill, minmax(450px, 1fr)); gap: 16px; }
  .instance { background: #1e1e1e; border: 1px solid #333; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.3); }
  .header { background: #252526; padding: 12px 16px; border-bottom: 1px solid #333; font-size: 15px; }
  .header .icon { margin-right: 5px; }
  .header .cls { color: #4ec9b0; font-weight: 600; }
  .header .nm { color: #ce9178; }
  .path { background: #181818; padding: 8px 16px; color: #569cd6; font-family: 'Consolas', monospace; font-size: 12px; border-bottom: 1px solid #2a2a2a; word-break: break-all; }
  .section { padding: 8px 16px; border-top: 1px solid #2a2a2a; }
  .section summary { cursor: pointer; color: #c586c0; font-size: 13px; font-weight: 600; padding: 8px 0; outline: none; user-select: none; }
  .section summary:hover { color: #dcdcaa; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; margin-bottom: 8px; }
  tr { border-bottom: 1px solid #2a2a2a; }
  tr:last-child { border-bottom: none; }
  td { padding: 8px 0; vertical-align: top; }
  td.pn { color: #9cdcfe; width: 35%; padding-right: 12px; }
  td.pv { color: #dcdcaa; word-break: break-all; }
  pre { background: #181818; padding: 12px; border-radius: 4px; font-size: 12px; overflow-x: auto; max-height: 400px; border: 1px solid #333; }
  pre code { font-family: 'Consolas', monospace; color: #d4d4d4; }
  .tags-box { padding: 8px 0; color: #b5cea8; font-style: italic; }
</style>
</head>
<body>
    ]]
    
    htmlParts[#htmlParts+1] = string.format(
        '<h1>🧩 DEX Explorer Dump</h1><div class="meta"><strong>Place ID:</strong> <span>%s</span><br><strong>Root Items:</strong> <span>%d</span></div><div class="container">', 
        tostring(game.PlaceId), #instances
    )

    local flat = {}
    local cap = CONFIG.MaxDeepCount or 5000
    for _, inst in ipairs(instances) do
        if typeof(inst) == "Instance" then
            collectAllDescendants(inst, flat, cap)
        end
        if #flat >= cap then break end
    end
    
    htmlParts[#htmlParts+1] = string.format('<!-- Total Items Dumped: %d -->', #flat)

    for i, inst in ipairs(flat) do
        local cok, html = pcall(buildInstanceHtml, inst)
        if cok then htmlParts[#htmlParts+1] = html end
        if i % CONFIG.DeepPauseEvery == 0 then task.wait() end
    end

    htmlParts[#htmlParts+1] = "</div></body></html>"
    return table.concat(htmlParts, "\n")
end

-- ============================================================
-- Telegram File Sender
-- ============================================================
local function tgSendFile(htmlContent, filename)
    if not CONFIG.BotToken or CONFIG.BotToken == "" then return false, "BotToken is empty" end
    if not CONFIG.ChatId or CONFIG.ChatId == "" then return false, "ChatId is empty" end

    local url = "https://api.telegram.org/bot" .. CONFIG.BotToken .. "/sendDocument"
    local boundary = "----DEXExportBoundary" .. tostring(math.random(10000000, 99999999))
    local CRLF = "\r\n"
    
    local caption = "🧩 DEX Export | Place: " .. tostring(game.PlaceId)
    
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
        Headers = { ["Content-Type"] = "multipart/form-data; boundary=" .. boundary },
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
    toast("[TG-Export] Scanning items & compiling HTML…")
    task.spawn(function()
        local ok, err = pcall(function()
            local htmlContent = compileHtmlFile(instances)
            local filename = "DEX_Dump_" .. tostring(os.time()) .. ".html"
            local sok, serr = tgSendFile(htmlContent, filename)
            if not sok then error(serr) end
        end)
        if ok then
            if not CONFIG.Silent then toast("[TG-Export] ✔ HTML file sent to Telegram.") end
        else
            toast("[TG-Export] Failed: " .. tostring(err), true)
            warn("[TG-Export] " .. tostring(err))
        end
    end)
end

_G.SendInstanceToTelegram = sendInstances

-- ============================================================
-- DEX hook
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
    end)

    if not rawget(ctx, "__dextg_hooked") then
        rawset(ctx, "__dextg_hooked", true)
        local oldShow = ctx.Show
        ctx.Show = function(self, x, y)
            if not self.Registered or not self.Registered["SEND_TO_TG"] then
                self:Register("SEND_TO_TG", { Name = "Send to Telegram (HTML)", Icon = ICON, OnClick = function() sendInstances(getSelectedObjs()) end })
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
    frame.Size = UDim2.new(0, 240, 0, 130)
    frame.Position = UDim2.new(0, 20, 0.5, -65)
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
        b.Size = UDim2.new(1, -16, 0, 28)
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

    mkBtn("Pick from world (Deep)", 30, function()
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

    mkBtn("Send DEX selection (Deep)", 66, function()
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

    mkBtn("Send Entire Workspace (Deep)", 102, function() 
        sendInstances({ workspace }) 
    end)
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
