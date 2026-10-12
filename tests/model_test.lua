local Model = dofile(ROOT .. '/reframework/autorun/onimusha_issen/model.lua')
local checks = 0
local function eq(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, message .. ': ' .. tostring(actual))
end
local model = Model.new()
eq(model:choose(false, false), nil, '默认关闭')
model:set_options({auto_issen=true, auto_chain=true, auto_grab=true})
eq(model:choose(false, false), 0, '普通攻击对应TYPE0')
eq(model:choose(true, true), 1, '可反制抓取对应TYPE1')
eq(model:choose(true, false), nil, '不可反制抓取不伪装为一闪')
model:observe_player('playerA')
eq(model:claim_hit('hit', 1), true, '首次事件')
eq(model:claim_hit('hit', 1.05), false, '重复碰撞')
eq(model:claim_hit('hit', 1.2), true, '超过重复窗口允许复用ID')
model:chain_ready('supporterA', 1.2)
eq(model:claim_chain('supporterA', 0, false, true, 1.2), true, '原生允许首段')
eq(model:claim_chain('supporterA', 0, false, true, 1.3), false, '同段仅一次')
model:chain_damage('supporterA', 1.4)
eq(model:claim_chain('supporterA', 0, true, false, 1.4), true, '命中后检测窗续段')
eq(model:claim_chain('supporterA', 0, true, false, 1.5), false, '同续段仅一次')
model:chain_ready('supporterA', 1.6)
eq(model:claim_chain('supporterA', 0, false, false, 1.6), false, '准备通知不能提前派发')
eq(model:claim_chain('supporterA', 1, true, true, 1.6), false, '不覆盖原生已有输入')
model:observe_player('playerB')
eq(model:claim_chain('supporterA', 0, true, true, 1.7), false, '换玩家清除旧连锁')
eq(model:claim_hit('hit', 1.21), true, '换玩家清除旧碰撞')
model:chain_ready('supporterB', 2)
eq(model:claim_chain('supporterB', 0, true, true, 30), false, '旧连锁会话失效')
model:chain_ready('supporterB', 31)
model:reset('scene')
eq(model:claim_chain('supporterB', 0, true, true, 31), false, '场景切换清除状态')
model:chain_ready('supporterB', 32)
model:set_options({auto_issen=false, auto_chain=false, auto_grab=false})
eq(model:claim_chain('supporterB', 0, true, true, 32), false, '关闭无派发')
eq(model:choose(false, false), nil, '关闭恢复原生输入')
eq(model.options.auto_kakei,false,'旧配置化劲默认关闭')
eq(model.options.auto_parry,false,'旧配置弹刀默认关闭')
for _,kakei in ipairs({false,true}) do
    for _,parry in ipairs({false,true}) do
        model:set_options({auto_issen=true,auto_chain=true,auto_grab=true,auto_kakei=kakei,auto_parry=parry})
        for mask=0,31 do
            local e={};for slot=0,4 do e[slot]=(mask & (1<<slot))~=0 end
            for flags=0,7 do
                local f={unable_issen=(flags&1)~=0,unable_parry=(flags&2)~=0,unable_block=(flags&4)~=0}
                local expected=nil
                if (f.unable_issen or not e[0]) and not e[1] and e[3] then
                    if kakei and not f.unable_parry then expected=3
                    elseif parry and not f.unable_block then expected=2 end
                end
                eq(model:choose_deflect(e,f),expected,'两开关/全部资格/禁止属性矩阵')
            end
        end
    end
end
return checks
