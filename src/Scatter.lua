-- Scatter: random but repeatable placement of assets in a band along a path,
-- and brush painting/erasing in a circle. Pure planning; the plugin places clones.
local G=require(script.Parent.Geometry)
local S={MAX_COUNT=2000}

-- Deterministic generator (same seed -> same layout in Studio and tests).
function S.rng(seed)
    local state=math.floor(math.abs(seed or 1))%2147483646+1
    return function()
        state=(state*48271)%2147483647
        return (state-1)/2147483646
    end
end

-- Spatial hash on XZ for minimum-distance checks.
local function grid(cell)
    local g={cell=math.max(cell,0.01),cells={}}
    local function key(x,z) return math.floor(x/g.cell)..","..math.floor(z/g.cell) end
    function g.add(p) local k=key(p.X,p.Z); g.cells[k]=g.cells[k] or {}; table.insert(g.cells[k],p) end
    function g.near(p,r)
        local cx,cz=math.floor(p.X/g.cell),math.floor(p.Z/g.cell)
        for dx=-1,1 do for dz=-1,1 do
            for _,q in ipairs(g.cells[(cx+dx)..","..(cz+dz)] or {}) do
                local ex,ez=q.X-p.X,q.Z-p.Z
                if ex*ex+ez*ez<r*r then return true end
            end
        end end
        return false
    end
    return g
end
S.grid=grid

function S.validate(o)
    assert(o.band>0 and o.band<=500,"Scatter band must be 0–500 studs")
    assert(o.gap>=0 and o.gap<o.band,"Clear zone must be smaller than the band")
    assert(o.density>0 and o.density<=100,"Density must be 0–100 per 100 square studs")
    assert(o.minDistance>=0 and o.minDistance<=100,"Minimum distance must be 0–100")
    assert(o.scaleMin>0 and o.scaleMax>=o.scaleMin and o.scaleMax<=20,"Scale range must be 0–20 with min ≤ max")
end

local function variation(rng,o)
    return o.scaleMin+(o.scaleMax-o.scaleMin)*rng(),rng()*360
end

-- Scatter along a path in a band on both sides, keeping `gap` studs clear of the center line.
-- existing: positions already placed (kept apart by minDistance).
-- Returns a list of {position, scale, yaw}.
function S.along(path,o,existing)
    S.validate(o)
    local rng=S.rng(o.seed)
    local area=path.length*2*(o.band-o.gap)
    local target=math.floor(area*o.density/100+0.5)
    assert(target<=S.MAX_COUNT,"Too many scatter instances: lower the density or band")
    local g=grid(math.max(o.minDistance,1))
    for _,p in ipairs(existing or {}) do g.add(p) end
    local out={}
    local tries=0
    while #out<target and tries<target*20 do
        tries+=1
        local d=rng()*path.length
        local side=rng()<0.5 and -1 or 1
        local off=o.gap+(o.band-o.gap)*rng()
        local p,_,r=G.frame(path,d)
        local q=p+r*(off*side)
        if o.minDistance<=0 or not g.near(q,o.minDistance) then
            g.add(q)
            local scale,yaw=variation(rng,o)
            out[#out+1]={position=q,scale=scale,yaw=yaw}
        end
    end
    return out
end

-- Brush: about density-per-100-square-studs instances inside a circle.
function S.brush(center,radius,o,existing,seed)
    assert(radius>0 and radius<=200,"Brush radius must be 0–200 studs")
    local rng=S.rng(seed)
    local target=math.max(1,math.floor(math.pi*radius*radius*o.density/100+0.5))
    assert(target<=S.MAX_COUNT,"Too many scatter instances: lower the density or band")
    local g=grid(math.max(o.minDistance,1))
    for _,p in ipairs(existing or {}) do g.add(p) end
    local out={}
    local tries=0
    while #out<target and tries<target*20 do
        tries+=1
        -- Uniform point in a disc.
        local a=rng()*2*math.pi
        local r=radius*math.sqrt(rng())
        local q=center+Vector3.new(math.cos(a)*r,0,math.sin(a)*r)
        if o.minDistance<=0 or not g.near(q,o.minDistance) then
            g.add(q)
            local scale,yaw=variation(rng,o)
            out[#out+1]={position=q,scale=scale,yaw=yaw}
        end
    end
    return out
end

-- Indexes of positions within radius of center (XZ), for the eraser.
function S.erase(positions,center,radius)
    local out={}
    for i,p in ipairs(positions) do
        local dx,dz=p.X-center.X,p.Z-center.Z
        if dx*dx+dz*dz<=radius*radius then out[#out+1]=i end
    end
    return out
end

-- Picks one of n assets.
function S.pick(rng,n) return math.min(n,math.floor(rng()*n)+1) end
return S
