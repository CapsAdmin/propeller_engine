include("shared.lua")

local cvar_idle_volume = CreateClientConVar("propeller_engine_idle_sound_volume", "0.2", true, true)

hook.Add("PlayerBindPress", "PropellerEngine:PlayerBindPress", function(ply, bind, pressed)
	local self = ply.propellerengine
	if  bind ~= "noclip" or not IsValid(self) then return end
	if ply:GetMoveType() ~= MOVETYPE_NOCLIP then
		self.dt.engineoff = true
		local volume = math.Clamp(cvar_idle_volume:GetFloat(),0,1)*100
		if volume > 0 then self:EmitSound("vehicles/Airboat/fan_motor_shut_off1.wav", volume, math.random(90,110)) end
	else
		self.dt.engineoff = false
	end
end)

hook.Add("KeyPress", "PropellerEngine:KeyPress", function(ply, key)
	if ply:OnGround() then return end
	local self = ply.propellerengine
	if self and key == IN_DUCK and ply:GetMoveType() ~= MOVETYPE_NOCLIP then
		self.yawspin = math.random()+1*(math.abs(self.lastspeed))
		self.spindirection = self.lastspeed > 0 and 1 or -1
		if self.dt.isthrusting and math.abs(self.lastspeed) > 20 then 
			self:EmitSound("physics/metal/metal_computer_impact_hard"..math.random(3)..".wav", 120, math.random(100,120))
			self:EmitSound("ambient/machines/spinup.wav", 120, math.random(90,110))
		end
	end
end)

local localplayervisible = false

hook.Add("PrePlayerDraw", "PropellerEngine:PrePlayerDraw", function(ply)
	local self = ply.propellerengine
	
	if not IsValid(self) then return end
	
	if ply == LocalPlayer() then
		localplayervisible = true
		timer.Create("PropellerEngineLocalPlayerVisible", 0.1, 1, function()
			localplayervisible = false
		end)
	end
	
	if not IsValid(ply:GetVehicle()) and not ply:OnGround() then 
	
		local trace = util.QuickTrace(ply:GetPos(), Vector(0,0,-50), ply)
		
		local eye = ply:EyeAngles()
		
		eye.p = self.dt.playerpitch
		
		local angle = LerpAngle(trace.Fraction, ply:EyeAngles(), eye+Angle(-40, 0, 5))
		
		if trace.Hit then 
			ply.pedowntrace = trace 
			ply.propellerlegsoverride = Angle(0,45*trace.Fraction,0) 
		else 
			ply.propellerlegsoverride = nil 
			ply.pedowntrace = false 
		end
		
		ply:SetRenderAngles(angle)
		ply:SetupBones()
		local weapon = ply:GetActiveWeapon()
		if IsValid(weapon) then 
			weapon:SetRenderAngles(angle)
			weapon:SetupBones() 
		end
	end
	
	self:DrawParts(ply)
	
end)

local enable_roll = CreateClientConVar("propeller_engine_enable_roll", "1", true)
local move_divider = CreateClientConVar("propeller_engine_move_divider", "1", true)

local pitch = 0
local yaw = 0

