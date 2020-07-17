local function proxy_name(name, belt_to_ground_type)
  return "beltlayer-"..
    (belt_to_ground_type and (belt_to_ground_type .. "-") or "")..
    "bpproxy-"..name
end

return {
  proxy_name = proxy_name,
}