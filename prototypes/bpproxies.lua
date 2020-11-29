local add_shift = util.add_shift
local deepcopy = util.table.deepcopy
local merge = util.merge
local util = require "util"

local DEFAULT_INDEXES = { east = 1, west = 2, north = 3, south = 4, }
local function extract_sprites_from_animation_set(belt_animation_set)
  local out = {}
  for direction in pairs(DEFAULT_INDEXES) do
    local index = belt_animation_set[direction.."_index"] or DEFAULT_INDEXES[direction]
    local original_layers = belt_animation_set.animation_set.layers or {belt_animation_set.animation_set}
    local new_layers = deepcopy(original_layers)
    for _, layer in pairs(new_layers) do
      layer.y = layer.height * (index - 1)
      if layer.hr_version then
        layer.hr_version.y = layer.hr_version.height * (index - 1)
      end
    end
    out[direction] = { layers = new_layers }
  end
  return out
end

local function extract_belt_sprites(proto)
  if proto.belt_animation_set then
    return extract_sprites_from_animation_set(proto.belt_animation_set)
  end
  return {
    north = deepcopy(proto.belt_vertical),
    east = deepcopy(proto.belt_horizontal),
    south = merge{proto.belt_vertical, { scale = -1 }},
    west = merge{proto.belt_horizontal, { scale = -1 }},
  }
end

