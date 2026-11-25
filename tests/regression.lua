-- Extra checks run only outside Studio. Each runs on freshly loaded modules.
local G=require('Geometry')
local E=require('Extrude')
local V=Vector3.new
local results={}
local function check(name,fn)
    local ok,err=pcall(fn)
    results[#results+1]=(ok and "ok   " or "FAIL ")..name..(ok and "" or (" -> "..tostring(err)))
end
-- Bug: G.adaptive is defined inside G.frame, so it is nil until G.frame runs once.
check("G.adaptive exists right after require",function() assert(type(G.adaptive)=="function","G.adaptive is nil") end)
check("E.plan works before any G.frame call",function()
    local p=G.path({V(0,0,0),V(0,0,-20)},false)
    E.plan(p,{profile="rectangle",width=4,height=2,sides=16,step=5,angle=8,tolerance=0.05})
end)
check("vertical path frame is orthonormal",function()
    local p=G.path({V(0,0,0),V(0,20,0),V(0,40,0)},true)
    for i=0,20 do local _,f,r,u=G.frame(p,p.length*i/20)
        assert(math.abs(f:Dot(r))<1e-4 and math.abs(r:Dot(u))<1e-4 and math.abs(r.Magnitude-1)<1e-4) end
end)
check("circle profile plan counts",function()
    local p=G.path({V(0,0,0),V(0,0,-20)},false)
    local plan=E.plan(p,{profile="circle",width=4,height=4,sides=12,step=5,angle=8,tolerance=0.05})
    assert(plan.vertices==5*12 and plan.triangles==4*12*2+2*10,"got "..plan.vertices.."/"..plan.triangles)
end)
local failed=0
for _,line in ipairs(results) do if line:sub(1,4)=="FAIL" then failed=failed+1 end end
local msg=table.concat(results,"\n    ")
if failed>0 then error(failed.." of "..#results.." failed\n    "..msg,0) end
return #results.." passed\n    "..msg
