# The MIT License (MIT)
#
# Copyright (c) 2018 George Marques
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

tool
extends Reference

# Constants for tile flipping
# http://doc.mapeditor.org/reference/tmx-map-format/#tile-flipping
const FLIPPED_HORIZONTALLY_FLAG = 0x80000000
const FLIPPED_VERTICALLY_FLAG   = 0x40000000
const FLIPPED_DIAGONALLY_FLAG   = 0x20000000

const DataValidator = preload("data_validator.gd")
const Utils = preload("utils.gd")
# XML Format reader
const XMLToDictionary = preload("xml_to_dict.gd")

# Polygon vertices sorter
const PolygonSorter = preload("polygon_sorter.gd")

# Prefix for error messages, make easier to identify the source
const error_prefix = "Tiled Importer: "

# Custom function to print error, to centralize the prefix addition
static func print_error(err):
	printerr(error_prefix + err)

# Properties to save the value in the metadata
const whitelist_properties = [
	"backgroundcolor",
	"compression",
	"draworder",
	"gid",
	"height",
	"imageheight",
	"imagewidth",
	"infinite",
	"margin",
	"name",
	"orientation",
	"probability",
	"spacing",
	"tilecount",
	"tiledversion",
	"tileheight",
	"tilewidth",
	"type",
	"version",
	"visible",
	"width",
	"custom_material"
]

# All templates loaded, can be looked up by path name
var _loaded_templates = {}
# Maps each tileset file used by the map to it's first gid; Used for template parsing
var _tileset_path_to_first_gid = {}

func reset_global_memebers():
	_loaded_templates = {}
	_tileset_path_to_first_gid = {}

# Main function
# Reads a source file and gives back a scene
func build(source_path, options):
	reset_global_memebers()
	var map = read_file(source_path)
	if typeof(map) == TYPE_INT:
		return map
	if typeof(map) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA

	var err = DataValidator.validate_map(map)
	if err != OK:
		return err

	var cell_size = Vector2(int(map.tilewidth), int(map.tileheight))
	var map_mode = TileMap.MODE_SQUARE
	var map_offset = TileMap.HALF_OFFSET_DISABLED
	var map_pos_offset = Vector2()
	var map_background = Color()
	var cell_offset = Vector2()
	if "orientation" in map:
		match map.orientation:
			"isometric":
				map_mode = TileMap.MODE_ISOMETRIC
			"staggered":
				map_pos_offset.y -= cell_size.y / 2
				match map.staggeraxis:
					"x":
						map_offset = TileMap.HALF_OFFSET_Y
						cell_size.x /= 2.0
						if map.staggerindex == "even":
							cell_offset.x += 1
							map_pos_offset.x -= cell_size.x
					"y":
						map_offset = TileMap.HALF_OFFSET_X
						cell_size.y /= 2.0
						if map.staggerindex == "even":
							cell_offset.y += 1
							map_pos_offset.y -= cell_size.y
			"hexagonal":
				# Godot maps are always odd and don't have an "even" setting. To
				# imitate even staggering we simply start one row/column late and
				# adjust the position of the whole map.
				match map.staggeraxis:
					"x":
						map_offset = TileMap.HALF_OFFSET_Y
						cell_size.x = int((cell_size.x + map.hexsidelength) / 2)
						if map.staggerindex == "even":
							cell_offset.x += 1
							map_pos_offset.x -= cell_size.x
					"y":
						map_offset = TileMap.HALF_OFFSET_X
						cell_size.y = int((cell_size.y + map.hexsidelength) / 2)
						if map.staggerindex == "even":
							cell_offset.y += 1
							map_pos_offset.y -= cell_size.y

	var tileset = build_tileset_for_scene(map.tilesets, source_path, options)
	if typeof(tileset) != TYPE_OBJECT:
		# Error happened
		return tileset

	var root = Node2D.new()
	root.set_name(source_path.get_file().get_basename())
	if options.save_tiled_properties:
		set_tiled_properties_as_meta(root, map)
	if options.custom_properties:
		set_custom_properties(root, map)

	var map_data = {
		"options": options,
		"map_mode": map_mode,
		"map_offset": map_offset,
		"map_pos_offset": map_pos_offset,
		"map_background": map_background,
		"cell_size": cell_size,
		"cell_offset": cell_offset,
		"tileset": tileset,
		"source_path": source_path,
		"infinite": bool(map.infinite) if "infinite" in map else false
	}

	for layer in map.layers:
		err = make_layer(layer, root, root, map_data)
		if err != OK:
			return err

	if options.add_background and "backgroundcolor" in map:
		var bg_color = str(map.backgroundcolor)
		if (!bg_color.is_valid_html_color()):
			print_error("Invalid background color format: " + bg_color)
			return root

		map_background = Color(bg_color)

		var viewport_size = Vector2(ProjectSettings.get("display/window/size/width"), ProjectSettings.get("display/window/size/height"))
		var parbg = ParallaxBackground.new()
		var parlayer = ParallaxLayer.new()
		var colorizer = ColorRect.new()

		parbg.scroll_ignore_camera_zoom = true
		parlayer.motion_mirroring = viewport_size
		colorizer.color = map_background
		colorizer.rect_size = viewport_size
		colorizer.rect_min_size = viewport_size

		parbg.name = "Background"
		root.add_child(parbg)
		parbg.owner = root
		parlayer.name = "BackgroundLayer"
		parbg.add_child(parlayer)
		parlayer.owner = root
		colorizer.name = "BackgroundColor"
		parlayer.add_child(colorizer)
		colorizer.owner = root

	return root

