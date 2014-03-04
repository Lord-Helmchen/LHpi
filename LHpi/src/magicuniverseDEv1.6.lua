--*- coding: utf-8 -*-
--[[- Price import script for Magic Album
to import card pricing from www.magicuniverse.de.

Inspired by and loosely based on "MTG Mint Card.lua" by Goblin Hero, Stromglad1 and "Import Prices.lua" by woogerboy21;
who generously granted permission to "do as I like" with their code;
everything else Copyright (C) 2012 by Christian Harms.
If you want to contact me about the script, try its release thread in http://www.slightlymagic.net/forum/viewforum.php?f=32

@module magicuniverseDE.lua
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

--[[- feedback options.
 control the amount of feedback/logging done by the script
 @type option
 @field [parent=#global] #boolean VERBOSE			default false
 @field [parent=#global] #boolean LOGDROPS 			default false
 @field [parent=#global] #boolean LOGNAMEREPLACE 	default false
]]
VERBOSE = false
LOGDROPS = false
LOGNAMEREPLACE = false
--[[-
 control options.
 control the script's behaviour.
 Don't change anything below this line unless you know what you're doing :-)
 @type option
 @field #boolean CHECKEXPECTED	compare card count with expected numbers; default true
 @field #boolean DEBUG			log all and exit on error; default false
 @field #boolean DEBUGVARIANTS	DEBUG inside variant loops; default false
 @field #boolean OFFLINE		read source data from #string.savepath instead of site url; default false
 @field #boolean SAVEHTML		save a local copy of each source html to #string.savepath; default false
 @field #boolean SAVELOG		log to seperate logfile instead of Magic Album.log;	default true
 @field #boolean SAVETABLE		save price table to file before importing to MA;	default false
]]
CHECKEXPECTED = true
DEBUG = false
DEBUGVARIANTS = false
OFFLINE = false
SAVEHTML = false
SAVELOG = true
-- TODO write a seperate function that loops through the table and uses incremental putFile instead of 
SAVETABLE = false -- needs incremental putFile to be remotely readable :)

--- @field [parent=#global] #string scriptname	
--FIXME does not work, GetFile returns nil for its own log :(
--local _s,_e,myname = string.find( ma.GetFile("Magic Album.log"), "Starting Lua script .-([^\\]+%.lua)$" )
if myname then
	scriptname = myname
else -- use hardcoded scriptname as fallback
	scriptname = "magicuniverseDEv1.6.lua" -- should always be equal to the scripts filename !
end
savepath = "Prices\\" .. string.gsub(scriptname, "v%d+%.%d+%.lua$","") .. "\\" -- for OFFLINE (read) and SAVEHTML (write). must point to an existing directory relative to MA's root.

-- global configuration ends here; site-specific configuration externalized to .lconf

--[[ TODO
patch to accept entries with a condition description if no other entry with better condition is in the table:
	buildCardData will need to add condition to carddata
	global conditions{} to define priorities
	then fillCardsetTable needs a new check before overwriting existing data
!! check conflict handling with Onulet from 140

get scriptname from ma-log by gmatching "Starting Lua script C:\Spiele\Magic - The Gathering\Magic Album\Prices\(magicuniverseDEv1.3).lua$"

prepare for more languages
	DONE	totals
	importprice - might need a switch to support site with one page per language
	needs to loop through languages
	to save bandwith: build table of urls first, then have loop through it to call parsehtml
	DONE	change expected to match new format of totalcount
	test with legends(150) italian
	do another set of gmatch for (französisch) et al if consistently named
	DONE	change nameE,nameG to names { [1],[3]
	make price a (sub-)table as well


externalize all hardcoded website-specific configuration into global variables:
	DONE	url (and filename)
	DONE	parsehtml regex string
	DONE	site and set specific patches moved to .lconf [not: will have to be block-commented or iffed by a global variable]
	DONE	add (potentially empty) funtion call to buildCardData and externalize to .lconf
	seperate avsets{} into site-specific (like url and fruc{} ) and valid-for-all-sites data (like id and cards{})

for kicks and giggles, have SAVETABLE generate a csv usable by woogerboys importprices :-)

CHANGELOG
renamed .config to .lconf to ease syntax highlighting
got rid of utf-8 BOM
changed some comments to luadoc-like
added Gatecrash to avsets and expectedcounts (shop does not yet provide foil)
]]

--TODO condprio = { [0] = "NONE", } -- table to sort condition description. lower indexed will overwrite when building the cardsetTable

--[[-
 "main" function.
 called by Magic Album to import prices. Parameters are passed from MA.
 
 @function [parent=#global] ImportPrice
 @param #string importfoil	"Y"|"N"|"O"		Update Regular and Foil|Update Regular|Update Foil
 @param #table importlangs	array of languages script should import, represented as pairs {languageid, languagename} 
	(see "Database\Languages.txt").
	only {1, "English"} and {3, German} are supported by this script yet. (and more or less ignored anyway)
 @param #table importsets	array of sets script should import, represented as pairs {setid, setname}
	(see "Database\Sets.txt").
]]
function ImportPrice(importfoil, importlangs, importsets)
	if SAVELOG then
		ma.Log( "Check " .. scriptname .. ".log for detailed information" )
		--llog("\239\187\191Script started" ,0,0) -- add unicode BOM - still saved as ANSI :-/
		llog("Script started" ,0,0)
	end
	do -- load site specific configuration and functions from external file
		local configfile = "Prices\\" .. string.gsub(scriptname, ".lua$", ".lconf")
		local config = ma.GetFile( configfile )
		if not config then
			error ("configuration " .. configfile .. " not found")
		else -- execute config to set global variables
			if VERBOSE then llog("config " .. configfile .. " loaded") end
			config = string.gsub(config, "^\239\187\191", "") -- remove unicode BOM (0xEF, 0xBB, 0xBF) for files tainted by it :)
			local execconfig,errormsg = load ( config )
			if not execconfig then
				error (errormsg)
			end
			execconfig ( )
		end	-- if not config else
	end -- do loadconfig
	collectgarbage () -- we now have the global tables, no need to keep copies inside config and execconfig() in memory

	-- identify user defined types of foiling to import
	if string.lower(importfoil) == "y" then
		llog("Importing Non-Foil (+) Foil Card Prices")
	elseif string.lower(importfoil) == "o" then
		llog("Importing Foil Only Card Prices")
		for f = 2,tlength(frucnames) do -- disable all non-foil frucs
			for sid,_ in pairs(avsets) do
				avsets[sid].fruc[f] = false
			end --for sid
		end -- for i
	elseif string.lower(importfoil) == "n" then -- disable all foil frucs
		llog("Importing Non-Foil Only Card Prices")
		for sid,_ in pairs(avsets) do
			avsets[sid].fruc[1] = false
		end --for sid
	end -- if importfoil
	-- identify user defined sets to import
	for _,sname in pairs(importsets) do
		if not allsets then
			allsets = sname
		else
			allsets = allsets .. "," .. sname
		end
	end
	llog("Importing Sets: [" .. allsets .. "]")
	-- identify user defined languages to import
	do -- block to free unneeded variables sooner
		local nosuplangs = true
		local allangs = nil
		for lid,lname in pairs(importlangs) do
			if suplangs[lid] then nosuplangs = false end
			if not alllangs then
				alllangs = lname
			else
				alllangs = alllangs .. "," .. lname
			end
		end -- for lid,lname
		llog("Importing Languages: [" .. alllangs .. "]")
		if nosuplangs then
			local suplanglist = nil
			for lid,lang in pairs(suplangs) do
				if lang then
					if not suplanglist then
						suplanglist = lang.full
					else
						suplanglist = suplanglist .. "," .. lang.full
					end
				end
			end
			llog("No supported language selected; returning from script now.")
			error ( "No supported language selected, please select at least one of " .. suplanglist )
		end -- if nosuplangs
	end -- do
	if not VERBOSE then
		llog("If you want to see more detailed logging, edit Prices\\" .. scriptname .. " and set VERBOSE = true.",0)
	end
	-- Calculate total number of html pages to parse (need this for progress bar)
	totalhtmlnum = 0
	for _, cSet in pairs(avsets) do
		if importsets[cSet.id] then
			local persetnum = 0
			for f,fruc in pairs(cSet.fruc) do
				if fruc then
					persetnum = persetnum + 1
				end
			end -- for f,fruc
			totalhtmlnum = totalhtmlnum + persetnum
		end -- if importsets[rec.id]
	end -- for _,rec

	-- Main import cycle
	curhtmlnum = 0
	progress = 0
	totalcount = { pset= {0,nil,0}, failed={0,nil,0}, dropped=0, namereplace=0 }
	if CHECKEXPECTED then
		setcountdiffers = {}
	end
	for _, cSet in pairs(avsets) do
		if importsets[cSet.id] then
			persetcount = { pset= {0,nil,0}, failed={0,nil,0}, dropped=0, namereplace=0 }
			cardsetTable = {} -- clear cardsetTable
			-- build cardsetTable containing all prices to be imported
			--[[
			--			if importlangs [1] or importlangs[3] then -- ger or eng wanted
			--	"if" unnedded, unsupported importlangs have been caught already
			-- TODO instead, loop through importlangs/suplangs for sites that have different langs on seperate pages
			-- then avsets.set.german will need to be made a lang table
			-- for now, just pass on importlangs
			--]]
			for f,fruc in pairs(cSet.fruc) do
				if fruc then
					parsehtml(cSet, importsets[cSet.id], f , importlangs)
				end
			end -- for f,fruc
			--			end if importlangs
			-- build cardsetTable from htmls finished
			if VERBOSE then
				llog( "cardsetTable for set " .. importsets[cSet.id] .. "(id " .. cSet.id .. ") build with " .. tlength(cardsetTable) .. " rows. set supposedly contains " .. cSet.cards.reg .. " cards and " .. cSet.cards.tok .. " tokens." ,1)
			end
			if SAVETABLE then
				local filename = savepath .. "table-set=" .. importsets[cSet.id] .. ".txt"
				llog( "Saving table to file: \"" .. filename .. "\"" )
				ma.PutFile( filename , deeptostring(cardsetTable) )
			end
			-- Set the price
			local pmesg = "Importing " .. importsets[cSet.id] .. " from table"
			if VERBOSE then
				llog( pmesg .. "  " .. progress ,1)
			end -- if VERBOSE
			ma.SetProgress( pmesg, progress )
			for cName,cCard in pairs(cardsetTable) do
				if DEBUG then llog( "ImportPrice\t cName is " .. cName .. " and table cCard is " .. deeptostring(cCard) ,2) end
				for lid,_cLang in pairs(importlangs) do
					if cCard.lang[lid] then
						setPrice( cSet.id, lid, cName, cCard )
					end
				end
			end -- for cName,cCard in pairs(cardsetTable)
			local statmsg = "Set " .. importsets[cSet.id]
			if VERBOSE then
				statmsg = statmsg .. " contains \t" .. cSet.cards.reg+cSet.cards.tok .. " cards (\t" .. cSet.cards.reg .. " regular,\t " .. cSet.cards.tok .. " tokens )"
				statmsg = statmsg .. "\n\t successfully set new price for " .. persetcount.pset[1] .. " English and " .. persetcount.pset[3] .. " German cards. " .. persetcount.failed[3] .. " German and " .. persetcount.failed[1] .. " English cards failed; DROPped " .. persetcount.dropped .. "."
				statmsg = statmsg .. "\nnamereplace table contains " .. (tlength(namereplace[cSet.id]) or "no") .. " names and was triggered " .. persetcount.namereplace .. " times."
			else
				statmsg = statmsg .. " imported."
			end
			llog ( statmsg )
			if DEBUG then
				llog( "persetstats " .. deeptostring(persetcount) ,2)
			end
			if CHECKEXPECTED then
				if expectedcount[cSet.id] then
					local allgood = true
					for lid,_cLang in pairs(importlangs) do
						if expectedcount[cSet.id].pset[lid] ~= persetcount.pset[lid] then allgood = false end
						if expectedcount[cSet.id].failed[lid] ~= persetcount.failed[lid] then allgood = false end
					end -- for lid,_cLang in importlangs
					if expectedcount[cSet.id].dropped ~= persetcount.dropped then allgood = false end
					if expectedcount[cSet.id].namereplace ~= persetcount.namereplace then allgood = false end
					if not allgood then
						llog( ":-( persetcount for " .. importsets[cSet.id] .. "(id " .. cSet.id .. ") differs from expected. ",1)
						table.insert(setcountdiffers, cSet.id, importsets[cSet.id])
						if VERBOSE then
							llog( ":-( counted  :\t" .. deeptostring(persetcount) ,1)
							llog( ":-( expected :\t" .. deeptostring(expectedcount[cSet.id]) ,1)
						end
						if DEBUG then
							error ("notallgood in set " .. importsets[cSet.id] .. "(" ..  cSet.id .. ")")
						end
					else
						llog( ":-) Prices for set " .. importsets[cSet.id] .. "(id " .. cSet.id .. ") were imported as expected :-)" ,1)
					end
				else
					llog( "No expected persetcount for " .. importsets[cSet.id] .. "(id " .. cSet.id .. ") found." ,1)
				end -- if expectedcount[cSet.id] else
			end -- if CHECKEXPECTED
			for lid,_ in pairs(suplangs) do
				totalcount.pset[lid] = totalcount.pset[lid] + persetcount.pset[lid]
				totalcount.failed[lid] = totalcount.failed[lid] + persetcount.failed[lid]
			end -- for lid
			totalcount.dropped = totalcount.dropped + persetcount.dropped
			totalcount.namereplace = totalcount.namereplace + persetcount.namereplace
		end -- if importsets[cSet.id]
	end -- for _, cSet inpairs(avsets)
	if VERBOSE or CHECKEXPECTED then
		llog( "totalcount \t" .. deeptostring(totalcount) ,1)
	end
	if CHECKEXPECTED then
		local totalexpected = {pset={0,nil,0},failed={0,nil,0},dropped=0,namereplace=0}
		for sid,set in pairs(importsets) do
			if expectedcount[sid] then
				for lid,_ in pairs(suplangs) do
					totalexpected.pset[lid] = totalexpected.pset[lid] + expectedcount[sid].pset[lid]
					totalexpected.failed[lid] = totalexpected.failed[lid] + expectedcount[sid].failed[lid]
				end -- for lid
				totalexpected.dropped = totalexpected.dropped + expectedcount[sid].dropped
				totalexpected.namereplace = totalexpected.namereplace + expectedcount[sid].namereplace
			end -- if expectedcount[sid]
		end -- for sid,set
		llog ("totalexpected \t" .. deeptostring(totalexpected) ,1)
		llog ("count differs in sets" .. deeptostring(setcountdiffers), 1)
	end -- if CHECKEXPECTED
	ma.Log("End of Lua script " .. scriptname )
end -- function ImportPrice

--[[-
 calls MA to set card price.
 
 @function [parent=#global] setPrice
 @param	#number setid	(see "Database\Sets.txt")
 @param	#number langid	(see "Database\Languages.txt")
 @param #string name	card name Ma will try to match to Oracle Name, then localized Name
 @param #table  card	card data from cardsetTable
 @return #number MA.SetPrice retval (summed over variant loop)
]]
function setPrice(setid, langid, name, card)
	local retval
	if card.variant and DEBUGVARIANTS then DEBUG = true end
	if DEBUG then
		llog( "setPrice\t setid is " .. setid .. " langid is " .. langid .. " name is " .. name .. " variant is " .. deeptostring(card.variant) .. " regprice is " .. deeptostring(card.regprice) .. " foilprice is " .. deeptostring(card.foilprice) ,2)
	end
	if not card.variant then
		retval = ma.SetPrice(setid, langid, name, "", card.regprice or 0, card.foilprice or 0)
	else
		if DEBUG then
			llog( "variant is " .. deeptostring(card.variant) .. " regprice is " .. deeptostring(card.regprice) .. " foilprice is " .. deeptostring(card.foilprice) ,2)
		end
		if not card.regprice then card.regprice = {} end
		if not card.foilprice then card.foilprice = {} end
		for varnr, varname in pairs(card.variant) do
			if DEBUG then
				llog("varnr is " .. varnr .. " varname is " .. tostring(varname) ,2)
			end
			if varname then
				retval = (retval or 0) + ma.SetPrice(setid, langid, name, varname, card.regprice[varname] or 0, card.foilprice[varname] or 0 )
			end -- if
		end -- for
	end -- if

	-- count ma.SetPrice retval and log potential problems
	if retval == 0 or (not retval) then
		persetcount.failed[langid] = persetcount.failed[langid] + 1
		if DEBUG then
			llog( "! SetPrice \"" .. name .. "\" for language " .. suplangs[langid].abbr .. " with n/f price " .. deeptostring(card.regprice) .. "/" .. deeptostring(card.foilprice) .. " not ( " .. tostring(retval) .. " times) set" ,2)
		end
	else
		persetcount.pset[langid] = persetcount.pset[langid] + retval
		if DEBUG then
			llog( "setPrice\t name \"" .. name .. "\" version \"" .. deeptostring(card.variant) .. "\" set to " .. deeptostring(card.regprice) .. "/" .. deeptostring(card.foilprice).. " non/foil " .. tostring(retval) .. " times for laguage " .. suplangs[langid].abbr ,2)
		end
	end
	--llog(deeptostring(persetcount.pset))
	if VERBOSE or DEBUG then
		local expected
		if not card.variant then
			expected = 1
		else
			expected = tlength(card.variant)
		end
		if (retval ~= expected) then
			llog( "! setPrice \"" .. name .. "\" for language " .. suplangs[langid].abbr .. " returned unexpected retval \"" .. tostring(retval) .. "\"; expected was " .. expected ,1)
		elseif DEBUG then
			llog( "setPrice \"" .. name .. "\" for language " .. suplangs[langid].abbr .. " returned expected retval \"" .. tostring(retval) .. "\"" ,2)
		end
	end
	if DEBUGVARIANTS then DEBUG = false end
	return retval
end -- function setPrice

--[[-
 fill cardsetTable from one source html file.
 download and parse one source file
 
 @function [parent=#global] parsehtml
 @param #table set		set record from avsets
 @param #string setname	needed only for progressbar
 @param #number fruc	1|2|3|4|5 for foil|rare|uncommon|common|purple rarity
 @param #table importlangs	passed on from ImportPrice (until I change language handling)
 @return #number 1 if sourceTable is empty, 0 if all ok;  never read anyway
]]
function parsehtml(set, setname, fruc , importlangs)
	curhtmlnum = curhtmlnum + 1
	progress = 100*curhtmlnum/totalhtmlnum
	local pmesg = "Parsing " .. frucnames[fruc] .. " " .. setname
	if VERBOSE then
		pmesg = pmesg .. " (id " .. set.id .. ")"
		llog( pmesg .. "  " .. progress .. "%" ,1)
	end
	ma.SetProgress(pmesg, progress)
	local sourceTable = getSourceData ( set.id , fruc , importlangs)
	if not sourceTable then
		llog("No cards found, skipping to next source" ,1)
		if DEBUG then
			error ("empty sourceTable for " .. setname .. " - " .. frucnames[fruc])
		end
		return 1 -- retval never read, but return is a quick way out of the function
	end
	for _,row in pairs(sourceTable) do
		local newcard = buildCardData ( row.names, row.price, set.id, fruc, set.german , importlangs)
		if newcard.drop then
			persetcount.dropped = persetcount.dropped + 1
			if DEBUG or LOGDROPS then
				llog("DROPped cName \"" .. newcard.name .. "\"." ,0)
			end
		else -- not newcard.drop
			-- now feed new data into cardsetTable
			local retval,mergedrow,oldrow,newrow = fillCardsetTable ( newcard )
			--TODO change checks and log in a way that fillCardsetTable needs not return three cardrows
			if retval == 0 or retval == "new" or retval == "keep equal" or retval == "notzero/zero" or retval == "zero/notzero" then
				if DEBUG then
					llog("fillCardsetTable returned \"".. retval .. "\" on \"" .. newcard.name .. "\"" ,2)
					llog("old data was " .. deeptostring(oldrow) ,2)
					llog("new data is  " .. deeptostring(newrow) ,2)
					llog("merged data is " .. deeptostring(mergedrow) ,2)
				end
			else -- unexpected retval (not one of 0, "new", "keep equal")
				llog("fillCardsetTable returned \"".. retval .. "\" on \"" .. newcard.name .. "\"" ,1)
				if VERBOSE or DEBUG then
					llog("old data was   " .. deeptostring(oldrow) ,2)
					llog("new data was   " .. deeptostring(newrow) ,2)
					llog("merged data is " .. deeptostring(mergedrow) ,2)
				end
				if DEBUG then
					error ("unmanaged conflict for " .. newcard.name .. " in " .. setname .. "(" .. set.id .. ")" )
				end
			end
		end -- if newcard.drop
		if DEBUGVARIANTS then DEBUG = false end
	end -- for i,row in pairs(sourceTable)
	return 0
end -- function parsehtml

--[[-
  construct url/filename and build sourceTable.
  Construct URL/filename from set and rarity and return a table with all entries found therein
 
  @function [parent=#global] getSourceData
  @param #number setid	to allow avsets[setid].url (see "Database\Sets.txt")
  @param #number fruc	1|2|3|4|5 for foil|rare|uncommon|common|purple rarity
  @param #table importlangs		passed on through parsehtml from ImportPrice (until I change language handling)
  @return #table { #table names, #table price }
]]
function getSourceData (setid , fruc , importlangs) -- 
	local htmldata = nil -- declare here for right scope
	if not OFFLINE then -- get htmldata from online source
		local url = "http://" .. sitedomain .. sitefile .. sitesetprefix .. avsets[setid].url .. sitefrucprefix .. frucnames[fruc] .. sitesuffix
		if DEBUG then
			llog( "url is \"" .. url .. "\"" ,2)
		end
		llog( "Parsing " .. url )
		htmldata = ma.GetUrl(url)
		if not htmldata then
			llog( "!! GetUrl failed for " .. url )
			return nil
		end
	else -- OFFLINE -- get htmldata from local source
		local filename = savepath .. string.gsub(sitefile, "%?", "_") .. sitesetprefix .. avsets[setid].url .. sitefrucprefix .. frucnames[fruc] ..sitesuffix .. ".html"
		if DEBUG then
			llog( "filename is \"" .. filename .. "\"" ,2)
		end
		llog( "Parsing " .. filename )
		htmldata = ma.GetFile(filename)
		if not htmldata then
			llog( "!! GetFile failed for " .. filename )
			return nil
		end
	end -- if offline -- get htmldata

	local sourceTable = {}
	if SAVEHTML then
		local filename = savepath .. string.gsub(sitefile, "%?", "_") .. sitesetprefix .. avsets[setid].url .. sitefrucprefix .. frucnames[fruc] ..sitesuffix .. ".html"
		llog( "Saving source html to file: \"" .. filename .. "\"" )
		ma.PutFile(filename , htmldata)
	end -- if SAVEHTML
	for foundstring in string.gmatch(htmldata, siteRegex) do
		if DEBUG then
			llog( "FOUND in " .. frucnames[fruc] .. " : " .. foundstring )
		end
		local foundData = siteSortData(foundstring)
		-- do some initial input sanitizing: "_" to " "; remove spaces from start and end of string
		for lid,_cLang in pairs(importlangs) do
			if foundData.names[lid] then
				foundData.names[lid] = ansi2utf ( foundData.names[lid] )
				foundData.names[lid] = string.gsub(foundData.names[lid], "_", " ")
				foundData.names[lid] = string.gsub(foundData.names[lid], "^%s*(.-)%s*$", "%1")
			end
		end -- for lid,_cLang
		if foundData.price then
			foundData.price = string.gsub(foundData.price, ",", "%.") -- change decimal comma to decimal point - not needed for this site but left to be on the safe side
		end
		if tlength(foundData) == 0 then
			if VERBOSE then
				llog("foundstring contained no data" ,1)
			end
			if DEBUG then
				error("foundstring contained no data")
			end
		else -- something was found
			table.insert (sourceTable, { names = foundData.names, price = foundData.price } )
		end
	end -- for foundstring
	htmldata = nil 	-- potentially large htmldata now ready for garbage collector
	collectgarbage ()
	if DEBUG then
		logreallybigtable(sourceTable, "sourceTable" , 2)
	end
	if table.maxn(sourceTable) == 0 then
		return nil
	else
		return sourceTable
	end
end -- function getSourceData

--[[-
 construct cardData.
 constructs cardData for one card entry found in htmldata
 
 @function [parent=#global] buildCardData
 @param #table names	{ langid = name } as parsed from htmldata
 @param #table price	{ langid = price } as parsed from htmldata
 @param #number setid	(see "Database\Sets.txt")
 @param #number fruc	1|2|3|4|5 for foil|rare|uncommon|common|purple rarity
 @param #string setgerman	"Y"|"N"|"O"; from avsets.set.german (until I change language handling)
 @param #table importlangs	passed on through parsehtml from ImportPrice (until I change language handling)
 @return #table { 	name		: card name to be matched against MAs Oracle Name or localized Name
					names{}		: if DEBUG keeps names from sourcedata
					drop		: true if data was marked as to-be-dropped and further processing was skipped
					variant		: table of variant names, nil if single-versioned card
					regprice	: nonfoil price, table if variant
					foilprice	: foil price, table if variant
				}
 ]]
function buildCardData ( names, price, setid, fruc, setgerman , importlangs ) -- constructs cardData for one card entry found in htmldata
	local card = {}
	if DEBUG then --keep all (localized) unprocessed names
		card.names = names
	end -- DEBUG
	--TODO loop through all importlangs ? then use the first one that's not nil ?
	if setgerman ~="O" then
		card.name = names[1]
	else -- setgerman == "O"
		card.name = names[3]
	end

	if not card.name then -- should not be reached, but caught here to prevent errors in string.gsub/find below
		card.drop = true
		card.name = "DROPPED nil-name"
		if VERBOSE then
			llog ( "!! buildCardData\t dropped empty card " .. deeptostring(card) ,1)
		end
		if DEBUG then
			error ( "!! buildCardData\t dropped empty card " .. deeptostring(card) )
		end
		return card
	end --if

	--experimental: let the card's sourcedata determine language to import (if importlangs[langid])
	card.lang = {}
	for lid,_ in pairs(importlangs) do
		if names[lid] and (names[lid] ~= "") then
			card.lang[lid] = suplangs[lid].abbr
		end
	end

	if fruc == 1 then -- remove "(foil)" if foil url
		card.name = string.gsub(card.name, " *%([fF][oO][iI][lL]%)", "")
		card.foil = true
	else
		card.foil = false
	end

	card.name = string.gsub(card.name, " // ","|")
	card.name = string.gsub(card.name, "Æ", "AE")
	card.name = string.gsub(card.name, "â", "a")
	card.name = string.gsub(card.name, "û", "u")
	card.name = string.gsub(card.name, "á", "a")
	card.name = string.gsub(card.name, "´", "'")
	card.name = string.gsub(card.name, "?", "'")

	if string.find(card.name, "Emblem: ") then -- Emblem prefix to suffix
		card.name = string.gsub(card.name, "Emblem: ([^\"]+)" , "%1 Emblem")
	end
	card.name = string.gsub(card.name, "%(Nr%.%s+(%d+)%)", "(%1)")
	card.name = string.gsub(card.name, "%s+", " ")
	card.name = string.gsub(card.name, "%s+$", "")
	card.variant = nil
	if variants[setid] and variants[setid][card.name] then  -- Check for and set variant (and new card.name)
		if DEBUGVARIANTS then DEBUG = true end
		card.variant = variants[setid][card.name][2]
		if DEBUG then
			llog( "VARIANTS\tcardname \"" .. card.name .. "\" changed to name \"" .. variants[setid][card.name][1] .. "\" with variant \"" .. deeptostring(card.variant) .. "\"" ,2)
		end
		card.name = variants[setid][card.name][1]
	end
	if string.find(card.name, "[tT][oO][kK][eE][nN] %- ") then -- Token prefix and color suffix
		card.name = string.gsub(card.name, "[tT][oO][kK][eE][nN] %- ([^\"]+)", "%1")
		card.name = string.gsub(card.name, "%([WUBRG][/]?[WUBRG]?%)", "")
		card.name = string.gsub(card.name, "%(Art%)", "")
		card.name = string.gsub(card.name, "%(Gld%)", "")
	end
	card.name = string.gsub(card.name, "^%s*(.-)%s*$", "%1") --remove any leftover spaces from start and end of string

	--[[ do site-specific card data manipulation
	for magicuniverse, this is
	seperate "(alpha)" and beta from beta-urls
	set Legends "(ital.)" suffixed to lang[] and DROP
	]]
	card = siteCardDataManipulation ( card , setid )

	if namereplace[setid] and namereplace[setid][card.name] then
		if LOGNAMEREPLACE or DEBUG then
			llog("namereplaced\t" .. card.name .. "\t to " .. namereplace[setid][card.name],1)
		end
		card.name = namereplace[setid][card.name]
		if CHECKEXPECTED then
			persetcount.namereplace = persetcount.namereplace + 1
		end
	end
	-- drop unwanted sourcedata before further processing
	if     string.find(card.name, "%(DROP[ %a]*%)")
	or string.find(card.name, "%([mM]int%)$")
	or string.find(card.name, "%(near [mM]int%)$")
	or string.find(card.name, "%([eE]xce[l]+ent%)$")
	or string.find(card.name, "%(light played%)$")
	or string.find(card.name, "%([lL][pP]%)$")
	or string.find(card.name, "%(light played/played%)")
	or string.find(card.name, "%([lL][pP]/[pP]%)$")
	or string.find(card.name, "%(played%)$")
	or string.find(card.name, "%([pP]%)$")
	or string.find(card.name, "%(knick%)$")
	or string.find(card.name, "%(geknickt%)$")
	then
		card.drop = true
		if DEBUG then
			llog ( "buildCardData\t dropped card " .. deeptostring(card) ,2)
		end
		return card
	end -- if entry to be dropped

	--TODO	card.condition = "NONE"

	-- define price according to card.foil and card.variant
	if card.variant then
		if DEBUG then
			llog( "VARIANTS\t" .. deeptostring(card.variant) ,2)
		end
		if card.foil then
			if not card.foilprice then card.foilprice = {} end
		else -- nonfoil
			if not card.regprice then card.regprice = {} end
		end
		for varnr,varname in pairs(card.variant) do
			if DEBUG then
				llog( "VARIANTS\tvarnr is " .. varnr .. " varname is " .. tostring(varname) ,2)
			end
			if varname then
				if card.foil then
					card.foilprice[varname] = price
				else -- nonfoil
					card.regprice[varname] = price
				end
			end -- if varname
		end -- for varname,varnr
	else -- not card.variant
		if card.foil then
			card.foilprice = price
		else -- nonfoil
			card.regprice = price
		end
	end -- define price
	if DEBUG then
		llog( "buildCardData\t will return card " .. deeptostring(card) ,2)
	end -- DEBUG
	card.foil = nil -- remove foilstat; info is retained in [foil|reg]price and it would cause confusion later
	return card
end -- function buildCardData

--[[-
 add card to cardsetTable.
 do duplicate checking and add card to cardsetTable.
 cardsetTable will hold all prices to be imported, one row per card.
 moved to seperate function to allow early return on unwanted duplicates.
 
 @function [parent=#global] fillCardsetTable
 @param #table card		single tablerow from buildCardData
 @return #string, #table, #table, #table	compare result, oldCardrow, newCardrow, mergedCardrow
]]
function fillCardsetTable ( card )
	if DEBUG then
		llog("fCT\t fill with " .. deeptostring(card) ,2)
	end
	local retval = 0
	local oldCardrow = cardsetTable[card.name]
	local newCardrow = { variant = card.variant, regprice = card.regprice, foilprice = card.foilprice, lang=card.lang }
	local mergedCardrow = {}
	if oldCardrow then
		if (oldCardrow.variant and (not newCardrow.variant)) or ((not oldCardrow.variant) and newCardrow.variant) then
			if VERBOSE or DEBUG then
				llog ("fCT\t!!! conflict variant vs not variant" ,2)
			end
			return "var/novar", oldCardrow,newCardrow
		end
		if oldCardrow.variant and newCardrow.variant then -- unify variants
			mergedCardrow.variant = {}
			for varnr = 1,math.max( tlength(oldCardrow.variant) , tlength(newCardrow.variant) ) do
				if DEBUG then
					llog (" varnr " .. varnr ,2)
				end
				if 		newCardrow.variant[varnr] == oldCardrow.variant[varnr]
				or	newCardrow.variant[varnr] and not oldCardrow.variant[varnr]
				or	oldCardrow.variant[varnr] and not newCardrow.variant[varnr]
				then
					mergedCardrow.variant[varnr] = oldCardrow.variant[varnr] or newCardrow.variant[varnr]
					if DEBUG then
						llog("variant[" .. varnr .. "] equal or only one set" ,2)
					end
				else
					-- think of something
					if VERBOSE or DEBUG then
						llog("!! conflict while unifying varnames" ,2)
					end
					return "varname~=varname", mergedCardrow,oldCardrow,newCardrow
				end
			end -- for
		end
		if mergedCardrow.variant then
			mergedCardrow.regprice, mergedCardrow.foilprice = {}, {}
			if not newCardrow.regprice then newCardrow.regprice = {} end
			if not newCardrow.foilprice then newCardrow.foilprice = {} end
			if not oldCardrow.regprice then oldCardrow.regprice = {} end
			if not oldCardrow.foilprice then oldCardrow.foilprice = {} end
			for varnr,varname in pairs(mergedCardrow.variant) do
				if DEBUG then
					llog ("fCT\t varnr " .. varnr ,2)
				end
				if 		newCardrow.regprice[varname] == oldCardrow.regprice[varname]
				or	newCardrow.regprice[varname] and not oldCardrow.regprice[varname]
				or	oldCardrow.regprice[varname] and not newCardrow.regprice[varname]
				then
					mergedCardrow.regprice[varname] = oldCardrow.regprice[varname] or newCardrow.regprice[varname]
					if DEBUG then
						llog("regprice[" .. tostring(varname) .. "] equal or only one set" ,2)
					end
					retval = "keep equal"
				elseif tonumber(newCardrow.regprice[varname]) == 0 then
					mergedCardrow.regprice[varname] = oldCardrow.regprice[varname]
					retval = "zero/notzero"
				elseif tonumber(oldCardrow.regprice[varname]) == 0 then
					mergedCardrow.regprice[varname] = newCardrow.regprice[varname]
					retval = "notzero/zero"
				else -- newCardrow.regprice[varname] ~= oldCardrow.regprice[varname]
					-- TODO think of something
					if DEBUG then
						llog("fCT\t!! conflicting regprice[" .. tostring(varname) .. "]" ,2)
					end
					retval = "conflict regprices"
				end -- if newCardrow.regprice[varname] == oldCardrow.regprice[varname]
				if 		newCardrow.foilprice[varname] == oldCardrow.foilprice[varname]
				or	newCardrow.foilprice[varname] and not oldCardrow.foilprice[varname]
				or	oldCardrow.foilprice[varname] and not newCardrow.foilprice[varname]
				then
					mergedCardrow.foilprice[varname] = oldCardrow.foilprice[varname] or newCardrow.foilprice[varname]
					if DEBUG then
						llog("foilprice[" .. tostring(varname) .. "] equal or only one set" ,2)
					end
					retval = "keep equal"
				elseif tonumber(newCardrow.foilprice[varname]) == 0 then
					mergedCardrow.foilprice[varname] = oldCardrow.foilprice[varname]
					retval = "zero/notzero"
				elseif tonumber(oldCardrow.foilprice[varname]) == 0 then
					mergedCardrow.foilprice[varname] = newCardrow.foilprice[varname]
					retval = "notzero/zero"
				else -- newCardrow.foilprice[varname] ~= oldCardrow.foilprice[varname]
					-- TODO think of something
					if VERBOSE or DEBUG then
						llog("fCT\t!! conflicting foilprice[" .. tostring(varname) .. "]" ,2)
					end
					retval = "conflict foilprices"
				end -- if newCardrow.foilprice[varname] == oldCardrow.foilprice[varname]
			end -- for varnr,varname
		else -- not variant
			if 		newCardrow.regprice == oldCardrow.regprice
			or	newCardrow.regprice and not oldCardrow.regprice
			or	oldCardrow.regprice and not newCardrow.regprice
			then
				mergedCardrow.regprice = oldCardrow.regprice or newCardrow.regprice
				if DEBUG then
					llog("regprice equal or only one set" ,2)
				end
				retval = "keep equal"
			elseif tonumber(newCardrow.regprice) == 0 then
				mergedCardrow.regprice = oldCardrow.regprice
				retval = "zero/notzero"
			elseif tonumber(oldCardrow.regprice) == 0 then
				mergedCardrow.regprice = newCardrow.regprice
				retval = "notzero/zero"
			else -- newCardrow.regprice ~= oldCardrow.regprice
				-- TODO think of something
				if DEBUG then
					llog("!! conflicting regprice" ,2)
				end
				retval = "conflict regprice"
			end -- if newCardrow.regprice == oldCardrow.regprice
			if 		newCardrow.foilprice == oldCardrow.foilprice
			or	newCardrow.foilprice and not oldCardrow.foilprice
			or	oldCardrow.foilprice and not newCardrow.foilprice
			then
				mergedCardrow.foilprice = oldCardrow.foilprice or newCardrow.foilprice
				if DEBUG then
					llog("foilprice equal or only one set" ,2)
				end
				retval = "keep equal"
			elseif tonumber(newCardrow.foilprice) == 0 then
				mergedCardrow.foilprice = oldCardrow.foilprice
				retval = "zero/notzero"
			elseif tonumber(oldCardrow.foilprice) == 0 then
				mergedCardrow.foilprice = newCardrow.foilprice
				retval = "notzero/zero"
			else -- newCardrow.foilprice ~= oldCardrow.foilprice
				-- TODO think of something
				if VERBOSE or DEBUG then
					llog("!! conflicting foilprice" ,2)
				end
				retval = "conflict foilprice"
			end -- if newCardrow.foilprice == oldCardrow.foilprice
		end -- if variant
		mergedCardrow.lang = {}
		for langid = 1,3 do
			mergedCardrow.lang[langid] = oldCardrow.lang[langid] or newCardrow.lang[langid]
		end
		cardsetTable[card.name] = mergedCardrow
	else -- not oldCardrow
		cardsetTable[card.name] = newCardrow
		mergedCardrow = "not needed"
		retval = "new"
	end
	return retval, mergedCardrow,oldCardrow,newCardrow
end -- function fillCardsetTable

--[[-
 function to sanitize ANSI encoded strings.
 Note that this would not be necessary if the script was saved ANSI encoded instead of utf-8,
 but then again it would not send utf-8 strings to MA :)
 Only replaces previously encountered special characters;
 see https://en.wikipedia.org/wiki/Windows-1252#Codepage_layout if you need to add more.

@function [parent=#global] ansi2utf
@param #string str	string with ansi encoded non-ascii characters
returns #string with utf8 encoded non-ascii characters
]]
function ansi2utf ( str )
--[[
	just keeping this sniplett here in case I need it again
	str = string.gsub(str, "^\239\187\191", "") -- remove unicode BOM (0xEF, 0xBB, 0xBF)
]]
	if "string" == type (str) then
		str = string.gsub(str, "\198", "Æ")
		str = string.gsub(str, "\226", "â")
		str = string.gsub(str, "\225", "á")
		str = string.gsub(str, "\233", "é")
		str = string.gsub(str, "\237", "í")
		str = string.gsub(str, "\250", "ú")
		str = string.gsub(str, "\251", "û")
		str = string.gsub(str, "\228", "ä")
		str = string.gsub(str, "\196", "Ä")
		str = string.gsub(str, "\246", "ö")
		str = string.gsub(str, "\214", "Ö")
		str = string.gsub(str, "\252", "ü")
		str = string.gsub(str, "\220", "Ü")
		str = string.gsub(str, "\223", "ß")
		str = string.gsub(str, "\146", "´")
		return str
	end
end -- function ansi2utf

--[[-
 flexible logging.
 mode 1 for VERBOSE.
 mode 2 for DEBUG.
 else log.
 add other modes as needed

 @function [parent=#global] llog
 @param #string str		log text
 @param #number m 		(optional) mode, default is normal logging
 @param #number a		(optional) 0 to overwrite, default is append
]]
function llog ( str, m , a)
	local mode = m or 0
	local apnd = a or 1
	local logfile = "Prices\\" .. string.gsub(scriptname, "lua$","log")
	if mode == 1 then
		str = " " .. str
	elseif mode == 2 then
		str = "DEBUG\t" .. str
		logfile = logfile -- change filename for seperate debuglog
	end
	if SAVELOG then
		str = "\n" .. str
		ma.PutFile ( logfile, str , apnd)
	else
		ma.Log(str)
	end
end
--[[-
 get table length
 
 @function [parent=#global] tlength
 @param #table tbl
 @return #number
]]
function tlength ( tbl )
	if type ( tbl) == "table" then
		local result = 0
		for _, __ in pairs (tbl) do
			result = result + 1
		end
		return result
	else
		return nil
	end
end
--[[-
 recursively get string representation
 
 @function [parent=#global] deeptostring
 @param tbl
 @return #string 
]]
function deeptostring (tbl)
	if type(tbl) == 'table' then
		local s = '{ '
		for k,v in pairs(tbl) do
			s = s .. '[' .. deeptostring(k) .. ']=' .. deeptostring(v) .. ';'
		end
		return s .. '} '
	elseif type(tbl) == string then
		return '\"' .. tbl .. '\"'
	else
		return tostring(tbl)
	end
end
function logreallybigtable ( tbl , str , m ) -- deeptostring crashes ma; too deep recursion?
	name = str or tostring(tbl)
	lm = 0 or m
	c=0
	if type(tbl) == "table" then
		llog("BIGTABLE " .. name .." has " .. tlength(tbl) .. " rows:" , m )
		for k,v in pairs (tbl) do
			llog("\tkey '" .. k .. "' \t value '" .. deeptostring(v) , m )
			c = c + 1
		end
		if DEBUG then
			llog("BIGTABLE " .. name .. " sent to log in " .. c .. " rows" , m )
		end
	else
		llog("BIGTABLE called for non-table")
	end
end