--*- coding: utf-8 -*-
--[[- Magic Album API dummy
to test LHpi within an IDE and without needing Magic Album

Inspired by and loosely based on "MTG Mint Card.lua" by Goblin Hero, Stromglad1 and "Import Prices.lua" by woogerboy21;
who generously granted permission to "do as I like" with their code;
everything else Copyright (C) 2012-2016 by Christian Harms.
If you want to contact me about the script, try its release thread in http://www.slightlymagic.net/forum/viewforum.php?f=32

@module LHpi.dummyMA
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
0.9
added 831,830,829,828,827,34
]]

--[[- "main" function called by Magic Album; just display error and return.
 Called by Magic Album to import prices. Parameters are passed from MA.
 We don't want to call the dummy from within MA.
 @function [parent=#global] ImportPrice
 @param #string importfoil	"Y"|"N"|"O"
 @param #table importlangs	{ #number (langid)= #string , ... }
 @param #table importsets	{ #number (setid)= #string , ... }
]]
function ImportPrice(importfoil, importlangs, importsets)
	ma.Log( "Called LHpi.dummyMA from MA. Raising error to inform user via dialog box." )
	error ("LHpi.dummyMA.lua is not an import script. Do not attempt to use it from within MA!")
end -- function ImportPrice

--[[-
Simulate MA's API functions
@type ma
]]
ma = {}
if not io then
	io = {}
	io.open = function ()  end
	io.input = function ()  end
	io.read = function ()  end
	io.output = function ()  end
	io.write = function ()  end
end

--- GetURL.
-- Returns downloaded web page or nil if there was an error (page not found, network problems, etc.).
-- 
-- dummy: uses luasockets and additionally prints status to stdout if not "200" (OK).
-- 
-- @function [parent=#ma] GetURL
-- @param #string url
-- @return #string webpage OR nil instead on error
function ma.GetUrl(url)
	print("dummy: GetUrl called for " .. url)
	local host,file = string.match(url, "http://([^/]+)/(.+)" )
	local http = require("socket.http")
	local page,status = http.request(url)
	if status~=200 then
		print("http status " .. status)
	end
	return page
end

--- GetFile.
-- Returns loaded file or nil if there was an error (file not found, out of memory, etc.).
-- For security reasons only files from the Magic Album folder can be loaded.
-- filepath is relative to the Magic Album folder. I.e. if you call
--  file = ma.GetFile("Prices\\test.dat")
-- "MA_FOLDER\Prices\test.dat" will be loaded. Do not forget to use double slashes for paths.
-- 
-- dummy: functional. DANGER: no security implemented, directory traversal attack possible.
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
	else
		local temp = io.output()	-- save current file
		io.output( handle )			-- open a new current file
		io.write( data )	
		io.output():close()			-- close current file
    	io.output(temp)				-- restore previous current file
    end
end

--- Log.
-- Adds debug message to Magic Album log file.
-- 
-- dummy: just prints to stdout instead.
-- 
-- @function [parent=#ma] Log
-- @param #string message
function ma.Log(message)
	print("ma.Log\t" .. tostring(message) )
end

--- SetPrice.
-- Set the price of the certain card.
-- setid is the numeric ID of the set. You can find all available IDs in "Database\Sets.txt" file.
-- langid is the numeric ID of the language. You can find all available IDs in "Database\Languages.txt" file.
-- cardname is the name of the card in UTF-8 encoding. Magic Album tries to match the cardname first against the Oracle Name, then against the Name field.
-- cardversion is the version of the card as it is shown in Magic Album. If set to "*" all versions of the card will be processed.
-- regprice and foilprice are the numerical values. Pass zero if you do not know or do not want to set the value.
-- objtype is an object type (1 for cards, 2 for tokens, 3 for nontraditional, 4 for inserts, 5 for replicas). This parameter is optional. Default value is 1.
-- this function returns the number of modified cards.
-- dummy: just prints request to stdout and return 1
-- 
-- Examples:
-- Set the price of foil M11 English Celestial Purge to $4.25
-- ma.SetPrice(770, 1, "Celestial Purge", "", 0, 4.25)
-- Set the regular and foil prices for all versions of M10 Russian Forests (using Russian card name)
-- ma.SetPrice(759, 2, "Лес", "*", 0.01, 0.1)
-- 
-- @function [parent=#ma] SetPrice
-- @param #number setid
-- @param #number langid
-- @param #string cardname
-- @param #string cardversion	#string "" and #string "*" is also possible
-- @param #number regprice 		#nil is also possible
-- @param #number foilprice 	#nil is also possible
-- @param #number objtype 		(optional) 0:all, 1:cards, 2:tokens, 3:nontraditional, 4:inserts, 5:replicas; default:0
-- @return #number modifiednum
function ma.SetPrice(setid, langid, cardname, cardversion, regprice, foilprice, objtype)
	if not objtype then
		objtype = 0
	end
	local dummystring=string.format('ma.SetPrice: setid=%q  langid=%q  cardname=%-30q\tcardversion=%q\tregprice=%q\tfoilprice=%q\tobjtype=%q',setid,langid,cardname,tostring(cardversion),tostring(regprice),tostring(foilprice),tostring(objtype))
	print (dummystring)
	if cardversion == "*" then
		return 4
	elseif LHpi.Length then
		return LHpi.Length(cardversion)
	end
	return 1 -- just always assume one price was set successfully
end

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
end

--- table to hold LHpi.dummyMA additional functions
-- @type dummy
dummy={}
---	dummy version
-- @field [parent=#dummy] #string version
dummy.version = "0.8"

--[[- loads LHpi library for testing.
@function [parent=#dummy] LoadLib
@param #string libver			library version to be loaded
@param #string path		(optional)
@param #string savepath	(optional)
@return #table LHpi library object
]]
function dummy.LoadLib(libver,path,savepath)
	local path = path or ""
	local savepath = savepath or ""
	if libver>2.14 and not (_VERSION == "Lua 5.1") then
		ma.Log("LoadLib is only for legacy libver < 2.14 without global workdir support!")
		ma.Log('you can simply do \'LHpi = dofile(workdir.."lib\\\\LHpi-v"..libver..".lua")\'')
		return dofile(path.."lib\\LHpi-v"..libver..".lua")
	end
	local LHpi = {}
	do -- load LHpi library from external file
		local libname = path .. "lib\\LHpi-v" .. libver .. ".lua"
		local LHpilib = ma.GetFile( libname )
		if not LHpilib then
			error( "LHpi library " .. libname .. " not found." )
		else -- execute LHpilib to make LHpi.* available
			LHpilib = string.gsub( LHpilib , "^\239\187\191" , "" ) -- remove unicode BOM (0xEF, 0xBB, 0xBF) for files tainted by it :)
			if _VERSION == "Lua 5.1" then
				-- not only do we need to change the way the library is loaded,
				-- but also how the data file is loaded from within the library
				LHpilib = string.gsub(LHpilib, 'errormsg = load','errormsg=loadstring' )
			end
			if path~="" then
				--patch library to change paths
				path = string.gsub(path,"\\","\\\\")
				LHpilib = string.gsub(LHpilib,'Prices\\\\',path )
				if savepath~="" then
					savepath = string.gsub(savepath,"\\","\\\\")
					LHpilib = string.gsub(LHpilib,'savepath = "src','savepath = "' .. savepath)
				end
			end--if path
			if VERBOSE then
				ma.Log( "LHpi library " .. libname .. " loaded and ready for execution." )
			end
			local execlib,errormsg=nil
			if _VERSION == "Lua 5.1" then
				-- we need to change the way the library is loaded
				execlib,errormsg = loadstring( LHpilib , "=(loadstring) LHpi library" )
			else
				execlib,errormsg = load( LHpilib , "=(load) LHpi library" )
			end
			if not execlib then
				error( errormsg )
			end
			LHpi = execlib()
		end	-- if not LHpilib else
	end -- do load LHpi library
	collectgarbage() -- we now have LHpi table with all its functions inside, let's clear LHpilib and execlib() from memory
	print( "LHpi lib is ready for use." )
	return LHpi
end -- function dummy.LoadLib

--[[- load and execute sitescript.
You can then call the sitescript's ImportPrice, as ma would do.
@function [parent=#dummy] LoadScript
@param #string scriptname
@param #string path		(optional)
@param #string savepath	(optional)
@return nil, but script is loaded and executed
]]
function dummy.LoadScript(scriptname,path,savepath)
	local path = path or ""
	local savepath = savepath or ""
	do
		local scriptfile = ma.GetFile( path .. scriptname )
		if not scriptfile then
			error( "script " .. scriptname .. " not found at " .. path .. "." )
		else
			local _,_,libver = string.find(scriptfile,'libver = "([%d%.]+)"')
			if tonumber(libver)>2.14 and not (_VERSION == "Lua 5.1") then
				ma.Log("LoadScript is only for legacy libver < 2.14 without global workdir support!")
				ma.Log("you can simply do \'dofile(workdir..\""..scriptname.."\")\'")
			--	dofile(path..scriptname)
			--	return
			end
			scriptfile = string.gsub( scriptfile , "^\239\187\191" , "" ) -- remove unicode BOM (0xEF, 0xBB, 0xBF) for files tainted by it :)
			if _VERSION == "Lua 5.1" then
				-- not only do we need to change the way the sitescript is loaded,
				-- but also how the library is loaded from within the sitescript
				scriptfile = string.gsub(scriptfile, 'local execlib,errormsg = load','local execlib,errormsg=loadstring')
				--but we even need to go one level deeper: change how the library loads the data file
				scriptfile = string.gsub( scriptfile, 'local execlib,errormsg=loadstring',
							'LHpilib=string.gsub(LHpilib,"errormsg = load","errormsg=loadstring") local execlib,errormsg=loadstring' )
			end
			if path~="" then
				--patch script to change paths
				path = string.gsub(path,"\\","\\\\")
				scriptfile = string.gsub(scriptfile,'Prices\\\\',path )
				if savepath~="" then
					savepath = string.gsub(savepath,"\\","\\\\")
					scriptfile = string.gsub(scriptfile,'savepath = "src','savepath = "' .. savepath)
				end
				--patch library loading to patch paths in library
				scriptfile = string.gsub( scriptfile, "local execlib,errormsg ?= ?load",
							'LHpilib=string.gsub(LHpilib,"Prices\\\\","'..path..'") local execlib,errormsg=load' )
				if savepath~="" then
					savepath = string.gsub(savepath, "\\", "\\\\" )
					scriptfile = string.gsub( scriptfile, "local execlib,errormsg ?= ?load",
								'LHpilib=string.gsub(LHpilib,"savepath = \\\"src","savepath = \\\"'..savepath..'\") local execlib,errormsg=load' )
				end
			end--if path
			local execscript,errormsg=nil
			if _VERSION == "Lua 5.1" then
				-- we need to change the way the script is loaded
				execscript,errormsg = loadstring( scriptfile , "=(loadstring)" .. scriptname )
			else
				execscript,errormsg = load( scriptfile , "=(load)" .. scriptname )
			end
			if not execscript then
				error( errormsg )
			end
			execscript()
		end--if scriptfile	
	end--do
	collectgarbage()
end--function dummy.LoadScript

--[[- fake a minimal, nonfunctional sitescript.
You can then run library functions to test them.

@function [parent=#dummy] FakeSitescript
@return nil, but site fields an functions are set.
]]
function dummy.FakeSitescript()
	site={}
	site.langs={ {id=1,url="foo"} }
	site.sets= { [0]={id=0,lang={true},fruc={true},url="bar"} }
	site.frucs={ {id=1,name="fruc",isfoil=true,isnonfoil=true,url="baz"} }
	site.regex="none"
	--dataver=8
	scriptname="LHpi.fakescript.lua"
	site.variants= { [0]= {
		["site"]			= { "inSiteOnly"		, { "one", "two" } },
		["site (1)"]		= { "inSiteOnly"		, { "one", false } },
		["site (2)"]		= { "inSiteOnly"		, { false, "two" } },
		["same"]			= { "samefromSite"		, { "one", "two" } },
		["same (1)"]		= { "samefromSite"		, { "one", false } },
		["same (2)"]		= { "samefromSite"		, { false, "two" } },
	} }
	
	function site.BuildUrl() return { ["fakeURL"] ={} } end
end--function dummy.FakeSitescript

--[[- merge up to four tables.
@function [parent=#dummy] MergeTables
@param #table teins
@param #table tzwei
@param #table tdrei	(optional)
@param #table tvier (optional)
@return #table
]]
--TODO move MergeTables from dummy to LHpi.helpers once library loads by require
function dummy.MergeTables (teins,tzwei,tdrei,tvier)
	local tmerged= {}
	for k,v in pairs(teins) do 
		tmerged[k] = v
	end
	for k,v in pairs(tzwei) do 
		tmerged[k] = v
	end
	if tdrei then
		for k,v in pairs(tdrei) do 
			tmerged[k] = v
		end
	end	 
	if tvier then
		for k,v in pairs(tvier) do 
			tmerged[k] = v
		end
	end	 
	return tmerged
end-- function dummy.MergeTables

--[[- force debug enviroment
@function [parent=#dummy] ForceEnv
@param #table env (optional)
]]
function dummy.ForceEnv(env)
	env = env or dummy.env
	VERBOSE = env.VERBOSE
	LOGDROPS = env.LOGDROPS
	LOGNAMEREPLACE = env.LOGNAMEREPLACE
	LOGFOILTWEAK = env.LOGFOILTWEAK
	CHECKEXPECTED = env.CHECKEXPECTED
	STRICTEXPECTED = env.STRICTEXPECTED
	OFFLINE = env.OFFLINE
	SAVELOG = env.SAVELOG
	SAVEHTML = env.SAVEHTML
	DEBUG = env.DEBUG
	DEBUGFOUND = env.DEBUGFOUND
	DEBUGVARIANTS = env.DEBUGVARIANTS
	SAVETABLE = env.SAVETABLE
	--legacy
	STRICTCHECKEXPECTED = nil
	DEBUGSKIPFOUND = nil
end--function dummy.ForceEnv

--[[- run and time sitescript multiple times.
@function [parent=#dummy] TestPerformance
@param #number repeats
@param #table script
@param #table impF
@param #table impL
@param #table impS
@param #string timefile (optional) default:"time.log"
]]
function dummy.TestPerformance(repeats,script,impF,impL,impS,timefile)
	timefile = timefile or "time.log"
	for run=1, repeats do
		local t1 = os.clock()
		dummy.LoadScript(script.name,script.path,script.savepath)
		dummy.ForceEnv()
		ImportPrice( impF, impL, impS )
		local dt = os.clock() - t1
		ma.PutFile(timefile,string.format("\nrun %2i: %3.3g seconds",run,dt),1)
	end--for run
end--function dummy.performancetest

--[[- compare dummy's set tables with Prices/Database/Sets.txt.
Before using this function, you need to convert Sets.txt from UCS-2 to UTF-8.
 @function [parent=#dummy] CompareDummySets
 @param #number libver
 @param #string mapath	path to MA
]]
function dummy.CompareDummySets(mapath,libver)
	if not LHpi or not LHpi.version then
		if libver < 2.15 then
			dummy.LoadLib(libver,workdir,savepath)
		else
			LHpi = dofile(workdir.."lib\\LHpi-v"..libver..".lua")
			LHpi.Log( "LHpi lib is ready for use." ,1)
		end
	else
		print("LHpi v"..LHpi.version.." already loaded as "..tostring(LHpi))
	end
	local setsTxt = ma.GetFile(workdir..mapath.."Database\\Sets.txt")
	--local s,e,firstline = string.find(setsTxt,"([^\n]+)")
	--print(LHpi.ByteRep(firstline))
	if setsTxt:find("^\255\254") then
	--TODO encountered \255\254\83 and \255\254\56 ... What's the third byte?
		LHpi.Log(workdir..mapath.."Database\\Sets.txt is UCS-2 Little Endian.\nIf you updated Magic Album recently, you probably need to convert it to UTF-8 again.")
		error(workdir..mapath.."Database\\Sets.txt is UCS-2 Little Endian.")
	end
	setsTxt= setsTxt:gsub( "^\239\187\191" , "" ) -- remove UTF-8 BOM if it's there
	local dummySets = dummy.MergeTables ( dummy.coresets, dummy.expansionsets, dummy.specialsets, dummy.promosets )
	local revDummySets = {}
	for sid,name in pairs(dummySets) do
		revDummySets[name] = sid
	end--for id,name
	local missing = {}
	for sid,name in string.gmatch( setsTxt, "(%d+)%s+([^\n]+)\n") do
		--print( string.format("sid %3i : %s",sid,name) )
		if revDummySets[name] then
			--print(string.format("found %3i : %q",sid,name) )
		else
			table.insert(missing,{ id=sid, name=name})
		end
	end
	
	LHpi.Log(#missing .. " sets from Database/Sets.txt missing in dummy:" ,0)
	for i,set in pairs(missing) do
		LHpi.Log(string.format("[%3i] = %q;",set.id,set.name) ,0)
	end
end--function CompareDummySets

--[[- compare LHpi.Data.sets with dummy's set tables.

 @function [parent=#dummy] CompareDataSets
 @param #number libver
 @param #number dataver
]]
function dummy.CompareDataSets(libver,dataver)
	if not LHpi or not LHpi.version then
		if libver < 2.15 then
			LHpi = dummy.LoadLib(libver,workdir,savepath)
		else
			LHpi = dofile(workdir.."lib\\LHpi-v"..libver..".lua")
			LHpi.Log( "LHpi lib is ready for use." ,1)
		end
	else
		print("LHpi v"..LHpi.version.." already loaded as "..tostring(LHpi))
	end
	if not LHpi.Data or not LHpi.Data.version then
		LHpi.Data = LHpi.LoadData(dataver or 5)
		LHpi.Log( "LHpi.Data is ready for use." ,1)
	else
		print("LHpi.Data v"..LHpi.Data.version.." already loaded as "..tostring(LHpi.Data))
	end
	local dummySets = dummy.MergeTables ( dummy.coresets, dummy.expansionsets, dummy.specialsets, dummy.promosets )
	local revDataSets = {}
	for sid,set in pairs(LHpi.Data.sets) do
		revDataSets[LHpi.Data.sets[sid].name] = sid
	end--for id,name
	local missing = {}
	for sid,name in pairs(dummySets) do
		--print( string.format("sid %3i : %s",sid,name) )
		if revDataSets[name] then
			--print(string.format("found %3i : %q",sid,name) )
		else
			table.insert(missing,{ id=sid, name=name})
		end
	end
	LHpi.Log(#missing .. " sets from dummy's set list missing in LHpi.Data:" ,0)
	for i,set in pairs(missing) do
		LHpi.Log(string.format("[%3i] = %q;",set.id,set.name) ,0)
	end
end--function CompareDataSets

--[[- compare site.sets with dummy.coresets, dummy.expansionsets, dummy.specialsets, dummy.promosets.
finds sets from dummy's lists that are not in site.sets.

 @function [parent=#dummy] CompareSiteSets
]]
function dummy.CompareSiteSets()
	local dummySets = dummy.MergeTables ( dummy.coresets, dummy.expansionsets, dummy.specialsets, dummy.promosets )
	local missing = {}
	if not site.sets then
		print ("site.sets is "..tostring(site.sets))
		return
	end
	for sid,name in pairs(dummySets) do
		if site.sets[sid] then
			--print(string.format("found %3i : %q",sid,name) )
		else
			table.insert(missing,{ id=sid, name=name})
		end
	end
	LHpi.Log(#missing .. " sets from dummy missing in site.sets:" ,0)
	table.sort(missing, function(a, b) return a.id > b.id end)--order descending by setid
	for i,set in pairs(missing) do
		LHpi.Log(string.format("[%3i] = %q;",set.id,set.name) ,0)
	end
	return(missing)
end--function CompareSiteSets

--[[- list expansions names that are not used as url for any set in site.sets and prepare a site.sets template.
 @function [parent=#dummy] ListUnknownUrls
 @param #table expansions		list of expansions, as returned by helper.FetchExpansionList()
 @param #string file	(optional) filename to save to, defaults to logfile
 @return nil, but saves to file
]]
function dummy.ListUnknownUrls(expansions,file)
	if file then
		LHpi.Log("site.sets = {",0,file,0 )--
	else
		-- insert to normal logfile
		LHpi.Log("-----\nTemplate for missing urls:\nsite.sets = {",0 )--
	end
	local knownUrls = {}
	for sid,set in pairs(site.sets) do
		if "table"==type(set.url) then
			for _,url in ipairs(set.url) do
				knownUrls[url]=true
			end
		else
			knownUrls[set.url]=true
		end
	end
	for i,expansion in pairs(expansions) do
		if knownUrls[expansion.urlsuffix] then
			expansions[i]=nil
		end
	end
	--now prepare site.sets entries for expansions that are not in any site.sets entry
		local setcats = { "coresets", "expansionsets", "specialsets", "promosets" }
		for _,setcat in ipairs(setcats) do
			local setNames = dummy[setcat]
			local revSets = {}
			for id,name in pairs(setNames) do
				revSets[name] = id
			end--for id,name
			local sets,sortSets = {},{}
			for i,expansion in pairs(expansions) do
				if revSets[expansion.name] then
					local sid = revSets[expansion.name]
					sets[sid] = { id = sid , name = expansion.name, mkmId=expansion.idExpansion, urlsuffix=expansion.urlsuffix }
					table.insert(sortSets,sid)
					expansions[i]=nil
				end--if revSets
			end--for i,expansion
			table.sort(sortSets, function(a, b) return a > b end)
			LHpi.Log("-- ".. setcat ,0,file)--
			for i,sid in ipairs(sortSets) do
				local string = string.format(site.updateFormatString,sid,sid,sets[sid].urlsuffix,sets[sid].name )
				--print(string)
				LHpi.Log(string, 0,file )--
			end--for i,sid
		end--for setcat
		LHpi.Log("-- unknown" ,0,file)--
		for i,expansion in pairs(expansions) do
			local string = string.format(site.updateFormatString,0,0,expansion.urlsuffix,expansion.name )
			--print(string)
			LHpi.Log(string, 0,file )--
		end--for i,sid
	LHpi.Log("}--end table site.sets\n-----",0,file )--
end

--- @field [parent=#dummy] #table alllangs
dummy.alllangs = {
 [1]  = "English";
 [2]  = "Russian";
 [3]  = "German";
 [4]  = "French";
 [5]  = "Italian";
 [6]  = "Portuguese";
 [7]  = "Spanish";
 [8]  = "Japanese";
 [9]  = "Simplified Chinese"; -- for mtgmintcard
 [10] = "Traditional Chinese";
 [11] = "Korean";
 [12] = "Hebrew";
 [13] = "Arabic";
 [14] = "Latin";
 [15] = "Sanskrit";
 [16] = "Ancient Greek";
}

--- @field [parent=#dummy] #table promosets
dummy.promosets = {
 [55] = "Ugin’s Fate Promos";
 [53] = "Holiday Gift Box Promos";
 [52] = "Intro Pack Promos";
 [50] = "Full Box Promotion";
 [45] = "Magic Premiere Shop";
 [42] = "Summer of Magic Promos";
 [43] = "Two-Headed Giant Promos";
 [41] = "Happy Holidays Promos";
 [40] = "Arena/Colosseo Leagues Promos";
 [34] = "World Magic Cup Qualifiers Promos";
 [33] = "Championships Prizes";
 [32] = "Pro Tour Promos";
 [31] = "Grand Prix Promos";
 [30] = "Friday Night Magic Promos";
 [27] = "Alternate Art Lands";
 [26] = "Magic Game Day";
 [25] = "Judge Gift Cards";
 [24] = "Champs Promos";
 [23] = "Gateway & WPN Promos";
 [22] = "Prerelease Promos";
 [21] = "Release & Launch Parties Promos";
 [20] = "Magic Player Rewards";
 [15] = "Convention Promos";
 [12] = "Hobby Japan Commemorative Cards";
 [11] = "Redemption Program Cards";
 [10] = "Junior Series Promos";
 [9]  = "Video Game Promos";
 [8]  = "Stores Promos";
 [7]  = "Magazine Inserts";
 [6]  = "Comic Inserts";
 [5]  = "Book Inserts";
 [4]  = "Ultra Rare Cards";
 [2]  = "DCI Legend Membership";
}

--- @field [parent=#dummy] #table specialsets
dummy.specialsets = {
 [830] = "Duel Decks: Blessed vs. Cursed";
 [828] = "Commander 2015 Edition";
 [827] = "Magic Origins Clash Pack";
 [826] = "Zendikar Expeditions";
 [824] = "Duel Decks: Zendikar vs. Eldrazi";
 [823] = "From the Vault: Angels";
 [821] = "Challenge Deck: Defeat a God";
 [820] = "Duel Decks: Elspeth vs. Kiora";
 [819] = "Modern Masters 2015 Edition";
 [817] = "Duel Decks: Anthology";
 [815] = "Fate Reforged Clash Pack";
 [814] = "Commander 2014 Edition"; 
 [812] = "Duel Decks: Speed vs. Cunning";
 [811] = "Magic 2015 Clash Pack";
 [810] = "Modern Event Deck 2014";
 [809] = "From the Vault: Annihilation";
 [807] = "Conspiracy";
 [805] = "Duel Decks: Jace vs. Vraska";
 [804] = "Challenge Deck: Battle the Horde";
 [803] = "Challenge Deck: Face the Hydra";
 [801] = "Commander 2013 Edition";
 [799] = "Duel Decks: Heroes vs. Monsters";
 [798] = "From the Vault: Twenty";
 [796] = "Modern Masters";
 [794] = "Duel Decks: Sorin vs. Tibalt";
 [792] = "Commander’s Arsenal";
 [790] = "Duel Decks: Izzet vs. Golgari";
 [789] = "From the Vault: Realms";
 [787] = "Planechase 2012 Edition";
 [785] = "Duel Decks: Venser vs. Koth";
 [783] = "Premium Deck Series: Graveborn";
 [781] = "Duel Decks: Ajani vs. Nicol Bolas";
 [780] = "From the Vault: Legends";
 [778] = "Magic: The Gathering Commander";
 [777] = "Duel Decks: Knights vs. Dragons";
 [774] = "Premium Deck Series: Fire & Lightning";
 [772] = "Duel Decks: Elspeth vs. Tezzeret";
 [771] = "From the Vault: Relics";
 [769] = "Archenemy";
 [768] = "Duels of the Planeswalkers";
 [766] = "Duel Decks: Phyrexia vs. The Coalition";
 [764] = "Premium Deck Series: Slivers";
 [763] = "Duel Decks: Garruk vs. Liliana";
 [761] = "Planechase";
 [760] = "From the Vault: Exiled";
 [757] = "Duel Decks: Divine vs. Demonic";
 [755] = "Duel Decks: Jace vs. Chandra";
 [753] = "From the Vault: Dragons";
 [740] = "Duel Decks: Elves vs. Goblins";
 [675] = "Coldsnap Theme Decks";
 [636] = "Salvat 2011";
 [635] = "Salvat Magic Encyclopedia";
 [600] = "Unhinged";
 [490] = "Deckmasters";
 [440] = "Beatdown";
 [415] = "Starter 2000";
 [405] = "Battle Royale";
 [390] = "Starter 1999";
 [380] = "Portal Three Kingdoms";
 [340] = "Anthologies";
 [320] = "Unglued";
 [310] = "Portal Second Age";
 [260] = "Portal";
 [235] = "Multiverse Gift Box";
 [225] = "Introductory Two-Player Set";
 [201] = "Renaissance";
 [200] = "Chronicles";
 [106] = "Collectors’ Edition (International)";
 [105] = "Collectors’ Edition (Domestic)";
 [70]  = "Vanguard";
 [69]  = "Box Topper Cards";
}
--- @field [parent=#dummy] #table expansionsets
dummy.expansionsets = {
 [831] = "Shadows over Innistrad";
 [829] = "Oath of the Gatewatch";
 [825] = "Battle for Zendikar";
 [818] = "Dragons of Tarkir";
 [816] = "Fate Reforged";
 [813] = "Khans of Tarkir";
 [806] = "Journey into Nyx";
 [802] = "Born of the Gods";
 [800] = "Theros";
 [795] = "Dragon’s Maze";
 [793] = "Gatecrash";
 [791] = "Return to Ravnica";
 [786] = "Avacyn Restored";
 [784] = "Dark Ascension";
 [782] = "Innistrad";
 [776] = "New Phyrexia";
 [775] = "Mirrodin Besieged";
 [773] = "Scars of Mirrodin";
 [767] = "Rise of the Eldrazi";
 [765] = "Worldwake";
 [762] = "Zendikar";
 [758] = "Alara Reborn";
 [756] = "Conflux";
 [754] = "Shards of Alara";
 [752] = "Eventide";
 [751] = "Shadowmoor";
 [750] = "Morningtide";
 [730] = "Lorwyn";
 [710] = "Future Sight";
 [700] = "Planar Chaos";
 [690] = "Time Spiral Timeshifted";
 [680] = "Time Spiral";
 [670] = "Coldsnap";
 [660] = "Dissension";
 [650] = "Guildpact";
 [640] = "Ravnica: City of Guilds";
 [620] = "Saviors of Kamigawa";
 [610] = "Betrayers of Kamigawa";
 [590] = "Champions of Kamigawa";
 [580] = "Fifth Dawn";
 [570] = "Darksteel";
 [560] = "Mirrodin";
 [540] = "Scourge";
 [530] = "Legions";
 [520] = "Onslaught";
 [510] = "Judgment";
 [500] = "Torment";
 [480] = "Odyssey";
 [470] = "Apocalypse";
 [450] = "Planeshift";
 [430] = "Invasion";
 [420] = "Prophecy";
 [410] = "Nemesis";
 [400] = "Mercadian Masques";
 [370] = "Urza’s Destiny";
 [350] = "Urza’s Legacy";
 [330] = "Urza’s Saga";
 [300] = "Exodus";
 [290] = "Stronghold";
 [280] = "Tempest";
 [270] = "Weatherlight";
 [240] = "Visions";
 [230] = "Mirage";
 [220] = "Alliances";
 [210] = "Homelands";
 [190] = "Ice Age";
 [170] = "Fallen Empires";
 [160] = "The Dark";
 [150] = "Legends";
 [130] = "Antiquities";
 [120] = "Arabian Nights";
}
--- @field [parent=#dummy] #table coresets
dummy.coresets = {
 [822] = "Magic Origins";
 [808] = "Magic 2015";
 [797] = "Magic 2014";
 [788] = "Magic 2013";
 [779] = "Magic 2012";
 [770] = "Magic 2011";
 [759] = "Magic 2010";
 [720] = "Tenth Edition";
 [630] = "9th Edition";
 [550] = "8th Edition";
 [460] = "7th Edition";
 [360] = "6th Edition";
 [250] = "5th Edition";
 [180] = "4th Edition";
 [179] = "4th Edition (FBB)";
 [141] = "Revised Edition (Summer Magic)";
 [140] = "Revised Edition";
 [139] = "Revised Edition (FBB)"; --"Revised Limited", "Foreign Black Border"
 [110] = "Unlimited";
 [100] = "Beta";
 [90]  = "Alpha";
}

--- @field [parent=#dummy] #table standardsets
dummy.standardsets = {
-- standard as of April 2016
		[831] = "Shadows over Innistrad";
		[829] = "Oath of the Gatewatch";
		[825] = "Battle for Zendikar";
		[818] = "Dragons of Tarkir";
		[822] = "Magic Origins"; 
}

--[[- run as lua application  from your ide.

@function [parent=#global] main
]]
function main(mode)
	if mode == "helper" then
		return("LHpi.dummyMA running as helper. ma namespace and dummy implementations are now available.")
	end
	print("dummy says: Hello " .. _VERSION .. "!")
	local t1 = os.clock()
	--- global working directory to allow operation outside of MA\Prices hierarchy
	-- @field [parent=#global] workdir
	workdir=".\\"
	local libver=2.17
	local dataver=10
	
	--don't keep a seperate dev savepath, though
	mapath = "..\\..\\..\\Magic Album\\"
	package.path = workdir..'lib\\ext\\?.lua;' .. package.path
	package.cpath= workdir..'lib\\bin\\?.dll;' .. package.cpath
	dummy.env={--define debug enviroment options
		VERBOSE = true,--default false
		LOGDROPS = true,--default false
		LOGNAMEREPLACE = true,--default false
		LOGFOILTWEAK = true,--default false
--		CHECKEXPECTED = false,--default true
		STRICTEXPECTED = true,--default false
--		STRICTOBJTYPE = false,--default true
		SAVELOG = true,--default false
		SAVEHTML = true,--default false
--		DEBUGFOUND = true,--default false
--		DEBUGVARIANTS = true,--default false
--		SAVETABLE=true,--default false
--		DEBUG = true,--default false
		OFFLINE = true,--default false
--		OFFLINE = false,--scripts should be set to true unless preparing for release
	}
	dummy.ForceEnv()

	local importfoil = "y"
	local importlangs = dummy.alllangs
--	local importlangs = { [1] = "eng" }
	local importsets = dummy.standardsets
--	local importsets = { [0] = "fakeset"; }
	local importsets = { [220]="some set" }
--	local importsets = { [220]="foo";[800]="bar";[0]="baz"; }
--	local importsets = dummy.coresets
--	local importsets = dummy.expansionsets
--	local importsets = dummy.MergeTables ( dummy.coresets, dummy.expansionsets, dummy.specialsets, dummy.promosets )
	
	local scripts={
		[0]={name="lib\\LHpi.sitescriptTemplate-v2.17.10.15.lua",savepath="."},
		[1]={name="\\MTG Mint Card.lua",path=savepath,savepath=mapath,oldloader=true},
		[2]={name="\\Import Prices.lua",path=mapath,savepath=mapath,oldloader=true},
		[3]={name="LHpi.mtgmintcard.lua",savepath=mapath.."Prices\\LHpi.mtgmintcard\\"},
		[4]={name="LHpi.magicuniverseDE.lua",savepath=mapath.."Prices\\LHpi.magicuniverseDE\\"},
		[5]={name="LHpi.trader-onlineDE.lua",savepath=mapath.."Prices\\LHpi.trader-onlineDE\\"},
		[6]={name="LHpi.tcgplayerPriceGuide.lua",savepath=mapath.."Prices\\LHpi.tcgplayerPriceGuide\\"},
		[7]={name="LHpi.mtgprice.com.lua",savepath=mapath.."Prices\\LHpi.mtgprice.com\\"},
		[8]={name="LHpi.magickartenmarkt.lua",savepath=mapath.."Prices\\LHpi.magickartenmarkt\\"},
		[9]={name="LHpi.mkm-helper.lua",savepath=mapath.."Prices\\LHpi.magickartenmarkt\\"},
	}
	
	-- select a predefined script to be tested
--	dummy.FakeSitescript()
	local selection = 9
	local script=scripts[selection]
	if script.oldloadert then
		dummy.LoadScript(script.name,script.path,script.savepath)--deprecated
	else
		--new loader
		savepath=script.savepath
		dofile(workdir..script.name)
	end
		
	-- only load library (and Data)
	--LHpi = dummy.LoadLib(libver,workdir,script.savepath)--deprecated
--	LHpi = dofile(workdir.."lib\\LHpi-v"..libver..".lua")

	-- force debug enviroment options
	dummy.ForceEnv(dummy.env)
	print("dummy says: script loaded.")
	
	-- utility functions from dummy:
	--only run sitescript update helpers
	if selection ~= 9 then
		if site.Initialize then
			site.Initialize({update=true})
		--else
		--	dummy.CompareDummySets(mapath,libver)
		--	dummy.CompareDataSets(libver,dataver)
		--	dummy.CompareSiteSets()	
		end
	end
	
	-- now try to break the script :-)
	if selection ~= 9 then
		ImportPrice( importfoil, importlangs, importsets )
	end

	-- demo LHpi helper functions:
--	print(LHpi.Tostring( { ["this"]=1, is=2, [3]="a", ["table"]="string" } ))
--	print(LHpi.ByteRep("Zwölffüßler"))
--TODO add demo for other helper functions

	--TestPerformance(10,script,importfoil,importlangs,importsets,"time.log")

	-- use ProFi to profile the script
--	ProFi = require 'ProFi'
--	ProFi:start()
--	--
--	ImportPrice( importfoil, importlangs, importsets )
	--profile single function only
--	package.path = 'src\\lib\\ext\\?.lua;' .. package.path
--	Json = require ("dkjson")
--	site.sets={ [808]={id=808, lang={ "ENG",[2]="RUS",[3]="GER",[4]="FRA",[5]="ITA",[6]="POR",[7]="SPA",[8]="JPN",[9]="SZH",[10]="ZHT",[11]="KOR" }, fruc={ true }, url="Magic%202015"} }
--	local urldetails = { setid=808, langid=1, frucid=1 }
--	local foundstring = '{"idProduct":7923,"idMetaproduct":2248,"idGame":1,"countReprints":2,"name":{"1":{"idLanguage":1,"languageName":"English","productName":"Fyndhorn Druid (Version 2)"},"2":{"idLanguage":2,"languageName":"French","productName":"Druide cordellien (Version 2)"},"3":{"idLanguage":3,"languageName":"German","productName":"Fyndhorndruide (Version 2)"},"4":{"idLanguage":4,"languageName":"Spanish","productName":"Druida de Fyndhorn (Version 2)"},"5":{"idLanguage":5,"languageName":"Italian","productName":"Druido di Fyndhorn (Version 2)"}},"website":"\\/Products\\/Singles\\/Alliances\\/Fyndhorn+Druid+%28Version+2%29","image":".\\/img\\/cards\\/Alliances\\/fyndhorn_druid2.jpg","category":{"idCategory":1,"categoryName":"Magic Single"},"priceGuide":{"SELL":0.05,"LOW":0.02,"LOWEX":0.02,"LOWFOIL":0,"AVG":0.1,"TREND":0.05},"expansion":"Alliances","expIcon":13,"number":null,"rarity":"Common","countArticles":466,"countFoils":0}'
--	site.ParseHtmlData( foundstring , urldetails )
--	--	
--	ProFi:stop()
--	ProFi:writeReport( 'MyProfilingReport.txt' )
	
	local dt = os.clock() - t1 
	print(string.format("All this took %g seconds",dt))
	return "dummy says: Goodbye lua!"
end--main()

local dummymode = dummymode or nil
local ret = main(dummymode)
print(tostring(ret))
--EOF