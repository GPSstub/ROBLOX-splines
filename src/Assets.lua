-- Source asset checks and safe cloning (scripts, joints and prompts removed).
local A={}
local STRIP={"LuaSourceContainer","JointInstance","Constraint","WeldConstraint","ProximityPrompt","ClickDetector"}
-- Returns the number of BaseParts in a valid Model/BasePart source.
function A.count(a)
    assert(a and (a:IsA("Model") or a:IsA("BasePart")),"Select a Model or BasePart")
    assert(a.Archivable,"Asset must be Archivable")
    assert(not a:IsA("Terrain"),"Terrain cannot be used as a static asset")
    local count=a:IsA("BasePart") and 1 or 0
    for _,d in ipairs(a:GetDescendants()) do
        if d:IsA("BasePart") then count+=1; assert(d.Archivable,"All source BaseParts must be Archivable") end
    end
    assert(count>0,"Asset contains no BaseParts")
    return count
end
function A.clone(a)
    local c=a:Clone(); assert(c,"Cannot clone asset")
    for _,d in ipairs(c:GetDescendants()) do
        for _,class in ipairs(STRIP) do
            if d:IsA(class) then d:Destroy(); break end
        end
    end
    return c
end
-- Anchors every part of a placed clone; previews are also hidden from raycasts and saves.
function A.configure(c,collide,preview)
    local function set(part)
        part.Anchored=true; part.CanCollide=collide and not preview; part.CanTouch=false
        if preview then part.CanQuery=false; part.Archivable=false end
    end
    if c:IsA("BasePart") then set(c) end
    for _,d in ipairs(c:GetDescendants()) do if d:IsA("BasePart") then set(d) end end
end
return A
