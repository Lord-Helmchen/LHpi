--[[ Price import script for Magic Album 
to import card pricing from www.magicuniverse.de.

inspired by and loosely based on "MTG Mint Card.lua" by Goblin Hero, Stromglad1
and "Import Prices.lua" by woogerboy21;
who generously granted permission to "do as I like" with their code.
everything else Copyright (C) 2012 by Christian Harms
If you want to contact me about the script, try its release thread in 
http://www.slightlymagic.net/forum/viewforum.php?f=32

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
It felt like overkill to add 35KB of license text to a 95KB script file,
so unless anyone complains, I'll leave it at the referral to the gnu site.
]]
 -- control the amount of feedback/logging done by the script
VERBOSE = true
LOGDROPS = false
 -- don't change these unless you know what you're doing :-)
OFFLINE = true
SAVEHTML = false
scriptname = "magicuniverseDEv1.3.lua" -- should always be equal to the scripts filename !
savepath = "Prices\\" .. string.gsub(scriptname, "v%d+%.%d+%.lua$","") .. "\\" -- for OFFLINE (read) and SAVEHTML (write). must point to an existing directory relative to MA's root.
DEBUG = false
DEBUGVARIANTS = false
-- TODO
SAVETABLE = false -- needs incremental putFile to be remotely readable :)
SAVELOG = false -- true needs incremental putFile

--[[ TODO
patch to accept entries with a condition description if no other entry with better condition is in the table:
buildCardData will need to add condition to carddata
global conditions{} to define priorities
then fillCardsetTable needs a new check before overwriting existing data
at --TODO below

let card's names lang determine possible importlangs
at --TODO below and in main() or setprice()

check for incremental PutFile and change llog and SAVETABLE to use it

externalize all hardcoded website-specific configuration into global variables:
DONE	url (and filename)
DONE	parsehtml regex string
site and set specific patches will have to be block-commented or iffed by a global variable
seperate avsets{} into site-specific (like url and possibly fruc{} ) and valid-for-all-sites data (like id and cards{})
]]--

-- global ans site-specific configuration should end here
suplangs = { -- table of (supported) languages
	  {full = "english", abbr="ENG", id=1},
	  nil,
	  {full = "german", abbr="GER", id=3},
}

frucnames = { "Foil" , "Rare" , "Uncommon" , "Common" , "Purple" }

--TODO condprio = { [0] = "NONE", } -- table to sort condition description. lower indexed will overwrite when building the cardsetTable

