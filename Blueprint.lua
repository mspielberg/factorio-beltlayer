local Constants = require "Constants"
require "util"

local SURFACE_NAME = Constants.SURFACE_NAME
local debug = function() end
if Constants.DEBUG_ENABLED then
  debug = log
end

local M = {}

local editor_surface

function M.on_init()
  M.on_load()
end

function M.on_load()
  editor_surface = global.editor_surface
end

function M.is_setup_bp(stack)
  return stack and
    stack.valid and
    stack.valid_for_read and
    stack.is_blueprint and
    stack.is_blueprint_setup()
end

-- returns BoundingBox of blueprint entities (not tiles!) in blueprint coordinates
function M.bounding_box(bp)
  local left = -0.1
  local top = -0.1
  local right = 0.1
  local bottom = 0.1

  local entities = bp.get_blueprint_entities()
  if entities then
    for _, e in pairs(entities) do
      local pos = e.position
      if pos.x < left then left = pos.x - 0.5 end
      if pos.y < top then top = pos.y - 0.5 end
      if pos.x > right then right = pos.x + 0.5 end
      if pos.y > bottom then bottom = pos.y + 0.5 end
    end
  end

  return {
    left_top = {x=left, y=top},
    right_bottom = {x=right, y=bottom},
  }
end

local function is_connector(name)
  return name:find("%-beltlayer%-connector$")
end

local function is_connector_or_ghost(entity)
  return is_connector(entity.name) or (entity.name == "entity-ghost" and is_connector(entity.ghost_name))
end

local function find_in_area(surface, area, args)
  local position
  if area.left_top.x >= area.right_bottom.x or area.left_top.y >= area.right_bottom.y then
    position = area.left_top
    area = nil
  end
  if args then
    local find_args = util.table.deepcopy(args)
    find_args.position = position
    find_args.area = area
    return surface.find_entities_filtered(find_args)
  else
    if position then
      return surface.find_entities({{position.x, position.y}, {position.x + 0.1, position.y + 0.1}})
    else
      return surface.find_entities(area)
    end
  end
end

local function stack_from_items_to_place(entity)
  local product = next(entity.prototype.items_to_place_this)
  return { name = product, count = 1 }
end

local function abort_player_build(player, entity, message)
  player.insert(stack_from_items_to_place(entity))
  entity.surface.create_entity{
    name = "flying-text",
    position = entity.position,
    text = message,
  }
  entity.destroy()
end

local function abort_robot_build(entity, message)
  local surface = entity.surface
  local position = entity.position
  local force = entity.force
  local stack = stack_from_items_to_place(entity)
  surface.create_entity{
    name = "flying-text",
    position = position,
    text = message,
  }
  entity.destroy()
  -- don't drop an item-on-ground on top of a belt entity
  position = surface.find_non_colliding_position("transport-belt", position, 0, 0.5)
  local spilled_stack = surface.create_entity{
    name = "item-on-ground",
    force = force,
    position = position,
    stack = stack,
  }
  spilled_stack.order_deconstruction(force)
end

local function nonproxy_name(name)
  return name:match("^beltlayer%-bpproxy%-(.*)$")
end

local function counterpart_surface(surface)
  if surface.name == SURFACE_NAME then
    return game.surfaces.nauvis
  end
  return editor_surface
end

local function surface_counterpart(entity)
  local name = entity.name
  if is_connector(name) then
    return game.surfaces.nauvis.find_entity(name, entity.position)
  end
  return game.surfaces.nauvis.find_entity("beltlayer-bpproxy-"..name, entity.position)
end

local function underground_counterpart(entity)
  local name = nonproxy_name(entity.name)
  if name then
    return editor_surface.find_entity(name, entity.position)
  end
  return editor_surface.find_entity(entity.name, entity.position)
end

