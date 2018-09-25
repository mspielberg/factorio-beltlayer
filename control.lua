local Blueprint = require "Blueprint"
local Connector = require "Connector"
local Editor = require "Editor"

local function on_init()
  Editor.on_init() -- init first to set up editor surface
  Blueprint.on_init()
  Connector.on_init()
end

local function on_load()
  Editor.on_load()
  Blueprint.on_load()
  Connector.on_load()
end

local event_handlers = {
  on_built_entity = function(event)
    if event.mod_name and event.mod_name ~= "upgrade-planner" then
      Blueprint.on_robot_built_entity(nil, event.created_entity, event.stack)
      Editor.on_robot_built_entity(nil, event.created_entity, event.stack)
    else
      Blueprint.on_player_built_entity(event)
      Editor.on_player_built_entity(event)
    end
  end,

  on_robot_built_entity = function(event)
    local robot = event.robot
    local entity = event.created_entity
    local stack = event.stack
    Blueprint.on_robot_built_entity(robot, entity, stack)
    Editor.on_robot_built_entity(robot, entity, stack)
  end,

  on_pre_player_mined_item = function(event)
    Blueprint.on_pre_player_mined_item(event)
  end,

  on_player_mined_item = function(event)
    Editor.on_player_mined_item(event)
  end,

  on_player_mined_entity = function(event)
    Editor.on_player_mined_entity(event)
  end,

  on_robot_mined_entity = function(event)
    local robot = event.robot
    local entity = event.entity
    local buffer = event.buffer
    Blueprint.on_robot_mined_entity(robot, entity, buffer)
    Editor.on_robot_mined_entity(robot, entity, buffer)
  end,

  on_player_setup_blueprint = function(event)
    Blueprint.on_player_setup_blueprint(event)
  end,

  on_pre_ghost_deconstructed = function(event)
    Blueprint.on_pre_ghost_deconstructed(event.player_index, event.ghost)
  end,

  on_player_deconstructed_area = function(event)
    Blueprint.on_player_deconstructed_area(event.player_index, event.area, event.item, event.alt)
  end,

  on_canceled_deconstruction = function(event)
    Blueprint.on_canceled_deconstruction(event.entity, event.player_index)
  end,

  on_player_rotated_entity = function(event)
     Editor.on_player_rotated_entity(event)
  end,

  on_entity_died = function(event)
    Editor.on_entity_died(event)
  end,

  on_tick = function(event)
    Connector.on_tick(event.tick)
  end,

  on_runtime_mod_setting_changed = function(event)
    Connector.on_runtime_mod_setting_changed(event.player_index, event.setting, event.setting_type)
  end,
}

local function on_toggle_editor(event)
  Editor.toggle_editor_status_for_player(event.player_index)
end

script.on_init(on_init)
script.on_load(on_load)
script.on_event("beltlayer-toggle-editor-view", on_toggle_editor)
for event_name, handler in pairs(event_handlers) do
  script.on_event(defines.events[event_name], handler)
end
script.on_event(defines.events.on_tick, nil)
script.on_nth_tick(10, event_handlers.on_tick)