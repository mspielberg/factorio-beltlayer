local util = require "util"

for _, tech in pairs(data.raw.technology) do
  if tech.effects then
    for i, effect in ipairs(tech.effects) do
      if effect.type == "unlock-recipe" then
        local recipe = data.raw.recipe[effect.recipe]
        if recipe then
          local connector_recipe_name = util.connector_name(effect.recipe)
          if util.find_underground_belt_result(recipe) then
            table.insert(
              tech.effects,
              i + 1,
              {
                type = "unlock-recipe",
                recipe = connector_recipe_name,
              }
            )
          end
        end
      end
    end
  end
end