hook.Add("CreateMove", "PropellerEngine:CreateMove", function(ucmd)

	local ply = LocalPlayer()
	local self = ply.propellerengine
	if not IsValid(self) then return end
		
	local new = Angle(0,0,0)
	
	if enable_roll:GetBool() then
		
		local roll = 0
		local pitch = 0
		
		if ply:GetMoveType() ~= MOVETYPE_NOCLIP and not ply:OnGround() then
			if ply:KeyDown(IN_MOVELEFT) then
				roll = -30
			elseif ply:KeyDown(IN_MOVERIGHT) then
				roll = 30
			end
			local velocity = WorldToLocal(ply:GetVelocity(), Angle(0,0,0), Vector(0,0,0), ply:EyeAngles())
			pitch = pitch + (velocity.x/70)
			roll = roll -(velocity.y/70)
		end
		
		self.smoothpitch = Lerp(FrameTime()*7,self.smoothpitch,pitch)
		self.smoothroll = Lerp(FrameTime()*7,self.smoothroll,roll)
		
		new = Angle(self.smoothpitch,0,self.smoothroll)
	end
	
	if self.yawspin > 0.01 then
		self.yawspin = self.yawspin - (self.yawspin * 0.05)
		new = new + Angle(0,self.yawspin*self.spindirection,0)
	end
	
	--if ply:KeyDown(IN_USE) and ply:KeyDown(IN_ATTACK) and (ValidEntity(LocalPlayer():GetActiveWeapon()) and ply:GetActiveWeapon():GetClass() == "weapon_physgun") then return end	
	local lply = LocalPlayer()
	if 
		ply:Alive() and 
		not (
			lply:KeyDown(IN_USE) and 
			lply:KeyDown(IN_ATTACK) and (
				IsValid(lply:GetActiveWeapon()) and 
				lply:GetActiveWeapon():GetClass() == "weapon_physgun"
			)
		) and
		not ply:OnGround()
	then
		local sensitivity = 50--math.Clamp(math.abs(self:GetZVelocity()/7),50,350)
		pitch = pitch + (ucmd:GetMouseY() / (ply:GetInfo("sensitivity") * LocalPlayer():GetInfo("m_pitch") < 0 and -sensitivity or sensitivity))
		yaw = yaw + (ucmd:GetMouseX() / (ply:GetInfo("sensitivity") * LocalPlayer():GetInfo("m_yaw") < 0 and sensitivity or -sensitivity))
	else
		pitch = ply:EyeAngles().p - self.smoothpitch
		yaw = ply:EyeAngles().y 
	end
	
	ucmd:SetViewAngles(new+Angle(pitch, yaw,0))
	ucmd:SetForwardMove(ucmd:GetForwardMove()/move_divider:GetFloat())
	ucmd:SetSideMove(ucmd:GetSideMove()/move_divider:GetFloat())
	return true
end)

hook.Add("PostDrawOpaqueRenderables", "PropellerEngine:PostDrawOpaqueRenderables", function()
	for key, ply in pairs(player.GetAll()) do
		if ply == LocalPlayer() and ply.propellerengine and not localplayervisible and ply:Alive() then
			ply.propellerengine:DrawPropeller(LocalPlayer(), true)
		end
		if not IsValid(ply:GetVehicle()) and ply.propellerengine and not ply:Alive() then
			local ragdoll = ply:GetRagdollEntity()
			if IsValid(ragdoll) then
				local chest	= ragdoll:GetPhysicsObjectNum(1)
				if not IsValid(chest) then return end
				local collision = ply.propellerengine:GetColliding(ragdoll, chest)
				chest:AddAngleVelocity(Vector(300,0,0))
				if collision then 
					chest:AddVelocity(collision*500)
				else
					chest:AddVelocity(chest:GetAngles():Forward()*50)
				end
				ply:SetPos(chest:GetPos())
				ply.propellerengine:DrawParts(ragdoll, chest)
			end
		end
	end
end)

local bones = {
	"ValveBiped.Bip01_R_Thigh",
	"ValveBiped.Bip01_L_Thigh",
}

function ENT:BuildPlayerBones(ply)
	ply.smoothlegs = ply.smoothlegs or Vector(0, 0, 0)
	if ply.propellerengine and not ply:OnGround() then
		for key, bone in pairs(bones) do
			local index = ply:LookupBone(bone)
			if index and index > -1 then
			local velocity = WorldToLocal(ply:GetVelocity(), Angle(0,0,0), Vector(0,0,0), ply:EyeAngles())
			ply.smoothlegs = LerpVector(FrameTime()*2,ply.smoothlegs,velocity*0.1)
			
				ply:ManipulateBoneAngles(index, ply:GetManipulateBoneAngles(index) + (ply.propellerlegsoverride or Angle(math.Clamp(ply.smoothlegs.y/5,-60,60),math.Clamp(ply.smoothlegs.x/5,-60,60)+45,0)))
			end
		end
	end
end

