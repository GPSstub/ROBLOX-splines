-- v0.11: draft undo/redo, field validation, theme, Korean UI load.
local t=require('harness').new()
local H=require('DraftHistory')
local Ui=require('Ui')
local V=Vector3.new

t.check("draft history: undo and redo restore copies",function()
    local h=H.new(10)
    local pts={V(0,0,0)}
    h:push({points=pts,selected=1})
    pts[2]=V(1,0,0) -- mutate after push: snapshot must not change
    local s=h:undo({points=pts,selected=2})
    assert(#s.points==1 and s.selected==1)
    local r=h:redo({points=s.points,selected=1})
    assert(#r.points==2 and r.selected==2)
    assert(h:redo({points={},selected=0})==nil)
end)
t.check("draft history: a new edit clears redo; duplicates are skipped; limit holds",function()
    local h=H.new(3)
    h:push({points={V(0,0,0)},selected=1})
    h:push({points={V(0,0,0)},selected=1})
    assert(#h.past==1,"duplicate kept")
    h:undo({points={},selected=0})
    assert(h:canRedo())
    h:push({points={V(5,0,0)},selected=1})
    assert(not h:canRedo(),"redo should be cleared")
    for i=1,10 do h:push({points={V(i,0,0)},selected=1}) end
    assert(#h.past==3)
end)
t.check("field check accepts in-range numbers only",function()
    assert(Ui.check("5",0,10) and Ui.check("0",0,10) and Ui.check("1e1",0,10))
    assert(not Ui.check("11",0,10) and not Ui.check("abc",0,10) and not Ui.check("",0,10) and not Ui.check("nan",0,10))
end)
t.check("theme: colors come from Studio, failures keep defaults",function()
    local saved=table.clone(Ui.C)
    local fake={GetColor=function(_,g) return Color3.fromRGB(#g.Name,0,0) end}
    assert(Ui.applyTheme(fake))
    assert(Ui.C.bg.R==#"MainBackground"/255)
    for k,v in pairs(saved) do Ui.C[k]=v end
    assert(not Ui.applyTheme({GetColor=function() error("no theme") end}))
    assert(not Ui.applyTheme(nil))
end)
t.check("korean studio: plugin loads with Korean text and generates",function()
    local savedG={game=game,workspace=workspace,plugin=plugin,task=task,warn=warn}
    local mock=require('studio_mock')
    mock.locale="ko_kr"
    local env=mock.install()
    MODULES={} -- reload Locale with the Korean Studio setting
    env.load()
    env.find("경로를 새로 만들거나 저장된 PathForge 모델을 불러오세요.","TextLabel")
    env.click("뷰포트에서 점 추가")
    env.clickViewport(V(0,0,0)); env.clickViewport(V(0,0,-20))
    env.click("생성 / 저장된 경로 업데이트")
    local s=env.status(); assert(s:find("^Generated")==nil and s:find("파트"),s)
    mock.locale=nil
    for k,v in pairs(savedG) do _G[k]=v end
end)
return t.finish()
