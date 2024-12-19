local Tinkr, Bastion = ...

local testmode = Bastion.Module:New('test')

-- 获取玩家和目标单位
local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')

-- 创建法术书
local SpellBook = Bastion.SpellBook:New()

local FlashHeal = SpellBook:GetSpell(48066)
local BUFF = SpellBook:GetSpell(6788)

-- 创建一个追踪血量最低友方单位的自定义单位
local Lowest = Bastion.UnitManager:CreateCustomUnit('lowest', function(unit)
    local lowest = nil
    local lowestHP = math.huge  -- 初始化最低血量为无限大

    -- 遍历所有友方单位
    Bastion.UnitManager:EnumFriends(function(unit)
        -- 检查单位是否可用（未死亡、在距离内、可见）
        if unit:IsDead() or Player:GetDistance(unit) > 40 or not Player:CanSee(unit) then
            return false
        end

        -- 更新最低血量单位
        local hp = unit:GetHP()
        if hp < lowestHP then
            lowest = unit
            lowestHP = hp
        end
    end)

    return lowest or Player  -- 如果没找到则返回玩家自身
end)

local DefaultAPL = Bastion.APL:New('default')       -- 默认优先级

-- 快速治疗优先级设置
DefaultAPL:AddSpell(
    FlashHeal:CastableIf(function(self)
        return Lowest:Exists() and self:IsKnownAndUsable() 
            and not Player:IsCastingOrChanneling()
            and not Lowest:GetAuras():FindAny(FlashHeal):IsUp()
            and not Lowest:GetAuras():FindAny(BUFF):IsUp()
    end):SetTarget(Lowest)  -- 对血量最低的目标使用
)

testmode:Sync(function()
    DefaultAPL:Execute()      -- 然后执行常规治疗
end)

Bastion:Register(testmode)