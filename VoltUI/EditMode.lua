-- VoltUI · Settings and edit mode
-- One window for every VoltUI setting (/volt). A sidebar lists the pages, grouped, with a search box
-- at the top that finds any setting by name and shows it, working, in the results. Each page is
-- cards of rows (Controls.lua) built from Pages.lua. Changes apply as you make them and are
-- saved straight away; there's nothing to apply.
--
-- Pages can copy settings from a page like them (the player frame's text onto the pet frame,
-- the raid frames' look onto the party frames, one bar onto another), with an undo, and reset
-- to their defaults after a second click.
--
-- Move frames (or /volt edit) puts a drag overlay on everything that can be moved, and the
-- toolbar from Move.lua: grid, snapping and pixel nudges. Clicking a frame opens its page.
-- Entering combat stops moving frames, since secure frames can't move in combat; the window can
-- stay open, and settings that would resize secure frames wait, dimmed, until the fight ends.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style
local P = ns.Pages

local E = { pages = {}, rows = {}, side = {}, ios = {}, actionButtons = {}, results = {}, lastTab = {}, tabButtons = {}, previews = {} }
local PREVIEW_H = 96 -- one height, so the cards don't move under the mouse as you drag a size
ns.EditMode = E

-- (1.87.0) 204 and 390 (184 and 330): mono letters are wider, and names ran into their controls
local SIDE_W, RAIL_W, COL_W, GAP = 204, 44, 390, 12 -- 12 between cards since 1.62.2 (10)
local HEAD, FOOT, PAGE_HEAD, BANNER_H, SIDE_ROW, SEARCH_H, TABS_H = 30, 40, 68, 30, 22, 24, 26 -- 68: a two-line description clears the tabs

-- The window's widths (since 1.61.0; it was always the 2-column one): drag its bottom-right
-- corner between them. "2r" and "1" fold the sidebar to a rail of icons that opens on hover.
-- On "3", a page with a preview keeps two columns of cards and the preview takes the third.
local SHAPES = {
  ["1"] = { cols = 1, rail = true },
  ["2r"] = { cols = 2, rail = true },
  ["2"] = { cols = 2 },
  ["3"] = { cols = 3 },
}
local SHAPE_ORDER = { "1", "2r", "2", "3" }
-- The cards, the gaps around them, and a gutter on the right so the scroll bar has room
-- (since 1.62.1).
local SCROLL_GUTTER = 10
local function ContentW(cols) return COL_W * cols + GAP * (cols + 1) + SCROLL_GUTTER end
local function ShapeWidth(key)
  local sh = SHAPES[key]
  return (sh.rail and RAIL_W or SIDE_W) + ContentW(sh.cols)
end
E.SHAPES, E.ShapeWidth = SHAPES, ShapeWidth
E.shape, E.cols, E.sideW = "2", 2, SIDE_W
local CONTENT_W = ContentW(2)
local WIDTH = SIDE_W + CONTENT_W
E.WIDTH, E.COL_W, E.CONTENT_W = WIDTH, COL_W, CONTENT_W
local floor, max, min = math.floor, math.max, math.min
local A = S.UI.accent

-- Older names for pages.
local ALIASES = { groups = "raid", healing = "heal", click = "clicks", clickcast = "clicks", dispels = "dispel", cleanse = "dispel", nameplates = "plates", enemy = "plates", castbar = "cast", unitframes = "player" }

local HINT = "Changes save as you make them."
local MOVE_HINT = "Drag a frame to move it. Click one to change it."

local function Now() return GetTime and GetTime() or 0 end

-- Is this part of VoltUI running (and not standing aside for another add-on)?
local function Running(name)
  local m = ns[name]
  return m ~= nil and m.enabled == true and not m.yielded
end
E.Running = Running

------------------------------------------------------------------------
-- Pages and their cards
------------------------------------------------------------------------

function E:IO(key)
  local io = self.ios[key]
  if not io then
    io = P.Wrap(P.byKey[key].io())
    self.ios[key] = io
  end
  return io
end

-- A card for a part of VoltUI that's off (or standing aside): its switch and what to do.
local function OffCard(def, title)
  local m = ns[def.needs]
  local yielded = m and m.enabled and m.yielded
  local card = { title = title or "This part of VoltUI" }
  if def.part and not yielded then
    card[#card + 1] = { kind = "toggle", label = def.partLabel or (m and m.name) or def.title, key = def.part, store = "part" }
  end
  card[#card + 1] = { kind = "note", lines = yielded and 2 or 1, text = function()
    if yielded then
      return ("%s is drawing these, so VoltUI leaves them alone. Turn %s off to get VoltUI's."):format(yielded, yielded)
    end
    if def.part and ns.db[def.part] ~= false then return "Switched on. Reload to start it." end
    return "Off. Switch it on, then reload."
  end }
  return card
end

-- A page's cards as they'll show: a card for a part that's off becomes its switch. A page
-- that shows one of several views (Timers, since 1.102.0) can give `searchSections`: the
-- cards the search looks through, whatever view is showing.
function E:Sections(def, forSearch)
  if def.needs and not Running(def.needs) then return { OffCard(def) } end
  local out = {}
  local list = forSearch and def.searchSections or def.sections
  for _, sec in ipairs(list()) do
    if sec.needs and not Running(sec.needs) then
      out[#out + 1] = OffCard(sec, sec.title)
    elseif sec.part then
      local s = { title = sec.title }
      s[1] = { kind = "toggle", label = sec.partLabel or "On", key = sec.part, store = "part" }
      for _, row in ipairs(sec) do s[#s + 1] = row end
      out[#out + 1] = s
    else
      out[#out + 1] = sec
    end
  end
  return out
end

local function CardHeight(card) return (card.head or S.CARD_HEAD) + card.used + (card.padBottom or 4) end

-- Lays cards out in columns (two unless the window says otherwise), each card under the
-- shortest column. A card marked `full` (a wide page's grid or text box) spans them all, below
-- whatever is above it.
local function Lay(frame, cards, cols)
  cols = cols or 2
  local heights = {}
  for i = 1, cols do heights[i] = 0 end
  local function tallest()
    local h = 0
    for i = 1, cols do h = max(h, heights[i]) end
    return h
  end
  for _, card in ipairs(cards) do
    if card.full then
      card.top = tallest() + GAP
      card:ClearAllPoints()
      card:SetPoint("TOPLEFT", frame, "TOPLEFT", GAP, -card.top)
      local bottom = card.top + CardHeight(card)
      for i = 1, cols do heights[i] = bottom end
    else
      local col = 1
      for i = 2, cols do if heights[i] < heights[col] then col = i end end
      card.top = heights[col] + GAP
      card:ClearAllPoints()
      card:SetPoint("TOPLEFT", frame, "TOPLEFT", GAP + (col - 1) * (COL_W + GAP), -card.top)
      heights[col] = card.top + CardHeight(card)
    end
  end
  return tallest() + GAP
end
E.Lay = Lay

-- How many columns of cards a page gets: the window's, less one on the widest window where the
-- page's preview takes the last column.
function E:PageCols(def)
  if self.cols >= 3 and def and def.preview and (not def.needs or Running(def.needs)) then return self.cols - 1 end
  return self.cols
end

-- A page is built the first time it's shown and kept. A page whose rows depend on something
-- outside VoltUI (the party page, on the kind of party frames the game uses) gives a `shape`, and
-- is built again when that changes. The old one's frame is only hidden: frames can't be freed.
function E:Page(key)
  local def = P.byKey[key]
  local cols = self:PageCols(def)
  -- A wide page's cards are as wide as the window, so each width gets its own build.
  local shape = def.shape and def.shape() or nil
  if def.wide then shape = tostring(shape) .. "|" .. cols end
  local page = self.pages[key]
  if page and page.shape == shape then
    if page.cols ~= cols then -- the window changed width: the same cards, laid out again
      page.cols = cols
      page.frame:SetWidth(ContentW(cols))
      page.height = Lay(page.frame, page.cards, cols)
      page.frame:SetHeight(page.height)
    end
    return page
  end
  -- One page is kept for each shape (heal mode's party and raid sets, simple and full), so
  -- flipping between them shows the one already built. Frames can't be freed, and building a
  -- new page on every flip left the old ones behind for good.
  self.shapes = self.shapes or {}
  local cacheKey = key .. ":" .. tostring(shape)
  if page then
    page.frame:Hide()
  else
    -- No page in use for this key: it was dropped on purpose, so its kept shapes go too.
    for k in pairs(self.shapes) do
      if k:sub(1, #key + 1) == key .. ":" then self.shapes[k] = nil end
    end
  end
  local kept = self.shapes[cacheKey]
  if kept then
    self.pages[key] = kept
    return kept
  end
  self.pages[key] = nil
  local io = self:IO(key)
  page = { key = key, def = def, shape = shape, cols = cols, rows = {}, cards = {}, frame = CreateFrame("Frame", nil, self.scroll.child) }
  page.frame:SetPoint("TOPLEFT", self.scroll.child, "TOPLEFT", 0, 0)
  page.frame:SetWidth(ContentW(cols))
  local wide = ContentW(cols) - GAP * 2
  for i, sec in ipairs(self:Sections(def)) do
    -- On a wide page only the cards that need the room (`full`) get it; the rest stay in two
    -- columns, where a label and its control are close together. A page that's off shows one card.
    local full = def.wide and (sec.full or sec.full == nil and def.wide == "all")
    local card = S.Card(page.frame, sec.title, full and wide or COL_W)
    card.sec, card.index, card.full = sec, i, full or nil
    card:SetNo(i) -- its place on the page, on its heading
    -- (1.102.0) a card can have one small button on its heading: { text, fn, tip }
    if sec.action then card:Action(sec.action.text, sec.action.fn, sec.action.tip) end
    for _, rowDef in ipairs(sec) do
      local r = card:Add(rowDef, io)
      r.page = key
      page.rows[#page.rows + 1] = r
      -- A custom row can hold rows of its own (the Home page's tiles): they count as the page's.
      for _, sub in ipairs(r.subRows or {}) do
        sub.page = key
        page.rows[#page.rows + 1] = sub
      end
    end
    page.cards[i] = card
  end
  page.height = Lay(page.frame, page.cards, cols)
  page.frame:SetHeight(page.height)
  page.frame:Hide()
  self.pages[key] = page
  self.shapes[cacheKey] = page
  return page
end

-- (1.102.0) A custom row that lists things (your timers, the spells to add) is as tall as
-- its list: when that changes, its card is stacked again and the page's cards laid out again.
function E:RowResized(r, h)
  h = max(1, floor(h + 0.5))
  if r.h == h then return end
  r.h = h
  r:SetHeight(h)
  local page = r.page and self.pages[r.page]
  if not page then return end -- still being built: its card reads the new height itself
  local mine = false
  for _, card in ipairs(page.cards) do
    for _, x in ipairs(card.rows) do
      if x == r then
        card:Arrange(card.rows)
        mine = true
      end
    end
  end
  if not mine then return end
  page.height = Lay(page.frame, page.cards, page.cols)
  page.frame:SetHeight(page.height)
  if self.shownPage == page.key and not self.query then self.scroll:SetContentHeight(page.height) end
end

-- (1.96.0) A page can put one more card above its own: `pinned()` gives its rows, a title
-- and a `key`, or nothing. The unit frame pages use it for the part picked in the preview.
-- The card holds settings the page's other cards have too, so its rows are marked `mirror`
-- and left out of the count of changes. One card is kept for each key. Returns the rows now
-- on the page.
function E:Pin(page)
  local def = page.def
  if not def.pinned or (def.needs and not Running(def.needs)) then return page.rows end
  local sec = def.pinned()
  local key = sec and sec.key or nil
  page.pins = page.pins or {}
  for k, card in pairs(page.pins) do card:SetShown(k == key) end
  local cards, rows = page.cards, page.rows
  if sec then
    local card = page.pins[key]
    if not card then
      local io = self:IO(page.key)
      card = S.Card(page.frame, sec.title, COL_W)
      for _, rowDef in ipairs(sec) do
        local r = card:Add(rowDef, io)
        r.page, r.mirror = page.key, true
      end
      S.ColorEdges(card.edges, A[1], A[2], A[3], 1) -- gold all round: it's the one in hand
      page.pins[key] = card
    end
    cards, rows = { card }, {}
    for _, c in ipairs(page.cards) do cards[#cards + 1] = c end
    for _, r in ipairs(page.rows) do rows[#rows + 1] = r end
    for _, r in ipairs(card.rows) do rows[#rows + 1] = r end
  end
  page.pinned = key
  page.height = Lay(page.frame, cards, page.cols)
  page.frame:SetHeight(page.height)
  return rows
end

-- A part was picked or let go of in a page's preview: its card comes or goes.
function E:Picked(key)
  if not self:IsOpen() or self.tab ~= key or self.query then return end
  self:Select(key)
  self.scroll:ScrollTo(0)
end

-- The strip at the top of a frame's page with a copy of the frame in it (since 1.39.0), drawn
-- again after every change. Pages give one with `preview(box)`.
function E:Preview()
  local box = self.previewBox
  if not box then return end
  local def = not self.query and P.byKey[self.tab or ""] or nil
  local on = def ~= nil and def.preview ~= nil and (not def.needs or Running(def.needs))
  for key, f in pairs(self.previews) do
    if not on or key ~= def.key then f:Hide() end
  end
  self.previewH = 0
  box:SetShown(on)
  if not on then return end
  local f, height, scale = def.preview(box)
  box.note:SetText(def.previewNote or "Shows you. Click a part of it to change that part.")
  if type(scale) ~= "number" or scale <= 0 then scale = 1 end
  self.previews[def.key] = f
  f:ClearAllPoints()
  -- On the widest window the preview has a column of its own beside the cards (since 1.61.0),
  -- which stays put while they scroll.
  self.docked = self:PageCols(def) < self.cols
  if self.docked then
    f:SetPoint("TOPLEFT", box, "TOPLEFT", 14 / scale, -46 / scale)
    self.previewH = 0
    return
  end
  f:SetPoint("LEFT", box, "LEFT", 14 / scale, 0) -- offsets are in the frame's own scale
  self.previewH = PREVIEW_H -- a frame taller than this is cut off at the strip's edge
  box:SetHeight(self.previewH)
end

function E:RefreshPage()
  for _, r in ipairs(self.rows) do r:Refresh() end
  self:Preview()
  if self.panel and self.panel:IsShown() then
    self:Banner()
    self:Footer()
    self:PaintReset()
    self:PaintStatus()
    self:PaintProfile()
  end
end

-- The picked frame's overlay stands out, and the move toolbar shows where it is.
function E:Mark()
  local def = P.byKey[self.tab or ""]
  local picked = def and def.mover and def.mover() or nil
  -- A page with no frame of its own (bags, loot, rares) leaves the picked frame as it is: its
  -- windows' stand-ins open that page, and were un-picked the moment they were clicked.
  if not picked then return end
  for _, m in ipairs(S.movers) do
    if m.fill then m.fill:SetColorTexture(A[1], A[2], A[3], m == picked and 0.45 or 0.2) end
  end
  if ns.Move then ns.Move:Pick(picked) end
end

-- Clicking a bar's overlay shows that bar's settings.
function E:PickBar(key)
  local page = ns.ActionBars:Def(key).extra and "extras" or "bars"
  if page == "extras" then self.extraKey = key else self.barKey = key end
  -- The window steps aside while frames are moved: a click brings it back, as on any other frame.
  if self:IsOpen() then self:Select(page) else self:Open(page) end
end

------------------------------------------------------------------------
-- Showing a page
------------------------------------------------------------------------

function E:ShowFrame(frame, height, rows)
  for _, page in pairs(self.pages) do
    if page.frame ~= frame then page.frame:Hide() end
  end
  if self.resultFrame and self.resultFrame ~= frame then self.resultFrame:Hide() end
  frame:Show()
  self.rows = rows
  self.scroll:SetContentHeight(height)
  self:RefreshPage()
end

function E:Select(key)
  key = ALIASES[key] or key
  local def = P.byKey[key]
  if not def or not self.panel then return end
  if self.copyPop then self.copyPop:Hide() end -- it belongs to the page it was opened on
  if self.query then self:ClearSearch() end
  local same = self.tab == key and self.shownPage == key
  self.tab, self.shownPage = key, key
  ns.db.editPage = key -- where the window opens next time
  local tg = P.tabOf[key]
  if tg then self.lastTab[tg.key] = key end -- its sidebar entry comes back to this tab
  if key == "bars" then self.barKey = self.barKey or "bar1" end
  if key == "extras" then
    local first = ns.ActionBars:List(true)[1]
    self.extraKey = self.extraKey or (first and first.key)
  end
  local page = self:Page(key)
  local rows = self:Pin(page)
  self:ShowFrame(page.frame, page.height, rows)
  if not same then self.scroll:ScrollTo(0) end
  self.title:SetText(tg and tg.title or def.title)
  self.desc:SetText(def.desc or "")
  self:Tabs(tg)
  self:Actions(def)
  self:PaintSide()
  self:Footer()
  self:Mark()
  self:Banner()
end

-- The buttons at the top right of a page: its own, Copy from and Reset.
function E:Actions(def)
  for _, b in pairs(self.actionButtons) do b:Hide() end
  local right = -GAP
  local function place(b)
    b:ClearAllPoints()
    b:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", right, -10)
    b:Show()
    right = right - b.width - 6
  end
  local running = not def or not def.needs or Running(def.needs)
  self.resetArmed = nil
  self:PaintReset()
  self.reset.tip = def and def.resetTip
  self.reset:SetShown(false)
  self.copyFrom:SetShown(false)
  if not def or not running then return end
  if def.reset then place(self.reset) end
  if def.copy and #def.copy() > 0 then place(self.copyFrom) end
  for i = #(def.actions or {}), 1, -1 do
    local a = def.actions[i]
    local b = self.actionButtons[a.key]
    if not b then
      b = S.PillButton(self.content, a.text, a.width or 110, function(btn)
        local cur = P.byKey[E.tab or ""]
        for _, act in ipairs(cur and cur.actions or {}) do
          if act.key == btn.actionKey then return act.fn() end
        end
      end, false, a.tip)
      b.actionKey = a.key -- b.width: what S.FitPill made it
      self.actionButtons[a.key] = b
    end
    place(b)
  end
  self.copy, self.keys = self.actionButtons.copy, self.actionButtons.keys
end

-- How many settings on the page aren't at their defaults (Reset's label, since 1.61.0).
function E:ChangedCount()
  local n = 0
  for _, r in ipairs(self.rows or {}) do
    if r.changed and not r.mirror then n = n + 1 end
  end
  return n
end

function E:PaintReset()
  local b = self.reset
  if not b or self.resetArmed then return end
  local n = self.query and 0 or self:ChangedCount()
  b.text:SetText(n > 0 and ("Reset · %d changed"):format(n) or "Reset")
  -- red while it would undo something of yours
  local c = n > 0 and S.UI.bad or S.UI.text
  b.text:SetTextColor(c[1], c[2], c[3])
end

-- The footer: what the page needs you to know, or that your changes are saved, with Undo last
-- for the newest of them (since 1.61.0; it always said "Changes save as you make them.").
function E:Footer()
  if not self.hint then return end
  local def = P.byKey[self.tab or ""]
  local text = HINT
  local undo = false
  if self.query then
    text = "These work just as they do on their own pages."
  elseif FUI.unlocked then
    text = MOVE_HINT
  elseif def and def.hint then
    text = def.hint
  elseif P.logCount > 0 then
    local n = P.logCount
    text = (S.UI.Hex(S.UI.ok) .. "Saved|r  ·  %d change%s this session"):format(n, n == 1 and "" or "s")
  end
  if not self.query and not FUI.unlocked and #P.log > 0 then undo = true end
  self.hint:SetText(text)
  if self.undoBtn then
    self.undoBtn:SetShown(undo)
    local last = P.log[#P.log]
    self.undoBtn.tip = last and ("Puts back: " .. tostring(last.label or "the last change")) or nil
  end
end

function E:UndoLast()
  local it = P.UndoLast()
  if not it then
    if #P.log > 0 then self:Toast("Can't undo that in combat: it resizes frames.", nil, nil, 5) end
    return
  end
  self:Toast(("Put back: %s."):format(tostring(it.label or "the last change")), nil, nil, 5)
  self:RefreshPage()
end

-- Whether any row on show can't change right now.
function E:Blocked()
  for _, r in ipairs(self.rows) do
    if r.io and r.io.blocked and r.io.blocked(r.def) then return true end
  end
  return false
end

-- A line under the page's title: a short-lived note with an undo, what combat holds back, or a
-- reload that's needed. Only one at a time, in that order.
function E:Toast(text, button, fn, seconds)
  local t = { text = text, button = button, fn = fn, untilT = Now() + (seconds or 12) }
  self.toast = t
  self:Banner()
  if C_Timer then
    C_Timer.After((seconds or 12) + 0.1, function()
      if E.toast == t then
        E.toast = nil
        E:Banner()
      end
    end)
  end
end

function E:Banner()
  local b = self.banner
  if not b then return end
  local text, button, fn, kind
  local t = self.toast
  if t and Now() <= t.untilT then
    text, button, fn, kind = t.text, t.button, t.fn, "note"
  elseif InCombatLockdown() and self:Blocked() then
    text, kind = "In combat: settings that resize frames wait until the fight ends.", "combat"
  elseif FUI:ReloadPending() then
    text, button, fn, kind = "Some changes need a reload to take effect.", "Reload now", function() FUI:Reload() end, "reload"
  end
  local shown = text ~= nil
  b:SetShown(shown)
  b.kind = kind
  if shown then
    b.text:SetText(text)
    b.button:SetShown(button ~= nil)
    if button then
      b.button.text:SetText(button)
      b.fn = fn
    end
    local c = (kind == "combat" and S.UI.warn) or (kind == "reload" and S.UI.info) or A
    S.Paint(b.fill, c[1], c[2], c[3], 0.14)
    b.line:SetColorTexture(c[1], c[2], c[3], 0)
  end
  local tabs = self.tabGroup and TABS_H or 0
  local left = self.sideW + 1 + GAP
  -- Down the page: title, tabs, the preview strip, this line, then the cards.
  -- A docked preview sits in the last column instead, from under the tabs to the footer.
  local pv = self.previewBox
  local docked = pv and pv:IsShown() and self.docked
  local preview = pv and pv:IsShown() and not docked and (self.previewH or 0) + 6 or 0
  local right = docked and (1 + GAP + COL_W + GAP) or (1 + GAP)
  if pv then
    pv:ClearAllPoints()
    if docked then
      pv:SetPoint("TOPRIGHT", self.panel, "TOPRIGHT", -1 - GAP, -(HEAD + PAGE_HEAD + tabs + 2))
      pv:SetPoint("BOTTOMRIGHT", self.panel, "BOTTOMRIGHT", -1 - GAP, FOOT + GAP)
      pv:SetWidth(COL_W)
    else
      pv:SetPoint("TOPLEFT", self.panel, "TOPLEFT", left, -(HEAD + PAGE_HEAD + tabs + 2))
      pv:SetPoint("TOPRIGHT", self.panel, "TOPRIGHT", -1 - GAP, -(HEAD + PAGE_HEAD + tabs + 2))
      pv:SetHeight(PREVIEW_H)
    end
  end
  b:ClearAllPoints()
  b:SetPoint("TOPLEFT", self.panel, "TOPLEFT", left, -(HEAD + PAGE_HEAD + tabs + preview))
  b:SetPoint("TOPRIGHT", self.panel, "TOPRIGHT", -right, -(HEAD + PAGE_HEAD + tabs + preview))
  local top = HEAD + PAGE_HEAD + tabs + preview + (shown and BANNER_H or 0)
  self.scroll:ClearAllPoints()
  self.scroll:SetPoint("TOPLEFT", self.panel, "TOPLEFT", self.sideW + 1, -top)
  self.scroll:SetPoint("BOTTOMRIGHT", self.panel, "BOTTOMRIGHT", -(right - GAP), FOOT)
  self.scroll.viewH = self.height - top - FOOT
  self.scroll:ScrollTo(self.scroll.offset)
end

------------------------------------------------------------------------
-- The window's width and height (since 1.61.0)
------------------------------------------------------------------------

-- Puts the window in one of its widths. Everything that sits beside the sidebar moves with it.
function E:ApplyShape(key, keepScroll)
  if not SHAPES[key] then key = "2" end
  local sh = SHAPES[key]
  self.shape, self.cols = key, sh.cols
  self.sideW = sh.rail and RAIL_W or SIDE_W
  CONTENT_W, WIDTH = ContentW(sh.cols), ShapeWidth(key)
  E.WIDTH, E.CONTENT_W = WIDTH, CONTENT_W
  local p = self.panel
  if not p then return end
  p:SetWidth(WIDTH)
  self.content:ClearAllPoints()
  self.content:SetPoint("TOPLEFT", p, "TOPLEFT", self.sideW + 1, -(HEAD + 1))
  self.content:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -1, 1)
  self.desc:SetWidth(CONTENT_W - GAP * 2 - 4)
  self.scroll.child:SetWidth(CONTENT_W)
  self.resultFrame:SetWidth(CONTENT_W)
  self.footLine:ClearAllPoints()
  self.footLine:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", self.sideW + 1, FOOT)
  self.footLine:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -1, FOOT)
  self.hint:ClearAllPoints()
  self.hint:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", self.sideW + 1 + GAP, 14)
  self.hint:SetPoint("RIGHT", self.undoBtn, "LEFT", -10, 0)
  -- the header loses its extras when there's no room for them
  self.credit:SetShown(key ~= "1" and key ~= "2r")
  self.profileBtn:SetShown(key ~= "1")
  self:Rail(sh.rail)
  if self.query then
    local q = self.query
    self.query = nil
    self:Search(q)
  elseif self.tab then
    local offset = self.scroll.offset
    self.shownPage = nil
    self:Select(self.tab)
    if keepScroll then self.scroll:ScrollTo(offset) end
  end
end

-- The sidebar folded to icons, and opened over the page while the mouse is on it.
function E:Rail(on)
  self.railMode = on and true or nil
  self:PaintRail(false)
end

function E:PaintRail(open)
  local side = self.sideFrame
  if not side then return end
  local folded = self.railMode and not open
  self.railOpen = self.railMode and open or nil
  side:SetWidth(folded and RAIL_W or SIDE_W)
  side.cover:SetShown(self.railOpen and true or false)
  side:SetFrameLevel(self.panel:GetFrameLevel() + (self.railOpen and 30 or 2))
  self.searchBox:SetShown(not folded)
  self.railSearch:SetShown(folded and true or false)
  for _, h in ipairs(self.sideHeads or {}) do h:SetShown(not folded) end
  for _, b in ipairs(self.side) do
    b:SetWidth((folded and RAIL_W or SIDE_W) - 8)
    b.text:SetShown(not folded)
    b.note:SetShown(not folded)
    b.icon:ClearAllPoints()
    if folded then b.icon:SetPoint("CENTER", 0, 0) else b.icon:SetPoint("LEFT", 12, 0) end
  end
end

-- The nearest width to `w`.
function E:ShapeFor(w)
  local best, bd
  for _, key in ipairs(SHAPE_ORDER) do
    local d = math.abs(ShapeWidth(key) - w)
    if not bd or d < bd then best, bd = key, d end
  end
  return best
end

function E:MaxHeight()
  local h = UIParent and UIParent:GetHeight() or 0
  if not h or h <= 0 then return 900 end
  return max(420, floor(h - 40))
end

function E:SetHeight(h)
  h = max(420, min(self:MaxHeight(), floor(h + 0.5)))
  self.height = h
  self.panel:SetHeight(h)
  self.sideList.viewH = h - HEAD - SEARCH_H - 20
  self.sideList:ScrollTo(self.sideList.offset)
  self:Banner()
end

------------------------------------------------------------------------
-- Tabs: the pages that share a sidebar entry, across the top of the page
------------------------------------------------------------------------

function E:Tabs(tg)
  self.tabGroup = tg
  for _, b in ipairs(self.tabButtons) do b:Hide() end
  if self.tabLine then self.tabLine:SetShown(tg ~= nil) end
  if not tg or not self.content then return end
  local x = GAP
  for i, key in ipairs(tg.pages) do
    local b = self.tabButtons[i]
    if not b then
      b = CreateFrame("Button", nil, self.content)
      b:SetHeight(TABS_H - 4)
      S.Hover(b, { bar = false })
      b.text = S.UIText(b, nil, "CENTER", "OVERLAY", 13)
      b.text:SetPoint("CENTER", 0, 1)
      b.bar = S.Tex(b, "ARTWORK")
      b.bar:SetPoint("BOTTOMLEFT")
      b.bar:SetPoint("BOTTOMRIGHT")
      b.bar:SetHeight(2)
      b.bar:SetColorTexture(A[1], A[2], A[3], 1)
      b:SetScript("OnClick", function(btn) E:Select(btn.key) end)
      self.tabButtons[i] = b
    end
    local def = P.byKey[key]
    local label = tg.names[key] or def.title
    local width = max(64, #label * 7 + 22)
    b.key, b.width = key, width
    b.text:SetText(label)
    b:SetWidth(width)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, -(PAGE_HEAD - 1))
    local on = key == self.tab
    b.bar:SetShown(on)
    if on then
      b.text:SetTextColor(S.UI.text[1], S.UI.text[2], S.UI.text[3])
    elseif def.needs and not Running(def.needs) then
      b.text:SetTextColor(S.UI.off[1], S.UI.off[2], S.UI.off[3])
    else
      b.text:SetTextColor(S.UI.label[1], S.UI.label[2], S.UI.label[3])
    end
    b:Show()
    x = x + width + 2
  end
end

------------------------------------------------------------------------
-- The sidebar
------------------------------------------------------------------------

function E:BuildSide()
  local side = self.sideList
  local y = 2
  for _, group in ipairs(P.GROUPS) do
    local any = false
    for _, def in ipairs(P.list) do
      -- Pages that are tabs of one another share an entry: the first of them makes it.
      local tg = P.tabOf[def.key]
      if def.group == group and (not tg or tg.pages[1] == def.key) then
        if not any then
          local head = S.UIText(side.child, nil, "LEFT", "OVERLAY", 10)
          S.Mono(head, 10, nil, "medium")
          head:SetPoint("TOPLEFT", side.child, "TOPLEFT", 12, -(y + 8))
          head:SetText(group:upper())
          local hc = S.UI.Cat(group)
          head:SetTextColor(hc[1], hc[2], hc[3], 0.85)
          self.sideHeads = self.sideHeads or {}
          self.sideHeads[#self.sideHeads + 1] = head
          y = y + SIDE_ROW
          any = true
        end
        local b = CreateFrame("Button", nil, side.child)
        b:SetSize(SIDE_W - 12, SIDE_ROW)
        b:SetPoint("TOPLEFT", side.child, "TOPLEFT", 4, -y)
        b.bg = S.Tex(b, "BACKGROUND")
        b.bg:SetAllPoints()
        S.Round(b.bg, S.UI.r.button)
        S.Paint(b.bg, S.UI.raised[1], S.UI.raised[2], S.UI.raised[3], 0)
        S.Highlight(b, 0.04, S.UI.r.button)
        -- the page you're on: raised, with a solid gold edge its full height (1.81.0)
        b.bar = S.Tex(b, "ARTWORK")
        b.bar:SetPoint("TOPLEFT", 0, 0)
        b.bar:SetPoint("BOTTOMLEFT", 0, 0)
        b.bar:SetWidth(3)
        b.bar:SetColorTexture(A[1], A[2], A[3], 1)
        b.icon = S.Icon(b, def.key, 14)
        b.cat = S.UI.Cat(group) -- its icon takes its heading's colour
        b.icon:SetPoint("LEFT", 12, 0)
        b.text = S.UIText(b, nil, "LEFT", "OVERLAY", 13)
        b.text:SetPoint("LEFT", 33, 0)
        b.note = S.UIText(b, nil, "RIGHT", "OVERLAY", 11, nil, "mono")
        b.note:SetPoint("RIGHT", -6, 0)
        b.text:SetText(tg and tg.title or def.title)
        b.tab, b.tabGroup = def.key, tg
        b.y = y
        b:SetScript("OnClick", function() E:Select(tg and E.lastTab[tg.key] or def.key) end)
        b:SetScript("OnEnter", function() if E.railMode and not E.railOpen then E:PaintRail(true) end end)
        self.side[#self.side + 1] = b
        y = y + SIDE_ROW
      end
    end
    if any then y = y + 4 end
  end
  side:SetContentHeight(y + 6)
  self.tabs = self.side
end

function E:PaintSide()
  local counts = self.query and self.counts
  local cur = P.tabOf[self.tab or ""]
  for _, b in ipairs(self.side) do
    local tg = b.tabGroup
    local keys = tg and tg.pages or { b.tab }
    local on = not self.query and (b.tab == self.tab or (tg ~= nil and tg == cur))
    S.Paint(b.bg, S.UI.raised[1], S.UI.raised[2], S.UI.raised[3], on and 1 or 0)
    b.bar:SetShown(on)
    -- "off" when every page behind the entry belongs to a part that's off
    local off = true
    for _, key in ipairs(keys) do
      local d = P.byKey[key]
      if not (d.needs and not Running(d.needs)) then off = false end
    end
    if on then
      b.text:SetTextColor(S.UI.text[1], S.UI.text[2], S.UI.text[3])
      b.icon:SetColor(A[1], A[2], A[3], 1)
    elseif off then
      b.text:SetTextColor(S.UI.off[1], S.UI.off[2], S.UI.off[3])
      b.icon:SetColor(S.UI.off[1], S.UI.off[2], S.UI.off[3], 0.8)
    else
      b.text:SetTextColor(S.UI.label[1], S.UI.label[2], S.UI.label[3])
      b.icon:SetColor(b.cat[1], b.cat[2], b.cat[3], 0.85)
    end
    if counts then
      local n, hit = 0, false
      for _, key in ipairs(keys) do
        n = n + (counts[key] or 0)
        hit = hit or self.pageHits[key]
      end
      b.note:SetText(n > 0 and tostring(n) or "")
      b.note:SetTextColor(A[1], A[2], A[3])
      b:SetAlpha((n > 0 or hit) and 1 or 0.4)
    else
      b.note:SetText(off and "off" or "")
      b.note:SetTextColor(S.UI.off[1], S.UI.off[2], S.UI.off[3])
      b:SetAlpha(1)
    end
  end
end

------------------------------------------------------------------------
-- Search
------------------------------------------------------------------------

local SPELLING = { color = "colour", colors = "colours", gray = "grey", center = "centre", hp = "health" }

local function Norm(text)
  text = tostring(text or ""):lower():gsub("[^%w%s]", " ")
  return (text:gsub("%w+", function(w) return SPELLING[w] or w end))
end

local function Words(text)
  local out = {}
  for w in Norm(text):gmatch("%w+") do out[#out + 1] = w end
  return out
end

-- Everything that can be found: each page, and each setting on the pages that are on.
function E:Index()
  if self.index then return self.index end
  local index = { pages = {}, items = {} }
  for _, def in ipairs(P.list) do
    index.pages[#index.pages + 1] = {
      def = def, hay = Norm(table.concat({ def.title, def.desc or "", def.keywords or "", def.group or "" }, " ")),
    }
    if not def.needs or Running(def.needs) then
      for si, sec in ipairs(self:Sections(def, true)) do
        local found = {}
        for ri, row in ipairs(sec) do
          found[#found + 1] = { ri, row }
          for pi, part in ipairs(row.parts or {}) do found[#found + 1] = { ri * 1000 + pi, part } end
        end
        for _, f in ipairs(found) do
          local ri, row = f[1], f[2]
          local kind = row.kind
          if kind ~= "custom" and kind ~= "note" and (row.label or "") ~= "" then
            local bits = { sec.title, row.label, row.tip or "", row.keywords or "" }
            if type(row.text) == "string" then bits[#bits + 1] = row.text end
            if type(row.list) == "table" then
              for _, it in ipairs(row.list) do bits[#bits + 1] = it.name end
            end
            for _, it in ipairs(row.keys or {}) do bits[#bits + 1] = it.name end
            index.items[#index.items + 1] = {
              page = def.key, def = row, sec = sec, si = si, ri = ri, hay = Norm(table.concat(bits, " ")),
              -- The page's own name helps narrow a search ("target width") but doesn't make
              -- every setting on the page a result by itself.
              title = Norm(def.title),
            }
          end
        end
      end
    end
  end
  self.index = index
  return index
end

local function Matches(hay, words)
  for _, w in ipairs(words) do
    if not hay:find(w, 1, true) then return false end
  end
  return true
end

-- A setting matches when every word is in its own text or its page's name, and at least one is
-- in its own text.
local function MatchesItem(it, words)
  local own = false
  for _, w in ipairs(words) do
    if it.hay:find(w, 1, true) then
      own = true
    elseif not (it.title and it.title:find(w, 1, true)) then
      return false
    end
  end
  return own
end

-- Where a setting lives, for its search result: Unit frames › Target › Size.
function E:Path(pageKey, cardTitle)
  local def = P.byKey[pageKey]
  local tg = P.tabOf[pageKey]
  local bits = {}
  if tg then bits[#bits + 1] = tg.title end
  bits[#bits + 1] = tg and (tg.names[pageKey] or def.title) or def.title
  if cardTitle then bits[#bits + 1] = cardTitle end
  return table.concat(bits, "  >  ")
end

function E:ResultCard(id, title, page)
  local c = self.results[id]
  if not c then
    c = S.Card(self.resultFrame, title, COL_W)
    c.itemRows = {}
    if page then
      c:Action("Open page", function() E:Select(page); E:RevealCard(page, c.cardIndex) end, "Go to this setting's card on its page")
    end
    self.results[id] = c
  end
  return c
end

function E:Search(text)
  text = text or ""
  local words = Words(text)
  if #words == 0 then
    if self.query then
      self.query = nil
      self:Select(self.tab or "home")
    end
    return
  end
  self.query = text
  if self.copyPop then self.copyPop:Hide() end
  -- One letter matches nearly every setting, and each result is a working row to build.
  local letters = 0
  for _, w in ipairs(words) do letters = letters + #w end
  if letters < 2 then
    for _, c in pairs(self.results) do c:Hide() end
    self.counts, self.pageHits, self.firstHit = {}, {}, nil
    self.noResults:SetText("Keep typing: two letters or more.")
    self.noResults:Show()
    self.shownPage = nil
    self:ShowFrame(self.resultFrame, 60, {})
    self.scroll:ScrollTo(0)
    self.title:SetText("Search")
    self.desc:SetText("")
    self:Tabs(nil)
    self:Actions(nil)
    self:PaintSide()
    self:Footer()
    self:Banner()
    return
  end
  local index = self:Index()
  self.counts, self.pageHits = {}, {}
  local cards, order, rows = {}, {}, {}
  -- Pages whose name or description match, as links.
  local links = {}
  for _, p in ipairs(index.pages) do
    if Matches(p.hay, words) then
      links[#links + 1] = p.def
      self.pageHits[p.def.key] = true
    end
  end
  for _, it in ipairs(index.items) do
    if MatchesItem(it, words) then
      local id = it.page .. "#" .. it.si
      if not cards[id] then
        local def = P.byKey[it.page]
        cards[id] = { card = self:ResultCard(id, self:Path(it.page, it.sec.title), it.page), rows = {} }
        cards[id].card.cardIndex = it.si
        cards[id].page = it.page
        order[#order + 1] = cards[id]
      end
      local entry = cards[id]
      local r = entry.card.itemRows[it.ri]
      if not r then
        r = entry.card:Add(it.def, self:IO(it.page))
        r.page = it.page
        entry.card.itemRows[it.ri] = r
      end
      entry.rows[#entry.rows + 1] = r
      rows[#rows + 1] = r
      self.counts[it.page] = (self.counts[it.page] or 0) + 1
    end
  end
  for _, c in pairs(self.results) do c:Hide() end
  local shown = {}
  if #links > 0 then
    local lc = self:ResultCard("#pages", "Pages")
    lc.links = lc.links or {}
    local list = {}
    for _, def in ipairs(links) do
      local r = lc.links[def.key]
      if not r then
        local key = def.key
        r = lc:Add({ kind = "link", label = def.title, note = "Open", fn = function() E:Select(key) end })
        lc.links[key] = r
      end
      list[#list + 1] = r
    end
    lc:Arrange(list)
    lc:Show()
    shown[#shown + 1] = lc
  end
  for _, entry in ipairs(order) do
    entry.card:Arrange(entry.rows)
    entry.card:Show()
    shown[#shown + 1] = entry.card
  end
  local height = Lay(self.resultFrame, shown, self.cols)
  -- Up and Down move through the results, Enter opens the one picked (since 1.61.0).
  self.hits, self.hitIndex = {}, nil
  for _, entry in ipairs(order) do self.hits[#self.hits + 1] = { card = entry.card, page = entry.page, si = entry.card.cardIndex } end
  self:PaintHits()
  self.noResults:SetShown(#shown == 0)
  if #shown == 0 then
    self.noResults:SetText(("Nothing matches \"%s\". Try fewer or shorter words."):format(text))
    height = 60
  end
  -- Enter in the search box goes to the first thing found: a page by name, else a setting's page.
  self.firstHit = (links[1] and links[1].key) or (rows[1] and rows[1].page) or nil
  self.shownPage = nil
  self:ShowFrame(self.resultFrame, height, rows)
  self.scroll:ScrollTo(0)
  local n = #rows
  self.title:SetText("Search")
  self.desc:SetText((n == 1 and "1 setting matches." or (n .. " settings match.")) .. (n > 0 and "  Up and Down pick a result, Enter opens it." or ""))
  self:Tabs(nil)
  self:Actions(nil)
  self:PaintSide()
  self:Footer()
  self:Banner()
end

-- The picked result's card is edged in the accent.
function E:PaintHits()
  for i, h in ipairs(self.hits or {}) do
    local on = i == self.hitIndex
    if h.card.edges then
      S.ColorEdges(h.card.edges, on and A[1] or S.UI.line[1], on and A[2] or S.UI.line[2], on and A[3] or S.UI.line[3], 1)
    end
  end
end

function E:MoveHit(dir)
  local hits = self.hits
  if not self.query or not hits or #hits == 0 then return end
  local i = (self.hitIndex or 0) + dir
  if i < 1 then i = #hits elseif i > #hits then i = 1 end
  self.hitIndex = i
  self:PaintHits()
  local card = hits[i].card
  if card.top then self.scroll:Reveal(card.top - GAP, CardHeight(card) + GAP * 2) end
end

-- Enter: the picked result's page, at its card; with none picked, the first thing found.
function E:OpenHit()
  local h = self.hits and self.hitIndex and self.hits[self.hitIndex]
  if h then
    self:Select(h.page)
    self:RevealCard(h.page, h.si)
  elseif self.query and self.firstHit then
    self:Select(self.firstHit)
  end
end

function E:ClearSearch()
  self.hits, self.hitIndex = nil, nil
  self.query, self.firstHit = nil, nil
  self.counts, self.pageHits = nil, nil
  if self.searchBox then
    self.searchBox.quiet = true
    self.searchBox:SetText("")
    self.searchBox.quiet = nil
    self.searchBox:ClearFocus()
    self.searchHint:Show()
    self.searchClear:Hide()
  end
end

------------------------------------------------------------------------
-- Copying from another page, and resetting
------------------------------------------------------------------------

local function Copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = Copy(x) end
  return t
end

local function Same(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return a == b end
  for k, v in pairs(a) do if not Same(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

-- What a copy would change on the current page: { { def, value } } from source `src`.
function E:CopyPlan(src, what, picked)
  local page = self:Page(self.tab)
  local io = self:IO(self.tab)
  local plan = {}
  for i, card in ipairs(page.cards) do
    if what ~= "pick" or picked[i] ~= false then
      for _, r in ipairs(card.rows) do
        -- A row of colour swatches holds a setting for each swatch.
        local defs = { r.def }
        if r.def.keys and not r.def.key then
          defs = {}
          for _, k in ipairs(r.def.keys) do
            defs[#defs + 1] = { kind = r.def.kind, key = k.key, store = r.def.store, isText = r.def.isText, nocopy = r.def.nocopy }
          end
        end
        for _, d in ipairs(defs) do
          if P.Copyable(d) and (what ~= "text" or d.isText) then
            local v = src.get(d)
            if v ~= nil and not Same(io.get(d), v) then plan[#plan + 1] = { def = d, value = v } end
          end
        end
      end
    end
  end
  return plan
end

function E:DoCopy(src, what, picked)
  local key = self.tab
  local io = self:IO(key)
  if io.blocked() then
    return self:Toast("Can't copy in combat: these settings resize frames.", nil, nil, 6)
  end
  local plan = self:CopyPlan(src, what, picked)
  if #plan == 0 then
    return self:Toast(("Nothing to copy: these already match %s."):format(src.name), nil, nil, 6)
  end
  local undo = { barKey = self.barKey, extraKey = self.extraKey, items = {} }
  P.quiet = true
  for _, step in ipairs(plan) do
    undo.items[#undo.items + 1] = { def = step.def, value = Copy(io.get(step.def)) }
    io.set(step.def, Copy(step.value))
    io.changed(step.def)
  end
  P.quiet = nil
  local n = #plan
  self:Toast(("Copied %d setting%s from %s."):format(n, n == 1 and "" or "s", src.name), "Undo", function()
    if io.blocked() then return end
    E.barKey, E.extraKey = undo.barKey, undo.extraKey
    P.quiet = true
    for _, it in ipairs(undo.items) do
      io.set(it.def, Copy(it.value))
      io.changed(it.def)
    end
    P.quiet = nil
    E.toast = nil
    E:RefreshPage()
  end)
end

-- The small window Copy from opens, under its button.
function E:OpenCopy()
  local def = P.byKey[self.tab or ""]
  local sources = def and def.copy and def.copy() or {}
  if #sources == 0 then return end
  local state = { src = 1, what = "all", picked = {}, sources = sources }
  self.copyState = state
  local pop = self.copyPop
  if not pop then
    pop = CreateFrame("Frame", "VoltUICopy", self.panel)
    -- a layer above the settings window: in its own layer the page's cards, drawn at higher
    -- levels than a child of the window gets, covered it (seen in game, 1.74.0)
    pop:SetFrameStrata("FULLSCREEN_DIALOG")
    pop:SetToplevel(true)
    pop:EnableMouse(true)
    pop:SetWidth(COL_W + 20)
    S.ThemePanel(pop, 0.98)
    S.TitleBar(pop, "Copy settings", 26)
    local x = S.UIButton(pop, "x", 22, function() pop:Hide() end, "Close")
    x:SetPoint("TOPRIGHT", -2, -2)
    pop.views = {}
    self.copyPop = pop
    table.insert(UISpecialFrames, "VoltUICopy")
  end
  for _, v in pairs(pop.views) do v:Hide() end
  local viewKey = self.tab .. ":" .. tostring(self:Page(self.tab).shape) -- the cards differ by shape
  local view = pop.views[viewKey]
  local page = self:Page(self.tab)
  -- The rows are kept for the next time, so they read whatever this time's choices are.
  local io = {
    get = function(d)
      local st = E.copyState
      if d.key == "src" then return st.src end
      if d.key == "what" then return st.what end
      return st.picked[d.key] ~= false
    end,
    set = function(d, v)
      local st = E.copyState
      if d.key == "src" then st.src = v elseif d.key == "what" then st.what = v else st.picked[d.key] = v end
    end,
    changed = function() for _, r in ipairs(pop.rows) do r:Refresh() end end,
  }
  if not view then
    view = S.Card(pop, "From another page", COL_W)
    view:SetPoint("TOPLEFT", pop, "TOPLEFT", 10, -34)
    view.rows = {}
    local function add(d) view.rows[#view.rows + 1] = view:Add(d, io) end
    add({ kind = "cycle", stepper = true, label = "Copy from", key = "src", list = function()
      local list = {}
      for i, s in ipairs(E.copyState.sources) do list[i] = { key = i, name = s.name } end
      return list
    end })
    add({ kind = "cycle", label = "What", key = "what", segWidth = 200, list = {
      { key = "all", name = "Everything" }, { key = "text", name = "Text only" }, { key = "pick", name = "Choose" },
    }, tip = "Everything: every setting both pages have. Text only: what text shows and its sizes. Choose: pick cards." })
    for i, card in ipairs(page.cards) do
      local any = false
      for _, r in ipairs(card.rows) do if P.Copyable(r.def) then any = true end end
      if any then
        add({ kind = "toggle", label = card.sec.title, key = i, when = function() return E.copyState.what == "pick" end })
      end
    end
    add({ kind = "note", lines = 1, text = function()
      local st = E.copyState
      local n = #E:CopyPlan(st.sources[st.src], st.what, st.picked)
      if n == 0 then return "Nothing would change." end
      return n == 1 and "1 setting will change." or (n .. " settings will change.")
    end })
    add({ kind = "button", label = "", text = "Copy", primary = true, fn = function()
      local st = E.copyState
      pop:Hide()
      E:DoCopy(st.sources[st.src], st.what, st.picked)
    end })
    pop.views[viewKey] = view
  end
  state.sources = sources
  pop.rows = view.rows
  view:Show()
  for _, r in ipairs(view.rows) do r:Refresh() end
  pop:SetHeight(34 + CardHeight(view) + 10)
  pop:ClearAllPoints()
  pop:SetPoint("TOPRIGHT", self.copyFrom, "BOTTOMRIGHT", 0, -4)
  pop:Show()
  if pop.Raise then pop:Raise() end
end

-- Reset asks once more before it does anything.
function E:Reset()
  local def = P.byKey[self.tab or ""]
  if not def or not def.reset then return end
  local io = self:IO(self.tab)
  if io.blocked() then
    return self:Toast("Can't reset in combat: these settings resize frames.", nil, nil, 6)
  end
  if not self.resetArmed then
    local token = {}
    self.resetArmed = token
    self.reset.text:SetText("Click to confirm")
    self.reset.text:SetTextColor(S.UI.bad[1], S.UI.bad[2], S.UI.bad[3])
    if C_Timer then
      C_Timer.After(4, function()
        if E.resetArmed == token then -- not a newer one, armed on another page since
          E.resetArmed = nil
          E:PaintReset()
        end
      end)
    end
    return
  end
  self.resetArmed = nil
  self:PaintReset()
  -- What every setting on the page is now, and where its frame sits, for Undo.
  local key = self.tab
  local undo = { barKey = self.barKey, extraKey = self.extraKey, items = {} }
  for _, card in ipairs(self:Page(key).cards) do
    for _, r in ipairs(card.rows) do
      local defs = { r.def }
      if r.def.keys and not r.def.key then
        defs = {}
        for _, k in ipairs(r.def.keys) do defs[#defs + 1] = { kind = r.def.kind, key = k.key, store = r.def.store } end
      end
      for _, d in ipairs(defs) do
        if P.Copyable(d) then undo.items[#undo.items + 1] = { def = d, value = Copy(io.get(d)) } end
      end
    end
  end
  local mover = def.mover and def.mover() or nil
  if mover and mover.opts and mover.opts.spot then
    local t, xk, yk, pk = mover.opts.spot()
    undo.spot = { t = t, xk = xk, yk = yk, pk = pk, x = t[xk], y = t[yk], p = t[pk], frame = mover.frame }
  end
  P.quiet = true
  local ok, err = pcall(def.reset)
  P.quiet = nil
  if not ok then error(err, 0) end
  self:RefreshPage()
  self:Mark()
  self:Toast(def.title .. ": back to the defaults.", "Undo", function()
    if io.blocked() then return end
    E.barKey, E.extraKey = undo.barKey, undo.extraKey
    P.quiet = true
    for _, it in ipairs(undo.items) do
      io.set(it.def, Copy(it.value))
    end
    P.quiet = nil
    local sp = undo.spot
    if sp and sp.p ~= nil then
      sp.t[sp.xk], sp.t[sp.yk], sp.t[sp.pk] = sp.x, sp.y, sp.p
      S.PlaceSpot(sp.frame, sp.t, sp.xk, sp.yk, sp.pk)
    end
    for _, it in ipairs(undo.items) do io.changed(it.def) end
    E.toast = nil
    E:RefreshPage()
  end)
end

-- After "Open page" on a search result: the page scrolled to the card the setting is on.
function E:RevealCard(key, index)
  local page = self.pages[key]
  local card = page and index and page.cards[index]
  if not card or not card.top then return end
  self.scroll:Reveal(card.top - GAP, CardHeight(card) + GAP * 2)
end

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------

function E:WindowHeight()
  local saved = ns.db and tonumber(ns.db.editH)
  if saved then return max(420, min(self:MaxHeight(), floor(saved))) end
  local h = UIParent and UIParent:GetHeight() or 0
  if not h or h <= 0 then return 660 end
  return max(420, min(660, floor(h - 80)))
end

-- On Home the line under the title says how things stand (since 1.61.0): the profile in use,
-- VoltUI's version, this session's errors and anything waiting on a reload. Each is a link.
function E:BuildStatus(content)
  local bar = CreateFrame("Frame", nil, content)
  bar:SetPoint("TOPLEFT", content, "TOPLEFT", GAP, -34)
  bar:SetHeight(20)
  bar:SetWidth(400)
  bar.items = {}
  local function item(key, fn)
    local b = CreateFrame("Button", nil, bar)
    b:SetHeight(20)
    b.text = S.UIText(b, nil, "LEFT", "OVERLAY", 12)
    b.text:SetPoint("LEFT", 0, 0)
    b.line = S.Tex(b, "ARTWORK")
    b.line:SetPoint("BOTTOMLEFT", 0, 2)
    b.line:SetPoint("BOTTOMRIGHT", 0, 2)
    b.line:SetHeight(1)
    b.line:Hide()
    if fn then
      b:SetScript("OnClick", fn)
      b:SetScript("OnEnter", function(self) self.line:Show() end)
      b:SetScript("OnLeave", function(self) self.line:Hide() end)
    else
      b:EnableMouse(false)
    end
    b.key = key
    bar.items[#bar.items + 1] = b
    return b
  end
  item("profile", function() E:Select("profiles") end)
  item("version")
  item("errors", function() E:Select("errors") end)
  item("reload", function() if FUI:ReloadPending() then FUI:Reload() end end)
  bar:Hide()
  self.status = bar
end

local function ErrorsThisSession()
  local Er = ns.Errors
  if not Er or not Er.list then return 0 end
  local n = 0
  for _, e in ipairs(Er.list) do
    if e.session == nil or e.session == Er.session then n = n + (e.count or 1) end
  end
  return n
end

function E:PaintStatus()
  local bar = self.status
  if not bar then return end
  local on = self.tab == "home" and not self.query
  bar:SetShown(on)
  self.desc:SetShown(not on)
  if not on then return end
  local Pr = ns.Profiles
  local wanted = Pr and Pr.Wanted and Pr.Wanted(ns.db, Pr.Char()) or ns.db.activeProfile or "Default"
  local version = ns.Errors and ns.Errors.Version and ns.Errors.Version() or "?"
  local errs = ErrorsThisSession()
  local texts = {
    profile = { "Profile |cffffffff" .. tostring(wanted) .. "|r", S.UI.sub },
    version = { "VoltUI |cffffffff" .. tostring(version) .. "|r", S.UI.sub },
    errors = errs > 0 and { ("%d error%s this session"):format(errs, errs == 1 and "" or "s"), S.UI.bad }
      or { "No errors", S.UI.ok },
    reload = FUI:ReloadPending() and { "Reload to apply changes", S.UI.info } or { "Nothing waiting on a reload", S.UI.off },
  }
  local x = 0
  for _, b in ipairs(bar.items) do
    local t = texts[b.key]
    b.text:SetText(t[1])
    b.text:SetTextColor(t[2][1], t[2][2], t[2][3])
    b.line:SetColorTexture(t[2][1], t[2][2], t[2][3], 0.8)
    local plain = t[1]:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local w = floor(#plain * 6.4 + 4)
    b:SetWidth(w)
    b:ClearAllPoints()
    b:SetPoint("LEFT", bar, "LEFT", x, 0)
    x = x + w + 18
  end
  bar:SetWidth(x)
end

-- The profile in use, as a menu at the top of the window (since 1.61.0).
function E:PaintProfile()
  local b = self.profileBtn
  if not b then return end
  local Pr = ns.Profiles
  local wanted = Pr and Pr.Wanted and Pr.Wanted(ns.db, Pr.Char()) or "Default"
  local pending = Pr and wanted ~= ns.db.activeProfile
  b.text:SetText(("Profile: %s%s  v"):format(tostring(wanted), pending and " (reload)" or ""))
  S.FitPill(b, 110)
end

function E:ProfileMenu(owner)
  local Pr = ns.Profiles
  if not (Pr and MenuUtil and MenuUtil.CreateContextMenu) then return self:Select("profiles") end
  local wanted = Pr.Wanted(ns.db, Pr.Char())
  MenuUtil.CreateContextMenu(owner, function(_, root)
    root:CreateTitle("Profile for this character")
    for _, name in ipairs(Pr:List()) do
      local label = name == wanted and (name .. "  (in use)") or name
      root:CreateButton(label, function()
        if name == wanted then return end
        Pr:Use(name)
        if Pr.Wanted(ns.db, Pr.Char()) ~= ns.db.activeProfile then FUI:NeedReload() end
        E:Toast(("This character will use %s after a reload."):format(name), "Reload now", function() FUI:Reload() end, 12)
        E:RefreshPage()
      end)
    end
    root:CreateButton("New or manage profiles...", function() E:Select("profiles") end)
  end)
end

-- The map levels' credit, when another add-on gives them (ns.Extra.zoneLevels).
function E:DrawCredit()
  local zones = ns.Extra.zoneLevels
  self.credit:SetText(type(zones) == "table" and zones.credit and ("Map levels: " .. zones.credit) or "")
end

function E:PaintMove()
  local b = self.moveBtn
  if not b then return end
  local on = FUI.unlocked and true or false
  S.PillOn(b, on)
  b.text:SetText(on and "Moving frames" or "Move frames")
  S.Wake(b.text)
end

function E:BuildSearch(side)
  local box = CreateFrame("EditBox", nil, side)
  box:SetPoint("TOPLEFT", side, "TOPLEFT", 8, -8)
  box:SetPoint("TOPRIGHT", side, "TOPRIGHT", -8, -8)
  box:SetHeight(SEARCH_H)
  box:SetAutoFocus(false)
  box:SetMaxLetters(40)
  box:SetTextInsets(8, 22, 0, 0)
  S.FixFont(box, 12)
  local bg, edges = S.RoundBox(box, S.UI.r.field, "BACKGROUND", -8, -7)
  S.Paint(bg, S.UI.card[1], S.UI.card[2], S.UI.card[3], 1)
  S.ColorEdges(edges, S.UI.soft[1], S.UI.soft[2], S.UI.soft[3], 1)
  local hint = S.UIText(box, nil, "LEFT", "ARTWORK", 12)
  hint:SetPoint("LEFT", 8, 0)
  hint:SetText("Search settings")
  hint:SetTextColor(S.UI.off[1], S.UI.off[2], S.UI.off[3])
  local clear = S.UIButton(box, "x", 18, function()
    box:SetText("")
    E:Search("")
    hint:Show()
  end, "Clear the search")
  clear:SetPoint("RIGHT", -2, 0)
  clear:Hide()
  box:SetScript("OnEditFocusGained", function() S.ColorEdges(edges, A[1], A[2], A[3], 1) end)
  box:SetScript("OnEditFocusLost", function() S.ColorEdges(edges, S.UI.soft[1], S.UI.soft[2], S.UI.soft[3], 1) end)
  box:SetScript("OnTextChanged", function(self)
    local text = self:GetText() or ""
    hint:SetShown(text == "")
    clear:SetShown(text ~= "")
    if not self.quiet then E:Search(text) end
  end)
  box:SetScript("OnEscapePressed", function(self)
    if (self:GetText() or "") ~= "" then
      self:SetText("")
    else
      self:ClearFocus()
    end
  end)
  box:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    E:OpenHit()
  end)
  box:SetScript("OnArrowPressed", function(_, key)
    if key == "DOWN" then E:MoveHit(1) elseif key == "UP" then E:MoveHit(-1) end
  end)
  self.searchBox, self.searchHint, self.searchClear = box, hint, clear
end

function E:Build()
  if self.panel then return end
  local H = self:WindowHeight()
  self.height = H
  local p = CreateFrame("Frame", "VoltUISettings", UIParent)
  p:SetFrameStrata("DIALOG")
  p:SetToplevel(true)
  p:SetClampedToScreen(true)
  p:SetMovable(true)
  p:EnableMouse(true)
  p:SetSize(WIDTH, H)
  p:Hide()
  S.ThemePanel(p, max(ns.db.alpha, 0.95), S.UI.r.window) -- stays readable over the world, whatever the opacity
  S.TitleBar(p, "Settings", HEAD)
  self.panel = p

  local header = CreateFrame("Frame", nil, p)
  header:SetPoint("TOPLEFT", 1, -1)
  header:SetPoint("TOPRIGHT", -1, -1)
  header:SetHeight(HEAD - 1)
  header:EnableMouse(true)
  header:RegisterForDrag("LeftButton")
  header:SetScript("OnDragStart", function() p:StartMoving() end)
  header:SetScript("OnDragStop", function()
    p:StopMovingOrSizing()
    S.KeepSpot(p, ns.db, "editLeft", "editTop", "editPoint")
  end)
  local x = S.UIButton(header, "x", 22, function() E:Close() end, "Close the settings")
  x:SetPoint("RIGHT", -4, 0)
  self.closeBtn = x
  self.moveBtn = S.PillButton(header, "Move frames", 112, function()
    if InCombatLockdown() and not FUI.unlocked then
      return E:Toast("Frames can't move in combat.", nil, nil, 5)
    end
    FUI:SetUnlocked(not FUI.unlocked)
  end, false, "Drag VoltUI's frames around the screen, with a grid and pixel nudges")
  self.moveBtn:SetHeight(20)
  S.FitPill(self.moveBtn, 112, "Moving frames") -- room for either label
  self.moveBtn:SetPoint("RIGHT", x, "LEFT", -8, 0)
  self.profileBtn = S.PillButton(header, "Profile", 120, function(btn) E:ProfileMenu(btn) end, false,
    "The settings this character uses. Choosing another takes a reload.")
  self.profileBtn:SetHeight(20)
  S.FixFont(self.profileBtn.text, 11)
  self.profileBtn:SetPoint("RIGHT", self.moveBtn, "LEFT", -6, 0)
  self.credit = S.UIText(header, nil, "RIGHT", nil, 11)
  self.credit:SetPoint("RIGHT", self.profileBtn, "LEFT", -10, 0)
  self.credit:SetTextColor(S.UI.hint[1], S.UI.hint[2], S.UI.hint[3])
  self:DrawCredit()

  -- The sidebar: search, then the pages.
  local side = CreateFrame("Frame", nil, p)
  side:SetPoint("TOPLEFT", p, "TOPLEFT", 1, -(HEAD + 1))
  side:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 1, 1)
  side:SetWidth(SIDE_W)
  -- Opened over the page from the rail, it needs a solid ground and an edge.
  side.cover = S.Tex(side, "BACKGROUND", -7)
  side.cover:SetAllPoints()
  side.cover:SetColorTexture(S.UI.panel[1], S.UI.panel[2], S.UI.panel[3], 0.98)
  side.cover:Hide()
  local sbg = S.Tex(side, "BACKGROUND", -6)
  sbg:SetAllPoints()
  sbg:SetColorTexture(S.UI.side[1], S.UI.side[2], S.UI.side[3], 0)
  self.sideFrame = side
  -- The rail: a search icon where the box was. Hovering the rail opens the whole sidebar.
  local rs = CreateFrame("Button", nil, side)
  rs:SetSize(RAIL_W - 8, SEARCH_H)
  rs:SetPoint("TOPLEFT", side, "TOPLEFT", 4, -8)
  rs.icon = S.Icon(rs, "search", 14)
  rs.icon:SetPoint("CENTER")
  rs.icon:SetColor(S.UI.sub[1], S.UI.sub[2], S.UI.sub[3], 1)
  rs:SetScript("OnClick", function() E:PaintRail(true); E.searchBox:SetFocus() end)
  rs:Hide()
  self.railSearch = rs
  local function watch()
    if not E.railMode then return end
    if not E.railOpen then E:PaintRail(true) end
  end
  side:SetScript("OnEnter", watch)
  rs:HookScript("OnEnter", watch)
  side:SetScript("OnUpdate", function()
    if not E.railOpen then return end
    if MouseIsOver and MouseIsOver(side) then return end
    if E.searchBox.HasFocus and E.searchBox:HasFocus() then return end
    E:PaintRail(false)
  end)
  local split = S.Tex(p, "BORDER")
  split:SetPoint("TOPLEFT", side, "TOPRIGHT", 0, 0)
  split:SetPoint("BOTTOMLEFT", side, "BOTTOMRIGHT", 0, 0)
  split:SetWidth(1)
  split:SetColorTexture(S.UI.line[1], S.UI.line[2], S.UI.line[3], 1) -- shown since 1.81.0: the page is square now
  self:BuildSearch(side)
  local list = S.Scroll(side)
  list:SetPoint("TOPLEFT", side, "TOPLEFT", 0, -(SEARCH_H + 14))
  list:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", 0, 4)
  list.viewH = H - HEAD - SEARCH_H - 20
  list.child:SetWidth(SIDE_W)
  self.sideList = list

  -- The page: its title and buttons, a line for notes, the cards, and a footer.
  local content = CreateFrame("Frame", nil, p)
  content:SetPoint("TOPLEFT", p, "TOPLEFT", SIDE_W + 1, -(HEAD + 1))
  content:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -1, 1)
  self.content = content
  -- the page: the ladder's darkest grey, a rounded pane that follows the sidebar's width
  local pane = S.Tex(p, "BACKGROUND", -6)
  pane:SetAllPoints(content)
  S.Round(pane, S.UI.r.window - 1)
  S.Paint(pane, S.UI.bg[1], S.UI.bg[2], S.UI.bg[3], 1)
  self.pane = pane
  self:BuildStatus(content)
  self.title = S.UIText(content, nil, "LEFT", "OVERLAY", 18)
  self.title:SetPoint("TOPLEFT", GAP + 2, -12)
  self.title:SetTextColor(S.UI.text[1], S.UI.text[2], S.UI.text[3])
  self.desc = S.UIText(content, nil, "LEFT", "OVERLAY", 12)
  self.desc:SetPoint("TOPLEFT", GAP + 2, -36)
  self.desc:SetWidth(CONTENT_W - GAP * 2 - 4)
  self.desc:SetWordWrap(true)
  self.desc:SetTextColor(S.UI.hint[1], S.UI.hint[2], S.UI.hint[3])
  self.copyFrom = S.PillButton(content, "Copy from...", 104, function() E:OpenCopy() end, false,
    "Copy settings onto this page from one like it")
  self.reset = S.PillButton(content, "Reset", 112, function() E:Reset() end, false)
  S.FitPill(self.reset, 112, "Reset · 88 changed") -- as wide as its longest label
  self.reset:SetScript("OnEnter", function(b)
    GameTooltip:SetOwner(b, "ANCHOR_BOTTOM")
    GameTooltip:SetText(b.tip or "Back to the defaults", 1, 1, 1, 1, true)
    GameTooltip:AddLine("Click twice: once to ask, once to do it.", 0.75, 0.77, 0.8, true)
    GameTooltip:Show()
  end)
  self.reset:SetScript("OnLeave", function() GameTooltip:Hide() end)

  self.tabLine = S.Tex(content, "BORDER")
  self.tabLine:SetPoint("TOPLEFT", content, "TOPLEFT", GAP, -(PAGE_HEAD + TABS_H - 5))
  self.tabLine:SetPoint("TOPRIGHT", content, "TOPRIGHT", -GAP, -(PAGE_HEAD + TABS_H - 5))
  self.tabLine:SetHeight(1)
  self.tabLine:SetColorTexture(S.UI.line[1], S.UI.line[2], S.UI.line[3], 1)
  self.tabLine:Hide()

  -- The preview strip: a patch of dull green-grey, like the world behind a frame, with a copy
  -- of the frame on it. Too big a frame is cut off at its edge rather than covering the cards.
  local pv = CreateFrame("Frame", nil, p)
  pv:SetHeight(PREVIEW_H)
  if pv.SetClipsChildren then pv:SetClipsChildren(true) end
  pv.fill, pv.edges = S.RoundBox(pv, S.UI.r.card, "BACKGROUND", -6, -5)
  S.Paint(pv.fill, 0.17, 0.2, 0.2, 1)
  S.ColorEdges(pv.edges, S.UI.line[1], S.UI.line[2], S.UI.line[3], 1)
  pv.label = S.UIText(pv, nil, "RIGHT", "OVERLAY", 11)
  pv.label:SetPoint("TOPRIGHT", -8, -6)
  pv.label:SetText("Preview")
  pv.label:SetTextColor(S.UI.text[1], S.UI.text[2], S.UI.text[3])
  pv.note = S.UIText(pv, nil, "RIGHT", "OVERLAY", 11)
  pv.note:SetPoint("TOPRIGHT", pv.label, "BOTTOMRIGHT", 0, -3)
  pv.note:SetText("Shows you. Click a part of it to change that part.")
  pv.note:SetTextColor(S.UI.sub[1], S.UI.sub[2], S.UI.sub[3])
  -- Health and power move on their own; twice a second is plenty for a preview.
  pv:SetScript("OnUpdate", function(self, elapsed)
    self.wait = (self.wait or 0) + (elapsed or 0)
    if self.wait < 0.5 then return end
    self.wait = 0
    local f = E.previews[E.tab or ""]
    if f and f.preview and f:IsShown() and ns.UnitFrames.enabled then ns.UnitFrames:Update(f, true) end
  end)
  pv:Hide()
  self.previewBox = pv

  local banner = CreateFrame("Frame", nil, p)
  banner:SetPoint("TOPLEFT", p, "TOPLEFT", SIDE_W + 1 + GAP, -(HEAD + PAGE_HEAD))
  banner:SetPoint("TOPRIGHT", p, "TOPRIGHT", -1 - GAP, -(HEAD + PAGE_HEAD))
  banner:SetHeight(BANNER_H - 6)
  banner.fill = S.Tex(banner, "BACKGROUND")
  banner.fill:SetAllPoints()
  S.Round(banner.fill, S.UI.r.button)
  banner.line = S.Tex(banner, "BORDER")
  banner.line:SetPoint("TOPLEFT")
  banner.line:SetPoint("BOTTOMLEFT")
  banner.line:SetWidth(2)
  banner.text = S.UIText(banner, nil, "LEFT", "OVERLAY", 12)
  banner.text:SetPoint("LEFT", 10, 0)
  banner.text:SetTextColor(S.UI.text[1], S.UI.text[2], S.UI.text[3])
  banner.button = S.PillButton(banner, "Undo", 96, function() if banner.fn then banner.fn() end end)
  banner.button:SetHeight(18)
  banner.button:SetPoint("RIGHT", -4, 0)
  banner:Hide()
  self.banner = banner

  self.scroll = S.Scroll(p)
  self.scroll.child:SetWidth(CONTENT_W)
  self.resultFrame = CreateFrame("Frame", nil, self.scroll.child)
  self.resultFrame:SetPoint("TOPLEFT", self.scroll.child, "TOPLEFT", 0, 0)
  self.resultFrame:SetWidth(CONTENT_W)
  self.resultFrame:Hide()
  self.noResults = S.UIText(self.resultFrame, nil, "LEFT", "OVERLAY", 13)
  self.noResults:SetPoint("TOPLEFT", GAP + 2, -GAP - 4)
  self.noResults:SetTextColor(S.UI.hint[1], S.UI.hint[2], S.UI.hint[3])

  local foot = S.Tex(p, "BORDER")
  foot:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", SIDE_W + 1, FOOT)
  foot:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -1, FOOT)
  foot:SetHeight(1)
  foot:SetColorTexture(S.UI.line[1], S.UI.line[2], S.UI.line[3], 1)
  self.footLine = foot
  local done = S.PillButton(p, "Done", 84, function() E:Close() end, true)
  done:SetPoint("BOTTOMRIGHT", -GAP - 8, 9)
  local undo = S.PillButton(p, "Undo last", 84, function() E:UndoLast() end, false)
  undo:SetPoint("RIGHT", done, "LEFT", -6, 0)
  undo:SetScript("OnEnter", function(b)
    if not b.tip then return end
    GameTooltip:SetOwner(b, "ANCHOR_TOP")
    GameTooltip:SetText(b.tip, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  undo:SetScript("OnLeave", function() GameTooltip:Hide() end)
  undo:Hide()
  local hint = S.UIText(p, nil, "LEFT", nil, 12)
  hint:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", SIDE_W + 1 + GAP, 14)
  hint:SetPoint("RIGHT", undo, "LEFT", -10, 0)
  hint:SetTextColor(S.UI.hint[1], S.UI.hint[2], S.UI.hint[3])
  self.done, self.hint, self.undoBtn = done, hint, undo

  -- The corner to drag for the window's width (snapping between its widths) and height.
  local grip = CreateFrame("Button", nil, p)
  grip:SetSize(14, 14)
  grip:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -1, 1)
  grip:SetFrameLevel(p:GetFrameLevel() + 40)
  grip.dots = {}
  for _, at in ipairs({ { 0, 0 }, { 3, 0 }, { 6, 0 }, { 0, 3 }, { 3, 3 }, { 0, 6 } }) do
    local d = S.Tex(grip, "OVERLAY")
    d:SetSize(2, 2)
    d:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", -2 - at[1], 2 + at[2])
    grip.dots[#grip.dots + 1] = d
  end
  local function paintGrip(on)
    for _, d in ipairs(grip.dots) do
      if on then d:SetColorTexture(A[1], A[2], A[3], 1) else d:SetColorTexture(S.UI.edge[1], S.UI.edge[2], S.UI.edge[3], 1) end
    end
  end
  paintGrip(false)
  local function drag()
    local d = E.sizing
    if not d then return end
    local cx, cy = GetCursorPosition()
    local scale = p:GetEffectiveScale()
    local want = E:ShapeFor(d.w + (cx - d.x) / scale)
    if want ~= E.shape then E:ApplyShape(want, true) end
    E:SetHeight(d.h - (cy - d.y) / scale)
  end
  local function stop()
    if not E.sizing then return end
    E.sizing = nil
    grip:SetScript("OnUpdate", nil)
    paintGrip(grip.over)
    ns.db.editShape, ns.db.editH = E.shape, E.height
  end
  grip:SetScript("OnMouseDown", function()
    local cx, cy = GetCursorPosition()
    S.KeepSpot(p, ns.db, "editLeft", "editTop", "editPoint") -- the top-left stays put
    E.sizing = { x = cx, y = cy, w = WIDTH, h = E.height }
    paintGrip(true)
    grip:SetScript("OnUpdate", drag)
  end)
  grip:SetScript("OnMouseUp", stop)
  grip:SetScript("OnHide", stop)
  grip:SetScript("OnEnter", function(self)
    self.over = true
    paintGrip(true)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Drag to resize", 1, 1, 1)
    GameTooltip:AddLine("Wider for three columns, narrower for one; the sidebar folds to icons when there's no room for it.", 0.75, 0.77, 0.8, true)
    GameTooltip:Show()
  end)
  grip:SetScript("OnLeave", function(self)
    self.over = nil
    if not E.sizing then paintGrip(false) end
    GameTooltip:Hide()
  end)
  self.grip = grip

  self:BuildSide()
  -- A right-click puts one setting back; the toast says so.
  S.OnRowReset = function(r)
    if E:IsOpen() then E:Toast(("%s: back to its default."):format(tostring(r.def.label or "That")), "Undo", function() E:UndoLast() end, 6) end
  end
  self:ApplyShape(ns.db.editShape or "2")

  -- Search draws the action bar pages' rows without those pages having been opened, so a bar is
  -- picked for each from the start. Without one, a first search threw an error on every key.
  if ns.ActionBars and ns.ActionBars.enabled then
    self.barKey = self.barKey or "bar1"
    local ok, list = pcall(ns.ActionBars.List, ns.ActionBars, true)
    local first = ok and type(list) == "table" and list[1]
    self.extraKey = self.extraKey or (first and first.key) or nil
  end

  p:SetScript("OnHide", function()
    if FUI.unlocked and not E.stashing then
      -- Closed by hand (Done, x, Esc) while moving frames: that ends it, and the window isn't
      -- brought straight back by "it was open before".
      E.openBeforeMove = nil
      FUI:SetUnlocked(false)
    end
    local R = ns.Raid
    if R and R.simFromEdit then R:Simulate(false) end
    if E.copyPop then E.copyPop:Hide() end
  end)
  table.insert(UISpecialFrames, "VoltUISettings") -- Esc closes it

  -- Clicking a frame's overlay opens its page.
  local function pick(f, key)
    if f and f.mover then
      f.mover:SetScript("OnMouseUp", function()
        if S.MoverDragged(f.mover) then return end -- that was the end of a drag, not a click
        E:Open(key)
        if ns.Move then ns.Move:Pick(f.mover) end -- this one, not whichever frame the page calls its own
      end)
    end
  end
  for key, f in pairs(ns.UnitFrames.frames) do pick(f, key) end
  pick(ns.Castbar.player, "cast")
  pick(ns.Minimap.holder, "maps")
  pick(ns.Raid.holder, "raid")
  if ns.Dispel and ns.Dispel.enabled then
    pick(ns.Dispel.holder, "dispel")
    pick(ns.Dispel.warn, "dispel")
  end

  -- In combat the window stays, and says what's waiting.
  local ev = CreateFrame("Frame", nil, p)
  ev:RegisterEvent("PLAYER_REGEN_DISABLED")
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")
  ev:SetScript("OnEvent", function()
    if p:IsShown() then
      E:PaintMove()
      E:RefreshPage()
    end
  end)
end

function E:Open(key)
  key = key and (ALIASES[key] or key)
  if key and not P.byKey[key] then key = nil end
  self:Build()
  local p = self.panel
  if not p:IsShown() then
    if not S.PlaceSpot(p, ns.db, "editLeft", "editTop", "editPoint") then
      p:ClearAllPoints()
      p:SetPoint("TOP", UIParent, "TOP", 0, -50)
    end
    S.ThemePanel(p, max(ns.db.alpha, 0.95))
    p:Show()
  end
  self:PaintMove()
  if self.closeBtn then S.Wake(self.closeBtn.text) end
  if key or not self.query then
    local last = ns.db.editPage
    last = last and (ALIASES[last] or last)
    if not (last and P.byKey[last]) then last = nil end
    self:Select(key or self.tab or last or "home")
  end
end

function E:Close()
  if self.panel then self.panel:Hide() end
end

-- Out of the way while frames are being moved, without ending that (the move toolbar's
-- Settings button). Closing the window any other way still ends it.
function E:Stash(on)
  if not self.panel then return end
  if on then
    self.stashing = true
    self.panel:Hide()
    self.stashing = nil
  else
    self:Open()
  end
  if ns.Move then ns.Move:PaintTools() end
end

function E:IsOpen() return self.panel ~= nil and self.panel:IsShown() end

function E:SetShown(on)
  if on then self:Open() else self:Close() end
end

-- Moving frames started or stopped (FUI:SetUnlocked).
function E:MoveMode(on)
  if ns.Move then ns.Move:SetActive(on) end
  -- The window covers the middle of the screen, where most frames sit, so it steps aside while
  -- frames are being moved (since 1.53.0) and comes back when that ends, if it was open.
  -- Clicking a frame's overlay brings it back on that frame's page.
  if on then
    self:Build()
    self.openBeforeMove = self:IsOpen()
    if self.openBeforeMove then self:Stash(true) end
  elseif self.openBeforeMove then
    self.openBeforeMove = nil
    if not self:IsOpen() then self:Open() end
  end
  self:PaintMove()
  if self:IsOpen() then
    self:Footer()
    self:Mark()
    self:RefreshPage() -- the Home page's Move frames button says which way it goes
  end
end

-- While a page is being scrolled with the wheel, sliders passing under the mouse don't take it.
S.PageWheel = function(delta)
  local sf = E.scroll
  if not (sf and E:IsOpen() and sf:MaxScroll() > 0) then return false end
  if (IsShiftKeyDown and IsShiftKeyDown()) or (IsControlKeyDown and IsControlKeyDown()) then return false end
  sf.lastWheel = Now()
  sf:ScrollBy(delta)
  return true
end
