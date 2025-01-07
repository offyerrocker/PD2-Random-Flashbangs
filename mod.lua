local FlashBangMemeger = class()

FlashBangMemeger.DEBUG = io.file_is_readable(ModPath .. "developer.txt") or false -- for flashbang makers

FlashBangMemeger.ASSETS_PATH = "mods/FlashBang Packs/"
FlashBangMemeger.SOFT_PATH = "gui/interface/MemeBangs/"

-- for loging
FlashBangMemeger.MOD_NAME = "Random Flashes"
FlashBangMemeger.ERRORS = {
	ASSETS_PATH_MISSING = "Pack directory not found @"
		.. FlashBangMemeger.ASSETS_PATH
		.. "\nIf you are reading this, create the folder manually or get the sample archive from the mod download page: https://modworkshop.net/mod/49716?tab=downloads",
	META_FILE_BROKEN_OR_CORRUPT = "The meta.json file inside folder '%s' does not contain proper json data or is corrupt.",
}
FlashBangMemeger.WARNINGS = {
	NO_PACKS_FOUND = "No FlashBang Packs Found! Returning to vanilla behavior...",
	META_FILE_NOT_FOUND = "Could not load meta.json file from path %s",
	ASSET_FILE_NOT_FOUND = "Could not load %s asset '%s' from path %s",
	EMPTY_META = "The '%s' pack does not contain any flashbangs!",
	EMPTY_ASSETS = "The '%s' pack attempted to create a flashbang with no existing assets linked!",
}

local table_get = function(t, ...)
	if not t then
		return nil
	end
	local v, keys = t, { ... }
	for i = 1, #keys do
		v = v[keys[i]]
		if v == nil then
			break
		end
	end
	return v
end

local get_setting = function(key)
	local options = table_get(_G, "MemeBangs", "Options")
	if options and table_get(options, "GetValue") then
		return options:GetValue(key)
	end

	return nil
end

local animate_ui = function(total_t, callback)
	local t = 0
	local const_frames = 0
	local count_frames = const_frames + 1
	while t < total_t do
		coroutine.yield()
		t = t + TimerManager:main():delta_time()
		if count_frames >= const_frames then
			callback(t / total_t, t)
			count_frames = 0
		end
		count_frames = count_frames + 1
	end

	callback(1, total_t)
end

function FlashBangMemeger:init()
	self.METADATA = {}
	self.FLASHBANGS = {}

	blt.xaudio.setup()

	self:load_meta_files()
	self:process_meta_files()
end

function FlashBangMemeger:load_meta_files()
	if not FileIO:Exists(self.ASSETS_PATH) then
		self:log("error", self.ERRORS.ASSETS_PATH_MISSING)
		return
	end

	for _, folder in pairs(file.GetDirectories(self.ASSETS_PATH)) do
		local current_path = self.ASSETS_PATH .. folder .. "/"
		if io.file_is_readable(current_path .. "meta.json") then
			local flash_list = {}
			local file = io.open(current_path .. "meta.json", "r")
			if file then
				flash_list = json.decode(file:read("*all"))
				file:close()
			end

			if not flash_list then
				self:log("error", self.ERRORS.META_FILE_BROKEN_OR_CORRUPT:format(folder))
			end

			table.insert(self.METADATA, {
				id = folder,
				path = current_path,
				flash_list = flash_list or {},
			})
		else
			self:log("warning", self.WARNINGS.META_FILE_NOT_FOUND:format(current_path))
		end
	end
end

function FlashBangMemeger:process_meta_files()
	for _, meta in pairs(self.METADATA) do
		if not next(meta.flash_list) then
			self:log("warning", self.WARNINGS.EMPTY_META:format(meta.id))
			goto next_item
		end

		for _, flash_data in pairs(meta.flash_list) do
			local textures, movies, sounds

			if flash_data.textures then
				textures = self:load_assets(meta.id, meta.path, flash_data.textures, Idstring("texture"))
			end

			if flash_data.movies then
				movies = self:load_assets(meta.id, meta.path, flash_data.movies, Idstring("movie"))
			end

			if flash_data.sounds then
				sounds = self:load_assets(meta.id, meta.path, flash_data.sounds)
			end

			if textures or movies or sounds then
				table.insert(self.FLASHBANGS, { textures = textures, movies = movies, sounds = sounds })
			else
				self:log("warning", self.WARNINGS.EMPTY_ASSETS:format(meta.id))
			end
		end

		::next_item::
	end

	if not next(self.FLASHBANGS) then
		self:log("warning", self.WARNINGS.NO_PACKS_FOUND)
	end
