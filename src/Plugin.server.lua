-- PathForge v0.2 | Studio-only procedural path editor. No HTTP or runtime scripts.
if not plugin then return end
local G=require(script.Parent.Geometry)
local Materials=require(script.Parent.Materials)
local Deform=require(script.Parent.Deform)
local Selection=game:GetService("Selection")
local History=game:GetService("ChangeHistoryService")
local RunService=game:GetService("RunService")
local Storage=game:GetService("ServerStorage")
local Http=game:GetService("HttpService")
local toolbar=plugin:CreateToolbar("PathForge")
local tool=toolbar:CreateButton("PathForge", "Procedural path and asset editor", "", "PathForge")
tool.ClickableWhenViewportHidden=true
local info=DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right,false,false,340,700,290,360)
local widget=plugin:CreateDockWidgetPluginGuiAsync("PathForge_Editor_v1",info)
widget.Title="PathForge | Level Toolkit"
local mouse=plugin:GetMouse()
local presets={"Rail","Road","Wall","Fence","Pipe","Custom","Deform"}
local defaults={Rail={width=3.2,height=0.2,spacing=1.8,step=1},Road={width=12,height=0.35,spacing=8,step=2},Wall={width=0.8,height=8,spacing=5,step=2},Fence={width=0.3,height=4,spacing=5,step=2},Pipe={width=1.4,height=1.5,spacing=8,step=1},Custom={width=1,height=0,spacing=5,step=2},Deform={width=1,height=0,spacing=5,step=2}}
local fields={}
local styles={}
local materialSlots={"RailFoot","RailHead","Sleeper","RoadSurface","EdgeLine","CenterMark","Wall","FenceRail","FencePost","Pipe","Joint"}
local materialSlot=1
local busy=false
local syncMaterials=function() end
local points={}
local preset="Rail"
local smooth=true
local collide=true
local selected=0
local root=nil
local asset=nil
local preview=nil
local mode=nil
local dragging=false
local lastMove=0
local refreshPreview
local refreshLabel
local MAX_PARTS=6500
local MAX_POINTS=128
local C={bg=Color3.fromRGB(24,28,34),panel=Color3.fromRGB(38,44,52),text=Color3.fromRGB(232,237,242),muted=Color3.fromRGB(157,170,185),accent=Color3.fromRGB(36,126,146),error=Color3.fromRGB(255,147,139)}
local function make(class,parent,props)
    local o=Instance.new(class)
    for k,v in pairs(props or {}) do o[k]=v end
    o.Parent=parent
    return o
