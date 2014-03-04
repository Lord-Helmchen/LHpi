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
!only magicuniverse uses multiple frucs. maybe it's time to revert back to foil=Y|N|O 
 and move common|uncommon|rare url building into the sitescript

patch to accept entries with a condition description if no other entry with better condition is in the table:
	buildCardData will need to add condition to carddata
	global conditions{} to define priorities
	then fillCardsetTable needs a new check before overwriting existing data
	check conflict handling with Onulet from 140

string.format all LOG that contain variables
	http://www.troubleshooters.com/codecorn/lua/luastring.htm#_String_Formatting

add all special and promo sets (cardcount,variants,foiltweak) to LHpi.sets

no longer silently assume that fruc is {foil,rare,uncommon,common}
that means ProcessUserParams should not use importfoil,importlangs to nil parts of
 site.sets[setid].fruc and site.sets[setid].langs   
instead, apply [url].foilonly and [url].lang
 then use importfoil,importlangs to 
 a) have ListSources drop unwanted urls to minmize network load
 b) have BuildCardData drop unwanted cards/prices to make sure user wishes are honoured 

to anticipate sites that return "*CARDNAME*REGPRICE*FOILPRICE* instead of "*CARDNAME*PRICE*FOILSTATUS*"
 have site.ParseHtml return a collection of cards, similar to site.BuildUrl
 
seperate library (code) and LHpi.sets (data) into 2 files ?
Would make updates/versioning cleaner by distinguishing between new set info (data) and further generalization,bugfixing (code)
]]

--[[ CHANGES
added BNG and Commander2013
started adding missing special and promo sets
expanded version tables for old expansions
count foiltweak events
]]
--- @field [parent=#LHpi] #string version
LHpi.version = "2.6"

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
	print(savepath)
	print(scriptname)
	if not savepath then
	--- savepath for OFFLINE (read) and SAVEHTML (write). must point to an existing directory relative to MA's root.
	-- @field [parent=#global] #string savepath
		savepath = "Prices\\" .. string.gsub( scriptname , "%-v[%d%.]+%.lua$" , "" ) .. "\\"
	end -- if
	print (savepath)
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
			if LHpi.sets[sid] then
				site.variants[sid] = LHpi.sets[sid].variants
			end -- if
		end -- if
	end -- for
	if not site.foiltweak then site.foiltweak={} end
	for sid,_setname in pairs(supImportsets) do
		if not site.foiltweak[sid] then
			if LHpi.sets[sid] then
				site.foiltweak[sid] = LHpi.sets[sid].foiltweak
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
						if ( LHpi.sets[sid] and LHpi.sets[sid].cardcount ) then
							--if LHpi.sets[sid].cardcount then
							if site.expected.EXPECTTOKENS then
								site.expected[sid].pset[lid] = LHpi.sets[sid].cardcount.reg + LHpi.sets[sid].cardcount.tok 
							else
								site.expected[sid].pset[lid] = LHpi.sets[sid].cardcount.reg
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

	--- @field [parent=#global] #table totalcount
	totalcount = { pset= {}, failed={}, dropped=0, namereplaced=0, foiltweaked=0 }
	for lid,_lang in pairs(supImportlangs) do
		totalcount.pset[lid] = 0
		totalcount.failed[lid] = 0
	end -- for
	--- @field [parent=#global] #table setcountdiffers	list sets where persetcount differs from site.expected[setid]
	setcountdiffers = {}
	--- @field [parent=#global] #number curhtmlnum	count imported sourcefiles for progressbar
	curhtmlnum = 0

	-- loop through importsets to parse html, build cardsetTable and then call ma.setPrice
	LHpi.MainImportCycle(sourceList, sourceCount, supImportfoil, supImportlangs, supImportsets)
	
	-- report final count
	LHpi.Log("Import Cycle finished.")
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
 here the magic occurs.
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
			--- @field [parent=#global] #table cardsetTable		All import data for current set, one row per card
			cardsetTable = {} -- clear cardsetTable
			--- @field [parent=#global] #table persetcount
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
				pmesg = "Importing " ..  importsets[sid]
				if VERBOSE then
					pmesg = pmesg .. " (id " .. sid .. ")"
					LHpi.Log( string.format( "%d percent: %q", progress, pmesg) , 1 )
				end
				ma.SetProgress( pmesg , progress )
				local sourceTable = LHpi.GetSourceData( sourceurl,urldetails )
				-- process found data and fill cardsetTable
				if sourceTable then
					for _,row in pairs(sourceTable) do
						local newcard = LHpi.BuildCardData( row , sid , urldetails.foilonly , importlangs)
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
				if ( LHpi.sets[sid] and LHpi.sets[sid].cardcount ) then
--					msg = msg ..  " Set supposedly contains " .. ( LHpi.sets[sid].cardcount.reg or "#" ) .. " cards and " .. ( LHpi.sets[sid].cardcount.tok or "#" ).. " tokens."
					msg = msg .. string.format( " Set supposedly contains %i cards and %i tokens.", LHpi.sets[sid].cardcount.reg, LHpi.sets[sid].cardcount.tok )
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
			if ( LHpi.sets[sid] and LHpi.sets[sid].cardcount ) then
--				LHpi.Log( "[" .. cSet.id .. "] contains \t" .. ( LHpi.sets[sid].cardcount.both or "#" ) .. " cards (\t" .. ( LHpi.sets[sid].cardcount.reg or "#" ) .. " regular,\t " .. ( LHpi.sets[sid].cardcount.tok or "#" ) .. " tokens )" )
				LHpi.Log( string.format( "[%i] contains %4i cards (%4i regular, %4i tokens )", cSet.id, LHpi.sets[sid].cardcount.both, LHpi.sets[sid].cardcount.reg, LHpi.sets[sid].cardcount.tok ) )
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
	-- importsets = setlist

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
	--importlangs = langlist
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
		LHpi.Log("Importing Non-Foil (+) Foil Card Prices")
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
								urls[sid][url] = urldetails
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
 @param #table importlangs	passed on through parsehtml from ImportPrice (until I change language handling)
 @return #table { 	name		: unique card name used as index in cardsetTable (localized name with lowest langid)
 					lang{}		: card languages
 					names{}		: card names by language (not used, might be removed)
					drop		: true if data was marked as to-be-dropped and further processing was skipped
					variant		: table of variant names, nil if single-versioned card
					regprice{}	: nonfoil prices by language, subtables if variant
					foilprice{}	: foil prices by language, subtables if variant
				}
 ]]
function LHpi.BuildCardData( sourcerow , setid , urlfoil , importlangs )
	local card = { names = {} , lang = {} }
 
	-- set name to identify the card
	if sourcerow.name then -- keep site.ParseHtmlData preset name 
		card.name = sourcerow.name
	else
	-- set lowest langid name as internal name
		for langid = 1,16  do
			if sourcerow.names[langid] then
				card.name = sourcerow.names[langid]
				break
			end -- if
		end -- for lid,name
	end --  if sourcerow.name

	if sourcerow.pluginData then -- keep site.ParseHtmlData additional info
		card.pluginData= sourcerow.pluginData
	end

	-- set card languages
	if sourcerow.lang then -- keep site.ParseHtmlData preset lang 
		card.lang = sourcerow.lang
	else
		-- use names{} to determine card languages	
		for lid,_ in pairs( importlangs ) do
			if sourcerow.names[lid] and (sourcerow.names[lid] ~= "") then
				card.names[lid] = sourcerow.names[lid]
				card.lang[lid] = site.langs[lid].abbr
			end
		end -- for lid,_
	end -- if sourcerow.lang

	if not card.name then-- should not be reached, but caught here to prevent errors in string.gsub/find below
		card.drop = true
		card.name = "DROPPED nil-name"
	end --if not card.name

	if sourcerow.drop then -- keep site.ParseHtmlData preset drop
		card.drop = sourcerow.drop
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

	if sourcerow.foil then -- keep site.ParseHtmlData preset foil
		card.foil = sourcerow.foil
	else
		if urlfoil then
			card.foil = true -- believe urldata
		elseif string.find ( card.name, "[%(-].- ?[fF][oO][iI][lL] ?.-%)?" ) then
			card.foil = true -- check cardname
		elseif LHpi.sets[setid].foilonly then
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
			LHpi.Log( string.format( "foiltweaked %s from %s to %s" ,card.name, tostring(card.foil), site.foiltweak[setid][card.name].foil ), 1 )
--			LHpi.Log( "FOILTWEAKed " ..  name ..  " to "  .. card.foil , 2 )
		end
		card.foil = site.foiltweak[setid][card.name].foil
		if CHECKEXPECTED then 
			persetcount.foiltweaked = persetcount.foiltweaked + 1
		end
	end -- if site.foiltweak

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
--		card.name = string.gsub( card.name , "[tT][oO][kK][eE][nN] %- ([^\"]+)" , "%1" )
--		card.name = string.gsub( card.name , " [tT][oO][kK][eE][nN]" , "" )
		card.name = string.gsub( card.name , "[tT][oO][kK][eE][nN]" , "" )
		card.name = string.gsub( card.name , "%((.*)White(.*)%)" , "(%1W%2)" )
		card.name = string.gsub( card.name , "%((.*)Blue(.*)%)" , "(%1U%2)" )
		card.name = string.gsub( card.name , "%((.*)Black(.*)%)" , "(%1B%2)" )
		card.name = string.gsub( card.name , "%((.*)Red(.*)%)" , "(%1R%2)" )
		card.name = string.gsub( card.name , "%((.*)Green(.*)%)" , "(%1G%2)" )
		card.name = string.gsub( card.name , "^ %- " , "" )
		card.name = string.gsub( card.name , "%([WUBRGCHTAM][/|]?[WUBRG]?%)" , "" )
		card.name = string.gsub( card.name , "%(Art%)" , "" )
		card.name = string.gsub( card.name , "%(Gld%)" , "" )
		card.name = string.gsub( card.name , "%(Gold%)" , "" )
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
	for lid,lang in pairs( card.lang ) do
		-- define price according to card.foil and card.variant
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
	if sourcerow.regprice then -- keep site.ParseHtmlData preset regprice
		card.regprice = sourcerow.regprice
	end
	if sourcerow.foilprice then -- keep site.ParseHtmlData preset foilprice
		card.foilprice = sourcerow.foilprice
	end
	
	--[[ do final site-specific card data manipulation
	]]
	if site.BCDpluginPost then
		card = site.BCDpluginPost ( card , setid )
	end
	
	card.foil = nil -- remove foilstat; info is retained in [foil|reg]price and it could cause confusion later
	card.BCDpluginData = nil -- if present at all, should have been used and deleted by site.BCDpluginCard 	
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
 @return #number		0 if ok, 1 if conflict; modifies global #table cardsetTable
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
				-- TODO manage cardsetTable conflict differently ?
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
				-- TODO manage cardsetTable conflict differently ?
			end -- if newRow.foilprice[lid] == oldRow.foilprice[lid]
		end -- for lid,lang
	end -- if variants
	mergedRow.lang = langs
	mergedRow.variant = variants
	return mergedRow,conflict
end -- function LHpi.MergeCardrows

--[[-
 calls MA to set card price.
 
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

--[[- save table as csv
file encoding is utf-8 without BOM
@function [parent=#LHpi] SaveCSV( setid , tbl , path )
@param #number setid
@param #table tbl
@param #string path
@return nil
]]
function LHpi.SaveCSV( setid , tbl , path )
	local setname=LHpi.sets[setid].name
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

--[[- detect BOMs to get char encoding
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

--[[- get single-byte representation
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
	if SAVELOG then
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
 for non-tables, length(nil)=nil, otherwise 1.
 
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

--[[- recursively get string representation
 
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

--- site independent set information
-- 
-- @type LHpi.sets
-- @field [parent=#LHpi.sets] #table cardcount		number of (English) cards in MA database.
-- { #number = { reg = #number , tok = #number } , ... }
-- TODO dynamically generate via ma.GetCardCount( setid, langid, cardtype ) when available.
-- @field [parent=#LHpi.sets] #boolean foilonly		set contains only foil cards
-- @field [parent=#LHpi.sets] #table variants		default card variant tables.]]
-- { #number = #table { #string = #table { #string, #table { #number or #boolean , ... } } , ... } , ...  }
LHpi.sets = {
-- Coresets
[797] = { name="Magic 2014",
	cardcount={ reg = 249, tok = 13 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (230)"]				= { "Plains"	, { 1    , false, false, false } }, 
["Plains (231)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (232)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (233)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (234)"]				= { "Island"	, { 1    , false, false, false } },
["Island (235)"]				= { "Island"	, { false, 2    , false, false } },
["Island (236)"]				= { "Island"	, { false, false, 3    , false } },
["Island (237)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (238)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (239)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (240)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (241)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (242)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (243)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (244)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (245)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (246)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (247)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (248)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (249)"]				= { "Forest"	, { false, false, false, 4     } },
["Elemental"]					= { "Elemental"	, { 1    , 2     } },
["Elemental (7)"]				= { "Elemental"	, { 1    , false } },
["Elemental (8)"]				= { "Elemental"	, { false, 2     } },
["Elementarwesen"]				= { "Elementarwesen"	, { 1    , 2     } },
["Elementarwesen (7)"]			= { "Elementarwesen"	, { 1    , false } },
["Elementarwesen (8)"]			= { "Elementarwesen"	, { false, 2     } },
	},
},
[788] = { name="Magic 2013",
	cardcount={ reg = 249, tok = 11 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (230)"]				= { "Plains"	, { 1    , false, false, false } }, 
["Plains (231)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (232)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (233)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (234)"]				= { "Island"	, { 1    , false, false, false } },
["Island (235)"]				= { "Island"	, { false, 2    , false, false } },
["Island (236)"]				= { "Island"	, { false, false, 3    , false } },
["Island (237)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (238)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (239)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (240)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (241)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (242)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (243)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (244)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (245)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (246)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (247)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (248)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (249)"]				= { "Forest"	, { false, false, false, 4     } }
	},
},
[779] = { name="Magic 2012",
	cardcount={ reg = 249, tok =  7 }, 
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (230)"]				= { "Plains"	, { 1    , false, false, false } }, 
["Plains (231)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (232)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (233)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (234)"]				= { "Island"	, { 1    , false, false, false } },
["Island (235)"]				= { "Island"	, { false, 2    , false, false } },
["Island (236)"]				= { "Island"	, { false, false, 3    , false } },
["Island (237)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (238)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (239)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (240)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (241)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (242)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (243)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (244)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (245)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (246)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (247)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (248)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (249)"]				= { "Forest"	, { false, false, false, 4     } }
	},
},
[770] = { name="Magic 2011",
	cardcount={ reg = 249, tok =  6 }, 
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (230)"]				= { "Plains"	, { 1    , false, false, false } }, 
["Plains (231)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (232)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (233)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (234)"]				= { "Island"	, { 1    , false, false, false } },
["Island (235)"]				= { "Island"	, { false, 2    , false, false } },
["Island (236)"]				= { "Island"	, { false, false, 3    , false } },
["Island (237)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (238)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (239)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (240)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (241)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (242)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (243)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (244)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (245)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (246)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (247)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (248)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (249)"]				= { "Forest"	, { false, false, false, 4     } },
["Ooze"]						= { "Ooze"			, { 1    , 2     } },
["Ooze (5)"]					= { "Ooze"			, { 1    , false } },
["Ooze (6)"]					= { "Ooze"			, { false, 2     } },
["Schlammwesen"]				= { "Schlammwesen"	, { 1    , 2     } },
["Schlammwesen (5)"]			= { "Schlammwesen"	, { 1    , false } },
["Schlammwesen (6)"]			= { "Schlammwesen"	, { false, 2     } },
	},
},
[759] = { name="Magic 2010",
	cardcount={ reg = 249, tok =  8 }, 
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (230)"]				= { "Plains"	, { 1    , false, false, false } }, 
["Plains (231)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (232)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (233)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (234)"]				= { "Island"	, { 1    , false, false, false } },
["Island (235)"]				= { "Island"	, { false, 2    , false, false } },
["Island (236)"]				= { "Island"	, { false, false, 3    , false } },
["Island (237)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (238)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (239)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (240)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (241)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (242)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (243)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (244)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (245)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (246)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (247)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (248)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (249)"]				= { "Forest"	, { false, false, false, 4     } }
	},
},
[720] = { name="Tenth Edition",
	cardcount={ reg = 384-1, tok =  6 }, 
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (364)"]				= { "Plains"	, { 1    , false, false, false } },
["Plains (365)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (366)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (367)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (368)"]				= { "Island"	, { 1    , false, false, false } },
["Island (369)"]				= { "Island"	, { false, 2    , false, false } },
["Island (370)"]				= { "Island"	, { false, false, 3    , false } },
["Island (371)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (372)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (373)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (374)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (375)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (376)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (377)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (378)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (379)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (380)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (381)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (382)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (383)"]				= { "Forest"	, { false, false, false, 4     } }
	},
},
[630] = { name="9th Edition",
	cardcount={ reg = 359, tok =  0 }, 
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (331)"]				= { "Plains"	, { 1    , false, false, false } }, 
["Plains (332)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (333)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (334)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (335)"]				= { "Island"	, { 1    , false, false, false } },
["Island (336)"]				= { "Island"	, { false, 2    , false, false } },
["Island (337)"]				= { "Island"	, { false, false, 3    , false } },
["Island (338)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (339)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (340)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (341)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (342)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (343)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (344)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (345)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (346)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (347)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (348)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (349)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (350)"]				= { "Forest"	, { false, false, false, 4     } },
	},
},
[550] = { name="8th Edition",
	cardcount={ reg = 357, tok =  0 }, 
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (331)"]				= { "Plains"	, { 1    , false, false, false } }, 
["Plains (332)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (333)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (334)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (335)"]				= { "Island"	, { 1    , false, false, false } },
["Island (336)"]				= { "Island"	, { false, 2    , false, false } },
["Island (337)"]				= { "Island"	, { false, false, 3    , false } },
["Island (338)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (339)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (340)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (341)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (342)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (343)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (344)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (345)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (346)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (347)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (348)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (349)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (350)"]				= { "Forest"	, { false, false, false, 4     } },
	},
},
[460] = { name="7th Edition",
	cardcount={ reg = 350, tok =  0 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (341)"]				= { "Plains"	, { 1    , false, false, false } }, 
["Plains (342)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (343)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (344)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (332)"]				= { "Island"	, { 1    , false, false, false } },
["Island (333)"]				= { "Island"	, { false, 2    , false, false } },
["Island (334)"]				= { "Island"	, { false, false, 3    , false } },
["Island (335)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (346)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (347)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (348)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (349)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (337)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (338)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (339)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (340)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (328)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (329)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (330)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (331)"]				= { "Forest"	, { false, false, false, 4     } },
	},
},
[360] = { name="6th Edition",
	cardcount={ reg = 350, tok =  0 }, 
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (331)"]				= { "Plains"	, { 1    , false, false, false } }, 
["Plains (332)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (333)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (334)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (335)"]				= { "Island"	, { 1    , false, false, false } },
["Island (336)"]				= { "Island"	, { false, 2    , false, false } },
["Island (337)"]				= { "Island"	, { false, false, 3    , false } },
["Island (338)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (339)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (340)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (341)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (342)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (343)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (344)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (345)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (346)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (347)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (348)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (349)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (350)"]				= { "Forest"	, { false, false, false, 4     } },
	},
},
[250] = { name="5th Edition",
	cardcount={ reg = 449, tok =  0 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (1)"]					= { "Plains"	, { 1    , false, false, false } }, 
["Plains (2)"]					= { "Plains"	, { false, 2    , false, false } },
["Plains (3)"]					= { "Plains"	, { false, false, 3    , false } },
["Plains (4)"]					= { "Plains"	, { false, false, false, 4     } },
["Island (1)"]					= { "Island"	, { 1    , false, false, false } },
["Island (2)"]					= { "Island"	, { false, 2    , false, false } },
["Island (3)"]					= { "Island"	, { false, false, 3    , false } },
["Island (4)"]					= { "Island"	, { false, false, false, 4     } },
["Swamp (1)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (2)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (3)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (4)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (1)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (2)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (3)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (4)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (1)"]					= { "Forest"	, { 1    , false, false, false } },
["Forest (2)"]					= { "Forest"	, { false, 2    , false, false } },
["Forest (3)"]					= { "Forest"	, { false, false, 3    , false } },
["Forest (4)"]					= { "Forest"	, { false, false, false, 4     } },
	},
},
[180] = { name="4th Edition",
	cardcount={ reg = 378, tok =  0 }, 
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3     } },
["Plains (1)"]					= { "Plains"	, { 1    , false, false } },
["Plains (2)"]					= { "Plains"	, { false, 2    , false } },
["Plains (3)"]					= { "Plains"	, { false, false, 3     } },
["Island (1)"]					= { "Island"	, { 1    , false, false } },
["Island (2)"]					= { "Island"	, { false, 2    , false } },
["Island (3)"]					= { "Island"	, { false, false, 3     } },
["Swamp (1)"]					= { "Swamp"		, { 1    , false, false } },
["Swamp (2)"]					= { "Swamp"		, { false, 2    , false } },
["Swamp (3)"]					= { "Swamp"		, { false, false, 3     } },
["Mountain (1)"]				= { "Mountain"	, { 1    , false, false } },
["Mountain (2)"]				= { "Mountain"	, { false, 2    , false } },
["Mountain (3)"]				= { "Mountain"	, { false, false, 3     } },
["Forest (1)"]					= { "Forest"	, { 1    , false, false } },
["Forest (2)"]					= { "Forest"	, { false, 2    , false } },
["Forest (3)"]					= { "Forest"	, { false, false, 3     } },
	},
},
[141] = { name="Revised Edition (Summer Magic)",
	cardcount={ reg=306, tok=0, nontr=0, overs=0 }, 
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3     } },
["Plains (1)"]					= { "Plains"	, { 1    , false, false } },
["Plains (2)"]					= { "Plains"	, { false, 2    , false } },
["Plains (3)"]					= { "Plains"	, { false, false, 3     } },
["Island (1)"]					= { "Island"	, { 1    , false, false } },
["Island (2)"]					= { "Island"	, { false, 2    , false } },
["Island (3)"]					= { "Island"	, { false, false, 3     } },
["Swamp (1)"]					= { "Swamp"		, { 1    , false, false } },
["Swamp (2)"]					= { "Swamp"		, { false, 2    , false } },
["Swamp (3)"]					= { "Swamp"		, { false, false, 3     } },
["Mountain (1)"]				= { "Mountain"	, { 1    , false, false } },
["Mountain (2)"]				= { "Mountain"	, { false, 2    , false } },
["Mountain (3)"]				= { "Mountain"	, { false, false, 3     } },
["Forest (1)"]					= { "Forest"	, { 1    , false, false } },
["Forest (2)"]					= { "Forest"	, { false, 2    , false } },
["Forest (3)"]					= { "Forest"	, { false, false, 3     } },
	},
},
[140] = { name="Revised Edition",
	cardcount={ reg = 306, tok =  0 }, 
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3     } },
["Plains (1)"]					= { "Plains"	, { 1    , false, false } },
["Plains (2)"]					= { "Plains"	, { false, 2    , false } },
["Plains (3)"]					= { "Plains"	, { false, false, 3     } },
["Island (1)"]					= { "Island"	, { 1    , false, false } },
["Island (2)"]					= { "Island"	, { false, 2    , false } },
["Island (3)"]					= { "Island"	, { false, false, 3     } },
["Swamp (1)"]					= { "Swamp"		, { 1    , false, false } },
["Swamp (2)"]					= { "Swamp"		, { false, 2    , false } },
["Swamp (3)"]					= { "Swamp"		, { false, false, 3     } },
["Mountain (1)"]				= { "Mountain"	, { 1    , false, false } },
["Mountain (2)"]				= { "Mountain"	, { false, 2    , false } },
["Mountain (3)"]				= { "Mountain"	, { false, false, 3     } },
["Forest (1)"]					= { "Forest"	, { 1    , false, false } },
["Forest (2)"]					= { "Forest"	, { false, 2    , false } },
["Forest (3)"]					= { "Forest"	, { false, false, 3     } },
	},
},
[139] = { name="Revised Edition (Limited)",
	cardcount={ reg = 306, tok =  0 }, 
	variants={
["Plains"] 						= { "Ebene"		, { 1    , 2    , 3     } },
["Island"] 						= { "Insel" 	, { 1    , 2    , 3     } },
["Swamp"] 						= { "Sumpf"		, { 1    , 2    , 3     } },
["Mountain"] 					= { "Gebirge"	, { 1    , 2    , 3     } },
["Forest"] 						= { "Wald"	 	, { 1    , 2    , 3     } },
["Plains (1)"]					= { "Plains"	, { 1    , false, false } },
["Plains (2)"]					= { "Plains"	, { false, 2    , false } },
["Plains (3)"]					= { "Plains"	, { false, false, 3     } },
["Island (1)"]					= { "Island"	, { 1    , false, false } },
["Island (2)"]					= { "Island"	, { false, 2    , false } },
["Island (3)"]					= { "Island"	, { false, false, 3     } },
["Swamp (1)"]					= { "Swamp"		, { 1    , false, false } },
["Swamp (2)"]					= { "Swamp"		, { false, 2    , false } },
["Swamp (3)"]					= { "Swamp"		, { false, false, 3     } },
["Mountain (1)"]				= { "Mountain"	, { 1    , false, false } },
["Mountain (2)"]				= { "Mountain"	, { false, 2    , false } },
["Mountain (3)"]				= { "Mountain"	, { false, false, 3     } },
["Forest (1)"]					= { "Forest"	, { 1    , false, false } },
["Forest (2)"]					= { "Forest"	, { false, 2    , false } },
["Forest (3)"]					= { "Forest"	, { false, false, 3     } },
	},
},
[110] = { name="Unlimited",
	cardcount={ reg = 302, tok =  0 }, 
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3     } },
["Plains (1)"]					= { "Plains"	, { 1    , false, false } },
["Plains (2)"]					= { "Plains"	, { false, 2    , false } },
["Plains (3)"]					= { "Plains"	, { false, false, 3     } },
["Island (1)"]					= { "Island"	, { 1    , false, false } },
["Island (2)"]					= { "Island"	, { false, 2    , false } },
["Island (3)"]					= { "Island"	, { false, false, 3     } },
["Swamp (1)"]					= { "Swamp"		, { 1    , false, false } },
["Swamp (2)"]					= { "Swamp"		, { false, 2    , false } },
["Swamp (3)"]					= { "Swamp"		, { false, false, 3     } },
["Mountain (1)"]				= { "Mountain"	, { 1    , false, false } },
["Mountain (2)"]				= { "Mountain"	, { false, 2    , false } },
["Mountain (3)"]				= { "Mountain"	, { false, false, 3     } },
["Forest (1)"]					= { "Forest"	, { 1    , false, false } },
["Forest (2)"]					= { "Forest"	, { false, 2    , false } },
["Forest (3)"]					= { "Forest"	, { false, false, 3     } },
	},
},
[100] = { name="Beta",
	cardcount={ reg = 302, tok =  0 }, 
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3     } },
["Plains (1)"]					= { "Plains"	, { 1    , false, false } },
["Plains (2)"]					= { "Plains"	, { false, 2    , false } },
["Plains (3)"]					= { "Plains"	, { false, false, 3     } },
["Island (1)"]					= { "Island"	, { 1    , false, false } },
["Island (2)"]					= { "Island"	, { false, 2    , false } },
["Island (3)"]					= { "Island"	, { false, false, 3     } },
["Swamp (1)"]					= { "Swamp"		, { 1    , false, false } },
["Swamp (2)"]					= { "Swamp"		, { false, 2    , false } },
["Swamp (3)"]					= { "Swamp"		, { false, false, 3     } },
["Mountain (1)"]				= { "Mountain"	, { 1    , false, false } },
["Mountain (2)"]				= { "Mountain"	, { false, 2    , false } },
["Mountain (3)"]				= { "Mountain"	, { false, false, 3     } },
["Forest (1)"]					= { "Forest"	, { 1    , false, false } },
["Forest (2)"]					= { "Forest"	, { false, 2    , false } },
["Forest (3)"]					= { "Forest"	, { false, false, 3     } },
	},
},
[90]  = { name="Alpha",
	cardcount={ reg = 295, tok =  0 }, 
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2     } },
["Island"] 						= { "Island" 	, { 1    , 2     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2     } },
["Forest"] 						= { "Forest" 	, { 1    , 2     } },
["Plains (1)"]					= { "Plains"	, { 1    , false } },
["Plains (2)"]					= { "Plains"	, { false, 2     } },
["Island (1)"]					= { "Island"	, { 1    , false } },
["Island (2)"]					= { "Island"	, { false, 2     } },
["Swamp (1)"]					= { "Swamp"		, { 1    , false } },
["Swamp (2)"]					= { "Swamp"		, { false, 2     } },
["Mountain (1)"]				= { "Mountain"	, { 1    , false } },
["Mountain (2)"]				= { "Mountain"	, { false, 2     } },
["Forest (1)"]					= { "Forest"	, { 1    , false } },
["Forest (2)"]					= { "Forest"	, { false, 2     } },
	},
},
-- Expansions
[802] = { name="Born of the Gods",
	cardcount={ reg=165, tok=11 },
	variants={
["Bird"]						= { "Bird"		, { 1    , 2     } },
["Bird (1)"]					= { "Bird"		, { 1    , false } },--White
["Bird (4)"]					= { "Bird"		, { false, 2     } },--Blue
	},
},
[800] = { name="Theros",
	cardcount={ reg = 249, tok = 11 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (230)"]				= { "Plains"	, { 1    , false ,false, false } }, 
["Plains (231)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (232)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (233)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (234)"]				= { "Island"	, { 1    , false, false, false } },
["Island (235)"]				= { "Island"	, { false, 2    , false, false } },
["Island (236)"]				= { "Island"	, { false, false, 3    , false } },
["Island (237)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (238)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (239)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (240)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (241)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (242)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (243)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (244)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (245)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (246)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (247)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (248)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (249)"]				= { "Forest"	, { false, false, false, 4     } },
["Soldier"]						= { "Soldier"	, { 1    , 2    , 3     } },
["Soldier (2)"]					= { "Soldier"	, { 1    , false, false } },
["Soldier (3)"]					= { "Soldier"	, { false, 2    , false } },
["Soldier (7)"]					= { "Soldier"	, { false, false, 3     } },--Red
["Soldat"]						= { "Soldat"	, { 1    , 2    , 3     } },
["Soldat (2)"]					= { "Soldat"	, { 1    , false, false } },
["Soldat (3)"]					= { "Soldat"	, { false, 2    , false } },
["Soldat (7)"]					= { "Soldat"	, { false, false, 3     } },
	},
},
[795] = { name="Dragon's Maze",
	cardcount={ reg = 156, tok =  1 },
	variants={}
},
[793] = { name="Gatecrash",
	cardcount={ reg = 249, tok =  8 },
	variants={}
},
[791] = { name="Return to Ravnica",
	cardcount={ reg = 274, tok = 12 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4    , 5     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4    , 5     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4    , 5     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4    , 5     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4    , 5     } },