end

function FlashBangMemeger:log(label, text)
	log(string.format("[%s] [%s] %s", self.MOD_NAME, (label or "log"):upper(), text))
end

local ext_list = {
	[Idstring("texture"):key()] = { "", ".texture", ".dds" },
	[Idstring("movie"):key()] = { "", ".movie" },
	["sounds"] = { "", ".ogg" },
}
local dir_ext = {
	[Idstring("texture"):key()] = { "", "textures/", "assets/", "assets/textures/" },
	[Idstring("movie"):key()] = { "", "movies/", "videos/", "assets/", "assets/movies/" },
	["sounds"] = { "", "sounds/", "assets/", "assets/sounds/" },
}
local ext_translations = {
	[Idstring("texture"):key()] = "texture",
	[Idstring("movie"):key()] = "movie",
}
function FlashBangMemeger:load_assets(flash_id, path, asset_list, asset_type)
	local path_list = {}
	for _, asset in pairs(asset_list) do
		local file_found
		for _, extension in pairs((asset_type and ext_list[asset_type:key()]) or ext_list.sounds) do
			for _, prefix in pairs((asset_type and dir_ext[asset_type:key()]) or dir_ext.sounds) do
				local file_path = path .. prefix .. asset .. extension
				local soft_path = self.SOFT_PATH .. flash_id .. "/" .. asset
				if io.file_is_readable(file_path) then
					file_found = true
					if asset_type and not DB:has(asset_type, soft_path) then
						BLT.AssetManager:CreateEntry(soft_path, asset_type, file_path)
					end

					table.insert(path_list, asset_type and soft_path or file_path)

					goto next_asset
				end
			end
		end

		if not file_found then
			local type = asset_type and ext_translations[asset_type:key()] or "sound"
			self:log("warning", self.WARNINGS.ASSET_FILE_NOT_FOUND:format(type, asset, path))
		end

		::next_asset::
	end

	return next(path_list) and path_list
end

