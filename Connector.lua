local M = {}

local Connector = {}

local all_connectors

function M.on_init()
  global.all_connectors = {}
  M.on_load()
end

function M.on_load()
  all_connectors = global.all_connectors
  for _, connector in pairs(all_connectors) do
    M.restore(connector)
  end
end

function M.new(above_connector_entity, above_container, below_container)
  local self = {
    above_loader = above_connector_entity,
    above_inv = above_container.get_inventory(defines.inventory.chest),
    below_inv = below_container.get_inventory(defines.inventory.chest),
    above_to_below = above_connector_entity.loader_type == "input",
  }
  all_connectors[above_connector_entity.unit_number] = self
  return M.restore(self)
end

function M.restore(self)
  return setmetatable(self, { __index = Connector })
end

function M.for_entity(above_connector_entity)
  return all_connectors[above_connector_entity.unit_number]
end

function Connector:valid()
  return self.above_inv and self.above_inv.valid and self.below_inv and self.below_inv.valid
end

function Connector:rotate()
  self.above_to_below = self.above_loader.loader_type == "input"
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

function Connector:transfer()
  local from, to = self.above_inv, self.below_inv
  if not self.above_to_below then
    from, to = to, from
  end
  for name, count in pairs(from.get_contents()) do
    local proto = game.item_prototypes[name]
    if proto.type ~= "item" then
      transfer_special(from, to, name)
    else
      local inserted = to.insert{name = name, count = count}
      if inserted == 0 then
        -- all full
        return
      end
      from.remove{name = name, count = inserted}
    end
  end
end

function M.update()
  local connector
  global.connector_iter, connector = next(all_connectors, global.connector_iter)
  if not connector then
    global.connector_iter, connector = next(all_connectors, global.connector_iter)
  end
  if connector then
    if connector:valid() then
      connector:transfer()
    else
      all_connectors[global.connector_iter] = nil
    end
  end
end

return M