local FlashBangMemeger = class()
FlashBangMemeger.ASSETS_PATH = "mods/FlashBang Packs/"
FlashBangMemeger.SOFT_PATH = "gui/interface/MemeBangs/"

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

function FlashBangMemeger:init()
	self.METADATA = {}
	self.FLASHBANGS = {}

	blt.xaudio.setup()

	self:load_meta_files()
	self:process_meta_files()
end

function FlashBangMemeger:load_meta_files()
	for _, folder in pairs(file.GetDirectories(self.ASSETS_PATH)) do
		local current_path = self.ASSETS_PATH .. folder .. "/"
		if io.file_is_readable(current_path .. "meta.json") then
			local flash_list = {}
			local file = io.open(current_path .. "meta.json", "r")
			if file then
				flash_list = json.decode(file:read("*all"))
				file:close()
			end

			table.insert(self.METADATA, {
				id = folder,
				path = current_path,
				flash_list = flash_list or {},
			})
		end
	end
end

function FlashBangMemeger:process_meta_files()
	for _, meta in pairs(self.METADATA) do
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

			table.insert(self.FLASHBANGS, { textures = textures, movies = movies, sounds = sounds })
		end
	end
end

local ext_list = {
	[Idstring("texture"):key()] = { "", ".texture", ".dds" },
	[Idstring("movie"):key()] = { "", ".movie" },
	["sounds"] = { "", ".ogg", ".wav", ".wave" },
}
local dir_ext = {
	[Idstring("texture"):key()] = { "", "textures/", "assets/", "assets/textures/" },
	[Idstring("movie"):key()] = { "", "movies/", "videos/", "assets/", "assets/movies/" },
	["sounds"] = { "", "sounds/", "assets/", "assets/sounds/" },
}
function FlashBangMemeger:load_assets(flash_id, path, asset_list, asset_type)
	local path_list = {}
	for _, asset in pairs(asset_list) do
		for _, extension in pairs((asset_type and ext_list[asset_type:key()]) or ext_list.sounds) do
			for _, prefix in pairs((asset_type and dir_ext[asset_type:key()]) or dir_ext.sounds) do
				local file_path = path .. prefix .. asset .. extension
				local soft_path = self.SOFT_PATH .. flash_id .. "/" .. asset
				if io.file_is_readable(file_path) then
					if asset_type and not DB:has(asset_type, soft_path) then
						BLT.AssetManager:CreateEntry(soft_path, asset_type, file_path)
					end

					table.insert(path_list, asset_type and soft_path or file_path)

					goto next_asset
				end
			end
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
	self:remove_current_visuals()

	if type == "movie" then
		self.video = self.panel:video({ video = path, loop = true, layer = 1 })
		self.video:set_size(self.panel:w(), self.panel:h())

		return
	end

	self.bitmap = self.panel:bitmap({ texture = path, color = Color.white:with_alpha(1), layer = 1 })
	self.bitmap:set_size(self.panel:w(), self.panel:h())
end

function FlashBangMemeger:remove_current_visuals()
	if not alive(self.panel) then
		return
	end

	if alive(self.bitmap) then
		self.panel:remove(self.bitmap)
		self.bitmap = nil
	end

	if alive(self.video) then
		self.panel:remove(self.video)
		self.video = nil
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

		if managers.memebangs.audio_source and not managers.memebangs.audio_source:is_active() then
			return
		end

		local flashbang_progress = managers.environment_controller._current_flashbang
		flashbang_progress = math.clamp(tonumber(flashbang_progress), 0, 1)

		local visual_fade_out = get_setting("__picture_fadeout")
		if visual_fade_out then
			managers.memebangs:set_alpha(flashbang_progress)
		end

		local audio_fade_out = get_setting("__volume_fadeout")
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