end
local scroll=make("ScrollingFrame",widget,{Size=UDim2.fromScale(1,1),BackgroundColor3=C.bg,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=5})
make("UIPadding",scroll,{PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,12),PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)})
make("UIListLayout",scroll,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
local order=0
local function item(class,props)
    order=order+1
    props.LayoutOrder=order
    return make(class,scroll,props)
end
local function label(text,h,color)
    return item("TextLabel",{Size=UDim2.new(1,0,0,h or 22),BackgroundTransparency=1,Text=text,TextColor3=color or C.text,Font=Enum.Font.Gotham,TextSize=13,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left})
end
local function button(text,fn,accent)
    local b=item("TextButton",{Size=UDim2.new(1,0,0,32),BackgroundColor3=accent and C.accent or C.panel,BorderSizePixel=0,Text=text,TextColor3=C.text,Font=Enum.Font.GothamMedium,TextSize=13,AutoButtonColor=true})
    make("UICorner",b,{CornerRadius=UDim.new(0,5)})
    b.Activated:Connect(function() if not busy then fn() end end)
    return b
end
local function input(key,title,value)
    local row=item("Frame",{Size=UDim2.new(1,0,0,30),BackgroundTransparency=1})
    make("TextLabel",row,{Size=UDim2.fromScale(0.59,1),BackgroundTransparency=1,Text=title,TextColor3=C.muted,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left})
    local box=make("TextBox",row,{Position=UDim2.fromScale(0.6,0),Size=UDim2.fromScale(0.4,1),BackgroundColor3=C.panel,BorderSizePixel=0,Text=tostring(value),TextColor3=C.text,Font=Enum.Font.Gotham,TextSize=13,ClearTextOnFocus=false})
    make("UICorner",box,{CornerRadius=UDim.new(0,4)})
    fields[key]=box
    return box
end
local title=label("PATHFORGE   /   0.2",28)
title.Font=Enum.Font.GothamBold; title.TextSize=19
label("01   PATH / CONTROL POINTS",22,C.muted)
local status=label("Create a path or load a saved PathForge model.",46)
local function say(t,err) status.Text=t; status.TextColor3=err and C.error or C.text end
local function guarded(fn)
    return function(...)
        if busy then return end
        local ok,err=pcall(fn,...)
        if not ok then say(tostring(err),true); warn("[PathForge]",err) end
    end
end
local function editAllowed() assert(not RunService:IsRunning(),"Stop play testing before editing") end
local function number(key,lo,hi)
    local v=tonumber(fields[key].Text)
    assert(v and v==v and v>=lo and v<=hi,key.." must be between "..lo.." and "..hi)
    return v
end
local function options()
    return {materialStyles=Http:JSONEncode(styles),preset=preset,smooth=smooth,collide=collide,width=number("width",0.05,100),height=number("height",-50,100),spacing=number("spacing",0.2,200),step=number("step",0.15,100),offset=number("offset",-100,100),yaw=number("yaw",-360,360),roll=number("roll",-360,360)}
end
local function pathFor()
    local path=G.path(points,smooth); path.linear=not smooth; return path
end
local function clearPreview()
    if preview then preview:Destroy(); preview=nil end
end
local function stopMode()
    dragging=false; mode=nil
    if plugin:IsActivated() then plugin:Deactivate() end
end
local function startMode(m)
    editAllowed(); mode=m; plugin:Activate(true); say(m=="add" and "Click surfaces to add points. Switch to Move to drag nodes." or (m=="insert" and "Click a surface to insert a node after the selected node." or "Drag a blue node. Use coordinate fields for exact XYZ."))
end
local function simplePart(parent,name,cf,size,material,color,canCollide)
    local p=Instance.new("Part")
    p.Name=name; p.Size=Vector3.new(math.max(size.X,0.05),math.max(size.Y,0.05),math.max(size.Z,0.05)); p.CFrame=cf
    p.Anchored=true; p.CanCollide=canCollide; p.CanTouch=false; p.Material=material; p.Color=color
    p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth; p.Parent=parent
    return p
end
local function axisCF(a,b,up)
    local v=b-a
    if v.Magnitude<1e-5 then return nil,0 end
    if math.abs(v.Unit:Dot(up))>0.995 then up=Vector3.new(0,0,1); if math.abs(v.Unit:Dot(up))>0.995 then up=Vector3.new(1,0,0) end end
    return CFrame.lookAt((a+b)/2,b,up),v.Magnitude
end
refreshPreview=function()
    clearPreview()
    if not widget.Enabled or RunService:IsRunning() then return end
    preview=Instance.new("Folder"); preview.Name="_PathForgeDraft"; preview.Archivable=false; preview.Parent=workspace
    if #points>=2 then
        local ok,path=pcall(pathFor)
        if ok then
            local n=math.min(160,math.max(1,math.ceil(path.length/2)))
            for i=1,n do
                local a,b=G.at(path,path.length*(i-1)/n),G.at(path,path.length*i/n)
                local cf,len=axisCF(a,b,Vector3.new(0,1,0))
                if cf then local p=simplePart(preview,"Guide",cf,Vector3.new(0.10,0.10,len+0.04),Enum.Material.Neon,Color3.fromRGB(66,187,216),false); p.CanQuery=false; p.CastShadow=false end
            end
        end
    end
    for i,p in ipairs(points) do
        local node=simplePart(preview,"Node_"..i,CFrame.new(p),Vector3.new(0.65,0.65,0.65),Enum.Material.Neon,i==selected and Color3.fromRGB(255,176,79) or Color3.fromRGB(70,160,255),false)
        node.Shape=Enum.PartType.Ball; node.CastShadow=false; node:SetAttribute("NodeIndex",i)
    end
end
local pointLabel=label("0 points",22)
button("New path / clear draft",guarded(function() editAllowed(); stopMode(); root=nil; points={}; selected=0; styles={}; syncMaterials(); refreshLabel(); refreshPreview(); say("New draft. Existing generated models are unchanged.") end))
button("Add points in viewport",guarded(function() startMode("add") end),true)
button("Move nodes by dragging",guarded(function() startMode("move") end))
button("Insert node after selected",guarded(function() assert(selected>0,"Select a node first"); startMode("insert") end))
button("Stop viewport editing",function() stopMode(); say("Viewport released; draft kept.") end)
button("Previous / select node",function() if #points>0 then selected=(selected-2)%#points+1; refreshLabel(); refreshPreview() end end)
button("Next / select node",function() if #points>0 then selected=selected%#points+1; refreshLabel(); refreshPreview() end end)
input("x","Selected X",0); input("y","Selected Y",0); input("z","Selected Z",0)
input("grid","Placement grid (0 = off)",0)
input("plane","Empty-space plane Y",0)
refreshLabel=function()
    pointLabel.Text=string.format("%d points   |   Node %d   |   %s",#points,selected,root and "Editing saved path" or "New path")
    local p=points[selected]
    if p then for k,v in pairs({x=p.X,y=p.Y,z=p.Z}) do fields[k].Text=string.format("%.3f",v) end end
end
button("Apply selected XYZ",guarded(function() editAllowed(); assert(points[selected],"Select a node first"); points[selected]=Vector3.new(number("x",-100000,100000),number("y",-100000,100000),number("z",-100000,100000)); refreshPreview(); refreshLabel() end))
button("Delete selected node",guarded(function() editAllowed(); if points[selected] then table.remove(points,selected); selected=math.min(selected,#points); refreshLabel(); refreshPreview() end end))
local function hitPosition(planeY)
    local ray=mouse.UnitRay
    local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Exclude
    local exclude={}; if preview then exclude[#exclude+1]=preview end; if root and root.Parent then exclude[#exclude+1]=root end
    rp.FilterDescendantsInstances=exclude; rp.IgnoreWater=false
    local result=workspace:Raycast(ray.Origin,ray.Direction*2048,rp)
    local p=result and result.Position or nil
    if not p then
        if math.abs(ray.Direction.Y)<0.0001 then return nil end
        local t=(planeY-ray.Origin.Y)/ray.Direction.Y
        if t<0 or t>2048 then return nil end
        p=ray.Origin+ray.Direction*t
    end
    local grid=number("grid",0,100)
    if grid>0 then p=Vector3.new(math.floor(p.X/grid+0.5)*grid,math.floor(p.Y/grid+0.5)*grid,math.floor(p.Z/grid+0.5)*grid) end
    return p
end
local function movePoint()
    local old=points[selected]; if not old then return end
    local p=hitPosition(old.Y)
    if p then points[selected]=p; refreshLabel(); refreshPreview() end
end
mouse.Button1Down:Connect(guarded(function()
    if not mode or not widget.Enabled or RunService:IsRunning() then return end
    local target=mouse.Target
    if target and preview and target.Parent==preview and target:GetAttribute("NodeIndex") then
        selected=target:GetAttribute("NodeIndex"); dragging=mode=="move"; refreshLabel(); refreshPreview(); return
    end
    if mode=="add" or mode=="insert" then
        assert(#points<MAX_POINTS,"Maximum 128 points")
        local p=hitPosition(number("plane",-100000,100000))
        if p then
            if mode=="insert" and selected>0 then selected=selected+1; table.insert(points,selected,p) else points[#points+1]=p; selected=#points end
            refreshLabel(); refreshPreview()
        end
    end
end))
mouse.Move:Connect(guarded(function() if dragging and os.clock()-lastMove>0.05 then lastMove=os.clock(); movePoint() end end))
mouse.Button1Up:Connect(guarded(function() if dragging then dragging=false; movePoint() end end))
plugin.Deactivation:Connect(function() mode=nil; dragging=false end)
label("02   GENERATOR / PARAMETERS",22,C.muted)
local presetButton,smoothButton,collisionButton,assetLabel
local function syncButtons()
    presetButton.Text="Preset: "..preset.."   >"
    smoothButton.Text=smooth and "Curve: Smooth spline" or "Curve: Straight segments"
    collisionButton.Text=collide and "Collision: ON" or "Collision: OFF"
    assetLabel.Text=asset and ("Asset: "..asset.Name) or "Asset: none (Custom / Deform)"
end
local function applyDefaults()
    for k,v in pairs(defaults[preset]) do fields[k].Text=tostring(v) end
end
presetButton=button("Preset: Rail",function()
    local idx=table.find(presets,preset) or 1; preset=presets[idx%#presets+1]; applyDefaults(); syncButtons()
end,true)
smoothButton=button("Curve: Smooth spline",function() smooth=not smooth; syncButtons(); refreshPreview() end)
collisionButton=button("Collision: ON",function() collide=not collide; syncButtons() end)
input("width","Width / rail gauge / diameter",3.2)
input("height","Height / base elevation",0.2)
input("spacing","Asset / sleeper / post spacing",1.8)
input("step","Segment size (studs)",1)
input("offset","Vertical offset (studs)",0)
input("yaw","Custom yaw (degrees)",0)
input("roll","Custom roll (degrees)",0)
assetLabel=label("Asset: none (Custom preset only)",30,C.muted)
local function validAsset(a)
    assert(a and a.Parent and (a:IsA("Model") or a:IsA("BasePart")),"Select a Model or BasePart")
    assert(a.Archivable,"Asset must be Archivable")
    local count=a:IsA("BasePart") and 1 or 0
    for _,d in ipairs(a:GetDescendants()) do if d:IsA("BasePart") then count=count+1 end end
    assert(count>0,"Asset contains no BaseParts")
    return count
end
button("Use selected Model as custom asset",guarded(function()
    editAllowed(); local a=Selection:Get()[1]; validAsset(a)
    assert(not preview or not a:IsDescendantOf(preview),"Do not use a preview node")
    asset=a; preset="Custom"; applyDefaults(); syncButtons(); say("Asset selected. A reusable snapshot is stored when generated.")
end))
label("02B  MATERIAL SLOTS",22,C.muted)
local slotButton,styleLabel
syncMaterials=function()
    local name=materialSlots[materialSlot]
    if slotButton then slotButton.Text="Material slot: "..name end
    if styleLabel then
        local style=styles[name]
        styleLabel.Text=style and (style.material.." / "..(style.variant~="" and style.variant or "default").." / "..#style.textures.." textures") or "Preset default (no override)"
    end
end
slotButton=button("Material slot: RailFoot",function()
    materialSlot=materialSlot%#materialSlots+1; syncMaterials()
end)
styleLabel=label("Preset default (no override)",34,C.muted)
button("Capture material from selected part",guarded(function()
    editAllowed()
    local s=Selection:Get()[1]
    assert(not preview or not s or not s:IsDescendantOf(preview),"Select a real source part")
    styles[materialSlots[materialSlot]]=Materials.capture(s)
    syncMaterials(); say("Material slot captured. Generate to apply.")
end),true)
button("Reset material slot",function() styles[materialSlots[materialSlot]]=nil; syncMaterials() end)
button("Reset all material slots",function() styles={}; syncMaterials() end)
button("Use selected MeshPart / Deform",guarded(function()
    editAllowed()
    local a=Selection:Get()[1]; validAsset(a)
    assert(a:IsA("MeshPart"),"Select a single MeshPart")
    asset=a; preset="Deform"; applyDefaults(); syncButtons()
    say("Deform uses the full path length, local -Z forward. Dense mesh required.")
end))
local function cloneAsset(a)
    local c=a:Clone(); assert(c,"Cannot clone asset")
    for _,d in ipairs(c:GetDescendants()) do
        if d:IsA("LuaSourceContainer") or d:IsA("JointInstance") or d:IsA("Constraint") or d:IsA("WeldConstraint") or d:IsA("ProximityPrompt") or d:IsA("ClickDetector") then d:Destroy() end
    end
    return c
end
local steel=Color3.fromRGB(103,110,119)
local timber=Color3.fromRGB(91,67,46)
local asphalt=Color3.fromRGB(54,58,63)
local concrete=Color3.fromRGB(129,130,124)
local function build(path,o)
    local output=Instance.new("Folder"); output.Name="Generated"
    local count=0
    local overrides=Http:JSONDecode(o.materialStyles or "{}")
    local function add(name,cf,size,mat,col,shape)
        count=count+1; assert(count<=MAX_PARTS,"Part budget exceeded (6500)")
        local p=simplePart(output,name,cf,size,mat,col,o.collide)
        if shape then p.Shape=shape end
        Materials.apply(p,overrides[name])
        return p
    end
    local function frame(d)
        local p,f,r,u=G.frame(path,d); return p+Vector3.new(0,o.offset,0),f,r,u
    end
    local function beam(name,a,b,up,w,h,mat,col,overlap)
        local cf,len=axisCF(a,b,up)
        if cf then add(name,cf,Vector3.new(w,h,len+(overlap or 0)),mat,col) end
    end
    local ok,err=pcall(function()
        if o.preset=="Deform" then
            validAsset(asset)
            local part=Deform.build(asset,path,o); part.Parent=output; count=1; return
        end
        if o.preset=="Custom" then
            local per=validAsset(asset)
            local ds=G.instances(path,o.spacing,math.floor(MAX_PARTS/per))
            for _,d in ipairs(ds) do
                local p,f,_,u=frame(d)
                local c=cloneAsset(asset)
                local cf=CFrame.lookAt(p,p+f,u)*CFrame.Angles(0,math.rad(o.yaw),0)*CFrame.Angles(0,0,math.rad(o.roll))
                c:PivotTo(cf)
                local function configure(part) part.Anchored=true; part.CanCollide=o.collide; part.CanTouch=false end
                if c:IsA("BasePart") then configure(c) end
                for _,child in ipairs(c:GetDescendants()) do if child:IsA("BasePart") then configure(child) end end
                c.Parent=output; count=count+per
            end
            return
        end
        if o.preset=="Wall" or o.preset=="Fence" or o.preset=="Road" then assert(o.height>0,"Height must be positive for this preset") end
        local ds=G.segments(path,o.step,2000)
        for i=1,#ds-1 do
            local a,_,ra,ua=frame(ds[i]); local b,_,rb,ub=frame(ds[i+1])
            local up=ua+ub; up=up.Magnitude>1e-4 and up.Unit or ua
            if o.preset=="Rail" then
                for _,side in ipairs({-1,1}) do
                    local aa=a+ra*o.width/2*side+ua*o.height
                    local bb=b+rb*o.width/2*side+ub*o.height
                    beam("RailFoot",aa,bb,up,0.30,0.10,Enum.Material.Metal,steel,0.06)
                    beam("RailHead",aa+ua*0.11,bb+ub*0.11,up,0.13,0.17,Enum.Material.Metal,steel,0.06)
                end
            elseif o.preset=="Road" then
                beam("RoadSurface",a-ua*o.height/2,b-ub*o.height/2,up,o.width,o.height,Enum.Material.Asphalt,asphalt,0.12)
                for _,side in ipairs({-1,1}) do
                    beam("EdgeLine",a+ra*(o.width/2-0.3)*side+ua*0.025,b+rb*(o.width/2-0.3)*side+ub*0.025,up,0.10,0.035,Enum.Material.SmoothPlastic,Color3.fromRGB(220,220,210),0.06)
                end
            elseif o.preset=="Wall" then
                beam("Wall",a+ua*o.height/2,b+ub*o.height/2,up,o.width,o.height,Enum.Material.Concrete,concrete,0.12)
            elseif o.preset=="Fence" then
                for _,h in ipairs({0.38,0.82}) do beam("FenceRail",a+ua*o.height*h,b+ub*o.height*h,up,o.width,0.20,Enum.Material.Wood,timber,0.06) end
            elseif o.preset=="Pipe" then
                local aa=a+ua*o.height; local bb=b+ub*o.height
                local cf,len=axisCF(aa,bb,up)
                if cf then
                    add("Pipe",cf*CFrame.Angles(0,math.pi/2,0),Vector3.new(len+0.04,o.width,o.width),Enum.Material.Metal,steel,Enum.PartType.Cylinder)
                    if i>1 then add("Joint",CFrame.new(aa),Vector3.new(o.width,o.width,o.width),Enum.Material.Metal,steel,Enum.PartType.Ball) end
                end
            end
        end
        if o.preset=="Rail" or o.preset=="Fence" or o.preset=="Road" then
            for _,d in ipairs(G.instances(path,o.spacing,2000)) do
                local p,f,_,u=frame(d); local cf=CFrame.lookAt(p,p+f,u)
                if o.preset=="Rail" then
                    add("Sleeper",cf*CFrame.new(0,o.height-0.14,0),Vector3.new(o.width+1.25,0.20,0.40),Enum.Material.Wood,timber)
                elseif o.preset=="Fence" then
                    add("FencePost",cf*CFrame.new(0,o.height/2,0),Vector3.new(o.width*1.7,o.height,o.width*1.7),Enum.Material.Wood,timber)
                else
                    local len=math.min(2,o.spacing*0.45,path.length)
                    if d-len/2>=0 and d+len/2<=path.length then add("CenterMark",cf*CFrame.new(0,0.028,0),Vector3.new(0.15,0.035,len),Enum.Material.SmoothPlastic,Color3.fromRGB(233,184,62)) end
                end
            end
        end
    end)
    if not ok then output:Destroy(); error(err,0) end
    return output,count
end
local function makeMeta(o,template)
    local meta=Instance.new("Folder"); meta.Name="PathData"
    for k,v in pairs(o) do meta:SetAttribute(k,v) end
    meta:SetAttribute("PointCount",#points)
    for i,p in ipairs(points) do local val=Instance.new("Vector3Value"); val.Name=string.format("P%03d",i); val.Value=p; val.Parent=meta end
    local ref=Instance.new("ObjectValue"); ref.Name="Asset"; ref.Value=template; ref.Parent=meta
    return meta
end
local function commit()
    editAllowed(); stopMode()
    local o=options(); local path=pathFor()
    assert(not root or (root:IsDescendantOf(workspace) and root:GetAttribute("PathForgeSchema")==1),"Saved path no longer exists; load again or create a new path")
    if root then assert(root:FindFirstChild("Generated") and root:FindFirstChild("PathData"),"PathForge data is missing; load or create a new path") end
    local output,count=build(path,o)
    local template=nil; local pending=nil
    if o.preset=="Custom" or o.preset=="Deform" then
        local library=Storage:FindFirstChild("PathForgeAssets")
        if library and asset:IsDescendantOf(library) then template=asset else
            local ok,result=pcall(cloneAsset,asset)
            if not ok then output:Destroy(); error(result,0) end
            pending=result; pending.Name=asset.Name.."_"..Http:GenerateGUID(false):sub(1,8); template=pending
        end
    end
    if RunService:IsRunning() then output:Destroy(); if pending then pending:Destroy() end; error("Stop play testing and regenerate") end
    local meta=makeMeta(o,template)
    local recording=History:TryBeginRecording("PathForgeGenerate","PathForge: Generate path")
    if not recording then output:Destroy(); meta:Destroy(); if pending then pending:Destroy() end; error("Cannot start Studio undo recording. Try again.") end
    local target=root
    local oldGenerated,oldMeta
    local createdLibrary=nil
    local success,err=pcall(function()
        if pending then
            local lib=Storage:FindFirstChild("PathForgeAssets")
            if not lib then lib=Instance.new("Folder"); lib.Name="PathForgeAssets"; lib.Parent=Storage; createdLibrary=lib end
            assert(lib:IsA("Folder"),"ServerStorage.PathForgeAssets must be a Folder")
            pending.Parent=lib
        end
        if not target then target=Instance.new("Model"); target.Name="PF_"..o.preset; target:SetAttribute("PathForgeSchema",1)
        else oldGenerated=target:FindFirstChild("Generated"); oldMeta=target:FindFirstChild("PathData"); oldGenerated.Parent=nil; oldMeta.Parent=nil end
        output.Parent=target; meta.Parent=target
        if not root then target.Parent=workspace end
    end)
    if not success then
        output:Destroy(); meta:Destroy(); if pending then pending:Destroy() end; if createdLibrary then createdLibrary:Destroy() end
        if not root and target then target:Destroy() end
        if root and oldGenerated then oldGenerated.Parent=root end; if root and oldMeta then oldMeta.Parent=root end
        History:FinishRecording(recording,Enum.FinishRecordingOperation.Cancel); error(err,0)
    end
    History:FinishRecording(recording,Enum.FinishRecordingOperation.Commit)
    -- Detached prior objects are left for Studio history, with no Workspace presence.
    root=target; if template then asset=template end
    Selection:Set({root}); refreshLabel(); syncButtons(); refreshPreview()
    say(string.format("Generated %d parts | %.1f studs. Saved path can be reloaded.",count,path.length))
end
local function loadSelected()
    editAllowed(); stopMode()
    local s=Selection:Get()[1]
    while s and s~=workspace and s:GetAttribute("PathForgeSchema")~=1 do s=s.Parent end
    assert(s and s~=workspace and s:GetAttribute("PathForgeSchema")==1,"Select a PathForge model or one of its parts")
    local meta=s:FindFirstChild("PathData"); assert(meta and s:FindFirstChild("Generated"),"Missing saved path data")
    local n=meta:GetAttribute("PointCount"); assert(type(n)=="number" and n>=2 and n<=MAX_POINTS,"Invalid saved point count")
    local pp={}
    for i=1,n do local v=meta:FindFirstChild(string.format("P%03d",i)); assert(v and v:IsA("Vector3Value"),"Missing control point"); pp[i]=v.Value end
    local pr=meta:GetAttribute("preset"); assert(table.find(presets,pr),"Unknown preset")
    root=s; points=pp; selected=1; preset=pr; smooth=meta:GetAttribute("smooth")==true; collide=meta:GetAttribute("collide")==true
    for _,k in ipairs({"width","height","spacing","step","offset","yaw","roll"}) do local v=meta:GetAttribute(k); if type(v)=="number" then fields[k].Text=tostring(v) end end
    local ref=meta:FindFirstChild("Asset"); asset=ref and ref:IsA("ObjectValue") and ref.Value or nil
    local saved=meta:GetAttribute("materialStyles"); styles=type(saved)=="string" and Http:JSONDecode(saved) or {}; syncMaterials()
    syncButtons(); refreshLabel(); refreshPreview(); say("Loaded saved path. Generate updates only this model's output.")
end
label("03   BUILD / SAVED PATHS",22,C.muted)
button("Generate / update saved path",guarded(function()
    busy=true
    local ok,err=pcall(commit)
    busy=false
    if not ok then error(err,0) end
end),true)
button("Load selected saved path",guarded(loadSelected))
button("Hide draft guides",function() stopMode(); clearPreview(); say("Guides hidden. Draft retained.") end)
button("Show draft guides",guarded(function() editAllowed(); refreshPreview() end))
label("Custom repeats source models; Deform bends one static MeshPart. Material slots affect built-in geometry. Generate commits; draft edits do not.",72,C.muted)
widget:GetPropertyChangedSignal("Enabled"):Connect(function()
    tool:SetActive(widget.Enabled)
    if widget.Enabled then refreshPreview() else stopMode(); clearPreview() end
end)
local runConnection=RunService.Heartbeat:Connect(function()
    if RunService:IsRunning() and (preview or mode) then stopMode(); clearPreview() end
end)
tool.Click:Connect(function() widget.Enabled=not widget.Enabled end)
plugin.Unloading:Connect(function() stopMode(); clearPreview(); runConnection:Disconnect() end)
syncButtons(); syncMaterials(); refreshLabel(); if widget.Enabled then refreshPreview() end
