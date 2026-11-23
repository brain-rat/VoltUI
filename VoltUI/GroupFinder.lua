-- VoltUI · Group finder (since 1.91.0)
-- The listings in the game's group finder (the Browse page), laid out to be read at a glance.
-- The game's row says who listed, then "3 activities" and nothing of the note; the rest is in
-- the panel that pops up beside a row you point at. VoltUI's row says it on the row:
--
--   | Name  60 Warrior                                  [the game's role counts]
--   | Scholomance, Stratholme: Live, Dire Maul: East +2
--   | the note they wrote, or who's in the group                             4m
--
-- A bar in the leader's class colour down the left, the dungeons by name (the ones you're
-- listed for too in gold, a lone one with its level range), the note, and how long ago it
-- was listed. Rows are flat, with a gold tint on the one you've picked.
--
-- The game still runs the window: searching, picking, whispering, inviting and the pop-up
-- panel are all its own. VoltUI adds its own textures and texts to each row and fades the ones
-- they replace. It follows the game's own row function (LFGBrowseSearchEntry_Update), hooked
-- after it runs; it never hooks a method of the window, and writes no field on the game's
-- frames: what VoltUI knows about a row is kept in a table of its own. Every step is guarded.
--
-- The finder is a load-on-demand add-on (Blizzard_GroupFinder_VanillaStyle on Forever), so
-- the rows are taken over when that loads.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style

local F = { key = "groupfinder", name = "Group finder" }
ns.GroupFinder = F

local floor, max, min = math.floor, math.max, math.min
local Fade = S.Fade
local UI, A = S.UI, S.UI.accent

F.ADDON = "Blizzard_GroupFinder_VanillaStyle"
F.rows = setmetatable({}, { __mode = "k" })  -- the game's row -> VoltUI's parts on it
F.heads = setmetatable({}, { __mode = "k" }) -- the game's "Groups" / "Solo players" headings
F.done = false

-- Layout, in the row's own units. A row is 312 wide; 72 tall under a heading, 52 without.
F.LEFT = 14           -- where the texts start, after the class bar
F.NAMES = 4           -- how many activities are named before "+2"
-- The game's display (role icons, counts, the delist button) is a block 200 wide and 32 tall
-- with its pieces centred in it. Hung this far below the row's top its icons end above line
-- 2, so that line has the row's whole width (1.101.4: it used to stop short of the icons and
-- cut "Scarlet Graveyard, Scarlet Li..." with half the row empty).
F.DD_TOP = -1
F.RIGHT = 10          -- the gap kept at the row's right end

local function Report(what, err)
  F.errors = F.errors or {}
  if F.errors[what] then return end -- once each: a row is redrawn many times a second
  F.errors[what] = tostring(err)
  if ns.Errors and ns.Errors.Add then pcall(ns.Errors.Add, ns.Errors, "Group finder " .. what .. ": " .. tostring(err), nil, nil, "volt") end
end

