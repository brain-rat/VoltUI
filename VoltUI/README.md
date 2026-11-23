# VoltUI

A flat, dark look for the game's own windows. It's built as the base for a bigger UI overhaul: every part uses the same shared style (`Style.lua`), so more windows can be added and they'll all match.

So far it covers the player and target frames, the party and raid frames, nameplates, the castbar, action bars, your bags and bank, the loot window, tooltips, junk selling, the minimap and the world map. If you use the Questie add-on, it gets the same look.

Every setting is in one window: type **`/volt`**, or click the minimap icon and choose **Settings**. See [The settings window](#the-settings-window).

## Player and target frames

Since 1.96.0 you can **click a part of the frame in the preview** on its settings page to get that part's settings (font size, place, side, nudges) together in one card at the top. Since 1.95.0 the player frame has **class extras** (Player page): a thin **mana bar while shapeshifted**, a **regen tick** spark on the power bar (an experiment, off to begin with), and two **extra texts** you can set to anything your class uses, such as Soul Shards, ammo, a reagent count or combo points, or to health, mana, name or level, and place below or above the frame at the left or right. The pet frame has an **experience line** for a hunter's pet and, since 1.95.1, one **extra text** of its own, which shows a hunter pet's mood (Happy, Content, Unhappy) unless you change it.

Since 1.47.0 there's a **focus frame** too, with its own **Focus** tab on the Unit frames page: smaller than the player and target frames, starting up and to the left of the player frame, with the same settings as the others and its own cast bar above it (as tall as the target frame's; *Cast bar: Show* on its tab). The game's own focus frame is put away. Set a focus with `/focus` or a click bound to Focus.

Since 1.46.0 each frame's **Health** card has **Numbers show**: *Now / most* (2,480 / 4,000, as before), *Now*, or *Missing* (-1,520, and nothing at full health), and **Shorten big numbers** (12.5K) for health and power. The **Power** card has the same choice, with *Percent* in place of *Missing*.

Flat frames in the shared style replace Blizzard's player, target, target-of-target and pet frames.

