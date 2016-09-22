# The MIT License (MIT)
#
# Copyright (c) 2016 George Marques
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

# http://doc.mapeditor.org/reference/tmx-map-format/#tile-flipping
const FLIPPED_HORIZONTALLY_FLAG = 0x80000000
const FLIPPED_VERTICALLY_FLAG   = 0x40000000
const FLIPPED_DIAGONALLY_FLAG   = 0x20000000

const parser_error_message = "Error parsing .tmx file"

var data = {}
var options = {}
var tilesets = []
var scene = null
var source = ""
var tile_id_mapping = {}

func init(p_source, p_options):
	source = p_source
	options = p_options

	options.name = source.basename()
	options.basedir = source.get_base_dir()

func get_data():

	if source.extension() == "json":
		var f = File.new()
		if f.open(source, File.READ) != OK:
			return "Couldn't open source file"

		var tiled_raw_data = f.get_as_text()
		f.close()

		if data.parse_json(tiled_raw_data) != OK:
			return "Couldn't parse the source file"
	else:
		data = _tmx_to_dict(source)

	return data;

func build():
	# Validate before doing anything
	if not data.has("tilesets"):
		return 'Invalid Tiled data: missing "tilesets" key.'

	if not data.has("layers"):
		return 'Invalid Tiled data: missing "layers" key.'

	if not data.has("height") or not data.has("width"):
		return 'Invalid Tiled data: missing "height" or "width" keys.'

	if not data.has("tileheight") or not data.has("tilewidth"):
		return 'Invalid Tiled data: missing "tileheight" or "tilewidth" keys.'

	var basename = options.target.substr(options.target.find_last('/'), options.target.length()).basename()

	var map_size = Vector2(int(data.width), int(data.height))
	var cell_size = Vector2(int(data.tilewidth), int(data.tileheight))
	var map_mode = TileMap.MODE_SQUARE
	if "orientation" in data:
		if data.orientation == "isometric":
			map_mode = TileMap.MODE_ISOMETRIC

	var single_tileset = null

	if options.single_tileset:
		single_tileset = TileSet.new()

	# Make tilesets
	for ts in data.tilesets:
		var tileset = null
		if options.single_tileset:
			tileset = single_tileset
		else:
			tileset = TileSet.new()

		var spacing = 0
		var margin = 0
		var firstgid = 0
		var image = ImageTexture.new()
		var image_path = ""
		var image_h = 0
		var image_w = 0
		var name = ""
		var tilesize = Vector2()
		var tilecount = 0

		if ts.has("spacing"):
			spacing = int(ts.spacing)
		if ts.has("margin"):
			margin = int(ts.margin)
		if ts.has("imageheight"):
			image_h = int(ts.imageheight)
		if ts.has("imagewidth"):
			image_w = int(ts.imagewidth)
		if ts.has("firstgid"):
			firstgid = int(ts.firstgid)
		if ts.has("name"):
			name = ts.name
		if ts.has("tilewidth") and ts.has("tileheight"):
			tilesize = Vector2(int(ts.tilewidth), int(ts.tileheight))
		else:
			return "Missing tile dimensions (%s)" % [name]
		if ts.has("tilecount"):
			tilecount = int(ts.tilecount)
		else:
			return "Missing tile count (%s)" % [name]

		if ts.has("image"):
			image_path = options.basedir.plus_file(ts.image)
			var dir = Directory.new()
			if not dir.file_exists(image_path):
				return 'Referenced image "%s" not found' % [image_path]
			image.load(image_path)
			image.set_flags(0)

			if not options.embed:
				var target_image = options.target.get_base_dir() \
								   .plus_file(options.rel_path + name + ".png")
				var err = ResourceSaver.save(target_image, image, ResourceSaver.FLAG_CHANGE_PATH)
				if err != OK:
					return "Couldn't save image for Tileset %s" % [name]
				image.take_over_path(target_image)

		if image.get_width() != image_w or image.get_height() != image_h:
			return "Image dimensions don't match (%s)" % [image_path]

		var gid = firstgid

		for y in range(margin, image_h, tilesize.y + margin + spacing):
			for x in range(margin, image_w, tilesize.x + margin + spacing):
				var tilepos = Vector2(x,y)
				var region = Rect2(tilepos, tilesize)

				tileset.create_tile(gid)
				tileset.tile_set_texture(gid, image)
				tileset.tile_set_region(gid, region)

				var rel_id = str(gid - firstgid)

				if "tiles" in ts and rel_id in ts.tiles and "objectgroup" in ts.tiles[rel_id] \
				                 and "objects" in ts.tiles[rel_id].objectgroup:
					for obj in ts.tiles[rel_id].objectgroup.objects:
						var shape = _shape_from_object(obj)

						if typeof(shape) == TYPE_STRING:
							return "Error on shape data in tileset %s:\n%s" % [name, shape]

						var offset = Vector2(int(obj.x), int(obj.y))
						offset += Vector2(int(obj.width) / 2, int(obj.height) / 2)

						if obj.type == "navigation":
							tileset.tile_set_navigation_polygon(gid, shape)
							tileset.tile_set_navigation_polygon_offset(gid, offset)
						elif obj.type == "occluder":
							tileset.tile_set_light_occluder(gid, shape)
							tileset.tile_set_occluder_offset(gid, offset)
						else:
							tileset.tile_set_shape(gid, shape)
							tileset.tile_set_shape_offset(gid, offset)

				gid += 1

		tileset.set_name(name)

		if not options.single_tileset:
			if not options.embed:
				var tileset_path = options.target.get_base_dir().plus_file(options.rel_path + name + ".res")
				var err = ResourceSaver.save(tileset_path, tileset, ResourceSaver.FLAG_CHANGE_PATH)
				if err != OK:
					return "Couldn't save TileSet %s" % [name]
				tileset.take_over_path(tileset_path)

			tilesets.push_back(tileset)

			tile_id_mapping[name] = {
				"firstgid": firstgid,
				"tilecount": tilecount,
				"tileset": tileset,
			}

	if options.single_tileset and not options.embed:
		single_tileset.set_name(basename)

		var tileset_path = options.target.get_base_dir().plus_file(options.rel_path + basename + ".res")
		var err = ResourceSaver.save(tileset_path, single_tileset, ResourceSaver.FLAG_CHANGE_PATH)
		if err != OK:
			return "Couldn't save TileSet"
		single_tileset.take_over_path(tileset_path)

	if options.single_tileset:
		tilesets = [single_tileset]

	# TileSets done, creating the target scene

	scene = Node2D.new()
	scene.set_name(basename)

	for l in data.layers:
		if l.has("compression"):
			return 'Tiled compressed format is not supported. Change your Map properties to a format without compression.'

		if not l.has("name"):
			return 'Invalid Tiled data: missing "name" key on layer.'
		var name = l.name

		if not l.has("data"):
			return 'Invalid Tiled data: missing "data" key on layer %s.' % [name]
		var layer_data = l.data

		if "encoding" in l:
			if l.encoding != "base64":
				return 'Unsupported layer data encoding. Use Base64 or no enconding.'
			layer_data = _parse_base64_layer(l.data)

		var opacity = 1.0
		var visible = true

		if l.has("opacity"):
			opacity = float(l.opacity)
		if l.has("visible"):
			visible = bool(l.visible)

		var tilemap = TileMap.new()
		tilemap.set_name(name)
		tilemap.set_cell_size(cell_size)
		tilemap.set_opacity(opacity)
		tilemap.set_hidden(not visible)
		tilemap.set_mode(map_mode)

		var offset = Vector2()
		if l.has("offsetx") and l.has("offsety"):
			offset = Vector2(int(l.offsetx), int(l.offsety))

		tilemap.set_pos(offset)

		var firstgid = 0
		tilemap.set_tileset(_tileset_from_gid(firstgid))

		var count = 0
		for tile_id in layer_data:

			var int_id = int(tile_id)

			if int_id == 0:
				count += 1
				continue

			var flipped_v = bool(int_id & FLIPPED_VERTICALLY_FLAG)
			var flipped_h = bool(int_id & FLIPPED_HORIZONTALLY_FLAG)
			var flipped_d = bool(int_id & FLIPPED_DIAGONALLY_FLAG)

			var gid = int_id & ~(FLIPPED_HORIZONTALLY_FLAG | FLIPPED_VERTICALLY_FLAG | FLIPPED_DIAGONALLY_FLAG)

			if firstgid == 0:
				firstgid = gid
				tilemap.set_tileset(_tileset_from_gid(firstgid))

			var cell_pos = Vector2(count % int(map_size.width), int(count / map_size.width))
			tilemap.set_cellv(cell_pos, gid, flipped_h, flipped_v, flipped_d)

			count += 1

		scene.add_child(tilemap)
		tilemap.set_owner(scene)

	return "OK"