local function Step(what, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then Report(what, err) end
  return ok
end

------------------------------------------------------------------------
-- What a row says (plain functions, so they can be tested without the game)
------------------------------------------------------------------------

-- "4m", "1h 20m", "2h": how long ago something was listed. Nothing for no age.
function F.Age(sec)
  if type(sec) ~= "number" or sec < 0 then return "" end
  if sec < 60 then return "now" end
  local m = floor(sec / 60)
  if m < 60 then return m .. "m" end
  local h = floor(m / 60)
  m = m - h * 60
  if h >= 3 or m == 0 then return h .. "h" end
  return h .. "h " .. m .. "m"
end

local function Hex(c) return UI.Hex(c) end

-- An activity's name as the game shortens it.
local function ActivityName(a)
  if type(a) ~= "table" then return nil end
  local n = (a.shortName ~= nil and a.shortName ~= "") and a.shortName or a.fullName
  if n == nil or n == "" then return nil end
  return n
end

-- The activities line. ids: the listing's activities; mine: a set of the ones you're listed
-- for; infoOf(id): the game's activity info. Yours come first, in gold. A lone activity gets
-- its level range; more than F.NAMES end in "+2". plain: no colours (a listing that's gone).
-- Returns the text and whether any of them is one of yours.
function F.Activities(ids, mine, infoOf, plain)
  local first, rest = {}, {}
  local lone
  for _, id in ipairs(ids or {}) do
    local a = infoOf(id)
    local n = ActivityName(a)
    if n then
      lone = a
      if mine and mine[id] then first[#first + 1] = n else rest[#rest + 1] = n end
    end
  end
  local total = #first + #rest
  if total == 0 then return "", false end
  local parts = {}
  for i, n in ipairs(first) do
    if #parts < F.NAMES then parts[#parts + 1] = plain and n or (Hex(UI.accentText) .. n .. "|r") end
  end
  for _, n in ipairs(rest) do
    if #parts < F.NAMES then parts[#parts + 1] = n end
  end
  local text = table.concat(parts, ", ")
  if total > #parts then
    text = text .. (plain and "" or Hex(UI.hint)) .. " +" .. (total - #parts) .. (plain and "" or "|r")
  elseif total == 1 and lone then
    local lo, hi = tonumber(lone.minLevelSuggestion) or 0, tonumber(lone.maxLevelSuggestion) or 0
    local range = (lo > 0 and hi > lo) and (lo .. "-" .. hi) or (lo > 0 and (lo .. "+")) or nil
    if range then text = text .. (plain and "  " or ("  " .. Hex(UI.hint))) .. range .. (plain and "" or "|r") end
  end
  return text, #first > 0
end

-- A note on one line: line breaks and runs of spaces become one space.
function F.Note(s)
  if type(s) ~= "string" then return "" end
  s = s:gsub("[\r\n]+", " "):gsub("%s%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

-- Who else is in the group, each in their class colour: for a listing with no note.
function F.Roster(members, colors, plain)
  local out = {}
  for _, m in ipairs(members or {}) do
    if type(m) == "table" and m.name and not m.isLeader then
      local c = not plain and colors and m.classFilename and colors[m.classFilename]
      if c then
        out[#out + 1] = ("|cff%02x%02x%02x%s|r"):format(floor(c.r * 255 + 0.5), floor(c.g * 255 + 0.5), floor(c.b * 255 + 0.5), m.name)
      else
        out[#out + 1] = m.name
      end
    end
  end
  if #out == 0 then return "" end
  return (plain and "" or Hex(UI.hint)) .. "with " .. (plain and "" or "|r") .. table.concat(out, ", ")
end

------------------------------------------------------------------------
-- A row
------------------------------------------------------------------------

-- VoltUI's parts on one of the game's rows, made the first time the row is drawn.
function F:Build(row)
  local p = {}
  self.rows[row] = p
  p.tall = type(row.PlaystyleLabel) == "table" -- the 72-tall row the game uses under a heading
  local dd = row.DataDisplay

  -- the game's pieces VoltUI's take the place of. The game shows and hides them and sets their
  -- text, never their alpha, so a fade holds.
  Fade(row.ResultBG, row.PartyIcon, row.Level, row.ClassIcon, row.ActivityName, row.PlaystyleLabel)
  if type(dd) == "table" then
    Fade(dd.Comment)
    if type(dd.Solo) == "table" then Fade(dd.Solo.RolesText) end
  end

  p.bg = S.Tex(row, "BACKGROUND", -6)
  p.bg:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -2)
  p.bg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -3, 1)
  p.bg:SetColorTexture(UI.card[1], UI.card[2], UI.card[3], 0.92)
  p.bar = S.Tex(row, "BORDER")
  p.bar:SetPoint("TOPLEFT", p.bg, "TOPLEFT", 0, 0)
  p.bar:SetPoint("BOTTOMLEFT", p.bg, "BOTTOMLEFT", 0, 0)
  p.bar:SetWidth(3)

  -- the game's own "picked" and "under the mouse" textures, flat: it shows and hides them
  for key, alpha in pairs({ Selected = 0.26, Highlight = 0.12 }) do
    local t = row[key]
    if type(t) == "table" and t.SetColorTexture then
      t:SetColorTexture(A[1], A[2], A[3], alpha)
      if t.SetBlendMode then t:SetBlendMode("BLEND") end
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", p.bg, "TOPLEFT", 0, 0)
      t:SetPoint("BOTTOMRIGHT", p.bg, "BOTTOMRIGHT", 0, 0)
    end
  end

  if type(row.Name) == "table" and row.Name.SetFont then S.FixFont(row.Name, 13, nil, "semibold") end
  p.info = S.UIText(row, nil, "LEFT", "ARTWORK", 11, nil, "mono") -- "60 Warrior"
  p.acts = S.UIText(row, nil, "LEFT", "ARTWORK", 12)              -- the activities
  p.note = S.UIText(row, nil, "LEFT", "ARTWORK", 11)              -- the note, or who's in the group
  p.age = S.UIText(row, nil, "RIGHT", "ARTWORK", 10, nil, "mono") -- "4m"
  p.age:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -10, 9)
  p.age:SetTextColor(UI.hint[1], UI.hint[2], UI.hint[3])

  -- the game's display moves up beside the first line, on short rows (your own listing) as
  -- on tall ones, so the lines under it have the row's whole width. The game anchors it once,
  -- in its layout file.
  if type(dd) == "table" and dd.ClearAllPoints then
    dd:ClearAllPoints()
    dd:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, F.DD_TOP)
  end
  return p
end

-- Called after the game has drawn a row.
function F:Row(row)
  if type(row) ~= "table" or not row.resultID or not C_LFGList then return end
  local id = row.resultID
  local info = C_LFGList.GetSearchResultInfo(id)
  if type(info) ~= "table" then return end
  local p = self.rows[row] or self:Build(row)
  local leader = C_LFGList.GetSearchResultLeaderInfo and C_LFGList.GetSearchResultLeaderInfo(id)
  if type(leader) ~= "table" then leader = nil end
  local colors = _G.RAID_CLASS_COLORS

  -- Gone or filtered out: the game greys the name. VoltUI's lines follow that grey rather than
  -- working out the filters again.
  local off = info.isDelisted and true or false
  if type(row.Name) == "table" and row.Name.GetTextColor then
    local r, g, b = row.Name:GetTextColor()
    if type(r) == "number" and r == g and g == b and r < 0.35 then off = true end
  end

  -- the class bar
  local c = leader and colors and colors[leader.classFilename]
  if c and not off then
    p.bar:SetColorTexture(c.r, c.g, c.b, 1)
  else
    p.bar:SetColorTexture(UI.line[1], UI.line[2], UI.line[3], 1)
  end

  -- line 1: the name (the game's own text, moved to the row's left edge), then level and class
  local top = p.tall and -10 or -9
  if type(row.Name) == "table" and row.Name.SetPoint then row.Name:SetPoint("TOPLEFT", row, "TOPLEFT", F.LEFT, top) end
  local words = {}
  if leader and leader.level then words[#words + 1] = tostring(leader.level) end
  local class = leader and ((_G.LOCALIZED_CLASS_NAMES_MALE and _G.LOCALIZED_CLASS_NAMES_MALE[leader.classFilename]) or leader.className)
  if class then words[#words + 1] = class end
  p.info:SetText(table.concat(words, " "))
  local dim = off and UI.off or UI.sub
  p.info:SetTextColor(dim[1], dim[2], dim[3])
  local after = type(row.Name) == "table" and row.Name or nil
  if type(row.DiscordIcon) == "table" and row.DiscordIcon.IsShown and row.DiscordIcon:IsShown() then after = row.DiscordIcon end
  p.info:ClearAllPoints()
  if after then p.info:SetPoint("LEFT", after, "RIGHT", 6, 0) else p.info:SetPoint("TOPLEFT", row, "TOPLEFT", F.LEFT, top) end
  if type(row.NewPlayerFriendlyIcon) == "table" and row.NewPlayerFriendlyIcon.SetPoint then
    row.NewPlayerFriendlyIcon:SetPoint("LEFT", p.info, "RIGHT", 4, 0)
  end

  -- line 2: the activities by name
  local mine
  local active = C_LFGList.GetActiveEntryInfo and C_LFGList.GetActiveEntryInfo()
  if type(active) == "table" and type(active.activityIDs) == "table" then
    mine = {}
    for _, a in ipairs(active.activityIDs) do mine[a] = true end
  end
  local text = F.Activities(info.activityIDs, mine, C_LFGList.GetActivityInfoTable, off)
  if info.hasSelf then
    local own = _G.LFG_SELF_LISTING or "Your listing"
    text = (off and own or (Hex(UI.ok) .. own .. "|r")) .. (text ~= "" and ("  " .. text) or "")
  end
  p.acts:SetText(text)
  local col = off and UI.off or UI.label
  p.acts:SetTextColor(col[1], col[2], col[3])
  p.acts:ClearAllPoints()
  p.acts:SetPoint("TOPLEFT", row, "TOPLEFT", F.LEFT, top - 19)
  p.acts:SetPoint("TOPRIGHT", row, "TOPRIGHT", -F.RIGHT, top - 19)

  -- line 3 (tall rows): the note, or who's in the group; and how long it's been listed
  if p.tall then
    local note = F.Note(info.comment)
    local style = info.generalPlaystyle and type(_G.GetGeneralPlaystyleString) == "function" and _G.GetGeneralPlaystyleString(info.generalPlaystyle)
    if note == "" and (info.numMembers or 0) > 1 and (info.numMembers or 0) <= 10 and C_LFGList.GetSearchResultPlayerInfo then
      local members = {}
      for i = 1, info.numMembers do members[#members + 1] = C_LFGList.GetSearchResultPlayerInfo(id, i) or false end
      note = F.Roster(members, colors, off)
    end
    if type(style) == "string" and style ~= "" then
      note = (off and style or (Hex(UI.ok) .. style .. "|r")) .. (note ~= "" and ("  " .. note) or "")
    end
    p.note:SetText(note)
    col = off and UI.off or UI.sub
    p.note:SetTextColor(col[1], col[2], col[3])
    local age = off and "" or F.Age(info.age)
    p.age:SetText(age)
    p.note:ClearAllPoints()
    p.note:SetPoint("TOPLEFT", row, "TOPLEFT", F.LEFT, top - 38)
    p.note:SetPoint("TOPRIGHT", row, "TOPRIGHT", age ~= "" and -56 or -10, top - 38)
    p.note:Show()
    p.age:Show()
  else
    p.note:Hide()
    p.age:Hide()
  end
end

------------------------------------------------------------------------
-- The "Groups" and "Solo players" headings
------------------------------------------------------------------------

function F:Head(h)
  if type(h) ~= "table" or self.heads[h] or type(h.CategoryLabel) ~= "table" then return end
  self.heads[h] = true
  Fade(h.ResultBG)
  local band = S.Tex(h, "BACKGROUND", -6)
  band:SetPoint("TOPLEFT", h, "TOPLEFT", 3, -9)
  band:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -3, 1)
  band:SetColorTexture(UI.raised[1], UI.raised[2], UI.raised[3], 0.95)
  local line = S.Tex(h, "BORDER")
  line:SetPoint("BOTTOMLEFT", band, "BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", band, "BOTTOMRIGHT", 0, 0)
  line:SetHeight(1)
  line:SetColorTexture(UI.line[1], UI.line[2], UI.line[3], 1)
  if type(h.Highlight) == "table" and h.Highlight.SetColorTexture then
    h.Highlight:SetColorTexture(A[1], A[2], A[3], UI.hover)
    if h.Highlight.SetBlendMode then h.Highlight:SetBlendMode("BLEND") end
    h.Highlight:ClearAllPoints()
    h.Highlight:SetPoint("TOPLEFT", band, "TOPLEFT", 0, 0)
    h.Highlight:SetPoint("BOTTOMRIGHT", band, "BOTTOMRIGHT", 0, 0)
  end
  if h.CategoryLabel.SetFont then
    S.FixFont(h.CategoryLabel, 11, nil, "semibold", "mono")
    h.CategoryLabel:SetTextColor(UI.sub[1], UI.sub[2], UI.sub[3])
  end
end

-- The headings have no function of the game's to follow, so they're looked for among the
-- rows on show whenever a row is drawn or the page opens.
function F:Sweep()
  local f = _G.LFGBrowseFrame
  local box = type(f) == "table" and f.ScrollBox
  if type(box) ~= "table" or type(box.ForEachFrame) ~= "function" then return end
  box:ForEachFrame(function(frame)
    if type(frame) == "table" and frame.CategoryLabel then Step("heading", F.Head, F, frame) end
  end)
end

------------------------------------------------------------------------
-- Taking the rows over
------------------------------------------------------------------------

function F:Hook()
  if self.done then return end
  if type(_G.LFGBrowseSearchEntry_Update) ~= "function" then return end
  self.done = true
  hooksecurefunc("LFGBrowseSearchEntry_Update", function(row)
    if not F.enabled or ns.db.groupfinder == false then return end
    Step("row", F.Row, F, row)
    Step("headings", F.Sweep, F)
  end)
  local f = _G.LFGBrowseFrame
  if type(f) == "table" and f.HookScript then
    f:HookScript("OnShow", function()
      if F.enabled and ns.db.groupfinder ~= false then Step("headings", F.Sweep, F) end
    end)
  end
end

function F:Enable()
  self.enabled = true
  local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
  if (loaded and loaded(self.ADDON)) or type(_G.LFGBrowseSearchEntry_Update) == "function" then
    self:Hook()
    return
  end
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("ADDON_LOADED")
  ev:SetScript("OnEvent", function(frame, _, name)
    if name ~= F.ADDON then return end
    frame:UnregisterEvent("ADDON_LOADED")
    F:Hook()
  end)
end

FUI:Register(F)
