-- PathForge | Studio-only path editor. Mesh uploads are explicit.
-- This script wires the UI to the modules; geometry, generators, building and
-- saved data live in their own ModuleScripts.
if not plugin then return end
local G=require(script.Parent.Geometry)
local Materials=require(script.Parent.Materials)
local Layers=require(script.Parent.Layers)
local SelfTest=require(script.Parent.SelfTest)
local P=require(script.Parent.Presets)
local Assets=require(script.Parent.Assets)
local Builder=require(script.Parent.Builder)
local Persist=require(script.Parent.Persist)
local Ui=require(script.Parent.Ui)
local Version=require(script.Parent.Version)
local Cache=require(script.Parent.Cache)
local Library=require(script.Parent.Library)
local Network=require(script.Parent.Network)
local Scatter=require(script.Parent.Scatter)
local DraftHistory=require(script.Parent.DraftHistory)
local TerrainPlan=require(script.Parent.Terrain)
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
pcall(function() Ui.applyTheme(settings().Studio.Theme) end)
local C=Ui.C
local MAX_PARTS=Builder.MAX_PARTS
local MAX_POINTS=128
local PREVIEW_BUDGET=3000

-- Editor state -------------------------------------------------------------
local busy=false
local unloading=false
local uploadArmed=false
local points={}
local selected=0
local smooth=true
local junctionsOn=true
local root,loadedPivot,loadedMeta,loadedOutput=nil,nil,nil,nil
local function newEntry(preset) return {o=P.options(preset),source=nil,styles={},enabled=true} end
local entries={newEntry("Rail")}
local current=1
local function entry() return entries[current] end
local repeatLayers={}
local layerIndex=0
local materialSlot=1
local preview=nil
local draftGuides,draftNodes={},{}
local previewFolder,previewMeshes=nil,{}
local liveEnabled,previewBusy,previewRevision,previewDue=false,false,0,nil
local mode,dragging,lastMove=nil,false,0
local axisHandles,axisStart,axisNode

local ui=Ui.new(widget,T,function() return busy end)
local label,button,row,fields=ui.label,ui.button,ui.row,ui.fields
-- Valid ranges for numeric fields; inputs turn red while out of range.
local RANGES={x={-100000,100000},y={-100000,100000},z={-100000,100000},grid={0,100},plane={-100000,100000},
    snapRadius={0.1,100},drapeOffset={-50,100},drapeSpacing={0,1000},terrainShoulder={0,100},terrainDepth={0,200},terrainClear={0,200},
    layerSpacing={0.2,200},layerSide={-1000,1000},layerHeight={-1000,1000},layerYaw={-360,360},layerRoll={-360,360},
    scatterBand={0.1,500},scatterGap={0,500},scatterDensity={0.001,100},scatterMin={0,100},scatterScaleMin={0.05,20},scatterScaleMax={0.05,20},
    scatterSeed={0,1e9},brushRadius={0.5,200}}
for k,spec in pairs(P.NUMBERS) do RANGES[k]={spec[1],spec[2]} end
local function input(key,title,value) return ui.input(key,title,value,RANGES[key]) end
local draftHistory=DraftHistory.new(50)
local function remember() draftHistory:push({points=points,selected=selected}) end
local status
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
    if not lo then lo,hi=RANGES[key][1],RANGES[key][2] end
    local v=tonumber(fields[key].Text)
    assert(v and v==v and v>=lo and v<=hi,key.." must be between "..lo.." and "..hi)
    return v
end
local function canContinue() return not unloading and widget.Enabled and not RunService:IsRunning() end
local pathCache=Cache.new(64)
local specCache=Cache.new(32)
-- Paths are cached by their points; identical drafts reuse samples and frames.
local function cachedPath(controlPoints,isSmooth)
    local key=Cache.pointsKey(controlPoints,isSmooth)
    return pathCache:memo(key,function()
        local path=G.path(controlPoints,isSmooth); path.linear=not isSmooth; path.key=key; return path
    end)
end
local function pathFor() return cachedPath(points,smooth) end
local function roadWidth(list)
    local width
    for _,e in ipairs(list) do
        if e.enabled~=false and e.o.preset=="Road" then width=math.max(width or 0,e.o.width) end
    end
    return width
end
local function savedPaths(includeRoot)
    local out={}
    for _,m in ipairs(workspace:GetDescendants()) do
        if m:IsA("Model") and (includeRoot or m~=root) and m:GetAttribute("PathForgeSchema")==1 and m:FindFirstChild("PathData") then
            local meta,pivot=m:FindFirstChild("PathData"),m:GetPivot()
            local ok,state=pcall(Persist.read,meta,pivot)
            if ok then
                local okPath,path=pcall(cachedPath,state.points,state.smooth)
                if okPath then
                    local output=m:FindFirstChild("Generated")
                    out[#out+1]={model=m,path=path,entries=state.entries,meta=meta,pivot=pivot,output=output,
                        width=state.junctions and output and roadWidth(state.entries) or nil}
                end
            end
        end
    end
    return out
