-- 真实入口脚本的旧配置迁移与第四开关保存，游戏边界以契约替身隔离。
local checks=0
local function eq(actual,expected,message)checks=checks+1;assert(actual==expected,message)end
local original_dofile=dofile
local saved_globals={}
local names={'dofile','sdk','thread','log','fs','json','re','imgui','reframework'}
for _,name in ipairs(names)do saved_globals[name]=_G[name]end
local old_options={auto_issen=true,auto_chain=false,auto_grab=true}
local callbacks,labels,last_saved,latest_status={},{},nil,nil
local counts=setmetatable({},{__index=function()return 0 end})
local fake_adapter={new=function(_,model)
    return {discovered=false,installed=false,chain_ready=true,deflect_ready=true,errors={},counts=counts,
        discover=function(self)self.discovered=true end,install=function(self)self.installed=true end,
        set_options=function(self,options)model:set_options(options);self.write_enabled=true end,
        status=function()return {options=model.options}end,poll=function()end,
        fail=function(_,scope,err)error(scope..': '..tostring(err))end}
end}
_G.dofile=function(path)
    if path:match('/adapter.lua$')then return fake_adapter end
    if path:sub(1,12)=='reframework/'then return original_dofile(ROOT..'/'..path)end
    return original_dofile(path)
end
_G.sdk,_G.thread={},{}
_G.log={info=function()end,error=function()end}
_G.fs={read=function()return '{}'end}
_G.json={load_file=function()return{schema_version=1,options=old_options}end,
    dump_file=function(path,data)
        if path=='onimusha_issen_standalone.json'then last_saved=data
        else latest_status=data end
        return true
    end}
_G.re={on_frame=function(fn)callbacks.frame=fn end,on_draw_ui=function(fn)callbacks.ui=fn end,
    on_script_reset=function(fn)callbacks.reset=fn end}
_G.reframework={is_drawing_ui=function()return true end}
_G.imgui={get_default_font_size=function()return 16 end,load_font=function()return 1 end,push_font=function()end,pop_font=function()end,
    get_display_size=function()return{x=1280,y=720}end,set_next_window_size=function()end,
    set_next_window_pos=function()end,begin_window=function()return true end,end_window=function()end,
    collapsing_header=function()return false end,
    new_line=function()end,
    calc_text_size=function()return{x=200,y=18}end,tree_node=function()return true end,
    tree_pop=function()end,text=function()end,button=function()return false end,
    checkbox=function(label,value)
        labels[#labels+1]=label
        if label:match('Auto Kakei')then return true,true end
        return false,value
    end}
local ok,err=pcall(function()
    original_dofile(ROOT..'/reframework/autorun/onimusha_issen.lua')
    eq(latest_status.startup_error,nil,'旧三开关配置正常加载')
    eq(latest_status.options.auto_issen,true,'旧一闪设置保持')
    eq(latest_status.options.auto_chain,false,'旧连锁设置保持')
    eq(latest_status.options.auto_grab,true,'旧抓取设置保持')
    eq(latest_status.options.auto_kakei,false,'第四开关默认关闭')
    callbacks.ui()
    callbacks.frame()
    eq(#labels,5,'显示四个开关')
    eq(last_saved.options.auto_kakei,true,'第四开关勾选立即保存')
    eq(last_saved.options.auto_issen,true,'第四开关不覆盖旧设置')
    eq(latest_status.ui_font.loaded,true,'诊断记录字体测量')
    callbacks.reset()
    eq(last_saved.options.auto_kakei,true,'脚本重载不抹掉持久设置')
end)
for _,name in ipairs(names)do _G[name]=saved_globals[name]end
assert(ok,err)
return checks
