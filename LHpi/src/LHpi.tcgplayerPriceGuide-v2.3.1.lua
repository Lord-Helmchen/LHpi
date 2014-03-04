--*- coding: utf-8 -*-
--[[- LHpi sitescript for magic.tcgplayer.com PriceGuide 

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
use LHpi-v2.3 
added M14 and MMA
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
--- revision of the LHpi library to use
-- @field [parent=#global] #string libver
libver = "2.3"
--- must always be equal to the scripts filename !
-- @field [parent=#global] #string scriptname	
scriptname = "LHpi.tcgplayerPriceGuide-v" .. libver .. ".1.lua" 

--- @field [parent=#global] #table LHpi		LHpi library table
LHpi = {}

--- Site specific configuration
-- Settings that define the source site's structure and functions that depend on it
-- @type site
-- 
-- @field #string regex

site={}
site.regex = '<TR height=20>(.-)</TR>'

--- @field [parent=#site] #table himelo		defines the three price columns
site.himelo = { "high" , "medium" , "low" }


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
	-- choose column to import from
	himelo = 3 -- not local, read in ParseHtmlData
	LHpi.Log("Importing " .. site.himelo[himelo] .. " prices. Columns available are " .. LHpi.Tostring(site.himelo) , 1 )
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
	site.domain = "magic.tcgplayer.com/db/"
	site.file = "price_guide.asp"
	site.setprefix = "?setname="
	
	local container = {}
	local url = site.file .. site.setprefix .. site.sets[setid].url
	if offline then
		url = savepath .. string.gsub( url, "%?", "_" )  .. ".html"
		container[url] = { isfile = true}
	else
		url = "http://" .. site.domain .. url
		container[url] = {}
	end -- if offline 
	container[url].foilonly = false -- just to make the point :)
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
	local tablerow = {}
	for column in string.gmatch(foundstring , "<td[^>]->+%b<>([^<]+)%b<></td>") do
		table.insert(tablerow , column)
	end -- for column
	if DEBUG then
		LHpi.Log("(parsed):" .. LHpi.Tostring(tablerow) , 2 )
	end
	local name = string.gsub( tablerow[1], "&nbsp;" , "" )	 
	local price = ( tablerow[ ( himelo+5 ) ] ) or 0 -- 6 to 8
	price = string.gsub( price , "&nbsp;" , "" )
	price = string.gsub( price , "%$" , "" )
	price = string.gsub( price , "[,.]" , "" )
	local newCard = { names = { [1] = name } , price = { [1] = price } }
	return newCard
end -- function site.ParseHtmlData

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
}

--- @field [parent=#site] #table frucs	rarity array { #number = #string }
site.frucs = { "" , "" } -- see comment in site.sets

--[[- table of available sets
-- { #number = #table { #number id, #table lang = #table { #boolean, ... } , #table fruc = # table { #boolean, ... }, #string url } }
-- #number id		: setid (can be found in "Database\Sets.txt" file)
-- #table fruc		: table of available rarity urls to be parsed
--		compare with site.frucs
-- 		#boolean fruc[1]	: does foil url exist?
-- 		#boolean fruc[2]	: does rares url exist?
-- #table lang		:  table of available languages { #boolean , ... }
-- #string url		: set url infix
-- 
--- @field [parent=#site] #table sets ]]
--- @field [parent=#site] #table sets
site.sets = {
--[[
	setting fruc = { true } would be enough, as the site only provides one table per set
	(which doesn't even give explicit foil prices)
	but I wanted to retain the information Golob gathered,
	and LHpi.Listsources will sort out the duplicate urls anyway.
--]]
-- Core sets
[797]={ id = 797 , fruc = { true , true },	lang = { true }, url = "Magic%202014%20(M14)"},
[788]={ id = 788 , fruc = { true , true } , lang = { true }, url = "Magic%202013%20(M13)"},
[779]={ id = 779 , fruc = { true , true } , lang = { true }, url = "Magic%202012%20(M12)"},
[759]={ id = 759 , fruc = { true , true } , lang = { true }, url = "Magic%202010"},
[720]={ id = 720 , fruc = { true , true } , lang = { true }, url = "10th%20Edition"},
[630]={ id = 630 , fruc = { true , true } , lang = { true }, url = "9th%20Edition"},
[550]={ id = 550 , fruc = { true , true } , lang = { true }, url = "8th%20Edition"},
[460]={ id = 460 , fruc = { true , true } , lang = { true }, url = "7th%20Edition"},
[360]={ id = 360 , fruc = { true , true } , lang = { true }, url = "Classic%20Sixth%20Edition"},
[250]={ id = 250 , fruc = { true , false} , lang = { true }, url = "Fifth%20Edition"},
[180]={ id = 180 , fruc = { true , false} , lang = { true }, url = "Fourth%20Edition"},
[140]={ id = 140 , fruc = { true , false} , lang = { true }, url = "Revised%20Edition"},
[110]={ id = 110 , fruc = { true , false} , lang = { true }, url = "Unlimited%20Edition"},
[100]={ id = 100 , fruc = { true , false} , lang = { true }, url = "Beta%20Edition"},
[90] ={ id =  90 , fruc = { true , false} , lang = { true }, url = "Alpha%20Edition"},
-- Expansions
[795]={ id = 795 , fruc = { true , true } , lang = { true }, url = "Dragon's%20Maze"},
[793]={ id = 793 , fruc = { true , true } , lang = { true }, url = "Gatecrash"},
[791]={ id = 791 , fruc = { true , true } , lang = { true }, url = "Return%20to%20Ravnica"},
[786]={ id = 786 , fruc = { true , true } , lang = { true }, url = "Avacyn%20Restored"},
[784]={ id = 784 , fruc = { true , true } , lang = { true }, url = "Dark%20Ascension"},
[782]={ id = 782 , fruc = { true , true } , lang = { true }, url = "Innistrad"},
[776]={ id = 776 , fruc = { true , true } , lang = { true }, url = "New%20Phyrexia"},
[775]={ id = 775 , fruc = { true , true } , lang = { true }, url = "Mirrodin%20Besieged"},
[773]={ id = 773 , fruc = { true , true } , lang = { true }, url = "Scars%20of%20Mirrodin"},
[770]={ id = 770 , fruc = { true , true } , lang = { true }, url = "Magic%202011%20(M11)"},
[767]={ id = 767 , fruc = { true , true } , lang = { true }, url = "Rise%20of%20the%20Eldrazi"},
[765]={ id = 765 , fruc = { true , true } , lang = { true }, url = "Worldwake"},
[762]={ id = 762 , fruc = { true , true } , lang = { true }, url = "Zendikar"},
[758]={ id = 758 , fruc = { true , true } , lang = { true }, url = "Alara%20Reborn"},
[756]={ id = 756 , fruc = { true , true } , lang = { true }, url = "Conflux"},
[754]={ id = 754 , fruc = { true , true } , lang = { true }, url = "Shards%20of%20Alara"},
[752]={ id = 752 , fruc = { true , true } , lang = { true }, url = "Eventide"},
[751]={ id = 751 , fruc = { true , true } , lang = { true }, url = "Shadowmoor"},
[750]={ id = 750 , fruc = { true , true } , lang = { true }, url = "Morningtide"},
[730]={ id = 730 , fruc = { true , true } , lang = { true }, url = "Lorwyn"},
[710]={ id = 710 , fruc = { true , true } , lang = { true }, url = "Future%20Sight"},
[700]={ id = 700 , fruc = { true , true } , lang = { true }, url = "Planar%20Chaos"},
[690]={ id = 690 , fruc = { true , true } , lang = { true }, url = "Timeshifted"},
[680]={ id = 680 , fruc = { true , true } , lang = { true }, url = "Time%20Spiral"},
[670]={ id = 670 , fruc = { true , true } , lang = { true }, url = "Coldsnap"},
[660]={ id = 660 , fruc = { true , true } , lang = { true }, url = "Dissension"},
[650]={ id = 650 , fruc = { true , true } , lang = { true }, url = "Guildpact"},
[640]={ id = 640 , fruc = { true , true } , lang = { true }, url = "Ravnica"},
[620]={ id = 620 , fruc = { true , true } , lang = { true }, url = "Saviors%20of%20Kamigawa"},
[610]={ id = 610 , fruc = { true , true } , lang = { true }, url = "Betrayers%20of%20Kamigawa"},
[590]={ id = 590 , fruc = { true , true } , lang = { true }, url = "Champions%20of%20Kamigawa"},
[580]={ id = 580 , fruc = { true , true } , lang = { true }, url = "Fifth%20Dawn"},
[570]={ id = 570 , fruc = { true , true } , lang = { true }, url = "Darksteel"},
[560]={ id = 560 , fruc = { true , true } , lang = { true }, url = "Mirrodin"},
[540]={ id = 540 , fruc = { true , true } , lang = { true }, url = "Scourge"},
[530]={ id = 530 , fruc = { true , true } , lang = { true }, url = "Legions"},
[520]={ id = 520 , fruc = { true , true } , lang = { true }, url = "Onslaught"},
[510]={ id = 510 , fruc = { true , true } , lang = { true }, url = "Judgment"},
[500]={ id = 500 , fruc = { true , true } , lang = { true }, url = "Torment"},
[480]={ id = 480 , fruc = { true , true } , lang = { true }, url = "Odyssey"},
[470]={ id = 470 , fruc = { true , true } , lang = { true }, url = "Apocalypse"},
[450]={ id = 450 , fruc = { true , true } , lang = { true }, url = "Planeshift"},
[430]={ id = 430 , fruc = { true , true } , lang = { true }, url = "Invasion"},
[420]={ id = 420 , fruc = { true , true } , lang = { true }, url = "Prophecy"},
[410]={ id = 410 , fruc = { true , true } , lang = { true }, url = "Nemesis"},
[400]={ id = 400 , fruc = { true , true } , lang = { true }, url = "Mercadian%20Masques"},
[370]={ id = 370 , fruc = { true , true } , lang = { true }, url = "Urza's%20Destiny"},
[350]={ id = 350 , fruc = { true , true } , lang = { true }, url = "Urza's%20Legacy"},
[330]={ id = 330 , fruc = { true , true } , lang = { true }, url = "Urza's%20Saga"},
[300]={ id = 300 , fruc = { true , false} , lang = { true }, url = "Exodus"},
[290]={ id = 290 , fruc = { true , false} , lang = { true }, url = "Stronghold"},
[280]={ id = 280 , fruc = { true , false} , lang = { true }, url = "Tempest"},
[270]={ id = 270 , fruc = { true , false} , lang = { true }, url = "Weatherlight"},
[240]={ id = 240 , fruc = { true , false} , lang = { true }, url = "Visions"},
[230]={ id = 230 , fruc = { true , false} , lang = { true }, url = "Mirage"},
[220]={ id = 220 , fruc = { true , false} , lang = { true }, url = "Alliances"},
[210]={ id = 210 , fruc = { true , false} , lang = { true }, url = "Homelands"},
[200]={ id = 200 , fruc = { true , false} , lang = { true }, url = "Chronicles"},
[190]={ id = 190 , fruc = { true , false} , lang = { true }, url = "Ice%20Age"},
[170]={ id = 170 , fruc = { true , false} , lang = { true }, url = "Fallen%20Empires"},
[160]={ id = 160 , fruc = { true , false} , lang = { true }, url = "The%20Dark"},
[150]={ id = 150 , fruc = { true , false} , lang = { true }, url = "Legends"},
[130]={ id = 130 , fruc = { true , false} , lang = { true }, url = "Antiquities"},
[120]={ id = 120 , fruc = { true , false} , lang = { true }, url = "Arabian%20Nights"},
-- special sets
[796]={ id = 796 , fruc = { true , true } ,	lang = { true }, url = "Modern+Masters"},
[600]={ id = 600 , fruc = { true , false} , lang = { true }, url = "Unhinged"},
[320]={ id = 320 , fruc = { true , false} , lang = { true }, url = "Unglued"},
[380]={ id = 380 , fruc = { true , false} , lang = { true }, url = "Portal%20Three%20Kingdoms"},   
[310]={ id = 310 , fruc = { true , false} , lang = { true }, url = "Portal%20Second%20Age"},   
[260]={ id = 260 , fruc = { true , false} , lang = { true }, url = "Portal"},
-- unsupported yet
--[790]={ id = 790 , fruc = { true , false} , lang = { true }, url = "Duel%20Decks:%20Garruk%20vs.%20Liliana"},
--[789]={ id = 789 , fruc = { false , true} , lang = { true }, url = "From%20the%20Vault%3A%20Realms"},
--[787]={ id = 787 , fruc = { true , false} , lang = { true }, url = "Planechase%202012"},
--[785]={ id = 785 , fruc = { true , true } , lang = { true }, url = "Venser%20vs.%20Koth"},
--[783]={ id = 783 , fruc = { false , true} , lang = { true }, url = "Graveborn"},
--[781]={ id = 781 , fruc = { true , true } , lang = { true }, url = "Ajani%20vs.%20Nicol%20Bolas"},
--[780]={ id = 780 , fruc = { false , true} , lang = { true }, url = "From%20the%20Vault%3A%20Legends"},
--[778]={ id = 778 , fruc = { true , false} , lang = { true }, url = "Commander"},
--[777]={ id = 777 , fruc = { true , true } , lang = { true }, url = "Knights%20vs.%20Dragons"},
--[774]={ id = 774 , fruc = { false , true} , lang = { true }, url = "Premium%20Deck%20Series:%20Fire%20and%20Lightning"},
--[772]={ id = 772 , fruc = { true , true } , lang = { true }, url = "Duel%20Decks:%20Elspeth%20vs.%20Tezzeret"},
--[771]={ id = 771 , fruc = { false , true} , lang = { true }, url = "From%20the%20Vault%3A%20Relics"},
--[769]={ id = 769 , fruc = { true , false} , lang = { true }, url = "Archenemy"},   
--[768]={ id = 768 , fruc = { true , true } , lang = { true }, url = "Duels%20of%20the%20Planeswalkers"},
--[766]={ id = 766 , fruc = { true , false} , lang = { true }, url = "Duel%20Decks:%20Phyrexia%20vs.%20The%20Coalition"},
--[764]={ id = 764 , fruc = { false , true} , lang = { true }, url = "Premium%20Deck%20Series:%20Slivers"},
--[763]={ id = 763 , fruc = { true , true } , lang = { true }, url = "Garruk%20VS%20Liliana"},
--[761]={ id = 761 , fruc = { true , false} , lang = { true }, url = "Planechase"},   
--[757]={ id = 757 , fruc = { true , true } , lang = { true }, url = "Duel%20Decks:%20Divine%20vs.%20Demonic"},
--[755]={ id = 755 , fruc = { true , true } , lang = { true }, url = "Duel%20Decks:%20Jace%20vs.%20Chandra"},
--[740]={ id = 740 , fruc = { true , true } , lang = { true }, url = "Duel%20Decks: Elves vs. Goblins"},   
--[490]={ id = 490 , fruc = { true , false} , lang = { true }, url = "Deckmaster"},
--[440]={ id = 440 , fruc = { true , true } , lang = { true }, url = "Beatdown%20Box%20Set"},
--[415]={ id = 415 , fruc = { true , false} , lang = { true }, url = "Starter%202000"},   
--[405]={ id = 405 , fruc = { true , true } , lang = { true }, url = "Battle%20Royale%20Box%20Set"},
--[390]={ id = 390 , fruc = { true , false} , lang = { true }, url = "Starter%201999"},
--[70] ={ id =  70 , fruc = { true , false} , lang = { true }, url = "Vanguard"},
--[40] ={ id =  40 , fruc = { false , true} , lang = { true }, url = "Arena%20Promos"},
--[30] ={ id =  30 , fruc = { false , true} , lang = { true }, url = "FNM%20Promos"},
--[26] ={ id =  26 , fruc = { false , true} , lang = { true }, url = "Game%20Day%20Promos"},
--[25] ={ id =  25 , fruc = { false , true} , lang = { true }, url = "Judge%20Promos"},
--[24] ={ id =  24 , fruc = { false , true} , lang = { true }, url = "Champs%20Promos"},
--[23] ={ id =  23 , fruc = { false , true} , lang = { true }, url = "Gateway%20Promos"},
--[22] ={ id =  22 , fruc = { false , true} , lang = { true }, url = "Prerelease%20Cards"},
--[21] ={ id =  21 , fruc = { false , true} , lang = { true }, url = "Launch%20Party%20Cards"},
--[20] ={ id =  20 , fruc = { false , true} , lang = { true }, url = "Magic%20Player%20Rewards"},
} -- end table site.sets

--[[- card name replacement tables.
-- { #number = #table { #string = #string } }
-- 
--- @field [parent=#site] #table namereplace ]]
--- @field [parent=#site] #table namereplace
site.namereplace = {
[250] = { -- 5th Edition
["Ghazban Ogre"]						= "Ghazbán Ogre",
},
[180] = { -- 4th Edition
["Junun Efreet"]						= "Junún Efreet",
["El-Hajjaj"]							= "El-Hajjâj",
},
[140] = { -- Revised
["El-Hajjâj"]							= "El-Hajjaj",
},
[795] = { -- Dragon's Maze
["AEtherling"]							= "Ætherling",
},
[793] = { -- Gatecrash
["Aetherize"]							= "Ætherize",
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
},
[773] = { -- Scars of Mirrodin
-- I have no idea which one they call "A"
["Wurm Token (A)"]						= "Wurm",
["Wurm Token (B)"]						= "Wurm",
},
[680] = { -- Time Spiral
["Lim-Dul the Necromancer"]				= "Lim-Dûl the Necromancer"
},
[670] = { -- Coldsnap
["Jotun Owl Keeper"]					= "Jötun Owl Keeper",
["Jotun Grunt"]							= "Jötun Grunt"
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
["Khabál Ghoul"]						= "Khabal Ghoul",
["Juzám Djinn"]							= "Juzam Djinn",
["Army of Allah"] 						= "Army of Allah (1)",
["Bird Maiden"] 						= "Bird Maiden (1)",
["Erg Raiders"] 						= "Erg Raiders (1)",
["Fishliver Oil"] 						= "Fishliver Oil (1)",
["Giant Tortoise"] 						= "Giant Tortoise (1)",
["Hasran Ogress"] 						= "Hasran Ogress (1)",
["Moorish Cavalry"] 					= "Moorish Cavalry (1)",
["Naf's Asp"] 							= "Nafs Asp (1)",
["Naf's Asp (2)"] 						= "Nafs Asp (2)",
["Oubliette"] 							= "Oubliette (1)",
["Rukh Egg"] 							= "Rukh Egg (1)",
["Piety"] 								= "Piety (1)",
["Ring of Ma'ruf"]						= "Ring of Ma ruf",
["Stone-Throwing Devils"] 				= "Stone-Throwing Devils (1)",
["War Elephant"] 						= "War Elephant (1)",
["Wyluli Wolf"] 						= "Wyluli Wolf (1)",
},
-- special sets
[600] = { -- Unhinged
["Ach! Hans, Run!"]						= '"Ach! Hans, Run!"',
["Our Market Research..."]				= "Our Market Research Shows That Players Like Really Long Card Names So We Made this Card to Have the Absolute Longest Card Name Ever Elemental",
["Kill Destroy"]						= "Kill! Destroy!",
["Who|What/When|Where/Why"]				= "Who|What|When|Where|Why",
},
[380] = { -- Portal Three Kingdoms
["Pang Tong, “Young Phoenix”"]			= 'Pang Tong, "Young Phoenix"',
["Kongming, “Sleeping Dragon”"]			= 'Kongming, "Sleeping Dragon"',
["Sun Ce, Young Conqueror"]				= "Sun Ce, Young Conquerer",
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
["B.F.M. (Big Furry Monster Left)"]		= "B.F.M. (left)",
["B.F.M. (Big Furry Monster Right)"]	= "B.F.M. (right)",
["The Ultimate Nightmare of Wizards of the Coast\174 Cu"]	= "The Ultimate Nightmare of Wizards of the Coast® Customer Service",
["[Goblin token card]"]					= "Goblin",
["[Sheep token card]"]					= "Sheep",
["[Soldier token card]"]				= "Soldier",
["[Squirrel token card]"]				= "Squirrel",
["[Zombie token card]"]					= "Zombie",
},
[200] = { -- Chronicles
["Urza's Mine"] 						= "Urza's Mine (1)",
["Urza's Power Plant"] 					= "Urza's Power Plant (1)",
["Urza's Tower"] 						= "Urza's Tower (1)",
}
} -- end table site.namereplace

if CHECKEXPECTED then
--[[- table of expected results.
-- as of script release
-- { #number = #table { #table pset = #table { #number = #number, ... }, #table failed = #table { #number = #number, ... },	dropped = #number ,	namereplaced = #number }
-- 
--- @field [parent=#site] #table expected ]]
--- @field [parent=#site] #table expected
site.expected = {
-- Core sets
[770] = { failed={ 15 } },
[720] = { pset={ 384-1 }, failed={ 1 } },
[250] = { namereplaced=1 },
[180] = { namereplaced=2 },
[140] = { namereplaced=1 },
[110] = { failed={ 10 } },
[100] = { failed={ 10 } },
[90]  = { failed={ 10 } },
-- Expansions
[795] = { namereplaced=1 },
[793] = { namereplaced=1 },
[784] = { namereplaced=14 },
[782] = { pset={ 264+1 }, namereplaced=21 },
[776] = { pset={ 175+4 } },
[775] = { pset={ 155+1 }, failed={ 4 } },
[773] = { pset={ 249+9 }, failed={ 1 }, namereplaced=2 },
[767] = { failed={ 15 } },
[762] = { pset={ 269-20 } },
[680] = { namereplaced=1 },
[670] = { namereplaced=2 },
[620] = { namereplaced=5 },
[610] = { namereplaced=5 },
[590] = { namereplaced=10 },
[450] = { pset={ 146-3 } },
[250] = { namereplaced=1 },
[220] = { namereplaced=1 },
[210] = { failed={ 25 } },
[190] = { namereplaced=5 },
[170] = { failed={ 85 } },
[120] = { namereplaced=18 },
[130] = { failed={ 16 } },
-- special sets
[600] = { namereplaced=4 },
[380] = { namereplaced=11 },
[310] = { failed= { 10 } },
[320] = { pset={ 88-1+6}, namereplaced=8 },
[270] = { namereplaced=1 },
[260] = { failed= { 22 } },
[200] = { namereplaced=3 },
}
end
