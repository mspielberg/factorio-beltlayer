require "util"

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

local function make_proxy(proto)
  local proxy_proto = util.table.deepcopy(proto)
  proxy_proto.name = "beltlayer-bpproxy-"..proto.name
  proxy_proto.localised_name = {"entity-name.beltlayer-bpproxy", proto.localised_name or {"entity-name."..proto.name}}
  proxy_proto.collision_mask = {}
  proxy_proto.flags = {"player-creation"}
  proxy_proto.placeable_by = proxy_proto.placeable_by or {{item=proto.minable.result, count=1}}
  proxy_proto.next_upgrade = proto.next_upgrade and "beltlayer-bpproxy-"..proto.next_upgrade
  add_tint(proxy_proto, {r = 0.5, g = 0.5, b = 0.8, a = 0.25})
  return proxy_proto
end

for _, type in ipairs{"splitter", "transport-belt", "underground-belt"} do
  for _, proto in pairs(data.raw[type]) do
    if proto.minable and not proto.name:find("^beltlayer%-bpproxy%-") then
      data:extend{make_proxy(proto)}
    end
  end
end