-- REFramework 边界适配器。接口来自恢复源码，派发策略为本次重新实现。
-- TYPE0 由 evHitDamageProcess 原生检查、收尾并消费命中；只提供输入。
-- 不直接构造 requestCounterIssenlAction 参数，不写游戏速度。
local Adapter = {}
Adapter.__index = Adapter

local CORE = {'player_info','character_entity','just_frame_updater','set_input_on',
    'force_disable_input','is_active','attack_sensor_hook','hit_damage_hook','sensor_attack_owner',
    'sensor_attack_object','sensor_hit_id','sensor_unique_id','sensor_attack_param_data',
    'attack_param_check_flag','is_enable_just_guard','check_counter_issen','check_counter_grab','request_counter_issen_action'}
local CHAIN = {'chain_issen_supporter','chain_input_state','chain_ready_detection',
    'chain_can_request_action','chain_damage_event','chain_fail_check','chain_detection_input',
    'controller_entity','chain_around_frame_updater','chain_default_update','chain_hit_query',
    'chain_frame_active','chain_frame_failure','chain_bitset_input','chain_first_input_update','command_result'}
local DEFLECT = {'just_guard_supporter','try_just_guard'}

local function typename(td) return td and td:get_full_name() or nil end
local function object_type(object) return object and typename(object:get_type_definition()) or nil end

function Adapter.new(environment, model, contracts)
    return setmetatable({env=environment,model=model,contracts=contracts,methods={},
        sensor_stacks={},damage_stacks={},controller_stacks={},installed=false,chain_ready=false,
        write_enabled=false,scene=nil,loading=true,errors={},events={},chain_trace={},chain_trace_state={},counts={
        chain_default_checks=0,chain_native_hit_windows=0,chain_attack_bit_checks=0,chain_detection_checks=0,chain_detection_rejected=0,chain_initial_signals=0,chain_initial_inputs=0,chain_pending_fail=0,armed=0,accepted=0,rejected=0,duplicate=0,chain_inputs=0,chain_damage=0,
        released=0,native_input_preserved=0,counter_checks=0,action_requests=0,
        qualification_rejected=0,grab_gate_promoted=0,damage_consumed=0,input_not_armed=0,
        deflect_armed=0,deflect_accepted=0,deflect_rejected=0,deflect_gate_promoted=0,
        deflect_unknown_style=0,kakei_accepted=0,parry_accepted=0},chain_input_observed={},deflect_profiles={},metadata={}},Adapter)
end

function Adapter:now() return self.env.clock() end
function Adapter:token(object) return object and tostring(self.env.sdk.to_ptr(object)) or nil end
function Adapter:integer(value)
    if type(value) == 'number' then return value end
    return self.env.sdk.to_int64(value)
end
function Adapter:hook_bool(value) return (self:integer(value) & 0xff) ~= 0 end

