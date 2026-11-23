-- VoltUI · Chat
-- The game's chat windows in VoltUI's look (since 1.49.0): a flat panel behind each window and
-- behind the box you type in, plain text tabs in VoltUI's font, and the game's own chat art faded
-- out. Since 1.54.0 the scroll bar is a slim flat one, the buttons beside the window (friends,
-- channels, the chat menu) are flat squares, and the main window can be dragged and resized
-- while moving frames.
--
-- Everything else is the game's: channels, filters, and the font and size of the chat text
-- itself, which you set by right-clicking a tab.
--
-- Nothing of the game's is replaced; its art is only made see-through, and kept that way when
-- the game fades it back in. Each window is done on its own, guarded, so a part this client
-- doesn't have is skipped. The main window's spot and size are the game's (its own Edit Mode)
-- until you move or resize it here; after that VoltUI puts it back whenever the game moves it.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style

local C = { key = "chat", name = "Chat", skinned = {}, backs = {} }
ns.Chat = C

local max, min, floor, rad = math.max, math.min, math.floor, math.rad
local A = S.UI.accent -- (1.86.0) VoltUI's own windows' look: square greys, gold marks
local UI = S.UI

-- See-through, and kept that way: the game shows a window's art again when you mouse over it.
local function KeepFaded(obj)
  if type(obj) ~= "table" or not obj.SetAlpha or obj.voltFaded then return end
  obj.voltFaded = true
  obj:SetAlpha(0)
  hooksecurefunc(obj, "SetAlpha", function(self, a)
    if a and a > 0 and C.enabled then self:SetAlpha(0) end
  end)
end

