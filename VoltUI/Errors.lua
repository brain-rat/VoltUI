-- VoltUI · Errors
-- Catches Lua errors so they can be copied and sent in one go, instead of read off the screen.
-- Every error the game reports goes past here: VoltUI's own (anything with VoltUI's files in it, a part
-- that couldn't start, a look that couldn't be put on, an action the game blocked) are kept and
-- told about once in chat; other add-ons' are kept too, behind a switch on the Errors page.
--
-- It listens after the game's own error window has taken an error (a hook on that window's
-- method, run after it), so nothing of the game's is replaced and the game's window, log and
-- error display all work as before. The list keeps the last 40, across reloads.

local ADDON, ns = ...
local FUI, S = ns.FUI, ns.Style

local Er = { list = {}, max = 40, session = 0 }
ns.Errors = Er

local function Plain(v, fallback)
  if v == nil then return fallback end
  if S.IsSecret(v) then return "(hidden by the game)" end
  return tostring(v)
end

local function Trim(text, most)
  if #text > most then return text:sub(1, most) .. "\n..." end
  return text
end

-- Anything that passed through VoltUI's own files.
local function Mine(text) return text:lower():find("addons[\\/]voltui[\\/]") ~= nil end

local function Now() return time and time() or 0 end

-- The list in use: VoltUI's saved one once settings have loaded, until then one in memory.
function Er:List() return self.list end

-- Keeps an error. kind: "lua" (from the game), "volt" (a part of VoltUI reporting its own), "blocked".
function Er:Add(msg, stack, locals, kind)
  msg = Plain(msg, "?")
  stack = Trim(Plain(stack, ""), 4000)
  locals = Trim(Plain(locals, ""), 2000)
  local key = msg .. "\n" .. (stack:match("^[^\n]*") or "")
  local list = self:List()
  for _, e in ipairs(list) do
    if e.key == key then
      e.count = (e.count or 1) + 1
      e.last, e.session = Now(), self.session
      self:Changed(e, false)
      return e
    end
  end
  local e = {
    key = key, msg = msg, stack = stack, locals = locals, count = 1,
    first = Now(), last = Now(), session = self.session, kind = kind or "lua",
    mine = kind == "volt" or kind == "blocked" or Mine(msg .. "\n" .. stack),
  }
  table.insert(list, 1, e)
  while #list > self.max do table.remove(list) end
  self:Changed(e, true)
  return e
end

function Er:Changed(e, new)
  if e.mine then
    self.unseen = true
    -- VoltUI's own reports and blocked actions say so in chat themselves.
    if new and e.kind == "lua" and not self.told and ns.db then
      self.told = true
      FUI:Print("caught an error. |cff7fc8ff/volt errors|r shows it, ready to copy.")
    end
    if ns.MinimapIcon and ns.MinimapIcon.Badge then pcall(ns.MinimapIcon.Badge, ns.MinimapIcon, true) end
  end
  local E = ns.EditMode
  if E and E.tab == "errors" and E.panel and E.panel:IsShown() then E:RefreshPage() end
end

