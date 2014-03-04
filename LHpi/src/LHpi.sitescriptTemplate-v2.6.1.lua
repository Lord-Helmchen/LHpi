--*- coding: utf-8 -*-
--[[- LHpi sitescript template 
Template to write new sitescripts for LHpi library

Inspired by and loosely based on "MTG Mint Card.lua" by Goblin Hero, Stromglad1 and "Import Prices.lua" by woogerboy21;
who generously granted permission to "do as I like" with their code;
everything else Copyright (C) 2012-2014 by Christian Harms.
If you want to contact me about the script, try its release thread in http://www.slightlymagic.net/forum/viewforum.php?f=32

@module LHpi_magicuniverseDE
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
pre-populated site.sets with all sets
added LOGFOILTWEAK option
]]

-- options that control the amount of feedback/logging done by the script
--- @field [parent=#global] #boolean VERBOSE 			default false
VERBOSE = true
--- @field [parent=#global] #boolean LOGDROPS 			default false
LOGDROPS = true
--- @field [parent=#global] #boolean LOGNAMEREPLACE 	default false
LOGNAMEREPLACE = true
--- @field [parent=#global] #boolean LOGFOILTWEAK	 	default false
LOGFOILTWEAK = true

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
SAVEHTML = true
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
scriptname = "LHpi.sitescriptTemplate-v".. libver .. ".1.lua"
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
--function site.BuildUrl( setid,langid,frucid,offline )
--	site.domain = "www.example.com"
--	site.file = "magic.php"
--	site.setprefix = "&edition="
--	site.langprefix = "&language="
--	site.frucprefix = "&rarity="
--	site.suffix = ""
--	
--	local container = {}
--	local url = site.domain .. site.file .. site.setprefix .. site.sets[setid].url .. site.langprefix .. site.langs[langid].url .. site.frucprefix .. site.frucs[frucid]
--	if offline then
--		string.gsub( url, "%?", "_" )
--		string.gsub( url, "/", "_" )
--		container[url] = { isfile = true}
--	else
--		container[url] = {}
--	end -- if offline 
--	
--	if string.find( url , "[Ff][Oo][Ii][Ll]" ) then -- mark url as foil-only
--		container[url].foilonly = true
--	else
--		-- url without foil marker
--	end -- if foil-only url
--	return container
--end -- function site.BuildUrl

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

--[[- special cases card data manipulation
 Ties into LHpi.buildCardData to make changes that are specific to one site and thus don't belong into the library.
 This Plugin is called before most of LHpi's BuildCardData proecssing.

 @function [parent=#site] BCDpluginPre
 @param #table card		the card LHpi.BuildCardData is working on
 @param #number setid
 @returns #table card modified card is passed back for further processing
]]
--function site.BCDpluginPre ( card , setid )
--	if DEBUG then
--		LHpi.Log( "site.BCDpluginPre got " .. LHpi.Tostring( card ) .. " from set " .. setid , 2 )
--	end
--
--	-- if you don't want a full namereplace table, gsubs like this might take care of a lot of fails.
--	card.name = string.gsub( card.name , "AE" , "Æ")
--	card.name = string.gsub( card.name , "Ae" , "Æ")

--	return card
--end -- function site.BCDpluginPre

--[[- special cases card data manipulation
 Ties into LHpi.buildCardData to make changes that are specific to one site and thus don't belong into the library
 This Plugin is called after LHpi's BuildCardData proecssing (and probably not needed).
 
 @function [parent=#site] BCDpluginPost
 @param #table card		the card LHpi.BuildCardData is working on
 @param #number setid
 @returns #table card modified card is passed back for further processing
]]
--function site.BCDpluginPost( card , setid )
--	if DEBUG then
--		LHpi.Log( "site.BCDpluginPost got " .. LHpi.Tostring( card ) .. " from set " .. setid , 2 )
--	end
--
--	return card
--end -- function site.BCDpluginPost

-------------------------------------------------------------------------------------------------------------
-- tables
-------------------------------------------------------------------------------------------------------------

--[[- table of (supported) languages.
-- { #number = {id = #number, full = #string, abbr = #string } }
-- 
--- @field [parent=#site] #table langs ]]
--- @field [parent=#site] #table langs
site.langs = {
	[1] = {id=1, full = "English", 	abbr="ENG", url="" },
}

--- @field [parent=#site] #table frucs	rarity array { #number = #string }
site.frucs = { "Foil" , "Rare" , "Uncommon" , "Common" , "Purple" }

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
-- Core Sets
[797]={id = 797, lang = { [1]=true }, fruc = { true , true }, url = "M14"},
[788]={id = 788, lang = { [1]=true }, fruc = { true , true }, url = "M13"},
[779]={id = 779, lang = { [1]=true }, fruc = { true , true }, url = "M12"},
[770]={id = 770, lang = { [1]=true }, fruc = { true , true }, url = "M11"},
[759]={id = 759, lang = { [1]=true }, fruc = { true , true }, url = "M10"},
[720]={id = 720, lang = { [1]=true }, fruc = { true , true }, url = "10E"},
[630]={id = 630, lang = { [1]=true }, fruc = { true , true }, url = "9ED"},
[550]={id = 550, lang = { [1]=true }, fruc = { true , true }, url = "8ED"},
[460]={id = 460, lang = { [1]=true }, fruc = { true , true }, url = "7ED"},
[360]={id = 360, lang = { [1]=true }, fruc = { true , true }, url = "6ED"},
[250]={id = 250, lang = { [1]=true }, fruc = { true , false}, url = "5ED"},
[180]={id = 180, lang = { [1]=true }, fruc = { true , false}, url = "4ED"},
[141]={id = 141, lang = { [1]=true }, fruc = { true , false}, url = "RSM"},--Revised Summer Magic
[140]={id = 140, lang = { [1]=true }, fruc = { true , false}, url = "3ED"},--Revised
[139]={id = 139, lang = { [1]=true }, fruc = { true , false}, url = "RLD"},--Revised Limited Deutsch
[110]={id = 110, lang = { [1]=true }, fruc = { true , false}, url = "2ED"},--Unlimited
[100]={id = 100, lang = { [1]=true }, fruc = { true , false}, url = "LEB"},--Beta
[90] ={id =  90, lang = { [1]=true }, fruc = { true , false}, url = "LEA"},--Alpha
-- Expansions
[802]={id = 802, lang = { [1]=true }, fruc = { true , true }, url = "BNG"},--Born of the Gods
[800]={id = 800, lang = { [1]=true }, fruc = { true , true }, url = "THS"},--Theros
[795]={id = 795, lang = { [1]=true }, fruc = { true , true }, url = "DGM"},--Dragon's Maze
[793]={id = 793, lang = { [1]=true }, fruc = { true , true }, url = "GTC"},--Gatecrash
[791]={id = 791, lang = { [1]=true }, fruc = { true , true }, url = "RTR"},--Return to Ravnica
[786]={id = 786, lang = { [1]=true }, fruc = { true , true }, url = "AVR"},--Avacyn Restored
[784]={id = 784, lang = { [1]=true }, fruc = { true , true }, url = "DKA"},--Dark Ascension
[782]={id = 782, lang = { [1]=true }, fruc = { true , true }, url = "ISD"},--Inistrad
[776]={id = 776, lang = { [1]=true }, fruc = { true , true }, url = "NPH"},--New Phyrexia
[775]={id = 775, lang = { [1]=true }, fruc = { true , true }, url = "MBS"},--Mirrodin Besieged
[773]={id = 773, lang = { [1]=true }, fruc = { true , true }, url = "SOM"},--Scars of Mirrodin
[767]={id = 767, lang = { [1]=true }, fruc = { true , true }, url = "ROE"},--Rise of the Eldrazi
[765]={id = 765, lang = { [1]=true }, fruc = { true , true }, url = "WWK"},--Worldwake
[762]={id = 762, lang = { [1]=true }, fruc = { true , true }, url = "ZEN"},--Zendikar
[758]={id = 758, lang = { [1]=true }, fruc = { true , true }, url = "ARB"},--Alara Reborn
[756]={id = 756, lang = { [1]=true }, fruc = { true , true }, url = "CON"},--Conflux
[754]={id = 754, lang = { [1]=true }, fruc = { true , true }, url = "ALA"},--Shards of Alara
[752]={id = 752, lang = { [1]=true }, fruc = { true , true }, url = "EVE"},--Eventide
[751]={id = 751, lang = { [1]=true }, fruc = { true , true }, url = "SHM"},--Shadowmoor
[750]={id = 750, lang = { [1]=true }, fruc = { true , true }, url = "MOR"},--Morningtide
[730]={id = 730, lang = { [1]=true }, fruc = { true , true }, url = "LRW"},--Lorwyn
[710]={id = 710, lang = { [1]=true }, fruc = { true , true }, url = "FUT"},--Future Sight
[700]={id = 700, lang = { [1]=true }, fruc = { true , true }, url = "PLC"},--Planar Chaos
[690]={id = 690, lang = { [1]=true }, fruc = { true , true }, url = "TSB"},--Time Spiral Timeshifted
[680]={id = 680, lang = { [1]=true }, fruc = { true , true }, url = "TSP"},--Time Spiral
[670]={id = 670, lang = { [1]=true }, fruc = { true , true }, url = "CSP"},--Coldsnap
[660]={id = 660, lang = { [1]=true }, fruc = { true , true }, url = "DIS"},--Dissension
[650]={id = 650, lang = { [1]=true }, fruc = { true , true }, url = "GPT"},--Guildpact
[640]={id = 640, lang = { [1]=true }, fruc = { true , true }, url = "RAV"},--Ravnica:
[620]={id = 620, lang = { [1]=true }, fruc = { true , true }, url = "SOK"},--Saviors of Kamigawa
[610]={id = 610, lang = { [1]=true }, fruc = { true , true }, url = "BOK"},--Betrayers of Kamigawa
[590]={id = 590, lang = { [1]=true }, fruc = { true , true }, url = "CHK"},--Champions of Kamigawa
[580]={id = 580, lang = { [1]=true }, fruc = { true , true }, url = "5DN"},--Fifth Dawn
[570]={id = 570, lang = { [1]=true }, fruc = { true , true }, url = "DST"},--Darksteel
[560]={id = 560, lang = { [1]=true }, fruc = { true , true }, url = "MRD"},--Mirrodin
[540]={id = 540, lang = { [1]=true }, fruc = { true , true }, url = "SCG"},--Scourge
[530]={id = 530, lang = { [1]=true }, fruc = { true , true }, url = "LGN"},--Legions
[520]={id = 520, lang = { [1]=true }, fruc = { true , true }, url = "ONS"},--Onslaught
[510]={id = 510, lang = { [1]=true }, fruc = { true , true }, url = "JUD"},--Judgment
[500]={id = 500, lang = { [1]=true }, fruc = { true , true }, url = "TOR"},--Torment
[480]={id = 480, lang = { [1]=true }, fruc = { true , true }, url = "ODY"},--Odyssey
[470]={id = 470, lang = { [1]=true }, fruc = { true , true }, url = "APC"},--Apocalypse
[450]={id = 450, lang = { [1]=true }, fruc = { true , true }, url = "PLS"},--Planeshift
[430]={id = 430, lang = { [1]=true }, fruc = { true , true }, url = "INV"},--Invasion
[420]={id = 420, lang = { [1]=true }, fruc = { true , true }, url = "PCY"},--Prophecy
[410]={id = 410, lang = { [1]=true }, fruc = { true , true }, url = "NEM"},--Nemesis
[400]={id = 400, lang = { [1]=true }, fruc = { true , true }, url = "MMQ"},--Mercadian Masques
[370]={id = 370, lang = { [1]=true }, fruc = { true , true }, url = "UDS"},--Urza's Destiny 
[350]={id = 350, lang = { [1]=true }, fruc = { true , false}, url = "ULG"},--Urza's Legacy
[330]={id = 330, lang = { [1]=true }, fruc = { true , false}, url = "USG"},--Urza's Saga
[300]={id = 300, lang = { [1]=true }, fruc = { true , false}, url = "EXO"},--Exodus
[290]={id = 290, lang = { [1]=true }, fruc = { true , false}, url = "STH"},--Stronghold
[280]={id = 280, lang = { [1]=true }, fruc = { true , false}, url = "TMP"},--Tempest
[270]={id = 270, lang = { [1]=true }, fruc = { true , false}, url = "WTH"},--Weatherlight
[240]={id = 240, lang = { [1]=true }, fruc = { true , false}, url = "VIS"},--Visions
[230]={id = 230, lang = { [1]=true }, fruc = { true , false}, url = "MIR"},--Mirage
[220]={id = 220, lang = { [1]=true }, fruc = { true , false}, url = "ALL"},--Alliances
[210]={id = 210, lang = { [1]=true }, fruc = { true , false}, url = "HML"},--Homelands
[190]={id = 190, lang = { [1]=true }, fruc = { true , false}, url = "ICE"},--Ice Age
[170]={id = 170, lang = { [1]=true }, fruc = { true , false}, url = "FEM"},--Fallen Empire
[160]={id = 160, lang = { [1]=true }, fruc = { true , false}, url = "DRK"},--The Dark
[150]={id = 150, lang = { [1]=true }, fruc = { true , false}, url = "LEG"},--Legends
[130]={id = 130, lang = { [1]=true }, fruc = { true , false}, url = "ATQ"},--Antiquities
[120]={id = 120, lang = { [1]=true }, fruc = { true , false}, url = "ARN"},--Arabian Nights
-- special sets
--TODO check if fruc defaults match the sets foilage
--[801]={id = 801, lang = { [1]=true }, fruc = { true , true }, url = "C13"},--Commander 2013
--[799]={id = 799, lang = { [1]=true }, fruc = { true , true }, url = "DDL"},--Duel Decks: Heroes vs. Monsters
--[798]={id = 798, lang = { [1]=true }, fruc = { false, true }, url = "V13"},--From the Vault: Twenty
[796]={id = 796, lang = { [1]=true }, fruc = { true , true }, url = "MMA"},--Modern Masters
--[794]={id = 794, lang = { [1]=true }, fruc = { true , true }, url = "DDK"},--Duel Decks: Sorin vs. Tibalt
--[792]={id = 792, lang = { [1]=true }, fruc = { false, true }, url = "CM1"},--Commander’s Arsenal
--[790]={id = 790, lang = { [1]=true }, fruc = { true , false}, url = "DDJ"},--Duel Decks: Izzet vs. Golgari
--[789]={id = 789, lang = { [1]=true }, fruc = { false, true }, url = "V12"},--From the Vault: Realms
--[787]={id = 787, lang = { [1]=true }, fruc = { true , false}, url = "PC2"},--Planechase 2012
--[785]={id = 785, lang = { [1]=true }, fruc = { true , true }, url = "DDI"},--Duel Decks: Venser vs. Koth
--[783]={id = 783, lang = { [1]=true }, fruc = { false, true }, url = "PD3"},--Premium Deck Series: Graveborn
--[781]={id = 781, lang = { [1]=true }, fruc = { true , true }, url = "DDH"},--Duel Decks: Ajani vs. Nicol Bolas
--[780]={id = 780, lang = { [1]=true }, fruc = { false, true }, url = "V11"},--From the Vault: Legends
--[778]={id = 778, lang = { [1]=true }, fruc = { true , false}, url = "CMD"},--Commander
--[777]={id = 777, lang = { [1]=true }, fruc = { true , true }, url = "DDG"},--Duel Decks: Knights vs. Dragons
--[774]={id = 774, lang = { [1]=true }, fruc = { false, true }, url = "PD2"},--Premium Deck Series: Fire and Lightning
--[772]={id = 772, lang = { [1]=true }, fruc = { true , true }, url = "DDF"},--Duel Decks: Elspeth vs. Tezzeret
--[771]={id = 771, lang = { [1]=true }, fruc = { false, true }, url = "V10"},--From the Vault: Relics
--[769]={id = 769, lang = { [1]=true }, fruc = { true , false}, url = "ARC"},--Archenemy   
--[768]={id = 768, lang = { [1]=true }, fruc = { true , true }, url = "DPA"},--Duels of the Planeswalkers
--[766]={id = 766, lang = { [1]=true }, fruc = { true , false}, url = "DDE"},--Duel Decks: Phyrexia vs. The Coalition
--[764]={id = 764, lang = { [1]=true }, fruc = { false, true }, url = "H09"},--Premium Deck Series: Slivers
--[763]={id = 763, lang = { [1]=true }, fruc = { true , true }, url = "DDD"},--Duel Decks: Garruk vs. Liliana
--[761]={id = 761, lang = { [1]=true }, fruc = { true , false}, url = "HOP"},--Planechase
--[760]={id = 760, lang = { [1]=true }, fruc = { false, true }, url = "V09"},--From the Vault: Exiled
--[757]={id = 757, lang = { [1]=true }, fruc = { true , true }, url = "DDC"},--Duel Decks: Divine vs. Demonic
--[755]={id = 755, lang = { [1]=true }, fruc = { true , true }, url = "DD2"},--Duel Decks: Jace vs. Chandra
--[753]={id = 753, lang = { [1]=true }, fruc = { false, true }, url = "DRB"},--From the Vault: Dragons
--[740]={id = 740, lang = { [1]=true }, fruc = { true , true }, url = "EVG"},--Duel Decks: Elves vs. Goblins   
--[675]={id = 675, lang = { [1]=true }, fruc = { true , true }, url = ""},--Coldsnap Theme Decks
--[635]={id = 635, lang = { [1]=true }, fruc = {  }, url = ""},--Magic Encyclopedia
[600]={id = 600, lang = { [1]=true }, fruc = { true , false}, url = "UNH"},--Unhinged
--[490]={id = 490, lang = { [1]=true }, fruc = { true , false}, url = "DKM"},--Deckmaster
--[440]={id = 440, lang = { [1]=true }, fruc = { true , true }, url = "BTD"},--Beatdown Box Set
--[415]={id = 415, lang = { [1]=true }, fruc = { true , false}, url = "S00"},--Starter 2000   
--[405]={id = 405, lang = { [1]=true }, fruc = { true , true }, url = ""},--Battle Royale Box Set
--[390]={id = 390, lang = { [1]=true }, fruc = { true , false}, url = "S99"},--Starter 1999
[380]={id = 380, lang = { [1]=true }, fruc = { true , false}, url = "PTK"},--Portal Three Kingdoms   
--[340]={id = 340, lang = { [1]=true }, fruc = {  }, url = "ATH"},--Anthologies
[320]={id = 320, lang = { [1]=true }, fruc = { true , false}, url = "UGL"},--Unglued
[310]={id = 310, lang = { [1]=true }, fruc = { true , false}, url = "P02"},--Portal Second Age   
[260]={id = 260, lang = { [1]=true }, fruc = { true , false}, url = "POR"},--Portal
--[225]={id = 225, lang = { [1]=true }, fruc = {  }, url = ""},--Introductory Two-Player Set
--[201]={id = 201, lang = { [1]=true }, fruc = {  }, url = ""},--Renaissance
[200]={id = 200, lang = { [1]=true }, fruc = { true , false}, url = "CHR"},--Chronicles
--[70] ={id =  70, lang = { [1]=true }, fruc = { true , false}, url = "VAN"},--Vanguard
--[69] ={id =  69, lang = { [1]=true }, fruc = {  }, url = ""},--Box Topper Cards
-- Promo Cards
--[50] ={id =  50, lang = { [1]=true }, fruc = {  }, url = ""},--Full Box Promotion
--[45] ={id =  45, lang = { [1]=true }, fruc = {  }, url = ""},--Magic Premiere Shop
--[43] ={id =  43, lang = { [1]=true }, fruc = {  }, url = ""},--Two-Headed Giant Promos
--[42] ={id =  42, lang = { [1]=true }, fruc = {  }, url = ""},--Summer of Magic Promos
--[41] ={id =  41, lang = { [1]=true }, fruc = {  }, url = ""},--Happy Holidays Promos
--[40] ={id =  40, lang = { [1]=true }, fruc = { false, true }, url = ""},--Arena Promos
--[33] ={id =  33, lang = { [1]=true }, fruc = {  }, url = ""},--Championships Prizes
--[32] ={id =  32, lang = { [1]=true }, fruc = {  }, url = ""},--Pro Tour Promos
--[31] ={id =  31, lang = { [1]=true }, fruc = {  }, url = ""},--Grand Prix Promos
--[30] ={id =  30, lang = { [1]=true }, fruc = { false, true }, url = ""},--FNM Promos
--[27] ={id =  27, lang = { [1]=true }, fruc = {  }, url = ""},--Alternate Art Lands
--[26] ={id =  26, lang = { [1]=true }, fruc = { false, true }, url = ""},--Game Day Promos
--[25] ={id =  25, lang = { [1]=true }, fruc = { false, true }, url = ""},--Judge Promos
--[24] ={id =  24, lang = { [1]=true }, fruc = { false, true }, url = ""},--Champs Promos
--[23] ={id =  23, lang = { [1]=true }, fruc = { false, true }, url = ""},--Gateway & WPN Promos
--[22] ={id =  22, lang = { [1]=true }, fruc = { false, true }, url = ""},--Prerelease Cards
--[21] ={id =  21, lang = { [1]=true }, fruc = { false, true }, url = ""},--Release & Launch Party Cards
--[20] ={id =  20, lang = { [1]=true }, fruc = { false, true }, url = ""},--Magic Player Rewards
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
--[2]  ={id =   2, lang = { [1]=true }, fruc = {  }, url = ""},--DCI Legend Membership
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

if CHECKEXPECTED then
--[[- table of expected results.
-- as of script release
-- { #number = #table { #table pset = #table { #number = #number, ... }, #table failed = #table { #number = #number, ... }, dropped = #number , namereplaced = #number , foiltweaked = #number }
-- 
--- @field [parent=#site] #table expected ]]
--- @field [parent=#site] #table expected
site.expected = {
-- -- Core sets
--[788] = { pset={ 249+11, nil, 249 }, failed={ 0, nil, 11 }, dropped=0, namereplaced=1, foiltweaked=0 }, -- M2013
}
end