local function make_placeable_by(entity_proto)
  local placeable_by = {}
  local entity_name = entity_proto.name
  for _, protos in pairs(data.raw) do
    for item_name, item_proto in pairs(protos) do
      if item_proto.place_result == entity_name then
        placeable_by[#placeable_by+1] = {item = item_name, count = 1}
      end
    end
  end
  return placeable_by
end

local function add_tint(t, tint)
  for _, v in pairs(t) do
    if type(v) == "table" then
      add_tint(v, tint)
    end
  end
  if t.filename and t.width and t.height and not t.tint then
    t.tint = tint
  end
end

local function make_transport_belt_proxy(proto)
  local proxy_proto = deepcopy(data.raw["constant-combinator"]["constant-combinator"])
  proxy_proto.name = util.proxy_name(proto.name)
  proxy_proto.icon = proto.icon
  proxy_proto.icon_size = proto.icon_size
  proxy_proto.icons = proto.icons
  proxy_proto.item_slot_count = 0
  proxy_proto.max_circuit_wire_distance = 0
  proxy_proto.localised_name = {"entity-name.beltlayer-bpproxy", proto.localised_name or {"entity-name."..proto.name}}
  proxy_proto.minable_properties = deepcopy(proto.minable_properties)
  proxy_proto.selection_box = deepcopy(proto.selection_box)
  proxy_proto.collision_box = deepcopy(proto.collision_box)
  proxy_proto.collision_mask = {}
  proxy_proto.flags = {"player-creation"}
  proxy_proto.fast_replaceable_group = proto.fast_replaceable_group
  proxy_proto.next_upgrade = proto.next_upgrade and util.proxy_name(proto.next_upgrade)
  proxy_proto.sprites = extract_belt_sprites(proto)
  proxy_proto.placeable_by = make_placeable_by(proto)
  add_tint(proxy_proto, {r = 0.5, g = 0.5, b = 0.8, a = 0.25})
  return proxy_proto
end

for name, proto in pairs(data.raw["transport-belt"]) do
  if not name:find("^replicating%-") then
    data:extend{make_transport_belt_proxy(proto)}
  end
end

local underground_belt_sprite_index = {
  input = { north = 1, east = 2, south = 3, west = 4 },
  output = { north = 3, east = 4, south = 1, west = 2 },
}
local function make_underground_belt_sprites(proto, belt_to_ground_type)
  local out = {}
  local belt_sprites = extract_belt_sprites(proto)
  for direction in pairs(DEFAULT_INDEXES) do
    local belt_sprite = belt_sprites[direction]
    local structure_sprite = deepcopy(proto.structure["direction_"..(belt_to_ground_type == "input" and "in" or "out")])
    local structure_sheets = structure_sprite.sheets or { structure_sprite.sheet }
    for _, sheet in pairs(structure_sheets) do
      sheet.x =
        sheet.width * (underground_belt_sprite_index[belt_to_ground_type][direction] - 1)
      if sheet.hr_version then
        sheet.hr_version.x =
          sheet.hr_version.width * (underground_belt_sprite_index[belt_to_ground_type][direction] - 1)
      end
    end
    local layers = deepcopy(belt_sprite.layers)
    for i = 1, #structure_sheets do
      layers[#belt_sprite + i] = structure_sheets[i]
    end
    out[direction] = { layers = layers }
  end
  return out
end

local function make_underground_belt_proxies(proto)
  local out = {}
  for _, belt_to_ground_type in pairs{"input", "output"} do
    local proxy_proto = deepcopy(data.raw["constant-combinator"]["constant-combinator"])
    proxy_proto.name = util.proxy_name(proto.name, belt_to_ground_type)
    proxy_proto.icon = proto.icon
    proxy_proto.icon_size = proto.icon_size
    proxy_proto.icons = proto.icons
    proxy_proto.localised_name = {"entity-name.beltlayer-bpproxy", proto.localised_name or {"entity-name."..proto.name}}
    proxy_proto.minable_properties = deepcopy(proto.minable_properties)
    proxy_proto.selection_box = deepcopy(proto.selection_box)
    proxy_proto.collision_box = deepcopy(proto.collision_box)
    proxy_proto.collision_mask = {}
    proxy_proto.flags = {"player-creation"}
    proxy_proto.fast_replaceable_group = proto.fast_replaceable_group
    proxy_proto.next_upgrade = proto.next_upgrade and util.proxy_name(proto.next_upgrade, belt_to_ground_type)
    proxy_proto.sprites =
      make_underground_belt_sprites(proto, belt_to_ground_type)
    proxy_proto.placeable_by = make_placeable_by(proto)
    add_tint(proxy_proto, {r = 0.5, g = 0.5, b = 0.8, a = 0.25})
    out[#out+1] = proxy_proto
  end
  return out
end

for _, proto in pairs(data.raw["underground-belt"]) do
  data:extend(make_underground_belt_proxies(proto))
end

local function rotated_point(point, direction)
  if direction == "north" then
    return point
  elseif direction == "east" then
    return {-point[2], point[1]}
  elseif direction == "south" then
    return {-point[1], -point[2]}
  elseif direction == "west" then
    return { point[2], -point[1]}
  end
end

local function make_splitter_proxy_sprites(proto)
  local out = {}
  local belt_sprites = extract_belt_sprites(proto)
  for direction in pairs(DEFAULT_INDEXES) do
    local belt_sprite_l = belt_sprites[direction]
    local belt_sprite_r = deepcopy(belt_sprite_l)
    belt_sprite_l.shift = add_shift(belt_sprite_l.shift, rotated_point({-0.5, 0}, direction))
    belt_sprite_r.shift = add_shift(belt_sprite_r.shift, rotated_point({ 0.5, 0}, direction))

    out[direction] = {
      layers = {
        belt_sprite_l,
        belt_sprite_r,
        deepcopy(proto.structure[direction]),
      }
    }
    if proto.structure_patch then
      table.insert(out[direction].layers, 3, deepcopy(proto.structure_patch[direction]))
    end
  end
  return out
end

local function make_splitter_proxy(proto)
  local proxy_proto = deepcopy(data.raw["constant-combinator"]["constant-combinator"])
  proxy_proto.name = util.proxy_name(proto.name)
  proxy_proto.icon = proto.icon
  proxy_proto.icon_size = proto.icon_size
  proxy_proto.icons = proto.icons
  proxy_proto.localised_name = {"entity-name.beltlayer-bpproxy", proto.localised_name or {"entity-name."..proto.name}}
  proxy_proto.minable_properties = deepcopy(proto.minable_properties)
  proxy_proto.selection_box = deepcopy(proto.selection_box)
  proxy_proto.collision_box = deepcopy(proto.collision_box)
  proxy_proto.collision_mask = {}
  proxy_proto.flags = {"player-creation"}
  proxy_proto.fast_replaceable_group = proto.fast_replaceable_group
  proxy_proto.sprites = make_splitter_proxy_sprites(proto)
  proxy_proto.next_upgrade = proto.next_upgrade and util.proxy_name(proto.next_upgrade)
  proxy_proto.placeable_by = make_placeable_by(proto)
  add_tint(proxy_proto, {r = 0.5, g = 0.5, b = 0.8, a = 0.25})
  return proxy_proto
end

for _, proto in pairs(data.raw["splitter"]) do
  data:extend{make_splitter_proxy(proto)}
end