function ENT:Initialize()
	local ply = self.dt.ply
	
	if not IsValid(ply) then return end
	
	self:SetNoDraw(true)
	
	self.engine = ClientsideModel("models/props_c17/trappropeller_engine.mdl")
	self.engine:SetNoDraw(true)
	self.engine:SetParent(self.dt.ply)
	
	self.propeller = ClientsideModel("models/props_c17/TrapPropeller_Blade.mdl")
	self.propeller:SetNoDraw(true)
	self.propeller.yaw = 0
	self.propeller:SetParent(self.dt.ply)
	
	self.clientyaw = 0
	
	self.emitter = ParticleEmitter( self:GetPos() )
	
	self.dt.ply.propellerengine = self
	
	self.speed = 0
	self.shake = Vector(0)
	
	self.yawspin = 0
	
	self.smoothsoundpitch = 0
	self.smoothpitch = 0
	
	self.sound_propeller = CreateSound( self, "vehicles/Airboat/fan_blade_fullthrottle_loop1.wav" )
	self.sound_propeller:SetSoundLevel(110)
	self.sound_propeller:PlayEx(1,0)

	self.sound_idle = CreateSound( self, "ambient/machines/diesel_engine_idle1.wav" )
	self.sound_idle:PlayEx(1,255)
		
	self.bump = Vector(0)
	
	self.smoothroll = 0
	
	self.emitter = ParticleEmitter(self:GetPos())
end

local function VectorRandSphere()
	return Angle(math.Rand(-180,180),math.Rand(-180,180),math.Rand(-180,180)):Forward()
end

function ENT:Spark(pos, normal, amount)
	
	amount = math.Clamp(amount,0,100)
	
	for index = 1, amount do
		local spark = self.emitter:Add( "effects/spark", pos)
		if spark then
		--	print(self:GetForward():Angle())
		--	print(type(self:GetForward():Angle()))
		--	print((VectorRandSphere()+self:GetForward():Angle())*4*amount)
			spark:SetVelocity((VectorRandSphere()+self:GetForward())*4*amount)
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
		end		
	end
end

function ENT:CalculateSounds()

	local pitch = self.dt.pitch+(self:GetZVelocity()*0.05)
	local idle_volume = math.Clamp(cvar_idle_volume:GetFloat(),0,1)
	
	if not self.dt.ply:Alive() then
		pitch = math.random(150,255)
		self.dt.isthrusting = true
	end
	
	self.smoothsoundpitch = Lerp(0.05,math.max(self.smoothsoundpitch,0.001),pitch)
	local propeller_pitch = math.Clamp(self.smoothsoundpitch+50,0,255)
	--print(propeller_pitch)
	local propeller_volume = math.Clamp(self.smoothsoundpitch/30,0,1)

	if self.dt.engineoff then
		self.sound_propeller:ChangePitch(propeller_pitch, 0.1)
		self.sound_propeller:ChangeVolume(propeller_volume, 0.1)
		self.sound_idle:ChangeVolume(0, 0.1)
		return 
	end
	
	if self.dt.ply:KeyDown(IN_DUCK) then
		self.sound_propeller:ChangePitch(0, 0.1)
		self.sound_propeller:ChangeVolume(0, 0.1)
		self.sound_idle:ChangeVolume(1*idle_volume, 0.1)		
		return
	end

	self.sound_propeller:ChangePitch(propeller_pitch, 0,1)
	self.sound_propeller:ChangeVolume(propeller_volume,0.1)
	self.sound_idle:ChangeVolume(math.Clamp(math.abs(self.smoothsoundpitch)/100*-1+1, 0, 1)*idle_volume, 0.1)
	
end

function ENT:Think()
	
	self:GetZVelocity()
	
	local ply = self.dt.ply
	
	if not IsValid(ply) then return end
	
	self.lastspeed = self.zvelocity ~= 0 and self.zvelocity or self.lastspeed
					
	self.speed = self:GetSpeed()
	
	self.shake = VectorRand()*(self.speed/500+0.05)
	
	self.shake.x = math.Clamp(self.shake.x, 0.05, 0.3)
	self.shake.y = math.Clamp(self.shake.y, 0.05, 0.3)
	self.shake.z = math.Clamp(self.shake.z, 0.05, 0.3)
	
	self:CalculateSounds()
		
	self:NextThink(CurTime())
	return true
