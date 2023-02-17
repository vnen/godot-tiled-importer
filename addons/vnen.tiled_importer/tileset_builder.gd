# The MIT License (MIT)
#
# Copyright (c) 2023 George Marques
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
# XML Format reader
const XMLToDictionary = preload("xml_to_dict.gd")

# Polygon vertices sorter
const PolygonSorter = preload("polygon_sorter.gd")

# Prefix for error messages, make easier to identify the source
const error_prefix = "Tiled Importer: "

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

# Makes a standalone TileSet. Useful for importing TileSets from Tiled
# Returns an error code if fails
func build(source_path, options):
	var tileset = load_tileset_file(source_path)

	return build_tileset_for_scene([tileset], source_path, options)

# Collects all the required data from a tileset file
# Such that it can be provided to the builder, individually or as a set
func load_tileset_file(source_path):
	var tileset = read_file(source_path)
	if typeof(tileset) == TYPE_INT:
		return tileset
	if typeof(tileset) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA

	# Just to validate and build correctly using the existing builder
	if not "firstgid" in tileset:
		tileset["firstgid"] = 0

	return tileset

# When loading a tileset from a tilemap
# The map will store only the firstgid and the source file
# This function resolves the inner data to be updated accordingly
func _resolve_tileset_source(tileset, source_path):
	if not "source" in tileset:
		print_error("Missing or invalid source tileset property.")
		return ERR_INVALID_DATA

	if not "firstgid" in tileset or not str(tileset.firstgid).is_valid_integer():
		print_error("Missing or invalid firstgid tileset property.")
		return ERR_INVALID_DATA

	var output = {}

	var new_source_path = source_path.get_base_dir().plus_file(tileset.source)
	# Used later for templates
	_tileset_path_to_first_gid[new_source_path] = tileset.firstgid

	output = load_tileset_file(new_source_path)

	output.firstgid = tileset.firstgid

	return output

# Makes a tileset from a array of tilesets data
# Since Godot supports only one TileSet per TileMap, all tilesets from Tiled are combined
func build_tileset_for_scene(tilesets, source_path, options):
	var result = TileSet.new()
	var err = ERR_INVALID_DATA
	var tile_meta = {}

	for tileset in tilesets:
		var ts = tileset
		var ts_source_path = source_path

		#resolve source reference
		if "source" in ts:
			ts = _resolve_tileset_source(ts, source_path)

		err = DataValidator.validate_tileset(ts)
		if err != OK:
			return err

		var has_global_image = "image" in ts

		var spacing = int(ts.spacing) if "spacing" in ts and str(ts.spacing).is_valid_integer() else 0
		var margin = int(ts.margin) if "margin" in ts and str(ts.margin).is_valid_integer() else 0
		var firstgid = int(ts.firstgid)
		var columns = int(ts.columns) if "columns" in ts and str(ts.columns).is_valid_integer() else -1

		var image = null
		var imagesize = Vector2()

		if has_global_image:
			image = load_image(ts.image, ts_source_path, options)
			if typeof(image) != TYPE_OBJECT:
				# Error happened
				return image
			imagesize = Vector2(int(ts.imagewidth), int(ts.imageheight))

		var tilesize = Vector2(int(ts.tilewidth), int(ts.tileheight))
		var tilecount = int(ts.tilecount)

		var gid = firstgid

		var x = margin
		var y = margin

		var i = 0
		var column = 0

		# Needed to look up textures for animations
		var tileRegions = []
		while i < tilecount:
			var tilepos = Vector2(x, y)
			var region = Rect2(tilepos, tilesize)

			tileRegions.push_back(region)

			column += 1
			i += 1

			x += int(tilesize.x) + spacing
			if (columns > 0 and column >= columns) or x >= int(imagesize.x) - margin or (x + int(tilesize.x)) > int(imagesize.x):
				x = margin
				y += int(tilesize.y) + spacing
				column = 0

		i = 0

		while i < tilecount:
			var region = tileRegions[i]

			var rel_id = str(gid - firstgid)

			result.create_tile(gid)

			if has_global_image:
				if "tiles" in ts && rel_id in ts.tiles && "animation" in ts.tiles[rel_id]:
					var animated_tex = AnimatedTexture.new()
					animated_tex.frames = ts.tiles[rel_id].animation.size()
					animated_tex.fps = 0
					var c = 0
					# Animated texture wants us to have seperate textures for each frame
					# so we have to pull them out of the tileset
					var tilesetTexture = image.get_data()
					for g in ts.tiles[rel_id].animation:
						var frameTex = tilesetTexture.get_rect(tileRegions[(int(g.tileid))])
						var newTex = ImageTexture.new()
						newTex.create_from_image(frameTex, flags)
						animated_tex.set_frame_texture(c, newTex)
						animated_tex.set_frame_delay(c, float(g.duration) * 0.001)
						c += 1
					result.tile_set_texture(gid, animated_tex)
					result.tile_set_region(gid, Rect2(Vector2(0, 0), tilesize))
				else:
					result.tile_set_texture(gid, image)
					result.tile_set_region(gid, region)
				if options.apply_offset:
					result.tile_set_texture_offset(gid, Vector2(0, -tilesize.y))
			elif not rel_id in ts.tiles:
				gid += 1
				continue
			else:
				if rel_id in ts.tiles && "animation" in ts.tiles[rel_id]:
					var animated_tex = AnimatedTexture.new()
					animated_tex.frames = ts.tiles[rel_id].animation.size()
					animated_tex.fps = 0
					var c = 0
					#untested
					var image_path = ts.tiles[rel_id].image
					for g in ts.tiles[rel_id].animation:
						animated_tex.set_frame_texture(c, load_image(image_path, ts_source_path, options))
						animated_tex.set_frame_delay(c, float(g.duration) * 0.001)
						c += 1
					result.tile_set_texture(gid, animated_tex)
					result.tile_set_region(gid, Rect2(Vector2(0, 0), tilesize))
				else:
					var image_path = ts.tiles[rel_id].image
					image = load_image(image_path, ts_source_path, options)
					if typeof(image) != TYPE_OBJECT:
						# Error happened
						return image
					result.tile_set_texture(gid, image)
				if options.apply_offset:
					result.tile_set_texture_offset(gid, Vector2(0, -image.get_height()))

			if "tiles" in ts:
				var has_tile = false
				var found_id = 0
				for tile_i in range(0, ts.tiles.size()):
					var tile = ts.tiles[tile_i]
					if str(tile.id) == rel_id:
						found_id = tile_i
						has_tile = true

				if has_tile and "objectgroup" in ts.tiles[found_id] and "objects" in ts.tiles[found_id].objectgroup:
					for object in ts.tiles[found_id].objectgroup.objects:

						var shape = shape_from_object(object)

						if typeof(shape) != TYPE_OBJECT:
							# Error happened
							return shape

						var offset = Vector2(float(object.x), float(object.y))
						if "width" in object and "height" in object:
							offset += Vector2(float(object.width) / 2, float(object.height) / 2)

						if object.type == "navigation":
							result.tile_set_navigation_polygon(gid, shape)
							result.tile_set_navigation_polygon_offset(gid, offset)
						elif object.type == "occluder":
							result.tile_set_light_occluder(gid, shape)
							result.tile_set_occluder_offset(gid, offset)
						else:
							result.tile_add_shape(gid, shape, Transform2D(0, offset), object.type == "one-way")

			if "properties" in ts and "custom_material" in ts.properties:
				result.tile_set_material(gid, load(ts.properties.custom_material))

			if options.custom_properties and options.tile_metadata and "tileproperties" in ts \
					and "tilepropertytypes" in ts and rel_id in ts.tileproperties and rel_id in ts.tilepropertytypes:
				tile_meta[gid] = get_custom_properties(ts.tileproperties[rel_id])
			if options.save_tiled_properties and rel_id in ts.tiles:
				for property in whitelist_properties:
					if property in ts.tiles[rel_id]:
						if not gid in tile_meta: tile_meta[gid] = {}
						tile_meta[gid][property] = ts.tiles[rel_id][property]

					# If tile has a custom property called 'name', set the tile's name
					if property == "name":
						result.tile_set_name(gid, ts.tiles[rel_id].properties.name)


			gid += 1
			i += 1

		if str(ts.name) != "":
			result.resource_name = str(ts.name)

		if options.save_tiled_properties:
			set_tiled_properties_as_meta(result, ts)
		if options.custom_properties:
			if "properties" in ts and "propertytypes" in ts:
				set_custom_properties(result, ts)

	if options.custom_properties and options.tile_metadata:
		result.set_meta("tile_meta", tile_meta)

	return result

