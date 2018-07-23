require "util"

local overlay_icon = {
  icon = "__core__/graphics/arrows/indication-arrow-up-to-down.png",
  icon_size = 64,
  scale = 0.25,
  shift = {8, -8},
}

local function make_item(proto)
  local item = util.table.deepcopy(proto)
  item.name = item.name.."-beltlayer-connector"
  item.localised_name = data.raw["loader"][item.name].localised_name
  item.place_result = item.name
  if item.icons then
    table.insert(item.icons, overlay_icon)
  else
    item.icons = {
      {
        icon = item.icon,
        icon_size = item.icon_size,
      },
      overlay_icon,
    }
  end
  return item
end

for _, item in pairs(data.raw.item) do
  local place_result = item.place_result
  if place_result then
    if data.raw["underground-belt"][place_result] then
      data:extend{make_item(item)}
    end
  end
end