func get_tilesets():
	return tilesets

func get_scene():
	return scene

# Get the tileset based on the global tile id
func _tileset_from_gid(gid):
	if options.single_tileset:
		return tilesets[0]

	for map_id in tile_id_mapping:
		var map = tile_id_mapping[map_id]
		if gid >= map.firstgid and gid < (map.firstgid + map.tilecount):
			return map.tileset

	return null

# Get a shape based on the object data
func _shape_from_object(obj):
	var shape = "No shape created. That really shouldn't happen..."

	if "polygon" in obj or "polyline" in obj:
		var vertices = Vector2Array()

		if "polygon" in obj:
			for point in obj.polygon:
				vertices.push_back(Vector2(int(point.x), int(point.y)))
		else:
			for point in obj.polyline:
				vertices.push_back(Vector2(int(point.x), int(point.y)))

		if obj.type == "navigation":
			shape = NavigationPolygon.new()
			shape.set_vertices(vertices)
		elif obj.type == "occluder":
			shape = OccluderPolygon2D.new()
			shape.set_polygon(vertices)
			shape.set_closed("polygon" in obj)
		else:
			shape = ConcavePolygonShape2D.new()
			shape.set_segments(vertices)

	elif "ellipse" in obj:
		if obj.type == "navigation" or obj.type == "occluder":
			return "Ellipse shapes are not supported as navigation or occluder. Use a polygon/polyline or a rectangle."

		var w = int(obj.width)
		var h = int(obj.height)

		if w == h:
			shape = CircleShape2D.new()
			shape.set_radius(w/2)
		else:
			shape = CapsuleShape2D.new()
			shape.set_radius(w/2)
			shape.set_height(h/2)

	else:
		# Rectangle
		var size = Vector2(int(obj.width), int(obj.height))

		if obj.type == "navigation" or obj.type == "occluder":
			var vertices = Vector2Array([
				Vector2(0, 0),
				Vector2(size.width, 0),
				size,
				Vector2(0, size.height),
			])

			if obj.type == "navigation":
				shape = NavigationPolygon.new()
				shape.set_vertices(vertices)
			else:
				shape = OccluderPolygon2D.new()
				shape.set_polygon(vertices)
		else:
			shape = RectangleShape2D.new()
			shape.set_extents(size / 2)

	return shape

