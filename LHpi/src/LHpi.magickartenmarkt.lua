--*- coding: utf-8 -*-
--[[- LHpi magiccardmarket.eu sitescript 
Price import script for Magic Album
uses and needs LHpi library
to import card pricing from www.magiccardmarket.eu.

Inspired by and loosely based on "MTG Mint Card.lua" by Goblin Hero, Stromglad1 and "Import Prices.lua" by woogerboy21;
who generously granted permission to "do as I like" with their code;
everything else Copyright (C) 2012-2016 by Christian Harms.
If you want to contact me about the script, try its release thread in http://www.slightlymagic.net/forum/viewforum.php?f=32

@module LHpi.site
@author Christian Harms
@copyright 2012-2016 Christian Harms except parts by Goblin Hero, Stromglad1 or woogerboy21
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
2.17.10.5
start SOI branch
set options to dev prefs again
added 831,830,829,828,827,34
updated 818,53,52,34,31,30,25,22,21
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
-- set to false if you prefer speed over sanity checks.
-- @field [parent=#global] #boolean CHECKEXPECTED
--CHECKEXPECTED = false

--[[- choose between available price types; defaults to 5 ("AVG" prices).
 	[1] = "SELL",	--Average price of articles ever sold of this product
	[2] = "LOW",	--Current lowest non-foil price (all conditions)
	[3] = "LOWEX+",	--Current lowest non-foil price (condition EX and better)
	[4] = "LOWFOIL",--Current lowest foil price
	[5] = "AVG",	--Current average non-foil price of all available articles of this product
	[6] = "TREND",	--Trend of AVG 

 @field #number useAsRegprice
 @field #number useAsFoilprice
]]
local useAsRegprice=5
local useAsFoilprice=6

--local mkmtokenfile = "LHpi.mkm.tokens.example"
local mkmtokenfile = "LHpi.mkm.tokens.DarkHelmet"

--- use a persistent counter of all OAuth requests sent to the server.
-- this could be helpful, as MKM's server will respond with http 429 errors
-- after 5.000 requests.
-- @field #boolean COUNTREQUESTS
local COUNTREQUESTS = true

--  Don't change anything below this line unless you know what you're doing :-) --

--- reset the persistent request counter to 0.
-- MKM's server resets the request count at at 0:00 CE(S)T,
-- so we would want to be able to start counting at 0 again. 
-- 
-- Having this here is mostly in preparation for when/if we can do without mkm-helper
-- running outside of MA.
-- For now, the prefered method to reset the counter is from LHpi.mkm-helper.lua.
-- 
-- @field #boolean COUNTREQUESTS
local RESETCOUNTER = false

--- choose how the site sends the requested data.
-- mkm api offers json and xml format. Only json parsing is implemented yet,
-- and we need json anyways to read the mkm token file :)
-- @field #string responseFormat	"json" or "xml"
local responseFormat = "json"

--- Probably only need appToken,appSecret and can do without accessToken,accessTokenSecret.
-- Would need a token set of an MKM-approved widget app.
local widgetonly = false
--- use mkm sandbox instead of live server.
-- @field #boolean sandbox
local sandbox = false

--- also complain if drop,namereplace or foiltweak count differs; default false
-- @field [parent=#global] #boolean STRICTEXPECTED
STRICTEXPECTED = true

--- if true, exit with error on object type mismatch, else use object type 0 (all);	default true
-- @field [parent=#global] #boolean STRICTOBJTYPE
--STRICTOBJTYPE = false

--- log to seperate logfile instead of LHpi.log; default false
-- @field [parent=#global] #boolean SAVELOG
SAVELOG = true

---	read source data from #string savepath instead of site url; default false
-- @field [parent=#global] #boolean OFFLINE
OFFLINE = true--download from dummy, only change to false for release

--- save a local copy of each source html to #string savepath if not in OFFLINE mode; default false
-- @field [parent=#global] #boolean SAVEHTML
SAVEHTML = true

--- save price table to file before importing to MA; default false
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
local libver = "2.17"
--- revision of the LHpi library datafile to use
-- @field #string dataver
local dataver = "10"
--- sitescript revision number
-- @field  string scriptver
local scriptver = "5"
--- should be similar to the script's filename. Used for loging and savepath.
-- @field #string scriptname
local scriptname = "LHpi.magickartenmarkt-v".. libver .. "." .. dataver .. "." .. scriptver .. ".lua"
--- savepath for OFFLINE (read) and SAVEHTML (write). must point to an existing directory relative to MA's root.
-- set by LHpi lib unless specified here.
-- Can also be set externally via global variable.
-- @field  #string savepath
--local savepath = "Prices\\" .. string.gsub( scriptname , "%-v%d+%.%d+%.lua$" , "" ) .. "\\"
local savepath = savepath -- keep external global savepath
--- log file name. must point to (nonexisting or writable) file in existing directory relative to MA's root.
-- set by LHpi lib unless specified here. Defaults to LHpi.log unless SAVELOG is true.
-- Can also be set externally via global variable.
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
site={ scriptname=scriptname, dataver=dataver, logfile=logfile or nil, savepath=savepath or nil }

-- add to site namespace for use in mkm-helper
site.useAsRegprice=useAsRegprice
site.useAsFoilprice=useAsFoilprice

--[[- regex matches shall include all info about a single card that one html-file has,
 i.e. "*CARDNAME*FOILSTATUS*PRICE*".
 it will be chopped into its parts by site.ParseHtmlData later. 
 @field [parent=#site] #string regex
]]
--site.regex = '{"idProduct".-"countFoils":%d+}'
site.regex = '.(%b{})'

--- resultregex can be used to display in the Log how many card the source file claims to contain
-- @field #string resultregex
site.resultregex = nil

--- pagenumberregex can be used to check for unneeded calls to empty pages
-- see site.BuildUrl in LHpi.mtgmintcard.lua for working example of a multiple-page-setup. 
-- @field #string pagenumberregex
site.pagenumberregex = nil

--- @field #string currency		not used yet;default "$"
site.currency = "€"
--- @field #string encoding		default "cp1252"
site.encoding="utf8"

--- support for global workdir, if used outside of Magic Album/Prices folder. Do not change here!
-- Can be set externally via global variable.
-- @field #string workdir
local workdir = workdir or "Prices\\"

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
	LHpi.Log( "LHpi lib is ready for use." ,0)
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
 
 for LHpi.mkm, we need to configure and prepare the oauth client.
@param #table mode { #boolean helper, ... }
	-- nil 			if called by Magic Album
	-- helper		true if called as library by LHpi.mkm-helper
	-- mode.json or mode.xml	to select mkm response format (default json, xml not implemented)
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
	LHpi.Log(site.scriptname.." started site.Initialize():" ,1)
	if sandbox then
		LHpi.Log("using mkm sandbox instead of live server!" ,1)
		print("using mkm sandbox instead of live server!")
		LHpi.savepath = string.gsub(LHpi.savepath,"\\+$",".sandbox\\")
	end--if sandbox
	if OFFLINE~=true then
		if not (mode.helper or mode.update) then
			error("LHpi.magickartenmarkt only works in OFFLINE mode. Use LHpi.mkm-helper.lua to fetch source data!")
		end
	end
	if mode.helper then
		print("starting LHpi.magickartenmarkt.lua in helper mode")
		--prevent sitescript from overwriting LHpi lib
		function ImportPrice()
			error("ImportPrice disabled by helper mode!")
		end
		LHpi.Log(site.scriptname .. " running as helper. Function ImportPrice() removed." ,1)
	end
	if RESETCOUNTER  or ( not ma.GetFile (LHpi.savepath.."LHpi.mkm.requestcounter") )then
		LHpi.Log("0",0,LHpi.savepath.."LHpi.mkm.requestcounter",0)
	end
	useAsRegprice = useAsRegprice or 3
	useAsFoilprice = useAsFoilprice or 5	
	LHpi.Log(string.format("Importing %q prices into MA regular price column",site.priceTypes[useAsRegprice].type) ,1)
	LHpi.Log(string.format("Importing %q prices into MA foil price column",site.priceTypes[useAsFoilprice].type) ,1)
	if not require then
		LHpi.Log("trying to work around Magic Album lua sandbox limitations..." ,1)
		--emulate require(modname) using dofile; only works for lua files, not dlls.
		local packagePath = workdir..'lib\\ext\\'
		require = function (fname)
			local donefile
			donefile = dofile( packagePath .. fname .. ".lua" )
			return donefile
		end-- function require
	else
		package.path = workdir..'lib\\ext\\?.lua;' .. package.path
		package.cpath= workdir..'lib\\bin\\?.dll;' .. package.cpath
		--print(package.path.."\n"..package.cpath)
	end
	if mode.json then
		responseFormat = "json"
	elseif mode.xml then
		responseFormat = "xml"
	end 
	if not responseFormat then responseFormat = "json" end
	if responseFormat == "json" then
		Json = require ("dkjson")
	elseif responseFormat == "xml" then
		error("xml parsing not implemented yet")
		--Xml = require "luaxml"
	end
	if OFFLINE and (not mode.helper) then
		--skip OAuth preparation
		--when launched from ma, dll loading is not possible.
	else 
		OAuth = require "OAuth"
		---@field [parent=#site] #table oauth
		site.oauth = {}
		site.oauth.client, site.oauth.params = site.PrepareOAuth()
	end
--	if not mode.helper then
--		--create an empty file to hold missorted cards
--		-- that is, the mkm expansion does not match the MA set
--		LHpi.Log("site.sets = {" ,0 , "missorted."..responseFormat , 0 )-- new missorted.json
--		site.settweak = site.settweak or {}
--	end
	if mode.update then
		if not dummy then error("Update mode needs to be called by LHpi.dummyMA!") end
		dummy.CompareDummySets(mapath,site.libver)
		dummy.CompareDataSets(site.libver,site.libver)
		dummy.CompareSiteSets()
	 	dummy.ListUnknownUrls(site.FetchExpansionList())
		return
	end--mode.update
end--function site.Initialize


--[[- sets all oauth raleted options and prepares the oauth-client.
ideally, tokens/secrets should be read from a file instead of being hardcoded.

 @function [parent=#site] PrepareOAuth
 @return client			OAuth instance
 @return #table params	oauth parameters
]]
function site.PrepareOAuth()
	local tokens = workdir.."lib\\" .. mkmtokenfile
	tokens = ma.GetFile(tokens)
	if not tokens then error("magiccardmarket token file %q not found!") end
	tokens = Json.decode(tokens)
	local params = {
		oauth_version = "1.0",
		oauth_consumer_key = tokens.appToken, -- MKM "App Token"
		oauth_token = "", -- public resource: the oauth_token parameter in the Authorization header is empty 
		oauth_signature_method = "HMAC-SHA1",
		appSecret = tokens.appSecret, -- MKM "App Secret"
		accessTokenSecret = "",
	}
	if not widgetonly then
		params.oauth_token = tokens.accessToken -- MKM "Access Token"
		params.accessTokenSecret = tokens.accessTokenSecret -- MKM "Access Token Secret"
	end
	--at least try not to leak the tokens :)
	tokens = nil
	collectgarbage()
	if mkmtokenfile == "LHpi.mkm.tokens.example" then
		params = { -- set to values from example at https://www.mkmapi.eu/ws/documentation/API:Auth_OAuthHeader
			oauth_version = "1.0",
			oauth_signature_method = "HMAC-SHA1",
			oauth_consumer_key = "bfaD9xOU0SXBhtBP",
			appSecret = "pChvrpp6AEOEwxBIIUBOvWcRG3X9xL4Y",
			oauth_token = "lBY1xptUJ7ZJSK01x4fNwzw8kAe5b10Q",
			accessTokenSecret = "hc1wJAOX02pGGJK2uAv1ZOiwS7I9Tpoe",
			oauth_timestamp = "1407917892",
			oauth_nonce = "53eb1f44909d6",
			url = "https://www.mkmapi.eu/ws/v1.1/account",
		}
	end
	local client = OAuth.new(params.oauth_consumer_key, params.appSecret )
	client:SetToken( params.oauth_token )
	client:SetTokenSecret( params.accessTokenSecret)

	LHpi.Log("OAuth prepared" ,1)
	return client, params
end--function PrepareOAuth

--[[- construct, sign and send/receive OAuth requests
 Done in sitescript to keep library dependencies low, as this is currently the only sitescript that uses OAuth.
 Library should not need to know about OAuth, so only url is passed from LHpi.GetSourceData,
 which calls this function when url.oauth==true and not OFFLINE.
 An OAuth-client has to be present in site.oauth.client (and should have been prepard by site.PrepareOAuth).

 @function [parent=#site] FetchSourceDataFromOAuth
 @param #string url
 @return #string body		source data in xml or json format
 @return #string status		http(s) status code and response
]]
function site.FetchSourceDataFromOAuth( url )
	if sandbox then
		url = "sandbox." .. url
	else
		url = "www." .. url
	end--if sandbox
	url = "https://" .. url
	LHpi.Log("site.FetchSourceDataFromOAuth started for url " .. url ,2)
--	if DEBUG then
--		print("BuildRequest:")
--		local headers, arguments, post_body = site.oauth.client:BuildRequest( "GET", url )
--		print("headers=", LHpi.Tostring(headers))
--		print("arguments=", LHpi.Tostring(arguments))
--		print("post_body=", LHpi.Tostring(post_body))
--		--error("stopped before actually contacting the server")
--		print("PerformRequest:")
--	end
	if COUNTREQUESTS then
		local counter = ma.GetFile(LHpi.savepath.."LHpi.mkm.requestcounter")
		counter = tonumber(counter)
		counter = counter + 1
		LHpi.Log(counter,0,LHpi.savepath.."LHpi.mkm.requestcounter",0)
	end
	
	local code, headers, status, body = site.oauth.client:PerformRequest( "GET", url )
	local errorstring = nil
	if code == 200 or code == 204 then
		LHpi.Log("status=".. LHpi.Tostring(status) ,2)
		return body, status
	elseif code == 206 or code == 204 then -- Partial Content or No Content
		errorstring = status .. " - not implemented yet!"
		--TODO for 206 (Partial Content) modify Content-Range and recursively call LHpi.GetSourceData(url , details)
	elseif code == 400 then -- Bad Request
		errorstring = status .. " - " .. LHpi.Tostring(body)
	elseif code == 401 then -- Unauthorized
		errorstring = status .. " - check token file, url and OAuth!"
	elseif code == 403 then -- Forbidden
		errorstring = status .. " - resource valid, check dedicated vs. widget app!"
	elseif code == 405 then -- Not Allowed
		errorstring = status .. " - check HTTP method!"
	elseif code == 412 then -- Precondition Failed
		errorstring = status .. " - invalid state change on one of your orders!"
	elseif code == 417 then -- Expectation Failed
		errorstring = status .. " - check token file, url and OAuth!"
	elseif code == 429 then -- Too Many Requests
		errorstring = status .. " :limited to 5000 requests per day, resets at 0:00 CE(S)T. Pass \"resetcounter\" to mkm-helper to reset the persistant request counter." 
	else
		errorstring = status .. " - " .. LHpi.Tostring(headers)
	end
	LHpi.Log(errorstring ,1)
	print(errorstring)
	if DEBUG then
		error(errorstring)
	end
	return nil, status
end--function site.FetchSourceDataFromOAuth

-- Like URL-encoding, but following MKM and OAuth's specific semantics
local function OauthEncode(val)
	return val:gsub('[^-._~a-zA-Z0-9:&]', function(letter)
		return string.format("%%%02x", letter:byte()):upper()
	end)
end

--[[-  build source url/filename.
 Has to be done in sitescript since url structure is site specific.
 To allow returning more than one url here, BuildUrl is required to wrap it/them into a container table.

 foilonly and isfile fields can be nil and then are assumed to be false.
 while isfile is read and interpreted by the library, foilonly is not.
 Its only here as a convenient shortcut to set card.foil in your site.ParseHtmlData

Optionally, for setid=="list", you can return an url with a list of available sets.
This will be used by site.FetchExpansionList().
 
 !ONLY IN LHpi.magickartenmarkt:
 !Only build the mkm api request and set oauth flag. This way, we keep the urls human-readable and non-random
 !so we can store the files and retrieve them later in OFFLINE mode.
 !LHpi.GetSourceData calls site.FetchSourceDataFromOAuth to construct, sign and send/receive OAuth requests, triggered by the flag.
 !"www." or "sandbox." is prefixed in site.FetchSourceDataFromOAuth.
 !Alternatively, it can be called as site.BuildUrl(#table setid), 
 !where setid is not a numerical set id, but a Json.decod'ed mkm Expansion or Product Entity.
 !ulr is still rewturned as table, so we need to remember to convert the table key to a string in the calling function.
 
 @function [parent=#site] BuildUrl
 @param #number setid		see site.sets
 @param #number langid		see site.langs
 @param #number frucid		see site.frucs
 @return #table { #string (url)= #table { isfile= #boolean, (optional) foilonly= #boolean, (optional) setid= #number, (optional) langid= #number, (optional) frucid= #number } , ... }
]]
function site.BuildUrl( setid,langid,frucid )
	local url = "mkmapi.eu/ws/v1.1/output." .. responseFormat
	local container = {}
	local urls
	if type(setid)=="table" then-- mkm mode
		if setid.idExpansion then
			url = url .. "/expansion/1/"
			local name = OauthEncode(setid.name)
			--local name = setid.name
			container[url .. name] = { oauth=true, setid=setid }
			return container
		elseif setid.idProduct then
			url = url .. "/product/"
			container[url .. setid.idProduct] = { oauth=true, setid=setid }
			return container
		else
			error(LHpi.Tostring(setid))
		end
--	elseif setid=="skip" then
--		return { }
	elseif setid=="list" then --request Expansion entities for all expansions
		return url .. "/expansion/1"
	else -- usual LHpi behaviour
		url = url .. "/expansion/1"
		if site.sets[setid]==nil then
			return {}
		elseif  type(site.sets[setid].url) == "table" then
			urls = site.sets[setid].url
		else
			urls = { site.sets[setid].url }
		end--if type(site.sets[setid].url)
	for _i,seturl in pairs(urls) do
		container[url .. "/" .. seturl] = { oauth=true, setid=setid }
	end--for _i,seturl
	return container
	end--if type(setid)
	error("reached unreachable state")	
end -- function site.BuildUrl

--[[- fetch list of expansions from mkmapi to be used by update helper functions.
 The returned table shall contain at least the sets' name and LHpi-comnpatible urlsuffix,
 so it can be processed by dummy.ListUnknownUrls.
 
 @function [parent=#site] FetchExpansionList
 @return #table  @return #table { #number= #table { name= #string , urlsuffix= #string , ... }
]]
function site.FetchExpansionList()
	if OFFLINE then
		LHpi.Log("OFFLINE mode active. Expansion list may not be up-to-date." ,1)
	end
	local expansions
	local url = site.BuildUrl( "list" )
	local urldetails={ oauth=true }
	expansions = LHpi.GetSourceData ( url , urldetails )
	if not expansions then
		error(string.format("Expansion list not found at %s (OFFLINE=%s)",LHpi.Tostring(url),tostring(OFFLINE)) )
	end
	expansions = Json.decode(expansions).expansion
	for i,expansion in pairs(expansions) do
		expansions[i].urlsuffix = LHpi.OAuthEncode(expansion.name)
	end
	return expansions
end--function site.FetchExpansionList

--[[- format string to use in dummy.ListUnknownUrls update helper function.
 @field [parent=#site] #string updateFormatString ]]
site.updateFormatString = '[%i]={id=%3i, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url=%q},--%s'

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
	local regpriceType = site.priceTypes[useAsRegprice].type
	local foilpriceType = site.priceTypes[useAsFoilprice].type
	local product
	if responseFormat == "json" then
		product = Json.decode(foundstring)
	else
		error("nothing here for xml yet")
	end
	if not product.idProduct then
		return { }
	end 
	--print(LHpi.Tostring(product.name))
	local newCard = 	{ names = {}, lang={}, pluginData={}, foil=false }
	local newFoilCard = { names = {}, lang={}, pluginData={}, foil=true  }
	-- can just set names[1] to productName[1].productName, as productName reflects mkm ui langs, not card langs		
	newCard.names[1] = product.name["1"].productName
	newFoilCard.names[1] = product.name["1"].productName
	--for i,prodName in pairs(product.name) do
	--	local langid = site.mapLangs[prodName.languageName] or error("unknown MKM language")
	--	newCard.names[langid] = prodName.productName
	--	newFoilCard.names[langid] = prodName.productName
	--end--for i,prodName
	local regprice,foilprice
	if product.priceGuide then
	--	local regprice  = string.gsub( product.priceGuide[priceType] , "[,.]" , "" ) --nonfoil price, use AVG by default
	--	local foilprice = string.gsub( product.priceGuide["LOWFOIL"] , "[,.]" , "" ) --foil price
		regprice  = tonumber(product.priceGuide[regpriceType])*100 --nonfoil price, use AVG by default
		foilprice = tonumber(product.priceGuide[foilpriceType])*100 --foil price
	else
		LHpi.Log(string.format("PriceGuide field missing for %s",newCard.names[1]),1)
	end
	for lid,lang in pairs(site.sets[urldetails.setid].lang) do
		if site.sets[urldetails.setid].lang[lid] then
			newCard.lang[lid] = LHpi.Data.languages[lid].abbr
			newFoilCard.lang[lid] = LHpi.Data.languages[lid].abbr
		end
	end
	newCard.price=tonumber(regprice)
	newFoilCard.price=tonumber(foilprice)
	local pluginData = { rarity=product.rarity, collectNr=product.number, set=product.expansion }
	newCard.pluginData = pluginData
	newFoilCard.pluginData = pluginData
	return { newCard, newFoilCard }
end -- function site.ParseHtmlData

--[[- special cases card data manipulation.
 Ties into LHpi.buildCardData to make changes that are specific to one site and thus don't belong into the library.
 This Plugin is called before most of LHpi's BuildCardData processing.
 It's probably safest to only make name and language modifications here.

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
	if "Land" == card.pluginData.rarity then
		if (not card.pluginData.collectNr)
		or card.pluginData.set == "Zendikar"
		or card.pluginData.set == "Battle for Zendikar"
		then
			card.name = string.gsub( card.name,"%(Version (%d+)%)","(%1)" )
		else
			card.name = string.gsub( card.name,"%(Version %d+%)","("..card.pluginData.collectNr..")" )
		end
	elseif "Token" == card.pluginData.rarity then
		if card.pluginData.collectNr then
			card.name = string.gsub( card.name, "%(.+%)", "("..card.pluginData.collectNr..")" )
			card.name = string.gsub( card.name, "%(TO?K?E?N?%-?(%d+[abc]?)%)","(%1)")
		elseif setid == 751
		or setid == 754
		or setid == 755
		or setid == 757
		or setid == 766
		--or setid == 40
		--or setid == 21
		then
			card.name = string.gsub( card.name, "%(.+%)", "" )
		end
	elseif "Tip Card" == card.pluginData.rarity then
		card.objtype = 4
		card.name = card.name .. "(DROP insert)"
	end--if "Land" elseif "Token" elseif "Tip Card"
	
	if setid == 720 then -- Tenth Edition
		if card.pluginData.set == "DCI Promos" then
			if card.name == "Kamahl, Pit Fighter" then
				card.name = card.name .. " (ST)"
			else
				card.name = card.name .. " (DROP not Tenth Edition)"
			end
		end
	elseif setid == 680 then --Time Spiral
		if card.pluginData.rarity == "Time Shifted" then
			card.name = card.name .. " (DROP Timeshfted)"
		end
	elseif setid == 690 then --Time Spiral Timeshifted
		if card.pluginData.rarity ~= "Time Shifted" then
			card.name = card.name .. " (DROP not Timeshfted)"
		end
	elseif setid == 240 then --Visions
		--TODO 240: Jamuuran Lion versioning
	elseif setid == 821 then -- Challenge Deck: Defeat a God
		if card.pluginData.set == "Journey into Nyx" then
			if card.name == "Dance of Flame"
			or card.name == "Dance of Panic"
--			or card.name == "Ecstatic Piper"
			or card.name == "Estatic Piper"
			or card.name == "Impulsive Charge"
			or card.name == "Impulsive Destruction"
			or card.name == "Impulsive Return"
			or card.name == "Maddened Oread"
			or card.name == "Pheres-Band Revelers"
			or card.name == "Rip to Pieces"
			or card.name == "Rollicking Throng"
			or card.name == "Serpent Dancers"
			or card.name == "Wild Maenads"
			or card.name == "Xenagos Ascended"
--			or card.name == "Xenagos’s Scorn"
			or card.name == "Xenagos's Scorn"
--			or card.name == "Xenagos’s Strike"
			or card.name == "Xenagos's Strike"
			then
				card.name = card.name .. " (nontrad)"
				-- objtype is later overwritten by lib :(
				card.objtype = 3
			else
				card.name = card.name .. " (DROP not Defeat a God)"
			end
		end
	elseif setid == 804 then -- Challenge Deck: Battle the Horde
		if card.pluginData.set == "Born of the Gods" then
			if card.name == "Altar of Mogis"
			or card.name == "Consuming Rage"
			or card.name == "Descend on the Prey"
			or card.name == "Intervention of Keranos"
			or card.name == "Massacre Totem"
			or card.name == "Minotaur Goreseeker"
			or card.name == "Minotaur Younghorn"
			or card.name == "Mogis's Chosen"
			or card.name == "Phoberos Reaver"
			or card.name == "Plundered Statue"
			or card.name == "Reckless Minotaur"
			or card.name == "Refreshing Elixir"
			or card.name == "Touch of the Horned God"
			or card.name == "Unquenchable Fury"
			or card.name == "Vitality Salve"
			then
				card.name = card.name .. " (nontrad)"
				-- objtype is later overwritten by lib :(
				card.objtype = 3
			else
				card.name = card.name .. " (DROP not Battle the Horde)"
			end
		end
	elseif setid == 803 then -- Challenge Deck: Face the Hydra
		if card.pluginData.set == "Theros" then
			if card.name == "Disorienting Glower"
			or card.name == "Distract the Hydra"
			or card.name == "Grown from the Stump"
			or card.name == "Hydra Head"
			or card.name == "Hydra's Impenetrable Hide"
			or card.name == "Neck Tangle"
			or card.name == "Noxious Hydra Breath"
			or card.name == "Ravenous Brute Head"
			or card.name == "Savage Vigor Head"
			or card.name == "Shrieking Titan Head"
			or card.name == "Snapping Fang Head"
			or card.name == "Strike the Weak Spot"
			or card.name == "Swallow the Hero Whole"
			or card.name == "Torn Between Heads"
			or card.name == "Unified Lunge"
			then
				card.name = card.name .. " (nontrad)"
				-- objtype is later overwritten by lib :(
				card.objtype = 3
			else
				card.name = card.name .. " (DROP not Face the Hydra)"
			end
		end
	elseif setid == 755 then -- DD: Jace vs Chandra
		if card.name == "Chandra Nalaar (Version 1)"
		or card.name == "Jace Beleren (Version 1)"
		then
			card.lang = { "ENG" }
			card.name = string.gsub(card.name," %(Version 1%)","")
		elseif card.name == "Chandra Nalaar (Version 2)"
		or card.name == "Jace Beleren (Version 2)"
		then
			card.lang = { [8]="JPN" }
			card.name = string.gsub(card.name," %(Version 2%)","")
		end
	elseif setid == 635 then -- Salvat Magic Encyclopedia
		if card.pluginData.rarity~="Land" then
			card.name = string.gsub( card.name,"%(Version %d+%)","("..card.pluginData.collectNr..")" )
			if string.find(card.name,"^Selesnya Guildmage") then
				card.name=string.gsub(card.name,"02%-","Elves ")
				card.name=string.gsub(card.name,"10%-","Thallids ")
			end
			card.name = string.gsub(card.name,"%(%d+-(%d+)%)","(%1)")
		end
	elseif setid ==  390 then -- Starter 1999
		if card.pluginData.set == "Oversized 6x9 Promos" then
			if card.name == "Thorn Elemental" then
				card.name = card.name .. " (oversized)"
			else
				card.name = card.name .. " (DROP not Starter 1999)"
			end
		end
	elseif setid == 200 then -- Chronicles
		if card.pluginData.set == "Chronicles" then
			card.lang = { [1]="ENG" }
		elseif card.pluginData.set == "Chronicles: Japanese" then
			card.lang = { [8]="JPN" }
		end
	elseif setid == 201 then -- Renaissance/Rinascimento
		if card.pluginData.set == "Renaissance" then
			card.lang = { [3]="GER", [4]="FRA" }
		elseif card.pluginData.set == "Rinascimento" then
			card.lang = { [5]="ITA" }
		end
	elseif setid == 140 then -- Revised (Unlimited)
		if card.pluginData.set == "Revised" then
			card.lang = { [1]="ENG" }
		elseif card.pluginData.set == "Foreign White Bordered" then
			card.lang = { [3]="GER", [4]="FRA", [5]="ITA" }
		end
	elseif setid == 53 then -- Holiday Gift Box Promos
		if card.pluginData.set == "Promos" then
			if card.name == "Dreg Mangler"
			or card.name == "Karametra's Acolyte"
			then
			else
				card.name = card.name .. " (DROP not Holiday Gift Box Promos)"
			end
		elseif card.pluginData.set == "Khans of Tarkir: Promos" then
			if card.name ~= "Sultai Charm" then
				card.name = card.name .. "(DROP not Holiday Gift Box Promos)"
			end
		elseif card.pluginData.set == "Battle for Zendikar: Promos" then
			if card.name ~= "Scythe Leopard" then
				card.name = card.name .. "(DROP not Holiday Gift Box Promos)"
			end
		elseif card.pluginData.set == "Shadows over Innistrad: Promos" then
			if card.name ~= "Ravenous Bloodseeker" then
				card.name = card.name .. "(DROP not Holiday Gift Box Promos)"
			end
		end
	elseif setid == 52 then -- Intro Pack Promos
		if card.pluginData.set == "Khans of Tarkir: Promos" and
			( card.name == "Ankle Shanker (Version 2)"
			or card.name == "Avalanche Tusker (Version 2)"
			or card.name == "Ivorytusk Fortress (Version 2)"
			or card.name == "Rakshasa Vizier (Version 2)"
			or card.name == "Sage of the Inward Eye (Version 2)"
		) then
		elseif card.pluginData.set == "Fate Reforged: Promos" and
			( card.name == "Archfiend of Depravity (Version 2)"
			or card.name == "Dragonscale General (Version 2)"
			or card.name == "Flamerush Rider (Version 2)"
			or card.name == "Sage-Eye Avengers (Version 2)"
			or card.name == "Temur War Shaman"
		) then
		elseif card.pluginData.set == "Dragons Of Tarkir: Promos" and
			( card.name == "Arashin Sovereign (Version 2)"
			or card.name == "Boltwing Marauder (Version 2)"
			or card.name == "Harbinger of the Hunt (Version 2)"
			or card.name == "Necromaster Dragon (Version 2)"
			or card.name == "Pristine Skywise (Version 2)"
		) then
		elseif card.pluginData.set == "Magic Origins: Promos" and
			( card.name == "Alhammarret, High Arbiter (Version 2)"
			or card.name == "Dwynen, Gilt-Leaf Daen (Version 2)"
			or card.name == "Hixus, Prison Warden (Version 2)"
			or card.name == "Kothophed, Soul Hoarder (Version 2)"
			or card.name == "Pia and Kiran Nalaar (Version 2)"
		) then
		elseif card.pluginData.set == "Battle for Zendikar: Promos" and
			( card.name == "Barrage Tyrant (Version 1)"
			or card.name == "Defiant Bloodlord (Version 1)"
			or card.name == "Drowner of Hope (Version 1)"
			or card.name == "Hero of Goma Fada (Version 1)"
			or card.name == "Oran-Rief Hydra (Version 1)"
		) then
		elseif card.pluginData.set == "Oath of the Gatewatch: Promos" and
			( card.name == "Deepfathom Skulker (Version 2)"
			or card.name == "Dread Defiler (Version 2)"
			or card.name == "Gladehart Cavalry (Version 2)"
			or card.name == "Munda's Vanguard (Version 2)"
			or card.name == "Tyrant of Valakut (Version 2)"
		) then
		elseif card.pluginData.set == "Shadows over Innistrad: Promos" and
			( card.name == "Drogskol Cavalry (Version 2)"
			or card.name == "Flameblade Angel (Version 2)"
			or card.name == "Markov Dreadknight (Version 2)"
			or card.name == "Nephalia Moondrakes (Version 2)"
			or card.name == "Soul Swallower (Version 2)"
		) then
		else
			card.name = card.name .. " (DROP not Intro Pack Promos)"
		end
	elseif setid ==  50 then -- Full Box Promotion
		if card.pluginData.set == "Promos" then
			if card.name == "Ruthless Cullblade"
			or card.name == "Pestilence Demon"
			then
				card.lang = { [8]="JPN" }
			else
				card.name = card.name .. " (DROP not Full Box Promotion)"
			end
		end
	elseif setid == 43 then -- Two-Headed Giant Promo
		if card.name ~= "Underworld Dreams" then
			card.name = card.name .. " (DROP not Two-Headed Giant Promo)"
		end
	elseif setid == 42 then -- Summer of Magic
		if card.name == "Faerie Conclave"
		or card.name == "Treetop Village"
		then
		else
			card.name = card.name .. " (DROP not Summer of Magic)"
		end
	elseif setid == 40 then -- Arena/Coloseo League
		if card.pluginData.set == "Oversized 6x9 Promos" then
			card.name = card.name .. " (oversized)"
		--elseif card.pluginData.set == "Promos" then -- settweak
		end
	elseif setid == 34 then -- World Magic Cup Promos
		if card.pluginData.set == "DCI Promos" then
			if card.name == "Abrupt Decay"
			or card.name == "Thalia, Guardian of Thraben"
			or card.name == "Vengevine"
			then
			else
				card.name = card.name .. " (DROP not World Magic Cup Promos)"
			end
		elseif card.pluginData.set == "Promos" then
			if card.name ~= "Geist of Saint Traft" then
				card.name = card.name .. "(DROP not World Magic Cup Promos)"
			end
		end
	elseif setid == 33 then -- Championships Prizes
		if card.pluginData.set == "DCI Promos" then
			if card.name ~= "Balduvian Horde"
			then
				card.name = card.name .. " (DROP not Championships Prizes)"
			end
		elseif card.pluginData.set == "Promos" then
			if card.name ~= "Geist of Saint Traft" then
				card.name = card.name .. "(DROP not Championship Prizes)"
			end
		end
	elseif setid == 32 then -- Pro Tour Promos
		if card.name == "Ajani Goldmane"
		or card.name == "Avatar of Woe"
		or card.name == "Eternal Dragon"
		or card.name == "Mirari's Wake"
		or card.name == "Treva, the Renewer"
		then
		else
			card.name = card.name .. " (DROP not Pro Tour Promos)"
		end
	elseif setid == 27 then -- Alternate Art Lands
		if card.pluginData.set == "APAC Lands" then
			card.name = card.name .. " (APAC)"
		elseif card.pluginData.set == "Euro Lands" then
			card.name = card.name .. " (Euro)"
		elseif card.pluginData.set == "Guru Lands" then
			card.name = card.name .. " (Guru)"
		elseif card.pluginData.set == "Promos" then
			if card.name ~= "Magic Guru" then
				card.name = card.name .. " (DROP not Guru)"
			end
		end
	elseif setid ==  26 then -- Magic Game Day
		if card.pluginData.set == "Gateway Promos" then
			if card.name ~= "Naya Sojourners" then
				card.name = card.name .. " (DROP not Magic Game Day)"
			end
		elseif card.pluginData.set == "Release Promos" then
			if card.name ~= "Reya Dawnbringer" then
				card.name = card.name .. " (DROP not Magic Game Day)"
			end
		elseif card.pluginData.set == "Theros" then
			if card.name ~= "The Slayer" then
				card.name = card.name .. " (DROP not Magic Game Day)"
			end
		elseif card.pluginData.set == "Born of the Gods" then
			if card.name ~= "The Vanquisher" then
				card.name = card.name .. " (DROP not Magic Game Day)"
			end
		elseif card.pluginData.set == "Journey into Nyx" then
			if card.name ~= "The Champion" then
				card.name = card.name .. " (DROP not Magic Game Day)"
			end
		end
	elseif setid == 25 then -- Judge Gift Cards
		if card.name == "Elesh Norn, Grand Cenobite" then
			card.lang = { [17]="PHY" }
		else
			card.lang[17] = nil
		end
		if card.pluginData.set == "Promos" then
			if card.name == "Centaur Token (Green 3/3)"
			or card.name == "Golem Token (Artefact 2/2)"
			then
			else
				card.name = card.name .. " (DROP not Judge Gift Cards)"
			end
		end
	elseif setid == 22 then -- Prerelease Promos
		for _,lid in ipairs({12,13,14,15,16}) do
			card.lang[lid] = nil
		end
		if card.pluginData.set == "Prerelease Promos" then
			if card.name == "Glory" then
				card.lang = { [12]="HEB"}
			elseif card.name == "Stone-Tongue Basilisk" then
				card.lang = { [13]="ARA" }
			elseif card.name == "Raging Kavu" then
				card.lang = { [14]="LAT" }
			elseif card.name == "Fungal Shambler" then
				card.lang = { [15]="SAN"}
			elseif card.name == "Questing Phelddagrif" then
				card.lang = { [16]="GRC" }
			end
		elseif card.pluginData.set == "Oversized 6x9 Promos" then
			if card.name == "Garruk the Slayer" then
				card.name = card.name .. " (oversized)"
			else
				card.name = card.name .. " (DROP not Prerelease Promos)"
			end
--		elseif card.pluginData.set == "DCI Promos" then
--			-- DCI Griselbrand is GP; Prerelease Griselbrand is oversized!
--			if card.name ~= "Griselbrand" then
--				card.name = card.name .. " (DROP not Prerelease Promos)"
--			end
		elseif card.pluginData.set == "Theros" then
			if card.name == "The Protector"
			or card.name == "The Philosopher"
			or card.name == "The Avenger"
			or card.name == "The Warrior"
			or card.name == "The Hunter"
			then
			else
				card.name = card.name .. " (DROP not Prerelease Promos)"
			end
		elseif card.pluginData.set == "Born of the Gods" then
			if card.name == "The General"
			or card.name == "The Savant"
			or card.name == "The Tyrant"
			or card.name == "The Warmonger"
			or card.name == "The Provider"
			then
			else
				card.name = card.name .. " (DROP not Prerelease Promos)"
			end
		elseif card.pluginData.set == "Journey into Nyx" then
			if card.name == "Spear of the General"
			or card.name == "Cloak of the Philosopher"
			or card.name == "Lash of the Tyrant"
			or card.name == "Axe of the Warmonger"
			or card.name == "Bow of the Hunter"
			then
			else
				card.name = card.name .. " (DROP not Prerelease Promos)"
			end
		elseif card.pluginData.set == "Promos" then
			if card.name == "Dragonlord's Servant"
			or card.name == "Foe-Razer Regent"
			or card.name == "Dragon Fodder"
			or card.name == "Evolving Wilds"
			then
				card.name = card.name .. " (Dragonfury)"
			else
				card.name = card.name .. " (DROP not Prerelease Promos)"
			end
		end
	elseif setid == 21  then -- Release Promos
		if card.pluginData.set == "Oversized 6x9 Promos" then
			if card.name == "Incoming!" then
				card.name = card.name .. " (oversized)"
			else
				card.name = card.name .. " (DROP not Release Promos)"
			end
		elseif card.pluginData.set == "Prerelease Promos" then
			if card.name ~= "Lord of Shatterskull Pass" then
				card.name = card.name .. " (DROP not Release Promos)"
			end
		elseif card.pluginData.set == "Theros" then
			if card.name ~= "The Harvester" then
				card.name = card.name .. " (DROP not Release Promos)"
			end
		elseif card.pluginData.set == "Born of the Gods" then
			if card.name ~= "The Explorer" then
				card.name = card.name .. " (DROP not Release Promos)"
			end
		elseif card.pluginData.set == "Journey into Nyx" then
			if card.name ~= "The Destined" then
				card.name = card.name .. " (DROP not Release Promos)"
			end
		elseif card.pluginData.set == "Magic Origins: Promos" then
			if card.name == "Mizzium Meddler (Version 1)" then
				card.name = "Mizzium Meddler"
			else
				card.name = card.name .. " (DROP not Release Promos)"
			end
		elseif card.pluginData.set == "Shadows over Innistrad: Promos" then
			if card.name == "Angel of Deliverance (Version 2)" then
				card.name = "Angel of Deliverance"
			else
				card.name = card.name .. " (DROP not Release Promos)"
			end
		end
	elseif setid == 15 then -- Convention Promos
		if card.pluginData.set == "San Diego Comic-Con 2013 Promos" then
			card.name = card.name .. " (CC13)"
		elseif card.pluginData.set == "San Diego Comic-Con 2014 Promos" then
			card.name = card.name .. " (CC14)"
		elseif card.pluginData.set == "Oversized 6x9 Promos" then
			if card.name == "Hurloon Minotaur"
			or card.name == "Serra Angel (Version 1)" then
				card.name = card.name .. " (oversized)"
			else
				card.name = card.name .. " (DROP not Convention Promo)"
			end
		elseif card.pluginData.set == "DCI Promos" then
			if card.name == "Bloodthrone Vampire"
			or card.name == "Chandra's Fury"
			or card.name == "Char"
			or card.name == "Kor Skyfisher"
			or card.name == "Merfolk Mesmerist"
			or card.name == "Steward of Valeron"
			then
			else
				card.name = card.name .. " (DROP not Convention Promo)"
			end
		elseif card.pluginData.set == "Promos" then
			if card.name ~= "Stealer of Secrets" then
				card.name = card.name .. " (DROP not Convention Promo)"
			end
		elseif card.pluginData.set == "Dengeki Maoh Promos" then
			if card.name == "Shepherd of the Lost" then
				card.lang= { [8]="JPN" }
			else
				card.name = card.name .. " (DROP not Convention Promo)"
			end
		end
	elseif setid == 10 then -- Junior Series Promos
		if card.pluginData.set == "Junior Series Promos" then
			card.lang = { "ENG" }
			card.name = card.name .. " (E)"
		elseif card.pluginData.set == "Junior APAC Series Promos" then
			card.lang = { "ENG" }
			card.name = card.name .. " (U)"
		elseif card.pluginData.set == "Japan Junior Tournament Promos" then
			card.lang = { [8]="JPN" }
			card.name = card.name .. " (JPN)"
		elseif card.pluginData.set == "Magic Scholarship Series Promos" then
			card.lang = { "ENG" }
			card.name = card.name .. " (J)" -- "Mad Auntie": " (J)"->"" in namereplace
		elseif card.pluginData.set == "Junior Super Series Promos" then
			card.lang = { "ENG" }
			card.name = card.name .. " (J)"	-- most are variant " (J)"->"" in namereplace
		end
	elseif setid == 9 then -- Video Game Promos
		if card.pluginData.set == "Oversized 6x9 Promos" then
			if card.name ~= "Aswan Jaguar" then
				card.name = card.name .. " (DROP not Video Game Promo)"
			end
		end
	elseif setid == 8 then -- Stored Promos
		if card.pluginData.set == "DCI Promos" then
			if card.name == "Relentless Rats" then
				card.lang = { [5]="ITA" }
			elseif card.name ~= "Serra Angel" then
				card.name = card.name .. " (DROP not Stores Promos)"
			else
				card.lang = { "ENG" }
			end
--		elseif card.pluginData.set == "Walmart Promos" then
--			card.lang = { "ENG" }
		elseif card.pluginData.set == "Promos" then
			if card.name == "Goblin Chieftain"
			or card.name == "Loam Lion"
			or card.name == "Oran-Rief, the Vastwood"
			then
				card.lang = { [8]="JPN" }
			else
				card.name = card.name .. " (DROP not Stores Promos)"
			end
		end
	elseif setid == 7 then -- Magazine Inserts
		if card.pluginData.set == "Oversized 6x9 Promos" then
			if card.name == "Chaos Orb"
			or card.name == "Black Lotus"
			or card.name == "Juzám Djinn"
			or card.name == "Jester's Cap"
			or card.name == "Shivan Dragon"
			then
				card.lang = { "ENG" }
			else
				card.name = card.name .. " (DROP not Magazine Inserts)"
			end
		elseif card.pluginData.set == "TopDeck Promos" then
			card.lang={ "ENG" }
		elseif card.pluginData.set == "CardZ Promos" then
			card.lang={ "ENG" }
		elseif card.pluginData.set == "The Duelist Promos" then
			card.lang={ "ENG" }
		elseif card.pluginData.set == "Promos" then
			if card.name == "Jamuraan Lion" then
				card.lang = { [3]="GER" }
			elseif card.name == "Archangel"
			or card.name == "Thorn Elemental"
			then
				card.lang = { [8]="JPN" }
			else
				card.name = card.name .. " (DROP not Magazine Inserts)"
			end
		end
	elseif setid == 6 then -- Comic Inserts
		if card.pluginData.set == "Oversized 6x9 Promos" then
			card.lang = { "ENG" }
			if card.name ~= "Serra Angel (Version 2)" then
				card.name = card.name .. " (DROP not Comic Inserts)"
			end
		elseif card.pluginData.set == "Dengeki Maoh Promos" then
				card.lang = { [8]="JPN" }
		elseif card.pluginData.set == "Armada Comics" then
				card.lang = { "ENG" }
		elseif card.pluginData.set == "IDW Promos" then
				card.lang = { "ENG" }
		elseif card.pluginData.set == "Promos" then
			if card.name == "Darksteel Juggernaut"
			or card.name == "Kuldotha Phoenix"
			or card.name == "Phantasmal Dragon"
			or card.name == "Shivan Dragon"
			then
				card.lang = { [8]="JPN" }
			else
				card.name = card.name .. " (DROP not Comic Inserts)"
			end
		end
	elseif setid == 5 then -- Book Inserts
		if card.pluginData.set == "Harper Prism Promos" then
			if card.name == "Mana Crypt (Version 2)" then
				--card.name = "Mana Crypt"
				card.lang = { [7]="SPA" }
			end
		elseif card.pluginData.set == "DCI Promos" then
			if card.name ~= "Jace Beleren" then
				card.name = card.name .. " (DROP not Book Inserts)"
			end
		end
	elseif setid == 2 then -- DCI Legend Membership
		if card.name == "Incinerate"
		or card.name == "Counterspell"
		then
		else
			card.name = card.name .. " (DROP not DCI Legend Membership)"
		end
	end
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
	--TODO migrate settweak to library?
	if site.settweak[setid] and site.settweak[setid][card.name] then
		if LOGSETTWEAK then
			LHpi.Log( string.format( "settweak saved %s with new set %s" ,card.name, site.settweak[setid][card.name] ) ,0)
		end
		card.name = card.name .. "(DROP settweaked to " .. site.settweak[setid][card.name] .. ")"
		settweaked=1
		--save to file instead of dropping would not help, as the sets are imported in semi-random order.
	end -- site.settweak[setid]

	
	card.pluginData=nil
	return card
end -- function site.BCDpluginPost

-------------------------------------------------------------------------------------------------------------
-- tables
-------------------------------------------------------------------------------------------------------------

--[[- Define the six price entries. This table is unique to this sitescript.
 @field [parent=#site] #table priceTypes	{ #number id= { type=#string, definition=#string } , ... }
]]
site.priceTypes = {	--Price guide entity
	[1] = { type="SELL", description="Average price of articles ever sold" },--Average price of articles ever sold of this product
	[2] = { type="LOW", description="lowest non-foil price" },--Current lowest non-foil price (all conditions)
	[3] = { type="LOWEX", description="lowest non-foil EX+ price" },--Current lowest non-foil price (condition EX and better)
	[4] = { type="LOWFOIL", description="lowest foil price" },--Current lowest foil price
	[5] = { type="AVG", description="Average of all available non-foil articles" },--Current average non-foil price of all available articles of this product
	[6] = { type="TREND", description="Trend of average available" },--Trend of AVG 
}

--[[- Map MKM langs to MA langs
 @field [parent=#site] #table mapLangs	{ #string langName = #number MAlangid, ... }
]]
site.mapLangs = {
	["English"]				=  1,
	["German"]				=  3,
	["French"]				=  4,
	["Italian"]				=  5,
	["Spanish"]				=  7,
}

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
	[2]  = { id= 2, url="" },--Russian
	[3]  = { id= 3, url="" },--German
	[4]  = { id= 4, url="" },--French
	[5]  = { id= 5, url="" },--Italian
	[6]  = { id= 6, url="" },--Portuguese
	[7]  = { id= 7, url="" },--Spanish
	[8]  = { id= 8, url="" },--Japanese
	[9]  = { id= 9, url="" },--Simplified Chinese
	[10] = { id=10, url="" },--Traditional Chinese
	[11] = { id=11, url="" },--Korean
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
site.frucs = {
	[1]= { id=1, name="api", url="" },
}

local all = { "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }
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
-- coresets
[822]={id=822, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Magic%20Origins"},--Magic Origins
[808]={id=808, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Magic%202015"},--Magic 2015
[797]={id=797, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Magic%202014"},--Magic 2014
[788]={id=788, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Magic%202013"},--Magic 2013
[779]={id=779, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT" }, fruc={ true }, url="Magic%202012"},--Magic 2012
[770]={id=770, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT" }, fruc={ true }, url="Magic%202011"},--Magic 2011
[759]={id=759, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Magic%202010"},--Magic 2010
[720]={id=720, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url={ --Tenth Edition
											"Tenth%20Edition",
											"DCI%20Promos",-- "Kamahl, Pit Fighter (ST)"
											} },
[630]={id=630, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Ninth%20Edition"},--Ninth Edition
[550]={id=550, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Eighth%20Edition"},--Eighth Edition
[460]={id=460, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[8]="JPN" }, fruc={ true }, url="Seventh%20Edition"},--Seventh Edition
[360]={id=360, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[8]="JPN" }, fruc={ true }, url="Sixth%20Edition"},--Sixth Edition
[250]={id=250, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[8]="JPN" }, fruc={ true }, url="Fifth%20Edition"},--Fifth Edition
[180]={id=180, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[8]="JPN" }, fruc={ true }, url="Fourth%20Edition"},--Fourth Edition
[179]={id=179, lang={ [6] = "POR", [8]="JPN" }, fruc={ true }, url="Fourth%20Edition:%20Black%20Bordered"},--Fourth Edition: Black Bordered
[141]={id=141, lang={ "ENG" }, fruc={ true }, url="Summer%20Magic"},--Summer Magic
[140]={id=140, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA" }, fruc={ true }, url={ "Revised", "Foreign%20White%20Bordered"} },--Revised; Foreign White Bordered = Revised Unlimited
[139]={id=139, lang={ [3]="GER",[4]="FRA",[5]="ITA" }, fruc={ true }, url="Foreign%20Black%20Bordered"},--Foreign Black Bordered = Revised Limited
[110]={id=110, lang={ "ENG" }, fruc={ true }, url="Unlimited"},--Unlimited
[100]={id=100, lang={ "ENG" }, fruc={ true }, url="Beta"},--Beta
[90] ={id= 90, lang={ "ENG" }, fruc={ true }, url="Alpha"},--Alpha
-- expansionsets
[831]={id=831, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Shadows%20over%20Innistrad"},--Shadows over Innistrad
[829]={id=829, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Oath%20of%20the%20Gatewatch"},--Oath of the Gatewatch
[825]={id=825, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Battle%20for%20Zendikar"},--Battle for Zendikar
[818]={id=818, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Dragons%20of%20Tarkir"},--Dragons of Tarkir
[816]={id=816, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Fate%20Reforged"},--Fate Reforged
[813]={id=813, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Khans%20of%20Tarkir"},--Khans of Tarkir
[806]={id=806, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Journey%20into%20Nyx"},--Journey into Nyx
[802]={id=802, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Born%20of%20the%20Gods"},--Born of the Gods
[800]={id=800, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Theros"}, -- Theros
[795]={id=795, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Dragon%27s%20Maze"},--Dragon's Maze
[793]={id=793, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Gatecrash"},--Gatecrash
[791]={id=791, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Return%20to%20Ravnica"}, --Return to Ravnica
[786]={id=786, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Avacyn%20Restored"},--Avacyn Restored
[784]={id=784, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Dark%20Ascension"},--Dark Ascension
[782]={id=782, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT" }, fruc={ true }, url="Innistrad"},--Innistrad
[776]={id=776, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT" }, fruc={ true }, url="New%20Phyrexia"},--New Phyrexia
[775]={id=775, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT" }, fruc={ true }, url="Mirrodin%20Besieged"},--Mirrodin Besieged
[773]={id=773, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT" }, fruc={ true }, url="Scars%20of%20Mirrodin"},--Scars of Mirrodin
[767]={id=767, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Rise%20of%20the%20Eldrazi"},--Rise of the Eldrazi
[765]={id=765, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Worldwake"},--Worldwake
[762]={id=762, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Zendikar"},--Zendikar
[758]={id=758, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Alara%20Reborn"},--Alara Reborn
[756]={id=756, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Conflux"},--Conflux
[754]={id=754, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Shards%20of%20Alara"},--Shards of Alara
[752]={id=752, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Eventide"},--Eventide
[751]={id=751, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Shadowmoor"},--Shadowmoor
[750]={id=750, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Morningtide"},--Morningtide
[730]={id=730, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Lorwyn"},--Lorwyn
[710]={id=710, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Future%20Sight"},--Future Sight
[700]={id=700, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Planar%20Chaos"},--Planar Chaos
[690]={id=690, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Time%20Spiral"},--Time Spiral Timeshifted
[680]={id=680, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Time%20Spiral"},--Time Spiral
[670]={id=670, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Coldsnap"},--Coldsnap
[660]={id=660, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Dissension"},--Dissension
[650]={id=650, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Guildpact"},--Guildpact
[640]={id=640, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Ravnica:%20City%20of%20Guilds"},--Ravnica: City of Guilds
[620]={id=620, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Saviors%20of%20Kamigawa"},--Saviors of Kamigawa
[610]={id=610, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Betrayers%20of%20Kamigawa"},--Betrayers of Kamigawa
[590]={id=590, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Champions%20of%20Kamigawa"},--Champions of Kamigawa
[580]={id=580, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Fifth%20Dawn"},--Fifth Dawn
[570]={id=570, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Darksteel"},--Darksteel
[560]={id=560, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Mirrodin"},--Mirrodin
[540]={id=540, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Scourge"},--Scourge
[530]={id=530, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Legions"},--Legions
[520]={id=520, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Onslaught"},--Onslaught
[510]={id=510, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Judgment"},--Judgment
[500]={id=500, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Torment"},--Torment
[480]={id=480, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Odyssey"},--Odyssey
[470]={id=470, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN" }, fruc={ true }, url="Apocalypse"},--Apocalypse
[450]={id=450, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[8]="JPN" }, fruc={ true }, url="Planeshift"},--Planeshift
[430]={id=430, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[8]="JPN" }, fruc={ true }, url="Invasion"},--Invasion
[420]={id=420, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[8]="JPN" }, fruc={ true }, url="Prophecy"},--Prophecy
[410]={id=410, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN" }, fruc={ true }, url="Nemesis"},--Nemesis
[400]={id=400, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[8]="JPN" }, fruc={ true }, url="Mercadian%20Masques"},--Mercadian Masques
[370]={id=370, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN" }, fruc={ true }, url="Urza%27s%20Destiny"},--Urza's Destiny
[350]={id=350, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN" }, fruc={ true }, url="Urza%27s%20Legacy"},--Urza's Legacy
[330]={id=330, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[8]="JPN" }, fruc={ true }, url="Urza%27s%20Saga"},--Urza's Saga
[300]={id=300, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[8]="JPN" }, fruc={ true }, url="Exodus"},--Exodus
[290]={id=290, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[8]="JPN" }, fruc={ true }, url="Stronghold"},--Stronghold
[280]={id=280, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[8]="JPN" }, fruc={ true }, url="Tempest"},--Tempest
[270]={id=270, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[8]="JPN" }, fruc={ true }, url="Weatherlight"},--Weatherlight
[240]={id=240, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[8]="JPN" }, fruc={ true }, url="Visions"},--Visions
[230]={id=230, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[8]="JPN" }, fruc={ true }, url="Mirage"},--Mirage
[220]={id=220, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR" }, fruc={ true }, url="Alliances"},--Alliances
[210]={id=210, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR" }, fruc={ true }, url="Homelands"},--Homelands
[190]={id=190, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR" }, fruc={ true }, url="Ice%20Age"},--Ice Age
[170]={id=170, lang={ "ENG" }, fruc={ true }, url="Fallen%20Empires"},--Fallen Empires
[160]={id=160, lang={ "ENG",[5]="ITA" }, fruc={ true }, url="The%20Dark"},--The Dark
[150]={id=150, lang={ "ENG",[5]="ITA" }, fruc={ true }, url="Legends"},--Legends
[130]={id=130, lang={ "ENG" }, fruc={ true }, url="Antiquities"},--Antiquities
[120]={id=120, lang={ "ENG" }, fruc={ true }, url="Arabian%20Nights"},--Arabian Nights
-- specialsets
[830]={id=830, lang={ "ENG",[8]="JPN" }, fruc={ true }, url="Duel%20Decks:%20Blessed%20vs.%20Cursed"},--Duel Decks: Blessed vs. Cursed
[828]={id=828, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Commander%202015"},--Commander 2015
[827]={id=827, lang={ "ENG" }, fruc={ true }, url={ -- Origins Clash Pack
											"Clash%20Pack%20Promos",--Clash Pack Promos
											} },
[826]={id=826, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Zendikar%20Expeditions"},--Zendikar Expeditions
[824]={id=824, lang={ "ENG",[8]="JPN" }, fruc={ true }, url="Duel%20Decks:%20Zendikar%20vs.%20Eldrazi"},--Duel Decks: Zendikar vs. Eldrazi
[823]={id=823, lang={ "ENG" }, fruc={ true }, url="From%20the%20Vault:%20Angels"},--From the Vault: Angels
[821]={id=821, lang={ "ENG" }, fruc={ true }, url={ -- Challenge Deck: Defeat a God
											"Journey%20into%20Nyx"
											} },
[820]={id=820, lang={ "ENG",[8]="JPN" }, fruc={ true }, url="Duel%20Decks:%20Elspeth%20vs.%20Kiora"},--Duel Decks: Elspeth vs. Kiora
[819]={id=819, lang={ "ENG",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Modern%20Masters%202015"},--Modern Masters 2015
[817]={id=817, lang={ "ENG" }, fruc={ true }, url="Duel%20Decks:%20Anthology"},--Duel Decks: Anthology
[815]={id=815, lang={ "ENG" }, fruc={ true }, url={ -- Fate Reforged Clash Pack
											"Clash%20Pack%20Promos",--Clash Pack Promos
											} },
[814]={id=814, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Commander%202014"},--Commander 2014
[812]={id=812, lang={ "ENG",[8]="JPN" }, fruc={ true }, url="Duel%20Decks:%20Speed%20vs.%20Cunning"},--Duel Decks: Speed vs. Cunning
[811]={id=811, lang={ "ENG" }, fruc={ true }, url={ -- Magic 2015 Clash Pack
											"Clash%20Pack%20Promos",--Clash Pack Promos
											} },
[810]={id=810, lang={ "ENG" }, fruc={ true }, url="Modern%20Event%20Deck%202014"},--Modern Event Deck 2014
[809]={id=809, lang={ "ENG" }, fruc={ true }, url="From%20the%20Vault:%20Annihilation"},--From the Vault: Annihilation
[807]={id=807, lang={ "ENG",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Conspiracy"},--Conspiracy
[805]={id=805, lang={ "ENG",[8]="JPN" }, fruc={ true }, url="Duel%20Decks:%20Jace%20vs.%20Vraska"},--Duel Decks: Jace vs. Vraska
[804]={id=804, lang={ "ENG",[3]="GER" }, fruc={ true }, url={ -- Challenge Deck: Battle the Horde
											"Born%20of%20the%20Gods"
											} },
[803]={id=803, lang={ "ENG",[3]="GER" }, fruc={ true }, url={ -- Challenge Deck: Face the Hydra
											"Theros"
											} },
[801]={id=801, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[7]="SPA",[8]="JPN" }, fruc={ true }, url="Commander%202013"},--Commander 2013
[799]={id=799, lang={ "ENG",[8]="JPN" }, fruc={ true }, url="Duel%20Decks:%20Heroes%20vs.%20Monsters"},--Duel Decks: Heroes vs. Monsters
[798]={id=798, lang={ "ENG" }, fruc={ true }, url="From%20the%20Vault:%20Twenty"},--From the Vault: Twenty
[796]={id=796, lang={ "ENG" }, fruc={ true }, url="Modern%20Masters"},--Modern Masters
[794]={id=794, lang={ "ENG",[8]="JPN" }, fruc={ true }, url="Duel%20Decks:%20Sorin%20vs.%20Tibalt"},--Duel Decks: Sorin vs. Tibalt
[792]={id=792, lang={ "ENG" }, fruc={ true }, url="Commander%27s%20Arsenal"},--Commander's Arsenal
[790]={id=790, lang={ "ENG",[8]="JPN" }, fruc={ true }, url="Duel%20Decks:%20Izzet%20vs.%20Golgari"},--Duel Decks: Izzet vs. Golgari
[789]={id=789, lang={ "ENG" }, fruc={ true }, url="From%20the%20Vault:%20Realms"},--From the Vault: Realms
[787]={id=787, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[7]="SPA",[8]="JPN" }, fruc={ true }, url="Planechase%202012"},--Planechase 2012
[785]={id=785, lang={ "ENG",[8]="JPN" }, fruc={ true }, url="Duel%20Decks:%20Venser%20vs.%20Koth"},--Duel Decks: Venser vs. Koth
[783]={id=783, lang={ "ENG" }, fruc={ true }, url="Premium%20Deck%20Series:%20Graveborn"},--Premium Deck Series: Graveborn
[781]={id=781, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[7]="SPA" }, fruc={ true }, url="Duel%20Decks:%20Ajani%20vs.%20Nicol%20Bolas"},--Duel Decks: Ajani vs. Nicol Bolas
[780]={id=780, lang={ "ENG" }, fruc={ true }, url="From%20the%20Vault:%20Legends"},--From the Vault: Legends
[778]={id=778, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[7]="SPA",[8]="JPN" }, fruc={ true }, url="Commander"},--Commander
[777]={id=777, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[7]="SPA" }, fruc={ true }, url="Duel%20Decks:%20Knights%20vs.%20Dragons"},--Duel Decks: Knights vs. Dragons
[774]={id=774, lang={ "ENG" }, fruc={ true }, url="Premium%20Deck%20Series:%20Fire%20&%20Lightning"},--Premium Deck Series: Fire & Lightning
[772]={id=772, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[7]="SPA" }, fruc={ true }, url="Duel%20Decks:%20Elspeth%20vs.%20Tezzeret"},--Duel Decks: Elspeth vs. Tezzeret
[771]={id=771, lang={ "ENG" }, fruc={ true }, url="From%20the%20Vault:%20Relics"},--From the Vault: Relics
[769]={id=769, lang={ "ENG" }, fruc={ true }, url="Archenemy"},--Archenemy
[768]={id=768, lang={ "ENG" }, fruc={ true }, url="Duels%20of%20the%20Planeswalkers%20Decks"},--Duels of the Planeswalkers Decks
[766]={id=766, lang={ "ENG",[8]="JPN" }, fruc={ true }, url="Duel%20Decks:%20Phyrexia%20vs.%20The%20Coalition"},--Duel Decks: Phyrexia vs. The Coalition
[764]={id=764, lang={ "ENG" }, fruc={ true }, url="Premium%20Deck%20Series:%20Slivers"},--Premium Deck Series: Slivers
[763]={id=763, lang={ "ENG" }, fruc={ true }, url="Duel%20Decks:%20Garruk%20vs.%20Liliana"},--Duel Decks: Garruk vs. Liliana
[761]={id=761, lang={ "ENG" }, fruc={ true }, url="Planechase"},--Planechase
[760]={id=760, lang={ "ENG" }, fruc={ true }, url="From%20the%20Vault:%20Exiled"},--From the Vault: Exiled
[757]={id=757, lang={ "ENG" }, fruc={ true }, url="Duel%20Decks:%20Divine%20vs.%20Demonic"},--Duel Decks: Divine vs. Demonic
[755]={id=755, lang={ "ENG",[8]="JPN" }, fruc={ true }, url="Duel%20Decks:%20Jace%20vs.%20Chandra"},--Duel Decks: Jace vs. Chandra
[753]={id=753, lang={ "ENG" }, fruc={ true }, url="From%20the%20Vault:%20Dragons"},--From the Vault: Dragons
[740]={id=740, lang={ "ENG" }, fruc={ true }, url="Duel%20Decks:%20Elves%20vs.%20Goblins"},--Duel Decks: Elves vs. Goblins
[675]={id=675, lang={ "ENG",[3]="GER",[5]="ITA" }, fruc={ true }, url="Coldsnap%20Theme%20Decks"},--Coldsnap Theme Decks
[636]={id=636, lang={ [7]="SPA" }, fruc={ true }, url="Salvat-Hachette%202011"},--Salvat-Hachette 2011
[635]={id=635, lang={ [4]="FRA",[5]="ITA",[7]="SPA" }, fruc={ true }, url="Salvat-Hachette"},--Salvat Magic Encyclopedia
[600]={id=600, lang={ "ENG" }, fruc={ true }, url="Unhinged"},--Unhinged
[490]={id=490, lang={ "ENG" }, fruc={ true }, url="Deckmasters"},--Deckmasters
[440]={id=440, lang={ "ENG" }, fruc={ true }, url="Beatdown"},--Beatdown
[415]={id=415, lang={ "ENG",[3]="GER",[7]="SPA" }, fruc={ true }, url="Starter%202000"},--Starter 2000
[405]={id=405, lang={ "ENG" }, fruc={ true }, url="Battle%20Royale"},--Battle Royale
[390]={id=390, lang={ "ENG" }, fruc={ true }, url={ --Starter 1999
											"Starter%201999",
											"Oversized%206x9%20Promos" -- "Thorn Elemental (oversized)"
											} },
[380]={id=380, lang={ "ENG",[8]="JPN" }, fruc={ true }, url="Portal%20Three%20Kingdoms"},--Portal Three Kingdoms
[340]={id=340, lang={ "ENG" }, fruc={ true }, url="Anthologies"},--Anthologies
[235]={id=235, lang={ "ENG" }, fruc={ true }, url="Multiverse%20Gift%20Box"},--Multiverse Gift Box
[320]={id=320, lang={ "ENG" }, fruc={ true }, url="Unglued"},--Unglued
[310]={id=310, lang={ "ENG",[3]="GER",[5]="ITA",[6]="POR",[8]="JPN" }, fruc={ true }, url="Portal%20Second%20Age"},--Portal Second Age
[260]={id=260, lang={ "ENG",[3]="GER",[8]="JPN" }, fruc={ true }, url="Portal"},--Portal
[225]={id=225, lang={ "ENG",[3]="GER",[4]="FRA",[7]="SPA" }, fruc={ true }, url="Introductory%20Two-Player%20Set"},--Introductory Two-Player Set
[201]={id=201, lang={ [3]="GER", [4]="FRA", [5]="ITA" }, fruc={ true }, url={ "Renaissance", "Rinascimento" } },--Renaissance
[200]={id=200, lang={ "ENG",[8]="JPN" }, fruc={ true }, url={
											"Chronicles",--Chronicles
											"Chronicles:%20Japanese",--Chronicles: Japanese
											} },
[106]={id=106, lang={ "ENG" }, fruc={ true }, url="International%20Edition"},--Collectors' Edition International
[105]={id=105, lang={ "ENG" }, fruc={ true }, url="Collectors%27%20Edition"},--Collectors' Edition
[70] ={id= 70, lang={ "ENG" }, fruc={ true }, url="Vanguard"},--Vanguard
[69] ={id= 69, lang={ "ENG" }, fruc={ true }, url="Oversized%20Box%20Toppers"},--Oversized Box Toppers
-- promosets
[55] ={id= 55, lang={ "ENG" }, fruc={ true }, url="Ugin%27s%20Fate%20Promos"},--Ugin's Fate Promos
[53] ={id= 53, lang={ "ENG" }, fruc={ true }, url={ --Holiday Gift Box Promos
											"Promos", -- "Dreg Mangler", "Karametra’s Acolyte"
											"Khans%20of%20Tarkir:%20Promos",-- "Sultai Charm"
											"Battle%20for%20Zendikar:%20Promos",-- "Scythe Leopard"
											"Shadows%20over%20Innistrad:%20Promos",-- "Ravenous Bloodseeker"
											} },
[52] ={id= 52, lang={ "ENG",[3]="GER" }, fruc={ true }, url={ --Intro Pack Promos
											"Khans%20of%20Tarkir:%20Promos",--Khans of Tarkir: Promos
											"Fate%20Reforged:%20Promos",--Fate Reforged: Promos
											"Dragons%20Of%20Tarkir:%20Promos",--Dragons Of Tarkir: Promos
											"Magic%20Origins:%20Promos",--Magic Origins: Promos
											"Battle%20for%20Zendikar:%20Promos",-- Battle for Zendikar: Promos
											"Oath%20of%20the%20Gatewatch:%20Promos",--Oath of the Gatewatch: Promos
											"Shadows%20over%20Innistrad:%20Promos",--Shadows over Innistrad: Promos
											} },
[50] ={id= 50, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[6]="POR",[7]="SPA",[8]="JPN" }, fruc={ true }, url={ --Full Box Promotion
											"Buy%20a%20Box%20Promos", --Buy a Box Promos
											"Promos", -- "Ruthless Cullblade (JPN)","Pestilence Demon (JPN)"
											} },
[45] ={id= 45, lang={ [8]="JPN" }, fruc={ true }, url="Magic%20Premiere%20Shop%20Promos"},--Magic Premiere Shop Promos
[43] ={id= 43, lang={ "ENG" }, fruc={ true }, url="DCI%20Promos"}, -- Two-Headed Giant Promos: in DCI Promos
[42] ={id= 42, lang={ "ENG" }, fruc={ true }, url="Gateway%20Promos"}, -- Summer of Magic Promos: in Gateway Promos
[41] ={id= 41, lang={ "ENG" }, fruc={ true }, url="Happy%20Holidays%20Promos"},--Happy Holidays Promos
[40] ={id= 40, lang={ "ENG",[3]="GER",[8]="JPN" }, fruc={ true }, url={ --Arena/Colosseo Leagues Promos
											"Arena%20League%20Promos",--Arena League Promos
											"League%20Tokens",--League Tokens
											"Oversized%206x9%20Promos",--Oversized 6x9 Promos
--											"Gateway%20Promos",--Gateway Promos
											} },
[34] ={id= 34, lang={ "ENG" }, fruc={ true }, url={ -- World Magic Cup Qualifiers Promos
											"DCI%20Promos",--DCI Promos
											"Promos", -- "Geist of Saint Traft"
											} },
[33] ={id= 33, lang={ "ENG" }, fruc={ true }, url={ -- Championships Prizes
											"DCI%20Promos",--DCI Promos
--											"Promos", -- "Geist of Saint Traft"-- now in WMCQ
											} },
[32] ={id= 32, lang={ "ENG",[8]="JPN" }, fruc={ true } , url={ --Pro Tour Promos
											"DCI%20Promos", -- Pro Tour Promos in DCI Promos
											"Pro%20Tour%20Promos", --Pro Tour Promos
											} },
[31] ={id= 31, lang={ "ENG" }, fruc={ true }, url={ -- Grand Prix Promos
											"Grand%20Prix%20Promos", --Grand Prix Promos
											"DCI%20Promos",--DCI Promos
											} },
[30] ={id= 30, lang={ "ENG",[2]="RUS",[3]="GER",[5]="ITA",[7]="SPA" }, fruc={ true }, url="Friday%20Night%20Magic%20Promos"},--Friday Night Magic Promos
[27] ={id= 27, lang={ "ENG" }, fruc={ true }, url={ -- Alternate Art Lands
											"APAC%20Lands",
											"Euro%20Lands",
											"Guru%20Lands",
											--"Promos", -- "Magic Guru" (not in set, but if anywhere, this would where it belonged
											} },
[26] ={id= 26, lang={ "ENG",[2]="RUS",[3]="GER",[7]="SPA" }, fruc={ true }, url={ -- "Magic Game Day"
											"Game%20Day%20Promos", -- Game Day Promos
											"Gateway%20Promos", -- "Naya Sojourners"
											"Release%20Promos", -- "Reya Dawnbringer"
											"Theros", -- "The Slayer"
											"Born%20of%20the%20Gods", -- "The Vanquisher"
											"Journey%20into%20Nyx", -- "The Champion"
											} },
[25] ={id= 25, lang={ "ENG",[3]="GER",[17]="PHY" }, fruc={ true }, url={ --Judge Gift Cards
											"Judge%20Rewards%20Promos",-- Judge Rewards Promos
											"Judge%20Program%20Tokens",--Judge Program Tokens
											} },
[24] ={id= 24, lang={ "ENG" }, fruc={ true }, url="Champs%20&%20States%20Promos"},--Champs & States Promos
[23] ={id= 23, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[7]="SPA",[8]="JPN" }, fruc={ true }, url="Gateway%20Promos"},--Gateway Promos
[22] ={id= 22, lang={ "ENG",[2]="RUS",[3]="GER",[7]="SPA",[12]="HEB",[13]="ARA",[14]="LAT",[15]="SAN",[16]="GRC" }, fruc={ true }, url={ --Prerelease Promos
											"Prerelease%20Promos", -- Prerelease Promos
--	no griselbrand here						"DCI%20Promos", -- DCI Promos ("Griselbrand") - DCI Griselbrand is GP; Prerelease Griselbrand is oversized!
											"Theros" , -- Theros (5 Hero Cards)
											"Born%20of%20the%20Gods", -- Born of the Gods (5 Hero Cards)
											"Journey%20into%20Nyx", -- Journey into Nyx (5 Hero Cards)
											"Dragons%20Of%20Tarkir:%20Promos",--Dragons Of Tarkir: Promos
											"Promos" , -- 4 Dragonfury variants
											"Fate%20Reforged:%20Promos",--Fate Reforged: Promos
											"Khans%20of%20Tarkir:%20Promos",--Khans of Tarkir: Promos
											"Magic%20Origins:%20Promos",--Magic Origins: Promos
											"Oversized%206x9%20Promos", -- Oversized 6x9 Promos ("Garruk the Slayer (oversized)")
--											"Battle%20for%20Zendikar:%20Promos",--Battle for Zendikar Promos
--											"Oath%20of%20the%20Gatewatch:%20Promos",--Oath of the Gatewatch: Promos
--											"Shadows%20over%20Innistrad:%20Promos",--Shadows over Innistrad: Promos
											} },
[21] ={id= 21, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[7]="SPA",[8]="JPN" }, fruc={ true }, url={ --Release & Launch Party Promos
											"Release%20Promos", -- Release Promos
											"Oversized%206x9%20Promos", -- "Incoming! (oversized)"
											"Prerelease%20Promos", -- "Lord of Shatterskull Pass"
											"Theros" , -- "The Harvester"
											"Born%20of%20the%20Gods", -- "The Explorer"
											"Journey%20into%20Nyx", -- "The Destined"
											"Magic%20Origins:%20Promos",--"Mizzium Meddler"
											"Shadows%20over%20Innistrad:%20Promos",--"Angel of Deliverance"
											} },
[20] ={id= 20, lang={ "ENG" }, fruc={ true }, url="Player%20Rewards%20Promos"},--Player Rewards Promos
[15]= {id= 15, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[7]="SPA",[8]="JPN" }, fruc={ true }, url={-- Convention Promos
											"Convention%20Promos", --Convention Promos
											"San%20Diego%20Comic-Con%202015%20Promos",--San Diego Comic-Con 2015 Promos
											"San%20Diego%20Comic-Con%202013%20Promos", --San Diego Comic-Con 2013 Promos
											"San%20Diego%20Comic-Con%202014%20Promos", --San Diego Comic-Con 2014 Promos
											"Oversized%206x9%20Promos", -- "Serra Angel (oversized)","Hurloon Minotaur (oversized)"
											"DCI%20Promos", -- 6 cards
											"Promos", -- "Stealer of Secrets" (Gamescon 2014, not yet in MA)
											"Dengeki%20Maoh%20Promos", -- "Shepherd of the Lost" (Dengeki Character Festival)
											} },
[12] ={id= 12, lang={ [8]="JPN" }, fruc={ true }, url="Hobby%20Japan%20Commemorative%20Promos"},--Hobby Japan Commemorative Promos
[11] = nil, -- Redemption Program Cards
[10] ={id= 10, lang={ "ENG",[8]="JPN" }, fruc={ true }, url={ -- Junior Series Promos
											"Junior%20APAC%20Series%20Promos",--Junior APAC Series Promos (6 cards) - 6 ENG, all (U)
											"Junior%20Series%20Promos",--Junior Series Promos (8 cards) - 8 ENG, all (E)
											"Junior%20Super%20Series%20Promos",--Junior Super Series Promos (14 cards)
											"Japan%20Junior%20Tournament%20Promos",--Japan Junior Tournament Promos (11 cards) -- 11 JPN ""
											"Magic%20Scholarship%20Series%20Promos",--Magic Scholarship Series Promos (5 cards) - 5 EN, 1 "", 4 (J)
											} },
[9]=  {id=  9, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[7]="SPA" }, fruc={ true }, url={ -- Video Game Promos
											"Duels%20of%20the%20Planeswalkers%20Promos",--Duels of the Planeswalkers Promos
											"Oversized%206x9%20Promos", -- "Aswan Jaguar (oversized)"
											} },
[8]=  {id=  8, lang={ "ENG",[5]="ITA",[8]="JPN" }, fruc={ true }, url={ -- Stores Promos
											"Resale%20Promos",--Resale Promos
--											"Walmart%20Promos", -- Walmart Promos
											"DCI%20Promos", -- DCI Promos
											"Promos", -- 3 jp
											} },
[7]=  {id=  7, lang={ "ENG",[3]="GER",[8]="JPN" }, fruc={ true },	url={ -- "Magazine Inserts"
											"The%20Duelist%20Promos",--The Duelist Promos
											"CardZ%20Promos",--CardZ Promos
											"TopDeck%20Promos",--TopDeck Promos
											"Oversized%206x9%20Promos", -- 5 oversized
											"Promos", -- 1 Kartefakt(de), 2 Gotta Magazine(jp)
											} },
[6]=  {id=  6, lang={ "ENG",[8]="JPN" }, fruc={ true }, url={ -- Comic Inserts
											"Armada%20Comics",--Armada Comics
											"Dengeki%20Maoh%20Promos",--Dengeki Maoh Promos
											"IDW%20Promos",--IDW Promos
											"Oversized%206x9%20Promos",--Oversized 6x9 Promos
											"Promos", -- 4 jp
											} },
[5]=  {id=  5, lang={ "ENG",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA" }, fruc={ true }, url={ -- Book Inserts
											"Harper%20Prism%20Promos",--Harper Prism Promos
											"DCI%20Promos",--DCI Promos "Jace Beleren"
											} },
[4]  =nil, -- Ultra Rare Cards
[2]  ={id=  2, lang={ "ENG" }, fruc={ true }, url="DCI%20Promos"},-- DCI Legend Membership in DCI Promos
-- unknown to MA
[9990]={id=  0, lang=all, fruc={ true }, url={
										"MKM%20Products",--MKM Products
										"MKM%20Series%20Promos",--MKM Series Promos
										} },
[9991]={id=  0, lang=all, fruc={ true }, url="Simplified%20Chinese%20Alternate%20Art%20Cards"},--Simplified Chinese Alternate Art Cards
[9992]={id=  0, lang=all, fruc={ true }, url={
										"Misprints",--Misprints
										"Fallen%20Empires:%20Wyvern%20Misprints",--Fallen Empires: Wyvern Misprints
										} },
[9993]={id=  0, lang=all, fruc={ true }, url="Oversized%209x12%20Promos"},--Oversized 9x12 Promos
[9994]={id=  0, lang={ "ENG" }, fruc={ true }, url="Fourth%20Edition:%20Alternate"},--Fourth Edition: Alternate ("Summer 4th")
[9995]={id=  0, lang=all, fruc={ true }, url={
										"Ultra-Pro%20Puzzle%20Cards",--Ultra-Pro Puzzle Cards
										"Filler%20Cards",--Filler Cards
										"Blank%20Cards",--Blank Cards
										} },
[9996]={id=  0, lang=all, fruc={ true }, url={-- these are preconstructed decks
										"Pro%20Tour%201996:%20Mark%20Justice",--Pro Tour 1996: Mark Justice
										"Pro%20Tour%201996:%20Michael%20Locanto",--Pro Tour 1996: Michael Locanto
										"Pro%20Tour%201996:%20Bertrand%20Lestree",--Pro Tour 1996: Bertrand Lestree
										"Pro%20Tour%201996:%20Preston%20Poulter",--Pro Tour 1996: Preston Poulter
										"Pro%20Tour%201996:%20Eric%20Tam",--Pro Tour 1996: Eric Tam
										"Pro%20Tour%201996:%20Shawn%20Regnier",--Pro Tour 1996: Shawn Regnier
										"Pro%20Tour%201996:%20George%20Baxter",--Pro Tour 1996: George Baxter
										"Pro%20Tour%201996:%20Leon%20Lindback",--Pro Tour 1996: Leon Lindback
										} },
[9997]={id=  0, lang=all, fruc={ true }, url={
										"World%20Championship%20Decks",--World Championship Decks
										"WCD%201997:%20Svend%20Geertsen",--WCD 1997: Svend Geertsen
										"WCD%201997:%20Jakub%20Slemr",--WCD 1997: Jakub Slemr
										"WCD%201997:%20Janosch%20Kuhn",--WCD 1997: Janosch Kuhn
										"WCD%201997:%20Paul%20McCabe",--WCD 1997: Paul McCabe
										"WCD%201998:%20Brian%20Selden",--WCD 1998: Brian Selden
										"WCD%201998:%20Randy%20Buehler",--WCD 1998: Randy Buehler
										"WCD%201998:%20Brian%20Hacker",--WCD 1998: Brian Hacker
										"WCD%201998:%20Ben%20Rubin",--WCD 1998: Ben Rubin
										"WCD%201999:%20Jakub%20%C5%A0lemr",--WCD 1999: Jakub Šlemr
										"WCD%201999:%20Matt%20Linde",--WCD 1999: Matt Linde
										"WCD%201999:%20Mark%20Le%20Pine",--WCD 1999: Mark Le Pine
										"WCD%201999:%20Kai%20Budde",--WCD 1999: Kai Budde
										"WCD%202000:%20Janosch%20K%C3%BChn",--WCD 2000: Janosch Kühn
										"WCD%202000:%20Jon%20Finkel",--WCD 2000: Jon Finkel
										"WCD%202000:%20Nicolas%20Labarre",--WCD 2000: Nicolas Labarre
										"WCD%202000:%20Tom%20Van%20de%20Logt",--WCD 2000: Tom Van de Logt
										"WCD%202001:%20Alex%20Borteh",--WCD 2001: Alex Borteh
										"WCD%202001:%20Tom%20van%20de%20Logt",--WCD 2001: Tom van de Logt
										"WCD%202001:%20Jan%20Tomcani",--WCD 2001: Jan Tomcani
										"WCD%202001:%20Antoine%20Ruel",--WCD 2001: Antoine Ruel
										"WCD%202002:%20Carlos%20Romao",--WCD 2002: Carlos Romao
										"WCD%202002:%20Sim%20Han%20How",--WCD 2002: Sim Han How
										"WCD%202002:%20Raphael%20Levy",--WCD 2002: Raphael Levy
										"WCD%202002:%20Brian%20Kibler",--WCD 2002: Brian Kibler
										"WCD%202003:%20Dave%20Humpherys",--WCD 2003: Dave Humpherys
										"WCD%202003:%20Daniel%20Zink",--WCD 2003: Daniel Zink
										"WCD%202003:%20Peer%20Kr%C3%B6ger",--WCD 2003: Peer Kröger
										"WCD%202003:%20Wolfgang%20Eder",--WCD 2003: Wolfgang Eder
										"WCD%202004:%20Gabriel%20Nassif",--WCD 2004: Gabriel Nassif
										"WCD%202004:%20Manuel%20Bevand",--WCD 2004: Manuel Bevand
										"WCD%202004:%20Aeo%20Paquette",--WCD 2004: Aeo Paquette
										"WCD%202004:%20Julien%20Nuijten",--WCD 2004: Julien Nuijten
										} },
[9998]={id=  0, lang=all, fruc={ true }, url={ -- actual Pro-Players on baseballcard-like cards
										"2005%20Player%20Cards",--2005 Player Cards
										"2006%20Player%20Cards",--2006 Player Cards
										"2007%20Player%20Cards",--2007 Player Cards
										} },
[9999]={id=  0, lang=all, fruc={ true }, url={ -- custom tokens
										"Custom%20Tokens",--Custom Tokens
										"GamingEtc%20Tokens",--GamingEtc Tokens
										"Yummy%20Tokens",--Yummy Tokens
										"Revista%20Serra%20Promos",--Revista Serra Promos
										"Your%20Move%20Games%20Tokens",--Your Move Games Tokens
										"Tierra%20Media%20Tokens",--Tierra Media Tokens
										"TokyoMTG%20Products",--TokyoMTG Products
										"Mystic%20Shop%20Products",--Mystic Shop Products
										"Tokens%20for%20MTG",--Tokens for MTG
										"JingHe%20Age:%202002%20Tokens",--JingHe Age: 2002 Tokens
										"JingHe%20Age:%20MtG%2010th%20Anniversary%20Tokens",--JingHe Age: MtG 10th Anniversary Tokens
										"Starcity%20Games:%20Commemorative%20Tokens",--Starcity Games: Commemorative Tokens
										"Starcity%20Games:%20Creature%20Collection",--Starcity Games: Creature Collection
										"Starcity%20Games:%20Justin%20Treadway%20Tokens",--Starcity Games: Justin Treadway Tokens
										"Starcity%20Games:%20Kristen%20Plescow%20Tokens",--Starcity Games: Kristen Plescow Tokens
										"Starcity%20Games:%20Token%20Series%20One",--Starcity Games: Token Series One
										"Javi%20Alterations%20Tokens",--Javi Alterations Tokens
										"GnD%20Cards",--GnD Cards
										} },
	}
--end table site.sets

--[[- card name replacement tables.

  fields are for subtables indexed by #number setid.
 { #number (setid)= #table { #string (oldname)= #string (newname), ... } , ... }
 
 @type site.namereplace
 @field [parent=#site.namereplace] #string name
]]
site.namereplace = {
[822]={-- Origins
["Ashaya, the Awoken World"]	= "Ashaya, the Awoken World Token",
},
[139]={-- Revised Edition (FBB)
["Plains (293)"]		= "Plains (1)",
["Plains (294)"]		= "Plains (2)",
["Plains (295)"]		= "Plains (3)",
["Island (287)"]		= "Island (1)",
["Island (288)"]		= "Island (2)",
["Island (289)"]		= "Island (3)",
["Swamp (299)"]			= "Swamp (1)",
["Swamp (300)"]			= "Swamp (2)",
["Swamp (301)"]			= "Swamp (3)",
["Mountain (290)"]		= "Mountain (1)",
["Mountain (291)"]		= "Mountain (2)",
["Mountain (292)"]		= "Mountain (3)",
["Forest (284)"]		= "Forest (1)",
["Forest (285)"]		= "Forest (2)",
["Forest (286)"]		= "Forest (3)",
},
[829] = { -- Oath of the Gatewatch
["Wastes (1)"]			= "Wastes (183F)",
["Wastes (2)"]			= "Wastes (183)",
["Wastes (3)"]			= "Wastes (184F)",
["Wastes (4)"]			= "Wastes (184)",
},
[825] = { --Battle for Zendikar
["Plains (1)"]			= "Plains (250)",
["Plains (2)"]			= "Plains (250F)",
["Plains (3)"]			= "Plains (251)",
["Plains (4)"]			= "Plains (251F)",
["Plains (5)"]			= "Plains (252)",
["Plains (6)"]			= "Plains (252F)",
["Plains (7)"]			= "Plains (253)",
["Plains (8)"]			= "Plains (253F)",
["Plains (9)"]			= "Plains (254)",
["Plains (10)"]			= "Plains (254F)",
["Island (1)"]			= "Island (255)",
["Island (2)"]			= "Island (255F)",
["Island (3)"]			= "Island (256)",
["Island (4)"]			= "Island (256F)",
["Island (5)"]			= "Island (257)",
["Island (6)"]			= "Island (257F)",
["Island (7)"]			= "Island (258)",
["Island (8)"]			= "Island (258F)",
["Island (9)"]			= "Island (259)",
["Island (10)"]			= "Island (259F)",
["Swamp (1)"]			= "Swamp (260)",
["Swamp (2)"]			= "Swamp (260F)",
["Swamp (3)"]			= "Swamp (261)",
["Swamp (4)"]			= "Swamp (261F)",
["Swamp (5)"]			= "Swamp (262)",
["Swamp (6)"]			= "Swamp (262F)",
["Swamp (7)"]			= "Swamp (263)",
["Swamp (8)"]			= "Swamp (263F)",
["Swamp (9)"]			= "Swamp (264)",
["Swamp (10)"]			= "Swamp (264F)",
["Mountain (1)"]		= "Mountain (265)",
["Mountain (2)"]		= "Mountain (265F)",
["Mountain (3)"]		= "Mountain (266)",
["Mountain (4)"]		= "Mountain (266F)",
["Mountain (5)"]		= "Mountain (267)",
["Mountain (6)"]		= "Mountain (267F)",
["Mountain (7)"]		= "Mountain (268)",
["Mountain (8)"]		= "Mountain (268F)",
["Mountain (9)"]		= "Mountain (269)",
["Mountain (10)"]		= "Mountain (269F)",
["Forest (1)"]			= "Forest (270)",
["Forest (2)"]			= "Forest (270F)",
["Forest (3)"]			= "Forest (271)",
["Forest (4)"]			= "Forest (271F)",
["Forest (5)"]			= "Forest (272)",
["Forest (6)"]			= "Forest (272F)",
["Forest (7)"]			= "Forest (273)",
["Forest (8)"]			= "Forest (273F)",
["Forest (9)"]			= "Forest (274)",
["Forest (10)"]			= "Forest (274F)",
},
[818] = { -- Dragons  of Tarkir
--["Narset Transcendent Emblem"]				= "Narset Emblem",
},
[817] = { --Duel Decks: Anthology
["Plains (5026)"]		= "Plains (DVD 26)",
["Plains (5027)"]		= "Plains (DVD 27)",
["Plains (5028)"]		= "Plains (DVD 28)",
["Plains (5029)"]		= "Plains (DVD 29)",
["Island (3030)"]		= "Island (JVC 30)",
["Island (3031)"]		= "Island (JVC 31)",
["Island (3032)"]		= "Island (JVC 32)",
["Island (3033)"]		= "Island (JVC 33)",
["Swamp (6059)"]			= "Swamp (DVD 59)",
["Swamp (6060)"]			= "Swamp (DVD 60)",
["Swamp (6061)"]			= "Swamp (DVD 61)",
["Swamp (6062)"]			= "Swamp (DVD 62)",
["Swamp (8060)"]			= "Swamp (GVL 60)",
["Swamp (8061)"]			= "Swamp (GVL 61)",
["Swamp (8062)"]			= "Swamp (GVL 62)",
["Swamp (8063)"]			= "Swamp (GVL 63)",
["Mountain (2059)"]		= "Mountain (EVG 59)",
["Mountain (2060)"]		= "Mountain (EVG 60)",
["Mountain (2061)"]		= "Mountain (EVG 61)",
["Mountain (2062)"]		= "Mountain (EVG 62)",
["Mountain (4059)"]		= "Mountain (JVC 59)",
["Mountain (4060)"]		= "Mountain (JVC 60)",
["Mountain (4061)"]		= "Mountain (JVC 61)",
["Mountain (4062)"]		= "Mountain (JVC 62)",
["Forest (1028)"]		= "Forest (EVG 28)",
["Forest (1029)"]		= "Forest (EVG 29)",
["Forest (1030)"]		= "Forest (EVG 30)",
["Forest (1031)"]		= "Forest (EVG 31)",
["Forest (7028)"]		= "Forest (GVL 28)",
["Forest (7029)"]		= "Forest (GVL 29)",
["Forest (7030)"]		= "Forest (GVL 30)",
["Forest (7031)"]		= "Forest (GVL 31)",
["Angel's Feather"]			= "Angel’s Feather",
["Demon's Horn"]			= "Demon’s Horn",
["Demon's Jester"]			= "Demon’s Jester",
["Faith's Fetters"]			= "Faith’s Fetters",
["Man-o'-War"]				= "Man-o’-War",
["Nature's Lore"]			= "Nature’s Lore",
["Serra's Boon"]			= "Serra’s Boon",
["Serra's Embrace"]			= "Serra’s Embrace",
["Wren's Run Vanquisher"]	= "Wren’s Run Vanquisher",
["Corrupt (1)"]				= "Corrupt (55)",
["Corrupt (2)"]				= "Corrupt (57)",
["Flamewave Invoker (1)"]	= "Flamewave Invoker (40)",
["Flamewave Invoker (2)"]	= "Flamewave Invoker (36)",
["Giant Growth (1)"]		= "Giant Growth (14)",
["Giant Growth (2)"]		= "Giant Growth (21)",
["Harmonize (1)"]			= "Harmonize (22)",
["Harmonize (2)"]			= "Harmonize (21)",
["Bat Token (11)"]				= "Bat Token",
["Demon Token (6)"]				= "Demon Token",
["Elf Warrior Token (2)"]		= "Elf Warrior Token",
["Elemental Token (1)"]			= "Elemental Token",
["Elemental Shaman Token (4)"]	= "Elemental Shaman Token",
["Elephant Token (10)"]			= "Elephant Token",
["Goblin Token (3)"]			= "Goblin Token",
["Spirit Token (5)"]			= "Spirit Token",
["Thrull Token (7)"]			= "Thrull Token",
},
[802] = { -- Born of the Gods
["Unravel the Æther"]				= "Unravel the AEther",
},
[784] = { -- Dark Ascension
["Hinterland Hermit"] 				= "Hinterland Hermit|Hinterland Scourge",
["Mondronen Shaman"] 				= "Mondronen Shaman|Tovolar’s Magehunter",
["Soul Seizer"] 					= "Soul Seizer|Ghastly Haunting",
["Lambholt Elder"] 					= "Lambholt Elder|Silverpelt Werewolf",
["Ravenous Demon"] 					= "Ravenous Demon|Archdemon of Greed",
["Elbrus, the Binding Blade"] 		= "Elbrus, the Binding Blade|Withengar Unbound",
["Loyal Cathar"] 					= "Loyal Cathar|Unhallowed Cathar",
["Chosen of Markov"] 				= "Chosen of Markov|Markov’s Servant",
["Huntmaster of the Fells"] 		= "Huntmaster of the Fells|Ravager of the Fells",
["Afflicted Deserter"] 				= "Afflicted Deserter|Werewolf Ransacker",
["Chalice of Life"] 				= "Chalice of Life|Chalice of Death",
["Wolfbitten Captive"] 				= "Wolfbitten Captive|Krallenhorde Killer",
["Scorned Villager"]				= "Scorned Villager|Moonscarred Werewolf",
},
[782] = { -- Innistrad
["Bloodline Keeper"] 				= "Bloodline Keeper|Lord of Lineage",
["Ludevic's Test Subject"] 			= "Ludevic's Test Subject|Ludevic's Abomination",
["Instigator Gang"] 				= "Instigator Gang|Wildblood Pack",
["Kruin Outlaw"] 					= "Kruin Outlaw|Terror of Kruin Pass",
["Daybreak Ranger"] 				= "Daybreak Ranger|Nightfall Predator",
["Garruk Relentless"] 				= "Garruk Relentless|Garruk, the Veil-Cursed",
["Mayor of Avabruck"] 				= "Mayor of Avabruck|Howlpack Alpha",
["Cloistered Youth"] 				= "Cloistered Youth|Unholy Fiend",
["Civilized Scholar"] 				= "Civilized Scholar|Homicidal Brute",
["Screeching Bat"] 					= "Screeching Bat|Stalking Vampire",
["Hanweir Watchkeep"] 				= "Hanweir Watchkeep|Bane of Hanweir",
["Reckless Waif"] 					= "Reckless Waif|Merciless Predator",
["Gatstaf Shepherd"] 				= "Gatstaf Shepherd|Gatstaf Howler",
["Ulvenwald Mystics"] 				= "Ulvenwald Mystics|Ulvenwald Primordials",
["Thraben Sentry"] 					= "Thraben Sentry|Thraben Militia",
["Delver of Secrets"] 				= "Delver of Secrets|Insectile Aberration",
["Tormented Pariah"] 				= "Tormented Pariah|Rampaging Werewolf",
["Village Ironsmith"] 				= "Village Ironsmith|Ironfang",
["Grizzled Outcasts"] 				= "Grizzled Outcasts|Krallenhorde Wantons",
["Villagers of Estwald"] 			= "Villagers of Estwald|Howlpack of Estwald",
},
[762] = { --Zendikar
["Plains (1)"]			= "Plains (230a)",
["Plains (2)"]			= "Plains (230)",
["Plains (3)"]			= "Plains (231a)",
["Plains (4)"]			= "Plains (231)",
["Plains (5)"]			= "Plains (232a)",
["Plains (6)"]			= "Plains (232)",
["Plains (7)"]			= "Plains (233a)",
["Plains (8)"]			= "Plains (233)",
["Island (1)"]			= "Island (234a)",
["Island (2)"]			= "Island (234)",
["Island (3)"]			= "Island (235a)",
["Island (4)"]			= "Island (235)",
["Island (5)"]			= "Island (236a)",
["Island (6)"]			= "Island (236)",
["Island (7)"]			= "Island (237a)",
["Island (8)"]			= "Island (237)",
["Swamp (1)"]			= "Swamp (238a)",
["Swamp (2)"]			= "Swamp (238)",
["Swamp (3)"]			= "Swamp (239a)",
["Swamp (4)"]			= "Swamp (239)",
["Swamp (5)"]			= "Swamp (240a)",
["Swamp (6)"]			= "Swamp (240)",
["Swamp (7)"]			= "Swamp (241a)",
["Swamp (8)"]			= "Swamp (241)",
["Mountain (1)"]		= "Mountain (242a)",
["Mountain (2)"]		= "Mountain (242)",
["Mountain (3)"]		= "Mountain (243a)",
["Mountain (4)"]		= "Mountain (243)",
["Mountain (5)"]		= "Mountain (244a)",
["Mountain (6)"]		= "Mountain (244)",
["Mountain (7)"]		= "Mountain (245a)",
["Mountain (8)"]		= "Mountain (245)",
["Forest (1)"]			= "Forest (246a)",
["Forest (2)"]			= "Forest (246)",
["Forest (3)"]			= "Forest (247a)",
["Forest (4)"]			= "Forest (247)",
["Forest (5)"]			= "Forest (248a)",
["Forest (6)"]			= "Forest (248)",
["Forest (7)"]			= "Forest (249a)",
["Forest (8)"]			= "Forest (249)",
},
[620] = { -- Saviors of Kamigawa
["Sasaya, Orochi Ascendant"] 		= "Sasaya, Orochi Ascendant|Sasaya’s Essence",
["Rune-Tail, Kitsune Ascendant"]	= "Rune-Tail, Kitsune Ascendant|Rune-Tail’s Essence",
["Homura, Human Ascendant"] 		= "Homura, Human Ascendant|Homura’s Essence",
["Kuon, Ogre Ascendant"] 			= "Kuon, Ogre Ascendant|Kuon’s Essence",
["Erayo, Soratami Ascendant"] 		= "Erayo, Soratami Ascendant|Erayo’s Essence"
},
[610] = { -- Betrayers of Kamigawa
["Hired Muscle"] 					= "Hired Muscle|Scarmaker",
["Cunning Bandit"] 					= "Cunning Bandit|Azamuki, Treachery Incarnate",
["Callow Jushi"] 					= "Callow Jushi|Jaraku the Interloper",
["Faithful Squire"] 				= "Faithful Squire|Kaiso, Memory of Loyalty",
["Budoka Pupil"] 					= "Budoka Pupil|Ichiga, Who Topples Oaks",
},
[590] = { -- Champions of Kamigawa
["Student of Elements"]				= "Student of Elements|Tobita, Master of Winds",
["Kitsune Mystic"]					= "Kitsune Mystic|Autumn-Tail, Kitsune Sage",
["Initiate of Blood"]				= "Initiate of Blood|Goka the Unjust",
["Bushi Tenderfoot"]				= "Bushi Tenderfoot|Kenzo the Hardhearted",
["Budoka Gardener"]					= "Budoka Gardener|Dokai, Weaver of Life",
["Nezumi Shortfang"]				= "Nezumi Shortfang|Stabwhisker the Odious",
["Jushi Apprentice"]				= "Jushi Apprentice|Tomoya the Revealer",
["Orochi Eggwatcher"]				= "Orochi Eggwatcher|Shidako, Broodmistress",
["Nezumi Graverobber"]				= "Nezumi Graverobber|Nighteyes the Desecrator",
["Akki Lavarunner"]					= "Akki Lavarunner|Tok-Tok, Volcano Born",
["Brothers Yamazaki (1)"]			= "Brothers Yamazaki (160a)",
["Brothers Yamazaki (2)"]			= "Brothers Yamazaki (160b)",
},
[450] = { -- Planeshift
["Ertai, the Corrupted (2)"] 		= "Ertai, the Corrupted (Alt)",
["Skyship Weatherlight (2)"] 		= "Skyship Weatherlight (Alt)",
["Tahngarth, Talruum Hero (2)"]		= "Tahngarth, Talruum Hero (Alt)",
["Ertai, the Corrupted (1)"] 		= "Ertai, the Corrupted",
["Skyship Weatherlight (1)"] 		= "Skyship Weatherlight",
["Tahngarth, Talruum Hero (1)"]		= "Tahngarth, Talruum Hero",
},
[240] = { -- Visions
["Jamuraan Lion (1)"]				= "Jamuraan Lion",
["Jamuraan Lion (2)"]				= "Jamuraan Lion",
},
-- special sets and promos
[828] = { --Commander 2015
["Daxos the Returned (1)"]			= "Daxos the Returned",
["Daxos the Returned (2)"]			= "Daxos the Returned (oversized)",
["Ezuri, Claw of Progress (1)"]		= "Ezuri, Claw of Progress",
["Ezuri, Claw of Progress (2)"]		= "Ezuri, Claw of Progress (oversized)",
["Kalemne, Disciple of Iroas (1)"]	= "Kalemne, Disciple of Iroas",
["Kalemne, Disciple of Iroas (2)"]	= "Kalemne, Disciple of Iroas (oversized)",
["Meren of Clan Nel Toth (1)"]		= "Meren of Clan Nel Toth",
["Meren of Clan Nel Toth (2)"]		= "Meren of Clan Nel Toth (oversized)",
["Mizzix of the Izmagnus (1)"]		= "Mizzix of the Izmagnus",
["Mizzix of the Izmagnus (2)"]		= "Mizzix of the Izmagnus (oversized)",
},
[821] = { --Challenge Deck: Defeat a God
["Estatic Piper (nontrad)"]				= "Ecstatic Piper (nontrad)",
["Xenagos's Scorn (nontrad)"]			= "Xenagos’s Scorn (nontrad)",
["Xenagos's Strike (nontrad)"]			= "Xenagos’s Strike (nontrad)",
},
[814] = { --Commander 2014
["Daretti, Scrap Savant (1)"]			= "Daretti, Scrap Savant",
["Daretti, Scrap Savant (2)"]			= "Daretti, Scrap Savant (oversized)",
--["Daretti, Scrap Savant Emblem"]		= "Daretti Emblem",
["Freyalise, Llanowar's Fury (1)"]		= "Freyalise, Llanowar’s Fury",
["Freyalise, Llanowar's Fury (2)"]		= "Freyalise, Llanowar’s Fury (oversized)",
["Nahiri, the Lithomancer (1)"]			= "Nahiri, the Lithomancer",
["Nahiri, the Lithomancer (2)"]			= "Nahiri, the Lithomancer (oversized)",
["Ob Nixilis of the Black Oath (1)"]	= "Ob Nixilis of the Black Oath",
["Ob Nixilis of the Black Oath (2)"]	= "Ob Nixilis of the Black Oath (oversized)",
--["Ob Nixilis of the Black Oath Emblem"]	= "Nixilis Emblem",
["Teferi, Temporal Archmage (1)"]		= "Teferi, Temporal Archmage",
["Teferi, Temporal Archmage (2)"]		= "Teferi, Temporal Archmage (oversized)",
--["Teferi, Temporal Archmage Emblem"]	= "Teferi Emblem",
},
[810] = { --Modern Event Deck 2014
["Myr|Spirit Token"]				= "Spirit Token|Myr Token",
["Elspeth Emblem|Soldier Token"]	= "Soldier Token|Elspeth, Knight-Errant Emblem",
},
[801] = { -- Commander 2013
["Plains (325)"]	= "Plains (337)",
["Plains (326)"]	= "Plains (338)",
["Plains (327)"]	= "Plains (339)",
["Plains (328)"]	= "Plains (340)",
["Island (300)"]	= "Island (341)",
["Island (301)"]	= "Island (342)",
["Island (302)"]	= "Island (343)",
["Island (303)"]	= "Island (344)",
["Swamp (343)"]		= "Swamp (345)",
["Swamp (344)"]		= "Swamp (346)",
["Swamp (345)"]		= "Swamp (347)",
["Swamp (346)"]		= "Swamp (348)",
["Mountain (316)"]	= "Mountain (349)",
["Mountain (317)"]	= "Mountain (350)",
["Mountain (318)"]	= "Mountain (351)",
["Mountain (319)"]	= "Mountain (352)",
["Forest (289)"]	= "Forest (353)",
["Forest (290)"]	= "Forest (354)",
["Forest (291)"]	= "Forest (355)",
["Forest (292)"]	= "Forest (356)",
['Kongming, "Sleeping Dragon"']		= "Kongming, “Sleeping Dragon”",
["Derevi, Empyrial Tactician (1)"]	= "Derevi, Empyrial Tactician",
["Derevi, Empyrial Tactician (2)"]	= "Derevi, Empyrial Tactician (oversized)",
["Gahiji, Honored One (1)"]			= "Gahiji, Honored One",
["Gahiji, Honored One (2)"]			= "Gahiji, Honored One (oversized)",
["Jeleva, Nephalia's Scourge (1)"]	= "Jeleva, Nephalia’s Scourge",
["Jeleva, Nephalia's Scourge (2)"]	= "Jeleva, Nephalia’s Scourge (oversized)",
["Marath, Will of the Wild (1)"]	= "Marath, Will of the Wild",
["Marath, Will of the Wild (2)"]	= "Marath, Will of the Wild (oversized)",
["Mayael the Anima (1)"]			= "Mayael the Anima",
["Mayael the Anima (2)"]			= "Mayael the Anima (oversized)",
["Nekusar, the Mindrazer (1)"]		= "Nekusar, the Mindrazer",
["Nekusar, the Mindrazer (2)"]		= "Nekusar, the Mindrazer (oversized)",
["Oloro, Ageless Ascetic (1)"]		= "Oloro, Ageless Ascetic",
["Oloro, Ageless Ascetic (2)"]		= "Oloro, Ageless Ascetic (oversized)",
["Prossh, Skyraider of Kher (1)"]	= "Prossh, Skyraider of Kher",
["Prossh, Skyraider of Kher (2)"]	= "Prossh, Skyraider of Kher (oversized)",
["Roon of the Hidden Realm (1)"]	= "Roon of the Hidden Realm",
["Roon of the Hidden Realm (2)"]	= "Roon of the Hidden Realm (oversized)",
["Rubinia Soulsinger (1)"]			= "Rubinia Soulsinger",
["Rubinia Soulsinger (2)"]			= "Rubinia Soulsinger (oversized)",
["Sek'Kuar, Deathkeeper (1)"]		= "Sek’Kuar, Deathkeeper",
["Sek'Kuar, Deathkeeper (2)"]		= "Sek’Kuar, Deathkeeper (oversized)",
["Sharuum the Hegemon (1)"]			= "Sharuum the Hegemon",
["Sharuum the Hegemon (2)"]			= "Sharuum the Hegemon (oversized)",
["Shattergang Brothers (1)"]		= "Shattergang Brothers",
["Shattergang Brothers (2)"]		= "Shattergang Brothers (oversized)",
["Sydri, Galvanic Genius (1)"]		= "Sydri, Galvanic Genius",
["Sydri, Galvanic Genius (2)"]		= "Sydri, Galvanic Genius (oversized)",
["Thraximundar (1)"]				= "Thraximundar",
["Thraximundar (2)"]				= "Thraximundar (oversized)",
},
[792] = { -- Commander's Arsenal
["Azusa, Lost but Seeking"]			= "Azusa, Lost but Seeking (oversized)",
["Brion Stoutarm"]					= "Brion Stoutarm (oversized)",
["Glissa, the Traitor"]				= "Glissa, the Traitor (oversized)",
["Godo, Bandit Warlord"]			= "Godo, Bandit Warlord (oversized)",
["Grimgrin, Corpse-Born"]			= "Grimgrin, Corpse-Born (oversized)",
["Karn, Silver Golem"]				= "Karn, Silver Golem (oversized)",
["Karrthus, Tyrant of Jund"]		= "Karrthus, Tyrant of Jund (oversized)",
["Mayael the Anima"]				= "Mayael the Anima (oversized)",
["Sliver Queen"]					= "Sliver Queen (oversized)",
["Zur the Enchanter"]				= "Zur the Enchanter (oversized)",
},
[787] = { -- Planechase 2012
["Norn's Dominion"]					= "Norn’s Dominion",
},
[785] = { -- DD: Venser vs Koth
["Plains (1)"]			= "Plains (38)",
["Plains (2)"]			= "Plains (39)",
["Plains (3)"]			= "Plains (40)",
["Island (1)"]			= "Island (41)",
["Island (2)"]			= "Island (42)",
["Island (3)"]			= "Island (43)",
["Mountain (1)"]		= "Mountain (74)",
["Mountain (2)"]		= "Mountain (75)",
["Mountain (3)"]		= "Mountain (76)",
["Mountain (4)"]		= "Mountain (77)",
},
[778] = { -- Magic: The Gathering Commander
["Plains (1)"]			= "Plains (299)",
["Plains (2)"]			= "Plains (300)",
["Plains (3)"]			= "Plains (301)",
["Plains (4)"]			= "Plains (302)",
["Island (1)"]			= "Island (303)",
["Island (2)"]			= "Island (304)",
["Island (3)"]			= "Island (305)",
["Island (4)"]			= "Island (306)",
["Swamp (1)"]			= "Swamp (307)",
["Swamp (2)"]			= "Swamp (308)",
["Swamp (3)"]			= "Swamp (309)",
["Swamp (4)"]			= "Swamp (310)",
["Mountain (1)"]		= "Mountain (311)",
["Mountain (2)"]		= "Mountain (312)",
["Mountain (3)"]		= "Mountain (313)",
["Mountain (4)"]		= "Mountain (314)",
["Forest (1)"]			= "Forest (315)",
["Forest (2)"]			= "Forest (316)",
["Forest (3)"]			= "Forest (317)",
["Forest (4)"]			= "Forest (318)",
["Nezumi Graverobber"]	= "Nezumi Graverobber|Nighteyes the Desecrator",
["Animar, Soul of Elements (1)"]	= "Animar, Soul of Elements",
["Animar, Soul of Elements (2)"]	= "Animar, Soul of Elements (oversized)",
["Damia, Sage of Stone (1)"]		= "Damia, Sage of Stone",
["Damia, Sage of Stone (2)"]		= "Damia, Sage of Stone (oversized)",
["Ghave, Guru of Spores (1)"]		= "Ghave, Guru of Spores",
["Ghave, Guru of Spores (2)"]		= "Ghave, Guru of Spores (oversized)",
["Intet, the Dreamer (1)"]			= "Intet, the Dreamer",
["Intet, the Dreamer (2)"]			= "Intet, the Dreamer (oversized)",
["Kaalia of the Vast (1)"]			= "Kaalia of the Vast",
["Kaalia of the Vast (2)"]			= "Kaalia of the Vast (oversized)",
["Karador, Ghost Chieftain (1)"]	= "Karador, Ghost Chieftain",
["Karador, Ghost Chieftain (2)"]	= "Karador, Ghost Chieftain (oversized)",
["Numot, the Devastator (1)"]		= "Numot, the Devastator",
["Numot, the Devastator (2)"]		= "Numot, the Devastator (oversized)",
["Oros, the Avenger (1)"]			= "Oros, the Avenger",
["Oros, the Avenger (2)"]			= "Oros, the Avenger (oversized)",
["Riku of Two Reflections (1)"]		= "Riku of Two Reflections",
["Riku of Two Reflections (2)"]		= "Riku of Two Reflections (oversized)",
["Ruhan of the Fomori (1)"]			= "Ruhan of the Fomori",
["Ruhan of the Fomori (2)"]			= "Ruhan of the Fomori (oversized)",
["Tariel, Reckoner of Souls (1)"]	= "Tariel, Reckoner of Souls",
["Tariel, Reckoner of Souls (2)"]	= "Tariel, Reckoner of Souls (oversized)",
["Teneb, the Harvester (1)"]		= "Teneb, the Harvester",
["Teneb, the Harvester (2)"]		= "Teneb, the Harvester (oversized)",
["The Mimeoplasm (1)"]				= "The Mimeoplasm",
["The Mimeoplasm (2)"]				= "The Mimeoplasm (oversized)",
["Vorosh, the Hunter (1)"]			= "Vorosh, the Hunter",
["Vorosh, the Hunter (2)"]			= "Vorosh, the Hunter (oversized)",
["Zedruu the Greathearted (1)"]		= "Zedruu the Greathearted",
["Zedruu the Greathearted (2)"]		= "Zedruu the Greathearted (oversized)",
},
[769] = { -- Archenemy
["Plains (1)"]			= "Plains (137)",
["Plains (2)"]			= "Plains (138)",
["Island (1)"]			= "Island (139)",
["Island (2)"]			= "Island (140)",
["Island (3)"]			= "Island (141)",
["Swamp (1)"]			= "Swamp (142)",
["Swamp (2)"]			= "Swamp (143)",
["Swamp (3)"]			= "Swamp (144)",
["Mountain (1)"]		= "Mountain (145)",
["Mountain (2)"]		= "Mountain (146)",
["Mountain (3)"]		= "Mountain (147)",
["Forest (1)"]			= "Forest (148)",
["Forest (2)"]			= "Forest (149)",
["Forest (3)"]			= "Forest (150)",
["Your Will is Not Your Own"]	= "Your Will Is Not Your Own",
["Mortal Flesh is Weak"]		= "Mortal Flesh Is Weak",
},
[768] = { -- Duels of the Planeswalkers
["Island (1)"]			= "Island (98)",
["Island (2)"]			= "Island (99)",
["Island (3)"]			= "Island (100)",
["Island (4)"]			= "Island (101)",
["Swamp (1)"]			= "Swamp (102)",
["Swamp (2)"]			= "Swamp (103)",
["Swamp (3)"]			= "Swamp (104)",
["Swamp (4)"]			= "Swamp (105)",
["Mountain (1)"]		= "Mountain (106)",
["Mountain (2)"]		= "Mountain (107)",
["Mountain (3)"]		= "Mountain (108)",
["Mountain (4)"]		= "Mountain (109)",
["Forest (1)"]			= "Forest (110)",
["Forest (2)"]			= "Forest (111)",
["Forest (3)"]			= "Forest (112)",
["Forest (4)"]			= "Forest (113)",
},
[766] = { -- DD: Phyrexia vs Coalition
["Urza's Rage"]					= "Urza’s Rage",
},
[761] = { -- Planechase
["The Aether Flues"]				= "The Æther Flues",
},
[675] = { -- Coldsnap Theme Decks
["Plains (48)"]			= "Plains (369)",
["Plains (49)"]			= "Plains (370)",
["Plains (50)"]			= "Plains (371)",
["Island (51)"]			= "Island (372)",
["Island (52)"]			= "Island (373)",
["Island (53)"]			= "Island (374)",
["Swamp (54)"]			= "Swamp (375)",
["Swamp (55)"]			= "Swamp (376)",
["Swamp (56)"]			= "Swamp (377)",
["Mountain (57)"]		= "Mountain (378)",
["Mountain (58)"]		= "Mountain (379)",
["Mountain (59)"]		= "Mountain (380)",
["Forest (60)"]			= "Forest (381)",
["Forest (61)"]			= "Forest (382)",
["Forest (62)"]			= "Forest (383)",
},
[636] = { -- Salvat 2011
--["Plains (1)"]			= "Plains (205)",
--["Plains (2)"]			= "Plains (206)",
--["Plains (3)"]			= "Plains (207)",
--["Plains (4)"]			= "Plains (208)",
["Island (1)"]			= "Island (209)",
["Island (2)"]			= "Island (210)",
["Island (3)"]			= "Island (211)",
["Island (4)"]			= "Island (212)",
["Swamp (1)"]			= "Swamp (213)",
["Swamp (2)"]			= "Swamp (214)",
["Swamp (3)"]			= "Swamp (215)",
["Swamp (4)"]			= "Swamp (216)",
["Mountain (1)"]		= "Mountain (217)",
["Mountain (2)"]		= "Mountain (218)",
["Mountain (3)"]		= "Mountain (219)",
["Mountain (4)"]		= "Mountain (220)",
["Forest (1)"]			= "Forest (221)",
["Forest (2)"]			= "Forest (222)",
["Forest (3)"]			= "Forest (223)",
["Forest (4)"]			= "Forest (224)",
["Eyeblight's Ending"]	= "Fin de la desgracia visual",
["Hurricane"]			= "Huracán",
},
[635] = { -- Salvat Magic Encyclopedia
-- 1Plains=Cats,Swamp=Rats,Mountain=Beasts,Forest=Cats
-- 2 Elves
-- 3 Spirits
-- 4 Slivers
-- 5 Ninjas
-- 6 Zombies
-- 7 Angels
-- 8 Wizards
-- 9 Berserkers
-- 10 Thallids
["Plains (03-08)"]	= "Plains (Spirits 8)",
["Plains (03-09)"]	= "Plains (Spirits 9)",
["Plains (03-10)"]	= "Plains (Spirits 10)",
["Plains (03-20)"]	= "Plains (Spirits 20)",
["Plains (03-21)"]	= "Plains (Spirits 21)",
["Plains (03-33)"]	= "Plains (Spirits 33)",
["Plains (03-34)"]	= "Plains (Spirits 34)",
["Plains (03-44)"]	= "Plains (Spirits 44)",
["Plains (03-45)"]	= "Plains (Spirits 45)",
["Plains (03-46)"]	= "Plains (Spirits 46)",
["Plains (03-56)"]	= "Plains (Spirits 56)",
["Plains (03-57)"]	= "Plains (Spirits 57)",
["Plains (07-08)"]	= "Plains (Angels 8)",
["Plains (07-09)"]	= "Plains (Angels 9)",
["Plains (07-10)"]	= "Plains (Angels 10)",
["Plains (07-20)"]	= "Plains (Angels 20)",
["Plains (07-21)"]	= "Plains (Angels 21)",
["Plains (07-22)"]	= "Plains (Angels 22)",
["Plains (07-23)"]	= "Plains (Angels 23)",
["Plains (07-32)"]	= "Plains (Angels 32)",
["Plains (07-33)"]	= "Plains (Angels 33)",
["Plains (07-34)"]	= "Plains (Angels 34)",
["Plains (07-45)"]	= "Plains (Angels 45)",
["Plains (07-46)"]	= "Plains (Angels 46)",
["Plains (07-56)"]	= "Plains (Angels 56)",
["Plains (07-57)"]	= "Plains (Angels 57)",
["Plains (07-58)"]	= "Plains (Angels 58)",
["Plains (10-11)"]	= "Plains (Thallids 11)",
["Plains (10-12)"]	= "Plains (Thallids 12)",
["Plains (10-23)"]	= "Plains (Thallids 23)",
["Plains (10-24)"]	= "Plains (Thallids 24)",
["Plains (10-35)"]	= "Plains (Thallids 35)",
["Plains (10-36)"]	= "Plains (Thallids 36)",
["Plains (10-47)"]	= "Plains (Thallids 47)",
["Plains (10-48)"]	= "Plains (Thallids 48)",
["Plains (10-59)"]	= "Plains (Thallids 59)",
["Plains (10-60)"]	= "Plains (Thallids 60)",
["Plains (47)"]		= "Plains (Cats 47)",
["Plains (58)"]		= "Plains (Cats 58)",
["Plains (59)"]		= "Plains (Cats 59)",
--missing 9 Plains : Cats 9,10,11,21,22,23,35,46,57
--retval "40"; expected was 49
["Island (05-08)"]	= "Island (Ninjas 8)",
["Island (05-09)"]	= "Island (Ninjas 9)",
["Island (05-10)"]	= "Island (Ninjas 10)",
["Island (05-20)"]	= "Island (Ninjas 20)",
["Island (05-21)"]	= "Island (Ninjas 21)",
["Island (05-32)"]	= "Island (Ninjas 32)",
["Island (05-33)"]	= "Island (Ninjas 33)",
["Island (05-34)"]	= "Island (Ninjas 34)",
["Island (05-45)"]	= "Island (Ninjas 45)",
["Island (05-46)"]	= "Island (Ninjas 46)",
["Island (05-56)"]	= "Island (Ninjas 56)",
["Island (05-57)"]	= "Island (Ninjas 57)",
["Island (05-58)"]	= "Island (Ninjas 58)",
["Island (07-11)"]	= "Island (Angels 11)",
["Island (07-12)"]	= "Island (Angels 12)",
["Island (07-24)"]	= "Island (Angels 24)",
["Island (07-35)"]	= "Island (Angels 35)",
["Island (07-36)"]	= "Island (Angels 36)",
["Island (07-47)"]	= "Island (Angels 47)",
["Island (07-48)"]	= "Island (Angels 48)",
["Island (07-59)"]	= "Island (Angels 59)",
["Island (07-60)"]	= "Island (Angels 60)",
["Island (08-08)"]	= "Island (Wizards 8)",
["Island (08-09)"]	= "Island (Wizards 9)",
["Island (08-10)"]	= "Island (Wizards 10)",
["Island (08-11)"]	= "Island (Wizards 11)",
["Island (08-12)"]	= "Island (Wizards 12)",
["Island (08-20)"]	= "Island (Wizards 20)",
["Island (08-21)"]	= "Island (Wizards 21)",
["Island (08-22)"]	= "Island (Wizards 22)",
["Island (08-23)"]	= "Island (Wizards 23)",
["Island (08-24)"]	= "Island (Wizards 24)",
["Island (08-32)"]	= "Island (Wizards 32)",
["Island (08-33)"]	= "Island (Wizards 33)",
["Island (08-34)"]	= "Island (Wizards 34)",
["Island (08-35)"]	= "Island (Wizards 35)",
["Island (08-36)"]	= "Island (Wizards 36)",
["Island (08-45)"]	= "Island (Wizards 45)",
["Island (08-46)"]	= "Island (Wizards 46)",
["Island (08-47)"]	= "Island (Wizards 47)",
["Island (08-48)"]	= "Island (Wizards 48)",
["Island (08-56)"]	= "Island (Wizards 56)",
["Island (08-57)"]	= "Island (Wizards 57)",
["Island (08-58)"]	= "Island (Wizards 58)",
["Island (08-59)"]	= "Island (Wizards 59)",
["Island (08-60)"]	= "Island (Wizards 60)",
-- missing 0 Islands
["Swamp (04-33)"]	= "Swamp (Slivers 33)",
["Swamp (04-34)"]	= "Swamp (Slivers 34)",
["Swamp (04-35)"]	= "Swamp (Slivers 35)",
["Swamp (04-36)"]	= "Swamp (Slivers 36)",
["Swamp (04-45)"]	= "Swamp (Slivers 45)",
["Swamp (04-46)"]	= "Swamp (Slivers 46)",
["Swamp (04-56)"]	= "Swamp (Slivers 56)",
["Swamp (05-11)"]	= "Swamp (Ninjas 11)",
["Swamp (05-12)"]	= "Swamp (Ninjas 12)",
["Swamp (05-22)"]	= "Swamp (Ninjas 22)",
["Swamp (05-23)"]	= "Swamp (Ninjas 23)",
["Swamp (05-24)"]	= "Swamp (Ninjas 24)",
["Swamp (05-35)"]	= "Swamp (Ninjas 35)",
["Swamp (05-36)"]	= "Swamp (Ninjas 36)",
["Swamp (05-47)"]	= "Swamp (Ninjas 47)",
["Swamp (05-48)"]	= "Swamp (Ninjas 48)",
["Swamp (05-59)"]	= "Swamp (Ninjas 59)",
["Swamp (05-60)"]	= "Swamp (Ninjas 60)",
["Swamp (06-08)"]	= "Swamp (Zombies 8)",
["Swamp (06-09)"]	= "Swamp (Zombies 9)",
["Swamp (06-10)"]	= "Swamp (Zombies 10)",
["Swamp (06-11)"]	= "Swamp (Zombies 11)",
["Swamp (06-12)"]	= "Swamp (Zombies 12)",
["Swamp (06-20)"]	= "Swamp (Zombies 20)",
["Swamp (06-21)"]	= "Swamp (Zombies 21)",
["Swamp (06-22)"]	= "Swamp (Zombies 22)",
["Swamp (06-23)"]	= "Swamp (Zombies 23)",
["Swamp (06-24)"]	= "Swamp (Zombies 24)",
["Swamp (06-32)"]	= "Swamp (Zombies 32)",
["Swamp (06-33)"]	= "Swamp (Zombies 33)",
["Swamp (06-34)"]	= "Swamp (Zombies 34)",
["Swamp (06-35)"]	= "Swamp (Zombies 35)",
["Swamp (06-36)"]	= "Swamp (Zombies 36)",
["Swamp (06-45)"]	= "Swamp (Zombies 45)",
["Swamp (06-46)"]	= "Swamp (Zombies 46)",
["Swamp (06-47)"]	= "Swamp (Zombies 47)",
["Swamp (06-48)"]	= "Swamp (Zombies 48)",
["Swamp (06-56)"]	= "Swamp (Zombies 56)",
["Swamp (06-57)"]	= "Swamp (Zombies 57)",
["Swamp (06-58)"]	= "Swamp (Zombies 58)",
["Swamp (06-59)"]	= "Swamp (Zombies 59)",
["Swamp (06-60)"]	= "Swamp (Zombies 60)",
["Swamp (8)"]		= "Swamp (Rats 8)",
["Swamp (9)"]		= "Swamp (Rats 9)",
["Swamp (10)"]		= "Swamp (Rats 10)",
["Swamp (11)"]		= "Swamp (Rats 11)",
["Swamp (12)"]		= "Swamp (Rats 12)",
["Swamp (20)"]		= "Swamp (Rats 20)",
["Swamp (21)"]		= "Swamp (Rats 21)",
["Swamp (22)"]		= "Swamp (Rats 22)",
["Swamp (23)"]		= "Swamp (Rats 23)",
["Swamp (24)"]		= "Swamp (Rats 24)",
["Swamp (32)"]		= "Swamp (Rats 32)",
["Swamp (33)"]		= "Swamp (Rats 33)",
["Swamp (34)"]		= "Swamp (Rats 34)",
["Swamp (35)"]		= "Swamp (Rats 35)",
["Swamp (36)"]		= "Swamp (Rats 36)",
["Swamp (45)"]		= "Swamp (Rats 45)",
["Swamp (46)"]		= "Swamp (Rats 46)",
["Swamp (47)"]		= "Swamp (Rats 47)",
["Swamp (48)"]		= "Swamp (Rats 48)",
["Swamp (56)"]		= "Swamp (Rats 56)",
["Swamp (57)"]		= "Swamp (Rats 57)",
["Swamp (58)"]		= "Swamp (Rats 58)",
["Swamp (59)"]		= "Swamp (Rats 59)",
["Swamp (60)"]		= "Swamp (Rats 60)",
-- missing 0 Swamps
["Mountain (03-11)"]	= "Mountain (Spirits 11)",
["Mountain (03-12)"]	= "Mountain (Spirits 12)",
["Mountain (03-22)"]	= "Mountain (Spirits 22)",
["Mountain (03-23)"]	= "Mountain (Spirits 23)",
["Mountain (03-24)"]	= "Mountain (Spirits 24)",
["Mountain (03-35)"]	= "Mountain (Spirits 35)",
["Mountain (03-36)"]	= "Mountain (Spirits 36)",
["Mountain (03-47)"]	= "Mountain (Spirits 47)",
["Mountain (03-48)"]	= "Mountain (Spirits 48)",
["Mountain (03-58)"]	= "Mountain (Spirits 58)",
["Mountain (03-59)"]	= "Mountain (Spirits 59)",
["Mountain (03-60)"]	= "Mountain (Spirits 60)",
["Mountain (04-09)"]	= "Mountain (Slivers 9)",
["Mountain (04-10)"]	= "Mountain (Slivers 10)",
["Mountain (04-21)"]	= "Mountain (Slivers 21)",
["Mountain (04-22)"]	= "Mountain (Slivers 22)",
["Mountain (04-47)"]	= "Mountain (Slivers 47)",
["Mountain (04-57)"]	= "Mountain (Slivers 57)",
["Mountain (04-58)"]	= "Mountain (Slivers 58)",
["Mountain (09-09)"]	= "Mountain (Berserkers 9)",
["Mountain (09-10)"]	= "Mountain (Berserkers 10)",
["Mountain (09-11)"]	= "Mountain (Berserkers 11)",
["Mountain (09-12)"]	= "Mountain (Berserkers 12)",
["Mountain (09-20)"]	= "Mountain (Berserkers 20)",
["Mountain (09-21)"]	= "Mountain (Berserkers 21)",
["Mountain (09-22)"]	= "Mountain (Berserkers 22)",
["Mountain (09-23)"]	= "Mountain (Berserkers 23)",
["Mountain (09-24)"]	= "Mountain (Berserkers 24)",
["Mountain (09-32)"]	= "Mountain (Berserkers 32)",
["Mountain (09-44)"]	= "Mountain (Berserkers 44)",
["Mountain (09-45)"]	= "Mountain (Berserkers 45)",
["Mountain (09-57)"]	= "Mountain (Berserkers 57)",
["Mountain (36)"]		= "Mountain (Beasts 36)",
["Mountain (48)"]		= "Mountain (Beasts 48)",
["Mountain (59)"]		= "Mountain (Beasts 59)",
["Mountain (60)"]		= "Mountain (Beasts 60)",
-- Missing 4 Mountains: Beasts 11,12,24,35
--retval "36"; expected was 40
["Forest (02-08)"]	= "Forest (Elves 8)",
["Forest (02-09)"]	= "Forest (Elves 9)",
["Forest (02-10)"]	= "Forest (Elves 10)",
["Forest (02-11)"]	= "Forest (Elves 11)",
["Forest (02-12)"]	= "Forest (Elves 12)",
["Forest (02-20)"]	= "Forest (Elves 20)",
["Forest (02-21)"]	= "Forest (Elves 21)",
["Forest (02-22)"]	= "Forest (Elves 22)",
["Forest (02-23)"]	= "Forest (Elves 23)",
["Forest (02-24)"]	= "Forest (Elves 24)",
["Forest (02-33)"]	= "Forest (Elves 33)",
["Forest (02-34)"]	= "Forest (Elves 34)",
["Forest (02-35)"]	= "Forest (Elves 35)",
["Forest (02-36)"]	= "Forest (Elves 36)",
["Forest (02-45)"]	= "Forest (Elves 45)",
["Forest (02-46)"]	= "Forest (Elves 46)",
["Forest (02-47)"]	= "Forest (Elves 47)",
["Forest (02-48)"]	= "Forest (Elves 48)",
["Forest (02-56)"]	= "Forest (Elves 56)",
["Forest (02-57)"]	= "Forest (Elves 57)",
["Forest (02-58)"]	= "Forest (Elves 58)",
["Forest (02-59)"]	= "Forest (Elves 59)",
["Forest (02-60)"]	= "Forest (Elves 60)",
["Forest (04-11)"]	= "Forest (Slivers 11)",
["Forest (04-12)"]	= "Forest (Slivers 12)",
["Forest (04-23)"]	= "Forest (Slivers 23)",
["Forest (04-24)"]	= "Forest (Slivers 24)",
["Forest (04-48)"]	= "Forest (Slivers 48)",
["Forest (04-59)"]	= "Forest (Slivers 59)",
["Forest (04-60)"]	= "Forest (Slivers 60)",
["Forest (09-33)"]	= "Forest (Berserkers 33)",
["Forest (09-34)"]	= "Forest (Berserkers 34)",
["Forest (09-35)"]	= "Forest (Berserkers 35)",
["Forest (09-36)"]	= "Forest (Berserkers 36)",
["Forest (09-46)"]	= "Forest (Berserkers 46)",
["Forest (09-47)"]	= "Forest (Berserkers 47)",
["Forest (09-48)"]	= "Forest (Berserkers 48)",
["Forest (09-58)"]	= "Forest (Berserkers 58)",
["Forest (09-59)"]	= "Forest (Berserkers 59)",
["Forest (09-60)"]	= "Forest (Berserkers 60)",
["Forest (10-08)"]	= "Forest (Thallids 8)",
["Forest (10-09)"]	= "Forest (Thallids 9)",
["Forest (10-10)"]	= "Forest (Thallids 10)",
["Forest (10-20)"]	= "Forest (Thallids 20)",
["Forest (10-21)"]	= "Forest (Thallids 21)",
["Forest (10-22)"]	= "Forest (Thallids 22)",
["Forest (10-33)"]	= "Forest (Thallids 33)",
["Forest (10-34)"]	= "Forest (Thallids 34)",
["Forest (10-44)"]	= "Forest (Thallids 44)",
["Forest (10-45)"]	= "Forest (Thallids 45)",
["Forest (10-46)"]	= "Forest (Thallids 46)",
["Forest (10-56)"]	= "Forest (Thallids 56)",
["Forest (10-57)"]	= "Forest (Thallids 57)",
["Forest (10-58)"]	= "Forest (Thallids 58)",
["Forest (24)"]		= "Forest (Cats 24)",
["Forest (48)"]		= "Forest (Cats 48)",
["Forest (60)"]		= "Forest (Cats 60)",
--missing 2+16 Forests : Cats 12,36, Beasts 8,9,10,20,21,22,23,32,33,34,45,46,47,56,57,58
--retval "57"; expected was 75
["Angel of Mercy (14)"]						= "Angel of Mercy (Angels 14)",
["Angel of Mercy (38)"]						= "Angel of Mercy (Angels 38)",
["Aphetto Dredging (40)"]					= "Aphetto Dredging (Slivers 40)",
["Aphetto Dredging (41)"]					= "Aphetto Dredging (Slivers 41)",
["Arctic Nishoba (14)"]						= "Arctic Nishoba (Cats 14)",
["Arctic Nishoba (686)"]					= "Arctic Nishoba (Cats 26)",
["Ardent Militia (15)"]						= "Ardent Militia (Angels 15)",
["Ardent Militia (26)"]						= "Ardent Militia (Angels 26)",
["Auratouched Mage (27)"]					= "Auratouched Mage (Angels 27)",
["Auratouched Mage (50)"]					= "Auratouched Mage (Angels 50)",
["Aven Windreader (52)"]					= "Aven Windreader (Wizards 52)",
["Aven Windreader (53)"]					= "Aven Windreader (Wizards 53)",
["Balduvian Rage (14)"]						= "Balduvian Rage (Berserkers 14)",
["Balduvian Rage (15)"]						= "Balduvian Rage (Berserkers 15)",
["Belltower Sphinx (14)"]					= "Belltower Sphinx (Wizards 14)",
["Belltower Sphinx (26)"]					= "Belltower Sphinx (Wizards 26)",
["Birchlore Rangers (52)"]					= "Birchlore Rangers (Elves 52)",
["Birchlore Rangers (53)"]					= "Birchlore Rangers (Elves 53)",
["Blade Sliver (2)"]						= "Blade Sliver (Slivers 2)",
["Blade Sliver (3)"]						= "Blade Sliver (Slivers 3)",
["Blade Sliver (38)"]						= "Blade Sliver (Slivers 38)",
["Blade Sliver (52)"]						= "Blade Sliver (Slivers 52)",
["Blademane Baku (4)"]						= "Blademane Baku (Spirits 4)",
["Blademane Baku (30)"]						= "Blademane Baku (Spirits 30)",
["Blademane Baku (53)"]						= "Blademane Baku (Spirits 53)",
["Blind Creeper (4)"]						= "Blind Creeper (Zombies 4)",
["Blind Creeper (29)"]						= "Blind Creeper (Zombies 29)",
["Bonesplitter (5)"]						= "Bonesplitter (Cats 5)",
["Bonesplitter (700)"]						= "Bonesplitter (Cats 40)",
["Boomerang (16)"]							= "Boomerang (Wizards 16)",
["Boomerang (29)"]							= "Boomerang (Wizards 29)",
["Carrion Rats (40)"]						= "Carrion Rats (Rats 40)",
["Carrion Rats (41)"]						= "Carrion Rats (Rats 41)",
["Carrion Rats (53)"]						= "Carrion Rats (Rats 53)",
["Chittering Rats (5)"]						= "Chittering Rats (Rats 5)",
["Chittering Rats (19)"]					= "Chittering Rats (Rats 19)",
["Chittering Rats (54)"]					= "Chittering Rats (Rats 54)",
["Clutch of the Undercity (14)"]			= "Clutch of the Undercity (Ninjas 14)",
["Clutch of the Undercity (38)"]			= "Clutch of the Undercity (Ninjas 38)",
["Crippling Fatigue (6)"]					= "Crippling Fatigue (Rats 6)",
["Crippling Fatigue (30)"]					= "Crippling Fatigue (Rats 30)",
["Crown of Vigor (6)"]						= "Crown of Vigor (Slivers 6)",
["Crown of Vigor (54)"]						= "Crown of Vigor (Elves 54)",
["Crypt Sliver (29)"]						= "Crypt Sliver (Slivers 29)",
["Crypt Sliver (30)"]						= "Crypt Sliver (Slivers 30)",
["Crypt Sliver (50)"]						= "Crypt Sliver (Slivers 50)",
["Darigaaz's Charm (39)"]					= "Darigaaz’s Charm (Slivers 39)",
["Darigaaz's Charm (51)"]					= "Darigaaz’s Charm (Slivers 51)",
["Dark Banishing (30)"]						= "Dark Banishing (Zombies 30)",
["Dark Banishing (31)"]						= "Dark Banishing (Slivers 31)",
["Dark Banishing (32)"]						= "Dark Banishing (Slivers 32)",
["Dark Banishing (41)"]						= "Dark Banishing (Zombies 41)",
["Dark Banishing (53)"]						= "Dark Banishing (Zombies 53)",
["Death Denied (42)"]						= "Death Denied (Zombies 42)",
["Death Denied (54)"]						= "Death Denied (Zombies 54)",
["Dehydration (41)"]						= "Dehydration (Wizards 41)",
["Dehydration (42)"]						= "Dehydration (Wizards 42)",
["Dimir Infiltrator (4)"]					= "Dimir Infiltrator (Ninjas 4)",
["Dimir Infiltrator (5)"]					= "Dimir Infiltrator (Ninjas 5)",
["Dirty Wererat (7)"]						= "Dirty Wererat (Rats 7)",
["Dirty Wererat (31)"]						= "Dirty Wererat (Rats 31)",
["Darigaaz's Caldera"]						= "Darigaaz’s Caldera",
["Elvish Warrior (41)"]						= "Elvish Warrior (Elves 41)",
["Elvish Warrior (42)"]						= "Elvish Warrior (Elves 42)",
["Enormous Baloth (2)"]						= "Enormous Baloth (Beasts 2)",
["Enormous Baloth (650)"]					= "Enormous Baloth (Beasts 50)",
["Fangren Pathcutter (614)"]				= "Fangren Pathcutter (Beasts 14)",
["Fangren Pathcutter (615)"]				= "Fangren Pathcutter (Beasts 15)",
["Feral Lightning (2)"]						= "Feral Lightning (Berserkers 2)",
["Feral Lightning (50)"]					= "Feral Lightning (Berserkers 50)",
["Fertile Ground"]							= "Fertile Ground (Beasts 5)",
--["Fertile Ground (5)"]						= "Fertile Ground (Beasts 5)",
--["Fertile Ground (6)"]						= "Fertile Ground (Beasts 6)",
["Fertile Imagination (2)"]					= "Fertile Imagination (Thallids 2)",
["Fertile Imagination (38)"]				= "Fertile Imagination (Thallids 38)",
["Festering Goblin (5)"]					= "Festering Goblin (Zombies 5)",
["Festering Goblin (6)"]					= "Festering Goblin (Zombies 6)",
["Festering Goblin (17)"]					= "Festering Goblin (Zombies 17)",
["Flowstone Shambler (7)"]					= "Flowstone Shambler (Beasts 7)",
["Flowstone Shambler (653)"]				= "Flowstone Shambler (Beasts 53)",
["Freewind Equenaut (4)"]					= "Freewind Equenaut (Angels 4)",
["Freewind Equenaut (17)"]					= "Freewind Equenaut (Angels 17)",
["Freewind Equenaut (41)"]					= "Freewind Equenaut (Angels 41)",
["Frostling (6)"]							= "Frostling (Spirits 6)",
["Frostling (16)"]							= "Frostling (Spirits 16)",
["Ghor-Clan Savage (29)"]					= "Ghor-Clan Savage (Berserkers 29)",
["Ghor-Clan Savage (55)"]					= "Ghor-Clan Savage (Berserkers 55)",
["Goblin Chariot (4)"]						= "Goblin Chariot (Berserkers 4)",
["Goblin Chariot (17)"]						= "Goblin Chariot (Berserkers 17)",
["Goblin Chariot (18)"]						= "Goblin Chariot (Berserkers 18)",
["Golgari Guildmage (39)"]					= "Golgari Guildmage (Zombies 39)",
["Golgari Guildmage (50)"]					= "Golgari Guildmage (Elves 50)",
["Gravedigger (7)"]							= "Gravedigger (Zombies 7)",
["Gravedigger (43)"]						= "Gravedigger (Zombies 43)",
["Gravedigger (55)"]						= "Gravedigger (Zombies 55)",
["Grifter's Blade (27)"]					= "Grifter’s Blade (Cats 27)",
["Grifter's Blade (710)"]					= "Grifter’s Blade (Cats 50)",
["Groffskithur (30)"]						= "Groffskithur (Beasts 30)",
["Groffskithur (641)"]						= "Groffskithur (Beasts 41)",
["Groffskithur (642)"]						= "Groffskithur (Beasts 42)",
["Groffskithur (655)"]						= "Groffskithur (Beasts 55)",
["Gruul Scrapper (42)"]						= "Gruul Scrapper (Berserkers 42)",
["Gruul Scrapper (43)"]						= "Gruul Scrapper (Berserkers 43)",
["Guardian's Magemark (5)"]					= "Guardian’s Magemark (Angels 5)",
["Guardian's Magemark (52)"]				= "Guardian’s Magemark (Angels 52)",
["Hunter Sliver (7)"]						= "Hunter Sliver (Slivers 7)",
["Hunter Sliver (8)"]						= "Hunter Sliver (Slivers 8)",
["Hunter Sliver (53)"]						= "Hunter Sliver (Slivers 53)",
["Indrik Stomphowler (38)"]					= "Indrik Stomphowler (Berserkers 38)",
["Indrik Stomphowler (638)"]				= "Indrik Stomphowler (Beasts 38)",
["Indrik Stomphowler (651)"]				= "Indrik Stomphowler (Beasts 51)",
["Infiltrator's Magemark (7)"]				= "Infiltrator’s Magemark (Angels 7)",
["Infiltrator's Magemark (19)"]				= "Infiltrator’s Magemark (Angels 19)",
["Iron-Barb Hellion (603)"]					= "Iron-Barb Hellion (Beasts 3)",
["Iron-Barb Hellion (604)"]					= "Iron-Barb Hellion (Beasts 4)",
["Jedit's Dragoons"]						= "Jedit’s Dragoons",
["Kami of the Palace Fields (27)"]			= "Kami of the Palace Fields (Spirits 27)",
["Kami of the Palace Fields (50)"]			= "Kami of the Palace Fields (Spirits 50)",
["Kirtar's Wrath"]							= "Kirtar’s Wrath",
["Kitsune Mystic"]							= "Kitsune Mystic|Autumn-Tail, Kitsune Sage",
["Kodama's Reach"]							= "Kodama’s Reach",
["Leonin Den-Guard (17)"]					= "Leonin Den-Guard (Cats 17)",
["Leonin Den-Guard (689)"]					= "Leonin Den-Guard (Cats 29)",
["Leonin Den-Guard (690)"]					= "Leonin Den-Guard (Cats 30)",
["Llanowar Elite (16)"]						= "Llanowar Elite (Elves 16)",
["Llanowar Elite (17)"]						= "Llanowar Elite (Elves 17)",
["Lure (16)"]								= "Lure (Beasts 16)",
["Lure (639)"]								= "Lure (Beasts 39)",
["Martyr of Frost (5)"]						= "Martyr of Frost (Wizards 5)",
["Martyr of Frost (17)"]					= "Martyr of Frost (Wizards 17)",
["Merfolk of the Pearl Trident (42)"]		= "Merfolk of the Pearl Trident (Ninjas 42)",
["Merfolk of the Pearl Trident (43)"]		= "Merfolk of the Pearl Trident (Ninjas 43)",
["Nantuko Husk (3)"]						= "Nantuko Husk (Zombies 3)",
["Nantuko Husk (15)"]						= "Nantuko Husk (Zombies 15)",
["Nantuko Husk (27)"]						= "Nantuko Husk (Zombies 27)",
["Nezumi Cutthroat (17)"]					= "Nezumi Cutthroat (Rats 17)",
["Nezumi Cutthroat (29)"]					= "Nezumi Cutthroat (Rats 29)",
["Nezumi Graverobber (38)"]					= "Nezumi Graverobber|Nighteyes the Desecrator (Rats 38)",
["Nezumi Graverobber (39)"]					= "Nezumi Graverobber|Nighteyes the Desecrator (Rats 39)",
["Nightguard Patrol (18)"]					= "Nightguard Patrol (Angels 18)",
["Nightguard Patrol (29)"]					= "Nightguard Patrol (Angels 29)",
["Ninja of the Deep Hours (6)"]				= "Ninja of the Deep Hours (Ninjas 6)",
["Ninja of the Deep Hours (30)"]			= "Ninja of the Deep Hours (Ninjas 30)",
["Ninja of the Deep Hours (41)"]			= "Ninja of the Deep Hours (Ninjas 41)",
["Nullmage Shepherd (2)"]					= "Nullmage Shepherd (Elves 2)",
["Nullmage Shepherd (40)"]					= "Nullmage Shepherd (Elves 40)",
["Okiba-Gang Shinobi (53)"]					= "Okiba-Gang Shinobi (Ninjas 53)",
["Okiba-Gang Shinobi (54)"]					= "Okiba-Gang Shinobi (Ninjas 54)",
["Pacifism (42)"]							= "Pacifism (Angels 42)",
["Pacifism (53)"]							= "Pacifism (Angels 53)",
["Pain Kami (28)"]							= "Pain Kami (Spirits 28)",
["Pain Kami (29)"]							= "Pain Kami (Spirits 29)",
["Phantom Flock (3)"]						= "Phantom Flock (Spirits 3)",
["Phantom Flock (39)"]						= "Phantom Flock (Spirits 39)",
["Phantom Nomad (7)"]						= "Phantom Nomad (Spirits 7)",
["Phantom Nomad (17)"]						= "Phantom Nomad (Spirits 17)",
["Plagued Rusalka (28)"]					= "Plagued Rusalka (Zombies 28)",
["Plagued Rusalka (40)"]					= "Plagued Rusalka (Zombies 40)",
["Plumes of Peace (31)"]					= "Plumes of Peace (Angels 31)",
["Plumes of Peace (55)"]					= "Plumes of Peace (Angels 55)",
["Predator's Strike"]						= "Predator’s Strike",
["Primal Forcemage (39)"]					= "Primal Forcemage (Berserkers 39)",
["Primal Forcemage (40)"]					= "Primal Forcemage (Berserkers 40)",
["Primal Forcemage (52)"]					= "Primal Forcemage (Berserkers 52)",
["Puppeteer (2)"]							= "Puppeteer (Wizards 2)",
["Puppeteer (39)"]							= "Puppeteer (Wizards 39)",
["Pyroclasm"]								= "Pyroclasm",
["Quick Sliver (16)"]						= "Quick Sliver (Slivers 16)",
["Quick Sliver (17)"]						= "Quick Sliver (Slivers 17)",
["Quick Sliver (42)"]						= "Quick Sliver (Slivers 42)",
["Raging Goblin (6)"]						= "Raging Goblin (Berserkers 6)",
["Raging Goblin (7)"]						= "Raging Goblin (Berserkers 7)",
["Raging Goblin (41)"]						= "Raging Goblin (Berserkers 41)",
["Rampant Growth (19)"]						= "Rampant Growth (Beasts 19)",
["Rampant Growth (628)"]					= "Rampant Growth (Beasts 28)",
["Rats' Feast (44)"]						= "Rats’ Feast (Rats 44)",
["Rats' Feast (55)"]						= "Rats’ Feast (Rats 55)",
["Root Sliver (14)"]						= "Root Sliver (Slivers 14)",
["Root Sliver (15)"]						= "Root Sliver (Slivers 15)",
["Sage Owl (7)"]							= "Sage Owl (Ninjas 7)",
["Sage Owl (31)"]							= "Sage Owl (Ninjas 31)",
["Saltblast (28)"]							= "Saltblast (Cats 28)",
["Saltblast (713)"]							= "Saltblast (Cats 53)",
["Sandsower (26)"]							= "Sandsower (Thallids 26)",
["Sandsower (51)"]							= "Sandsower (Spirits 51)",
["Savage Thallid (4)"]						= "Savage Thallid (Thallids 4)",
["Savage Thallid (5)"]						= "Savage Thallid (Thallids 5)",
["Scab-Clan Mauler (31)"]					= "Scab-Clan Mauler (Berserkers 31)",
["Scab-Clan Mauler (56)"]					= "Scab-Clan Mauler (Berserkers 56)",
["Seeker of Skybreak (29)"]					= "Seeker of Skybreak (Elves 29)",
["Seeker of Skybreak (30)"]					= "Seeker of Skybreak (Elves 30)",
["Selesnya Evangel (54)"]					= "Selesnya Evangel (Thallids 54)",
["Selesnya Evangel (55)"]					= "Selesnya Evangel (Thallids 55)",
["Selesnya Guildmage (Elves 51)"]			= "Selesnya Guildmage (Elves 51)",
["Selesnya Guildmage (Thallids 51)"]		= "Selesnya Guildmage (Thallids 51)",
["Selesnya Sanctuary (33)"]					= "Selesnya Sanctuary (Cats 33)",
["Selesnya Sanctuary (704)"]				= "Selesnya Sanctuary (Cats 44)",
["Selesnya Signet (41)"]					= "Selesnya Signet (Cats 41)",
["Selesnya Signet (715)"]					= "Selesnya Signet (Cats 55)",
["Selesnya Signet (716)"]					= "Selesnya Signet (Cats 56)",
["Seht's Tiger"]							= "Seht’s Tiger",
["Sever Soul (15)"]							= "Sever Soul (Rats 15)",
["Sever Soul (16)"]							= "Sever Soul (Rats 16)",
["Shinen of Fury's Fire (42)"]				= "Shinen of Fury’s Fire (Spirits 42)",
["Shinen of Fury's Fire (54)"]				= "Shinen of Fury’s Fire (Spirits 54)",
["Shinen of Fury's Fire (55)"]				= "Shinen of Fury’s Fire (Spirits 55)",
["Shock (53)"]								= "Shock (Berserkers 53)",
["Shock (54)"]								= "Shock (Berserkers 54)",
["Sinstriker's Will"]						= "Sinstriker’s Will",
["Skullsnatcher (4)"]						= "Skullsnatcher (Rats 4)",
["Skullsnatcher (17)"]						= "Skullsnatcher (Ninjas 17)",
["Skullsnatcher (18)"]						= "Skullsnatcher (Ninjas 18)",
["Skullsnatcher (19)"]						= "Skullsnatcher (Ninjas 19)",
["Skullsnatcher (42)"]						= "Skullsnatcher (Rats 42)",
["Skullsnatcher (43)"]						= "Skullsnatcher (Rats 43)",
["Skyhunter Cub (7)"]						= "Skyhunter Cub (Cats 7)",
["Skyhunter Cub (678)"]						= "Skyhunter Cub (Cats 18)",
["Skyhunter Cub (702)"]						= "Skyhunter Cub (Cats 42)",
["Skyhunter Patrol (19)"]					= "Skyhunter Patrol (Cats 19)",
["Skyhunter Patrol (714)"]					= "Skyhunter Patrol (Cats 54)",
["Skyhunter Skirmisher (3)"]				= "Skyhunter Skirmisher (Cats 3)",
["Skyhunter Skirmisher (699)"]				= "Skyhunter Skirmisher (Cats 39)",
["Skyrider Trainee (6)"]					= "Skyrider Trainee (Angels 6)",
["Skyrider Trainee (54)"]					= "Skyrider Trainee (Angels 54)",
["Soratami Mindsweeper (3)"]				= "Soratami Mindsweeper (Wizards 3)",
["Soratami Mindsweeper (28)"]				= "Soratami Mindsweeper (Wizards 28)",
["Soratami Mindsweeper (50)"]				= "Soratami Mindsweeper (Wizards 50)",
["Soratami Rainshaper (30)"]				= "Soratami Rainshaper (Wizards 30)",
["Soratami Rainshaper (43)"]				= "Soratami Rainshaper (Wizards 43)",
["Soul of Magma (18)"]						= "Soul of Magma (Spirits 18)",
["Soul of Magma (19)"]						= "Soul of Magma (Spirits 19)",
["Soul Warden (14)"]						= "Soul Warden (Thallids 14)",
["Soul Warden (27)"]						= "Soul Warden (Thallids 27)",
["Soulsworn Jury (43)"]						= "Soulsworn Jury (Angels 43)",
["Soulsworn Jury (44)"]						= "Soulsworn Jury (Angels 44)",
["Specter's Shroud"]						= "Specter’s Shroud",
["Spectral Sliver (27)"]					= "Spectral Sliver (Slivers 27)",
["Spectral Sliver (28)"]					= "Spectral Sliver (Slivers 28)",
["Spineless Thug (18)"]						= "Spineless Thug (Zombies 18)",
["Spineless Thug (19)"]						= "Spineless Thug (Zombies 19)",
["Spineless Thug (31)"]						= "Spineless Thug (Zombies 31)",
["Spirit Link (3)"]							= "Spirit Link (Angels 3)",
["Spirit Link (40)"]						= "Spirit Link (Spirits 40)",
["Sprout (30)"]								= "Sprout (Thallids 30)",
["Sprout (41)"]								= "Sprout (Thallids 41)",
["Strength in Numbers (42)"]				= "Strength in Numbers (Thallids 42)",
["Strength in Numbers (52)"]				= "Strength in Numbers (Thallids 52)",
["Strength in Numbers (53)"]				= "Strength in Numbers (Thallids 53)",
["Supply|Demand (16)"]						= "Supply|Demand (Thallids 16)",
["Supply|Demand (28)"]						= "Supply|Demand (Thallids 28)",
["Swarm of Rats (2)"]						= "Swarm of Rats (Rats 2)",
["Swarm of Rats (14)"]						= "Swarm of Rats (Rats 14)",
["Swarm of Rats (27)"]						= "Swarm of Rats (Rats 27)",
["Sylvan Messenger (14)"]					= "Sylvan Messenger (Elves 14)",
["Sylvan Messenger (15)"]					= "Sylvan Messenger (Elves 15)",
["Terramorphic Expanse (8)"]				= "Terramorphic Expanse (Cats 8)",
["Terramorphic Expanse (680)"]				= "Terramorphic Expanse (Cats 20)",
["Terramorphic Expanse (694)"]				= "Terramorphic Expanse (Cats 34)",
["Terramorphic Expanse (705)"]				= "Terramorphic Expanse (Cats 45)",
["Terrarion (19)"]							= "Terrarion (Slivers 19)",
["Terrarion (20)"]							= "Terrarion (Slivers 20)",
["Thallid Germinator (19)"]					= "Thallid Germinator (Thallids 19)",
["Thallid Germinator (31)"]					= "Thallid Germinator (Thallids 31)",
["Thallid Germinator (43)"]					= "Thallid Germinator (Thallids 43)",
["Thallid Shell-Dweller (6)"]				= "Thallid Shell-Dweller (Thallids 6)",
["Thallid Shell-Dweller (7)"]				= "Thallid Shell-Dweller (Thallids 7)",
["Threaten (26)"]							= "Threaten (Berserkers 26)",
["Threaten (27)"]							= "Threaten (Berserkers 27)",
["Throat Slitter (2)"]						= "Throat Slitter (Ninjas 2)",
["Throat Slitter (3)"]						= "Throat Slitter (Ninjas 3)",
["Timberwatch Elf (18)"]					= "Timberwatch Elf (Elves 18)",
["Timberwatch Elf (19)"]					= "Timberwatch Elf (Elves 19)",
["Treetop Scout (5)"]						= "Treetop Scout (Elves 5)",
["Treetop Scout (6)"]						= "Treetop Scout (Elves 6)",
["Vacuumelt (4)"]							= "Vacuumelt (Wizards 4)",
["Vacuumelt (40)"]							= "Vacuumelt (Wizards 40)",
["Vedalken Dismisser (54)"]					= "Vedalken Dismisser (Wizards 54)",
["Vedalken Dismisser (55)"]					= "Vedalken Dismisser (Wizards 55)",
["Vedalken Entrancer (7)"]					= "Vedalken Entrancer (Wizards 7)",
["Vedalken Entrancer (18)"]					= "Vedalken Entrancer (Wizards 18)",
["Vedalken Entrancer (31)"]					= "Vedalken Entrancer (Wizards 31)",
["Vedalken Entrancer (44)"]					= "Vedalken Entrancer (Wizards 44)",
["Volcanic Hammer (617)"]					= "Volcanic Hammer (Beasts 17)",
["Volcanic Hammer (631)"]					= "Volcanic Hammer (Beasts 31)",
["Volcanic Hammer (43)"]					= "Volcanic Hammer (Spirits 43)",
["Walker of Secret Ways (51)"]				= "Walker of Secret Ways (Ninjas 51)",
["Walker of Secret Ways (52)"]				= "Walker of Secret Ways (Ninjas 52)",
["Waxmane Baku (31)"]						= "Waxmane Baku (Spirits 31)",
["Waxmane Baku (32)"]						= "Waxmane Baku (Spirits 32)",
["Wayfarer's Bauble (43)"]					= "Wayfarer’s Bauble (Slivers 43)",
["Wayfarer's Bauble (44)"]					= "Wayfarer’s Bauble (Slivers 44)",
["Wirewood Hivemaster (3)"]					= "Wirewood Hivemaster (Elves 3)",
["Wirewood Hivemaster (4)"]					= "Wirewood Hivemaster (Elves 4)",
["Wirewood Pride (32)"]						= "Wirewood Pride (Elves 32)",
["Wirewood Pride (44)"]						= "Wirewood Pride (Elves 44)",
["Wirewood Pride (55)"]						= "Wirewood Pride (Elves 55)",
["Woebearer (16)"]							= "Woebearer (Zombies 16)",
["Woebearer (51)"]							= "Woebearer (Zombies 51)",
},
[600] = { -- Unhinged
['"Ach! Hans, Run!"']				= '“Ach! Hans, Run!”',
},
[490] = { -- Deckmasters
["Swamp (48)"]			= "Swamp (42)",
["Swamp (49)"]			= "Swamp (43)",
["Swamp (50)"]			= "Swamp (44)",
["Mountain (51)"]		= "Mountain (45)",
["Mountain (52)"]		= "Mountain (46)",
["Mountain (53)"]		= "Mountain (47)",
["Forest (54)"]			= "Forest (48)",
["Forest (55)"]			= "Forest (49)",
["Forest (56)"]			= "Forest (50)",
["Guerrilla Tactics (1)"]		= "Guerrilla Tactics (13a)",
["Guerrilla Tactics (2)"]		= "Guerrilla Tactics (13b)",
["Icy Manipulator (1)"]			= "Icy Manipulator",
["Icy Manipulator (2)"]			= "Icy Manipulator (premium)",
["Incinerate (1)"]				= "Incinerate",
["Incinerate (2)"]				= "Incinerate (premium)",
["Lim-Dûl's High Guard (1)"]	= "Lim-Dûl’s High Guard (6a)",
["Lim-Dûl's High Guard (2)"]	= "Lim-Dûl’s High Guard (6b)",
["Phantasmal Fiend (1)"]		= "Phantasmal Fiend (8a)",
["Phantasmal Fiend (2)"]		= "Phantasmal Fiend (8b)",
["Phyrexian War Beast (1)"]		= "Phyrexian War Beast (37a)",
["Phyrexian War Beast (2)"]		= "Phyrexian War Beast (37b)",
["Storm Shaman (1)"]			= "Storm Shaman (21a)",
["Storm Shaman (2)"]			= "Storm Shaman (21b)",
["Yavimaya Ancients (1)"]		= "Yavimaya Ancients (31a)",
["Yavimaya Ancients (2)"]		= "Yavimaya Ancients (31b)",
},
[380] = { -- Portal Three Kingdoms
['Pang Tong, "Young Phoenix"']			= "Pang Tong, “Young Phoenix”",
['Kongming, "Sleeping Dragon"']			= "Kongming, “Sleeping Dragon”",
},
[340] = { -- Anthologies
["Plains (87)"]			= "Plains (1)",
["Plains (86)"]			= "Plains (2)",
["Swamp (42)"]			= "Swamp (1)",
["Swamp (43)"]			= "Swamp (2)",
["Mountain (40)"]		= "Mountain (1)",
["Mountain (41)"]		= "Mountain (2)",
["Forest (85)"]			= "Forest (1)",
["Forest (84)"]			= "Forest (2)",
},
[320] = { -- Unglued
["B.F.M. (Big Furry Monster) (1)"]	= "B.F.M. (Left)",
["B.F.M. (Big Furry Monster) (2)"]	= "B.F.M. (Right)",
},
[260] = { -- Portal
["Anaconda (2)"]			= "Anaconda",
["Anaconda (1)"]			= "Anaconda (ST)",
["Armored Pegasus (1)"]		= "Armored Pegasus",
["Armored Pegasus (2)"]		= "Armored Pegasus (DG)",
["Blaze (2)"]				= "Blaze",
["Blaze (1)"]				= "Blaze (ST)",
["Bull Hippo (2)"]			= "Bull Hippo",
["Bull Hippo (1)"]			= "Bull Hippo (DG)",
["Cloud Pirates (1)"]		= "Cloud Pirates",
["Cloud Pirates (2)"]		= "Cloud Pirates (DG)",
["Elite Cat Warrior (2)"]	= "Elite Cat Warrior",
["Elite Cat Warrior (1)"]	= "Elite Cat Warrior (ST)",
["Feral Shadow (1)"]		= "Feral Shadow",
["Feral Shadow (2)"]		= "Feral Shadow (DG)",
["Hand of Death (2)"]		= "Hand of Death",
["Hand of Death (1)"]		= "Hand of Death (ST)",
["Monstrous Growth (2)"]	= "Monstrous Growth",
["Monstrous Growth (1)"]	= "Monstrous Growth (ST)",
["Raging Goblin (2)"]		= "Raging Goblin",
["Raging Goblin (1)"]		= "Raging Goblin (ST)",
["Snapping Drake (1)"]		= "Snapping Drake",
["Snapping Drake (2)"]		= "Snapping Drake (DG)",
["Storm Crow (1)"]			= "Storm Crow",
["Storm Crow (2)"]			= "Storm Crow (DG)",
["Warrior's Charge (2)"]	= "Warrior's Charge",
["Warrior's Charge (1)"]	= "Warrior's Charge (ST)",
},
[225] = { -- Introductory Two-Player Set
["Plains (42)"]			= "Plains (1)",
["Plains (43)"]			= "Plains (2)",
["Plains (44)"]			= "Plains (3)",
["Island (26)"]			= "Island (1)",
["Island (27)"]			= "Island (2)",
["Island (28)"]			= "Island (3)",
["Swamp (53)"]			= "Swamp (1)",
["Swamp (54)"]			= "Swamp (2)",
["Swamp (55)"]			= "Swamp (3)",
["Mountain (34)"]		= "Mountain (1)",
["Mountain (35)"]		= "Mountain (2)",
["Mountain (36)"]		= "Mountain (3)",
["Forest (18)"]			= "Forest (1)",
["Forest (19)"]			= "Forest (2)",
["Forest (20)"]			= "Forest (3)",
},
[69] = { -- Box Topper Cards
["Ambition's Cost"]				= "Ambition’s Cost",
["Avatar of Hope (1)"]			= "Avatar of Hope (8ED)",
["Avatar of Hope (2)"]			= "Avatar of Hope (PRM)",
["Hell's Caretaker"]			= "Hell’s Caretaker",
["Jester's Cap"]				= "Jester’s Cap",
["Lord of the Undead (1)"]		= "Lord of the Undead (8ED)",
["Lord of the Undead (2)"]		= "Lord of the Undead (PRM)",
["Obliterate (1)"]				= "Obliterate (8ED)",
["Obliterate (2)"]				= "Obliterate (PRM)",
["Phyrexian Plaguelord (1)"]	= "Phyrexian Plaguelord (8ED)",
["Phyrexian Plaguelord (2)"]	= "Phyrexian Plaguelord (PRM)",
["Savannah Lions (1)"]			= "Savannah Lions (8ED)",
["Savannah Lions (2)"]			= "Savannah Lions (PRM)",
["Two-Headed Dragon (1)"]		= "Two-Headed Dragon (8ED)", 
["Two-Headed Dragon (2)"]		= "Two-Headed Dragon (PRM)", 
},
[53] = { -- Holiday Gift Box Promos
["Karametra's Acolyte"]			= "Karametra’s Acolyte",
},
[52] = { -- Intro Pack Promos
["Ankle Shanker (2)"]				= "Ankle Shanker",-- KTK
["Avalanche Tusker (2)"]			= "Avalanche Tusker",-- KTK
["Ivorytusk Fortress (2)"]			= "Ivorytusk Fortress",-- KTK
["Rakshasa Vizier (2)"]				= "Rakshasa Vizier",-- KTK
["Sage of the Inward Eye (2)"]		= "Sage of the Inward Eye",-- KTK
["Archfiend of Depravity (2)"]		= "Archfiend of Depravity",-- FRF
["Dragonscale General (2)"]			= "Dragonscale General",-- FRF
["Flamerush Rider (2)"]				= "Flamerush Rider",-- FRF
["Sage-Eye Avengers (2)"]			= "Sage-Eye Avengers",-- FRF
["Arashin Sovereign (2)"]			= "Arashin Sovereign",-- DTK
["Boltwing Marauder (2)"]			= "Boltwing Marauder",-- DTK
["Harbinger of the Hunt (2)"]		= "Harbinger of the Hunt",-- DTK
["Necromaster Dragon (2)"]			= "Necromaster Dragon",-- DTK
["Pristine Skywise (2)"]			= "Pristine Skywise",-- DTK
["Alhammarret, High Arbiter (2)"]	= "Alhammarret, High Arbiter",-- ORI
["Dwynen, Gilt-Leaf Daen (2)"]		= "Dwynen, Gilt-Leaf Daen",-- ORI
["Hixus, Prison Warden (2)"]		= "Hixus, Prison Warden",-- ORI
["Kothophed, Soul Hoarder (2)"]		= "Kothophed, Soul Hoarder",-- ORI
["Pia and Kiran Nalaar (2)"]		= "Pia and Kiran Nalaar",-- ORI
["Barrage Tyrant (1)"]				= "Barrage Tyrant",-- BFZ
["Defiant Bloodlord (1)"]			= "Defiant Bloodlord",-- BFZ
["Drowner of Hope (1)"]				= "Drowner of Hope",-- BFZ
["Hero of Goma Fada (1)"]			= "Hero of Goma Fada",-- BFZ
["Oran-Rief Hydra (1)"]				= "Oran-Rief Hydra",-- BFZ
["Deepfathom Skulker (2)"]			= "Deepfathom Skulker",-- OGW
["Dread Defiler (2)"]				= "Dread Defiler",-- OGW
["Gladehart Cavalry (2)"]			= "Gladehart Cavalry",-- OGW
["Munda's Vanguard (2)"]			= "Munda's Vanguard",-- OGW
["Tyrant of Valakut (2)"]			= "Tyrant of Valakut",-- OGW
["Drogskol Cavalry (2)"]			= "Drogskol Cavalry",-- SOI
["Flameblade Angel (2)"]			= "Flameblade Angel",-- SOI
["Markov Dreadknight (2)"]			= "Markov Dreadknight",-- SOI
["Nephalia Moondrakes (2)"]			= "Nephalia Moondrakes",-- SOI
["Soul Swallower (2)"]				= "Soul Swallower",-- SOI
},
[45] = { -- Magic Premiere Shop Promos
["Plains (7)"]		= "Plains (ALA)",
["Plains (10)"]		= "Plains (ISD)",
["Plains (6)"]		= "Plains (LRW)",
["Plains (9)"]		= "Plains (SOM)",
["Plains (5)"]		= "Plains (TSP)",
["Plains (8)"]		= "Plains (ZEN)",
["Plains (1)"]		= "Plains (Azorius)",
["Plains (2)"]		= "Plains (Boros)",
["Plains (3)"]		= "Plains (Orzhov)",
["Plains (4)"]		= "Plains (Selesnya)",
["Island (7)"]		= "Island (ALA)",
["Island (10)"]		= "Island (ISD)",
["Island (6)"]		= "Island (LRW)",
["Island (9)"]		= "Island (SOM)",
["Island (5)"]		= "Island (TSP)",
["Island (8)"]		= "Island (ZEN)",
["Island (1)"]		= "Island (Azorius)",
["Island (2)"]		= "Island (Dimir)",
["Island (3)"]		= "Island (Izzet)",
["Island (4)"]		= "Island (Simic)",
["Swamp (7)"]		= "Swamp (ALA)",
["Swamp (10)"]		= "Swamp (ISD)",
["Swamp (6)"]		= "Swamp (LRW)",
["Swamp (9)"]		= "Swamp (SOM)",
["Swamp (5)"]		= "Swamp (TSP)",
["Swamp (8)"]		= "Swamp (ZEN)",
["Swamp (3)"]		= "Swamp (Dimir)",
["Swamp (2)"]		= "Swamp (Golgari)",
["Swamp (4)"]		= "Swamp (Orzhov)",
["Swamp (1)"]		= "Swamp (Rakdos)",
["Mountain (7)"]	= "Mountain (ALA)",
["Mountain (10)"]	= "Mountain (ISD)",
["Mountain (6)"]	= "Mountain (LRW)",
["Mountain (9)"]	= "Mountain (SOM)",
["Mountain (5)"]	= "Mountain (TSP)",
["Mountain (8)"]	= "Mountain (ZEN)",
["Mountain (1)"]	= "Mountain (Boros)",
["Mountain (2)"]	= "Mountain (Rakdos)",
["Mountain (3)"]	= "Mountain (Gruul)",
["Mountain (4)"]	= "Mountain (Izzet)",
["Forest (7)"]		= "Forest (ALA)",
["Forest (10)"]		= "Forest (ISD)",
["Forest (6)"]		= "Forest (LRW)",
["Forest (9)"]		= "Forest (SOM)",
["Forest (5)"]		= "Forest (TSP)",
["Forest (8)"]		= "Forest (ZEN)",
["Forest (1)"]		= "Forest (Golgari)",
["Forest (2)"]		= "Forest (Gruul)",
["Forest (3)"]		= "Forest (Selesnya)",
["Forest (4)"]		= "Forest (Simic)",
},
[40] = {-- Arena/Coloseo League
["Plains (1)"]		= "Plains (1996)",
["Plains (2)"]		= "Plains (1999)",
["Plains (3)"]		= "Plains (2000)",
["Plains (4)"]		= "Plains (2001)",
["Plains (5)"]		= "Plains (2003)",
["Plains (6)"]		= "Plains (2004)",
["Plains (7)"]		= "Plains (2005)",
["Plains (8)"]		= "Plains (2006)",
["Island (1)"]		= "Island (1996)",
["Island (2)"]		= "Island (1999)",
["Island (3)"]		= "Island (2000)",
["Island (4)"]		= "Island (2001a)",
["Island (5)"]		= "Island (2001b)",
["Island (6)"]		= "Island (2003)",
["Island (7)"]		= "Island (2004)",
["Island (8)"]		= "Island (2005)",
["Island (9)"]		= "Island (2006)",
["Swamp (1)"]		= "Swamp (1996)",
["Swamp (2)"]		= "Swamp (1999)",
["Swamp (3)"]		= "Swamp (2000)",
["Swamp (4)"]		= "Swamp (2001)",
["Swamp (5)"]		= "Swamp (2003)",
["Swamp (6)"]		= "Swamp (2004)",
["Swamp (7)"]		= "Swamp (2005)",
["Swamp (8)"]		= "Swamp (2006)",
["Mountain (1)"]	= "Mountain (1996)",
["Mountain (2)"]	= "Mountain (1999)",
["Mountain (3)"]	= "Mountain (2000)",
["Mountain (4)"]	= "Mountain (2001)",
["Mountain (5)"]	= "Mountain (2003)",
["Mountain (6)"]	= "Mountain (2004)",
["Mountain (7)"]	= "Mountain (2005)",
["Mountain (8)"]	= "Mountain (2006)",
["Forest (1)"]		= "Forest (1996)",
["Forest (2)"]		= "Forest (1999)",
["Forest (3)"]		= "Forest (2000)",
["Forest (4)"]		= "Forest (2001a)",
["Forest (5)"]		= "Forest (2001b)",
["Forest (6)"]		= "Forest (2003)",
["Forest (7)"]		= "Forest (2004)",
["Forest (8)"]		= "Forest (2005)",
["Forest (9)"]		= "Forest (2006)",
["All Hallow's Eve (oversized)"]			= "All Hallow’s Eve (oversized)",
["Sol'kanar the Swamp King (oversized)"]	= "Sol’kanar the Swamp King (oversized)",
["City of Brass (1) (oversized)"]			= "City of Brass (3rd) (oversized)",
["City of Brass (2) (oversized)"]			= "City of Brass (4th) (oversized)",
["Pyroclasm (1) (oversized)"]				= "Pyroclasm (3rd) (oversized)",
["Pyroclasm (2) (oversized)"]				= "Pyroclasm (4th) (oversized)",
["Deflection (1) (oversized)"]				= "Deflection (3rd) (oversized)",
["Deflection (2) (oversized)"]				= "Deflection (4th) (oversized)",
["Natural Balance (1) (oversized)"]			= "Natural Balance (3rd) (oversized)",
["Natural Balance (2) (oversized)"]			= "Natural Balance (4th) (oversized)",
["Nether Shadow (1) (oversized)"]			= "Nether Shadow (3rd) (oversized)",
["Nether Shadow (2) (oversized)"]			= "Nether Shadow (4th) (oversized)",
["Squirrel Farm (1) (oversized)"]			= "Squirrel Farm (3rd) (oversized)",
["Squirrel Farm (2) (oversized)"]			= "Squirrel Farm (4th) (oversized)",
["Fallen Angel (1) (oversized)"]			= "Fallen Angel (3rd) (oversized)",
["Fallen Angel (2) (oversized)"]			= "Fallen Angel (4th) (oversized)",
["Meditate (1) (oversized)"]				= "Meditate (3rd) (oversized)",
["Meditate (2) (oversized)"]				= "Meditate (4th) (oversized)",
["Enduring Renewal (1) (oversized)"]		= "Enduring Renewal (3rd) (oversized)",
["Enduring Renewal (2) (oversized)"]		= "Enduring Renewal (4th) (oversized)",
["Dissipate (1) (oversized)"]				= "Dissipate (3rd) (oversized)",
["Dissipate (2) (oversized)"]				= "Dissipate (4th) (oversized)",
["Swords to Plowshares (1) (oversized)"]	= "Swords to Plowshares (3rd) (oversized)",
["Swords to Plowshares (2) (oversized)"]	= "Swords to Plowshares (4th) (oversized)",
["Erhnam Djinn (1) (oversized)"]			= "Erhnam Djinn (3rd) (oversized)",
["Erhnam Djinn (2) (oversized)"]			= "Erhnam Djinn (4th) (oversized)",
["Guardian Beast (1) (oversized)"]			= "Guardian Beast (3rd) (oversized)",
["Guardian Beast (2) (oversized)"]			= "Guardian Beast (4th) (oversized)",
["Hydroblast (1) (oversized)"]				= "Hydroblast (3rd) (oversized)",
["Hydroblast (2) (oversized)"]				= "Hydroblast (4th) (oversized)",
["Pyroblast (1) (oversized)"]				= "Pyroblast (3rd) (oversized)",
["Pyroblast (2) (oversized)"]				= "Pyroblast (4th) (oversized)",
["Knight Token (1 League)"]					= "Knight Token", -- RTR
["Minotaur Token (Red 2/3)"]				= "Minotaur Token", -- JOU
["Soldier Token (White 1/1 Enchantment)"]	= "Soldier Token (BNG)",
["Soldier Token (White 1/1)"]				= "Soldier Token (THS)",
["Soldier Token (1)"]						= "Soldier Token (GTC)",-- RW 1/1
},
[30] = { -- Friday Night Magic Promos
["Goblin Warchief (1)"]				= "Goblin Warchief",
["Goblin Warchief (2)"]				= "Goblin Warchief (2016)",--2016
},
[27] = { -- Alternate Art Lands
["Plains (R1) (APAC)"]	= "Plains (APAC Red)",
["Plains (B1) (APAC)"]	= "Plains (APAC Blue)",
["Plains (C1) (APAC)"]	= "Plains (APAC Clear)",
["Island (R2) (APAC)"]	= "Island (APAC Red)",
["Island (B2) (APAC)"]	= "Island (APAC Blue)",
["Island (C2) (APAC)"]	= "Island (APAC Clear)",
["Swamp (R3) (APAC)"]	= "Swamp (APAC Red)",
["Swamp (B3) (APAC)"]	= "Swamp (APAC Blue)",
["Swamp (C3) (APAC)"]	= "Swamp (APAC Clear)",
["Mountain (R4) (APAC)"]= "Mountain (APAC Red)",
["Mountain (B4) (APAC)"]= "Mountain (APAC Blue)",
["Mountain (C4) (APAC)"]= "Mountain (APAC Clear)",
["Forest (R5) (APAC)"]	= "Forest (APAC Red)",
["Forest (B5) (APAC)"]	= "Forest (APAC Blue)",
["Forest (C5) (APAC)"]	= "Forest (APAC Clear)",
["Plains (10) (Euro)"]	= "Plains (Euro Blue)",
["Plains (11) (Euro)"]	= "Plains (Euro Red)",
["Plains (12) (Euro)"]	= "Plains (Euro Purple)",
["Island (4) (Euro)"]	= "Island (Euro Blue)",
["Island (5) (Euro)"]	= "Island (Euro Red)",
["Island (6) (Euro)"]	= "Island (Euro Purple)",
["Swamp (13) (Euro)"]	= "Swamp (Euro Blue)",
["Swamp (14) (Euro)"]	= "Swamp (Euro Red)",
["Swamp (15) (Euro)"]	= "Swamp (Euro Purple)",
["Mountain (7) (Euro)"]	= "Mountain (Euro Blue)",
["Mountain (8) (Euro)"]	= "Mountain (Euro Red)",
["Mountain (9) (Euro)"]	= "Mountain (Euro Purple)",
["Forest (1) (Euro)"]	= "Forest (Euro Blue)",
["Forest (2) (Euro)"]	= "Forest (Euro Red)",
["Forest (3) (Euro)"]	= "Forest (Euro Purple)",
},
[25] = { -- Judge Gift Cards
["Vindicate (1)"]			= "Vindicate (2007)",
["Vindicate (2)"]			= "Vindicate (2013)",
["Wasteland (1)"]			= "Wasteland (2010)",
["Wasteland (2)"]			= "Wasteland (2015)",
},
[24] = { --Champs Promos
["Urza's Factory"]			= "Urza’s Factory",
},
[23] = { -- Gateway
["Imprison this Insolent Wretch"]	= "Imprison This Insolent Wretch",
["Perhaps You've Met My Cohort"]	= "Perhaps You’ve Met My Cohort",
["Fling (1)"]						= "Fling (50 DCI)",
["Fling (2)"]						= "Fling (69 DCI)",
["Sylvan Ranger (1)"]				= "Sylvan Ranger (51 DCI)",
["Sylvan Ranger (2)"]				= "Sylvan Ranger (70 DCI)",
},
[22] = { -- Prerelease Promos
["Lu Bu, Master-at-Arms (1)"]		= "Lu Bu, Master-at-Arms (April)",
["Lu Bu, Master-at-Arms (2)"]		= "Lu Bu, Master-at-Arms (July)",
["Dirtcowl Wurm (1)"]				= "Dirtcowl Wurm",
["Dirtcowl Wurm (2)"]				= "Dirtcowl Wurm (DROP unique?)",
["Ravenous Demon"]					= "Ravenous Demon|Archdemon of Greed",
["Mayor of Avabruck"]				= "Mayor of Avabruck|Howlpack Alpha",
["Laquatus's Champion"]				= "Laquatus’s Champion",
["Garruk the Slayer (oversized)"]	= "Garruk the Slayer",
["Ankle Shanker (1)"]				= "Ankle Shanker",-- KTK
["Avalanche Tusker (1)"]			= "Avalanche Tusker",-- KTK
["Ivorytusk Fortress (1)"]			= "Ivorytusk Fortress",-- KTK
["Rakshasa Vizier (1)"]				= "Rakshasa Vizier",-- KTK
["Sage of the Inward Eye (1)"]		= "Sage of the Inward Eye",-- KTK
["Archfiend of Depravity (1)"]		= "Archfiend of Depravity",-- FRF
["Dragonscale General (1)"]			= "Dragonscale General",-- FRF
["Flamerush Rider (1)"]				= "Flamerush Rider",-- FRF
["Sage-Eye Avengers (1)"]			= "Sage-Eye Avengers",-- FRF
["Dragonlord's Servant (Dragonfury)"]	= "Dragonlord’s Servant (Dragonfury)",-- FRF
["Arashin Sovereign (1)"]			= "Arashin Sovereign",-- DTK
["Boltwing Marauder (1)"]			= "Boltwing Marauder",-- DTK
["Harbinger of the Hunt (1)"]		= "Harbinger of the Hunt",-- DTK
["Necromaster Dragon (1)"]			= "Necromaster Dragon",-- DTK
["Pristine Skywise (1)"]			= "Pristine Skywise",-- DTK
["Alhammarret, High Arbiter (1)"]	= "Alhammarret, High Arbiter",--ORI
["Dwynen, Gilt-Leaf Daen (1)"]		= "Dwynen, Gilt-Leaf Daen",--ORI
["Hixus, Prison Warden (1)"]		= "Hixus, Prison Warden",--ORI
["Kothophed, Soul Hoarder (1)"]		= "Kothophed, Soul Hoarder",--ORI
["Pia and Kiran Nalaar (1)"]		= "Pia and Kiran Nalaar ",--ORI
["Mizzium Meddler (2)"]				= "Mizzium Meddler",--ORI
},
[21] = { -- Release Promos
["Plots That Span Centuries"]		= "Plots that Span Centuries (Scheme)",
["Mondronen Shaman"]				= "Mondronen Shaman|Tovolar’s Magehunter",
["Ludevic's Test Subject"]			= "Ludevic’s Test Subject|Ludevic’s Abomination",
["Budoka Pupil"]					= "Budoka Pupil|Ichiga, Who Topples Oaks",
["Marit Lage Token (Black 20/20)"]	= "Marit Lage Token",
["Incoming! (oversized)"]			= "Incoming!",
},
[20] = {  --Magic Player Rewards 
["Bear Token (39)"] 		= "Bear Token (ONS)",
["Bear Token (29)"] 		= "Bear Token (ODY)",
["Beast Token (45)"] 		= "Beast Token (DST)",
["Beast Token (30)"] 		= "Beast Token (ODY)",
["Elephant Token (25)"]		= "Elephant Token (INV)",
["Elephant Token (31)"]		= "Elephant Token (ODY)",
["Spirit Token (47)"] 		= "Spirit Token (CHK)",
["Spirit Token (28)"] 		= "Spirit Token (PLS)",
["Lightning Bolt (1)"]		= "Lightning Bolt (146)",
["Lightning Bolt (2)"]		= "Lightning Bolt (1)",
},
[15] = { -- Convention Promos
["Ajani, Caller of the Pride (CC13)"]	= "Ajani, Caller of the Pride",
["Chandra, Pyromaster (CC13)"]			= "Chandra, Pyromaster",
["Garruk, Caller of Beasts (CC13)"]		= "Garruk, Caller of Beasts",
["Jace, Memory Adept (CC13)"]			= "Jace, Memory Adept",
["Liliana of the Dark Realms (CC13)"]	= "Liliana of the Dark Realms",
["Hurloon Minotaur (oversized)"]		= "Hurloon Minotaur",
["Serra Angel (1) (oversized)"]			= "Serra Angel",
},
[10] = { --Junior Series Promos
["City of Brass (J)"]			= "City of Brass",
["Crusade (J)"]					= "Crusade",
["Elvish Lyrist (J)"]			= "Elvish Lyrist",
["Giant Growth (J)"]			= "Giant Growth",
["Giant Growth (JPN)"]			= "Giant Growth",
["Lord of Atlantis (J)"]		= "Lord of Atlantis",
["Serra Avatar (J)"]			= "Serra Avatar",
["Thran Quarry (J)"]			= "Thran Quarry",
["Two-Headed Dragon (J)"]		= "Two-Headed Dragon",
["Two-Headed Dragon (JPN)"]		= "Two-Headed Dragon",
["Volcanic Hammer (J)"]			= "Volcanic Hammer",
["Volcanic Hammer (JPN)"]		= "Volcanic Hammer",
["Mad Auntie (J)"]				= "Mad Auntie",--Magic Scholarship
["Token (1) (J)"]				= "Token (1/1) (DROP)",
},
[7] = {
["Jester's Cap"]				= "Jester’s Cap",
},
[6] = { -- Comic Inserts 
["Chandra's Outrage"]			= "Chandra’s Outrage",
["Chandra's Spitfire"]			= "Chandra’s Spitfire",
["Serra Angel (2)"]				= "Serra Angel",
},
[5] = { -- Book Inserts 
["Mana Crypt (1)"]				= "Mana Crypt",
["Mana Crypt (2)"]				= "Mana Crypt",
--["Mana Crypt (2)"]				= "Mana Crypt (SPA)",
},
} -- end table site.namereplace

--[[- set replacement tables.

  fields are for subtables indexed by #number setid.
 { #number (setid)= #table { #string (cardname)= #string (newset), ... } , ... }
 
 @type site.settweak
 @field [parent=#site.settweak] #string name
]]
site.settweak = {
[806] = { -- JOU
["Spear of the General"]		= "Prerelease Promos",
["Cloak of the Philosopher"]	= "Prerelease Promos",
["Lash of the Tyrant"]			= "Prerelease Promos",
["Axe of the Warmonger"]		= "Prerelease Promos",
["Bow of the Hunter"]			= "Prerelease Promos",
["The Destined"]				= "Release Promos",
["The Champion"]				= "Magic Game Day",
["Impulsive Charge"]		= "Challenge Deck: Deicide",
["Wild Maenads"]			= "Challenge Deck: Deicide",
["Maddened Oread"]			= "Challenge Deck: Deicide",
["Xenagos Ascended"]		= "Challenge Deck: Deicide",
["Serpent Dancers"]			= "Challenge Deck: Deicide",
["Xenagos's Scorn"]			= "Challenge Deck: Deicide",
["Pheres-Band Revelers"]	= "Challenge Deck: Deicide",
["Estatic Piper"]			= "Challenge Deck: Deicide",
["Rollicking Throng"]		= "Challenge Deck: Deicide",
["Impulsive Return"]		= "Challenge Deck: Deicide",
["Impulsive Destruction"]	= "Challenge Deck: Deicide",
["Xenagos's Strike"]		= "Challenge Deck: Deicide",
["Rip to Pieces"]			= "Challenge Deck: Deicide",
["Dance of Flame"]			= "Challenge Deck: Deicide",
["Dance of Panic"]			= "Challenge Deck: Deicide",
},
[802] = { -- BNG
["The General"]					= "Prerelease Promos",
["The Savant"]					= "Prerelease Promos",
["The Tyrant"]					= "Prerelease Promos",
["The Warmonger"]				= "Prerelease Promos",
["The Provider"]				= "Prerelease Promos",
["The Explorer"]				= "Release Promos",
["The Vanquisher"]				= "Magic Game Day",
["Altar of Mogis"]			= "Challenge Deck: Battle the Horde",
["Consuming Rage"]			= "Challenge Deck: Battle the Horde",
["Descend on the Prey"]		= "Challenge Deck: Battle the Horde",
["Intervention of Keranos"]	= "Challenge Deck: Battle the Horde",
["Massacre Totem"]			= "Challenge Deck: Battle the Horde",
["Minotaur Goreseeker"]		= "Challenge Deck: Battle the Horde",
["Minotaur Younghorn"]		= "Challenge Deck: Battle the Horde",
["Mogis's Chosen"]			= "Challenge Deck: Battle the Horde",
["Phoberos Reaver"]			= "Challenge Deck: Battle the Horde",
["Plundered Statue"]		= "Challenge Deck: Battle the Horde",
["Reckless Minotaur"]		= "Challenge Deck: Battle the Horde",
["Refreshing Elixir"]		= "Challenge Deck: Battle the Horde",
["Touch of the Horned God"]	= "Challenge Deck: Battle the Horde",
["Unquenchable Fury"]		= "Challenge Deck: Battle the Horde",
["Vitality Salve"]			= "Challenge Deck: Battle the Horde",
},
[800] = { -- THS
["The Protector"]				= "Prerelease Promos",
["The Philosopher"]				= "Prerelease Promos",
["The Avenger"]					= "Prerelease Promos",
["The Warrior"]					= "Prerelease Promos",
["The Hunter"]					= "Prerelease Promos",
["The Harvester"]				= "Release Promos",
["The Slayer"]					= "Magic Game Day",
["Disorienting Glower"]			= "Challenge Deck: Face the Hydra",
["Distract the Hydra"]			= "Challenge Deck: Face the Hydra",
["Grown from the Stump"]		= "Challenge Deck: Face the Hydra",
["Hydra Head"]					= "Challenge Deck: Face the Hydra",
["Hydra's Impenetrable Hide"]	= "Challenge Deck: Face the Hydra",
["Neck Tangle"]					= "Challenge Deck: Face the Hydra",
["Noxious Hydra Breath"]		= "Challenge Deck: Face the Hydra",
["Ravenous Brute Head"]			= "Challenge Deck: Face the Hydra",
["Savage Vigor Head"]			= "Challenge Deck: Face the Hydra",
["Shrieking Titan Head"]		= "Challenge Deck: Face the Hydra",
["Snapping Fang Head"]			= "Challenge Deck: Face the Hydra",
["Strike the Weak Spot"]		= "Challenge Deck: Face the Hydra",
["Swallow the Hero Whole"]		= "Challenge Deck: Face the Hydra",
["Torn Between Heads"]			= "Challenge Deck: Face the Hydra",
["Unified Lunge"]				= "Challenge Deck: Face the Hydra",
},
[340] = { --Anthologies
--TODO unglued tokens already in unglued url. MKM bug?
["Goblin"]						= "Unglued (Token)",
["Pegasus"]						= "Unglued (Token)",
},
[40] = { -- Arena/Colosseo Leagues Promos
 --Oversized%206x9%20Promos
["Serra Angel (1) (oversized)"]		= "Convention Promos",
["Hurloon Minotaur (oversized)"]	= "Convention Promos",
["Aswan Jaguar (oversized)"]		= "Video Game Promos",
["Chaos Orb (oversized)"]			= "Magazine Inserts",
["Black Lotus (oversized)"]			= "Magazine Inserts",
["Juzám Djinn (oversized)"]			= "Magazine Inserts",
["Jester's Cap (oversized)"]		= "Magazine Inserts",
["Shivan Dragon (oversized)"]		= "Magazine Inserts",
["Serra Angel (2) (oversized)"]		= "Comic Inserts",
["Garruk the Slayer (oversized)"]	= "Prerelease Promos",
["Thorn Elemental (oversized)"]		= "Starter 1999",
["Incoming! (oversized)"]			= "Release Promo",
-- Promos
["Geist of Saint Traft"]	= "Championship Prizes",
["Dreg Mangler"]			= "RTR (Holiday Gift Box)",
["Karametra's Acolyte"]		= "THS (Holiday Gift Box",
["Angel(W 4/4)"]			= "Custom Tokens",
["Centaur"]					= "Judge (RTR)",
["Stealer of Secrets"]		= "Convention Promos (Gamescon 2014)",
["Ruthless Cullblade"]		= "Full Box Promotion (jp)",
["Pestilence Demon"]		= "Full Box Promotion (jp)",
["Goblin Chieftain"]		= "Stores Promos (jp)",
["Loam Lion"]				= "Stores Promos (jp)",
["Oran-Rief, the Vastwood"]	= "Stores Promos (jp)",
["Jamuraan Lion"]			= "Magazine Inserts (de)",
["Archangel"]				= "Magazine Inserts (jp)",
["Darksteel Juggernaut"]	= "Comic Inserts (jp)",
["Kuldotha Phoenix"]		= "Comic Inserts (jp)",
["Phantasmal Dragon"]		= "Comic Inserts (jp)",
["Shivan Dragon"]			= "Comic Inserts (jp)",
["Magic Guru"]				= "Guru Lands",
["Thorn Elemental"]			= "Magazine Inserts (jp)",
},
[31] = { -- Grand Prix Promos (here for DCI%20Promos)
["Ajani Goldmane"]			= "Pro Tour Promo",
["Avatar of Woe"]			= "Pro Tour Promo",
["Eternal Dragon"]			= "Pro Tour Promo",
["Mirari's Wake"]			= "Pro Tour Promo",
["Treva, the Renewer"]		= "Pro Tour Promo",
["Snapcaster Mage"]			= "Pro Tour Promo",
["Balduvian Horde"]			= "Championship Prizes",
["Vengevine"]				= "Championship Prizes",
["Bloodthrone Vampire"]		= "Convention Promos",
["Chandra's Fury"]			= "Covention Promos",
["Char"]					= "Covention Promos",
["Kor Skyfisher"]			= "Convention Promos",
["Merfolk Mesmerist"]		= "Convention Promos",
["Steward of Valeron"]		= "Convention Promos",
["Counterspell"]			= "DCI Legend Membership",
["Incinerate"]				= "DCI Legend Membership",
["Jace Beleren"]			= "Book Inserts",
["Kamahl, Pit Fighter"]		= "Tenth Edition",--"ST"
["Relentless Rats"]			= "Stores Promos",--ITA
["Serra Angel"]				= "Stores Promos",
["Underworld Dreams"]		= "Two-Headed Giant Promo",
["Thalia, Guardian of Thraben"]	= "WMCQ",
["Abrupt Decay"]			= "WMCQ",
["Liliana of the Veil"]		= "Regional PTQ",
},
[23] = { -- Gateway
["Naya Sojourners"]				= "Magic Game Day",
["Faerie Conclave"]				= "Summer of Magic",
["Treetop Village"]				= "Summer of Magic",
},
[22] = { -- Prerelease Promos
["Lord of Shatterskull Pass"]		= "Release Promos",
["Sultai Charm"]					= "Holiday Gift Box",
["Ankle Shanker (2)"]				= "Intro Pack Promos",
["Avalanche Tusker (2)"]			= "Intro Pack Promos",
["Ivorytusk Fortress (2)"]			= "Intro Pack Promos",
["Rakshasa Vizier (2)"]				= "Intro Pack Promos",
["Sage of the Inward Eye (2)"]		= "Intro Pack Promos",
["Archfiend of Depravity (2)"]		= "Intro Pack Promos",
["Dragonscale General (2)"]			= "Intro Pack Promos",
["Flamerush Rider (2)"]				= "Intro Pack Promos",
["Sage-Eye Avengers (2)"]			= "Intro Pack Promos",
["Temur War Shaman"]				= "Intro Pack Promos",
["Arashin Sovereign (2)"]			= "Intro Pack Promos",
["Boltwing Marauder (2)"]			= "Intro Pack Promos",
["Harbinger of the Hunt (2)"]		= "Intro Pack Promos",
["Necromaster Dragon (2)"]			= "Intro Pack Promos",
["Pristine Skywise (2)"]			= "Intro Pack Promos",
["Alhammarret, High Arbiter (2)"]	= "Intro Pack Promos",
["Dwynen, Gilt-Leaf Daen (2)"]		= "Intro Pack Promos",
["Hixus, Prison Warden (2)"]		= "Intro Pack Promos",
["Kothophed, Soul Hoarder (2)"]		= "Intro Pack Promos",
["Pia and Kiran Nalaar (2)"]		= "Intro Pack Promos",
["Mizzium Meddler (1)"]				= "Release Promos",
["Drowner of Hope (1)"]				= "Intro Pack Promos",
},
[21] = {
["Reya Dawnbringer"]			= "Magic Game Day"
},
[6] = { -- Comic Inserts (here for Dengeki%20Maoh%20Promos)
["Shepherd of the Lost"]		= "Convention Promos",
},
} -- end table site.settweak

--[[- card variant tables.
 tables of cards that need to set variant.
 For each setid, will be merged with sensible defaults from LHpi.Data.sets[setid].variants.
 When variants for the same card are set here and in LHpi.Data, sitescript's entry overwrites Data's.
 If override is true, the variant table from LHpi.Data is ignored for this set.
 
 fields are for subtables indexed by #number setid.
 { #number (setid)= #table { override=#boolean , #string (name)= #table { #string, #table { #string or #boolean , ... } } , ... } , ...  }

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
 If override is true, the foiltweak table from LHpi.Data is ignored for this set.

  fields are for subtables indexed by #number setid.
 { #number (setid)= #table { override=#boolean , #string (name)= #table { foil= #boolean } , ... } , ... }
 
 @type site.foiltweak
 @field [parent=#site.foiltweak] #boolean override	(optional) if true, defaults from LHpi.Data will not be used at all
 @field [parent=#site.foiltweak] #table foilstatus
]]
site.foiltweak = {
} -- end table site.foiltweak
--ignore all foiltweak tables from LHpi.Data
for sid,set in pairs(site.sets) do
	site.foiltweak[sid] = { override=true }
end

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
--	tokens = true,
	tokens = { "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA" },
--- if site.expected.nontrad is true, LHpi.Data.sets[setid].cardcount.nontrad is added to pset default.
-- a boolean will set this for all languges, a table will be assumed to be of the form { [langid]=#boolean, ... }
-- @field [parent=#site.expected] #boolean nontrad
	nontrad = true,
--- if site.expected.replica is true, LHpi.Data.sets[setid].cardcount.repl is added to pset default.
-- a boolean will set this for all languges, a table will be assumed to be of the form { [langid]=#boolean, ... }
-- @field [parent=#site.expected] #boolean replica
	replica = true,
-- Core sets
[822] = { pset={ dup=LHpi.Data.sets[822].cardcount.reg }, failed={ dup=LHpi.Data.sets[822].cardcount.tok }, duppset={ [4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dupfail={ [4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, namereplaced=2, dropped=2 },--Checklist dropped
[808] = { pset={ dup=LHpi.Data.sets[808].cardcount.reg }, failed={ dup=LHpi.Data.sets[808].cardcount.tok }, duppset={ [4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dupfail={ [4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" } },
[797] = { pset={ dup=LHpi.Data.sets[797].cardcount.reg }, failed={ dup=LHpi.Data.sets[797].cardcount.tok }, duppset={ [7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dupfail={ [7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" } },
[788] = { pset={ dup=LHpi.Data.sets[788].cardcount.reg }, failed={ dup=LHpi.Data.sets[788].cardcount.tok }, duppset={ [7]="SPA" }, dupfail={ [7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dropped=28 },-- 14 inserts
[779] = { failed={ dup=LHpi.Data.sets[779].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH",[10]="ZHT" } },
[770] = { failed={ dup=LHpi.Data.sets[770].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH",[10]="ZHT" }, dropped=2*9 },--9 inserts
[759] = { failed={ dup=LHpi.Data.sets[759].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" }, dropped=30 },
[720] = { pset={ dup=LHpi.Data.sets[720].cardcount.both-1, [3]=LHpi.Data.sets[720].cardcount.both-2,[8]=LHpi.Data.sets[720].cardcount.reg-1,[9]=LHpi.Data.sets[720].cardcount.reg-1 }, duppset={ [2]="RUS",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA" }, failed={ dup=1, [3]=2,[8]=LHpi.Data.sets[720].cardcount.tok+1,[9]=LHpi.Data.sets[720].cardcount.tok+1 }, dupfail={ [2]="RUS",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA" }, dropped=28 },--"Kamahl, Pit Fighter (ST)" only ENG; no GER March of the Machines exists
[630] = { pset={ dup=LHpi.Data.sets[630].cardcount.reg-7 }, failed={ dup=7 }, duppset={ [2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[9]="SZH" }, dupfail={ [2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[9]="SZH" } },--7 cards exist only in ENG
[550] = { pset={ dup=LHpi.Data.sets[550].cardcount.reg-2,[9]=LHpi.Data.sets[550].cardcount.reg-7 }, failed={ dup=2, [9]=7 }, duppset={ [3]="GER",[4]="FRA",[6]="POR",[7]="SPA" }, dupfail={ [3]="GER",[4]="FRA",[6]="POR",[7]="SPA" } },--2 cards do not exist in GER,FRA,POR,SPA; 7 in SZH
[180] = { pset={ dup=LHpi.Data.sets[180].cardcount.reg,[6]=375 }, duppset={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[8]="JPN" }, failed={ [6]=3 } },
[179] = { pset={ [6]=LHpi.Data.sets[179].cardcount.reg-3, [8]=LHpi.Data.sets[179].cardcount.reg}, failed={ [6]=3 } },--3 cards not in POR
-- Expansions
[831] = { pset={ dup=LHpi.Data.sets[831].cardcount.reg }, failed={ dup=LHpi.Data.sets[831].cardcount.tok }, duppset={ [2]="RUS",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dupfail={ [2]="RUS",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dropped=4 },-- checklists dropped
[829] = { pset={ dup=LHpi.Data.sets[829].cardcount.reg }, failed={ dup=LHpi.Data.sets[829].cardcount.tok }, duppset={ [2]="RUS",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dupfail={ [2]="RUS",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" } },
[825] = { pset={ dup=LHpi.Data.sets[825].cardcount.reg }, failed={ dup=LHpi.Data.sets[825].cardcount.tok }, duppset={ [4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dupfail={ [4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" } },
[818] = { pset={ dup=LHpi.Data.sets[818].cardcount.reg }, failed={ dup=LHpi.Data.sets[818].cardcount.tok }, duppset={ [4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dupfail={ [4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, namereplaced=2 },
[816] = { pset={ dup=LHpi.Data.sets[816].cardcount.reg }, failed={ dup=LHpi.Data.sets[816].cardcount.tok }, duppset={ [4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dupfail={ [4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" } },
[813] = { pset={ dup=LHpi.Data.sets[813].cardcount.reg }, failed={ dup=LHpi.Data.sets[813].cardcount.tok }, duppset={ [4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dupfail={ [4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" } },
[806] = { pset={ dup=LHpi.Data.sets[806].cardcount.reg }, failed={ dup=LHpi.Data.sets[806].cardcount.tok }, duppset={ [4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dupfail={ [4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dropped=44 },
[802] = { pset={ dup=LHpi.Data.sets[802].cardcount.reg }, failed={ dup=LHpi.Data.sets[802].cardcount.tok }, duppset={ [4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dupfail={ [4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dropped=2*22 },
[800] = { pset={ dup=LHpi.Data.sets[800].cardcount.reg }, failed={ dup=LHpi.Data.sets[800].cardcount.tok }, duppset={ [7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dupfail={ [7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dropped=30+14 },--15 Challenge, 7 Hero
[795] = { pset={ dup=LHpi.Data.sets[795].cardcount.reg }, failed={ dup=LHpi.Data.sets[795].cardcount.tok }, duppset={ [3]="GER",[7]="SPA" }, dupfail={ [3]="GER",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" } },
[793] = { pset={ dup=LHpi.Data.sets[793].cardcount.reg }, failed={ dup=LHpi.Data.sets[793].cardcount.tok }, duppset={ [7]="SPA" }, dupfail={ [7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" } },
[791] = { pset={ [7]=LHpi.Data.sets[791].cardcount.reg }, failed={ dup=LHpi.Data.sets[791].cardcount.tok }, dupfail={ [7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" } },
[786] = { pset={ [7]=LHpi.Data.sets[786].cardcount.reg }, failed={ dup=LHpi.Data.sets[786].cardcount.tok }, dupfail= { [7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dropped=22 },--11 inserts
[784] = { failed={ dup=LHpi.Data.sets[784].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dropped=2 },--Double-Faced Card insert
[782] = { failed={ dup=LHpi.Data.sets[782].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH",[10]="ZHT" }, dropped=2 },--Double-Faced Card insert
[776] = { pset={ dup=LHpi.Data.sets[776].cardcount.reg }, failed={ dup=1, [8]=5,[9]=5,[10]=5 }, duppset={ [8]="JPN",[9]="SZH",[10]="ZHT" }, dupfail={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA", }, dropped=8 },--4 inserts
[775] = { pset={ dup=LHpi.Data.sets[775].cardcount.reg }, failed={ dup=1, [8]=6,[9]=6,[10]=6 }, duppset={ [8]="JPN",[9]="SZH",[10]="ZHT" }, dupfail={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA", }, dropped=10 },--5 inserts
[773] = { failed={ dup=1,[8]=LHpi.Data.sets[773].cardcount.tok+1,[9]=LHpi.Data.sets[773].cardcount.tok+1,[10]=LHpi.Data.sets[773].cardcount.tok+1 }, dupfail={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA", }, dropped=10 },--Poison Counter, 10 inserts
[767] = { failed={ dup=LHpi.Data.sets[767].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" }, dropped=10 },--5 inserts
[765] = { failed={ dup=LHpi.Data.sets[765].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" }, dropped=10 },-- 5 inserts
[764] = { failed={ dup=LHpi.Data.sets[764].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" } },
[762] = { failed={ dup=LHpi.Data.sets[762].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" }, dropped=10 },--5 inserts
[758] = { failed={ dup=LHpi.Data.sets[758].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" } },
[756] = { failed={ dup=LHpi.Data.sets[756].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" }, dropped=8 },--4 inserts
[754] = { failed={ dup=LHpi.Data.sets[754].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" }, dropped=2 },--1 insert
[752] = { failed={ dup=LHpi.Data.sets[752].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" }, dropped=16 },-- 8 inserts
[751] = { failed={ dup=LHpi.Data.sets[751].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" }, dropped=6 },-- 3 inserts
[750] = { failed={ dup=LHpi.Data.sets[750].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" } },
[730] = { failed={ dup=LHpi.Data.sets[730].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" } },
[690] = { dropped=602 },--  301 cards non-Timeshifted
[680] = { dropped=242 }, -- 121 cards Timeshifted
[210] = { pset={ [6]=LHpi.Data.sets[210].cardcount.reg-1 }, failed= { [6]=1 } },-- no POR Timmerian Fiends
[190] = { pset={ [6]=LHpi.Data.sets[190].cardcount.reg-1 }, failed= { [6]=1 } },-- no POR Amulet of Quoz
-- special sets
[830] = { pset={ dup=LHpi.Data.sets[830].cardcount.all }, duppset={ [8]="JPN" } },
[828] = { pset={ LHpi.Data.sets[828].cardcount.reg+LHpi.Data.sets[828].cardcount.repl+3,dup=LHpi.Data.sets[828].cardcount.reg+LHpi.Data.sets[828].cardcount.repl }, failed={ 23,dup=26 }, duppset={ [3]="GER",[4]="FRA",[5]="ITA",[7]="SPA",[8]="JPN",[9]="SZH" }, dupfail={ [3]="GER",[4]="FRA",[5]="ITA",[7]="SPA",[8]="JPN",[9]="SZH" } },-- tokens are (23 of 26) doublesided in MKM, (24) single sided in MA
[827] = { failed={ 12 } },-- url contains CP1,CP2,CP3
[826] = { pset={ dup=0 }, failed={ dup=LHpi.Data.sets[826].cardcount.reg }, duppset={ [2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dupfail={ [2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" } },
[824] = { pset={ [8]=LHpi.Data.sets[824].cardcount.both } },
[821] = { dropped=356 },
[820] = { pset={ [8]=LHpi.Data.sets[820].cardcount.both } },
[819] = { failed={ dup=LHpi.Data.sets[819].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" } },
[815] = { failed={ 12 } },-- url contains CP1,CP2,CP3
[814] = { pset={ dup=LHpi.Data.sets[814].cardcount.reg+LHpi.Data.sets[814].cardcount.repl }, failed={ dup=24 }, duppset={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[7]="SPA",[8]="JPN",[9]="SZH" }, dupfail={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[7]="SPA",[8]="JPN",[9]="SZH" } },-- tokens are (24) doublesided in MKM, (36) single sided in MA
[812] = { pset={ [8]=LHpi.Data.sets[812].cardcount.both } },
[811] = { failed={ 12 } },-- url contains CP1,CP2,CP3
[807] = { pset={ dup=LHpi.Data.sets[807].cardcount.reg+LHpi.Data.sets[807].cardcount.nontrad }, failed={ dup=LHpi.Data.sets[807].cardcount.tok }, duppset={ [8]="JPN",[9]="SZH" }, dupfail={ [8]="JPN",[9]="SZH" } },
[805] = { failed={ [8]=LHpi.Data.sets[805].cardcount.tok } },
[804] = { dropped=366 },
[803] = { dropped=534 },
[799] = { failed={ [8]=LHpi.Data.sets[799].cardcount.tok } },
[794] = { failed={ [8]=LHpi.Data.sets[794].cardcount.tok } },
[790] = { failed={ [8]=LHpi.Data.sets[790].cardcount.tok } },
[785] = { failed={ [8]=LHpi.Data.sets[785].cardcount.tok } },
[781] = { pset={ dup=LHpi.Data.sets[781].cardcount.reg }, failed={ dup=LHpi.Data.sets[781].cardcount.tok }, duppset={ [3]="GER",[5]="ITA" }, dupfail={ [3]="GER",[5]="ITA" } },
[777] = { pset={ [5]=LHpi.Data.sets[777].cardcount.reg }, failed={ [5]=LHpi.Data.sets[777].cardcount.tok } },
[772] = { pset={ [5]=LHpi.Data.sets[772].cardcount.reg }, failed={ [5]=LHpi.Data.sets[772].cardcount.tok } },
[766] = { failed={ [8]=LHpi.Data.sets[766].cardcount.tok } },
[755] = { pset={ [8]=LHpi.Data.sets[755].cardcount.both } },
[635] = { pset={ [4]=600-35, [5]=720-31-1, [7]=600 }, failed={ [4]=120+35, [5]=9+4+18+1, [7]=120 } },--ITA missing 9 Plains,4 Mountains,18 Forests,1 Fertile Ground; 35 FRA varnames wrong in MA
[415] = { pset={ [7]=1 }, failed={ [7]=LHpi.Data.sets[415].cardcount.reg-1  } },
[390] = { dropped=188 },
[340] = { dropped=4 },
[310] = { pset={ [6]=49 }, failed={ [6]=LHpi.Data.sets[310].cardcount.reg-49 } },
[260] = { pset={ dup=LHpi.Data.sets[260].cardcount.reg-6 }, failed={ 2,dup=2+6 }, duppset={ [3]="GER",[8]="JPN" }, dupfail={ [3]="GER",[8]="JPN" }, dropped=20 },-- 10 inserts, 2 "Complete Portal Card List"
[225] = { dropped=4 },-- 2 inserts
[201] = { pset={ [5]=69 } },
-- Promos
[53]  = { dropped=444 },
[52]  = { pset={ [3]=30 }, namereplaced=21-2, dropped=708 },-- GER SOI not yet in Ma
[50]  = { pset={ [2]=5,[3]=27,[4]=1,[6]=1,[7]=5;[8]=4 }, failed={ [2]=23,[3]=1,[4]=27,[6]=27,[7]=23;[8]=26 }, dropped=42 },
[45]  = { pset={ 0,[8]=LHpi.Data.sets[45].cardcount.reg-1 } },-- "Jaya Ballard, Task Mage" missing
[43]  = { dropped=26 },
[42]  = { dropped=130 },
--[41]  = { failed={ 1 } },-- "Mishra's Toy Workshop" not in MA
[40]  = { pset={ LHpi.Data.sets[40].cardcount.all,[3]=5,[8]=24-18 }, failed={ 1,[3]=173,[8]=172 }, dropped=24 },--Mad Auntie only JPN; JPN: "Faerie Conclave" ENG is SUM, 17 others ENG are GTW 
[34]  = { dropped=66 },
[33]  = { pset={ 1 }, dropped=26 },-- all but "Balduvian Horde" are one-of-a-kind
[32]  = { pset={ LHpi.Data.sets[32].cardcount.reg,[8]=1 }, failed={ [8]=LHpi.Data.sets[32].cardcount.reg-1 }, dropped=28 },
[31]  = { dropped=28 },
[30]  = { pset={ [2]=23,[3]=55,[5]=1,[7]=6 }, failed={ 3,[2]=171,[3]=139,[5]=193,[7]=188 } },-- "Blighted Fen","Sylvan Scrying","Goblin Warchief (2016)" not yet in MA
--[27]  = { failed={ dup=1 }, dupfail= { "ENG" }, dropped=48 },-- "Magic Guru" not in MA
[26]  = { pset={ [2]=17,[3]=24,[7]=4 }, failed={ [2]=LHpi.Data.sets[26].cardcount.all-17,[3]=LHpi.Data.sets[26].cardcount.all-24,[7]=LHpi.Data.sets[26].cardcount.all-4 }, dropped=1580 },
[25]  = { pset={ LHpi.Data.sets[25].cardcount.all,[3]=2,[17]=1 }, failed={ 3+1,[3]=LHpi.Data.sets[25].cardcount.both } },-- cant distinguish "Wolf│Open New Worlds"/"Wolf│Make a Positive Mark"; "Shardless Agent","Temporal Manipulation","Rishadan Port" not yet in MA
[23]  = { pset={ [3]=39-2,[4]=12,[5]=11,[7]=11,[8]=4 }, failed={ [3]=27,[4]=52,[5]=53,[7]=53,[8]=60 }, dropped=6 },-- "Fling (50 DCI)","Sylvan Ranger (51 DCI)" are version "1" in ENG, but "" in GER
[22]  = { pset={ [2]=77,[3]=50,[7]=14,[12]=1,[13]=1,[14]=1,[15]=1,[16]=1 }, failed={ 1,[2]=183,[3]=210,[7]=246 }, dropped=1588 },-- BFZ(69),OGW,ISD not yet in MA, Laquatus's Champion only RUS
[21]  = { pset={ [2]=14,[3]=29,[4]=1,[5]=1,[7]=7,[8]=3-2 }, failed={ 1,[2]=46,[3]=31,[4]=59,[5]=59,[7]=53,[8]=59 }, dropped=1978 },-- "Shivan Dragon"  (Release Promos) only RUS; JPN Treetop Village and Zoetic Cavern missing (ENG:Treetop is in SUM, Cavern is GTW)
[15]  = { pset={ [3]=1,[4]=2,[5]=3,[7]=2,[8]=2 }, failed={ 11,[3]=25,[4]=24,[5]=23,[7]=24,[8]=25 }, dropped=264 },--not in MA: 5 SanDiego'15,6 SanDiego'14 ; 5 SanDiego'13,2 oversized Caravan Tours
[10]  = { pset= { [8]=11 }, failed={ 8,[8]=22 }, dropped=2 },
[9]   = { pset={ [2]=7,[3]=12,[4]=3,[7]=3 }, failed={ [2]=8,[3]=3,[4]=12,[7]=12 }, dropped=188 },-- not all nonENG in MA
[8]	  = { pset={ [5]=1,[8]=3 }, failed={ [5]=12,[8]=12 }, dropped=64 },
[7]   = { pset={ [3]=1,[8]=4-2 }, failed={ 4 }, dropped=220 },-- fail 4 Lifecounter cards; MA has JPN 4 Gotta Magazine, GER 1 Kartefakt
[6]   = { pset={ [8]=7 }, dropped=228 },
[5]   = { pset={ [4]=5,[5]=3,[6]=2,[7]=5 }, failed={ [4]=1,[5]=3,[6]=4,[7]=1 }, dropped=26 },
[2]   = { dropped=24 },

	}--end table site.expected
	-- I'm too lazy to fill in site.expected myself, let the script do it ;-)
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