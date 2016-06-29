-- Parameters

local pdef = {cx = 0, cy = 0, cz = 0, tr = 256, ar = 384, tp = 0}

local np_terrain = {
	offset = 0,
	scale = 1.0,
	spread = {x = 96, y = 96, z = 96},
	seed = 921181,
	octaves = 3,
	persist = 0.5
}

-- TODO reduce cloud noise to a 5x5x5 map since is quantised
-- will depend on chunksize = 80

local np_cloud = {
	offset = 0,
	scale = 1,
	spread = {x = 192, y = 192, z = 192},
	seed = 2113,
	octaves = 4,
	persist = 1.0
}


-- Do files

dofile(minetest.get_modpath("planets") .. "/nodes.lua")


-- Mapgen parameters

minetest.set_mapgen_params({mgname = "singlenode",
	flags = "nolight", water_level = -31000})


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
	
	local c_air = minetest.get_content_id("air")
	local c_lava = minetest.get_content_id("planets:lava")
	local c_stone = minetest.get_content_id("planets:stone")
	local c_water = minetest.get_content_id("planets:water")
	local c_cloud = minetest.get_content_id("planets:cloud")
	local c_vacuum = minetest.get_content_id("planets:vacuum")
	
	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge = emin, MaxEdge = emax}
	local data = vm:get_data()

	local sidelen = x1 - x0 + 1
	local facearea = sidelen ^ 2
	local chulens = {x = sidelen, y = sidelen, z = sidelen}
	local minpos = {x = x0, y = y0, z = z0}

	nobj_terrain = nobj_terrain or minetest.get_perlin_map(np_terrain, chulens)
	nobj_cloud   = nobj_cloud   or minetest.get_perlin_map(np_cloud, chulens)

	local nvals_terrain = nobj_terrain:get3dMap_flat(minpos, nbuf_terrain)
	local nvals_cloud   = nobj_cloud:get3dMap_flat(minpos, nbuf_cloud)

	local tersca = (pdef.ar - pdef.tr) / 2

	local ni = 1
	for z = z0, z1 do
	for y = y0, y1 do
		local vi = area:index(x0, y, z)
		for x = x0, x1 do
			local nodrad = math.sqrt((x - pdef.cx) ^ 2 +
				(y - pdef.cy) ^ 2 + (z - pdef.cz) ^ 2)
			local dengrad = (pdef.tr - nodrad) / tersca
			local dennoise = nvals_terrain[ni]
			if nodrad <= pdef.tr then
				dennoise = dennoise / 2
			end
			local density = dennoise + dengrad

			if nodrad <= pdef.tr / 2 then
				data[vi] = c_lava
			elseif density >= 0 then
				data[vi] = c_stone
			elseif nodrad <= pdef.tr then
				data[vi] = c_water
			elseif dengrad >= -1.0 and dengrad <= -0.9 then
				local xrq = 16 * math.floor((x - x0) / 16)
				local yrq = 16 * math.floor((y - y0) / 16)
				local zrq = 16 * math.floor((z - z0) / 16)
				local qixyz = zrq * facearea + yrq * sidelen + xrq + 1
				if nvals_cloud[qixyz] > 0 then
					data[vi] = c_cloud
				end
			elseif nodrad <= pdef.ar then
				data[vi] = c_air
			else
				data[vi] = c_vacuum
			end
	
			ni = ni + 1
			vi = vi + 1
		end
	end
	end
	
	vm:set_data(data)
	vm:calc_lighting()
	vm:write_to_map(data)

	local chugent = math.ceil((os.clock() - t0) * 1000)
	print ("[planets] " .. chugent)
end)
