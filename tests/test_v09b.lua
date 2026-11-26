-- v0.9b: draping onto ground and terrain fill/carve planning.
local t=require('harness').new()
local G=require('Geometry')
local T=require('Terrain')
local V=Vector3.new
local function hill(x,z) return math.max(0,10-math.abs(x)/2) end
local function line(a,b) local p=G.path({a,b},false); p.linear=true; return p end

t.check("drape: points move to ground plus offset; misses keep height",function()
    local out,hit=T.drape({V(0,50,0),V(10,50,0),V(999,7,0)},function(x) if x<100 then return hill(x,0) end end,0.5)
    assert(hit==2)
    t.close(out[1].Y,10.5); t.close(out[2].Y,5.5); t.close(out[3].Y,7)
end)
t.check("resample: follows a hill between two far points",function()
    local p=line(V(-30,0,0),V(30,0,0))
    local out,hit=T.resample(p,5,hill,0,128)
    assert(#out==13 and hit==13,"points "..#out)
    t.close(out[7].Y,10,1e-6,"hill top")
    t.close(out[1].X,-30); t.close(out[13].X,30)
    t.fails(function() T.resample(p,0.1,hill,0,128) end,"Too many points")
end)
t.check("plan: one fill and one carve block per segment, sized by width + shoulders",function()
    local p=line(V(0,0,0),V(0,0,-40))
    local plan=T.plan(p,{width=12,shoulder=2,depth=6,clear=10,step=4,offset=0})
    assert(#plan.fill==10 and #plan.carve==10)
    local f,c=plan.fill[1],plan.carve[1]
    t.close(f.size.X,16); t.close(f.size.Y,6); t.close(f.size.Z,6)
    -- Fill top is 0.5 below the path; carve bottom is at the path.
    t.close(f.cf.Position.Y+f.size.Y/2,-0.5); t.close(c.cf.Position.Y-c.size.Y/2,0)
end)
t.check("plan: blocks tilt with a sloped path",function()
    local p=line(V(0,0,0),V(0,10,-40))
    local plan=T.plan(p,{width=8,shoulder=0,depth=4,clear=0,step=4,offset=0})
    assert(#plan.carve==0)
    local look=plan.fill[1].cf.LookVector
    assert(look.Y>0.2,"block should follow the slope")
end)
t.check("plan: zero depth or clear skips that kind; bad input fails",function()
    local p=line(V(0,0,0),V(0,0,-8))
    local plan=T.plan(p,{width=8,shoulder=0,depth=0,clear=5,step=4,offset=0})
    assert(#plan.fill==0 and #plan.carve==2)
    t.fails(function() T.plan(p,{width=0,shoulder=0,depth=1,clear=1,step=4,offset=0}) end,"Invalid terrain settings")
end)
return t.finish()
