--*- coding: utf-8 -*-
--[[- LHpi magiccardmarket.eu downloader
seperate price data downloader for www.magiccardmarket.eu ,
to be used in LHpi magiccardmarket.eu sitescript's OFFLINE mode.
Needed as long as MA does not allow to load external lua libraries.
uses and needs LHpi library

Inspired by and loosely based on "MTG Mint Card.lua" by Goblin Hero, Stromglad1 and "Import Prices.lua" by woogerboy21;
who generously granted permission to "do as I like" with their code;
everything else Copyright (C) 2012-2015 by Christian Harms.
If you want to contact me about the script, try its release thread in http://www.slightlymagic.net/forum/viewforum.php?f=32

@module LHpi.helper
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
seperated price data retrival from LHpi.magickartenmarkt.lua
]]

-- options that control the script's behaviour.

local mode={}
mode.json=true
mode.xml=nil--not implemented. use json.
mode.getsets=true

--  Don't change anything below this line unless you know what you're doing :-) --

--- revision of the LHpi library to use
-- @field [parent=#global] #string libver
libver = "2.15"
--- revision of the LHpi library datafile to use
-- @field [parent=#global] #string dataver
dataver = "5"
--- sitescript revision number
-- @field [parent=#global] string scriptver
scriptver = "1"
--- should be similar to the script's filename. Used for loging and savepath.
-- @field [parent=#global] #string scriptname
scriptname = "LHpi.mkm-downloader-v".. libver .. "." .. dataver .. "." .. scriptver .. ".lua"
--- savepath for OFFLINE (read) and SAVEHTML (write). must point to an existing directory relative to MA's root.
-- set by LHpi lib unless specified here.
-- @field [parent=#global] #string savepath
--savepath = "Prices\\" .. string.gsub( scriptname , "%-v%d+%.%d+%.lua$" , "" ) .. "\\"

---	LHpi library
-- will be loaded by LoadLib()
-- @field [parent=#global] #table LHpi
LHpi = {}

--- helper namespace
-- site namespace is taken by LHpi.magickartenmarkt.lua
-- @type helper
helper={}

workdir="src\\" 
-- helper.workdir="Prices\\" -- this is default in LHpi lib


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
	ma.Log( "Called mkm download helper script instead of site script. Raising error to inform user via dialog box." )
	ma.Log( "Helper scripts should probably be in \\lib subdir to prevent this." )
	LHpi.Log( LHpi.Tostring( importfoil ) )
	LHpi.Log( LHpi.Tostring( importlangs ) )
	LHpi.Log( LHpi.Tostring( importsets ) )
	error( scriptname .. " does not work from within MA. Please run it from a seperate lua interpreter and use LHpi.magickartenmarkt.lua in OFFLINE mode!" )

end -- function ImportPrice

function main(mode)
	mode = mode or {}
	mode.helper=true
	package.path = workdir..'lib\\ext\\?.lua;' .. package.path
	package.cpath= workdir..'lib\\bin\\?.dll;' .. package.cpath
	--print(package.path.."\n"..package.cpath)
	LHpi = dofile(workdir.."lib\\LHpi-v"..libver..".lua")
	LHpi.Log( "LHpi lib is ready to use." )
	dofile(workdir.."LHpi.magickartenmarkt.lua")
	OFFLINE=false
	site.Initialize(mode)
	
	DEBUG=true
	-- primitive tests (use local mkmexample = false and local mkmtokenfile = "mkmtokens.example" in LHpi.magickartenmarkt.lua)
	--helper.OAuthTest( site.oauth.params )
	if mode.getsets then
		local expansionList = helper.FetchExpansionList()
		helper.ParseExpansions(expansionList )
	end
	print("main() finished")
end--function main




--[[- fetch list of expansions from mkmapi
 @function [parent=#helper] FetchExpansionList
 @return #string list		List of expansions, in xml or json format
]]
function helper.FetchExpansionList()
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
 @function [parent=#helper] ParseExpansionList
 @param #string list		List of expansions, as returned from helper.FetchExpansionList
 @return nil, but saves to file
]]
function helper.ParseExpansions(list)
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

--[[- test OAuth implementation
 @function [parent=#helper] OAuthTest
 @param #table params
]]
function helper.OAuthTest( params )
	print("helper.OAuthTest started")
	print("params: " .. LHpi.Tostring(params))

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

print(params.url)
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


--- define ma namespace to recycle code from sitescripts and dummy.
if not ma then
	ma={}

	--- GetFile.
	-- Returns loaded file or nil if there was an error (file not found, out of memory, etc.).
	-- For security reasons only files from the Magic Album folder can be loaded.
	-- filepath is relative to the Magic Album folder. I.e. if you call
	--  file = ma.GetFile("Prices\\test.dat")
	-- "MA_FOLDER\Prices\test.dat" will be loaded. Do not forget to use double slashes for paths.
	-- 
	-- dummy: functional. DANGER: no security implemented.
	-- 
	-- @function [parent=#ma] GetFile
	-- @param #string filepath
	-- @return #string file OR nil instead on error
	function ma.GetFile(filepath)
		print(string.format("ma.GetFile(%s)", filepath) )
		local handle,err = io.open(filepath,"r")
		if err then print("GetFile error: " .. tostring(err)) end
		local file = nil
	    if handle then
			local temp = io.input()	-- save current file
			io.input( handle )		-- open a new current file
			file = io.read( "*all" )
			io.input():close()		-- close current file
			io.input(temp)			-- restore previous current file
		end
		return file
	end--function ma.GetFile
	
	--- PutFile.
	-- Saves data to the file. For security reasons the file is placed inside the Magic Album folder.
	-- "filepath" is relative to the Magic Album folder (see GetFile description).
	-- If "append" parameter is missing or 0 - file will be overwritten.
	-- Otherwise data will be added to the end of file.
	-- 
	-- dummy: functional. DANGER: no security implemented.
	-- 
	-- @function [parent=#ma] PutFile
	-- @param #string filepath
	-- @param #string data
	-- @param #number append nil or 0 for overwrite
	function ma.PutFile(filepath, data, append)
		if not string.find(filepath,"log") then
			print(string.format("ma.PutFile(%s ,DATA, append=%q)",filepath, tostring(append) ) )
		end
		local a = append or 0
		local handle,err
		if append == 0 then
			handle,err = io.open(filepath,"w")	-- get file handle in new file mode
		else
			handle,err = io.open(filepath,"a")	-- get file handle in append mode
		end
		if err then
			print("PutFile error: " .. tostring(err))
			print("PutFile Data was: '" .. data .. "'")
		else
			local temp = io.output()	-- save current file
			io.output( handle )			-- open a new current file
			io.write( data )	
			io.output():close()			-- close current file
		    io.output(temp)				-- restore previous current file
		end
	end--function ma.PutFile

--	--- Log.
--	-- Adds debug message to Magic Album log file.
--	-- 
--	-- dummy: just prints to stdout instead.
--	-- 
--	-- @function [parent=#ma] Log
--	-- @param #string message
--	function ma.Log(message)
--		print("ma.Log\t" .. tostring(message) )
--	end--function ma.Log
	
	--- SetProgress.
	-- Sets progress bar text and position. Position is a numeric value in range 0..100.
	-- 
	-- dummy: just prints request to stdout
	-- 
	-- @function [parent=#ma] SetProgress
	-- @param #string text
	-- @param #number position	0 ... 100
	function ma.SetProgress(text, position)
		--print("ma.SetProgress\t " .. position .. " %\t: \"" .. text .. "\"")
		print(string.format("ma.SetProgress:%3.2f%%\t: %q",position,text))
	end--function ma.SetProgress
	
end--if not ma

--run main function
main(mode)
--EOF