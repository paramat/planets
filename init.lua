-- Parameters

local pnum = 1 -- number of planets desired
local maxatt = 128 -- maximum number of attempts to add a planet

local np_terrain = {
	offset = 0,
	scale = 1.0,
	spread = {x = 96, y = 96, z = 96},
	seed = 921181,
	octaves = 3,
	persist = 0.5
}

local np_cloud = {
	offset = 0,
	scale = 1,
	spread = {x = 16, y = 16, z = 16},
	seed = 2113,
	octaves = 4,
	persist = 1.0
}


-- Do files

dofile(minetest.get_modpath("planets") .. "/nodes.lua")


-- Mapgen parameters

minetest.set_mapgen_params({mgname = "singlenode",
	chunksize = 5, water_level = -31000, flags = "nolight"})


-- Create pseudorandom galaxy

-- space is 64 ^ 3 chunks, centred on world centre
-- space table is flat array of planet ids or nil (vacuum chunk)
local space = {}
-- planet definition table indexed by planet id
local def = {}
local spzstr = 64 * 64 -- space array z stride
local spystr = 64 -- space array y stride
local plid = 0 -- planet id of last planet added, 0 = none
local addatt = 0 -- number of attempts to add a planet

while plid < pnum and addatt <= maxatt do -- avoid infinite attempts
	-- create initial planet data to check for obstruction
		-- cenx/y/z is planet centre
		-- radter = terrain radius / water level
		-- radmax = atmosphere radius or max mountain radius
	local cenx = 0
	local ceny = 0
	local cenz = 0
	local radter = 256
	local radmax = 384

	-- chunk co-ords of chunk containing planet centre 
	-- measured from space origin (-32, -32, -32 chunks)
	local cenxcc = math.floor((cenx + 32) / 80) + 32
	local cenycc = math.floor((ceny + 32) / 80) + 32
	local cenzcc = math.floor((cenz + 32) / 80) + 32
	local radmaxc = math.ceil(radmax / 80) -- planet radius in chunks

	-- check space is clear for planet
	local clear = true -- is space clear
	print ("[planets] Checking for obstruction")

	for cz = cenzcc - radmaxc, cenzcc + radmaxc do
		for cy = cenycc - radmaxc, cenycc + radmaxc do
			local spi = cz * spzstr + cy * spystr + cenxcc - radmaxc + 1
			for cx = cenxcc - radmaxc, cenxcc + radmaxc do
				if space[spi] ~= nil then
					clear = false
					print ("[planets] Planet obstructed")
					break
				end
				spi = spi + 1
			end
			if not clear then
				break
			end
		end
		if not clear then
			break
		end
	end

	if clear then -- add planet
		-- TODO generate extra planet data
		plid = #def + 1 -- planet id
		-- add planet data to def table
		def[plid] = {i = cenx, j = ceny, k = cenz, t = radter, m = radmax}
		print ("[planets] Adding planet " .. plid)

		for cz = cenzcc - radmaxc, cenzcc + radmaxc do
		for cy = cenycc - radmaxc, cenycc + radmaxc do
			local spi = cz * spzstr + cy * spystr + cenxcc - radmaxc + 1
			for cx = cenxcc - radmaxc, cenxcc + radmaxc do
				space[spi] = plid -- add planet id to this chunk
				spi = spi + 1
			end
		end
		end
	end

	addatt = addatt + 1
end


-- Globalstep function

local skybox_space = {
	"planets_skybox_space.png",
	"planets_skybox_space.png",
	"planets_skybox_space.png",
	"planets_skybox_space.png",
	"planets_skybox_space.png",
	"planets_skybox_space.png"
}

minetest.register_globalstep(function(dtime)
	for _, player in ipairs(minetest.get_connected_players()) do
		if math.random() < 0.05 then -- set gravity, skybox and override light
			local ppos = player:getpos()
			ppos.y = ppos.y + 1.5 -- node player head is in
			local nodename = minetest.get_node(ppos).name
			if nodename == "planets:vacuum" or nodename == "ignore" then -- space
				--player:set_physics_override(1, 1, 1) -- speed, jump, gravity
				player:set_sky({r = 0, g = 0, b = 0, a = 0}, "skybox", skybox_space)
				player:override_day_night_ratio(1)
			else -- regular sky for now
				--player:set_physics_override(1, 1, 1) -- speed, jump, gravity
				player:set_sky({}, "regular", {})
				player:override_day_night_ratio(nil)
			end
		end
	end
end)


