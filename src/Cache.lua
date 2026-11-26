-- Small least-recently-used cache for pure results (paths, part specs).
-- Keys are strings, usually Json.encode of every input that affects the result.
local Json=require(script.Parent.Json)
local C={}
C.__index=C
function C.new(max)
    return setmetatable({max=max or 16,map={},order={},hits=0,misses=0},C)
end
local function touch(self,key)
    local order=self.order
    local i=table.find(order,key)
    if i then table.remove(order,i) end
    order[#order+1]=key
end
function C:get(key)
    local v=self.map[key]
    if v~=nil then self.hits+=1; touch(self,key) else self.misses+=1 end
    return v
end
function C:put(key,v)
    self.map[key]=v; touch(self,key)
    while #self.order>self.max do
        local old=table.remove(self.order,1); self.map[old]=nil
    end
    return v
end
-- Returns the cached value for key, computing it with fn() on a miss.
-- Errors are not cached.
function C:memo(key,fn)
    local v=self:get(key)
    if v==nil then v=self:put(key,fn()) end
    return v
end
function C:clear() self.map={}; self.order={} end
-- Stable key for a list of Vector3 points plus extra settings.
function C.pointsKey(points,extra)
    local flat={}
    for i,p in ipairs(points) do flat[i]={p.X,p.Y,p.Z} end
    return Json.encode({p=flat,x=extra})
end
return C
