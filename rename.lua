local fs = require("fs")
local Buffer = require("Buffer").Buffer
local path = require("path")
local fileType = require("file-type")

local MIN_BYTES = 262



local function printf(fmt, ...)
	return print(string.format(fmt, ...))
end


local function cleanName(name)
	return (name
		:gsub("[^a-zA-Z0-9%-_ ]", "")
		:match("^%s*(.-)%s*$")
		:gsub("^$", "empty")
	)
end


local function readFile(filePath)
	local fd, err1 = fs.openSync(filePath, "r")
	if not fd then return nil, err1 end

	local bytes, err2 = fs.readSync(fd, MIN_BYTES, 0)
	if not bytes then return nil, err2 end

	local success, err3 = fs.closeSync(fd)
	if not success then return nil, err3 end

	return Buffer:new(bytes), nil
end


local function processFile(dir, oldBase)
	local oldFull = path.join(dir, oldBase)
	local oldExt = path.extname(oldBase)
	local rootName = oldBase:sub(1, -(#oldExt + 1))

	local actualExt, actualMime
	do
		local buf, err = readFile(oldFull)
		if not buf then
			printf("Warning: Unable to read file %q because: %s", oldFull, err)
			return nil, nil
		end

		local res = fileType(buf)
		if not res then return nil, nil end

		actualExt, actualMime = ("." .. res.ext), res.mime
	end

	if oldExt == actualExt then return end
	if not actualMime:find("^image/") then return end

	local newBase = cleanName(rootName) .. actualExt
	local newFull = path.join(dir, newBase)

	if fs.existsSync(newFull) then
		printf("!!! Did not rename %s to %s because already exists", oldBase, newBase)
		return nil, nil
	end

	fs.renameSync(oldFull, newFull)
	return oldBase, actualExt
end


local function rename(dir)
	print("Renaming...")
	local numRenamed = 0

	for basename, fType in fs.scandirSync(dir) do
		if fType == "file" then
			local old, new = processFile(basename)

			if new then
				numRenamed = numRenamed + 1
				print(new .. " <- " .. old)
			end
		end
	end

	printf("Finished! Renamed %d files.", numRenamed)
end



rename(args[2] or "/sdcard/Download")