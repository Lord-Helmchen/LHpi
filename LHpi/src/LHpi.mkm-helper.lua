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

--- select a mode of operation (and a set of sets to operate on)
-- Modes are selected by setting a #boolean true.
-- these modes are exclusive, and checked in the listed order:
-- mode.helper			only initialize mkm-helper without it doing anything
-- mode.testoauth		test the OAuth implementation
-- mode.download		fetch data for mode.sets from MKM
-- mode.boostervalue	estimate the Expected Value of booster from mode.sets
-- additional, nonexclusive modes:
-- mode.resetcounter 	resets LHpi.magickartenmarkt.lua's persistent MKM request counter.
-- 						MKM's server will respond with http 429 errors after 5.000 requests.
--	 					It resets the request count at at 0:00 CE(S)T, so we would want to be able to start counting at 0 again. 
-- mode.sets			can be a table { #number setid = #string ,... }, a set id or set name, or one of the predefined strings
-- 						"standard", "core", "expansion", "special", "promo"
-- 
-- Additionally, command line arguments will be parsed for known modes and set strings.
-- Both may interfere with the MODE you set here.
-- 
-- @field #table MODE
--MODE = { download=true, sets="standard" }
MODE=nil
local MODE={ test=true }

--- how long before stored price info is considered too old.
-- To help with MKM's daily request limit, and because MKM and MA sets do not map one-to-one,
-- helper.GetSourceData keeps a persistent list of urls and when the url was last fetched from MKM.
-- If the Data age is less than DATASTALEAGE seconds, the url will be skipped.
-- See also #boolean COUNTREQUESTS and #boolean COUNTREQUESTS in LHpi.magickartenmarkt.lua
-- @field #boolean DATASTALEAGE
--local DATASTALEAGE = 60*60*24 -- one day
local DATASTALEAGE = 60*60*24*7
--local DATASTALEAGE = 60

--  Don't change anything below this line unless you know what you're doing :-) --

---	read source data from #string savepath instead of site url; default false
--	helper.GetSourceData normally overrides OFFLINE switch from LHpi.magickartenmarkt.lua.
--	This forces the script to stay in OFFLINE mode.
--	Only really useful for testing with SAVECARDDATA.
-- @field #boolean STAYOFFLINE
--local STAYOFFLINE = true

--- save a local copy of each individual card source json to #string savepath if not in OFFLINE mode; default false
--	helper.GetSourceData normally overrides SAVEHTML switch from LHpi.magickartenmarkt.lua to enforce SAVEDATA.
--	SAVECARDDATA instructs the script to save not only the (reconstructed) set sources, but also the individual card sources
--	where the priceGuide field is fetched from.
--	Only really useful for testing with STAYOFFLINE.
-- @field #boolean SAVECARDDATA
--local SAVECARDDATA = true

--- when running helper.ExpectedBoosterValue, also give the EV of a full Booster Box.
-- @field #boolean BOXEV
local BOXEV = false

