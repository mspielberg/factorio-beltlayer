local BaseEditor = require "lualib.BaseEditor.BaseEditor"
local Connector = require "Connector"
local util = require "util"

local M = {}

local Editor = {}
local super = BaseEditor.class
setmetatable(Editor, { __index = super })

function M.new()
  local self = BaseEditor.new("beltlayer")
  self.valid_editor_types = {
    "blueprint", "blueprint-book", "deconstruction-item", "upgrade-item",
    "transport-belt", "underground-belt", "splitter",
  }
  return M.restore(self)
end

function M.restore(self)
  return setmetatable(self, { __index = Editor })
end

local debug = function() end
-- debug = log

local function find_in_area(args)
  local area = args.area
  if area.left_top.x >= area.right_bottom.x or area.left_top.y >= area.right_bottom.y then
    args.position = area.left_top
    args.area = nil
  end
  local surface = args.surface
  args.surface = nil
  return surface.find_entities_filtered(args)
end

local function is_connector_name(name)
  return name:find("%-beltlayer%-connector$")
end

local function is_connector(entity)
  return is_connector_name(entity.name)
end

local function is_connector_or_ghost(entity)
  return is_connector(entity) or (entity.name == "entity-ghost" and is_connector_name(entity.ghost_name))
end

local function is_surface_connector(self, entity)
  return is_connector(entity) and self:is_valid_aboveground_surface(entity.surface)
end

local function connector_in_area(surface, area)
  local entities = find_in_area{surface = surface, area = area}
  for _, entity in ipairs(entities) do
    if is_connector_or_ghost(entity) then
      return true
    end
  end
  return false
end

local function opposite_type(loader_type)
  if loader_type == "input" then
    return "output"
  end
  return "input"
end

function Editor:proxy_name(entity)
  local entity_name = entity.type == "entity-ghost" and entity.ghost_name or entity.name
  return util.proxy_name(entity_name, entity.type == "underground-belt" and entity.belt_to_ground_type)
end

function Editor:nonproxy_name(entity)
  local pattern = "^"..self.name..".*%-bpproxy%-"
  local _, last = entity.name:find(pattern)
  if last then
    return entity.name:sub(last + 1)
  end
  return nil
end

function Editor:create_entity_args_for_editor_entity(bpproxy)
  local create_args = super.create_entity_args_for_editor_entity(self, bpproxy)
  local name = bpproxy.name
  if name == "entity-ghost" then name = bpproxy.ghost_name end
  local type, nonproxy_name =
    name:match("^beltlayer%-([^-]*)%-?bpproxy%-(.*)$")
  if not type then return create_args end
  create_args.direction = bpproxy.direction
  create_args.type = type
  create_args.name = nonproxy_name
  return create_args
end

local function surface_counterpart(self, entity)
  local editor_surface = self:editor_surface_for_aboveground_surface(entity.surface)
  if is_connector(entity) then
    return editor_surface.find_entity(entity.name, entity.position)
  end
  return editor_surface.find_entity(self:proxy_name(entity), entity.position)
end