func _parse_base64_layer(data):
	var decoded = Marshalls.base64_to_raw(data)

	var result = []

	for i in range(0, decoded.size(), 4):

		var num = (decoded[i]) | \
		          (decoded[i + 1] << 8) | \
		          (decoded[i + 2] << 16) | \
		          (decoded[i + 3] << 24)
		result.push_back(num)

	return result


# Read a .tmx file and build a dictionary in the same format as Tiled .json
# This helps normalizing the data and using a single builder
func _tmx_to_dict(path):

	var parser = XMLParser.new()
	var err = parser.open(path)
	if err != OK:
		return "Couldn't open .tmx file %s" % [path]

	while parser.get_node_type() != XMLParser.NODE_ELEMENT:
		err = parser.read()
		if err != OK:
			return "Error parsing .tmx file %s" % [path]

	if parser.get_node_name() != "map":
		return 'Error parsing .tmx file %s. Expected "map" element' % [path]

	var data = _attributes_to_dict(parser)
	data.tilesets = []
	data.layers = []

	err = parser.read()
	if err != OK:
		return parser_error_message

	var tileset_data = {}

	while err == OK:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name() == "map":
				break
			elif parser.get_node_name() == "tileset":
				data.tilesets.push_back(tileset_data)
				tileset_data = {}

		elif parser.get_node_type() == XMLParser.NODE_ELEMENT:
			if parser.get_node_name() == "tileset":
				tileset_data = _attributes_to_dict(parser)
				tileset_data.tiles = {}

			elif parser.get_node_name() == "image":
				var attr = _attributes_to_dict(parser)
				tileset_data.image = attr.source
				tileset_data.imagewidth = attr.width
				tileset_data.imageheight = attr.height

			elif parser.get_node_name() == "tile":
				var attr = _attributes_to_dict(parser)
				var tile_data = _parse_tile_data(parser)

				tileset_data.tiles[attr.id] = tile_data

			elif parser.get_node_name() == "layer":
				 data.layers.push_back(_parse_layer(parser))


		err = parser.read()

	return data


