-- VoltUI · Settings pages
-- What the settings window shows: every page, in sidebar order, each a list of cards made of
-- rows (see Controls.lua), with the `io` that reads and writes its settings.
--
-- A page: { key, title, group, desc, needs, part, sections(), io(), copy(), reset(), actions,
--           wide, keywords }
--   needs:   the part of VoltUI it belongs to (ns[needs]); while that's off the page shows a switch
--            to turn it on instead. A card can say the same for itself (combined pages).
--   part:    the setting that turns that part on (it needs a reload)
--   copy():  where its settings can be copied from: { { key, name, get(def) } }
--   reset(): puts the page back to its defaults
-- A row's store says where its value lives: nothing for the page's own settings, "db" for a
-- VoltUI-wide one, "part" for a part's on switch (needs a reload), others as each page says.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style

local P = { list = {}, byKey = {} }
ns.Pages = P

local function Add(page)
  P.list[#P.list + 1] = page
  P.byKey[page.key] = page
  return page
end

-- Cards another add-on adds to one of VoltUI's pages: fn() gives a list of cards, shown
-- after the page's own. Rows in them work as the page's own do (its io, `after`, `when`).
function P.Extend(key, fn)
  local page = P.byKey[key]
  if not page then return false end
  local function wrap(orig)
    return function(...)
      local out = orig(...)
      local ok, more = pcall(fn)
      if ok and type(more) == "table" and type(out) == "table" then
        for _, c in ipairs(more) do out[#out + 1] = c end
      end
      return out
    end
  end
  page.sections = wrap(page.sections)
  if page.searchSections then page.searchSections = wrap(page.searchSections) end
  P.reloadKeys = nil
  return true
end

-- A whole page of another add-on's, put after the page keyed
-- `after` (at the end without one). Its `part` tile on Home opens it.
function P.AddPage(page, after)
  if P.byKey[page.key] then return P.byKey[page.key] end
  local at = #P.list + 1
  for i, p in ipairs(P.list) do
    if p.key == after then at = i + 1 end
  end
  table.insert(P.list, at, page)
  P.byKey[page.key] = page
  if page.part and P.PART_PAGE then P.PART_PAGE[page.part] = page.key end
  P.reloadKeys = nil
  return page
end

-- Pages that share one sidebar entry as tabs (see P.TABS), for pages added with P.AddPage.
function P.AddTab(tab)
  for _, t in ipairs(P.TABS) do
    if t.key == tab.key then return t end
  end
  tab.names = tab.names or {}
  P.TABS[#P.TABS + 1] = tab
  for _, key in ipairs(tab.pages) do P.tabOf[key] = tab end
  return tab
end

-- Buttons another add-on adds to the Home page's launcher, after the one keyed `after`.
P.launchers = {}
function P.AddLauncher(item, after)
  for _, it in ipairs(P.launchers) do
    if it.item.key == item.key then return end
  end
  P.launchers[#P.launchers + 1] = { item = item, after = after }
end

local function E() return ns.EditMode end

-- A row's io, with the stores every page shares handled here.
local function Same(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return a == b end
  for k, v in pairs(a) do if not Same(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end
P.Same = Same

local function Copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = Copy(x) end
  return t
end

-- Settings that aren't really settings: which bar a page is showing, a preview, a part's switch.
local NOT_SETTINGS = { pick = true, sim = true, preview = true, menuButton = true, part = true }

-- This session's changes, newest last, for the footer's Undo last (since 1.61.0). A slider
-- dragged through many values in a row is one change.
P.log = {}
P.logCount = 0

local function Wrap(io)
  local get, set, changed, blocked = io.get, io.set, io.changed, io.blocked
  local w = {}
  -- A setting's default, where the page knows it.
  function w.default(def)
    if NOT_SETTINGS[def.store or ""] then return nil end
    if def.store == "db" then return FUI.defaults[def.key] end
    if io.default then return io.default(def) end
    return nil
  end
  function w.isChanged(def)
    if not def.key or def.nocopy then return false end
    local d = w.default(def)
    if d == nil then return false end
    local v = w.get(def)
    if type(d) == "number" and type(v) == "number" then return math.abs(d - v) > 1e-6 end
    return not Same(v, d)
  end
  function w.get(def)
    if def.store == "db" then return ns.db[def.key] end
    if def.store == "part" then return ns.db[def.key] ~= false end
    return get(def)
  end
  function w.set(def, v)
    if not P.quiet and def.key ~= nil and not NOT_SETTINGS[def.store or ""] then
      local old = Copy(w.get(def))
      local last = P.log[#P.log]
      local page = E() and E().tab
      local now = GetTime and GetTime() or 0
      -- a slider dragged or wheeled through values is one change; anything else is its own
      if last and def.kind == "step" and last.def == def and last.page == page and now - last.t < 2 then
        last.t = now
      elseif not Same(old, v) then
        P.log[#P.log + 1] = { def = def, io = w, old = old, page = page, t = now, label = def.label }
        P.logCount = P.logCount + 1
        while #P.log > 50 do table.remove(P.log, 1) end
      end
    end
    if def.store == "db" or def.store == "part" then
      ns.db[def.key] = v
    else
      set(def, v)
    end
  end
  -- Switches that need a reload are noticed by FUI:ReloadPending, which knows how each was when
  -- the game started, so switching one back takes the reload away again.
  function w.changed(def)
    if def.store == "part" then
      -- nothing more until the reload
    elseif def.store == "db" and def.key == "font" then
      S.ApplyFonts()
      FUI:Refresh()
    elseif def.store == "db" and (def.key == "alpha" or def.key == "glow" or def.key == "common") then
      FUI:Refresh()
    elseif changed then
      changed(def)
    end
    if def.after then def.after(def) end
    E():RefreshPage()
  end
  function w.blocked(def)
    if def and (def.store == "part" or def.free) then return false end
    return blocked and blocked(def) or false
  end
  return w
end
P.Wrap = Wrap

local function InCombat() return InCombatLockdown() end
local function Never() return false end

-- The newest change back (the footer's Undo last). False if there's none, or it can't be
-- undone right now (in combat, for frames that resize).
function P.UndoLast()
  local it = P.log[#P.log]
  if not it then return false end
  if it.io.blocked(it.def) then return false end
  table.remove(P.log)
  P.quiet = true
  it.io.set(it.def, Copy(it.old))
  P.quiet = nil
  it.io.changed(it.def)
  return it
end

-- Writes that aren't one change of yours (Reset, Copy from, their undos) don't go in the log.
function P.Quietly(fn, ...)
  P.quiet = true
  local ok, err = pcall(fn, ...)
  P.quiet = nil
  if not ok then error(err, 0) end
end

-- VoltUI-wide settings, with something to run after a change.
local function DbIO(after)
  return {
    default = function(def) return FUI.defaults[def.key] end,
    get = function(def) return ns.db[def.key] end,
    set = function(def, v) ns.db[def.key] = v end,
    changed = function(def) if after then after(def) end end,
    blocked = Never,
  }
end
P.DbIO = DbIO

local function OnOff(v) return v and "on" or "off" end

------------------------------------------------------------------------
-- Choices used on several pages
------------------------------------------------------------------------

local NAME_MODES = { { key = "full", name = "Full" }, { key = "first", name = "First" }, { key = "off", name = "Hidden" } }
local PORTRAITS = { { key = "off", name = "Off" }, { key = "2d", name = "Flat" }, { key = "3d", name = "3D" } }
local SIDES = { { key = "left", name = "Left" }, { key = "right", name = "Right" } }
local ELITE = { { key = "off", name = "Off" }, { key = "border", name = "Border" }, { key = "glow", name = "Glow" } }
local PREVIEW = {
  { key = false, name = "Normal" }, { key = "elite", name = "Elite" }, { key = "rare", name = "Rare" },
  { key = "rareelite", name = "R. Elite" }, { key = "worldboss", name = "Boss" },
}
local GROW_X = { { key = "right", name = "Right" }, { key = "left", name = "Left" } }
local GROW_Y = { { key = "up", name = "Up" }, { key = "down", name = "Down" } }
local TEXT_MODES = { { key = "always", name = "Always" }, { key = "hover", name = "Hover" }, { key = "off", name = "Off" } }
local BAR_MODES = {
  { key = "always", name = "Always" }, { key = "combat", name = "In combat" }, { key = "peace", name = "No combat" },
}
-- Fading is its own setting since 1.80.0, so it goes with any of the three above.
local BAR_FADES = {
  { key = "off", name = "Never" }, { key = "hover", name = "Until hovered" }, { key = "combat", name = "Out of combat" },
}
local BAR_FADE_TIP = "Until hovered: faded until the mouse is over it. Out of combat: solid for the whole of a fight, faded outside one until the mouse is over it."
local function BarFades(c) return c.fade == "hover" or c.fade == "combat" end
local NAME_COLORS = { { key = "white", name = "White" }, { key = "class", name = "Class" } }
local TARGET_BORDER = { { key = "accent", name = "Blue" }, { key = "white", name = "White" }, { key = "off", name = "Off" } }
local PLATE_COLORS = { { key = "volt", name = "VoltUI's" }, { key = "game", name = "Game's" } }
local THREAT = { { key = "off", name = "Off" }, { key = "tank", name = "Tank" }, { key = "dps", name = "Damage" } }
local HP_TEXT = {
  { key = "game", name = "The game's" }, { key = "off", name = "Off" }, { key = "pct", name = "Percent" },
  { key = "num", name = "Number" }, { key = "both", name = "Number and %" },
}
local TARGET_TEXT = {
  { key = "same", name = "The same" }, { key = "off", name = "Off" }, { key = "pct", name = "Percent" },
  { key = "num", name = "Number" }, { key = "both", name = "Number and %" },
}
local TEXT_POS = { { key = "left", name = "Left" }, { key = "center", name = "Centre" }, { key = "right", name = "Right" } }
local PLATE_NAME = { { key = "game", name = "Game's" }, { key = "white", name = "White" }, { key = "class", name = "Class" } }
local AURA_TIMER = { { key = "short", name = "Short" }, { key = "all", name = "All" }, { key = "off", name = "Off" } }
local AURA_BORDER = { { key = "type", name = "By type" }, { key = "black", name = "Black" } }

local function Scale(label, key, when, extra)
  local def = { kind = "step", label = label, key = key, min = 0.6, max = 2, step = 0.05, fmt = "%.2f", when = when }
  for k, v in pairs(extra or {}) do def[k] = v end
  return def
end

------------------------------------------------------------------------
-- Home: every part of VoltUI as a tile, and the things reached for most (since 1.38.0)
------------------------------------------------------------------------

-- The page each part's tile opens.
local PART_PAGE = {
  frames = "player", castbar = "cast", groups = "party", bars = "bars", nameplates = "plates",
  bags = "bags", loot = "loot", tooltips = "loot", junk = "loot", map = "maps", worldmap = "maps",
  questie = "questie", buffs = "buffs", timers = "timers", chat = "general", links = "general",
}
P.PART_PAGE = PART_PAGE
-- Parts with no page of their own, by the heading their tile sits under.
local PART_GROUP = { drawer = "World", rolls = "Items", guildbank = "Items", groupfinder = "More", chat = "More", links = "More" }
-- On the spacing scale (since 1.62.2): 12 in from the card's edges and above and below the
-- grid, 8 between tiles, 12 above each heading and 8 under it.
local TILE_H, TILE_GAP, TILE_MIN_W, GROUP_H, GROUP_GAP, GRID_PAD = 48, 8, 196, 21, 12, 8

-- What a part is doing, in a few words, and whether that's worth a second look.
local function PartState(m)
  local want = ns.db[m.key] ~= false
  if m.enabled and m.yielded then return ("%s draws these"):format(tostring(m.yielded)), true end
  if want and m.enabled then return "On", false end
  if want then return "On after a reload", true end
  if m.enabled then return "Off after a reload", true end
  return "Off", false
end
P.PartState = PartState

-- A part's heading on Home: its page's sidebar heading, or its own.
local function PartGroup(m)
  if PART_GROUP[m.key] then return PART_GROUP[m.key] end
  local page = PART_PAGE[m.key] and P.byKey[PART_PAGE[m.key]]
  local g = page and page.group or "More"
  if g == "VoltUI" or g == "Other add-ons" then g = "More" end
  return g
end
P.PartGroup = PartGroup

-- Every part as a tile, under the sidebar's headings (since 1.61.0): an icon, its name, what
-- it's doing, and its switch. A part that's off fades to grey; one standing aside for another
-- add-on gets an amber edge; one waiting on a reload says so in blue. Clicking a tile opens
-- the part's page. Each switch is a row like any other, so search finds it.
local function PartTiles()
  local groups, byGroup = {}, {}
  local parts = {}
  for _, m in ipairs(FUI.modules) do
    if m.key ~= "icon" then
      local g = PartGroup(m)
      if not byGroup[g] then
        byGroup[g] = {}
      end
      table.insert(byGroup[g], m)
      parts[#parts + 1] = { kind = "toggle", label = m.name, key = m.key, store = "part",
        keywords = "part module on off reload", tip = "Switching a part on or off takes a reload." }
    end
  end
  for _, g in ipairs(P.GROUPS) do
    if g ~= "VoltUI" and byGroup[g] then groups[#groups + 1] = g end
  end
  local partOf = {}
  for _, d in ipairs(parts) do partOf[d.key] = d end
  local IN = S.INSET
  local function Cols(width) return math.max(1, math.floor((width - 2 * IN + TILE_GAP) / (TILE_MIN_W + TILE_GAP))) end
  local function Height(width)
    local cols, h = Cols(width), GRID_PAD
    for i, g in ipairs(groups) do
      if i > 1 then h = h + GROUP_GAP end
      h = h + GROUP_H + math.ceil(#byGroup[g] / cols) * (TILE_H + TILE_GAP) - TILE_GAP
    end
    return h + GRID_PAD
  end
  return { kind = "custom", label = "", parts = parts, heightFor = Height, height = Height(690 - 22),
    build = function(r, width)
      local cols = Cols(width)
      local w = math.floor((width - 2 * IN - (cols - 1) * TILE_GAP) / cols)
      r.subRows, r.tiles = {}, {}
      local y = GRID_PAD
      for gi, g in ipairs(groups) do
        if gi > 1 then y = y + GROUP_GAP end
        local head = S.UIText(r, nil, "LEFT", nil, 10)
        S.Mono(head, 10, nil, "medium") -- small capitals, as in the sidebar
        head:SetPoint("TOPLEFT", r, "TOPLEFT", IN, -y)
        head:SetText(g:upper())
        local hc = S.UI.Cat(g)
        head:SetTextColor(hc[1], hc[2], hc[3], 0.85)
        y = y + GROUP_H
        for i, m in ipairs(byGroup[g]) do
          local t = CreateFrame("Button", nil, r)
          t:SetSize(w, TILE_H)
          local col, line = (i - 1) % cols, math.floor((i - 1) / cols)
          t:SetPoint("TOPLEFT", r, "TOPLEFT", IN + col * (w + TILE_GAP), -(y + line * (TILE_H + TILE_GAP)))
          t.fill = S.Tex(t, "BACKGROUND", -4)
          t.fill:SetAllPoints()
          S.Round(t.fill, S.UI.r.button)
          t.edges = S.RoundEdges(t, "BACKGROUND", -3, t, S.UI.r.button)
          S.Highlight(t, 0.04, S.UI.r.button)
          -- icon, then the name over what it's doing, as one block centred top to bottom;
          -- the switch at the right, centred too
          t.icon = S.Icon(t, m.key, 20)
          t.icon:SetPoint("LEFT", 12, 0)
          t.name = S.UIText(t, nil, "LEFT", nil, 13)
          t.name:SetPoint("BOTTOMLEFT", t, "LEFT", 44, 1)
          t.name:SetPoint("BOTTOMRIGHT", t, "RIGHT", -56, 1)
          t.name:SetText(m.name)
          t.state = S.UIText(t, nil, "LEFT", nil, 11)
          t.state:SetPoint("TOPLEFT", t, "LEFT", 44, -2)
          t.state:SetPoint("TOPRIGHT", t, "RIGHT", -56, -2)
          t.dot = S.Disc(S.Tex(t, "OVERLAY"), 6)
          t.dot:SetSize(6, 6)
          t.dot:SetPoint("TOPRIGHT", -6, -6)
          S.Paint(t.dot, S.UI.info[1], S.UI.info[2], S.UI.info[3], 1) -- waits on a reload
          -- The switch is a row of its own, its label hidden: the tile shows the name.
          local row = S.Row(t, partOf[m.key], 26 + 2 * IN, r.io)
          row:SetPoint("RIGHT", t, "RIGHT", 0, 0)
          row.label:SetText("")
          if row.tipZone then row.tipZone:Hide() end
          local page = PART_PAGE[m.key]
          t.page = page
          t:SetScript("OnClick", function() if page then ns.EditMode:Select(page) end end)
          t:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(m.name, 1, 1, 1)
            GameTooltip:AddLine((PartState(m)), 0.75, 0.77, 0.8)
            GameTooltip:AddLine(page and "Click for its settings. The switch turns it on or off (takes a reload)."
              or "The switch turns it on or off (takes a reload).", 0.6, 0.63, 0.68, true)
            GameTooltip:Show()
          end)
          t:SetScript("OnLeave", function() GameTooltip:Hide() end)
          t.mod = m
          r.subRows[#r.subRows + 1], r.tiles[#r.tiles + 1] = row, t
        end
        y = y + math.ceil(#byGroup[g] / cols) * (TILE_H + TILE_GAP) - TILE_GAP
      end
    end,
    refresh = function(r)
      local T = S.UI
      for i, t in ipairs(r.tiles or {}) do
        r.subRows[i]:Refresh()
        local m = t.mod
        local text, note = PartState(m)
        local want = ns.db[m.key] ~= false
        local aside = m.enabled and m.yielded
        local live = m.enabled and not m.yielded
        local cat = T.Cat(PartGroup(m))
        t.state:SetText(text)
        t.dot:SetShown(note and not aside and true or false)
        if aside then
          -- standing aside for another add-on: amber, so it reads as a warning, not an error
          S.Paint(t.fill, T.warn[1], T.warn[2], T.warn[3], 0.06)
          S.ColorEdges(t.edges, T.warn[1], T.warn[2], T.warn[3], 0.75)
          t.icon:SetColor(T.warn[1], T.warn[2], T.warn[3], 1)
          t.name:SetTextColor(T.text[1], T.text[2], T.text[3])
          t.state:SetTextColor(T.warn[1], T.warn[2], T.warn[3])
        elseif want then
          -- on: its heading's colour, and "On" in green (blue while it waits on a reload)
          S.Paint(t.fill, T.raised[1], T.raised[2], T.raised[3], live and 1 or 0.7)
          S.ColorEdges(t.edges, T.soft[1], T.soft[2], T.soft[3], 0.9)
          t.icon:SetColor(cat[1], cat[2], cat[3], live and 1 or 0.6)
          t.name:SetTextColor(T.text[1], T.text[2], T.text[3])
          local c = note and T.info or T.ok
          t.state:SetTextColor(c[1], c[2], c[3])
        else
          -- off: the tile steps back, grey and flat, and "Off" in red
          S.Paint(t.fill, 0, 0, 0, 0.18)
          S.ColorEdges(t.edges, T.soft[1], T.soft[2], T.soft[3], 0.45)
          t.icon:SetColor(T.off[1], T.off[2], T.off[3], 0.7)
          t.name:SetTextColor(T.off[1], T.off[2], T.off[3])
          local c = note and T.info or T.bad
          t.state:SetTextColor(c[1], c[2], c[3], note and 1 or 0.85)
        end
      end
    end }
end

-- The things reached for most, as a grid of buttons with an icon over the name (since 1.61.0;
-- three rows of text buttons before). Since 1.62.2 there's no second line of "how else to get
-- there" (the hover says it), and the icon and name sit centred with even room around them.
local LAUNCH_H, LAUNCH_GAP, LAUNCH_MIN_W, LAUNCH_ICON = 64, 8, 118, 20
local function Launcher()
  local list = {
    { key = "move", icon = "move", text = function() return FUI.unlocked and "Stop moving" or "Move frames" end, how = "/volt edit",
      fn = function() FUI:SetUnlocked(not FUI.unlocked) end, tip = "Drag VoltUI's frames around the screen" },
    { key = "keys", icon = "keys", text = "Quick keybinds", when = function() return ns.ActionBars.enabled end,
      fn = function() ns.ActionBars:QuickKeys() end, tip = "Hover a button and press a key to bind it" },
    { key = "setup", icon = "layouts", text = "Layouts", how = "/volt setup", fn = function() ns.Setup:Open() end,
      tip = "A few ready-made places for your frames. Nothing moves until you pick one, and Undo puts them back." },
    { key = "look", icon = "look", text = "Font and look", fn = function() ns.EditMode:Select("general") end },
    { key = "share", icon = "share", text = "Back up", fn = function() ns.EditMode:Select("share") end,
      tip = "Copy your settings out as text, or bring them back in" },
    { key = "errors", icon = "errors", text = function() return ns.Errors and ns.Errors.unseen and "Errors: new" or "Errors" end, how = "/volt errors",
      fn = function() ns.EditMode:Select("errors") end },
  }
  for _, extra in ipairs(P.launchers) do
    local at = #list + 1
    for i, it in ipairs(list) do
      if it.key == extra.after then at = i + 1 end
    end
    table.insert(list, at, extra.item)
  end
  local IN = S.INSET
  local function Cols(width) return math.max(2, math.min(#list, math.floor((width - 2 * IN + LAUNCH_GAP) / (LAUNCH_MIN_W + LAUNCH_GAP)))) end
  local function Height(width) return math.ceil(#list / Cols(width)) * (LAUNCH_H + LAUNCH_GAP) - LAUNCH_GAP + 2 * GRID_PAD end
  return { kind = "custom", label = "", heightFor = Height, height = Height(690 - 22),
    keywords = "move frames keybinds layouts rare list treasure list recent alerts back up errors font look windows",
    build = function(r, width)
      local cols = Cols(width)
      local w = math.floor((width - 2 * IN - (cols - 1) * LAUNCH_GAP) / cols)
      r.buttons = {}
      for i, it in ipairs(list) do
        local b = CreateFrame("Button", nil, r)
        b:SetSize(w, LAUNCH_H)
        local col, line = (i - 1) % cols, math.floor((i - 1) / cols)
        b:SetPoint("TOPLEFT", r, "TOPLEFT", IN + col * (w + LAUNCH_GAP), -(GRID_PAD + line * (LAUNCH_H + LAUNCH_GAP)))
        b.fill = S.Tex(b, "BACKGROUND", -4)
        b.fill:SetAllPoints()
        S.Round(b.fill, S.UI.r.card)
        S.Paint(b.fill, S.UI.raised[1], S.UI.raised[2], S.UI.raised[3], 1)
        b.edges = S.RoundEdges(b, "BACKGROUND", -3, b, S.UI.r.card)
        S.ColorEdges(b.edges, S.UI.soft[1], S.UI.soft[2], S.UI.soft[3], 1)
        S.Highlight(b, 0.04, S.UI.r.card)
        -- the icon and the name as one block, 8 apart, centred top to bottom
        b.icon = S.Icon(b, it.icon, LAUNCH_ICON)
        b.icon:SetPoint("BOTTOM", b, "CENTER", 0, 1)
        b.text = S.UIText(b, nil, "CENTER", nil, 12)
        b.text:SetPoint("TOPLEFT", b, "LEFT", 8, -7)
        b.text:SetPoint("TOPRIGHT", b, "RIGHT", -8, -7)
        b:SetScript("OnClick", function()
          if it.when and not it.when() then return end
          it.fn(b)
        end)
        b:SetScript("OnEnter", function(self)
          S.ColorEdges(self.edges, S.UI.primaryEdge[1], S.UI.primaryEdge[2], S.UI.primaryEdge[3], 1)
          local why = it.when and not it.when() and "Needs that part of VoltUI on." or nil
          if not it.tip and not it.how and not why then return end
          GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
          GameTooltip:SetText(type(it.text) == "function" and it.text() or it.text, 1, 1, 1)
          if it.tip then GameTooltip:AddLine(it.tip, 0.75, 0.77, 0.8, true) end
          if it.how then GameTooltip:AddLine("Or type " .. it.how, 0.55, 0.58, 0.62) end
          if why then GameTooltip:AddLine(why, 1, 0.82, 0.3, true) end
          GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self)
          S.PillOn(self, self.lit) -- puts the edges back
          GameTooltip:Hide()
        end)
        b.bg = b.fill
        b.item = it
        r.buttons[i] = b
      end
    end,
    refresh = function(r)
      for _, b in ipairs(r.buttons or {}) do
        local it = b.item
        b.text:SetText(type(it.text) == "function" and it.text() or it.text)
        local off = it.when and not it.when()
        b:SetAlpha(off and 0.4 or 1)
        b.lit = it.key == "move" and FUI.unlocked and true or false
        S.PillOn(b, b.lit)
        b.text:SetTextColor(S.UI.text[1], S.UI.text[2], S.UI.text[3])
        if b.lit then b.icon:SetColor(S.UI.accent[1], S.UI.accent[2], S.UI.accent[3], 1) else b.icon:SetColor(S.UI.sub[1], S.UI.sub[2], S.UI.sub[3], 1) end
      end
    end }
end

-- The three presets (since 1.100.0): Centre, Healer and Top left as cards, each drawn as a
-- little screen with a Use button. They're Setup.lua's layouts, so the Layouts window, Undo and
-- "only out of combat" are all the same thing.
local PRESET_H, PRESET_GAP, PRESET_MIN_W, PRESET_THUMB_H, PRESET_FOOT = 136, 8, 170, 90, 30
local function PaintPresets(r)
  local T, db = S.UI, ns.db
  local trying = type(db.setupUndo) == "table"
  local used = trying and db.setupUsed or nil
  local name
  for _, c in ipairs(r.cards or {}) do
    local on = c.layout.key == used
    if on then name = c.layout.name end
    c.use.text:SetText(on and "In use" or "Use")
    S.PillOn(c.use, on)
    S.ColorEdges(c.edges, on and T.accent[1] or T.soft[1], on and T.accent[2] or T.soft[2], on and T.accent[3] or T.soft[3], on and 0.9 or 1)
  end
  if not r.note then return end
  r.note:SetText(r.say or name and ("Using %s. Undo puts your frames and bars back where they were."):format(name)
    or "Nothing moves until you press Use. A preset places your frames and lays out action bars 2 and 3.")
  local c = r.say and T.warn or T.sub
  r.note:SetTextColor(c[1], c[2], c[3])
  r.undo:SetShown(trying)
end
local function Presets()
  local Su = ns.Setup
  local list = Su:Presets()
  local IN = S.INSET
  local function Cols(width) return math.max(1, math.min(#list, math.floor((width - 2 * IN + PRESET_GAP) / (PRESET_MIN_W + PRESET_GAP)))) end
  local function Height(width)
    return math.ceil(#list / Cols(width)) * (PRESET_H + PRESET_GAP) - PRESET_GAP + 2 * GRID_PAD + PRESET_FOOT
  end
  return { kind = "custom", label = "", heightFor = Height, height = Height(690 - 22),
    keywords = "presets layouts healer top left centre center starting frames bars arrange",
    build = function(r, width)
      local cols = Cols(width)
      local w = math.floor((width - 2 * IN - (cols - 1) * PRESET_GAP) / cols)
      r.cards = {}
      for i, l in ipairs(list) do
        local c = CreateFrame("Frame", nil, r)
        c:SetSize(w, PRESET_H)
        local col, line = (i - 1) % cols, math.floor((i - 1) / cols)
        c:SetPoint("TOPLEFT", r, "TOPLEFT", IN + col * (w + PRESET_GAP), -(GRID_PAD + line * (PRESET_H + PRESET_GAP)))
        c.fill = S.Tex(c, "BACKGROUND", -4)
        c.fill:SetAllPoints()
        S.Round(c.fill, S.UI.r.card)
        S.Paint(c.fill, S.UI.raised[1], S.UI.raised[2], S.UI.raised[3], 1)
        c.edges = S.RoundEdges(c, "BACKGROUND", -3, c, S.UI.r.card)
        c.thumb = Su.Thumb(c, l, w - 16, PRESET_THUMB_H)
        c.thumb:SetPoint("TOP", c, "TOP", 0, -8)
        c.name = S.UIText(c, nil, "LEFT", nil, 13)
        c.name:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 10, 13)
        c.name:SetText(l.name)
        c.name:SetTextColor(S.UI.text[1], S.UI.text[2], S.UI.text[3])
        c.use = S.PillButton(c, "Use", 68, function()
          if InCombatLockdown() then
            r.say = "Frames can't move in combat. Try again after the fight."
          else
            r.say = nil
            Su:Apply(l.key)
          end
          PaintPresets(r)
        end, false, l.text)
        c.use:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -8, 8)
        c.layout = l
        r.cards[i] = c
      end
      r.undo = S.PillButton(r, "Undo", 70, function()
        if InCombatLockdown() then
          r.say = "Frames can't move in combat. Try again after the fight."
        else
          r.say = nil
          Su:Undo()
        end
        PaintPresets(r)
      end, false, "Everything back where it was before you tried a preset")
      r.undo:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -IN, GRID_PAD)
      r.note = S.UIText(r, nil, "LEFT", nil, 12)
      r.note:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", IN, GRID_PAD + 4)
      r.note:SetPoint("RIGHT", r, "RIGHT", -(IN + 78), 0)
    end,
    refresh = function(r)
      r.say = nil
      PaintPresets(r)
    end }
end

Add({
  key = "home", title = "Home", group = "VoltUI", wide = "all",
  desc = "Every part of VoltUI and what it's doing, and the things you reach for most.",
  keywords = "parts modules on off reload overview start",
  io = function() return DbIO() end,
  sections = function()
    return {
      { title = "Launch", Launcher() },
      { title = "Presets", Presets() },
      { title = "Parts of VoltUI", PartTiles() },
    }
  end,
})

------------------------------------------------------------------------
-- General
------------------------------------------------------------------------

Add({
  key = "general", title = "General", group = "VoltUI",
  desc = "VoltUI's look everywhere, the grid for moving frames, and the minimap icon.",
  keywords = "font bar texture statusbar opacity glow minimap icon grid snap look",
  io = function() return DbIO() end,
  sections = function()
    return {
      {
        title = "Look",
        { kind = "cycle", stepper = true, label = "Font", key = "font", store = "db", list = function() return S.FONTS end,
          fontFace = function(v) local f = S.Font(v) return f and f.path end,
          tip = "VoltUI's font, everywhere except its settings windows, which stay in Inter. The Fonts page gives any text a font of its own." },
        { kind = "cycle", stepper = true, label = "Bar texture", key = "barTexture", store = "db", list = function() return S.BarTextures() end,
          after = function() S.RefreshBarTextures() end,
          tip = "The fill of VoltUI's bars: unit, party and raid frames, castbars, XP, timers and the rest. The nameplates have their own." },
        { kind = "step", label = "Panel opacity", key = "alpha", store = "db", min = 0, max = 1, step = 0.05, fmt = "%.2f",
          tip = "How see-through VoltUI's panels are, from 0 (clear) to 1 (solid)." },
        { kind = "step", label = "Rarity glow", key = "glow", store = "db", min = 0, max = 1, step = 0.1, fmt = "%.1f",
          tip = "How strongly items glow in their rarity's colour in your bags and the loot window. 0 leaves just the outline." },
        { kind = "toggle", label = "Glow on common items", key = "common", store = "db" },
        { kind = "toggle", label = "Crisp borders", key = "pixelEdges", store = "db", keywords = "pixel perfect border line sharp soft blurry thin",
          tip = "Border lines are a whole number of screen pixels thick, whatever your UI scale, so they look sharp and even. Off gives the lines as they were before 1.101.19.",
          after = function() S.RefreshEdges() end },
      },
      {
        title = "Web links", needs = "Web links", part = "links",
        { kind = "note", lines = 3, text = "Alt-click an item (bags, character, loot, vendors, a chat link) or a quest (quest log, chat) for its web page. The address comes up selected: Ctrl+C, then paste it into your browser." },
        { kind = "cycle", label = "Site", key = "linkSite", store = "db", segWidth = 190,
          list = function() return ns.Links.SITES end,
          when = function() return ns.Links and ns.Links.enabled end, whyOff = "Needs the Web links part on.",
          tip = "Wowhead's WoW Forever database, or ForeverDB's. Both have Forever's own new items and quests. NPCs always go to Wowhead." },
      },
      {
        title = "Chat", needs = "Chat", part = "chat",
        { kind = "step", label = "Panel opacity", key = "chatAlpha", store = "db", min = 0.2, max = 0.9, step = 0.05, fmt = "%.2f",
          when = function() return ns.Chat and ns.Chat.enabled end, whyOff = "Needs the Chat part on.",
          after = function() if ns.Chat.enabled then ns.Chat:Refresh() end end,
          tip = "How solid the panel behind the chat windows and their buttons is." },
        { kind = "toggle", label = "Web addresses as links", key = "chatUrls", store = "db", keywords = "url link web address http www click copy",
          when = function() return ns.Chat and ns.Chat.enabled end, whyOff = "Needs the Chat part on.",
          after = function() if ns.Chat.enabled then ns.Chat:Extras() end end,
          tip = "A web address someone posts becomes a link. Click it for a box to copy it from. Turning it off stops new messages being changed." },
        { kind = "toggle", label = "Copy button", key = "chatCopy", store = "db", keywords = "copy chat text select log",
          when = function() return ns.Chat and ns.Chat.enabled end, whyOff = "Needs the Chat part on.",
          after = function() if ns.Chat.enabled then ns.Chat:Extras() end end,
          tip = "A small C in each chat window's top-right corner. Click it for that window's last 500 lines as text you can select and copy. /volt chat copy does the same for the window that's showing." },
        { kind = "note", lines = 3, text = "While moving frames, drag the chat to place it and drag its bottom-right corner to resize it. Until you do, it stays where the game's own Edit Mode has it." },
        { kind = "button", label = "Spot and size", text = "Reset spot", tip = "Back to where the game starts it, at the size it had. The game's Edit Mode places it again from the next reload.",
          when = function() return ns.Chat and ns.Chat.enabled end, whyOff = "Needs the Chat part on.",
          fn = function()
            ns.Chat:ResetSpot()
            ns.EditMode:Toast("The chat is back at the game's spot and size.", nil, nil, 6)
          end },
      },
      {
        title = "Settings window",
        { kind = "step", label = "Text size", key = "uiText", store = "db", min = 11, max = 14, step = 1,
          after = function() FUI:NeedReload() end,
          tip = "The text in VoltUI's settings windows, menus and toolbars. 12 is the usual size. Takes a reload." },
        { kind = "note", lines = 2, text = "Drag the window's bottom-right corner to make it wider or narrower. Right-click any setting to put it back to its default." },
      },
      {
        title = "Moving frames",
        { kind = "toggle", label = "Show a grid", key = "grid", store = "db", after = function() ns.Move:Refresh() end },
        { kind = "toggle", label = "Snap to the grid", key = "snap", store = "db", after = function() ns.Move:Refresh() end,
          tip = "A frame you drop lines up its nearest edge or middle with the nearest grid line." },
        { kind = "toggle", label = "Snap to other frames", key = "snapFrames", store = "db", after = function() ns.Move:Refresh() end,
          tip = "A frame you drop near another frame's edge or middle lines up with it. A yellow line shows while they line up." },
        { kind = "step", label = "Grid size (pixels)", key = "gridSize", store = "db", min = 4, max = 64, step = 4,
          after = function() ns.Move:Refresh() end },
        { kind = "note", lines = 2, text = "Click a frame while moving frames, then use the arrow keys to move it one pixel at a time (Shift: ten)." },
      },
      {
        title = "Minimap icon",
        { kind = "toggle", label = "Show the minimap icon", key = "icon", store = "db",
          after = function() ns.MinimapIcon:SetShown(ns.db.icon ~= false) end },
      },
    }
  end,
})

------------------------------------------------------------------------
-- Fonts (since 1.70.0): the overall font, and a font of its own for any text
------------------------------------------------------------------------

local function FontPath(key)
  local f = key and key ~= "default" and S.Font(key) or S.Font()
  return f and f.path
end

-- A text's choices: the overall font first (named, so you can see what it is), then every font.
local function RoleFonts()
  local list = { { key = "default", name = "Overall: " .. S.Font().name } }
  for _, f in ipairs(S.FONTS) do list[#list + 1] = f end
  return list
end

local function ApplyFontChange()
  S.ApplyFonts()
  FUI:Refresh()
end

local function FontIO()
  return {
    blocked = Never,
    default = function(def) if def.store == "role" then return "default" end end,
    get = function(def)
      local f = S.RoleFont(def.key)
      return f and f.key or "default"
    end,
    set = function(def, v) S.SetRoleFont(def.key, v ~= "default" and v or nil) end,
    changed = ApplyFontChange,
  }
end

Add({
  key = "fonts", title = "Fonts", group = "VoltUI",
  desc = "One font for all of VoltUI, and a different one for any text you like. Settings windows stay in Inter.",
  keywords = "font fonts typeface text numbers names health power cooldown timer keybind nameplate tooltip inter lato teko titillium pt sans narrow barlow",
  io = function() return FontIO() end,
  sections = function()
    local cards = {
      {
        title = "Overall",
        { kind = "cycle", stepper = true, label = "Font", key = "font", store = "db", list = function() return S.FONTS end,
          fontFace = FontPath, tip = "VoltUI's font, for every text below that hasn't got one of its own." },
        { kind = "note", lines = 2, text = "Each text below uses the overall font until you pick another. Right-click one to put it back." },
      },
    }
    local byGroup = {}
    for _, role in ipairs(S.FONT_ROLES) do
      local card = byGroup[role.group]
      if not card then
        card = { title = role.group }
        byGroup[role.group] = card
        cards[#cards + 1] = card
      end
      card[#card + 1] = { kind = "cycle", stepper = true, label = role.name, key = role.key, store = "role",
        list = RoleFonts, fontFace = FontPath }
    end
    return cards
  end,
  reset = function()
    if ns.db then ns.db.fontRoles = nil end
    ApplyFontChange()
  end,
  resetTip = "Every text back to the overall font. The overall font stays as it is.",
})

------------------------------------------------------------------------
-- Unit frames
------------------------------------------------------------------------

local function UnitIO(tab)
  return {
    blocked = InCombat,
    default = function(def)
      local d = ns.UnitFrames.DEFAULTS[tab]
      return d and d[def.key]
    end,
    get = function(def)
      if def.store == "preview" then return ns.UnitFrames.previewClass or false end
      if def.row then
        -- a row's place among this frame's rows, counted from the top
        local U = ns.UnitFrames
        for i, k in ipairs(U:Order(U:Cfg(tab), tab == "player")) do
          if k == def.row then return i end
        end
      end
      return ns.UnitFrames:Cfg(tab)[def.key]
    end,
    set = function(def, v)
      if def.store == "preview" then
        ns.UnitFrames.previewClass = v or nil
      elseif def.row then
        ns.UnitFrames:SetRow(ns.UnitFrames:Cfg(tab), def.row, v, tab == "player")
      else
        ns.UnitFrames:Cfg(tab)[def.key] = v
      end
    end,
    changed = function(def)
      local U, C = ns.UnitFrames, ns.Castbar
      if def.key == "focusCast" then
        C:SetFocusBar(ns.db.focusCast)
      elseif def.key == "targetCast" then
        C:SetTargetBar(ns.db.targetCast)
      elseif def.key == "targetCastH" then
        C:LayoutAll()
      else
        local f = U.frames[tab]
        U:Layout(f)
        U:Update(f)
        if def.key == "scale" then U:Place() end
      end
    end,
  }
end

-- (1.96.0) Click a part of the frame in the preview and its settings come together in one
-- card above the others. What each part's card holds, by setting, in order: a name alone,
-- or { name, label } where the row's own label only makes sense on its usual card.
local function Place4(piece) return piece .. "At", piece .. "Align", piece .. "X", piece .. "Y" end
local PART_ROWS = {
  frame = { "width", "scale", "border" },
  panel = { { "rowName", "Place among the rows" }, { "nameSize", "Height, from the name's font size" } },
  hp = { { "hpHeight", "Height" }, { "rowHp", "Place among the rows" }, "classColor", "heals" },
  pw = { { "power", "Show" }, "pwHeight", { "rowPw", "Place among the rows" }, "tick", "altMana" },
  portrait = { "portrait", "portraitSide" },
  name = { { "name", "Shows" }, { "nameSize", "Font size" }, Place4("name") },
  level = { { "level", "Show" }, { "levelSize", "Font size" }, Place4("level") },
  tag = { { "tags", "Show" }, { "tagSize", "Font size" }, Place4("tag") },
  hpText = { { "hpText", "Show" }, { "hpFormat", "Shows" }, "short", { "barSize", "Font size" }, Place4("hpText") },
  hpPct = { { "hpPct", "Show" }, { "hpPctSize", "Font size" }, Place4("hpPct") },
  pwText = { { "pwText", "Show" }, { "pwFormat", "Shows" }, "short", { "pwSize", "Font size" }, Place4("pwText") },
}
for i = 1, 2 do
  local k = "extra" .. i
  PART_ROWS[k] = { k, k .. "At", k .. "Label", { k .. "Size", "Font size" }, k .. "X", k .. "Y" }
end

local FrameSections

-- The picked part's card for page `pageKey`, or nothing with no part picked. `want` maps a
-- part to its settings, `sections` gives the page's own cards (whose rows are copied, so no
-- row is written twice), `parts` names the parts.
local function Pinned(pageKey, want, sections, parts)
  local part = S.Picked(pageKey)
  want = part and want[part]
  if not want then return nil end
  local byKey = {}
  for _, sec in ipairs(sections) do
    for _, row in ipairs(sec) do
      if row.key and not byKey[row.key] then byKey[row.key] = row end
      for _, k in ipairs(row.keys or {}) do -- a row of colour swatches goes by any of them
        if not byKey[k.key] then byKey[k.key] = row end
      end
    end
  end
  local card = { key = part, title = "Selected: " .. (S.PartName(parts, part) or part) }
  local seen = {}
  for _, it in ipairs(want) do
    local key, label = it, nil
    if type(it) == "table" then key, label = it[1], it[2] end
    local row = byKey[key]
    if row and not seen[row] then
      seen[row] = true
      local copy = {}
      for k, v in pairs(row) do copy[k] = v end
      copy.label = label or row.label
      card[#card + 1] = copy
    end
  end
  card[#card + 1] = { kind = "button", label = "Done with it", text = "Deselect", keywords = "",
    tip = "Puts this card away. Clicking the part again in the preview does the same.",
    fn = function() S.Pick(pageKey, nil) end }
  return card
end

local function FramePinned(tab)
  return Pinned(tab, PART_ROWS, FrameSections(tab), ns.UnitFrames.PARTS)
end

function FrameSections(tab)
  local function cfg() return ns.UnitFrames:Cfg(tab) end
  local function on(key) return function() return cfg()[key] end end
  local function portraitOn() return cfg().portrait ~= "off" end
  local function nameOn() return cfg().name ~= "off" end
  local sections = {
    {
      title = "Size",
      { kind = "step", label = "Width", key = "width", min = 80, max = 500, step = 5 },
      { kind = "step", label = "Health bar height", key = "hpHeight", min = 4, max = 60, step = 1 },
      { kind = "step", label = "Scale", key = "scale", min = 0.5, max = 2, step = 0.05, fmt = "%.2f" },
    },
    {
      title = "Border",
      { kind = "cycle", stepper = true, label = "Style", key = "border", list = ns.UnitFrames.BORDERS,
        keywords = "border frame edge outline line plate glass rail tab double hairline none",
        tip = "Hairline: one grey line. Double line: a dark gap and a black line outside it. Glass plate: the see-through plate from the action bars, with the combo points on it. Rail and tab: a gold rail down the left, and the level in a tab above the frame. None: no line." },
    },
    {
      title = "Name and header",
      { kind = "cycle", label = "Name", key = "name", list = NAME_MODES, isText = true },
      { kind = "step", label = "Name font size", key = "nameSize", min = 8, max = 28, step = 1, when = nameOn, whyOff = "Needs the name showing.", isText = true },
      { kind = "toggle", label = "Level", key = "level", isText = true },
      { kind = "step", label = "Level font size", key = "levelSize", min = 8, max = 28, step = 1, when = on("level"), whyOff = "Needs Level on.", isText = true },
      { kind = "toggle", label = "Status tags and raid marker", key = "tags", isText = true },
      { kind = "step", label = "Status tags font size", key = "tagSize", min = 8, max = 28, step = 1, when = on("tags"), whyOff = "Needs Status tags on.", isText = true },
    },
    {
      title = "Health",
      { kind = "toggle", label = "Numbers", key = "hpText", isText = true },
      { kind = "cycle", label = "Numbers show", key = "hpFormat", list = ns.UnitFrames.HP_FORMATS, segWidth = 196, when = on("hpText"),
        whyOff = "Needs Numbers on.", isText = true,
        tip = "Now / most: 2,480 / 4,000. Now: 2,480. Missing: -1,520, and nothing at full health." },
      { kind = "toggle", label = "Percent", key = "hpPct", isText = true },
      { kind = "toggle", label = "Shorten big numbers", key = "short", isText = true, tip = "12.5K rather than 12,500, on health and power." },
      { kind = "step", label = "Numbers font size", key = "barSize", min = 8, max = 28, step = 1, isText = true },
      { kind = "step", label = "Percent font size", key = "hpPctSize", min = 8, max = 28, step = 1, when = on("hpPct"), whyOff = "Needs Percent on.", isText = true },
      { kind = "toggle", label = "Class colours", key = "classColor" },
      { kind = "toggle", label = "Incoming heals and shields", key = "heals",
        tip = "Heals on their way and shields, as their own parts of the health bar up to full health, with a bright edge when there's more than health missing." },
    },
    {
      title = "Power",
      { kind = "toggle", label = "Power bar", key = "power" },
      { kind = "step", label = "Height", key = "pwHeight", min = 2, max = 40, step = 1, when = on("power"), whyOff = "Needs the power bar on." },
      { kind = "toggle", label = "Numbers", key = "pwText", when = on("power"), whyOff = "Needs the power bar on.", isText = true },
      { kind = "cycle", label = "Numbers show", key = "pwFormat", list = ns.UnitFrames.PW_FORMATS, segWidth = 196, isText = true,
        when = function() return cfg().power and cfg().pwText end, whyOff = "Needs the power bar and its numbers on." },
      { kind = "step", label = "Font size", key = "pwSize", min = 8, max = 28, step = 1, when = on("power"), whyOff = "Needs the power bar on.", isText = true },
    },
    {
      title = "Portrait",
      { kind = "cycle", label = "Portrait", key = "portrait", list = PORTRAITS },
      { kind = "cycle", label = "Side", key = "portraitSide", list = SIDES, when = portraitOn, whyOff = "Needs a portrait." },
    },
  }
  -- (1.93.0) The order of the rows, and where each text sits.
  local places = tab == "player" and 4 or 3
  local spots = {}
  for i = 1, places do
    spots[i] = { key = i, name = i == 1 and "1 (top)" or i == places and (i .. " (bottom)") or tostring(i) }
  end
  local order = {
    title = "Order, top to bottom",
    { kind = "cycle", stepper = true, label = "Name panel", key = "rowName", row = "name", list = spots,
      keywords = "order stack rows arrange above below",
      tip = "Where the name panel sits among the rows. It takes the place of the row that had that spot. With no text on it, the panel isn't drawn." },
    { kind = "cycle", stepper = true, label = "Health bar", key = "rowHp", row = "hp", list = spots, keywords = "order stack rows arrange above below" },
    { kind = "cycle", stepper = true, label = "Power bar", key = "rowPw", row = "pw", list = spots, keywords = "order stack rows arrange above below" },
  }
  if tab == "player" then
    order[#order + 1] = { kind = "cycle", stepper = true, label = "Combo points", key = "rowPips", row = "pips", list = spots,
      keywords = "order stack rows arrange above below combo",
      tip = "Rogues and Druids. First or last, they sit just outside the frame as before. In between, they get a row inside it." }
  end
  sections[#sections + 1] = order
  local U = ns.UnitFrames
  local function place(title, piece, shown, why)
    return {
      title = title,
      { kind = "cycle", label = "Sits on", key = piece .. "At", list = U.PLACES, segWidth = 232, when = shown, whyOff = why, isText = true,
        keywords = "text position place move bar panel" },
      { kind = "cycle", label = "Side", key = piece .. "Align", list = U.ALIGNS, when = shown, whyOff = why, isText = true,
        keywords = "align anchor left right middle centre center" },
      { kind = "step", label = "Nudge across", key = piece .. "X", min = -200, max = 200, step = 1, when = shown, whyOff = why, isText = true,
        keywords = "offset nudge", tip = "Moves the text from its side: more is right, less is left." },
      { kind = "step", label = "Nudge up", key = piece .. "Y", min = -60, max = 60, step = 1, when = shown, whyOff = why, isText = true,
        keywords = "offset nudge", tip = "More is up, less is down." },
    }
  end
  sections[#sections + 1] = place("Place: name", "name", nameOn, "Needs the name showing.")
  sections[#sections + 1] = place("Place: level", "level", function() return cfg().level and cfg().border ~= "rail" end,
    "Needs Level on, and a border other than Rail and tab, which keeps the level in its tab.")
  sections[#sections + 1] = place("Place: status tags", "tag", on("tags"), "Needs Status tags on.")
  sections[#sections + 1] = place("Place: health numbers", "hpText", on("hpText"), "Needs the health Numbers on.")
  sections[#sections + 1] = place("Place: health percent", "hpPct", on("hpPct"), "Needs the health Percent on.")
  sections[#sections + 1] = place("Place: power numbers", "pwText", function() return cfg().power and cfg().pwText end,
    "Needs the power bar and its numbers on.")
  -- (1.95.0) What a class needs beyond the bars: FrameExtras.lua.
  local X = ns.FrameExtras
  if tab == "player" and X then
    sections[#sections + 1] = {
      title = "Class extras",
      { kind = "toggle", label = "Mana bar while shapeshifted", key = "altMana", keywords = "druid bear cat form mana shapeshift second bar",
        tip = "A thin mana bar under your frame while your power bar shows rage or energy, so a Druid in a form can see what's left to shift out with." },
      { kind = "toggle", label = "Regen tick on the power bar", key = "tick", when = on("power"), whyOff = "Needs the power bar on.",
        keywords = "energy tick mana five second rule regen spark rogue",
        tip = "An experiment. A spark crosses the power bar in time with the 2 second energy or mana tick, and a pale fill runs for the 5 seconds after you spend mana. In a fight the game may hide the numbers: the spark then keeps time from the last tick it saw, and can drift." },
    }
  end
  if tab == "pet" and X then
    sections[#sections + 1] = {
      title = "Experience",
      { kind = "toggle", label = "Experience line", key = "petXP", keywords = "pet xp experience hunter level",
        tip = "A thin line under the pet frame for a hunter's pet that's below your level. Hover the frame for the numbers." },
    }
  end
  if X and X.EXTRAS[tab] then
    for i = 1, X.EXTRAS[tab] do
      local k = "extra" .. i
      local function shown() return cfg()[k] ~= "off" end
      local why = "Pick what it shows first."
      sections[#sections + 1] = {
        title = tab == "pet" and "Extra text" or ("Extra text " .. i),
        { kind = "cycle", stepper = true, menu = true, label = "Shows", key = k, list = function() return X.SourceList(tab) end, isText = true,
          keywords = "extra text block soul shards ammo reagent combo pet happiness health mana name level custom",
          tip = tab == "pet" and "A text of your choice outside the pet frame: a hunter pet's mood or experience, or plain things like its health, name and level. Click the value for the whole list."
            or "A text of your choice outside your frame. The list has what your class uses (a shard, ammo or reagent count, combo points) and plain things like health, mana, name and level. A pet's mood is on the Pet page. Click the value for the whole list." },
        { kind = "cycle", stepper = true, menu = true, label = "Sits", key = k .. "At", list = X.SPOTS, when = shown, whyOff = why, isText = true,
          keywords = "anchor above below left right corner" },
        { kind = "toggle", label = "Say what it is", key = k .. "Label", when = shown, whyOff = why, isText = true,
          tip = tab == "pet" and "Mood Happy, not just Happy." or "Shards 7, not just 7." },
        { kind = "step", label = "Font size", key = k .. "Size", min = 8, max = 28, step = 1, when = shown, whyOff = why, isText = true },
        { kind = "step", label = "Nudge across", key = k .. "X", min = -300, max = 300, step = 1, when = shown, whyOff = why, isText = true,
          keywords = "offset nudge", tip = "More is right, less is left." },
        { kind = "step", label = "Nudge up", key = k .. "Y", min = -100, max = 100, step = 1, when = shown, whyOff = why, isText = true,
          keywords = "offset nudge", tip = "More is up, less is down." },
      }
    end
  end
  if tab == "focus" then
    sections[#sections + 1] = {
      title = "Cast bar",
      { kind = "toggle", label = "Show", key = "focusCast", store = "db",
        tip = "Your focus's casts, above its frame. It's as tall as the target frame's cast bar." },
    }
  end
  if tab == "target" or tab == "tot" or tab == "focus" then
    local elite = {
      title = "Elite and rare",
      { kind = "cycle", label = "Style", key = "elite", list = ELITE },
    }
    if tab == "target" then
      elite[2] = { kind = "cycle", label = "Preview", key = "previewClass", store = "preview", list = PREVIEW, segWidth = 208,
        tip = "See the frame as an elite, rare or boss without finding one." }
    end
    sections[#sections + 1] = elite
  end
  if tab == "target" then
    sections[#sections + 1] = {
      title = "Buffs and debuffs",
      { kind = "toggle", label = "Show", key = "auras" },
      { kind = "step", label = "Icon size", key = "auraSize", min = 14, max = 48, step = 1, when = on("auras"), whyOff = "Needs Show on." },
      { kind = "toggle", label = "Kept up by the game", key = "auraGame", when = on("auras"), whyOff = "Needs Show on.",
        keywords = "auras buffs debuffs combat fight update container game target",
        tip = "The icons are drawn by the game's own aura container, which keeps updating in a fight, where an add-on can't read auras at all. Off: VoltUI's own row, with borders in the debuff's colour and a gold border on your own, but frozen until the fight ends. A first try, on the target frame only." },
    }
    sections[#sections + 1] = {
      title = "Cast bar",
      { kind = "toggle", label = "Show", key = "targetCast", store = "db" },
      { kind = "step", label = "Height", key = "targetCastH", store = "db", min = 10, max = 50, step = 1,
        when = function() return ns.db.targetCast end },
    }
  end
  return sections
end

local UNIT_PAGES = {
  { key = "player", title = "Player" },
  { key = "target", title = "Target" },
  { key = "tot", title = "Target of target" },
  { key = "pet", title = "Pet" },
  { key = "focus", title = "Focus" },
}
for _, u in ipairs(UNIT_PAGES) do
  local tab = u.key
  Add({
    key = tab, title = u.title, group = "Frames", needs = "UnitFrames", part = "frames",
    desc = "The " .. u.title:lower() .. " frame. Drag it to move it while moving frames.",
    keywords = "unit frame",
    io = function() return UnitIO(tab) end,
    sections = function() return FrameSections(tab) end,
    pinned = function() return FramePinned(tab) end,
    copy = function()
      local out = {}
      for _, o in ipairs(UNIT_PAGES) do
        if o.key ~= tab then
          out[#out + 1] = { key = o.key, name = o.title, get = function(def) return ns.UnitFrames:Cfg(o.key)[def.key] end }
        end
      end
      return out
    end,
    reset = function() ns.UnitFrames:ResetFrame(tab) end,
    resetTip = "This frame's settings and spot back to their defaults",
    -- A copy of the frame at the top of its page: frame, its height on screen, its scale.
    preview = function(box) return ns.UnitFrames:Preview(tab, box) end,
    mover = function()
      local f = ns.UnitFrames.frames[tab]
      return f and f.mover
    end,
  })
end

------------------------------------------------------------------------
-- Buffs and debuffs
------------------------------------------------------------------------

Add({
  key = "buffs", title = "Buffs", group = "Frames", needs = "Buffs", part = "buffs",
  desc = "The game's buff and debuff frames in VoltUI's look, placed by VoltUI. Drag them while moving frames.",
  keywords = "buffs debuffs auras timers cancel",
  io = function() return DbIO(function() ns.Buffs:Place(); ns.Buffs:Update() end) end,
  sections = function()
    return {
      {
        title = "Size",
        { kind = "step", label = "Buff size", key = "buffSize", min = 18, max = 56, step = 1 },
        { kind = "step", label = "Debuff size", key = "debuffSize", min = 18, max = 64, step = 1 },
        { kind = "step", label = "Scale", key = "buffScale", min = 0.5, max = 2, step = 0.05, fmt = "%.2f" },
      },
      {
        title = "Text",
        { kind = "toggle", label = "Time left under each", key = "buffTimers", isText = true,
          tip = "The time is the game's own, in VoltUI's font." },
        { kind = "step", label = "Time font size", key = "buffTimeSize", min = 8, max = 24, step = 1, isText = true,
          when = function() return ns.db.buffTimers ~= false end, whyOff = "Needs the time left showing.",
          keywords = "timer text size duration", tip = "The game leaves room for about 10: a much bigger one reaches the row below." },
        { kind = "step", label = "Stack count font size", key = "buffCountSize", min = 8, max = 24, step = 1, isText = true,
          keywords = "stacks charges number text size" },
        { kind = "note", lines = 3, text = "These are the game's own buffs, restyled, so they keep up in a fight. How many sit in a row and which way they grow is in the game's Edit Mode. Weapon enchants are edged in violet." },
      },
    }
  end,
  reset = function() ns.Buffs:Reset() end,
  resetTip = "Their size and spot back to the defaults",
  mover = function() return ns.Buffs.holder and ns.Buffs.holder.mover end,
})

------------------------------------------------------------------------
-- Timers: the spells you want to watch (Timers.lua, since 1.69.0). Since 1.102.0 the page
-- is your list of timers, and it shows one of four views (E().timerView):
--   list    your timers, the fight card, where they sit
--   add     what VoltUI found for your class, and any other spell by name or ID
--   edit    one timer's own settings (E().timerKey)
--   layout  the blocks the timers sit in
-- Each view is a page shape of its own (the edit view one for each kind of timer and each
-- shape, since their rows differ), built once and kept.
------------------------------------------------------------------------

local TIMER_STYLE = { { key = "icons", name = "Icon" }, { key = "bars", name = "Bar" } }
local TIMER_GROW = {
  { key = "center", name = "Centre" }, { key = "right", name = "Right" }, { key = "left", name = "Left" },
  { key = "down", name = "Down" }, { key = "up", name = "Up" },
}
local TIMER_SHOW = { { key = "show", name = "Show" }, { key = "hide", name = "Hide" } }
local TIMER_MISS = { { key = "flash", name = "Flash" }, { key = "faded", name = "Faded" }, { key = "hide", name = "Hide" } }
local TIMER_KINDS = { "keep", "proc", "cd", "dot", "imbue", "totem" }
local TIMER_KIND_HEAD = {
  keep = "Buffs to keep up", proc = "Procs", cd = "Cooldowns", dot = "On your target", imbue = "Weapon imbues", totem = "Totems",
}

-- The block the layout view is changing (picked there, or by clicking a block while moving
-- frames).
local function TimerGroup()
  local e = E()
  local ok = false
  for _, g in ipairs(ns.Timers.GROUPS) do if g.key == e.timerGroup then ok = true end end
  if not ok then e.timerGroup = "buffs" end
  return e.timerGroup
end

-- The timer the edit view is changing, while it's one of yours.
local function TimerItem()
  local it = ns.Timers:Find(E().timerKey or "")
  if it and it.listed then return it end
end

local function TimerView()
  local v = E().timerView
  if v == "edit" and not TimerItem() then v = "list" end
  if v ~= "add" and v ~= "edit" and v ~= "layout" then v = "list" end
  return v
end

-- To another view (and timer). A change made to one timer can't be undone onto another, so
-- those leave the footer's Undo.
local function TimerGo(view, key)
  local e = E()
  e.timerView = view
  if key then e.timerKey = key end
  for i = #P.log, 1, -1 do
    if P.log[i].def.store == "aura" then table.remove(P.log, i) end
  end
  if e.panel and e:IsOpen() and e.tab == "timers" then
    e:Select("timers")
    e.scroll:ScrollTo(0)
  end
end
P.TimerGo, P.TimerView = TimerGo, TimerView

local function TimerIO()
  local T = ns.Timers
  return {
    blocked = Never,
    default = function(def)
      if def.store == "pick" then return nil end
      if def.store == "timers" then return T.DEFAULTS[def.key] end
      if def.store == "aura" then
        local it = TimerItem()
        if not it then return nil end
        if def.key == "on" then return true end
        return T:OptDefault(it, def.key)
      end
      return T.DEFAULTS[TimerGroup()][def.key]
    end,
    get = function(def)
      if def.store == "pick" then return TimerGroup() end
      if def.store == "timers" then return T:Cfg()[def.key] end
      if def.store == "aura" then
        local it = TimerItem()
        if not it then return def.min end -- no timer in hand: a slider still needs a number
        if def.key == "on" then return not it.hidden end
        return T:Opt(it, def.key)
      end
      return T:G(TimerGroup())[def.key]
    end,
    set = function(def, v)
      if def.store == "pick" then
        E().timerGroup = v
      elseif def.store == "timers" then
        T:Cfg()[def.key] = v
      elseif def.store == "aura" then
        local it = TimerItem()
        if not it then return end
        if def.key == "on" then T:SetOn(it.key, v) else T:SetOpt(it.key, def.key, v) end
      else
        T:G(TimerGroup())[def.key] = v
      end
    end,
    changed = function(def)
      if def.store ~= "pick" then T:Refresh() end
    end,
  }
end

local function TimerIcon(parent, size)
  local t = S.Tex(parent, "ARTWORK")
  t:SetSize(size, size)
  t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  return t
end

local function TimerIconOf(it)
  return it.icon or (it.st and it.st.icon) or 134400 -- the question mark
end

local function OneLine(fs)
  if fs.SetWordWrap then fs:SetWordWrap(false) end
  return fs
end

local function Tint(fs, c) fs:SetTextColor(c[1], c[2], c[3]) end

-- A small grey heading in capitals inside a list.
local function TimerHeading(r)
  local h = S.UIText(r, nil, "LEFT", "OVERLAY", 10, nil, "mono")
  Tint(h, S.UI.hint)
  return h
end

-- Your timers: each with its icon, its name, a line on when it shows, a switch and Edit.
local TIMER_ENTRY, TIMER_HEAD, TIMER_TILE = 36, 22, 28
local function TimerMine()
  return { kind = "custom", label = "", height = 96,
    keywords = "list your timers add edit remove aura auras",
    build = function(r, width)
      r.entries, r.heads, r.w = {}, {}, width - 2 * S.INSET
      r.none = S.UIText(r, nil, "LEFT", "OVERLAY", 12)
      r.none:SetPoint("TOPLEFT", S.INSET, -10)
      r.none:SetWidth(r.w)
      r.none:SetWordWrap(true)
      if r.none.SetJustifyV then r.none:SetJustifyV("TOP") end
      r.none:SetText("No timers yet. Add a spell you want to watch: a cooldown, a buff to keep up, a proc or a debuff on your target. Then set when and how it shows.")
      Tint(r.none, S.UI.hint)
      r.add = S.PillButton(r, "Add a timer", 130, function() TimerGo("add") end, true, "Pick a spell to watch")
      r.add:SetPoint("TOPLEFT", S.INSET, -62)
      r.count = S.UIText(r, nil, "LEFT", "OVERLAY", 11)
      r.count:SetWidth(r.w)
      Tint(r.count, S.UI.hint)
    end,
    refresh = function(r)
      if not r.entries then return end
      local T = ns.Timers
      local mine = T:Mine()
      local empty = #mine == 0
      r.none:SetShown(empty)
      r.add:SetShown(empty)
      local track = not empty and T.ManagerOn() and T.TrackList() or nil
      local y, nh, ne = empty and 92 or 2, 0, 0
      for _, g in ipairs(T.GROUPS) do
        local first = true
        for _, it in ipairs(mine) do
          if it.group == g.key then
            if first then
              first = false
              nh = nh + 1
              local h = r.heads[nh]
              if not h then
                h = TimerHeading(r)
                r.heads[nh] = h
              end
              h:ClearAllPoints()
              h:SetPoint("TOPLEFT", S.INSET, -(y + 8))
              h:SetText(g.name:upper())
              h:Show()
              y = y + TIMER_HEAD
            end
            ne = ne + 1
            local b = r.entries[ne]
            if not b then
              b = CreateFrame("Button", nil, r)
              b:SetSize(r.w + 8, TIMER_ENTRY - 2)
              b.icon = TimerIcon(b, 26)
              b.icon:SetPoint("LEFT", 5, 0)
              b.edit = S.PillButton(b, "Edit", 44, function() if b.item then TimerGo("edit", b.item.key) end end, false, "This timer's own settings")
              b.edit:SetPoint("RIGHT", b, "RIGHT", -4, 0)
              b.on = S.PillButton(b, "Off", 38, function()
                local item = b.item and ns.Timers:Find(b.item.key) -- as it is now: the spells may have been read again
                if not item then return end
                ns.Timers:SetOn(item.key, item.hidden)
                E():RefreshPage()
              end, false, "Switch this timer off or on. Its settings are kept.")
              b.on:SetPoint("RIGHT", b.edit, "LEFT", -4, 0)
              for _, pill in ipairs({ b.edit, b.on }) do pill:SetFrameLevel((b:GetFrameLevel() or 1) + 2) end
              b.name = OneLine(S.UIText(b, nil, "LEFT", "OVERLAY", 12))
              b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 8, 1)
              b.name:SetPoint("RIGHT", b.on, "LEFT", -8, 0)
              b.sum = OneLine(S.UIText(b, nil, "LEFT", "OVERLAY", 11))
              b.sum:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 8, -1)
              b.sum:SetPoint("RIGHT", b.on, "LEFT", -8, 0)
              S.Hover(b)
              b:SetScript("OnClick", function(btn) if btn.item then TimerGo("edit", btn.item.key) end end)
              r.entries[ne] = b
            end
            b.item = it
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", S.INSET - 4, -y)
            b.icon:SetTexture(TimerIconOf(it))
            b.icon:SetDesaturated(it.hidden and true or false)
            b.name:SetText(it.name)
            Tint(b.name, it.hidden and S.UI.hint or S.UI.label)
            local sum = (T.KIND_LONG[it.kind] or it.kind) .. " · " .. T:Summary(it)
            -- a buff the game's Cooldown Manager isn't following can't be seen dropping in a fight
            local f = not it.hidden and T:Follow(it, track) or nil
            if f == "off" or (type(f) == "table" and not f.on) then
              sum = sum .. " · " .. S.UI.Hex(S.UI.warn) .. "not followed in a fight|r"
            end
            b.sum:SetText(sum)
            Tint(b.sum, S.UI.hint)
            b.on.text:SetText(it.hidden and "Off" or "On")
            Tint(b.on.text, it.hidden and S.UI.off or S.UI.ok)
            b:Show()
            y = y + TIMER_ENTRY
          end
        end
      end
      for i = nh + 1, #r.heads do r.heads[i]:Hide() end
      for i = ne + 1, #r.entries do r.entries[i]:Hide() end
      local more = #T:Available()
      r.count:ClearAllPoints()
      r.count:SetPoint("TOPLEFT", S.INSET, -(y + 8))
      if empty then
        r.count:SetText(more > 0 and (more .. " found for your class.") or "")
      else
        r.count:SetText(("%d %s.%s"):format(#mine, #mine == 1 and "timer" or "timers",
          more > 0 and ("  %d more for your class in Add a timer."):format(more) or ""))
      end
      E():RowResized(r, y + 30)
    end }
end

-- What VoltUI found for your class that isn't a timer yet: click one to add it and set it up.
local function TimerPicker()
  return { kind = "custom", label = "", height = 60,
    keywords = "add pick class spells available",
    build = function(r, width)
      r.tiles, r.heads, r.w = {}, {}, width - 2 * S.INSET
      r.none = S.UIText(r, nil, "LEFT", "OVERLAY", 12)
      r.none:SetPoint("TOPLEFT", S.INSET, -10)
      r.none:SetWidth(r.w)
      r.none:SetWordWrap(true)
      r.none:SetText("Everything VoltUI found for your class is in your list. VoltUI looks again as you learn spells.")
      Tint(r.none, S.UI.hint)
      r.all = S.PillButton(r, "Add them all", 110, function()
        ns.Timers:AddAll()
        TimerGo("list")
      end, false, "Everything here joins your list, each with its block's settings")
      r.all:SetPoint("TOPRIGHT", r, "TOPRIGHT", -S.INSET, -4)
    end,
    refresh = function(r)
      if not r.tiles then return end
      local T = ns.Timers
      local avail = T:Available()
      r.none:SetShown(#avail == 0)
      r.all:SetShown(#avail > 0)
      local tileW = math.floor((r.w - 6) / 2)
      local y, nh, nt = #avail == 0 and 40 or 6, 0, 0
      for _, kind in ipairs(TIMER_KINDS) do
        local n = 0
        for _, it in ipairs(avail) do
          if it.kind == kind then
            if n == 0 then
              nh = nh + 1
              local h = r.heads[nh]
              if not h then
                h = TimerHeading(r)
                r.heads[nh] = h
              end
              h:ClearAllPoints()
              h:SetPoint("TOPLEFT", S.INSET, -(y + 8))
              h:SetText(TIMER_KIND_HEAD[kind]:upper())
              h:Show()
              y = y + TIMER_HEAD + 4
            end
            n = n + 1
            nt = nt + 1
            local b = r.tiles[nt]
            if not b then
              b = CreateFrame("Button", nil, r)
              b.bg = S.Tex(b, "BACKGROUND")
              b.bg:SetAllPoints()
              b.bg:SetColorTexture(S.UI.raised[1], S.UI.raised[2], S.UI.raised[3], 1)
              b.icon = TimerIcon(b, 20)
              b.icon:SetPoint("LEFT", 4, 0)
              b.name = OneLine(S.UIText(b, nil, "LEFT", "OVERLAY", 12))
              b.name:SetPoint("LEFT", b.icon, "RIGHT", 7, 0)
              b.name:SetPoint("RIGHT", b, "RIGHT", -4, 0)
              Tint(b.name, S.UI.label)
              S.Hover(b)
              b:SetScript("OnClick", function(btn)
                local item = btn.item
                if item and ns.Timers:Add(item.key) then TimerGo("edit", item.key) end
              end)
              r.tiles[nt] = b
            end
            b.item = it
            b:SetSize(tileW, TIMER_TILE - 4)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", S.INSET + ((n - 1) % 2) * (tileW + 6), -(y + math.floor((n - 1) / 2) * TIMER_TILE))
            b.icon:SetTexture(TimerIconOf(it))
            b.name:SetText(it.name)
            b:Show()
          end
        end
        y = y + math.ceil(n / 2) * TIMER_TILE
      end
      for i = nh + 1, #r.heads do r.heads[i]:Hide() end
      for i = nt + 1, #r.tiles do r.tiles[i]:Hide() end
      E():RowResized(r, y + 8)
    end }
end

-- Any other spell: its name or ID, and a button for what it is. It joins your list and its
-- settings open.
local function TimerAdd()
  return { kind = "custom", label = "", height = 110,
    keywords = "add custom spell buff proc cooldown debuff own track weakaura id name",
    build = function(r, width)
      local T = ns.Timers
      local say = S.UIText(r, nil, "LEFT", "OVERLAY", 12)
      say:SetPoint("TOPLEFT", S.INSET, -8)
      say:SetText("Spell")
      Tint(say, S.UI.label)
      local box = CreateFrame("EditBox", nil, r)
      box:SetHeight(20)
      box:SetPoint("LEFT", say, "RIGHT", 10, 0)
      box:SetPoint("RIGHT", r, "RIGHT", -S.INSET, 0)
      box:SetAutoFocus(false)
      box:SetMaxLetters(60)
      box:SetTextInsets(6, 6, 0, 0)
      S.FixFont(box, 12)
      local bg, edges = S.RoundBox(box, S.UI.r.field, "BACKGROUND", -8, -7)
      S.Paint(bg, S.UI.field[1], S.UI.field[2], S.UI.field[3], 1)
      S.ColorEdges(edges, S.UI.soft[1], S.UI.soft[2], S.UI.soft[3], 1)
      box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
      box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
      r.box = box
      r.said = S.UIText(r, nil, "LEFT", "OVERLAY", 11)
      r.said:SetPoint("TOPLEFT", S.INSET, -88)
      r.said:SetPoint("RIGHT", r, "RIGHT", -S.INSET, 0)
      r.said:SetText("Type it, then pick what it is.")
      Tint(r.said, S.UI.hint)
      local function add(kind)
        local ok, said, key = T:AddCustom(kind, box:GetText() or "")
        r.said:SetText(ok and (said .. " added.") or said)
        Tint(r.said, ok and S.UI.ok or S.UI.warn)
        if ok then
          box:SetText("")
          TimerGo("edit", key)
        end
        return ok, said, key
      end
      r.add = add
      local w = math.floor((width - 2 * S.INSET - 4) / 2)
      r.kinds = {}
      for i, k in ipairs(T.CUSTOM_LIST) do
        local pill = S.PillButton(r, k.name, w, function() add(k.key) end, false, "Add it as: " .. k.name:lower())
        pill:SetWidth(w)
        pill:SetPoint("TOPLEFT", S.INSET + ((i - 1) % 2) * (w + 4), -34 - math.floor((i - 1) / 2) * 26)
        r.kinds[i] = pill
      end
    end }
end

-- The timer in hand: its icon, its name and what kind of timer it is.
local function TimerHero()
  return { kind = "custom", label = "", height = 56,
    build = function(r)
      r.icon = TimerIcon(r, 40)
      r.icon:SetPoint("LEFT", S.INSET, 0)
      r.name = OneLine(S.UIText(r, nil, "LEFT", "OVERLAY", 14))
      S.FixFont(r.name, 14, nil, "semibold")
      r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 10, -3)
      r.name:SetPoint("RIGHT", r, "RIGHT", -S.INSET, 0)
      Tint(r.name, S.UI.text)
      r.sub = OneLine(S.UIText(r, nil, "LEFT", "OVERLAY", 11))
      r.sub:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 10, 4)
      r.sub:SetPoint("RIGHT", r, "RIGHT", -S.INSET, 0)
      Tint(r.sub, S.UI.hint)
    end,
    refresh = function(r)
      local T = ns.Timers
      local it = TimerItem()
      if not (r.icon and it) then return end
      r.icon:SetTexture(TimerIconOf(it))
      r.icon:SetDesaturated(it.hidden and true or false)
      r.name:SetText(it.name)
      local group = it.group
      for _, g in ipairs(T.GROUPS) do if g.key == it.group then group = g.name end end
      r.sub:SetText((T.KIND_LONG[it.kind] or it.kind) .. " · sits with " .. group .. (it.custom and " · added by you" or ""))
    end }
end

-- A buff or proc in a fight: whether the game's Cooldown Manager follows it, and a button
-- to have it do so. (The manager's long list of Tracked Buffs was here before 1.102.0.)
local function TimerFollow()
  return { kind = "custom", label = "", height = 76,
    keywords = "tracked buffs cooldown manager fight combat lightning shield follow",
    build = function(r, width)
      r.label:ClearAllPoints()
      r.label:SetPoint("TOPLEFT", S.INSET, -8)
      r.label:SetText("Followed in a fight")
      r.button = S.PillButton(r, "Follow it", 96, function() if r.act then r.act() end end, false)
      r.button:SetPoint("TOPRIGHT", r, "TOPRIGHT", -S.INSET, -3)
      r.state = S.UIText(r, nil, "RIGHT", "OVERLAY", 12)
      r.state:SetPoint("RIGHT", r.button, "LEFT", -8, 0)
      r.hint = S.UIText(r, nil, "LEFT", "OVERLAY", 11)
      r.hint:SetPoint("TOPLEFT", S.INSET, -30)
      r.hint:SetWidth(width - 2 * S.INSET)
      r.hint:SetWordWrap(true)
      if r.hint.SetJustifyV then r.hint:SetJustifyV("TOP") end
      Tint(r.hint, S.UI.hint)
    end,
    refresh = function(r)
      local T = ns.Timers
      local it = TimerItem()
      if not r.state then return end
      local f = it and T:Follow(it)
      local state, color, hint, text, act = "", S.UI.hint, "", nil, nil
      if f == "none" then
        state = "No"
        hint = "In a fight the game hides your buffs from add-ons, and this client has no Cooldown Manager to ask instead: this timer catches up once the fight ends."
      elseif f == "off" then
        state, color, text = "Manager off", S.UI.warn, "Switch it on"
        hint = "In a fight the game hides your buffs from add-ons. Its own Cooldown Manager can still see them: switch it on and VoltUI asks it."
        act = function() T:TurnManagerOn() FUI:Refresh() end
      elseif f == "cant" then
        state = "Can't be"
        hint = "The game's Cooldown Manager doesn't offer this one, so in a fight this timer catches up once the fight ends."
      elseif type(f) == "table" then
        if f.pending then
          state, color, text = "After a reload", S.UI.warn, "Reload now"
          hint = "Saved in the game's Cooldown Manager. Reload for it to take: until then it may not be followed in a fight."
          act = function() FUI:Reload() end
        elseif f.on then
          state, color, text = "Followed", S.UI.ok, "Stop"
          hint = "The game's Cooldown Manager tells VoltUI when this drops in a fight."
        else
          state, color, text = "Not followed", S.UI.warn, "Follow it"
          hint = "In a fight the game hides your buffs from add-ons. Follow it, and the game's Cooldown Manager tells VoltUI when it drops. Takes a reload."
        end
        if not f.pending then
          act = function()
            local ok, why = T:SetFollow(it, not f.on)
            T.trackSay = not ok and why or nil
            E():RefreshPage()
          end
        end
      end
      if T.trackSay then hint = T.trackSay end
      r.act = act
      r.state:SetText(state)
      Tint(r.state, color)
      r.hint:SetText(hint)
      r.button:SetShown(text ~= nil)
      if text then r.button.text:SetText(text) end
    end }
end

-- Earlier or later among the timers of its block.
local function TimerOrder()
  return { kind = "custom", label = "Order in its block", height = S.ROW_H,
    keywords = "order sort reorder move earlier later",
    build = function(r)
      local function move(dir)
        local it = TimerItem()
        if it then ns.Timers:Move(it.key, dir) end
        E():RefreshPage()
      end
      r.later = S.PillButton(r, "Later", 56, function() move(1) end, false, "Later among its block's timers")
      r.later:SetPoint("RIGHT", r, "RIGHT", -S.INSET, 0)
      r.earlier = S.PillButton(r, "Earlier", 64, function() move(-1) end, false, "Earlier among its block's timers")
      r.earlier:SetPoint("RIGHT", r.later, "LEFT", -4, 0)
    end,
    refresh = function(r)
      local it, at = TimerItem(), nil
      if not (r.later and it) then return end
      local items = ns.Timers.items
      for i, x in ipairs(items) do if x == it then at = i end end
      local first, last = true, true
      for j = (at or 1) - 1, 1, -1 do if items[j].group == it.group and items[j].listed then first = false break end end
      for j = (at or #items) + 1, #items do if items[j].group == it.group and items[j].listed then last = false break end end
      r.earlier:SetAlpha(first and 0.3 or 1)
      r.later:SetAlpha(last and 0.3 or 1)
    end }
end

local function TimerBack()
  return { text = "Back to list", fn = function() TimerGo("list") end, tip = "Your list of timers" }
end

-- The cards of each view.
local function TimerFightCard()
  return {
    title = "In a fight",
    { kind = "note", lines = 6, text = function()
        local T = ns.Timers
        if not C_CooldownViewer then return "In a fight the game hides your buffs from add-ons, and this client has no Cooldown Manager to ask instead: a buff that drops in a fight shows once the fight ends." end
        if not T.ManagerOn() then return "In a fight the game hides your buffs from add-ons, so a buff that drops (Lightning Shield out of charges) only shows once the fight ends. The game's own Cooldown Manager can see them: switch it on and VoltUI asks it." end
        local followed, total, missing = T:FollowCount()
        if total == 0 then return "In a fight the game hides your buffs from add-ons, so VoltUI asks the game's Cooldown Manager which are up. It's on. Each buff or proc you add says on its own settings whether the game follows it." end
        local text = ("In a fight the game hides your buffs from add-ons, so VoltUI asks the game's Cooldown Manager which are up. It follows %d of your %d buffs and procs."):format(followed, total)
        if #missing > 0 then text = text .. " Not followed: " .. table.concat(missing, ", ") .. ". Open one with Edit to follow it." end
        return text
      end },
    { kind = "button", label = "Cooldown Manager", text = "Switch it on", keywords = "cooldown manager combat fight lightning shield tracked buffs",
      when = function() return C_CooldownViewer ~= nil and not ns.Timers.ManagerOn() end, whyOff = "It's on already, or this client has none.",
      tip = "Turns on the game's own Cooldown Manager (Options, Gameplay Enhancements). You can turn it off there again.",
      fn = function() ns.Timers:TurnManagerOn(); FUI:Refresh() end },
    { kind = "toggle", label = "Keep the game's manager out of sight", key = "hideManager", store = "timers",
      keywords = "cooldown manager hide blizzard",
      tip = "The manager has to be on for VoltUI to ask it, but it shows the same things as these timers. On: its icons are see-through. They come back while the game's Edit Mode or the manager's own settings are open." },
    { kind = "button", label = "Followed buffs changed", text = "Reload now", keywords = "reload tracked buffs",
      when = function() return ns.Timers.trackReload == true end, whyOff = "Nothing has changed.",
      fn = function() FUI:Reload() end },
  }
end

local function TimerListCards()
  return {
    { title = "Your timers", action = { text = "+ Add a timer", fn = function() TimerGo("add") end, tip = "Pick a spell to watch" },
      TimerMine() },
    TimerFightCard(),
    { title = "Where they sit",
      { kind = "note", lines = 4, text = "Timers sit in blocks on screen: buffs and procs, cooldowns, your debuffs on the target, totems. Drag a block while moving frames; its rows, gaps and direction are under Blocks." },
      { kind = "button", label = "Blocks", text = "Set up", keywords = "block group layout grow row gap scale opacity",
        fn = function() TimerGo("layout") end },
      { kind = "button", label = "Place them", text = "Move frames", keywords = "move drag place position",
        fn = function() E():MoveMode(true) end },
    },
  }
end

local function TimerAddCards()
  return {
    { title = "For your class", action = TimerBack(),
      { kind = "note", lines = 2, text = "Click a spell: it joins your list and its settings open, where you set when and how it shows." },
      TimerPicker() },
    { title = "Any other spell",
      { kind = "note", lines = 5, text = "A trinket's proc, someone else's buff, a spell VoltUI doesn't list. A name works for a spell in your spellbook; for anything else give its spell ID (Alt-click the spell or buff for its web page: the number is in the address)." },
      TimerAdd() },
  }
end

local function TimerLayoutCards()
  return {
    { title = "Block", action = TimerBack(),
      { kind = "note", lines = 2, text = "A block is one group of timers on screen. Its rows and direction are set once for everything in it." },
      { kind = "cycle", stepper = true, label = "Editing", key = "group", store = "pick", list = function() return ns.Timers.GROUPS end },
      { kind = "toggle", label = "Show this block", key = "on" },
      { kind = "step", label = "In a row", key = "perRow", min = 1, max = 20, step = 1,
        tip = "How many before a new row starts (a new column, growing up or down)." },
      { kind = "step", label = "Gap", key = "gap", min = 0, max = 20, step = 1 },
      { kind = "cycle", label = "Grow", key = "grow", list = TIMER_GROW },
      { kind = "button", label = "Place it", text = "Move frames", fn = function() E():MoveMode(true) end },
    },
    { title = "All timers",
      { kind = "step", label = "Scale", key = "scale", store = "timers", min = 0.5, max = 2, step = 0.05, fmt = "%.2f" },
      { kind = "step", label = "Opacity out of a fight", key = "idleAlpha", store = "timers", min = 0, max = 1, step = 0.05, fmt = "%.2f",
        tip = "With no target and out of combat." },
      { kind = "button", label = "See them", text = "Pulse them", fn = function() ns.Timers:Test() end,
        tip = "Every timer showing pulses once. Move frames shows them all, to place them." },
    },
  }
end

local function TimerEditCards(kind, style)
  local T = ns.Timers
  local function A(row) row.store = "aura" return row end
  local buff = kind == "keep" or kind == "imbue"
  local first = {
    title = "This timer", action = TimerBack(),
    TimerHero(),
    A({ kind = "toggle", label = "Show this timer", key = "on",
        tip = "Off: it stays in your list with its settings, and doesn't show." }),
  }
  if kind == "keep" or kind == "proc" then first[#first + 1] = TimerFollow() end
  first[#first + 1] = { kind = "button", label = "Take it out of your list", text = "Remove", keywords = "remove delete",
    buttonTip = "Its own settings go with it. Add it again from Add a timer.",
    fn = function()
      local it = TimerItem()
      if it then T:Remove(it.key) end
      TimerGo("list")
    end }

  local when = {
    title = "When it shows",
    A({ kind = "cycle", label = "Show", key = "when", list = T.WHEN, keywords = "combat fight condition trigger" }),
    A({ kind = "toggle", label = "In the open world", key = "world", keywords = "place zone outside" }),
    A({ kind = "toggle", label = "In dungeons", key = "dungeon", keywords = "place instance party" }),
    A({ kind = "toggle", label = "In raids", key = "raid", keywords = "place instance" }),
    A({ kind = "toggle", label = "In battlegrounds", key = "pvp", keywords = "place pvp arena" }),
  }
  if kind == "cd" then
    when[#when + 1] = A({ kind = "cycle", label = "While it's ready", key = "ready", list = TIMER_SHOW,
      tip = "Hide: it only shows while it's cooling down." })
  elseif buff then
    when[#when + 1] = A({ kind = "cycle", label = "While it's up", key = "up", list = TIMER_SHOW,
      tip = "Hide: it only shows once it's gone or about to run out, so you know to put it back on." })
    when[#when + 1] = A({ kind = "step", label = "Show again in the last (sec)", key = "soon", min = 0, max = 300, step = 15,
      when = function() local it = TimerItem() return it ~= nil and T:Opt(it, "up") == "hide" end, whyOff = "Needs While it's up set to Hide.",
      tip = "How long before it runs out a hidden buff shows again. 0: only once it's gone. A buff whose time the game keeps hidden shows only once it's gone." })
    when[#when + 1] = A({ kind = "cycle", label = "Missing, in a fight", key = "miss", list = TIMER_MISS, keywords = "warn warning red missing combat flash",
      tip = "Flash: red and pulsing. Faded: grey. Hide: not shown." })
    when[#when + 1] = A({ kind = "cycle", label = "Missing, out of a fight", key = "missOut", list = TIMER_MISS, keywords = "warn warning red missing idle flash",
      tip = "Flash: red and pulsing. Faded: grey. Hide: not shown." })
  elseif kind == "dot" then
    when[#when + 1] = { kind = "note", lines = 2, text = "It shows while you have something to attack." }
    when[#when + 1] = A({ kind = "cycle", label = "Missing, in a fight", key = "miss", list = TIMER_MISS, keywords = "warn warning red missing combat flash",
      tip = "While it isn't on what you're attacking. Flash: red and pulsing. Faded: grey. Hide: not shown." })
  elseif kind == "proc" then
    when[#when + 1] = { kind = "note", lines = 1, text = "A proc shows while it's up." }
  else
    when[#when + 1] = { kind = "note", lines = 2, text = "A totem shows while it's down, and flashes for a moment when it goes." }
  end

  local look = {
    title = "Look",
    A({ kind = "cycle", label = "Shape", key = "style", list = TIMER_STYLE,
        tip = "An icon with the time over it, or a bar with the icon, name and time. Bars use VoltUI's bar texture (General).",
        after = function() if E().tab == "timers" and not E().query then E():Select("timers") end end }),
  }
  if style == "bars" then
    look[#look + 1] = A({ kind = "step", label = "Bar width", key = "width", min = 80, max = 400, step = 2 })
    look[#look + 1] = A({ kind = "step", label = "Bar height", key = "height", min = 10, max = 48, step = 1 })
  else
    look[#look + 1] = A({ kind = "step", label = "Size", key = "size", min = 16, max = 80, step = 1 })
  end
  look[#look + 1] = A({ kind = "step", label = "Number size", key = "numbers", min = 8, max = 40, step = 1, isText = true })
  look[#look + 1] = A({ kind = "toggle", label = kind == "cd" and "Pulse when it's ready" or "Pulse when it comes up", key = "pulse" })
  if kind == "cd" then
    look[#look + 1] = A({ kind = "toggle", label = "Blue when short of power", key = "usable",
      tip = "Blue while you lack the mana, rage or energy. A spell that only works after something happens (Overpower, Revenge, Execute, Riposte) stays dim until it can be used, then lights up gold." })
  end
  look[#look + 1] = A({ kind = "cycle", stepper = true, label = "Sits with", key = "group", list = function() return T.GROUPS end,
    tip = "The block on screen it's drawn in. A size or shape you haven't changed follows that block's." })
  look[#look + 1] = TimerOrder()
  look[#look + 1] = { kind = "button", label = "Same look for its whole block", text = "Copy look", keywords = "copy look all group block size",
    buttonTip = "Every timer in this one's block takes this shape and these sizes",
    fn = function()
      local it = TimerItem()
      if not it then return end
      local n = T:CopyLook(it.key)
      E():Toast(n == 1 and "1 other timer in its block now looks like this." or (n .. " other timers in its block now look like this."), nil, nil, 5)
    end }
  return { first, when, look }
end

Add({
  key = "timers", title = "Timers", group = "Frames", needs = "Timers", part = "timers",
  desc = "Icons and bars for the spells you want to watch: a cooldown coming back, a buff that dropped, a proc. Add one, then set when and how it shows.",
  keywords = "timers weakauras auras aura cooldowns buffs procs debuffs dots totems imbues uptime pulse flash alerts add edit dungeon raid combat",
  io = function() return TimerIO() end,
  shape = function()
    local v = TimerView()
    if v ~= "edit" then return v end
    local it = TimerItem()
    return "edit:" .. it.kind .. ":" .. tostring(ns.Timers:Opt(it, "style"))
  end,
  sections = function()
    local v = TimerView()
    if v == "add" then return TimerAddCards() end
    if v == "layout" then return TimerLayoutCards() end
    if v == "edit" then
      local it = TimerItem()
      return TimerEditCards(it.kind, ns.Timers:Opt(it, "style"))
    end
    return TimerListCards()
  end,
  -- What the search looks through, whatever view is showing: the settings that aren't one
  -- timer's own.
  searchSections = function()
    local out = TimerLayoutCards()
    for _, card in ipairs(out) do card.action = nil end
    out[#out + 1] = TimerFightCard()
    return out
  end,
  reset = function() ns.Timers:Reset() end,
  resetTip = "Every timer back to its block's settings, and the blocks' looks and spots back to the defaults. Your list of timers stays.",
  mover = function()
    local v = TimerView()
    local it = v == "edit" and TimerItem() or nil
    local h = ns.Timers.holders[it and it.group or (v == "layout" and TimerGroup()) or ""]
    return h and h.mover
  end,
})

------------------------------------------------------------------------
-- Castbar
------------------------------------------------------------------------

Add({
  key = "cast", title = "Castbar", group = "Frames", needs = "Castbar", part = "castbar",
  desc = "Your cast bar. Its icon, time and spark settings apply to the target frame's bar too.",
  keywords = "cast bar casting spell",
  io = function()
    return {
      blocked = InCombat,
      default = function(def) return FUI.defaults[def.key] end,
      get = function(def) return ns.db[def.key] end,
      set = function(def, v) ns.db[def.key] = v end,
      changed = function() ns.Castbar:LayoutAll() end,
    }
  end,
  sections = function()
    return {
      {
        title = "Size",
        { kind = "step", label = "Width", key = "castWidth", store = "db", min = 80, max = 600, step = 5 },
        { kind = "step", label = "Height", key = "castHeight", store = "db", min = 10, max = 60, step = 1 },
        { kind = "step", label = "Scale", key = "castScale", store = "db", min = 0.5, max = 2, step = 0.05, fmt = "%.2f" },
      },
      {
        title = "Parts",
        { kind = "step", label = "Font size", key = "castSize", store = "db", min = 8, max = 28, step = 1 },
        { kind = "toggle", label = "Spell icon", key = "castIcon", store = "db" },
        { kind = "toggle", label = "Time left", key = "castTime", store = "db" },
        { kind = "toggle", label = "Spark", key = "castSpark", store = "db" },
        { kind = "toggle", label = "Your latency", key = "castLag", store = "db", free = true,
          tip = "A red zone at the end of your own casts as wide as your latency: a spell pressed once the bar reaches it goes off straight after." },
        { kind = "toggle", label = "Mark casts you can't interrupt", key = "castLock", store = "db", free = true,
          tip = "A gold line along the top of the bar, as well as the grey colour." },
        { kind = "toggle", label = "Breath and fatigue timers", key = "castMirror", store = "db", free = true, reloadOff = true,
          tip = "The game's breath, fatigue and feign death timers in VoltUI's look. Switching it off takes a reload." },
        { kind = "toggle", label = "Weapon swing timers", key = "castSwing", store = "db", free = true, reloadOff = true,
          keywords = "swing timer melee auto attack main hand off hand ranged",
          tip = "The game's swing timer bars (main hand, off hand, ranged) in VoltUI's look. The game still places them: move them in its Edit Mode, and switch them on in its options. Switching this off takes a reload." },
        { kind = "button", label = "See it", text = "Sample cast", free = true, fn = function() ns.Castbar:Slash("test") end },
      },
    }
  end,
  reset = function() ns.Castbar:Reset() end,
  resetTip = "Your cast bar's settings and spot back to their defaults",
  mover = function() return ns.Castbar.player and ns.Castbar.player.mover end,
})

------------------------------------------------------------------------
-- Party and raid frames
------------------------------------------------------------------------

local RAID_HP_COLORS = {
  { key = "class", name = "Class" }, { key = "green", name = "Green" }, { key = "dark", name = "Dark" }, { key = "custom", name = "Pick" },
}
local RAID_HP_TEXT = { { key = "off", name = "Off" }, { key = "missing", name = "Missing" }, { key = "percent", name = "Percent" } }
local RAID_POWER = { { key = "off", name = "Off" }, { key = "healers", name = "Healers" }, { key = "all", name = "Everyone" } }
local RAID_LAYOUT = { { key = "columns", name = "Columns" }, { key = "rows", name = "Rows" } }
local PARTY_LAYOUT = { { key = "columns", name = "Column" }, { key = "rows", name = "Row" } }
local RAID_SORT = {
  { key = "group", name = "Group" }, { key = "role", name = "Role" }, { key = "class", name = "Class" }, { key = "name", name = "Name" },
}

-- A set's name, or a function giving it (the Heal mode page switches between two).
local function SetNameOf(setName)
  if type(setName) == "function" then return setName() end
  return setName
end

-- A settings set's rows read and write that set: "party", "raid", "healParty" or "healRaid"
-- (Raid.lua's R.SETS).
local function RaidIO(setName)
  return {
    blocked = InCombat,
    default = function(def)
      if def.store == "sim" or def.store == "cfg" then return nil end
      return ns.Raid:DefaultFor(SetNameOf(setName), def.key)
    end,
    get = function(def)
      if def.store == "sim" then return ns.Raid.sim or false end
      if def.store == "cfg" then return ns.Raid:Cfg()[def.key] end
      return ns.Raid:Set(SetNameOf(setName))[def.key]
    end,
    set = function(def, v)
      local R = ns.Raid
      local name = SetNameOf(setName)
      if def.store == "sim" then
        R.simSet = name
        R:Simulate(v, true)
        return
      end
      if def.store == "cfg" then
        R:Cfg()[def.key] = v
        return
      end
      if v == nil then v = R:DefaultFor(name, def.key) end -- a colour swatch's right-click
      R:Set(name)[def.key] = R.Copy(v) -- a colour copied from another set stays its own
    end,
    changed = function(def)
      local R = ns.Raid
      if def.store == "cfg" then
        if def.key == "healMode" then R:CheckHeal() end
        if def.key == "clicksWhen" then R:ApplyClicks() end
      elseif def.store ~= "sim" then
        R:Apply()
      end
    end,
  }
end
P.RaidIO = RaidIO

-- Made-up members to see a set's settings on: a party for a party set, a raid for a raid set.
local function SimRow(setName, label)
  local R = ns.Raid
  local raid = R:SetKind(SetNameOf(setName)) == "raid"
  return { kind = "cycle", label = label or "Show", key = "sim", store = "sim", list = raid and R.SIM_RAID or R.SIM_PARTY,
    segWidth = raid and 208 or 104,
    tip = raid and "A made-up raid of 10, 25 or 40 where your frames go, to see these settings on. It goes when the settings window closes."
      or "A made-up party where your frames go, to see these settings on. It goes when the settings window closes." }
end

-- The cards every set has. `extra` adds cards (heal mode's own). Rows that only mean
-- something for a party (yourself, alone) or a raid (groups) show on that kind's sets.
local function RaidCards(setName, extra)
  local R = ns.Raid
  local function set() return R:Set(SetNameOf(setName)) end
  local raid = R:SetKind(SetNameOf(setName)) == "raid"
  local function power() return set().power ~= "off" end
  local function debuffs() return set().debuffs end
  local layout = {
    title = "Size and layout",
    { kind = "step", label = "Width", key = "width", min = 30, max = 200, step = 1 },
    { kind = "step", label = "Height", key = "height", min = 16, max = 100, step = 1 },
    { kind = "step", label = "Gap between members", key = "gap", min = 0, max = 12, step = 1 },
  }
  if raid then
    layout[#layout + 1] = { kind = "step", label = "Gap between groups", key = "groupGap", min = 0, max = 40, step = 1 }
  end
  layout[#layout + 1] = { kind = "step", label = "Scale", key = "scale", min = 0.5, max = 2, step = 0.05, fmt = "%.2f" }
  layout[#layout + 1] = { kind = "cycle", label = raid and "Raid groups as" or "Members in a", key = "layout",
    list = raid and RAID_LAYOUT or PARTY_LAYOUT }
  layout[#layout + 1] = { kind = "cycle", label = raid and "Order in a group" or "Order", key = "sort", list = RAID_SORT }
  if not raid then
    layout[#layout + 1] = { kind = "toggle", label = "Show yourself", key = "showPlayer" }
    layout[#layout + 1] = { kind = "toggle", label = "Show when you're alone", key = "showSolo" }
  end
  layout[#layout + 1] = { kind = "toggle", label = raid and "Group titles" or "Party title", key = "titles" }
  local cards = {
    { title = "Preview", SimRow(setName) },
    layout,
    {
      title = "Health",
      { kind = "cycle", label = "Colour", key = "hpColor", list = RAID_HP_COLORS },
      { kind = "color", label = "Your colour", keys = { { key = "customColor", name = "Bar" } },
        when = function() return set().hpColor == "custom" end },
      { kind = "step", label = "Missing health shade", key = "missing", min = 0, max = 0.5, step = 0.05, fmt = "%.2f",
        when = function() return set().hpColor ~= "dark" end },
      { kind = "cycle", label = "Health text", key = "hpText", list = RAID_HP_TEXT,
        tip = "Missing shows how much health is gone (-1634), empty at full health." },
      { kind = "toggle", label = "Incoming heals", key = "heals" },
      { kind = "toggle", label = "Shields", key = "shields" },
      { kind = "toggle", label = "Overhealing", key = "overheal",
        when = function() return set().heals or set().shields end,
        tip = "A bright edge at the end of the bar when more heals are coming than health is missing, and a white one for shields past full health." },
      { kind = "step", label = "Out of range opacity", key = "rangeAlpha", min = 0.1, max = 1, step = 0.05, fmt = "%.2f" },
    },
    {
      title = "Power",
      { kind = "cycle", label = "Power bar", key = "power", list = RAID_POWER,
        tip = "Mana, rage or energy under the health bar: for healers only, for everyone, or off." },
      { kind = "step", label = "Height", key = "powerHeight", min = 2, max = 14, step = 1, when = power, whyOff = "Needs the power bar on." },
    },
    {
      title = "Text",
      Scale("Name size", "nameScale", nil, { isText = true }),
      { kind = "cycle", label = "Name colour", key = "nameColor", list = NAME_COLORS, isText = true },
      Scale("Status text size", "statusScale", nil, { isText = true }),
    },
    {
      title = "Borders and icons",
      { kind = "cycle", label = "Your target", key = "target", list = TARGET_BORDER },
      { kind = "toggle", label = "Aggro glow", key = "aggro" },
      { kind = "toggle", label = "Under the mouse", key = "hover" },
      { kind = "toggle", label = "Role icons", key = "roleIcons" },
      { kind = "toggle", label = "Raid markers", key = "markers" },
      { kind = "toggle", label = "Leader mark", key = "leader" },
      { kind = "toggle", label = "Ready check answers", key = "ready",
        tip = "A tick, cross or question mark on each member during a ready check, and for a few seconds after." },
      { kind = "toggle", label = "Resurrection and summon", key = "incoming",
        tip = "\"Res coming\" on a member someone is resurrecting, and \"Summon\" on one with a summon waiting." },
    },
    {
      title = "Debuffs",
      { kind = "toggle", label = "Debuffs on the frames", key = "debuffs" },
      { kind = "step", label = "Size", key = "debuffSize", min = 8, max = 32, step = 1, when = debuffs, whyOff = "Needs debuffs on the frames." },
      { kind = "step", label = "How many", key = "debuffCount", min = 1, max = 6, step = 1, when = debuffs, whyOff = "Needs debuffs on the frames." },
      { kind = "toggle", label = "Ones you can remove first", key = "removableFirst", when = debuffs, whyOff = "Needs debuffs on the frames." },
      { kind = "toggle", label = "Only ones you can remove", key = "onlyRemovable", when = debuffs, whyOff = "Needs debuffs on the frames." },
      { kind = "toggle", label = "Bigger when you can remove it", key = "bigRemovable", when = debuffs, whyOff = "Needs debuffs on the frames." },
    },
    {
      title = "HoTs and shields",
      { kind = "toggle", label = "Your HoTs and shields", key = "hots",
        tip = "Your own heals over time and shields on each member, bottom right, with their time left." },
      { kind = "step", label = "Size", key = "hotSize", min = 8, max = 24, step = 1 },
      { kind = "step", label = "How many", key = "hotCount", min = 1, max = 5, step = 1, when = function() return set().hots end },
      { kind = "toggle", label = "Earth Shield and Fear Ward", key = "corners",
        tip = "An icon in the top right corner while a member has Earth Shield or Fear Ward, from anyone." },
    },
  }
  for _, card in ipairs(extra or {}) do cards[#cards + 1] = card end
  return cards
end
P.RaidCards = RaidCards

-- "Copy from": the other three sets.
local function CopyFromSets(except)
  local out = {}
  for _, s in ipairs(ns.Raid.SETS) do
    if s.key ~= except then
      local key = s.key
      out[#out + 1] = { key = key, name = s.name, get = function(def) return ns.Raid:Set(key)[def.key] end }
    end
  end
  return out
end

local function FramesPage(setKey, title, desc, keywords)
  Add({
    key = setKey, title = title, group = "Frames", needs = "Raid", part = "groups",
    desc = desc, keywords = keywords,
    io = function() return RaidIO(setKey) end,
    sections = function()
      local cards = RaidCards(setKey)
      cards[#cards + 1] = {
        title = "Party and raid frames",
        { kind = "note", text = function()
          local R = ns.Raid
          if R:HealOn() then return "Heal mode is on, so its settings are in use now. These come back when it's off." end
          return "Heal mode is off, so these are in use."
        end },
        { kind = "link", label = "Heal mode's settings", note = "Heal mode", fn = function()
          ns.Raid:Cfg().healEdit = ns.Raid:SetKind(setKey)
          ns.EditMode:Select("heal")
        end },
        { kind = "toggle", label = "VoltUI's party and raid frames", key = "groups", store = "part",
          tip = "Off gives you the game's own party and raid frames back, after a reload." },
      }
      return cards
    end,
    copy = function() return CopyFromSets(setKey) end,
    reset = function() ns.Raid:ResetSet(setKey) end,
    resetTip = title .. " settings back to their defaults",
    mover = function() return ns.Raid.holder and ns.Raid.holder.mover end,
  })
end

FramesPage("party", "Party frames",
  "VoltUI's own party frames, in place of the game's: up to five of you. Size, layout, bars and debuffs for a party are set here; the Raid tab has a raid's.",
  "party group frames healer width height power mana debuff dispel dungeon")
FramesPage("raid", "Raid frames",
  "VoltUI's own raid frames, in place of the game's: up to eight groups. Size, layout, bars and debuffs for a raid are set here; the Party tab has a party's.",
  "raid group frames healer width height power mana debuff dispel")

------------------------------------------------------------------------
-- Click slots: a click, and the spell it casts, picked from your healing spells
------------------------------------------------------------------------

local PICK_ROW_H, PICK_COL_W, PICK_PER_COL, PICK_TOP = 22, 190, 12, 24
local picker

-- What a click does without VoltUI: left targets, right opens the menu (with any key held).
local function Unset(combo)
  local btn = tostring(combo):match("(%d+)$")
  if btn == "1" then return "Target" end
  if btn == "2" then return "Menu" end
  return "Not set"
end

-- The list a slot opens: your healing spells with their icons, then Target, Menu and Clear.
-- One list, shared by every slot. It closes on a pick, a click anywhere else, a second click
-- on its slot, when its slot goes away (the settings window closes), and in combat.
local function Picker()
  if picker then return picker end
  local p = CreateFrame("Frame", "VoltUIClickPicker", UIParent)
  p:SetFrameStrata("FULLSCREEN_DIALOG")
  p:SetFrameLevel(20)
  p:SetClampedToScreen(true)
  p:EnableMouse(true)
  S.ThemePanel(p, 0.97)
  p.title = S.UIText(p, nil, "LEFT", nil, 12)
  p.title:SetPoint("TOPLEFT", 8, -6)
  p.title:SetTextColor(S.UI.sub[1], S.UI.sub[2], S.UI.sub[3])
  p.empty = S.UIText(p, nil, "LEFT", nil, 11)
  p.empty:SetTextColor(S.UI.hint[1], S.UI.hint[2], S.UI.hint[3])
  p.items = {}
  local away = CreateFrame("Button", nil, UIParent)
  away:SetAllPoints(UIParent)
  away:SetFrameStrata("FULLSCREEN_DIALOG")
  away:SetFrameLevel(10)
  away:RegisterForClicks("AnyUp")
  away:SetScript("OnClick", function() p:Hide() end)
  away:Hide()
  p.away = away
  p:SetScript("OnShow", function() away:Show() end)
  p:SetScript("OnHide", function(self)
    away:Hide()
    self.slot = nil
  end)
  p:SetScript("OnUpdate", function(self)
    if InCombatLockdown() or not (self.slot and self.slot:IsVisible()) then self:Hide() end
  end)
  p:Hide()
  picker = p
  P.picker = p
  return p
end

local function PickItem(p, i)
  if p.items[i] then return p.items[i] end
  local b = CreateFrame("Button", nil, p)
  b:SetSize(PICK_COL_W - 4, PICK_ROW_H)
  S.Highlight(b)
  b.icon = S.Tex(b, "ARTWORK")
  b.icon:SetSize(18, 18)
  b.icon:SetPoint("LEFT", 3, 0)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.text = S.UIText(b, nil, "LEFT", nil, 12)
  b.text:SetPoint("LEFT", 27, 0)
  b.text:SetPoint("RIGHT", -4, 0)
  b:SetScript("OnClick", function(self)
    local R = ns.Raid
    local slot = p.slot
    p:Hide()
    if not slot or InCombatLockdown() then return end
    local ch = self.choice
    R:SetBinding(slot.combo, (not ch.clear) and R.Copy(ch.bind) or nil)
    E():RefreshPage()
  end)
  p.items[i] = b
  return b
end

local function OpenPicker(slot)
  local R = ns.Raid
  local p = Picker()
  if p:IsShown() and p.slot == slot then
    p:Hide()
    return
  end
  if InCombatLockdown() then
    FUI:Print("Clicks can be changed once you're out of combat.")
    return
  end
  if slot.onOpen then slot.onOpen(slot) end
  local choices = R:PickChoices()
  local current = R:GetBinding(slot.combo)
  p.title:SetText(R:ComboName(slot.combo) .. " click")
  local spells = 0
  for _, ch in ipairs(choices) do
    if not ch.other then spells = spells + 1 end
  end
  local n = #choices
  local cols = math.max(1, math.ceil(n / PICK_PER_COL))
  local rows = math.ceil(n / cols)
  local top = PICK_TOP
  if spells == 0 then
    p.empty:ClearAllPoints()
    p.empty:SetPoint("TOPLEFT", 8, -PICK_TOP)
    p.empty:SetText("No healing spells in your spellbook yet.")
    p.empty:Show()
    top = top + 18
  else
    p.empty:Hide()
  end
  for i, ch in ipairs(choices) do
    local b = PickItem(p, i)
    local col, row = math.floor((i - 1) / rows), (i - 1) % rows
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", p, "TOPLEFT", 4 + col * PICK_COL_W, -(top + row * PICK_ROW_H))
    b.choice = ch
    if ch.icon then
      b.icon:SetTexture(ch.icon)
      b.icon:SetVertexColor(1, 1, 1)
    else
      b.icon:SetTexture(S.WHITE)
      b.icon:SetVertexColor(0.16, 0.18, 0.22)
    end
    b.text:SetText(ch.name)
    if R:SameBinding(current, ch) then
      b.text:SetTextColor(S.UI.accent[1], S.UI.accent[2], S.UI.accent[3])
    elseif ch.other then
      b.text:SetTextColor(S.UI.sub[1], S.UI.sub[2], S.UI.sub[3])
    else
      b.text:SetTextColor(1, 1, 1)
    end
    b:Show()
  end
  for i = n + 1, #p.items do p.items[i]:Hide() end
  p:SetSize(cols * PICK_COL_W + 8, top + rows * PICK_ROW_H + 6)
  p:ClearAllPoints()
  p:SetPoint("TOPLEFT", slot, "BOTTOMLEFT", 0, -2)
  p.slot = slot
  p:Show()
end
P.OpenPicker = OpenPicker

-- A click's slot: the spell's icon and name, or what it does. Click to pick, right-click
-- to clear.
local function ClickSlot(parent, width, height, combo)
  local R = ns.Raid
  local s = CreateFrame("Button", nil, parent)
  s:SetSize(width, height)
  s.combo = combo
  s.fill = S.Tex(s, "BACKGROUND")
  s.fill:SetAllPoints()
  S.Round(s.fill, S.UI.r.button)
  S.Paint(s.fill, S.UI.field[1], S.UI.field[2], S.UI.field[3], 1)
  s.edges = S.RoundEdges(s, "BORDER", nil, s, S.UI.r.button)
  S.Highlight(s, 0.05, S.UI.r.button)
  s.icon = S.Tex(s, "ARTWORK")
  s.icon:SetSize(height - 4, height - 4)
  s.icon:SetPoint("LEFT", 2, 0)
  s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  s.text = S.UIText(s, nil, "LEFT", nil, 12)
  s.text:SetPoint("LEFT", height + 2, 0)
  s.text:SetPoint("RIGHT", -14, 0)
  s.arrow = S.UIText(s, nil, "RIGHT", nil, 10)
  s.arrow:SetPoint("RIGHT", -4, 0)
  s.arrow:SetText("v")
  s.arrow:SetTextColor(S.UI.hint[1], S.UI.hint[2], S.UI.hint[3])
  function s:Paint()
    local b = R:GetBinding(self.combo)
    local icon = R:BindingIcon(b)
    if icon then
      self.icon:SetTexture(icon)
      self.icon:SetVertexColor(1, 1, 1)
    else
      self.icon:SetTexture(S.WHITE)
      self.icon:SetVertexColor(0.16, 0.18, 0.22)
    end
    if b then
      self.text:SetText(R:Describe(b))
      self.text:SetTextColor(1, 1, 1)
    else
      self.text:SetText(Unset(self.combo))
      self.text:SetTextColor(S.UI.hint[1], S.UI.hint[2], S.UI.hint[3])
    end
    local on = self.isPicked and self.isPicked(self)
    -- The game's own click binding on this click wins over VoltUI's: an orange edge says so.
    self.clash = b and R.GameClickFor and R:GameClickFor(self.combo) or nil
    if self.clash then
      S.ColorEdges(self.edges, S.UI.warn[1], S.UI.warn[2], S.UI.warn[3], 1)
    elseif on then
      S.ColorEdges(self.edges, S.UI.accent[1], S.UI.accent[2], S.UI.accent[3], 0.9)
    else
      S.ColorEdges(self.edges, S.UI.soft[1], S.UI.soft[2], S.UI.soft[3], 0.9)
    end
  end
  s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  s:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
      if InCombatLockdown() then return end
      if picker then picker:Hide() end
      R:SetBinding(self.combo, nil)
      E():RefreshPage()
    else
      OpenPicker(self)
    end
  end)
  s:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local b = R:GetBinding(self.combo)
    GameTooltip:SetText(R:ComboName(self.combo) .. " click: " .. (b and R:Describe(b) or Unset(self.combo)), 1, 1, 1)
    GameTooltip:AddLine("Click to pick one of your healing spells. Right-click to clear.", 0.75, 0.75, 0.75, true)
    if self.clash then
      GameTooltip:AddLine(("The game's own click casting has %s on this click, and it wins over this one. Change or remove it in the game's Click Casting options."):format(self.clash), 1, 0.6, 0.3, true)
    end
    GameTooltip:Show()
  end)
  s:SetScript("OnLeave", function() GameTooltip:Hide() end)
  s:Paint()
  return s
end
P.ClickSlot = ClickSlot

-- One click on its own row: "Shift+Left click   [icon] Flash Heal".
local function ClickRow(combo)
  local R = ns.Raid
  return { kind = "custom", label = R:ComboName(combo) .. " click", height = 26,
    keywords = "click spell heal bind", build = function(r)
      r.slot = ClickSlot(r, 192, 22, combo)
      r.slot:SetPoint("RIGHT", r, "RIGHT", -8, 0)
    end, refresh = function(r) if r.slot then r.slot:Paint() end end }
end

-- Every click at once: the five buttons across, alone and with each key held down. Picking
-- one also makes it the click the "Edit a click" card works on.
local function ClickGrid()
  local R = ns.Raid
  local LEFT_W, CELL_H = 84, 25
  local function picked(s) return s.combo == (R.pickMod or "") .. (R.pickButton or "1") end
  return { kind = "custom", label = "", height = (#R.MODS + 1) * CELL_H + 4, build = function(r, width)
    local cellW = math.floor((width - 2 * S.INSET - LEFT_W) / #R.BUTTONS)
    r.slots = {}
    for i, bt in ipairs(R.BUTTONS) do
      local h = S.UIText(r, nil, "CENTER", nil, 11, nil, "mono") -- mouse buttons and keys
      h:SetPoint("TOPLEFT", S.INSET + LEFT_W + (i - 1) * cellW, -6)
      h:SetWidth(cellW)
      h:SetText(bt.name)
      h:SetTextColor(S.UI.sub[1], S.UI.sub[2], S.UI.sub[3])
    end
    for j, m in ipairs(R.MODS) do
      local y = -(j * CELL_H)
      local l = S.UIText(r, nil, "LEFT", nil, 11, nil, "mono")
      l:SetPoint("TOPLEFT", S.INSET, y - 6)
      l:SetText(m.key == "" and "Click" or m.name)
      l:SetTextColor(S.UI.sub[1], S.UI.sub[2], S.UI.sub[3])
      for i, bt in ipairs(R.BUTTONS) do
        local s = ClickSlot(r, cellW - 4, CELL_H - 3, m.key .. bt.key)
        s:SetPoint("TOPLEFT", r, "TOPLEFT", S.INSET + LEFT_W + (i - 1) * cellW + 2, y)
        s.isPicked = picked
        s.onOpen = function(self)
          R.pickMod, R.pickButton = m.key, bt.key
          E():RefreshPage()
        end
        r.slots[#r.slots + 1] = s
      end
    end
    r.clickGrid = true
  end, refresh = function(r)
    for _, s in ipairs(r.slots or {}) do s:Paint() end
  end }
end

-- The Heal mode page shows heal mode's party set or its raid set (raidCfg.healEdit).
local HEAL_EDIT = { { key = "party", name = "Party" }, { key = "raid", name = "Raid" } }
local function HealEditSet()
  return ns.Raid:Cfg().healEdit == "raid" and "healRaid" or "healParty"
end

Add({
  key = "heal", title = "Heal mode", group = "Frames", needs = "Raid", part = "groups",
  desc = "Heal mode's own frame settings, used while it's on: one set for party frames and one for raid frames, just the ones that matter for healing. Click-casting is on the Clicks tab.",
  keywords = "heal healer healing mode party raid frames overheal",
  io = function() return RaidIO(HealEditSet) end,
  -- Simple by default: what a healer changes. "Show every setting" swaps in the full list.
  -- Which of the two sets it shows (party or raid) is part of its shape.
  shape = function()
    local c = ns.Raid:Cfg()
    return (c.healAll and "all-" or "simple-") .. (c.healEdit or "party")
  end,
  sections = function()
    local R = ns.Raid
    local function set() return R:Set(HealEditSet()) end
    local raid = R:Cfg().healEdit == "raid"
    local mode = {
      title = "Heal mode",
      { kind = "cycle", label = "Heal mode", key = "healMode", store = "cfg", list = R.HEAL_MODES,
        tip = "Auto: on while your group role is healer. It switches between fights, never during one." },
      { kind = "cycle", label = "Settings for", key = "healEdit", store = "cfg", list = HEAL_EDIT, free = true, nocopy = true,
        tip = "Heal mode has a set for party frames and one for raid frames. Pick which one this page changes.",
        after = function() ns.EditMode:Select("heal") end },
      { kind = "note", text = function()
        if not R:HealOn() then return "In use now: the Party frames and Raid frames pages' settings." end
        return "In use now: heal mode, its " .. (R:Kind() == "raid" and "raid" or "party") .. " set."
      end },
    }
    -- What each click on a member casts, picked from your healing spells.
    local clicks = {
      title = "Clicks",
      { kind = "note", lines = 1, text = function()
        return R:Cfg().clicksWhen == "always" and "Click a slot to pick a spell. These work all the time."
          or "Click a slot to pick a spell. These work while heal mode is on."
      end },
    }
    for _, combo in ipairs(R.QUICK_CLICKS) do clicks[#clicks + 1] = ClickRow(combo) end
    clicks[#clicks + 1] = { kind = "link", label = "More clicks, macros", note = "Clicks", fn = function() ns.EditMode:Select("clicks") end }
    local more = {
      title = "More",
      { kind = "toggle", label = "Show every setting", key = "healAll", store = "cfg", free = true, nocopy = true,
        tip = "Every Raid frames setting, for heal mode's set: layout, colours, text, borders and the rest.",
        after = function() ns.EditMode:Select("heal") end },
    }
    if R:Cfg().healAll then
      local cards = RaidCards(HealEditSet)
      table.insert(cards, 1, mode)
      table.insert(cards, 2, clicks)
      cards[#cards + 1] = more
      return cards
    end
    return {
      mode,
      clicks,
      {
        title = raid and "Raid frames" or "Party frames",
        SimRow(HealEditSet, "Preview"),
        { kind = "step", label = "Width", key = "width", min = 30, max = 200, step = 1 },
        { kind = "step", label = "Height", key = "height", min = 16, max = 100, step = 1 },
        { kind = "step", label = "Scale", key = "scale", min = 0.5, max = 2, step = 0.05, fmt = "%.2f" },
      },
      {
        title = "Health",
        { kind = "cycle", label = "Health text", key = "hpText", list = RAID_HP_TEXT,
          tip = "Missing shows how much health is gone (-1634), empty at full health." },
        { kind = "cycle", label = "Colour", key = "hpColor", list = RAID_HP_COLORS },
        { kind = "toggle", label = "Incoming heals and shields", key = "heals", after = function()
          local s = set()
          s.shields = s.heals
        end },
        { kind = "toggle", label = "Overhealing", key = "overheal", when = function() return set().heals end },
        { kind = "step", label = "Out of range opacity", key = "rangeAlpha", min = 0.1, max = 1, step = 0.05, fmt = "%.2f" },
        { kind = "cycle", label = "Power bar", key = "power", list = RAID_POWER },
      },
      {
        title = "Debuffs",
        { kind = "toggle", label = "Only ones you can remove", key = "onlyRemovable" },
        { kind = "toggle", label = "Bigger when you can remove it", key = "bigRemovable" },
        { kind = "step", label = "Size", key = "debuffSize", min = 8, max = 32, step = 1 },
        { kind = "link", label = "Dispel windows and warning", note = "Dispels", fn = function() ns.EditMode:Select("dispel") end },
      },
      {
        title = "HoTs and shields",
        { kind = "toggle", label = "Your HoTs and shields", key = "hots",
          tip = "Your own heals over time and shields on each member, bottom right, with their time left." },
        { kind = "step", label = "Size", key = "hotSize", min = 8, max = 24, step = 1 },
        { kind = "toggle", label = "Earth Shield and Fear Ward", key = "corners",
          tip = "An icon in the top right corner while a member has Earth Shield or Fear Ward, from anyone." },
      },
      more,
    }
  end,
  copy = function() return CopyFromSets(HealEditSet()) end,
  reset = function() ns.Raid:ResetSet(HealEditSet()) end,
  resetTip = "The heal mode settings this page shows (party or raid) back to their defaults",
  mover = function() return ns.Raid.holder and ns.Raid.holder.mover end,
})

-- Click-casting: pick a click, then what it does.
local function ClicksIO()
  local function combo()
    local R = ns.Raid
    return (R.pickMod or "") .. (R.pickButton or "1")
  end
  local function bind() return ns.Raid:GetBinding(combo()) or { kind = "none" } end
  return {
    blocked = InCombat,
    get = function(def)
      local R = ns.Raid
      if def.store == "cfg" then return R:Cfg()[def.key] end
      if def.key == "pickButton" then return R.pickButton or "1" end
      if def.key == "pickMod" then return R.pickMod or "" end
      local b = bind()
      if def.key == "action" then return b.kind or "none" end
      if def.key == "spell" then
        if b.spell then return b.spell end
        local first = R:SpellChoices()[1]
        return first and first.key
      end
    end,
    set = function(def, v)
      local R = ns.Raid
      if def.store == "cfg" then
        R:Cfg()[def.key] = v
        return
      end
      if def.key == "pickButton" then R.pickButton = v; return end
      if def.key == "pickMod" then R.pickMod = v; return end
      local b = R.Copy(bind())
      if def.key == "action" then
        b.kind = v
        if v == "spell" and not b.spell and not b.value then
          local first = R:SpellChoices()[1]
          b.spell = first and first.key or nil
        end
        if v ~= "spell" and v ~= "macro" then b.spell, b.value = nil, nil end
        if v == "macro" then b.spell = nil end
      elseif def.key == "spell" then
        b.kind, b.spell, b.value = "spell", v or nil, nil
      end
      R:SetBinding(combo(), b)
    end,
    changed = function(def)
      if def.store == "cfg" then ns.Raid:ApplyClicks() end
    end,
  }
end

-- The typed spell (with a rank) or the macro's text, for the picked click.
local function TypedRow()
  return { kind = "custom", height = 64, label = "", build = function(r, width)
    local R = ns.Raid
    r.box = S.TextBox(r, width - 2 * S.INSET, 58, { hint = "A spell with its rank, Heal(Rank 2), or the macro's text", onChange = function(text)
      if InCombatLockdown() then return end
      local combo = (R.pickMod or "") .. (R.pickButton or "1")
      local b = R.Copy(R:GetBinding(combo) or { kind = "none" })
      if b.kind == "macro" then
        b.value = text
      else
        b.kind = "spell"
        b.value = text ~= "" and text or nil
      end
      R:SetBinding(combo, b)
    end })
    r.box:SetPoint("TOPLEFT", S.INSET, -3)
    r.typed = true
  end, refresh = function(r)
    local R = ns.Raid
    if not r.box or (r.box.edit.HasFocus and r.box.edit:HasFocus()) then return end
    local b = R:GetBinding((R.pickMod or "") .. (R.pickButton or "1"))
    r.box:SetText(b and type(b.value) == "string" and b.value or "")
  end }
end

Add({
  key = "clicks", title = "Clicks", group = "Frames", needs = "Raid", part = "groups", wide = true,
  desc = "Click-casting on the party and raid frames: every mouse button, alone or with Shift, Ctrl and Alt. Click a slot to pick one of your healing spells.",
  keywords = "click cast casting mouse binding heal dispel macro mouseover spell keybind",
  io = ClicksIO,
  sections = function()
    local R = ns.Raid
    local function spell() local b = R:GetBinding((R.pickMod or "") .. (R.pickButton or "1")); return b and b.kind == "spell" end
    local function typed()
      local b = R:GetBinding((R.pickMod or "") .. (R.pickButton or "1"))
      return b and (b.kind == "spell" or b.kind == "macro")
    end
    return {
      {
        title = "Every click", full = true,
        { kind = "note", lines = 1, text = "Click a slot to pick one of your healing spells. Right-click it to clear it." },
        ClickGrid(),
      },
      {
        title = "Clicks",
        { kind = "cycle", label = "Clicks work", key = "clicksWhen", store = "cfg", list = R.CLICKS_WHEN, segWidth = 260,
          tip = "In heal mode only, or always. Otherwise a click targets and a right-click opens the menu." },
        { kind = "button", label = "Ready-made clicks", text = "Use them", fn = function()
          R:UseDefaultClicks()
          ns.EditMode:RefreshPage()
        end, buttonTip = "Your class's ready-made clicks, in place of yours" },
        { kind = "note", lines = 2, when = function() return R:GameClickBindings() > 0 end, text = function()
          local n = R:GameClickBindings()
          if n == 0 then return "" end
          return ("The game's own click casting has %d click%s set, and those win over VoltUI's on the same click."):format(n, n == 1 and "" or "s")
        end },
      },
      {
        title = "Edit a click",
        { kind = "note", lines = 1, text = "For a macro, focus, or a spell at a set rank. The click picked above, or pick one here." },
        { kind = "cycle", label = "Button", key = "pickButton", list = R.BUTTONS, stepper = true, free = true, nocopy = true },
        { kind = "cycle", label = "With", key = "pickMod", list = R.MODS, stepper = true, free = true, nocopy = true },
        { kind = "cycle", label = "Does", key = "action", list = R.ACTIONS, stepper = true, nocopy = true },
        { kind = "cycle", label = "Spell", key = "spell", stepper = true, nocopy = true, when = spell,
          list = function()
            local b = R:GetBinding((R.pickMod or "") .. (R.pickButton or "1"))
            return R:SpellChoices(b and b.spell)
          end },
        TypedRow(),
        { kind = "note", lines = 1, when = typed, text = "Typed text wins over the spell picked above. Empty it to use the pick." },
      },
      {
        title = "Mouseover macro", full = true,
        { kind = "note", lines = 2, text = "Clicks work on the frames. For a key, a macro like this one casts on whoever is under the mouse, in combat too:" },
        { kind = "custom", height = 34, build = function(r, width)
          r.box = S.TextBox(r, width - 2 * S.INSET, 28, { readOnly = true })
          r.box:SetPoint("TOPLEFT", S.INSET, -3)
        end, refresh = function(r) if r.box then r.box:SetText(R:MacroExample()) end end },
      },
    }
  end,
  reset = function() ns.Raid:UseDefaultClicks() end,
  resetTip = "Your clicks back to your class's ready-made ones",
})

-- Dispel windows and the dispel warning (Dispel.lua).
local function DispelIO()
  return {
    blocked = InCombat,
    default = function(def) return ns.Dispel.DEFAULTS[def.key] end,
    get = function(def) return ns.Dispel:Cfg()[def.key] end,
    set = function(def, v) ns.Dispel:Cfg()[def.key] = v end,
    changed = function() ns.Dispel:Apply() end,
  }
end

Add({
  key = "dispel", title = "Dispels", group = "Frames", needs = "Raid", part = "groups",
  desc = "Dispel windows that show who has a debuff you can remove, and a warning with a sound when someone gets one.",
  keywords = "dispel cleanse cure remove debuff magic curse disease poison warning sound alert window",
  io = DispelIO,
  sections = function()
    local D = ns.Dispel
    local function windows() return D:Cfg().windows ~= "off" end
    local function warn() return D:Cfg().warn ~= "off" end
    return {
      {
        title = "Dispel windows",
        { kind = "cycle", label = "Windows", key = "windows", list = D.WHEN, segWidth = 208,
          tip = "A square for each member that shows while they have a debuff you can remove." },
        { kind = "step", label = "Size", key = "size", min = 20, max = 60, step = 1, when = windows },
        { kind = "note", lines = 2, text = function()
          local sp = D:Spells()
          if not sp[1] then return "You don't know a dispel spell yet, so the windows stay away." end
          if sp[2] then return ("Left-click casts %s, right-click %s."):format(sp[1].name, sp[2].name) end
          return ("Left-click casts %s."):format(sp[1].name)
        end },
        { kind = "note", lines = 3, text = "A window shows only while its member has something you can remove, and keeps its place in a fight. The empty squares still take clicks, so put them away from where you click the world." },
      },
      {
        title = "Warning",
        { kind = "cycle", label = "Warning", key = "warn", list = D.WHEN, segWidth = 208,
          tip = "A large line when someone gets a debuff you can remove: who, what, and which click removes it." },
        { kind = "cycle", label = "Sound", key = "sound", list = D.SOUNDS, segWidth = 208, when = warn },
        { kind = "step", label = "Size", key = "warnScale", min = 0.6, max = 2, step = 0.05, fmt = "%.2f", when = warn },
        { kind = "button", label = "Try it", text = "Test", fn = function() D:Test() end,
          buttonTip = "Shows a made-up warning and plays its sound" },
      },
      {
        title = "Moving",
        { kind = "link", label = "Move the windows and the warning", note = "Move", fn = function() FUI:SetUnlocked(true) end },
      },
    }
  end,
  reset = function() ns.Dispel:Reset() end,
  resetTip = "Dispel windows and warning back to their defaults",
  mover = function() return ns.Dispel.holder and ns.Dispel.holder.mover end,
})

------------------------------------------------------------------------
-- Action bars
------------------------------------------------------------------------

-- The bars page and the menu and bags page work the same way, with a bar picked on each.
-- The bar a bars page is showing ("barKey" for Action bars, "extraKey" for Menu, bags, XP).
-- Picked the first time anything asks: search draws these pages' rows before the pages have
-- ever been opened, and with no bar picked that threw an error on every key typed.
local function BarKey(pick)
  local e = E()
  if e[pick] == nil then
    if pick == "barKey" then
      e[pick] = "bar1"
    else
      local ok, list = pcall(ns.ActionBars.List, ns.ActionBars, true)
      local first = ok and type(list) == "table" and list[1]
      e[pick] = first and first.key or "menu"
    end
  end
  return e[pick]
end

local function BarIO(pick)
  local function hidden()
    local c = ns.ActionBars:Cfg("menu")
    c.hide = c.hide or {}
    return c.hide
  end
  return {
    blocked = InCombat,
    default = function(def)
      if def.store then return nil end
      return ns.ActionBars:DefaultFor(BarKey(pick), def.key)
    end,
    get = function(def)
      if def.store == "pick" then return BarKey(pick) end
      if def.store == "menuButton" then return not hidden()[def.key] end
      return ns.ActionBars:Cfg(BarKey(pick))[def.key]
    end,
    set = function(def, v)
      if def.store == "pick" then
        E()[pick] = v
      elseif def.store == "menuButton" then
        hidden()[def.key] = (not v) or nil
      else
        ns.ActionBars:Cfg(BarKey(pick))[def.key] = v
      end
    end,
    changed = function(def)
      local AB = ns.ActionBars
      if def.key == "barRange" then
        if not ns.db.barRange then
          for _, b in ipairs(AB.buttons) do AB:SetRange(b, true, true) end
        end
      elseif def.key == "barProcs" or def.key == "barProcStyle" then
        if AB.Glow then AB.Glow:Refresh() end -- ProcGlow.lua only loads after a full restart
      elseif def.store ~= "pick" then
        AB:Changed(E()[pick])
      end
      E():Mark()
    end,
  }
end

local function BarSources(pick, extra)
  return function()
    local out = {}
    for _, it in ipairs(ns.ActionBars:List(extra)) do
      if it.key ~= E()[pick] then
        local key = it.key
        out[#out + 1] = { key = key, name = it.name, get = function(def) return ns.ActionBars:Cfg(key)[def.key] end }
      end
    end
    return out
  end
end

local function BarMover(pick)
  return function()
    local f = ns.ActionBars.frames[E()[pick]]
    return f and f.mover
  end
end

Add({
  key = "bars", title = "Action bars", group = "Action bars", needs = "ActionBars", part = "bars",
  desc = "Pick a bar in the first card; the rest of the page changes that bar.",
  keywords = "action bar buttons keybinds hotkeys macro cooldown",
  io = function() return BarIO("barKey") end,
  sections = function()
    local function c() return ns.ActionBars:Cfg(BarKey("barKey")) end
    -- The totem bar has fixed buttons, no empty slots to hide, no macros and no stacks.
    local function slots() return BarKey("barKey") ~= "totem" end
    local function on(key) return function() return c()[key] end end
    local function slotted(key) return function() return slots() and c()[key] end end
    local function button(def)
      def.when = def.when or slots
      return def
    end
    return {
      {
        title = "Bar",
        { kind = "cycle", stepper = true, label = "Editing", key = "bar", store = "pick",
          list = function() return ns.ActionBars:List() end },
        { kind = "toggle", label = "Show this bar", key = "on" },
      },
      {
        title = "Layout",
        button({ kind = "step", label = "Buttons", key = "count", min = 1, max = 12, step = 1 }),
        { kind = "step", label = "Buttons per row", key = "perRow", min = 1, max = 12, step = 1 },
        { kind = "step", label = "Button size", key = "size", min = 16, max = 64, step = 1 },
        { kind = "step", label = "Gap across", key = "gapX", min = 0, max = 24, step = 1 },
        { kind = "step", label = "Gap between rows", key = "gapY", min = 0, max = 24, step = 1 },
        { kind = "step", label = "Scale", key = "scale", min = 0.5, max = 2, step = 0.05, fmt = "%.2f" },
        { kind = "cycle", label = "Fill rows to the", key = "growX", list = GROW_X },
        { kind = "cycle", label = "Add rows going", key = "growY", list = GROW_Y },
      },
      {
        title = "When it shows",
        { kind = "cycle", label = "Show", key = "mode", list = BAR_MODES, segWidth = 216 },
        { kind = "cycle", label = "Fade out", key = "fade", list = BAR_FADES, segWidth = 216, tip = BAR_FADE_TIP,
          keywords = "hover mouseover fade combat hide transparent" },
        { kind = "step", label = "Opacity", key = "alpha", min = 0.1, max = 1, step = 0.05, fmt = "%.2f" },
        { kind = "step", label = "Opacity when faded", key = "fadeTo", min = 0, max = 1, step = 0.05, fmt = "%.2f",
          when = function() return BarFades(c()) end, whyOff = "Only for a bar that fades out." },
        button({ kind = "toggle", label = "Empty slots", key = "empty" }),
      },
      {
        title = "Text",
        { kind = "toggle", label = "Key bindings", key = "keys", isText = true },
        { kind = "step", label = "Key size", key = "keySize", min = 7, max = 24, step = 1, when = on("keys"), whyOff = "Needs key bindings showing.", isText = true },
        button({ kind = "toggle", label = "Macro names", key = "macro", isText = true }),
        { kind = "step", label = "Macro size", key = "macroSize", min = 7, max = 24, step = 1, when = slotted("macro"), whyOff = "Needs macro names on, on a bar that has them.", isText = true },
        button({ kind = "toggle", label = "Stack counts", key = "stack", isText = true }),
        { kind = "step", label = "Stack size", key = "stackSize", min = 7, max = 24, step = 1, when = slotted("stack"), whyOff = "Needs stack counts on, on a bar that has them.", isText = true },
      },
      {
        title = "Cooldowns and border",
        { kind = "toggle", label = "Cooldown numbers", key = "cdText", isText = true },
        { kind = "step", label = "Number size", key = "cdSize", min = 8, max = 32, step = 1, when = on("cdText"), whyOff = "Needs cooldown numbers on.", isText = true },
        { kind = "step", label = "No number under", key = "cdMin", min = 0, max = 10, step = 0.5, fmt = "%.1f s", when = on("cdText"), whyOff = "Needs cooldown numbers on.",
          keywords = "global cooldown gcd short hide number minimum",
          tip = "A cooldown whose whole length is shorter than this shows no number, only the sweep. At 2 the global cooldown stays clear of numbers. 0 shows a number on every cooldown." },
        { kind = "step", label = "Tenths under", key = "cdTenths", min = 0, max = 10, step = 1, fmt = "%d s", when = on("cdText"), whyOff = "Needs cooldown numbers on.",
          keywords = "decimal tenths milliseconds last seconds precise",
          tip = "With less than this left, the number shows tenths of a second (2.4). 0 keeps whole seconds." },
        { kind = "toggle", label = "Border", key = "border" },
      },
      {
        title = "Plate",
        { kind = "toggle", label = "Plate behind this bar", key = "plate", keywords = "plate panel glass background backdrop frame",
          tip = "A glass panel behind the bar's buttons, a little larger than them. The bar doesn't move or resize; the plate reaches past it by its padding." },
        { kind = "step", label = "Plate strength", key = "plateAlpha", min = 0.1, max = 1, step = 0.05, fmt = "%.2f",
          when = on("plate"), whyOff = "Needs the plate on.", tip = "0.55 is glass; 1 is a solid plate." },
        { kind = "step", label = "Plate padding", key = "platePad", min = 0, max = 16, step = 1,
          when = on("plate"), whyOff = "Needs the plate on." },
      },
      {
        title = "All bars",
        { kind = "toggle", label = "Red icons out of range", key = "barRange", store = "db" },
        { kind = "toggle", label = "Glow when a spell procs", key = "barProcs", store = "db", free = true,
          keywords = "proc procs flash ping glow maelstrom instant clearcasting overpower",
          tip = "A button lights up while a proc makes its spell instant, free or usable: Maelstrom Weapon at 5 stacks on Lightning Bolt, Shadow Trance on Shadow Bolt, Overpower after a dodge. The game's own proc glow lights it too." },
        { kind = "cycle", stepper = true, label = "Proc glow look", key = "barProcStyle", store = "db", free = true,
          list = function() return ns.ActionBars.Glow and ns.ActionBars.Glow.STYLES or {} end,
          when = function() return ns.db.barProcs ~= false end, whyOff = "Needs Glow when a spell procs on.",
          tip = "VoltUI's square glow, pulsing or still, both with a flash as it lights; or the game's own round proc art, fitted to the button." },
        { kind = "button", label = "See the glow", text = "Light them", free = true,
          when = function() return ns.db.barProcs ~= false end, whyOff = "Needs Glow when a spell procs on.",
          fn = function() if ns.ActionBars.Glow then ns.ActionBars.Glow:Test() end end,
          tip = "Every button with something on it lights for 3 seconds. Also /volt bars glow." },
      },
    }
  end,
  copy = BarSources("barKey"),
  reset = function() ns.ActionBars:ResetBar(BarKey("barKey")) end,
  resetTip = "This bar's look and spot back to their defaults",
  mover = BarMover("barKey"),
  actions = {
    { key = "copy", text = "Copy to all bars", width = 120, tip = "Gives every other bar this bar's size, gaps, scale, text and visibility",
      fn = function()
        local AB = ns.ActionBars
        local function deep(v)
          if type(v) ~= "table" then return v end
          local t = {}
          for k, x in pairs(v) do t[k] = deep(x) end
          return t
        end
        if InCombatLockdown() then
          return E():Toast("Can't copy in combat: these settings resize the bars.", nil, nil, 6)
        end
        local before = deep(ns.db.barCfg or {})
        local from = AB:Def(BarKey("barKey"))
        AB:CopyLook(BarKey("barKey"))
        E():RefreshPage()
        E():Toast(("Gave every bar the look of %s."):format(from and from.label or "this bar"), "Undo", function()
          if InCombatLockdown() then return end
          for key, cfg in pairs(before) do
            local now = AB:Cfg(key)
            for k in pairs(now) do now[k] = nil end
            for k, v in pairs(cfg) do now[k] = deep(v) end
          end
          AB:ApplyAll()
          E().toast = nil
          E():RefreshPage()
        end)
      end },
    { key = "keys", text = "Quick keybinds", width = 110, tip = "Hover a button and press a key to bind it",
      fn = function() ns.ActionBars:QuickKeys() end },
  },
})

Add({
  key = "extras", title = "Menu, bags, XP", group = "Action bars", needs = "ActionBars", part = "bars",
  desc = "The menu and bag buttons, and the XP and reputation bars. Pick one in the first card.",
  keywords = "micro menu bag buttons experience reputation rested",
  io = function() return BarIO("extraKey") end,
  sections = function()
    local function c() return ns.ActionBars:Cfg(BarKey("extraKey")) end
    local function isMenu() return BarKey("extraKey") == "menu" end
    local function isBags() return BarKey("extraKey") == "bags" end
    local function isXP() return BarKey("extraKey") == "xp" end
    local function isStatus() return BarKey("extraKey") == "xp" or BarKey("extraKey") == "rep" end
    local function hasButtons() return not isStatus() end
    local menu = { title = "Menu buttons" }
    for _, item in ipairs(ns.ActionBars:MenuList()) do
      menu[#menu + 1] = { kind = "toggle", label = item.name, key = item.key, store = "menuButton", when = isMenu, whyOff = "Only for the menu buttons." }
    end
    return {
      {
        title = "Bar",
        { kind = "cycle", stepper = true, label = "Editing", key = "bar", store = "pick",
          list = function() return ns.ActionBars:List(true) end },
        { kind = "toggle", label = "Show this bar", key = "on" },
      },
      {
        title = "Layout",
        { kind = "step", label = "Buttons per row", key = "perRow", min = 1, max = 14, step = 1, when = hasButtons, whyOff = "Not for the XP and reputation bars." },
        { kind = "step", label = "Button size", key = "size", min = 16, max = 64, step = 1, when = hasButtons, whyOff = "Not for the XP and reputation bars." },
        { kind = "step", label = "Gap across", key = "gapX", min = 0, max = 24, step = 1, when = hasButtons, whyOff = "Not for the XP and reputation bars." },
        { kind = "step", label = "Gap between rows", key = "gapY", min = 0, max = 24, step = 1, when = hasButtons, whyOff = "Not for the XP and reputation bars." },
        { kind = "step", label = "Scale", key = "scale", min = 0.5, max = 2, step = 0.05, fmt = "%.2f" },
        { kind = "cycle", label = "Fill rows to the", key = "growX", list = GROW_X, when = hasButtons, whyOff = "Not for the XP and reputation bars." },
        { kind = "cycle", label = "Add rows going", key = "growY", list = GROW_Y, when = hasButtons, whyOff = "Not for the XP and reputation bars." },
      },
      {
        title = "When it shows",
        { kind = "cycle", label = "Show", key = "mode", list = BAR_MODES, segWidth = 216 },
        { kind = "cycle", label = "Fade out", key = "fade", list = BAR_FADES, segWidth = 216, tip = BAR_FADE_TIP,
          keywords = "hover mouseover fade combat hide transparent" },
        { kind = "step", label = "Opacity", key = "alpha", min = 0.1, max = 1, step = 0.05, fmt = "%.2f" },
        { kind = "step", label = "Opacity when faded", key = "fadeTo", min = 0, max = 1, step = 0.05, fmt = "%.2f",
          when = function() return BarFades(c()) end, whyOff = "Only for a bar that fades out." },
      },
      {
        title = "XP and reputation",
        { kind = "step", label = "Width", key = "width", min = 60, max = 2000, step = 1, when = isStatus, whyOff = "Only for the XP and reputation bars." },
        { kind = "step", label = "Height", key = "height", min = 4, max = 40, step = 1, when = isStatus, whyOff = "Only for the XP and reputation bars." },
        { kind = "cycle", label = "Numbers", key = "text", list = TEXT_MODES, when = isStatus, whyOff = "Only for the XP and reputation bars.", isText = true },
        { kind = "step", label = "Number size", key = "textSize", min = 7, max = 24, step = 1, when = isStatus, whyOff = "Only for the XP and reputation bars.", isText = true },
        { kind = "toggle", label = "Rested XP", key = "rested", when = isXP, whyOff = "Only for the XP bar." },
      },
      {
        title = "Look",
        { kind = "toggle", label = "Border", key = "border" },
        { kind = "toggle", label = "Plate behind this bar", key = "plate", when = hasButtons, whyOff = "Not for the XP and reputation bars.",
          keywords = "plate panel glass background backdrop frame",
          tip = "A glass panel behind the buttons, a little larger than them. The bar doesn't move or resize; the plate reaches past it by its padding." },
        { kind = "step", label = "Plate strength", key = "plateAlpha", min = 0.1, max = 1, step = 0.05, fmt = "%.2f",
          when = function() return hasButtons() and c().plate end, whyOff = "Needs the plate on.", tip = "0.55 is glass; 1 is a solid plate." },
        { kind = "step", label = "Plate padding", key = "platePad", min = 0, max = 16, step = 1,
          when = function() return hasButtons() and c().plate end, whyOff = "Needs the plate on." },
        { kind = "toggle", label = "Grey menu icons", key = "mono", when = isMenu, whyOff = "Only for the menu buttons." },
        { kind = "toggle", label = "Free bag slots", key = "stack", when = isBags, whyOff = "Only for the bag buttons.", isText = true },
        { kind = "step", label = "Free slots size", key = "stackSize", min = 7, max = 24, step = 1, isText = true,
          when = function() return isBags() and c().stack end },
      },
      {
        title = "Bags",
        { kind = "toggle", label = "Bag slots", key = "slots", when = isBags, whyOff = "Only for the bag buttons." },
        { kind = "toggle", label = "Reagent bag", key = "reagent", when = isBags, whyOff = "Only for the bag buttons." },
        { kind = "toggle", label = "Key ring", key = "keyring", when = isBags, whyOff = "Only for the bag buttons." },
      },
      menu,
    }
  end,
  copy = BarSources("extraKey", true),
  reset = function() ns.ActionBars:ResetBar(BarKey("extraKey")) end,
  resetTip = "This bar's look and spot back to their defaults",
  mover = BarMover("extraKey"),
  actions = {
    { key = "keys", text = "Quick keybinds", width = 110, tip = "Hover a button and press a key to bind it",
      fn = function() ns.ActionBars:QuickKeys() end },
  },
})

------------------------------------------------------------------------
-- Nameplates
------------------------------------------------------------------------

-- One kind of plate's page reads and writes that kind's set. "shared": every plate's settings,
-- "target": your target's.
local function PlateIO(set)
  local N = ns.Nameplates
  local function where(def)
    local c = N:Cfg()
    if def.store == "shared" then return c, nil end
    if def.store == "target" then return c.target, "target" end
    return c[set], set
  end
  return {
    blocked = Never, -- only looks, which can change in combat
    default = function(def)
      local _, which = where(def)
      if which == "target" then return N.TARGET_DEFAULTS[def.key] end
      if which then return N.TYPE_DEFAULTS[def.key] end
      return N.DEFAULTS[def.key]
    end,
    get = function(def)
      local t = where(def)
      return t[def.key]
    end,
    set = function(def, v)
      local t, which = where(def)
      if v == nil then
        N:Default(def.key, which) -- a swatch's right-click
      else
        t[def.key] = v
      end
    end,
    changed = function() N:Refresh() end,
  }
end

local function PlateSections(set)
  local N = ns.Nameplates
  local function c() return N:Cfg()[set] end
  local function volt() return c().hpColor == "volt" end
  local function mine() return c().hpText ~= "game" and c().hpText ~= "off" end
  local function castOn() return c().castBar end
  local function aurasOn() return c().auras end
  local enemy = set == "enemy"
  local health = {
    title = "Health bar",
    { kind = "cycle", label = "Colour", key = "hpColor", list = PLATE_COLORS,
      tip = "VoltUI's: the colours below, each yours to pick. Game's: the game's own colours." },
    { kind = "cycle", stepper = true, label = "Texture", key = "texture", list = N.Textures },
    { kind = "step", label = "Height (0 = game's)", key = "barHeight", min = 0, max = 30, step = 1 },
    { kind = "toggle", label = "Class colours on players", key = "class", when = volt, whyOff = "Needs VoltUI's colours, not the game's." },
  }
  local colours = { title = "Colours" }
  if enemy then
    health[#health + 1] = { kind = "cycle", label = "Threat colours", key = "threat", store = "shared", list = THREAT, when = volt, whyOff = "Needs VoltUI's colours, not the game's.",
      tip = "Tank: green while you hold a mob, orange as it slips, red when someone else has it. Damage: orange as you're about to pull it, red once you have." }
    colours[#colours + 1] = { kind = "color", label = "Units", store = "shared", when = volt, whyOff = "Needs VoltUI's colours, not the game's.", keys = {
      { key = "colHostile", name = "Hostile" }, { key = "colNeutral", name = "Neutral" },
      { key = "colTapped", name = "Tapped by someone else" },
    } }
    colours[#colours + 1] = { kind = "color", label = "Threat", store = "shared",
      when = function() return volt() and N:Cfg().threat ~= "off" end, keys = {
        { key = "colThreatGood", name = "Tanking it (tank)" }, { key = "colThreatWarn", name = "Losing or pulling it" },
        { key = "colThreatBad", name = "Not tanking it (tank), or have it (damage)" },
      } }
  else
    colours[#colours + 1] = { kind = "color", label = "Units", store = "shared", when = volt, whyOff = "Needs VoltUI's colours, not the game's.", keys = {
      { key = "colFriendly", name = "Friendly characters" }, { key = "colPlayer", name = "Players without class colours" },
    } }
  end
  local border = {
    title = "Border",
    { kind = "step", label = "Thickness (pixels)", key = "border", min = 1, max = 4, step = 1 },
    { kind = "color", label = "Colour", key = "colBorder" },
  }
  if enemy then
    border[#border + 1] = { kind = "toggle", label = "Aggro ring", key = "aggro", store = "shared",
      tip = "A ring in the threat colour round anything that's after you." }
  end
  border[#border + 1] = { kind = "toggle", label = "Quest marker", key = "quest", store = "shared", keywords = "quest objective mob kill needed exclamation",
    tip = "A gold ! after the health bar of a creature one of your quests still needs, with how many are left when the game says. For enemy and friendly plates alike." }
  return {
    health,
    colours,
    {
      title = "Health text",
      { kind = "cycle", stepper = true, label = "Show", key = "hpText", list = HP_TEXT, isText = true },
      { kind = "cycle", label = "Position", key = "hpTextPos", list = TEXT_POS, when = mine, whyOff = "Needs VoltUI's health text, not the game's.", isText = true },
      Scale("Size", "textScale", nil, { isText = true }),
    },
    {
      title = "Name and level",
      { kind = "cycle", label = "Name colour", key = "nameColor", list = PLATE_NAME, isText = true },
      Scale("Name size", "nameScale", nil, { isText = true }),
      Scale("Level size", "levelScale", nil, { isText = true }),
    },
    border,
    {
      title = "Cast bar",
      { kind = "toggle", label = "VoltUI cast bar", key = "castBar" },
      { kind = "step", label = "Height (0 = game's)", key = "castHeight", min = 0, max = 30, step = 1 },
      { kind = "toggle", label = "Time left", key = "castTime", isText = true },
      Scale("Text size", "castScale", nil, { isText = true }),
      { kind = "color", label = "Colours", when = castOn, whyOff = "Needs the VoltUI cast bar on.", keys = {
        { key = "colCast", name = "Cast" }, { key = "colChannel", name = "Channel" },
        { key = "colLocked", name = "Can't be interrupted" }, { key = "colFailed", name = "Interrupted or failed" },
      } },
    },
    {
      title = "Auras",
      { kind = "toggle", label = "VoltUI aura icons", key = "auras" },
      Scale("Debuff size", "debuffScale"),
      Scale("Buff size", "buffScale"),
      Scale("Crowd control size", "ccScale"),
      { kind = "cycle", label = "Timer numbers", key = "auraTimer", list = AURA_TIMER, isText = true,
        tip = "Short: the game's rule, numbers under a minute. All: every aura. Off: none." },
      Scale("Timer size", "timerScale", aurasOn, { isText = true }),
      Scale("Stack size", "stackScale", aurasOn, { isText = true }),
      { kind = "cycle", label = "Border", key = "auraBorder", list = AURA_BORDER, when = aurasOn, whyOff = "Needs VoltUI aura icons on." },
      { kind = "toggle", label = "Dark swipe", key = "swipe", when = aurasOn, whyOff = "Needs VoltUI aura icons on." },
    },
  }
end

local PLATE_HINT = "Which plates show, their size and what cast bars show are in the game's options."

-- (1.97.0) A sketch of a plate at the top of each nameplate page, with parts to click.
local PLATE_NOTE = "A sketch of a plate. Click a part of it to change that part."
local PLATE_ROWS = {
  border = { "border", "colBorder", "aggro" },
  health = { "hpColor", "texture", { "barHeight", "Height (0 = game's)" }, "class", "threat", "colHostile", "colFriendly", "colThreatGood" },
  hpText = { "hpText", "hpTextPos", "textScale" },
  name = { { "nameColor", "Colour" }, { "nameScale", "Size" } },
  level = { { "levelScale", "Size" } },
  cast = { "castBar", "castHeight", "castTime", "castScale", "colCast" },
  auras = { "auras", "debuffScale", "buffScale", "ccScale", "auraTimer", "timerScale", "stackScale", "auraBorder", "swipe" },
}
local TARGET_ROWS = {
  border = { "color", { "border", "Thickness (0 = same)" }, "glow" },
  health = { "barHeight" },
  hpText = { "hpText" },
  name = { { "nameScale", "Size" } },
}

local function PlatePage(key, set, title, desc, other, otherName)
  Add({
    key = key, title = title, group = "Nameplates", needs = "Nameplates", part = "nameplates",
    desc = desc, hint = PLATE_HINT,
    keywords = "nameplates plates health bar cast auras debuffs buffs " .. set,
    io = function() return PlateIO(set) end,
    sections = function() return PlateSections(set) end,
    preview = function(box) return ns.Nameplates:Preview(key, set, box) end,
    previewNote = PLATE_NOTE,
    pinned = function() return Pinned(key, PLATE_ROWS, PlateSections(set), ns.Nameplates.PARTS) end,
    copy = function()
      return { { key = other, name = otherName, get = function(def) return ns.Nameplates:Cfg()[other][def.key] end } }
    end,
    reset = function() ns.Nameplates:ResetCfg(set) end,
    resetTip = "These plates' settings back to their defaults",
  })
end
PlatePage("plates", "enemy", "Enemy plates", "Plates on anything you can attack: hostile and neutral units, and enemy players.", "friendly", "Friendly plates")
PlatePage("friendly", "friendly", "Friendly plates", "Plates on friendly characters and players. Inside dungeons and raids the game keeps these to itself.", "enemy", "Enemy plates")

Add({
  key = "plateTarget", title = "Your target", group = "Nameplates", needs = "Nameplates", part = "nameplates",
  desc = "How your target's plate stands out. These go on top of its enemy or friendly settings.",
  hint = PLATE_HINT,
  keywords = "nameplates plates target focus dim highlight",
  io = function() return PlateIO("target") end,
  preview = function(box) return ns.Nameplates:Preview("plateTarget", "target", box) end,
  previewNote = "A sketch of your target's plate, on an enemy. Click a part of it to change that part.",
  pinned = function() return Pinned("plateTarget", TARGET_ROWS, P.byKey.plateTarget.sections(), ns.Nameplates.PARTS) end,
  sections = function()
    local function t(key, extra)
      extra.key, extra.store = key, "target"
      return extra
    end
    return {
      {
        title = "Border",
        t("color", { kind = "cycle", label = "Colour", list = TARGET_BORDER }),
        t("border", { kind = "step", label = "Thickness (0 = same)", min = 0, max = 6, step = 1 }),
        t("glow", { kind = "toggle", label = "Faint ring round it" }),
      },
      {
        title = "Size and text",
        t("barHeight", { kind = "step", label = "Bar height (0 = same)", min = 0, max = 40, step = 1 }),
        t("hpText", { kind = "cycle", stepper = true, label = "Health text", list = TARGET_TEXT, isText = true,
          tip = "Health text on your target only: say Percent here and Off on the other pages." }),
        t("nameScale", { kind = "step", label = "Name size", min = 0.6, max = 2, step = 0.05, fmt = "%.2f", isText = true,
          tip = "Times its kind's name size: 1 keeps it the same." }),
      },
      {
        title = "Other plates",
        { kind = "step", label = "Dim them", key = "dim", store = "shared", min = 0, max = 0.8, step = 0.05, fmt = "%.2f",
          tip = "How much the other plates darken while you have a target. 0 leaves them be." },
      },
      {
        title = "Your focus",
        { kind = "toggle", label = "Orange border", key = "focus", store = "shared" },
      },
    }
  end,
  reset = function() ns.Nameplates:ResetCfg("target") end,
  resetTip = "Your target's settings back to their defaults",
})

------------------------------------------------------------------------
-- Bags
------------------------------------------------------------------------

local BAG_GROUPS = { "Layout", "Text", "Look" }
local BAG_SKIP = { font = true, glow = true, alpha = true, common = true } -- on the General page

Add({
  key = "bags", title = "Bags and bank", group = "Items", needs = "Bags", part = "bags",
  desc = "VoltUI's bag window, and its bank window when that's on.",
  keywords = "bags inventory bank columns slots categories item level",
  io = function() return DbIO(function() FUI:Refresh() end) end,
  sections = function()
    local out = {}
    for _, group in ipairs(BAG_GROUPS) do
      local sec = { title = group }
      for _, def in ipairs(ns.Bags.SETTINGS) do
        if def.group == group and not BAG_SKIP[def.key] then
          local row = {}
          for k, v in pairs(def) do row[k] = v end
          sec[#sec + 1] = row
        end
      end
      out[#out + 1] = sec
    end
    out[#out + 1] = {
      title = "Bank and more",
      { kind = "toggle", label = "VoltUI's bank window", key = "bank", store = "db", reload = true,
        tip = "Off gives you the game's bank window. Takes a reload." },
      { kind = "button", label = "Your bags", text = "Open them", fn = function() ns.Bags:Open() end },
    }
    return out
  end,
  reset = function() ns.Bags:Slash("reset") end,
  resetTip = "The bag settings back to their defaults",
})

------------------------------------------------------------------------
-- Loot, tooltips, selling
------------------------------------------------------------------------

Add({
  key = "loot", title = "Loot and tooltips", group = "Items",
  desc = "The loot window, the extra lines on item and creature tooltips, and selling your junk.",
  keywords = "loot window tooltip item level vendor price drops drop rate chance creature mob best loot world drop junk sell grey",
  io = function()
    return DbIO(function(def)
      if type(def.key) == "string" and def.key:find("^loot") and ns.Loot.enabled then ns.Loot:Reshow() end
    end)
  end,
  sections = function()
    return {
      {
        title = "Loot window", needs = "Loot", part = "loot", partLabel = "VoltUI's loot window",
        { kind = "step", label = "Scale", key = "lootScale", min = 0.6, max = 1.6, step = 0.05, fmt = "%.2f" },
        { kind = "step", label = "Width", key = "lootWidth", min = 180, max = 400, step = 10 },
        { kind = "step", label = "Rows before it scrolls", key = "lootRows", min = 3, max = 16, step = 1,
          tip = "A corpse with more than this scrolls with the mouse wheel, rather than making a very tall window." },
        { kind = "toggle", label = "Item level on gear", key = "lootIlvl" },
        { kind = "button", label = "See it", text = "Sample loot", fn = function() ns.Loot:Test() end },
        { kind = "button", label = "Where it opens", text = "Reset spot", fn = function()
          S.ClearSpot(ns.db, "lootLeft", "lootTop", "lootPoint")
          ns.EditMode:Toast("The loot window is back at its default spot.", nil, nil, 6)
        end },
      },
      {
        title = "Tooltips", needs = "Tooltips", part = "tooltips", partLabel = "VoltUI's tooltips",
        { kind = "cycle", label = "Where they show", key = "tipAnchor", list = function() return ns.Tooltips.ANCHORS end, segWidth = 190,
          tip = "For things in the world, like units under the mouse. Game's: where the game puts them. Cursor: at the mouse. Its spot: a place you choose with Move frames; the tooltip's bottom-right corner sits there." },
        { kind = "step", label = "Text size", key = "tipSize", min = 10, max = 18, step = 1, fmt = "%d",
          after = function() if ns.Tooltips.enabled then ns.Tooltips:Refresh() end end },
        { kind = "toggle", label = "Class colours on players' names", key = "tipClass" },
        { kind = "toggle", label = "Who they're targeting", key = "tipTarget" },
        { kind = "toggle", label = "Hide unit tooltips in combat", key = "tipCombat",
          tip = "For units in the world under the mouse, while you're in combat. Tooltips on frames and buttons still show." },
        { kind = "cycle", label = "Health on the bar", key = "tipHealth", list = function() return ns.Tooltips.HEALTH end, segWidth = 190,
          keywords = "health text percent number hp unit tooltip bar",
          tip = "Text on the health bar under a unit's tooltip. Off keeps the bar a thin line.",
          after = function() if ns.Tooltips.enabled then ns.Tooltips:Refresh() end end },
        { kind = "toggle", label = "Item level", key = "tipIlvl" },
        { kind = "toggle", label = "Vendor price", key = "tipVendor", tip = "Only when the game doesn't show one itself." },
        { kind = "toggle", label = "How many you have", key = "tipCount", keywords = "count bags bank own stock",
          tip = "A line on item tooltips with how many you carry, and how many more are in the bank." },
        { kind = "toggle", label = "Ids while Shift is held", key = "tipIds", keywords = "item id spell id npc id creature number",
          tip = "Hold Shift over an item, a spell or a creature for its id number. Nothing is added otherwise." },
        { kind = "toggle", label = "Where it drops", key = "tipDrops" },
      },
      {
        title = "Selling junk", needs = "Junk", part = "junk", partLabel = "Sell junk at vendors",
        { kind = "note", lines = 3, text = "Grey items sell when you talk to any vendor. Hold Shift as you open the vendor to skip it once. To keep a grey item, Alt-right-click it in VoltUI's bags; again to sell it as before." },
        { kind = "toggle", label = "Repair your gear too", key = "autoRepair", store = "db", keywords = "auto repair durability vendor armour broken",
          tip = "At a vendor that repairs, everything is repaired from your own money as the window opens, and chat says what it cost. Hold Shift as you open the vendor to skip it, with the junk sale. If you can't afford it, nothing is repaired and chat says so." },
        { kind = "button", label = "Kept items", text = "Sell them all again", keywords = "keep list junk grey exclude",
          tip = "Forgets every grey item you've said to keep, so they sell with the rest.",
          when = function() return ns.Junk:KeepCount() > 0 end, whyOff = "You aren't keeping any grey items.",
          fn = function()
            local n = ns.Junk:KeepCount()
            ns.Junk:ForgetKept()
            FUI:Print("%d kept item%s will sell with your junk again.", n, n == 1 and "" or "s")
            FUI:Refresh()
          end },
      },
    }
  end,
})

------------------------------------------------------------------------
-- Maps
------------------------------------------------------------------------

Add({
  key = "maps", title = "Minimap and map", group = "World",
  desc = "The square minimap, where it sits and its size, and the world map's look and zone levels.",
  keywords = "minimap world map zone levels labels coordinates square move scale size",
  io = function()
    return DbIO(function(def)
      if def.key == "minimapScale" then
        if ns.Minimap.enabled then ns.Minimap:Rescale() end
        return
      end
      if type(def.key) == "string" and def.key:find("^strip") then
        if ns.Minimap.enabled then ns.Minimap:ApplyInfo() end
        return
      end
      if def.key == "mapCoords" then
        if ns.WorldMap.enabled then ns.WorldMap:PaintCoords() end
        return
      end
      local W = ns.WorldMap
      if not W.enabled then return end
      if def.key == "mapDrag" then
        if W.grip then W.grip:SetShown(ns.db.mapDrag) end
        W:PlaceWindow()
      elseif def.key == "mapScale" then
        W:SetMapScale(ns.db.mapScale)
      else
        W:Draw()
      end
    end)
  end,
  sections = function()
    local function levels() return ns.db.mapLevels end
    return {
      {
        title = "Minimap", needs = "Minimap", part = "map", partLabel = "Square minimap",
        { kind = "note", lines = 2, text = "Square, with the place name on its own row, your coordinates and the tracking menu. Click Move frames at the top to drag it; the arrow keys nudge it." },
        { kind = "step", label = "Scale", key = "minimapScale", min = 0.5, max = 2, step = 0.05, fmt = "%.2f",
          tip = "The corner nearest the screen's edge stays put." },
        { kind = "button", label = "Spot and size", text = "Reset spot", tip = "Where the game had it, at its normal size.",
          fn = function() ns.Minimap:Reset() end },
      },
      {
        title = "Line under the minimap", needs = "Minimap",
        { kind = "toggle", label = "Clock", key = "stripClock", tip = "The game's clock, which the square minimap hides. It sits beside your coordinates. Click it for the calendar." },
        { kind = "toggle", label = "Latency", key = "stripMs" },
        { kind = "toggle", label = "Frame rate", key = "stripFps" },
        { kind = "toggle", label = "Durability", key = "stripDura", tip = "Your most worn piece of gear. Amber under half, red under a fifth." },
        { kind = "toggle", label = "Gold", key = "stripGold" },
        { kind = "toggle", label = "Mail", key = "stripMail", tip = "Says Mail while you have some waiting." },
        { kind = "note", lines = 2, text = "The clock sits beside your coordinates. The other five share the line under them, which goes when all five are off." },
      },
      {
        title = "World map", needs = "WorldMap", part = "worldmap", partLabel = "VoltUI's world map",
        { kind = "toggle", label = "Zone levels", key = "mapLevels" },
        { kind = "toggle", label = "Dark plate behind each", key = "mapPlates", when = levels, whyOff = "Needs zone levels on." },
        { kind = "step", label = "Label size", key = "mapLabelSize", min = 10, max = 24, step = 1, when = levels, whyOff = "Needs zone levels on." },
        { kind = "toggle", label = "VoltUI's look on the window", key = "mapSkin", reload = true, tip = "Takes a reload." },
        { kind = "toggle", label = "Drag it by its title", key = "mapDrag" },
        { kind = "step", label = "Small map's size", key = "mapScale", min = 0.6, max = 2, step = 0.05, fmt = "%.2f", keywords = "resize scale bigger smaller",
          tip = "Or drag the gold corner at the map's bottom right; right-click the corner for the normal size. The full-size map always fills the screen." },
        { kind = "button", label = "Where it opens", text = "Reset spot", fn = function() ns.WorldMap:Slash("reset") end },
      },
      {
        title = "Coordinates", needs = "WorldMap",
        { kind = "toggle", label = "Coordinates on the map", key = "mapCoords",
          tip = "Where you are and where the cursor is, at the bottom-left of the world map." },
      },
    }
  end,
  mover = function() return ns.Minimap.holder and ns.Minimap.holder.mover end,
})

------------------------------------------------------------------------
-- Other add-ons
------------------------------------------------------------------------

Add({
  key = "questie", title = "Questie", group = "Other add-ons", needs = "QuestieSkin", part = "questie",
  desc = "The Questie add-on in VoltUI's look: its tracker, settings and journey windows.",
  keywords = "questie quest tracker",
  io = function()
    return DbIO(function()
      local Q = ns.QuestieSkin
      if ns.db.questieFonts and Q.ready then
        Q:ApplyFonts()
        pcall(Q.QuestieTracker.Update, Q.QuestieTracker)
      end
    end)
  end,
  sections = function()
    return {
      {
        title = "Questie",
        { kind = "note", lines = 1, text = function()
          return ns.QuestieSkin.ready and "Questie is running and has VoltUI's look." or "Questie isn't installed or isn't running."
        end },
        { kind = "toggle", label = "VoltUI's font on its tracker", key = "questieFonts",
          tip = "Off leaves the tracker in its current font until you pick another in Questie's settings." },
      },
    }
  end,
  mover = function() return ns.QuestieSkin.mover end,
})

Add({
  key = "foreverdb", title = "ForeverDB", group = "Other add-ons",
  desc = "VoltUI can keep just the ForeverDB Companion's leveling window and switch the rest of it off.",
  keywords = "foreverdb companion helper leveling",
  io = function() return DbIO() end,
  sections = function()
    local function loaded() return type(_G.ForeverDB_DB) == "table" end
    return {
      {
        title = "ForeverDB Companion",
        { kind = "note", lines = 3, text = function()
          if not loaded() then return "The ForeverDB Companion add-on isn't loaded." end
          local text = ns.db.fdbTrimmed and ns.db.fdbTrimmed ~= "undone"
            and "VoltUI has kept only its leveling window, and switched the ForeverDB Helper off."
            or "ForeverDB is as you set it up."
          if ns.db.fdbWindowOff then text = text .. " Its leveling window is off too" .. (FUI.levelPlanner and (": " .. FUI.levelPlanner .. " plans your levelling.") or ".") end
          return text
        end },
        { kind = "button", label = "Its leveling window", text = function() return ns.db.fdbWindowOff and "Show it" or "Turn it off" end,
          when = loaded, fn = function()
          ns.Companion:Slash("window")
          FUI:NeedReload()
        end },
        { kind = "button", label = "Just the leveling window", text = "Trim it", when = loaded, fn = function()
          ns.Companion:Slash("")
          FUI:NeedReload()
        end },
        { kind = "button", label = "Everything as it was", text = "Undo", when = loaded, fn = function()
          ns.Companion:Slash("undo")
          FUI:NeedReload()
        end },
      },
    }
  end,
})

------------------------------------------------------------------------
-- Profiles
------------------------------------------------------------------------

Add({
  key = "profiles", title = "Profiles", group = "VoltUI",
  desc = "Sets of settings by name. Each character uses one; until you make a second, they all use Default.",
  keywords = "profile character alt spec layout copy",
  io = function()
    local Pr = ns.Profiles
    return {
      blocked = Never,
      get = function(def)
        if def.key == "use" then return Pr.Wanted(ns.db, Pr.Char()) end
        if def.key == "pick" then
          local names, ok = Pr:List(), false
          for _, n in ipairs(names) do if n == Pr.picked then ok = true end end
          if not ok then Pr.picked = names[1] end
          return Pr.picked
        end
      end,
      set = function(def, v)
        if def.key == "use" then
          Pr:Use(v)
        elseif def.key == "pick" then
          Pr.picked = v
        end
      end,
      changed = function() end,
    }
  end,
  sections = function()
    local Pr = ns.Profiles
    local function names()
      local out = {}
      for _, n in ipairs(Pr:List()) do out[#out + 1] = { key = n, name = n } end
      return out
    end
    local function pending() return Pr.Wanted(ns.db, Pr.Char()) ~= ns.db.activeProfile end
    return {
      {
        title = "This character",
        { kind = "cycle", stepper = true, label = "Uses profile", key = "use", list = names,
          tip = "The profile this character's settings come from. Choosing another takes a reload." },
        { kind = "note", lines = 2, text = function()
          if pending() then
            return ("In use now: %s. After a reload: %s."):format(ns.db.activeProfile, Pr.Wanted(ns.db, Pr.Char()))
          end
          return ("In use now: %s. Every change you make is saved to it."):format(ns.db.activeProfile)
        end },
        { kind = "button", label = "Bring it in", text = "Reload now", when = pending, fn = function() FUI:Reload() end },
        { kind = "button", label = "A profile of its own", text = "New profile", primary = true,
          tip = "Makes a profile named after this character, starting as a copy of the settings in use, and sets this character to use it.",
          fn = function()
            local name = Pr:New((Pr.Char():gsub("%-.*$", "")))
            ns.EditMode:Toast(("Made %s. Reload to start using it: changes before then stay in %s."):format(name, ns.db.activeProfile),
              "Reload now", function() FUI:Reload() end, 30)
            ns.EditMode:RefreshPage()
          end },
      },
      {
        title = "Other profiles",
        { kind = "cycle", stepper = true, label = "Profile", key = "pick", list = names },
        { kind = "note", lines = 2, text = function()
          local name = Pr.picked or Pr.DEFAULT
          local who = Pr:UsedBy(name)
          if name == ns.db.activeProfile then return "This is the one in use." end
          if name == Pr.DEFAULT then return "Used by every character that hasn't been given another." end
          return #who > 0 and ("Used by " .. table.concat(who, ", ") .. ".") or "No character uses it."
        end },
        { kind = "button", label = "Its settings onto the ones in use", text = "Copy and reload",
          tip = "Replaces the settings in use with that profile's, then reloads straight away so every part of VoltUI picks them up.",
          when = function() return Pr.picked ~= nil and Pr.picked ~= ns.db.activeProfile and ns.db.profiles[Pr.picked] ~= nil end,
          fn = function()
            if Pr:CopyFrom(Pr.picked) then
              FUI:NeedReload()
              FUI:Reload() -- straight away: the parts of VoltUI still hold the old settings' tables
            end
          end },
        { kind = "button", label = "Remove it",
          text = function() return Pr.armed ~= nil and Pr.armed == Pr.picked and "Click to confirm" or "Delete" end,
          when = function() return Pr.picked ~= nil and Pr.picked ~= Pr.DEFAULT and Pr.picked ~= ns.db.activeProfile end,
          fn = function(row)
            -- A second click within a few seconds does it, and the button says so, like Reset.
            if Pr.armed ~= Pr.picked then
              local name = Pr.picked
              Pr.armed = name
              ns.EditMode:RefreshPage()
              if C_Timer and C_Timer.After then
                C_Timer.After(4, function()
                  if Pr.armed == name then
                    Pr.armed = nil
                    if ns.EditMode:IsOpen() then ns.EditMode:RefreshPage() end
                  end
                end)
              end
              return
            end
            local name = Pr.picked
            Pr.armed = nil
            if Pr:Delete(name) then
              Pr.picked = nil
              ns.EditMode:Toast(("Removed the profile %s."):format(name), nil, nil, 6)
              ns.EditMode:RefreshPage()
            end
          end },
      },
      {
        title = "What's in a profile",
        { kind = "note", lines = 4, text = "Every setting and every frame's spot. Not in a profile, and shared by all of them: what VoltUI and other add-ons have noted, such as the error list. To move a profile to another account, use Share and back up." },
      },
    }
  end,
})

------------------------------------------------------------------------
-- Sharing and errors
------------------------------------------------------------------------

Add({
  key = "share", title = "Share and back up", group = "VoltUI",
  desc = "Your layout and settings as a string of text: keep it as a back-up, or paste in someone else's.",
  keywords = "export import profile layout backup back-up string copy paste",
  io = function() return ns.Share:IO() end,
  sections = function() return ns.Share:Sections() end,
})

Add({
  key = "errors", title = "Errors", group = "VoltUI", wide = true,
  desc = "Lua errors VoltUI caught, ready to copy and send.",
  keywords = "error lua bug report problem crash",
  io = function() return DbIO() end,
  sections = function() return ns.Errors:Sections() end,
})

------------------------------------------------------------------------
-- Copying between pages
------------------------------------------------------------------------

-- Can this row's value be copied from another page? The page's own settings only.
function P.Copyable(def)
  return def.key ~= nil and def.store == nil and not S.PLAIN_ROWS[def.kind] and not def.nocopy
end

-- Where the sidebar groups go, in order.
-- Pages with the same kind of rows share one sidebar entry and show as tabs across the top of
-- the page (since 1.37.0). Each is still its own page, with its own key, search results, Copy
-- from and Reset. `names` gives a tab a shorter label than its page's title.
P.TABS = {
  { key = "unit", title = "Unit frames", pages = { "player", "target", "tot", "pet", "focus" } },
  { key = "groups", title = "Party and raid", pages = { "party", "raid" }, names = { party = "Party", raid = "Raid" } },
  { key = "healing", title = "Healing", pages = { "heal", "clicks", "dispel" } },
  { key = "plates", title = "Nameplates", pages = { "plates", "friendly", "plateTarget" }, names = { plates = "Enemy", friendly = "Friendly" } },
  { key = "addons", title = "Other add-ons", pages = { "questie", "foreverdb" } },
}
P.tabOf = {}
for _, t in ipairs(P.TABS) do
  t.names = t.names or {}
  for _, key in ipairs(t.pages) do P.tabOf[key] = t end
end

-- The sidebar's headings, and the pages that sit under a different one than they were made with.
P.GROUPS = { "VoltUI", "Frames", "Bars", "World", "Items", "More" }
for key, group in pairs({
  bars = "Bars", extras = "Bars", plates = "World", friendly = "World", plateTarget = "World",
  questie = "More", foreverdb = "More", share = "More", errors = "More",
}) do
  P.byKey[key].group = group
end

-- The switches that only take effect after a reload, read off the pages' own rows (1.80.0):
-- a row with `reload = true` needs one either way, `reloadOff = true` only once it's switched
-- off. Core used to keep its own list of these, and the two had drifted apart. Worked out on
-- first use; a page that can't be listed just now is left out rather than stopping the rest.
function P.ReloadKeys()
  if P.reloadKeys then return P.reloadKeys end
  local keys = { both = {}, off = {} }
  local seen = {}
  for _, page in ipairs(P.list) do
    local ok, sections = pcall(page.sections)
    for _, sec in ipairs(ok and type(sections) == "table" and sections or {}) do
      for _, row in ipairs(type(sec) == "table" and sec or {}) do
        if type(row) == "table" and type(row.key) == "string" and not seen[row.key]
           and (row.store == "db" or row.store == nil) and (row.reload or row.reloadOff) then
          seen[row.key] = true
          local list = row.reload and keys.both or keys.off
          list[#list + 1] = row.key
        end
      end
    end
  end
  P.reloadKeys = keys
  return keys
end
