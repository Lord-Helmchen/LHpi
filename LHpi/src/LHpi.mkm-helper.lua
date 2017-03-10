--*- coding: utf-8 -*-
--[[- LHpi magiccardmarket.eu downloader
seperate price data downloader for www.magiccardmarket.eu ,
to be used in LHpi magiccardmarket.eu sitescript's OFFLINE mode.
Needed as long as MA does not allow to load external lua libraries.
uses and needs LHpi library

Inspired by and loosely based on "MTG Mint Card.lua" by Goblin Hero, Stromglad1 and "Import Prices.lua" by woogerboy21;
who generously granted permission to "do as I like" with their code;
everything else Copyright (C) 2012-2016 by Christian Harms.
If you want to contact me about the script, try its release thread in http://www.slightlymagic.net/forum/viewforum.php?f=32

@module LHpi.helper
@author Christian Harms
@copyright 2014-2016 Christian Harms except parts by Goblin Hero, Stromglad1 or woogerboy21
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
2.17.10.5:
start work on html fetch mode
renamed helper.GetSourceData to helper.FetchAllPrices
]]

-- options unique to this script

--- select a mode of operation (and a set of sets to operate on)
-- Modes are selected by setting a #boolean true.
-- these modes are exclusive, and checked in the listed order:
-- mode.html			force html scraping as data source
-- mode.api				force mkm-api/oauth as data source
-- mode.helper			only initialize mkm-helper without it doing anything
-- mode.testoauth		test the OAuth implementation
-- mode.download		fetch data for mode.sets from MKM
-- mode.boostervalue	estimate the Expected Value of booster from mode.sets
-- mode.checkstock		load exported MA csv, fetch stock from mkm and compare
-- additional, nonexclusive modes:
-- mode.resetcounter 	resets LHpi.magickartenmarkt.lua's persistent MKM request counter.
-- 						MKM's server will respond with http 429 errors after 5.000 requests.
--	 					It resets the request count at at 0:00 CE(S)T, so we would want to be able to start counting at 0 again. 
-- mode.forcerefresh 	force download (temporarily set dataStaleAge to one hour for all sets)
-- mode.sets			can be a table { #number setid = #string ,... }, a set id, TLA or name, or one of the predefined strings
-- 						"standard", "core", "expansion", "special", "promo"
-- 
-- Additionally, command line arguments will be parsed for known modes and set strings.
-- Both may interfere with the MODE you set here.
-- 
-- @field [parent=#global] #table MODE
--MODE = { download=true, sets="standard", html=true}
--MODE={ test=true, checkstock=true }
--TODO make sure hardcoded MODE is not needed for release

--- how long before stored price info is considered too old.
-- To help with MKM's daily request limit, and because MKM and MA sets do not map one-to-one,
-- helper.FetchAllPrices keeps a persistent list of urls and when the url was last fetched from MKM.
-- If the Data age is less than dataStaleAge[setid] seconds, the url will be skipped.
-- See also #boolean COUNTREQUESTS and #boolean COUNTREQUESTS in LHpi.magickartenmarkt.lua
-- @field #table dataStaleAge
--- @field #table dataStaleAge
local dataStaleAge = {
	--["default"]	= 60*60*24, -- one day
	["default"]	= 60*60*24*7, -- one week
--	[825] = 3600*24,--"Battle for Zendikar";
--	[822] = 3600*24,--"Magic Origins",
--	[818] = 3600*24,--"Dragons of Tarkir",
--	[816] =	3600*24,--"Fate Reforged",
--	[813] = 3600*24,--"Khans of Tarkir",
--	[826] = 3600*24,--"Zendikar Expeditions";
--	[819] = 3600*24*3,--"Modern Masters 2015 Edition";
--	 [22] = 3600*24*3,--"Prerelease Promos";
--	 [21] = 3600*24*3,--"Release & Launch Parties Promos";
--	 [26] = 3600*24*3,--"Magic Game Day";
--	 [30] = 3600*24*3,--"Friday Night Magic Promos";
--	 [53] = 3600*24*3,--"Holiday Gift Box Promos";
--	 [52] = 3600*24*3,--"Intro Pack Promos";
--	 [50] = 3600*24*3,--"Full Box Promotion";
}

--- stay below mkms daily request limit
-- mkm limits api requests to 5000 per day.
-- can be set lower to be exceptionally nice to mkm's server,
-- or much higher if we have to scrape html data intead of using the api. 
--local dailyRequestLimit = 5000
local dailyRequestLimit = 100000

--- set data source
-- select either 
-- mkm-api and oauth (requires mkm api tokens and their cooperation)
-- or
-- html page scraping, because mkm is kinda dickish about it :-P
--local dataSource = { api=true, html=false }
local dataSource = { html=true, api=false }

--  Don't change anything below this line unless you know what you're doing :-) --

--- log to seperate logfile instead of LHpi.log; default false
-- @field [parent=#global] #boolean SAVELOG
SAVELOG = true

---	read source data from #string savepath instead of site url; default false
--	helper.FetchAllPrices normally overrides OFFLINE switch from LHpi.magickartenmarkt.lua.
--	This forces the script to stay in OFFLINE mode.
--	Only really useful for testing with SAVECARDDATA.
-- @field #boolean STAYOFFLINE
--local STAYOFFLINE = true

--- save a local copy of each individual card source json to #string savepath if not in OFFLINE mode; default false
--	helper.FetchAllPrices normally overrides SAVEHTML switch from LHpi.magickartenmarkt.lua to enforce SAVEDATA.
--	SAVECARDDATA instructs the script to save not only the (reconstructed) set sources, but also the individual card sources
--	where the priceGuide field is fetched from.
--	Only really useful for testing with STAYOFFLINE.
-- @field #boolean SAVECARDDATA
--local SAVECARDDATA = true

--- when running helper.ExpectedBoosterValue, also give the EV of a full Booster Box.
-- @field #boolean BOXEV
--local BOXEV = true

--- global working directory to allow operation outside of MA\Prices hierarchy
-- @field [parent=#global] workdir
workdir=".\\"

--- revision of the LHpi library to use
-- @field #string libver
local libver = "2.17"
--- revision of the LHpi library datafile to use
-- @field #string dataver
local dataver = "10"
--- sitescript revision number
-- @field string scriptver
local scriptver = "5"
--- should be similar to the script's filename. Used for loging and savepath.
-- @field #string scriptname
local scriptname = "LHpi.mkm-helper-v".. libver .. "." .. dataver .. "." .. scriptver .. ".lua"
--local scriptname = string.gsub(arg[0],"%.lua","-v".. libver .. "." .. dataver .. "." .. scriptver .. ".lua")
--- savepath for OFFLINE (read) and SAVEHTML (write). must point to an existing directory relative to MA\\Prices.
-- set by LHpi lib unless specified here.
-- @field  #string savepath
local savepath = savepath or "LHpi.magickartenmarkt\\"
--local savepath = "..\\..\\..\\Magic Album\\Prices\\LHpi.magickartenmarkt\\"
--FIXME remove savepath prefix for release
--- log file name. can be set explicitely via site.logfile or automatically.
-- defaults to LHpi.log unless SAVELOG is true.
-- @field #string logfile
--local logfile = string.gsub( scriptname , "lua$" , "log" )
local logfile = logfile or nil

---	LHpi library
-- will be loaded in main()
-- @field [parent=#global] #table LHpi
LHpi = {}

--[[- helper namespace
 site namespace is taken by LHpi.magickartenmarkt.lua
 
 @type helper
]]
helper={ scriptname=scriptname }

---	command line arguments can set MODE and MODE.sets.
-- need to declare here for scope.
-- @field #table params
local params
--- @field #table knownModes
local knownModes = {
	["html"]=true,
	["api"]=true,
	["helper"]=true,
	["testoauth"]=true,
	["download"]=true,
	["boostervalue"]=true,
	["resetcounter"]=true,
	["forcerefresh"]=true,
	["checkstock"]=true,
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
	if "table" ~= type (mode) then
		local m=mode
		mode = { [m]=true }
	end
	-- load libraries
	package.path = workdir..'lib\\ext\\?.lua;' .. package.path
	package.cpath= workdir..'lib\\bin\\?.dll;' .. package.cpath
	--print(package.path.."\n"..package.cpath)	
	if not ma then
	-- load dummyMA to define ma namespace and helper functions
		if tonumber(libver)>2.14 and not (_VERSION == "Lua 5.1") then
			print("Loading LHpi.dummyMA.lua for ma namespace and functions...")
			dummymode = "helper"
			dofile(workdir.."lib\\LHpi.dummyMA.lua")
			if tonumber(dummy.version)<0.8 then
				error("need dummyMA version > 0.7")
			end
		else
			error("need LHpi version >2.14 and Lua version 5.2.")
		end -- if libver
	end -- if not ma
	--load library now, instead of letting the sitescript configure it.
	site = { scriptname=scriptname, dataver=dataver, logfile=logfile or nil, savepath=savepath or nil }
	LHpi = dofile(workdir.."lib\\LHpi-v"..libver..".lua")
	LHpi.Log( "LHpi lib is ready for use." ,1)

	if mode==nil or next(mode)==nil then
		--error("set global MODE or supply cmdline arguments to select what the helper should do.")
		print("set global MODE or supply cmdline arguments to select what the helper should do." ,0)
		return "No MODE set for mkm-helper: doing nothing!"
	end
	-- parse MODE and args for set definitions
	local sets = {}
	local function setStringToTable(setString)
		setString = string.lower(setString)
		local setNum = tonumber(setString)
		if setNum and LHpi.Data.sets[setNum] then
			local recognizedString = string.format("recognized setid %i for %s",setNum,LHpi.Data.sets[setNum].name)
			print(recognizedString)
			LHpi.Log(recognizedString ,2)
			local s = {}
			s[setNum] = LHpi.Data.sets[setNum].name
			return s
		elseif setString=="all" then
			return dummy.MergeTables ( dummy.coresets, dummy.expansionsets, dummy.specialsets, dummy.promosets )
		elseif ( setString=="std" ) or ( setString=="standard" ) then
			return dummy.standardsets
		elseif setString=="core" then
			return dummy.coresets
		elseif setString=="expansion" or setString=="expansions" then
			return dummy.expansionsets
		elseif setString=="special" then
			return dummy.specialsets
		elseif setString=="promo" then
			return dummy.promosets
		-- add more set strings here
		--elseif ( setString=="mod" ) or ( setString=="modern" ) then
		else
			for sid,set in pairs(LHpi.Data.sets) do
				if setString == string.lower(set.tla) then
					local recognizedString = string.format("recognized TLA %q for set %q",set.tla,set.name)
					print(recognizedString)
					LHpi.Log(recognizedString ,2)
					local s = {}
					s[sid] = set.name
					return s
				elseif setString == string.lower(set.name) then
					local recognizedString = string.format("recognized setname %q",set.name)
					print(recognizedString)
					LHpi.Log(recognizedString ,2)
					local s = {}
					s[sid] = set.name
					return s
				end--if
			end--for
		end--if setString
		local recognizedString = string.format("set definition not recognized: %s",setString)
		print(recognizedString)
		LHpi.Log(recognizedString ,1)
		return {}
	end--local function addSets
	if "table"==type(mode.sets) then
		sets = mode.sets
	elseif "string"==type(mode.sets) or "number"==type(mode.sets) then
		sets = dummy.MergeTables( sets, setStringToTable(mode.sets) )
	end
	for i,p in pairs(params) do
		--print(i..":"..p)
		if knownModes[p] then
			LHpi.Log( "skip mode string" ,2)
		else
			sets = dummy.MergeTables( sets, setStringToTable(p) )
		end
		arg[i]=nil
	end--for

	-- load LHpi.magickartenmarkt in helper mode
	dofile(workdir.."LHpi.magickartenmarkt.lua")
	site.scriptname = helper.scriptname
	if mode.html then
		dataSource = { html=true, api=false }
	elseif mode.api then
		dataSource = { api=true, html=false }
	elseif not MKMDATASOURCE then
		error("MKMDATASOURCE not defined!")
	end--mode.html/mode.api
	site.Initialize({helper=true})

	if mode.test then
		print("mkm-helper experiments mode")
		print("arg: "..LHpi.Tostring(arg))
		print("mode="..LHpi.Tostring(mode))
		print("sets="..LHpi.Tostring(sets))
		print("OFFLINE="..tostring(OFFLINE))
	end--mode.test

	if mode.resetcounter then
		LHpi.Log("0",0,LHpi.savepath.."LHpi.mkm.requestcounter",0)
	end--mode.resetcounter
	if mode.forcerefresh then
		dataStaleAge = { ["default"] = 3600, } -- one hour 
	end--mode.forcerefresh
	if mode.helper then
		return ("mkm-helper running in helper mode (passive)")
	end--mode.helper
	if mode.testoauth then
		if not MKMDATASOURCE.api then
			error("MKMDATASOURCE is html!")
		end
		print('basic OAuth tests (check mkmtokenfile setting!)')
		LHpi.Log('basic OAuth tests (remember to set local mkmtokenfile = "LHpi.mkm.tokens.example" in LHpi.magickartenmarkt.lua!)' ,0)
		DEBUG=true
		helper.OAuthTest( site.oauth.params )
		return ("testoauth done")
	end--mode.testoauth
	if mode.download then
		helper.FetchAllPrices(sets)
		return ("download done")
	end--mode.download
	if mode.boostervalue then
		helper.ExpectedBoosterValue(sets)
		return("boostervalue done")
	end--mode.boostervalue
	if mode.checkstock then
		local csvfile = "..\\MAexport-mkmStock.csv"
		--local csvfile = "..\\..\\..\\Magic Album\\Prices\\MAexport-mkmStock.csv"
		local maStock = helper.LoadCSV( csvfile)
		local mkmStock = helper.GetStock()
		helper.CheckStockPrices(maStock, mkmStock)
		return ("checkstock done")
	end--mode.checkstock
	
	return("mkm-helper.main() finished")
end--function main

--[[- download and save source data.
 site.sets can be used as parameter, but any table with MA setids as index can be used.
 If setlist is nil, a list of all available expansions is fetched from the server and all are downloaded.
 
 @function [parent=#helper] FetchAllPrices
 @param #table setlist (optional) { #number sid= #string name } list of sets to download
]]
function helper.FetchAllPrices(sets)
	ma.PutFile(LHpi.savepath .. "testfolderwritable" , "true", 0 )
	local folderwritable = ma.GetFile( LHpi.savepath .. "testfolderwritable" )
	if not folderwritable then
		error( "failed to write file to savepath " .. LHpi.savepath .. "!" )
	end -- if not folderwritable
	local dataAge = ma.GetFile(savepath.."LHpi.mkm.offlinedataage")
	if dataAge then
		dataAge = Json.decode( dataAge )
	else
		local noDataAgeString = "A new file will be created. If this is the first time the script is run, this is normal."
		print (noDataAgeString)
		LHpi.Log(noDataAgeString, 1)
		dataAge={}
	end
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
		--sets = Json.decode(sets).expansion
		for _,exp in pairs(sets) do
			local urls = site.BuildUrl( exp )--call by Expansion Entity
			if string.find(exp.name,"Janosch") or string.find(exp.name,"Jakub") or string.find(exp.name,"Peer") then
				LHpi.Log(exp.name .. " encoding Problem results in 401 Unauthorized. Set skipped." ,2)
			else--this is what should happen
				for u,d in pairs(urls) do
					table.insert(seturls,u,d)
				end--for
			end--401 exceptions
		end--for _,exp
	end--if sets

	local totalcount={ fetched=0, found=0 }
	for url,details in pairs(seturls) do
		if not dataAge[url] then
			dataAge[url]={timestamp=0}
		end
		local maxAge = dataStaleAge["default"]
		--TODO dataStaleAge per set
		if dataStaleAge[sid] then
			maxAge = dataStaleAge[sid]
		end
		if os.time()-dataAge[url].timestamp>maxAge then
			print(string.format("stale data for %s was fetched on %s, refreshing...",url,os.date("%c",dataAge[url].timestamp)))
			LHpi.Log(string.format("refreshing stale data for %s, last fetched on %s",url,os.date("%c",dataAge[url].timestamp)) ,0)
			local reqCountPre=ma.GetFile(LHpi.savepath.."LHpi.mkm.requestcounter") or 0
			local reqForSet = dataAge[url].requests or LHpi.Data.sets[details.setid].cardcount.all or 1
			print(string.format(" predicted number of requests is %i",reqForSet))			
			local reqPrediction = reqCountPre+reqForSet
			if reqPrediction < dailyRequestLimit then
				local count,ok
				if MKMDATASOURCE.html then
					count,ok = helper.FetchPricesFromHtml( url,details )
				elseif HTMLDATASOURCE.api then
					count,ok = helper.FetchPriceGuidesFromAPI( url,details )
				end
				if ok then
					dataAge[url].timestamp=os.time()
				end
				totalcount.fetched=totalcount.fetched+count.fetched
				totalcount.found=totalcount.found+count.found
				local reqCountPost=ma.GetFile(LHpi.savepath.."LHpi.mkm.requestcounter")
				dataAge[url].requests=reqCountPost-reqCountPre

			else-- reqPredition > 5000
				print(string.format("Skipped %s with %s requests (today's total: %i) to prevent HTTP/429.",url,(dataAge[url].requests or "unknown"),reqPrediction))
				LHpi.Log(string.format("Fetching data for %s would result in %s requests (%i total for today). Skipping url to prevent http 429 errors.",url,(dataAge[url].requests or "unknown"),reqPrediction) ,0)
			end--if requests < 5000
		else
			print(string.format("%s fetched on %s is still fresh.",url,os.date("%c",dataAge[url].timestamp)))
			LHpi.Log(string.format("data for %s was fetched on %s and is still fresh.",url,os.date("%c",dataAge[url].timestamp)) ,0)
		end
		ma.PutFile(savepath.."LHpi.mkm.offlinedataage", Json.encode( dataAge,{ indent = true } ) ,0)
	end--for url,details
	OFFLINE=o
	SAVEHTML=s
	ma.PutFile(savepath.."LHpi.mkm.offlinedataage", Json.encode( dataAge,{ indent = true } ) ,0)
	print( string.format("%i cards have been fetched, and %i pricesGuides were found.",totalcount.fetched,totalcount.found) )
	LHpi.Log( string.format("%i cards have been fetched, and %i pricesGuides were found.",totalcount.fetched,totalcount.found) ,1)
	local counter = ma.GetFile(LHpi.savepath.."LHpi.mkm.requestcounter") or "zero"
	LHpi.Log("Persistent request counter now is at "..counter ,1)
	print("Persistent request counter now is at "..counter)
end--function FetchAllPrices

--[[- implements price fetching for a set url via html scraping.
emulate mkm api response format for save file, so MKMDATASOURCE is transparent to further processings.
 
 @function [parent=#helper] FetchPricesFromHtml
 @param #string url
 @param #table	details
 @return #table		fetchedCount	{ fetched = #number, found = #number }
 @return #boolean	ok
]]
function helper.FetchPricesFromHtml( url, details )
	local count= { fetched=0, found=0 }
	local ok = true
	local expansiontable = { expansion= {name=string.match(url,"/([^/]+)$"), idExpansion=details.setid}, card = {} }
	local cards = helper.CardsInSetFromHtml(url)
	for cardname,cardurlsuffix in pairs(cards) do
		print(string.format("name:%s : urlsuffix:%s",cardname,cardurlsuffix))
		LHpi.Log(string.format("name:%s : urlsuffix:%s",cardname,cardurlsuffix))
		local cardurl=site.BuildUrl( { idProduct=cardname, urlsuffix=cardurlsuffix } )
		for u,d in pairs(cardurl) do
			-- this is only safe because site.Buildurl( #table ) always returns a single url in the container
			cardurl = u
		end
		local cardRawData,status = LHpi.GetSourceData( cardurl , { oauth = false } )
		count.fetched=count.fetched+1
		local waitTimer=1
		while cardRawData=="" and status == "HTTP/1.1 200 OK" do
			print(string.format("! %s but no cardRawData. Wait %i seconds for (d)dos protection to calm down.",status,waitTimer))
			helper.sleep(waitTimer)
			cardRawData,status = LHpi.GetSourceData( cardurl , { oauth = false } )
			count.fetched=count.fetched+1
			waitTimer=waitTimer*2
		end--if not cardRawData

		if cardRawData and cardRawData ~= "" then
			count.found=count.found+1
			local idProduct = "faked"
			local rarity = nil
			local expansion = expansiontable.expansion.name
			local name = {{idLanguage=1, languageName="English",productName=cardname},nil}
			local priceGuide= {LOWFOIL=nil, SELL=nil ,TREND=nil ,AVG=0 ,LOW=0 ,LOWEX=nil }
			priceGuide.LOWEX = string.match(cardRawData,'Verfügbar ab %(EX%+%):</td><td.-><span itemprop="lowPrice">([%d.,]-)<')
			priceGuide.TREND = string.match(cardRawData,'Preistendenz:</td><td.-">([%d.,]-) .-</td>')
			priceGuide.LOWFOIL = string.match(cardRawData,'Foils verfügbar ab:</td><td.-">([%d.,]-) .-</td>')
			priceGuide.SELL = string.match(cardRawData,'{"label":"Durchschnittlicher Verkaufspreis".-"data":%[[%d.,]-%]}') or ""
			priceGuide.SELL = string.match(priceGuide.SELL,',([%d.]+)%]}$')
			local newCard = { rarity= rarity, expansion = expansion, name = name, priceGuide=priceGuide }
			--print(LHpi.Tostring(newCard))
			table.insert(expansiontable.card,newCard)
		else--not cardRawData
			if status == "HTTP/1.1 301 Moved Permanently" then
				print(string.format("! %s",status))
				LHpi.Log(string.format("! %s",status) ,0,"LHpi-Debug.log")
				LHpi.Log(string.format("%s : %s",cardname,cardurlsuffix) ,0,"LHpi-Debug.log")
				LHpi.Log(string.format("cardname \"%s\": %s",cardname,LHpi.ByteRep(cardname)) ,0,"LHpi-Debug.log")
				LHpi.Log(string.format("cardurlsuffix \"%s\": %s",cardurlsuffix,LHpi.ByteRep(cardurlsuffix)) ,0,"LHpi-Debug.log")
				--TODO debug 301 urls
			end
			print("!! no cardRawData - " .. status)
			ok = false
			--TODO break loop now?
		end--if cardRawData
	end--for cardname,cardurlsuffix in pairs(cards)
	LHpi.Log( string.format("%i cards have been requested, and %i cards were found. LHpi.Data claims %i cards in set %q.",count.fetched,count.found,LHpi.Data.sets[details.setid].cardcount.all,LHpi.Data.sets[details.setid].name ) ,1)

	--error("STOP and debug!")
	return count,ok
end--function FetchPricesFromHtml

--[[- first step for helper.FetchPricesFromUrl:
 build table of all cards and their individual urls
 
 @function [parent=#helper] CardsInSetFromHtml
 @param #string url
 @param #number resultsPage		mkm result page index
 @param #table cards			previously found cards for recursive call
 @return #table	cards			{ #string name = #string url }
]]
function helper.CardsInSetFromHtml(seturl,resultsPage,cards)
	if cards == nil then cards = {} end
	if resultsPage == nil then resultsPage = 0 end
	local url = seturl .. "?sortBy=number&sortDir=asc&view=list"
	if resultsPage > 0 then
		url = url .. "&resultsPage=" .. resultsPage
	end
	local trefferVon, trefferBis, trefferMax
	local setdata = LHpi.GetSourceData( url , nil )
	if setdata then
		trefferMax, trefferVon, trefferBis = string.match(setdata,">(%d+) Treffer %- Zeige Seite Nr%. %d+ %(Treffer (%d+) bis (%d+)%)<")
		trefferMax=tonumber(trefferMax)
		trefferVon=tonumber(trefferVon)
		trefferBis=tonumber(trefferBis)
		local i=0
		for urlsuffix,name in string.gmatch(setdata,'<td><a href="([^"]-)">([^<]-)</a></td><td><a href') do
			i=i+1
--			print(i .. ": " .. name .. " : " .. urlsuffix)
			urlsuffix = LHpi.urldecode(urlsuffix)
--			print("urldecoded to: " .. urlsuffix )
--			print("OAuthencoded to: " .. LHpi.OAuthEncode(urlsuffix) )
			cards[name]=urlsuffix
		end--for
		print(string.format("von %i bis %i sind %i, gefunden %i",trefferVon,trefferBis,trefferBis-trefferVon+1,i))
		if i ~= (trefferBis - trefferVon + 1) then
			error("Anzahl gefundener Karten-Urls passt nicht zur Trefferzahl!")
		end--if i
	else
		LHpi.Log("no data from "..url ,1)
		print("no data from "..url)
		--TODO revocer from empty setdata
	end--if setdata
	local cardnum = LHpi.Length(cards)
	if cardnum < trefferBis then
		print(string.format("%i cards in table, but trefferBis is %i",cardnum,trefferBis))
--		for name,urlsuffix in pairs(cards) do
--			print (name .. " : " .. urlsuffix)
--		end
		error("Anzahl gefundener Karten-Urls passt nicht zur Trefferzahl!")
	end
	if trefferBis ~= trefferMax then
		cards = helper.CardsInSetFromHtml(seturl,resultsPage+1,cards)
	end
	return cards
	--TODO count these requests, too
end--function CardsInSetFromHtml

--[[- implements price fetching for a set url via MKM API
 
 @function [parent=#helper] FetchPriceGuidesFromAPI
 @param #string url
 @param #table	details
 @return #table		fetchedCount	{ fetched = #number, found = #number }
 @return #boolean	ok
]]
function helper.FetchPriceGuidesFromAPI( url, details )
	local count= { fetched=0, found=0 }
	local ok = true
	local setdata = LHpi.GetSourceData( url , details )
	if setdata then
		local fileurl = string.gsub(url, '[/\\:%*%?<>|"]', "_")
		--LHpi.Log( "Backup source to file: \"" .. (LHpi.savepath or "") .. "BACKUP-" .. fileurl .. "\"" ,1)
		--ma.PutFile( (LHpi.savepath or "") .. "BACKUP-" .. fileurl , setdata , 0 )
		LHpi.Log("integrating priceGuide entries into " .. fileurl ,1)
		print("integrating priceGuide entries into " .. fileurl)
		setdata = Json.decode(setdata)
		local httpStatus
		for cid,card in pairs(setdata.card) do
			--local cardurl = site.BuildUrl(card)
			local cardurl
			local urls = site.BuildUrl(card)
			for u,d in pairs(urls) do
				-- this is only safe because site.Buildurl( #mkm-Entity ) always returns a single url in the container
				cardurl = u
			end
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
				if proddata.priceGuide~=nil then
					count.found=count.found+1
					setdata.card[cid].priceGuide=proddata.priceGuide
				end--if proddata.priceGuide
			else
				httpStatus = status
				break
			end--if proddata
		end--for cid,card
		if not httpStatus then
			setdata = Json.encode(setdata)
			LHpi.Log( "Saving rebuilt source to file: \"" .. (LHpi.savepath or "") .. fileurl .. "\"" ,1)
			LHpi.Log( string.format("%i cards have been fetched, and %i pricesGuides were found. LHpi.Data claims %i cards in set %q.",count.fetched,count.found,LHpi.Data.sets[details.setid].cardcount.all,LHpi.Data.sets[details.setid].name ) ,1)
			print( "Saving rebuilt source to file: \"" .. (LHpi.savepath or "") .. fileurl .. "\"")
			ma.PutFile( (LHpi.savepath or "") .. fileurl , setdata , 0 )
		else
			local skippedString = string.format("%s encountered, abort and skip %q.",httpStatus,LHpi.Data.sets[details.setid].name)
			ok = false
		end--if not httpStatus
	else
		LHpi.Log("no data from "..url ,1)
		print("no data from "..url)
		ok=false
	end--if setdata
	return count,ok
end--function FetchPriceGuidesFromAPI

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

--[[- compare my offers with mkm priceGuide prices
 @function [parent=#helper] CheckStockPrices
 @param none
]]
function helper.CheckStockPrices(maStock, mkmStock)
	for _,article in ipairs(mkmStock) do
		local foilstring = ""
		if article.isFoil then foilstring = "foil " end
		if maStock[article.set] and maStock[article.set][article.name] then
			local maCard=maStock[article.set][article.name]
			local stockedString=string.format("Stocked %ix %s%q (%s) from %q in %s for €%3.2f",article.count,foilstring,maCard.oracleName,article.condition,LHpi.Data.sets[article.set].name,LHpi.Data.languages[article.lang].abbr,article.price)
			if article.isPlayset then
				stockedString=string.gsub(stockedString,"Stocked (%d+)x","Stocked %1x Playset")
			end--if article.isPlayset
			local priceString=string.format(" latest imported card value is %s=€%3.2f, %s=€%3.2f",site.priceTypes[site.useAsRegprice].type,maCard.priceR or 0,site.priceTypes[site.useAsFoilprice].type,maCard.priceF or 0	)
			local inventoryString=string.format(" Inventorized %i regular and %i foils for €%3.2f (bought %i for €%3.2f, already sold %i)",maCard.qtyR or 0,maCard.qtyF or 0,maCard.sellPrice or 0,maCard.buyQty or 0,maCard.buyPrice or 0,maCard.sellQty or 0)
			print(stockedString)
			print(priceString)
			print(inventoryString)
			LHpi.Log(stockedString, 1)
			LHpi.Log(priceString, 1)
			LHpi.Log(inventoryString, 1)
			local qty
			if article.isFoil then
				qty=maCard.qtyF
			else
				qty=maCard.qtyR
			end--if article.isFoil
				if article.isPlayset then
					qty=qty/4
				end--if article.isPlayset
			if article.count ~= qty then
				local warnString=string.format("! %i stocked but %i inventorized!",article.count,qty)
				if article.isPlayset then
					warnString=string.gsub(warnString,"(%d+) stocked but (%d+)","%1 Playset stocked but "..qty*4)
				end--if article.isPlayset
				print(warnString)
				LHpi.Log(warnString, 1)
			end--article.count ~= qty
		else
			if not article.isFoil then foilstring = "nonfoil " end
			local string=string.format("Stocked (MKM) item not inventorized (MA): %ix %s%q (%s,%s) from %q, ",article.count,foilstring,article.name,LHpi.Data.languages[article.lang].abbr,article.condition,LHpi.Data.sets[article.set].name )
			if article.isPlayset then
				string=string.gsub(string,"%(MA%): (%d+)x","(MA): %1x Playset")
			end--if article.isPlayset
			print(string)
			LHpi.Log(string, 1)
		end--if maStock
	end--for article
end--function CheckStockPrices

--[[- fetch my stock from mkm
 @function [parent=#helper] GetStock
 @param none
 @return #table
]]
function helper.GetStock()
	local url = "mkmapi.eu/ws/v1.1/output.json/stock"
	local o=OFFLINE
	--OFFLINE=false
	local stock = LHpi.GetSourceData( url , { oauth=true } )
	if not OFFLINE then
		helper.IndentJson(LHpi.savepath.."mkmapi.eu_ws_v1.1_output.json_stock")
	end
	OFFLINE=o
	if stock then
		stock = Json.decode(stock)
	else
		error("MKM stock not found")
	end
	stock = stock.article
	local mkmStock = {}
	for i,article in ipairs(stock) do
		for sid,set in pairs(LHpi.Data.sets) do 
			article.product.expansion = string.gsub(article.product.expansion,"^Fifth","5th")
			article.product.expansion = string.gsub(article.product.expansion,"^Release Promos","Release & Launch Parties Promos")
			article.product.expansion = string.gsub(article.product.expansion,"^Buy a Box Promos","Full Box Promotion")
			article.product.expansion = string.gsub(article.product.expansion,"^Gildensturm","Gatecrash")
			article.product.expansion = string.gsub(article.product.expansion,"^Labyrinth des Drachen","Dragon's Maze")
			article.product.expansion = string.gsub(article.product.expansion,"^Reise nach Nyx","Journey into Nyx")
			article.product.expansion = string.gsub(article.product.expansion,"'","’")
			if set.name == article.product.expansion then
				article.set=sid
			end
		end--for sid,set
		if "number" ~= type(article.set) then
			error("set not found: "..article.product.expansion)
		end--if "number"
		for lid,lang in pairs(LHpi.Data.languages) do 
			if lang.full == article.language.languageName then
				article.lang=lid
			end
		end--for lid,lang
		if "number" ~= type(article.lang) then
			error("lang not found: "..article.language.languageName)
		end--if "number"
		local card = { set=article.set, name=article.product.name, condition=article.condition, isFoil=article.isFoil, lang=article.lang, count=article.count, price=article.price, isPlayset=article.isPlayset }
		table.insert(mkmStock,card)
	end
	return mkmStock
end--function GetStock

--[[- import MA export csv
 @function [parent=#helper] LoadCSV
 @param #string filename
 @return #table
]]
function helper.LoadCSV( filename )
	if not string.find(filename,".csv$") then
		filename = filename .. ".csv"
	end--if
	local csvdata = ma.GetFile(filename)
	if not csvdata then
		error("Could not open "..filename)
	end
	if csvdata:find("^\255\254") then
		error(filename.." is UCS-2/UFT-16 Little Endian. Convert to UTF-8!")
	end--if
	csvdata= csvdata:gsub( "^\239\187\191" , "" ) -- remove UTF-8 BOM if it's there
	local maData = {}
	for csvline in string.gmatch( csvdata, "(.-)\n") do
		local csvregex = "([^\t]-)\t([^\t]-)\t([^\t]-)\t([^\t]-)\t([^\t]-)\t([^\t]-)\t([^\t]-)\t([^\t]-)\t([^\t]-)\t([^\t]-)\t([^\t]-)\t([^\t]-)\t([^\t]-)\t([^\t]-)\t([^\t]-)\t([^\t]-)\t([^\t]-)\t([^\t]-)\t([^\t]-)\t([^\t]-)\t([^\t]-)\t([^\t]-)\t([^\t]-)\t([^\t]-)"
		local _,_,set,oracleName,name,version,language,qtyR,qtyF,notes,rarity,colNumber,color,cost,powTgh,artist,border,buyQty,buyPrice,sellQty,sellPrice,gradeR,gradeF,priceR,priceF = string.find( csvline , csvregex)
		local card = { set=set, oracleName=oracleName, name=name,lang=language,variant=version,qtyR=tonumber(qtyR) or 0,qtyF=tonumber(qtyF) or 0,priceR=tonumber(priceR) or 0,priceF=tonumber(priceF) or 0,buyQty=tonumber(buyQty) or 0,buyPrice=tonumber(buyPrice) or 0,sellQty=tonumber(sellQty) or 0,sellPrice=tonumber(sellPrice) or 0}
		card.set = string.gsub(card.set,"^5E$","5ED")
		if card.oracleName ~= "Name (Oracle)" then
			table.insert(maData,card)
		end--if
	end--for line
	local maStock = {}
	for i,card in ipairs(maData) do
		for sid,set in pairs(LHpi.Data.sets) do 
			if set.tla == card.set then
				card.set=sid
			end
		end--for sid,set
		if "number" ~= type(card.set) then
			error("set not found: "..card.set)
		end--if "number"
		for lid,lang in pairs(LHpi.Data.languages) do 
			if lang.abbr == card.lang then
				card.lang=lid
			end
		end--for lid,lang
		if "number" ~= type(card.lang) then
			error("lang not found: "..card.lang)
		end--if "number"
		if maStock[card.set]==nil then maStock[card.set]={} end
		maStock[card.set][card.name] = { oracleName=card.oracleName,variant=card.version,lang=card.lang,qtyR=card.qtyR,qtyF=card.qtyF,priceR=card.priceR,priceF=card.priceF}
	end--for card
	return maStock
end--function LoadCSV

--[[- recode json file with indention
 @function [parent=#helper] IndentJson
 @param #table filepath
]]
function helper.IndentJson( file )
	local tmp = ma.GetFile(file)
	if tmp then
		tmp = Json.decode(tmp)
		tmp = Json.encode (tmp, { indent = true })
		ma.PutFile(file,tmp,0)
	else
		error("source file not found!")
	end
end--function IndentJson

--[[- test OAuth implementation
 @function [parent=#helper] OAuthTest
 @param #table params
]]
function helper.OAuthTest( params )
	print("helper.OAuthTest started")
	print("params: " .. LHpi.Tostring(params))

	-- "manual" Authorization header construction
	--local Crypto = require "crypto"
	local sha1 = require "sha1"
	--local Base64 = require "base64"
	local mime = require "mime"

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
	--local rawSignature = Crypto.hmac.digest("sha1", baseString, signingKey, true)
	local rawSignature = sha1.hmac(signingKey, baseString)
	print(rawSignature)
	--local signature = Base64.encode( rawSignature )
	local signature = (mime.b64( rawSignature ))
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

	print("stopped before actually contacting the server")
--	print("PerformRequest:")
--	--local response_code, response_headers, response_status_line, response_body = client.PerformRequest( client, "GET", params.url, args )
--	local response_code, response_headers, response_status_line, response_body = client.PerformRequest( "GET", params.url, args )
--	print("code=" .. LHpi.Tostring(response_code))
--	print("headers=", LHpi.Tostring(response_headers))
--	print("status_line=", LHpi.Tostring(response_status_line))
--	print("body=", LHpi.Tostring(response_body))
end--function OAuthTest

--[[- sleep for n seconds using os.time()
 @function [parent=#helper] sleep
 @param #number s
]]
function helper.sleep(s)
  local ntime = os.time() + s
  repeat until os.time() > ntime
end

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

if not site then
	site={}
	function site.Initialize( mode )
		error("mkm-helper is not a sitescript. Initialize not implemented.")
		LHpi.Log( "mkm-helper is not a sitescript. Initialize not implemented.", 0)
	end --function Initialize
end

--run main function
local retval = main(MODE)
print(tostring(retval))
--EOF
