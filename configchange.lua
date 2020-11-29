local Editor = require "Editor"
local version = require "lualib.version"

local M = {}

local function remove_orphans()
  Editor.restore(global.editor)
  local affected_surfaces = 0
  local removed_connectors = 0
  for _, surface in pairs(game.surfaces) do
    local did_remove_connector = false
    local counterpart_surface = global.editor:counterpart_surface(surface)
    if counterpart_surface then
      for _, loader in pairs(surface.find_entities_filtered{type = "loader-1x1"}) do
        if loader.name:find("%-beltlayer%-connector$") then
          local position = loader.position
          local counterpart_connector = counterpart_surface.find_entity(loader.name, position)
          if not counterpart_connector then
            local buffer = surface.find_entity("beltlayer-buffer", position)
            if buffer then buffer.destroy() end
            buffer = counterpart_surface.find_entity("beltlayer-buffer", position)
            if buffer then buffer.destroy() end
            loader.destroy()
            removed_connectors = removed_connectors + 1
            did_remove_connector = true
          end
        end
      end
    end
    if did_remove_connector then
      affected_surfaces = affected_surfaces + 1
    end
  end
  if removed_connectors > 0 then
    log("Removed "..removed_connectors.." orphan connector(s) on "..affected_surfaces.." surface(s).")
  end
end

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
  remove_orphans()
end

add_migration{
  name = "v0_6_0_change_bpproxies_to_constant_combinator",
  version = {0,6,0},
  task = function()
    local editor = global.editor
    local prototypes_by_name = game.get_filtered_entity_prototypes{{filter = "transport-belt-connectable"}}
    local prototype_names = {}
    for name in pairs(prototypes_by_name) do
      if name:find("^beltlayer%-bpproxy%-") then
        prototype_names[#prototype_names + 1] = name
      end
    end

    local function new_proxy_name(entity)
      return "beltlayer-"..entity.belt_to_ground_type..entity.name:sub(#"beltlayer-")
    end

    for _, surface in pairs(game.surfaces) do
      if editor:editor_surface_for_aboveground_surface(surface) then
        for _, entity in pairs(surface.find_entities_filtered{name = prototype_names}) do
          entity.order_deconstruction(entity.force, entity.last_user)
          if entity.type == "underground-belt" then
            local new_bpproxy = entity.surface.create_entity{
              name = new_proxy_name(entity),
              position = entity.position,
              direction = entity.direction,
              force = entity.force,
              player = entity.last_user,
            }
            new_bpproxy.order_deconstruction(entity.force, entity.last_user)
            entity.destroy()
          end
        end
      end
    end
  end,
}

return M