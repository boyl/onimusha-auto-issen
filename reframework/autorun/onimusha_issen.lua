-- Onimusha Issen Standalone 0.1.21-test. Build 24769601 / TDB82.
local ROOT='reframework/autorun/onimusha_issen/'
local Model=dofile(ROOT..'model.lua')
local Adapter=dofile(ROOT..'adapter.lua')
local View=dofile(ROOT..'view.lua')
local view=View.new(imgui)
local contracts=dofile(ROOT..'contracts.lua')
local CONFIG='onimusha_issen_standalone.json'
local STATUS='onimusha_issen_standalone_status.json'
local VERSION='0.1.21-test'
local model=Model.new()
local adapter=Adapter.new({sdk=sdk,thread=thread,log=log,clock=os.clock},model,contracts)
local options={auto_issen=false,auto_chain=false,auto_grab=false,auto_kakei=false,auto_parry=false}
local startup_error, save_error
local frame=0
local draw_ui

local function save()
    local ok,err=pcall(function()
        assert(json.dump_file(CONFIG,{schema_version=1,options=options}), 'Configuration write returned false')
    end)
    if not ok then save_error=tostring(err);log.error('[Onimusha Issen] Config save: '..save_error)
    else save_error=nil end
end

local function publish()
    local status=adapter:status()
    status.version,status.startup_error,status.save_error=VERSION,startup_error,save_error
    status.ui_font=view.metrics
    local ok,err=pcall(function() assert(json.dump_file(STATUS,status),'Status write returned false') end)
    if not ok then log.error('[Onimusha Issen] Status save: '..tostring(err)) end
end

do
    local read,contents=pcall(fs.read,CONFIG)
    if read and type(contents)=='string' and contents:match('%S') then
        local ok,saved=pcall(json.load_file,CONFIG)
        if not ok or type(saved)~='table' or saved.schema_version~=1 or type(saved.options)~='table' then
            startup_error='Invalid configuration. Use Reset settings, then restart scripts.'
        else
            for key in pairs(options) do
                if (key=='auto_kakei' or key=='auto_parry') and saved.options[key]==nil then options[key]=false
                elseif type(saved.options[key])~='boolean' then startup_error='Invalid option: '..key
                else options[key]=saved.options[key] end
            end
        end
    end
end

if not startup_error then
    local ok,err=pcall(function()
        -- 元数据发现和玩法调用分离；完成所有签名校验后才安装挂钩。
        adapter:discover()
        adapter:install()
        adapter:set_options(options)
    end)
    if not ok then startup_error=tostring(err);adapter:fail('startup',err) end
end
log.info('[Onimusha Issen] Loaded '..VERSION..'; status='..(startup_error or 'ready'))
publish()

re.on_frame(function()
    frame=frame+1
    if adapter.discovered then
        local ok,err=pcall(adapter.poll,adapter)
        if not ok then adapter:fail('lifecycle',err) end
    end
    if frame%120==0 then publish() end
    if view.window_open and reframework:is_drawing_ui() then
        local ok,err=pcall(view.window,view,draw_ui)
        if not ok then adapter:fail('ui',err) end
    end
end)

draw_ui=function()
    if startup_error then imgui.text('Startup failed: '..startup_error)
    else
        imgui.text(adapter.write_enabled and 'Status: ready' or 'Status: injection stopped')
        local changed=false
        for _,item in ipairs(View.items) do
            if item[1]=='auto_chain' and not adapter.chain_ready then
                imgui.text(view:label(item)..' [Unavailable]')
            elseif (item[1]=='auto_kakei' or item[1]=='auto_parry') and not adapter.deflect_ready then
                imgui.text(view:label(item)..' [Unavailable]')
            else
                local toggled,value=imgui.checkbox(view:label(item),options[item[1]])
                if toggled then options[item[1]]=value;changed=true end
            end
        end
        if changed then
            local ok,err=pcall(adapter.set_options,adapter,options)
            if not ok then adapter:fail('options',err) end
            save();publish()
        end
    end
    if imgui.button('Disable all / Reset settings') then
        options={auto_issen=false,auto_chain=false,auto_grab=false,auto_kakei=false,auto_parry=false}
        local ok,err=pcall(adapter.set_options,adapter,options)
        if not ok then adapter:fail('disable',err) end
        save();publish()
    end
    if save_error then imgui.text('Settings save failed: '..save_error) end
    if not imgui.collapsing_header('Diagnostics / Details') then return end
    imgui.text(VERSION)
    if adapter.chain_error then imgui.text('Chain: '..tostring(adapter.chain_error)) end
    if adapter.deflect_error then imgui.text('Pink counter: '..tostring(adapter.deflect_error)) end
    if imgui.button('Save diagnostic snapshot') then publish() end
    for _,err in ipairs(adapter.errors) do imgui.text(err) end
    local c=adapter.counts
    imgui.text(string.format('Armed %d / Accepted %d / Rejected %d / Duplicate %d',c.armed,c.accepted,c.rejected,c.duplicate))
    imgui.text(string.format('Chain inputs %d / Damage %d / Released %d',c.chain_inputs,c.chain_damage,c.released))
    imgui.text(string.format('Chain detection checks %d / Rejected %d / Initial inputs %d',c.chain_detection_checks,c.chain_detection_rejected,c.chain_initial_inputs))
    imgui.text(string.format('Default checks %d / Hit windows %d / Attack bit9 checks %d',c.chain_default_checks,c.chain_native_hit_windows,c.chain_attack_bit_checks))
    imgui.text(string.format('Counter checks %d / Requests %d / Qualification rejected %d',c.counter_checks,c.action_requests,c.qualification_rejected))
    imgui.text(string.format('Deflect armed %d / Accepted %d / Rejected %d',c.deflect_armed,c.deflect_accepted,c.deflect_rejected))
    imgui.text(string.format('Kakei accepted %d / Parry accepted %d',c.kakei_accepted,c.parry_accepted))
    imgui.text('Settings are saved on change. Diagnostic events are bounded to 128.')
end
re.on_draw_ui(function()
    local opened=view:begin(VERSION)
    if opened then
        if not view.launcher_expanded then view.window_open=true end
        view:finish()
    end
    view.launcher_expanded=opened
    -- 为入口与父窗口底边留出一行空白；跟随框架默认行高。
    imgui.new_line()
end)

re.on_script_reset(function()
    local ok,err=pcall(adapter.set_options,adapter,{auto_issen=false,auto_chain=false,auto_grab=false,auto_kakei=false,auto_parry=false})
    if not ok then log.error('[Onimusha Issen] Reset cleanup: '..tostring(err)) end
    adapter.write_enabled=false
end)






