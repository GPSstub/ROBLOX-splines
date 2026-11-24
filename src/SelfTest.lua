-- In-Studio math self-tests; no assets, uploads or Workspace edits.
local G=require(script.Parent.Geometry)
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
    return n
end
return T
