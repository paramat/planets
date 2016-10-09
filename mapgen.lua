minetest.clear_registered_ores()
minetest.clear_registered_decorations()

-- Gravel

minetest.register_ore({
	ore_type        = "blob",
	ore             = "default:gravel",
	wherein         = {"planets:stone", "planets:moon_stone"},
	clust_scarcity  = 16 * 16 * 16,
	clust_size      = 5,
	y_min           = -31000,
	y_max           = 31000,
	noise_threshold = 0.0,
	noise_params    = {
		offset = 0.5,
		scale = 0.2,
		spread = {x = 5, y = 5, z = 5},
		seed = 766,
		octaves = 1,
		persist = 0.0
	},
})

-- Coal

minetest.register_ore({
	ore_type       = "scatter",
	ore            = "default:stone_with_coal",
	wherein        = "planets:stone",
	clust_scarcity = 8 * 8 * 8,
	clust_num_ores = 9,
	clust_size     = 3,
	y_min          = -31000,
	y_max          = 31000,
})

-- Iron

minetest.register_ore({
	ore_type       = "scatter",
	ore            = "default:stone_with_iron",
	wherein        = {"planets:stone", "planets:moon_stone"},
	clust_scarcity = 9 * 9 * 9,
	clust_num_ores = 12,
	clust_size     = 3,
	y_min          = -31000,
	y_max          = 31000,
})

-- Copper

minetest.register_ore({
	ore_type       = "scatter",
	ore            = "default:stone_with_copper",
	wherein        = {"planets:stone", "planets:moon_stone"},
	clust_scarcity = 9 * 9 * 9,
	clust_num_ores = 5,
	clust_size     = 3,
	y_min          = -31000,
	y_max          = 31000,
})

-- Gold

minetest.register_ore({
	ore_type       = "scatter",
	ore            = "default:stone_with_gold",
	wherein        = {"planets:stone", "planets:moon_stone"},
	clust_scarcity = 13 * 13 * 13,
	clust_num_ores = 5,
	clust_size     = 3,
	y_min          = -31000,
	y_max          = 31000,
})

-- Mese crystal

minetest.register_ore({
	ore_type       = "scatter",
	ore            = "default:stone_with_mese",
	wherein        = {"planets:stone", "planets:moon_stone"},
	clust_scarcity = 14 * 14 * 14,
	clust_num_ores = 5,
	clust_size     = 3,
	y_min          = -31000,
	y_max          = 31000,
})

-- Diamond

minetest.register_ore({
	ore_type       = "scatter",
	ore            = "default:stone_with_diamond",
	wherein        = {"planets:stone", "planets:moon_stone"},
	clust_scarcity = 15 * 15 * 15,
	clust_num_ores = 4,
	clust_size     = 3,
	y_min          = -31000,
	y_max          = 31000,
})

-- Mese block

minetest.register_ore({
	ore_type       = "scatter",
	ore            = "default:mese",
	wherein        = {"planets:stone", "planets:moon_stone"},
	clust_scarcity = 36 * 36 * 36,
	clust_num_ores = 3,
	clust_size     = 2,
	y_min          = -31000,
	y_max          = 31000,
})

-- Grasses

local function register_grass_decoration(offset, scale, length)
	minetest.register_decoration({
		deco_type = "simple",
		place_on = {"planets:grass"},
		sidelen = 16,
		noise_params = {
			offset = offset,
			scale = scale,
			spread = {x = 200, y = 200, z = 200},
			seed = 329,
			octaves = 3,
			persist = 0.6
		},
		y_min = -31000,
		y_max = 31000,
		decoration = "default:grass_"..length,
	})
end

register_grass_decoration(-0.03,  0.09,  5)
register_grass_decoration(-0.015, 0.075, 4)
register_grass_decoration(0,      0.06,  3)
register_grass_decoration(0.015,  0.045, 2)
register_grass_decoration(0.03,   0.03,  1)

-- Appletrees

minetest.register_decoration({
	deco_type = "schematic",
	place_on = {"planets:grass"},
	sidelen = 16,
	noise_params = {
		offset = 0.036,
		scale = 0.022,
		spread = {x = 250, y = 250, z = 250},
		seed = 2,
		octaves = 3,
		persist = 0.66
	},
	y_min = -31000,
	y_max = 31000,
	schematic = minetest.get_modpath("default").."/schematics/apple_tree.mts",
	flags = "place_center_x, place_center_z",
})

-- Flowers

local function register_flower(seed, name)
	minetest.register_decoration({
		deco_type = "simple",
		place_on = {"planets:grass"},
		sidelen = 16,
		noise_params = {
			offset = -0.015,
			scale = 0.025,
			spread = {x = 200, y = 200, z = 200},
			seed = seed,
			octaves = 3,
			persist = 0.6
		},
		y_min = -31000,
		y_max = 31000,
		decoration = "flowers:"..name,
	})
end

register_flower(436,     "rose")
register_flower(19822,   "tulip")
register_flower(1220999, "dandelion_yellow")
register_flower(36662,   "geranium")
register_flower(1133,    "viola")
register_flower(73133,   "dandelion_white")

-- Mushrooms

local function register_mushroom(name)
	minetest.register_decoration({
		deco_type = "simple",
		place_on = {"planets:grass"},
		sidelen = 16,
		noise_params = {
			offset = 0,
			scale = 0.006,
			spread = {x = 250, y = 250, z = 250},
			seed = 2,
			octaves = 3,
			persist = 0.66
		},
		y_min = -31000,
		y_max = 31000,
		decoration = "flowers:"..name,
	})
end

register_mushroom("mushroom_brown")
register_mushroom("mushroom_red")