["Plains (250)"]				= { "Plains"	, { 1    , false, false, false, false } },
["Plains (251)"]				= { "Plains"	, { false, 2    , false, false, false } },
["Plains (252)"]				= { "Plains"	, { false, false, 3    , false, false } },
["Plains (253)"]				= { "Plains"	, { false, false, false, 4    , false } },
["Plains (254)"]				= { "Plains"	, { false, false, false, false, 5     } },
["Island (255)"]				= { "Island"	, { 1    , false, false, false, false } },
["Island (256)"]				= { "Island"	, { false, 2    , false, false, false } },
["Island (257)"] 				= { "Island"	, { false, false, 3    , false, false } },
["Island (258)"]				= { "Island"	, { false, false, false, 4    , false } },
["Island (259)"]				= { "Island"	, { false, false, false, false, 5     } },
["Swamp (260)"]					= { "Swamp" 	, { 1    , false, false, false, false } },
["Swamp (261)"]					= { "Swamp" 	, { false, 2    , false, false, false } },
["Swamp (262)"]					= { "Swamp" 	, { false, false, 3    , false, false } },
["Swamp (263)"]					= { "Swamp" 	, { false, false, false, 4    , false } },
["Swamp (264)"]					= { "Swamp" 	, { false, false, false, false, 5     } },
["Mountain (265)"]				= { "Mountain"	, { 1    , false, false, false, false } },
["Mountain (266)"]				= { "Mountain"	, { false, 2    , false, false, false } },
["Mountain (267)"]				= { "Mountain"	, { false, false, 3    , false, false } },
["Mountain (268)"]				= { "Mountain"	, { false, false, false, 4    , false } },
["Mountain (269)"]				= { "Mountain"	, { false, false, false, false, 5     } },
["Forest (270)"]				= { "Forest"	, { 1    , false, false, false, false } },
["Forest (271)"]				= { "Forest"	, { false, 2    , false, false, false } },
["Forest (272)"]				= { "Forest"	, { false, false, 3    , false, false } },
["Forest (273)"]				= { "Forest"	, { false, false, false, 4    , false } },
["Forest (274)"]				= { "Forest"	, { false, false, false, false, 5     } }
	},
},
[786] = { name="Avacyn Restored",
	cardcount={ reg = 244, tok =  8 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3     } },
["Plains (230)"]				= { "Plains"	, { 1    , false, false } },
["Plains (231)"]				= { "Plains"	, { false, 2    , false } },
["Plains (232)"]				= { "Plains"	, { false, false, 3     } },
["Island (233)"]				= { "Island"	, { 1    , false, false } },
["Island (234)"]				= { "Island"	, { false, 2    , false } },
["Island (235)"]				= { "Island"	, { false, false, 3     } },
["Swamp (236)"]					= { "Swamp"		, { 1    , false, false } },
["Swamp (237)"]					= { "Swamp"		, { false, 2    , false } },
["Swamp (238)"]					= { "Swamp"		, { false, false, 3     } },
["Mountain (239)"]				= { "Mountain"	, { 1    , false, false } },
["Mountain (240)"]				= { "Mountain"	, { false, 2    , false } },
["Mountain (241)"]				= { "Mountain"	, { false, false, 3     } },
["Forest (242)"]				= { "Forest"	, { 1    , false, false } },
["Forest (243)"]				= { "Forest"	, { false, 2    , false } },
["Forest (244)"]				= { "Forest"	, { false, false, 3     } },
["Human"]						= { "Human"		, { 1    , 2     } },
["Human (2)"]					= { "Human"		, { 1    ,false  } },--White
["Human (7)"]					= { "Human"		, { false, 2     } },--Red
["Spirit"]						= { "Spirit"	, { 1    , 2     } },
["Spirit (3)"]					= { "Spirit"	, { 1    , false } },--White
["Spirit (4)"]					= { "Spirit"	, { false, 2     } },--Blue
["Mensch"]						= { "Mensch"	, { 1    , 2     } },
["Mensch (2)"]					= { "Mensch"	, { 1    ,false  } },
["Mensch (7)"]					= { "Mensch"	, { false, 2     } },
["Geist"]						= { "Geist"		, { 1    , 2     } },
["Geist (3)"]					= { "Geist"		, { 1    , false } },
["Geist (4)"]					= { "Geist"		, { false, 2     } },
	},
},
[784] = { name="Dark Ascension",
	cardcount={ reg = 158, tok =  3 }, 
	variants={}
},
[782] = { name="Innistrad",
	cardcount={ reg = 264, tok = 12 }, 
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3     } },
["Plains (250)"]				= { "Plains"	, { 1    , false, false } },
["Plains (251)"]				= { "Plains"	, { false, 2    , false } },
["Plains (252)"]				= { "Plains"	, { false, false, 3     } },
["Island (253)"]				= { "Island"	, { 1    , false, false } },
["Island (254)"]				= { "Island"	, { false, 2    , false } },
["Island (255)"]				= { "Island"	, { false, false, 3     } },
["Swamp (256)"]					= { "Swamp"		, { 1    , false, false } },
["Swamp (257)"]					= { "Swamp"		, { false, 2    , false } },
["Swamp (258)"]					= { "Swamp"		, { false, false, 3     } },
["Mountain (259)"]				= { "Mountain"	, { 1    , false, false } },
["Mountain (260)"]				= { "Mountain"	, { false, 2    , false } },
["Mountain (261)"]				= { "Mountain"	, { false, false, 3     } },
["Forest (262)"]				= { "Forest"	, { 1    , false, false } },
["Forest (263)"]				= { "Forest"	, { false, 2    , false } },
["Forest (264)"]				= { "Forest"	, { false, false, 3     } },
["Wolf"]						= { "Wolf"		, { 1    , 2     } },
["Wolf (6)"]					= { "Wolf"		, { 1    , false } },--Deathtouch
["Wolf (12)"]					= { "Wolf"		, { false, 2     } },--Green
["Zombie"]						= { "Zombie"	, { 1    , 2    , 3		} },
["Zombie (7)"]					= { "Zombie"	, { 1    , false, false } },
["Zombie (8)"]					= { "Zombie"	, { false, 2    , false } },
["Zombie (9)"]					= { "Zombie"	, { false, false, 3     } },
	},
},
[776] = { name="New Phyrexia",
	cardcount={ reg = 175, tok =  4 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2     } },
["Island"] 						= { "Island" 	, { 1    , 2     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2     } },
["Forest"] 						= { "Forest" 	, { 1    , 2     } },
["Plains (166)"]				= { "Plains"	, { 1    , false } },
["Plains (167)"]				= { "Plains"	, { false, 2     } },
["Island (168)"]				= { "Island"	, { 1    , false } },
["Island (169)"]				= { "Island"	, { false, 2     } },
["Swamp (170)"]					= { "Swamp"		, { 1    , false } },
["Swamp (171)"]					= { "Swamp"		, { false, 2     } },
["Mountain (172)"]				= { "Mountain"	, { 1    , false } },
["Mountain (173)"]				= { "Mountain"	, { false, 2     } },
["Forest (174)"]				= { "Forest"	, { 1    , false } },
["Forest (175)"]				= { "Forest"	, { false, 2     } }
	},
},
[775] = { name="Mirrodin Besieged",
	cardcount={ reg = 155, tok =  5 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2     } },
