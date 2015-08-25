--*- coding: utf-8 -*-
--[[- LHpi magicuniverse.de sitescript 
Price import script for Magic Album
uses and needs LHpi library
to import card pricing from www.magicuniverse.de.

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
2.13.5.14
addded 813
2.14.5.14
removed url to filename changes that are done by the library if OFFLINE 
2.15.6.14
synchronized with template
fixed/updated site.regex

merged back into mkm branch
]]

-- options unique to this site
--- for magicuniverse.de, parse 10% lower Stammkunden-Preis instead of default price (the one sent to the Warenkorb)
-- @field #boolean STAMMKUNDE
--local STAMMKUNDE = true

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
--OFFLINE = true--download from dummy, only change to false for release

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
local scriptname = "LHpi.magicuniverseDE-v" .. libver .. "." .. dataver .. "." .. scriptver .. ".lua"
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
site.regex = '<tr>%s+<td align="center">%s+%b<>%b<>%s+%b<>%b<>%b<>%s+%b<>%b<>%s+(.-)%s+%b<>%s+</td>%s+</tr>'

--- @field #string currency		not used yet
site.currency = "€"
--- @field #string encoding
site.encoding = "cp1252"

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
	site.domain = "www.magicuniverse.de/html/"
	site.file = "magic.php?startrow=1"
	site.setprefix = "&edition="
	site.frucprefix = "&rarity="
	if "list"==setid then
		return site.domain .. "einzelkarten.php?menue=magic"
	end

	local container = {}
	local url = site.domain .. site.file .. site.setprefix .. site.sets[setid].url .. site.frucprefix .. site.frucs[frucid].url
	container[url] = {}
	
	if string.find( url , "[Ff][Oo][Ii][Ll]" ) then -- mark url as foil-only
		container[url].foilonly = true
	else
		-- url without foil marker
	end -- if foil-only url
	return container
end -- function site.BuildUrl

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
	local setregex = '<table cellpadding=0 cellspacing=0[^>]->(.-)</table>'
	local expansions = { }
	local i=0
	for found in string.gmatch( expansionSource , setregex) do
		i=i+1
		_,_,name = string.find(found,'<b> ?&nbsp; ?(.+)</font>')
		name = string.gsub(name,"&nbsp;"," ")
		name = string.gsub(name,"%b<>","")
		name= string.gsub(name," +"," ")
		_,_,url = string.find(found,"&edition=([^&]+)")
		table.insert(expansions, { name=name, urlsuffix=LHpi.OAuthEncode(url)} )
	end
	LHpi.Log(i.." expansions found" ,1)
	return expansions