# Creates a layer node from the data
# Returns an error code
func make_layer(layer, parent, root, data):
	var err = DataValidator.validate_layer(layer)
	if err != OK:
		return err

	# Main map data
	var map_mode = data.map_mode
	var map_offset = data.map_offset
	var map_pos_offset = data.map_pos_offset
	var cell_size = data.cell_size
	var cell_offset = data.cell_offset
	var options = data.options
	var tileset = data.tileset
	var source_path = data.source_path
	var infinite = data.infinite

	var opacity = float(layer.opacity) if "opacity" in layer else 1.0
	var visible = bool(layer.visible) if "visible" in layer else true

	var z_index = 0

	if "properties" in layer and "z_index" in layer.properties:
		z_index = layer.properties.z_index

	if layer.type == "tilelayer":
		var layer_size = Vector2(int(layer.width), int(layer.height))
		var tilemap = TileMap.new()
		tilemap.set_name(str(layer.name))
		tilemap.cell_size = cell_size
		tilemap.modulate = Color(1.0, 1.0, 1.0, opacity);
		tilemap.visible = visible
		tilemap.mode = map_mode
		tilemap.cell_half_offset = map_offset
		tilemap.format = 1
		tilemap.cell_clip_uv = options.uv_clip
		tilemap.cell_y_sort = true
		tilemap.cell_tile_origin = TileMap.TILE_ORIGIN_BOTTOM_LEFT
		tilemap.collision_layer = options.collision_layer
		tilemap.z_index = z_index

		var offset = Vector2()
		if "offsetx" in layer:
			offset.x = int(layer.offsetx)
		if "offsety" in layer:
			offset.y = int(layer.offsety)

		tilemap.position = offset + map_pos_offset
		tilemap.tile_set = tileset

		var chunks = []

		if infinite:
			chunks = layer.chunks
		else:
			chunks = [layer]

		for chunk in chunks:
			err = DataValidator.validate_chunk(chunk)
			if err != OK:
				return err

			var chunk_data = chunk.data

			if "encoding" in layer and layer.encoding == "base64":
				if "compression" in layer:
					chunk_data = decompress_layer_data(chunk.data, layer.compression, layer_size)
					if typeof(chunk_data) == TYPE_INT:
						# Error happened
						return chunk_data
				else:
					chunk_data = read_base64_layer_data(chunk.data)

			var count = 0
			for tile_id in chunk_data:
				var int_id = int(str(tile_id)) & 0xFFFFFFFF

				if int_id == 0:
					count += 1
					continue

				var flipped_h = bool(int_id & FLIPPED_HORIZONTALLY_FLAG)
				var flipped_v = bool(int_id & FLIPPED_VERTICALLY_FLAG)
				var flipped_d = bool(int_id & FLIPPED_DIAGONALLY_FLAG)

				var gid = int_id & ~(FLIPPED_HORIZONTALLY_FLAG | FLIPPED_VERTICALLY_FLAG | FLIPPED_DIAGONALLY_FLAG)

				var cell_x = cell_offset.x + chunk.x + (count % int(chunk.width))
				var cell_y = cell_offset.y + chunk.y + int(count / chunk.width)
				tilemap.set_cell(cell_x, cell_y, gid, flipped_h, flipped_v, flipped_d)

				count += 1

		if options.save_tiled_properties:
			set_tiled_properties_as_meta(tilemap, layer)
		if options.custom_properties:
			set_custom_properties(tilemap, layer)

		tilemap.set("editor/display_folded", true)
		parent.add_child(tilemap)
		tilemap.set_owner(root)
	elif layer.type == "imagelayer":
		var image = null
		if layer.image != "":
			image = load_image(layer.image, source_path, options)
			if typeof(image) != TYPE_OBJECT:
				# Error happened
				return image

		var pos = Vector2()
		var offset = Vector2()

		if "x" in layer:
			pos.x = float(layer.x)
		if "y" in layer:
			pos.y = float(layer.y)
		if "offsetx" in layer:
			offset.x = float(layer.offsetx)
		if "offsety" in layer:
			offset.y = float(layer.offsety)

		var sprite = Sprite.new()
		sprite.set_name(str(layer.name))
		sprite.centered = false
		sprite.texture = image
		sprite.visible = visible
		sprite.modulate = Color(1.0, 1.0, 1.0, opacity)
		sprite.z_index = z_index
		if options.save_tiled_properties:
			set_tiled_properties_as_meta(sprite, layer)
		if options.custom_properties:
			set_custom_properties(sprite, layer)

		sprite.set("editor/display_folded", true)
		parent.add_child(sprite)
		sprite.position = pos + offset
		sprite.set_owner(root)
	elif layer.type == "objectgroup":
		var object_layer = Node2D.new()
		if options.save_tiled_properties:
			set_tiled_properties_as_meta(object_layer, layer)
		if options.custom_properties:
			set_custom_properties(object_layer, layer)
		object_layer.modulate = Color(1.0, 1.0, 1.0, opacity)
		object_layer.visible = visible
		object_layer.z_index = z_index
		object_layer.set("editor/display_folded", true)
		parent.add_child(object_layer)
		object_layer.set_owner(root)
		if "name" in layer and not str(layer.name).empty():
			object_layer.set_name(str(layer.name))

		if not "draworder" in layer or layer.draworder == "topdown":
			layer.objects.sort_custom(self, "object_sorter")

		for object in layer.objects:
			if "template" in object:
				var template_file = object["template"]
				var template_filename = Utils.remove_filename_from_path(data["source_path"]) + template_file
				var template_data_immutable = get_template(template_filename)
				if typeof(template_data_immutable) != TYPE_DICTIONARY:
					# Error happened
					print("Error getting template for object with id " + str(data["id"]))
					continue

				# Overwrite template data with current object data
				apply_template(object, template_data_immutable)

				set_default_obj_params(object)

			if "point" in object and object.point:
				var point = Position2D.new()
				if not "x" in object or not "y" in object:
					print_error("Missing coordinates for point in object layer.")
					continue
				point.position = Vector2(float(object.x), float(object.y))
				point.visible = bool(object.visible) if "visible" in object else true
				object_layer.add_child(point)
				point.set_owner(root)
				if "name" in object and not str(object.name).empty():
					point.set_name(str(object.name))
				elif "id" in object and not str(object.id).empty():
					point.set_name(str(object.id))
				if options.save_tiled_properties:
					set_tiled_properties_as_meta(point, object)
				if options.custom_properties:
					set_custom_properties(point, object)

			elif not "gid" in object:
				# Not a tile object
				if "type" in object and object.type == "navigation":
					# Can't make navigation objects right now
					print_error("Navigation polygons aren't supported in an object layer.")
					continue # Non-fatal error
				var shape = shape_from_object(object)

				if typeof(shape) != TYPE_OBJECT:
					# Error happened
					return shape

				if "type" in object and object.type == "occluder":
					var occluder = LightOccluder2D.new()
					var pos = Vector2()
					var rot = 0

					if "x" in object:
						pos.x = float(object.x)
					if "y" in object:
						pos.y = float(object.y)
					if "rotation" in object:
						rot = float(object.rotation)

					occluder.visible = bool(object.visible) if "visible" in object else true
					occluder.position = pos
					occluder.rotation_degrees = rot
					occluder.occluder = shape
					if "name" in object and not str(object.name).empty():
						occluder.set_name(str(object.name))
					elif "id" in object and not str(object.id).empty():
						occluder.set_name(str(object.id))

					if options.save_tiled_properties:
						set_tiled_properties_as_meta(occluder, object)
					if options.custom_properties:
						set_custom_properties(occluder, object)

					object_layer.add_child(occluder)
					occluder.set_owner(root)

				else:
					var body = Area2D.new() if object.type == "area" else StaticBody2D.new()

					var offset = Vector2()
					var collision
					var pos = Vector2()
					var rot = 0

					if not ("polygon" in object or "polyline" in object):
						# Regular shape
						collision = CollisionShape2D.new()
						collision.shape = shape
						if shape is RectangleShape2D:
							offset = shape.extents
						elif shape is CircleShape2D:
							offset = Vector2(shape.radius, shape.radius)
						elif shape is CapsuleShape2D:
							offset = Vector2(shape.radius, shape.height)
							if shape.radius > shape.height:
								var temp = shape.radius
								shape.radius = shape.height
								shape.height = temp
								collision.rotation_degrees = 90
							shape.height *= 2
						collision.position = offset
					else:
						collision = CollisionPolygon2D.new()
						var points = null
						if shape is ConcavePolygonShape2D:
							points = []
							var segments = shape.segments
							for i in range(0, segments.size()):
								if i % 2 != 0:
									continue
								points.push_back(segments[i])
							collision.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
						else:
							points = shape.points
							collision.build_mode = CollisionPolygon2D.BUILD_SOLIDS
						collision.polygon = points

					collision.one_way_collision = object.type == "one-way"

					if "x" in object:
						pos.x = float(object.x)
					if "y" in object:
						pos.y = float(object.y)
					if "rotation" in object:
						rot = float(object.rotation)

					body.set("editor/display_folded", true)
					object_layer.add_child(body)
					body.set_owner(root)
					body.add_child(collision)
					collision.set_owner(root)

					if options.save_tiled_properties:
						set_tiled_properties_as_meta(body, object)
					if options.custom_properties:
						set_custom_properties(body, object)

					if "name" in object and not str(object.name).empty():
						body.set_name(str(object.name))
					elif "id" in object and not str(object.id).empty():
						body.set_name(str(object.id))
					body.visible = bool(object.visible) if "visible" in object else true
					body.position = pos
					body.rotation_degrees = rot

			else: # "gid" in object
				var tile_raw_id = int(str(object.gid)) & 0xFFFFFFFF
				var tile_id = tile_raw_id & ~(FLIPPED_HORIZONTALLY_FLAG | FLIPPED_VERTICALLY_FLAG | FLIPPED_DIAGONALLY_FLAG)

				var is_tile_object = tileset.tile_get_region(tile_id).get_area() == 0
				var collisions = tileset.tile_get_shape_count(tile_id)
				var has_collisions = collisions > 0 && object.has("type") && object.type != "sprite"
				var sprite = Sprite.new()
				var pos = Vector2()
				var rot = 0
				var scale = Vector2(1, 1)
				sprite.texture = tileset.tile_get_texture(tile_id)
				var texture_size = sprite.texture.get_size() if sprite.texture != null else Vector2()

				if not is_tile_object:
					sprite.region_enabled = true
					sprite.region_rect = tileset.tile_get_region(tile_id)
					texture_size = tileset.tile_get_region(tile_id).size

				sprite.flip_h = bool(tile_raw_id & FLIPPED_HORIZONTALLY_FLAG)
				sprite.flip_v = bool(tile_raw_id & FLIPPED_VERTICALLY_FLAG)

				if "x" in object:
					pos.x = float(object.x)
				if "y" in object:
					pos.y = float(object.y)
				if "rotation" in object:
					rot = float(object.rotation)
				if texture_size != Vector2():
					if "width" in object and float(object.width) != texture_size.x:
						scale.x = float(object.width) / texture_size.x
					if "height" in object and float(object.height) != texture_size.y:
						scale.y = float(object.height) / texture_size.y

				var obj_root = sprite
				if has_collisions:
					match object.type:
						"area": obj_root = Area2D.new()
						"kinematic": obj_root = KinematicBody2D.new()
						"rigid": obj_root = RigidBody2D.new()
						_: obj_root = StaticBody2D.new()

					object_layer.add_child(obj_root)
					obj_root.owner = root

					obj_root.add_child(sprite)
					sprite.owner = root

					var shapes = tileset.tile_get_shapes(tile_id)
					for s in shapes:
						var collision_node = CollisionShape2D.new()
						collision_node.shape = s.shape

						collision_node.transform = s.shape_transform
						if sprite.flip_h:
							collision_node.position.x *= -1
							collision_node.position.x -= cell_size.x
							collision_node.scale.x *= -1
						if sprite.flip_v:
							collision_node.scale.y *= -1
							collision_node.position.y *= -1
							collision_node.position.y -= cell_size.y
						obj_root.add_child(collision_node)
						collision_node.owner = root

				if "name" in object and not str(object.name).empty():
					obj_root.set_name(str(object.name))
				elif "id" in object and not str(object.id).empty():
					obj_root.set_name(str(object.id))

				obj_root.position = pos
				obj_root.rotation_degrees = rot
				obj_root.visible = bool(object.visible) if "visible" in object else true
				obj_root.scale = scale
				# Translate from Tiled bottom-left position to Godot top-left
				sprite.centered = false
				sprite.region_filter_clip = options.uv_clip
				sprite.offset = Vector2(0, -texture_size.y)

				if not has_collisions:
					object_layer.add_child(sprite)
					sprite.set_owner(root)

				if options.save_tiled_properties:
					set_tiled_properties_as_meta(obj_root, object)
				if options.custom_properties:
					if options.tile_metadata:
						var tile_meta = tileset.get_meta("tile_meta")
						if typeof(tile_meta) == TYPE_DICTIONARY and tile_id in tile_meta:
							for prop in tile_meta[tile_id]:
								obj_root.set_meta(prop, tile_meta[tile_id][prop])
					set_custom_properties(obj_root, object)

	elif layer.type == "group":
		var group = Node2D.new()
		var pos = Vector2()
		if "x" in layer:
			pos.x = float(layer.x)
		if "y" in layer:
			pos.y = float(layer.y)
		group.modulate = Color(1.0, 1.0, 1.0, opacity)
		group.visible = visible
		group.position = pos
		group.z_index = z_index

		if options.save_tiled_properties:
			set_tiled_properties_as_meta(group, layer)
		if options.custom_properties:
			set_custom_properties(group, layer)

		if "name" in layer and not str(layer.name).empty():
			group.set_name(str(layer.name))

		group.set("editor/display_folded", true)
		parent.add_child(group)
		group.set_owner(root)

		for sub_layer in layer.layers:
			make_layer(sub_layer, group, root, data)

	else:
		print_error("Unknown layer type ('%s') in '%s'" % [str(layer.type), str(layer.name) if "name" in layer else "[unnamed layer]"])
		return ERR_INVALID_DATA

	return OK

