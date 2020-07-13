local deepcopy = util.table.deepcopy
local util = require "util"

local DEFAULT_INDEXES = { east = 1, west = 2, north = 3, south = 4, }
local function extract_animation(belt_animation_set, direction)
  local index = belt_animation_set[direction.."_index"] or DEFAULT_INDEXES[direction]
  local out = deepcopy(belt_animation_set.animation_set)
  out.y = out.height * (index - 1)
  out.variation_count = 1
  out.direction_count = nil
  if out.hr_version then
    out.hr_version.y = out.hr_version.height * (index - 1)
    out.hr_version.variation_count = 1
    out.hr_version.direction_count = nil
  end
  return out
end

local function to_animation4way(belt_animation_set)
  local out = {}
  for direction in pairs(DEFAULT_INDEXES) do
    out[direction] = extract_animation(belt_animation_set, direction)
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

-- local function make_base_proxy(proto)
--   local proxy_proto = deepcopy(proto)
--   add_items_to_placeable_by(proxy_proto)
--   proxy_proto.name = util.proxy_name(proto.name, "beltlayer-bpproxy-"..proto.name)
--   proxy_proto.type = "electric-energy-interface"
--   proxy_proto.animations = to_animation4way(proto.belt_animation_set)
--   proxy_proto.localised_name = {"entity-name.beltlayer-bpproxy", proto.localised_name or {"entity-name."..proto.name}}
--   proxy_proto.collision_mask = {}
--   proxy_proto.flags = {"player-creation"}
--   proxy_proto.next_upgrade = proto.next_upgrade and "beltlayer-bpproxy-"..proto.next_upgrade
--   add_tint(proxy_proto, {r = 0.5, g = 0.5, b = 0.8, a = 0.25})
--   proxy_proto.circuit_wire_max_distance = nil
--   return proxy_proto
-- end

-- for _, type in ipairs{"splitter", "transport-belt", "underground-belt"} do
--   for _, proto in pairs(data.raw[type]) do
--     if proto.minable and not proto.name:find("^beltlayer%-bpproxy%-") then
--       local bpproxy = make_proxy(proto)
--       data:extend{bpproxy}
--     end
--   end
-- end

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
local function sprite4way_to_animation(sprite4way, direction, belt_to_ground_type, frame_count)
  local frame_sequence = {}
  for i=1,frame_count do frame_sequence[i] = 1 end
  if sprite4way.sheet then
    local out = deepcopy(sprite4way.sheet)
    out.x = (sprite4way_index[belt_to_ground_type][direction] - 1) * out.width
    out.variation_count = 1
    out.frame_sequence = frame_sequence
    --out.repeat_count = frame_count
    if out.hr_version then
      out.hr_version.x = (sprite4way_index[belt_to_ground_type][direction] - 1) * out.hr_version.width
      out.hr_version.variation_count = 1
      out.hr_version.frame_sequence = frame_sequence
      --out.hr_version.repeat_count = frame_count
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
        belt_to_ground_type,
        proto.belt_animation_set.animation_set.frame_count)
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