-- @since 25.5.28

local M = {}

local options = ya.sync(function(state, update)
	if update then
		state.theme = update.theme
		state.custom_args = update.custom_args
		state.scroll_step = update.scroll_step
		state.code_theme = update.code_theme
	end
	return {
		theme = state.theme,
		custom_args = state.custom_args,
		scroll_step = state.scroll_step,
		code_theme = state.code_theme,
	}
end)

local emit = ya.emit or ya.manager_emit or ya.mgr_emit

local MEM = { key = nil, lines = nil, total = 0, last_skip = -1, last_w = 0, last_h = 0 }

local NHASH_BASE = 131
local NHASH_MOD = 1000003
local CACHE_PRIME = 10007

local function strip_osc8(s)
	return s
		:gsub("\27%]8;.-\7", ""):gsub("\27%]8;.-\27\\", "")
		:gsub("\27%]8;;\7", ""):gsub("\27%]8;;\27\\", "")
		:gsub("\r", "")
end

local function collect_tokens(acc, value)
	if type(value) ~= "string" then return end
	local input = value:gsub(",", " ")
	local i, len = 1, #input
	while i <= len do
		while i <= len and input:sub(i, i):match("%s") do i = i + 1 end
		if i > len then break end
		local ch = input:sub(i, i)
		local token
		if ch == '"' or ch == "'" then
			local j = i + 1
			while j <= len and input:sub(j, j) ~= ch do j = j + 1 end
			if j <= len then
				token = input:sub(i + 1, j - 1)
				i = j + 1
			else
				token = input:sub(i + 1)
				i = len + 1
			end
		else
			local j = i
			while j <= len and not input:sub(j, j):match("%s") do j = j + 1 end
			token = input:sub(i, j - 1)
			i = j
		end
		if token ~= "" then acc[#acc + 1] = token end
	end
end

local function strip_monitor_args(args)
	if not args[1] then return args end
	local filtered, i = {}, 1
	while i <= #args do
		local token = args[i]
		if token == "--monitor" then
			local next_token = args[i + 1]
			if next_token and not next_token:match("^%-") then
				i = i + 1
			end
		elseif token:match("^%-%-monitor=") then
		else
			filtered[#filtered + 1] = token
		end
		i = i + 1
	end
	return filtered
end

local function normalize_custom_args(input)
	local args = {}
	if type(input) == "string" then
		collect_tokens(args, input)
	elseif type(input) == "table" then
		for _, value in ipairs(input) do
			collect_tokens(args, value)
		end
	end
	args = strip_monitor_args(args)
	return args[1] and args or nil
end

local function normalize_scroll_step(value)
	if value == nil then return nil, false end
	if type(value) == "string" then
		local trimmed = value:match("^%s*(.-)%s*$")
		if trimmed == "" then return nil, false end
		if trimmed:lower() == "auto" then return nil, false end
		value = trimmed
	end
	local n = tonumber(value)
	if not n then return nil, true end
	if n <= 0 or math.floor(n) ~= n then return nil, true end
	return math.floor(n), false
end

local function _nhash(s)
	local h = 0
	for i = 1, #s do
		h = (h * NHASH_BASE + s:byte(i)) % NHASH_MOD
	end
	return h
end

local function cache_url(job, opts)
	opts = opts or options() or {}
	local w = (job.area and job.area.w) or 0
	local theme = opts.theme or ""
	local code_theme = opts.code_theme or ""
	local custom_args = opts.custom_args
	local th = _nhash(theme)
	local cth = _nhash(code_theme)
	local ch = (custom_args and #custom_args > 0) and _nhash(table.concat(custom_args, "\0")) or 0
	return ya.file_cache({
		file = job.file,
		skip = ((((w * CACHE_PRIME + (th % CACHE_PRIME)) * CACHE_PRIME) + (cth % CACHE_PRIME)) * CACHE_PRIME) +
			(ch % CACHE_PRIME),
	})
end

local function build_mdv_args(width, theme, code_theme, custom_args)
	local args
	if custom_args and #custom_args > 0 then
		args = {}
		for i = 1, #custom_args do args[i] = custom_args[i] end
	else
		args = {
			"--no-config",
			"-c", tostring(width),
			"-u", "it",
			"-l", "cut",
			"--wrap", "word",
			"--heading-layout", "level",
			"--smart-indent",
		}
	end

	local has_no_config, has_width, has_theme, has_code_theme = false, false, false, false
	for _, token in ipairs(args) do
		if token == "--no-config" then
			has_no_config = true
		elseif not has_width and (token == "-c" or token == "--cols" or token:match("^%-c=") or token:match("^%-%-cols=")) then
			has_width = true
		elseif not has_theme and (token == "--theme" or token == "-t" or token:match("^%-%-theme=") or token:match("^%-t=")) then
			has_theme = true
		elseif not has_code_theme and (token == "--code-theme" or token == "-T" or token:match("^%-%-code%-theme=") or token:match("^%-T=")) then
			has_code_theme = true
		end
	end

	if not has_no_config then table.insert(args, 1, "--no-config") end
	if not has_width then
		args[#args + 1] = "-c"
		args[#args + 1] = tostring(width)
	end
	if theme and not has_theme then
		args[#args + 1] = "--theme"
		args[#args + 1] = theme
	end
	if code_theme and not has_code_theme then
		args[#args + 1] = "--code-theme"
		args[#args + 1] = code_theme
	end

	return args
end

local function read_all(path)
	local f = io.open(tostring(path), "rb")
	if not f then return "" end
	local s = f:read("*a") or ""
	f:close()
	return s
end

local function split_lines(blob)
	local lines, i = {}, 0
	for line in (blob .. "\n"):gmatch("([^\n]*)\n") do
		i = i + 1
		lines[i] = line
	end
	return lines, i
end

local function show(job, widget)
	ya.preview_widget({
		area = job.area,
		file = job.file,
		mime = job.mime or "text/plain",
		skip = job.skip or 0,
	}, widget)
end


function M:preload(job)
	local opts = options() or {}
	local theme = opts.theme
	local code_theme = opts.code_theme
	local cache = cache_url(job, opts)
	if not cache then return true end

	local cha = fs.cha(cache)
	if cha and cha.len > 0 then
		return true
	end

	local src = fs.cha(job.file.url)
	if src and src.len == 0 then
		fs.write(cache, "")
		return true
	end

	local width = job.area and job.area.w or 0
	local custom_args = opts.custom_args
	local cmd_args = build_mdv_args(width, theme, code_theme, custom_args)
	cmd_args[#cmd_args + 1] = tostring(job.file.url)

	local command = Command("mdv")
	for _, arg in ipairs(cmd_args) do
		command:arg(arg)
	end
	local out = (command
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:output())

	if not out then
		return true, ui.Text("mdv: failed to start"):area(job.area)
	elseif out.status and not out.status.success then
		local msg = (out.stderr and out.stderr ~= "") and out.stderr or "mdv: rendering error"
		fs.write(cache, msg)
		return true, ui.Text(msg):area(job.area)
	end

	local normalized = strip_osc8(out.stdout)
	normalized = normalized:gsub("\t", string.rep(" ", (rt.preview and rt.preview.tab_size) or 4))
	return fs.write(cache, normalized)
end

function M:load_into_mem(job)
	local function build_prefixes_replay(blob)
		local prefixes, acc, ln = { "" }, {}, 1
		for line in (blob .. "\n"):gmatch("([^\n]*)\n") do
			for params in line:gmatch("\27%[([0-9:;]*)m") do
				local reset = (params == "")
				if not reset then
					for tok in params:gmatch("%d+") do
						if tok == "0" then
							reset = true
							break
						end
					end
				end
				if reset then
					acc = {}
				else
					acc[#acc + 1] = "\27[" .. params .. "m"
				end
			end
			ln = ln + 1
			prefixes[ln] = (#acc > 0) and table.concat(acc) or ""
		end
		return prefixes
	end

	local meta = fs.cha(job.file.url)
	local mtime = meta and meta.mtime or 0
	local opts = options() or {}
	local theme = opts.theme or ""
	local code_theme = opts.code_theme or ""
	local args_token = opts.custom_args and _nhash(table.concat(opts.custom_args, "\0")) or 0
	local key = table.concat({
		tostring(job.file.url),
		tostring(job.area and job.area.w or 0),
		tostring(mtime),
		theme,
		code_theme,
		tostring(args_token),
	}, "#")

	if MEM.key == key and MEM.lines then
		return MEM
	end

	local cache = cache_url(job, opts)
	if not cache then
		MEM = { key = key, lines = { "cache disabled" }, total = 1, last_skip = -1, last_w = 0, last_h = 0 }
		return MEM
	end

	local blob = read_all(cache)
	local lines, total = split_lines(blob)
	local prefixes = build_prefixes_replay(blob)

	local function is_visually_blank(s)
		s = strip_osc8(s)
		s = s:gsub("\27%[[0-9:;]*m", "")
		s = s:gsub("[ \t\r]", "")
		return s == ""
	end

	local first = 1
	while first <= total and is_visually_blank(lines[first]) do
		first = first + 1
	end

	local last = total
	while last >= first and is_visually_blank(lines[last]) do
		last = last - 1
	end

	if first > last then
		lines, prefixes, total = {}, prefixes and {}, 0
	else
		local new_len = last - first + 1
		if first > 1 or last < total then
			table.move(lines, first, last, 1, lines)
			for i = new_len + 1, total do lines[i] = nil end
			if prefixes then
				local plen = #prefixes
				table.move(prefixes, first, last, 1, prefixes)
				for i = new_len + 1, plen do prefixes[i] = nil end
			end
		end
		total = new_len
	end

	MEM = { key = key, lines = lines, total = total, prefixes = prefixes, last_skip = -1, last_w = 0, last_h = 0 }
	return MEM
end

function M:peek(job)
	local area, file = job.area, job.file
	local skip = math.max(0, job.skip or 0)

	local _, err_widget = self:preload(job)
	if err_widget then
		return show(job, err_widget)
	end

	local mem = self:load_into_mem(job)
	if not mem or mem.total == 0 then
		return show(job, ui.Text.parse("\27[38;2;15;17;26m\27[48;2;143;147;162mEmpty file\27[0m"):area(area))
	end

	local bound = math.max(0, mem.total - area.h)
	local eff_skip = math.min(skip, bound)
	if skip > bound and emit then emit("peek", { bound, only_if = file.url, upper_bound = true }) end
	if mem.last_skip == eff_skip and mem.last_w == area.w and mem.last_h == area.h then return end

	local start_line = eff_skip + 1
	local end_line = math.min(mem.total, start_line + area.h - 1)
	local prefix = mem.prefixes and mem.prefixes[start_line] or ""
	show(job, ui.Text.parse(prefix .. table.concat(mem.lines, "\n", start_line, end_line) .. "\27[0m"):area(area))
	mem.last_skip = eff_skip
	mem.last_w, mem.last_h = area.w, area.h
end

function M:seek(job)
	local h = cx.active and cx.active.current and cx.active.current.hovered
	if not (h and h.url == job.file.url and emit) then
		return
	end

	local units = job.units or 0
	if units == 0 then
		return
	end

	local opts = options()
	local configured = opts.scroll_step
	local height = (job.area and job.area.h) or 0
	local step = (configured and configured > 0) and units * configured or math.floor(units * height / 10)
	if step == 0 then step = ya.clamp(-1, units, 1) end
	if step == 0 then return end

	local current_skip = cx.active.preview.skip or 0
	local next_skip = math.max(0, current_skip + step)
	if next_skip ~= current_skip then emit("peek", { next_skip, only_if = job.file.url }) end
end

function M:setup(user)
	user = user or {}
	local theme = user.theme
	if theme == "" then theme = nil end -- Will be removed in newer versions of mdv
	local code_theme = user.code_theme
	local custom_args = normalize_custom_args(user.custom_args)
	local scroll_step, invalid_scroll_step = normalize_scroll_step(user.scroll_step)
	if invalid_scroll_step and ya and ya.notify then
		ya.notify {
			title = "mdv previewer",
			content = "Invalid value for `scroll_step`",
			timeout = 2,
			level = "warn",
		}
	end
	options({
		theme = theme,
		code_theme = code_theme,
		custom_args = custom_args,
		scroll_step = scroll_step,
	})
	if ya and ya.dbg then
		local args_info = custom_args and table.concat(custom_args, " ") or "default"
		local step_info = scroll_step and tostring(scroll_step) or "auto"
		local theme_info = theme or "mdv-default"
		local code_theme_info = code_theme or "mdv-default"
		ya.dbg(string.format("mdv-preview: theme '%s', code_theme '%s', custom args %s, scroll_step %s", theme_info,
			code_theme_info, args_info, step_info))
	end
end

return M