function ImportPrice(importfoil, importlangs, importsets) -- "main" function
 --[[ parameters (are passed from MA) :
importfoil	:	"Y"|"N"|"O"		Update Regular and Foil|Update Regular|Update Foil
importlangs	:	array of languages script should import, represented as pairs {languageid, languagename}
				(see "Database\Languages.txt" file).
				only {1, "English"} and {3, German} are supported by this script.
importsets	:	array of sets script should import, represented as pairs {setid, setname}
				(see "Database\Sets.txt" file). 
]]--
	do -- load site specific configuration from external file
		local configfile = "Prices\\" .. string.gsub(scriptname, ".lua$", ".config")
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
	collectgarbage () -- we now have the global tables, no need to keep a second copy inside execconfig() in memory
	
	totalcount = { pENGset=0, pGERset=0, pENGfailed=0, pGERfailed=0, dropped=0, namereplace=0 }
	if SAVELOG then llog( "Check " .. scriptname .. ".log for detailed information" ) end
	-- identify user defined types of foiling to import
	if string.lower(importfoil) == "y" then llog("Importing Non-Foil (+) Foil Card Prices") end
	if string.lower(importfoil) == "o" then llog("Importing Foil Only Card Prices") end
	if string.lower(importfoil) == "n" then llog("Importing Non-Foil Only Card Prices") end
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
	for _,lname in pairs(importlangs) do
		if not alllangs then
			alllangs = lname
		else
			alllangs = alllangs .. "," .. lname
		end
	end
	llog("Importing Languages: [" .. alllangs .. "]")
	if not VERBOSE then
		llog("If you want to see more detailed logging, edit Prices\\" .. scriptname .. " and set VERBOSE = true.",0)
	end
	-- Calculate total number of html pages to parse (need this for progress bar)
	totalhtmlnum = 0
	for _, rec in pairs(avsets) do
		if importsets[rec.id] then
			local persetnum = 0
			if string.lower(importfoil) ~= "o" then -- import non-foil RUC
				if rec.fruc[2] then persetnum = persetnum + 1 end
				if rec.fruc[3] then persetnum = persetnum + 1 end
				if rec.fruc[4] then persetnum = persetnum + 1 end
				if rec.fruc[5] then persetnum = persetnum + 1 end
			end
			if string.lower(importfoil) ~= "n" and rec.fruc[1] ~= "N" then persetnum = persetnum + 1 end -- import foil
			if importlangs[1] or importlangs[3] then totalhtmlnum = totalhtmlnum + persetnum end
		end
	end -- for
	-- Main import cycle
	curhtmlnum = 0
	progress = 0
	for _, cSet in pairs(avsets) do
			
		if importsets[cSet.id] then
			persetcount = { pENGset=0, pGERset=0, pENGfailed=0, pGERfailed=0, dropped=0, namereplace=0 }
			cardsetTable = {} -- clear cardsetTable

			-- issue special case messages 
			if cSet.id == 680 or cSet.id == 690 then -- Time Spiral or Timeshifted
				if VERBOSE then 
					llog( "Note: Timeshifted and Time Spiral share one Foils url. Many expected fails are nothing to worry about." ,1)
				end
			end
			if string.lower(importfoil) ~= "o" and cSet.fruc[1] ~= "O" -- non-foil wanted and exists
				and ( importlangs [1] or importlangs[3] ) -- ger or eng wanted
				then -- we still need to check if RUC(and P for Timeshifted) exists
				if cSet.fruc[2] then parsehtml(cSet, importsets[cSet.id], 2 ) end
				if cSet.fruc[3] then parsehtml(cSet, importsets[cSet.id], 3 ) end
				if cSet.fruc[4] then parsehtml(cSet, importsets[cSet.id], 4 ) end
				if cSet.fruc[5] then parsehtml(cSet, importsets[cSet.id], 5 ) end
			end
			if string.lower(importfoil) ~= "n" and cSet.fruc[1] ~= "N" -- foil wanted and exists
				and ( importlangs [1] or importlangs[3] ) -- ger or eng wanted
				then parsehtml(cSet, importsets[cSet.id], 1, importlangs)
			end
			-- build cardsetTable from htmls finished
			if VERBOSE then
				llog( "cardsetTable for set " .. importsets[cSet.id] .. "(id " .. cSet.id .. ") build with " .. tlength(cardsetTable) .. " rows. set supposedly contains " .. cSet.cards.reg .. " cards and " .. cSet.cards.tok .. " tokens." ,1)
			end
			if SAVETABLE then
				local filename = "Prices\\tables\\table-set=" .. importsets[cSet.id] .. ".txt"
				llog( "Saving table to file: \"" .. filename .. "\"" )
				ma.PutFile( filename , deeptostring(cardsetTable) )
			end
			-- Set the price
			ma.SetProgress( "Importing " .. importsets[cSet.id] .. " from table", progress )
			for cName,cCard in pairs(cardsetTable) do
				if DEBUG then llog( "ImportPrice\t cName is " .. cName .. " and table cCard is " .. deeptostring(cCard) ,2) end
				if importlangs[1] and cSet.german ~= "O" then --set ENG prices
					retvalENG = setPrice(cSet.id, 1, cName, cCard)
				end
				if importlangs[3] and cSet.german ~= "N" then -- set GER prices
					retvalGER = setPrice(cSet.id, 3, cName, cCard)
				end
			end -- for cName,cCard in pairs(cardsetTable)
			local statmsg = "Set " .. importsets[cSet.id]
			if VERBOSE then
				statmsg = statmsg .. " contains \t" .. cSet.cards.reg+cSet.cards.tok .. " cards (\t" .. cSet.cards.reg .. " regular,\t " .. cSet.cards.tok .. " tokens )"
				statmsg = statmsg .. "\n\t successfully set new price for " .. persetcount.pENGset .. " English and " .. persetcount.pGERset .. " German cards. " .. persetcount.pGERfailed .. " German and " .. persetcount.pENGfailed .. " English cards failed; DROPped " .. persetcount.dropped .. "."
				statmsg = statmsg .. "\nnamereplace table contains " .. (tlength(namereplace[cSet.id]) or "no") .. " names and was triggered " .. persetcount.namereplace .. " times."
			else
				statmsg = statmsg .. " imported."
			end
			llog ( statmsg )
			if VERBOSE then
				local allgood = true
				if expectedtotals[cSet.id] then
					if importlangs[1] then
						if expectedtotals[cSet.id][1] ~= persetcount.pENGset then allgood = false end
						if expectedtotals[cSet.id][4] ~= persetcount.pENGfailed then allgood = false end
					end
					if importlangs[3] then
						if expectedtotals[cSet.id][2] ~= persetcount.pGERset then allgood = false end
						if expectedtotals[cSet.id][3] ~= persetcount.pGERfailed then allgood = false end
					end
					if expectedtotals[cSet.id][5] ~= persetcount.dropped then allgood = false end
					if expectedtotals[cSet.id][6] ~= persetcount.namereplace then allgood = false end
					if not allgood then
						llog( "!! persetcount for " .. importsets[cSet.id] .. "(id " .. cSet.id .. ") differs from expected: " .. deeptostring(expectedtotals[cSet.id]) ,1)
						if DEBUG then
							error ("notallgood in set " .. importsets[cSet.id] .. "(" ..  cSet.id .. ")")
						end
					else
						llog( ":) Prices for set " .. importsets[cSet.id] .. "(id " .. cSet.id .. ") were imported as expected :-)" ,1)
					end
				else
					llog( "No expected persetcount for " .. importsets[cSet.id] .. "(id " .. cSet.id .. ") found." ,1)
				end
			end
			if DEBUG then 
				llog( "persetstats " .. deeptostring(persetcount) ,2)
			end
			for key,count in pairs(persetcount) do
				totalcount[key] = totalcount[key] + count
			end -- for
		end -- if importsets[cSet.id]
	end -- for _, cSet inpairs(avsets)
	if VERBOSE then
		llog( "totalcount " .. deeptostring(totalcount) ,2)
		local totalexpected = {0,0,0,0,0,0}
		for id,set in pairs(importsets) do
			for k,_ in ipairs(totalexpected) do
			totalexpected[k] = totalexpected[k] + ( (expectedtotals[id] and expectedtotals[id][k]) or 0)
			end -- for k,_
		end -- for id,set
		llog ("totalexpected " .. deeptostring(totalexpected) ,2)
	end -- if VERBOSE
	ma.Log("End of Lua script " .. scriptname )