func set_default_obj_params(object):
	# Set default values for object
	for attr in ["width", "height", "rotation", "x", "y"]:
		if not attr in object:
			object[attr] = 0
	if not "type" in object:
		object.type = ""
	if not "visible" in object:
		object.visible = true

var flags

	var set = read_tileset_file(source_path)
	if typeof(set) == TYPE_INT:
		return set
	if typeof(set) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA

	# Just to validate and build correctly using the existing builder
	set["firstgid"] = 0

	return build_tileset_for_scene([set], source_path, options)

# Reads a file and returns its contents as a dictionary
# Returns an error code if fails
func read_file(path):
	if path.get_extension().to_lower() == "tmx":
		var tmx_to_dict = XMLToDictionary.new()
		var data = tmx_to_dict.read_tmx(path)
		if typeof(data) != TYPE_DICTIONARY:
			# Error happened
			print_error("Error parsing map file '%s'." % [path])
		# Return error or result
		return data

	# Not TMX, must be JSON
	var file = File.new()
	var err = file.open(path, File.READ)
	if err != OK:
		return err

	var content = JSON.parse(file.get_as_text())
	if content.error != OK:
		print_error("Error parsing JSON: " + content.error_string)
		return content.error

	return content.result
	if path.get_extension().to_lower() == "tsx":
		var tmx_to_dict = XMLToDictionary.new()
		var data = tmx_to_dict.read_tsx(path)
		if typeof(data) != TYPE_DICTIONARY:
			# Error happened
			print_error("Error parsing map file '%s'." % [path])
		# Return error or result
		return data

	# Not TSX, must be JSON
	var file = File.new()
	var err = file.open(path, File.READ)
	if err != OK:
		return err

	var content = JSON.parse(file.get_as_text())
	if content.error != OK:
		print_error("Error parsing JSON: " + content.error_string)
		return content.error

	return content.result