end

local smoke = { 
	"particle/smokesprites_0001",
	"particle/smokesprites_0002",
	"particle/smokesprites_0003",
	"particle/smokesprites_0004",
	"particle/smokesprites_0005",
	"particle/smokesprites_0006",
	"particle/smokesprites_0007",
	"particle/smokesprites_0008",
	"particle/smokesprites_0009",
	"particle/smokesprites_0010",
	"particle/smokesprites_0012",
	"particle/smokesprites_0013",
	"particle/smokesprites_0014",
	"particle/smokesprites_0015",
	"particle/smokesprites_0016"
}

function ENT:DrawPropeller(ply, firstperson)

	if not IsValid(self.propeller) then return end

		local speed = ply.KeyDown and ply:KeyDown(IN_DUCK) and 0 or not ply:IsPlayer() and 500 or self.dt.isthrusting and self.dt.thrust*100 or (self:GetSpeed())
		local shake = ply.KeyDown and ply:KeyDown(IN_DUCK) and Vector(0) or self.shake
			
		local vehicle = ply.GetVehicle and ply:GetVehicle()
		
		local eye = ply:EyeAngles()
		
		local position, angles
		
		local eyepos, eyeangles = ply:EyePos(), EyeAngles()
		
		if firstperson and IsValid(vehicle) then
			position, angles = vehicle:GetPos()+vehicle:GetUp()*50, vehicle:GetAngles()
			angles.y = angles.y + 35
		elseif firstperson and ply:OnGround() then
			position, angles = eyepos+Vector(0,0,10), Angle(0,eyeangles.y,eyeangles.r)
			angles.y = angles.y + 35
		elseif firstperson and not ply:OnGround() then
			position, angles = eyepos+eyeangles:Up()*10, eye
		else
			position, angles = LocalToWorld(Vector(20, -10, -1.5), Angle(-90,0,180), ply:GetBonePosition(ply:LookupBone("ValveBiped.Bip01_Spine2")))
		end
		
		angles:RotateAroundAxis(angles:Forward(), -5)
		
		if IsValid(vehicle) or ply:GetMoveType() ~= MOVETYPE_NOCLIP then 
		
			self.propeller.yaw = self.propeller.yaw + (speed/30) * (FrameTime()*150) 
			
			if math.abs(speed) > 100 then
				self.propeller:SetBodygroup(1,1)
			else
				self.propeller:SetBodygroup(1,0)
			end
		
		else
			self.propeller:SetBodygroup(1,0)
		end
		
		angles:RotateAroundAxis(angles:Up(), self.propeller.yaw)
		
		if self.clientyaw ~= self.propeller.yaw and ply == LocalPlayer() then 
			RunConsoleCommand("_propeller_engine_yaw", self.propeller.yaw%360)
			if ply:Alive() then 
				self.bump = self:GetColliding() 
			end
		end
		
		self.clientyaw = self.propeller.yaw
		
		self.propeller:SetPos(position+shake)
		self.propeller:SetAngles(angles) 
		--local scale = math.abs(speed)/1000+1
		--self.propeller:SetModelScale(Vector(scale,scale,1))

		self.propeller:DrawModel()
		
		if(self.dt.ply == nil or !self.dt.ply:IsValid()) then return end
		if self.dt.ply:KeyDown(IN_WALK) then speed = speed * 0.7 end
		
		speed = math.abs(speed) * 0.3
		
		if speed < 10 then return end
		
		local groundtrace = util.TraceLine{ start = ply:GetPos(), endpos = ply:GetPos()+ply:EyeAngles():Up()*-500, filter = ply }
		local watertrace = util.TraceLine{ start = ply:GetPos(), endpos = ply:GetPos()+ply:EyeAngles():Up()*-500, filter = ply, mask = MASK_WATER }
		
		if watertrace.Hit then
			if math.random() > 0.9 then
				local data = EffectData()
				data:SetOrigin(watertrace.HitPos)
				data:SetScale(10*(watertrace.Fraction+3))
				util.Effect("WaterRipple", data)
			end
		elseif groundtrace.HitWorld then
			local randomsphere = Angle(0,math.random(360),0):Forward()*(math.random(groundtrace.Fraction*500+70))
			local particle = self.emitter:Add( table.Random(smoke), groundtrace.HitPos+randomsphere)	
		local spread = (groundtrace.HitPos - groundtrace.HitPos+randomsphere):GetNormalized()
			local colortrace = util.TraceLine{
				start = groundtrace.HitPos+Vector(0,0,10), 
				endpos = groundtrace.HitPos+Vector(0,0,-10)+randomsphere,
			}		
			local vector = Vector(100, 100, 100)
			
			if colortrace.HitWorld then
				vector = render.GetSurfaceColor(groundtrace.StartPos, groundtrace.HitPos+(groundtrace.Normal*10)) * 255
			end
					
			particle:SetVelocity(spread*speed / 2)
			particle:SetDieTime( 1 )
			particle:SetStartAlpha( speed*(groundtrace.Fraction*-1+1) * 0.35 )
			particle:SetEndAlpha( 0 )
			particle:SetStartSize( 0 )
			particle:SetEndSize( speed / 8 )
			particle:SetRoll( math.Rand( 360, 480 ) )
			particle:SetRollDelta( math.Rand( -1, 1 ) )
			particle:SetColor( vector.x, vector.y, vector.z )
			particle:SetGravity(Vector(0,0,100))
			particle:SetAirResistance(100)
			particle:SetCollide(true)	
		end
	end