["Island"] 						= { "Island" 	, { 1    , 2     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2     } },
["Forest"] 						= { "Forest" 	, { 1    , 2     } },
["Plains (146)"]				= { "Plains"	, { 1    , false } },
["Plains (147)"]				= { "Plains"	, { false, 2     } },
["Island (148)"]				= { "Island"	, { 1    , false } },
["Island (149)"]				= { "Island"	, { false, 2     } },
["Swamp (150)"]					= { "Swamp"		, { 1    , false } },
["Swamp (151)"]					= { "Swamp"		, { false, 2     } },
["Mountain (152)"]				= { "Mountain"	, { 1    , false } },
["Mountain (153)"]				= { "Mountain"	, { false, 2     } },
["Forest (154)"]				= { "Forest"	, { 1    , false } },
["Forest (155)"]				= { "Forest"	, { false, 2     } }
	},
},
[773] = { name="Scars of Mirrodin",
	cardcount={ reg = 249, tok =  9 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (230)"]				= { "Plains"	, { 1    , false ,false, false } }, 
["Plains (231)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (232)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (233)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (234)"]				= { "Island"	, { 1    , false, false, false } },
["Island (235)"]				= { "Island"	, { false, 2    , false, false } },
["Island (236)"]				= { "Island"	, { false, false, 3    , false } },
["Island (237)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (238)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (239)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (240)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (241)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (242)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (243)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (244)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (245)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (246)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (247)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (248)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (249)"]				= { "Forest"	, { false, false, false, 4     } },
["Wurm"]						= { "Wurm"		, { 1    , 2     } },
["Wurm (8)"]					= { "Wurm"		, { 1    , false } }, -- Deathtouch
["Wurm (9)"]					= { "Wurm"		, { false, 2     } }, -- Lifelink
["Poison Counter"]				= { "Poison Counter"	, { "*" } },
	},
},
[767] = { name="Rise of the Eldrazi",
	cardcount={ reg = 248, tok =  7 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (229)"]				= { "Plains"	, { 1    , false, false, false } }, 
["Plains (230)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (231)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (232)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (233)"]				= { "Island"	, { 1    , false, false, false } },
["Island (234)"]				= { "Island"	, { false, 2    , false, false } },
["Island (235)"]				= { "Island"	, { false, false, 3    , false } },
["Island (236)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (237)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (238)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (239)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (240)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (241)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (242)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (243)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (244)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (245)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (246)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (247)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (248)"]				= { "Forest"	, { false, false, false, 4     } },
["Eldrazi Spawn"]		 		= { "Eldrazi Spawn"		, { "a"   , "b"   , "c"   } },
["Eldrazi Spawn (1a)"]		 	= { "Eldrazi Spawn"		, { "a"   , false , false } },
["Eldrazi Spawn (1b)"]		 	= { "Eldrazi Spawn"		, { false , "b"   , false } },
["Eldrazi Spawn (1c)"]		 	= { "Eldrazi Spawn"		, { false , false , "c"   } },
["Eldrazi, Ausgeburt"]			= { "Eldrazi, Ausgeburt", { "a"   , "b"   , "c"   } },
["Eldrazi, Ausgeburt (1a)"]	 	= { "Eldrazi, Ausgeburt", { "a"   , false , false } },
["Eldrazi, Ausgeburt (1b)"]	 	= { "Eldrazi, Ausgeburt", { false , "b"   , false } },
["Eldrazi, Ausgeburt (1c)"]	 	= { "Eldrazi, Ausgeburt", { false , false , "c"   } },
	},
},
[765] = { name="Worldwake",
	cardcount={ reg = 145, tok =  6 },
	variants={}
},
[762] = { name="Zendikar",
	cardcount={ reg = 269-20, tok = 11 }, -- do not count normal-art basic lands
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4    } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (230)"]				= { "Plains"	, { 1    , false, false, false } },
["Plains (231)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (232)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (233)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (234)"]				= { "Island"	, { 1    , false, false, false } },
["Island (235)"]				= { "Island"	, { false, 2    , false, false } },
["Island (236)"]				= { "Island"	, { false, false, 3    , false } },
["Island (237)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (238)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (239)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (240)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (241)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (242)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (243)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (244)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (245)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (246)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (247)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (248)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (249)"]				= { "Forest"	, { false, false, false, 4     } }
	},
},
[758] = { name="Alara Reborn",
	cardcount={ reg = 145, tok =  4 },
	variants={}
},
[756] = { name="Conflux",
	cardcount={ reg = 145, tok =  2 },
	variants={}
},
[754] = { name="Shards of Alara",
	cardcount={ reg = 249, tok = 10 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (230)"]				= { "Plains"	, { 1    , false ,false, false } }, 
["Plains (231)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (232)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (233)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (234)"]				= { "Island"	, { 1    , false, false, false } },
["Island (235)"]				= { "Island"	, { false, 2    , false, false } },
["Island (236)"]				= { "Island"	, { false, false, 3    , false } },
["Island (237)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (238)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (239)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (240)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (241)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (242)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (243)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (244)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (245)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (246)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (247)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (248)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (249)"]				= { "Forest"	, { false, false, false, 4     } }
	},
},
[752] = { name="Eventide",
	cardcount={ reg = 180, tok =  7 },
	variants={}
},
[751] = { name="Shadowmoor",
	cardcount={ reg = 301, tok = 12 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (282)"]				= { "Plains"	, { 1    , false ,false, false } }, 
["Plains (283)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (284)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (285)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (286)"]				= { "Island"	, { 1    , false, false, false } },
["Island (287)"]				= { "Island"	, { false, 2    , false, false } },
["Island (288)"]				= { "Island"	, { false, false, 3    , false } },
["Island (289)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (290)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (291)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (292)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (293)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (294)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (295)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (296)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (297)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (298)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (299)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (300)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (301)"]				= { "Forest"	, { false, false, false, 4     } },
["Elemental"] 					= { "Elemental"		, { 1    , 2     } },
["Elemental (4)"] 				= { "Elemental"		, { 1    , false } },--Red
["Elemental (9)"] 				= { "Elemental"		, { false, 2     } },--Black|Red
["Elf Warrior"]					= { "Elf Warrior"	, { 1    , 2     } },
["Elf Warrior (5)"]				= { "Elf Warrior"	, { 1    , false } },--Green
["Elf Warrior (12)"]			= { "Elf Warrior"	, { false, 2     } },--White|Green
["Elementarwesen"] 				= { "Elementarwesen", { 1    , 2     } },
["Elementarwesen (4)"] 			= { "Elementarwesen", { 1    , false } },
["Elementarwesen (9)"] 			= { "Elementarwesen", { false, 2     } },
["Elf, Krieger"]				= { "Elf, Krieger"	, { 1    , 2     } },
["Elf, Krieger (5)"]			= { "Elf, Krieger"	, { 1    , false } },
["Elf, Krieger (12)"]			= { "Elf, Krieger"	, { false, 2     } },
	},
},
[750] = { name="Morningtide",
	cardcount={ reg = 150, tok =  3 },
	variants={}
},
[730] = { name="Lorwyn",
	cardcount={ reg = 301, tok = 11 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (282)"]				= { "Plains"	, { 1    , false ,false, false } }, 
["Plains (283)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (284)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (285)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (286)"]				= { "Island"	, { 1    , false, false, false } },
["Island (287)"]				= { "Island"	, { false, 2    , false, false } },
["Island (288)"]				= { "Island"	, { false, false, 3    , false } },
["Island (289)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (290)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (291)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (292)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (293)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (294)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (295)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (296)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (297)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (298)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (299)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (300)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (301)"]				= { "Forest"	, { false, false, false, 4     } },
["Elemental"] 					= { "Elemental"		, { 1    , 2     } },
["Elemental (2)"] 				= { "Elemental"		, { 1    , false } },--White
["Elemental (8)"] 				= { "Elemental"		, { false, 2     } },--Green
["Elementarwesen"] 				= { "Elementarwesen", { 1    , 2     } },
["Elementarwesen (2)"] 			= { "Elementarwesen", { 1    , false } },
["Elementarwesen (8)"] 			= { "Elementarwesen", { false, 2     } },
	},
},
[710] = { name="Future Sight",
	cardcount={ reg = 180, tok =  0 },
	variants={}
},
[700] = { name="Planar Chaos",
	cardcount={ reg = 165, tok =  0 },
	variants={}
},
[690] = { name="Time Spiral Timeshifted",
	cardcount={ reg = 121, tok =  0 },
	variants={}
},
[680] = { name="Time Spiral",
	cardcount={ reg = 301, tok =  0 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (282)"]				= { "Plains"	, { 1    , false ,false, false } }, 
["Plains (283)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (284)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (285)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (286)"]				= { "Island"	, { 1    , false, false, false } },
["Island (287)"]				= { "Island"	, { false, 2    , false, false } },
["Island (288)"]				= { "Island"	, { false, false, 3    , false } },
["Island (289)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (290)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (291)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (292)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (293)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (294)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (295)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (296)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (297)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (298)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (299)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (300)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (301)"]				= { "Forest"	, { false, false, false, 4     } },
	},
},
[670] = { name="Coldsnap",
	cardcount={ reg = 155, tok =  0 },
	variants={}
},
[660] = { name="Dissension",
	cardcount={ reg = 180, tok =  0 },
	variants={}
},
[650] = { name="Guildpact",
	cardcount={ reg = 165, tok =  0 },
	variants={}
},
[640] = { name="Ravnica: City of Guilds",
	cardcount={ reg = 306, tok =  0 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (287)"]				= { "Plains"	, { 1    , false ,false, false } }, 
["Plains (288)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (289)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (290)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (291)"]				= { "Island"	, { 1    , false, false, false } },
["Island (292)"]				= { "Island"	, { false, 2    , false, false } },
["Island (293)"]				= { "Island"	, { false, false, 3    , false } },
["Island (294)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (295)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (296)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (297)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (298)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (299)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (300)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (301)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (302)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (303)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (304)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (305)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (306)"]				= { "Forest"	, { false, false, false, 4     } }
	},
},
[620] = { name="Saviors of Kamigawa",
	cardcount={ reg = 165, tok =  0 },
	variants={}
},
[610] = { name="Betrayers of Kamigawa",
	cardcount={ reg = 165, tok =  0 },
	variants={}
},
[590] = { name="Champions of Kamigawa",
	cardcount={ reg = 307, tok =  0 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (287)"]				= { "Plains"	, { 1    , false ,false, false } }, 
["Plains (288)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (289)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (290)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (291)"]				= { "Island"	, { 1    , false, false, false } },
["Island (292)"]				= { "Island"	, { false, 2    , false, false } },
["Island (293)"]				= { "Island"	, { false, false, 3    , false } },
["Island (294)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (295)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (296)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (297)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (298)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (299)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (300)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (301)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (302)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (303)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (304)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (305)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (306)"]				= { "Forest"	, { false, false, false, 4     } },
["Brothers Yamazaki"]			= { "Brothers Yamazaki"	, { "a"  , "b"   } },
["Brothers Yamazaki (a)"]		= { "Brothers Yamazaki"	, { "a"  , false } },
["Brothers Yamazaki (b)"]		= { "Brothers Yamazaki"	, { false, "b"   } },
["Yamazaki-Brüder"]				= { "Yamazaki-Brüder"	, { "a"  , "b"   } },
["Yamazaki-Brüder (a)"]			= { "Yamazaki-Brüder"	, { "a"  , false } },
["Yamazaki-Brüder (b)"]			= { "Yamazaki-Brüder"	, { false, "b"   } },
	},
},
[580] = { name="Fifth Dawn",
	cardcount={ reg = 165, tok =  0 },
	variants={}
},
[570] = { name="Darksteel",
	cardcount={ reg = 165, tok =  0 },
	variants={}
},
[560] = { name="Mirrodin",
	cardcount={ reg = 306, tok =  0 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (287)"]				= { "Plains"	, { 1    , false ,false, false } }, 
["Plains (288)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (289)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (290)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (291)"]				= { "Island"	, { 1    , false, false, false } },
["Island (292)"]				= { "Island"	, { false, 2    , false, false } },
["Island (293)"]				= { "Island"	, { false, false, 3    , false } },
["Island (294)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (295)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (296)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (297)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (298)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (299)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (300)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (301)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (302)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (303)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (304)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (305)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (306)"]				= { "Forest"	, { false, false, false, 4     } },
	},
},
[540] = { name="Scourge",
	cardcount={ reg = 143, tok =  0 },
	variants={}
},
[530] = { name="Legions",
	cardcount={ reg = 145, tok =  0 },
	variants={}
},
[520] = { name="Onslaught",
	cardcount={ reg = 350, tok =  0 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (331)"]				= { "Plains"	, { 1    , false, false, false } }, 
["Plains (332)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (333)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (334)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (335)"]				= { "Island"	, { 1    , false, false, false } },
["Island (336)"]				= { "Island"	, { false, 2    , false, false } },
["Island (337)"]				= { "Island"	, { false, false, 3    , false } },
["Island (338)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (339)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (340)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (341)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (342)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (343)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (344)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (345)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (346)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (347)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (348)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (349)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (350)"]				= { "Forest"	, { false, false, false, 4     } },
	},
},
[510] = { name="Judgment",
	cardcount={ reg = 143, tok =  0 },
	variants={}
},
[500] = { name="Torment",
	cardcount={ reg = 143, tok =  0 },
	variants={}
},
[480] = { name="Odyssey",
	cardcount={ reg = 350, tok =  0 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (331)"]				= { "Plains"	, { 1    , false, false, false } }, 
["Plains (332)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (333)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (334)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (335)"]				= { "Island"	, { 1    , false, false, false } },
["Island (336)"]				= { "Island"	, { false, 2    , false, false } },
["Island (337)"]				= { "Island"	, { false, false, 3    , false } },
["Island (338)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (339)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (340)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (341)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (342)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (343)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (344)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (345)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (346)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (347)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (348)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (349)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (350)"]				= { "Forest"	, { false, false, false, 4     } },
	},
},
[470] = { name="Apocalypse",
	cardcount={ reg = 143, tok =  0 },
	variants={}
},
[450] = { name="Planeshift",
	cardcount={ reg = 146, tok =  0 },
	variants={
["Ertai, the Corrupted"] 			= { "Ertai, the Corrupted"		, { ""   , false } },
["Ertai, the Corrupted (Alt)"] 		= { "Ertai, the Corrupted"		, { false, "Alt" } },
["Skyship Weatherlight"] 			= { "Skyship Weatherlight"		, { ""   , false } },
["Skyship Weatherlight (Alt)"] 		= { "Skyship Weatherlight"		, { false, "Alt" } },
["Tahngarth, Talruum Hero"] 		= { "Tahngarth, Talruum Hero"	, { ""   , false } },
["Tahngarth, Talruum Hero (Alt)"]	= { "Tahngarth, Talruum Hero"	, { false, "Alt" } },
--["Ertai, the Corrupted (Alt)"] 		= { "Ertai, the Corrupted"		, { "Alt" } },
--["Skyship Weatherlight (Alt)"] 		= { "Skyship Weatherlight"		, { "Alt" } },
--["Tahngarth, Talruum Hero (Alt)"]	= { "Tahngarth, Talruum Hero"	, { "Alt" } },
	},
	foiltweak={
["Ertai, the Corrupted (Alt)"] 		= { foil = true },
["Skyship Weatherlight (Alt)"] 		= { foil = true },
["Tahngarth, Talruum Hero (Alt)"]	= { foil = true },

	}
},
[430] = { name="Invasion",
	cardcount={ reg = 350, tok =  0 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (331)"]				= { "Plains"	, { 1    , false, false, false } }, 
["Plains (332)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (333)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (334)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (335)"]				= { "Island"	, { 1    , false, false, false } },
["Island (336)"]				= { "Island"	, { false, 2    , false, false } },
["Island (337)"]				= { "Island"	, { false, false, 3    , false } },
["Island (338)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (339)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (340)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (341)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (342)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (343)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (344)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (345)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (346)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (347)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (348)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (349)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (350)"]				= { "Forest"	, { false, false, false, 4     } },
	},
},
[420] = { name="Prophecy",
	cardcount={ reg = 143, tok =  0 },
	variants={}
},
[410] = { name="Nemesis",
	cardcount={ reg = 143, tok =  0 },
	variants={}
},
[400] = { name="Mercadian Masques",
	cardcount={ reg = 350, tok =  0 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (331)"]				= { "Plains"	, { 1    , false, false, false } }, 
["Plains (332)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (333)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (334)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (335)"]				= { "Island"	, { 1    , false, false, false } },
["Island (336)"]				= { "Island"	, { false, 2    , false, false } },
["Island (337)"]				= { "Island"	, { false, false, 3    , false } },
["Island (338)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (339)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (340)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (341)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (342)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (343)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (344)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (345)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (346)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (347)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (348)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (349)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (350)"]				= { "Forest"	, { false, false, false, 4     } },
	},
},
[370] = { name="Urza's Destiny",
	cardcount={ reg = 143, tok =  0 },
	variants={}
},
[350] = { name="Urza's Legacy",
	cardcount={ reg = 143, tok =  0 },
	variants={}
},
[330] = { name="Urza's Saga",
	cardcount={ reg = 350, tok =  0 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (331)"]				= { "Plains"	, { 1    , false, false, false } }, 
["Plains (332)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (333)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (334)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (335)"]				= { "Island"	, { 1    , false, false, false } },
["Island (336)"]				= { "Island"	, { false, 2    , false, false } },
["Island (337)"]				= { "Island"	, { false, false, 3    , false } },
["Island (338)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (339)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (340)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (341)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (342)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (343)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (344)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (345)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (346)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (347)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (348)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (349)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (350)"]				= { "Forest"	, { false, false, false, 4     } },
	},
},
[300] = { name="Exodus",
	cardcount={ reg = 143, tok =  0 },
	variants={}
},
[290] = { name="Stronghold",
	cardcount={ reg = 143, tok =  0 },
	variants={}
},
[280] = { name="Tempest",
	cardcount={ reg = 350, tok =  0 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (1)"]					= { "Plains"	, { 1    , false, false, false } }, 
["Plains (2)"]					= { "Plains"	, { false, 2    , false, false } },
["Plains (3)"]					= { "Plains"	, { false, false, 3    , false } },
["Plains (4)"]					= { "Plains"	, { false, false, false, 4     } },
["Island (1)"]					= { "Island"	, { 1    , false, false, false } },
["Island (2)"]					= { "Island"	, { false, 2    , false, false } },
["Island (3)"]					= { "Island"	, { false, false, 3    , false } },
["Island (4)"]					= { "Island"	, { false, false, false, 4     } },
["Swamp (1)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (2)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (3)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (4)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (1)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (2)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (3)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (4)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (1)"]					= { "Forest"	, { 1    , false, false, false } },
["Forest (2)"]					= { "Forest"	, { false, 2    , false, false } },
["Forest (3)"]					= { "Forest"	, { false, false, 3    , false } },
["Forest (4)"]					= { "Forest"	, { false, false, false, 4     } },
	},
},
[270] = { name="Weatherlight",
	cardcount={ reg = 167, tok =  0 },
	variants={}
},
[240] = { name="Visions",
	cardcount={ reg = 167, tok =  0 },
	variants={}
},
[230] = { name="Mirage",
	cardcount={ reg = 350, tok =  0 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (1)"]					= { "Plains"	, { 1    , false, false, false } }, 
["Plains (2)"]					= { "Plains"	, { false, 2    , false, false } },
["Plains (3)"]					= { "Plains"	, { false, false, 3    , false } },
["Plains (4)"]					= { "Plains"	, { false, false, false, 4     } },
["Island (1)"]					= { "Island"	, { 1    , false, false, false } },
["Island (2)"]					= { "Island"	, { false, 2    , false, false } },
["Island (3)"]					= { "Island"	, { false, false, 3    , false } },
["Island (4)"]					= { "Island"	, { false, false, false, 4     } },
["Swamp (1)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (2)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (3)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (4)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (1)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (2)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (3)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (4)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (1)"]					= { "Forest"	, { 1    , false, false, false } },
["Forest (2)"]					= { "Forest"	, { false, 2    , false, false } },
["Forest (3)"]					= { "Forest"	, { false, false, 3    , false } },
["Forest (4)"]					= { "Forest"	, { false, false, false, 4     } },
	},
},
[220] = { name="Alliances",
	cardcount={ reg = 199, tok =  0 },
	variants={
["Aesthir Glider"] 						= { "Aesthir Glider"				, { 1    , 2     } },
["Aesthir Glider (1)"] 					= { "Aesthir Glider"				, { 1    , false } },
["Aesthir Glider (2)"] 					= { "Aesthir Glider"				, { false, 2     } },
	["Aesthirgleiter"] 					= { "Aesthirgleiter"				, { 1    , 2     } },
	["Aesthirgleiter (1)"] 				= { "Aesthirgleiter"				, { 1    , false } },
	["Aesthirgleiter (2)"] 				= { "Aesthirgleiter"				, { false, 2     } },
["Agent of Stromgald"] 					= { "Agent of Stromgald"			, { 1    , 2     } },
["Agent of Stromgald (1)"] 				= { "Agent of Stromgald"			, { 1    , false } },
["Agent of Stromgald (2)"] 				= { "Agent of Stromgald"			, { false, 2     } },
	["Agent der Stromgalder"] 			= { "Agent der Stromgalder"			, { 1    , 2     } },
	["Agent der Stromgalder (1)"] 		= { "Agent der Stromgalder"			, { 1    , false } },
	["Agent der Stromgalder (2)"] 		= { "Agent der Stromgalder"			, { false, 2     } },
["Arcane Denial"] 						= { "Arcane Denial"					, { 1    , 2     } },
["Arcane Denial (1)"] 					= { "Arcane Denial"					, { 1    , false } },
["Arcane Denial (2)"] 					= { "Arcane Denial"					, { false, 2     } },
	["Mysteriöse Ablehnung"]		 	= { "Mysteriöse Ablehnung"			, { 1    , 2     } },
	["Mysteriöse Ablehnung (1)"] 		= { "Mysteriöse Ablehnung"			, { 1    , false } },
	["Mysteriöse Ablehnung (2)"] 		= { "Mysteriöse Ablehnung"			, { false, 2     } },
["Astrolabe"] 							= { "Astrolabe"						, { 1    , 2     } },
["Astrolabe (1)"] 						= { "Astrolabe"						, { 1    , false } },
["Astrolabe (2)"] 						= { "Astrolabe"						, { false, 2     } },
	["Astrolabium"] 					= { "Astrolabium"					, { 1    , 2     } },
	["Astrolabium (1)"] 				= { "Astrolabium"					, { 1    , false } },
	["Astrolabium (2)"] 				= { "Astrolabium"					, { false, 2     } },
["Awesome Presence"] 					= { "Awesome Presence"				, { 1    , 2     } },
["Awesome Presence (1)"] 				= { "Awesome Presence"				, { 1    , false } },
["Awesome Presence (2)"] 				= { "Awesome Presence"				, { false, 2     } },
	["Furchterregende Aura"]		 	= { "Furchterregende Aura"			, { 1    , 2     } },
	["Furchterregende Aura (1)"] 		= { "Furchterregende Aura"			, { 1    , false } },
	["Furchterregende Aura (2)"] 		= { "Furchterregende Aura"			, { false, 2     } },
["Balduvian War-Makers"] 				= { "Balduvian War-Makers"			, { 1    , 2     } },
["Balduvian War-Makers (1)"] 			= { "Balduvian War-Makers"			, { 1    , false } },
["Balduvian War-Makers (2)"] 			= { "Balduvian War-Makers"			, { false, 2     } },
	["Balduvianische Kämpfer"] 			= { "Balduvianische Kämpfer"		, { 1    , 2     } },
	["Balduvianische Kämpfer (1)"] 		= { "Balduvianische Kämpfer"		, { 1    , false } },
	["Balduvianische Kämpfer (2)"] 		= { "Balduvianische Kämpfer"		, { false, 2     } },
["Benthic Explorers"] 					= { "Benthic Explorers"				, { 1    , 2     } },
["Benthic Explorers (1)"] 				= { "Benthic Explorers"				, { 1    , false } },
["Benthic Explorers (2)"] 				= { "Benthic Explorers"				, { false, 2     } },
	["Meeresforscher"] 					= { "Meeresforscher"				, { 1    , 2     } },
	["Meeresforscher (1)"] 				= { "Meeresforscher"				, { 1    , false } },
	["Meeresforscher (2)"] 				= { "Meeresforscher"				, { false, 2     } },
["Bestial Fury"] 						= { "Bestial Fury"					, { 1    , 2     } },
["Bestial Fury (1)"] 					= { "Bestial Fury"					, { 1    , false } },
["Bestial Fury (2)"] 					= { "Bestial Fury"					, { false, 2     } },
	["Kampfinstinkt"] 					= { "Kampfinstinkt"					, { 1    , 2     } },
	["Kampfinstinkt (1)"] 				= { "Kampfinstinkt"					, { 1    , false } },
	["Kampfinstinkt (2)"] 				= { "Kampfinstinkt"					, { false, 2     } },
["Carrier Pigeons"] 					= { "Carrier Pigeons"				, { 1    , 2     } },
["Carrier Pidgeons (1)"] 				= { "Carrier Pidgeons"				, { 1    , false } },
["Carrier Pidgeons (2)"] 				= { "Carrier Pidgeons"				, { false, 2     } },
	["Brieftauben"] 					= { "Brieftauben"					, { 1    , 2     } },
	["Brieftauben (1)"] 				= { "Brieftauben"					, { 1    , false } },
	["Brieftauben (2)"] 				= { "Brieftauben"					, { false, 2     } },
["Casting of Bones"] 					= { "Casting of Bones"				, { 1    , 2     } },
["Casting of Bones (1)"] 				= { "Casting of Bones"				, { 1    , false } },
["Casting of Bones (2)"] 				= { "Casting of Bones"				, { false, 2     } },
	["Knochenorakel"] 					= { "Knochenorakel"					, { 1    , 2     } },
	["Knochenorakel (1)"] 				= { "Knochenorakel"					, { 1    , false } },
	["Knochenorakel (2)"] 				= { "Knochenorakel"					, { false, 2     } },
["Deadly Insect"] 						= { "Deadly Insect"					, { 1    , 2     } },
["Deadly Insect (1)"] 					= { "Deadly Insect"					, { 1    , false } },
["Deadly Insect (2)"] 					= { "Deadly Insect"					, { false, 2     } },
	["Killerinsekten"] 					= { "Killerinsekten"				, { 1    , 2     } },
	["Killerinsekten (1)"] 				= { "Killerinsekten"				, { 1    , false } },
	["Killerinsekten (2)"] 				= { "Killerinsekten"				, { false, 2     } },
["Elvish Ranger"] 						= { "Elvish Ranger"					, { 1    , 2     } },
["Elvish Ranger (1)"] 					= { "Elvish Ranger"					, { 1    , false } },
["Elvish Ranger (2)"] 					= { "Elvish Ranger"					, { false, 2     } },
	["Elfenwaldläufer"] 				= { "Elfenwaldläufer"				, { 1    , 2     } },
	["Elfenwaldläufer (1)"] 			= { "Elfenwaldläufer"				, { 1    , false } },
	["Elfenwaldläufer (2)"] 			= { "Elfenwaldläufer"				, { false, 2     } },
["Enslaved Scout"] 						= { "Enslaved Scout"				, { 1    , 2     } },
["Enslaved Scout (1)"] 					= { "Enslaved Scout"				, { 1    , false } },
["Enslaved Scout (2)"] 					= { "Enslaved Scout"				, { false, 2     } },
	["Unterworfener Späher"] 			= { "Unterworfener Späher"			, { 1    , 2     } },
	["Unterworfener Späher (1)"] 		= { "Unterworfener Späher"			, { 1    , false } },
	["Unterworfener Späher (2)"] 		= { "Unterworfener Späher"			, { false, 2     } },
["Errand of Duty"] 						= { "Errand of Duty"				, { 1    , 2     } },
["Errand of Duty (1)"] 					= { "Errand of Duty"				, { 1    , false } },
["Errand of Duty (2)"] 					= { "Errand of Duty"				, { false, 2     } },
	["Ruf der Pflicht"] 				= { "Ruf der Pflicht"				, { 1    , 2     } },
	["Ruf der Pflicht (1)"] 			= { "Ruf der Pflicht"				, { 1    , false } },
	["Ruf der Pflicht (2)"] 			= { "Ruf der Pflicht"				, { false, 2     } },
["False Demise"] 						= { "False Demise"					, { 1    , 2     } },
["False Demise (1)"] 					= { "False Demise"					, { 1    , false } },
["False Demise (2)"] 					= { "False Demise"					, { false, 2     } },
	["Vorgetäuschter Tod"] 				= { "Vorgetäuschter Tod"			, { 1    , 2     } },
	["Vorgetäuschter Tod (1)"] 			= { "Vorgetäuschter Tod"			, { 1    , false } },
	["Vorgetäuschter Tod (2)"] 			= { "Vorgetäuschter Tod"			, { false, 2     } },
["Feast or Famine"] 					= { "Feast or Famine"				, { 1    , 2     } },
["Feast of Famine (1)"] 				= { "Feast of Famine"				, { 1    , false } },
["Feast of Famine (2)"] 				= { "Feast of Famine"				, { false, 2     } },
	["Um Leben und Tod"] 				= { "Um Leben und Tod"				, { 1    , 2     } },
	["Um Leben und Tod (1)"] 			= { "Um Leben und Tod"				, { 1    , false } },
	["Um Leben und Tod (2)"] 			= { "Um Leben und Tod"				, { false, 2     } },
["Foresight"] 							= { "Foresight"						, { 1    , 2     } },
["Foresight (1)"] 						= { "Foresight"						, { 1    , false } },
["Foresight (2)"] 						= { "Foresight"						, { false, 2     } },
	["Vorsehung"] 						= { "Vorsehung"						, { 1    , 2     } },
	["Vorsehung (1)"] 					= { "Vorsehung"						, { 1    , false } },
	["Vorsehung (2)"] 					= { "Vorsehung"						, { false, 2     } },
["Fevered Strength"] 					= { "Fevered Strength"				, { 1    , 2     } },
["Fevered Strength (1)"] 				= { "Fevered Strength"				, { 1    , false } },
["Fevered Strength (2)"] 				= { "Fevered Strength"				, { false, 2     } },
	["Fieberstärke"] 					= { "Fieberstärke"					, { 1    , 2     } },
	["Fieberstärke (1)"] 				= { "Fieberstärke"					, { 1    , false } },
	["Fieberstärke (2)"] 				= { "Fieberstärke"					, { false, 2     } },
["Fyndhorn Druid"] 						= { "Fyndhorn Druid"				, { 1    , 2     } },
["Fyndhorn Druid (1)"] 					= { "Fyndhorn Druid"				, { 1    , false } },
["Fyndhorn Druid (2)"] 					= { "Fyndhorn Druid"				, { false, 2     } },
	["Fyndhorndruide"] 					= { "Fyndhorndruide"				, { 1    , 2     } },
	["Fyndhorndruide (1)"] 				= { "Fyndhorndruide"				, { 1    , false } },
	["Fyndhorndruide (2)"] 				= { "Fyndhorndruide"				, { false, 2     } },
["Gift of the Woods"] 					= { "Gift of the Woods"				, { 1    , 2     } },
["Gift of the Woods (1)"] 				= { "Gift of the Woods"				, { 1    , false } },
["Gift of the Woods (2)"] 				= { "Gift of the Woods"				, { false, 2     } },
	["Geschenk des Waldes"] 			= { "Geschenk des Waldes"			, { 1    , 2     } },
	["Geschenk des Waldes (1)"] 		= { "Geschenk des Waldes"			, { 1    , false } },
	["Geschenk des Waldes (2)"] 		= { "Geschenk des Waldes"			, { false, 2     } },
["Gorilla Berserkers"] 					= { "Gorilla Berserkers"			, { 1    , 2     } },
["Gorilla Berserkers (1)"] 				= { "Gorilla Berserkers"			, { 1    , false } },
["Gorilla Berserkers (2)"] 				= { "Gorilla Berserkers"			, { false, 2     } },
	["Rasende Gorillas"] 				= { "Rasende Gorillas"				, { 1    , 2     } },
	["Rasende Gorillas (1)"] 			= { "Rasende Gorillas"				, { 1    , false } },
	["Rasende Gorillas (2)"] 			= { "Rasende Gorillas"				, { false, 2     } },
["Gorilla Chieftain"] 					= { "Gorilla Chieftain"				, { 1    , 2     } },
["Gorilla Chieftain (1)"] 				= { "Gorilla Chieftain"				, { 1    , false } },
["Gorilla Chieftain (2)"] 				= { "Gorilla Chieftain"				, { false, 2     } },
	["Gorillahäuptling"] 				= { "Gorillahäuptling"				, { 1    , 2     } },
	["Gorillahäuptling (1)"] 			= { "Gorillahäuptling"				, { 1    , false } },
	["Gorillahäuptling (2)"]	 		= { "Gorillahäuptling"				, { false, 2     } },
["Gorilla Shaman"] 						= { "Gorilla Shaman"				, { 1    , 2     } },
["Gorilla Shaman (1)"] 					= { "Gorilla Shaman"				, { 1    , false } },
["Gorilla Shaman (2)"] 					= { "Gorilla Shaman"				, { false, 2     } },
	["Gorillaschamane"] 				= { "Gorillaschamane"				, { 1    , 2     } },
	["Gorillaschamane (1)"] 			= { "Gorillaschamane"				, { 1    , false } },
	["Gorillaschamane (2)"] 			= { "Gorillaschamane"				, { false, 2     } },
["Gorilla War Cry"] 					= { "Gorilla War Cry"				, { 1    , 2     } },
["Gorilla War Cry (1)"] 				= { "Gorilla War Cry"				, { 1    , false } },
["Gorilla War Cry (2)"] 				= { "Gorilla War Cry"				, { false, 2     } },
	["Schlachtruf der Gorillas"]		= { "Schlachtruf der Gorillas"		, { 1    , 2     } },
	["Schlachtruf der Gorillas (1)"] 	= { "Schlachtruf der Gorillas"		, { 1    , false } },
	["Schlachtruf der Gorillas (2)"] 	= { "Schlachtruf der Gorillas"		, { false, 2     } },
["Guerrilla Tactics"] 					= { "Guerrilla Tactics"				, { 1    , 2     } },
["Guerrilla Tactics (1)"] 				= { "Guerrilla Tactics"				, { 1    , false } },
["Guerrilla Tactics (2)"]	 			= { "Guerrilla Tactics"				, { false, 2     } },
	["Guerillataktik"] 					= { "Guerillataktik"				, { 1    , 2     } },
	["Guerillataktik (1)"] 				= { "Guerillataktik"				, { 1    , false } },
	["Guerillataktik (2)"] 				= { "Guerillataktik"				, { false, 2     } },
["Insidious Bookworms"] 				= { "Insidious Bookworms"			, { 1    , 2     } },
["Insidious Bookworms (1)"] 			= { "Insidious Bookworms"			, { 1    , false } },
["Insidious Bookworms (2)"] 			= { "Insidious Bookworms"			, { false, 2     } },
	["Heimtückische Bücherwürmer"]		= { "Heimtückische Bücherwürmer"	, { 1    , 2     } },
	["Heimtückische Bücherwürmer (1)"]	= { "Heimtückische Bücherwürmer"	, { 1    , false } },
	["Heimtückische Bücherwürmer (2)"] 	= { "Heimtückische Bücherwürmer"	, { false, 2     } },
["Kjeldoran Escort"] 					= { "Kjeldoran Escort"				, { 1    , 2     } },
["Kjeldoran Escort (1)"] 				= { "Kjeldoran Escort"				, { 1    , false } },
["Kjeldoran Escort (2)"] 				= { "Kjeldoran Escort"				, { false, 2     } },
	["Kjeldoranische Eskorte"]		 	= { "Kjeldoranische Eskorte"		, { 1    , 2     } },
	["Kjeldoranische Eskorte (1)"] 		= { "Kjeldoranische Eskorte"		, { 1    , false } },
	["Kjeldoranische Eskorte (2)"] 		= { "Kjeldoranische Eskorte"		, { false, 2     } },
["Kjeldoran Pride"] 					= { "Kjeldoran Pride"				, { 1    , 2     } },
["Kjeldoran Pride (1)"] 				= { "Kjeldoran Pride"				, { 1    , false } },
["Kjeldoran Pride (2)"] 				= { "Kjeldoran Pride"				, { false, 2     } },
	["Kjeldors Stolz"] 					= { "Kjeldors Stolz"				, { 1    , 2     } },
	["Kjeldors Stolz (1)"] 				= { "Kjeldors Stolz"				, { 1    , false } },
	["Kjeldors Stolz (2)"] 				= { "Kjeldors Stolz"				, { false, 2     } },
["Lat-Nam's Legacy"] 					= { "Lat-Nam's Legacy"				, { 1    , 2     } },
["Lat-Nam's Legacy (1)"] 				= { "Lat-Nam's Legacy"				, { 1    , false } },
["Lat-Nam's Legacy (2)"] 				= { "Lat-Nam's Legacy"				, { false, 2     } },
	["Lat-Nams Erbe"] 					= { "Lat-Nams Erbe"					, { 1    , 2     } },
	["Lat-Nams Erbe (1)"] 				= { "Lat-Nams Erbe"					, { 1    , false } },
	["Lat-Nams Erbe (2)"] 				= { "Lat-Nams Erbe"					, { false, 2     } },
["Lim-Dûl's High Guard"]	 			= { "Lim-Dûl's High Guard"			, { 1    , 2     } },
["Lim-Dûl's High Guard (1)"] 			= { "Lim-Dûl's High Guard"			, { 1    , false } },
["Lim-Dûl's High Guard (2)"] 			= { "Lim-Dûl's High Guard"			, { false, 2     } },
	["Lim-Dûls Ehrengarde"]	 			= { "Lim-Dûls Ehrengarde"			, { 1    , 2     } },
	["Lim-Dûls Ehrengarde (1)"] 		= { "Lim-Dûls Ehrengarde"			, { 1    , false } },
	["Lim-Dûls Ehrengarde (2)"] 		= { "Lim-Dûls Ehrengarde"			, { false, 2     } },
["Martyrdom"] 							= { "Martyrdom"						, { 1    , 2     } },
["Martyrdom (1)"] 						= { "Martyrdom"						, { 1    , false } },
["Martyrdom (2)"] 						= { "Martyrdom"						, { false, 2     } },
	["Martyrium"] 						= { "Martyrium"						, { 1    , 2     } },
	["Martyrium (1)"] 					= { "Martyrium"						, { 1    , false } },
	["Martyrium (2)"] 					= { "Martyrium"						, { false, 2     } },
["Noble Steeds"] 						= { "Noble Steeds"					, { 1    , 2     } },
["Noble Steeds (1)"] 					= { "Noble Steeds"					, { 1    , false } },
["Noble Steeds (2)"] 					= { "Noble Steeds"					, { false, 2     } },
	["Edle Rösser"] 					= { "Edle Rösser"					, { 1    , 2     } },
	["Edle Rösser (1)"] 				= { "Edle Rösser"					, { 1    , false } },
	["Edle Rösser (2)"] 				= { "Edle Rösser"					, { false, 2     } },
["Phantasmal Fiend"] 					= { "Phantasmal Fiend"				, { 1    , 2     } },
["Phantasmal Fiend (1)"] 				= { "Phantasmal Fiend"				, { 1    , false } },
["Phantasmal Fiend (2)"] 				= { "Phantasmal Fiend"				, { false, 2     } },
	["Traumunhold"] 					= { "Traumunhold"					, { 1    , 2     } },
	["Traumunhold (1)"] 				= { "Traumunhold"					, { 1    , false } },
	["Traumunhold (2)"] 				= { "Traumunhold"					, { false, 2     } },
["Phyrexian Boon"] 						= { "Phyrexian Boon"				, { 1    , 2     } },
["Phyrexian Boon (1)"] 					= { "Phyrexian Boon"				, { 1    , false } },
["Phyrexian Boon (2)"] 					= { "Phyrexian Boon"				, { false, 2     } },
	["Phyrexianischer Segen"]		 	= { "Phyrexianischer Segen"			, { 1    , 2     } },
	["Phyrexianischer Segen (1)"] 		= { "Phyrexianischer Segen"			, { 1    , false } },
	["Phyrexianischer Segen (2)"] 		= { "Phyrexianischer Segen"			, { false, 2     } },
["Phyrexian War Beast"] 				= { "Phyrexian War Beast"			, { 1    , 2     } },
["Phyrexian War Beast (1)"] 			= { "Phyrexian War Beast"			, { 1    , false } },
["Phyrexian War Beast (2)"] 			= { "Phyrexian War Beast"			, { false, 2     } },
	["Phyrexianische Kriegsbestie"]		= { "Phyrexianische Kriegsbestie"	, { 1    , 2     } },
	["Phyrexianische Kriegsbestie (1)"] = { "Phyrexianische Kriegsbestie"	, { 1    , false } },
	["Phyrexianische Kriegsbestie (2)"] = { "Phyrexianische Kriegsbestie"	, { false, 2     } },
["Reprisal"] 							= { "Reprisal"						, { 1    , 2     } },
["Reprisal (1)"] 						= { "Reprisal"						, { 1    , false } },
["Reprisal (2)"] 						= { "Reprisal"						, { false, 2     } },
	["Revolte"] 						= { "Revolte"						, { 1    , 2     } },
	["Revolte (1)"] 					= { "Revolte"						, { 1    , false } },
	["Revolte (2)"] 					= { "Revolte"						, { false, 2     } },
["Royal Herbalist"] 					= { "Royal Herbalist"				, { 1    , 2     } },
["Royal Herbalist (1)"] 				= { "Royal Herbalist"				, { 1    , false } },
["Royal Herbalist (2)"] 				= { "Royal Herbalist"				, { false, 2     } },
	["Königlicher Kräuterkundler"]		= { "Königlicher Kräuterkundler"	, { 1    , 2     } },
	["Königlicher Kräuterkundler (1)"] 	= { "Königlicher Kräuterkundler"	, { 1    , false } },
	["Königlicher Kräuterkundler (2)"] 	= { "Königlicher Kräuterkundler"	, { false, 2     } },
["Reinforcements"] 						= { "Reinforcements"				, { 1    , 2     } },
["Reinforcements (1)"] 					= { "Reinforcements"				, { 1    , false } },
["Reinforcements (2)"] 					= { "Reinforcements"				, { false, 2     } },
	["Verstärkungen"] 					= { "Verstärkungen"					, { 1    , 2     } },
	["Verstärkungen (1)"] 				= { "Verstärkungen"					, { 1    , false } },
	["Verstärkungen (2)"] 				= { "Verstärkungen"					, { false, 2     } },
["Stench of Decay"] 					= { "Stench of Decay"				, { 1    , 2     } },
["Stench of Decay (1)"] 				= { "Stench of Decay"				, { 1    , false } },
["Stench of Decay (2)"] 				= { "Stench of Decay"				, { false, 2     } },
	["Verwesungsgestank"] 				= { "Verwesungsgestank"				, { 1    , 2     } },
	["Verwesungsgestank (1)"] 			= { "Verwesungsgestank"				, { 1    , false } },
	["Verwesungsgestank (2)"] 			= { "Verwesungsgestank"				, { false, 2     } },
["Storm Shaman"]	 					= { "Storm Shaman"					, { 1    , 2     } },
["Storm Shaman (1)"] 					= { "Storm Shaman"					, { 1    , false } },
["Storm Shaman (2)"] 					= { "Storm Shaman"					, { false, 2     } },
	["Sturmschamane"]	 				= { "Sturmschamane"					, { 1    , 2     } },
	["Sturmschamane (1)"] 				= { "Sturmschamane"					, { 1    , false } },
	["Sturmschamane (2)"] 				= { "Sturmschamane"					, { false, 2     } },
["Storm Crow"] 							= { "Storm Crow"					, { 1    , 2     } },
["Storm Crow (1)"] 						= { "Storm Crow"					, { 1    , false } },
["Storm Crow (2)"] 						= { "Storm Crow"					, { false, 2     } },
	["Sturmkrähe"] 						= { "Sturmkrähe"					, { 1    , 2     } },
	["Sturmkrähe (1)"] 					= { "Sturmkrähe"					, { 1    , false } },
	["Sturmkrähe (2)"] 					= { "Sturmkrähe"					, { false, 2     } },
["Soldevi Adnate"]	 					= { "Soldevi Adnate"				, { 1    , 2     } },
["Soldevi Adnate (1)"] 					= { "Soldevi Adnate"				, { 1    , false } },
["Soldevi Adnate (2)"] 					= { "Soldevi Adnate"				, { false, 2     } },
	["Soldevischer Sektierer"]			= { "Soldevischer Sektierer"		, { 1    , 2     } },
	["Soldevischer Sektierer (1)"] 		= { "Soldevischer Sektierer"		, { 1    , false } },
	["Soldevischer Sektierer (2)"] 		= { "Soldevischer Sektierer"		, { false, 2     } },
["Soldevi Heretic"] 					= { "Soldevi Heretic"				, { 1    , 2     } },
["Soldevi Heretic (1)"] 				= { "Soldevi Heretic"				, { 1    , false } },
["Soldevi Heretic (2)"] 				= { "Soldevi Heretic"				, { false, 2     } },
	["Soldevischer Ketzer"] 			= { "Soldevischer Ketzer"			, { 1    , 2     } },
	["Soldevischer Ketzer (1)"] 		= { "Soldevischer Ketzer"			, { 1    , false } },
	["Soldevischer Ketzer (2)"] 		= { "Soldevischer Ketzer"			, { false, 2     } },
["Soldevi Sage"] 						= { "Soldevi Sage"					, { 1    , 2     } },
["Soldevi Sage (1)"] 					= { "Soldevi Sage"					, { 1    , false } },
["Soldevi Sage (2)"] 					= { "Soldevi Sage"					, { false, 2     } },
	["Soldevischer Weiser"] 			= { "Soldevischer Weiser"			, { 1    , 2     } },
	["Soldevischer Weiser (1)"] 		= { "Soldevischer Weiser"			, { 1    , false } },
	["Soldevischer Weiser (2)"] 		= { "Soldevischer Weiser"			, { false, 2     } },
["Soldevi Sentry"] 						= { "Soldevi Sentry"				, { 1    , 2     } },
["Soldevi Sentry (1)"] 					= { "Soldevi Sentry"				, { 1    , false } },
["Soldevi Sentry (2)"] 					= { "Soldevi Sentry"				, { false, 2     } },
	["Soldevischer Wachposten"] 		= { "Soldevischer Wachposten"		, { 1    , 2     } },
	["Soldevischer Wachposten (1)"] 	= { "Soldevischer Wachposten"		, { 1    , false } },
	["Soldevischer Wachposten (2)"] 	= { "Soldevischer Wachposten"		, { false, 2     } },
["Soldevi Steam Beast"] 				= { "Soldevi Steam Beast"			, { 1    , 2     } },
["Soldevi Steam Beast (1)"] 			= { "Soldevi Steam Beast"			, { 1    , false } },
["Soldevi Steam Beast (2)"] 			= { "Soldevi Steam Beast"			, { false, 2     } },
	["Soldevische Dampfmaschine"]		= { "Soldevische Dampfmaschine"		, { 1    , 2     } },
	["Soldevische Dampfmaschine (1)"] 	= { "Soldevische Dampfmaschine"		, { 1    , false } },
	["Soldevische Dampfmaschine (2)"] 	= { "Soldevische Dampfmaschine"		, { false, 2     } },
["Swamp Mosquito"] 						= { "Swamp Mosquito"				, { 1    , 2     } },
["Swamp Mosquito (1)"] 					= { "Swamp Mosquito"				, { 1    , false } },
["Swamp Mosquito (2)"] 					= { "Swamp Mosquito"				, { false, 2     } },
	["Sumpfmoskito"] 					= { "Sumpfmoskito"					, { 1    , 2     } },
	["Sumpfmoskito (1)"] 				= { "Sumpfmoskito"					, { 1    , false } },
	["Sumpfmoskito (2)"] 				= { "Sumpfmoskito"					, { false, 2     } },
["Taste of Paradise"] 					= { "Taste of Paradise"				, { 1    , 2     } },
["Taste of Paradise (1)"] 				= { "Taste of Paradise"				, { 1    , false } },
["Taste of Paradise (2)"] 				= { "Taste of Paradise"				, { false, 2     } },
	["Vorgeschmack des Paradieses"]		= { "Vorgeschmack des Paradieses"	, { 1    , 2     } },
	["Vorgeschmack des Paradieses (1)"] = { "Vorgeschmack des Paradieses"	, { 1    , false } },
	["Vorgeschmack des Paradieses (2)"] = { "Vorgeschmack des Paradieses"	, { false, 2     } },
["Undergrowth"] 						= { "Undergrowth"					, { 1    , 2     } },
["Undergrowth (1)"] 					= { "Undergrowth"					, { 1    , false } },
["Undergrowth (2)"] 					= { "Undergrowth"					, { false, 2     } },
	["Unterholz"] 						= { "Unterholz"						, { 1    , 2     } },
	["Unterholz (1)"] 					= { "Unterholz"						, { 1    , false } },
	["Unterholz (2)"] 					= { "Unterholz"						, { false, 2     } },
["Varchild's Crusader"] 				= { "Varchild's Crusader"			, { 1    , 2     } },
["Varchild's Crusader (1)"] 			= { "Varchild's Crusader"			, { 1    , false } },
["Varchild's Crusader (2)"] 			= { "Varchild's Crusader"			, { false, 2     } },
	["Varchilds Kreuzritter"]		 	= { "Varchilds Kreuzritter"			, { 1    , 2     } },
	["Varchilds Kreuzritter (1)"] 		= { "Varchilds Kreuzritter"			, { 1    , false } },
	["Varchilds Kreuzritter (2)"] 		= { "Varchilds Kreuzritter"			, { false, 2     } },
["Veteran's Voice"] 					= { "Veteran's Voice"				, { 1    , 2     } },
["Veteran's Voice (1)"] 				= { "Veteran's Voice"				, { 1    , false } },
["Veteran's Voice (2)"] 				= { "Veteran's Voice"				, { false, 2     } },
	["Stimme des Veteranen"] 			= { "Stimme des Veteranen"			, { 1    , 2     } },
	["Stimme des Veteranen (1)"] 		= { "Stimme des Veteranen"			, { 1    , false } },
	["Stimme des Veteranen (2)"] 		= { "Stimme des Veteranen"			, { false, 2     } },
["Viscerid Armor"] 						= { "Viscerid Armor"				, { 1    , 2     } },
["Viscerid Armor (1)"] 					= { "Viscerid Armor"				, { 1    , false } },
["Viscerid Armor (2)"] 					= { "Viscerid Armor"				, { false, 2     } },
	["Visceridenpanzer"] 				= { "Visceridenpanzer"				, { 1    , 2     } },
	["Visceridenpanzer (1)"] 			= { "Visceridenpanzer"				, { 1    , false } },
	["Visceridenpanzer (2)"] 			= { "Visceridenpanzer"				, { false, 2     } },
["Whip Vine"] 							= { "Whip Vine"						, { 1    , 2     } },
["Whip Vine (1)"] 						= { "Whip Vine"						, { 1    , false } },
["Whip Vine (2)"] 						= { "Whip Vine"						, { false, 2     } },
	["Kletterranken"] 					= { "Kletterranken"					, { 1    , 2     } },
	["Kletterranken (1)"] 				= { "Kletterranken"					, { 1    , false } },
	["Kletterranken (2)"] 				= { "Kletterranken"					, { false, 2     } },
["Wild Aesthir"] 						= { "Wild Aesthir"					, { 1    , 2     } },
["Wild Aesthir (1)"] 					= { "Wild Aesthir"					, { 1    , false } },
["Wild Aesthir (2)"] 					= { "Wild Aesthir"					, { false, 2     } },
	["Wilder Aesthir"] 					= { "Wilder Aesthir"				, { 1    , 2     } },
	["Wilder Aesthir (1)"] 				= { "Wilder Aesthir"				, { 1    , false } },
	["Wilder Aesthir (2)"] 				= { "Wilder Aesthir"				, { false, 2     } },
["Yavimaya Ancients"] 					= { "Yavimaya Ancients"				, { 1    , 2     } },
["Yavimaya Ancients (1)"] 				= { "Yavimaya Ancients"				, { 1    , false } },
["Yavimaya Ancients (2)"] 				= { "Yavimaya Ancients"				, { false, 2     } },
	["Ahnen aus Yavimaya"] 				= { "Ahnen aus Yavimaya"			, { 1    , 2     } },
	["Ahnen aus Yavimaya (1)"] 			= { "Ahnen aus Yavimaya"			, { 1    , false } },
	["Ahnen aus Yavimaya (2)"] 			= { "Ahnen aus Yavimaya"			, { false, 2     } },
	},
},
[210] = { name="Homelands",
	cardcount={ reg = 140, tok =  0 },
	variants={
["Abbey Matron"] 					= { "Abbey Matron"				, { 1    , 2     } },
["Abbey Matron (1)"] 				= { "Abbey Matron"				, { 1    , false } },
["Abbey Matron (2)"] 				= { "Abbey Matron"				, { false, 2     } },
	["Oberin der Abtei"] 			= { "Oberin der Abtei"			, { 1    , 2     } },
	["Oberin der Abtei (1)"] 		= { "Oberin der Abtei"			, { 1    , false } },
	["Oberin der Abtei (2)"] 		= { "Oberin der Abtei"			, { false, 2     } },
["Aliban's Tower"] 					= { "Aliban's Tower"			, { 1    , 2     } },
["Aliban's Tower (1)"] 				= { "Aliban's Tower"			, { 1    , false } },
["Aliban's Tower (2)"] 				= { "Aliban's Tower"			, { false, 2     } },
	["Armax' Turm"] 				= { "Armax' Turm"				, { 1    , 2     } },
	["Armax' Turm (1)"] 			= { "Armax' Turm"				, { 1    , false } },
	["Armax' Turm (2)"] 			= { "Armax' Turm"				, { false, 2     } },
["Ambush Party"] 					= { "Ambush Party"				, { 1    , 2     } },
["Ambush Party (1)"] 				= { "Ambush Party"				, { 1    , false } },
["Ambush Party (2)"] 				= { "Ambush Party"				, { false, 2     } },
	["Lauernde Räuber"] 			= { "Lauernde Räuber"			, { 1    , 2     } },
	["Lauernde Räuber (1)"] 		= { "Lauernde Räuber"			, { 1    , false } },
	["Lauernde Räuber (2)"] 		= { "Lauernde Räuber"			, { false, 2     } },
["Anaba Bodyguard"] 				= { "Anaba Bodyguard"			, { 1    , 2     } },
["Anaba Bodyguard (1)"] 			= { "Anaba Bodyguard"			, { 1    , false } },
["Anaba Bodyguard (2)"] 			= { "Anaba Bodyguard"			, { false, 2     } },
	["Anaba-Leibwächter"] 			= { "Anaba-Leibwächter"			, { 1    , 2     } },
	["Anaba-Leibwächter (1)"] 		= { "Anaba-Leibwächter"			, { 1    , false } },
	["Anaba-Leibwächter (2)"] 		= { "Anaba-Leibwächter"			, { false, 2     } },
["Anaba Shaman"] 					= { "Anaba Shaman"				, { 1    , 2     } },
["Anaba Shaman (1)"] 				= { "Anaba Shaman"				, { 1    , false } },
["Anaba Shaman (2)"] 				= { "Anaba Shaman"				, { false, 2     } },
	["Anaba-Schamane"] 				= { "Anaba-Schamane"			, { 1    , 2     } },
	["Anaba-Schamane (1)"] 			= { "Anaba-Schamane"			, { 1    , false } },
	["Anaba-Schamane (2)"] 			= { "Anaba-Schamane"			, { false, 2     } },
["Aysen Bureaucrats"] 				= { "Aysen Bureaucrats"			, { 1    , 2     } },
["Aysen Bureaucrats (1)"] 			= { "Aysen Bureaucrats"			, { 1    , false } },
["Aysen Bureaucrats (2)"] 			= { "Aysen Bureaucrats"			, { false, 2     } },
	["Aysenischer Bürokrat"] 		= { "Aysenischer Bürokrat"		, { 1    , 2     } },
	["Aysenischer Bürokrat (1)"] 	= { "Aysenischer Bürokrat"		, { 1    , false } },
	["Aysenischer Bürokrat (2)"] 	= { "Aysenischer Bürokrat"		, { false, 2     } },
["Carapace"] 						= { "Carapace"					, { 1    , 2     } },
["Carapace (1)"] 					= { "Carapace"					, { 1    , false } },
["Carapace (2)"] 					= { "Carapace"					, { false, 2     } },
	["Rückenpanzer"] 				= { "Rückenpanzer"				, { 1    , 2     } },
	["Rückenpanzer (1)"] 			= { "Rückenpanzer"				, { 1    , false } },
	["Rückenpanzer (2)"] 			= { "Rückenpanzer"				, { false, 2     } },
["Cemetery Gate"] 					= { "Cemetery Gate"				, { 1    , 2     } },
["Cemetery Gate (1)"] 				= { "Cemetery Gate"				, { 1    , false } },
["Cemetery Gate (2)"] 				= { "Cemetery Gate"				, { false, 2     } },
	["Friedhofspforte"]	 			= { "Friedhofspforte"			, { 1    , 2     } },
	["Friedhofspforte (1)"] 		= { "Friedhofspforte"			, { 1    , false } },
	["Friedhofspforte (2)"] 		= { "Friedhofspforte"			, { false, 2     } },
["Dark Maze"] 						= { "Dark Maze"					, { 1    , 2     } },
["Dark Maze (1)"] 					= { "Dark Maze"					, { 1    , false } },
["Dark Maze (2)"] 					= { "Dark Maze"					, { false, 2     } },
	["Dunkler Irrgarten"] 			= { "Dunkler Irrgarten"			, { 1    , 2     } },
	["Dunkler Irrgarten (1)"] 		= { "Dunkler Irrgarten"			, { 1    , false } },
	["Dunkler Irrgarten (2)"] 		= { "Dunkler Irrgarten"			, { false, 2     } },
["Dry Spell"] 						= { "Dry Spell"					, { 1    , 2     } },
["Dry Spell (1)"] 					= { "Dry Spell"					, { 1    , false } },
["Dry Spell (2)"] 					= { "Dry Spell"					, { false, 2     } },
	["Trockenheit"]					= { "Trockenheit"				, { 1    , 2     } },
	["Trockenheit (1)"] 			= { "Trockenheit"				, { 1    , false } },
	["Trockenheit (2)"] 			= { "Trockenheit"				, { false, 2     } },
["Dwarven Trader"] 					= { "Dwarven Trader"			, { 1    , 2     } },
["Dwarven Trader (1)"] 				= { "Dwarven Trader"			, { 1    , false } },
["Dwarven Trader (2)"] 				= { "Dwarven Trader"			, { false, 2     } },
	["Zwergenkaufmann"]	 			= { "Zwergenkaufmann"			, { 1    , 2     } },
	["Zwergenkaufmann (1)"] 		= { "Zwergenkaufmann"			, { 1    , false } },
	["Zwergenkaufmann (2)"] 		= { "Zwergenkaufmann"			, { false, 2     } },
["Feast of the Unicorn"] 			= { "Feast of the Unicorn"		, { 1    , 2     } },
["Feast of the Unicorn (1)"] 		= { "Feast of the Unicorn"		, { 1    , false } },
["Feast of the Unicorn (2)"] 		= { "Feast of the Unicorn"		, { false, 2     } },
	["Einhornschlachtfest"] 		= { "Einhornschlachtfest"		, { 1    , 2     } },
	["Einhornschlachtfest (1)"] 	= { "Einhornschlachtfest"		, { 1    , false } },
	["Einhornschlachtfest (2)"] 	= { "Einhornschlachtfest"		, { false, 2     } },
["Folk of An-Havva"] 				= { "Folk of An-Havva"			, { 1    , 2     } },
["Folk of An-Havva (1)"] 			= { "Folk of An-Havva"			, { 1    , false } },
["Folk of An-Havva (2)"] 			= { "Folk of An-Havva"			, { false, 2     } },
	["Bewohner von An-Havva"]	 	= { "Bewohner von An-Havva"		, { 1    , 2     } },
	["Bewohner von An-Havva (1)"] 	= { "Bewohner von An-Havva"		, { 1    , false } },
	["Bewohner von An-Havva (2)"] 	= { "Bewohner von An-Havva"		, { false, 2     } },
["Giant Albatross"] 				= { "Giant Albatross"			, { 1    , 2     } },
["Giant Albatross (1)"] 			= { "Giant Albatross"			, { 1    , false } },
["Giant Albatross (2)"] 			= { "Giant Albatross"			, { false, 2     } },
	["Riesenalbatros"] 				= { "Riesenalbatros"			, { 1    , 2     } },
	["Riesenalbatros (1)"] 			= { "Riesenalbatros"			, { 1    , false } },
	["Riesenalbatros (2)"] 			= { "Riesenalbatros"			, { false, 2     } },
["Hungry Mist"] 					= { "Hungry Mist"				, { 1    , 2     } },
["Hungry Mist (1)"] 				= { "Hungry Mist"				, { 1    , false } },
["Hungry Mist (2)"] 				= { "Hungry Mist"				, { false, 2     } },
	["Hungrige Nebelschwaden"]	 	= { "Hungrige Nebelschwaden"	, { 1    , 2     } },
	["Hungrige Nebelschwaden (1)"]	= { "Hungrige Nebelschwaden"	, { 1    , false } },
	["Hungrige Nebelschwaden (2)"]	= { "Hungrige Nebelschwaden"	, { false, 2     } },
["Labyrinth Minotaur"] 				= { "Labyrinth Minotaur"		, { 1    , 2     } },
["Labyrinth Minotaur (1)"] 			= { "Labyrinth Minotaur"		, { 1    , false } },
["Labyrinth Minotaur (2)"] 			= { "Labyrinth Minotaur"		, { false, 2     } },
	["Labyrinthminotaurus"] 		= { "Labyrinthminotaurus"		, { 1    , 2     } },
	["Labyrinthminotaurus (1)"] 	= { "Labyrinthminotaurus"		, { 1    , false } },
	["Labyrinthminotaurus (2)"] 	= { "Labyrinthminotaurus"		, { false, 2     } },
["Memory Lapse"] 					= { "Memory Lapse"				, { 1    , 2     } },
["Memory Lapse (1)"]	 			= { "Memory Lapse"				, { 1    , false } },
["Memory Lapse (2)"] 				= { "Memory Lapse"				, { false, 2     } },
	["Gedächtnislücke"] 			= { "Gedächtnislücke"			, { 1    , 2     } },
	["Gedächnislücke (1)"] 			= { "Gedächnislücke"			, { 1    , false } },
	["Gedächnislücke (2)"]	 		= { "Gedächnislücke"			, { false, 2     } },
["Mesa Falcon"] 					= { "Mesa Falcon"				, { 1    , 2     } },
["Mesa Falcon (1)"] 				= { "Mesa Falcon"				, { 1    , false } },
["Mesa Falcon (2)"]	 				= { "Mesa Falcon"				, { false, 2     } },
	["Mesafalken"] 					= { "Mesafalken"				, { 1    , 2     } },
	["Mesafalken (1)"] 				= { "Mesafalken"				, { 1    , false } },
	["Mesafalken (2)"] 				= { "Mesafalken"				, { false, 2     } },
["Reef Pirates"] 					= { "Reef Pirates"				, { 1    , 2     } },
["Reef Pirates (1)"] 				= { "Reef Pirates"				, { 1    , false } },
["Reef Pirates (2)"] 				= { "Reef Pirates"				, { false, 2     } },
	["Riffpiraten"] 				= { "Riffpiraten"				, { 1    , 2     } },
	["Riffpiraten (1)"] 			= { "Riffpiraten"				, { 1    , false } },
	["Riffpiraten (2)"] 			= { "Riffpiraten"				, { false, 2     } },
["Samite Alchemist"] 				= { "Samite Alchemist"			, { 1    , 2     } },
["Samite Alchemist (1)"] 			= { "Samite Alchemist"			, { 1    , false } },
["Samite Alchemist (2)"] 			= { "Samite Alchemist"			, { false, 2     } },
	["Samitischer Alchimist"]	 	= { "Samitischer Alchimist"		, { 1    , 2     } },
	["Samitischer Alchimist (1)"] 	= { "Samitischer Alchimist"		, { 1    , false } },
	["Samitischer Alchimist (2)"] 	= { "Samitischer Alchimist"		, { false, 2     } },
["Shrink"] 							= { "Shrink"					, { 1    , 2     } },
["Shrink (1)"]	 					= { "Shrink"					, { 1    , false } },
["Shrink (2)"] 						= { "Shrink"					, { false, 2     } },
	["Schrumpfen"] 					= { "Schrumpfen"				, { 1    , 2     } },
	["Schrumpfen (1)"] 				= { "Schrumpfen"				, { 1    , false } },
	["Schrumpfen (2)"] 				= { "Schrumpfen"				, { false, 2     } },
["Sengir Bats"] 					= { "Sengir Bats"				, { 1    , 2     } },
["Sengir Bats (1)"] 				= { "Sengir Bats"				, { 1    , false } },
["Sengir Bats (2)"] 				= { "Sengir Bats"				, { false, 2     } },
	["Sengirs Fledermäuse"] 		= { "Sengirs Fledermäuse"		, { 1    , 2     } },
	["Sengirs Fledermäuse (1)"] 	= { "Sengirs Fledermäuse"		, { 1    , false } },
	["Sengirs Fledermäuse (2)"] 	= { "Sengirs Fledermäuse"		, { false, 2     } },
["Torture"] 						= { "Torture"					, { 1    , 2     } },
["Torture (1)"] 					= { "Torture"					, { 1    , false } },
["Torture (2)"] 					= { "Torture"					, { false, 2     } },
	["Folterung"] 					= { "Folterung"					, { 1    , 2     } },
	["Folterung (1)"]	 			= { "Folterung"					, { 1    , false } },
	["Folterung (2)"] 				= { "Folterung"					, { false, 2     } },
["Trade Caravan"] 					= { "Trade Caravan"				, { 1    , 2     } },
["Trade Caravan (1)"]	 			= { "Trade Caravan"				, { 1    , false } },
["Trade Caravan (2)"] 				= { "Trade Caravan"				, { false, 2     } },
	["Handelskarawane"] 			= { "Handelskarawane"			, { 1    , 2     } },
	["Handelskarawane (1)"] 		= { "Handelskarawane"			, { 1    , false } },
	["Handelskarawane (2)"] 		= { "Handelskarawane"			, { false, 2     } },
["Willow Faerie"]	 				= { "Willow Faerie"				, { 1    , 2     } },
["Willow Faerie (1)"] 				= { "Willow Faerie"				, { 1    , false } },
["Willow Faerie (2)"] 				= { "Willow Faerie"				, { false, 2     } },
	["Weidenfee"] 					= { "Weidenfee"					, { 1    , 2     } },
	["Weidenfee (1)"]		 		= { "Weidenfee"					, { 1    , false } },
	["Weidenfee (2)"] 				= { "Weidenfee"					, { false, 2     } },
	},
},
[190] = { name="Ice Age",
	cardcount={ reg = 383, tok =  0 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3     } },
