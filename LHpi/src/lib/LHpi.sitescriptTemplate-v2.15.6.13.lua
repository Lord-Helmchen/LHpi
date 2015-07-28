--*- coding: utf-8 -*-
--[[- LHpi sitescript template 
Template to write new sitescripts for LHpi library

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
2.14.5.12
removed url to filename changes that are done by the library if OFFLINE
2.15.6.13
script configuration variables local instead of global
workdir support
site.LoadLib split from ImportPrice
site.Initialize loads LHpi lib if not yet available (needed if ImportPrice is not called)
keep LHpi library table if already present
no longer check for lib and Data in deprecated location
removed site.CompareSiteSets
optional site.BuildUrl("list") behaviour
new optional function site.FetchExpansionList
site.BuildUrl supports multiple urls per set

merged back into mkm branch
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
local scriptver = "13"
--- should be similar to the script's filename. Used for loging and savepath.
-- @field #string scriptname
local scriptname = "LHpi.sitescriptTemplate-v" .. libver .. "." .. dataver .. "." .. scriptver .. ".lua"
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
--site.regex = ''

--- resultregex can be used to display in the Log how many card the source file claims to contain
-- @field #string resultregex
--site.resultregex = "Your query of .+ filter.+ returns (%d+) results."

--- pagenumberregex can be used to check for unneeded calls to empty pages
-- see site.BuildUrl in LHpi.mtgmintcard.lua for working example of a multiple-page-setup. 
-- @field #string pagenumberregex
--site.pagenumberregex = "page=(%d+)"

--- @field #string currency		not used yet;default "$"
--site.currency = "$"
--- @field #string encoding		default "cp1252"
--site.encoding="cp1252"

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

--	-- if you need to load additional files, you can try this:
--	-- as long as Magic Album's lua api does not allow the "package" standard library, try a workaround:
--	if not require then
--		LHpi.Log("trying to work around Magic Album lua sandbox limitations...")
--		--emulate require(modname) using dofile; only works for lua files, not dlls.
--		local packagePath = 'Prices\\lib\\ext\\'
--		require = function (fname)
--			local donefile
--			donefile = dofile( packagePath .. fname .. ".lua" )
--			return donefile
--		end-- function require
--	else
--		package.path = 'Prices\\lib\\ext\\?.lua;' .. package.path
--		package.cpath= 'Prices\\lib\\bin\\?.dll;' .. package.cpath
--		--print(package.path.."\n"..package.cpath)
--	end
	
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
--function site.BuildUrl( setid,langid,frucid,offline )
--	site.domain = "www.example.com"
--	site.file = "magic.php"
--	site.setprefix = "&edition="
--	site.langprefix = "&language="
--	site.frucprefix = "&rarity="
--	site.suffix = ""
--	
--	local url = site.domain .. site.file
--	if setid=="list" then --return url to get a list of available expansions
--		return url .. "&expansions"
--	end
--	-- usual LHpi behaviour
--	url = url .. site.setprefix
--	if  type(site.sets[setid].url) == "table" then
--		urls = site.sets[setid].url
--	else
--		urls = { site.sets[setid].url }
--	end--if type(site.sets[setid].url)
--	for _i,seturl in pairs(urls) do
--		seturl = url .. seturl .. site.langprefix .. site.langs[langid].url .. site.frucprefix .. site.frucs[frucid].url .. site.suffix
--		local details = {}
--		if site.frucs[frucid].isfoil and not site.frucs[frucid].isnonfoil then
--			detals.foilonly = true
--		end--if
--	
--		--LHpi.GetDourceData already does:
--		--if OFFLINE then
--		--	--seturl = string.gsub(seturl, '[/\\:%*%?<>|"]', "_")
--		--	--details.isfile = true
--		--end -- if OFFLINE
--		--if not details.isfile then
--		--	seturl = "http://" .. seturl
--		--end -- if isfile
--		
--	container[seturl] = details
--	end--for
--	return container
--end -- function site.BuildUrl

--[[- fetch list of expansions to be used by update helper functions.
 The returned table shall contain at least the sets' name and LHpi-comnpatible urlsuffix,
 so it can be processed by dummy.ListUnknownUrls.
 Implementing this function is optional and may not be possible for some sites.
 @function [parent=#site] FetchExpansionList
 @return #table  @return #table { #number= #table { name= #string , urlsuffix= #string , ... }
]]
function site.FetchExpansionList()
--	if OFFLINE then
--		LHpi.Log("OFFLINE mode active. Expansion list may not be up-to-date." ,1)
--	end
--	local expansionSource
--	local url = site.BuildUrl( "list" )
--	expansionSource = LHpi.GetSourceData ( url , urldetails )
--	if not expansionSource then
--		error(string.format("Expansion list not found at %s (OFFLINE=%s)",LHpi.Tostring(url),tostring(OFFLINE)) )
--	end
	-- parse expansion source and build the table here
	
	-- This implementation is only to help updating the template.
	-- You should probably delete it and implement it for the site if you want to use the update helper mode.
	local expansionSource = dummy.mergetables ( dummy.coresets, dummy.expansionsets, dummy.specialsets, dummy.promosets )
	local expansions = {}
	for sid,name in pairs(expansionSource) do
		expansions[sid]={name=name, urlsuffix = LHpi.OAuthEncode(name)}
	end

	return expansions
end--function site.FetchExpansionList
--[[- format string to use in dummy.ListUnknownUrls update helper function.
 @field [parent=#site] #string updateFormatString ]]
site.updateFormatString = "[%i]={id=%3i, lang = { [1]=true }, fruc = { true , true }, url = %q},--%s"

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
--function site.ParseHtmlData( foundstring , urldetails )
--	local container={}
--	
--	--you need to split foundstring into its fields here
--	local foundnames = {}
--	local foundPrice = 0
--	local foundFoil = false
--	--then assemble the new card data
--	foundprice = string.gsub(foundprice , "[,.]" , "" ) -- return price as integer
--	local newCard= { names=foundNames , price=foundPrice , foil=foundFoil }
--	
--	--wrap (all) the card(s) into a container table
--	container = { newCard }
--	return container
--end -- function site.ParseHtmlData

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
--	LHpi.Log( "site.BCDpluginPre got " .. LHpi.Tostring( card ) .. " from set " .. setid ,2)
--
--	-- if you don't want a full namereplace table, gsubs like this might take care of a lot of fails.
--	card.name = string.gsub( card.name , "AE" , "Æ")
--	card.name = string.gsub( card.name , "Ae" , "Æ")
--
--	if setid == 25 then -- Judge Gift Cards
--		if card.name == "Elesh Norn, Grand Cenobite" then
--			card.lang = { [17]="PHY" }
--		else
--			card.lang[17] = nil
--		end
--	elseif setid == 22 then -- Prerelease Promos
--		for _,lid in ipairs({12,13,14,15,16}) do
--			card.lang[lid] = nil
--		end
--		if card.name == "Glory" then
--			card.lang = { [12]="HEB"}
--		elseif card.name == "Stone-Tongue Basilisk" then
--			card.lang = { [13]="ARA" }
--		elseif card.name == "Raging Kavu" then
--			card.lang = { [14]="LAT" }
--		elseif card.name == "Fungal Shambler" then
--			card.lang = { [15]="SAN"}
--		elseif card.name == "Questing Phelddagrif" then
--			card.lang = { [16]="GRC" }
--		end
--	end
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
--	LHpi.Log( "site.BCDpluginPost got " .. LHpi.Tostring( card ) .. " from set " .. setid ,2)
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
	[1]  = { id= 1, url="" },--English
--	[2]  = { id= 2, url="" },--Russian
--	[3]  = { id= 3, url="" },--German
--	[4]  = { id= 4, url="" },--French
--	[5]  = { id= 5, url="" },--Italian
--	[6]  = { id= 6, url="" },--Portuguese
--	[7]  = { id= 7, url="" },--Spanish
--	[8]  = { id= 8, url="" },--Japanese
--	[9]  = { id= 9, url="" },--Simplified Chinese
--	[10] = { id=10, url="" },--Traditional Chinese
--	[11] = { id=11, url="" },--Korean
	[12] = { id=12, url="" },-- Only "Glory" in [22] Prerelease Promos
	[13] = { id=13, url="" },-- Only "Stone-Tongue Basilisk" in [22] Prerelease Promos
	[14] = { id=14, url="" },-- Only "Raging Kavu" in [22] Prerelease Promos
	[15] = { id=15, url="" },-- Only "Fungal Shambler" in [22] Prerelease Promos
	[16] = { id=16, url="" },-- Only "Questing Phelddagrif" in [22] Prerelease Promos
	[17] = { id=17, url="" },-- Only "Elesh Norn, Grand Cenobite" in [25] Judge Gift Cards
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
--site.frucs = {
--	[1]= { id=1, name="Foil"	, isfoil=true , isnonfoil=false, url="foil" },
--	[2]= { id=2, name="nonFoil"	, isfoil=false, isnonfoil=true , url="regular" },
--}

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
[822]={id=822, lang = { [1]=true }, fruc = { true , true }, url = "Magic%20Origins"},--Magic Origins
[808]={id=808, lang = { [1]=true }, fruc = { true , true }, url = "Magic%202015"},--Magic 2015
[797]={id=797, lang = { [1]=true }, fruc = { true , true }, url = "Magic%202014"},--Magic 2014
[788]={id=788, lang = { [1]=true }, fruc = { true , true }, url = "Magic%202013"},--Magic 2013
[779]={id=779, lang = { [1]=true }, fruc = { true , true }, url = "Magic%202012"},--Magic 2012
[770]={id=770, lang = { [1]=true }, fruc = { true , true }, url = "Magic%202011"},--Magic 2011
[759]={id=759, lang = { [1]=true }, fruc = { true , true }, url = "Magic%202010"},--Magic 2010
[720]={id=720, lang = { [1]=true }, fruc = { true , true }, url = "Tenth%20Edition"},--Tenth Edition
[630]={id=630, lang = { [1]=true }, fruc = { true , true }, url = "9th%20Edition"},--9th Edition
[550]={id=550, lang = { [1]=true }, fruc = { true , true }, url = "8th%20Edition"},--8th Edition
[460]={id=460, lang = { [1]=true }, fruc = { true , true }, url = "7th%20Edition"},--7th Edition
[360]={id=360, lang = { [1]=true }, fruc = { true , true }, url = "6th%20Edition"},--6th Edition
[250]={id=250, lang = { [1]=true }, fruc = { false, true }, url = "5th%20Edition"},--5th Edition
[180]={id=180, lang = { [1]=true }, fruc = { false, true }, url = "4th%20Edition"},--4th Edition
[179]={id=179, lang = { [1]=true }, fruc = { false, true }, url = "4th%20Edition%20%28FBB%29"},--4th Edition (FBB)
[141]={id=141, lang = { [1]=true }, fruc = { false, true }, url = "Revised%20Edition%20%28Summer%20Magic%29"},--Revised Edition (Summer Magic)
[140]={id=140, lang = { [1]=true }, fruc = { false, true }, url = "Revised%20Edition"},--Revised Edition
[139]={id=139, lang = { [3]=true }, fruc = { false, true }, url = "Revised%20Edition%20%28FBB%29"},--Revised Edition (FBB)
[110]={id=110, lang = { [1]=true }, fruc = { false, true }, url = "Unlimited"},--Unlimited
[100]={id=100, lang = { [1]=true }, fruc = { false, true }, url = "Beta"},--Beta
[90] ={id= 90, lang = { [1]=true }, fruc = { false, true }, url = "Alpha"},--Alpha
-- Expansions
[818]={id=818, lang = { [1]=true }, fruc = { true , true }, url = "Dragons%20of%20Tarkir"},--Dragons of Tarkir
[816]={id=816, lang = { [1]=true }, fruc = { true , true }, url = "Fate%20Reforged"},--Fate Reforged
[813]={id=813, lang = { [1]=true }, fruc = { true , true }, url = "Khans%20of%20Tarkir"},--Khans of Tarkir
[806]={id=806, lang = { [1]=true }, fruc = { true , true }, url = "Journey%20into%20Nyx"},--Journey into Nyx
[802]={id=802, lang = { [1]=true }, fruc = { true , true }, url = "Born%20of%20the%20Gods"},--Born of the Gods
[800]={id=800, lang = { [1]=true }, fruc = { true , true }, url = "Theros"},--Theros
[795]={id=795, lang = { [1]=true }, fruc = { true , true }, url = "Dragon%E2%80%99s%20Maze"},--Dragon’s Maze
[793]={id=793, lang = { [1]=true }, fruc = { true , true }, url = "Gatecrash"},--Gatecrash
[791]={id=791, lang = { [1]=true }, fruc = { true , true }, url = "Return%20to%20Ravnica"},--Return to Ravnica
[786]={id=786, lang = { [1]=true }, fruc = { true , true }, url = "Avacyn%20Restored"},--Avacyn Restored
[784]={id=784, lang = { [1]=true }, fruc = { true , true }, url = "Dark%20Ascension"},--Dark Ascension
[782]={id=782, lang = { [1]=true }, fruc = { true , true }, url = "Innistrad"},--Innistrad
[776]={id=776, lang = { [1]=true }, fruc = { true , true }, url = "New%20Phyrexia"},--New Phyrexia
[775]={id=775, lang = { [1]=true }, fruc = { true , true }, url = "Mirrodin%20Besieged"},--Mirrodin Besieged
[773]={id=773, lang = { [1]=true }, fruc = { true , true }, url = "Scars%20of%20Mirrodin"},--Scars of Mirrodin
[767]={id=767, lang = { [1]=true }, fruc = { true , true }, url = "Rise%20of%20the%20Eldrazi"},--Rise of the Eldrazi
[765]={id=765, lang = { [1]=true }, fruc = { true , true }, url = "Worldwake"},--Worldwake
[762]={id=762, lang = { [1]=true }, fruc = { true , true }, url = "Zendikar"},--Zendikar
[758]={id=758, lang = { [1]=true }, fruc = { true , true }, url = "Alara%20Reborn"},--Alara Reborn
[756]={id=756, lang = { [1]=true }, fruc = { true , true }, url = "Conflux"},--Conflux
[754]={id=754, lang = { [1]=true }, fruc = { true , true }, url = "Shards%20of%20Alara"},--Shards of Alara
[752]={id=752, lang = { [1]=true }, fruc = { true , true }, url = "Eventide"},--Eventide
[751]={id=751, lang = { [1]=true }, fruc = { true , true }, url = "Shadowmoor"},--Shadowmoor
[750]={id=750, lang = { [1]=true }, fruc = { true , true }, url = "Morningtide"},--Morningtide
[730]={id=730, lang = { [1]=true }, fruc = { true , true }, url = "Lorwyn"},--Lorwyn
[710]={id=710, lang = { [1]=true }, fruc = { true , true }, url = "Future%20Sight"},--Future Sight
[700]={id=700, lang = { [1]=true }, fruc = { true , true }, url = "Planar%20Chaos"},--Planar Chaos
[690]={id=690, lang = { [1]=true }, fruc = { true , true }, url = "Time%20Spiral%20Timeshifted"},--Time Spiral Timeshifted
[680]={id=680, lang = { [1]=true }, fruc = { true , true }, url = "Time%20Spiral"},--Time Spiral
[670]={id=670, lang = { [1]=true }, fruc = { true , true }, url = "Coldsnap"},--Coldsnap
[660]={id=660, lang = { [1]=true }, fruc = { true , true }, url = "Dissension"},--Dissension
[650]={id=650, lang = { [1]=true }, fruc = { true , true }, url = "Guildpact"},--Guildpact
[640]={id=640, lang = { [1]=true }, fruc = { true , true }, url = "Ravnica:%20City%20of%20Guilds"},--Ravnica: City of Guilds
[620]={id=620, lang = { [1]=true }, fruc = { true , true }, url = "Saviors%20of%20Kamigawa"},--Saviors of Kamigawa
[610]={id=610, lang = { [1]=true }, fruc = { true , true }, url = "Betrayers%20of%20Kamigawa"},--Betrayers of Kamigawa
[590]={id=590, lang = { [1]=true }, fruc = { true , true }, url = "Champions%20of%20Kamigawa"},--Champions of Kamigawa
[580]={id=580, lang = { [1]=true }, fruc = { true , true }, url = "Fifth%20Dawn"},--Fifth Dawn
[570]={id=570, lang = { [1]=true }, fruc = { true , true }, url = "Darksteel"},--Darksteel
[560]={id=560, lang = { [1]=true }, fruc = { true , true }, url = "Mirrodin"},--Mirrodin
[540]={id=540, lang = { [1]=true }, fruc = { true , true }, url = "Scourge"},--Scourge
[530]={id=530, lang = { [1]=true }, fruc = { true , true }, url = "Legions"},--Legions
[520]={id=520, lang = { [1]=true }, fruc = { true , true }, url = "Onslaught"},--Onslaught
[510]={id=510, lang = { [1]=true }, fruc = { true , true }, url = "Judgment"},--Judgment
[500]={id=500, lang = { [1]=true }, fruc = { true , true }, url = "Torment"},--Torment
[480]={id=480, lang = { [1]=true }, fruc = { true , true }, url = "Odyssey"},--Odyssey
[470]={id=470, lang = { [1]=true }, fruc = { true , true }, url = "Apocalypse"},--Apocalypse
[450]={id=450, lang = { [1]=true }, fruc = { true , true }, url = "Planeshift"},--Planeshift
[430]={id=430, lang = { [1]=true }, fruc = { true , true }, url = "Invasion"},--Invasion
[420]={id=420, lang = { [1]=true }, fruc = { true , true }, url = "Prophecy"},--Prophecy
[410]={id=410, lang = { [1]=true }, fruc = { true , true }, url = "Nemesis"},--Nemesis
[400]={id=400, lang = { [1]=true }, fruc = { true , true }, url = "Mercadian%20Masques"},--Mercadian Masques
[370]={id=370, lang = { [1]=true }, fruc = { true , true }, url = "Urza%E2%80%99s%20Destiny"},--Urza’s Destiny
[350]={id=350, lang = { [1]=true }, fruc = { true , true }, url = "Urza%E2%80%99s%20Legacy"},--Urza’s Legacy
[330]={id=330, lang = { [1]=true }, fruc = { false, true }, url = "Urza%E2%80%99s%20Saga"},--Urza’s Saga
[300]={id=300, lang = { [1]=true }, fruc = { false, true }, url = "Exodus"},--Exodus
[290]={id=290, lang = { [1]=true }, fruc = { false, true }, url = "Stronghold"},--Stronghold
[280]={id=280, lang = { [1]=true }, fruc = { false, true }, url = "Tempest"},--Tempest
[270]={id=270, lang = { [1]=true }, fruc = { false, true }, url = "Weatherlight"},--Weatherlight
[240]={id=240, lang = { [1]=true }, fruc = { false, true }, url = "Visions"},--Visions
[230]={id=230, lang = { [1]=true }, fruc = { false, true }, url = "Mirage"},--Mirage
[220]={id=220, lang = { [1]=true }, fruc = { false, true }, url = "Alliances"},--Alliances
[210]={id=210, lang = { [1]=true }, fruc = { false, true }, url = "Homelands"},--Homelands
[190]={id=190, lang = { [1]=true }, fruc = { false, true }, url = "Ice%20Age"},--Ice Age
[170]={id=170, lang = { [1]=true }, fruc = { false, true }, url = "Fallen%20Empires"},--Fallen Empires
[160]={id=160, lang = { [1]=true }, fruc = { false, true }, url = "The%20Dark"},--The Dark
[150]={id=150, lang = { [1]=true }, fruc = { false, true }, url = "Legends"},--Legends
[130]={id=130, lang = { [1]=true }, fruc = { false, true }, url = "Antiquities"},--Antiquities
[120]={id=120, lang = { [1]=true }, fruc = { false, true }, url = "Arabian%20Nights"},--Arabian Nights
-- special sets
[821]={id=821, lang = { [1]=true }, fruc = { false, true }, url = "Challenge%20Deck:%20Defeat%20a%20God"},--Challenge Deck: Defeat a God
[820]={id=820, lang = { [1]=true }, fruc = { true , true }, url = "Duel%20Decks:%20Elspeth%20vs.%20Kiora"},--Duel Decks: Elspeth vs. Kiora
[819]={id=819, lang = { [1]=true }, fruc = { true , true }, url = "Modern%20Masters%202015%20Edition"},--Modern Masters 2015 Edition
[817]={id=817, lang = { [1]=true }, fruc = { true , true }, url = "Duel%20Decks:%20Anthology"},--Duel Decks: Anthology
[815]={id=815, lang = { [1]=true }, fruc = { true , false}, url = "Fate%20Reforged%20Clash%20Pack"},--Fate Reforged Clash Pack
[814]={id=814, lang = { [1]=true }, fruc = { true , true }, url = "Commander%202014%20Edition"},--Commander 2014 Edition
[812]={id=812, lang = { [1]=true }, fruc = { true , true }, url = "Duel%20Decks:%20Speed%20vs.%20Cunning"},--Duel Decks: Speed vs. Cunning
[811]={id=811, lang = { [1]=true }, fruc = { true , false}, url = "Magic%202015%20Clash%20Pack"},--Magic 2015 Clash Pack
[810]={id=810, lang = { [1]=true }, fruc = { false, true }, url = "Modern%20Event%20Deck%202014"},--Modern Event Deck 2014
[809]={id=809, lang = { [1]=true }, fruc = { true , false}, url = "From%20the%20Vault:%20Annihilation"},--From the Vault: Annihilation
[807]={id=807, lang = { [1]=true }, fruc = { true , true }, url = "Conspiracy"},--Conspiracy
[805]={id=805, lang = { [1]=true }, fruc = { true , true }, url = "Duel%20Decks:%20Jace%20vs.%20Vraska"},--Duel Decks: Jace vs. Vraska
[804]={id=804, lang = { [1]=true }, fruc = { false, true }, url = "Challenge%20Deck:%20Battle%20the%20Horde"},--Challenge Deck: Battle the Horde
[803]={id=803, lang = { [1]=true }, fruc = { false, true }, url = "Challenge%20Deck:%20Face%20the%20Hydra"},--Challenge Deck: Face the Hydra
[801]={id=801, lang = { [1]=true }, fruc = { true , true }, url = "Commander%202013%20Edition"},--Commander 2013 Edition
[799]={id=799, lang = { [1]=true }, fruc = { true , true }, url = "Duel%20Decks:%20Heroes%20vs.%20Monsters"},--Duel Decks: Heroes vs. Monsters
[798]={id=798, lang = { [1]=true }, fruc = { true , false}, url = "From%20the%20Vault:%20Twenty"},--From the Vault: Twenty
[796]={id=796, lang = { [1]=true }, fruc = { true , true }, url = "Modern%20Masters"},--Modern Masters
[794]={id=794, lang = { [1]=true }, fruc = { true , true }, url = "Duel%20Decks:%20Sorin%20vs.%20Tibalt"},--Duel Decks: Sorin vs. Tibalt
[792]={id=792, lang = { [1]=true }, fruc = { true , true }, url = "Commander%E2%80%99s%20Arsenal"},--Commanderâ€™s Arsenal
[790]={id=790, lang = { [1]=true }, fruc = { true , true }, url = "Duel%20Decks:%20Izzet%20vs.%20Golgari"},--Duel Decks: Izzet vs. Golgari
[789]={id=789, lang = { [1]=true }, fruc = { true , false}, url = "From%20the%20Vault:%20Realms"},--From the Vault: Realms
[787]={id=787, lang = { [1]=true }, fruc = { false, true }, url = "Planechase%202012%20Edition"},--Planechase 2012 Edition
[785]={id=785, lang = { [1]=true }, fruc = { true , true }, url = "Duel%20Decks:%20Venser%20vs.%20Koth"},--Duel Decks: Venser vs. Koth
[783]={id=783, lang = { [1]=true }, fruc = { true , false}, url = "Premium%20Deck%20Series:%20Graveborn"},--Premium Deck Series: Graveborn
[781]={id=781, lang = { [1]=true }, fruc = { true , true }, url = "Duel%20Decks:%20Ajani%20vs.%20Nicol%20Bolas"},--Duel Decks: Ajani vs. Nicol Bolas
[780]={id=780, lang = { [1]=true }, fruc = { true , false}, url = "From%20the%20Vault:%20Legends"},--From the Vault: Legends
[778]={id=778, lang = { [1]=true }, fruc = { true , true }, url = "Magic:%20The%20Gathering%20Commander"},--Magic: The Gathering Commander
[777]={id=777, lang = { [1]=true }, fruc = { true , true }, url = "Duel%20Decks:%20Knights%20vs.%20Dragons"},--Duel Decks: Knights vs. Dragons
[774]={id=774, lang = { [1]=true }, fruc = { true , false}, url = "Premium%20Deck%20Series:%20Fire%20&%20Lightning"},--Premium Deck Series: Fire & Lightning
[772]={id=772, lang = { [1]=true }, fruc = { true , true }, url = "Duel%20Decks:%20Elspeth%20vs.%20Tezzeret"},--Duel Decks: Elspeth vs. Tezzeret
[771]={id=771, lang = { [1]=true }, fruc = { true , false}, url = "From%20the%20Vault:%20Relics"},--From the Vault: Relics
[769]={id=769, lang = { [1]=true }, fruc = { false, true }, url = "Archenemy"},--Archenemy
[768]={id=768, lang = { [1]=true }, fruc = { true , true }, url = "Duels%20of%20the%20Planeswalkers"},--Duels of the Planeswalkers
[766]={id=766, lang = { [1]=true }, fruc = { true , true }, url = "Duel%20Decks:%20Phyrexia%20vs.%20The%20Coalition"},--Duel Decks: Phyrexia vs. The Coalition
[764]={id=764, lang = { [1]=true }, fruc = { true , false}, url = "Premium%20Deck%20Series:%20Slivers"},--Premium Deck Series: Slivers
[763]={id=763, lang = { [1]=true }, fruc = { true , true }, url = "Duel%20Decks:%20Garruk%20vs.%20Liliana"},--Duel Decks: Garruk vs. Liliana
[761]={id=761, lang = { [1]=true }, fruc = { false, true }, url = "Planechase"},--Planechase
[760]={id=760, lang = { [1]=true }, fruc = { true , false}, url = "From%20the%20Vault:%20Exiled"},--From the Vault: Exiled
[757]={id=757, lang = { [1]=true }, fruc = { true , true }, url = "Duel%20Decks:%20Divine%20vs.%20Demonic"},--Duel Decks: Divine vs. Demonic
[755]={id=755, lang = { [1]=true }, fruc = { true , true }, url = "Duel%20Decks:%20Jace%20vs.%20Chandra"},--Duel Decks: Jace vs. Chandra
[753]={id=753, lang = { [1]=true }, fruc = { true , false}, url = "From%20the%20Vault:%20Dragons"},--From the Vault: Dragons
[740]={id=740, lang = { [1]=true }, fruc = { true , true }, url = "Duel%20Decks:%20Elves%20vs.%20Goblins"},--Duel Decks: Elves vs. Goblins
[675]={id=675, lang = { [1]=true }, fruc = { false, true }, url = "Coldsnap%20Theme%20Decks"},--Coldsnap Theme Decks
[636]={id=636, lang = { [1]=true }, fruc = { true , true }, url = "Salvat%202011"},--Salvat 2011
[635]={id=635, lang = { [1]=false,[4]=true,[5]=true,[7]=true }, fruc = { true , true }, url = "Salvat%20Magic%20Encyclopedia"},--Salvat Magic Encyclopedia
[600]={id=600, lang = { [1]=true }, fruc = { true , true }, url = "Unhinged"},--Unhinged
[490]={id=490, lang = { [1]=true }, fruc = { true , true }, url = "Deckmasters"},--Deckmasters
[440]={id=440, lang = { [1]=true }, fruc = { true , true }, url = "Beatdown"},--Beatdown
[415]={id=415, lang = { [1]=true }, fruc = { true , true }, url = "Starter%202000"},--Starter 2000
[405]={id=405, lang = { [1]=true }, fruc = { false, true }, url = "Battle%20Royale"},--Battle Royale
[390]={id=390, lang = { [1]=true }, fruc = { false, true }, url = "Starter%201999"},--Starter 1999
[380]={id=380, lang = { [1]=true }, fruc = { false, true }, url = "Portal%20Three%20Kingdoms"},--Portal Three Kingdoms
[340]={id=340, lang = { [1]=true }, fruc = { false, true }, url = "Anthologies"},--Anthologies
[320]={id=320, lang = { [1]=true }, fruc = { false, true }, url = "Unglued"},--Unglued
[310]={id=310, lang = { [1]=true }, fruc = { false, true }, url = "Portal%20Second%20Age"},--Portal Second Age
[260]={id=260, lang = { [1]=true }, fruc = { false, true }, url = "Portal"},--Portal
[235]={id=235, lang = { [1]=true }, fruc = { false, true }, url = "Multiverse%20Gift%20Box"},--Multiverse Gift Box
[225]={id=225, lang = { [1]=true }, fruc = { true , true }, url = "Introductory%20Two-Player%20Set"},--Introductory Two-Player Set
[201]={id=201, lang = { [1]=false,[3]=true,[4]=true,[5]=true }, fruc = { false, true }, url = "Renaissance"},--Renaissance
[200]={id=200, lang = { [1]=true }, fruc = { false, true }, url = "Chronicles"},--Chronicles
[106]={id=106, lang = { [1]=true }, fruc = { false, true }, url = "Collectors%E2%80%99%20Edition%20%28International%29"},--Collectors’ Edition (International)
[105]={id=105, lang = { [1]=true }, fruc = { false, true }, url = "Collectors%E2%80%99%20Edition%20%28Domestic%29"},--Collectors’ Edition (Domestic)
[70]={id= 70, lang = { [1]=true }, fruc = { false, true }, url = "Vanguard"},--Vanguard
[69]={id= 69, lang = { [1]=true }, fruc = { false, true }, url = "Box%20Topper%20Cards"},--Box Topper Cards
-- Promo Cards
[55]={id= 55, lang = { [1]=true }, fruc = { true , true }, url = "Ugin%E2%80%99s%20Fate%20Promos"},--Ugin’s Fate Promos
[53]={id= 53, lang = { [1]=true }, fruc = { true , true }, url = "Holiday%20Gift%20Box%20Promos"},--Holiday Gift Box Promos
[52]={id= 52, lang = { [1]=true }, fruc = { true , true }, url = "Intro%20Pack%20Promos"},--Intro Pack Promos
[50]={id= 50, lang = { [1]=true }, fruc = { true , true }, url = "Full%20Box%20Promotion"},--Full Box Promotion
[45]={id= 45, lang = { [1]=true }, fruc = { true , true }, url = "Magic%20Premiere%20Shop"},--Magic Premiere Shop
[43]={id= 43, lang = { [1]=true }, fruc = { true , true }, url = "Two-Headed%20Giant%20Promos"},--Two-Headed Giant Promos
[42]={id= 42, lang = { [1]=true }, fruc = { true , true }, url = "Summer%20of%20Magic%20Promos"},--Summer of Magic Promos
[41]={id= 41, lang = { [1]=true }, fruc = { true , true }, url = "Happy%20Holidays%20Promos"},--Happy Holidays Promos
[40]={id= 40, lang = { [1]=true }, fruc = { true , true }, url = "Arena%2FColosseo%20Leagues%20Promos"},--Arena/Colosseo Leagues Promos
[33]={id= 33, lang = { [1]=true }, fruc = { true , true }, url = "Championships%20Prizes"},--Championships Prizes
[32]={id= 32, lang = { [1]=true }, fruc = { true , true }, url = "Pro%20Tour%20Promos"},--Pro Tour Promos
[31]={id= 31, lang = { [1]=true }, fruc = { true , true }, url = "Grand%20Prix%20Promos"},--Grand Prix Promos
[30]={id= 30, lang = { [1]=true }, fruc = { true , true }, url = "Friday%20Night%20Magic%20Promos"},--Friday Night Magic Promos
[27]={id= 27, lang = { [1]=true }, fruc = { true , true }, url = "Alternate%20Art%20Lands"},--Alternate Art Lands
--															url={ --Alternate Art Lands
--															"",--Asian-Pacific Lands
--															"",--European Lands
--															"",--Guru Lands
--															} },
[26]={id= 26, lang = { [1]=true }, fruc = { true , true }, url = "Magic%20Game%20Day"},--Magic Game Day
[25]={id= 25, lang = { [1]=true, [17]="PHY" }, fruc = { true , true }, url = "Judge%20Gift%20Cards"},--Judge Gift Cards
[24]={id= 24, lang = { [1]=true }, fruc = { true , true }, url = "Champs%20Promos"},--Champs Promos
[23]={id= 23, lang = { [1]=true }, fruc = { true , true }, url = "Gateway%20&%20WPN%20Promos"},--Gateway & WPN Promos
--														url={ --Gateway & WPN Promos
--														"",--Gateway Promos
--														"",--WPN Promos
--														} },
[22]={id= 22, lang = { [1]=true,[12]="HEB",[13]="ARA",[14]="LAT",[15]="SAN",[16]="GRC" }, fruc = { true , true }, url = "Prerelease%20Promos"},--Prerelease Promos
[21]={id= 21, lang = { [1]=true }, fruc = { true , true }, url = "Release%20&%20Launch%20Parties%20Promos"},--Release & Launch Parties Promos
[20]={id= 20, lang = { [1]=true }, fruc = { true , true }, url = "Magic%20Player%20Rewards"},--Magic Player Rewards
[15]={id= 15, lang = { [1]=true }, fruc = { true , true }, url = "Convention%20Promos"},--Convention Promos
[12]={id= 12, lang = { [1]=true }, fruc = { true , true }, url = "Hobby%20Japan%20Commemorative%20Cards"},--Hobby Japan Commemorative Cards
[11]={id= 11, lang = { [1]=true }, fruc = { true , true }, url = "Redemption%20Program%20Cards"},--Redemption Program Cards
[10]={id= 10, lang = { [1]=true }, fruc = { true , true }, url = "Junior%20Series%20Promos"},--Junior Series Promos
[9]={id=  9, lang = { [1]=true }, fruc = { true , true }, url = "Video%20Game%20Promos"},--Video Game Promos
[8]={id=  8, lang = { [1]=true }, fruc = { true , true }, url = "Stores%20Promos"},--Stores Promos
[7]={id=  7, lang = { [1]=true }, fruc = { true , true }, url = "Magazine%20Inserts"},--Magazine Inserts
[6]={id=  6, lang = { [1]=true }, fruc = { true , true }, url = "Comic%20Inserts"},--Comic Inserts
[5]={id=  5, lang = { [1]=true }, fruc = { true , true }, url = "Book%20Inserts"},--Book Inserts
[4]={id=  4, lang = { [1]=true }, fruc = { true , true }, url = "Ultra%20Rare%20Cards"},--Ultra Rare Cards
[2]={id=  2, lang = { [1]=true }, fruc = { true , true }, url = "DCI%20Legend%20Membership"},--DCI Legend Membership
} -- end table site.sets

--[[- card name replacement tables.

  fields are for subtables indexed by #number setid.
 { #number (setid)= #table { #string (oldname)= #string (newname), ... } , ... }
 
 @type site.namereplace
 @field [parent=#site.namereplace] #string name
]]
site.namereplace = {
--[[
[788] = { -- M2013
["Liliana o. t. Dark Realms Emblem"]	= "Liliana of the Dark Realms Emblem"
}
--]]
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
 @field [parent=#site.foiltweak] #boolean override	(optional) if true, defaults from LHpi.Data will not be used at all
 @field [parent=#site.foiltweak] #table foilstatus
]]
site.foiltweak = {
--[[ example
[766] = { -- Phyrexia VS Coalition
	override=true,
 	["Phyrexian Negator"] 	= { foil = true  },
	["Urza's Rage"] 		= { foil = true  }
}
]]
} -- end table site.foiltweak
--ignore all foiltweak tables from LHpi.Data
--for sid,set in pairs(site.sets) do
--	site.foiltweak[sid] = { override=true }
--end

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
	tokens = false,
--	tokens = { "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA" },
--- if site.expected.nontrad is true, LHpi.Data.sets[setid].cardcount.nontrad is added to pset default.
-- a boolean will set this for all languges, a table will be assumed to be of the form { [langid]=#boolean, ... }
-- @field [parent=#site.expected] #boolean nontrad
	nontrad = true,
--- if site.expected.replica is true, LHpi.Data.sets[setid].cardcount.repl is added to pset default.
-- a boolean will set this for all languges, a table will be assumed to be of the form { [langid]=#boolean, ... }
-- @field [parent=#site.expected] #boolean replica
	replica = true,
-- Core sets
--[808] = { pset={ LHpi.Data.sets[808].cardcount.reg+LHpi.Data.sets[808].cardcount.tok, nil, LHpi.Data.sets[808].cardcount.reg }, failed={ 0, nil, LHpi.Data.sets[808].cardcount.tok }, dropped=1 },
--[788] = { pset={ 249+11, nil, 249 }, failed={ 0, nil, 11 }, dropped=0, namereplaced=1, foiltweaked=0 }, -- M2013
	}--end table site.expected
	-- Too lazy to fill in site.expected for all languages? Let the script do it ;-)
	for sid,name in pairs(importsets) do
		if site.expected[sid] then
			if site.expected[sid].pset and site.expected[sid].duppset and site.expected[sid].pset.dup then			
				for lid,lang in pairs(site.expected[sid].duppset) do
					if importlangs[lid] then
						site.expected[sid].pset[lid] = site.expected[sid].pset.dup or 0
					end
				end--for lid
			site.expected[sid].duppset=nil
			site.expected[sid].pset.dup=nil
			end-- if site.expected[sid].pset
			if site.expected[sid].failed and site.expected[sid].dupfail and site.expected[sid].failed.dup then			
				for lid,lang in pairs(site.expected[sid].dupfail) do
					if importlangs[lid] then
						site.expected[sid].failed[lid] = site.expected[sid].failed.dup or 0
					end
				end--for lid
			site.expected[sid].dupfail=nil
			site.expected[sid].failed.dup=nil
			end-- if site.expected[sid].failed
		end--if site.expected[sid]
		if site.namereplace[sid] then
			if site.expected[sid] then
				site.expected[sid].namereplaced=2*LHpi.Length(site.namereplace[sid])
			else
				site.expected[sid]= { namereplaced=2*LHpi.Length(site.namereplace[sid]) }
			end
		end
	end--for sid,name
end--function site.SetExpected()
ma.Log(site.scriptname .. " loaded.")
--EOF