local Tinkr, Bastion = ...

-- 创建模块
local HunterModule = Bastion.Module:New('HunterModule')

-- 获取玩家和目标单位
local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local Pet = Bastion.UnitManager:Get('pet')
local PetTarget = Bastion.UnitManager:Get('pettarget')

-- 创建法术书
local SpellBook = Bastion.SpellBook:New()

-- 定义技能
-- 基础技能
local shalumingling = SpellBook:GetSpell(34026)           -- 杀戮命令
local Intimidation = SpellBook:GetSpell(19263)            -- 威慑
local AspectOfTheViper = SpellBook:GetSpell(34074)        -- 蝰蛇守护
local AspectOfTheDragonhawk = SpellBook:GetSpell(61847)   -- 龙鹰守护
local TrapSpell = SpellBook:GetSpell(425777)              -- 陷阱技能
local MultiShotSpell = SpellBook:GetSpell(58434)          -- 乱射技能
local KillShot = SpellBook:GetSpell(61006)                -- 杀戮射击
local SteadyShot = SpellBook:GetSpell(49052)              -- 稳固射击
local ExplosiveShot = SpellBook:GetSpell(60053)           -- 爆炸射击4
local ExplosiveShott = SpellBook:GetSpell(60052)          -- 爆炸射击3
local BlackArrow = SpellBook:GetSpell(63672)              -- 黑箭
local AimedShot = SpellBook:GetSpell(49050)               -- 瞄准射击
local MultiShot = SpellBook:GetSpell(49048)               -- 多重射击
local Serpent = SpellBook:GetSpell(49001)                 -- 毒蛇钉刺
local HuntersMark = SpellBook:GetSpell(53338)             -- 猎人印记
local heqiang = SpellBook:GetSpell(56453)                 -- 荷枪实弹
local CallPet1 = SpellBook:GetSpell(883)                  -- 召唤宠物

-- 找目标
local BestTarget = Bastion.UnitManager:CreateCustomUnit('besttarget', function()
    local bestTarget = nil
    local highestHealth = 0
    
    -- 遍历所有敌人，寻找最适合的目标
    Bastion.UnitManager:EnumEnemies(function(unit)
        -- 检查目标是否符合条件：
        -- 1. 正在战斗中
        -- 2. 在40码范围内
        -- 3. 玩家可以看见该目标
        if unit:IsAffectingCombat() and unit:GetDistance(Player) <= 35 and Player:CanSee(unit)
        and unit:GetDistance(Player) >= 5 then
            local health = unit:GetHealth()
            -- 选择生命值最高的目标
            if health > highestHealth then
                highestHealth = health
                bestTarget = unit
            end
        end
    end)
    
    -- 如果没找到合适目标，返回当前目标
    return bestTarget or Bastion.UnitManager:Get('none')
end)

-- 选择目标
local function CheckAndSetTarget()
    if not Target:Exists() or Target:IsFriendly() or not Target:IsAlive() then
        if BestTarget.unit then -- 检查返回值有效
        -- 检查是否没有当前目标，或当前目标是友善的
            SetTargetObject(BestTarget.unit)
            return true
        end
    end
    return false
end

-- 斩杀目标
local ExecuteTarget = Bastion.UnitManager:CreateCustomUnit('executetarget', function()
    local target = nil
    Bastion.UnitManager:EnumEnemies(function(unit)
        -- 检查目标是否：
        -- 1. 正在战斗中
        -- 2. 在40码范围内
        -- 3. 玩家可以看见该目标
        -- 4. 生命值低于20%(斩杀线)
        if unit:IsAffectingCombat() and unit:GetDistance(Player) <= 45 and Player:CanSee(unit)
           and unit:GetDistance(Player) >= 5
           and unit:GetHP() < 20 and unit:GetName() ~= "坍缩星" then
            target = unit
            return true  -- 找到合适目标后立即返回
        end
    end)
    return target or Bastion.UnitManager:Get('none')
end)

