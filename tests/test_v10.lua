-- v0.10: deterministic scatter along paths, brush painting and erasing.
local t=require('harness').new()
local G=require('Geometry')
local S=require('Scatter')
local N=require('Network')
local V=Vector3.new
local function line(a,b) local p=G.path({a,b},false); p.linear=true; return p end
local function opts(patch)
    local o={band=20,gap=8,density=1,minDistance=4,scaleMin=0.8,scaleMax=1.2,seed=7}
    for k,v in pairs(patch or {}) do o[k]=v end
    return o
end

t.check("rng: same seed repeats, different seed differs, values in [0,1)",function()
    local a,b,c=S.rng(5),S.rng(5),S.rng(6)
    local same,diff=true,false
    for _=1,100 do
        local x,y,z=a(),b(),c()
        assert(x>=0 and x<1)
        if x~=y then same=false end
        if x~=z then diff=true end
    end
    assert(same and diff)
end)
t.check("along: count follows density and band area",function()
    local p=line(V(0,0,0),V(0,0,-100))
    local items=S.along(p,opts({minDistance=0}))
    -- 100 long x 2 sides x 12 wide = 2400 square studs at 1 per 100 -> 24.
    assert(#items==24,"count "..#items)
end)
t.check("along: everything stays in the band and outside the clear zone",function()
    local p=line(V(0,0,0),V(0,0,-100))
    for _,it in ipairs(S.along(p,opts())) do
        local _,_,gap=N.project(p,it.position)
        assert(gap>=8-1e-6 and gap<=20+1e-6,"gap "..gap)
        assert(it.scale>=0.8 and it.scale<=1.2 and it.yaw>=0 and it.yaw<360)
    end
end)
t.check("along: minimum distance holds, also against existing assets",function()
    local p=line(V(0,0,0),V(0,0,-100))
    local existing={V(-14,0,-50),V(14,0,-50)}
    local items=S.along(p,opts({density=5,minDistance=6}),existing)
    local all={table.unpack(existing)}
    for _,it in ipairs(items) do all[#all+1]=it.position end
    for i=1,#all do for j=i+1,#all do
        local dx,dz=all[i].X-all[j].X,all[i].Z-all[j].Z
        assert(dx*dx+dz*dz>=36-1e-6,"too close")
    end end
end)
t.check("along: same seed gives the same layout",function()
    local p=line(V(0,0,0),V(0,0,-50))
    local a,b=S.along(p,opts()),S.along(p,opts())
    assert(#a==#b)
    for i=1,#a do assert(a[i].position==b[i].position and a[i].yaw==b[i].yaw) end
end)
t.check("along: bad settings and huge counts are refused",function()
    local p=line(V(0,0,0),V(0,0,-50))
    t.fails(function() S.along(p,opts({gap=25})) end,"Clear zone must be smaller")
    t.fails(function() S.along(p,opts({scaleMin=2,scaleMax=1})) end,"Scale range")
    t.fails(function() S.along(line(V(0,0,0),V(0,0,-5000)),opts({band=400,gap=0,density=10})) end,"Too many scatter")
end)
t.check("brush: points land inside the circle and respect spacing",function()
    local items=S.brush(V(10,0,10),8,opts({density=5,minDistance=2}),{},3)
    assert(#items>=8,"count "..#items)
    for _,it in ipairs(items) do
        local dx,dz=it.position.X-10,it.position.Z-10
        assert(dx*dx+dz*dz<=64+1e-6)
    end
end)
t.check("erase: picks positions inside the radius only",function()
    local idx=S.erase({V(0,0,0),V(3,5,0),V(10,0,0)},V(0,0,0),4)
    assert(#idx==2 and idx[1]==1 and idx[2]==2)
end)
t.check("scatter: exact source choices respect total part budget",function()
    local items={{},{},{}}
    local pool={{count=2},{count=3}}
    local function count(a) return a.count end
    local picks,total=S.sources(items,pool,7,count,0)
    assert(#picks==3 and total==picks[1].count+picks[2].count+picks[3].count)
    t.fails(function() S.sources(items,pool,7,count,6499) end,"Scatter part budget exceeded")
end)
return t.finish()
