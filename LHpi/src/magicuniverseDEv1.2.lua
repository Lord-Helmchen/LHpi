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
VERBOSE = false
LOGDROPS = false
 -- don't change these unless you know what you're doing :-)
OFFLINE = false
SAVEHTML = true
scriptname = "magicuniverseDEv1.2.lua" -- should always be equal to the scripts filename !
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

avsets = { -- table that describes sets available for price import
 --[[ fields:
          id:	numerical database set id (can be found in "Database\Sets.txt" file)
 	   cards:	table of expected cardcounts used for sanity checking the import.
				must be hardcoded here until ma.getcardcount(setid, cardtype[all|regular|token|basicland] is possile :)
   cards.reg:	numer of expected regular cards
   cards.tok:	number of expected tokens
        fruc:	table of available rarity urls to be parsed
	 fruc[1]:	"N" - no foils in set, "Y" - foils in set, "O" - only foils in set
	 fruc[2]:	boolean, does rares url exist?
	 fruc[3]:	boolean, does uncommons url exist?
	 fruc[4]:	boolean, does commons url exist?
	 fruc[5]:	TimeSpiral Timeshifted
				looks like i can manually request a Foil url, which includes both Time Spiral AND Timeshifted
	  german:	"N" - no german cards, "Y" - german cards, "O" - only german card
		 url:	price url infix
 --]]
 -- Core sets
[788]={id = 788, cards = { reg = 249, tok = 11 },	german="Y", fruc = { "Y",true,true,true }, url = "M2013"}, 
[779]={id = 779, cards = { reg = 249, tok = 7 },	german="Y", fruc = { "Y",true,true,true }, url = "M2012"}, 
[770]={id = 770, cards = { reg = 249, tok = 6 },	german="Y", fruc = { "Y",true,true,true }, url = "M2011"}, 
[759]={id = 759, cards = { reg = 249, tok = 8 },	german="Y", fruc = { "Y",true,true,true }, url = "M2010"}, 
[720]={id = 720, cards = { reg = 384, tok = 6 },	german="Y", fruc = { "Y",true,true,true }, url = "10th_Edition"}, 
[630]={id = 630, cards = { reg = 359, tok = 0 },	german="Y", fruc = { "Y",true,true,true }, url = "9th_Edition"}, 
[550]={id = 550, cards = { reg = 357, tok = 0 },	german="Y", fruc = { "Y",true,true,true }, url = "8th_Edition"}, 
[460]={id = 460, cards = { reg = 350, tok = 0 },	german="Y", fruc = { "N",true,true,false }, url = "7th_Edition"}, 
[180]={id = 180, cards = { reg = 378, tok = 0 },	german="Y", fruc = { "N",true,true,false }, url = "4th_Edition"}, 
[140]={id = 140, cards = { reg = 306, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Revised"}, 
 -- Revised Limited : url only provides cNameG
[139]={id = 139, cards = { reg = 306, tok = 0 },	german="O", fruc = { "N",true,true,true }, url = "deutsch_limitiert"}, 
[110]={id = 110, cards = { reg = 302, tok = 0 },	german="N", fruc = { "N",true,true,true }, url = "Unlimited"}, 
[100]={id = 100, cards = { reg = 302, tok = 0 },	german="N", fruc = { "N",true,true,true }, url = "Beta"}, 
 -- Alpha in Beta with "([Aa]lpha)" suffix
[90] ={id =  90, cards = { reg = 395, tok = 0 },	german="N", fruc = { "N",true,true,true }, url = "Beta"}, 
 -- Expansions
[782]={id = 782, cards = { reg = 264, tok = 12 },	german="Y", fruc = { "Y",true,true,true }, url = "Innistrad"}, 
[784]={id = 784, cards = { reg = 158, tok = 3 },	german="Y", fruc = { "Y",true,true,true }, url = "Dark%20Ascension"}, 
[786]={id = 786, cards = { reg = 244, tok = 8 },	german="Y", fruc = { "Y",true,true,true }, url = "Avacyn%20Restored"},
[773]={id = 773, cards = { reg = 249, tok = 9 },	german="Y", fruc = { "Y",true,true,true }, url = "Scars%20of%20Mirrodin"},
[775]={id = 775, cards = { reg = 155, tok = 5 },	german="Y", fruc = { "Y",true,true,true }, url = "Mirrodin%20Besieged"},
[776]={id = 776, cards = { reg = 175, tok = 4 },	german="Y", fruc = { "Y",true,true,true }, url = "New%20Phyrexia"},
[762]={id = 762, cards = { reg = 269, tok = 11 },	german="Y", fruc = { "Y",true,true,true }, url = "Zendikar"},
[765]={id = 765, cards = { reg = 145, tok = 6 },	german="Y", fruc = { "Y",true,true,true }, url = "Worldwake"},
[767]={id = 767, cards = { reg = 248, tok = 7 },	german="Y", fruc = { "Y",true,true,true }, url = "Rise%20of%20the%20Eldrazi"},
[754]={id = 754, cards = { reg = 249, tok = 10 },	german="Y", fruc = { "Y",true,true,true }, url = "Shards%20of%20Alara"},
[756]={id = 756, cards = { reg = 145, tok = 2 },	german="Y", fruc = { "Y",true,true,true }, url = "Conflux"},
[758]={id = 758, cards = { reg = 145, tok = 4 },	german="Y", fruc = { "Y",true,true,true }, url = "Alara%20Reborn"},
[751]={id = 751, cards = { reg = 301, tok = 12 },	german="Y", fruc = { "Y",true,true,true }, url = "Shadowmoor"},
[752]={id = 752, cards = { reg = 180, tok = 7 },	german="Y", fruc = { "Y",true,true,true }, url = "Eventide"},
[730]={id = 730, cards = { reg = 301, tok = 11 },	german="Y", fruc = { "Y",true,true,true }, url = "Lorwyn"},
[750]={id = 750, cards = { reg = 150, tok = 3 },	german="Y", fruc = { "Y",true,true,true }, url = "Morningtide"},
 -- for Timeshifted and Timespiral, lots of expected fails due to shared foil url
[690]={id = 690, cards = { reg = 121, tok = 0 },	german="Y", fruc = { "Y",false,false,false,true }, url = "Time_Spiral"}, -- Timeshifted
[680]={id = 680, cards = { reg = 301, tok = 0 },	german="Y", fruc = { "Y",true,true,true }, url = "Time_Spiral"},
[700]={id = 700, cards = { reg = 165, tok = 0 },	german="Y", fruc = { "Y",true,true,true }, url = "Planar_Chaos"},
[710]={id = 710, cards = { reg = 180, tok = 0 },	german="Y", fruc = { "Y",true,true,true }, url = "Future_Sight"},
[190]={id = 190, cards = { reg = 383, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Ice_Age"},
[220]={id = 220, cards = { reg = 199, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Alliances"},
[670]={id = 670, cards = { reg = 155, tok = 0 },	german="Y", fruc = { "Y",true,true,true }, url = "Coldsnap"},
[640]={id = 640, cards = { reg = 306, tok = 0 },	german="Y", fruc = { "Y",true,true,true }, url = "Ravnica"},
[650]={id = 650, cards = { reg = 165, tok = 0 },	german="Y", fruc = { "Y",true,true,true }, url = "Guildpact"},
[660]={id = 660, cards = { reg = 180, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Dissension"},
[590]={id = 590, cards = { reg = 307, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Champions_of_Kamigawa"},
[610]={id = 610, cards = { reg = 165, tok = 0 },	german="Y", fruc = { "Y",true,true,true }, url = "Betrayers_of_Kamigawa"},
[620]={id = 620, cards = { reg = 165, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Saviors_of_Kamigawa"},
[560]={id = 560, cards = { reg = 306, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Mirrodin"},
[570]={id = 570, cards = { reg = 165, tok = 0 },	german="Y", fruc = { "Y",true,true,true }, url = "Darksteel"},
[580]={id = 580, cards = { reg = 165, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "5th_Dawn"},
[520]={id = 520, cards = { reg = 350, tok = 0 },	german="Y", fruc = { "Y",true,true,true }, url = "Onslaught"},
[530]={id = 530, cards = { reg = 145, tok = 0 },	german="Y", fruc = { "Y",true,true,true }, url = "Legions"},
[540]={id = 540, cards = { reg = 143, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Scourge"},
[480]={id = 480, cards = { reg = 350, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Odyssey"},
[500]={id = 500, cards = { reg = 143, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Torment"},
[510]={id = 510, cards = { reg = 143, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Judgment"},
[430]={id = 430, cards = { reg = 350, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Invasion"},
[450]={id = 450, cards = { reg = 146, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Planeshift"},
[470]={id = 470, cards = { reg = 143, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Apocalypse"},
[400]={id = 400, cards = { reg = 350, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Merkadische_Masken"},
[410]={id = 410, cards = { reg = 143, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Nemesis"},
[420]={id = 420, cards = { reg = 143, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Prophecy"},
[330]={id = 330, cards = { reg = 350, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Urzas_Saga"},
[350]={id = 350, cards = { reg = 143, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Urzas_Legacy"},
[370]={id = 370, cards = { reg = 143, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Urzas_Destiny"},
[280]={id = 280, cards = { reg = 350, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Tempest"},
[290]={id = 290, cards = { reg = 143, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Stronghold"},
[300]={id = 300, cards = { reg = 143, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Exodus"},
[230]={id = 230, cards = { reg = 350, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Mirage"},
[240]={id = 240, cards = { reg = 167, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Vision"},
[270]={id = 270, cards = { reg = 167, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Weatherlight"},
[210]={id = 210, cards = { reg = 140, tok = 0 },	german="Y", fruc = { "N",true,true,true }, url = "Homelands"},
[170]={id = 170, cards = { reg = 187, tok = 0 },	german="N", fruc = { "N",true,true,true }, url = "Fallen_Empires"},
[130]={id = 130, cards = { reg = 100, tok = 0 },	german="N", fruc = { "N",true,true,true }, url = "Antiquities"},
[120]={id = 120, cards = { reg = 92 , tok = 0 },	german="N", fruc = { "N",true,true,true }, url = "Arabian_Nights"},
[150]={id = 150, cards = { reg = 310, tok = 0 },	german="N", fruc = { "N",true,true,true }, url = "Legends"},
[160]={id = 160, cards = { reg = 119, tok = 0 },	german="N", fruc = { "N",true,true,true }, url = "The_Dark"}
} -- end table avsets

namereplace = { -- tables that define a replacement list for card names
[788] = { -- M2013
["Liliana o. t. Dark Realms Emblem"]	= "Liliana of the Dark Realms Emblem"
},
[140] = { -- Revised
["Serendib Efreet (Fehldruck)"] 		= "Serendib Efreet",
["Pearl Unicorn"] 						= "Pearled Unicorn",
["Monss Goblin Raiders"] 				= "Mons's Goblin Raiders"
},
[139] = { -- Revised Limited (german)
["Schwarzer Ritus (Dark Ritual)"] 		= "Schwarzer Ritus",
["Goblinkönig"]							= "Goblin König",
["Bengalische Heldin"] 					= "Benalische Heldin",
["Advocatus Diaboli"] 					= "Advokatus Diaboli",
["Zersetzung (Desintegrate)"] 			= "Zersetzung",
["Ketos' Zauberbuch"] 					= "Ketos Zauberbuch",
["Leibwächter d. Veteranen"] 			= "Leibwächter des Veteranen",
["Stab des Verderbens"] 				= "Stab der Verderbnis",
["Der schwarze Tot"] 					= "Der Schwarze Tod",
["Greif Roc aus dem Khergebrige"] 		= "Greif Roc aus dem Khergebirge",
["Rückkopplung"] 						= "Rückkoppelung",
["Armageddon-Uhr"] 						= "Armageddonuhr",
["Mons Plündernde Goblins"] 			= "Mons's Goblin Raiders", -- "Mons' plündernde Goblins" failed, might be the ' at end of string?
["Gaeas Vasall"] 						= "Gäas Vasall",
["Bogenschützen der Elfen"] 			= "Bogenschütze der Elfen",
["Ornithropher"] 						= "Ornithopter",
["Granitgargoyle"] 						= "Granit Gargoyle",
["Inselfisch Jaskonius"] 				= "Inselfisch Jasconius",
["Irrlichter"] 							= "Irrlicht",
["Hypnotiserendes Gespenst"] 			= "Hypnotisierendes Gespenst"
},
[110] = { -- Unlimited
["Will-o-The-Wisp"] 					= "Will-o’-the-Wisp"
},
[100] = { -- Beta (shares urls with Alpha, which will be set at end of table)
["Time Walk (alpha, near mint)"]		= "Time Walk (alpha)(near mint)"
},
[782] = { -- Innistrad
["Bloodline Keeper"] 					= "Bloodline Keeper|Lord of Lineage",
["Ludevic's Test Subject"] 				= "Ludevic's Test Subject|Ludevic's Abomination",
["Instigator Gang"] 					= "Instigator Gang|Wildblood Pack",
["Kruin Outlaw"] 						= "Kruin Outlaw|Terror of Kruin Pass",
["Daybreak Ranger"] 					= "Daybreak Ranger|Nightfall Predator",
["Garruk Relentless"] 					= "Garruk Relentless|Garruk, the Veil-Cursed",
["Mayor of Avabruck"] 					= "Mayor of Avabruck|Howlpack Alpha",
["Cloistered Youth"] 					= "Cloistered Youth|Unholy Fiend",
["Civilized Scholar"] 					= "Civilized Scholar|Homicidal Brute",
["Screeching Bat"] 						= "Screeching Bat|Stalking Vampire",
["Hanweir Watchkeep"] 					= "Hanweir Watchkeep|Bane of Hanweir",
["Reckless Waif"] 						= "Reckless Waif|Merciless Predator",
["Gatstaf Shepherd"] 					= "Gatstaf Shepherd|Gatstaf Howler",
["Ulvenwald Mystics"] 					= "Ulvenwald Mystics|Ulvenwald Primordials",
["Thraben Sentry"] 						= "Thraben Sentry|Thraben Militia",
["Delver of Secrets"] 					= "Delver of Secrets|Insectile Aberration",
["Tormented Pariah"] 					= "Tormented Pariah|Rampaging Werewolf",
["Village Ironsmith"] 					= "Village Ironsmith|Ironfang",
["Grizzled Outcasts"] 					= "Grizzled Outcasts|Krallenhorde Wantons",
["Villagers of Estwald"] 				= "Villagers of Estwald|Howlpack of Estwald",
["Doublesidedcards-Checklist"]			= "Checklist"
},
[784] = { -- Dark Ascension
["Hinterland Hermit"] 					= "Hinterland Hermit|Hinterland Scourge",
["Mondronen Shaman"] 					= "Mondronen Shaman|Tovolar’s Magehunter",
["Soul Seizer"] 						= "Soul Seizer|Ghastly Haunting",
["Lambholt Elder"] 						= "Lambholt Elder|Silverpelt Werewolf",
["Ravenous Demon"] 						= "Ravenous Demon|Archdemon of Greed",
["Elbrus, the Binding Blade"] 			= "Elbrus, the Binding Blade|Withengar Unbound",
["Loyal Cathar"] 						= "Loyal Cathar|Unhallowed Cathar",
["Chosen of Markov"] 					= "Chosen of Markov|Markov’s Servant",
["Huntmaster of the Fells"] 			= "Huntmaster of the Fells|Ravager of the Fells",
["Afflicted Deserter"] 					= "Afflicted Deserter|Werewolf Ransacker",
["Chalice of Life"] 					= "Chalice of Life|Chalice of Death",
["Wolfbitten Captive"] 					= "Wolfbitten Captive|Krallenhorde Killer",
["Scorned Villager"]					= "Scorned Villager|Moonscarred Werewolf",
["Doublesidedcards-Checklist"]			= "Checklist"
},
[786] = { -- Avacyn Restored
["Tamiyo, the Moonsage Emblem"]			= "Tamiyo, the Moon Sage Emblem"
},
[773] = { -- Scars of Mirrodin
["Poisoncounter"]						= "Poison Counter"
},
[775] = { -- Mirrodin Besieged
["Poisoncounter"]						= "Poison Counter"
},
[762] = { -- Zendikar
["Meerfolk"] 							= "Merfolk"
},
[730] = { -- Lorwyn
["Elf, Warrior"] 						= "Elf Warrior",
["Kithkin, Soldier"] 					= "Kithkin Soldier",
["Meerfolk Wizard"] 					= "Merfolk Wizard"
},
[750] = { -- Morningtide
["Faery Rogue"] 						= "Faerie Rogue"
},
[670] = { -- Coldsnap
["Jötun Grunt"] 						= "Jotun Grunt",
["Jötun Owl Keeper"] 					= "Jotun Owl Keeper"
},
[640] = { -- Ravnica: City of Guilds
["Drooling Groodian"] 					= "Drooling Groodion",
["Flame Fusilade"]						= "Flame Fusillade",
["Sabretooth Alley Cat"] 				= "Sabertooth Alley Cat",
["Torpid Morloch"]						= "Torpid Moloch",
["Ordunn Commando"] 					= "Ordruun Commando"
},
[590] = { -- Champions of Kamigawa
["Student of Elements"]					= "Student of Elements|Tobita, Master of Winds",
["Kitsune Mystic"]						= "Kitsune Mystic|Autumn-Tail, Kitsune Sage",
["Initiate of Blood"]					= "Initiate of Blood|Goka the Unjust",
["Bushi Tenderfoot"]					= "Bushi Tenderfoot|Kenzo the Hardhearted",
["Budoka Gardener"]						= "Budoka Gardener|Dokai, Weaver of Life",
["Nezumi Shortfang"]					= "Nezumi Shortfang|Stabwhisker the Odious",
["Jushi Apprentice"]					= "Jushi Apprentice|Tomoya the Revealer",
["Orochi Eggwatcher"]					= "Orochi Eggwatcher|Shidako, Broodmistress",
["Nezumi Graverobber"]					= "Nezumi Graverobber|Nighteyes the Desecrator",
["Akki Lavarunner"]						= "Akki Lavarunner|Tok-Tok, Volcano Born"
},
[610] = { -- Betrayers of Kamigawa
["Hired Muscle"] 						= "Hired Muscle|Scarmaker",
["Cunning Bandit"] 						= "Cunning Bandit|Azamuki, Treachery Incarnate",
["Callow Jushi"] 						= "Callow Jushi|Jaraku the Interloper",
["Faithful Squire"] 					= "Faithful Squire|Kaiso, Memory of Loyalty",
["Budoka Pupil"] 						= "Budoka Pupil|Ichiga, Who Topples Oaks"
},
[620] = { -- Saviors of Kamigawa
["Sasaya, Orochi Ascendant"] 			= "Sasaya, Orochi Ascendant|Sasaya’s Essence",
["Rune-Tail, Kitsune Ascendant"] 		= "Rune-Tail, Kitsune Ascendant|Rune-Tail’s Essence",
["Homura, Human Ascendant"] 			= "Homura, Human Ascendant|Homura’s Essence",
["Kuon, Ogre Ascendant"] 				= "Kuon, Ogre Ascendant|Kuon’s Essence",
["Erayo, Soratami Ascendant"] 			= "Erayo, Soratami Ascendant|Erayo’s Essence"
},
[560] = { -- Mirrodin
["Goblin Warwagon"]						= "Goblin War Wagon"
},
[500] = { -- Torment
["Chainers Edict"]						= "Chainer's Edict",
["Caphalid Illusionist"]				= "Cephalid Illusionist"
},
[270] = { -- Weatherlight
["Bösium Strip"]						= "Bosium Strip"
},
[120] = { -- Arabian Nights
["Ifh-Bíff Efreet"] 					= "Ifh-Biff Efreet"
}
} -- end table namereplace

variants = { -- tables of cards that need to set variant
 --[[
[0] = { -- Basic Lands 
["Plains"] 						= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } }
},
]]--
[788] = { -- M2013
["Plains"] 									= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (230)"]							= { "Plains"	, { 1    , false ,false, false } }, 
["Plains (231)"]							= { "Plains"	, { false, 2    , false, false } },
["Plains (232)"]							= { "Plains"	, { false, false, 3    , false } },
["Plains (233)"]							= { "Plains"	, { false, false, false, 4     } },
["Island (234)"]							= { "Island"	, { 1    , false, false, false } },
["Island (235)"]							= { "Island"	, { false, 2    , false, false } },
["Island (236)"]							= { "Island"	, { false, false, 3    , false } },
["Island (237)"]							= { "Island"	, { false, false, false, 4     } },
["Swamp (238)"]								= { "Swamp"		, { 1    , false, false, false } },
["Swamp (239)"]								= { "Swamp"		, { false, 2    , false, false } },
["Swamp (240)"]								= { "Swamp"		, { false, false, 3    , false } },
["Swamp (241)"]								= { "Swamp"		, { false, false, false, 4     } },
["Mountain (242)"]							= { "Mountain"	, { 1    , false, false, false } },
["Mountain (243)"]							= { "Mountain"	, { false, 2    , false, false } },
["Mountain (244)"]							= { "Mountain"	, { false, false, 3    , false } },
["Mountain (245)"]							= { "Mountain"	, { false, false, false, 4     } },
["Forest (246)"]							= { "Forest"	, { 1    , false, false, false } },
["Forest (247)"]							= { "Forest"	, { false, 2    , false, false } },
["Forest (248)"]							= { "Forest"	, { false, false, 3    , false } },
["Forest (249)"]							= { "Forest"	, { false, false, false, 4     } }
},
[779] = { -- M2012
["Plains"] 									= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (230)"]							= { "Plains"	, { 1    , false ,false, false } }, 
["Plains (231)"]							= { "Plains"	, { false, 2    , false, false } },
["Plains (232)"]							= { "Plains"	, { false, false, 3    , false } },
["Plains (233)"]							= { "Plains"	, { false, false, false, 4     } },
["Island (234)"]							= { "Island"	, { 1    , false, false, false } },
["Island (235)"]							= { "Island"	, { false, 2    , false, false } },
["Island (236)"]							= { "Island"	, { false, false, 3    , false } },
["Island (237)"]							= { "Island"	, { false, false, false, 4     } },
["Swamp (238)"]								= { "Swamp"		, { 1    , false, false, false } },
["Swamp (239)"]								= { "Swamp"		, { false, 2    , false, false } },
["Swamp (240)"]								= { "Swamp"		, { false, false, 3    , false } },
["Swamp (241)"]								= { "Swamp"		, { false, false, false, 4     } },
["Mountain (242)"]							= { "Mountain"	, { 1    , false, false, false } },
["Mountain (243)"]							= { "Mountain"	, { false, 2    , false, false } },
["Mountain (244)"]							= { "Mountain"	, { false, false, 3    , false } },
["Mountain (245)"]							= { "Mountain"	, { false, false, false, 4     } },
["Forest (246)"]							= { "Forest"	, { 1    , false, false, false } },
["Forest (247)"]							= { "Forest"	, { false, 2    , false, false } },
["Forest (248)"]							= { "Forest"	, { false, false, 3    , false } },
["Forest (249)"]							= { "Forest"	, { false, false, false, 4     } }
},
[770] = { -- M2011
["Plains"] 									= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (230)"]							= { "Plains"	, { 1    , false ,false, false } }, 
["Plains (231)"]							= { "Plains"	, { false, 2    , false, false } },
["Plains (232)"]							= { "Plains"	, { false, false, 3    , false } },
["Plains (233)"]							= { "Plains"	, { false, false, false, 4     } },
["Island (234)"]							= { "Island"	, { 1    , false, false, false } },
["Island (235)"]							= { "Island"	, { false, 2    , false, false } },
["Island (236)"]							= { "Island"	, { false, false, 3    , false } },
["Island (237)"]							= { "Island"	, { false, false, false, 4     } },
["Swamp (238)"]								= { "Swamp"		, { 1    , false, false, false } },
["Swamp (239)"]								= { "Swamp"		, { false, 2    , false, false } },
["Swamp (240)"]								= { "Swamp"		, { false, false, 3    , false } },
["Swamp (241)"]								= { "Swamp"		, { false, false, false, 4     } },
["Mountain (242)"]							= { "Mountain"	, { 1    , false, false, false } },
["Mountain (243)"]							= { "Mountain"	, { false, 2    , false, false } },
["Mountain (244)"]							= { "Mountain"	, { false, false, 3    , false } },
["Mountain (245)"]							= { "Mountain"	, { false, false, false, 4     } },
["Forest (246)"]							= { "Forest"	, { 1    , false, false, false } },
["Forest (247)"]							= { "Forest"	, { false, 2    , false, false } },
["Forest (248)"]							= { "Forest"	, { false, false, 3    , false } },
["Forest (249)"]							= { "Forest"	, { false, false, false, 4     } },
["Token - Ooze (G) - (2/2)"]				= { "Ooze"		, { 1    , false } },
["Token - Ooze (G) - (1/1)"]				= { "Ooze"		, { false, 2     } }
},
[759] = { -- M2010
["Plains"] 									= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (230)"]							= { "Plains"	, { 1    , false ,false, false } }, 
["Plains (231)"]							= { "Plains"	, { false, 2    , false, false } },
["Plains (232)"]							= { "Plains"	, { false, false, 3    , false } },
["Plains (233)"]							= { "Plains"	, { false, false, false, 4     } },
["Island (234)"]							= { "Island"	, { 1    , false, false, false } },
["Island (235)"]							= { "Island"	, { false, 2    , false, false } },
["Island (236)"]							= { "Island"	, { false, false, 3    , false } },
["Island (237)"]							= { "Island"	, { false, false, false, 4     } },
["Swamp (238)"]								= { "Swamp"		, { 1    , false, false, false } },
["Swamp (239)"]								= { "Swamp"		, { false, 2    , false, false } },
["Swamp (240)"]								= { "Swamp"		, { false, false, 3    , false } },
["Swamp (241)"]								= { "Swamp"		, { false, false, false, 4     } },
["Mountain (242)"]							= { "Mountain"	, { 1    , false, false, false } },
["Mountain (243)"]							= { "Mountain"	, { false, 2    , false, false } },
["Mountain (244)"]							= { "Mountain"	, { false, false, 3    , false } },
["Mountain (245)"]							= { "Mountain"	, { false, false, false, 4     } },
["Forest (246)"]							= { "Forest"	, { 1    , false, false, false } },
["Forest (247)"]							= { "Forest"	, { false, 2    , false, false } },
["Forest (248)"]							= { "Forest"	, { false, false, 3    , false } },
["Forest (249)"]							= { "Forest"	, { false, false, false, 4     } }
},
[720] = { -- 10th
["Plains"] 									= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (364)"]							= { "Plains"	, { 1    , false, false, false } },
["Plains (365)"]							= { "Plains"	, { false, 2    , false, false } },
["Plains (366)"]							= { "Plains"	, { false, false, 3    , false } },
["Plains (367)"]							= { "Plains"	, { false, false, false, 4     } },
["Island (368)"]							= { "Island"	, { 1    , false, false, false } },
["Island (369)"]							= { "Island"	, { false, 2    , false, false } },
["Island (370)"]							= { "Island"	, { false, false, 3    , false } },
["Island (371)"]							= { "Island"	, { false, false, false, 4     } },
["Swamp (372)"]								= { "Swamp"		, { 1    , false, false, false } },
["Swamp (373)"]								= { "Swamp"		, { false, 2    , false, false } },
["Swamp (374)"]								= { "Swamp"		, { false, false, 3    , false } },
["Swamp (375)"]								= { "Swamp"		, { false, false, false, 4     } },
["Mountain (376)"]							= { "Mountain"	, { 1    , false, false, false } },
["Mountain (377)"]							= { "Mountain"	, { false, 2    , false, false } },
["Mountain (378)"]							= { "Mountain"	, { false, false, 3    , false } },
["Mountain (379)"]							= { "Mountain"	, { false, false, false, 4     } },
["Forest (380)"]							= { "Forest"	, { 1    , false, false, false } },
["Forest (381)"]							= { "Forest"	, { false, 2    , false, false } },
["Forest (382)"]							= { "Forest"	, { false, false, 3    , false } },
["Forest (383)"]							= { "Forest"	, { false, false, false, 4     } }
},
[630] = { -- 9th
["Plains"] 									= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3    , 4     } }
},
[550] = { -- 8th
["Plains"] 									= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Swamp (341)"]								= { "Swamp"		, { false, false, 3    , false } }
},
[140] = { -- Revised Edition
["Plains"] 									= { "Plains"	, { 1    , 2    , 3     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3     } }
},
[139] = { -- Revised Limited (german)
["Ebene"] 									= { "Ebene"		, { 1    , 2    , 3     } },
["Insel"] 									= { "Insel" 	, { 1    , 2    , 3     } },
["Sumpf"] 									= { "Sumpf"		, { 1    , 2    , 3     } },
["Gebirge"] 								= { "Gebirge"	, { 1    , 2    , 3     } },
["Wald"] 									= { "Wald"	 	, { 1    , 2    , 3     } }
},
[110] = { -- Unlimited
["Plains"] 									= { "Plains"	, { 1    , 2    , 3     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3     } }
},
[100] = { -- Beta
["Plains"] 									= { "Plains"	, { 1    , 2    , 3     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3     } },
["Plains (vers.1)"]							= { "Plains"	, { 1    , false, false } },
["Plains (vers.2)"]							= { "Plains"	, { false, 2    , false } },
["Plains (vers.3)"]							= { "Plains"	, { false, false, 3     } },
["Island (vers.1)"]							= { "Island"	, { 1    , false, false } },
["Island (vers.2)"]							= { "Island"	, { false, 2    , false } },
["Island (vers.3)"]							= { "Island"	, { false, false ,true  } },
["Swamp (vers.1)"]							= { "Swamp"		, { 1    , false, false } },
["Swamp (vers.2)"]							= { "Swamp"		, { false, 2    , false } },
["Swamp (vers.3)"]							= { "Swamp"		, { false, false, 3     } },
["Mountain (vers.1)"]						= { "Mountain"	, { 1    , false, false } },
["Mountain (vers.2)"]						= { "Mountain"	, { false, 2    , false } },
["Mountain (vers.3)"]						= { "Mountain"	, { false, false, 3     } },
["Forest (vers.1)"]							= { "Forest"	, { 1    , false, false } },
["Forest (vers.2)"]							= { "Forest"	, { false, 2    , false } },
["Forest (vers.3)"]							= { "Forest"	, { false, false, 3     } }
},
 [90] = { -- Alpha
["Plains"] 									= { "Plains"	, { 1    , 2    , 3     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3     } },
["Plains (vers.1)"]							= { "Plains"	, { 1    , false, false } },
["Plains (vers.2)"]							= { "Plains"	, { false, 2    , false } },
["Plains (vers.3)"]							= { "Plains"	, { false, false, 3     } },
["Island (vers.1)"]							= { "Island"	, { 1    , false, false } },
["Island (vers.2)"]							= { "Island"	, { false, 2    , false } },
["Island (vers.3)"]							= { "Island"	, { false, false ,true  } },
["Swamp (vers.1)"]							= { "Swamp"		, { 1    , false, false } },
["Swamp (vers.2)"]							= { "Swamp"		, { false, 2    , false } },
["Swamp (vers.3)"]							= { "Swamp"		, { false, false, 3     } },
["Mountain (vers.1)"]						= { "Mountain"	, { 1    , false, false } },
["Mountain (vers.2)"]						= { "Mountain"	, { false, 2    , false } },
["Mountain (vers.3)"]						= { "Mountain"	, { false, false, 3     } },
["Forest (vers.1)"]							= { "Forest"	, { 1    , false, false } },
["Forest (vers.2)"]							= { "Forest"	, { false, 2    , false } },
["Forest (vers.3)"]							= { "Forest"	, { false, false, 3     } }
},
[782] = { -- Innistrad
["Plains"] 									= { "Plains"	, { 1    , 2    , 3     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3     } },
["Plains (250)"]							= { "Plains"	, { 1    , false, false } },
["Plains (251)"]							= { "Plains"	, { false, 2    , false } },
["Plains (252)"]							= { "Plains"	, { false, false, 3     } },
["Island (253)"]							= { "Island"	, { 1    , false, false } },
["Island (254)"]							= { "Island"	, { false, 2    , false } },
["Island (255)"]							= { "Island"	, { false, false, 3     } },
["Swamp (256)"]								= { "Swamp"		, { 1    , false, false } },
["Swamp (257)"]								= { "Swamp"		, { false, 2    , false } },
["Swamp (258)"]								= { "Swamp"		, { false, false, 3     } },
["Mountain (259)"]							= { "Mountain"	, { 1    , false, false } },
["Mountain (260)"]							= { "Mountain"	, { false, 2    , false } },
["Mountain (261)"]							= { "Mountain"	, { false, false, 3     } },
["Forest (262)"]							= { "Forest"	, { 1    , false, false } },
["Forest (263)"]							= { "Forest"	, { false, 2    , false } },
["Forest (264)"]							= { "Forest"	, { false, false, 3     } },
["Token - Zombie (B) (7)"]					= { "Zombie"	, { 1    , false, false } },
["Token - Zombie (B) (8)"]					= { "Zombie"	, { false, 2    , false } },
["Token - Zombie (B) (9)"]					= { "Zombie"	, { false, false, 3     } },
["Token - Wolf (B)"]						= { "Wolf"		, { 1    , false } },
["Token - Wolf (G)"]						= { "Wolf"		, { false, 2     } }
},
[786] = { -- Avacyn Restored
["Plains"] 									= { "Plains"	, { 1    , 2    , 3     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3     } },
["Plains (230)"]							= { "Plains"	, { 1    , false, false } },
["Plains (231)"]							= { "Plains"	, { false, 2    , false } },
["Plains (232)"]							= { "Plains"	, { false, false, 3     } },
["Island (233)"]							= { "Island"	, { 1    , false, false } },
["Island (234)"]							= { "Island"	, { false, 2    , false } },
["Island (235)"]							= { "Island"	, { false, false, 3     } },
["Swamp (236)"]								= { "Swamp"		, { 1    , false, false } },
["Swamp (237)"]								= { "Swamp"		, { false, 2    , false } },
["Swamp (238)"]								= { "Swamp"		, { false, false, 3     } },
["Mountain (239)"]							= { "Mountain"	, { 1    , false, false } },
["Mountain (240)"]							= { "Mountain"	, { false, 2    , false } },
["Mountain (241)"]							= { "Mountain"	, { false, false, 3     } },
["Forest (242)"]							= { "Forest"	, { 1    , false, false } },
["Forest (243)"]							= { "Forest"	, { false, 2    , false } },
["Forest (244)"]							= { "Forest"	, { false, false, 3     } },
["Token - Spirit (W)"]						= { "Spirit"	, { 1    , false } },
["Token - Spirit (U)"]						= { "Spirit"	, { false, 2     } },
["Token - Human (W)"]						= { "Human"		, { 1    ,false  } },
["Token - Human (R)"]						= { "Human"		, { false, 2     } }
},
[773] = { -- Scars of Mirrodin
["Plains"] 									= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (230)"]							= { "Plains"	, { 1    , false ,false, false } }, 
["Plains (231)"]							= { "Plains"	, { false, 2    , false, false } },
["Plains (232)"]							= { "Plains"	, { false, false, 3    , false } },
["Plains (233)"]							= { "Plains"	, { false, false, false, 4     } },
["Island (234)"]							= { "Island"	, { 1    , false, false, false } },
["Island (235)"]							= { "Island"	, { false, 2    , false, false } },
["Island (236)"]							= { "Island"	, { false, false, 3    , false } },
["Island (237)"]							= { "Island"	, { false, false, false, 4     } },
["Swamp (238)"]								= { "Swamp"		, { 1    , false, false, false } },
["Swamp (239)"]								= { "Swamp"		, { false, 2    , false, false } },
["Swamp (240)"]								= { "Swamp"		, { false, false, 3    , false } },
["Swamp (241)"]								= { "Swamp"		, { false, false, false, 4     } },
["Mountain (242)"]							= { "Mountain"	, { 1    , false, false, false } },
["Mountain (243)"]							= { "Mountain"	, { false, 2    , false, false } },
["Mountain (244)"]							= { "Mountain"	, { false, false, 3    , false } },
["Mountain (245)"]							= { "Mountain"	, { false, false, false, 4     } },
["Forest (246)"]							= { "Forest"	, { 1    , false, false, false } },
["Forest (247)"]							= { "Forest"	, { false, 2    , false, false } },
["Forest (248)"]							= { "Forest"	, { false, false, 3    , false } },
["Forest (249)"]							= { "Forest"	, { false, false, false, 4     } },
["Token - Wurm (Art) (Deathtouch)"] 		= { "Wurm"		, { 1    , false } },
["Token - Wurm (Art) (Lifelink)"] 			= { "Wurm"		, { false, 2     } }
},
[775] = { -- Mirrodin Besieged
["Plains"] 									= { "Plains"	, { 1    , 2     } },
["Island"] 									= { "Island" 	, { 1    , 2     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2     } },
["Forest"] 									= { "Forest" 	, { 1    , 2     } },
["Plains (146)"]							= { "Plains"	, { 1    , false } },
["Plains (147)"]							= { "Plains"	, { false, 2     } },
["Island (148)"]							= { "Island"	, { 1    , false } },
["Island (149)"]							= { "Island"	, { false, 2     } },
["Swamp (150)"]								= { "Swamp"		, { 1    , false } },
["Swamp (151)"]								= { "Swamp"		, { false, 2     } },
["Mountain (152)"]							= { "Mountain"	, { 1    , false } },
["Mountain (153)"]							= { "Mountain"	, { false, 2     } },
["Forest (154)"]							= { "Forest"	, { 1    , false } },
["Forest (155)"]							= { "Forest"	, { false, 2     } }
},
[776] = { -- New Phyrexia
["Plains"] 									= { "Plains"	, { 1    , 2     } },
["Island"] 									= { "Island" 	, { 1    , 2     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2     } },
["Forest"] 									= { "Forest" 	, { 1    , 2     } },
["Plains (166)"]							= { "Plains"	, { 1    , false } },
["Plains (167)"]							= { "Plains"	, { false, 2     } },
["Island (168)"]							= { "Island"	, { 1    , false } },
["Island (169)"]							= { "Island"	, { false, 2     } },
["Swamp (170)"]								= { "Swamp"		, { 1    , false } },
["Swamp (171)"]								= { "Swamp"		, { false, 2     } },
["Mountain (172)"]							= { "Mountain"	, { 1    , false } },
["Mountain (173)"]							= { "Mountain"	, { false, 2     } },
["Forest (174)"]							= { "Forest"	, { 1    , false } },
["Forest (175)"]							= { "Forest"	, { false, 2     } }
},
[762] = { -- Zendikar
["Plains - Vollbild"] 						= { "Plains"	, { 1    , 2    , 3    , 4    } },
["Island - Vollbild"] 						= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp - Vollbild"] 						= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain - Vollbild"] 					= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest - Vollbild"] 						= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains - Vollbild (230)"]					= { "Plains"	, { 1    , false, false, false } },
["Plains - Vollbild (231)"]					= { "Plains"	, { false, 2    , false, false } },
["Plains - Vollbild (232)"]					= { "Plains"	, { false, false, 3    , false } },
["Plains - Vollbild (233)"]					= { "Plains"	, { false, false, false, 4     } },
["Island - Vollbild (234)"]					= { "Island"	, { 1    , false, false, false } },
["Island - Vollbild (235)"]					= { "Island"	, { false, 2    , false, false } },
["Island - Vollbild (236)"]					= { "Island"	, { false, false, 3    , false } },
["Island - Vollbild (237)"]					= { "Island"	, { false, false, false, 4     } },
["Swamp - Vollbild (238)"]					= { "Swamp"		, { 1    , false, false, false } },
["Swamp - Vollbild (239)"]					= { "Swamp"		, { false, 2    , false, false } },
["Swamp - Vollbild (240)"]					= { "Swamp"		, { false, false, 3    , false } },
["Swamp - Vollbild (241)"]					= { "Swamp"		, { false, false, false, 4     } },
["Mountain - Vollbild (242)"]				= { "Mountain"	, { 1    , false, false, false } },
["Mountain - Vollbild (243)"]				= { "Mountain"	, { false, 2    , false, false } },
["Mountain - Vollbild (244)"]				= { "Mountain"	, { false, false, 3    , false } },
["Mountain - Vollbild (245)"]				= { "Mountain"	, { false, false, false, 4     } },
["Forest - Vollbild (246)"]					= { "Forest"	, { 1    , false, false, false } },
["Forest - Vollbild (247)"]					= { "Forest"	, { false, 2    , false, false } },
["Forest - Vollbild (248)"]					= { "Forest"	, { false, false, 3    , false } },
["Forest - Vollbild (249)"]					= { "Forest"	, { false, false, false, 4     } }
},
[767] = { -- Rise of the Eldrazi
["Plains"] 									= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (229)"]							= { "Plains"	, { 1    , false, false, false } }, 
["Plains (230)"]							= { "Plains"	, { false, 2    , false, false } },
["Plains (231)"]							= { "Plains"	, { false, false, 3    , false } },
["Plains (232)"]							= { "Plains"	, { false, false, false, 4     } },
["Island (233)"]							= { "Island"	, { 1    , false, false, false } },
["Island (234)"]							= { "Island"	, { false, 2    , false, false } },
["Island (235)"]							= { "Island"	, { false, false, 3    , false } },
["Island (236)"]							= { "Island"	, { false, false, false, 4     } },
["Swamp (237)"]								= { "Swamp"		, { 1    , false, false, false } },
["Swamp (238)"]								= { "Swamp"		, { false, 2    , false, false } },
["Swamp (239)"]								= { "Swamp"		, { false, false, 3    , false } },
["Swamp (240)"]								= { "Swamp"		, { false, false, false, 4     } },
["Mountain (241)"]							= { "Mountain"	, { 1    , false, false, false } },
["Mountain (242)"]							= { "Mountain"	, { false, 2    , false, false } },
["Mountain (243)"]							= { "Mountain"	, { false, false, 3    , false } },
["Mountain (244)"]							= { "Mountain"	, { false, false, false, 4     } },
["Forest (245)"]							= { "Forest"	, { 1    , false, false, false } },
["Forest (246)"]							= { "Forest"	, { false, 2    , false, false } },
["Forest (247)"]							= { "Forest"	, { false, false, 3    , false } },
["Forest (248)"]							= { "Forest"	, { false, false, false, 4     } },
["TOKEN - Eldrazi Spawn (Vers. A)"] 		= { "Eldrazi Spawn"	, { "a"  , false, false } },
["TOKEN - Eldrazi Spawn (Vers. B)"] 		= { "Eldrazi Spawn"	, { false, "b"  , false } },
["TOKEN - Eldrazi Spawn (Vers. C)"] 		= { "Eldrazi Spawn"	, { false, false, "c"   } }
},
[754] = { -- Shards of Alara
["Plains"] 									= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (230)"]							= { "Plains"	, { 1    , false ,false, false } }, 
["Plains (231)"]							= { "Plains"	, { false, 2    , false, false } },
["Plains (232)"]							= { "Plains"	, { false, false, 3    , false } },
["Plains (233)"]							= { "Plains"	, { false, false, false, 4     } },
["Island (234)"]							= { "Island"	, { 1    , false, false, false } },
["Island (235)"]							= { "Island"	, { false, 2    , false, false } },
["Island (236)"]							= { "Island"	, { false, false, 3    , false } },
["Island (237)"]							= { "Island"	, { false, false, false, 4     } },
["Swamp (238)"]								= { "Swamp"		, { 1    , false, false, false } },
["Swamp (239)"]								= { "Swamp"		, { false, 2    , false, false } },
["Swamp (240)"]								= { "Swamp"		, { false, false, 3    , false } },
["Swamp (241)"]								= { "Swamp"		, { false, false, false, 4     } },
["Mountain (242)"]							= { "Mountain"	, { 1    , false, false, false } },
["Mountain (243)"]							= { "Mountain"	, { false, 2    , false, false } },
["Mountain (244)"]							= { "Mountain"	, { false, false, 3    , false } },
["Mountain (245)"]							= { "Mountain"	, { false, false, false, 4     } },
["Forest (246)"]							= { "Forest"	, { 1    , false, false, false } },
["Forest (247)"]							= { "Forest"	, { false, 2    , false, false } },
["Forest (248)"]							= { "Forest"	, { false, false, 3    , false } },
["Forest (249)"]							= { "Forest"	, { false, false, false, 4     } }
},
[751] = { -- Shadowmoor
["Plains"] 									= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3    , 4     } },
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
["Token - Elf, Warrior (G)"]				= { "Elf Warrior"	, { 1    , false } },
["Token - Elf Warrior (G/W)"]				= { "Elf Warrior"	, { false, 1     } },
["Token - Elemental (R)"] 					= { "Elemental"		, { 1    , false } },
["Token - Elemental (B/R)"] 				= { "Elemental"		, { false, 2     } }
},
[730] = { -- Lorwyn
["Plains"] 									= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3    , 4     } },
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
["Token - Elemental (W)"] 					= { "Elemental"	, { 1    , false } },
["Token - Elemental (G)"] 					= { "Elemental"	, { false, 2     } }
},
[680] = { -- Time Spiral
["Plains"] 									= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3    , 4     } },
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
[640] = { -- Ravnica: City of Guilds
["Plains"] 									= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (287)"]							= { "Plains"	, { 1    , false ,false, false } }, 
["Plains (288)"]							= { "Plains"	, { false, 2    , false, false } },
["Plains (289)"]							= { "Plains"	, { false, false, 3    , false } },
["Plains (290)"]							= { "Plains"	, { false, false, false, 4     } },
["Island (291)"]							= { "Island"	, { 1    , false, false, false } },
["Island (292)"]							= { "Island"	, { false, 2    , false, false } },
["Island (293)"]							= { "Island"	, { false, false, 3    , false } },
["Island (294)"]							= { "Island"	, { false, false, false, 4     } },
["Swamp (295)"]								= { "Swamp"		, { 1    , false, false, false } },
["Swamp (296)"]								= { "Swamp"		, { false, 2    , false, false } },
["Swamp (297)"]								= { "Swamp"		, { false, false, 3    , false } },
["Swamp (298)"]								= { "Swamp"		, { false, false, false, 4     } },
["Mountain (299)"]							= { "Mountain"	, { 1    , false, false, false } },
["Mountain (300)"]							= { "Mountain"	, { false, 2    , false, false } },
["Mountain (301)"]							= { "Mountain"	, { false, false, 3    , false } },
["Mountain (302)"]							= { "Mountain"	, { false, false, false, 4     } },
["Forest (303)"]							= { "Forest"	, { 1    , false, false, false } },
["Forest (304)"]							= { "Forest"	, { false, 2    , false, false } },
["Forest (305)"]							= { "Forest"	, { false, false, 3    , false } },
["Forest (306)"]							= { "Forest"	, { false, false, false, 4     } }
},
[590] = { -- Champions of Kamigawa
["Plains"] 									= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3    , 4     } },
["Plains (287)"]							= { "Plains"	, { 1    , false ,false, false } }, 
["Plains (288)"]							= { "Plains"	, { false, 2    , false, false } },
["Plains (289)"]							= { "Plains"	, { false, false, 3    , false } },
["Plains (290)"]							= { "Plains"	, { false, false, false, 4     } },
["Island (291)"]							= { "Island"	, { 1    , false, false, false } },
["Island (292)"]							= { "Island"	, { false, 2    , false, false } },
["Island (293)"]							= { "Island"	, { false, false, 3    , false } },
["Island (294)"]							= { "Island"	, { false, false, false, 4     } },
["Swamp (295)"]								= { "Swamp"		, { 1    , false, false, false } },
["Swamp (296)"]								= { "Swamp"		, { false, 2    , false, false } },
["Swamp (297)"]								= { "Swamp"		, { false, false, 3    , false } },
["Swamp (298)"]								= { "Swamp"		, { false, false, false, 4     } },
["Mountain (299)"]							= { "Mountain"	, { 1    , false, false, false } },
["Mountain (300)"]							= { "Mountain"	, { false, 2    , false, false } },
["Mountain (301)"]							= { "Mountain"	, { false, false, 3    , false } },
["Mountain (302)"]							= { "Mountain"	, { false, false, false, 4     } },
["Forest (303)"]							= { "Forest"	, { 1    , false, false, false } },
["Forest (304)"]							= { "Forest"	, { false, 2    , false, false } },
["Forest (305)"]							= { "Forest"	, { false, false, 3    , false } },
["Forest (306)"]							= { "Forest"	, { false, false, false, 4     } },
["Brothers Yamazaki"]						= { "Brothers Yamazaki"	, { "a"  , false } },
["Brothers Yamazaki (b)"]					= { "Brothers Yamazaki"	, { false, "b"   } }
},
[330] = { -- Urza's Saga
["Plains"] 									= { "Plains"	, { 1    , 2    , 3    , 4     } },
["Island"] 									= { "Island" 	, { 1    , 2    , 3    , 4     } },
["Swamp"] 									= { "Swamp"		, { 1    , 2    , 3    , 4     } },
["Mountain"] 								= { "Mountain"	, { 1    , 2    , 3    , 4     } },
["Forest"] 									= { "Forest" 	, { 1    , 2    , 3    , 4     } }
},
[210] = { -- Homelands
["Mesa Falcon"] 				 			= { "Mesa Falcon"			, { 1    , 2     } },
["Abbey Matron"] 				 			= { "Abbey Matron"			, { 1    , 2     } },
["Dwarven Trader"] 				 			= { "Dwarven Trader"		, { 1    , 2     } },
["Reef Pirates"] 				 			= { "Reef Pirates"			, { 1    , 2     } },
["Willow Faerie"] 				 			= { "Willow Faerie"			, { 1    , 2     } },
["Shrink"] 						 			= { "Shrink"				, { 1    , 2     } },
["Sengir Bats"] 				 			= { "Sengir Bats"			, { 1    , 2     } },
["Hungry Mist"] 				 			= { "Hungry Mist"			, { 1    , 2     } },
["Folk of An-Havva"] 			 			= { "Folk of An-Havva"		, { 1    , 2     } },
["Cemetery Gate"] 				 			= { "Cemetery Gate"			, { 1    , 2     } },
["Aysen Bureaucrats"] 			 			= { "Aysen Bureaucrats"		, { 1    , 2     } },
["Torture"] 					 			= { "Torture"				, { 1    , 2     } },
["Anaba Bodyguard"] 			 			= { "Anaba Bodyguard"		, { 1    , 2     } },
["Anaba Shaman"] 				 			= { "Anaba Shaman"			, { 1    , 2     } },
["Ambush Party"] 				 			= { "Ambush Party"			, { 1    , 2     } },
["Aliban's Tower"] 				 			= { "Aliban's Tower"		, { 1    , 2     } },
["Feast of the Unicorn"] 		 			= { "Feast of the Unicorn"	, { 1    , 2     } },
["Carapace"] 					 			= { "Carapace"				, { 1    , 2     } },
["Memory Lapse"] 				 			= { "Memory Lapse"			, { 1    , 2     } },
["Labyrinth Minotaur"] 			 			= { "Labyrinth Minotaur"	, { 1    , 2     } },
["Giant Albatross"] 			 			= { "Giant Albatross"		, { 1    , 2     } },
["Samite Alchemist"] 			 			= { "Samite Alchemist"		, { 1    , 2     } },
["Dark Maze"] 					 			= { "Dark Maze"				, { 1    , 2     } },
["Dry Spell"] 					 			= { "Dry Spell"				, { 1    , 2     } },
["Trade Caravan"] 				 			= { "Trade Caravan"			, { 1    , 2     } }
},
[170] = { -- Fallen Empires
["Armor Thrull"] 							= { "Armor Thrull"					, { 1    , 2    , 3    , 4     } },
["Basal Thrull"] 							= { "Basal Thrull"					, { 1    , 2    , 3    , 4     } },
["Brassclaw Orcs"] 							= { "Brassclaw Orcs"				, { 1    , 2    , 3    , 4     } },
["Combat Medic"] 							= { "Combat Medic"					, { 1    , 2    , 3    , 4     } },
["Dwarven Soldier"] 						= { "Dwarven Soldier"				, { 1    , 2    , 3     } },
["Elven Fortress"] 							= { "Elven Fortress"				, { 1    , 2    , 3    , 4     } },
["Elvish Hunter"] 							= { "Elvish Hunter"					, { 1    , 2    , 3     } },
["Elvish Scout"] 							= { "Elvish Scout"					, { 1    , 2    , 3     } },
["Farrel's Zealot"] 						= { "Farrel's Zealot"				, { 1    , 2    , 3     } },
["Goblin Chirurgeon"] 						= { "Goblin Chirurgeon"				, { 1    , 2    , 3     } },
["Goblin Grenade"] 							= { "Goblin Grenade"				, { 1    , 2    , 3     } },
["Goblin War Drums"] 						= { "Goblin War Drums"				, { 1    , 2    , 3    , 4     } },
["High Tide"] 								= { "High Tide"						, { 1    , 2    , 3     } },
["Homarid"] 								= { "Homarid"						, { 1    , 2    , 3    , 4     } },
["Homarid Warrior"] 						= { "Homarid Warrior"				, { 1    , 2    , 3     } },
["Hymn to Tourach"] 						= { "Hymn to Tourach"				, { 1    , 2    , 3    , 4     } },
["Icatian Infantry"] 						= { "Icatian Infantry"				, { 1    , 2    , 3    , 4     } },
["Icatian Javelineers"] 					= { "Icatian Javelineers"			, { 1    , 2    , 3     } },
["Icatian Moneychanger"] 					= { "Icatian Moneychanger"			, { 1    , 2    , 3     } },
["Icatian Scout"] 							= { "Icatian Scout"					, { 1    , 2    , 3    , 4     } },
["Initiates of the Ebon Hand"] 				= { "Initiates of the Ebon Hand"	, { 1    , 2    , 3     } },
["Merseine"] 								= { "Merseine"						, { 1    , 2    , 3    , 4     } },
["Mindstab Thrull"] 						= { "Mindstab Thrull"				, { 1    , 2    , 3     } },
["Necrite"] 								= { "Necrite"						, { 1    , 2    , 3     } },
["Night Soil"] 								= { "Night Soil"					, { 1    , 2    , 3     } },
["Orcish Spy"] 								= { "Orcish Spy"					, { 1    , 2    , 3     } },
["Orcish Veteran"] 							= { "Orcish Veteran"				, { 1    , 2    , 3    , 4     } },
["Order of the Ebon Hand"] 					= { "Order of the Ebon Hand"		, { 1    , 2    , 3     } },
["Order of Leitbur"] 						= { "Order of Leitbur"				, { 1    , 2    , 3     } },
["Spore Cloud"] 							= { "Spore Cloud"					, { 1    , 2    , 3     } },
["Thallid"] 								= { "Thallid"						, { 1    , 2    , 3    , 4     } },
["Thorn Thallid"] 							= { "Thorn Thallid"					, { 1    , 2    , 3    , 4     } },
["Tidal Flats"] 							= { "Tidal Flats"					, { 1    , 2    , 3     } },
["Vodalian Soldiers"] 						= { "Vodalian Soldiers"				, { 1    , 2    , 3    , 4     } },
["Vodalian Mage"] 							= { "Vodalian Mage"					, { 1    , 2    , 3     } }
},
[130] = { -- Antiquities
["Mishra's Factory (Spring - Version 1)"] 	= { "Mishra's Factory"		, { 1    , false, false, false } },
["Mishra's Factory (Summer - Version 2)"] 	= { "Mishra's Factory"		, { false, 2    , false, false } },
["Mishra's Factory (Autumn - Version 3)"] 	= { "Mishra's Factory"		, { false, false, 3    , false } },
["Mishra's Factory (Winter - Version 4)"] 	= { "Mishra's Factory"		, { false, false, false, 4     } },
["Strip Mine (Vers.1)"] 					= { "Strip Mine"			, { 1    , false, false, false } },
["Strip Mine (Vers.2)"] 					= { "Strip Mine"			, { false, 2    , false, false } },
["Strip Mine (Vers.3)"] 					= { "Strip Mine"			, { false, false, 3    , false } },
["Strip Mine (Vers.4)"] 					= { "Strip Mine"			, { false, false, false, 4     } },
["Urza's Mine (Vers.1)"] 					= { "Urza's Mine"			, { 1    , false, false, false } },
["Urza's Mine (Vers.2)"] 					= { "Urza's Mine"			, { false, 2    , false, false } },
["Urza's Mine (Vers.3)"] 					= { "Urza's Mine"			, { false, false, 3    , false } },
["Urza's Mine (Vers.4)"] 					= { "Urza's Mine"			, { false, false, false, 4     } },
["Urza's Power Plant (Vers.1)"] 			= { "Urza's Power Plant"	, { 1    , false, false, false } },
["Urza's Power Plant (Vers.2)"] 			= { "Urza's Power Plant"	, { false, 2    , false, false } },
["Urza's Power Plant (Vers.3)"] 			= { "Urza's Power Plant"	, { false, false, 3    , false } },
["Urza's Power Plant (Vers.4)"] 			= { "Urza's Power Plant"	, { false, false, false, 4     } },
["Urza's Tower (Vers.1)"] 					= { "Urza's Tower"			, { 1    , false, false, false } },
["Urza's Tower (Vers.2)"] 					= { "Urza's Tower"			, { false, 2    , false, false } },
["Urza's Tower (Vers.3)"] 					= { "Urza's Tower"			, { false, false, 3    , false } },
["Urza's Tower (Vers.4)"] 					= { "Urza's Tower"			, { false, false, false, 4     } }
},
[220] = { -- Alliances
["Gorilla Chieftain"] 						= { "Gorilla Chieftain"		, { 1    , 2     } },
["Reprisal"] 								= { "Reprisal"				, { 1    , 2     } },
["Phyrexian Boon"] 							= { "Phyrexian Boon"		, { 1    , 2     } },
["Phyrexian War Beast"] 					= { "Phyrexian War Beast"	, { 1    , 2     } },
["Carrier Pigeons"] 						= { "Carrier Pigeons"		, { 1    , 2     } },
["Wild Aesthir"] 							= { "Wild Aesthir"			, { 1    , 2     } },
["Martyrdom"] 								= { "Martyrdom"				, { 1    , 2     } },
["Yavimaya Ancients"] 						= { "Yavimaya Ancients"		, { 1    , 2     } },
["Gift of the Woods"] 						= { "Gift of the Woods"		, { 1    , 2     } },
["Feast or Famine"] 						= { "Feast or Famine"		, { 1    , 2     } },
["Arcane Denial"] 							= { "Arcane Denial"			, { 1    , 2     } },
["Errand of Duty"] 							= { "Errand of Duty"		, { 1    , 2     } },
["Viscerid Armor"] 							= { "Viscerid Armor"		, { 1    , 2     } },
["Benthic Explorers"] 						= { "Benthic Explorers"		, { 1    , 2     } },
["Agent of Stromgald"] 						= { "Agent of Stromgald"	, { 1    , 2     } },
["Stench of Decay"] 						= { "Stench of Decay"		, { 1    , 2     } },
["Soldevi Heretic"] 						= { "Soldevi Heretic"		, { 1    , 2     } },
["Fevered Strength"] 						= { "Fevered Strength"		, { 1    , 2     } },
["Lim-Dul's High Guard"]	 				= { "Lim-Dul's High Guard"	, { 1    , 2     } },
["Bestial Fury"] 							= { "Bestial Fury"			, { 1    , 2     } },
["Storm Crow"] 								= { "Storm Crow"			, { 1    , 2     } },
["Phantasmal Fiend"] 						= { "Phantasmal Fiend"		, { 1    , 2     } },
["Deadly Insect"] 							= { "Deadly Insect"			, { 1    , 2     } },
["Guerrilla Tactics"] 						= { "Guerrilla Tactics"		, { 1    , 2     } },
["Soldevi Sentry"] 							= { "Soldevi Sentry"		, { 1    , 2     } },
["Kjeldoran Pride"] 						= { "Kjeldoran Pride"		, { 1    , 2     } },
["Insidious Bookworms"] 					= { "Insidious Bookworms"	, { 1    , 2     } },
["Casting of Bones"] 						= { "Casting of Bones"		, { 1    , 2     } },
["Fyndhorn Druid"] 							= { "Fyndhorn Druid"		, { 1    , 2     } },
["Varchild's Crusader"] 					= { "Varchild's Crusader"	, { 1    , 2     } },
["Whip Vine"] 								= { "Whip Vine"				, { 1    , 2     } },
["Storm Shaman"]	 						= { "Storm Shaman"			, { 1    , 2     } },
["Soldevi Adnate"]	 						= { "Soldevi Adnate"		, { 1    , 2     } },
["Undergrowth"] 							= { "Undergrowth"			, { 1    , 2     } },
["Soldevi Steam Beast"] 					= { "Soldevi Steam Beast"	, { 1    , 2     } },
["Astrolabe"] 								= { "Astrolabe"				, { 1    , 2     } },
["Aesthir Glider"] 							= { "Aesthir Glider"		, { 1    , 2     } },
["Taste of Paradise"] 						= { "Taste of Paradise"		, { 1    , 2     } },
["Gorilla Berserkers"] 						= { "Gorilla Berserkers"	, { 1    , 2     } },
["Elvish Ranger"] 							= { "Elvish Ranger"			, { 1    , 2     } },
["Veteran's Voice"] 						= { "Veteran's Voice"		, { 1    , 2     } },
["Gorilla War Cry"] 						= { "Gorilla War Cry"		, { 1    , 2     } },
["Gorilla Shaman"] 							= { "Gorilla Shaman"		, { 1    , 2     } },
["Enslaved Scout"] 							= { "Enslaved Scout"		, { 1    , 2     } },
["Lat-Nam's Legacy"] 						= { "Lat-Nam's Legacy"		, { 1    , 2     } },
["Balduvian War-Makers"] 					= { "Balduvian War-Makers"	, { 1    , 2     } },
["Reinforcements"] 							= { "Reinforcements"		, { 1    , 2     } },
["Swamp Mosquito"] 							= { "Swamp Mosquito"		, { 1    , 2     } },
["Noble Steeds"] 							= { "Noble Steeds"			, { 1    , 2     } },
["Soldevi Sage"] 							= { "Soldevi Sage"			, { 1    , 2     } },
["Foresight"] 								= { "Foresight"				, { 1    , 2     } },
["False Demise"] 							= { "False Demise"			, { 1    , 2     } },
["Awesome Presence"] 						= { "Awesome Presence"		, { 1    , 2     } },
["Royal Herbalist"] 						= { "Royal Herbalist"		, { 1    , 2     } },
["Kjeldoran Escort"] 						= { "Kjeldoran Escort"		, { 1    , 2     } }
},
[120] = { -- Arabian Nights
["Army of Allah"] 							= { "Army of Allah"			, { 1    , false } },
["Army of Allah (Vers. b)"] 				= { "Army of Allah"			, { false, 2     } },
["Bird Maiden"] 							= { "Bird Maiden"			, { 1    , false } },
["Bird Maiden (Vers. b)"] 					= { "Bird Maiden"			, { false, 2     } },
["Erg Raiders"] 							= { "Erg Raiders"			, { 1    , false } },
["Erg Raiders (Vers. b)"] 					= { "Erg Raiders"			, { false, 2     } },
["Fishliver Oil"] 							= { "Fishliver Oil"			, { 1    , false } },
["Fishliver Oil (Vers. b)"] 				= { "Fishliver Oil"			, { false, 2     } },
["Giant Tortoise"] 							= { "Giant Tortoise"		, { 1    , false } },
["Giant Tortoise (Vers. b)"]				= { "Giant Tortoise"		, { false, 2     } },
["Hasran Ogress"] 							= { "Hasran Ogress"			, { 1    , false } },
["Hasran Ogress (Vers. b)"] 				= { "Hasran Ogress"			, { false, 2     } },
["Moorish Cavalry"] 						= { "Moorish Cavalry"		, { 1    , false } },
["Moorish Cavalry (Vers. b)"]				= { "Moorish Cavalry"		, { false, 2     } },
["Nafs Asp"] 								= { "Nafs Asp"				, { 1    , false } },
["Nafs Asp (Vers. b)"] 						= { "Nafs Asp"				, { false, 2     } },
["Oubliette"] 								= { "Oubliette"				, { 1    , false } },
["Oubliette (Vers. b)"] 					= { "Oubliette"				, { false, 2     } },
["Rukh Egg"] 								= { "Rukh Egg"				, { 1    , false } },
["Rukh Egg (Vers. b)"] 						= { "Rukh Egg"				, { false, 2     } },
["Piety"] 									= { "Piety"					, { 1    , false } },
["Piety (Vers. b)"] 						= { "Piety"					, { false, 2     } },
["Stone-Throwing Devils"] 					= { "Stone-Throwing Devils"	, { 1    , false } },
["War Elephant"] 							= { "War Elephant"			, { 1    , false } },
["War Elephant (Vers. b)"]		 			= { "War Elephant"			, { false, 2     } },
["Wyluli Wolf"] 							= { "Wyluli Wolf"			, { 1    , false } },
["Wyluli Wolf (Vers. b)"] 					= { "Wyluli Wolf"			, { false, 2     } }
}
} -- end table variants
variants[90] = variants [100] -- Alpha (shares url with Beta)

if VERBOSE or DEBUG then -- table with expected results as of release
expectedtotals = { -- pENGset,pGERset,pGERfailed,pENGfailed,dropped,namereplace
[788] = {260,249,11,0,0,1},-- ok
[779] = {256,249,7,0,0,0},-- ok
[770] = {255,255,0,0,0,0},-- ok
[759] = {257,257,0,0,0,0},-- ok
[720] = {389,388,1,0,0,0},-- ok
[630] = {339,332,7,0,0,0},-- ok
[550] = {338,336,2,0,0,0},-- ok
[460] = {220,220,0,0,0,0},--ok
[180] = {242,242,0,0,0,0},-- ok
[140] = {306,306,8,8,198,3},-- ok
[139] = {0,306,0,0,16,20},-- ok
[110] = {278,0,0,13,94,1},-- ok
[100] = {168,0,0,19,342,1},--ok
[90]  = {234,0,0,1,295,0},-- ok
[782] = {277,264,10,0,0,43},--ok
[784] = {162,158,4,0,0,27},--ok
[786] = {252,244,6,0,0,1},--ok
[773] = {258,259,0,1,0,1},--ok
[775] = {160,161,0,1,0,1},-- ok
[776] = {179,179,0,0,0,0},-- ok
[762] = {260,260,0,0,0,1},-- ok
[765] = {151,151,0,0,0,0},--ok
[767] = {255,255,0,0,0,0},--ok
[754] = {259,259,0,0,0,0},--ok
[756] = {147,147,0,0,0,0},--ok
[758] = {149,149,0,0,0,0},--ok
[751] = {313,313,0,0,0,0},--ok
[752] = {187,187,0,0,0,0},--ok
[730] = {312,312,0,0,0,3},--ok
[750] = {153,153,0,0,0,1},--ok
[690] = {121,121,298,298,0,0},--ok
[680] = {301,301,121,121,0,0},--ok
[700] = {165,165,0,0,0,0},--ok
[710] = {180,180,0,0,0,0},-- ok
[190] = {363,363,2,2,0,0},--ok
[220] = {199,199,0,0,0,0},--ok
[670] = {155,155,0,0,0,4},--ok
[640] = {306,306,0,0,0,10},--ok
[650] = {165,165,0,0,0,0},--ok
[660] = {180,180,0,0,0,0},--ok
[590] = {287,287,0,0,0,10},--ok
[610] = {165,165,0,0,0,10},--ok
[620] = {165,165,0,0,0,5},--ok
[560] = {286,286,0,0,0,1},--ok
[570] = {165,165,0,0,1,0},--ok
[580] = {165,165,0,0,0,0},--ok
[520] = {330,330,5,5,0,0},--ok
[530] = {145,145,0,0,0,0},--ok
[540] = {143,143,0,0,0,0},--ok
[480] = {330,330,1,1,0,0},--ok
[500] = {143,143,0,0,0,2},--ok
[510] = {143,143,0,0,0,0},--ok
[430] = {330,330,0,0,0,0},--ok
[450] = {143,143,0,0,0,0},--ok
[470] = {143,143,0,0,0,0},--ok
[400] = {330,0,330,0,0,0},--ok
[410] = {143,0,143,0,0,0},--ok
[420] = {143,0,143,0,1,0},--ok
[330] = {350,350,0,0,0,0},--ok
[350] = {143,143,0,0,0,0},--ok
[370] = {143,143,0,0,0,0},--ok
[280] = {330,330,0,0,0,0},--ok
[290] = {143,0,143,0,1,0},--ok
[300] = {143,0,143,0,0,0},--ok
[230] = {330,330,0,0,0,0},--ok
[240] = {167,167,0,0,0,0},--ok
[270] = {167,167,0,0,0,1},--ok
[210] = {140,140,0,0,0,0},--ok
[170] = {187,0,0,0,0,0},--ok
[160] = {119,0,0,0,59,0},--ok
[150] = {310,0,0,0,174,0},--ok
[130] = {100,0,0,3,51,0},--ok
[120] = {91,0,0,3,73,1},--ok
}
end

foiltweak = { -- table that defines a replacement list for foil
 -- { set = 999, nameE="Cardname", foil = true }
} -- end table foiltweak

sitedomain = "www.magicuniverse.de/html/"
sitefile = "magic.php?startrow=1"
sitesetprefix = "&edition="
sitefrucprefix = "&rarity="
siteRegex = 'name="namee" value="([^"]+)">\n%s*<input type="hidden" name="named" value="([^"]+)">\n%s*<input type=hidden name="preis" value="(%d+%.%d+)"'

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
			if importfoil ~= "O" then -- import non-foil RUC
				if rec.fruc[2] then persetnum = persetnum + 1 end
				if rec.fruc[3] then persetnum = persetnum + 1 end
				if rec.fruc[4] then persetnum = persetnum + 1 end
				if rec.fruc[5] then persetnum = persetnum + 1 end
			end
			if importfoil ~= "N" and rec.fruc[1] ~= "N" then persetnum = persetnum + 1 end -- import foil
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
			if importfoil ~= "O" and cSet.fruc[1] ~= "O" -- non-foil wanted and exists
				and ( importlangs [1] or importlangs[3] ) -- ger or eng wanted
				then -- we still need to check if RUC(and P for Timeshifted) exists
				if cSet.fruc[2] then parsehtml(cSet, importsets[cSet.id], 2 ) end
				if cSet.fruc[3] then parsehtml(cSet, importsets[cSet.id], 3 ) end
				if cSet.fruc[4] then parsehtml(cSet, importsets[cSet.id], 4 ) end
				if cSet.fruc[5] then parsehtml(cSet, importsets[cSet.id], 5 ) end
			end
			if importfoil ~= "N" and cSet.fruc[1] ~= "N" -- foil wanted and exists
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
		local url = "http://" .. sitedomain .. sitefile .. sitesetprefix .. avsets[setid].url .. sitefrucprefix .. frucnames[fruc]
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
		local filename = savepath .. string.gsub(sitefile, "%?", "_") .. sitesetprefix .. avsets[setid].url .. sitefrucprefix .. frucnames[fruc] .. ".html"
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
		local filename = savepath .. string.gsub(sitefile, "%?", "_") .. sitesetprefix .. avsets[setid].url .. sitefrucprefix .. frucnames[fruc] .. ".html"
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
	llog("BIGTABLE " .. name .." has " .. tlength(tbl) .. " rows:" , m )
	for k,v in pairs (tbl) do
		llog("\tkey '" .. k .. "' \t value '" .. deeptostring(v) , m )
		c = c + 1
	end
	if DEBUG then
		llog("BIGTABLE " .. name .. " sent to log in " .. c .. " rows" , m )
	end
end