end--function site.FetchExpansionList
--[[- format string to use in dummy.ListUnknownUrls update helper function.
 @field [parent=#site] #string updateFormatString ]]
site.updateFormatString = "[%i]={id = %3i, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = %q},--%s"

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
	local newCard = { names = { [1] = nameE ,	[3] = nameG }, price = price }
	LHpi.Log( "site.ParseHtmlData\t returns" .. LHpi.Tostring(newCard) , 2)
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
	
	-- probably need this to correct "die beliebtesten X der letzen Tage" entries 
	--card.name = string.gsub( card.name , "?" , "'")
	
	-- seperate "(alpha)" and beta from beta-urls
	if setid == 90 then -- importing Alpha
		if string.find( card.name , "%([aA]lpha%)" ) then
			card.name = string.gsub( card.name , "%s*%([aA]lpha%)" , "" )
		else -- not "(alpha")
			card.name = card.name .. "(DROP not alpha)" -- change name to prevent import
		end
	elseif setid == 100 then -- importing Beta
		if string.find( card.name , "%([aA]lpha%)" ) then
			card.name = card.name .. "(DROP not beta)" -- change name to prevent import
		else -- not "(alpha")
			card.name = string.gsub( card.name , "%s*%(beta%)" , "" ) -- catch needlessly suffixed rawdata
			card.name = string.gsub( card.name , "%(beta, " , "(") -- remove beta infix from condition descriptor
		end
	end -- if setid
	
	-- mark condition modifier suffixed cards to be dropped
	card.name = string.gsub( card.name , "%([mM]int%)$" , "%0 (DROP)" )
	card.name = string.gsub( card.name , "%(near [mM]int%)$" , "%0 (DROP)" )
	card.name = string.gsub(card. name , "%([eE]xce[l]+ent%)$" , "%0 (DROP)" )
	card.name = string.gsub(card.name , "%(light played%)$" , "%0 (DROP)" )
	card.name = string.gsub(card.name , "%(light plaxed%)$" , "%0 (DROP)" )
	card.name = string.gsub( card.name , "%([lL][pP]%)$" , "%0 (DROP)" )
	card.name = string.gsub( card.name , "%(light played[/%-|][Pp]layed%)" , "%0 (DROP)" )
	card.name = string.gsub( card.name , "%([lL][pP]/[pP]%)$" , "%0 (DROP)" )
	card.name = string.gsub( card.name , "%(played[/%-|]light played%)" , "%0 (DROP)" )
	card.name = string.gsub( card.name , "%(played[/|]played%)$" , "%0 (DROP)" )
	card.name = string.gsub( card.name , "%(played%)$" , "%0 (DROP)" )
	card.name = string.gsub( card.name , "%([pP]%)$" , "%0 (DROP)" )
	card.name = string.gsub( card.name , "%(poor%)$" , "%0 (DROP)" )
	card.name = string.gsub( card.name , "%(knick%)$" , "%0 (DROP)" )
	card.name = string.gsub( card.name , "%(geknickt%)$" , "%0 (DROP)" )
	card.name = string.gsub( card.name , "signed%)$" , "%0 (DROP)" )
	card.name = string.gsub( card.name , "signiert%)$" , "%0 (DROP)" )
	card.name = string.gsub( card.name , "signiert!%)$" , "%0 (DROP)" )
	card.name = string.gsub( card.name , "signiert!$" , "%0 (DROP)" )
	card.name = string.gsub( card.name , "unterschrieben%)$" , "%0 (DROP)" )
	card.name = string.gsub( card.name , "unterschrieben, excellent%)$" , "%0 (DROP)" )
	card.name = string.gsub( card.name , "light played$" , "%0 (DROP)" )
	card.name = string.gsub( card.name , "%(lp %- played%)" , "%0 (DROP)" )
	card.name = string.gsub( card.name , "%(lp%) %(ia%)$" , "%0 (DROP)" )

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
function site.BCDpluginPost( card , setid, importfoil, importlangs )
	LHpi.Log( "site.BCDpluginPost got " .. LHpi.Tostring( card ) .. " from set " .. setid ,2)
	
	-- special case
	if setid == 140 then -- Revised
		if card.name == "Schilftroll (Fehldruck, deutsch)" then
			card.lang = { [3]="GER" }
			card.name = "Manabarbs"
		end
		if string.find( card.name , "%(französisch%)") then
			card.name = string.gsub( card.name , "%s*%(französisch%)%s*" , "" )
			card.lang = { [4]="FRA" }
			card.regprice = { [4] = card.regprice[1] }
		end
	elseif setid == 180 then -- 4th Edition
		if card.name == "Warp Artifact (FEHLDRUCK)" then
			card.lang = { [3]="GER" }
--			card.name = "El-Hajjâj"
		end
	elseif setid == 150 then -- Legends
		if string.find( card.name , "%(ital%.?%)" ) then
			card.name = string.gsub( card.name , "%s*%(ital%.?%)%s*" , "" )
			card.lang = { [5] = "ITA" }
			card.regprice = { [5] = card.regprice[1] }
		end
			card.name = string.gsub( card.name , "%s*%(LG%)" , "" )
	end -- if setid

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
	[1] = { id=1, url="" },
	[3] = { id=3, url="" },
	[4] = { id=4, url="" },
	[5] = { id=5, url="" },
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
	[1]= { id=1, name="Foil"   	, isfoil=true , isnonfoil=false, url="Foil"		},
	[2]= { id=2, name="Rare"   	, isfoil=false, isnonfoil=true , url="Rare"		},
	[3]= { id=3, name="Uncommon", isfoil=false, isnonfoil=true , url="Uncommon"	},
	[4]= { id=4, name="Common"	, isfoil=false, isnonfoil=true , url="Common"	},
	[5]= { id=5, name="Purple"	, isfoil=false, isnonfoil=true , url="Purple"	},
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
[822]={id = 822, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Magic%20Origins"},--Magic Origins
[808]={id = 808, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "M2015"},
[797]={id = 797, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "M2014"}, 
[788]={id = 788, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "M2013"}, 
[779]={id = 779, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "M2012"}, 
[770]={id = 770, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "M2011"}, 
[759]={id = 759, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "M2010"}, 
[720]={id = 720, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "10th_Edition"}, 
[630]={id = 630, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "9th_Edition"}, 
[550]={id = 550, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "8th_Edition"}, 
[460]={id = 460, lang = { true , [3]=true }, fruc = { false,true ,true ,false}, url = "7th_Edition"}, 
[180]={id = 180, lang = { true , [3]=true }, fruc = { false,true ,true ,false}, url = "4th_Edition"}, 
[140]={id = 140, lang = { true , [3]=true , [4]=true }, fruc = { false,true ,true ,true }, url = "Revised"},
[139]={id = 139, lang = { false, [3]=true }, fruc = { false,true ,true ,true }, url = "deutsch_limitiert"},-- Revised Limited : url only provides cNameG
[110]={id = 110, lang = { true , [3]=false}, fruc = { false,true ,true ,true }, url = "Unlimited"}, 
[100]={id = 100, lang = { true , [3]=false}, fruc = { false,true ,true ,true }, url = "Beta"}, 
[90] ={id =  90, lang = { true , [3]=false}, fruc = { false,true ,true ,true }, url = "Beta"}, -- Alpha in Beta with "([Aa]lpha)" suffix
 -- Expansions
[813]={id = 813, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Khans%20of%20Tarkir"},
[806]={id = 806, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Journey%20into%20Nyx"},
[802]={id = 802, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Born%20of%20the%20Gods"},
[800]={id = 800, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Theros"},
[795]={id = 795, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Dragons%20Maze"},
[793]={id = 793, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Gatecrash"},
[791]={id = 791, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Return%20to%20Ravnica"},
[786]={id = 786, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Avacyn%20Restored"},
[784]={id = 784, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Dark%20Ascension"}, 
[782]={id = 782, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Innistrad"}, 
[776]={id = 776, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "New%20Phyrexia"},
[775]={id = 775, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Mirrodin%20Besieged"},
[773]={id = 773, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Scars%20of%20Mirrodin"},
[767]={id = 767, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Rise%20of%20the%20Eldrazi"},
[765]={id = 765, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Worldwake"},
[762]={id = 762, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Zendikar"},
[758]={id = 758, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Alara%20Reborn"},
[756]={id = 756, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Conflux"},
[754]={id = 754, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Shards%20of%20Alara"},
[752]={id = 752, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Eventide"},
[751]={id = 751, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Shadowmoor"},
[750]={id = 750, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Morningtide"},
[730]={id = 730, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Lorwyn"},
[710]={id = 710, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Future_Sight"},
[700]={id = 700, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Planar_Chaos"},
 -- for Timeshifted and Timespiral, lots of expected fails due to shared foil url
[690]={id = 690, lang = { true , [3]=true }, fruc = { true ,false,false,false,true }, url = "Time_Spiral"}, -- Timeshifted
[680]={id = 680, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Time_Spiral"},
[670]={id = 670, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Coldsnap"},
[660]={id = 660, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Dissension"},
[650]={id = 650, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Guildpact"},
[640]={id = 640, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Ravnica"},
[620]={id = 620, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Saviors_of_Kamigawa"},
[610]={id = 610, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Betrayers_of_Kamigawa"},
[590]={id = 590, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Champions_of_Kamigawa"},
[580]={id = 580, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "5th_Dawn"},
[570]={id = 570, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Darksteel"},
[560]={id = 560, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Mirrodin"},
[540]={id = 540, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Scourge"},
[530]={id = 530, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Legions"},
[520]={id = 520, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Onslaught"},
[510]={id = 510, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Judgment"},
[500]={id = 500, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Torment"},
[480]={id = 480, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Odyssey"},
[470]={id = 470, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Apocalypse"},
[450]={id = 450, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Planeshift"},
[430]={id = 430, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Invasion"},
[420]={id = 420, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Prophecy"},--not really foil, but card "Foil" ("Durchkreuzen")
[410]={id = 410, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Nemesis"},
[400]={id = 400, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Merkadische_Masken"},
[370]={id = 370, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Urzas_Destiny"},
[350]={id = 350, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Urzas_Legacy"},
[330]={id = 330, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Urzas_Saga"},
[300]={id = 300, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Exodus"},
[290]={id = 290, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Stronghold"},
[280]={id = 280, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Tempest"},
[270]={id = 270, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Weatherlight"},
[240]={id = 240, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Vision"},
[230]={id = 230, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Mirage"},
[220]={id = 220, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Alliances"},
[210]={id = 210, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Homelands"},
[190]={id = 190, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Ice_Age"},
[170]={id = 170, lang = { true , [3]=false}, fruc = { false,true ,true ,true }, url = "Fallen_Empires"},
[160]={id = 160, lang = { true , [3]=false}, fruc = { false,true ,true ,true }, url = "The_Dark"},
[150]={id = 150, lang = { true , [3]=false, [5]=true }, fruc = { false,true ,true ,true }, url = "Legends"},
[130]={id = 130, lang = { true , [3]=false}, fruc = { false,true ,true ,true }, url = "Antiquities"},
[120]={id = 120, lang = { true , [3]=false}, fruc = { false,true ,true ,true }, url = "Arabian_Nights"},
-- Special sets
[818]={id = 818, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Dragons%20of%20Tarkir"},--Dragons of Tarkir
[816]={id = 816, lang = { true , [3]=true }, fruc = { true ,true ,true ,true }, url = "Fate%20Reforged"},--Fate Reforged
[814]={id = 814, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Commander%202014"},
[807]={id = 807, lang = { true , [3]=false}, fruc = { false,true ,true ,true }, url = "Conspiracy"},
[801]={id = 801, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Commander%202013"},
--TODO Promo Cards (when settweak is in lib)
-- uncomment these while running helper.FindUnknownUrls
--[999]={id = 0, lang = { true , [3]=true }, fruc = { false,true ,true ,true }, url = "Foils"},--miscelaneous Promos
} -- end table site.sets

--[[- card name replacement tables.

  fields are for subtables indexed by #number setid.
 { #number (setid)= #table { #string (oldname)= #string (newname), ... } , ... }
 
 @type site.namereplace
 @field [parent=#site.namereplace] #string name
]]
site.namereplace = {
[808] = { -- M20155
["Token - Beast (B)"] 					= "Beast Token (5)";
["Token - Beast (G)"] 					= "Beast Token (9)";
["Emblem - Ajani"]						= "Ajani Steadfast Emblem";
["Emblem - Garruk"]						= "Garruk, Apex Predator Emblem"
},
[797] = { -- M2014
["Token - Elemental (R) (7)"] 			= "Elemental Token (7)";
["Token - Elemental (R) (8)"] 			= "Elemental Token (8)";
["Emblem: Liliana o. t. Dark Realms"]	= "Emblem: Liliana of the Dark Realms"
},
[788] = { -- M2013
["Emblem: Liliana o. t. Dark Realms"]	= "Emblem: Liliana of the Dark Realms"
},
[770] = { --M2011
["Token - Ooze (G) - (2)"]				= "Ooze Token (5)",
["Token - Ooze (G) - (1)"]				= "Ooze Token (6)",
},
[140] = { -- Revised
["Serendib Efreet (Fehldruck)"] 		= "Serendib Efreet",
["Pearl Unicorn"] 						= "Pearled Unicorn",
["Monss Goblin Raiders"] 				= "Mons's Goblin Raiders",
["El-Hajjâj"]							= "El-Hajjaj",
},
[139] = { -- Revised Limited (german)
["Schwarzer Ritus (Dark Ritual)"] 		= "Schwarzer Ritus",
["Goblinkönig"]							= "Goblin König",
["Bengalische Heldin"] 					= "Benalische Heldin",
["Advocatus Diaboli"] 					= "Advokatus Diaboli",
["Zersetzung (Desintegrate)"] 			= "Zersetzung",
["Leibwächter d. Veteranen"] 			= "Leibwächter des Veteranen",
["Stab des Verderbens"] 				= "Stab der Verderbnis",
["Der schwarze Tot"] 					= "Der Schwarze Tod",
["Rückkopplung"] 						= "Rückkoppelung",
["Armageddon-Uhr"] 						= "Armageddonuhr",
["Gaeas Vasall"] 						= "Gäas Vasall",
["Bogenschützen der Elfen"] 			= "Bogenschütze der Elfen",
["Ornithropher"] 						= "Ornithopter",
["Granitgargoyle"] 						= "Granit Gargoyle",
["Inselfisch Jaskonius"] 				= "Inselfisch Jasconius",
["Hypnotiserendes Gespenst"] 			= "Hypnotisierendes Gespenst",
["Mons Plündernde Goblins"]				= "Mons’ plündernde Goblins",
["Ketos? Zauberbuch"]					= "Ketos Zauberbuch",
["Jandors Satteltaschen"]				= "Jandors Satteltasche"
},
[110] = { -- Unlimited
["Will-o-The-Wisp"] 					= "Will-O’-The-Wisp"
},
[100] = { -- Beta (shares urls with Alpha)
["Time Walk (alpha, near mint)"]		= "Time Walk (alpha)(near mint)"
},
[90] = { -- Alpha
["Time Walk (alpha, near mint)"]		= "Time Walk (alpha)(near mint)"
},
[813] = { --Khans of Tarkir
["Token - Warrior (3) (W)"]				= "Warrior Token (3)",
["Token - Warrior (4) (W)"]				= "Warrior Token (4)",
["Emblem: Sarkhan"]						= "Sarkhan, the Dragonspeaker Emblem",
["Emblem: Sorin"]						= "Sorin, Solemn Visitor Emblem",
},
[806] = { -- Journey into Nyx
["Token - Snake (SPT)"]					= "Snake Token",
["Token - Ophis (SPT)"]					= "Ophis Token",
["Token - Spinx (U)"]					= "Sphinx Token",
},
[802] = { -- Born of the Gods
["Unravel the Æther"] 					= "Unravel the AEther",
["Token - Bird (W)"]					= "Bird Token (1)",
["Token - Bird (U)"]					= "Bird Token (4)",
},
[800] = { -- Theros
["Token - Soldier (R)"]					= "Soldier Token (3)",
["Token - Soldier (2) (W)"]				= "Soldier Token (2)",
["Token - Soldier (3) (W)"]				= "Soldier Token (7)",
["Emblem - Elspeth, Suns Champion"]		= "Emblem - Elspeth, Sun's Champion",
},
[793] = { -- Gatecrash
["Emblem: Domrirade"] 					= "Emblem: Domri Rade"
},
[786] = { -- Avacyn Restored
["Emblem: Tamiyo, the Moonsage"]		= "Emblem Tamiyo, the Moon Sage",
["Token - Spirit (W)"]					= "Spirit Token (3)",
["Token - Spirit (U)"]					= "Spirit Token (4)",
["Token - Human (W)"]					= "Human Token (2)",
["Token - Human (R)"]					= "Human Token (7)",
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
["Token - Zombie (B) (7)"]				= "Zombie Token (7)",
["Token - Zombie (B) (8)"]				= "Zombie Token (8)",
["Token - Zombie (B) (9)"]				= "Zombie Token (9)",
["Token - Wolf (B)"]					= "Wolf Token (6)",
["Token - Wolf (G)"]					= "Wolf Token (12)",
["Doublesidedcards-Checklist"]			= "Checklist"
},
[775] = { -- Mirrodin Besieged
["Token - Poisoncounter"]				= "Poison Counter Token"
},
[773] = { -- Scars of Mirrodin
["Token - Wurm (Art) (Deathtouch)"] 	= "Wurm Token (8)",
["Token - Wurm (Art) (Lifelink)"] 		= "Wurm Token (9)",
["Token - Poisoncounter"]				= "Poison Counter Token"
},
[767] = { -- Rise of the Eldrazi
["TOKEN - Eldrazi Spawn (Vers. A)"] 	= "Eldrazi Spawn Token (1a)",
["TOKEN - Eldrazi Spawn (Vers. B)"] 	= "Eldrazi Spawn Token (1b)",
["TOKEN - Eldrazi Spawn (Vers. C)"] 	= "Eldrazi Spawn Token (1c)",
},
[762] = { -- Zendikar
["Token - Meerfolk (U)"] 				= "Merfolk Token (U)",
},
[751] = { -- Shadowmoor
["Token - Elf, Warrior (G)"]			= "Elf Warrior Token (5)",
["Token - Elf Warrior (G|W)"]			= "Elf Warrior Token (12)",
["Token - Elemental (R)"] 				= "Elemental Token (4)",
["Token - Elemental (B|R)"] 			= "Elemental Token (9)",
},
[750] = { -- Morningtide
["Token - Faery Rogue"]					= "Faerie Rogue Token"
},
[730] = { -- Lorwyn
["Token - Elf, Warrior (G)"] 			= "Elf Warrior Token (G)",
["Token - Kithkin, Soldier (W)"] 		= "Kithkin Soldier Token (W)",
["Token - Meerfolk Wizard (U)"] 		= "Merfolk Wizard Token (U)",
["Token - Elemental (W)"] 				= "Elemental Token (2)",
["Token - Elemental (G)"]	 			= "Elemental Token (8)",
},
[680] = { -- Time Spiral
["Lim-Dul the Necromancer"]				= "Lim-Dûl the Necromancer"
},
[670] = { -- Coldsnap
["Surging Aether"]						= "Surging Æther"
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
["Erayo, Soratami Ascendant"] 			= "Erayo, Soratami Ascendant|Erayo’s Essence",
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
["Akki Lavarunner"]						= "Akki Lavarunner|Tok-Tok, Volcano Born",
["Brothers Yamazaki"]					= "Brothers Yamazaki (160a)",
["Brothers Yamazaki (b)"]				= "Brothers Yamazaki (160b)",
},
[560] = { -- Mirrodin
["Goblin Warwagon"]						= "Goblin War Wagon",
},
[500] = { -- Torment
["Chainers Edict"]						= "Chainer's Edict",
},
[220] = { -- Alliances
["Lim-Dul's Vault"]						= "Lim-Dûl's Vault",
["Lim-Dul's Paladin"]					= "Lim-Dûl's Paladin",
["Lim-Dul's High Guard"]				= "Lim-Dûl's High Guard",
},
[120] = { -- Arabian Nights
["Ring of Ma'rûf"] 						= "Ring of Ma ruf",
["El-Hajjâj"]							= "El-Hajjaj",
["Dandân"]								= "Dandan",
["Ghazbán Ogre"]						= "Ghazban Ogre",
},
-- special sets
[807] = {
["Adventageous Proclamation"]			= "Advantageous Proclamation",
},
[801] = {
["Kongming, 'Sleeping Dragon'"]			= "Kongming, “Sleeping Dragon”",
["Sek'Kuar, Deathkeeper"]				= "Sek’Kuar, Deathkeeper",
["Sek'Kuar, Deathkeeper (Oversized)"]	= "Sek’Kuar, Deathkeeper (oversized)",
["Jeleva, Nephalia's Scourge"]			 = "Jeleva, Nephalia’s Scourge",
["Jeleva, Nephalia's Scourge (Oversized)"] = "Jeleva, Nephalia’s Scourge (oversized)",
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
[100] = { -- Beta
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
[762] = { -- Zendikar
override=true,
["Plains - Vollbild"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
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
[450] = { --Planeshift
override=true,
},
[130] = { -- Antiquities
override=true,
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
override=true,
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
[808] = {pset={ LHpi.Data.sets[808].cardcount.both-15, [3]=LHpi.Data.sets[808].cardcount.reg-15 }, failed={[3]=LHpi.Data.sets[808].cardcount.tok}, namereplaced=4 },-- -15 extra cards (nr. 270 - 284)
[797] = { namereplaced=3 },
[788] = { namereplaced=1 },
[770] = { namereplaced=2 },
[720] = { pset={ LHpi.Data.sets[720].cardcount.both-1,[3]=LHpi.Data.sets[720].cardcount.both-2 }, failed={ 1,[3]=2 } },
[630] = { pset={ 359-20, [3]=359-20-7 }, failed={ [3]=7 } },
[550] = { pset={ 357-19, [3]=357-19-2 }, failed={ 3, [3]=2+3 } },-- 3 foil swamps missing
[460] = { pset={ 350-130, [3]=350-130 }, dropped=2 }, --no commons
[180] = { pset={ 378-136-2, [3]=378-136-2 }, dropped=2, failed={[3]=1} }, --no commons
[140] = { pset={ LHpi.Data.sets[140].cardcount.reg-1, [3]=47, [4]=1 }, dropped=202, namereplaced=4 },-- ENG missing Counterspell
[139] = { dropped=9, namereplaced=19 },
[110] = { pset={ 302-24 }, dropped=106, namereplaced=1 },
[100] = { pset={ 302-134 },	failed={ 8 }, dropped=352, namereplaced=1 },
[90]  = { pset={ 295-61 }, dropped=293,},
-- Expansions
[813] = { pset={ LHpi.Data.sets[813].cardcount.both-5, [3]=LHpi.Data.sets[813].cardcount.reg-5 }, failed={ 5, [3]=LHpi.Data.sets[813].cardcount.tok+5}, namereplaced=4 },-- -5 Intro Deck variants
[806] = { pset={ [3]=165 }, failed={ [3]=6}, namereplaced=2 },--GER tokens 
[802] = { namereplaced=4 },
[800] = { pset={ LHpi.Data.sets[800].cardcount.both-1,[3]=LHpi.Data.sets[800].cardcount.both-1 }, failed={ 1,[3]=1 }, namereplaced=4 },
[795] = { pset={ [3]=157-1 }, failed ={ [3]=1} }, -- -1/fail is elemental token
[793] = { namereplaced=1 },
[791] = { pset={ LHpi.Data.sets[791].cardcount.both-1,[3]=LHpi.Data.sets[791].cardcount.both-1 }, failed={ 1,[3]=1 } },
[786] = { namereplaced=5 },
[784] = { pset={ 161+1 }, failed={ [3]=1 }, namereplaced=27 },-- +1/fail is checklist
[782] = { pset={ 276+1 }, failed={ [3]=1}, namereplaced=46 },-- +1/fail is checklist
[775] = { failed={ 1, [3]=1 }, namereplaced=1 },-- fail is Poison Counter
[773] = { failed={ 1, [3]=1 }, namereplaced=3 },-- fail is Poison Counter
[767] = { namereplaced=3 },
[762] = { pset={ LHpi.Data.sets[762].cardcount.both-20,[3]=LHpi.Data.sets[762].cardcount.both-20 }, namereplaced=1 },
[751] = { namereplaced=4 },
[750] = { namereplaced=1 },
[730] = { namereplaced=5 },
[690] = { failed={ 299,[3]=299 } },
[680] = { failed={ 121,[3]=121 }, namereplaced=2 },
[670] = { namereplaced=1 },
[640] = { namereplaced=5 },
[620] = { namereplaced=5 },
[610] = { namereplaced=5 },
[590] = { pset={ 307-20, [3]=307-20 }, namereplaced=12 },
[570] = { dropped=1 },
[560] = { pset={ 306-20, [3]=306-20 }, namereplaced=1 },
[520] = { pset={ 350-20, [3]=350-20 }, dropped=3 },
[500] = { namereplaced=1, dropped=1 },
[480] = { pset={ 350-20, [3]=350-20 }, dropped=1 },
[450] = { pset={ 146-3, [3]=146-3 } },-- 3 alt art versions missing
[430] = { pset={ 350-20, [3]=350-20 } },
[370] = { dropped=2 },
[330] = { dropped=2 },
[300] = { dropped=1 },
[290] = { dropped=2 },
[280] = { dropped=2 },
[220] = { namereplaced=3 },
[190] = { pset={ 383-3, [3]=383-3 }, dropped=1 },-- -3 plains
[160] = { dropped=9 },
[150] = { pset={ [5]=19 }, dropped=87 },
[130] = { dropped=54 },
[120] = { pset={ LHpi.Data.sets[120].cardcount.reg-1 }, failed={ 1 }, namereplaced=4 },
-- special sets
[807] = { pset={ LHpi.Data.sets[807].cardcount.all }, namereplaced=1},
[801] = { pset={ LHpi.Data.sets[801].cardcount.all, [3]=LHpi.Data.sets[801].cardcount.all }, foiltweaked=15, namereplaced=5 },
	}--end table site.expected
end--function site.SetExpected()
ma.Log(site.scriptname .. " loaded.")
--EOF