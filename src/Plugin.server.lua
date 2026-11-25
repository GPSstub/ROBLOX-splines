-- PathForge v0.5 | Studio-only path editor. Mesh uploads are explicit.
if not plugin then return end
local G=require(script.Parent.Geometry)
local Materials=require(script.Parent.Materials)
local Deform=require(script.Parent.Deform)
local Extrude=require(script.Parent.Extrude)
local Layers=require(script.Parent.Layers)
local SelfTest=require(script.Parent.SelfTest)
local T=require(script.Parent.Locale).t
local Selection=game:GetService("Selection")
local History=game:GetService("ChangeHistoryService")
local RunService=game:GetService("RunService")
local Storage=game:GetService("ServerStorage")
local Http=game:GetService("HttpService")
local toolbar=plugin:CreateToolbar("PathForge")
local tool=toolbar:CreateButton("PathForge", T("Procedural path and asset editor"), "", "PathForge")
tool.ClickableWhenViewportHidden=true
local info=DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right,false,false,340,700,290,360)
local widget=plugin:CreateDockWidgetPluginGuiAsync("PathForge_Editor_v1",info)
widget.Title=T("PathForge | Level Toolkit")
local mouse=plugin:GetMouse()
local presets={"Rail","Road","Wall","Fence","Pipe","Custom","Deform","Extrude"}
local defaults={Rail={width=3.2,height=0.2,spacing=1.8,step=1},Road={width=12,height=0.35,spacing=8,step=2},Wall={width=0.8,height=8,spacing=5,step=2},Fence={width=0.3,height=4,spacing=5,step=2},Pipe={width=1.4,height=1.5,spacing=8,step=1},Custom={width=1,height=0,spacing=5,step=2},Deform={width=1,height=0,spacing=5,step=2},Extrude={width=6,height=1,spacing=5,step=2}}
local fields={}
local styles={}
local materialSlots={"RailFoot","RailHead","Sleeper","RoadSurface","EdgeLine","CenterMark","Wall","FenceRail","FencePost","Pipe","Joint","ExtrudedMesh"}
local materialSlot=1
local busy=false
local uploadArmed=false
local uploadButton
local unloading=false
local loadedPivot=nil
local loadedMeta=nil
local loadedOutput=nil
local draftGuides={}
local draftNodes={}
local meshPreview,previewEditable,layerPreview
local repeatLayers={}
local layerIndex=0
local syncLayers=function() end
local liveEnabled=false
local previewBusy=false
local previewRevision=0
local previewDue=nil
local liveButton
local function setLive(enabled)
    liveEnabled=enabled
    previewDue=enabled and os.clock()+0.35 or nil
    if liveButton then liveButton.Text=T(enabled and "Auto preview: ON" or "Auto preview: OFF") end
end
local fidelity="Default"
local function clearMeshPreview()
    previewRevision+=1
    if liveEnabled then previewDue=os.clock()+0.35 end
    if layerPreview then layerPreview:Destroy(); layerPreview=nil end
    if meshPreview then meshPreview:Destroy(); meshPreview=nil end
    if previewEditable then previewEditable:Destroy(); previewEditable=nil end
end
local function resetUpload()
    uploadArmed=false
    if uploadButton then uploadButton.Text=T("Authorize ONE mesh upload: OFF") end
end
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
local syncHandles=function() end
local refreshLabel
local syncButtons=function() end
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
local currentSection=nil
local activeSection="Path"
local sectionItems={}
local sectionButtons={}
local function selectSection(name)
    activeSection=name
    for section,items in pairs(sectionItems) do
        for _,obj in ipairs(items) do obj.Visible=section==name end
    end
    for section,b in pairs(sectionButtons) do b.BackgroundColor3=section==name and C.accent or C.panel end
end
local function item(class,props)
    order=order+1
    props.LayoutOrder=order
    local obj=make(class,scroll,props)
    if currentSection then
        sectionItems[currentSection]=sectionItems[currentSection] or {}
        table.insert(sectionItems[currentSection],obj); obj.Visible=currentSection==activeSection
    end
    return obj
end
local function label(text,h,color)
    return item("TextLabel",{Size=UDim2.new(1,0,0,h or 22),BackgroundTransparency=1,Text=T(text),TextColor3=color or C.text,Font=Enum.Font.Gotham,TextSize=13,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left})
end
local function button(text,fn,accent)
    local b=item("TextButton",{Size=UDim2.new(1,0,0,32),BackgroundColor3=accent and C.accent or C.panel,BorderSizePixel=0,Text=T(text),TextColor3=C.text,Font=Enum.Font.GothamMedium,TextSize=13,AutoButtonColor=true})
    make("UICorner",b,{CornerRadius=UDim.new(0,5)})
    b.Activated:Connect(function() if not busy then fn() end end)
    return b
