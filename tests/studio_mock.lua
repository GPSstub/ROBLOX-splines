-- Fake Studio environment for loading Plugin.server.lua outside Roblox.
-- Buttons are clicked by their (English) text; the viewport is a mouse ray.
local M={}
local V=Vector3.new
function M.install()
    UDim=UDim or {new=function(s,o) return {Scale=s,Offset=o} end}
    UDim2=UDim2 or {new=function(a,b,c,d) return {a,b,c,d} end,fromScale=function(a,b) return {a,0,b,0} end,fromOffset=function(a,b) return {0,a,0,b} end}
    Vector2.zero=Vector2.new(0,0)
    Faces={new=function(...) return {...} end}
    DockWidgetPluginGuiInfo={new=function(...) return {...} end}
    RaycastParams={new=function() return {} end}
    task={spawn=function(fn,...) fn(...) end,wait=function() end,defer=function(fn,...) fn(...) end}
    warn=function() end
    Vector3.FromNormalId=function(n) local m={Right=V(1,0,0),Left=V(-1,0,0),Top=V(0,1,0),Bottom=V(0,-1,0),Front=V(0,0,-1),Back=V(0,0,1)}; return m[n.Name] end
    local env={}
    env.workspace=Instance.new("Model"); env.workspace.Name="Workspace"
    env.rayHit=nil -- set to a Vector3 to simulate a surface hit
    env.ground=nil -- function(x, z) -> height, used by downward rays (draping)
    env.workspace.Raycast=function(_,origin,dir)
        if env.ground and dir.Y<-1000 then
            local y=env.ground(origin.X,origin.Z)
            return y and {Position=V(origin.X,y,origin.Z)} or nil
        end
        return env.rayHit and {Position=env.rayHit} or nil
    end
    env.fills={}
    env.terrain=Instance.new("Terrain"); env.terrain.Name="Terrain"
    env.terrain.FillBlock=function(_,cf,size,material) env.fills[#env.fills+1]={cf=cf,size=size,material=material.Name} end
    env.terrain.Parent=env.workspace
    workspace=env.workspace
    env.storage=Instance.new("Folder"); env.storage.Name="ServerStorage"
    env.coreGui=Instance.new("Folder")
    env.selection={}
    env.recordings=0
    env.running=false
    local heartbeat=Signal.new()
    env.heartbeat=heartbeat
    local services={
        Selection={Get=function() return env.selection end,Set=function(_,list) env.selection=list end},
        ChangeHistoryService={TryBeginRecording=function() env.recordings+=1; return "rec"..env.recordings end,FinishRecording=function() end},
        RunService={IsRunning=function() return env.running end,Heartbeat=heartbeat},
        ServerStorage=env.storage,
        HttpService={GenerateGUID=function() return "abcdef12-0000" end},
        CoreGui=env.coreGui,
        StudioService={StudioLocaleId="en_us"},
        AssetService={},
    }
    game={GetService=function(_,name) return services[name] or {} end,CreatorId=0}
    env.mouse={UnitRay={Origin=V(0,50,0),Direction=V(0,-1,0)},Target=nil,
        Button1Down=Signal.new(),Button1Up=Signal.new(),Move=Signal.new()}
    env.widget=Instance.new("Folder"); env.widget.Enabled=false
    env.toolButton={Click=Signal.new(),SetActive=function() end}
    local active=false
    plugin={
        CreateToolbar=function() return {CreateButton=function() return env.toolButton end} end,
        CreateDockWidgetPluginGuiAsync=function() return env.widget end,
        GetMouse=function() return env.mouse end,
        Activate=function() active=true end, Deactivate=function() active=false end, IsActivated=function() return active end,
        Deactivation=Signal.new(), Unloading=Signal.new(),
    }
    function env.find(text,class)
        for _,d in ipairs(env.widget:GetDescendants()) do
            if (not class or d.ClassName==class) and d.Text==text then return d end
        end
        error("UI element not found: "..text,0)
    end
    function env.click(text) env.find(text,"TextButton").Activated:Fire() end
    function env.status()
        -- Status label is the third item in the scroll list (after title and tabs).
        for _,d in ipairs(env.widget:GetDescendants()) do
            if d.ClassName=="TextLabel" and d.LayoutOrder==3 then return d.Text end
        end
    end
    function env.setField(key,value)
        -- Inputs: a Frame row holding a TextLabel title and a TextBox.
        for _,d in ipairs(env.widget:GetDescendants()) do
            if d.ClassName=="Frame" then
                local title=d:FindFirstChild("TextLabel"); local box=d:FindFirstChild("TextBox")
                if title and box and title.Text==key then box.Text=tostring(value); return end
            end
        end
        error("field not found: "..key,0)
    end
    function env.clickViewport(pos) env.rayHit=pos; env.mouse.Target=nil; env.mouse.Button1Down:Fire() end
    function env.load()
        local fn=assert(load(PLUGIN_SOURCE,"@src/Plugin.server.lua"))
        fn()
        env.widget.Enabled=true
    end
    return env
end
return M
