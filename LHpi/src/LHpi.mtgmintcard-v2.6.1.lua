--*- coding: utf-8 -*-
--[[- LHpi mtgmintcard.com sitescript 
Price import script for Magic Album
uses and needs LHpi library
to import card pricing from www.mtgmintcard.com.

Inspired by and loosely based on "MTG Mint Card.lua" by Goblin Hero, Stromglad1 and "Import Prices.lua" by woogerboy21;
who generously granted permission to "do as I like" with their code;
everything else Copyright (C) 2012-2014 by Christian Harms.
If you want to contact me about the script, try its release thread in http://www.slightlymagic.net/forum/viewforum.php?f=32

@module LHpi_mtgmintcard
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
use LHpi-v2.6
added BNG,FTV:20,DD:HvsM,DD:SvT,DD:VvK,DD:EvT,DD:DvD,Beatdown,Unhinged,Unglued,Portal,Chronicles
started adding missing special and promo sets, some may work, most will not
]]

-- options that control the amount of feedback/logging done by the script
--- @field [parent=#global] #boolean VERBOSE 			default false
VERBOSE = false
--- @field [parent=#global] #boolean LOGDROPS 			default false
LOGDROPS = false
--- @field [parent=#global] #boolean LOGNAMEREPLACE 	default false
LOGNAMEREPLACE = false
--- @field [parent=#global] #boolean LOGFOILTWEAK	 	default false
LOGFOILTWEAK = false

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
--- revision of the LHpi library to use
-- @field [parent=#global] #string libver
libver = "2.6"
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
site.regex = 'class="cardBorderBlack".-(<a.->$[%d.,]+%b<>).-</tr>'

site.currency = "$" -- not used yet
site.encoding = "utf-8" -- utf-16?
site.resultregex = "Your query of .+ filter.+ returns (%d+) results."

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
	local container = {}

	site.domain = "www.mtgmintcard.com/"
	site.prefix = "magic-the-gathering/"
	site.suffix = "?page_show=200&page="
--	site.currency = "&currency_reference=EUR"
--TODO switch to advanced search url?
--http://www.mtgmintcard.com/magic-the-gathering/search?&action=advanced_search&page_show=2000&ed=1021&mo_1=1&mo_2=1&lg_1=1&lg_2=1&cc_1=1&cc_2=1&cc_4=1&cc_6=1&cc_7=1&cc_3=1&cc_8=1&cf=0&ct=-1&ty=0&t2=&pf=-1&pt=99&tf=-1&tt=99&ra_4=1&ra_3=1&ra_2=1&ra_1=1&ra_6=1&rt=&prf=0.00&prt=-1&page=6

	for pagenr=1, site.sets[setid].pages do
		local url = site.domain .. site.prefix .. site.langs[langid].url .. "-" .. site.frucs[frucid] .. "/" .. site.sets[setid].url .. site.suffix .. pagenr
		if offline then
			url = string.gsub( url, "%?", "_" )
			url = string.gsub( url, "/", "_" )
			container[url] = { isfile = true}
		else
			container[url] = {}
		end -- if offline 
		
		if frucid == 1 then 
			container[url].foilonly = true
		else
			-- url without foil marker
		end -- if foil-only url
	end -- for
	if DEBUG then
		LHpi.Log(LHpi.Tostring(container))
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
function site.ParseHtmlData( foundstring , 	urldetails )
	local _start,_end,name = string.find(foundstring, '<a .*href=%b"">([^<]+)%b<>' )
	local _start,_end,price = string.find( foundstring , '[$€]([%d.,]+)' )
	price = string.gsub( price , "[,.]" , "" )
	price = tonumber( price )
	local newCard = { names = { [urldetails.langid] = name }, price = { [urldetails.langid] = price } }
	if DEBUG then
		LHpi.Log( "site.ParseHtmlData\t returns" .. LHpi.Tostring(newCard) , 2 )
	end
	return newCard
end -- function site.ParseHtmlData

--[[- special cases card data manipulation
 Ties into LHpi.buildCardData to make changes that are specific to one site and thus don't belong into the library.
 This Plugin is called before most of LHpi's BuildCardData proecssing.

 @function [parent=#site] BCDpluginPre
 @param #table card		the card LHpi.BuildCardData is working on
 @param #number setid
 @returns #table card modified card is passed back for further processing
]]
function site.BCDpluginPre ( card , setid )
	if DEBUG then
		LHpi.Log( "site.BCDpluginPre got " .. card.name .. " from set " .. setid , 2 )
	end
	
	-- mark condition modifier suffixed cards to be dropped
	card.name = string.gsub( card.name , "%(Used%)$" , "%0 (DROP)" )
	
	--TODO make this into LHpi.Utf16ToUtf8, rename LHpi.Toutf8 to LHpi.AnsiToUtf8
	--even better, add this after "site.encoding == "utf-16" into LHpi.Toutf8
	card.name = string.gsub( card.name , "\195\130\194\174" , "®" ) 	 
	card.name = string.gsub( card.name , "\195\131\194\160" , "à" )
	card.name = string.gsub( card.name , "\195\131\194\162" , "â" ) -- 0xc3 0x83 0xc2 0xa2
	card.name = string.gsub( card.name , "\195\131\194\169" , "é" )
	card.name = string.gsub( card.name , "\195\131\226\128\160" , "Æ" ) -- 0xc3 0x83 0xe2 0x80 0xa0
	card.name = string.gsub( card.name , "\195\160" , "à" )
	card.name = string.gsub( card.name , "\226\128\156" , '"' ) 

	card.name = string.gsub( card.name , "%(Chinese Version%)" , "" )	
-- @lib	card.name = string.gsub( card.name , " / " , "|" )

	card.name = string.gsub( card.name , " ships Sep 27" , "") -- Theros Prerelease suffix

	return card
end -- function site.BCDpluginPre

-------------------------------------------------------------------------------------------------------------
-- tables
-------------------------------------------------------------------------------------------------------------

--[[- table of (supported) languages.
-- { #number = { id = #number, full = #string, abbr = #string } }
-- 
--- @field [parent=#site] #table langs ]]
--- @field [parent=#site] #table langs
site.langs = {
	[1] = {id=1, full = "English", 	abbr="ENG" , 	url="english" },
	[9] = {id=1, full = "Simplified Chinese", abbr="SZH" , 	url="chinese" },
}

--- @field [parent=#site] #table frucs	rarity array { #number = #string }
--site.frucs = { "Foils" , "Regular" }
site.frucs = { "foil" , "regular" }

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
--TODO decide SZH in site but not in MA: [9]=false or expected fails ?
 -- Core sets
[797]={id = 797, lang = { true , [9]=true }, fruc = { true, true },	pages=2, url = "2014+Core+set"},
[788]={id = 788, lang = { true , [9]=true }, fruc = { true ,true }, pages=2, url = "2013+Core+set"}, 
[779]={id = 779, lang = { true , [9]=true }, fruc = { true ,true }, pages=2, url = "2012+Core+set"}, 
[770]={id = 770, lang = { true , [9]=true }, fruc = { true ,true }, pages=2, url = "2011+Core+set"}, 
[759]={id = 759, lang = { true , [9]=true }, fruc = { true ,true }, pages=2, url = "2010+Core+set"}, 
[720]={id = 720, lang = { true , [9]=true }, fruc = { true ,true }, pages=2, url = "10th+Edition+%28X+Edition%29"}, 
[630]={id = 630, lang = { true , [9]=false}, fruc = { true ,true }, pages=2, url = "9th+Edition"}, 
[550]={id = 550, lang = { true , [9]=false}, fruc = { true ,true }, pages=2, url = "8th+Edition"}, 
[460]={id = 460, lang = { true , [9]=false}, fruc = { true ,true }, pages=2, url = "7th+Edition"}, -- SZH in site but not in MA
[360]={id = 360, lang = { true , [9]=false}, fruc = { true ,true }, pages=2, url = "6th+Edition"},
[250]={id = 250, lang = { true , [9]=false}, fruc = { false,true }, pages=3, url = "5th+Edition"},
[180]={id = 180, lang = { true , [9]=false}, fruc = { false,true }, pages=3, url = "4th+Edition"}, 
[141]=nil,--Summer Magic
[140]={id = 140, lang = { true , [9]=false}, fruc = { false,true }, pages=2, url = "3rd+Edition+(Revised)"},
[139]=nil,--Revised Limited Deutsch
[110]={id = 110, lang = { true , [9]=false}, fruc = { false,true }, pages=2, url = "Unlimited"}, 
[100]={id = 100, lang = { true , [9]=false}, fruc = { false,true }, pages=2, url = "Beta"},
[90] ={id =  90, lang = { true , [9]=false}, fruc = { false,true }, pages=2, url = "Alpha"}, 
 -- Expansions
[802]={id = 802, lang = { true , [9]=true }, fruc = { true ,true }, pages=1, url = "born-of-the-gods"},
[800]={id = 800, lang = { true , [9]=true }, fruc = { true ,true }, pages=2, url = "Theros"},
[795]={id = 795, lang = { true , [9]=true }, fruc = { true ,true }, pages=1, url = "dragon's-maze"},
[793]={id = 793, lang = { true , [9]=true }, fruc = { true ,true }, pages=2, url = "gatecrash"},
[791]={id = 791, lang = { true , [9]=true }, fruc = { true ,true }, pages=2, url = "Return+to+Ravnica"},
[786]={id = 786, lang = { true , [9]=true }, fruc = { true ,true }, pages=2, url = "Avacyn+Restored"},
[784]={id = 784, lang = { true , [9]=true }, fruc = { true ,true }, pages=1, url = "Dark+Ascension"}, 
[782]={id = 782, lang = { true , [9]=true }, fruc = { true ,true }, pages=2, url = "Innistrad"}, 
[776]={id = 776, lang = { true , [9]=true }, fruc = { true ,true }, pages=1, url = "New+Phyrexia"},
[775]={id = 775, lang = { true , [9]=true }, fruc = { true ,true }, pages=1, url = "Mirrodin+Besieged"},
[773]={id = 773, lang = { true , [9]=true }, fruc = { true ,true }, pages=2, url = "Scars+of+Mirrodin"},
[767]={id = 767, lang = { true , [9]=true }, fruc = { true ,true }, pages=2, url = "Rise+of+the+Eldrazi"},
[765]={id = 765, lang = { true , [9]=true }, fruc = { true ,true }, pages=1, url = "Worldwake"},
[762]={id = 762, lang = { true , [9]=true }, fruc = { true ,true }, pages=2, url = "Zendikar"},
[758]={id = 758, lang = { true , [9]=true }, fruc = { true ,true }, pages=1, url = "Alara%20Reborn"},
[756]={id = 756, lang = { true , [9]=true }, fruc = { true ,true }, pages=1, url = "Conflux"},
[754]={id = 754, lang = { true , [9]=true }, fruc = { true ,true }, pages=2, url = "Shards+of+Alara"},
[752]={id = 752, lang = { true , [9]=true }, fruc = { true ,true }, pages=1, url = "Eventide"},
[751]={id = 751, lang = { true , [9]=true }, fruc = { true ,true }, pages=2, url = "Shadowmoor"},
[750]={id = 750, lang = { true , [9]=true }, fruc = { true ,true }, pages=1, url = "Morningtide"},
[730]={id = 730, lang = { true , [9]=true }, fruc = { true ,true }, pages=2, url = "Lorwyn"},
[710]={id = 710, lang = { true , [9]=true }, fruc = { true ,true }, pages=1, url = "Future+Sight"},
[700]={id = 700, lang = { true , [9]=true }, fruc = { true ,true }, pages=1, url = "Planar+Chaos"},
[690]={id = 690, lang = { true , [9]=false}, fruc = { true ,true }, pages=1, url = "Timeshifted"},
[680]={id = 680, lang = { true , [9]=true }, fruc = { true ,true }, pages=2, url = "Time+Spiral"},
[670]={id = 670, lang = { true , [9]=false}, fruc = { true ,true }, pages=1, url = "Coldsnap"},
[660]={id = 660, lang = { true , [9]=false}, fruc = { true ,true }, pages=1, url = "Dissension"},
[650]={id = 650, lang = { true , [9]=false}, fruc = { true ,true }, pages=1, url = "Guildpact"},
[640]={id = 640, lang = { true , [9]=false}, fruc = { true ,true }, pages=2, url = "Ravnica"},
[620]={id = 620, lang = { true , [9]=false}, fruc = { true ,true }, pages=1, url = "Saviors+of+Kamigawa"},
[610]={id = 610, lang = { true , [9]=false}, fruc = { true ,true }, pages=1, url = "Betrayers+of+Kamigawa"},
[590]={id = 590, lang = { true , [9]=false}, fruc = { true ,true }, pages=2, url = "Champions+of+Kamigawa"},
[580]={id = 580, lang = { true , [9]=true }, fruc = { true ,true }, pages=1, url = "Fifth+Dawn"},
[570]={id = 570, lang = { true , [9]=false}, fruc = { true ,true }, pages=1, url = "Darksteel"},
[560]={id = 560, lang = { true , [9]=false}, fruc = { true ,true }, pages=2, url = "Mirrodin"},
[540]={id = 540, lang = { true , [9]=false}, fruc = { true ,true }, pages=1, url = "Scourge"},
[530]={id = 530, lang = { true , [9]=false}, fruc = { true ,true }, pages=1, url = "Legions"}, -- SZH in site but not in MA
[520]={id = 520, lang = { true , [9]=false}, fruc = { true ,true }, pages=2, url = "Onslaught"}, -- SZH in site but not in MA
[510]={id = 510, lang = { true , [9]=false}, fruc = { true ,true }, pages=1, url = "Judgment"}, -- SZH in site but not in MA
[500]={id = 500, lang = { true , [9]=false}, fruc = { true ,true }, pages=1, url = "Torment"}, -- SZH in site but not in MA
[480]={id = 480, lang = { true , [9]=false}, fruc = { true ,true }, pages=2, url = "Odyssey"}, -- SZH in site but not in MA
[470]={id = 470, lang = { true , [9]=false}, fruc = { true ,true }, pages=1, url = "Apocalypse"},
[450]={id = 450, lang = { true , [9]=false}, fruc = { true ,true }, pages=1, url = "Planeshift"},
[430]={id = 430, lang = { true , [9]=false}, fruc = { true ,true }, pages=3, url = "Invasion"}, -- SZH in site but not in MA
[420]={id = 420, lang = { true , [9]=false}, fruc = { true ,true }, pages=1, url = "Prophecy"},
[410]={id = 410, lang = { true , [9]=false}, fruc = { true ,true }, pages=1, url = "Nemesis"},
[400]={id = 400, lang = { true , [9]=false}, fruc = { true ,true }, pages=2, url = "Mercadian+Masques"},
[370]={id = 370, lang = { true , [9]=false}, fruc = { true ,true }, pages=1, url = "Urza's+Destiny"},
[350]={id = 350, lang = { true , [9]=false}, fruc = { true ,true }, pages=1, url = "Urza's+Legacy"},
[330]={id = 330, lang = { true , [9]=false}, fruc = { true ,true }, pages=2, url = "Urza's+Saga"},
[300]={id = 300, lang = { true , [9]=false}, fruc = { false,true }, pages=1, url = "Exodus"},
[290]={id = 290, lang = { true , [9]=false}, fruc = { false,true }, pages=1, url = "Stronghold"},
[280]={id = 280, lang = { true , [9]=false}, fruc = { false,true }, pages=2, url = "Tempest"},
[270]={id = 270, lang = { true , [9]=false}, fruc = { false,true }, pages=1, url = "Weatherlight"},
[240]={id = 240, lang = { true , [9]=false}, fruc = { false,true }, pages=1, url = "Visions"},
[230]={id = 230, lang = { true , [9]=false}, fruc = { false,true }, pages=3, url = "Mirage"},
[220]={id = 220, lang = { true , [9]=false}, fruc = { false,true }, pages=1, url = "Alliances"},
[210]={id = 210, lang = { true , [9]=false}, fruc = { false,true }, pages=1, url = "Homelands"},
[190]={id = 190, lang = { true , [9]=false}, fruc = { false,true }, pages=3, url = "Ice+Age"},
[170]={id = 170, lang = { true , [9]=false}, fruc = { false,true }, pages=1, url = "Fallen+Empires"},
[160]={id = 160, lang = { true , [9]=false}, fruc = { false,true }, pages=1, url = "The+Dark"},
[150]={id = 150, lang = { true , [9]=false}, fruc = { false,true }, pages=2, url = "Legends"},
[130]={id = 130, lang = { true , [9]=false}, fruc = { false,true }, pages=1, url = "Antiquities"},
[120]={id = 120, lang = { true , [9]=false}, fruc = { false,true }, pages=1, url = "Arabian+Nights"},
-- special sets
--[801]={id = 801, lang = { true , [9]=false}, fruc = { true , true }, pages=2, url = "commander-2013"},--Commander 2013 Edition
[799]={id = 799, lang = { true , [9]=false}, fruc = { true , true }, pages=1, url = "heroes-vs.-monsters"},--Duel Decks: Heroes vs. Monsters
[798]={id = 798, lang = { true , [9]=false}, fruc = { true , false}, pages=1, url = "from-the-vault%3A-twenty"},--From the Vault: Twenty
[796]={id = 796, lang = { true , [9]=false}, fruc = { true , true }, pages=2, url = "Modern+Masters"},--Modern Masters
[794]={id = 794, lang = { true , [9]=false}, fruc = { true , true }, pages=1, url = "sorin-vs.-tibalt"},--Duel Decks: Sorin vs. Tibalt
[792]=nil,--Commander’s Arsenal
[790]={id = 790, lang = { true , [9]=false}, fruc = { true , true }, pages=1, url = "izzet-vs-golgari"},--Duel Decks: Izzet vs. Golgari
--[789]={id = 789, lang = { true , [9]=true }, fruc = { true , false}, pages=4, url = "from-the-vault%3A-realms"},--From the Vault: Realms
--[787]={id = 787, lang = { true , [9]=true }, fruc = { false, true }, pages=4, url = "planechase-2012-edition"},--Planechase 2012
[785]={id = 785, lang = { true , [9]=false}, fruc = { true , true }, pages=1, url = "venser-vs.-koth"},--Duel Decks: Venser vs. Koth
--[783]={id = 783, lang = { true , [9]=true }, fruc = { true , false}, pages=4, url = "graveborn"},--Premium Deck Series: Graveborn
--[781]={id = 781, lang = { true , [9]=true }, fruc = { true , true }, pages=4, url = "ajani-vs.-nicol-bolas"},--Duel Decks: Ajani vs. Nicol Bolas
--[780]={id = 780, lang = { true , [9]=true }, fruc = { true , false}, pages=4, url = "from-the-vault%3A-legends"},--From the Vault: Legends
--[778]={id = 778, lang = { true , [9]=true }, fruc = { false, true }, pages=4, url = "commander"},--Commander
--[777]={id = 777, lang = { true , [9]=true }, fruc = { true , true }, pages=4, url = "knights-vs.-dragons"},--Duel Decks: Knights vs. Dragons
--[774]={id = 774, lang = { true , [9]=true }, fruc = { true , false}, pages=4, url = "fire-%2526-lightning"},--Premium Deck Series: Fire and Lightning
[772]={id = 772, lang = { true , [9]=false}, fruc = { true , true }, pages=1, url = "elspeth-vs.-tezzeret"},--Duel Decks: Elspeth vs. Tezzeret
--[771]={id = 753, lang = { true , [9]=true }, fruc = { true , false}, pages=4, url = "From+the+Vault%3A+Relics"},--From the Vault: Relics
--[769]={id = 769, lang = { true , [9]=true }, fruc = { false, true }, pages=4, url = "archenemy"},--Archenemy   
--[768]={id = 768, lang = { true , [9]=true }, fruc = { true , true }, pages=4, url = "duels-of-the-planeswalkers"},--Duels of the Planeswalkers
--[766]={id = 766, lang = { true , [9]=true }, fruc = { false, true }, pages=4, url = "phyrexia-vs.-coalition"},--Duel Decks: Phyrexia vs. The Coalition
--[764]={id = 764, lang = { true , [9]=true }, fruc = { true , false}, pages=4, url = "slivers"},--Premium Deck Series: Slivers
--[763]={id = 763, lang = { true , [9]=true }, fruc = { true , true }, pages=4, url = "garruk-vs.-liliana"},--Duel Decks: Garruk vs. Liliana
[761]=nil,--Planechase
[760]=nil,--From the Vault: Exiled
[757]={id = 757, lang = { true , [9]=false}, fruc = { true , true }, pages=1, url = "divine-vs.-demonic"},--Duel Decks: Divine vs. Demonic
--[755]={id = 755, lang = { true , [9]=true }, fruc = { true , true }, pages=4, url = "jace-vs.-chandra"},--Duel Decks: Jace vs. Chandra
--[753]={id = 753, lang = { true , [9]=true }, fruc = { true , false}, pages=4, url = "from-the-vault%3A-dragons"},--From the Vault: Dragons
[740]=nil,--Duel Decks: Elves vs. Goblins   
[675]=nil,--Coldsnap Theme Decks
[635]=nil,--Magic Encyclopedia
[600]={id = 600, lang = { true , [9]=false}, fruc = { false, true }, pages=1, url = "unhinged"},--Unhinged
--[490]={id = 490, lang = { true , [9]=true }, fruc = { false, true }, pages=4, url = "deckmasters"},--Deckmaster
[440]={id = 440, lang = { true , [9]=false}, fruc = { false, true }, pages=1, url = "beatdown"},--Beatdown Box Set
[415]=nil,--Starter 2000   
--[405]={id = 405, lang = { true , [9]=true }, fruc = { true , true }, pages=4, url = "battle-royale"},--Battle Royale Box Set
[390]=nil,--Starter 1999
[380]=nil,--Portal Three Kingdoms   
--[340]={id = 340, lang = { true , [9]=true }, fruc = { true , true }, pages=4, url = "anthologies"},--Anthologies
[320]={id = 320, lang = { true , [9]=false}, fruc = { false, true }, pages=1, url = "unglued"},--Unglued
[310]=nil,--Portal Second Age   
[260]={id = 260, lang = { true , [9]=false}, fruc = { false, true }, pages=2, url = "portal"},--Portal
[225]=nil,--Introductory Two-Player Set
[201]=nil,--Renaissance
[200]={id = 200, lang = { true , [9]=false}, fruc = { false, true }, pages=1, url = "chronicles"},--Chronicles
--[70] ={id =  70, lang = { true , [9]=true }, fruc = { false, true }, pages=4, url = "vanguard"},--Vanguard
[69] =nil,--Box Topper Cards
-- World Championship and Promo sets: sorting out the two single page seems more trouble than it's worth
} -- end table site.sets

--[[- card name replacement tables.
-- { #number = #table { #string = #string } }
-- 
--- @field [parent=#site] #table namereplace ]]
--- @field [parent=#site] #table namereplace
site.namereplace = {
[797] = { -- M2014
["Elemental Token(7)"]					= "Elemental (7)",
["Elemental Token (8)"]					= "Elemental (8)",
},
[770] = { -- M11
["Ooze Token 5/6"]						= "Ooze (6)",
["Ooze Token 6/6 Textless"]				= "Ooze (5)",
},
[140] = { -- Revised Edition
--["El-Hajjâj"]							= "El-Hajjaj",
},
[90] = { -- Alpha
["Circle of Protection : Blue"]			= "Circle of Protection: Blue",
["Circle of Protection : Green"]		= "Circle of Protection: Green",
["Circle of Protection : Red"]			= "Circle of Protection: Red",
["Circle of Protection : White"]		= "Circle of Protection: White",
},
[802] = { -- Born of the Gods
["Unravel the Æther (Unravel the Aether)"]	= "Unravel the Aether",
["Bird Token(4)"]						= "Bird (4)",
["Birds Token(1)"]						= "Bird (1)",
},
[800] = { -- Theros
["Warrior's Lesson"]					= "Warriors' Lesson",
["Soldier Token(2)"]					= "Soldier (2)",
["Soldier Token(3)"]					= "Soldier (3)",
["Soldier Token(7)"]					= "Soldier (7)",
},
[795] = { -- Dragon's Maze
["Aetherling (Ætherling)"]				= "Ætherling",
},
[786] = { -- Avacyn Restored
["Spirit Token (White)"]				= "Spirit (3)",
["Spirit Token (Blue)"]					= "Spirit (4)",
["Human Token (White)"]					= "Human (2)",
["Human Token (Red)"]					= "Human (7)",
},
[782] = { -- Innistrad
["Double-Sided Card Checklist"]			= "Checklist",
["Curse of the Nightly Haunt"]			= "Curse of the Nightly Hunt",
--["Alter's Reap"] 						= "Altar's Reap",
--["Elder Cather"] 						= "Elder Cathar",
--["Moldgraft Monstrosity"] 				= "Moldgraf Monstrosity",
["Zombie Token 7/12"]					= "Zombie (7)",
["Zombie Token 8/12"]					= "Zombie (8)",
["Zombie Token 9/12"]					= "Zombie (9)",
["Black Wolf Token"]					= "Wolf (6)",
["Green Wolf Token"]					= "Wolf (12)",
},
[773] = { -- Scars of Mirrodin
["Wurm Token 8/9"]						= "Wurm (8)",
["Wurm Token 9/9"]						= "Wurm (9)",
},
[767] = { -- Rise of the Eldrazi
["Eldrazi Spawn 1A"] 					= "Eldrazi Spawn (1a)",
["Eldrazi Spawn 1B"] 					= "Eldrazi Spawn (1b)",
["Eldrazi Spawn 1C"] 					= "Eldrazi Spawn (1c)",
},
[754] = { -- Shards of Alara
["Godsire Beast Token"]					= "Beast Token"
},
[751] = { -- Shadowmoor
["Elf Warrior Token (Green)"]			= "Elf Warrior (5)",
["Elf Warrior Token (Green & White)"]	= "Elf Warrior (12)",
["Elemental Token (Red)"]				= "Elemental (4)",
["Elemental Token (Black & Red)"]		= "Elemental (9)",
},
[730] = { -- Lorwyn
["Elemental Token (White)"]				= "Elemental (2)",
["Elemental Token (Green)"]				= "Elemental (8)",
},
[690] = { -- Time Spiral Timeshifted
["XXValor"]								= "Valor",
},
[610] = { -- Betrayers of Kamigawa
["Hired Muscle"] 						= "Hired Muscle|Scarmaker",
["Callow Jushi"] 						= "Callow Jushi|Jaraku the Interloper",
},
[520] = { -- Onslaught
["AEther Charge (Æther Charge)"]		= "Æther Charge",
},
[470] = { -- Apocalypse
["Ice"]		 							= "Fire|Ice",
},
[150] = { -- Legends
["AErathi Berserker"]					= "Ærathi Berserker",
},
[130] = { -- Antiquities
["Karakas"]								= "Mishra's Factory (Autumn)",
},
[120] = { -- Arabian Nights
--["El-Hajjâj"]							= "El-Hajjaj",
--["Dandân"]								= "Dandan",
},
-- special sets
[796] = { -- Modern Masters
["Aethersnipe (Æthersnipe)"]			= "Æthersnipe",
["Aether Spellbomb (Æther Spellbomb)"]	= "Æther Spellbomb",
["Aether Vial (Æther Vial)"]			= "Æther Vial",
},
[600] = { -- Unhinged
["Who|What/When|Where/Why"]				= "Who|What|When|Where|Why",
--TODO['"Ach! Hans, Run!"']
},
[320] = { -- Unglued
["B.F.M. (Big Furry Monster)"]			= "B.F.M.",--TODO grep P/T to distinguish left/right
--["Chicken à la King"]					= "Chicken à la King",
--["The Ultimate Nightmare ..."]			= "The Ultimate Nightmare of Wizards of the Coast® Customer Service",
},
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
[799] = {},
[794] = {},
[790] = {},
[785] = {},
[772] = {},
[757] = {},

} -- end table foiltweak

if CHECKEXPECTED then
--[[- table of expected results.
-- as of script release
-- { #number = #table { #table pset = #table { #number = #number, ... }, #table failed = #table { #number = #number, ... }, dropped = #number , namereplaced = #number , foiltweaked = #number }
-- 
--- @field [parent=#site] #table expected ]]
--- @field [parent=#site] #table expected
site.expected = {
EXPECTTOKENS = true,
-- Core sets
[797] = { pset={ [9]=262-13 }, failed={ [9]=12}, namereplaced=4 }, -- 13 tokens
[788] = { pset={ [9]=249 }, failed={[9]=11} },-- fail SZH tokens
[779] = { pset={ [9]=249 }, failed={[9]=7} },-- fail SZH tokens
[770] = { namereplaced=4, pset={ [9]=249 }, failed={[9]=5} },-- fail SZH tokens
[759] = { pset={ [9]=249-20 }, failed={[9]=8}, dropped=8 },-- no SZH lands, fail SZH tokens
[720] = { pset={ [9]=383-20 }, failed={[9]=6}, dropped=3 }, -- no SZH lands, fail SZH tokens	
[630] = { pset={ 359-31 } },
[550] = { pset={ 357-27 } },
[460] = { pset={ 350-20 }, dropped=3 },
[360] = { pset={ 350-20 }, dropped=18 },
[250] = { pset={ 449-20 }, dropped=50 },
[180] = { pset={ 378-15 }, dropped=85 },
[140] = { pset={ 306-15 }, dropped=29 },
[110] = { dropped=2 },
[100] = { pset={ 302-19 } },
[90]  = {namereplaced=4},
-- Expansions
[802] = {namereplaced=7, pset={[9]=165}, failed={[9]=10}},-- fail SZH tokens
[800] = {namereplaced=10, pset={[9]=249}, failed={[9]=9}},-- fail SZH tokens
[795] = { namereplaced=4, pset={ [9]=156 }, failed={[9]=1} },-- fail SZH tokens
[793] = { pset={ [9]=249 }, failed={[9]=8} },-- fail SZH tokens
[791] = { pset={ [9]=274 }, failed={[9]=11} },-- fail SZH tokens
[786] = { pset={ 252-1, [9]=244-1 }, failed={[9]=6}, namereplaced=8 },-- missing 1 swamp, fail SZH tokens
[784] = { pset={ [9]=158 }, failed={[9]=3} },-- fail SZH tokens
[782] = { pset={ 276+1, [9]=264 }, failed={[9]=9}, namereplaced=15 },-- fail SZH tokens, +1 is Checklist
[776] = { pset={ [9]=175 }, failed={[9]=4} },-- fail SZH tokens
[775] = { pset={160-1, [9]=155} },-- no ENG zombie token, no SZH tokens
[773] = { namereplaced=4, pset={[9]=249+1}, failed={1, [9]=8} },-- fail SZH tokens
[767] = { pset={ [9]=248 }, failed={[9]=5}, namereplaced=6 },-- fail SZH tokens
[765] = { pset={ [9]=145 } },-- no SZH tokens
[756] = { pset={ [9]=145 } },-- no SZH tokens
[762] = { pset={ [9]=249 }, dropped=1 },-- no SZH tokens
[758] = { pset={ [9]=145 }, failed={[9]=4} },-- fail SZH tokens
[756] = { pset={ [9]=145 } },-- no SZH tokens
[754] = { pset={ [9]=249 }, failed={[9]=9}, namereplaced=1 },-- fail SZH tokens
[752] = { pset={ [9]=180 }, failed={[9]=7} },-- fail SZH tokens
[751] = { pset={ [9]=301-20 }, failed={[9]=10}, namereplaced=8 },-- fail SZH tokens, no SZH lands
[750] = { pset={ [9]=150 } },-- no SZH tokens
[730] = { pset={ [9]=301-1 }, failed={[9]=10}, dropped=1, namereplaced=4 },-- -1 is missing "Changeling Berserker" (SZH), fail SZH tokens
[710] = { dropped=2 },
[700] = { dropped=1 },
[690] = { dropped=1, namereplaced=2 },
[680] = { pset={ [9]=4 }, dropped=1 },
[660] = { dropped=1 },
[640] = { dropped=2 },
[620] = { dropped=1 },
[610] = { dropped=2, namereplaced=4 },
[580] = { pset={ [9]=110 }, dropped=2 },
[570] = { dropped=1 },
[560] = { pset={ 306-20}, dropped=5 },
[540] = { dropped=3 },
[530] = { dropped=2 },
[520] = { namereplaced=1, dropped=7 },
[510] = { dropped=16 },
[500] = { dropped=9 },
[480] = { pset={ 350-20 }, 	dropped=29 },
[470] = { dropped=4, namereplaced=1 },
[450] = { pset={ 146-3 }, dropped=23 },
[430] = { dropped=97 },
[420] = { pset={ 143-60 }, dropped=8 },
[410] = { pset={ 143-1 }, dropped=9 },
[400] = { pset={ 350-20 }, dropped=13 },
[370] = { dropped=10 },
[350] = { dropped=10 },
[330] = { pset={ 350-20 }, dropped=30 }, -- no lands
[300] = { dropped=10 },
[290] = { dropped=21 },
[280] = { pset={ 350-20 }, dropped=53 },
[270] = { dropped=8 },
[240] = { dropped=11 },
[230] = { pset={ 350-21 }, dropped=69 },
[220] = { dropped=10 },
[210] = { dropped=6 },
[190] = { pset={ 383-15 }, dropped=86 },-- no basic lands
[170] = { dropped=18 },
[160] = { dropped=9 },
[150] = { dropped=22, namereplaced=1 },
[130] = { dropped=7, namereplaced=1 },
[120] = { dropped=12 },
-- special sets
[796] = { namereplaced=6},
[794] = { pset={ 81-12-1} },-- -16 basic lands, -1 token
[790] = { pset={ 91-16-1} },-- -16 basic lands, -1 token
[785] = { pset={ 79-2} },-- -2 tokens
[772] = { pset={ 80-8-1} },-- -8 basic lands, -1 token
[600] = { pset={141-2} },--"Kill! Destroy!" and "Super Secret Tech" missing
[440] = { foiltweaked=2 },
[320] = { dropped=3, namereplaced=2 },
[260] = { dropped=27, pset={228-20} },-- no basic lands
[200] = { pset={ 125-1 }, dropped=1 },-- "Wall of Shadows" missing
}
end
