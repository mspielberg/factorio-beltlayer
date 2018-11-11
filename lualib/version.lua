local M = {}

function M.parse(str)
  local major, minor, patch = string.match(str, "^(%d+)%.(%d+)%.(.+)$")
  return {tonumber(major), tonumber(minor), tonumber(patch)}
end
function M.lt(v1, v2)
  for i = 1, 3 do
    if v1[i] < v2[i] then
      return true
    elseif v1[i] > v2[i] then
      return false
    end
  end
  return false
end

return M