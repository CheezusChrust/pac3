local L = pace.LanguageString
pace.Tools = {}

function pace.AddToolsToMenu(menu)
	menu.GetDeleteSelf = function() return false end
	for key, data in pairs(pace.Tools) do
		if #data.suboptions > 0 then
			local menu = menu:AddSubMenu(data.name)
			menu.GetDeleteSelf = function() return false end
			for key, option in pairs(data.suboptions) do
				menu:AddOption(option, function() 
					if pace.current_part:IsValid() then
						data.callback(pace.current_part, key) 
					end
				end)
			end
		else
			menu:AddOption(data.name, function() 
				if pace.current_part:IsValid() then
					data.callback(pace.current_part) 
				end
			end)
		end
	end
end

function pace.AddTool(name, callback, ...)
	for i,v in pairs(pace.Tools) do 
		if v.name == name then
			table.remove(pace.Tools, i)
		end
	end
	
	table.insert(pace.Tools, {name = name, callback = callback, suboptions = {...}})
end

pace.AddTool(L"scale this and children", function(part, suboption)
	Derma_StringRequest(L"scale", L"input the scale multiplier (does not work well with bones)", "1", function(scale)
		scale = tonumber(scale)
		
		if scale and part:IsValid() then
			local function scale_parts(part, scale)
				if part.SetPosition then 
					part:SetPosition(part:GetPosition() * scale)
					part:SetPositionOffset(part:GetPositionOffset() * scale)
				end 
						
				if part.SetSize then 
					part:SetSize(part:GetSize() * scale) 
				end 
						
				for _, part in pairs(part:GetChildren()) do 
					scale_parts(part, scale)
				end
			end
			
			scale_parts(part, scale)
		end			
	end)
end)

pace.AddTool(L"show only with active weapon", function(part, suboption)
	local event = part:CreatePart("event")
	local owner = part:GetOwner(true)
	if not owner.GetActiveWeapon or not owner:GetActiveWeapon():IsValid() then
		owner = pac.LocalPlayer
	end

	local class_name = owner:GetActiveWeapon():GetClass()

	event:SetName(class_name .. " ws")
	event:SetEvent("weapon_class")
	event:SetOperator("equal")
	event:SetInvert(true)
	event:SetRootOwner(true)
		
	event:ParseArguments(class_name, suboption == 1)

end, L"hide weapon", L"show weapon")

pace.AddTool(L"spawn as props", function(part)
	local data = pac.PartToContraptionData(part)
	net.Start("pac_to_contraption")
		net.WriteTable(data)
	net.SendToServer()
end)

function round_pretty(val)
	return math.Round(val, 2)
end

pace.AddTool(L"help i have ocd (rounding numbers)", function(part)
	local function ocdify_parts(part)
		for _, key in pairs(part:GetStorableVars()) do
			local val = part["Get" .. key](part)
			
			if type(val) == "number" then		
				part["Set" .. key](part, round_pretty(val))
			elseif type(val) == "Vector" then
				part["Set" .. key](part, Vector(round_pretty(val.x), round_pretty(val.y), round_pretty(val.z)))
			elseif type(val) == "Angle" then
				part["Set" .. key](part, Angle(round_pretty(val.p), round_pretty(val.y), round_pretty(val.r)))
			end
		end
		
		for _, part in pairs(part:GetChildren()) do
			ocdify_parts(part)
		end
	end
	
	ocdify_parts(part)
end)