# Creates a shape from an object data
# Returns a valid shape depending on the object type (collision/occluder/navigation)
func shape_from_object(object):
	var shape = ERR_INVALID_DATA
	set_default_obj_params(object)

	if "polygon" in object or "polyline" in object:
		var vertices = PoolVector2Array()

		if "polygon" in object:
			for point in object.polygon:
				vertices.push_back(Vector2(float(point.x), float(point.y)))
		else:
			for point in object.polyline:
				vertices.push_back(Vector2(float(point.x), float(point.y)))

		if object.type == "navigation":
			shape = NavigationPolygon.new()
			shape.vertices = vertices
			shape.add_outline(vertices)
			shape.make_polygons_from_outlines()
		elif object.type == "occluder":
			shape = OccluderPolygon2D.new()
			shape.polygon = vertices
			shape.closed = "polygon" in object
		else:
			if is_convex(vertices):
				var sorter = PolygonSorter.new()
				vertices = sorter.sort_polygon(vertices)
				shape = ConvexPolygonShape2D.new()
				shape.points = vertices
			else:
				shape = ConcavePolygonShape2D.new()
				var segments = [vertices[0]]
				for x in range(1, vertices.size()):
					segments.push_back(vertices[x])
					segments.push_back(vertices[x])
				segments.push_back(vertices[0])
				shape.segments = PoolVector2Array(segments)

	elif "ellipse" in object:
		if object.type == "navigation" or object.type == "occluder":
			print_error("Ellipse shapes are not supported as navigation or occluder. Use polygon/polyline instead.")
			return ERR_INVALID_DATA

		if not "width" in object or not "height" in object:
			print_error("Missing width or height in ellipse shape.")
			return ERR_INVALID_DATA

		var w = abs(float(object.width))
		var h = abs(float(object.height))

		if w == h:
			shape = CircleShape2D.new()
			shape.radius = w / 2.0
		else:
			# Using a capsule since it's the closest from an ellipse
			shape = CapsuleShape2D.new()
			shape.radius = w / 2.0
			shape.height = h / 2.0

	else: # Rectangle
		if not "width" in object or not "height" in object:
			print_error("Missing width or height in rectangle shape.")
			return ERR_INVALID_DATA

		var size = Vector2(float(object.width), float(object.height))

		if object.type == "navigation" or object.type == "occluder":
			# Those types only accept polygons, so make one from the rectangle
			var vertices = PoolVector2Array([
					Vector2(0, 0),
					Vector2(size.x, 0),
					size,
					Vector2(0, size.y)
			])
			if object.type == "navigation":
				shape = NavigationPolygon.new()
				shape.vertices = vertices
				shape.add_outline(vertices)
				shape.make_polygons_from_outlines()
			else:
				shape = OccluderPolygon2D.new()
				shape.polygon = vertices
		else:
			shape = RectangleShape2D.new()
			shape.extents = size / 2.0

	return shape