local function on_built_surface_connector(self, creator, entity, stack)
  local position = entity.position
  local force = entity.force

  local direction = entity.direction
  local loader_type = opposite_type(entity.loader_type)
  local editor_surface = self:editor_surface_for_aboveground_surface(entity.surface)

  -- check for existing underground connector
  local underground_connector = editor_surface.find_entities_filtered{position = position, type = "loader-1x1"}[1]
  local belt_item_inventory
  local left_tl_count
  if underground_connector then
    local left_tl = underground_connector.get_transport_line(defines.transport_line.left_line)
    left_tl_count = #left_tl
    local right_tl = underground_connector.get_transport_line(defines.transport_line.right_line)
    belt_item_inventory = game.create_inventory(#left_tl + #right_tl)
    for i = 1, left_tl_count do
      belt_item_inventory[i].set_stack(left_tl[i])
    end
    for i = 1, #right_tl do
      belt_item_inventory[left_tl_count + i].set_stack(right_tl[i])
    end
    underground_connector.destroy()
    underground_connector = nil
  end

  -- check for existing underground connector ghost
  local underground_ghost = editor_surface.find_entity("entity-ghost", position)
  if underground_ghost and underground_ghost.ghost_type == "loader-1x1" then
    direction = underground_ghost.direction
    loader_type = underground_ghost.loader_type
    entity.loader_type = opposite_type(loader_type)
  end

  local underground_connector = editor_surface.create_entity{
    name = entity.name,
    position = position,
    direction = direction,
    type = loader_type,
    force = force,
  }

  if not underground_connector then
    self.abort_build(creator, entity, stack, {"beltlayer-error.underground-obstructed"})
    return
  end

  underground_connector.last_user = entity.last_user
  underground_connector.minable = false

  -- replace items if needed
  if belt_item_inventory then
    local position = 0.99
    local left_tl = underground_connector.get_transport_line(defines.transport_line.left_line)
    for i = 1, left_tl_count do
      left_tl.insert_at(position, belt_item_inventory[i])
      position = position - 0.01
    end
    position = 0.99
    local right_tl = underground_connector.get_transport_line(defines.transport_line.right_line)
    for i = left_tl_count + 1, #belt_item_inventory do
      right_tl.insert_at(position, belt_item_inventory[i])
      position = position - 0.01
    end
    belt_item_inventory.destroy()
  end

  -- create buffer containers
  local above_container = entity.surface.find_entity("beltlayer-buffer", position)
  if not above_container then
    above_container = entity.surface.create_entity{
      name = "beltlayer-buffer",
      position = position,
      force = force,
    }
    above_container.destructible = false
  end

  local below_container = editor_surface.find_entity("beltlayer-buffer", position)
  if not below_container then
    below_container = editor_surface.create_entity{
      name = "beltlayer-buffer",
      position = position,
      force = force,
    }
    below_container.destructible = false
  end

  Connector.new(entity, above_container, below_container)
end

local function re_place_belt(surface, position)
  local belt = surface.find_entities_filtered{
    position = position,
    type = "transport-belt",
  }[1]
  if not belt then return end

  local name = belt.name
  local surface = belt.surface
  local position = belt.position
  local direction = belt.direction
  local force = belt.force
  local intermediate_name = name == "transport-belt" and "fast-transport-belt" or "transport-belt"
  local args = {
    name = intermediate_name,
    position = position,
    direction = direction,
    force = force,
    fast_replace = true,
    spill = false,
    create_build_effect_smoke = false,
  }
  surface.create_entity(args)
  args.name = name
  surface.create_entity(args)
end

function Editor:on_built_entity(event)
  local entity = event.created_entity
  if not entity.valid then return end
  local surface = entity.surface
  local position = entity.position
  local was_belt_proxy = entity.name:find("^beltlayer%-bpproxy%-")
  super.on_built_entity(self, event)

  local player = event.player_index and game.players[event.player_index]
  local stack = event.stack

  if entity.valid and is_connector(entity) then
    if self:is_valid_aboveground_surface(entity.surface) then
      on_built_surface_connector(self, player, entity, stack)
    else
      self.abort_build(player, entity, stack, {"beltlayer-error.bad-surface-for-connector"})
    end
  elseif was_belt_proxy then
    re_place_belt(surface, position)
  end
end

function Editor:on_robot_built_entity(event)
  local entity = event.created_entity
  if not entity.valid then return end
  super.on_robot_built_entity(self, event)
  if not entity.valid then return end

  if is_connector(entity) then
    if self:is_valid_aboveground_surface(entity.surface) then
      on_built_surface_connector(self, event.robot, entity, event.stack)
    else
      self.abort_build(event.robot, entity, event.stack, {"beltlayer-error.bad-surface-for-connector"})
    end
  end
end

local function insert_container_inventory_to_buffer(container, buffer)
  local inv = container.get_inventory(defines.inventory.chest)
  for i=1,#inv do
    local stack = inv[i]
    if stack.valid_for_read then
      buffer.insert(stack)
      stack.clear()
    end
  end
end

local function insert_transport_lines_to_buffer(entity, buffer)
  for i=1,2 do
    local tl = entity.get_transport_line(i)
    for j=1,#tl do
      buffer.insert(tl[j])
    end
    tl.clear()
  end
end

local upgrade_in_progress
local function upgrade_in_progress_matches(entity)
  return upgrade_in_progress and
    upgrade_in_progress.tick == game.tick and
    upgrade_in_progress.entity == entity
end

local function on_mined_surface_connector(self, entity, buffer)
  local above_container = entity.surface.find_entity("beltlayer-buffer", entity.position)
  local editor_surface = self:editor_surface_for_aboveground_surface(entity.surface)
  local below_container = editor_surface.find_entity("beltlayer-buffer", entity.position)
  local underground_connector = editor_surface.find_entity(entity.name, entity.position)
  if buffer then
    if not upgrade_in_progress_matches(entity) then
      insert_container_inventory_to_buffer(above_container, buffer)
      insert_container_inventory_to_buffer(below_container, buffer)
    end
    insert_transport_lines_to_buffer(underground_connector, buffer)
  end
  if not upgrade_in_progress_matches(entity) then
    above_container.destroy()
    below_container.destroy()
  end
  underground_connector.destroy()
end

function Editor:on_player_mined_entity(event)
  super.on_player_mined_entity(self, event)
  local entity = event.entity
  if entity.valid and is_surface_connector(self, entity) then
    on_mined_surface_connector(self, entity, event.buffer)
  end
end

function Editor:on_robot_mined_entity(event)
  super.on_robot_mined_entity(self, event)
  local entity = event.entity
  if entity.valid and is_surface_connector(self, entity) then
    if entity.to_be_upgraded() then
      local inventory = event.robot and event.robot.get_inventory(defines.inventory.robot_cargo)
      local contents = inventory and inventory.get_contents()
      for name in pairs(contents) do
        if is_connector_name(name) then
          upgrade_in_progress = {
            tick = event.tick,
            entity = entity,
          }
        end
      end
    end
    on_mined_surface_connector(self, entity, event.buffer)
  end
end

local handling_rotation = false
function Editor:on_player_rotated_entity(event)
  if handling_rotation then return end
  local entity = event.entity
  if not entity or not entity.valid then return end
  if is_connector(entity) then
    handling_rotation = true
    local surface = entity.surface
    if self:is_editor_surface(surface) then
      local aboveground_surface = self:aboveground_surface_for_editor_surface(surface)
      local above_connector = aboveground_surface.find_entity(entity.name, entity.position)
      if above_connector then
        above_connector.rotate{by_player = event.player_index}
        Connector.for_entity(above_connector):rotate()
      end
    elseif self:is_valid_aboveground_surface(surface) then
      local editor_surface = self:editor_surface_for_aboveground_surface(surface)
      local below_connector = editor_surface.find_entity(entity.name, entity.position)
      if below_connector then
        below_connector.rotate{by_player = event.player_index}
      end
      Connector.for_entity(entity):rotate()
    end
    handling_rotation = false
  end
end

function Editor:on_entity_died(event)
  local entity = event.entity
  if not entity or not entity.valid then return end
  if is_surface_connector(self, entity) then
    on_mined_surface_connector(self, entity, nil)
  end
end

------------------------------------------------------------------------------------------------------------------------
-- deconstruction

-- Set whenever a constructor ghost is deconstructed, e.g. by deconstruction tool,
-- so we can decide whether to deconstruct underground also.
local previous_connector_ghost_deconstruction_tick

local function on_player_deconstructed_surface_area(self, player, area, tool)
  local aboveground_surface = player.surface
  if not connector_in_area(aboveground_surface, area) and
     game.tick ~= previous_connector_ghost_deconstruction_tick then
    -- no connectors present, and no connector ghosts deconstructed this tick by this player
    return
  end
  local editor_surface = self:editor_surface_for_aboveground_surface(aboveground_surface)
  local underground_entities = self:order_underground_deconstruction(player, editor_surface, area, tool)
  if next(underground_entities) and
     settings.get_player_settings(player)["beltlayer-deconstruction-warning"].value then
    player.print({"beltlayer-message.marked-for-deconstruction", #underground_entities})
  end
end

local function on_player_deconstructed_underground_area(self, player, area, tool)
  local editor_surface = player.surface
  local underground_entities = self:order_underground_deconstruction(player, editor_surface, area, tool)
  for _, entity in ipairs(underground_entities) do
    if is_connector(entity) then
      local counterpart = surface_counterpart(self, entity)
      if counterpart then
        entity.order_deconstruction(player.force, player)
      end
      local bpproxy = self:surface_counterpart_bpproxy(entity)
      if bpproxy then
        bpproxy.destroy()
      end
    end
  end
end

local function on_player_deconstructed_area(self, player, area, tool)
  local surface = player.surface
  if self:is_valid_aboveground_surface(surface) then
    return on_player_deconstructed_surface_area(self, player, area, tool)
  elseif self:is_editor_surface(surface) then
    return on_player_deconstructed_underground_area(self, player, area, tool)
  end
end

function Editor:on_player_deconstructed_area(event)
  if event.alt then return end
  local player = game.players[event.player_index]
  on_player_deconstructed_area(self, player, event.area, player.cursor_stack)
end

function Editor:on_marked_for_deconstruction(event)
  local entity = event.entity
  local player = event.player_index and game.players[event.player_index]
  if entity.name == "beltlayer-buffer" then
    entity.cancel_deconstruction(player and player.force or entity.force)
  else
    super.on_marked_for_deconstruction(self, event)
  end
end

function Editor:on_marked_for_upgrade(event)
  local entity = event.entity
  if is_connector(entity) then
    local surface = self:counterpart_surface(entity.surface)
    local counterpart = surface and surface.find_entity(entity.name, entity.position)
    if counterpart then
      counterpart.order_upgrade{force = counterpart.force, player = event.player_index, target = event.target}
    end
  end
  super.on_marked_for_upgrade(self, event)
end

function Editor:on_cancelled_upgrade(event)
  local entity = event.entity
  if is_connector(entity) then
    local surface = self:counterpart_surface(entity.surface)
    local counterpart = surface and surface.find_entity(entity.name, entity.position)
    if counterpart then
      counterpart.cancel_upgrade(counterpart.force, event.player_index)
    end
  end
  super.on_cancelled_upgrade(self, event)
end

function Editor:on_pre_ghost_deconstructed(event)
  local ghost = event.ghost
  if ghost.name ~= "entity-ghost" then return end
  if is_connector_name(ghost.ghost_name) and self:is_valid_aboveground_surface(ghost.surface) then
    -- connector ghost deconstructed, so if this is the result of a deconstruction tool,
    -- we want to deconstruct underground too, but by the time on_player_deconstructed_area is raised
    -- there will be no ghosts, and if there were only ghosts we need to keep track of that fact.
    previous_connector_ghost_deconstruction_tick = event.tick
  end
  super.on_pre_ghost_deconstructed(self, event)
end

function Editor:on_player_setup_blueprint(event)
  local player = game.players[event.player_index]
  local area = event.area

  if connector_in_area(player.surface, area) then
    super.capture_underground_entities_in_blueprint(self, event)
    if event.item == "cut-paste-tool" and event.alt then
      local player = game.players[event.player_index]
      on_player_deconstructed_area(self, player, area, nil)
    end
  end
end

function Editor:on_put_item(event)
  local player = game.players[event.player_index]
  local stack = player.cursor_stack
  if stack and stack.valid_for_read and is_connector_name(stack.name) then
    local existing_entities =
      player.surface.find_entities_filtered{position = event.position, type = "loader-1x1"}
    for _, entity in pairs(existing_entities) do
      if is_connector(entity) then
        upgrade_in_progress = {
          entity = entity,
          tick = event.tick,
        }
      end
    end
  end
  super.on_put_item(self, event)
end

function Editor:script_raised_built(event)
  event.created_entity = event.entity
  return self:on_built_entity(event)
end

function Editor:script_raised_destroy(event)
  if is_surface_connector(self, event.entity) then
    previous_connector_ghost_deconstruction_tick = event.tick
  end
  self:on_player_mined_entity(event)
end

function Editor:script_raised_revive(event)
  event.created_entity = event.entity
  self:on_built_entity(event)
end

return M