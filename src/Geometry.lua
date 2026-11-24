-- Pure path math; uses only Roblox Vector3 arithmetic.
local G = {}
local EPS = 1e-5
local function mix(a,b,t) return a + (b-a)*t end
local function blend(a,b,ta,tb,t) return mix(a,b,(t-ta)/(tb-ta)) end
local function span(a,b) return math.max((b-a).Magnitude^0.5, 0.01) end
-- Centripetal Catmull-Rom; reflected endpoints preserve endpoint tangents.
function G.curve(p0,p1,p2,p3,u)
    local t0=0
    local t1=span(p0,p1)
    local t2=t1+span(p1,p2)
    local t3=t2+span(p2,p3)
    local t=t1+(t2-t1)*u
    local a1=blend(p0,p1,t0,t1,t)
    local a2=blend(p1,p2,t1,t2,t)
    local a3=blend(p2,p3,t2,t3,t)
    local b1=blend(a1,a2,t0,t2,t)
    local b2=blend(a2,a3,t1,t3,t)
    return blend(b1,b2,t1,t2,t)
end
function G.path(points, smooth)
    local clean={}
    for _,p in ipairs(points) do
        if #clean==0 or (p-clean[#clean]).Magnitude>0.001 then clean[#clean+1]=p end
    end
    assert(#clean>=2,"Add at least two distinct control points")
    assert(#clean<=128,"Maximum 128 control points")
    local out={clean[1]}
    local distances={0}
    local total=0
    for i=1,#clean-1 do
        local a,b=clean[i],clean[i+1]
        local p0=clean[i-1] or (a+(a-b))
        local p3=clean[i+2] or (b+(b-a))
        local n=smooth and math.min(160,math.max(16,math.ceil((b-a).Magnitude/1.0))) or 1
        for j=1,n do
            local q= j==n and b or (smooth and G.curve(p0,a,b,p3,j/n) or mix(a,b,j/n))
            local d=(q-out[#out]).Magnitude
            if d>EPS then
                total=total+d
                out[#out+1]=q
                distances[#distances+1]=total
            end
        end
    end
    assert(total>EPS,"Path is too short")
    return {positions=out, distances=distances, length=total}
end
function G.at(path,d)
    d=math.max(0,math.min(path.length,d))
    local ds,ps=path.distances,path.positions
    local lo,hi=1,#ds
    while hi-lo>1 do
        local m=math.floor((lo+hi)/2)
        if ds[m]<=d then lo=m else hi=m end
    end
    return mix(ps[lo],ps[hi],(d-ds[lo])/(ds[hi]-ds[lo]))
end
local function tangent(path,d)
    local delta=math.min(0.25,path.length/4)
    local t=G.at(path,d+delta)-G.at(path,d-delta)
    if t.Magnitude<EPS then t=G.at(path,d+delta)-G.at(path,d) end
    if t.Magnitude<EPS then t=G.at(path,d)-G.at(path,d-delta) end
    return t.Magnitude<EPS and Vector3.new(0,0,-1) or t.Unit
end
local function initialRight(f)
    local up=math.abs(f.Y)>0.995 and Vector3.new(0,0,1) or Vector3.yAxis
    return f:Cross(up).Unit
end
-- Minimal rotation transporting the previous frame to the next tangent.
local function transport(r,a,b)
    local cross=a:Cross(b)
    local sin=cross.Magnitude
    local cos=math.clamp(a:Dot(b),-1,1)
    if sin>EPS then
        local axis=cross/sin
        r=r*cos+axis:Cross(r)*sin+axis*(axis:Dot(r)*(1-cos))
    end
    r=r-b*r:Dot(b)
    return r.Magnitude>EPS and r.Unit or initialRight(b)
end
local function frames(path)
    if path.frames then return path.frames end
    local cache={}
    for i,d in ipairs(path.distances) do
        local f=tangent(path,d)
        local r=i==1 and initialRight(f) or transport(cache[i-1].r,cache[i-1].f,f)
        cache[i]={f=f,r=r}
    end
    path.frames=cache
    return cache
end
function G.frame(path,d)
    d=math.clamp(d,0,path.length)
    local cache=frames(path)
    local lo,hi=1,#cache
    while hi-lo>1 do
        local m=math.floor((lo+hi)/2)
        if path.distances[m]<=d then lo=m else hi=m end
    end
    local f=tangent(path,d)
    local r=transport(cache[lo].r,cache[lo].f,f)
    return G.at(path,d),f,r,r:Cross(f).Unit
end
-- Continuous geometry includes both endpoints and distributes segment length evenly.
function G.segments(path,step,limit)
    assert(step>0,"Segment length must be positive")
    local n=math.max(1,math.ceil(path.length/step))
    assert(n<=limit,"Too many segments: increase segment length or shorten path")
    local ds={}
    for i=0,n do ds[#ds+1]=path.length*i/n end
    -- Preserve polyline corners even when a uniform sample would skip over them.
    -- The caller marks linear paths; smooth samples are already sufficiently dense.
    if path.linear then
        for i=2,#path.distances-1 do ds[#ds+1]=path.distances[i] end
        table.sort(ds)
        local unique={ds[1]}
        for i=2,#ds do if ds[i]-unique[#unique]>EPS then unique[#unique+1]=ds[i] end end
        ds=unique
    end
    assert(#ds-1<=limit,"Too many segments")
    return ds
end
-- Repeated objects use exact spacing; centered placement avoids clipped endpoints.
function G.instances(path,spacing,limit)
    assert(spacing>0,"Spacing must be positive")
    local n=math.max(1,math.floor(path.length/spacing)+1)
    assert(n<=limit,"Too many assets: increase spacing or shorten path")
    local start=(path.length-(n-1)*spacing)/2
    local ds={}
    for i=0,n-1 do ds[#ds+1]=start+i*spacing end
    return ds
end
return G