# Determines if the set of vertices is convex or not
# Returns a boolean
func is_convex(vertices):
	var size = vertices.size()
	if size <= 3:
		# Less than 3 verices can't be concave
		return true

	var cp = 0

	for i in range(0, size + 2):
		var p1 = vertices[(i + 0) % size]
		var p2 = vertices[(i + 1) % size]
		var p3 = vertices[(i + 2) % size]

		var prev_cp = cp
		cp = (p2.x - p1.x) * (p3.y - p2.y) - (p2.y - p1.y) * (p3.x - p2.x)
		if i > 0 and sign(cp) != sign(prev_cp):
			return false

	return true

# Decompress the data of the layer
# Compression argument is a string, either "gzip" or "zlib"
func decompress_layer_data(layer_data, compression, map_size):
	if compression != "gzip" and compression != "zlib":
		print_error("Unrecognized compression format: %s" % [compression])
		return ERR_INVALID_DATA

	var compression_type = File.COMPRESSION_DEFLATE if compression == "zlib" else File.COMPRESSION_GZIP
	var expected_size = int(map_size.x) * int(map_size.y) * 4
	var raw_data = Marshalls.base64_to_raw(layer_data).decompress(expected_size, compression_type)

	return decode_layer(raw_data)

# Reads the layer as a base64 data
# Returns an array of ints as the decoded layer would be
func read_base64_layer_data(layer_data):
	var decoded = Marshalls.base64_to_raw(layer_data)
	return decode_layer(decoded)

