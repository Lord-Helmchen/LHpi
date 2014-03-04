--*- coding: utf-8 -*-
--[[- Magic Album API dummy
to test LHpi within an IDE and without needing Magic Album

Inspired by and loosely based on "MTG Mint Card.lua" by Goblin Hero, Stromglad1 and "Import Prices.lua" by woogerboy21;
who generously granted permission to "do as I like" with their code;
everything else Copyright (C) 2012-2013 by Christian Harms.
If you want to contact me about the script, try its release thread in http://www.slightlymagic.net/forum/viewforum.php?f=32

@module dummyMA
@author Christian Harms
@copyright 2012-2013 Christian Harms except parts by Goblin Hero, Stromglad1 or woogerboy21
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

--- @module ma
ma = {}
if not io then
	io = {}
	io.open = function ()  end
	io.input = function ()  end
	io.read = function ()  end
	io.output = function ()  end
	io.write = function ()  end
end

function ImportPrice(importfoil, importlangs, importsets)
	ma.Log( "Called dummyMa from MA. Raising error to inform user via dialog box." )
	error ("dummyMA.lua is not an import script. Do not attempt to use it from within MA!")
end -- function ImportPrice

--- GetURL
-- Returns downloaded web page or nil if there was an error (page not found, network problems, etc.)
-- dummy: just prints request to stdout
-- 
-- @function [parent=#ma] GetURL
-- @param #string url
-- @return #string webpage
-- @return nil on error
function ma.GetUrl(url)
	print("dummy.GetUrl called for " .. url)
	return nil
end

--- GetFile
-- Returns loaded file or nil if there was an error (file not found, out of memory, etc.).
-- For security reasons only files from the Magic Album folder can be loaded.
-- filepath is relative to the Magic Album folder. I.e. if you call
--  file = ma.GetFile("Prices\\test.dat")
-- "MA_FOLDER\Prices\test.dat" will be loaded. Do not forget to use double slashes for paths.
-- dummy: functional. DANGER: no security implemented.
-- 
-- @function [parent=#ma] GetFile
-- @param #string filepath
-- @return #string file
-- @return nil on error
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

--- PutFile
-- Saves data to the file. For security reasons the file is placed inside the Magic Album folder.
-- "filepath" is relative to the Magic Album folder (see GetFile description).
-- If "append" parameter is missing or 0 - file will be overwritten.
-- Otherwise data will be added to the end of file.
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

--- Log
-- Adds debug message to Magic Album log file.
-- dummy: just prints to stdout instead.
-- 
-- @function [parent=#ma] Log
-- @param #string message
function ma.Log(message)
	print("ma.Log\t" .. tostring(message) )
end

--- SetPrice
-- Set the price of the certain card.
-- setid is the numeric ID of the set. You can find all available IDs in "Database\Sets.txt" file.
-- langid is the numeric ID of the language. You can find all available IDs in "Database\Languages.txt" file.
-- cardname is the name of the card in UTF-8 encoding. Magic Album tries to match the cardname first against the Oracle Name, then against the Name field.
-- cardversion is the version of the card as it is shown in Magic Album. If set to "*" all versions of the card will be processed.
-- regprice and foilprice are the numerical values. Pass zero if you do not know or do not want to set the value.
-- this function returns the number of modified cards.
-- dummy: just prints request to stdout
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

--- SetProgress
-- Sets progress bar text and position. Position is a numeric value in range 0..100. 
-- dummy: just prints request to stdout
-- 
-- @function [parent=#ma] SetProgress
-- @param #string text
-- @param #number position	0 ... 100
function ma.SetProgress(text, position)
	print("ma.SetProgress\t " .. position .. " %\t: \"" .. text .. "\"")
end

function loadlibonly()
	local libver="2.1"
	do -- load LHpi library from external file
		local libfile = "Prices\\LHpi-v" .. libver .. ".lua"
		local LHpilib = ma.GetFile( libfile )
		if not LHpilib then
			error( "LHpi library " .. libfile .. " not found." )
		else -- execute LHpilib to make LHpi.* available
			LHpilib = string.gsub( LHpilib , "^\239\187\191" , "" ) -- remove unicode BOM (0xEF, 0xBB, 0xBF) for files tainted by it :)
			if VERBOSE then
				ma.Log( "LHpi library " .. libfile .. " loaded and ready for execution." )
			end
			local execlib,errormsg = load( LHpilib , "=(load) LHpi library" )
			if not execlib then
				error( errormsg )
			end
			LHpi = execlib()
		end	-- if not LHpilib else
	end -- do load LHpi library
	collectgarbage() -- we now have LHpi table with all its functions inside, let's clear LHpilib and execlib() from memory
	LHpi.Log( "LHpi lib is ready to use." )
end -- function

local function mergetables (teins,tzwei,tdrei,tvier)
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
local specialsets = {
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
local expansionsets = {
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
local coresets = {
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

local function main()
	print("dummy says: Hello lua!")
	--loadlibonly()
	--dofile("Prices\\Import Prices.lua")
	dofile("Prices\\LHpi.magicuniverseDE-v2.1.lua")
	--dofile("Prices\\LHpi.mtgmintcard-v2.1.lua")
	--dofile("Prices\\LHpi.tcgplayerPriceGuide-v2.1.lua")
	--dofile("Prices\\LHpi.trader-onlineDE-v2.1.lua")
	-- force debug enviroment options
	VERBOSE = true
	LOGDROPS = true
	LOGNAMEREPLACE = true
	CHECKEXPECTED = true
	DEBUG = true
	DEBUGSKIPFOUND = false
	DEBUGVARIANTS = false
	OFFLINE = true
	SAVEHTML = false
	SAVETABLE=true
	print("dummy says: sitescript dofile'd")
	local fakeimportfoil = "Y"
	local fakeimportlangs = { [1] = "English" }
	--local fakeimportlangs = { [3] = "German" }
	local fakeimportlangs = { [1] = "English", [3]  = "German" , [5] = "Italian" ,[9] = "Simplified Chinese"}
	--local fakeimportlangs = alllangs
	--local fakeimportsets = { [788] = "Magic 2013"; }
	--local fakeimportsets = { [784]="Dark Ascension";[782]="Innistrad";[786]="Avacyn Restored";}
	--local fakeimportsets = coresets
	local fakeimportsets = mergetables ( coresets, expansionsets)
	--local fakeimportsets = mergetables ( coresets, expansionsets, specialsets, promosets )
	ImportPrice( fakeimportfoil, fakeimportlangs, fakeimportsets )
	--print(LHpi.Tostring( "this is a string." ))
	print("dummy says: Goodbye lua!")
end

main()
--EOF