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
@copyright 2014-2015 Christian Harms except parts by Goblin Hero, Stromglad1 or woogerboy21
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
Initial release, no changelog yet
* separated price data retrieval from LHpi.magickartenmarkt.lua
]]

-- options unique to this script
-- @field #table MODE
--MODE=nil
--MODE = { download=true, sets="standard" }
--MODE = { boostervalue=true, sets="standard" }
local standard ={--standard + MM15
			[822] = "Magic Origins",
			[819] = "Modern Masters 2015",
			[818] = "Dragons of Tarkir",
			[816] =	"Fate Reforged",
			[813] = "Khans of Tarkir",
			}
local newBFZ ={--825,823,824,826
 [825] = "Battle for Zendikar";
 [826] = "Zendikar Expeditions";
 [824] = "Duel Decks: Zendikar vs. Eldrazi";
 [823] = "From the Vault: Angels";
			}

MODE = { download=true, sets=newBFZ }
--MODE = { boostervalue=true, sets=fetchedsets }

--  Don't change anything below this line unless you know what you're doing :-) --

---	read source data from #string savepath instead of site url; default false
--	helper.GetSourceData normally overrides OFFLINE switch from LHpi.magickartenmarkt.lua.
--	This forces the script to stay in OFFLINE mode. Only really useful for testing.
-- @field [parent=#global] #boolean STAYOFFLINE
--STAYOFFLINE = true

--- save a local copy of each individual card source json to #string savepath if not in OFFLINE mode; default false
--	helper.GetSourceData normally overrides SAVEHTML switch from LHpi.magickartenmarkt.lua to enforce SAVEDATA.
--	SAVECARDDATA instructs the script to save not only the (reconstructed) set sources, but also the individual card sources
--	where the priceGuide field is fetched from. Only really useful for testing.
-- @field [parent=#global] #boolean SAVECARDDATA
SAVECARDDATA = true

--- when running helper.ExpectedBoosterValue, also give the EV of a full Booster Box.
-- @field [parent=#global] #boolean BOXEV
BOXEV = false

--- global working directory to allow operation outside of MA\Prices hierarchy
-- @field [parent=#global] workdir
workdir="src\\" 
-- workdir="Prices\\" -- this is default in LHpi lib

--- revision of the LHpi library to use
-- @field #string libver
local libver = "2.15"
--- revision of the LHpi library datafile to use
-- @field #string dataver
local dataver = "7"
--- sitescript revision number
-- @field string scriptver
local scriptver = "1"
--- should be similar to the script's filename. Used for loging and savepath.
-- @field #string scriptname
local scriptname = "LHpi.mkm-helper-v".. libver .. "." .. dataver .. "." .. scriptver .. ".lua"
--- savepath for OFFLINE (read) and SAVEHTML (write). must point to an existing directory relative to MA\\Prices.
-- set by LHpi lib unless specified here.
-- @field  #string savepath
--local savepath = string.gsub( scriptname , "%-v%d+%.%d+%.lua$" , "" ) .. "\\"
local savepath = savepath or "..\\..\\..\\Magic Album\\Prices\\LHpi.magickartenmarkt\\"
--FIXME remove savepath prefix for release
--- log file name. can be set explicitely via site.logfile or automatically.
-- defaults to LHpi.log unless SAVELOG is true.
-- @field #string logfile
--local logfile = string.gsub( scriptname , "lua$" , "log" )
local logfile = logfile or nil

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
--TODO filenameoptions to select mode (downloadl-std,downloadl-all,boostervalue-std,boostervalue-all)
	if mode==nil then
		error("set global MODE to select what the helper should do.")
	end
	if "table" ~= type (mode) then
		local m=mode
		mode = { [m]=true }
	end
	
	local sets
	if "string"==type(mode.sets) then
		mode.sets=string.lower(mode.sets)
		-- continue when dummyMA is loaded
	else
		sets = mode.sets or {}
	end

	
	package.path = workdir..'lib\\ext\\?.lua;' .. package.path
	package.cpath= workdir..'lib\\bin\\?.dll;' .. package.cpath
	--print(package.path.."\n"..package.cpath)	
	if not ma then
	-- define ma namespace to recycle code from sitescripts and dummy.
		if tonumber(libver)>2.14 and not (_VERSION == "Lua 5.1") then
			print("Loading dummyMA.lua for ma namespace and functions...")
			dummymode = "helper"
			dofile(workdir.."lib\\dummyMA.lua")
		else
			error("need libver>2.14 and Lua version 5.2.")
		end -- if libver
	end -- if not ma
	site = { scriptname=scriptname, dataver=dataver, logfile=logfile or nil, savepath=savepath or nil }
	LHpi = dofile(workdir.."lib\\LHpi-v"..libver..".lua")
	LHpi.Log( "LHpi lib is ready for use." ,1)
	dofile(workdir.."LHpi.magickartenmarkt.lua")
	site.logfile =string.gsub(LHpi.logfile,"src\\","")
	site.savepath=helper.savepath
	site.Initialize({helper=true})
	print("mode="..LHpi.Tostring(mode))

	if mode.sets=="all" then
		sets=site.sets
	elseif ( mode.sets=="std" ) or ( mode.sets=="standard" ) then
		sets = { -- standard as of July 2015
			[822] = "Magic Origins",
			[818] = "Dragons of Tarkir",
			[816] =	"Fate Reforged",
			[813] = "Khans of Tarkir",
			[808] = "Magic 2015",
			[806] = "Journey into Nyx",
			[802] = "Born of the Gods",
			[800] = "Theros",
		}
	elseif ( mode.sets=="cur" ) or ( mode.sets=="current" ) then
		sets = { 
			[822] = "Magic Origins",
			[819] = "Modern Masters 2015",
			[818] = "Dragons of Tarkir",
			[816] =	"Fate Reforged",
			[813] = "Khans of Tarkir",
		}
	elseif ( mode.sets=="cor" ) or ( mode.sets=="core" ) or ( mode.sets=="coresets" ) then
		sets = dummy.coresets
	elseif ( mode.sets=="exp" ) or ( mode.sets=="expansions" ) or ( mode.sets=="expansionsets" ) then
		sets = dummy.expansionsets
	elseif ( mode.sets=="spc" ) or ( mode.sets=="special" ) or ( mode.sets=="specialsets" ) then
		sets = dummy.specialsets
	elseif ( mode.sets=="pro" ) or ( mode.sets=="promo" ) or ( mode.sets=="promosets" ) then
		sets = dummy.promosets
	end

	if mode.helper then
		return ("mkm-helper running in helper mode (passive)")
	elseif mode.testoauth then
		-- basic tests (remember to set local mkmtokenfile = "mkmtokens.example" in LHpi.magickartenmarkt.lua!)
		DEBUG=true
		helper.OAuthTest( site.oauth.params )
		return ("testoauth done")
	elseif mode.download then
		helper.GetSourceData(sets)
		return ("download done")
	elseif mode.boostervalue then
		helper.ExpectedBoosterValue(sets)
		return("boostervalue done")
	end
	
	return("mkm-helper.main() finished")
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
	if STAYOFFLINE~=true then
		OFFLINE=false
	end
	SAVEHTML=true
	local seturls={}
	LHpi.Log("Building table of set-urls..." ,1)
	if sets then
		for sid,set in pairs(sets) do
			local urls = site.BuildUrl( sid )
			for url,details in pairs(urls) do
				seturls[url]=details
			end--for url
		end--for sid,set
	else -- fetch list of available expansions and download all
		sets = site.FetchExpansionList()
		sets = Json.decode(sets).expansion
		for _,exp in pairs(sets) do
			local request = site.BuildUrl( exp )
			if string.find(exp.name,"Janosch") or string.find(exp.name,"Jakub") or string.find(exp.name,"Peer") then
				print(exp.name .. " encoding Problem results in 401 Unauthorized")
				LHpi.Log(exp.name .. " skipped.")
			else--this is what should happen
				seturls[request]={oauth=true}
			end--401 exceptions
		end--for _,exp
	end--if sets

--	print("OFFLINE "..tostring(OFFLINE))
--	for url,details in pairs(seturls) do
--		print(url .. " : " .. LHpi.Tostring(details))
--	end
--	if true then return end
	local totalcount={fetched=0, found=0 }
	for url,details in pairs(seturls) do
		local setdata = LHpi.GetSourceData( url , details )
		if setdata then
			local count= { fetched=0, found=0 }
			url = string.gsub(url, '[/\\:%*%?<>|"]', "_")
			LHpi.Log( "Backup source to file: \"" .. (LHpi.savepath or "") .. "BACKUP-" .. url .. "\"" ,1)
			ma.PutFile( (LHpi.savepath or "") .. "BACKUP-" .. url , setdata , 0 )
			LHpi.Log("integrating priceGuide entries into " .. url ,1)
			print("integrating priceGuide entries into " .. url)
			setdata = Json.decode(setdata)
			for cid,card in pairs(setdata.card) do
				local cardurl = site.BuildUrl(card)
				print("fetching single card from " .. cardurl)
				local s2=SAVEHTML
				if SAVECARDDATA~=true then
					SAVEHTML=false
				end
				--local proddata,status = site.FetchSourceDataFromOAuth( cardurl )
				--TODO try/catch block here?
				local proddata,status = LHpi.GetSourceData( cardurl , { oauth=true } )
				SAVEHTML=s2
				if proddata then
					count.fetched=count.fetched+1
					proddata = Json.decode(proddata).product
				end--if proddata
				if proddata.priceGuide~=nil then
					count.found=count.found+1
					setdata.card[cid].priceGuide=proddata.priceGuide
				end
			end--for cid,card
			setdata = Json.encode(setdata)
			LHpi.Log( "Saving rebuilt source to file: \"" .. (LHpi.savepath or "") .. url .. "\"" ,1)
			LHpi.Log( string.format("%i cards have been fetched, and %i pricesGuides were found. LHpi.Data claims %i cards in set %q.",count.fetched,count.found,LHpi.Data.sets[details.setid].cardcount.all,LHpi.Data.sets[details.setid].name ) ,1)
			print( "Saving rebuilt source to file: \"" .. (LHpi.savepath or "") .. url .. "\"")
			ma.PutFile( (LHpi.savepath or "") .. url , setdata , 0 )
			totalcount.fetched=totalcount.fetched+count.fetched
			totalcount.found=totalcount.found+count.found
		else
			LHpi.Log("no data from "..url ,1)
			print("no data from "..url ,1)
		end--if setdata
	end--for url,details
	OFFLINE=o
	SAVEHTML=s
	print( string.format("%i cards have been fetched, and %i pricesGuides were found.",totalcount.fetched,totalcount.found) )
	LHpi.Log( string.format("%i cards have been fetched, and %i pricesGuides were found.",totalcount.fetched,totalcount.found) ,1)
	local counter = ma.GetFile(workdir.."\\requestcounter")
	LHpi.Log("Persistent request counter now is at "..counter ,1)
	print("Persistent request counter now is at "..counter ,1)
end--function GetSourceData

--[[- determine the Expected Value of a booster from chosen sets.
 site.sets could be used as parameter, but any table with MA setids as index can be used.
 This may be incorrect and/or nor work at all for (older) sets with nonstandard booster contents. 
 
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
				sourcedata = Json.decode(sourcedata)
				sourcedata = sourcedata.card
				for _,card in pairs(sourcedata) do
					if not card.category then
						print(sid .. " :not card.category!")
						print(LHpi.Tostring(card))
					else
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
							else
								print(string.format("no priceGuide in setid %i, skipping %s",sid,LHpi.Data.sets[sid].name))
								LHpi.Log(string.format("no priceGuide in setid %i, skipping %s",sid,LHpi.Data.sets[sid].name) ,1)
								break
							end--if card.priceGuide
						end--if card.category.categoryName
					end--if not card.category
				end--for _,card
			else
				print("no data for ["..sid.."] ")
				LHpi.Log("no data for ["..sid.."] " ,1)
			end--if sourcedata1
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
				if values["Mythic"] then
					values.EV[ptype].RMonly=(values["Rare"].average[ptype]*7/8)+(values["Mythic"].average[ptype]/8)
				else
					values.EV[ptype].RMonly=values["Rare"].average[ptype]
				end
				values.EV[ptype].MRUC=values.EV[ptype].RMonly+(values["Uncommon"].average[ptype]*3)+(values["Common"].average[ptype]*10)
--TODO dynamically check whether to add Landslot
				--values.EV[ptype].MRUCL=values.EV[ptype].MRUC+values["Land"].average[ptype]
			end--for ptype,_
			--print(sid .. " : Rare " .. LHpi.Tostring(values["Rare"]) .. " Mythic " .. LHpi.Tostring(values["Mythic"]))
--TODO dynamically build resultstrings from available price categories
			resultstrings[sid].rareSlot=(string.format("%20s: EW RareSlot AVG=%2.3f SELL=%2.3f TREND=%2.3f LOWEX=%2.3f",set,values.EV.AVG.RMonly,values.EV.SELL.RMonly,values.EV.TREND.RMonly,values.EV.LOWEX.RMonly))
			resultstrings[sid].booster=(string.format("%20s: EW Booster  AVG=%2.3f SELL=%2.3f TREND=%2.3f LOWEX=%2.3f",set,values.EV.AVG.MRUC,values.EV.SELL.MRUC,values.EV.TREND.MRUC,values.EV.LOWEX.MRUC))
			if BOXEV then
				resultstrings[sid].boxRares=(string.format("%20s: Box RareSlot AVG=%2.3f SELL=%2.3f TREND=%2.3f LOWEX=%2.3f",set,36*values.EV.AVG.RMonly,36*values.EV.SELL.RMonly,36*values.EV.TREND.RMonly,36*values.EV.LOWEX.RMonly))
				resultstrings[sid].box=(string.format("%20s: EW Full Box  AVG=%2.3f SELL=%2.3f TREND=%2.3f LOWEX=%2.3f",set,36*values.EV.AVG.MRUC,36*values.EV.SELL.MRUC,36*values.EV.TREND.MRUC,36*values.EV.LOWEX.MRUC))
			end--if BOXEV
		end--if values
		--return("early")
	end--for sid,set
--TODO sort sets by sid before looping
	for sid,result in pairs(resultstrings) do
		print(result.rareSlot)
		LHpi.Log(result.rareSlot ,0)
	end--for sid
	print()
	LHpi.Log("" ,0)
	for sid,result in pairs(resultstrings) do
		print(result.booster)
		LHpi.Log(result.booster ,0)
	end--for sid
	if BOXEV then
		print()
		LHpi.Log("" ,0)
		for sid,result in pairs(resultstrings) do
			print(result.boxRares)
			LHpi.Log(result.boxRares ,0)
		end--for sid
		print()
		LHpi.Log("" ,0)
		for sid,result in pairs(resultstrings) do
			print(result.box)
			LHpi.Log(result.box ,0)
		end--for sid
	end--if BOXEV	
end--function ExpectedBoosterValue

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

	params.oauth_timestamp = params.oauth_timestamp or tostring(os.time())
	params.oauth_nonce = params.oauth_nonce or Crypto.hmac.digest("sha1", tostring(math.random()) .. "random" .. tostring(os.time()), "keyyyy")

print(params.url)
	local baseString = "GET&" .. LHpi.OAuthEncode( params.url ) .. "&"
	print(baseString)
	local paramString = "oauth_consumer_key=" .. LHpi.OAuthEncode(params.oauth_consumer_key) .. "&"
					..	"oauth_nonce=" .. LHpi.OAuthEncode(params.oauth_nonce) .. "&"
					..	"oauth_signature_method=" .. LHpi.OAuthEncode(params.oauth_signature_method) .. "&"
					..	"oauth_timestamp=" .. LHpi.OAuthEncode(params.oauth_timestamp) .. "&"
					..	"oauth_token=" .. LHpi.OAuthEncode(params.oauth_token) .. "&"
					..	"oauth_version=" .. LHpi.OAuthEncode(params.oauth_version) .. ""
	paramString = LHpi.OAuthEncode(paramString)
	print(paramString)
	baseString = baseString .. paramString
	print(baseString)
	local signingKey = LHpi.OAuthEncode(params.appSecret) .. "&" .. LHpi.OAuthEncode(params.accessTokenSecret)
	print(signingKey)--ok until here
	local rawSignature = Crypto.hmac.digest("sha1", baseString, signingKey, true)
	print(rawSignature)
	local signature = Base64.encode( rawSignature )
	print(signature)
	local authString = "Authorization: Oauth "
		..	"realm=\"" .. LHpi.OAuthEncode(params.url) .. "\", "
		..	"oauth_consumer_key=\"" .. LHpi.OAuthEncode(params.oauth_consumer_key) .. "\", "
		..	"oauth_nonce=\"" .. LHpi.OAuthEncode(params.oauth_nonce) .. "\", "
		..	"oauth_signature_method=\"" .. LHpi.OAuthEncode(params.oauth_signature_method) .. "\", "
		..	"oauth_timestamp=\"" .. LHpi.OAuthEncode(params.oauth_timestamp) .. "\", "
		..	"oauth_token=\"" .. LHpi.OAuthEncode(params.oauth_token) .. "\", "
		..	"oauth_version=\"" .. LHpi.OAuthEncode(params.oauth_version) .. "\", "
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

--run main function
local retval = main(MODE)
print(LHpi.Tostring(retval))
--EOF