-- 荷枪实弹层数
local function GetheqiangStack()
    return Player:GetAuras():FindMy(heqiang):GetCount()
end

-- ===================== APL定义 =====================
local ExecuteAPL = Bastion.APL:New('execute')         -- 斩杀
local DefaultAPL = Bastion.APL:New('default')         -- 默认输出循环
local DefensiveAPL = Bastion.APL:New('defensive')     -- 防御循环
local AoEAPL = Bastion.APL:New('aoe')                 -- AOE循环
local ResourceAPL = Bastion.APL:New('resource')       -- 资源管理循环
local PetControlAPL = Bastion.APL:New('petcontrol')   -- 宠物控制
local DefaultSPAPL = Bastion.APL:New('DefaultSP')     -- 简单模式

-- ===================== 防御循环 =====================
-- 威慑
DefensiveAPL:AddSpell(
    Intimidation:CastableIf(function(self)
        return Player:GetHP() <= 30 and
               Player:IsAffectingCombat()
    end):SetTarget(Player):PreCast(function(self)
        if Player:IsCastingOrChanneling() then
            SpellStopCasting()
        end
    end)
)

-- 召唤宠物
PetControlAPL:AddSpell(
    CallPet1:CastableIf(function(self)
        return not Pet:Exists()
            and self:IsKnownAndUsable()
            and not Player:IsCastingOrChanneling()
    end):SetTarget(Player)
)

-- 宠物攻击
PetControlAPL:AddAction("PetAttack", function()
    if Pet:Exists()
        and not PetTarget:Exists()
		and HERUIPetAttack()
		and Target:IsAlive()
        and Target:Exists() then
        PetAttack()
        return true
    end
    return false
end)

---- 宠物跟随
PetControlAPL:AddAction("PetFollow", function()
    if Pet:Exists()
        and PetTarget:Exists()
		and HERUIPetFollow() then
        PetFollow()
        return true
    end
    return false
end)

-- ===================== 资源管理循环 =====================
-- 守护切换
-- 蝰蛇
ResourceAPL:AddSpell(
    AspectOfTheViper:CastableIf(function(self)
        return Player:GetPP(0) <= 7 and
               Player:GetAuras():FindMy(AspectOfTheDragonhawk):IsUp() and
               Player:IsAffectingCombat() and
               not Player:IsCastingOrChanneling()
    end):SetTarget(Player)
)

-- 龙鹰
ResourceAPL:AddSpell(
    AspectOfTheDragonhawk:CastableIf(function(self)
        return Player:GetPP(0) >= 50 and
               not Player:GetAuras():FindMy(AspectOfTheDragonhawk):IsUp() and
               Player:IsAffectingCombat() and
               not Player:IsCastingOrChanneling()
    end):SetTarget(Player)
)

-- 斩杀射击
ResourceAPL:AddSpell(
    KillShot:CastableIf(function(self)
        return ExecuteTarget:Exists() and
               Player:IsAffectingCombat() and
               Player:GetGCD() < 0.2
    end):SetTarget(ExecuteTarget):PreCast(function(self)  
        if Player:IsCastingOrChanneling() then
            SpellStopCasting()
        end
    end)
)

-- 杀戮命令
ResourceAPL:AddSpell(
    shalumingling:CastableIf(function(self)
        return Target:Exists()
		    and Target:IsAlive()
            and self:IsKnownAndUsable()
            and Player:IsAffectingCombat()
    end):SetTarget(Target)
)

