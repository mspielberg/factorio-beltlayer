local add_shift = util.add_shift
local deepcopy = util.table.deepcopy
local merge = util.merge
local util = require "util"

local DEFAULT_INDEXES = { east = 1, west = 2, north = 3, south = 4, }
local function extract_sprites_from_animation_set(belt_animation_set)
  local out = {}
  for direction in pairs(DEFAULT_INDEXES) do
    local index = belt_animation_set[direction.."_index"] or DEFAULT_INDEXES[direction]
    local sprite = deepcopy(belt_animation_set.animation_set)
    sprite.y = sprite.height * (index - 1)
    if sprite.hr_version then
      sprite.hr_version.y = sprite.hr_version.height * (index - 1)
    end
    out[direction] = sprite
  end
  return out
end

local function extract_belt_sprites(proto)
  if proto.belt_animation_set then
    return extract_sprites_from_animation_set(proto.belt_animation_set)
  end
  return {
    north = proto.belt_vertical,
    east = proto.belt_horizontal,
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

local function add_tint(proto, tint)
  for k,v in pairs(proto) do
    if type(v) == "table" then
      if v.filename and v.width and v.height and not v.tint then
        v.tint = tint
      else
        add_tint(v, tint)
      end
    end
  end
end

local function make_transport_belt_proxy(proto)
  local proxy_proto = deepcopy(data.raw["constant-combinator"]["constant-combinator"])
  proxy_proto.name = util.proxy_name(proto.name)
  proxy_proto.icon = proto.icon
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
    local structure_sprite = deepcopy(proto.structure["direction_"..(belt_to_ground_type == "input" and "in" or "out")].sheet)
    structure_sprite.x =
      structure_sprite.width * (underground_belt_sprite_index[belt_to_ground_type][direction] - 1)
    if structure_sprite.hr_version then
      structure_sprite.hr_version.x =
        structure_sprite.hr_version.width * (underground_belt_sprite_index[belt_to_ground_type][direction] - 1)
    end
    out[direction] = { layers = { belt_sprite, structure_sprite } }
  end
  return out
end

local function make_underground_belt_proxies(proto)
  local out = {}
  for _, belt_to_ground_type in pairs{"input", "output"} do
    local proxy_proto = deepcopy(data.raw["constant-combinator"]["constant-combinator"])
    proxy_proto.name = util.proxy_name(proto.name, belt_to_ground_type)
    proxy_proto.icon = proto.icon
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

local function make_migration_proxy(proto)
  local proxy_proto = deepcopy(proto)
  proxy_proto.name = util.proxy_name(proto.name)
  proxy_proto.localised_name = {"entity-name.beltlayer-bpproxy", proto.localised_name or {"entity-name."..proto.name}}
  proxy_proto.collision_mask = {}
  proxy_proto.next_upgrade = nil
  add_tint(proxy_proto, {r = 1.5, g = 0.5, b = 0.8, a = 0.25})
  return proxy_proto
end

for _, type in ipairs{"underground-belt"} do
  for _, proto in pairs(data.raw[type]) do
    if proto.minable and not proto.name:find("^beltlayer%-bpproxy%-") then
      local bpproxy = make_migration_proxy(proto)
      data:extend{bpproxy}
    end
  end
end