-- converts overworld bpproxy ghost to regular ghost underground
local function on_player_built_bpproxy_ghost(ghost, name)
  local position = ghost.position
  local create_entity_args = {
    name = "entity-ghost",
    inner_name = name,
    position = position,
    force = ghost.force,
    direction = ghost.direction,
  }
  if ghost.ghost_type == "underground-belt" then
    create_entity_args.type = ghost.belt_to_ground_type
  end

  local editor_ghost = editor_surface.create_entity(create_entity_args)
  if editor_ghost then
    editor_ghost.last_user = ghost.last_user
    if is_connector(name) then
      ghost.destroy()
    end
  else
    ghost.destroy()
  end
end

local function on_player_built_underground_ghost(ghost)
  game.surfaces.nauvis.create_entity{
    name = "entity-ghost",
    inner_name = "beltlayer-bpproxy-"..ghost.ghost_name,
    position = ghost.position,
    force = ghost.force,
    direction = ghost.direction
  }
end

local function on_player_built_ghost(ghost)
  local name = nonproxy_name(ghost.ghost_name)
  if name then
    if editor_surface.find_entity("entity-ghost", ghost.position) then
      ghost.destroy()
      return
    end
    return on_player_built_bpproxy_ghost(ghost, name)
  end
  if ghost.surface == editor_surface then
    local surface_ghost = game.surfaces.nauvis.find_entity("entity-ghost", ghost.position)
    if surface_ghost and
      (is_connector(surface_ghost.ghost_name) or nonproxy_name(surface_ghost.ghost_name)) then
      ghost.destroy()
      return
    end
    return on_player_built_underground_ghost(ghost)
  end
end

local function create_underground_entity(name, position, force, direction, belt_to_ground_type)
  local underground_entity = editor_surface.create_entity{
    name = name,
    position = position,
    force = force,
    direction = direction,
    type = belt_to_ground_type,
  }
  if underground_entity then
    game.surfaces.nauvis.create_entity{
      name="flying-text",
      position=position,
      text={"beltlayer-message.created-underground", underground_entity.localised_name},
    }
  end
  return underground_entity
end

local ghost_mined
local function on_player_built_surface_entity(player, entity)
  if not ghost_mined then return end
  local name = entity.name
  local position = entity.position
  local force = entity.force
  if ghost_mined.tick == game.tick and
    ghost_mined.name == name and
    ghost_mined.position.x == position.x and
    ghost_mined.position.y == position.y and
    ghost_mined.force == force.name or force.get_friend(ghost_mined.force) then
      local direction = ghost_mined.direction
      local type = ghost_mined.belt_to_ground_type
      local underground_entity = create_underground_entity(name, position, force, direction, type)
      if underground_entity then
        entity.destroy()
      else
        abort_player_build(player, entity, {"beltlayer-error.underground-obstructed"})
      end
  end
end

local function on_player_built_underground_entity(_, entity)
  local colliding_ghosts = find_in_area(game.surfaces.nauvis, entity.bounding_box, {name = "entity-ghost"})
  for _, ghost in ipairs(colliding_ghosts) do
    if nonproxy_name(ghost.ghost_name) then
      -- bpproxy ghost on surface collides with new underground entity
      ghost.destroy()
    end
  end
end

function M.on_player_built_entity(event)
  local player = game.players[event.player_index]
  local entity = event.created_entity
  if entity.name == "entity-ghost" then
    return on_player_built_ghost(entity)
  end

  if entity.surface == game.surfaces.nauvis then
    return on_player_built_surface_entity(player, entity)
  elseif entity.surface == editor_surface then
    return on_player_built_underground_entity(player, entity)
  end
end

function M.on_robot_built_entity(_, entity, _)
  local surface = entity.surface
  if surface ~= game.surfaces.nauvis then return end
  local name = nonproxy_name(entity.name)
  if not name then return end
  local belt_to_ground_type
  if entity.type == "underground-belt" then
    belt_to_ground_type = entity.belt_to_ground_type
  end
  local underground_entity = create_underground_entity(
    name,
    entity.position,
    entity.force,
    entity.direction,
    belt_to_ground_type)
  if underground_entity then
    entity.destroy()
  else
    abort_robot_build(entity, {"beltlayer-error.underground-obstructed"})
  end
end

local function player_mined_connector_ghost(connector_ghost)
  local counterpart = counterpart_surface(connector_ghost.surface).find_entity("entity-ghost", connector_ghost.position)
  if counterpart and is_connector(counterpart.ghost_name) then
    counterpart.destroy()
  end
