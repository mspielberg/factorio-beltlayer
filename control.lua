local Editor = require("Editor")

local function on_init()
  Editor.on_init()
end

local function on_load()
  Editor.on_load()
end

local function on_toggle_editor(event)
  Editor.toggle_editor_status_for_player(event.player_index)
end

local function on_chunk_generated(event)
  if event.surface == Editor.surface then
    Editor.on_chunk_generated(event)
  end
end

script.on_init(on_init)
script.on_load(on_load)
script.on_event("plumbing-toggle-editor-view", on_toggle_editor)
script.on_event(defines.events.on_chunk_generated, on_chunk_generated)