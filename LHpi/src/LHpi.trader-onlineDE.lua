--*- coding: utf-8 -*-
--[[- LHpi trader-online.de sitescript 
Price import script for Magic Album
uses and needs LHpi library
to import card pricing from www.trader-online.de.

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
2.12.4.12
added 801,807,M15
updated expected 100,680,690,800
synchronized with template
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

-- options that control the script's behaviour.

--- compare prices set and failed with expected numbers; default true
-- @field [parent=#global] #boolean CHECKEXPECTED
--CHECKEXPECTED = false

--  Don't change anything below this line unless you know what you're doing :-) --

--- also complain if drop,namereplace or foiltweak count differs; default false
-- @field [parent=#global] #boolean STRICTEXPECTED
STRICTEXPECTED = true

--- log to seperate logfile instead of Magic Album.log;	default true
-- @field [parent=#global] #boolean SAVELOG
--SAVELOG = false

---	read source data from #string savepath instead of site url; default false
-- @field [parent=#global] #boolean OFFLINE
--OFFLINE = true

--- save a local copy of each source html to #string savepath if not in OFFLINE mode; default false
-- @field [parent=#global] #boolean SAVEHTML
SAVEHTML = true

--- save price table to file before importing to MA;	default false
-- @field [parent=#global] #boolean SAVETABLE
--SAVETABLE = true

---	log everything and exit on error; default false
-- @field [parent=#global] #boolean DEBUG
--DEBUG = true

---	even while DEBUG, do not log raw html data found by regex; default true 
-- @field [parent=#global] #boolean DEBUGFOUND
--DEBUGFOUND = false

--- DEBUG (only but deeper) inside variant loops; default false
-- @field [parent=#global] #boolean DEBUGVARIANTS
--DEBUGVARIANTS = true

--- revision of the LHpi library to use
-- @field [parent=#global] #string libver
libver = "2.12"
--- revision of the LHpi library datafile to use
-- @field [parent=#global] #string dataver
dataver = "4"
--- sitescript revision number
-- @field [parent=#global] string scriptver
scriptver = "12"
--- should be similar to the script's filename. Used for loging and savepath.
-- @field [parent=#global] #string scriptname
scriptname = "LHpi.trader-onlineDE-v" .. libver .. "." .. dataver .. "." .. scriptver .. ".lua"

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
site.regex = '<tr><td colspan="11"><hr noshade size=1></td></tr>\n%s*<tr>\n%s*(.-)</font></td>\n%s*<td width'

--- resultregex can be used to display in the Log how many card the source file claims to contain
-- @field #string resultregex
site.resultregex = "Es wurden <b>(%d+)</b> Artikel"
--- @field #string currency		not used yet;default "$"
site.currency = "€"
--- @field #string encoding		default "cp1252"
site.encoding="cp1252"

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
 @return #table { #string (url)= #table { isfile= #boolean, (optional) foilonly= #boolean, (optional) setid= #number, (optional) langid= #number, (optional) frucid= #number } , ... }
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
	local url = site.domain ..  site.frucfileprefix .. site.file .. site.setprefix .. site.frucs[frucid].url .. "-" .. seturl .. site.langs[langid].url
	if offline then
		url = string.gsub( url, "%?", "_" )
		url = string.gsub( url, "/", "_" )
		container[url] = { isfile = true}
	else
		container[url] = {}
	end -- if offline 
	if site.frucs[frucid].isfoil then -- mark url as foil-only
		container[url].foilonly = true
	else
		-- url without foil marker
	end -- if foil-only url

	if setid == 772 or setid == 757 then --special case for Duel Decks
		container = {}
		local url1=url
		local url2=url
		url1 = string.gsub( url1 , "ELSTEZ" , "ELS" )
		url1 = string.gsub( url1 , "DvD" , "DvD-W" )
		url2 = string.gsub( url2 , "ELSTEZ" , "TEZ" )
		url2 = string.gsub( url2 , "DvD" , "DvD-B" )
		if offline then
			container[url1] = { isfile = true}
			container[url2] = { isfile = true}
		else
			container[url1] = {}			
			container[url2] = {}			
		end
		if site.frucs[frucid].isfoil then
			container[url1].foilonly = true
			container[url2].foilonly = true
		end
	end--if setid
	
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
	local newCard = { names = {} , price = {} }
	local _s,_e,name  = string.find( foundstring, '\n%s*<td width="415"><p><div id="st12">([^<]+)</div></p>' )
	local _s,_e,price = string.find( foundstring, '\n%s*<td width="60".+color="#%d-"><b>([%d.,]+)%s*</b>' )
	local _s,_e,fruc  = string.find( foundstring, '\n%s*<td width="25">%b<>([^<]+) +%b<></td>' )
	local _s,_e,set   = string.find( foundstring, '\n%s*<td width="50">%b<>([^<]+) +%b<></td>' )
	local _s,_e,color = string.find( foundstring, '</p>%s*<td width="25">%b<>(.-) %b<></td>' )
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
	newCard.foil = site.frucs[urldetails.frucid].isfoil
	newCard.pluginData = { fruc=fruc, set=set, color=color }
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
function site.BCDpluginPre ( card , setid , importfoil, importlangs )
	if DEBUG then
		LHpi.Log( "site.BCDpluginPre got " .. LHpi.Tostring( card ) .. " from set " .. setid , 2 )
	end
	
	--card.name = string.gsub( card.name , "\226\128\156" , '"')
	--card.name = string.gsub( card.name , "Ae" , "Æ" )
	
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

	card.name = string.gsub( card.name , "Spielstein" , "Token" )
	if string.find( card.name, "Token" ) and card.pluginData.color then
		card.name = string.gsub( card.name, "%(Token%)", "" ) .. " (" .. card.pluginData.color .. ")"
	end
	if setid == 640 then
		card.name = string.gsub( card.name , "^GebirgeNr" , "Gebirge Nr" )
	elseif setid == 150 or setid == 160 then
		-- remove "ital." suffix from italian Legends and The Dark
		card.name = string.gsub( card.name, ", ital%.$" , "" )
	elseif setid == 801 or setid == 807 then --Commander 2013
print(LHpi.Tostring(card.name))
		card.name=string.gsub(card.name, "%s*englisch$", "")
		local _s,_e,nameeng,nameger = string.find(card.name, "(.+)%s*(%b())$")
		if nameeng and nameger then
			card.names[1]=string.gsub(nameeng,"(.-)%s*$", "%1")
			card.names[3]=string.gsub(nameger, "^%((.+)%)", "%1" )
			card.name=card.names[1]
		end--if nameeng,nameger
	end--if setid
print(LHpi.Tostring(card.name) .. " : " .. LHpi.Tostring(card.names))
	
	-- mark condition modifier suffixed cards to be dropped
	card.name = string.gsub( card.name , ", light played$" , "%0 (DROP)" )
	card.name = string.gsub( card.name , ", gespielt$" , "%0 (DROP)" )
	card.name = string.gsub( card.name , " NM%-EX$" , "%0 (DROP)" )
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
	if setid == 805 then
		card.name = string.gsub(card.name," %(%D-%)$","")
	end
	card.pluginData=nil
	return card
end -- function site.BCDpluginPost

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
	[1] = { id=1, url="-E" },
	[3] = { id=3, url="-D" },
	[5] = { id=5, url="-E" },
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
	[1]= { id=1, name="Foil"	, isfoil=true , isnonfoil=false, url="Foil"	 },
	[2]= { id=2, name="nonFoil"	, isfoil=false, isnonfoil=true , url="Serie" },
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
--[808]={id = 808, lang = { true , [3]=true }, fruc = { true ,true }, url = "M15"}, 
[797]={id = 797, lang = { true , [3]=true }, fruc = { true ,true }, url = "M14"}, 
[788]={id = 788, lang = { true , [3]=true }, fruc = { true ,true }, url = "M13"}, 
[779]={id = 779, lang = { true , [3]=true }, fruc = { true ,true }, url = "M12"}, 
[770]={id = 770, lang = { true , [3]=true }, fruc = { true ,true }, url = "M11"}, 
[759]={id = 759, lang = { true , [3]=true }, fruc = { true ,true }, url = "M10"}, 
[720]={id = 720, lang = { true , [3]=true }, fruc = { true ,true }, url = "10th"}, 
[630]={id = 630, lang = { true , [3]=true }, fruc = { true ,true }, url = "9th"}, 
[550]={id = 550, lang = { true , [3]=true }, fruc = { true ,true }, url = "8th"}, 
[460]={id = 460, lang = { true , [3]=true }, fruc = { true ,true }, url = "7th"}, 
[360]={id = 360, lang = { true , [3]=true }, fruc = { false,true }, url = "6th"},
[250]={id = 250, lang = { true , [3]=true }, fruc = { false,true }, url = "5th"},
[180]={id = 180, lang = { true , [3]=true }, fruc = { false,true }, url = "4th"}, 
[141]=nil,--Summer Magic
[140]={id = 140, lang = { true , [3]=true }, fruc = { false,true }, url = "RV"},
[139]={id = 139, lang = { false, [3]=true }, fruc = { false,true }, url = "DL"}, -- deutsch limitiert
[110]={id = 110, lang = { true , [3]=false}, fruc = { false,true }, url = "UN"},  
[100]={id = 100, lang = { true , [3]=false}, fruc = { false,true }, url = "B%20"},
[90] = nil, -- Alpha 
 -- Expansions
[806]={id = 806, lang = { true , [3]=true }, fruc = { true, true }, url = "JOU"},
[802]={id = 802, lang = { true , [3]=true }, fruc = { true, true }, url = "BNG"},
[800]={id = 800, lang = { true , [3]=true }, fruc = { true, true }, url = "THS"},
[795]={id = 795, lang = { true , [3]=true }, fruc = { true, true }, url = "DGM"},
[793]={id = 793, lang = { true , [3]=true }, fruc = { true, true }, url = "GTC"},
[791]={id = 791, lang = { true , [3]=true }, fruc = { true ,true }, url = "RTR"},
[786]={id = 786, lang = { true , [3]=true }, fruc = { true ,true }, url = "AVR"},
[784]={id = 784, lang = { true , [3]=true }, fruc = { true ,true }, url = "DKA"}, 
[776]={id = 776, lang = { true , [3]=true }, fruc = { true ,true }, url = "NPH"},
[782]={id = 782, lang = { true , [3]=true }, fruc = { true ,true }, url = "INN"}, 
[775]={id = 775, lang = { true , [3]=true }, fruc = { true ,true }, url = "MBS"},
[773]={id = 773, lang = { true , [3]=true }, fruc = { true ,true }, url = "SOM"},
[767]={id = 767, lang = { true , [3]=true }, fruc = { true ,true }, url = "ROE"},
[765]={id = 765, lang = { true , [3]=true }, fruc = { true ,true }, url = "WWK"},
[762]={id = 762, lang = { true , [3]=true }, fruc = { true ,true }, url = "ZEN"},
[758]={id = 758, lang = { true , [3]=true }, fruc = { true ,true }, url = "ARB"},
[756]={id = 756, lang = { true , [3]=true }, fruc = { true ,true }, url = "CON"},
[754]={id = 754, lang = { true , [3]=true }, fruc = { true ,true }, url = "Alara"},
[752]={id = 752, lang = { true , [3]=true }, fruc = { true ,true }, url = "EVE"},
[751]={id = 751, lang = { true , [3]=true }, fruc = { true ,true }, url = "SHM"},
[750]={id = 750, lang = { true , [3]=true }, fruc = { true ,true }, url = "MOR"},
[730]={id = 730, lang = { true , [3]=true }, fruc = { true ,true }, url = "LOR"},
[710]={id = 710, lang = { true , [3]=true }, fruc = { true ,true }, url = "FS"},
[700]={id = 700, lang = { true , [3]=true }, fruc = { true ,true }, url = "PLC"},
[690]={id = 690, lang = { true , [3]=true }, fruc = { true ,true }, url = "TS"},
[680]={id = 680, lang = { true , [3]=true }, fruc = { true ,true }, url = "TS"},
[670]={id = 670, lang = { true , [3]=true }, fruc = { true ,true }, url = "CS"},
[660]={id = 660, lang = { true , [3]=true }, fruc = { true ,true }, url = "DIS"},
[650]={id = 650, lang = { true , [3]=true }, fruc = { true ,true }, url = "GP"},
[640]={id = 640, lang = { true , [3]=true }, fruc = { true ,true }, url = "RAV"},
[620]={id = 620, lang = { true , [3]=true }, fruc = { true ,true }, url = "SK"},
[610]={id = 610, lang = { true , [3]=true }, fruc = { true ,true }, url = "BK"},
[590]={id = 590, lang = { true , [3]=true }, fruc = { true ,true }, url = "CK"},
[580]={id = 580, lang = { true , [3]=true }, fruc = { true ,true }, url = "FD"},
[570]={id = 570, lang = { true , [3]=true }, fruc = { true ,true }, url = "DS"},
[560]={id = 560, lang = { true , [3]=true }, fruc = { true ,true }, url = "MD"},
[540]={id = 540, lang = { true , [3]=true }, fruc = { true ,true }, url = "SC"},
[530]={id = 530, lang = { true , [3]=true }, fruc = { true ,true }, url = "LE"},
[520]={id = 520, lang = { true , [3]=true }, fruc = { true ,true }, url = "Onslaught"},
[510]={id = 510, lang = { true , [3]=true }, fruc = { true ,true }, url = "JD"},
[500]={id = 500, lang = { true , [3]=true }, fruc = { true ,true }, url = "TO"},
[480]={id = 480, lang = { true , [3]=true }, fruc = { true ,true }, url = "OD"},
[470]={id = 470, lang = { true , [3]=true }, fruc = { true ,true }, url = "AP"},
[450]={id = 450, lang = { true , [3]=true }, fruc = { true ,true }, url = "PL%20"},
[430]={id = 430, lang = { true , [3]=true }, fruc = { true ,true }, url = "Invasion"},
[420]={id = 420, lang = { true , [3]=true }, fruc = { true ,true }, url = "PR"},
[410]={id = 410, lang = { true , [3]=true }, fruc = { true ,true }, url = "NE"},
[400]={id = 400, lang = { true , [3]=true }, fruc = { true ,true }, url = "MM"},
[370]={id = 370, lang = { true , [3]=true }, fruc = { true ,true }, url = "UD"},
[350]={id = 350, lang = { true , [3]=true }, fruc = { true ,true }, url = "UL"},
[330]={id = 330, lang = { true , [3]=true }, fruc = { false,true }, url = "US"},
[300]={id = 300, lang = { true , [3]=true }, fruc = { false,true }, url = "EX"},
[290]={id = 290, lang = { true , [3]=true }, fruc = { false,true }, url = "SH"},
[280]={id = 280, lang = { true , [3]=true }, fruc = { false,true }, url = "TP"},
[270]={id = 270, lang = { true , [3]=true }, fruc = { false,true }, url = "WL"},
[240]={id = 240, lang = { true , [3]=true }, fruc = { false,true }, url = "VI"},
[230]={id = 230, lang = { true , [3]=true }, fruc = { false,true }, url = "MI"},
[220]={id = 220, lang = { true , [3]=true }, fruc = { false,true }, url = "Alliances"},
[210]={id = 210, lang = { true , [3]=true }, fruc = { false,true }, url = "HL"},
[190]={id = 190, lang = { true , [3]=true }, fruc = { false,true }, url = "IA"},
[170]={id = 170, lang = { true , [3]=false}, fruc = { false,true }, url = "FE"},
[160]={id = 160, lang = { true , [3]=false,[5]=true }, fruc = { false,true }, url = "DK%20"},
[150]={id = 150, lang = { true , [3]=false,[5]=true }, fruc = { false,true }, url = "LG%20"},
[130]={id = 130, lang = { true , [3]=false }, fruc = { false,true }, url = "AQ"},
[120]={id = 120, lang = { true , [3]=false }, fruc = { false,true }, url = "AN"},
-- special sets
[807]={id = 807, lang = { true , [3]=false}, fruc = { true ,true }, url = "CNS"},--Conspiracy
[805]={id = 805, lang = { true , [3]=false}, fruc = { false,true }, url = "JVV"}, -- Duel Decks: Jace vs. Vaska
[801]={id = 801, lang = { true , [3]=false}, fruc = { false,true }, url = "C13"},--Commander 2013
[796]={id = 796, lang = { true , [3]=false}, fruc = { true ,true }, url = "MMA"}, -- Modern Masters
[794]={id = 794, lang = { true , [3]=false}, fruc = { false,true }, url = "SVT"},--Duel Decks: Sorin vs. Tibalt
[790]={id = 790, lang = { true , [3]=false}, fruc = { false,true }, url = "IZZ"},--Duel Decks: Izzet vs. Golgari
[785]={id = 785, lang = { true , [3]=false}, fruc = { false,true }, url = "VEN"},--Duel Decks: Venser vs. Koth
[772]={id = 772, lang = { false, [3]=true }, fruc = { false,true }, url = "ELSTEZ"},--Duel Decks: Elspeth vs. Tezzeret
[757]={id = 757, lang = { true , [3]=false}, fruc = { false,true }, url = "DvD"},--Duel Decks: Divine vs. Demonic
[600]={id = 600, lang = { true , [3]=false}, fruc = { true ,true }, url = "UH"}, -- Unhinged
[320]={id = 320, lang = { true , [3]=false}, fruc = { false,true }, url = "UG"}, -- Unglued
[310]={id = 310, lang = { true , [3]=true }, fruc = { false,true }, url = "PT2"}, -- Portal Second Age
[260]={id = 260, lang = { true , [3]=true }, fruc = { false,true }, url = "PT1"}, -- Portal
[201]={id = 201, lang = { false, [3]=true }, fruc = { false,true }, url = "REN"}, -- Renaissance 
[200]={id = 200, lang = { true , [3]=false}, fruc = { false,true }, url = "CH"}, -- Chronicles
} -- end table site.sets

--[[- card name replacement tables.

  fields are for subtables indexed by #number setid.
 { #number (setid)= #table { #string (oldname)= #string , ... } , ... }
 
 @type site.namereplace
 @field [parent=#site.namereplace] #string name
]]
site.namereplace = {
[797] = { -- M2014
["Token - Elemental (7) (R)"]				= "Elemental (7)",
["Token - Elemental (8) (R)"]				= "Elemental (8)",
["Token - Elementarwesen (7) (R)"]			= "Elementarwesen (7)",
["Token - Elementarwesen (8) (R)"]			= "Elementarwesen (8)",
},
[779] = { -- M2012
["Aether Adept"]						= "Æther Adept",
},
[770] = { -- M11
["Aether Adept"]						= "Æther Adept",
["Zyklop -Gladiator"]					= "Zyklop-Gladiator",
["Token - Schlammwesen (G)"]			= "Ooze",
["Token - Ooze (1) (G)"]				= "Ooze (6)",
["Token - Ooze (2) (G)"]				= "Ooze (5)",
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
["Tainted Aether"]						= "Tainted Æther",
["Aether Flash"]						= "Æther Flash",
["Baumvolksprößlinge"]					= "Baumvolksprösslinge",
["Flußpferdbulle"]						= "Flusspferdbulle",
["Ausschluß"]							= "Ausschluss",
["Phyrexianischer Koloß"]				= "Phyrexianischer Koloss",
["Dornenelementar (273)"]				= "Dornenelementar",
},
[360] = { -- 6th
["Aether Flash"]						= "Æther Flash",
["Zwiespaltszepter"]					= "Zwiespaltsszepter",
["Hammer von Bogardan (Hammer aus Bogardan)"]	= "Hammer von Bogardan",
["Zwang (engl. Coercion)"]				= "Zwang",
["Stein der Sanftmut"]					= "Stein des Sanftmuts"
},
[250] = { -- 5th
["Aether Storm"]						= "Æther Storm",
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
[802] = { --Born of the Gods
["Brimaz' Vorhut"]						= "Vanguard of Brimaz",
--["Brimaz' Vorhut"]						= "Brimaz’ Vorhut",
["Unravel the Aether"]					= "Unravel the Æther",
["Token - Bird (W)"]					= "Bird (1)",
["Token - Bird (U)"]					= "Bird (4)",
["Token - Vogel (W)"]					= "Vogel (1)",
["Token - Vogel (U)"]					= "Vogel (4)",
},
[800] = { -- Theros
["Mogis' Plünderer"]					= "Mogis’ Plünderer",
--["Mogis' Plünderer"]					= "Mogis's Marauder",
["Token - Soldier (R)"]					= "Soldier (7)",
["Token - Soldier (2) (W)"]				= "Soldier (2)",
["Token - Soldier (3) (W)"]				= "Soldier (3)",
["Token - Soldat (R)"]					= "Soldat (7)",
["Token - Soldat (2) (W)"]				= "Soldat (2)",
["Token - Soldat (3) (W)"]				= "Soldat (3)",
},
[795] = { -- Dragon's Maze
["Aetherling"]							= "Ætherling",
["Token - Elementarwesen (Token)"]		= "Elementarwesen",
},
[793] = { -- Gatecrash
["Aetherize"]							= "Ætherize",
},
[786] = { -- Avacyn Restored
["Token - Human (W)"]				= "Human (2)",
["Token - Human (R)"]				= "Human (7)",
["Token - Spirit (W)"]				= "Spirit (3)",
["Token - Spirit (U)"]				= "Spirit (4)",
["Token - Mensch (W)"]				= "Mensch (2)",
["Token - Mensch (R)"]				= "Mensch (7)",
["Token - Geist (W)"]				= "Geist (3)",
["Token - Geist (U)"]				= "Geist (4)",
},
[784] = { -- Dark Ascension
["Mondrenner-Schamanin|Trovolars Zauberjägerin"]	= "Mondrenner-Schamanin|Tovolars Zauberjägerin",
["Checklist Card Dark Ascension"]		= "Checklist",
["Checklisten-Karte Dunkles Erwachen"]	= "Checklist",
["Séance)"]								= "Séance",
["Séance (Seance)"]						= "Séance",
},
[782] = { -- Innistrad
["Ludevic's Test Subject|Ludevic's Abomniation"] = "Ludevic's Test Subject|Ludevic's Abomination",
["Checklist Card Innistrad"]			= "Checklist",
["Checklisten-Karte Innistrad"]			= "Checklist",
["Token - Wolf (B)"]					= "Wolf (6)", 
["Token - Wolf (G)"]					= "Wolf (12)", 
["Token - Zombie (B)"]					= "Zombie",
},
[776] = { -- New Phyrexia
["Arm with Aether"]						= "Arm with Æther"
},
[773] = { -- Scars of Mirrodin
["Token - Poison Counter (C)"]				= "Poison Counter",
["Token - Giftmarke (C)"]					= "Poison Counter",
["Token - Wurm (Deathtouch) (A)"]			= "Wurm (8)",
["Token - Wurm (Lifelink) (A)"]				= "Wurm (9)",
["Token - Wurm (Token|Todesberührung) (A)"]		= "Wurm (8)",
["Token - Wurm (Token|Lebensverknüpfung) (A)"]	= "Wurm (9)",
},
[767] = { -- Rise of the Eldrazi
["Swamp (2340)"]						= "Swamp (240)",
["Token - Eldrazi Spawn (C)"]			= "Eldrazi Spawn",
["Token - Eldrazi, Ausgeburt (C)"]		= "Eldrazi, Ausgeburt",
},
[765] = { -- Worldwake
["Aether Tradewinds"]					= "Æther Tradewinds",
["Elefant"]								= "Elefant ",
},
[762] = { -- Zendikar
["Aether Figment"]						= "Æther Figment",
},
[756] = { -- Conflux
["Scornful Aether-Lich"]				= "Scornful Æther-Lich"
},
[754] = { -- Shards of Alara
["Macht des Seele (Macht der Seele)"]	= "Macht des Seele",
["Soul's Might)"]						= "Soul's Might",
["Blasenkäpfer"]						= "Blasenkäfer",
},
[751] = { -- Shadowmoor
["Aethertow"]							= "Æthertow",
["Mühsam erkämpfter Rum"]				= "Mühsam erkämpfter Ruhm",
["Token - Elemental (R)"]				= "Elemental (4)",
["Token - Elemental (H)"]				= "Elemental (9)",
["Token - Elf Warrior (G)"]				= "Elf Warrior (5)",
["Token - Elf Warrior (H)"]				= "Elf Warrior (12)",
["Token - Elementarwesen (R)"]			= "Elementarwesen (4)",
["Token - Elementarwesen (H)"]			= "Elementarwesen (9)",
["Token - Elf, Krieger (G)"]			= "Elf, Krieger (5)",
["Token - Elf, Krieger (H)"]			= "Elf, Krieger (12)",
},
[730] = { -- Lorwyn
["Aethersnipe"]							= "Æthersnipe",
["Token - Elemental (W)"]				= "Elemental (2)",
["Token - Elemental (G)"]				= "Elemental (8)",
["Token - Elementarwesen (W)"]			= "Elementarwesen (2)",
["Token - Elementarwesen (G)"]			= "Elementarwesen (8)",
},
[710] = { -- Future Sight
["Tarmogoyf, englisch"]					= "Tarmogoyf",
["Tarmogoyf, deutsch"]					= "Tarmogoyf",
["Vedalken Aethermage"]					= "Vedalken Æthermage"
},
[700] = { -- Planar Chaos
["Frozen Aether"]						= "Frozen Æther",
["Aether Membrane"]						= "Æther Membrane"
},
[690] = { -- Timeshifted
["Sindbad, der Seefahrer"]				= "Sindbad der Seefahrer",
["Dandan"]								= "Dandân"
},
[680] = { -- Time Spiral
["Aether Web"]							= "Æther Web",
["Aetherflame Wall"]					= "Ætherflame Wall",
["Lim-Dul the Necromancer"]				= "Lim-Dûl the Necromancer"
},
[670] = { -- Coldsnap
["Surging Aether"]						= "Surging Æther",
["Gaza Zol, Seuchenkönigin"]			= "Garza Zol, Seuchenkönigin",
["Nachleuten"]							= "Nachleuchten",
},
[660] = { -- Dissension
["Aethermage's Touch"]					= "Æthermage's Touch",
["Azorius Aethermage"]					= "Azorius Æthermage"
},
[650] = { -- Guildpact
["Aetherplasm"]							= "Ætherplasm",
["Parallelektrische Rückkoppelung"]		= "Parallelektrische Rückkopplung",
},
[620] = { -- Saviors of Kamigawa
["Aether Shockwave"]					= "Æther Shockwave",
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
--["Brothers Yamazaki"]					= "Brothers Yamazaki (160a)",
["Brothers Yamazaki (1)"]				= "Brothers Yamazaki (160a)",
["Brothers Yamazaki (2)"]				= "Brothers Yamazaki (160b)",
--["Yamazaki-Brüder"]						= "Yamazaki-Brüder (160a)",
["Yamazaki-Brüder (1)"]					= "Yamazaki-Brüder (160a)",
["Yamazaki-Brüder (2)"]					= "Yamazaki-Brüder (160b)",
["Aura der Oberschaft"]					= "Aura der Oberherrschaft",
["Spährenweber-Kumo"]					= "Sphärenweber-Kumo",
["Honor-worn Shaku"]					= "Honor-Worn Shaku",
},
[580] = { -- Fifth Dawn
["Fold into Aether"]					= "Fold into Æther",
["Virdischer Späher"]					= "Viridischer Späher",
["Virdische Sagenbewahrer"]				= "Viridische Sagenbewahrer",
},
[570] = { -- Darksteel
["Aether Snap"]							= "Æther Snap",
["Aether Vial"]							= "Æther Vial"
},
[560] = { -- Mirrodin
["Gate to the Aether"]					= "Gate to the Æther",
["Aether Spellbomb"]					= "Æther Spellbomb"
},
[530] = { -- Legions
["Brüllender Blutsiedler"]				= "Brüllender Blutsieder",
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
[430] = { -- Invasion
["Aether Rift"]							= "Æther Rift"
},
[410] = { -- Nemesis
["Aether Barrier"]						= "Æther Barrier",
["Rhox (112)a"]							= "Rhox",
["Aufstrebender Envincar"]				= "Aufstrebender Evincar",
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
["Benalische Infantrie"]				= "Benalische Infanterie",
["Reißzahnratte"]						= "Reißzahnratten",
},
[220] = { -- Alliances
["Insidious Bookworm"]					= "Insidious Bookworms",
["Gorilla Chieftan"]					= "Gorilla Chieftain",
["Lim-Duls Gruft"]						= "Lim-Dûls Gruft",
["Ahnen aus dem Yavimaya"]				= "Ahnen aus Yavimaya",
["Lim-Duls Paladin"]					= "Lim-Dûls Paladin",
["Lim-Dul's High Guard"]				= "Lim-Dûl's High Guard",
},
[210] = { -- Homelands
["Aether Storm"]						= "Æther Storm"
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
[150] = { -- Legends
["Aerathi Berserker"]					= "Ærathi Berserker"
},
[120] = { -- Arabian Nights
["Junun Efreet"]						= "Junún Efreet",
["Ifh-Biff Efreet"]						= "Ifh-Bíff Efreet",
["Ring of Ma'ruf"]						= "Ring of Ma ruf",
},
-- specal sets
[807] = { -- Conspiracy
["Aether Tradewinds"]					= "Æther Tradewinds",
["Aether Searcher"]						= "Æther Searcher"
},
[805] = { --Duel Decks: Jace vs. Vraska
["Aether Adept (Meister des Äthers)"]	= "Æther Adept",
["Aether Figment (Äthergespinst)"]		= "Æther Figment",
},
[801] = { -- Commander 2013
["Kongming, “Sleeping Dragon“"]			= "Kongming, “Sleeping Dragon”",
["Aethermage's Touch"]					= "Æthermage's Touch",
},
[796] = { -- Modern Masters
["Aether Vial"]							= "Æther Vial",
["Aether Spellbomb"]					= "Æther Spellbomb",
["Aethersnipe"]							= "Æthersnipe",
},
[785] = { -- DD:Venser vs. Koth
["Aether Membrane"]						= "Æther Membrane",
["Venser, the Sojourner (Alternate)"]	= "Venser, the Sojourner",
["Koth of the Hammer (Alternate)"]		= "Koth of the Hammer",
},
[772] = { -- DD:Elspeth vs. Tezzeret
["Argivische Wiederherstellung (Argivische Restauration)"]	= "Argivische Wiederherstellung",
},
[600] = { -- Unhinged
["First Come First Served"]				= "First Come, First Served",
["Our Market Research Shows ..."]		= "Our Market Research Shows That Players Like Really Long Card Names So We Made this Card to Have the Absolute Longest Card Name Ever Elemental",
["Our Market Research Shows ?"]		= "Our Market Research Shows That Players Like Really Long Card Names So We Made this Card to Have the Absolute Longest Card Name Ever Elemental",
["Erase"]								= "Erase (Not the Urza’s Legacy One)",
["Who|What/When|Where/Why"]				= "Who|What|When|Where|Why",
["Yet Another Aether Vortex"]			= "Yet Another Æther Vortex",
["“Ach! Hans, Run!“"]					= "“Ach! Hans, Run!”",
},
[320] = { -- Unglued
["B.F.M. (Big Furry Monster) links"]	= "B.F.M. (Left)",
["B.F.M. (Big Furry Monster) rechts"]	= "B.F.M. (Right)",
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
[200] = { -- Chronicles
["Dandan"]								= "Dandân",
["Ghazban Ogre"]						= "Ghazbán Ogre",
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
[450] = { --Planeshift
},
[130] = { -- Antiquities
--["Mishra's Factory"] 			= { "Mishra's Factory"		, { 1    , 2    , 3    , 4     } },
["Mishra's Factory, Frühling"] 	= { "Mishra's Factory"		, { 1    , false, false, false } },
["Mishra's Factory, Sommer"] 	= { "Mishra's Factory"		, { false, 2    , false, false } },
["Mishra's Factory, Herbst"] 	= { "Mishra's Factory"		, { false, false, 3    , false } },
["Mishra's Factory, Winter"] 	= { "Mishra's Factory"		, { false, false, false, 4     } },
--["Strip Mine"] 					= { "Strip Mine"			, { 1    , 2    , 3    , 4     } },
["Strip Mine, kein Himmel"] 	= { "Strip Mine"			, { 1    , false, false, false } },
["Strip Mine, ebene Treppen"] 	= { "Strip Mine"			, { false, 2    , false, false } },
["Strip Mine, mit Turm"] 		= { "Strip Mine"			, { false, false, 3    , false } },
["Strip Mine, unebene Treppen"] = { "Strip Mine"			, { false, false, false, 4     } },
--["Urza's Mine"] 				= { "Urza's Mine"			, { 1    , 2    , 3    , 4     } },
--["Urza's Power Plant"] 			= { "Urza's Power Plant"	, { 1    , 2    , 3    , 4     } },
--["Urza's Tower"] 				= { "Urza's Tower"			, { 1    , 2    , 3    , 4     } },
},
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
--[772]={
--not needed, card have "(Foil)" suffix
--["Elspeth, fahrende Ritterin"]	= { foil = true},
--["Tezzeret der Sucher "]		= { foil = true},
--	},
} -- end table site.foiltweak

--[[- wrapper function for expected table 
 Wraps table site.expected, so we can wait for LHpi.Data to be loaded before setting it.
 This allows to read LHpi.Data.sets[setid].cardcount tables for less hardcoded numbers. 

 @function [parent=#site] SetExpected
 @param nil
]]
function site.SetExpected()
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
[797] = { namereplaced=4 },
[779] = { namereplaced=2 },
[770] = { namereplaced=8 },
[720] = { pset={ [3]=383-1+6 }, failed={ [3]=1 }, namereplaced=3 },
[630] = { pset={ 359-9, [3]=352-2 }, namereplaced=2 },
[550] = { pset={ 357-7, [3]=355-5 }, namereplaced=7 },
[460] = { namereplaced=7 },
[360] = { namereplaced=5 },
[250] = { namereplaced=4 },
[180] = { namereplaced=5 },
[140] = { pset={ [3]=306-1 }, failed= { [3]=1 }, namereplaced=6 },
[139] = { namereplaced=2 },
[110] = { pset={ 302-7-9 }, namereplaced=1 }, -- 7 empty cards on page, 9 missing entirely
[100] = { pset={ 249 } },
-- Expansions
[806] = { pset={ [3]=171-6 }, failed= { [3]=6 } }, -- -6 is tokens
[802] = { namereplaced=6 },
[800] = { namereplaced=8 },
[795] = { pset={ [3]=157-1 }, failed= { [3]=1 }, namereplaced=1 }, -- -1 is token
[793] = { namereplaced=1 },
[786] = { namereplaced=8 },
[784] = { pset={ 161+1 }, failed={ [3]=1 }, namereplaced=7 }, --+1 is Checklist
[782] = { pset={ 276+1 }, failed={ [3]=1 }, namereplaced=9 }, -- +1/fail is Checklist
[776] = { namereplaced=2 },
[773] = { failed={ 1, [3]=1 }, namereplaced=6 }, -- fail is Poison Counter
[767] = { namereplaced=3 },
[765] = { namereplaced=2 },
[762] = { namereplaced=1 },
[756] = { namereplaced=2 },
[754] = { namereplaced=4 },
[751] = { namereplaced=12 },
[730] = { namereplaced=5 },
[710] = { namereplaced=4 },
[700] = { namereplaced=3 },
[690] = { dropped=956, namereplaced=5 },
[680] = { dropped=373, namereplaced=5 },
[670] = { namereplaced=4 },
[660] = { namereplaced=4 },
[650] = { namereplaced=4 },
[654] = { namereplaced=3 },
[650] = { namereplaced=3 },
[620] = { namereplaced=16 },
[610] = { namereplaced=19 },
[590] = { namereplaced=33 },
[580] = { namereplaced=6 },
[570] = { namereplaced=3 },
[560] = { namereplaced=3 },
[530] = { namereplaced=2 },
[520] = { namereplaced=1 },
[480] = { namereplaced=2 },
[470] = { namereplaced=1 },
[450] = { pset={ 146-3, [3]=146-3 } },-- 3 alt art versions missing
[430] = { namereplaced=1 },
[410] = { failed= { [3]=1 }, namereplaced = 5 },
[370] = { namereplaced=2 },
[330] = { namereplaced=1 },
[300] = { namereplaced=1 },
[270] = { namereplaced=3 },
[220] = { namereplaced=6 },
[210] = { namereplaced=1 },
[190] = { namereplaced=4 },
[160] = { namereplaced=1 }, -- in ita
[150] = { namereplaced=2 },
[120] = { namereplaced=3 },
-- special sets
[807] = { pset={ LHpi.Data.sets[807].cardcount.reg+LHpi.Data.sets[807].cardcount.nontr }, namereplaced=3 },--no tokens
[805] = { namereplaced=2 },
[801] = { pset={ LHpi.Data.sets[801].cardcount.reg+LHpi.Data.sets[801].cardcount.overs }, failed={ LHpi.Data.sets[801].cardcount.overs }, namereplaced=2 },
[796] = { namereplaced=5 },
[794] = { foiltweaked=2 },
[790] = { foiltweaked=2 },
[785] = { namereplaced=3, foiltweaked=2 },
[772] = { namereplaced=1, foiltweaked=0 },
[757] = { foiltweaked=2 },
[600] = { namereplaced=9, foiltweaked=1 },
[320] = { namereplaced=6 },
[310] = { namereplaced=2 },
[260] = { pset={ 228-6-7,[3]=228-6-7 }, namereplaced=4 },-- no(6) DG, no(7) ST variants (also ma:no GER "DG")
[200] = { namereplaced=2 },
	}--end table site.expected
end--function site.SetExpected
--EOF