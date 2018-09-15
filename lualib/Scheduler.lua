local dheap = require "lualib.dheap"

local M = {}

local heap = dheap.new()

function M.on_tick(tick)
  local next_tick, task = heap:peek()
  while next_tick and next_tick <= tick do
    heap:pop()
    task(tick)
    next_tick, task = heap:peek()
  end
end

function M.schedule(tick, f)
  heap:insert(tick, f)
end

return M