end
local function junctionPlan(path,list,updateNeighbors)
    local width=junctionsOn and roadWidth(list) or nil
    if not width and not (updateNeighbors and root) then return {junctions={},pads={}},{} end
    local draft={path=path,width=width}
    local roads={}
    local index,previous
    for _,saved in ipairs(savedPaths(true)) do
        if saved.model==root then
            if saved.width then previous=saved end
            roads[#roads+1]=draft
            index=#roads
        elseif saved.width then
            roads[#roads+1]=saved
        end
    end
    if not index then
        roads[#roads+1]=draft
        index=#roads
    end
    return Network.planRoads(roads,index,previous,updateNeighbors)
end
local function hasMeshEntry()
    for _,e in ipairs(entries) do if e.enabled and P.MESH[e.o.preset] then return true end end
    return false
end

-- Late-bound UI refreshers.
local refreshPreview,refreshLabel
local syncHandles=function() end
local syncButtons=function() end
local syncMaterials=function() end
local syncLayers=function() end
local liveButton,uploadButton,junctionButton

local function setLive(enabled)
    liveEnabled=enabled
    previewDue=enabled and os.clock()+0.35 or nil
    if liveButton then liveButton.Text=T(enabled and "Auto preview: ON" or "Auto preview: OFF") end
end
local function clearMeshPreview()
    previewRevision+=1
    if liveEnabled then previewDue=os.clock()+0.35 end
    if previewFolder then previewFolder:Destroy(); previewFolder=nil end
    for _,m in ipairs(previewMeshes) do m:Destroy() end
    previewMeshes={}
end
local function resetUpload()
    uploadArmed=false
    if uploadButton then uploadButton.Text=T("Authorize mesh uploads for next Generate: OFF") end
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
local MODE_HELP={
    add="Click surfaces to add points. Switch to Move to drag nodes.",
    insert="Click a surface to insert a node after the selected node.",
    move="Drag a blue node. Use coordinate fields for exact XYZ.",
    brush="Click or drag in the viewport to paint scatter assets.",
    erase="Click or drag in the viewport to erase scatter assets.",
}
local function startMode(m)
    editAllowed(); mode=m; plugin:Activate(true); syncHandles(); say(MODE_HELP[m])
end
-- Scatter output and brush strokes (filled in by the Layers tab).
local scatterBox=nil
local brush={active=false,begin=function() end,paint=function() end,finish=function() end}

-- Generator fields <-> current stack entry.
local NUMBER_KEYS={"width","height","spacing","step","offset","yaw","roll","sides","uvLength","uvWidth","angle","tolerance"}
local function storeFields()
    local e=entry()
    local o=table.clone(e.o)
    for _,k in ipairs(NUMBER_KEYS) do local spec=P.NUMBERS[k]; o[k]=number(k,spec[1],spec[2]) end
    o.profile=fields.profile.Text
    e.o=P.validate(o)
end
local function loadFields()
    local o=entry().o
    for _,k in ipairs(NUMBER_KEYS) do fields[k].Text=tostring(o[k]) end
    fields.profile.Text=o.profile
end
local function applyDefaults()
    local o=entry().o
    for k,v in pairs(P.DEFAULTS[o.preset]) do o[k]=v end
    loadFields()
end

-- Draft guides ---------------------------------------------------------------
local function guidePart(parent,name,cf,size,color)
    local p=Instance.new("Part")
    p.Name=name; p.Size=size; p.CFrame=cf
    p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.CastShadow=false; p.Archivable=false
    p.Material=Enum.Material.Neon; p.Color=color; p.Parent=parent
    return p
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
                local cf,len=P.axisCF(a,b,Vector3.yAxis)
                if cf then
                    used+=1
                    local part=draftGuides[used]
                    if not part then
                        draftGuides[used]=guidePart(preview,"Guide",cf,Vector3.new(0.1,0.1,len+0.04),Color3.fromRGB(66,187,216))
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
            node=guidePart(preview,"Node_"..i,CFrame.new(pos),Vector3.new(0.65,0.65,0.65),color)
            node.Shape=Enum.PartType.Ball; node.CanQuery=true
            node:SetAttribute("NodeIndex",i); draftNodes[i]=node
        else node.CFrame=CFrame.new(pos); node.Color=color end
    end
    for i=#draftNodes,#points+1,-1 do draftNodes[i]:Destroy(); draftNodes[i]=nil end
    syncHandles()
end

-- Header / tabs --------------------------------------------------------------
local title=label("PATHFORGE   /   "..Version.SHORT,28)
title.Font=Enum.Font.GothamBold; title.TextSize=19
ui.tabBar({"Path","Shape","Layers","Library","Build"})
status=label("Create a path or load a saved PathForge model.",46)

-- 01 Path --------------------------------------------------------------------
ui.section="Path"
label("01   PATH / CONTROL POINTS",22,C.muted)
local pointLabel=label("0 points",22)
local function resetDraft()
    root=nil; loadedPivot=nil; loadedMeta=nil; loadedOutput=nil
    draftHistory:clear()
    entries={newEntry("Rail")}; current=1; loadFields()
    repeatLayers={}; layerIndex=0; syncLayers(); resetUpload()
    points={}; selected=0; materialSlot=1; junctionsOn=true
    syncMaterials(); syncButtons(); refreshLabel(); refreshPreview()
end
button("New path / clear draft",guarded(function() editAllowed(); stopMode(); resetDraft(); say("New draft. Existing generated models are unchanged.") end))
button("Add points in viewport",guarded(function() startMode("add") end),true)
button("Move nodes by dragging",guarded(function() startMode("move") end))
button("Insert node after selected",guarded(function() assert(selected>0,"Select a node first"); startMode("insert") end))
button("Stop viewport editing",function() stopMode(); say("Viewport released; draft kept.") end)
row({
    {"Previous node",function() if #points>0 then selected=(selected-2)%#points+1; refreshLabel(); refreshPreview() end end},
    {"Next node",function() if #points>0 then selected=selected%#points+1; refreshLabel(); refreshPreview() end end},
})
input("x","Selected X",0); input("y","Selected Y",0); input("z","Selected Z",0)
input("grid","Placement grid (0 = off)",0)
input("plane","Empty-space plane Y",0)
refreshLabel=function()
    pointLabel.Text=T(string.format("%d points   |   Node %d   |   %s",#points,selected,root and "Editing saved path" or "New path"))
    local p=points[selected]
    if p then for k,v in pairs({x=p.X,y=p.Y,z=p.Z}) do fields[k].Text=string.format("%.3f",v) end end
end
button("Apply selected XYZ",guarded(function() editAllowed(); assert(points[selected],"Select a node first"); remember(); points[selected]=Vector3.new(number("x",-100000,100000),number("y",-100000,100000),number("z",-100000,100000)); refreshPreview(); refreshLabel() end))
local deleteNode=guarded(function() editAllowed(); if points[selected] then remember(); table.remove(points,selected); selected=math.min(selected,#points); refreshLabel(); refreshPreview() end end)
button("Delete selected node",deleteNode)
local function restoreDraft(state)
    points=state.points; selected=math.min(state.selected,#points)
    refreshLabel(); refreshPreview()
end
local function undoDraft()
    local s=draftHistory:undo({points=points,selected=selected})
    if s then restoreDraft(s); say("Draft edit undone.") else say("Nothing to undo in the draft.") end
end
local function redoDraft()
    local s=draftHistory:redo({points=points,selected=selected})
    if s then restoreDraft(s); say("Draft edit redone.") else say("Nothing to redo in the draft.") end
end
row({{"Undo draft edit",guarded(function() editAllowed(); undoDraft() end)},{"Redo draft edit",guarded(function() editAllowed(); redoDraft() end)}})
local smoothButton=button("Curve: Smooth spline",function() smooth=not smooth; syncButtons(); refreshPreview() end)
label("01B  TERRAIN",22,C.muted)
input("drapeOffset","Height above ground (studs)",0.5)
input("drapeSpacing","Drape resample spacing (0 = keep points)",0)
-- Ground height under (x, z): terrain first, then any non-PathForge surface.
local function groundAt(x,z)
    local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Exclude
    local exclude={}; if preview then exclude[#exclude+1]=preview end; if root and root.Parent then exclude[#exclude+1]=root end
    if scatterBox and scatterBox.Parent then exclude[#exclude+1]=scatterBox end
    rp.FilterDescendantsInstances=exclude
    local hit=workspace:Raycast(Vector3.new(x,10000,z),Vector3.new(0,-20000,0),rp)
    return hit and hit.Position.Y or nil
end
button("Drape points onto ground",guarded(function()
    editAllowed(); assert(#points>=1,"Add at least two points")
    local offset=number("drapeOffset",-50,100)
    local spacing=number("drapeSpacing",0,1000)
    local out,hit
    if spacing>0 then
        assert(#points>=2,"Add at least two points")
        out,hit=TerrainPlan.resample(pathFor(),spacing,groundAt,offset,MAX_POINTS)
    else
        out,hit=TerrainPlan.drape(points,groundAt,offset)
    end
    if hit>0 then
        remember()
        points=out; selected=math.min(math.max(selected,1),#points); refreshLabel(); refreshPreview()
    end
    say(string.format("Draped %d of %d points onto the ground.",hit,#points),hit==0)
end))
input("terrainShoulder","Terrain shoulder each side (studs)",2)
input("terrainDepth","Fill depth below path (studs)",6)
input("terrainClear","Clear height above path (studs)",12)
local terrainMaterial="Ground"
local terrainMaterialButton=button("Fill material: Ground",function()
    terrainMaterial=TerrainPlan.MATERIALS[(table.find(TerrainPlan.MATERIALS,terrainMaterial) or 1)%#TerrainPlan.MATERIALS+1]
end)
terrainMaterialButton.Activated:Connect(function() terrainMaterialButton.Text=T("Fill material: "..terrainMaterial) end)
button("Fill and carve terrain along path",guarded(function()
    editAllowed(); storeFields()
    local terrain=workspace:FindFirstChildOfClass("Terrain")
    assert(terrain,"This place has no Terrain")
    local width
    for _,e in ipairs(entries) do if e.enabled then width=math.max(width or 0,e.o.width) end end
    local path=pathFor()
    local plan=TerrainPlan.plan(path,{width=width or 4,shoulder=number("terrainShoulder",0,100),depth=number("terrainDepth",0,200),
        clear=number("terrainClear",0,200),step=4,offset=0})
    local rec=History:TryBeginRecording("PathForgeTerrain","PathForge: Terrain along path")
    assert(rec,"Cannot start Studio undo recording. Try again.")
    local ok,err=pcall(function()
        for _,b in ipairs(plan.carve) do terrain:FillBlock(b.cf,b.size,Enum.Material.Air) end
        for _,b in ipairs(plan.fill) do terrain:FillBlock(b.cf,b.size,Enum.Material[terrainMaterial]) end
    end)
    History:FinishRecording(rec,ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
    if not ok then error(err,0) end
    say(string.format("Terrain: %d fill and %d carve blocks. Undo reverts it in one step.",#plan.fill,#plan.carve))
end))
label("01A  BRANCHES",22,C.muted)
input("snapRadius","Branch snap radius (studs)",4)
button("Snap path ends onto nearby paths",guarded(function()
    editAllowed(); assert(#points>=2,"Add at least two points")
    local paths={}
    for _,other in ipairs(savedPaths(false)) do paths[#paths+1]=other.path end
    local snapped,n=Network.snapEnds(points,paths,number("snapRadius",0.1,100))
    if n>0 then remember() end
    points=snapped; refreshLabel(); refreshPreview()
    say(n>0 and string.format("Snapped %d path end(s). Generate to build the branch.",n) or "No other path within the snap radius.",n==0)
end))

local function hitPosition(planeY)
    local ray=mouse.UnitRay
    local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Exclude
    local exclude={}; if preview then exclude[#exclude+1]=preview end; if root and root.Parent then exclude[#exclude+1]=root end
    if scatterBox and scatterBox.Parent then exclude[#exclude+1]=scatterBox end
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
    if p and (p-old).Magnitude>0.001 then points[selected]=p; refreshLabel(); refreshPreview() end
end
mouse.Button1Down:Connect(guarded(function()
    if axisStart or not mode or not widget.Enabled or RunService:IsRunning() then return end
    local target=mouse.Target
    if target and preview and target.Parent==preview and target:GetAttribute("NodeIndex") then
        selected=target:GetAttribute("NodeIndex"); dragging=mode=="move"; if dragging then remember() end; refreshLabel(); refreshPreview(); return
    end
    if mode=="brush" or mode=="erase" then brush.begin(); return end
    if mode=="add" or mode=="insert" then
        assert(#points<MAX_POINTS,"Maximum 128 points")
        local p=hitPosition(number("plane",-100000,100000))
        if p then
            remember()
            if mode=="insert" and selected>0 then selected+=1; table.insert(points,selected,p) else points[#points+1]=p; selected=#points end
            refreshLabel(); refreshPreview()
        end
    end
end))
mouse.Move:Connect(guarded(function()
    if dragging and os.clock()-lastMove>0.05 then lastMove=os.clock(); movePoint() end
    if brush.active and os.clock()-lastMove>0.08 then lastMove=os.clock(); brush.paint() end
end))
mouse.Button1Up:Connect(guarded(function()
    if dragging then dragging=false; movePoint() end
    if brush.active then brush.finish() end
end))
plugin.Deactivation:Connect(function() mode=nil; dragging=false; axisStart=nil; if brush.active then brush.finish() end; syncHandles() end)
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
            dragging=false; axisNode=selected; axisStart=points[selected]; remember()
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

-- 02 Shape: generator stack ----------------------------------------------------
ui.section="Shape"
label("02   GENERATOR STACK",22,C.muted)
local stackLabel=label("Generator 1 / 1  |  Rail",24)
local function switchTo(i)
    storeFields(); current=i; materialSlot=1; loadFields(); resetUpload(); clearMeshPreview(); syncMaterials(); syncButtons()
end
row({
    {"Previous generator",guarded(function() if #entries>1 then switchTo((current-2)%#entries+1) end end)},
    {"Next generator",guarded(function() if #entries>1 then switchTo(current%#entries+1) end end)},
})
row({
    {"Add generator",guarded(function()
        assert(#entries<Persist.MAX_GENERATORS,"Maximum 8 generators per path")
        storeFields()
        local copy={o=table.clone(entry().o),source=entry().source,styles=table.clone(entry().styles),enabled=true}
        table.insert(entries,current+1,copy); switchTo(current+1)
        say("Generator added. Pick its type and settings; all generators share this path.")
    end)},
    {"Remove generator",guarded(function()
        assert(#entries>1,"A path needs at least one generator")
        table.remove(entries,current); current=math.min(current,#entries); materialSlot=1
        loadFields(); resetUpload(); clearMeshPreview(); syncMaterials(); syncButtons()
    end)},
})
local enabledGenButton=button("Generator enabled: ON",function()
    local e=entry(); e.enabled=not e.enabled; clearMeshPreview(); syncButtons()
end)
label("02A  GENERATOR TYPE / PARAMETERS",22,C.muted)
local presetChoices={}
for r=0,1 do
    local list={}
    for col=1,4 do
        local name=P.LIST[r*4+col]
        list[col]={name,function()
            local e=entry()
            if e.o.preset==name then return end
            e.o.preset=name
            if name=="Extrude" then e.source=nil end
            materialSlot=1; resetUpload(); applyDefaults(); syncButtons(); syncMaterials(); clearMeshPreview()
        end}
    end
    for col,b in ipairs(row(list,29)) do presetChoices[P.LIST[r*4+col]]=b end
end
local collisionButton=button("Collision: ON",function() local o=entry().o; o.collide=not o.collide; clearMeshPreview(); syncButtons() end)
input("width","Width / rail gauge / diameter",3.2)
input("height","Height / base elevation",0.2)
input("spacing","Asset / sleeper / post spacing",1.8)
input("step","Segment size (studs)",1)
input("offset","Vertical offset (studs)",0)
input("yaw","Custom yaw (degrees)",0)
input("roll","Roll (degrees)",0)
label("02B  EXTRUDE / MESH QUALITY",22,C.muted)
input("profile","Profile (rectangle / circle / arch / x,y;...)","rectangle")
input("sides","Circle / arch subdivisions",16)
input("uvLength","UV length per tile",4)
input("uvWidth","UV perimeter per tile",4)
input("angle","Max turn per segment (degrees)",8)
input("tolerance","Chord tolerance (studs)",0.05)
local fidelityButton
fidelityButton=button("Mesh collision: Default",function()
    local o=entry().o
    o.fidelity=P.FIDELITY[(table.find(P.FIDELITY,o.fidelity) or 1)%#P.FIDELITY+1]
    syncButtons(); clearMeshPreview()
end)
local assetLabel=label("Asset: none (Custom preset only)",30,C.muted)
local function pickSource(kind)
    editAllowed()
    local a=Selection:Get()[1]; Assets.count(a); assert(a.Parent,"Select an existing asset")
    assert(not preview or (a~=preview and not a:IsDescendantOf(preview)),"Do not use preview objects")
    assert(not root or (a~=root and not a:IsDescendantOf(root)),"Choose a source outside the active generated path")
    if kind~="Custom" then assert(a:IsA("MeshPart"),"Select a single MeshPart") end
    local e=entry(); e.source=a
    if e.o.preset~=kind then e.o.preset=kind; applyDefaults() end
    materialSlot=1; resetUpload(); clearMeshPreview(); syncButtons(); syncMaterials()
end
button("Use selected Model as custom asset",guarded(function() pickSource("Custom"); say("Asset selected. A reusable snapshot is stored when generated.") end))
button("Use selected MeshPart / Deform",guarded(function() pickSource("Deform"); say("Deform uses the full path length, local -Z forward. Dense mesh required.") end))
button("Use selected MeshPart appearance / Extrude",guarded(function() pickSource("Extrude"); say("Extrude copies selected mesh appearance, not its geometry.") end))
button("Clear source / use Extrude material slot",guarded(function()
    local e=entry(); e.source=nil
    if e.o.preset~="Extrude" then e.o.preset="Extrude"; applyDefaults() end
    resetUpload(); syncButtons(); syncMaterials(); clearMeshPreview()
end))

label("02C  MATERIAL SLOTS",22,C.muted)
local slotButton=button("Material slot: RailFoot",function()
    local slots=P.SLOTS[entry().o.preset]
    if #slots>0 then materialSlot=materialSlot%#slots+1; syncMaterials() end
end)
local styleLabel=label("Preset default (no override)",34,C.muted)
syncMaterials=function()
    local slots=P.SLOTS[entry().o.preset]
    local name=slots[materialSlot]
    slotButton.Text=T(name and ("Material slot: "..name) or "No material slots for this generator")
    local style=name and entry().styles[name]
    styleLabel.Text=T(style and (style.material.." / "..(style.variant~="" and style.variant or "default").." / "..#style.textures.." textures") or "Preset default (no override)")
end
button("Capture material from selected part",guarded(function()
    editAllowed()
    local name=assert(P.SLOTS[entry().o.preset][materialSlot],"No material slots for this generator")
    local s=Selection:Get()[1]
    assert(not preview or not s or not s:IsDescendantOf(preview),"Select a real source part")
    entry().styles[name]=Materials.capture(s); clearMeshPreview()
    syncMaterials(); say("Material slot captured. Generate to apply.")
end),true)
row({
    {"Reset material slot",function() local name=P.SLOTS[entry().o.preset][materialSlot]; if name then entry().styles[name]=nil end; clearMeshPreview(); syncMaterials() end},
    {"Reset all material slots",function() entry().styles={}; clearMeshPreview(); syncMaterials() end},
})
syncButtons=function()
    local e=entry()
    stackLabel.Text=T(string.format("Generator %d / %d  |  %s",current,#entries,e.o.preset))
    for name,b in pairs(presetChoices) do b.BackgroundColor3=name==e.o.preset and C.accent or C.panel end
    enabledGenButton.Text=T(e.enabled and "Generator enabled: ON" or "Generator enabled: OFF")
    smoothButton.Text=T(smooth and "Curve: Smooth spline" or "Curve: Straight segments")
    collisionButton.Text=T(e.o.collide and "Collision: ON" or "Collision: OFF")
    fidelityButton.Text=T("Mesh collision: "..e.o.fidelity)
    assetLabel.Text=T(e.source and ("Asset: "..e.source.Name) or "Asset: none (Custom / Deform)")
    if not hasMeshEntry() then resetUpload() end
    if junctionButton then junctionButton.Text=T(junctionsOn and "Road junctions: ON" or "Road junctions: OFF") end
end

-- 03 Layers ------------------------------------------------------------------
ui.section="Layers"
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
    editAllowed(); local a=Selection:Get()[1]; Assets.count(a); assert(a.Parent,"Select an existing asset")
    assert(not preview or (a~=preview and not a:IsDescendantOf(preview)),"Do not use preview objects")
    assert(not root or (a~=root and not a:IsDescendantOf(root)),"Do not use the active generated path")
    assert(#repeatLayers<Layers.MAX_LAYERS,"Maximum 12 repeat layers")
    repeatLayers[#repeatLayers+1]={source=a,spacing=5,side=0,height=0,yaw=0,roll=0,enabled=true,collide=true}
    layerIndex=#repeatLayers; syncLayers(); clearMeshPreview()
end),true)
row({
    {"Previous layer",function() if #repeatLayers>0 then layerIndex=(layerIndex-2)%#repeatLayers+1; syncLayers() end end},
    {"Next layer",function() if #repeatLayers>0 then layerIndex=layerIndex%#repeatLayers+1; syncLayers() end end},
})
button("Apply layer settings",guarded(function()
    local l=assert(repeatLayers[layerIndex],"Select a layer")
    local nextLayer=table.clone(l)
    nextLayer.spacing=number("layerSpacing",0.2,200); nextLayer.side=number("layerSide",-1000,1000)
    nextLayer.height=number("layerHeight",-1000,1000); nextLayer.yaw=number("layerYaw",-360,360); nextLayer.roll=number("layerRoll",-360,360)
    Layers.validate(nextLayer); repeatLayers[layerIndex]=nextLayer; clearMeshPreview(); say("Layer settings applied to draft.")
end),true)
local toggles=row({
    {"Layer enabled: —",function() local l=repeatLayers[layerIndex]; if l then l.enabled=not l.enabled; syncLayers(); clearMeshPreview() end end},
    {"Layer collision: —",function() local l=repeatLayers[layerIndex]; if l then l.collide=not l.collide; syncLayers(); clearMeshPreview() end end},
})
enabledButton,layerCollisionButton=toggles[1],toggles[2]
button("Remove selected layer",guarded(function()
    if repeatLayers[layerIndex] then table.remove(repeatLayers,layerIndex); layerIndex=math.min(layerIndex,#repeatLayers); syncLayers(); clearMeshPreview() end
end))
label("Each layer repeats its own source model along the same spline. Apply layer settings before preview or generation.",58,C.muted)
label("03B  SCATTER / BRUSH",22,C.muted)
local scatterPool={}
local poolLabel=label("Scatter assets: none",24)
input("scatterBand","Scatter band each side (studs)",20)
input("scatterGap","Keep clear of path center (studs)",8)
input("scatterDensity","Density (per 100 square studs)",1)
input("scatterMin","Minimum distance between assets",4)
input("scatterScaleMin","Random scale min",0.8)
input("scatterScaleMax","Random scale max",1.2)
input("scatterSeed","Random seed",1)
input("brushRadius","Brush radius (studs)",12)
local function scatterOptions()
    local o={band=number("scatterBand",0.1,500),gap=number("scatterGap",0,500),density=number("scatterDensity",0.001,100),
        minDistance=number("scatterMin",0,100),scaleMin=number("scatterScaleMin",0.05,20),scaleMax=number("scatterScaleMax",0.05,20),
        seed=number("scatterSeed",0,1e9)}
    Scatter.validate(o)
    return o
end
-- One "PathForge Scatter" model per place collects everything scattered or painted.
local function scatterContainer(create)
    if scatterBox and scatterBox.Parent==workspace then return scatterBox end
    for _,c in ipairs(workspace:GetChildren()) do
        if c:IsA("Model") and c:GetAttribute("PathForgeScatter")==1 then scatterBox=c; return c end
    end
    if not create then return nil end
    scatterBox=Instance.new("Model"); scatterBox.Name="PathForge Scatter"; scatterBox:SetAttribute("PathForgeScatter",1)
    scatterBox.Parent=workspace
    return scatterBox
end
local function scatterPositions(box)
    local out={}
    for _,c in ipairs(box and box:GetChildren() or {}) do out[#out+1]=c:GetPivot().Position end
    return out
end
local function place(box,items,seed)
    assert(#scatterPool>0,"Pick scatter assets first")
    local rng=Scatter.rng(seed)
    for _,it in ipairs(items) do
        local p=it.position
        local y=groundAt(p.X,p.Z)
        if y then p=Vector3.new(p.X,y,p.Z) end
        local c=Assets.clone(scatterPool[Scatter.pick(rng,#scatterPool)])
        if c:IsA("Model") then c:ScaleTo(it.scale) else c.Size*=it.scale end
        c:PivotTo(CFrame.new(p)*CFrame.Angles(0,math.rad(it.yaw),0))
        Assets.configure(c,true,false)
        c.Parent=box
    end
end
button("Use selected models as scatter assets",guarded(function()
    editAllowed()
    local pool={}
    for _,a in ipairs(Selection:Get()) do
        Assets.count(a)
        assert(not preview or (a~=preview and not a:IsDescendantOf(preview)),"Do not use preview objects")
        pool[#pool+1]=a
    end
    assert(#pool>0,"Select one or more models")
    scatterPool=pool
    local names={}
    for _,a in ipairs(pool) do names[#names+1]=a.Name end
    poolLabel.Text=T("Scatter assets: "..table.concat(names,", "))
end))
button("Scatter along path",guarded(function()
    editAllowed(); assert(#scatterPool>0,"Pick scatter assets first")
    local o=scatterOptions()
    local path=pathFor()
    local rec=History:TryBeginRecording("PathForgeScatter","PathForge: Scatter along path")
    assert(rec,"Cannot start Studio undo recording. Try again.")
    local created
    local ok,err=pcall(function()
        created=not scatterContainer(false)
        local box=scatterContainer(true)
        local items=Scatter.along(path,o,scatterPositions(box))
        place(box,items,o.seed)
        say(string.format("Scattered %d assets. Undo removes them in one step.",#items))
    end)
    if not ok and created and scatterBox then scatterBox:Destroy(); scatterBox=nil end
    History:FinishRecording(rec,ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
    if not ok then error(err,0) end
end),true)
row({
    {"Brush: paint",guarded(function() assert(#scatterPool>0,"Pick scatter assets first"); scatterOptions(); startMode("brush") end)},
    {"Brush: erase",guarded(function() startMode("erase") end)},
})
local strokeRecording,strokeCount,strokeSeed=nil,0,0
brush.begin=function()
    strokeRecording=History:TryBeginRecording("PathForgeBrush",mode=="erase" and "PathForge: Erase scatter" or "PathForge: Paint scatter")
    assert(strokeRecording,"Cannot start Studio undo recording. Try again.")
    brush.active=true; strokeCount=0; strokeSeed+=1
    local ok,err=pcall(brush.paint)
    if not ok then
        brush.active=false
        History:FinishRecording(strokeRecording,Enum.FinishRecordingOperation.Cancel); strokeRecording=nil
        error(err,0)
    end
end
brush.paint=function()
    local center=hitPosition(number("plane",-100000,100000))
    if not center then return end
    local radius=number("brushRadius",0.5,200)
    if mode=="erase" then
        local box=scatterContainer(false)
        if not box then return end
        local children=box:GetChildren()
        for _,i in ipairs(Scatter.erase(scatterPositions(box),center,radius)) do children[i]:Destroy(); strokeCount+=1 end
    else
        local o=scatterOptions()
        local box=scatterContainer(true)
        local items=Scatter.brush(center,radius,o,scatterPositions(box),o.seed+strokeSeed*7919+strokeCount)
        place(box,items,o.seed+strokeSeed)
        strokeCount+=#items
    end
end
brush.finish=function()
    brush.active=false
    if strokeRecording then History:FinishRecording(strokeRecording,Enum.FinishRecordingOperation.Commit); strokeRecording=nil end
    say(string.format(mode=="erase" and "Erased %d assets." or "Painted %d assets.",strokeCount))
end
label("Scattered and painted assets go into the PathForge Scatter model. Each scatter or brush stroke is one undo step.",44,C.muted)

-- 05 Library ----------------------------------------------------------------
ui.section="Library"
-- Library edits change ServerStorage, so each one is a single Studio undo step.
local function recorded(name,fn)
    editAllowed()
    local rec=History:TryBeginRecording("PathForgeLibrary",name)
    assert(rec,"Cannot start Studio undo recording. Try again.")
    local ok,err=pcall(fn)
    History:FinishRecording(rec,ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
    if not ok then error(err,0) end
end
local libIndex={material=1,asset=1,recipe=1}
local materialLabel,assetLibLabel,recipeLabel
local function libLists()
    return Library.materials(Storage),Library.assets(Storage),Library.recipes(Storage)
end
local function syncLibrary()
    local mats,assets,recipes=libLists()
    for key,list in pairs({material=mats,asset=assets,recipe=recipes}) do
        libIndex[key]=#list>0 and math.clamp(libIndex[key],1,#list) or 0
    end
    local m=mats[libIndex.material]
    materialLabel.Text=m and string.format("%d / %d  |  %s%s",libIndex.material,#mats,T(m.name),m.builtin and "" or " ★") or T("Library is empty")
    local a=assets[libIndex.asset]
    assetLibLabel.Text=a and string.format("%d / %d  |  %s",libIndex.asset,#assets,a.Name) or T("Library is empty")
    local r=recipes[libIndex.recipe]
    recipeLabel.Text=r and string.format("%d / %d  |  %s",libIndex.recipe,#recipes,r.Name) or T("No saved recipes")
end
local function step(key,delta)
    local mats,assets,recipes=libLists()
    local n=#({material=mats,asset=assets,recipe=recipes})[key]
    if n>0 then libIndex[key]=(libIndex[key]-1+delta)%n+1 end
    syncLibrary()
end
label("05   LIBRARY / SAVED WITH THIS PLACE",22,C.muted)
input("libName","Name for saving",""):SetAttribute("NoPreviewReset",true)
label("05A  MATERIALS",22,C.muted)
materialLabel=label("Library is empty",24)
row({{"Previous material",function() step("material",-1) end},{"Next material",function() step("material",1) end}})
button("Apply material to current slot",guarded(function()
    local mats=libLists()
    local m=assert(mats[libIndex.material],"Library is empty")
    local slot=assert(P.SLOTS[entry().o.preset][materialSlot],"No material slots for this generator")
    entry().styles[slot]=table.clone(m.style); clearMeshPreview(); syncMaterials()
    say("Material applied to the current slot. Generate to apply.")
end),true)
button("Save current slot to library",guarded(function()
    local slot=assert(P.SLOTS[entry().o.preset][materialSlot],"No material slots for this generator")
    local style=assert(entry().styles[slot],"Capture or apply a material to this slot first")
    recorded("PathForge: Save material",function() Library.saveMaterial(Storage,fields.libName.Text,style) end)
    syncLibrary(); say("Saved to the library.")
end))
label("05B  ASSETS",22,C.muted)
assetLibLabel=label("Library is empty",24)
row({{"Previous asset",function() step("asset",-1) end},{"Next asset",function() step("asset",1) end}})
button("Add selected model to library",guarded(function()
    local a=Selection:Get()[1]
    assert(not preview or not a or (a~=preview and not a:IsDescendantOf(preview)),"Do not use preview objects")
    local name=fields.libName.Text~="" and fields.libName.Text or (a and a.Name)
    recorded("PathForge: Add asset",function() Library.addAsset(Storage,a,name) end)
    syncLibrary(); say("Saved to the library.")
end))
row({
    {"Use as Custom asset",guarded(function()
        local _,assets=libLists(); local a=assert(assets[libIndex.asset],"Library is empty")
        local e=entry(); e.source=a
        if e.o.preset~="Custom" then e.o.preset="Custom"; applyDefaults() end
        materialSlot=1; resetUpload(); clearMeshPreview(); syncButtons(); syncMaterials()
        say("Asset selected. A reusable snapshot is stored when generated.")
    end)},
    {"Add as repeat layer",guarded(function()
        local _,assets=libLists(); local a=assert(assets[libIndex.asset],"Library is empty")
        assert(#repeatLayers<Layers.MAX_LAYERS,"Maximum 12 repeat layers")
        repeatLayers[#repeatLayers+1]={source=a,spacing=5,side=0,height=0,yaw=0,roll=0,enabled=true,collide=true}
        layerIndex=#repeatLayers; syncLayers(); clearMeshPreview()
        say("Layer added. Adjust it in the Layers tab.")
    end)},
})
label("05C  RECIPES (GENERATORS + LAYERS, NO POINTS)",22,C.muted)
recipeLabel=label("No saved recipes",24)
row({{"Previous recipe",function() step("recipe",-1) end},{"Next recipe",function() step("recipe",1) end}})
button("Save current setup as recipe",guarded(function()
    storeFields()
    recorded("PathForge: Save recipe",function() Library.saveRecipe(Storage,fields.libName.Text,entries,repeatLayers,smooth) end)
    syncLibrary(); say("Saved to the library.")
end),true)
button("Load recipe into draft",guarded(function()
    local _,_,recipes=libLists(); local r=assert(recipes[libIndex.recipe],"No saved recipes")
    local loadedEntries,loadedLayers,loadedSmooth=Library.loadRecipe(r)
    entries=loadedEntries; current=1; materialSlot=1
    repeatLayers=loadedLayers; layerIndex=#repeatLayers>0 and 1 or 0
    smooth=loadedSmooth
    loadFields(); resetUpload(); clearMeshPreview(); syncLayers(); syncMaterials(); syncButtons(); refreshPreview()
    say("Recipe loaded into the draft. Points are unchanged; Generate to apply.")
end))
label("Materials, assets and recipes are stored in ServerStorage > PathForgeLibrary and travel with this place. ★ marks your own materials.",58,C.muted)

-- Commit / load ----------------------------------------------------------------
local function stageRoadUpdate(layout)
    local road=layout.road
    local entries={}
    for i,e in ipairs(road.entries) do
        entries[i]=e.o.preset=="Road" and e or {o=e.o,enabled=false}
    end
    local removed,retained={},0
    for _,child in ipairs(road.output:GetChildren()) do
        if child.Name=="Junctions" or child.Name:match("^G%d%d_Road$") then
            removed[#removed+1]=child
        else
            if child:IsA("BasePart") then retained+=1 end
            for _,descendant in ipairs(child:GetDescendants()) do
                if descendant:IsA("BasePart") then retained+=1 end
            end
        end
    end
    local staged=Builder.stack(road.path,entries,{budget=MAX_PARTS-retained,cache=specCache,
        junctions=layout.junctions,junctionPads=layout.pads})
    return {road=road,staged=staged,removed=removed,added=staged:GetChildren()}
end

local function commit(allowUpload)
    editAllowed(); stopMode(); storeFields()
    local path=pathFor()
    local target=root
    local pivot=target and target:GetPivot() or CFrame.new(points[1])
    local oldGenerated,oldMeta
    local function checkTarget()
        assert(canContinue(),"Editor closed or play testing started")
        if target then
            assert(target:IsDescendantOf(workspace) and target:GetAttribute("PathForgeSchema")==1,"Saved path no longer exists")
            assert(target:FindFirstChild("Generated")==loadedOutput and target:FindFirstChild("PathData")==loadedMeta,"Path changed externally; reload before generating")
            assert(target:GetPivot()==loadedPivot,"Path was moved; reload it before generating")
        end
    end
    checkTarget()
    local output,meta,createdLibrary,recording,overlays,count
    local pending,snapshots,savedLayers,savedEntries={}, {}, {}, {}
    local roadUpdates={}
    local createdTarget=false
    local success,err=pcall(function()
        local library=Storage:FindFirstChild("PathForgeAssets")
        if library then assert(library:IsA("Folder"),"PathForgeAssets must be a Folder") end
        local function snapshot(a)
            Assets.count(a); assert(a.Parent,"Source asset was removed")
            assert(not target or (a~=target and not a:IsDescendantOf(target)),"Choose a source outside the active generated path")
            assert(not preview or (a~=preview and not a:IsDescendantOf(preview)),"Do not use preview objects")
            if library and a:IsDescendantOf(library) then return a end
            if snapshots[a] then return snapshots[a] end
            local clone=Assets.clone(a)
            clone.Name=a.Name.."_"..Http:GenerateGUID(false):sub(1,8)
            pending[#pending+1]=clone; snapshots[a]=clone
            return clone
        end
        for i,e in ipairs(entries) do
            local copy={o=table.clone(e.o),styles=e.styles,enabled=e.enabled,source=nil}
            local needs=e.o.preset=="Custom" or e.o.preset=="Deform"
            if e.source and (needs or e.o.preset=="Extrude") then
                if e.enabled then copy.source=snapshot(e.source) else copy.source=e.source end
            elseif needs and e.enabled then
                error(e.o.preset=="Custom" and "Select a custom asset for the Custom generator" or "Select a MeshPart for the Deform generator",0)
            end
            savedEntries[i]=copy
        end
        for i,l in ipairs(repeatLayers) do
            local copy=table.clone(l)
            if l.source then copy.source=snapshot(l.source) else assert(not l.enabled,"Enabled layer has a missing source") end
            savedLayers[i]=copy
        end
        local layerCount
        overlays,layerCount=Layers.build(path,savedLayers,Assets.count,Assets.clone,MAX_PARTS,false)
        local layout,neighbors=junctionPlan(path,savedEntries,true)
        for _,neighbor in ipairs(neighbors) do roadUpdates[#roadUpdates+1]=stageRoadUpdate(neighbor) end
        output,count=Builder.stack(path,savedEntries,{preview=false,allowUpload=allowUpload,canContinue=canContinue,
            budget=MAX_PARTS-layerCount,cache=specCache,junctions=layout.junctions,junctionPads=layout.pads})
        output.Name="Generated"
        overlays.Parent=output; count+=layerCount
        checkTarget()
        for _,update in ipairs(roadUpdates) do
            local r=update.road
            assert(r.model:IsDescendantOf(workspace) and r.model:FindFirstChild("Generated")==r.output
                and r.model:FindFirstChild("PathData")==r.meta and r.model:GetPivot()==r.pivot,
                "Path changed externally; reload before generating")
            for _,child in ipairs(update.removed) do
                assert(child.Parent==r.output,"Path changed externally; reload before generating")
            end
        end
        meta=Instance.new("Folder"); meta.Name="PathData"
        Persist.write(meta,{points=points,smooth=smooth,entries=savedEntries,layers=savedLayers,junctions=junctionsOn},pivot)
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
            target.Name="PF_"..savedEntries[1].o.preset; target:SetAttribute("PathForgeSchema",1)
            target.WorldPivot=pivot
        else
            oldGenerated=target:FindFirstChild("Generated"); oldMeta=target:FindFirstChild("PathData")
            oldGenerated.Parent=nil; oldMeta.Parent=nil
            target.WorldPivot=pivot
        end
        output.Parent=target; meta.Parent=target
        if createdTarget then target.Parent=workspace end
        for _,update in ipairs(roadUpdates) do
            update.applied=true
            for _,child in ipairs(update.removed) do child.Parent=nil end
            for _,child in ipairs(update.added) do child.Parent=update.road.output end
        end
        History:FinishRecording(recording,Enum.FinishRecordingOperation.Commit)
        recording=nil
    end)
    if not success then
        for _,update in ipairs(roadUpdates) do
            if update.applied then
                for _,child in ipairs(update.added) do child.Parent=update.staged end
                for _,child in ipairs(update.removed) do child.Parent=update.road.output end
            end
            update.staged:Destroy()
        end
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
    for _,update in ipairs(roadUpdates) do update.staged:Destroy() end
    root=target; loadedPivot=target:GetPivot(); loadedMeta=meta; loadedOutput=output
    for i,e in ipairs(savedEntries) do entries[i].source=e.source end
    repeatLayers=savedLayers; syncLayers()
    Selection:Set({root}); refreshLabel(); syncButtons(); refreshPreview()
    say(string.format("Generated %d parts | %.1f studs. Saved path can be reloaded.",count,path.length))
end
local function loadSelected()
    editAllowed(); stopMode()
    local s=Selection:Get()[1]
    while s and s~=workspace and s:GetAttribute("PathForgeSchema")~=1 do s=s.Parent end
    assert(s and s~=workspace and s:GetAttribute("PathForgeSchema")==1,"Select a PathForge model or one of its parts")
    local meta=s:FindFirstChild("PathData"); assert(meta and s:FindFirstChild("Generated"),"Missing saved path data")
    local state=Persist.read(meta,s:GetPivot())
    repeatLayers=state.layers; layerIndex=#repeatLayers>0 and 1 or 0; syncLayers()
    resetUpload(); root=s; loadedPivot=s:GetPivot(); loadedMeta=meta; loadedOutput=s:FindFirstChild("Generated")
    draftHistory:clear(); points=state.points; selected=1; smooth=state.smooth; junctionsOn=state.junctions
    entries=state.entries; current=1; materialSlot=1; loadFields()
    syncMaterials(); syncButtons(); refreshLabel(); refreshPreview()
    say("Loaded saved path. Generate also refreshes junctions on connected roads.")
end

-- 04 Build -------------------------------------------------------------------
ui.section="Build"
label("04   BUILD / SAVED PATHS",22,C.muted)
local function previewNow(manual)
    if previewBusy or busy or not canContinue() then return end
    if #points<2 then if manual then say("Add at least two points",true) end; return end
    if not preview then refreshPreview() end
    clearMeshPreview(); previewDue=nil; resetUpload()
    local revision=previewRevision
    local function active() return revision==previewRevision and canContinue() end
    previewBusy=true
    local folder,meshes,overlays
    local ok,err=pcall(function()
        storeFields()
        local path=pathFor()
        local list={}
        for i,l in ipairs(repeatLayers) do list[i]=table.clone(l) end
        local layerCount,partCount
        overlays,layerCount=Layers.build(path,list,Assets.count,Assets.clone,1000,true)
        local layout=junctionPlan(path,entries,false)
        folder,partCount,meshes=Builder.stack(path,entries,{preview=true,canContinue=active,budget=PREVIEW_BUDGET,
            cache=specCache,junctions=layout.junctions,junctionPads=layout.pads})
        if not active() then return end
        folder.Name="Preview"; folder.Archivable=false
        overlays.Archivable=false; overlays.Parent=folder
        folder.Parent=preview
        previewFolder=folder; previewMeshes=meshes
        folder=nil; meshes=nil; overlays=nil
        if manual then say(string.format("Preview ready: %d parts, %d layer parts. Nothing was uploaded.",partCount,layerCount)) end
    end)
    if folder then folder:Destroy() end
    if meshes then for _,m in ipairs(meshes) do m:Destroy() end end
    if overlays then overlays:Destroy() end
    previewBusy=false
    if not ok and active() then say("Preview: "..tostring(err),true) end
end
local previewManual=guarded(function() editAllowed(); stopMode(); previewNow(true) end)
button("Preview now (no upload)",previewManual,true)
liveButton=row({
    {"Auto preview: OFF",guarded(function() editAllowed(); setLive(not liveEnabled); if not liveEnabled then clearMeshPreview() end end)},
    {"Clear preview",function() setLive(false); clearMeshPreview() end},
})[1]
junctionButton=button("Road junctions: ON",function() junctionsOn=not junctionsOn; clearMeshPreview(); syncButtons() end)
uploadButton=button("Authorize mesh uploads for next Generate: OFF",guarded(function()
    editAllowed(); assert(hasMeshEntry(),"Only mesh generators need an asset upload")
    setLive(false)
    uploadArmed=not uploadArmed
    uploadButton.Text=T(uploadArmed and "Authorize mesh uploads for next Generate: ON" or "Authorize mesh uploads for next Generate: OFF")
    say(uploadArmed and "Next Generate uploads every enabled mesh generator to Roblox under your account (long sweeps upload one mesh per chunk). Uploads may remain even after undo." or "Mesh upload disabled.")
end))
local generateNow=guarded(function()
    assert(not previewBusy,"Wait for preview to finish before generating")
    local authorized=uploadArmed
    setLive(false); resetUpload(); clearMeshPreview()
    say(authorized and "Generating… mesh uploads can take a while." or "Generating…")
    busy=true
    local ok,err=pcall(commit,authorized)
    busy=false
    if not ok then error(err,0) end
end)
button("Generate / update saved path",generateNow,true)
button("Load selected saved path",guarded(loadSelected))
button("Run geometry self-tests",guarded(function() editAllowed(); local n=SelfTest.run(); say(tostring(n).." geometry tests passed") end))
row({
    {"Hide draft guides",function() stopMode(); clearPreview(); say("Guides hidden. Draft retained.") end},
    {"Show draft guides",guarded(function() editAllowed(); refreshPreview() end)},
})
label("Generators share one path and are built in order. Custom repeats a model; Deform bends one static MeshPart; Extrude sweeps a profile. Generate commits; draft edits do not.",72,C.muted)

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
-- Plugin actions: bind keyboard shortcuts in File > Advanced > Customize Shortcuts.
local actions={
    {"PathForgeAdd","PathForge: Add points",guarded(function() widget.Enabled=true; startMode("add") end)},
    {"PathForgeMove","PathForge: Move nodes",guarded(function() widget.Enabled=true; startMode("move") end)},
    {"PathForgeStop","PathForge: Stop viewport editing",function() stopMode() end},
    {"PathForgeDelete","PathForge: Delete selected node",deleteNode},
    {"PathForgeUndo","PathForge: Undo draft edit",guarded(function() editAllowed(); undoDraft() end)},
    {"PathForgeRedo","PathForge: Redo draft edit",guarded(function() editAllowed(); redoDraft() end)},
    {"PathForgePreview","PathForge: Preview now",previewManual},
    {"PathForgeGenerate","PathForge: Generate / update",generateNow},
}
for _,a in ipairs(actions) do
    local ok,action=pcall(function() return plugin:CreatePluginAction(a[1],T(a[2]),T(a[2]),"",true) end)
    if ok and action then action.Triggered:Connect(function() if not busy then a[3]() end end) end
end
plugin.Unloading:Connect(function() unloading=true; if brush.active then brush.finish() end; resetUpload(); stopMode(); clearPreview(); if axisHandles then axisHandles:Destroy() end; runConnection:Disconnect() end)
for _,field in pairs(fields) do
    if not field:GetAttribute("NoPreviewReset") then field:GetPropertyChangedSignal("Text"):Connect(clearMeshPreview) end
end
ui.tabs.Library.Activated:Connect(syncLibrary)
loadFields(); syncButtons(); syncMaterials(); syncLayers(); syncLibrary(); ui.select("Path"); refreshLabel(); if widget.Enabled then refreshPreview() end
