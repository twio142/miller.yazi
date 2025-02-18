---@diagnostic disable: undefined-global
local M = {}

local function detect_separator(file)
	local scpt = [=[
file="%s"
ss=(, ";" "|", "	")
vs=("${ss[@]}")
read -r fl < "$file"
while IFS= read -r l; do
    nvs=()
    for s in "${vs[@]}"; do
        fc=$(echo "$fl" | grep -o "$s" | wc -l)
        cc=$(echo "$l" | grep -o "$s" | wc -l)
        [[ "$fc" -eq "$cc" && "$cc" -gt 0 ]] && nvs+=("$s")
    done
    vs=("${nvs[@]}")
    [[ ${#vs[@]} -eq 1 ]] && break
done < "$file"
printf "${vs[0]}"
	]=]
	scpt = string.format(scpt, tostring(file.url))
	local output, _ = Command("bash"):args({ "-c", scpt }):stdout(Command.PIPED):stderr(Command.PIPED):output()
	local sep = output.stdout
	return sep == "" and "," or sep
end

function M:peek(job)
	local sep = detect_separator(job.file)
	local child = Command("mlr")
		:args({
			"--icsv",
			"--opprint",
			"-C",
			"--key-color",
			"208",
			"--ifs",
			sep,
			"--value-color",
			"grey70",
			"cat",
			tostring(job.file.url),
		})
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:spawn()

	local limit = job.area.h
	local i, lines = 0, ""
	repeat
		local line, event = child:read_line()
		if event == 1 then
			ya.err(tostring(event))
		elseif event ~= 0 then
			break
		end

		i = i + 1
		if i > job.skip then
			lines = lines .. line
		end
	until i >= job.skip + limit

	child:start_kill()
	if job.skip > 0 and i < job.skip + limit then
		ya.manager_emit(
			"peek",
			{ tostring(math.max(0, i - limit)), only_if = tostring(job.file.url), upper_bound = "" }
		)
	else
		lines = lines:gsub("\t", string.rep(" ", PREVIEW.tab_size))
		ya.preview_widgets(job, { ui.Text(lines):area(job.area) })
	end
end

function M:seek(job)
	local h = cx.active.current.hovered
	if h and h.url == job.file.url then
		local step = math.floor(job.units * job.area.h / 10)
		ya.manager_emit("peek", {
			tostring(math.max(0, cx.active.preview.skip + step)),
			only_if = tostring(job.file.url),
		})
	end
end

return M
