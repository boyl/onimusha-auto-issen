local Adapter=dofile(ROOT..'/reframework/autorun/onimusha_issen/adapter.lua')
local Model=dofile(ROOT..'/reframework/autorun/onimusha_issen/model.lua')
local checks=0
local function eq(a,b,message) checks=checks+1;assert(a==b,message..': '..tostring(a)) end
local function object(name,id)
    local result={id=id,native_fields={}}
    result.get_type_definition=function() return {
        get_full_name=function()return name end,get_parent_type=function()return nil end,
        get_fields=function()
            local fields={}
            for offset,value in pairs(result.native_fields) do
                fields[#fields+1]={is_static=function()return false end,
                    get_offset_from_base=function()return offset end,get_data=function()return value end}
            end
            return fields
        end} end
    return result
end
local player,other=object('app.cPlayerCharacterEntity','player'),object('app.cPlayerCharacterEntity','other')
local info=object('app.cPlayerManageInfo','info')
local updater=object('app.cPlayerJustFrameUpdater','updater')
local hit=object('app.AttackSensorHitInfo','hit')
local damage_hit=object('app.HitInfo','damage_hit')
local param=object('app.cAttackRuntimeParamBase','param')
local supporter=object('app.cPlayerChainIssenSupporter','supporter')
local controller=object('app.cPlayerChainIssenInputControllerEntity','controller')
local around=object('app.cPlayerAroundFrameUpdater','around')
local wrong_around=object('app.cPlayerAroundFrameUpdater','wrong_around')
local default_controller=object('app.cPlayerDefaultInputControllerEntity','default_controller')
local bitset=object('ace.Bitset`1<System.Int32>','bitset')
local ready_owner=object('app.cPlayerManageInfo','ready_owner')
local ready_holder=object('app.cInputContextHolder','ready_holder')
local ready_command=object('app.cInputCommandResult','ready_command')
supporter.native_fields[0x10]=ready_owner
ready_owner.native_fields[0xe8]=ready_holder
ready_holder.native_fields[0x10]=ready_command
ready_command.native_fields[0x50]=bitset
local cancel_bitset=object('ace.Bitset`1<System.Int32>','cancel_bitset')

local native_hit,native_window,native_failure=false,false,0
local command=object('app.cPlayerCommandResult','command')
local guard=object('app.cCharacterJustGuardSupporter','guard')
local other_guard=object('app.cCharacterJustGuardSupporter','other_guard')
local style_controller=object('app.cPlayerStyleController','style_controller')
local style,eligibility=1,nil
local native_health=100
local holder=object('app.cGameContextHolder','holder')
local chara=object('app.cCharacterContextParam','chara')
local health_manager=object('app.cHealthManager','health')
local now,active,current_player=1,{},player
local flags,can_request,detection,input={},false,false,0
local hooks,storages,calls={},{},{}
local invoke
local native_requests=0
local sdk={PreHookResult={CALL_ORIGINAL=1},get_tdb_version=function()return 82 end,
    to_ptr=function(o) return type(o)=='table' and o.id or o end,
    to_int64=function(v)return v end,to_managed_object=function(o)return o end,
    get_managed_singleton=function()return {} end,
    hook=function(method,pre,post) hooks[method.key]={pre=pre,post=post} end}
