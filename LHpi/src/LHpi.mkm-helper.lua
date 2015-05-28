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

--  Don't change anything below this line unless you know what you're doing :-) --

--- global working directory to allow operation outside of MA\Prices hierarchy
-- @field [parent=#global] workdir
workdir="src\\" 
-- workdir="Prices\\" -- this is default in LHpi lib

--- revision of the LHpi library to use
-- @field #string libver
local libver = "2.15"
--- revision of the LHpi library datafile to use
-- @field #string dataver
local dataver = "5"
--- sitescript revision number
-- @field string scriptver
local scriptver = "1"
--- should be similar to the script's filename. Used for loging and savepath.
-- @field #string scriptname
local scriptname = "LHpi.mkm-helper-v".. libver .. "." .. dataver .. "." .. scriptver .. ".lua"
--- savepath for OFFLINE (read) and SAVEHTML (write). must point to an existing directory relative to MA's root.
-- set by LHpi lib unless specified here.
-- @field  #string savepath
--local savepath = "Prices\\" .. string.gsub( scriptname , "%-v%d+%.%d+%.lua$" , "" ) .. "\\"
local savepath = workdir .. "..\\" .. "LHpi.magickartenmarkt" .. "\\"
--- log file name. can be set explicitely via site.logfile or automatically.
-- defaults to LHpi.log unless SAVELOG is true.
-- @field #string logfile
local logfile = workdir .. string.gsub( scriptname , "lua$" , "log" )

---	LHpi library
-- will be loaded by LoadLib()
-- @field [parent=#global] #table LHpi
LHpi = {}

--[[- helper namespace
 site namespace is taken by LHpi.magickartenmarkt.lua
 
 @type helper
 @field #string scriptname
 @field #string dataver
 @field #string logfile (optional)
 @field #string savepath (optional)
]]
helper={ scriptname=scriptname, dataver=dataver, logfile=logfile or nil, savepath=savepath or nil }

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
	ma.Log( "Called mkm download helper script instead of site script. Raising error to inform user via dialog box." )
	LHpi.Log( LHpi.Tostring( importfoil ) ,1)
	LHpi.Log( LHpi.Tostring( importlangs ) ,1)
	LHpi.Log( LHpi.Tostring( importsets ) ,1)
	error( scriptname .. " does not work from within MA. Please run it from a seperate Lua interpreter and use LHpi.magickartenmarkt.lua in OFFLINE mode!" )
end -- function ImportPrice

function main( mode )
--TODO select mode (downloadl-std,downloadl-all,boostervalue-std,boostervalue-all) via filenameoptions
	if mode==nil then
--		mode = { download=true, sets="standard" }
--		mode = { download=true, sets=nil }
		mode = { boostervalue=true, sets="standard" }
	end
	if "table" ~= type (mode) then
		local m=mode
		mode = { [m]=true }
	end
	
	package.path = workdir..'lib\\ext\\?.lua;' .. package.path
	package.cpath= workdir..'lib\\bin\\?.dll;' .. package.cpath
	--print(package.path.."\n"..package.cpath)
	site = { scriptname=scriptname, dataver=dataver, logfile=logfile or nil, savepath=savepath or nil }
	LHpi = dofile(workdir.."lib\\LHpi-v"..libver..".lua")
	LHpi.Log( "LHpi lib is ready to use." ,1)
	dofile(workdir.."LHpi.magickartenmarkt.lua")
	site.Initialize({helper=true})

if site.sandbox then
	LHpi.savepath = workdir .. "..\\" .. "LHpi.magickartenmarkt.sandbox" .. "\\"
end

	if mode.testoauth then
		-- basic tests (use local mkmtokenfile = "mkmtokens.example" in LHpi.magickartenmarkt.lua)
		DEBUG=true
		helper.OAuthTest( site.oauth.params )
		return ("testoauth done")
	end
	if mode.setlist then
		local expansionList = helper.FetchExpansionList()
		local file = file or "setsTemplate.txt"
		helper.ParseExpansions(expansionList,file )
		LHpi.Log("site.sets template saved to " .. file ,0)
		return ("setlist done")
	end

	local sets
	if "string"==type(mode.sets) then
		mode.sets=string.lower(mode.sets)
	end
	if mode.sets=="all" then
		sets=site.sets
	elseif ( mode.sets=="std" ) or ( mode.sets=="standard" ) then
		sets = { -- standard as of May 2015
			[818] = "Dragons of Tarkir";
			[816] =	"Fate Reforged";
			[813] = "Khans of Tarkir";
			[808] = "Magic 2015";
			[806] = "Journey into Nyx";
			[802] = "Born of the Gods";
			[800] = "Theros";
		} 
--	else
--		sets = {}
	end
	
	if mode.download then
		helper.GetSourceData(sets)
		return ("download done")
	end

	if mode.boostervalue then
		helper.ExpectedBoosterValue(sets)
		return("boostervalue done")
	end
	
	return("main() finished")
end--function main

--[[- download and save source data.
 site.sets can be used as parameter, but any table with MA setids as index can be used.
 If setlist is nil, a list of all available expansions is fetched from the server and all are downloaded.
 
 @function [parent=#helper] GetSourceData
 @param #table setlist (optional) { #number sid= #string name } list of sets to download
]]
function helper.GetSourceData(sets)
	
	ma.PutFile(LHpi.savepath .. "testfolderwritable" , "true", 0 )
	local folderwritable = ma.GetFile( LHpi.savepath .. "testfolderwritable" )
	if not folderwritable then
		error( "failed to write file to savepath " .. LHpi.savepath .. "!" )
	end -- if not folderwritable
	local s = SAVEHTML
	local o = OFFLINE
	OFFLINE=false
	SAVEHTML=true
	local seturls={}
	if sets then
		for sid,set in pairs(sets) do
			local urls = site.BuildUrl( sid )
			for url,details in pairs(urls) do
				seturls[url]=details
			end--for url
		end--for sid,set
	else -- fetch list of available expansions and download all
		sets = helper.FetchExpansionList()
		sets = Json.decode(sets).expansion
		for _,exp in pairs(sets) do
			local request = site.BuildUrl( exp )
			if string.find(exp.name,"Janosch") or string.find(exp.name,"Jakub") or string.find(exp.name,"Peer") then
				print(exp.name .. " encoding Problem results in 401 Unauthorized")
			else--this is what should happen
				seturls[request]={oauth=true}
			end--401 exceptions
		end--for _,exp
	end--if sets
	
	for url,details in pairs(seturls) do
		local setdata = LHpi.GetSourceData( url , details )
		if setdata then
			LHpi.Log("integrating priceGuide entries into " .. url ,1)
print("integrating priceGuide entries into " .. url)
			setdata = Json.decode(setdata)
			for cid,card in pairs(setdata.card) do
				local cardurl = site.BuildUrl(card)
print("fetching single card from " .. cardurl)
				local proddata,status = site.FetchSourceDataFromOAuth( cardurl )
				if proddata then
					proddata = Json.decode(proddata).product
				end--if proddata
				setdata.card[cid].priceGuide=proddata.priceGuide
			end--for cid,card
			setdata = Json.encode(setdata)
			url = string.gsub(url, '[/\\:%*%?<>|"]', "_")
			LHpi.Log( "Saving rebuilt source to file: \"" .. (LHpi.savepath or "") .. url .. "\"" ,1)
print( "Saving rebuilt source to file: \"" .. (LHpi.savepath or "") .. url .. "\"")
			ma.PutFile( (LHpi.savepath or "") .. url , setdata , 0 )
		else
			LHpi.Log("no data from "..url ,1)
print("no data from "..url ,1)
		end--if setdata
	end--for url,details
	OFFLINE=o
	SAVEHTML=s
end--function GetSourceData

--[[- fetch list of expansions from mkmapi
 @function [parent=#helper] FetchExpansionList
 @return #string list		List of expansions, in xml or json format
]]
function helper.FetchExpansionList()
	local setlist
	local url = site.BuildUrl( "list" )
	local urldetails={ oauth=true }
	setlist = LHpi.GetSourceData ( url , urldetails )
	if not setlist then
		error(string.format("Expansion list not found at %s (OFFLINE=%s)",LHpi.Tostring(url),tostring(OFFLINE)) )
	end
	return setlist
end--function FetchExpansionList

--[[- determine the Expected Value of a booster from chosen sets.
 site.sets can be used as parameter, but any table with MA setids as index can be used.
 
 @function [parent=#helper] ExpectedBoosterValue
 @param #table setlist { #number sid= #string name } list of sets to work on
]]
function helper.ExpectedBoosterValue(sets)
	local resultstrings = {}
	for sid,set in pairs(sets) do
		local values
		local urls = site.BuildUrl(sid)
		for url,details in pairs(urls) do
			local sourcedata = LHpi.GetSourceData(url,details)
			if sourcedata then
--				sourcedata = Json.decode(sourcedata).card
				sourcedata = Json.decode(sourcedata)
				for _,card in pairs(sourcedata) do
					if not card.category then
						print(sid .. " :not card.category!")
						break
					end
					resultstrings[sid]={rareSlot="",booster=""}
					if not values then values={} end
					if card.category.categoryName~="Magic Single" then
						print(LHpi.Tostring(card.category))
					else
						if not values[card.rarity] then
							values[card.rarity]={ count=0, sum={} }
						end--if not values[card.rarity]
						values[card.rarity].count=values[card.rarity].count+1
						if card.priceGuide~=nil then
							for ptype,value in pairs(card.priceGuide) do
								if not values[card.rarity].sum[ptype] then
									values[card.rarity].sum[ptype]=0
								end--if not values[card.rarity].sum[ptype]
								values[card.rarity].sum[ptype]=values[card.rarity].sum[ptype]+value
							end--for ptype,value
						end--if card.priceGuide
					end--if card.category.categoryName
				end--for _,card
			else
				print("no data for ["..sid.."] ")
			end--if sourcedata
		end--for url,details
		if values then
			for rarity,_ in pairs(values) do
				values[rarity].average={}
				for ptype,_ in pairs(values[rarity].sum) do
					values[rarity].average[ptype]=values[rarity].sum[ptype]/values[rarity].count
				end--for ptype,_
			end--for rarity,_
			values.EV={}
			for ptype,_ in pairs(values["Rare"].average) do
				values.EV[ptype]={ }
				values.EV[ptype].RMonly=(values["Rare"].average[ptype]+7/8)+(values["Mythic"].average[ptype]/8)
				values.EV[ptype].MRUC=values.EV[ptype].RMonly+(values["Uncommon"].average[ptype]*3)+(values["Common"].average[ptype]*10)
				values.EV[ptype].MRUCL=values.EV[ptype].MRUC+values["Land"].average[ptype]
			end--for ptype,_
			--print(sid .. " : Rare " .. LHpi.Tostring(values["Rare"]) .. " Mythic " .. LHpi.Tostring(values["Mythic"]))
			resultstrings[sid].rareSlot=(string.format("%20s: EW RareSlot AVG=%2.3f SELL=%2.3f TREND=%2.3f LOWEX=%2.3f",set,values.EV["AVG"].RMonly,values.EV["SELL"].RMonly,values.EV["TREND"].RMonly,values.EV["LOWEX"].RMonly))
			resultstrings[sid].booster=(string.format("%20s: EW Booster  AVG=%2.3f SELL=%2.3f TREND=%2.3f LOWEX=%2.3f",set,values.EV["AVG"].MRUCL,values.EV["SELL"].MRUCL,values.EV["TREND"].MRUCL,values.EV["LOWEX"].MRUCL))
		end--if values
		--return("early")
	end--for sid,set
	for sid,result in pairs(resultstrings) do
		print(result.rareSlot)
	end
	print()
	for sid,result in pairs(resultstrings) do
		print(result.booster)
	end
	
end--function ExpectedBoosterValue

--[[- Parse list of expansions and prepare a site.sets template.
Still leaves much to do, but it helped :)
 @function [parent=#helper] ParseExpansionList
 @param #table list		list of expansions, as returned by helper.FetchExpansionList()
 @return nil, but saves to file
]]
function helper.ParseExpansions(list,file)
	if not dummy then error("ParseExpansions needs to be run from dummyMA!") end
	local file = file or "setsTemplate.txt"
	local expansions
	if responseFormat == "xml" then
		error("nothing here for xml yet")
	else
		expansions = Json.decode(list).expansion
	end
	local setcats = { "coresets", "expansionsets", "specialsets", "promosets" }
	LHpi.Log("site.sets = {",0,file,0 )--
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
		LHpi.Log("-- ".. setcat ,0,file)--
		for i,sid in ipairs(sortSets) do
			local string = string.format("[%i]={id=%3i, lang={ true,[2]=true,[3]=true,[4]=true,[5]=true,[6]=true,[7]=true,[8]=true,[9]=true,[10]=true,[11]=true }, fruc={ true }, url=%q},--%s",sid,sid,sets[sid].url,sets[sid].name )
			print(string)
			LHpi.Log(string, 0,file )--
		end--for i,sid
	end--for setcat
		LHpi.Log("-- unknown" ,0,file)--
		for i,expansion in pairs(expansions) do
			local url=expansion.name
			local string = string.format("[%i]={id=%3i, lang={ true,[2]=true,[3]=true,[4]=true,[5]=true,[6]=true,[7]=true,[8]=true,[9]=true,[10]=true,[11]=true }, fruc={ true }, url=%q},--%s",0,0,url,expansion.name )
			print(string)
			LHpi.Log(string, 0,file )--
		end--for i,sid
		LHpi.Log("-- catchall" ,0,file)--
		local urls="{ "
		for i,expansion in pairs(expansions) do
			urls = urls .. "\"" .. expansion.name .. "\","
		end--for i,sid
		urls = urls .. "},"
		local string = string.format("[%i]={id=%3i, lang={ true,[2]=true,[3]=true,[4]=true,[5]=true,[6]=true,[7]=true,[8]=true,[9]=true,[10]=true,[11]=true }, fruc={ true }, url=%s},--%s",999,999,urls,"catchall")
		print(string)
		LHpi.Log(string, 0,file )--
	LHpi.Log("\t}\n--end table site.sets",0,file)--
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
		if DEBUG then
			print(string.format("ma.GetFile(%s)", filepath) )
		end
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
		if DEBUG then
			if not string.find(filepath,"log") then
				print(string.format("ma.PutFile(%s ,DATA, append=%q)",filepath, tostring(append) ) )
			end
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
local retval = main()
print(LHpi.Tostring(retval))
--EOF