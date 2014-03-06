--*- coding: utf-8 -*-
--[[- LHpi mtgprice.com sitescript
Price import script for Magic Album
uses and needs LHpi library
to import card pricing from www.mtgprice.com.

Inspired by and loosely based on "MTG Mint Card.lua" by Goblin Hero, Stromglad1 and "Import Prices.lua" by woogerboy21;
who generously granted permission to "do as I like" with their code;
everything else Copyright (C) 2012-2014 by Christian Harms.
If you want to contact me about the script, try its release thread in http://www.slightlymagic.net/forum/viewforum.php?f=32

@module LHpi.site
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
synchronized with template]]

-- options that control the amount of feedback/logging done by the script

--- more detailed log; default false
-- @field [parent=#global] #boolean VERBOSE
--VERBOSE = true
--- also log dropped cards; default false
-- @field [parent=#global] #boolean LOGDROPS
--LOGDROPS = true
--- also log namereplacements; default false
-- @field [parent=#global] #boolean LOGNAMEREPLACE
--LOGNAMEREPLACE = true
--- also log foiltweaking; default false
-- @field [parent=#global] #boolean LOGFOILTWEAK
--LOGFOILTWEAK = true

-- options that control the script's behaviour.

--- compare prices set and failed with expected numbers; default true
-- @field [parent=#global] #boolean CHECKEXPECTED
--CHECKEXPECTED = false

--  Don't change anything below this line unless you know what you're doing :-) --

--- also complain if drop,namereplace or foiltweak count differs; default false
-- @field [parent=#global] #boolean STRICTCHECKEXPECTED
--STRICTEXPECTED = true

--- log to seperate logfile instead of Magic Album.log;	default true
-- @field [parent=#global] #boolean SAVELOG
--SAVELOG = false

---	read source data from #string savepath instead of site url; default false
-- @field [parent=#global] #boolean OFFLINE
--OFFLINE = true

--- save a local copy of each source html to #string savepath if not in OFFLINE mode; default false
-- @field [parent=#global] #boolean SAVEHTML
--SAVEHTML = true

--- save price table to file before importing to MA;	default false
-- @field [parent=#global] #boolean SAVETABLE
--SAVETABLE = true

---	log everything and exit on error; default false
-- @field [parent=#global] #boolean DEBUG
--DEBUG = true

---	even while DEBUG, do not log raw html data found by regex; default true 
-- @field [parent=#global] #boolean DEBUGSKIPFOUND
--DEBUGFOUND = false

--- DEBUG (only but deeper) inside variant loops; default false
-- @field [parent=#global] #boolean DEBUGVARIANTS
--DEBUGVARIANTS = true

--- revision of the LHpi library to use
-- @field [parent=#global] #string libver
libver = "2.10"
--- revision of the LHpi library datafile to use
-- @field [parent=#global] #string dataver
dataver = "2"
--- sitescript revision number
-- @field [parent=#global] string scriptver
scriptver = "2"
--- should be similar to the script's filename. Used for loging and savepath.
-- @field [parent=#global] #string scriptname
scriptname = "LHpi.mtgprice.com-v" .. libver .. "." .. dataver .. "" .. scriptver .. ".lua"

---	LHpi library
-- will be loaded by ImportPrice
-- @field [parent=#global] #table LHpi
LHpi = {}

--[[- Site specific configuration
 Settings that define the source site's structure and functions that depend on it
 
 @type site ]]
site={}

--[[- regex matches shall include all info about a single card that one html-file has,
 i.e. "*CARDNAME*FOILSTATUS*PRICE*".
 it will be chopped into its parts by site.ParseHtmlData later. 
 @field [parent=#site] #string regex ]]
--site.regex = '<tr><td>(<a href ="/sets/.->)</td></tr>'
site.regex = '<tr><td>(<a href ="/sets/[^>]+>[^<]+</a> </td><td>[$0-9.,]+)</td></tr>'

--- resultregex can be used to display in the Log how many card the source file claims to contain
-- @field #string resultregex
--site.resultregex = "Your query of .+ filter.+ returns (%d+) results."

--- @field #string currency		not used yet;default "$"
--site.currency = "$"
--- @field #string encoding		default "cp1252"
--site.encoding="cp1252"

--[[- "main" function.
 called by Magic Album to import prices. Parameters are passed from MA.
 
 @function [parent=#global] ImportPrice
 @param #string importfoil	"Y"|"N"|"O"
	-- parameter passed from Magic Album
	-- "Y"|"N"|"O"		Update Regular and Foil|Update Regular|Update Foil
 @param #table importlangs	{ #number (langid)= #string , ... }
	-- parameter passed from Magic Album
	-- array of languages the script should import, represented as pairs { #number = #string } (see "Database\Languages.txt").
 @param #table importsets	{ #number (setid)= #string , ... }
	-- parameter passed from Magic Album
	-- array of sets the script should import, represented as pairs { #number = #string } (see "Database\Sets.txt").
]]
function ImportPrice( importfoil , importlangs , importsets )
	if SAVELOG~=false then
		ma.Log( "Check " .. scriptname .. ".log for detailed information" )
	end
	ma.SetProgress( "Loading LHpi library", 0 )
	do -- load LHpi library from external file
		local libname = "Prices\\lib\\LHpi-v" .. libver .. ".lua"
		local LHpilib = ma.GetFile( libname )
		local oldlibname = "Prices\\LHpi-v" .. libver .. ".lua"
		local oldLHpilib = ma.GetFile ( oldlibname )
		local loglater = ""
		if oldLHpilib then
			if DEBUG then
				error("LHpi library found in deprecated location. Please move it to Prices\\lib subdirectory!")
			end
			loglater = loglater .. "LHpi library found in deprecated location.\n"
			if not LHpilib then
				loglater = loglater .. "Using file in old location as fallback."
				LHpilib = oldLHpilib
			end
		end
		if not LHpilib then
			error( "LHpi library " .. libname .. " not found." )
		else -- execute LHpilib to make LHpi.* available
			LHpilib = string.gsub( LHpilib , "^\239\187\191" , "" ) -- remove unicode BOM (0xEF, 0xBB, 0xBF) for files tainted by it :)
			if VERBOSE then
				ma.Log( "LHpi library " .. libname .. " loaded and ready for execution." )
			end
			local execlib,errormsg = load( LHpilib , "=(load) LHpi library" )
			if not execlib then
				error( errormsg )
			end
			LHpi = execlib()
		end	-- if not LHpilib else
		LHpi.Log(loglater)
	end -- do load LHpi library
	collectgarbage() -- we now have LHpi table with all its functions inside, let's clear LHpilib and execlib() from memory
	LHpi.Log( "LHpi lib is ready to use." )
	LHpi.DoImport (importfoil , importlangs , importsets)
	ma.Log( "End of Lua script " .. scriptname )
end -- function ImportPrice

--[[-  build source url/filename.
 Has to be done in sitescript since url structure is site specific.
 To allow returning more than one url here, BuildUrl is required to wrap it/them into a container table.

 foilonly and isfile fields can be nil and then are assumed to be false.
 while isfile is read and interpreted by the library, foilonly is not.
 Its only here as a convenient shortcut to set card.foil in your site.ParseHtmlData  
 
 @function [parent=#site] BuildUrl
 @param #number setid		see site.sets
 @param #number langid		see site.langs
 @param #number frucid		see site.frucs
 @param #boolean offline	(can be nil) use local file instead of url
 @return #table { #string (url)= #table { isfile= #boolean, (optional) foilonly= #boolean } , ... }
]]
function site.BuildUrl( setid,langid,frucid,offline )
	site.domain = "www.mtgprice.com"
	site.setprefix = "/spoiler_lists/"
	
	local container = {}
	local url = site.domain .. site.setprefix .. site.sets[setid].url .. site.frucs[frucid].url
	if offline then
		string.gsub( url, "%?", "_" )
		string.gsub( url, "/", "_" )
		container[url] = { isfile = true}
	else
		container[url] = {}
	end -- if offline 
	
--	if string.find( url , "[Ff][Oo][Ii][Ll]" ) then -- mark url as foil-only
--		container[url].foilonly = true
--	else
--		-- url without foil marker
--	end -- if foil-only url
	return container
end -- function site.BuildUrl

--[[-  get data from foundstring.
 Has to be done in sitescript since html raw data structure is site specific.
 To allow returning more than one card here (foil and nonfoil versions are considered seperate cards!),
 ParseHtmlData is required to wrap it/them into a container table.
 
 Price is returned as whole number to generalize decimal and digit group separators
 ( 1.000,00 vs 1,000.00 ); LHpi library then divides the price by 100 again.
 This is, of course, not optimal for speed, but the most flexible.

 Return value newCard can receive optional additional fields:
 @return #boolean newcard.foil		(semi-optional) set the card as foil. It's often a good idea to explicitely set this, for example by querying site.frucs[urldetails.frucid].isfoil
 @return #table newCard.pluginData	(optional) is passed on by LHpi.buildCardData for use in site.BCDpluginName and/or site.BCDpluginCard.
 @return #string newCard.name		(optional) will pre-set the card's unique (for the cardsetTable) identifying name.
 @return #table newCard.lang		(optional) will override LHpi.buildCardData generated values.
 @return #boolean newCard.drop		(optional) will override LHpi.buildCardData generated values.
 @return #table newCard.variant		(optional) will override LHpi.buildCardData generated values.
 @return #table newCard.regprice	(optional) will override LHpi.buildCardData generated values.
 @return #table newCard.foilprice 	(optional) will override LHpi.buildCardData generated values.
 
 @function [parent=#site] ParseHtmlData
 @param #string foundstring		one occurence of siteregex from raw html data
 @param #table urldetails		{ isfile= #boolean , setid= #number, langid= #number, frucid= #number , foilonly= #boolean }
 @return #table { #number= #table { names= #table { #number (langid)= #string , ... }, price= #number , foil= #boolean , ... } , ... } 
]]
function site.ParseHtmlData( foundstring , urldetails )
	local _start,_end,name = string.find(foundstring, '<a.->([^<]+)</a>' )
	local _start,_end,price = string.find( foundstring , '[$€]([%d.,]+)' )
	price = string.gsub( price , "[,.]" , "" )
	price = tonumber( price )
	local newCard = { names = { [urldetails.langid] = name }, price = { [urldetails.langid] = price } }
	if site.frucs[urldetails.frucid].isfoil and not site.frucs[urldetails.frucid].isnonfoil then
		newCard.foil = true
	end
	if DEBUG then
		LHpi.Log( "site.ParseHtmlData\t returns" .. LHpi.Tostring(newCard) , 2 )
	end
	return { newCard }
end -- function site.ParseHtmlData

--[[- special cases card data manipulation.
 Ties into LHpi.buildCardData to make changes that are specific to one site and thus don't belong into the library.
 This Plugin is called before most of LHpi's BuildCardData processing.

 @function [parent=#site] BCDpluginPre
 @param #table card			the card LHpi.BuildCardData is working on
 			{ name= #string , lang= #table , names= #table , pluginData= #table or nil , (preset fields) }
 @param #number setid		see site.sets 
 @param #string importfoil	"y"|"n"|"o" passed from DoImport to drop unwanted cards
 @param #table importlangs	{ #number (langid)= #string , ... } passed from DoImport to drop unwanted cards
 @return #table 		modified card is passed back for further processing
 			{ name= #string , (optional) drop= #boolean , lang= #table , (optional) names= #table , (optional) pluginData= #table , (preset fields) }
]]
--function site.BCDpluginPre ( card, setid, importfoil, importlangs )
--	if DEBUG then
--		LHpi.Log( "site.BCDpluginPre got " .. LHpi.Tostring( card ) .. " from set " .. setid , 2 )
--	end
--
--	-- if you don't want a full namereplace table, gsubs like this might take care of a lot of fails.
--	card.name = string.gsub( card.name , "AE" , "Æ")
--	card.name = string.gsub( card.name , "Ae" , "Æ")
--
--	return card
--end -- function site.BCDpluginPre

--[[- special cases card data manipulation.
 Ties into LHpi.buildCardData to make changes that are specific to one site and thus don't belong into the library
 This Plugin is called after LHpi's BuildCardData processing (and probably not needed).
 
 @function [parent=#site] BCDpluginPost
 @param #table card		the card LHpi.BuildCardData is working on
 			{ name= #string , (can be nil) drop= #boolean , lang= #table , (can be nil) names= #table , (can be nil) variant= #table , (can be nil) regprice= #table , (can be nil) foilprice= #table }
 @param #number setid		see site.sets 
 @param #string importfoil	"y"|"n"|"o" passed from DoImport to drop unwanted cards
 @param #table importlangs	{ #number (langid)= #string , ... } passed from DoImport to drop unwanted cards
 @return #table			modified card is passed back for further processing
 			{ name= #string , drop= #boolean, lang= #table , (optional) names= #table , variant= (#table or nil), regprice= #table , foilprice= #table }
]]
--function site.BCDpluginPost( card , setid , importfoil, importlangs )
--	if DEBUG then
--		LHpi.Log( "site.BCDpluginPost got " .. LHpi.Tostring( card ) .. " from set " .. setid , 2 )
--	end
--
--	card.pluginData=nil
--	return card
--end -- function site.BCDpluginPost

-------------------------------------------------------------------------------------------------------------
-- tables
-------------------------------------------------------------------------------------------------------------

--[[- table of (supported) languages.
 can contain url infixes for use in site.BuildUrl.
 static language fields (full,abbr) can be read from LHpi.Data.languages.

 fields are for subtables indexed by #number langid.
 { #number (langid)= { id= #number , url= #string } , ... }
 
 @type site.langs
 @field [parent=#site.langs] #number id		for reverse lookup (can be found in "..\Database\Languages.txt" file)
 @field [parent=#site.langs] #string url	infix for site.BuildUrl
]]
site.langs = {
	[1] = { id=1, url="" },
}

--[[- table of available rarities.
 can contain url infixes for use in site.BuildUrl.

  fields are for subtables indexed by #number frucid.
 { #number= { id= #number , name= #string , isfoil= #boolean , isnonfoil= #boolean , url= #string } , ... }
 
 @type site.frucs
 @field [parent=#site.langs] #number id		for reverse lookup
 @field [parent=#site.frucs] #string name	for log
 @field [parent=#site.frucs] #boolean isfoil
 @field [parent=#site.frucs] #boolean isnonfoil
 @field [parent=#site.langs] #string url	infix for site.BuildUrl
]]
site.frucs = {
	[1]= { id=1, name="Foil"	, isfoil=true , isnonfoil=false, url="_(Foil)" },
	[2]= { id=2, name="nonFoil"	, isfoil=false, isnonfoil=true , url="" },
}

--[[- table of available sets.
 List alls sets that the site has prices for,
 and defines which frucs and languages are available for the set.
 can contain url infixes for use in site.BuildUrl.
 
 fields are for subtables indexed by #number setid.
 { #number (setid)= #table { id= #number , lang= #table { #boolean, ... } , fruc= #table { #boolean , ... } , url= #string } , ... }
 
 @type site.sets
 @field [parent=#site.sets] #number id		for reverse lookup (can be found in "..\Database\Sets.txt" file)
 @field [parent=#site.sets] #table lang		{ #number (langid)= #boolean , ... }
 @field [parent=#site.sets] #table fruc		{ #number (frucid)= #boolean , ... }
 @field [parent=#site.sets] #string url		infix for site.BuildUrl
]]
site.sets = {
-- Core Sets
[797]={id = 797, lang = { [1]=true }, fruc = { true , true }, url = "M14"},
[788]={id = 788, lang = { [1]=true }, fruc = { true , true }, url = "M13"},
[779]={id = 779, lang = { [1]=true }, fruc = { true , true }, url = "M12"},
[770]={id = 770, lang = { [1]=true }, fruc = { true , true }, url = "M11"},
[759]={id = 759, lang = { [1]=true }, fruc = { true , true }, url = "M10"},
[720]={id = 720, lang = { [1]=true }, fruc = { true , true }, url = "10th_Edition"},
[630]={id = 630, lang = { [1]=true }, fruc = { true , true }, url = "9th_Edition"},
[550]={id = 550, lang = { [1]=true }, fruc = { true , true }, url = "8th_Edition"},
[460]={id = 460, lang = { [1]=true }, fruc = { true , true }, url = "7th_Edition"},
[360]={id = 360, lang = { [1]=true }, fruc = { false, true }, url = "6th_Edition"},
[250]={id = 250, lang = { [1]=true }, fruc = { false, true }, url = "5th_Edition"},
[180]={id = 180, lang = { [1]=true }, fruc = { false, true }, url = "4th_Edition"},
[141]=nil,--Revised Summer Magic
[140]={id = 140, lang = { [1]=true }, fruc = { false, true }, url = "Revised"},--Revised
[139]=nil,--Revised Limited Deutsch
[110]={id = 110, lang = { [1]=true }, fruc = { false, true }, url = "Unlimited"},
[100]={id = 100, lang = { [1]=true }, fruc = { false, true }, url = "Beta"},
[90] ={id =  90, lang = { [1]=true }, fruc = { false, true }, url = "Alpha"},
-- Expansions
[802]={id = 802, lang = { [1]=true }, fruc = { true , true }, url = "Born_of_the_Gods"},
[800]={id = 800, lang = { [1]=true }, fruc = { true , true }, url = "Theros"},
[795]={id = 795, lang = { [1]=true }, fruc = { true , true }, url = "Dragons_Maze"},
[793]={id = 793, lang = { [1]=true }, fruc = { true , true }, url = "Gatecrash"},
[791]={id = 791, lang = { [1]=true }, fruc = { true , true }, url = "Return_to_Ravnica"},
[786]={id = 786, lang = { [1]=true }, fruc = { true , true }, url = "Avacyn_Restored"},
[784]={id = 784, lang = { [1]=true }, fruc = { true , true }, url = "Dark_Ascension"},
[782]={id = 782, lang = { [1]=true }, fruc = { true , true }, url = "Inistrad"},
[776]={id = 776, lang = { [1]=true }, fruc = { true , true }, url = "New_Phyrexia"},
[775]={id = 775, lang = { [1]=true }, fruc = { true , true }, url = "Mirrodin_Besieged"},
[773]={id = 773, lang = { [1]=true }, fruc = { true , true }, url = "Scars_of_Mirrodin"},
[767]={id = 767, lang = { [1]=true }, fruc = { true , true }, url = "Rise_of_the_Eldrazi"},
[765]={id = 765, lang = { [1]=true }, fruc = { true , true }, url = "Worldwake"},
[762]={id = 762, lang = { [1]=true }, fruc = { true , true }, url = "Zendikar"},
[758]={id = 758, lang = { [1]=true }, fruc = { true , true }, url = "Alara_Reborn"},
[756]={id = 756, lang = { [1]=true }, fruc = { true , true }, url = "Conflux"},
[754]={id = 754, lang = { [1]=true }, fruc = { true , true }, url = "Shards_of_Alara"},
[752]={id = 752, lang = { [1]=true }, fruc = { true , true }, url = "Eventide"},
[751]={id = 751, lang = { [1]=true }, fruc = { true , true }, url = "Shadowmoor"},
[750]={id = 750, lang = { [1]=true }, fruc = { true , true }, url = "Morningtide"},
[730]={id = 730, lang = { [1]=true }, fruc = { true , true }, url = "Lorwyn"},
[710]={id = 710, lang = { [1]=true }, fruc = { true , true }, url = "Future_Sight"},
[700]={id = 700, lang = { [1]=true }, fruc = { true , true }, url = "Planar_Chaos"},
-- for Timeshifted and Timespiral, lots of expected fails due to shared urls
[690]={id = 690, lang = { [1]=true }, fruc = { true , true }, url = "Time Spiral"},--Time Spiral Timeshifted
[680]={id = 680, lang = { [1]=true }, fruc = { true , true }, url = "Time Spiral"},--Time Spiral
[670]={id = 670, lang = { [1]=true }, fruc = { true , true }, url = "Coldsnap"},
[660]={id = 660, lang = { [1]=true }, fruc = { true , true }, url = "Dissension"},
[650]={id = 650, lang = { [1]=true }, fruc = { true , true }, url = "Guildpact"},
[640]={id = 640, lang = { [1]=true }, fruc = { true , true }, url = "Ravnica"},--Ravnica: City of Guilds
[620]={id = 620, lang = { [1]=true }, fruc = { true , true }, url = "Saviors_of_Kamigawa"},
[610]={id = 610, lang = { [1]=true }, fruc = { true , true }, url = "Betrayers_of_Kamigawa"},
[590]={id = 590, lang = { [1]=true }, fruc = { true , true }, url = "Champions_of_Kamigawa"},
[580]={id = 580, lang = { [1]=true }, fruc = { true , true }, url = "Fifth_Dawn"},
[570]={id = 570, lang = { [1]=true }, fruc = { true , true }, url = "Darksteel"},
[560]={id = 560, lang = { [1]=true }, fruc = { true , true }, url = "Mirrodin"},
[540]={id = 540, lang = { [1]=true }, fruc = { true , true }, url = "Scourge"},
[530]={id = 530, lang = { [1]=true }, fruc = { true , true }, url = "Legions"},
[520]={id = 520, lang = { [1]=true }, fruc = { true , true }, url = "Onslaught"},
[510]={id = 510, lang = { [1]=true }, fruc = { true , true }, url = "Judgment"},
[500]={id = 500, lang = { [1]=true }, fruc = { true , true }, url = "Torment"},
[480]={id = 480, lang = { [1]=true }, fruc = { true , true }, url = "Odyssey"},
[470]={id = 470, lang = { [1]=true }, fruc = { true , true }, url = "Apocalypse"},
[450]={id = 450, lang = { [1]=true }, fruc = { true , true }, url = "Planeshift"},
[430]={id = 430, lang = { [1]=true }, fruc = { true , true }, url = "Invasion"},
[420]={id = 420, lang = { [1]=true }, fruc = { true , true }, url = "Prophecy"},
[410]={id = 410, lang = { [1]=true }, fruc = { true , true }, url = "Nemesis"},
[400]={id = 400, lang = { [1]=true }, fruc = { true , true }, url = "Mercadian_Masques"},
[370]={id = 370, lang = { [1]=true }, fruc = { true , true }, url = "Urzas_Destiny"}, 
[350]={id = 350, lang = { [1]=true }, fruc = { true , true }, url = "Urzas_Legacy"},
[330]={id = 330, lang = { [1]=true }, fruc = { false, true }, url = "Urzas_Saga"},
[300]={id = 300, lang = { [1]=true }, fruc = { false, true }, url = "Exodus"},
[290]={id = 290, lang = { [1]=true }, fruc = { false, true }, url = "Stronghold"},
[280]={id = 280, lang = { [1]=true }, fruc = { false, true }, url = "Tempest"},
[270]={id = 270, lang = { [1]=true }, fruc = { false, true }, url = "Weatherlight"},
[240]={id = 240, lang = { [1]=true }, fruc = { false, true }, url = "Visions"},
[230]={id = 230, lang = { [1]=true }, fruc = { false, true }, url = "Mirage"},
[220]={id = 220, lang = { [1]=true }, fruc = { false, true }, url = "Alliances"},
[210]={id = 210, lang = { [1]=true }, fruc = { false, true }, url = "Homelands"},
[190]={id = 190, lang = { [1]=true }, fruc = { false, true }, url = "Ice_Age"},
[170]={id = 170, lang = { [1]=true }, fruc = { false, true }, url = "Fallen_Empires"},
[160]={id = 160, lang = { [1]=true }, fruc = { false, true }, url = "The_Dark"},
[150]={id = 150, lang = { [1]=true }, fruc = { false, true }, url = "Legends"},
[130]={id = 130, lang = { [1]=true }, fruc = { false, true }, url = "Antiquities"},
[120]={id = 120, lang = { [1]=true }, fruc = { false, true }, url = "Arabian_Nights"},
-- special sets
--TODO FtV are foilonly. check all frucs
--[801]={id = 801, lang = { [1]=true }, fruc = { true , true }, url = "C13"},--Commander 2013
--[799]={id = 799, lang = { [1]=true }, fruc = { false, true }, url = "DDL"},--Duel Decks: Heroes vs. Monsters
--[798]={id = 798, lang = { [1]=true }, fruc = { true , false}, url = "V13"},--From the Vault: Twenty
--[796]={id = 796, lang = { [1]=true }, fruc = { true , true }, url = "Modern_Masters"},
--[794]={id = 794, lang = { [1]=true }, fruc = { false, true }, url = "DDK"},--Duel Decks: Sorin vs. Tibalt
--[792]={id = 792, lang = { [1]=true }, fruc = { false, true }, url = "Commanders_Arsenal"},
--[790]={id = 790, lang = { [1]=true }, fruc = { false, true }, url = "Duel_Decks_Izzet_vs_Golgari"},
--[789]={id = 789, lang = { [1]=true }, fruc = { true , false}, url = "From_the_Vault_Realms"},
--TODO "Planechase_2012_Planes" is subset of 787
--[787]={id = 787, lang = { [1]=true }, fruc = { false, true }, url = "Planechase_2012"},--Planechase 2012
--[785]={id = 785, lang = { [1]=true }, fruc = { false, true }, url = "Duel_Decks_Venser_vs_Koth"},
--[783]={id = 783, lang = { [1]=true }, fruc = { true , false}, url = "Premium_Deck_Series_Graveborn"},
--[781]={id = 781, lang = { [1]=true }, fruc = { false, true }, url = "Duel_Decks_Ajani_vs_Nicol_Bolas"},
--[780]={id = 780, lang = { [1]=true }, fruc = { true , false}, url = "From_the_Vault_Legends"},
--TODO Commander has oversized in MA, not in url
--[778]={id = 778, lang = { [1]=true }, fruc = { false, true }, url = "Commander"},
--[777]={id = 777, lang = { [1]=true }, fruc = { false, true }, url = "Duel_Decks_Knights_vs_Dragons"},
--[774]={id = 774, lang = { [1]=true }, fruc = { true , false}, url = "Premium_Deck_Series_Fire_and_Lightning"},
--[772]={id = 772, lang = { [1]=true }, fruc = { false, true }, url = "Duel_Decks_Elspeth_vs_Tezzeret"},
--[771]={id = 771, lang = { [1]=true }, fruc = { true , false}, url = "From_the_Vault_Relics"},
--TODO Archenemy_Schemes is subset of 769
--[769]={id = 769, lang = { [1]=true }, fruc = { false, true }, url = "Archenemy"},
--[768]=nil,--Duels of the Planeswalkers
--[766]={id = 766, lang = { [1]=true }, fruc = { false, true }, url = "Duel_Decks_Phyrexia_vs_The_Coalition"},
--[764]={id = 764, lang = { [1]=true }, fruc = { true , false}, url = "Premium_Deck_Series_Slivers"},
--[763]={id = 763, lang = { [1]=true }, fruc = { false, true }, url = "Duel_Decks_Garruk_vs_Liliana"},
-- TODO Plancechase_Planes is subset of 761
--[761]={id = 761, lang = { [1]=true }, fruc = { false, true }, url = "Planechase"},--Planechase
--[760]={id = 760, lang = { [1]=true }, fruc = { true , false}, url = "From_the_Vault_Exiled"},
--[757]={id = 757, lang = { [1]=true }, fruc = { false, true }, url = "Duel_Decks_Divine_vs_Demonic"},
--[755]={id = 755, lang = { [1]=true }, fruc = { false, true }, url = "Duel_Decks_Jace_vs_Chandra"},
--[753]={id = 753, lang = { [1]=true }, fruc = { true , false}, url = "From_the_Vault_Dragons"},
--[740]={id = 740, lang = { [1]=true }, fruc = { false, true }, url = "Duel_Decks_Elves_vs_Goblins"},
--[675]={id = 675, lang = { [1]=true }, fruc = { false, true }, url = ""},--Coldsnap Theme Decks
--[635]={id = 635, lang = { [1]=true }, fruc = {  }, url = ""},--Magic Encyclopedia
--[600]={id = 600, lang = { [1]=true }, fruc = { false, true }, url = "Unhinged"},--no foils on site
--[490]={id = 490, lang = { [1]=true }, fruc = { false, true }, url = "Deckmasters_Box_Set"},--Deckmaster --TODO foiltweak
--[440]={id = 440, lang = { [1]=true }, fruc = { false, true }, url = "Beatdown_Box_Set"},
--[415]={id = 415, lang = { [1]=true }, fruc = { false, true }, url = "Starter_2000"},--TODO foiltweak
--[405]={id = 405, lang = { [1]=true }, fruc = { false, true }, url = "Battle_Royale_Box_Set"},
--[390]={id = 390, lang = { [1]=true }, fruc = { false, true }, url = "Starter_1999"},
--[380]={id = 380, lang = { [1]=true }, fruc = { false, true }, url = "Portal_Three_Kingdoms"},   
--[340]={id = 340, lang = { [1]=true }, fruc = {  }, url = "ATH"},--Anthologies
--[320]={id = 320, lang = { [1]=true }, fruc = { false, true }, url = "Unglued"},
--[310]={id = 310, lang = { [1]=true }, fruc = { false, true }, url = "Portal_Second_Age"},   
--[260]={id = 260, lang = { [1]=true }, fruc = { false, true }, url = "Portal"},
--[225]={id = 225, lang = { [1]=true }, fruc = {  }, url = ""},--Introductory Two-Player Set
--[201]={id = 201, lang = { [1]=true }, fruc = {  }, url = ""},--Renaissance
--[200]={id = 200, lang = { [1]=true }, fruc = { false, true }, url = "Chronicles"},
--[70] ={id =  70, lang = { [1]=true }, fruc = { true , false}, url = "VAN"},--Vanguard
--[69] ={id =  69, lang = { [1]=true }, fruc = {  }, url = ""},--Box Topper Cards
-- Promo Cards
--[50] ={id =  50, lang = { [1]=true }, fruc = {  }, url = ""},--Full Box Promotion
--[45] ={id =  45, lang = { [1]=true }, fruc = {  }, url = ""},--Magic Premiere Shop
--[43] ={id =  43, lang = { [1]=true }, fruc = { true , false}, url = "Two-Headed_Giant"},
--[42] ={id =  42, lang = { [1]=true }, fruc = { true , false}, url = "Summer of Magic"},
--[41] ={id =  41, lang = { [1]=true }, fruc = { true , false}, url = "Happy_Holidays"},
--[40] ={id =  40, lang = { [1]=true }, fruc = { true , false}, url = "Arena_League"},
--[33] ={id =  33, lang = { [1]=true }, fruc = {  }, url = ""},--Championships Prizes
--[32] ={id =  32, lang = { [1]=true }, fruc = { true , false}, url = "Pro_Tour"},
--[31] ={id =  31, lang = { [1]=true }, fruc = { true , false}, url = "Grand_Prix"},
--[30] ={id =  30, lang = { [1]=true }, fruc = { true , false}, url = "Friday_Night_Magic"},
-- subsets of 27: "Euro_Land_Program" , "Guru" , "Asia Pacific Land Program"
--[27] ={id =  27, lang = { [1]=true }, fruc = {  }, url = ""},--Alternate Art Lands
--[26] ={id =  26, lang = { [1]=true }, fruc = { true , false}, url = "Game_Day"},
--[25] ={id =  25, lang = { [1]=true }, fruc = { true , false}, url = "Judge_Gift_Program"},
--TODO half of the cards are foilonly
--[24] ={id =  24, lang = { [1]=true }, fruc = { true , false}, url = "Champs"},
--[23] ={id =  23, lang = { [1]=true }, fruc = { false, true }, url = "Gateway"},--Gateway & WPN Promos
--[22] ={id =  22, lang = { [1]=true }, fruc = { true , false}, url = "Prerelease_Events"},
----TODO Release_Events is subset of 21
--[21] ={id =  21, lang = { [1]=true }, fruc = { true , false}, url = "Launch_Parties"},--Release & Launch Party Cards
--[20] ={id =  20, lang = { [1]=true }, fruc = { true , false}, url = "Player_Rewards"},--Magic Player Rewards
--[15] ={id =  15, lang = { [1]=true }, fruc = {  }, url = ""},--Convention Promos
--[12] ={id =  12, lang = { [1]=true }, fruc = {  }, url = ""},--Hobby Japan Commemorative Cards
--[11] ={id =  11, lang = { [1]=true }, fruc = {  }, url = ""},--Redemption Program Cards
--[10] ={id =  10, lang = { [1]=true }, fruc = {  }, url = ""},--Junior Series Promos
--[9]  ={id =   9, lang = { [1]=true }, fruc = {  }, url = ""},--Video Game Promos
--[8]  ={id =   8, lang = { [1]=true }, fruc = {  }, url = ""},--Stores Promos
--[7]  ={id =   7, lang = { [1]=true }, fruc = {  }, url = ""},--Magazine Inserts
--[6]  ={id =   6, lang = { [1]=true }, fruc = {  }, url = ""},--Comic Inserts
--[5]  ={id =   5, lang = { [1]=true }, fruc = {  }, url = ""},--Book Inserts
--[4]  ={id =   4, lang = { [1]=true }, fruc = {  }, url = ""},--Ultra Rare Cards
--[2]  ={id =   2, lang = { [1]=true }, fruc = { false,true }, url = "Legend_Membership"},
--TODO what is "15th_Anniversary" ?
--TODO what is "World_Magic_Cup_Qualifier" ?
--TODO what is "Super_Series" ?
--TODO sort out "Media_Inserts"
} -- end table site.sets

--[[- card name replacement tables.

  fields are for subtables indexed by #number setid.
 { #number (setid)= #table { #string (oldname)= #string , ... } , ... }
 
 @type site.namereplace
 @field [parent=#site.namereplace] #string name
]]
site.namereplace = {
--[[
--TODO probably needs this for each set with basic lands.
--see LHpi.Data (or MA) for collector numbers to go with the land versions
[]={
["Forest (1)"]			= "Forest ()",
["Forest (2)"]			= "Forest ()",
["Forest (3)"]			= "Forest ()",
["Forest (4)"]			= "Forest ()",
["Forest (5)"]			= "Forest ()",
["Island (1)"]			= "Island ()",
["Island (2)"]			= "Island ()",
["Island (3)"]			= "Island ()",
["Island (4)"]			= "Island ()",
["Island (5)"]			= "Island ()",
["Swamp (1)"]			= "Swamp ()",
["Swamp (2)"]			= "Swamp ()",
["Swamp (3)"]			= "Swamp ()",
["Swamp (4)"]			= "Swamp ()",
["Swamp (5)"]			= "Swamp ()",
["Mountain (1)"]		= "Mountain ()",
["Mountain (2)"]		= "Mountain ()",
["Mountain (3)"]		= "Mountain ()",
["Mountain (4)"]		= "Mountain ()",
["Mountain (5)"]		= "Mountain ()",
["Forest (1)"]			= "Forest ()",
["Forest (2)"]			= "Forest ()",
["Forest (3)"]			= "Forest ()",
["Forest (4)"]			= "Forest ()",
["Forest (5)"]			= "Forest ()",
},
]]
-- Core Sets
[797]={--M14
["Plains (1)"]			= "Plains (230)",
["Plains (2)"]			= "Plains (231)",
["Plains (3)"]			= "Plains (232)",
["Plains (4)"]			= "Plains (233)",
["Island (1)"]			= "Island (234)",
["Island (2)"]			= "Island (235)",
["Island (3)"]			= "Island (236)",
["Island (4)"]			= "Island (237)",
["Swamp (1)"]			= "Swamp (238)",
["Swamp (2)"]			= "Swamp (239)",
["Swamp (3)"]			= "Swamp (240)",
["Swamp (4)"]			= "Swamp (241)",
["Mountain (1)"]		= "Mountain (242)",
["Mountain (2)"]		= "Mountain (243)",
["Mountain (3)"]		= "Mountain (244)",
["Mountain (4)"]		= "Mountain (245)",
["Forest (1)"]			= "Forest (246)",
["Forest (2)"]			= "Forest (247)",
["Forest (3)"]			= "Forest (248)",
["Forest (4)"]			= "Forest (249)",
},
} -- end table site.namereplace

--[[- card variant tables.
 tables of cards that need to set variant.
 For each setid, will be merged with sensible defaults from LHpi.Data.sets[setid].variants.
 When variants for the same card are set here and in LHpi.Data, sitescript's entry overwrites Data's.
 
 fields are for subtables indexed by #number setid.
 { #number (setid)= #table { #string (name)= #table { #string, #table { #string or #boolean , ... } } , ... } , ...  }

 @type site.variants
 @field [parent=#site.variants] #boolean override	(optional) if true, defaults from LHpi.Data will not be used at all
 @field [parent=#site.variants] #table variant
]]
site.variants = {
--[0] = { -- Basic Lands as example (setid 0 is not used)
--override=false,
--["Plains"] 					= { "Plains"	, { 1    , 2    , 3    , 4     } },
--["Island"] 					= { "Island" 	, { 1    , 2    , 3    , 4     } },
--["Swamp"] 					= { "Swamp"		, { 1    , 2    , 3    , 4     } },
--["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
--["Forest"] 					= { "Forest" 	, { 1    , 2    , 3    , 4     } }
--},
} -- end table site.variants

--[[- foil status replacement tables.
 tables of cards that need to set foilage.
 For each setid, will be merged with sensible defaults from LHpi.Data.sets[setid].variants.
 When variants for the same card are set here and in LHpi.Data, sitescript's entry overwrites Data's.

  fields are for subtables indexed by #number setid.
 { #number (setid)= #table { #string (name)= #table { foil= #boolean } , ... } , ... }
 
 @type site.foiltweak
 @field [parent=#site.variants] #boolean override	(optional) if true, defaults from LHpi.Data will not be used at all
 @field [parent=#site.foiltweak] #table foilstatus
]]
site.foiltweak = {
} -- end table site.foiltweak

if CHECKEXPECTED~=false then
--[[- table of expected results.
 as of script release. Used as sanity check during sitescript development and source of insanity afterwards ;-)
 For each setid, if unset defaults to expect all cards to be set.
 
  fields are for subtables indexed by #number setid.
 { #number (setid)= #table { #table pset= #table { #number (langid)= #number, ... }, #table failed= #table { #number (langid)= #number, ... }, dropped= #number , namereplaced= #number , foiltweaked= #number } , ... }
 
 @type site.expected
 @field #table pset				{ #number (langid)= #number, ... } (optional) default depends on site.expected.EXPECTTOKENS
 @field #table failed			{ #number (langid)= #number, ... } (optional) default { 0 , ... }
 @field #number dropped			(optional) default 0
 @field #number namereplaced	(optional) default 0
 @field #number foiltweaked		(optional) default 0
 ]]
site.expected = {
--- false:pset defaults to regular, true:pset defaults to regular+tokens instead
-- @field [parent=#site.expected] #boolean EXPECTTOKENS
EXPECTTOKENS = false,
-- -- Core sets
[797] = { namereplaced=4*5 },
--TODO expect a lot of namereplacements
}--end table site.expected
end--if
--EOF