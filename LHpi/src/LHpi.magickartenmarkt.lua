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
@author Christ@copyright 2012-2014 Christian Harms except parts by Goblin Hero, Stromglad1 or woogerboy21
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
		--emulate require(modname) using dofile
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

 @function [parent=#site] CompareDataSets
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
 @return #number or #table newCard.regprice		(optional) will override LHpi.buildCardData generated values. #number or #table { [#number langid]= #number,...}
 @return #number or #table newCard.foilprice 	(optional) will override LHpi.buildCardData generated values. #number or #table { [#number langid]= #number,...}
 
 @function [parent=#site] ParseHtmlData
 @param #string foundstring		one occurence of siteregex from raw html data
 @param #table urldetails		{ isfile= #boolean , setid= #number, langid= #number, frucid= #number , foilonly= #boolean }
 @return #table { #number= #table { names= #table { #number (langid)= #string , ... }, price= #number or #table { [#number langid]= #number,...} , foil= #boolean , ... } , ... } 
]]
function site.ParseHtmlData( foundstring , urldetails )
	local priceType = site.priceTypes[priceToUse] or "AVG"
	local product
	if responseFormat == "json" then
		product = Json.decode(foundstring)
	else
		error("nothing here for xml yet")
	end
	local newCard = 	{ names = {}, lang={}, price = {}, pluginData={} }
	local newFoilCard = { names = {}, lang={}, price = {}, pluginData={} }
	newCard.foil = false
	newFoilCard.foil=true
	local regprice  = string.gsub( product.priceGuide[priceType] , "[,.]" , "" ) --nonfoil price, use AVG by default
	local foilprice = string.gsub( product.priceGuide["LOWFOIL"] , "[,.]" , "" ) --foil price
	-- could just set name to productNamw[1].productName, as productName reflects mkm ui langs, not card langs		
	for i,prodName in pairs(product.name) do
		local langid = site.mapLangs[prodName.languageName] or error("unknown MKM language")
		newCard.names[langid] = prodName.productName
		newFoilCard.names[langid] = prodName.productName
		--newCard.price[langid]= regprice
		--newFoilCard.price[langid]= foilprice
	end--for i,prodName
	for lid,lang in pairs(site.sets[urldetails.setid].lang) do
		newCard.lang[lid] = LHpi.Data.languages[lid].abbr
		newFoilCard.lang[lid] = LHpi.Data.languages[lid].abbr
	end
	newCard.price=tonumber(regprice)
	newFoilCard.price=tonumber(foilprice)
	local pluginData = { rarity=product.rarity, collectNr=product.number, set=product.expansion }
	newCard.pluginData = pluginData
	newFoilCard.pluginData = pluginData
	local container={ newCard, newFoilCard }
	return container
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
			card.name = string.gsub( card.name,"%(T(%d+)%)","(%1)")
		end
	end--if "Land" else "Token"
	if setid == 680 then --Time Spiral
		if card.pluginData.rarity == "Time Shifted" then
			card.name = card.name .. "(DROP Timeshfted)"
		end
	elseif setid == 690 then --Time Spiral Timeshifted
		if card.pluginData.rarity ~= "Time Shifted" then
			card.name = card.name .. "(DROP not Timeshfted)"
		end	
	elseif setid == 140 then
		if card.pluginData.set == "Revised" then
			card.lang = { [1]="ENG" }
		elseif card.pluginData.set == "Foreign White Bordered" then
			card.lang = { [3]="GER", [4]="FRA", [5]="ITA" }
		end
	elseif setid == 201 then
		if card.pluginData.set == "Renaissance" then
			card.lang = { [3]="GER", [4]="FRA" }
		elseif card.pluginData.set == "Rinascimento" then
			card.lang = { [5]="ITA" }
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
	if site.settweak[setid] and site.settweak[setid][card.name] then
		if LOGSETTWEAK or DEBUG then
			LHpi.Log( string.format( "settweak saved %s with new set %s" ,card.name, site.settweak[setid][card.name] ), 1 )
		end
		card.name = card.name .. "(DROP settweaked to" .. site.settweak[setid][card.name] .. ")"
		settweaked=1
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
commented out langs that are not available as mkm site localization
 @field [parent=#site] #table mapLangs	{ #string langName = #number MAlangid, ... }
]]
site.mapLangs = {
	["English"]				=  1,
--	["Russian"]				=  2,
	["German"]				=  3,
	["French"]				=  4,
	["Italian"]				=  5,
--	["Portuguese"]			=  6,
	["Spanish"]				=  7,
--	["Japanese"]			=  8,
--	["Simplified Chinese"]	=  9,
--	["Traditional Chinese"]	= 10,
--	["Korean"]				= 11,
--	["Hebrew"]				= 12,
--	["Arabic"]				= 13,
--	["Latin"]				= 14,
--	["Sanskrit"]			= 15,
--	["Ancient Greek"]		= 16,
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
	[12] = { id=12, url="" },--Hebrew
	[13] = { id=13, url="" },--Arabic
	[14] = { id=14, url="" },--Latin
	[15] = { id=15, url="" },--Sanskrit
	[16] = { id=16, url="" },--Ancient Greek
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

local all = { "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR",[12]="HEB",[13]="ARA",[14]="LAT",[15]="SAN",[16]="GRC" }
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
[720]={id=720, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Tenth%20Edition"},--Tenth Edition
[630]={id=630, lang=all, fruc={ true }, url="Ninth%20Edition"},--Ninth Edition
[550]={id=550, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH" }, fruc={ true }, url="Eighth%20Edition"},--Eighth Edition
[460]={id=460, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[8]="JPN" }, fruc={ true }, url="Seventh%20Edition"},--Seventh Edition
[360]={id=360, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[8]="JPN" }, fruc={ true }, url="Sixth%20Edition"},--Sixth Edition
[250]={id=250, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[8]="JPN" }, fruc={ true }, url="Fifth%20Edition"},--Fifth Edition
[180]={id=180, lang={ "ENG",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[8]="JPN" }, fruc={ true }, url="Fourth%20Edition"},--Fourth Edition
[179]={id=179, lang={ [6] = true, [8]=true }, fruc={ true }, url="Fourth%20Edition:%20Black%20Bordered"},--Fourth Edition: Black Bordered
[141]={id=141, lang={ "ENG" }, fruc={ true }, url="Summer%20Magic"},--Summer Magic
[140]={id=140, lang=all, fruc={ true }, url={ "Revised", "Foreign%20White%20Bordered"} },--Revised; Foreign White Bordered = Revised Unlimited
[139]={id=139, lang={ [3]=true,[4]=true,[5]=true }, fruc={ true }, url="Foreign%20Black%20Bordered"},--Foreign Black Bordered = Revised Limited
[110]={id=110, lang={ "ENG" }, fruc={ true }, url="Unlimited"},--Unlimited
[100]={id=100, lang={ "ENG" }, fruc={ true }, url="Beta"},--Beta
[90] ={id= 90, lang={ "ENG" }, fruc={ true }, url="Alpha"},--Alpha
-- expansionsets
[813]={id=813, lang=all, fruc={ true }, url="Khans%20of%20Tarkir"},--Khans of Tarkir
[806]={id=806, lang=all, fruc={ true }, url="Journey%20into%20Nyx"},--Journey into Nyx
[802]={id=802, lang=all, fruc={ true }, url="Born%20of%20the%20Gods"},--Born of the Gods
[800]={id=800, lang=all, fruc={ true }, url="Theros"},--Theros
[795]={id=795, lang=all, fruc={ true }, url="Dragon%27s%20Maze"},--Dragon's Maze
[793]={id=793, lang=all, fruc={ true }, url="Gatecrash"},--Gatecrash
[791]={id=791, lang=all, fruc={ true }, url="Return%20to%20Ravnica"},--Return to Ravnica
[786]={id=786, lang=all, fruc={ true }, url="Avacyn%20Restored"},--Avacyn Restored
[784]={id=784, lang=all, fruc={ true }, url="Dark%20Ascension"},--Dark Ascension
[782]={id=782, lang=all, fruc={ true }, url="Innistrad"},--Innistrad
[776]={id=776, lang=all, fruc={ true }, url="New%20Phyrexia"},--New Phyrexia
[775]={id=775, lang=all, fruc={ true }, url="Mirrodin%20Besieged"},--Mirrodin Besieged
[773]={id=773, lang=all, fruc={ true }, url="Scars%20of%20Mirrodin"},--Scars of Mirrodin
[767]={id=767, lang=all, fruc={ true }, url="Rise%20of%20the%20Eldrazi"},--Rise of the Eldrazi
[765]={id=765, lang=all, fruc={ true }, url="Worldwake"},--Worldwake
[762]={id=762, lang=all, fruc={ true }, url="Zendikar"},--Zendikar
[758]={id=758, lang=all, fruc={ true }, url="Alara%20Reborn"},--Alara Reborn
[756]={id=756, lang=all, fruc={ true }, url="Conflux"},--Conflux
[754]={id=754, lang=all, fruc={ true }, url="Shards%20of%20Alara"},--Shards of Alara
[752]={id=752, lang=all, fruc={ true }, url="Eventide"},--Eventide
[751]={id=751, lang=all, fruc={ true }, url="Shadowmoor"},--Shadowmoor
[750]={id=750, lang=all, fruc={ true }, url="Morningtide"},--Morningtide
[730]={id=730, lang=all, fruc={ true }, url="Lorwyn"},--Lorwyn
[710]={id=710, lang=all, fruc={ true }, url="Future%20Sight"},--Future Sight
[700]={id=700, lang=all, fruc={ true }, url="Planar%20Chaos"},--Planar Chaos
[690]={id=690, lang=all, fruc={ true }, url="Time%20Spiral"},--Time Spiral Timeshifted
[680]={id=680, lang=all, fruc={ true }, url="Time%20Spiral"},--Time Spiral
[670]={id=670, lang=all, fruc={ true }, url="Coldsnap"},--Coldsnap
[660]={id=660, lang=all, fruc={ true }, url="Dissension"},--Dissension
[650]={id=650, lang=all, fruc={ true }, url="Guildpact"},--Guildpact
[640]={id=640, lang=all, fruc={ true }, url="Ravnica:%20City%20of%20Guilds"},--Ravnica: City of Guilds
[620]={id=620, lang=all, fruc={ true }, url="Saviors%20of%20Kamigawa"},--Saviors of Kamigawa
[610]={id=610, lang=all, fruc={ true }, url="Betrayers%20of%20Kamigawa"},--Betrayers of Kamigawa
[590]={id=590, lang=all, fruc={ true }, url="Champions%20of%20Kamigawa"},--Champions of Kamigawa
[580]={id=580, lang=all, fruc={ true }, url="Fifth%20Dawn"},--Fifth Dawn
[570]={id=570, lang=all, fruc={ true }, url="Darksteel"},--Darksteel
[560]={id=560, lang=all, fruc={ true }, url="Mirrodin"},--Mirrodin
[540]={id=540, lang=all, fruc={ true }, url="Scourge"},--Scourge
[530]={id=530, lang=all, fruc={ true }, url="Legions"},--Legions
[520]={id=520, lang=all, fruc={ true }, url="Onslaught"},--Onslaught
[510]={id=510, lang=all, fruc={ true }, url="Judgment"},--Judgment
[500]={id=500, lang=all, fruc={ true }, url="Torment"},--Torment
[480]={id=480, lang=all, fruc={ true }, url="Odyssey"},--Odyssey
[470]={id=470, lang=all, fruc={ true }, url="Apocalypse"},--Apocalypse
[450]={id=450, lang=all, fruc={ true }, url="Planeshift"},--Planeshift
[430]={id=430, lang=all, fruc={ true }, url="Invasion"},--Invasion
[420]={id=420, lang=all, fruc={ true }, url="Prophecy"},--Prophecy
[410]={id=410, lang=all, fruc={ true }, url="Nemesis"},--Nemesis
[400]={id=400, lang=all, fruc={ true }, url="Mercadian%20Masques"},--Mercadian Masques
[370]={id=370, lang=all, fruc={ true }, url="Urza%27s%20Destiny"},--Urza's Destiny
[350]={id=350, lang=all, fruc={ true }, url="Urza%27s%20Legacy"},--Urza's Legacy
[330]={id=330, lang=all, fruc={ true }, url="Urza%27s%20Saga"},--Urza's Saga
[300]={id=300, lang=all, fruc={ true }, url="Exodus"},--Exodus
[290]={id=290, lang=all, fruc={ true }, url="Stronghold"},--Stronghold
[280]={id=280, lang=all, fruc={ true }, url="Tempest"},--Tempest
[270]={id=270, lang=all, fruc={ true }, url="Weatherlight"},--Weatherlight
[240]={id=240, lang=all, fruc={ true }, url="Visions"},--Visions
[230]={id=230, lang=all, fruc={ true }, url="Mirage"},--Mirage
[220]={id=220, lang=all, fruc={ true }, url="Alliances"},--Alliances
[210]={id=210, lang=all, fruc={ true }, url="Homelands"},--Homelands
[190]={id=190, lang=all, fruc={ true }, url="Ice%20Age"},--Ice Age
[170]={id=170, lang=all, fruc={ true }, url="Fallen%20Empires"},--Fallen Empires
[160]={id=160, lang=all, fruc={ true }, url="The%20Dark"},--The Dark
[150]={id=150, lang=all, fruc={ true }, url="Legends"},--Legends
[130]={id=130, lang={ true }, fruc={ true }, url="Antiquities"},--Antiquities
[120]={id=120, lang=all, fruc={ true }, url="Arabian%20Nights"},--Arabian Nights
-- specialsets
--[0]={id=  0, lang=all, fruc={ true }, url="Duel%20Decks:%20Anthology"},--Duel Decks: Anthology
[814]={id=814, lang=all, fruc={ true }, url="Commander%202014"},--Commander 2014
[812]={id=812, lang=all, fruc={ true }, url="Duel%20Decks:%20Speed%20vs.%20Cunning"},--Duel Decks: Speed vs. Cunning
[811]={id=811, lang=all, fruc={ true }, url="M15%20Clash%20Pack"},--M15 Clash Pack
[810]={id=810, lang=all, fruc={ true }, url="Modern%20Event%20Deck%202014"},--Modern Event Deck 2014
[809]={id=809, lang=all, fruc={ true }, url="From%20the%20Vault:%20Annihilation"},--From the Vault: Annihilation
[807]={id=807, lang=all, fruc={ true }, url="Conspiracy"},--Conspiracy
[805]={id=805, lang=all, fruc={ true }, url="Duel%20Decks:%20Jace%20vs.%20Vraska"},--Duel Decks: Jace vs. Vraska
--[804] = "Challenge Deck: Battle the Horde";
--[803] = "Challenge Deck: Face the Hydra";
[801]={id=801, lang=all, fruc={ true }, url="Commander%202013"},--Commander 2013
[799]={id=799, lang=all, fruc={ true }, url="Duel%20Decks:%20Heroes%20vs.%20Monsters"},--Duel Decks: Heroes vs. Monsters
[798]={id=798, lang=all, fruc={ true }, url="From%20the%20Vault:%20Twenty"},--From the Vault: Twenty
[796]={id=796, lang=all, fruc={ true }, url="Modern%20Masters"},--Modern Masters
[794]={id=794, lang=all, fruc={ true }, url="Duel%20Decks:%20Sorin%20vs.%20Tibalt"},--Duel Decks: Sorin vs. Tibalt
[792]={id=792, lang=all, fruc={ true }, url="Commander%27s%20Arsenal"},--Commander's Arsenal
[790]={id=790, lang=all, fruc={ true }, url="Duel%20Decks:%20Izzet%20vs.%20Golgari"},--Duel Decks: Izzet vs. Golgari
[789]={id=789, lang=all, fruc={ true }, url="From%20the%20Vault:%20Realms"},--From the Vault: Realms
[787]={id=787, lang=all, fruc={ true }, url="Planechase%202012"},--Planechase 2012
[785]={id=785, lang=all, fruc={ true }, url="Duel%20Decks:%20Venser%20vs.%20Koth"},--Duel Decks: Venser vs. Koth
[783]={id=783, lang=all, fruc={ true }, url="Premium%20Deck%20Series:%20Graveborn"},--Premium Deck Series: Graveborn
[781]={id=781, lang=all, fruc={ true }, url="Duel%20Decks:%20Ajani%20vs.%20Nicol%20Bolas"},--Duel Decks: Ajani vs. Nicol Bolas
[780]={id=780, lang=all, fruc={ true }, url="From%20the%20Vault:%20Legends"},--From the Vault: Legends
[778]={id=778, lang=all, fruc={ true }, url="Commander"},--Commander
[777]={id=777, lang=all, fruc={ true }, url="Duel%20Decks:%20Knights%20vs.%20Dragons"},--Duel Decks: Knights vs. Dragons
[774]={id=774, lang=all, fruc={ true }, url="Premium%20Deck%20Series:%20Fire%20&%20Lightning"},--Premium Deck Series: Fire & Lightning
[772]={id=772, lang=all, fruc={ true }, url="Duel%20Decks:%20Elspeth%20vs.%20Tezzeret"},--Duel Decks: Elspeth vs. Tezzeret
[771]={id=771, lang=all, fruc={ true }, url="From%20the%20Vault:%20Relics"},--From the Vault: Relics
[769]={id=769, lang=all, fruc={ true }, url="Archenemy"},--Archenemy
[768]={id=768, lang=all, fruc={ true }, url="Duels%20of%20the%20Planeswalkers%20Decks"},--Duels of the Planeswalkers Decks
[766]={id=766, lang=all, fruc={ true }, url="Duel%20Decks:%20Phyrexia%20vs.%20The%20Coalition"},--Duel Decks: Phyrexia vs. The Coalition
[764]={id=764, lang=all, fruc={ true }, url="Premium%20Deck%20Series:%20Slivers"},--Premium Deck Series: Slivers
[763]={id=763, lang=all, fruc={ true }, url="Duel%20Decks:%20Garruk%20vs.%20Liliana"},--Duel Decks: Garruk vs. Liliana
[761]={id=761, lang=all, fruc={ true }, url="Planechase"},--Planechase
[760]={id=760, lang=all, fruc={ true }, url="From%20the%20Vault:%20Exiled"},--From the Vault: Exiled
[757]={id=757, lang=all, fruc={ true }, url="Duel%20Decks:%20Divine%20vs.%20Demonic"},--Duel Decks: Divine vs. Demonic
[755]={id=755, lang=all, fruc={ true }, url="Duel%20Decks:%20Jace%20vs.%20Chandra"},--Duel Decks: Jace vs. Chandra
[753]={id=753, lang=all, fruc={ true }, url="From%20the%20Vault:%20Dragons"},--From the Vault: Dragons
[740]={id=740, lang=all, fruc={ true }, url="Duel%20Decks:%20Elves%20vs.%20Goblins"},--Duel Decks: Elves vs. Goblins
[675]={id=675, lang=all, fruc={ true }, url="Coldsnap%20Theme%20Decks"},--Coldsnap Theme Decks
[636]={id=636, lang=all, fruc={ true }, url="Salvat-Hachette"},--Salvat-Hachette
[635]={id=635, lang=all, fruc={ true }, url="Salvat-Hachette%202011"},--Salvat-Hachette 2011
[600]={id=600, lang=all, fruc={ true }, url="Unhinged"},--Unhinged
[490]={id=490, lang=all, fruc={ true }, url="Deckmasters"},--Deckmasters
[440]={id=440, lang=all, fruc={ true }, url="Beatdown"},--Beatdown
[415]={id=415, lang=all, fruc={ true }, url="Starter%202000"},--Starter 2000
[405]={id=405, lang=all, fruc={ true }, url="Battle%20Royale"},--Battle Royale
[390]={id=390, lang=all, fruc={ true }, url="Starter%201999"},--Starter 1999
[380]={id=380, lang=all, fruc={ true }, url="Portal%20Three%20Kingdoms"},--Portal Three Kingdoms
[340]={id=340, lang=all, fruc={ true }, url="Anthologies"},--Anthologies
--[235] = "Multiverse Gift Box";
[320]={id=320, lang=all, fruc={ true }, url="Unglued"},--Unglued
[310]={id=310, lang=all, fruc={ true }, url="Portal%20Second%20Age"},--Portal Second Age
[260]={id=260, lang=all, fruc={ true }, url="Portal"},--Portal
[225]={id=225, lang=all, fruc={ true }, url="Introductory%20Two-Player%20Set"},--Introductory Two-Player Set
[201]={id=201, lang={ [3]=true, [4]=true, [5]=true }, fruc={ true }, url={ "Renaissance", "Rinascimento" } },--Renaissance
[200]={id=200, lang=all, fruc={ true }, url="Chronicles"},--Chronicles
[106]={id=106, lang=all, fruc={ true }, url="International%20Edition"},--International Edition
[105]={id=105, lang=all, fruc={ true }, url="Collectors%27%20Edition"},--Collectors' Edition
[70] ={id= 70, lang=all, fruc={ true }, url="Vanguard"},--Vanguard
[69] ={id= 69, lang=all, fruc={ true }, url="Oversized%20Box%20Toppers"},--Oversized Box Toppers
-- promosets
[50] ={id= 50, lang=all, fruc={ true }, url="Buy%20a%20Box%20Promos"},--Buy a Box Promos
[45] ={id= 45, lang=all, fruc={ true }, url="Magic%20Premiere%20Shop%20Promos"},--Magic Premiere Shop Promos
--[ 43] = "Two-Headed Giant Promos";
--[ 42] = "Summer of Magic Promos";
[41] ={id= 41, lang=all, fruc={ true }, url="Happy%20Holidays%20Promos"},--Happy Holidays Promos
[40] ={id= 40, lang=all, fruc={ true }, url="Arena%20League%20Promos"},--Arena League Promos
--[ 33] = "Championships Prizes";
--[ 32] = "Pro Tour Promos";
[0]={id=  0, lang=all, fruc={ true }, url="Pro%20Tour%201996:%20Mark%20Justice"},--Pro Tour 1996: Mark Justice
[0]={id=  0, lang=all, fruc={ true }, url="Pro%20Tour%201996:%20Michael%20Locanto"},--Pro Tour 1996: Michael Locanto
[0]={id=  0, lang=all, fruc={ true }, url="Pro%20Tour%201996:%20Bertrand%20Lestree"},--Pro Tour 1996: Bertrand Lestree
[0]={id=  0, lang=all, fruc={ true }, url="Pro%20Tour%201996:%20Preston%20Poulter"},--Pro Tour 1996: Preston Poulter
[0]={id=  0, lang=all, fruc={ true }, url="Pro%20Tour%201996:%20Eric%20Tam"},--Pro Tour 1996: Eric Tam
[0]={id=  0, lang=all, fruc={ true }, url="Pro%20Tour%201996:%20Shawn%20Regnier"},--Pro Tour 1996: Shawn Regnier
[0]={id=  0, lang=all, fruc={ true }, url="Pro%20Tour%201996:%20George%20Baxter"},--Pro Tour 1996: George Baxter
[0]={id=  0, lang=all, fruc={ true }, url="Pro%20Tour%201996:%20Leon%20Lindback"},--Pro Tour 1996: Leon Lindback
--[ 31] = "Grand Prix Promos";
[30] ={id= 30, lang=all, fruc={ true }, url="Friday%20Night%20Magic%20Promos"},--Friday Night Magic Promos
[27] ={id= 27, lang=all, fruc={ true }, url={ "APAC%20Lands", "Guru%20Lands", "Euro%20Lands" } },--Alternate Art Lands: APAC Lands, Guru Lands, Euro Lands
[26] ={id= 26, lang=all, fruc={ true }, url="Game%20Day%20Promos"},--Game Day Promos
[25] ={id= 25, lang=all, fruc={ true }, url="Judge%20Rewards%20Promos"},--Judge Rewards Promos
--TODO 23 is Gateway & WPN Promos
[24] ={id= 24, lang=all, fruc={ true }, url="Champs%20%26%20States%20Promos"},--Champs & States Promos
[23] ={id= 23, lang=all, fruc={ true }, url="Gateway%20Promos"},--Gateway Promos
[22] ={id= 22, lang=all, fruc={ true }, url="Prerelease%20Promos"},--Prerelease Promos
--TODO 21 is release & launch party
[21] ={id= 21, lang=all, fruc={ true }, url="Release%20Promos"},--Release Promos
[20] ={id= 20, lang=all, fruc={ true }, url="Player%20Rewards%20Promos"},--Player Rewards Promos
--[ 15] = "Convention Promos";
[15]= {id= 15, lang=all, fruc={ true }, url="San%20Diego%20Comic-Con%202013%20Promos", --San Diego Comic-Con 2013 Promos
											"San%20Diego%20Comic-Con%202014%20Promos"},--San Diego Comic-Con 2014 Promos
