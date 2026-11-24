-- Repeat overlays: one shared spline, independent placement parameters.
local G=require(script.Parent.Geometry)
local L={MAX_LAYERS=12}
local function bounded(v,a,b) return type(v)=="number" and v==v and v>=a and v<=b end
function L.validate(layer)
    assert(bounded(layer.spacing,0.2,200),"Layer spacing must be 0.2–200")
    assert(bounded(layer.side,-1000,1000) and bounded(layer.height,-1000,1000),"Layer offsets outside limits")
    assert(bounded(layer.yaw,-360,360) and bounded(layer.roll,-360,360),"Layer rotation outside limits")
    assert(type(layer.enabled)=="boolean" and type(layer.collide)=="boolean","Invalid layer switches")
end
function L.frame(path,d,layer)
    local p,f,r,u=G.frame(path,d)
    p=p+r*layer.side+u*layer.height
    return CFrame.lookAt(p,p+f,u)*CFrame.Angles(0,math.rad(layer.yaw),0)*CFrame.Angles(0,0,math.rad(layer.roll))
end
function L.plan(path,layers,validAsset,budget)
    assert(#layers<=L.MAX_LAYERS,"Maximum 12 repeat layers")
    local plan,total={},0
    for i,layer in ipairs(layers) do
        L.validate(layer)
        if layer.enabled then
            local n=validAsset(layer.source)
            local ds=G.instances(path,layer.spacing,math.floor((budget-total)/n))
            total+=#ds*n
            assert(total<=budget,"Layer part budget exceeded")
            plan[#plan+1]={index=i,layer=layer,distances=ds}
        end
    end
    return plan,total
end
function L.build(path,layers,validAsset,cloneAsset,budget,preview)
    local plan,count=L.plan(path,layers,validAsset,budget)
    local folder=Instance.new("Folder"); folder.Name="RepeatLayers"
    local ok,err=pcall(function()
        for _,entry in ipairs(plan) do
            local l=entry.layer
            local group=Instance.new("Folder"); group.Name=string.format("%02d_%s",entry.index,l.source.Name); group.Parent=folder
            for _,d in ipairs(entry.distances) do
                local c=cloneAsset(l.source); c.Parent=group
                c:PivotTo(L.frame(path,d,l))
                local function configure(part)
                    part.Anchored=true; part.CanCollide=not preview and l.collide; part.CanTouch=false
                    if preview then part.CanQuery=false; part.Archivable=false end
                end
                if c:IsA("BasePart") then configure(c) end
                for _,obj in ipairs(c:GetDescendants()) do if obj:IsA("BasePart") then configure(obj) end end
            end
        end
    end)
    if not ok then folder:Destroy(); error(err,0) end
    return folder,count
end
function L.write(meta,layers)
    local folder=Instance.new("Folder"); folder.Name="RepeatLayers"; folder.Parent=meta
    for i,l in ipairs(layers) do
        local ref=Instance.new("ObjectValue"); ref.Name=string.format("L%02d",i); ref.Value=l.source
        for _,key in ipairs({"spacing","side","height","yaw","roll","enabled","collide"}) do ref:SetAttribute(key,l[key]) end
        ref.Parent=folder
    end
end
function L.read(meta)
    local folder=meta:FindFirstChild("RepeatLayers")
    if not folder then return {} end
    local children=folder:GetChildren()
    table.sort(children,function(a,b) return a.Name<b.Name end)
    assert(#children<=L.MAX_LAYERS,"Too many saved repeat layers")
    local out={}
    for _,ref in ipairs(children) do
        assert(ref:IsA("ObjectValue"),"Invalid saved repeat layer")
        local l={source=ref.Value}
        for _,key in ipairs({"spacing","side","height","yaw","roll","enabled","collide"}) do l[key]=ref:GetAttribute(key) end
        L.validate(l); out[#out+1]=l
    end
    return out
end
return L
