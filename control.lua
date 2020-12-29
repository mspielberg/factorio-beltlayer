local configchange = require "configchange"
local Editor = require "Editor"

local editor

local function on_init()
  global.editor = Editor.new()
  editor = global.editor
end

local function on_load()
  if global.editor then
    editor = Editor.restore(global.editor)
  end
end

local function on_tick(event)
  editor:on_tick(event)
end

local event_handlers = {
  on_built_entity                  = function(event) editor:on_built_entity(event)                  end,
  on_cancelled_deconstruction      = function(event) editor:on_cancelled_deconstruction(event)      end,
  on_cancelled_upgrade             = function(event) editor:on_cancelled_upgrade(event)             end,
  on_entity_died                   = function(event) editor:on_entity_died(event)                   end,
  on_marked_for_deconstruction     = function(event) editor:on_marked_for_deconstruction(event)     end,
  on_marked_for_upgrade            = function(event) editor:on_marked_for_upgrade(event)            end,
  on_player_deconstructed_area     = function(event) editor:on_player_deconstructed_area(event)     end,
  on_player_main_inventory_changed = function(event) editor:on_player_main_inventory_changed(event) end,
  on_player_mined_entity           = function(event) editor:on_player_mined_entity(event)           end,
  on_player_mined_item             = function(event) editor:on_player_mined_item(event)             end,
  on_player_rotated_entity         = function(event) editor:on_player_rotated_entity(event)         end,
  on_player_setup_blueprint        = function(event) editor:on_player_setup_blueprint(event)        end,
  on_pre_build                     = function(event) editor:on_pre_build(event)                     end,
  on_pre_ghost_deconstructed       = function(event) editor:on_pre_ghost_deconstructed(event)       end,
  on_pre_player_mined_item         = function(event) editor:on_pre_player_mined_item(event)         end,
  on_robot_built_entity            = function(event) editor:on_robot_built_entity(event)            end,
  on_robot_mined_entity            = function(event) editor:on_robot_mined_entity(event)            end,
  script_raised_built              = function(event) editor:script_raised_built(event)              end,
  script_raised_destroy            = function(event) editor:script_raised_destroy(event)            end,
  script_raised_revive             = function(event) editor:script_raised_revive(event)             end,
}

local function on_configuration_changed(data)
  if data.mod_changes.beltlayer and data.mod_changes.beltlayer.old_version then
    configchange.on_mod_version_changed(data.mod_changes.beltlayer.old_version)
    editor = global.editor
  end
  editor:on_configuration_changed(data)
end

local function on_toggle_editor(event)
  editor:toggle_editor_status_for_player(event.player_index)
end

script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_configuration_changed)
script.on_event("beltlayer-toggle-editor-view", on_toggle_editor)
for event_name, handler in pairs(event_handlers) do
  local event_id = defines.events[event_name]
  if not event_id then error("unknown event: "..event_name) end
  script.on_event(event_id, handler)
end
script.on_nth_tick(10, on_tick)