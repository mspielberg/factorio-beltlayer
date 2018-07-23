local M = {}

local surface_name = "plumbing"
local tile_name = "dirt-6"

local player_state

function M.on_init()
  if not game.surfaces[surface_name] then
    global.surface = game.create_surface(surface_name)
  end
  if not global.player_state then
    global.player_state = {}
  end
  M.on_load()
end

function M.on_load()
  M.surface = global.surface
  player_state = global.player_state
end

function M.has_active_players()
  for _, player in pairs(game.players) do
    if player.connected and player.surface.name == surface_name then
      return true
    end
  end
  return false
end

local function activate()
  for _, entity in ipairs(game.surfaces[surface_name].find_entities()) do
    entity.active = true
  end
end

local function deactivate()
  for _, entity in ipairs(game.surfaces[surface_name].find_entities()) do
    entity.active = false
  end
end

local function get_player_pipe_stacks(player)
  local stacks = {}
  for _, inventory_index in ipairs{defines.inventory.player_quickbar, defines.inventory.player_main} do
    local inventory = player.get_inventory(inventory_index)
    if inventory then
      for i=1,#inventory do
        local stack = inventory[i]
        if stack.valid_for_read then
          local place_result = stack.prototype.place_result
          if place_result and (place_result.type == "pipe" or place_result.type == "pipe-to-ground") then
            stacks[#stacks+1] = {name = stack.name, count = stack.count}
          end
        end
      end
    end
  end
  return stacks
end

local function move_player_to_editor(player)
  if not M.has_active_players() then
    activate()
  end
  local pipe_stacks = get_player_pipe_stacks(player)
  local player_index = player.index
  player_state[player_index] = {
    position = player.position,
    surface = player.surface,
    character = player.character,
  }
  player.character = nil
  player.teleport(player.position, surface_name)
  for _, stack in ipairs(pipe_stacks) do
    player.insert(stack)
  end
end

local function return_player_from_editor(player)
  local player_index = player.index
  player.clean_cursor()
  player.get_main_inventory().clear()
  player.get_quickbar().clear()
  player.teleport(player_state[player_index].position, player_state[player_index].surface)
  player.character = player_state[player_index].character
  player_state[player_index] = nil
  if not M.has_active_players() then
    deactivate()
  end
end

function M.toggle_editor_status_for_player(player_index)
  local player = game.players[player_index]
  if player.surface.name == surface_name then
    return_player_from_editor(player)
  elseif player.surface == game.surfaces.nauvis then
    move_player_to_editor(player)
  else
    player.print({"plumbing-error.bad-surface"})
  end
end

function M.on_chunk_generated(event)
  if event.surface.name ~= surface_name then return end
  local surface = event.surface
  local area = event.area

  local tiles = {}
  for y=area.left_top.y,area.right_bottom.y do
    for x=area.left_top.x,area.right_bottom.x do
      tiles[#tiles+1] = {name = tile_name, position={x = x,y = y}}
    end
  end
  surface.set_tiles(tiles)

  for _, entity in ipairs(surface.find_entities(area)) do
    entity.destroy()
  end
end

return M