function ENT:DrawParts(ply) -- made with help from PAC

	if not IsValid(ply) or not IsValid(self.engine) then return end
	
	local speed = self.speed
	local shake = self.shake
			
	local bone = ply:LookupBone("ValveBiped.Bip01_Spine2")
	
	local position, angles = LocalToWorld(Vector(3, -10, -3), Angle(-90,0,180), ply:GetBonePosition(bone))
	
	angles:RotateAroundAxis(angles:Forward(), -5)
	angles:RotateAroundAxis(angles:Up(), 90)	
	
	self.engine:SetPos(position+shake)  
	self.engine:SetAngles(angles)  
	self.engine:SetModelScale(0.7,0) 
	
	self.engine:DrawModel()
	
	self:DrawPropeller(ply)
	
	if not self.dt.isthrusting then
		local position, angles = LocalToWorld(Vector(10, -5.5, 4), Angle(-90,0,180), ply:GetBonePosition( bone ))
			
		angles:RotateAroundAxis(angles:Forward(), -5)
		angles:RotateAroundAxis(angles:Up(), 90)	
				
		local particle = self.emitter:Add( table.Random(smoke), position)
		
		particle:SetDieTime( 1 )
		particle:SetStartAlpha( 10 )
		particle:SetEndAlpha( 0 )
		particle:SetStartSize( 0 )
		particle:SetEndSize( math.Rand( 20, 30 ) )
		particle:SetRoll( math.Rand( 360, 480 ) )
		particle:SetRollDelta( math.Rand( -1, 1 ) )
		particle:SetColor( 180, 180, 180 )
		particle:SetVelocity(VectorRand()*10+vector_up*40)
		particle:SetGravity(Vector(math.Rand(-100,100),math.Rand(-100,100),math.Rand(150,200)))
		particle:SetAirResistance(100)
		particle:SetCollide(true)
	end
end

function ENT:OnRemove()
	self.dt.ply.propellerengine = false
	if(self.sound_propeller != nil) then
		self.sound_propeller:Stop()
	end
	if(self.sound_idle != nil) then
		self.sound_idle:Stop()
	end
	if self.dt.ply == LocalPlayer() and IsValid(LocalPlayer()) then
		local eye = LocalPlayer():EyeAngles()
		LocalPlayer():SetEyeAngles(Angle(eye.p,eye.y,0))
	end
end