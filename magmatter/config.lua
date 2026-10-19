-- config.lua : Magmatter plasma feeder (GTNH, OpenComputers)
-- Addresses: right-click a component with the OC Analyzer, click the chat line to copy.
local sides = require("sides")
 
local config = {
  -- ===== Components =====
  greenInterfaceAddress  = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", -- adapter next to ME dual interface / controller of GREEN (input) subnet
  purpleInterfaceAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", -- adapter next to ME dual interface of PURPLE (plasma storage) subnet
  databaseAddress        = nil, -- optional: leave nil to use the Database Upgrade (Tier 3) installed in this computer
 
  outputTransposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", -- moves plasma purple -> blue
  purpleSide = sides.west,  -- side touching the PURPLE interface
  blueSide   = sides.east,  -- side touching the BLUE (output) interface
 
  clearTransposerAddress = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", -- empties green
  greenSide = sides.west,   -- side touching the GREEN interface
  trashSide = sides.east,   -- side touching the void / trash tank
 
  interfaceConfigSlot = 1,  -- config slot of the purple interface used to select the plasma
  interfaceFluidIndex = 1,  -- 2nd argument ("index") of setFluidInterfaceConfiguration(slot, index, database, entry)
 
  -- ===== The two fluids to subtract (confirmed names) =====
  enlarged = { name = "spatialfluid",  label = "spatially enlarged" },
  tachyon  = { name = "temporalfluid", label = "tachyon rich" },
 
  -- Items (by exact label) that live in the green network permanently and must NOT be cleared,
  -- e.g. { "Cosmic Neutronium Dust" }. Leave empty to clear every item.
  ignoreItems = {},
 
  -- ===== Behaviour =====
  chunk        = 16000,
  retrySeconds = 5,
  idleSeconds  = 5,
  logFile      = "magmatter.log",
}
 
-- ===== Magmatter plasmas =====
-- db = slot in the Database Upgrade holding that plasma's fluid drop.
-- Fill the database in THIS order (slot 1 = Awakened Draconium, ...), or edit db numbers.
local list = {
  { "Awakened Draconium",  "plasma.draconiumawakened" },
  { "Bedrockium",          "plasma.bedrockium" },
  { "Celestial Tungsten",  "plasma.celestialtungsten" },
  { "Chromatic Glass",     "plasma.chromaticglass" },
  { "Cosmic Neutronium",   "plasma.cosmicneutronium" },
  { "Draconium",           "plasma.draconium" },
  { "Dragonblood",         "plasma.dragonblood" },
  { "Flerovium",           "plasma.flerovium_gt5u" },
  { "Hypogen",             "plasma.hypogen" },
  { "Ichorium",            "plasma.ichorium" },
  { "Infinity",            "plasma.infinity" },
  { "Neutronium",          "plasma.neutronium" },
  { "Rhugnor",             "plasma.rhugnor" },
  { "Six-Phased Copper",   "plasma.sixphasedcopper" },
  { "Tritanium",           "plasma.tritanium" },
}
config.plasmas = {}
for i, p in ipairs(list) do config.plasmas[p[1]] = { fluid = p[2], db = i } end
 
-- ===== Plasma selection =====
-- The dust in the green network picks the plasma: its label/name (e.g. "Awakened Draconium Dust")
-- is stripped of "dust" and matched to the plasma list above.
-- Amount sent to blue = |enlarged - tachyon| * multiplier
config.multiplier = 144  -- the "x" (same factor God Forge Control uses for magmatter)
 
return config
 
