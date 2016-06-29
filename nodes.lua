minetest.register_node("planets:stone", {
	description = "Stone",
	tiles = {"default_stone.png"},
	groups = {cracky = 3, stone = 1},
	sounds = default.node_sound_stone_defaults(),
})

minetest.register_node("planets:cloud", {
	description = "Cloud",
	drawtype = "glasslike",
	tiles = {"planets_cloud.png"},
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	floodable = true,
	post_effect_color = {a = 31, r = 241, g = 248, b = 255},
	groups = {not_in_creative_inventory = 1},
})

minetest.register_node("planets:vacuum", {
	description = "Vacuum",
	drawtype = "airlike",
	paramtype = "light",
	is_ground_content = false,
	sunlight_propagates = true,
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	floodable = true,
	drowning = 1,
})

minetest.register_node("planets:water", {
	description = "Water Source",
	inventory_image = minetest.inventorycube("default_water.png"),
	drawtype = "liquid",
	tiles = {
		{
			name = "default_water_source_animated.png",
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = 2.0,
			},
		},
	},
	alpha = WATER_ALPHA,
	paramtype = "light",
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	drop = "",
	drowning = 1,
	liquidtype = "source",
	liquid_alternative_flowing = "planets:water",
	liquid_alternative_source = "planets:water",
	liquid_viscosity = WATER_VISC,
	liquid_renewable = false,
	liquid_range = 0,
	post_effect_color = {a = 64, r = 100, g = 100, b = 200},
	groups = {water = 3, liquid = 3, puts_out_fire = 1},
})

minetest.register_node("planets:lava", {
	description = "Lava Source",
	inventory_image = minetest.inventorycube("default_lava.png"),
	drawtype = "liquid",
	tiles = {
		{
			name = "default_lava_source_animated.png",
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = 3.0,
			},
		},
	},
	paramtype = "light",
	light_source = LIGHT_MAX - 1,
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	drop = "",
	drowning = 1,
	liquidtype = "source",
	liquid_alternative_flowing = "planets:lava",
	liquid_alternative_source = "planets:lava",
	liquid_viscosity = LAVA_VISC,
	liquid_renewable = false,
	liquid_range = 0,
	damage_per_second = 8,
	post_effect_color = {a = 192, r = 255, g = 64, b = 0},
	groups = {lava = 3, liquid = 2, igniter = 1},
})
