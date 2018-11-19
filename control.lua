local configchange = require "configchange"
local Connector = require "Connector"
local Editor = require "Editor"

local editor

local function on_init()
  editor = Editor.instance()
  Connector.on_init()
end

local function on_load()
  if global.editor then
    editor = global.editor
  end
  Editor.on_load()
  Connector.on_load()
end

local event_handlers = {
  on_built_entity = function(event)
    editor:on_player_built_entity(event)
  end,

  on_robot_built_entity = function(event)
    editor:on_robot_built_entity(event)
  end,

  on_picked_up_item = function(event)
    editor:on_picked_up_item(event)
  end,

  on_pre_player_mined_item = function(event)
    editor:on_pre_player_mined_item(event)
  end,

  on_player_mined_item = function(event)
    editor:on_player_mined_item(event)
  end,

  on_player_mined_entity = function(event)
    editor:on_player_mined_entity(event)
  end,

  on_robot_mined_entity = function(event)
    editor:on_robot_mined_entity(event)
  end,

  on_player_setup_blueprint = function(event)
    editor:on_player_setup_blueprint(event)
  end,

  on_pre_ghost_deconstructed = function(event)
    editor:on_pre_ghost_deconstructed(event)
  end,

  on_player_deconstructed_area = function(event)
    editor:on_player_deconstructed_area(event)
  end,

  on_canceled_deconstruction = function(event)
    editor:on_canceled_deconstruction(event)
  end,

  on_player_rotated_entity = function(event)
    editor:on_player_rotated_entity(event)
  end,

  on_entity_died = function(event)
    editor:on_entity_died(event)
  end,

  on_tick = function(event)
    Connector.on_tick(event.tick)
    editor:on_tick(event)
  end,

  on_runtime_mod_setting_changed = function(event)
    Connector.on_runtime_mod_setting_changed(event.player_index, event.setting, event.setting_type)
  end,
}

local function on_toggle_editor(event)
  editor:toggle_editor_status_for_player(event.player_index)
end

script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(function(event)
  if event.mod_changes.beltlayer then
    configchange.on_mod_version_changed(event.mod_changes.beltlayer.old_version)
    editor = global.editor
  end
end)
script.on_event("beltlayer-toggle-editor-view", on_toggle_editor)
for event_name, handler in pairs(event_handlers) do
  script.on_event(defines.events[event_name], handler)
end
script.on_event(defines.events.on_tick, nil)
script.on_nth_tick(10, event_handlers.on_tick)