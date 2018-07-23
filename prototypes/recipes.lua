require "util"

local function find_underground_belt_result(recipe)
  for _, root in ipairs{recipe, recipe.normal, recipe.expensive} do
    if root then
      if root.result then
        if data.raw["underground-belt"][root.result] then
          return root.result
        end
      elseif root.results then
        for _, result in ipairs(root.results) do
          if data.raw["underground-belt"][result.name] then
            return root.result
          end
        end
      end
    end
  end
end

local function make_recipe(proto, base_result)
  local recipe = util.table.deepcopy(proto)
  recipe.name = recipe.name.."-beltlayer-connector"
  recipe.result_count = 1
  for _, root in ipairs{recipe, recipe.normal, recipe.expensive} do
    if root then
      if root.result then
        root.result = recipe.name
      elseif root.results then
        for i, result in ipairs(root.results) do
          if result.name == base_result then
            root.results[i].name = recipe.name
          end
        end
      end
    end
  end

  return recipe
end

for _, recipe in pairs(data.raw.recipe) do
  local underground_belt_result = find_underground_belt_result(recipe)
  if underground_belt_result then
    data:extend{make_recipe(recipe, underground_belt_result)}
  end
end