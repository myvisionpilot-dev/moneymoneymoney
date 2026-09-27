--!strict
-- The fixed resident behind each door, by house number (the map names houses House1..House30).
-- Houses 1-12 are Westside (tier 1), 13-22 Eastside (tier 2), 23-30 Hillside (tier 3).
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
	-- Westside (tier 1)
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

	-- Eastside (tier 2)
	[13] = {
		name = "Professor Plum",
		greeting = "Ah, a visitor! Have you considered the economics of lawns?",
		chore = "Mow",
		wildcard = "Letter",
		wildcardLine = "Please deliver my strongly worded letter about the neighbour's hedge.",
	},
	[14] = {
		name = "Lady Mayfair",
		greeting = "The servants' entrance is round the back, darling.",
		chore = "CarWash",
		wildcard = "ShadyPackage",
		wildcardLine = "Take this hatbox to the alley. There are no hats in it.",
	},
	[15] = {
		name = "Coach Buck",
		greeting = "YOU! You look like you could use some cardio!",
		chore = "Bins",
		wildcard = "BreakIn",
		wildcardLine = "He's off to a training camp all week. The trophies are right there...",
	},
	[16] = {
		name = "DJ Spinz",
		greeting = "WHAT? Hang on, turning it down. Okay. WHAT?",
		chore = "Mow",
		wildcard = "DogWalk",
		wildcardLine = "Take Bass Drop to the park. He only walks to the beat.",
	},
	[17] = {
		name = "Madame Zelda",
		greeting = "I knew you would come. I also knew you'd be late.",
		chore = "CarWash",
		wildcard = "WalletSwipe",
		wildcardLine = "She's staring into her crystal ball, not at her purse...",
	},
	[18] = {
		name = "Sir Reginald",
		greeting = "Good heavens, a commoner! How thrilling.",
		chore = "Bins",
		wildcard = "Letter",
		wildcardLine = "Deliver this invitation to my exclusive party. You are not invited.",
	},
	[19] = {
		name = "Nurse Nancy",
		greeting = "Hi! Sorry, I've got about four minutes before my shift.",
		chore = "Mow",
		wildcard = "ShadyPackage",
		wildcardLine = "My brother asked me to get this to the alley. Please don't tell anyone.",
	},
	[20] = {
		name = "Captain Ahab Jr.",
		greeting = "Ahoy! Have you seen a very large fish?",
		chore = "CarWash",
		wildcard = "BreakIn",
		wildcardLine = "He's heading out to sea for a month. The house will be empty...",
	},
	[21] = {
		name = "Gary the Gamer",
		greeting = "Can't pause, it's an online game. What do you need?",
		chore = "Bins",
		wildcard = "DogWalk",
		wildcardLine = "Walk Pixel to the park. He hasn't seen the sun in weeks either.",
	},
	[22] = {
		name = "Countess Bling",
		greeting = "Mind the diamonds on the doormat, sweetie.",
		chore = "Mow",
		wildcard = "WalletSwipe",
		wildcardLine = "Her purse is sparkling so hard it's practically asking...",
	},

	-- Hillside (tier 3)
	[23] = {
		name = "Mr. Moneybags",
		greeting = "Whatever you're selling, I already own three.",
		chore = "CarWash",
		wildcard = "Letter",
		wildcardLine = "Deliver this cheque to my accountant's friend. Tip included.",
	},
	[24] = {
		name = "Duchess Pearl",
		greeting = "One does not usually open one's own door.",
		chore = "Bins",
		wildcard = "ShadyPackage",
		wildcardLine = "Take this velvet case to the alley. It's for a... friend.",
	},
	[25] = {
		name = "Tech Bro Tyler",
		greeting = "Hey, can't talk, I'm disrupting something.",
		chore = "Mow",
		wildcard = "BreakIn",
		wildcardLine = "He's off to a conference and his smart lock runs on vibes...",
	},
	[26] = {
		name = "Baroness Von Fluff",
		greeting = "Darling! My poodle and I were just discussing you.",
		chore = "CarWash",
		wildcard = "DogWalk",
		wildcardLine = "Walk Sir Fluffsalot to the park. He prefers the scenic route.",
	},
	[27] = {
		name = "The Magnificent Marvin",
		greeting = "Behold! It is I! Pick a card! Any card!",
		chore = "Bins",
		wildcard = "WalletSwipe",
		wildcardLine = "He's doing a trick with his wallet. You could do one too...",
	},
	[28] = {
		name = "Mayor Goodwin",
		greeting = "Always happy to meet a voter! You ARE a voter?",
		chore = "Mow",
		wildcard = "Letter",
		wildcardLine = "Deliver this very official letter. It's definitely not a bribe.",
	},
	[29] = {
		name = "Lord Fancypants",
		greeting = "Please wipe your feet on the SECOND doormat.",
		chore = "CarWash",
		wildcard = "ShadyPackage",
		wildcardLine = "Take this golden briefcase to the alley. Tell no one. Especially Tony.",
	},
	[30] = {
		name = "Lady Opal",
		greeting = "The helicopter's waiting, so do make it snappy.",
		chore = "Bins",
		wildcard = "BreakIn",
		wildcardLine = "She's jetting off for the season. Nobody's watching the back gate...",
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
