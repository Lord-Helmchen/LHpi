--*- coding: utf-8 -*-
--[[- LordHelmchen's price import
 Price import script library for Magic Album.

Inspired by and loosely based on "MTG Mint Card.lua" by Goblin Hero, Stromglad1 and "Import Prices.lua" by woogerboy21;
who generously granted permission to "do as I like" with their code;
everything else Copyright (C) 2012-2014 by Christian Harms.
If you want to contact me about the script, try its release thread in http://www.slightlymagic.net/forum/viewforum.php?f=32

@module LHpi
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
2.14 (unreleased)
cardcount.nontr renamed to cardcount.nontrad
GetSourceData split into GetSourceData and ParseSourceData.
* this change is completely transparent to existing sitescripts, but having GetSourceData seperated allows to use it from the sitescript for special cases.
LHpi.GetSourceData( sourceurl,urldetails )
* defer fetching to sitescript for oauth
* now returns #string sourcedata
* converts url to filename if OFFLINE
* fixed savepath==nil handling (needed when called before DoImport has run)
* Log https status if not ok
LHpi.ParseSourceData( sourcedata,sourceurl,urldetails )
* does the parsing previously done by GetSourceData and returns the #table sourceTable
* shortcut return nil for sourcedata==nil
* now strictly expect site.ParseHtmlData to return card.price as #number (and not #table, as was possible before)
* do not sanitize nor check card.regprice or card.foilpriceBuildCardData
* counts namereplace and foiltweak even if card is dropped
BuildCardData
* remove "(nontrad)","(replica)","(plane)","(scheme)","(conspiracy)" and
"(oversized)" card.name infixes when no longer needed
* set objecttype replica for 105,106,69
* improved Token suffix handling
* keeps "Replica" suffix for variants
* removes "Insert" suffix
* keep (oversized) in set [40]
SetPrice
* objtype infixe handling improved
Logtable
* no longer strictly requires #table arguments
MainImportCycle
* fixed CHECKEXPECTED handling for semi-available languages
DoImport
* changed site.expected.EXPECTTOKENS to site.expected.tokens
* changed site.expected.EXPECTNONTRAD to site.expected.nontrad
* changed site.expected.EXPECTREPL to site.expected.replica
* all three can be #boolean (like before) or #table { [langid]=#boolean,... }
* DoImport passes supImportfoil,supImportlangs,supImportsets to site.SetExpected
* fixed expected defaults and checks
removed some leftover commented-out code
improved some comments and log msgs

2.15
Split Initialize() from DoImport(importfoil , importlangs , importsets)
always run Initialize() before returning LHpi library table.
scriptname,savepath,logfile change from global to local (in site and LHpi)
Log now filters out VERBOSE and DEBUG lines by loglevel param to save "if DEBUG then Log() end" conditionals
*those conditionals have been cut and loglevel has been set for all existing LHpi.Log calls
DEBUGVARIANTS=true no longer sets DEBUG=false, instead remembers and restores previous DEBUG state

]]

--TODO count averaging events with counter attached to prices
--todo nil unneeded Data.sets[sid] to save memory?
--TODO change #boolean VERBOSE to #number verbosity and adjust loglevels?