-- ===================== AOE循环 =====================
-- 在AOE APL部分修改
-- 爆炸陷阱
AoEAPL:AddSpell(
    TrapSpell:CastableIf(function(self)
        return Target:Exists()
		    and self:IsKnownAndUsable() 
			and not Player:IsCastingOrChanneling()
			and Target:IsAlive()
			and Target:IsEnemy()
			and HERUIExplosiveTrap()
    end):SetTarget(Target):OnCast(function(self)
        -- 检查是否需要点选位置
        if IsSpellPending() == 64 then
            -- 获取目标位置
            local x, y, z = ObjectPosition(Target:GetOMToken())
            -- 如果位置有效，点击释放
            if x and y and z then
                self:Click(x, y, z)
            end
        end
    end)
)

-- 乱射(密集点放置)
AoEAPL:AddSpell(
    MultiShotSpell:CastableIf(function(self)
        return Target:Exists()
		    and self:IsKnownAndUsable() 
			and not Player:IsCastingOrChanneling()
			and Target:IsAlive()
            and Target:IsEnemy()
    end):SetTarget(Target):OnCast(function(self)
        -- 检查是否需要点选位置
        if IsSpellPending() == 64 then
            -- 获取目标位置
            local x, y, z = ObjectPosition(Target:GetOMToken())
            -- 如果位置有效，点击释放
            if x and y and z then
                self:Click(x, y, z)
            end
        end
    end)
)

-- ===================== 默认循环 =====================
-- 爆炸陷阱
DefaultAPL:AddSpell(
    TrapSpell:CastableIf(function(self)
        return Target:Exists()
		    and self:IsKnownAndUsable()
			and HERUIExplosiveTrap()
			and Target:IsAlive()
			and Target:IsEnemy()
    end):SetTarget(Target):OnCast(function(self)
        -- 检查是否需要点选位置
        if IsSpellPending() == 64 then
            -- 获取目标位置
            local x, y, z = ObjectPosition(Target:GetOMToken())
            -- 如果位置有效，点击释放
            if x and y and z then
                self:Click(x, y, z)
            end
        end
    end)
)

-- 爆炸射击4
DefaultAPL:AddSpell(
    ExplosiveShot:CastableIf(function(self)
        return Target:Exists()
		    and Target:IsAlive()
            and self:IsKnownAndUsable()
			and (GetheqiangStack() == 2 or GetheqiangStack() == 0)
    end):SetTarget(Target)
)

-- 爆炸射击3
DefaultAPL:AddSpell(
    ExplosiveShott:CastableIf(function(self)
        return Target:Exists()
		    and Target:IsAlive()
            and self:IsKnownAndUsable()
			and GetheqiangStack() == 1
    end):SetTarget(Target)
)

-- 黑箭
DefaultAPL:AddSpell(
    BlackArrow:CastableIf(function(self)
        return Target:Exists()
		    and Target:IsAlive()
            and self:IsKnownAndUsable()
			and HERUIBlackArrow()
    end):SetTarget(Target)
)

-- 毒蛇钉刺
DefaultAPL:AddSpell(
    Serpent:CastableIf(function(self)
        return Target:Exists()
            and Target:IsAlive()
            and self:IsKnownAndUsable()
            and (
                not Target:GetAuras():FindMy(Serpent):IsUp()
                or Target:GetAuras():FindMy(Serpent):GetRemainingTime() <= 1
            )
            and ExplosiveShot:GetCooldownRemaining() > 0.5
            and TrapSpell:GetCooldownRemaining() > 0.5
    end):SetTarget(Target)
)

-- 多重射击
DefaultAPL:AddSpell(
    MultiShot:CastableIf(function(self)
        return Target:Exists() 
		    and Target:IsAlive()
            and self:IsKnownAndUsable() 
			and HERUIMultiShot()
			and ExplosiveShot:GetCooldownRemaining() > 0.5
			and TrapSpell:GetCooldownRemaining() > 0.5
    end):SetTarget(Target)
)

-- 瞄准射击
DefaultAPL:AddSpell(
    AimedShot:CastableIf(function(self)
        return Target:Exists() 
		    and Target:IsAlive()
            and self:IsKnownAndUsable()
			and HERUIAimedShot()
			and ExplosiveShot:GetCooldownRemaining() > 0.5
			and TrapSpell:GetCooldownRemaining() > 0.5
    end):SetTarget(Target)
)

