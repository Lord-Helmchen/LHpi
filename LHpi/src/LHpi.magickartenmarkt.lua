--*- coding: utf-8 -*-
--[[- LHpi magiccardmarket.eu sitescript 
Price import script for Magic Album
uses and needs LHpi library
to import card pricing from www.magiccardmarket.eu.

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
migrate to other sitescripts:
*Initialize()
*site.priceTypes Table and local global option

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

--- choose between available price types; defaults to 5 ("AVG" prices).
-- see table site.priceTypes for available options
-- @field #number priceToUse
local priceToUse=5--use AVG

--local mkmtokenfile = "mkmtokens.example"
--local mkmtokenfile = "mkmtokens.sandbox"
local mkmtokenfile = "mkmtokens.DarkHelmet"

--  Don't change anything below this line unless you know what you're doing :-) --

--- choose how the site sends the requested data.
-- mkm api offers json and xml format. Only json parsing is implemented yet,
-- and we need json anyways to read the mkm token file :)
-- @field #string responseFormat	"json" or "xml"
local responseFormat = "json"

---
local mkmexample = false
local widgetonly = true
local sandbox = false

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
OFFLINE = true

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
-- @field [parent=#global] #string libver
libver = "2.14"
--- revision of the LHpi library datafile to use
-- @field [parent=#global] #string dataver
dataver = "5"
--- sitescript revision number
-- @field [parent=#global] string scriptver
scriptver = "2"
--- should be similar to the script's filename. Used for loging and savepath.
-- @field [parent=#global] #string scriptname
scriptname = "LHpi.magickartenmarkt-v".. libver .. "." .. dataver .. "." .. scriptver .. ".lua"
--- savepath for OFFLINE (read) and SAVEHTML (write). must point to an existing directory relative to MA's root.
-- set by LHpi lib unless specified here.
-- @field [parent=#global] #string savepath
--savepath = "Prices\\" .. string.gsub( scriptname , "%-v%d+%.%d+%.lua$" , "" ) .. "\\"

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
 @field [parent=#site] #string regex
]]
site.regex = '{"idProduct".-"countFoils":%d+}'

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
	site.Initialize( scriptmode ) -- keep site-specific stuff out of ImportPrice
	LHpi.DoImport (importfoil , importlangs , importsets)
	ma.Log( "End of Lua script " .. scriptname )
end -- function ImportPrice

--[[- prepare script
 Do stuff here that needs to be done between loading the Library and calling LHpi.DoImport.
 At this point, LHpi's functions are avalable, but default values for missing fields have not yet been set.
 
 for LHpi.mkm, we need to configure and prepare the oauth client.
@param #table mode { #boolean listsets, boolean checksets, ... }
	-- nil if called by Magic Album
	-- testOAuth	tests the OAuth implementation
	-- checksets	compares site.sets with setlist from dummyMA
	-- getsets		fetches available expansions from server and saves a site.sets template.
 @function [parent=#site] Initialize
]]
function site.Initialize( mode )
	if not require then
		LHpi.Log("trying to work around Magic Album lua sandbox limitations...")
		--emulate require(modname) using dofile; only works for lua files, not dlls.
		local packagePath = 'Prices\\lib\\ext\\'
		require = function (fname)
			local donefile
			donefile = dofile( packagePath .. fname .. ".lua" )
			return donefile
		end-- function require
	else
		package.path = 'Prices\\lib\\ext\\?.lua;' .. package.path
		package.cpath= 'Prices\\lib\\bin\\?.dll;' .. package.cpath
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
	if OFFLINE then
		--skip OAuth preparation
		--when launched from ma, dll loading is not possible.
	else 
		OAuth = require "OAuth"
		---@field [parent=#site] #table oauth
		site.oauth = {}
		site.oauth.client, site.oauth.params = site.PrepareOAuth()
	end
	if mode.testOAuth then
		site.OAuthTest( site.oauth.params )
	end
	if mode.checksets then
		site.CompareSiteSets()
	end
	if mode.getsets then
		local expansionList = site.FetchExpansionList()
		site.ParseExpansions(expansionList )
	end
	--create an empty file to hold missorted cards
	-- that is, the mkm expansion does not match the MA set
		LHpi.Log("site.sets = {",0,"missorted."..responseFormat,0 )
		site.settweak = site.settweak or {}
	--error("break")
end


--[[- sets all oauth raleted options and prepares the oauth-client.
ideally, tokens/secrets should be read from a file instead of being hardcoded.

 @function [parent=#site] PrepareOAuth
 @return client			OAuth instance
 @return #table params	oauth parameters
]]
function site.PrepareOAuth()
	local tokens = "Prices\\lib\\" .. mkmtokenfile
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
	if mkmexample then
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

	LHpi.Log("OAuth prepared")
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
function site.FetchSourceDataFromOAuth( url, details )
	url = "https://" .. url
	if DEBUG then
		print("site.FetchSourceDataFromOAuth started for url " .. url )
		print("BuildRequest:")
		local headers, arguments, post_body = site.oauth.client:BuildRequest( "GET", url )
		print("headers=", LHpi.Tostring(headers))
		print("arguments=", LHpi.Tostring(arguments))
		print("post_body=", LHpi.Tostring(post_body))
		--error("stopped before actually contacting the server")
		print("PerformRequest:")
	end
	local code, headers, status, body = site.oauth.client:PerformRequest( "GET", url )
	if code == 200 or code == 204 then
	elseif code == 404 then
		print("status=", LHpi.Tostring(status))
	else
		LHpi.Log(("headers=".. LHpi.Tostring(headers)))
		LHpi.Log(("arguments=".. LHpi.Tostring(arguments)))
		LHpi.Log(("post_body=".. LHpi.Tostring(post_body)))
		LHpi.Log(("code=".. LHpi.Tostring(code)))
		LHpi.Log(("BuildRequest:"))
		local headers, arguments, post_body = site.oauth.client:BuildRequest( "GET", url )
		LHpi.Log(("headers=".. LHpi.Tostring(headers)))
		LHpi.Log(("status=".. LHpi.Tostring(status)))
		LHpi.Log(("body=".. LHpi.Tostring(body)))
		--error (LHpi.Tostring(statusline))
		print("status=", LHpi.Tostring(status))
	end
		return body, status
end--function site.FetchSourceDataFromOAuth

--[[- fetch list of expansions from mkmapi
 @function [parent=#site] FetchExpansionList
 @return #string list		List of expansions, in xml or json format
]]
function site.FetchExpansionList()
	local xmldata
	local url = "www.mkmapi.eu/ws/v1.1"
 	if sandbox then
 		url = "sandbox.mkmapi.eu/ws/v1.1"
 	end
	url = url .. "/output." .. (responseFormat or "json") .. "/expansion/1"
	local urldetails={ oauth=true }
	xmldata = LHpi.GetSourceData ( url , urldetails )
	return xmldata
end--function

--[[- Parse list of expansions and prepare a site.sets template.
Still leaves much to do, but it helped :)
 @function [parent=#site] ParseExpansionList
 @param #string list		List of expansions, as returned from site.FetchExpansionList
 @return nil, but saves to file
]]
function site.ParseExpansions(list)
	if not dummy then error("ParseExpansions needs to be run from dummyMA!") end
	local file = "setsTemplate.txt"
	local expansions
	if responseFormat == "json" then
		expansions = Json.decode(list).expansion
	else
		error("nothing here for xml yet")
	end
	local setcats = { "coresets", "expansionsets", "specialsets", "promosets" }
	LHpi.Log("site.sets = {",0,file,0 )
	for _,setcat in ipairs(setcats) do
		local setNames = dummy[setcat]
		local revSets = {}
		for id,name in pairs(setNames) do
			revSets[name] = id
		end--for id,name
		local sets,sortSets = {},{}
		for i,expansion in pairs(expansions) do
			if revSets[expansion.name] then
				local id = revSets[expansion.name]
				sets[id] = { id = id , name = expansion.name, mkmId=expansion.idExpansion, url=expansion.name }
				table.insert(sortSets,id)
				expansions[i]=nil
			end--if revSets
		end--for i,expansion
		table.sort(sortSets, function(a, b) return a > b end)
		LHpi.Log("-- ".. setcat ,0,file)
		for i,sid in ipairs(sortSets) do
			local string = string.format("[%i]={id=%3i, lang={ true,[2]=true,[3]=true,[4]=true,[5]=true,[6]=true,[7]=true,[8]=true,[9]=true,[10]=true,[11]=true }, fruc={ true }, url=%q},--%s",sid,sid,sets[sid].url,sets[sid].name )
			print(string)
			LHpi.Log(string, 0,file )
		end--for i,sid
	end--for setcat
		LHpi.Log("-- unknown" ,0,file)
		for i,expansion in pairs(expansions) do
			local url=expansion.name
			local string = string.format("[%i]={id=%3i, lang={ true,[2]=true,[3]=true,[4]=true,[5]=true,[6]=true,[7]=true,[8]=true,[9]=true,[10]=true,[11]=true }, fruc={ true }, url=%q},--%s",0,0,url,expansion.name )
			print(string)
			LHpi.Log(string, 0,file )
		end--for i,sid
		LHpi.Log("-- catchall" ,0,file)
		local urls="{ "
		for i,expansion in pairs(expansions) do
			urls = urls .. "\"" .. expansion.name .. "\","
		end--for i,sid
		urls = urls .. "},"
		local string = string.format("[%i]={id=%3i, lang={ true,[2]=true,[3]=true,[4]=true,[5]=true,[6]=true,[7]=true,[8]=true,[9]=true,[10]=true,[11]=true }, fruc={ true }, url=%s},--%s",999,999,urls,"catchall")
		print(string)
		LHpi.Log(string, 0,file )
	LHpi.Log("\t}\n--end table site.sets",0,file)
end

--[[- compare site.sets with dummy.coresets, dummy.expansionsets, dummy.specialsets, dummy.promosets.
finds sets from dummy's lists that are not in site.sets.

 @function [parent=#site] CompareSiteSets
]]
function site.CompareSiteSets()
	if not dummy then error("CompareSiteSetsneeds to be run from dummyMA!") end
	local dummySets = dummy.mergetables ( dummy.coresets, dummy.expansionsets, dummy.specialsets, dummy.promosets )
	local missing = {}
	for sid,name in pairs(dummySets) do
		if site.sets[sid] then
			--print(string.format("found %3i : %q",sid,name) )
		else
			table.insert(missing,{ id=sid, name=name})
		end
	end
	print(#missing .. " sets from dummy missing in site.sets:")
	for i,set in pairs(missing) do
		print(string.format("[%3i] = %q;",set.id,set.name) )
	end
end--function CompareSiteSets


--[[- test OAuth implementation
 @function [parent=#site] OAuthTest
 @param #table params
]]
function site.OAuthTest( params )
	print("site.OAuthTest started")
	print(LHpi.Tostring(params))

	-- "manual" Authorization header construction
	local Crypto = require "crypto"
	local Base64 = require "base64"
	--
	-- Like URL-encoding, but following OAuth's specific semantics
	local function oauth_encode(val)
		return val:gsub('[^-._~a-zA-Z0-9]', function(letter)
			return string.format("%%%02x", letter:byte()):upper()
		end)
	end

	params.oauth_timestamp = params.oauth_timestamp or tostring(os.time())
	params.oauth_nonce = params.oauth_nonce or Crypto.hmac.digest("sha1", tostring(math.random()) .. "random" .. tostring(os.time()), "keyyyy")

	local baseString = "GET&" .. oauth_encode( params.url ) .. "&"
	print(baseString)
	local paramString = "oauth_consumer_key=" .. oauth_encode(params.oauth_consumer_key) .. "&"
					..	"oauth_nonce=" .. oauth_encode(params.oauth_nonce) .. "&"
					..	"oauth_signature_method=" .. oauth_encode(params.oauth_signature_method) .. "&"
					..	"oauth_timestamp=" .. oauth_encode(params.oauth_timestamp) .. "&"
					..	"oauth_token=" .. oauth_encode(params.oauth_token) .. "&"
					..	"oauth_version=" .. oauth_encode(params.oauth_version) .. ""
	paramString = oauth_encode(paramString)
	print(paramString)
	baseString = baseString .. paramString
	print(baseString)
	local signingKey = oauth_encode(params.appSecret) .. "&" .. oauth_encode(params.accessTokenSecret)
	print(signingKey)--ok until here
	local rawSignature = Crypto.hmac.digest("sha1", baseString, signingKey, true)
	print(rawSignature)
	local signature = Base64.encode( rawSignature )
	print(signature)
	local authString = "Authorization: Oauth "
		..	"realm=\"" .. oauth_encode(params.url) .. "\", "
		..	"oauth_consumer_key=\"" .. oauth_encode(params.oauth_consumer_key) .. "\", "
		..	"oauth_nonce=\"" .. oauth_encode(params.oauth_nonce) .. "\", "
		..	"oauth_signature_method=\"" .. oauth_encode(params.oauth_signature_method) .. "\", "
		..	"oauth_timestamp=\"" .. oauth_encode(params.oauth_timestamp) .. "\", "
		..	"oauth_token=\"" .. oauth_encode(params.oauth_token) .. "\", "
		..	"oauth_version=\"" .. oauth_encode(params.oauth_version) .. "\", "
		..  "oauth_signature=\"" .. signature .. "\""
	print(authString)

	-- OAuth library use
	local OAuth = require "OAuth"
	--print(LHpi.Tostring(params))
	local args
	if params.oauth_timestamp and params.oauth_nonce then
		args = { timestamp = params.oauth_timestamp, nonce = params.oauth_nonce }
		params.oauth_timestamp = nil
		params.oauth_nonce = nil
	end
	local client = OAuth.new(params.oauth_consumer_key, params.appSecret, {} )
	--client.SetToken( client, params.oauth_token )
	client:SetToken( params.oauth_token )
	--client.SetTokenSecret(client, params.accessTokenSecret)
	client:SetTokenSecret( params.accessTokenSecret)
	print("BuildRequest:")
	--local headers, arguments, post_body = client.BuildRequest( client, "GET", params.url, args )
	local headers, arguments, post_body = client:BuildRequest( "GET", params.url, args )
	print("headers=", LHpi.Tostring(headers))
	print("arguments=", LHpi.Tostring(arguments))
	print("post_body=", LHpi.Tostring(post_body))

	error("stopped before actually contacting the server")
	print("PerformRequest:")
	--local response_code, response_headers, response_status_line, response_body = client.PerformRequest( client, "GET", params.url, args )
	local response_code, response_headers, response_status_line, response_body = client.PerformRequest( "GET", params.url, args )
	print("code=" .. LHpi.Tostring(response_code))
	print("headers=", LHpi.Tostring(response_headers))
	print("status_line=", LHpi.Tostring(response_status_line))
	print("body=", LHpi.Tostring(response_body))
end--function OAuthTest

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
	-- Only build the baseURL and set oauth flag. This way, we keep the urls human-readably and non-random
	-- so we can store the files and retrieve them later in OFFLINE mode.
	-- LHpi.GetSourceData calls site.FetchSourceDataFromOAuth to construct, sign and send/receive OAuth requests, triggered by the flag.
	local container = {}
	local url = "www.mkmapi.eu/ws/v1.1"
	if sandbox then
		url = "sandbox.mkmapi.eu/ws/v1.1"
	end--if sandbox
	url = url .. "/output." .. (responseFormat or "json") .. "/expansion/1"
	local urls
	if "table" == type(site.sets[setid].url) then
		urls = site.sets[setid].url
	else
		urls = { site.sets[setid].url }
	end--if "table"
	for _i,seturl in pairs(urls) do
		container[url .. "/" .. seturl] = { oauth=true }
	end--for _i,seturl
	return container
end -- function site.BuildUrl

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
	local priceType = site.priceTypes[priceToUse] or "AVG"
	local product
	if responseFormat == "json" then
		product = Json.decode(foundstring)
	else
		error("nothing here for xml yet")
	end
	--print(LHpi.Tostring(product.name))
	local newCard = 	{ names = {}, lang={}, pluginData={}, foil=false }
	local newFoilCard = { names = {}, lang={}, pluginData={}, foil=true  }
--	local regprice  = string.gsub( product.priceGuide[priceType] , "[,.]" , "" ) --nonfoil price, use AVG by default
--	local foilprice = string.gsub( product.priceGuide["LOWFOIL"] , "[,.]" , "" ) --foil price
	local regprice  = tonumber(product.priceGuide[priceType])*100 --nonfoil price, use AVG by default
	local foilprice = tonumber(product.priceGuide["LOWFOIL"])*100 --foil price
	-- can just set names[1] to productName[1].productName, as productName reflects mkm ui langs, not card langs		
	newCard.names[1] = product.name["1"].productName
	newFoilCard.names[1] = product.name["1"].productName
	--for i,prodName in pairs(product.name) do
	--	local langid = site.mapLangs[prodName.languageName] or error("unknown MKM language")
	--	newCard.names[langid] = prodName.productName
	--	newFoilCard.names[langid] = prodName.productName
	--end--for i,prodName
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
	if DEBUG then
		LHpi.Log( "site.BCDpluginPre got " .. LHpi.Tostring( card ) .. " from set " .. setid , 2 )
	end
	
	if "Land" == card.pluginData.rarity then
		if card.pluginData.collectNr then
			card.name = string.gsub( card.name,"%(Version %d+%)","("..card.pluginData.collectNr..")" )
		else
			card.name = string.gsub( card.name,"%(Version (%d+)%)","(%1)" )
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
		or setid == 21
		then
			card.name = string.gsub( card.name, "%(.+%)", "" )
		end
	end--if "Land" else "Token"
	
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
	elseif setid ==  390 then -- Starter 1999
		if card.pluginData.set == "Oversized 6x9 Promos" then
			if card.name == "Thorn Elemental" then
				card.name = card.name .. " (oversized)"
			else
				card.name = card.name .. " (DROP not Starter 1999)"
			end
		end
	elseif setid == 201 then
		if card.pluginData.set == "Renaissance" then
			card.lang = { [3]="GER", [4]="FRA" }
		elseif card.pluginData.set == "Rinascimento" then
			card.lang = { [5]="ITA" }
		end
	elseif setid == 140 then
		if card.pluginData.set == "Revised" then
			card.lang = { [1]="ENG" }
		elseif card.pluginData.set == "Foreign White Bordered" then
			card.lang = { [3]="GER", [4]="FRA", [5]="ITA" }
		end
	elseif setid == 43 then
		if card.name ~= "Underworld Dreams" then
			card.name = card.name .. " (DROP not Two-Headed Giant Promo)"
		end
	elseif setid == 42 then
		if card.name == "Faerie Conclave"
		or card.name == "Treetop Village"
		then
		else
			card.name = card.name .. " (DROP not Summer of Magic Promo)"
		end
	elseif setid == 40 then
		if card.pluginData.set == "Oversized 6x9 Promos" then
			card.name = card.name .. " (oversized)"
		end
	elseif setid == 33 then -- Championships Prizes
		if card.pluginData.set == "DCI Promos" then
			if card.name == "Balduvian Horde"
			or card.name == "Geist of Saint Traft"
			or card.name == "Vengevine"
			then
			else
				card.name = card.name .. " (DROP not Championships Prizes)"
			end
		elseif card.pluginData == "Promos" then
			if card.name ~= "Geist of Saint Traft" then
				card.name = card.name .. "(DROP not Championship Prizes)"
			end
		end
	elseif setid == 32 then
		if card.name == "Ajani Goldmane"
		or card.name == "Avatar of Woe"
		or card.name == "Eternal Dragon"
		or card.name == "Mirari's Wake"
		or card.name == "Treva, the Renewer"
		then
		else
			card.name = card.name .. " (DROP not Pro Tour Promo)"
		end
	elseif setid == 27 then
		if card.pluginData.set == "APAC Lands" then
			card.name = card.name .. " (APAC)"
		elseif card.pluginData.set == "Euro Lands" then
			card.name = card.name .. " (Euro)"
		elseif card.pluginData.set == "Guru Lands" then
			card.name = card.name .. " (Guru)"
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
	elseif setid == 25 then
		if card.name == "Elesh Norn, Grand Cenobite" then
			card.lang = { [17]="PHY" }
		end
	elseif setid == 22 then
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
				card.nae = card.name .. " (oversized)"
			else
				card.name = card.name .. " (DROP not Prerelease Promos)"
			end
		elseif card.pluginData.set == "DCI Promos" then
			if card.name ~= "Griselbrand" then
				card.name = card.name .. " (DROP not Prerelease Promos)"
			end
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
		end
	elseif setid == 21  then -- Release Promos
		if card.pluginData.set == "Oversized 6x9 Promos" then
			if card.name == "Incoming!" then
				--card.name = card.name .. " (oversized)"
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
		end
	elseif setid == 15 then
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
		end
	elseif setid == 10 then
		if card.pluginData.set == "Junior Series Promos" then
			card.lang = { "ENG" }
			card.name = card.name .. " (E)"
		elseif card.pluginData.set == "Junior Super Series Promos" then
			card.lang = { "ENG" }
			card.name = card.name .. " (J)"	-- most are variant "" -> -"(J)" in namereplace
		elseif card.pluginData.set == "Japan Junior Tournament Promos" then
			card.lang = { [8]="JPN" }
			card.name = card.name .. " (jjtp)"
		elseif card.pluginData.set == "Magic Scholarship Series Promos" then
			card.lang = { "ENG" }
			card.name = card.name .. " (J)"
		end
	elseif setid == 9 then
		if card.pluginData.set == "Oversized 6x9 Promos" then
			if card.name ~= "Aswan Jaguar" then
				card.name = card.name .. " (DROP not Video Game Promo)"
			end
		end
	elseif setid == 8 then -- Stored Promos
		if card.pluginData.set == "Walmart Promos" then
			card.lang = { "ENG" }
		end
		if card.pluginData.set == "DCI Promos" then
			if card.name == "Relentless Rats" then
				card.lang = { [5]="ITA" }
			elseif card.name ~= "Serra Angel" then
				card.name = card.name .. " (DROP not )"
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
		end
	elseif setid == 6 then
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
		end
	elseif setid == 5 then
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
	elseif setid == 2 then
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
	if DEBUG then
		LHpi.Log( "site.BCDpluginPost got " .. LHpi.Tostring( card ) .. " from set " .. setid , 2 )
	end
	--TODO migrate settweak to library?
	if site.settweak[setid] and site.settweak[setid][card.name] then
		if LOGSETTWEAK or DEBUG then
			LHpi.Log( string.format( "settweak saved %s with new set %s" ,card.name, site.settweak[setid][card.name] ), 1 )
		end
		card.name = card.name .. "(DROP settweaked to " .. site.settweak[setid][card.name] .. ")"
		settweaked=1
		--TODO save to file instead of dropping
	end -- site.settweak[setid]

	
	card.pluginData=nil
	return card
end -- function site.BCDpluginPost

-------------------------------------------------------------------------------------------------------------
-- tables
-------------------------------------------------------------------------------------------------------------

--[[- Define the six price entries. This table is unique to this sitescript.
 @field [parent=#site] #table priceTypes	{ #number priceId = #string priceName, ... }
]]
site.priceTypes = {	--Price guide entity
	[1] = "SELL",	--Average price of articles ever sold of this product
	[2] = "LOW",	--Current lowest non-foil price (all conditions)
	[3] = "LOWEX+",	--Current lowest non-foil price (condition EX and better)
	[4] = "LOWFOIL",--Current lowest foil price
	[5] = "AVG",	--Current average non-foil price of all available articles of this product
	[6] = "TREND",	--Trend of AVG 
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
	[12] = { id=12, url="" },--Hebrew		-- Only 1 card, in [22] Prerelease Promos
	[13] = { id=13, url="" },--Arabic		-- Only 1 card, in [22] Prerelease Promos
	[14] = { id=14, url="" },--Latin		-- Only 1 card, in [22] Prerelease Promos
	[15] = { id=15, url="" },--Sanskrit		-- Only 1 card, in [22] Prerelease Promos
	[16] = { id=16, url="" },--Ancient Greek-- Only 1 card, in [22] Prerelease Promos
	[17] = { id=17, url="" },--Phyrexian	-- Only 1 card, in [25] Judge Gift Cards
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
[813]={id=813, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Khans%20of%20Tarkir"},--Khans of Tarkir
[806]={id=806, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Journey%20into%20Nyx"},--Journey into Nyx
[802]={id=802, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Born%20of%20the%20Gods"},--Born of the Gods
[800]={id=800, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Theros"},--Theros
[795]={id=795, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Dragon%27s%20Maze"},--Dragon's Maze
[793]={id=793, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Gatecrash"},--Gatecrash
[791]={id=791, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Return%20to%20Ravnica"},--Return to Ravnica
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
--[0]={id=  0, lang=all, fruc={ true }, url="Duel%20Decks:%20Anthology"},--Duel Decks: Anthology
[814]={id=814, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Commander%202014"},--Commander 2014
[812]={id=812, lang={ "ENG",[8]="JPN" }, fruc={ true }, url="Duel%20Decks:%20Speed%20vs.%20Cunning"},--Duel Decks: Speed vs. Cunning
[811]={id=811, lang={ "ENG" }, fruc={ true }, url="M15%20Clash%20Pack"},--M15 Clash Pack
[810]={id=810, lang={ "ENG" }, fruc={ true }, url="Modern%20Event%20Deck%202014"},--Modern Event Deck 2014
[809]={id=809, lang={ "ENG" }, fruc={ true }, url="From%20the%20Vault:%20Annihilation"},--From the Vault: Annihilation
[807]={id=807, lang={ "ENG",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Conspiracy"},--Conspiracy
[805]={id=805, lang={ "ENG" }, fruc={ true }, url="Duel%20Decks:%20Jace%20vs.%20Vraska"},--Duel Decks: Jace vs. Vraska
[804] = nil, -- "Challenge Deck: Battle the Horde" not available as singles 
[803] = nil, -- "Challenge Deck: Face the Hydra" not available as singles
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
[766]={id=766, lang={ "ENG" }, fruc={ true }, url="Duel%20Decks:%20Phyrexia%20vs.%20The%20Coalition"},--Duel Decks: Phyrexia vs. The Coalition
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
--TODO [635] Data.variants, site.namereplace
--[635]={id=635, lang={ [4]="FRA",[5]="ITA",[7]="SPA" }, fruc={ true }, url="Salvat-Hachette"},--Salvat Magic Encyclopedia
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
[235] =nil, -- Multiverse Gift Box not distinguished from normal [240] Visions cards
[320]={id=320, lang={ "ENG" }, fruc={ true }, url="Unglued"},--Unglued
[310]={id=310, lang={ "ENG",[3]="GER",[5]="ITA",[6]="POR",[8]="JPN" }, fruc={ true }, url="Portal%20Second%20Age"},--Portal Second Age
[260]={id=260, lang={ "ENG",[3]="GER",[8]="JPN" }, fruc={ true }, url="Portal"},--Portal
[225]={id=225, lang={ "ENG",[3]="GER",[4]="FRA",[7]="SPA" }, fruc={ true }, url="Introductory%20Two-Player%20Set"},--Introductory Two-Player Set
[201]={id=201, lang={ [3]="GER", [4]="FRA", [5]="ITA" }, fruc={ true }, url={ "Renaissance", "Rinascimento" } },--Renaissance
[200]={id=200, lang={ "ENG" }, fruc={ true }, url="Chronicles"},--Chronicles
[106]={id=106, lang={ "ENG" }, fruc={ true }, url="International%20Edition"},--Collectors' Edition International
[105]={id=105, lang={ "ENG" }, fruc={ true }, url="Collectors%27%20Edition"},--Collectors' Edition
[70] ={id= 70, lang={ "ENG" }, fruc={ true }, url="Vanguard"},--Vanguard
[69] ={id= 69, lang={ "ENG" }, fruc={ true }, url="Oversized%20Box%20Toppers"},--Oversized Box Toppers
-- promosets
[50] ={id= 50, lang={ "ENG",[3]="GER",[4]="FRA",[6]="POR",[7]="SPA",[8]="JPN" }, fruc={ true }, url="Buy%20a%20Box%20Promos"},--Buy a Box Promos
[45] ={id= 45, lang={ [8]="JPN" }, fruc={ true }, url="Magic%20Premiere%20Shop%20Promos"},--Magic Premiere Shop Promos
[43] ={id= 43, lang=all, fruc={ true }, url="DCI%20Promos"}, -- Two-Headed Giant Promos: in DCI Promos
[42] ={id= 42, lang=all, fruc={ true }, url="Gateway%20Promos"}, -- Summer of Magic Promos: in Gateway Promos
[41] ={id= 41, lang={ "ENG" }, fruc={ true }, url="Happy%20Holidays%20Promos"},--Happy Holidays Promos
[40] ={id= 40, lang={ "ENG",[3]="GER",[8]="JPN" }, fruc={ true }, url={ --Arena/Colosseo Leagues Promos
											"Arena%20League%20Promos",--Arena League Promos
											"Oversized%206x9%20Promos",--Oversized 6x9 Promos
											} },
[33] ={id= 33, lang=all, fruc={ true }, url={ -- Championships Prizes
											"DCI%20Promos",--DCI Promos
											"Promos", -- "Geist of Saint Traft"
											} },
[32] ={id= 32, lang={ "ENG",[8]="JPN" }, fruc={ true } , url="DCI%20Promos"}, -- Pro Tour Promos in DCI Promos
[31] ={id= 31, lang=all, fruc={ true }, url={ -- Grand Prix Promos
											"DCI%20Promos",--DCI Promos
											} },
[30] ={id= 30, lang={ "ENG",[2]="RUS",[3]="GER",[5]="ITA",[7]="SPA" }, fruc={ true }, url="Friday%20Night%20Magic%20Promos"},--Friday Night Magic Promos
[27] ={id= 27, lang=all, fruc={ true }, url={ "APAC%20Lands", "Guru%20Lands", "Euro%20Lands" } },--Alternate Art Lands: APAC Lands, Guru Lands, Euro Lands
[26] ={id= 26, lang={ "ENG",[2]="RUS",[3]="GER" }, fruc={ true }, url={ -- "Magic Game Day"
											"Game%20Day%20Promos", -- Game Day Promos
											"Gateway%20Promos", -- "Naya Sojourners"
											"Release%20Promos", -- "Reya Dawnbringer"
											"Theros", -- "The Slayer"
											"Born%20of%20the%20Gods", -- "The Vanquisher"
											"Journey%20into%20Nyx", -- "The Champion"
											} },
[25] ={id= 25, lang={ "ENG",[17]="PHY" }, fruc={ true }, url="Judge%20Rewards%20Promos"},--Judge Rewards Promos
[24] ={id= 24, lang={ "ENG" }, fruc={ true }, url="Champs%20&%20States%20Promos"},--Champs & States Promos
[23] ={id= 23, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[7]="SPA",[8]="JPN" }, fruc={ true }, url="Gateway%20Promos"},--Gateway Promos
[22] ={id= 22, lang={ "ENG",[2]="RUS",[3]="GER",[7]="SPA",[12]="HEB",[13]="ARA",[14]="LAT",[15]="SAN",[16]="GRC" }, fruc={ true }, url={ --Prerelease Promos
											"Prerelease%20Promos", -- Prerelease Promos
											"Oversized%206x9%20Promos", -- Oversized 6x9 Promos "Garruk the Slayer (oversized)"
											"DCI%20Promos", -- DCI Promos "Griselbrand"
											"Theros" , -- Theros (5 Hero Cards)
											"Born%20of%20the%20Gods", -- Born of the Gods (5 Hero Cards)
											"Journey%20into%20Nyx", -- Journey into Nyx (5 Hero Cards)
											} },
[21] ={id= 21, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[7]="SPA",[8]="JPN" }, fruc={ true }, url={ --Release & Launch Party Promos
											"Release%20Promos", -- Release Promos
											"Oversized%206x9%20Promos", -- "Incoming! (oversized)"
											"Prerelease%20Promos", -- "Lord of Shatterskull Pass"
											"Theros" , -- "The Harvester"
											"Born%20of%20the%20Gods", -- "The Explorer"
											"Journey%20into%20Nyx", -- "The Destined"
											} },
[20] ={id= 20, lang={ "ENG" }, fruc={ true }, url="Player%20Rewards%20Promos"},--Player Rewards Promos
[15]= {id= 15, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[7]="SPA",[8]="JPN" }, fruc={ true }, url={-- Convention Promos
											"San%20Diego%20Comic-Con%202013%20Promos", --San Diego Comic-Con 2013 Promos
											"San%20Diego%20Comic-Con%202014%20Promos",--San Diego Comic-Con 2014 Promos
											"Oversized%206x9%20Promos", -- "Serra Angel (oversized)","Hurloon Minotaur (oversized)"
											"DCI%20Promos", -- 6 cards
											} },
[12] ={id= 12, lang={ [8]="JPN" }, fruc={ true }, url="Hobby%20Japan%20Commemorative%20Promos"},--Hobby Japan Commemorative Promos
[11] ={id= 11, lang={ [8]="JPN" }, fruc={ true }, url={ -- Redemption Program Cards
											} },
[10] ={id= 10, lang={ "ENG",[8]="JPN" }, fruc={ true }, url={
											"Junior%20Series%20Promos",--Junior Series Promos
											"Junior%20Super%20Series%20Promos",--Junior Super Series Promos
											"Japan%20Junior%20Tournament%20Promos",--Japan Junior Tournament Promos
											"Magic%20Scholarship%20Series%20Promos",--Magic Scholarship Series Promos
													} },
[9]=  {id=  9, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[7]="SPA" }, fruc={ true }, url={ -- Video Game Promos
											"Duels%20of%20the%20Planeswalkers%20Promos",--Duels of the Planeswalkers Promos
											"Oversized%206x9%20Promos", -- "Aswan Jaguar (oversized)"
											} },
[8]=  {id=  8, lang={ "ENG",[5]="ITA",[8]="JPN" }, fruc={ true }, url={ -- Stores Promos
											"Walmart%20Promos", -- Walmart Promos
											"DCI%20Promos", -- DCI Promos
											} } ,
[7]=  {id=  7, lang={ "ENG",[3]="GER",[8]="JPN" }, fruc={ true },	url={ -- "Magazine Inserts"
											"The%20Duelist%20Promos",--The Duelist Promos
											"CardZ%20Promos",--CardZ Promos
											"TopDeck%20Promos",--TopDeck Promos
											"Oversized%206x9%20Promos", -- 5 oversized
											} },
[6]=  {id=  6, lang={ "ENG",[8]="JPN" }, fruc={ true }, url={ -- Comic Inserts
											"Armada%20Comics",--Armada Comics
											"Dengeki%20Maoh%20Promos",--Dengeki Maoh Promos
											"IDW%20Promos",--IDW Promos
											"Oversized%206x9%20Promos",--Oversized 6x9 Promos
											} },
[5]=  {id=  5, lang={ "ENG",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA" }, fruc={ true }, url={ -- Book Inserts
											"Harper%20Prism%20Promos",--Harper Prism Promos
											"DCI%20Promos",--DCI Promos "Jace Beleren"
											} },
[4]  =nil, -- Ultra Rare Cards
[2]  ={id=  2, lang={ "ENG" }, fruc={ true }, url="DCI%20Promos"},-- DCI Legend Membership in DCI Promos
-- unknown
--[0]={id=  0, lang=all, fruc={ true }, url="Simplified%20Chinese%20Alternate%20Art%20Cards"},--Simplified Chinese Alternate Art Cards
--[0]={id=  0, lang=all, fruc={ true }, url="Misprints"},--Misprints
--[0]={id=  0, lang=all, fruc={ true }, url={-- these are preconstructed decks
--										"Pro%20Tour%201996:%20Mark%20Justice",--Pro Tour 1996: Mark Justice
--										"Pro%20Tour%201996:%20Michael%20Locanto",--Pro Tour 1996: Michael Locanto
--										"Pro%20Tour%201996:%20Bertrand%20Lestree",--Pro Tour 1996: Bertrand Lestree
--										"Pro%20Tour%201996:%20Preston%20Poulter",--Pro Tour 1996: Preston Poulter
--										"Pro%20Tour%201996:%20Eric%20Tam",--Pro Tour 1996: Eric Tam
--										"Pro%20Tour%201996:%20Shawn%20Regnier",--Pro Tour 1996: Shawn Regnier
--										"Pro%20Tour%201996:%20George%20Baxter",--Pro Tour 1996: George Baxter
--										"Pro%20Tour%201996:%20Leon%20Lindback",--Pro Tour 1996: Leon Lindback
--										} },
--[0]={id=  0, lang=all, fruc={ true }, url={"World%20Championship%20Decks",--World Championship Decks
--										"WCD%201997:%20Svend%20Geertsen",--WCD 1997: Svend Geertsen
--										"WCD%201997:%20Jakub%20Slemr",--WCD 1997: Jakub Slemr
--										"WCD%201997:%20Janosch%20Kuhn",--WCD 1997: Janosch Kuhn
--										"WCD%201997:%20Paul%20McCabe",--WCD 1997: Paul McCabe
--										"WCD%201998:%20Brian%20Selden",--WCD 1998: Brian Selden
--										"WCD%201998:%20Randy%20Buehler",--WCD 1998: Randy Buehler
--										"WCD%201998:%20Brian%20Hacker",--WCD 1998: Brian Hacker
--										"WCD%201998:%20Ben%20Rubin",--WCD 1998: Ben Rubin
--										"WCD%201999:%20Jakub%20Slemr",--WCD 1999: Jakub Šlemr
--										"WCD%201999:%20Matt%20Linde",--WCD 1999: Matt Linde
--										"WCD%201999:%20Mark%20Le%20Pine",--WCD 1999: Mark Le Pine
--										"WCD%201999:%20Kai%20Budde",--WCD 1999: Kai Budde
--										"WCD%202000:%20Janosch%20uhn",--WCD 2000: Janosch Kühn
--										"WCD%202000:%20Jon%20Finkel",--WCD 2000: Jon Finkel
--										"WCD%202000:%20Nicolas%20Labarre",--WCD 2000: Nicolas Labarre
--										"WCD%202000:%20Tom%20Van%20de%20Logt",--WCD 2000: Tom Van de Logt
--										"WCD%202001:%20Alex%20Borteh",--WCD 2001: Alex Borteh
--										"WCD%202001:%20Tom%20van%20de%20Logt",--WCD 2001: Tom van de Logt
--										"WCD%202001:%20Jan%20Tomcani",--WCD 2001: Jan Tomcani
--										"WCD%202001:%20Antoine%20Ruel",--WCD 2001: Antoine Ruel
--										"WCD%202002:%20Carlos%20Romao",--WCD 2002: Carlos Romao
--										"WCD%202002:%20Sim%20Han%20How",--WCD 2002: Sim Han How
--										"WCD%202002:%20Raphael%20Levy",--WCD 2002: Raphael Levy
--										"WCD%202002:%20Brian%20Kibler",--WCD 2002: Brian Kibler
--										"WCD%202003:%20Dave%20Humpherys",--WCD 2003: Dave Humpherys
--										"WCD%202003:%20Daniel%20Zink",--WCD 2003: Daniel Zink
--										"WCD%202003:%20Peer%20Kroger",--WCD 2003: Peer Kröger
--										"WCD%202003:%20Wolfgang%20Eder",--WCD 2003: Wolfgang Eder
--										"WCD%202004:%20Gabriel%20Nassif",--WCD 2004: Gabriel Nassif
--										"WCD%202004:%20Manuel%20Bevand",--WCD 2004: Manuel Bevand
--										"WCD%202004:%20Aeo%20Paquette",--WCD 2004: Aeo Paquette
--										"WCD%202004:%20Julien%20Nuijten",--WCD 2004: Julien Nuijten
--} },
--[0]={id=  0, lang=all, fruc={ true }, url="Ultra-Pro%20Puzzle%20Cards"},--Ultra-Pro Puzzle Cards
--[0]={id=  0, lang=all, fruc={ true }, url="Filler%20Cards"},--Filler Cards
--[0]={id=  0, lang=all, fruc={ true }, url="Blank%20Cards"},--Blank Cards
--[0]={id=  0, lang=all, fruc={ true }, url={ -- actual Pro-Players on baseballcard-like cards
--										"2005%20Player%20Cards",--2005 Player Cards
--										"2006%20Player%20Cards",--2006 Player Cards
--										"2007%20Player%20Cards",--2007 Player Cards
--										} },
--[0]={id=  0, lang=all, fruc={ true }, url={ -- custom tokens
--										"Custom%20Tokens",--Custom Tokens
--										"Revista%20Serra%20Promos",--Revista Serra Promos
--										"Your%20Move%20Games%20Tokens",--Your Move Games Tokens
--										"Tierra%20Media%20Tokens",--Tierra Media Tokens
--										"TokyoMTG%20Products",--TokyoMTG Products
--										"Mystic%20Shop%20Products",--Mystic Shop Products
--										"JingHe%20Age:%202002%20Tokens",--JingHe Age: 2002 Tokens
--										"JingHe%20Age:%20MtG%2010th%20Anniversary%20Tokens",--JingHe Age: MtG 10th Anniversary Tokens
--										"Starcity%20Games:%20Commemorative%20Tokens",--Starcity Games: Commemorative Tokens
--										"Starcity%20Games:%20Creature%20Collection",--Starcity Games: Creature Collection
--										"Starcity%20Games:%20Justin%20Treadway%20Tokens",--Starcity Games: Justin Treadway Tokens
--										"Starcity%20Games:%20Kristen%20Plescow%20Tokens",--Starcity Games: Kristen Plescow Tokens
--										"Starcity%20Games:%20Token%20Series%20One",--Starcity Games: Token Series One
--										} },
	}
--end table site.sets

--[[- card name replacement tables.

  fields are for subtables indexed by #number setid.
 { #number (setid)= #table { #string (oldname)= #string (newname), ... } , ... }
 
 @type site.namereplace
 @field [parent=#site.namereplace] #string name
]]
site.namereplace = {
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
[813] = { -- Khans of Tarkir
["Avalanche Tusker (1)"]			= "Avalanche Tusker",
["Avalanche Tusker (2)"]			= "Avalanche Tusker (Intro)",
["Ivorytusk Fortress (1)"]			= "Ivorytusk Fortress",
["Ivorytusk Fortress (2)"]			= "Ivorytusk Fortress (Intro)",
["Sage of the Inward Eye (1)"]		= "Sage of the Inward Eye",
["Sage of the Inward Eye (2)"]		= "Sage of the Inward Eye (Intro)",
["Rakshasa Vizier (1)"]				= "Rakshasa Vizier",
["Rakshasa Vizier (2)"]				= "Rakshasa Vizier (Intro)",
["Ankle Shanker (1)"]				= "Ankle Shanker",
["Ankle Shanker (2)"]				= "Ankle Shanker (Intro)",
["Sultai Charm (1)"]				= "Sultai Charm",
["Sultai Charm (2)"]				= "Sultai Charm (Holiday Gift Box)",
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
[814] = { --Commander 2014
["Daretti, Scrap Savant (1)"]			= "Daretti, Scrap Savant",
["Daretti, Scrap Savant (2)"]			= "Daretti, Scrap Savant (oversized)",
["Daretti, Scrap Savant Emblem"]		= "Daretti Emblem",
["Freyalise, Llanowar's Fury (1)"]		= "Freyalise, Llanowar’s Fury",
["Freyalise, Llanowar's Fury (2)"]		= "Freyalise, Llanowar’s Fury (oversized)",
["Nahiri, the Lithomancer (1)"]			= "Nahiri, the Lithomancer",
["Nahiri, the Lithomancer (2)"]			= "Nahiri, the Lithomancer (oversized)",
["Ob Nixilis of the Black Oath (1)"]	= "Ob Nixilis of the Black Oath",
["Ob Nixilis of the Black Oath (2)"]	= "Ob Nixilis of the Black Oath (oversized)",
["Ob Nixilis of the Black Oath Emblem"]	= "Nixilis Emblem",
["Teferi, Temporal Archmage (1)"]		= "Teferi, Temporal Archmage",
["Teferi, Temporal Archmage (2)"]		= "Teferi, Temporal Archmage (oversized)",
["Teferi, Temporal Archmage Emblem"]	= "Teferi Emblem",
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
[755] = { -- DD: Jace vs Chandra
["Chandra Nalaar (1)"]			= "Chandra Nalaar",
["Chandra Nalaar (2)"]			= "Chandra Nalaar (Manga)",
["Jace Beleren (1)"]			= "Jace Beleren",
["Jace Beleren (2)"]			= "Jace Beleren (Manga)",
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
[40] = {
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
},
[27] = { -- Alternate Art Lands
["Plains (1) (APAC)"]	= "Plains (APAC Red)",
["Plains (2) (APAC)"]	= "Plains (APAC Blue)",
["Plains (3) (APAC)"]	= "Plains (APAC Clear)",
["Island (1) (APAC)"]	= "Island (APAC Red)",
["Island (2) (APAC)"]	= "Island (APAC Blue)",
["Island (3) (APAC)"]	= "Island (APAC Clear)",
["Swamp (1) (APAC)"]	= "Swamp (APAC Red)",
["Swamp (2) (APAC)"]	= "Swamp (APAC Blue)",
["Swamp (3) (APAC)"]	= "Swamp (APAC Clear)",
["Mountain (1) (APAC)"]	= "Mountain (APAC Red)",
["Mountain (2) (APAC)"]	= "Mountain (APAC Blue)",
["Mountain (3) (APAC)"]	= "Mountain (APAC Clear)",
["Forest (1) (APAC)"]	= "Forest (APAC Red)",
["Forest (2) (APAC)"]	= "Forest (APAC Blue)",
["Forest (3) (APAC)"]	= "Forest (APAC Clear)",
["Plains (1) (Euro)"]	= "Plains (Euro Blue)",
["Plains (2) (Euro)"]	= "Plains (Euro Red)",
["Plains (3) (Euro)"]	= "Plains (Euro Purple)",
["Island (1) (Euro)"]	= "Island (Euro Blue)",
["Island (2) (Euro)"]	= "Island (Euro Red)",
["Island (3) (Euro)"]	= "Island (Euro Purple)",
["Swamp (1) (Euro)"]	= "Swamp (Euro Blue)",
["Swamp (2) (Euro)"]	= "Swamp (Euro Red)",
["Swamp (3) (Euro)"]	= "Swamp (Euro Purple)",
["Mountain (1) (Euro)"]	= "Mountain (Euro Blue)",
["Mountain (2) (Euro)"]	= "Mountain (Euro Red)",
["Mountain (3) (Euro)"]	= "Mountain (Euro Purple)",
["Forest (1) (Euro)"]	= "Forest (Euro Blue)",
["Forest (2) (Euro)"]	= "Forest (Euro Red)",
["Forest (3) (Euro)"]	= "Forest (Euro Purple)",
},
[25] = { -- Judge Gift Cards
["Vindicate (1)"]			= "Vindicate (4)",
["Vindicate (2)"]			= "Vindicate (7)",
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
["Lu Bu, Master-at-Arms (1)"] 	= "Lu Bu, Master-at-Arms (April)",
["Lu Bu, Master-at-Arms (2)"] 	= "Lu Bu, Master-at-Arms (July)",
["Dirtcowl Wurm (1)"]			= "Dirtcowl Wurm",
["Dirtcowl Wurm (2)"]			= "Dirtcowl Wurm (DROP unique?)",
["Ravenous Demon"]				= "Ravenous Demon|Archdemon of Greed",
["Mayor of Avabruck"]			= "Mayor of Avabruck|Howlpack Alpha",
["Laquatus's Champion"]			= "Laquatus’s Champion",
},
[21] = { -- Release Promos
["Plots That Span Centuries"]	= "Plots that Span Centuries (Scheme)",
["Mondronen Shaman"]			= "Mondronen Shaman|Tovolar’s Magehunter",
["Ludevic's Test Subject"]		= "Ludevic’s Test Subject|Ludevic’s Abomination",
["Budoka Pupil"]				= "Budoka Pupil|Ichiga, Who Topples Oaks",
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
["Sakura-Tribe Elder (1) (E)"]	= "Sakura-Tribe Elder (E)",
["Sakura-Tribe Elder (2) (E)"]	= "Sakura-Tribe Elder (U)",
["Soltari Priest (1) (E)"]		= "Soltari Priest (E)",
["Soltari Priest (2) (E)"]		= "Soltari Priest (U)",
["Crusade (J)"]					= "Crusade",
["Thran Quarry (J)"]			= "Thran Quarry",
["Serra Avatar (J)"]			= "Serra Avatar",
["City of Brass (J)"]			= "City of Brass",
["Volcanic Hammer (J)"]			= "Volcanic Hammer",
["Mad Auntie (J)"]				= "Mad Auntie",--Magic Scholarship
["Giant Growth (J)"]			= "Giant Growth",
["Two-Headed Dragon (J)"]		= "Two-Headed Dragon",
["Elvish Lyrist (J)"]			= "Elvish Lyrist",
["Lord of Atlantis (J)"]		= "Lord of Atlantis",
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
[813] = { -- KTK
["Sultai Charm (Holiday Gift Box)"]	= "Holiday Gift Box",
},
[806] = { -- JOU
["Spear of the General"]		= "Prerelease Promos",
["Cloak of the Philosopher"]	= "Prerelease Promos",
["Lash of the Tyrant"]			= "Prerelease Promos",
["Axe of the Warmonger"]		= "Prerelease Promos",
["Bow of the Hunter"]			= "Prerelease Promos",
["The Destined"]				= "Release Promos",
["The Champion"]				= "Magic Game Day",
},
[802] = { -- BNG
["The General"]					= "Prerelease Promos",
["The Savant"]					= "Prerelease Promos",
["The Tyrant"]					= "Prerelease Promos",
["The Warmonger"]				= "Prerelease Promos",
["The Provider"]				= "Prerelease Promos",
["The Explorer"]				= "Release Promos",
["The Vanquisher"]				= "Magic Game Day",
},
[800] = { -- THS
["The Protector"]				= "Prerelease Promos",
["The Philosopher"]				= "Prerelease Promos",
["The Avenger"]					= "Prerelease Promos",
["The Warrior"]					= "Prerelease Promos",
["The Hunter"]					= "Prerelease Promos",
["The Harvester"]				= "Release Promos",
["The Slayer"]					= "Magic Game Day",
},
[755] = { -- DD:Jace vs Chandra
--TODO right set, but JPN ?
["Chandra Nalaar (Manga)"]		= "unknown",
["Jace Beleren (Manga)"]		= "unknown",
},
[340] = { --Anthologies
--TODO unglued tokens already in unglued url?
["Goblin"]						= "(Token) Unglued ?",
["Pegasus"]						= "(Token) Unglued ?",
},
[40] = { -- Arena (here for Oversized%206x9%20Promos)
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
},
[33] = { -- Championship Prizes (here for "Promos")
--TODO sort us :)
--["Geist of Saint Traft"]		= "Championship Prizes",
},
[31] = { -- Grand Prix Promos (here for DCI%20Promos)
["Ajani Goldmane"]			= "Pro Tour Promo",
["Avatar of Woe"]			= "Pro Tour Promo",
["Balduvian Horde"]			= "Championship Prizes",
["Bloodthrone Vampire"]		= "Convention Promos",
["Chandra's Fury"]			= "Covention Promos",
["Char"]					= "Covention Promos",
["Counterspell"]			= "DCI Legend Membership",
["Eternal Dragon"]			= "Pro Tour Promo",
["Griselbrand"]				= "Prerelease Promos",
["Incinerate"]				= "DCI Legend Membership",
["Jace Beleren"]			= "Book Inserts",
["Kamahl, Pit Fighter"]		= "Tenth Edition",--"ST"
["Kor Skyfisher"]			= "Convention Promos",
["Merfolk Mesmerist"]		= "Convention Promos",
["Mirari's Wake"]			= "Pro Tour Promo",
["Relentless Rats"]			= "Stores Promos",--ITA
["Serra Angel"]				= "Stores Promos",
["Steward of Valeron"]		= "Convention Promos",
["Treva, the Renewer"]		= "Pro Tour Promo",
["Underworld Dreams"]		= "Two-Headed Giant Promo",
["Vengevine"]				= "Championship Prizes",
},
[23] = { -- Gateway
["Naya Sojourners"]				= "Magic Game Day",
["Faerie Conclave"]				= "Summer of Magic",
["Treetop Village"]				= "Summer of Magic",
},
[22] = { -- Prerelease Promos
["Lord of Shatterskull Pass"]	= "Release Promos"
},
[21] = {
["Reya Dawnbringer"]			= "Magic Game Day"
},
} -- end table site.settweak

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
[10] = { override=true,
["Elvish Champion (E)"]			= {	"Elvish Champion"	, { "E"	 , false, false } },
["Elvish Champion (J)"]			= {	"Elvish Champion"	, { false, "J"  , false } },
["Elvish Champion (jjtp)"]		= {	"Elvish Champion"	, { false, false, ""    } },
["Glorious Anthem (E)"]			= {	"Glorious Anthem"	, { "E"	 , false, false, false } },
["Glorious Anthem (J)"]			= {	"Glorious Anthem"	, { false, "J"  , false, false } },
["Glorious Anthem (U)"]			= {	"Glorious Anthem"	, { false, false, "U"  , false } },
["Glorious Anthem (jjtp)"]		= {	"Glorious Anthem"	, { false, false, false, ""    } },
["Royal Assassin (E)"]			= {	"Royal Assassin"	, { "E"	 , false, false } },
["Royal Assassin (J)"]			= {	"Royal Assassin"	, { false, "J"  , false } },
["Royal Assassin (jjtp)"]		= {	"Royal Assassin"	, { false, false, ""   } },
["Sakura-Tribe Elder (E)"]		= {	"Sakura-Tribe Elder", { "E"	 , false, false, false } },
["Sakura-Tribe Elder (J)"]		= {	"Sakura-Tribe Elder", { false, "J"  , false, false } },
["Sakura-Tribe Elder (U)"]		= {	"Sakura-Tribe Elder", { false, false, "U"  , false } },
["Sakura-Tribe Elder (jjtp)"]	= {	"Sakura-Tribe Elder", { false, false, false, ""    } },
["Shard Phoenix (E)"]			= {	"Shard Phoenix"		, { "E"	 , false, false, false } },
["Shard Phoenix (J)"]			= {	"Shard Phoenix"		, { false, "J"  , false, false } },
["Shard Phoenix (U)"]			= {	"Shard Phoenix"		, { false, false, "U"  , false } },
["Shard Phoenix (jjtp)"]		= {	"Shard Phoenix"		, { false, false, false, ""    } },
["Slith Firewalker (E)"]		= {	"Slith Firewalker"	, { "E"	 , false, false } },
["Slith Firewalker (J)"]		= {	"Slith Firewalker"	, { false, "J"  , false } },
["Slith Firewalker (jjtp)"]		= {	"Slith Firewalker"	, { false, false, ""   } },
["Soltari Priest (E)"]			= {	"Soltari Priest"	, { "E"	 , false, false, false } },
["Soltari Priest (J)"]			= {	"Soltari Priest"	, { false, "J"  , false, false } },
["Soltari Priest (U)"]			= {	"Soltari Priest"	, { false, false, "U"  , false } },
["Soltari Priest (jjtp)"]		= {	"Soltari Priest"	, { false, false, false, ""    } },
["Whirling Dervish (E)"]		= {	"Whirling Dervish"	, { "E"	 , false, false, false } },
["Whirling Dervish (J)"]		= {	"Whirling Dervish"	, { false, "J"  , false, false } },
["Whirling Dervish (U)"]		= {	"Whirling Dervish"	, { false, false, "U"  , false } },
["Whirling Dervish (jjtp)"]		= {	"Whirling Dervish"	, { false, false, false, ""    } },
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

--- if EXPECTTOKENS is true, LHpi.Data.sets[setid].cardcount.tok is added to pset default.
-- a boolean will set this for all languges, a table will be assumed to be of the form { [langid]=#boolean, ... }
-- @field [parent=#site.expected] #boolean or #table { #boolean,...} tokens
--	tokens = true,
	tokens = { "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA" },
--- if EXPECTNONTRAD is true, LHpi.Data.sets[setid].cardcount.nontrad is added to pset default.
-- a boolean will set this for all languges, a table will be assumed to be of the form { [langid]=#boolean, ... }
-- @field [parent=#site.expected] #boolean nontrad
	nontrad = true,
--- if EXPECTREPL is true, LHpi.Data.sets[setid].cardcount.repl is added to pset default.
-- a boolean will set this for all languges, a table will be assumed to be of the form { [langid]=#boolean, ... }
-- @field [parent=#site.expected] #boolean replica
	replica = true,
-- Core sets
[808] = { pset={ dup=LHpi.Data.sets[808].cardcount.reg }, duppset={ [2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, failed={ dup=LHpi.Data.sets[808].cardcount.tok }, dupfail={ [2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" } },
[797] = { pset={ dup=LHpi.Data.sets[797].cardcount.reg }, failed={ dup=LHpi.Data.sets[797].cardcount.tok }, duppset={ [2]="RUS",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dupfail={ [2]="RUS",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" } },
[788] = { pset={ dup=LHpi.Data.sets[788].cardcount.reg }, failed={ dup=LHpi.Data.sets[788].cardcount.tok }, duppset={ [7]="SPA" }, dupfail={ [7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" } },
[779] = { failed={ dup=LHpi.Data.sets[779].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH",[10]="ZHT" } },
[770] = { failed={ dup=LHpi.Data.sets[770].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH",[10]="ZHT" } },
[759] = { failed={ dup=LHpi.Data.sets[759].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" } },
[720] = { pset={ dup=LHpi.Data.sets[720].cardcount.both-1, [3]=LHpi.Data.sets[720].cardcount.both-2,[8]=LHpi.Data.sets[720].cardcount.reg-1,[9]=LHpi.Data.sets[720].cardcount.reg-1 }, duppset={ [2]="RUS",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA" }, failed={ dup=1, [3]=2,[8]=LHpi.Data.sets[720].cardcount.tok+1,[9]=LHpi.Data.sets[720].cardcount.tok+1 }, dupfail={ [2]="RUS",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA" }, dropped=60 },--"Kamahl, Pit Fighter (ST)" only ENG; no GER March of the Machines exists
[630] = { pset={ dup=LHpi.Data.sets[630].cardcount.reg-7 }, duppset={ [2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[9]="SZH" }, failed={ dup=7 }, dupfail={ [2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[9]="SZH" } },--7 cards exist only in ENG
[550] = { pset={ dup=LHpi.Data.sets[550].cardcount.reg-2,[9]=LHpi.Data.sets[550].cardcount.reg-7 }, duppset={ [3]="GER",[4]="FRA",[6]="POR",[7]="SPA" }, failed={ dup=2, [9]=7 }, dupfail={ [3]="GER",[4]="FRA",[6]="POR",[7]="SPA" } },--2 cards do not exist in GER,FRA,POR,SPA; 7 in SZH
[180] = { pset={ dup=LHpi.Data.sets[180].cardcount.reg,[6]=375 }, duppset={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[8]="JPN" }, failed={ [6]=3 } },
[179] = { pset={ [6]=LHpi.Data.sets[179].cardcount.reg-3, [8]=LHpi.Data.sets[179].cardcount.reg}, failed={ [6]=3 } },--3 cards do not exist in POR
[139] = { namereplaced=30 },
-- Expansions
[813] = { pset={ dup=LHpi.Data.sets[813].cardcount.reg-5 }, failed={ dup=LHpi.Data.sets[813].cardcount.tok+5 }, duppset={ [2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dupfail={ [2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, namereplaced=24, dropped=2 },--5 "Intro" variants only in ENG
[806] = { pset={ dup=LHpi.Data.sets[806].cardcount.reg }, failed={ dup=LHpi.Data.sets[806].cardcount.tok }, duppset={ [2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dupfail={ [2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dropped=14 },
[802] = { pset={ dup=LHpi.Data.sets[802].cardcount.reg }, failed={ dup=LHpi.Data.sets[802].cardcount.tok }, duppset={ [2]="RUS",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dupfail={ [2]="RUS",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dropped=14, namereplaced=2 },
[800] = { pset={ dup=LHpi.Data.sets[800].cardcount.reg }, failed={ dup=LHpi.Data.sets[800].cardcount.tok }, duppset={ [2]="RUS",[7]="SPA" }, dupfail={ [2]="RUS",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, dropped=14 },
[795] = { pset={ dup=LHpi.Data.sets[795].cardcount.reg }, failed={ dup=LHpi.Data.sets[795].cardcount.tok }, duppset={ [2]="RUS",[3]="GER",[7]="SPA" }, dupfail={ [2]="RUS",[3]="GER",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" } },
[793] = { pset={ dup=LHpi.Data.sets[793].cardcount.reg }, failed={ dup=LHpi.Data.sets[793].cardcount.tok }, duppset={ [2]="RUS",[7]="SPA" }, dupfail={ [2]="RUS",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" } },
[791] = { pset={ dup=LHpi.Data.sets[791].cardcount.reg }, failed={ dup=LHpi.Data.sets[791].cardcount.tok }, duppset={ [2]="RUS",[7]="SPA" }, dupfail={ [2]="RUS",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" } },
[786] = { pset={ [7]=LHpi.Data.sets[786].cardcount.reg }, failed= { dup=LHpi.Data.sets[786].cardcount.tok }, dupfail= { [7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" } },
[784] = { failed={ dup=1,[8]=LHpi.Data.sets[784].cardcount.tok+1,[9]=LHpi.Data.sets[784].cardcount.tok+1,[10]=LHpi.Data.sets[784].cardcount.tok+1,[11]=LHpi.Data.sets[784].cardcount.tok+1 }, dupfail={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA" }, namereplaced=26 },--Double-Faced Card Proxy
[782] = { failed={ dup=1,[8]=LHpi.Data.sets[782].cardcount.tok+1,[9]=LHpi.Data.sets[782].cardcount.tok+1,[10]=LHpi.Data.sets[782].cardcount.tok+1 }, dupfail={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA" }, namereplaced=40 },--Double-Faced Card Proxy
[776] = { pset={ dup=LHpi.Data.sets[776].cardcount.reg }, failed={ dup=1, [8]=5,[9]=5,[10]=5 }, duppset={ [8]="JPN",[9]="SZH",[10]="ZHT" }, dupfail={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA", } },
[775] = { pset={ dup=LHpi.Data.sets[775].cardcount.reg }, failed={ dup=1, [8]=6,[9]=6,[10]=6 }, duppset={ [8]="JPN",[9]="SZH",[10]="ZHT" }, dupfail={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA", } },
[773] = { failed={ dup=1,[8]=LHpi.Data.sets[773].cardcount.tok+1,[9]=LHpi.Data.sets[773].cardcount.tok+1,[10]=LHpi.Data.sets[773].cardcount.tok+1 }, dupfail={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA", } },--Poison Counter
[767] = { failed={ dup=LHpi.Data.sets[767].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" } },
[765] = { failed={ dup=LHpi.Data.sets[765].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" } },
[764] = { failed={ dup=LHpi.Data.sets[764].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" } },
[762] = { failed={ dup=LHpi.Data.sets[762].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" } },
[758] = { failed={ dup=LHpi.Data.sets[758].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" } },
[756] = { failed={ dup=LHpi.Data.sets[756].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" } },
[754] = { failed={ dup=LHpi.Data.sets[754].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" } },
[752] = { failed={ dup=LHpi.Data.sets[752].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" } },
[751] = { failed={ dup=LHpi.Data.sets[751].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" } },
[750] = { failed={ dup=LHpi.Data.sets[750].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" } },
[730] = { failed={ dup=LHpi.Data.sets[730].cardcount.tok }, dupfail={ [8]="JPN",[9]="SZH" } },
[690] = { dropped=602 },--  301 cards non-Timeshifted
[680] = { dropped=242 }, -- 121 cards Timeshifted
[620] = { namereplaced=10 },
[610] = { namereplaced=10 },
[590] = { namereplaced=24 },
[450] = { namereplaced=12 },
[240] = { namereplaced=4 },
[210] = { pset={ [6]=LHpi.Data.sets[210].cardcount.reg-1 }, failed= { [6]=1 } },-- no POR Timmerian Fiends
[190] = { pset={ [6]=LHpi.Data.sets[190].cardcount.reg-1 }, failed= { [6]=1 } },-- no POR Amulet of Quoz
-- special sets
[814] = { pset={ dup=LHpi.Data.sets[814].cardcount.reg+LHpi.Data.sets[814].cardcount.repl }, duppset={ [3]="GER",[4]="FRA",[5]="ITA",[7]="SPA",[8]="JPN",[9]="SZH" }, failed={ dup=LHpi.Data.sets[814].cardcount.tok }, dupfail={ [3]="GER",[4]="FRA",[5]="ITA",[7]="SPA",[8]="JPN",[9]="SZH" }, namereplaced=26 },
[812] = { pset={ [8]=LHpi.Data.sets[812].cardcount.both } },
[810] = { namereplaced=4 },
[807] = { pset={ dup=LHpi.Data.sets[807].cardcount.reg+LHpi.Data.sets[807].cardcount.nontrad }, failed={ dup=LHpi.Data.sets[807].cardcount.tok }, duppset={ [8]="JPN",[9]="SZH" }, dupfail={ [8]="JPN",[9]="SZH" } },
[801] = { namereplaced=102 },
[799] = { failed={ [8]=LHpi.Data.sets[799].cardcount.tok } },
[794] = { failed={ [8]=LHpi.Data.sets[794].cardcount.tok } },
[792] = { namereplaced=20 },
[790] = { failed={ [8]=LHpi.Data.sets[790].cardcount.tok } },
[787] = { namereplaced=2 },
[785] = { failed={ [8]=LHpi.Data.sets[785].cardcount.tok },namereplaced=20 },
[781] = { pset={ dup=LHpi.Data.sets[781].cardcount.reg }, failed={ dup=LHpi.Data.sets[781].cardcount.tok }, duppset={ [3]="GER",[5]="ITA" }, dupfail={ [3]="GER",[5]="ITA" } },
[778] = { namereplaced=102 },
[777] = { pset={ [5]=LHpi.Data.sets[777].cardcount.reg }, failed={ [5]=LHpi.Data.sets[777].cardcount.tok } },
[772] = { pset={ [5]=LHpi.Data.sets[772].cardcount.reg }, failed={ [5]=LHpi.Data.sets[772].cardcount.tok } },
[769] = { namereplaced=32 },
[768] = { namereplaced=32 },
[766] = { namereplaced=2 },
[761] = { namereplaced=2 },
[755] = { pset={ [8]=LHpi.Data.sets[755].cardcount.both }, dropped=4, namereplaced=8 },
[675] = { namereplaced=30 },
[636] = { namereplaced=36 },
[600] = { namereplaced=2 },
[490] = { namereplaced=50 },
[415] = { pset={ [7]=1 }, failed={ [7]=LHpi.Data.sets[415].cardcount.reg-1  } },
[390] = { dropped=188 },
[380] = { namereplaced=4 },
[340] = { dropped=4, namereplaced=16 },
[320] = { namereplaced=4 },
[310] = { pset={ [5]=LHpi.Data.sets[310].cardcount.reg+1,[6]=49 }, failed={ [5]=1,[6]=LHpi.Data.sets[310].cardcount.reg-49 } },-- TODO why does ma.SetPrice(setid="310",langid="5",cardname="Ogre Berserker",cardversion="",regprice="0.14",foilprice="0",objtype="1") return 2 ?!
[260] = { pset={ dup=LHpi.Data.sets[260].cardcount.reg-6 }, failed={ dup=6 }, duppset={ [3]="GER",[8]="JPN" }, dupfail={ [3]="GER",[8]="JPN" }, namereplaced=52 },
[201] = { pset={ [5]=69 } },
[69]  = { namereplaced=30 },
-- Promos
[43]  = { dropped= 60 },
[42]  = { dropped= 130 },
[40]  = { pset={ LHpi.Data.sets[40].cardcount.reg+LHpi.Data.sets[40].cardcount.repl }, failed={ 3 }, namereplaced=148, dropped=24 },--Mad Auntie only JAP, missing Minotaur Token, Soldier Token
[33]  = { pset={ 3 }, dropped=82 },-- all but 3 cards are one-of-a-kind
[32]  = { pset={ LHpi.Data.sets[32].cardcount.reg,[8]=1 }, failed={ [8]=LHpi.Data.sets[32].cardcount.reg-1 }, dropped=52 },
[31]  = { dropped=42 },
[30]  = { failed={ 3 } },--3 not yet in MA
[27]  = { namereplaced=60 },
[26]  = { dropped=1480 },
[25]  = { pset={ LHpi.Data.sets[25].cardcount.reg,[17]=1 }, failed={ 5,[17]=LHpi.Data.sets[25].cardcount.all-1 },namereplaced=4 },-- 5 FullArt foil Basic lands not in MA
[23]  = { namereplaced=12, dropped=6 },
[24]  = { namereplaced=2 },
[22]  = { pset={ [12]=1,[13]=1,[14]=1,[15]=1,[16]=1 }, failed={ 1 }, namereplaced=14, dropped=1478 },-- Laquatus's Champion only RUS,
[21]  = { failed={ 1 }, namereplaced=8, dropped=1712 },-- Shivan Dragon only RUS
[20]  = { namereplaced=20 },
[15]  = { failed={ 6 }, namereplaced=14, dropped=236 },--6 SanDiego'14(not in MA);5SanDiego'13,2 oversized Caravan Tours
[10]  = { pset= { 10+13+5,[8]=11 }, failed={ 11,[8]=10+13+5 }, namereplaced=28 },-- 10 JSS, 13 JSSP,11 JJTP, 5 MSSP; missing 5 APACJS (MA has ENG 32, JPN 11)
[9]   = { pset={ [2]=3,[3]=12,[4]=3,[7]=3 }, dropped=188 },-- not all nonENG in MA
[8]	  = { pset={ [5]=0,[8]=0 }, failed={ 2,[5]=11,[8]=11 }, dropped=58 },
[7]   = { pset={ [3]=1-1,[8]=4-4 }, failed={ 4 },namereplaced=2, dropped=180 },-- fail 4 Lifecounter cards; MA has JPN 4 Gotta Magazine, GER 1 Kartefakt
[6]   = { pset={ [8]=7-3 }, namereplaced=6, dropped=188 },
[5]   = { namereplaced=4, dropped=60 },
[2]   = { dropped=2*29 },

--TODO check why averaging foilcard in duel decks. possibly no averaging should be necessarry, so error on any conflict.
-- override all foiltweak tables, no more averaging
-- averaging in core,expansion: 813(ktk)	762(ZEN)	450(Planeshift)	240(visions)

	}--end table site.expected
	-- I'm too lazy to fill in site.expected myself, let the script do it ;-)
	for sid,name in pairs(importsets) do
		if site.expected[sid] then
			if site.expected[sid].pset and site.expected[sid].duppset and site.expected[sid].pset.dup then			
				for lid,lang in pairs(site.expected[sid].duppset) do
					if importlangs[lid] then
						site.expected[sid].pset[lid] = site.expected[sid].pset.dup or 0
					end
				end
			site.expected[sid].duppset=nil
			site.expected[sid].pset.dup=nil
			end
			if site.expected[sid].failed and site.expected[sid].dupfail and site.expected[sid].failed.dup then			
				for lid,lang in pairs(site.expected[sid].dupfail) do
					if importlangs[lid] then
						site.expected[sid].failed[lid] = site.expected[sid].failed.dup or 0
					end
				end
			site.expected[sid].dupfail=nil
			site.expected[sid].failed.dup=nil
			end
		end
	end--for sid,name
end--function site.SetExpected()
--EOF