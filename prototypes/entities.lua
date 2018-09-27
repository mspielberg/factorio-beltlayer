require "util"

local empty_sprite = {
  filename = "__core__/graphics/empty.png",
  width = 0,
  height = 0,
  frame_count = 1,
}

local overlay_icon = {
  icon = "__core__/graphics/arrows/indication-arrow-up-to-down.png",
  icon_size = 64,
  scale = 0.25,
  shift = {8, -8},
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

  return loader
end

local fastest_belt_speed = 0
for _, ug in pairs(data.raw["underground-belt"]) do
  if ug.minable then
    if ug.speed > fastest_belt_speed then fastest_belt_speed = ug.speed end
    local loader = make_connector(ug)
    data:extend{loader}
  end
end

local max_items_per_tick = fastest_belt_speed * 2 / (9 / 32)
local max_stacks_per_tick = max_items_per_tick / 50
local max_stacks_per_update = max_stacks_per_tick * 60 * 5
log("projected max stacks per update: "..max_stacks_per_update)

data:extend{
  {
    type = "container",
    name = "beltlayer-buffer",
    collision_box = {{-0.1, -0.1}, {0.1, 0.1}},
    collision_mask = {},
    flags = {"player-creation", "hide-alt-info", "not-blueprintable", "not-deconstructable"},
    inventory_size = max_stacks_per_update * 2,
    picture = empty_sprite,
  }
}