tool
extends Reference

var data = {}
var options = {}
var tilesets = []
var scene = null
var source = ""

func init(p_source, p_options):
	source = p_source
	options = p_options

	options.name = source.basename()
	options.basedir = source.get_base_dir()

func get_data():
	var f = File.new()
	if f.open(source, File.READ) != OK:
		return "Couldn't open source file"

	var tiled_raw_data = f.get_as_text()
	f.close()

	if data.parse_json(tiled_raw_data) != OK:
		return "Couldn't parse the source file"

	print("data 1 ", data.height)

	return data;

func build():
	print("data 2 ", data.height)
	# Validate before doing anything
	if not data.has("tilesets"):
		return 'Invalid Tiled data: missing "tilesets" key.'

	var scn = Node2D.new()
	scn.set_name(options.name)

	# Make tilesets
	for ts in data.tilesets:
		var tileset = TileSet.new()

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

				gid += 1

		tileset.set_name(name)
		tilesets.push_back(tileset)

	return "OK"

func get_tilesets():
	return tilesets

func get_scene():
	return scene
