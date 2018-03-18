-- Skin mod for minetest voxel game
-- by shivajiva101@hotmail.com

-- Expose API
skin_db = {}
skin_db.active = {}
skin_db.inactive = {}
skin_db.skin = {}

minetest.register_privilege("moderator_skins", "Moderator skins access")

local ie = minetest.request_insecure_environment()

if not ie then
	error("insecure environment inaccessible"..
		" - make sure this mod has been added to minetest.conf!")
end

-- Requires library for db access
local _sql = ie.require("lsqlite3")
-- secure global
if sqlite3 then sqlite3 = nil end

local S = {
	WP = minetest.get_worldpath(),
	MP = minetest.get_modpath(minetest.get_current_modname()),
	invplus = minetest.get_modpath("inventory_plus"),
	sfinv = minetest.get_modpath("sfinv"),
	ui = minetest.get_modpath("unified_inventory"),
	armor = minetest.get_modpath("3d_armor")
}

local db = _sql.open(S.WP.."/skin_db.sqlite") -- connection


local function getos()
	-- is popen supported?
	local popen_status, popen_result = pcall(ie.io.popen, "")
	if popen_status then
		popen_result:close()
		-- Unix-based OS
		return "linux"
	else
		-- Windows
		local env_OS = os.getenv('OS')
		if env_OS then
			return "windows"
		end
	end
	return "unknown"
end


-- Create db:exec wrapper for error reporting

local function db_exec(stmt)
	if db:exec(stmt) ~= _sql.OK then
		minetest.log("info", "Sqlite ERROR:  ", db:errmsg())
	end
end


--[[
################
### Database ###
################
]]


local create_db = [[
CREATE TABLE IF NOT EXISTS player (id INTEGER PRIMARY KEY AUTOINCREMENT,
name VARCHAR(32), skin_id INTEGER);
CREATE TABLE IF NOT EXISTS skins (id INTEGER PRIMARY KEY AUTOINCREMENT,
filename VARCHAR(32), name VARCHAR(32), author VARCHAR(32), license VARCHAR(12),
moderator BOOLEAN, admin BOOLEAN, private BOOLEAN, player VARCHAR(32),
active BOOLEAN);
]]
db_exec(create_db)


-- Queries

local function get_player_record(name)
	local query = ([[
	    SELECT * FROM player WHERE name = '%s' LIMIT 1;
	]]):format(name)
	for row in db:nrows(query) do
		return row
	end
end

local function get_skin(id)
	local query = ([[
	    SELECT * FROM skins WHERE id = '%i' LIMIT 1;
	]]):format(id)
	for row in db:nrows(query) do
		return row
	end
end

