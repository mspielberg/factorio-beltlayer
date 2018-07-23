local Editor = require("Editor")

local surface_name = "plumbing"
local pipe_capacity = game.entity_prototypes["pipe"].fluid_capacity
local pipe_to_ground_capacity = game.entity_prototypes["pipe-to-ground"].fluid_capacity

--[[
  {
    fluid_name = "water",
    force = game.forces["player"],
    pipes = {
      [x] = {
        [y] = true,
        ...
      },
      ...
    },
    pipe_to_grounds = {
      [x] = {
        [y] = direction,
        ...
      },
      ...
    },
    vias = {
      [unit_number] = via_aboveground_entity,
      ...
    }
  }
]]

--[[
  {
    "surface_name" = {
      [x] = {
        [y] = network,
        ...
      },
      ...
    },
    ...
  }
]]
global.network_for_via = global.network_for_via or {}
local network_for_via = global.network_for_via

-- Network class
local Network = {}
function Network:can_absorb(other_network)
  return other_network.fluid_name == self.fluid_name or other_network.fluid_name == nil or self.fluid_name == nil
end

function Network:absorb(other_network)
  if not self.fluid_name then
    self.fluid_name = other_network.fluid_name
  end
  for x, ys in pairs(other_network.pipes) do
    for y in pairs(ys) do
      self.add_pipe(x, y)
    end
  end
  for x, ys in pairs(other_network.pipe_to_grounds) do
    for y, direction in pairs(ys) do
      self.add_pipe_to_ground(x, y, direction)
    end
  end
  for _, via in pairs(other_network.vias) do
    self.vias[#self.vias+1] = via
  end
end

function Network:add_pipe(x,y)
  if not self.pipes[x] then self.pipes[x] = {} end
  self.pipes[x][y] = true
end

function Network:add_pipe_to_ground(x, y, direction)
  if not self.pipe_to_grounds[x] then self.pipe_to_grounds[x] = {} end
  self.pipe_to_grounds[x][y] = direction
end

function Network:balance()
  local total_volume = 0
  local total_temperature = 0
  for unit_number, via in ipairs(self.vias) do
    if via.valid then
    else
      self.vias[unit_number] = nil
    end
  end
end

function Network:create_underground_entities()
end

function Network:destroy_underground_entities()
end

function Network:foreach_underground_entity(callback)
  local surface = game.surfaces[surface_name]
  for x, ys in pairs(self.pipes) do
    for y in pairs(ys) do
      local pipe = surface.find_entity("pipe", {x,y})
      if pipe then
        callback(pipe)
      end
    end
  end
  for x, ys in pairs(self.pipe_to_grounds) do
    for y, direction in pairs(ys) do
      local entity = surface.find_entity("pipe-to-ground", {x,y})
      if entity then
        callback(entity)
      end
    end
  end
  for _, via in pairs(self.vias) do
    local entity = surface.find_entity("plumbing-underground-via", via.position)
    if entity then
      callback(entity)
    end
  end
end

function Network:set_fluid(fluid_name)
  self.fluid_name = fluid_name
  if Editor.is_active() then
    self.foreach_underground_entity(function(entity)
      entity.fluidbox[1] = {name = self.fluid_name, amount = pipe_capacity}
    end)
  end
end

function Network:infer_fluid_from_vias()
  local inferred_fluid
  for _, via in pairs(self.vias) do
    if inferred_fluid then
      local via_fluid = via.fluidbox[1].name
      if via_fluid and via_fluid ~= inferred_fluid then
        return nil
      end
    else
      inferred_fluid = via.fluidbox[1].name
    end
  end
  return inferred_fluid
end