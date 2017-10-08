local APPNAME = "NBS Play!"
local VERSION = "1.5"
local COPYRIGHT = "Copyright (C) 2017 BLOKKY all rights reserved"

local shell = require("shell")
local computer = require("computer")
local filesystem = require("filesystem")
local note = require("note")
local term = require("term")
local component = require("component")
local event = require("event")
local gpu = term.gpu()

local BASE_KEY = 21 -- Actual key for key 0. Key 1 => BASE_KEY + 1, Key 2 => BASE_KEY + 2, ...
local BREAK =    10 -- Time in milliseconds to break between notes

--[[
	GUI
]]

local screenW, screenH = gpu.getResolution()

local TOPBAR_BGCOLOR =      0xFFFFFF   -- Top bar background color
local TOPBAR_FGCOLOR =      0x000000   -- Top bar foreground color
local BACKGROUND_COLOR =    0x3F3F3F   -- App background color
local BACKGROUND_FGCOLOR =  0x7F7F7F   -- App background text color
local PROGBAR_COLOR =       0xFF0000   -- Progress bar color
local PROGBAR_BGCOLOR =     0x1F0000   -- Progress bar background color
local MSGBOX_BGCOLOR =      0x7E7E7E   -- Message box background color
local MSGBOX_FGCOLOR =      0xFFFFFF   -- Message box foreground color
local MSGBOX_FGCOLOR_DARK = 0xAAAAAA   -- Message box foreground color(Darker)
local TITLEINFO_BGCOLOR =   0x3F3FFF   -- Title bar color for information
local TITLEERR_BGCOLOR =    0xFF0000   -- Title bar color for error
local TITLE_FGCOLOR =       0xFFFFFF   -- Title bar foreground color

-- drawBackground(): Draws background
local function drawBackground()
	gpu.setBackground(BACKGROUND_COLOR)
	gpu.fill(1, 1, screenW, screenH, ' ')
end