end

local function on_player_mined_surface_entity(entity)
  local name = nonproxy_name(entity.name)
  if not name then return end
  local counterpart = underground_counterpart(entity)
  if counterpart then
    counterpart.destroy()
  end
end

local function on_player_mined_underground_entity(entity)
  local counterpart = surface_counterpart(entity)
  if counterpart then
    counterpart.destroy()
  end
end

function M.on_pre_player_mined_item(event)
  local entity = event.entity
  if not entity.valid then return end
  if entity.name == "entity-ghost" then
    local ghost_name = entity.ghost_name
    local name = nonproxy_name(ghost_name)
    if name then
      ghost_mined = {
        tick = event.tick,
        name = name,
        direction = entity.direction,
        force = entity.force.name,
        position = entity.position,
      }
      if entity.ghost_type == "underground-belt" then
        ghost_mined.belt_to_ground_type = entity.belt_to_ground_type
      end
    elseif ghost_name == "beltlayer-connector" then
      return player_mined_connector_ghost(entity)
    end
  elseif entity.surface == editor_surface then
    return on_player_mined_underground_entity(entity)
  elseif entity.surface == game.surfaces.nauvis then
    return on_player_mined_surface_entity(entity)
  end
end

function M.on_robot_mined_entity(_, entity, _)
  if not entity.valid or entity.surface ~= game.surfaces.nauvis then return end
  local name = nonproxy_name(entity.name)
  if not name then return end
  local counterpart = underground_counterpart(entity)
  if counterpart then
    counterpart.destroy()
  end
end

------------------------------------------------------------------------------------------------------------------------
-- deconstruction

local function create_entity_filter(tool)
  local set = {}
  for _, item in pairs(tool.entity_filters) do
    set[item] = true
  end
  if not next(set) then
    return function(_) return true end
  elseif tool.entity_filter_mode == defines.deconstruction_item.entity_filter_mode.blacklist then
    return function(entity)
      if entity.name == "entity-ghost" then
        return not set[entity.ghost_name]
      else
        return not set[entity.name]
      end
    end
  else
    return function(entity)
      if entity.name == "entity-ghost" then
        return set[entity.ghost_name]
      else
        return set[entity.name]
      end
    end
  end
end

local function destroy_bpproxy_ghost(position)
  local ghost = game.surfaces.nauvis.find_entity("entity-ghost", position)
  if ghost and ghost.ghost_name:find("^beltlayer%-bpproxy%-") then
    ghost.destroy()
  end
end

