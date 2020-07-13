local reverse_direction = {}
for k, v in pairs(defines.direction) do
  reverse_direction[v] = k
end

local function proxy_name(name, direction, belt_to_ground_type)
  if type(direction) == "number" then
    direction = reverse_direction[direction]
  end
  return "beltlayer-"..
    (direction and (direction .. "-") or "")..
    (belt_to_ground_type and (belt_to_ground_type .. "-") or "")..
    "bpproxy-"..name
end

return {
  proxy_name = proxy_name,
}