-- Every texture a frame draws itself (its children's are theirs). `keep` is left alone.
local function FadeRegions(f, keep)
  if type(f) ~= "table" or type(f.GetRegions) ~= "function" then return end
  local ok, regions = pcall(function() return { f:GetRegions() } end)
  if not ok then return end
  for _, r in ipairs(regions) do
    if type(r) == "table" and r ~= keep and type(r.GetObjectType) == "function" and r:GetObjectType() == "Texture" then
      KeepFaded(r)
    end
  end
end

local function Alpha() return max(0.2, min(0.9, tonumber(ns.db.chatAlpha) or 0.55)) end

local function Back(owner, l, t, r, b)
  local back = CreateFrame("Frame", nil, owner)
  back:SetPoint("TOPLEFT", owner, "TOPLEFT", l, t)
  back:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", r, b)
  back:SetFrameLevel(max(0, (owner:GetFrameLevel() or 1) - 1))
  S.ThemePanel(back, Alpha())
  C.backs[#C.backs + 1] = back
  return back
end

-- The game's names for a chat window's art, on clients that don't list them.
local ART = { "Background", "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture", "LeftTexture",
  "RightTexture", "BottomTexture", "TopTexture", "ButtonFrameBackground", "ButtonFrameTopLeftTexture",
  "ButtonFrameBottomLeftTexture", "ButtonFrameTopRightTexture", "ButtonFrameBottomRightTexture", "ButtonFrameLeftTexture",
  "ButtonFrameRightTexture", "ButtonFrameBottomTexture", "ButtonFrameTopTexture" }
local TAB_ART = { "Left", "Middle", "Right", "SelectedLeft", "SelectedMiddle", "SelectedRight", "HighlightLeft",
  "HighlightMiddle", "HighlightRight", "ActiveLeft", "ActiveMiddle", "ActiveRight" }
local EDIT_ART = { "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }

------------------------------------------------------------------------
-- The scroll bar and the buttons
------------------------------------------------------------------------

-- A thin line, turned. Two of them make an arrow head.
local function Stroke(parent, x, y, turn)
  local t = S.Tex(parent, "ARTWORK")
  t:SetSize(7, 1.5)
  t:SetPoint("CENTER", parent, "CENTER", x, y)
  t:SetColorTexture(A[1], A[2], A[3], 1)
  if t.SetRotation then pcall(t.SetRotation, t, rad(turn)) end
  return t
end

-- The game's scroll bar (its "minimal" one: two arrows, a track and a thumb) becomes a faint
-- line with a flat thumb. The arrows are see-through but still there; the wheel does the rest.
function C:SkinScroll(f)
  local sb = f.ScrollBar
  if type(sb) ~= "table" or sb.voltSkin then return end
  sb.voltSkin = true
  local track = type(sb.Track) == "table" and sb.Track or nil
  local thumb = track and type(track.Thumb) == "table" and track.Thumb or nil
  for _, part in ipairs({ sb, sb.Back, sb.Forward, track, thumb }) do FadeRegions(part) end
  if track and track.CreateTexture then
    local line = S.Tex(track, "BACKGROUND")
    line:SetPoint("TOP", 0, 0)
    line:SetPoint("BOTTOM", 0, 0)
    line:SetWidth(1)
    line:SetColorTexture(1, 1, 1, 0.1)
    sb.voltLine = line
  end
  if thumb and thumb.CreateTexture then
    local bar = S.Tex(thumb, "ARTWORK")
    bar:SetPoint("TOP", 0, -1)
    bar:SetPoint("BOTTOM", 0, 1)
    bar:SetWidth(4)
    bar:SetColorTexture(UI.edge[1], UI.edge[2], UI.edge[3], 1)
    sb.voltThumb = bar
    if thumb.HookScript then
      thumb:HookScript("OnEnter", function() bar:SetColorTexture(A[1], A[2], A[3], 1) end)
      thumb:HookScript("OnLeave", function() bar:SetColorTexture(UI.edge[1], UI.edge[2], UI.edge[3], 1) end)
    end
  end
  -- "Back to the newest line": the game's arrow, as a flat one. Its flash, when new lines come
  -- in while you're scrolled up, is kept.
  local down = f.ScrollToBottomButton
  if type(down) == "table" and down.CreateTexture and not down.voltSkin then
    down.voltSkin = true
    FadeRegions(down, type(down.Flash) == "table" and down.Flash or nil)
    Stroke(down, -2.3, 0, -45)
    Stroke(down, 2.3, 0, 45)
  end
end

-- What each of the buttons beside the chat shows in place of its round icon.
local SIDE = {
  { "ChatFrameMenuButton", "menu", "Chat menu" },
  { "ChatFrameChannelButton", "#", "Channels" },
  { "QuickJoinToastButton", "count", "Friends" },
  { "TextToSpeechButton", "tts", "Text to speech" },
}
C.SIDE = SIDE

local function EdgeColour(skin, hover)
  local p = skin.fuiPanel
  if not p then return end
  if hover then
    S.ColorEdges(p.edges, A[1], A[2], A[3], 1)
  else
    S.ThemePanel(skin, Alpha())
  end
end

-- One of the game's chat buttons as a flat square: its art see-through, a VoltUI panel and a
-- plain mark in its place. The button itself, and what clicking it does, is untouched.
function C:SkinButton(b, glyph)
  if type(b) ~= "table" or b.voltSkin or not b.CreateTexture or not b.GetFrameLevel then return end
  FadeRegions(b)
  local skin = CreateFrame("Frame", nil, b)
  skin:SetSize(22, 22)
  skin:SetPoint("CENTER", b, "CENTER", 0, 0)
  skin:SetFrameLevel(max(0, (b:GetFrameLevel() or 1) - 1)) -- under the button's own text
  S.ThemePanel(skin, Alpha())
  self.backs[#self.backs + 1] = skin
  b.voltSkin = skin
  if glyph == "menu" then
    for i = -1, 1 do
      local t = S.Tex(skin, "ARTWORK")
      t:SetSize(10, 1.5)
      t:SetPoint("CENTER", skin, "CENTER", 0, i * 3.5)
      t:SetColorTexture(A[1], A[2], A[3], 1)
    end
  elseif glyph == "count" then
    -- The friends button already counts who's online: that number is the mark.
    local n = b.FriendCount
    if type(n) == "table" and n.SetFont then
      S.FixFont(n, 11, nil, nil, "mono")
      n:ClearAllPoints()
      n:SetPoint("CENTER", skin, "CENTER", 0, 0)
      if n.SetTextColor then n:SetTextColor(A[1], A[2], A[3]) end
    end
  else
    skin.glyph = S.UIText(skin, nil, "CENTER", "OVERLAY", glyph == "tts" and 9 or 12, nil, "mono")
    skin.glyph:SetPoint("CENTER", skin, "CENTER", 0, 0)
    skin.glyph:SetText(glyph)
    skin.glyph:SetTextColor(A[1], A[2], A[3])
  end
  if b.HookScript then
    b:HookScript("OnEnter", function() EdgeColour(skin, true) end)
    b:HookScript("OnLeave", function() EdgeColour(skin, false) end)
  end
  return skin
end

-- The friends button sits well above the chat in the game's layout, on its own. Here it
-- joins the column: straight under the channels button, and back there if the game moves it.
function C:DockFriends()
  local b, above = _G.QuickJoinToastButton, _G.ChatFrameChannelButton
  if type(b) ~= "table" or type(above) ~= "table" or not b.voltSkin or not b.SetPoint or not b.ClearAllPoints then return end
  self.docking = true
  b:ClearAllPoints()
  b:SetPoint("TOP", above, "BOTTOM", 0, 6) -- the squares are 22 in a 32 button: 4 apart
  self.docking = nil
  if not b.voltDocked then
    b.voltDocked = true
    hooksecurefunc(b, "SetPoint", function()
      if C.docking or C.dockQueued or not (C_Timer and C_Timer.After) then return end
      C.dockQueued = true
      C_Timer.After(0, function() C.dockQueued = nil; C:DockFriends() end)
    end)
  end
end

function C:SkinButtons()
  for _, def in ipairs(SIDE) do
    local ok, err = pcall(self.SkinButton, self, _G[def[1]], def[2])
    if not ok and ns.Errors and ns.Errors.Add then pcall(ns.Errors.Add, ns.Errors, "Chat: " .. tostring(err), nil, nil, "volt") end
  end
  pcall(self.DockFriends, self)
end

------------------------------------------------------------------------
-- The windows
------------------------------------------------------------------------

function C:Skin(f)
  if type(f) ~= "table" or self.skinned[f] or not f.GetName then return end
  local name = f:GetName()
  if type(name) ~= "string" then return end
  self.skinned[f] = true
  local ok, err = pcall(function()
    for _, key in ipairs(type(_G.CHAT_FRAME_TEXTURES) == "table" and _G.CHAT_FRAME_TEXTURES or ART) do KeepFaded(_G[name .. key]) end
    -- The scroll bar hangs off the window's right edge (8 wide): the panel takes it in, and
    -- ends where the box you type in does.
    f.voltBack = Back(f, -4, 4, type(f.ScrollBar) == "table" and 14 or 4, -6)
    -- the tab: plain text in VoltUI's font
    local tab = _G[name .. "Tab"]
    if type(tab) == "table" then
      for _, key in ipairs(TAB_ART) do
        local art = tab[key]
        KeepFaded(type(art) == "table" and art or _G[name .. "Tab" .. key])
      end
      local text = tab.Text or (tab.GetFontString and tab:GetFontString())
      if type(text) == "table" and text.SetFont then S.FixFont(text, 11, nil, nil, "mono") end
      -- the tab that's shown: a gold tint with a solid gold line under it (the text's colour
      -- stays the game's, which changes it as tabs are picked and fade)
      if tab.CreateTexture then
        local line = S.Tex(tab, "OVERLAY")
        line:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 8, 4)
        line:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -8, 4)
        line:SetHeight(2)
        line:SetColorTexture(A[1], A[2], A[3], 1)
        local tint = S.Tex(tab, "BACKGROUND")
        tint:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", 0, 0)
        tint:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", 0, 0)
        tint:SetHeight(18)
        tint:SetColorTexture(A[1], A[2], A[3], 0.2)
        line:Hide(); tint:Hide()
        self.tabMarks = self.tabMarks or {}
        self.tabMarks[f] = { line = line, tint = tint }
      end
      -- a tab with new messages flashes gold
      local glow = tab.glow or _G[name .. "TabGlow"]
      if type(glow) == "table" and glow.SetVertexColor then
        pcall(glow.SetVertexColor, glow, A[1], A[2], A[3])
        -- The game re-colours the glow each time the tabs update (FCFTab_UpdateColors), so
        -- it's put back to gold after that.
        self.goldGlow = self.goldGlow or {}
        self.goldGlow[tab] = glow
        if not self.glowHooked and type(FCFTab_UpdateColors) == "function" and hooksecurefunc then
          self.glowHooked = true
          hooksecurefunc("FCFTab_UpdateColors", function(t)
            local g = t and self.goldGlow[t]
            if g then pcall(g.SetVertexColor, g, A[1], A[2], A[3]) end
          end)
        end
      end
    end
    -- the box you type in
    local box = _G[name .. "EditBox"]
    if type(box) == "table" and box.GetFrameLevel then
      for _, key in ipairs(EDIT_ART) do
        local art = _G[name .. "EditBox" .. key]
        KeepFaded(type(art) == "table" and art or box[key])
      end
      box.voltBack = Back(box, 2, -3, -2, 3)
      -- while you type: outlined in gold, with a solid left edge
      local back = box.voltBack
      local bar = S.Tex(back, "ARTWORK")
      bar:SetPoint("TOPLEFT", 0, 0)
      bar:SetPoint("BOTTOMLEFT", 0, 0)
      bar:SetWidth(3)
      bar:SetColorTexture(A[1], A[2], A[3], 1)
      bar:Hide()
      back.voltBar = bar
      if box.HookScript then
        box:HookScript("OnEditFocusGained", function()
          bar:Show()
          if back.fuiPanel then S.ColorEdges(back.fuiPanel.edges, A[1], A[2], A[3], 1) end
        end)
        box:HookScript("OnEditFocusLost", function()
          bar:Hide()
          S.ThemePanel(back, Alpha())
        end)
      end
    end
    self:SkinScroll(f)
    -- a window pulled out of the dock has a button to fold it away
    local side = type(f.buttonFrame) == "table" and f.buttonFrame or nil
    if side and type(side.minimizeButton) == "table" then self:SkinButton(side.minimizeButton, "-") end
  end)
  if not ok and ns.Errors and ns.Errors.Add then pcall(ns.Errors.Add, ns.Errors, "Chat: " .. tostring(err), nil, nil, "volt") end
end

-- Which tab is shown: the dock's chosen window, and any window pulled out of the dock.
function C:MarkTabs()
  local sel
  local dock = _G.GENERAL_CHAT_DOCK
  if dock and type(_G.FCFDock_GetSelectedWindow) == "function" then
    local ok, got = pcall(_G.FCFDock_GetSelectedWindow, dock)
    if ok then sel = got end
  end
  sel = sel or _G.SELECTED_DOCK_FRAME
  for f, mark in pairs(self.tabMarks or {}) do
    local on = f == sel or not f.isDocked
    mark.line:SetShown(on); mark.tint:SetShown(on)
  end
end

function C:SkinAll()
  -- The game's own list of chat windows includes the ones it makes later (a whisper in its own
  -- tab is ChatFrame11 or higher), which counting to ten would miss.
  if type(_G.CHAT_FRAMES) == "table" then
    for _, name in ipairs(_G.CHAT_FRAMES) do self:Skin(_G[name]) end
  end
  for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do self:Skin(_G["ChatFrame" .. i]) end
  self:SkinButtons()
  if not self.tabHooked then
    self.tabHooked = true
    for _, fn in ipairs({ "FCFDock_SelectWindow", "FCF_DockFrame", "FCF_UnDockFrame" }) do
      if type(_G[fn]) == "function" then hooksecurefunc(fn, function() C:MarkTabs() end) end
    end
  end
  self:MarkTabs()
end

function C:Refresh()
  for _, back in ipairs(self.backs) do S.ThemePanel(back, Alpha()) end
end

------------------------------------------------------------------------
-- Moving and resizing the main window
------------------------------------------------------------------------
-- The other windows are docked to the main one as tabs, so they follow it.

local SPOT = { "chatLeft", "chatTop", "chatPoint" }
local MIN_W, MIN_H, MAX_W, MAX_H = 250, 120, 800, 800 -- the game's own limits for a chat window

function C:Main()
  local f = _G.ChatFrame1
  if type(f) == "table" and f.SetPoint and f.GetFrameLevel then return f end
end

-- Has it been moved or resized here? Until then the game's own spot and size are left alone.
function C:HasSpot()
  local db = ns.db
  return db.chatPoint ~= nil or (tonumber(db.chatW) and tonumber(db.chatH)) and true or false
end

function C:PlaceMain()
  local f = self:Main()
  if not f or not self:HasSpot() then return end
  local db = ns.db
  self.placing = true
  local w, h = tonumber(db.chatW), tonumber(db.chatH)
  if w and h then
    pcall(f.SetSize, f, max(MIN_W, min(MAX_W, w)), max(MIN_H, min(MAX_H, h)))
  end
  pcall(S.PlaceSpot, f, db, SPOT[1], SPOT[2], SPOT[3])
  self.placing = nil
end

-- The game's own layout (its Edit Mode) put the window somewhere: back to yours, a moment
-- later. Not while that Edit Mode is open, where the window is the game's to arrange.
local function GameEditing()
  local m = _G.EditModeManagerFrame
  return type(m) == "table" and m.IsShown and m:IsShown() and true or false
end

local function Again()
  if C.placing or C.sizing or C.queued or not C:HasSpot() or GameEditing() then return end
  if not (C_Timer and C_Timer.After) then return end
  C.queued = true
  C_Timer.After(0, function()
    C.queued = nil
    if not GameEditing() then C:PlaceMain() end
  end)
end
C.Again = Again

-- Where the game starts it, for Reset spot. The game's Edit Mode decides again from the next
-- reload; VoltUI doesn't call into that itself.
function C.GameSpot(f)
  C.placing = true
  f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 32, 95)
  C.placing = nil
