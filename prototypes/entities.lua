require "util"

local empty_sprite = {
  filename = "__core__/graphics/empty.png",
  width = 1,
  height = 1,
  frame_count = 1,
}

local overlay_icon = {
  icon = "__core__/graphics/icons/collapse.png",
  icon_size = 32,
  scale = 0.5,
  shift = {8, -8},
  tint = {r=1,g=.7,b=0},
}

local function make_connector(ug)
  local name = ug.name.."-beltlayer-connector"
  local loader = util.table.deepcopy(ug)
  loader.type = "loader"
  loader.name = name
  loader.localised_name = {"entity-name.beltlayer-connector", ug.localised_name or {"entity-name."..ug.name}}
  loader.localised_description = {"entity-description.beltlayer-connector"}
  if loader.icons then
    table.insert(loader.icons, overlay_icon)
  else
    loader.icons = {
      {
        icon = ug.icon,
        icon_size = ug.icon_size,
      },
      overlay_icon,
    }
  end
  loader.minable.result = name
  loader.max_distance = nil
  loader.underground_sprite = nil
  loader.underground_remove_belts_sprite = nil
  loader.fast_replaceable_group = "beltlayer-connector"
  loader.filter_count = 0
  loader.container_distance = 0
  loader.belt_distance = 0
  loader.next_upgrade = loader.next_upgrade and loader.next_upgrade .. "-beltlayer-connector"

  return loader
end

for name, ug in pairs(data.raw["underground-belt"]) do
  if ug.minable then
    data:extend{make_connector(ug)}
  end
end

local beltlayer_buffer = {
  type = "container",
  name = "beltlayer-buffer",
  collision_box = {{-0.1, -0.1}, {0.1, 0.1}},
  collision_mask = {},
  selection_box = {{-0.2, -0.2}, {0.2, 0.2}},
  selection_priority = 100,
  flags = {"player-creation", "not-blueprintable", "not-deconstructable"},
  inventory_size = settings.startup["beltlayer-buffer-stacks"].value,
  picture = empty_sprite,
}
if not settings.startup["beltlayer-show-buffer-contents"].value then
  beltlayer_buffer.flags[#beltlayer_buffer.flags+1] = "hide-alt-info"
  beltlayer_buffer.selection_box = nil
end

data:extend{beltlayer_buffer}