--[[
	A basic javascript-like class module.
	This is very light, and structures your script as well.

	Usage:
		local Class = require(path.to.module)
  		local CLASSNAME = Class:create("CLASSNAME") -- Create pure class
  
  		local CHILDCLASSNAME = CLASSNAME:inherit("CHILDCLASSNAME") -- Inherit class
  
  		function CLASSNAME:constructor(super, ...) super(var1, var2, ...) --[call super constructor] end -- Assign class constructor function
  		function CLASSNAME:destructor(super, ...) super(var1, var2, ...) --[call super destructor] end -- Assign class destructor function
  
  		function CLASSNAME:foo(...) end -- Add new function
  
  		locla obj = CLASSNAME(var1, var2, ...) -- Create object
  		obj:destroy() -- Destroy object
  
  		print(obj:__is(CLASSNAME)) -- Return object is given class or given the class' child's class
  		print(obj:__isStatic(CLASSNAME)) -- Return object is whether it's static or not
  		print(obj:__name(CLASSNAME)) -- Return object's name for programmer
  		print(obj:__tostring(CLASSNAME)) -- (A customizable implement function) Return object's status *USUALLY*

	LICENCE:
		Licenced under the MIT licence
]]--


local Class = {} -- Base index
Class.__index = Class

local HTTP_SERVICE = game:GetService("HttpService")
local RUN_SERVICE = game:GetService("RunService")

local ERR_CLASS_NOT_BASECLASS = "Given class is not baseclass"
local ERR_CLASS_NOT_STATIC = "Given class is not static"
local ERR_CLASS_NOT_DYNAMIC = "Given class is not dynamic"
local WARN_NO_RESULT = "Couldn't find result from given index"
local WARN_NO_CONSTRUCTOR = "No constructor found from class or super"
local WARN_NO_DESTRUCTOR = "No destructor found from class or super"

-- Sorting class's supers list to be reversed to call con/destructor in order
local function sortReverse(tbl)
	local newTbl = table.clone(tbl)
	
	for i, v in pairs(tbl) do
		newTbl[#tbl - i + 1] = v
	end
	
	return newTbl
end

function Class:__call(...) -- Create object
	assert(self:__isStatic(), ERR_CLASS_NOT_STATIC) -- Non-static confirm
	local obj = {
		["__id"] = string.gsub(HTTP_SERVICE:GenerateGUID(false), "-", "") -- giving internal (is able to use as extending) class id to define unique object 
	}
	
	local super = sortReverse(self.__super) -- Sort super by reversing
	local superIndex = 1
	
	local superFunc
	superFunc = function(...) -- Contructor's super calling function
		if super[superIndex] ~= nil then
			superIndex += 1
			if super[superIndex - 1].constructor then
				super[superIndex - 1].constructor(obj, superFunc, ...)
			else
				warn(WARN_NO_CONSTRUCTOR)
			end
		end
	end
	
	if self.constructor ~= nil then
		self.constructor(obj, superFunc, ...) -- First super call
	else
		warn(WARN_NO_CONSTRUCTOR)
	end
	return setmetatable(obj, self)
end

function Class:destroy() -- Destroy object
	assert(not self:__isStatic(), ERR_CLASS_NOT_DYNAMIC) -- Non-static confirm
	local super = sortReverse(getmetatable(self).__super) -- Sort super by reversing
	local superIndex = 1

	local superFunc
	superFunc = function() -- Destructor's super calling function
		if super[superIndex] then
			superIndex += 1
			if super[superIndex - 1].destructor then
				super[superIndex - 1].destructor(self, superFunc)
			else
				warn(WARN_NO_DESTRUCTOR)
			end
		end
	end

	if getmetatable(self).destructor ~= nil then
		getmetatable(self).destructor(self, superFunc) -- First super call
	else
		warn(WARN_NO_DESTRUCTOR)
	end
	
	setmetatable(self, nil)
	table.clear(self)
end

function Class:constructor() -- Empty constructor
end

function Class:destructor() -- Empty destructor
end

function Class:create(className) -- Create highest class
	assert(self == Class, ERR_CLASS_NOT_BASECLASS)
	local newClass = {
		["__typename"] = className, -- Tyfifies class name for programmers
		["__super"] = {
			self
		}
	}
	
	newClass.__index = function(self, index) -- Connecting class' variable
		if getmetatable(self)[index] ~= nil then
			return getmetatable(self)[index]
		end
		for i, v in pairs(sortReverse(getmetatable(self).__super)) do
			if v[index] ~= nil then
				return v[index]
			end
		end
		warn(WARN_NO_RESULT, index)
		
		return nil
	end
	return setmetatable(newClass, Class)
end

function Class:inherit(classType) -- Inherit given class
	assert(self:__isStatic(), ERR_CLASS_NOT_STATIC) -- Static confirm
	local newClass = Class:create(classType) -- Making pure class
	
	newClass.__super = table.clone(self.__super) -- Indexing super
	table.insert(newClass.__super, self)
	return newClass
end

function Class:__is(givenClass) -- Determine what the given class is
	if getmetatable(self) == givenClass and givenClass ~= Class then
		return true
	end
	for i, v in pairs(self.__super) do
		if v == givenClass and givenClass ~= Class then
			return true
		end
	end
	if getmetatable(givenClass) ~= nil and getmetatable(givenClass) ~= Class then
		return self:__is(getmetatable(givenClass))
	end
	return false
end

function Class:__isStatic() -- Determine which is static
	return self.__id == nil
end

function Class:__name() -- Return, for programmer, class name
	return getmetatable(self).__typename or "Unknown"
end

function Class:__tostring() -- Recommending to overwrite to use to return class status
	return "Class"
end

return Class