do

	local function fix_name(str)
		str = str:lower()
		str = str:gsub("_", " ")
		return str
	end

	local hue =
	{
		"red",
		"orange",
		"yellow",
		"green",
		"turquoise",
		"blue",
		"purple",
		"magenta",	
	}

	local sat =
	{
		"pale",
		"",
		"strong",
	}

	local val =
	{
		"dark",
		"",
		"bright"
	}

	local function HSVToNames(h,s,v)
		return 
			hue[math.Round((1+(h/360)*#hue))] or hue[1],
			sat[math.ceil(s*#sat)] or sat[1],
			val[math.ceil(v*#val)] or val[1]
	end

	local function ColorToNames(c)
		return HSVToNames(ColorToHSV(Color(c.r, c.g, c.b)))
	end

	pace.AddTool(L"rename parts", function(part, suboptions)
		local function go(parts)
			for _, part in pairs(parts) do
				local name
				
				if part.ClassName == "model" then
					local mdl = part:GetModel()
					name = fix_name(("/".. mdl):match(".+/(.-)%."))
				end
			
				if part.ClassName == "sound" then
					local snd = part:GetSound()
					name = fix_name(("/".. snd):match(".+/(.-)%."))
				end
			
				if part.ClassName == "sprite" then
					local mat = part:GetSpritePath()
					name = fix_name(("/".. mat):match(".+/(.+)"):gsub("%..+", ""))
				end
			
				if part.ClassName == "bone" then
					name = part:GetBone()
				end
				
				if part.ClassName == "animation" then
					local str = part:GetSequenceName()
					if str == "" then
						str = part:GetWeaponHoldType()
					end
					name = fix_name(str)
				end
			
				if part.ClassName == "event" then
					name = fix_name(part:GetEvent().. " " .. part:GetOperator() .. " ".. part:GetArguments())
				end
			
				if part.ClassName == "light" and part:GetColor() ~= Vector(255, 255, 255)  then	
					local hue, sat, val = ColorToNames(part:GetColor())
					name = hue .. " light"
				end
			
				if part.ClassName == "proxy" then
					name = fix_name(part:GetVariableName()) .. " changer"
				end
			
				if part.ClassName == "clip" then
					name = "clip"
				end			
				
				if name then
					part:SetName(name)
					pace.Call("VariableChanged",part, "Name", name)
				end
				
				if suboptions == 2 then
					go(part.Children, true)
				end
			end
			
			local renamed = {}
			
			for _, part in pairs(parts) do
				if part:HasParent() then
					
					local parts = {}
					for k,v in pairs(part:GetParent():GetChildren()) do
						if v:GetName() == part:GetName() then
							table.insert(parts, v)
						end
					end
					
					if #parts > 1 then
						for k,v in pairs(parts) do
							v:SetName(v:GetName() .. " " .. k)
							pace.Call("VariableChanged",v, "Name", v.Name)
						end
					end
					
					if suboptions == 2 then
						go(part.Children, true)
					end
				end
			end
		end
		
		if suboptions == 2 then
			go(part:GetChildren())
		else
			go(pac.GetParts(true))
		end
	end, L"everything", L"children")

end
	

do return end

pace.AddTool(L"convert to expression2 holo", function(part)
	local holo_str = 
	[[
	
	HOLO_NAME = IDX
	holoCreate(HOLO_NAME)
		PARENT
		holoColor(HOLO_NAME, COLOR)
		holoAlpha(HOLO_NAME, ALPHA)
		holoScale(HOLO_NAME, SCALE)
		holoPos(HOLO_NAME, entity():toWorld(POSITION))
		holoAng(HOLO_NAME, entity():toWorld(ANGLES))
		#holoAnim(HOLO_NAME, ANIMATION_NAME, ANIMATION_FRAME, ANIMATION_RATE)
		#holoDisableShading(HOLO_NAME, FULLBRIGHT)
		holoMaterial(HOLO_NAME, MATERIAL)
		holoModel(HOLO_NAME, MODEL)
		holoSkin(HOLO_NAME, SKIN)
	]]

	local function tovec(vec) return ("vec(%s, %s, %s)"):format(math.Round(vec.x, 4), math.Round(vec.y, 4), math.Round(vec.z, 4)) end
	local function toang(vec) return ("ang(%s, %s, %s)"):format(math.Round(vec.p, 4), math.Round(vec.y, 4), math.Round(vec.r, 4)) end

	local function part_to_holo(part)
		local scale = part:GetSize() * part:GetScale()
				
		for key, clip in pairs(part.ClipPlanes) do
			if clip:IsValid() and not clip:IsHidden() then
				local pos, ang = clip.Position, clip:CalcAngles(owner, clip.Angles)
				local normal = ang:Forward()
				holo_str = holo_str .. 
				"holoClip(HOLO_NAME, " .. tovec(pos) .. ", " .. tovec(normal) ..  ", 1)\n"
			end
		end
		
		local holo = holo_str			
		:gsub("IDX", part.UniqueID)
		:gsub("ALPHA", part:GetAlpha()*255)
		:gsub("COLOR", tovec(part:GetColor()))
		:gsub("SCALE", tovec(Vector(scale.y, scale.x, scale.z)))
		:gsub("ANGLES", toang(part:GetAngles()))
		:gsub("POSITION", tovec(part:GetPosition()))
		:gsub("MATERIAL", ("%q"):format(part:GetModel()))
		:gsub("MODEL", ("%q"):format(part:GetModel()))
		:gsub("SKIN", part:GetSkin())
		
		-- not yet implemented
		--:gsub("FULLBRIGHT", part:GetFullbright()) -- forgot to implement this in pac lol
		--:gsub("ANIMATION_NAME", tovec(part:GetScale()))
		--:gsub("ANIMATION_FRAME", tovec(part:GetScale()))
		
		if part:HasParent() and part:GetParent().ClassName == "model" then
			holo = holo:gsub("PARENT", ("holoParent(HOLO_NAME, %s)"):format(part.Parent.UniqueID))
		else
			holo = holo:gsub("PARENT", "holoParent(HOLO_NAME, entity())")
		end

		holo = holo:Replace("HOLO_NAME", "PAC_" ..part:GetName():gsub("%p", ""):gsub(" ", "_"))
		
		return holo
	end

	local function convert(part)	
		local out = ""
			
		if part.ClassName == "model" then
			out = part_to_holo(part)
		end
		
		for key, part in pairs(part:GetChildren()) do
			if part.ClassName == "model" and not part:IsHidden() and not part.wavefront_mesh then
				out = out .. convert(part)
			end
		end
		
		return out
	end
	file.CreateDir("expression2/pac")
	file.Write("expression2/pac/"..part:GetName()..".txt", convert(part))
end)

pace.AddTool(L"record surrounding props to pac", function(part)
	local base = pac.CreatePart("group")
	base:SetName("recorded props")

	local origin = base:CreatePart("model")
	origin:SetName("origin")
	origin:SetBone("none")
	origin:SetModel("models/dav0r/hoverball.mdl")

	for key, ent in pairs(ents.FindInSphere(pac.EyePos, 1000)) do
		if 
			not ent:IsPlayer() and
			not ent:IsNPC() and
			not ent:GetOwner():IsPlayer() 
		then
			local mdl = origin:CreatePart("model")
			mdl:SetModel(ent:GetModel())
			
			local lpos, lang = WorldToLocal(ent:GetPos(), ent:GetAngles(), pac.EyePos, pac.EyeAng)
			
			mdl:SetMaterial(ent:GetMaterial())
			mdl:SetPosition(lpos)
			mdl:SetAngles(lang)
			local c = ent:GetColor()
			mdl:SetColor(Vector(c.r,c.g,c.b))
			mdl:SetAlpha(c.a/255)
			mdl:SetName(ent:GetModel():match(".+/(.-)%.mdl"))
		end
	end
end)