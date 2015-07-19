--*- coding: utf-8 -*-
--[[- LHpi trader-online.de sitescript 
Price import script for Magic Album
uses and needs LHpi library
to import card pricing from www.trader-online.de.

Inspired by and loosely based on "MTG Mint Card.lua" by Goblin Hero, Stromglad1 and "Import Prices.lua" by woogerboy21;
who generously granted permission to "do as I like" with their code;
everything else Copyright (C) 2012-2015 by Christian Harms.
If you want to contact me about the script, try its release thread in http://www.slightlymagic.net/forum/viewforum.php?f=32

@module LHpi.site
@author Christian Harms
@copyright 2012-2015 Christian Harms except parts by Goblin Hero, Stromglad1 or woogerboy21
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
2.13.6.13
added 814
2.14.5.13
removed url to filename changes that are done by the library if OFFLINE 
2.15.6.14
synchronized with template
]]

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
-- @field [parent=#global] #boolean STRICTEXPECTED
--STRICTEXPECTED = true

--- if true, exit with error on object type mismatch, else use object type 0 (all);	default true
-- @field [parent=#global] #boolean STRICTOBJTYPE
--STRICTOBJTYPE = false

--- log to seperate logfile instead of Magic Album.log;	default true
-- @field [parent=#global] #boolean SAVELOG
--SAVELOG = false

---	read source data from #string savepath instead of site url; default false
-- @field [parent=#global] #boolean OFFLINE
OFFLINE = true--download from dummy, only change to false for release

--- save a local copy of each source html to #string savepath if not in OFFLINE mode; default false
-- @field [parent=#global] #boolean SAVEHTML
--SAVEHTML = true

--- save price table to file before importing to MA;	default false
-- @field [parent=#global] #boolean SAVETABLE
--SAVETABLE = true

---	log everything and exit on error; default false
-- @field [parent=#global] #boolean DEBUG
--DEBUG = true

---	log raw html data found by regex; default false
-- @field [parent=#global] #boolean DEBUGFOUND
--DEBUGFOUND = true

--- DEBUG (only but deeper) inside variant loops; default false
-- @field [parent=#global] #boolean DEBUGVARIANTS
--DEBUGVARIANTS = true

--- revision of the LHpi library to use
-- @field #string libver
local libver = "2.15"
--- revision of the LHpi library datafile to use
-- @field #string dataver
local dataver = "6"
--- sitescript revision number
-- @field  string scriptver
local scriptver = "14"
--- should be similar to the script's filename. Used for loging and savepath.
-- @field #string scriptname
local scriptname = "LHpi.trader-onlineDE-v" .. libver .. "." .. dataver .. "." .. scriptver .. ".lua"
--- savepath for OFFLINE (read) and SAVEHTML (write). must point to an existing directory relative to MA's root.
-- set by LHpi lib unless specified here.
-- @field  #string savepath
--local savepath = "Prices\\" .. string.gsub( scriptname , "%-v%d+%.%d+%.lua$" , "" ) .. "\\"
local savepath = savepath -- keep external global savepath
--- log file name. must point to (nonexisting or writable) file in existing directory relative to MA's root.
-- set by LHpi lib unless specified here. Defaults to LHpi.log unless SAVELOG is true.
-- @field #string logfile
--local logfile = "Prices\\" .. string.gsub( site.scriptname , "lua$" , "log" )
local logfile = logfile -- keep external global logfile

---	LHpi library
-- will be loaded by ImportPrice
-- do not delete already present LHpi (needed for helper mode)
-- @field [parent=#global] #table LHpi
LHpi = LHpi or {}

--[[- Site specific configuration
 Settings that define the source site's structure and functions that depend on it,
 as well as some properties of the sitescript.
 
 @type site
 @field #string scriptname
 @field #string dataver
 @field #string logfile (optional)
 @field #string savepath (optional)
 @field #boolean sandbox 
]]
site={ scriptname=scriptname, dataver=dataver, logfile=logfile or nil, savepath=savepath or nil , sandbox=sandbox}

--[[- regex matches shall include all info about a single card that one html-file has,
 i.e. "*CARDNAME*FOILSTATUS*PRICE*".
 it will be chopped into its parts by site.ParseHtmlData later. 
 @field [parent=#site] #string regex
]]
site.regex = '<tr><td colspan="11"><hr noshade size=1></td></tr>\n%s*<tr>\n%s*(.-)</font></td>\n%s*<td width'

--- resultregex can be used to display in the Log how many card the source file claims to contain
-- @field #string resultregex
site.resultregex = "Es wurden <b>(%d+)</b> Artikel"
--- @field #string currency		not used yet;default "$"
site.currency = "€"
--- @field #string encoding		default "cp1252"
site.encoding="cp1252"

--- support for global workdir, if used outside of Magic Album/Prices folder. do not change here.
-- @field [parent=#local] #string workdir
-- @field [parent=#local] #string mapath
local workdir = workdir or "Prices\\"
local mapath = mapath or ".\\"

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
 @param #table scriptmode { #boolean listsets, boolean checksets, ... }
	-- nil if called by Magic Album
	-- will be passed to site.Initialize to trigger nonstandard modes of operation	
]]
function ImportPrice( importfoil , importlangs , importsets , scriptmode)
	scriptmode = scriptmode or {}
	if SAVELOG~=false then
		ma.Log( "Check " .. scriptname .. ".log for detailed information" )
	end
	ma.SetProgress( "Loading LHpi library", 0 )
	local loglater
	LHpi, loglater = site.LoadLib()
	collectgarbage() -- we now have LHpi table with all its functions inside, let's clear LHpilib and execlib() from memory
	if loglater then
		LHpi.Log(loglater ,0)
	end
	LHpi.Log( "LHpi lib is ready for use." )
	site.Initialize( scriptmode ) -- keep site-specific stuff out of ImportPrice
	LHpi.DoImport (importfoil , importlangs , importsets)
	LHpi.Log( "Lua script " .. scriptname .. " finished" ,0)
	collectgarbage()--try prevent MA crashes on exit
	ma.Log( "Lua script " .. scriptname .. " finished" )
end -- function ImportPrice

--[[- load LHpi library from external file
@function [parent=#site] LoadLib
@return #table LHpi library object
@return #string log concatenated strings to be logged when LHpi is available
]]
function site.LoadLib()
	local LHpi
	local libname = workdir .. "lib\\LHpi-v" .. libver .. ".lua"
	local loglater
	local LHpilib = ma.GetFile( libname )
	if tonumber(libver) < 2.15 then
		loglater = ""
		local oldlibname = workdir .. "LHpi-v" .. libver .. ".lua"
		local oldLHpilib = ma.GetFile ( oldlibname )
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
	return LHpi, loglater
end--function site.LoadLib

--[[- prepare script
 Do stuff here that needs to be done between loading the Library and calling LHpi.DoImport.
 At this point, LHpi's functions are available and OPTIONS are set,
 but default values for functions and other missing fields have not yet been set.
 
@param #table mode { #boolean flags for nonstandard modes of operation }
	-- nil if called by Magic Album
	-- mode.update	true to run update helper functions
 @function [parent=#site] Initialize
]]
function site.Initialize( mode )
	if mode == nil then
		mode = {}
	elseif "table" ~= type(mode) then
		local m=mode
		mode = { [m]=true }
	end
	if not LHpi or not LHpi.version then
		--error("LHpi library not loaded!")
		print("LHpi lib not available, loading it now...")
		LHpi = site.LoadLib()
	end
	LHpi.Log(site.scriptname.." started site.Initialize():",1)
	
	if mode.update then
		if not dummy then error("ListUnknownUrls needs to be run from dummyMA!") end
		dummy.CompareDummySets(mapath,site.libver)
		dummy.CompareDataSets(site.libver,site.libver)
		dummy.CompareSiteSets()
		dummy.ListUnknownUrls(site.FetchExpansionList())
		return
	end
end--function site.Initialize

--[[-  build source url/filename.
 Has to be done in sitescript since url structure is site specific.
 To allow returning more than one url here, BuildUrl is required to wrap it/them into a container table.

 foilonly and isfile fields can be nil and then are assumed to be false.
 while isfile is read and interpreted by the library, foilonly is not.
 Its only here as a convenient shortcut to set card.foil in your site.ParseHtmlData

Optionally, for setid=="list", you can return an url with a list of available sets.
This will be used by site.FetchExpansionList().
 
 @function [parent=#site] BuildUrl
 @param #number setid		see site.sets
 @param #number langid		see site.langs
 @param #number frucid		see site.frucs
 @param #boolean offline	DEPRECATED, read global OFFLINE instead if you need really it.
 							(can be nil) use local file instead of url
 @return #table { #string (url)= #table { isfile= #boolean, (optional) foilonly= #boolean, (optional) setid= #number, (optional) langid= #number, (optional) frucid= #number } , ... }
]]
function site.BuildUrl( setid,langid,frucid )
	site.domain = "www.trader-online.de/"
	if "list"==setid then
		return site.domain .. "Magic-Einzelkarten_englisch.php"
	end
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
	container[url] = {}
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
		container[url1] = {}			
		container[url2] = {}			
		if site.frucs[frucid].isfoil then
			container[url1].foilonly = true
			container[url2].foilonly = true
		end
	end--if setid
	
	return container
end -- function site.BuildUrl

--[[- fetch list of expansions to be used by update helper functions.
 The returned table shall contain at least the sets' name and LHpi-comnpatible urlsuffix,
 so it can be processed by dummy.ListUnknownUrls.
 Implementing this function is optional and may not be possible for some sites.
 @function [parent=#site] FetchExpansionList
 @return #table  @return #table { #number= #table { name= #string , urlsuffix= #string , ... }
]]
--[[- fetch list of expansions to be used by update helper functions.
 The returned table shall contain at least the sets' name and LHpi-comnpatible urlsuffix,
 so it can be processed by dummy.ListUnknownUrls.
 Implementing this function is optional and may not be possible for some sites.
 @function [parent=#site] FetchExpansionList
 @return #table  @return #table { #number= #table { name= #string , urlsuffix= #string , ... }
]]
function site.FetchExpansionList()
	if OFFLINE then
		LHpi.Log("OFFLINE mode active. Expansion list may not be up-to-date." ,1)
	end
	local expansionSource
	local url = site.BuildUrl( "list" )
	expansionSource = LHpi.GetSourceData ( url , urldetails )
	if not expansionSource then
		error(string.format("Expansion list not found at %s (OFFLINE=%s)",LHpi.Tostring(url),tostring(OFFLINE)) )
	end
	local setregex = 'serie=Serie%-([^"]+)">([^<]+)'
	local expansions = { }
	local i=0
	for url,name in string.gmatch( expansionSource , setregex) do
		i=i+1
		url=string.gsub(url," ?%-[Ee]$","")
		name=string.gsub(name," ?%(%w+%)$","")
		table.insert(expansions, { name=name, urlsuffix=url} )
	end
	LHpi.Log(i.." expansions found" ,1)
	return expansions
end--function site.FetchExpansionList
--[[- format string to use in dummy.ListUnknownUrls update helper function.
 @field [parent=#site] #string updateFormatString ]]
site.updateFormatString = "[%i]={id = %3i, lang = { true , [3]=true }, fruc = { true ,true }, url = %q},--%s"

--[[-  get data from foundstring.
 Has to be done in sitescript since html raw data structure is site specific.
 To allow returning more than one card here (foil and nonfoil versions are considered seperate cards at this stage!),
 ParseHtmlData is required to wrap it/them into a container table.
 NEW: newCard.price must be #number; if foundstring contains multiple prices, return a different card for each price! 
 If you decide to set regprice or foilprice directly, language and variant detection will not be applied to the price!
 LHpi.buildCardData will construct regprice or foilprice as #table { #number (langid)= #number, ... } or { #number (langid)= #table { #string (variant)= #number, ... }, ... }
 It's usually a good idea to explicitely set newCard.foil, for example by querying site.frucs[urldetails.frucid].isfoil, unless parsed card names contain a foil suffix.
 
 Price is returned as whole number to generalize decimal and digit group separators
 ( 1.000,00 vs 1,000.00 ); LHpi library then divides the price by 100 again.
 This is, of course, not optimal for speed, but the most flexible.

 Return value newCard can receive optional additional fields:
 @return #boolean newcard.foil		(semi-optional) set the card as foil. 
 @return #table newCard.pluginData	(optional) is passed on by LHpi.buildCardData for use in site.BCDpluginName and/or site.BCDpluginCard.
 @return #string newCard.name		(optional) will pre-set the card's unique (for the cardsetTable) identifying name.
 @return #table newCard.lang		(optional) will override LHpi.buildCardData generated values.
 @return #boolean newCard.drop		(optional) will override LHpi.buildCardData generated values.
 @return #table newCard.variant		(discouraged) will override LHpi.buildCardData generated values.
 @return #number or #table newCard.regprice		(discouraged) will override LHpi.buildCardData generated values. #number or #table { [#number langid]= #number,...}
 @return #number or #table newCard.foilprice 	(discouraged) will override LHpi.buildCardData generated values. #number or #table { [#number langid]= #number,...}
 
 @function [parent=#site] ParseHtmlData
 @param #string foundstring		one occurence of siteregex from raw html data
 @param #table urldetails		{ isfile= #boolean, oauth= #boolean, setid= #number, langid= #number, frucid= #number , foilonly= #boolean }
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
--	newCard.price[urldetails.langid] = price
	newCard.price = price
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
function site.BCDpluginPre ( card, setid, importfoil, importlangs )
	LHpi.Log( "site.BCDpluginPre got " .. LHpi.Tostring( card ) .. " from set " .. setid ,2)
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
	elseif setid == 801
	or setid == 807
	or setid == 812
	then
		card.name=string.gsub(card.name, "%s*englisch$", "")
		local _s,_e,nameeng,nameger = string.find(card.name, "(.+)%s*(%b())$")
		if nameeng and nameger then
			card.names[1]=string.gsub(nameeng,"(.-)%s*$", "%1")
			card.names[3]=string.gsub(nameger, "^%((.+)%)", "%1" )
			card.name=card.names[1]
		end--if nameeng,nameger
	end-- if setid
	
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
	LHpi.Log( "site.BCDpluginPost got " .. LHpi.Tostring( card ) .. " from set " .. setid ,2)
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
[808]={id = 808, lang = { true , [3]=true }, fruc = { true ,true }, url = "M15"}, 
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
[813]={id = 813, lang = { true , [3]=true }, fruc = { true ,true }, url = "KTK"},--Khans of Tarkir
[806]={id = 806, lang = { true , [3]=true }, fruc = { true ,true }, url = "JOU"},
[802]={id = 802, lang = { true , [3]=true }, fruc = { true ,true }, url = "BNG"},
[800]={id = 800, lang = { true , [3]=true }, fruc = { true ,true }, url = "THS"},
[795]={id = 795, lang = { true , [3]=true }, fruc = { true ,true }, url = "DGM"},
[793]={id = 793, lang = { true , [3]=true }, fruc = { true ,true }, url = "GTC"},
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
--[814]={id = 814, lang = { true , [3]=false}, fruc = { false,true }, url = "C14"},--Commander 2014
[812]={id = 812, lang = { true , [3]=false}, fruc = { false,true }, url = "DDN"}, -- Duel Decks: Speed vs. Cunning
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
 { #number (setid)= #table { #string (oldname)= #string (newname), ... } , ... }
 
 @type site.namereplace
 @field [parent=#site.namereplace] #string name
]]
site.namereplace = {
[808] = { --M2015
["Token - Emblem Ajani (A)"]			= "Ajani Steadfast Emblem",
["Token - Emblem Garruk (A)"]			= "Garruk, Apex Predator Emblem",
["Aetherspouts"]						= "Ætherspouts",
["Token - Beast (B)"]					= "Beast Token (5)",
["Token - Beast (G)"]					= "Beast Token (9)",
["Token - Bestie (B)"]					= "Bestie Token (5)",
["Token - Bestie (G)"]					= "Bestie Token (9)",
},
[797] = { -- M2014
["Token - Elemental (7) (R)"]			= "Elemental Token (7)",
["Token - Elemental (8) (R)"]			= "Elemental Token (8)",
["Token - Elementarwesen (7) (R)"]		= "Elementarwesen Token (7)",
["Token - Elementarwesen (8) (R)"]		= "Elementarwesen Token (8)",
},
[779] = { -- M2012
["Aether Adept"]						= "Æther Adept",
},
[770] = { -- M11
["Aether Adept"]						= "Æther Adept",
["Zyklop -Gladiator"]					= "Zyklop-Gladiator",
["Token - Schlammwesen (G)"]			= "Ooze Token",
["Token - Ooze (1) (G)"]				= "Ooze Token (6)",
["Token - Ooze (2) (G)"]				= "Ooze Token (5)",
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
--["Schilftroll|Manahaken (Fehldruck)"] 	= "Schilftroll",
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
[813] = { -- Khans of Tarkir
["Token - Warrior (3) (W)"]			= "Warrior Token (3)",
["Token - Warrior (4) (W)"]			= "Warrior Token (4)",
["Token - Krieger (3) (W)"]			= "Krieger Token (3)",
["Token - Krieger (4) (W)"]			= "Krieger Token (4)",
["Token - Emblem Sarkhan (A)"]		= "Sarkhan, the Dragonspeaker Emblem",
["Token - Emblem Sorin (A)"]		= "Sorin, Solemn Visitor Emblem",
["Anführerin der Klinge"]			= "Anführer der Klinge",
},
[802] = { --Born of the Gods
["Brimaz' Vorhut"]						= "Vanguard of Brimaz",
--["Brimaz' Vorhut"]						= "Brimaz’ Vorhut",
["Unravel the Aether"]					= "Unravel the Æther",
["Token - Bird (W)"]					= "Bird Token (1)",
["Token - Bird (U)"]					= "Bird Token (4)",
["Token - Vogel (W)"]					= "Vogel Token (1)",
["Token - Vogel (U)"]					= "Vogel Token (4)",
},
[800] = { -- Theros
["Mogis' Plünderer"]					= "Mogis’ Plünderer",
--["Mogis' Plünderer"]					= "Mogis's Marauder",
["Token - Soldier (R)"]					= "Soldier Token (7)",
["Token - Soldier (2) (W)"]				= "Soldier Token (2)",
["Token - Soldier (3) (W)"]				= "Soldier Token (3)",
["Token - Soldat (R)"]					= "Soldat Token (7)",
["Token - Soldat (2) (W)"]				= "Soldat Token (2)",
["Token - Soldat (3) (W)"]				= "Soldat Token (3)",
},
[795] = { -- Dragon's Maze
["Aetherling"]							= "Ætherling",
["Token - Elementarwesen (Token)"]		= "Elementarwesen",
},
[793] = { -- Gatecrash
["Aetherize"]							= "Ætherize",
},
[786] = { -- Avacyn Restored
["Token - Human (W)"]				= "Human Token (2)",
["Token - Human (R)"]				= "Human Token (7)",
["Token - Spirit (W)"]				= "Spirit Token (3)",
["Token - Spirit (U)"]				= "Spirit Token (4)",
["Token - Mensch (W)"]				= "Mensch Token (2)",
["Token - Mensch (R)"]				= "Mensch Token (7)",
["Token - Geist (W)"]				= "Geist Token (3)",
["Token - Geist (U)"]				= "Geist Token (4)",
},
[784] = { -- Dark Ascension
["Mondrenner-Schamanin|Trovolars Zauberjägerin"]	= "Mondrenner-Schamanin|Tovolars Zauberjägerin",
["Huntmaster of the Fells|Ravager of the Fells (Jagdmeister vom Kahlenberg|Verwüster vom Kahlenber"]	= "Huntmaster of the Fells|Ravager of the Fells",
["Checklist Card Dark Ascension"]		= "Checklist",
["Checklisten-Karte Dunkles Erwachen"]	= "Checklist",
["Séance)"]								= "Séance",
["Séance (Seance)"]						= "Séance",
},
[782] = { -- Innistrad
["Ludevic's Test Subject|Ludevic's Abomniation"] = "Ludevic's Test Subject|Ludevic's Abomination",
["Checklist Card Innistrad"]			= "Checklist",
["Checklisten-Karte Innistrad"]			= "Checklist",
["Token - Wolf (B)"]					= "Wolf Token (6)", 
["Token - Wolf (G)"]					= "Wolf Token (12)", 
["Token - Zombie (B)"]					= "Zombie Token",
},
[776] = { -- New Phyrexia
["Arm with Aether"]						= "Arm with Æther"
},
[773] = { -- Scars of Mirrodin
["Token - Poison Counter (C)"]				= "Poison Counter Token",
["Token - Giftmarke (C)"]					= "Poison Counter Token",
["Token - Wurm (Deathtouch) (A)"]			= "Wurm Token (8)",
["Token - Wurm (Lifelink) (A)"]				= "Wurm Token (9)",
["Token - Wurm (Token|Todesberührung) (A)"]		= "Wurm Token (8)",
["Token - Wurm (Token|Lebensverknüpfung) (A)"]	= "Wurm Token (9)",
},
[767] = { -- Rise of the Eldrazi
["Swamp (2340)"]						= "Swamp (240)",
["Token - Eldrazi Spawn (C)"]			= "Eldrazi Spawn Token",
["Token - Eldrazi, Ausgeburt (C)"]		= "Eldrazi, Ausgeburt Token",
},
[765] = { -- Worldwake
["Aether Tradewinds"]					= "Æther Tradewinds",
["Elefant"]								= "Elefant (Token)",
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
["Token - Elemental (R)"]				= "Elemental Token (4)",
["Token - Elemental (H)"]				= "Elemental Token (9)",
["Token - Elf Warrior (G)"]				= "Elf Warrior Token (5)",
["Token - Elf Warrior (H)"]				= "Elf Warrior Token (12)",
["Token - Elementarwesen (R)"]			= "Elementarwesen Token (4)",
["Token - Elementarwesen (H)"]			= "Elementarwesen Token (9)",
["Token - Elf, Krieger (G)"]			= "Elf, Krieger Token (5)",
["Token - Elf, Krieger (H)"]			= "Elf, Krieger Token (12)",
},
[730] = { -- Lorwyn
["Aethersnipe"]							= "Æthersnipe",
["Token - Elemental (W)"]				= "Elemental Token (2)",
["Token - Elemental (G)"]				= "Elemental Token (8)",
["Token - Elementarwesen (W)"]			= "Elementarwesen Token (2)",
["Token - Elementarwesen (G)"]			= "Elementarwesen Token (8)",
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
['Kongming, "Sleeping Dragon"']			= "Kongming, “Sleeping Dragon”",
["Aethermage's Touch"]					= "Æthermage's Touch",
["Sek'Kuar, Deathkeeper"]				= "Sek’Kuar, Deathkeeper",
["Jeleva, Nephalia's Scourge"]			 = "Jeleva, Nephalia’s Scourge",
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
["Our Market Research Shows ?"]			= "Our Market Research Shows That Players Like Really Long Card Names So We Made this Card to Have the Absolute Longest Card Name Ever Elemental",
["Erase"]								= "Erase (Not the Urza’s Legacy One)",
["Who|What/When|Where/Why"]				= "Who|What|When|Where|Why",
["Yet Another Aether Vortex"]			= "Yet Another Æther Vortex",
['"Ach! Hans, Run!"']					= "“Ach! Hans, Run!”",
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
 @field [parent=#site.foiltweak] #boolean override	(optional) if true, defaults from LHpi.Data will not be used at all
 @field [parent=#site.foiltweak] #table foilstatus
]]
site.foiltweak = {
--[772]={
--not needed, cards have "(Foil)" suffix
--["Elspeth, fahrende Ritterin"]	= { foil = true},
--["Tezzeret der Sucher "]		= { foil = true},
--	},
} -- end table site.foiltweak

--[[- wrapper function for expected table 
 Wraps table site.expected, so we can wait for LHpi.Data to be loaded before setting it.
 This allows to read LHpi.Data.sets[setid].cardcount tables for less hardcoded numbers. 

 @function [parent=#site] SetExpected
 @param #string importfoil	"y"|"n"|"o" passed from DoImport
 @param #table importlangs	{ #number (langid)= #string , ... } passed from DoImport
 @param #table importsets	{ #number (setid)= #string , ... } passed from DoImport
]]
function site.SetExpected( importfoil , importlangs , importsets )
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
--- pset defaults to LHpi.Data.sets[setid].cardcount.reg, if available and not set otherwise here.
--  LHpi.Data.sets[setid]cardcount has 6 fields you can use to avoid hardcoded numbers here: { reg, tok, both, nontrad, repl, all }.

--- if site.expected.tokens is true, LHpi.Data.sets[setid].cardcount.tok is added to pset default.
-- a boolean will set this for all languges, a table will be assumed to be of the form { [langid]=#boolean, ... }
-- @field [parent=#site.expected] #boolean or #table { #boolean,...} tokens
	tokens = true,
--- if site.expected.nontrad is true, LHpi.Data.sets[setid].cardcount.nontrad is added to pset default.
-- a boolean will set this for all languges, a table will be assumed to be of the form { [langid]=#boolean, ... }
-- @field [parent=#site.expected] #boolean nontrad
	nontrad = true,
--- if site.expected.replica is true, LHpi.Data.sets[setid].cardcount.repl is added to pset default.
-- a boolean will set this for all languges, a table will be assumed to be of the form { [langid]=#boolean, ... }
-- @field [parent=#site.expected] #boolean replica
	replica = true,
-- Core sets
[808] = {pset={ LHpi.Data.sets[808].cardcount.both-15, [3]=LHpi.Data.sets[808].cardcount.reg-15 }, failed={[3]=LHpi.Data.sets[808].cardcount.tok}, namereplaced=10 },-- -15 extra cards (nr. 270 - 284)
[797] = { namereplaced=4 },
[779] = { namereplaced=2 },
[770] = { namereplaced=8 },
[720] = { pset={ LHpi.Data.sets[720].cardcount.both-1,[3]=LHpi.Data.sets[720].cardcount.both-2 }, failed={ 1,[3]=1 }, namereplaced=3 },
[630] = { pset={ 359-9, [3]=352-2 }, namereplaced=2 },-- missing #s "S1" to "S9"
[550] = { pset={ 357-7, [3]=355-5 }, namereplaced=7 },
[460] = { namereplaced=7 },
[360] = { namereplaced=5 },
[250] = { namereplaced=4 },
[180] = { namereplaced=5 },
[140] = { pset={ [3]=306-2 }, failed= { [3]=2 }, namereplaced=5 },--fail 2 Fehldruck
[139] = { namereplaced=2 },
[110] = { pset={ 302-7-9 }, namereplaced=1 }, -- 7 empty cards on page, 9 missing entirely
[100] = { pset={ 241 } },
-- Expansions
[813] = { pset={ LHpi.Data.sets[813].cardcount.both-5, [3]=LHpi.Data.sets[813].cardcount.reg-5 }, failed={ 5, [3]=LHpi.Data.sets[813].cardcount.tok+5 }, namereplaced=10 },-- -5 Intro Deck variants
[806] = { pset={ [3]=171-6 }, failed= { [3]=6 } }, -- -6 is tokens
[802] = { namereplaced=6 },
[800] = { pset={ LHpi.Data.sets[800].cardcount.both-1,[3]=LHpi.Data.sets[800].cardcount.both-1}, failed={ 1 }, namereplaced=8 },
[795] = { pset={ [3]=157-1 }, failed= { [3]=1 }, namereplaced=1 }, -- -1 is token
[793] = { namereplaced=1 },
[791] = { pset={ LHpi.Data.sets[791].cardcount.both-1,[3]=LHpi.Data.sets[791].cardcount.both-1}, failed={ 1 } },
[786] = { namereplaced=8 },
[784] = { pset={ 161+1 }, failed={ [3]=1 }, namereplaced=8 }, --+1 is Checklist
[782] = { pset={ 276+1 }, failed={ [3]=1 }, namereplaced=9 }, -- +1/fail is Checklist
[776] = { namereplaced=2 },
[773] = { failed={ 1, [3]=1 }, namereplaced=6 }, -- fail is Poison Counter
[767] = { namereplaced=3 },
[765] = { namereplaced=2 },
[762] = { namereplaced=1 },
[756] = { namereplaced=2 },
[754] = { namereplaced=3 },
[751] = { namereplaced=12 },
[730] = { namereplaced=6 },
[710] = { namereplaced=4 },
[700] = { namereplaced=4 },
[690] = { dropped=954, namereplaced=5 },
[680] = { dropped=378, namereplaced=5 },
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
[450] = { pset={ LHpi.Data.sets[450].cardcount.reg-3, [3]=LHpi.Data.sets[450].cardcount.reg-3 }, failed={ 3 } },-- 3 alt art versions missing
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
[812] = { foiltweaked=2 },
[807] = { pset={ LHpi.Data.sets[807].cardcount.all }, namereplaced=3 },
[805] = { namereplaced=2 },
[801] = { pset={ LHpi.Data.sets[801].cardcount.reg }, failed={ LHpi.Data.sets[801].cardcount.repl }, namereplaced=4 },
[796] = { namereplaced=5 },
[794] = { foiltweaked=2 },
[790] = { foiltweaked=2 },
[785] = { namereplaced=3, foiltweaked=2 },
[772] = { namereplaced=1, foiltweaked=0 },
[757] = { foiltweaked=2 },
[600] = { namereplaced=9, foiltweaked=1 },
[320] = { namereplaced=6 },
[310] = { namereplaced=2 },
[260] = { pset={ 228-6-7,[3]=228-6-7 }, failed={ 6+7, [3]=7 }, namereplaced=4 },-- no(6) DG, no(7) ST variants (also ma:no GER "DG")
[200] = { namereplaced=2 },
	}--end table site.expected
end--function site.SetExpected
ma.Log(site.scriptname .. " loaded.")
--EOF