--- global working directory to allow operation outside of MA\Prices hierarchy
-- @field [parent=#global] workdir
--workdir="src\\"
workdir=".\\"
--FIXME check what needs to be set here when operating in MA\Prices. Should be nil
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
--local scriptname = "LHpi.mkm-helper-v".. libver .. "." .. dataver .. "." .. scriptver .. ".lua"
local scriptname = string.gsub(arg[0],"%.lua","-v".. libver .. "." .. dataver .. "." .. scriptver .. ".lua")
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

---	command line arguments can set MODE and MODE.sets.
-- need to declare here for scope.
-- @field #table params
local params
--- @field #table knownModes
local knownModes = {
	["helper"]=true,
	["testoauth"]=true,
	["download"]=true,
	["boostervalue"]=true,
	["resetcounter"]=true,
	}

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
	error( scriptname .. " does not work from within MA. Please run it with LHpi.mkm-helper.bat and use LHpi.magickartenmarkt.lua in OFFLINE mode!" )
end -- function ImportPrice

function main( mode )
--TODO filenameoptions to select mode (downloadl-std,downloadl-all,boostervalue-std,boostervalue-all)
	if mode==nil then
		error("set global MODE or supply cmdline arguments to select what the helper should do.")
	end
	if "table" ~= type (mode) then
		local m=mode
		mode = { [m]=true }
	end
	-- load libraries
	package.path = workdir..'lib\\ext\\?.lua;' .. package.path
	package.cpath= workdir..'lib\\bin\\?.dll;' .. package.cpath
	--print(package.path.."\n"..package.cpath)	
	if not ma then
	-- define ma namespace to recycle code from sitescripts and dummy.
		if tonumber(libver)>2.14 and not (_VERSION == "Lua 5.1") then
			print("Loading LHpi.dummyMA.lua for ma namespace and functions...")
			dummymode = "helper"
			dofile(workdir.."lib\\LHpi.dummyMA.lua")
		else
			error("need libver>2.14 and Lua version 5.2.")
		end -- if libver
	end -- if not ma
	site = { scriptname=scriptname, dataver=dataver, logfile=logfile or nil, savepath=savepath or nil }
	LHpi = dofile(workdir.."lib\\LHpi-v"..libver..".lua")
	LHpi.Log( "LHpi lib is ready for use." ,1)

	-- parse MODE and args for set definitions
	local sets = {}
	local function setStringToTable(setString)
		setString = string.lower(setString)
		local setNum = tonumber(setString)
		if setNum and LHpi.Data.sets[setNum] then
			print(string.format("recognized setid %i for %s",setNum,LHpi.Data.sets[setNum].name))
			LHpi.Log(string.format("recognized setid %i for %s",setNum,LHpi.Data.sets[setNum].name) ,2)
			local s = {}
			s[setNum] = LHpi.Data.sets[setNum].name
			return s
		elseif setString=="all" then
			return site.sets
		elseif ( setString=="std" ) or ( setString=="standard" ) then
			return { -- standard as of September 2015
				[825] = "Battle for Zendikar";
				[822] = "Magic Origins",
				[818] = "Dragons of Tarkir",
				[816] =	"Fate Reforged",
				[813] = "Khans of Tarkir",
			}
		elseif ( setString=="cor" ) or ( setString=="core" ) or ( setString=="coresets" ) then
			return dummy.coresets
		elseif ( setString=="exp" ) or ( setString=="expansions" ) or ( setString=="expansionsets" ) then
			return dummy.expansionsets
		elseif ( setString=="spc" ) or ( setString=="special" ) or ( setString=="specialsets" ) then
			return dummy.specialsets
		elseif ( setString=="pro" ) or ( setString=="promo" ) or ( setString=="promosets" ) then
			return dummy.promosets
		-- add more set strings here
		--elseif ( setString=="mod" ) or ( setString=="modern" ) then
		else
			--TODO scan for TLA
			for sid,set in pairs(LHpi.Data.sets) do
				if setString == string.lower(set.name) then
					print(string.format("recognized setname %q",setString))
					local s = {}
					s[sid] = set.name
					return s
				end--if
			end--for
		end--if setString
		print(string.format("set definition not recognized: %s",setString))
		LHpi.Log(string.format("! set definition not recognized: %s",setString) ,1)
		return {}
	end--local function addSets
	if "table"==type(mode.sets) then
		sets = mode.sets
	elseif "string"==type(mode.sets) or "number"==type(mode.sets) then
		sets = dummy.mergetables( sets, setStringToTable(mode.sets) )
	end
	for i,p in pairs(params) do
		--print(i..":"..p)
		if knownModes[p] then
			LHpi.Log( "skip mode string" ,2)
		else
			sets = dummy.mergetables( sets, setStringToTable(p) )
		end
		arg[i]=nil
	end--for
	print("mode="..LHpi.Tostring(mode))
	print("sets="..LHpi.Tostring(sets))

	-- load LHpi.magickartenmarkt in helper mode
	dofile(workdir.."LHpi.magickartenmarkt.lua")
	site.logfile =string.gsub(LHpi.logfile,"src\\","")
	site.savepath=helper.savepath
	site.Initialize({helper=true})

	if mode.test then
		print("mkm-helper experiments mode")
		print("arg: "..LHpi.Tostring(arg))
	end--mode.test

	if mode.resetcounter then
		LHpi.Log("0",0,workdir.."\\lib\\LHpi.mkm.requestcounter",0)
	end--mode.resetcounter
	if mode.helper then
		return ("mkm-helper running in helper mode (passive)")
	end--mode.helper
	if mode.testoauth then
		print('basic OAuth tests (remember to set local mkmtokenfile = "LHpi.mkm.tokens.example" in LHpi.magickartenmarkt.lua!)')
		LHpi.Log('basic OAuth tests (remember to set local mkmtokenfile = "LHpi.mkm.tokens.example" in LHpi.magickartenmarkt.lua!)' ,0)
		DEBUG=true
		helper.OAuthTest( site.oauth.params )
		return ("testoauth done")
	end--mode.testoauth
	if mode.download then
		helper.GetSourceData(sets)
		return ("download done")
	end--mode.download
	if mode.boostervalue then
		helper.ExpectedBoosterValue(sets)
		return("boostervalue done")
	end--mode.boostervalue
	
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
	local dataAge = Json.decode( ma.GetFile(workdir.."\\lib\\LHpi.mkm.offlinedataage") )
	-- ["#string url"] = { timestamp = #number, requests = #number }
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
	else -- fetch list of available expansions and select all for download
		sets = site.FetchExpansionList()
		sets = Json.decode(sets).expansion
		for _,exp in pairs(sets) do
			local request = site.BuildUrl( exp )
			if string.find(exp.name,"Janosch") or string.find(exp.name,"Jakub") or string.find(exp.name,"Peer") then
				print(exp.name .. " encoding Problem results in 401 Unauthorized")
				LHpi.Log(exp.name .. " skipped." ,1)
			else--this is what should happen
				seturls[request]={oauth=true}
			end--401 exceptions
		end--for _,exp
	end--if sets

	local totalcount={fetched=0, found=0 }
	for url,details in pairs(seturls) do
		if not dataAge[url] then
			dataAge[url]={timestamp=0}
		end
		if os.time()-dataAge[url].timestamp>DATASTALEAGE then
			print(string.format("refreshing stale data for %s, last fetched on %s",url,os.date("%c",dataAge[url].timestamp)))
			LHpi.Log(string.format("refreshing stale data for %s, last fetched on %s",url,os.date("%c",dataAge[url].timestamp)) ,0)
			local reqCountPre=ma.GetFile(workdir.."\\lib\\LHpi.mkm.requestcounter")
			local reqPrediction = reqCountPre+(dataAge[url].requests or 1)
			if reqPrediction < 5000 then
				local setdata = LHpi.GetSourceData( url , details )
				if setdata then
					local count= { fetched=0, found=0 }
					local fileurl = string.gsub(url, '[/\\:%*%?<>|"]', "_")
					--LHpi.Log( "Backup source to file: \"" .. (LHpi.savepath or "") .. "BACKUP-" .. fileurl .. "\"" ,1)
					--ma.PutFile( (LHpi.savepath or "") .. "BACKUP-" .. fileurl , setdata , 0 )
					LHpi.Log("integrating priceGuide entries into " .. fileurl ,1)
					print("integrating priceGuide entries into " .. fileurl)
					setdata = Json.decode(setdata)
					for cid,card in pairs(setdata.card) do
						local cardurl = site.BuildUrl(card)
						print("fetching single card from " .. cardurl)
						local s2=SAVEHTML
						if SAVECARDDATA~=true then
							SAVEHTML=false
						end
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
					LHpi.Log( "Saving rebuilt source to file: \"" .. (LHpi.savepath or "") .. fileurl .. "\"" ,1)
					LHpi.Log( string.format("%i cards have been fetched, and %i pricesGuides were found. LHpi.Data claims %i cards in set %q.",count.fetched,count.found,LHpi.Data.sets[details.setid].cardcount.all,LHpi.Data.sets[details.setid].name ) ,1)
					print( "Saving rebuilt source to file: \"" .. (LHpi.savepath or "") .. fileurl .. "\"")
					ma.PutFile( (LHpi.savepath or "") .. fileurl , setdata , 0 )
					totalcount.fetched=totalcount.fetched+count.fetched
					totalcount.found=totalcount.found+count.found
				else
					LHpi.Log("no data from "..url ,1)
					print("no data from "..url)
				end--if setdata
				local reqCountPost=ma.GetFile(workdir.."\\lib\\LHpi.mkm.requestcounter")
				dataAge[url].requests=reqCountPost-reqCountPre
				dataAge[url].timestamp=os.time()
			else-- reqPredition > 5000
				print(string.format("Fetching data for %s would result in %s requests (%i total for today). Skipping url to prevent http 429 errors. ",url,(dataAge[url].requests or "unknown"),reqPrediction))
				LHpi.Log(string.format("Fetching data for %s would result in %s requests (%i total for today). Skipping url to prevent http 429 errors. ",url,(dataAge[url].requests or "unknown"),reqPrediction) ,0)
			end--if requests < 5000
		else
			print(string.format("data for %s was fetched on %s and is still fresh.",url,os.date("%c",dataAge[url].timestamp)))
			LHpi.Log(string.format("data for %s was fetched on %s and is still fresh.",url,os.date("%c",dataAge[url].timestamp)) ,0)
		end
		ma.PutFile(workdir.."\\lib\\LHpi.mkm.offlinedataage", Json.encode( dataAge,{ indent = true } ) ,0)
	end--for url,details
	OFFLINE=o
	SAVEHTML=s
	ma.PutFile(workdir.."\\lib\\LHpi.mkm.offlinedataage", Json.encode( dataAge,{ indent = true } ) ,0)
	print( string.format("%i cards have been fetched, and %i pricesGuides were found.",totalcount.fetched,totalcount.found) )
	LHpi.Log( string.format("%i cards have been fetched, and %i pricesGuides were found.",totalcount.fetched,totalcount.found) ,1)
	local counter = ma.GetFile(workdir.."\\lib\\LHpi.mkm.requestcounter") or "zero"
	LHpi.Log("Persistent request counter now is at "..counter ,1)
	print("Persistent request counter now is at "..counter)
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

-- read cmdline parameters
if MODE==nil then MODE={} end
params={...}
for i,p in pairs(params) do
	if "string"==type(p) then
		p=string.lower(p)
	end
	--print(i..":"..p)
	if knownModes[p] then
		MODE[p] = true
	end--if known
end--for
-- cmdline args will be checked for known sets in main
--run main function
local retval = main(MODE)
print(LHpi.Tostring(retval))
--EOF