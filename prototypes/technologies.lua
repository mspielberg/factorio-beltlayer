local function find_underground_belt_result(recipe)
  for _, root in ipairs{recipe, recipe.normal, recipe.expensive} do
    if root then
      if root.results then
        for _, result in ipairs(root.results) do
          local name = result.name or result[1]
          if data.raw["underground-belt"][name] then
            return name
          end
        end
      elseif root.result then
        if data.raw["underground-belt"][root.result] then
          return root.result
        end
      end
    end
  end
end

for _, tech in pairs(data.raw.technology) do
  if tech.effects then
    for i, effect in ipairs(tech.effects) do
      if effect.type == "unlock-recipe" then
        local recipe = data.raw.recipe[effect.recipe]
        if false and recipe then
          if find_underground_belt_result(recipe) then
            table.insert(
              tech.effects,
              i + 1,
              {
                type = "unlock-recipe",
                recipe = effect.recipe:gsub("underground%-belt", "beltlayer-connector"),
              }
            )
          end
        end
      end
    end
  end
end