end
local function input(key,title,value)
    local row=item("Frame",{Size=UDim2.new(1,0,0,30),BackgroundTransparency=1})
    make("TextLabel",row,{Size=UDim2.fromScale(0.59,1),BackgroundTransparency=1,Text=T(title),TextColor3=C.muted,Font=Enum.Font.Gotham,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left})
    local box=make("TextBox",row,{Position=UDim2.fromScale(0.6,0),Size=UDim2.fromScale(0.4,1),BackgroundColor3=C.panel,BorderSizePixel=0,Text=tostring(value),TextColor3=C.text,Font=Enum.Font.Gotham,TextSize=13,ClearTextOnFocus=false})
    make("UICorner",box,{CornerRadius=UDim.new(0,4)})
    fields[key]=box
    return box
end
local title=label("PATHFORGE   /   0.5",28)
title.Font=Enum.Font.GothamBold; title.TextSize=19
local nav=item("Frame",{Size=UDim2.new(1,0,0,32),BackgroundTransparency=1})
for i,name in ipairs({"Path","Shape","Layers","Build"}) do
    local b=make("TextButton",nav,{Position=UDim2.new((i-1)/4,2,0,0),Size=UDim2.new(1/4,-4,1,0),Text=T(name),TextSize=12,Font=Enum.Font.GothamMedium,TextColor3=C.text,BackgroundColor3=C.panel,BorderSizePixel=0})
    make("UICorner",b,{CornerRadius=UDim.new(0,4)}); sectionButtons[name]=b
    b.Activated:Connect(function() selectSection(name); scroll.CanvasPosition=Vector2.zero end)
end
local status=label("Create a path or load a saved PathForge model.",46)
currentSection="Path"
label("01   PATH / CONTROL POINTS",22,C.muted)
local function say(t,err) status.Text=T(t); status.TextColor3=err and C.error or C.text end
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
    return {profile=fields.profile.Text,sides=math.floor(number("sides",3,64)),uvLength=number("uvLength",0.05,1000),uvWidth=number("uvWidth",0.05,1000),angle=number("angle",1,90),tolerance=number("tolerance",0.005,10),fidelity=fidelity,materialStyles=Http:JSONEncode(styles),preset=preset,smooth=smooth,collide=collide,width=number("width",0.05,100),height=number("height",-50,100),spacing=number("spacing",0.2,200),step=number("step",0.15,100),offset=number("offset",-100,100),yaw=number("yaw",-360,360),roll=number("roll",-360,360)}
end
local function pathFor()
    local path=G.path(points,smooth); path.linear=not smooth; return path
end
local function clearPreview()
    setLive(false); clearMeshPreview()
    if preview then preview:Destroy(); preview=nil end
    table.clear(draftGuides); table.clear(draftNodes); syncHandles()
end
local function stopMode()
    dragging=false; mode=nil; syncHandles()
    if plugin:IsActivated() then plugin:Deactivate() end
end
local function startMode(m)
    editAllowed(); mode=m; plugin:Activate(true); syncHandles(); say(m=="add" and "Click surfaces to add points. Switch to Move to drag nodes." or (m=="insert" and "Click a surface to insert a node after the selected node." or "Drag a blue node. Use coordinate fields for exact XYZ."))
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
-- Reuse guide instances while dragging; no repeated full-folder allocation.
refreshPreview=function()
    clearMeshPreview()
    if not widget.Enabled or RunService:IsRunning() or unloading then clearPreview(); return end
    if not preview or preview.Parent~=workspace then
        if preview then preview:Destroy() end; table.clear(draftGuides); table.clear(draftNodes)
        preview=Instance.new("Folder"); preview.Name="_PathForgeDraft"; preview.Archivable=false; preview.Parent=workspace
    end
    local used=0
    if #points>=2 then
        local ok,path=pcall(pathFor)
        if ok then
            local n=math.min(160,math.max(1,math.ceil(path.length/2)))
            for i=1,n do
                local a,b=G.at(path,path.length*(i-1)/n),G.at(path,path.length*i/n)
                local cf,len=axisCF(a,b,Vector3.new(0,1,0))
                if cf then
                    used+=1
                    local part=draftGuides[used]
                    if not part then
                        part=simplePart(preview,"Guide",cf,Vector3.new(0.1,0.1,len+0.04),Enum.Material.Neon,Color3.fromRGB(66,187,216),false)
                        part.CanQuery=false; part.CastShadow=false; part.Archivable=false
                        draftGuides[used]=part
                    else
                        part.CFrame=cf; part.Size=Vector3.new(0.1,0.1,len+0.04)
                    end
                end
            end
        end
    end
    for i=#draftGuides,used+1,-1 do draftGuides[i]:Destroy(); draftGuides[i]=nil end
    for i,pos in ipairs(points) do
        local color=i==selected and Color3.fromRGB(255,176,79) or Color3.fromRGB(70,160,255)
        local node=draftNodes[i]
        if not node then
            node=simplePart(preview,"Node_"..i,CFrame.new(pos),Vector3.new(0.65,0.65,0.65),Enum.Material.Neon,color,false)
            node.Shape=Enum.PartType.Ball; node.CastShadow=false; node.Archivable=false
            node:SetAttribute("NodeIndex",i); draftNodes[i]=node
        else node.CFrame=CFrame.new(pos); node.Color=color end
    end
    for i=#draftNodes,#points+1,-1 do draftNodes[i]:Destroy(); draftNodes[i]=nil end
    syncHandles()
