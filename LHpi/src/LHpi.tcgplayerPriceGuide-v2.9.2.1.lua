--*- coding: utf-8 -*-
--[[- LHpi sitescript for magic.tcgplayer.com PriceGuide 

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
synchronized with template
drop all "SOON" prices (higher maintenance for site.expected,but less "0"s in averaging)
corrected site.expected (apparently, they don't like Boros: a sizable portion is Plains and Mountains!?)
]]

-- options that control the amount of feedback/logging done by the script

--- more detailed log; default false
-- @field [parent=#global] #boolean VERBOSE
VERBOSE = true
--- also log dropped cards; default false
-- @field [parent=#global] #boolean LOGDROPS
LOGDROPS = true
--- also log namereplacements; default false
-- @field [parent=#global] #boolean LOGNAMEREPLACE
LOGNAMEREPLACE = true
--- also log foiltweaking; default false
-- @field [parent=#global] #boolean LOGFOILTWEAK
LOGFOILTWEAK = true

-- options unique to this sitescript

--- choose column (HIgh/MEdium/LOw) to import from
--@field [parent=#global] #number himelo
himelo = 3
--- for each lang, if true, have BCDpluginPost copy prices from ENG
-- This is similar to MA's "Apply Cost to All Languages" checkbox, only selectively;
-- no additional sanity checks will be performed for non-Englisch cards
--@field [parent=#global] #table copyprice
copyprice = nil
--copyprice = { [3]=true }

-- options that control the script's behaviour.

--- compare prices set and failed with expected numbers; default true
-- @field [parent=#global] #boolean CHECKEXPECTED
--CHECKEXPECTED = false

--  Don't change anything below this line unless you know what you're doing :-) --

--- also complain if drop,namereplace or foiltweak count differs; default false
-- @field [parent=#global] #boolean STRICTCHECKEXPECTED
STRICTCHECKEXPECTED = true

---	log everything and exit on error; default false
-- @field [parent=#global] #boolean DEBUG
--DEBUG = true

---	even while DEBUG, do not log raw html data found by regex; default true 
-- @field [parent=#global] #boolean DEBUGSKIPFOUND
--DEBUGSKIPFOUND = false

--- DEBUG (only but deeper) inside variant loops; default false
-- @field [parent=#global] #boolean DEBUGVARIANTS
--DEBUGVARIANTS = true

---	read source data from #string savepath instead of site url; default false
-- @field [parent=#global] #boolean OFFLINE
--OFFLINE = true

--- save a local copy of each source html to #string savepath if not in OFFLINE mode; default false
-- @field [parent=#global] #boolean SAVEHTML
--SAVEHTML = true

--- log to seperate logfile instead of Magic Album.log;	default true
-- @field [parent=#global] #boolean SAVELOG
--SAVELOG = false

--- save price table to file before importing to MA;	default false
-- @field [parent=#global] #boolean SAVETABLE
--SAVETABLE = true

--- revision of the LHpi library to use
-- @field [parent=#global] #string libver
libver = "2.9"
--- revision of the LHpi library datafile to use
-- @field [parent=#global] #string dataver
dataver = "2"
--- sitescript revision number
-- @field [parent=#global] string scriptver
scriptver = "1"
--- should be similar to the script's filename. Used for loging and savepath.
-- @field [parent=#global] #string scriptname
scriptname = "LHpi.tcgplayerPriceGuide-v" .. libver .. "." .. dataver .. "." .. scriptver .. ".lua"

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
site.regex = '<TR height=20>(.-)</TR>'


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
	LHpi.Log("Importing " .. site.himelo[himelo] .. " prices. Columns available are " .. LHpi.Tostring(site.himelo) , 1 )
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
	site.domain = "magic.tcgplayer.com/db/"
	site.file = "price_guide.asp"
	site.setprefix = "?setname="
	
	local container = {}
	local url = site.domain .. site.file .. site.setprefix .. site.sets[setid].url
	if offline then
		url = string.gsub( url, "%?", "_" )
		url = string.gsub( url, "/", "_" )
		container[url] = { isfile = true}
	else
		container[url] = {}
	end -- if offline 
	if LHpi.Data.sets[setid].foilonly then
		container[url].foilonly = true
	else
		container[url].foilonly = false -- just to make the point :)
	end
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
	local tablerow = {}
	for column in string.gmatch(foundstring , "<td[^>]->+%b<>([^<]+)%b<></td>") do
		table.insert(tablerow , column)
	end -- for column
	if DEBUG then
		LHpi.Log("(parsed):" .. LHpi.Tostring(tablerow) , 2 )
	end
	local name = string.gsub( tablerow[1], "&nbsp;" , "" )
	name = string.gsub( name , "^ " , "" )--should not be necessary, done by LHpi.GetSourceData as well...
	local price = ( tablerow[ ( himelo+5 ) ] ) or 0 -- rows 6 to 8
	price = string.gsub( price , "&nbsp;" , "" )
	price = string.gsub( price , "%$" , "" )
	price = string.gsub( price , "[,.]" , "" )
	price = tonumber(price)
	if (price == 0) and string.find(foundstring,"SOON") then
		name = name .. "(DROP price SOON)"
	end
	local newCard = { names = { [1] = name } , price = { [1] = price } }
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
function site.BCDpluginPre( card, setid, importfoil, importlangs )
	if DEBUG then
		LHpi.Log( "site.BCDpluginPre got " .. LHpi.Tostring( card ) .. " from set " .. setid , 2 )
	end
	card.name = string.gsub( card.name , "^(Magic QA.*)" , "(DROP) %1")
	card.name = string.gsub( card.name , "^(Staging Check.*)" , "(DROP) %1") 
	card.name = string.gsub( card.name , "^(RWN Testing.*)" , "(DROP) %1") 
	return card
end -- function site.BCDpluginPre

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
function site.BCDpluginPost( card , setid , importfoil, importlangs )
	if DEBUG then
		LHpi.Log( "site.BCDpluginPost got " .. LHpi.Tostring( card ) .. " from set " .. setid , 2 )
	end
	-- Probably useless to most, but still a good example what BCDpluginPost can be used for.
	if copyprice then
		for lid,boolang in pairs(copyprice) do
			card.lang[lid]=LHpi.Data.languages[lid].abbr
			card.regprice[lid]=card.regprice[1]
			card.foilprice[lid]=card.foilprice[1]
		end--for
	end--if copyprice
	return card
end -- function site.BCDpluginPost

-------------------------------------------------------------------------------------------------------------
-- tables
-------------------------------------------------------------------------------------------------------------

--- Define the three price columns. This table is unique to this sitescript.
-- @field [parent=#site] #table himelo
site.himelo = { "high" , "medium" , "low" }

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
	[1] = { id=1,  url="" },
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
--this is not strictly correct. The site does not give explicit foil prices, but some foilonly sets are priced nonetheless
--We'll depend on LHpi.Data.sets[setid].foilonly and LHpi.Data.sets[setid].foiltweak for those.
	[1]= { id=1, name="nonfoil"	, isfoil=false, isnonfoil=true , url="" },
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
[797]={id = 797, lang = { true }, fruc = { true }, url = "Magic%202014%20(M14)"},
[788]={id = 788, lang = { true }, fruc = { true }, url = "Magic%202013%20(M13)"},
[779]={id = 779, lang = { true }, fruc = { true }, url = "Magic%202012%20(M12)"},
[770]={id = 770, lang = { true }, fruc = { true }, url = "Magic%202011%20(M11)"},
[759]={id = 759, lang = { true }, fruc = { true }, url = "Magic%202010"},
[720]={id = 720, lang = { true }, fruc = { true }, url = "10th%20Edition"},
[630]={id = 630, lang = { true }, fruc = { true }, url = "9th%20Edition"},
[550]={id = 550, lang = { true }, fruc = { true }, url = "8th%20Edition"},
[460]={id = 460, lang = { true }, fruc = { true }, url = "7th%20Edition"},
[360]={id = 360, lang = { true }, fruc = { true }, url = "Classic%20Sixth%20Edition"},
[250]={id = 250, lang = { true }, fruc = { true }, url = "Fifth%20Edition"},
[180]={id = 180, lang = { true }, fruc = { true }, url = "Fourth%20Edition"},
[141]=nil,--Revised Summer Magic
[140]={id = 140, lang = { true }, fruc = { true }, url = "Revised%20Edition"},
[139]=nil,--Revised Limited Deutsch
[110]={id = 110, lang = { true }, fruc = { true }, url = "Unlimited%20Edition"},
[100]={id = 100, lang = { true }, fruc = { true }, url = "Beta%20Edition"},
[90] ={id =  90, lang = { true }, fruc = { true }, url = "Alpha%20Edition"},
-- Expansions
[802]={id = 802, lang = { true }, fruc = { true }, url = "Born%20of%20the%20Gods"},
[800]={id = 800, lang = { true }, fruc = { true }, url = "Theros"},
[795]={id = 795, lang = { true }, fruc = { true }, url = "Dragon's%20Maze"},
[793]={id = 793, lang = { true }, fruc = { true }, url = "Gatecrash"},
[791]={id = 791, lang = { true }, fruc = { true }, url = "Return%20to%20Ravnica"},
[786]={id = 786, lang = { true }, fruc = { true }, url = "Avacyn%20Restored"},
[784]={id = 784, lang = { true }, fruc = { true }, url = "Dark%20Ascension"},
[782]={id = 782, lang = { true }, fruc = { true }, url = "Innistrad"},
[776]={id = 776, lang = { true }, fruc = { true }, url = "New%20Phyrexia"},
[775]={id = 775, lang = { true }, fruc = { true }, url = "Mirrodin%20Besieged"},
[773]={id = 773, lang = { true }, fruc = { true }, url = "Scars%20of%20Mirrodin"},
[767]={id = 767, lang = { true }, fruc = { true }, url = "Rise%20of%20the%20Eldrazi"},
[765]={id = 765, lang = { true }, fruc = { true }, url = "Worldwake"},
[762]={id = 762, lang = { true }, fruc = { true }, url = "Zendikar"},
[758]={id = 758, lang = { true }, fruc = { true }, url = "Alara%20Reborn"},
[756]={id = 756, lang = { true }, fruc = { true }, url = "Conflux"},
[754]={id = 754, lang = { true }, fruc = { true }, url = "Shards%20of%20Alara"},
[752]={id = 752, lang = { true }, fruc = { true }, url = "Eventide"},
[751]={id = 751, lang = { true }, fruc = { true }, url = "Shadowmoor"},
[750]={id = 750, lang = { true }, fruc = { true }, url = "Morningtide"},
[730]={id = 730, lang = { true }, fruc = { true }, url = "Lorwyn"},
[710]={id = 710, lang = { true }, fruc = { true }, url = "Future%20Sight"},
[700]={id = 700, lang = { true }, fruc = { true }, url = "Planar%20Chaos"},
[690]={id = 690, lang = { true }, fruc = { true }, url = "Timeshifted"},
[680]={id = 680, lang = { true }, fruc = { true }, url = "Time%20Spiral"},
[670]={id = 670, lang = { true }, fruc = { true }, url = "Coldsnap"},
[660]={id = 660, lang = { true }, fruc = { true }, url = "Dissension"},
[650]={id = 650, lang = { true }, fruc = { true }, url = "Guildpact"},
[640]={id = 640, lang = { true }, fruc = { true }, url = "Ravnica"},
[620]={id = 620, lang = { true }, fruc = { true }, url = "Saviors%20of%20Kamigawa"},
[610]={id = 610, lang = { true }, fruc = { true }, url = "Betrayers%20of%20Kamigawa"},
[590]={id = 590, lang = { true }, fruc = { true }, url = "Champions%20of%20Kamigawa"},
[580]={id = 580, lang = { true }, fruc = { true }, url = "Fifth%20Dawn"},
[570]={id = 570, lang = { true }, fruc = { true }, url = "Darksteel"},
[560]={id = 560, lang = { true }, fruc = { true }, url = "Mirrodin"},
[540]={id = 540, lang = { true }, fruc = { true }, url = "Scourge"},
[530]={id = 530, lang = { true }, fruc = { true }, url = "Legions"},
[520]={id = 520, lang = { true }, fruc = { true }, url = "Onslaught"},
[510]={id = 510, lang = { true }, fruc = { true }, url = "Judgment"},
[500]={id = 500, lang = { true }, fruc = { true }, url = "Torment"},
[480]={id = 480, lang = { true }, fruc = { true }, url = "Odyssey"},
[470]={id = 470, lang = { true }, fruc = { true }, url = "Apocalypse"},
[450]={id = 450, lang = { true }, fruc = { true }, url = "Planeshift"},
[430]={id = 430, lang = { true }, fruc = { true }, url = "Invasion"},
[420]={id = 420, lang = { true }, fruc = { true }, url = "Prophecy"},
[410]={id = 410, lang = { true }, fruc = { true }, url = "Nemesis"},
[400]={id = 400, lang = { true }, fruc = { true }, url = "Mercadian%20Masques"},
[370]={id = 370, lang = { true }, fruc = { true }, url = "Urza's%20Destiny"},
[350]={id = 350, lang = { true }, fruc = { true }, url = "Urza's%20Legacy"},
[330]={id = 330, lang = { true }, fruc = { true }, url = "Urza's%20Saga"},
[300]={id = 300, lang = { true }, fruc = { true }, url = "Exodus"},
[290]={id = 290, lang = { true }, fruc = { true }, url = "Stronghold"},
[280]={id = 280, lang = { true }, fruc = { true }, url = "Tempest"},
[270]={id = 270, lang = { true }, fruc = { true }, url = "Weatherlight"},
[240]={id = 240, lang = { true }, fruc = { true }, url = "Visions"},
[230]={id = 230, lang = { true }, fruc = { true }, url = "Mirage"},
[220]={id = 220, lang = { true }, fruc = { true }, url = "Alliances"},
[210]={id = 210, lang = { true }, fruc = { true }, url = "Homelands"},
[190]={id = 190, lang = { true }, fruc = { true }, url = "Ice%20Age"},
[170]={id = 170, lang = { true }, fruc = { true }, url = "Fallen%20Empires"},
[160]={id = 160, lang = { true }, fruc = { true }, url = "The%20Dark"},
[150]={id = 150, lang = { true }, fruc = { true }, url = "Legends"},
[130]={id = 130, lang = { true }, fruc = { true }, url = "Antiquities"},
[120]={id = 120, lang = { true }, fruc = { true }, url = "Arabian%20Nights"},
-- special sets
--[801]={id = 801, lang = { true }, fruc = { true }, url = "Commander%202013"},
[799]={id = 799, lang = { true }, fruc = { true }, url = "Duel%20Decks%3A%20Heroes%20vs.%20Monsters"},
[798]={id = 798, lang = { true }, fruc = { true }, url = "From%20the%20Vault%3A%20Twenty"},
[796]={id = 796, lang = { true }, fruc = { true }, url = "Modern+Masters"},
[794]={id = 794, lang = { true }, fruc = { true }, url = "Duel%20Decks%3A%20Sorin%20vs.%20Tibalt"},
--[792]={id = 792, lang = { true }, fruc = { true }, url = "Commander%27s%20Arsenal"},
--[790]={id = 790, lang = { true }, fruc = { true }, url = "Duel%20Decks:%20Izzet%20vs.%20Golgari"},
--[789]={id = 789, lang = { true }, fruc = { true }, url = "From%20the%20Vault%3A%20Realms"},
--[787]={id = 787, lang = { true }, fruc = { true }, url = "Planechase%202012"},
[785]={id = 785, lang = { true }, fruc = { true }, url = "Duel%20Decks:%20Venser%20vs.%20Koth"},
--[783]={id = 783, lang = { true }, fruc = { true }, url = "Graveborn"},
--[781]={id = 781, lang = { true }, fruc = { true }, url = "Duel%20Decks:%20Ajani%20vs.%20Nicol%20Bolas"},
--[780]={id = 780, lang = { true }, fruc = { true }, url = "From%20the%20Vault%3A%20Legends"},
--[778]={id = 778, lang = { true }, fruc = { true }, url = "Commander"},
--[777]={id = 777, lang = { true }, fruc = { true }, url = "Knights%20vs.%20Dragons"},
--[774]={id = 774, lang = { true }, fruc = { true }, url = "Premium%20Deck%20Series:%20Fire%20and%20Lightning"},
[772]={id = 772, lang = { true }, fruc = { true }, url = "Duel%20Decks:%20Elspeth%20vs.%20Tezzeret"},
--[771]={id = 771, lang = { true }, fruc = { true }, url = "From%20the%20Vault%3A%20Relics"},
--[769]={id = 769, lang = { true }, fruc = { true }, url = "Archenemy"},
--[768]={id = 768, lang = { true }, fruc = { true }, url = "Duels%20of%20the%20Planeswalkers"},
--[766]={id = 766, lang = { true }, fruc = { true }, url = "Duel%20Decks:%20Phyrexia%20vs.%20The%20Coalition"},
--[764]={id = 764, lang = { true }, fruc = { true }, url = "Premium%20Deck%20Series:%20Slivers"},
--[763]={id = 763, lang = { true }, fruc = { true }, url = "Duel%20Decks:%20Garruk%20VS%20Liliana"},
--[761]={id = 761, lang = { true }, fruc = { true }, url = "Planechase"},   
--[760]={id = 760, lang = { true }, fruc = { true }, url = "From%20the%20Vault%3A%20Exiled"},
[757]={id = 757, lang = { true }, fruc = { true }, url = "Duel%20Decks:%20Divine%20vs.%20Demonic"},
--[755]={id = 755, lang = { true }, fruc = { true }, url = "Duel%20Decks:%20Jace%20vs.%20Chandra"},
--[753]={id = 753, lang = { true }, fruc = { true }, url = "From%20the%20Vault%3A%20Dragons"},
--[740]={id = 740, lang = { true }, fruc = { true }, url = "Duel%20Decks: Elves vs. Goblins"},
[675]=nil,--Coldsnap Theme Decks
[635]=nil,--Magic Encyclopedia
[600]={id = 600, lang = { true }, fruc = { true }, url = "Unhinged"},
--[490]={id = 490, lang = { true }, fruc = { true }, url = "Deckmaster"},
[440]={id = 440, lang = { true }, fruc = { true }, url = "Beatdown%20Box%20Set"},
--[415]={id = 415, lang = { true }, fruc = { true }, url = "Starter%202000"},   
--[405]={id = 405, lang = { true }, fruc = { true }, url = "Battle%20Royale%20Box%20Set"},
--[390]={id = 390, lang = { true }, fruc = { true }, url = "Starter%201999"},
[380]={id = 380, lang = { true }, fruc = { true }, url = "Portal%20Three%20Kingdoms"},
[340]=nil,--Anthologies
[320]={id = 320, lang = { true }, fruc = { true }, url = "Unglued"},
[310]={id = 310, lang = { true }, fruc = { true }, url = "Portal%20Second%20Age"},
[260]={id = 260, lang = { true }, fruc = { true }, url = "Portal"},
[225]=nil,--Introductory Two-Player Set
[201]=nil,--Renaissance
[200]={id = 200, lang = { true }, fruc = { true }, url = "Chronicles"},
--[70] ={id =  70, lang = { true }, fruc = { true }, url = "Vanguard"},
[69] =nil,--Box Topper Cards
-- Promo Cards
[50] =nil,--Full Box Promotion
[45] =nil,--Magic Premiere Shop
[43] =nil,--Two-Headed Giant Promos
[42] =nil,--Summer of Magic Promos
[41] =nil,--Happy Holidays Promos
--[40] ={id =  40, lang = { true }, fruc = { true }, url = "Arena%20Promos"},
[33] =nil,--Championships Prizes
--[32] ={id =  32, lang = { true }, fruc = { true }, url = "Pro%20Tour%20Promos"},--Pro Tour Promos
--[31] ={id =  31, lang = { true }, fruc = { true }, url = "Grand%20Prix%20Promos"},--Grand Prix Promos
--[30] ={id =  30, lang = { true }, fruc = { true }, url = "FNM%20Promos"},
--TODO: "APAC%20Lands" is Asian-Pacific subset of altArt, needs variant table
--TODO: "European%20Lands" is Asian-Pacific subset of altArt, needs variant table
--TODO: "Guru%20Lands" is Asian-Pacific subset of altArt, needs variant table
--[27] ={id =  27, lang = { true }, fruc = { true }, url = ""},--Alternate Art Lands
--[26] ={id =  26, lang = { true }, fruc = { true }, url = "Game%20Day%20Promos"},
--[25] ={id =  25, lang = { true }, fruc = { true }, url = "Judge%20Promos"},
--[24] ={id =  24, lang = { true }, fruc = { true }, url = "Champs%20Promos"},
--TODO "WPN%20Promos" is subset of 23 Gateway & WPN Promos
--[23] ={id =  23, lang = { true }, fruc = { true }, url = "Gateway%20Promos"},
--[22] ={id =  22, lang = { true }, fruc = { true }, url = "Prerelease%20Cards"},
--TODO "Release%20Event%20Cards" is subset of 21 Release & Launch Party Cards
--[21] ={id =  21, lang = { true }, fruc = { true }, url = "Launch%20Party%20Cards"},
--[20] ={id =  20, lang = { true }, fruc = { true }, url = "Magic%20Player%20Rewards"},
[15] =nil,--Convention Promos
[12] =nil,--Hobby Japan Commemorative Cards
[11] =nil,--Redemption Program Cards
--TODO: 10 JSS Needs Variant Table
--[10] ={id =  10, lang = { true }, fruc = { true }, url = "JSS/MSS%20Promos"},--Junior Series Promos
[9]  =nil,--Video Game Promos
[8]  =nil,--Stores Promos
[7]  =nil,--Magazine Inserts
[6]  =nil,--Comic Inserts
[5]  =nil,--Book Inserts
[4]  =nil,--Ultra Rare Cards
[2]  =nil,--DCI Legend Membership
-- "Media%20Promos": sorting out the single page seems more trouble than it's worth
-- "Special%20Occasion": sorting out the single page seems more trouble than it's worth
} -- end table site.sets

--[[- card name replacement tables.

  fields are for subtables indexed by #number setid.
 { #number (setid)= #table { #string (oldname)= #string , ... } , ... }
 
 @type site.namereplace
 @field [parent=#site.namereplace] #string name
]]
site.namereplace = {
[797] = { -- M2014
["Elemental Token"]						= "Elemental",
},
[779] = { -- M2012
["AEther Adept"]						= "Æther Adept",
["Pentiavite Token"]					= "Pentavite"
},
[770] = { -- M2011
["Aether Adept"]						= "Æther Adept",
["Ooze Token"]							= "Ooze",
},
[460] = { -- 7th Edition
["Tainted Aether"]						= "Tainted Æther",
["Aether Flash"]						= "Æther Flash",
},
[360] = { -- 6th Edition
["Aether Flash"]						= "Æther Flash",
},
[250] = { -- 5th Edition
["Aether Storm"]						= "Æther Storm",
},
[140] = { -- Revised
--["El-Hajjâj"]							= "El-Hajjaj",
},
[802] = { -- Born of the Gods
["Bird Token (White)"]					= "Bird (1)",
["Bird Token (Blue)"]					= "Bird (4)",
},
[800] = { -- Theros
["Purphoros' Emissary"]					= "Purphoros's Emissary",
["Soldier Token (Red)"]					= "Soldier (7)",
["Soldier Token A"]						= "Soldier",
["Soldier Token B"]						= "Soldier",
},
[795] = { -- Dragon's Maze
["AEtherling"]							= "Ætherling",
},
[793] = { -- Gatecrash
["Aetherize"]							= "Ætherize",
},
[786] = { -- Avacyn Restored
["Spirit Token (White)"]				= "Spirit (3)",
["Spirit Token (Blue)"]					= "Spirit (4)",
["Human Token (White)"]					= "Human (2)",
["Human Token (Red)"]					= "Human (7)",
},
[784] = { -- Dark Ascension
["Seance"]								= "Séance",
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
["Double-Sided Card Checklist"]			= "Checklist",
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
["Double-Sided Card Checklist"]			= "Checklist",
["Wolf Token (Deathtouch)"]				= "Wolf (6)",
["Wolf Token"]							= "Wolf (12)",
["Zombie Token"]						= "Zombie",
},
[776] = { -- New Phyrexia
["Arm with AEther"]						= "Arm with Æther"
},
[775] = { -- Mirrodin Besieged
["Plains - B"]							= "Plains (147)",
["Island - B"]							= "Island (149)",
["Swamp - B"]							= "Swamp (151)",
["Mountain - B"]						= "Mountain (153)",
["Forest - B"]							= "Forest (155)",
},
[773] = { -- Scars of Mirrodin
["Wurm Token (Deathtouch)"]				= "Wurm (8)",
["Wurm Token (Lifelink)"]				= "Wurm (9)",
},
[767] = { -- Rise of the Eldazi
["Eldrazi Spawn Token (1a)"]			= "Eldrazi Spawn (1a)",
["Eldrazi Spawn Token (1b)"]			= "Eldrazi Spawn (1b)",
["Eldrazi Spawn Token (1c)"]			= "Eldrazi Spawn (1c)",
["Plains - B"]							= "Plains (230)",
["Plains - C"]							= "Plains (231)",
["Plains - D"]							= "Plains (232)",
["Island - B"]							= "Island (234)",
["Island - C"]							= "Island (235)",
["Island - D"]							= "Island (236)",
["Swamp - B"]							= "Swamp (238)",
["Swamp - C"]							= "Swamp (239)",
["Swamp - D"]							= "Swamp (240)",
["Mountain - B"]						= "Mountain (242)",
["Mountain - C"]						= "Mountain (243)",
["Mountain - D"]						= "Mountain (244)",
["Forest - B"]							= "Forest (246)",
["Forest - C"]							= "Forest (247)",
["Forest - D"]							= "Forest (248)",
},
[765] = { -- Worldwake
["Aether Tradewinds"]					= "Æther Tradewinds"
},
[762] = { -- Zendikar
["Aether Figment"]						= "Æther Figment"
},
[756] = { -- Conflux
["Scornful AEther-Lich"]				= "Scornful Æther-Lich"
},
[754] = { -- Shards of Alara
["Homnculus Token"]						= "Homunculus Token"
},
[751] = { -- Shadowmoor
["AEthertow"]							= "Æthertow",
["Elemental Token (Red)"]				= "Elemental (4)",
["Elemental Token (Black|Red)"]			= "Elemental (9)",
["Elf Warrior Token (Green)"]			= "Elf Warrior (5)",
["Elf Warrior Token (Green|White)"]		= "Elf Warrior (12)",
},
[730] = { -- Lorwyn
["Aethersnipe"]							= "Æthersnipe",
["Elemental Token (Green)"]				= "Elemental (8)",
["Elemental Token (White)"]				= "Elemental (2)",
},
[710] = { -- Future Sight
["Vedalken Aethermage"]					= "Vedalken Æthermage"
},
[700] = { -- Planar Chaos
["Frozen Aether"]						= "Frozen Æther",
["Aether Membrane"]						= "Æther Membrane"
},
[680] = { -- Time Spiral
["Aether Web"]							= "Æther Web",
["Aetherflame Wall"]					= "Ætherflame Wall",
["Lim-Dul the Necromancer"]				= "Lim-Dûl the Necromancer"
},
[670] = { -- Coldsnap
["Surging Aether"]						= "Surging Æther",
["Jotun Owl Keeper"]					= "Jötun Owl Keeper",
["Jotun Grunt"]							= "Jötun Grunt"
},
[660] = { -- Dissension
["Aethermage's Touch"]					= "Æthermage's Touch",
["Azorius Aethermage"]					= "Azorius Æthermage"
},
[650] = { -- Guildpact
["Aetherplasm"]							= "Ætherplasm"
},
[620] = { -- Saviors of Kamigawa
["Aether Shockwave"]					= "Æther Shockwave",
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
["Budoka Pupil"] 						= "Budoka Pupil|Ichiga, Who Topples Oaks",
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
["Akki Lavarunner"]						= "Akki Lavarunner|Tok-Tok, Volcano Born",
},
[580] = { -- Fifth DAwn
["Fold into Aether"]					= "Fold into Æther"
},
[570] = { -- Darksteel
["Aether Snap"]							= "Æther Snap",
["AEther Vial"]							= "Æther Vial"
},
[560] = { -- Mirrodin
["Gate to the Aether"]					= "Gate to the Æther",
["Aether Spellbomb"]					= "Æther Spellbomb",
["Island (293"]							= "Island (293)",
},
[520] = { -- Onslaught
["Aether Charge"]						= "Æther Charge"
},
[480] = { -- Odyssey
["Aether Burst"]						= "Æther Burst"
},
[470] = { -- Apocalypse
["Aether Mutation"]						= "Æther Mutation"
},
[450] = { -- Planeshift
["Ertai, the Corrupted (Alt. Art)"]		= "Ertai, the Corrupted (Alt)",
["Skyship Weatherlight (Alt. Art)"]		= "Skyship Weatherlight (Alt)",
["Tahngarth, Talruum Hero (Alt. Art)"]	= "Tahngarth, Talruum Hero (Alt)",
},
[430] = { -- Invasion
["Aether Rift"]							= "Æther Rift"
},
[410] = { -- Nemesis
["Aether Barrier"]						= "Æther Barrier"
},
[370] = { -- Urza's Destiny
["Aether Sting"]						= "Æther Sting"
},
[330] = { -- Urza's Saga
["Tainted Aether"]						= "Tainted Æther"
},
[300] = { -- Exodus
["Aether Tide"]							= "Æther Tide"
},
[270] = { -- Weatherlight
["Aether Flash"]						= "Æther Flash",
["Bosium Strip"]						= "Bösium Strip"
},
[220] = { -- Alliances
["Lim-Dul's High Guard"]				= "Lim-Dûl's High Guard"
},
[210] = { -- Homelands
["Aether Storm"]						= "Æther Storm"
},
[190] = { -- Ice Age
["Lim-Dul's Cohort"] 					= "Lim-Dûl’s Cohort",
["Marton Stromgald"] 					= "Márton Stromgald",
["Lim-Dul's Hex"]						= "Lim-Dûl’s Hex",
["Legions of Lim-Dul"]					= "Legions of Lim-Dûl",
["Oath of Lim-Dul"]						= "Oath of Lim-Dûl",
},
[150] = { -- Legends
["Aerathi Berserker"]					= "Ærathi Berserker"
},
[130] = { --Antiquities
--["Mishra's Factory (2)"]				= "Mishra's Factory (Summer)",
--["Mishra's Factory (3)"]				= "Mishra's Factory (Autumn)",
["Mishra's Factory (Fall)"]				= "Mishra's Factory (Autumn)",
--["Mishra's Factory (4)"]				= "Mishra's Factory (Winter)",
["Strip Mine (No Horizon)"]				= "Strip Mine (1)",
["Strip Mine (Uneven Horizon)"]			= "Strip Mine (2)",
["Strip Mine (Tower)"]					= "Strip Mine (3)",
["Strip Mine (Even Horizon)"]			= "Strip Mine (4)",
["Urza's Mine (Pulley)"] 				= "Urza's Mine (1)",
["Urza's Mine (Mouth)"] 				= "Urza's Mine (2)",
["Urza's Mine (Clawed Sphere)"] 		= "Urza's Mine (3)",
["Urza's Mine (Tower)"] 				= "Urza's Mine (4)",
["Urza's Power Plant (Sphere)"] 		= "Urza's Power Plant (1)",
["Urza's Power Plant (Columns)"] 		= "Urza's Power Plant (2)",
["Urza's Power Plant (Bug)"] 			= "Urza's Power Plant (3)",
["Urza's Power Plant (Rock in Pot)"] 	= "Urza's Power Plant (4)",
["Urza's Tower (Forest)"] 				= "Urza's Tower (1)",
["Urza's Tower (Shore)"] 				= "Urza's Tower (2)",
["Urza's Tower (Plains)"] 				= "Urza's Tower (3)",
["Urza's Tower (Mountains)"] 			= "Urza's Tower (4)",
},
[120] = { -- Arabian Nights
["Ring of Ma'ruf"]						= "Ring of Ma’rûf",
--["Army of Allah"] 						= "Army of Allah (1)",
--["Bird Maiden"] 						= "Bird Maiden (1)",
--["Erg Raiders"] 						= "Erg Raiders (1)",
--["Fishliver Oil"] 						= "Fishliver Oil (1)",
--["Giant Tortoise"] 						= "Giant Tortoise (1)",
--["Hasran Ogress"] 						= "Hasran Ogress (1)",
--["Moorish Cavalry"] 					= "Moorish Cavalry (1)",
--["Naf's Asp"] 							= "Nafs Asp (1)",
["Naf's Asp"] 							= "Nafs Asp",
--["Naf's Asp"] 							= "Nafs Asp (1)",
["Naf's Asp (2)"] 						= "Nafs Asp (2)",
--["Oubliette"] 							= "Oubliette (1)",
--["Rukh Egg"] 							= "Rukh Egg (1)",
--["Piety"] 								= "Piety (1)",
--["Stone-Throwing Devils"] 				= "Stone-Throwing Devils (1)",
--["War Elephant"] 						= "War Elephant (1)",
--["Wyluli Wolf"] 						= "Wyluli Wolf (1)",
},
-- special sets
[796] = { -- Modern Masters
["Aether Vial"]							= "Æther Vial",
["Aether Spellbomb"]					= "Æther Spellbomb",
["Aethersnipe"]							= "Æthersnipe",
},
[785] = { -- DD:Elspeth vs. Tezzeret
["Aether Membrane"]						= "Æther Membrane",
},
[772] = { -- DD:Elspeth vs. Tezzeret
["Aether Spellbomb"]					= "Æther Spellbomb",
},
[600] = { -- Unhinged
--TODO "Ach Hans"
["Ach! Hans, Run!"]						= '"Ach! Hans, Run!"',
["Our Market Research..."]				= "Our Market Research Shows That Players Like Really Long Card Names So We Made this Card to Have the Absolute Longest Card Name Ever Elemental",
["Kill Destroy"]						= "Kill! Destroy!",
["Who|What/When|Where/Why"]				= "Who|What|When|Where|Why",
["Yet Another AEther Vortex"]			= "Yet Another Æther Vortex",
},
[380] = { -- Portal Three Kingdoms
--TODO Pang Tong and Kongming (")
["Pang Tong, “Young Phoenix”"]			= 'Pang Tong, "Young Phoenix"',
["Kongming, “Sleeping Dragon”"]			= 'Kongming, "Sleeping Dragon"',
["Plains (1)"]							= "Plains (166)",
["Plains (2)"]							= "Plains (167)",
["Plains (3)"]							= "Plains (168)",
["Island (1)"]							= "Island (169)",
["Island (2)"]							= "Island (170)",
["Island (3)"]							= "Island (171)",
["Swamp (1)"]							= "Swamp (172)",
["Swamp (2)"]							= "Swamp (173)",
["Swamp (3)"]							= "Swamp (174)",
["Mountain (1)"]						= "Mountain (175)",
["Mountain (2)"]						= "Mountain (176)",
["Mountain (3)"]						= "Mountain (177)",
["Forest (1)"]							= "Forest (178)",
["Forest (2)"]							= "Forest (179)",
["Forest (3)"]							= "Forest (180)",
},
[320] = { -- Unglued
["B.F.M. (Big Furry Monster Left)"]		= "B.F.M. (Left)",
["B.F.M. (Big Furry Monster Right)"]	= "B.F.M. (Right)",
--["The Ultimate Nightmare of Wizards of the Coast\174 Cu"]	= "The Ultimate Nightmare of Wizards of the Coast® Customer Service",
["The Ultimate Nightmare of Wizards of the Coast® Cu"]	= "The Ultimate Nightmare of Wizards of the Coast® Customer Service",
},
[260] = { -- Portal
["Anaconda (2)"]						= "Anaconda (ST)",
["Blaze (2)"]							= "Blaze (ST)",
["Elite Cat Warrior (2)"]				= "Elite Cat Warrior (ST)",
["Hand of Death (2)"]					= "Hand of Death (ST)",
["Monstrous Growth (2)"]				= "Monstrous Growth (ST)",
["Raging Goblin (2)"]					= "Raging Goblin (ST)",
["Warrior's Charge (2)"]				= "Warrior's Charge (ST)",
},
[200] = { -- Chronicles
["Urza's Mine (Mouth)"] 				= "Urza's Mine (1)",
["Urza's Mine (Clawed Sphere)"] 		= "Urza's Mine (2)",
["Urza's Mine (Pully)"] 				= "Urza's Mine (3)",
["Urza's Mine (Tower)"] 				= "Urza's Mine (4)",
["Urza's Power Plant (Rock in Pot)"] 	= "Urza's Power Plant (1)",
["Urza's Power Plant (Columns)"] 		= "Urza's Power Plant (2)",
["Urza's Power Plant (Bug)"] 			= "Urza's Power Plant (3)",
["Urza's Power Plant (Sphere)"] 		= "Urza's Power Plant (4)",
["Urza's Tower (Forest)"] 				= "Urza's Tower (1)",
["Urza's Tower (Plains)"] 				= "Urza's Tower (2)",
["Urza's Tower (Mountains)"] 			= "Urza's Tower (3)",
["Urza's Tower (Shore)"] 				= "Urza's Tower (4)",
},
} -- end table site.namereplace

--[[- card variant tables.
 tables of cards that need to set variant.
 For each setid, if unset uses sensible defaults from LHpi.Data.sets.variants.
 Note that you need to replicate the default values for the whole setid here,
 even if you set only a single card from the set differently.

  fields are for subtables indexed by #number setid.
 { #number (setid)= #table { #string (name)= #table { #string, #table { #string or #boolean , ... } } , ... } , ...  }

 @type site.variants
 @field [parent=#site.variants] #table variant
]]
site.variants = {
[762] = { --Zendikar
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4    , "1a" , "2a" , "3a" , "4a"  } },
["Plains - Full Art"] 			= { "Plains"	, { 1    , 2    , 3    , 4    , false, false, false, false } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4    , "1a" , "2a" , "3a" , "4a"  } },
["Island - Full Art"] 			= { "Island" 	, { 1    , 2    , 3    , 4    , false, false, false, false } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4    , "1a" , "2a" , "3a" , "4a"  } },
["Swamp - Full Art"] 			= { "Swamp"		, { 1    , 2    , 3    , 4    , false, false, false, false } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4    , "1a" , "2a" , "3a" , "4a"  } },
["Mountain - Full Art"]			= { "Mountain"	, { 1    , 2    , 3    , 4    , false, false, false, false } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4    , "1a" , "2a" , "3a" , "4a"  } },
["Forest - Full Art"] 			= { "Forest" 	, { 1    , 2    , 3    , 4    , false, false, false, false } },
["Plains (230) - Full Art"]		= { "Plains"	, { 1    , false, false, false, false, false, false, false } },
["Plains (230)"]				= { "Plains"	, { false, false, false, false, "1a" , false, false, false } },
["Plains (231) - Full Art"]		= { "Plains"	, { false, 2    , false, false, false, false, false, false } },
["Plains (231)"]				= { "Plains"	, { false, false, false, false, false, "2a" , false, false } },
["Plains (232) - Full Art"]		= { "Plains"	, { false, false, 3    , false, false, false, false, false } },
["Plains (232)"]				= { "Plains"	, { false, false, false, false, false, false, "3a" , false } },
["Plains (233) - Full Art"]		= { "Plains"	, { false, false, false, 4    , false, false, false, false } },
["Plains (233)"]				= { "Plains"	, { false, false, false, false, false, false, false, "4a"  } },
["Island (234) - Full Art"]		= { "Island"	, { 1    , false, false, false, false, false, false, false } },
["Island (234)"]				= { "Island"	, { false, false, false, false, "1a" , false, false, false } },
["Island (235) - Full Art"]		= { "Island"	, { false, 2    , false, false, false, false, false, false } },
["Island (235)"]				= { "Island"	, { false, false, false, false, false, "2a" , false, false } },
["Island (236) - Full Art"]		= { "Island"	, { false, false, 3    , false, false, false, false, false } },
["Island (236)"]				= { "Island"	, { false, false, false, false, false, false, "3a" , false } },
["Island (237) - Full Art"]		= { "Island"	, { false, false, false, 4    , false, false, false, false } },
["Island (237)"]				= { "Island"	, { false, false, false, false, false, false, false, "4a"  } },
["Swamp (238) - Full Art"]		= { "Swamp"		, { 1    , false, false, false, false, false, false, false } },
["Swamp (238)"]					= { "Swamp"		, { false, false, false, false, "1a" , false, false, false } },
["Swamp (239) - Full Art"]		= { "Swamp"		, { false, 2    , false, false, false, false, false, false } },
["Swamp (239)"]					= { "Swamp"		, { false, false, false, false, false, "2a" , false, false } },
["Swamp (240) - Full Art"]		= { "Swamp"		, { false, false, 3    , false, false, false, false, false } },
["Swamp (240)"]					= { "Swamp"		, { false, false, false, false, false, false, "3a" , false } },
["Swamp (241) - Full Art"]		= { "Swamp"		, { false, false, false, 4    , false, false, false, false } },
["Swamp (241)"]					= { "Swamp"		, { false, false, false, false, false, false, false, "4a"  } },
["Mountain (242) - Full Art"]	= { "Mountain"	, { 1    , false, false, false, false, false, false, false } },
["Mountain (242)"]				= { "Mountain"	, { false, false, false, false, "1a" , false, false, false } },
["Mountain (243) - Full Art"]	= { "Mountain"	, { false, 2    , false, false, false, false, false, false } },
["Mountain (243)"]				= { "Mountain"	, { false, false, false, false, false, "2a" , false, false } },
["Mountain (244) - Full Art"]	= { "Mountain"	, { false, false, 3    , false, false, false, false, false } },
["Mountain (244)"]				= { "Mountain"	, { false, false, false, false, false, false, "3a" , false } },
["Mountain (245) - Full Art"]	= { "Mountain"	, { false, false, false, 4    , false, false, false, false } },
["Mountain (245)"]				= { "Mountain"	, { false, false, false, false, false, false, false, "4a"  } },
["Forest (246) - Full Art"]		= { "Forest"	, { 1    , false, false, false, false, false, false, false } },
["Forest (246)"]				= { "Forest"	, { false, false, false, false, "1a" , false, false, false } },
["Forest (247) - Full Art"]		= { "Forest"	, { false, 2    , false, false, false, false, false, false } },
["Forest (247)"]				= { "Forest"	, { false, false, false, false, false, "2a" , false, false } },
["Forest (248) - Full Art"]		= { "Forest"	, { false, false, 3    , false, false, false, false, false } },
["Forest (248)"]				= { "Forest"	, { false, false, false, false, false, false, "3a" , false } },
["Forest (249) - Full Art"]		= { "Forest"	, { false, false, false, 4    , false, false, false, false } },
["Forest (249)"]				= { "Forest"	, { false, false, false, false, false, false, false, "4a"  } },
	},
} -- end table site.variants


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
EXPECTTOKENS = true,
-- Core sets
[797] = { failed={ 1 }, namereplaced=2 },
[779] = { namereplaced=2 },
[770] = { namereplaced=3, dropped=6 },
[759] = { pset={ 257-20-8 }, dropped=6 },--no basic lands, no tokens
[720] = { dropped=2 },
[460] = { namereplaced=2, dropped=1 },
[360] = { namereplaced=1 },
[250] = { namereplaced=1 },
[140] = { dropped=2 },
[100] = { pset={302-3}, dropped=3},
[90]  = { pset={295-6}, dropped=6},
-- Expansions
[802] = { namereplaced=2},
[800] = { namereplaced=3 },
[795] = { namereplaced=1, failed={ 1 } },
[793] = { namereplaced=1 },
[786] = { namereplaced=4 },
[784] = { pset={161+1}, namereplaced=15 },-- +1 Checklist
[782] = { pset={276+1}, namereplaced=26 },-- +1 Checklist
[776] = { pset={ 175+4 }, namereplaced=1 },
[775] = { namereplaced=4 },
[773] = { failed={ 1 }, namereplaced=2 },-- 1 fail is Poison Counter
[767] = { namereplaced=18 },
[765] = { namereplaced=1 },
[762] = { pset={ 260+20-1 }, namereplaced=1, dropped=2 },-- +20 non-fullart lands
[758] = { dropped=1 },
[756] = { namereplaced=1 },
[754] = { namereplaced=1 },
[752] = { pset={ 187-1-3 }, dropped=3 },--Worm token missing
[751] = { pset={313-3}, namereplaced=5-1, dropped=13 },
[730] = { pset={ 312-1-1 }, namereplaced=3, dropped=1 },--Elemental Shaman Token missing
[710] = { namereplaced=1 },
[700] = { namereplaced=2 },
[680] = { pset={301-4}, dropped=4, namereplaced=3 },
[670] = { namereplaced=2 },
[660] = { namereplaced=2 },
[650] = { namereplaced=1 },
[620] = { namereplaced=6 },
[610] = { namereplaced=5 },
[590] = { namereplaced=10 },
[580] = { namereplaced=1 },
[570] = { namereplaced=2 },
[560] = { namereplaced=3, dropped=2 },
[520] = { namereplaced=1, dropped=2 },
[480] = { namereplaced=1, dropped=2 },
[470] = { namereplaced=1 },
[450] = { pset={146-3}, namereplaced=3-3, foiltweaked=3-3, dropped=3 },
[430] = { namereplaced=1, dropped=2 },
[410] = { namereplaced=1 },
[400] = { dropped=1 },
[370] = { namereplaced=1 },
[330] = { namereplaced=1, dropped=2 },
[300] = { namereplaced=1 },
[280] = { dropped=2 },
[270] = { namereplaced=2 },
[230] = { dropped=2 },
[220] = { pset={199-1}, dropped=1, namereplaced=1 },
[210] = { namereplaced=1 },
[190] = { namereplaced=5, dropped=2 },
[150] = { namereplaced=1 },
[120] = { namereplaced=3 },
[130] = { namereplaced=17, dropped=3 },
-- special sets
[799] = { foiltweaked=2, pset={ 83-16-2 } },-- -16 basic lands, -2 (of 4) nonbasic lands
[798] = {pset={20-20}, dropped=21 }, 
[796] = { namereplaced=3 },
[794] = { pset={81-12}, dropped=12, foiltweaked=2},
[785] = { pset={79-4}, namereplaced=1, foiltweaked=2-1, dropped=4 },
[772] = { namereplaced=1, foiltweaked=2},
[757] = { foiltweaked=2},
[600] = { pset={141-2}, failed={1}, namereplaced=4, dropped=1, foiltweaked=1-1 },--"Ach! Hans, Run", Super Secret Tech 
[440] = { foiltweaked=2},
[380] = { pset={180-2-2}, failed={2-1}, namereplaced=12-2-6, dropped=9 },--Pang Tong and Kongming fail due to "-Problems
[320] = { namereplaced=3 },
[310] = { dropped=10},
[260] = { pset={228-7}, dropped=7, namereplaced=6 },-- 7 SOON
[200] = { namereplaced=12 },
}--end table site.expected
end--if
--EOF