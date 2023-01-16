local Class = require(script.Parent.Parent.Class)
local Aero = Class:create("Aero")

local BiVector3 = require(script.Parent.BiVector3)
local gizmo = require(script.Parent.gizmo)

local FORCE_MULTIPLIER = 10

local defaultConstant = {
	liftSlope = 6.20,
	skinFriction = 0.02,
	zeroLiftAoA = 0.00,
	stallAngleHigh = 15.0,
	stallAngleLow = -15.0,
	chord = 1,
	flapFraction = 0.20,
	span = 1,
	autoAspectRatio = true,
	aspectRatio = 2.00
}
table.freeze(defaultConstant)

local function lerp(a, b, t)
	return a + (b - a) * t
end

function Aero:LiftCoefficientMaxFraction(flapFraction)
	return math.clamp(1 - 0.5 * (flapFraction - 0.1) / 0.3, 0, 1)
end

function Aero:FlapEffectivnessCorrection(flapAngle)
	return lerp(0.8, 0.4, (math.deg(math.abs(flapAngle)) - 10) / 50)
end

function Aero:FrictionAt90Degrees(flapAngle)
	return 1.98 - 4.26e-2 * flapAngle * flapAngle + 2.1e-1 * flapAngle
end

function Aero:TorqCoefficientProportion(effectiveAngle)
	return 0.25 - 0.175 * (1 - 2 * math.abs(effectiveAngle) / math.pi)
end

function Aero:CalculateCoefficientsAtStall(angleOfAttack, correctedLiftSlope, zeroLiftAoA, stallAngleHigh, stallAngleLow)
	local liftCoefficientLowAoA = 0
	if angleOfAttack > stallAngleHigh then
		liftCoefficientLowAoA = correctedLiftSlope * (stallAngleHigh - zeroLiftAoA)
	else
		liftCoefficientLowAoA = correctedLiftSlope * (stallAngleLow - zeroLiftAoA)
	end
	local inducedAngle = liftCoefficientLowAoA / (math.pi * self.constant.aspectRatio)

	local lerpParam = 0
	if angleOfAttack > stallAngleHigh then
		lerpParam = (math.pi / 2 - math.clamp(angleOfAttack, -math.pi / 2, math.pi / 2))
                / (math.pi / 2 - stallAngleHigh)
	else
		lerpParam = (-math.pi / 2 - math.clamp(angleOfAttack, -math.pi / 2, math.pi / 2))
                / (-math.pi / 2 - stallAngleLow)
	end
	inducedAngle = lerp(0, inducedAngle, lerpParam)
	local effectiveAngle = angleOfAttack - zeroLiftAoA - inducedAngle;

	local normalCoefficient = self:FrictionAt90Degrees(self.flapAngle) * math.sin(effectiveAngle) *
        (1 / (0.56 + 0.44 * math.abs(math.sin(effectiveAngle))) -
        0.41 * (1 - math.exp(-17 / self.constant.aspectRatio)))
	local tangentialCoefficient = 0.5 * self.constant.skinFriction * math.cos(effectiveAngle)

	local liftCoefficient = normalCoefficient * math.cos(effectiveAngle) - tangentialCoefficient * math.sin(effectiveAngle)
	local dragCoefficient = normalCoefficient * math.sin(effectiveAngle) + tangentialCoefficient * math.cos(effectiveAngle)
	local torqueCoefficient = -normalCoefficient * self:TorqCoefficientProportion(effectiveAngle);

    return Vector3.new(liftCoefficient, dragCoefficient, torqueCoefficient)
end

function Aero:CalculateCoefficientsAtLowAoA(angleOfAttack, correctedLiftSlope, zeroLiftAoA)
	local liftCoefficient = correctedLiftSlope * (angleOfAttack - zeroLiftAoA)
    local inducedAngle = liftCoefficient / (math.pi * self.constant.aspectRatio)
    local effectiveAngle = angleOfAttack - zeroLiftAoA - inducedAngle

    local tangentialCoefficient = self.constant.skinFriction * math.cos(effectiveAngle)
        
    local normalCoefficient = (liftCoefficient +
        math.sin(effectiveAngle) * tangentialCoefficient) / math.cos(effectiveAngle)
	local dragCoefficient = normalCoefficient * math.sin(effectiveAngle) + tangentialCoefficient * math.cos(effectiveAngle)
	local torqueCoefficient = -normalCoefficient * self:TorqCoefficientProportion(effectiveAngle)

    return Vector3.new(liftCoefficient, dragCoefficient, torqueCoefficient)
end

