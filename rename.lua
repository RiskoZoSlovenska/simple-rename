local fs = require("fs")
local Buffer = require("Buffer").Buffer
local pathlib = require("path")
local getFileType = require("file-type")

local MIN_BYTES = 262



local function printf(fmt, ...)
	return print(string.format(fmt, ...))
end

local function assert2(func, ...)
	return assert(func(...))
end


local function randomString(size)
	local buf = {}

	for i = 1, size do
		buf[i] = string.char(math.random(97, 122))
	end

	return table.concat(buf)
end


local function getMimeMain(mime)
	return mime:match("^%a+")
end

local function splitName(name)
	local ext = pathlib.extname(name)
	local root = pathlib.basename(name, ext)

	return root, ext
end

local function cleanRoot(name)
	return (name
		:gsub("[^a-zA-Z0-9%-_ ]", "")
		:match("^%s*(.-)%s*$")
		:gsub("^$", randomString(6))
	)
end


local function readFile(filePath)
	local fd = assert2(fs.openSync, filePath, "r")
	local bytes = assert2(fs.readSync, fd, MIN_BYTES, 0)
	assert2(fs.closeSync, fd)

	return Buffer:new(bytes)
end

local function getMimeOfFile(path)
	local buffer = readFile(path)

	local fileType = getFileType(buffer)
	if not fileType then return nil, nil end

	return fileType.mime, "." .. fileType.ext
end



local function processFile(dir, oldName)
	local oldPath = pathlib.join(dir, oldName)
	local oldRoot, oldExt = splitName(oldName)
	local mime, newExt = getMimeOfFile(oldPath)

	if not mime                     then return false end
	if oldExt:lower() == newExt     then return false end
	if getMimeMain(mime) ~= "image" then return false end

	local newRoot = cleanRoot(oldRoot)
	local newName = newRoot .. newExt
	local newPath = pathlib.join(dir, newName)

	if fs.existsSync(newPath) then
		printf("!!! Did not rename %s to %s because already exists", oldName, newName)
		return false
	end

	assert2(fs.renameSync, oldPath, newPath)

	printf("%s:\n  %s -> %s", oldRoot, oldExt, newExt)
	if newRoot ~= oldRoot then
		printf("  %s", newRoot)
	end
	return true
end

local function processDir(dir)
	printf("Renaming in %q...", dir)
	local renamed = 0

	for name, t in fs.scandirSync(dir) do
		if t ~= "file" then goto continue end

		local success, res = pcall(processFile, dir, name)
		if not success then
			printf("Error when renaming %s:\n%s", name, res)
		elseif res then
			renamed = renamed + 1
		end

		::continue::
	end

	printf("Finished! Renamed %d file(s).", renamed)
end



processDir(args[2] or "/sdcard/Download")