# Loads an image from a given path
# Returns a Texture
func load_image(rel_path, source_path, options):
	flags = options.image_flags if "image_flags" in options else Texture.FLAGS_DEFAULT
	var embed = options.embed_internal_images if "embed_internal_images" in options else false

	var ext = rel_path.get_extension().to_lower()
	if ext != "png" and ext != "jpg":
		print_error("Unsupported image format: %s. Use PNG or JPG instead." % [ext])
		return ERR_FILE_UNRECOGNIZED

	var total_path = rel_path
	if rel_path.is_rel_path():
		total_path = ProjectSettings.globalize_path(source_path.get_base_dir()).plus_file(rel_path)
	total_path = ProjectSettings.localize_path(total_path)

	var dir = Directory.new()
	if not dir.file_exists(total_path):
		print_error("Image not found: %s" % [total_path])
		return ERR_FILE_NOT_FOUND

	if not total_path.begins_with("res://"):
		# External images need to be embedded
		embed = true

	var image = null
	if embed:
		image = ImageTexture.new()
		image.load(total_path)
	else:
		image = ResourceLoader.load(total_path, "ImageTexture")

	if image != null:
		image.set_flags(flags)

	return image

# Reads a tileset file and return its contents as a dictionary
# Returns an error code if fails
func read_file(path):
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

# Custom function to print error, to centralize the prefix addition
func print_error(err):
	printerr(error_prefix + err)

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
					var ts_path = remove_filename_from_path(path) + result.tileset.source
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
				var ts_path = remove_filename_from_path(path) + parser.get_named_attribute_value_safe("source")
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

func get_first_gid_from_tileset_path(path):
	for t in _tileset_path_to_first_gid:
		if is_same_file(path, t):
			return _tileset_path_to_first_gid[t]

	return 0

static func get_filename_from_path(path):
	var substrings = path.split("/", false)
	var file_name = substrings[substrings.size() - 1]
	return file_name

static func remove_filename_from_path(path):
	var file_name = get_filename_from_path(path)
	var stringSize = path.length() - file_name.length()
	var file_path = path.substr(0,stringSize)
	return file_path

static func is_same_file(path1, path2):
	var file1 = File.new()
	var err = file1.open(path1, File.READ)
	if err != OK:
		return err

	var file2 = File.new()
	err = file2.open(path2, File.READ)
	if err != OK:
		return err

	var file1_str = file1.get_as_text()
	var file2_str = file2.get_as_text()

	if file1_str == file2_str:
		return true

	return false

static func apply_template(object, template_immutable):
	for k in template_immutable:
		# Do not overwrite any object data
		if typeof(template_immutable[k]) == TYPE_DICTIONARY:
			if not object.has(k):
				object[k] = {}
			apply_template(object[k], template_immutable[k])

		elif not object.has(k):
			object[k] = template_immutable[k]