end
local pointLabel=label("0 points",22)
button("New path / clear draft",guarded(function() editAllowed(); stopMode(); root=nil; loadedPivot=nil; loadedMeta=nil; loadedOutput=nil; asset=nil; repeatLayers={}; layerIndex=0; syncLayers(); resetUpload(); points={}; selected=0; styles={}; syncMaterials(); syncButtons(); refreshLabel(); refreshPreview(); say("New draft. Existing generated models are unchanged.") end))
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
    pointLabel.Text=T(string.format("%d points   |   Node %d   |   %s",#points,selected,root and "Editing saved path" or "New path"))
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
local axisHandles,axisStart,axisNode
local function movePoint()
    local old=points[selected]; if not old then return end
    local p=hitPosition(old.Y)
    if p and (p-old).Magnitude>0.001 then points[selected]=p; refreshLabel(); refreshPreview() end
end
mouse.Button1Down:Connect(guarded(function()
    if axisStart or not mode or not widget.Enabled or RunService:IsRunning() then return end
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
plugin.Deactivation:Connect(function() mode=nil; dragging=false; axisStart=nil; syncHandles() end)
do
    local ok,err=pcall(function()
        axisHandles=Instance.new("Handles")
        axisHandles.Name="PathForgeAxisHandles"; axisHandles.Style=Enum.HandlesStyle.Movement
        axisHandles.Faces=Faces.new(Enum.NormalId.Right,Enum.NormalId.Left,Enum.NormalId.Top,Enum.NormalId.Bottom,Enum.NormalId.Front,Enum.NormalId.Back)
        axisHandles.Color3=Color3.fromRGB(83,185,234); axisHandles.Visible=false
        axisHandles.Parent=game:GetService("CoreGui")
        syncHandles=function()
            local node=widget.Enabled and mode=="move" and draftNodes[selected] or nil
            if not node then axisStart=nil; axisNode=nil end
            axisHandles.Adornee=node; axisHandles.Visible=node~=nil
        end
        axisHandles.MouseButton1Down:Connect(guarded(function()
            if mode~="move" or not points[selected] then return end
            dragging=false; axisNode=selected; axisStart=points[selected]
        end))
        axisHandles.MouseDrag:Connect(guarded(function(face,distance)
            if not axisStart or not axisNode or not points[axisNode] then return end
            local grid=number("grid",0,100)
            if grid>0 then distance=math.floor(distance/grid+0.5)*grid end
            points[axisNode]=axisStart+Vector3.FromNormalId(face)*distance
            refreshLabel(); refreshPreview()
        end))
        axisHandles.MouseButton1Up:Connect(function() axisStart=nil; axisNode=nil end)
    end)
    if not ok then if axisHandles then axisHandles:Destroy(); axisHandles=nil end; syncHandles=function() end; warn("[PathForge] Axis handles unavailable:",err) end
end
currentSection="Shape"
label("02   GENERATOR / PARAMETERS",22,C.muted)
local presetButton,smoothButton,collisionButton,assetLabel
local presetChoices={}
syncButtons=function()
    presetButton.Text=T("Generator: "..preset)
    for name,b in pairs(presetChoices) do b.BackgroundColor3=name==preset and C.accent or C.panel end
    smoothButton.Text=T(smooth and "Curve: Smooth spline" or "Curve: Straight segments")
    collisionButton.Text=T(collide and "Collision: ON" or "Collision: OFF")
    assetLabel.Text=T(asset and ("Asset: "..asset.Name) or "Asset: none (Custom / Deform)")
    if preset~="Deform" and preset~="Extrude" then resetUpload() end
    -- Upload authorization is in Build, always visible when that tab is selected.
end
local function applyDefaults()
    for k,v in pairs(defaults[preset]) do fields[k].Text=tostring(v) end
end
presetButton=label("Generator: Rail",24)
for row=0,1 do
    local panel=item("Frame",{Size=UDim2.new(1,0,0,29),BackgroundTransparency=1})
    for col=1,4 do
        local name=presets[row*4+col]
        local b=make("TextButton",panel,{Position=UDim2.new((col-1)/4,2,0,0),Size=UDim2.new(1/4,-4,1,0),Text=T(name),TextSize=12,Font=Enum.Font.GothamMedium,TextColor3=C.text,BackgroundColor3=C.panel,BorderSizePixel=0})
        make("UICorner",b,{CornerRadius=UDim.new(0,4)}); presetChoices[name]=b
        b.Activated:Connect(function()
            if busy or preset==name then return end
            preset=name; if name=="Extrude" then asset=nil end
            resetUpload(); applyDefaults(); syncButtons(); clearMeshPreview()
        end)
    end
end
smoothButton=button("Curve: Smooth spline",function() smooth=not smooth; syncButtons(); refreshPreview() end)
collisionButton=button("Collision: ON",function() collide=not collide; clearMeshPreview(); syncButtons() end)
input("width","Width / rail gauge / diameter",3.2)
input("height","Height / base elevation",0.2)
input("spacing","Asset / sleeper / post spacing",1.8)
input("step","Segment size (studs)",1)
input("offset","Vertical offset (studs)",0)
input("yaw","Custom yaw (degrees)",0)
input("roll","Roll (degrees)",0)
label("02A  EXTRUDE / MESH QUALITY",22,C.muted)
input("profile","Profile (rectangle / circle / arch / x,y;...)", "rectangle")
input("sides","Circle / arch subdivisions",16)
input("uvLength","UV length per tile",4)
input("uvWidth","UV perimeter per tile",4)
input("angle","Max turn per segment (degrees)",8)
input("tolerance","Chord tolerance (studs)",0.05)
local collisionModes={"Default","Box","Hull","PreciseConvexDecomposition"}
local fidelityButton
fidelityButton=button("Mesh collision: Default",function()
    fidelity=collisionModes[(table.find(collisionModes,fidelity) or 1)%#collisionModes+1]
    fidelityButton.Text=T("Mesh collision: "..fidelity); clearMeshPreview()
end)
assetLabel=label("Asset: none (Custom preset only)",30,C.muted)
local function validAsset(a)
    assert(a and (a:IsA("Model") or a:IsA("BasePart")),"Select a Model or BasePart")
    assert(a.Archivable,"Asset must be Archivable")
    assert(not a:IsA("Terrain"),"Terrain cannot be used as a static asset")
    local count=a:IsA("BasePart") and 1 or 0
    for _,d in ipairs(a:GetDescendants()) do
        if d:IsA("BasePart") then count=count+1; assert(d.Archivable,"All source BaseParts must be Archivable") end
    end
    assert(count>0,"Asset contains no BaseParts")
    return count
end
button("Use selected Model as custom asset",guarded(function()
    editAllowed(); local a=Selection:Get()[1]; validAsset(a); assert(a.Parent,"Select an existing asset")
    assert(not preview or not a:IsDescendantOf(preview),"Do not use a preview node")
    clearMeshPreview(); asset=a; preset="Custom"; applyDefaults(); syncButtons(); say("Asset selected. A reusable snapshot is stored when generated.")
end))
label("02B  MATERIAL SLOTS",22,C.muted)
local slotButton,styleLabel
syncMaterials=function()
    local name=materialSlots[materialSlot]
    if slotButton then slotButton.Text=T("Material slot: "..name) end
    if styleLabel then
        local style=styles[name]
        styleLabel.Text=T(style and (style.material.." / "..(style.variant~="" and style.variant or "default").." / "..#style.textures.." textures") or "Preset default (no override)")
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
    styles[materialSlots[materialSlot]]=Materials.capture(s); clearMeshPreview()
    syncMaterials(); say("Material slot captured. Generate to apply.")
end),true)
button("Reset material slot",function() styles[materialSlots[materialSlot]]=nil; clearMeshPreview(); syncMaterials() end)
button("Reset all material slots",function() styles={}; clearMeshPreview(); syncMaterials() end)
button("Use selected MeshPart / Deform",guarded(function()
    editAllowed()
    local a=Selection:Get()[1]; validAsset(a); assert(a.Parent,"Select an existing asset")
    assert(a:IsA("MeshPart"),"Select a single MeshPart")
    assert(not preview or not a:IsDescendantOf(preview),"Do not use preview objects")
    assert(not root or not a:IsDescendantOf(root),"Use a source mesh outside the active generated path")
    clearMeshPreview(); resetUpload(); asset=a; preset="Deform"; applyDefaults(); syncButtons()
    say("Deform uses the full path length, local -Z forward. Dense mesh required.")
end))
button("Use selected MeshPart appearance / Extrude",guarded(function()
    editAllowed(); local a=Selection:Get()[1]; validAsset(a)
    assert(a:IsA("MeshPart") and a.Parent,"Select a MeshPart with PBR appearance")
    assert(not preview or not a:IsDescendantOf(preview),"Select a real source")
    assert(not root or not a:IsDescendantOf(root),"Choose a source outside active path")
    asset=a; preset="Extrude"; resetUpload(); applyDefaults(); syncButtons(); clearMeshPreview()
    say("Extrude copies selected mesh appearance, not its geometry.")
end))
button("Clear source / use Extrude material slot",guarded(function()
    asset=nil; preset="Extrude"; resetUpload(); applyDefaults(); syncButtons(); clearMeshPreview()
end))
currentSection="Layers"
label("03   REPEAT LAYERS / SHARED PATH",22,C.muted)
local layerTitle=label("No repeat layers",42)
input("layerSpacing","Spacing (studs)",5)
input("layerSide","Lateral offset (studs)",0)
input("layerHeight","Local height offset",0)
input("layerYaw","Yaw (degrees)",0)
input("layerRoll","Roll (degrees)",0)
local enabledButton,layerCollisionButton
syncLayers=function()
    local l=repeatLayers[layerIndex]
    layerTitle.Text=T(l and string.format("%d / %d  |  %s",layerIndex,#repeatLayers,l.source and l.source.Name or "Missing source") or "No repeat layers")
    if l then
        for k,v in pairs({layerSpacing=l.spacing,layerSide=l.side,layerHeight=l.height,layerYaw=l.yaw,layerRoll=l.roll}) do fields[k].Text=tostring(v) end
    end
    if enabledButton then enabledButton.Text=T(l and (l.enabled and "Layer enabled: ON" or "Layer enabled: OFF") or "Layer enabled: —") end
    if layerCollisionButton then layerCollisionButton.Text=T(l and (l.collide and "Layer collision: ON" or "Layer collision: OFF") or "Layer collision: —") end
end
button("Add selected model as repeat layer",guarded(function()
    editAllowed(); local a=Selection:Get()[1]; validAsset(a); assert(a.Parent,"Select an existing asset")
    assert(not preview or (a~=preview and not a:IsDescendantOf(preview)),"Do not use preview objects")
    assert(not root or (a~=root and not a:IsDescendantOf(root)),"Do not use the active generated path")
    assert(#repeatLayers<Layers.MAX_LAYERS,"Maximum 12 repeat layers")
    repeatLayers[#repeatLayers+1]={source=a,spacing=5,side=0,height=0,yaw=0,roll=0,enabled=true,collide=true}
    layerIndex=#repeatLayers; syncLayers(); clearMeshPreview()
end),true)
button("Previous layer",function() if #repeatLayers>0 then layerIndex=(layerIndex-2)%#repeatLayers+1; syncLayers() end end)
button("Next layer",function() if #repeatLayers>0 then layerIndex=layerIndex%#repeatLayers+1; syncLayers() end end)
button("Apply layer settings",guarded(function()
    local l=assert(repeatLayers[layerIndex],"Select a layer")
    local nextLayer=table.clone(l)
    nextLayer.spacing=number("layerSpacing",0.2,200); nextLayer.side=number("layerSide",-1000,1000)
    nextLayer.height=number("layerHeight",-1000,1000); nextLayer.yaw=number("layerYaw",-360,360); nextLayer.roll=number("layerRoll",-360,360)
    Layers.validate(nextLayer); repeatLayers[layerIndex]=nextLayer; clearMeshPreview(); say("Layer settings applied to draft.")
end),true)
enabledButton=button("Layer enabled: —",function() local l=repeatLayers[layerIndex]; if l then l.enabled=not l.enabled; syncLayers(); clearMeshPreview() end end)
layerCollisionButton=button("Layer collision: —",function() local l=repeatLayers[layerIndex]; if l then l.collide=not l.collide; syncLayers(); clearMeshPreview() end end)
button("Remove selected layer",guarded(function()
    if repeatLayers[layerIndex] then table.remove(repeatLayers,layerIndex); layerIndex=math.min(layerIndex,#repeatLayers); syncLayers(); clearMeshPreview() end
end))
label("Each layer repeats its own source model along the same spline. Apply layer settings before preview or generation.",58,C.muted)
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
local function build(path,o,source,allowUpload)
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
        if o.preset=="Extrude" then
            assert(allowUpload,"Authorize one mesh upload before Generate")
            local part=Extrude.build(path,o,source,false,function() return not unloading and widget.Enabled and not RunService:IsRunning() end,overrides.ExtrudedMesh)
            part.Parent=output; count=1; return
        end
        if o.preset=="Deform" then
            validAsset(source)
            assert(allowUpload,"Authorize one mesh upload before Generate (Deform only)")
            local part=Deform.build(source,path,o,function() return not unloading and widget.Enabled and not RunService:IsRunning() end); part.Parent=output; count=1; return
        end
        if o.preset=="Custom" then
            local per=validAsset(source)
            local ds=G.instances(path,o.spacing,math.floor(MAX_PARTS/per))
            for _,d in ipairs(ds) do
                local p,f,_,u=frame(d)
                local c=cloneAsset(source)
                local cf=CFrame.lookAt(p,p+f,u)*CFrame.Angles(0,math.rad(o.yaw),0)*CFrame.Angles(0,0,math.rad(o.roll))
                c.Parent=output
                c:PivotTo(cf)
                local function configure(part) part.Anchored=true; part.CanCollide=o.collide; part.CanTouch=false end
                if c:IsA("BasePart") then configure(c) end
                for _,child in ipairs(c:GetDescendants()) do if child:IsA("BasePart") then configure(child) end end
                count=count+per
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
local function makeMeta(o,template,pivot,savedLayers)
    local meta=Instance.new("Folder"); meta.Name="PathData"
    for k,v in pairs(o) do meta:SetAttribute(k,v) end
    meta:SetAttribute("PointCount",#points)
    meta:SetAttribute("CoordinateSpace","Local")
    for i,pos in ipairs(points) do local val=Instance.new("Vector3Value"); val.Name=string.format("P%03d",i); val.Value=pivot:PointToObjectSpace(pos); val.Parent=meta end
    local ref=Instance.new("ObjectValue"); ref.Name="Asset"; ref.Value=template; ref.Parent=meta
    Layers.write(meta,savedLayers)
    return meta
end
local function commit(allowUpload)
    editAllowed(); stopMode()
    local o=options(); local path=pathFor()
    local target=root
    local pivot=target and target:GetPivot() or CFrame.new(points[1])
    local oldGenerated,oldMeta
    local function checkTarget()
        assert(not unloading and widget.Enabled and not RunService:IsRunning(),"Editor closed or play testing started")
        if target then
            assert(target:IsDescendantOf(workspace) and target:GetAttribute("PathForgeSchema")==1,"Saved path no longer exists")
            assert(target:FindFirstChild("Generated")==loadedOutput and target:FindFirstChild("PathData")==loadedMeta,"Path changed externally; reload before generating")
            assert(target:GetPivot()==loadedPivot,"Path was moved; reload it before generating")
        end
    end
    checkTarget()
    local source=(o.preset=="Custom" or o.preset=="Deform" or o.preset=="Extrude") and asset or nil
    local output,meta,createdLibrary,recording
    local pending={}
    local snapshots={}
    local savedLayers={}
    local overlays
    local count
    local createdTarget=false
    local success,err=pcall(function()
        local library=Storage:FindFirstChild("PathForgeAssets")
        if library then assert(library:IsA("Folder"),"PathForgeAssets must be a Folder") end
        local function snapshot(a)
            validAsset(a); assert(a.Parent,"Source asset was removed")
            assert(not target or (a~=target and not a:IsDescendantOf(target)),"Choose a source outside the active generated path")
            assert(not preview or (a~=preview and not a:IsDescendantOf(preview)),"Do not use preview objects")
            if library and a:IsDescendantOf(library) then return a end
            if snapshots[a] then return snapshots[a] end
            local clone=cloneAsset(a)
            clone.Name=a.Name.."_"..Http:GenerateGUID(false):sub(1,8)
            pending[#pending+1]=clone; snapshots[a]=clone
            return clone
        end
        local template
        if o.preset=="Custom" or o.preset=="Deform" or (o.preset=="Extrude" and source) then template=snapshot(source) end
        for i,l in ipairs(repeatLayers) do
            local copy=table.clone(l)
            if l.source then copy.source=snapshot(l.source) else assert(not l.enabled,"Enabled layer has a missing source") end
            savedLayers[i]=copy
        end
        local layerCount
        overlays,layerCount=Layers.build(path,savedLayers,validAsset,cloneAsset,MAX_PARTS,false)
        -- A mesh generator uses exactly one part. Preflight overlay budget before upload.
        if o.preset=="Extrude" or o.preset=="Deform" then assert(layerCount<MAX_PARTS,"No budget left for base mesh") end
        output,count=build(path,o,template or source,allowUpload)
        assert(count+layerCount<=MAX_PARTS,"Combined base and layer budget exceeded")
        overlays.Parent=output; count+=layerCount
        checkTarget()
        meta=makeMeta(o,template,pivot,savedLayers)
        recording=History:TryBeginRecording("PathForgeGenerate","PathForge: Generate path")
        assert(recording,"Cannot start Studio undo recording. Try again.")
        if #pending>0 then
            local lib=Storage:FindFirstChild("PathForgeAssets")
            if not lib then lib=Instance.new("Folder"); lib.Name="PathForgeAssets"; lib.Parent=Storage; createdLibrary=lib end
            assert(lib:IsA("Folder"),"PathForgeAssets must be a Folder")
            for _,clone in ipairs(pending) do clone.Parent=lib end
        end
        if not target then
            target=Instance.new("Model"); createdTarget=true
            target.Name="PF_"..o.preset; target:SetAttribute("PathForgeSchema",1)
            target.WorldPivot=pivot
        else
            oldGenerated=target:FindFirstChild("Generated"); oldMeta=target:FindFirstChild("PathData")
            oldGenerated.Parent=nil; oldMeta.Parent=nil
            target.WorldPivot=pivot
        end
        output.Parent=target; meta.Parent=target
        if createdTarget then target.Parent=workspace end
        History:FinishRecording(recording,Enum.FinishRecordingOperation.Commit)
        recording=nil
        root=target; loadedPivot=target:GetPivot(); loadedMeta=meta; loadedOutput=output
        if template then asset=template end
        repeatLayers=savedLayers; syncLayers()
    end)
    if not success then
        if output then output:Destroy() end
        if meta then meta:Destroy() end
        if overlays and not overlays.Parent then overlays:Destroy() end
        for _,clone in ipairs(pending) do clone:Destroy() end
        if createdLibrary then createdLibrary:Destroy() end
        if createdTarget and target then target:Destroy() end
        if not createdTarget and target then
            if oldGenerated then oldGenerated.Parent=target end
            if oldMeta then oldMeta.Parent=target end
        end
        if recording then pcall(function() History:FinishRecording(recording,Enum.FinishRecordingOperation.Cancel) end) end
        error(err,0)
    end
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
    for i=1,n do local v=meta:FindFirstChild(string.format("P%03d",i)); assert(v and v:IsA("Vector3Value"),"Missing control point"); pp[i]=meta:GetAttribute("CoordinateSpace")=="Local" and s:GetPivot():PointToWorldSpace(v.Value) or v.Value end
    local pr=meta:GetAttribute("preset"); assert(table.find(presets,pr),"Unknown preset")
    local loadedLayers=Layers.read(meta)
    repeatLayers=loadedLayers; layerIndex=#repeatLayers>0 and 1 or 0; syncLayers()
    resetUpload(); root=s; loadedPivot=s:GetPivot(); loadedMeta=meta; loadedOutput=s:FindFirstChild("Generated"); points=pp; selected=1; preset=pr; smooth=meta:GetAttribute("smooth")==true; collide=meta:GetAttribute("collide")==true
    for _,k in ipairs({"width","height","spacing","step","offset","yaw","roll","sides","uvLength","uvWidth","angle","tolerance"}) do local v=meta:GetAttribute(k); if type(v)=="number" then fields[k].Text=tostring(v) elseif k=="sides" then fields[k].Text="16" elseif k=="uvLength" or k=="uvWidth" then fields[k].Text="4" elseif k=="angle" then fields[k].Text="8" elseif k=="tolerance" then fields[k].Text="0.05" end end
    fields.profile.Text=meta:GetAttribute("profile") or "rectangle"
    local savedFidelity=meta:GetAttribute("fidelity"); fidelity=table.find(collisionModes,savedFidelity) and savedFidelity or "Default"; fidelityButton.Text=T("Mesh collision: "..fidelity)
    local ref=meta:FindFirstChild("Asset"); asset=ref and ref:IsA("ObjectValue") and ref.Value or nil
    local saved=meta:GetAttribute("materialStyles"); styles=type(saved)=="string" and Http:JSONDecode(saved) or {}; syncMaterials()
    syncButtons(); refreshLabel(); refreshPreview(); say("Loaded saved path. Generate updates only this model's output.")
end
currentSection="Build"
label("04   BUILD / SAVED PATHS",22,C.muted)
local function previewNow(manual)
    if previewBusy or busy or not widget.Enabled or RunService:IsRunning() then return end
    if #points<2 then if manual then say("Add at least two points",true) end; return end
    if not preview then refreshPreview() end
    clearMeshPreview(); previewDue=nil; resetUpload()
    local revision=previewRevision
    local function active() return revision==previewRevision and not unloading and widget.Enabled and not RunService:IsRunning() end
    previewBusy=true
    local part,mesh,overlays
    local ok,err=pcall(function()
        local o,path=options(),pathFor()
        local list={}
        for i,l in ipairs(repeatLayers) do list[i]=table.clone(l) end
        overlays=Layers.build(path,list,validAsset,cloneAsset,1000,true)
        if o.preset=="Extrude" then
            part,mesh=Extrude.build(path,o,asset,true,active,styles.ExtrudedMesh)
        elseif o.preset=="Deform" then
            validAsset(asset); part,mesh=Deform.build(asset,path,o,active,true)
        end
        if not active() then return end
        if part then part.Parent=preview end
        overlays.Archivable=false; overlays.Parent=preview
        meshPreview=part; previewEditable=mesh; layerPreview=overlays
        part=nil; mesh=nil; overlays=nil
        if manual then say("Preview ready. Part-based base generators show guides only; repeat layers and mesh bases show geometry.") end
    end)
    if part then part:Destroy() end; if mesh then mesh:Destroy() end; if overlays then overlays:Destroy() end
    previewBusy=false
    if not ok and active() then say("Preview: "..tostring(err),true) end
end
button("Preview now (no upload)",guarded(function() editAllowed(); stopMode(); previewNow(true) end),true)
liveButton=button("Auto preview: OFF",guarded(function()
    editAllowed(); setLive(not liveEnabled); if not liveEnabled then clearMeshPreview() end
end))
button("Clear preview / disable auto",function() setLive(false); clearMeshPreview() end)
uploadButton=button("Authorize ONE mesh upload: OFF",guarded(function()
    editAllowed(); assert(preset=="Deform" or preset=="Extrude","Only mesh generators need an asset upload")
    setLive(false)
    uploadArmed=not uploadArmed
    uploadButton.Text=T(uploadArmed and "Authorize ONE mesh upload: ON" or "Authorize ONE mesh upload: OFF")
    say(uploadArmed and "Next Generate uploads one new mesh to Roblox under your account. It may remain even after undo." or "Mesh upload disabled.")
end))
button("Generate / update saved path",guarded(function()
    assert(not previewBusy,"Wait for preview to finish before generating")
    local authorized=uploadArmed
    setLive(false); resetUpload(); clearMeshPreview()
    busy=true
    local ok,err=pcall(commit,authorized)
    busy=false
    if not ok then error(err,0) end
end),true)
button("Load selected saved path",guarded(loadSelected))
button("Run geometry self-tests",guarded(function() editAllowed(); local n=SelfTest.run(); say(tostring(n).." geometry tests passed") end))
button("Hide draft guides",function() stopMode(); clearPreview(); say("Guides hidden. Draft retained.") end)
button("Show draft guides",guarded(function() editAllowed(); refreshPreview() end))
label("Custom repeats source models; Deform bends one static MeshPart. Material slots affect built-in geometry. Generate commits; draft edits do not.",72,C.muted)
widget:GetPropertyChangedSignal("Enabled"):Connect(function()
    tool:SetActive(widget.Enabled)
    if widget.Enabled then refreshPreview() else resetUpload(); stopMode(); clearPreview() end
end)
local runConnection=RunService.Heartbeat:Connect(function()
    if RunService:IsRunning() and (preview or mode or uploadArmed or liveEnabled) then resetUpload(); stopMode(); clearPreview(); return end
    if liveEnabled and previewDue and os.clock()>=previewDue and not busy and not previewBusy and not dragging and not axisStart then
        previewDue=nil; task.spawn(function() previewNow(false) end)
    end
end)
tool.Click:Connect(function() widget.Enabled=not widget.Enabled end)
plugin.Unloading:Connect(function() unloading=true; resetUpload(); stopMode(); clearPreview(); if axisHandles then axisHandles:Destroy() end; runConnection:Disconnect() end)
for _,field in pairs(fields) do field:GetPropertyChangedSignal("Text"):Connect(clearMeshPreview) end
syncButtons(); syncMaterials(); syncLayers(); selectSection("Path"); refreshLabel(); if widget.Enabled then refreshPreview() end