local LHpi = {}
---	LHpi library version
-- @field [parent=#LHpi] #string version
LHpi.version = "2.15"

--[[- "main" function called by Magic Album; just display error and return.
 Called by Magic Album to import prices. Parameters are passed from MA.
 We don't want to call the library directly.
 
 @function [parent=#global] ImportPrice
 @param #string importfoil	"Y"|"N"|"O"
 @param #table importlangs	{ #number = #string , ... }
 @param #table importsets	{ #number = #string , ... }
]]
function ImportPrice( importfoil , importlangs , importsets )
	ma.Log( "Called LHpi library instead of site script. Raising error to inform user via dialog box." )
	ma.Log( "LHpi library should be in \\lib subdir to prevent this." )
	LHpi.Log( LHpi.Tostring( importfoil ) ,1)
	LHpi.Log( LHpi.Tostring( importlangs ) ,1)
	LHpi.Log( LHpi.Tostring( importsets ) ,1)
	error( "LHpi-v" .. LHpi.version .. " is a library. Please select a LHpi-sitescript instead!" )
end -- function ImportPrice

--- All import data for current set, one row per card.
-- declared here for scope, initialized in LHpi.MainImportCycle
-- @field #table cardsetTable
local cardsetTable

--[[- Prepare library for use before returning LHpi namespace.
 Set sensible defaults for unset or missing options,
 configure LHpi behaviour and prevent undefined logfile locations
 This should eventually enable us to get rid of most global variables,
 except for OPTIONS, which need to be changed at will.
 
 @function [parent=#LHpi] Initialize
]]  
function LHpi.Initialize()
	if not site then site = {} end
	---@field [parent=#LHpi] #string workdir
	--LHpi usually resides in MagicAlbum\\Prices. Allow for global workdir to explicitly set otherwise.
	LHpi.workdir = workdir or "Prices\\"
	--default values for feedback options
	if VERBOSE==nil then
		---@field [parent=#global] VERBOSE
		VERBOSE = false
	end
	if LOGDROPS==nil then
		---@field [parent=#global] LOGDROPS
		LOGDROPS = false
	end
	if LOGNAMEREPLACE==nil then
		---@field [parent=#global] LOGNAMEREPLACE
		LOGNAMEREPLACE = false
	end
	if LOGFOILTWEAK==nil then
		---@field [parent=#global] LOGFOILTWEAK
		LOGFOILTWEAK = false
	end
	-- default values for behaviour options
	if CHECKEXPECTED==nil then
		---@field [parent=#global] CHECKEXPECTED
		CHECKEXPECTED = true
	end
	if STRICTEXPECTED==nil then
		---@field [parent=#global] STRICTEXPECTED
		STRICTEXPECTED = false
	end
	if DEBUG==nil then
		---@field [parent=#global] DEBUG
		DEBUG = false
	end
	if DEBUGFOUND==nil then
		---@field [parent=#global] DEBUGFOUND
		DEBUGFOUND = false
	end
	if DEBUGVARIANTS==nil then
		---@field [parent=#global] DEBUGVARIANTS
		DEBUGVARIANTS = false
	end
	if OFFLINE==nil then
		---@field [parent=#global] OFFLINE
		OFFLINE = false
	end
	if SAVEHTML==nil then
		---@field [parent=#global] SAVEHTML
		SAVEHTML = false
	end
	if SAVELOG==nil then
		---@field [parent=#global] SAVELOG
		SAVELOG = true
	end
	if SAVETABLE==nil then
		---@field [parent=#global] SAVETABLE
		SAVETABLE = false
	end
	if not site.scriptname then
	-- should usually be similar to the sitescript filename, as it is used to determine default logfile and savepath.
		local _s,_e,myname = string.find( ( ma.GetFile( "Magic Album.log" ) or "" ) , "Starting Lua script .-([^\\]+%.lua)$" )
		if myname and myname ~= "" then
			site.scriptname = myname
		else -- use hardcoded scriptname as fallback
			site.scriptname = "LHpi.SITESCRIPT_NAME_NOT_SET-v" .. LHpi.version .. ".lua"
		end
	end -- if
	--- log file name. can be set explicitely via site.logfile or automatically.
	-- defaults to LHpi.log unless SAVELOG is true.
	-- @field [parent=#LHpi] #string logfile
	LHpi.logfile = LHpi.workdir.."LHpi.log" -- use global LHpi.log unless configured otherwise
	if SAVELOG~=false then
		if site.scriptname then
			LHpi.logfile = LHpi.workdir .. string.gsub( site.scriptname , "lua$" , "log" )
		end
		if site.logfile then -- allow sitescripts to explicitely set log file name
			LHpi.logfile = site.logfile
		end
	end
	--- savepath for OFFLINE (read) and SAVEHTML,SAVETABLE (write). must point to an existing directory relative to MA's root.
	-- @field [parent=#LHpi] #string savepath
	if site.savepath then
		LHpi.savepath = site.savepath .. "\\"
	else
		LHpi.savepath = LHpi.workdir .. string.gsub( site.scriptname , "%-?v?[%d%.]*%.lua$" , "" ) .. "\\"
	end -- if
	if SAVEHTML or SAVETABLE then
		ma.PutFile(LHpi.savepath .. "testfolderwritable" , "true", 0 )
		local folderwritable = ma.GetFile( LHpi.savepath .. "testfolderwritable" )
		if not folderwritable then
			SAVEHTML = false
			SAVETABLE = false
			LHpi.Log( "failed to write file to savepath " .. LHpi.savepath .. ". Disabling SAVEHTML and SAVETABLE" ,0)
			if DEBUG then
				error( "Savepath " .. LHpi.savepath .. " not writable!" )
			end
		end -- if not folderwritable
	end -- if SAVEHTML
	--load LHpi.Data
	if (not site.dataver) or (site.dataver == "") then
		if DEBUG then
			error("undefined dataver!")
		else
			site.dataver = "5"
		end
	end
	---	LHpi static set data
	--@field [parent=#LHpi] #table Data
	LHpi.Data = LHpi.LoadData(site.dataver)
end--function Initialize

--[[- "main" function called by LHpi sitescript.
 Parameters are passed through sitescript's ImportPrice from Magic Album.
 This is all that a sitescript should need to do in its ImportPrice once LHpi library has been executed
  
 @function [parent=#LHpi] DoImport
 @param #string importfoil	"Y"|"N"|"O"
 @param #table importlangs	{ #number (langid)= #string , ... }
 @param #table importsets	{ #number (setid)= #string , ... }
]]
function LHpi.DoImport (importfoil , importlangs , importsets)
	-- create empty dummy fields for undefined sitescript fields to allow graceful exit
	if DEBUG and ((not site.langs) or (not next(site.langs)) ) then error("undefined site.langs!") end
	if not site.langs then site.langs = {} end
	if DEBUG and ((not site.sets) or (not next(site.sets)) ) then error("undefined site.sets!") end
	if not site.sets then site.sets = {} end
	if DEBUG and ((not site.frucs) or (not next(site.frucs)) ) then error("undefined site.frucs!") end
	if not site.frucs then site.frucs = {} end
	if DEBUG and ((not site.regex) or site.regex == "" ) then error("undefined site.regex!") end
	if not site.regex then site.regex = "" end
	-- read user supplied parameters and modify site.sets table
	local supImportfoil,supImportlangs, supImportsets = LHpi.ProcessUserParams( importfoil , importlangs , importsets )
	-- set sensible defaults or throw error on missing sitescript fields or functions
	if not site.BuildUrl then
		function site.BuildUrl( setid,langid,frucid,offline )
			local errormsg = "sitescript " .. site.scriptname .. ": function site.BuildUrl not implemented!" 
			ma.Log( "!!critical error: " .. errormsg )
			error( errormsg )
		end	-- function
	end -- if
	if not site.ParseHtmlData then
		function site.ParseHtmlData( foundstring )
			local errormsg = "sitescript " .. site.scriptname .. ": function site.ParseHtmlData not implemented!" 
			ma.Log( "!!critical error: " .. errormsg )
			error( errormsg )
		end	-- function
	end -- if
	-- Don't need to define defaults here as long as BuildCardData checks for their existence before calling them.	
	--	if not site.BCDpluginPre then
	--		function site.BCDpluginPre ( card , setid )
	--			return card,namereplaced,foiltweaked
	--		end -- function
	--	end -- if
	--	if not site.BCDpluginPost then
	--		function site.BCDpluginPost( card , setid )
	--			card.pluginData = nil
	--			return card,namereplaced,foiltweaked
	--		end -- function
	--	end -- if
	if not site.encoding then site.encoding = "cp1252" end
	if not site.currency then site.currency = "$" end
	if not site.namereplace then site.namereplace={} end
	if not site.variants then site.variants = {} end
	if not site.foiltweak then site.foiltweak={} end
	for sid,_setname in pairs(supImportsets) do
		if not site.variants[sid] then site.variants[sid]={} end
		if not site.variants[sid].override then
			--merge
			local mergedvariants=LHpi.Data.sets[sid].variants
			for card,variant in pairs(site.variants[sid]) do
				mergedvariants[card]=variant
			end--for card,variant
			site.variants[sid]=mergedvariants
		end--if variants.override
		if not site.foiltweak[sid] then site.foiltweak[sid]={} end
		if not site.foiltweak[sid].override then
			--merge
			local mergedfoiltweak=LHpi.Data.sets[sid].foiltweak
			for card,tweak in pairs(site.foiltweak[sid]) do
				mergedfoiltweak[card]=tweak
			end--for card,variant
			site.foiltweak[sid]=mergedfoiltweak
		end--if foiltweak.override
	end -- for
	if not site.condprio then site.condprio={ [0] = "NONE" } end
	if CHECKEXPECTED then
		if site.SetExpected then
			site.SetExpected( supImportfoil , supImportlangs , supImportsets ) -- actively set site.expected table
		end
		if not site.expected then site.expected = {} end
		for sid,_setname in pairs(supImportsets) do
			if not site.expected[sid] then
				site.expected[sid] = {}
			end
			if not site.expected[sid].pset then
				site.expected[sid].pset = {}
			end
			if not site.expected[sid].failed then
				site.expected[sid].failed = {}
			end
			for lid,langbool in pairs (site.sets[sid].lang) do
				if langbool then
					if not site.expected[sid].pset[lid] then
						local psetExpected
						if ( LHpi.Data.sets[sid] and LHpi.Data.sets[sid].cardcount ) then
							psetExpected = LHpi.Data.sets[sid].cardcount.reg or 0
							if site.expected.tokens and ( "boolean"==type(site.expected.tokens) or site.expected.tokens[lid] ) then
								psetExpected = psetExpected + (LHpi.Data.sets[sid].cardcount.tok or 0)
							end
							if site.expected.nontrad and ( "boolean"==type(site.expected.nontrad) or site.expected.nontrad[lid] ) then
								psetExpected = psetExpected + (LHpi.Data.sets[sid].cardcount.nontrad or 0)
							end
							if site.expected.replica and ( "boolean"==type(site.expected.replica) or site.expected.replica[lid] ) then
								psetExpected = psetExpected + (LHpi.Data.sets[sid].cardcount.repl or 0)
							end
							site.expected[sid].pset[lid] = psetExpected
						else
							site.expected[sid].pset[lid] = 0	
						end
					end
					if not site.expected[sid].failed[lid] then
						site.expected[sid].failed[lid] = 0
					end
				end -- if
			end -- for
		end -- for sid,_setname
	end -- if CHECKEXPECTED
	
	-- build sourceList of urls/files to fetch
	local sourceList, sourceCount = LHpi.ListSources( supImportfoil , supImportlangs , supImportsets )

	-- loop through importsets to parse html, build cardsetTable and then call ma.setPrice
	local totalcount,setcountdiffers = LHpi.MainImportCycle(sourceList, sourceCount, supImportfoil, supImportlangs, supImportsets)
	
	-- report final count
	LHpi.Log("Import Cycle finished." ,0)
	ma.SetProgress( "Finishing", 100 )
	local totalcountstring = ""
	for lid,lang in pairs (supImportlangs) do
		totalcountstring = totalcountstring .. string.format( "%i set, %i failed %s cards\t", totalcount.pset[lid], totalcount.failed[lid], lang )
	end -- for
	LHpi.Log( string.format ( "Total counted : " .. totalcountstring .. "; %i dropped, %i namereplaced and %i foiltweaked.", totalcount.dropped, totalcount.namereplaced, totalcount.foiltweaked ) ,0)
	if DEBUG then
		print( string.format ( "Total counted : " .. totalcountstring .. "; %i dropped, %i namereplaced and %i foiltweaked.", totalcount.dropped, totalcount.namereplaced, totalcount.foiltweaked ) )
	end
	if CHECKEXPECTED then
		local totalexpected = {pset={},failed={},dropped=0,namereplaced=0,foiltweaked=0}
		for lid,_lang in pairs(supImportlangs) do
			totalexpected.pset[lid] = 0
			totalexpected.failed[lid] = 0
		end -- for
		for sid,set in pairs( supImportsets ) do
			if site.expected[sid] then
				for lid,_ in pairs( supImportlangs ) do
					totalexpected.pset[lid] = totalexpected.pset[lid] + ( site.expected[sid].pset[lid] or 0 )
					totalexpected.failed[lid] = totalexpected.failed[lid]  + ( site.expected[sid].failed[lid] or 0 )
				end -- for lid
				totalexpected.dropped = totalexpected.dropped + ( site.expected[sid].dropped or 0 )
				totalexpected.namereplaced = totalexpected.namereplaced + ( site.expected[sid].namereplaced or 0 )
				totalexpected.foiltweaked = totalexpected.foiltweaked + ( site.expected[sid].foiltweaked or 0 )
			end -- if site.expected[sid]
		end -- for sid,set
		local totalexpectedstring = ""
		for lid,lang in pairs (supImportlangs) do
			totalexpectedstring = totalexpectedstring .. string.format( "%i set, %i failed %s cards\t", totalexpected.pset[lid], totalexpected.failed[lid], lang )
		end -- for
		LHpi.Log( string.format( "Total expected: " .. totalexpectedstring .. "; %i dropped, %i namereplaced and %i foiltweaked.", totalexpected.dropped, totalexpected.namereplaced, totalexpected.foiltweaked ) ,1)
		if DEBUG then
			print( string.format( "Total expected: " .. totalexpectedstring .. "; %i dropped, %i namereplaced and %i foiltweaked.", totalexpected.dropped, totalexpected.namereplaced, totalexpected.foiltweaked ) )
		end
		LHpi.Log( string.format( "count differs in %i sets: %s", LHpi.Length(setcountdiffers),LHpi.Tostring(setcountdiffers) ), 1)
	end -- if CHECKEXPECTED	
end

--[[- Main import cycle 
 , here the magic occurs.
 importfoil, importlangs, importsets are shortened to supported only entries by LHpi.ProcessUserParams
 to shorten loops, but could be used unmodified if wanted.
  
 @function [parent=#LHpi] MainImportCycle
 @param #table sourcelist		{ #number (setid)= #table { #string (url)= #table { isfile= #boolean } , ... } , ... }
 @param #number totalhtmlnum	for progressbar
 @param #string importfoil		"y"|"n"|"o"
 @param #table importlangs		{ #number (langid)= #string , ... }
 @param #table importsets		{ #number (setid)= #string , ... }
 @return #table	{ pset= #table { #number (langid)= #number , ... }, failed= #table { #number (langid)= #number , ... }, dropped= #number, namereplaced= #number, foiltweaked= #number }
  : count of set,failed prices and drop,namereplace,foiltweak events.
 @return #table	{ #number (setid)= #string } : list of sets where persetcount differs from site.expected[setid].
]]
function LHpi.MainImportCycle( sourcelist , totalhtmlnum , importfoil , importlangs , importsets )
	local totalcount = { pset= {}, failed={}, dropped=0, namereplaced=0, foiltweaked=0 }
	for lid,_lang in pairs(importlangs) do
		totalcount.pset[lid] = 0
		totalcount.failed[lid] = 0
	end -- for
	local setcountdiffers = {}
	-- count imported sourcefiles for progressbar.
	local curhtmlnum = 0

	for sid,cSet in pairs( site.sets ) do
		if importsets[sid] then
			cardsetTable = {} -- clear cardsetTable
			-- count all set,failed prices and drop,namereplace,foiltweak events.
			local persetcount = { pset= {}, failed={}, dropped=0, namereplaced=0, foiltweaked=0 }
			for lid,_lang in pairs(importlangs) do
				persetcount.pset[lid] = 0
				persetcount.failed[lid] = 0
			end-- for lid
			local progress = 0
			local nonemptysource = {}
			-- build cardsetTable containing all prices to be imported
			for sourceurl,urldetails in pairs( sourcelist[sid] ) do
				curhtmlnum = curhtmlnum + 1
				progress = 100*curhtmlnum/totalhtmlnum
				local pmesg = "Collecting " ..  importsets[sid] .. " into table"
				local _s,_e,pagenr = nil, nil, nil
				if VERBOSE then
					pmesg = pmesg .. " (id " .. sid .. ")"
					LHpi.Log( string.format( "%d%%: %q", progress, pmesg) , 1)
				end
				ma.SetProgress( pmesg , progress )
				if site.pagenumberregex then
					_s,_e,pagenr=string.find(sourceurl, site.pagenumberregex )
					if pagenr then pagenr=tonumber(pagenr) end
				end
				local sourcedata = LHpi.GetSourceData( sourceurl,urldetails )
				local sourceTable = LHpi.ParseSourceData( sourcedata,sourceurl,urldetails )
				-- process found data and fill cardsetTable
				if sourceTable then
					for _,row in pairs(sourceTable) do
						local d
						if DEBUGVARIANTS then d = DEBUG end
						local newcard,namereplaced,foiltweaked = LHpi.BuildCardData( row , sid , importfoil , importlangs)
						persetcount.namereplaced = persetcount.namereplaced + (namereplaced or 0)
						persetcount.foiltweaked = persetcount.foiltweaked + (foiltweaked or 0)
						if newcard.drop then
							persetcount.dropped = persetcount.dropped + 1
							if LOGDROPS then
								LHpi.Log( string.format("DROPped cName \"%s\".", newcard.name ) ,0)
							end
						else -- not newcard.drop
							local errnum,errormsg,filledRow = LHpi.FillCardsetTable ( newcard )
							if errnum < 0 then
								LHpi.Log(string.format("%s! No row sent to cardsetTable.",errormsg), 1)
								if DEBUG then
									error(string.format("Set [%i] %s - %s:%s\t%s",sid,LHpi.Data.sets[sid].name,newcard.name,errormsg,LHpi.Tostring(filledRow)) , 2 )
								end
							elseif errnum > 0 then
								LHpi.Log(string.format("sent %s (%s) to cardsetTable",errormsg,newcard.name ), 1)
								LHpi.Log(string.format("Set [%i] %s - %s:%s\t%s",sid,LHpi.Data.sets[sid].name,newcard.name,errormsg,LHpi.Tostring(filledRow)), 2)
							else
								LHpi.Log(string.format("sent %s (%s) to cardsetTable",errormsg,newcard.name ), 2)
							end--if errnum
						end -- if newcard.drop
						if DEBUGVARIANTS then DEBUG = d end
					end -- for i,row in pairs(sourceTable)
					if pagenr then
						nonemptysource[pagenr] = true
					end
				else -- not sourceTable
					LHpi.Log("No cards found, skipping to next source" , 1)
					if pagenr and (not nonemptysource[pagenr]) then
						nonemptysource[pagenr] = false
					end
					if DEBUG then
						print("!! empty sourceTable for " .. importsets[sid] .. " - " .. sourceurl)
						--error("empty sourceTable for " .. importsets[sid] .. " - " .. sourceurl)
					end
				end -- if sourceTable
			end -- for _,source 
			-- build cardsetTable from htmls finished
			if VERBOSE then
				local msg =  string.format( "cardsetTable for set %s (id %i) build with %i rows.",importsets[sid],sid,LHpi.Length(cardsetTable) )
				if ( LHpi.Data.sets[sid] and LHpi.Data.sets[sid].cardcount ) then
					msg = msg .. string.format( " Set supposedly contains %i cards and %i tokens.", LHpi.Data.sets[sid].cardcount.reg, LHpi.Data.sets[sid].cardcount.tok )
				else
					msg = msg .. " Number of cards in set is not known to LHpi."
				end 
				LHpi.Log( msg , 1)
			end
			if SAVETABLE then
				LHpi.Log(string.format("Saving Cardset Table for set %s to %s",sid, LHpi.savepath))
				LHpi.SaveCSV( sid, cardsetTable , LHpi.savepath )
			end
			-- Set the price
			local pmesg = "Importing " .. importsets[cSet.id] .. " from table"
			LHpi.Log( string.format( "%3i%%: %s", progress, pmesg ) , 1)
			ma.SetProgress( pmesg, progress )
			for cName,cCard in pairs(cardsetTable) do
				LHpi.Log( string.format("ImportPrice\t cName is %s and table cCard is %s", cName, LHpi.Tostring(cCard) ) , 2)
				local psetcount,failcount = LHpi.SetPrice( sid , cName , cCard )
				for lid,_lang in pairs(importlangs) do
					persetcount.pset[lid] = persetcount.pset[lid] + (psetcount[lid] or 0)
					persetcount.failed[lid] = persetcount.failed[lid] + (failcount[lid] or 0)
				end-- for lid
			end -- for cName,cCard in pairs(cardsetTable)
			LHpi.Log ( "Set " .. importsets[cSet.id] .. " imported." ,0)
			if VERBOSE then
				if ( LHpi.Data.sets[sid] and LHpi.Data.sets[sid].cardcount ) then
					LHpi.Log( string.format( "[%i] contains %4i cards (%4i regular, %4i tokens, %4i nontraditional, %4i replica )", cSet.id, LHpi.Data.sets[sid].cardcount.all, LHpi.Data.sets[sid].cardcount.reg, LHpi.Data.sets[sid].cardcount.tok, LHpi.Data.sets[sid].cardcount.nontrad or 0, LHpi.Data.sets[sid].cardcount.repl or 0 ) ,1)
				else
					LHpi.Log( string.format( "[%i] contains unknown to LHpi number of cards.", cSet.id ) ,1)
				end
			end
			
			if CHECKEXPECTED then
				if site.expected[sid] then
					local allgood = true
					LHpi.Log("site.expected.pset:"..LHpi.Tostring(site.expected[cSet.id].pset) ,1)
					LHpi.Log("persetcount.pset  :"..LHpi.Tostring(persetcount.pset) ,1)					
					for lid,cLang in pairs(importlangs) do
						if (site.expected[cSet.id].pset[lid] or 0) ~= (persetcount.pset[lid] or 0) then
							allgood = false
							LHpi.Log(string.format("allgood set false: site.expected[%s].pset[%s]=%s - persetcount.pset[%s]=%s",cSet.id,lid,tostring(site.expected[cSet.id].pset[lid]),lid,tostring(persetcount.pset[lid])) ,1)
						end
						if (site.expected[cSet.id].failed[lid] or 0) ~= (persetcount.failed[lid] or 0) then
							allgood = false
								LHpi.Log(string.format("allgood set false: site.expected[%s].failed[%s]=%s - persetcount.failed[%s]=%s",cSet.id,lid,tostring(site.expected[cSet.id].failed[lid]),lid,tostring(persetcount.failed[lid])) ,1)
						end
					end -- for lid,cLang in importlangs
					if STRICTEXPECTED then
						if ( site.expected[sid].dropped or 0 ) ~= persetcount.dropped then
							allgood = false
							LHpi.Log("allgood set false in dropped" ,1)
						end
						if ( site.expected[sid].namereplaced or 0 ) ~= persetcount.namereplaced then
							allgood = false
							LHpi.Log("allgood set false in namereplaced" ,1)
						end
						if ( site.expected[sid].foiltweaked or 0 ) ~= persetcount.foiltweaked then
							allgood = false
							LHpi.Log("allgood set false in foiltweaked" ,1)
						end
					end
					if not allgood then
						LHpi.Log( string.format( ":-( persetcount for %s (id %i) differs from expected. ", importsets[sid], sid ) , 1)
						--table.insert( setcountdiffers , sid , importsets[sid] )
						setcountdiffers[sid] = importsets[sid]
						if VERBOSE then
							local setcountstring = ""
							for lid,lang in pairs (importlangs) do
								if cSet.lang[lid] or (persetcount.pset[lid]~=0) then
									setcountstring = setcountstring .. string.format( " %3i set & %3i failed %8s cards ;", persetcount.pset[lid], persetcount.failed[lid], lang )
								end -- if
							end -- for
							LHpi.Log( string.format ( ":-( counted :" .. setcountstring .. " %3i dropped, %3i namereplaced and %3i foiltweaked.", persetcount.dropped, persetcount.namereplaced, persetcount.foiltweaked ) ,1)
							local setexpectedstring = ""
							for lid,lang in pairs (importlangs) do
								if cSet.lang[lid] or (persetcount.pset[lid]~=0) then
									setexpectedstring = setexpectedstring .. string.format( " %3i set & %3i failed %8s cards ;", site.expected[sid].pset[lid] or 0, site.expected[sid].failed[lid] or 0, lang )
								end -- if
							end -- for
							LHpi.Log( string.format ( ":-( expected:" .. setexpectedstring .. " %3i dropped, %3i namereplaced and %3i foiltweaked.", site.expected[sid].dropped or 0 , site.expected[sid].namereplaced or 0, site.expected[sid].foiltweaked or 0 ) ,1)
							LHpi.Log( string.format( "namereplace table for the set contains %s entries.", (LHpi.Length(site.namereplace[sid]) or "no") ) ,1)
							LHpi.Log( string.format( "foiltweak table for the set contains %s entries.", (LHpi.Length(site.foiltweak[sid]) or "no") ) ,1)
						end
						if DEBUG then
							error( "not allgood in set " .. importsets[sid] .. "(" ..  sid .. ")" )
						end
					else
						LHpi.Log( string.format( ":-) Prices for set %s (id %i) were imported as expected :-)", importsets[sid], sid ), 1)
					end
				else
					LHpi.Log( string.format( "No expected persetcount for %s (id %i) found.", importsets[sid], sid ), 1)
				end -- if site.expected[sid] else
				if site.sets[sid].pages and (nonemptysource ~= {})  then
					local lastnonempty = 0
					for i = 1,#nonemptysource do
						if nonemptysource[i] then
							lastnonempty=i
						end
					end--for
					if lastnonempty < site.sets[sid].pages then
						LHpi.Log(string.format("!! [%i] %s only needs %i pages instead of %i.",sid,LHpi.Data.sets[sid].name,lastnonempty,site.sets[sid].pages), 1)
					end
				end
			end -- if CHECKEXPECTED
			
			for lid,_lang in pairs(importlangs) do
				totalcount.pset[lid]=totalcount.pset[lid]+persetcount.pset[lid]
				totalcount.failed[lid]=totalcount.failed[lid]+persetcount.failed[lid]
			end
			totalcount.dropped=totalcount.dropped+persetcount.dropped
			totalcount.namereplaced=totalcount.namereplaced+persetcount.namereplaced
			totalcount.foiltweaked=totalcount.foiltweaked+persetcount.foiltweaked		
		else--not importsets[sid]
			LHpi.Log("Set " .. importsets[cSet.id] .. "not imported." ,1)
		end -- if/else importsets[sid]
	end -- for sid,cSet
	return totalcount,setcountdiffers
end -- function LHpi.MainImportCycle 

--[[- load and execute LHpi.Data.
 which contains LHpi.Data.sets with predefined variant,foiltweak and cardcount
 
 @function [parent=#LHpi] LoadData
 @param #string version		LHpi.Data version to be loaded
 @return #table		LHpi.Data
 ]]
function LHpi.LoadData( version )
	local Data=nil
	ma.SetProgress( "Loading LHpi.Data", 0 )
	do -- load LHpi predefined set data from external file
		local dataname = LHpi.workdir.."lib\\LHpi.Data-v" .. version .. ".lua"
		local olddataname = LHpi.workdir.."LHpi.Data-v" .. version .. ".lua"
		local LHpiData = ma.GetFile( dataname )
		local oldLHpiData = ma.GetFile ( olddataname )
		if oldLHpiData then
			if DEBUG then
				error("LHpi.Data found in deprecated location. Please move it to Prices\\lib subdirectory!")
			end
			LHpi.Log("LHpi.Data found in deprecated location." ,0 )
			if not LHpiData then
				LHpi.Log( "Using file in old location as fallback." ,1)
				LHpiData = oldLHpiData
			end
		end
		if not LHpiData then
			error( "LHpi.Data " .. dataname .. " not found." )
		else -- execute LHpiData to make LHpi.Data.sets.* available
			LHpiData = string.gsub( LHpiData , "^\239\187\191" , "" ) -- remove unicode BOM (0xEF, 0xBB, 0xBF) for files tainted by it :)
			LHpi.Log( "LHpi.Data " .. dataname .. " loaded and ready for execution." ,1)
			local execdata,errormsg = load( LHpiData , "=(load) LHpi.Data" )
			if not execdata then
				error( errormsg )
			end
			Data = execdata()
		end	-- if not LHpidata else
	end -- do load LHpi data
	collectgarbage() -- we now have LHpi.Data.sets table, let's clear LHpiData and execdata() from memory
	LHpi.Log( "LHpi.Data is ready to use." ,0)
	return Data
end--function LHpi.LoadData

--[[- read MA suplied parameters and configure script instance.
 returns shortened versions of the ma supplied global parameters
 by stripping unsupported (by sitescript) langs and sets;
 and modifies global site.sets to exclude unwanted langs, frucs and sets

 @function [parent=#LHpi] ProcessUserParams
 @param #string importfoil	"Y"|"N"|"O"
 @param #table importlangs	{ #number (langid)= #string , ... }
 @param #table importsets	{ #number (setid)= #string , ... }
 @return #string "y"|"n"|"o"
 @return #table { #number (langid)= #string , ... }
 @return #table { #number (setid)= #string , ... }
 @return global #table site.sets is modified
 ]]
function LHpi.ProcessUserParams( importfoil , importlangs , importsets )
	ma.SetProgress( "Initializing", 0 )
	-- identify user defined sets to import
	local setlist = {}
	for sid,cSet in pairs( site.sets ) do
		if importsets[sid] then
			setlist[sid] = importsets[sid]
		else
			site.sets[sid] = nil
		end
	end
	if next(setlist) then
		LHpi.Log( "Importing Sets: " .. LHpi.Tostring( setlist ) ,0)
	else -- setlist is empty
	--[[local supsetlist = ""
		for lid,lang in pairs(site.sets) do
			if lang then
				supsetlist = supsetlist .. " " .. set.url
			end
		end
	--]]
		LHpi.Log( "No supported set selected; returning from script now." ,0)
		error ( "No supported set selected" .. --[[" , please select at least one of: " .. supsetlist .. ]] "." )
	end

	-- identify user defined languages to import
	local langlist = {}
	for lid,lang in pairs( site.langs ) do
		if importlangs[lid] then
			langlist[lid] = importlangs[lid]
		else
			for sid,cSet in pairs(site.sets) do
				site.sets[sid].lang[lid] = false
			end
		end
	end
	if next(langlist) then
		LHpi.Log( "Importing Languages: " .. LHpi.Tostring( langlist ) ,0)
	else -- langlist is empty
		local suplanglist = ""
		for lid,lang in pairs(site.langs) do
			if lang then
				suplanglist = suplanglist .. " " .. LHpi.Data.languages[lid].full
			end
		end
		LHpi.Log( "No supported language selected; returning from script now." ,0)
		error ( "No supported language selected, please select at least one of: " .. suplanglist .. "." )
	end
	
	-- identify user defined types of foiling to import
	local lowerfoil = string.lower( importfoil )
	if lowerfoil == "y" then
		--don't disable any fruc
		LHpi.Log("Importing Non-Foil and Foil Card Prices" ,0)
	else
		for fid = 1,LHpi.Length(site.frucs) do
			if site.frucs[fid].isfoil and site.frucs[fid].isnonfoil then
				--never disable this fruc. dropping needs to be done on a per-card-base in BuildCardData
			else 
				for sid,cSet in pairs(site.sets) do		
					if lowerfoil == "n" and not site.frucs[fid].isnonfoil then -- disable foil only frucs
						site.sets[sid].fruc[fid] = false
					end--if lowerfoil=="n"
					if lowerfoil == "o" and not site.frucs[fid].isfoil then -- disable nonfoil only frucs
						site.sets[sid].fruc[fid] = false
					end--if lowerfoil=="o"
				end --for sid
			end--if fruc.isfoil/isnonfoil
		end--for fid
		if lowerfoil == "n" then
			LHpi.Log("Importing Non-Foil Only Card Prices" ,0)
		elseif lowerfoil == "o" then
			LHpi.Log("Importing Foil Only Card Prices" ,0)
		end -- if lowerfoil
	end--if

	if not VERBOSE then
		LHpi.Log("If you want to see more detailed logging, edit Prices\\" .. site.scriptname .. " and set VERBOSE = true.", 0)
	end
	return lowerfoil, langlist, setlist
end -- function LHpi.ProcessUserParams

--[[- build a list of sources (urls/files) we need.
 The urls will have to be concatenated eventually ayways, but doing it now
 (instead of concatenating the url just before we fetch the source data)
 allows a more detailed progress bar, though at the cost of an additional loop through site.sets.
  
 @function [parent=#LHpi] ListSources
 @param #string importfoil	"y"|"n"|"o"
 @param #table importlangs	{ #number (langid)= #string , ... }
 @param #table importsets	{ #number (setid)= #string , ... }
 @return #table	{ #number (setid)= #table { #string (url) = #table { isfile= #boolean } , ... } , ... }
 @return #number its length (for progressbar)
 ]]
function LHpi.ListSources ( importfoil , importlangs , importsets )
	ma.SetProgress( "Building list of price sources", 0 )
	local urls={}
	local urlcount = 0
	for sid,cSet in pairs( site.sets ) do
		if importsets[sid] then
			urls[sid]={}
			for lid,lang in pairs( importlangs ) do
				if cSet.lang[lid] then
					for fid,fruc in pairs ( site.frucs ) do
						if cSet.fruc[fid] then
							for url,urldetails in next, site.BuildUrl( sid , lid , fid , OFFLINE ) do
								urldetails.setid=sid
								urldetails.langid=lid
								urldetails.frucid=fid
									LHpi.Log( "site.BuildUrl is " .. LHpi.Tostring( url ) ,2)
								urls[sid][url] = urldetails
							end -- for url
						else
							LHpi.Log( string.format( "url for fruc %s (%i) not available", fruc.name, fid ) ,2)
						end -- if cSet.fruc[fid]
					end -- for fid,fruc
				else
					LHpi.Log( string.format( "url for lang %s (%i) not available", lang, lid ) ,2)
				end	-- if cSet.lang[lid]
			end -- for lid,_lang
			-- Calculate total number of sources for progress bar
			urlcount = urlcount + LHpi.Length(urls[sid])
		else
			LHpi.Log( string.format( "url for %s (%i) not available", importsets[sid], sid ) ,2)
		end -- if importsets[sid]
	end -- for sid,cSet
	LHpi.Logtable(urls, "urls" ,2)
	return urls, urlcount
end -- function LHpi.ListSources

--[[- construct url/filename fetch the contents
 fetch a page/file and return a string with the fetched content.
 Initial Parsing and calls to site.ParseHtmlData are then done by LHpi.ParseSourceData.

 @function [parent=#LHpi] GetSourceData
 @param #string url		source location (url or filename)
 @param #table details	{ setid= #number, langid= #number, frucid= #number, isfile= #boolean, oauth= #boolean }
 @return #string sourcedata
]]
function LHpi.GetSourceData( url , details ) -- 
	local sourcedata = nil -- declare here for right scope
	local status = nil
	local details = details or {}
	if OFFLINE then
		url = string.gsub(url, '[/\\:%*%?<>|"]', "_")
		details.isfile = true
	end
	if details.isfile then -- get htmldata from local source
		LHpi.Log( "Loading file: " .. url ,0)
		sourcedata = ma.GetFile( (LHpi.savepath or "") .. url )
		if not sourcedata then
			LHpi.Log( "!! GetFile failed for " .. (LHpi.savepath or "") .. url ,0)
			return nil
		end
	elseif details.oauth then -- we need to build a AOuth request and probably send it via https
		LHpi.Log("calling sitescript to fetch OAuth protected ressources from " .. url ,2)
		local status
		if site.FetchSourceDataFromOAuth then
			sourcedata, status = site.FetchSourceDataFromOAuth( url )
		else
			error("site.FetchSourceDataFromOAuth not implemented !")
		end
		if not sourcedata or sourcedata == "" then
			LHpi.Log( "!! site.FetchSourceDataFromOAuth failed for " .. url ,0)
			LHpi.Log("server response " .. status ,1)
			return nil,status
		end		
	else -- get htmldata from online source
		LHpi.Log( "Fetching http://" .. url ,0)
		sourcedata = ma.GetUrl( "http://" .. url )
		LHpi.Log("fetched remote file." ,2)
		if not sourcedata then
			LHpi.Log( "!! GetUrl failed for " .. url ,0)
			return nil
		end
	end -- if details.isfile

	if SAVEHTML and (not OFFLINE) then
		url = string.gsub(url, '[/\\:%*%?<>|"]', "_")
		LHpi.Log( "Saving source html to file: \"" .. (LHpi.savepath or "") .. url .. "\"" ,0)
		ma.PutFile( (LHpi.savepath or "") .. url , sourcedata , 0 )
	end -- if SAVEHTML
	
	if VERBOSE and site.resultregex then
		local _s,_e,results = string.find( sourcedata, site.resultregex )
		LHpi.Log( "html source data claims to contain " .. tostring(results) .. " cards." ,0)
	end

	return sourcedata
end -- function LHpi.GetSourceData

--[[- build sourceTable from (html) sourcedata
 get a string with a page's or file's contents (from LHpi.GetSourceData) and return a table with all entries found therein.
 Calls site.ParseHtmlData from sitescript.
 sourceurl, urldetails are also passed, so the split from GetSourceData is transparent to sitescripts.

 @function [parent=#LHpi] ParseSourceData
 @param #string sourcedata		source file contents
 @param #string url		source location (url or filename)
 @param #table details	{ setid= #number, langid= #number, frucid= #number, isfile= #boolean, oauth= #boolean }
 @return #table	{ #number= #table { names= #table { #number (langid)= #string , ... }, price= #number , foil= #boolean , ... } , ... } (OR nil instead of empty table.)
  : with entries as supplied by site.ParseHtmData.
]]
function LHpi.ParseSourceData( sourcedata,sourceurl,urldetails )
	if not sourcedata then
		return nil
	end
	local sourceTable = {}
	for foundstring in string.gmatch( sourcedata , site.regex) do
		if DEBUGFOUND then
			LHpi.Log( "FOUND : " .. foundstring ,2)
		end
		for _datanum,foundData in next, site.ParseHtmlData(foundstring , urldetails ) do
			-- do some initial input sanitizing: "_" to " "; remove spaces from start and end of string
			for lid,_cName in pairs( foundData.names ) do
				if urldetails.setid == 600 then
					foundData.names[lid] = string.gsub( foundData.names[lid], "^_+$" , "Unhinged Shapeshifter" )
				end
				foundData.names[lid] = LHpi.Toutf8( foundData.names[lid] )
				foundData.names[lid] = string.gsub( foundData.names[lid], "_", " " )
				foundData.names[lid] = string.gsub( foundData.names[lid], "^%s*(.-)%s*$", "%1" )
			end -- for lid,_cName
			-- divide price by 100 again (see site.ParseHtmlData in sitescript for reason)
--			if "Table" == type(foundData.price) then
--				for lid,price in pairs(foundData.price) do
--					foundData.price[lid] = ( foundData.price[lid] or 0 ) / 100
--				end
--			else
				foundData.price = ( foundData.price or 0 ) / 100
--			end-- if "Table"
--			if foundData.regprice then
--				if "Table" == type(foundData.regprice) then
--					for lid,lang in pairs(foundData.regprice) do
--						foundData.regprice[lid] = ( foundData.regprice[lid] or 0 ) / 100
--					end
--				else
--					foundData.regprice = ( foundData.regprice or 0 ) / 100
--				end-- if "Table"
--			end--if foundData.regprice
--			if foundData.foilprice then
--				if "Table" == type(foundData.foilprice) then
--					for lid,lang in pairs(foundData.foilprice) do
--						foundData.foilprice[lid] = ( foundData.foilprice[lid] or 0 ) / 100
--					end
--				else
--					foundData.foilprice = ( foundData.foilprice or 0 ) / 100
--				end-- if "Table"
--			end--if foundData.foilprice
			if next( foundData.names ) then
				table.insert( sourceTable , foundData ) -- actually keep ParseHtmlData-supplied information
			else -- nothing was found
				LHpi.Log( "foundstring contained no data" ,1)
				LHpi.Log( string.format("FOUND : '%s'" ,foundstring) ,2)
				LHpi.Log( "foundData :" .. LHpi.Tostring(foundData) ,2)
--				if DEBUG then
--					error( "foundstring contained no data" )
--				end
			end
		end--for _datanum,foundData
	end -- for foundstring
	sourcedata = nil 	-- potentially large htmldata now ready for garbage collector
	collectgarbage()
	LHpi.Logtable( sourceTable , "sourceTable" ,2)
	if table.maxn( sourceTable ) == 0 then
		return nil
	end
	return sourceTable
end--function LHpi.ParseSourceData

--[[- construct card data.
 constructs card data for one card entry found in htmldata.
 uses site.BCDpluginName and site.BCDpluginCard.
 fields already existing in sourceTable will be kept, so site.ParseHtmlData could preset more fields if neccessary.
 additional data can be passed from site.ParseHtmlData to site.BCDpluginName and/or site.BCDpluginCard via pluginData field.
 
 @function [parent=#LHpi] BuildCardData
 @param #table sourcerow	from sourceTable, returned from ParseSourceData
 @param #number setid		(see "..\Database\Sets.txt")
 @param #string importfoil	"y"|"n"|"o" passed from DoImport to drop unwanted cards
 @param #table importlangs	{ #number (langid)= #string, ... } passed from DoImport to drop unwanted cards
 @return #table		{ name= #string , drop= #boolean , lang= #table , (optional) names= #table , variant= #table , regprice= #numer or #table , foilprice= #number or #table , objtype= #number }  : card
 @return #number	0 or 1: namereplace event to be counted in LHpi.MainImportCycle
 @return #number	0 or 1: foiltweak event to be counted in LHpi.MainImportCycle
 
 @return #string card.name		: unique card name used as index in cardsetTable (localized name with lowest langid)
 @return #boolean card.drop		: true if data was marked as to-be-dropped and further processing was skipped
 @return #table card.lang		: card languages { #number (langid)= #string , ... }
 @return #table card.names		: card names by language { #number (langid)= #string , ... }
 @return #table card.variant	: table of variant names { #number= #string , ... }, nil if single-versioned card
 @return #table card.regprice	: { #number (langid)= #number , ... } nonfoil prices by language, subtables if variant
 @return #table card.foilprice	: { #number (langid)= #number , ... }    foil prices by language, subtables if variant
 @return #table card.objtype	: 0:all, 1:card, 2:token, 3:nontraditional, 4:insert, 5:replica; table if variant
 ]]
function LHpi.BuildCardData( sourcerow , setid , importfoil, importlangs )
	local card = { names = {} , lang = {} }
	local namereplaced = 0
	local foiltweaked = 0
 
	-- set name to identify the card
	if sourcerow.name~=nil and sourcerow.name~="" then -- keep site.ParseHtmlData preset name 
		card.name = sourcerow.name
	else
	-- set lowest langid name as internal name (primary key, unique card identifier)
		for langid = 1,16  do
			if sourcerow.names[langid]~=nil and sourcerow.names[langid]~="" then
				card.name = sourcerow.names[langid]
				break
			end -- if
		end -- for lid,name
	end --  if sourcerow.name

	if sourcerow.pluginData~=nil then -- keep site.ParseHtmlData additional info
		card.pluginData= sourcerow.pluginData
	end

	-- set card languages
	if sourcerow.lang~=nil then -- keep site.ParseHtmlData preset lang 
		card.lang = sourcerow.lang
	else
		-- use names{} and importlangs to determine card languages
		for lid,_ in pairs( importlangs ) do --only set langs the user wants imported
			if sourcerow.names[lid]~=nil and (sourcerow.names[lid] ~= "") then
				card.names[lid] = sourcerow.names[lid]
				card.lang[lid] = LHpi.Data.languages[lid].abbr
			end
		end -- for lid,_
	end -- if sourcerow.lang

	if not card.name then-- should not be reached, but caught here to prevent errors in string.gsub/find below
		card.drop = true
		card.name = "(DROPPED nil-name)"
	end --if not card.name
	if sourcerow.drop then -- keep site.ParseHtmlData preset drop
		card.drop = sourcerow.drop
	end -- if
	
	--[[ do site-specific card data manipulation before processing 
	]]
	if site.BCDpluginPre then
		card = site.BCDpluginPre ( card , setid , importfoil, importlangs )
	end
	
	-- drop unwanted sourcedata before further processing
	if string.find( card.name , "%(DROP.*%)" ) then
		card.drop = true
		LHpi.Log ( "LHpi.buildCardData\t dropped card " .. LHpi.Tostring(card) ,2)
	end -- if entry to be dropped
	if card.drop then
		return card,namereplaced,foiltweaked
	end--if card.drop
	
	card.name = string.gsub( card.name , " ?// ?" , "|" )
	card.name = string.gsub( card.name , " / " , "|" )
	card.name = string.gsub (card.name , "([%aäÄöÖüÜ]+)/([%aäÄöÖüÜ]+)" , "%1|%2" )
	card.name = string.gsub( card.name , "´" , "'" )
--	card.name = string.gsub( card.name , '"' , "“" )
	card.name = string.gsub( card.name , "^Unhinged Shapeshifter$" , "_____" )
	
	-- unify collector number suffix. must come before variant checking
	card.name = string.gsub( card.name , "%(Nr%. -(%d+)%)" , "(%1)" )
	card.name = string.gsub( card.name , " *(%(%d+%))" , " %1" )
	card.name = string.gsub( card.name , " Nr%. -(%d+)" , " (%1)" )
	card.name = string.gsub( card.name , " # ?(%d+)" , " (%1)" )
	card.name = string.gsub( card.name , "[%[%(][vV]ersion (%d+)[%]%)]" , "(%1)" )
	--card.name = string.gsub( card.name , "%([vV]ersion (%d)%)" , "(%1)" )
	card.name = string.gsub( card.name , "%((%d+)/%d+%)" , "(%1)" )
	card.name = string.gsub( card.name , "%(0+(%d+)%)" , "(%1)")

	if sourcerow.foil~=nil then -- keep site.ParseHtmlData preset foil
		card.foil = sourcerow.foil
	else
		if LHpi.Data.sets[setid].foilonly then
			card.foil = true
		elseif string.find ( card.name, "[%(-].- ?[fF][oO][iI][lL] ?.-%)?" ) then
			card.foil = true -- check cardname
		else
			card.foil = false
		end -- if foil
	end -- if sourcerow.foil
	card.name = string.gsub( card.name , "([%(-].-) ?[fF][oO][iI][lL] ?(.-%)?)" , "%1%2" )
	card.name = string.gsub( card.name , "%( -%)" , "" ) -- remove empty brackets
	card.name = string.gsub(card.name , "-$" , "" ) -- remove dash from end of string
	-- removal of foil suffix  must come before variant and namereplace check
	
	card.name = string.gsub( card.name , "%s+" , " " ) -- reduce multiple spaces
	card.name = string.gsub( card.name , "^%s*(.-)%s*$" , "%1" ) --remove spaces from start and end of string

	LHpi.Log(card.name .. ":" .. LHpi.ByteRep(card.name) , 2)
	
	if site.namereplace[setid] and site.namereplace[setid][card.name] then
		if LOGNAMEREPLACE then
			LHpi.Log( string.format( "namereplaced %s to %s" ,card.name, site.namereplace[setid][card.name] ), 0)
		end
		card.name = site.namereplace[setid][card.name]
		namereplaced=1
	end -- site.namereplace[setid]

	-- unify Oversized suffix
	card.name= string.gsub(card.name,"[ %-%(]*[Oo][Vv][Ee][Rr][Ss]%.?[Ii]?[Zz]?[Ee]?[Dd]?%)?$"," (oversized)")

	-- foiltweak, should be after namereplace and before variants, to work with oversized foilonly commanders
	if site.foiltweak[setid] and site.foiltweak[setid][card.name] then
		if LOGFOILTWEAK then
			LHpi.Log( string.format( "foiltweaked %s from %s to %s" ,card.name, tostring(card.foil), tostring(site.foiltweak[setid][card.name].foil) ), 1)
		end
		card.foil = site.foiltweak[setid][card.name].foil
		foiltweaked=1
	end -- if site.foiltweak

	-- drop for foil reasons must happen after foiltweak
	if importfoil == "n" and card.foil then
		card.name = card.name .. "(DROP foil)"
		card.drop = true
	elseif importfoil == "o" and (not card.foil) then
		card.name = card.name .. "(DROP nonfoil)"
		card.drop = true
	end-- if importfoil == "y" no reason for drop here
	if card.drop then
		return card,namereplaced,foiltweaked
	end--if card.drop
	
	-- unify basic land names
	if sourcerow.names then
		if sourcerow.names[3] then
			-- replace German Basic Lands' name with English to avoid needing a duplicate variant table. 
			card.name = string.gsub ( card.name , "^Ebene (%(%d+%))" , "Plains %1" )
			card.name = string.gsub ( card.name , "^Insel (%(%d+%))" , "Island %1" )
			card.name = string.gsub ( card.name , "^Sumpf (%(%d+%))" , "Swamp %1" )
			card.name = string.gsub ( card.name , "^Gebirge (%(%d+%))" , "Mountain %1" )
			card.name = string.gsub ( card.name , "^Wald (%(%d+%))" , "Forest %1" )
			-- and again for unversioned. matching start _and_ end of string to avoid generating "Islandheiligtum", "Forestesbibliothek" etc.
			card.name = string.gsub ( card.name , "^Ebene$" , "Plains" )
			card.name = string.gsub ( card.name , "^Insel$" , "Island" )
			card.name = string.gsub ( card.name , "^Sumpf$" , "Swamp" )
			card.name = string.gsub ( card.name , "^Gebirge$" , "Mountain" )
			card.name = string.gsub ( card.name , "^Wald$" , "Forest" )
		end
		if sourcerow.names[9] then --Simplified Chinese Basic Lands
			card.name = string.gsub ( card.name , "^平原 (%(%d+%))" , "Plains %1" )
			card.name = string.gsub ( card.name , "^海岛 (%(%d+%))" , "Island %1" )
			card.name = string.gsub ( card.name , "^沼泽 (%(%d+%))" , "Swamp %1" )
			card.name = string.gsub ( card.name , "^山脉 (%(%d+%))" , "Mountain %1" )
			card.name = string.gsub ( card.name , "^树林 (%(%d+%))" , "Forest %1" )
			card.name = string.gsub ( card.name , "^平原$" , "Plains" )
			card.name = string.gsub ( card.name , "^海岛$" , "Island" )
			card.name = string.gsub ( card.name , "^沼泽$" , "Swamp" )
			card.name = string.gsub ( card.name , "^山脉$" , "Mountain" )
			card.name = string.gsub ( card.name , "^树林$" , "Forest" )	
		end--if sourcerow.names
		-- TODO basic land names could probably need replacements for all languages
	end

	-- ma database object type, after namereplacement and before variant, but removal of token and other objtype pre-/suffix after variant
	-- We need to make sure we distinguish regular vs. oversized, so by default objtype=1 is required.
	-- This could show unwanted behaviour for multiple database objects with the same name in one set,
	-- such as Oversized Commander Replica in the Commander sets. LHpi only has card.name as primary object identifier,
	-- so objtype could be overwritten and we'd be back to averaging.
	-- Instead we'll use the existing variant loops and set the variant names "Token", "Nontrad", "Replica" via variant tables.  
	-- LHpi.SetPrice will then change these variants into explicit object type declaration.
	local objtype = nil
	if sourcerow.objtype ~=nil then
		objtype = sourcerow.objtype
	-- Token and Emblems are handled below
	--elseif string.find (card.name, "[tT][oO][kK][eE][nN]" ) then
	--	card.objtype = 2
	elseif string.find(card.name, "%([Nn][Oo][Nn][Tt][Rr][Aa][Dd]%.?[Ii]?[Tt]?[Ii]?[Oo]?[Nn]?[Aa]?[Ll]?%)") then
		card.name = string.gsub(card.name,"%([Nn][Oo][Nn][Tt][Rr][Aa][Dd]%.?[Ii]?[Tt]?[Ii]?[Oo]?[Nn]?[Aa]?[Ll]?%)","")
		objtype = 3
	elseif string.find(card.name, "%([Ii][Nn][Ss]%.?[Ee]?[Rr]?[Tt]?%)") then
		card.name = string.gsub(card.name,"%([Ii][Nn][Ss]%.?[Ee]?[Rr]?[Tt]?%)","")
		objtype = 4
	elseif string.find(card.name, "%([Rr][Ee][Pp][Ll]%.?[Ii]?[Cc]?[Aa]?%)") then
		--card.name = string.gsub(card.name,"%([Rr][Ee][Pp][Ll]%.?[Ii]?[Cc]?[Aa]?%)","(Replica)")
		-- keep suffix for variants
		objtype = 5
	elseif string.find(card.name, "%([Pp]lane%)") then
		card.name = string.gsub(card.name,"%([Pp]lane%)","")
		objtype = 3
	elseif string.find(card.name, "%([Ss]cheme%)") then
		card.name = string.gsub(card.name,"%([Ss]cheme%)","")
		objtype = 3
	elseif string.find(card.name, "%([Cc]onspiracy%)") then
		card.name = string.gsub(card.name,"%([Cc]onspiracy%)","")
		objtype = 3
	elseif string.find(card.name, "%([Oo]versized%)$" ) then
		if setid == 778 -- Commander
		or setid == 801 -- Commander 2013
		or setid == 40 -- Arena/Colosseo Leagues Promos
		then
			-- keep suffix for variants
			objtype = 5 -- replica
		elseif setid == 792 then -- Commander's Arsenal
			card.name = string.gsub(card.name,"%s*%([Oo]versized%)$","")			
			objtype = 5 -- replica
		elseif setid == 761 -- Planechase
		or setid == 769 -- Archenemy
		or setid == 787 -- Planechase 2012 Edition
		or setid == 807 -- Conspiracy
		then
			card.name = string.gsub(card.name," *%([Oo]versized%)$","")
			objtype = 3 -- nontrad
		end-- if setid
	elseif setid == 105 --Collectors Edition
	or setid == 106 -- Collectors Edition
	or setid ==  69 -- Box Topper Cards
	then
		objtype = 5
	else
		objtype = 1
	end--if string.find

	-- variant checking must be after namereplacement, and should probably be before token pre-/suffix removal
	if sourcerow.variant then -- keep site.ParseHtmlData preset variant
		card.variant = sourcerow.variant
	else
	-- check site.variants[setid] table for variant
		card.variant = nil
		if site.variants[setid] and site.variants[setid][card.name] then  -- Check for and set variant (and new card.name)
			if DEBUGVARIANTS then DEBUG = true end
			card.variant = site.variants[setid][card.name][2]
			LHpi.Log( string.format("VARIANTS\tcardname \"%s\" changed to name \"%s\" with variant \"%s\"", card.name, site.variants[setid][card.name][1], LHpi.Tostring( card.variant ) ) ,2)
			card.name = site.variants[setid][card.name][1]
		else
--			--set variant to empty string
--			card.variant = { "" }
		end -- if site.variants[setid]
	end -- if sourcerow.variant
	-- remove unparsed leftover variant numbers
--keep then, let's see what breaks :)
--	card.name = string.gsub( card.name , "%(%d+%)" , "" )
	
	-- Token infix removal, must come after variant checking
	-- For object type detection, variant tables need to keep/set "Token" suffix.
	if string.find(card.name , "[tT][oO][kK][eE][nN]" ) then -- Token pre-/suffix and color suffix
		objtype = 2
		card.name = string.gsub( card.name , " ?[tT][oO][kK][eE][nN][ %-]*" , "" )
		card.name = string.gsub( card.name , "%((.*)White(.*)%)" , "(%1W%2)" )
		card.name = string.gsub( card.name , "%((.*)Blue(.*)%)" , "(%1U%2)" )
		card.name = string.gsub( card.name , "%((.*)Black(.*)%)" , "(%1B%2)" )
		card.name = string.gsub( card.name , "%((.*)Red(.*)%)" , "(%1R%2)" )
		card.name = string.gsub( card.name , "%((.*)Green(.*)%)" , "(%1G%2)" )
		card.name = string.gsub( card.name , "%([WUBRGCHTAM][/|]?[WUBRG]?%)" , "" )
		card.name = string.gsub( card.name , "%(Art%)" , "" )
		card.name = string.gsub( card.name , "%(Go?ld%)" , "" )
		card.name = string.gsub( card.name , "%(Multicolor%)" , "" )
		card.name = string.gsub( card.name , "%([Sp][Pp][Tt]%)" , "" )
		card.name = string.gsub( card.name , "%(%d+/?%d*%)" , "" )
--		card.name = string.gsub( card.name , "  +" , " " )
		card.name = string.gsub( card.name , "%s+" , " " )
		card.name = string.gsub( card.name , "%(%)%s*$" , "" )
--		card.name = string.gsub( card.name , "^%s*(.-)%s*$" , "%1" )
	end
	if string.find( card.name , "^Emblem" ) then -- Emblem prefix to suffix
		if card.name == "Emblem of the Warmind" 
		or card.name == "Emblem des Kriegerhirns"
		or card.name == "Emblema del Guerrafondaio"
		or card.name == "Emblema da Mente Belicosa"
		or card.name == "Emblema de la Mente bélica"
		or card.name == "Emblema receloso"
		or card.name == "Emblema Nefasto"
		then
			-- do nothing
		else
			card.name = string.gsub( card.name , "Emblem[-: ]+([^\"]+)" , "%1 Emblem" )
			card.name = string.gsub( card.name , "  +" , " " )
		end
	end
	if string.find(card.name , "Emblem$") then -- set object type to "token"
		if card.name == "Leering Emblem"
		or card.name == "Schielendes Emblem" then
			--do nothing
		else
			objtype = 2
		end
	end
	
	--card.condition[lid] = "NONE"

	card.name = string.gsub( card.name , "^%s*(.-)%s*$" , "%1" ) --remove any leftover spaces from start and end of string	
	--set card.objtype
	if card.variant then
		LHpi.Log( "VARIANTS objtype : " .. LHpi.Tostring(card.variant) ,2)
		card.objtype = {}
		for varnr,varname in pairs(card.variant) do
			LHpi.Log( string.format("VARIANTS\tvarnr is %i varname is %s", varnr, tostring(varname) ) ,2)
			if varname then
				card.objtype[varname] = objtype
			end -- if varname
		end -- for varname,varnr
	else -- not card.variant
		card.objtype = objtype
	end -- set objtype
	
	card.regprice={}
	card.foilprice={}
	-- I would prefer to skip as many loops as possible if we're to discard the results anyway...
	-- Therefore, we'll nest some ifs to skip some fors
	if sourcerow.regprice~=nil or sourcerow.foilprice~=nil then -- keep site.ParseHtmlData preset reg/foilprice		
--		-- keep #table, otherwise convert #number price to #table { #number (langid) = #number, ... }
		if sourcerow.regprice then
--			if "Table" == type(sourcerow.regprice) then
				card.regprice = sourcerow.regprice
--			else
--				for lid,_ in pairs(card.lang) do
--					card.regprice[lid]=sourcerow.regprice
--				end-- end for lid
--			end--if "Table"
		end--if sourcerow.regprice
		if sourcerow.foilprice then
--			if "Table" == type(sourcerow.foilprice) then
				card.foilprice = sourcerow.foilprice
--			else
--				for lid,_ in pairs(card.lang) do
--					card.foilprice[lid]=sourcerow.foilprice
--				end-- end for lid
--			end--if "Table"
		end--if sourcerow.foilprice
	else -- define price according to card.foil and card.variant
		if "Table" ~= type(sourcerow.price) then
			--convert #number price to #table { #number (langid) = #number, ... }
			local sourceprice=sourcerow.price
			sourcerow.price={}
			for lid,_ in pairs(card.lang) do
				sourcerow.price[lid]=sourceprice
			end--for lid
		end-- if not "Table"
		for lid,lang in pairs( card.lang ) do
			if importlangs[lid] then
				if card.variant then
					LHpi.Log( "VARIANTS pricing " .. lang .. " : " .. LHpi.Tostring(card.variant) ,2)
					if card.foil then
						if not card.foilprice[lid] then card.foilprice[lid] = {} end
					else -- nonfoil
						if not card.regprice[lid] then card.regprice[lid] = {} end
					end
					for varnr,varname in pairs(card.variant) do
						LHpi.Log( string.format("VARIANTS\tvarnr is %i varname is %s", varnr, tostring(varname) ) ,2)
						if varname then
							if card.foil then
								card.foilprice[lid][varname] = sourcerow.price[lid]
							else -- nonfoil
								card.regprice[lid][varname] = sourcerow.price[lid]
							end
						end -- if varname
					end -- for varname,varnr
				else -- not card.variant
					if card.foil then
						card.foilprice[lid] = sourcerow.price[lid]
					else -- nonfoil
						card.regprice[lid] = sourcerow.price[lid]
					end
				end -- define price
			else
				-- dont set unwanted language's prices
			end--if importlangs[lid]
		end -- for lid,_lang
	end--if sourcerow reg/foilprice
	
	--[[ do final site-specific card data manipulation
	]]
	if site.BCDpluginPost then
		card = site.BCDpluginPost ( card , setid , importfoil, importlangs )
	end
	if string.find( card.name , "%(DROP.*%)" ) then
		card.drop = true
		LHpi.Log ( "LHpi.buildCardData\t dropped card " .. LHpi.Tostring(card) ,2)
	end -- if entry to be dropped
	if card.drop then
		return card,namereplaced,foiltweaked
	end--if card.drop

	--make sure userParams are honoured, even when preset data is present
	if importfoil == "n" then
		card.foilprice = nil
	elseif importfoil == "o" then
		card.regprice=nil
	end-- if importfoil == "y" nothing to strip
	for lid,lang in pairs( site.langs ) do
		if not importlangs[lid] then
			card.lang[lid]=nil
			--if card.names then card.names[lid]=nil end
			if card.regprice then card.regprice[lid]=nil end
			if card.foilprice then card.foilprice[lid]=nil end
		end--if
	end--for lid
	
	card.foil = nil -- remove foilstat; info is retained in [foil|reg]price and it could cause confusion later
	card.pluginData = nil -- if present at all, should have been used and deleted by site.BCDpluginPre|Post 	
	LHpi.Log( "LHpi.buildCardData\t will return card " .. LHpi.Tostring(card) ,2)
	return card,namereplaced,foiltweaked
end -- function LHpi.BuildCardData

--[[- add card to cardsetTable.
 do duplicate checking and add card to global #table cardsetTable.
 cardsetTable will hold all prices to be imported, one row per card.
 moved to seperate function to allow early return,
 at the price of forcing cardsetTable to be global instead of local in MainImportCycle.
 calls LHpi.MergeCardrows
 
 @function [parent=#LHpi] FillCardsetTable
 @param #table card		single tablerow from BuildCardData: { name= #string , drop = #boolean , lang= #table , (optional) names= #table , variant= #table , regprice= #table , foilprice= #table , objtype= #number }
 @return #number	0 if new row, -1 to -9 if severe conflict
 @return #string	conflict description
 @return modifies global #table cardsetTable
]]
function LHpi.FillCardsetTable( card )
	LHpi.Log("FillCardsetTable\t with " .. LHpi.Tostring( card ) ,2)
	local newCardrow = { variant = card.variant , regprice = card.regprice , foilprice = card.foilprice , lang=card.lang , objtype=card.objtype}
	newCardrow.names=card.names
	local oldCardrow = cardsetTable[card.name]
	if oldCardrow then
		-- merge card.lang, so we'll loop through all languages present in either old or new cardrow
		local mergedlang = {}
		for lid,_lang in pairs(site.langs) do
			mergedlang[lid] = oldCardrow.lang[lid] or newCardrow.lang[lid]
		end -- for lid,_lang
		local mergedvariant = nil -- declare for scope, but keep nil for if
		if oldCardrow.variant and newCardrow.variant then -- unify variants
			mergedvariant = {}
			for varnr = 1,math.max( LHpi.Length( oldCardrow.variant ) , LHpi.Length( newCardrow.variant ) ) do
				LHpi.Log ( " varnr " .. varnr ,2)
				if newCardrow.variant[varnr] == oldCardrow.variant[varnr]
				or newCardrow.variant[varnr] and not oldCardrow.variant[varnr]
				or oldCardrow.variant[varnr] and not newCardrow.variant[varnr]
				then
					mergedvariant[varnr] = oldCardrow.variant[varnr] or newCardrow.variant[varnr]
					LHpi.Log( string.format("variant[%i] equal or only one set", varnr ) ,2)
				else
					-- this should never happen 
					LHpi.Log( "!!! " .. card.name .. ": FillCardsetTable\t conflict while unifying varnames" , 1)
					if DEBUG then 
						error( "FillCardsetTable conflict: variant[" .. varnr .. "] not equal. " )
					end
					return -1,"variant" .. varnr .. "name differs!"
				end -- if
			end -- for varnr
		elseif (oldCardrow.variant and (not newCardrow.variant)) or ((not oldCardrow.variant) and newCardrow.variant) then
			-- this is severe and should never ever happen
			LHpi.Log ("!!! " .. card.name .. ": FillCardsetTable\t conflict variant vs not variant" ,1)
			LHpi.Log ("oldCardrow.variant is:" .. LHpi.Tostring(oldCardrow.variant) ,1)
			LHpi.Log ("newCardrow.variant is:" .. LHpi.Tostring(newCardrow.variant) ,1)
			if DEBUG then
--				print("oldCardrow.variant is:" .. LHpi.Tostring(oldCardrow.variant))
--				print("newCardrow.variant is:" .. LHpi.Tostring(newCardrow.variant))
				error( "FillCardsetTable conflict in " .. card.name .. " : " .. LHpi.Tostring(oldCardrow.variant) .. " vs " .. LHpi.Tostring(newCardrow.variant) .. " !" )
			end
			return -9,"variant state differs"
		end -- if oldCardrow.variant and newCardrow.variant
				
		-- variant table equal (or equally nil) in old and new, now merge data
		local conflicts,mergedCardrow,conflictdesc = LHpi.MergeCardrows (card.name, mergedlang, oldCardrow, newCardrow, mergedvariant)
		--LHpi.Log(string.format("%i conflicts merging %s: %s" , conflicts,card.name,LHpi.Tostring(conflictdesc) ) ,2)
		if conflicts~=0 then
			LHpi.Log( string.format( "%i conflicts merging %s: %s" , conflicts,card.name,LHpi.Tostring(conflictdesc) ) ,1)
		end -- if
		LHpi.Log("to cardsetTable(mrg) " .. card.name .. "\t\t: " .. LHpi.Tostring(mergedCardrow) ,2)
		cardsetTable[card.name] = mergedCardrow
		return conflicts,"ok:merged rows",mergedCardrow
		
	else -- no oldCardrow, no conflict checking necessary
		local mergedCardrow = "not needed"
		LHpi.Log("to cardsetTable(new) " .. card.name .. "\t\t: " .. LHpi.Tostring(newCardrow) ,2)
		cardsetTable[card.name] = newCardrow
		return 0,"ok:new row",newCardrow
	end
	error( "FillCardsetTable did not return." )
end -- function LHpi.FillCardsetTable()

--[[- check conflicts while merging rows.
 used in LHpi.FillCardsetTable if card to be inserted already exists in cardsetTable.
 calls itself to pre-merge variant prices seperately.
 
 @function [parent=#LHpi] MergeCardrows
 @param #string name	only needed for readable log
 @param #table langs	{ #number= #string , ... }
 @param #table oldRow	{ lang= #table, (optional) variant= #table , regprice= #table , foilprice= #table , (optional) names= #table , objtype=#number } (from cardsetTable[card.name] )
 @param #table newRow	{ lang= #table, (optional) variant= #table , regprice= #table , foilprice= #table , (optional) names= #table , objtype=#number }
 @param #table variants (optional) { #number = #string , ... }
 @return #number	0 if all ok, number of conflicts otherwise
 @return #table		{ lang= #table, (optional) variant= #table , regprice= #table , foilprice= #table , (optional) names= #table , objtype=#number } merged cardrow to fill into cardsetTable
 @return #table		{ reg= #table { #number (langid)= #string , ... } , foil= { #number (langid)= #string , ... } } conflict description
]]
function LHpi.MergeCardrows ( name, langs,  oldRow , newRow , variants )
--TODO (((a+b)/2)+c)/2 != (a+b+c)/3 = (((a+b)/2*2)+c)/3 is 
--for mathematically correct averaging, need to attach a counter to averaged prices
--then on next averaging, do 
--if counter then newaverage=(oldaverage*(counter+1) + newprice) / (counter+2)
	local mergedRow = { regprice = {} , foilprice = {} , objtype = nil }
	local conflictdesc = {reg = {} , foil = {} , type = {} }
	local conflictcount=0
	if variants then
		mergedRow.objtype = {}
		--build temporary cardrows holding a single variant and recursively call LHpi.MergeCardrows again
		for varnr,varname in pairs(variants) do
			local oldVarrow = { regprice = {}, foilprice = {} , objtype = {} }
			local newVarrow = { regprice = {}, foilprice = {} , objtype = {} }
			if not oldRow.regprice then oldRow.regprice={} end
			if not newRow.regprice then newRow.regprice={} end
			if not oldRow.foilprice then oldRow.foilprice={} end
			if not newRow.foilprice then newRow.foilprice={} end
			for lid,_lang in pairs(langs) do
				if not oldRow.regprice[lid] then oldRow.regprice[lid] = {} end
				if not newRow.regprice[lid] then newRow.regprice[lid] = {} end
				if not oldRow.foilprice[lid] then oldRow.foilprice[lid] = {} end
				if not newRow.foilprice[lid] then newRow.foilprice[lid] = {} end
				oldVarrow.regprice[lid] = oldRow.regprice[lid][varname]
				newVarrow.regprice[lid] = newRow.regprice[lid][varname]
				oldVarrow.foilprice[lid] = oldRow.foilprice[lid][varname]
				newVarrow.foilprice[lid] = newRow.foilprice[lid][varname]
			end --for lid,_lang
			if not oldRow.objtype then oldRow.objtype={} end
			if not newRow.objtype then newRow.objtype={} end
			oldVarrow.objtype = oldRow.objtype[varname]
			newVarrow.objtype = newRow.objtype[varname]
			local varConflictcount, mergedVarrow, varconflictdesc = LHpi.MergeCardrows ( name .. "[" .. varnr .. "]" , langs , oldVarrow, newVarrow, nil)
			conflictcount = conflictcount + varConflictcount
			for lid,_lang in pairs(langs) do
				if not mergedRow.regprice[lid] then mergedRow.regprice[lid] = {} end		
				mergedRow.regprice[lid][varname] = mergedVarrow.regprice[lid]
				if not mergedRow.foilprice[lid] then mergedRow.foilprice[lid] = {} end	
				mergedRow.foilprice[lid][varname] = mergedVarrow.foilprice[lid]
				conflictdesc.reg[lid]=( conflictdesc.reg[lid] or "" ) .. "[" .. varnr .. "]" ..  varconflictdesc.reg[lid]
				conflictdesc.foil[lid]=( conflictdesc.foil[lid] or "" ) .. "[" .. varnr .. "]" ..  varconflictdesc.foil[lid]
			end -- for lid,_langs
			mergedRow.objtype[varname] = mergedVarrow.objtype
--			conflictdesc.reg = ( conflictdesc.reg or "" ) .. "[" .. varnr .. "]" ..  varconflictdesc.reg
--			conflictdesc.foil = ( conflictdesc.foil or "" ) .. "[" .. varnr .. "]" ..  varconflictdesc.foil
		end -- for varnr,varname 
	else -- no variant (even variants will end up here eventually due to recursion)
		if oldRow.regprice or newRow.regprice then
		--at least one row has a regprice, merge them
			if not oldRow.regprice then oldRow.regprice={} end
			if not newRow.regprice then newRow.regprice={} end
			for lid,_lang in pairs(langs) do
				if oldRow.regprice[lid] and oldRow.regprice[lid]~=0 then
					if newRow.regprice[lid] and newRow.regprice[lid]~=0 then
						if oldRow.regprice[lid] == newRow.regprice[lid] then
							conflictdesc.reg[lid] = "ok:equal"
							mergedRow.regprice[lid] = oldRow.regprice[lid] or newRow.regprice[lid]
						else--average
							conflictcount=conflictcount+1
							mergedRow.regprice[lid] = (oldRow.regprice[lid] + newRow.regprice[lid]) * 0.5
							conflictdesc.reg[lid] = "avg:" .. mergedRow.regprice[lid]
							--mergedRow.mergecounter++
							LHpi.Log(string.format("averaging conflicting %s regprice[%s] %g and %g to %g", name, LHpi.Data.languages[lid].abbr, oldRow.regprice[lid], newRow.regprice[lid], mergedRow.regprice[lid] ) ,1)
							LHpi.Log("!! conflicting regprice in lang [" .. LHpi.Data.languages[lid].abbr .. "]" ,2)
							LHpi.Log("oldRow: " .. LHpi.Tostring(oldRow) ,2)
							LHpi.Log("newRow: " .. LHpi.Tostring(newRow) ,2)
							if DEBUG then
								print(string.format("conflict in card %s lang %s: %s (reg)", name,LHpi.Data.languages[lid].abbr,conflictdesc.reg[lid]) )
								--error(string.format("conflict in card %s lang %s: %s (reg)", name,LHpi.Data.languages[lid].abbr,conflictdesc.reg[lid]) )
							end--if DEBUG
						end--if equals
					else
						conflictdesc.reg[lid] = "ok:old"
						mergedRow.regprice[lid] = oldRow.regprice[lid]
					end--if newRow
				elseif newRow.regprice[lid] and newRow.regprice[lid]~=0 then
					conflictdesc.reg[lid] = "ok:new"
					mergedRow.regprice[lid] = newRow.regprice[lid]
				else--no price at all
--					conflictcount=conflictcount+1
					conflictdesc.reg[lid]="ok:none"
					LHpi.Log( string.format("not merging nonexisting %s regprice[%s].", name, lid ) ,2)
				end-- if oldRow
			end--for lid,_lang
		end--if: done merging regprices
		
		if oldRow.foilprice or newRow.foilprice then
		--at least one row has a foilprice, merge them
			if not oldRow.foilprice then oldRow.foilprice={} end
			if not newRow.foilprice then newRow.foilprice={} end
			for lid,_lang in pairs(langs) do
				if oldRow.foilprice[lid] and oldRow.foilprice[lid]~=0 then
					if newRow.foilprice[lid] and newRow.foilprice[lid]~=0 then
						if oldRow.foilprice[lid] == newRow.foilprice[lid] then
							conflictdesc.foil[lid] = "ok:equal"
							mergedRow.foilprice[lid] = oldRow.foilprice[lid] or newRow.foilprice[lid]
						else--average
							conflictcount=conflictcount+1
							mergedRow.foilprice[lid] = (oldRow.foilprice[lid] + newRow.foilprice[lid]) * 0.5
--							mergedRow.mergecounter++				
							conflictdesc.foil[lid] = "avg:" .. mergedRow.foilprice[lid]
							LHpi.Log(string.format("averaging conflicting %s foilprice[%s] %g and %g to %g", name, LHpi.Data.languages[lid].abbr, oldRow.foilprice[lid], newRow.foilprice[lid], mergedRow.foilprice[lid] ) ,1)
							LHpi.Log("!! conflicting foilprice in lang [" .. LHpi.Data.languages[lid].abbr .. "]" ,2)
							LHpi.Log("oldRow: " .. LHpi.Tostring(oldRow) ,2)
							LHpi.Log("newRow: " .. LHpi.Tostring(newRow) ,2)
							if DEBUG then
								print(string.format("conflict in card %s lang %s: %s (foil)", name,LHpi.Data.languages[lid].abbr,conflictdesc.reg[lid]) )
								--error(string.format("conflict in card %s lang %s: %s (foil)", name,LHpi.Data.languages[lid].abbr,conflictdesc.reg[lid]) )
							end--if DEBUG
						end--if equals
					else
						conflictdesc.foil[lid] = "ok:old"
						mergedRow.foilprice[lid] = oldRow.foilprice[lid]
					end--if newRow
				elseif newRow.foilprice[lid] and newRow.foilprice[lid]~=0 then
						conflictdesc.foil[lid] = "ok:new"
					mergedRow.foilprice[lid] = newRow.foilprice[lid]
				else--no price at all
--					conflictcount=conflictcount+1
					conflictdesc.foil[lid]="ok:none"
					LHpi.Log( string.format("not merging nonexisting %s foilprice[%s].", name, lid ) ,2)
				end-- if oldRow
			end--for lid,_lang
		end--if: done merging foilprices
		--check/merge objtype
		if oldRow.objtype == newRow.objtype then
			mergedRow.objtype = oldRow.objtype
			conflictdesc.type="ok:equal"
		elseif oldRow.objtype and not newRow.objtype then
			mergedRow.objtype = oldRow.objtype
			conflictdesc.type="ok:old"
		elseif newRow.objtype and not oldRow.objtype then
			mergedRow.objtype = newRow.objtype
			conflictdesc.type="ok:new"
		else
			conflictcount=conflictcount+1
			conflictdesc.type="objtype mismatch:" .. tostring(oldRow.objtype) .. " vs " .. tostring(newRow.objtype)
			LHpi.Log( string.format("card \"%s\" objtype mismatch: old is %i but new is %i !", name, oldRow.objtype, newRow.objtype) ,0)
			if STRICTOBJTYPE then
				error( string.format("card \"%s\" objtype mismatch: old is %i but new is %i !", name, oldRow.objtype, newRow.objtype) )
			else
				mergedRow.objtype = 0
			end
		end
		LHpi.Log("merged objtype to " .. LHpi.Tostring(mergedRow.objtype) ,2)
	end -- if variants
	
	mergedRow.names = {}
	if not oldRow.names then oldRow.names={} end
	if not newRow.names then newRow.names={} end
	for lid=1,16 do --quick'n'dirty merge names
		mergedRow.names[lid] = oldRow.names[lid] or newRow.names[lid]
	end
	if mergedRow.names == {} then mergedRow.names = nil end
	mergedRow.lang = langs
	mergedRow.variant = variants
	return conflictcount,mergedRow,conflictdesc
end -- function LHpi.MergeCardrows

--[[- calls MA to set card price.
 
 @function [parent=#LHpi] SetPrice
 @param	#number setid	(see "Database\Sets.txt")
 @param #string name	card name MA will try to match to Oracle Name, then localized Name
 @param #table card		{ lang= #table, (optional) variant= #table , regprice= #table , foilprice= #table , objtype=#table } card data from cardsetTable
 @return #table { #number (langid)= #number , ... } sum of ma.SetPrice return values
 @return #table { #number (langid)= #number , ... } count ma.SetPrice returns 0 events
]]
function LHpi.SetPrice(setid, name, card)
	local psetcount = {}
	local failcount = {}
	local d
	if card.variant and DEBUGVARIANTS then
		d = DEBUG
		DEBUG = true
	end
	LHpi.Log( string.format("LHpi.SetPrice\t setid is %i name is %s card is %s", setid, name, LHpi.Tostring(card) ) ,2)
	if not card.regprice then card.regprice={} end
	if not card.foilprice then card.foilprice={} end
	for lid,lang in pairs(card.lang) do
		local perlangretval
		if card.variant then
			LHpi.Log( string.format("variant is %s regprice is %s foilprice is %s", LHpi.Tostring(card.variant), LHpi.Tostring(card.regprice[lid]), LHpi.Tostring(card.foilprice[lid]) ) ,2)
			if not card.regprice[lid] then card.regprice[lid] = {} end
			if not card.foilprice[lid] then card.foilprice[lid] = {} end
			for varnr, varname in pairs(card.variant) do
				local realvarname = varname
				LHpi.Log(string.format("varnr is %i varname is %q", varnr, tostring(varname) ) ,2)
				if varname then
					if string.find(varname,"[Tt][Oo][Kk][Ee][Nn]") then
						card.objtype[varname] = 2
						realvarname = string.gsub(realvarname," ?[Tt][Oo][Kk][Ee][Nn] ?","")
					elseif string.find(varname,"[Nn][Oo][Nn][Tt][Rr][Aa][Dd]") then
						card.objtype[varname] = 3
						realvarname = string.gsub(realvarname," ?[Nn][Oo][Nn][Tt][Rr][Aa][Dd] ?","")
					elseif string.find(varname,"[Ii][Nn][Ss][Ee][Rr][Tt]") then
						card.objtype[varname] = 4
						realvarname = string.gsub(realvarname," ?[Ii][Nn][Ss][Ee][Rr][Tt] ?","")
					elseif string.find(varname,"[Rr][Ee][Pp][Ll][Ii][Cc][Aa]") then
						card.objtype[varname] = 5
						realvarname = string.gsub(realvarname," ?[Rr][Ee][Pp][Ll][Ii][Cc][Aa] ?","")
					else
					end-- if string.find
					perlangretval = (perlangretval or 0) + ma.SetPrice(setid, lid, name, realvarname, card.regprice[lid][varname] or 0, card.foilprice[lid][varname] or 0, card.objtype[varname] or 0 )
				end -- if varname
			end -- for varnr,varname
		else -- no variant
			perlangretval = ma.SetPrice(setid, lid, name, "", card.regprice[lid] or 0, card.foilprice[lid] or 0, card.objtype or 0)
		end -- if card.variant
		
		-- count ma.SetPrice retval and log potential problems
		psetcount[lid] = ( psetcount[lid] or 0 ) + perlangretval
		local expected
		if card.variant then
			--expected = LHpi.Length(card.variant)
			for _varnr, varname in pairs(card.variant) do
				if varname~=nil then expected = (expected or 0) + 1 end
			end
		else
			expected = 1		
		end
		if perlangretval == expected then
			LHpi.Log( string.format("LHpi.SetPrice \"%s\" version %q objtype %s set to %s/%s non/foil %s times for laguage %s", name, LHpi.Tostring(card.variant), LHpi.Tostring(card.objtype), LHpi.Tostring(card.regprice[lid]), LHpi.Tostring(card.foilprice[lid]), tostring(perlangretval), lang ) ,2)
		else
			failcount[lid] = math.abs(expected - (perlangretval or 0) )
			if perlangretval == 0 or (not perlangretval) then
				LHpi.Log( string.format("! LHpi.SetPrice \"%s\" (object type %s) for language %s with n/f price %s/%s not ( %s times) set",name, LHpi.Tostring(card.objtype), lang, LHpi.Tostring(card.regprice[lid]), LHpi.Tostring(card.foilprice[lid]), tostring(perlangretval) ) ,1)
			else
				LHpi.Log( string.format("! LHpi.SetPrice \"%s\" (object type %s) for language %s returned unexpected retval \"%s\"; expected was %i", name, LHpi.Tostring(card.objtype), lang, tostring(perlangretval), expected ) ,1)
			end
			LHpi.Log(LHpi.Tostring(card.names) ,2)
		end--if perlangretval == expected
	end -- for lid,lang

	if DEBUGVARIANTS then DEBUG = d end

	return psetcount,failcount	
end -- function LHpi.SetPrice(setid, name, card)

--[[- save table as csv.
 file encoding is utf-8 without BOM
 @function [parent=#LHpi] SaveCSV( setid , tbl , path )
 @param	#number setid	(see "Database\Sets.txt")
 @param #table tbl		one set's cardsetTable
 @param #string path	path to save csv into, must end in "\\"
]]
function LHpi.SaveCSV( setid , tbl , path )
	local setname = LHpi.Data.sets[setid].name
	local filename = path .. setid .. "-" .. setname .. ".csv"
	LHpi.Log( "Saving table to file: \"" .. filename .. "\"" ,1)
	ma.PutFile( filename, "cardname\tcardprice\tsetname\tcardlanguage\tcardversion\tfoil|nonfoil\tcardnotes" , 0 )
	for name,card in pairs(cardsetTable) do
		for lid,lang in pairs(card.lang) do
			lang=LHpi.Data.languages[lid].full
			if not card.regprice then card.regprice={} end
			if not card.foilprice then card.foilprice={} end
			if card.variant then
				if not card.regprice[lid] then card.regprice[lid] = {} end
				if not card.foilprice[lid] then card.foilprice[lid] = {} end
				for varnr, varname in pairs(card.variant) do
					if varname then
						local cardline = string.format( "%s\t%-4.2f\t%s\t%s\t%s\t%s\t%s" , name, card.regprice[lid][varname] or 0, setname, lang, varname, "nonfoil", LHpi.Tostring(card) )
						ma.PutFile( filename , "\n" .. cardline , 1 )
						cardline = string.format( "%s\t%-4.2f\t%s\t%s\t%s\t%s\t%s" , name, card.foilprice[lid][varname] or 0, setname, lang, varname, "foil", LHpi.Tostring(card) )
						ma.PutFile( filename , "\n" .. cardline , 1 )
					end -- if varname
				end -- for varnr,varname
			else -- no card.variant
				local cardline = string.format( "%s\t%-4.2f\t%s\t%s\t%s\t%s\t%s" , name, card.regprice[lid] or 0, setname, lang, 0, "nonfoil", LHpi.Tostring(card) )
				ma.PutFile( filename , "\n" .. cardline , 1 )
				cardline = string.format( "%s\t%-4.2f\t%s\t%s\t%s\t%s\t%s" , name, card.foilprice[lid] or 0, setname, lang, 0, "foil", LHpi.Tostring(card) )
				ma.PutFile( filename , "\n" .. cardline , 1 )
			end -- if card.variant
		end -- for lid,lang
	end -- for cName,cCard in pairs(cardsetTable)	
end -- function LHpi.SaveCSV

--[[- detect BOMs to get file encoding.
@function [parent=#LHpi] GuessFileEncoding( str )
@param #string str		html raw data
@return #string "cp1252"|"utf8"|"utf16-le"|"utf16-be"
]]
function LHpi.GuessFileEncoding ( str )
	local e = "cp1252"
	if string.find(str , "^\239\187\191") then -- utf-8 BOM (0xEF, 0xBB, 0xBF)
		e = "utf-8"
	elseif string.find(str , "^\255\254") then -- utf-16 little-endian BOM (0xFF 0xFE)
		e = "utf-16-le"
	elseif string.find(str , "^\254\255") then -- utf-16 big-endian BOM (0xFE 0xFF)
		e = "utf-16-be"
	end
	return e	
end -- LHpi.GuessFileEncoding

--[[- get single-byte representation.
 Seperates the string parameter into single bytes and returns a string with a sequence of the byte's decimal representation.
 Can be used to find the right character replacements.

 @function [parent=#LHpi] ByteRep( str )
 @param #string str
 @return #string
]]
function LHpi.ByteRep ( str )
	if type(str) == "string" then
		local br = ""
		for i = 1, string.len(str) do
			local c = string.sub ( str, i, i)
			local b = string.byte (str, i)
			br = br .. "[" .. c .. "]=" .. b .. " "
		end -- for
		return br
	else
		if DEBUG then
			error(tostring(str) .. " is not a string.")
		end
		return nil
	end -- if
end -- function LHpi.ByteRep

--[[- sanitize CP-1252 encoded strings.
 For CP-1252 ("ANSI") this would not be necessary if the script was saved CP-1252 encoded
 instead of utf-8 (which would be customary for lua),
 but then again it would not send utf-8 strings to MA :)
 
 Only replaces previously encountered special characters;
 see https://en.wikipedia.org/wiki/Windows-1252#Codepage_layout if you need to add more.

@function [parent=#LHpi] Toutf8
@param #string str	string to be converted to utf-8
@param #string enc	(optional) source character encoding to convert from, defaults to site.encoding
@return #string with utf8 encoded non-ascii characters
]]
function LHpi.Toutf8( str , enc )
	local encoding = enc or site.encoding
	if "string" == type( str ) then
		if encoding == "utf-8" or encoding == "utf8" or encoding == "unicode" then
			return str -- exit asap
		elseif encoding == "cp1252" or encoding == "ansi" then
			str = string.gsub( str , "\133" , "..." )
			str = string.gsub( str , "\146" , "´" )
			str = string.gsub( str , "\147" , '"' )
			str = string.gsub( str , "\148" , '"' )
			str = string.gsub( str , "\174" , '®' )
			str = string.gsub( str , "\196" , "Ä" )
			str = string.gsub( str , "\198" , "Æ" )
			str = string.gsub( str , "\214" , "Ö" )
			str = string.gsub( str , "\220" , "Ü" )
			str = string.gsub( str , "\223" , "ß" )
			str = string.gsub( str , "\224" , "à" )
			str = string.gsub( str , "\225" , "á" )
			str = string.gsub( str , "\226" , "â" )
			str = string.gsub( str , "\228" , "ä" )
			str = string.gsub( str , "\233" , "é" )
			str = string.gsub( str , "\237" , "í" )
			str = string.gsub( str , "\246" , "ö" )
			str = string.gsub( str , "\250" , "ú" )
			str = string.gsub( str , "\251" , "û" )
			str = string.gsub( str , "\252" , "ü" )
		else
			if DEBUG then
				error("Conversion from " .. encoding .. " not implemented.")
			end
		end
		return str
	else
		error( "LHpi.Toutf8 called with non-string." )
	end
end -- function LHpi.Toutf8

--[[- flexible logging.
 if SAVELOG option is true, logs to a seperate logfile for each sitescript,
 otherwise use LHpi.log, which is overwritten on each sitescript initialization.
 
 loglevels:
  -1 to use ma.Log instead
   1 for VERBOSE
   2 for DEBUG, else log.
 add other levels as needed

 @function [parent=#LHpi] Log
 @param #string str		log text
 @param #number l		(optional) loglevel, default is normal logging
 @param #string f		(optional) logfile, default is scriptname.log
 @param #number a		(optional) 0 to overwrite, default is append
]]
function LHpi.Log( str , l , f , a )
	local loglevel = l or 0
	local apnd = a or 1
	local logfile = f or LHpi.logfile
	if loglevel == 1 then
		if not VERBOSE then
			return
		end
		str = " " .. str
	elseif loglevel == 2 then
		if not DEBUG then
			return
		end
		if os then
			str = string.format("%3.3f\t%s",os.clock(),str)
		else
			str = "DEBUG\t" .. str
		end
		--logfile = string.gsub(logfile, "log$", "DEBUG.log") -- for seperate debuglog
	elseif loglevel == 3 then
		logfile = string.gsub(logfile, "log$", "DEBUG.log")
	end
	if loglevel < 0 then
		ma.Log( "LHpi:" .. str )
	else
		if apnd ~= 0 then
			str = "\n" .. str
		end
		ma.PutFile( logfile , str , apnd )
	end
end -- function LHpi.Log

--[[- get array length.
 non-recursively count table rows.
 for non-tables, length(nil)=length(false)=nil, otherwise 1.
 
 @function [parent=#LHpi] Length
 @param #table tbl
 @return #number
]]
function LHpi.Length( tbl )
	if not tbl then
		return nil
	elseif type( tbl ) == "table" then
		local result = 0
		for _, __ in pairs( tbl ) do
			result = result + 1
		end
		return result
	else
		return 1
	end
end -- function LHpi.Length

--[[- recursively get string representation.
 
 @function [parent=#LHpi] Tostring
 @param tbl
 @return #string 
]]
function LHpi.Tostring( tbl )
	if type( tbl ) == 'table' then
		local s = '{ '
		for k,v in pairs( tbl ) do
			s = s .. '[' .. LHpi.Tostring( k ) .. ']=' .. LHpi.Tostring( v ) .. ';'
		end
		return s .. '} '
	elseif type( tbl ) == 'string' then
		return '"' .. tbl .. '"'
	else
		return tostring( tbl )
	end
end -- function LHpi.Tostring

--[[- log table by row.
 for large tables, LHpi.Tostring crashes ma. recursion too deep / out of memory ?
 this function LHpi.Tostrings and logs each row seperately .
 
 @function [parent=#LHpi] Logtable
 @param #table tbl
 @param #string str		(optional) table name, defaults to tostring(tbl)
 @param #number l		(optional) loglevel, defaults to 0
]]
function LHpi.Logtable( tbl , str , l )
	local name = str or tostring( tbl )
	local llvl = l or 0
	local c=0
	if type( tbl ) == "table" then
		LHpi.Log( string.format("BIGTABLE %s has %i rows:", name, LHpi.Length(tbl) ) , llvl )
		for k,v in pairs (tbl) do
			LHpi.Log( string.format("\tkey '%s' \t value '%s'", k, LHpi.Tostring(v) ), llvl )
			c = c + 1
		end
		if DEBUG then
			LHpi.Log( string.format("BIGTABLE %s sent to log in %i rows", name,c ) , llvl )
		end
	else
		--error( "LHpi.Logtable called for non-table" )
		LHpi.Log(LHpi.Tostring(tbl) , llvl )
	end
end -- function LHpi.Logtable

LHpi.Initialize()
--LHpi.Log( "\239\187\191LHpi library loaded and executed successfully" , 0 , nil , 0 ) -- add unicode BOM to beginning of logfile
LHpi.Log( "LHpi library " .. LHpi.version .. " loaded and executed successfully." , 0 , nil ,0)
return LHpi
--EOF