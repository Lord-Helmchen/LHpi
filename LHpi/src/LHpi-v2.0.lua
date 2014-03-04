--*- coding: utf-8 -*-
--[[- LordHelmchen's price import
 Price import script library for Magic Album.

Inspired by and loosely based on "MTG Mint Card.lua" by Goblin Hero, Stromglad1 and "Import Prices.lua" by woogerboy21;
who generously granted permission to "do as I like" with their code;
everything else Copyright (C) 2012 by Christian Harms.
If you want to contact me about the script, try its release thread in http://www.slightlymagic.net/forum/viewforum.php?f=32

@module LHpi
@author Christian Harms
@copyright 2012-2013 Christian Harms except parts by Goblin Hero, Stromglad1 or woogerboy21
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

--[[ TODO
DONE reverse script and config
	DONE minimize code duplication once more than one site is available
	DONE lib contains general and reusable functions and as much of the actual program logic as possible
	DONE script contains configuration and all site specific functions
	DONE script needs to load and run lib to make functions available.
	DONE lib needs to error out if called directly from MA gui
	DONE implement stubs for non-existing site.*, if possible doing something sensible, else throwing an error.

duplicate handling
	DONE check for duplicates when inserting into cardsetTable
	DONE handle duplicate prices by averaging the price

patch to accept entries with a condition description if no other entry with better condition is in the table:
	buildCardData will need to add condition to carddata
	global conditions{} to define priorities
	then fillCardsetTable needs a new check before overwriting existing data
	check conflict handling with Onulet from 140

DONE prepare for more languages
	DONT importprice - might need a switch to support site with one page per language
	DONE needs to loop through languages
	DONE to save bandwith: build table of urls first, then have loop through it to call parsehtml
	DONE test with legends(150) italian
	DONE	change nameE,nameG to names { [1],[3] }
 	DONE make price a (sub-)table as well

for kicks and giggles, have SAVETABLE generate a csv usable by woogerboys importprices :-)

]]

--- @field [parent=#LHpi] #string version
LHpi.version = "2.0"

--TODO condprio = { [0] = "NONE", } -- table to sort condition description. lower indexed will overwrite when building the cardsetTable

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
	-- read user supplied parameters and modify site.sets table
	local supImportfoil,supImportlangs, supImportsets = LHpi.ProcessUserParams( importfoil , importlangs , importsets )
	-- build sourceList of urls/files to fetch
	local sourceList, sourceCount = LHpi.ListSources( supImportfoil , supImportlangs , supImportsets )

	--- @field [parent=#global] #table totalcount
	totalcount = { pset= {}, failed={}, dropped=0, namereplaced=0 }
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
	LHpi.Log("totalcounted  \t" .. LHpi.Tostring(totalcount) , 1 )
	if CHECKEXPECTED then
		local totalexpected = {pset={},failed={},dropped=0,namereplaced=0}
		for lid,_lang in pairs(supImportlangs) do
			totalexpected.pset[lid] = 0
			totalexpected.failed[lid] = 0
		end -- for
		for sid,set in pairs( importsets ) do
			if site.expected[sid] then
				for lid,_ in pairs( supImportlangs ) do
					totalexpected.pset[lid] = totalexpected.pset[lid] + ( site.expected[sid].pset[lid] or 0 )
					totalexpected.failed[lid] = totalexpected.failed[lid]  + ( site.expected[sid].failed[lid] or 0 )
				end -- for lid
				totalexpected.dropped = totalexpected.dropped + ( site.expected[sid].dropped or 0 )
				totalexpected.namereplaced = totalexpected.namereplaced + ( site.expected[sid].namereplaced or 0 )
			end -- if site.expected[sid]
		end -- for sid,set
		LHpi.Log ( "totalexpected \t" .. LHpi.Tostring(totalexpected) , 1 )
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
			persetcount = { pset= {}, failed={}, dropped=0, namereplaced=0 }
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
					LHpi.Log( pmesg .. "  " .. progress .. "%" , 1 )
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
						print("empty sourceTable for " .. importsets[sid] .. " - " .. sourceurl)
						--error("empty sourceTable for " .. importsets[sid] .. " - " .. sourceurl)
					end
				end -- if sourceTable
			end -- for _,source 
			-- build cardsetTable from htmls finished
			if VERBOSE then
				local msg =  "cardsetTable for set " .. importsets[sid] .. "(id " .. sid .. ") build with " .. LHpi.Length(cardsetTable) .. " rows."
				if LHpi.sets.cardcount[sid] then
					msg = msg ..  " Set supposedly contains " .. ( LHpi.sets.cardcount[sid].reg or "#" ) .. " cards and " .. ( LHpi.sets.cardcount[sid].tok or "#" ).. " tokens."
				else
					msg = msg .. " Number of cards in set is not known to LHpi."
				end 
				LHpi.Log( msg , 1 )
			end
			if SAVETABLE then
			-- TODO write a seperate function that loops through the table and uses incremental putFile
				local filename = savepath .. "table-set=" .. importsets[cSet.id] .. ".txt"
				LHpi.Log( "Saving table to file: \"" .. filename .. "\"" )
				ma.PutFile( filename , LHpi.Tostring( cardsetTable ) )
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
			if LHpi.sets.cardcount[sid] then
				LHpi.Log( "[" .. cSet.id .. "] contains \t" .. ( LHpi.sets.cardcount[sid].both or "#" ) .. " cards (\t" .. ( LHpi.sets.cardcount[sid].reg or "#" ) .. " regular,\t " .. ( LHpi.sets.cardcount[sid].tok or "#" ) .. " tokens )" )
			else
				LHpi.Log(  "[" .. cSet.id .. "] contains unknown to LHpi number of cards." )
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
				if ( site.expected[sid].dropped or 0 ) ~= persetcount.dropped then allgood = false end
				if ( site.expected[sid].namereplaced or 0 ) ~= persetcount.namereplaced then allgood = false end
				if not allgood then
					LHpi.Log( ":-( persetcount for " .. importsets[sid] .. "(id " .. sid .. ") differs from expected. " , 1 )
					table.insert( setcountdiffers , sid , importsets[sid] )
					if VERBOSE then
						LHpi.Log( ":-( counted  :\t" .. LHpi.Tostring( persetcount ) , 1 )
						LHpi.Log( ":-( expected :\t" .. LHpi.Tostring( site.expected[sid]) , 1 )
						LHpi.Log( "nameraplace table for the set contains " .. ( LHpi.Length(site.namereplace[sid]) or "no" ) .. " entries." )
					end
					if DEBUG then
						print( "not allgood in set " .. importsets[sid] .. "(" ..  sid .. ")" )
						--error( "not allgood in set " .. importsets[sid] .. "(" ..  sid .. ")" )
					end
				else
					LHpi.Log( ":-) Prices for set " .. importsets[sid] .. "(id " .. sid .. ") were imported as expected :-)" , 1 )
				end
			else
				LHpi.Log( "No expected persetcount for " .. importsets[sid] .. "(id " .. sid .. ") found." , 1 )
			end -- if site.expected[sid] else
		end -- if CHECKEXPECTED
		
		for lid,_lang in pairs(importlangs) do
			totalcount.pset[lid]=totalcount.pset[lid]+persetcount.pset[lid]
			totalcount.failed[lid]=totalcount.failed[lid]+persetcount.failed[lid]
		end
		totalcount.dropped=totalcount.dropped+persetcount.dropped
		totalcount.namereplaced=totalcount.namereplaced+persetcount.namereplaced
		
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
			for lid,_lang in pairs( importlangs ) do
				if cSet.lang[lid] then
					for fid,fruc in pairs ( site.frucs ) do
						if cSet.fruc[fid] then
							local url,urldetails = next( site.BuildUrl( sid , lid , fid , OFFLINE ) )
							urldetails.setid=sid
							urldetails.langid=lid
							urldetails.frucid=fid
							if DEBUG then
								urldetails.lang=site.langs[lid].url
								urldetails.fruc=site.frucs[fid]
								LHpi.Log( "site.BuildUrl is \"" .. LHpi.Tostring( container ) .. "\"" , 2 )
							end
							urls[sid][url] = urldetails
						elseif DEBUG then
							LHpi.Log( fruc .. " not available" , 2 )
						end -- of cSet.fruc[fid]
					end -- for fid,fruc
				elseif DEBUG then
					LHpi.Log( _lang .. " not available" , 2 )
				end	-- if cSet.lang[lid]
			end -- for lid,_lang
			-- Calculate total number of sources for progress bar
			urlcount = urlcount + LHpi.Length(urls[sid])
			if DEBUG then
				LHpi.Logtable(urls[sid])
			end
		elseif DEBUG then
			LHpi.Log( sid .. " not available" , 2 )
		end -- if importsets[sid]
	end -- for sid,cSet
	return urls, urlcount
end -- function LHpi.ListSources

--[[- construct url/filename and build sourceTable.
 Construct URL/filename from set and rarity and return a table with all entries found therein
 Calls site.ParseHtmlData from sitescript.

 @function [parent=#LHpi] GetSourceData
 @param #string url		source location (url or filename)
 @param #table details	{ foilonly = #boolean , offline = #boolean , setid = #number, langid = #number, frucid = #number }
 @return #table { #table names, #table price }
]]
function LHpi.GetSourceData( url , details ) -- 
	local htmldata = nil -- declare here for right scope
	LHpi.Log( "Fetching " .. url )
	if details.isfile then -- get htmldata from local source
		htmldata = ma.GetFile( url )
		if not htmldata then
			LHpi.Log( "!! GetFile failed for " .. url )
			return nil
		end
	else -- get htmldata from online source
		htmldata = ma.GetUrl( url )
		if not htmldata then
			LHpi.Log( "!! GetUrl failed for " .. url )
			return nil
		end
	end -- if details.isfile
	
	if SAVEHTML and not OFFLINE then
		local filename = next( site.BuildUrl( details.setid , details.langid , details.frucid , true ) )
		LHpi.Log( "Saving source html to file: \"" .. filename .. "\"" )
		ma.PutFile( filename , htmldata )
	end -- if SAVEHTML

	local sourceTable = {}
	for foundstring in string.gmatch( htmldata , site.regex) do
		if DEBUG and not DEBUGSKIPFOUND then
			LHpi.Log( "FOUND : " .. foundstring )
		end
		local foundData = site.ParseHtmlData(foundstring , details )
		-- divide price by 100 again (see site.ParseHtmlData in sitescript for reason)
		-- do some initial input sanitizing: "_" to " "; remove spaces from start and end of string
		for lid,_cName in pairs( foundData.names ) do
			foundData.price[lid] = foundData.price[lid] / 100
			foundData.names[lid] = LHpi.Toutf8( foundData.names[lid] )
			foundData.names[lid] = string.gsub( foundData.names[lid], "_", " " )
			foundData.names[lid] = string.gsub( foundData.names[lid], "^%s*(.-)%s*$", "%1" )
		end -- for lid,_cName
		if LHpi.Length( foundData.names ) == 0 then
			if VERBOSE then
				LHpi.Log( "foundstring contained no data" , 1 )
			end
			if DEBUG then
				error( "foundstring contained no data" )
			end
		else -- something was found
			table.insert( sourceTable , { names = foundData.names, price = foundData.price } )
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
 @param #boolean foil	optional: true if processing row from a foil-only url
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
		card.bcdData = sourcerow.bcdData
	end

	-- set card languages
	if sourcerow.Lang then -- keep site.ParseHtmlData preset lang 
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
	
	--[[ do site-specific card data manipulation
	for magicuniverse, this is
	seperate "(alpha)" and beta from beta-urls
	set lots of condition suffixes to (DROP)
	]]
	if site.BCDpluginName then
		card.name = site.BCDpluginName ( card.name , setid )
	end
	
	-- drop unwanted sourcedata before further processing
	if     string.find( card.name , "%(DROP[ %a]*%)" ) then
		card.drop = true
		if DEBUG then
			LHpi.Log ( "LHpi.Oldlib.buildCardData\t dropped card " .. LHpi.Tostring(card) , 2 )
		end
		return card
	end -- if entry to be dropped
	
	card.name = string.gsub( card.name , " // " , "|")
	card.name = string.gsub( card.name , "Æ" , "AE")
	card.name = string.gsub( card.name , "â" , "a")
	card.name = string.gsub( card.name , "û" , "u")
	card.name = string.gsub( card.name , "á" , "a")
	card.name = string.gsub( card.name , "´" , "'")
	card.name = string.gsub( card.name , "?" , "'")
	
	if string.find( card.name , "Emblem: " ) then -- Emblem prefix to suffix
		card.name = string.gsub( card.name , "Emblem: ([^\"]+)" , "%1 Emblem" )
	end
	
	-- unify collector number suffix. must come before variant checking
	card.name = string.gsub( card.name , "%(Nr%.%s+(%d+)%)" , "(%1)" )
	card.name = string.gsub( card.name , " *(%(%d+%))" , " %1" )
--	card.name = string.gsub( card.name , "%s+" , " " )
--	card.name = string.gsub( card.name , "%s+$" , "" )

	if sourcerow.foil then -- keep site.ParseHtmlData preset foil
		card.foil = sourcerow.foil
	else
	-- removal of foil suffix  must come before variant and namereplace check
		if urlfoil then -- remove "(foil)" if foil url
			card.name = string.gsub( card.name , "%([fF][oO][iI][lL]%)" , "" )
			card.foil = true
		else
			-- FIXME what about mixed foil/nonfoil htmldata ?
			card.foil = false
		end -- if urlfoil
	end -- if

	card.name = string.gsub( card.name , "%s+" , " " ) -- reduce multiple spaces
	card.name = string.gsub( card.name , "^%s*(.-)%s*$" , "%1" ) --remove spaces from start and end of string

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

	-- Token infix removal, must come after variant checking
	if string.find(card.name , "[tT][oO][kK][eE][nN] %- " ) then -- Token prefix and color suffix
		card.name = string.gsub( card.name , "[tT][oO][kK][eE][nN] %- ([^\"]+)" , "%1" )
		card.name = string.gsub( card.name , "%([WUBRG][/]?[WUBRG]?%)" , "" )
		card.name = string.gsub( card.name , "%(Art%)" , "" )
		card.name = string.gsub( card.name , "%(Gld%)" , "" )
	end
	card.name = string.gsub( card.name , "^%s*(.-)%s*$" , "%1" ) --remove any leftover spaces from start and end of string
	
	if site.namereplace[setid] and site.namereplace[setid][card.name] then
		if LOGNAMEREPLACE or DEBUG then
			LHpi.Log( "namereplaced\t" .. card.name .. "\t to " .. site.namereplace[setid][card.name] , 1 )
		end
		card.name = site.namereplace[setid][card.name]
		if CHECKEXPECTED then
			persetcount.namereplaced = persetcount.namereplaced + 1
		end
	end -- site.namereplace[setid]
	
	if site.foiltweak[setid] and site.foiltweak[setid][card.name] then -- foiltweak
		card.foil = site.foiltweak[setid][card.name].foil
		if DEBUG then 
			LHpi.Log( "FOILTWEAKed " ..  name ..  " to "  .. card.foil , 2 )
		end
	end -- if site.foiltweak
	
	--TODO card.condition[lid] = "NONE"
	
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
	
	--[[ do site-specific card data manipulation
	for magicuniverse, this is
	set 140 "Schilftroll (Fehldruck, deutsch)"
	set Legends "(ital.)" suffixed to lang[] and DROP
	]]
	card = site.BCDpluginCard( card , setid )
	
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
						LHpi.Log( "!!! FillCardsetTable\t conflict while unifying varnames" , 2 )
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
				LHpi.Log ("!!! FillCardsetTable\t conflict variant vs not variant" ,2)
			end
			if DEBUG then 
				error( "FillCardsetTable conflict: " .. LHpi.Tostring(oldCardrow.variant) .. " vs " .. LHpi.Tostring(newCardrow.variant) .. " !" )
			end
			return 1,"variant state differs"
		end -- if oldCardrow.variant and newCardrow.variant
				
		-- variant table equal (or equally nil) in old and new, now merge data
		local mergedCardrow,conflict = LHpi.MergeCardrows (card.name, mergedlang, oldCardrow, newCardrow, mergedvariant)
		if DEBUG then
			if string.find( conflict.reg , "!!") or string.find( conflict.foil , "!!") then
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

--[[ old helper function]]
function LHpi.readexpectedfromhtml (str)
	local _s,_e,results = string.find(str, "Your query of .+ filtered by .+ returns (%d+) results.")
	LHpi.Log("html source data contains " .. results .. " cards.")
end -- LHpi.readexpectedfromhtml

--[[- detect BOMs to get char encoding
function LHpi.findFileEncoding( str )
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
	if type(str) == string then
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
		if site.encoding == "utf-8" then
			return str -- exit asap
		elseif site.encoding == "cp1252" or site.encoding == "ansi" then
			str = string.gsub( str , "\146" , "´" )
			str = string.gsub( str , "\196" , "Ä" )
			str = string.gsub( str , "\198" , "Æ" )
			str = string.gsub( str , "\214" , "Ö" )
			str = string.gsub( str , "\220" , "Ü" )
			str = string.gsub( str , "\223" , "ß" )
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
	elseif type( tbl ) == string then
		-- FIXME quotation marks are either not returned or not logged
		return "'" .. tbl .. "'"
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
-- TODO add special and promo sets
-- 
-- @type LHpi.sets
LHpi.sets = {}
--- @field [parent=#LHpi.sets] #table cardcount		number of (English) cards in MA database.
-- { #number = { reg = #number , tok = #number } , ... }
-- TODO ask for ma.GetCardCount( setid, langid, cardtype )
LHpi.sets.cardcount ={
-- Core sets
[788]={ reg = 249, tok = 11 },
[779]={ reg = 249, tok =  7 }, 
[770]={ reg = 249, tok =  6 }, 
[759]={ reg = 249, tok =  8 }, 
[720]={ reg = 384, tok =  6 }, 
[630]={ reg = 359, tok =  0 }, 
[550]={ reg = 357, tok =  0 }, 
[460]={ reg = 350, tok =  0 },
[360]={ reg = 350, tok =  0 }, 
[250]={ reg = 449, tok =  0 },
[180]={ reg = 378, tok =  0 }, 
[140]={ reg = 306, tok =  0 }, 
[139]={ reg = 306, tok =  0 }, 
[110]={ reg = 302, tok =  0 }, 
[100]={ reg = 302, tok =  0 }, 
[90] ={ reg = 295, tok =  0 }, 
 -- Expansions
[793]={ reg = 249, tok =  8 },
[791]={ reg = 274, tok = 12 },
[786]={ reg = 244, tok =  8 },
[784]={ reg = 158, tok =  3 }, 
[782]={ reg = 264, tok = 12 }, 
[776]={ reg = 175, tok =  4 },
[775]={ reg = 155, tok =  5 },
[773]={ reg = 249, tok =  9 },
[767]={ reg = 248, tok =  7 },
[765]={ reg = 145, tok =  6 },
[762]={ reg = 269, tok = 11 },
[758]={ reg = 145, tok =  4 },
[756]={ reg = 145, tok =  2 },
[754]={ reg = 249, tok = 10 },
[752]={ reg = 180, tok =  7 },
[751]={ reg = 301, tok = 12 },
[750]={ reg = 150, tok =  3 },
[730]={ reg = 301, tok = 11 },
[710]={ reg = 180, tok =  0 },
[700]={ reg = 165, tok =  0 },
[690]={ reg = 121, tok =  0 },
[680]={ reg = 301, tok =  0 },
[670]={ reg = 155, tok =  0 },
[660]={ reg = 180, tok =  0 },
[650]={ reg = 165, tok =  0 },
[640]={ reg = 306, tok =  0 },
[620]={ reg = 165, tok =  0 },
[610]={ reg = 165, tok =  0 },
[590]={ reg = 307, tok =  0 },
[580]={ reg = 165, tok =  0 },
[570]={ reg = 165, tok =  0 },
[560]={ reg = 306, tok =  0 },
[540]={ reg = 143, tok =  0 },
[530]={ reg = 145, tok =  0 },
[520]={ reg = 350, tok =  0 },
[510]={ reg = 143, tok =  0 },
[500]={ reg = 143, tok =  0 },
[480]={ reg = 350, tok =  0 },
[470]={ reg = 143, tok =  0 },
[450]={ reg = 146, tok =  0 },
[430]={ reg = 350, tok =  0 },
[420]={ reg = 143, tok =  0 },
[410]={ reg = 143, tok =  0 },
[400]={ reg = 350, tok =  0 },
[370]={ reg = 143, tok =  0 },
[350]={ reg = 143, tok =  0 },
[330]={ reg = 350, tok =  0 },
[300]={ reg = 143, tok =  0 },
[290]={ reg = 143, tok =  0 },
[280]={ reg = 350, tok =  0 },
[270]={ reg = 167, tok =  0 },
[240]={ reg = 167, tok =  0 },
[230]={ reg = 350, tok =  0 },
[220]={ reg = 199, tok =  0 },
[210]={ reg = 140, tok =  0 },
[190]={ reg = 383, tok =  0 },
[170]={ reg = 187, tok =  0 },
[160]={ reg = 119, tok =  0 },
[150]={ reg = 310, tok =  0 },
[130]={ reg = 100, tok =  0 },
[120]={ reg = 92 , tok =  0 },
}
for sid,count in pairs(LHpi.sets.cardcount) do
	count.both = count.reg + count.tok
end -- for sid,count
--- @field [parent=#LHpi.sets] #table variants		default card variant tables.
-- { #number = #table { #string = #table { #string, #table { #number or #boolean , ... } } , ... } , ...  }
LHpi.sets.variants = {
[788] = { -- M2013
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
[779] 	= { -- M2012
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
[770] 	= { -- M2011
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
},
[759] 	= { -- M2010
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
[720] 	= { -- 10th
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
[630] 	= { -- 9th
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } }
},
[550] 	= { -- 8th
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
},
[460] 	= { -- 7th
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
},
[360] 	= { -- 6th
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
},
[250] 	= { -- 5th
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
},
[140] 	= { -- Revised Edition
["Plains"] 						= { "Plains"	, { 1    , 2    , 3     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3     } }
},
[139] 	= { -- Revised Limited (german)
["Ebene"] 						= { "Ebene"		, { 1    , 2    , 3     } },
["Insel"] 						= { "Insel" 	, { 1    , 2    , 3     } },
["Sumpf"] 						= { "Sumpf"		, { 1    , 2    , 3     } },
["Gebirge"] 					= { "Gebirge"	, { 1    , 2    , 3     } },
["Wald"] 						= { "Wald"	 	, { 1    , 2    , 3     } }
},
[110] 	= { -- Unlimited
["Plains"] 						= { "Plains"	, { 1    , 2    , 3     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3     } }
},
[100] 	= { -- Beta
["Plains"] 						= { "Plains"	, { 1    , 2    , 3     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3     } },
},
 [90] 	= { -- Alpha
["Plains"] 						= { "Plains"	, { 1    , 2     } },
["Island"] 						= { "Island" 	, { 1    , 2     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2     } },
["Forest"] 						= { "Forest" 	, { 1    , 2     } },
},
[791] 	= { -- Return to Ravnica
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
[786] 	= { -- Avacyn Restored
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
},
[782] 	= { -- Innistrad
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
},
[776] 	= { -- New Phyrexia
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
[775] = { -- Mirrodin Besieged
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
[773] = { -- Scars of Mirrodin
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
},
[767] = { -- Rise of the Eldrazi
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
},
[762] = { -- Zendikar
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
[754] = { -- Shards of Alara
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
[751] = { -- Shadowmoor
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (282)"]							= { "Plains"	, { 1    , false ,false, false } }, 
["Plains (283)"]							= { "Plains"	, { false, 2    , false, false } },
["Plains (284)"]							= { "Plains"	, { false, false, 3    , false } },
["Plains (285)"]							= { "Plains"	, { false, false, false, 4     } },
["Island (286)"]							= { "Island"	, { 1    , false, false, false } },
["Island (287)"]							= { "Island"	, { false, 2    , false, false } },
["Island (288)"]							= { "Island"	, { false, false, 3    , false } },
["Island (289)"]							= { "Island"	, { false, false, false, 4     } },
["Swamp (290)"]								= { "Swamp"		, { 1    , false, false, false } },
["Swamp (291)"]								= { "Swamp"		, { false, 2    , false, false } },
["Swamp (292)"]								= { "Swamp"		, { false, false, 3    , false } },
["Swamp (293)"]								= { "Swamp"		, { false, false, false, 4     } },
["Mountain (294)"]							= { "Mountain"	, { 1    , false, false, false } },
["Mountain (295)"]							= { "Mountain"	, { false, 2    , false, false } },
["Mountain (296)"]							= { "Mountain"	, { false, false, 3    , false } },
["Mountain (297)"]							= { "Mountain"	, { false, false, false, 4     } },
["Forest (298)"]							= { "Forest"	, { 1    , false, false, false } },
["Forest (299)"]							= { "Forest"	, { false, 2    , false, false } },
["Forest (300)"]							= { "Forest"	, { false, false, 3    , false } },
["Forest (301)"]							= { "Forest"	, { false, false, false, 4     } },
},
[730] = { -- Lorwyn
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (282)"]							= { "Plains"	, { 1    , false ,false, false } }, 
["Plains (283)"]							= { "Plains"	, { false, 2    , false, false } },
["Plains (284)"]							= { "Plains"	, { false, false, 3    , false } },
["Plains (285)"]							= { "Plains"	, { false, false, false, 4     } },
["Island (286)"]							= { "Island"	, { 1    , false, false, false } },
["Island (287)"]							= { "Island"	, { false, 2    , false, false } },
["Island (288)"]							= { "Island"	, { false, false, 3    , false } },
["Island (289)"]							= { "Island"	, { false, false, false, 4     } },
["Swamp (290)"]								= { "Swamp"		, { 1    , false, false, false } },
["Swamp (291)"]								= { "Swamp"		, { false, 2    , false, false } },
["Swamp (292)"]								= { "Swamp"		, { false, false, 3    , false } },
["Swamp (293)"]								= { "Swamp"		, { false, false, false, 4     } },
["Mountain (294)"]							= { "Mountain"	, { 1    , false, false, false } },
["Mountain (295)"]							= { "Mountain"	, { false, 2    , false, false } },
["Mountain (296)"]							= { "Mountain"	, { false, false, 3    , false } },
["Mountain (297)"]							= { "Mountain"	, { false, false, false, 4     } },
["Forest (298)"]							= { "Forest"	, { 1    , false, false, false } },
["Forest (299)"]							= { "Forest"	, { false, 2    , false, false } },
["Forest (300)"]							= { "Forest"	, { false, false, 3    , false } },
["Forest (301)"]							= { "Forest"	, { false, false, false, 4     } },
},
[680] = { -- Time Spiral
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
[640] = { -- Ravnica: City of Guilds
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
[590] = { -- Champions of Kamigawa
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
["Brothers Yamazaki"]			= { "Brothers Yamazaki"	, { "a"  , "b" } },
},
[520] = { -- Onslaught
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
},
[330] = { -- Urza's Saga
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } }
},
[210] = { -- Homelands
["Mesa Falcon"] 				 = { "Mesa Falcon"			, { 1    , 2     } },
["Abbey Matron"] 				 = { "Abbey Matron"			, { 1    , 2     } },
["Dwarven Trader"] 				 = { "Dwarven Trader"		, { 1    , 2     } },
["Reef Pirates"] 				 = { "Reef Pirates"			, { 1    , 2     } },
["Willow Faerie"] 				 = { "Willow Faerie"		, { 1    , 2     } },
["Shrink"] 						 = { "Shrink"				, { 1    , 2     } },
["Sengir Bats"] 				 = { "Sengir Bats"			, { 1    , 2     } },
["Hungry Mist"] 				 = { "Hungry Mist"			, { 1    , 2     } },
["Folk of An-Havva"] 			 = { "Folk of An-Havva"		, { 1    , 2     } },
["Cemetery Gate"] 				 = { "Cemetery Gate"		, { 1    , 2     } },
["Aysen Bureaucrats"] 			 = { "Aysen Bureaucrats"	, { 1    , 2     } },
["Torture"] 					 = { "Torture"				, { 1    , 2     } },
["Anaba Bodyguard"] 			 = { "Anaba Bodyguard"		, { 1    , 2     } },
["Anaba Shaman"] 				 = { "Anaba Shaman"			, { 1    , 2     } },
["Ambush Party"] 				 = { "Ambush Party"			, { 1    , 2     } },
["Aliban's Tower"] 				 = { "Aliban's Tower"		, { 1    , 2     } },
["Feast of the Unicorn"] 		 = { "Feast of the Unicorn"	, { 1    , 2     } },
["Carapace"] 					 = { "Carapace"				, { 1    , 2     } },
["Memory Lapse"] 				 = { "Memory Lapse"			, { 1    , 2     } },
["Labyrinth Minotaur"] 			 = { "Labyrinth Minotaur"	, { 1    , 2     } },
["Giant Albatross"] 			 = { "Giant Albatross"		, { 1    , 2     } },
["Samite Alchemist"] 			 = { "Samite Alchemist"		, { 1    , 2     } },
["Dark Maze"] 					 = { "Dark Maze"			, { 1    , 2     } },
["Dry Spell"] 					 = { "Dry Spell"			, { 1    , 2     } },
["Trade Caravan"] 				 = { "Trade Caravan"		, { 1    , 2     } }
},
[170] = { -- Fallen Empires
["Armor Thrull"] 				= { "Armor Thrull"					, { 1    , 2    , 3    , 4     } },
["Basal Thrull"] 				= { "Basal Thrull"					, { 1    , 2    , 3    , 4     } },
["Brassclaw Orcs"] 				= { "Brassclaw Orcs"				, { 1    , 2    , 3    , 4     } },
["Combat Medic"] 				= { "Combat Medic"					, { 1    , 2    , 3    , 4     } },
["Dwarven Soldier"] 			= { "Dwarven Soldier"				, { 1    , 2    , 3     } },
["Elven Fortress"] 				= { "Elven Fortress"				, { 1    , 2    , 3    , 4     } },
["Elvish Hunter"] 				= { "Elvish Hunter"					, { 1    , 2    , 3     } },
["Elvish Scout"] 				= { "Elvish Scout"					, { 1    , 2    , 3     } },
["Farrel's Zealot"] 			= { "Farrel's Zealot"				, { 1    , 2    , 3     } },
["Goblin Chirurgeon"] 			= { "Goblin Chirurgeon"				, { 1    , 2    , 3     } },
["Goblin Grenade"] 				= { "Goblin Grenade"				, { 1    , 2    , 3     } },
["Goblin War Drums"] 			= { "Goblin War Drums"				, { 1    , 2    , 3    , 4     } },
["High Tide"] 					= { "High Tide"						, { 1    , 2    , 3     } },
["Homarid"] 					= { "Homarid"						, { 1    , 2    , 3    , 4     } },
["Homarid Warrior"] 			= { "Homarid Warrior"				, { 1    , 2    , 3     } },
["Hymn to Tourach"] 			= { "Hymn to Tourach"				, { 1    , 2    , 3    , 4     } },
["Icatian Infantry"] 			= { "Icatian Infantry"				, { 1    , 2    , 3    , 4     } },
["Icatian Javelineers"] 		= { "Icatian Javelineers"			, { 1    , 2    , 3     } },
["Icatian Moneychanger"] 		= { "Icatian Moneychanger"			, { 1    , 2    , 3     } },
["Icatian Scout"] 				= { "Icatian Scout"					, { 1    , 2    , 3    , 4     } },
["Initiates of the Ebon Hand"] 	= { "Initiates of the Ebon Hand"	, { 1    , 2    , 3     } },
["Merseine"] 					= { "Merseine"						, { 1    , 2    , 3    , 4     } },
["Mindstab Thrull"] 			= { "Mindstab Thrull"				, { 1    , 2    , 3     } },
["Necrite"] 					= { "Necrite"						, { 1    , 2    , 3     } },
["Night Soil"] 					= { "Night Soil"					, { 1    , 2    , 3     } },
["Orcish Spy"] 					= { "Orcish Spy"					, { 1    , 2    , 3     } },
["Orcish Veteran"] 				= { "Orcish Veteran"				, { 1    , 2    , 3    , 4     } },
["Order of the Ebon Hand"] 		= { "Order of the Ebon Hand"		, { 1    , 2    , 3     } },
["Order of Leitbur"] 			= { "Order of Leitbur"				, { 1    , 2    , 3     } },
["Spore Cloud"] 				= { "Spore Cloud"					, { 1    , 2    , 3     } },
["Thallid"] 					= { "Thallid"						, { 1    , 2    , 3    , 4     } },
["Thorn Thallid"] 				= { "Thorn Thallid"					, { 1    , 2    , 3    , 4     } },
["Tidal Flats"] 				= { "Tidal Flats"					, { 1    , 2    , 3     } },
["Vodalian Soldiers"] 			= { "Vodalian Soldiers"				, { 1    , 2    , 3    , 4     } },
["Vodalian Mage"] 				= { "Vodalian Mage"					, { 1    , 2    , 3     } }
},
[130] = { -- Antiquities
["Mishra's Factory"] 			= { "Mishra's Factory"		, { 1    , 2    , 3    , 4     } },
["Mishra's Factory (Spring)"] 	= { "Mishra's Factory"		, { 1    , false, false, false } },
["Mishra's Factory (Summer)"] 	= { "Mishra's Factory"		, { false, 2    , false, false } },
["Mishra's Factory (Autumn)"] 	= { "Mishra's Factory"		, { false, false, 3    , false } },
["Mishra's Factory (Winter)"] 	= { "Mishra's Factory"		, { false, false, false, 4     } },
["Strip Mine"] 					= { "Strip Mine"			, { 1    , 2    , 3    , 4     } },
["Urza's Mine"] 				= { "Urza's Mine"			, { 1    , 2    , 3    , 4     } },
["Urza's Power Plant"] 			= { "Urza's Power Plant"	, { 1    , 2    , 3    , 4     } },
["Urza's Tower"] 				= { "Urza's Tower"			, { 1    , 2    , 3    , 4     } },
},
[220] = { -- Alliances
["Gorilla Chieftain"] 			= { "Gorilla Chieftain"		, { 1    , 2     } },
["Reprisal"] 					= { "Reprisal"				, { 1    , 2     } },
["Phyrexian Boon"] 				= { "Phyrexian Boon"		, { 1    , 2     } },
["Phyrexian War Beast"] 		= { "Phyrexian War Beast"	, { 1    , 2     } },
["Carrier Pigeons"] 			= { "Carrier Pigeons"		, { 1    , 2     } },
["Wild Aesthir"] 				= { "Wild Aesthir"			, { 1    , 2     } },
["Martyrdom"] 					= { "Martyrdom"				, { 1    , 2     } },
["Yavimaya Ancients"] 			= { "Yavimaya Ancients"		, { 1    , 2     } },
["Gift of the Woods"] 			= { "Gift of the Woods"		, { 1    , 2     } },
["Feast or Famine"] 			= { "Feast or Famine"		, { 1    , 2     } },
["Arcane Denial"] 				= { "Arcane Denial"			, { 1    , 2     } },
["Errand of Duty"] 				= { "Errand of Duty"		, { 1    , 2     } },
["Viscerid Armor"] 				= { "Viscerid Armor"		, { 1    , 2     } },
["Benthic Explorers"] 			= { "Benthic Explorers"		, { 1    , 2     } },
["Agent of Stromgald"] 			= { "Agent of Stromgald"	, { 1    , 2     } },
["Stench of Decay"] 			= { "Stench of Decay"		, { 1    , 2     } },
["Soldevi Heretic"] 			= { "Soldevi Heretic"		, { 1    , 2     } },
["Fevered Strength"] 			= { "Fevered Strength"		, { 1    , 2     } },
["Lim-Dul's High Guard"]	 	= { "Lim-Dul's High Guard"	, { 1    , 2     } },
["Bestial Fury"] 				= { "Bestial Fury"			, { 1    , 2     } },
["Storm Crow"] 					= { "Storm Crow"			, { 1    , 2     } },
["Phantasmal Fiend"] 			= { "Phantasmal Fiend"		, { 1    , 2     } },
["Deadly Insect"] 				= { "Deadly Insect"			, { 1    , 2     } },
["Guerrilla Tactics"] 			= { "Guerrilla Tactics"		, { 1    , 2     } },
["Soldevi Sentry"] 				= { "Soldevi Sentry"		, { 1    , 2     } },
["Kjeldoran Pride"] 			= { "Kjeldoran Pride"		, { 1    , 2     } },
["Insidious Bookworms"] 		= { "Insidious Bookworms"	, { 1    , 2     } },
["Casting of Bones"] 			= { "Casting of Bones"		, { 1    , 2     } },
["Fyndhorn Druid"] 				= { "Fyndhorn Druid"		, { 1    , 2     } },
["Varchild's Crusader"] 		= { "Varchild's Crusader"	, { 1    , 2     } },
["Whip Vine"] 					= { "Whip Vine"				, { 1    , 2     } },
["Storm Shaman"]	 			= { "Storm Shaman"			, { 1    , 2     } },
["Soldevi Adnate"]	 			= { "Soldevi Adnate"		, { 1    , 2     } },
["Undergrowth"] 				= { "Undergrowth"			, { 1    , 2     } },
["Soldevi Steam Beast"] 		= { "Soldevi Steam Beast"	, { 1    , 2     } },
["Astrolabe"] 					= { "Astrolabe"				, { 1    , 2     } },
["Aesthir Glider"] 				= { "Aesthir Glider"		, { 1    , 2     } },
["Taste of Paradise"] 			= { "Taste of Paradise"		, { 1    , 2     } },
["Gorilla Berserkers"] 			= { "Gorilla Berserkers"	, { 1    , 2     } },
["Elvish Ranger"] 				= { "Elvish Ranger"			, { 1    , 2     } },
["Veteran's Voice"] 			= { "Veteran's Voice"		, { 1    , 2     } },
["Gorilla War Cry"] 			= { "Gorilla War Cry"		, { 1    , 2     } },
["Gorilla Shaman"] 				= { "Gorilla Shaman"		, { 1    , 2     } },
["Enslaved Scout"] 				= { "Enslaved Scout"		, { 1    , 2     } },
["Lat-Nam's Legacy"] 			= { "Lat-Nam's Legacy"		, { 1    , 2     } },
["Balduvian War-Makers"] 		= { "Balduvian War-Makers"	, { 1    , 2     } },
["Reinforcements"] 				= { "Reinforcements"		, { 1    , 2     } },
["Swamp Mosquito"] 				= { "Swamp Mosquito"		, { 1    , 2     } },
["Noble Steeds"] 				= { "Noble Steeds"			, { 1    , 2     } },
["Soldevi Sage"] 				= { "Soldevi Sage"			, { 1    , 2     } },
["Foresight"] 					= { "Foresight"				, { 1    , 2     } },
["False Demise"] 				= { "False Demise"			, { 1    , 2     } },
["Awesome Presence"] 			= { "Awesome Presence"		, { 1    , 2     } },
["Royal Herbalist"] 			= { "Royal Herbalist"		, { 1    , 2     } },
["Kjeldoran Escort"] 			= { "Kjeldoran Escort"		, { 1    , 2     } }
},
[120] = { -- Arabian Nights
["Army of Allah"] 				= { "Army of Allah"			, { 1    , 2     } },
["Bird Maiden"] 				= { "Bird Maiden"			, { 1    , 2     } },
["Erg Raiders"] 				= { "Erg Raiders"			, { 1    , 2     } },
["Fishliver Oil"] 				= { "Fishliver Oil"			, { 1    , 2     } },
["Giant Tortoise"] 				= { "Giant Tortoise"		, { 1    , 2     } },
["Hasran Ogress"] 				= { "Hasran Ogress"			, { 1    , 2     } },
["Moorish Cavalry"] 			= { "Moorish Cavalry"		, { 1    , 2     } },
["Nafs Asp"] 					= { "Nafs Asp"				, { 1    , 2     } },
["Oubliette"] 					= { "Oubliette"				, { 1    , 2     } },
["Rukh Egg"] 					= { "Rukh Egg"				, { 1    , 2     } },
["Piety"] 						= { "Piety"					, { 1    , 2     } },
["Stone-Throwing Devils"] 		= { "Stone-Throwing Devils"	, { 1    , 2     } },
["War Elephant"] 				= { "War Elephant"			, { 1    , 2     } },
["Wyluli Wolf"] 				= { "Wyluli Wolf"			, { 1    , 2     } },
},
} -- end table LHpi.sets.variants

-- set sensible defaults or throw error on missing sitescript fields or functions
if not scriptname then
--- must always be equal to the scripts filename !
-- @field [parent=#global] #string scriptname	
	local _s,_e,myname = string.find( ( ma.GetFile( "Magic Album.log" ) or "" ) , "Starting Lua script .-([^\\]+%.lua)$" )
	if myname and myname ~= "" then
		scriptname = myname
	else -- use hardcoded scriptname as fallback
		scriptname = "LHpi.SITESCRIPT_NAME_NOT_SET-v2.0.lua"
	end
end -- if
if not savepath then
--- savepath for OFFLINE (read) and SAVEHTML (write). must point to an existing directory relative to MA's root.
-- @field [parent=#global] #string savepath
	savepath = "Prices\\" .. string.gsub( scriptname , "%-v%d+%.%d+%.lua$" , "" ) .. "\\"
end -- if
if not site then site = {} end
--if (not site.regex) or site.regex == "" then error("undefined site.regex!") end
if not site.regex then site.regex = "" end
if not site.encoding then site.encoding = "cp1252" end
if not site.currency then site.currency = "$" end
--if (not site.langs) or (not next(site.langs)) then error("undefined site.langs!") end
if not site.langs then site.langs = {} end
--if (not site.sets) or (not next(site.sets)) then error("undefined site.sets!") end
if not site.sets then site.sets = {} end
--if (not site.frucs) or (not next(site.frucs)) then error("undefined site.frucs!") end
if not site.frucs then site.frucs = {} end
if not site.namereplace then site.namereplace={} end
if not site.variants then site.variants = {} end
for sid,variant in pairs(LHpi.sets.variants) do
	if not site.variants[sid] then
		site.variants[sid] = variant
	end
end
if not site.foiltweak then site.foiltweak={} end
if not site.expected then site.expected = {} end

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
if not site.BCDpluginName then
	function site.BCDpluginName ( name , setid )
		return name
	end -- function
end -- if
if not site.BCDpluginCard then
	function site.BCDpluginCard( card , setid )
		return card
	end -- function
end -- if

--LHpi.Log( "\239\187\191LHpi library loaded and executed successfully" , 0 , nil , 0 ) -- add unicode BOM to beginning of logfile
LHpi.Log( "LHpi library loaded and executed successfully." , 0 , nil , 0 )
return LHpi