[12] ={id= 12, lang=all, fruc={ true }, url="Hobby%20Japan%20Commemorative%20Promos"},--Hobby Japan Commemorative Promos
--[ 11] = "Redemption Program Cards";
[10] ={id= 10, lang=all, fruc={ true }, url="Junior%20Series%20Promos",--Junior Series Promos
											"Junior%20Super%20Series%20Promos",--Junior Super Series Promos
											"Japan%20Junior%20Tournament%20Promos",--Japan Junior Tournament Promos
											"Magic%20Scholarship%20Series%20Promos"},--Magic Scholarship Series Promos
[9]=  {id=  9, lang=all, fruc={ true }, url= -- "Video Game Promos";
											"Duels%20of%20the%20Planeswalkers%20Promos",--Duels of the Planeswalkers Promos
											"Oversized%206x9%20Promos"},--Oversized 6x9 Promos
[8]=  {id=  8, lang=all, fruc={ true }, url= -- "Stores Promos";
											"Walmart%20Promos"},--Walmart Promos
[7]=  {id=  7, lang=all, fruc={ true }, url= -- "Magazine Inserts"
											"The%20Duelist%20Promos",--The Duelist Promos
											"Oversized%206x9%20Promos",--Oversized 6x9 Promos
											"CardZ%20Promos",--CardZ Promos
											"TopDeck%20Promos"},--TopDeck Promos
