-- VoltUI · Profiles
-- Named sets of settings, picked per character (since 1.49.0). Until you make a second one
-- every character uses "Default", as before.
--
-- The settings in use always sit where they always have, at the top of VoltUIDB, so no other part
-- of VoltUI knows profiles exist. A profile that isn't in use is a copy kept in VoltUIDB.profiles.
-- The swap happens once, as the add-on loads: if this character's profile isn't the one whose
-- settings are at the top, those are put away under their name and this character's are
-- brought out. So choosing another profile takes a reload.
--
-- What's been noted (the error list, say) isn't settings and is shared by every profile.

local _, ns = ...
local FUI = ns.FUI

local Pr = {}
ns.Profiles = Pr

Pr.DEFAULT = "Default"
-- Kept out of profiles: things VoltUI has learned or noted, and the profiles themselves.
local DATA = {
  profiles = true, profileOf = true, activeProfile = true, dataKeys = true,
  errorLog = true, errorSession = true, startErrors = true, spotFormat = true,
  barRepOff = true, fdbTrimmed = true, fdbWindowOff = true, fdbSaved = true, fdbHelperWasOn = true,
  blockedLog = true, setupDone = true, loginProbe = true,
  -- importUndo is not here: it holds one profile's settings, so it stays with that profile.
}
Pr.DATA = DATA

-- Another add-on's noted keys, remembered from an earlier load (Pr.AddData).
local function RememberedData(db)
  if type(db.dataKeys) ~= "table" then return end
  for k in pairs(db.dataKeys) do DATA[k] = true end
end

-- Things another add-on notes in VoltUIDB (not settings), kept out of profiles like VoltUI's own.
-- Profiles swap as VoltUI loads, before any other add-on has, so the keys are remembered in
-- VoltUIDB.dataKeys for the next load. Call it before adding defaults for them. A key that went
-- into a profile before VoltUI knew it is brought back out of every profile.
function Pr.AddData(keys, db)
  db = db or ns.db
  for _, k in ipairs(keys) do DATA[k] = true end
  if type(db) ~= "table" then return end
  db.dataKeys = type(db.dataKeys) == "table" and db.dataKeys or {}
  local profiles = type(db.profiles) == "table" and db.profiles or {}
  for _, k in ipairs(keys) do
    db.dataKeys[k] = true
    for _, snap in pairs(profiles) do
      if type(snap) == "table" and snap[k] ~= nil then
        if db[k] == nil then db[k] = snap[k] end
        snap[k] = nil
      end
    end
  end
end

local function Copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = Copy(x) end
  return t
end

-- This character, as a key: "Name-Realm".
function Pr.Char()
  local name = UnitName and UnitName("player") or nil
  if (issecretvalue and issecretvalue(name)) or type(name) ~= "string" or name == "" then name = "?" end
  local realm = GetRealmName and GetRealmName() or ""
  return name .. "-" .. tostring(realm or "")
end

-- A copy of every setting in db.
function Pr.Snapshot(db)
  local out = {}
  for k, v in pairs(db) do
    if not DATA[k] then out[k] = Copy(v) end
  end
  return out
end

-- Replaces db's settings with a snapshot's, then fills what it lacks from the defaults.
function Pr.Restore(db, snap, defaults)
  for k in pairs(db) do
    if not DATA[k] then db[k] = nil end
  end
  for k, v in pairs(snap) do
    if not DATA[k] then db[k] = Copy(v) end
  end
  for k, v in pairs(defaults or {}) do
    if db[k] == nil then db[k] = Copy(v) end
  end
end

function Pr.Init(db)
  db.profiles = type(db.profiles) == "table" and db.profiles or {}
  db.profileOf = type(db.profileOf) == "table" and db.profileOf or {}
  db.activeProfile = type(db.activeProfile) == "string" and db.activeProfile or Pr.DEFAULT
end

-- The profile a character is set to use.
function Pr.Wanted(db, char)
  local name = db.profileOf[char]
  if type(name) ~= "string" then return Pr.DEFAULT end
  if name ~= Pr.DEFAULT and name ~= db.activeProfile and db.profiles[name] == nil then return Pr.DEFAULT end -- it was deleted
  return name
end

-- As the add-on loads: brings this character's profile to the top of db. True if it swapped.
function Pr:Load(db, char, defaults)
  db = db or ns.db
  char = char or Pr.Char()
  Pr.Init(db)
  RememberedData(db)
  local want, active = Pr.Wanted(db, char), db.activeProfile
  if want == active then return false end
  db.profiles[active] = Pr.Snapshot(db)
  local snap = db.profiles[want]
  if snap then
    Pr.Restore(db, snap, defaults or FUI.defaults)
    db.profiles[want] = nil -- it's the one in use now; it's saved again when another takes over
  end
  db.activeProfile = want
  return true
end

-- Every profile's name: Default first, then the rest in order.
function Pr:List(db)
  db = db or ns.db
  Pr.Init(db)
  local seen, names = { [Pr.DEFAULT] = true }, {}
  for name in pairs(db.profiles) do
    if not seen[name] then seen[name] = true; names[#names + 1] = name end
  end
  if not seen[db.activeProfile] then names[#names + 1] = db.activeProfile end
  table.sort(names)
  table.insert(names, 1, Pr.DEFAULT)
  return names
end

-- Sets the profile this character uses. It's brought in at the next reload.
function Pr:Use(name, db, char)
  db = db or ns.db
  Pr.Init(db)
  char = char or Pr.Char()
  db.profileOf[char] = (name ~= Pr.DEFAULT) and name or nil
end

-- A new profile, starting as a copy of the settings in use. Returns its name.
function Pr:New(base, db, char)
  db = db or ns.db
  Pr.Init(db)
  base = tostring(base or "Profile")
  local name, n = base, 1
  local taken = {}
  for _, existing in ipairs(self:List(db)) do taken[existing] = true end
  while taken[name] do
    n = n + 1
    name = base .. " " .. n
  end
  db.profiles[name] = Pr.Snapshot(db)
  self:Use(name, db, char)
  return name
end

-- Removes a profile that isn't in use. Characters set to it go back to Default.
function Pr:Delete(name, db)
  db = db or ns.db
  Pr.Init(db)
  if name == Pr.DEFAULT or name == db.activeProfile or db.profiles[name] == nil then return false end
  db.profiles[name] = nil
  for char, used in pairs(db.profileOf) do
    if used == name then db.profileOf[char] = nil end
  end
  return true
end

-- Overwrites the settings in use with another profile's. A reload shows them.
function Pr:CopyFrom(name, db)
  db = db or ns.db
  Pr.Init(db)
  local snap = db.profiles[name]
  if not snap then return false end
  Pr.Restore(db, snap, FUI.defaults)
  return true
end

-- Which characters use a profile, for the settings page.
function Pr:UsedBy(name, db)
  db = db or ns.db
  Pr.Init(db)
  local out = {}
  for char, used in pairs(db.profileOf) do
    if used == name then out[#out + 1] = (char:gsub("%-.*$", "")) end
  end
  table.sort(out)
  return out
end
