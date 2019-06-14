local Editor = require "Editor"
local version = require "lualib.version"

local M = {}

local all_migrations = {}

local function add_migration(migration)
  all_migrations[#all_migrations+1] = migration
end

function M.on_mod_version_changed(old)
  old = version.parse(old)
  for _, migration in ipairs(all_migrations) do
    if version.lt(old, migration.version) then
      log("running world migration "..migration.name)
      migration.task()
    end
  end
end

add_migration{
  name = "v0_2_0_migrate_globals",
  version = {0,2,0},
  task = function()
    global.editor = Editor.new()
    global.editor.player_state = global.player_state or {}
    global.player_state = nil
    global.editor_surface = nil
    for _, connector in pairs(global.all_connectors) do
      if connector:valid() then
        connector.items_per_tick = connector.above_loader.prototype.belt_speed * 32 * 2 / 9
      end
    end
  end,
}

add_migration{
  name = "v0_2_2_remove_invalid_connectors",
  version = {0,2,2},
  task = function()
    for key, connector in pairs(global.all_connectors) do
      if connector:valid() then
        connector.id = key
      else
        global.all_connectors[key] = nil
      end
    end
  end,
}

add_migration{
  name = "v0_2_3_remove_enemies",
  version = {0,2,3},
  task = function()
    for surface_name, s in pairs(game.surfaces) do
      if surface_name:find("^beltlayer") then
        for _, entity in pairs(s.find_entities_filtered{force = "enemy"}) do
          entity.destroy()
        end
      end
    end
  end,
}

add_migration{
  name = "v0_2_5_reset_buffer_bars",
  version = {0,2,5},
  task = function()
    for surface_name, s in pairs(game.surfaces) do
      for _, entity in pairs(s.find_entities_filtered{name = "beltlayer-buffer"}) do
        entity.get_inventory(defines.inventory.chest).setbar()
      end
    end
  end,
}

add_migration{
  name = "v0_3_1_remove_duplicate_bpproxies",
  version = {0,3,1},
  task = function()
    for _, surface in pairs(game.surfaces) do
      local prev = nil
      for _, en in ipairs(surface.find_entities_filtered{name = "entity-ghost"}) do
        if en.ghost_name:find("^beltlayer%-bpproxy%-") then
          if prev and prev.position.x == en.position.x and prev.position.y == en.position.y then
            en.destroy()
          else
            prev = en
          end
        end
      end
    end
  end,
}

return M