[6]=  {id=  6, lang=all, fruc={ true }, url=-- "Comic Inserts"
											"Armada%20Comics",--Armada Comics
											"Dengeki%20Maoh%20Promos",--Dengeki Maoh Promos
											"IDW%20Promos"},--IDW Promos
[5]=  {id=  5, lang=all, fruc={ true }, url="Harper%20Prism%20Promos"},--Harper Prism Promos = "Book Inserts"
--[  4] = "Ultra Rare Cards";
[2]  ={id=  2, lang=all, fruc={ true }, url="DCI%20Promos"},--DCI Promos
-- unknown
[0]={id=  0, lang=all, fruc={ true }, url="Promos"},--Promos
[0]={id=  0, lang=all, fruc={ true }, url="Simplified%20Chinese%20Alternate%20Art%20Cards"},--Simplified Chinese Alternate Art Cards
[0]={id=  0, lang=all, fruc={ true }, url="World%20Championship%20Decks"},--World Championship Decks
[0]={id=  0, lang=all, fruc={ true }, url="WCD%201997:%20Svend%20Geertsen"},--WCD 1997: Svend Geertsen
[0]={id=  0, lang=all, fruc={ true }, url="WCD%201997:%20Jakub%20Slemr"},--WCD 1997: Jakub Slemr
[0]={id=  0, lang=all, fruc={ true }, url="WCD%201997:%20Janosch%20Kuhn"},--WCD 1997: Janosch Kuhn
[0]={id=  0, lang=all, fruc={ true }, url="WCD%201997:%20Paul%20McCabe"},--WCD 1997: Paul McCabe
[0]={id=  0, lang=all, fruc={ true }, url="WCD%201998:%20Brian%20Selden"},--WCD 1998: Brian Selden
[0]={id=  0, lang=all, fruc={ true }, url="WCD%201998:%20Randy%20Buehler"},--WCD 1998: Randy Buehler
[0]={id=  0, lang=all, fruc={ true }, url="WCD%201998:%20Brian%20Hacker"},--WCD 1998: Brian Hacker
[0]={id=  0, lang=all, fruc={ true }, url="WCD%201998:%20Ben%20Rubin"},--WCD 1998: Ben Rubin
[0]={id=  0, lang=all, fruc={ true }, url="WCD%201999:%20Jakub%20Slemr"},--WCD 1999: Jakub Šlemr
[0]={id=  0, lang=all, fruc={ true }, url="WCD%201999:%20Matt%20Linde"},--WCD 1999: Matt Linde
[0]={id=  0, lang=all, fruc={ true }, url="WCD%201999:%20Mark%20Le%20Pine"},--WCD 1999: Mark Le Pine
[0]={id=  0, lang=all, fruc={ true }, url="WCD%201999:%20Kai%20Budde"},--WCD 1999: Kai Budde
[0]={id=  0, lang=all, fruc={ true }, url="WCD%202000:%20Janosch%20uhn"},--WCD 2000: Janosch Kühn
[0]={id=  0, lang=all, fruc={ true }, url="WCD%202000:%20Jon%20Finkel"},--WCD 2000: Jon Finkel
[0]={id=  0, lang=all, fruc={ true }, url="WCD%202000:%20Nicolas%20Labarre"},--WCD 2000: Nicolas Labarre
[0]={id=  0, lang=all, fruc={ true }, url="WCD%202000:%20Tom%20Van%20de%20Logt"},--WCD 2000: Tom Van de Logt
[0]={id=  0, lang=all, fruc={ true }, url="WCD%202001:%20Alex%20Borteh"},--WCD 2001: Alex Borteh
[0]={id=  0, lang=all, fruc={ true }, url="WCD%202001:%20Tom%20van%20de%20Logt"},--WCD 2001: Tom van de Logt
[0]={id=  0, lang=all, fruc={ true }, url="WCD%202001:%20Jan%20Tomcani"},--WCD 2001: Jan Tomcani
[0]={id=  0, lang=all, fruc={ true }, url="WCD%202001:%20Antoine%20Ruel"},--WCD 2001: Antoine Ruel
[0]={id=  0, lang=all, fruc={ true }, url="WCD%202002:%20Carlos%20Romao"},--WCD 2002: Carlos Romao
[0]={id=  0, lang=all, fruc={ true }, url="WCD%202002:%20Sim%20Han%20How"},--WCD 2002: Sim Han How
[0]={id=  0, lang=all, fruc={ true }, url="WCD%202002:%20Raphael%20Levy"},--WCD 2002: Raphael Levy
[0]={id=  0, lang=all, fruc={ true }, url="WCD%202002:%20Brian%20Kibler"},--WCD 2002: Brian Kibler
[0]={id=  0, lang=all, fruc={ true }, url="WCD%202003:%20Dave%20Humpherys"},--WCD 2003: Dave Humpherys
[0]={id=  0, lang=all, fruc={ true }, url="WCD%202003:%20Daniel%20Zink"},--WCD 2003: Daniel Zink
[0]={id=  0, lang=all, fruc={ true }, url="WCD%202003:%20Peer%20Kroger"},--WCD 2003: Peer Kröger
[0]={id=  0, lang=all, fruc={ true }, url="WCD%202003:%20Wolfgang%20Eder"},--WCD 2003: Wolfgang Eder
[0]={id=  0, lang=all, fruc={ true }, url="WCD%202004:%20Gabriel%20Nassif"},--WCD 2004: Gabriel Nassif
[0]={id=  0, lang=all, fruc={ true }, url="WCD%202004:%20Manuel%20Bevand"},--WCD 2004: Manuel Bevand
[0]={id=  0, lang=all, fruc={ true }, url="WCD%202004:%20Aeo%20Paquette"},--WCD 2004: Aeo Paquette
[0]={id=  0, lang=all, fruc={ true }, url="WCD%202004:%20Julien%20Nuijten"},--WCD 2004: Julien Nuijten
[0]={id=  0, lang=all, fruc={ true }, url="Ultra-Pro%20Puzzle%20Cards"},--Ultra-Pro Puzzle Cards
[0]={id=  0, lang=all, fruc={ true }, url="Misprints"},--Misprints
[0]={id=  0, lang=all, fruc={ true }, url="Filler%20Cards"},--Filler Cards
[0]={id=  0, lang=all, fruc={ true }, url="Blank%20Cards"},--Blank Cards
[0]={id=  0, lang=all, fruc={ true }, url="2005%20Player%20Cards"},--2005 Player Cards
[0]={id=  0, lang=all, fruc={ true }, url="2006%20Player%20Cards"},--2006 Player Cards
[0]={id=  0, lang=all, fruc={ true }, url="2007%20Player%20Cards"},--2007 Player Cards
[0]={id=  0, lang=all, fruc={ true }, url="Custom%20Tokens"},--Custom Tokens
[0]={id=  0, lang=all, fruc={ true }, url="Revista%20Serra%20Promos"},--Revista Serra Promos
[0]={id=  0, lang=all, fruc={ true }, url="Your%20Move%20Games%20Tokens"},--Your Move Games Tokens
[0]={id=  0, lang=all, fruc={ true }, url="Tierra%20Media%20Tokens"},--Tierra Media Tokens
[0]={id=  0, lang=all, fruc={ true }, url="TokyoMTG%20Products"},--TokyoMTG Products
[0]={id=  0, lang=all, fruc={ true }, url="Mystic%20Shop%20Products"},--Mystic Shop Products
[0]={id=  0, lang=all, fruc={ true }, url="JingHe%20Age:%202002%20Tokens"},--JingHe Age: 2002 Tokens
[0]={id=  0, lang=all, fruc={ true }, url="JingHe%20Age:%20MtG%2010th%20Anniversary%20Tokens"},--JingHe Age: MtG 10th Anniversary Tokens
[0]={id=  0, lang=all, fruc={ true }, url="Starcity%20Games:%20Commemorative%20Tokens"},--Starcity Games: Commemorative Tokens
[0]={id=  0, lang=all, fruc={ true }, url="Starcity%20Games:%20Creature%20Collection"},--Starcity Games: Creature Collection
[0]={id=  0, lang=all, fruc={ true }, url="Starcity%20Games:%20Justin%20Treadway%20Tokens"},--Starcity Games: Justin Treadway Tokens
[0]={id=  0, lang=all, fruc={ true }, url="Starcity%20Games:%20Kristen%20Plescow%20Tokens"},--Starcity Games: Kristen Plescow Tokens
[0]={id=  0, lang=all, fruc={ true }, url="Starcity%20Games:%20Token%20Series%20One"},--Starcity Games: Token Series One
	}
