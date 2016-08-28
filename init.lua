-- Parameters

local pnum = 1024 -- number of planets desired
local maxatt = 8192 -- maximum number of attempts to add a planet

local np_terrain1 = {
	offset = 0,
	scale = 1.0,
	spread = {x = 192, y = 192, z = 192},
	seed = 921181,
	octaves = 4,
	persist = 0.6,
	lacunarity = 2.0,
}

local np_terrain2 = {
	offset = 0,
	scale = 0.5,
	spread = {x = 192, y = 192, z = 192},
	seed = 30091,
	octaves = 4,
	persist = 0.4,
	lacunarity = 2.0,
	flags = "eased"
}

local np_fissure = {
	offset = 0,
	scale = 1.0,
	spread = {x = 96, y = 96, z = 96},
	seed = 921181,
	octaves = 3,
	persist = 0.6,
	lacunarity = 2.0,
}

local np_cloud = {
	offset = 0,
	scale = 1,
	spread = {x = 8, y = 8, z = 8},
	seed = 2113,
	octaves = 3,
	persist = 1.0,
	lacunarity = 2.0,
}


-- Do files

dofile(minetest.get_modpath("planets") .. "/nodes.lua")


-- Content ids

local cids = {
	air = minetest.get_content_id("air"),
	vacuum = minetest.get_content_id("planets:vacuum"),
	lava = minetest.get_content_id("planets:lava"),
	stone = minetest.get_content_id("planets:stone"),
	sand = minetest.get_content_id("planets:sand"),
	dirt = minetest.get_content_id("planets:dirt"),
	grass = minetest.get_content_id("planets:grass"),
	water = minetest.get_content_id("planets:water"),
	cloud = minetest.get_content_id("planets:cloud"),
}


-- Mapgen parameters

minetest.set_mapgen_params({mgname = "singlenode",
	chunksize = 5, water_level = -31000, flags = "nolight"})


-- Create planetary system

-- space is 128 ^ 3 mapchunks, centred on world centre
-- space table is flat array of planet ids or nil (vacuum mapchunk)
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
	local radmax = 640
	local cenx = math.random(-5000 + radmax, 5000 - radmax)
	local ceny = math.random(-5000 + radmax, 5000 - radmax)
	local cenz = math.random(-5000 + radmax, 5000 - radmax)

	-- mapchunk co-ords of chunk containing planet centre 
	-- measured from space origin (-64, -64, -64 mapchunks)
	local cenxcc = math.floor((cenx + 32) / 80) + 64
	local cenycc = math.floor((ceny + 32) / 80) + 64
	local cenzcc = math.floor((cenz + 32) / 80) + 64
	local radmaxc = math.ceil(radmax / 80) -- planet radius in mapchunks

	-- check space is clear for planet
	local clear = true -- is space clear

	for cz = cenzcc - radmaxc, cenzcc + radmaxc do
		for cy = cenycc - radmaxc, cenycc + radmaxc do
			local spi = cz * spzstr + cy * spystr + cenxcc - radmaxc + 1
			for cx = cenxcc - radmaxc, cenxcc + radmaxc do
				if space[spi] ~= nil then
					clear = false
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

	if clear then -- generate more data
		local tersca = 64 -- terrain scale / cloud height
		local radter = radmax - tersca * 2 -- average terrain level / density grad zero
		local radlav = (radter - tersca * 2) / 2 -- lava core radius
		local ocean = true -- liquid ocean
		local radwat = radter - 2 -- water level 2 nodes below terrain squash
		local atmos = true -- gaseous atmosphere to radmax
		local clothr = -1 + math.random() * 2 -- cloud noise threshold
		local ternoi = math.random(1, 2) -- terrain noise

		plid = #def + 1 -- planet id
		-- add planet data to def table
		def[plid] = {
			cx = cenx,
			cy = ceny,
			cz = cenz,
			rm = radmax,
			ts = tersca,
			rt = radter,
			rl = radlav,
			ob = ocean,
			rw = radwat,
			ab = atmos,
			ct = clothr,
			tn = ternoi,
		}
		print ("[planets] Adding planet " .. plid)

		-- add planet id to space table
		for cz = cenzcc - radmaxc, cenzcc + radmaxc do
		for cy = cenycc - radmaxc, cenycc + radmaxc do
			local spi = cz * spzstr + cy * spystr + cenxcc - radmaxc + 1
			for cx = cenxcc - radmaxc, cenxcc + radmaxc do
				space[spi] = plid
				spi = spi + 1
			end
		end
		end
	end

	addatt = addatt + 1
