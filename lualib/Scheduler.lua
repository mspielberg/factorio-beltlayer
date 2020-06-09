local dheap = require "lualib.dheap"

local M = {}

local heap = dheap.new()

local scheduler_key_meta = {
  __lt = function(a, b)
    for i=1,#a do
      local va, vb = a[i], b[i]
      if not a[i] then return true end
      if not b[i] then return false end
      if a[i] < b[i] then
        return true
      elseif a[i] > b[i] then
        return false
      end
    end
    return false
  end,
}

function M.on_tick(tick)
  local next_key, task = heap:peek()
  while next_key and next_key[1] <= tick do
    heap:pop()
    task(tick)
    next_key, task = heap:peek()
  end
end

function M.schedule(key, f)
  heap:insert(setmetatable(key, scheduler_key_meta), f)
end

return M