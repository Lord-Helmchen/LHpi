--*- coding: utf-8 -*-
--[[- LHpi mtgmintcard.com sitescript 
Price import script for Magic Album
uses and needs LHpi library
to import card pricing from www.mtgmintcard.com.

Inspired by and loosely based on "MTG Mint Card.lua" by Goblin Hero, Stromglad1 and "Import Prices.lua" by woogerboy21;
who generously granted permission to "do as I like" with their code;
everything else Copyright (C) 2012-2013 by Christian Harms.
If you want to contact me about the script, try its release thread in http://www.slightlymagic.net/forum/viewforum.php?f=32

@module LHpi_mtgmintcard
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

--[[ CHANGES
Updated for MA 1.5.2.264b
use LHpi-v2.2
]]

-- options that control the amount of feedback/logging done by the script
--- @field [parent=#global] #boolean VERBOSE 			default false
VERBOSE = false
--- @field [parent=#global] #boolean LOGDROPS 			default false
LOGDROPS = false
--- @field [parent=#global] #boolean LOGNAMEREPLACE 	default false
LOGNAMEREPLACE = false

-- options that control the script's behaviour.
--- compare card count with expected numbers; default false
-- @field [parent=#global] #boolean CHECKEXPECTED
CHECKEXPECTED = true
--  Don't change anything below this line unless you know what you're doing :-)
---	log everything and exit on error; default false
-- @field [parent=#global] #boolean DEBUG			log all and exit on error; default false
DEBUG = false
---	while DEBUG, do not log raw html data found by regex 
-- @field [parent=#global] #boolean DEBUG			log all and exit on error; default true
DEBUGSKIPFOUND = true
--- DEBUG inside variant loops; default true
-- @field [parent=#global] #boolean DEBUGVARIANTS	DEBUG inside variant loops; default false
DEBUGVARIANTS = false
---	read source data from #string.savepath instead of site url; default false
-- @field [parent=#global] #boolean OFFLINE
OFFLINE = false
--- save a local copy of each source html to #string.savepath if not in OFFLINE mode; default false
-- @field [parent=#global] #boolean SAVEHTML
SAVEHTML = false
--- log to seperate logfile instead of Magic Album.log;	default true
-- @field [parent=#global] #boolean SAVELOG
SAVELOG = true
--- save price table to file before importing to MA;	default false
-- @field [parent=#global] #boolean SAVETABLE
SAVETABLE = false
--- revision of the LHpi library to use
-- @field [parent=#global] #string libver
libver = "2.2"
--- must always be equal to the scripts filename !
-- @field [parent=#global] #string scriptname	
scriptname = "LHpi.mtgmintcard-v" .. libver .. ".1.lua" 

--- @field [parent=#global] #table LHpi		LHpi library table
LHpi = {}

--- Site specific configuration
-- Settings that define the source site's structure and functions that depend on it
-- @type site
-- 
-- @field #string regex
-- @field #string currency
-- @field #string encoding
-- @field #string resultpattern
site={}
site.regex = 'class="cardBorderBlack">.-(<a[^>]+>[^<]+<.->[$€][%d.,]+<.->)'
site.currency = "$" -- not used yet
site.encoding = "utf-8"
site.resultregex = "Your query of .+ filtered by .+ returns (%d+) results."

--[[- "main" function.
 called by Magic Album to import prices. Parameters are passed from MA.
 
 @function [parent=#global] ImportPrice
 @param #string importfoil	"Y"|"N"|"O"
	-- parameter passed from Magic Album
	-- "Y"|"N"|"O"		Update Regular and Foil|Update Regular|Update Foil
 @param #table importlangs	{ #number = #string }
	-- parameter passed from Magic Album
	-- array of languages the script should import, represented as pairs { #number = #string } (see "Database\Languages.txt").
 @param #table importsets	{ #number = #string }
	-- parameter passed from Magic Album
	-- array of sets the script should import, represented as pairs { #number = #string } (see "Database\Sets.txt").
]]
function ImportPrice( importfoil , importlangs , importsets )
	if SAVELOG then
		ma.Log( "Check " .. scriptname .. ".log for detailed information" )
	end
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
	LHpi.DoImport (importfoil , importlangs , importsets)
	ma.Log( "End of Lua script " .. scriptname )
end -- function ImportPrice

--[[-  build source url/filename.
 Has to be done in sitescript since url structure is site specific.
 foilonly and isfile fields can be nil and then are assumed to be false.
 
 @function [parent=#site] BuildUrl
 @param #number setid
 @param #number langid
 @param #number frucid
 @param #boolean offline	(optional) use local file instead of url
 @return #table { #string = #table { foilonly = #boolean , isfile = #boolean } }

]]
function site.BuildUrl( setid,langid,frucid,offline )
	site.domain = "www.mtgmintcard.com/"
	site.fileprefix = "mtg"
--	site.file = "_search_result.php?currency_reference=EUR&search_result=500"
	site.file = "_search_result.php?search_result=500"
	site.setprefix = "&edition="
	site.frucprefix = "&mode="
	
	local container = {}
	local url = site.fileprefix .. site.langs[langid].url .. site.file .. site.setprefix .. site.sets[setid].url .. site.frucprefix .. site.frucs[frucid]
	if offline then
		url = savepath .. string.gsub( url, "%?", "_" )  .. ".html"
		container[url] = { isfile = true}
	else
		url = "http://" .. site.domain .. url
		container[url] = {}
	end -- if offline 
	
	if frucid == 1 then 
		container[url].foilonly = true
	else
		-- url without foil marker
	end -- if foil-only url
	return container
end -- function site.BuildUrl

--[[-  get data from foundstring.
 Has to be done in sitescript since html raw data structure is site specific.
 Price is returned as whole number to generalize decimal and digit group separators
 ( 1.000,00 vs 1,000.00 ); LHpi library then divides the price by 100 again.
 This is, of course, not optimal for speed, but the most flexible.

 Return value newCard can receive optional additional fields:
 #table pluginData is passed on by LHpi.buildCardData for use in
 site.BCDpluginName and/or site.BCDpluginCard.
 #string name will pre-set the card's unique (for the cardsetTable) identifying name.
 #table lang, #boolean drop, #table variant, #table regprice, #table foilprice
 will override LHpi.buildCardData generated values.
 
 @function [parent=#site] ParseHtmlData
 @param #string foundstring		one occurence of siteregex from raw html data
 @param #table urldetails	{ foilonly = #boolean , isfile = #boolean , setid = #number, langid = #number, 	frucid = #number }
 @return #table { names = #table { #number = #string, ... }, price = #table { #number = #string, ... }} 
]]
function site.ParseHtmlData( foundstring , 	urldetails )
	local _start,_end,name = string.find(foundstring, '<a .*href=%b"">([^<]+)</a>' )
	local _start,_end,price = string.find( foundstring , '$([%d.,]+)' )
	price = string.gsub( price , "[,.]" , "" )
	price = tonumber( price )
	local newCard = { names = { [urldetails.langid] = name }, price = { [urldetails.langid] = price } }
	if DEBUG then
		LHpi.Log( "site.ParseHtmlData\t returns" .. LHpi.Tostring(newCard) , 2 )
	end
	return newCard
end -- function site.ParseHtmlData

--[[- special cases card name manipulation
 Ties into LHpi.buildCardData to make changes that are specific to one site and thus don't belong into the library
 
 @function [parent=#site] BCDpluginName
 @param #string name		the cardname LHpi.buildardData is working on
 @param #number setid
 @returns #string name	modified cardname is passed back for further processing
]]
function site.BCDpluginName ( name , setid )
	if DEBUG then
		LHpi.Log( "site.BCDpluginName got " .. name .. " from set " .. setid , 2 )
	end
	
	-- mark condition modifier suffixed cards to be dropped
	name = string.gsub( name , "%(Used%)$" , "%0 (DROP)" )
	
	name = string.gsub( name , "\195\131\194\162" , "â" ) -- 0xc3 0x83 0xc2 0xa2
	name = string.gsub( name , "\195\131\226\128\160" , "Æ" ) -- 0xc3 0x83 0xe2 0x80 0xa0
	name = string.gsub(name , "%(Chinese Version%)" , "" )
--@lib	name = string.gsub( name , " / " , "|" )

	return name
end -- function site.BCDpluginName

--[[- special cases card data manipulation
 Ties into LHpi.buildCardData to make changes that are specific to one site and thus don't belong into the library
 
 @function [parent=#site] BCDpluginCard
 @param #table card		the card LHpi.BuildCardData is working on
 @param #number setid
 @returns #table card modified card is passed back for further processing
]]
function site.BCDpluginCard( card , setid )
	if DEBUG then
		LHpi.Log( "site.BCDpluginCard got " .. LHpi.Tostring( card ) .. " from set " .. setid , 2 )
	end
	
	-- nothing to be done here, just return card unchanged
	return card
end -- function site.BCDpluginCard

-------------------------------------------------------------------------------------------------------------
-- tables
-------------------------------------------------------------------------------------------------------------

--[[- table of (supported) languages.
-- { #number = { id = #number, full = #string, abbr = #string } }
-- 
--- @field [parent=#site] #table langs ]]
--- @field [parent=#site] #table langs
site.langs = {
	[1] = {id=1, full = "English", 	abbr="ENG" , 	url="" },
	[9] = {id=1, full = "Simplified Chinese", abbr="SZH" , 	url="c" },
}

--- @field [parent=#site] #table frucs	rarity array { #number = #string }
site.frucs = { "Foils" , "Regular" }

--[[- table of available sets
-- { #number = #table { #number id, #table lang = #table { #boolean, ... } , #table fruc = # table { #boolean, ... }, #string url } }
-- #number id		: setid (can be found in "Database\Sets.txt" file)
-- #table fruc		: table of available rarity urls to be parsed
--		compare with site.frucs
-- 		#boolean fruc[1]	: does foil url exist?
-- 		#boolean fruc[2]	: does regular url exist?
-- #table lang		:  table of available languages { #boolean , ... }
-- #string url		: set url infix
-- 
--- @field [parent=#site] #table sets ]]
--- @field [parent=#site] #table sets
site.sets = {
 -- Core sets
[788]={id = 788,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "2013+Core+set"}, 
[779]={id = 779,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "2012+Core+set"}, 
[770]={id = 770,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "2011+Core+set"}, 
[759]={id = 759,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "2010+Core+set"}, 
[720]={id = 720,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "10th+Edition+%28X+Edition%29"}, 
[630]={id = 630,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "9th+Edition"}, 
[550]={id = 550,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "8th+Edition"}, 
[460]={id = 460,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "7th+Edition"}, 
[360]={id = 360,	lang = { true , 	[9]=false }, 	fruc = { true ,true }, 	url = "6th+Edition"},
[250]={id = 250,	lang = { true , 	[9]=false }, 	fruc = { false,true }, 	url = "5th+Edition"},
[180]={id = 180,	lang = { true , 	[9]=true }, 	fruc = { false,true }, 	url = "4th+Edition"}, 
[140]={id = 140,	lang = { true , 	[9]=true }, 	fruc = { false,true }, 	url = "3rd+Edition+(Revised)"},
[139]=nil,
[110]={id = 110,	lang = { true , 	[9]=false }, 	fruc = { false,true }, 	url = "Unlimited"}, 
[100]={id = 100,	lang = { true , 	[9]=false }, 	fruc = { false,true }, 	url = "Beta"},
[90] ={id =  90,	lang = { true , 	[9]=false }, 	fruc = { false,true }, 	url = "Alpha"}, 
 -- Expansions
[795]={id = 795,	lang = { true , 	[9]=true }, 	fruc = { true, true }, 	url = "Dragon's+Maze"},
[793]={id = 793,	lang = { true , 	[9]=true }, 	fruc = { true, true }, 	url = "Gatecrash"},
[791]={id = 791, 	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Return+to+Ravnica"},
[786]={id = 786,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Avacyn+Restored"},
[784]={id = 784,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Dark+Ascension"}, 
[782]={id = 782,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Innistrad"}, 
[776]={id = 776,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "New+Phyrexia"},
[775]={id = 775,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Mirrodin+Besieged"},
[773]={id = 773,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Scars+of+Mirrodin"},
[767]={id = 767,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Rise+of+the+Eldrazi"},
[765]={id = 765,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Worldwake"},
[762]={id = 762,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Zendikar"},
[758]={id = 758,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Alara%20Reborn"},
[756]={id = 756,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Conflux"},
[754]={id = 754,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Shards+of+Alara"},
[752]={id = 752,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Eventide"},
[751]={id = 751,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Shadowmoor"},
[750]={id = 750,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Morningtide"},
[730]={id = 730,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Lorwyn"},
[710]={id = 710,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Future+Sight"},
[700]={id = 700,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Planar+Chaos"},
[690]={id = 690,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Timeshifted"},
[680]={id = 680,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Time+Spiral"},
[670]={id = 670,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Coldsnap"},
[660]={id = 660,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Dissension"},
[650]={id = 650,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Guildpact"},
[640]={id = 640,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Ravnica"},
[620]={id = 620,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Saviors+of+Kamigawa"},
[610]={id = 610,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Betrayers+of+Kamigawa"},
[590]={id = 590,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Champions+of+Kamigawa"},
[580]={id = 580,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Fifth+Dawn"},
[570]={id = 570,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Darksteel"},
[560]={id = 560,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Mirrodin"},
[540]={id = 540,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Scourge"},
[530]={id = 530,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Legions"},
[520]={id = 520,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Onslaught"},
[510]={id = 510,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Judgment"},
[500]={id = 500,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Torment"},
[480]={id = 480,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Odyssey"},
[470]={id = 470,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Apocalypse"},
[450]={id = 450,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Planeshift"},
[430]={id = 430,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Invasion"},
[420]={id = 420,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Prophecy"},
[410]={id = 410,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Nemesis"},
[400]={id = 400,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Mercadian+Masques"},
[370]={id = 370,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Urza's+Destiny"},
[350]={id = 350,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Urza's+Legacy"},
[330]={id = 330,	lang = { true , 	[9]=true }, 	fruc = { true ,true }, 	url = "Urza's+Saga"},
[300]={id = 300,	lang = { true , 	[9]=true }, 	fruc = { false,true }, 	url = "Exodus"},
[290]={id = 290,	lang = { true , 	[9]=true }, 	fruc = { false,true }, 	url = "Stronghold"},
[280]={id = 280,	lang = { true , 	[9]=true }, 	fruc = { false,true }, 	url = "Tempest"},
[270]={id = 270,	lang = { true , 	[9]=true }, 	fruc = { false,true }, 	url = "Weatherlight"},
[240]={id = 240,	lang = { true , 	[9]=true }, 	fruc = { false,true }, 	url = "Visions"},
[230]={id = 230,	lang = { true , 	[9]=true }, 	fruc = { false,true }, 	url = "Mirage"},
[220]={id = 220,	lang = { true , 	[9]=true }, 	fruc = { false,true }, 	url = "Alliances"},
[210]={id = 210,	lang = { true , 	[9]=true }, 	fruc = { false,true }, 	url = "Homelands"},
[190]={id = 190,	lang = { true , 	[9]=true }, 	fruc = { false,true }, 	url = "Ice+Age"},
[170]={id = 170,	lang = { true , 	[9]=false }, 	fruc = { false,true }, 	url = "Fallen+Empires"},
[160]={id = 160,	lang = { true , 	[9]=false }, 	fruc = { false,true }, 	url = "The+Dark"},
[150]={id = 150,	lang = { true , 	[9]=false }, 	fruc = { false,true }, 	url = "Legends"},
[130]={id = 130,	lang = { true , 	[9]=false }, 	fruc = { false,true }, 	url = "Antiquities"},
[120]={id = 120,	lang = { true , 	[9]=false }, 	fruc = { false,true }, 	url = "Arabian+Nights"},
-- TODO add special and promo sets
} -- end table site.sets

--[[- card name replacement tables.
-- { #number = #table { #string = #string } }
-- 
--- @field [parent=#site] #table namereplace ]]
--- @field [parent=#site] #table namereplace
site.namereplace = {
[759] = { -- M2010
["Runeclaw Bears"] 						= "Runeclaw Bear",
},
[720] = { -- 10th Edition
["Wall of Sword"]						= "Wall of Swords",
},
[460] = { -- 7th Edition
["Tainted Æther"]						= "Tainted Aether"
},
[250] = { -- 5th Edition
--["Dandân"]								= "Dandan",
["Ghazban Ogre"]						= "Ghazbán Ogre"
},
[180] = { -- 4th Edition
["Junun Efreet"]						= "Junún Efreet",
},
[140] = { -- Revised Edition
["El-Hajjâj"]							= "El-Hajjaj",
},
[795] = { -- Dragon's Maze
["Ætherling (Aetherling)"]				= "Ætherling",
["Breaking | Entering"]					= "Breaking|Entering"
},
[793] = { -- Gatecrash
["AEtherize"]							= "Ætherize",
},
[786] = { -- Avacyn Restored
["Favourable Winds"]					= "Favorable Winds",
},
[782] = { -- Innistrad
["Double-Sided Card Checklist"]			= "Checklist",
["Curse of the Nightly Haunt"]			= "Curse of the Nightly Hunt",
["Alter's Reap"] 						= "Altar's Reap",
["Elder Cather"] 						= "Elder Cathar",
["Moldgraft Monstrosity"] 				= "Moldgraf Monstrosity",
},
[784] = { -- Dark Ascension
["Soul Seizer |Ghastly Haunting"] 		= "Soul Seizer|Ghastly Haunting",
["Hunger of the Wolfpack"]				= "Hunger of the Howlpack"
},
[776] = { -- New Phyrexia
["Urabrask, the Hidden"]				= "Urabrask the Hidden"
},
[775] = { -- Mirrodin Besieged
["Gust Skimmer"]						= "Gust-Skimmer"
},
[773] = { --Scars of Mirrodin
["Vulshok Heartstroker"]				= "Vulshok Heartstoker"
},
[690] = { -- Time Spiral Timeshifted
["DANDÂN"]								= "Dandân"
},
[680] = { -- Time Spiral
["Lim-Dul the Necromancer"]				= "Lim-Dûl the Necromancer"
},
[710] = { -- Future Sight
["Vedalken Æthermage"]					= "Vedalken Aethermage"
},
[700] = { -- Planar Chaos
["Frozen Æther"]						= "Frozen Aether"
},
[670] = { -- Coldsnap
["Surging Æther"]						= "Surging Aether",
["Jotun Owl Keeper"]					= "Jötun Owl Keeper",
["Jotun Grunt"]						= "Jötun Grunt"
},
[660] = { -- Dissension
["Azorius Æthermage"]					= "Azorius Aethermage"
},
[620] = { -- Saviors of Kamigawa
["Sasaya, Orochi Ascendant"] 			= "Sasaya, Orochi Ascendant|Sasaya’s Essence",
["Rune-Tail, Kitsune Ascendant"] 		= "Rune-Tail, Kitsune Ascendant|Rune-Tail’s Essence",
["Homura, Human Ascendant"] 			= "Homura, Human Ascendant|Homura’s Essence",
["Kuon, Ogre Ascendant"] 				= "Kuon, Ogre Ascendant|Kuon’s Essence",
["Erayo, Soratami Ascendant"] 			= "Erayo, Soratami Ascendant|Erayo’s Essence"
},
[610] = { -- Betrayers of Kamigawa
["Hired Muscle"] 						= "Hired Muscle|Scarmaker",
["Cunning Bandit"] 						= "Cunning Bandit|Azamuki, Treachery Incarnate",
["Callow Jushi"] 						= "Callow Jushi|Jaraku the Interloper",
["Faithful Squire"] 					= "Faithful Squire|Kaiso, Memory of Loyalty",
["Budoka Pupil"] 						= "Budoka Pupil|Ichiga, Who Topples Oaks"
},
[590] = { -- Champions of Kamigawa
["Student of Elements"]					= "Student of Elements|Tobita, Master of Winds",
["Kitsune Mystic"]						= "Kitsune Mystic|Autumn-Tail, Kitsune Sage",
["Initiate of Blood"]					= "Initiate of Blood|Goka the Unjust",
["Bushi Tenderfoot"]					= "Bushi Tenderfoot|Kenzo the Hardhearted",
["Budoka Gardener"]						= "Budoka Gardener|Dokai, Weaver of Life",
["Nezumi Shortfang"]					= "Nezumi Shortfang|Stabwhisker the Odious",
["Jushi Apprentice"]					= "Jushi Apprentice|Tomoya the Revealer",
["Orochi Eggwatcher"]					= "Orochi Eggwatcher|Shidako, Broodmistress",
["Nezumi Graverobber"]					= "Nezumi Graverobber|Nighteyes the Desecrator",
["Akki Lavarunner"]						= "Akki Lavarunner|Tok-Tok, Volcano Born"
},
[580] = { -- Fifth Dawn
["Fold into Æther"]						= "Fold into Aether"
},
[560] = { -- Urza's Saga
["Gate to the Æther"]					= "Gate to the Aether"
},
[470] = { -- Apocalypse
["Fire-Ice"] 							= "Fire|Ice",
},
[330] = { -- Urza's Saga
["Tainted Æther"]						= "Tainted Aether"
},
[270] = { -- Weatherlight
["Bosium Strip"]						= "Bösium Strip"
},
[220] = { -- Alliances
["Lim-Dul's High Guard"]				= "Lim-Dûl's High Guard"
},
[190] = { -- Ice Age
["Lim-Dul's Cohort"] 					= "Lim-Dûl’s Cohort",
["Marton Stromgald"] 					= "Márton Stromgald",
["Lim-Dul's Hex"]						= "Lim-Dûl’s Hex",
["Legions of Lim-Dul"]					= "Legions of Lim-Dûl",
["Oath of Lim-Dul"]						= "Oath of Lim-Dûl",
},
[120] = { -- Arabian Nights
["Junun Efreet"] 						= "Junún Efreet",
["El-Hajjâj"]							= "El-Hajjaj",
["Dandân"]								= "Dandan",
["Ifh-Biff Efreet"]						= "Ifh-Bíff Efreet",
["Ring of Ma'ruf"]						= "Ring of Ma ruf",
}
} -- end table site.namereplace

--[[- card variant tables.
-- tables of cards that need to set variant.
-- For each setid, if unset uses sensible defaults from LHpi.sets.variants.
-- Note that you need to replicate the default values for the whole setid here, 
-- even if you set only a single card from the set differently.

-- { #number = #table { #string = #table { #string, #table { #number or #boolean , ... } } , ... } , ...  }
-- [0] = { -- Basic Lands as example (setid 0 is not used)
-- ["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
-- ["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
-- ["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
-- ["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
-- ["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } }
-- },
-- 
--- @field [parent=#site] #table variants ]]
--- @field [parent=#site] #table variants
site.variants = {
} -- end table site.variants

--[[- foil status replacement tables
-- { #number = #table { #string = #table { #boolean foil } } }
-- 
--- @field [parent=#site] #table foiltweak ]]
--- @field [parent=#site] #table foiltweak
site.foiltweak = {
[766] = { -- Phyrexia VS Coalition
 	["Phyrexian Negator"] 	= { foil = true },
	["Urza's Rage"] 		= { foil = true }
},
} -- end table foiltweak

if CHECKEXPECTED then
--[[- table of expected results.
-- as of script release
-- { #number = #table { #table pset = #table { #number = #number, ... }, #table failed = #table { #number = #number, ... }, 	dropped = #number ,	namereplaced = #number }
-- 
--- @field [parent=#site] #table expected ]]
--- @field [parent=#site] #table expected
site.expected = {
-- Core sets
[779] = { pset={ [9]=249+1 } },--why +1?
[770] = { dropped=1 },
[759] = { pset={ [9]=249-20 }, dropped=8, namereplaced=4 },
[720] = { pset={ [9]=383-20, [9]=383-20 }, dropped=4, namereplaced=2 },
[630] = { pset={ 359-31, [9]=0 } },
[550] = { pset={ 357-27, [9]=0 } },
[460] = { pset={ 350-20, [9]=0 }, failed={ [9]=125 }, dropped=3, namereplaced=1 },
[360] = { pset={ 350-20 }, dropped=20 },
[250] = { pset={ 449-20 }, dropped=52, namereplaced=1 },
[180] = { pset={ 378-15, [9]=0 }, dropped=96, namereplaced=1 },
[140] = { pset={ 306-15, [9]=0 }, dropped=41, namereplaced=1 },
[110] = { dropped=4 },
[100] = { pset={ 302-19 } },
-- Expansions
[795] = { namereplaced=7 },
[793] = { pset={ [9]=249-1 }, failed={ [9]=1 }, namereplaced=4 },
[786] = { pset={ [9]=244+1 }, namereplaced=2 },-- why +1?
[784] = { namereplaced=5 },
[782] = { pset={ 264+1 }, namereplaced=12 },
[776] = { namereplaced=4 },
[775] = { namereplaced=3 },
[773] = { namereplaced=2 },
[762] = { pset={ 269-20,[9]=269-20 }, dropped=1 },
[751] = { pset={ [9]=301-20 } },
[730] = { pset={ 301-1, [9]=301-1 }, dropped=2 },
[710] = { dropped=2, namereplaced=2 },
[700] = { dropped=1, namereplaced=2 },
[690] = { pset={ [9]=0 }, dropped=1, namereplaced=2 },
[680] = { pset={ [9]=4 }, dropped=2, namereplaced=2 },
[670] = { pset={ [9]=0 }, namereplaced=6 },
[660] = { pset={ [9]=0 }, dropped=2, namereplaced=2 },
[650] = { pset={ [9]=0 } },
[640] = { pset={ [9]=0 }, dropped=2 },
[620] = { pset={ [9]=0 }, dropped=1, namereplaced=6 },
[610] = { pset={ [9]=0 }, dropped=2, namereplaced=10 },
[590] = { pset={ [9]=0 }, namereplaced=20 },
[580] = { pset={ [9]=110 }, dropped=2, namereplaced=2 },
[570] = { pset={ [9]=0 }, dropped=2 },
[560] = { pset={ 306-20, [9]=0 }, dropped=4, namereplaced=2 },
[540] = { pset={ [9]=0 }, dropped=3 },
[530] = { pset={ [9]=0 }, failed={ [9]=96 }, dropped=2 },
[520] = { pset={ [9]=0 }, dropped=9 },
[510] = { pset={ [9]=0 }, failed={ [9]=143 }, 	dropped=17 },
[500] = { pset={ [9]=0 }, failed={ [9]=40 }, 	dropped=8 },
[480] = { pset={ 350-20, [9]=0 }, failed={ [9]=166 }, 	dropped=36 },
[470] = { pset={ [9]=0 }, dropped=4, namereplaced=1 },
[450] = { pset={ 146-3, [9]=0 }, dropped=24 },
[430] = { pset={ 350-20, [9]=0 }, failed={ [9]=144 }, 	dropped=104 },
[420] = { pset={ 143-60, [9]=0 }, dropped=8 },
[410] = { pset={ 143-1, [9]=0 }, dropped=13 },
[400] = { pset={ 350-20, [9]=0 }, dropped=15 },
[370] = { pset={ [9]=0 }, dropped=15 },
[350] = { pset={ [9]=0 }, dropped=11 },
[330] = { pset={ 350-20, [9]=0 }, dropped=38, namereplaced=1 },
[300] = { pset={ [9]=0 }, dropped=12 },
[290] = { pset={ [9]=0 }, dropped=28 },
[280] = { pset={ 350-20, [9]=0 }, dropped=64 },
[270] = { pset={ [9]=0 }, dropped=9, namereplaced=1 },
[240] = { pset={ [9]=0 }, dropped=12 },
[230] = { pset={ 350-21, [9]=0 }, dropped=80 },
[220] = { pset={ [9]=0 }, dropped=12, namereplaced=1 },
[210] = { pset={ [9]=0 }, dropped=7 },
[190] = { pset={ 383-15, [9]=0 }, dropped=92, namereplaced=5 },
[170] = { dropped=20 },
[160] = { dropped=9 },
[150] = { dropped=23 },
[130] = { dropped=7 },
[120] = { dropped=15, namereplaced=5 },
}
end