-- What the Errors page lists: VoltUI's, or everyone's with the switch on.
function Er:Shown()
  local out, all = {}, ns.db and ns.db.errorsAll
  for _, e in ipairs(self:List()) do
    if all or e.mine then out[#out + 1] = e end
  end
  return out
end

function Er:Clear()
  wipe(self:List())
  self.unseen, self.picked = nil, nil
  if ns.MinimapIcon and ns.MinimapIcon.Badge then pcall(ns.MinimapIcon.Badge, ns.MinimapIcon, false) end
end

local function When(e)
  if e.session == Er.session then return "this session" end
  return "an earlier session"
end

-- One error, written out in full.
function Er:Text(e)
  if not e then return "" end
  local lines = {
    ("%s (x%d, %s)"):format(e.msg, e.count or 1, When(e)),
  }
  if e.stack ~= "" then lines[#lines + 1] = e.stack end
  if e.locals ~= "" then lines[#lines + 1] = "Locals:\n" .. e.locals end
  return table.concat(lines, "\n")
end

local function Version()
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
  local ok, v = pcall(get or function() end, ADDON, "Version")
  return ok and v or "?"
end
Er.Version = Version

-- Every error shown, with what's needed to make sense of them, as one block of text.
function Er:Report()
  local build = GetBuildInfo and table.concat({ GetBuildInfo() }, " ", 1, 2) or "?"
  local parts = {}
  for _, m in ipairs(FUI.modules) do
    if m.enabled then parts[#parts + 1] = m.key end
  end
  local out = {
    ("VoltUI %s, game %s, %s"):format(Version(), build, date and date("%Y-%m-%d %H:%M") or ""),
    "Parts on: " .. table.concat(parts, ", "),
  }
  local shown = self:Shown()
  if #shown == 0 then out[#out + 1] = "No errors caught." end
  for _, e in ipairs(shown) do
    out[#out + 1] = ""
    out[#out + 1] = self:Text(e)
  end
  return table.concat(out, "\n")
end

------------------------------------------------------------------------
-- Listening
------------------------------------------------------------------------

-- After the game's error window has taken an error: errors only (type 0), not warnings.
function Er:Hook()
  if self.hooked then return true end
  local sef = _G.ScriptErrorsFrame
  if type(sef) ~= "table" or type(sef.DisplayMessageInternal) ~= "function" then return false end
  self.hooked = true
  hooksecurefunc(sef, "DisplayMessageInternal", function(_, msg, kind, stack, locals)
    if kind ~= nil and kind ~= 0 then return end
    pcall(Er.Add, Er, msg, stack, locals, "lua")
  end)
  return true
end
Er:Hook()

-- Once settings have loaded, the saved list takes over, with anything caught before it on top.
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  local db = ns.db
  if not db then return end
  db.errorSession = (tonumber(db.errorSession) or 0) + 1
  Er.session = db.errorSession
  local saved = type(db.errorLog) == "table" and db.errorLog or {}
  for i = #Er.list, 1, -1 do
    local e = Er.list[i]
    e.session = Er.session
    -- One that fails at every login is the same row again with its count raised, not a new
    -- row each session until the list holds nothing else.
    for j = #saved, 1, -1 do
      local old = saved[j]
      if type(old) == "table" and old.key ~= nil and old.key == e.key then
        e.count = (e.count or 1) + (old.count or 1)
        e.first = old.first or e.first
        table.remove(saved, j)
      end
    end
    table.insert(saved, 1, e)
  end
  while #saved > Er.max do table.remove(saved) end
  db.errorLog = saved
  Er.list = saved
  Er:Hook()
end)

------------------------------------------------------------------------
-- The Errors page
------------------------------------------------------------------------

local LIST_ROWS, LIST_ROW_H = 8, 20
local A = S.ACCENT

local function BuildList(r, width)
  r.items = {}
  for i = 1, LIST_ROWS do
    local b = CreateFrame("Button", nil, r)
    b:SetPoint("TOPLEFT", r, "TOPLEFT", S.INSET, -(i - 1) * LIST_ROW_H)
    b:SetSize(width - 2 * S.INSET, LIST_ROW_H)
    b.hl = S.Highlight(b, 0.06)
    b.bg = S.Tex(b, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(A[1], A[2], A[3], 0)
    b.count = S.UIText(b, nil, "RIGHT", "OVERLAY", 11, nil, "mono")
    b.count:SetPoint("LEFT", 2, 0)
    b.count:SetWidth(30)
    b.count:SetTextColor(1, 0.5, 0.45)
    b.when = S.UIText(b, nil, "RIGHT", "OVERLAY", 11, nil, "mono")
    b.when:SetPoint("RIGHT", -4, 0)
    b.when:SetTextColor(S.HINT[1], S.HINT[2], S.HINT[3])
    b.text = S.UIText(b, nil, "LEFT", "OVERLAY", 12)
    b.text:SetPoint("LEFT", b.count, "RIGHT", 6, 0)
    b.text:SetPoint("RIGHT", b.when, "LEFT", -8, 0)
    b:SetScript("OnClick", function(self)
      Er.picked, Er.reporting = self.entry, nil
      ns.EditMode:RefreshPage()
    end)
    r.items[i] = b
  end
  r.empty = S.UIText(r, nil, "LEFT", "OVERLAY", 12)
  r.empty:SetPoint("TOPLEFT", S.INSET, -4)
  r.empty:SetPoint("RIGHT", -10, 0)
  r.empty:SetWordWrap(true)
  r.empty:SetTextColor(S.HINT[1], S.HINT[2], S.HINT[3])
  r.empty:SetText("Nothing caught. If something looks wrong in game, it shows up here with what's needed to fix it.")
end

local function FillList(r)
  local shown = Er:Shown()
  if Er.picked then
    local still
    for _, e in ipairs(shown) do if e == Er.picked then still = true end end
    if not still then Er.picked = nil end
  end
  Er.picked = Er.picked or shown[1]
  r.empty:SetShown(#shown == 0)
  for i, b in ipairs(r.items) do
    local e = shown[i]
    b.entry = e
    if e then
      b.count:SetText("x" .. (e.count or 1))
      b.text:SetText(e.msg:match("^[^\n]*"))
      b.when:SetText(e.session == Er.session and "now" or "before")
      b.bg:SetColorTexture(A[1], A[2], A[3], e == Er.picked and 0.16 or 0)
      b.text:SetTextColor(e.mine and 0.92 or 0.7, e.mine and 0.93 or 0.72, e.mine and 0.95 or 0.76)
      b:Show()
    else
      b:Hide()
    end
  end
  Er.unseen = nil
  if ns.MinimapIcon and ns.MinimapIcon.Badge then pcall(ns.MinimapIcon.Badge, ns.MinimapIcon, false) end
end

-- The page's cards, for the settings window.
function Er:Sections()
  local box
  return {
    {
      title = "Errors", full = true,
      { kind = "note", lines = 2, text = function()
        local n = #Er:Shown()
        local how = Er.hooked and "VoltUI is listening for errors." or "This game version doesn't let VoltUI listen for every error; VoltUI's own are still kept."
        return (n == 1 and "1 error kept. " or n .. " errors kept. ") .. how
      end },
      { kind = "toggle", label = "Show other add-ons' errors too", key = "errorsAll", store = "db" },
      { kind = "custom", height = LIST_ROWS * LIST_ROW_H + 4, build = BuildList, refresh = FillList },
      { kind = "custom", height = 176, build = function(r, width)
        box = S.TextBox(r, width - 2 * S.INSET, 170, { readOnly = true, hint = "Pick an error above to see all of it." })
        box:SetPoint("TOPLEFT", S.INSET, -2)
        r.box = box
        Er.box = box
      end, refresh = function(r)
        local text = Er.reporting and Er:Report() or Er:Text(Er.picked)
        if r.box.fixed ~= text then r.box:SetText(text) end
      end },
      { kind = "note", lines = 1, text = "Click in the box and press Ctrl+C to copy it." },
      { kind = "button", label = "This error", text = "Select it", fn = function()
        Er.reporting = nil
        ns.EditMode:RefreshPage()
        if Er.box then Er.box:Select() end
      end },
      { kind = "button", label = "Every error, with VoltUI's version", text = "Make a report", fn = function()
        Er.reporting = true
        ns.EditMode:RefreshPage()
        if Er.box then Er.box:Select() end
      end },
      { kind = "button", label = "Start the list again", text = "Clear", fn = function()
        Er.reporting = nil
        Er:Clear()
        ns.EditMode:RefreshPage()
      end },
    },
  }
end