# Reads a PoolByteArray and returns the layer array
# Used for base64 encoded and compressed layers
func decode_layer(layer_data):
	var result = []
	for i in range(0, layer_data.size(), 4):
		var num = (layer_data[i]) | \
				(layer_data[i + 1] << 8) | \
				(layer_data[i + 2] << 16) | \
				(layer_data[i + 3] << 24)
		result.push_back(num)
	return result

# Set the custom properties into the metadata of the object
func set_custom_properties(object, tiled_object):
	if not "properties" in tiled_object:
		return

	var properties = get_custom_properties(tiled_object.properties)
	for property in properties:
		object.set_meta(property, properties[property])

# Get the custom properties as a dictionary
# Useful for tile meta, which is not stored directly
func get_custom_properties(properties):
	var result = {}

	for property in properties:
		var propertyType = property.type
		var value = null
		if propertyType == "bool":
			value = bool(property.value)
		elif propertyType == "int":
			value = int(property.value)
		elif propertyType == "float":
			value = float(property.value)
		elif propertyType == "color":
			value = Color(property.value)
		else:
			value = str(property.value)
		result[property.name] = value
	return result

# Get the available whitelisted properties from the Tiled object
# And them as metadata in the Godot object
func set_tiled_properties_as_meta(object, tiled_object):
	for property in whitelist_properties:
		if property in tiled_object:
			object.set_meta(property, tiled_object[property])

