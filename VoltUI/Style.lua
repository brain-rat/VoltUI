-- VoltUI · Style
-- The shared look: flat dark panels, thin blue-grey borders, faint
-- highlights, and the rarity outline + inner glow used on items. Every module
-- builds from these so the whole UI stays consistent.

local _, ns = ...
local S = {}
ns.Style = S

S.WHITE = "Interface\\Buttons\\WHITE8X8"
S.BG = { 0.04, 0.05, 0.07 }
S.EDGE = { 0.35, 0.4, 0.5 }
S.ACCENT = { 0.5, 0.78, 1 }
S.LABEL = { 0.75, 0.75, 0.75 }
-- Greys for text that isn't the main thing (since 1.51.0, in place of two dozen shades picked
-- window by window): secondary text, hints and notes, and things that are off or empty.
S.SUB = { 0.75, 0.77, 0.8 }
S.HINT = { 0.6, 0.63, 0.68 }
S.OFF = { 0.5, 0.52, 0.56 }
S.HEADER_H = 24

local max, min, floor = math.max, math.min, math.floor

-- VoltUI's own windows. Since 1.81.0 the look the user chose from mockups on 2026-11-18: the same
-- graphite greys, but square corners throughout, WoW's gold (#FFC61A) as the one accent, a
-- graphic band on every card's heading, a flat tint with a solid edge under the mouse (no
-- gradient), and two mono fonts: Space Mono for titles, JetBrains Mono for everything else.
-- What follows describes the look it grew from.
-- (1.66.0, the "Obsidian" look, after obsidian.md; 1.62.0-1.65.0 was the
-- warm "Gilded" look): a ladder of neutral graphite greys (#0F0F0F window, #171717 header and
-- sidebar, #1E1E1E cards, #262626 card titles), one soft violet (#A78BFA) for what you're working
-- with and kept rare, neutral #404040 main buttons, and grey sidebar headings so the violet stands
-- alone. Status colours each mean one thing: green on and saved, red off, errors and Reset, amber
-- a part standing aside, blue a reload or help (Obsidian's are Tailwind's 400 shades; it has no
-- blue, so blue-400 is ours). Only VoltUI's windows use these: unit frames, bars, castbars and the
-- rest keep their own colours.
local function Hex(h)
  return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 }
end
S.UI = {
  -- the grey ladder, darkest first: the page, the window (header, sidebar, menus), cards,
  -- raised things (buttons, the chosen page, card title bands)
  bg = Hex("0F0F0F"), panel = Hex("171717"), head = Hex("171717"), side = Hex("171717"),
  card = Hex("1E1E1E"), cardHead = Hex("1E1E1E"), raised = Hex("262626"),
  field = Hex("171717"), -- boxes you type in, and the well behind choices, inside a card
  line = Hex("404040"), -- dividers: card borders, the line under a card's heading, the sidebar's edge
  edge = Hex("595959"), soft = Hex("404040"), -- the window's border; controls' borders
  text = Hex("FFFFFF"), label = Hex("DDDDDD"), sub = Hex("BCBCBC"),
  hint = Hex("8C8C8C"), off = Hex("666666"),
  accent = Hex("FFC61A"), accentText = Hex("FFD75E"),
  -- (1.87.0) the window's main button and a window's title block: gold text on a dark gold
  -- tint with a gold line (dark text on solid gold before: too harsh). The button's tint and
  -- border lighten under the mouse.
  primary = Hex("3C3317"), primaryText = Hex("FFC61A"), primaryEdge = Hex("FFE9A6"),
  primaryLine = Hex("FFC61A"), primaryHover = Hex("5D4B18"), block = Hex("3C3317"),
  control = Hex("404040"), -- a switch that's off, a slider's track, a chosen segment
  knob = Hex("FFFFFF"), knobOff = Hex("BCBCBC"),
  hatch = Hex("4A4A4A"), -- the hatched strip on a card's heading
  hover = 0.18,          -- how strong the accent tint under the mouse is
  ok = Hex("4ADE80"), warn = Hex("FACC15"), info = Hex("60A5FA"), bad = Hex("F87171"),
}
-- Corner radii, from Obsidian's scale (2, 3, 4, 6, 8, 12): the settings window, smaller
-- windows and menus, cards and tiles, buttons and boxes, a chosen segment, a slider's track.
-- (1.81.0) All square now. The names stay, so a look with corners again is one line; S.Round and
-- S.RoundEdges draw a plain box and plain lines for a radius they have no corner texture for.
S.UI.r = { window = 0, menu = 0, card = 0, button = 0, field = 0, seg = 0, track = 0, switch = 0, thumb = 0 }
-- The sidebar's headings: all one quiet grey, so the violet is the only colour that marks
-- where you are (Gilded gave each its item quality colour).
S.UI.cat = {
  VoltUI = Hex("8C8C8C"), Frames = Hex("8C8C8C"), Bars = Hex("8C8C8C"), World = Hex("8C8C8C"),
  Items = Hex("8C8C8C"), More = Hex("8C8C8C"),
}
function S.UI.Cat(group) return S.UI.cat[group or ""] or S.UI.cat.More end
-- "|cffrrggbb" for a colour, to colour part of a line of text.
function S.UI.Hex(c)
  return ("|cff%02x%02x%02x"):format(floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5))
end

-- Secret values can be handed to widgets (bars, text, textures) but not compared,
-- added up or formatted in Lua. Safe() gives nil for a secret, so a check just fails.
function S.IsSecret(v) return issecretvalue ~= nil and issecretvalue(v) == true end
function S.Safe(v)
  if S.IsSecret(v) then return nil end
  return v
end
function S.Present(v)
  if S.IsSecret(v) then return true end -- a secret is always a real value
  return v ~= nil
end

------------------------------------------------------------------------
-- Reading a unit's auras, in a fight too (1.92.1)
------------------------------------------------------------------------
-- By position (GetAuraDataByIndex) is what works out of a fight. In a fight the game refuses
-- it outright ("Auras cannot be accessed when secret while tainted"), which froze the buff
-- panel and emptied the target's auras until combat ended. Then they're read by instance id:
-- the game's API marks the id list as not refused, and each aura's data as secret-valued
-- rather than refused. An aura whose data can't be read at all is { auraInstanceID = id }
-- with the icon it had last time (voltIcon) from `seen`, or voltUnknown when never seen.

-- A table VoltUI may look inside: not a secret one.
function S.OpenTable(t)
  if type(t) ~= "table" or S.IsSecret(t) then return false end
  if canaccesstable and not canaccesstable(t) then return false end
  return true
end

local function RememberAura(seen, a)
  if not seen then return end
  local id, icon = a.auraInstanceID, a.icon
  if type(id) ~= "number" or S.IsSecret(id) or icon == nil or S.IsSecret(icon) then return end
  seen[id] = { icon = icon, dispelName = S.Safe(a.dispelName) }
end

