-- Parameters

local pnum = 512 -- number of planets desired
local maxatt = 8192 -- maximum number of attempts to add a planet

local np_terrain = {
	offset = 0,
	scale = 1.0,
	spread = {x = 192, y = 192, z = 192},
	seed = 921181,
	octaves = 4,
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


-- Create planetary system

-- space is 128 ^ 3 chunks, centred on world centre
-- space table is flat array of planet ids or nil (vacuum chunk)
local space = {}
-- planet definition table indexed by planet id
local def = {}
local spzstr = 128 * 128 -- space array z stride
local spystr = 128 -- space array y stride
local plid = 0 -- planet id of last planet added, 0 = none
local addatt = 0 -- number of attempts to add a planet
math.randomseed(42) -- set pseudorandom seed

while plid < pnum and addatt <= maxatt do -- avoid infinite attempts
	-- create initial planet data to check for obstruction
		-- cenx/y/z is planet centre
		-- radmax = atmosphere radius or max mountain radius
	local radmax = math.random(128, 512)
	local cenx = math.random(-5000 + radmax, 5000 - radmax)
	local ceny = math.random(-5000 + radmax, 5000 - radmax)
	local cenz = math.random(-5000 + radmax, 5000 - radmax)

	-- chunk co-ords of chunk containing planet centre 
	-- measured from space origin (-64, -64, -64 chunks)
	local cenxcc = math.floor((cenx + 32) / 80) + 64
	local cenycc = math.floor((ceny + 32) / 80) + 64
	local cenzcc = math.floor((cenz + 32) / 80) + 64
	local radmaxc = math.ceil(radmax / 80) -- planet radius in chunks

	-- check space is clear for planet
	local clear = true -- is space clear

	for cz = cenzcc - radmaxc, cenzcc + radmaxc do
		for cy = cenycc - radmaxc, cenycc + radmaxc do
			local spi = cz * spzstr + cy * spystr + cenxcc - radmaxc + 1
			for cx = cenxcc - radmaxc, cenxcc + radmaxc do
				if space[spi] ~= nil then
					clear = false
					--print ("[planets] Planet obstructed")
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

	if clear then -- generate more data and add planet
		local tersca = math.random(16, 64) -- terrain scale / cloud height
		-- average terrain level / density gradient zero
		local radter = radmax - tersca * 2
		local radlav = (radter - tersca * 2) / 2 -- lava core radius
		local ocean = true -- liquid ocean
		local radwat = radter - 2 -- water level 2 nodes below terrain squash
		local atmos = true -- gaseous atmosphere to radmax
		local clot = -2 + math.random() * 4 -- cloud noise threshold

		plid = #def + 1 -- planet id
		-- add planet data to def table
		def[plid] = {
			x = cenx,
			y = ceny,
			z = cenz,
			m = radmax,
			s = tersca,
			t = radter,
			l = radlav,
			o = ocean,
			w = radwat,
			a = atmos,
			c = clot,
		}
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


-- Spawn above planet 1

local pdef = def[1]
local spawn_pos = {x = pdef.x, y = pdef.y + pdef.m - 4, z = pdef.z}

minetest.register_on_newplayer(function(player)
	player:setpos(spawn_pos)
end)

minetest.register_on_respawnplayer(function(player)
	player:setpos(spawn_pos)
	return true
end)


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
		if math.random() < 0.03 then -- set gravity, skybox and override light
			local ppos = player:getpos()
			-- chunk co-ords of player
			-- measured from space origin (-64, -64, -64 chunks)
			local cpposx = math.floor((ppos.x + 32) / 80) + 64
			local cpposy = math.floor((ppos.y + 32) / 80) + 64
			local cpposz = math.floor((ppos.z + 32) / 80) + 64
			-- space table index
			local spi = cpposz * spzstr + cpposy * spystr + cpposx + 1
			local defi = space[spi] -- planet def table index
			local pdef = def[defi] -- planet def
			local grav = 0 -- initialise to vacuum chunk
			if pdef then -- planet chunk
				grav = pdef.t / 384 -- gravity override
			end

			ppos.y = ppos.y + 1.5 -- node player head is in
			local nodename = minetest.get_node(ppos).name
			if nodename == "planets:vacuum" or nodename == "ignore" then -- space
				player:set_physics_override(1, 1, 0) -- speed, jump, gravity
				player:set_sky({r = 0, g = 0, b = 0, a = 0}, "skybox", skybox_space)
				player:override_day_night_ratio(1)
			else -- planet
				player:set_physics_override(1, 1, grav) -- speed, jump, gravity
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

local tree_path = minetest.get_modpath("default") .. "/schematics/apple_tree.mts"

minetest.register_on_generated(function(minp, maxp, seed)
	local t0 = os.clock()
	local tree_pos = {} -- table of tree positions for schematic adding

	local x0 = minp.x
	local y0 = minp.y
	local z0 = minp.z
	local x1 = maxp.x
	local y1 = maxp.y
	local z1 = maxp.z
	
	-- chunk co-ords of chunk
	-- measured from space origin (-64, -64, -64 chunks)
	local cx0 = math.floor((x0 + 32) / 80) + 64
	local cy0 = math.floor((y0 + 32) / 80) + 64
	local cz0 = math.floor((z0 + 32) / 80) + 64
	-- space table index
	local spi = cz0 * spzstr + cy0 * spystr + cx0 + 1
	-- planet def table index
	local defi = space[spi]
	-- planet def
	local pdef = def[defi]
	
	local c_vacuum = minetest.get_content_id("planets:vacuum")

	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge = emin, MaxEdge = emax}
	local data = vm:get_data()

	if pdef then -- planet chunk
		local c_air = minetest.get_content_id("air")
		local c_lava = minetest.get_content_id("planets:lava")
		local c_stone = minetest.get_content_id("planets:stone")
		local c_sand = minetest.get_content_id("planets:sand")
		local c_dirt = minetest.get_content_id("planets:dirt")
		local c_grass = minetest.get_content_id("planets:grass")
		local c_water = minetest.get_content_id("planets:water")
		local c_cloud = minetest.get_content_id("planets:cloud")

		local pmapdims = {x = 80, y = 80, z = 80} -- perlinmap dimensions
		local pmapminp = {x = x0, y = y0, z = z0} -- perlinmap minp
		local pmapdimsclo = {x = 5, y = 5, z = 5} -- cloud perlinmap dimensions
		local pmapminpclo = {x = x0 / 16, y = y0 / 16, z = z0 / 16} -- cloud perlinmap minp

		nobj_terrain = nobj_terrain or minetest.get_perlin_map(np_terrain, pmapdims)
		nobj_cloud   = nobj_cloud   or minetest.get_perlin_map(np_cloud, pmapdimsclo)

		local nvals_terrain = nobj_terrain:get3dMap_flat(pmapminp, nbuf_terrain)
		local nvals_cloud   = nobj_cloud:get3dMap_flat(pmapminpclo, nbuf_cloud)

		-- auto set noise thresholds
		local surt = 1 / pdef.s -- surface threshold for flora
		local dirt = 1.5 / pdef.s -- dirt
		local stot = 3 / pdef.s -- stone

		local ni = 1 -- noise index
		for z = z0, z1 do
		for y = y0, y1 do
			local vi = area:index(x0, y, z) -- luavoxelmanip index
			for x = x0, x1 do
				local xcr = x - pdef.x -- x centre-relative
				local ycr = y - pdef.y
				local zcr = z - pdef.z
				local top = ycr > math.abs(xcr) and ycr > math.abs(zcr) -- planet top

				local nodrad = math.sqrt(xcr ^ 2 + ycr ^ 2 + zcr ^ 2) -- node radius
				local dengrad = (pdef.t - nodrad) / pdef.s -- density gradient
				local dennoise = nvals_terrain[ni] -- density noise
				if pdef.o and nodrad <= pdef.w + 2 then -- if ocean squash terrain
					dennoise = dennoise / 2
				end
				local density = dennoise + dengrad -- density

				if nodrad <= pdef.l then -- magma
					data[vi] = c_lava
				elseif density >= stot then -- stone
					data[vi] = c_stone
				elseif density >= 0 then -- fine materials
					if nodrad <= pdef.w + 2 then
						data[vi] = c_sand
					elseif density >= dirt then
						data[vi] = c_dirt
					else
						data[vi] = c_grass
						-- apple trees
						if top and density <= surt and math.random() < 0.02 then
							-- store pos to add schematic later
							tree_pos[#tree_pos + 1] = {x = x - 2, y = y, z = z - 2}
						end
					end
				elseif pdef.o and nodrad <= pdef.w then -- ocean
					data[vi] = c_water
				elseif pdef.a and pdef.c < 2 and
						dengrad >= -1.0 and dengrad <= -0.95 then -- clouds
					local xq = math.floor((x - x0) / 16) -- quantise position
					local yq = math.floor((y - y0) / 16)
					local zq = math.floor((z - z0) / 16)
					local niq = zq * 25 + yq * 5 + xq + 1
					if nvals_cloud[niq] > pdef.c then
						data[vi] = c_cloud
					end
				elseif pdef.a and nodrad <= pdef.m then -- air
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

	-- place trees
	for tree_id = 1, #tree_pos do
		minetest.place_schematic_on_vmanip(vm,
			tree_pos[tree_id], tree_path, "0", nil, false)
	end

	if pdef then
		vm:calc_lighting()
	else -- vacuum chunk, don't propagate shadow from above
		vm:calc_lighting(nil, nil, false)
	end
	vm:write_to_map(data)

	local chugent = math.ceil((os.clock() - t0) * 1000)
	print ("[planets] Generated chunk " .. chugent .. " ms")
end)