# Custom function to sort objects in an object layer
# This is done to support the "topdown" draw order, which sorts by 'y' coordinate
func object_sorter(first, second):
	if first.y == second.y:
		return first.id < second.id
	return first.y < second.y

func get_template(path):
	# If this template has not yet been loaded
	if not _loaded_templates.has(path):
		# IS XML
		if path.get_extension().to_lower() == "tx":
			var parser = XMLParser.new()
			var err = parser.open(path)
			if err != OK:
				print_error("Error opening TX file '%s'." % [path])
				return err
			var content = parse_template(parser, path)
			if typeof(content) != TYPE_DICTIONARY:
				# Error happened
				print_error("Error parsing template map file '%s'." % [path])
				return false
			_loaded_templates[path] = content

		# IS JSON
		else:
			var file = File.new()
			var err = file.open(path, File.READ)
			if err != OK:
				return err

			var json_res = JSON.parse(file.get_as_text())
			if json_res.error != OK:
				print_error("Error parsing JSON template map file '%s'." % [path])
				return json_res.error

			var result = json_res.result
			if typeof(result) != TYPE_DICTIONARY:
				print_error("Error parsing JSON template map file '%s'." % [path])
				return ERR_INVALID_DATA

			var object = result.object
			if object.has("gid"):
				if result.has("tileset"):
					var ts_path = Utils.remove_filename_from_path(path) + result.tileset.source
					var tileset_gid_increment = get_first_gid_from_tileset_path(ts_path) - 1
					object.gid += tileset_gid_increment

			_loaded_templates[path] = object

	var dict = _loaded_templates[path]
	var dictCopy = {}
	for k in dict:
		dictCopy[k] = dict[k]

	return dictCopy

func parse_template(parser, path):
	var err = OK
	# Template root node shouldn't have attributes
	var data = {}
	var tileset_gid_increment = 0
	data.id = 0

	err = parser.read()
	while err == OK:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name() == "template":
				break

		elif parser.get_node_type() == XMLParser.NODE_ELEMENT:
			if parser.get_node_name() == "tileset":
				var ts_path = Utils.remove_filename_from_path(path) + parser.get_named_attribute_value_safe("source")
				tileset_gid_increment = get_first_gid_from_tileset_path(ts_path) - 1
				data.tileset = ts_path

			if parser.get_node_name() == "object":
				var object = XMLToDictionary.parse_object(parser)
				for k in object:
					data[k] = object[k]

		err = parser.read()

	if data.has("gid"):
		data["gid"] += tileset_gid_increment

	return data

static func apply_template(object, template_immutable):
	for k in template_immutable:
		# Do not overwrite any object data
		if typeof(template_immutable[k]) == TYPE_DICTIONARY:
			if not object.has(k):
				object[k] = {}
			apply_template(object[k], template_immutable[k])

		elif not object.has(k):
			object[k] = template_immutable[k]