end

function C:ResetSpot()
  local f, db = self:Main(), ns.db
  S.ClearSpot(db, SPOT[1], SPOT[2], SPOT[3])
  local sized = db.chatW ~= nil
  db.chatW, db.chatH = nil, nil
  if not f then return end
  self.placing = true
  if sized and self.gameW then pcall(f.SetSize, f, self.gameW, self.gameH) end
  f:ClearAllPoints()
  self.placing = nil
  C.GameSpot(f)
end

function C:SaveSize(f)
  local w, h = f:GetWidth(), f:GetHeight() -- straight after a drag, when the game has just set them
  if type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then return end
  ns.db.chatW, ns.db.chatH = floor(w + 0.5), floor(h + 0.5)
end

function C:SetupMover()
  local f = self:Main()
  if not f or self.mover then return end
  local db = ns.db
  self.gameW, self.gameH = f:GetWidth(), f:GetHeight() -- the game's size, for Reset spot
  local m = S.Mover(f, "Chat", function(fr)
    S.KeepSpot(fr, db, SPOT[1], SPOT[2], SPOT[3])
  end, { spot = function() return ns.db, SPOT[1], SPOT[2], SPOT[3] end,
         default = function(fr) C:ResetSpot() end })
  m:SetScript("OnMouseUp", function()
    if S.MoverDragged(m) then return end -- that was the end of a drag, not a click
    ns.EditMode:Open("general")
    if ns.Move then ns.Move:Pick(m) end
  end)
  self.mover = m

  -- The corner to drag for its size.
  local g = CreateFrame("Button", nil, m)
  g:SetSize(18, 18)
  g:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", 0, 0)
  g:SetFrameLevel(m:GetFrameLevel() + 2)
  local sq = S.Tex(g, "OVERLAY", 7)
  sq:SetAllPoints()
  sq:SetColorTexture(A[1], A[2], A[3], 0.9)
  g.mark = S.UIText(g, nil, "CENTER", "OVERLAY", 11, "OUTLINE")
  g.mark:SetPoint("CENTER", 0, 0)
  g.mark:SetText("<>")
  local function stop()
    if not C.sizing then return end
    f:StopMovingOrSizing()
    C.sizing = nil
    if f.SetUserPlaced then f:SetUserPlaced(false) end
    C:SaveSize(f)
    S.KeepSpot(f, ns.db, SPOT[1], SPOT[2], SPOT[3])
    C:PlaceMain()
    if ns.Move and ns.Move.Readout then pcall(ns.Move.Readout, ns.Move) end
  end
  g:SetScript("OnMouseDown", function()
    if InCombatLockdown() or not f.StartSizing then return end
    if f.SetResizable then f:SetResizable(true) end
    if f.SetResizeBounds then pcall(f.SetResizeBounds, f, MIN_W, MIN_H, MAX_W, MAX_H) end
    C.sizing = true
    f:StartSizing("BOTTOMRIGHT")
  end)
  g:SetScript("OnMouseUp", stop)
  g:SetScript("OnHide", stop)
  g:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Drag to resize the chat", 1, 1, 1)
    GameTooltip:Show()
  end)
  g:SetScript("OnLeave", function() GameTooltip:Hide() end)
  self.grip = g

  for _, method in ipairs({ "SetPoint", "SetSize", "SetWidth", "SetHeight" }) do
    if type(f[method]) == "function" then hooksecurefunc(f, method, Again) end
  end
  -- Leaving the game's Edit Mode re-applies its layout.
  if type(_G.EventRegistry) == "table" and _G.EventRegistry.RegisterCallback then
    pcall(_G.EventRegistry.RegisterCallback, _G.EventRegistry, "EditMode.Exit", function() Again() end, C)
  end
