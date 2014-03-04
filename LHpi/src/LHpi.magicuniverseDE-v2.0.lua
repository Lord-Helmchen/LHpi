--*- coding: utf-8 -*-
--[[- LHpi magicuniverse.de sitescript 
Price import script for Magic Album
uses and needs LHpi library
to import card pricing from www.magicuniverse.de.

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
SAVETABLE = false -- needs incremental putFile to be remotely readable :)
--- must always be equal to the scripts filename !
-- @field [parent=#global] #string scriptname	
scriptname = "LHpi.magicuniverseDE-v2.0.lua" 
--[[FIXME the dynamic approach myname does not work, ma.GetFile returns nil for its own log :(
do
	--local _s,_e,myname = string.find( ma.GetFile("Magic Album.log"), "Starting Lua script .-([^\\]+%.lua)$" )
	if myname then
		scriptname = myname
	else -- use hardcoded scriptname as fallback
		scriptname = "LHpi.magicuniverseDE-v2.0.lua" -- should always be equal to the scripts filename !
	end
end
--]]
--- savepath for OFFLINE (read) and SAVEHTML (write). must point to an existing directory relative to MA's root.
-- @field [parent=#global] #string savepath
savepath = "Prices\\" .. string.gsub( scriptname , "%-v%d+%.%d+%.lua$" , "" ) .. "\\"

--- revision of the LHpi library to use
-- @field [parent=#global] #string libver
libver = "2.0"
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
site.regex = '<tr>\n<td align="center">\n%b<>%b<>\n%b<>%b<>%b<>\n%b<>%b<>\n(.-)\n%b<>\n</td>\n</tr>'
site.currency = "€" -- not used yet
site.encoding = "cp1252"

local STAMMKUNDE = false -- for magicuniverse.de, parse 10% lower Stammkunden-Preis instead of default price (the one sent to the Warenkorb)

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
 @return #table { #string = #table { foilonly = #boolean , offline = #boolean } } 
]]
function site.BuildUrl( setid,langid,frucid,offline )
	site.domain = "www.magicuniverse.de/html/"
	site.file = "magic.php?startrow=1"
	site.setprefix = "&edition="
--	site.langprefix = ""
	site.frucprefix = "&rarity="
--	site.suffix = ""
	
	local container = {}
	local url = site.file .. site.setprefix .. site.sets[setid].url .. site.frucprefix .. site.frucs[frucid]
	if offline then
		url = savepath .. string.gsub( url, "%?", "_" )  .. ".html"
		container[url] = { isfile = true}
	else
		url = "http://" .. site.domain .. url
		container[url] = {}
	end -- if offline 
	
	if string.find( url , "[Ff][Oo][Ii][Ll]" ) then -- mark url as foil-only
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
 @param #table urldetails	{ foilonly = #boolean , offline = #boolean , setid = #number, langid = #number, frucid = #number }
 @return #table { names = #table { #number = #string, ... }, price = #table { #number = #string, ... }} 
]]
function site.ParseHtmlData( foundstring , urldetails )
	local _start,_end,nameE = string.find( foundstring , 'name="namee" value="([^"]+)"' )
	if nameE == "_" then
		nameE = nil
	end
	local _start,_end,nameG = string.find( foundstring , 'name="named" value="([^"]+)"' )
	if nameG == "_" then
		nameG = nil
	end
	local price = nil
	if not STAMMKUNDE then
		local _start,_end,lprice = string.find( foundstring , 'name="preis" value="([%d.,]+)"' )
		price=lprice
	else
		local _start,_end,lprice = string.find( foundstring , '<a href="rabatt.php" target="_blank"  class="linkblack"> %(([%d.,]+) &euro;%)' )
		price=lprice
	end
	price = string.gsub(price , "[,.]" , "" )
	price= tonumber( price )
	local prices = {}
	if nameE then
		prices[1] = price
	end
	if nameG then
		prices[3] = price
	end
	local newCard = { names = { [1] = nameE ,	[3] = nameG }, price = prices }
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
	
	-- seperate "(alpha)" and beta from beta-urls
	if setid == 90 then -- importing Alpha
		if string.find( name , "%([aA]lpha%)" ) then
			name = string.gsub( name , "%s*%([aA]lpha%)" , "" )
		else -- not "(alpha")
			name = name .. "(DROP not alpha)" -- change name to prevent import
		end
	elseif setid == 100 then -- importing Beta
		if string.find( name , "%([aA]lpha%)" ) then
			name = name .. "(DROP not beta)" -- change name to prevent import
		else -- not "(alpha")
			name = string.gsub( name , "%s*%(beta%)" , "" ) -- catch needlessly suffixed rawdata
			name = string.gsub( name , "%(beta, " , "(") -- remove beta infix from condition descriptor
		end 
--	elseif setid == 150 then -- Legends
--		if string.find( name , "%(ital%.?%)" ) then
--			name = string.gsub( name , "%(ital%.?%)" , "(DROP italian)" )
--			LHpi.Log("TODO Implement Card mangling to set lang instead of drop")
--			--card.lang = { nil,nil,nil,nil,[5] = "ITA" }
--		end
	end -- if setid
	
	-- mark condition modifier suffixed cards to be dropped
	name = string.gsub( name , "%([mM]int%)$" , "%0 (DROP)" )
	name = string.gsub( name , "%(near [mM]int%)$" , "%0 (DROP)" )
	name = string.gsub( name , "%([eE]xce[l]+ent%)$" , "%0 (DROP)" )
	name = string.gsub( name , "%(light played%)$" , "%0 (DROP)" )
	name = string.gsub( name , "%([lL][pP]%)$" , "%0 (DROP)" )
	name = string.gsub( name , "%(light played[/%-]played%)" , "%0 (DROP)" )
	name = string.gsub( name , "%([lL][pP]/[pP]%)$" , "%0 (DROP)" )
	name = string.gsub( name , "%(played%)$" , "%0 (DROP)" )
	name = string.gsub( name , "%([pP]%)$" , "%0 (DROP)" )
	name = string.gsub( name , "%(poor%)$" , "%0 (DROP)" )
	name = string.gsub( name , "%(knick%)$" , "%0 (DROP)" )
	name = string.gsub( name , "%(geknickt%)$" , "%0 (DROP)" )
	name = string.gsub( name , "signed%)$" , "%0 (DROP)" )
	name = string.gsub( name , "signiert%)$" , "%0 (DROP)" )
	name = string.gsub( name , "signiert!%)$" , "%0 (DROP)" )
	name = string.gsub( name , "unterschrieben%)$" , "%0 (DROP)" )
	name = string.gsub( name , "unterschrieben, excellent%)$" , "%0 (DROP)" )

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
	
	-- special case
	if setid == 140 then -- Revised
		if card.name == "Schilftroll (Fehldruck, deutsch)" then
			card.lang = { [3]="GER" }
			card.name = "Mana Barbs (Misprint 'Mana Troll')"
		end
	elseif setid == 180 then -- 4th Edition
		if card.name == "Warp Artifact (FEHLDRUCK)" then
			card.lang = { [3]="GER" }
			card.name = "El-Hajjâj (Misprint 'El-Pancake')"
		end
	elseif setid == 150 then -- Legends
		if string.find( card.name , "%(ital%.?%)" ) then
			card.name = string.gsub( card.name , "%s*%(ital%.?%)%s*" , "" )
			card.lang = { [5] = "ITA" }
			card.regprice = { [5] = card.regprice[1] }
		end
	end -- if setid

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
	[1] = {id=1, full = "English", 	abbr="ENG", url="" },
	[3] = {id=3, full = "German", 	abbr="GER", url="" },
	[5] = {id=5, full = "Italian", 	abbr="ITA", url="" },
}

