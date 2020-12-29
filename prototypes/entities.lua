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
  local name = ug.name:gsub("underground%-belt", "beltlayer-connector")
  local connector = util.table.deepcopy(ug)
  connector.type = "linked-belt"
  connector.name = name
  connector.localised_name = {"entity-name.beltlayer-connector", ug.localised_name or {"entity-name."..ug.name}}
  connector.localised_description = {"entity-description.beltlayer-connector"}
  if connector.icons then
    table.insert(connector.icons, overlay_icon)
  else
    connector.icons = {
      {
        icon = ug.icon,
        icon_size = ug.icon_size,
      },
      overlay_icon,
    }
  end
  connector.minable.result = name
  connector.max_distance = nil
  connector.underground_sprite = nil
  connector.underground_remove_belts_sprite = nil
  connector.fast_replaceable_group = "beltlayer-connector"
  connector.next_upgrade =
    connector.next_upgrade and connector.next_upgrade:gsub("underground%-belt", "beltlayer-connector")

  if mods["space-exploration"] then
    connector.collision_mask = connector.collision_mask
      or { "object-layer", "item-layer", "water-tile", "transport-belt-layer" }
    table.insert(connector.collision_mask, space_collision_layer)
  end

  return connector
end

local function make_migration_connector(ug)
  local migration_connector = util.table.deepcopy(ug)
  migration_connector.name = ug.name.."-beltlayer-connector"
  return migration_connector
end

for name, ug in pairs(data.raw["underground-belt"]) do
  if ug.minable and not name:find("beltlayer%-connector") then
    data:extend{--[[make_connector(ug), ]]make_migration_connector(ug)}
  end
end