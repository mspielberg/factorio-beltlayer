local M = {}

-- a minimum d-ary heap
local dheap = {}

-- creates a new d-ary heap, or a 4-heap if d is not specified
function M.new(d)
  return M.restore{d = d or 4}
end

function M.restore(self)
  return setmetatable(self, { __index = dheap })
end

-- conditionally locally restores the heap condition by swapping the node at n
-- with its parent
local function heapup1(self, n)
  if n == 0 then
    return false
  end
  local i = math.floor((n - 1) / self.d)
  if self[i][1] > self[n][1] then
    self[i], self[n] = self[n], self[i]
    return true, i
  end
  return false
end

-- moves the node at n up the tree until the heap condition is restored
local function heapup(self, n)
  local swapped
  repeat
    swapped, n = heapup1(self, n)
  until not swapped
end

-- conditionally locally restores the heap condition by swapping the node at n
-- with its lowest priority child
local function heapdown1(self, n)
  local first_child = self.d*n
  local min_index, min_value
  for i=first_child+1,first_child+self.d do
    local v = self[i]
    if v and (not min_value or v[1] < min_value) then
      min_index = i
      min_value = v[1]
    end
  end
  if min_index and min_value < self[n][1] then
    self[min_index], self[n] = self[n], self[min_index]
    return true, min_index
  end
  return false
end

-- moves the node at n down the tree until the heap condition is restored
local function heapdown(self, n)
  local swapped
  repeat
    swapped, n = heapdown1(self, n)
  until not swapped
end

-- inserts v into the heap with priority prio
function dheap:insert(prio, v)
  local n
  if not self[0] then
    self[0] = {prio, v}
    return
  end

  n = #self + 1
  self[n] = {prio, v}
  heapup(self, n)
end

local function heapify(self)
  for i=#self,0,-1 do
    heapdown(self, i)
  end
end

local function delete_at_index(self, n)
  local x = self[n]
  if not x then return end
  local l = #self
  self[n] = self[l]
  self[l] = nil
  heapify(self)
  return x[1]
end

-- returns the minimum priority and the associated value
function dheap:peek()
  local x = self[0]
  if not x then return end
  return x[1], x[2]
end

-- deletes the node with minimum priority and returns its priority and value
function dheap:pop()
  local x = self[0]
  if not x then return end
  local l = #self
  self[0] = self[l]
  self[l] = nil

  heapdown(self, 0)

  return x[1], x[2]
end

-- deletes the node with value v and returns its priority
function dheap:delete(v)
  if not self[0] then return end
  for i=0,#self do
    if self[i][2] == v then
      return delete_at_index(self, i)
    end
  end
end

-- returns a string representation of this heap
function dheap:tostring(n, d)
  if not n then
    n = 0
    d = 0
  end
  local x = self[n]
  if not x then return "" end

  local indent = {}
  for i=1,d do indent[i] = '  ' end
  local lines = {
    table.concat{
      table.concat(indent),
      '{', x[1], ',', tostring(x[2]), '}'
    }
  }

  local first_child = self.d*n
  for i=first_child+1,first_child+self.d do
    if self[i] then
      local from_child = self:tostring(i, d+1)
      lines[#lines+1] = from_child
    end
  end
  return table.concat(lines, "\n")
end

return M