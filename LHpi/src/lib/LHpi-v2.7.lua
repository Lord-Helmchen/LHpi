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
local LHpi = {}

--[[ TODO generalizazion and improvement tasks
add all promo sets (cardcount,variants,foiltweak) to LHpi.Data

string.format all LOG that contain variables
	http://www.troubleshooters.com/codecorn/lua/luastring.htm#_String_Formatting

to anticipate sites that return "*CARDNAME*REGPRICE*FOILPRICE* instead of "*CARDNAME*PRICE*FOILSTATUS*"
 have site.ParseHtml return a collection of cards, similar to site.BuildUrl
 
change sitescripts to new library path, check comments versus template
]]

--[[ CHANGES
fix handling of site.ParseHtmlData supplied sourcerow.* data 
pass supImportfoil,supImportlangs from MainImportCycle to BuildCardData
BuildCardData drops unwanted foil/nonfoil cards/prices to make sure user wishes are honoured
ListSources now drops foilonly urls if foil import is deselected
externalized static set data to LHpi.Data
look for LHpi and LHpi.Data in Prices\lib\
set default values for unset sitescript options
fixed luadoc comments
]]

--- @field [parent=#LHpi] #string version
LHpi.version = "2.7"

--[[- "main" function called by Magic Album; just display error and return.
 Called by Magic Album to import prices. Parameters are passed from MA.
 We don't want to call the library directly.
 
 @function [parent=#global] ImportPrice
 @param #string importfoil	"Y"|"N"|"O"
 @param #table importlangs	{ #number = #string }
 @param #table importsets	{ #number = #string }
]]
function ImportPrice( importfoil , importlangs , importsets )
	ma.Log( "Called LHpi library instead of site script. Raising error to inform user via dialog box." )
	ma.Log( "LHpi library should be in \\lib subdir to prevent this." )
	LHpi.Log( LHpi.Tostring( importfoil ) )
	LHpi.Log( LHpi.Tostring( importlangs ) )
	LHpi.Log( LHpi.Tostring( importsets ) )
	error( "LHpi-v" .. LHpi.version .. " is a library. Please select a LHpi-sitescript instead!" )
end -- function ImportPrice

--[[- "main" function called by LHpi sitescript.
 Parameters are passed through sitescript's ImportPrice from Magic Album.
 This is all that a sitescript should need to do in its ImportPrice once LHpi library has been executed
  
 @function [parent=#LHpi] DoImport
 @param #string importfoil	"Y"|"N"|"O"
 @param #table importlangs	{ #number = #string }
 @param #table importsets	{ #number = #string }
]]

function LHpi.DoImport (importfoil , importlangs , importsets)
	--default values for feedback options
	if VERBOSE==nil then VERBOSE = false end
	if LOGDROPS==nil then LOGDROPS = false end
	if LOGNAMEREPLACE==nil then LOGNAMEREPLACE = false end
	if LOGFOILTWEAK==nil then LOGFOILTWEAK = false end
	-- default values for behaviour options
	if CHECKEXPECTED==nil then CHECKEXPECTED = true end
	if DEBUG==nil then DEBUG = false end
	if DEBUGSKIPFOUND==nil then DEBUGSKIPFOUND = true end
	if DEBUGVARIANTS==nil then DEBUGVARIANTS = false end
	if OFFLINE==nil then OFFLINE = false end
	if SAVEHTML==nil then SAVEHTML = false end
	if SAVELOG==nil then SAVELOG = true end
	if SAVETABLE==nil then SAVETABLE = false end
	-- create empty dummy fields for undefined sitescript fields to allow graceful exit
	if not site then site = {} end
	if DEBUG and ((not site.langs) or (not next(site.langs)) ) then error("undefined site.langs!") end
	if not site.langs then site.langs = {} end
	if DEBUG and ((not site.sets) or (not next(site.sets)) ) then error("undefined site.sets!") end
	if not site.sets then site.sets = {} end
	if DEBUG and ((not site.frucs) or (not next(site.frucs)) ) then error("undefined site.frucs!") end
	if not site.frucs then site.frucs = {} end
	if DEBUG and ((not site.regex) or site.regex == "" ) then error("undefined site.regex!") end
	if not site.regex then site.regex = "" end

	if DEBUG and ((not dataver) or site.dataver == "" ) then error("undefined dataver!") end
	if not dataver then dataver = "1" end
	LHpi.Data = LHpi.LoadData(dataver)
	-- read user supplied parameters and modify site.sets table
	local supImportfoil,supImportlangs, supImportsets = LHpi.ProcessUserParams( importfoil , importlangs , importsets )
	
	-- set sensible defaults or throw error on missing sitescript fields or functions
	if not scriptname then
	--- must always be equal to the scripts filename !
	-- @field [parent=#global] #string scriptname
		local _s,_e,myname = string.find( ( ma.GetFile( "Magic Album.log" ) or "" ) , "Starting Lua script .-([^\\]+%.lua)$" )
		if myname and myname ~= "" then
			scriptname = myname
		else -- use hardcoded scriptname as fallback
			scriptname = "LHpi.SITESCRIPT_NAME_NOT_SET-v" .. LHpi.version .. ".lua"
		end
	end -- if
	if not savepath then
	--- savepath for OFFLINE (read) and SAVEHTML (write). must point to an existing directory relative to MA's root.
	-- @field [parent=#global] #string savepath
		savepath = "Prices\\" .. string.gsub( scriptname , "%-v[%d%.]+%.lua$" , "" ) .. "\\"
	end -- if
	if SAVEHTML then
		ma.PutFile(savepath .. "testfolderwritable" , "true", 0 )
		local folderwritable = ma.GetFile( savepath .. "testfolderwritable" )
		if not folderwritable then
			SAVEHTML = false
			LHpi.Log( "failed to write file to savepath " .. savepath .. ". Disabling SAVEHTML" )
			if DEBUG then
				error( "failed to write file to savepath " .. savepath .. "!" )
				--print( "failed to write file to savepath " .. savepath .. ". Disabling SAVEHTML" )
			end
		end -- if not folderwritable
	end -- if SAVEHTML
	if not site.encoding then site.encoding = "cp1252" end
	if not site.currency then site.currency = "$" end
	if not site.namereplace then site.namereplace={} end
	if not site.variants then site.variants = {} end
	for sid,_setname in pairs(supImportsets) do
		if not site.variants[sid] then
			if LHpi.Data.sets[sid] then
				site.variants[sid] = LHpi.Data.sets[sid].variants
			end -- if
		end -- if
	end -- for
	if not site.foiltweak then site.foiltweak={} end
	for sid,_setname in pairs(supImportsets) do
		if not site.foiltweak[sid] then
			if LHpi.Data.sets[sid] then
				site.foiltweak[sid] = LHpi.Data.sets[sid].foiltweak
			end -- if
		end -- if
	end -- for
	if not site.condprio then site.condprio={ [0] = "NONE" } end
	if CHECKEXPECTED then
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
			for lid,langb in pairs (site.sets[sid].lang) do
				if langb then
					if not site.expected[sid].pset[lid] then
						if ( LHpi.Data.sets[sid] and LHpi.Data.sets[sid].cardcount ) then
							if site.expected.EXPECTTOKENS then
								site.expected[sid].pset[lid] = LHpi.Data.sets[sid].cardcount.reg + LHpi.Data.sets[sid].cardcount.tok 
							else
								site.expected[sid].pset[lid] = LHpi.Data.sets[sid].cardcount.reg
							end
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
	if not site.BuildUrl then
		function site.BuildUrl( setid,langid,frucid,offline )
			local errormsg = "sitescript " .. scriptname .. ": function site.BuildUrl not implemented!" 
			ma.Log( "!!critical error: " .. errormsg )
			error( errormsg )
		end	-- function
	end -- if
	if not site.ParseHtmlData then
		function site.ParseHtmlData( foundstring )
			local errormsg = "sitescript " .. scriptname .. ": function site.ParseHtmlData not implemented!" 
			ma.Log( "!!critical error: " .. errormsg )
			error( errormsg )
		end	-- function
	end -- if
-- Don't need to define defaults here as long as BuildCardData checks for their existence before calling them.	
--	if not site.BCDpluginPre then
--		function site.BCDpluginPre ( card , setid )
--			return card
--		end -- function
--	end -- if
--	if not site.BCDpluginPost then
--		function site.BCDpluginPost( card , setid )
--			card.BCDPluginData = nil
--			return card
--		end -- function
--	end -- if
	
	-- build sourceList of urls/files to fetch
	local sourceList, sourceCount = LHpi.ListSources( supImportfoil , supImportlangs , supImportsets )

	--- adds count of set,failed prices and drop,namereplace,foiltweak events.
	-- @field [parent=#global] #table totalcount
	totalcount = { pset= {}, failed={}, dropped=0, namereplaced=0, foiltweaked=0 }
	for lid,_lang in pairs(supImportlangs) do
		totalcount.pset[lid] = 0
		totalcount.failed[lid] = 0
	end -- for
	
	--- list sets where persetcount differs from site.expected[setid].
	-- @field [parent=#global] #table setcountdiffers
	setcountdiffers = {}
	--- count imported sourcefiles for progressbar.
	-- @field [parent=#global] #number curhtmlnum
	curhtmlnum = 0

	-- loop through importsets to parse html, build cardsetTable and then call ma.setPrice
	LHpi.MainImportCycle(sourceList, sourceCount, supImportfoil, supImportlangs, supImportsets)
	
	-- report final count
	LHpi.Log("Import Cycle finished.")
	ma.SetProgress( "Finishing", 100 )
	local totalcountstring = ""
	for lid,lang in pairs (supImportlangs) do
		totalcountstring = totalcountstring .. string.format( "%i set, %i failed %s cards\t", totalcount.pset[lid], totalcount.failed[lid], lang )
	end -- for
	LHpi.Log( string.format ( "Total counted : " .. totalcountstring .. "; %i dropped, %i namereplaced and %i foiltweaked.", totalcount.dropped, totalcount.namereplaced, totalcount.foiltweaked ) )
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
		LHpi.Log( string.format ( "Total expected: " .. totalexpectedstring .. "; %i dropped, %i namereplaced and %i foiltweaked.", totalexpected.dropped, totalexpected.namereplaced, totalexpected.foiltweaked ) )
		LHpi.Log ( "count differs in " .. LHpi.Length(setcountdiffers) .. " sets:" .. LHpi.Tostring(setcountdiffers ), 1 )
	end -- if CHECKEXPECTED	
end

--[[- Main import cycle 
 ,here the magic occurs.
 importfoil, importlangs, importsets are shortened to supported only entries by LHpi.ProcessUserParams
 to shorten loops, but could be used unmodified if wanted.
  
 @function [parent=#LHpi] MainImportCycle
 @param #table sourcelist	{ #number = { #string = #boolean }
 @param #number totalhtmlnum	for progressbar
 @param #string importfoil	"y"|"n"|"o"
 @param #table importlangs	{ #number = #string }
 @param #table importsets	{ #number = #string }
]]
function LHpi.MainImportCycle( sourcelist , totalhtmlnum , importfoil , importlangs , importsets )

	for sid,cSet in pairs( site.sets ) do
		if importsets[sid] then
			--- All import data for current set, one row per card.
			-- @field [parent=#global] #table cardsetTable
			cardsetTable = {} -- clear cardsetTable
			
			--- counts of set,failed prices and drop,namereplace,foiltweak events.
			-- @field [parent=#global] #table persetcount
			persetcount = { pset= {}, failed={}, dropped=0, namereplaced=0, foiltweaked=0 }
			for lid,_lang in pairs(importlangs) do
				persetcount.pset[lid] = 0
				persetcount.failed[lid] = 0
			end -- for
			local progress = 0
			-- build cardsetTable containing all prices to be imported
			for sourceurl,urldetails in pairs( sourcelist[sid] ) do
				curhtmlnum = curhtmlnum + 1
				progress = 100*curhtmlnum/totalhtmlnum
				pmesg = "Collecting " ..  importsets[sid] .. " into table"
				if VERBOSE then
					pmesg = pmesg .. " (id " .. sid .. ")"
					LHpi.Log( string.format( "%d percent: %q", progress, pmesg) , 1 )
				end
				ma.SetProgress( pmesg , progress )
				local sourceTable = LHpi.GetSourceData( sourceurl,urldetails )
				-- process found data and fill cardsetTable
				if sourceTable then
					for _,row in pairs(sourceTable) do
						local newcard = LHpi.BuildCardData( row , sid , urldetails.foilonly ,importfoil, importlangs)
						if newcard.drop then
							persetcount.dropped = persetcount.dropped + 1
							if DEBUG or LOGDROPS then
								LHpi.Log("DROPped cName \"" .. newcard.name .. "\"." ,0)
							end
						else -- not newcard.drop
							local ernum,errormsg,resultRow = LHpi.FillCardsetTable ( newcard )
						end -- if newcard.drop
						if DEBUGVARIANTS then DEBUG = false end
					end -- for i,row in pairs(sourceTable)
				else -- not sourceTable
					LHpi.Log("No cards found, skipping to next source" , 1 )
					if DEBUG then
						print("!! empty sourceTable for " .. importsets[sid] .. " - " .. sourceurl)
						--error("empty sourceTable for " .. importsets[sid] .. " - " .. sourceurl)
					end
				end -- if sourceTable
			end -- for _,source 
			-- build cardsetTable from htmls finished
			if VERBOSE then
--				local msg =  "cardsetTable for set " .. importsets[sid] .. "(id " .. sid .. ") build with " .. LHpi.Length(cardsetTable) .. " rows."
				local msg =  string.format( "cardsetTable for set %s (id %i) build with %i rows.",importsets[sid],sid,LHpi.Length(cardsetTable) )
				if ( LHpi.Data.sets[sid] and LHpi.Data.sets[sid].cardcount ) then
--					msg = msg ..  " Set supposedly contains " .. ( LHpi.Data.sets[sid].cardcount.reg or "#" ) .. " cards and " .. ( LHpi.Data.sets[sid].cardcount.tok or "#" ).. " tokens."
					msg = msg .. string.format( " Set supposedly contains %i cards and %i tokens.", LHpi.Data.sets[sid].cardcount.reg, LHpi.Data.sets[sid].cardcount.tok )
				else
					msg = msg .. " Number of cards in set is not known to LHpi."
				end 
				LHpi.Log( msg , 1 )
			end
			if SAVETABLE then
				LHpi.SaveCSV( sid, cardsetTable , savepath )
			end
			-- Set the price
			local pmesg = "Importing " .. importsets[cSet.id] .. " from table"
			if VERBOSE then
				LHpi.Log( pmesg .. "  " .. progress .. "%" , 1 )
			end -- if VERBOSE
			ma.SetProgress( pmesg, progress )
			for cName,cCard in pairs(cardsetTable) do
				if DEBUG then
					LHpi.Log( "ImportPrice\t cName is " .. cName .. " and table cCard is " .. LHpi.Tostring(cCard) , 2 )
				end
				LHpi.SetPrice( sid , cName , cCard )
			end -- for cName,cCard in pairs(cardsetTable)
			
		end -- if importsets[sid]
		local statmsg = "Set " .. importsets[cSet.id] .. " imported." 
		LHpi.Log ( statmsg )
		if VERBOSE then
			if ( LHpi.Data.sets[sid] and LHpi.Data.sets[sid].cardcount ) then
--				LHpi.Log( "[" .. cSet.id .. "] contains \t" .. ( LHpi.Data.sets[sid].cardcount.both or "#" ) .. " cards (\t" .. ( LHpi.Data.sets[sid].cardcount.reg or "#" ) .. " regular,\t " .. ( LHpi.Data.sets[sid].cardcount.tok or "#" ) .. " tokens )" )
				LHpi.Log( string.format( "[%i] contains %4i cards (%4i regular, %4i tokens )", cSet.id, LHpi.Data.sets[sid].cardcount.both, LHpi.Data.sets[sid].cardcount.reg, LHpi.Data.sets[sid].cardcount.tok ) )
			else
				LHpi.Log( string.format( "[%i] contains unknown to LHpi number of cards.", cSet.id ) )
			end
		end
		if DEBUG then
			LHpi.Log( "persetstats " .. LHpi.Tostring( persetcount ) , 1 )
		end
		
		if CHECKEXPECTED then
			if site.expected[sid] then
				local allgood = true
				for lid,_cLang in pairs(importlangs) do
					if ( site.expected[cSet.id].pset[lid] or 0 ) ~= persetcount.pset[lid] then allgood = false end
					if ( site.expected[cSet.id].failed[lid] or 0 ) ~= persetcount.failed[lid] then allgood = false end
				end -- for lid,_cLang in importlangs
				if VERBOSE then
					if ( site.expected[sid].dropped or 0 ) ~= persetcount.dropped then allgood = false end
					if ( site.expected[sid].namereplaced or 0 ) ~= persetcount.namereplaced then allgood = false end
					if ( site.expected[sid].foiltweaked or 0 ) ~= persetcount.foiltweaked then allgood = false end
				end
				if not allgood then
--					LHpi.Log( ":-( persetcount for " .. importsets[sid] .. "(id " .. sid .. ") differs from expected. " , 1 )
					LHpi.Log( string.format( ":-( persetcount for %s (id %i) differs from expected. ", importsets[sid], sid ) , 1)
					table.insert( setcountdiffers , sid , importsets[sid] )
					if VERBOSE then
						local setcountstring = ""
						for lid,lang in pairs (importlangs) do
							if cSet.lang[lid] then
								setcountstring = setcountstring .. string.format( " %3i set & %3i failed %8s cards ;", persetcount.pset[lid], persetcount.failed[lid], lang )
							end -- if
						end -- for
						LHpi.Log( string.format ( ":-( counted :" .. setcountstring .. " %3i dropped, %3i namereplaced and %3i foiltweaked.", persetcount.dropped, persetcount.namereplaced, persetcount.foiltweaked ) , 1 )
						local setexpectedstring = ""
						for lid,lang in pairs (importlangs) do
							if cSet.lang[lid] then
								setexpectedstring = setexpectedstring .. string.format( " %3i set & %3i failed %8s cards ;", site.expected[sid].pset[lid], site.expected[sid].failed[lid], lang )
							end -- if
						end -- for
						LHpi.Log( string.format ( ":-( expected:" .. setexpectedstring .. " %3i dropped, %3i namereplaced and %3i foiltweaked.", site.expected[sid].dropped or 0 , site.expected[sid].namereplaced or 0, site.expected[sid].foiltweaked or 0 ) , 1 )
						LHpi.Log( "namereplace table for the set contains " .. ( LHpi.Length(site.namereplace[sid]) or "no" ) .. " entries." , 1 )
						LHpi.Log( "foiltweak table for the set contains " .. ( LHpi.Length(site.foiltweak[sid]) or "no" ) .. " entries." , 1 )
					end
					if DEBUG then
						print( "not allgood in set " .. importsets[sid] .. "(" ..  sid .. ")" )
						--error( "not allgood in set " .. importsets[sid] .. "(" ..  sid .. ")" )
					end
				else
--					LHpi.Log( ":-) Prices for set " .. importsets[sid] .. "(id " .. sid .. ") were imported as expected :-)" , 1 )
					LHpi.Log( string.format( ":-) Prices for set %s (id %i) were imported as expected :-)", importsets[sid], sid ), 1 )
				end
			else
--				LHpi.Log( "No expected persetcount for " .. importsets[sid] .. "(id " .. sid .. ") found." , 1 )
				LHpi.Log( string.format( "No expected persetcount for %s (id %i) found.", importsets[sid], sid ), 1 )
			end -- if site.expected[sid] else
		end -- if CHECKEXPECTED
		
		for lid,_lang in pairs(importlangs) do
			totalcount.pset[lid]=totalcount.pset[lid]+persetcount.pset[lid]
			totalcount.failed[lid]=totalcount.failed[lid]+persetcount.failed[lid]
		end
		totalcount.dropped=totalcount.dropped+persetcount.dropped
		totalcount.namereplaced=totalcount.namereplaced+persetcount.namereplaced
		totalcount.foiltweaked=totalcount.foiltweaked+persetcount.foiltweaked		
	end -- for sid,cSet

end -- function LHpi.MainImportCycle 

--[[- load and execute LHpi.Data.
 which contains LHpi.Data.sets with predefined variant,foiltweak and cardcount
 
 @function [parent=#LHpi] LoadData
 @param #string version		LHpi.Data version to be loaded
 @return #table Data		LHpi.Data table
 ]]
function LHpi.LoadData( version )
	local Data=nil
	ma.SetProgress( "Loading LHpi.Data", 0 )
	do -- load LHpi predefined set data from external file
		local dataname = "Prices\\lib\\LHpi.Data-v" .. version .. ".lua"
		local olddataname = "Prices\\LHpi.Data-v" .. version .. ".lua"
		local LHpiData = ma.GetFile( dataname )
		local oldLHpiData = ma.GetFile ( olddataname )
		if oldLHpiData then
			if DEBUG then
				error("LHpi.Data found in deprecated location. Please move it to Prices\\lib subdirectory!")
			end
			LHpi.Log("LHpi.Data found in deprecated location.")
			if not LHpidata then
				LHpi.Log( "Using file in old location as fallback.")
				LHpidata = oldLHpiData
			end
		end
		if not LHpiData then
			error( "LHpi.Data " .. dataname .. " not found." )
		else -- execute LHpiData to make LHpi.Data.sets.* available
			LHpiData = string.gsub( LHpiData , "^\239\187\191" , "" ) -- remove unicode BOM (0xEF, 0xBB, 0xBF) for files tainted by it :)
			if VERBOSE then
				LHpi.Log( "LHpi.Data " .. dataname .. " loaded and ready for execution." )
			end
			local execdata,errormsg = load( LHpiData , "=(load) LHpi.Data" )
			if not execdata then
				error( errormsg )
			end
			Data = execdata()
		end	-- if not LHpidata else
	end -- do load LHpi data
	collectgarbage() -- we now have LHpi.Data.sets table, let's clear LHpiData and execdata() from memory
	LHpi.Log( "LHpi.Data is ready to use." )
	return Data
end--function LHpi.LoadData

--[[- read MA suplied parameters and configure script instance.
 strips unsupported langs from ma supplied global parameters
 and modifies global site.sets to exclude unwanted langs, frucs and sets

 @function [parent=#LHpi] ProcessUserParams
 @param #string importfoil	"Y"|"N"|"O"
 @param #table importlangs	{ #number = #string }
 @param #table importsets	{ #number = #string }
 @returns #string lowerfoil, #table langlist, #table setlist and global #table site.sets is modified
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
		LHpi.Log( "Importing Sets: " .. LHpi.Tostring( setlist ) )
	else -- setlist is empty
	--[[local supsetlist = ""
		for lid,lang in pairs(site.sets) do
			if lang then
				supsetlist = supsetlist .. " " .. set.url
			end
		end
	--]]
		LHpi.Log( "No supported set selected; returning from script now." )
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
		LHpi.Log( "Importing Languages: " .. LHpi.Tostring( langlist ) )
	else -- langlist is empty
		local suplanglist = ""
		for lid,lang in pairs(site.langs) do
			if lang then
				suplanglist = suplanglist .. " " .. lang.full
			end
		end
		LHpi.Log( "No supported language selected; returning from script now." )
		error ( "No supported language selected, please select at least one of: " .. suplanglist .. "." )
	end
	
	-- identify user defined types of foiling to import
	--TODO don't assume fruc[1] is foil and all other frucs are nonfoil or at least document the asumption properly
	local lowerfoil = string.lower( importfoil )
	if lowerfoil == "n" then
		LHpi.Log("Importing Non-Foil Only Card Prices")
		for sid,cSet in pairs(site.sets) do  -- disable all foil frucs
			site.sets[sid].fruc[1] = false
		end --for sid
	elseif lowerfoil == "o" then
		LHpi.Log("Importing Foil Only Card Prices")
		for f = 2,LHpi.Length(site.frucs) do -- disable all non-foil frucs
			for sid,cSet in pairs(site.sets) do
				site.sets[sid].fruc[f] = false
			end --for sid
		end -- for i
	else --  lowerfoil == "y" then
		LHpi.Log("Importing Non-Foil and Foil Card Prices")
	end -- if importfoil
	
	if not VERBOSE then
		LHpi.Log("If you want to see more detailed logging, edit Prices\\" .. scriptname .. " and set VERBOSE = true.", 0)
	end
	return lowerfoil, langlist, setlist
end -- function LHpi.ProcessUserParams

--[[- build a list of sources (urls/files) we need.
 The urls will have to be concatenated eventually ayways, but doing it now
 (instead of concatenating the url just before we fetch the source data)
 allows a more detailed progress bar, though at the cost of an additional loop through site.sets
  
 @function [parent=#LHpi] ListSources
 @param #string importfoil	"Y"|"N"|"O"
 @param #table importlangs	{ #number = #string }
 @param #table importsets	{ #number = #string }
 @return #table, #number  	{ #number = #table { #string = #table { foilonly = #boolean } } }  and its length (for progressbar)
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
								if DEBUG then
									urldetails.lang=site.langs[lid].url
									urldetails.fruc=site.frucs[fid]
									LHpi.Log( "site.BuildUrl is " .. LHpi.Tostring( url ) , 2 )
								end
								if importfoil == "n" and url.foilonly then
									if DEBUG then
										LHpi.Log( "unwanted foilonly url dropped" , 2 )
									end
								else -- add url to list
									urls[sid][url] = urldetails
								end
							end -- for
						elseif DEBUG then
--							LHpi.Log( "url for fruc " .. fruc .. " (" .. fid .. ") not available" , 2 )
							LHpi.Log( string.format( "url for fruc %s (%i) not available", fruc, fid ), 2 )
						end -- of cSet.fruc[fid]
					end -- for fid,fruc
				elseif DEBUG then
					LHpi.Log( string.format( "url for lang %s (%i) not available", lang, lid ), 2 )
				end	-- if cSet.lang[lid]
			end -- for lid,_lang
			-- Calculate total number of sources for progress bar
			urlcount = urlcount + LHpi.Length(urls[sid])
--			if DEBUG then
--				LHpi.Logtable(urls[sid])
--			end
		elseif DEBUG then
			LHpi.Log( string.format( "url for %s (%i) not available", importsets[sid], sid ), 2 )
		end -- if importsets[sid]
	end -- for sid,cSet
	if DEBUG then
		LHpi.Logtable(urls)
	end
	return urls, urlcount
end -- function LHpi.ListSources

--[[- construct url/filename and build sourceTable.
 fetch a page/file and return a table with all entries found therein
 Calls site.ParseHtmlData from sitescript.

 @function [parent=#LHpi] GetSourceData
 @param #string url		source location (url or filename)
 @param #table details	{ foilonly = #boolean , isfile = #boolean , setid = #number, langid = #number, frucid = #number }
 @return #table { #table names, #table price }
]]
function LHpi.GetSourceData( url , details ) -- 
	local htmldata = nil -- declare here for right scope
	if details.isfile then -- get htmldata from local source
		LHpi.Log( "Loading " .. url )
		url = string.gsub(url, "/", "_")
		url = string.gsub(url, "%?", "_")
		htmldata = ma.GetFile( savepath .. url )
		if not htmldata then
			LHpi.Log( "!! GetFile failed for " .. savepath .. url )
			return nil
		end
	else -- get htmldata from online source
		LHpi.Log( "Fetching http://" .. url )
		htmldata = ma.GetUrl( "http://" .. url )
		if DEBUG then LHpi.Log("fetched remote file.") end
		if not htmldata then
			LHpi.Log( "!! GetUrl failed for " .. url )
			return nil
		end
	end -- if details.isfile
	
	if SAVEHTML and not OFFLINE then
--		local filename = next( site.BuildUrl( details.setid , details.langid , details.frucid , true ) )
		url = string.gsub(url, "/", "_")
		url = string.gsub(url, "%?", "_")
		LHpi.Log( "Saving source html to file: \"" .. savepath .. url .. "\"" )
		ma.PutFile( savepath .. url , htmldata )
	end -- if SAVEHTML
	
	if VERBOSE then
		LHpi.readexpectedfromhtml (htmldata, site.resultregex )
	end
	
	local sourceTable = {}
	for foundstring in string.gmatch( htmldata , site.regex) do
		if DEBUG and not DEBUGSKIPFOUND then
			LHpi.Log( "FOUND : " .. foundstring )
		end
		local foundData = site.ParseHtmlData(foundstring , details )
		-- divide price by 100 again (see site.ParseHtmlData in sitescript for reason)
		-- do some initial input sanitizing: "_" to " "; remove spaces from start and end of string
		for lid,_cName in pairs( foundData.names ) do
			if details.setid == 600 then
				foundData.names[lid] = string.gsub( foundData.names[lid], "^_+$" , "Unhinged Shapeshifter" )
			end
			foundData.price[lid] = ( foundData.price[lid] or 0 ) / 100
			foundData.names[lid] = LHpi.Toutf8( foundData.names[lid] )
			foundData.names[lid] = string.gsub( foundData.names[lid], "_", " " )
			foundData.names[lid] = string.gsub( foundData.names[lid], "^%s*(.-)%s*$", "%1" )
		end -- for lid,_cName
		if next( foundData.names ) then
--			table.insert( sourceTable , { names = foundData.names, price = foundData.price , pluginData = foundData.pluginData } )
			table.insert( sourceTable , foundData ) -- actually keep ParseHtmlData-supplied information
		else -- nothing was found
			if VERBOSE or DEBUG then
				LHpi.Log( "foundstring contained no data" , 1 )
			end
			if DEBUG then
				LHpi.Log( "FOUND : '" .. foundstring .. "'" , 2 )
				LHpi.Log( "foundData :" .. LHpi.Tostring(foundData) , 2 )
				--error( "foundstring contained no data" )
			end
		end
	end -- for foundstring
	htmldata = nil 	-- potentially large htmldata now ready for garbage collector
	collectgarbage()
	if DEBUG then
		LHpi.Logtable( sourceTable , "sourceTable" , 2 )
	end
	if table.maxn( sourceTable ) == 0 then
		return nil
	end
	return sourceTable
end -- function LHpi.GetSourceData


--[[- construct card data.
 constructs card data for one card entry found in htmldata
 uses site.BCDpluginName and site.BCDpluginCard
 fields already existing in sourceTable will be kept, so 
 site.ParseHtmlData could preset more fields if neccessary.
 additional data can be passed from site.ParseHtmlData to 
 site.BCDpluginName and/or site.BCDpluginCard via pluginData field.
 
 @function [parent=#LHpi] BuildCardData
 @param #table sourcerow	from sourceTable, as parsed from htmldata 
 @param #number setid	(see "Database\Sets.txt")
 @param #boolean urlfoil	optional: true if processing row from a foil-only url
 @param #table importfoil	passed from ImportPrice to drop unwanted cards
 @param #table importlangs	passed from ImportPrice to drop unwanted cards
 @return #table { 	name		: unique card name used as index in cardsetTable (localized name with lowest langid)
 					lang{}		: card languages
 					names{}		: card names by language (not used, might be removed)
					drop		: true if data was marked as to-be-dropped and further processing was skipped
					variant		: table of variant names, nil if single-versioned card
					regprice{}	: nonfoil prices by language, subtables if variant
					foilprice{}	: foil prices by language, subtables if variant
				}
 ]]
function LHpi.BuildCardData( sourcerow , setid , urlfoil , importfoil, importlangs )
	local card = { names = {} , lang = {} }
 
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
		for lid,_ in pairs( importlangs ) do
			if sourcerow.names[lid]~=nil and (sourcerow.names[lid] ~= "") then
				card.names[lid] = sourcerow.names[lid]
				card.lang[lid] = site.langs[lid].abbr
			end
		end -- for lid,_
	end -- if sourcerow.lang

	if not card.name then-- should not be reached, but caught here to prevent errors in string.gsub/find below
		card.drop = true
		card.name = "DROPPED nil-name"
		return card
	end --if not card.name

	if sourcerow.drop then -- keep site.ParseHtmlData preset drop
		card.drop = sourcerow.drop
		return card
	end -- if

	--[[ do site-specific card data manipulation before processing 
	]]
	if site.BCDpluginPre then
		card = site.BCDpluginPre ( card , setid )
	end
	
	-- drop unwanted sourcedata before further processing
	if string.find( card.name , "%(DROP[ %a]*%)" ) then
		card.drop = true
		if DEBUG then
			LHpi.Log ( "LHpi.buildCardData\t dropped card " .. LHpi.Tostring(card) , 2 )
		end
		return card
	end -- if entry to be dropped
	
	card.name = string.gsub( card.name , " // " , "|" )
	card.name = string.gsub( card.name , " / " , "|" )
	card.name = string.gsub (card.name , "([%aäÄöÖüÜ]+)/([%aäÄöÖüÜ]+)" , "%1|%2" )
	card.name = string.gsub( card.name , "´" , "'" )
	card.name = string.gsub( card.name , '"' , "“" )
	card.name = string.gsub( card.name , "^Unhinged Shapeshifter$" , "_____" )
	
	-- unify collector number suffix. must come before variant checking
	card.name = string.gsub( card.name , "%(Nr%. -(%d+)%)" , "(%1)" )
	card.name = string.gsub( card.name , " *(%(%d+%))" , " %1" )
	card.name = string.gsub( card.name , " Nr%. -(%d+)" , " (%1)" )
	card.name = string.gsub( card.name , " # ?(%d+)" , " (%1)" )
	card.name = string.gsub( card.name , "%[[vV]ersion (%d)%]" , "(%1)" )
	card.name = string.gsub( card.name , "%((%d+)/%d+%)" , "(%1)" )

	if sourcerow.foil~=nil then -- keep site.ParseHtmlData preset foil
		card.foil = sourcerow.foil
	else
		if urlfoil then
			card.foil = true -- believe urldata
		elseif string.find ( card.name, "[%(-].- ?[fF][oO][iI][lL] ?.-%)?" ) then
			card.foil = true -- check cardname
		elseif LHpi.Data.sets[setid].foilonly then
			card.foil = true
		else
			card.foil = false
		end -- if urlfoil
	end -- if sourcerow.foil
	card.name = string.gsub( card.name , "([%(-].-) ?[fF][oO][iI][lL] ?(.-%)?)" , "%1%2" )
	card.name = string.gsub( card.name , "%( -%)" , "" ) -- remove empty brackets
	card.name = string.gsub(card.name , "-$" , "" ) -- remove dash from end of string
	-- removal of foil suffix  must come before variant and namereplace check
	
	card.name = string.gsub( card.name , "%s+" , " " ) -- reduce multiple spaces
	card.name = string.gsub( card.name , "^%s*(.-)%s*$" , "%1" ) --remove spaces from start and end of string

	if DEBUG then
		LHpi.Log(card.name .. ":" .. LHpi.ByteRep(card.name) , 2 )
	end

	if site.namereplace[setid] and site.namereplace[setid][card.name] then
		if LOGNAMEREPLACE or DEBUG then
			LHpi.Log( string.format( "namereplaced %s to %s" ,card.name, site.namereplace[setid][card.name] ), 1 )
		end
		card.name = site.namereplace[setid][card.name]
		if CHECKEXPECTED then
			persetcount.namereplaced = persetcount.namereplaced + 1
		end
	end -- site.namereplace[setid]

	-- foiltweak, should probably be after namereplace and before variants
	if site.foiltweak[setid] and site.foiltweak[setid][card.name] then
		if LOGFOILTWEAK or DEBUG then
			LHpi.Log( string.format( "foiltweaked %s from %s to %s" ,card.name, tostring(card.foil), tostring(site.foiltweak[setid][card.name].foil) ), 1 )
--			LHpi.Log( "FOILTWEAKed " ..  name ..  " to "  .. card.foil , 2 )
		end
		card.foil = site.foiltweak[setid][card.name].foil
		if CHECKEXPECTED then 
			persetcount.foiltweaked = persetcount.foiltweaked + 1
		end
	end -- if site.foiltweak

	-- drop for foil reasons must happen after foiltweak
	if importfoil == "n" and card.foil then
		card.drop = true
		return card
	elseif importfoil == o and (not card.foil) then
		card.drop = true
		return card		
	end-- if importfoil == "y" no reason for drop here

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
	if sourcerow.variant then -- keep site.ParseHtmlData preset variant
		card.variant = sourcerow.variant
	else
	-- check site.variants[setid] table for variant
		card.variant = nil
		if site.variants[setid] and site.variants[setid][card.name] then  -- Check for and set variant (and new card.name)
			if DEBUGVARIANTS then DEBUG = true end
			card.variant = site.variants[setid][card.name][2]
			if DEBUG then
				LHpi.Log( "VARIANTS\tcardname \"" .. card.name .. "\" changed to name \"" .. site.variants[setid][card.name][1] .. "\" with variant \"" .. LHpi.Tostring( card.variant ) .. "\"" , 2 )
			end
			card.name = site.variants[setid][card.name][1]
		end -- if site.variants[setid]
	end -- if sourcerow.variant
	-- remove unparsed leftover variant numbers
	card.name = string.gsub( card.name , "%(%d+%)" , "" )
	
	-- Token infix removal, must come after variant checking
	-- This means that we sometimes have to namereplace the suffix away for variant tokens
	if string.find(card.name , "[tT][oO][kK][eE][nN]" ) then -- Token pre-/suffix and color suffix
		card.name = string.gsub( card.name , "[tT][oO][kK][eE][nN]" , "" )
		card.name = string.gsub( card.name , "%((.*)White(.*)%)" , "(%1W%2)" )
		card.name = string.gsub( card.name , "%((.*)Blue(.*)%)" , "(%1U%2)" )
		card.name = string.gsub( card.name , "%((.*)Black(.*)%)" , "(%1B%2)" )
		card.name = string.gsub( card.name , "%((.*)Red(.*)%)" , "(%1R%2)" )
		card.name = string.gsub( card.name , "%((.*)Green(.*)%)" , "(%1G%2)" )
		card.name = string.gsub( card.name , "^ %- " , "" )
		card.name = string.gsub( card.name , "%([WUBRGCHTAM][/|]?[WUBRG]?%)" , "" )
		card.name = string.gsub( card.name , "%(Art%)" , "" )
		card.name = string.gsub( card.name , "%(Go?ld%)" , "" )
		--card.name = string.gsub( card.name , "%(Gold%)" , "" )
		card.name = string.gsub( card.name , "%(Multicolor%)" , "" )
		card.name = string.gsub( card.name , "%(Spt%)" , "" )
		card.name = string.gsub( card.name , "%(%)%s*$" , "" )
		card.name = string.gsub( card.name , "  +" , " " )
	end
	if string.find( card.name , "^Emblem" ) then -- Emblem prefix to suffix
		if card.name == "Emblem of the Warmind" 
		or card.name == "Emblem des Kriegerhirns" then
			-- do nothing
		else
			card.name = string.gsub( card.name , "Emblem[-: ]+([^\"]+)" , "%1 Emblem" )
			card.name = string.gsub( card.name , "  +" , " " )
		end
	end

	card.name = string.gsub( card.name , "^%s*(.-)%s*$" , "%1" ) --remove any leftover spaces from start and end of string
		
	--card.condition[lid] = "NONE"
	
	card.regprice={}
	card.foilprice={}
	--TODO I would prefer to skip as much loops as possible if we're to discard the results anyway...
--	if sourcerow.regprice~=nil then -- keep site.ParseHtmlData preset regprice
--		card.regprice = sourcerow.regprice
--	elseif sourcerow.foilprice~=nil then -- keep site.ParseHtmlData preset foilprice
--		card.foilprice = sourcerow.foilprice
--	else -- define price according to card.foil and card.variant	
		for lid,lang in pairs( card.lang ) do
			if card.variant then
				if DEBUG then
					LHpi.Log( "VARIANTS pricing " .. lang .. " : " .. LHpi.Tostring(card.variant) , 2 )
				end
				if card.foil then
					if not card.foilprice[lid] then card.foilprice[lid] = {} end
				else -- nonfoil
					if not card.regprice[lid] then card.regprice[lid] = {} end
				end
				for varnr,varname in pairs(card.variant) do
					if DEBUG then
						LHpi.Log( "VARIANTS\tvarnr is " .. varnr .. " varname is " .. tostring(varname) , 2 )
					end
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
		end -- for lid,_lang
--	end--if sourcerow reg/foilprice
	if sourcerow.regprice~=nil then -- keep site.ParseHtmlData preset regprice instead
		card.regprice = sourcerow.regprice
	end
	if sourcerow.foilprice~=nil then -- keep site.ParseHtmlData preset foilprice instead
		card.foilprice = sourcerow.foilprice
	end
	
	--[[ do final site-specific card data manipulation
	]]
	if site.BCDpluginPost then
		card = site.BCDpluginPost ( card , setid )
	end
	
	card.foil = nil -- remove foilstat; info is retained in [foil|reg]price and it could cause confusion later
	card.BCDpluginData = nil -- if present at all, should have been used and deleted by site.BCDpluginPre|Post 	
	if DEBUG then
		LHpi.Log( "LHpi.buildCardData\t will return card " .. LHpi.Tostring(card) , 2 )
	end -- DEBUG
	return card
end -- function LHpi.BuildCardData

--[[- add card to cardsetTable.
 do duplicate checking and add card to global #table cardsetTable.
 cardsetTable will hold all prices to be imported, one row per card.
 moved to seperate function to allow early return.
 calls LHpi.MergeCardrows
 
 @function [parent=#LHpi] FillCardsetTable
 @param #table card		single tablerow from BuildCardData
 @return #number		0 if ok, 1 if conflict
 @return modifies global #table cardsetTable
]]
function LHpi.FillCardsetTable( card )
	if DEBUG then
		LHpi.Log("FillCardsetTable\t with " .. LHpi.Tostring( card ) , 2 )
	end
	local newCardrow = { variant = card.variant , regprice = card.regprice , foilprice = card.foilprice , lang=card.lang }
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
				if DEBUG then
					LHpi.Log ( " varnr " .. varnr , 2 )
				end
				if newCardrow.variant[varnr] == oldCardrow.variant[varnr]
				or newCardrow.variant[varnr] and not oldCardrow.variant[varnr]
				or oldCardrow.variant[varnr] and not newCardrow.variant[varnr]
				then
					mergedvariant[varnr] = oldCardrow.variant[varnr] or newCardrow.variant[varnr]
					if DEBUG then
						LHpi.Log( "variant[" .. varnr .. "] equal or only one set" , 2 )
					end
				else
					-- this should never happen 
					if VERBOSE then
						LHpi.Log( "!!! " .. card.name .. ": FillCardsetTable\t conflict while unifying varnames" , 2 )
					end
					if DEBUG then 
						error( "FillCardsetTable conflict: variant[" .. varnr .. "] not equal. " )
					end
					return 1,"variant" .. varnr .. "name differs!"
				end -- if
			end -- for varnr
		elseif (oldCardrow.variant and (not newCardrow.variant)) or ((not oldCardrow.variant) and newCardrow.variant) then
			-- this is severe and should never happen
			if VERBOSE then
				LHpi.Log ("!!! " .. card.name .. ": FillCardsetTable\t conflict variant vs not variant" ,2)
			end
			if DEBUG then 
				error( "FillCardsetTable conflict: " .. LHpi.Tostring(oldCardrow.variant) .. " vs " .. LHpi.Tostring(newCardrow.variant) .. " !" )
			end
			return 1,"variant state differs"
		end -- if oldCardrow.variant and newCardrow.variant
				
		-- variant table equal (or equally nil) in old and new, now merge data
		local mergedCardrow,conflict = LHpi.MergeCardrows (card.name, mergedlang, oldCardrow, newCardrow, mergedvariant)
		if DEBUG then
			if (conflict.reg and string.find( conflict.reg , "!!")) or (conflict.foil and string.find( conflict.foil , "!!")) then
				LHpi.Log(LHpi.Tostring(conflict) .. " while merging " .. card.name )
			end -- if
		end
		if DEBUG then
			LHpi.Log("to cardsetTable(mrg) " .. card.name .. "\t\t: " .. LHpi.Tostring(mergedCardrow) , 2 )
		end
		cardsetTable[card.name] = mergedCardrow
		return 0,"ok:merged rows",mergedCardrow
		
	else -- no oldCardrow, no conflict checking necessary
		local mergedCardrow = "not needed"
		if DEBUG then
			LHpi.Log("to cardsetTable(new) " .. card.name .. "\t\t: " .. LHpi.Tostring(newCardrow) , 2 )
		end
		cardsetTable[card.name] = newCardrow
		return 0,"ok:new row",newCardrow
	end
	error( "FillCardsetTable did not return." )
end -- function LHpi.FillCardsetTable()

--[[- check conflicts while merging rows.
 used repeatedly in LHpi.FillCardsetTable.
 
 @function [parent=#LHpi] MergeCardrows
 @param #string name	only needed for more meaningfull log
 @param #table langs { #number = #string }
 @param #table oldRow
 @param #table newRow
 @param #table variants (optional) { #number = #string }
 @return #table mergedRow, #table conflict { reg = #string, foil = #string }
]]
function LHpi.MergeCardrows ( name, langs,  oldRow , newRow , variants )
--TODO (((a+b)/2)+c)/2 != (a+b+c)/3 = (((a+b)/2*2)+c)/3 is 
--for mathematically correct averaging, need to attach a counter to averaged prices
--then on next averaging, do 
--if counter then newaverage=(oldaverage*(counter+1) + newprice) / (counter+2)
	local mergedRow = { regprice = {} , foilprice = {} }
	local conflict = {reg = nil , foil = nil }
	if variants then
		for varnr,varname in pairs(variants) do
			local oldvar = { regprice = {}, foilprice = {} }
			local newvar = { regprice = {}, foilprice = {} }
			for lid,_lang in pairs(langs) do
				if not oldRow.regprice[lid] then oldRow.regprice[lid] = {} end
				if not newRow.regprice[lid] then newRow.regprice[lid] = {} end
				if not oldRow.foilprice[lid] then oldRow.foilprice[lid] = {} end
				if not newRow.foilprice[lid] then newRow.foilprice[lid] = {} end
				oldvar.regprice[lid] = oldRow.regprice[lid][varname]
				newvar.regprice[lid] = newRow.regprice[lid][varname]
				oldvar.foilprice[lid] = oldRow.foilprice[lid][varname]
				newvar.foilprice[lid] = newRow.foilprice[lid][varname]
			end --for lid,_lang
			local mergedvarRow, varconflict = LHpi.MergeCardrows ( name .. "[" .. varnr .. "]" , langs , oldvar, newvar, nil)
			for lid,_lang in pairs(langs) do
				if not mergedRow.regprice[lid] then mergedRow.regprice[lid] = {} end		
				mergedRow.regprice[lid][varname] = mergedvarRow.regprice[lid]
				if not mergedRow.foilprice[lid] then mergedRow.foilprice[lid] = {} end	
				mergedRow.foilprice[lid][varname] = mergedvarRow.foilprice[lid]
			end -- for lid,_langs
			conflict.reg = ( conflict.reg or "" ) .. "[" .. varnr .. "]" ..  varconflict.reg
			conflict.foil = ( conflict.foil or "" ) .. "[" .. varnr .. "]" ..  varconflict.foil
		end -- for varnr,varname 
	else -- no variant
		for lid,_lang in pairs(langs) do
			if 		newRow.regprice[lid] == oldRow.regprice[lid]
			or	newRow.regprice[lid] and not oldRow.regprice[lid]
			or	oldRow.regprice[lid] and not newRow.regprice[lid]
			then
				mergedRow.regprice[lid] = oldRow.regprice[lid] or newRow.regprice[lid]
				conflict.reg = "ok:keep equal"
			elseif newRow.regprice[lid] == 0 then
				mergedRow.regprice[lid] = oldRow.regprice[lid]
				conflict.reg = "ok:zero/notzero"
			elseif oldRow.regprice[lid] == 0 then
				mergedRow.regprice[lid] = newRow.regprice[lid]
				conflict.reg = "ok:notzero/zero"
			else -- newCardrow.regprice ~= oldCardrow.regprice
				conflict.reg = "!!:regprice[" .. lid .. "]"
				mergedRow.regprice[lid] = (oldRow.regprice[lid] + newRow.regprice[lid]) * 0.5
--TODO				mergedRow.mergecounter++				
				if VERBOSE then
					LHpi.Log("averaging conflicting " .. name .. " regprice[" .. site.langs[lid].abbr .. "] " .. oldRow.regprice[lid] .. " and " .. newRow.regprice[lid] .. " to " .. mergedRow.regprice[lid] , 1 )
				end
				if DEBUG then
					LHpi.Log("!! conflicting regprice in lang [" .. site.langs[lid].abbr .. "]" , 1 )
					LHpi.Log("oldRow: " .. LHpi.Tostring(oldRow))
					LHpi.Log("newRow: " .. LHpi.Tostring(newRow))
					print("conflict " .. conflict.reg)
					--error("conflict " .. conflict.reg)
				end
			end -- if newRow.regprice[lid] == oldRow.regprice[lid]
			if 		newRow.foilprice[lid] == oldRow.foilprice[lid]
			or	newRow.foilprice[lid] and not oldRow.foilprice[lid]
			or	oldRow.foilprice[lid] and not newRow.foilprice[lid]
			then
				mergedRow.foilprice[lid] = oldRow.foilprice[lid] or newRow.foilprice[lid]
				conflict.foil = "ok:keep equal"
			elseif newRow.foilprice[lid] == 0 then
				mergedRow.foilprice[lid] = oldRow.foilprice[lid]
				conflict.foil = "ok:zero/notzero"
			elseif oldRow.foilprice[lid] == 0 then
				mergedRow.foilprice[lid] = newRow.foilprice[lid]
				conflict.foil = "ok:notzero/zero"
			else -- newCardrow.foilprice ~= oldCardrow.foilprice
				conflict.foil = "!!:foilprice[" .. lid .. "]"
				mergedRow.foilprice[lid] = (oldRow.foilprice[lid] + newRow.foilprice[lid]) * 0.5
				if VERBOSE then
					LHpi.Log("  averaging conflicting " .. name .. " foilprice[" .. site.langs[lid].abbr .. "] " .. oldRow.foilprice[lid] .. " and " .. newRow.foilprice[lid] .. " to " .. mergedRow.foilprice[lid] , 1 )
				end
				if DEBUG then
					LHpi.Log("!! conflicting foilprice in lang [" .. site.langs[lid].abbr .. "]" , 1 )
					LHpi.Log("oldRow: " .. LHpi.Tostring(oldRow))
					LHpi.Log("newRow: " .. LHpi.Tostring(newRow))
					print("conflict " .. conflict.foil)
					--error("conflict " .. conflict.foil)
				end
			end -- if newRow.foilprice[lid] == oldRow.foilprice[lid]
		end -- for lid,lang
	end -- if variants
	mergedRow.lang = langs
	mergedRow.variant = variants
	return mergedRow,conflict
end -- function LHpi.MergeCardrows

--[[- calls MA to set card price.
 
 @function [parent=#LHpi] SetPrice
 @param	#number setid	(see "Database\Sets.txt")
 @param #string name	card name Ma will try to match to Oracle Name, then localized Name
 @param #table  card	card data from cardsetTable
 @return #number MA.SetPrice retval (summed over card.lang and card.variant loops) (not read)
]]
function LHpi.SetPrice(setid, name, card)
	local retval
	if card.variant and DEBUGVARIANTS then DEBUG = true end
	if DEBUG then
		LHpi.Log( "LHpi.SetPrice\t setid is " .. setid ..  " name is " .. name .. " card is " .. LHpi.Tostring(card) ,2)
	end
	
	for lid,lang in pairs(card.lang) do
	local perlangretval
		if card.variant then
			if DEBUG then
				LHpi.Log( "variant is " .. LHpi.Tostring(card.variant) .. " regprice is " .. LHpi.Tostring(card.regprice[lid]) .. " foilprice is " .. LHpi.Tostring(card.foilprice[lid]) ,2)
			end
			if not card.regprice[lid] then card.regprice[lid] = {} end
			if not card.foilprice[lid] then card.foilprice[lid] = {} end
			for varnr, varname in pairs(card.variant) do
				if DEBUG then
					LHpi.Log("varnr is " .. varnr .. " varname is " .. tostring(varname) ,2)
				end
				if varname then
					perlangretval = (perlangretval or 0) + ma.SetPrice(setid, lid, name, varname, card.regprice[lid][varname] or 0, card.foilprice[lid][varname] or 0 )
				end -- if varname
			end -- for varnr,varname
			
		else -- no variant
			perlangretval = ma.SetPrice(setid, lid, name, "", card.regprice[lid] or 0, card.foilprice[lid] or 0)
		end -- if card.variant
		
		-- count ma.SetPrice retval and log potential problems
		if perlangretval == 0 or (not perlangretval) then
			persetcount.failed[lid] = ( persetcount.failed[lid] or 0 ) + 1
			if DEBUG then
				LHpi.Log( "! LHpi.SetPrice \"" .. name .. "\" for language " ..lang .. " with n/f price " .. LHpi.Tostring(card.regprice[lid]) .. "/" .. LHpi.Tostring(card.foilprice[lid]) .. " not ( " .. tostring(perlangretval) .. " times) set" ,2)
			end
		else
			persetcount.pset[lid] = ( persetcount.pset[lid] or 0 )+ perlangretval
			if DEBUG then
				LHpi.Log( "LHpi.SetPrice\t name \"" .. name .. "\" version \"" .. LHpi.Tostring(card.variant) .. "\" set to " .. LHpi.Tostring(card.regprice[lid]) .. "/" .. LHpi.Tostring(card.foilprice[lid]).. " non/foil " .. tostring(perlangretval) .. " times for laguage " .. lang ,2)
			end
		end
		if VERBOSE or DEBUG then
			local expected
			if not card.variant then
				expected = 1
			else
				expected = LHpi.Length(card.variant)
			end
			if (perlangretval ~= expected) then
				LHpi.Log( "! LHpi.SetPrice \"" .. name .. "\" for language " .. lang .. " returned unexpected retval \"" .. tostring(perlangretval) .. "\"; expected was " .. expected , 1 )
			elseif DEBUG then
				LHpi.Log( "LHpi.SetPrice \"" .. name .. "\" for language " .. lang .. " returned expected retval \"" .. tostring(perlangretval) .. "\"" ,2)
			end
		end
		retval = (retval or 0) + perlangretval
	end -- for lid,lang

	if DEBUGVARIANTS then DEBUG = false end
	return retval -- not used
	
end -- function LHpi.SetPrice(setid, name, card)

--[[- save table as csv.
file encoding is utf-8 without BOM
@function [parent=#LHpi] SaveCSV( setid , tbl , path )
@param #number setid
@param #table tbl
@param #string path
@return nil
]]
function LHpi.SaveCSV( setid , tbl , path )
	local setname=LHpi.Data.sets[setid].name
	local filename = path .. setid .. "-" .. setname .. ".csv"
	LHpi.Log( "Saving table to file: \"" .. filename .. "\"" )
	ma.PutFile( filename, "cardname\tcardprice\tsetname\tcardlanguage\tcardversion\tfoil|nonfoil\tcardnotes" , 0 )
	for name,card in pairs(cardsetTable) do
		for lid,lang in pairs(card.lang) do
			lang=site.langs[lid].full
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

--[[may be usefull to manually check expected count]]
function LHpi.readexpectedfromhtml (str, pattern)
	if pattern then
		local _s,_e,results = string.find(str, pattern )
		LHpi.Log( "html source data claims to contain " .. tostring(results) .. " cards." )
	end
end -- LHpi.readexpectedfromhtml

--[[- detect BOMs to get file encoding.
@function [parent=#LHpi] findFileEncoding( str )
@param #string str		html raw data
@return #string "cp1252"|"utf8"|"utf16-le"|"utf16-be"
]]
function LHpi.guessFileEncoding ( str )
	local e = "cp1252"
	if string.find(str , "^\239\187\191") then -- utf-8 BOM (0xEF, 0xBB, 0xBF)
		e = "utf-8"
	elseif string.find(str , "^\255\254") then -- utf-16 little-endian BOM (0xFF 0xFE)
		e = "utf-16-le"
	elseif string.find(str , "^\254\255") then -- utf-16 big-endian BOM (0xFE 0xFF)
		e = "utf-16-be"
	end
	return e	
end -- LHpi.guessFileEncoding

--[[- get single-byte representation.
can be used to find the right character replacements

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
@param #string str
@return #string with utf8 encoded non-ascii characters
]]
function LHpi.Toutf8( str )
	if "string" == type( str ) then
		if site.encoding == "utf-8" or site.encoding == "utf8" or site.encoding == "unicode" then
			return str -- exit asap
		elseif site.encoding == "cp1252" or site.encoding == "ansi" then
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
		end
		return str
	else
		error( "LHpi.Toutf8 called with non-string." )
	end
end -- function LHpi.Toutf8

--[[- flexible logging.
 loglevels:
  1 for VERBOSE,  2 for DEBUG, else log.
 add other levels as needed

 @function [parent=#LHpi] Log
 @param #string str		log text
 @param #number l		(optional) loglevel, default is normal logging
 @param #string f		(optional) logfile, default is scriptname.log
 @param #number a		(optional) 0 to overwrite, default is append
 @returns nil
]]
function LHpi.Log( str , l , f , a )
	local loglevel = l or 0
	local apnd = a or 1
	local logfile = "Prices\\LHpi.Log" -- fallback if global # string scriptname is missing
	if scriptname then
		logfile = "Prices\\" .. string.gsub( scriptname , "lua$" , "log" )
	end
	if f then
		logfile = f
	end
	if loglevel == 1 then
		str = " " .. str
	elseif loglevel == 2 then
		str = "DEBUG\t" .. str
		--logfile = string.gsub(logfile, "log$", "DEBUG.log") -- for seperate debuglog
	end
	if SAVELOG~=false then
--		if not apnd == 0 then
			str = "\n" .. str
--		end
		ma.PutFile( logfile , str , apnd )
	else
		ma.Log( str )
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
 @return nil
]]
function LHpi.Logtable( tbl , str , l )
	local name = str or tostring( tbl )
	local llvl = 0 or l
	local c=0
	if type( tbl ) == "table" then
		LHpi.Log( "BIGTABLE " .. name .." has " .. LHpi.Length( tbl ) .. " rows:" , llvl )
		for k,v in pairs (tbl) do
			LHpi.Log( "\tkey '" .. k .. "' \t value '" .. LHpi.Tostring( v ) .. "'", llvl )
			c = c + 1
		end
		if DEBUG then
			LHpi.Log( "BIGTABLE " .. name .. " sent to log in " .. c .. " rows" , llvl )
		end
	else
		error( "BIGTABLE called for non-table" )
	end
end -- function LHpi.Logtable

--LHpi.Log( "\239\187\191LHpi library loaded and executed successfully" , 0 , nil , 0 ) -- add unicode BOM to beginning of logfile
LHpi.Log( "LHpi library loaded and executed successfully." , 0 , nil , 0 )
return LHpi