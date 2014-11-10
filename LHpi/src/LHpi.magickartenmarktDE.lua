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

-- @field [parent=#global] #boolean CHECKEXPECTED
CHECKEXPECTED = false

--  Don't change anything below this line unless you know what you're doing :-) --

--- also complain if drop,namereplace or foiltweak count differs; default false
-- @field [parent=#global] #boolean STRICTEXPECTED
STRICTEXPECTED = true

--- if true, exit with error on object type mismatch, else use object type 0 (all)
-- @field [parent=#global] boolena STRICTOBJTYPE
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
DEBUG = true

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
scriptname = "LHpi.magickartenmarktDE-v".. libver .. "." .. dataver .. "." .. scriptver .. ".lua"
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
	site.Initialize() -- keep site-specific stuff out of ImportPrice
	LHpi.DoImport (importfoil , importlangs , importsets)
	ma.Log( "End of Lua script " .. scriptname )
end -- function ImportPrice

--[[- prepare script
 Do stuff here that needs to be done between loading the Library and calling LHpi.DoImport.
 At this point, LHpi's functions are avalable, but default values for missing fields have not yet been set.
 
 for LHpi.mkm, we need to configure and prepare the oauth client.
 @function [parent=#site] Initialize
]]
function site.Initialize()
--TODO generalize library (c)path
	package.path = 'D:\\Magic - The Gathering\\LHpi.git\\LHpi\\src\\lib\\ext\\?.lua;' .. package.path
	package.cpath= 'D:\\Magic - The Gathering\\LHpi.git\\LHpi\\src\\lib\\bin\\?.dll;' .. package.cpath
	--print(package.path.."\n"..package.cpath)
	Json = require ("dkjson")
	---@field [parent=#site] #table oauth
	site.oauth = {}
	site.oauth.client, site.oauth.params = site.PrepareOAuth()
	--site.OAuthTest( site.oauth.params )
	--local oldsavepath = savepath
	--if not savepath then savepath="src\\lib\\" end
	local expansionList = site.FetchExpansionList()
	site.ParseExpansions(expansionList, site.oauth.params.responseFormat )
	--savepath = oldsavepath
end

--[[- sets all oauth raleted options and prepares the oauth-client.
ideally, tokens/secrets should be read from a file instead of being hardcoded.

 @function [parent=#site] PrepareOAuth
 @return client			OAuth instance
 @return #table params	oauth parameters
]]
function site.PrepareOAuth()
	--sandbox = true
	local mkmexample = false
	local widgetonly = true
	--print("require starts now")
	OAuth = require "OAuth"
	--TODO local mkmtokens = require "mkmtokens"
	-- tokens/secrets should be read from an external file
	
	local params = {
		--responseFormat = "xml",
		responseFormat = "json",
		oauth_version = "1.0",
		oauth_consumer_key = "zFtb7cIpfgkknFlf", -- MKM "App Token"
		oauth_token = "", -- public resource: the oauth_token parameter in the Authorization header is empty 
		oauth_signature_method = "HMAC-SHA1",
		appSecret = "qu1kSFihbGmz6fSveNWmKVQ5KDmCj4J8", -- MKM "App Secret"
		accessTokenSecret = "",
	}
	if not widgetonly then
		params.oauth_token = "fdYLsAa0yUEEkxvHiKABovSy397bt22S" -- MKM "Access Token"
		params.accessTokenSecret = "qsWAYhLaOPLlwm2MixBhplCvXa5Zsmci" -- MKM "Access Token Secret"
	end
	if sandbox then
		local params = {
			--responseFormat = "xml",
			responseFormat = "json",
			oauth_version = "1.0",
			oauth_consumer_key = "OoPQCj8ANLIC1pQB", -- MKM "App Token"
			oauth_token = "", -- public resource: the oauth_token parameter in the Authorization header is empty 
			oauth_signature_method = "HMAC-SHA1",
			appSecret = "157EcRurGiey8Z0qZF7dN86xODMoCFq3", -- MKM "App Secret"
			accessTokenSecret = "",
		}
		if not widgetonly then
			params.oauth_token = "dQ7Dx0qwI1DedOcIwmxORRSl33wfwGJq" -- MKM "Access Token"
			params.accessTokenSecret = "2X5ez81iQUSq8Ld0pRG3eARIQHk3z1tX" -- MKM "Access Token Secret"
		end
	end--if sandox
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
	--client.SetToken( client, params.oauth_token )
	client:SetToken( params.oauth_token )
	--client.SetTokenSecret(client, params.accessTokenSecret)
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
	if DEBUG then
		print("site.FetchSourceDataFromOAuth started for url " .. url )
		url = "https://" .. url
		print("BuildRequest:")
		--local headers, arguments, post_body = site.oauth.client.BuildRequest( site.oauth.client, "GET", url )
		local headers, arguments, post_body = site.oauth.client:BuildRequest( "GET", url )
		print("headers=", LHpi.Tostring(headers))
		print("arguments=", LHpi.Tostring(arguments))
		print("post_body=", LHpi.Tostring(post_body))
		--error("stopped before actually contacting the server")
		print("PerformRequest:")
	end
	--local code, headers, status, body = site.oauth.client.PerformRequest( site.oauth.client, "GET", url )
	local code, headers, status, body = site.oauth.client:PerformRequest( "GET", url )
	if code == 200 or code == 204 then
		print("status=", LHpi.Tostring(status))
	--TODO HTTP/1.1 404 Not Found
	-- and other non-ok codes
	else
		print("code=" .. LHpi.Tostring(code))
		print("headers=", LHpi.Tostring(headers))
		print("status=", LHpi.Tostring(status))
		print("body=", LHpi.Tostring(body))
		--error (LHpi.Tostring(statusline))
	end
		return body, status
end--function site.FetchSourceDataFromOAuth

--[[- fetch list of expansions from mkmapi
 @function [parent=#site] FetchExpansionList
 @return #string list		List of expansions, in xml or json format
]]
function site.FetchExpansionList()
	local xmldata
	local format = site.oauth.params.responseFormat or "xml"
	local url = "www.mkmapi.eu/ws/v1.1"
 	if sandbox then
 		url = "sandbox.mkmapi.eu/ws/v1.1"
 	end
	url = url .. "/output." .. format .. "/expansion/1"
	local urldetails={ oauth=true }
	xmldata = LHpi.GetSourceData ( url , urldetails )
	return xmldata
end--function

--[[- Parse list of expansions and prepare a site.sets template
 @function [parent=#site] ParseExpansionList
 @param #string list		List of expansions, as returned from site.FetchExpansionList
 @param #string format	"xml" or "json"
 @return nil, but saves to file
]]
function site.ParseExpansions(list,format)
	if not dummy then error("ParseExpansions needs to be run from dummyMA!") end
	local file = "setsTemplate.txt"
	local expansions
	if format == "json" then
		expansions = Json.decode(list).expansion
	else
		error("nothing here for xml yet")
	end
	local setcats = { "coresets", "expansionsets", "specialsets", "promosets" }
	--local setNames = dummy.mergetables ( dummy.coresets, dummy.expansionsets, dummy.specialsets, dummy.promosets )
	LHpi.Log("-- ".. file,0,file,0)
	for _,setcat in ipairs(setcats) do
--		print("setcat",setcat)
		local setNames = dummy[setcat]
		local revSets = {}
		for id,name in pairs(setNames) do
			revSets[name] = id
		end--for id,name
		local sets,sortSets = {},{}
--print("expansions",LHpi.Tostring(expansions))
--print("setnames",LHpi.Tostring(setNames))
		for i,expansion in pairs(expansions) do
			if revSets[expansion.name] then
				--print("found", expansion.name)
				local id = revSets[expansion.name]
				sets[id] = { id = id , name = expansion.name, url= tostring(expansion.idExpansion) }
				table.insert(sortSets,id)
				expansions[i]=nil
			else
				--print("not", expansion.name)
			end--if revSets
		end--for i,expansion
--print("sets",LHpi.Tostring(sets))
		table.sort(sortSets, function(a, b) return a > b end)
		LHpi.Log("site.sets = {",0,file )
		LHpi.Log("-- ".. setcat ,0,file)
		for i,sid in ipairs(sortSets) do
			local string = string.format("[%i]={id=%3i, lang={ true }, fruc={ true }, url=\"%s\",--%s",sid,sid,sets[sid].url,sets[sid].name)
			print(string)
			LHpi.Log(string, 0,file )
		end--for i,sid
	end--for setcat
		LHpi.Log("-- unknown" ,0,file)
		for i,expansion in pairs(expansions) do
			local string = string.format("[%i]={id=%3i, lang={ true }, fruc={ true }, url=\"%s\",--%s",0,0,expansion.idExpansion,expansion.name)
			print(string)
			LHpi.Log(string, 0,file )
		end--for i,sid

	LHpi.Log("\t}\n--end table site.sets",0,file)
end

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
		..	"realm=\"" .. params.url .. "\", "
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
	end
	local format = site.oauth.params.responseFormat or "xml"
	url = url .. "/output." .. format .. "/expansion/1"
	url = url .. "/" .. site.setprefix
		container[url] = { oauth=true }
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
--function site.ParseHtmlData( foundstring , urldetails )
--	local container={}
--	
--	--you need to split foundstring into its fields here
--	local foundnames = {}
--	local foundPrice = 0
--	local foundFoil = false
--	--then assemble the new card data
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
--	if DEBUG then
--		LHpi.Log( "site.BCDpluginPre got " .. LHpi.Tostring( card ) .. " from set " .. setid , 2 )
--	end
--
--	-- if you don't want a full namereplace table, gsubs like this might take care of a lot of fails.
--	card.name = string.gsub( card.name , "AE" , "Æ")
--	card.name = string.gsub( card.name , "Ae" , "Æ")
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
--	if DEBUG then
--		LHpi.Log( "site.BCDpluginPost got " .. LHpi.Tostring( card ) .. " from set " .. setid , 2 )
--	end
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
	[1] = {id=1, full = "English", 	abbr="ENG", url="" },
--	[3] = {id=3, full = "German", 	abbr="GER", url="" },
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
[808]={id = 808, lang = { [1]=true }, fruc = { true , true }, url = "M15"},
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
[250]={id = 250, lang = { [1]=true }, fruc = { false, true }, url = "5ED"},
[180]={id = 180, lang = { [1]=true }, fruc = { false, true }, url = "4ED"},
[141]={id = 141, lang = { [1]=true }, fruc = { false, true }, url = "RSM"},--Revised Summer Magic
[140]={id = 140, lang = { [1]=true }, fruc = { false, true }, url = "3ED"},--Revised
[139]={id = 139, lang = { [3]=true }, fruc = { false, true }, url = "RLD"},--Revised Limited Deutsch
[110]={id = 110, lang = { [1]=true }, fruc = { false, true }, url = "2ED"},--Unlimited
[100]={id = 100, lang = { [1]=true }, fruc = { false, true }, url = "LEB"},--Beta
[90] ={id =  90, lang = { [1]=true }, fruc = { false, true }, url = "LEA"},--Alpha
-- Expansions
[813]={id = 813, lang = { [1]=true }, fruc = { true , true }, url = "KTK"},--Khans of Tarkir
[806]={id = 806, lang = { [1]=true }, fruc = { true , true }, url = "JOU"},--Journey into Nyx
[802]={id = 802, lang = { [1]=true }, fruc = { true , true }, url = "Born%20of%20the%20Gods"},--Born of the Gods
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
[350]={id = 350, lang = { [1]=true }, fruc = { true , true }, url = "ULG"},--Urza's Legacy
[330]={id = 330, lang = { [1]=true }, fruc = { false, true }, url = "USG"},--Urza's Saga
[300]={id = 300, lang = { [1]=true }, fruc = { false, true }, url = "EXO"},--Exodus
[290]={id = 290, lang = { [1]=true }, fruc = { false, true }, url = "STH"},--Stronghold
[280]={id = 280, lang = { [1]=true }, fruc = { false, true }, url = "TMP"},--Tempest
[270]={id = 270, lang = { [1]=true }, fruc = { false, true }, url = "WTH"},--Weatherlight
[240]={id = 240, lang = { [1]=true }, fruc = { false, true }, url = "VIS"},--Visions
[230]={id = 230, lang = { [1]=true }, fruc = { false, true }, url = "MIR"},--Mirage
[220]={id = 220, lang = { [1]=true }, fruc = { false, true }, url = "ALL"},--Alliances
[210]={id = 210, lang = { [1]=true }, fruc = { false, true }, url = "HML"},--Homelands
[190]={id = 190, lang = { [1]=true }, fruc = { false, true }, url = "ICE"},--Ice Age
[170]={id = 170, lang = { [1]=true }, fruc = { false, true }, url = "FEM"},--Fallen Empire
[160]={id = 160, lang = { [1]=true }, fruc = { false, true }, url = "DRK"},--The Dark
[150]={id = 150, lang = { [1]=true }, fruc = { false, true }, url = "LEG"},--Legends
[130]={id = 130, lang = { [1]=true }, fruc = { false, true }, url = "ATQ"},--Antiquities
[120]={id = 120, lang = { [1]=true }, fruc = { false, true }, url = "ARN"},--Arabian Nights
-- special sets
--[812]={id=812, lang = { [1]=true }, fruc = { false, true }, url = ""},--Duel Decks: Speed vs. Cunning
--[811]={id=811, lang = { [1]=true }, fruc = { true , false}, url = ""},--Magic 2015 Clash Pack
--[810]={id=810, lang = { [1]=true }, fruc = { false, true }, url = ""},--Modern Event Deck 2014
--[809]={id=809, lang = { [1]=true }, fruc = { true , false}, url = ""},--From the Vault: Annihilation
--[807]={id=807, lang = { [1]=true }, fruc = { true , true }, url = ""},--Conspiracy
--[805]={id=805, lang = { [1]=true }, fruc = { false, true }, url = "DDM"},--Duel Decks: Jace vs. Vraska
--[804]={id=804, lang = { [1]=true }, fruc = { false, true }, url = ""},--Challenge Deck: Battle the Horde
--[803]={id=803, lang = { [1]=true }, fruc = { false, true }, url = ""},--Challenge Deck: Face the Hydra
--[801]={id = 801, lang = { [1]=true }, fruc = { true , true }, url = "C13"},--Commander 2013
--[799]={id = 799, lang = { [1]=true }, fruc = { false, true }, url = "DDL"},--Duel Decks: Heroes vs. Monsters
--[798]={id = 798, lang = { [1]=true }, fruc = { true , false}, url = "V13"},--From the Vault: Twenty
[796]={id = 796, lang = { [1]=true }, fruc = { true , true }, url = "MMA"},--Modern Masters
--[794]={id = 794, lang = { [1]=true }, fruc = { false, true }, url = "DDK"},--Duel Decks: Sorin vs. Tibalt
--[792]={id = 792, lang = { [1]=true }, fruc = { true , false}, url = "CM1"},--Commander’s Arsenal
--[790]={id = 790, lang = { [1]=true }, fruc = { false, true }, url = "DDJ"},--Duel Decks: Izzet vs. Golgari
--[789]={id = 789, lang = { [1]=true }, fruc = { true , false}, url = "V12"},--From the Vault: Realms
--[787]={id = 787, lang = { [1]=true }, fruc = { false, true }, url = "PC2"},--Planechase 2012
--[785]={id = 785, lang = { [1]=true }, fruc = { false, true }, url = "DDI"},--Duel Decks: Venser vs. Koth
--[783]={id = 783, lang = { [1]=true }, fruc = { true , false}, url = "PD3"},--Premium Deck Series: Graveborn
--[781]={id = 781, lang = { [1]=true }, fruc = { false, true }, url = "DDH"},--Duel Decks: Ajani vs. Nicol Bolas
--[780]={id = 780, lang = { [1]=true }, fruc = { true , false}, url = "V11"},--From the Vault: Legends
--[778]={id = 778, lang = { [1]=true }, fruc = { false, true }, url = "CMD"},--Commander
--[777]={id = 777, lang = { [1]=true }, fruc = { false, true }, url = "DDG"},--Duel Decks: Knights vs. Dragons
--[774]={id = 774, lang = { [1]=true }, fruc = { true , false}, url = "PD2"},--Premium Deck Series: Fire and Lightning
--[772]={id = 772, lang = { [1]=true }, fruc = { false, true }, url = "DDF"},--Duel Decks: Elspeth vs. Tezzeret
--[771]={id = 771, lang = { [1]=true }, fruc = { true , false}, url = "V10"},--From the Vault: Relics
--[769]={id = 769, lang = { [1]=true }, fruc = { false, true }, url = "ARC"},--Archenemy   
--[768]={id = 768, lang = { [1]=true }, fruc = { false, true }, url = "DPA"},--Duels of the Planeswalkers
--[766]={id = 766, lang = { [1]=true }, fruc = { false, true }, url = "DDE"},--Duel Decks: Phyrexia vs. The Coalition
--[764]={id = 764, lang = { [1]=true }, fruc = { true , false}, url = "H09"},--Premium Deck Series: Slivers
--[763]={id = 763, lang = { [1]=true }, fruc = { false, true }, url = "DDD"},--Duel Decks: Garruk vs. Liliana
--[761]={id = 761, lang = { [1]=true }, fruc = { false, true }, url = "HOP"},--Planechase
--[760]={id = 760, lang = { [1]=true }, fruc = { true , false}, url = "V09"},--From the Vault: Exiled
--[757]={id = 757, lang = { [1]=true }, fruc = { false, true }, url = "DDC"},--Duel Decks: Divine vs. Demonic
--[755]={id = 755, lang = { [1]=true }, fruc = { false, true }, url = "DD2"},--Duel Decks: Jace vs. Chandra
--[753]={id = 753, lang = { [1]=true }, fruc = { true , false}, url = "DRB"},--From the Vault: Dragons
--[740]={id = 740, lang = { [1]=true }, fruc = { false, true }, url = "EVG"},--Duel Decks: Elves vs. Goblins   
--[675]={id = 675, lang = { [1]=true }, fruc = { false, true }, url = ""},--Coldsnap Theme Decks
--[635]={id = 635, lang = { [1]=false,[4]=true,[5]=true,[7]=true }, fruc = { false, true }, url = ""},--Magic Encyclopedia
[600]={id = 600, lang = { [1]=true }, fruc = { true , true }, url = "UNH"},--Unhinged
--[490]={id = 490, lang = { [1]=true }, fruc = { false, true }, url = "DKM"},--Deckmaster
--[440]={id = 440, lang = { [1]=true }, fruc = { false, true }, url = "BTD"},--Beatdown Box Set
--[415]={id = 415, lang = { [1]=true }, fruc = { false, true }, url = "S00"},--Starter 2000   
--[405]={id = 405, lang = { [1]=true }, fruc = { false, true }, url = ""},--Battle Royale Box Set
--[390]={id = 390, lang = { [1]=true }, fruc = { false, true }, url = "S99"},--Starter 1999
[380]={id = 380, lang = { [1]=true }, fruc = { false, true }, url = "PTK"},--Portal Three Kingdoms   
--[340]={id = 340, lang = { [1]=true }, fruc = { false, true }, url = "ATH"},--Anthologies
[320]={id = 320, lang = { [1]=true }, fruc = { false, true }, url = "UGL"},--Unglued
[310]={id = 310, lang = { [1]=true }, fruc = { false, true }, url = "P02"},--Portal Second Age   
[260]={id = 260, lang = { [1]=true }, fruc = { false, true }, url = "POR"},--Portal
--[235]={id = 235, lang = { [1]=true }, fruc = { false, true }, url = ""},--Multiverse Gift Box
--[225]={id = 225, lang = { [1]=true }, fruc = { false, true }, url = ""},--Introductory Two-Player Set
--[201]={id = 201, lang = { [1]=false,[3]=true,[4]=true,[5]=true }, fruc = { false, true }, url = ""},--Renaissance
[200]={id = 200, lang = { [1]=true }, fruc = { false, true }, url = "CHR"},--Chronicles
--[106]={id = 106, lang = { [1]=true }, fruc = { true , true }, url = ""},--Collectors’ Edition (International)
--[105]={id = 105, lang = { [1]=true }, fruc = { true , true }, url = ""},--Collectors’ Edition (Domestic)
--[70] ={id =  70, lang = { [1]=true }, fruc = { false, true }, url = "VAN"},--Vanguard
--[69] ={id =  69, lang = { [1]=true }, fruc = { false, true }, url = ""},--Box Topper Cards
-- Promo Cards
--[50] ={id =  50, lang = { [1]=true }, fruc = { true }, url = ""},--Full Box Promotion
--[45] ={id =  45, lang = { [1]=true }, fruc = { true }, url = ""},--Magic Premiere Shop
--[43] ={id =  43, lang = { [1]=true }, fruc = { true }, url = ""},--Two-Headed Giant Promos
--[42] ={id =  42, lang = { [1]=true }, fruc = { true }, url = ""},--Summer of Magic Promos
--[41] ={id =  41, lang = { [1]=true }, fruc = { true }, url = ""},--Happy Holidays Promos
--[40] ={id =  40, lang = { [1]=true }, fruc = { true }, url = ""},--Arena Promos
--[33] ={id =  33, lang = { [1]=true }, fruc = { true }, url = ""},--Championships Prizes
--[32] ={id =  32, lang = { [1]=true }, fruc = { true }, url = ""},--Pro Tour Promos
--[31] ={id =  31, lang = { [1]=true }, fruc = { true }, url = ""},--Grand Prix Promos
--[30] ={id =  30, lang = { [1]=true }, fruc = { true }, url = ""},--FNM Promos
--[27] ={id =  27, lang = { [1]=true }, fruc = { true }, url = ""},--Alternate Art Lands
--[26] ={id =  26, lang = { [1]=true }, fruc = { true }, url = ""},--Game Day Promos
--[25] ={id =  25, lang = { [1]=true }, fruc = { true }, url = ""},--Judge Promos
--[24] ={id =  24, lang = { [1]=true }, fruc = { true }, url = ""},--Champs Promos
--[23] ={id =  23, lang = { [1]=true }, fruc = { true }, url = ""},--Gateway & WPN Promos
--[22] ={id =  22, lang = { [1]=true }, fruc = { true }, url = ""},--Prerelease Cards
--[21] ={id =  21, lang = { [1]=true }, fruc = { true }, url = ""},--Release & Launch Party Cards
--[20] ={id =  20, lang = { [1]=true }, fruc = { true }, url = ""},--Magic Player Rewards
--[15] ={id =  15, lang = { [1]=true }, fruc = { true }, url = ""},--Convention Promos
--[12] ={id =  12, lang = { [1]=true }, fruc = { true }, url = ""},--Hobby Japan Commemorative Cards
--[11] ={id =  11, lang = { [1]=true }, fruc = { true }, url = ""},--Redemption Program Cards
--[10] ={id =  10, lang = { [1]=true }, fruc = { true }, url = ""},--Junior Series Promos
--[9]  ={id =   9, lang = { [1]=true }, fruc = { true }, url = ""},--Video Game Promos
--[8]  ={id =   8, lang = { [1]=true }, fruc = { true }, url = ""},--Stores Promos
--[7]  ={id =   7, lang = { [1]=true }, fruc = { true }, url = ""},--Magazine Inserts
--[6]  ={id =   6, lang = { [1]=true }, fruc = { true }, url = ""},--Comic Inserts
--[5]  ={id =   5, lang = { [1]=true }, fruc = { true }, url = ""},--Book Inserts
--[4]  ={id =   4, lang = { [1]=true }, fruc = { true }, url = ""},--Ultra Rare Cards
--[2]  ={id =   2, lang = { [1]=true }, fruc = { true }, url = ""},--DCI Legend Membership
} -- end table site.sets

--[[- card name replacement tables.

  fields are for subtables indexed by #number setid.
 { #number (setid)= #table { #string (oldname)= #string , ... } , ... }
 
 @type site.namereplace
 @field [parent=#site.namereplace] #string name
]]
site.namereplace = {
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
--  LHpi.Data.sets[setid]cardcount has 6 fields you can use avoid hardcoded numbers here: { reg, tok, both, nontr, repl, all }.

--- if EXPECTTOKENS is true, LHpi.Data.sets[setid].cardcount.tok is added to pset default.
-- @field [parent=#site.expected] #boolean EXPECTTOKENS
	EXPECTTOKENS = true,
--- if EXPECTNONTRAD is true, LHpi.Data.sets[setid].cardcount.nontrad is added to pset default.
-- @field [parent=#site.expected] #boolean EXPECTNONTRAD
	EXPECTNONTRAD = true,
--- if EXPECTREPL is true, LHpi.Data.sets[setid].cardcount.repl is added to pset default.
-- @field [parent=#site.expected] #boolean EXPECTREPL
	EXPECTREPL = true,
	}--end table site.expected
end--function site.SetExpected()
--EOF