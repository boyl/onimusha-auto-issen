-- 菜单视图：独立字体、双语标签和实际文字测量。
local View={}
View.__index=View
View.items={
    {'auto_issen','自动一闪（Auto Issen）','Auto Issen'},
    {'auto_chain','自动连锁一闪（Auto Chain Issen）','Auto Chain Issen'},
    {'auto_grab','抓取攻击自动反制（Auto Counter Grab）','Auto Counter Grab'},
    {'auto_kakei','自动化劲（Auto Kakei）','Auto Kakei'},
    {'auto_parry','自动弹刀（Auto Parry）','Auto Parry'},
}
local TITLE='一闪独立模块（Onimusha Issen Standalone）'
function View.new(imgui)
    return setmetatable({imgui=imgui,metrics={loaded=false}},View)
end
function View:load()
    if self.attempted then return end
    self.attempted=true
    local codes={}
    local texts={TITLE}
    for _,item in ipairs(View.items) do texts[#texts+1]=item[2] end
    for _,text in ipairs(texts) do
        for _,code in utf8.codes(text) do if code>0x7e then codes[code]=true end end
    end
    local ordered={}
    for code in pairs(codes) do ordered[#ordered+1]=code end
    table.sort(ordered)
    local ranges={0x20,0x7e}
    for _,code in ipairs(ordered) do ranges[#ranges+1]=code;ranges[#ranges+1]=code end
    ranges[#ranges+1]=0
    local size=math.floor(self.imgui.get_default_font_size()+0.5)
    self.metrics.size=size
    self.metrics.family='Onimusha Issen Sans'
    local ok,font=pcall(self.imgui.load_font,'onimusha_issen/IssenCJK.ttf',size,ranges)
    if ok and font and font~=0 then self.font=font
    else self.metrics.error='Chinese font load failed: '..tostring(font) end
end
function View:begin(version)
    self:load()
    if self.font then
        self.imgui.push_font(self.font)
        if not self.metrics.loaded then
            local ok,measurements=pcall(function()
                local measurements={}
                for _,item in ipairs(View.items) do
                    local size=self.imgui.calc_text_size(item[2])
                    assert(size.x>0 and size.y>0,'Text size is empty')
                    measurements[item[1]]={width=size.x,height=size.y}
                end
                return measurements
            end)
            if ok then self.metrics.loaded=true;self.metrics.labels=measurements
            else self.metrics.error=tostring(measurements) end
        end
    end
    local title=self.font and TITLE or 'Onimusha Issen Standalone'
    local opened=self.imgui.tree_node(title..' '..version)
    if not opened then if self.font then self.imgui.pop_font() end;return false end
    if self.metrics.error then self.imgui.text(self.metrics.error) end
    return true
end
function View:label(item) return self.font and item[2] or item[3] end
function View:finish()
    self.imgui.tree_pop()
    if self.font then self.imgui.pop_font() end
end

function View:window(draw)
    if not self.window_open then return end
    local display=self.imgui.get_display_size()
    local label_width=0
    for _,size in pairs(self.metrics.labels or {}) do label_width=math.max(label_width,size.width) end
    local width=math.min(math.max(label_width+110,360),math.max(display.x-32,120))
    local height=math.min(self.metrics.size*17,math.max(display.y-32,100))
    -- 首次出现时居中；之后由ImGui保存用户拖动和缩放。
    self.imgui.set_next_window_size({width,height},4)
    self.imgui.set_next_window_pos({math.max(16,(display.x-width)/2),math.max(16,(display.y-height)/2)},4)
    local title=self.font and TITLE or 'Onimusha Issen Standalone'
    self.window_open=self.imgui.begin_window(title..'###OnimushaIssenSettings',true,0)
    local ok,err=true,nil
    if self.window_open then
        if self.font then self.imgui.push_font(self.font) end
        ok,err=pcall(draw)
        if self.font then self.imgui.pop_font() end
    end
    self.imgui.end_window()
    if not ok then error(err) end
end
return View
