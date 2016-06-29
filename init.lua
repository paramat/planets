-- Parameters

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


-- Space array and planet def table

-- space is 64 ^ 3 chunks, centred on world centre
-- space table is flat array of planet ids or nil (vacuum chunk)
local space = {}
-- planet definition table indexed by planet id
local def = {}
local spzstr = 64 * 64 -- space array z stride
local spystr = 64 -- space array y stride

-- planet centres are at chunk minp
-- cenx/y/z is planet centre in chunk co-ords
-- rter = terrain radius / water level
-- ratm = atmosphere radius. var = planet variation
local cenx = 32
local ceny = 32
local cenz = 32
local rter = 256
local ratm = 384
local var = 1
-- planet id 1
def[1] = {i = cenx, j = ceny, k = cenz, t = rter, a = ratm, v = var}

local rchu = math.ceil(ratm / 80) -- radius in chunks

-- TODO add scan loop to check for existing planets

for cz = cenz - rchu, cenz + rchu do
for cy = ceny - rchu, ceny + rchu do
	local spi = cz * spzstr + cy * spystr + cenx - rchu + 1
	for cx = cenx - rchu, cenx + rchu do
		space[spi] = 1
		spi = spi + 1
	end
end
end


-- Globalstep function

local skybox_space = {
	"planets_skybox_space_posy.png",
	"planets_skybox_space.png",
	"planets_skybox_space.png",
	"planets_skybox_space.png",
	"planets_skybox_space.png",
	"planets_skybox_space.png"
}

minetest.register_globalstep(function(dtime)
	for _, player in ipairs(minetest.get_connected_players()) do
		if math.random() < 0.02 then -- set gravity, skybox and override light
			local ppos = player:getpos()
			ppos.y = ppos.y + 1.5 -- node player head is in
			if minetest.get_node(ppos).name == "planets:vacuum" then
				--player:set_physics_override(1, 1, 1) -- speed, jump, gravity
				player:set_sky({r = 0, g = 0, b = 0, a = 0}, "skybox", skybox_space)
				player:override_day_night_ratio(1)
			else
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
	
	-- minp in chunk co-ords measured from space origin (-32, -32, -32 chunks)
	local cx0 = math.floor(x0 / 80) + 32
	local cy0 = math.floor(y0 / 80) + 32
	local cz0 = math.floor(z0 / 80) + 32
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
		local chudims = x1 - x0 + 1 -- mapchunk dimensions
		local pmapzstr = chudims * chudims -- perlinmap z stride, y stride
		local pmapystr = chudims
		local pmapdims = {x = chudims, y = chudims, z = chudims} -- perlinmap dimensions
		local pmapminp = {x = x0, y = y0, z = z0} -- perlinmap minp

		nobj_terrain = nobj_terrain or minetest.get_perlin_map(np_terrain, pmapdims)
		nobj_cloud   = nobj_cloud   or minetest.get_perlin_map(np_cloud, pmapdims)

		local nvals_terrain = nobj_terrain:get3dMap_flat(pmapminp, nbuf_terrain)
		local nvals_cloud   = nobj_cloud:get3dMap_flat(pmapminp, nbuf_cloud)

		local tersca = (pdef.a - pdef.t) / 2 -- terrain scale

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
					local xq = 16 * math.floor((x - x0) / 16) -- quantise position
					local yq = 16 * math.floor((y - y0) / 16)
					local zq = 16 * math.floor((z - z0) / 16)
					local niq = zq * pmapzstr + yq * pmapystr + xq + 1
					if nvals_cloud[niq] > 0 then
						data[vi] = c_cloud
					end
				elseif nodrad <= pdef.a then -- air
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
	print ("[planets] " .. chugent .. " ms")
end)
