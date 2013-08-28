ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.Category = "CapsAdmin"
ENT.PrintName = "Propeller Engine"
ENT.Author = "CapsAdmin"
ENT.Contact = "sboyto@gmail.com"
ENT.Purpose = "Fly around"
ENT.Instructions = "Spawn to wear, undo to unwear"
ENT.Spawnable = true

hook.Add("Move", "PropellerEngine:Move", function(ply, ucmd)
	if not ply:Alive() then return end
	
	local self = ply.propellerengine
	
	if not IsValid(self) then return end
	if not self.dt then return end
		
	if self.dt.isthrusting then
		ply:SetGroundEntity(NULL)
	end
	
	if self.bump then ucmd:SetVelocity(ucmd:GetVelocity() + self.bump) end
	
	if not IsValid(ply:GetVehicle()) and (ply:GetMoveType() == MOVETYPE_NOCLIP or ply:KeyDown(IN_DUCK)) or not self.zvelocity then return end
		
	ucmd:SetVelocity(ucmd:GetVelocity() + ply:EyeAngles():Up() * self:GetThrust())
end)

hook.Add("UpdateAnimation", "PropellerEngine:UpdateAnimation", function(ply)
	if IsValid(ply) and ply.propellerengine and not ply:OnGround() then
		if CLIENT and ply.pedowntrace then ply:SetPoseParameter("aim_pitch", ply.pedowntrace.Fraction*40) return false end
		ply:SetPoseParameter("aim_pitch", 40)
		ply:SetPoseParameter("aim_yaw", 0)
		ply:SetPoseParameter("body_yaw", 0)
		if CLIENT then 
			ply:SetupBones() 
		end
		return false
	end
end)

hook.Add("PlayerSpawn", "PropellerEngine:PlayerSpawn", function(ply)
	local self = ply.propellerengine
	if not IsValid(self) then return end
	self.dt.thrust = 0
	self.dt.speed = 0
	self.dt.isthrusting = false
	self.dt.engineoff = true
	self.dt.pitch = 0
	ply.pefootsteps = 3
	ply:SetGroundEntity(SERVER and game.GetWorld() or Entity(0))
	if CLIENT then 
		self.speed = 0 
	end
end)

function ENT:SetupDataTables()
	self:DTVar( "Bool", 0, "isthrusting" )
	self:DTVar( "Bool", 1, "engineoff" )
	self:DTVar( "Bool", 2, "realism" )
	self:DTVar( "Entity", 0, "ply" )
	self:DTVar( "Float", 0, "speed" )
	self:DTVar( "Float", 1, "thrust" )
	self:DTVar( "Int", 0, "pitch" )
	self:DTVar( "Int", 1, "playerpitch" )
end

function ENT:GetZVelocity()
	local ply = self.dt.ply
	
	if not IsValid(ply) then return end
	
	local vehicle = ply:GetVehicle()
	
	local eye = ply:EyeAngles()
	eye.p = self.dt.playerpitch
	
	local velocity = Vector(0,0,0)
	if IsValid(vehicle) then
		velocity = WorldToLocal(vehicle:GetVelocity(), Angle(0,0,0), Vector(0,0,0), vehicle:GetAngles())
	elseif ply:GetMoveType() ~= MOVETYPE_NOCLIP then
		velocity = WorldToLocal(ply:GetVelocity(), Angle(0,0,0), Vector(0,0,0), eye)
	end
	
	if ply:OnGround() and not self.dt.isthrusting then velocity.z = 0 end
	
	self.zvelocity = -velocity.z
		
	return self.zvelocity
end

function ENT:GetSpeed()
	
	local ply = self.dt.ply
		
	self.speed = math.Clamp(self.zvelocity*5, -1200, 200)
	
 	if CLIENT and ply:IsPlayer() and ply:KeyDown(IN_WALK) and math.abs(self.zvelocity) > 0 then
		self.speed = self.speed * 5 + 1
	end
	
	return self.speed
end

function ENT:GetThrust()
	local ply = self.dt.ply
	if not IsValid(ply) then return end
	
	local eye = ply:EyeAngles()
	eye.p = self.dt.playerpitch
	
	local mask = CONTENTS_SOLID + CONTENTS_WATER + CONTENTS_OPAQUE + CONTENTS_HITBOX + CONTENTS_DETAIL + CONTENTS_TRANSLUCENT + CONTENTS_MOVEABLE + MASK_SOLID + MASK_VISIBLE
		
	local trace_down = util.TraceLine{ start = ply:GetPos(), endpos = ply:GetPos()+eye:Up()*-150, filter = ply, mask = mask }
	local trace_up = util.TraceLine{ start = ply:GetPos()+Vector(0,0,-72), endpos = ply:GetPos()+Vector(0,0,-72)+eye:Up()*150, filter = ply, mask = mask }
		
	local pressure_down = (trace_down.Fraction*-1+1)*math.abs(self.zvelocity*0.04)
	local pressure_up = (trace_up.Fraction*-1+1)*math.abs(self.zvelocity*0.04)
	
	
	local pressure = trace_down.Hit and pressure_down or trace_up.Hit and -pressure_up or 0
		
	return (self.dt.thrust + pressure + (self.zvelocity *0.020) ) * (FrameTime()*70)
