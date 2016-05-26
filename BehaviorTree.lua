-- 行为树
local BehaviorTree = class("BehaviorTree")

local EVALUATE_TYPE = {
	SELECTOR    = "SEL",
	PARALLEL    = "PAR",
	SEQUENCE    = "SEQ",
	CONDITIONAL = "CON",
	BEHAVIOR    = "ACT",
}


local table_insert = table.insert
local table_remove = table.remove
local string_upper = string.upper
local string_match = string.match
local string_rep = string.rep
local string_len = string.len
local string_find = string.find
local string_sub = string.sub
local string_format = string.format
local ipairs = ipairs
local type = type
local tostring = tostring
local string_split = string.split or function (input, delimiter)
    input = tostring(input)
    delimiter = tostring(delimiter)
    if (delimiter=='') then return false end
    local pos,arr = 0, {}
    -- for each divider found
    for st,sp in function() return string_find(input, delimiter, pos, true) end do
        table_insert(arr, string_sub(input, pos, st - 1))
        pos = sp + 1
    end
    table_insert(arr, string_sub(input, pos))
    return arr
end
local util_filter = function(fn, datas)
	local result = {}
	for i, data in ipairs(datas) do
		if fn(data) then
			result[#result + 1] = data
		end
	end
	return result
end
local util_find = function ( fn, datas )
	for i, data in ipairs(datas) do
		if fn(data) then return data end
	end
end
-- 前期调试用,确定后改为nil或false
local debug = false

--[[

把字符串格式的AI行为树转换成程序使用的table格式

@param aistring: 		string 				字符串格式的AI行为树,参看e.g.

** e.g. **
SEL:AI
	SEQ:去球场打球
		CON:不是情人节:isNotValentinesDay
		ACT:去球场:gotoCourt
		ACT:打球:playBall
	SEL:约会
		SEL:买花
			SEQ:回家拿钱
				CON:女友没花:hasnotFlowerGF
				CON:自己没花没带够钱:hasnotFlowerSelf:100
				ACT:走回家:goHome 
				ACT:拿钱:fetchMoney
			SEQ:去花店买花
				CON:女友没花:hasnotFlowerGF
				CON:自己没花:hasnotFlowerSelf
				ACT:走去花店:gotoFlowerShop
				ACT:买花:buyFlower
		SEQ:见女友
			ACT:去找女友:gotoGF
			CON:女友还在:isHereGF
			CON:女友没花:hasnotFlowerGF
			ACT:送花:giveFlower
--]]
local function createAItable_(aistring)
	local aiarray = string_split(aistring, "\n")
	local defaultSpaceLen = nil
	local regString = "(%s*)(%S*)"
	local result = {}
	local stack = {}
	table_insert(stack, result)
	result.level = 1
	local function perpareInfo(singleString)
		local space, text = string_match(singleString, regString)
		local level = 1
		local spaceLen = string_len(space)
		if spaceLen > 0 then 
			if not defaultSpaceLen then defaultSpaceLen = spaceLen end
		end
		if defaultSpaceLen then 
			level = spaceLen / defaultSpaceLen + 1
		end
		local infos = string_split(text, ":")
		return level, string_upper(infos[1]), infos[2], infos[3], infos[4]
	end
	local function perpareAITable(level , bttype, name, fun, param)
		local cur = stack[#stack]
		if level > 1 and cur.level then 
			while cur.level >= level do
				table_remove(stack)
				cur = stack[#stack]
			end
		end
		local ischildren = false
		if #stack > 1 then 
			local curParent = stack[#stack - 1]
			if curParent.children and curParent.children == cur then 
				ischildren = true
			end
		end
		if not ischildren then 
			cur.level = level
			if string_find(bttype, "_") then 
				local bttypeTable = string_split(bttype, "_")
				cur.bttype = bttypeTable[1]
				cur.bttypeParam = bttypeTable[2]
			else
				cur.bttype = bttype
			end
			if debug then 
				cur.name = name
			end
			cur.fun = fun 
			cur.param = param
			local tempBttype = cur.bttype
			if tempBttype == EVALUATE_TYPE.SELECTOR  
				or tempBttype == EVALUATE_TYPE.SEQUENCE  
				or tempBttype == EVALUATE_TYPE.PARALLEL  
				then 
				cur.children = {}
				cur.children.level = level
				table_insert(stack, cur.children)
			else
				table_remove(stack)
			end
		else
			local newChild = {}
			table_insert(cur, newChild)
			table_insert(stack, newChild)
			perpareAITable(level , bttype, name, fun, param)
		end
	end
	for i, v in ipairs(aiarray) do
		if v ~= "" then  
			local level , bttype, name, fun, param = perpareInfo(v)
			perpareAITable(level , bttype, name, fun, param)
		end
	end
	return result
end

function BehaviorTree:ctor( fulltree )
	if type(fulltree) == "string" then 
		self.fulltree = createAItable_(fulltree)
	else
		self.fulltree = fulltree
	end
end

function BehaviorTree:behave( entity )
	self:behave_(self.fulltree, entity)
end

local function logState_( tree, entity )
	-- if true and entity.params_.debug then 
		print(string_format("%d.%s:%s:%s", tree.level, string_rep("  ", tree.level), tree.bttype, tree.name))
	-- end
end

function BehaviorTree:behave_( tree, entity )
	local behaveType = tree.bttype
	if behaveType == EVALUATE_TYPE.CONDITIONAL then 
		-- 处理条件判断 CON
		return self:condition_(tree, entity)
	elseif behaveType == EVALUATE_TYPE.BEHAVIOR then 
		-- 处理动作 ACT
		return self:action_(tree, entity)
	elseif behaveType == EVALUATE_TYPE.SELECTOR then 
		-- 处理选择执行 SEL
		return self:select_(tree, entity)
	elseif behaveType == EVALUATE_TYPE.SEQUENCE then 
		-- 处理顺序执行 SEQ
		return self:sequence_(tree, entity)
	elseif behaveType == EVALUATE_TYPE.PARALLEL then 
		-- 处理并列执行 PAR
		return self:parallel_(tree, entity)
	end
	return false
end

function BehaviorTree:select_( tree, entity )
	local children = tree.children
	local result = util_find(function ( child, index )
		return self:behave_(child, entity)
	end, children)
	return result ~= nil
end

function BehaviorTree:sequence_( tree, entity )
	local children = tree.children
	local result = util_find(function ( child, index )
		return not self:behave_(child, entity)
	end, children)
	return result == nil
end

function BehaviorTree:parallel_( tree, entity )
	local children = tree.children
	local filterResult = util_filter(function ( child, index )
		return self:behave_(child, entity)
	end, children)
	local trueCount = #filterResult
	local allCount = #children
	local bttypeParam = tree.bttypeParam or "ALL"
	local result = false
	if "ALL" == bttypeParam then 
		-- Parallel Succeed On All Node: 所有True才返回True，否则返回False。
		result = trueCount == allCount
	elseif "TRUE" == bttypeParam then 
		result = true
	elseif "FALSE" == bttypeParam then 
		result = false
	else
		-- Parallel Hybird Node: 指定数量的Child Node返回True或False后才决定结果
		local count = tonumber(bttypeParam)
		if count then
			result = trueCount >= count
		end
	end
	return result
end

function BehaviorTree:condition_( tree, entity )
	return self:do_(tree, entity, "condition")
end

function BehaviorTree:action_( tree, entity )
	return self:do_(tree, entity, "action") ~= false
end

function BehaviorTree:do_( tree, entity, typeStr )
	if debug then 
		logState_( tree, entity )
		local fun = tree.fun
		if not type(entity[fun]) == "function" then
			error("BehaviorTree %s_() can't find a function [%s(%s)] in entity"
				, typeStr, fun, tree.param or "")
		end
	end
	return entity[tree.fun](entity, tree.param)
end

return BehaviorTree