--- @field [parent=#site] #table frucs	rarity array { #number = #string }
site.frucs = { "Foil" , "Rare" , "Uncommon" , "Common" , "Purple" }

--TODO local condprio = { [0] = "NONE", } -- table to sort condition description. lower indexed will overwrite when building the cardsetTable

--[[- table of available sets
-- { #number = #table { #number id, #table lang = #table { #boolean, ... } , #table fruc = # table { #boolean, ... }, #string url } }
-- #number id		: setid (can be found in "Database\Sets.txt" file)
-- #table cards	: { #number reg, #number tok }
-- 					table of expected cardcounts used for sanity checking the import.
-- 					must be hardcoded here until ma.getcardcount(setid, cardtype[all|regular|token|basicland] is possile :)
-- 		#number cards.reg	: number of expected regular cards
-- 		#number cards.tok	: number of expected tokens
-- #table fruc		: table of available rarity urls to be parsed
--		compare with site.frucs
-- 		#boolean fruc[1]	: does foil url exist?
-- 		#boolean fruc[2]	: does rares url exist?
-- 		#boolean fruc[3]	: does uncommons url exist?
-- 		#boolean fruc[4]	: does commons url exist?
-- 		#boolean fruc[5]	: does TimeSpiral Timeshifted url exist?
-- #table lang		:  table of available languages { #number langid = #boolean }
-- #string url		: set url infix
-- 
--- @field [parent=#site] #table sets ]]
--- @field [parent=#site] #table sets
site.sets = {
-- Core sets
[788]={id = 788, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "M2013"}, 
[779]={id = 779, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "M2012"}, 
[770]={id = 770, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "M2011"}, 
[759]={id = 759, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "M2010"}, 
[720]={id = 720, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "10th_Edition"}, 
[630]={id = 630, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "9th_Edition"}, 
[550]={id = 550, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "8th_Edition"}, 
[460]={id = 460, lang = { true , [3]=true  }, fruc = { false,true ,true ,false }, url = "7th_Edition"}, 
[180]={id = 180, lang = { true , [3]=true  }, fruc = { false,true ,true ,false }, url = "4th_Edition"}, 
[140]={id = 140, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Revised"}, 
 -- Revised Limited : url only provides cNameG
[139]={id = 139, lang = { false, [3]=true  }, fruc = { false,true ,true ,true  }, url = "deutsch_limitiert"}, 
[110]={id = 110, lang = { true , [3]=false }, fruc = { false,true ,true ,true  }, url = "Unlimited"}, 
[100]={id = 100, lang = { true , [3]=false }, fruc = { false,true ,true ,true  }, url = "Beta"}, 
 -- Alpha in Beta with "([Aa]lpha)" suffix
[90] ={id =  90, lang = { true , [3]=false }, fruc = { false,true ,true ,true  }, url = "Beta"}, 
 -- Expansions
[793]={id = 793, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Gatecrash"},
[791]={id = 791, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Return%20to%20Ravnica"},
[786]={id = 786, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Avacyn%20Restored"},
[784]={id = 784, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Dark%20Ascension"}, 
[782]={id = 782, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Innistrad"}, 
[776]={id = 776, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "New%20Phyrexia"},
[775]={id = 775, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Mirrodin%20Besieged"},
[773]={id = 773, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Scars%20of%20Mirrodin"},
[767]={id = 767, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Rise%20of%20the%20Eldrazi"},
[765]={id = 765, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Worldwake"},
[762]={id = 762, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Zendikar"},
[758]={id = 758, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Alara%20Reborn"},
[756]={id = 756, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Conflux"},
[754]={id = 754, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Shards%20of%20Alara"},
[752]={id = 752, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Eventide"},
[751]={id = 751, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Shadowmoor"},
[750]={id = 750, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Morningtide"},
[730]={id = 730, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Lorwyn"},
[710]={id = 710, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Future_Sight"},
[700]={id = 700, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Planar_Chaos"},
 -- for Timeshifted and Timespiral, lots of expected fails due to shared foil url
[690]={id = 690, lang = { true , [3]=true  }, fruc = { true ,false,false,false,true  }, url = "Time_Spiral"}, -- Timeshifted
[680]={id = 680, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Time_Spiral"},
[670]={id = 670, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Coldsnap"},
[660]={id = 660, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Dissension"},
[650]={id = 650, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Guildpact"},
[640]={id = 640, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Ravnica"},
[620]={id = 620, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Saviors_of_Kamigawa"},
[610]={id = 610, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Betrayers_of_Kamigawa"},
[590]={id = 590, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Champions_of_Kamigawa"},
[580]={id = 580, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "5th_Dawn"},
[570]={id = 570, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Darksteel"},
[560]={id = 560, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Mirrodin"},
[540]={id = 540, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Scourge"},
[530]={id = 530, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Legions"},
[520]={id = 520, lang = { true , [3]=true  }, fruc = { true ,true ,true ,true  }, url = "Onslaught"},
[510]={id = 510, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Judgment"},
[500]={id = 500, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Torment"},
[480]={id = 480, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Odyssey"},
[470]={id = 470, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Apocalypse"},
[450]={id = 450, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Planeshift"},
[430]={id = 430, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Invasion"},
[420]={id = 420, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Prophecy"},
[410]={id = 410, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Nemesis"},
[400]={id = 400, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Merkadische_Masken"},
[370]={id = 370, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Urzas_Destiny"},
[350]={id = 350, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Urzas_Legacy"},
[330]={id = 330, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Urzas_Saga"},
[300]={id = 300, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Exodus"},
[290]={id = 290, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Stronghold"},
[280]={id = 280, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Tempest"},
[270]={id = 270, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Weatherlight"},
[240]={id = 240, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Vision"},
[230]={id = 230, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Mirage"},
[220]={id = 220, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Alliances"},
[210]={id = 210, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Homelands"},
[190]={id = 190, lang = { true , [3]=true  }, fruc = { false,true ,true ,true  }, url = "Ice_Age"},
[170]={id = 170, lang = { true , [3]=false }, fruc = { false,true ,true ,true  }, url = "Fallen_Empires"},
[160]={id = 160, lang = { true , [3]=false }, fruc = { false,true ,true ,true  }, url = "The_Dark"},
[150]={id = 150, lang = { true , [3]=false , [5]=true }, fruc = { false,true ,true ,true  }, url = "Legends"},
[130]={id = 130, lang = { true , [3]=false }, fruc = { false,true ,true ,true  }, url = "Antiquities"},
[120]={id = 120, lang = { true , [3]=false }, fruc = { false,true ,true ,true  }, url = "Arabian_Nights"},
-- TODO add special and promo sets
} -- end table site.sets

--[[- card name replacement tables.
-- { #number = #table { #string = #string } }
-- 
--- @field [parent=#site] #table namereplace ]]
--- @field [parent=#site] #table namereplace
site.namereplace = {
[788] = { -- M2013
["Liliana o. t. Dark Realms Emblem"]	= "Liliana of the Dark Realms Emblem"
},
[140] = { -- Revised
["Serendib Efreet (Fehldruck)"] 		= "Serendib Efreet",
["Pearl Unicorn"] 						= "Pearled Unicorn",
["Monss Goblin Raiders"] 				= "Mons's Goblin Raiders"
},
[139] = { -- Revised Limited (german)
["Schwarzer Ritus (Dark Ritual)"] 		= "Schwarzer Ritus",
["Goblinkönig"]							= "Goblin König",
["Bengalische Heldin"] 					= "Benalische Heldin",
["Advocatus Diaboli"] 					= "Advokatus Diaboli",
["Zersetzung (Desintegrate)"] 			= "Zersetzung",
["Ketos' Zauberbuch"] 					= "Ketos Zauberbuch",
["Leibwächter d. Veteranen"] 			= "Leibwächter des Veteranen",
["Stab des Verderbens"] 				= "Stab der Verderbnis",
["Der schwarze Tot"] 					= "Der Schwarze Tod",
["Greif Roc aus dem Khergebrige"] 		= "Greif Roc aus dem Khergebirge",
["Rückkopplung"] 						= "Rückkoppelung",
["Armageddon-Uhr"] 						= "Armageddonuhr",
["Mons Plündernde Goblins"] 			= "Mons's Goblin Raiders", -- "Mons' plündernde Goblins" failed, might be the ' at end of string?
["Gaeas Vasall"] 						= "Gäas Vasall",
["Bogenschützen der Elfen"] 			= "Bogenschütze der Elfen",
["Ornithropher"] 						= "Ornithopter",
["Granitgargoyle"] 						= "Granit Gargoyle",
["Inselfisch Jaskonius"] 				= "Inselfisch Jasconius",
["Hypnotiserendes Gespenst"] 			= "Hypnotisierendes Gespenst"
},
[110] = { -- Unlimited
["Will-o-The-Wisp"] 					= "Will-o’-the-Wisp"
},
[100] = { -- Beta (shares urls with Alpha)
["Time Walk (alpha, near mint)"]		= "Time Walk (alpha)(near mint)"
},
[90] = { -- Alpha
["Time Walk (alpha, near mint)"]		= "Time Walk (alpha)(near mint)"
},
[793] = { -- Gatecrash
["AEtherize"]							= "Ætherize",
["Domrirade Emblem"] 					= "Domri Rade Emblem"
},
[786] = { -- Avacyn Restored
["Tamiyo, the Moonsage Emblem"]			= "Tamiyo, the Moon Sage Emblem"
},
[784] = { -- Dark Ascension
["Hinterland Hermit"] 					= "Hinterland Hermit|Hinterland Scourge",
["Mondronen Shaman"] 					= "Mondronen Shaman|Tovolar’s Magehunter",
["Soul Seizer"] 						= "Soul Seizer|Ghastly Haunting",
["Lambholt Elder"] 						= "Lambholt Elder|Silverpelt Werewolf",
["Ravenous Demon"] 						= "Ravenous Demon|Archdemon of Greed",
["Elbrus, the Binding Blade"] 			= "Elbrus, the Binding Blade|Withengar Unbound",
["Loyal Cathar"] 						= "Loyal Cathar|Unhallowed Cathar",
["Chosen of Markov"] 					= "Chosen of Markov|Markov’s Servant",
["Huntmaster of the Fells"] 			= "Huntmaster of the Fells|Ravager of the Fells",
["Afflicted Deserter"] 					= "Afflicted Deserter|Werewolf Ransacker",
["Chalice of Life"] 					= "Chalice of Life|Chalice of Death",
["Wolfbitten Captive"] 					= "Wolfbitten Captive|Krallenhorde Killer",
["Scorned Villager"]					= "Scorned Villager|Moonscarred Werewolf",
["Doublesidedcards-Checklist"]			= "Checklist"
},
[782] = { -- Innistrad
["Bloodline Keeper"] 					= "Bloodline Keeper|Lord of Lineage",
["Ludevic's Test Subject"] 				= "Ludevic's Test Subject|Ludevic's Abomination",
["Instigator Gang"] 					= "Instigator Gang|Wildblood Pack",
["Kruin Outlaw"] 						= "Kruin Outlaw|Terror of Kruin Pass",
["Daybreak Ranger"] 					= "Daybreak Ranger|Nightfall Predator",
["Garruk Relentless"] 					= "Garruk Relentless|Garruk, the Veil-Cursed",
["Mayor of Avabruck"] 					= "Mayor of Avabruck|Howlpack Alpha",
["Cloistered Youth"] 					= "Cloistered Youth|Unholy Fiend",
["Civilized Scholar"] 					= "Civilized Scholar|Homicidal Brute",
["Screeching Bat"] 						= "Screeching Bat|Stalking Vampire",
["Hanweir Watchkeep"] 					= "Hanweir Watchkeep|Bane of Hanweir",
["Reckless Waif"] 						= "Reckless Waif|Merciless Predator",
["Gatstaf Shepherd"] 					= "Gatstaf Shepherd|Gatstaf Howler",
["Ulvenwald Mystics"] 					= "Ulvenwald Mystics|Ulvenwald Primordials",
["Thraben Sentry"] 						= "Thraben Sentry|Thraben Militia",
["Delver of Secrets"] 					= "Delver of Secrets|Insectile Aberration",
["Tormented Pariah"] 					= "Tormented Pariah|Rampaging Werewolf",
["Village Ironsmith"] 					= "Village Ironsmith|Ironfang",
["Grizzled Outcasts"] 					= "Grizzled Outcasts|Krallenhorde Wantons",
["Villagers of Estwald"] 				= "Villagers of Estwald|Howlpack of Estwald",
["Doublesidedcards-Checklist"]			= "Checklist"
},
[775] = { -- Mirrodin Besieged
["Poisoncounter"]						= "Poison Counter"
},
[773] = { -- Scars of Mirrodin
["Poisoncounter"]						= "Poison Counter"
},
[750] = { -- Morningtide
["Faery Rogue"] 						= "Faerie Rogue"
},
[762] = { -- Zendikar
["Meerfolk"] 							= "Merfolk"
},
[730] = { -- Lorwyn
["Elf, Warrior"] 						= "Elf Warrior",
["Kithkin, Soldier"] 					= "Kithkin Soldier",
["Meerfolk Wizard"] 					= "Merfolk Wizard"
},
[640] = { -- Ravnica: City of Guilds
["Drooling Groodian"] 					= "Drooling Groodion",
["Flame Fusilade"]						= "Flame Fusillade",
["Sabretooth Alley Cat"] 				= "Sabertooth Alley Cat",
["Torpid Morloch"]						= "Torpid Moloch",
["Ordunn Commando"] 					= "Ordruun Commando"
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
[560] = { -- Mirrodin
["Goblin Warwagon"]						= "Goblin War Wagon"
},
[500] = { -- Torment
["Chainers Edict"]						= "Chainer's Edict",
["Caphalid Illusionist"]				= "Cephalid Illusionist"
},
[120] = { -- Arabian Nights
["Ifh-Bíff Efreet"] 					= "Ifh-Biff Efreet"
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
[770] = { -- M2011
["Plains"] 									= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (230)"]							= { "Plains"	, { 1    , false, false, false } }, 
["Plains (231)"]							= { "Plains"	, { false, 2    , false, false } },
["Plains (232)"]							= { "Plains"	, { false, false, 3    , false } },
["Plains (233)"]							= { "Plains"	, { false, false, false, 4     } },
["Island (234)"]							= { "Island"	, { 1    , false, false, false } },
["Island (235)"]							= { "Island"	, { false, 2    , false, false } },
["Island (236)"]							= { "Island"	, { false, false, 3    , false } },
["Island (237)"]							= { "Island"	, { false, false, false, 4     } },
["Swamp (238)"]								= { "Swamp"		, { 1    , false, false, false } },
["Swamp (239)"]								= { "Swamp"		, { false, 2    , false, false } },
["Swamp (240)"]								= { "Swamp"		, { false, false, 3    , false } },
["Swamp (241)"]								= { "Swamp"		, { false, false, false, 4     } },
["Mountain (242)"]							= { "Mountain"	, { 1    , false, false, false } },
["Mountain (243)"]							= { "Mountain"	, { false, 2    , false, false } },
["Mountain (244)"]							= { "Mountain"	, { false, false, 3    , false } },
["Mountain (245)"]							= { "Mountain"	, { false, false, false, 4     } },
["Forest (246)"]							= { "Forest"	, { 1    , false, false, false } },
["Forest (247)"]							= { "Forest"	, { false, 2    , false, false } },
["Forest (248)"]							= { "Forest"	, { false, false, 3    , false } },
["Forest (249)"]							= { "Forest"	, { false, false, false, 4     } },
["Token - Ooze (G) - (2/2)"]				= { "Ooze"		, { 1    , false } },
["Token - Ooze (G) - (1/1)"]				= { "Ooze"		, { false, 2     } }
},
[550] = { -- 8th
["Plains"] 									= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Swamp (341)"]								= { "Swamp"		, { false, false, 3    , false } }
},
[100] = { -- Beta
["Plains"] 									= { "Plains"	, { 1    , 2    , 3     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3     } },
["Plains (vers.1)"]							= { "Plains"	, { 1    , false, false } },
["Plains (vers.2)"]							= { "Plains"	, { false, 2    , false } },
["Plains (vers.3)"]							= { "Plains"	, { false, false, 3     } },
["Island (vers.1)"]							= { "Island"	, { 1    , false, false } },
["Island (vers.2)"]							= { "Island"	, { false, 2    , false } },
["Island (vers.3)"]							= { "Island"	, { false, false ,true  } },
["Swamp (vers.1)"]							= { "Swamp"		, { 1    , false, false } },
["Swamp (vers.2)"]							= { "Swamp"		, { false, 2    , false } },
["Swamp (vers.3)"]							= { "Swamp"		, { false, false, 3     } },
["Mountain (vers.1)"]						= { "Mountain"	, { 1    , false, false } },
["Mountain (vers.2)"]						= { "Mountain"	, { false, 2    , false } },
["Mountain (vers.3)"]						= { "Mountain"	, { false, false, 3     } },
["Forest (vers.1)"]							= { "Forest"	, { 1    , false, false } },
["Forest (vers.2)"]							= { "Forest"	, { false, 2    , false } },
["Forest (vers.3)"]							= { "Forest"	, { false, false, 3     } }
},
[786] = { -- Avacyn Restored
["Plains"] 									= { "Plains"	, { 1    , 2    , 3     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3     } },
["Plains (230)"]							= { "Plains"	, { 1    , false, false } },
["Plains (231)"]							= { "Plains"	, { false, 2    , false } },
["Plains (232)"]							= { "Plains"	, { false, false, 3     } },
["Island (233)"]							= { "Island"	, { 1    , false, false } },
["Island (234)"]							= { "Island"	, { false, 2    , false } },
["Island (235)"]							= { "Island"	, { false, false, 3     } },
["Swamp (236)"]								= { "Swamp"		, { 1    , false, false } },
["Swamp (237)"]								= { "Swamp"		, { false, 2    , false } },
["Swamp (238)"]								= { "Swamp"		, { false, false, 3     } },
["Mountain (239)"]							= { "Mountain"	, { 1    , false, false } },
["Mountain (240)"]							= { "Mountain"	, { false, 2    , false } },
["Mountain (241)"]							= { "Mountain"	, { false, false, 3     } },
["Forest (242)"]							= { "Forest"	, { 1    , false, false } },
["Forest (243)"]							= { "Forest"	, { false, 2    , false } },
["Forest (244)"]							= { "Forest"	, { false, false, 3     } },
["Token - Spirit (W)"]						= { "Spirit"	, { 1    , false } },
["Token - Spirit (U)"]						= { "Spirit"	, { false, 2     } },
["Token - Human (W)"]						= { "Human"		, { 1    ,false  } },
["Token - Human (R)"]						= { "Human"		, { false, 2     } }
},
[782] = { -- Innistrad
["Plains"] 									= { "Plains"	, { 1    , 2    , 3     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3     } },
["Plains (250)"]							= { "Plains"	, { 1    , false, false } },
["Plains (251)"]							= { "Plains"	, { false, 2    , false } },
["Plains (252)"]							= { "Plains"	, { false, false, 3     } },
["Island (253)"]							= { "Island"	, { 1    , false, false } },
["Island (254)"]							= { "Island"	, { false, 2    , false } },
["Island (255)"]							= { "Island"	, { false, false, 3     } },
["Swamp (256)"]								= { "Swamp"		, { 1    , false, false } },
["Swamp (257)"]								= { "Swamp"		, { false, 2    , false } },
["Swamp (258)"]								= { "Swamp"		, { false, false, 3     } },
["Mountain (259)"]							= { "Mountain"	, { 1    , false, false } },
["Mountain (260)"]							= { "Mountain"	, { false, 2    , false } },
["Mountain (261)"]							= { "Mountain"	, { false, false, 3     } },
["Forest (262)"]							= { "Forest"	, { 1    , false, false } },
["Forest (263)"]							= { "Forest"	, { false, 2    , false } },
["Forest (264)"]							= { "Forest"	, { false, false, 3     } },
["Token - Zombie (B) (7)"]					= { "Zombie"	, { 1    , false, false } },
["Token - Zombie (B) (8)"]					= { "Zombie"	, { false, 2    , false } },
["Token - Zombie (B) (9)"]					= { "Zombie"	, { false, false, 3     } },
["Token - Wolf (B)"]						= { "Wolf"		, { 1    , false } },
["Token - Wolf (G)"]						= { "Wolf"		, { false, 2     } }
},
[773] = { -- Scars of Mirrodin
["Plains"] 									= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (230)"]							= { "Plains"	, { 1    , false ,false, false } }, 
["Plains (231)"]							= { "Plains"	, { false, 2    , false, false } },
["Plains (232)"]							= { "Plains"	, { false, false, 3    , false } },
["Plains (233)"]							= { "Plains"	, { false, false, false, 4     } },
["Island (234)"]							= { "Island"	, { 1    , false, false, false } },
["Island (235)"]							= { "Island"	, { false, 2    , false, false } },
["Island (236)"]							= { "Island"	, { false, false, 3    , false } },
["Island (237)"]							= { "Island"	, { false, false, false, 4     } },
["Swamp (238)"]								= { "Swamp"		, { 1    , false, false, false } },
["Swamp (239)"]								= { "Swamp"		, { false, 2    , false, false } },
["Swamp (240)"]								= { "Swamp"		, { false, false, 3    , false } },
["Swamp (241)"]								= { "Swamp"		, { false, false, false, 4     } },
["Mountain (242)"]							= { "Mountain"	, { 1    , false, false, false } },
["Mountain (243)"]							= { "Mountain"	, { false, 2    , false, false } },
["Mountain (244)"]							= { "Mountain"	, { false, false, 3    , false } },
["Mountain (245)"]							= { "Mountain"	, { false, false, false, 4     } },
["Forest (246)"]							= { "Forest"	, { 1    , false, false, false } },
["Forest (247)"]							= { "Forest"	, { false, 2    , false, false } },
["Forest (248)"]							= { "Forest"	, { false, false, 3    , false } },
["Forest (249)"]							= { "Forest"	, { false, false, false, 4     } },
["Token - Wurm (Art) (Deathtouch)"] 		= { "Wurm"		, { 1    , false } },
["Token - Wurm (Art) (Lifelink)"] 			= { "Wurm"		, { false, 2     } }
},
[767] = { -- Rise of the Eldrazi
["Plains"] 									= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (229)"]							= { "Plains"	, { 1    , false, false, false } }, 
["Plains (230)"]							= { "Plains"	, { false, 2    , false, false } },
["Plains (231)"]							= { "Plains"	, { false, false, 3    , false } },
["Plains (232)"]							= { "Plains"	, { false, false, false, 4     } },
["Island (233)"]							= { "Island"	, { 1    , false, false, false } },
["Island (234)"]							= { "Island"	, { false, 2    , false, false } },
["Island (235)"]							= { "Island"	, { false, false, 3    , false } },
["Island (236)"]							= { "Island"	, { false, false, false, 4     } },
["Swamp (237)"]								= { "Swamp"		, { 1    , false, false, false } },
["Swamp (238)"]								= { "Swamp"		, { false, 2    , false, false } },
["Swamp (239)"]								= { "Swamp"		, { false, false, 3    , false } },
["Swamp (240)"]								= { "Swamp"		, { false, false, false, 4     } },
["Mountain (241)"]							= { "Mountain"	, { 1    , false, false, false } },
["Mountain (242)"]							= { "Mountain"	, { false, 2    , false, false } },
["Mountain (243)"]							= { "Mountain"	, { false, false, 3    , false } },
["Mountain (244)"]							= { "Mountain"	, { false, false, false, 4     } },
["Forest (245)"]							= { "Forest"	, { 1    , false, false, false } },
["Forest (246)"]							= { "Forest"	, { false, 2    , false, false } },
["Forest (247)"]							= { "Forest"	, { false, false, 3    , false } },
["Forest (248)"]							= { "Forest"	, { false, false, false, 4     } },
["TOKEN - Eldrazi Spawn (Vers. A)"] 		= { "Eldrazi Spawn"	, { "a"  , false, false } },
["TOKEN - Eldrazi Spawn (Vers. B)"] 		= { "Eldrazi Spawn"	, { false, "b"  , false } },
["TOKEN - Eldrazi Spawn (Vers. C)"] 		= { "Eldrazi Spawn"	, { false, false, "c"   } }
},
[762] = { -- Zendikar
["Plains - Vollbild"] 						= { "Plains"	, { 1    , 2    , 3    , 4    } },
["Island - Vollbild"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp - Vollbild"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain - Vollbild"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest - Vollbild"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains - Vollbild (230)"]					= { "Plains"	, { 1    , false, false, false } },
["Plains - Vollbild (231)"]					= { "Plains"	, { false, 2    , false, false } },
["Plains - Vollbild (232)"]					= { "Plains"	, { false, false, 3    , false } },
["Plains - Vollbild (233)"]					= { "Plains"	, { false, false, false, 4     } },
["Island - Vollbild (234)"]					= { "Island"	, { 1    , false, false, false } },
["Island - Vollbild (235)"]					= { "Island"	, { false, 2    , false, false } },
["Island - Vollbild (236)"]					= { "Island"	, { false, false, 3    , false } },
["Island - Vollbild (237)"]					= { "Island"	, { false, false, false, 4     } },
["Swamp - Vollbild (238)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp - Vollbild (239)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp - Vollbild (240)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp - Vollbild (241)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain - Vollbild (242)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain - Vollbild (243)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain - Vollbild (244)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain - Vollbild (245)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest - Vollbild (246)"]					= { "Forest"	, { 1    , false, false, false } },
["Forest - Vollbild (247)"]					= { "Forest"	, { false, 2    , false, false } },
["Forest - Vollbild (248)"]					= { "Forest"	, { false, false, 3    , false } },
["Forest - Vollbild (249)"]					= { "Forest"	, { false, false, false, 4     } }
},
[751] = { -- Shadowmoor
["Plains"] 									= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (282)"]							= { "Plains"	, { 1    , false ,false, false } }, 
["Plains (283)"]							= { "Plains"	, { false, 2    , false, false } },
["Plains (284)"]							= { "Plains"	, { false, false, 3    , false } },
["Plains (285)"]							= { "Plains"	, { false, false, false, 4     } },
["Island (286)"]							= { "Island"	, { 1    , false, false, false } },
["Island (287)"]							= { "Island"	, { false, 2    , false, false } },
["Island (288)"]							= { "Island"	, { false, false, 3    , false } },
["Island (289)"]							= { "Island"	, { false, false, false, 4     } },
["Swamp (290)"]								= { "Swamp"		, { 1    , false, false, false } },
["Swamp (291)"]								= { "Swamp"		, { false, 2    , false, false } },
["Swamp (292)"]								= { "Swamp"		, { false, false, 3    , false } },
["Swamp (293)"]								= { "Swamp"		, { false, false, false, 4     } },
["Mountain (294)"]							= { "Mountain"	, { 1    , false, false, false } },
["Mountain (295)"]							= { "Mountain"	, { false, 2    , false, false } },
["Mountain (296)"]							= { "Mountain"	, { false, false, 3    , false } },
["Mountain (297)"]							= { "Mountain"	, { false, false, false, 4     } },
["Forest (298)"]							= { "Forest"	, { 1    , false, false, false } },
["Forest (299)"]							= { "Forest"	, { false, 2    , false, false } },
["Forest (300)"]							= { "Forest"	, { false, false, 3    , false } },
["Forest (301)"]							= { "Forest"	, { false, false, false, 4     } },
["Token - Elf, Warrior (G)"]				= { "Elf Warrior"	, { 1    , false } },
["Token - Elf Warrior (G/W)"]				= { "Elf Warrior"	, { false, 1     } },
["Token - Elemental (R)"] 					= { "Elemental"		, { 1    , false } },
["Token - Elemental (B/R)"] 				= { "Elemental"		, { false, 2     } }
},
[730] = { -- Lorwyn
["Plains"] 									= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (282)"]							= { "Plains"	, { 1    , false ,false, false } }, 
["Plains (283)"]							= { "Plains"	, { false, 2    , false, false } },
["Plains (284)"]							= { "Plains"	, { false, false, 3    , false } },
["Plains (285)"]							= { "Plains"	, { false, false, false, 4     } },
["Island (286)"]							= { "Island"	, { 1    , false, false, false } },
["Island (287)"]							= { "Island"	, { false, 2    , false, false } },
["Island (288)"]							= { "Island"	, { false, false, 3    , false } },
["Island (289)"]							= { "Island"	, { false, false, false, 4     } },
["Swamp (290)"]								= { "Swamp"		, { 1    , false, false, false } },
["Swamp (291)"]								= { "Swamp"		, { false, 2    , false, false } },
["Swamp (292)"]								= { "Swamp"		, { false, false, 3    , false } },
["Swamp (293)"]								= { "Swamp"		, { false, false, false, 4     } },
["Mountain (294)"]							= { "Mountain"	, { 1    , false, false, false } },
["Mountain (295)"]							= { "Mountain"	, { false, 2    , false, false } },
["Mountain (296)"]							= { "Mountain"	, { false, false, 3    , false } },
["Mountain (297)"]							= { "Mountain"	, { false, false, false, 4     } },
["Forest (298)"]							= { "Forest"	, { 1    , false, false, false } },
["Forest (299)"]							= { "Forest"	, { false, 2    , false, false } },
["Forest (300)"]							= { "Forest"	, { false, false, 3    , false } },
["Forest (301)"]							= { "Forest"	, { false, false, false, 4     } },
["Token - Elemental (W)"] 					= { "Elemental"	, { 1    , false } },
["Token - Elemental (G)"] 					= { "Elemental"	, { false, 2     } }
},
[590] = { -- Champions of Kamigawa
["Plains"] 									= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (287)"]							= { "Plains"	, { 1    , false ,false, false } }, 
["Plains (288)"]							= { "Plains"	, { false, 2    , false, false } },
["Plains (289)"]							= { "Plains"	, { false, false, 3    , false } },
["Plains (290)"]							= { "Plains"	, { false, false, false, 4     } },
["Island (291)"]							= { "Island"	, { 1    , false, false, false } },
["Island (292)"]							= { "Island"	, { false, 2    , false, false } },
["Island (293)"]							= { "Island"	, { false, false, 3    , false } },
["Island (294)"]							= { "Island"	, { false, false, false, 4     } },
["Swamp (295)"]								= { "Swamp"		, { 1    , false, false, false } },
["Swamp (296)"]								= { "Swamp"		, { false, 2    , false, false } },
["Swamp (297)"]								= { "Swamp"		, { false, false, 3    , false } },
["Swamp (298)"]								= { "Swamp"		, { false, false, false, 4     } },
["Mountain (299)"]							= { "Mountain"	, { 1    , false, false, false } },
["Mountain (300)"]							= { "Mountain"	, { false, 2    , false, false } },
["Mountain (301)"]							= { "Mountain"	, { false, false, 3    , false } },
["Mountain (302)"]							= { "Mountain"	, { false, false, false, 4     } },
["Forest (303)"]							= { "Forest"	, { 1    , false, false, false } },
["Forest (304)"]							= { "Forest"	, { false, 2    , false, false } },
["Forest (305)"]							= { "Forest"	, { false, false, 3    , false } },
["Forest (306)"]							= { "Forest"	, { false, false, false, 4     } },
["Brothers Yamazaki"]						= { "Brothers Yamazaki"	, { "a"  , false } },
["Brothers Yamazaki (b)"]					= { "Brothers Yamazaki"	, { false, "b"   } }
},
[130] = { -- Antiquities
["Mishra's Factory (Spring - Version 1)"] 	= { "Mishra's Factory"		, { 1    , false, false, false } },
["Mishra's Factory (Summer - Version 2)"] 	= { "Mishra's Factory"		, { false, 2    , false, false } },
["Mishra's Factory (Autumn - Version 3)"] 	= { "Mishra's Factory"		, { false, false, 3    , false } },
["Mishra's Factory (Winter - Version 4)"] 	= { "Mishra's Factory"		, { false, false, false, 4     } },
["Strip Mine (Vers.1)"] 					= { "Strip Mine"			, { 1    , false, false, false } },
["Strip Mine (Vers.2)"] 					= { "Strip Mine"			, { false, 2    , false, false } },
["Strip Mine (Vers.3)"] 					= { "Strip Mine"			, { false, false, 3    , false } },
["Strip Mine (Vers.4)"] 					= { "Strip Mine"			, { false, false, false, 4     } },
["Urza's Mine (Vers.1)"] 					= { "Urza's Mine"			, { 1    , false, false, false } },
["Urza's Mine (Vers.2)"] 					= { "Urza's Mine"			, { false, 2    , false, false } },
["Urza's Mine (Vers.3)"] 					= { "Urza's Mine"			, { false, false, 3    , false } },
["Urza's Mine (Vers.4)"] 					= { "Urza's Mine"			, { false, false, false, 4     } },
["Urza's Power Plant (Vers.1)"] 			= { "Urza's Power Plant"	, { 1    , false, false, false } },
["Urza's Power Plant (Vers.2)"] 			= { "Urza's Power Plant"	, { false, 2    , false, false } },
["Urza's Power Plant (Vers.3)"] 			= { "Urza's Power Plant"	, { false, false, 3    , false } },
["Urza's Power Plant (Vers.4)"] 			= { "Urza's Power Plant"	, { false, false, false, 4     } },
["Urza's Tower (Vers.1)"] 					= { "Urza's Tower"			, { 1    , false, false, false } },
["Urza's Tower (Vers.2)"] 					= { "Urza's Tower"			, { false, 2    , false, false } },
["Urza's Tower (Vers.3)"] 					= { "Urza's Tower"			, { false, false, 3    , false } },
["Urza's Tower (Vers.4)"] 					= { "Urza's Tower"			, { false, false, false, 4     } }
},
[120] = { -- Arabian Nights
["Army of Allah"] 							= { "Army of Allah"			, { 1    , false } },
["Army of Allah (Vers. b)"] 				= { "Army of Allah"			, { false, 2     } },
["Bird Maiden"] 							= { "Bird Maiden"			, { 1    , false } },
["Bird Maiden (Vers. b)"] 					= { "Bird Maiden"			, { false, 2     } },
["Erg Raiders"] 							= { "Erg Raiders"			, { 1    , false } },
["Erg Raiders (Vers. b)"] 					= { "Erg Raiders"			, { false, 2     } },
["Fishliver Oil"] 							= { "Fishliver Oil"			, { 1    , false } },
["Fishliver Oil (Vers. b)"] 				= { "Fishliver Oil"			, { false, 2     } },
["Giant Tortoise"] 							= { "Giant Tortoise"		, { 1    , false } },
["Giant Tortoise (Vers. b)"]				= { "Giant Tortoise"		, { false, 2     } },
["Hasran Ogress"] 							= { "Hasran Ogress"			, { 1    , false } },
["Hasran Ogress (Vers. b)"] 				= { "Hasran Ogress"			, { false, 2     } },
["Moorish Cavalry"] 						= { "Moorish Cavalry"		, { 1    , false } },
["Moorish Cavalry (Vers. b)"]				= { "Moorish Cavalry"		, { false, 2     } },
["Nafs Asp"] 								= { "Nafs Asp"				, { 1    , false } },
["Nafs Asp (Vers. b)"] 						= { "Nafs Asp"				, { false, 2     } },
["Oubliette"] 								= { "Oubliette"				, { 1    , false } },
["Oubliette (Vers. b)"] 					= { "Oubliette"				, { false, 2     } },
["Rukh Egg"] 								= { "Rukh Egg"				, { 1    , false } },
["Rukh Egg (Vers. b)"] 						= { "Rukh Egg"				, { false, 2     } },
["Piety"] 									= { "Piety"					, { 1    , false } },
["Piety (Vers. b)"] 						= { "Piety"					, { false, 2     } },
["Stone-Throwing Devils"] 					= { "Stone-Throwing Devils"	, { 1    , false } },
["Stone-Throwing Devils (Vers. b)"] 		= { "Stone-Throwing Devils"	, { false, 2     } },
["War Elephant"] 							= { "War Elephant"			, { 1    , false } },
["War Elephant (Vers. b)"]		 			= { "War Elephant"			, { false, 2     } },
["Wyluli Wolf"] 							= { "Wyluli Wolf"			, { 1    , false } },
["Wyluli Wolf (Vers. b)"] 					= { "Wyluli Wolf"			, { false, 2     } }
}
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
--]]
} -- end table site.foiltweak

if CHECKEXPECTED then
--[[- table of expected results.
-- as of script release
-- { #number = #table { #table pset = #table { #number = #number, ... }, #table failed = #table { #number = #number, ... },	dropped = #number ,	namereplaced = #number }
-- 
--- @field [parent=#site] #table expected ]]
--- @field [parent=#site] #table expected
site.expected = {
-- Core sets
[788] = { pset={ 249+11,	[3]=249 },	failed={ 0,	[3]=11 },	dropped=0,	namereplaced=1 },-- ok
[779] = { pset={ 249+7,		[3]=249 },	failed={ 0,	[3]=7 },	dropped=0,	namereplaced=0 },-- ok
[770] = { pset={ 249+6,		[3]=255 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },-- ok
[759] = { pset={ 249+8,		[3]=257 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },-- ok
[720] = { pset={ 384-1+6,	[3]=388 },	failed={ 0,	[3]=1 },	dropped=0,	namereplaced=0 },-- ok
[630] = { pset={ 359-20,	[3]=332 },	failed={ 0,	[3]=7 },	dropped=0,	namereplaced=0 },-- ok
[550] = { pset={ 357-19,	[3]=336 },	failed={ 0,	[3]=2 },	dropped=0,	namereplaced=0 },-- ok
[460] = { pset={ 350-130,	[3]=220 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[180] = { pset={ 378-136,	[3]=242 },	failed={ 0,	[3]=1 },	dropped=0,	namereplaced=0 },-- ok
[140] = { pset={ 306,		[3]=46 },	failed={ 2,	[3]=1 },	dropped=199,namereplaced=3 },-- ok
[139] = { pset={ 0,			[3]=306 },	failed={ 0,	[3]=0 },	dropped=9,	namereplaced=19 },-- ok
[110] = { pset={ 302-24,	[3]=0 },	failed={ 0,	[3]=0 },	dropped=107,namereplaced=1 },-- ok
[100] = { pset={ 302-134,	[3]=0 },	failed={ 7,	[3]=0 },	dropped=352,namereplaced=1 },--ok
[90]  = { pset={ 295-61,	[3]=0 },	failed={ 0,	[3]=0 },	dropped=293,namereplaced=0 },-- ok
-- Expansions
[793] = { pset={ 249+8, 	[3]=249 },	failed={ 2,	[3]=10 },	dropped=0,	namereplaced=3 },--ok
[791] = { pset={ 274+12,	[3]=274 },	failed={ 0,	[3]=12 },	dropped=0,	namereplaced=0 },--ok
[786] = { pset={ 244+8,		[3]=244 },	failed={ 0,	[3]=6 },	dropped=0,	namereplaced=1 },--ok
[784] = { pset={ 158+3+1,	[3]=158 },	failed={ 0,	[3]=4 },	dropped=0,	namereplaced=27 },--ok
[782] = { pset={ 264+12+1,	[3]=264 },	failed={ 0,	[3]=10 },	dropped=0,	namereplaced=41 },--ok
[776] = { pset={ 175+4,		[3]=179 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },-- ok
[775] = { pset={ 155+5,		[3]=161 },	failed={ 1,	[3]=0 },	dropped=0,	namereplaced=1 },-- ok
[773] = { pset={ 249+9,		[3]=259 },	failed={ 1,	[3]=0 },	dropped=0,	namereplaced=1 },--ok
[767] = { pset={ 248+7,		[3]=255 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[765] = { pset={ 145+6,		[3]=151 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[762] = { pset={ 269-20+11,	[3]=260 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=1 },-- ok
[758] = { pset={ 145+4,		[3]=149 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[756] = { pset={ 145+2,		[3]=147 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[754] = { pset={ 249+10,	[3]=259 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[752] = { pset={ 180+7,		[3]=187 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[751] = { pset={ 301+12,	[3]=313 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[750] = { pset={ 150+3,		[3]=153 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=1 },--ok
[730] = { pset={ 301+11,	[3]=312 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=3 },--ok
[710] = { pset={ 180,		[3]=180 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },-- ok
[700] = { pset={ 165,		[3]=165 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[690] = { pset={ 121,		[3]=121 },	failed={ 298,[3]=298 },	dropped=0,	namereplaced=0 },--ok
[680] = { pset={ 301,		[3]=301 },	failed={ 121,[3]=121 },	dropped=0,	namereplaced=0 },--ok
[670] = { pset={ 155,		[3]=155 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[660] = { pset={ 180,		[3]=180 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[650] = { pset={ 165,		[3]=165 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[640] = { pset={ 306,		[3]=306 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=10 },--ok
[620] = { pset={ 165,		[3]=165 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=5 },--ok
[610] = { pset={ 165,		[3]=165 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=10 },--ok
[590] = { pset={ 307-20,	[3]=287 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=10 },--ok
[580] = { pset={ 165,		[3]=165 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[570] = { pset={ 165,		[3]=165 },	failed={ 0,	[3]=0 },	dropped=1,	namereplaced=0 },--ok
[560] = { pset={ 306-20,	[3]=286 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=1 },--ok
[540] = { pset={ 143,		[3]=143 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[530] = { pset={ 145,		[3]=145 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[520] = { pset={ 350-20,	[3]=330 },	failed={ 0,	[3]=0 },	dropped=3,	namereplaced=0 },--ok
[510] = { pset={ 143,		[3]=143 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[500] = { pset={ 143,		[3]=143 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=2 },--ok
[480] = { pset={ 350-20,	[3]=330 },	failed={ 0,	[3]=0 },	dropped=1,	namereplaced=0 },--ok
[470] = { pset={ 143,		[3]=143 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[450] = { pset={ 143,		[3]=143 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[430] = { pset={ 350-20,	[3]=330 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[420] = { pset={ 143,		[3]=0 },	failed={ 0,	[3]=143 },	dropped=0,	namereplaced=0 },--ok
[410] = { pset={ 143,		[3]=0 },	failed={ 0,	[3]=143 },	dropped=0,	namereplaced=0 },--ok
[400] = { pset={ 350-20,	[3]=0 },	failed={ 0,	[3]=330 },	dropped=0,	namereplaced=0 },--ok
[370] = { pset={ 143,		[3]=143 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[350] = { pset={ 143,		[3]=143 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[330] = { pset={ 350,		[3]=350 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[300] = { pset={ 143,		[3]=143 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[290] = { pset={ 143,		[3]=0 },	failed={ 0,	[3]=143 },	dropped=1,	namereplaced=0 },--ok
[280] = { pset={ 350-20,	[3]=330 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[270] = { pset={ 167,		[3]=167 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[240] = { pset={ 167,		[3]=167 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[230] = { pset={ 350-20,	[3]=330 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[220] = { pset={ 199,		[3]=199 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[210] = { pset={ 140,		[3]=140 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[190] = { pset={ 383-20,	[3]=363 },	failed={ 1,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[170] = { pset={ 187,		[3]=0 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=0 },--ok
[160] = { pset={ 119,		[3]=0 },	failed={ 0,	[3]=0 },	dropped=9,	namereplaced=0 },--ok
[150] = { pset={ 310, 		[5]=0 },	failed={ 0, [5]=19 },	dropped=87,	namereplaced=0 },--ok
[130] = { pset={ 100,		[3]=0 },	failed={ 3,	[3]=0 },	dropped=51,	namereplaced=0 },--ok
[120] = { pset={  92,		[3]=0 },	failed={ 0,	[3]=0 },	dropped=0,	namereplaced=1 },--ok
}
end