end
function ENT:GetColliding(ragdoll, chest)
	local ply = ragdoll or self.dt.ply

	if self.dt.ply != nil and self.dt.ply:IsValid() and self.dt.ply:Alive() and ply:GetMoveType() == MOVETYPE_NOCLIP then return end
	if(ply == nil) then return end
	local eye = ply:EyeAngles()
	
	eye.p = self.dt.playerpitch

	local position, angles
	
	if chest then
		position, angles = chest:GetPos()+chest:GetEntity():GetUp()*25, chest:GetAngles()
		angles:RotateAroundAxis(angles:Up(), self.clientyaw)
	elseif ply:OnGround() then
		position, angles = LocalToWorld(Vector(20, -10, -1.5), Angle(-90,0,180), ply:GetBonePosition(ply:LookupBone("ValveBiped.Bip01_Spine2")))
		angles:RotateAroundAxis(angles:Forward(), -5)
		angles:RotateAroundAxis(angles:Up(), self.clientyaw-70)
	else
		position, angles = ply:GetPos()+(eye:Up()*80)+(eye:Right()*0)+(eye:Forward()*-34), eye
		position = position + (angles:Up() * -20)
		angles:RotateAroundAxis(angles:Up(), self.clientyaw)
	end


	local trace = util.TraceHull{
		start = position+angles:Forward()*-40, 
		endpos = position+angles:Forward()*75,
		maxs = Vector(20,20,10),
		mins = Vector(-20,-20,-10),
		filter = not ragdoll and ply,
	}
							
	if (self.lastspeed and math.abs(self.lastspeed) > 20 or chest or SERVER) and not ply:OnGround() and trace.Hit then
		local velocity = ply:GetPos()+Vector(0,0,64) - position
		local force = self.dt.thrust+math.abs(self:GetZVelocity())*0.005
				
		if CLIENT then
		if trace.Entity:GetOwner() == self:GetOwner() then return end
			if ragdoll or ply:GetVelocity():Length() > 10 then
				
				if ragdoll then ragdoll:EmitSound("physics/metal/metal_box_break"..math.random(2)..".wav", 70, math.random(130,255)) end
				
				if not chest and ply == LocalPlayer() and self.yawspin < 50 and not (IsValid(trace.Entity) and (trace.Entity:IsPlayer() or trace.Entity:IsNPC()))then 
					self.yawspin = math.random()+1*(math.abs(self.lastspeed))
					self.spindirection = self.lastspeed > 0 and 1 or -1
				end
				
 				if trace.MatType == MAT_METAL or trace.MatType == MAT_CONCRETE then
					self:EmitSound("physics/metal/metal_box_break"..math.random(2)..".wav", 70, math.random(130,255))
					self:Spark(LerpVector(trace.Fraction*-1+1, position+angles:Forward()*-40, position+angles:Forward()*120), velocity:Normalize(), ragdoll and 100 or force*10)
				end
			end
		end
			local entity = /*IsValid(trace.Entity) and */trace.Entity
			if entity and force > 1 then
				if SERVER then
					if entity:GetOwner() == self:GetOwner() then return end
					local damage = DamageInfo()
					damage:SetDamageType(DMG_SLASH)
					damage:SetDamage(force*10)
					if entity:IsNPC() then 
						damage:SetDamageForce(velocity*(force*10000))
					elseif entity:IsPlayer() then
						entity:SetVelocity(velocity*(force*400))
					else
						damage:SetDamageForce(velocity*(force*1000))
					end
				--	ply:ChatPrint("SLICE!")
					damage:SetAttacker(ply)
					damage:SetInflictor(self)
					damage:SetDamagePosition(trace.HitPos)
					entity:TakeDamageInfo(damage)
					if not (entity:IsPlayer() or entity:IsNPC() or entity:GetClass() == "prop_ragdoll" or entity:IsWorld()) and not entity:GetOwner() == self:GetOwner() then
						local damage = DamageInfo()
						damage:SetDamageType(DMG_SLASH)
						damage:SetDamage(force)
						damage:SetAttacker(game.GetWorld())
						damage:SetInflictor(self)
						damage:SetDamagePosition(trace.HitPos)
						ply:TakeDamageInfo(damage)
						--ply:ChatPrint("pew")
					elseif entity:IsWorld() or trace.HitWorld then
					--	ply:ChatPrint("POW!")
						local damage = DamageInfo()
						damage:SetDamageType(DMG_SLASH)
						damage:SetDamage(force)
						damage:SetAttacker(game.GetWorld())
						damage:SetInflictor(self)
						damage:SetDamagePosition(trace.HitPos)
						ply:TakeDamageInfo(damage)
					--	ply:ChatPrint("POW!")
					end
				end
				self.bumped = true
				timer.Create("PropellerEngineBumped"..self:EntIndex(), math.Clamp(force*0.01, 0.5, 2), 1, function()
					self.bumped = false
				end)
			end
		local oldthrust = self.dt.thrust / 10
		
		self.dt.thrust = 0
		
		return velocity * math.Clamp((math.abs(self.zvelocity)/10), 0, 1) * oldthrust
	end
end