end -- function ImportPrice

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
		if langid == 1 then
			persetcount.pENGfailed = persetcount.pENGfailed + 1
		elseif langid == 3 then
			persetcount.pGERfailed = persetcount.pGERfailed + 1
		end
		if DEBUG then
			llog( "! SetPrice \"" .. name .. "\" for language " .. suplangs[langid].abbr .. " with n/f price " .. deeptostring(card.regprice) .. "/" .. deeptostring(card.foilprice) .. " not ( " .. tostring(retval) .. " times) set" ,2)
		end
	else
		if langid == 1 then
			persetcount.pENGset = persetcount.pENGset + retval
		elseif langid == 3 then
			persetcount.pGERset = persetcount.pGERset + retval
		end
		if DEBUG then
			llog( "setPrice\t name \"" .. name .. "\" version \"" .. deeptostring(card.variant) .. "\" set to " .. deeptostring(card.regprice) .. "/" .. deeptostring(card.foilprice).. " non/foil " .. tostring(retval) .. " times for laguage " .. suplangs[langid].abbr ,2)
		end
	end
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

function parsehtml(set, setname, fruc ) -- downloads and parses one html file.
 --[[ parameters 
    set: set record from avsets
setname: set name, needed only for progressbar
   fruc: 1|2|3|4|5 for foil|rare|uncommon|common|purple rarity to look up
]]
	curhtmlnum = curhtmlnum + 1
	progress = 100*curhtmlnum/totalhtmlnum
	local pmesg = "Parsing " .. frucnames[fruc] .. " " .. setname
	if DEBUG then
		pmesg = pmesg .. " (id " .. set.id .. ")"
		llog( "parsehtml\tpmesg is \"" .. pmesg .. "\"" ,2)
	end
	ma.SetProgress(pmesg, progress)
	
	local sourceTable = getSourceData ( set.id , fruc )
	if not sourceTable then
		if DEBUG then
			error ("empty sourceTable for " .. setname .. " - " .. frucnames[fruc])
		end
		return 1 -- retval never read, but return is a quick way out of the function
	end	
	for _,row in pairs(sourceTable) do
		local newcard = buildCardData ( row.nameE, row.nameG, row.price, set.id, fruc, set.german )
		if newcard.drop then
			persetcount.dropped = persetcount.dropped + 1
			if DEBUG or LOGDROPS then
				llog("DROPped cName \"" .. newcard.name .. "\"." ,0)
			end
		else -- not newcard.drop
			-- now feed new data into cardsetTable
			local retval,mergedrow,oldrow,newrow = fillCardsetTable ( newcard )
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

