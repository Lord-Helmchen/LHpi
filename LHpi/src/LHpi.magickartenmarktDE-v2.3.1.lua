--*- coding: utf-8 -*-
--[[- LHpi sitescript template 
Template to write new sitescripts for LHpi library

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
use LHpi-v2.2
]]

-- options that control the amount of feedback/logging done by the script
--- @field [parent=#global] #boolean VERBOSE 			default false
VERBOSE = true
--- @field [parent=#global] #boolean LOGDROPS 			default false
LOGDROPS = true
--- @field [parent=#global] #boolean LOGNAMEREPLACE 	default false
LOGNAMEREPLACE = true

-- options that control the script's behaviour.
--- compare card count with expected numbers; default true
-- @field [parent=#global] #boolean CHECKEXPECTED
CHECKEXPECTED = false
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
SAVEHTML = true
--- log to seperate logfile instead of Magic Album.log;	default true
-- @field [parent=#global] #boolean SAVELOG
SAVELOG = true
--- save price table to file before importing to MA;	default false
-- @field [parent=#global] #boolean SAVETABLE
SAVETABLE = false
--- revision of the LHpi library to use
-- @field [parent=#global] #string libver
libver = "2.3"
--- must always be equal to the scripts filename !
-- @field [parent=#global] #string scriptname
scriptname = "LHpi.magickartenmarktDE-v".. libver .. ".1.lua" 
--- savepath for OFFLINE (read) and SAVEHTML (write). must point to an existing directory relative to MA's root.
-- set by LHpi lib unless specified here.
-- @field [parent=#global] #string savepath
--savepath = "Prices\\" .. string.gsub( scriptname , "%-v%d+%.%d+%.lua$" , "" ) .. "\\"

--- @field [parent=#global] #table LHpi		LHpi library table
LHpi = {}

--- Site specific configuration
-- Settings that define the source site's structure and functions that depend on it
-- @type site
-- 
-- @field #string regex
-- @field #string currency
-- @field #string encoding
site={}
--site.regex = ''
site.currency="€"

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
--	https://www.magickartenmarkt.de/?mainPage=browseCategory&idCategory=1&idExpansion=56&idRarity=&onlyAvailable=no&sortBy=englishName&sortDir=asc
	site.domain = "www.magickartenmarkt.de/"
	site.file = "?mainPage=browseCategory&idCategory=1&onlyAvailable=no&sortBy=englishName&sortDir=asc"
	site.setprefix = "&idExpansion="
	site.frucprefix = "&idRarity="
	site.pagenrprefix = "&resultsPage="

	local container = {}
	
	for pagenr=0, 5 do
		local url = site.file .. site.setprefix .. site.sets[setid].url .. site.frucprefix .. site.frucs[frucid] .. site.pagenrprefix .. pagenr
		if offline then
			url = savepath .. string.gsub( url, "%?", "_" )  .. ".html"
			container[url] = { isfile = true}
		else
			url = "http://" .. site.domain .. url
			container[url] = {}
		end -- if offline 
	end	

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
--function site.ParseHtmlData( foundstring , urldetails )
--
--	return newCard
--end -- function site.ParseHtmlData

--[[- special cases card name manipulation
 Ties into LHpi.buildCardData to make changes that are specific to one site and thus don't belong into the library
 
 @function [parent=#site] BCDpluginName
 @param #string name		the cardname LHpi.buildardData is working on
 @param #number setid
 @returns #string name	modified cardname is passed back for further processing
]]
--function site.BCDpluginName ( name , setid )
--	if DEBUG then
--		LHpi.Log( "site.BCDpluginName got " .. name .. " from set " .. setid , 2 )
--	end
--
--	-- if you don't want a full namereplace table, these four gsubs will take care of a lot of fails.
--	name = string.gsub( name , "Æ" , "AE")
--	name = string.gsub( name , "â" , "a")
--	name = string.gsub( name , "û" , "u")
--	name = string.gsub( name , "á" , "a")

--	return name
--end -- function site.BCDpluginName

--[[- special cases card data manipulation
 Ties into LHpi.buildCardData to make changes that are specific to one site and thus don't belong into the library
 
 @function [parent=#site] BCDpluginCard
 @param #table card		the card LHpi.BuildCardData is working on
 @param #number setid
 @returns #table card modified card is passed back for further processing
]]
--function site.BCDpluginCard( card , setid )
--	if DEBUG then
--		LHpi.Log( "site.BCDpluginCard got " .. LHpi.Tostring( card ) .. " from set " .. setid , 2 )
--	end
--
--	return card
--end -- function site.BCDpluginCard

-------------------------------------------------------------------------------------------------------------
-- tables
-------------------------------------------------------------------------------------------------------------

--[[- table of (supported) languages.
-- { #number = { id = #number, full = #string, abbr = #string } }
-- 
--- @field [parent=#site] #table langs ]]
--- @field [parent=#site] #table langs
site.langs = {
	[1] = {id=1, full = "English", 	abbr="ENG", url="" },
	[3] = {id=3, full = "German", 	abbr="GER", url="" },
}

--- @field [parent=#site] #table frucs	rarity array { #number = #string }
--site.frucs={ false , "Mythic", "Rare", "Uncommon", "Common",	"Land",	"Token",	"Time Shifted",	"Special" }
site.frucs = { "nil" , "17",	 "18",	 "21",		 "22",		"23",	"24",		"20",			"19" }

--[[- table of available sets
-- { #number = #table { #number id, #table lang = #table { #boolean, ... } , #table fruc = # table { #boolean, ... }, #string url } }
-- #number id		: setid (can be found in "Database\Sets.txt" file)
-- #table fruc		: table of available rarity urls to be parsed
--		compare with site.frucs
-- 		#boolean fruc[1]	: does foil url exist?
-- 		#boolean fruc[2]	: does rares url exist?
-- 		#boolean fruc[3]	: does uncommons url exist?
-- 		#boolean fruc[4]	: does commons url exist?
-- 		#boolean fruc[5]	: does TimeSpiral Timeshifted url exist?
-- #table lang		:  table of available languages { #boolean , ... }
-- #string url		: set url infix
-- 
--- @field [parent=#site] #table sets ]]
--- @field [parent=#site] #table sets
site.sets = {

-- -- Core sets
--[[
[788]={id = 788, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "M2013"}, 
--]]

} -- end table site.sets

--[[- card name replacement tables.
-- { #number = #table { #string = #string } }
-- 
--- @field [parent=#site] #table namereplace ]]
--- @field [parent=#site] #table namereplace
site.namereplace = {

--[[
[788] = { -- M2013
["Liliana o. t. Dark Realms Emblem"]	= "Liliana of the Dark Realms Emblem"
}
--]]
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

--[[ example
[766] = { -- Phyrexia VS Coalition
 	["Phyrexian Negator"] 	= { foil = true  },
	["Urza's Rage"] 		= { foil = true  }
}
]]
} -- end table site.foiltweak

if not (CHECKEXPECTED==false) then
--[[- table of expected results.
-- as of script release
-- { #number = #table { #table pset = #table { #number = #number, ... }, #table failed = #table { #number = #number, ... }, dropped = #number , namereplaced = #number }
-- 
--- @field [parent=#site] #table expected ]]
--- @field [parent=#site] #table expected
site.expected = {
-- -- Core sets
--[788] = { pset={ 249+11, nil, 249 }, failed={ 0, nil, 11 }, dropped=0, namereplaced=1 }, -- M2013
}
end
