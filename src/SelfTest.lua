-- In-Studio math self-tests; no assets, uploads or Workspace edits.
local G=require(script.Parent.Geometry)
local E=require(script.Parent.Extrude)
local L=require(script.Parent.Layers)
local T={}
local function close(a,b,e) assert(math.abs(a-b)<(e or 1e-4),"Expected "..tostring(b)..", got "..tostring(a)) end
function T.run()
    local n=0
    local function test(fn) fn(); n+=1 end
    local V=Vector3.new
    test(function() local p=G.path({V(0,0,0),V(0,0,-20)},true); close(p.length,20); close((G.at(p,0)-V(0,0,0)).Magnitude,0); close((G.at(p,20)-V(0,0,-20)).Magnitude,0) end)
    test(function() local p=G.path({V(0,0,0),V(0,0,0),V(5,0,0)},false); close(p.length,5) end)
    test(function() assert(not pcall(G.path,{V(0,0,0),V(0,0,0)},true)) end)
    test(function() local p=G.path({V(0,0,0),V(0,0,-10)},true); local ds=G.instances(p,3,10); close(ds[1],0.5); close(ds[2]-ds[1],3); close(ds[#ds],9.5) end)
    test(function() local p=G.path({V(0,0,0),V(3,0,0),V(3,0,5)},false); p.linear=true; local ds=G.segments(p,4,10); assert(table.find(ds,3)) end)
    test(function() local p=G.path({V(0,0,0),V(0,10,0),V(3,20,0),V(8,30,0)},true); local last
        for i=0,100 do local _,f,r,u=G.frame(p,p.length*i/100); close(f.Magnitude,1); close(r.Magnitude,1); close(u.Magnitude,1); close(f:Dot(r),0); close(f:Dot(u),0); close(r:Dot(u),0); if last then assert(last:Dot(r)>0,"Frame flip") end; last=r end
    end)
    test(function() local p=G.path({V(0,0,0),V(0,10,0)},true); local _,f,r,u=G.frame(p,5); close(f.Y,1); close(r:Dot(u),0) end)
    test(function() local p=G.path({V(0,0,0),V(100,0,0)},false); assert(not pcall(G.instances,p,1,10)); assert(not pcall(G.segments,p,1,10)) end)
    test(function() local p=G.path({V(0,0,0),V(0,0,-20)},true); local ds=G.adaptive(p,5,0.1,0.01,100); assert(#ds==5); close(ds[#ds],20) end)
    test(function() local p=G.path({V(0,0,0),V(10,0,0),V(10,0,10)},true); local a=G.adaptive(p,10,0.15,0.03,1000); assert(#a>math.ceil(p.length/10)+1); close(a[1],0); close(a[#a],p.length) end)
    test(function() local p=G.path({V(0,0,0),V(0,0,-20)},false); local o={profile="rectangle",width=4,height=2,sides=16,step=5,angle=8,tolerance=0.05}; local plan=E.plan(p,o); assert(plan.vertices==20 and plan.triangles==36); close(plan.perimeter[5],12) end)
    test(function() local q,closed=E.profile({profile="arch",width=4,height=2,sides=8}); assert(#q==9 and not closed) end)
    test(function() local q,closed=E.profile({profile="0,0;0,2;2,2;2,0",width=4,height=2,sides=8}); assert(#q==4 and closed); assert(not pcall(E.profile,{profile="0,0;2,2;0,2;2,0",width=4,height=2,sides=8})) end)
    test(function()
        local p=G.path({V(0,0,0),V(0,0,-10)},false)
        local l={spacing=5,side=2,height=3,yaw=0,roll=0,enabled=true,collide=true,source={}}
        local cf=L.frame(p,5,l); close((cf.Position-V(2,3,-5)).Magnitude,0)
        local plan,count=L.plan(p,{l},function() return 2 end,10); assert(#plan==1 and count==6)
        assert(not pcall(L.plan,p,{l},function() return 2 end,5))
        l.enabled=false; local _,empty=L.plan(p,{l},function() error("disabled") end,10); assert(empty==0)
    end)
    test(function() assert(not pcall(L.validate,{spacing=0,side=0,height=0,yaw=0,roll=0,enabled=true,collide=true})) end)
    return n
end
return T
