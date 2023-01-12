local REPLICATED_STORAGE = game:GetService("ReplicatedStorage")
local RUN_SERVICE = game:GetService("RunService")

local Class = require(REPLICATED_STORAGE.Classes.Class)
local Utility = Class:create("Utility")

local control = script:FindFirstChild("AirFlow-Connection") or (RUN_SERVICE:IsServer() and Instance.new("RemoteEvent") or script:WaitForChild("AirFlow-Connection"))
control.Name = "AirFlow-Connection"

function Utility:constructor(super, id, player)
	self._cons = {}
	self.__id = id
	self._player = player
	
	if RUN_SERVICE:IsServer() then
		return control.OnServerEvent:Connect(function(player, id, role, ...)
			if self.__id == id and self._player == player then
				if self._cons[role] then
					for _, v in pairs(self._cons[role]) do v(...) end
				end
			end
		end)
	else
		return control.OnClientEvent:Connect(function(id, role, ...)
			if self.__id == id then
				if self._cons[role] then
					for _, v in pairs(self._cons[role]) do v(...) end
				end
			end
		end)
	end
	
end

function Utility:destructor(super)
	self._player = nil
	table.clear(self._cons)
	self._cons = nil
end

function Utility:fire(role, ...)
	if RUN_SERVICE:IsServer() then
		control:FireClient(self._player, self.__id, role, ...)
	else
		control:FireServer(self.__id, role, ...)
	end
end

function Utility:get(role, func)
	if self._cons[role] == nil then
		self._cons[role] = {}
	end
	
	table.insert(self._cons, func)

	return function()
		local index = table.find(self._cons, func)
		if index then
			table.remove(self._cons, index)
		end
	end
end

return Utility