local function AurasByIndex(unit, filter, most)
  local UA = C_UnitAuras
  if not (UA and UA.GetAuraDataByIndex) then return nil end
  local out = {}
  for i = 1, most do
    local ok, a = pcall(UA.GetAuraDataByIndex, unit, i, filter)
    if not ok then return nil end
    if a == nil then break end
    if not S.OpenTable(a) then return nil end
    out[#out + 1] = { a, i }
  end
  return out
end

local function AurasByID(unit, filter, most, seen)
  local UA = C_UnitAuras
  if not (UA and UA.GetUnitAuraInstanceIDs) then return nil end
  local ok, ids = pcall(UA.GetUnitAuraInstanceIDs, unit, filter)
  if not ok or not S.OpenTable(ids) then return nil end
  local out = {}
  local fine = pcall(function()
    for i, id in ipairs(ids) do
      if i > most then break end
      if type(id) == "number" and not S.IsSecret(id) then
        local a
        if UA.GetAuraDataByAuraInstanceID then
          local got, d = pcall(UA.GetAuraDataByAuraInstanceID, unit, id)
          if got and S.OpenTable(d) then a = d end
        end
        local old = seen and seen[id]
        if a then
          if old and (a.icon == nil or S.IsSecret(a.icon)) then a.voltIcon = old.icon end
        else
          -- Only the look comes from last time: the time and stacks are asked for by id.
          a = { auraInstanceID = id, voltIcon = old and old.icon, dispelName = old and old.dispelName, voltUnknown = not old }
        end
        out[#out + 1] = { a, i }
      end
    end
  end)
  if fine then return out end
end

-- A unit's auras under one filter: a list of { auraData, index }, and whether it was a plain
-- reading by position (true) or by id in a fight (false). Nil when the game refused both.
-- `seen` (optional, by instance id) is filled from every aura that can be read.
function S.AuraList(unit, filter, most, seen)
  local out = AurasByIndex(unit, filter, most)
  local plain = out ~= nil
  out = out or AurasByID(unit, filter, most, seen)
  if not out then return nil end
  for _, it in ipairs(out) do RememberAura(seen, it[1]) end
  return out, plain
end

-- Forget seen auras no longer there: `...` are id sets of what is.
function S.ForgetAuras(seen, ...)
  local sets = { ... }
  for id in pairs(seen) do
    local keep
    for _, set in ipairs(sets) do if set[id] then keep = true break end end
    if not keep then seen[id] = nil end
  end
end

-- The ids in an AuraList, as a set.
function S.AuraIDSet(list)
  local set = {}
  for _, it in ipairs(list) do
    local id = it[1].auraInstanceID
    if type(id) == "number" and not S.IsSecret(id) then set[id] = true end
  end
  return set
end

-- An aura's icon onto a texture: a secret one goes straight in (the game draws it); one VoltUI
-- can't even pass on becomes the icon seen last time, or a question mark.
function S.AuraIcon(tex, a)
  if a.icon == nil or not pcall(tex.SetTexture, tex, a.icon) then
    tex:SetTexture(a.voltIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
  end
end

-- A health or power number for text, secret or not: the game's own functions format it.
function S.Num(v)
  if BreakUpLargeNumbers then return BreakUpLargeNumbers(v) end
  if AbbreviateNumbers then return AbbreviateNumbers(v) end
  return S.Safe(v) and tostring(v) or "?"
end

-- The same, shortened (12.5K) where there's little room.
function S.ShortNum(v)
  if AbbreviateNumbers then return AbbreviateNumbers(v) end
  if AbbreviateLargeNumbers then return AbbreviateLargeNumbers(v) end
  return S.Num(v)
end

-- A unit's health as a whole percent, for text. Worked out here when the numbers can be read,
-- otherwise asked of the game, which hands back something text can show even when secret.
function S.HealthPercent(u, cur, maxv)
  local c, m = S.Safe(cur), S.Safe(maxv)
  if c and m then return m > 0 and floor(c / m * 100 + 0.5) or 0 end
  if UnitHealthPercent and CurveConstants then
    local p = UnitHealthPercent(u, nil, CurveConstants.ScaleTo100)
    if C_StringUtil and C_StringUtil.RoundToNearestString then return C_StringUtil.RoundToNearestString(p) end
    if AbbreviateNumbers then return AbbreviateNumbers(p) end
  end
  return "?"
end

-- A hidden parent for Blizzard frames that VoltUI replaces.
function S.HiddenParent()
  if not S.hidden then
    S.hidden = CreateFrame("Frame")
    S.hidden:Hide()
  end
  return S.hidden
end

function S.Tex(parent, layer, sub)
  local t = parent:CreateTexture(nil, layer, nil, sub)
  if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
  if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
  t.kParent, t.kLayer, t.kSub = parent, layer, sub -- for S.Round's pieces
  return t
end

------------------------------------------------------------------------
-- Fonts: twenty bundled (SIL Open Font Licence), the game's own, and any
-- LibSharedMedia fonts other add-ons register. One font for all of VoltUI (db.font), and any
-- text can have its own (db.fontRoles, the Fonts page, since 1.70.0).
------------------------------------------------------------------------

local FONT_DIR = "Interface\\AddOns\\VoltUI\\Fonts\\"
S.FONTS = {
  { key = "barlow", name = "Barlow", path = FONT_DIR .. "Barlow-SemiBold.ttf" },
  { key = "barlowcondensed", name = "Barlow Condensed", path = FONT_DIR .. "BarlowCondensed-SemiBold.ttf" },
  { key = "rajdhani", name = "Rajdhani", path = FONT_DIR .. "Rajdhani-SemiBold.ttf" },
  { key = "chakra", name = "Chakra Petch", path = FONT_DIR .. "ChakraPetch-SemiBold.ttf" },
  { key = "inter", name = "Inter", path = FONT_DIR .. "Inter-SemiBold.ttf" },
  { key = "ptsansnarrow", name = "PT Sans Narrow", path = FONT_DIR .. "PTSansNarrow-Bold.ttf" },
  { key = "lato", name = "Lato", path = FONT_DIR .. "Lato-SemiBold.ttf" },
  { key = "titillium", name = "Titillium Web", path = FONT_DIR .. "TitilliumWeb-SemiBold.ttf" },
  { key = "teko", name = "Teko", path = FONT_DIR .. "Teko-SemiBold.ttf" },
  -- since 1.71.0
  { key = "bigshoulders", name = "Big Shoulders Text", path = FONT_DIR .. "BigShouldersText-Bold.ttf" },
  { key = "baloo", name = "Baloo 2", path = FONT_DIR .. "Baloo2-SemiBold.ttf" },
  { key = "orbitron", name = "Orbitron", path = FONT_DIR .. "Orbitron-SemiBold.ttf" },
  { key = "russo", name = "Russo One", path = FONT_DIR .. "RussoOne-Regular.ttf" },
  { key = "oxanium", name = "Oxanium", path = FONT_DIR .. "Oxanium-SemiBold.ttf" },
  { key = "electrolize", name = "Electrolize", path = FONT_DIR .. "Electrolize-Regular.ttf" },
  { key = "baijamjuree", name = "Bai Jamjuree", path = FONT_DIR .. "BaiJamjuree-SemiBold.ttf" },
  { key = "jetbrainsmono", name = "JetBrains Mono", path = FONT_DIR .. "JetBrainsMono-SemiBold.ttf" },
  { key = "spacemono", name = "Space Mono", path = FONT_DIR .. "SpaceMono-Bold.ttf" },
  { key = "bebas", name = "Bebas Neue", path = FONT_DIR .. "BebasNeue-Regular.ttf" },
  -- since 1.87.1: a mono font a sixth narrower than JetBrains Mono
  { key = "inconsolatasc", name = "Inconsolata Semi Condensed", path = FONT_DIR .. "Inconsolata-SemiCondensedMedium.ttf" },
  { key = "friz", name = "Friz Quadrata (game)", path = "Fonts\\FRIZQT__.TTF" },
  { key = "arial", name = "Arial Narrow (game)", path = "Fonts\\ARIALN.TTF" },
  { key = "skurri", name = "Skurri (game)", path = "Fonts\\skurri.ttf" },
  { key = "morpheus", name = "Morpheus (game)", path = "Fonts\\MORPHEUS.TTF" },
}
S.OUTLINES = { { key = "", name = "None" }, { key = "OUTLINE", name = "Outline" }, { key = "THICKOUTLINE", name = "Thick" } }

function S.LoadSharedFonts()
  local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
  if not LSM then return end
  local have = {}
  for _, f in ipairs(S.FONTS) do have[f.key] = true end
  for _, name in ipairs(LSM:List("font") or {}) do
    local key = "lsm:" .. name
    if not have[key] then
      table.insert(S.FONTS, { key = key, name = name, path = LSM:Fetch("font", name) })
    end
  end
end

-- The texts that can have a font of their own, in the Fonts page's order. Each is a key in
-- db.fontRoles; a text with none set (or a font that's gone) uses the overall font.
S.FONT_ROLES = {
  { key = "frames.name", group = "Unit frames", name = "Names" },
  { key = "frames.level", group = "Unit frames", name = "Level and tags" },
  { key = "frames.health", group = "Unit frames", name = "Health numbers" },
  { key = "frames.power", group = "Unit frames", name = "Power numbers" },
  { key = "frames.auras", group = "Unit frames", name = "Aura stacks" },
  { key = "groups.name", group = "Party and raid", name = "Names" },
  { key = "groups.status", group = "Party and raid", name = "Health and status" },
  { key = "cast.name", group = "Castbar", name = "Spell names" },
  { key = "cast.time", group = "Castbar", name = "Cast times" },
  { key = "timers.numbers", group = "Timers", name = "Countdown numbers" },
  { key = "timers.label", group = "Timers", name = "Bar names" },
  { key = "timers.count", group = "Timers", name = "Stacks" },
  { key = "buffs.time", group = "Buffs", name = "Time left" },
  { key = "buffs.count", group = "Buffs", name = "Stacks" },
  { key = "bars.cooldown", group = "Action bars", name = "Cooldown numbers" },
  { key = "bars.key", group = "Action bars", name = "Keybinds" },
  { key = "bars.macro", group = "Action bars", name = "Macro names" },
  { key = "bars.count", group = "Action bars", name = "Stacks and charges" },
  { key = "bars.xp", group = "Action bars", name = "XP and reputation text" },
  { key = "plates.name", group = "Nameplates", name = "Names" },
  { key = "plates.health", group = "Nameplates", name = "Health text" },
  { key = "plates.level", group = "Nameplates", name = "Levels" },
  { key = "plates.cast", group = "Nameplates", name = "Cast text" },
  { key = "plates.auras", group = "Nameplates", name = "Aura numbers" },
  { key = "bags.header", group = "Bags", name = "Category headings" },
  { key = "bags.count", group = "Bags", name = "Stack counts" },
  { key = "tooltips", group = "Tooltips", name = "Tooltip text" },
}

local function FindFont(key)
  if key == nil then return nil end
  for _, f in ipairs(S.FONTS) do
    if f.key == key then return f end
  end
end

-- A font by key; with no key, the font for `role` (its own, or else the overall one).
function S.Font(key, role)
  local f = FindFont(key)
  if f then return f end
  local db = ns.db
  if role and db and type(db.fontRoles) == "table" then f = FindFont(db.fontRoles[role]) end
  return f or FindFont(key == nil and db and db.font or nil) or S.FONTS[1]
end

-- The font a role has picked for itself, or nil when it follows the overall font.
function S.RoleFont(role)
  local db = ns.db
  local t = db and type(db.fontRoles) == "table" and db.fontRoles
  return t and FindFont(t[role]) or nil
end

-- Give `role` a font of its own (a font key), or nil to follow the overall font again.
function S.SetRoleFont(role, key)
  local db = ns.db
  if not db then return end
  if key == nil then
    if type(db.fontRoles) == "table" then
      db.fontRoles[role] = nil
      if next(db.fontRoles) == nil then db.fontRoles = nil end
    end
    return
  end
  if type(db.fontRoles) ~= "table" then db.fontRoles = {} end
  db.fontRoles[role] = key
end

local registered = {}
local roles = setmetatable({}, { __mode = "k" }) -- font string -> its role, kept across SetFont calls
S.fontRoleOf = roles
local fixed = {}
local faceOf = setmetatable({}, { __mode = "k" }) -- font string -> "mono", kept across FixFont calls
-- Settings windows are set in fonts of their own (since 1.66.0, the Obsidian look; Barlow
-- before), never the font picked for frames, and not one players pick either (1.72.0). Inter
-- for words; JetBrains Mono (since 1.72.0) for what reads as data: values, numbers, keys and
-- the small capital headings. Three weights each: regular for text, medium for buttons,
-- semibold for titles (14 and up, unless told).
-- (1.81.0) Two mono fonts and no Inter: words are JetBrains Mono, and anything semibold (titles:
-- the window's, a page's, a card's, the main button) is Space Mono Bold. Data keeps JetBrains
-- Mono at every weight. Mono letters are about a fifth wider than Inter's, so words asked for
-- at 12 or 13 are set a size smaller, which keeps labels on their rows.
S.UI_FONTS = { key = "words", name = "JetBrains Mono", regular = FONT_DIR .. "JetBrainsMono-Regular.ttf",
  medium = FONT_DIR .. "JetBrainsMono-Medium.ttf", semibold = FONT_DIR .. "SpaceMono-Bold.ttf", title = "Space Mono" }
S.UI_MONO = { key = "mono", name = "JetBrains Mono", regular = FONT_DIR .. "JetBrainsMono-Regular.ttf",
  medium = FONT_DIR .. "JetBrainsMono-Medium.ttf", semibold = FONT_DIR .. "JetBrainsMono-SemiBold.ttf" }
local function Weight(size, weight) return weight or (size >= 14 and "semibold" or "regular") end
local function FixedFont(size, weight, face)
  face = face == "mono" and S.UI_MONO or S.UI_FONTS
  return face[Weight(size, weight)] or face.regular
end
-- The size a settings text is drawn at, for the size it was asked for.
function S.UIWordSize(size, weight, face)
  if face ~= "mono" and Weight(size, weight) ~= "semibold" and size >= 12 and size < 14 then return size - 1 end
  return size
end
-- Load them all now: the first text set in a font the game hasn't loaded yet can be drawn
-- blank (seen in game, 1.66.0: the close and Move frames buttons, the first made in Inter
-- Medium). These stay, unseen, so the fonts stay loaded.
do
  local holder = CreateFrame("Frame", nil, UIParent)
  holder:SetSize(1, 1)
  holder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -50, 50)
  holder:SetAlpha(0)
  S.fontWarm = {}
  for _, face in ipairs({ S.UI_FONTS, S.UI_MONO }) do -- (Space Mono Bold is the first's semibold)
    for _, w in ipairs({ "regular", "medium", "semibold" }) do
      local fs = holder:CreateFontString(nil, "OVERLAY")
      pcall(fs.SetFont, fs, face[w], 12, "")
      fs:SetText("VoltUI 0123")
      fs:SetPoint("TOPLEFT")
      S.fontWarm[#S.fontWarm + 1] = fs
    end
  end
end

-- Settings windows' text can be made bigger or smaller as a whole (General > Settings window,
-- since 1.61.0): 12 is as it was. Read when each text is made, so it takes a reload.
function S.UISize(size)
  local base = ns.db and tonumber(ns.db.uiText) or 12
  return size + max(-1, min(2, floor(base + 0.5) - 12))
end

local function SetFixed(fs, size, flags, weight)
  local path = FixedFont(size, weight, faceOf[fs])
  size = S.UISize(S.UIWordSize(size, weight, faceOf[fs]))
  local ok = pcall(fs.SetFont, fs, path, size, flags or "")
  if not ok or (fs.GetFont and not fs:GetFont()) then
    pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", size, flags or "")
  end
end

-- Settings windows stay in their own fonts, whatever font the rest of VoltUI is set to. weight:
-- "regular", "medium" or "semibold"; by default semibold from 14 up, regular under. face:
-- "mono" for JetBrains Mono, "inter" back to Inter; left out, the text keeps the one it had.
function S.FixFont(fs, size, flags, weight, face)
  registered[fs] = nil
  weight = weight or (type(fixed[fs]) == "string" and fixed[fs]) or nil -- a button's text stays medium at any size
  fixed[fs] = weight or true
  if face == "mono" then faceOf[fs] = "mono" elseif face then faceOf[fs] = nil end
  SetFixed(fs, size, flags, weight)
end

-- A settings text in JetBrains Mono: S.FixFont with the face given.
function S.Mono(fs, size, flags, weight)
  S.FixFont(fs, size, flags, weight, "mono")
  return fs
end
S.UIFaceOf = function(fs) return faceOf[fs] == "mono" and S.UI_MONO or S.UI_FONTS end

-- Set a font string to the VoltUI font at this size (and outline flags). role: which text it is
-- (S.FONT_ROLES), for a font of its own; once given it stays with the font string.
function S.SetFont(fs, size, flags, role)
  if fixed[fs] then return SetFixed(fs, size, flags, fixed[fs] ~= true and fixed[fs] or nil) end
  if role then roles[fs] = role end
  local reg = registered[fs]
  if reg then reg[1], reg[2] = size, flags else registered[fs] = { size, flags } end
  local f = S.Font(nil, roles[fs])
  local ok = pcall(fs.SetFont, fs, f.path, size, flags or "")
  if not ok or (fs.GetFont and not fs:GetFont()) then
    pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", size, flags or "")
  end
end

-- (1.87.0) One font by its key for a text, whatever the font setting is: S.ApplyFonts leaves
-- it alone after. S.SetFont puts the text back on the font setting.
function S.SetFace(fs, key, size, flags)
  local f = FindFont(key)
  if not f or fixed[fs] then return S.SetFont(fs, size, flags) end
  registered[fs] = nil
  local ok = pcall(fs.SetFont, fs, f.path, size, flags or "")
  if not ok or (fs.GetFont and not fs:GetFont()) then
    pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", size, flags or "")
  end
end

-- Re-apply after the font setting changes. WoW doesn't always redraw text that
-- isn't set again after its font changes, so each text is set again too.
function S.ApplyFonts()
  for fs, v in pairs(registered) do
    S.SetFont(fs, v[1], v[2])
    if fs.GetObjectType and fs:GetObjectType() == "FontString" and fs.GetText then
      local t = fs:GetText()
      if S.IsSecret(t) then
        fs:SetText(t) -- a secret can't be compared, only passed back
      elseif t and t ~= "" then
        fs:SetText(" ")
        fs:SetText(t)
      end
    end
  end
end

-- size: use the VoltUI font at this size; otherwise the template's font. role: see S.SetFont.
function S.Text(parent, template, justify, layer, size, flags, role)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY", template or "GameFontHighlightSmall")
  fs:SetJustifyH(justify or "LEFT")
  fs:SetWordWrap(false)
  if role then roles[fs] = role end
  if size then S.SetFont(fs, size, flags) end
  return fs
end

-- Text for settings windows: never follows the font setting. face: "mono" for JetBrains Mono.
function S.UIText(parent, template, justify, layer, size, flags, face)
  local fs = S.Text(parent, template, justify, layer)
  S.FixFont(fs, size or 12, flags, nil, face)
  return fs
end

-- One screen pixel, in the units of `frame` (or of the screen). 1 where the game can't say.
function S.Px(frame)
  local pu = _G.PixelUtil
  local factor = pu and pu.GetPixelToUIUnitFactor and S.Safe(pu.GetPixelToUIUnitFactor())
  if type(factor) ~= "number" or factor <= 0 then return 1 end
  local scale = frame and frame.GetEffectiveScale and S.Safe(frame:GetEffectiveScale())
  if type(scale) ~= "number" or scale <= 0 then
    scale = UIParent and UIParent.GetEffectiveScale and S.Safe(UIParent:GetEffectiveScale())
  end
  if type(scale) ~= "number" or scale <= 0 then return 1 end
  return factor / scale
end

-- Pixel-true borders (1.101.19). A border line used to be 1 UI unit thick, which at most UI
-- scales is not a whole number of screen pixels (1.25 at a common one), so lines came out
-- soft and of uneven weight. Each line is now a whole number of screen pixels, worked out
-- from the scale of the frame it's on, and sits on the pixel grid. Every border made by
-- S.Edges is remembered (weakly), so they can all be sized again when the UI scale, the
-- window or a frame's own scale changes: S.RefreshEdges. "Crisp borders" off (pixelEdges)
-- gives the old 1-unit lines.
S.edgeSets = setmetatable({}, { __mode = "k" })

local function EdgeSize(e)
  local info = S.edgeSets[e]
  local w = info and info.w or 1
  local crisp = not (ns.db and ns.db.pixelEdges == false)
  local t = w
  if crisp then
    local px = S.Px(info and info.parent)
    t = math.max(1, math.floor(w + 0.5)) * px
  end
  e[1]:SetHeight(t); e[2]:SetHeight(t); e[3]:SetWidth(t); e[4]:SetWidth(t)
  for i = 1, 4 do
    local line = e[i]
    if line.SetSnapToPixelGrid then line:SetSnapToPixelGrid(crisp) end
    if line.SetTexelSnappingBias then line:SetTexelSnappingBias(crisp and 1 or 0) end
  end
end

-- 1px border of four lines around `anchor` (outset pushes it outside).
function S.Edges(parent, layer, sub, anchor, outset)
  anchor, outset = anchor or parent, outset or 0
  local o = outset
  local e = {}
  for i = 1, 4 do e[i] = S.Tex(parent, layer, sub) end
  e[1]:SetPoint("TOPLEFT", anchor, "TOPLEFT", -o, o); e[1]:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", o, o)
  e[2]:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", -o, -o); e[2]:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", o, -o)
  e[3]:SetPoint("TOPLEFT", anchor, "TOPLEFT", -o, o); e[3]:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", -o, -o)
  e[4]:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", o, o); e[4]:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", o, -o)
  S.edgeSets[e] = { parent = parent, w = 1 }
  EdgeSize(e)
  return e
end

-- (1.88.0) How thick a border made by S.Edges is (1 as made). It grows inward.
function S.EdgeWidth(e, w)
  local info = S.edgeSets[e]
  if not info then
    info = { w = 1 }
    S.edgeSets[e] = info
  end
  info.w = tonumber(w) or 1
  EdgeSize(e)
end

-- Every border again, after a scale changed. Sizes and snapping only: safe in a fight.
function S.RefreshEdges()
  for e in pairs(S.edgeSets) do pcall(EdgeSize, e) end
end

function S.ColorEdges(e, r, g, b, a)
  for i = 1, e.n or 4 do
    S.Paint(e[i], r, g, b, a)
    e[i]:Show()
  end
end

function S.HideEdges(e)
  for i = 1, e.n or 4 do e[i]:Hide() end
end

------------------------------------------------------------------------
-- Rounded corners (since 1.66.0, for VoltUI's own windows). A rounded box is drawn in pieces:
-- four corners from small white textures in VoltUI/Media (tools/make_round.py), each made for the
-- size it's shown at, and flat colour for everything straight, so straight edges stay crisp at
-- any interface scale. (The first try nine-sliced one texture; the game drew its 1px border
-- and corners blurred and uneven at a 1.24 scale.) The pieces keep the game's own pixel
-- snapping. A rounded texture takes its colour from S.Paint, never SetColorTexture.
------------------------------------------------------------------------

S.MEDIA = "Interface\\AddOns\\VoltUI\\Media\\"
local RADII = { [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true, [11] = true, [12] = true }
local DISCS = { [5] = true, [6] = true, [10] = true, [12] = true }
-- each corner: its point, and texture coordinates that turn the top-left corner into it
local CORNERS = {
  { "TOPLEFT", 0, 1, 0, 1 }, { "TOPRIGHT", 1, 0, 0, 1 },
  { "BOTTOMLEFT", 0, 1, 1, 0 }, { "BOTTOMRIGHT", 1, 0, 1, 0 },
}

local function Piece(parent, layer, sub, file)
  local t = parent:CreateTexture(nil, layer, nil, sub)
  if file then
    t:SetTexture(S.MEDIA .. file, "CLAMP", "CLAMP", "TRILINEAR")
    t.round = true
  end
  return t
end

local function Corners(parent, layer, sub, anchor, file, radius)
  local p = {}
  for i, c in ipairs(CORNERS) do
    local t = Piece(parent, layer, sub, file .. radius)
    t:SetTexCoord(c[2], c[3], c[4], c[5])
    t:SetSize(radius, radius)
    t:SetPoint(c[1], anchor, c[1])
    p[i] = t
  end
  return p
end

-- The pieces show, hide and fade with the texture they're drawn for.
local function Follow(tex)
  local show, hide, setAlpha = tex.Show, tex.Hide, tex.SetAlpha
  function tex:Show() show(self); for _, p in ipairs(self.pieces) do p:Show() end end
  function tex:Hide() hide(self); for _, p in ipairs(self.pieces) do p:Hide() end end
  function tex:SetShown(on) if on then self:Show() else self:Hide() end end
  function tex:SetAlpha(a) setAlpha(self, a); for _, p in ipairs(self.pieces) do p:SetAlpha(a) end end
end

-- Makes `tex` a rounded rectangle with corners `radius` across (one of RADII). `tex` keeps its
-- points and is the box the pieces are drawn in; it draws nothing itself.
function S.Round(tex, radius)
  if not (radius and RADII[radius]) or tex.shape then return tex end
  local parent, layer, sub = tex.kParent, tex.kLayer, tex.kSub
  if not parent then return tex end -- not made by S.Tex
  tex:SetColorTexture(1, 1, 1, 0)
  local p = Corners(parent, layer, sub, tex, "Corner", radius)
  local top = Piece(parent, layer, sub)
  top:SetPoint("TOPLEFT", p[1], "TOPRIGHT")
  top:SetPoint("BOTTOMRIGHT", p[2], "BOTTOMLEFT")
  local mid = Piece(parent, layer, sub)
  mid:SetPoint("TOPLEFT", p[1], "BOTTOMLEFT")
  mid:SetPoint("BOTTOMRIGHT", p[4], "TOPRIGHT")
  local bottom = Piece(parent, layer, sub)
  bottom:SetPoint("TOPLEFT", p[3], "TOPRIGHT")
  bottom:SetPoint("BOTTOMRIGHT", p[4], "BOTTOMLEFT")
  p[5], p[6], p[7] = top, mid, bottom
  tex.pieces, tex.shape = p, radius
  Follow(tex)
  return tex
end

-- Colours a texture: square, rounded, or a disc. tex.paint keeps the colour, in one table
-- that's written over: this runs for every fill and edge on every repaint of a settings page.
local function KeepPaint(tex, r, g, b, a)
  local p = tex.paint
  if p then p[1], p[2], p[3], p[4] = r, g, b, a else tex.paint = { r, g, b, a } end
end

function S.Paint(tex, r, g, b, a)
  a = a or 1
  if tex.shape then
    KeepPaint(tex, r, g, b, a)
    for _, p in ipairs(tex.pieces) do
      if p.round then p:SetVertexColor(r, g, b, a) else p:SetColorTexture(r, g, b, a) end
    end
  elseif tex.round then
    KeepPaint(tex, r, g, b, a)
    tex:SetVertexColor(r, g, b, a)
  else
    tex:SetColorTexture(r, g, b, a)
  end
end

-- A rounded 1px border around `anchor`: four corner arcs and four straight lines, coloured
-- with S.ColorEdges like S.Edges' four lines.
function S.RoundEdges(parent, layer, sub, anchor, radius)
  anchor = anchor or parent
  if not RADII[radius or 0] then return S.Edges(parent, layer, sub, anchor) end
  local e = Corners(parent, layer, sub, anchor, "CornerRing", radius)
  local top, bottom, left, right = Piece(parent, layer, sub), Piece(parent, layer, sub), Piece(parent, layer, sub), Piece(parent, layer, sub)
  top:SetPoint("TOPLEFT", e[1], "TOPRIGHT"); top:SetPoint("TOPRIGHT", e[2], "TOPLEFT"); top:SetHeight(1)
  bottom:SetPoint("BOTTOMLEFT", e[3], "BOTTOMRIGHT"); bottom:SetPoint("BOTTOMRIGHT", e[4], "BOTTOMLEFT"); bottom:SetHeight(1)
  left:SetPoint("TOPLEFT", e[1], "BOTTOMLEFT"); left:SetPoint("BOTTOMLEFT", e[3], "TOPLEFT"); left:SetWidth(1)
  right:SetPoint("TOPRIGHT", e[2], "BOTTOMRIGHT"); right:SetPoint("BOTTOMRIGHT", e[4], "TOPRIGHT"); right:SetWidth(1)
  e[5], e[6], e[7], e[8] = top, bottom, left, right
  e.n = 8
  return e
end

-- A white disc `size` across (one of DISCS: switch knobs, slider thumbs, dots), tinted with S.Paint.
-- (1.81.0) Square, like everything else in the hard-edged look: knobs, markers and dots are
-- small solid squares. S.UI.round brings the discs back.
function S.Disc(tex, size)
  size = DISCS[size or 0] and size or 10
  if S.UI.round then
    tex:SetTexture(S.MEDIA .. "Disc" .. size, "CLAMP", "CLAMP", "TRILINEAR")
  else
    tex:SetColorTexture(1, 1, 1, 1)
  end
  tex:SetSize(size, size)
  if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(true) end
  tex.round = true -- tinted with SetVertexColor either way
  return tex
end

-- A strip of diagonal hatching (VoltUI/Media/Hatch.tga, from tools/make_hatch.py), tiled at its
-- own size whatever the strip's, and tinted with S.Paint. The graphic on a card's heading.
function S.Hatch(tex)
  tex:SetTexture(S.MEDIA .. "Hatch", "REPEAT", "REPEAT")
  if tex.SetHorizTile then tex:SetHorizTile(true) end
  if tex.SetVertTile then tex:SetVertTile(true) end
  tex.round, tex.hatch = true, true
  return tex
end

-- A pill button as wide as its label (or `text`, its longest label) with room each side, and
-- no narrower than `minW`. b.width keeps it for whatever lays buttons out in a row.
S.PILL_PAD = 12
function S.FitPill(b, minW, text)
  local old = b.text:GetText()
  if text then b.text:SetText(text) end
  local label = b.text:GetText() or ""
  local w = max(minW or 0, math.ceil(S.TextWidth and S.TextWidth(b.text, #label * 7) or #label * 7) + 2 * S.PILL_PAD)
  if text then b.text:SetText(old) end
  b:SetWidth(w)
  b.width = w
  return w
end

-- A rounded box in one go: a fill and a border, both on `f`'s back layers. Returns fill, edges.
function S.RoundBox(f, radius, fillLayer, fillSub, edgeSub)
  local fill = S.Tex(f, fillLayer or "BACKGROUND", fillSub or -8)
  fill:SetAllPoints()
  S.Round(fill, radius)
  local edges = S.RoundEdges(f, fillLayer or "BACKGROUND", edgeSub or (fillSub or -8) + 1, f, radius)
  return fill, edges
end

-- A window: flat fill + border. Returns the panel parts.
function S.Panel(f, alpha)
  local p = f.fuiPanel
  if not p then
    p = { fill = S.Tex(f, "BACKGROUND", -8) }
    p.fill:SetAllPoints()
    p.edges = S.Edges(f, "BACKGROUND", -7)
    f.fuiPanel = p
  end
  alpha = alpha or ns.db.alpha
  p.fill:SetColorTexture(S.BG[1], S.BG[2], S.BG[3], alpha)
  S.ColorEdges(p.edges, S.EDGE[1], S.EDGE[2], S.EDGE[3], min(1, alpha + 0.2))
  return p
end

-- The same window in VoltUI's own look (S.UI): settings, menus, the move toolbar. A rounded
-- window in the ladder's window grey; `radius` defaults to a menu's.
function S.ThemePanel(f, alpha, radius)
  local p = f.fuiPanel
  if not p then
    p = {}
    p.fill, p.edges = S.RoundBox(f, radius or S.UI.r.menu, "BACKGROUND", -8, -7)
    f.fuiPanel = p
  end
  local T = S.UI
  S.Paint(p.fill, T.panel[1], T.panel[2], T.panel[3], alpha or ns.db.alpha)
  S.ColorEdges(p.edges, T.edge[1], T.edge[2], T.edge[3], 1)
  return p
end

-- Faint title strip across the top.
function S.Header(f, h)
  local t = S.Tex(f, "BACKGROUND", -6)
  t:SetPoint("TOPLEFT", 1, -1)
  t:SetPoint("TOPRIGHT", -1, -1)
  t:SetHeight((h or S.HEADER_H) - 1)
  t:SetColorTexture(1, 1, 1, 0.06)
  return t
end

-- What shows under the mouse in VoltUI's own windows (since 1.81.0): a flat tint of the accent,
-- a one-pixel outline in it and, on rows and buttons, a solid edge down the left. WoW lights a
-- row with a gradient; this is the same idea with none. All in the HIGHLIGHT layer, so the
-- game shows and hides it. opts.bar = false leaves the edge off (small buttons);
-- opts.plain = true leaves the outline off too (the choices in a segmented set).
-- opts.layer (with opts.sub) draws it in an ordinary layer instead, hidden, for a frame that
-- shows and hides it itself (a settings row, which has to stay lit over its own controls).
-- f.hl is the tint; showing, hiding or fading it does the same to the rest.
function S.Hover(f, opts)
  opts = opts or {}
  local A = S.UI.accent
  local layer, sub = opts.layer or "HIGHLIGHT", opts.layer and opts.sub or nil
  local hl = f.hl
  if not hl then
    hl = S.Tex(f, layer, sub)
    hl:SetAllPoints()
    f.hl = hl
  end
  hl:SetColorTexture(A[1], A[2], A[3], S.UI.hover)
  if hl.kHover then return hl end
  hl.kHover = true
  local parts = {}
  if not opts.plain then
    local e = S.Edges(f, layer, sub)
    S.ColorEdges(e, A[1], A[2], A[3], 1)
    for i = 1, 4 do parts[#parts + 1] = e[i] end
    f.hlEdges = e
  end
  if opts.bar ~= false and not opts.plain then
    local bar = S.Tex(f, layer, sub)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("BOTTOMLEFT")
    bar:SetWidth(3)
    bar:SetColorTexture(A[1], A[2], A[3], 1)
    parts[#parts + 1] = bar
    f.hlBar = bar
  end
  hl.parts = parts
  local show, hide, setAlpha = hl.Show, hl.Hide, hl.SetAlpha
  function hl:Show() show(self); for _, p in ipairs(self.parts) do p:Show() end end
  function hl:Hide() hide(self); for _, p in ipairs(self.parts) do p:Hide() end end
  function hl:SetShown(on) if on then self:Show() else self:Hide() end end
  function hl:SetAlpha(a) setAlpha(self, a); for _, p in ipairs(self.parts) do p:SetAlpha(a) end end
  if opts.layer then hl:Hide() end
  return hl
end

-- A plain white highlight, for the game-side windows (bags, loot, lists). Given a radius it's
-- one of VoltUI's own windows asking, which gets S.Hover's look.
function S.Highlight(f, a, radius)
  if radius ~= nil then return S.Hover(f) end
  local hl = S.Tex(f, "HIGHLIGHT")
  hl:SetAllPoints()
  S.Paint(hl, 1, 1, 1, a or 0.12)
  f.hl = hl
  return hl
end

-- Sets a text again, through a blank, so the game redraws it in its font.
function S.Wake(fs)
  if not (fs and fs.GetText) then return end
  local t = fs:GetText()
  if type(t) == "string" and t ~= "" then
    fs:SetText(" ")
    fs:SetText(t)
  end
end

-- A flat text button.
function S.Button(parent, label, width, onClick, tip)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width, 18)
  b.text = S.Text(b, "GameFontHighlightSmall", "CENTER", nil, 12)
  -- Across the button, as tall as the text wants: a label pinned to the button's height too
  -- was drawn blank on the bag window's buttons (seen in game, 1.53.0).
  b.text:SetPoint("LEFT", b, "LEFT", 0, 0)
  b.text:SetPoint("RIGHT", b, "RIGHT", 0, 0)
  b.text:SetText(label)
  S.Highlight(b)
  b:SetScript("OnClick", onClick)
  if tip then
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:SetText(tip, 1, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  return b
end

-- The same button for settings windows, with their hover. plain: no outline under the mouse
-- (a choice in a segmented set).
function S.UIButton(parent, label, width, onClick, tip, plain)
  local b = S.Button(parent, label, width, onClick, tip)
  S.FixFont(b.text, 12, nil, "medium")
  S.Hover(b, { bar = false, plain = plain })
  return b
end

-- The main button of a window: a solid neutral grey fill (rounded when `bg` is) with light text and a lighter grey
-- border that brightens under the mouse (1.66.0, Obsidian: main buttons stay neutral so they
-- don't compete with the violet). bg is the button's fill texture. S.PlainLook takes it off again
-- (for pooled rows that are sometimes a main button and sometimes not).
S.PRIMARY_BG = { 0.11, 0.21, 0.34 }
S.PRIMARY_TEXT = 13

local function PrimaryEdge(b, hover)
  local e = b.primaryEdges
  if not (e and e.on) then return end
  -- flat like Obsidian's: the border is the fill's own grey, a step lighter under the mouse
  hover = hover and not (b.IsEnabled and b:IsEnabled() == false)
  local c = hover and S.UI.primaryEdge or S.UI.primaryLine
  S.ColorEdges(e, c[1], c[2], c[3], 1)
  local f = hover and S.UI.primaryHover or S.UI.primary
  if b.primaryBg then S.Paint(b.primaryBg, f[1], f[2], f[3], 1) end
end

-- (1.87.0) A window's title block: a dark gold tint with a 2-pixel gold line along its bottom
-- (block.kLine), for gold text. owner: what the line is drawn on.
function S.BlockLook(owner, block)
  local T = S.UI
  block:SetColorTexture(T.block[1], T.block[2], T.block[3], 1)
  if not block.kLine then
    block.kLine = S.Tex(owner, "OVERLAY")
    block.kLine:SetPoint("BOTTOMLEFT", block, "BOTTOMLEFT", 0, 0)
    block.kLine:SetPoint("BOTTOMRIGHT", block, "BOTTOMRIGHT", 0, 0)
    block.kLine:SetHeight(2)
  end
  block.kLine:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], 1)
end

function S.PrimaryLook(b, bg)
  local T = S.UI
  S.Paint(bg, T.primary[1], T.primary[2], T.primary[3], 1)
  b.primaryBg = bg
  if b.text then b.text:SetTextColor(T.primaryText[1], T.primaryText[2], T.primaryText[3]) end
  if not b.primaryEdges then
    b.primaryEdges = bg.shape and S.RoundEdges(b, "BORDER", nil, b, bg.shape) or S.Edges(b, "BORDER")
    b:HookScript("OnEnter", function(self) PrimaryEdge(self, true) end)
    b:HookScript("OnLeave", function(self) PrimaryEdge(self, false) end)
  end
  b.primaryEdges.on = true
  PrimaryEdge(b, b.IsMouseOver and b:IsMouseOver())
end

function S.PlainLook(b)
  local e = b.primaryEdges
  if not e then return end
  e.on = false
  b.primaryBg = nil
  S.HideEdges(e)
end

------------------------------------------------------------------------
-- Flattening another window's art. Only ever fades it, because the owner of the art keeps
-- looking those textures up. See the rules in S.Kill and the read-me's notes on taint.
------------------------------------------------------------------------

function S.Fade(...)
  for i = 1, select("#", ...) do
    local o = select(i, ...)
    if type(o) == "table" and o.SetAlpha then o:SetAlpha(0) end
  end
end

function S.FadeTextures(frame)
  for _, r in ipairs({ frame:GetRegions() }) do
    if r.GetObjectType and r:GetObjectType() == "Texture" then r:SetAlpha(0) end
  end
end

function S.FlatHighlight(b)
  local hl = b.GetHighlightTexture and b:GetHighlightTexture()
  if hl then
    hl:SetColorTexture(1, 1, 1, 0.12)
    hl:SetTexCoord(0, 1, 0, 1)
    hl:SetAlpha(1)
  end
end

-- (1.86.0) The hover of VoltUI's own windows on one of the game's buttons: its highlight as a
-- flat gold tint, with a gold outline. Only textures are added; nothing is written on the button.
function S.GoldHighlight(b, alpha)
  local A = S.UI.accent
  local hl = b.GetHighlightTexture and b:GetHighlightTexture()
  if hl then
    hl:SetColorTexture(A[1], A[2], A[3], alpha or S.UI.hover)
    hl:SetTexCoord(0, 1, 0, 1)
    hl:SetAlpha(1)
  end
  S.ColorEdges(S.Edges(b, "HIGHLIGHT"), A[1], A[2], A[3], 1)
end

function S.Glyph(b, text)
  local g = S.Text(b, nil, "CENTER", "OVERLAY", 13)
  g:SetPoint("CENTER", b, "CENTER", 0, 0)
  g:SetText(text)
  return g
end

-- A close or resize button: the same button, flat, with a letter.
function S.FlatButton(b, text)
  if not b then return end
  S.Fade(b:GetNormalTexture(), b:GetPushedTexture(), b:GetDisabledTexture())
  S.FlatHighlight(b)
  S.Glyph(b, text)
end

------------------------------------------------------------------------
-- Bar textures (since 1.69.0): flat, VoltUI's own (tools/make_bars.py), two of the game's, and
-- any LibSharedMedia ones other add-ons register. VoltUI's own are registered with
-- LibSharedMedia too, so other add-ons can use them.
------------------------------------------------------------------------

local MEDIA = "Interface\\AddOns\\VoltUI\\Media\\"
S.BAR_TEXTURES = {
  { key = "flat", name = "Flat", path = S.WHITE },
  { key = "voltsmooth", name = "VoltUI Smooth", path = MEDIA .. "BarSmooth" },
  { key = "voltgloss", name = "VoltUI Gloss", path = MEDIA .. "BarGloss" },
  { key = "voltsoft", name = "VoltUI Soft", path = MEDIA .. "BarSoft" },
  { key = "voltmatte", name = "VoltUI Matte", path = MEDIA .. "BarMatte" },
  { key = "voltstripes", name = "VoltUI Stripes", path = MEDIA .. "BarStripes" },
  { key = "voltglass", name = "VoltUI Glass", path = MEDIA .. "BarGlass" },
  { key = "voltobsidian", name = "VoltUI Obsidian", path = MEDIA .. "BarObsidian" },
  -- The game's two keep the keys the nameplates saved them under before 1.69.0.
  { key = "smooth", name = "Smooth (game)", path = "Interface\\TargetingFrame\\UI-StatusBar" },
  { key = "raid", name = "Raid (game)", path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
}

local function LSM() return LibStub and LibStub("LibSharedMedia-3.0", true) end

do
  local lib = LSM()
  if lib and lib.Register then
    for _, t in ipairs(S.BAR_TEXTURES) do
      if t.name:find("^VoltUI ") then pcall(lib.Register, lib, "statusbar", t.name, t.path) end
    end
  end
end

-- Every texture to pick from: { key, name, path }.
function S.BarTextures()
  local list, seen = {}, {}
  for _, t in ipairs(S.BAR_TEXTURES) do
    list[#list + 1] = t
    seen[t.name] = true
  end
  local lib = LSM()
  if lib then
    local ok, names = pcall(lib.List, lib, "statusbar")
    for _, name in ipairs(ok and type(names) == "table" and names or {}) do
      local path = not seen[name] and lib:Fetch("statusbar", name, true)
      if path then list[#list + 1] = { key = "lsm:" .. name, name = name, path = path } end
    end
  end
  return list
end

-- A texture's file. Nothing, or a name no longer there, is VoltUI's bar texture (General page);
-- "flat" is plain white.
function S.BarPath(key)
  if key == nil then key = ns.db and ns.db.barTexture end
  if key == nil or key == "flat" then return S.WHITE end
  for _, t in ipairs(S.BAR_TEXTURES) do
    if t.key == key then return t.path end
  end
  local name = type(key) == "string" and key:match("^lsm:(.+)$")
  local lib = name and LSM()
  return lib and lib:Fetch("statusbar", name, true) or S.WHITE
end

-- Bars that follow VoltUI's bar texture: set it now, and again whenever it changes.
S.texturedBars = setmetatable({}, { __mode = "k" })
function S.UseBarTexture(bar)
  if type(bar) ~= "table" or not bar.SetStatusBarTexture then return end
  S.texturedBars[bar] = true
  bar:SetStatusBarTexture(S.BarPath())
end

function S.RefreshBarTextures()
  local path = S.BarPath()
  for bar in pairs(S.texturedBars) do pcall(bar.SetStatusBarTexture, bar, path) end
end

-- Status bar with a faint track behind it, in VoltUI's bar texture.
function S.Bar(parent)
  local b = CreateFrame("StatusBar", nil, parent)
  S.UseBarTexture(b)
  b:SetMinMaxValues(0, 1)
  b:SetValue(0)
  b.bg = S.Tex(b, "BACKGROUND", -8)
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(1, 1, 1, 0.07)
  return b
end

-- Colours the fill directly, because these numbers can be secret.
function S.BarColor(bar, r, g, b)
  bar:GetStatusBarTexture():SetVertexColor(r, g, b)
end

------------------------------------------------------------------------
-- Incoming heals and shields: party and raid frames, and the player frame
------------------------------------------------------------------------

-- One heal prediction calculator, filled for each unit in turn. Heals and shields are cut
-- to the health that's missing, and the calculator says when there's more than that: the
-- overheal and over-shield glows.
S.healCalc = nil -- one calculator for every unit (a field, so a test can start a new one)
local function MakeCalc()
  local ok, made = pcall(CreateUnitHealPredictionCalculator)
  if not ok or not made then return false end
  local E = Enum or {}
  local heal = E.UnitIncomingHealClampMode and E.UnitIncomingHealClampMode.MissingHealth or 0
  local shield = E.UnitDamageAbsorbClampMode and E.UnitDamageAbsorbClampMode.MissingHealth or 0
  if made.SetIncomingHealClampMode then pcall(made.SetIncomingHealClampMode, made, heal) end
  if made.SetIncomingHealOverflowPercent then pcall(made.SetIncomingHealOverflowPercent, made, 1) end
  if made.SetDamageAbsorbClampMode then pcall(made.SetDamageAbsorbClampMode, made, shield) end
  return made
end

-- heals, shields, overheal, over-shield. The last two are true/false, secret, or nil (unknown).
-- In a fight all four can be secret, and a secret true/false can't be tested at all (no
-- `x and y`, `x or y`, `if x`, `x == nil`): they're only handed on, and checked with type().
function S.Predict(u)
  if CreateUnitHealPredictionCalculator and UnitGetDetailedHealPrediction then
    if S.healCalc == nil then S.healCalc = MakeCalc() end
    local calc = S.healCalc
    if calc and pcall(UnitGetDetailedHealPrediction, u, nil, calc) then
      local okH, heals, _, _, healOver = pcall(calc.GetIncomingHeals, calc)
      local okS, shields, shieldOver = pcall(calc.GetDamageAbsorbs, calc)
      if not okH then heals, healOver = nil, nil end -- heals held pcall's error text
      if not okS then shields, shieldOver = nil, nil end
      return heals, shields, healOver, shieldOver
    end
  end
  local heals = UnitGetIncomingHeals and UnitGetIncomingHeals(u)
  local shields = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(u)
  -- Without the calculator, worked out here when the numbers can be read.
  local healOver, shieldOver
  local cur, maxv = S.Safe(UnitHealth(u)), S.Safe(UnitHealthMax(u))
  local h, s = S.Safe(heals), S.Safe(shields)
  if cur and maxv then
    local missing = maxv - cur
    if h then healOver = h > missing end
    if s then shieldOver = s > max(0, missing - (h or 0)) end
  end
  return heals, shields, healOver, shieldOver
end

-- A bar's amount: the value, or 0 when off or unknown, without testing the value.
function S.SetAmount(bar, v, on)
  if on and (S.IsSecret(v) or type(v) == "number") then bar:SetValue(v) else bar:SetValue(0) end
end

-- A glow shown by a true/false answer, secret or not.
function S.ShowIf(tex, flag, on)
  if not on or not (S.IsSecret(flag) or type(flag) == "boolean") then
    tex:SetAlpha(0)
  elseif S.IsSecret(flag) then
    if tex.SetAlphaFromBoolean then tex:SetAlphaFromBoolean(flag, 1, 0) else tex:SetAlpha(0) end
  else
    tex:SetAlpha(flag and 1 or 0)
  end
end

------------------------------------------------------------------------
-- Saved spots
------------------------------------------------------------------------
-- A frame's top-left corner is kept against the nearest screen corner, edge or middle,
-- so it stays put when the window size or UI scale changes (windowed and back, a new
-- resolution). Three keys hold it: x, y and the screen point it hangs from. Older saves
-- have no point: they were the top-left measured from the screen's bottom-left, which
-- drifts whenever the screen changes shape, so they're rewritten the first time the
-- frame is placed.
--
-- Nothing here asks the game where a frame is or how big it is, except straight after
-- a drag. Right after SetPoint or SetSize this client still hands back the frame's old
-- rect, width and height. 1.12.1 read the rect and 1.12.2 the size, and both moved bars
-- (as if each bar were 2 pixels across). Only the corner, which VoltUI already knows, and
-- the screen's size are used.
S.SPOT_FORMAT = 3
local SPOT_KEYS = { "cast", "bag", "bank", "loot", "treasure", "map", "mapBig", "edit",
  "player", "target", "tot", "pet" }

-- Spots written by 1.12.1 and 1.12.2 came from those stale numbers, so they're dropped
-- once and those frames go back to their default spots. Old-style spots are kept.
function S.DropBadSpots(db)
  if type(db) ~= "table" or db.spotFormat == S.SPOT_FORMAT then return end
  for _, k in ipairs(SPOT_KEYS) do
    if db[k .. "Point"] ~= nil then db[k .. "Left"], db[k .. "Top"], db[k .. "Point"] = nil, nil, nil end
  end
  for _, c in pairs(type(db.barCfg) == "table" and db.barCfg or {}) do
    if type(c) == "table" and c.point ~= nil then c.left, c.top, c.point = nil, nil, nil end
  end
  db.spotFormat = S.SPOT_FORMAT
end

-- The spot for f with its top-left at left, top (in f's own units), as point, x, y. Whole
-- units, or with `exact` to a hundredth, so a nudge of one screen pixel isn't rounded away.
-- `scale` is f's scale against the screen's, for a frame whose scale was just changed.
function S.SpotFrom(f, left, top, exact, scale)
  if type(left) ~= "number" or type(top) ~= "number" then return nil end
  local s = scale or (f:GetEffectiveScale() / UIParent:GetEffectiveScale())
  local W, H = UIParent:GetWidth() / s, UIParent:GetHeight() / s
  if not (W > 0 and H > 0) then return nil end
  local px, ax, py, ay
  if left < W / 3 then px, ax = "LEFT", 0
  elseif left > W * 2 / 3 then px, ax = "RIGHT", W
  else px, ax = "", W / 2 end
  if top < H / 3 then py, ay = "BOTTOM", 0
  elseif top > H * 2 / 3 then py, ay = "TOP", H
  else py, ay = "", H / 2 end
  local point = py .. px
  if point == "" then point = "CENTER" end
  local function round(v)
    if exact then return floor(v * 100 + 0.5) / 100 end
    return floor(v + 0.5)
  end
  return point, round(left - ax), round(top - ay)
end

-- Where a dropped frame goes instead of where the drag left it: the edit mode's snap to grid
-- sets it just before the frame's own code saves the spot. { frame, left, top }
S.dropAt = nil

-- Where f sits now. Only for right after a drag, when the game has just put it there.
function S.SpotOf(f)
  local d = S.dropAt
  if d and d.frame == f then return S.SpotFrom(f, d.left, d.top, true) end
  return S.SpotFrom(f, f:GetLeft(), f:GetTop())
end

-- Where a saved spot puts f's top-left, in f's own units, worked out from the spot and the
-- screen's size alone. Nil when there's no spot saved in the current format.
function S.SpotCorner(f, t, xk, yk, pk)
  local x, y, p = t[xk], t[yk], t[pk]
  if type(x) ~= "number" or type(y) ~= "number" or type(p) ~= "string" then return nil end
  local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
  local W, H = UIParent:GetWidth() / s, UIParent:GetHeight() / s
  local ax = p:find("LEFT") and 0 or p:find("RIGHT") and W or W / 2
  local ay = p:find("BOTTOM") and 0 or p:find("TOP") and H or H / 2
  return ax + x, ay + y
end

-- Saves where f sits into t[xk], t[yk], t[pk]. True if it could.
function S.SaveSpot(f, t, xk, yk, pk)
  if ns.db then S.DropBadSpots(ns.db) end -- first, or it could drop this new spot
  local p, x, y = S.SpotOf(f)
  if not p then return false end
  t[xk], t[yk], t[pk] = x, y, p
  return true
end

function S.ClearSpot(t, xk, yk, pk)
  t[xk], t[yk], t[pk] = nil, nil, nil
end

-- Puts f at its saved spot. False if there's none, so the caller uses its default.
function S.PlaceSpot(f, t, xk, yk, pk)
  if ns.db then S.DropBadSpots(ns.db) end
  local x, y, p = t[xk], t[yk], t[pk]
  if type(x) ~= "number" or type(y) ~= "number" then return false end
  if type(p) ~= "string" then
    local np, nx, ny = S.SpotFrom(f, x, y)
    if np then
      t[xk], t[yk], t[pk] = nx, ny, np
      x, y, p = nx, ny, np
    end
  end
  f:ClearAllPoints()
  if type(p) == "string" then
    f:SetPoint("TOPLEFT", UIParent, p, x, y)
  else
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
  end
  return true
end

-- After a drag: saves the spot and re-anchors f to it, since the drag left it anchored
-- to the bottom-left corner.
function S.KeepSpot(f, t, xk, yk, pk)
  if S.SaveSpot(f, t, xk, yk, pk) then S.PlaceSpot(f, t, xk, yk, pk) end
end

-- Letting go of a dragged frame also counts as a mouse-up on its overlay. The overlays' click
-- handlers ask this first, so a drop doesn't open that frame's settings over the screen.
function S.MoverDragged(m)
  if m and m.dragged then
    m.dragged = nil
    return true
  end
  return false
end

-- Drag overlay shown while frames are unlocked. onStop(f) saves the spot.
-- opts.spot() returns the table and keys the spot is saved in (t, xk, yk, pk), so the edit
-- mode can snap a dropped frame to its grid and nudge it a pixel at a time.
S.movers = {}
function S.Mover(f, label, onStop, opts)
  local m = CreateFrame("Frame", nil, f)
  m:SetAllPoints(f)
  m:SetFrameLevel(f:GetFrameLevel() + 20)
  m:EnableMouse(true)
  m:RegisterForDrag("LeftButton")
  local fill = S.Tex(m, "OVERLAY", 5)
  fill:SetAllPoints()
  fill:SetColorTexture(S.ACCENT[1], S.ACCENT[2], S.ACCENT[3], 0.25)
  m.fill = fill
  S.ColorEdges(S.Edges(m, "OVERLAY", 6), S.ACCENT[1], S.ACCENT[2], S.ACCENT[3], 1)
  m.label = S.UIText(m, "GameFontHighlightSmall", "CENTER", "OVERLAY", 12, "OUTLINE")
  m.label:SetDrawLayer("OVERLAY", 7)
  m.label:SetPoint("CENTER")
  m.label:SetText(label)
  m.name, m.frame, m.opts = label, f, opts or {}
  -- Where it is, while it's the one picked in the edit mode.
  m.pos = S.UIText(m, "GameFontHighlightSmall", "CENTER", "OVERLAY", 11, "OUTLINE")
  m.pos:SetDrawLayer("OVERLAY", 7)
  m.pos:SetPoint("TOP", m.label, "BOTTOM", 0, -1)
  m.pos:SetTextColor(0.85, 0.9, 1)
  m.pos:Hide()
  m:SetScript("OnMouseDown", function() m.dragged = nil end)
  m:SetScript("OnDragStart", function()
    if InCombatLockdown() then return end
    f:SetMovable(true)
    f:StartMoving()
    m.dragging = true
    m.dragged = true
    if S.OnMoverDrag then S.OnMoverDrag(m, true) end
  end)
  local function drop()
    f:StopMovingOrSizing()
    m.dragging = nil
    if f.SetUserPlaced then f:SetUserPlaced(false) end
    if S.SnapDrop then S.SnapDrop(m) end
    onStop(f)
    S.dropAt = nil
    if S.OnMoverDrag then S.OnMoverDrag(m, false) end
  end
  m:SetScript("OnDragStop", drop)
  -- Combat ending Move frames hides the overlay mid-drag, and the game then never says the drag
  -- stopped: the frame would stay stuck to the mouse with its spot unsaved.
  m:SetScript("OnHide", function()
    if m.dragging then drop() end
  end)
  m:Hide()
  S.movers[#S.movers + 1] = m
  return m
end

------------------------------------------------------------------------
-- Rarity outline + inner glow
------------------------------------------------------------------------

function S.QualityRGB(q)
  if type(q) ~= "number" or (issecretvalue and issecretvalue(q)) then return nil end
  if q == 1 and not ns.db.common then return nil end
  local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  if c then return c.r, c.g, c.b end
  if C_Item and C_Item.GetItemQualityColor then return C_Item.GetItemQualityColor(q) end
end

local function Gradient(t, orientation, r, g, b, a1, a2)
  if t.SetGradient and CreateColor then
    t:SetGradient(orientation, CreateColor(r, g, b, a1), CreateColor(r, g, b, a2))
  elseif t.SetGradientAlpha then
    t:SetGradientAlpha(orientation, r, g, b, a1, r, g, b, a2)
  end
end

-- Adds the outline and glow textures over `icon` on frame `f`. Returns a glow object.
function S.Glow(f, icon, size)
  local g = { edges = S.Edges(f, "OVERLAY", 6, icon), glow = {} }
  for i = 1, 4 do
    local t = S.Tex(f, "OVERLAY", 5)
    t:SetTexture(S.WHITE)
    t:SetBlendMode("ADD")
    g.glow[i] = t
  end
  local w = g.glow
  w[1]:SetPoint("TOPLEFT", icon); w[1]:SetPoint("TOPRIGHT", icon)
  w[2]:SetPoint("BOTTOMLEFT", icon); w[2]:SetPoint("BOTTOMRIGHT", icon)
  w[3]:SetPoint("TOPLEFT", icon); w[3]:SetPoint("BOTTOMLEFT", icon)
  w[4]:SetPoint("TOPRIGHT", icon); w[4]:SetPoint("BOTTOMRIGHT", icon)
  S.GlowSize(g, size)
  return g
end

function S.GlowSize(g, size)
  local w = g.glow
  local d = max(4, floor((size or 30) * 0.34 + 0.5))
  w[1]:SetHeight(d); w[2]:SetHeight(d); w[3]:SetWidth(d); w[4]:SetWidth(d)
end

-- Outline and glow in any colour. a = 0 leaves just the outline.
function S.GlowRGB(g, r, gg, b, a)
  S.ColorEdges(g.edges, r, gg, b, 1)
  Gradient(g.glow[1], "VERTICAL", r, gg, b, 0, a)
  Gradient(g.glow[2], "VERTICAL", r, gg, b, a, 0)
  Gradient(g.glow[3], "HORIZONTAL", r, gg, b, a, 0)
  Gradient(g.glow[4], "HORIZONTAL", r, gg, b, 0, a)
  for i = 1, 4 do g.glow[i]:SetShown(a > 0) end
end

function S.GlowOff(g)
  for i = 1, 4 do
    g.edges[i]:Hide()
    g.glow[i]:Hide()
  end
end

function S.PaintGlow(g, q)
  local r, gg, b = S.QualityRGB(q)
  if r then
    S.GlowRGB(g, r, gg, b, ns.db.glow * (q == 0 and 0.6 or 1))
  else
    S.ColorEdges(g.edges, S.EDGE[1], S.EDGE[2], S.EDGE[3], 0.5)
    for i = 1, 4 do g.glow[i]:Hide() end
  end
end

-- Hide something for good, even if the game shows it again (not for protected frames).
function S.Kill(obj)
  if type(obj) ~= "table" then return end
  if obj.Hide then obj:Hide() end
  if obj.SetAlpha then obj:SetAlpha(0) end
  if obj.fuiKilled or not obj.Show then return end
  obj.fuiKilled = true
  hooksecurefunc(obj, "Show", function(self) if ns.db and ns.killing then self:Hide() end end)
end

------------------------------------------------------------------------
-- Picking a part of a settings preview (1.96.0 on the unit frames, shared since 1.97.0)
------------------------------------------------------------------------
-- A preview at the top of a settings page can have click zones over its parts. Clicking one
-- picks it for that page, and the page shows a card for that part alone above its other
-- cards (EditMode.lua, Pin). One pick is kept for each page.
--
-- parts: a list from the back to the front; where two overlap, the later one takes the
-- click. Each has key, name and region(f, ctx), which gives what the part covers and how
-- far past its edges a click still counts, or nothing while the part isn't showing. `only`
-- keeps a part to the pages named in it.

S.picked = {}

function S.Picked(key) return S.picked[key] end

function S.Pick(key, part)
  S.picked[key] = part
  local E = ns.EditMode
  if E and E.Picked then E:Picked(key) end
end

function S.PartName(parts, key)
  for _, part in ipairs(parts) do
    if part.key == key then return part.name end
  end
end

local function ZonePaint(z)
  local on = S.picked[z.key] == z.part.key
  local a = on and 1 or z.over and 0.7 or 0
  for _, t in ipairs(z.edges) do t:SetAlpha(a) end
  z.fill:SetAlpha(on and 0.16 or z.over and 0.1 or 0)
end

local function Zone(f, key, part, level)
  local z = CreateFrame("Button", nil, f.zoneBox)
  z.f, z.key, z.part = f, key, part
  z:SetFrameLevel(f.zoneBox:GetFrameLevel() + level)
  local A = S.UI.accent
  z.fill = S.Tex(z, "OVERLAY", 1)
  z.fill:SetAllPoints()
  z.fill:SetColorTexture(A[1], A[2], A[3], 1)
  z.edges = {}
  for i, at in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
    local t = S.Tex(z, "OVERLAY", 2)
    t:SetColorTexture(A[1], A[2], A[3], 1)
    t:SetPoint(at[1], z, at[1], 0, 0)
    t:SetPoint(at[2], z, at[2], 0, 0)
    if i <= 2 then t:SetHeight(1) else t:SetWidth(1) end
    z.edges[i] = t
  end
  z:SetScript("OnEnter", function(self)
    self.over = true
    ZonePaint(self)
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(self.part.name)
      GameTooltip:AddLine(S.picked[self.key] == self.part.key and "Click to let go of it." or "Click to change it.", 0.7, 0.7, 0.7)
      GameTooltip:Show()
    end
  end)
  z:SetScript("OnLeave", function(self)
    self.over = nil
    ZonePaint(self)
    if GameTooltip then GameTooltip:Hide() end
  end)
  z:SetScript("OnClick", function(self)
    S.Pick(self.key, S.picked[self.key] ~= self.part.key and self.part.key or nil)
  end)
  return z
end

-- Puts a zone over each part of preview `f` that's showing, and marks the picked one.
function S.PickZones(f, key, parts, ctx)
  if not f.zoneBox then
    f.zoneBox = CreateFrame("Frame", nil, f)
    f.zoneBox:SetAllPoints(f)
    f.zoneBox:SetFrameLevel(f:GetFrameLevel() + 8)
    f.zones = {}
  end
  for i, part in ipairs(parts) do
    local region, pad
    if not part.only or part.only[key] then region, pad = part.region(f, ctx) end
    local z = f.zones[part.key]
    if region and not z then
      z = Zone(f, key, part, i)
      f.zones[part.key] = z
    end
    if z then
      z:SetShown(region ~= nil)
      if region then
        pad = pad or 0
        z:ClearAllPoints()
        z:SetPoint("TOPLEFT", region, "TOPLEFT", -pad, pad)
        z:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", pad, -pad)
      end
      ZonePaint(z)
    end
  end
end