function FlashBangMemeger:get_random_flashbang()
	if not next(self.FLASHBANGS) then
		return "none", "flashbang list is empty", nil
	end

	local flash = self.FLASHBANGS[math.random(#self.FLASHBANGS)]
	local sound

	if flash.sounds then
		sound = flash.sounds[math.random(#flash.sounds)]
	end

	if flash.movies and flash.textures then
		local flash_type = ({ "movie", "texture" })[math.random(1, 2)]
		local asset_list = flash_type == "movie" and flash.movies or flash.textures

		return flash_type, asset_list[math.random(#asset_list)], sound
	end

	if flash.textures then
		return "texture", flash.textures[#flash.textures], sound
	end

	if flash.movies then
		return "movie", flash.movies[#flash.movies], sound
	end

	return "none", "", sound
end

function FlashBangMemeger:play_audio(file)
	self:stop_audio()

	self.audio_buffer = XAudio.Buffer:new(file)
	self.audio_source = XAudio.UnitSource:new(XAudio.PLAYER)

	self.audio_source:set_buffer(self.audio_buffer)
	self.audio_source:play()
	self.audio_source:set_volume(get_setting("__volume_start") or 1)
end

function FlashBangMemeger:stop_audio()
	if self.audio_buffer then
		-- self.audio_buffer:close(true)
		-- self.audio_buffer = nil
	end

	if self.audio_source then
		self.audio_source:stop()
		-- self.audio_source:close(true)
		-- self.audio_source = nil
	end
end

function FlashBangMemeger:set_volume(volume)
	if self.audio_source then
		self.audio_source:set_volume(volume)
	end
end

function FlashBangMemeger:setup_panel()
	if self.panel then
		return
	end

	local hud = managers.hud:script(_G.PlayerBase.PLAYER_INFO_HUD_FULLSCREEN_PD2)

	self.panel = hud and hud.panel or self._ws:panel({ name = "MemeBangPanel" })
end

function FlashBangMemeger:set_visual(type, path)
	self:remove_current_visuals(true)
	if type == "none" then
		return
	end

	if type == "movie" then
		self.video = self.panel:video({ video = path, loop = true, layer = 1 })
		self.video:set_size(self.panel:w(), self.panel:h())

		return
	end

	self.bitmap = self.panel:bitmap({
		texture = path,
		blend_mode = "add",
		color = Color.white:with_alpha(1),
		layer = 1,
	})
	self.bitmap:set_size(self.panel:w(), self.panel:h())
end

function FlashBangMemeger:remove_current_visuals(skip_anim)
	if not alive(self.panel) then
		return
	end

	if alive(self.bitmap) then
		if skip_anim then
			self.panel:remove(self.bitmap)
			self.bitmap = nil
			return
		end

		self.bitmap:animate(function(o)
			animate_ui(1, function(p)
				o:set_alpha(math.lerp(o:alpha(), 0, p))
			end)

			o:set_alpha(0)
			o:parent():remove(o)
			self.bitmap = nil
		end)
	end

	if alive(self.video) then
		if skip_anim then
			self.panel:remove(self.video)
			self.video = nil
			return
		end

		self.video:animate(function(o)
			animate_ui(1, function(p)
				o:set_alpha(math.lerp(o:alpha(), 0, p))
			end)

			o:set_alpha(0)
			o:parent():remove(o)
			self.video = nil
		end)
	end
end

function FlashBangMemeger:set_alpha(alpha)
	if alive(self.bitmap) then
		self.bitmap:set_alpha(math.max(alpha, 0))
	end

	if alive(self.video) then
		self.video:set_alpha(alpha)
	end
end

if RequiredScript == "lib/setups/gamesetup" then
	local GameSetup = _G["GameSetup"]
	Hooks:PostHook(GameSetup, "init_managers", "MemeBangs:init_managers", function(self, managers)
		if managers.memebangs then
			return
		end

		managers.memebangs = FlashBangMemeger:new()
	end)
end

-- there is no reason to init memebangs in the main menu, this is just for asset loading debug purposes.
if FlashBangMemeger.DEBUG and RequiredScript == "lib/setups/setup" then
	local Setup = _G["Setup"]
	Hooks:PostHook(Setup, "init_managers", "MemeBangs:init_managers", function(self, managers)
		if managers.memebangs then
			return
		end

		managers.memebangs = FlashBangMemeger:new()
	end)
end

if RequiredScript == "core/lib/managers/coreenvironmentcontrollermanager" then
	Hooks:PostHook(CoreEnvironmentControllerManager, "set_flashbang", "MemeBangs:CECM.set_flashbang", function(self)
		local type, visual, audio = managers.memebangs:get_random_flashbang()
		if type ~= "none" then
			managers.memebangs:set_visual(type, visual)
		end

		if audio then
			managers.memebangs:play_audio(audio)
		end
	end)
end

if RequiredScript == "lib/units/beings/player/playerdamage" then
	Hooks:PostHook(PlayerDamage, "update", "MemeBangs:PlayerDamage.update", function(self)
		if not managers.environment_controller then
			managers.memebangs:remove_current_visuals()
			return
		end

		local visual_fade_out = get_setting("__picture_fadeout")
		local audio_fade_out = get_setting("__volume_fadeout")
		if not visual_fade_out and not audio_fade_out then
			return
		end

		local flashbang_progress = managers.environment_controller._current_flashbang
		if not flashbang_progress then
			return
		end

		flashbang_progress = math.clamp(tonumber(flashbang_progress), 0, 1)

		if visual_fade_out then
			managers.memebangs:set_alpha(flashbang_progress)
		end

		if managers.memebangs.audio_source and not managers.memebangs.audio_source:is_active() then
			return
		end

		if audio_fade_out then
			managers.memebangs:set_volume(flashbang_progress * get_setting("__volume_start"))
		end
	end)

	Hooks:PostHook(PlayerDamage, "_stop_tinnitus", "MemeBangs:PlayerDamage._stop_tinnitus", function(self)
		managers.memebangs:stop_audio()
		managers.memebangs:remove_current_visuals()
	end)

	Hooks:PreHook(PlayerDamage, "pre_destroy", "MemeBangs:PlayerDamage.pre_destroy", function(self)
		managers.memebangs:stop_audio()
		managers.memebangs:remove_current_visuals()
	end)
end

if RequiredScript == "lib/managers/hudmanager" then
	local HUDManager = _G["HUDManager"]
	Hooks:PostHook(HUDManager, "_player_hud_layout", "memebangs:HUDManager._player_hud_layout", function(hudman)
		managers.memebangs:setup_panel()
	end)
end