func _parse_tile_data(parser):
	var err = OK
	var data = {}

	if parser.is_empty():
		return data

	err = parser.read()

	var obj_group = {}

	while err == OK:

		if parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name() == "tile":
				return data
			elif parser.get_node_name() == "objectgroup":
				data.objectgroup = obj_group

		elif parser.get_node_type() == XMLParser.NODE_ELEMENT:
			if parser.get_node_name() == "objectgroup":
				obj_group = _attributes_to_dict(parser)
				for attr in ["width", "height", "offsetx", "offsety"]:
					if not attr in obj_group:
						data[attr] = 0
				if not "opacity" in data:
					data.opacity = 1
				if not "visible" in data:
					data.visible = true
				if parser.is_empty():
					data.objectgroup = obj_group
			elif parser.get_node_name() == "object":
				if not "objects" in obj_group:
					obj_group.objects = []
				var obj = _parse_object(parser)
				obj_group.objects.push_back(obj)

		err = parser.read()

	return data


func _parse_object(parser):
	var err = OK
	var data = _attributes_to_dict(parser)

	if not parser.is_empty():
		err = parser.read()
		while err == OK:

			if parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
				if parser.get_node_name() == "object":
					break

			elif parser.get_node_type() == XMLParser.NODE_ELEMENT:
				if parser.get_node_name() == "ellipse":
					data.ellipse = true
				elif parser.get_node_name() == "polygon" or parser.get_node_name() == "polyline":
					var points = []
					var points_raw = parser.get_named_attribute_value("points").split(" ")

					for pr in points_raw:
						points.push_back({
							"x": float(pr.split(",")[0]),
							"y": float(pr.split(",")[1]),
						})

					data[parser.get_node_name()] = points

			err = parser.read()

	for attr in ["width", "height", "x", "y", "rotation"]:
		if not attr in data:
			data[attr] = 0
	if not "type" in data:
		data.type = ""
	if not "visible" in data:
		data.visible = true

	return data


func _parse_layer(parser):
	var err = OK
	var data = _attributes_to_dict(parser)

	if not parser.is_empty():
		err = parser.read()

		while err == OK:
			if parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
				if parser.get_node_name() == "layer":
					break

			elif parser.get_node_type() == XMLParser.NODE_ELEMENT:
				if parser.get_node_name() == "data":
					var attr = _attributes_to_dict(parser)

					if "compression" in attr:
						data.compression = attr.compression

					if "encoding" in attr:
						parser.read()

						if attr.encoding != "csv":
							data.encoding = attr.encoding
							data.data = parser.get_node_data().strip_edges()
						else:
							var csv = parser.get_node_data().split(",", false)
							data.data = []

							for v in csv:
								data.data.push_back(int(v.strip_edges()))
					else:
						data.data = []

				elif parser.get_node_name() == "tile":
					data.data.push_back(int(parser.get_named_attribute_value("gid")))

			err = parser.read()

	return data


func _attributes_to_dict(parser):
	var data = {}
	for i in range(parser.get_attribute_count()):
		var attr = parser.get_attribute_name(i)
		var val = parser.get_attribute_value(i)
		if val.is_valid_integer():
			val = int(val)
		elif val.is_valid_float():
			val = float(val)
		elif val == "true":
			val = true
		elif val == "false":
			val = false
		data[attr] = val
	return data
