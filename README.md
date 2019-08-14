# Skin Database

A minetest skin mod that uses the skins resources located at http://minetest.fensta.bplaced.net/ to offer:

* access over 1000 skins in the db
* assign moderator and admin flags
* assign personal skins to specific players
* supports Unified Inventory
* supports Inventory Plus
* supports 3D Armor

## How to use

To activate a skin double click it, after selecting a skin in the active list you have the options to remove it by double clicking, set moderator or admin flags and assign the skin to a specific player by typing their name in the field and clicking the private checkbox.

## INSTALLATION

skin_db requires lsqlite3 (https://github.com/LuaDist/lsqlite3).

If you have luarocks (https://luarocks.org/) installed on the target server,
you can easily install lsqlite3 in a terminal:

    luarocks install lsqlite3

If the target server runs mods in secure mode(recommended), you must add skin_db
to the list of trusted mods in minetest.conf:

    secure.trusted_mods = skin_db

then move the skin_db.sqlite file into the world folder.  
Also see https://wiki.minetest.net/Installing_Mods for more information.

## Adding skins

You need 3 files before you can import a skin.
```
character_<number>.png -- 64 x 32 skin image
character_<number>_preview.png -- 16 x 32 preview image
character_<number>.txt -- name, author, license on seperate lines
```
The .png files are placed in the textures folder and the txt file in the meta folder, use the admin GUI import button. New skins appear in the inactive list and can be used immediately by adding them to the active list.
  
Texture Info: All textures retain original licensing which can be found in the respective meta file.
