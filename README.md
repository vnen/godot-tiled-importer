# Tiled Map Importer

This is a plugin for [Godot Engine](https://godotengine.org) to import
`TileMap`s and `TileSet`s from the [Tiled Map Editor](http://www.mapeditor.org).

## Installation

Download or clone this repository and copy the contents of the `addons` folder
to your own project's `addons` folder. Then enable the plugin on the Project
Settings.

## Usage

1. In Godot, click on menu Import -> TileMap from Tiled Editor.
2. Set the source Tiled file (either a `.json` or a `.tmx`).
3. Set the target destination scene.
4. Ajusted the desired options.
5. Press ok.

If no error occurs, the generated scene will be stored where you set it. The
TileSets will be on a relative folder or embedded, depending on the options.

## Options

### Single TileSet

Save all Tiled tilesets a single Godot resource. If any of your layers uses
more than one tileset image, this is required otherwise it won't be generated
properly.

### Embed resources

Save all TileSets and images embedded in the target scene. Otherwise they will
be saved individually in the selected relative folder.

### Relative resource path

The relative path from the target scene where to save the resources
(images and tilesets).

## License

[MIT License](LICENSE). Copyright (c) 2016 George Marques.
