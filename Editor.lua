local Connector = require "Connector"
local Constants = require "Constants"

local M = {}
local SURFACE_NAME = Constants.SURFACE_NAME
local UNDERGROUND_TILE_NAME = Constants.UNDERGROUND_TILE_NAME

local editor_surface
local player_state

local debug = function() end
if Constants.DEBUG_ENABLED then
  debug = log
end

function M.on_init()
    local surface = game.create_surface(
      SURFACE_NAME,
      {
        starting_area = "none",
        water = "none",
        cliff_settings = { cliff_elevation_0 = 1024 },
        default_enable_all_autoplace_controls = false,
        autoplace_controls = {
          dirt = {
            frequency = "very-low",
            size = "very-high",
          },
        },
        autoplace_settings = {
          decorative = { treat_missing_as_default = false },
          entity = { treat_missing_as_default = false },
        },
      }
    )
    surface.daytime = 0.35
    surface.freeze_daytime = true
    global.editor_surface = surface
    global.player_state = {}
    M.on_load()
end

function M.on_load()
  editor_surface = global.editor_surface
  player_state = global.player_state
end

local valid_editor_types = {
  ["transport-belt"] = true,
  ["underground-belt"] = true,
}

local function get_player_editor_stacks(player)
  local stacks = {}
  for _, inventory_index in ipairs{defines.inventory.player_quickbar, defines.inventory.player_main} do
    local inventory = player.get_inventory(inventory_index)
    if inventory then
      for i=1,#inventory do
        local stack = inventory[i]
        if stack.valid_for_read then
          local place_result = stack.prototype.place_result
          if place_result and valid_editor_types[place_result.type] then
            stacks[#stacks+1] = {name = stack.name, count = stack.count}
          end
        end
      end
    end
  end
  return stacks
end

local function move_player_to_editor(player)
  local success = player.clean_cursor()
  if not success then return end
  local editor_stacks = get_player_editor_stacks(player)
  local player_index = player.index
  player_state[player_index] = {
    position = player.position,
    surface = player.surface,
    character = player.character,
  }
  player.character = nil
  player.teleport(player.position, editor_surface)
  if player_state[player_index].character then
    for _, stack in ipairs(editor_stacks) do
      player.insert(stack)
    end
  end
end

local function return_player_from_editor(player)
  local player_index = player.index
  if player_state[player_index].character then
    player.clean_cursor()
    player.get_main_inventory().clear()
    player.get_quickbar().clear()
    player.teleport(player_state[player_index].position, player_state[player_index].surface)
    player.character = player_state[player_index].character
  else
    player.teleport(player_state[player_index].position, player_state[player_index].surface)
  end
  player_state[player_index] = nil
end

function M.toggle_editor_status_for_player(player_index)
  local player = game.players[player_index]
  if player.surface == editor_surface then
    return_player_from_editor(player)
  elseif player.surface == game.surfaces.nauvis then
    move_player_to_editor(player)
  else
    player.print({"beltlayer-error.bad-surface-for-editor"})
  end
end

local function abort_player_build(player, entity, message)
  player.insert({name = entity.name, count = 1})
  entity.surface.create_entity{
    name = "flying-text",
    position = entity.position,
    text = message,
  }
  entity.destroy()
end

local function opposite_type(loader_type)
  if loader_type == "input" then
    return "output"
  else
    return "input"
  end
end

local function built_surface_connector(player, entity)
  local position = entity.position
  local force = entity.force
  if not editor_surface.is_chunk_generated(position) then
    editor_surface.request_to_generate_chunks(position, 1)
    editor_surface.force_generate_chunk_requests()
  end

  local direction = entity.direction
  local loader_type = opposite_type(entity.loader_type)
  -- check for existing underground connector ghost
  local underground_ghost = editor_surface.find_entity("entity-ghost", position)
  if underground_ghost and underground_ghost.ghost_type == "loader" then
    direction = underground_ghost.direction
    loader_type = underground_ghost.loader_type
    entity.loader_type = opposite_type(loader_type)
  end

  local create_args = {
    name = entity.name,
    position = position,
    direction = direction,
    type = loader_type,
    force = force,
  }
  if not editor_surface.can_place_entity(create_args) then
    if player then
      abort_player_build(player, entity, {"beltlayer-error.underground-obstructed"})
    else
      entity.order_deconstruction(entity.force)
    end
    return
  end

  local underground_connector = editor_surface.create_entity(create_args)
  underground_connector.minable = false

  -- create buffer containers
  local above_container = entity.surface.create_entity{
    name = "beltlayer-buffer",
    position = position,
    force = force,
  }
  above_container.destructible = false
  local below_container = editor_surface.create_entity{
    name = "beltlayer-buffer",
    position = position,
    force = force,
  }
  below_container.destructible = false

  Connector.new(entity, above_container, below_container)
end

local function player_built_underground_entity(player_index, stack)
  local character = player_state[player_index].character
  if character then
    character.remove_item(stack)
  end
end

local function is_connector(entity)
  return entity.name:find("%-beltlayer%-connector$")
end

function M.on_player_built_entity(event)
  local player_index = event.player_index
  local player = game.players[player_index]
  local entity = event.created_entity
  if not entity.valid or entity.name == "entity-ghost" then return end
  local surface = entity.surface

  if is_connector(entity) then
    if surface.name == "nauvis" then
      built_surface_connector(player, entity)
    else
      abort_player_build(player, entity, {"beltlayer-error.bad-surface-for-connector"})
    end
  elseif surface == editor_surface then
    player_built_underground_entity(player_index, event.stack)
  end
end

function M.on_robot_built_entity(_, entity, _)
  if not entity.valid then return end
  if is_connector(entity) then
    built_surface_connector(nil, entity)
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

local function mined_surface_connector(entity, buffer)
  local above_container = entity.surface.find_entity("beltlayer-buffer", entity.position)
  local below_container = editor_surface.find_entity("beltlayer-buffer", entity.position)
  local underground_connector = editor_surface.find_entity(entity.name, entity.position)
  if buffer then
    insert_container_inventory_to_buffer(above_container, buffer)
    insert_container_inventory_to_buffer(below_container, buffer)
    insert_transport_lines_to_buffer(underground_connector, buffer)
  end
  above_container.destroy()
  below_container.destroy()
  underground_connector.destroy()
end

local function return_to_character_inventory(player_index, character, buffer)
  local player = game.players[player_index]
  for i=1,#buffer do
    local stack = buffer[i]
    if stack.valid_for_read then
      local inserted = character.insert(stack)
      if inserted < stack.count then
        player.print({"inventory-restriction.player-inventory-full", stack.prototype.localised_name})
        character.surface.spill_item_stack(
          character.position,
          {name = stack.name, count = stack.count - inserted})
        stack.count = inserted
      end
    end
  end
end

local function player_mined_from_editor(event)
  local character = player_state[event.player_index].character
  if character then
    return_to_character_inventory(event.player_index, character, event.buffer)
  end
end

function M.on_player_mined_entity(event)
  local entity = event.entity
  local surface = entity.surface
  if surface == editor_surface then
    player_mined_from_editor(event)
  elseif surface.name == "nauvis" and is_connector(entity) then
    mined_surface_connector(entity, event.buffer)
  end
end

function M.on_robot_mined_entity(_, entity, buffer)
  if entity.surface.name == "nauvis" and is_connector(entity) then
    mined_surface_connector(entity, buffer)
  end
end

local handling_rotation = false
function M.on_player_rotated_entity(event)
  if handling_rotation then return end
  local entity = event.entity
  if not entity or not entity.valid then return end
  if is_connector(entity) then
    if entity.surface == editor_surface then
      local above_connector = game.surfaces.nauvis.find_entity(entity.name, entity.position)
      if above_connector then
        handling_rotation = true
        above_connector.rotate{by_player = event.player_index}
        handling_rotation = false
        Connector.for_entity(above_connector):rotate()
      end
    elseif entity.surface == game.surfaces.nauvis then
      local below_connector = editor_surface.find_entity(entity.name, entity.position)
      if below_connector then
        handling_rotation = true
        below_connector.rotate{by_player = event.player_index}
        handling_rotation = false
      end
      Connector.for_entity(entity):rotate()
    end
  end
end

function M.on_entity_died(event)
  local entity = event.entity
  if not entity or not entity.valid then return end
  if entity.surface == game.surfaces.nauvis and is_connector(entity) then
    mined_surface_connector(entity)
  end
end

return M