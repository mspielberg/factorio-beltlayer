require "util"

local empty_sprite = {
  filename = "__core__/graphics/empty.png",
  width = 1,
  height = 1,
  frame_count = 1,
}

local overlay_icon = {
  icon = "__core__/graphics/icons/mip/collapse.png",
  icon_size = 32,
  icon_mipmaps = 2,
  scale = 0.5,
  shift = {-8, -8},
  tint = {r=1,g=.7,b=0},
}

local function make_connector(ug)
  local name = ug.name.."-beltlayer-connector"
  local loader = util.table.deepcopy(ug)
  loader.type = "linked-belt"
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
  loader.next_upgrade = loader.next_upgrade and loader.next_upgrade .. "-beltlayer-connector"

  if mods["space-exploration"] then
    loader.collision_mask = loader.collision_mask
      or { "object-layer", "item-layer", "water-tile", "transport-belt-layer" }
    table.insert(loader.collision_mask, space_collision_layer)
  end

  return loader
end

for name, ug in pairs(data.raw["underground-belt"]) do
  if ug.minable then
    data:extend{make_connector(ug)}
  end
end

data:extend{beltlayer_buffer}