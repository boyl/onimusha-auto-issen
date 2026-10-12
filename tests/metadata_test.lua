local Adapter=dofile(ROOT..'/reframework/autorun/onimusha_issen/adapter.lua')
local checks=0
local function eq(a,b,message)checks=checks+1;assert(a==b,message)end
local reads,calls=0,0
local primitive={get_full_name=function()return 'System.Int32'end,get_parent_type=function()return nil end}
local static={get_name=function()return 'PARRY'end,get_type=function()return primitive end,
    is_static=function()return true end,is_literal=function()return true end,
    get_offset_from_base=function()return 0 end,get_data=function(_,owner)
        eq(owner,nil,'静态枚举读取owner必须为nil');reads=reads+1;return 3
    end}
local instance={get_name=function()return 'Mode'end,get_type=function()return primitive end,
    is_static=function()return false end,is_literal=function()return false end,
    get_offset_from_base=function()return 0x28 end,
    get_data=function()error('不得在元数据阶段读取未知实例')end}
local method={get_name=function()return 'get_Mode'end,get_param_types=function()return{}end,
    get_return_type=function()return primitive end,is_static=function()return false end,
    get_function=function()return 1234 end,call=function()calls=calls+1;error('不得调用玩法方法')end}
local td={get_fields=function()return{static,instance}end,get_methods=function()return{method}end}
local env={sdk={find_type_definition=function()return td end}}
local adapter=Adapter.new(env,{}, {})
local report=adapter:inspect_defense_metadata()
eq(report.static_reads,7,'白名单类型各读取一次常量')
eq(reads,7,'只有静态字面字段读取')
eq(calls,0,'没有玩法方法调用')
eq(report.gameplay_writes,0,'没有玩法写入')
eq(#report.errors,0,'元数据探针正常')
eq(report.types['app.cCharacterJustGuardSupporter.cInfo'].fields[2].offset,0x28,'保留字段偏移证据')
local failures=0
env.sdk.find_type_definition=function()failures=failures+1;error('metadata failure')end
report=adapter:inspect_defense_metadata()
eq(#report.errors,3,'全局错误预算为三次')
eq(failures,3,'达到预算停止其他分支')
return checks