local env={sdk=sdk,thread={get_hash=function()return 1 end,get_hook_storage=function()return storages[#storages]end},
    log={error=function()end},clock=function()return now end}
local model=Model.new()
local adapter=Adapter.new(env,model,{})
local methods={health_context=function()return holder end,health_character=function()return chara end,
    health_manager=function()return health_manager end,health_value=function()return native_health end,player_info=function()return info end,character_entity=function()return current_player end,
    just_frame_updater=function()return updater end,sensor_attack_param_data=function()return param end,
    attack_param_check_flag=function(_,flag)return flags[flag]==true end,
    sensor_attack_owner=function()return {id='enemy'} end,sensor_attack_object=function()return {id='attack'} end,
    sensor_hit_id=function()return 22 end,sensor_unique_id=function()return 95 end,
    is_active=function(_,slot)return active[slot]==true end,
    set_input_on=function(_,slot)active[slot]=true end,force_disable_input=function(_,slot)active[slot]=false end,
    chain_hit_query=function()return native_hit end,chain_frame_active=function()return native_window end,
    chain_frame_failure=function()return native_failure end,
    chain_around_frame_updater=function()return around end,
    chain_initial_before_hit_frame=function()return 8 end,
    chain_initial_frame_enable=function(_,slot,frames)eq(slot,0,'首段原生TYPE0');eq(frames,8,'不修改原生帧数')end,
    chain_issen_supporter=function()return supporter end,chain_input_state=function()return input end,
    is_enable_just_guard=function(_,slot)return eligibility==nil or eligibility[slot]==true end,
    player_style_controller=function()return style_controller end,
    player_style_type=function()return style end,just_guard_supporter=function()return guard end,
    check_counter_issen=function()
        native_requests=native_requests+1
        invoke('request_counter_issen_action',{[2]=player,[3]=hit},function()return 0x100 end)
        return true
    end,
    chain_can_request_action=function()return can_request end,chain_notify_input=function() input=1 end,
    controller_entity=function()return controller end,command_result=function()return command end,
    scene_current=function()return {id='scene'}end,scene_loading=function()return false end}
for key,fn in pairs(methods) do adapter.methods[key]={key=key,call=function(_,owner,...)calls[key]=(calls[key]or 0)+1;return fn(owner,...)end} end
for _,key in ipairs({'attack_sensor_hook','hit_damage_hook','request_counter_issen_action','check_counter_grab',
    'chain_ready_detection','chain_damage_event','chain_input_failure_hook','chain_fail_check',
    'chain_default_update','chain_bitset_input','chain_detection_input','chain_initial_hit_signal','chain_first_input_update','command_check_normal','is_enable_just_guard','try_just_guard'}) do
    if not adapter.methods[key] then adapter.methods[key]={key=key} end
end
adapter.discovered,adapter.chain_ready,adapter.deflect_ready=true,true,true
adapter.detection_field={get_data=function()return detection end}
adapter.command_normal_field={get_data=function()return bitset end}
adapter.command_hold_field={get_data=function()return cancel_bitset end}
adapter:install()
adapter:poll()
adapter:set_options({auto_issen=true,auto_chain=true,auto_grab=true})
invoke=function(key,args,original)
    storages[#storages+1]={}
    hooks[key].pre(args)
    local value=original and original() or 0
    if type(value)=='boolean' then value=value and 1 or 0 end
    local result=hooks[key].post(value)
    storages[#storages]=nil
    return result
end
-- 原生伤害入口负责检查和命中收尾。动作请求false也可排队，检查true仍消费命中。
local function native_damage()
    if active[0] then
        invoke('check_counter_issen',{[2]=player,[3]=hit},function()return adapter:call('check_counter_issen',player,hit) end)
        return 1
    end
    return 0
end
invoke('attack_sensor_hook',{[2]=player,[3]=hit})
eq(native_requests,0,'传感器不提前触发一闪')
invoke('hit_damage_hook',{[2]=player,[3]=damage_hit},function()
    eq(active[0],true,'原回调前输入已准备')
    return native_damage()
end)
eq(native_requests,1,'每次原生派发仅一次')
eq(adapter.counts.accepted,1,'原生消费命中才记录成功')
eq(active[0],false,'成功后释放自己生成的输入')
eq(calls.check_counter_issen,1,'必要动作检查仅调用一次')
eq(adapter:hook_bool(0x101),true,'bool低字节为真')
now=2;active[0]=true
invoke('hit_damage_hook',{[2]=player,[3]=damage_hit},native_damage)
eq(active[0],true,'保留手动一闪输入')
active[0]=false
invoke('hit_damage_hook',{[2]=other,[3]=damage_hit})
eq(adapter.counts.armed,1,'非玩家不注入')
flags[0x80],flags[0x1000]=true,true
invoke('attack_sensor_hook',{[2]=player,[3]=hit},function()
    eq(active[1],true,'抓取使用TYPE1')
    eq(invoke('is_enable_just_guard',{[2]=player,[3]=1,[4]=hit}),1,'当前可反制抓取提升派发资格')
    eq(invoke('is_enable_just_guard',{[2]=other,[3]=1,[4]=hit}),0,'其他玩家资格保持')
    eq(invoke('is_enable_just_guard',{[2]=player,[3]=0,[4]=hit}),0,'其他槽资格保持')
    invoke('check_counter_grab',{[2]=player,[3]=hit},function()return 1 end)
end)
eq(active[1],false,'抓取输入清理')
eq(adapter.counts.accepted,2,'抓取结果来自原生检查')
now=3;input=0;can_request=false;detection=true
local prepared=false
invoke('chain_ready_detection',{[2]=supporter},function()
    prepared=invoke('chain_bitset_input',{[2]=bitset,[3]=4})==1
    eq(invoke('chain_bitset_input',{[2]=object('ace.Bitset`1<System.Int32>','other_bitset'),[3]=4}),0,'其他位集不提升准备命令')
    eq(invoke('chain_bitset_input',{[2]=bitset,[3]=9}),0,'准备入口不提升攻击编号9')
end)
eq(prepared,true,'自动一闪首轮准备入口得到原生命令4')
eq(adapter:ready_input_bitset(supporter),bitset,'原生Ready引用链得到正确位集')
eq(adapter:ready_input_bitset(supporter)==cancel_bitset,false,'上下文位集与控制器Cancel位集不同')
eq(invoke('chain_bitset_input',{[2]=bitset,[3]=4}),0,'准备调用外不提升命令4')
invoke('chain_ready_detection',{[2]=supporter},function()
    eq(invoke('chain_bitset_input',{[2]=bitset,[3]=4},function()return 1 end),1,'准备入口保留手动输入')
end)
native_health=0
invoke('chain_ready_detection',{[2]=supporter},function()
    eq(invoke('chain_bitset_input',{[2]=bitset,[3]=4}),0,'零血不补准备命令')
end)
native_health=100

invoke('chain_ready_detection',{[2]=supporter})
local function chain_bit(bit,owner)
    local result
    invoke('chain_first_input_update',{[2]=owner or controller},function()
        result=invoke('chain_bitset_input',{[2]=bitset,[3]=bit or 9})
    end)
    return result
end
eq(invoke('chain_detection_input',{[2]=supporter}),0,'检测阶段不伪造原生结果')
eq(chain_bit(),0,'无动作请求资格不补输入')
can_request=true
eq(chain_bit(8),0,'零售版不使用Demo输入编号')
eq(chain_bit(9,default_controller),0,'错误控制器不补输入')
eq(chain_bit(),1,'连锁控制器首段输入')
eq(chain_bit(),0,'同段不重复')
now=3.2;invoke('chain_damage_event',{[2]=supporter})
eq(chain_bit(),1,'原生命中后下一段输入')
eq(chain_bit(),0,'下一段不重复')
now=3.4;invoke('chain_damage_event',{[2]=supporter})
adapter:set_options({auto_issen=true,auto_chain=false,auto_grab=true,auto_kakei=false,auto_parry=false})
eq(chain_bit(),0,'关闭连锁开关不补输入')
adapter:set_options({auto_issen=true,auto_chain=true,auto_grab=true,auto_kakei=false,auto_parry=false})
invoke('chain_ready_detection',{[2]=supporter})
native_health=0
eq(chain_bit(),0,'连锁控制器零血不补输入')
eq(model.chain,nil,'连锁控制器零血清理')
native_health=100;now=3.5;invoke('chain_ready_detection',{[2]=supporter})

eq(calls.chain_initial_frame_enable,nil,'不重开AroundFrame')
eq(calls.chain_notify_input,nil,'不直接通知连锁')
input=0;invoke('chain_fail_check',{[2]=supporter},function()return 1 end)
eq(model.chain~=nil,true,'NONE不因fail查询清理')
input=2;invoke('chain_fail_check',{[2]=supporter},function()return 1 end)
eq(model.chain,nil,'明确FAIL清理')
input=0;now=3.6;invoke('chain_ready_detection',{[2]=supporter})
native_health=0
eq(invoke('chain_detection_input',{[2]=supporter}),0,'零血不注入连锁')
eq(model.chain,nil,'零血清理连锁')
native_health=100
-- 首段来自普通控制器原生攻击位，原生命中和窗口有效是必要条件。
controller=default_controller;now=3.8;input=0
invoke('chain_ready_detection',{[2]=supporter})
local function default_bit(bit)
    local result
    invoke('chain_default_update',{[2]=default_controller},function()
        result=invoke('chain_bitset_input',{[2]=bitset,[3]=bit or 9})
    end)
    return result
end
eq(default_bit(),0,'未命中不补攻击')
native_hit=true
eq(default_bit(),0,'窗口未开放不补攻击')
native_window=true;native_failure=2
eq(default_bit(),0,'窗口FAIL不补攻击')
native_failure=0
eq(default_bit(8),0,'旧Demo编号8不触发零售版攻击')
eq(default_bit(),1,'有效命中窗口首段补攻击')
eq(default_bit(),0,'相同段下一帧不重复')
controller=object('app.cPlayerChainIssenInputControllerEntity','controller');can_request=true
eq(chain_bit(9,controller),1,'普通控制器预输入不阻止实际连锁动作输入')
eq(chain_bit(9,controller),0,'动作输入同段不重复')
controller=default_controller
eq(calls.chain_initial_frame_enable,nil,'普通输入补充不主动enable')
eq(calls.chain_notify_input,nil,'普通输入补充不主动notify')
now=3.95;invoke('chain_damage_event',{[2]=supporter})
native_health=0
eq(default_bit(),0,'致死后不补攻击')
native_health=100
-- Zero low byte must remain false even if high bits are nonzero.
eq(adapter:hook_bool(0x100),false,'原生bool ABI低字节')
now=4;flags={};current_player=other
adapter:poll()
eq(model.player,'other','玩家替换生效')
eq(next(adapter.sensor_stacks),nil,'回调栈清理')
-- Repeated-trigger regression: 100 collision/action cycles on reused IDs.
current_player=player;adapter:poll();now=5
local before=adapter.counts.accepted
for iteration=1,100 do
    now=5+iteration*0.2
    invoke('hit_damage_hook',{[2]=player,[3]=damage_hit},native_damage)
    eq(active[0],false,'连续触发后无残留输入')
end
eq(adapter.counts.accepted-before,100,'100次连续原生派发均记录成功')
eq(next(adapter.sensor_stacks),nil,'连续触发后无残留回调栈')
eq(#adapter.events<=128,true,'诊断事件有界')
-- 原生拒绝仍正常受击；仅返回命中已处理但未检查一闪不能计作一闪成功。
local accepted_before=adapter.counts.accepted
eq(invoke('hit_damage_hook',{[2]=player,[3]=damage_hit},function()return 0 end),0,'拒绝不拦截原生伤害')
eq(adapter.counts.accepted,accepted_before,'拒绝不计成功')
eq(active[0],false,'拒绝后清理输入')
eq(invoke('hit_damage_hook',{[2]=player,[3]=damage_hit},function()return 1 end),1,'其他命中消费返回值不改')
eq(adapter.counts.accepted,accepted_before,'其他消费不计一闪成功')
local normal_set=adapter.methods.set_input_on.call
adapter.methods.set_input_on.call=function()end
invoke('hit_damage_hook',{[2]=player,[3]=damage_hit},function()return 0 end)
eq(adapter.write_enabled,true,'死亡或状态拒绝激活输入不导致全模块报错')
eq(adapter.counts.input_not_armed,1,'未激活单独记录')
adapter.methods.set_input_on.call=normal_set
-- 两种开关独立；粉光候选允许TYPE4，禁止一闪属性可覆盖TYPE0外层资格。
adapter:set_options({auto_issen=true,auto_chain=true,auto_grab=true,auto_kakei=true,auto_parry=false})
now=28;eligibility={[0]=true,[1]=false,[2]=false,[3]=true,[4]=true};flags[32]=true
invoke('attack_sensor_hook',{[2]=player,[3]=hit},function()
    eq(active[3],true,'化劲开关提供TYPE3')
    eq(active[2],nil,'化劲不派发弹刀')
    invoke('try_just_guard',{[2]=other_guard,[3]={}},function()return true end)
    eq(adapter:current_sensor().accepted,nil,'其他支持器不能标记成功')
    invoke('try_just_guard',{[2]=guard,[3]={}},function()return true end)
    return 0
end)
eq(adapter.counts.kakei_accepted,1,'化劲原生成功单独计数')
eq(active[3],false,'化劲输入清理')
adapter:set_options({auto_issen=true,auto_chain=true,auto_grab=true,auto_kakei=false,auto_parry=true})
now=29
invoke('attack_sensor_hook',{[2]=player,[3]=hit},function()
    eq(active[2],true,'弹刀开关提供TYPE2')
    eq(invoke('is_enable_just_guard',{[2]=player,[3]=2,[4]=hit}),1,'当前弹刀派发门槛补足')
    eq(invoke('is_enable_just_guard',{[2]=other,[3]=2,[4]=hit}),0,'其他玩家不提升')
    invoke('try_just_guard',{[2]=guard,[3]={}},function()return true end)
    return 0
end)
eq(adapter.counts.parry_accepted,1,'弹刀原生成功单独计数')
eq(active[2],false,'弹刀输入清理')
now=29.2
invoke('attack_sensor_hook',{[2]=player,[3]=hit},function()
    invoke('try_just_guard',{[2]=guard,[3]={}},function()return false end)
    return 2
end)
eq(adapter.counts.deflect_rejected,1,'原生拒绝不伪造成功')
eq(active[2],false,'拒绝后清理')
local before=adapter.counts.deflect_armed
now=29.4;flags[16]=true
invoke('attack_sensor_hook',{[2]=player,[3]=hit})
eq(adapter.counts.deflect_armed,before,'禁止弹刀属性不注入');flags[16]=nil
now=29.6;flags[32]=nil;eligibility={[0]=true,[1]=false,[2]=false,[3]=true,[4]=true}
invoke('attack_sensor_hook',{[2]=player,[3]=hit})
eq(adapter.counts.deflect_armed,before,'普通一闪攻击不改为弹刀')
now=29.8;flags[32]=true;active[3]=true
invoke('attack_sensor_hook',{[2]=player,[3]=hit})
eq(active[3],true,'保留手动输入');active[3]=false
flags[1099511627776]=true
invoke('attack_sensor_hook',{[2]=player,[3]=hit})
eq(adapter.counts.deflect_armed,before,'远程攻击不注入');flags={}
adapter:set_options({auto_issen=true,auto_chain=true,auto_grab=true,auto_kakei=false,auto_parry=false})
invoke('attack_sensor_hook',{[2]=player,[3]=hit})
eq(adapter.counts.deflect_armed,before,'两功能关闭无注入')
-- 零血时不干预原生致死处理，也不派发反制或连锁。
native_health=0;local previous_armed=adapter.counts.armed
invoke('hit_damage_hook',{[2]=player,[3]=damage_hit},function()return 0 end)
eq(adapter.counts.armed,previous_armed,'零血不派发自动一闪')
eq(model.chain,nil,'零血清除自动连锁状态')
eq(adapter.native_health,0,'诊断记录原生零血')
native_health=100
-- Error after setInputOn must still clean the owned slot and stop writes.
now=30
adapter.methods.set_input_on.call=function(_,_,slot) active[slot]=true;error('after native write') end
invoke('hit_damage_hook',{[2]=player,[3]=damage_hit})
eq(active[0],false,'异常后释放生成输入')
eq(adapter.write_enabled,false,'异常停止派发')
return checks

