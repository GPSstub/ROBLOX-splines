-- Undo/redo for draft point edits (separate from Studio's undo, which only
-- covers committed changes). Snapshots are copied, so later edits never leak in.
local H={}
H.__index=H
function H.new(limit) return setmetatable({limit=limit or 50,past={},future={}},H) end
local function copy(s) return {points=table.clone(s.points),selected=s.selected} end
-- Call before an edit with the state as it is now.
function H:push(state)
    local past=self.past
    local last=past[#past]
    if last and #last.points==#state.points and last.selected==state.selected then
        local same=true
        for i,p in ipairs(state.points) do if last.points[i]~=p then same=false; break end end
        if same then return end
    end
    past[#past+1]=copy(state)
    if #past>self.limit then table.remove(past,1) end
    self.future={}
end
function H:undo(state)
    local s=table.remove(self.past)
    if not s then return nil end
    self.future[#self.future+1]=copy(state)
    return s
end
function H:redo(state)
    local s=table.remove(self.future)
    if not s then return nil end
    self.past[#self.past+1]=copy(state)
    return s
end
function H:canUndo() return #self.past>0 end
function H:canRedo() return #self.future>0 end
function H:clear() self.past={}; self.future={} end
return H
