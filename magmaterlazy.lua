-- main.lua : Magmatter plasma feeder
-- green (input) -> |enlarged - tachyon| * mult -> plasma purple -> blue -> clear green
-- Never crashes / never gives up: every failure waits `retrySeconds` and retries.
-- Stop with Q (or Ctrl+Alt+C).
-- doc:
-- Program par claude code, il demande un subnet green (output des elements)
-- subnet blue (input des elements/plasma), purple (storage des plasma)
-- dans le subnet vert placer une storage bus pour virer la magmatter ailleur, une stocking set en space et time pour re insertion.
-- les 3 channels ont un adapteur connecté à une interface, le channel purple to blue a un transposer d'une interface vers un tank 
-- le tank est storage bus sur le blue, il y a un autre transposer depuis l'interface du sub green vers une trash à item.
 
local component = require("component")
local event     = require("event")
local CFG       = require("config")
 
------------------------------------------------------------------
-- Logging (screen + file, file errors ignored)
------------------------------------------------------------------
local function log(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
  local line = os.date("%d.%m.%Y %H:%M:%S") .. " " .. table.concat(parts, " ")
  print(line)
  pcall(function()
    local f = io.open(CFG.logFile, "a")
    if f then f:write(line .. "\n") f:close() end
  end)
end
 
------------------------------------------------------------------
-- Stop / interrupt handling
------------------------------------------------------------------
local STOP = {}                                  -- sentinel error value
 
local function isInterrupt(err)
  return err == STOP or (type(err) == "string" and err:find("interrupted", 1, true) ~= nil)
end
 
-- sleeps `s` seconds, wakes early and stops when Q is pressed
local function wait(s)
  local deadline = os.time() -- fallback (unused when events work)
  local ok, name, _, _, code = pcall(event.pull, s, "key_down")
  if not ok then error(name, 0) end              -- "interrupted" from Ctrl+Alt+C
  if name == "key_down" and code == 16 then error(STOP, 0) end   -- Q
end
 
-- retry fn until it returns a truthy value without error
local function retry(label, fn)
  while true do
    local res = table.pack(pcall(fn))
    if res[1] and res[2] then return table.unpack(res, 2, res.n) end
    if not res[1] and isInterrupt(res[2]) then error(res[2], 0) end
    log("[retry]", label, "->", res[1] and "no result" or tostring(res[2]))
    wait(CFG.retrySeconds)
  end
end
 
local function getComponent(address, what)
  return retry("component " .. what, function()
    local full = component.get(address)
    if not full then error("not found: " .. tostring(address)) end
    return component.proxy(full)
  end)
end
 
------------------------------------------------------------------
-- Green network reading
------------------------------------------------------------------
local function matches(fluid, spec)
  if fluid.name and fluid.name == spec.name then return true end
  local label = fluid.label and fluid.label:lower() or ""
  return spec.label ~= nil and label:find(spec.label, 1, true) ~= nil
end
 
-- lowercase, letters/digits only: "Six-Phased Copper Dust" -> "sixphasedcopperdust"
local function norm(s) return (tostring(s or ""):lower():gsub("[^%w]", "")) end
 
-- normalized plasma name -> plasma label (e.g. "sixphasedcopper" -> "Six-Phased Copper")
local plasmaByNorm = {}
for label in pairs(CFG.plasmas) do plasmaByNorm[norm(label)] = label end
 
-- "Awakened Draconium Dust" / "Dust of Draconium" / "dustDraconium" -> "Draconium"
local function plasmaFromDust(item)
  -- same patterns as the God Forge Control repo: "Pile of X Dust" and "X Dust"
  if item.label then
    local name = item.label:match("Pile of%s(.+)%sDust") or item.label:match("(.+) Dust")
    if name and plasmaByNorm[norm(name)] then return plasmaByNorm[norm(name)] end
  end
  local candidates = {}
  for _, raw in ipairs({ item.label, item.name }) do
    if raw then
      local n = norm(raw)
      candidates[#candidates + 1] = n:gsub("dust$", "")            -- "...dust"
      candidates[#candidates + 1] = n:gsub("^dustof", "")           -- "dust of ..."
      candidates[#candidates + 1] = n:gsub("^dust", "")             -- "dust..."
    end
  end
  for _, c in ipairs(candidates) do
    if plasmaByNorm[c] then return plasmaByNorm[c] end
  end
  return nil
end
 
local function isDust(item)
  return norm(item.label):find("dust", 1, true) ~= nil or norm(item.name):find("dust", 1, true) ~= nil
end
 
-- items listed in CFG.ignoreItems (by label) are never counted, pulled or used as the input dust
local ignored = {}
for _, label in ipairs(CFG.ignoreItems or {}) do ignored[label] = true end
local function ignoredItem(item) return ignored[item.label] == true end
 
-- returns { e, t, kinds, dust (item or nil), plasma (label or nil) }
-- kinds = number of different fluids + items present (0 = green is empty)
local function readGreen(green)
  return retry("read green network", function()
    local fluids = green.getFluidsInNetwork()
    if type(fluids) ~= "table" then error("getFluidsInNetwork returned " .. type(fluids)) end
    local items = green.getItemsInNetwork()
    if type(items) ~= "table" then error("getItemsInNetwork returned " .. type(items)) end
 
    local e, t, kinds = 0, 0, 0
    for _, f in ipairs(fluids) do
      if (f.amount or 0) > 0 then
        kinds = kinds + 1
        if matches(f, CFG.enlarged) then e = e + f.amount
        elseif matches(f, CFG.tachyon) then t = t + f.amount end
      end
    end
 
    local dust, plasma
    for _, it in ipairs(items) do
      if (it.size or 0) > 0 and not ignoredItem(it) then
        kinds = kinds + 1
        if not dust and isDust(it) then
          dust = it
          plasma = plasmaFromDust(it)
        end
      end
    end
    return { e = e, t = t, kinds = kinds, dust = dust, plasma = plasma, items = items, fluids = fluids }
  end)
end
 
------------------------------------------------------------------
-- Actions
------------------------------------------------------------------
-- GTNH wiki lists setFluidInterfaceConfiguration(slot, index, database, entry), older builds
-- take (slot, database, entry). Try the documented form first, remember whichever works.
local workingForm = nil
 
-- The Database Upgrade lives in the computer itself (like the God Forge Control repo uses
-- component.database). It is filled automatically with the plasma fluid drops at startup.
local function database()
  if CFG.databaseAddress then
    local full = component.get(CFG.databaseAddress)
    if full then return component.proxy(full) end
  end
  if component.isAvailable("database") then return component.database end
  error("no Database Upgrade found in this computer")
end
 
local function fillDatabase()
  retry("fill database with plasma fluid drops", function()
    local db = database()
    for label, p in pairs(CFG.plasmas) do
      local ok = db.set(p.db, "ae2fc:fluid_drop", 0, '{Fluid:"' .. p.fluid .. '"}')
      if ok == false then error("cannot save " .. label .. " to database") end
    end
    -- drops of the two input fluids, used to pull them out of the green network when clearing
    db.set(79, "ae2fc:fluid_drop", 0, '{Fluid:"' .. CFG.enlarged.name .. '"}')
    db.set(80, "ae2fc:fluid_drop", 0, '{Fluid:"' .. CFG.tachyon.name .. '"}')
    return true
  end)
end
 
local docLogged = false
local function logSignature(purple, fn)
  if docLogged then return end
  docLogged = true
  pcall(function()
    log("[info] real signature on your adapter:", tostring(component.doc(purple.address, fn)))
    local names = {}
    for name in pairs(component.methods(purple.address)) do
      if name:lower():find("interface") or name:lower():find("config") then names[#names + 1] = name end
    end
    table.sort(names)
    log("[info] interface/config methods:", table.concat(names, ", "))
  end)
end
 
-- Sets a fluid config slot on an ME interface (single attempt, errors if every form fails)
local function setFluidConfig(purple, slot, fluid, entry)
  do
    local db = database().address
    local idx = CFG.interfaceFluidIndex or 1
 
    -- Your adapter reported "bad argument #2 (table expected)" for the (slot, database, entry)
    -- forms, so the fluid-stack-table forms come first.
    local forms = {
      function() return purple.setFluidInterfaceConfiguration(slot, { name = fluid, amount = 1 }) end,
      function() return purple.setFluidInterfaceConfiguration(slot, { name = fluid }) end,
      function() return purple.setFluidInterfaceConfiguration(slot, { name = fluid, amount = 1000 }) end,
      function() return purple.setFluidInterfaceConfiguration(slot, idx, db, entry) end,
      function() return purple.setFluidInterfaceConfiguration(slot, db, entry) end,
      function() return purple.setInterfaceConfiguration(slot, db, entry, 1) end,
    }
    local order = {}
    if workingForm then order[1] = workingForm end
    for i = 1, #forms do if i ~= workingForm then order[#order + 1] = i end end
 
    local errs = {}
    for _, i in ipairs(order) do
      local ok, res = pcall(forms[i])
      if ok and res then workingForm = i return true end
      if not ok and isInterrupt(res) then error(res, 0) end
      errs[#errs + 1] = "form" .. i .. ": " .. tostring(ok and "returned false" or res)
    end
    logSignature(purple, "setFluidInterfaceConfiguration")
    error(table.concat(errs, " | "))
  end
end
 
local function selectPlasma(purple, entry, fluid)
  retry("select plasma on purple interface", function()
    return setFluidConfig(purple, CFG.interfaceConfigSlot, fluid, entry)
  end)
end
 
local function movePlasma(xp, amount)
  local remaining = amount
  while remaining > 0 do
    local want = math.min(remaining, CFG.chunk)
    local moved = retry("move plasma purple -> blue", function()
      local ok, n = xp.transferFluid(CFG.purpleSide, CFG.blueSide, want)
      if not ok or type(n) ~= "number" or n <= 0 then
        error("nothing moved (no plasma in purple or blue full)")
      end
      return n
    end)
    remaining = remaining - moved
    log(string.format("moved %d mB, %d left", moved, math.max(remaining, 0)))
  end
end
 
-- Items/fluids sitting in the ME network are NOT visible to a transposer: they have to be pulled
-- into the green interface first (interface config = "keep N of this in stock"), and then the
-- transposer moves them from the interface to the trash.
local lastLabel, lastSize, sameRounds = nil, nil, 0
local skipped = {}   -- labels that did not shrink for several rounds (skipped until green is empty)
 
-- Stores exactly `it` in database slot `dbSlot`. GT dusts share one item id and differ only by
-- damage, so the filter must contain name+damage; the stored entry is read back and checked,
-- otherwise AE would silently store "the first item" (= Cosmic Neutronium Dust).
-- `store` ignores the filter on this build (it returned the wrong dust), so instead we store a
-- whole batch of items into database slots FIRST_DB..LAST_DB and search the database for the
-- entry whose label is the dust we want. Returns that database slot.
local FIRST_DB, LAST_DB = 16, 78
 
local function findInDatabase(db, label)
  for s = FIRST_DB, LAST_DB do
    local ok, stack = pcall(db.get, s)
    if ok and type(stack) == "table" and stack.label == label then return s end
  end
  return nil
end
 
local function storeItem(green, db, it)
  local slot = findInDatabase(db, it.label)           -- already stored earlier?
  if slot then return slot end
 
  local filters = { {}, { name = it.name }, { name = it.name, damage = it.damage } }
  for _, filter in ipairs(filters) do
    local ok, res = pcall(green.store, filter, db.address, FIRST_DB, LAST_DB - FIRST_DB + 1)
    if not ok and isInterrupt(res) then error(res, 0) end
    if ok and res then
      slot = findInDatabase(db, it.label)
      if slot then return slot end
    end
  end
  error("'" .. tostring(it.label) .. "' not found in database slots " .. FIRST_DB .. "-" .. LAST_DB
    .. " after storing the network items")
end
 
local function pullIntoInterface(green, state)
  local db = database()
 
  -- Take the FIRST dust of the green network (then, if there is no dust left, the first other
  -- item), put exactly that one in config slot 1 and nothing in the other slots.
  local dusts, others = {}, {}
  for _, it in ipairs(state.items or {}) do
    if (it.size or 0) > 0 and not ignoredItem(it) and not skipped[it.label] then
      if isDust(it) then dusts[#dusts + 1] = it else others[#others + 1] = it end
    end
  end
  local it = dusts[1] or others[1]
  if not it then
    if next(skipped) ~= nil then skipped = {} end   -- everything was skipped once: start over
  else
    -- stuck protection: same item and no decrease for 4 rounds -> skip it for now
    if it.label == lastLabel and lastSize and it.size >= lastSize then
      sameRounds = sameRounds + 1
    else
      sameRounds = 0
    end
    lastLabel, lastSize = it.label, it.size
    if sameRounds >= 4 then
      log("[warn] " .. tostring(it.label) .. " does not shrink, skipping it for now")
      skipped[it.label] = true
      sameRounds = 0
      lastLabel, lastSize = nil, nil
    end
 
    for s = 2, 9 do pcall(green.setInterfaceConfiguration, s) end  -- keep the other slots empty
    local ok, err = pcall(function()
      local dbSlot = storeItem(green, db, it)
      if not green.setInterfaceConfiguration(1, db.address, dbSlot, math.min(it.size, 64)) then
        error("setInterfaceConfiguration returned false")
      end
    end)
    if ok then
      log("[clear] pulling " .. tostring(it.label) .. " x" .. tostring(it.size))
    else
      if isInterrupt(err) then error(err, 0) end
      log("[warn] cannot pull item " .. tostring(it.label) .. ": " .. tostring(err))
    end
  end
 
end
 
-- remove the "keep in stock" configs again so new inputs are not pulled into the interface
local function releaseInterface(green)
  for s = 1, 9 do pcall(green.setInterfaceConfiguration, s) end
  for s = 1, 9 do pcall(green.setFluidInterfaceConfiguration, s) end
end
 
local function clearGreen(green, xp)
  while true do
    local state = readGreen(green)
    if state.kinds == 0 then
      skipped, lastLabel, lastSize, sameRounds = {}, nil, nil, 0
      releaseInterface(green)
      return
    end
    pullIntoInterface(green, state)
    wait(1)  -- give the interface a moment to import the configured stacks
    local moved = 0
    pcall(function()  -- dust (items) too
      for slot = 1, xp.getInventorySize(CFG.greenSide) or 0 do
        local n = xp.transferItem(CFG.greenSide, CFG.trashSide, 64, slot)
        if type(n) == "number" then moved = moved + n end
      end
    end)
    if moved <= 0 then
      log("[retry] clear green: nothing drained")
      wait(CFG.retrySeconds)
    end
  end
end
 
------------------------------------------------------------------
-- One cycle
------------------------------------------------------------------
local function cycle(green, purple, xpOut, xpClr)
  local s = readGreen(green)
  local diff = s.e - s.t
 
  if diff == 0 then
    -- equal (non-zero) amounts: nothing to send, clear. Zero: inputs still arriving, wait.
    if s.e > 0 then clearGreen(green, xpClr) end
    return
  end
 
  local label = s.plasma
  local entry = label and CFG.plasmas[label]
  if not entry then
    -- no dust yet / unknown dust: do NOT clear green, just wait and retry
    log("[retry] no known dust in green (dust=" .. tostring(s.dust and s.dust.label) .. ")")
    wait(CFG.retrySeconds)
    return
  end
  local amount = math.floor(math.abs(diff) * 144)
  local rule = { plasma = label .. " (" .. entry.fluid .. ")", mult = CFG.multiplier, db = entry.db }
  log(string.format("enlarged=%d tachyon=%d diff=%d -> %s = %d mB",
    s.e, s.t, diff, rule.plasma, amount))
 
  if amount > 0 then
    selectPlasma(purple, rule.db, entry.fluid)
    movePlasma(xpOut, amount)
  end
  clearGreen(green, xpClr)
  log("cycle done")
end
 
------------------------------------------------------------------
-- Main (outer guard restarts on any error except stop/interrupt)
------------------------------------------------------------------
local function run()
  local green  = getComponent(CFG.greenInterfaceAddress,   "green interface")
  local purple = getComponent(CFG.purpleInterfaceAddress,  "purple interface")
  local xpOut  = getComponent(CFG.outputTransposerAddress, "output transposer")
  local xpClr  = getComponent(CFG.clearTransposerAddress,  "clear transposer")
  fillDatabase()
  log("Magmatter feeder started (Q to quit)")
 
  while true do
    local ok, err = pcall(cycle, green, purple, xpOut, xpClr)
    if not ok then
      if isInterrupt(err) then error(err, 0) end
      log("[error]", tostring(err))
      wait(CFG.retrySeconds)
    else
      wait(CFG.idleSeconds)
    end
  end
end
 
while true do
  local ok, err = pcall(run)
  if not ok then
    if isInterrupt(err) then log("Stopped by user.") return end
    log("[restart]", tostring(err))
    local ok2, err2 = pcall(wait, CFG.retrySeconds)
    if not ok2 and isInterrupt(err2) then log("Stopped by user.") return end
  end
end
 