function Aero:CalculateCoefficients(angleOfAttack, correctedLiftSlope, zeroLiftAoA, stallAngleHigh, stallAngleLow)
	local aerodynamicCoefficients = Vector3.zero

	local paddingAngleHigh = math.rad(lerp(15, 5, (math.deg(self.flapAngle) + 50) / 100))
	local paddingAngleLow = math.rad(lerp(15, 5, (math.deg(self.flapAngle) + 50) / 100))
	local paddedStallAngleHigh = stallAngleHigh + paddingAngleHigh
	local paddedStallAngleLow = stallAngleLow - paddingAngleLow

	if angleOfAttack < stallAngleHigh and angleOfAttack > stallAngleLow then
		aerodynamicCoefficients = self:CalculateCoefficientsAtLowAoA(angleOfAttack, correctedLiftSlope, zeroLiftAoA)
	elseif angleOfAttack > paddedStallAngleHigh or angleOfAttack < paddedStallAngleLow then
		aerodynamicCoefficients = self:CalculateCoefficientsAtStall(
                    angleOfAttack, correctedLiftSlope, zeroLiftAoA, stallAngleHigh, stallAngleLow)
	else
		local aerodynamicCoefficientsLow = Vector3.zero
		local aerodynamicCoefficientsStall = Vector3.zero
		local lerpParam = 0

		if angleOfAttack > stallAngleHigh then
			aerodynamicCoefficientsLow = self:CalculateCoefficientsAtLowAoA(stallAngleHigh, correctedLiftSlope, zeroLiftAoA)
            aerodynamicCoefficientsStall = self:CalculateCoefficientsAtStall(
				paddedStallAngleHigh, correctedLiftSlope, zeroLiftAoA, stallAngleHigh, stallAngleLow)
            lerpParam = (angleOfAttack - stallAngleHigh) / (paddedStallAngleHigh - stallAngleHigh)
		else
			aerodynamicCoefficientsLow = self:CalculateCoefficientsAtLowAoA(stallAngleLow, correctedLiftSlope, zeroLiftAoA)
            aerodynamicCoefficientsStall = self:CalculateCoefficientsAtStall(
                paddedStallAngleLow, correctedLiftSlope, zeroLiftAoA, stallAngleHigh, stallAngleLow)
            lerpParam = (angleOfAttack - stallAngleLow) / (paddedStallAngleLow - stallAngleLow)
		end
		aerodynamicCoefficients = aerodynamicCoefficientsLow:Lerp(aerodynamicCoefficientsStall, lerpParam)
	end

    return aerodynamicCoefficients
end

function Aero:calculateForces(worldAirVelocity, airDensity, relativePosition)
    local forceAndTorque = BiVector3()

	local correctedLiftSlope = self.constant.liftSlope * self.constant.aspectRatio /
           (self.constant.aspectRatio + 2 * (self.constant.aspectRatio + 4) / (self.constant.aspectRatio + 2))

	local theta = math.acos(2 * self.constant.flapFraction - 1)
	local flapEffectivness = 1 - (theta - math.sign(theta)) / math.pi
	local deltaLift = correctedLiftSlope * flapEffectivness * self:FlapEffectivnessCorrection(self.flapAngle) * self.flapAngle

	local zeroLiftAoaBase = math.rad(self.constant.zeroLiftAoA)
	local zeroLiftAoA = zeroLiftAoaBase - deltaLift / correctedLiftSlope

	local stallAngleHighBase = math.rad(self.constant.stallAngleHigh)
	local stallAngleLowBase = math.rad(self.constant.stallAngleLow)

	local clMaxHigh = correctedLiftSlope * (stallAngleHighBase - zeroLiftAoaBase) + deltaLift * self:LiftCoefficientMaxFraction(self.constant.flapFraction)
	local clMaxLow = correctedLiftSlope * (stallAngleLowBase - zeroLiftAoaBase) + deltaLift * self:LiftCoefficientMaxFraction(self.constant.flapFraction)

	local stallAngleHigh = zeroLiftAoA + clMaxHigh / correctedLiftSlope
	local stallAngleLow = zeroLiftAoA + clMaxLow / correctedLiftSlope

	local airVelocity = self.wing.CFrame:Inverse().LookVector * worldAirVelocity
    local dragDirection = worldAirVelocity.Magnitude > 0 and worldAirVelocity.Unit or worldAirVelocity
    local liftDirection = dragDirection.Magnitude > 0 and dragDirection:Cross(self.wing.CFrame.RightVector).Unit or dragDirection

    local area = self.constant.chord * self.constant.span
    local dynamicPressure = 0.5 * airDensity * math.sqrt(airVelocity.Magnitude)
    local angleOfAttack = math.atan2(airVelocity.Y, -airVelocity.Z)
        
    local aerodynamicCoefficients = self:CalculateCoefficients(angleOfAttack,
                                                            correctedLiftSlope,
                                                            zeroLiftAoA,
                                                            stallAngleHigh,
                                                            stallAngleLow)

	local lift = liftDirection * aerodynamicCoefficients.X * dynamicPressure * area
	local drag = dragDirection * aerodynamicCoefficients.Y * dynamicPressure * area
	local torque = -self.wing.CFrame.RightVector * aerodynamicCoefficients.Z * dynamicPressure * area * self.constant.chord

    forceAndTorque.force += lift + drag
    forceAndTorque.torque += relativePosition:Cross(forceAndTorque.force)
    forceAndTorque.torque += torque

	gizmo.setColor(Color3.fromRGB(51, 248, 133))
	gizmo.drawRay(self.wing.Position, drag, self.wing)
	gizmo.setColor(Color3.fromRGB(161, 9, 9))
	gizmo.drawRay(self.wing.Position, lift, self.wing)
	gizmo.setColor(Color3.fromRGB(255, 255, 255))
	gizmo.drawRay(self.wing.Position, torque, self.wing)

	self.vectorForce.Force = -forceAndTorque.force

    return forceAndTorque
end

function Aero:setFlapAngle(angle)
    self.flapAngle = math.clamp(angle, -math.rad(50), math.rad(50))
end

function Aero:constructor(super, wing)
	self.constant = defaultConstant
    self.wing = wing
    self.flapAngle = 0

	self.att = Instance.new("Attachment")
    self.att.Parent = self.wing

	self.vectorForce = Instance.new("VectorForce")
    self.vectorForce.Parent = self.wing
    self.vectorForce.Attachment0 = self.att
    self.vectorForce.Force = Vector3.zero
	self.vectorForce.Visible = true
end

return Aero