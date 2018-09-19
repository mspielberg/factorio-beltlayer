require "util"

local function find_underground_belt_result(recipe)
  for _, root in ipairs{recipe, recipe.normal, recipe.expensive} do
    if root then
      local results = root.results or {{name = root.result}}
      for _, result in ipairs(results) do
        local item = data.raw.item[result.name]
        if item and item.place_result then
          if data.raw["underground-belt"][item.place_result] then
            return result.name
          end
        end
      end
    end
  end
end

local function make_recipe(proto, base_result)
  local recipe = util.table.deepcopy(proto)
  recipe.name = recipe.name.."-beltlayer-connector"
  local connector_item = base_result.."-beltlayer-connector"
  recipe.result_count = 1
  for _, root in ipairs{recipe, recipe.normal, recipe.expensive} do
    if root then
      root.icons = nil
      root.icon = nil
      root.icon_size = nil

      if root.main_product == base_result then
        root.main_product = connector_item
      end

      if root.result == base_result then
        root.result = connector_item
        root.result_count = nil
      elseif root.results then
        for i, result in ipairs(root.results) do
          if result.name == base_result then
            root.results[i].name = connector_item
            root.results[i].amount = 1
          end
        end
      end

      for _, ingredient in ipairs(root.ingredients) do
        if ingredient.amount then
          ingredient.amount = math.ceil(ingredient.amount / 2)
        elseif ingredient[2] then
          ingredient[2] = math.ceil(ingredient[2] / 2)
        end
      end
    end
  end

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