-- Initialize noise objects to nil

local nobj_terrain = nil
local nobj_cloud = nil


-- Localise noise buffers

local nbuf_terrain
local nbuf_cloud


-- On generated function

minetest.register_on_generated(function(minp, maxp, seed)
	local t0 = os.clock()

	local x0 = minp.x
	local y0 = minp.y
	local z0 = minp.z
	local x1 = maxp.x
	local y1 = maxp.y
	local z1 = maxp.z
	
	-- chunk co-ords of chunk
	-- measured from space origin (-32, -32, -32 chunks)
	local cx0 = math.floor((x0 + 32) / 80) + 32
	local cy0 = math.floor((y0 + 32) / 80) + 32
	local cz0 = math.floor((z0 + 32) / 80) + 32
	-- space table index
	local spi = cz0 * spzstr + cy0 * spystr + cx0 + 1
	-- planet def table index
	local defi = space[spi]
	-- planet def
	local pdef = def[defi]

	local c_air = minetest.get_content_id("air")
	local c_lava = minetest.get_content_id("planets:lava")
	local c_stone = minetest.get_content_id("planets:stone")
	local c_water = minetest.get_content_id("planets:water")
	local c_cloud = minetest.get_content_id("planets:cloud")
	local c_vacuum = minetest.get_content_id("planets:vacuum")
	
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge = emin, MaxEdge = emax}
	local data = vm:get_data()

	if pdef then -- planet chunk
		local pmapdims = {x = 80, y = 80, z = 80} -- perlinmap dimensions
		local pmapminp = {x = x0, y = y0, z = z0} -- perlinmap minp
		local pmapdimsclo = {x = 5, y = 5, z = 5} -- cloud perlinmap dimensions
		local pmapminpclo = {x = x0 / 16, y = y0 / 16, z = z0 / 16} -- cloud perlinmap minp

		nobj_terrain = nobj_terrain or minetest.get_perlin_map(np_terrain, pmapdims)
		nobj_cloud   = nobj_cloud   or minetest.get_perlin_map(np_cloud, pmapdimsclo)

		local nvals_terrain = nobj_terrain:get3dMap_flat(pmapminp, nbuf_terrain)
		local nvals_cloud   = nobj_cloud:get3dMap_flat(pmapminpclo, nbuf_cloud)

		local tersca = (pdef.m - pdef.t) / 2 -- terrain scale

		local ni = 1 -- noise index
		for z = z0, z1 do
		for y = y0, y1 do
			local vi = area:index(x0, y, z) -- luavoxelmanip index
			for x = x0, x1 do
				local nodrad = math.sqrt((x - pdef.i) ^ 2 + -- node radius
					(y - pdef.j) ^ 2 + (z - pdef.k) ^ 2)
				local dengrad = (pdef.t - nodrad) / tersca -- density gradient
				local dennoise = nvals_terrain[ni] -- density noise
				if nodrad <= pdef.t then -- make oceans shallower
					dennoise = dennoise / 2
				end
				local density = dennoise + dengrad -- density

				if nodrad <= pdef.t / 2 then -- lava
					data[vi] = c_lava
				elseif density >= 0 then -- stone
					data[vi] = c_stone
				elseif nodrad <= pdef.t then -- water
					data[vi] = c_water
				elseif dengrad >= -1.0 and dengrad <= -0.95 then -- clouds
					local xq = math.floor((x - x0) / 16) -- quantise position
					local yq = math.floor((y - y0) / 16)
					local zq = math.floor((z - z0) / 16)
					local niq = zq * 25 + yq * 5 + xq + 1
					if nvals_cloud[niq] > 0.5 then
						data[vi] = c_cloud
					end
				elseif nodrad <= pdef.m then -- air
					data[vi] = c_air
				else -- vacuum
					data[vi] = c_vacuum
				end

				ni = ni + 1
				vi = vi + 1
			end
		end
		end
	else -- vacuum chunk
		for z = z0, z1 do
		for y = y0, y1 do
			local vi = area:index(x0, y, z)
			for x = x0, x1 do
				data[vi] = c_vacuum
				vi = vi + 1
			end
		end
		end
	end

	vm:set_data(data)
	if pdef then
		vm:calc_lighting()
	else -- vacuum chunk, don't propagate shadow
		vm:calc_lighting(nil, nil, false)
	end
	vm:write_to_map(data)

	local chugent = math.ceil((os.clock() - t0) * 1000)
	print ("[planets] Generated chunk " .. chugent .. " ms")
end)
