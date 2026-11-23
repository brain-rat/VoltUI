-- VoltUI · Share and back up
-- Your layout and settings as one string of text: copy it to keep a back-up, or send it to someone
-- else with VoltUI, who pastes it in. You pick which parts go in, and which parts of a pasted string
-- come in. Bringing a string in keeps what it replaced, so it can be undone, then asks for a
-- reload, since the frames are built from these settings as the game starts.
--
-- The string is VoltUI's own: a plain list of values (no code is ever run from it), in letters and
-- numbers only, so it survives chat windows and forum posts, with a checksum to spot one that
-- was cut short. Only VoltUI's own settings go in; what it has learned (errors, and what other add-ons
-- note) stays yours.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style

local Sh = { export = {}, import = {} }
ns.Share = Sh

local floor, format = math.floor, string.format
local PREFIX = "VoltUI1"

------------------------------------------------------------------------
-- What can go in
------------------------------------------------------------------------

local function ModuleKeys()
  local keys = { "bank" }
  for _, m in ipairs(FUI.modules) do keys[#keys + 1] = m.key end
  return keys
end

Sh.PARTS = {
  { key = "look", name = "Fonts, bar texture, opacity and glow", keys = { "font", "fontRoles", "barTexture", "alpha", "glow", "common" } },
  { key = "layout", name = "Where everything sits" },
  { key = "frames", name = "Unit frames, castbar, buffs and timers", keys = {
    "frameCfg", "classColor", "frameScale", "castWidth", "castHeight", "castSize", "castIcon", "castTime",
    "castSpark", "castScale", "targetCast", "targetCastH", "focusCast", "castLag", "castLock", "castMirror", "castSwing",
    "buffSize", "debuffSize", "buffPerRow", "buffScale", "buffTimers", "buffTimeSize", "buffCountSize", "timerCfg" } },
  { key = "bars", name = "Action bars", keys = { "barCfg", "barRange", "barProcs", "barProcStyle" } },
  { key = "groups", name = "Party and raid frames", keys = { "raidCfg" } },
  { key = "plates", name = "Nameplates", keys = { "plateCfg" } },
  { key = "bags", name = "Bags", keys = {
    "bagCols", "bagSize", "gapX", "gapY", "sectionGap", "categories", "ilvl", "countSize", "headerSize",
    "outline", "bagScale", "questLeft", "junkKeep", "bagHeads", "bagEdge" } },
  { key = "world", name = "Minimap and map", keys = {
    "minimapScale", "mapSkin", "mapLevels", "mapPlates", "mapLabelSize", "mapDrag", "mapScale", "mapCoords",
    "stripClock", "stripMs", "stripFps", "stripDura", "stripGold", "stripMail" } },
  { key = "other", name = "Tooltips, Questie, edit mode", keys = {
    "tipIlvl", "tipVendor", "tipDrops", "questieFonts", "snap", "grid", "gridSize", "iconAngle", "errorsAll",
    "tipAnchor", "tipSize", "tipClass", "tipTarget", "tipCombat", "snapFrames", "lootScale", "lootWidth", "lootRows", "lootIlvl",
    "chatAlpha", "linkSite", "uiText", "editShape", "editH" } },
  { key = "parts", name = "Which parts of VoltUI are on", keys = ModuleKeys },
}
for _, p in ipairs(Sh.PARTS) do Sh.export[p.key] = true end

-- Settings another add-on keeps in VoltUIDB, backed up with one of the parts above.
function Sh.AddKeys(partKey, keys)
  for _, p in ipairs(Sh.PARTS) do
    if p.key == partKey and type(p.keys) == "table" then
      for _, k in ipairs(keys) do
        local have = false
        for _, x in ipairs(p.keys) do if x == k then have = true end end
        if not have then p.keys[#p.keys + 1] = k end
      end
      return true
    end
  end
  return false
end

local function Keys(part)
  return type(part.keys) == "function" and part.keys() or part.keys or {}
end

local function Copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = Copy(x) end
  return t
end

-- A frame's saved spot: kept in keys ending Left, Top and Point.
local function IsSpotKey(k, v)
  if type(k) ~= "string" then return false end
  if not (k:find("Left$") or k:find("Top$") or k:find("Point$")) then return false end
  return type(v) == "number" or type(v) == "string"
end
local BAR_SPOT = { "left", "top", "point" }

-- The current values of one part.
function Sh:Collect(key)
  local db = ns.db
  if key == "layout" then
    local out = { db = {}, bars = {}, spotFormat = db.spotFormat }
    for k, v in pairs(db) do
      if IsSpotKey(k, v) then out.db[k] = v end
    end
    for bar, c in pairs(type(db.barCfg) == "table" and db.barCfg or {}) do
      if type(c) == "table" and c.point ~= nil then
        out.bars[bar] = { left = c.left, top = c.top, point = c.point }
      end
    end
    return out
  end
  local part
  for _, p in ipairs(self.PARTS) do if p.key == key then part = p end end
  local out = {}
  for _, k in ipairs(Keys(part)) do out[k] = Copy(db[k]) end
  if key == "bars" and type(out.barCfg) == "table" then
    -- Where the bars sit belongs to the layout.
    for _, c in pairs(out.barCfg) do
      if type(c) == "table" then
        for _, s in ipairs(BAR_SPOT) do c[s] = nil end
      end
    end
  end
  return out
end

------------------------------------------------------------------------
-- The string: values, then letters and numbers
------------------------------------------------------------------------

local function Ser(v, out, depth)
  local t = type(v)
  if t == "string" then
    out[#out + 1] = "s" .. #v .. ":" .. v
  elseif t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then v = 0 end
    out[#out + 1] = "n" .. format("%.17g", v) .. ";"
  elseif t == "boolean" then
    out[#out + 1] = v and "T" or "F"
  elseif t == "table" then
    if depth > 12 then return end
    out[#out + 1] = "{"
    local keys = {}
    for k in pairs(v) do
      if type(k) == "string" or type(k) == "number" then keys[#keys + 1] = k end
    end
    table.sort(keys, function(a, b)
      if type(a) == type(b) then return a < b end
      return type(a) == "number"
    end)
    for _, k in ipairs(keys) do
      local x = v[k]
      local tx = type(x)
      if tx == "string" or tx == "number" or tx == "boolean" or tx == "table" then
        Ser(k, out, depth)
        Ser(x, out, depth + 1)
      end
    end
    out[#out + 1] = "}"
  end
end

function Sh.Serialize(v)
  local out = {}
  Ser(v, out, 0)
  return table.concat(out)
end

-- Back to values. Nil for anything that isn't exactly what Serialize writes.
function Sh.Deserialize(s)
  local pos, n = 1, #s
  local function val(depth)
    if depth > 14 then error("too deep") end
    local c = s:sub(pos, pos)
    if c == "s" then
      local colon = s:find(":", pos, true)
      local len = colon and tonumber(s:sub(pos + 1, colon - 1))
      if not len or len < 0 then error("bad text") end
      local str = s:sub(colon + 1, colon + len)
      if #str ~= len then error("cut short") end
      pos = colon + len + 1
      return str
    elseif c == "n" then
      local semi = s:find(";", pos, true)
      local num = semi and tonumber(s:sub(pos + 1, semi - 1))
      if not num then error("bad number") end
      pos = semi + 1
      return num
    elseif c == "T" or c == "F" then
      pos = pos + 1
      return c == "T"
    elseif c == "{" then
      pos = pos + 1
      local t = {}
      while s:sub(pos, pos) ~= "}" do
        if pos > n then error("cut short") end
        local k = val(depth + 1)
        if type(k) ~= "string" and type(k) ~= "number" then error("bad key") end
        t[k] = val(depth + 1)
      end
      pos = pos + 1
      return t
    end
    error("bad value")
  end
  local ok, v = pcall(val, 0)
  if not ok or pos ~= n + 1 then return nil end
  return v
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DEC = {}
for i = 1, 64 do DEC[B64:byte(i)] = i - 1 end

local function Char(i) return B64:sub(i + 1, i + 1) end

function Sh.Encode(s)
  local out = {}
  for i = 1, #s, 3 do
    local a, b, c = s:byte(i, i + 2)
    local v = a * 65536 + (b or 0) * 256 + (c or 0)
    out[#out + 1] = Char(floor(v / 262144) % 64) .. Char(floor(v / 4096) % 64)
      .. (b and Char(floor(v / 64) % 64) or "=") .. (c and Char(v % 64) or "=")
  end
  return table.concat(out)
end

function Sh.Decode(s)
  if #s % 4 ~= 0 then return nil end
  local out = {}
  for i = 1, #s, 4 do
    local a, b, c, d = s:byte(i, i + 3)
    local va, vb = DEC[a], DEC[b]
    local vc, vd = c ~= 61 and DEC[c] or nil, d ~= 61 and DEC[d] or nil
    if not va or not vb or (c ~= 61 and not vc) or (d ~= 61 and not vd) or (c == 61 and d ~= 61) then return nil end
    local v = va * 262144 + vb * 4096 + (vc or 0) * 64 + (vd or 0)
    out[#out + 1] = string.char(floor(v / 65536) % 256)
    if vc then out[#out + 1] = string.char(floor(v / 256) % 256) end
    if vd then out[#out + 1] = string.char(v % 256) end
  end
  return table.concat(out)
end

local function Sum(s)
  local a, b = 1, 0
  for i = 1, #s do
    a = (a + s:byte(i)) % 65521
    b = (b + a) % 65521
  end
  return format("%04x%04x", b, a)
end

-- The string for these parts (a set of part keys).
function Sh:Make(pick)
  local data = { v = 1, volt = ns.Errors and ns.Errors.Version() or "?", made = date and date("%Y-%m-%d") or "", parts = {} }
  for _, p in ipairs(self.PARTS) do
    if pick[p.key] then data.parts[p.key] = self:Collect(p.key) end
  end
  local body = self.Serialize(data)
  return PREFIX .. ":" .. self.Encode(body) .. ":" .. Sum(body)
end

-- What a pasted string holds, or nil and why not.
function Sh:Read(text)
  text = (text or ""):gsub("%s", "")
  if text == "" then return nil, "" end
  local tag, code, sum = text:match("^(%w+):([%w%+/=]+):(%x+)$")
  if tag ~= PREFIX then
    if text:find("^VoltUI%d") then return nil, "That string is from a newer VoltUI. Update VoltUI, then paste it again." end
    return nil, "That isn't a VoltUI string. Copy the whole thing, from VoltUI1: to the end."
  end
  local body = self.Decode(code)
  if not body or Sum(body) ~= sum:lower() then
    return nil, "That string looks cut short or changed. Copy the whole thing again."
  end
  local data = self.Deserialize(body)
  if type(data) ~= "table" or data.v ~= 1 or type(data.parts) ~= "table" then
    return nil, "That string couldn't be read."
  end
  return data
end

------------------------------------------------------------------------
-- Bringing one in
------------------------------------------------------------------------

-- A setting as an import would write it: the string's value, or the default when the string
-- doesn't have it (as after a reload) or has one of the wrong kind (a string edited by hand, or
-- made by another version: the part that owns it would fail on it at every login).
local function Incoming(got, k)
  local v, d = Copy(got[k]), FUI.defaults[k]
  if v ~= nil and d ~= nil and type(v) ~= type(d) then v = nil end
  if v ~= nil and d == nil and k:find("Cfg$") and type(v) ~= "table" then v = nil end
  if v == nil then v = Copy(d) end
  return v
end

-- How many single values differ between two settings (tables are gone through, value by value).
local function Diff(a, b)
  local ta, tb = type(a) == "table", type(b) == "table"
  if ta and tb then
    local n = 0
    for k, v in pairs(a) do n = n + Diff(v, b[k]) end
    for k, v in pairs(b) do if a[k] == nil then n = n + Diff(nil, v) end end
    return n
  end
  if ta or tb then
    local n = 0
    for _, v in pairs(ta and a or b) do n = n + Diff(v, nil) end
    return n
  end
  if a == b then return 0 end
  if type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-9 then return 0 end
  return 1
end

-- Before anything is brought in (1.80.0): how many of a part's settings in `data` differ from
-- yours now. Nil when the string doesn't hold that part.
function Sh:Differs(data, key)
  local got = type(data) == "table" and type(data.parts) == "table" and data.parts[key]
  if type(got) ~= "table" then return nil end
  local mine = self:Collect(key)
  if key == "layout" then
    return Diff({ db = mine.db, bars = mine.bars },
      { db = type(got.db) == "table" and got.db or {}, bars = type(got.bars) == "table" and got.bars or {} })
  end
  local part
  for _, p in ipairs(self.PARTS) do if p.key == key then part = p end end
  local n = 0
  for _, k in ipairs(Keys(part)) do n = n + Diff(mine[k], Incoming(got, k)) end
  return n
end

-- The preview's words: each part the string holds, with how much of it differs from yours.
function Sh:Preview(data)
  local differ, same = {}, {}
  for _, p in ipairs(self.PARTS) do
    local n = self:Differs(data, p.key)
    if n and n > 0 then
      differ[#differ + 1] = ("%s: %d"):format(p.name, n)
    elseif n then
      same[#same + 1] = p.name
    end
  end
  local out = {}
  if #differ > 0 then out[#out + 1] = "Settings that differ from yours. " .. table.concat(differ, " · ") .. "." end
  if #same > 0 then out[#out + 1] = "The same as yours: " .. table.concat(same, " · ") .. "." end
  if #out == 0 then return "This string holds no settings." end
  return table.concat(out, "\n")
end

-- Writes the chosen parts of `data` into VoltUI's settings, after keeping what they replace.
function Sh:Apply(data, pick, keepUndo)
  local db = ns.db
  local undo = { v = 1, parts = {} }
  local layout = pick.layout and type(data.parts.layout) == "table" and data.parts.layout
  for _, p in ipairs(self.PARTS) do
    local got = data.parts[p.key]
    if pick[p.key] and type(got) == "table" then undo.parts[p.key] = self:Collect(p.key) end
  end
  -- Parts first, then where things sit, so the bars' spots from the layout win.
  for _, p in ipairs(self.PARTS) do
    local got = data.parts[p.key]
    if pick[p.key] and p.key ~= "layout" and type(got) == "table" then
      local spots = {}
      if p.key == "bars" then
        for bar, c in pairs(type(db.barCfg) == "table" and db.barCfg or {}) do
          if type(c) == "table" then spots[bar] = { left = c.left, top = c.top, point = c.point } end
        end
      end
      -- A setting the string doesn't have goes back to its default, as it would after a reload.
      for _, k in ipairs(Keys(p)) do db[k] = Incoming(got, k) end
      if p.key == "bars" and type(db.barCfg) == "table" then
        for bar, s in pairs(spots) do
          local c = db.barCfg[bar]
          if type(c) == "table" then c.left, c.top, c.point = s.left, s.top, s.point end
        end
      end
    end
  end
  if layout then
    for k, v in pairs(db) do
      if IsSpotKey(k, v) then db[k] = nil end
    end
    for k, v in pairs(type(layout.db) == "table" and layout.db or {}) do
      if IsSpotKey(k, v) then db[k] = v end
    end
    db.barCfg = type(db.barCfg) == "table" and db.barCfg or {}
    for _, c in pairs(db.barCfg) do
      if type(c) == "table" then c.left, c.top, c.point = nil, nil, nil end
    end
    for bar, s in pairs(type(layout.bars) == "table" and layout.bars or {}) do
      if type(bar) == "string" and type(s) == "table" then
        local c = db.barCfg[bar] or {}
        db.barCfg[bar] = c
        for _, key in ipairs(BAR_SPOT) do
          local v = s[key]
          if type(v) == "number" or type(v) == "string" then c[key] = v end
        end
      end
    end
    if type(layout.spotFormat) == "number" then db.spotFormat = layout.spotFormat end
  end
  if keepUndo then db.importUndo = undo end
  FUI:NeedReload()
end

-- What's pasted in the Import box, brought in.
function Sh:Import()
  if not self.pasted then return end
  local pick = {}
  for _, p in ipairs(self.PARTS) do
    pick[p.key] = self.import[p.key] ~= false and self.pasted.parts[p.key] ~= nil
  end
  self:Apply(self.pasted, pick, true)
  self.done = "Brought in. Reload to see it."
end

function Sh:Undo()
  local undo = ns.db.importUndo
  if type(undo) ~= "table" or type(undo.parts) ~= "table" then return end
  local pick = {}
  for k in pairs(undo.parts) do pick[k] = true end
  self:Apply(undo, pick, false)
  ns.db.importUndo = nil
  self.done = "Put back as it was before. Reload to see it."
end

------------------------------------------------------------------------
-- The page
------------------------------------------------------------------------

function Sh:IO()
  return {
    get = function(def)
      if def.store == "export" then return Sh.export[def.key] ~= false end
      if def.store == "import" then return Sh.import[def.key] ~= false end
    end,
    set = function(def, v)
      if def.store == "export" then Sh.export[def.key] = v end
      if def.store == "import" then Sh.import[def.key] = v end
    end,
    changed = function() end,
  }
end

local function Has(key) return function() return Sh.pasted ~= nil and Sh.pasted.parts[key] ~= nil end end

function Sh:Sections()
  local out, into
  local export = {
    title = "Export",
    { kind = "note", lines = 3, text = "Pick what goes in, then make the string. Keep it as a back-up, or send it: anyone with VoltUI can paste it on the Import card." },
  }
  local import = {
    title = "Import",
    { kind = "note", lines = 2, text = "Paste a VoltUI string in the box (Ctrl+V). You'll see what's in it before anything changes." },
    { kind = "custom", height = 100, build = function(r, width)
      into = S.TextBox(r, width - 2 * S.INSET, 94, { hint = "Paste here", onChange = function(text)
        Sh.pasted, Sh.problem = Sh:Read(text)
        Sh.done = nil
        ns.EditMode:RefreshPage()
      end })
      into:SetPoint("TOPLEFT", S.INSET, -3)
      Sh.into = into
    end },
    { kind = "note", lines = 2, text = function()
      if Sh.done then return Sh.done end
      local d = Sh.pasted
      if d then
        return ("From VoltUI %s, made %s. Pick what to bring in:"):format(tostring(d.volt or "?"), tostring(d.made or "?"))
      end
      return Sh.problem ~= "" and Sh.problem or "Nothing pasted yet."
    end },
    -- how the string differs from what you have, part by part, before you bring any of it in
    { kind = "custom", label = "", height = 66, keywords = "preview differ compare changes",
      build = function(r, width)
        r.preview = S.UIText(r, nil, "LEFT", "OVERLAY", 11)
        r.preview:SetPoint("TOPLEFT", S.INSET, -4)
        r.preview:SetWidth(width - 2 * S.INSET)
        r.preview:SetHeight(58)
        if r.preview.SetJustifyV then r.preview:SetJustifyV("TOP") end
        if r.preview.SetWordWrap then r.preview:SetWordWrap(true) end
        r.preview:SetTextColor(S.UI.hint[1], S.UI.hint[2], S.UI.hint[3])
      end,
      refresh = function(r)
        if not r.preview then return end
        if Sh.pasted and not Sh.done then
          r.preview:SetText(Sh:Preview(Sh.pasted))
        else
          r.preview:SetText(Sh.done and "" or "Once a string is pasted, this says how many settings in each part differ from yours.")
        end
      end },
  }
  for _, p in ipairs(self.PARTS) do
    export[#export + 1] = { kind = "toggle", label = p.name, key = p.key, store = "export" }
    import[#import + 1] = { kind = "toggle", label = p.name, key = p.key, store = "import", when = Has(p.key) }
  end
  export[#export + 1] = { kind = "button", label = "", text = "Make the string", primary = true, fn = function()
    out:SetText(Sh:Make(Sh.export))
    out:Select()
  end }
  export[#export + 1] = { kind = "custom", height = 100, build = function(r, width)
    out = S.TextBox(r, width - 2 * S.INSET, 94, { readOnly = true, hint = "The string shows here." })
    out:SetPoint("TOPLEFT", S.INSET, -3)
    Sh.out = out
  end }
  export[#export + 1] = { kind = "note", lines = 1, text = "Click in the box, then Ctrl+C to copy." }
  import[#import + 1] = { kind = "button", label = "", text = "Bring it in", primary = true,
    when = function() return Sh.pasted ~= nil and not Sh.done end, fn = function() Sh:Import() end }
  import[#import + 1] = { kind = "button", label = "Undo the last import", text = "Undo",
    when = function() return type(ns.db.importUndo) == "table" end, fn = function() Sh:Undo() end }
  return { export, import }
end
