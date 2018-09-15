local Scheduler = require "lualib.Scheduler"

local M = {}

local Connector = {}
local UPDATE_INTERVAL = 300
local all_connectors

function M.on_init()
  global.all_connectors = {}
  M.on_load()
end

function M.on_load()
  all_connectors = global.all_connectors
  for _, connector in pairs(all_connectors) do
    M.restore(connector)
    if connector.next_tick then
      Scheduler.schedule(connector.next_tick, function(tick) connector:update(tick) end)
    end
  end
end

function M.new(above_connector_entity, above_container, below_container)
  local self = {
    unit_number = above_connector_entity.unit_number,
    above_loader = above_connector_entity,
    above_inv = above_container.get_inventory(defines.inventory.chest),
    below_inv = below_container.get_inventory(defines.inventory.chest),
    above_to_below = above_connector_entity.loader_type == "input",
    items_per_tick = above_connector_entity.prototype.belt_speed * 32 * 2 / 9,
    next_tick = nil,
  }
  all_connectors[self.unit_number] = self
  self = M.restore(self)
  self:update()
end

function M.restore(self)
  return setmetatable(self, { __index = Connector })
end

function M.for_entity(above_connector_entity)
  return all_connectors[above_connector_entity.unit_number]
end

function Connector:valid()
  return self.above_loader and self.above_loader.valid and
    self.above_inv and self.above_inv.valid and
    self.below_inv and self.below_inv.valid
end

function Connector:rotate()
  if not self:valid() then return end
  self.above_to_below = self.above_loader.loader_type == "input"
  self.above_inv.setbar()
  self.below_inv.setbar()
  self.stack_size = nil
  self.next_tick = nil
  self:update()
end

local function from_to_inventories(self)
  if self.above_to_below then
    return self.above_inv, self.below_inv
  end
  return self.below_inv, self.above_inv
end

local function transfer_special(from, to, name)
  -- search for empty stack
  for i=1,#to do
    local stack = to[i]
    if not stack.valid_for_read then
      local from_stack = from.find_item_stack(name)
      if from_stack then
        stack.swap_stack(from_stack)
      else
        return
      end
    end
  end
end

local function transfer(self, from, to)
  local smallest_stack_size
  local items_to_buffer = math.floor(self.items_per_tick * UPDATE_INTERVAL * 1.5)
  local items_to_transfer = items_to_buffer - to.get_item_count()
  if items_to_transfer <= 0 then
    for i=1,#to do
      if to[i].valid_for_read then
        return to[i].prototype.stack_size
      end
    end
    -- should be unreachable
    error("no room to transfer, but also nothing in destination buffer")
  end

  for name, count in pairs(from.get_contents()) do
    if count > items_to_transfer then
      count = items_to_transfer
    end

    local proto = game.item_prototypes[name]
    local stack_size = proto.stack_size
    if not smallest_stack_size or stack_size < smallest_stack_size then
      smallest_stack_size = stack_size
    end

    if proto.type ~= "item" then
      transfer_special(from, to, name)
      items_to_transfer = items_to_transfer - 1
    else
      local inserted = to.insert{name = name, count = count}
      if inserted == 0 then
        -- all full
        return smallest_stack_size
      end
      from.remove{name = name, count = inserted}
      items_to_transfer = items_to_transfer - inserted
    end

    if items_to_transfer <= 0 then
      return smallest_stack_size or 50
    end
  end

  return smallest_stack_size or 50
end

local function set_buffer_limit(self, from_inventory, stack_size)
  local items_to_buffer = self.items_per_tick * UPDATE_INTERVAL
  local stacks_to_buffer = math.ceil(items_to_buffer / stack_size)
  from_inventory.setbar(stacks_to_buffer + 1)
end

function Connector:update(tick)
  if not self:valid() then return end
  tick = tick or game.tick
  if self.next_tick and tick < self.next_tick then
    return
  end

  local from, to = from_to_inventories(self)
  local stack_size = transfer(self, from, to)
  if not self.stack_size or self.stack_size ~= stack_size then
    self.stack_size = stack_size
    set_buffer_limit(self, from, stack_size)
  end

  local next_tick = game.tick + UPDATE_INTERVAL
  self.next_tick = next_tick
  Scheduler.schedule(next_tick, function(t) self:update(t) end)
end

function M.on_tick(tick)
  Scheduler.on_tick(tick)
end

return M