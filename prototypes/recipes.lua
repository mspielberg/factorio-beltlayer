local deepcopy = util.table.deepcopy
local util = require "util"

local function find_underground_belt_result(recipe)
  for _, root in ipairs{recipe, recipe.normal, recipe.expensive} do
    if root then
      local results = root.results or {{name = root.result}}
      for _, result in ipairs(results) do
        local item_name = result.name or result[1]
        local item = data.raw.item[item_name]
        if item and item.place_result then
          if data.raw["underground-belt"][item.place_result] then
            return item_name
          end
        end
      end
    end
  end
end

local function make_recipe(proto, base_result)
  local recipe = deepcopy(proto)
  recipe.name = util.connector_name(recipe.name)
  local connector_item = util.connector_name(base_result)
  for _, root in ipairs{recipe, recipe.normal, recipe.expensive} do
    if root then
      root.icons = nil
      root.icon = nil
      root.icon_size = nil

      if root.main_product == base_result then
        root.main_product = connector_item
      end

      local count
      if root.results then
        for i, result in ipairs(root.results) do
          local item_name = result.name or result[1]
          if item_name == base_result then
            count = result.amount or result[2]
            root.results[i] = {name = connector_item, amount = 1}
          end
        end
      elseif root.result == base_result then
        root.result = connector_item
        count = root.result_count
        root.result_count = nil
      end

      count = count or 1

      if root.ingredients then
        for _, ingredient in ipairs(root.ingredients) do
          if ingredient.amount then
            ingredient.amount = math.ceil(ingredient.amount / count)
          elseif ingredient[2] then
            ingredient[2] = math.ceil(ingredient[2] / count)
          end
        end
      end
    end
  end

  recipe.result_count = 1
  return recipe
end

local new_recipes = {}
for _, recipe in pairs(data.raw.recipe) do
  local underground_belt_result = find_underground_belt_result(recipe)
  if underground_belt_result then
    local connector_recipe = make_recipe(recipe, underground_belt_result)
    new_recipes[#new_recipes+1] = connector_recipe
  end
end
data:extend(new_recipes)