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

local function editor_autoplace_control()
  for control in pairs(game.autoplace_control_prototypes) do
    if control:find("dirt") then
      return control
    end
  end
  -- pick one at random
  return next(game.autoplace_control_prototypes)
end

local function create_editor_surface()
  local autoplace_control = editor_autoplace_control()
  local surface = game.create_surface(
    SURFACE_NAME,
    {
      starting_area = "none",
      water = "none",
      cliff_settings = { cliff_elevation_0 = 1024 },
      default_enable_all_autoplace_controls = false,
      autoplace_controls = {
        [autoplace_control] = {
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
end

function M.on_init()
  if game.surfaces[SURFACE_NAME] then
    game.delete_surface(SURFACE_NAME)
  else
    create_editor_surface()
  end
  global.player_state = {}
  M.on_load()
end

function M.on_load()
  editor_surface = global.editor_surface
  player_state = global.player_state
end

function M.on_surface_deleted(event)
  if not game.surfaces[SURFACE_NAME] then
    create_editor_surface()
    editor_surface = global.editor_surface
  end
end

local valid_editor_types = {
  ["transport-belt"] = true,
  ["underground-belt"] = true,
}

local function is_stack_valid_for_editor(stack)
  local item_prototype
  if stack.valid and stack.valid_for_read then
    item_prototype = stack.prototype
  elseif not stack.valid then
    item_prototype = game.item_prototypes[stack.name]
  else
    return false
  end
  local place_result = item_prototype.place_result
  if place_result and valid_editor_types[place_result.type] then
    return true
  end
  return false
end

local function sync_player_inventory(character, player)
  for name in pairs(valid_editor_types) do
    local character_count = character.get_item_count(name)
    local player_count = player.get_item_count(name)
    if character_count > player_count then
      player.insert{name = name, count = character_count - player_count}
    elseif character_count < player_count then
      player.remove_item{name = name, count = player_count - character_count}
    end
  end
end

local function sync_player_inventories()
  for player_index, state in pairs(player_state) do
    local character = state.character
    if character then
      local player = game.players[player_index]
      if player.connected then
        sync_player_inventory(character, player)
      end
    end
  end
end

local function move_player_to_editor(player)
  local success = player.clean_cursor()
  if not success then return end
  local player_index = player.index
  player_state[player_index] = {
    position = player.position,
    surface = player.surface,
    character = player.character,
  }
  player.character = nil
  player.teleport(player.position, editor_surface)
end

local function return_player_from_editor(player)
  local player_index = player.index
  local state = player_state[player_index]
  player.teleport(state.position, state.surface)
  if state.character then
    player.character = state.character
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
  end
  return "input"
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

  local underground_connector = editor_surface.create_entity{
    name = entity.name,
    position = position,
    direction = direction,
    type = loader_type,
    force = force,
  }

  if not underground_connector then
    if player then
      abort_player_build(player, entity, {"beltlayer-error.underground-obstructed"})
    else
      entity.order_deconstruction(entity.force)
    end
    return
  end

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

local function item_for_entity(entity)
  return next(entity.prototype.items_to_place_this)
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
  local stack = event.stack
  local surface = entity.surface

  if event.mod_name == "upgrade-planner" then
    -- work around https://github.com/Klonan/upgrade-planner/issues/10
    stack = {name = item_for_entity(entity), count = 1}
  end

  if is_connector(entity) then
    if surface.name == "nauvis" then
      built_surface_connector(player, entity)
    else
      abort_player_build(player, entity, {"beltlayer-error.bad-surface-for-connector"})
    end
  elseif surface == editor_surface then
    player_built_underground_entity(player_index, stack)
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

local function return_to_character_or_spill(player, character, stack)
  local inserted = character.insert(stack)
  if inserted < stack.count then
    player.print({"inventory-restriction.player-inventory-full", game.item_prototypes[stack.name].localised_name})
    character.surface.spill_item_stack(
      character.position,
      {name = stack.name, count = stack.count - inserted})
  end
  return inserted
end

local function return_buffer_to_character(player_index, character, buffer)
  local player = game.players[player_index]
  for i=1,#buffer do
    local stack = buffer[i]
    if stack.valid_for_read then
      local inserted = return_to_character_or_spill(player, character, stack)
      if is_stack_valid_for_editor(stack) then
        -- match editor player inventory to character inventory
        stack.count = inserted
      else
        -- belt contents; don't allow placement in editor
        stack.clear()
      end
    end
  end
end

function M.on_picked_up_item(event)
  local player = game.players[event.player_index]
  if player.surface ~= editor_surface then return end
  local character = player_state[event.player_index].character
  if character then
    local stack = event.item_stack
    local inserted = return_to_character_or_spill(player, character, stack)
    local excess = stack.count - inserted
    if not is_stack_valid_for_editor(stack) then
      player.remove_item(stack)
    elseif excess > 0 then
      player.remove_item{name = stack.name, count = excess}
    end
  end
end

local function player_mined_from_editor(event)
  local character = player_state[event.player_index].character
  if character then
    return_buffer_to_character(event.player_index, character, event.buffer)
  end
end

function M.on_player_mined_item(event)
  if event.mod_name == "upgrade-planner" then
    -- upgrade-planner won't insert to character inventory
    local player = game.players[event.player_index]
    local character = player_state[event.player_index].character
    if character then
      local stack = event.item_stack
      local count = stack.count
      local inserted = return_to_character_or_spill(player, character, stack)
      local excess = count - inserted
      if excess > 0 then
        -- try to match editor inventory to character inventory
        player.remove_item{name = event.item_stack.name, count = excess}
      end
    end
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

function M.on_tick(_)
  sync_player_inventories()
end

return M