--end table site.sets

--[[- card name replacement tables.

  fields are for subtables indexed by #number setid.
 { #number (setid)= #table { #string (oldname)= #string (newname), ... } , ... }
 
 @type site.namereplace
 @field [parent=#site.namereplace] #string name
]]
site.namereplace = {
--TODO KTK "Version 2" -> "Intro"
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
["The Destined"]				= "REL",
["The Champion"]				= "MGD",
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
 @field [parent=#site.variants] #boolean override	(optional) if true, defaults from LHpi.Data will not be used at all
 @field [parent=#site.foiltweak] #table foilstatus
]]
site.foiltweak = {
} -- end table site.foiltweak

--[[- wrapper function for expected table 
 Wraps table site.expected, so we can wait for LHpi.Data to be loaded before setting it.
 This allows to read LHpi.Data.sets[setid].cardcount tables for less hardcoded numbers. 

 @function [parent=#site] SetExpected
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
--- pset defaults to LHpi.Data.sets[setid].cardcount.reg, if available and not set otherwise here.
--  LHpi.Data.sets[setid]cardcount has 6 fields you can use to avoid hardcoded numbers here: { reg, tok, both, nontr, repl, all }.

--- if EXPECTTOKENS is true, LHpi.Data.sets[setid].cardcount.tok is added to pset default.
-- a boolean will set this for all languges, a table will be assumed to be of the form { [langid]=#boolean, ... }
-- @field [parent=#site.expected] #boolean or #table { #boolean,...} tokens
	tokens = true,
--	tokens = { [1]="ENG" },
--	tokens = { "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR",[12]="HEB",[13]="ARA",[14]="LAT",[15]="SAN",[16]="GRC" }
--- if EXPECTNONTRAD is true, LHpi.Data.sets[setid].cardcount.nontrad is added to pset default.
-- a boolean will set this for all languges, a table will be assumed to be of the form { [langid]=#boolean, ... }
-- @field [parent=#site.expected] #boolean nontrad
	nontrad = true,
--- if EXPECTREPL is true, LHpi.Data.sets[setid].cardcount.repl is added to pset default.
-- a boolean will set this for all languges, a table will be assumed to be of the form { [langid]=#boolean, ... }
-- @field [parent=#site.expected] #boolean replica
	replica = true,
	}--end table site.expected
end--function site.SetExpected()
--EOF