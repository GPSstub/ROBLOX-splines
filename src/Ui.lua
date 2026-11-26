-- Widget building helpers: tabbed sections, labels, buttons, button rows, inputs.
local U={}
U.C={bg=Color3.fromRGB(24,28,34),panel=Color3.fromRGB(38,44,52),text=Color3.fromRGB(232,237,242),muted=Color3.fromRGB(157,170,185),accent=Color3.fromRGB(36,126,146),error=Color3.fromRGB(255,147,139)}
-- Follows Studio's light/dark theme when available; keeps the defaults otherwise.
function U.applyTheme(theme)
    if not theme then return false end
    local ok=pcall(function()
        local g=Enum.StudioStyleGuideColor
        U.C.bg=theme:GetColor(g.MainBackground)
        U.C.panel=theme:GetColor(g.Button)
        U.C.text=theme:GetColor(g.MainText)
        U.C.muted=theme:GetColor(g.DimmedText)
        U.C.accent=theme:GetColor(g.DialogMainButton)
        U.C.error=theme:GetColor(g.ErrorText)
    end)
    return ok
end
-- Checks a numeric field's text against an inclusive range.
function U.check(text,lo,hi)
    local v=tonumber(text)
    return v~=nil and v==v and v>=lo and v<=hi
end
function U.make(class,parent,props)
    local o=Instance.new(class)
    for k,v in pairs(props or {}) do o[k]=v end
    o.Parent=parent
    return o
end
-- T translates text; isBusy blocks button callbacks while a build runs.
function U.new(widget,T,isBusy)
    local C=U.C
    local make=U.make
    local ui={fields={},order=0,section=nil,active=nil,items={},tabs={}}
    ui.scroll=make("ScrollingFrame",widget,{Size=UDim2.fromScale(1,1),BackgroundColor3=C.bg,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=5})
    make("UIPadding",ui.scroll,{PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,12),PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)})
    make("UIListLayout",ui.scroll,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
    function ui.select(name)
        ui.active=name
        for section,items in pairs(ui.items) do
            for _,obj in ipairs(items) do obj.Visible=section==name end
        end
        for section,b in pairs(ui.tabs) do b.BackgroundColor3=section==name and C.accent or C.panel end
    end
    function ui.item(class,props)
        ui.order+=1
        props.LayoutOrder=ui.order
        local obj=make(class,ui.scroll,props)
        if ui.section then
            ui.items[ui.section]=ui.items[ui.section] or {}
            table.insert(ui.items[ui.section],obj); obj.Visible=ui.section==ui.active
        end
        return obj
    end
    function ui.label(text,h,color)
        return ui.item("TextLabel",{Size=UDim2.new(1,0,0,h or 22),BackgroundTransparency=1,Text=T(text),TextColor3=color or C.text,Font=Enum.Font.Gotham,TextSize=13,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left})
    end
    local function styleButton(b)
        make("UICorner",b,{CornerRadius=UDim.new(0,5)})
        return b
    end
    function ui.button(text,fn,accent)
        local b=styleButton(ui.item("TextButton",{Size=UDim2.new(1,0,0,32),BackgroundColor3=accent and C.accent or C.panel,BorderSizePixel=0,Text=T(text),TextColor3=C.text,Font=Enum.Font.GothamMedium,TextSize=13,TextWrapped=true,AutoButtonColor=true}))
        b.Activated:Connect(function() if not isBusy() then fn() end end)
        return b
    end
    -- Several equal-width buttons on one line: {{text, fn}, ...}. Returns the buttons.
    function ui.row(list,height)
        local frame=ui.item("Frame",{Size=UDim2.new(1,0,0,height or 30),BackgroundTransparency=1})
        local out={}
        for i,entry in ipairs(list) do
            local b=styleButton(make("TextButton",frame,{Position=UDim2.new((i-1)/#list,2,0,0),Size=UDim2.new(1/#list,-4,1,0),Text=T(entry[1]),TextSize=12,TextWrapped=true,Font=Enum.Font.GothamMedium,TextColor3=C.text,BackgroundColor3=C.panel,BorderSizePixel=0}))
            b.Activated:Connect(function() if not isBusy() then entry[2]() end end)
            out[i]=b
        end
        return out
    end
    -- range = {lo, hi}: invalid numbers turn red as they are typed.
    function ui.input(key,title,value,range)
        local row=ui.item("Frame",{Size=UDim2.new(1,0,0,30),BackgroundTransparency=1})
        make("TextLabel",row,{Size=UDim2.fromScale(0.59,1),BackgroundTransparency=1,Text=T(title),TextColor3=C.muted,Font=Enum.Font.Gotham,TextSize=12,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left})
        local box=make("TextBox",row,{Position=UDim2.fromScale(0.6,0),Size=UDim2.fromScale(0.4,1),BackgroundColor3=C.panel,BorderSizePixel=0,Text=tostring(value),TextColor3=C.text,Font=Enum.Font.Gotham,TextSize=13,ClearTextOnFocus=false})
        make("UICorner",box,{CornerRadius=UDim.new(0,4)})
        if range then
            local stroke=make("UIStroke",box,{Color=C.error,Thickness=1,Enabled=false})
            box:GetPropertyChangedSignal("Text"):Connect(function()
                local ok=U.check(box.Text,range[1],range[2])
                box.TextColor3=ok and C.text or C.error; stroke.Enabled=not ok
            end)
        end
        ui.fields[key]=box
        return box
    end
    -- Tab bar; each tab shows only the items created after ui.section=name.
    function ui.tabBar(names,onSelect)
        local bar=ui.item("Frame",{Size=UDim2.new(1,0,0,32),BackgroundTransparency=1})
        for i,name in ipairs(names) do
            local b=styleButton(make("TextButton",bar,{Position=UDim2.new((i-1)/#names,2,0,0),Size=UDim2.new(1/#names,-4,1,0),Text=T(name),TextSize=12,Font=Enum.Font.GothamMedium,TextColor3=C.text,BackgroundColor3=C.panel,BorderSizePixel=0}))
            ui.tabs[name]=b
            b.Activated:Connect(function() ui.select(name); ui.scroll.CanvasPosition=Vector2.zero; if onSelect then onSelect(name) end end)
        end
        ui.active=names[1]
        return bar
    end
    return ui
end
return U