function Adapter:chain_trace_event(kind,detail)
    if #self.chain_trace>=256 then return end -- 保留最早首轮，禁止后续战斗覆盖。
    self.chain_trace[#self.chain_trace+1]={time=self:now(),kind=kind,detail=detail}
end

function Adapter:chain_probe(path,supporter,entity)
    local updater=self:call('chain_around_frame_updater',entity)
    local hit=updater and self:call('chain_hit_query',updater,0)
    local active=updater and self:call('chain_frame_active',updater,0)
    local input=supporter and self:integer(self:call('chain_input_state',supporter))
    local can_request=supporter and self:call('chain_can_request_action',supporter)
    local failure=updater and self:integer(self:call('chain_frame_failure',updater,0))
    local chain=self.model.chain
    local state=table.concat({tostring(hit),tostring(active),tostring(input),tostring(can_request),
        tostring(chain~=nil),tostring(chain and chain.submitted),tostring(failure)},':')
    if self.chain_trace_state[path]~=state then
        self.chain_trace_state[path]=state
        self:chain_trace_event('controller_state',{path=path,hit=hit,active=active,input=input,
            failure=failure,can_request=can_request,has_ready=chain~=nil,submitted=chain and chain.submitted,
            health=self.native_health,generation=self.model.generation})
    end
end

function Adapter:event(kind, detail)
    if kind:sub(1,6)=='chain_' or kind=='scene_changed' then self:chain_trace_event(kind,detail) end
    self.events[#self.events+1] = {time=self:now(),kind=kind,detail=detail}
    if #self.events > 128 then table.remove(self.events,1) end
end

function Adapter:fail(scope, message)
    self.write_enabled = false
    local text = scope .. ': ' .. tostring(message)
    if self.errors[#self.errors] ~= text then
        self.errors[#self.errors+1] = text
        if #self.errors > 16 then table.remove(self.errors,1) end
        self.env.log.error('[Onimusha Issen] ' .. text)
        self:event('error',text)
    end
end

function Adapter:resolve(key, contract)
    contract = contract or self.contracts[key]
    assert(contract, 'Missing contract: ' .. key)
    local td = assert(self.env.sdk.find_type_definition(contract.lookup_type), 'Missing type: '..contract.lookup_type)
    local found
    for _, method in ipairs(td:get_methods()) do
        if method:get_name() == contract.name and method:is_static() == contract.is_static
            and typename(method:get_declaring_type()) == contract.declaring_type
            and typename(method:get_return_type()) == contract.return_type then
            local params, match = method:get_param_types(), true
            if #params ~= #contract.param_types then match = false end
            for i, actual in ipairs(params) do
                local name, expected = typename(actual), contract.param_types[i]
                local prefix = contract.param_type_prefixes and contract.param_type_prefixes[i]
                local suffix = prefix and name:sub(#prefix+1,#prefix+1)
                local prefix_match = prefix and name:sub(1,#prefix) == prefix
                    and (suffix == '' or suffix == '<' or suffix == '[')
                if name ~= expected and not prefix_match then match = false end
            end
            if match then
                assert(not found, 'Ambiguous method: '..key)
                found = method
            end
        end
    end
    assert(found, 'Unsupported signature: '..key)
    self.methods[key] = found
    local params = {}
    for _, td_param in ipairs(found:get_param_types()) do params[#params+1] = typename(td_param) end
    local native_ok,native_address=pcall(function()return tostring(found:get_function())end)
    self.metadata[key] = {native=native_ok and native_address or nil,owner=contract.lookup_type,name=found:get_name(),
        returns=typename(found:get_return_type()),params=params,static=found:is_static()}
    return found
end

function Adapter:call(key, owner, ...)
    return assert(self.methods[key], 'Unresolved method: '..key):call(owner,...)
end

function Adapter:player()
    local manager = self.env.sdk.get_managed_singleton('app.PlayerManager')
    if not manager then return nil end
    local info = self:call('player_info',manager)
    if not info then return nil end
    assert(object_type(info)=='app.cPlayerManageInfo','Wrong player info type')
    local entity = self:call('character_entity',info)
    if not entity then return nil end
    assert(object_type(entity)=='app.cPlayerCharacterEntity','Wrong player entity type')
    return entity, info
end

function Adapter:owner(args, expected_type, getter)
    local object = self.env.sdk.to_managed_object(args[2])
    if not object or object_type(object) ~= expected_type then return nil end
    local entity, info = self:player()
    if not entity then return nil end
    self.model:observe_player(self:token(entity))
    local expected = getter and self:call(getter,entity) or entity
    if self:token(object) ~= self:token(expected) then return nil end
    return object, entity, info
end

function Adapter:stack(kind)
    local key = tostring(self.env.thread.get_hash())
    local map = self[kind..'_stacks']
    local stack = map[key]
    if not stack then stack={};map[key]=stack end
    return stack,key
end

function Adapter:current_sensor()
    local stack = self.sensor_stacks[tostring(self.env.thread.get_hash())]
    return stack and stack[#stack]
end

function Adapter:current_damage()
    local stack=self.damage_stacks[tostring(self.env.thread.get_hash())]
    return stack and stack[#stack]
end

function Adapter:damage_pre(args,context)
    if not self:allowed() or not self.model.options.auto_issen then return end
    local entity=self:owner(args,'app.cPlayerCharacterEntity')
    if not entity then return end
    local hit=self.env.sdk.to_managed_object(args[3])
    if object_type(hit)~='app.HitInfo' then return end
    local updater=self:call('just_frame_updater',entity)
    if object_type(updater)~='app.cPlayerJustFrameUpdater' then return end
    for slot=0,4 do
        if self:call('is_active',updater,slot) then
            self.counts.native_input_preserved=self.counts.native_input_preserved+1
            return
        end
    end
    context.player,context.hit=self:token(entity),self:token(hit)
    context.slot,context.generation=0,self.model.generation
    context.updater_token,context.generated=self:token(updater),true
    self:call('set_input_on',updater,0)
    if not self:call('is_active',updater,0) then
        self.counts.input_not_armed=self.counts.input_not_armed+1
        self:release(context)
        self:event('input_not_armed',{path='damage'})
        return
    end
    self.counts.armed=self.counts.armed+1
    self:event('input_armed',{slot=0,path='damage'})
end

function Adapter:damage_post(retval,context)
    -- 原生成功分支返回 RESULT=1，并已调用命中收尾；不修改伤害返回值。
    context.accepted=context.generated and context.native_counter_result==true and self:integer(retval)==1
    if context.accepted then self.counts.damage_consumed=self.counts.damage_consumed+1 end
    self:event('damage_result',{result=self:integer(retval),generated=context.generated==true,
        checks=context.check_count or 0,requests=context.request_count or 0})
    self:sensor_post(retval,context)
    return retval
end

function Adapter:health()
    local entity,info=self:player()
    if not entity then return nil end
    local holder=self:call('health_context',info)
    if object_type(holder)~='app.cGameContextHolder' then return nil end
    local chara=self:call('health_character',holder)
    if object_type(chara)~='app.cCharacterContextParam' then return nil end
    local manager=self:call('health_manager',chara)
    if object_type(manager)~='app.cHealthManager' then return nil end
    local value=self:integer(self:call('health_value',manager))
    assert(type(value)=='number','Invalid native health')
    self.native_health=value
    return value
end

function Adapter:allowed()
    if not self.write_enabled or self.loading then return false end
    local health=self:health()
    if not health or health<=0 then self.model.chain=nil;return false end
    return true
end

function Adapter:release(context)
    if not context or not context.generated then return end
    -- Never dereference an updater retained across a player/scene transition.
    local entity = self:player()
    if not entity or context.player ~= self:token(entity)
        or context.generation ~= self.model.generation then
        context.generated=false
        return
    end
    local updater = self:call('just_frame_updater',entity)
    if self:token(updater) ~= context.updater_token then context.generated=false;return end
    self:call('force_disable_input',updater,context.slot)
    assert(self:call('is_active',updater,context.slot)==false,'Generated input remained active')
    context.generated=false
    self.counts.released=self.counts.released+1
end

function Adapter:sensor_pre(args, context)
    if not self:allowed() then return end
    local entity = self:owner(args,'app.cPlayerCharacterEntity')
    if not entity then return end
    local hit = self.env.sdk.to_managed_object(args[3])
    if object_type(hit) ~= 'app.AttackSensorHitInfo' then return end
    local param = self:call('sensor_attack_param_data',hit)
    if not param then return end
    local grapple = self:call('attack_param_check_flag',param,0x80)
    local counter_grab = self:call('attack_param_check_flag',param,0x1000)
    local slot = self.model:choose(grapple,counter_grab)
    if not grapple and not counter_grab and (self.model.options.auto_kakei or self.model.options.auto_parry) and self.deflect_ready then
        if self:call('attack_param_check_flag',param,1099511627776)
            or self:call('attack_param_check_flag',param,70368744177664) then return end
        local eligible,profile={},0
        for candidate=0,4 do
            eligible[candidate]=self:call('is_enable_just_guard',entity,candidate,hit)
            if eligible[candidate] then profile=profile+(1<<candidate) end
        end
        self.deflect_profiles[tostring(profile)]=(self.deflect_profiles[tostring(profile)] or 0)+1
        local attack_flags={
            unable_issen=self:call('attack_param_check_flag',param,32),
            unable_parry=self:call('attack_param_check_flag',param,8),
            unable_block=self:call('attack_param_check_flag',param,16)}
        self:event('defense_profile',{eligibility=profile,flags=attack_flags})
        slot=self.model:choose_deflect(eligible,attack_flags)
        if slot then
            local guard=self:call('just_guard_supporter',entity)
            if not guard then return end
            context.deflect,context.guard_supporter=true,self:token(guard)
            context.defense_kind=slot==3 and 'kakei' or 'parry'
            self:event('deflect_candidate',{eligibility=profile,slot=slot,kind=context.defense_kind})
        end
    end
    if slot==nil or slot==0 then return end -- 普通一闪仅走完整原生伤害管线。
    local updater = self:call('just_frame_updater',entity)
    if object_type(updater) ~= 'app.cPlayerJustFrameUpdater' then return end
    -- Preserve every existing native/player input, including other defensive slots.
    for candidate=0,4 do
        if self:call('is_active',updater,candidate) then
            self.counts.native_input_preserved=self.counts.native_input_preserved+1
            return
        end
    end
    local key=table.concat({self:token(entity), self:token(self:call('sensor_attack_owner',hit)) or '-',
        self:token(self:call('sensor_attack_object',hit)) or '-',
        tostring(self:call('sensor_hit_id',hit)),tostring(self:call('sensor_unique_id',hit))},'|')
    if not self.model:claim_hit(key,self:now()) then self.counts.duplicate=self.counts.duplicate+1;return end
    context.player,context.hit=self:token(entity),self:token(hit)
    context.slot,context.generation=slot,self.model.generation
    context.updater_token,context.generated=self:token(updater),true
    -- Mark ownership before the call so a partially successful call can be cleaned up.
    self:call('set_input_on',updater,slot)
    if not self:call('is_active',updater,slot) then
        self.counts.input_not_armed=self.counts.input_not_armed+1
        self:release(context)
        self:event('input_not_armed',{path='sensor'})
        return
    end
    self.counts.armed=self.counts.armed+1
    if context.deflect then self.counts.deflect_armed=self.counts.deflect_armed+1 end
    self:event('input_armed',{slot=slot,hit=key})
end

function Adapter:sensor_post(retval, context)
    if context.generated then
        if context.deflect then
            context.accepted=context.accepted==true and self:integer(retval)==0
            local counter=context.accepted and 'deflect_accepted' or 'deflect_rejected'
            self.counts[counter]=self.counts[counter]+1
            if context.accepted then
                local kind=context.defense_kind..'_accepted'
                self.counts[kind]=self.counts[kind]+1
            end
        end
        if context.accepted then self.counts.accepted=self.counts.accepted+1
        else self.counts.rejected=self.counts.rejected+1 end
        self:release(context)
        self:event('input_finished',{slot=context.slot,accepted=context.accepted==true})
    end
end

function Adapter:deflect_pre(args,context)
    local outer=self:current_sensor()
    if not outer or not outer.generated or not outer.deflect
        or outer.generation~=self.model.generation then return end
    local guard=self.env.sdk.to_managed_object(args[2])
    if self:token(guard)==outer.guard_supporter then context.outer=outer end
end

function Adapter:deflect_post(retval,context)
    if context.outer then
        if self:hook_bool(retval) then context.outer.accepted=true end
        self:event('native_deflect_check',{slot=context.outer.slot,result=self:hook_bool(retval)})
    end
    return retval
end

function Adapter:reaction_pre(args, context, slot)
    local outer=slot==0 and self:current_damage() or self:current_sensor()
    if not outer or not outer.generated or outer.slot ~= slot
        or outer.generation ~= self.model.generation then return end
    local player, hit = self.env.sdk.to_managed_object(args[2]),self.env.sdk.to_managed_object(args[3])
    if self:token(player)==outer.player and (slot==0 or self:token(hit)==outer.hit) then context.outer=outer end
end

function Adapter:reaction_post(retval, context)
    if context.outer then
        context.outer.request_count=(context.outer.request_count or 0)+1
        self.counts.action_requests=self.counts.action_requests+1
        if context.outer.slot==1 and self:hook_bool(retval) then context.outer.accepted=true end
        self:event('native_action_request',{slot=context.outer.slot,result=self:hook_bool(retval)})
    end
end

function Adapter:grab_gate_pre(args,context)
    local outer=self:current_sensor()
    if not outer or not outer.generated or (outer.slot~=1 and not outer.deflect)
        or outer.generation~=self.model.generation then return end
    if self:integer(args[3])~=outer.slot then return end
    local player=self.env.sdk.to_managed_object(args[2])
    local hit=self.env.sdk.to_managed_object(args[4])
    if self:token(player)==outer.player and self:token(hit)==outer.hit then context.outer=outer end
end

function Adapter:grab_gate_post(retval,context)
    if context.outer and not self:hook_bool(retval) and self:allowed()
        and context.outer.generation==self.model.generation then
        if context.outer.deflect and context.outer.slot==2 and self.model.options.auto_parry then
            -- TYPE2的外层要求实体防御命令；仅补足当前匹配命中的自动输入派发门槛。
            self.counts.deflect_gate_promoted=self.counts.deflect_gate_promoted+1
            return self.env.sdk.to_ptr(1)
        end
        if context.outer.slot~=1 or not self.model.options.auto_grab then return retval end
        -- 原版的抓取派发资格提升，仅限已确认COUNTER_GRAB属性的当前玩家/命中/TYPE1。
        -- 最终checkCounterGrab仍保留原生结果，不能把资格提升计为成功。
        self.counts.grab_gate_promoted=self.counts.grab_gate_promoted+1
        return self.env.sdk.to_ptr(1)
    end
    return retval
end

function Adapter:chain_owner(args)
    return self:owner(args,'app.cPlayerChainIssenSupporter','chain_issen_supporter')
end

-- 对应已反汇编Ready入口的引用链，不将输入上下文位集与控制器取消位集混用。
function Adapter:reference_at(object,offset)
    if not object then return nil end
    local td=object:get_type_definition()
    for depth=1,8 do
        if not td then break end
        for _,field in ipairs(td:get_fields()) do
            if not field:is_static() and field:get_offset_from_base()==offset then
                return field:get_data(object)
            end
        end
        td=td:get_parent_type()
    end
    return nil
end

function Adapter:ready_input_bitset(supporter)
    local owner=self:reference_at(supporter,0x10)
    local holder=self:reference_at(owner,0xe8)
    local command=self:reference_at(holder,0x10)
    local bitset=self:reference_at(command,0x50)
    self.metadata.chain_ready_path={owner=object_type(owner),holder=object_type(holder),
        command=object_type(command),bitset=object_type(bitset)}
    return bitset
end

function Adapter:chain_ready_pre(args, context, prepare)
    if not self:allowed() or not self.model.options.auto_chain then return end
    local supporter=self:chain_owner(args)
    if supporter then
        context.token=self:token(supporter)
        context.generation=self.model.generation
        if prepare then
            local hold=self:ready_input_bitset(supporter)
            context.ready_bitset=self:token(hold)
            self:chain_trace_event('chain_ready_path',self.metadata.chain_ready_path)
        end
    end
end

function Adapter:chain_ready_post(_, context)
    if context.token then
        self.model:chain_ready(context.token,self:now())
        self:event('chain_ready',{supporter=context.token})
    end
end

function Adapter:chain_damage_post(_, context)
    if context.token then
        self.model:chain_damage(context.token,self:now())
        self.counts.chain_damage=self.counts.chain_damage+1
        self:event('chain_damage',{supporter=context.token})
    end
end

-- 仅在游戏原生检测输入查询中补充一次输入；窗口、通知和动作都由原生调用者拥有。
function Adapter:chain_detection_pre(args,context)
    if not self:allowed() or not self.model.options.auto_chain then return end
    local supporter=self:chain_owner(args)
    if not supporter then return end
    context.supporter=supporter
    context.generation=self.model.generation
    self.counts.chain_detection_checks=self.counts.chain_detection_checks+1
end

-- 原生检测与可请求阶段互斥；检测结果保持原样，输入在实际控制器边界补足。
function Adapter:chain_detection_post(retval,context)
    return retval
end

function Adapter:chain_first_pre(args,context)
    if not self:allowed() or not self.model.options.auto_chain then return end
    local controller=self.env.sdk.to_managed_object(args[2])
    if object_type(controller)~='app.cPlayerChainIssenInputControllerEntity' then return end
    local entity,info=self:player()
    if not entity or self:token(self:call('controller_entity',info))~=self:token(controller) then return end
    local supporter=self:call('chain_issen_supporter',entity)
    self:chain_probe(object_type(controller),supporter,entity)
    local chain=self.model.chain
    if not supporter or not chain or chain.token~=self:token(supporter) or chain.submitted
        or chain.generation~=self.model.generation or self:now()-chain.updated>10 then return end
    if self:integer(self:call('chain_input_state',supporter))~=0
        or not self:call('chain_can_request_action',supporter) then return end
    context.controller=controller
    context.chain,context.generation=chain,self.model.generation
end

function Adapter:chain_default_pre(args,context)
    if not self:allowed() or not self.model.options.auto_chain then return end
    local controller=self.env.sdk.to_managed_object(args[2])
    if object_type(controller)~='app.cPlayerDefaultInputControllerEntity' then return end
    local entity,info=self:player()
    if not entity or self:token(self:call('controller_entity',info))~=self:token(controller) then return end
    self.counts.chain_default_checks=self.counts.chain_default_checks+1
    local supporter=self:call('chain_issen_supporter',entity)
    self:chain_probe(object_type(controller),supporter,entity)
    local chain=self.model.chain
    if not supporter or not chain or chain.token~=self:token(supporter) or chain.primed
        or chain.generation~=self.model.generation or self:now()-chain.updated>10 then return end
    if self:integer(self:call('chain_input_state',supporter))~=0 then return end
    local updater=self:call('chain_around_frame_updater',entity)
    if object_type(updater)~='app.cPlayerAroundFrameUpdater' then return end
    if not self:call('chain_hit_query',updater,0) or not self:call('chain_frame_active',updater,0)
        or self:integer(self:call('chain_frame_failure',updater,0))~=0 then return end
    self.counts.chain_native_hit_windows=self.counts.chain_native_hit_windows+1
    context.controller=controller
    context.chain,context.generation,context.prime=chain,self.model.generation,true
end

function Adapter:chain_bit_pre(args,context)
    local stack=self.controller_stacks[tostring(self.env.thread.get_hash())]
    local outer=stack and stack[#stack]
    if not outer then return end
    local bit=self:integer(args[3])
    if outer.ready_bitset and not outer.chain then
        if bit~=4 or not self:allowed() or not self.model.options.auto_chain then return end
        local bitset=self.env.sdk.to_managed_object(args[2])
        if object_type(bitset)=='ace.Bitset`1<System.Int32>' and self:token(bitset)==outer.ready_bitset then
            context.ready_outer=outer
        end
        return
    end
    if not outer.chain then return end
    if bit>=0 and bit<=63 then
        local key=tostring(bit)
        self.chain_input_observed[key]=(self.chain_input_observed[key] or 0)+1
    end
    if outer.bit_seen or bit~=9 then return end
    local bitset=self.env.sdk.to_managed_object(args[2])
    local command=self:call('command_result',outer.controller)
    local actual_type=object_type(bitset)
    self.metadata.chain_attack_bitset_type=actual_type
    if actual_type~='ace.Bitset`1<System.Int32>' then return end
    local expected=command and self.command_normal_field:get_data(command)
    if self:token(bitset)~=self:token(expected) then return end
    outer.bit_seen=true
    context.outer=outer
    self.counts.chain_attack_bit_checks=self.counts.chain_attack_bit_checks+1
end

function Adapter:chain_bit_post(retval,context)
    if context.ready_outer then
        if not self:hook_bool(retval) and self:allowed() and self.model.options.auto_chain
            and context.ready_outer.generation==self.model.generation then
            self:chain_trace_event('chain_ready_command',{bit=4})
            return self.env.sdk.to_ptr(1)
        end
        return retval
    end
    local outer=context.outer
    if not outer or not self:allowed() or not self.model.options.auto_chain
        or outer.generation~=self.model.generation or outer.chain~=self.model.chain then return retval end
    if self:hook_bool(retval) then
        -- 手动攻击由原生消费；不在后续帧重复补一个自动攻击。
        if outer.prime then outer.chain.primed=true else outer.chain.submitted=true end
        return retval
    end
    local flag=outer.prime and 'primed' or 'submitted'
    if outer.chain[flag] then return retval end
    outer.chain[flag]=true
    self.counts.chain_inputs=self.counts.chain_inputs+1
    if outer.chain.segment==0 then self.counts.chain_initial_inputs=self.counts.chain_initial_inputs+1 end
    self:event('chain_attack_input',{segment=outer.chain.segment,bit=9,phase=outer.prime and 'prime' or 'action'})
    return self.env.sdk.to_ptr(1)
end

function Adapter:hook(key,pre,post,stack_kind)
    self.env.sdk.hook(self.methods[key],function(args)
        local storage=self.env.thread.get_hook_storage()
        local context={}
        storage.onimusha_issen=context
        if stack_kind then
            local stack,token=self:stack(stack_kind)
            assert(#stack<8,'Hook recursion depth exceeded')
            stack[#stack+1]=context
            context.stack,context.thread_token=stack,token
        end
        local ok,err=pcall(pre or function() end,args,context)
        if not ok then self:fail(key..'_pre',err) end
        return self.env.sdk.PreHookResult.CALL_ORIGINAL
    end,function(retval)
        local context=self.env.thread.get_hook_storage().onimusha_issen or {}
        local ok,replacement=pcall(post or function(value) return value end,retval,context)
        if not ok then
            self:fail(key..'_post',replacement)
            if context.generated then
                local released,err=pcall(self.release,self,context)
                if not released then self:fail('cleanup',err) end
            end
        end
        if context.stack then
            if context.stack[#context.stack]~=context then self:fail('hook_stack','Unbalanced '..key)
            else context.stack[#context.stack]=nil end
            if #context.stack==0 then self[stack_kind..'_stacks'][context.thread_token]=nil end
        end
        if ok and replacement ~= nil then return replacement end
        return retval
    end)
end

function Adapter:discover()
    assert(self.env.sdk.get_tdb_version()==82,'Unsupported TDB version')
    for _,key in ipairs(CORE) do self:resolve(key) end
    for _,name in ipairs({'scene_current','scene_loading'}) do
        self:resolve(name,{lookup_type='via.SceneManager',declaring_type='via.SceneManager',
            name=name=='scene_current' and 'get_CurrentScene' or 'get_Loading',
            param_types={},return_type=name=='scene_current' and 'via.Scene' or 'System.Boolean',is_static=true})
    end
    for _,key in ipairs({'health_context','health_character','health_manager','health_value'}) do self:resolve(key) end
    local chain_ok,chain_error=pcall(function()
        for _,key in ipairs(CHAIN) do self:resolve(key) end
        local td=self.env.sdk.find_type_definition('app.cPlayerChainIssenSupporter')
        local field=assert(td:get_field('IsDetection'),'Missing IsDetection')
        assert(not field:is_static() and typename(field:get_type())=='System.Boolean','Wrong IsDetection field')
        self.detection_field=field
        local command_td=assert(self.env.sdk.find_type_definition('app.cPlayerCommandResult'))
        for _,candidate in ipairs(command_td:get_fields()) do
            if not candidate:is_static() and candidate:get_offset_from_base()==0x58 then
                -- 字段声明类型可与实际泛型对象不同；实际类型和身份在输入边界验证。
                self.metadata.chain_normal_field={name=candidate:get_name(),declared_type=typename(candidate:get_type()),offset=0x58}
                assert(not self.command_normal_field,'Ambiguous normal command field')
                self.command_normal_field=candidate
            end
        end
        assert(self.command_normal_field,'Missing native normal command bitset at 0x58')

    end)
    self.chain_ready=chain_ok
    if chain_ok then self.chain_error=nil else self.chain_error=tostring(chain_error) end
    local deflect_ok,deflect_error=pcall(function()
        for _,key in ipairs(DEFLECT) do self:resolve(key) end
    end)
    self.deflect_ready=deflect_ok
    if not deflect_ok then self.deflect_error=tostring(deflect_error) end
    if deflect_ok then self.deflect_error=nil end
    self.defense_metadata=self:inspect_defense_metadata()
    self.discovered=true
end

function Adapter:inspect_defense_metadata()
    local report={types={},errors={},static_reads=0,gameplay_writes=0}
    local pending={'app.cPlayerJustFrameUpdater.TYPE','app.CharacterDef.STYLE_TYPE',
        'app.cCharacterJustGuardSupporter.cInfo','app.cCharacterJustGuardSupporter',
        'app.AttackSensorHitInfo','app.cAttackParamDataBase.FLAG_BIT','app.cAttackRuntimeParamBase'}
    local seen={}
    local index=1
    while index<=#pending and index<=24 and #report.errors<3 do
        local name=pending[index];index=index+1
        if not seen[name] then
            seen[name]=true
            local ok,result=pcall(function()
                local td=self.env.sdk.find_type_definition(name)
                if not td then return {missing=true} end
                local result={fields={},methods={}}
                for fi,field in ipairs(td:get_fields()) do
                    if fi>128 then result.fields_truncated=true;break end
                    local ft=field:get_type()
                    local parent=ft and ft:get_parent_type()
                    local entry={name=field:get_name(),type=typename(ft),static=field:is_static(),
                        literal=field:is_literal(),offset=field:get_offset_from_base()}
                    if entry.static and entry.literal and report.static_reads<256 then
                        report.static_reads=report.static_reads+1
                        local value=field:get_data(nil)
                        entry.value=tostring(value)
                    end
                    if parent and typename(parent)=='System.Enum' and not seen[entry.type]
                        and #pending<24 then pending[#pending+1]=entry.type end
                    result.fields[#result.fields+1]=entry
                end
                for mi,method in ipairs(td:get_methods()) do
                    if mi>128 then result.methods_truncated=true;break end
                    local params={}
                    for _,pt in ipairs(method:get_param_types()) do params[#params+1]=typename(pt) end
                    result.methods[#result.methods+1]={name=method:get_name(),
                        returns=typename(method:get_return_type()),params=params,static=method:is_static(),
                        native=tostring(method:get_function())}
                end
                return result
            end)
            if ok then report.types[name]=result
            else report.errors[#report.errors+1]=name..': '..tostring(result) end
        end
    end
    return report
end

function Adapter:install()
    if self.installed then return end
    assert(self.discovered,'Discovery is required before hook installation')
    self:hook('request_counter_issen_action',function(a,c) self:reaction_pre(a,c,0) end,
        function(v,c) self:reaction_post(v,c) end)
    self:hook('check_counter_grab',function(a,c) self:reaction_pre(a,c,1) end,
        function(v,c) self:reaction_post(v,c) end)
    self:hook('is_enable_just_guard',function(a,c) self:grab_gate_pre(a,c) end,
        function(v,c) return self:grab_gate_post(v,c) end)
    self:hook('attack_sensor_hook',function(a,c) self:sensor_pre(a,c) end,
        function(v,c) self:sensor_post(v,c) end,'sensor')
    self:hook('hit_damage_hook',function(a,c) self:damage_pre(a,c) end,
        function(v,c) return self:damage_post(v,c) end,'damage')
    self:hook('check_counter_issen',function(a,c)
        local outer=self:current_damage()
        if outer and outer.generated and self:token(self.env.sdk.to_managed_object(a[2]))==outer.player then
            c.outer=outer
            outer.check_count=(outer.check_count or 0)+1
            self.counts.counter_checks=self.counts.counter_checks+1
        end
    end,function(v,c)
        if c.outer then
            c.outer.native_counter_result=self:hook_bool(v)
            self:event('native_counter_check',{result=c.outer.native_counter_result})
        end
        return v
    end)
    if self.deflect_ready then
        self:hook('try_just_guard',function(a,c) self:deflect_pre(a,c) end,
            function(v,c) return self:deflect_post(v,c) end)
    end
    if self.chain_ready then
        self:hook('chain_ready_detection',function(a,c) self:chain_ready_pre(a,c,true) end,
            function(v,c) self:chain_ready_post(v,c) end,'controller')
        self:hook('chain_damage_event',function(a,c) self:chain_ready_pre(a,c) end,
            function(v,c) self:chain_damage_post(v,c) end)
        self:hook('chain_fail_check',function(a,c) self:chain_ready_pre(a,c) end,function(v,c)
            if c.token and self:hook_bool(v) and self.model.chain
                and self.model.chain.token==c.token then
                local supporter
                local entity=self:player()
                supporter=entity and self:call('chain_issen_supporter',entity)
                if supporter and self:integer(self:call('chain_input_state',supporter))==2 then
                    self.model.chain=nil;self:event('chain_failed',{})
                else self.counts.chain_pending_fail=self.counts.chain_pending_fail+1 end
            end
        end)
        self:hook('chain_default_update',function(a,c) self:chain_default_pre(a,c) end,function(v,c)
            if c.chain and c.bit_seen then
                local entity=self:player()
                if entity then
                    local updater=self:call('chain_around_frame_updater',entity)
                    self:chain_trace_event('prime_native_result',{failure=self:integer(self:call('chain_frame_failure',updater,0)),
                        hit=self:call('chain_hit_query',updater,0),active=self:call('chain_frame_active',updater,0)})
                end
            end
            return v
        end,'controller')
        self:hook('chain_bitset_input',function(a,c) self:chain_bit_pre(a,c) end,
            function(v,c) return self:chain_bit_post(v,c) end)
        self:hook('chain_first_input_update',function(a,c) self:chain_first_pre(a,c) end,nil,'controller')
        self:hook('chain_detection_input',function(a,c) self:chain_detection_pre(a,c) end,
            function(v,c) return self:chain_detection_post(v,c) end)
    end
    self.installed=true
end

function Adapter:poll()
    if not self.discovered then return end
    local scene=self:call('scene_current',nil)
    local loading=self:call('scene_loading',nil)
    assert(type(loading)=='boolean','Invalid scene Loading')
    local scene_token=self:token(scene)
    if scene_token ~= self.scene or loading ~= self.loading then
        self.model:reset('scene_changed')
        self.scene,self.loading=scene_token,loading
        self:event('scene_changed',{scene=scene_token,loading=loading})
    end
    local entity=self:player()
    self.model:observe_player(self:token(entity))
    if not entity or loading or not scene then self.model.chain=nil end
end

function Adapter:set_options(options)
    -- Resolve any current generated slot before configuration invalidates its generation.
    for _,map in ipairs({self.sensor_stacks,self.damage_stacks}) do
        for _,stack in pairs(map) do
            for _,context in ipairs(stack) do self:release(context) end
        end
    end
    self.model:set_options(options)
    self.write_enabled=self.installed and #self.errors==0
end

function Adapter:status()
    return {ready=self.installed,write_enabled=self.write_enabled,chain_ready=self.chain_ready,
        deflect_ready=self.deflect_ready,deflect_error=self.deflect_error,deflect_profiles=self.deflect_profiles,
        chain_input_observed=self.chain_input_observed,native_health=self.native_health,defense_metadata=self.defense_metadata,
        chain_error=self.chain_error,counts=self.counts,errors=self.errors,events=self.events,chain_trace=self.chain_trace,
        metadata=self.metadata,generation=self.model.generation,scene=self.scene,loading=self.loading,
        chain=self.model.chain,options=self.model.options}
end

return Adapter