- **Header strip:** name, level and status. Your name is in the accent colour. A target's name and health bar use its reaction colour: red hostile, yellow neutral, green friendly, grey if someone else has tagged it.
- **Status tags:** Combat, Rested, Lead and PvP on you. Elite, Rare, Rare Elite, Boss and PvP on your target. A raid marker shows next to the name.
- **Health bar:** percent on the left, `current / max` on the right, or Dead, Ghost or Offline. Players use their class colour (`/volt frames class` for plain green).
- **Incoming heals and shields** (since 1.29.0) show on your health bar as their own parts, straight after your health and up to full, like on VoltUI's party and raid frames: green for heals on their way, white for shields. A bright edge at the end of the bar lights up when more heals are coming than health is missing, and a white one for shields past full. On by default for the player frame; the target, target-of-target and pet frames have it too, off by default. Switch it on each frame's page (*Health*, **Incoming heals and shields**).
- **Power bar:** in that power's colour, with `current / max`.
- **Clicks:** left-click targets, right-click opens the game's unit menu. Click-cast add-ons can see the frames.
- **Target's buffs and debuffs** sit above its frame, debuffs first, up to 16. Debuff borders show the dispel type, and your own are in the accent colour.
- **Combo points** are five pips under the player frame. Rogues always have them, and Druids see them while they have points.
- **Totems:** Blizzard's totem frame is kept and sits above the player frame. It keeps Blizzard's look for now.
- **Elites, rares and bosses** get a coloured border and soft glow on the target frame: gold for elites, silver-blue for rares, red for bosses.
- Portraits are off by default. Turn them on in the settings (`/volt`, then the frame's page).

## Party and raid frames

Since 1.47.0 a tile also shows its **raid marker** (top middle), a mark on the group's **leader** (top right), each member's answer during a **ready check** (a tick, cross or question mark, which stays a few seconds after the check ends), and **Res coming** or **Summon** across the middle while a resurrection is on its way or a summon is waiting. Each has a switch on the *Borders and icons* card.

Since 1.25.0, VoltUI has its own party and raid frames in place of the game's, with everything set in VoltUI. Since 1.26.0 they have a heal mode with its own settings, and click-casting. Since 1.28.0 party frames and raid frames have their own settings, and so does heal mode for each. The game's party and raid frames are hidden while VoltUI's are on. Switch the part off (**Party frames** or **Raid frames** page, or `/volt groups off`) and `/reload` to get the game's own back, untouched.

Each member gets a tile, up to 40:

- **Health**, in class colour, green, a colour you pick, or dark (with the class colour showing the health that's missing). **Incoming heals** and **shields** show as their own parts of the bar, up to full health. **Overhealing** (more heals coming than health missing) lights up the end of the bar, and a white edge shows shields past full health. The text can show missing health (-1634, empty at full health) or a percent, or nothing.
- **Power** (mana, rage, energy) under the health bar, for healers only, for everyone, or off.
- **Name** (without the realm) and **role icon**. **Dead**, **Ghost** and **Offline**, with offline members in grey.
- **Borders**: blue or white on your target, white under the mouse, and a red glow on anyone with aggro.
- **Fading** when someone is out of range. For a priest, paladin, druid or shaman that's your heal's range; anyone else gets the game's own range check.
- **Debuffs** along the bottom. The ones you can remove come first, framed in their type's colour (blue Magic, purple Curse, brown Disease, green Poison) and bigger if you like; the rest follow with a dark frame. VoltUI asks the game which ones you can remove, and also checks the debuff's type against your own dispel spells, because the game misses some for Forever's spells. Each shows its time left and stacks.
- Clicking a tile targets that member; right-click opens their menu.

Raid groups sit in columns or rows, with a title over each group that has someone in it. A party sits in a column or a row; you can show yourself or not, and the frames can show when you're alone.

### Settings

Party frames and raid frames each have their own settings, on the **Party frames** and **Raid frames** pages of the settings (`/volt`, or **`/volt groups options`**, which opens the one for the frames you have up). In a party, or alone, the party frames' settings are used; in a raid, the raid frames'. Joining or leaving a raid in the middle of a fight switches them when it ends.

Settings from before 1.28.0, when party and raid shared one set, are copied to both, so nothing looks different until you change one. **Copy from...** brings settings over from any of the other sets (the other page's, or either of heal mode's).

Changes show on the frames as you make them; ones that change the frames' size or layout wait until you're out of combat, because the game locks secure frames during a fight. **Reset** puts the page back; `/volt groups reset` puts all four sets back.

| Card | Setting | Options |
|---|---|---|
| Preview | Show | Party page: **Off** or **On** (a made-up party). Raid page: **Off**, or **10**, **25** or **40** made-up members, where your frames go |
| Size and layout | Width, height | 30 to 200, and 16 to 100 |
| | Gap between members | 0 to 12 |
| | Gap between groups (raid page) | 0 to 40 |
| | Scale | 0.5 to 2 |
| | Members in a (party page) | **Column** or **Row** |
| | Raid groups as (raid page) | **Columns** or **Rows** |
| | Order | The **Group** order, **Role** (tanks, healers, damage), **Class** or **Name** |
| | Show yourself, show when you're alone (party page) | On or off |
| | Party title, group titles | On or off |
| Health | Colour | **Class**, **Green**, **Dark** or **Pick** (your own colour, set on the row under it; right-click puts it back) |
| | Missing health shade | How much the empty part of the bar shows (not in the dark style) |
| | Health text | **Off**, **Missing** or **Percent** |
| | Incoming heals, shields, overhealing | On or off |
| | Out of range opacity | 0.1 to 1 |
| Power | Power bar | **Off**, **Healers** or **Everyone** |
| | Height | 2 to 14 |
| Text | Name size, status text size | 0.6 to 2 times |
| | Name colour | White or class colour |
| Borders and icons | Your target | Blue, white, or off |
| | Aggro glow, under the mouse, role icons | On or off |
| Debuffs | Debuffs on the frames | On or off |
| | Size, how many | 8 to 32, and 1 to 6 |
| | Ones you can remove first, only ones you can remove, bigger when you can remove it | On or off |
| HoTs and shields | Your HoTs and shields | On or off: your own heals over time and shields on each member, bottom right, with their time left |
| | Size, how many | 8 to 24, and 1 to 5 |
| | Earth Shield and Fear Ward | On or off: an icon in the top right corner while a member has one, from anyone |
| Party and raid frames | VoltUI's party and raid frames | On or off (takes a reload) |

Settings saved by the old skin of the game's frames (1.24 and before) are moved over once: health colour, missing health shade, out of range opacity, text sizes and colour, borders, role icons and group titles.

### Heal mode

Heal mode switches the frames to settings made for healing, with one set for party frames and one for raid frames. While it's on, party frames use its party set and raid frames its raid set. Both start out with bigger tiles (84 by 42), missing health shown, everyone's power bar, four debuffs at a larger size with the ones you can remove first and bigger, and a stronger out-of-range fade. The **Heal mode** page is kept short, with just what matters for healing. Its **Settings for** row picks which set the page changes: **Party** or **Raid** (the **Heal mode's settings** link on the Party frames and Raid frames pages opens the matching one).

- **Clicks**: what ten clicks on a member cast: left, right, Shift, Ctrl and Alt with each, middle and Shift+Middle. Each click has a slot showing its spell's icon and name. Click a slot to pick from your healing spells; right-click it to clear it. **More clicks, macros** opens the Clicks page.
- **Frames**: a preview, width, height and scale.
- **Health**: health text, colour, incoming heals and shields (one switch), overhealing, out of range opacity and the power bar.
- **Debuffs**: only the ones you can remove, bigger when you can remove them, and their size, with a link to the **Dispels** page.
- **HoTs and shields**: your own on each member with their time left, their size, and the Earth Shield and Fear Ward corner icons.

**Show every setting** at the bottom swaps in the full list, the same as the **Party frames** or **Raid frames** page but for heal mode's set. **Copy from...** brings settings over from any of the other three sets, and **Reset** puts back the set the page shows.

- **Heal mode**: **Off**, **Auto** (the default: on while your group role is healer) or **On**.
- Switch it from the **Heal mode** page, the minimap icon's menu, or `/volt heal` (on if it's off, off if it's on). `/volt heal on`, `off` and `auto` set it.
- It never switches in the middle of a fight, because the frames would change size. It switches as soon as the fight ends.

### Click-casting

Since 1.46.0 a click that the game's own click casting also uses gets an **orange edge** on the Clicks page, and hovering it says what the game has there: the game's binding wins, so VoltUI's would do nothing until you change or remove the game's.

The **Clicks** page (`/volt heal clicks`) sets what each click on a member does: the left, right and middle buttons and mouse buttons 4 and 5, alone or with Shift, Ctrl, Alt, Ctrl+Shift, Alt+Shift or Ctrl+Alt. That's 35 clicks.

- **Every click** shows all 35 as a grid: the five buttons across, and down the side the click alone and with each key held. Each slot shows its spell's icon and name, or what the click does.
  - Click a slot to open the list of **your healing spells**, each with its icon. Pick one and the click casts it. The list also has **Target**, **Menu** and **Clear**.
  - The list holds only healing spells from your spellbook: spells that help and are cast on someone else (heals, shields, cleanses, buffs, resurrection), including a server's own. It leaves out damage spells, buffs only you can have, passives, and the other spec's spells. A spell with ranks shows once.
  - Right-click a slot to clear it. A cleared click does what it does without VoltUI: left targets, right opens the menu, the others do nothing.
  - Spells are cast by name, so you always get your highest rank, and a spell you haven't learned yet starts working when you learn it.
- **Edit a click** is for the rest. The slot last opened in the grid is picked, or choose one with the *Button* and *With* rows. Then choose what it **Does**:
  - **Spell** casts one of your healing spells, chosen on the *Spell* row.
  - To cast a set rank, type it in the box, for example `Heal(Rank 2)`.
  - **Target**, **Menu** and **Focus** do what they say.
  - **Macro** runs the text in the box.
  - **Nothing** makes the click do nothing at all.
- **Ready-made clicks** for priests, paladins, druids and shamans. A priest gets:
  - Flash Heal on left-click and Renew on right-click;
  - Power Word: Shield on Ctrl+Left and Greater Heal on Ctrl+Right;
  - Dispel Magic on middle-click and Abolish Disease (or Cure Disease) on Shift+Middle;
  - Resurrection on Alt+Left.
  
  Paladins, druids and shamans get their own heals, dispels and resurrection on the same clicks. Everyone gets Shift+Left to target and Shift+Right for the menu. **Use them** on the page, or **Reset**, puts them back.
- **Clicks work**: **In heal mode** (the default) or **Always**. Outside of that, a click targets and a right-click opens the menu.
- Clicks are set on the frames out of combat. A change made in a fight is put in place when it ends. Someone who joins mid-fight gets your clicks straight away.
- If the game's own click casting (its Click Casting options) has a click set, it wins over VoltUI's on that click, and the page says how many it has.
- For a key rather than a click, the page shows a mouseover macro with your own spell to copy, like `/cast [@mouseover,help,nodead][] Flash Heal`.

### Dispels

The **Dispels** page (`/volt heal dispel`) has two extras for removing debuffs. Each works **In heal mode** (the default), **Always**, or is **Off**.

- **Dispel windows**: a small square for each member. A square shows only while its member has a debuff you can remove. It shows that debuff's icon in its type's colour, and the member's name.
  - Left-click a square to cast your first dispel on that member, and right-click for your second. A priest gets Dispel Magic and Abolish Disease (or Cure Disease); a shaman, Cure Poison and Cure Disease; a druid, Remove Curse and Abolish Poison (or Cure Poison). A paladin gets Cleanse (or Purify), and a mage Remove Lesser Curse, on left-click only. The page says which spells yours are.
  - The squares keep their places in a fight and work in one. Size: 20 to 60.
  - An empty square is see-through but still takes clicks, so put the squares away from where you click the world.
  - With no dispel spell learned, the squares stay away.
- **Warning**: a large line when someone gets a debuff you can remove. It shows the debuff's icon, who has it, its name and which click removes it: your click on the frames that casts the right dispel (for example *Middle-click*), else the dispel window's. In a fight the game can hide the debuff's type, and then it names any of your dispel clicks.
  - **Sound**: **Raid warning**, **Ready check**, **Alarm** or **None**, at most every two seconds.
  - **Size**: 0.6 to 2. **Test** shows a made-up warning with its sound.
  - It comes once per new debuff, and fades after four seconds.
- **Move the windows and the warning** starts moving frames. While moving, the warning shows made-up text so it can be placed.

### Moving them

`/volt edit` (or **Move frames** in the settings) shows a box over them; drag it, or nudge it with the arrow keys and the grid, like any other VoltUI frame. Not in combat. Since 1.33.0 the box over the dispel windows covers every row your group fills: one row for a party, up to eight for a raid of 40.

### Preview

You don't need a group to see what the settings do. The **Preview** row shows the set its page changes: a party on a party page, a raid on a raid page. **`/volt groups test`** (`5` for a party, `10`, `25` or `40` for a raid, or `off`) uses the settings in use. Either shows made-up members right where your frames go, with the real ones out of the way meanwhile: you first, then a tank with aggro, your target, someone out of range, someone dead, someone offline, a few with debuffs you can and can't remove, incoming heals and shields. Every setting shows on them straight away.

- They're VoltUI's plain frames, not secure ones: clicking them does nothing.
- Opened from the settings page, it closes with the settings window. Opened with the command, it stays until `/volt groups test` again. A fight closes it either way.

## Nameplates

The game's own nameplates, on every unit (enemies, friends, NPCs and players), in VoltUI's look. They stay the game's nameplates, so which units get one, how big they are, their style, what the cast bar shows (spell name, icon, target), which auras show and how they stack all still come from the game's options (Options > Interface > Nameplates).

- The health bar goes flat (or takes a texture you pick) on a dark track with a thin border. Its colours are VoltUI's and yours to change: hostile red, neutral gold, friendly green, friendly players blue and tapped mobs grey, with class colours on players and optional tank or damage threat colours. The game's own threat colours and anything else it picks pass through.
- Health text as a percent, a number, or both, on the left, in the centre or on the right. Or the game's own.
- Your target gets a blue border with a faint ring around it, and your focus an orange one. Anything that's after you gets an outer ring in the threat colour, in place of the game's aggro flare. While you have a target, the other plates dim a little. The border can be 1 to 4 screen pixels thick.
- Enemy plates and friendly plates have a set of settings each, and your target can stand out with its own health text, bar height, border and name size.
- The cast bar goes flat in VoltUI's castbar colours, which you can change: blue for casts, green for channels, grey when it can't be interrupted, red when it's stopped. The spell icon is square with a thin border. It can show the time left.
- Aura icons go square with a thin border in the debuff type's colour (Magic blue, Curse purple, and so on). Debuffs, buffs and crowd control can each be sized, and the timer numbers, stack counts and dark swipe changed.
- The level box and all the text go flat, with VoltUI's font and an outline. Names can be the game's colour, white, or class coloured.
- Text follows `/volt font`.
- Another nameplate add-on (Platynator, Plater, KuiNameplates, Threat Plates, NeatPlates) draws its own plates over the game's, so VoltUI leaves them alone while one is loaded and says so in chat once. Turn the other add-on off to get VoltUI's.
- Friendly nameplates inside dungeons and raids are locked away from add-ons by the game, so those keep the game's look.
- `/volt nameplates off` and `/reload` gives you the game's look back.

### Settings

Open them with **`/volt nameplates options`**, or the settings (`/volt`). There are three pages under **Nameplates**:

- **Enemy plates**: anything you can attack (hostile and neutral units, enemy players).
- **Friendly plates**: friendly characters and players. Inside dungeons and raids the game keeps these to itself.
- **Your target**: how your target's plate stands out, on top of its enemy or friendly settings.

A plate moves to the other set by itself when its unit turns hostile or friendly. Changes show on the nameplates around you as you make them, in combat too. **Reset** on a page puts that page back; `/volt nameplates reset` puts every page back. **Copy from...** gives one kind of plate the other's settings.

Colours are swatches. Click one to open the game's colour picker (Cancel puts the colour back), or right-click it for VoltUI's default. Hover a swatch to see what it's for.

**Enemy plates** and **Friendly plates** have the same settings, each kept apart:

| Card | Setting | Options |
|---|---|---|
| Health bar | Colour | **VoltUI's** (the colours below) or **Game's** (the game's own, with its own class colour options) |
| | Texture | Flat, two of the game's bar textures, and any bar textures other add-ons share through LibSharedMedia |
| | Height | The health bar's height. 0 keeps the game's own, which depends on its nameplate style and size. |
| | Class colours on players | Players in their class colour, or in the hostile colour (enemies) or the players colour (friends) |
| | Threat colours (enemy page) | **Off**. **Tank**: green while you hold a mob, orange as it slips, red when someone else has it. **Damage**: orange when you're about to pull it, red once you have it. |
| Colours | Units | Enemy page: hostile, neutral, and tapped by someone else. Friendly page: friendly characters, and players without class colours. |
| | Threat (enemy page) | The three threat colours |
| Health text | Show | **The game's** own text, **Off**, **Percent**, **Number** (shortened, like 12.5K) or **Number and %** |
| | Position | Left, centre or right inside the bar |
| | Size | 0.6 to 2 times the game's size |
| Name and level | Name colour | **Game's**, **White**, or **Class** (players; everyone else white). A tapped or dead unit's grey name stays grey. |
| | Name size, level size | 0.6 to 2 times the game's size |
| Border | Thickness | 1 to 4 screen pixels, whatever the nameplate's scale |
| | Colour | The plain border's colour (black) |
| | Aggro ring (enemy page) | The threat colour around anything that's after you |
| Cast bar | VoltUI cast bar | VoltUI's flat cast bar, or the game's art |
| | Height | The cast bar's height. 0 keeps the game's own. |
| | Time left | Seconds left on the cast or channel, at the right of the bar |
| | Text size | Spell name, target and time, 0.6 to 2 times the game's size |
| | Colours | Cast, channel, can't be interrupted, and interrupted or failed |
| Auras | VoltUI aura icons | Flat square icons with a thin border, or the game's round ones |
| | Debuff size, buff size, crowd control size | 0.6 to 2 times, on top of the game's own aura scale |
| | Timer numbers | **Short** (the game's rule: under a minute), **All**, or **Off** |
| | Timer size, stack size | 0.6 to 2 times |
| | Border | **By type** (the debuff type's colour, black when it has none) or **Black** |
| | Dark swipe | The dark sweep over an icon as it runs out |

**Your target**:

| Card | Setting | Options |
|---|---|---|
| Border | Colour | Blue, white, or off |
| | Thickness | 0 (the same as its kind) to 6 screen pixels |
| | Faint ring round it | On or off |
| Size and text | Bar height | 0 (the same) to 40 |
| | Health text | **The same**, or Off, Percent, Number, or Number and %, on your target only. Say Off on the other pages and Percent here to see health on your target alone. |
| | Name size | Times its kind's name size; 1 keeps it the same |
| Other plates | Dim them | How much the other plates darken while you have a target, 0 (off) to 0.8 |
| Your focus | Orange border | On or off |

Settings from 1.19 carry over: the one set every plate had becomes both the enemy set and the friendly set.

The game's own options still decide which cast bar parts show (spell name, icon, target), which auras show for each kind of unit, and the overall aura scale.

## Buffs and debuffs

Since 1.48.0, and **off until you switch it on** (Settings, Home, *Buffs and debuffs*, then reload), because it puts the game's own buff frame away.

- Your **buffs** in rows from the right, left of the minimap, each with its time left under it (red in the last ten seconds) and its stacks on the icon.
- Your **debuffs** below them, bigger, with a border in their type's colour.
- **Right-click a buff** to cancel it. That works out of combat only: add-ons can't cancel buffs in a fight.
- Drag the whole block with **Move frames**. Size, buffs in a row, scale and the times are on the **Buffs** page.
- A time the game keeps secret during a fight still shows as the dark sweep over the icon, without the number.
- Weapon enchants (poisons, sharpening stones, imbues) come first in the row, edged in violet (since 1.53.0).
- Since 1.92.1 the block keeps up during a fight: a buff you put on or lose in combat shows or goes straight away. If the game hides even a buff's icon, it shows the icon it had last time, or a question mark with its time until the fight ends.

## Timers

Icons and bars for the spells you want to watch, in the spirit of WeakAuras: a **cooldown** coming back, a **buff** that dropped, a **proc**, your **debuff on the target**, a **totem**, a **weapon imbue**. It's a part of its own, *Timers* on Home, on from the start. Since 1.102.0 **nothing shows until you add it**: the Timers page is your list of timers, and each timer has its own settings.

**The flow** (`/volt timers` opens the page):

1. **Your timers.** The page opens on your list: each timer's icon, its name, a line on what it is and when it shows, an On/Off switch and **Edit**. An empty list says so, with a button to add the first.
2. **Add a timer.** *For your class* shows every spell VoltUI found for you, with its icon, grouped as buffs to keep up, procs, cooldowns, debuffs on your target, weapon imbues and totems. Click one: it joins your list and its settings open. *Any other spell* takes a name (for a spell in your spellbook) or a spell ID (for a trinket's proc, someone else's buff, anything VoltUI doesn't list), and a button for what it is. *Add them all* takes everything at once.
3. **One timer's settings**, also behind **Edit** on its entry:
   - **Show this timer**: off keeps it in your list with its settings, and doesn't show it. **Remove** takes it out of the list.
   - **Followed in a fight** (buffs and procs): see *In a fight* below.
   - **When it shows**: *All the time*, *In a fight* or *Out of a fight*, and a switch for each kind of place: the **open world**, **dungeons**, **raids**, **battlegrounds** (arenas count as battlegrounds). Then what fits its kind:
     - a cooldown: *While it's ready*, Show or Hide;
     - a buff to keep up or a weapon imbue: *While it's up*, Show or Hide (with *Show again in the last* so many seconds), and what it does while it's **missing**, set apart for *in a fight* and *out of a fight*: **Flash** (red and pulsing), **Faded** (grey) or **Hide**;
     - a debuff on your target: what it does while missing in a fight.
   - **Look**: an **icon** or a **bar**, its size (or a bar's width and height), the size of its numbers, the pulse, for a cooldown the blue tint when you're short of mana, rage or energy, the **block** it sits with, and its order in that block. *Copy look* gives its shape and sizes to every timer in its block.
4. **Blocks** (*Where they sit* on the first view): timers sit in four blocks on screen, *Buffs and procs*, *Cooldowns*, *On your target* and *Totems*, each dragged on its own while **moving frames**. A block has how many to a row, the gap and which way it grows; the scale and the opacity out of a fight go for all of them.

**A setting you haven't changed on a timer follows its block.** Each block has a look of its own (icons or bars, sizes), and a timer keeps to it until you change that setting on the timer. Put a setting back to what the block gives and it follows the block again. If you used Timers before 1.102.0, what you had set for the groups and for every timer at once (hide cooldowns while ready, hide buffs while up, the flashes) is still there, as what a timer you add starts from; your list itself starts empty.

**What VoltUI finds for your class.** Each class has a list in VoltUI: Battle Shout, Overpower and Flurry for a warrior; seals, auras and blessings for a paladin; Lightning Shield, the shocks, Flame Shock, imbues and totems for a shaman; and so on. Only spells you know are offered. Anything else in your spellbook with a cooldown of 10 seconds to 10 minutes is offered too, which covers racials and Forever's own spells. A spell learned later turns up in *Add a timer*.

**What each kind does.**

- **Cooldowns** are dark with **big numbers** while they cool down, then **pulse** when ready. The global cooldown doesn't count. Spells that only work after something happens (Overpower, Revenge, Execute, Riposte, Counterattack, Mongoose Bite, Hammer of Wrath) stay dim and **light up gold** when you can use them.
- **Buffs to keep up** (Lightning Shield, Battle Shout, seals, auras, blessings, aspects, armors, Slice and Dice) and **weapon imbues** go grey when they drop and pulse when you put them back. To begin with a missing one flashes red in a fight and is hidden out of one.
- **Procs** (Clearcasting, Flurry, Enrage, Shadow Trance and the like) show only while they're up, with a pulse when they come.
- **On your target**: your debuffs to keep up (Flame Shock, Rend, Sunder Armor, Corruption, curses, stings). They show when you have something to attack.
- **Totems**: a bar for each totem down, with its name and time; one that goes flashes for a moment where it was. **Right-click** one to destroy that totem, and hover for its tooltip. While a totem timer of yours is showing, the game's own round totem buttons are see-through and laid over VoltUI's timers: they're the ones you click, since destroying a totem only works from the game's own code.

**In a fight.** The game hides your buffs from add-ons during a fight, so by itself VoltUI only learns that a buff dropped once the fight ends. The game's own **Cooldown Manager** can still see them, and VoltUI asks it. The first view's *In a fight* card says where that stands, switches the manager on, and keeps its icons out of sight (they'd show the same things). The manager only follows buffs in its Tracked Buffs set, so each buff's or proc's own settings have a **Followed in a fight** row: *Follow it* puts it in that set (it takes a reload), and the list marks any buff that isn't followed. Cooldowns, debuffs on your target, totems and imbues don't need it.

`/volt timers test` pulses them all once, `/volt timers all` adds everything found for your class, `/volt timers reset` puts every setting and spot back and keeps your list.

Times the game keeps secret in a fight are handed to the game's own widgets (the cooldown's countdown numbers and the bar's timer), which still draw them. Whether a cooldown is running comes from fields the game never hides.

## Castbar

Since 1.46.0: **your latency** is marked as a red zone at the end of your own casts (a spell pressed once the bar reaches it goes off straight after; channels and casts whose length the game keeps secret have none), a cast that **can't be interrupted** gets a gold line along its top as well as its grey colour, and the game's **breath, fatigue and feign death timers** get a flat bar on a VoltUI panel. All three have switches on the Castbar page.

- **Your bar:** spell icon, name, time left and a thin spark.
- **Target's bar:** sits above the target frame, and the target's buffs and debuffs move up to make room while it shows.
- **Colours:** sky blue for casts, green for channels, grey for spells you can't interrupt. A failed or interrupted cast flashes red with the reason.
- `/volt castbar test` runs a sample cast, so you can check the look without casting.

### Weapon swing timers

Since 1.67.0 the game's own **swing timer** bars (main hand, off hand and ranged) get VoltUI's look: a flat bar on a dark box with a 1px border, a thin white spark at the end of the fill, and VoltUI's font for the "Main Hand" label and the time left. Main hand is sky blue, off hand violet, ranged green. The game still runs them: switch them on in its options, place and size them in its Edit Mode, and they still dim with red text when your target is out of reach. VoltUI only repaints them, and writes nothing on them, since they're Edit Mode frames. Switch it off with **Weapon swing timers** on the Castbar page (takes a reload). It needs the Castbar part on.

## Action bars

Flat, square bars replace the game's: up to eight action bars (as many as the client has), plus the stance, pet and Shaman totem bars, the menu and bag buttons, and XP and reputation bars. Your spells and keys stay where they are, because the bars use the game's own buttons, action slots and key bindings.

- **The look:** cropped square icons on a dark slot with a thin border. No end caps or other artwork.
- **Which bars start on:** Bar 1, any bar the game was showing, and any bar with something on it. After that it's your choice.
- **What still works:** paging with Shift and a number, stance and form pages, drag and drop, cast on key down, cooldowns, charges and the game's vehicle bar.
- **Procs light the button** (since 1.89.0). See [Proc glow](#proc-glow).
- **Out of range** icons turn red. An equipped item gets a green border.
- **Empty slots** can be hidden. They come back while you hold a spell, even in combat, so you can see where it can go.
- **Flyouts:** if you move a bar to the other side of the screen, its flyouts change direction after the next `/reload` or loading screen.

**Quick keybinds:** type `/volt keys`, or use the minimap menu or the **Quick keybinds** button on the action bars' settings page. This is the game's own quick keybind mode, and it works on every VoltUI bar, including the menu and bag buttons. Hover a button, press a key, mouse button or wheel, then click **Okay** to save or **Cancel** to undo. Esc clears a button's key. Every bar and empty slot shows while it's open, so you can bind what's normally hidden. Entering combat closes it and drops keys you hadn't saved. It also works if you open it from the game's settings.

`/volt bars` starts moving frames and opens the **Action bars** page. Pick a bar at the top of the page, or click its overlay. Everything else on the page changes that bar. Every slider has a box for typing an exact value: Enter or Tab or clicking away keeps it, and Esc puts it back. Typed values stay between the slider's limits but don't have to land on one of its steps, so a scale of 1.23 is fine:

| Setting | What it does |
|---|---|
| Show this bar | Turns the bar on or off. An off bar gives its keys back to the game |
| Buttons, buttons per row | How many buttons, and how they wrap |
| Button size, gap across, gap between rows, scale | Size and spacing |
| Fill rows to the, add rows going | Which way the buttons run |
| Show | Always, only in combat, or only out of combat |
| Fade out | Never, until the mouse is over it, or out of combat (solid for the whole of a fight, faded outside one until hovered). Since 1.80.0 this is its own setting, so it goes with any of the Show choices; a bar that was on *Hover* is now always shown and fades until hovered. |
| Opacity, opacity when faded | How solid it is, and how far it fades |
| Empty slots | Show or hide slots with nothing in them |
| Key bindings, macro names, stack counts | Each can be off, and each has its own size |
| Cooldown numbers, number size | The countdown on the icon |
| Border | The thin border around each button |

The **All bars** card has red icons out of range and the proc glow (on or off, its look, and a button to see it). **Copy to all bars** gives every other bar this bar's size, gaps, scale, text and visibility, but not its position or number of buttons. **Copy from...** does the opposite for one bar: it gives the picked bar another bar's settings (everything, text only, or the cards you choose). **Reset** puts the picked bar back to its default look and spot.

**The totem bar** has the same flat buttons, with a border in each totem's colour: fire, earth, water and air. It sets its size, gaps, rows, text and visibility the same way. A spell or totem you don't have yet doesn't leave a gap. Totem keys stay the game's own, and the flyout that picks a totem still opens above each button.

**Menu and bag buttons, and the XP and reputation bars,** have their own **Menu, bags, XP** page. Pick a bar at the top, or click its overlay:

| Setting | What it does |
|---|---|
| Show this bar | Turns the buttons on or off. The keys that open your windows and bags work either way |
| Buttons per row, button size, gaps, scale, fill and rows | The same layout as any bar |
| Show, opacity, opacity when faded | The same visibility as any bar |
| Border | The thin border around each button |
| Grey menu icons | Menu icons in grey, or the game's colours |
| Menu buttons | Take any menu button off the bar. The others close up |
| Bag slots, reagent bag, key ring | Take these off the bag bar. The backpack always stays |
| Free bag slots, free slots size | The count on the backpack |
| Width, height | The size of the XP or reputation bar |
| Numbers, number size | Your XP or standing on the bar: always, on hover, or off |
| Rested XP | The lighter part past the end of your XP |

A menu button lights up while its window is open, and the game's alerts still flash on it. The menu goes back to the game for its vehicle bar and pet battles, and comes back afterwards.

The XP bar steps aside at top level or with XP turned off. The reputation bar shows the faction you're watching, in its standing's colour, and steps aside when you aren't watching one. Since 1.34.0 it starts switched off, and its default spot is just above the XP bar, where it overlaps the bottom of bar 1 unless you move one of them; switch it on with **Show this bar** on the **Menu, bags, XP** page. A reputation bar you had never moved is switched off once by the update; one you had placed yourself is left alone. Clicks pass through either bar unless its numbers are set to show on hover.

`/volt bars off` and `/reload` give you the game's bars back.

### Proc glow

Since 1.89.0 a button lights up while a proc makes its spell instant, free or usable, and goes dark when the proc is used up or runs out. It flashes as it lights, then glows: a gold line inside the button's edge and a soft band outside it.

Two things light a button:

- **The game's own proc glow.** The client has it, and it works on VoltUI's bars because they're the game's own buttons. Which procs Forever's server sends it for isn't known, so VoltUI doesn't count on it.
- **VoltUI's own list**, for your class, from Forever's talent text:

| Class | Proc | Lights |
|---|---|---|
| Shaman | Maelstrom Weapon, at 5 stacks (instant and free) | Lightning Bolt |
| | Nature's Swiftness | Lightning Bolt, Chain Lightning, Healing Wave, Lesser Healing Wave, Chain Heal |
| | Clearcasting (Elemental Focus) | Lightning Bolt, Chain Lightning |
| Mage | Presence of Mind | Pyroblast, Fireball, Frostbolt, Frostfire Bolt, Arcane Blast |
| | Missile Barrage | Arcane Missiles |
| | Heating Up, at 3 stacks | Pyroblast |
| | Fingers of Frost | Ice Lance |
| Warlock | Shadow Trance (Nightfall) | Shadow Bolt |
| | Decimation | Soul Fire |
| Druid | Nature's Swiftness | Healing Touch, Regrowth, Wrath, Rebirth |
| | Eclipse | Starfire |
| Paladin | Infusion of Light | Holy Light |
| | Divine Favor | Flash of Light, Holy Light, Holy Shock |
| Priest | Searing Light | Holy Nova |
| Rogue | Cold Blood | Sinister Strike, Backstab, Ambush, Eviscerate, Mutilate |
| | Remorseless Attacks | Sinister Strike, Backstab, Ambush, Mutilate, Ghostly Strike |
| Usable after something | Overpower, Revenge, Execute, Riposte, Counterattack, Mongoose Bite, Hammer of Wrath | while you can use them and they aren't cooling down |

Forever's Maelstrom Weapon only changes Lightning Bolt (20% off its cast time and mana per stack), so Chain Lightning doesn't light for it. It's a level 35 talent.

**In a fight** the game hides your buffs' names and stacks from add-ons. So VoltUI also asks the spell itself, which stays readable: a Lightning Bolt with no cast time, or no cost, is lit, whatever did it. That covers Maelstrom Weapon, Nature's Swiftness, Presence of Mind, Shadow Trance, Clearcasting, Missile Barrage and Searing Light in a fight. The others (Heating Up, Fingers of Frost, Decimation, Eclipse, Infusion of Light, Divine Favor, Cold Blood, Remorseless Attacks) need the buff, so in a fight they only show if they were already up before it. Spells are matched by name, any rank.

On the **Action bars** page, **All bars** card:

| Setting | What it does |
|---|---|
| Glow when a spell procs | On or off. Off also hides the game's own glow |
| Proc glow look | **Square, pulsing** (the default), **Square, still**, or **The game's**: the game's round proc art, fitted to the button, for its procs and VoltUI's |
| See the glow | Lights every button with something on it for 3 seconds. `/volt bars glow` does the same |

## The settings window

Type **`/volt`**, or click the **minimap icon** and choose **Settings**. One window holds every VoltUI setting.

It opens on **Home** the first time (since 1.38.0), and after that on the page you were last on. Home has a tile for each part of VoltUI with its switch, what it's doing (*On*, *Off*, *On after a reload*, or the name of the add-on it's standing aside for) and a **Settings** link to its page. Under the tiles are shortcuts: Move frames, Quick keybinds, Font and look, Back up settings and Errors. The switches for VoltUI's parts used to be a list on the General page.

- **The sidebar** lists the pages under six headings: *VoltUI* (Home, General), *Frames* (Unit frames, Castbar, Party and raid, Healing), *Bars* (Action bars; Menu, bags, XP), *World* (Nameplates, Minimap and map, and any page another add-on adds), *Items* (Bags and bank, Loot and tooltips) and *More* (Other add-ons, Share and back up, Errors). Since 1.37.0 pages with the same kind of settings share one entry and show as **tabs** across the top of the page: Unit frames has Player, Target, Target of target and Pet; Party and raid has Party and Raid; Healing has Heal mode, Clicks and Dispels; Nameplates has Enemy, Friendly and Your target; Other add-ons has Questie and ForeverDB. An entry comes back to the tab you were last on, and the list no longer needs scrolling. A part of VoltUI that's switched off says "off" beside its page, and its page shows the switch to turn it on.
- **Search** at the top of the sidebar finds any setting by its name, its card, its page, its choices or its hover text, as you type. The results are the settings themselves, working, grouped by the card they're on, with **Open page** to go there. The sidebar counts the results on each page and dims the pages with none. Pages whose name matches are listed to open. *Colour* and *color*, *grey* and *gray*, *centre* and *center* all find the same things. Esc or **x** clears it.
- **Cards** hold the settings, with sliders (the mouse wheel works on them too), switches, side-by-side choices and colour swatches. Hover a setting's name for more about it where there's more to say; since 1.38.0 those settings have a blue **?** after their name. A setting that has no effect right now, like Height with the power bar off, dims, and hovering it says what it's waiting for ("Needs the power bar on", or the end of the fight). A page taller than the window scrolls; while you scroll with the wheel, sliders under the mouse don't take it, and once you stop, the wheel works on them again.
- Changes show straight away and are saved as you make them. There's nothing to apply.
- **Preview** (since 1.39.0): the Player, Target, Target of target and Pet tabs have a strip at the top with a copy of the frame on it, since the window often covers the real one. It's laid out from the same settings, shows you (as the real frames do while you're moving them), follows every change, and keeps its health and power up to date. A frame too big for the strip is cut off at its edge. The Target tab's elite and rare preview shows on it too.
- The window opens on the page you were last on, after a reload too (since 1.33.0). In the search box, **Enter** opens the first thing found: a page whose name matches, otherwise the page of the first setting.
- **Copy from...** (on the unit frames, bars, raid frames and heal mode, and nameplates) copies another page's settings onto this one: the player frame onto the pet frame, one bar onto another, the raid frames onto heal mode, the enemy plates onto the friendly ones. Pick **Everything**, **Text only** (what text shows and how big it is), or **Choose** to pick cards. It says how many settings will change before you copy, and a line under the page's title offers **Undo** for a few seconds after. Where things sit is never copied.
- **Reset** puts the page back to its defaults (a frame's spot too). It asks once more first: click it again within a few seconds.
- A line under the page's title says when something needs a reload (**Reload now**), or, in combat, that settings which resize frames wait until the fight ends.
- A window's main button (**Done**, **Make the string**, **Bring it in**, **Reload to apply**) is dark blue with white text and a light blue border, which turns white under the mouse.
- **Done**, **x** or **Esc** closes it. It opens in combat too: settings that resize secure frames (unit frames, bars, the castbar, raid frames) dim until the fight ends, and everything else can change.
- The **General** page has VoltUI's font (the **Fonts** page has a font for each text), panel opacity and rarity glow, the moving frames options, the minimap icon, and a switch for each part of VoltUI.

### Moving frames

Since 1.40.0:

- **Every VoltUI window can be placed here.** Bags, bank and loot each show a box of their own size where they open, since the windows themselves aren't open while you're moving frames, and so do the windows another add-on adds. Drag the box, or nudge it, and the window opens there from then on.
- **To frames** on the toolbar (and *Snap to other frames* on the General page): a frame dropped within a few pixels of lining up with a nearby frame's edge or middle lines up with it, and a yellow line shows while they line up. Only frames close by count. It wins over the grid.
- **Frames** lists every frame that can be moved, to pick one that's small or under another.
- **Undo** takes back the last move (a run of arrow-key nudges counts as one). **Reset spot** puts the picked frame back where it sits by default.

Click **Move frames** at the top of the settings window or in the minimap icon's menu, or type **`/volt edit`**. Every frame gets a blue overlay, and a toolbar sits at the top of the screen.

- **Drag** a frame to move it. Its spot is kept against the nearest screen corner, edge or middle, so it stays put when you switch between windowed and full screen, change resolution or change the UI scale. Spots saved before 1.12.1 are converted the first time you log in with it.
- **Click** a frame to pick it and open its page. The toolbar shows where it is, in screen pixels from the top-left, and so does its overlay. Type a number in **X** or **Y** to put it exactly there.
- **The arrow keys** move the picked frame one screen pixel at a time; with **Shift**, ten. Other keys still go to the game.
- **Grid** shows lines across the screen, starting from the middle (the middle lines are blue). **Snap** lines a dropped frame's nearest edge or middle up with the nearest grid line or screen edge. **<** and **>** change the grid's size, 4 to 64 pixels. All three are also on the General page.
- **Done** on the toolbar, **Esc**, or **Move frames** again stops moving frames. Entering combat stops it too, and it can't start in combat, because the game doesn't let frames like these move in combat. Closing the settings window also stops it.
- While frames can be moved, the target, target-of-target and pet frames stay up showing you, so you can place them with nothing targeted.

### Frame settings

Each frame has its own page:

| Setting | Options |
|---|---|
| Width, health bar height, power bar height | Sizes in pixels |
| Power bar | On or off |
| Name | Full, first name only, or hidden |
| Name font size | The level and tags scale with it, and the header grows to fit |
| Level | On or off |
| Status tags and raid marker | On or off |
| Health numbers, health percent, power numbers | On or off, each on its own |
| Health font size, power font size | Sizes |
| Class colours | On, or plain green for players |
| Portrait | Off, flat or 3D |
| Portrait side | Left or right |
| Scale | 0.5 to 2 |

If the name, level and tags are all off, the header strip goes too.

The **Target** page also has:

| Setting | Options |
|---|---|
| Elite and rare style | Off, border, or border and glow. Also on the ToT page. |
| Preview as | See the frame as Normal, Elite, Rare, Rare Elite or Boss without finding one |
| Buffs and debuffs | On or off |
| Buff and debuff size | Icons wrap to fit the frame's width |
| Cast bar, cast bar height | The bar on the target frame |

The **Castbar** page has width, height, font size, spell icon, time left, spark and scale for your bar, and a sample cast. The icon, time and spark settings apply to the target's bar too.

**Copy from...** on a frame's page gives it another frame's settings: **Text only** copies what text shows and how big it is (the player frame's fonts onto the pet frame, say), **Everything** copies every setting both frames have, and **Choose** lets you pick cards (Size, Name and header, Health, Power, Portrait).

The **font**, **bar texture** and **panel opacity**, which apply to all of VoltUI, are on the General page. The bar textures (since 1.69.0) are flat, seven of VoltUI's own (*VoltUI Smooth*, *Gloss*, *Soft*, *Matte*, *Stripes*, *Glass* and *Obsidian*), two of the game's, and any that other add-ons share through LibSharedMedia. The pick applies to the unit, party and raid frames, castbars, the XP bar, the timers and the swing and breath bars. The nameplates keep their own pick, with the same list, and other add-ons can use VoltUI's textures too. The settings windows themselves always stay in Inter and stay readable, so they don't change under you while you try things.

### Starting layouts

Since 1.50.0 there's a small window with ready-made layouts. Since 1.100.0 there are four: **Classic** (VoltUI's own defaults) and three presets, which are also cards on the **Home** page under **Presets**:

| Preset | Frames | Action bars 2 and 3 |
| --- | --- | --- |
| **Centre** | Player and target close under your character, cast bar beneath them | Both on, as blocks of six either side of bar 1 |
| **Healer** | Party and raid frames in the middle, your own frames below them | Bar 2 on above bar 1, bar 3 off |
| **Top left** | Player and target in the top left corner, the party under them | Both on, stacked above bar 1 |

- The window opens by itself **once, on a brand-new install only**. If you already have VoltUI set up it never opens unless you ask, and nothing moves unless you press **Use** (or **Use this** in the window).
- Open the window from **Layouts** on the Home page, or `/volt setup`.
- A layout says where the player, target and focus frames, your cast bar and the party and raid frames sit. A preset also sets, for action bars 2 and 3 only: on or off, buttons per row, and where the bar sits. No other setting changes; bar 1, the other bars, the minimap and windows stay where they are.
- **Undo** puts every frame, and bars 2 and 3, back exactly as they were before the first layout you tried, however many you try. Not in combat.
- The card of the preset you're trying says **In use** until you press Undo.

### Profiles

Since 1.49.0 settings can be kept as named **profiles**, one per character if you like. Until you make a second one, every character uses *Default*, exactly as before.

- On the **Profiles** page, **New profile** makes one named after the character you're on, starting as a copy of the settings in use, and sets that character to use it. **Uses profile** picks any other.
- A change of profile is brought in by a **reload**: the settings in use are put away under their name and the chosen profile's are brought out. Nothing else in VoltUI knows profiles exist.
- A profile holds every setting and every frame's spot. What VoltUI has noted, such as the error list, is shared by all of them, and so is what another add-on notes.
- **Copy from it** puts another profile's settings onto the ones in use; **Delete** (two clicks) removes one that isn't in use, and its characters go back to Default.
- Not there: sharing the look between profiles while keeping spots apart.

### Share and back up

The **Share and back up** page (or `/volt share`) turns your layout and settings into a string of text, and brings one back in.

- **Export**: tick what goes in (font and look, where everything sits, unit frames and castbar, action bars, party and raid frames, nameplates, bags, maps and alerts, other settings, which parts are on), then **Make the string**. Click in the box and press Ctrl+C. Keep it as a back-up, or send it to someone else with VoltUI.
- **Import**: paste a string into the box with Ctrl+V. It says which VoltUI made it and when, and ticks the parts it holds; untick any you don't want, then **Bring it in** and reload. **Undo the last import** puts back what it replaced (then reload again).
- The string is letters and numbers only, so it survives chat and forum posts, with a check that catches a string that was cut short or changed. It's a plain list of values: nothing in it is ever run, and only VoltUI's own settings are read from it.
- What VoltUI has learned stays yours and never goes in: errors, and what another add-on has noted.
- A part the string holds but leaves a setting out of puts that setting back to its default.

### Errors

VoltUI catches Lua errors so they can be copied in one go. It listens after the game's own error window has taken an error, so that window, the game's log and its error display work as before.

- VoltUI's own errors (anything with VoltUI's files in it, a part that couldn't start, a look that couldn't be put on, an action the game blocked) are kept, and the first one each session says so in chat. A red dot shows on the minimap icon until you've looked.
- **`/volt errors`**, or the **Errors** page, lists them newest first, with how many times each happened and whether it was this session. Click one to see all of it: the message, where it happened and the values around it. **Select it** selects that one; **Make a report** puts every error together with VoltUI's version, the game's version and which parts are on. Click in the box and press Ctrl+C.
- Other add-ons' errors are kept too, behind **Show other add-ons' errors too**.
- The list keeps the last 40, across reloads. **Clear** starts it again.

## Chat

Since 1.49.0 the game's chat windows get VoltUI's look: a flat panel behind each window and behind the box you type in, plain text tabs in VoltUI's font, and the game's own chat art faded out. *Chat panel opacity* on the General page sets how solid the panel is. Everything else is still the game's: channels, filters, sizes, where the windows sit, and the chat text's own font and size (right-click a tab). It's a part of its own, *Chat* on Home. Not there: copying links out of chat, and fading when idle beyond what the game does.

Since 1.101.23 a web address in chat is a link that opens a box to copy it from, and a small **C** in each chat window's corner (or `/volt chat copy`) opens that window's last 500 lines as plain text to select and copy. Both can be turned off on the General page.

## Minimap icon

A small **k** on the edge of the minimap, bottom right to start with. Drag it to move it around the edge.

Click it for the VoltUI menu:

- **Customise:** Settings, Move frames, Heal mode and Quick keybinds. Settings says "error" beside it while there's an error of VoltUI's you haven't looked at.
- **Windows:** the ones another add-on adds.
- **Reload to apply** shows when you've switched a part on or off and not reloaded yet.

**Right-click** the icon to open (or close) the settings window without the menu.

Since 1.54.0 the samples, the switch for each part of VoltUI and the icon's own switch are in the settings window instead: **Home** has the parts, the lists and **Try it out**; **General** has **Show the minimap icon** (`/volt icon on` and `/reload` bring a hidden icon back).

Click the icon again, press Esc or click anywhere else to close the menu.

## Bags

**Untick Baganator and Baganator Sleek** in the AddOns list first. VoltUI bags stay off while Baganator is on, so the two never fight.

Press **B** as usual. One window holds all your bags:

- **Categories**: Quest, Equipment, Consumables, Trade Goods, Reagents, Recipes, Bags, Ammo, Keys, Miscellaneous, Junk.
  - New items you've just looted go in **New** at the top until you close your bags. Each has a small blue square in its bottom-left corner (since 1.33.0; it used to sit on top of the item level).
  - Small categories sit side by side when they fit, so the window stays compact.
  - Within a category, items are sorted best rarity first, then by type and name.
- **Every empty slot is shown at the bottom**, as real slots you can drop items into.
- **Bags that only take some items get their own sections** below that: the reagent bag, quivers, ammo pouches, soul bags and profession bags. Each has its items and empty slots together, and is headed with the bag's name and a count such as `Light Quiver 3/16`. Their slots aren't counted in your free space, because most of what you loot won't fit in them.
- **Rarity outline and inner glow** on every item: green, blue, purple, orange. Junk gets a softer grey. Common items get none, unless you turn that on.
- Stack counts in your chosen font, a gold **!** on items that start a quest, and an optional item level on gear.
- **Quest items you no longer need** (since 1.63.0) get a small red bin in the top-right corner: a quest item once no quest in your log needs it (you handed the quest in or dropped it), or an item that starts a quest you've already done. Hover it for why. What counts as needed: the items your quests' objectives name, each quest's usable item, and, if QuestieDB is installed, each quest's own items (the one its giver hands you, like a letter to deliver) and the quests it ties the item to. While you have a quest with no objectives (a delivery) that QuestieDB can't read, nothing but a done quest's starter is marked, since that quest could need any of them (1.63.1: a letter to deliver was marked). Only the game's Quest kind of item is judged, so cloth or ore a quest wants is never marked. Search `leftover` to see them all. Turn it off on the Bags page: **Mark quest items you don't need**.
- **Search** box: matches item names and types, such as "cloth" or "metal". Everything else dims. Since 1.35.0 it also knows a few words: a rarity (`poor` or `grey`, `common`, `uncommon` or `green`, `rare` or `blue`, `epic` or `purple`), `gear`, `boe`, `quest`, `junk` and `new`.
- **Filter buttons** under the title (since 1.35.0): **Gear**, **BoE**, **Quest**, **Consumables**, **Trade goods** and **Junk**. Click one and everything else dims; click it again, or close the window, to clear it. One at a time, and it works together with the search box. BoE means gear of green quality or better that isn't bound to you yet. A window too narrow for all six shows the ones that fit.
- **Sort** button (if the game has bag sorting), money (gold, silver and copper each in its own colour) and slots used.
- Drag the title bar to move it. Since 1.44.0 its title bar is 24 pixels tall like every other VoltUI window's (it was 26).

Items are the game's own bag slots, so everything works as normal: click, drag, right-click to use or sell, Shift-click to link or split, tooltips.

### Bank

Talk to a banker and the bank opens in the same style, with your bags beside it, and both close when you leave unless your bags were already open. All your tabs show together in categories, with the same search box and the same corner to drag for its width. Since 1.35.0 its footer shows free slots and your money, beside the button for buying a tab when there's one to buy. Right-click an item to move it across, or drag it. A button at the bottom buys your next tab and shows what it costs, or claims your free first one. The game asks you to confirm either way. Warband tabs show too if you can see them, but a right-click from your bags goes to your own tabs, so drag items to a warband tab.

### Guild bank

Since 1.67.0 the game's **guild bank** window gets VoltUI's look, as its own part (**Guild bank** on Home, under Items): a flat panel in place of the vault art and tabard, slots like your bags (cropped icons, a faint square behind each, and the rarity outline and glow), flat tabs down the side with the chosen one tinted, flat tabs along the bottom with a line under the chosen one, and flat Deposit, Withdraw, Purchase and Save buttons, money box and search box. It's still the game's window, so deposits, withdrawals, the logs and tab info all work as before. It's skinned the first time you open a guild bank each session. Switching the part off takes a reload.

### Group finder

Since 1.91.0 the listings on the game's **group finder** Browse page are laid out by VoltUI, as its own part (**Group finder** on Home, under More). Each row has the leader's name, level and class; the activities by name (yours in gold); the note, or who's in the group; and the listing's age. The game still runs everything: searching, picking a row, whispering, inviting and the panel beside a row are its own. Switch the part off and reload to get the game's rows back.

### Settings

Click **Settings** on the bag window, or type `/volt bags`. Since 1.36.0 that opens the settings window on its **Bags and bank** page (a second click closes it); the small panel that used to open beside the bags, with the same rows, is gone. Font, opacity and glow are on the **General** page. Changes show straight away:

| Setting | Default |
|---|---|
| Columns | 10 |
| Slot size | 36 |
| Horizontal gap (between slots side by side) | 4 |
| Vertical gap (between rows) | 4 |
| Gap between categories | 10 |
| Font | Barlow |
| Count size, heading size | 12, 12 |
| Text outline | Outline |
| Glow strength | 0.6 |
| Opacity, scale | 0.85, 1 |
| Categories, item level on gear, glow on common items | on, off, off |

### Fonts

The font is used across VoltUI: unit frames, cast bars, bags, loot window and minimap strip. The settings windows, the minimap menu and the drag overlays stay in Inter, whatever you pick.

Since 1.70.0 the **Fonts** page (under VoltUI, after General) has the overall font and a font of its own for any of these texts. A text you haven't picked one for uses the overall font, so changing that changes everything else. Right-click a text to put it back; the page's Reset puts them all back. Each choice is written in its own font, so you can see it before you pick it.

| Card | Texts |
|---|---|
| Unit frames | Names, level and tags, health numbers, power numbers, aura stacks |
| Party and raid | Names, health and status |
| Castbar | Spell names, cast times |
| Timers | Countdown numbers, bar names, stacks |
| Buffs | Time left, stacks |
| Action bars | Cooldown numbers, keybinds, macro names, stacks and charges, XP and reputation text |
| Nameplates | Names, health text, levels, cast text, aura numbers |
| Bags | Category headings, stack counts (since 1.73.0) |
| Tooltips | Tooltip text |

For example, your name in Inter and your health number in Teko. The picks go with the look in Export and Import. Everything else (bags, the loot window, the minimap strip, chat tabs) uses the overall font.

- **Bundled:** Barlow, Barlow Condensed, Rajdhani, Chakra Petch, Inter, PT Sans Narrow, Lato, Titillium Web and Teko, and since 1.71.0 Big Shoulders Text, Baloo 2, Orbitron, Russo One, Oxanium, Electrolize, Bai Jamjuree, JetBrains Mono, Space Mono and Bebas Neue. Each is in one weight: semibold where the font has it, otherwise bold (PT Sans Narrow, Big Shoulders Text, Space Mono) or its only weight (Russo One, Electrolize, Bebas Neue). Inter and JetBrains Mono also come in regular and medium for the settings windows. All are free under the SIL Open Font Licence; the licences are in `Fonts/`. Teko, Big Shoulders Text, Baloo 2, Oxanium and JetBrains Mono only come from Google Fonts as variable fonts, which the game can't read reliably, so VoltUI ships fixed weights cut from them (the licence allows that; none of them has a reserved name). Orbitron's fixed semibold comes unchanged from its own project.

The settings windows, menus and toolbars have fonts of their own, apart from the frames, and they can't be changed. Since 1.81.0 they are two mono fonts: **Space Mono** Bold for titles (each window's, a page's, a card's, the main button, the "VoltUI" in each title) and **JetBrains Mono** for everything else, words and data alike. (1.72.0 to 1.80 mixed Inter for words with JetBrains Mono for data. Inter is still there to pick for your frames.)
- **The game's own:** Friz Quadrata, Arial Narrow, Skurri, Morpheus.
- **Other add-ons' fonts:** any font they share through LibSharedMedia shows up in the list too.

## ForeverDB Companion

If you use the [ForeverDB Companion](https://foreverdb.net) add-on for its leveling window, VoltUI can switch off everything else it does, so the two don't double up: its rare alerts, map and minimap pins, routes, waypoint arrow, quest guide, tooltip lines, rotation helper, auto-selling and repairing, popups, chat lines and minimap button. It also switches off the ForeverDB Helper add-on, for every character.

The leveling window stays, with what it shows: the quest plan, where to go next, and its supply, training and gathering tips. The window has its own compass, so it still points the way with the big arrow off. What ForeverDB records for foreverdb.net (for its Uploader) is left as you set it; it shows nothing in game.

- VoltUI 1.13.0 does this once, by itself, the first time it loads with ForeverDB. Type `/reload` when it says so.
- `/volt foreverdb undo` puts back every ForeverDB setting exactly as it was, and turns the Helper back on.
- `/volt foreverdb` does it again, after you've turned things back on or ForeverDB has updated.
- **With a levelling planner** (VoltUI 1.30.0): when another add-on tells VoltUI it plans your levelling (`VoltUI:PlansLevelling(name)`), the leveling window goes too, once, at login, since that add-on does its job. `/volt foreverdb window` brings it back for good, or turns it off again; `/volt foreverdb undo` brings it back with the rest. VoltUI's **ForeverDB** page has the same button.

It works on ForeverDB's saved settings (`ForeverDB_DB`), using a list read from ForeverDB 0.57.10 and brought up to 0.72.1 in VoltUI 1.101.6, which adds ForeverDB's loot roll advice and alerts, its dungeon loot coverage lines, and its sparkles and "find" buttons for quest items, herbs, ore and corpses to skin (1.63.2 added the raid plan mini map). If you trimmed ForeverDB with an older VoltUI, just those new settings go off once, by themselves; anything you turned back on in ForeverDB stays on, and `/volt foreverdb undo` puts them back too. Features a version after 0.72.1 adds aren't on the list, so turn those off in ForeverDB's own settings if you don't want them. Not yet seen in game.

## Tooltips

Since 1.43.0, on the **Loot and tooltips** page:

- **Where they show**, for things in the world such as units under the mouse: *Game's* (where the game puts them, the default), *Cursor*, or *Its spot*, a place of your own. With *Its spot*, **Move frames** shows a Tooltips box to drag; the tooltip's bottom-right corner sits on the box's. Tooltips that buttons and bag items put beside themselves stay where they are.
- **Text size** (13 by default; headings are two bigger).
- **Class colours on players' names**, and **Who they're targeting** as a line on unit tooltips ("You" when it's you).
- **Hide unit tooltips in combat**, off by default: for units in the world, not for frames and buttons.

Every tooltip (items, people, spells, the map) uses the flat dark panel, the VoltUI font and a thin flat health bar.

- **Item tooltips get a border in the item's rarity colour**: green, blue, purple, orange or grey. Common items keep the plain border.
- On items it adds:
  - **Item level** on gear, when the game doesn't show it.
  - **Vendor** price, when the game isn't already showing a sell price.
  - **You have**: how many you carry, and how many more are in the bank (since 1.101.18).
  - **Item id** while you hold Shift (spells and creatures show theirs the same way).
- A unit's health bar carries its health as text: a percent, the numbers, or nothing (**Health on the bar**; since 1.101.17).
  - **Drops from (your loot record)**: the top three mobs, chests or nodes you've looted it from, with how often and out of how many loots, best chance first. It needs another add-on that records your loot and hands it to VoltUI (`VoltUI:SetDropRecord`), and fills in as you play.
- Other add-ons' lines (auction prices, say) still show underneath.

Another add-on can add lines under a creature's tooltip (`Tooltips:AddUnitLines`).

## Sell junk

Open a vendor and your grey items are sold automatically, then chat says what you made: "Sold 7 junk items for 1s 23c". It doesn't repair unless you turn on **Repair your gear too** (Loot and tooltips page, Selling junk; off to begin with): then a vendor that repairs fixes everything from your own money as the window opens, and chat says what it cost, or that you can't afford it.

- Hold **Shift** while opening the vendor to skip it, repairs included.
- It sells one item every 0.2 seconds and checks each slot again just before selling, so only greys are ever sold, never anything you've moved into that slot.
- Items with no sell value and items you're moving are left alone.

## Loot window

**Roll frames** (since 1.48.0): the game's need / greed windows get a flat VoltUI panel and a flat timer bar. The game still runs them. It's a part of its own, *Loot roll frames* on Home, on by default.

Since 1.41.0 the loot window has settings on the **Loot and tooltips** page: **Scale**, **Width**, **Rows before it scrolls** (8 by default: a corpse with more scrolls with the mouse wheel, with a line at the bottom saying where you are, rather than making a very tall window) and **Item level on gear**, shown at the right of weapons and armour.

The loot window is replaced with a flat one:

- a flat dark panel with a thin border, the corpse's name in the blue title strip, and **All** and **x** buttons;
- one row per item, with its icon, a **1px outline and inner glow in its rarity colour** (the same as the bags), and its name in that colour;
- a stack count on the icon, a **Quest** tag on quest items and **Starts a quest** on items that start one;
- locked items (someone else's roll, for example) greyed out.

| Do this | And |
|---|---|
| Click a row | Loot it |
| Shift-click | Link it in chat (Ctrl-click previews it) |
| **All** | Take everything |
| **x** or Esc | Close |
| Drag the title | Move it. The spot is saved. |

- If **Loot under mouse** is on in the game's options, the window opens at your cursor. Otherwise it opens where you last left it.
- With **auto loot**, the window only appears if something is left behind, so it doesn't flash on every kill.
- Bind-on-pickup warnings and group loot rolls still use the game's own popups.
- `/volt test` shows a sample window, so you can see the look without looting.

## Square minimap

**Add-on buttons** (since 1.48.0, off until you switch it on at Settings, Home, *Add-on buttons drawer*): other add-ons' minimap buttons are taken off the square map and put in a drawer under it. A tab says how many there are; click it to open or close the drawer. VoltUI's own icon and the game's buttons stay where they are.

Since 1.45.0 there's a **line of readouts** under the zone strip: the **clock** (the square minimap hides the game's own), **latency**, **frame rate**, **durability** of your most worn piece of gear (amber under half, red under a fifth), **gold**, and **Mail** while you have some waiting. Hover it for home and world latency and your exact money; click it for the calendar. Each has its own switch on the **Minimap and map** page, and with all six off the line goes. The box you drag in Move frames grows to cover it.

- The minimap is **square**, with a 1px border.
- Removed: Blizzard's round frame, compass, zoom buttons, world-map button, zone banner and clock.
- A thin strip underneath shows the **zone** (green friendly, red hostile, orange contested, blue sanctuary) and your **coordinates**.
- Kept and moved to the corners: the mail, tracking, battleground and dungeon-queue icons.
- Other add-ons' minimap buttons are told the map is square, so they sit around its edge.
- **Move it** like any other frame: click **Move frames** (or type `/volt edit`) and drag it. Snapping and the arrow keys work on it too.
- **Size:** the **Scale** slider on the **Minimap and map** page, 0.5 to 2. The side of the map nearest the screen's edge stays where it is, so a map in the top-right corner grows down and to the left. **Put it back** returns it to the game's spot at its normal size.
- Until you move it, it sits where the game puts its own map. Positions and sizes set in the game's own Edit Mode no longer reach it.

| On the minimap | Does |
|---|---|
| Mouse wheel | Zoom in and out |
| Right-click | Tracking menu (herbs, minerals and so on) |
| Middle-click | Calendar, if the game has one |
| Click the strip | World map |

## World map

Open the map and go up to a continent. Every zone has its level range on it, so you can see where to go next without hovering. Just the range: the map itself names a zone when you hover it.

- **Colours** follow your level, the same as the game's hover label: yellow when you're in range, orange and red when it's above you, green and then grey when it's below you. They update when you level up.
- **Where they sit:** the roomiest spot inside the zone, worked out from the game's own zone shapes, so a label doesn't land on a neighbour or out at sea. Labels that would overlap are moved apart.
- **Zooming** keeps labels the same size on screen. They're a little smaller on the small map.
- **On a zone's own map**, its levels are in the title bar instead.
- Clicks and hovering go straight through the labels to the map.
- **Resizing it** (since 1.90.0): drag the gold corner at the small map's bottom right, or right-click it for the normal size. The full-size map always fills the screen.
- **Moving the window:** drag it by its title bar, on the small map or at full size. Each remembers its own spot, and the window can't leave the screen. The full-size map is about as tall as the screen, so it mostly moves sideways. Other game windows still open where they normally do, so one can end up behind the map if you've moved it there.

**Where the levels come from,** in this order:

1. The game's own zone data, when it has it. A range too wide to be real, like 1-60, is ignored as scaling data.
2. Another add-on's ranges, when one gives them (`ns.Extra.zoneLevels`), with their credit in the title bar.
3. Classic's published ranges.
4. For zones new in Forever that the first two don't cover, VoltUI's own: Mount Hyjal 55-60, Riverglades 35-45, Shen'dralas 37-45 and Zephras Isle 1-12. The first three are read off the levels of the ordinary hostile creatures QuestieDB has in each zone (on 2026-11-14). For the zones ForeverDB does cover, that method comes within about 3 levels of ForeverDB's ranges.

A zone with none of these gets no label. Cities have no level range, so they get no label either. `/volt worldmap debug` shows which source each zone is using.

**Coordinates** (since 1.42.0; the map's own since 1.104.0): where you are and where the cursor is, at the map's bottom-left, ten times a second. The *Coordinates on the map* switch on the **Minimap and map** page turns them off.

Another add-on can add layers of pins (`WorldMap:AddLayer`).

**The window** gets the flat dark look: a thin border, a title strip with flat **+**, **-** and **x** buttons, a plain breadcrumb bar, and no portrait or stone frame. It's still the game's own window, so quest dots, map pins, the filter button, the quest list and TomTom all carry on as normal. TomTom's player and cursor coordinates move into a row after the title, clear of the title and the zone's levels (TomTom's own offset sliders for them don't apply while the look is on). These keep the game's art for now: the filter, pin and floor buttons on the map, the quest list's headers and search box, and the quest details page. The details page stays parchment because the game writes its text in dark ink.

| Command | Does |
|---|---|
| `/volt worldmap levels` | Zone labels on or off |
| `/volt worldmap plates` | The dark plate behind each label, on or off |
| `/volt worldmap size 15` | Size of the level numbers (10 to 24). The names are a little smaller |
| `/volt worldmap skin` | The flat window on or off (needs `/reload`). The labels work either way |
| `/volt worldmap scale 150` | The small map's size, 60 to 200 percent. `/volt worldmap reset` forgets it along with the spot |
| `/volt worldmap drag` | Dragging the window on or off. Off puts it back in the game's spot next time you open it, and keeps your spot for if you turn it back on |
| `/volt worldmap reset` | Forget the window's saved spots |
| `/volt worldmap debug` | List each zone on this map, its levels, where they came from and its label's spot |
| `/volt worldmap on` / `off` | This whole part on or off (needs `/reload`) |

## Questie

If you use Questie, install [Questie](https://github.com/Questie/Questie) as its own add-on and VoltUI restyles it. Questie does all the quest work: map icons, the tracker, tooltips, My Journey. Nothing of Questie's is copied into VoltUI, so you update Questie the usual way, and VoltUI does nothing if it isn't installed.

- **Tracker:** a flat panel with a thin border and a title strip, the title in VoltUI's blue, and VoltUI's font. It follows `/volt font` and `/volt alpha`. **To move it,** type `/volt edit` and drag it like any other frame (the grid's snapping and the arrow keys don't reach it, since Questie keeps its spot itself). Questie's own way works too: hold Ctrl and drag, or turn off its tracker lock in Questie's settings. Size and text stay in Questie's settings; VoltUI's **Questie** page has the font switch.
- **Settings window:** flat frame, title bar and side tabs, flat checkboxes, sliders, lists, buttons and text boxes.
- **My Journey:** flat frame, tabs and buttons, with the panes inside tinted to match.

The first time, VoltUI turns on the tracker's background and border, sets them to VoltUI's colours, and raises Questie's default text sizes (quests and objectives from 10 to 12, the header from 12 to 13). After that they're Questie's own settings, so you can change them in Questie's Tracker settings and they stay. A size you've already changed isn't touched. The font is the exception: VoltUI sets it at every login, so use `/volt questie fonts` if you want to pick your own.

These stay as Questie has them: its icons and logo, the map and minimap pins, the text colours in the tracker, the tracker's quest item buttons (secure buttons that work in combat), and the colour swatches and sound buttons in its settings. Questie's pages in the game's own settings panel also stay as they are. So do the buttons, lists and labels inside My Journey, because AceGUI lends those out to other add-ons like WeakAuras.

Turning the skin off doesn't undo what it changed in Questie's settings. Questie's Tracker settings can set them back.

| Command | Does |
|---|---|
| `/volt questie` | Show the skin's state, and anything a new Questie version has changed |
| `/volt questie fonts` | VoltUI's font on the tracker, on or off |
| `/volt questie on` / `off` | The skin on or off (needs `/reload`) |

## Commands

| Command | Does |
|---|---|
| `/volt` | The settings window (`/volt settings <page>` opens a page, like `/volt settings bags`) |
| `/volt edit` | Start or stop moving frames, with the settings window (`/volt unlock` and `/volt lock` also work) |
| `/volt errors` | The errors VoltUI caught, ready to copy |
| `/volt share` | Export and import your layout and settings |
| `/volt timers` | The Timers page, your list of timers (`/volt timers test` pulses them all once, `/volt timers all` adds everything found for your class, `/volt timers reset` puts their settings and spots back and keeps your list) |
| `/volt help` | Every command, in chat |
| `/volt icon on` / `off` | Minimap icon on or off (needs `/reload`) |
| `/volt frames` | Unit frame commands |
| `/volt frames scale 1.1` | Size of all the unit frames at once (0.5 to 2) |
| `/volt frames class` | Class colours on player health, on or off for all of them |
| `/volt frames reset` | All the unit frames back to their default settings and spots |
| `/volt frames on` / `off` | VoltUI unit frames or the game's (needs `/reload`) |
| `/volt castbar` | Castbar commands |
| `/volt castbar test` | Run a sample cast |
| `/volt castbar scale 1.1` | Size of your cast bar (0.5 to 2) |
| `/volt castbar target` | Cast bar on the target frame on or off |
| `/volt castbar reset` | Your cast bar back to its default settings and spot |
| `/volt castbar on` / `off` | VoltUI's cast bar or the game's for yourself (needs `/reload`) |
| `/volt bars` | Move frames, on the action bars' page |
| `/volt keys` | Quick keybinds: hover a button and press a key |
| `/volt bars reset` | All the action bars back to their default settings and spots |
| `/volt bars debug` | List each bar's state in chat, for reporting a problem |
| `/volt bars glow` | Light every button for 3 seconds, to see the proc glow |
| `/volt bars on` / `off` | VoltUI's action bars or the game's (needs `/reload`) |
| `/volt loot on` / `off` | Use the VoltUI loot window or the game's (needs `/reload`) |
| `/volt map on` / `off` | Square minimap or the game's (needs `/reload`) |
| `/volt minimap scale 1.2` | Size of the minimap (0.5 to 2) |
| `/volt minimap reset` | The minimap back in the game's spot, at its normal size |
| `/volt worldmap` | World map commands: see [World map](#world-map) |
| `/volt questie` | Questie skin commands: see [Questie](#questie) |
| `/volt groups` | Show the party and raid frames' state, and anything that went wrong |
| `/volt groups options` | Open the Party frames or Raid frames page, for the frames you have up |
| `/volt groups reset` | Put all four party and raid frame sets (heal mode's too) back to their defaults |
| `/volt groups test` | Show or hide made-up party or raid members where your frames go: `5`, `10`, `25`, `40` or `off` |
| `/volt groups on` / `off` | VoltUI's party and raid frames, or the game's (needs `/reload`) |
| `/volt heal` | Heal mode on if it's off, off if it's on |
| `/volt heal on` / `off` / `auto` | Heal mode on, off, or on while your group role is healer |
| `/volt heal options` / `clicks` / `dispel` | Open the Heal mode page, the Clicks page, or the Dispels page |
| `/volt nameplates` | Show the nameplate skin's state, and anything it couldn't style |
| `/volt nameplates options` | Open the nameplate settings (enemy plates; friendly plates and your target are the next pages) |
| `/volt nameplates reset` | Put every nameplate setting back to its default |
| `/volt nameplates on` / `off` | VoltUI's look on the nameplates or the game's (needs `/reload`) |
| `/volt bags on` / `off` | VoltUI bags or the game's (needs `/reload`) |
| `/volt bank on` / `off` | VoltUI's bank window or the game's (needs `/reload`) |
| `/volt bags` | Open the bag settings |
| `/volt bags gapx 6` / `gapy 6` / `gap 6` | Horizontal, vertical or both gaps |
| `/volt bags cols 12` / `size 40` / `scale 1.1` | Columns, slot size, scale |
| `/volt bags categories` / `ilvl` | Turn categories or item level on gear on or off |
| `/volt bags reset` | Bag settings back to defaults |
| `/volt tooltips ilvl` / `vendor` / `drops` | Turn those tooltip lines on or off |
| `/volt tooltips on` / `off` | VoltUI tooltips or the game's (needs `/reload`) |
| `/volt junk on` / `off` | Sell junk at vendors on or off (needs `/reload`) |
| `/volt foreverdb` | Keep only the ForeverDB Companion's leveling window, and switch the ForeverDB Helper off (needs `/reload`) |
| `/volt foreverdb window` | The Companion's leveling window on or off (off by itself once when another add-on plans your levelling) |
| `/volt foreverdb undo` | Put ForeverDB's settings back as they were, and the Helper (needs `/reload`) |
| `/volt font rajdhani` | Pick the overall font (`/volt font` lists them). The Fonts page gives single texts their own |
| `/volt alpha 0.85` | Panel opacity (0 to 1) |
| `/volt glow 0.6` | Rarity glow strength (0 to 1). `0` leaves just the outline. |
| `/volt common` | Turn a white glow on common items on or off |
| `/volt test` | Sample loot window |
| `/volt reset` | Put the loot window back in its default spot |

## Good to know

- **1.105.0: the add-on is called VoltUI.** Its folder is `VoltUI`, its saved settings are `VoltUIDB`, its frames start with `VoltUI` and its slash command is `/volt` (or `/voltui`). Its mark is a lightning bolt (`Media\Bolt.tga`, drawn by `tools/make_bolt.py`): on the minimap icon in place of the old letter, and before the name in every title bar, whose block is now sized to fit the bolt and the whole name.
- **1.104.0: the rare scanner, treasures, fishing pools and lifts leave VoltUI.** VoltUI is the look of the game's interface; what's out in the world and where to find it isn't its job. The Rares and treasures pages, the alerts, the lists, the pins and buttons on the map and `/volt rares`, `/volt treasures` and `/volt alerts` go with them. The coordinates on the world map stay: they used to sit with the pin buttons and now belong to the map. Another add-on can bring such parts back through new hooks (`Pages.AddPage`, `Pages.AddTab`, `Move.AddAnchor`, `WorldMap.LiftLabels`, `Profiles.AddData`, `VoltUI:PlansLevelling`, `VoltUI:SetDropRecord`; see [For other add-ons](#for-other-add-ons)), and `/volt <part> on|off` works for its parts too. **Not yet seen in game.**
- **1.103.0: everything that runs on ForeverDB's data leaves VoltUI.** That data isn't VoltUI's to share, so VoltUI can now ship on its own. Dungeon and raid entrances and flight masters on the world map, the upgrades window, library books, best loot on creature tooltips and the tools that made their files are gone, and VoltUI runs on Classic's data and what you see and loot, as before you made any ForeverDB files. In their place VoltUI has hooks another add-on can use (see [For other add-ons](#for-other-add-ons)). **Not yet seen in game.**
- **1.102.0: the Timers page is a list of your timers, each with its own settings.** The page had five cards of settings for whole groups, with the list of spells at the bottom. Now it opens on **your timers** (icon, name, a line on when each shows, On/Off, Edit), **Add a timer** shows what VoltUI found for your class as icons to click (or takes any spell by name or ID), and a click lands on **that timer's own settings**: all the time, in a fight or out of one; a switch each for the open world, dungeons, raids and battlegrounds; what it does while ready, up or missing; icon or bar, its size, its block. A setting you haven't changed on a timer follows its block, and *Copy look* gives one timer's look to its block. Each buff's settings say whether the game's Cooldown Manager follows it in a fight, with a button to have it do so; that replaces the long Tracked Buffs list. **Your list starts empty, as asked: after this update no timer shows until you add it** (`/volt timers all` adds everything found for your class at once). What you had set before for the groups and for every timer at once is kept, as what a timer you add starts from. Not yet seen in game: the page's layout (text fitting its buttons and tiles, the list card growing and shrinking), a timer hiding when you enter a dungeon or raid, timers of different sizes in one block, and a timer moved to another block.
- **1.101.24: the target's buffs and debuffs keep updating in a fight (a first try).** In a fight the game refuses every aura read an add-on makes, so the row of icons above the target frame froze until the fight ended. The game has a frame of its own made for this, an aura container, that add-ons may create: VoltUI tells it the unit, which auras, how many and the layout, and builds each icon's parts once; the game then fills the icon, the sweep and the stack count itself, so no aura value passes through VoltUI and it keeps going in combat. The target's row is now one of these (debuffs, then buffs, sixteen of each at most, at your icon size, with the game's own tooltips). What's different from VoltUI's own row: borders are plain (no debuff-type colour, no gold border on your own), and VoltUI can't resize the icons mid-fight. **Kept up by the game** (Target page, Auras) switches back to VoltUI's row; if this client won't make the container, VoltUI says so once in chat and uses its own row. Target frame only for now: raid frames, HoTs and dispel windows are the next step if this works. Not yet seen in game, and it is the least certain change in this batch: target something in a fight and watch whether a new debuff appears.
- **1.101.23: web addresses in chat are links, and chat can be copied.** A web address someone posts (https://..., www...) becomes a blue link; click it for VoltUI's copy box with the address in it. Each chat window has a small **C** in its top-right corner, faint until the mouse is on it: click it for that window's last 500 lines as plain text you can select and copy (`/volt chat copy` does the same for the window that's showing). Two switches on the General page's Chat card, both on to begin with. Messages the game hides from add-ons are passed through untouched and left out of the copy. Timestamps, channel names and the messages themselves are otherwise exactly the game's. Not yet seen in game.
- **1.101.22: a quest marker on nameplates.** A creature that one of your quests still needs gets a gold **!** after its health bar, with how many are left when the game says ("!5"). It reads the same list the game puts on that creature's tooltip (your quests' objectives it counts toward) as data, so nothing has to be hovered; in a group only your own progress counts, and it follows the quest log as objectives fill. **Quest marker** on the nameplate pages (Border card) turns it off. Not yet seen in game, and it rests on this client listing quest objectives on creature tooltips: if no marker ever shows on a quest mob, that's why.
- **1.101.21: the bank's bag slots.** On this client a bank tab you buy is an empty bag slot: nothing can be stored in it until a bag goes in, and those slots only existed on the game's own bank window, which VoltUI replaces, so a bought slot couldn't be used without turning VoltUI's bank off. VoltUI's bank window now has a row of small bag slots at the bottom left, one for each slot after the bank itself. Drop a bag on one (or click it with a bag on the cursor) to put it in; click or drag it off to take it out. A bag in a slot shows its icon with a gold outline, an empty bought slot is plain, and slots you haven't bought are dimmed. The buy button sits after the row. Not yet seen in game.
- **1.101.20: the key ring can be opened with VoltUI's bags on.** Where the client has a key ring, its button opens it in one of the game's own bag windows, and VoltUI keeps all of those out of sight, so keys couldn't be reached. That one window is now let back out, in the game's own look, for as long as it holds the key ring; VoltUI's bags still have no key ring section of their own. If this client has no key ring, nothing changes. Not yet seen in game, and whether the client has one couldn't be checked from outside it: click the key button on the bag bar.
- **1.101.19: crisp borders.** VoltUI's border lines were 1 UI unit thick, which at most UI scales isn't a whole number of screen pixels (1.25 at a common one), so they came out soft and of uneven weight. Every border VoltUI draws around a frame, button or panel is now a whole number of screen pixels thick, worked out from that frame's own scale, and sits on the pixel grid; they're sized again when the UI scale, the window size or a frame's scale changes. **Crisp borders** (Look page) turns it off. A first pass: about forty single lines drawn by hand (dividers, underlines) are as they were, and frame positions aren't rounded to pixels. Not yet seen in game; a screenshot will show whether lines are even.
- **1.101.18: how many of an item you have, and ids on Shift.** Item tooltips get a **You have** line: how many you carry, and how many more are in the bank (nothing for an item you have none of). Holding **Shift** over an item, a spell or a creature adds its id number; without Shift nothing is added. Two switches on the Loot and tooltips page: **How many you have** and **Ids while Shift is held**, both on to begin with. A creature's id isn't shown where the game hides who the unit is. Not yet seen in game.
- **1.101.17: health as text on a unit tooltip's bar.** The health bar under a unit's tooltip now carries its health as a percent, and is 12 pixels tall to hold it. **Health on the bar** (Loot and tooltips page, Tooltips) picks Off, Percent or Number; Off is the thin line it was. Where the game hides a unit's health from add-ons, its own formatters write the text, and if it refuses altogether the bar simply has none. Not yet seen in game.
- **1.101.16: cooldown numbers: none on the global cooldown, tenths at the end.** Two new settings per bar (Cooldowns and border card; copied by "Copy look to all"). **No number under** (2 seconds to begin with): a cooldown whose whole length is shorter shows only the sweep, so the global cooldown no longer flashes a "1" on every button. **Tenths under** (3 seconds to begin with): with less than that left the number shows tenths, like 2.4. Both are the game's own countdown settings, so they work on cooldowns add-ons can't read in a fight. Set either to 0 for how it was. Not yet seen in game.
- **1.101.15: VoltUI can repair at vendors, if you ask it to.** A new switch, **Repair your gear too** (Loot and tooltips page, under Selling junk), off to begin with. On, a vendor that repairs fixes everything from your own money as the window opens and chat says what it cost; if you can't afford it nothing is repaired and chat says so. Holding Shift as you open the vendor skips it along with the junk sale. It never uses guild money. Not yet seen in game.
- **1.101.14: someone who joins mid-fight gets every click straight away.** A member's button can't be told which mouse buttons to answer during a fight, so a party or raid frame made for someone who joined mid-fight took left clicks only (no menu, no right- or middle-click heal) until the fight ended; the same went for their dispel window. VoltUI now has the game make all of a group's buttons ahead of time: the party's five when the frames start, a raid's when you join one, out of combat. Buttons made mid-fight anyway (joining a raid while fighting) still catch up when it ends. Not yet seen in game.
- **1.101.13: a note of whether the game is locked when VoltUI starts.** After a /reload in a fight VoltUI has come back half set up, and nobody knew whether the game is already locking its frames at the moment add-ons start. Each start now notes what the game answers when VoltUI loads, at login and on entering the world, and how many seconds later a fight first began or ended: `VoltUIDB.loginProbe`, the last eight starts. Notes only; nothing behaves differently. One /reload in the middle of a fight settles it.
- **1.101.12: the leave-vehicle and stop-flight button shows again, in a place of its own.** The game's button for leaving a vehicle that has no bar of its own, and for landing early from a flight, belongs to the game's main bar, which VoltUI hides, so it never showed. It now sits in its own holder beside bar 1, with VoltUI's flat frame, and moves like any other frame (**Leave vehicle** when frames are unlocked). The game still decides when it shows and what a click does. Not yet seen in game: take a flight and look for it left of bar 1.
- **1.101.11: bar 1 keeps VoltUI's look when the game re-applies its bar art.** The game's Edit Mode re-applies each bar's art setting to every button still on that bar's list, which bar 1's buttons are, and that put the game's frame border and pressed art back on them (seen after a /reload in a fight). VoltUI now fades the border and flattens the pressed look again straight after the game does it. Not yet seen in game.
- **1.101.10: the new-mail icon sits on the map, and two leftovers are hidden.** On this client the mail icon has no name of its own (it lives in the minimap cluster's indicator frame), so VoltUI never moved it and it stayed wherever the game's zone text was. It now sits in the map's top-right corner and goes back there when the game re-places it. The day/night ring and the round plate the game shows under a rotating minimap are hidden, as they stayed behind where the game's map used to be. The add-on compartment button is left alone. Not yet seen in game.
- **1.101.9: right- and middle-click on the minimap no longer ping it.** The game's own click handler pings the map on any mouse button, and VoltUI's tracking menu (right-click) and calendar (middle-click) ran after it, so each one also sent a ping to your group. A plain frame over the map now takes those two buttons; the left button passes through it, so a left click still pings, and the map's own tooltips still show. After a /reload in a fight it's put in place when the fight ends. Not yet seen in game: check that mouse-over names on the minimap and other add-ons' minimap pins still answer the mouse.
- **1.101.8: "Reload now" waits for a fight to end.** Every Reload now button (the settings window, the toasts, the minimap icon's menu, importing settings) now says "not in a fight" in chat during combat and does nothing, because a reload mid-fight leaves the bars and party frames waiting until it's over. Typing /reload yourself still works. Not yet seen in game.
- **1.101.7: fixes found by reading ElvUI next to VoltUI.** No ElvUI code or art is used (its licence keeps all rights); these are things it guards against that VoltUI didn't, each checked in the game's own interface code. Party and raid frames now wait for a fight to end before they're made after a /reload in combat, as the player and target frames always did; before, they were made at once and never shown afterwards. The target's and focus's cast bars match "failed" and "interrupted" to the cast by the game's cast bar id, since another unit's cast GUID can't be read; before, any failed attempt by that unit ended the bar as Failed. They also repaint when a cast becomes interruptible or stops being so part-way. Bag, bank and guild bank icons lose the game's rounded mask, so they fill their square outline. The tooltip's **Vendor** line is left out when the game has already written its own Sell Price line (it's a text line on this client, which VoltUI wasn't looking for). A chat tab's new-message flash stays gold instead of going back to the game's colour. The game's "binds when picked up" question closes with VoltUI's loot window. Health shown as what's missing no longer compares a hidden number with nothing. Tested outside the game only; none of it has been seen in game yet.
- **1.101.6: ForeverDB 0.72's new features are off, like the rest.** ForeverDB 0.65 to 0.72 added features that are on by default: advice and alerts on loot rolls (they inspect your group), "seen in Forever" loot coverage lines in dungeons, and sparkles and "find" buttons for quest items, herbs, ore and skinnable corpses. If VoltUI trimmed ForeverDB down to its leveling window, these go off once, by themselves, with a line in chat asking for a /reload; `/volt foreverdb undo` puts them back. ForeverDB's new off-by-default options (loot feed, camera zoom, auto-accept invites and so on) are left alone. Not yet seen in game.
- **1.101.5: a buff set to Not tracked stays quiet in a fight.** With Lightning Shield set to **Not tracked** on the Timers page (In a fight), Timers still flashed it as missing in fights, shield up or not: with no icon for it on the game's Cooldown Manager, VoltUI fell back to asking the game about the buff, the game refuses that in a fight, and the refusal was read as "gone". Now a buff the manager doesn't track is left as it was when the fight began, with no warning and no icon during the fight. Tracked buffs warn as before. Not yet seen in game.
- **1.101.4: group finder rows no longer cut the dungeon names short.** A listing's second line stopped well short of the row's end ("Scarlet Graveyard, Scarlet Li..." with half the row empty), because room was kept on it for the game's role icons, which only sit beside the first line. The icons now sit a little higher, clear of the second line, and that line runs the row's whole width. Your own listing's row gets the same: its role icon and delist button move up beside your name, and the dungeons have the full line under them. Seen in the user's screenshots; the fix itself is not yet seen in game.
- **1.101.3: right-click a totem timer to remove the totem, again.** The game's own totem buttons lie see-through over VoltUI's totem timers so its right-click still destroys the totem. But each time the game showed its totem frame it put it back inside its own player frame, which VoltUI hides, so the buttons were hidden too and took no clicks. VoltUI now stops the game doing that. Not yet seen in game.
- **1.101.2: missing buffs stay away out of combat.** A buff you keep up that's gone (Lightning Shield, a weapon imbue) used to sit faded and grey on Timers outside a fight. Now it only shows in a fight, where it flashes. Out of a fight it shows only if **Flash them out of combat too** is on, or the new **Show missing buffs out of combat** (Timers, Alerts; off) is. Not yet seen in game.
- **1.101.1: debuffs in line with buffs.** Seen in game: your debuffs sat further right than your buffs, over the minimap's buttons, and were drawn bigger than their setting. They're now set in by the buff frame's little arrow, as the game does, so both rows end at the same place; the icon size the game's Edit Mode keeps for each frame is taken out, so **Buff size** and **Debuff size** are the sizes drawn; and a new debuff size starts at 30, the same as buffs (yours stays as saved: change it on the Buffs page). Not yet seen in game.
- **1.101.0: pick the game's Tracked Buffs from the Timers page.** Seen in game on 1.99: with the game's Cooldown Manager on, VoltUI can tell in a fight whether a buff is up (Lightning Shield's reminder now shows when its charges run out), but only for a buff in the manager's Tracked Buffs. Those can now be picked on the Timers page, under **In a fight**: every buff the game can follow is listed, click one to track it or stop. VoltUI asks the game's own Cooldown Manager settings to make the change and save it, then asks for a reload, after which the game has loaded it by itself. Not in a fight. If the game doesn't take a change, the page says so and `/cdm` still works. What the game answered is noted in `VoltUIDB.viewerProbe.trackSet`. Not yet seen in game.
- **1.100.0: three presets on the Home page.** A new **Presets** card on Home has **Centre**, **Healer** and **Top left**, each drawn as a little screen with a **Use** button. They come from the default-layout mock-ups. A preset places the player and target frames, the cast bar and the party and raid frames, and lays out action bars 2 and 3 (on or off, buttons per row, spot). **Undo** on the same card puts frames and bars back exactly as they were. The Layouts window shows the same three plus Classic; **Centre** replaces *Close in*, and **Healer** moved its frames below the group frames (they overlapped a full raid before). Not seen in game yet.
- **1.99.1: no more "VoltUI has been blocked" on loading.** Seen in game: a pop-up on every reload, "VoltUI has been blocked from an action only available to the Blizzard UI". It came from the notes added in 1.98.1, which asked the game for combat log events to see whether add-ons get any. On this client just asking is forbidden. That line is gone; the answer (add-ons get no combat log) stands.
- **1.99.0: Timers ask the game's Cooldown Manager in a fight.** What 1.98.1's notes said (in game, 2026-11-20): the combat log gives add-ons nothing on this client, but the game's **Cooldown Manager** is available and its Tracked Buffs include Lightning Shield, Water Shield, Flurry, Maelstrom Weapon and more. It was switched off. Its icons are the game's own frames, so they follow a fight. Timers now look at them (only look): for each tracked buff, whether the game has it active, or, where that is kept secret, whether its icon is showing. That answer comes before everything else in a fight, and is asked again twice a second, so **a Lightning Shield that loses its last charge in a fight should show (and flash) straight away**, and one put back on should go again. The Timers page has a new card, **In a fight**: a line saying where things stand, **Switch it on** (turns on the game's Cooldown Manager; it is the game's own setting, under Options, Gameplay Enhancements, and can be turned off there), and **Keep the game's manager out of sight** (on: its icons are made see-through and ignore the mouse, since Timers show the same things; they come back while the game's Edit Mode or the manager's settings are open). A buff has to be among the manager's Tracked Buffs to be asked about (`/cdm` shows them). **Not yet seen in game**, and one thing is still unknown: whether an add-on may read an icon's active or showing state in a fight. If not, Timers behave as before; the notes in `VoltUIDB.viewerProbe` will say after the next fights and a /reload.
- **1.98.1: finding out what can still tell a buff has gone in a fight.** Seen in game on 1.98.0: the restyled buff frames work, but the game's own buff list is secret to add-ons in a fight too, so Timers still can't see Lightning Shield lose its charges until the fight ends. Nothing changes in this version; it only takes notes (`VoltUIDB.viewerProbe`, saved on /reload) on the two things left that might say: the game's **Cooldown Manager** (which of your spells it tracks, and whether an add-on may see a tracked buff's icon showing or active in a fight) and the **combat log** (whether an add-on may read its lines in a fight). The next version is built on what those say.
- **1.98.0: buffs that keep up in a fight.** Seen in game: VoltUI's buff panel froze during a fight (a buff put on in combat only appeared afterwards, times stopped being right), and so did the buffs and procs on the Timers page. The cause is now known for certain from what the game answered (`VoltUIDB.auraProbe`): **in a fight this client refuses every aura read from an add-on**, the list, an aura by index, by id, by spell, its slots and its time alike. No add-on panel can be filled in there. So the **Buffs part no longer draws its own buttons. It restyles the game's own buff and debuff frames**, which the game's own code fills in and which do keep up: square cropped icons, VoltUI's thin border (violet on weapon enchants, the type's colour or red on debuffs), VoltUI's font and sizes on the time and stack count. VoltUI still places them: the block moves with Move frames as before, Buff size, Debuff size and Scale work, and the debuffs sit under however many rows of buffs are showing. What changes: **Buffs in a row is gone** (how many sit in a row and which way they grow is the game's, in its Edit Mode); the time is in the game's wording ("42 m"); the dark sweep over the icon is gone; a time font much over 10 reaches the row below, since the game leaves fixed room; right-click to cancel is the game's own. **Timers** (Lightning Shield and the other buffs and procs): in a fight they now look at the game's own buff list (`BuffFrame.auraInfo`, only read): a buff's id still there means it is up, gone means it dropped and it flashes straight away, and a buff or proc that comes on in the fight is found by its icon. Whether the game lets an add-on read those values in a fight is **not known yet**: if it does not, Timers behave as before, and the next fight's answer is saved as `gameBuffs` in `VoltUIDB.auraProbe` (after a /reload). The target frame's own aura row has the same limit in a fight and is unchanged. **Not yet seen in game.** Check first: that the game's buffs appear in VoltUI's look where the block is, that a buff cast in a fight appears at once, and whether Lightning Shield on Timers now follows the fight.
- **1.97.1: no border signals, and font sizes for buffs.** The unit frame border no longer changes in a fight, for a debuff you can remove or at low health: the three switches (Red in a fight, Debuff you can remove, Glow at low health) and the code behind them are gone, on every frame. The status tags still say Combat, and the border keeps the look you picked. The Buffs page gets **Time font size** and **Stack count font size** (Text card); the row under each icon grows with the time's text, so rows of buffs move apart for a bigger one. **Not yet seen in game.**
- **1.97.0: a nameplate preview you can click.** The three nameplate pages (Enemy, Friendly, Your target) now have a **sketch of a plate** at the top: a name, a health bar with its text and border, the level, a cast bar with its icon and time, and four aura icons with timers and a stack count. It follows every setting on the page as you change it. As on the unit frames, hover a part and click it for a **Selected:** card with that part's settings together: Border, Health bar, Health text, Name, Level, Cast bar, Aura icons. The target's page shows an enemy plate with your target's border and ring, and only the parts that page can change. It is a sketch, not a real plate: the real ones are the game's and only exist on units in the world. Sizes use the game's own where it gives them, the name colour under "Game's" is a guess at the game's, and with VoltUI's cast bar or aura icons switched off the game's art is only hinted at. The click zones are now shared code (Style.lua), so other pages can get them. **Not yet seen in game.** Check first: that the sketch is close to a real plate in size and layout, and that the parts take clicks.
- **1.96.0: click a part of a frame to change it.** On the Unit frames pages, the preview at the top can now be clicked. Hover it and each part lights up with its name: the name, level, status tags, health numbers, health percent, power numbers, the health and power bars, the name panel, the portrait, an extra text, and the rim round the frame for the frame itself. Click one and a gold-edged card, **Selected: (that part)**, appears above the page's other cards with everything about it in one place: for a text, whether it shows, its font size, which bar or panel it sits on, its side (left, middle, right) and a nudge across and up. Click another part to swap the card, click the same part again or press Deselect to put it away. Each frame's page keeps its own pick. The card's rows are the same settings as on the cards below, so a change in either shows in both. To make this true for every text, the **level, status tags and health percent now have font sizes of their own** (Name and header, and Health cards); they used to follow the name's size and the health numbers' size, and start from the sizes they had. A part that isn't showing (a text switched off, no portrait) has nothing to click: switch it on from its usual card first. **Not yet seen in game.** Check first: that the parts light up and take clicks in the preview, that small texts are easy enough to hit, and that level, tags and percent look the size they did before.
- **1.95.1: the pet's mood on the pet frame.** The pet frame gets an **extra text** of its own (Pet page, Extra text), set to **Pet happiness** to begin with: Happy in green, Content in amber, Unhappy in red, under the frame's left corner and clear of the experience line. It is blank for a pet that is not a hunter's. Like your own extra texts it can sit below or above, left or right, with a size, a nudge and a name in front ("Mood Happy", off to begin with), and can show other things: the pet's experience, health, power, name or level. Pet happiness and pet experience have left the player frame's list; if you had one of them chosen there it still shows until you change it. **Not yet seen in game.** Check first: that the text follows the pet's mood when you feed it, and that what `C_PetInfo.GetPetHappiness` returns is 1 to 3 in that order.
- **1.95.0: class extras on the unit frames.** Four additions, all in the new `FrameExtras.lua`. **Mana while shapeshifted** (Player page, Class extras, on): a thin mana bar under your frame while your power bar shows rage or energy, so a Druid in a form can see what is left. The frame keeps its size; combo points outside the frame move down under it. **Pet experience** (Pet page, Experience, on): a 3 pixel line under the pet frame for a hunter's pet below your level, with the numbers on the frame's tooltip. **Regen tick** (Player page, Class extras, **off, an experiment**): a spark crosses the power bar in time with the 2 second energy or mana tick, and a pale fill runs for the 5 seconds after you spend mana. **Extra text 1 and 2** (Player page, off): a text of your choice outside your frame, below or above, left or right, with a name in front if you want it, its own size and a nudge. The list has what your class uses (Soul Shards, ammo, reagent counts, combo points, pet happiness, pet experience) and plain things (health, health percent, mana, mana percent, power, name, level, experience). Click the value to drop the whole list down; the arrows still step through it. **Not yet seen in game.** Check first: that the mana bar shows in bear and cat form and not for a Warrior; that the tick spark lands on real ticks out of a fight, and how far it drifts in one (the game may hide power numbers there; if it is not accurate it should come out); whether Forever uses the Classic 2 second tick and 5 second rule at all; that the item counts are right (the item ids are Classic's: Soul Shard 6265, Ankh 17030 and so on) and that the ammo slot exists on this client; that the drop-down opens; that a text placed above the frame does not sit on the totems (nudge it if so).
- **1.94.0: borders for the unit frames, and the border as a signal.** Each frame page (Player, Target, Target of target, Pet, Focus) has a new **Border** card. **Style** picks the look: **Hairline** (the one grey line, as before), **Double line** (a dark gap and a black line outside the grey one), **Glass plate** (the see-through plate from the action bars, 6 past the frame, with the combo points on it), **Rail and tab** (a gold rail down the left side and the level in its own tab above the frame) or **None**. Three switches make the border signal: **Red in a fight**, **Debuff you can remove** (the debuff type colour with a soft glow) and **Glow at low health** (a pale line and a red glow that pulses under 20 percent). Low health comes first, then the debuff, then the fight. The signals start on for the player frame and off for the others. With Rail and tab the gold rail takes the colour of the signal. Cast bars, target buffs and totems above a frame move up to keep clear of a plate, a double line or a tab. **Not yet seen in game.** Check first: that the plate sits behind the bars and not over them, that the level tab does not cover anything above the frame, that the low health glow shows in a fight (it needs health numbers the game lets VoltUI read), and that the debuff signal only lights for debuffs you can remove.
- **1.93.0: unit frames you can rearrange.** Each frame page (Player, Target, Target of target, Pet, Focus) has two new sets of settings. **Order, top to bottom** puts the name panel, health bar and power bar in any order; picking a place for one swaps it with the row that had it. On the Player page the combo points are in the order too: first or last they sit just outside the frame as before, in between they get a row inside it. **Place** cards, one for each text (name, level, status tags with the raid marker, health numbers, health percent, power numbers), say what the text **sits on** (the name panel, the health bar or the power bar), which **side** (left, middle, right) and a **nudge** across and up from there. Texts that share a side line up outward from the edge; a long name is cut short where it meets what is on the other side. Text on a bar is outlined. A name panel with nothing left on it is not drawn, and the frame gets shorter. Nothing changes until you change a setting: the defaults are the old layout. **Not yet seen in game.** Check first: that a text moved onto a bar draws above the fill of the bar and the incoming heals, that a nudged text is not cut off at the edge of a bar, and how the combo points look as a row inside the frame.
- **1.92.4: Lightning Shield cast out of combat warns when it drops in a fight.** With 1.92.3, a shield you went into a fight without flashed as it should, but one put on before the fight never warned when it ran out in it. The game can report the new aura a moment before the cast itself, and Timers took that cast for a later recast that had replaced the aura. **Not yet seen in game.**
- **1.92.3: Lightning Shield in Timers notices when it drops in a fight.** When its last charge went in combat, Timers still showed it up until the fight ended, and only then said to cast it again. The game evidently hides the list VoltUI used to notice that (from 1.89.0). Timers now asks about the one buff: whether the aura it saw before is still there, and whether an aura with the spell id of the rank you cast is on you. VoltUI also notes what the game answers in the first few aura changes of each fight (kept in its saved settings, last 12), so if this still doesn't work, the next fix can rest on what the game really does. **Not yet seen in game.**
- **1.92.2: new items sorted when you close your bags.** Closing your bags now takes every item out of **New**, so next time each is in its own category. Since 1.80.0 only the ones you had hovered left New, and the rest stayed there until you hovered them too or clicked the New heading. While the bags are open nothing moves. **Not yet seen in game.**
- **1.92.1: buffs and debuffs keep up in a fight.** A buff put on in combat (Lightning Shield, say) only showed once the fight ended, because the game refuses VoltUI's usual way of reading your buffs during a fight and the block waited. The target frame's buffs and debuffs had the same cause and went blank in a fight. Both now read them by their ids then, which the game allows. A buff whose icon the game hides shows its last known icon, or a question mark, with its time. **Not yet seen in game.** Check first: that Lightning Shield cast mid-fight shows at once, with its own icon, and that your target's debuffs stay up in a fight.
- **1.92.0: plates behind bars, and a new look for the menu and bag buttons.** Every bar with buttons (the eight action bars, stance, pet, totems, menu and bags) has a **Plate** setting: a glass panel behind the buttons, a little larger than them, that ties the bar into one piece. It is off for action bars and on for the menu and bag bars; **Plate strength** takes it from faint to solid (0.55 is glass) and **Plate padding** sets how far it reaches past the buttons. The bar itself does not move or resize, so two bars sitting close together have plates that overlap: leave about 12 between them (two paddings and a seam) for separate plates. "Copy to all bars" copies the plate too. The menu and bag buttons are now raised grey squares like the buttons in VoltUI's windows, and a menu button whose window is open is a dark gold block with a gold line under it. Where you have never moved them, the menu and bag bars sit a few pixels further in from the corner so their plates fit on screen. **Not yet seen in game.** Check first: that a plate sits under the buttons and not over them, that it fades with its bar, and that the gold block reads well on an open menu button.
- **1.91.0: the group finder's listings, easier to read.** A new part, **Group finder** on Home (under More). On the finder's Browse page each listing now says on the row what you had to point at it to learn: the leader's name with level and class, the dungeons by name in place of "3 activities" (the ones you're listed for too in gold, a lone one with its level range), the note they wrote or, with no note, who's in the group, and how long ago it was listed. A bar in the leader's class colour runs down the left; rows and the Groups / Solo players headings are flat, with a gold tint on the one you've picked. The game's role counts stay, moved up beside the first two lines. The window itself, the other two pages and the pop-up panel are untouched. **Not yet seen in game.** Check first: that the activity names don't run under the role counts (the room left for them is a guess), the third line's spacing, and that picking a row, whispering and inviting work as before.
- **1.90.1: bag headings' hatched strips reach the edge.** A category's strip stopped where its own slots did, so the last category on a line left a bare gap up to the window's edge. The last heading on each line now runs on to the right edge. Not yet seen in game.
- **1.90.0: the small world map can be resized.** Drag the gold corner at its bottom right: the whole window grows or shrinks (60% to 200%, never past the screen) with its top-left corner staying put. Right-click the corner for the normal size. Also World map > *Small map's size* in the settings, and `/volt worldmap scale 150`. The window is scaled as a whole, because the game lays the small map out at fixed sizes and puts them back whenever it's minimised; the full-size map always fills the screen as before. **Not yet seen in game.** Check first: that the corner can be grabbed (it sits over the map's own corner), that hovering and clicking zones still line up at other sizes, and that pins and level labels keep their place.
- **1.89.0: procs light their buttons.** Maelstrom Weapon at 5 stacks lights Lightning Bolt, and a list for every class does the same for other procs (see [Proc glow](#proc-glow)); the game's own proc glow lights the button too. In a fight, when buffs can't be read, a listed spell with no cast time or no cost counts as procced. Action bars > All bars: on or off, *Proc glow look* (square pulsing, square still, or the game's art) and *See the glow* (`/volt bars glow`). Turning the glow off now hides the game's glow frame rather than telling the game to drop it. New file `ProcGlow.lua`. **Not yet seen in game.** Check first: that Lightning Bolt lights at 5 Maelstrom Weapon stacks in a fight (this rests on the game reporting a cast time of 0 for it, which the API documentation allows but nobody has seen); whether the game's own glow ever fires on Forever; the square glow's placement over the cooldown swipe and under the key text.
- **1.89.0: Timers notice a buff lost in a fight, and the out-of-combat flash is a switch.** In a fight, Lightning Shield losing its last charge flashed only once the fight ended, because the game hides buff names in a fight. Now VoltUI follows each buff by the id the game gives its aura (`C_UnitAuras.GetUnitAuraInstanceIDs`, not marked secret in the API documentation), so it flashes as soon as the buff goes, and its charges and time keep updating. A buff put back on in a fight is matched to the new aura that arrived with your cast (within 3 seconds, and only if it's the only new one). *Flash missing buffs* was one choice (Smart, Fights, Always, Off); it's now two switches on the Timers page's Alerts card: *Flash missing buffs in a fight* (on) and *Flash them out of combat too* (off). Your old choice carries over, except that Smart (the default) no longer flashes out of a fight. *Always* now flashes only long buffs out of a fight. **Not yet seen in game.** Check first: that the id list can be read in a fight (if not, it all works as before: the flash waits for the fight to end).
- **1.88.0: rarity outline width for the bags.** Bags and bank > Look > Rarity outline: 1 to 4 pixels (1 as before). It grows inward over the icon's edge; slots with no rarity colour keep a 1-pixel line. The loot window and guild bank are unchanged. **Not yet seen in game.**
- **1.87.1: Inconsolata Semi Condensed bundled** (Medium, SIL Open Font Licence, from google/fonts; its licence is `Fonts/OFL-Inconsolata.txt`). A mono font about a sixth narrower than JetBrains Mono. It's in the font lists. **Not yet seen in game.**
- **1.87.0: softer title blocks and main buttons, a wider settings window.** **Not yet seen in game.** Dark text on solid gold read too harsh in game, so a window's title block ("VoltUI", "Bags", "Rares", "RARE", "Upgrades", the guild bank's and world map's names) is now gold text on a dark gold tint with a 2-pixel gold line under it, and a main button (Done, Target, Waypoint) is the same tint with a gold border and gold text; its tint and border lighten under the mouse. The minimap icon keeps its solid gold square. The settings window is wider by default (sidebar 204 from 184, each column 390 from 330), since mono letters are wider: names were running into their controls. A row's blue "?" is a text of its own, bigger and right after the name. On the Timers page the spell list's Earlier, Later and Remove sit side by side and the name stops short of them (its kind follows it in grey), the kinds to add a spell as are two to a line under the box, and "In a fight" among the choices for flashing is "Fights" so the four fit. `S.BlockLook` and `S.SetFace` are new in Style.lua.
- **1.86.0: the upgrades window, guild bank, tooltips, chat and world map in the same look.** **Not yet seen in game.**
  - **Upgrades window.** The title on a gold block with the level and what the numbers are, the spec button beside it. The chosen slot is a gold tint with a solid left edge (blue before). Each candidate's icon has a border in its rarity colour; names keep their rarity colours and gains stay green.
  - **Guild bank.** The window's title in dark Space Mono on a gold block. Slots as the bags': a grey square with a thin border, gold tint and outline under the mouse. The side tab and the page that are shown are gold.
  - **Tooltips.** The window grey and border of VoltUI's own windows in place of the blue-black. "Drops from" and "Best loot" are gold after a small gold square, and "Targeting: You" is gold. The game's own lines, and your font, are untouched.
  - **Chat.** The grey panel behind each window, tab names in JetBrains Mono, a gold tint and line on the tab that's shown, the game's new-message flash on a tab turned gold, and a gold outline with a solid left edge round the box while you type. Messages keep your font and the game's channel colours.
  - **World map.** The map's name in dark Space Mono on a gold block, gold ticks in the map's top corners, gold hover on the breadcrumb and window buttons. Zone level labels are square plates with a border, in Space Mono, and the zone you're in is outlined in gold. The pin filters are bordered keys with the gold hover.
  - Loot, the Questie skin, and the frames you play with (cast bars, unit frames, nameplates, action bars) are left as they were.
- **1.85.0: the treasure alert, the recent-alerts list and the web-link box in the same look.** **Not yet seen in game.**
  - **Treasure alert.** As the rare alert: what it is (CHEST, FIND, NEST) on a gold block, then how it was found, a hatched strip and when you last looted it. The name is white in Space Mono; the icon's border carries the treasure's colour. **Waypoint** is the gold button.
  - **Recent alerts.** The title on a gold block; each row has a square in the alert's own colour, the name in white, and the settings' hover. So does the "+2 earlier" line under an alert.
  - **Web-link box.** "Link" on a gold block, then what it's a link to; the address in mono in a gold-edged box.
  - Loot, the upgrades window and the guild bank keep the older blue look for now.
- **1.84.0: the rare alert and the rare and treasure lists in the same look.** **Not yet seen in game.**
  - **Rare alert.** "RARE" in dark Space Mono on a gold block, then how it was found, a hatched strip and when you last killed it. The name is white in Space Mono; the border round the model carries the rare's colour (silver, or gold for an elite), which the name and a left edge used to. **Target** is the one gold button. ForeverDB's lines sit on a darker pane, each after a gold square.
  - **Lists.** "Rares" or "Treasures" on the gold block, then the zone and how many. Rows have the settings' hover and a thin line between them; distances are in mono with a dim "yd".
  - **A square before each rare** says where it stands: green may be up, red killed and not back yet (from ForeverDB's respawn times, where it has them), grey ignored. An ignored row is also dimmed. Treasures get a square in their own colour.
  - Fixed: the lists' title showed a stray "Â" before "· on the map" when the world map was open on another zone.
  - The treasure alert, loot, the recent-alerts list and the upgrades window keep the older blue look for now.
- **1.83.0: the square minimap in the same look, with three rows under it.** **Not yet seen in game.**
  - **Place name.** It has the first row to itself, in Space Mono, so long names fit. A small square before it carries the territory's colour (green friendly, red hostile, amber contested), which the name itself used to take. Click for the world map.
  - **Coordinates and clock.** The second row: coordinates on the left, a hatched strip, the clock on the right. Click the clock for the calendar, anywhere else on the row for the world map.
  - **Readouts.** Latency, frame rate, durability, gold and mail keep the last row, with each unit drawn dim. A good connection is green. The row goes when all five are off; the clock no longer needs it.
  - Two gold ticks mark the map's bottom corners, and the rows share their border lines. The frame is 16 pixels taller than before; a saved spot keeps its top-left corner. The game's own tracking and mail icons are not redrawn.
- **1.82.0: the bag and bank windows in the same look.** They follow 1.81.0's settings windows. **Not yet seen in game.**
  - **Title bar.** "Bags" or "Bank" in dark Space Mono on a solid gold block, the free-slot count in JetBrains Mono, a hatched strip up to the search box, and square Sort, Settings and close buttons. The search box's border turns gold while you type in it.
  - **Category headings.** A gold marker, the name in Space Mono, its count, and a short hatched strip. **Bags > Look > Category headings** switches between **Light** (the default) and **Band**, which puts each heading on a raised band with a gold end like the settings' cards. A font picked for bag headings on the Fonts page still wins; without one they no longer follow the overall font.
  - **Slots.** Square, each with a thin border (quieter on empty slots), on a darker pane. Hovering a slot tints it gold with a gold outline. Rarity outlines and glow are unchanged.
  - **Footer.** A green square before "N free" (red when the bags are full); money and currencies in mono. The new-item dot and the resize corner are gold.
  - The window's size and layout are the same, and saved spots are untouched. Loot, alerts, lists and the upgrades window keep the older blue look for now.
- **1.81.0: a new look for VoltUI's own windows.** The settings window, the minimap icon and its menu (and the other windows that share their style: the move toolbar and list, the starting layouts) are redrawn from the mockups chosen on 2026-11-18. **Not yet seen in game.**
  - **Hard edges.** Every corner is square: the window, cards, buttons, boxes, switches and their knobs, slider handles, the little markers.
  - **Gold.** WoW's gold replaces the violet as the one accent: what's switched on, slider fills, the page you're on, the main button.
  - **Card headings with a graphic.** Each card's heading is a raised band: a gold square, the card's number on its page, the title, a hatched strip, and a gold block at the end.
  - **A hover with no gradient.** Whatever the mouse is on gets a flat gold tint, a one-pixel gold outline and a solid gold edge down its left: rows, pages in the sidebar, buttons, menu rows. A settings row stays lit while the mouse is anywhere on it, its label and controls included.
  - **Two mono fonts.** Titles (the window's, a page's, a card's, the main button) are Space Mono Bold; everything else is JetBrains Mono. Inter is no longer used by the settings. Mono letters run wider, so words are a size smaller than before (11 for 12).
  - **Title bar and icon.** VoltUI's bolt and "VoltUI" sit on a block at the start of every title bar, and the minimap icon is the same mark in small: a gold square with a dark bolt. The menu's section headings are small capitals after a gold marker.
  - `tools/make_hatch.py` draws the heading's hatch texture (`VoltUI/Media/Hatch.tga`).
- **1.80.1: phantom totem bars fixed.** Seen in game on 1.79.0: in a fight every totem slot showed as a bar, the empty ones as full bars with no icon or name, and a totem that ran out stayed as an empty black bar until the next totem change. The game hides whether a slot holds a totem during a fight, and Timers took a hidden slot for a totem. It now goes by the game's own timer for the slot (there is one for a totem that's down, none for an empty slot), and reads the totems again when the fight ends. **Not yet seen in game.**
- **1.80.0: twelve things from the review.** None of this has run in the game yet.
  - **Action bars: fading is its own setting.** *Show* is now Always, In combat or No combat, and a new *Fade out* is Never, Until hovered or Out of combat (solid for the whole of a fight, faded outside one until the mouse is over it). A bar that was on *Hover* is carried over: always shown, fading until hovered.
  - **Moving frames.** Hold an arrow key and the frame keeps moving after a moment. Undo takes back the last ten moves, not one. Esc puts the settings window away if it's up, and only ends Move frames when it isn't.
  - **Timers: your own spells, in your own order.** On the Timers page, type a spell's name (if it's in your spellbook) or its spell ID and pick what it is: a cooldown, a buff to keep up, a proc or a debuff on your target. `/volt timers add cooldown|buff|proc|target <name or ID>` does the same. Each line has **Earlier** and **Later** to move it among its group's timers, and yours have **Remove**. They're kept by class, and *Reset* leaves them.
  - **Rares.** Looting a rare's corpse records the kill (it only counted if you targeted or moused over the corpse). A line in chat says when a rare you killed may be back, once its shortest respawn time in ForeverDB's data has passed (*Say when one you killed may be back*, on at first).
  - **Rare and treasure lists.** They scroll past ten rows instead of running off the screen, keep their distances up to date while open, and with the world map open on another zone they list that zone (by name, without distances), so you can plan from the map.
  - **Bags.** New items you hover stop being new when the bags close and the rest stay new (closing used to clear them all); click the **New** heading to say you've seen them all. Alt-right-click a grey item to keep it out of junk selling, again to sell it as before; the Selling junk card can forget them all. The bank's Sort button says what it sorts.
  - **Import.** Before you bring a string in, the Import card says how many settings in each part differ from yours, and which parts are the same.
  - **Under the hood.** One copy of the map code the rare scanner, treasures, pools, entrances and flight masters each had their own of, and one waypoint for all of VoltUI (a new one replaces the last, whichever part set it). A member's debuffs are read once for their tile, their dispel window and the dispel warning, not three times. Which switches need a reload is read from the settings rows themselves.
- **1.79.1: a review of the whole add-on: fixes and less work.** None of this has run in the game yet.
  - **Settings.** Right-click on an on/off switch puts it back to its default, like every other row (the switch covered its row, so the click never arrived). Switching the breath or swing timers off now asks for the reload it needs. `/volt font` with no name lists the fonts instead of quietly picking the first. `/volt icon on|off` shows or hides the icon at once. An import's setting of the wrong kind is treated as missing instead of breaking its part at every login. The leftover-quest-items switch is exported with the bags. An error at every login is one row in the Errors list with its count, not a new row each session.
  - **Moving frames.** A fight ends it whichever parts are on (it only did with unit frames or action bars on). Closing the settings window by hand while moving frames ends it and the window stays closed. Dropping a dragged frame no longer opens its settings. Clicking an action bar's overlay opens its settings when the window had stepped aside. The icon's menu offers *Move frames* whenever anything can be moved.
  - **Action bars.** A column bar's flyouts open towards the middle of the screen at any bar scale, and right after login. A bar that fades on hover is no longer set again every frame once it has settled. Range and slot events go straight to the buttons showing that slot.
  - **Bags.** In a fight they show what's in each slot as it changes (they couldn't be laid out, so they went stale), and bags first opened in a fight aren't empty. `/volt bags cols 0`, `scale 0` and the like are held inside what the settings allow. A slot already in place isn't moved again on every bag event. Alt-clicking a loot row for its web link doesn't also loot it.
  - **Party and raid.** A changed gap, order or direction shows at once instead of at the next change to the group, and switching between columns and rows no longer leaves the tiles in a staircase. The preview closing in a fight can't leave the real frames invisible.
  - **Timers and buffs.** The game's own totem buttons are only taken over for a class with totem timers. Buffs stay as they were when the game won't list them for a moment, instead of all vanishing. In a raid, Timers, Buffs, the rare scanner and Treasures no longer run for everyone's aura, cast and health events, only yours.
  - **Map.** A find that alerted a few minutes ago no longer stops the next one near you from alerting. A chest you've looted has one pin (faded until it's back), not a second full-strength one on top. A rare with only a longest respawn time known reads "up to N" and dims for that long. The map legend's buttons follow the Rares and Treasures switches. The minimap's pins are only moved when you or the map moved, and the game's map markers only redraw the pins when they add something.
  - **Minimap.** Other add-ons are only told the map is square while this part is on.
- **1.79.0: two Timers errors in fights fixed.** The game can send its lists of buffs gained and lost as secrets, which Timers tried to walk ("table expected, got secret"); it now leaves them unread. A totem the game gives no time for (not even its own timer object) showed an error at `SetCooldown`; it now shows without a timer. **Unverified in game.**
- **1.78.0: buffs put back on in a fight.** In a fight the game can hide aura names from add-ons, so a buff like Lightning Shield cast again mid-fight stayed red and "missing" in Timers, even after the fight. Your own cast of a buff to keep up now counts as it being on, auras are read again once the fight ends, and any that couldn't be read are tried again until they can. **Unverified in game.** See [Timers](#timers).
- **1.77.0: totems.** Right-click a Timers totem to destroy it. The game's own round totem timers no longer show above the player frame while the Totems group is on. **Unverified in game.** See [Timers](#timers).
- **1.76.0: whole bag headings.** A category with fewer items than its heading is wide (one recipe, one key) takes the room its heading needs, so the heading reads in full instead of "R...". **Unverified in game.**
- **1.75.0: two fixes.** Bag and bank category headings sit midway between the category above and their own slots, whatever the category gap (with a small gap they used to touch the row above). The *Copy from* window opens in front of the settings window instead of behind its cards. **Unverified in game.**
- **1.74.0: hide buffs while they're up.** A new Timers alert option, *Hide buffs while they're up*: buffs you keep up (Lightning Shield, armors, aspects, blessings) and weapon imbues only show when they're gone or about to run out, 60 seconds by default. **Unverified in game.** See [Timers](#timers).
- **1.73.0: bag fonts.** The Fonts page has a Bags card: bag and bank category headings and item stack counts can each have their own font. **Unverified in game.** See [Fonts](#fonts).
- **1.72.0: the settings windows' fonts are fixed, and mix Inter with JetBrains Mono.** 1.71.0's choice of settings window font is gone. Words stay in Inter; values, numbers, keys and the small capital headings are in JetBrains Mono, a size smaller so they take the same room. **Unverified in game.** See [Fonts](#fonts).
- **1.71.0: ten more fonts, and JetBrains Mono for the settings windows.** Big Shoulders Text, Baloo 2, Orbitron, Russo One, Oxanium, Electrolize, Bai Jamjuree, JetBrains Mono, Space Mono and Bebas Neue join the font lists. The settings windows, menus and toolbars could be set in JetBrains Mono in place of Inter (*Font* under Settings window on the General page; gone in 1.72.0). **Unverified in game.**
- **1.70.0: more fonts, and a font for each text.** Five more fonts to pick from: Inter, PT Sans Narrow, Lato, Titillium Web and Teko. A new **Fonts** settings page has the overall font and lets 25 texts each have their own: names, health and power numbers, cast times, cooldown numbers, keybinds, nameplate text, tooltips and more. Each choice is written in its own font. **Unverified in game.** See [Fonts](#fonts).
- **1.69.0: timers and bar textures.** A new part, *Timers*, shows your class's cooldowns, buffs, procs, debuffs on your target, totems and weapon imbues as icons or bars. They have big numbers, a pulse when something is ready or back, and a red flash when a buff you keep up drops. Each class's spells are found by themselves, plus anything in your spellbook with a cooldown. Seven new bar textures are VoltUI's own, picked under *Bar texture* on the General page for every VoltUI bar; the nameplates keep their own pick. **Unverified in game.** See [Timers](#timers).
- **1.68.1: cleaner bag slots.** Item icons no longer show the game's own border inside VoltUI's rarity outline: the game reset each icon's crop whenever it set the icon, and VoltUI now puts it back. Empty slots lose the game's slot picture and show just VoltUI's faint square. The guild bank's slots keep their crop the same way each time the game redraws them. **Unverified in game.**
- **1.68.0: lifts on the map.** The Great Lift and the Freewind Post lift in Thousand Needles, plus the lifts in Thunder Bluff, Undercity and Searing Gorge, are pinned on zone maps and the minimap. Each pin is a lime square with arrows; hover it for where the lift goes, click it for a waypoint (*Lifts*, `/volt worldmap lifts`). The spots are Classic's, from the CMaNGOS database. **Unverified in game.** See [World map](#world-map).
- **1.67.0: weapon swing timers and the guild bank in VoltUI's look.** The game's swing timer bars get a flat bar, a thin spark and VoltUI's font (*Weapon swing timers* on the Castbar page), and the guild bank window a flat panel, VoltUI-style slots with rarity outlines, and flat tabs and buttons (its own part, *Guild bank*). Both stay the game's own: VoltUI fades art and adds its own textures, never replacing what the game reads, and follows the game's shared helpers for rarity and the chosen tab. **Unverified in game.**
- **1.66.0: the Obsidian look for VoltUI's own windows** (after obsidian.md), in place of Gilded (1.62.0): the settings window, the minimap icon's menu, the Move frames toolbar and Frames list, Starting layouts, the click-casting picker, and the minimap icon (a rounded square in the window grey, its unseen-error dot round).
  - **Greys in steps** in place of warm stone: the window, its header and sidebar are #171717, the page beside the sidebar a darker #0F0F0F pane, cards #1E1E1E with a quiet #262626 border, and buttons, the chosen page and the chosen option a raised #262626 or #404040. Card titles sit over a hairline instead of on a band of their own.
  - **One soft violet** (#A78BFA) in place of gold, kept for what you pick: a switch that's on, a slider's fill, the page you're on (a short mark and its icon), a box you're typing in. "VoltUI", card titles and the sidebar headings are plain greys, and the main button is a solid neutral #404040 with light text.
  - **Rounded corners** from Obsidian's scale: 12 on the settings window, 8 on cards, tiles and smaller windows, 6 on buttons and boxes, 4 on the chosen option. Each box is drawn in pieces: four corners from small white textures in `Media/` (made by `tools/make_round.py`, each for the size it's shown at), and flat colour for the straight parts and the 1px borders, so edges stay crisp at any interface scale. Main buttons are flat, with no border until the mouse is over them, and every button is as wide as its label plus 12 each side.
  - **Obsidian's controls**: a switch is a violet pill when on and a grey one when off, with a light round knob (it was a green track with a red knob when off); choices sit in a dark well with the chosen one a raised grey pill; sliders have a thin rounded track and a round thumb.
  - **Inter** in place of Barlow in the settings windows, the minimap menu and the drag overlays: regular for text, medium for buttons, semibold for titles. Obsidian uses each computer's own system font, which the game can't load; Inter is the closest free match, cut from Google Fonts' copy into three fixed weights and bundled under the SIL Open Font Licence.
  - The status colours keep their meanings in Obsidian's shades: green on and saved, red off and Reset, amber standing aside, blue a reload or help. Unit frames, bars, castbars, bags and the rest keep their own colours.
- **1.65.0: zone levels on the new Forever zones, and just the levels**: Mount Hyjal, Riverglades and Shen'dralas get a level label on the continent map, and the labels no longer carry zone names (the setting and `/volt worldmap names` are gone). See [World map](#world-map).
- **1.64.0: fishing pools on the world map and minimap**: the pools you fish, noted as you catch from them, and Classic's spawn points, faded. See [World map](#world-map). `tools/foreverdb_pools.py` adds ForeverDB's spots.
- **1.62.0: a proper look for VoltUI's own windows** ("Gilded"): the settings window, the minimap icon's menu, the Move frames toolbar and Frames list, and Starting layouts. Warm stone greys in place of blue-grey, and a gold accent for what you're working with (the page you're on, the chosen option, sliders, the main button, which is now filled gold with dark text). Each sidebar heading has its own colour, taken from item quality (Frames rare blue, Bars legendary orange, World uncommon green, Items epic purple, More common white), and the icons under it share it, on the sidebar and on Home's tiles. Colours that say something mean one thing each: **green is on and saved, red is off and anything that undoes or went wrong** (a switch's knob, a tile's "Off", errors, Reset while it would undo a change), **amber** is a part standing aside for another add-on or a click the game's own binding wins, **blue** is a reload waiting or a setting's "?" help. Card titles sit on a band of their own in plain text. Unit frames, bars, castbars, bags and the rest keep their own colours.
  - 1.62.1, from the first look in game: **more room**. Rows are 26 tall (21 compact, were 22 and 18), card titles are a size up on a taller band with space under it, cards have padding at the bottom, the controls sit further in from the card's edge, and the scroll bar has a gutter of its own. Switches and slider handles are smaller. The main button (Done) is a gold tint with a gold edge and light gold text, since dark text on solid gold was hard to read.
  - 1.62.2, a spacing pass: **one spacing scale**. Text and controls sit 12 in from a card's edges, card titles are on a 32-tall band, rows are 28, and the room above a card's first line matches the room under its last. Cards are 12 apart. A note's row fits its text (no more empty space under a one-line note). Choices are each as wide as their name with 10 either side, with a hairline between them. Home's launch buttons are an icon over a name, centred, with the slash command in the hover instead of a second line; the part tiles centre their icon, name and switch. The Comfortable/Compact choice is gone.
  - 1.62.4: the **jump chips** (a row of card names under a page's title, from 1.61.0) are gone.

- **1.61.0: the settings window, redesigned** (from the hub and settings review):
  - **Home** opens with a status line: the profile in use, VoltUI's version, this session's errors and whether anything waits on a reload, each a link. Under it a **Launch** grid of square buttons with icons (Move frames, Quick keybinds, Layouts, Upgrades, Font and look, the rare, treasure and alert lists, Back up, Errors), each showing its slash command or page. The **part tiles** sit under the sidebar's headings, each with its own icon; a part that's off turns grey and flat, one standing aside for another add-on is edged in amber, one waiting on a reload has a blue dot. Click a tile for its settings. The samples moved to their own pages (Sample cast on Castbar, Sample loot on Loot, Sample alert on Rares and on Treasures).
  - **Changed settings are marked** with a small blue square, **right-click a setting to put it back** to its default, and **Reset** says how many it will change ("Reset · 3 changed").
  - **The footer** says your changes are saved and how many you've made this session, with **Undo last**, which steps back through them one at a time. Reset and Copy from aren't counted; they have their own Undo.
  - **Profile menu** at the top of the window: pick the profile this character uses (it takes a reload) or go to the Profiles page.
  - **Search** results say where each setting lives (Unit frames > Target > Size). **Up and Down** pick a result, **Enter** opens its page at that card.
  - **Long pages got jump chips** under the tabs, one per card (removed in 1.62.4).
  - **Drag the window's bottom-right corner** to resize it: one, two or three columns wide, and any height. Narrow, the sidebar folds to a rail of icons that opens over the page when you hover it. Three columns wide, a frame page keeps two columns of cards and its **preview docks in the third**, where it stays while the cards scroll. The size is remembered.
  - **General > Settings window**: the text size of VoltUI's settings windows (11 to 14). Takes a reload. (1.61.0 to 1.62.1 also had Comfortable or Compact spacing.)
  - Every page and part has a flat icon in VoltUI's colour, drawn by VoltUI rather than taken from the game.

- **1.60.0: web links.** Alt-click an item or a quest to get its page on Wowhead's WoW Forever database (`wowhead.com/forever`; 1.60.0 used Wowhead's Classic pages, which lack Forever's new items and quests): bags, bank, the character window, loot, vendors, the Upgrades window, item and quest links in chat (Alt-click the link), and the game's quest log. The game doesn't let add-ons open a browser, so the address comes up in a small box, already selected: press Ctrl+C and paste it into your browser. The box's button (or **General > Web links > Site**) switches to ForeverDB; NPCs always go to Wowhead. Action buttons are left out, since Alt is self-cast there. It's a part of its own, *Web links* on Home.
- **1.59.0: flight masters on the world map**, your side's, with the ones this character hasn't found faded once you've opened a flight map. (1.59.1 drops the flight path lines 1.59.0 drew.) See [World map](#world-map). Needs `tools/foreverdb_flights.py` run once.
- **1.58.0: the Upgrades window ranks gear by simulated DPS.** For damage specs the numbers now come from **ForeverDB's DPS simulator** (foreverdb.net/sim), which sims a boss fight a thousand times per spec at levels 20, 30, 40, 50 and 60 with a point more of each stat and of weapon DPS, and records the DPS each point adds. An item's gain is its stats and weapon DPS times those numbers, less what you wear, blended between the two sim levels around yours, and the list shows it as **DPS gained** ("+4.2 DPS"). Before, a weapon was worth a fixed 8 or 9 points per weapon DPS whatever its stats, and stamina counted as much as damage stats.
  - Weapon DPS counts for the hands the sim adds it to: the bow or gun for Beast Mastery and Marksmanship (their melee weapon only for its stats), main hand and ranged for Survival (80/20), both hands for dual wielders (70/30), the main hand for everyone else. Casters' weapon DPS and wands count for nothing; only their stats do. Stamina, armour, healing and mp5 add no DPS.
  - Hover a row for the DPS and what share it is of the sim's own DPS at your level. Healers and tanks have no sim and keep the ladders' stat weights, shown in percent as before.
  - The sim is ForeverDB's model: Classic's attack table, its talents and default dungeon builds, a 60-second fight on one target. For Enhancement it rates Intellect highly (mana for shocks), so some caster staves rank high. Item procs and on-use effects aren't simmed, so trinkets mostly count only for their stats.
  - Run `tools/foreverdb_gear.py` again to get it (it downloads `foreverdb.net/data/sim-defaults.json`; `--sim <file>` reads a saved copy, `--no-sim` leaves it out). That file is the website's, not part of ForeverDB's add-on, so it goes only into your install, never into this repository.

- **1.57.0: dungeon and raid entrances on the world map**, on zone and continent maps, with levels, group size and a waypoint on click. See [World map](#world-map). Needs `tools/foreverdb_dungeons.py` run once.
- **1.56.0: the Upgrades window** (`/volt upgrades`, the minimap icon's menu, or Home > Windows). For each gear slot it lists up to ten items better than what you wear, best first by how much better in percent, with where each comes from: a quest, a vendor and its price, a dungeon boss and its drop chance, a rare, a profession. Hover a row for the item and all its sources; click for a waypoint where a spot is known; Shift-click to link it in chat.
  - 1.56.2: **crafted gear that binds when picked up isn't listed**, since only its maker can wear it. A piece that's also a drop stays, without its crafted source.
  - 1.56.1: every row gets its rarity colour. Items the game hadn't seen this session stayed white; they're now asked for and coloured as the answers come. A drop chance under 0.1% says so instead of "0.0%".
  - The items, their sources and the weight each stat has for your class and spec are **ForeverDB's best-in-slot ladders** (foreverdb.net), scored the way ForeverDB's own gear finder scores them. Below level 60 the weights are its levelling ones, at 60 its raid ones. (Since 1.58.0 damage specs use ForeverDB's DPS sim instead; see above.)
  - The spec is the talent tree with the most points; the button at the top right steps through the others and back to Auto.
  - Rings and trinkets are compared with the weaker of the two you wear. A two-hander is compared with both hands together. A piece you can't use for another level or two shows as "soon" rather than in the list.
  - It needs `ForeverGear.lua`, made once on your PC: `python tools/foreverdb_gear.py "<AddOns>/VoltUI/ForeverGear.lua"` (add `--fdb "<AddOns>/ForeverDB/Data"` to read your installed ForeverDB instead of downloading), then restart the game. Run it again now and then for newer data. Without the file the window says so.
  - Not there yet: enchants, hiding an item you don't want, and choosing which kinds of source to show.

- **1.55.0**: drag the **bottom-right corner of the bags or the bank** to make the window wider or narrower, a column at a time; the rows follow, and it's the same Columns setting as on the Bags page. The **filter buttons under the title are gone**. The search box still knows their words: gear, boe, quest, junk, new, and rarities.
- **1.55.1**: the **totem bar's overlay is where the totems are**. The game's Edit Mode was placing the totem frame after VoltUI had put it in its bar, so the totems sat where Edit Mode had them and VoltUI's bar was empty somewhere else. VoltUI now puts them back in its bar whenever the game moves them (after a fight, if it happens in one).
- **1.54.0**, from the first look in game:
  - **The minimap icon's menu is short**: Settings, Move frames, Heal mode, Quick keybinds and VoltUI's lists. The samples and the lists are on the settings window's **Home** page (Windows, Try it out), the switches for each part were already there, and the icon's own switch is on **General**. Right-click the icon to open the settings directly.
  - **Bags**: the filter buttons and Sort, Settings and x in the title had no labels in game; a button's label is no longer pinned to the button's height, which is what left it blank. Your money shows the game's coins instead of g, s and c, and **Merchant's Favor** sits to its left, with any currency you've ticked "Show on backpack" for in the game's currency window.
  - 1.54.1: the chat's panel takes in the scroll bar, which sat on its edge over the text's margin, and the friends button sits under the channels button instead of floating above the chat.
  - **Chat**: while moving frames the main chat window has an overlay like every other frame, and a corner to drag for its size. The scroll bar is a slim flat one, and the friends, channels and chat menu buttons are flat squares. Reset spot is on the General page, under Chat.

- **1.53.0** finishes the review's list:
  - **Move frames puts the settings window away by itself.** `/volt edit`, the Move frames buttons and the minimap menu now show only the overlays and the toolbar. Click a frame to bring the window up on that frame's page, or press **Show settings** on the toolbar. A window that was open comes back when you finish. (`/volt edit` used to open the settings window as well.)
  - **Reset has an Undo**, like Copy from: every setting on the page and the frame's spot come back. **Copy to all bars** says what it did and can be undone too. Deleting a profile asks on the button itself ("Click to confirm"), as Reset does.
  - **One name for putting a window back: Reset spot** (it was also "Default spot", "Put it back" and "Forget its spot"). The toolbar's two snaps are **Snap: grid** and **Snap: frames**.
  - **Search** waits for two letters, no longer returns a whole page because the page's name matched, and **Open page** scrolls to the setting's card.
  - **Clicks and Errors pages**: only the click grid, the macro box and the error box are full width; the other cards are back in two columns, with labels beside their controls.
  - The Frames list and snapping ignore frames that are hidden. Heal mode's page is kept when you flip between party and raid instead of being built again.
  - **Buffs** (still off until you switch it on): weapon enchants show first in the row, edged in violet, and right-click removes them; debuffs keep their type colour in combat; and the block starts left of the minimap wherever the minimap is.

- **1.52.0 is a fixes release**, from a review of everything added since 1.33 against the game's own interface code. The ones you'd notice:
  - Typing in the settings search before ever opening the Action bars page threw an error on every key. Fixed.
  - Hovering the line under the minimap threw an error. Fixed.
  - On a settings page that scrolls, the mouse wheel now always scrolls the page; it used to change whichever slider was under the mouse. Hold **Shift** or **Ctrl** to step a slider with the wheel. On a page that doesn't scroll the wheel steps sliders as before.
  - The move toolbar has **Hide settings** / **Show settings**, to put the settings window away while you move frames without ending Move frames. Clicking a window's box (bags, loot, an alert) now keeps that box picked, so the arrow keys and Reset spot work on it.
  - A row's hover no longer covers the left end of its slider or first choice. Long slider labels are cut off at the slider instead of drawn over it.
  - The preview strip on the unit frame tabs is one height, so the cards don't jump as you drag a size.
  - Copy from closes when you leave its page (it could copy onto the wrong page), and copies colours too.
  - Starting layouts: **Undo** now goes back to your own layout however many layouts you try, not just one step.
  - Chat: whisper tabs and other windows made later are skinned too. Breath and fatigue bars keep the flat look after a timer starts. Ready-check answers stay through a second check. The game's own click casting is detected with modifier keys. The rare and treasure lists open side by side.
  - Add-on buttons drawer: icons no longer overlap, the game's own add-on menu button and other add-ons' map pins are left alone, and a button its add-on moves back to the map is put back in the drawer.

- Since 1.51.0 the small grey text across VoltUI's windows (counts, hints, notes, things that are off) uses three shared greys, where each window used to pick its own shade. Headers, close buttons and padding were brought into line in 1.44.0 and 1.50.0.

- **Tested mostly outside the game**, against a stubbed WoW API, plus play in game for the unit frames, settings windows and minimap icon.
  - Settings controls: sliders, typed values, the mouse wheel, limits, switches, choices, steppers, dimmed rows, cards in two columns, the same controls in the bag settings.
  - Minimap icon: placement on square and round maps, dragging, every menu item, part switches and the reload offer, closing by clicking elsewhere, hiding it.
  - Unit frames: Blizzard's frames hidden and silent, totems moved out, secure click setup, health, power, level, tags, colours, two-part player names, raid marker, Dead, Ghost and Offline, target-of-target and pet, buffs and debuffs, combo pips, moving, scale, closing on combat, waiting for combat to end after a `/reload`.
  - Edit mode: every setting through the panel's own buttons, one frame's change not touching another, limits, flat and 3D portraits, elite and rare preview, frame reset, older settings carrying over, nothing changing in combat, Done, Esc and combat closing it.
  - Castbar: casts, channels, pushback, finishing, failed and interrupted, another spell's failure not ending a cast, can't-interrupt colour, a new target, the sample.
  - Action bars, mostly outside the game, with the layout, keys, menu and bag buttons seen working in game: which bars start on, the game's bars retired, slots, keys and shortened key names, layout in every direction, paging, vehicle and form pages, the secure snippets, visibility, hover fading, empty slots, range, procs, stance, pet and totem bars, the menu and bag buttons (the game redrawing them, laying them out, or borrowing the menu for its vehicle bar), quick keybinds opened from VoltUI or the game, XP, rested XP and reputation, every setting through the panel, typed values, copy and reset, nothing secure changing in combat.
  - Secret values: health, power, names, levels, auras and casts as secret values, with any maths or text work on them in Lua failing the test.
  - Tooltips: panel, hidden Blizzard frame, old-style backdrops, health bar, font, rarity border and its reset, item level, vendor price (and not when the game shows one), drop lines best-first with chests by name, turning lines off; best loot on creatures (order, quality colours, Classic or Forever rates, world-drop line, hidden GUID found by name, names filling in later, settings), and the real generated file when run on the installed add-on.
  - Junk: greys sold, no-value and locked items left alone, nothing else sold, the summary, Shift to skip, a slot that changed isn't sold.
  - Fonts: text redrawn after a font change and back, frames following the font, every piece of text in the settings windows and menu staying in Inter (bar the font pickers' own names); the new fonts, a text's own font over the overall one and kept when that changes, a missing font falling back, the Fonts page, putting one or all back, and sharing them.
  - Treasures: Classic chests placed, world loots remembered by name and spot, gathering left out, chests told apart, repeat loots merged, map pins and tooltips, the game's treasure markers (and not its rare markers), alerts near known spots (not while still empty, no repeats), waypoint, ignore, closing in combat, the list, settings carried over once from when treasures were part of the rare scanner. Since 1.12.0 they run on their own, which hasn't been seen in game yet. Pet nests (1.20.0), not yet seen in game: placed from zone coordinates, pinned pink with the pet in the tooltip, their own switch apart from chests, remembered as nests when looted (by id, or by a name with the word "nest"), and an alert that names the pet. Lore books and caches (1.21.0), not yet seen in game: tested with a stand-in QuestieDB (books named after their quest, notice boards, mailboxes, quest objects, Classic's objects and other races' books left out, spots on the game's maps, a looted book renamed, the books switch, gone once done, no alert for a found book, nothing without QuestieDB or with a version VoltUI doesn't know); the same rules were run over the real QuestieDB 1.0.11 files and picked 51 books and 7 caches for an Orc Shaman. Felwood's plants and fishing left out of finds are tested too.
  - Rares: Classic spawns placed, nameplate, mouseover, target and map-marker alerts, the live game's rank beating the data, normal mobs left alone, no repeats, sound, flash, skull (not in combat, never inside the target event, left to the Target button's own macro, stopping after a block), sightings and kills saved, waypoint, ignore and unignore, the list, the alert's spot kept. The secure Target button: never anchored to the alert, hidden in combat, set up after it, and the alert closing, ignoring and dragging in combat without touching it. With ForeverDB's data: their spawn points replacing Classic's placing, seen spots, rares only they have, a rare new in Forever with no level yet, respawn times, drops, taming, the credit, a dungeon's rares, and everything going back without the file. The generator: run against ForeverDB's real file of 8 November 2026 (355 rares) and a made-up one, refusing anything unexpected. VoltUI 1.11.0's scanner was seen working in game; this standalone version hasn't been yet.
  - ForeverDB Companion: runs once, only with ForeverDB there, switches off its features and the Helper, keeps the leveling window, what it shows and its recording, leaves its own bookkeeping, undoes exactly (false and missing values too), runs again on request, leaves it alone while it only collects data. Against a stand-in for ForeverDB's saved settings, not seen in game yet.
  - Bags: a slot button for every bag slot, category order, empties at the bottom, horizontal and vertical gaps, categories side by side, rarity glow, quest marks, fonts, money, search by name and type, live settings, categories off, items moving, opening and closing from the game's bag keys, Blizzard's bag windows kept shut, the bank opening and closing with the banker.
  - Loot: rows, colours, glow, coins, quest tags, locked items, looting, linking, All, closing by **x** / Esc / the game, under-mouse placement, auto loot, the sample.
  - Map pins, not yet seen in game: the star and dot textures and their colours, rims and fading, centred on the spot, minimap pins placed by distance and direction, turning with a rotating minimap, out of range, no position or facing, the switches.
 Since 1.20.1 the world map's pins and zone labels sit over the explored parts of the map (they used to sit under them, because the game puts its explored-area art at a frame level around 2000): tested with a stand-in for the game's list of map levels, read but never written.
  - Minimap: square mask, hidden parts staying hidden, kept icons, zone colour, coordinates, zoom, tracking menu, world map.
  - World map, not yet seen in game: where levels come from, ForeverDB's ranges, labels landing inside oddly shaped zones, colours, zooming, overlaps, settings, zone maps, the game's art faded but still there, nav buttons the game makes later, dragging the window and keeping it there when the game re-anchors it.
  - Questie skin, not yet seen in game: run against Questie 12.6.3's real tracker, settings and AceGUI files with stand-in frames, including its settings pages being built in their coroutines. Set `QUESTIE_DIR` to a Questie folder to include this in `tests/voltui_test.lua`.
  - Party and raid frames (1.25.0, VoltUI's own), not yet seen in game: written against the game's secure group header and unit button code and its API documentation (the `forever` branch of the interface source), and tested with stand-in headers that make member buttons the way the game does: the headers and their attributes, member buttons dressed as they're made (in combat too, with their clicks waiting for it to end), health, incoming heals and shields, class and custom and dark colours, names without the realm, Dead and Offline, power bars for healers or everyone, aggro, target and mouse borders, fading by your heal's range or the game's, every setting, layout waiting for combat to end and touching no secure frame in it, secret health, range, threat and aura values going straight into the widgets, debuffs (removable first by the game's filter or your own dispels, bigger, by type, only removable, how many, stacks and time left), the game's frames hidden only out of combat, the old settings moving over, the preview, the settings page, Reset and the commands. Overhealing (1.26.0) is tested with the game's heal calculator set to cut heals and shields to the health missing, its overheal answer plain and secret, and worked out by VoltUI without the calculator. Heal mode and click-casting (1.26.0) are tested the same way: heal mode's own set, Auto by your role both ways, switching by hand and by command, never mid-fight, a shaman's ready-made clicks by spell name, every kind of click (spell, typed rank, nothing, macro, focus, target by macro on a modified click), clicks waiting for combat to end, members joining mid-fight getting them from the header, clicks always or only in heal mode, the game's own click casting noticed, the Heal mode and Clicks pages, Copy from and both resets. The click slots (1.26.2) are tested with a stand-in spellbook: only healing spells you cast on others are listed, one per name with its icon; picking, clearing by the list or by right-click, a slot that shows what it does, the list closing with its slot, nothing in a fight, and the grid picking the click to edit. HoTs, corner icons, dispel windows and the warning (1.27.0) are tested with stand-in auras sorted by the game's filters: your HoTs and not your long buffs, with their time and size; Earth Shield from someone else, still shown when the buffs go secret, and Fear Ward found by spell; both switched off; the preview; the windows' own header with both dispels as clicks, showing only while there's something to remove, hiding with heal mode only after a fight; the warning once per new debuff with who, what and which click (a window's, your frame click for the type, any dispel click when the type is secret), the sound at most every two seconds, fading, off, Test, made-up text while moving; and the Dispels page with Reset. Worth checking first in game: that the frames appear in a party and a raid with no "Interface action failed" (hiding the game's frames, and fading by range in a fight); that debuffs you can remove get their colour in a fight, when the game only gives it through its colour curve; that incoming heals and shields fill; that the missing-health text is empty at full health in a fight; and that range fading follows your heal; that left-click spells and Shift+Left targeting work on the frames, and that Shift+Right opens the menu (the game only allows a menu on a click its own click bindings give an interaction to); that overhealing lights up when a heal lands on someone nearly full; that your HoTs show in a fight (the game's `RAID_IN_COMBAT` filter), that Earth Shield and Fear Ward corner icons appear, that dispel windows show and their clicks cast in a fight, and that the warning names the right click; and that the click list shows your healing spells (it asks the game whether each spellbook spell helps, has a range and isn't a buff only you can have).
  - Nameplates (1.18.0), not yet seen in game: written against the game's own nameplate code (the `forever` branch of the interface source) and tested with stand-in nameplates: plates there before VoltUI starts and ones added later, a frame used again for another unit, the game laying a plate out again, each colour softened and the rest left alone, the game's colour back when the setting changes, target, focus and aggro borders, dimming, the bar height and back, text sizes, the cast bar in each state with a plain and a secret "can't be interrupted", interrupts, the game's art when VoltUI's cast bar is off, aura icons, another nameplate add-on loaded, the settings tab and reset, and nothing of VoltUI's written onto the game's frames. Worth checking first in game: how thick the 1px borders look at your nameplate size (they may be uneven or vanish when plates are scaled down), and no "Interface action failed" with **Height** changed, since that's the one setting that resizes part of a plate.
  - Moving and scaling the minimap (1.23.0), not yet seen in game: tested with stand-ins for the game's frames: the map moved into VoltUI's holder, the game's empty cluster letting clicks through, the map coming back if something hands it to the cluster (and waiting out a fight to do it), dragging and saving its spot, scaling around its middle, from the bottom-left and from the top-right corner, waiting out a fight, the page's scale row and Put it back, the arrow keys, its overlay opening its page, search, `/volt minimap`, export and import. Worth checking first in game: that the map, its strip and the icons on it move together, that clicks reach the world where the game's map used to be, and that the mail and tracking icons stay on the map's corners.
  - Settings window, moving frames, sharing and errors (1.22.0), not yet seen in game: tested with stand-ins for the game's frames: every page built, the sidebar, search (counts per page, either spelling, two words, page links, results that work, clearing), copying (text only, chosen cards, everything, raid onto party, enemy onto friendly plates, bar onto bar without its spot, undo), reset asking first, parts and the reload line, pages for parts that are off, the wheel over sliders while scrolling, the combat line; the grid and its middle lines, snapping on drop, the arrow keys (1 and 10 pixels, other keys passed on, nothing in combat), typed spots, the toolbar's switches; export strings (every value back as it went in, letters and back at every length, broken lists refused, cut or changed strings caught, only the parts picked), importing parts, keeping bar spots, undo, only VoltUI's own settings read; errors from the game's error window (VoltUI's and other add-ons', counted, warnings left out, a hidden message, the last 40, blocked actions, the page, the report, Clear); enemy, friendly and target nameplate sets, a unit changing sides, target overrides on and off, 1.19 settings carried over. Worth checking first in game: that the arrow keys nudge only while frames can be moved and every other key still reaches the game, that the colour picker and the Copy from window open above the settings window, that pasting a long string into the Import box works, and that an error from another add-on shows on the Errors page with its switch on.
  - Nameplate settings (1.19.0), not yet seen in game: tested with the same stand-in nameplates: border thickness in screen pixels through the plate's scale, the border colour, each colour you pick and its default, class colours on and off for enemy and friendly players, tank and damage threat colours with a secret threat answer, each kind of health text with plain and secret health, its position, the game's own text faded and back, name colours with the grey of a tapped unit kept, the game's and shared bar textures, the cast bar's height and back, cast colours, the time left on casts and channels with a secret time, aura list sizes, timer numbers, timer and stack sizes, the swipe, type-coloured aura borders with a secret type, the colour swatches with the game's colour picker (pick, Cancel, default), and the tab's two pages. Worth checking first in game: that the colour picker opens over the edit mode window, that *Time left* doesn't sit on top of the cast target's name when the game shows it, and how *Debuff size* looks next to the health bar (the list grows from where the game anchors it).
  - Saved spots, not yet seen in game: every movable frame saved against its nearest screen corner, old spots converted where they stood, frames keeping to their corner when the screen changes size and placed again after it, waiting for combat to end.
  - Settings.
- The minimap part works with both Classic and modern minimap layouts. If a Blizzard piece is still showing on the minimap, send me a screenshot.
- If anything errors in game, the Lua error text is what I need.
- If the game blocks VoltUI ("Interface action failed because of an AddOn"), VoltUI prints what was blocked in chat. That line is what I need.
- The unit frames replace Blizzard's completely, so anything of Blizzard's that lived inside them only comes back if VoltUI rebuilds it. Not in yet: a Druid's mana bar while shapeshifted, and heal and absorb bars on health. `/volt frames off` and `/reload` gives you Blizzard's frames back.
- The action bars follow the approach Dominos uses on this client, checked against the game's own interface code. Add-ons that skin or replace the game's action bars, like Dominos or Bartender, will clash: use one or the other.
- A `/reload` in combat shows the game's own action bars until the fight ends, because the buttons can't be moved during combat. VoltUI says so in chat, then its bars come back by themselves. `/volt bars debug` shows whether they've started.
- If the menu, bag, XP or reputation bar can't be set up, VoltUI says so in chat and leaves that part as the game has it. Your action bars carry on. That chat line is what I need.
- VoltUI's XP and reputation bars replace the frame the game keeps all its progress bars in, so the game's honor and house favor bars don't show while VoltUI's action bars are on. `/volt bars off` and `/reload` give them back.
- The game can refuse add-ons a target's auras during a fight. When it does, the target's aura icons disappear until the auras next change or combat ends.
- If using an item from your bags in combat ever shows "Interface action failed because of an AddOn", tell me. Bag add-ons occasionally hit that and it has a known fix.
- Not in yet: choosing which warband tab a deposit goes to, a key ring section in VoltUI's own bags (since 1.101.20 the key button opens the game's key ring window), and custom categories.

## For other add-ons

VoltUI's own parts are open to an add-on that adds parts of its own: `VoltUI.ns` is VoltUI's namespace. Each hook is small and neutral; VoltUI names no other add-on's data.

| Hook | What it does |
|---|---|
| `VoltUI:AddDefaults(t)` | Settings kept in `VoltUIDB` beside VoltUI's, so they go in profiles and backups. Saved values stay |
| `VoltUI.slash.word = fn(arg)`, `VoltUI.slashHelp` | More `/volt` words, and the words to list in `/volt`'s help |
| `VoltUI.tipToggles.word = "key"` | More `/volt tooltips` words |
| `VoltUI:Register(part)` | A part of its own: switched on at login like VoltUI's, with a tile on Home and a switch |
| `ns.Extra.zoneLevels`, `.shortCredit` | Zone levels for VoltUI's world map, with their `credit` |
| `ns.WorldMap:AddLayer(layer)` | A layer of pins drawn with the map: `Setup(canvas)`, `Draw()` (true shows its `credit()`), `Rescale()`, `Toggle()`, `slash` |
| `ns.WorldMap.LiftLabels = fn(frame, canvas, labels)` | Where the zone labels sit among the map's layers, for an add-on whose pins go over them |
| `ns.Tooltips:AddUnitLines(fn)` | Lines under creature and player tooltips |
| `ns.Pages.Extend(page, fn)`, `ns.Pages.AddLauncher(item, after)` | Cards on a settings page, a button on Home |
| `ns.Pages.AddPage(page, after)`, `ns.Pages.AddTab(tab)`, `ns.Pages.DbIO` | A whole settings page, and pages that share one sidebar entry as tabs |
| `ns.Move.AddAnchor(def, after)` | A window to place while moving frames, as a box of its size |
| `ns.MinimapIcon:AddAction(item)` | A line in the minimap icon's menu |
| `ns.Share.AddKeys(part, keys)` | Settings to back up with one of VoltUI's parts |
| `ns.Profiles.AddData(keys)` | Things it notes in `VoltUIDB` (not settings), shared by every profile. VoltUI remembers them, so they're kept out of the profile swap at the next load too |
| `VoltUI:SetDropRecord(fn)` | Its record of what you've looted, for *Drops from* on item tooltips: `fn()` gives `{ [source] = { name, loots, it = { ["itemID"] = { seen } } } }`, a source starting `o` for a chest or node |
| `VoltUI:PlansLevelling(name)` | Says it plans the player's levelling, before login: the ForeverDB Companion's leveling window goes, once |

## Files

| File | Contents |
|---|---|
| `VoltUI.toc` | Manifest |
| `Style.lua` | The shared look: panels, borders, buttons, bars, drag overlays, rarity glow, fonts |
| `Core.lua` | Settings and `/volt` |
| `UnitFrames.lua` | Player, target, target-of-target and pet frames, target auras, combo pips |
| `FrameExtras.lua` | Mana while shapeshifted, pet experience, the regen tick and the extra texts on the unit frames |
| `Raid.lua` | VoltUI's own party and raid frames: secure group headers, tiles, layout, the preview, hiding the game's |
| `RaidAuras.lua` | Debuffs on the party and raid frames, removable ones first |
| `HealMode.lua` | Heal mode (its own settings set, on by hand or by your role) and click-casting |
| `Dispel.lua` | Dispel windows and the dispel warning with its sound |
| `Nameplates.lua` | VoltUI's look on the game's own nameplates |
| `Castbar.lua` | Cast bars for you and your target; the game's breath and swing timers in VoltUI's look |
| `ActionBars.lua` | Action, stance, pet and totem bars, the menu and bag buttons, and the XP and reputation bars |
| `ProcGlow.lua` | The proc glow on the action bars: the game's own, and VoltUI's list of procs by class |
| `Controls.lua` | The settings controls: sliders, switches, choices, colour swatches, buttons, notes, cards, scrolling areas and text boxes |
| `Errors.lua` | The error catcher and its page |
| `Pages.lua` | Every settings page: its cards, rows, where its settings live, copying and resetting |
| `Share.lua` | Export and import: the string, its parts, bringing one in and undoing it |
| `Move.lua` | Moving frames: the toolbar, the grid, snapping and pixel nudges |
| `EditMode.lua` | The settings window: sidebar, search, pages, copy and reset |
| `MinimapIcon.lua` | The minimap icon and its menu |
| `Loot.lua` | Loot window |
| `Minimap.lua` | Square minimap and info strip, where it sits and its size |
| `WorldMap.lua` | Zone level labels and the map window's look |
| `Timers.lua` | Timers: each class's cooldowns, buffs, procs, target debuffs, totems and imbues, with pulses and flashes |
| `QuestieSkin.lua` | VoltUI's look for the Questie add-on, if it's installed |
| `Bags.lua` | Bag and bank windows, categories, settings panel |
| `Media/` | The bar textures (`Bar*.tga`, made by `tools/make_bars.py`), hatching and rounded corners |
| `Companion.lua` | `/volt foreverdb`: keeps only the ForeverDB Companion's leveling window |
| `Tooltips.lua` | Tooltip style, rarity border, extra item lines, other add-ons' lines on creatures |
| `Junk.lua` | Sells grey items at vendors |
| `GuildBank.lua` | The game's guild bank window in VoltUI's look |
| `GroupFinder.lua` | The group finder's listings laid out to be read at a glance |
| `Fonts/` | Bundled fonts and their licences |
