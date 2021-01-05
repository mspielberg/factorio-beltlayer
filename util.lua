local function connector_name(underground_belt_name)
  if underground_belt_name:find("^ye_tranport") then
    return underground_belt_name:gsub("_underground", "-beltlayer-connector")
  end
  return underground_belt_name:gsub("underground%-belt", "beltlayer-connector")
end

local function proxy_name(name, belt_to_ground_type)
  return "beltlayer-"..
    (belt_to_ground_type and (belt_to_ground_type .. "-") or "")..
    "bpproxy-"..name
end

return {
  connector_name = connector_name,
  proxy_name = proxy_name,
}