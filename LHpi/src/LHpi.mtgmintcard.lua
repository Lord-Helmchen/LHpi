--*- coding: utf-8 -*-
--[[- LHpi mtgmintcard.com sitescript 
Price import script for Magic Album
uses and needs LHpi library
to import card pricing from www.mtgmintcard.com.

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
added 807,M15
BuildUrl and tables changed for new site structure
site.regex and ParseHtmlData changed for new raw format
BCDPluginPre now handles "SZH (ENG)" card names
added site.pagenumberregex
updated all expected counts
wrap site.expected in site.SetExpected()
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
OFFLINE = true

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
scriptname = "LHpi.mtgmintcard-v" .. libver .. "." .. dataver .. "." .. scriptver .. ".lua"

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
--site.regex = 'class="cardBorderBlack".-(<a.->$[%d.,]+%b<>).-</tr>'
site.regex = 'class="cardBorderBlack".-(<a.->)</tr>'

--- resultregex can be used to display in the Log how many card the source file claims to contain
-- @field #string resultregex
site.resultregex = "Your query of .+ filter.+ returns (%d+) results."

--- pagenumberregex can be used to check for unneeded calls to empty pages
-- see site.BuildUrl in LHpi.mtgmintcard.lua for working example of a multiple-page-setup. 
-- @field #string pagenumberregex
site.pagenumberregex = "page=(%d+)"

--- @field #string currency		not used yet;default "$"
site.currency = "$" -- not used yet
--- @field #string encoding		default "cp1252"
site.encoding = "utf-8" -- claimed by html source

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
	local container = {}

	site.domain = "www.mtgmintcard.com/"
	site.prefix = "mtg/singles/"
	site.suffix = "?page="
--	site.suffix = "?page_show=200&page="
--	site.currency = "&currency_reference=EUR"

	for pagenr=1, site.sets[setid].pages do
--		local url = site.domain .. site.prefix .. site.langs[langid].url .. "-" .. site.frucs[frucid].url .. "/" .. site.sets[setid].url .. site.suffix .. pagenr
		local url = site.domain .. site.prefix .. site.sets[setid].url .. "/" .. site.langs[langid].url .. "-" .. site.frucs[frucid].url .. site.suffix .. pagenr
		if offline then
			url = string.gsub( url, "%?", "_" )
			url = string.gsub( url, "/", "_" )
			container[url] = { isfile = true}
		else
			container[url] = {}
		end -- if offline 
		container[url].langid = langid
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
function site.ParseHtmlData( foundstring , 	urldetails )
	local _start,_end,name = string.find(foundstring, '<a .*href=%b"">([^<]+)</a>' )
	local _start,_end,price = string.find( foundstring , '[$€]([%d.,]+)' )
	if price then
		price = string.gsub( price , "[,.]" , "" )
	else
		price=0
	end
	price = tonumber( price )
	local newCard = { names = { [urldetails.langid] = name }, price = { [urldetails.langid] = price }, foil=urldetails.foilonly }
	if DEBUG then
		LHpi.Log( "site.ParseHtmlData\t returns" .. LHpi.Tostring(newCard) , 2 )
	end
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
		LHpi.Log( "site.BCDpluginPre got " .. card.name .. " from set " .. setid , 2 )
	end
	
	-- mark condition modifier suffixed cards to be dropped
	card.name = string.gsub( card.name , "%(Used%)$" , "%0 (DROP)" )

	--If I ever find out what the encoding is they use here, 
	--add this after "site.encoding == "whatever-this-is" into LHpi.Toutf8
	--decoding in comment assumes utf-8
	card.name = string.gsub( card.name , "\195\130\194\174" , "®" ) -- 0xc3 0x82 0xc2 0xae
	card.name = string.gsub( card.name , "\195\131\194\160" , "à" ) -- 0xc3 0x83 0xc2 0xa0
	card.name = string.gsub( card.name , "\195\131\194\162" , "â" ) -- 0xc3 0x83 0xc2 0xa2
	card.name = string.gsub( card.name , "\195\131\194\169" , "é" )-- 0xc3 0x83 0xc2 0xa9
	card.name = string.gsub( card.name , "\195\131\226\128\160" , "Æ" ) -- 0xc3 0x83 0xe2 0x80 0xa0 is Ã†
	card.name = string.gsub( card.name , "\195\160" , "à" ) -- 0xc3 0xa0
	card.name = string.gsub( card.name , "\226\128\156" , '"' ) -- 0xe2 0x80 0x9c

	card.name = string.gsub( card.name , "%(Chinese Version%)" , "" )	
-- @lib	card.name = string.gsub( card.name , " / " , "|" )

	card.name = string.gsub( card.name , " ships Sep 27" , "") -- Theros Prerelease suffix
	card.name = string.gsub( card.name , " ships Jul 18" , "") -- M15 Prerelease suffix
	
	if setid == 801 or setid == 778 then -- Commander
		card.name = string.gsub(card.name,"%([Oo]versized%)","(oversized) (DROP)")
	elseif setid == 787 then -- Planechase
		card.name = string.gsub(card.name ,"%s*%([Oo]versized%)" ,"" )
	--elseif setid == 753 then
	--	card.foil = true
	-- taken care of by LHpi.Data.sets[753].foilonly
	end
	
	if card.lang[9] then
		if string.find(card.name, "^[^%(%)]+$" ) then
			card.names[9]=card.name
		else
			local _s,_e,namechi,nameeng = string.find(card.name, "(.+)%s*(%b())$")
			if namechi and nameeng then
				if string.find(namechi,"Token%s*$") or string.find(nameeng, "^%([%d/ &]+%)$") then
					card.names[9]=namechi .. nameeng
				else
					card.names[1]=string.gsub(nameeng, "^%((.+)%)", "%1" )
					card.names[9]=string.gsub(namechi,"(.-)%s*$", "%1")
					card.name=card.names[1]
				end
			else
				error("BCDPlugin pattern insufficient!")
			end--if namechi and nameeng then
		end--if
	end--if langid

	return card
end -- function site.BCDpluginPre

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
	[1] = { id=1, url="eng" },
	[9] = { id=2, url="chi" },
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
	[1]= { id=1, name="Foil"	, isfoil=true , isnonfoil=false, url="foil" },
	[2]= { id=2, name="nonFoil"	, isfoil=false, isnonfoil=true , url="reg" },
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
[808]={id = 808, lang = { true , [9]=true }, fruc = { true, true },	pages=10, url = "m15"},
[797]={id = 797, lang = { true , [9]=true }, fruc = { true, true },	pages= 9, url = "m14"},
[788]={id = 788, lang = { true , [9]=true }, fruc = { true ,true }, pages= 9, url = "m13"},
[779]={id = 779, lang = { true , [9]=true }, fruc = { true ,true }, pages= 9, url = "m12"},
[770]={id = 770, lang = { true , [9]=true }, fruc = { true ,true }, pages= 9, url = "m11"}, 
[759]={id = 759, lang = { true , [9]=true }, fruc = { true ,true }, pages= 9, url = "m10"}, 
[720]={id = 720, lang = { true , [9]=true }, fruc = { true ,true }, pages=13, url = "10e"}, 
[630]={id = 630, lang = { true , [9]=false}, fruc = { true ,true }, pages=11, url = "9ed"}, 
[550]={id = 550, lang = { true , [9]=false}, fruc = { true ,true }, pages=11, url = "8ed"}, 
[460]={id = 460, lang = { true , [9]=false}, fruc = { true ,true }, pages=12, url = "7ed"}, -- SZH in site but not in MA
[360]={id = 360, lang = { true , [9]=false}, fruc = { true ,true }, pages=12, url = "6ed"},
[250]={id = 250, lang = { true , [9]=false}, fruc = { false,true }, pages=16, url = "5ed"},
[180]={id = 180, lang = { true , [9]=false}, fruc = { false,true }, pages=15, url = "4ed"}, 
[141]=nil,--Summer Magic
[140]={id = 140, lang = { true , [9]=false}, fruc = { false,true }, pages=11, url = "3ed"},
[139]=nil,--Revised Limited Deutsch
[110]={id = 110, lang = { true , [9]=false}, fruc = { false,true }, pages=10, url = "2ed"}, -- Unlimited 
[100]={id = 100, lang = { true , [9]=false}, fruc = { false,true }, pages=10, url = "leb"}, -- Beta
[90] ={id =  90, lang = { true , [9]=false}, fruc = { false,true }, pages=10, url = "lea"}, -- Alpha 
 -- Expansions
[806]={id = 806, lang = { true , [9]=true }, fruc = { true ,true }, pages= 6, url = "jou"},
[802]={id = 802, lang = { true , [9]=true }, fruc = { true ,true }, pages= 6, url = "bng"},
[800]={id = 800, lang = { true , [9]=true }, fruc = { true ,true }, pages= 9, url = "ths"},
[795]={id = 795, lang = { true , [9]=true }, fruc = { true ,true }, pages= 6, url = "dgm"},
[793]={id = 793, lang = { true , [9]=true }, fruc = { true ,true }, pages= 9, url = "gtc"},
[791]={id = 791, lang = { true , [9]=true }, fruc = { true ,true }, pages=10, url = "rtr"},
[786]={id = 786, lang = { true , [9]=true }, fruc = { true ,true }, pages= 9, url = "avr"},
[784]={id = 784, lang = { true , [9]=true }, fruc = { true ,true }, pages= 6, url = "dka"}, 
[782]={id = 782, lang = { true , [9]=true }, fruc = { true ,true }, pages=10, url = "isd"}, 
[776]={id = 776, lang = { true , [9]=true }, fruc = { true ,true }, pages= 6, url = "nph"},
[775]={id = 775, lang = { true , [9]=true }, fruc = { true ,true }, pages= 6, url = "mbs"},
[773]={id = 773, lang = { true , [9]=true }, fruc = { true ,true }, pages= 9, url = "som"},
[767]={id = 767, lang = { true , [9]=true }, fruc = { true ,true }, pages= 9, url = "roe"},
[765]={id = 765, lang = { true , [9]=true }, fruc = { true ,true }, pages= 6, url = "wwk"},
[762]={id = 762, lang = { true , [9]=true }, fruc = { true ,true }, pages= 9, url = "zen"},
[758]={id = 758, lang = { true , [9]=true }, fruc = { true ,true }, pages= 5, url = "arb"},
[756]={id = 756, lang = { true , [9]=true }, fruc = { true ,true }, pages= 5, url = "con"},
[754]={id = 754, lang = { true , [9]=true }, fruc = { true ,true }, pages= 9, url = "ala"},
[752]={id = 752, lang = { true , [9]=true }, fruc = { true ,true }, pages= 7, url = "eve"},
[751]={id = 751, lang = { true , [9]=true }, fruc = { true ,true }, pages=10, url = "shm"},
[750]={id = 750, lang = { true , [9]=true }, fruc = { true ,true }, pages= 6, url = "mor"},
[730]={id = 730, lang = { true , [9]=true }, fruc = { true ,true }, pages=10, url = "lrw"},
[710]={id = 710, lang = { true , [9]=true }, fruc = { true ,true }, pages= 7, url = "fut"},
[700]={id = 700, lang = { true , [9]=true }, fruc = { true ,true }, pages= 6, url = "plc"},
[690]={id = 690, lang = { true , [9]=false}, fruc = { true ,true }, pages= 5, url = "tsb"},
[680]={id = 680, lang = { true , [9]=true }, fruc = { true ,true }, pages=10, url = "tsp"},
[670]={id = 670, lang = { true , [9]=false}, fruc = { true ,true }, pages= 6, url = "csp"},
[660]={id = 660, lang = { true , [9]=false}, fruc = { true ,true }, pages= 7, url = "dis"},
[650]={id = 650, lang = { true , [9]=false}, fruc = { true ,true }, pages= 6, url = "gpt"},
[640]={id = 640, lang = { true , [9]=false}, fruc = { true ,true }, pages=10, url = "rav"},
[620]={id = 620, lang = { true , [9]=false}, fruc = { true ,true }, pages= 6, url = "sok"},
[610]={id = 610, lang = { true , [9]=false}, fruc = { true ,true }, pages= 6, url = "bok"},
[590]={id = 590, lang = { true , [9]=false}, fruc = { true ,true }, pages=10, url = "chk"},
[580]={id = 580, lang = { true , [9]=true }, fruc = { true ,true }, pages= 6, url = "5dn"},
[570]={id = 570, lang = { true , [9]=false}, fruc = { true ,true }, pages= 6, url = "dst"},
[560]={id = 560, lang = { true , [9]=false}, fruc = { true ,true }, pages=10, url = "mrd"},
[540]={id = 540, lang = { true , [9]=false}, fruc = { true ,true }, pages= 5, url = "scg"},
[530]={id = 530, lang = { true , [9]=false}, fruc = { true ,true }, pages= 5, url = "lgn"}, -- SZH in site but not in MA
[520]={id = 520, lang = { true , [9]=false}, fruc = { true ,true }, pages=12, url = "ons"}, -- SZH in site but not in MA
[510]={id = 510, lang = { true , [9]=false}, fruc = { true ,true }, pages= 6, url = "jud"}, -- SZH in site but not in MA
[500]={id = 500, lang = { true , [9]=false}, fruc = { true ,true }, pages= 5, url = "tor"}, -- SZH in site but not in MA
[480]={id = 480, lang = { true , [9]=false}, fruc = { true ,true }, pages=12, url = "ody"}, -- SZH in site but not in MA
[470]={id = 470, lang = { true , [9]=false}, fruc = { true ,true }, pages= 5, url = "apc"},
[450]={id = 450, lang = { true , [9]=false}, fruc = { true ,true }, pages= 6, url = "pls"},
[430]={id = 430, lang = { true , [9]=false}, fruc = { true ,true }, pages=15, url = "inv"}, -- SZH in site but not in MA
[420]={id = 420, lang = { true , [9]=false}, fruc = { true ,true }, pages= 4, url = "pcy"},
[410]={id = 410, lang = { true , [9]=false}, fruc = { true ,true }, pages= 6, url = "nms"},
[400]={id = 400, lang = { true , [9]=false}, fruc = { true ,true }, pages=12, url = "mmq"},
[370]={id = 370, lang = { true , [9]=false}, fruc = { true ,true }, pages= 6, url = "uds"},
[350]={id = 350, lang = { true , [9]=false}, fruc = { true ,true }, pages= 6, url = "ulg"},
[330]={id = 330, lang = { true , [9]=false}, fruc = { true ,true }, pages=13, url = "usg"},
[300]={id = 300, lang = { true , [9]=false}, fruc = { false,true }, pages= 6, url = "exo"},
[290]={id = 290, lang = { true , [9]=false}, fruc = { false,true }, pages= 6, url = "sth"},
[280]={id = 280, lang = { true , [9]=false}, fruc = { false,true }, pages=13, url = "tmp"},
[270]={id = 270, lang = { true , [9]=false}, fruc = { false,true }, pages= 6, url = "wth"},
[240]={id = 240, lang = { true , [9]=false}, fruc = { false,true }, pages= 6, url = "vis"},
[230]={id = 230, lang = { true , [9]=false}, fruc = { false,true }, pages=14, url = "mir"},
[220]={id = 220, lang = { true , [9]=false}, fruc = { false,true }, pages= 6, url = "all"},
[210]={id = 210, lang = { true , [9]=false}, fruc = { false,true }, pages= 5, url = "hml"},
[190]={id = 190, lang = { true , [9]=false}, fruc = { false,true }, pages=15, url = "ice"},
[170]={id = 170, lang = { true , [9]=false}, fruc = { false,true }, pages= 4, url = "fem"},
[160]={id = 160, lang = { true , [9]=false}, fruc = { false,true }, pages= 5, url = "drk"},
[150]={id = 150, lang = { true , [9]=false}, fruc = { false,true }, pages=12, url = "leg"},
[130]={id = 130, lang = { true , [9]=false}, fruc = { false,true }, pages= 4, url = "atq"},
[120]={id = 120, lang = { true , [9]=false}, fruc = { false,true }, pages= 3, url = "arn"},
-- special sets
[807]={id = 807, lang = { true , [9]=false}, fruc = { true , true }, pages= 8, url = "cns"},--Conspiracy
[805]={id = 805, lang = { true , [9]=false}, fruc = { true , true }, pages= 3, url = "ddm"},--Duel Decks: Jace vs. Vraska
--[804]=nil,--Challenge Deck: Battle the Horde
--[803]=nil,--Challenge Deck: Face the Hydra
[801]={id = 801, lang = { true , [9]=false}, fruc = { true , true }, pages=12, url = "c13"},--Commander 2013 Edition
[799]={id = 799, lang = { true , [9]=false}, fruc = { true , true }, pages= 3, url = "hvm"},--Duel Decks: Heroes vs. Monsters
[798]={id = 798, lang = { true , [9]=false}, fruc = { true , false}, pages= 1, url = "ftv"},--From the Vault: Twenty
[796]={id = 796, lang = { true , [9]=false}, fruc = { true , true }, pages= 9, url = "mm"},--Modern Masters
[794]={id = 794, lang = { true , [9]=false}, fruc = { true , true }, pages= 3, url = "ddk"},--Duel Decks: Sorin vs. Tibalt
[792]=nil,--Commander's Arsenal
[790]={id = 790, lang = { true , [9]=false}, fruc = { true , true }, pages= 3, url = "ddj"},--Duel Decks: Izzet vs. Golgari
[789]={id = 789, lang = { true , [9]=false}, fruc = { true , false}, pages= 1, url = "fvr"},--From the Vault: Realms
[787]={id = 787, lang = { true , [9]=false}, fruc = { true , true }, pages= 7, url = "p12"},--Planechase 2012
[785]={id = 785, lang = { true , [9]=false}, fruc = { true , true }, pages= 3, url = "ddi"},--Duel Decks: Venser vs. Koth
[783]={id = 783, lang = { true , [9]=false}, fruc = { true , false}, pages= 1, url = "pd3"},--Premium Deck Series: Graveborn
[781]={id = 781, lang = { true , [9]=false}, fruc = { false, true }, pages= 3, url = "avn"},--Duel Decks: Ajani vs. Nicol Bolas
[780]={id = 780, lang = { true , [9]=false}, fruc = { true , false}, pages= 1, url = "v11"},--From the Vault: Legends
[778]={id = 778, lang = { true , [9]=false}, fruc = { true , true }, pages=11, url = "com"},--Commander
[777]={id = 777, lang = { true , [9]=false}, fruc = { true , true }, pages= 3, url = "ddg"},--Duel Decks: Knights vs. Dragons
[774]={id = 774, lang = { true , [9]=false}, fruc = { true , false}, pages= 2, url = "h10"},--Premium Deck Series: Fire and Lightning
[772]={id = 772, lang = { true , [9]=false}, fruc = { true , true }, pages= 3, url = "evt"},--Duel Decks: Elspeth vs. Tezzeret
--[771]={id = 753, lang = { true , [9]=true }, fruc = { true , false}, pages= 2, url = "From+the+Vault%3A+Relics"},--From the Vault: Relics
[769]={id = 769, lang = { true , [9]=false}, fruc = { false, true }, pages= 7, url = "arc"},--Archenemy   
[768]={id = 768, lang = { true , [9]=false}, fruc = { true , true }, pages= 4, url = "dpa"},--Duels of the Planeswalkers
[766]={id = 766, lang = { true , [9]=false}, fruc = { false, true }, pages= 3, url = "pvc"},--Duel Decks: Phyrexia vs. The Coalition
[764]={id = 764, lang = { true , [9]=false}, fruc = { true , false}, pages= 2, url = "h09"},--Premium Deck Series: Slivers
[763]={id = 763, lang = { true , [9]=false}, fruc = { true , true }, pages= 2, url = "gvl"},--Duel Decks: Garruk vs. Liliana
[761]=nil,--Planechase
[760]={id = 760, lang = { true , [9]=false}, fruc = { true , false}, pages= 1, url = "v09"},--From the Vault: Exiled
[757]={id = 757, lang = { true , [9]=false}, fruc = { true , true }, pages= 2, url = "dvd"},--Duel Decks: Divine vs. Demonic
[755]={id = 755, lang = { true , [9]=false}, fruc = { true , true }, pages= 2, url = "jvc"},--Duel Decks: Jace vs. Chandra
[753]={id = 753, lang = { true , [9]=false}, fruc = { false, true }, pages= 1, url = "drb"},--From the Vault: Dragons
[740]=nil,--Duel Decks: Elves vs. Goblins
[675]=nil,--Coldsnap Theme Decks
[635]=nil,--Magic Encyclopedia
[600]={id = 600, lang = { true , [9]=false}, fruc = { false, true }, pages= 5, url = "unh"},--Unhinged
[490]={id = 490, lang = { true , [9]=false}, fruc = { false, true }, pages= 2, url = "dkm"},--Deckmaster
[440]={id = 440, lang = { true , [9]=false}, fruc = { false, true }, pages= 3, url = "btd"},--Beatdown Box Set
[415]=nil,--Starter 2000   
[405]={id = 405, lang = { true , [9]=false}, fruc = { false, true }, pages= 4, url = "brb"},--Battle Royale Box Set
[390]=nil,--Starter 1999
[380]=nil,--Portal Three Kingdoms   
[340]={id = 340, lang = { true , [9]=false}, fruc = { false, true }, pages= 1, url = "ath"},--Anthologies
[320]={id = 320, lang = { true , [9]=false}, fruc = { false, true }, pages= 4, url = "ugl"},--Unglued
[310]=nil,--Portal Second Age   
[260]={id = 260, lang = { true , [9]=false}, fruc = { false, true }, pages= 8, url = "por"},--Portal
[235]=nil,--Multiverse Gift Box
[225]=nil,--Introductory Two-Player Set
[201]=nil,--Renaissance
[200]={id = 200, lang = { true , [9]=false}, fruc = { false, true }, pages= 4, url = "chr"},--Chronicles
[70] ={id =  70, lang = { true , [9]=false}, fruc = { false, true }, pages= 2, url = "vanguard"},--Vanguard
[69] =nil,--Box Topper Cards
-- World Championship and Promo sets: sorting out the two single pages seems more trouble than it's worth
--[50] ={id =  50, lang = { true , [9]=false}, fruc = { true , false}, pages=17, url = "ppr"},--Full Box Promotion
--[25] ={id =  25, lang = { true , [9]=false}, fruc = { true , false}, pages=17, url = "ppr"},--Judge Gift Cards
--[24] ={id =  24, lang = { true , [9]=false}, fruc = { false, true }, pages=17, url = "ppr"},--Champs Promos
--[22] ={id =  22, lang = { true , [9]=false}, fruc = { false, true }, pages=17, url = "ppr"},--Prerelease Promos
--[21] ={id =  21, lang = { true , [9]=false}, fruc = { false, true }, pages=17, url = "ppr"},--Release & Launch Parties Promos
--[10] ={id =  10, lang = { true , [9]=false}, fruc = { true , false}, pages=17, url = "ppr"},--Junior Series Promos
--[7]  ={id =   7, lang = { true , [9]=false}, fruc = { false, true }, pages=17, url = "ppr"},--Magazine Inserts
--[5]  ={id =   5, lang = { true , [9]=false}, fruc = { false, true }, pages=17, url = "ppr"},--Book Inserts
--[2]  ={id =   2, lang = { true , [9]=false}, fruc = { false, true }, pages=17, url = "ppr"},--DCI Legend Membership
} -- end table site.sets

--[[- card name replacement tables.

  fields are for subtables indexed by #number setid.
 { #number (setid)= #table { #string (oldname)= #string , ... } , ... }
 
 @type site.namereplace
 @field [parent=#site.namereplace] #string name
]]
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
["Eldrazi Spawn Token (Aleksi Briclot)"] 		= "Eldrazi Spawn (1a)",
["Eldrazi Spawn Token (Mark Tedin)"] 			= "Eldrazi Spawn (1b)",
["Eldrazi Spawn Token (Veronique Meignaud)"]	= "Eldrazi Spawn (1c)",
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
--[690] = { -- Time Spiral Timeshifted
--["XXValor"]								= "Valor",
--},
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
[807] = { --Conspiracy
["Æther Searcher(Aether Searcher)"]		= "Æther Searcher",
},
[805] = { --Duel Decks: Jace vs. Vraska
["Aether Adept(Æther Adept)"]			= "Æther Adept",
["Aether Figment(Æther Figment)"]		= "Æther Figment",
},
[801] = { -- Commander 2013
["Lim-Dûl’s Vault(Lim-Dul’s Vault)"]	= "Lim-Dûl’s Vault",
["Kongming, “Sleeping Dragon“"]			= "Kongming, “Sleeping Dragon”",
},
[796] = { -- Modern Masters
["Aethersnipe (Æthersnipe)"]			= "Æthersnipe",
["Aether Spellbomb (Æther Spellbomb)"]	= "Æther Spellbomb",
["Aether Vial (Æther Vial)"]			= "Æther Vial",
},
[787] = { -- Planechase 2012 Edition
["Chaotic AEther"]						= "Chaotic Æther",
},
[780] = { -- From the Vault: Legends
["Sharuum, the Hegemon"]				= "Sharuum the Hegemon",
},
[766] = { -- Duel Decks: Phyrexia vs. The Coalition
["Urza's Rage"]							= "Urza’s Rage",
},
[763] = { -- Duel Decks: Garruk vs. Liliana
["Beast Token T1"]						= "Beast (1)",
["Beast Token T2"]						= "Beast (2)",
},
[600] = { -- Unhinged
["Who|What/When|Where/Why"]				= "Who|What|When|Where|Why",
["“Ach! Hans, Run!“"]					= "“Ach! Hans, Run!”",
},
[490] = { -- Deckmasters
["Lim-Dul's High Guard"]				= "Lim-Dûl’s High Guard",
},
[320] = { -- Unglued
["B.F.M. (Big Furry Monster)(Left)"]	= "B.F.M. (Left)",
["B.F.M. (Big Furry Monster)(Right)"]	= "B.F.M. (Right)",
["B.F.M. (Big Furry Monster)"]			= "B.F.M.",--TODO grep P/T to distinguish left/right
--["Chicken à la King"]					= "Chicken à la King",
--["The Ultimate Nightmare ..."]			= "The Ultimate Nightmare of Wizards of the Coast® Customer Service",
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
[799] = {override=true},
[794] = {override=true},
[790] = {override=true},
[785] = {override=true},
[777] = {override=true},
[772] = {override=true},
[768] = {override=true},
[766] = {override=true},
[763] = {override=true},
[757] = {override=true},
[755] = {override=true},

} -- end table foiltweak

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
--TODO reduce amount of hardcoded numbers
-- Core sets
[797] = { pset={ [9]=262-13 }, failed={ [9]=13}, namereplaced=4 }, -- 13 tokens
[788] = { pset={ [9]=249 }, failed={[9]=11} },-- fail SZH tokens
[779] = { pset={ [9]=249 }, failed={[9]=7} },-- fail SZH tokens
[770] = { namereplaced=4, pset={ [9]=249 }, failed={[9]=6} },-- fail SZH tokens
[759] = { pset={ [9]=249-20 }, failed={[9]=8}, dropped=8 },-- no SZH lands, fail SZH tokens
[720] = { pset={ [9]=383-20 }, failed={[9]=6}, dropped=3 }, -- no SZH lands, fail SZH tokens	
[630] = { pset={ 359-31 } },
[550] = { pset={ 357-27 } },
[460] = { pset={ 350-20 }, dropped=3 },
[360] = { pset={ 350-20 }, dropped=17 },
[250] = { pset={ 449-20 }, dropped=49 },
[180] = { pset={ 378-15 }, dropped=82 },
[140] = { pset={ 306-15 }, dropped=32 },
[110] = { dropped=1 },
[100] = { pset={ 302-19 } },
[90]  = {namereplaced=4},
-- Expansions
[806] = {pset={[9]=165}, failed={[9]=6}},-- fail SZH tokens
[802] = {namereplaced=8, pset={[9]=165}, failed={[9]=11}},-- fail SZH tokens
[800] = {namereplaced=10, pset={[9]=249}, failed={[9]=11}},-- fail SZH tokens
[795] = { namereplaced=4, pset={ [9]=156 }, failed={[9]=1} },-- fail SZH tokens
[793] = { pset={ [9]=249 }, failed={[9]=8} },-- fail SZH tokens
[791] = { pset={ [9]=274 }, failed={[9]=12} },-- fail SZH tokens
[786] = { pset={ 252-1, [9]=244-1 }, failed={[9]=8}, namereplaced=8 },-- missing 1 swamp, fail SZH tokens
[784] = { pset={ [9]=158 }, failed={[9]=3} },-- fail SZH tokens
[782] = { pset={ 276+1, [9]=264 }, failed={[9]=12}, namereplaced=15 },-- fail SZH tokens, +1 is Checklist
[776] = { pset={ [9]=175 }, failed={[9]=4} },-- fail SZH tokens
[775] = { pset={160-1, [9]=155}, dropped=1 },-- no ENG zombie token, no SZH tokens
[773] = { namereplaced=4, pset={[9]=249+1}, failed={1, [9]=9} },-- fail SZH tokens
[767] = { pset={ [9]=248 }, failed={[9]=7}, namereplaced=6 },-- fail SZH tokens
[765] = { pset={ [9]=145 } },-- no SZH tokens
[756] = { pset={ [9]=145 } },-- no SZH tokens
[762] = { pset={ [9]=249 } },-- no SZH tokens
[758] = { pset={ [9]=145 }, failed={[9]=4} },-- fail SZH tokens
[756] = { pset={ [9]=145 }, dropped=1 },-- no SZH tokens
[754] = { pset={ [9]=249 }, failed={[9]=9}, namereplaced=1, dropped=2 },-- fail SZH tokens
[752] = { pset={ [9]=180 }, failed={[9]=7} },-- fail SZH tokens
[751] = { pset={ [9]=301-20 }, failed={[9]=12}, namereplaced=8 },-- fail SZH tokens, no SZH lands
[750] = { pset={ [9]=150 } },-- no SZH tokens
[730] = { pset={ [9]=301-1 }, failed={[9]=11}, dropped=2, namereplaced=4 },-- -1 is missing "Changeling Berserker" (SZH), fail SZH tokens
[710] = { dropped=2 },
[700] = { dropped=2 },
[690] = { dropped=1 },
[680] = { pset={ [9]=4 }, dropped=1 },
[660] = { dropped=1 },
[640] = { dropped=2 },
[620] = { dropped=1 },
[610] = { dropped=2, namereplaced=4 },
[580] = { dropped=2 },
[570] = { dropped=1 },
[560] = { pset={ 306-20}, dropped=4 },
[540] = { dropped=3 },
[530] = { dropped=2 },
[520] = { namereplaced=1, dropped=6 },
[510] = { dropped=16 },
[500] = { dropped=7 },
[480] = { pset={ 350-20 }, 	dropped=29 },
[470] = { dropped=3, namereplaced=1 },
[450] = { pset={ 146-3 }, dropped=23 },
[430] = { dropped=96 },
[420] = { pset={ 143-60 }, dropped=8 },
[410] = { pset={ 143-1 }, dropped=9 },
[400] = { pset={ 350-20 }, dropped=13 },
[370] = { dropped=9 },
[350] = { dropped=11 },
[330] = { pset={ 350-20 }, dropped=31 }, -- no lands
[300] = { dropped=10 },
[290] = { dropped=19 },
[280] = { pset={ 350-20 }, dropped=53 },
[270] = { dropped=8 },
[240] = { dropped=9 },
[230] = { pset={ 350-21 }, dropped=67 },
[220] = { dropped=10 },
[210] = { dropped=6 },
[190] = { pset={ 383-15 }, dropped=81 },-- no basic lands
[170] = { dropped=18 },
[160] = { dropped=8 },
[150] = { dropped=22, namereplaced=1 },
[130] = { dropped=7, namereplaced=1 },
[120] = { dropped=12 },
-- special sets
[807] = { pset={ LHpi.Data.sets[807].cardcount.both+LHpi.Data.sets[807].cardcount.nontr }, failed={ 9 }, namereplaced=2 },--no tokens
[805] = { namereplaced=2, foiltweaked=2, pset={ 89-1 } }, -- -1 token
[801] = { pset={ LHpi.Data.sets[801].cardcount.reg+LHpi.Data.sets[801].cardcount.overs }, failed={ LHpi.Data.sets[801].cardcount.overs }, dropped=LHpi.Data.sets[801].cardcount.overs, namereplaced=2 },
[796] = { namereplaced=6},
[794] = { pset={ 81-12-1 } },-- -16 basic lands, -1 token
[790] = { pset={ 91-16-1 } },-- -16 basic lands, -1 token
[787] = { pset={ LHpi.Data.sets[787].cardcount.reg-1+LHpi.Data.sets[787].cardcount.nontr }, namereplaced=1 },-- missing Pollenbright Wings 
[785] = { pset={ 79-2 } },-- -2 tokens
[781] = { pset={ LHpi.Data.sets[781].cardcount.reg-1 }, foiltweaked=2 },
[780] = { namereplaced=1},
[778] = { pset={ LHpi.Data.sets[778].cardcount.reg-14 }, failed={ 1 }, dropped=LHpi.Data.sets[778].cardcount.overs },
[772] = { pset={ 80-8-1 } },-- -8 basic lands, -1 token
[769] = { pset={ 150+45 } },-- all 45 Schemes (nontraditional)
[768] = { pset={ 113-16 } },-- -16 basic lands
[766] = { pset={LHpi.Data.sets[766].cardcount.reg+LHpi.Data.sets[766].cardcount.tok-1}, namereplaced=1},-- missing Foresst(71)
[763] = { pset={ 66-12 }, namereplaced=2 },
[600] = { pset={ 141-2 }, namereplaced=2 },--'Kill! Destroy!' and 'Super Secret Tech' missing
[490] = { pset={ 58-3 }, namereplaced=1, foiltweaked=1 },-- -3 premium
[440] = { foiltweaked=2 },
[340] = { pset={ 1} },
[320] = { dropped=3, namereplaced=2 },
[260] = { dropped=27, pset={228-20-13} },-- no(20) basic lands, no(13) "ST"/"GT" variants
[200] = { pset={ 125-1 } },-- "Wall of Shadows" missing
[70]  = { pset={ LHpi.Data.sets[70].cardcount.nontr } }-- all 32 Characters (nontraditional)
	}--end table site.expected
end--function site.SetExpected
--EOF