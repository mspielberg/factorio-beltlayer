for _, f in pairs(game.forces) do
  f.reset_technologies()
  for _, t in pairs(f.technologies) do
    for _, effect in ipairs(t.effects) do
      if effect.type == "unlock-recipe" and effect.recipe:find("%-beltlayer%-connector") then
        if t.researched then
          f.recipes[effect.recipe].enabled = true
        end
      end
    end
  end
end