function getSourceData ( setid , fruc ) -- Construct URL/filename from set and rarity and return a table with all entried found therein
 --[[ parameters :
		setid	to allow avsets[setid].url
		fruc
	returns
		sourceTable
]]
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
--		local filename = savepath .. "magic.phpstartrow=1&edition=" .. avsets[setid].url .. "&rarity=" .. frucnames[fruc] .. ".html"
		llog( "Saving source html to file: \"" .. filename .. "\"" )
		ma.PutFile(filename , htmldata)
	end -- if SAVEHTML
	for cNameE, cNameG, cPrice in string.gmatch(htmldata, siteRegex) do
		if DEBUG then
			llog( "FOUND in " .. frucnames[fruc] .. " : cNameE: " .. cNameE .. " cNameG: " .. cNameG .. " cPrice: " .. cPrice ,2)
		end
		-- do some initial input sanitizing: "_" to " "; remove spaces from start and end of string
		cNameE = ansi2utf ( cNameE )
		cNameE = string.gsub(cNameE, "_", " ")
		cNameE = string.gsub(cNameE, "^%s*(.-)%s*$", "%1")
		cNameG = ansi2utf ( cNameG )
		cNameG = string.gsub(cNameG, "_", " ")
		cNameG = string.gsub(cNameG, "^%s*(.-)%s*$", "%1")
		price = string.gsub(cPrice, ",", "%.") -- change decimal comma to decimal point - not needed for this site but left to be on the safe side
		table.insert (sourceTable, { nameE = cNameE, nameG = cNameG, price = cPrice } )
	end -- for ... in gmatch(htmldata, ..)
	htmldata = nil 	-- potentially large htmldata now ready for garbage collector
	collectgarbage ()
	if DEBUG then
		logreallybigtable(sourceTable, "sourceTable" , 2)
	end
	return sourceTable
end -- function getSourceData

