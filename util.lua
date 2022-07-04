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

local function find_underground_belt_result(recipe)
  for _, root in ipairs{recipe, recipe.normal, recipe.expensive} do
    if root then
      local results = root.results or {{ name = root.result, amount = root.result_count or 1 }}
      for _, result in ipairs(results) do
        local item_name = result.name or result[1]
        local item_amount = result.amount or result[2]
        local item = data.raw.item[item_name]
        if item and item.place_result then
          if data.raw["underground-belt"][item.place_result] and item_amount <= 2 then
            return item_name
          end
        end
      end
    end
  end
end

return {
  connector_name = connector_name,
  find_underground_belt_result = find_underground_belt_result,
  proxy_name = proxy_name,
}