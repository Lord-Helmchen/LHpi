--*- coding: utf-8 -*-
--[[- Magic Album API dummy
to test LHpi within an IDE and without needing Magic Album

Inspired by and loosely based on "MTG Mint Card.lua" by Goblin Hero, Stromglad1 and "Import Prices.lua" by woogerboy21;
who generously granted permission to "do as I like" with their code;
everything else Copyright (C) 2012-2014 by Christian Harms.
If you want to contact me about the script, try its release thread in http://www.slightlymagic.net/forum/viewforum.php?f=32

@module dummyMA
@author Christian Harms
@copyright 2012-2014 Christian Harms except parts by Goblin Hero, Stromglad1 or woogerboy21
@release This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

--[[ CHANGES
0.3
	misc. small improvements to code and/or comments
	patch paths, because dev src has been moved from MA\Prices
	dummy.fakesitescript()
]]

--[[- "main" function called by Magic Album; just display error and return.
 Called by Magic Album to import prices. Parameters are passed from MA.
 We don't want to call the dummy from within MA.
 @function [parent=#global] ImportPrice
 @param #string importfoil	"Y"|"N"|"O"
 @param #table importlangs	{ #number (langid)= #string , ... }
 @param #table importsets	{ #number (setid)= #string , ... }
]]
function ImportPrice(importfoil, importlangs, importsets)
	ma.Log( "Called dummyMa from MA. Raising error to inform user via dialog box." )
	error ("dummyMA.lua is not an import script. Do not attempt to use it from within MA!")
end -- function ImportPrice

--[[-
Simulate MA's API functions
@module ma
]]
ma = {}
if not io then
	io = {}
	io.open = function ()  end
	io.input = function ()  end
	io.read = function ()  end
	io.output = function ()  end
	io.write = function ()  end
end

--- GetURL.
-- Returns downloaded web page or nil if there was an error (page not found, network problems, etc.).
-- 
-- dummy: just prints request to stdout
-- 
-- @function [parent=#ma] GetURL
-- @param #string url
-- @return #string webpage OR nil instead on error
function ma.GetUrl(url)
	print("dummy.GetUrl called for " .. url)
	local host,file = string.match(url, "http://([^/]+)/(.+)" )
--	try {
--		require "luasocket"
--		local c = assert(socket.connect(host, 80))
--		c:send("GET " .. file .. " HTTP/1.0\r\n\r\n")
--		c:close()
--	}
	return nil
end

--- GetFile.
-- Returns loaded file or nil if there was an error (file not found, out of memory, etc.).
-- For security reasons only files from the Magic Album folder can be loaded.
-- filepath is relative to the Magic Album folder. I.e. if you call
--  file = ma.GetFile("Prices\\test.dat")
-- "MA_FOLDER\Prices\test.dat" will be loaded. Do not forget to use double slashes for paths.
-- 
-- dummy: functional. DANGER: no security implemented.
-- 
-- @function [parent=#ma] GetFile
-- @param #string filepath
-- @return #string file OR nil instead on error
function ma.GetFile(filepath)
	print("dummy.GetFile called for " .. filepath)
    local handle = io.open(filepath,"r")
    local file = nil
    if handle then
    	local temp = io.input()	-- save current file
       	io.input( handle )		-- open a new current file
		file = io.read( "*all" )
		io.input():close()		-- close current file
		io.input(temp)			-- restore previous current file
	end
	return file
end

--- PutFile.
-- Saves data to the file. For security reasons the file is placed inside the Magic Album folder.
-- "filepath" is relative to the Magic Album folder (see GetFile description).
-- If "append" parameter is missing or 0 - file will be overwritten.
-- Otherwise data will be added to the end of file.
-- 
-- dummy: functional. DANGER: no security implemented.
-- 
-- @function [parent=#ma] PutFile
-- @param #string filepath
-- @param #string data
-- @param #number append nil or 0 for overwrite
function ma.PutFile(filepath, data, append)
	--print("dummy.PutFile called for " .. filepath)
	local a = append or 0
	local handle
	if append == 0 then
		handle = io.open(filepath,"w")	-- get file handle in new file mode
	else
		handle = io.open(filepath,"a")	-- get file handle in append mode
	end
	local temp = io.output()	-- save current file
	io.output( handle )			-- open a new current file
	io.write( data )	
	io.output():close()			-- close current file
    io.output(temp)				-- restore previous current file
end

--- Log.
-- Adds debug message to Magic Album log file.
-- 
-- dummy: just prints to stdout instead.
-- 
-- @function [parent=#ma] Log
-- @param #string message
function ma.Log(message)
	print("ma.Log\t" .. tostring(message) )
end

--- SetPrice.
-- Set the price of the certain card.
-- setid is the numeric ID of the set. You can find all available IDs in "Database\Sets.txt" file.
-- langid is the numeric ID of the language. You can find all available IDs in "Database\Languages.txt" file.
-- cardname is the name of the card in UTF-8 encoding. Magic Album tries to match the cardname first against the Oracle Name, then against the Name field.
-- cardversion is the version of the card as it is shown in Magic Album. If set to "*" all versions of the card will be processed.
-- regprice and foilprice are the numerical values. Pass zero if you do not know or do not want to set the value.
-- this function returns the number of modified cards.
-- dummy: just prints request to stdout and return 1
-- 
-- Examples:
-- Set the price of foil M11 English Celestial Purge to $4.25
-- ma.SetPrice(770, 1, "Celestial Purge", "", 0, 4.25)
-- Set the regular and foil prices for all versions of M10 Russian Forests (using Russian card name)
-- ma.SetPrice(759, 2, "Лес", "*", 0.01, 0.1)
-- 
-- @function [parent=#ma SetPrice
-- @param #number setid
-- @param #number langid
-- @param #string cardname
-- @param #number cardversion	#string "" and #string "*" is also possible
-- @param #number regprice 		#nil is also possible
-- @param #number foilprice 	#nil is also possible
-- @return #number modifiednum
function ma.SetPrice(setid, langid, cardname, cardversion, regprice, foilprice)
	local dummystring = ""
	dummystring = dummystring .. "ma.SetPrice\tsetid=\"" .. setid .. "\""
	dummystring = dummystring .. "\tlangid=\"" .. langid .. "\""
	dummystring = dummystring .. "\tcardname=\"" .. cardname .. "\""
	dummystring = dummystring .. "\tcardversion=\"" .. tostring(cardversion) .. "\""
	dummystring = dummystring .. "\tregprice=\"" .. regprice .. "\""
	dummystring = dummystring .. "\tfoilprice=\"" .. foilprice .."\""
	print (dummystring)
	--if cardversion == "*" then
	--	return 4
	--elseif
	--	LHpi.Length(cardversion) == 1 then
	--	return 1
	--end
	return 1 -- just always assume one price was set successfully
end

--- SetProgress.
-- Sets progress bar text and position. Position is a numeric value in range 0..100.
-- 
-- dummy: just prints request to stdout
-- 
-- @function [parent=#ma] SetProgress
-- @param #string text
-- @param #number position	0 ... 100
function ma.SetProgress(text, position)
	print("ma.SetProgress\t " .. position .. " %\t: \"" .. text .. "\"")
end

--- table to hold dummyMA additional functions
-- @field [parent=global] dummy
dummy={}
---	dummy version
-- @field [parent=#dummy] #string version
dummy.version = "0.3"

--[[- loads LHpi library for testing.
@function [parent=#dummy] loadlibonly
@param #string libver			library version to be loaded
@param #string pathprefix		(optional)
@param #string savepathprefix	(optional)
@return #table LHpi library object
]]
function dummy.loadlibonly(libver,pathprefix,savepathprefix)
	local LHpi = {}
	local pathprefix = pathprefix or ""
	local savepathprefix = savepathprefix or ""
	do -- load LHpi library from external file
		local libname = pathprefix .. "lib\\LHpi-v" .. libver .. ".lua"
		local LHpilib = ma.GetFile( libname )
		if not LHpilib then
			error( "LHpi library " .. libname .. " not found." )
		else -- execute LHpilib to make LHpi.* available
			LHpilib = string.gsub( LHpilib , "^\239\187\191" , "" ) -- remove unicode BOM (0xEF, 0xBB, 0xBF) for files tainted by it :)
			if _VERSION == "Lua 5.1" then
				-- not only do we need to change the way the library is loaded,
				-- but also how the data file is loaded from within the library
				LHpilib = string.gsub(LHpilib, 'errormsg = load','errormsg=loadstring' )
			end
			if pathprefix~="" then
				--patch library to change paths
				pathprefix = string.gsub(pathprefix,"\\","\\\\")
				LHpilib = string.gsub(LHpilib,'Prices\\\\',pathprefix )
				if savepathprefix~="" then
					savepathprefix = string.gsub(savepathprefix,"\\","\\\\")
					LHpilib = string.gsub(LHpilib,'savepath = "src','savepath = "' .. savepathprefix)
				end
			end--if pathprefix
			if VERBOSE then
				ma.Log( "LHpi library " .. libname .. " loaded and ready for execution." )
			end
			local execlib,errormsg=nil
			if _VERSION == "Lua 5.1" then
				-- we need to change the way the library is loaded
				execlib,errormsg = loadstring( LHpilib , "=(loadstring) LHpi library" )
			else
				execlib,errormsg = load( LHpilib , "=(load) LHpi library" )
			end
			if not execlib then
				error( errormsg )
			end
			LHpi = execlib()
		end	-- if not LHpilib else
	end -- do load LHpi library
	collectgarbage() -- we now have LHpi table with all its functions inside, let's clear LHpilib and execlib() from memory
	LHpi.Log( "LHpi lib is ready to use." )
	return LHpi
end -- function

--[[- load and execute sitescript.
You can then call the sitescript's ImportPrice, as ma would do.
@function [parent=#dummy] loadscript
@param #string scriptname
@param #string pathprefix		(optional)
@param #string savepathprefix	(optional)
@return nil, but script is loaded and executed
]]
function dummy.loadscript(scriptname,pathprefix,savepathprefix)
	local pathprefix = pathprefix or ""
	local savepathprefix = savepathprefix or ""
	do
		local scriptfile = ma.GetFile( pathprefix .. scriptname )
		if not scriptfile then
			error( "script " .. scriptname .. " not found." )
		else
			scriptfile = string.gsub( scriptfile , "^\239\187\191" , "" ) -- remove unicode BOM (0xEF, 0xBB, 0xBF) for files tainted by it :)
			if _VERSION == "Lua 5.1" then
				-- not only do we need to change the way the sitescript is loaded,
				-- but also how the library is loaded from within the sitescript
				scriptfile = string.gsub(scriptfile, 'local execlib,errormsg = load','local execlib,errormsg=loadstring')
				--but we even need to go one level deeper: change how the library loads the data file
				scriptfile = string.gsub( scriptfile, 'local execlib,errormsg=loadstring',
							'LHpilib=string.gsub(LHpilib,"errormsg = load","errormsg=loadstring") local execlib,errormsg=loadstring' )
			end
			if pathprefix~="" then
				--patch script to change paths
				pathprefix = string.gsub(pathprefix,"\\","\\\\")
				scriptfile = string.gsub(scriptfile,'Prices\\\\',pathprefix )
				if savepathprefix~="" then
					savepathprefix = string.gsub(savepathprefix,"\\","\\\\")
					scriptfile = string.gsub(scriptfile,'savepath = "src','savepath = "' .. savepathprefix)
				end
				--patch library loading to patch paths in library
				scriptfile = string.gsub( scriptfile, "local execlib,errormsg=load",
							'LHpilib=string.gsub(LHpilib,"Prices\\\\","'..pathprefix..'") local execlib,errormsg=load' )
				if savepathprefix~="" then
					savepathprefix = string.gsub(savepathprefix, "\\", "\\\\" )
					scriptfile = string.gsub( scriptfile, "local execlib,errormsg=load",
								'LHpilib=string.gsub(LHpilib,"savepath = \\\"src","savepath = \\\"'..savepathprefix..'\") local execlib,errormsg=load' )
				end
			end--if pathprefix
			local execscript,errormsg=nil
			if _VERSION == "Lua 5.1" then
				-- we need to change the way the script is loaded
				execscript,errormsg = loadstring( scriptfile , "=(loadstring)" .. scriptname )
			else
				execscript,errormsg = load( scriptfile , "=(load)" .. scriptname )
			end
			if not execscript then
				error( errormsg )
			end
			execscript()
		end--if scriptfile	
	end--do
	collectgarbage()
end--function

--[[- fake a minimal, nonfunctional sitescript.
You can then run library functions to test them.

@function [parent=#dummy] fakesitescript
@return nil, but site fields an functions are set.
]]
function dummy.fakesitescript()
	site={}
	site.langs={ {id=1,url="foo"} }
	site.sets= { [0]={id=0,lang={true},fruc={true},url="bar"} }
	site.frucs={ {id=1,name="fruc",isfoil=true,isnonfoil=true,url="baz"} }
	site.regex="none"
	dataver=2
	scriptname="LHpi.debug.lua"
	function site.BuildUrl() return { ["fakeURL"] ={} } end
end--function fakesitescript

--[[- merge up to four tables.
@function [parent=#dummy] mergetables
@param #table teins
@param #table tzwei
@param #table tdrei	(optional)
@param #table tvier (optional)
@return #table
]]
function dummy.mergetables (teins,tzwei,tdrei,tvier)
	for k,v in pairs(tzwei) do 
		teins[k] = v
	end
	if tdrei then
		for k,v in pairs(tdrei) do 
			teins[k] = v
		end
	end	 
	if tvier then
		for k,v in pairs(tvier) do 
			teins[k] = v
		end
	end	 
	return teins
end -- function

--- @field #table alllangs
local alllangs = {
 [1]  = "English";
 [2]  = "Russian";
 [3]  = "German";
 [4]  = "French";
 [5]  = "Italian";
 [6]  = "Portuguese";
 [7]  = "Spanish";
 [8]  = "Japanese";
 [9]  = "Simplified Chinese"; -- for mtgmintcards
 [10] = "Traditional Chinese";
 [11] = "Korean";
 [12] = "Hebrew";
 [13] = "Arabic";
 [14] = "Latin";
 [15] = "Sanskrit";
 [16] = "Ancient Greek";
}

--- @field #table promosets
local promosets = {
 [50] = "Full Box Promotion";
 [45] = "Magic Premiere Shop";
 [42] = "Summer of Magic Promos";
 [43] = "Two-Headed Giant Promos";
 [41] = "Happy Holidays Promos";
 [40] = "Arena/Colosseo Leagues Promos";
 [33] = "Championships Prizes";
 [32] = "Pro Tour Promos";
 [31] = "Grand Prix Promos";
 [30] = "Friday Night Magic Promos";
 [27] = "Alternate Art Lands";
 [26] = "Magic Game Day";
 [25] = "Judge Gift Cards";
 [24] = "Champs Promos";
 [23] = "Gateway & WPN Promos";
 [22] = "Prerelease Promos";
 [21] = "Release & Launch Parties Promos";
 [20] = "Magic Player Rewards";
 [15] = "Convention Promos";
 [12] = "Hobby Japan Commemorative Cards";
 [11] = "Redemption Program Cards";
 [10] = "Junior Series Promos";
 [9]  = "Video Game Promos";
 [8]  = "Stores Promos";
 [7]  = "Magazine Inserts";
 [6]  = "Comic Inserts";
 [5]  = "Book Inserts";
 [4]  = "Ultra Rare Cards";
 [2]  = "DCI Legend Membership";
}

--- @field #table specialsets
local specialsets = {
 [801] = "Commander 2013 Edition";
 [799] = "Duel Decks: Heroes vs. Monsters";
 [798] = "From the Vault: Twenty";
 [796] = "Modern Masters";
 [794] = "Duel Decks: Sorin vs. Tibalt";
 [792] = "Commander's Arsenal";
 [790] = "Duel Decks: Izzet vs. Golgari";
 [789] = "From the Vault: Realms";
 [787] = "Planechase 2012 Edition";
 [785] = "Duel Decks: Venser vs. Koth";
 [783] = "Premium Deck Series: Graveborn";
 [781] = "Duel Decks: Ajani vs. Nicol Bolas";
 [780] = "From the Vault: Legends";
 [778] = "Magic: The Gathering Commander";
 [777] = "Duel Decks: Knights vs. Dragons";
 [774] = "Premium Deck Series: Fire & Lightning";
 [772] = "Duel Decks: Elspeth vs. Tezzeret";
 [771] = "From the Vault: Relics";
 [769] = "Archenemy";
 [768] = "Duels of the Planeswalkers";
 [766] = "Duel Decks: Phyrexia vs. The Coalition";
 [764] = "Premium Deck Series: Slivers";
 [763] = "Duel Decks: Garruk vs. Liliana";
 [761] = "Planechase";
 [760] = "From the Vault: Exiled";
 [757] = "Duel Decks: Divine vs. Demonic";
 [755] = "Duel Decks: Jace vs. Chandra";
 [753] = "From the Vault: Dragons";
 [740] = "Duel Decks: Elves vs. Goblins";
 [675] = "Coldsnap Theme Decks";
 [635] = "Magic Encyclopedia";
 [600] = "Unhinged";
 [490] = "Deckmasters";
 [440] = "Beatdown";
 [415] = "Starter 2000";
 [405] = "Battle Royale";
 [390] = "Starter 1999";
 [380] = "Portal Three Kingdoms";
 [340] = "Anthologies";
 [320] = "Unglued";
 [310] = "Portal Second Age";
 [260] = "Portal";
 [225] = "Introductory Two-Player Set";
 [201] = "Renaissance";
 [200] = "Chronicles";
 [70]  = "Vanguard";
}
--- @field #table expansionsets
local expansionsets = {
 [802] = "Born of the Gods";
 [800] = "Theros";
 [795] = "Dragon's Maze";
 [793] = "Gatecrash";
 [791] = "Return to Ravnica";
 [786] = "Avacyn Restored";
 [784] = "Dark Ascension";
 [782] = "Innistrad";
 [776] = "New Phyrexia";
 [775] = "Mirrodin Besieged";
 [773] = "Scars of Mirrodin";
 [767] = "Rise of the Eldrazi";
 [765] = "Worldwake";
 [762] = "Zendikar";
 [758] = "Alara Reborn";
 [756] = "Conflux";
 [754] = "Shards of Alara";
 [752] = "Eventide";
 [751] = "Shadowmoor";
 [750] = "Morningtide";
 [730] = "Lorwyn";
 [710] = "Future Sight";
 [700] = "Planar Chaos";
 [690] = "Time Spiral Timeshifted";
 [680] = "Time Spiral";
 [670] = "Coldsnap";
 [660] = "Dissension";
 [650] = "Guildpact";
 [640] = "Ravnica: City of Guilds";
 [620] = "Saviors of Kamigawa";
 [610] = "Betrayers of Kamigawa";
 [590] = "Champions of Kamigawa";
 [580] = "Fifth Dawn";
 [570] = "Darksteel";
 [560] = "Mirrodin";
 [540] = "Scourge";
 [530] = "Legions";
 [520] = "Onslaught";
 [510] = "Judgment";
 [500] = "Torment";
 [480] = "Odyssey";
 [470] = "Apocalypse";
 [450] = "Planeshift";
 [430] = "Invasion";
 [420] = "Prophecy";
 [410] = "Nemesis";
 [400] = "Mercadian Masques";
 [370] = "Urza's Destiny";
 [350] = "Urza's Legacy";
 [330] = "Urza's Saga";
 [300] = "Exodus";
 [290] = "Stronghold";
 [280] = "Tempest";
 [270] = "Weatherlight";
 [240] = "Visions";
 [230] = "Mirage";
 [220] = "Alliances";
 [210] = "Homelands";
 [190] = "Ice Age";
 [170] = "Fallen Empires";
 [160] = "The Dark";
 [150] = "Legends";
 [130] = "Antiquities";
 [120] = "Arabian Nights";
}
--- @field #table coresets
local coresets = {
 [797] = "Magic 2014";
 [788] = "Magic 2013";
 [779] = "Magic 2012";
 [770] = "Magic 2011";
 [759] = "Magic 2010";
 [720] = "Tenth Edition";
 [630] = "9th Edition";
 [550] = "8th Edition";
 [460] = "7th Edition";
 [360] = "6th Edition";
 [250] = "5th Edition";
 [180] = "4th Edition";
 [140] = "Revised Edition";
 [139] = "Revised Edition (Limited)";
 [110] = "Unlimited";
 [100] = "Beta";
 [90]  = "Alpha";
}

--[[- run as lua application  from your ide.

@function [parent=#global] main
]]
function main()
	print("dummy says: Hello " .. _VERSION .. "!")
	--adjust paths if not developing inside "Magic Album\Prices"
	local path="src\\"
	--don't keep a seperate dev savepath, though
	local savepath = "src\\..\\..\\..\\Magic Album\\Prices"

--	dummy.fakesitescript()
--	LHpi = dummy.loadlibonly(2.9,path,savepath)
--	dummy.loadscript("\\Import Prices.lua",savepath,savepath)
--	dummy.loadscript("\\MTG Mint Card.lua",savepath,savepath)
--	dummy.loadscript("lib\\LHpi.sitescriptTemplate-v2.9.2.1.lua",path,savepath)
--	dummy.loadscript("LHpi.magicuniverseDE-v2.9.2.1.lua",path,savepath)
--	dummy.loadscript("LHpi.trader-onlineDE-v2.9.2.1.lua",path,savepath)
	dummy.loadscript("LHpi.tcgplayerPriceGuide-v2.9.2.1.lua",path,savepath)
--	dummy.loadscript("LHpi.mtgmintcard-v2.9.2.1.lua",path,savepath)
--	dummy.loadscript("LHpi.mtgprice.com-v2.9.2.1.lua",path,savepath)
	-- force debug enviroment options
	VERBOSE = true
	LOGDROPS = true
	LOGNAMEREPLACE = true
	LOGFOILTWEAK = true
	CHECKEXPECTED = true
	STRICTCHECKEXPECTED = true
	DEBUG = true
	DEBUGSKIPFOUND = false
	DEBUGVARIANTS = false
	OFFLINE = true
	SAVELOG = true
	SAVEHTML = false
	SAVETABLE=false
	print("dummy says: sitescript dofile'd")

--	LHpi.LoadData(2)
	local fakeimportfoil = "y"
	local fakeimportlangs = { [1] = "Language" }
	local fakeimportlangs = { [1] = "English", [3]  = "German" , [5] = "Italian" ,[9] = "Simplified Chinese"}
--	local fakeimportlangs = alllangs
	local fakeimportsets = { [0] = "debugset"; }
	local fakeimportsets = { [220] = "some set"; }
--	local fakeimportsets = { [220]="foo";[800]="bar";[0]="baz";}
--	local fakeimportsets = coresets
--	local fakeimportsets = dummy.mergetables ( coresets, expansionsets, specialsets, promosets )

--	LHpi.DoImport(fakeimportfoil, fakeimportlangs, fakeimportsets)
	ImportPrice( fakeimportfoil, fakeimportlangs, fakeimportsets )
--	print(LHpi.Tostring( "this is a string." ))
--	print(LHpi.ByteRep("Zwölffüßler"))
	print("dummy says: Goodbye lua!")
end

main()
--EOF