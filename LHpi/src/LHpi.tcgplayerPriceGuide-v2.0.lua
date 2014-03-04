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
SAVEHTML = false
--- log to seperate logfile instead of Magic Album.log;	default true
-- @field [parent=#global] #boolean SAVELOG
SAVELOG = true
--- save price table to file before importing to MA;	default false
-- @field [parent=#global] #boolean SAVETABLE
SAVETABLE = false
--- must always be equal to the scripts filename !
-- @field [parent=#global] #string scriptname	
scriptname = "LHpi.tcgplayerPriceGuide-v2.0.lua" 
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

site={}
site.regex = '<TR height=20>(.-)</TR>'

-- define the three price columns
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
	himelo = 1 -- not local, read in ParseHtmlData
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
 @return #table { #string = #table { foilonly = #boolean , offline = #boolean } }
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
 @param #table urldetails	{ foilonly = #boolean , offline = #boolean , setid = #number, langid = #number, frucid = #number }
 @return #table { names = #table { #number = #string, ... }, price = #table { #number = #string, ... }} 
]]
function site.ParseHtmlData( foundstring , urldetails )
--[[ <TR height=20>
<td width=200 align=left valign=center><font  class=default_7>&nbsp;Abuna Acolyte</font></td>
<td width=80 align=left valign=center><font  class=default_7>&nbsp;1W</font></td>
<td width=120 align=left valign=center><font  class=default_7>&nbsp;Creature</font></td>
<td width=50 align=left valign=center><font  class=default_7>&nbsp;White</font></td>
<td width=30 align=left valign=center><font  class=default_7>&nbsp;U</font></td>
<td width=55 align=right valign=center><font  class=default_7>$0.50&nbsp;</font></td>
<td width=55 align=right valign=center><font  class=default_7>$0.16&nbsp;</font>
</td><td width=55 align=right valign=center><font  class=default_7>$0.01&nbsp;</font></td>
</TR>
--]]
	local tablerow = {}
	for column in string.gmatch(foundstring , "<td[^>]->+%b<>([^<]+)%b<></td>") do
		table.insert(tablerow , column)
	end -- for column
	if DEBUG then
		LHpi.Log("(parsed):" .. LHpi.Tostring(tablerow) , 2 )
	end
	local name = string.gsub( tablerow[1], "&nbsp;" , "" )	 
	local price = ( tablerow[ ( himelo+5 ) ] ) or 0
	price = string.gsub( price , "&nbsp;" , "" ) -- 6 to 8
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
[793]={ id = 793 , fruc = { true , true } , lang = { true }, url = "Gatecrash"},
[791]={ id = 791 , fruc = { true , true } , lang = { true }, url = "Return%20to%20Ravnica"},
[790]={ id = 790 , fruc = { true , false} , lang = { true }, url = "Duel%20Decks:%20Garruk%20vs.%20Liliana"},
[789]={ id = 789 , fruc = { false , true} , lang = { true }, url = "From%20the%20Vault%3A%20Realms"},
[788]={ id = 788 , fruc = { true , true } , lang = { true }, url = "Magic%202013%20(M13)"},
[787]={ id = 787 , fruc = { true , false} , lang = { true }, url = "Planechase%202012"},
[786]={ id = 786 , fruc = { true , true } , lang = { true }, url = "Avacyn%20Restored"},
[785]={ id = 785 , fruc = { true , true } , lang = { true }, url = "Venser%20vs.%20Koth"},
[784]={ id = 784 , fruc = { true , true } , lang = { true }, url = "Dark%20Ascension"},
[783]={ id = 783 , fruc = { false , true} , lang = { true }, url = "Graveborn"},
[782]={ id = 782 , fruc = { true , true } , lang = { true }, url = "Innistrad"},
[781]={ id = 781 , fruc = { true , true } , lang = { true }, url = "Ajani%20vs.%20Nicol%20Bolas"},
[780]={ id = 780 , fruc = { false , true} , lang = { true }, url = "From%20the%20Vault%3A%20Legends"},
[779]={ id = 779 , fruc = { true , true } , lang = { true }, url = "Magic%202012%20(M12)"},
[778]={ id = 778 , fruc = { true , false} , lang = { true }, url = "Commander"},
[777]={ id = 777 , fruc = { true , true } , lang = { true }, url = "Knights%20vs.%20Dragons"},
[776]={ id = 776 , fruc = { true , true } , lang = { true }, url = "New%20Phyrexia"},
[775]={ id = 775 , fruc = { true , true } , lang = { true }, url = "Mirrodin%20Besieged"},
[774]={ id = 774 , fruc = { false , true} , lang = { true }, url = "Premium%20Deck%20Series:%20Fire%20and%20Lightning"},
[773]={ id = 773 , fruc = { true , true } , lang = { true }, url = "Scars%20of%20Mirrodin"},
[772]={ id = 772 , fruc = { true , true } , lang = { true }, url = "Duel%20Decks:%20Elspeth%20vs.%20Tezzeret"},
[771]={ id = 771 , fruc = { false , true} , lang = { true }, url = "From%20the%20Vault%3A%20Relics"},
[770]={ id = 770 , fruc = { true , true } , lang = { true }, url = "Magic%202011%20(M11)"},
[769]={ id = 769 , fruc = { true , false} , lang = { true }, url = "Archenemy"},   
[768]={ id = 768 , fruc = { true , true } , lang = { true }, url = "Duels%20of%20the%20Planeswalkers"},
[767]={ id = 767 , fruc = { true , true } , lang = { true }, url = "Rise%20of%20the%20Eldrazi"},
[766]={ id = 766 , fruc = { true , false} , lang = { true }, url = "Duel%20Decks:%20Phyrexia%20vs.%20The%20Coalition"},
[765]={ id = 765 , fruc = { true , true } , lang = { true }, url = "Worldwake"},
[764]={ id = 764 , fruc = { false , true} , lang = { true }, url = "Premium%20Deck%20Series:%20Slivers"},
[763]={ id = 763 , fruc = { true , true } , lang = { true }, url = "Garruk%20VS%20Liliana"},
[762]={ id = 762 , fruc = { true , true } , lang = { true }, url = "Zendikar"},
[761]={ id = 761 , fruc = { true , false} , lang = { true }, url = "Planechase"},   
[759]={ id = 759 , fruc = { true , true } , lang = { true }, url = "Magic%202010"},
[758]={ id = 758 , fruc = { true , true } , lang = { true }, url = "Alara%20Reborn"},
[757]={ id = 757 , fruc = { true , true } , lang = { true }, url = "Duel%20Decks:%20Divine%20vs.%20Demonic"},
[756]={ id = 756 , fruc = { true , true } , lang = { true }, url = "Conflux"},
[755]={ id = 755 , fruc = { true , true } , lang = { true }, url = "Duel%20Decks:%20Jace%20vs.%20Chandra"},
[754]={ id = 754 , fruc = { true , true } , lang = { true }, url = "Shards%20of%20Alara"},
[752]={ id = 752 , fruc = { true , true } , lang = { true }, url = "Eventide"},
[751]={ id = 751 , fruc = { true , true } , lang = { true }, url = "Shadowmoor"},
[750]={ id = 750 , fruc = { true , true } , lang = { true }, url = "Morningtide"},
[740]={ id = 740 , fruc = { true , true } , lang = { true }, url = "Duel%20Decks: Elves vs. Goblins"},   
[730]={ id = 730 , fruc = { true , true } , lang = { true }, url = "Lorwyn"},
[720]={ id = 720 , fruc = { true , true } , lang = { true }, url = "10th%20Edition"},
[710]={ id = 710 , fruc = { true , true } , lang = { true }, url = "Future%20Sight"},
[700]={ id = 700 , fruc = { true , true } , lang = { true }, url = "Planar%20Chaos"},
[690]={ id = 690 , fruc = { true , true } , lang = { true }, url = "Timeshifted"},
[680]={ id = 680 , fruc = { true , true } , lang = { true }, url = "Time%20Spiral"},
[670]={ id = 670 , fruc = { true , true } , lang = { true }, url = "Coldsnap"},
[660]={ id = 660 , fruc = { true , true } , lang = { true }, url = "Dissension"},
[650]={ id = 650 , fruc = { true , true } , lang = { true }, url = "Guildpact"},
[640]={ id = 640 , fruc = { true , true } , lang = { true }, url = "Ravnica"},
[630]={ id = 630 , fruc = { true , true } , lang = { true }, url = "9th%20Edition"},
[620]={ id = 620 , fruc = { true , true } , lang = { true }, url = "Saviors%20of%20Kamigawa"},
[610]={ id = 610 , fruc = { true , true } , lang = { true }, url = "Betrayers%20of%20Kamigawa"},
[600]={ id = 600 , fruc = { true , false} , lang = { true }, url = "Unhinged"},
[590]={ id = 590 , fruc = { true , true } , lang = { true }, url = "Champions%20of%20Kamigawa"},
[580]={ id = 580 , fruc = { true , true } , lang = { true }, url = "Fifth%20Dawn"},
[570]={ id = 570 , fruc = { true , true } , lang = { true }, url = "Darksteel"},
[560]={ id = 560 , fruc = { true , true } , lang = { true }, url = "Mirrodin"},
[550]={ id = 550 , fruc = { true , true } , lang = { true }, url = "8th%20Edition"},
[540]={ id = 540 , fruc = { true , true } , lang = { true }, url = "Scourge"},
[530]={ id = 530 , fruc = { true , true } , lang = { true }, url = "Legions"},
[520]={ id = 520 , fruc = { true , true } , lang = { true }, url = "Onslaught"},
[510]={ id = 510 , fruc = { true , true } , lang = { true }, url = "Judgment"},
[500]={ id = 500 , fruc = { true , true } , lang = { true }, url = "Torment"},
[490]={ id = 490 , fruc = { true , false} , lang = { true }, url = "Deckmaster"},
[480]={ id = 480 , fruc = { true , true } , lang = { true }, url = "Odyssey"},
[470]={ id = 470 , fruc = { true , true } , lang = { true }, url = "Apocalypse"},
[460]={ id = 460 , fruc = { true , true } , lang = { true }, url = "7th%20Edition"},
[450]={ id = 450 , fruc = { true , true } , lang = { true }, url = "Planeshift"},
[440]={ id = 440 , fruc = { true , true } , lang = { true }, url = "Beatdown%20Box%20Set"},
[430]={ id = 430 , fruc = { true , true } , lang = { true }, url = "Invasion"},
[420]={ id = 420 , fruc = { true , true } , lang = { true }, url = "Prophecy"},
[415]={ id = 415 , fruc = { true , false} , lang = { true }, url = "Starter%202000"},   
[410]={ id = 410 , fruc = { true , true } , lang = { true }, url = "Nemesis"},
[405]={ id = 405 , fruc = { true , true } , lang = { true }, url = "Battle%20Royale%20Box%20Set"},
[400]={ id = 400 , fruc = { true , true } , lang = { true }, url = "Mercadian%20Masques"},
[390]={ id = 390 , fruc = { true , false} , lang = { true }, url = "Starter%201999"},
[380]={ id = 380 , fruc = { true , false} , lang = { true }, url = "Portal%20Three%20Kingdoms"},   
[370]={ id = 370 , fruc = { true , true } , lang = { true }, url = "Urza's%20Destiny"},
[360]={ id = 360 , fruc = { true , true } , lang = { true }, url = "Classic%20Sixth%20Edition"},
[350]={ id = 350 , fruc = { true , true } , lang = { true }, url = "Urza's%20Legacy"},
[330]={ id = 330 , fruc = { true , true } , lang = { true }, url = "Urza's%20Saga"},
[320]={ id = 320 , fruc = { true , false} , lang = { true }, url = "Unglued"},
[310]={ id = 310 , fruc = { true , false} , lang = { true }, url = "Portal%20Second%20Age"},   
[300]={ id = 300 , fruc = { true , false} , lang = { true }, url = "Exodus"},
[290]={ id = 290 , fruc = { true , false} , lang = { true }, url = "Stronghold"},
[280]={ id = 280 , fruc = { true , false} , lang = { true }, url = "Tempest"},
[270]={ id = 270 , fruc = { true , false} , lang = { true }, url = "Weatherlight"},
[260]={ id = 260 , fruc = { true , false} , lang = { true }, url = "Portal"},
[250]={ id = 250 , fruc = { true , false} , lang = { true }, url = "Fifth%20Edition"},
[240]={ id = 240 , fruc = { true , false} , lang = { true }, url = "Visions"},
[230]={ id = 230 , fruc = { true , false} , lang = { true }, url = "Mirage"},
[220]={ id = 220 , fruc = { true , false} , lang = { true }, url = "Alliances"},
[210]={ id = 210 , fruc = { true , false} , lang = { true }, url = "Homelands"},
[200]={ id = 200 , fruc = { true , false} , lang = { true }, url = "Chronicles"},
[190]={ id = 190 , fruc = { true , false} , lang = { true }, url = "Ice%20Age"},
[180]={ id = 180 , fruc = { true , false} , lang = { true }, url = "Fourth%20Edition"},
[170]={ id = 170 , fruc = { true , false} , lang = { true }, url = "Fallen%20Empires"},
[160]={ id = 160 , fruc = { true , false} , lang = { true }, url = "The%20Dark"},
[150]={ id = 150 , fruc = { true , false} , lang = { true }, url = "Legends"},
[140]={ id = 140 , fruc = { true , false} , lang = { true }, url = "Revised%20Edition"},
[130]={ id = 130 , fruc = { true , false} , lang = { true }, url = "Antiquities"},
[120]={ id = 120 , fruc = { true , false} , lang = { true }, url = "Arabian%20Nights"},
[110]={ id = 110 , fruc = { true , false} , lang = { true }, url = "Unlimited%20Edition"},
[100]={ id = 100 , fruc = { true , false} , lang = { true }, url = "Beta%20Edition"},
[90] ={ id =  90 , fruc = { true , false} , lang = { true }, url = "Alpha%20Edition"},
[70] ={ id =  70 , fruc = { true , false} , lang = { true }, url = "Vanguard"},
[40] ={ id =  40 , fruc = { false , true} , lang = { true }, url = "Arena%20Promos"},
[30] ={ id =  30 , fruc = { false , true} , lang = { true }, url = "FNM%20Promos"},
[26] ={ id =  26 , fruc = { false , true} , lang = { true }, url = "Game%20Day%20Promos"},
[25] ={ id =  25 , fruc = { false , true} , lang = { true }, url = "Judge%20Promos"},
[24] ={ id =  24 , fruc = { false , true} , lang = { true }, url = "Champs%20Promos"},
[23] ={ id =  23 , fruc = { false , true} , lang = { true }, url = "Gateway%20Promos"},
[22] ={ id =  22 , fruc = { false , true} , lang = { true }, url = "Prerelease%20Cards"},
[21] ={ id =  21 , fruc = { false , true} , lang = { true }, url = "Launch%20Party%20Cards"},
[20] ={ id =  20 , fruc = { false , true} , lang = { true }, url = "Magic%20Player%20Rewards"},
} -- end table site.sets