-- 猎人印记
DefaultAPL:AddSpell(
    HuntersMark:CastableIf(function(self)
        return Target:Exists()
		    and Target:IsAlive()
            and self:IsKnownAndUsable()
            and not Target:GetAuras():FindAny(HuntersMark):IsUp()
			and ExplosiveShot:GetCooldownRemaining() > 0.5
			and TrapSpell:GetCooldownRemaining() > 0.5
			and AimedShot:GetCooldownRemaining() > 0.5
    end):SetTarget(Target)
)

-- 稳固射击（填充技能）
DefaultAPL:AddSpell(
    SteadyShot:CastableIf(function(self)
        return ExplosiveShot:GetCooldownRemaining() > 1
            and TrapSpell:GetCooldownRemaining() > 1
            and Target:Exists()
            and Target:IsAlive()
            and self:IsKnownAndUsable()
            and AimedShot:GetCooldownRemaining() > 0.5
            and Target:GetAuras():FindMy(Serpent):GetRemainingTime() > 0.5
    end):SetTarget(Target)
)

-- ===================== 简单循环 =====================
-- 爆炸射击4
DefaultSPAPL:AddSpell(
    ExplosiveShot:CastableIf(function(self)
        return Target:Exists()
		    and Target:IsAlive()
            and self:IsKnownAndUsable()
			and GetheqiangStack() == 2
    end):SetTarget(Target)
)

-- 爆炸射击3
DefaultSPAPL:AddSpell(
    ExplosiveShott:CastableIf(function(self)
        return Target:Exists()
		    and Target:IsAlive()
            and self:IsKnownAndUsable()
			and GetheqiangStack() == 1
    end):SetTarget(Target)
)

-- 爆炸射击4
DefaultSPAPL:AddSpell(
    ExplosiveShot:CastableIf(function(self)
        return Target:Exists()
		    and Target:IsAlive()
            and self:IsKnownAndUsable()
			and GetheqiangStack() == 0
    end):SetTarget(Target)
)

-- 多重射击
DefaultSPAPL:AddSpell(
    MultiShot:CastableIf(function(self)
        return ExplosiveShot:GetCooldownRemaining() > 1
            and Target:Exists() 
		    and Target:IsAlive()
            and self:IsKnownAndUsable() 
			and HERUIMultiShot()
    end):SetTarget(Target)
)

-- 瞄准射击
DefaultSPAPL:AddSpell(
    AimedShot:CastableIf(function(self)
        return ExplosiveShot:GetCooldownRemaining() > 1
            and Target:Exists() 
		    and Target:IsAlive()
            and self:IsKnownAndUsable()
			and HERUIAimedShot()
    end):SetTarget(Target)
)

-- 稳固射击（填充技能）
DefaultSPAPL:AddSpell(
    SteadyShot:CastableIf(function(self)
        return ExplosiveShot:GetCooldownRemaining() > 1
            and Target:Exists()
            and Target:IsAlive()
            and self:IsKnownAndUsable()
            and AimedShot:GetCooldownRemaining() > 0.5
    end):SetTarget(Target)
)

-- ===================== 模块同步 =====================
HunterModule:Sync(function()
    -- 最高优先级：防御和资源管理
    DefensiveAPL:Execute()
    ResourceAPL:Execute()
    PetControlAPL:Execute()
    
    -- 战斗中切目标
    if Player:IsAffectingCombat() then
        CheckAndSetTarget()
    end
    if HERUIAOE() then
        AoEAPL:Execute()
    end
    if HERUINormal() then
        DefaultAPL:Execute()
    end
    if HERUISimple() then
        DefaultSPAPL:Execute()
    end
end)
-- ===================== 9. 注册模块 =====================
Bastion:Register(HunterModule)