-- drawWindow(X, Y, Width, Height, Title bar text, Title bar background color): Draws window
-- NOTE: Height does not includes title bar height
local function drawWindow(X, Y, Width, Height, Title, TitleColor)
	local titleX = (screenW - #Title) / 2
	local titleBarX = X
	local titleBarW = Width
	gpu.setBackground(TitleColor)
	gpu.setForeground(TITLE_FGCOLOR)
	gpu.fill(X, Y, titleBarW, 1, ' ')
	gpu.set(titleX, Y, Title)
	gpu.setBackground(MSGBOX_BGCOLOR)
	gpu.fill(X, Y + 1, Width, Height, ' ')
end

-- drawProgressWindow(Message, Title bar text, Max progess): Draws message box with progress bar background
local function drawProgressWindow(Message, Title, ProgressMax)
	local progressBarWidth = math.floor(screenW / 4)
	local progressBarX = math.floor((screenW - progressBarWidth) / 2)
	local progressBarY = math.floor((screenH - 1) / 2)
	local messageX = progressBarX + 1
	local messageY = progressBarY - 2
	local boxX = progressBarX - 1
	local boxY = messageY - 2
	local boxW = 2 + progressBarWidth
	local boxH = 6
	drawWindow(boxX, boxY, boxW, boxH, Title, TITLEINFO_BGCOLOR)
	gpu.setBackground(MSGBOX_BGCOLOR)
	gpu.set(messageX, messageY, Message)

	gpu.setBackground(PROGBAR_BGCOLOR)
	gpu.fill(progressBarX, progressBarY, progressBarWidth, 1, ' ')
	gpu.setBackground(MSGBOX_BGCOLOR)
	gpu.setForeground(MSGBOX_FGCOLOR_DARK)
end

-- drawProgress(Current progress, Max progess): Draws progress bar on window drawn by drawProgressWindow()
local function drawProgress(ProgressCurrent, ProgressMax)
	local progressBarWidth = math.floor(screenW / 4)
	local progressBarX = math.floor((screenW - progressBarWidth) / 2)
	local progressBarY = math.floor((screenH - 1) / 2)
	local messageX = progressBarX + 1
	local messageY = progressBarY - 2
	local boxX = progressBarX - 1
	local boxY = messageY - 2
	local boxW = 2 + progressBarWidth
	local boxH = 6
	gpu.setBackground(MSGBOX_BGCOLOR)
	local progW = math.floor((ProgressCurrent * progressBarWidth) / ProgressMax)
	gpu.setBackground(PROGBAR_COLOR)
	gpu.fill(progressBarX, progressBarY, progW, 1, ' ')
	gpu.setBackground(MSGBOX_BGCOLOR)
	gpu.setForeground(MSGBOX_FGCOLOR_DARK)
	local str = ProgressCurrent.."/"..ProgressMax
	gpu.set(progressBarX + progressBarWidth - #str, progressBarY + 1, str)
end

local NOTE_MAX = 95

local lastNoteMeter = {}

local NOTE_WIDTH = 2  -- Width of note displayed on screen
local KEYWIDTH = 4
local KEYHEIGHT = 10
local PRINTY = screenH - KEYHEIGHT + 1
local KEYS_COUNT = 75
local KEYSWIDTH = KEYWIDTH * ((6 * 7) + 2) -- 6: 6 octaves, 7: 7 keys(Non #) per octave, 2: key A0 and B0
local XOFFSET = -math.abs((KEYSWIDTH - screenW) / 2)
XOFFSET = XOFFSET - 20

local instruments = {
  [0] = { Name = "Harp", Color = 0x006BB7 },
  [1] = { Name = "Double Bass", Color = 0x00C416 },
  [2] = { Name = "Bass Drum", Color = 0x7F0037 },
  [3] = { Name = "Snare Drum", Color = 0xAF9200 },
  [4] = { Name = "Click", Color = 0xB200FF }, 
  [5] = { Name = "Guitar", Color = 0x562200 },
  [6] = { Name = "Flute", Color = 0xE0BB00 },
  [7] = { Name = "Bell", Color = 0x7300A8 },
  [8] = { Name = "Chime", Color = 0x005C9E },
  [9] = { Name = "Xyolophone", Color = 0x7A6660 },
}

local keys = {
  ['C'] = 0,
  ['D'] = 1,
  ['E'] = 2,
  ['F'] = 3,
  ['G'] = 4,
  ['A'] = 5,
  ['B'] = 6,
}
local noteInfos = {}

for key = 0, KEYS_COUNT - 1 do
  local this = {}
  local midi = key + 21
  if midi > 95 then
    error("Key="..key)
  end
  local str = note.name(midi)
  local kStr = string.sub(str, 1, 1)
  local a = string.sub(str, 2, 2)
  local sharp = false
  local octave
  if a == '#' then
    sharp = true
    octave = tonumber(string.sub(str, 3, 3))
  else
    octave = tonumber(a)
  end
  
  this.Name = str
  this.IsSharp = sharp
  this.Octave = octave
  this.KeyInOctave = keys[kStr]
  
  noteInfos[key] = this
end

--[[
  drawMusicScreen(Piano table): Draws music screen(Piano view).
    Piano table contains row(1 tick per row)s which contains colors for each key(nil=No press).
]]
local function drawMusicScreen(PianoTable)
  -- Draw background
  gpu.setBackground(BACKGROUND_COLOR)
  gpu.fill(1, 1, screenW, PRINTY - 1, ' ')
  
  -- Draw color information(Which color is which instrument)
  local y = 1
  gpu.setForeground(BACKGROUND_FGCOLOR)
  for k, instrument in pairs(instruments) do
    if instrument.Used then
      gpu.setBackground(instrument.Color)
      gpu.set(1, y, ' ')
      gpu.setBackground(BACKGROUND_COLOR)
      gpu.set(2, y, ": "..tostring(instrument.Name))
      y = y + 1
    end
  end
  
  -- Draw piano&note view
  gpu.setForeground(0x000000)
  local lastWhiteDark = true  -- Last white key was darker one?
  for isSharp = 0, 1 do
    for key = 0, KEYS_COUNT do
      local k = noteInfos[key]
      if k == nil then
        break
      end
      if (isSharp == 0 and not k.IsSharp) or (isSharp == 1 and k.IsSharp) then
        
        local prtX = XOFFSET + KEYWIDTH * (((7 * k.Octave)) + k.KeyInOctave)
        if prtX + KEYWIDTH - 1 > 0 then
          if prtX > screenW then
            break
          end
          
          local height = KEYHEIGHT
          local width = KEYWIDTH

          
          if k.IsSharp then
            prtX = prtX + KEYWIDTH / 2 + 1
            height = KEYHEIGHT / 2
            width = KEYWIDTH / 2
            gpu.setBackground(0x000000)
          else
            if lastWhiteDark then
              gpu.setBackground(0xFFFFFF)
              lastWhiteDark = false
            else
              gpu.setBackground(0xBEBEBE)
              lastWhiteDark = true
            end
          end
          if PianoTable[1] ~= nil then
            local col = PianoTable[1][key]
            if col ~= nil then
              gpu.setBackground(col)
            end
          end
          gpu.fill(prtX, PRINTY, width, height, ' ')
          
          -- Draw note name if it's non-sharp one
          if not k.IsSharp then
            local name = k.Name
            local namePrintX = prtX + (width - #name)/2
            gpu.set(namePrintX, PRINTY + height - 1, name)
          end
          
          -- Draw notes
          local index = 2
          local lastColor = nil
          local notePrtX = prtX + ((width - NOTE_WIDTH) / 2)
          for notePrtY = PRINTY - 1, 1, -1 do
            local row = PianoTable[index]
            if row == nil then
              break
            end
            local col = row[key]
            if col ~= nil then
              gpu.setBackground(col)
              gpu.fill(notePrtX, notePrtY, NOTE_WIDTH, 1, ' ')
            end

            index = index + 1
          end
        end
      end
    end
  end
  gpu.setBackground(0x000000)
end

-- drawMessageBox(Message, Title bar text, Title bar color): Draws an message box with simple information
local function drawMessageBox(Message, Title, TitleColor)
	local messageX = (screenW - #Message) / 2
	local messageY = (screenH - 1) / 2
	local boxX = messageX - 1
	local boxY = messageY - 2
	local boxW = #Message + 2
	local boxH = 3
	drawWindow(boxX, boxY, boxW, boxH, Title, TitleColor)
	gpu.setBackground(MSGBOX_BGCOLOR)
	gpu.setForeground(MSGBOX_FGCOLOR)
	gpu.set(messageX, messageY, Message)
end

-- drawErrorMessage(Message): Draw an error message box
local function drawErrorMessage(Message)
	drawMessageBox(Message, "Error", TITLEERR_BGCOLOR)
end

-- drawInfoMessage(Message, Title bar text): Draw an info message box
local function drawInfoMessage(Message, Title)
	drawMessageBox(Message, Title, TITLEINFO_BGCOLOR)
end


-- resetColor(): Reset color to black and white
local function resetColor()
	gpu.setBackground(0x000000)
	gpu.setForeground(0xFFFFFF)
end

--[[
	Note block playback
]]

local fileCurrOff = 1 -- Current offset in file
local fileBuffer = ""

-- Success? = readFile(Path): Reads file.
local function readFile(Path)
	fileBuffer = ""
	local size = filesystem.size(Path)
	local file, err = filesystem.open(Path, "rb")
	if file == nil then
		return false
	end

	local remaining = size
	drawProgressWindow("Reading file...", "Loading file...", size)
	while remaining > 0 do
		drawProgress(size - remaining, size)
		local str, err = file:read(remaining)
		if not str then
			error("Cannot read file: "..tostring(err))
		end
		fileBuffer = fileBuffer..str
		remaining = remaining - #str
	end
	drawBackground()
	file:close()
	fileCurrOff = 1
	return true
end

-- Byte (or nil if failed) = readByte(): Read 8bit integer from file
local function readByte()
	local s = string.sub(fileBuffer, fileCurrOff, fileCurrOff)
	if s == nil then
		error("Malformed NBS(250)")
	end
	fileCurrOff = fileCurrOff + 1
	local b = string.byte(s)
	if b == nil then
		error("Malformed NBS(251)")
	end
	return b
end

-- Byte (or nil if failed) = readShort(): Read 16bit integer from file
local function readShort()
	local b1 = readByte()
	local b2 = readByte()
	return bit32.lshift(b2, 8) + b1
end

-- Byte (or nil if failed) = readShort(): Read 32bit integer from file
local function readInteger()
	local b1 = readByte()
	local b2 = readByte()
	local b3 = readByte()
	local b4 = readByte()
	return bit32.lshift(b4, 24) + bit32.lshift(b3, 16) + bit32.lshift(b2, 8) + b1
end

-- String (or nil if failed) = readString(File): Read string from file
local function readString(File)
	local len = readInteger(File) -- String length
	if len == nil then
		error("Malformed NBS(260)")
	end
	local s = string.sub(fileBuffer, fileCurrOff, fileCurrOff + len - 1)
	if #s ~= len then
		error("Malformed NBS file(261)")
	end
	fileCurrOff = fileCurrOff + len
	return s
end

local totalRam = computer.totalMemory()

local function showHelp()
	print("Usage: nbsplay [Options] [NBS Files/Directories... or Playlist file]")
	print("Options:")
	print(" --playlist-file or -p: Play using playlist file.")
	print("  Playlist file(.txt file) consists with file paths per a line.")
	print(" --device-list or -l: Show list of sound card devices currently installed and exit.")
	print(" --channel-map or -m: Show sound card channel mapping for each channel and exit.")
	print(" --help or -h: Show this help and exit.")
	print(" --version or -v: Show version of this software and exit.")
end


local playlist = {}
local usePlaylistFile = false

local filePaths, options = shell.parse(...)
-- Parse options

if options["playlist-file"] or options["p"] then
	usePlaylistFile = true
end
if options["device-list"] or options["l"] then
	for n, card in ipairs(soundCards) do
		local cardInfo = computer.getDeviceInfo()[card.address]
		print("Component("..card.slot.."): "..cardInfo.vendor.." "..cardInfo.product.." "..cardInfo.description)
	end
	return
end
if options["channel-map"] or options["m"] then
	for n = 1, numberOfChannels do
		print("Channel "..n..": Card "..(getSoundCard(n).address)..", Channel "..getChannel(n))
	end
	return
end
if options["help"] or options["h"] then
	showHelp()
	return
end
if options["version"] or options["v"] then
	print(APPNAME.." V"..VERSION)
	print(COPYRIGHT)
	return
end

-- Initialize GUI
drawBackground()

local playList = {}

-- Path = getFullPath(Path): Get absolute path
local function getFullPath(Path)
	local path = shell.resolve(Path, ext) or Path
	if filesystem.exists(path) then
		return path
	end
	path = filesystem.concat(shell.getWorkingDirectory(), Path)
	if filesystem.exists(path) then
		return path
	end
	error("File/Directory "..Path.." does not exists.")
end

-- Parse file paths, playlist file.
drawInfoMessage("Loading file list...", "Building playlist...")
for n, filePath in ipairs(filePaths) do
	local ext = "nbs"
	if usePlaylistFile then
		ext = "txt"
	end
	local fullPath = getFullPath(filePath)
	-- Playlist file?
	if usePlaylistFile then
		-- Read playlist file
		local playListFile = io.open(fullPath, "r")
		if playListFile == nil then
			drawErrorMessage("Cannot open playlist file.")
			resetColor()
			return
		end
		drawBackground()
		drawInfoMessage("Reading playlist file...", "Building playlist...")
		while true do
			drawTopBar("Playlist "..fullPath)
			local path = playListFile:read("*l")
			if path == nil then
				break
			end
			table.insert(playList, getFullPath(path))
		end
		drawBackground()
		break -- We don't need to read anymore.
	-- File/directory?
	else
		table.insert(playList, fullPath)
	end
end

-- Handle directories
drawBackground()
drawInfoMessage("Reading directories(if exists)...", "Building playlist...")
for n, filePath in ipairs(playList) do
	-- Directory?
	if filesystem.isDirectory(filePath) then
		for file in filesystem.list(filePath) do
			local path = filesystem.concat(filePath, file)
			if not filesystem.isDirectory(path) then
				table.insert(playList, path)
			end
		end
		drawBackground()
	end
end

-- Check if every file exists
drawBackground()
drawInfoMessage("Checking playlist...", "Building playlist...")
for n, filePath in ipairs(playList) do
	if not filesystem.exists(filePath) then
		drawErrorMessage(n..": File/Directory "..filePath.." does not exists.")
		resetColor()
		return
	end
end

-- playPlaylist(): Plays playlist(playList table)
local function playPlaylist()
	-- More about NBS format: http://www.stuffbydavid.com/mcnbs/format
	for n, songFilePath in ipairs(playList) do
		local ok = readFile(songFilePath)
		if ok then
			local song = {}
			
			-- Read Part I, Basic infrmation.
			song.Length = readShort()
			song.Height = readShort()
			song.Name = readString()
			song.Author = readString()
			song.OriginalAuthor = readString()
			
			local titleText = n.."/"..#playList..": "
			if #song.Name > 0 then
				titleText = song.Name
				if #song.Author > 0 then
					titleText = song.Author..":: "..titleText
				end
				if #song.OriginalAuthor > 0 then
					titleText = titleText.." (Orignal author: "..song.OriginalAuthor..")"
				end
			end
			if #titleText > 0 then
				titleText = titleText.."(From "..songFilePath..")"
			else
				titleText = songFilePath
			end
			
			song.Description = readString()
			song.Tempo = (readShort() or 0) / 100.0
			if song.Tempo == 0 then
				drawErrorMessage("Malformed NBS file(1)")
				resetColor()
				return
			end
			local b = readByte()
			if b == 1 then
				song.AutoSave = true
			elseif b == 0 then
				song.AutoSave = false
			else
				drawErrorMessage("Malformed NBS file(2)")
				resetColor()
				return
			end
			song.AutoSaveDuration = readByte()
			song.TimeSignature = readByte()

			if song.TimeSignature < 2 or 8 < song.TimeSignature then
				drawErrorMessage("Malformed NBS file(3)")
				resetColor()
				return
			end
			song.MinutesSpent = readInteger()
			song.LeftClicks = readInteger()
			song.RightClicks = readInteger()
			song.BlocksAdded = readInteger()
			song.BlocksRemoved = readInteger()
			song.MIDIFileName = readString()

			local millisPerTick = 1000 / song.Tempo
			--error(tostring(millisPerTick))
			
			-- Read Part II, Note block data.
			-- After reading, notes can be accessed like this:
			--  song[Tick][Layer].Inst: Instrument
			--  song[Tick][Layer].Key: Key
			local tick = -1

			local lastMemoryUsage = 0
			
			drawProgressWindow("Reading note block information...", "Loading file...", song.Length)
			for n = 1, song.Length do
				drawProgress(n, song.Length)
				local jumpsToNextTick = readShort()
				if jumpsToNextTick == nil then
					drawErrorMessage("Malformed NBS file(4)")
					resetColor()
					return
				end
				if jumpsToNextTick == 0 then
					break
				end
				tick = tick + jumpsToNextTick
				
				song[tick] = {}
				
				local layer = -1
				while true do
					local jumpsToNextLayer = readShort()
					if jumpsToNextLayer == nil then
						drawErrorMessage("Malformed NBS file(5)")
						resetColor()
						return
					end
					if jumpsToNextLayer == 0 then
						break
					end
					layer = layer + jumpsToNextLayer
					-- We found a note block!
					local inst = readByte()
					local key = readByte()
					if key == nil then
						drawErrorMessage("Malformed NBS file(6)")
						resetColor()
						return
					end
					song[tick][layer] = { Inst = inst, Key = key }
				end
			end
			drawBackground()
			
			drawProgressWindow("Reading layers...", "Loading file...", song.Height)
			
			-- Read Part III, Layers.
			-- Layers can be accessed like this:
			-- layers[Layer number].Name: Layer name
			-- layers[Layer number].Volume: Layer volume(0~100)
			local layers = {}
			for n = 1, song.Height do
				drawProgress(n, song.Height)
				local name = readString()
				local volume = readByte()
				layers[n] = { Name = name, Volume = volume }
			end
			
			-- We are not going to read Part IV, Custom instruments. We are NOT going to
			--  use them.
			
			background_draw_copyright = false -- Hide copyright information for music screen
			drawBackground()
			
			-- Now we got all the notes we need. Now we have to build table for piano view.
      local pianoTable = {}
      
      local instColors = {
        0x006BB7, -- Harp
        0x00C416, -- Double Bass
        0x7F0037, -- Bass Drum
        0xAF9200, -- Snare Drum
        0xB200FF, -- Click
        0x562200, -- Guitar
        0xE0BB00, -- Flute
        0x7300A8, -- Bell
        0x005C9E, -- Chime
        0x7A6660, -- Xyolophone
      }
      
			for tik = 0, song.Length do
				local lyers = song[tik] -- Layers
        local pianoRow = {}
        
				if lyers ~= nil then
					for lyer = 0, song.Height do
						local noot = lyers[lyer]
						local layerInfo = layers[lyer + 1]
						if layerInfo == nil then
							break
						end
						--local vol = layerInfo.Volume / 100.0
						if noot ~= nil then
              -- 10 default instruments available since Note Block Studio v3.3.2
              local inst = instruments[noot.Inst]
              local instColor = inst.Color
              local key = noot.Key
							pianoRow[key] = instColor
              inst.Used = true
						end
					end
				end
        
        table.insert(pianoTable, pianoRow)
        --os.sleep(millisPerTick)
			end
      
      -- Add some empty lines to make first note fall down from top
      for n = 1, screenH do
        table.insert(pianoTable, 1, {})
      end
      
      -- Finally, start!
      local secsPerTick = millisPerTick/1000
      local startTime = computer.uptime()
      local lastTik = -1
      while #pianoTable > 0 do
        local current = startTime - computer.uptime()
        local tik = math.floor(current / secsPerTick)
        if tik ~= lastTik then
          for n = lastTik, tik - 1 do
            table.remove(pianoTable, 1)
          end
          drawMusicScreen(pianoTable)
          table.remove(pianoTable, 1)
          os.sleep(0.00000000000001)
          lastTik = tik
        end
      end
      drawMusicScreen(pianoTable)
      
		elseif not filesystem.isDirectory(songFilePath) then
			drawErrorMessage(n..": Cannot open: "..songFilePath)
			resetColor()
			return
		end
	end
end

--playPlaylist()
local ok, err = pcall(playPlaylist)
if not ok then
	drawErrorMessage(err)
end
resetColor()