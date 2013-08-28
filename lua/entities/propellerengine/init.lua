AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
include("shared.lua")

CreateConVar("propeller_engine_damage", 1, FCVAR_ARCHIVE)

concommand.Add("propeller_engine_spawn", function(ply)
	scripted_ents.Get("propellerengine"):SpawnFunction(ply)
end)

concommand.Add("propeller_engine_remove", function(ply)
	local self = ply.propellerengine
	if IsValid(self) then
		self:Remove()
	end
end)

concommand.Add("_propeller_engine_yaw", function(ply, command, args)
	local self = ply.propellerengine
	if not IsValid(self) then return end
	self.clientyaw = tonumber(args[1])
	--if game.SinglePlayer() or self.ply:Alive() then
		self.bump = self:GetColliding()
	--end
end)

hook.Add("PlayerFootstep", "PropellerEngine:PlayerFootstep", function(ply)
	local self = ply.propellerengine
	if not IsValid(self) then return end
		
	ply.pefootsteps = ply.pefootsteps or 0
		
	ply.pefootsteps = ply.pefootsteps + 1
	
	if ply.pefootsteps == 3 then
		self.dt.engineoff = true
		local volume = math.Clamp(ply:GetInfoNum("propeller_engine_idle_sound_volume", 0),0,1)*100
		if volume > 0 then self:EmitSound("vehicles/airboat/fan_motor_shut_off1.wav", volume, math.random(90,110)) end
	end
end)

function ENT:SpawnFunction( ply )
	if IsValid(ply.propellerengine) then
		ply.propellerengine:Remove()
	end
	
	local self = ents.Create("propellerengine")
	self.ply = ply
	ply.propellerengine = self

	self:SetOwner(ply)
	self:SetPos(ply:GetPos())
	self:Spawn()
	self:SetHealth("100")
	self:Activate()
	--self:SetSolid( SOLID_VPHYSICS )
	self:SetParent(ply)
	self:SetModel("models/props_c17/trappropeller_engine.mdl")
	self:SetModelScale( self:GetModelScale() / 16, 0 )
	self:SetNoDraw(true)
			
	self.smooththrust = 0
	
	return self
end/*
function ENT:OnTakeDamage()
--print("fuck!")
self:EmitSound("physics/metal/metal_box_break"..math.random(2)..".wav", 70, math.random(130,255))
		local spark = emitter:Add( "effects/spark", pos)
		amount = math.Clamp(amount,0,100)
		--if spark then
			spark:SetVelocity((VectorRandSphere()+normal)*4*amount)
			spark:SetDieTime( math.random()*5 )
			spark:SetStartLength(math.Rand(0.1,0.2)*amount)
			spark:SetEndLength(0)
			spark:SetAngles(Angle(math.random(360),math.random(360),math.random(360)))
			spark:SetStartSize( math.min(math.random()+0.2*amount*0.1, 20) )
			spark:SetEndSize( 0 )
			spark:SetRoll( math.Rand(-0.5, 0.5) )
			spark:SetRollDelta( math.Rand(-0.5, 0.5) )
			spark:SetGravity(Vector(0,0,-600))
			spark:SetCollide(true)
			spark:SetBounce(0.2)
		--end	
end*/
function ENT:Initialize()
	self.dt.ply = self.ply
	self.speed = 0
	self.clientyaw = 0
end

function ENT:Think()
	
	self:GetZVelocity()
		
	local ply = self.ply
	if(ply != nil and ply:IsValid()) then
		self.dt.playerpitch = ply:EyeAngles().p
		
		if not IsValid(ply) or not IsValid(self.ply.propellerengine) then self:Remove() return end
			
		local vehicle = ply:GetVehicle()
		local phys = IsValid(vehicle) and vehicle:GetPhysicsObject()
		
		self.dt.isthrusting = false
		
		local thrust = 0
		local pitch = 0
		local roll = 0
		
		if not self.bumped and (phys or ply:GetMoveType() ~= MOVETYPE_NOCLIP) then
			if ply:KeyDown(IN_WALK) then
				thrust = thrust + 9
				pitch = pitch + 70
				self.dt.isthrusting = true
				self.dt.engineoff = false
			end
			if ply:KeyDown(IN_JUMP) then
				thrust = thrust + 15
				pitch = pitch + 120
				self.dt.isthrusting = true
				self.dt.engineoff = false
			end
			if ply:KeyDown(IN_SPEED) and not ply:OnGround() then	
				thrust = thrust + 30
				pitch = pitch + 150
				self.dt.isthrusting = true
				self.dt.engineoff = false
			end
			thrust = ply:KeyDown(IN_USE) and -thrust or thrust
		end
			
		ply.pefootsteps = self.dt.isthrusting and 0 or ply.pefootsteps or 0
		
		self.dt.pitch = pitch

		self.smooththrust = Lerp(FrameTime()*3,self.smooththrust,thrust)
		
		self.dt.thrust = self.smooththrust
						
		if phys then phys:AddVelocity(ply:EyeAngles():Up() * self:GetThrust() ) end
		
		self:NextThink(CurTime())
	end
	return true
end