end

function C:SetUnlocked(on)
  if self.mover then self.mover:SetShown(on and true or false) end
end

------------------------------------------------------------------------
-- Web addresses and copying (1.101.23)
------------------------------------------------------------------------
-- A web address someone posts can't be selected in the game's chat. Each one becomes a link;
-- a click opens VoltUI's copy box with it (Links.lua's, or a line in chat without that part).
-- The link is the game's own kind for add-ons ("addon:"), which it hands to anyone listening
-- instead of trying to open it. Messages the game hides from add-ons are passed on untouched.

local URL_LINK = "addon:VoltUI:url:"
local URL_PATTERNS = {
  "https?://[%w%-%._~:/%?#%[%]@!%$&'%(%)%*%+,;=%%]+",
  "www%.[%w%-_]+%.[%w%-%._~:/%?#%[%]@!%$&'%(%)%*%+,;=%%]+",
}

-- A message with its web addresses turned into links; nil if it has none.
function C.LinkURLs(msg)
  if type(msg) ~= "string" or S.IsSecret(msg) then return nil end
  if not (msg:find("://", 1, true) or msg:find("www.", 1, true)) then return nil end
  if msg:find(URL_LINK, 1, true) then return nil end -- already done (another window's pass)
  local found = false
  -- Addresses already inside a link (an item or a player's name) are left alone: those parts
  -- are lifted out, the rest is searched, and they go back after.
  local kept = {}
  local body = msg:gsub("|H.-|h.-|h", function(link)
    kept[#kept + 1] = link
    return "\1" .. #kept .. "\2"
  end)
  local done = {}
  for _, pattern in ipairs(URL_PATTERNS) do
    body = body:gsub(pattern, function(url)
      local tail = url:match("[%.,;:!%?%)%]'\"]+$") or ""
      url = url:sub(1, #url - #tail)
      if #url < 5 then return nil end
      found = true
      done[#done + 1] = "|cff7fc8ff|H" .. URL_LINK .. url .. "|h[" .. url .. "]|h|r" .. tail
      return "\3" .. #done .. "\4"
    end)
  end
  if not found then return nil end
  body = body:gsub("\3(%d+)\4", function(i) return done[tonumber(i)] end)
  body = body:gsub("\1(%d+)\2", function(i) return kept[tonumber(i)] end)
  return body
end

local URL_EVENTS = {
  "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
  "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_CHANNEL", "CHAT_MSG_INSTANCE_CHAT",
  "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_SYSTEM",
}

local function URLFilter(_, _, msg, ...)
  if not (ns.db and ns.db.chatUrls) then return false end
  local ok, new = pcall(C.LinkURLs, msg)
  if not ok or not new then return false end
  return false, new, ...
end

function C:OpenURL(link)
  if type(link) ~= "string" or link:sub(1, #URL_LINK) ~= URL_LINK then return false end
  local url = link:sub(#URL_LINK + 1)
  if ns.Links and ns.Links.ShowURL and ns.Links:ShowURL(url) then return true end
  FUI:Print("%s", url)
  return true
end

function C:WatchURLs()
  if self.urlsWatched then return end
  self.urlsWatched = true
  local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or _G.ChatFrame_AddMessageEventFilter
  if type(add) == "function" then
    for _, e in ipairs(URL_EVENTS) do pcall(add, e, URLFilter) end
  end
  -- A click on one: the game announces add-on links; older clients only have SetItemRef to follow.
  if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("SetItemRef", function(_, link) C:OpenURL(link) end, C)
  elseif type(_G.SetItemRef) == "function" then
    hooksecurefunc("SetItemRef", function(link) C:OpenURL(link) end)
  end
end

-- A chat line as plain text: colours, icons and link wrappers taken off, the words kept.
function C.Plain(text)
  if type(text) ~= "string" or S.IsSecret(text) then return nil end
  text = text:gsub("|T.-|t", ""):gsub("|A.-|a", "")
  text = text:gsub("|H.-|h(.-)|h", "%1")
  text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn.-:", ""):gsub("|r", "")
  text = text:gsub("|K.-|k", "?"):gsub("||", "|")
  return text
end

-- The lines a chat window is holding, oldest first, as one block of text.
function C:Lines(f, most)
  local out = {}
  local n = f and f.GetNumMessages and f:GetNumMessages() or 0
  if type(n) ~= "number" then return "", 0 end
  for i = math.max(1, n - (most or 500) + 1), n do
    local ok, text = pcall(f.GetMessageInfo, f, i)
    local plain = ok and C.Plain(text)
    if plain and plain ~= "" then out[#out + 1] = plain end
  end
  return table.concat(out, "\n"), #out
end

function C:BuildCopy()
  if self.copy then return self.copy end
  local U = S.UI
  local f = CreateFrame("Frame", "VoltUIChatCopy", UIParent)
  f:SetSize(620, 380)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  f:Hide()
  S.ThemePanel(f, math.max(ns.db.alpha or 0.85, 0.94))
  S.BlockHead(f, "Chat", 13)
  f.close = S.PillButton(f, "x", 20, function() f:Hide() end, false, "Close")
  f.close:SetSize(20, 18)
  f.close:SetPoint("RIGHT", f, "TOPRIGHT", -3, -S.HEADER_H / 2)
  f.title = S.UIText(f, nil, "LEFT", nil, 11, nil, "mono")
  f.title:SetPoint("LEFT", f.block, "RIGHT", 9, 0)
  f.title:SetPoint("RIGHT", f.close, "LEFT", -8, 0)
  f.title:SetTextColor(U.text[1], U.text[2], U.text[3])
  f.hint = S.UIText(f, nil, "LEFT", nil, 11)
  f.hint:SetPoint("BOTTOMLEFT", 9, 7)
  f.hint:SetTextColor(U.hint[1], U.hint[2], U.hint[3])
  f.hint:SetText("Drag to select, Ctrl+C to copy. Ctrl+A selects it all.")

  local sf = CreateFrame("ScrollFrame", "VoltUIChatCopyScroll", f)
  sf:SetPoint("TOPLEFT", 9, -(S.HEADER_H + 8))
  sf:SetPoint("BOTTOMRIGHT", -9, 26)
  sf:EnableMouseWheel(true)
  local bg = S.Tex(sf, "BACKGROUND", -8)
  bg:SetAllPoints()
  bg:SetColorTexture(U.bg[1], U.bg[2], U.bg[3], 1)
  local e = CreateFrame("EditBox", "VoltUIChatCopyText", sf)
  e:SetMultiLine(true)
  e:SetAutoFocus(false)
  e:SetWidth(620 - 18 - 12)
  e:SetTextInsets(6, 6, 4, 4)
  S.FixFont(e, 11, nil, nil, "mono")
  sf:SetScrollChild(e)
  -- It's for copying: typing puts the text back.
  e:SetScript("OnTextChanged", function(self, user)
    if user and self:GetText() ~= (C.copyText or "") then self:SetText(C.copyText or "") end
  end)
  e:SetScript("OnEscapePressed", function() f:Hide() end)
  local function range() return math.max(0, (e:GetHeight() or 0) - (sf:GetHeight() or 0)) end
  sf:SetScript("OnMouseWheel", function(self, delta)
    local y = math.max(0, math.min(range(), (self:GetVerticalScroll() or 0) - delta * 44))
    self:SetVerticalScroll(y)
  end)
  f.scroll, f.edit, f.range = sf, e, range
  f:SetScript("OnHide", function() e:ClearFocus() end)
  table.insert(UISpecialFrames, "VoltUIChatCopy")
  self.copy = f
  return f
end

-- Opens the copy window on a chat window's text (the one that's showing, if none is given).
function C:Copy(f)
  f = f or _G.SELECTED_CHAT_FRAME or _G.DEFAULT_CHAT_FRAME or _G.ChatFrame1
  if type(f) ~= "table" then return false end
  local text, n = self:Lines(f, 500)
  local w = self:BuildCopy()
  local name = f.name or (f.GetName and f:GetName()) or "chat"
  w.title:SetText(n > 0 and ("%s, last %d line%s"):format(tostring(name), n, n == 1 and "" or "s") or (tostring(name) .. ": nothing to copy"))
  self.copyText = text
  w.edit:SetText(text)
  w:Show()
  w.edit:SetFocus()
  -- to the newest line, once the box has measured its text
  local bottom = function() w.scroll:SetVerticalScroll(w.range()) end
  if C_Timer and C_Timer.After then C_Timer.After(0, bottom) else bottom() end
  return true
end

-- A small button in each chat window's top-right corner, faint until the mouse is on it.
function C:CopyButton(f)
  self.copyButtons = self.copyButtons or {}
  local b = self.copyButtons[f]
  if not b then
    if type(f) ~= "table" or not f.GetName then return end
    b = CreateFrame("Button", nil, f)
    b:SetSize(16, 16)
    b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    b:SetFrameLevel((f:GetFrameLevel() or 1) + 5)
    local bg = S.Tex(b, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(S.UI.raised[1], S.UI.raised[2], S.UI.raised[3], 0.9)
    S.ColorEdges(S.Edges(b, "BORDER"), A[1], A[2], A[3], 1)
    local t = S.UIText(b, nil, "CENTER", nil, 10, nil, "mono")
    t:SetPoint("CENTER", 0, 0)
    t:SetText("C")
    t:SetTextColor(A[1], A[2], A[3])
    b:SetAlpha(0.2)
    b:SetScript("OnEnter", function(self)
      self:SetAlpha(1)
      GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
      GameTooltip:SetText("Copy chat", 1, 1, 1)
      GameTooltip:AddLine("Opens this window's last lines as text you can select and copy.", 0.75, 0.75, 0.75, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self) self:SetAlpha(0.2); GameTooltip:Hide() end)
    b:SetScript("OnClick", function() C:Copy(f) end)
    self.copyButtons[f] = b
  end
  b:SetShown(ns.db.chatCopy and true or false)
end

function C:Extras()
  if ns.db.chatUrls then self:WatchURLs() end
  for f in pairs(self.skinned or {}) do pcall(self.CopyButton, self, f) end
end

function C:Enable()
  self.enabled = true
  self:SkinAll()
  pcall(self.Extras, self)
  -- Whisper and pet battle windows are made as they're needed.
  if type(_G.FCF_OpenTemporaryWindow) == "function" then
    hooksecurefunc("FCF_OpenTemporaryWindow", function() C:SkinAll(); pcall(C.Extras, C) end)
  end
  local ok, err = pcall(self.SetupMover, self)
  if not ok and ns.Errors and ns.Errors.Add then pcall(ns.Errors.Add, ns.Errors, "Chat: " .. tostring(err), nil, nil, "volt") end
  self:PlaceMain()
  -- The game lays its windows out again as you come into the world.
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:SetScript("OnEvent", function() C:SkinButtons(); Again() end)
end

FUI:Register(C)
