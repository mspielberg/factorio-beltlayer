local Scheduler = require "lualib.Scheduler"

local M = {}

local Connector = {}
local update_interval = 300
local all_connectors

function M.on_init()
  global.all_connectors = {}
  M.on_load()
end

function M.on_load()
  all_connectors = global.all_connectors
  update_interval = settings.global["beltlayer-update-interval"].value
  for _, connector in pairs(all_connectors) do
    M.restore(connector)
    Scheduler.schedule({connector.next_tick or 0, connector.id}, function(t) connector:update(t) end)
  end
end

function M.new(above_connector_entity, above_container, below_container)
  local self = {
    id = above_connector_entity.unit_number,
    above_loader = above_connector_entity,
    above_inv = above_container.get_inventory(defines.inventory.chest),
    below_inv = below_container.get_inventory(defines.inventory.chest),
    above_to_below = above_connector_entity.loader_type == "input",
    items_per_tick = above_connector_entity.prototype.belt_speed * 32 * 2 / 9,
    next_tick = nil,
  }
  all_connectors[self.id] = self
  self = M.restore(self)
  self:update(game.tick)
end

function M.restore(self)
  return setmetatable(self, { __index = Connector })
end

function M.for_entity(above_connector_entity)
  return all_connectors[above_connector_entity.unit_number]
end

function M.on_runtime_mod_setting_changed(_, setting, _)
  if setting == "beltlayer-update-interval" then
    update_interval = settings.global[setting].value
  end
end

function Connector:valid()
  return self.above_loader and self.above_loader.valid and
    self.above_inv and self.above_inv.valid and
    self.below_inv and self.below_inv.valid
end

function Connector:rotate()
  if not self:valid() then return end
  self.above_to_below = self.above_loader.loader_type == "input"
  self.next_tick = nil
  self:update(game.tick)
end

local function from_to_inventories(self)
  if self.above_to_below then
    return self.above_inv, self.below_inv
  end
  return self.below_inv, self.above_inv
end

local function transfer_special(from, to, name)
  -- search for empty stack in target inventory
  for i=1,#to do
    local to_stack = to[i]
    if not to_stack.valid_for_read then
      local from_stack = from.find_item_stack(name)
      if from_stack then
        to_stack.swap_stack(from_stack)
        return to_stack.count
      else
        return 0
      end
    end
  end
  return 0
end

local function transfer(self, from, to)
  for name, count in pairs(from.get_contents()) do
    local proto = game.item_prototypes[name]
    local transferred = 0

    if proto.type ~= "item" then
      transferred = transfer_special(from, to, name)
    else
      transferred = to.insert{name = name, count = count}
      if transferred > 0 then
        from.remove{name = name, count = transferred}
      end
    end

    if transferred == 0 then
      -- all full
      return
    end
  end
end

function Connector:update(tick)
  if not self:valid() then
    if self.id then
      all_connectors[self.id] = nil
    else
      -- Invalid connector may have been scheduled before configchange migration
      -- removed it from global.all_connectors.
      for key, connector in pairs(all_connectors) do
        if connector == self then
          all_connectors[key] = nil
        end
      end
    end
    return
  end

  -- Rotations may result in multiple updates being scheduled simultaneously.
  -- Ignore unless this is the "next" tick.
  if self.next_tick and tick < self.next_tick then return end

  local from, to = from_to_inventories(self)
  transfer(self, from, to)

  self.next_tick = tick + update_interval
  Scheduler.schedule({self.next_tick, self.id}, function(t) self:update(t) end)
end

function M.on_tick(tick)
  Scheduler.on_tick(tick)
end

return M