["Plains (1)"]					= { "Plains"	, { 1    , false, false } },
["Plains (2)"]					= { "Plains"	, { false, 2    , false } },
["Plains (3)"]					= { "Plains"	, { false, false, 3     } },
["Island (1)"]					= { "Island"	, { 1    , false, false } },
["Island (2)"]					= { "Island"	, { false, 2    , false } },
["Island (3)"]					= { "Island"	, { false, false, 3     } },
["Swamp (1)"]					= { "Swamp"		, { 1    , false, false } },
["Swamp (2)"]					= { "Swamp"		, { false, 2    , false } },
["Swamp (3)"]					= { "Swamp"		, { false, false, 3     } },
["Mountain (1)"]				= { "Mountain"	, { 1    , false, false } },
["Mountain (2)"]				= { "Mountain"	, { false, 2    , false } },
["Mountain (3)"]				= { "Mountain"	, { false, false, 3     } },
["Forest (1)"]					= { "Forest"	, { 1    , false, false } },
["Forest (2)"]					= { "Forest"	, { false, 2    , false } },
["Forest (3)"]					= { "Forest"	, { false, false, 3     } },
	},
},
[170] = { name="Fallen Empires",
	cardcount={ reg = 187, tok =  0 },
	variants={
["Armor Thrull"]	 				= { "Armor Thrull"					, { 1    , 2    , 3    , 4     } },
["Armor Thrull (1)"]	 			= { "Armor Thrull"					, { 1    , false, false, false } },
["Armor Thrull (2)"] 				= { "Armor Thrull"					, { false, 2    , false, false } },
["Armor Thrull (3)"] 				= { "Armor Thrull"					, { false, false, 3    , false } },
["Armor Thrull (4)"] 				= { "Armor Thrull"					, { false, false, false, 4     } },
["Basal Thrull"] 					= { "Basal Thrull"					, { 1    , 2    , 3    , 4     } },
["Basal Thrull (1)"]	 			= { "Basal Thrull"					, { 1    , false, false, false } },
["Basal Thrull (2)"] 				= { "Basal Thrull"					, { false, 2    , false, false } },
["Basal Thrull (3)"] 				= { "Basal Thrull"					, { false, false, 3    , false } },
["Basal Thrull (4)"] 				= { "Basal Thrull"					, { false, false, false, 4     } },
["Brassclaw Orcs"] 					= { "Brassclaw Orcs"				, { 1    , 2    , 3    , 4     } },
["Brassclaw Orcs (1)"]	 			= { "Brassclaw Orcs"				, { 1    , false, false, false } },
["Brassclaw Orcs (2)"] 				= { "Brassclaw Orcs"				, { false, 2    , false, false } },
["Brassclaw Orcs (3)"] 				= { "Brassclaw Orcs"				, { false, false, 3    , false } },
["Brassclaw Orcs (4)"] 				= { "Brassclaw Orcs"				, { false, false, false, 4     } },
["Combat Medic"] 					= { "Combat Medic"					, { 1    , 2    , 3    , 4     } },
["Combat Medic (1)"] 				= { "Combat Medic"					, { 1    , false, false, false } },
["Combat Medic (2)"] 				= { "Combat Medic"					, { false, 2    , false, false } },
["Combat Medic (3)"] 				= { "Combat Medic"					, { false, false, 3    , false } },
["Combat Medic (4)"] 				= { "Combat Medic"					, { false, false, false, 4     } },
["Dwarven Soldier"] 				= { "Dwarven Soldier"				, { 1    , 2    , 3     } },
["Dwarven Soldier (1)"]				= { "Dwarven Soldier"				, { 1    , false, false } },
["Dwarven Soldier (2)"]				= { "Dwarven Soldier"				, { false, 2    , false } },
["Dwarven Soldier (3)"]				= { "Dwarven Soldier"				, { false, false, 3     } },
["Elven Fortress"] 					= { "Elven Fortress"				, { 1    , 2    , 3    , 4     } },
["Elven Fortress (1)"] 				= { "Elven Fortress"				, { 1    , false, false, false } },
["Elven Fortress (2)"] 				= { "Elven Fortress"				, { false, 2    , false, false } },
["Elven Fortress (3)"] 				= { "Elven Fortress"				, { false, false, 3    , false } },
["Elven Fortress (4)"] 				= { "Elven Fortress"				, { false, false, false, 4     } },
["Elvish Hunter"] 					= { "Elvish Hunter"					, { 1    , 2    , 3     } },
["Elvish Hunter (1)"]				= { "Elvish Hunter"					, { 1    , false, false } },
["Elvish Hunter (2)"]				= { "Elvish Hunter"					, { false, 2    , false } },
["Elvish Hunter (3)"]				= { "Elvish Hunter"					, { false, false, 3     } },
["Elvish Scout"] 					= { "Elvish Scout"					, { 1    , 2    , 3     } },
["Elvish Scout (1)"]				= { "Elvish Scout"					, { 1    , false, false } },
["Elvish Scout (2)"]				= { "Elvish Scout"					, { false, 2    , false } },
["Elvish Scout (3)"]				= { "Elvish Scout"					, { false, false, 3     } },
["Farrel's Zealot"] 				= { "Farrel's Zealot"				, { 1    , 2    , 3     } },
["Farrel's Zealot (1)"]				= { "Farrel's Zealot"				, { 1    , false, false } },
["Farrel's Zealot (2)"]				= { "Farrel's Zealot"				, { false, 2    , false } },
["Farrel's Zealot (3)"]				= { "Farrel's Zealot"				, { false, false, 3     } },
["Goblin Chirurgeon"] 				= { "Goblin Chirurgeon"				, { 1    , 2    , 3     } },
["Goblin Chirurgeon (1)"]			= { "Goblin Chirurgeon"				, { 1    , false, false } },
["Goblin Chirurgeon (2)"]			= { "Goblin Chirurgeon"				, { false, 2    , false } },
["Goblin Chirurgeon (3)"]			= { "Goblin Chirurgeon"				, { false, false, 3     } },
["Goblin Grenade"] 					= { "Goblin Grenade"				, { 1    , 2    , 3     } },
["Goblin Grenade (1)"]				= { "Goblin Grenade"				, { 1    , false, false } },
["Goblin Grenade (2)"]				= { "Goblin Grenade"				, { false, 2    , false } },
["Goblin Grenade (3)"]				= { "Goblin Grenade"				, { false, false, 3     } },
["Goblin War Drums"] 				= { "Goblin War Drums"				, { 1    , 2    , 3    , 4     } },
["Goblin War Drums (1)"]	 		= { "Goblin War Drums"				, { 1    , false, false, false } },
["Goblin War Drums (2)"] 			= { "Goblin War Drums"				, { false, 2    , false, false } },
["Goblin War Drums (3)"] 			= { "Goblin War Drums"				, { false, false, 3    , false } },
["Goblin War Drums (4)"]	 		= { "Goblin War Drums"				, { false, false, false, 4     } },
["High Tide"] 						= { "High Tide"						, { 1    , 2    , 3     } },
["High Tide (1)"]					= { "High Tide"						, { 1    , false, false } },
["High Tide (2)"]					= { "High Tide"						, { false, 2    , false } },
["High Tide (3)"]					= { "High Tide"						, { false, false, 3     } },
["Homarid"] 						= { "Homarid"						, { 1    , 2    , 3    , 4     } },
["Homarid (1)"] 					= { "Homarid"						, { 1    , false, false, false } },
["Homarid (2)"] 					= { "Homarid"						, { false, 2    , false, false } },
["Homarid (3)"] 					= { "Homarid"						, { false, false, 3    , false } },
["Homarid (4)"] 					= { "Homarid"						, { false, false, false, 4     } },
["Homarid Warrior"] 				= { "Homarid Warrior"				, { 1    , 2    , 3     } },
["Homarid Warrior (1)"]				= { "Homarid Warrior"				, { 1    , false, false } },
["Homarid Warrior (2)"]				= { "Homarid Warrior"				, { false, 2    , false } },
["Homarid Warrior (3)"]				= { "Homarid Warrior"				, { false, false, 3     } },
["Hymn to Tourach"] 				= { "Hymn to Tourach"				, { 1    , 2    , 3    , 4     } },
["Hymn to Tourach (1)"] 			= { "Hymn to Tourach"				, { 1    , false, false, false } },
["Hymn to Tourach (2)"] 			= { "Hymn to Tourach"				, { false, 2    , false, false } },
["Hymn to Tourach (3)"] 			= { "Hymn to Tourach"				, { false, false, 3    , false } },
["Hymn to Tourach (4)"] 			= { "Hymn to Tourach"				, { false, false, false, 4     } },
["Icatian Infantry"] 				= { "Icatian Infantry"				, { 1    , 2    , 3    , 4     } },
["Icatian Infantry (1)"] 			= { "Icatian Infantry"				, { 1    , false, false, false } },
["Icatian Infantry (2)"] 			= { "Icatian Infantry"				, { false, 2    , false, false } },
["Icatian Infantry (3)"]	 		= { "Icatian Infantry"				, { false, false, 3    , false } },
["Icatian Infantry (4)"] 			= { "Icatian Infantry"				, { false, false, false, 4     } },
["Icatian Javelineers"] 			= { "Icatian Javelineers"			, { 1    , 2    , 3     } },
["Icatian Javelineers (1)"]			= { "Icatian Javelineers"			, { 1    , false, false } },
["Icatian Javelineers (2)"]			= { "Icatian Javelineers"			, { false, 2    , false } },
["Icatian Javelineers (3)"]			= { "Icatian Javelineers"			, { false, false, 3     } },
["Icatian Moneychanger"] 			= { "Icatian Moneychanger"			, { 1    , 2    , 3     } },
["Icatian Moneychanger (1)"]		= { "Icatian Moneychanger"			, { 1    , false, false } },
["Icatian Moneychanger (2)"]		= { "Icatian Moneychanger"			, { false, 2    , false } },
["Icatian Moneychanger (3)"]		= { "Icatian Moneychanger"			, { false, false, 3     } },
["Icatian Scout"] 					= { "Icatian Scout"					, { 1    , 2    , 3    , 4     } },
["Icatian Scout (1)"] 				= { "Icatian Scout"					, { 1    , false, false, false } },
["Icatian Scout (2)"] 				= { "Icatian Scout"					, { false, 2    , false, false } },
["Icatian Scout (3)"] 				= { "Icatian Scout"					, { false, false, 3    , false } },
["Icatian Scout (4)"] 				= { "Icatian Scout"					, { false, false, false, 4     } },
["Initiates of the Ebon Hand"]	 	= { "Initiates of the Ebon Hand"	, { 1    , 2    , 3     } },
["Initiates of the Ebon Hand (1)"]	= { "Initiates of the Ebon Hand"	, { 1    , false, false } },
["Initiates of the Ebon Hand (2)"]	= { "Initiates of the Ebon Hand"	, { false, 2    , false } },
["Initiates of the Ebon Hand (3)"]	= { "Initiates of the Ebon Hand"	, { false, false, 3     } },
["Merseine"] 						= { "Merseine"						, { 1    , 2    , 3    , 4     } },
["Merseine (1)"] 					= { "Merseine"						, { 1    , false, false, false } },
["Merseine (2)"] 					= { "Merseine"						, { false, 2    , false, false } },
["Merseine (3)"] 					= { "Merseine"						, { false, false, 3    , false } },
["Merseine (4)"]	 				= { "Merseine"						, { false, false, false, 4     } },
["Mindstab Thrull"]	 				= { "Mindstab Thrull"				, { 1    , 2    , 3     } },
["Mindstab Thrull (1)"]				= { "Mindstab Thrull"				, { 1    , false, false } },
["Mindstab Thrull (2)"]				= { "Mindstab Thrull"				, { false, 2    , false } },
["Mindstab Thrull (3)"]				= { "Mindstab Thrull"				, { false, false, 3     } },
["Necrite"] 						= { "Necrite"						, { 1    , 2    , 3     } },
["Necrite (1)"]						= { "Necrite"						, { 1    , false, false } },
["Necrite (2)"]						= { "Necrite"						, { false, 2    , false } },
["Necrite (3)"]						= { "Necrite"						, { false, false, 3     } },
["Night Soil"] 						= { "Night Soil"					, { 1    , 2    , 3     } },
["Night Soil (1)"]					= { "Night Soil"					, { 1    , false, false } },
["Night Soil (2)"]					= { "Night Soil"					, { false, 2    , false } },
["Night Soil (3)"]					= { "Night Soil"					, { false, false, 3     } },
["Orcish Spy"] 						= { "Orcish Spy"					, { 1    , 2    , 3     } },
["Orcish Spy (1)"]					= { "Orcish Spy"					, { 1    , false, false } },
["Orcish Spy (2)"]					= { "Orcish Spy"					, { false, 2    , false } },
["Orcish Spy (3)"]					= { "Orcish Spy"					, { false, false, 3     } },
["Orcish Veteran"] 					= { "Orcish Veteran"				, { 1    , 2    , 3    , 4     } },
["Orcish Veteran (1)"] 				= { "Orcish Veteran"				, { 1    , false, false, false } },
["Orcish Veteran (2)"] 				= { "Orcish Veteran"				, { false, 2    , false, false } },
["Orcish Veteran (3)"] 				= { "Orcish Veteran"				, { false, false, 3    , false } },
["Orcish Veteran (4)"]	 			= { "Orcish Veteran"				, { false, false, false, 4     } },
["Order of the Ebon Hand"]	 		= { "Order of the Ebon Hand"		, { 1    , 2    , 3     } },
["Order of the Ebon Hand (1)"]		= { "Order of the Ebon Hand"		, { 1    , false, false } },
["Order of the Ebon Hand (2)"]		= { "Order of the Ebon Hand"		, { false, 2    , false } },
["Order of the Ebon Hand (3)"]		= { "Order of the Ebon Hand"		, { false, false, 3     } },
["Order of Leitbur"]	 			= { "Order of Leitbur"				, { 1    , 2    , 3     } },
["Order of Leitbur (1)"]			= { "Order of Leitbur"				, { 1    , false, false } },
["Order of Leitbur (2)"]			= { "Order of Leitbur"				, { false, 2    , false } },
["Order of Leitbur (3)"]			= { "Order of Leitbur"				, { false, false, 3     } },
["Spore Cloud"] 					= { "Spore Cloud"					, { 1    , 2    , 3     } },
["Spore Cloud (1)"]					= { "Spore Cloud"					, { 1    , false, false } },
["Spore Cloud (2)"]					= { "Spore Cloud"					, { false, 2    , false } },
["Spore Cloud (3)"]					= { "Spore Cloud"					, { false, false, 3     } },
["Thallid"] 						= { "Thallid"						, { 1    , 2    , 3    , 4     } },
["Thallid (1)"] 					= { "Thallid"						, { 1    , false, false, false } },
["Thallid (2)"] 					= { "Thallid"						, { false, 2    , false, false } },
["Thallid (3)"] 					= { "Thallid"						, { false, false, 3    , false } },
["Thallid (4)"] 					= { "Thallid"						, { false, false, false, 4     } },
["Thorn Thallid"] 					= { "Thorn Thallid"					, { 1    , 2    , 3    , 4     } },
["Thorn Thallid (1)"] 				= { "Thorn Thallid"					, { 1    , false, false, false } },
["Thorn Thallid (2)"] 				= { "Thorn Thallid"					, { false, 2    , false, false } },
["Thorn Thallid (3)"] 				= { "Thorn Thallid"					, { false, false, 3    , false } },
["Thorn Thallid (4)"] 				= { "Thorn Thallid"					, { false, false, false, 4     } },
["Tidal Flats"] 					= { "Tidal Flats"					, { 1    , 2    , 3     } },
["Tidal Flats (1)"]					= { "Tidal Flats"					, { 1    , false, false } },
["Tidal Flats (2)"]					= { "Tidal Flats"					, { false, 2    , false } },
["Tidal Flats (3)"]					= { "Tidal Flats"					, { false, false, 3     } },
["Vodalian Soldiers"] 				= { "Vodalian Soldiers"				, { 1    , 2    , 3    , 4     } },
["Vodalian Soldiers (1)"] 			= { "Vodalian Soldiers"				, { 1    , false, false, false } },
["Vodalian Soldiers (2)"] 			= { "Vodalian Soldiers"				, { false, 2    , false, false } },
["Vodalian Soldiers (3)"] 			= { "Vodalian Soldiers"				, { false, false, 3    , false } },
["Vodalian Soldiers (4)"] 			= { "Vodalian Soldiers"				, { false, false, false, 4     } },
["Vodalian Mage"] 					= { "Vodalian Mage"					, { 1    , 2    , 3     } },
["Vodalian Mage (1)"]				= { "Vodalian Mage"					, { 1    , false, false } },
["Vodalian Mage (2)"]				= { "Vodalian Mage"					, { false, 2    , false } },
["Vodalian Mage (3)"]				= { "Vodalian Mage"					, { false, false, 3     } },
	},
},
[160] = { name="The Dark",
	cardcount={ reg = 119, tok =  0 },
	variants={}
},
[150] = { name="Legends",
	cardcount={ reg = 310, tok =  0 },
	variants={}
},
[130] = { name="Antiquities",
	cardcount={ reg = 100, tok =  0 },
	variants={
["Mishra's Factory"] 			= { "Mishra's Factory"	, { 1    , 2    , 3    , 4     } },
["Mishra's Factory (Spring)"] 	= { "Mishra's Factory"	, { 1    , false, false, false } },
["Mishra's Factory (Summer)"] 	= { "Mishra's Factory"	, { false, 2    , false, false } },
["Mishra's Factory (Autumn)"] 	= { "Mishra's Factory"	, { false, false, 3    , false } },
["Mishra's Factory (Winter)"] 	= { "Mishra's Factory"	, { false, false, false, 4     } },
["Strip Mine"] 					= { "Strip Mine"		, { 1    , 2    , 3    , 4     } },
["Strip Mine (1)"] 				= { "Strip Mine"		, { 1    , false, false, false } },--No Horizon
["Strip Mine (2)"] 				= { "Strip Mine"		, { false, 2    , false, false } },--Uneven Horizon
["Strip Mine (3)"] 				= { "Strip Mine"		, { false, false, 3    , false } },--Tower
["Strip Mine (4)"] 				= { "Strip Mine"		, { false, false, false, 4     } },--Even Horizon
["Urza's Mine"] 				= { "Urza's Mine"		, { 1    , 2    , 3    , 4     } },
["Urza's Mine (1)"]	 			= { "Urza's Mine"		, { 1    , false, false, false } },--Pully
["Urza's Mine (2)"] 			= { "Urza's Mine"		, { false, 2    , false, false } },--Mouth
["Urza's Mine (3)"] 			= { "Urza's Mine"		, { false, false, 3    , false } },--Clawed Sphere
["Urza's Mine (4)"] 			= { "Urza's Mine"		, { false, false, false, 4     } },--Tower
["Urza's Power Plant"] 			= { "Urza's Power Plant", { 1    , 2    , 3    , 4     } },
["Urza's Power Plant (1)"]	 	= { "Urza's Power Plant", { 1    , false, false, false } },--Sphere
["Urza's Power Plant (2)"] 		= { "Urza's Power Plant", { false, 2    , false, false } },--Columns
["Urza's Power Plant (3)"] 		= { "Urza's Power Plant", { false, false, 3    , false } },--Bug
["Urza's Power Plant (4)"] 		= { "Urza's Power Plant", { false, false, false, 4     } },--Rock in Pot
["Urza's Tower"] 				= { "Urza's Tower"		, { 1    , 2    , 3    , 4     } },
["Urza's Tower (1)"] 			= { "Urza's Tower"		, { 1    , false, false, false } },--Forest
["Urza's Tower (2)"] 			= { "Urza's Tower"		, { false, 2    , false, false } },--Shore
["Urza's Tower (3)"] 			= { "Urza's Tower"		, { false, false, 3    , false } },--Plains
["Urza's Tower (4)"] 			= { "Urza's Tower"		, { false, false, false, 4     } },--Mountains
	},
},
[120] = { name="Arabian Nights",
	cardcount={ reg = 92 , tok =  0 },
	variants={
["Army of Allah"] 				= { "Army of Allah"			, { 1    , 2     } },
["Army of Allah (1)"] 			= { "Army of Allah"			, { 1    , false } },
["Army of Allah (2)"] 			= { "Army of Allah"			, { false, 2     } },
["Bird Maiden"] 				= { "Bird Maiden"			, { 1    , 2     } },
["Bird Maiden (1)"] 			= { "Bird Maiden"			, { 1    , false } },
["Bird Maiden (2)"] 			= { "Bird Maiden"			, { false, 2     } },
["Erg Raiders"] 				= { "Erg Raiders"			, { 1    , 2     } },
["Erg Raiders (1)"] 			= { "Erg Raiders"			, { 1    , false } },
["Erg Raiders (2)"] 			= { "Erg Raiders"			, { false, 2     } },
["Fishliver Oil"] 				= { "Fishliver Oil"			, { 1    , 2     } },
["Fishliver Oil (1)"] 			= { "Fishliver Oil"			, { 1    , false } },
["Fishliver Oil (2)"] 			= { "Fishliver Oil"			, { false, 2     } },
["Giant Tortoise"] 				= { "Giant Tortoise"		, { 1    , 2     } },
["Giant Tortoise (1)"] 			= { "Giant Tortoise"		, { 1    , false } },
["Giant Tortoise (2)"]			= { "Giant Tortoise"		, { false, 2     } },
["Hasran Ogress"] 				= { "Hasran Ogress"			, { 1    , 2     } },
["Hasran Ogress (1)"] 			= { "Hasran Ogress"			, { 1    , false } },
["Hasran Ogress (2)"] 			= { "Hasran Ogress"			, { false, 2     } },
["Moorish Cavalry"] 			= { "Moorish Cavalry"		, { 1    , 2     } },
["Moorish Cavalry (1)"] 		= { "Moorish Cavalry"		, { 1    , false } },
["Moorish Cavalry (2)"]			= { "Moorish Cavalry"		, { false, 2     } },
["Nafs Asp"] 					= { "Nafs Asp"				, { 1    , 2     } },
["Nafs Asp (1)"] 				= { "Nafs Asp"				, { 1    , false } },
["Nafs Asp (2)"] 				= { "Nafs Asp"				, { false, 2     } },
["Oubliette"] 					= { "Oubliette"				, { 1    , 2     } },
["Oubliette (1)"] 				= { "Oubliette"				, { 1    , false } },
["Oubliette (2)"] 				= { "Oubliette"				, { false, 2     } },
["Rukh Egg"] 					= { "Rukh Egg"				, { 1    , 2     } },
["Rukh Egg (1)"] 				= { "Rukh Egg"				, { 1    , false } },
["Rukh Egg (2)"] 				= { "Rukh Egg"				, { false, 2     } },
["Piety"] 						= { "Piety"					, { 1    , 2     } },
["Piety (1)"] 					= { "Piety"					, { 1    , false } },
["Piety (2)"] 					= { "Piety"					, { false, 2     } },
["Stone-Throwing Devils"] 		= { "Stone-Throwing Devils"	, { 1    , 2     } },
["Stone-Throwing Devils (1)"] 	= { "Stone-Throwing Devils"	, { 1    , false } },
["Stone-Throwing Devils (2)"] 	= { "Stone-Throwing Devils"	, { false, 2     } },
["War Elephant"] 				= { "War Elephant"			, { 1    , 2     } },
["War Elephant (1)"] 			= { "War Elephant"			, { 1    , false } },
["War Elephant (2)"]		 	= { "War Elephant"			, { false, 2     } },
["Wyluli Wolf"] 				= { "Wyluli Wolf"			, { 1    , 2     } },
["Wyluli Wolf (1)"] 			= { "Wyluli Wolf"			, { 1    , false } },
["Wyluli Wolf (2)"] 			= { "Wyluli Wolf"			, { false, 2     } },
	},
},
-- special sets
[801] = { name="Commander 2013 Edition",
	foil="n",--15 oversized are foilonly
	cardcount={ reg=356, tok=0, nontr=0, overs=15 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (337)"]				= { "Plains"	, { 1    , false, false, false } }, 
["Plains (338)"]				= { "Plains"	, { false, 2    , false, false } },
["Plains (339)"]				= { "Plains"	, { false, false, 3    , false } },
["Plains (340)"]				= { "Plains"	, { false, false, false, 4     } },
["Island (341)"]				= { "Island"	, { 1    , false, false, false } },
["Island (342)"]				= { "Island"	, { false, 2    , false, false } },
["Island (343)"]				= { "Island"	, { false, false, 3    , false } },
["Island (344)"]				= { "Island"	, { false, false, false, 4     } },
["Swamp (345)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (346)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (347)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (348)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (349)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (350)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (351)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (352)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (353)"]				= { "Forest"	, { 1    , false, false, false } },
["Forest (354)"]				= { "Forest"	, { false, 2    , false, false } },
["Forest (355)"]				= { "Forest"	, { false, false, 3    , false } },
["Forest (356)"]				= { "Forest"	, { false, false, false, 4     } },
	},
--TODO how to set regular vs oversized ?!?
},
[799] = { name="Duel Decks: Heroes vs. Monsters",
	foil="n",
	cardcount={ reg=81, tok=2, nontr=0, overs=0 }, 
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     , 5    , 6    , 7    , 8    } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Mountain (35)"]				= { "Mountain"	, { 1    , false, false, false, false, false, false, false } },
["Mountain (36)"]				= { "Mountain"	, { false, 2    , false, false, false, false, false, false } },
["Mountain (37)"]				= { "Mountain"	, { false, false, 3    , false, false, false, false, false } },
["Mountain (38)"]				= { "Mountain"	, { false, false, false, 4    , false, false, false, false } },
["Plains (39)"]					= { "Plains"	, { 1    , false, false, false } }, 
["Plains (40)"]					= { "Plains"	, { false, 2    , false, false } },
["Plains (41)"]					= { "Plains"	, { false, false, 3    , false } },
["Plains (42)"]					= { "Plains"	, { false, false, false, 4     } },
["Mountain (74)"]				= { "Mountain"	, { false, false, false, false, 5    , false, false, false } },
["Mountain (75)"]				= { "Mountain"	, { false, false, false, false, false, 6    , false, false } },
["Mountain (76)"]				= { "Mountain"	, { false, false, false, false, false, false, 7    , false } },
["Mountain (77)"]				= { "Mountain"	, { false, false, false, false, false, false, false, 8     } },
["Forest (78)"]					= { "Forest"	, { 1    , false, false, false } },
["Forest (79)"]					= { "Forest"	, { false, 2    , false, false } },
["Forest (80)"]					= { "Forest"	, { false, false, 3    , false } },
["Forest (81)"]					= { "Forest"	, { false, false, false, 4     } },
	},
	foiltweak={
["Sun Titan"]					= { foil = false},
["Polukranos, World Eater"]		= { foil = false},
	},
},
[798] = { name="From the Vault: Twenty",
	foilonly=true,
	cardcount={ reg=20, tok=0, nontr=0, overs=0 }, 
},
[796] = { name="Modern Masters",
	cardcount={ reg = 229, tok = 16 },
},
[794] = { name="Duel Decks: Sorin vs. Tibalt",
	foil="n",
	cardcount={ reg=80, tok=1, nontr=0, overs=0 }, 
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3 } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4    , 5    , 6     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3 } },
["Plains (38)"]					= { "Plains"	, { 1    , false, false } },
["Plains (39)"]					= { "Plains"	, { false, 2    , false } },
["Plains (40)"]					= { "Plains"	, { false, false, 3     } },
["Swamp (35)"]					= { "Swamp"		, { 1    , false, false, false, false, false } },
["Swamp (36)"] 					= { "Swamp"		, { false, 2    , false, false, false, false } },
["Swamp (37)"] 					= { "Swamp"		, { false, false, 3    , false, false, false } },
["Swamp (78)"] 					= { "Swamp"		, { false, false, false, 4    , false, false } },
["Swamp (79)"] 					= { "Swamp"		, { false, false, 3    , false, 5    , false } },
["Swamp (80)"] 					= { "Swamp"		, { false, false, 3    , false, false, 6     } },
["Mountain (75)"]				= { "Mountain"	, { 1    , false, false } },
["Mountain (76)"]				= { "Mountain"	, { false, 2    , false } },
["Mountain (77)"]				= { "Mountain"	, { false, false, 3     } },
	},
	foiltweak={
["Sorin, Lord of Innistrad"]		= { foil = true},
["Tibalt, the Fiend-Blooded"]		= { foil = true},
	},
},
[792] = { name="Commander’s Arsenal",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[790] = { name="Duel Decks: Izzet vs. Golgari",
	foil="n",
	cardcount={ reg=90, tok=1, nontr=0, overs=0 }, 
	variants={
["Island"] 						= { "Island"	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest"	, { 1    , 2    , 3    , 4     } },
["Island (37)"]					= { "Island"	, { 1    , false, false, false } }, 
["Island (38)"]					= { "Island"	, { false, 2    , false, false } },
["Island (39)"]					= { "Island"	, { false, false, 3    , false } },
["Island (40)"]					= { "Island"	, { false, false, false, 4     } },
["Swamp (83)"]					= { "Swamp"		, { 1    , false, false, false } }, 
["Swamp (84)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (85)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (86)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (41)"]				= { "Mountain"	, { 1    , false, false, false } }, 
["Mountain (42)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (43)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (44)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (87)"]					= { "Forest"	, { 1    , false, false, false } }, 
["Forest (88)"]					= { "Forest"	, { false, 2    , false, false } },
["Forest (89)"]					= { "Forest"	, { false, false, 3    , false } },
["Forest (90)"]					= { "Forest"	, { false, false, false, 4     } },
	},
	foiltweak={
["Niv-Mizzet, the Firemind"]		= { foil = true},
["Jarad, Golgari Lich Lord"]		= { foil = true},
	},
},
[789] = { name="From the Vault: Realms",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[787] = { name="Planechase 2012",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[785] = { name="Duel Decks: Venser vs. Koth",
	foil="n",
	cardcount={ reg=77, tok=2, nontr=0, overs=0 }, 
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3 } },
["Island"] 						= { "Island"	, { 1    , 2    , 3 } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Plains (38)"]					= { "Plains"	, { 1    , false, false } },
["Plains (39)"]					= { "Plains"	, { false, 2    , false } },
["Plains (40)"]					= { "Plains"	, { false, false, 3     } },
["Island (41)"]					= { "Island"	, { 1    , false, false } },
["Island (42)"]					= { "Island"	, { false, 2    , false } },
["Island (43)"]					= { "Island"	, { false, false, 3     } },
["Mountain (74)"]				= { "Mountain"	, { 1    , false, false, false } }, 
["Mountain (75)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (76)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (77)"]				= { "Mountain"	, { false, false, false, 4     } },
	},
	foiltweak={
["Venser, the Sojourner"]		= { foil = true},
["Koth of the Hammer"]			= { foil = true},
	},
},
[783] = { name="Premium Deck Series: Graveborn",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[781] = { name="Duel Decks: Ajani vs. Nicol Bolas",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[780] = { name="From the Vault: Legends",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[778] = { name="Commander",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[777] = { name="Duel Decks: Knights vs. Dragons",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[774] = { name="Premium Deck Series: Fire and Lightning",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[772] = { name="Duel Decks: Elspeth vs. Tezzeret",
	foil="n",
	cardcount={ reg=79, tok=1, nontr=0, overs=0 }, 
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island"	, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Plains (35)"]					= { "Plains"	, { 1    , false, false, false } },
["Plains (36)"]					= { "Plains"	, { false, 2    , false, false } },
["Plains (37)"]					= { "Plains"	, { false, false, 3    , false } },
["Plains (38)"]					= { "Plains"	, { 1    , false, false, 4     } }, 
["Island (76)"]					= { "Island"	, { 1    , false, false, false } },
["Island (77)"]					= { "Island"	, { false, 2    , false, false } },
["Island (78)"]					= { "Island"	, { false, false, 3    , false } },
["Island (79)"]					= { "Island"	, { 1    , false, false, 4     } }, 
	},
	foiltweak={
["Elspeth, Knight-Errant"]		= { foil = true},
["Tezzeret the Seeker"]			= { foil = true},
	},
},
[771] = { name="From the Vault: Relics",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[769] = { name="Archenemy",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[768] = { name="Duels of the Planeswalkers",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[766] = { name="Duel Decks: Phyrexia vs. The Coalition",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[764] = { name="Premium Deck Series: Slivers",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[763] = { name="Duel Decks: Garruk vs. Liliana",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[761] = { name="Planechase",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[760] = { name="From the Vault: Exiled",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[757] = { name="Duel Decks: Divine vs. Demonic",
	foil="n",
	cardcount={ reg=62, tok=3, nontr=0, overs=0 }, 
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Plains (26)"]					= { "Plains"	, { 1    , false, false, false } },
["Plains (27)"]					= { "Plains"	, { false, 2    , false, false } },
["Plains (28)"]					= { "Plains"	, { false, false, 3    , false } },
["Plains (29)"]					= { "Plains"	, { false, false, false, 4     } },
["Swamp (59)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (60)"] 					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (61)"] 					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (62)"] 					= { "Swamp"		, { false, false, false, 4     } },
	},
	foiltweak={
["Akroma, Angel of Wrath"]			= { foil = true},
["Lord of the Pit"]					= { foil = true},
	},
},
[755] = { name="Duel Decks: Jace vs. Chandra",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[753] = { name="From the Vault: Dragons",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[740] = { name="Duel Decks: Elves vs. Goblins   ",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[675] = { name="Coldsnap Theme Decks",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[635] = { name="Magic Encyclopedia",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[600] = { name="Unhinged",
	foil="y",
	cardcount={ reg = 141, tok = 0 },
	variants={},
	foiltweak={
["Super Secret Tech"]			= { foil = true},
	},
},
[490] = { name="Deckmasters",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[440] = { name="Beatdown Box Set",
	foil="n",
	cardcount={ reg=90, tok=0, nontr=0, overs=0 }, 
	variants={
["Island"] 						= { "Island" 	, { 1    , 2    , 3     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3     } },
["Island (79)"]					= { "Island"	, { 1    , false, false } },
["Island (80)"]					= { "Island"	, { false, 2    , false } },
["Island (81)"]					= { "Island"	, { false, false, 3     } },
["Swamp (82)"]					= { "Swamp"		, { 1    , false, false } },
["Swamp (83)"]					= { "Swamp"		, { false, 2    , false } },
["Swamp (84)"]					= { "Swamp"		, { false, false, 3     } },
["Mountain (85)"]				= { "Mountain"	, { 1    , false, false } },
["Mountain (86)"]				= { "Mountain"	, { false, 2    , false } },
["Mountain (87)"]				= { "Mountain"	, { false, false, 3     } },
["Forest (88)"]					= { "Forest"	, { 1    , false, false } },
["Forest (89)"]					= { "Forest"	, { false, 2    , false } },
["Forest (90)"]					= { "Forest"	, { false, false, 3     } },
	},
	foiltweak={
["Erhnam Djinn"]				= { foil = true},
["Sengir Vampire"]				= { foil = true},
	},
},
[415] = { name="Starter 2000   ",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[405] = { name="Battle Royale Box Set",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[390] = { name="Starter 1999",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[380] = { name="Portal Three Kingdoms",
	cardcount={ reg = 180, tok = 0 }, -- Portal Three Kingdoms
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3     } },
["Plains (166)"]				= { "Plains"	, { 1    , false, false } },
["Plains (167)"]				= { "Plains"	, { false, 2    , false } },
["Plains (168)"]				= { "Plains"	, { false, false, 3     } },
["Island (169)"]				= { "Island"	, { 1    , false, false } },
["Island (170)"]				= { "Island"	, { false, 2    , false } },
["Island (171)"]				= { "Island"	, { false, false, 3     } },
["Swamp (172)"]					= { "Swamp"		, { 1    , false, false } },
["Swamp (173)"]					= { "Swamp"		, { false, 2    , false } },
["Swamp (174)"]					= { "Swamp"		, { false, false, 3     } },
["Mountain (175)"]				= { "Mountain"	, { 1    , false, false } },
["Mountain (176)"]				= { "Mountain"	, { false, 2    , false } },
["Mountain (177)"]				= { "Mountain"	, { false, false, 3     } },
["Forest (178)"]				= { "Forest"	, { 1    , false, false } },
["Forest (179)"]				= { "Forest"	, { false, 2    , false } },
["Forest (180)"]				= { "Forest"	, { false, false, 3     } },
	},
},
[340] = { name="Anthologies",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[320] = { name="Unglued",
	foil="n",
	cardcount={ reg = 88 , tok = 6 }, -- Unglued
	variants={
["B.F.M."] 						= { "B.F.M."	, { "Left", "Right" } },
["B.F.M. (left)"] 				= { "B.F.M."	, { "Left", false   } },
["B.F.M. (right)"] 				= { "B.F.M."	, { false , "Right" } },
	},
},
[310] = { name="Portal Second Age",
	foil="n",
	cardcount={ reg = 165, tok = 0 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3     } },
["Plains (1)"]					= { "Plains"	, { 1    , false, false } },
["Plains (2)"]					= { "Plains"	, { false, 2    , false } },
["Plains (3)"]					= { "Plains"	, { false, false, 3     } },
["Island (1)"]					= { "Island"	, { 1    , false, false } },
["Island (2)"]					= { "Island"	, { false, 2    , false } },
["Island (3)"]					= { "Island"	, { false, false, 3     } },
["Swamp (1)"]					= { "Swamp"		, { 1    , false, false } },
["Swamp (2)"]					= { "Swamp"		, { false, 2    , false } },
["Swamp (3)"]					= { "Swamp"		, { false, false, 3     } },
["Mountain (1)"]				= { "Mountain"	, { 1    , false, false } },
["Mountain (2)"]				= { "Mountain"	, { false, 2    , false } },
["Mountain (3)"]				= { "Mountain"	, { false, false, 3     } },
["Forest (1)"]					= { "Forest"	, { 1    , false, false } },
["Forest (2)"]					= { "Forest"	, { false, 2    , false } },
["Forest (3)"]					= { "Forest"	, { false, false, 3     } },
	},
},
[260] = { name="Portal",
	foil="n",
	cardcount={ reg = 228, tok = 0 },
	variants={
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (1)"]					= { "Plains"	, { 1    , false, false, false } }, 
["Plains (2)"]					= { "Plains"	, { false, 2    , false, false } },
["Plains (3)"]					= { "Plains"	, { false, false, 3    , false } },
["Plains (4)"]					= { "Plains"	, { false, false, false, 4     } },
["Island (1)"]					= { "Island"	, { 1    , false, false, false } },
["Island (2)"]					= { "Island"	, { false, 2    , false, false } },
["Island (3)"]					= { "Island"	, { false, false, 3    , false } },
["Island (4)"]					= { "Island"	, { false, false, false, 4     } },
["Swamp (1)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp (2)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp (3)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp (4)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain (1)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain (2)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain (3)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain (4)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest (1)"]					= { "Forest"	, { 1    , false, false, false } },
["Forest (2)"]					= { "Forest"	, { false, 2    , false, false } },
["Forest (3)"]					= { "Forest"	, { false, false, 3    , false } },
["Forest (4)"]					= { "Forest"	, { false, false, false, 4     } },
["Anaconda"]					= { "Anaconda"				, { ""	 , "ST"	} },
["Anaconda (ST)"]				= { "Anaconda"				, { false, "ST"	} },
["Blaze"]						= { "Blaze"					, { ""	 , "ST"	} },
["Blaze (ST)"]					= { "Blaze"					, { false, "ST"	} },
["Elite Cat Warrior"]			= { "Elite Cat Warrior"		, { ""	 , "ST"	} },
["Elite Cat Warrior (ST)"]		= { "Elite Cat Warrior"		, { false, "ST"	} },
["Hand of Death"]				= { "Hand of Death"			, { ""	 , "ST"	} },
["Hand of Death (ST)"]			= { "Hand of Death"			, { false, "ST"	} },
["Monstrous Growth"]			= { "Monstrous Growth"		, { ""	 , "ST"	} },
["Monstrous Growth (ST)"]		= { "Monstrous Growth"		, { false, "ST"	} },
["Raging Goblin"]				= { "Raging Goblin"			, { ""	 , "ST"	} },
["Raging Goblin (ST)"]			= { "Raging Goblin"			, { false, "ST"	} },
["Warrior's Charge"]			= { "Warrior's Charge"		, { ""	 , "ST"	} },
["Warrior's Charge (ST)"]		= { "Warrior's Charge"		, { false, "ST"	} },
["Armored Pegasus"]				= { "Armored Pegasus"		, { ""	 , "DG"	} },
["Armored Pegasus (DG)"]		= { "Armored Pegasus"		, { false, "DG"	} },
["Bull Hippo"]					= { "Bull Hippo"			, { ""	 , "DG"	} },
["Bull Hippo (DG)"]				= { "Bull Hippo"			, { false, "DG"	} },
["Cloud Pirates"]				= { "Cloud Pirates"			, { ""	 , "DG"	} },
["Cloud Pirates (DG)"]			= { "Cloud Pirates"			, { false, "DG"	} },
["Feral Shadow"]				= { "Feral Shadow"			, { ""	 , "DG"	} },
["Feral Shadow (DG)"]			= { "Feral Shadow"			, { false, "DG"	} },
["Snapping Drake"]				= { "Snapping Drake"		, { ""	 , "DG"	} },
["Snapping Drake (DG)"]			= { "Snapping Drake"		, { false, "DG"	} },
["Storm Crow"]					= { "Storm Crow"			, { ""	 , "DG"	} },
["Storm Crow (DG)"]				= { "Storm Crow"			, { false, "DG"	} },
["Anakonda"]					= { "Anakonda"				, { ""	 , "ST"	} },
["Anakonda (ST)"]				= { "Anakonda"				, { false, "ST"	} },
["Heiße Glut"]					= { "Heiße Glut"			, { ""	 , "ST"	} },
["Heiße Glut (ST)"]				= { "Heiße Glut"			, { false, "ST"	} },
["Katzenkriegerelite"]			= { "Katzenkriegerelite"	, { ""	 , "ST"	} },
["Katzenkriegerelite (ST)"]		= { "Katzenkriegerelite"	, { false, "ST"	} },
["Todbringende Hand"]			= { "Todbringende Hand"		, { ""	 , "ST"	} },
["Todbringende Hand (ST)"]		= { "Todbringende Hand"		, { false, "ST"	} },
["Unheimliches Wachstum"]		= { "Unheimliches Wachstum"	, { ""	 , "ST"	} },
["Unheimliches Wachstum (ST)"]	= { "Unheimliches Wachstum"	, { false, "ST"	} },
["Wütender Goblin"]				= { "Wütender Goblin"		, { ""	 , "ST"	} },
["Wütender Goblin (ST)"]		= { "Wütender Goblin"		, { false, "ST"	} },
["Attacke der Krieger"]			= { "Attacke der Krieger"	, { ""	 , "ST"	} },
["Attacke der Krieger (ST)"]	= { "Attacke der Krieger"	, { false, "ST"	} },
	},
},
[225] = { name="Introductory Two-Player Set",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[201] = { name="Renaissance",-- (GER)
	foil="n",
	cardcount={ reg = 122, tok = 0 },
	variants={}
},
[200] = { name="Chronicles",
	foil="n",
	cardcount={ reg = 125, tok = 0 },
	variants={
["Urza's Mine"] 				= { "Urza's Mine"			, { 1    , 2    , 3    , 4 } },
["Urza's Power Plant"] 			= { "Urza's Power Plant"	, { 1    , 2    , 3    , 4 } },
["Urza's Tower"] 				= { "Urza's Tower"			, { 1    , 2    , 3    , 4 } },
["Urza's Mine (1)"] 			= { "Urza's Mine"			, { 1    , false, false, false } },--Mouth
["Urza's Mine (2)"] 			= { "Urza's Mine"			, { false, 2    , false, false } },--Clawed Sphere
["Urza's Mine (3)"] 			= { "Urza's Mine"			, { false, false, 3    , false } },--Pully
["Urza's Mine (4)"] 			= { "Urza's Mine"			, { false, false, false, 4     } },--Tower
["Urza's Power Plant (1)"] 		= { "Urza's Power Plant"	, { 1    , false, false, false } },--Rock in Pot
["Urza's Power Plant (2)"] 		= { "Urza's Power Plant"	, { false, 2    , false, false } },--Columns
["Urza's Power Plant (3)"] 		= { "Urza's Power Plant"	, { false, false, 3    , false } },--Bug
["Urza's Power Plant (4)"] 		= { "Urza's Power Plant"	, { false, false, false, 4     } },--Sphere
["Urza's Tower (1)"] 			= { "Urza's Tower"			, { 1    , false, false, false } },--Forest
["Urza's Tower (2)"] 			= { "Urza's Tower"			, { false, 2    , false, false } },--Plains
["Urza's Tower (3)"] 			= { "Urza's Tower"			, { false, false, 3    , false } },--Mountains
["Urza's Tower (4)"] 			= { "Urza's Tower"			, { false, false, false, 4     } },--Shore
	},
},
[70] = { name="Vanguard",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[69] = { name="Box Topper Cards",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
-- Promo Cards
[50] = { name="Full Box Promotion",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[45] = { name="Magic Premiere Shop",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[43] = { name="Two-Headed Giant Promos",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[42] = { name="Summer of Magic Promos",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[41] = { name="Happy Holidays Promos",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[40] = { name="Arena Promos",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[33] = { name="Championships Prizes",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[32] = { name="Pro Tour Promos",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[31] = { name="Grand Prix Promos",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[30] = { name="Friday Night Magic Promos",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[27] = { name="Alternate Art Lands",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[26] = { name="Game Day Promos",
--	foil="",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	variants={
--	},
},
[25] = { name="Judge Promos",
	foilonly=true,
	cardcount={ reg=70, tok=1, nontr=0, overs=0 }, 
	foiltweak={
["Centaur"]				= { foil = false},
	},
},
[24] = { name="Champs Promos",
	foilonly=true,
	cardcount={ reg=12, tok=0, nontr=0, overs=0 }, 
	foiltweak={
["Electrolyze"]						= { foil = false},
["Rakdos Guildmage"]				= { foil = false},
["Urza’s Factory"]					= { foil = false},
["Blood Knight"]					= { foil = false},
["Imperious Perfect"]				= { foil = false},
["Bramblewood Paragon"]				= { foil = false},
	},
},
[23] = { name="Gateway & WPN Promos",
	foilonly=true,
	cardcount={ reg=56, tok=0, nontr=7, overs=0 }, 
	foiltweak={
["Drench the Soil in Their Blood"]	= { foil = false},
["Horizon Boughs"]					= { foil = false},
["Imprison This Insolent Wretch"]	= { foil = false},
["Mirrored Depths"]					= { foil = false},
["Perhaps You’ve Met My Cohort"]	= { foil = false},
["Tember City"]						= { foil = false},
["Your Inescapable Doom"]			= { foil = false},
	},
},
[22] = { name="Prerelease Cards",
	foil="y",-- "o" might be better to catch most foils, but there are 5 "yes" cards in here...
	cardcount={ reg=66, tok=1, nontr=1, overs=5 }, 
	variants={
["Lu Bu, Master-at-Arms"] 			= { "Lu Bu, Master-at-Arms"		, { "April", "July" } },
["Plains"] 							= { "Plains"		, { "DGM" } },
	},
	foiltweak={
["Lu Bu, Master-at-Arms"]			= { foil = false},
["Revenant"]						= { foil = false},
["Dirtcowl Wurm"]					= { foil = false},
["Celestine Reef"]					= { foil = false},
["Monstrous Hound"]					= { foil = false},
	},
},
[21] = { name="Release & Launch Party Cards",
	foilonly=true,
	cardcount={ reg=34, tok=1, nontr=0, overs=6 }, 
	foiltweak={
["Incoming!"]						= { foil = false},
["Tazeem"]							= { foil = false},
["Plots that Span Centuries"]		= { foil = false},
["Stairs to Infinity"]				= { foil = false},
	},
},
[20] = { name="Magic Player Rewards",
	foil="n",
	cardcount={ reg=53, tok=24, nontr=0, overs=10 }, 
	variants={
["Bear"] 							= { "Bear"		, { "ONS", "ODY" } },
["Beast"] 							= { "Beast"		, { "DST", "ODY" } },
["Elephant"] 						= { "Elephant"	, { "INV", "ODY" } },
["Spirit"] 							= { "Spirit"	, { "CHK", "PLS" } },
	},
	foiltweak={
["Cryptic Command"]				= { foil = true },
["Damnation"]					= { foil = true },
["Day of Judgment"]				= { foil = true },
["Hypnotic Specter"]			= { foil = true },
--["Lightning Bolt"]				= { foil = true }, -- there's two 'Bolts here, one nofoil, one foilonly
["Powder Keg"]					= { foil = true },
["Psychatog"]					= { foil = true },
["Wasteland"]					= { foil = true },
["Wrath of God"]				= { foil = true },
	},
},
[15] = { name="Convention Promos",
	foilonly=true,
	cardcount={ reg=5, tok=0, nontr=0, overs=2 }, 
	foiltweak={
["Hurloon Minotaur"]			= { foil = false},
["Serra Angel"]					= { foil = false},
	},
},
[12] = { name="Hobby Japan Commemorative Cards",
--	foil="n",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	--jpn only
},
[11] = { name="Redemption Program Cards",
--	foil="n",
--	cardcount={ reg=0, tok=0, nontr=0, overs=0 }, 
--	--jpn only
},
[10] = { name="Junior Series Promos",
--	foilonly=true,
--	cardcount={ reg=31, tok=0, nontr=0, overs=0 }, 
--	variants={
----TODO
--	},
},
[9] = { name="Video Game Promos",
	foilonly=true,
	cardcount={ reg=12, tok=0, nontr=0, overs=1 }, 
	foiltweak={
["Aswan Jaguar"] 				= { foil = false},
["Primordial Hydra"]			= { foil = false},
["Serra Avatar"] 				= { foil = false},
["Vampire Nocturnus"]			= { foil = false},
	},
},
[8] = { name="Stores Promos",
	foilonly=true,
	cardcount={ reg=9, tok=0, nontr=0, overs=0 }, 
},
[7] = { name="Magazine Inserts",
	foil="n",
	cardcount={ reg=7, tok=0, nontr=0, overs=5 }, 
	foiltweak={
["Lightning Hounds"]	 		= { foil = true },
["Warmonger"]					= { foil = true },
	},
},
[6] = { name="Comic Inserts",
	foil="n",
	cardcount={ reg=14, tok=0, nontr=0, overs=1 }, 
},
[5] = { name="Book Inserts",
	foil="n",
	cardcount={ reg=6, tok=0, nontr=0, overs=0 }, 
},
[4] = { name="Ultra Rare Cards",
	foil="n",
	cardcount={ reg=5, tok=0, nontr=0, overs=0 }, 
},
[2] = { name="DCI Legend Membership",
	foil="n",
	cardcount={ reg=2, tok=0, nontr=0, overs=0 }, 
},
}-- end table LHpi.sets
for sid,set in pairs(LHpi.sets) do
	if set.cardcount then
		set.cardcount.both = set.cardcount.reg + set.cardcount.tok
	end --if
end -- for sid,count

--LHpi.Log( "\239\187\191LHpi library loaded and executed successfully" , 0 , nil , 0 ) -- add unicode BOM to beginning of logfile
LHpi.Log( "LHpi library loaded and executed successfully." , 0 , nil , 0 )
return LHpi