function buildCardData ( nameE, nameG, price, setid, fruc, setgerman ) -- constructs cardData for one card entry found in htmldata
 --[[ parameters:
		nameE, nameG, price :	card data as parsed from htmldata
		setid
		fruc
		setgerman
	returns:	single tablerow 
	{	name		: card name to be matched against MAs Oracle Name or localized Name
		[nameE,nameG :	if DEBUG keeps names from sourcedata]
		drop	: true if data was marked as to-be-dropped and further processing was skipped
		variant		: table of variant names, nil if single-versioned card
		regprice	: nonfoil price, table if variant
		foilprice	: foil price, table if variant
	}
]]
	local card = {}
	if DEBUG then
		card.nameE = nameE
		card.nameG = nameG
	end -- DEBUG
	if setgerman ~="O" then
		card.name = nameE
	else -- setgerman == "O"
		card.name = nameG
	end

	if not card.name then -- should not be reached, but caught here to prevent errors in string.find below
		card.drop = true
		card.name = "DROPPED nil-name"
		if VERBOSE then
				llog ( "!! buildCardData\t dropped empty card " .. deeptostring(card) ,1)
		end
		return card
	end --if
	
	card.name = string.gsub(card.name, " // ","|")
	card.name = string.gsub(card.name, "Æ", "AE")
	card.name = string.gsub(card.name, "â", "a")
	card.name = string.gsub(card.name, "û", "u")
	card.name = string.gsub(card.name, "á", "a")
	card.name = string.gsub(card.name, "´", "'")
	card.name = string.gsub(card.name, "?", "'")
	if fruc == 1 then -- remove "foil" if foil url
		card.name = string.gsub(card.name, " *%([fF][oO][iI][lL]%) *", " ")
	end
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
	if namereplace[setid] and namereplace[setid][card.name] then
		card.name = namereplace[setid][card.name]
		if VERBOSE then
			persetcount.namereplace = persetcount.namereplace + 1
		end
		if DEBUG then
			llog("namereplaced to " .. card.name ,2)
		end
	end
	
	-- seperate "(alpha)" and beta from beta-urls
	if setid == 90 then -- importing Alpha
		if string.find(card.name, "%([aA]lpha%)") then
			card.name = string.gsub(card.name, "%s*%([aA]lpha%)", "")
		else -- not "(alpha")
			card.name = card.name .. "(DROP notalpha)" -- change card.name to prevent import
		end
	elseif setid == 100 then -- importing Beta
		if string.find(card.name, "%([aA]lpha%)") then
			card.name = card.name .. "(DROP not beta)" 
		else -- not "(alpha")
			card.name = string.gsub(card.name, "%s*%(beta%)", "") -- catch needlessly suffixed rawdata
		end 
	end -- if 90 elseif 100

	--experimental: let the card's sourcedata determine importlang (if importlangs[langid])
	card.lang = {}
	if nameE and (nameE ~= "") then
		card.lang[1] = "ENG"
	end
	if nameG and (nameG ~= "") then
		card.lang[3] = "GER"
	end
	if setid == 150 then -- Legends
		if string.find(card.name, "%(ital%.?%)") then
			card.lang[5] = "ITA"
			card.name = card.name .. "(DROP italian)"
		end
	end -- if 150
	
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
	
	local cFoil = false
	if fruc == 1 then cFoil = true end
	-- Check for foil status patch
	for _, rec in ipairs(foiltweak) do
		if rec.setid == setid and rec.cardname == card.name then cFoil = rec.foil end
	end
	
	-- define price according to card.foil and card.variant
	if card.variant then
		if DEBUG then
			llog( "VARIANTS\t" .. deeptostring(card.variant) ,2)
		end
		if cFoil then
			if not card.foilprice then card.foilprice = {} end
		else -- nonfoil
			if not card.regprice then card.regprice = {} end
		end
		for varnr,varname in ipairs(card.variant) do
			if DEBUG then
				llog( "VARIANTS\tvarnr is " .. varnr .. " varname is " .. tostring(varname) ,2)
			end
			if varname then
				if cFoil then
					card.foilprice[varname] = price
				else -- nonfoil
					card.regprice[varname] = price
				end
			end -- if varname
		end -- for varname,varnr
	else -- not card.variant
		if cFoil then
			card.foilprice = price
		else -- nonfoil
			card.regprice = price
		end
	end -- define price
	if DEBUG then
		llog( "buildCardData\t will return card " .. deeptostring(card) ,2)
	end -- DEBUG
	return card
end -- function buildCardData

function fillCardsetTable ( card ) --[[ do duplicate checking and add card to cardsetTable
cardsetTable will hold all prices to be imported, one row per card.
moved to seperate function to allow early return on unwanted duplicates	]]
 --[[ parameters
		card 	: single tablerow from buildCardData
	returns
		retval
		oldCardrow
		newCardrow
		mergedCardrow
]]
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
end -- enclosed function fillCardsetTable


function ansi2utf ( str )
 --[[ function to sanitize ANSI encoded strings.
Note that this would not be necessary if the script was saved ANSI encoded instead of utf-8,
but then again it would not send utf-8 strings to ma :)
Only replaces previously encountered special characters;
see https://en.wikipedia.org/wiki/Windows-1252#Codepage_layout if you need to add more.
]]--
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
function llog ( str, m )
 --[[ mode 1 for VERBOSE.
	 mode 2 for DEBUG.
	 else log. add other modes as needed ]]
	local mode = m or 0
	local logfile = "Prices\\" .. string.gsub(scriptname, ".lua$","") .. ".log"
	if mode == 1 then
		str = " " .. str
	elseif mode == 2 then
		str = "DEBUG\t" .. str
		logfile = logfile -- change filename for seperate debuglog
	end
	if SAVELOG then
		ma.PutFile ( logfile, str, 1 )
	else
		ma.Log(str)
	end
end
	
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