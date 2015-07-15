--*- coding: utf-8 -*-
--[[- LHpi sitescript for magic.tcgplayer.com PriceGuide 

Inspired by and loosely based on "MTG Mint Card.lua" by Goblin Hero, Stromglad1 and "Import Prices.lua" by woogerboy21;
who generously granted permission to "do as I like" with their code;
everything else Copyright (C) 2012-2014 by Christian Harms.
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
2.14.5.14
removed url to filename changes that are done by the library if OFFLINE
2.15.6.14
new features from template/mkm branch
site.BuildUrl supports multiple urls per set
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
-- @field [parent=#global] #boolean STRICTEXPECTED
STRICTEXPECTED = true

--- if true, exit with error on object type mismatch, else use object type 0 (all)
-- @field [parent=#global] #boolean STRICTOBJTYPE
STRICTOBJTYPE = true

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

---	log raw html data found by regex; default false
-- @field [parent=#global] #boolean DEBUGFOUND
--DEBUGFOUND = true

--- DEBUG (only but deeper) inside variant loops; default false
-- @field [parent=#global] #boolean DEBUGVARIANTS
--DEBUGVARIANTS = true

--- revision of the LHpi library to use
-- @field [parent=#global] #string libver
libver = "2.15"
--- revision of the LHpi library datafile to use
-- @field [parent=#global] #string dataver
dataver = "6"
--- sitescript revision number
-- @field [parent=#global] string scriptver
scriptver = "14"
--- should be similar to the script's filename. Used for loging and savepath.
-- @field [parent=#global] #string scriptname
scriptname = "LHpi.tcgplayerPriceGuide-v" .. libver .. "." .. dataver .. "." .. scriptver .. ".lua"

---	LHpi library
-- will be loaded by ImportPrice
-- @field [parent=#global] #table LHpi
LHpi = {} or {}

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
 @field [parent=#site] #string regex ]]
site.regex = '<TR height=20>(.-)</TR>'


--- support for global workdir, if used outside of Magic Album/Prices folder. do not change here.
site.workdir = workdir or "Prices\\"

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
	ma.Log( "End of Lua script " .. scriptname )
end -- function ImportPrice

--[[- load LHpi library from external file
@function [parent=#site] LoadLib
@return #table LHpi library object
@return #string log concatenated strings to be logged when LHpi is available
]]
function site.LoadLib()
	local LHpi
	local libname = site.workdir .. "lib\\LHpi-v" .. libver .. ".lua"
	local loglater
	local LHpilib = ma.GetFile( libname )
	if tonumber(libver) < 2.15 then
		loglater = ""
		local oldlibname = "Prices\\LHpi-v" .. libver .. ".lua"
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
	LHpi.Log("Importing " .. site.himelo[himelo] .. " prices. Columns available are " .. LHpi.Tostring(site.himelo) , 1 )
	
	if mode.update then
		if not dummy then error("ListUnknownUrls needs to be run from dummyMA!") end
	 	dummy.ListUnknownUrls(site.FetchExpansionList(),dummy.CompareSiteSets())
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
 @param #boolean offline	(can be nil) use local file instead of url
 @return #table { #string (url)= #table { isfile= #boolean, (optional) foilonly= #boolean, (optional) setid= #number, (optional) langid= #number, (optional) frucid= #number } , ... }
]]
function site.BuildUrl( setid,langid,frucid,offline )
	site.domain = "magic.tcgplayer.com/"
	site.file = "db/price_guide.asp"
	site.setprefix = "?setname="
	
	local container = {}
	if setid=="list" then --request price guide expansion list 
		return site.domain .. "magic_price_guides.asp"
	else -- usual LHpi behaviour
		local url = site.domain .. site.file .. site.setprefix
		if  type(site.sets[setid].url) == "table" then
			urls = site.sets[setid].url
		else
			urls = { site.sets[setid].url }
		end--if type(site.sets[setid].url)
		for _i,seturl in pairs(urls) do
			container[url .. seturl] = {}
			if LHpi.Data.sets[setid].foilonly then
				container[url .. seturl].foilonly = true
			else
				container[url .. seturl].foilonly = false -- just to make the point :)
			end
		end--for _i,seturl
	end
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
	local expansions = {}
	local url = site.BuildUrl( "list" )
	local expansionSource = LHpi.GetSourceData ( url , urldetails )
	if not expansionSource then
		error(string.format("Expansion list not found at %s (OFFLINE=%s)",LHpi.Tostring(url),tostring(OFFLINE)) )
	end
	local setregex = '<img [^>]+>[^<]*<a.-href="([^"]+)">([^<]+)</a><BR>'
	for url,name in string.gmatch( expansionSource , setregex) do
		_,_,url=string.find(url,"setName=([^&]-)&")
		url=string.gsub(url,"-"," ")
		table.insert(expansions, { name=name, urlsuffix=LHpi.OAuthEncode(url)})
	end
	return expansions
end--function FetchExpansionList
--[[- format string to use in dummy.ListUnknownUrls update helper function.
 @field [parent=#site] #string updateFormatString ]]
site.updateFormatString = "[%i]={id = %3i, lang = { true }, fruc = { true }, url = %q},--%s"

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
 @return #table newCard.variant		(optional) will override LHpi.buildCardData generated values.
 @return #number or #table newCard.regprice		(optional) will override LHpi.buildCardData generated values. #number or #table { [#number langid]= #number,...}
 @return #number or #table newCard.foilprice 	(optional) will override LHpi.buildCardData generated values. #number or #table { [#number langid]= #number,...}
 
 @function [parent=#site] ParseHtmlData
 @param #string foundstring		one occurence of siteregex from raw html data
 @param #table urldetails		{ isfile= #boolean, oauth= #boolean, setid= #number, langid= #number, frucid= #number , foilonly= #boolean }
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
--	local newCard = { names = { [1] = name } , price = { [1] = price } }
	local newCard = { names = { [1] = name } , price = price }
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

--[[- Define the three price columns. This table is unique to this sitescript.
-- @type site.himelo
]]
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
[808]={id = 808, lang = { true }, fruc = { true }, url = "Magic%202015%20(M15)"},--Magic 2015 (M15)
[797]={id = 797, lang = { true }, fruc = { true }, url = "Magic%202014%20(M14)"},--Magic 2014 (M14)
[788]={id = 788, lang = { true }, fruc = { true }, url = "Magic%202013%20(M13)"},--Magic 2013 (M13)
[779]={id = 779, lang = { true }, fruc = { true }, url = "Magic%202012%20(M12)"},--Magic 2012 (M12)
[770]={id = 770, lang = { true }, fruc = { true }, url = "Magic%202011%20(M11)"},--Magic 2011 (M11)
[759]={id = 759, lang = { true }, fruc = { true }, url = "Magic%202010%20(M10)"},--Magic 2010 (M10)
[720]={id = 720, lang = { true }, fruc = { true }, url = "10th%20edition"},--Tenth Edition
[630]={id = 630, lang = { true }, fruc = { true }, url = "9th%20Edition"},--Ninth Edition
[550]={id = 550, lang = { true }, fruc = { true }, url = "8th%20Edition"},--Eighth Edition
[460]={id = 460, lang = { true }, fruc = { true }, url = "7th%20Edition"},--Seventh Edition
[360]={id = 360, lang = { true }, fruc = { true }, url = "Classic%20Sixth%20Edition"},--Sixth Edition
[250]={id = 250, lang = { true }, fruc = { true }, url = "Fifth%20Edition"},--Fifth Edition
[180]={id = 180, lang = { true }, fruc = { true }, url = "Fourth%20Edition"},--Fourth Edition
[179]=nil,--4th Edition (FBB)
[141]=nil,--Revised Summer Magic
[140]={id = 140, lang = { true }, fruc = { true }, url = "revised%20edition"},--Revised Edition
[139]=nil,--Revised Limited Deutsch
[110]={id = 110, lang = { true }, fruc = { true }, url = "Unlimited%20Edition"},--Unlimited Edition
[100]={id = 100, lang = { true }, fruc = { true }, url = "Beta%20Edition"},--Beta Edition
[90] ={id =  90, lang = { true }, fruc = { true }, url = "Alpha%20Edition"},--Alpha Edition
-- Expansions
[818]={id = 818, lang = { true }, fruc = { true }, url = "dragons%20of%20tarkir"},--Dragons of Tarkir
[816]={id = 816, lang = { true }, fruc = { true }, url = "fate%20reforged"},--Fate Reforged
[813]={id = 813, lang = { true }, fruc = { true }, url = "khans%20of%20tarkir"},--Khans of Tarkir
[806]={id = 806, lang = { true }, fruc = { true }, url = "journey%20into%20nyx"},--Journey into Nyx
[802]={id = 802, lang = { true }, fruc = { true }, url = "born%20of%20the%20gods"},--Born of the Gods
[800]={id = 800, lang = { true }, fruc = { true }, url = "theros"},--Theros
[795]={id = 795, lang = { true }, fruc = { true }, url = "Dragon's%20Maze"},--Dragon's Maze
[793]={id = 793, lang = { true }, fruc = { true }, url = "gatecrash"},--Gatecrash
[791]={id = 791, lang = { true }, fruc = { true }, url = "return%20to%20ravnica"},--Return to Ravnica
[786]={id = 786, lang = { true }, fruc = { true }, url = "avacyn%20restored"},--Avacyn Restored
[784]={id = 784, lang = { true }, fruc = { true }, url = "dark%20ascension"},--Dark Ascension
[782]={id = 782, lang = { true }, fruc = { true }, url = "innistrad"},--Innistrad
[776]={id = 776, lang = { true }, fruc = { true }, url = "new%20phyrexia"},--New Phyrexia
[775]={id = 775, lang = { true }, fruc = { true }, url = "mirrodin%20besieged"},--Mirrodin Besieged
[773]={id = 773, lang = { true }, fruc = { true }, url = "scars%20of%20mirrodin"},--Scars of Mirrodin
[767]={id = 767, lang = { true }, fruc = { true }, url = "rise%20of%20the%20eldrazi"},--Rise of the Eldrazi
[765]={id = 765, lang = { true }, fruc = { true }, url = "worldwake"},--Worldwake
[762]={id = 762, lang = { true }, fruc = { true }, url = "zendikar"},--Zendikar
[758]={id = 758, lang = { true }, fruc = { true }, url = "alara%20reborn"},--Alara Reborn
[756]={id = 756, lang = { true }, fruc = { true }, url = "conflux"},--Conflux
[754]={id = 754, lang = { true }, fruc = { true }, url = "shards%20of%20alara"},--Shards of Alara
[752]={id = 752, lang = { true }, fruc = { true }, url = "eventide"},--Eventide
[751]={id = 751, lang = { true }, fruc = { true }, url = "shadowmoor"},--Shadowmoor
[750]={id = 750, lang = { true }, fruc = { true }, url = "morningtide"},--Morningtide
[730]={id = 730, lang = { true }, fruc = { true }, url = "lorwyn"},--Lorwyn
[710]={id = 710, lang = { true }, fruc = { true }, url = "future%20sight"},--Future Sight
[700]={id = 700, lang = { true }, fruc = { true }, url = "planar%20chaos"},--Planar Chaos
[690]={id = 690, lang = { true }, fruc = { true }, url = "timeshifted"},--Timeshifted
[680]={id = 680, lang = { true }, fruc = { true }, url = "time%20spiral"},--Time Spiral
[670]={id = 670, lang = { true }, fruc = { true }, url = "coldsnap"},--Coldsnap
[660]={id = 660, lang = { true }, fruc = { true }, url = "dissension"},--Dissension
[650]={id = 650, lang = { true }, fruc = { true }, url = "guildpact"},--Guildpact
[640]={id = 640, lang = { true }, fruc = { true }, url = "ravnica"},--Ravnica
[620]={id = 620, lang = { true }, fruc = { true }, url = "saviors%20of%20kamigawa"},--Saviors of Kamigawa
[610]={id = 610, lang = { true }, fruc = { true }, url = "betrayers%20of%20kamigawa"},--Betrayers of Kamigawa
[590]={id = 590, lang = { true }, fruc = { true }, url = "champions%20of%20kamigawa"},--Champions of Kamigawa
[580]={id = 580, lang = { true }, fruc = { true }, url = "fifth%20dawn"},--Fifth Dawn
[570]={id = 570, lang = { true }, fruc = { true }, url = "darksteel"},--Darksteel
[560]={id = 560, lang = { true }, fruc = { true }, url = "mirrodin"},--Mirrodin
[540]={id = 540, lang = { true }, fruc = { true }, url = "scourge"},--Scourge
[530]={id = 530, lang = { true }, fruc = { true }, url = "legions"},--Legions
[520]={id = 520, lang = { true }, fruc = { true }, url = "onslaught"},--Onslaught
[510]={id = 510, lang = { true }, fruc = { true }, url = "judgment"},--Judgment
[500]={id = 500, lang = { true }, fruc = { true }, url = "torment"},--Torment
[480]={id = 480, lang = { true }, fruc = { true }, url = "odyssey"},--Odyssey
[470]={id = 470, lang = { true }, fruc = { true }, url = "apocalypse"},--Apocalypse
[450]={id = 450, lang = { true }, fruc = { true }, url = "planeshift"},--Planeshift
[430]={id = 430, lang = { true }, fruc = { true }, url = "invasion"},--Invasion
[420]={id = 420, lang = { true }, fruc = { true }, url = "prophecy"},--Prophecy
[410]={id = 410, lang = { true }, fruc = { true }, url = "nemesis"},--Nemesis
[400]={id = 400, lang = { true }, fruc = { true }, url = "mercadian%20masques"},--Mercadian Masques
[370]={id = 370, lang = { true }, fruc = { true }, url = "Urza's%20Destiny"},--Urza's Destiny
[350]={id = 350, lang = { true }, fruc = { true }, url = "Urza's%20Legacy"},--Urza's Legacy
[330]={id = 330, lang = { true }, fruc = { true }, url = "Urza's%20Saga"},--Urza's Saga
[300]={id = 300, lang = { true }, fruc = { true }, url = "exodus"},--Exodus
[290]={id = 290, lang = { true }, fruc = { true }, url = "stronghold"},--Stronghold
[280]={id = 280, lang = { true }, fruc = { true }, url = "tempest"},--Tempest
[270]={id = 270, lang = { true }, fruc = { true }, url = "weatherlight"},--Weatherlight
[240]={id = 240, lang = { true }, fruc = { true }, url = "visions"},--Visions
[230]={id = 230, lang = { true }, fruc = { true }, url = "mirage"},--Mirage
[220]={id = 220, lang = { true }, fruc = { true }, url = "alliances"},--Alliances
[210]={id = 210, lang = { true }, fruc = { true }, url = "homelands"},--Homelands
[190]={id = 190, lang = { true }, fruc = { true }, url = "ice%20age"},--Ice Age
[170]={id = 170, lang = { true }, fruc = { true }, url = "fallen%20empires"},--Fallen Empires
[160]={id = 160, lang = { true }, fruc = { true }, url = "the%20dark"},--The Dark
[150]={id = 150, lang = { true }, fruc = { true }, url = "legends"},--Legends
[130]={id = 130, lang = { true }, fruc = { true }, url = "antiquities"},--Antiquities
[120]={id = 120, lang = { true }, fruc = { true }, url = "arabian%20nights"},--Arabian Nights
-- special sets
[821]=nil,--Challenge Deck: Defeat a God
[820]=nil,--Duel Decks: Elspeth vs. Kiora
[819]=nil,--Modern Masters 2015 Edition
[817]=nil,--Duel Decks: Anthology
[815]=nil,--Fate Reforged Clash Pack
[814]={id=814, lang = { [1]=true }, fruc = { false, true }, url = "C14"},--Commander 2014
[812]={id=812, lang = { true }, fruc = { true }, url = "Duel%20Decks:%20Speed%20vs.%20Cunning"},--Duel Decks: Speed vs. Cunning
[811]=nil,--Magic 2015 Clash Pack
[810]={id=810, lang = { true }, fruc = { true }, url = "magic%20modern%20event%20deck"},--Modern Event Deck 2014
[809]={id = 809, lang = { true }, fruc = { true }, url = "From%20the%20Vault:%20Annihilation"},--From the Vault: Annihilation
[807]={id = 807, lang = { true }, fruc = { true }, url = "conspiracy"},--Conspiracy
[805]={id=805, lang = { true }, fruc = { true }, url = "Duel%20Decks:%20Jace%20vs.%20Vraska"},--Duel Decks: Jace vs. Vraska
[804]=nil,--Challenge Deck: Battle the Horde
[803]=nil,--Challenge Deck: Face the Hydra
[801]={id = 801, lang = { true }, fruc = { true }, url = "Commander%202013"},
[799]={id = 799, lang = { true }, fruc = { true }, url = "Duel%20Decks%3A%20Heroes%20vs.%20Monsters"},--Duel Decks: Heroes vs. Monsters
[798]={id = 798, lang = { true }, fruc = { true }, url = "From%20the%20Vault%3A%20Twenty"},--From the Vault: Twenty
[796]={id = 796, lang = { true }, fruc = { true }, url = "modern%20masters"},--Modern Masters
[794]={id = 794, lang = { true }, fruc = { true }, url = "Duel%20Decks%3A%20Sorin%20vs.%20Tibalt"},--Duel Decks: Sorin vs. Tibalt
[792]={id = 792, lang = { true }, fruc = { true }, url = "Commander%27s%20Arsenal"},
[790]={id = 790, lang = { true }, fruc = { true }, url = "Duel%20Decks:%20Izzet%20vs.%20Golgari"},--Duel Decks: Izzet vs. Golgari
[789]={id = 789, lang = { true }, fruc = { true }, url = "From%20the%20Vault%3A%20Realms"},--From the Vault: Realms
[787]={id = 787, lang = { true }, fruc = { true }, url = "planechase%202012"},--Planechase 2012
[785]={id = 785, lang = { true }, fruc = { true }, url = "Duel%20Decks:%20Venser%20vs.%20Koth"},--Duel Decks: Venser vs. Koth
[783]={id = 783, lang = { true }, fruc = { true }, url = "Premium%20Deck%20Series:%20Graveborn"},--Premium Deck Series: Graveborn
[781]={id = 781, lang = { true }, fruc = { true }, url = "Duel%20Decks:%20Ajani%20vs.%20Nicol%20Bolas"},--Duel Decks: Ajani vs. Nicol Bolas
[780]={id = 780, lang = { true }, fruc = { true }, url = "From%20the%20Vault%3A%20Legends"},--From the Vault: Legends
[778]={id = 778, lang = { true }, fruc = { true }, url = "commander"},--Commander
[777]={id = 777, lang = { true }, fruc = { true }, url = "Duel%20Decks:%20Knights%20vs%20Dragons"},--Duel Decks: Knights vs Dragons
[774]={id = 774, lang = { true }, fruc = { true }, url = "Premium%20Deck%20Series:%20Fire%20and%20Lightning"},--Premium Deck Series: Fire and Lightning
[772]={id = 772, lang = { true }, fruc = { true }, url = "Duel%20Decks:%20Elspeth%20vs.%20Tezzeret"},--Duel Decks: Elspeth vs. Tezzeret
[771]={id = 771, lang = { true }, fruc = { true }, url = "From%20the%20Vault%3A%20Relics"},--From the Vault: Relics
[769]={id = 769, lang = { true }, fruc = { true }, url = "archenemy"},--Archenemy
[768]={id = 768, lang = { true }, fruc = { true }, url = "Duels%20of%20the%20Planeswalkers"},
[766]={id = 766, lang = { true }, fruc = { true }, url = "Duel%20Decks:%20Phyrexia%20vs.%20The%20Coalition"},--Duel Decks: Phyrexia vs. The Coalition
[764]={id = 764, lang = { true }, fruc = { true }, url = "Premium%20Deck%20Series:%20Slivers"},--Premium Deck Series: Slivers
[763]={id = 763, lang = { true }, fruc = { true }, url = "Duel%20Decks:%20Garruk%20vs.%20Liliana"},--Duel Decks: Garruk vs. Liliana
[761]={id = 761, lang = { true }, fruc = { true }, url = "planechase"},--Planechase
[760]={id = 760, lang = { true }, fruc = { true }, url = "From%20the%20Vault%3A%20Exiled"},--From the Vault: Exiled
[757]={id = 757, lang = { true }, fruc = { true }, url = "Duel%20Decks:%20Divine%20vs.%20Demonic"},--Duel Decks: Divine vs. Demonic
[755]={id = 755, lang = { true }, fruc = { true }, url = "Duel%20Decks:%20Jace%20vs.%20Chandra"},--Duel Decks: Jace vs. Chandra
[753]={id = 753, lang = { true }, fruc = { true }, url = "From%20the%20Vault%3A%20Dragons"},--From the Vault: Dragons
[740]={id = 740, lang = { true }, fruc = { true }, url = "Duel%20Decks:%20Elves%20vs.%20Goblins"},--Duel Decks: Elves vs. Goblins
[675]=nil,--Coldsnap Theme Decks
[636]=nil,--Salvat 2011
[635]=nil,--Magic Encyclopedia
[600]={id = 600, lang = { true }, fruc = { true }, url = "unhinged"},--Unhinged
[490]=nil,--Deckmaster
[440]={id = 440, lang = { true }, fruc = { true }, url = "beatdown%20box%20set"},--Beatdown Box Set
[415]={id = 415, lang = { true }, fruc = { true }, url = "starter%202000"},--Starter 2000
[405]={id = 405, lang = { true }, fruc = { true }, url = "battle%20royale%20box%20set"},--Battle Royale Box Set
[390]={id = 390, lang = { true }, fruc = { true }, url = "starter%201999"},--Starter 1999
[380]={id = 380, lang = { true }, fruc = { true }, url = "portal%20three%20kingdoms"},--Portal Three Kingdoms
[340]=nil,--Anthologies
[320]={id = 320, lang = { true }, fruc = { true }, url = "unglued"},--Unglued
[310]={id = 310, lang = { true }, fruc = { true }, url = "portal%20second%20age"},--Portal Second Age
[260]={id = 260, lang = { true }, fruc = { true }, url = "portal"},--Portal
[235]=nil,--Multiverse Gift Box[225]=nil,--Introductory Two-Player Set
[201]=nil,--Renaissance
[200]={id = 200, lang = { true }, fruc = { true }, url = "chronicles"},--Chronicles
[106]={id = 106, lang = { true }, fruc = { true }, url = "collectors%20edition"},--Collectors’ Edition (International)
[105]={id = 105, lang = { true }, fruc = { true }, url = "collectors%20edition"},--Collectors’ Edition (Domestic)
[70] ={id =  70, lang = { true }, fruc = { true }, url = "vanguard"},--Vanguard
[69] =nil,--Box Topper Cards
-- Promo Cards
[55] =nil,--Ugin’s Fate Promos
[53] =nil,--Holiday Gift Box Promos
[52] =nil,--Intro Pack Promos
[50] =nil,--Full Box Promotion
[45] =nil,--Magic Premiere Shop
[43] =nil,--Two-Headed Giant Promos
[42] =nil,--Summer of Magic Promos
[41] =nil,--Happy Holidays Promos
[40] ={id =  40, lang = { true }, fruc = { true }, url = "arena%20promos"},--Arena Promos
[33] =nil,--Championships Prizes
[32] ={id =  32, lang = { true }, fruc = { true }, url = "pro%20tour%20promos"},--Pro Tour Promos
[31] ={id =  31, lang = { true }, fruc = { true }, url = "Grand%20Prix%20Promos"},--Grand Prix Promos
[30] ={id =  30, lang = { true }, fruc = { true }, url = "fnm%20promos"},--FNM Promos
[27] ={id =  27, lang = { true }, fruc = { true }, url = { --Alternate Art Lands
															"apac%20lands",--Asian-Pacific Lands
															"european%20lands",--European Lands
															"guru%20lands",--Guru Lands
															} },
[26] ={id =  26, lang = { true }, fruc = { true }, url = "game%20day%20promos"},--Game Day Promos
[25] ={id =  25, lang = { true }, fruc = { true }, url = "judge%20promos"},--Judge Promos
[24] ={id =  24, lang = { true }, fruc = { true }, url = "champs%20promos"},--Champs Promos
[23] ={id =  23, lang = { true }, fruc = { true }, url = { --Gateway & WPN Promos
														"gateway%20promos",--Gateway Promos
														"wpn%20promos",--WPN Promos
														} },
[22] ={id =  22, lang = { true }, fruc = { true }, url = "prerelease%20cards"},--Prerelease Cards
[21] ={id =  21, lang = { true }, fruc = { true }, url = { --Release & Launch Party Cards
														"release%20event%20cards",--Release Event Cards
														"launch%20party%20cards",--Launch Party Cards
														} },
[20] ={id =  20, lang = { true }, fruc = { true }, url = "magic%20player%20rewards"},--Magic Player Rewards
[15] =nil,--Convention Promos
[12] =nil,--Hobby Japan Commemorative Cards
[11] =nil,--Redemption Program Cards
--TODO: 10 JSS Needs Variant Table
[10] ={id =  10, lang = { true }, fruc = { true }, url = "JSS/MSS%20Promos"},--Junior Series Promos
[9]  =nil,--Video Game Promos
[8]  =nil,--Stores Promos
[7]  =nil,--Magazine Inserts
[6]  =nil,--Comic Inserts
[5]  =nil,--Book Inserts
[4]  =nil,--Ultra Rare Cards
[2]  =nil,--DCI Legend Membership
-- "Media%20Promos": sorting out the single page seems more trouble than it's worth
[9990]={id =   0, lang = { true }, fruc = { true }, url = "media%20promos"},--Media Promos
-- "Special%20Occasion": sorting out the single page seems more trouble than it's worth
[9991]={id =   0, lang = { true }, fruc = { true }, url = "special%20occasion"},--Special Occasion
} -- end table site.sets

--[[- card name replacement tables.

  fields are for subtables indexed by #number setid.
 { #number (setid)= #table { #string (oldname)= #string (newname), ... } , ... }
 
 @type site.namereplace
 @field [parent=#site.namereplace] #string name
]]
site.namereplace = {
[808] = { --M2015
["AEtherspouts"]						= "Ætherspouts",
["Beast Token (Black)"]					= "Beast Token (5)",
["Beast Token (Green)"]					= "Beast Token (9)",
["Land Mine"]							= "Land Mine Token",
},
[797] = { -- M2014
["Elemental Token (Jones)"]				= "Elemental Token (7)",
["Elemental Token (Nelson)"]			= "Elemental Token (8)",
},
[779] = { -- M2012
["AEther Adept"]						= "Æther Adept",
--["Pentiavite Token"]					= "Pentavite"
},
[770] = { -- M2011
["Aether Adept"]						= "Æther Adept",
["Ooze Token (1)"]						= "Ooze Token (5)",
["Ooze Token (2)"]						= "Ooze Token (6)",
},
[550] = { -- 8th Edition
["Abyssal Specter-staging-test"]		= "Abyssal Specter",
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
["Forest (417)"]						= "Forest (1)",
["Forest (418)"]						= "Forest (2)",
["Forest (419)"]						= "Forest (3)",
["Forest (420)"]						= "Forest (4)",
["Island (425)"]						= "Island (1)",
["Island (426)"]						= "Island (2)",
["Island (427)"]						= "Island (3)",
["Island (428)"]						= "Island (4)",
["Mountain (430)"]						= "Mountain (1)",
["Mountain (431)"]						= "Mountain (2)",
["Mountain (432)"]						= "Mountain (3)",
["Mountain (433)"]						= "Mountain (4)",
["Plains (434)"]						= "Plains (1)",
["Plains (435)"]						= "Plains (2)",
["Plains (436)"]						= "Plains (3)",
["Plains (437)"]						= "Plains (4)",
["Swamp (442)"]							= "Swamp (1)",
["Swamp (443)"]							= "Swamp (2)",
["Swamp (444)"]							= "Swamp (3)",
["Swamp (445)"]							= "Swamp (4)",
},
[180] = { -- 4th Edition
["Forest (175)"]						= "Forest (1)",
["Forest (176)"]						= "Forest (2)",
["Forest (177)"]						= "Forest (3)",
["Island (178)"]						= "Island (1)",
["Island (179)"]						= "Island (2)",
["Island (180)"]						= "Island (3)",
["Mountain (182)"]						= "Mountain (1)",
["Mountain (183)"]						= "Mountain (2)",
["Mountain (184)"]						= "Mountain (3)",
["Plains (186)"]						= "Plains (1)",
["Plains (187)"]						= "Plains (2)",
["Plains (188)"]						= "Plains (3)",
["Swamp (190)"]							= "Swamp (1)",
["Swamp (191)"]							= "Swamp (2)",
["Swamp (192)"]							= "Swamp (3)",
},
[140] = { -- Revised
--["El-Hajjâj"]							= "El-Hajjaj",
["Forest (284)"]						= "Forest (1)",
["Forest (285)"]						= "Forest (2)",
["Forest (286)"]						= "Forest (3)",
["Island (287)"]						= "Island (1)",
["Island (288)"]						= "Island (2)",
["Island (289)"]						= "Island (3)",
["Mountain (290)"]						= "Mountain (1)",
["Mountain (291)"]						= "Mountain (2)",
["Mountain (292)"]						= "Mountain (3)",
["Plains (293)"]						= "Plains (1)",
["Plains (294)"]						= "Plains (2)",
["Plains (295)"]						= "Plains (3)",
["Swamp (299)"]							= "Swamp (1)",
["Swamp (300)"]							= "Swamp (2)",
["Swamp (301)"]							= "Swamp (3)",
},
[100]  = { -- Beta
["Plains (A)"]							= "Plains (1)",
["Plains (B)"]							= "Plains (2)",
["Plains (C)"]							= "Plains (3)",
["Island (A)"]							= "Island (1)",
["Island (B)"]							= "Island (2)",
["Island (C)"]							= "Island (3)",
["Swamp (A)"]							= "Swamp (1)",
["Swamp (B)"]							= "Swamp (2)",
["Swamp (C)"]							= "Swamp (3)",
["Mountain (A)"]						= "Mountain (1)",
["Mountain (B)"]						= "Mountain (2)",
["Mountain (C)"]						= "Mountain (3)",
["Forest (A)"]							= "Forest (1)",
["Forest (B)"]							= "Forest (2)",
["Forest (C)"]							= "Forest (3)",
},
[90]  = { -- Alpha
["Plains (A)"]							= "Plains (1)",
["Plains (B)"]							= "Plains (2)",
["Island (A)"]							= "Island (1)",
["Island (B)"]							= "Island (2)",
["Swamp (A)"]							= "Swamp (1)",
["Swamp (B)"]							= "Swamp (2)",
["Mountain (A)"]						= "Mountain (1)",
["Mountain (B)"]						= "Mountain (2)",
["Forest (A)"]							= "Forest (1)",
["Forest (B)"]							= "Forest (2)",
},
--expansion sets
[813] = { -- Khans of Tarkir
--["Morph Reminder Card"]					= "Morph Token",
["Warrior Token (Sword & Shield)"]		= "Warrior Token (3)",
["Warrior Token (Pike)"]				= "Warrior Token (4)",
},
[802] = { -- Born of the Gods
["Bird Token (White)"]					= "Bird Token (1)",
["Bird Token (Blue)"]					= "Bird Token (4)",
},
[800] = { -- Theros
["Soldier Token (Red)"]					= "Soldier Token (7)",
["Soldier Token (McKinnon)"]			= "Soldier Token (2)",
["Soldier Token (Velinov)"]				= "Soldier Token (3)",
},
[795] = { -- Dragon's Maze
["AEtherling"]							= "Ætherling",
},
[793] = { -- Gatecrash
["Aetherize"]							= "Ætherize",
},
[786] = { -- Avacyn Restored
["Spirit Token (White)"]				= "Spirit Token (3)",
["Spirit Token (Blue)"]					= "Spirit Token (4)",
["Human Token (White)"]					= "Human Token (2)",
["Human Token (Red)"]					= "Human Token (7)",
["Angel|/Demon Double-Sided Creature Token"] = "Angel|Demon Token",
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
["Wolf Token (Deathtouch)"]				= "Wolf Token (6)",
["Wolf Token"]							= "Wolf Token (12)",
["Zombie Token (Graciano)"]				= "Zombie Token (7)",
["Zombie Token (Moeller)"]				= "Zombie Token (8)",
["Zombie Token (Sheppard)"]				= "Zombie Token (9)",
},
[776] = { -- New Phyrexia
["Arm with AEther"]						= "Arm with Æther"
},
--[775] = { -- Mirrodin Besieged
--["Plains - B"]							= "Plains (147)",
--["Island - B"]							= "Island (149)",
--["Swamp - B"]							= "Swamp (151)",
--["Mountain - B"]						= "Mountain (153)",
--["Forest - B"]							= "Forest (155)",
--},
[773] = { -- Scars of Mirrodin
["Wurm Token (Deathtouch)"]				= "Wurm Token (8)",
["Wurm Token (Lifelink)"]				= "Wurm Token (9)",
},
[767] = { -- Rise of the Eldazi
["Eldrazi Spawn Token (A)"]				= "Eldrazi Spawn Token (1a)",
["Eldrazi Spawn Token (B)"]				= "Eldrazi Spawn Token (1b)",
["Eldrazi Spawn Token (C)"]				= "Eldrazi Spawn Token (1c)",
--["Plains - B"]							= "Plains (230)",
--["Plains - C"]							= "Plains (231)",
--["Plains - D"]							= "Plains (232)",
--["Island - B"]							= "Island (234)",
--["Island - C"]							= "Island (235)",
--["Island - D"]							= "Island (236)",
--["Swamp - B"]							= "Swamp (238)",
--["Swamp - C"]							= "Swamp (239)",
--["Swamp - D"]							= "Swamp (240)",
--["Mountain - B"]						= "Mountain (242)",
--["Mountain - C"]						= "Mountain (243)",
--["Mountain - D"]						= "Mountain (244)",
--["Forest - B"]							= "Forest (246)",
--["Forest - C"]							= "Forest (247)",
--["Forest - D"]							= "Forest (248)",
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
[751] = { -- Shadowmoor
["AEthertow"]							= "Æthertow",
["Elemental Token (Red)"]				= "Elemental Token (4)",
["Elemental Token (Black|Red)"]			= "Elemental Token (9)",
["Elf Warrior Token (Green)"]			= "Elf Warrior Token (5)",
["Elf Warrior Token (Green|White)"]		= "Elf Warrior Token (12)",
},
[730] = { -- Lorwyn
["Aethersnipe"]							= "Æthersnipe",
["Elemental Token (Green)"]				= "Elemental Token (8)",
["Elemental Token (White)"]				= "Elemental Token (2)",
["Elemental Shaman"]					= "Elemental Shaman Token",
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
["Brothers Yamazaki (160a Sword)"]		= "Brothers Yamazaki (160a)",
["Brothers Yamazaki (160b Pike)"]		= "Brothers Yamazaki (160b)",
},
[580] = { -- Fifth Dawn
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
[280] = { -- Mirage
["Forest (308)"]						= "Forest (1)",
["Forest (309)"]						= "Forest (2)",
["Forest (310)"]						= "Forest (3)",
["Forest (311)"]						= "Forest (4)",
["Island (313)"]						= "Island (1)",
["Island (314)"]						= "Island (2)",
["Island (315)"]						= "Island (3)",
["Island (316)"]						= "Island (4)",
["Mountain (319)"]						= "Mountain (1)",
["Mountain (320)"]						= "Mountain (2)",
["Mountain (321)"]						= "Mountain (3)",
["Mountain (322)"]						= "Mountain (4)",
["Plains (324)"]						= "Plains (1)",
["Plains (325)"]						= "Plains (2)",
["Plains (326)"]						= "Plains (3)",
["Plains (327)"]						= "Plains (4)",
["Swamp (334)"]							= "Swamp (1)",
["Swamp (335)"]							= "Swamp (2)",
["Swamp (336)"]							= "Swamp (3)",
["Swamp (337)"]							= "Swamp (4)",
},
[270] = { -- Weatherlight
["Aether Flash"]						= "Æther Flash",
["Bosium Strip"]						= "Bösium Strip"
},
[230] = { -- Mirage
["Forest (292)"]						= "Forest (1)",
["Forest (293)"]						= "Forest (2)",
["Forest (294)"]						= "Forest (3)",
["Forest (295)"]						= "Forest (4)",
["Island (297)"]						= "Island (1)",
["Island (298)"]						= "Island (2)",
["Island (299)"]						= "Island (3)",
["Island (300)"]						= "Island (4)",
["Mountain (301)"]						= "Mountain (1)",
["Mountain (302)"]						= "Mountain (2)",
["Mountain (303)"]						= "Mountain (3)",
["Mountain (304)"]						= "Mountain (4)",
["Plains (306)"]						= "Plains (1)",
["Plains (307)"]						= "Plains (2)",
["Plains (308)"]						= "Plains (3)",
["Plains (309)"]						= "Plains (4)",
["Swamp (311)"]							= "Swamp (1)",
["Swamp (312)"]							= "Swamp (2)",
["Swamp (313)"]							= "Swamp (3)",
["Swamp (414)"]							= "Swamp (4)",
},
[220] = { -- Alliances
["Aesthir Glider"]								= "Aesthir Glider (1)",
["Aesthir Glider (Moon)"]						= "Aesthir Glider (2)",
["Agent of Stromgald"]							= "Agent of Stromgald (2)",
["Agent of Stromgald (Woman Holding Staff)"]	= "Agent of Stromgald (1)",
["Arcane Denial (Axe)"]							= "Arcane Denial (1)",
["Arcane Denial (Sword)"]						= "Arcane Denial (2)",
["Astrolabe"]									= "Astrolabe (2)",
["Astrolabe (Globe)"]							= "Astrolabe (1)",
["Awesome Presence"]							= "Awesome Presence (2)",
["Awesome Presence (Man Being Chased)"]			= "Awesome Presence (1)",
["Balduvian War-Makers"] 				= "Balduvian War-Makers (1)",
["Balduvian War-Makers (Verison 2)"]	= "Balduvian War-Makers (2)",
["Benthic Explorers"]							= "Benthic Explorers (1)",
["Benthic Explorers (On the Rocks)"]			= "Benthic Explorers (2)",
["Bestial Fury"]								= "Bestial Fury (2)",
["Bestial Fury (Facing Left)"]					= "Bestial Fury (1)",
["Carrier Pigeons"]								= "Carrier Pigeons (1)",
["Carrier Pigeons (Hand)"]						= "Carrier Pigeons (2)",
["Casting of Bones"]							= "Casting of Bones (1)",
["Casting of Bones (Close-up)"]					= "Casting of Bones (2)",
["Deadly Insect"]								= "Deadly Insect (1)",
["Deadly Insect (Red Robe)"]					= "Deadly Insect (2)",
["Elvish Ranger"]								= "Elvish Ranger (1)",
["Elvish Ranger (Woman)"]						= "Elvish Ranger (2)",
["Enslaved Scout"]								= "Enslaved Scout (1)",
["Enslaved Scout (Solitary Goblin)"]			= "Enslaved Scout (2)",
["Errand of Duty"]								= "Errand of Duty (1)",
["Errand of Duty (Page Holding Sword)"]			= "Errand of Duty (2)",
["False Demise"]								= "False Demise (1)",
["False Demise (Cave-in)"]						= "False Demise (2)",
["Feast or Famine"]								= "Feast or Famine (1)",
["Feast or Famine (Falling into Pit)"]			= "Feast or Famine (2)",
["Fevered Strength"]							= "Fevered Strength (2)",
["Fevered Strength (Foaming at Mouth)"]			= "Fevered Strength (1)",
["Foresight"]									= "Foresight (2)",
["Foresight (White Dress)"]						= "Foresight (1)",
["Fyndhorn Druid"] 						= "Fyndhorn Druid (1)",
["Gift of the Woods"]							= "Gift of the Woods (2)",
["Gift of the Woods (Girl/ Lynx)"]				= "Gift of the Woods (1)",
["Gorilla Berserkers"]							= "Gorilla Berserkers (1)",
["Gorilla Berserkers (Closed-Mouth)"]			= "Gorilla Berserkers (2)",
["Gorilla Chieftain"]							= "Gorilla Chieftain (2)",
["Gorilla Chieftain (2 Gorillas)"]				= "Gorilla Chieftain (1)",
["Gorilla Shaman"]								= "Gorilla Shaman (1)",
["Gorilla Shaman (Holding Baby)"]				= "Gorilla Shaman (2)",
["Gorilla War Cry"]								= "Gorilla War Cry (2)",
["Gorilla War Cry (Red Club)"]					= "Gorilla War Cry (1)",
["Guerrilla Tactics"]							= "Guerrilla Tactics (2)",
["Guerrilla Tactics (Kneeling Knight"]			= "Guerrilla Tactics (1)", 
["Insidious Bookworms"]							= "Insidious Bookworms (2)",
["Insidious Bookworms (Horde of Worms)"]		= "Insidious Bookworms (1)",
["Kjeldoran Escort"]							= "Kjeldoran Escort (2)",
["Kjeldoran Escort (Green Dog)"]				= "Kjeldoran Escort (1)",
["Kjeldoran Pride"]								= "Kjeldoran Pride (2)",
["Kjeldoran Pride (Boy|Hawk)"]					= "Kjeldoran Pride (1)",
["Lat-Nam's Legacy"]							= "Lat-Nam's Legacy (1)",
["Lat-Nam's Legacy (2 Blue Men)"]				= "Lat-Nam's Legacy (2)",
["Lim-Dul's High Guard"]				= "Lim-Dûl's High Guard (1)",
--["Lim-Dûl's High Guard"]						= "Lim-Dûl's High Guard (1)",
--["Lim-Dul's High Guard (2)"]			= "Lim-Dûl's High Guard (2)",
["Lim-Dul's High Guard (Red Armor)"]			= "Lim-Dûl's High Guard (2)",
["Martyrdom"]									= "Martyrdom (2)",
["Martyrdom (Wounded on Ground)"]				= "Martyrdom (1)",
["Noble Steeds"]								= "Noble Steeds (2)",
["Noble Steeds (Trees in Forefront)"]			= "Noble Steeds (1)",
["Phantasmal Fiend"]							= "Phantasmal Fiend (2)",
["Phantasmal Fiend (Close-up)"]					= "Phantasmal Fiend (1)",
["Phyrexian Boon"]								= "Phyrexian Boon (1)",
["Phyrexian Boon (Man Held Aloft)"]				= "Phyrexian Boon (2)",
["Phyrexian War Beast"]							= "Phyrexian War Beast (2)",
["Phyrexian War Beast (Facing Right)"]			= "Phyrexian War Beast (1)",
["Reinforcements"]								= "Reinforcements (1)",
["Reinforcements (Line-up)"]					= "Reinforcements (2)",
["Reprisal"]									= "Reprisal (1)",
["Reprisal (Green Monster)"]					= "Reprisal (2)",
["Royal Herbalist"]								= "Royal Herbalist (1)",
["Royal Herbalist (Man)"]						= "Royal Herbalist (2)",
["Soldevi Heretic"]								= "Soldevi Heretic (1)",
["Soldevi Heretic (Scolding Old Men)"]			= "Soldevi Heretic (2)",
["Soldevi Adnate"]	 					= "Soldevi Adnate (1)",
["Soldevi Sage"]								= "Soldevi Sage (1)",
["Soldevi Sage (2 Candles)"]					= "Soldevi Sage (2)",
["Soldevi Sentry"]								= "Soldevi Sentry (2)",
["Soldevi Sentry (Silver Bust)"]				= "Soldevi Sentry (1)",
["Soldevi Steam Beast"] 				= "Soldevi Steam Beast (1)",
["Stench of Decay"]								= "Stench of Decay (2)",
["Stench of Decay (Red Flower)"]				= "Stench of Decay (1)",
["Storm Crow"]									= "Storm Crow (2)",
["Storm Crow (Flying Right)"]					= "Storm Crow (1)",
["Storm Shaman"]								= "Storm Shaman (2)",
["Storm Shaman (Man on Plains)"]				= "Storm Shaman (1)",
["Swamp Mosquito"]								= "Swamp Mosquito (2)",
["Swamp Mosquito (Fallen Tree)"]				= "Swamp Mosquito (1)",
["Taste of Paradise"]							= "Taste of Paradise (2)",
["Taste of Paradise (Holding Fruit)"]			= "Taste of Paradise (1)",
["Undergrowth"]									= "Undergrowth (1)",
["Undergrowth (Holding Ax)"]					= "Undergrowth (2)",
["Varchild's Crusader"]							= "Varchild's Crusader (2)",
["Varchild's Crusader (Castle)"]				= "Varchild's Crusader (1)",
["Veteran's Voice"]								= "Veteran's Voice (1)",
["Veteran's Voice (Side-by-side)"]				= "Veteran's Voice (2)",
["Viscerid Armor"]								= "Viscerid Armor (2)",
["Viscerid Armor (Crashing Wave)"]				= "Viscerid Armor (1)",
["Whip Vine"]									= "Whip Vine (2)",
["Whip Vine (Only Plants)"]						= "Whip Vine (1)",
["Wild Aesthir"] 						= "Wild Aesthir (1)",
["Yavimaya Ancients"]							= "Yavimaya Ancients (2)",
["Yavimaya Ancients (Rearing Horse)"]			= "Yavimaya Ancients (1)",
},
[210] = { --Homelands
["Aether Storm"]						= "Æther Storm",
["Abbey Matron"] 						= "Abbey Matron (1)",
["Aliban's Tower"] 						= "Aliban's Tower (1)",
["Ambush Party"] 						= "Ambush Party (1)",
["Anaba Bodyguard"] 					= "Anaba Bodyguard (1)",
["Anaba Shaman"] 						= "Anaba Shaman (1)",
["Aysen Bureaucrats"] 					= "Aysen Bureaucrats (1)",
["Carapace"] 							= "Carapace (1)",
["Cemetery Gate"] 						= "Cemetery Gate (1)",
["Dark Maze"] 							= "Dark Maze (1)",
["Dry Spell"] 							= "Dry Spell (1)",
["Dwarven Trader"] 						= "Dwarven Trader (1)",
["Feast of the Unicorn"] 				= "Feast of the Unicorn (1)",
["Folk of An-Havva"] 					= "Folk of An-Havva (1)",
["Giant Albatross"] 					= "Giant Albatross (1)",
--["Hungry Mist"] 						= "Hungry Mist (1)",
["Labyrinth Minotaur"] 					= "Labyrinth Minotaur (1)",
["Memory Lapse"] 						= "Memory Lapse (1)",
--["Mesa Falcon"] 						= "Mesa Falcon (1)",
["Reef Pirates"] 						= "Reef Pirates (1)",
["Samite Alchemist"] 					= "Samite Alchemist (1)",
["Shrink"] 								= "Shrink (1)",
["Sengir Bats"] 						= "Sengir Bats (1)",
["Torture"] 							= "Torture (1)",
["Trade Caravan"] 						= "Trade Caravan (1)",
["Willow Faerie"]	 					= "Willow Faerie (1)",
},
[190] = { -- Ice Age
["Lim-Dul's Cohort"] 					= "Lim-Dûl’s Cohort",
["Marton Stromgald"] 					= "Márton Stromgald",
["Lim-Dul's Hex"]						= "Lim-Dûl’s Hex",
["Legions of Lim-Dul"]					= "Legions of Lim-Dûl",
["Oath of Lim-Dul"]						= "Oath of Lim-Dûl",
["Plains (343)"]						= "Plains (1)",
["Plains (344)"]						= "Plains (2)",
["Plains (345)"]						= "Plains (3)",
["Island (334)"]						= "Island (1)",
["Island (335)"]						= "Island (2)",
["Island (336)"]						= "Island (3)",
["Swamp (353)"]							= "Swamp (1)",
["Swamp (354)"]							= "Swamp (2)",
["Swamp (355)"]							= "Swamp (3)",
["Mountain (340)"]						= "Mountain (1)",
["Mountain (341)"]						= "Mountain (2)",
["Mountain (342)"]						= "Mountain (3)",
["Forest (328)"]						= "Forest (1)",
["Forest (329)"]						= "Forest (2)",
["Forest (330)"]						= "Forest (3)",
},
[170] = { -- Fallen Empires
--["Armor Thrull"]					= "Armor Thrull (1)",
["Armor Thrull (Spencer)"]			= "Armor Thrull (2)",
["Armor Thrull (Menges)"]			= "Armor Thrull (3)",
["Armor Thrull (Kirschner)"]		= "Armor Thrull (4)",
--["Basal Thrull"]					= "Basal Thrull (1)",
["Basal Thrull (P. Foglio)"]		= "Basal Thrull (2)",
["Basal Thrull (Ferguson)"]			= "Basal Thrull (3)",
["Basal Thrull (Rush)"]				= "Basal Thrull (4)",
["Brassclaw Orcs"] 					= "Brassclaw Orcs (1)",
["Combat Medic"] 					= "Combat Medic (1)",
["Dwarven Soldier"] 				= "Dwarven Soldier (1)",
["Elven Fortress"] 					= "Elven Fortress (1)",
["Elvish Hunter"] 					= "Elvish Hunter (1)",
["Elvish Scout"] 					= "Elvish Scout (1)",
["Farrel's Zealot"] 				= "Farrel's Zealot (1)",
["Goblin Chirurgeon"] 				= "Goblin Chirurgeon (1)",
["Goblin Grenade"]					= "Goblin Grenade (1)",
["Goblin Grenade (Frazier Art)"]	= "Goblin Grenade (2)",
["Goblin Grenade (Rush Art)"]		= "Goblin Grenade (3)",
["Goblin War Drums"] 				= "Goblin War Drums (1)",
--["High Tide"] 						= "High Tide (1)",
["High Tide (Wave)"] 				= "High Tide (1)",
["High Tide (Merfolk)"] 			= "High Tide (2)",
["High Tide (Coral)"] 				= "High Tide (3)",
--["Homarid"]							= "Homarid (1)",
["Homarid (Hoover)"]				= "Homarid (1)",
["Homarid (Hudson)"]				= "Homarid (2)",
["Homarid (Tedin)"]					= "Homarid (3)",
["Homarid (Wackwitz)"]				= "Homarid (4)",
["Homarid Warrior"] 				= "Homarid Warrior (1)",
--["Hymn to Tourach"] 				= "Hymn to Tourach (1)",
["Hymn to Tourach (Wolf)"] 			= "Hymn to Tourach (1)",
["Hymn to Tourach (Circle)"] 		= "Hymn to Tourach (2)",
["Hymn to Tourach (Table)"] 		= "Hymn to Tourach (3)",
["Hymn to Tourach (Cloak)"] 		= "Hymn to Tourach (4)",
["Icatian Infantry"] 				= "Icatian Infantry (1)",
--["Icatian Javelineers"] 			= "Icatian Javelineers (1)",
["Icatian Javelineers (Benson)"]	= "Icatian Javelineers (1)",
["Icatian Javelineers (Beard)"]		= "Icatian Javelineers (2)",
["Icatian Javelineers (Kirschner)"]	= "Icatian Javelineers (3)",
["Icatian Moneychanger"] 			= "Icatian Moneychanger (1)",
["Icatian Scout"] 					= "Icatian Scout (1)",
["Initiates of the Ebon Hand"]	 	= "Initiates of the Ebon Hand (1)",
["Merseine"] 						= "Merseine (1)",
["Mindstab Thrull"]	 				= "Mindstab Thrull (1)",
["Necrite"] 						= "Necrite (1)",
["Night Soil"] 						= "Night Soil (1)",
["Orcish Spy"] 						= "Orcish Spy (1)",
["Orcish Veteran"] 					= "Orcish Veteran (1)",
["Order of the Ebon Hand"]	 		= "Order of the Ebon Hand (1)",
["Order of Leitbur"]	 			= "Order of Leitbur (1)",
["Spore Cloud"] 					= "Spore Cloud (1)",
["Thallid"] 						= "Thallid (1)",
["Thorn Thallid"] 					= "Thorn Thallid (1)",
["Tidal Flats"] 					= "Tidal Flats (1)",
["Vodalian Soldiers"] 				= "Vodalian Soldiers (1)",
["Vodalian Mage"] 					= "Vodalian Mage (1)",
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
["Army of Allah"] 						= "Army of Allah (1)",
["Bird Maiden"] 						= "Bird Maiden (1)",
["Erg Raiders"] 						= "Erg Raiders (1)",
["Fishliver Oil"] 						= "Fishliver Oil (1)",
["Giant Tortoise"] 						= "Giant Tortoise (1)",
["Hasran Ogress"] 						= "Hasran Ogress (1)",
["Moorish Cavalry"] 					= "Moorish Cavalry (1)",
["Naf's Asp"] 							= "Nafs Asp (1)",
--["Naf's Asp"] 							= "Nafs Asp",
["Naf's Asp"] 							= "Nafs Asp (1)",
["Naf's Asp (2)"] 						= "Nafs Asp (2)",
["Oubliette"] 							= "Oubliette (1)",
["Rukh Egg"] 							= "Rukh Egg (1)",
["Piety"] 								= "Piety (1)",
["Stone-Throwing Devils"] 				= "Stone-Throwing Devils (1)",
["War Elephant"] 						= "War Elephant (1)",
["Wyluli Wolf"] 						= "Wyluli Wolf (1)",
["Mountain (Arabian Nights)"]			= "Mountain",
},
-- special sets
[807] = { --Conspiracy
["AEther Tradewinds"]					= "Æther Tradewinds",
["AEther Searcher"]						= "Æther Searcher",
},
[805] = { -- DD:Jace vs. Vraska
["Aether Adept"]						= "Æther Adept",
["Aether Figment"]						= "Æther Figment",
},
[801] = { -- Commander 2013
["AEthermage's Touch"]					= "Æthermage's Touch",
["Jeleva, Nephalia's Scourge"]			 = "Jeleva, Nephalia’s Scourge",
["Jeleva, Nephalia's Scourge - Oversized"]	 = "Jeleva, Nephalia’s Scourge (oversized)",
['Kongming, "Sleeping Dragon"']			= "Kongming, “Sleeping Dragon”",
["Lim-Dul's Vault"]						= "Lim-Dûl's Vault",
["Sek'Kuar, Deathkeeper"]				= "Sek’Kuar, Deathkeeper",
["Sek'Kuar, Deathkeeper - Oversized"]	= "Sek’Kuar, Deathkeeper (oversized)",
},
[796] = { -- Modern Masters
["Aether Vial"]							= "Æther Vial",
["Aether Spellbomb"]					= "Æther Spellbomb",
["Aethersnipe"]							= "Æthersnipe",
},
[787] = { -- planechase 2012
["Norn's Dominion"]						= "Norn’s Dominion",
},
[785] = { -- DD:Venser vs. Koth
["Aether Membrane"]						= "Æther Membrane",
},
[778] = { -- The Gathering Commander
["AEthersnipe"]							= "Æthersnipe",
["Jotun Grunt"]							= "Jötun Grunt",
["Nezumi Graverobber"]					= "Nezumi Graverobber|Nighteyes the Desecrator",
},
[772] = { -- DD:Elspeth vs. Tezzeret
["Aether Spellbomb"]					= "Æther Spellbomb",
},
[771]  = { -- From the Vault: Relics
["Aether Vial"]							= "Æther Vial",
},
[769] = { -- Archenemy
["Aether Spellbomb"]					= "Æther Spellbomb",
},
[766] = { -- DD:Phyrexia vs. The Coalition 
["Urza's Rage"]							= "Urza’s Rage",
["Minion"]								= "Minion Token",
["Saproling"]							= "Saproling Token",
},
[763] = { -- DD: Garruk vs. Liliana
["Beast Token (3)"]						= "Beast Token (1)",
["Beast Token (4)"]						= "Beast Token (2)",
["Elephant"]							= "Elephant Token",
},
[761] = { -- Planechase
["The Aether Flues"]					= "The Æther Flues",
},
[757] = { -- DD: Divine vs Demonic
["Demon"]								= "Demon Token",
["Spirit"]								= "Spirit Token",
["Thrull"]								= "Thrull Token",
},
[755] = { -- DD: Jace vs. Chandra
["Aethersnipe"]							= "Æthersnipe",
["Elemental Shaman"]					= "Elemental Shaman Token",
},
[740] = { -- DD: Elves vs. Goblins
["Elemental"]							= "Elemental Token",
["Elf Warrior"]							= "Elf Warrior Token",
["Goblin"]								= "Goblin Token",
},
[600] = { -- Unhinged
["Ach! Hans, Run!"]						= '“Ach! Hans, Run!”',
["Our Market Research..."]				= "Our Market Research Shows That Players Like Really Long Card Names So We Made this Card to Have the Absolute Longest Card Name Ever Elemental",
--["Kill Destroy"]						= "Kill! Destroy!",
["Who|What/When|Where/Why"]				= "Who|What|When|Where|Why",
["Yet Another AEther Vortex"]			= "Yet Another Æther Vortex",
["Plains - Full Art"]					= "Plains",
["Island - Full Art"]					= "Island",
["Swamp - Full Art"]					= "Swamp",
["Mountain - Full Art"]					= "Mountain",
["Forest - Full Art"]					= "Forest",
},
[405] = { --  Battle Royale
["Forest (101)"]						= "Forest (1)",
["Forest (102)"]						= "Forest (2)",
["Forest (103)"]						= "Forest (3)",
["Forest (104)"]						= "Forest (4)",
["Forest (105)"]						= "Forest (5)",
["Forest (106)"]						= "Forest (6)",
["Forest (107)"]						= "Forest (7)",
["Forest (108)"]						= "Forest (8)",
["Forest (109)"]						= "Forest (9)",
["Island (110)"]						= "Island (1)",
["Island (111)"]						= "Island (2)",
["Island (112)"]						= "Island (3)",
["Island (113)"]						= "Island (4)",
["Island (114)"]						= "Island (5)",
["Mountain (115)"]						= "Mountain (1)",
["Mountain (116)"]						= "Mountain (2)",
["Mountain (117)"]						= "Mountain (3)",
["Mountain (118)"]						= "Mountain (4)",
["Mountain (119)"]						= "Mountain (5)",
["Mountain (120)"]						= "Mountain (6)",
["Mountain (121)"]						= "Mountain (7)",
["Mountain (122)"]						= "Mountain (8)",
["Mountain (123)"]						= "Mountain (9)",
["Plains (124)"]						= "Plains (1)",
["Plains (125)"]						= "Plains (2)",
["Plains (126)"]						= "Plains (3)",
["Plains (127)"]						= "Plains (4)",
["Plains (128)"]						= "Plains (5)",
["Plains (129)"]						= "Plains (6)",
["Plains (130)"]						= "Plains (7)",
["Plains (131)"]						= "Plains (8)",
["Plains (132)"]						= "Plains (9)",
["Swamp (133)"]							= "Swamp (1)",
["Swamp (134)"]							= "Swamp (2)",
["Swamp (135)"]							= "Swamp (3)",
["Swamp (136)"]							= "Swamp (4)",
},
[380] = { -- Portal Three Kingdoms
['Pang Tong, "Young Phoenix"']			= "Pang Tong, “Young Phoenix”",
['Kongming, "Sleeping Dragon"']			= "Kongming, “Sleeping Dragon”",
},
[320] = { -- Unglued
["B.F.M. (Big Furry Monster Left)"]		= "B.F.M. (Left)",
["B.F.M. (Big Furry Monster Right)"]	= "B.F.M. (Right)",
--["The Ultimate Nightmare of Wizards of the Coast\174 Cu"]	= "The Ultimate Nightmare of Wizards of the Coast® Customer Service",
["The Ultimate Nightmare of Wizards of the Coast® Cu"]	= "The Ultimate Nightmare of Wizards of the Coast® Customer Service",
["Plains - Unglued"]					= "Plains",
["Island - Unglued"]					= "Island",
["Swamp - Unglued"]						= "Swamp",
["Mountain - Unglued"]					= "Mountain",
["Forest - Unglued"]					= "Forest",
},
[310] = { -- Portal Second Age
["Forest (151)"]						= "Forest (1)",
["Forest (152)"]						= "Forest (2)",
["Forest (153)"]						= "Forest (3)",
["Island (154)"]						= "Island (1)",
["Island (155)"]						= "Island (2)",
["Island (156)"]						= "Island (3)",
["Mountain (157)"]						= "Mountain (1)",
["Mountain (158)"]						= "Mountain (2)",
["Mountain (159)"]						= "Mountain (3)",
["Plains (160)"]						= "Plains (1)",
["Plains (161)"]						= "Plains (2)",
["Plains (162)"]						= "Plains (3)",
["Swamp (163)"]							= "Swamp (1)",
["Swamp (164)"]							= "Swamp (2)",
["Swamp (165)"]							= "Swamp (3)",
},
[260] = { -- Portal
["Anaconda (2)"]						= "Anaconda (ST)",
["Blaze (2)"]							= "Blaze (ST)",
["Elite Cat Warrior (2)"]				= "Elite Cat Warrior (ST)",
["Hand of Death (2)"]					= "Hand of Death (ST)",
["Monstrous Growth (2)"]				= "Monstrous Growth (ST)",
["Raging Goblin (2)"]					= "Raging Goblin (ST)",
["Warrior's Charge (2)"]				= "Warrior's Charge (ST)",
["Forest (203)"]						= "Forest (1)",
["Forest (204)"]						= "Forest (2)",
["Forest (205)"]						= "Forest (3)",
["Forest (206)"]						= "Forest (4)",
["Island (207)"]						= "Island (1)",
["Island (208)"]						= "Island (2)",
["Island (209)"]						= "Island (3)",
["Island (210)"]						= "Island (4)",
["Mountain (211)"]						= "Mountain (1)",
["Mountain (212)"]						= "Mountain (2)",
["Mountain (213)"]						= "Mountain (3)",
["Mountain (214)"]						= "Mountain (4)",
["Plains (215)"]						= "Plains (1)",
["Plains (216)"]						= "Plains (2)",
["Plains (217)"]						= "Plains (3)",
["Plains (218)"]						= "Plains (4)",
["Swamp (219)"]							= "Swamp (1)",
["Swamp (220)"]							= "Swamp (2)",
["Swamp (221)"]							= "Swamp (3)",
["Swamp (222)"]							= "Swamp (4)",
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
-- promo
[30] = { -- Friday Night Magic
--["Human|Wolf Token"]					= "Human|Wolf Token",
},
[21]  = { -- Release & Launch Parties Promos
["Ludevic's Test Subject"] 				= "Ludevic’s Test Subject|Ludevic’s Abomination",
["Mondronen Shaman"] 					= "Mondronen Shaman|Tovolar’s Magehunter",
},
[20]  = { -- Magic Player Rewards
["Beast Token (Darksteel)"] 			= "Beast Token (DST)",
["Beast Token (Odyssey)"] 				= "Beast Token (ODY)",
["Bear Token (Odyssey)"] 				= "Bear Token (ODY)",
["Bear Token (Onslaught)"] 				= "Bear Token (ONS)",
["Bird Token (Invasion)"] 				= "Bird Token",
--["Counterspell"] 						= "Counterspell",
["Demon Token (Mirrodin)"] 				= "Demon Token",
["Dragon Token (Onslaught)"] 			= "Dragon Token",
["Elephant Token (Odyssey)"] 			= "Elephant Token (ODY)",
["Elephant Token (Invasion)"] 			= "Elephant Token (INV)",
["Goblin Token (Legions)"] 				= "Goblin Token",
["Goblin Soldier Token (Apocalypse)"] 	= "Goblin Soldier Token",
["Insect Token (Onslaught)"] 			= "Insect Token",
--["Lightning Bolt"] 					= "Lightning Bolt",
["Myr Token (Mirrodin)"] 				= "Myr Token",
["Pentavite Token (Mirrodin)"] 			= "Pentavite Token",
["Rukh Token (8th)"] 					= "Rukh Token",
["Saproling Token (Invasion)"] 			= "Saproling Token",
["Sliver Token (Legions)"] 				= "Sliver Token",
["Soldier Token (Onslaught)"] 			= "Soldier Token",
["Spirit Token (Champions)"] 			= "Spirit Token (CHK)",
["Spirit Token (Planeshift)"] 			= "Spirit Token (PLS)",
["Squirrel Token (Odyssey)"] 			= "Squirrel Token",
["Wurm Token (Odyssey)"] 				= "Wurm Token",
["Zombie Token (Odyssey)"] 				= "Zombie Token",
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
[762] = { --Zendikar
override=true,
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
[23] = { name="Gateway & WPN Promos",
["Fling"]						= { "Fling"				, { "1"  , "2"  } },
["Sylvan Ranger"]				= { "Sylvan Ranger"		, { "1"  , "2"  } },
},	
[10]  = { -- Junior Series
["Elvish Champion"]				= { "Elvish Champion"	, { "E"	, "J" } },
["Glorious Anthem"]				= { "Glorious Anthem"	, { "E"	, "J" , "U" } },
["Royal Assassin"]				= { "Royal Assassin"	, { "E"	, "J" } },
["Sakura-Tribe Elder"]			= { "Sakura-Tribe Elder", { "E"	, "J" , "U" } },
["Shard Phoenix"]				= { "Shard Phoenix"		, { "E"	, "J" , "U" } },
["Slith Firewalker"]			= { "Slith Firewalker"	, { "E"	, "J" } },
["Soltari Priest"]				= { "Soltari Priest"	, { "E"	, "J" , "U" } },
["Whirling Dervish"]			= { "Whirling Dervish"	, { "E"	, "J" , "U" } },
	},	
} -- end table site.variants

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
[808] = { pset={LHpi.Data.sets[808].cardcount.both}, dropped=1, namereplaced=4 }, -- 1 SOON (1 Garruk the Slayer (oversized))
[797] = { failed={ 1 }, namereplaced=2 },
[788] = { failed={ 1 } },
[779] = { namereplaced=1 },
[770] = { namereplaced=3, dropped=6 },-- 6 SOON
[759] = { dropped=6 },
[720] = { pset={ LHpi.Data.sets[720].cardcount.both-1 }, failed={ 1 }, dropped=3+2 },-- 3 SOON, "Kamahl (ST)" missing
[550] = { namereplaced=1 },
[460] = { namereplaced=2, dropped=1 },
[360] = { namereplaced=1 },
[250] = { namereplaced=21 },
[180] = { namereplaced=15 },
[140] = { namereplaced=15, dropped=2 },
--[110] = { namereplaced=15},
[100] = { namereplaced=15},
[90]  = { pset={295-5}, dropped=6, namereplaced=10},-- 6 SOON
-- Expansions
[813] = { pset={LHpi.Data.sets[813].cardcount.both-5}, failed={ 5 }, namereplaced=2 },-- -5 Intro Deck variants
[802] = { namereplaced=2},
[800] = { pset={ LHpi.Data.sets[800].cardcount.both-1 }, failed={ 2 }, namereplaced=3 },-- Holiday Gift Box missing, fail Soldier(League)
[795] = { namereplaced=1, failed={ 1 } },
[793] = { namereplaced=1 },
[791] = { pset={ LHpi.Data.sets[791].cardcount.both-1 }, failed={ 2 } },-- Holiday Gift Box missing, fail Knight(League)
[786] = { failed={ 1 }, namereplaced=5, dropped=1 },-- Angel|Demon Token is Promo, 1 SOON
[784] = { pset={161+1}, namereplaced=15 },-- +1 Checklist
[782] = { pset={276+1}, namereplaced=26 },-- +1 Checklist
[776] = { failed={ 1 }, namereplaced=1 },-- 1 fail is Poison Counter
[775] = { failed={ 1 } },-- -1:Poison Counter
[773] = { failed={ 1 }, namereplaced=2 },-- 1 fail is Poison Counter
[767] = { namereplaced=3 },
[765] = { namereplaced=1 },
[762] = { pset={ 260+20 }, namereplaced=1 },-- +20 non-fullart lands
[758] = { dropped=1 },
[756] = { namereplaced=1 },
--[754] = { namereplaced=1 },
[751] = { pset={LHpi.Data.sets[751].cardcount.both-2}, failed={ 2 }, namereplaced=5, dropped=2 },--2 SOON
[730] = { namereplaced=4 },
[710] = { namereplaced=1 },
[700] = { namereplaced=2 },
[680] = { namereplaced=3 },
[670] = { namereplaced=3 },
[660] = { namereplaced=2 },
[650] = { namereplaced=1 },
[620] = { namereplaced=6 },
[610] = { namereplaced=5 },
[590] = { namereplaced=12, dropped=1 },
[580] = { namereplaced=1 },
[570] = { namereplaced=2 },
[560] = { namereplaced=3, dropped=2 },
[520] = { namereplaced=1, dropped=2 },
[480] = { namereplaced=1, dropped=2 },
[470] = { namereplaced=1 },
[450] = { pset={146}, namereplaced=3, foiltweaked=3 },
[430] = { namereplaced=1, dropped=2 },
[410] = { namereplaced=1 },
[400] = { dropped=1 },
[370] = { namereplaced=1 },
[330] = { namereplaced=1, dropped=2 },
[300] = { namereplaced=1 },
[280] = { namereplaced=20, dropped=2 },
[270] = { namereplaced=2 },
[230] = { namereplaced=20, dropped=2 },
[220] = { namereplaced=106 },
[210] = { namereplaced=24 },
[190] = { namereplaced=20, dropped=2 },-- 2 SOON
[170] = { namereplaced=51-1 },
[150] = { namereplaced=1 },
[120] = { namereplaced=17 },
[130] = { namereplaced=17, dropped=1 },
-- special sets
[812] = { pset={0} },
[810] = { pset={0} },
[807] = { pset={ LHpi.Data.sets[807].cardcount.both+LHpi.Data.sets[807].cardcount.nontrad }, namereplaced=2 },
[805] = { pset={0} },--{ foiltweaked=2, namereplaced=2 },
[801] = { pset={ LHpi.Data.sets[801].cardcount.all-1 }, failed={ 1 }, foiltweaked=15-1, namereplaced=7 },--  "Sydri, Galvanic Genius - Oversized)" missing
[799] = { pset={ LHpi.Data.sets[799].cardcount.both-25 }, foiltweaked=2-2, },
[798] = { pset={20}, dropped=1 }, 
[796] = { namereplaced=3 },
[794] = { pset={ LHpi.Data.sets[794].cardcount.both-27 }, dropped=6, foiltweaked=2-2 },-- 6 SOON
[792] = { pset={ LHpi.Data.sets[792].cardcount.reg }, dropped=LHpi.Data.sets[792].cardcount.repl-1  },
[790] = { pset={ LHpi.Data.sets[790].cardcount.all-8 } },
[787] = { pset={ LHpi.Data.sets[787].cardcount.all }, dropped=2 , namereplaced=1 },--2 SOON, both look wrong :)
[785] = { pset={ LHpi.Data.sets[785].cardcount.both-11 }, namereplaced=1, foiltweaked=2-2 },
[781] = { foiltweaked=2},
[777] = { foiltweaked=2},
[778] = { pset={ LHpi.Data.sets[778].cardcount.reg }, failed={ LHpi.Data.sets[778].cardcount.repl }, namereplaced=3 },
[772] = { pset={ LHpi.Data.sets[772].cardcount.both-11 }, namereplaced=1-1, foiltweaked=2-1 },
[771] = { namereplaced=1},
[769] = { pset={ LHpi.Data.sets[769].cardcount.reg+LHpi.Data.sets[769].cardcount.nontrad }, namereplaced=1, dropped=1 },
[768] = { foiltweaked=5},
[766] = { pset={ LHpi.Data.sets[766].cardcount.both-17 }, failed={ 3 }, foiltweaked=2-2, dropped=4-1, namereplaced=1-1 },
[763] = { pset={ LHpi.Data.sets[763].cardcount.both-9 }, failed={ 1 }, dropped=1, namereplaced=3-1, foiltweaked=2-1 },
[761] = { pset={ LHpi.Data.sets[761].cardcount.all-1 }, failed={ 4+1 }, namereplaced=1, dropped=2 },-- 4 fails are promos,2 SOON, 1 mountain missing
[757] = { pset={ LHpi.Data.sets[757].cardcount.both-2 }, namereplaced=3-1, foiltweaked=2},
[755] = { pset={ LHpi.Data.sets[755].cardcount.both-24 }, namereplaced=2-2, foiltweaked=2-1},
[740] = { pset={ LHpi.Data.sets[740].cardcount.both-9 }, dropped=2, namereplaced=3, foiltweaked=2-2},
[600] = { namereplaced=9, foiltweaked=1 }, 
[440] = { foiltweaked=2 },
[415] = { failed= { 5 }, dropped=28, foiltweaked=1},
[405] = { pset={ LHpi.Data.sets[405].cardcount.reg-1 }, failed={ 1 }, dropped=2, namereplaced=36-2 },-- 2 SOON
[390] = { pset={ LHpi.Data.sets[390].cardcount.reg }, failed={ 1 } },-- Thorn Elemental (oversized) missing
[380] = { pset={180}, namereplaced=2 },
[320] = { namereplaced=8 },
[310] = { namereplaced=15 },
[260] = { pset={228-6-1}, failed={ 7}, dropped=1, namereplaced=27-1 },-- 1 SOON, -6 "DG" variant
[200] = { namereplaced=12 },
-- promos
[31]  = { pset={ LHpi.Data.sets[31].cardcount.reg } },
[30]  = { pset={ LHpi.Data.sets[30].cardcount.all }, failed={ 3 }, foiltweaked=1-1, dropped=4 },--4 SOON, 3 not yet in MA
[26]  = { pset={ 42 }, foiltweaked=18 },
[24]  = { foiltweaked=5 },
[23]  = { pset={ 36 }, failed={ 2 } },
[21]  = { pset={ 24 }, namereplaced=2, foiltweaked=1, dropped=1 },
[20]  = { pset={ 77 }, namereplaced=23, foiltweaked=8 },
[10]  = { pset={ 26 }, dropped=1 },-- 1 SOON
	}--end table site.expected
end--function site.SetExpected()
ma.Log(site.scriptname .. " loaded.")
--EOF