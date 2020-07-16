local deepcopy = util.table.deepcopy
local util = require "util"

local DEFAULT_INDEXES = { east = 1, west = 2, north = 3, south = 4, }
local function extract_animation(belt_animation_set, direction)
  local index = belt_animation_set[direction.."_index"] or DEFAULT_INDEXES[direction]
  local out = deepcopy(belt_animation_set.animation_set)
  out.y = out.height * (index - 1)
  out.variation_count = 1
  out.frame_count = 1
  out.direction_count = nil
  if out.hr_version then
    out.hr_version.y = out.hr_version.height * (index - 1)
    out.hr_version.variation_count = 1
    out.hr_version.frame_count = 1
    out.hr_version.direction_count = nil
  end
  return out
end

local function add_items_to_placeable_by(entity_proto)
  entity_proto.placeable_by = entity_proto.placeable_by or {}
  local placeable_by = entity_proto.placeable_by
  local entity_name = entity_proto.name
  for _, protos in pairs(data.raw) do
    for item_name, item_proto in pairs(protos) do
      if item_proto.place_result == entity_name then
        placeable_by[#placeable_by+1] = {item = item_name, count = 1}
      end
    end
  end
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

local function make_transport_belt_proxies(proto)
  local out = {}
  for direction in pairs(DEFAULT_INDEXES) do
    local proxy_proto = deepcopy(proto)
    add_items_to_placeable_by(proxy_proto)
    proxy_proto.name = util.proxy_name(proto.name, direction)
    proxy_proto.type = "simple-entity-with-owner"
    proxy_proto.localised_name = {"entity-name.beltlayer-bpproxy", proto.localised_name or {"entity-name."..proto.name}}
    proxy_proto.collision_mask = {}
    proxy_proto.flags = {"player-creation"}
    proxy_proto.next_upgrade = proto.next_upgrade and util.proxy_name(proto.next_upgrade, direction)
    proxy_proto.animations = {
      sheet = extract_animation(proto.belt_animation_set, direction)
    }
    add_tint(proxy_proto, {r = 0.5, g = 0.5, b = 0.8, a = 0.25})
    out[#out+1] = proxy_proto
  end
  return out
end

for _, proto in pairs(data.raw["transport-belt"]) do
  data:extend(make_transport_belt_proxies(proto))
end

local sprite4way_index = {
  input = { north = 1, east = 2, south = 3, west = 4 },
  output = { north = 3, east = 4, south = 1, west = 2 },
}
local function sprite4way_to_animation(sprite4way, direction, belt_to_ground_type)
  if sprite4way.sheet then
    local out = deepcopy(sprite4way.sheet)
    out.x = (sprite4way_index[belt_to_ground_type][direction] - 1) * out.width
    out.variation_count = 1
    out.frame_count = 1
    if out.hr_version then
      out.hr_version.x = (sprite4way_index[belt_to_ground_type][direction] - 1) * out.hr_version.width
      out.hr_version.variation_count = 1
      out.hr_version.frame_count = 1
    end
    return out
  end
end

local function make_underground_belt_proxies(proto)
  local out = {}
  for direction in pairs(DEFAULT_INDEXES) do
    for _, belt_to_ground_type in pairs{"input", "output"} do
      local proxy_proto = deepcopy(proto)
      add_items_to_placeable_by(proxy_proto)
      proxy_proto.name = util.proxy_name(proto.name, direction, belt_to_ground_type)
      proxy_proto.type = "simple-entity-with-owner"
      proxy_proto.localised_name = {"entity-name.beltlayer-bpproxy", proto.localised_name or {"entity-name."..proto.name}}
      proxy_proto.collision_mask = {}
      proxy_proto.flags = {"player-creation"}
      proxy_proto.next_upgrade = proto.next_upgrade and util.proxy_name(proto.next_upgrade, direction, belt_to_ground_type)

      local structure_animation = sprite4way_to_animation(
        proto.structure["direction_"..(belt_to_ground_type == "input" and "in" or "out")],
        direction,
        belt_to_ground_type)
      proxy_proto.animations = {
        sheets = {
          extract_animation(proto.belt_animation_set, direction),
          structure_animation,
        }
      }

      add_tint(proxy_proto, {r = 0.5, g = 0.5, b = 0.8, a = 0.25})
      out[#out+1] = proxy_proto
    end
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

local function add_shift(sprite, shift, direction)
  local actual_shift = rotated_point(shift, direction)
  sprite.shift = sprite.shift or {0,0}
  sprite.shift[1] = sprite.shift[1] + actual_shift[1]
  sprite.shift[2] = sprite.shift[2] + actual_shift[2]
end

local function rotate_box(box, direction)
  box[1] = rotated_point(box[1], direction)
  box[2] = rotated_point(box[2], direction)
  if box[2][1] < box[1][1] then
    box[1][1], box[2][1] = box[2][1], box[1][1]
  end
  if box[2][2] < box[1][2] then
    box[1][2], box[2][2] = box[2][2], box[1][2]
  end
end

local function make_splitter_proxies(proto)
  local out = {}
  for direction in pairs(DEFAULT_INDEXES) do
      local proxy_proto = deepcopy(proto)
      add_items_to_placeable_by(proxy_proto)
      proxy_proto.name = util.proxy_name(proto.name, direction)
      proxy_proto.type = "simple-entity-with-owner"
      proxy_proto.localised_name = {"entity-name.beltlayer-bpproxy", proto.localised_name or {"entity-name."..proto.name}}
      proxy_proto.collision_mask = {}
      proxy_proto.flags = {"player-creation"}
      proxy_proto.next_upgrade = proto.next_upgrade and util.proxy_name(proto.next_upgrade, direction)

      rotate_box(proxy_proto.collision_box, direction)
      rotate_box(proxy_proto.selection_box, direction)

      local belt_animation_w = extract_animation(proto.belt_animation_set, direction)
      local belt_animation_e = deepcopy(belt_animation_w)
      add_shift(belt_animation_w, {-0.5, 0}, direction)
      add_shift(belt_animation_e, { 0.5, 0}, direction)

      local structure_animation = deepcopy(proxy_proto.structure[direction])
      structure_animation.variation_count = 1
      structure_animation.frame_count = 1
      if structure_animation.hr_version then
        structure_animation.hr_version.variation_count = 1
        structure_animation.hr_version.frame_count = 1
      end

      local patch_animation = deepcopy(proxy_proto.structure_patch[direction])
      patch_animation.variation_count = 1
      patch_animation.frame_count = 1
      if patch_animation.hr_version then
        patch_animation.hr_version.variation_count = 1
        patch_animation.hr_version.frame_count = 1
      end

      proxy_proto.animations = {
        sheets = {
          belt_animation_w,
          belt_animation_e,
          patch_animation,
          structure_animation,
        }
      }

      add_tint(proxy_proto, {r = 0.5, g = 0.5, b = 0.8, a = 0.25})
      out[#out+1] = proxy_proto
  end
  return out
end

for _, proto in pairs(data.raw["splitter"]) do
  data:extend(make_splitter_proxies(proto))
end

local function make_migration_proxy(proto)
  local proxy_proto = deepcopy(proto)
  add_items_to_placeable_by(proxy_proto)
  proxy_proto.name = util.proxy_name(proto.name)
  proxy_proto.localised_name = {"entity-name.beltlayer-bpproxy", proto.localised_name or {"entity-name."..proto.name}}
  proxy_proto.collision_mask = {}
  proxy_proto.flags = {"player-creation"}
  proxy_proto.next_upgrade = proto.next_upgrade and "beltlayer-bpproxy-"..proto.next_upgrade
  add_tint(proxy_proto, {r = 0.5, g = 0.5, b = 0.8, a = 0.25})
  return proxy_proto
end

for _, type in ipairs{"splitter", "transport-belt", "underground-belt"} do
  for _, proto in pairs(data.raw[type]) do
    if proto.minable and not proto.name:find("^beltlayer%-bpproxy%-") then
      local bpproxy = make_migration_proxy(proto)
      data:extend{bpproxy}
    end
  end
end