-- 独立状态模型。这里不持有托管对象、不调用游戏接口。
local Model = {}
Model.__index = Model

function Model.new()
    return setmetatable({options={auto_issen=false,auto_chain=false,auto_grab=false,auto_kakei=false,auto_parry=false},
        generation=0, player=nil, hits={}, chain=nil}, Model)
end

function Model:reset(reason)
    self.generation = self.generation + 1
    self.hits, self.chain = {}, nil
    self.last_reset = reason
end

function Model:set_options(options)
    for _, key in ipairs({'auto_issen','auto_chain','auto_grab'}) do
        assert(type(options[key]) == 'boolean', 'Invalid option: ' .. key)
    end
    for _,key in ipairs({'auto_kakei','auto_parry'}) do
        assert(options[key]==nil or type(options[key])=='boolean','Invalid option: '..key)
    end
    self.options = {auto_issen=options.auto_issen,auto_chain=options.auto_chain,auto_grab=options.auto_grab,
        auto_kakei=options.auto_kakei==true,auto_parry=options.auto_parry==true}
    self:reset('options_changed')
end

-- 分开选择两种原生输入，不由玩家持刀姿态替用户选择。
-- 仅处理无法一闪且具有原生近战防御派发资格的攻击。
function Model:choose_deflect(eligibility,flags)
    if not flags.unable_issen and eligibility[0]~=false then return nil end
    if eligibility[1]~=false or eligibility[3]~=true then return nil end
    if self.options.auto_kakei and not flags.unable_parry then return 3 end
    if self.options.auto_parry and not flags.unable_block then return 2 end
    return nil
end

function Model:observe_player(token)
    if token ~= self.player then
        self:reset('player_changed')
        self.player = token
    end
end

function Model:choose(grapple, counter_grab)
    if counter_grab then return self.options.auto_grab and 1 or nil end
    if grapple then return nil end
    return self.options.auto_issen and 0 or nil
end

function Model:claim_hit(key, now)
    local count = 0
    for previous, stamp in pairs(self.hits) do
        if now - stamp >= 0.12 or now < stamp then self.hits[previous] = nil
        else count = count + 1 end
    end
    if self.hits[key] ~= nil or count >= 128 then return false end
    self.hits[key] = now
    return true
end

function Model:chain_ready(token, now)
    if not self.options.auto_chain then return end
    -- Ready 会重置原生支持器；如果同段重复 Ready，保留已派发标记。
    if self.chain and self.chain.token == token and now-self.chain.updated < 0.12 then return end
    self.chain = {token=token,segment=0,submitted=false,updated=now,generation=self.generation}
end

function Model:chain_damage(token, now)
    local chain = self.chain
    if chain and chain.token == token then
        chain.segment = chain.segment + 1
        chain.submitted, chain.primed, chain.updated = false, false, now
    end
end

function Model:claim_chain(token, input_state, detection, can_request, now)
    local chain = self.chain
    if not self.options.auto_chain or not chain or chain.token ~= token
        or chain.generation ~= self.generation or input_state ~= 0
        or now-chain.updated > 10 or now < chain.updated or chain.submitted then return false end
    -- 首段只接受游戏本身的可派发状态；续段还可使用命中后的原生检测窗。
    if not can_request and not (chain.segment > 0 and detection) then return false end
    chain.submitted, chain.updated = true, now
    return true
end

return Model