end
print ("[planets] Add attempts " .. addatt)


-- Spawn above planet 1

local pdef = def[1]
local spawn_pos = {x = pdef.cx, y = pdef.cy + pdef.rm - 2, z = pdef.cz}

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
			local pdef = nil
			local in_radmax = false -- player within radmax of planet
			local ppos = player:getpos()
			-- mapchunk co-ords of player
			-- measured from space origin (-64, -64, -64 mapchunks)
			local cpposx = math.floor((ppos.x + 32) / 80) + 64
			local cpposy = math.floor((ppos.y + 32) / 80) + 64
			local cpposz = math.floor((ppos.z + 32) / 80) + 64
			if cpposx >= 0 and cpposx <= 127 and -- if inside space array
					cpposy >= 0 and cpposy <= 127 and
					cpposz >= 0 and cpposz <= 127 then
				-- space table index
				local spi = cpposz * spzstr + cpposy * spystr + cpposx + 1
				local defi = space[spi] -- planet def table index
				pdef = def[defi] -- planet def
				if pdef then
					in_radmax = (ppos.x - pdef.cx) ^ 2 +
						(ppos.y - pdef.cy) ^ 2 +
						(ppos.z - pdef.cz) ^ 2 <= pdef.rm ^ 2
				end
			end

			if pdef and in_radmax then
				local grav = pdef.rt / 512 -- gravity override
				local jump = 1 - (1 - grav) * 0.5 -- jump override
				player:set_physics_override(1, jump, grav) -- speed, jump, gravity
				player:set_sky({}, "regular", {})
				player:override_day_night_ratio(nil)
			else
				player:set_physics_override(1, 1, 0) -- speed, jump, gravity
				player:set_sky({r = 0, g = 0, b = 0, a = 0}, "skybox", skybox_space)
				player:override_day_night_ratio(1)
			end
		end
	end
end)


-- Initialize noise objects to nil

local nobj_terrain1 = nil
local nobj_terrain2 = nil
local nobj_fissure = nil
local nobj_cloud = nil


-- Localise noise buffers

local nbuf_terrain1
local nbuf_terrain2
local nbuf_fissure
local nbuf_cloud


-- On generated function

local tree_path = minetest.get_modpath("default") .. "/schematics/apple_tree.mts"

