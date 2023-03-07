extends Node

const error_prefix = "Utils: "

# Custom function to print error, to centralize the prefix addition
static func print_error(err):
	printerr(error_prefix + err)

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

# Loads an image from a given path
# Returns a Texture
static func load_image(rel_path, source_path, options):
	var flags = options.image_flags if "image_flags" in options else Texture.FLAGS_DEFAULT
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
