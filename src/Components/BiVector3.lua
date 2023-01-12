local Class = require(script.Parent.Parent.Class)
local BiVector3 = Class:create("BiVector3")

function BiVector3:constructor(super, force, torque)
   self.force = force or Vector3.zero
   self.torque = torque or Vector3.zero
end

function BiVector3:__add(value)
    return BiVector3(self.force + value.force, self.torque + value.torque)
end

function BiVector3:__sub(value)
    return BiVector3(self.force - value.force, self.torque - value.torque)
end

function BiVector3:__mul(value)
	local calcBiVector3 = nil
	
	if typeof(self) == "table" and typeof(value) == "table" then
		calcBiVector3 = BiVector3(self.force * value.force, self.torque * value.torque)
	elseif typeof(self) == "table" and typeof(value) == "number" then
		calcBiVector3 = BiVector3(self.force * value, self.torque * value)
	elseif typeof(self) == "number" and typeof(value) == "table" then
		calcBiVector3 = BiVector3(self * value.force, self * value.torque)
	end

	return calcBiVector3
end


return BiVector3