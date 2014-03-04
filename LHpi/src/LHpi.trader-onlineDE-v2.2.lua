--*- coding: utf-8 -*-
--[[- LHpi trader-online.de sitescript 
Price import script for Magic Album
uses and needs LHpi library
to import card pricing from www.trader-online.de.

Inspired by and loosely based on "MTG Mint Card.lua" by Goblin Hero, Stromglad1 and "Import Prices.lua" by woogerboy21;
who generously granted permission to "do as I like" with their code;
everything else Copyright (C) 2012-2013 by Christian Harms.
If you want to contact me about the script, try its release thread in http://www.slightlymagic.net/forum/viewforum.php?f=32

@module LHpi_magicuniverseDE
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
initial release
]]

-- options that control the amount of feedback/logging done by the script
--- @field [parent=#global] #boolean VERBOSE 			default false
VERBOSE = false
--- @field [parent=#global] #boolean LOGDROPS 			default false
LOGDROPS = false
--- @field [parent=#global] #boolean LOGNAMEREPLACE 	default false
LOGNAMEREPLACE = false

-- options that control the script's behaviour.
--- compare card count with expected numbers; default true
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
--- must always be equal to the scripts filename !
-- @field [parent=#global] #string scriptname	
scriptname = "LHpi.trader-onlineDE-v2.1.lua" 

--- revision of the LHpi library to use
-- @field [parent=#global] #string libver
libver = "2.1"
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
site.regex = '<tr><td colspan="11"><hr noshade size=1></td></tr>\n%s*<tr>\n%s*(.-)</font></td>\n%s*<td width'
site.encoding="cp1252"
--site.encoding="utf-8"
site.currency = "€"
site.resultregex = "Es wurden <b>(%d+)</b> Artikel"

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
	site.domain = "www.trader-online.de/"
	if frucid == 1 then
		site.frucfileprefix = "foil"
	else
		site.frucfileprefix= "magic"
	end
	site.file = "-search.php?"
	site.setprefix = "serie="
	local container = {}

	local seturl = site.sets[setid].url
	if langid == 3 then
		if setid == 220 then
	 		seturl = "Allianzen"
	 	elseif setid == 520 then
	 		seturl = "Aufmarsch"
		end
	elseif langid == 5 then
		seturl = "i" .. string.gsub( seturl, "%%20", "" )
	end
	local url = site.frucfileprefix .. site.file .. site.setprefix .. site.frucs[frucid] .. "-" .. seturl .. site.langs[langid].url
	if offline then
		url = savepath .. string.gsub( url, "%?", "_" )  .. ".html"
		container[url] = { isfile = true}
	else
		url = "http://" .. site.domain .. url
		container[url] = {}
	end -- if offline 
	
	if frucid == 1 then -- mark url as foil-only
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
 @param #table urldetails	{ foilonly = #boolean , isfile = #boolean , setid = #number, langid = #number, frucid = #number }
 @return #table { names = #table { #number = #string, ... }, price = #table { #number = #string, ... }} 
]]
function site.ParseHtmlData( foundstring , urldetails )
	local newCard = { names = {} , price = {} }
	local _s,_e,name  = string.find( foundstring, '\n%s*<td width="415"><p><div id="st12">([^<]+)</div></p>' )
	local _s,_e,price = string.find( foundstring, '\n%s*<td width="60".+color="#990000"><b>([%d.,]+)%s*</b>' )
	local _s,_e,fruc  = string.find( foundstring, '\n%s*<td width="25">%b<>([^<]+) +%b<></td>' )
	local _s,_e,set   = string.find( foundstring, '\n%s*<td width="50">%b<>([^<]+) +%b<></td>' )
	if name then -- prevent errors on nil, will be dropped later
		name = string.gsub( name , ", %d+x[%l ]+verf.gbar$" , "" )
		name = string.gsub( name , " %(%d+ Stk%)$" , "" )
		name = string.gsub( name , " %(%d+ Motive verf.gbar%)$" , "" )
		if urldetails.foilonly then 
			local _s,_e,nametoo = string.find( name , " %((.-)%)" )
			name = string.gsub( name , " %(.-%)" , "" )
		end
	end
	newCard.names[urldetails.langid] = name
	if price then -- prevent errors on nil
		price = string.gsub(price , "[,.]" , "" )
		price= tonumber( price )
	end
	newCard.price[urldetails.langid] = price
	newCard.pluginData = { fruc=fruc, set=set }
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
	if setid == 640 then
		name = string.gsub ( name , "^GebirgeNr" , "Gebirge Nr" )
	end
	if setid == 150 or setid == 160 then
		-- check Legends and The Dark for "ital." suffix
		name = string.gsub( name, ", ital%.$" , "" )
	end

	name = string.gsub( name , "Spielstein" , "Token" )
	
	-- mark condition modifier suffixed cards to be dropped
	name = string.gsub( name , ", light played$" , "%0 (DROP)" )
	name = string.gsub( name , ", gespielt$" , "%0 (DROP)" )
	name = string.gsub( name , " NM%-EX$" , "%0 (DROP)" )
	
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
	if setid == 690 then -- Timeshifted
		if not (card.pluginData.fruc == "T") then
			card.name = card.name .. "(DROP Time Spiral)"
			card.drop = true		
		end
	elseif setid == 680 then -- Time Spiral
		if card.pluginData.fruc == "T" then
			card.name = card.name .. "(DROP Timeshifted)"
			card.drop = true		
		end
	end

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
	[1] = {id=1, full = "English", 	abbr="ENG", url="-E" },
	[3] = {id=3, full = "German", 	abbr="GER", url="-D" },
	[5] = {id=5, full = "Italian", 	abbr="ITA", url="-E" },
}

--- @field [parent=#site] #table frucs	rarity array { #number = #string }
site.frucs = { "Foil" , "Serie" }

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
[788]={id = 788,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "M13"}, 
[779]={id = 779,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "M12"}, 
[770]={id = 770,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "M11"}, 
[759]={id = 759,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "M10"}, 
[720]={id = 720,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "10th"}, 
[630]={id = 630,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "9th"}, 
[550]={id = 550,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "8th"}, 
[460]={id = 460,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "7th"}, 
[360]={id = 360,	lang = { true , 	[3]=true }, 	fruc = { false,true }, 	url = "6th"},
[250]={id = 250,	lang = { true , 	[3]=true }, 	fruc = { false,true }, 	url = "5th"},
[180]={id = 180,	lang = { true , 	[3]=true }, 	fruc = { false,true }, 	url = "4th"}, 
[140]={id = 140,	lang = { true , 	[3]=true }, 	fruc = { false,true }, 	url = "RV"},
[139]={id = 139,	lang = { false, 	[3]=true  },	fruc = { false,true },	url = "DL"}, -- deutsch limitiert
[110]={id = 110,	lang = { true , 	[3]=false }, 	fruc = { false,true }, 	url = "UN"},  
[100]={id = 100,	lang = { true , 	[3]=false }, 	fruc = { false,true }, 	url = "B%20"},
[90] = nil, -- Alpha 
 -- Expansions
[793]={id = 793,	lang = { true , 	[3]=true }, 	fruc = { true, true }, 	url = "GTC"},
[791]={id = 791, 	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "RTR"},
[786]={id = 786,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "AVR"},
[784]={id = 784,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "DKA"}, 
[776]={id = 776,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "NPH"},
[782]={id = 782,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "INN"}, 
[775]={id = 775,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "MBS"},
[773]={id = 773,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "SOM"},
[767]={id = 767,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "ROE"},
[765]={id = 765,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "WWK"},
[762]={id = 762,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "ZEN"},
[758]={id = 758,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "ARB"},
[756]={id = 756,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "CON"},
[754]={id = 754,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "Alara"},
[752]={id = 752,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "EVE"},
[751]={id = 751,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "SHM"},
[750]={id = 750,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "MOR"},
[730]={id = 730,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "LOR"},
[710]={id = 710,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "FS"},
[700]={id = 700,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "PLC"},
[690]={id = 690,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "TS"},
[680]={id = 680,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "TS"},
[670]={id = 670,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "CS"},
[660]={id = 660,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "DIS"},
[650]={id = 650,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "GP"},
[640]={id = 640,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "RAV"},
[620]={id = 620,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "SK"},
[610]={id = 610,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "BK"},
[590]={id = 590,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "CK"},
[580]={id = 580,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "FD"},
[570]={id = 570,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "DS"},
[560]={id = 560,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "MD"},
[540]={id = 540,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "SC"},
[530]={id = 530,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "LE"},
[520]={id = 520,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "Onslaught"},
[510]={id = 510,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "JD"},
[500]={id = 500,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "TO"},
[480]={id = 480,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "OD"},
[470]={id = 470,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "AP"},
[450]={id = 450,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "PL%20"},
[430]={id = 430,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "Invasion"},
[420]={id = 420,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "PR"},
[410]={id = 410,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "NE"},
[400]={id = 400,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "MM"},
[370]={id = 370,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "UD"},
[350]={id = 350,	lang = { true , 	[3]=true }, 	fruc = { true ,true }, 	url = "UL"},
[330]={id = 330,	lang = { true , 	[3]=true }, 	fruc = { false,true }, 	url = "US"},
[300]={id = 300,	lang = { true , 	[3]=true }, 	fruc = { false,true }, 	url = "EX"},
[290]={id = 290,	lang = { true , 	[3]=true }, 	fruc = { false,true }, 	url = "SH"},
[280]={id = 280,	lang = { true , 	[3]=true }, 	fruc = { false,true }, 	url = "TP"},
[270]={id = 270,	lang = { true , 	[3]=true }, 	fruc = { false,true }, 	url = "WL"},
[240]={id = 240,	lang = { true , 	[3]=true }, 	fruc = { false,true }, 	url = "VI"},
[230]={id = 230,	lang = { true , 	[3]=true }, 	fruc = { false,true }, 	url = "MI"},
[220]={id = 220,	lang = { true , 	[3]=true }, 	fruc = { false,true }, 	url = "Alliances"},
[210]={id = 210,	lang = { true , 	[3]=true }, 	fruc = { false,true }, 	url = "HL"},
[190]={id = 190,	lang = { true , 	[3]=true }, 	fruc = { false,true }, 	url = "IA"},
[170]={id = 170,	lang = { true , 	[3]=false }, 	fruc = { false,true }, 	url = "FE"},
[160]={id = 160,	lang = { true , [3]=false,[5]=true }, 	fruc = { false,true }, 	url = "DK%20"},
[150]={id = 150,	lang = { true , [3]=false,[5]=true }, 	fruc = { false,true }, 	url = "LG%20"},
[130]={id = 130,	lang = { true , 	[3]=false }, 	fruc = { false,true }, 	url = "AQ"},
[120]={id = 120,	lang = { true , 	[3]=false }, 	fruc = { false,true }, 	url = "AN"},
-- special sets
[600]={id = 600,	lang = { true ,		[3]=false },	fruc = { true ,true } ,	url = "UH"}, -- Unhinged
[320]={id = 320,	lang = { true ,		[3]=false },	fruc = { false,true } ,	url = "UG"}, -- Unglued
[310]={id = 310,	lang = { true ,		[3]=true  },	fruc = { false,true } ,	url = "PT2"}, -- Portal Second Age
[260]={id = 260,	lang = { true ,		[3]=true  },	fruc = { false,true } ,	url = "PT1"}, -- Portal
[201]={id = 201,	lang = { false ,	[3]=true  },	fruc = { false,true } ,	url = "REN"}, -- Renaissance 
[200]={id = 200,	lang = { true ,		[3]=false },	fruc = { false,true } ,	url = "CH"}, -- Chronicles
} -- end table site.sets

--[[- card name replacement tables.
-- { #number = #table { #string = #string } }
-- 
--- @field [parent=#site] #table namereplace ]]
--- @field [parent=#site] #table namereplace
site.namereplace = {
[770] = { -- M11
["Zyklop -Gladiator"]					= "Zyklop-Gladiator",
["Token - Schlammwesen (Token)"]		= "Ooze",
["Token - Ooze (1/1)"]					= "Ooze (6)",
["Token - Ooze (2/2)"]					= "Ooze (5)",
},
[720] = { -- 10th
["Elite-Infantrie der Goblins"] 		= "Elite-Infanterie der Goblins",
["Nachleuten"]							= "Nachleuchten",
},
[630] = { -- 9th
["Bewußtseinserweiterung"]				= "Bewusstseinserweiterung",
},
[550] = { -- 8th
["Gemeinsames Bewußtsein"] 				= "Gemeinsames Bewusstsein",
["Drudge Skeleton"]						= "Drudge Skeletons",
["Bewußtseinserweiterung"]				= "Bewusstseinserweiterung",
["Sternenkompaß"]						= "Sternenkompass",
["Staunch Defender"]					= "Staunch Defenders",
},
[460] = { -- 7th
["Baumvolksprößlinge"]					= "Baumvolksprösslinge",
["Flußpferdbulle"]						= "Flusspferdbulle",
["Ausschluß"]							= "Ausschluss",
["Phyrexianischer Koloß"]				= "Phyrexianischer Koloss",
["Dornenelementar (273)"]				= "Dornenelementar",
},
[360] = { -- 6th
["Zwiespaltszepter"]					= "Zwiespaltsszepter",
["Hammer von Bogardan (Hammer aus Bogardan)"]	= "Hammer von Bogardan",
["Zwang (engl. Coercion)"]				= "Zwang",
["Stein der Sanftmut"]					= "Stein des Sanftmuts"
},
[250] = { -- 5th
["Ghazbanoger"]							= "Ghazbánoger",
["Dandan"]								= "Dandân"
},
[180] = { -- 4th
["Junun Ifrit"]							= "Jun´un Ifrit",
["Junun Efreet"]						= "Junún Efreet",
["Stein des Sanftmuts"]					= "Stein der Sanftmut",
["El-Hajjaj"]							= "El-Hajjâj",
},
[140] = { -- Revised
["Will-O-The-Wisp"] 					= "Will-O’-The-Wisp",
["Kird der Menschenaffe"]				= "Kird, der Menschenaffe",
["Verformtes Artefakt|El-Hajjaj (Fehldruck)"]	= "Verformtes Artefakt",
["Schilftroll|Manahaken (Fehldruck)"] 	= "Schilftroll",
["Mons' plündernde Goblins"]			= "Mons's plündernde Goblins",
["El-Hajjaj"]							= "El-Hajjâj",
},
[139] = { -- Revised Limited (german)
["Greif Roc aus dem Kehrgebirge"] 		= "Greif Roc aus dem Khergebrige",
["El-Hajjaj"]							= "El-Hajjâj",
},
[110] = { -- Unlimited
["Will-O-The-Wisp"] 					= "Will-O’-The-Wisp" 
},
-- Expansions
[793] = { -- Gatecrash
["Aetherize"]							= "Ætherize",
},
[786] = { -- Avacyn Restored
["Token - Human (Token)"]				= "Human",
["Token - Spirit (Token)"]				= "Spirit",
["Token - Mensch (Token)"]				= "Mensch",
["Token - Geist (Token)"]				= "Geist",
},
[784] = { -- Dark Ascension
["Mondrenner-Schamanin|Trovolars Zauberjägerin"]	= "Mondrenner-Schamanin|Tovolars Zauberjägerin",
["Checklist Card Dark Ascension"]		= "Checklist",
["Checklisten-Karte Dunkles Erwachen"]	= "Checklist",
["Séance)"]								= "Séance",
["Séance (Seance)"]						= "Séance",
["Elbrus, die bindende Klinge|Withengar der Entfesselte (Elbrus, the Binding Blade|Withengar Unbou"] = "Elbrus, die bindende Klinge|Withengar der Entfesselte"
},
[782] = { -- Innistrad
["Ludevic's Test Subject|Ludevic's Abomniation"] = "Ludevic's Test Subject|Ludevic's Abomination",
["Token - Wolf"]						= "Wolf",
["Token - Zombie"]						= "Zombie",
["Checklist Card Innistrad"]			= "Checklist",
["Checklisten-Karte Innistrad"]			= "Checklist",
["Token - Wolf (Token)"]				= "Wolf",
["Token - Zombie (Token)"]				= "Zombie",
},
[773] = { -- Scars of Mirrodin
["Token - Poison Counter"]				= "Poison Counter",
["Token - Giftmarke (Token)"]			= "Poison Counter",
["Token - Wurm (Deathtouch)"]			= "Wurm (8)",
["Token - Wurm (Lifelink)"]				= "Wurm (9)",
["Token - Wurm (Token|Todesberührung)"]	= "Wurm (8)",
["Token - Wurm (Token|Lebensverknüpfung)"]= "Wurm (9)",
},
[767] = { -- Rise of the Eldrazi
["Swamp (2340)"]						= "Swamp (240)",
["Token - Eldrazi Spawn"]				= "Eldrazi Spawn",
["Token - Eldrazi, Ausgeburt (Token)"]	= "Eldrazi, Ausgeburt",
},
[765] = { -- Worldwake
["Elefant"]								= "Elefant ",
},
[762] = { -- Zendikar
["Meervolk"]							= "Meervolk ",
["Vampir"]								= "Vampir ",
},
[754] = { -- Shards of Alara
["Macht des Seele (Macht der Seele)"]	= "Macht des Seele",
["Soul's Might)"]						= "Soul's Might",
["Blasenkäpfer"]						= "Blasenkäfer",
},
[751] = { -- Shadowmoor
["Mühsam erkämpfter Rum"]				= "Mühsam erkämpfter Ruhm",
["Token - Elemental"]					= "Elemental",
["Token - Elf Warrior"]					= "Elf Warrior",
["Token - Elementarwesen (Token)"]		= "Elementarwesen",
["Token - Elf, Krieger (Token)"]		= "Elf, Krieger",
},
[730] = { -- Lorwyn
["Token - Elementarwesen (Token)"]		= "Elementarwesen",
["Token - Elemental"]					= "Elemental",
},
[710] = { -- Future Sight
["Tarmogoyf, englisch"]					= "Tarmogoyf",
["Tarmogoyf, deutsch"]					= "Tarmogoyf",
},
[690] = { -- Timeshifted
["Sindbad, der Seefahrer"]				= "Sindbad der Seefahrer",
["Dandan"]								= "Dandân"
},
[680] = { -- Time Spiral
["Lim-Dul the Necromancer"]				= "Lim-Dûl the Necromancer"
},
[670] = { -- Coldsnap
["Gaza Zol, Seuchenkönigin"]			= "Garza Zol, Seuchenkönigin",
["Nachleuten"]							= "Nachleuchten",
},
[650] = { -- Guildpact
["Parallelektrische Rückkoppelung"]		= "Parallelektrische Rückkopplung",
},
[620] = { -- Saviors of Kamigawa
["Erayo, Soratami Ascendant"] 			= "Erayo, Soratami Ascendant|Erayo’s Essence",
	["Erayo, Vorfahr der Soratami"] 	= "Erayo, Vorfahr der Soratami|Erayos Substanz",
["Homura, Human Ascendant"] 			= "Homura, Human Ascendant|Homura’s Essence",
	["Homura, Vorfahr der Menschen"] 	= "Homura, Vorfahr der Menschen|Homuras Substanz",
["Kuon, Ogre Ascendant"] 				= "Kuon, Ogre Ascendant|Kuon’s Essence",
	["Kuon, Vorfahr der Oger"] 			= "Kuon, Vorfahr der Oger|Kuons Substanz",
["Rune-Tail, Kitsune Ascendant"] 		= "Rune-Tail, Kitsune Ascendant|Rune-Tail’s Essence",
	["Runenschwanz, Vorfahr der Kitsune"]	= "Runenschwanz, Vorfahr der Kitsune|Runenenschwanz’ Substanz",
["Sasaya, Orochi Ascendant"] 			= "Sasaya, Orochi Ascendant|Sasaya’s Essence",
	["Sasaya, Vorfahr der Orochi"] 		= "Sasaya, Vorfahr der Orochi|Sasayas Substanz",
},
[610] = { -- Betrayers of Kamigawa
["Budoka Pupil"] 						= "Budoka Pupil|Ichiga, Who Topples Oaks",
	["Budokaschüler"] 					= "Budokaschüler|Ichiga, der Eichen umwirft",
["Callow Jushi"] 						= "Callow Jushi|Jaraku the Interloper",
	["Unerfahrener Jushi"] 				= "Unerfahrener Jushi|Jaraku, der Eindringling",
["Cunning Bandit"] 						= "Cunning Bandit|Azamuki, Treachery Incarnate",
	["Listiger Bandit"] 				= "Listiger Bandit|Azamuki, Inbegriff des Verrats",
["Faithful Squire"] 					= "Faithful Squire|Kaiso, Memory of Loyalty",
	["Gläubiger Junker"] 				= "Gläubiger Junker|Kaiso, Erinnerung der Treue",
["Hired Muscle"] 						= "Hired Muscle|Scarmaker",
	["Angeheuerter Muskelprotz"] 		= "Angeheuerter Muskelprotz|Narbenmacher",
["Ninja der späten Stunde"] 			= "Ninja der späten Stunden",
},
[590] = { -- Champions of Kamigawa
["Akki Lavarunner"]						= "Akki Lavarunner|Tok-Tok, Volcano Born",
	["Akki-Lavaläufer"]					= "Akki-Lavaläufer|Tok-Tok der Vulkangeborene",
["Bushi Tenderfoot"]					= "Bushi Tenderfoot|Kenzo the Hardhearted",
	["Bushi-Grünschnabel"]				= "Bushi-Grünschnabel|Kenzo der Hartherzige",
["Budoka Gardener"]						= "Budoka Gardener|Dokai, Weaver of Life",
	["Budoka-Gärtner"]					= "Budoka-Gärtner|Dokai, Weber des Lebens",
["Initiate of Blood"]					= "Initiate of Blood|Goka the Unjust",
	["Novize des Blutes"]				= "Novize des Blutes|Goka der Ungerechte",
["Jushi Apprentice"]					= "Jushi Apprentice|Tomoya the Revealer",
	["Jushi-Lehrling"]					= "Jushi-Lehrling|Tomoya der Enthüller",
["Kitsune Mystic"]						= "Kitsune Mystic|Autumn-Tail, Kitsune Sage",
	["Kitsune-Mystiker"]				= "Kitsune-Mystiker|Herbstschwanz, Weiser Kitsune",
["Nezumi Graverobber"]					= "Nezumi Graverobber|Nighteyes the Desecrator",
	["Nezumi-Grabräuber"]				= "Nezumi-Grabräuber|Nachtauge der Schänder",
["Nezumi Shortfang"]					= "Nezumi Shortfang|Stabwhisker the Odious",
	["Nezumi-Kurzzahn"]					= "Nezumi-Kurzzahn|Dolchbart der Widerliche",
["Orochi Eggwatcher"]					= "Orochi Eggwatcher|Shidako, Broodmistress",
	["Orochi-Eierbewacherin"]			= "Orochi-Eierbewacherin|Shidako, Brutmeisterin",
["Student of Elements"]					= "Student of Elements|Tobita, Master of Winds",
	["Student der Elemente"]			= "Student der Elemente|Tobita, Meister der Winde",
--["Brothers Yamazaki"]					= "Brothers Yamazaki (a)",
["Brothers Yamazaki (1)"]				= "Brothers Yamazaki (a)",
["Brothers Yamazaki (2)"]				= "Brothers Yamazaki (b)",
--["Yamazaki-Brüder"]						= "Yamazaki-Brüder (a)",
["Yamazaki-Brüder (1)"]					= "Yamazaki-Brüder (a)",
["Yamazaki-Brüder (2)"]					= "Yamazaki-Brüder (b)",
["Aura der Oberschaft"]					= "Aura der Oberherrschaft",
["Spährenweber-Kumo"]					= "Sphärenweber-Kumo",
["Honor-worn Shaku"]					= "Honor-Worn Shaku",
},
[580] = { -- Fifth Dawn
["Virdischer Späher"]					= "Viridischer Späher",
["Virdische Sagenbewahrer"]				= "Viridische Sagenbewahrer",
},
[530] = { -- Legions
["Brüllender Blutsiedler"]				= "Brüllender Blutsieder",
},
[290] = { -- Stronghold
["Engel des Krieges"]					= "Engel des Kriegers",
},
[270] = { -- Weatherlight
["Benalische Infantrie"]				= "Benalische Infanterie",
["Reißzahnratte"]						= "Reißzahnratten",
},
[220] = { -- Alliances
["Insidious Bookworm"]					= "Insidious Bookworms",
["Gorilla Chieftan"]					= "Gorilla Chieftain",
["Lim-Duls Gruft"]						= "Lim-Dûls Gruft",
["Ahnen aus dem Yavimaya"]				= "Ahnen aus Yavimaya",
["Lim-Duls Paladin"]					= "Lim-Dûls Paladin",
},
[190] = { -- Ice Age
["Lim-Dul's Hex"]						= "Lim-Dûl's Hex",
["Lim-Dul's Cohort"]					= "Lim-Dûl's Cohort",
["Legions of Lim-Dul"]					= "Legions of Lim-Dûl",
["Oath of Lim-Dul"]						= "Oath of Lim-Dûl",
},
[160] = { -- The Dark
["Elves of Deep Shadows"]				= "Elves of Deep Shadow",
},
[120] = { -- Arabian Nights
["Junun Efreet"]						= "Junún Efreet",
["Ifh-Biff Efreet"]						= "Ifh-Bíff Efreet",
["Ring of Ma'ruf"]						= "Ring of Ma ruf",
},
-- specal sets
[600] = { -- Unhinged
["First Come First Served"]				= "First Come, First Served",
["Our Market Research Shows ..."]		= "Our Market Research Shows That Players Like Really Long Card Names So We Made this Card to Have the Absolute Longest Card Name Ever Elemental",
["Erase"]								= "Erase (Not the Urza’s Legacy One)",
["Who|What/When|Where/Why"]				= "Who|What|When|Where|Why",
},
[320] = { -- Unglued
["B.F.M. (Big Furry Monster) links"]	= "B.F.M. (left)",
["B.F.M. (Big Furry Monster) rechts"]	= "B.F.M. (right)",
["Bronze Calender"]						= "Bronze Calendar",
["Burning Cinder Fury o. C.C.F."]		= "Burning Cinder Fury of Crimson Chaos Fire",
["Gobin Bookie"]						= "Goblin Bookie",
["The Ultimate Nightmare ..."]			= "The Ultimate Nightmare of Wizards of the Coast® Customer Service",
},
[310] = { -- Portal Second Age
["Deja Vu"]								= "Déjà Vu",
},
[260] = { -- Portal
["Deja Vu"]								= "Déjà Vu",
["Furcheinflößender Ansturm"]			= "Furchteinflößender Ansturm",
["Plündernde Horde"]					= "Plündernde Horden",
},
[201] = { -- Renaissance
--["Der Koloß von Sardia"]				= "Der Koloss von Sardia",
["Schutzkreis geg. Artefakte"]			= "Schutzkreis gegen Artefakte",
},
[200] = { -- Chronicles
["Dandan"]								= "Dandân",
["Ghazban Ogre"]						= "Ghazbán Ogre",
},
} -- end table site.namereplace

--[[- card variant tables.
-- tables of cards that need to set variant.
-- For each setid, if unset uses sensible defaults from LHpi.sets.variants.
-- Note that you need to replicate the default values for the whole setid here, 
-- even if you set only a single card from the set differently.
-- 
--
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
[130] = { -- Antiquities
["Mishra's Factory"] 			= { "Mishra's Factory"		, { 1    , 2    , 3    , 4     } },
["Mishra's Factory, Frühling"] 	= { "Mishra's Factory"		, { 1    , false, false, false } },
["Mishra's Factory, Sommer"] 	= { "Mishra's Factory"		, { false, 2    , false, false } },
["Mishra's Factory, Herbst"] 	= { "Mishra's Factory"		, { false, false, 3    , false } },
["Mishra's Factory, Winter"] 	= { "Mishra's Factory"		, { false, false, false, 4     } },
["Strip Mine"] 					= { "Strip Mine"			, { 1    , 2    , 3    , 4     } },
["Strip Mine, kein Himmel"] 	= { "Strip Mine"			, { 1    , false, false, false } },
["Strip Mine, ebene Treppen"] 	= { "Strip Mine"			, { false, 2    , false, false } },
["Strip Mine, mit Turm"] 		= { "Strip Mine"			, { false, false, 3    , false } },
["Strip Mine, unebene Treppen"] = { "Strip Mine"			, { false, false, false, 4     } },
["Urza's Mine"] 				= { "Urza's Mine"			, { 1    , 2    , 3    , 4     } },
["Urza's Power Plant"] 			= { "Urza's Power Plant"	, { 1    , 2    , 3    , 4     } },
["Urza's Tower"] 				= { "Urza's Tower"			, { 1    , 2    , 3    , 4     } },
},
} -- end table site.variants

--[[- foil status replacement tables
-- { #number = #table { #string = #table { #boolean foil } } }
-- 
--- @field [parent=#site] #table foiltweak ]]
--- @field [parent=#site] #table foiltweak
site.foiltweak = {
} -- end table site.foiltweak

if CHECKEXPECTED then
--[[- table of expected results.
-- as of script release
-- { #number = #table { #table pset = #table { #number = #number, ... }, #table failed = #table { #number = #number, ... }, dropped = #number , namereplaced = #number }
-- 
--- @field [parent=#site] #table expected ]]
--- @field [parent=#site] #table expected
site.expected = {
EXPECTTOKENS = true,
-- Core sets
[770] = { namereplaced=6 },
[720] = { pset={ [3]=383-1+6 }, failed={ [3]=1 }, namereplaced=3 },
[630] = { pset={ 359-9, [3]=352-2 }, namereplaced=2 },
[550] = { pset={ 357-7, [3]=355-5 }, namereplaced=7 },
[460] = { namereplaced=5 },
[360] = { namereplaced=4 },
[250] = { namereplaced=3 },
[180] = { namereplaced=5 },
[140] = { namereplaced=7 },
[139] = { namereplaced=2 },
[110] = { pset={ 291 }, namereplaced=1 },
[100] = { pset={ 252 } },
-- Expansions
[793] = { namereplaced=1 },
[786] = { namereplaced=8 },
[784] = { pset={ 161+1 }, failed={ [3]=1 }, namereplaced=7 }, --+1 is Checklist
[782] = { pset={ 276+1 }, failed={ [3]=1 }, namereplaced=9 }, -- fail/+1 is Checklist
[773] = { failed={ 1, [3]=1 }, namereplaced=6 }, -- fail is Poison Counter
[767] = { namereplaced=3 },
[754] = { namereplaced=4 },
[751] = { namereplaced=10 },
[730] = { namereplaced=4 },
[710] = { namereplaced=2 },
[690] = { dropped=967, namereplaced=6 },
[680] = { dropped=362, namereplaced=1 },
[670] = { namereplaced=2 },
[654] = { namereplaced=3 },
[650] = { namereplaced=1 },
[620] = { namereplaced=14 },
[610] = { namereplaced=19 },
[590] = { namereplaced=32 },
[580] = { namereplaced=4 },
[530] = { namereplaced=5 },
[420] = { pset={ [3]=0 }, failed={ [3]=143 } },
[410] = { pset={ [3]=0 }, failed={ [3]=143+2 } },
[400] = { pset={ [3]=0 }, failed={ [3]=335 } },
[290] = { namereplaced=1 },
[270] = { namereplaced=2 },
[220] = { namereplaced=5 },
[190] = { namereplaced=4 },
[160] = { namereplaced=1 }, -- in ita
[150] = { pset={ [5]=0 }, failed={ [5]=310 } },
[120] = { namereplaced=3 },
-- special sets
[600] = { namereplaced=7 },
[320] = { namereplaced=6 },
[310] = { namereplaced=2 },
[260] = { pset={ [3]=222 }, namereplaced=4 },
[201] = { namereplaced=1 },
[200] = { namereplaced=2 },
}
end
