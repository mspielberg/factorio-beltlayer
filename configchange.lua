local Editor = require "Editor"
local version = require "lualib.version"

local M = {}

local function remove_orphans()
  Editor.restore(global.editor)
  local affected_surfaces = 0
  local removed_connectors = 0
  for _, surface in pairs(game.surfaces) do
    local did_remove_connector = false
    local editor_surface = global.editor:editor_surface_for_aboveground_surface(surface)
    if editor_surface then
      for _, linked_belt in pairs(surface.find_entities_filtered{type = "linked-belt"}) do
        if linked_belt.name:find("beltlayer%-connector") and not linked_belt.linked_belt_neighbour then
          linked_belt.destroy()
          removed_connectors = removed_connectors + 1
          did_remove_connector = true
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

add_migration{
  name = "v2_0_0_replace_with_linked_belts",
  version = {2,0,0},
  task = function()
    local editor = global.editor
    Editor.restore(editor)
    for _, surface in pairs(game.surfaces) do
      if editor:is_valid_aboveground_surface(surface) then
        local editor_surface = editor:editor_surface_for_aboveground_surface(surface)
        for _, loader in pairs(surface.find_entities_filtered{type = "loader-1x1"}) do
          if loader.name:find("beltlayer%-connector") then
            local position = loader.position
            local direction = loader.direction
            local force = loader.force
            local connector_type = loader.loader_type
            local last_user = loader.last_user

            local connector_name = loader.name:gsub("underground%-belt%-", "")
            local editor_connector = editor_surface.find_entity(loader.name, position)

            if editor_connector then
              loader.destroy()
              local connector = surface.create_entity{
                name = connector_name,
                position = position,
                direction = direction,
                type = connector_type,
                force = force,
                create_build_effect_smoke = false,
              }
              connector.last_user = last_user

              editor_connector.destroy()
              editor_connector = editor_surface.create_entity{
                name = connector_name,
                position = position,
                direction = direction,
                type = connector_type == "input" and "output" or "input",
                force = force,
                create_build_effect_smoke = false,
              }
              editor_connector.last_user = last_user
              editor_connector.minable = false
              connector.connect_linked_belts(editor_connector)
            end
          end
        end
      end
    end
    game.print("Beltlayer updated from version 1.x.\n"..
      "The names of beltlayer connectors have changed as part of this upgrade.\n"..
      "Any blueprints with [entity=beltlayer-connector] [color=red]must be re-created.[/color]")
  end,
}

add_migration{
  name = "v2_0_2_make_underground_connector_unminable",
  version = {2,0,2},
  task = function()
    local editor = global.editor
    Editor.restore(editor)
    for _, surface in pairs(game.surfaces) do
      if editor:is_editor_surface(surface) then
        for _, linked_belt in pairs(surface.find_entities_filtered{type = "linked-belt"}) do
          if linked_belt.name:find("beltlayer%-connector") then
            linked_belt.minable = false
          end
        end
      end
    end
  end,
}

return M