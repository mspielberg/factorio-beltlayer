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
    global.editor = {
      name = "beltlayer",
      proxy_prefix = "beltlayer-bpproxy-",
      player_state = global.player_state or {},
      valid_editor_types = { "transport-belt", "underground-belt" },
    }
    Editor.restore(global.editor)
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
  name = "v0_5_0_reattach_loaders",
  version = {0,5,0},
  task = function()
    for key, connector in pairs(global.all_connectors) do
      local inv = connector.above_inv
      if not connector.above_loader.valid and inv.valid then
        local surface = inv.entity_owner.surface
        local position = inv.entity_owner.position
        connector.above_loader = surface.find_entities_filtered{
          type = "loader-1x1",
          position = position,
        }[1]
        log("reset loader reference at "..serpent.line(position).." on "..surface.name)
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
        log("Connector "..serpent.block(connector).." is not valid. Removing.")
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
        entity.get_inventory(defines.inventory.chest).set_bar()
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

add_migration{
  name = "v0_4_0_add_splitter",
  version = {0,4,0},
  task = function()
    global.editor.valid_editor_types = {"splitter", "transport-belt", "underground-belt"}
  end,
}

add_migration{
  name = "v0_5_0_add_blueprint_items_to_editor",
  version = {0,5,0},
  task = function()
    global.editor.valid_editor_types = {
      "blueprint", "blueprint-book", "deconstruction-item", "upgrade-item",
      "splitter", "transport-belt", "underground-belt",
    }
  end,
}

add_migration{
  name = "v0_5_3_change_simple_entity_with_owner",
  version = {0,5,3},
  task = function()
    local reverse_direction = {}
    for k, v in pairs(defines.direction) do
      reverse_direction[v] = k
    end

    local function new_proxy_name(entity)
      local direction = entity.direction
      if entity.type == "transport-belt" or entity.type == "splitter" then
        return "beltlayer-"..reverse_direction[direction]..entity.name:sub(#"beltlayer" + 1)
      elseif entity.type == "underground-belt" then
        return "beltlayer-"..reverse_direction[direction].."-"..
          entity.belt_to_ground_type..entity.name:sub(#"beltlayer" + 1)
      end
    end

    local editor = global.editor
    local prototypes_by_name = game.get_filtered_entity_prototypes{{filter="transport-belt-connectable"}}
    local prototype_names = {}
    for name in pairs(prototypes_by_name) do
      if not name:find("^beltlayer%-bpproxy%-") then
        prototype_names[#prototype_names + 1] = name
      end
    end

    for _, surface in pairs(game.surfaces) do
      if editor:editor_surface_for_aboveground_surface(surface) then
        for _, entity in pairs(surface.find_entities_filtered{name = prototype_names}) do
          entity.surface.create_entity{
            name = new_proxy_name(entity),
            position = entity.position,
            force = entity.force,
            player = entity.last_user,
          }
          entity.destroy()
        end
      end
    end
  end,
}

return M