local function order_underground_deconstruction(player, area, filter)
  local nauvis = game.surfaces.nauvis
  local underground_entities = find_in_area(editor_surface, area, {})
  local to_deconstruct = {}
  for _, entity in ipairs(underground_entities) do
    if filter(entity) then
      if entity.name == "entity-ghost" then
        destroy_bpproxy_ghost(entity.position)
        entity.destroy()
      elseif is_connector(entity.name) then
        entity.minable = true
        entity.order_deconstruction(entity.force)
        entity.minable = false
        to_deconstruct[#to_deconstruct+1] = entity
      elseif entity.type == "transport-belt" or entity.type == "underground-belt" then
        local proxy = nauvis.create_entity{
          name = "beltlayer-bpproxy-"..entity.name,
          position = entity.position,
          force = entity.force,
          direction = entity.direction,
        }
        proxy.destructible = false
        proxy.order_deconstruction(proxy.force, player)
        entity.order_deconstruction(entity.force)
        to_deconstruct[#to_deconstruct+1] = entity
      end
    end
  end
  return to_deconstruct
end

local function connector_in_area(surface, area)
  local loaders = find_in_area(surface, area, {type = "loader", limit = 1})
  for _, loader in ipairs(loaders) do
    if is_connector(loader.name) then
      return true
    end
  end
  return false
end

local previous_connector_ghost_deconstruction_tick
local previous_connector_ghost_deconstruction_player_index

local function on_player_deconstructed_surface_area(player, area, filter)
  if not connector_in_area(player.surface, area) and
    (player.index ~= previous_connector_ghost_deconstruction_player_index or
    game.tick ~= previous_connector_ghost_deconstruction_tick) then
    return
  end
  local underground_entities = order_underground_deconstruction(player, area, filter)
  if next(underground_entities) and
     settings.get_player_settings(player)["beltlayer-deconstruction-warning"].value then
    player.print({"beltlayer-message.marked-for-deconstruction", #underground_entities})
  end
end

local function on_player_deconstructed_underground_area(player, area, filter)
  local underground_entities = order_underground_deconstruction(player, area, filter)
  for _, entity in ipairs(underground_entities) do
    if is_connector(entity.name) then
      local counterpart = surface_counterpart(entity)
      if counterpart then
        counterpart.order_deconstruction(counterpart.force)
      end
    end
  end
end

function M.on_player_deconstructed_area(player_index, area, _, alt)
  if alt then return end
  local player = game.players[player_index]
  local tool = player.cursor_stack
  if not tool or not tool.valid_for_read or not tool.is_deconstruction_item then return end
  local filter = create_entity_filter(tool)
  if player.surface == game.surfaces.nauvis then
    return on_player_deconstructed_surface_area(player, area, filter)
  elseif player.surface == editor_surface then
    return on_player_deconstructed_underground_area(player, area, filter)
  end
end

function M.on_pre_ghost_deconstructed(player_index, ghost)
  if is_connector(ghost.ghost_name) then
    previous_connector_ghost_deconstruction_player_index = player_index
    previous_connector_ghost_deconstruction_tick = game.tick
  end
end

function M.on_canceled_deconstruction(entity, _)
  if entity.surface == game.surfaces.nauvis then
    local counterpart = underground_counterpart(entity)
    if counterpart and counterpart.to_be_deconstructed(counterpart.force) then
      counterpart.cancel_deconstruction(counterpart.force)
    end
  elseif entity.surface == editor_surface then
    local counterpart = surface_counterpart(entity)
    if counterpart then
      if is_connector(counterpart.name) then
        counterpart.cancel_deconstruction(counterpart.force)
      else
        counterpart.destroy()
      end
    end
  end
end

------------------------------------------------------------------------------------------------------------------------
-- capture underground entities as bpproxy ghosts

function M.on_player_setup_blueprint(event)
  local player_index = event.player_index
  local player = game.players[player_index]
  local surface = player.surface
  if surface.name ~= "nauvis" then return end

  local bp = player.blueprint_to_setup
  if not bp or not bp.valid_for_read then bp = player.cursor_stack end
  local bp_entities = bp.get_blueprint_entities()
  local area = event.area

  local anchor_connector
  local entities = find_in_area(surface, area, {})
  for _, entity in ipairs(entities) do
    if is_connector_or_ghost(entity) then
      anchor_connector = entity
      break
    end
  end
  if not anchor_connector then return end

  local beltlayer_surface = game.surfaces[SURFACE_NAME]

  -- find counterpart in blueprint
  local world_to_bp
  for _, bp_entity in ipairs(bp_entities) do
    if is_connector(bp_entity.name) then
      local x_offset = bp_entity.position.x - anchor_connector.position.x
      local y_offset = bp_entity.position.y - anchor_connector.position.y
      world_to_bp = function(position)
        return { x = position.x + x_offset, y = position.y + y_offset }
      end
      break
    end
  end

  for _, ug_entity in ipairs(find_in_area(beltlayer_surface, area, {})) do
    if ug_entity.type == "transport-belt" or ug_entity.type == "underground-belt" then
      local new_bp_entity = {
        entity_number = #bp_entities + 1,
        name = "beltlayer-bpproxy-"..ug_entity.name,
        position = world_to_bp(ug_entity.position),
        direction = ug_entity.direction,
      }
      if ug_entity.type == "underground-belt" then
        new_bp_entity.type = ug_entity.belt_to_ground_type
      end
      bp_entities[#bp_entities + 1] = new_bp_entity
    end
  end
  bp.set_blueprint_entities(bp_entities)
end

return M