local function get_active()
	local r = {}
	local query = [[
	    SELECT * FROM skins WHERE active = 'true';
	]]
	for row in db:nrows(query) do
		r[#r+1] = row
	end
	skin_db.active = r
end
get_active()

local function get_inactive()
	local r = {}
	local query = [[
	    SELECT * FROM skins WHERE active = 'false';
	]]
	for row in db:nrows(query) do
		r[#r+1] = row
	end
	skin_db.inactive = r
end

local function get_skin_id(name)
	local query = ([[
	    SELECT id FROM skins WHERE name = '%s';
	]]):format(name)
	for row in db:nrows(query) do
		return row.id
	end
end

local function check_skins(filename)
	local query = ([[
	    SELECT *
		FROM skins
		WHERE filename = '%s' LIMIT 1;
	]]):format(filename)
	for row in db:nrows(query) do
		return row
	end
end

-- Inserts
local function create_player_record(name, skin_id)
	local stmt = ([[
		INSERT INTO player (
			name,
			skin_id
		) VALUES ('%s','%i');]]):format(name, skin_id)
	db_exec(stmt)
end

local function create_skin_record(filename, name, author, license, mod, admin, private, player, active)
	mod = mod or false
	admin = admin or false
	private = private or false
	player = player or ""
	active = active or false
	local stmt = ([[
		INSERT INTO skins (
		filename,
		name,
		author,
		license,
		moderator,
		admin,
		private,
		player,
		active
	) VALUES ('%s','%s','%s','%s','%s','%s','%s','%s','%s');
		]]):format(filename, name, author, license, mod, admin, private, player, active)
	db_exec(stmt)
end

-- Updates
local function update_player_record(name, skin_id)
	local stmt = ([[
		UPDATE player SET skin_id = '%i' WHERE name = '%s';
	]]):format(skin_id, name)
	db_exec(stmt)
end

local function update_skin_active(skin_id, status)
	local stmt = ([[
		UPDATE skins SET active = '%s' WHERE id = '%i';
	]]):format(status, skin_id)
	db_exec(stmt)
end

local function update_skin_record(data)
	local stmt = ([[
		UPDATE skins
		SET moderator = '%s',
		admin = '%s',
		private = '%s',
		player = '%s'
		WHERE id = '%i';
	]]):format(data.moderator, data.admin, data.private, data.player, data.id)
	db_exec(stmt)
end

--[[
#################
##  Formspecs  ##
#################
]]

local state = {}

local function get_context(name)
	local tbl = state[name]

	if not tbl then -- initialise?
		tbl = {
			event = "",
			page = 1, -- admin gui inactive
			max = 1,
			i = 1, -- active list index
			o = -1, -- inactive list index
			id = 1,
			list = {},
			preview = 1
		}
		state[name] = tbl
	end
	return tbl
end

-- Selection
skin_db.formspec = {}

skin_db.formspec.main = function(name)

	local formspec = ""
	local playerdata = get_player_record(name)
	local privs = minetest.get_player_privs(name)
	local context = get_context(name)
	local meta

	if S.invplus then
		formspec = "size[8,8.6]"
		..default.gui_bg
		..default.gui_bg_img
		.."button[6,0.1;2,0.5;main;Back]"
	end

	if privs.server then
		-- Show manage button
		formspec = formspec .. "button[6,1.9;1.5,0.5;admin;Admin]"
	end
	formspec = formspec .. "button[6,2.8;1.5,0.5;wear;Select]"

	context.list = {}
	-- filter active skins
	for i = 1, #skin_db.active do
		local record = skin_db.active[i]
		if privs.server then -- owner
			table.insert(context.list, record)
		elseif privs.moderator_skins
		and record.moderator == "true"
		and record.private == "false" then -- hub mod
			table.insert(context.list, record)
		elseif record.private == name then -- private
			table.insert(context.list, record)
		elseif record.admin == "false"
		and record.moderator == "false"
		and record.private == "false" then -- player
			table.insert(context.list, record)
		end
	end

	-- apply filtered skins
	formspec = formspec.. "textlist[0.5,4.5;6.8,4;sel;"

	for i,v in ipairs(context.list) do
		formspec = formspec .. v.name..","
		-- set metadata for correct index
		if i == context.preview then
			meta = {
				name = v.name,
				author = v.author,
				license = v.license
			}
		end
	end
	
	-- Remove unwanted final comma
	formspec = formspec:sub(1, (formspec:len() - 1))
	formspec = formspec..";"..context.preview..";true]"

	if meta then
		if meta.name then
			formspec = formspec.."label[0.5,0.5;Name: "..meta.name.."]"
		end
		if meta.author then
			formspec = formspec.."label[0.5,1;Author: ".. meta.author.."]"
		end
		if meta.license then
			formspec = formspec.."label[0.5,1.5;License:]"..
			"label[0.5,2;"..meta.license.."]"
		end
	end

	local preview = context.list[context.preview].filename:gsub(".png", "_preview.png")
	formspec = formspec.."image[4,0.4;2,4.5;"..preview.."]"

	return formspec
end

-- Management
skin_db.formspec.admin = function(name)

	local formspec
	local context = get_context(name)
	local bgimg = ""
	local privs = minetest.get_player_privs(name)

	if not privs.server then return "" end
	if default and default.gui_bg_img then
		bgimg = default.gui_bg_img
	end

	get_inactive()

	formspec = "size[12,8.4]"
	.. default.gui_bg
	.. bgimg -- comment out if you want bg to be transparent
		.."textlist[0.5,0.5;4,7.6;skin_db:out;" -- inactive list

	if #skin_db.inactive > 0 then -- content?
		-- calculate pages
		local min,max,pmax
		pmax = math.floor(#skin_db.inactive / 100)
		-- add a page?
		if pmax * 100 < #skin_db.inactive then pmax = pmax+1 end
		-- store page count
		context.max = pmax
		-- initialise the limits for the current page
		if context.page == 1 then
			min = 1
			max = 100
		else
			min = context.page * 100 - 99
			if context.page ~= pmax then
				max = min + 99
			else
				local leftover = #skin_db.inactive - ((pmax - 1)*100)
				max = min + leftover - 1
			end
		end
		-- add names
		for i = min, max do
			formspec = formspec..skin_db.inactive[i].name..","
		end
		formspec = formspec:sub(1, (formspec:len() - 1))
		formspec = formspec..";".. context.o .."]"
	else
		formspec = formspec.."]"
	end

	formspec = formspec.."textlist[7.3,0.5;4,7.6;skin_db:in;"
	for _,val in ipairs(skin_db.active) do
		formspec = formspec..val.name..","
	end
	formspec = formspec:sub(1, (formspec:len() - 1))
	formspec = formspec..";".. context.i .."]"

	-- handle preview selection
	local skin
	local img

	if context.event == "active" then
		if context.i > 0 then -- index?
			skin = skin_db.active[context.i] -- get skin data
			img = skin.filename:gsub(".png", "_preview.png") -- get filename
		else
			-- initialise the settings we need
			skin = {
				moderator = 'false',
				admin = 'false',
				private = 'false',
				player = ''
			}
		end
	elseif context.event == "inactive" then
		skin = {
			moderator = 'false',
			admin = 'false',
			private = 'false',
			player = ''
		}
		img = skin_db.inactive[context.id].filename:gsub(".png", "_preview.png")
	end

	formspec = formspec
	.."label[0.5,0;Available Skins:]"
	.."image_button[3,0;0.5,0.5;skin_db_left_icon.png;left;]"
	.."image_button[4,0;0.5,0.5;skin_db_right_icon.png;right;]"
	.."label[7.3,0;Loaded Skins:]"
	.."image[5.1,0.2;2,4.5;"..img.."]"
	.."button[4.9,4.5;2.2,0.5;upd;Importer]"
	.."checkbox[4.9,5;mod;Moderator;"..skin.moderator.."]"
	.."checkbox[4.9,5.5;admin;Admin;"..skin.admin.."]"
	.."checkbox[4.9,6;private;Private;"..skin.private.."]"
	.."field[5.2,7.2;2.2,0.5;player;;"..skin.player.."]"
	.."tooltip[player;Player assigned to private skin."
	.."\nAdd player name before selecting\nthe Private checkbox. Unchecking"
	.."\nwill reset this record!]"
	.."tooltip[mod;Moderator only skin]"
	.."tooltip[admin;Admin only skin]"
	.."tooltip[private;Players personal skin]"
	.."tooltip[skin_db:in;Active skins]"
	.."tooltip[skin_db:out;Inactive skins]"
	.."tooltip[upd;Search textures/meta folders for new skins]"

	if context.page > 9 then -- displacement for 2 digits?
		formspec = formspec.."label[3.49,0;"..context.page.."]"
	else
		formspec = formspec.."label[3.55,0;"..context.page.."]"
	end
	return formspec
end

-- Update player skin
local function update_player_skin(player)

	if not player then return end
	local name = player:get_player_name()
	local file_name = skin_db.skin[name].filename

	-- 3d_armor mod?
	if S.armor then
		armor.textures[name].skin = file_name
		armor:set_player_armor(player)
	else
		-- Set player texture
		player:set_properties({textures = {file_name},})
	end
end

--[[
###################
##  Inventories  ##
###################
]]

-- register sfinv tab when inv+ not active
if S.ui then
	unified_inventory.register_button("skins", {
		type = "image",
		image = "skin_db_button.png",
		tooltip = "Player Skins",
	})
	unified_inventory.register_page("skins", {
		get_formspec = function(player)
			return {
				formspec=skin_db.formspec.main(player:get_player_name()),
				draw_inventory=false
			}
		end,
	})
elseif S.sfinv and not S.invplus then

	sfinv.register_page("skin_db:skin", {
		title = "Skins",
		get = function(self, player, context)
			local name = player:get_player_name()
			return sfinv.make_formspec(player, context,skin_db.formspec.main(name))
		end,
		on_player_receive_fields = function(self, player, context, fields)
			local name = player:get_player_name()
			local event = minetest.explode_textlist_event(fields["skins_set"])

			if event.type == "CHG" then
				local index = event.index

				--if index > id then index = id end
				skin_db.skin[name] = skin_db.active[index]
				skin_db.update_player_skin(player)
				update_player_record(name, index)

				sfinv.override_page("skin_db:main", {
					get = function(self, player, context)
						local name = player:get_player_name()
						return sfinv.make_formspec(player, context,
								skin_db.formspec.main(name))
					end,
				})

				sfinv.set_player_inventory_formspec(player)
			end
		end,
	})
end


--[[
#################
##  Callbacks  ##
#################
]]


-- formspecs

minetest.register_on_player_receive_fields(function(player, formname, fields)

	if formname ~= "skin_db:main" and
	formname ~= "skin_db:admin" and
	formname ~= "" then return end

	local name = player:get_player_name()
	local context = get_context(name)

	if S.invplus then
		if fields.skin then
			-- show formspec
			local f = skin_db.formspec.main(name)
			inventory_plus.set_inventory_formspec(player, f)
			return
		end
	end

	if formname == "skin_db:admin" then

		local ev_out = minetest.explode_textlist_event(fields["skin_db:out"])
		local ev_in = minetest.explode_textlist_event(fields["skin_db:in"])

		if ev_out.type == "CHG" then
			context.o = ev_out.index
			context.i = -1
			context.event = "inactive"
			if context.page > 1 then
				context.id = context.o + (context.page * 100) - 100
			else
				context.id = context.o
			end
			-- update preview
			minetest.show_formspec(name, "skin_db:admin",
			skin_db.formspec.admin(name))
		end

		if ev_out.type == "DCL" then
			-- make skin active
			update_skin_active(skin_db.inactive[context.id].id, 'true')
			get_inactive()
			get_active()
			minetest.show_formspec(name, "skin_db:admin",
			skin_db.formspec.admin(name))
			if S.ui then
				unified_inventory.set_inventory_formspec(player, "craft")
			end
		end

		if ev_in.type == "CHG" then
			context.o = -1
			context.i = ev_in.index
			context.event = "active"
			-- update preview
			minetest.show_formspec(name, "skin_db:admin",
			skin_db.formspec.admin(name))
		end

		if ev_in.type == "DCL" then
			-- make skin as inactive
			update_skin_active(skin_db.active[context.i].id, 'false')
			context.i = 1
			context.event = "active"
			get_inactive()
			get_active()
			minetest.show_formspec(name, "skin_db:admin",
			skin_db.formspec.admin(name))
			if S.ui then
				unified_inventory.set_inventory_formspec(player, "craft")
			end
		end

		if fields.upd then
			bdb()
			get_active()
			get_active()
			-- update preview
			minetest.show_formspec(name, "skin_db:admin",
			skin_db.formspec.admin(name))
		end

		if fields.mod then
			skin_db.active[context.i].moderator = fields.mod
			update_skin_record(skin_db.active[context.i])
			-- update form
			minetest.show_formspec(name, "skin_db:admin",
			skin_db.formspec.admin(name))
		end

		if fields.admin then
			skin_db.active[context.i].admin = fields.admin
			update_skin_record(skin_db.active[context.i])
			-- update form
			minetest.show_formspec(name, "skin_db:admin",
			skin_db.formspec.admin(name))
		end

		if fields.private then
			local pname = fields.player
			if context.event == "active" then
				local update = false
				if skin_db.active[context.i].private == "true" and
				fields.private == "false" then
					pname = ""
					update = true
				elseif  skin_db.active[context.i].private == "false" and
				pname ~= "" and fields.private == "true" then
					update = true
				else -- not allowed
					-- switch and force update
					context.event = "inactive"
					context.i = -1
					context.o = 1
				end
				if update then
					skin_db.active[context.i].player = pname
					skin_db.active[context.i].private = fields.private
					update_skin_record(skin_db.active[context.i])
				end
			elseif context.event == "inactive" then
				-- switch and force update
				context.event = "active"
				context.i = 1
				context.o = -1
			end

			-- update form
			minetest.show_formspec(name, "skin_db:admin",
			skin_db.formspec.admin(name))
			return
		end

		if fields.right then
			if context.page < context.max then
				context.page = context.page + 1
				context.o = 1
				minetest.show_formspec(name, "skin_db:admin",
				skin_db.formspec.admin(name))
			end
		end

		if fields.left then
			if context.page ~= 1 then
				context.page = context.page - 1
				context.o = 1
				minetest.show_formspec(name, "skin_db:admin",
				skin_db.formspec.admin(name))
			end
		end

		if fields.quit == "true" then
			skin_db.inactive = nil
		end

		return
	end

	-- from this point we handle 2 formspec names "" & skin_db:main
	if formname == "" or formname == "skin_db:main" then
		if fields.admin then
			-- Initialise our context
			context.o = -1 -- no selection
			context.i = 1 -- first entry
			context.event = "active"
			-- show admin form
			minetest.show_formspec(name, "skin_db:admin",
			skin_db.formspec.admin(name))
			return
		end

		local e = minetest.explode_textlist_event(fields["sel"])

		if e.type == "CHG" then

			context.preview = e.index --save state

			if S.invplus then
				inventory_plus.set_inventory_formspec(player,
				skin_db.formspec.main(name))
			elseif S.ui then
				-- update
				unified_inventory.set_inventory_formspec(player, "skins")
			end
		end

		if fields.wear then
			-- change the players skin and save the data
			skin_db.skin[name] = context.list[context.preview] -- update cache
			update_player_skin(player) -- change player skin
			update_player_record(name, context.list[context.preview].id) -- update record
			if S.ui then
				-- update form
				unified_inventory.set_inventory_formspec(player, "skins")
			end
		end
	end
end)

-- Initialise player
minetest.register_on_joinplayer(function(player)

	local name = player:get_player_name()
	local playerdata = get_player_record(name)

	if playerdata then -- record?
		-- cache
		skin_db.skin[name] = get_skin(playerdata.skin_id)
	else -- initialise default skin
		create_player_record(name, 1)
		skin_db.skin[name] = get_skin(1)
	end

	update_player_skin(player)

	if S.invplus then
		inventory_plus.register_button(player,"skin", "Skins")
	end
end)

minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	state[name] = nil
	skin_db.skin[name] = nil
end)

local function bdb()

	local tdir = S.MP.."/textures"
	local mdir = S.MP.."/meta"
	local p = ie.io.popen('ls -1v '..tdir)
	local mfn = ""

	for file in p:lines() do
		if file:find(".png") and
		not file:find("_preview") and
		not file:find("skin_db") then
			local result = check_skins(file) -- prevent duplication
			if not result then
				mfn = file:gsub(".png", ".txt")
				local f = ie.io.open(mdir.."/"..mfn, "r")
				if f then
					local cont = {}
					for line in f:lines() do
						cont[#cont+1] = line
					end
					f:close()
					local name = cont[1]
					local author = cont[2]
					local license = cont[3]
					name = name:gsub("%(", " ")
					name = name:gsub("%)", "")
					name = name:gsub(",", "")
					create_skin_record(file, name, author, license, nil, nil, nil, nil, nil)
				end
			end
		end
	end
	p:close()
	update_skin_active(1, 'true')
end
--bdb()

minetest.register_chatcommand("build_db", {
    description = "",
    params = "",
	privs = {server = true},
    func = function(name)
		minetest.chat_send_player(name, "building database...")
		bdb()
		minetest.chat_send_player(name, "db data inserted...")
    end,
  })