minetest.register_on_generated(function(minp, maxp, seed)
	local t0 = os.clock()

	local x0 = minp.x
	local y0 = minp.y
	local z0 = minp.z
	local x1 = maxp.x
	local y1 = maxp.y
	local z1 = maxp.z
	
	local pdef = nil
	-- mapchunk co-ords of mapchunk
	-- measured from space origin (-64, -64, -64 mapchunks)
	local cx0 = math.floor((x0 + 32) / 80) + 64
	local cy0 = math.floor((y0 + 32) / 80) + 64
	local cz0 = math.floor((z0 + 32) / 80) + 64
	if cx0 >= 0 and cx0 <= 127 and
			cy0 >= 0 and cy0 <= 127 and
			cz0 >= 0 and cz0 <= 127 then -- inside space
		-- space table index
		local spi = cz0 * spzstr + cy0 * spystr + cx0 + 1
		-- planet def table index
		local defi = space[spi]
		-- planet def
		pdef = def[defi]
	end
	
	local tree_pos = {} -- table of tree positions for schematic adding

	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge = emin, MaxEdge = emax}
	local data = vm:get_data()

	if pdef then -- planet mapchunk
		local pmapdims = {x = 80, y = 80, z = 80} -- perlinmap dimensions
		local pmapminp = {x = x0, y = y0, z = z0} -- perlinmap minp
		local pmapdimsclo = {x = 5, y = 5, z = 5} -- cloud perlinmap dimensions
		local pmapminpclo = {x = x0 / 16, y = y0 / 16, z = z0 / 16} -- cloud perlinmap minp

		local nvals_terrain
		if pdef.tn == 1 then
			nobj_terrain1 = nobj_terrain1 or minetest.get_perlin_map(np_terrain1, pmapdims)
			nvals_terrain = nobj_terrain1:get3dMap_flat(pmapminp, nbuf_terrain1)
		elseif pdef.tn == 2 then
			nobj_terrain2 = nobj_terrain2 or minetest.get_perlin_map(np_terrain2, pmapdims)
			nvals_terrain = nobj_terrain2:get3dMap_flat(pmapminp, nbuf_terrain2)
		end

		nobj_fissure = nobj_fissure or minetest.get_perlin_map(np_fissure, pmapdims)
		local nvals_fissure = nobj_fissure:get3dMap_flat(pmapminp, nbuf_fissure)

		nobj_cloud = nobj_cloud or minetest.get_perlin_map(np_cloud, pmapdimsclo)
		local nvals_cloud = nobj_cloud:get3dMap_flat(pmapminpclo, nbuf_cloud)

		-- auto set noise thresholds
		local surt = 1 / pdef.ts -- surface threshold for flora
		local dirt = 1.5 / pdef.ts -- dirt
		local stot = 3 / pdef.ts -- stone

		local ni = 1 -- noise index
		for z = z0, z1 do
		for y = y0, y1 do
			local vi = area:index(x0, y, z) -- luavoxelmanip index
			for x = x0, x1 do
				local xcr = x - pdef.cx -- x centre-relative
				local ycr = y - pdef.cy
				local zcr = z - pdef.cz
				local top = ycr > math.abs(xcr) and ycr > math.abs(zcr) -- planet top

				local nodrad = math.sqrt(xcr ^ 2 + ycr ^ 2 + zcr ^ 2) -- node radius
				local dengrad = (pdef.rt - nodrad) / pdef.ts -- density gradient
				local dennoise = nvals_terrain[ni] -- density noise
				if pdef.ob and nodrad <= pdef.rw + 2 then -- if ocean squash terrain
					dennoise = dennoise / 2
				end
				local density = dennoise + dengrad -- density

				local n_fissure = math.abs(nvals_fissure[ni])
				local is_fissure = n_fissure < 0.04

				if nodrad <= pdef.rl then
					data[vi] = cids.lava -- magma
				elseif density >= stot then -- below stone level
					if is_fissure then
						data[vi] = cids.air -- fissure air
					else
						data[vi] = cids.stone -- stone
					end
				elseif density >= 0 then -- below terrain level
					if nodrad <= pdef.rw + 2 then
						data[vi] = cids.sand -- sand
					elseif is_fissure then
						data[vi] = cids.air -- fissure air
					elseif density >= dirt then
						data[vi] = cids.dirt -- dirt
					else
						data[vi] = cids.grass -- grass
						-- apple trees
						if top and density <= surt and math.random() < 0.02 then
							-- store pos to add schematic later
							tree_pos[#tree_pos + 1] = {x = x - 2, y = y, z = z - 2}
						end
					end
				elseif pdef.ob and nodrad <= pdef.rw then
					data[vi] = cids.water -- water
				elseif pdef.ab and pdef.ct < 2 and
						dengrad >= -1.0 and dengrad <= -0.95 then
					local xq = math.floor((x - x0) / 16) -- quantise position
					local yq = math.floor((y - y0) / 16)
					local zq = math.floor((z - z0) / 16)
					local niq = zq * 25 + yq * 5 + xq + 1
					if nvals_cloud[niq] > pdef.ct then
						data[vi] = cids.cloud -- cloud
					end
				elseif pdef.ab and nodrad <= pdef.rm then
					data[vi] = cids.air -- air
				else
					data[vi] = cids.vacuum -- vacuum
				end

				ni = ni + 1
				vi = vi + 1
			end
		end
		end
	else -- vacuum mapchunk
		for z = z0, z1 do
		for y = y0, y1 do
			local vi = area:index(x0, y, z)
			for x = x0, x1 do
				data[vi] = cids.vacuum
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
	else -- vacuum mapchunk, don't propagate shadow from above
		vm:calc_lighting(nil, nil, false)
	end
	vm:write_to_map(data)

	local chugent = math.ceil((os.clock() - t0) * 1000)
	print ("[planets] Generated chunk " .. chugent .. " ms")
end)
