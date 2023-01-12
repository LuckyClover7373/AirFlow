local RUN_SERVICE = game:GetService("RunService")

local Class = require(script.Parent.Parent.Class)
local Engine = Class:create("Engine")
local BiVector3 = require(script.Parent.BiVector3)
local Aero = require(script.Parent.Aero)
local gizmo = require(script.Parent.gizmo)

function Engine:constructor(super, plane)
    workspace.Gravity = 0
    self.plane = plane
    self.driver = plane:FindFirstChildWhichIsA("VehicleSeat")
    self.thrustPercent = 1
    self.aeros = {}

    if self.driver == nil then self:destroy() end

    local att = Instance.new("Attachment")
    att.Parent = self.driver
    --att.WorldCFrame = self.driver.CFrame

    local bodyThrust = Instance.new("BodyThrust")
    bodyThrust.Parent = self.plane.Part
    --vectorForce.Attachment0 = att
    bodyThrust.Force = Vector3.zero

    local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
    bodyAngularVelocity.Parent = self.plane.Part
    --angularVelocity.Attachment0 = att
    bodyAngularVelocity.MaxTorque = Vector3.one * 1000
    bodyAngularVelocity.AngularVelocity = Vector3.zero

    --self.driver.BodyGyro.CFrame = self.driver.CFrame
    self.update = RUN_SERVICE.Heartbeat:Connect(function(dt)
        local forceAndTorque = self:calculateAeroForces(self.driver.AssemblyLinearVelocity, self.driver.AssemblyAngularVelocity, Vector3.zero, 1.2, self.driver.AssemblyCenterOfMass)
        bodyThrust.Force = -forceAndTorque.force
        bodyAngularVelocity.AngularVelocity = forceAndTorque.torque
        
        bodyThrust.Force += -self.driver.CFrame.LookVector * 400 * self.thrustPercent
        
        gizmo.setColor(Color3.fromRGB(51, 54, 248))
	    gizmo.drawRay(self.driver.Position, self.plane.Part.AssemblyLinearVelocity, self.driver)
        gizmo.setColor(Color3.fromRGB(243, 96, 96))
	    gizmo.drawRay(self.driver.Position, self.plane.Part.AssemblyAngularVelocity, self.driver)
    end)
end

function Engine:setThrust(thrust)
    self.thrust = thrust
end

function Engine:addAero(wing)
    local newAero = Aero(wing)
    newAero:setFlapAngle(1)
    table.insert(self.aeros, Aero(wing))
end

function Engine:calculateAeroForces(velocity, anuglarVelocity, wind, airDensity, centerOfMass)
    local forceAndTorque = BiVector3()
    
    for _, aero in pairs(self.aeros) do
        local relativePosition = aero.wing.Position - centerOfMass
        forceAndTorque += aero:calculateForces(-velocity + wind - anuglarVelocity:Cross(relativePosition),
        airDensity, relativePosition)
    end

    return forceAndTorque
end


return Engine