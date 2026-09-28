--!strict
-- The fixed resident behind each door, by house number (the map names houses House1..House60).
-- Houses get richer the further they are from the bank:
--   1-24 the streets nearest town (tier 1), 25-48 the outer streets (tier 2),
--   49-56 the cul-de-sacs (tier 3), 57-60 the mansions at the ends of the cul-de-sacs (tier 4).
-- Content only: pay and heat live in Config.Paths.Doors and Config.Heat.

export type Chore = "Mow" | "Bins" | "CarWash"
export type Wildcard = "DogWalk" | "Letter" | "WalletSwipe" | "ShadyPackage" | "BreakIn"

export type Resident = {
	name: string,
	greeting: string, -- what they say when they open the door
	chore: Chore,
	wildcard: Wildcard,
	wildcardLine: string, -- how the wildcard job is pitched (or spotted)
}

local residents: { [number]: Resident } = {
	-- Near town (tier 1)
	[1] = {
		name = "Grandma Mildred",
		greeting = "Oh! A young helper. Would you be a dear?",
		chore = "Mow",
		wildcard = "DogWalk",
		wildcardLine = "Biscuit needs his walk to the park, and my hips say no.",
	},
	[2] = {
		name = "Big Sal",
		greeting = "Yeah? Whaddya want? Make it quick, the game's on.",
		chore = "Bins",
		wildcard = "WalletSwipe",
		wildcardLine = "His wallet is hanging out of his back pocket...",
	},
	[3] = {
		name = "Dr. Pickles",
		greeting = "Ah, excellent timing! I require an assistant.",
		chore = "CarWash",
		wildcard = "Letter",
		wildcardLine = "Deliver this very important letter. Do not read it. It's about pickles.",
	},
	[4] = {
		name = "Mr. Whiskers",
		greeting = "Shh! You'll wake the cats. All eleven of them.",
		chore = "Mow",
		wildcard = "ShadyPackage",
		wildcardLine = "Take this box to the alley. Don't shake it. Don't ask.",
	},
	[5] = {
		name = "The Johnsons",
		greeting = "Can't talk long, we're packing for the beach!",
		chore = "Bins",
		wildcard = "BreakIn",
		wildcardLine = "They're off on holiday and the back door looks flimsy...",
	},
	[6] = {
		name = "Aunt Doris",
		greeting = "Come in, come in! Actually, stay out there. I just mopped.",
		chore = "CarWash",
		wildcard = "DogWalk",
		wildcardLine = "Take Princess Fluffington to the park. She bites. Lovingly.",
	},
	[7] = {
		name = "Skater Zed",
		greeting = "Duuude. Heyyy. What's up?",
		chore = "Mow",
		wildcard = "WalletSwipe",
		wildcardLine = "He's too busy showing you a kickflip video to watch his wallet...",
	},
	[8] = {
		name = "Kevin",
		greeting = "Hi. I'm Kevin. Just Kevin.",
		chore = "Bins",
		wildcard = "Letter",
		wildcardLine = "Can you drop this letter off? It's a thank-you note. For a thank-you note.",
	},
	[9] = {
		name = "Old Man Barnaby",
		greeting = "Back in my day we knocked with our FOREHEADS.",
		chore = "CarWash",
		wildcard = "ShadyPackage",
		wildcardLine = "Take this to the alley. It's... vintage. Very vintage.",
	},
	[10] = {
		name = "Tammy Two-Phones",
		greeting = "Hold on, I'm on both lines. Okay. What?",
		chore = "Mow",
		wildcard = "BreakIn",
		wildcardLine = "She's heading out for a week and forgot to lock the back...",
	},
	[11] = {
		name = "Chef Gus",
		greeting = "Taste this. No? Fine. What do you need?",
		chore = "Bins",
		wildcard = "DogWalk",
		wildcardLine = "Meatball needs a walk before he eats my soufflé.",
	},
	[12] = {
		name = "The Twins",
		greeting = "We're not the twins. We're the other twins.",
		chore = "CarWash",
		wildcard = "WalletSwipe",
		wildcardLine = "They're arguing about which twin is which. Nobody's watching the wallet...",
	},
	[13] = {
		name = "Barista Bree",
		greeting = "Latte? No? Then why are you on my porch?",
		chore = "Mow",
		wildcard = "Letter",
		wildcardLine = "Drop this letter to my landlord. It's mostly apologies.",
	},
	[14] = {
		name = "Uncle Rodney",
		greeting = "If this is about my car's warranty, I told you people...",
		chore = "Bins",
		wildcard = "WalletSwipe",
		wildcardLine = "He's patting his pockets for his glasses. The wallet's right there...",
	},
	[15] = {
		name = "Yoga Yolanda",
		greeting = "Namaste. Please take your shoes off. Outside.",
		chore = "CarWash",
		wildcard = "DogWalk",
		wildcardLine = "Take Zen to the park. He's a very calm dog. Very, very calm.",
	},
	[16] = {
		name = "Pizza Pete",
		greeting = "You're not the pizza? Aw.",
		chore = "Mow",
		wildcard = "ShadyPackage",
		wildcardLine = "Take this pizza box to the alley. There's no pizza in it.",
	},
	[17] = {
		name = "Nana Flo",
		greeting = "You look hungry. Are you hungry? You look hungry.",
		chore = "Bins",
		wildcard = "DogWalk",
		wildcardLine = "Walk Pudding to the park. He's more pudding than dog.",
	},
	[18] = {
		name = "Cousin Vinny",
		greeting = "Hey hey hey! My favourite person! Who are you?",
		chore = "CarWash",
		wildcard = "BreakIn",
		wildcardLine = "He's off to a wedding all weekend, and the back window's wide open...",
	},
	[19] = {
		name = "Bookworm Beth",
		greeting = "Shh. I'm on chapter forty.",
		chore = "Mow",
		wildcard = "Letter",
		wildcardLine = "Return this letter to the library. It's eleven years overdue.",
	},
	[20] = {
		name = "Handyman Hal",
		greeting = "Careful, the doorbell's held on with tape.",
		chore = "Bins",
		wildcard = "WalletSwipe",
		wildcardLine = "He's up a ladder fixing the gutter. His wallet's on the step...",
	},
	[21] = {
		name = "Grandpa Joe",
		greeting = "Did you see the game? No? Neither did I. Fell asleep.",
		chore = "CarWash",
		wildcard = "ShadyPackage",
		wildcardLine = "Take this biscuit tin to the alley. Don't open it. Not biscuits.",
	},
	[22] = {
		name = "Busy Mum Maria",
		greeting = "Quick, before the kids hear the door!",
		chore = "Mow",
		wildcard = "BreakIn",
		wildcardLine = "The whole family's off to the zoo. That back door never locks...",
	},
	[23] = {
		name = "Marcel the Mime",
		greeting = "(He waves without a sound, then pretends to be stuck in a box.)",
		chore = "Bins",
		wildcard = "Letter",
		wildcardLine = "He mimes writing a letter, then hands you a real one. Deliver it?",
	},
	[24] = {
		name = "Plumber Pat",
		greeting = "If it's about the leak, it's not my leak.",
		chore = "CarWash",
		wildcard = "DogWalk",
		wildcardLine = "Take Wrench to the park. He chews pipes.",
	},

	-- The outer streets (tier 2)
	[25] = {
		name = "Professor Plum",
		greeting = "Ah, a visitor! Have you considered the economics of lawns?",
		chore = "Mow",
		wildcard = "Letter",
		wildcardLine = "Please deliver my strongly worded letter about the neighbour's hedge.",
	},
	[26] = {
		name = "Lady Mayfair",
		greeting = "The servants' entrance is round the back, darling.",
		chore = "CarWash",
		wildcard = "ShadyPackage",
		wildcardLine = "Take this hatbox to the alley. There are no hats in it.",
	},
	[27] = {
		name = "Coach Buck",
		greeting = "YOU! You look like you could use some cardio!",
		chore = "Bins",
		wildcard = "BreakIn",
		wildcardLine = "He's off to a training camp all week. The trophies are right there...",
	},
	[28] = {
		name = "DJ Spinz",
		greeting = "WHAT? Hang on, turning it down. Okay. WHAT?",
		chore = "Mow",
		wildcard = "DogWalk",
		wildcardLine = "Take Bass Drop to the park. He only walks to the beat.",
	},
	[29] = {
		name = "Madame Zelda",
		greeting = "I knew you would come. I also knew you'd be late.",
		chore = "CarWash",
		wildcard = "WalletSwipe",
		wildcardLine = "She's staring into her crystal ball, not at her purse...",
	},
	[30] = {
		name = "Sir Reginald",
		greeting = "Good heavens, a commoner! How thrilling.",
		chore = "Bins",
		wildcard = "Letter",
		wildcardLine = "Deliver this invitation to my exclusive party. You are not invited.",
	},
	[31] = {
		name = "Nurse Nancy",
		greeting = "Hi! Sorry, I've got about four minutes before my shift.",
		chore = "Mow",
		wildcard = "ShadyPackage",
		wildcardLine = "My brother asked me to get this to the alley. Please don't tell anyone.",
	},
	[32] = {
		name = "Captain Ahab Jr.",
		greeting = "Ahoy! Have you seen a very large fish?",
		chore = "CarWash",
		wildcard = "BreakIn",
		wildcardLine = "He's heading out to sea for a month. The house will be empty...",
	},
	[33] = {
		name = "Gary the Gamer",
		greeting = "Can't pause, it's an online game. What do you need?",
		chore = "Bins",
		wildcard = "DogWalk",
		wildcardLine = "Walk Pixel to the park. He hasn't seen the sun in weeks either.",
	},
	[34] = {
		name = "Countess Bling",
		greeting = "Mind the diamonds on the doormat, sweetie.",
		chore = "Mow",
		wildcard = "WalletSwipe",
		wildcardLine = "Her purse is sparkling so hard it's practically asking...",
	},
	[35] = {
		name = "Doctor Diane",
		greeting = "Say ahh. Sorry, habit. What can I do for you?",
		chore = "CarWash",
		wildcard = "Letter",
		wildcardLine = "Deliver these test results. Good news, but no peeking.",
	},
	[36] = {
		name = "Rocky the Retired Wrestler",
		greeting = "WHO DARES KNOCK ON ROCKY'S DOOR? Oh. Hello.",
		chore = "Bins",
		wildcard = "ShadyPackage",
		wildcardLine = "Take this championship-belt bag to the alley. It's... on loan.",
	},
	[37] = {
		name = "Poet Penelope",
		greeting = "Knock knock, who's there? A stranger fair! Hello!",
		chore = "Mow",
		wildcard = "WalletSwipe",
		wildcardLine = "She's busy finding a rhyme for 'door'. Her purse is wide open...",
	},
	[38] = {
		name = "Chef Antoine",
		greeting = "Bonjour! Mind the soufflé, it is very nervous.",
		chore = "CarWash",
		wildcard = "DogWalk",
		wildcardLine = "Walk Croissant to the park. He is a very flaky dog.",
	},
	[39] = {
		name = "Influencer Ivy",
		greeting = "OMG hi! Can you knock again? I wasn't filming.",
		chore = "Bins",
		wildcard = "BreakIn",
		wildcardLine = "She's off on a brand trip all week. Her back door is 'totally aesthetic'...",
	},
	[40] = {
		name = "Colonel Crumb",
		greeting = "State your business, soldier!",
		chore = "Mow",
		wildcard = "Letter",
		wildcardLine = "Deliver this letter at the double! It concerns biscuits.",
	},
	[41] = {
		name = "Astronomer Amir",
		greeting = "Did you see that shooting star? No? Me neither. It's daytime.",
		chore = "CarWash",
		wildcard = "ShadyPackage",
		wildcardLine = "Take this telescope case to the alley. It's full of... stars?",
	},
	[42] = {
		name = "Judge Judith",
		greeting = "Order! Oh, sorry. Habit. Hello.",
		chore = "Bins",
		wildcard = "WalletSwipe",
		wildcardLine = "She's reading a very long document. Her purse is unguarded...",
	},
	[43] = {
		name = "Dentist Dave",
		greeting = "Smile! Hmm. You should floss more.",
		chore = "Mow",
		wildcard = "DogWalk",
		wildcardLine = "Walk Molar to the park. He has excellent teeth.",
	},
	[44] = {
		name = "Sculptor Sofia",
		greeting = "Don't move! You'd make a lovely statue.",
		chore = "CarWash",
		wildcard = "BreakIn",
		wildcardLine = "She's at an art fair all week. Her studio window is unlatched...",
	},
	[45] = {
		name = "Pilot Pablo",
		greeting = "This is your captain speaking. Hello!",
		chore = "Bins",
		wildcard = "Letter",
		wildcardLine = "Deliver this postcard. It's already been to six countries.",
	},
	[46] = {
		name = "Fitness Frank",
		greeting = "Drop and give me twenty! Kidding. Unless...?",
		chore = "Mow",
		wildcard = "WalletSwipe",
		wildcardLine = "He's mid-plank and can't look up. His wallet's on the bench...",
	},
	[47] = {
		name = "Violinist Viola",
		greeting = "Mind the music stand, darling.",
		chore = "CarWash",
		wildcard = "ShadyPackage",
		wildcardLine = "Take this violin case to the alley. No violin inside. Obviously.",
	},
	[48] = {
		name = "Weatherman Wes",
		greeting = "Cloudy, with a chance of visitors!",
		chore = "Bins",
		wildcard = "DogWalk",
		wildcardLine = "Walk Drizzle to the park. Bring an umbrella.",
	},

	-- The cul-de-sacs (tier 3)
	[49] = {
		name = "Mr. Moneybags",
		greeting = "Whatever you're selling, I already own three.",
		chore = "CarWash",
		wildcard = "Letter",
		wildcardLine = "Deliver this cheque to my accountant's friend. Tip included.",
	},
	[50] = {
		name = "Duchess Pearl",
		greeting = "One does not usually open one's own door.",
		chore = "Bins",
		wildcard = "ShadyPackage",
		wildcardLine = "Take this velvet case to the alley. It's for a... friend.",
	},
	[51] = {
		name = "Tech Bro Tyler",
		greeting = "Hey, can't talk, I'm disrupting something.",
		chore = "Mow",
		wildcard = "BreakIn",
		wildcardLine = "He's off to a conference and his smart lock runs on vibes...",
	},
	[52] = {
		name = "Baroness Von Fluff",
		greeting = "Darling! My poodle and I were just discussing you.",
		chore = "CarWash",
		wildcard = "DogWalk",
		wildcardLine = "Walk Sir Fluffsalot to the park. He prefers the scenic route.",
	},
	[53] = {
		name = "The Magnificent Marvin",
		greeting = "Behold! It is I! Pick a card! Any card!",
		chore = "Bins",
		wildcard = "WalletSwipe",
		wildcardLine = "He's doing a trick with his wallet. You could do one too...",
	},
	[54] = {
		name = "Mayor Goodwin",
		greeting = "Always happy to meet a voter! You ARE a voter?",
		chore = "Mow",
		wildcard = "Letter",
		wildcardLine = "Deliver this very official letter. It's definitely not a bribe.",
	},
	[55] = {
		name = "Lord Fancypants",
		greeting = "Please wipe your feet on the SECOND doormat.",
		chore = "CarWash",
		wildcard = "ShadyPackage",
		wildcardLine = "Take this golden briefcase to the alley. Tell no one. Especially Tony.",
	},
	[56] = {
		name = "Lady Opal",
		greeting = "The helicopter's waiting, so do make it snappy.",
		chore = "Bins",
		wildcard = "BreakIn",
		wildcardLine = "She's jetting off for the season. Nobody's watching the back gate...",
	},

	-- The mansions (tier 4)
	[57] = {
		name = "Mr. Richington III",
		greeting = "Ah. The help has arrived. Splendid.",
		chore = "CarWash",
		wildcard = "BreakIn",
		wildcardLine = "He's off on his yacht for a month. The mansion's back door is solid gold... and unlocked.",
	},
	[58] = {
		name = "Madame Diamante",
		greeting = "Darling, you're standing on imported marble.",
		chore = "Mow",
		wildcard = "WalletSwipe",
		wildcardLine = "Her diamond purse is so heavy she's put it down on the step...",
	},
	[59] = {
		name = "Sir Goldfinch",
		greeting = "Welcome to Goldfinch Manor. Wipe your everything.",
		chore = "Bins",
		wildcard = "ShadyPackage",
		wildcardLine = "Take this monogrammed trunk to the alley. Quietly.",
	},
	[60] = {
		name = "The Mysterious Heiress",
		greeting = "Nobody has knocked on this door in years. Come in. No, wait.",
		chore = "Mow",
		wildcard = "BreakIn",
		wildcardLine = "She's at the opera all night, and the conservatory door is ajar...",
	},
}

local FALLBACK: Resident = {
	name = "A Neighbour",
	greeting = "Oh, hello there!",
	chore = "Mow",
	wildcard = "Letter",
	wildcardLine = "Could you drop this letter off for me?",
}

local Residents = {}

function Residents.forHouse(houseId: number): Resident
	return residents[houseId] or FALLBACK
end

return Residents
