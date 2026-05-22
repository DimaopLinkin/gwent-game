# Gwent Cards Catalog - The Witcher 3: Wild Hunt

**Master Reference**: [02_game_specifications.md](./02_game_specifications.md)

This document describes card types, properties, and abilities in Gwent. Note: Witcher 3 Gwent card pool changes based on game progression and region.

---

## Table of Contents
1. [Card Types](#card-types)
2. [Card Properties](#card-properties)
3. [Ability Reference](#ability-reference)
4. [Heroes vs Units](#heroes-vs-units)
5. [Card Examples by Type](#card-examples-by-type)

---

## Card Types

### Unit Cards
- **Standard Units**: Regular combat units with strength values
- **Heroes**: Indestructible legendary units with special abilities
- **Captains/Commanders**: High-value units with synergy bonuses

### Special Cards
- **Weather**: Environmental effects (Rain, Fog, Frost)
- **Horns**: Zone-wide buffs (+1 to all in zone)
- **Decoys**: Card manipulation tools
- **Spies**: Opponent disruption cards
- **Agents**: Scoia'tael-specific cards

### Ability Categories

#### Deployment Abilities (Trigger When Played)
- **Medic**: Restore random allied unit from discard
- **Spy**: Deploy on opponent's side, opponent draws 2, then switches
- **Scoia'tael**: Deploy with special agent mechanics
- **Muster**: All copies deploy from deck

#### Persistent Abilities (Active While On Board)
- **Agile**: Can move between zones
- **Horn**: +1 to entire zone
- **Morale Boost**: +1 to all allied units
- **Tight Bondage**: +1 if nearby specific card type

#### Resilience/Persistence (Remain After Round)
- **Resilience** (Skellige): Card returns to hand at round end
- **Scoia'tael** (Agents): Return to hand or persist based on ability

#### Destruction/Removal
- Most units are removed at round end (non-resilient)
- Heroes cannot be removed or destroyed
- Resilient cards return to hand instead

---

## Card Properties

### Card Attributes

**Card Name**
- Unique identifier for the card
- Heroes have iconic character names

**Card Type**
- Unit, Hero, Weather, Special, Agent
- Determines deployment and interaction rules

**Zone**
- Close Combat (melee zone)
- Ranged Combat (distance zone)
- Siege (heavy weapons/monsters)
- Special cards don't have zone requirement

**Strength Value**
- Number representing card's combat value
- Contributes to zone total
- Heroes typically have high strength
- Weather affects all units by -1 (not the value itself)

**Ability**
- Special card effect
- Can be on-deploy, persistent, or end-of-round

**Copies in Deck**
- How many times card appears in deck
- Typically 1-3 copies per card
- Affects Muster ability frequency

---

## Ability Reference

### Complete Ability Descriptions

#### Agile
- **Trigger**: Passive (always active)
- **Effect**: Unit can move between any combat zones
- **Use**: Weather avoidance, tactical positioning
- **Factions**: Common in Scoia'tael, some Northern Realms
- **Strategy**: Deploy to weak zone, move to strong zone as needed

#### Medic
- **Trigger**: On deployment
- **Effect**: Restore random allied unit from discard pile
- **Use**: Card recycling, recovery strategy
- **Factions**: All factions (common in Skellige)
- **Strategy**: Keep discarded units fresh for later reuse

#### Decoy
- **Trigger**: On deployment or activation
- **Effect**: Return target allied card to hand, draw replacement
- **Use**: Card manipulation, combo setup
- **Factions**: Northern Realms, Scoia'tael
- **Strategy**: Reset high-value units for replay

#### Spy
- **Trigger**: On deployment
- **Effect**: Deploy on opponent's side → opponent draws 2 cards → switches to player's side
- **Use**: Opponent disruption, board advantage
- **Factions**: Nilfgaard primary
- **Strategy**: Force bad draws or set up board state

#### Scoia'tael (Agent)
- **Trigger**: On deployment
- **Effect**: Deploy on opponent's side, don't count for opponent, switch when appropriate
- **Use**: Board manipulation without cost
- **Factions**: Scoia'tael exclusive
- **Strategy**: Build advantage without direct play

#### Muster
- **Trigger**: On deployment
- **Effect**: All copies of this card deploy from deck to battlefield
- **Use**: Rapid strength accumulation
- **Factions**: All factions (common in Nilfgaard, Monsters)
- **Strategy**: Set up explosive turn with multiple units

#### Horn
- **Trigger**: When card is played
- **Effect**: +1 strength to all units in target zone
- **Use**: Zone strength multiplication
- **Factions**: All factions
- **Strategy**: Play on zone with most units or highest-value units

#### Morale Boost
- **Trigger**: On deployment or special activation
- **Effect**: All allied units gain +1 strength
- **Use**: Faction-wide buff
- **Factions**: All factions
- **Strategy**: Use as finisher or mid-game boost

#### Tight Bondage
- **Trigger**: Passive or on specific condition
- **Effect**: +1 strength if specific card type is nearby
- **Use**: Synergy building
- **Factions**: Various
- **Strategy**: Deploy cards together for bonus

#### Resilience
- **Trigger**: End of round
- **Effect**: Card returns to hand instead of being discarded
- **Use**: Card recycling
- **Factions**: Skellige primary
- **Strategy**: Reuse powerful cards multiple rounds

#### No Ability
- **Effect**: Card is "vanilla" - just contributes strength
- **Use**: Filler strength
- **Factions**: All (numerous vanilla cards)
- **Strategy**: Combine with ability cards for synergy

---

## Heroes vs Units

### Heroes (Indestructible Legendary Cards)

**Properties**:
- Cannot be destroyed by any means
- Cannot be targeted by removal effects
- Have unique special abilities
- Remain on board throughout game
- Typically high strength values

**Deployment**:
- Heroes are deployed to zones like regular units
- Contribute strength like normal cards
- Cannot be removed or returned to hand

**Abilities**:
- Heroes have special text abilities
- Abilities may activate on deployment or specific triggers
- Some heroes have one-time activation

**Strategy**:
- Deploy heroes early for guaranteed value
- Use hero abilities for synergy
- Heroes provide consistent strength throughout game

### Regular Units

**Properties**:
- Can be destroyed or removed
- Disappear at end of round (unless resilient)
- Regular strength values
- Most common card type

**Deployment**:
- Deploy to zone to contribute strength
- Subject to removal effects
- Can be targeted by spells

**Removal**:
- Non-resilient units removed at end of round
- Can be destroyed by opponent effects
- Go to discard pile

**Strategy**:
- Use units for incremental strength
- Plan for removal and recycling
- Combine for synergy effects

### Key Differences

| Aspect | Heroes | Regular Units |
|--------|--------|---------------|
| Destruction | Cannot be destroyed | Can be removed |
| Persistence | Stay all game | Removed end of round |
| Abilities | Special unique effects | Various abilities |
| Targeting | Cannot be targeted | Can be targeted |
| Zone | Standard zones | Standard zones |
| Recovery | N/A (never removed) | Can return if Resilient |

---

## Card Examples by Type

### Northern Realms Cards

**Unit Examples**:
- Infantry (Close Combat, 2 strength, vanilla)
- Catapult (Siege, 4 strength, specialized)
- Knight (Close Combat, 4 strength, commander synergy)
- Ballista (Siege, 3 strength, strong)

**Special Cards**:
- Commander's Horn (faction-specific leader ability)
- Decoy (card manipulation)

**Heroes**:
- Foltest (leader, special ability)
- Multiple faction heroes

### Nilfgaard Cards

**Unit Examples**:
- Archer (Ranged, 2 strength)
- Assassin (Ranged, 3 strength)
- Soldier (Close Combat, 2 strength)

**Special Cards**:
- Spy (deploy on opponent, force draw)
- Muster cards (multiple copies deploy)

**Heroes**:
- Emhyr (leader)
- Other faction heroes

### Skellige Cards

**Unit Examples**:
- Warrior (Close Combat, 3 strength)
- Raider (Close Combat, 2 strength, resilience)
- Siege Warrior (Siege, 4 strength, resilience)

**Abilities**:
- Many have Resilience
- Some have Medic effects

**Heroes**:
- Crach an Craite (leader)
- Various Skellige heroes

### Scoia'tael Cards

**Unit Examples**:
- Archer (Ranged, 2 strength, agile)
- Elf (Close Combat, 2 strength)
- Agent units (special mechanics)

**Abilities**:
- Many Agile units
- Agent mechanics

**Heroes**:
- Francesca Findabair (leader)
- Scoia'tael heroes

### Monsters Cards

**Unit Examples**:
- Endrega (Siege, 1 strength)
- Nekker (Close Combat, 2 strength)
- Harpy (Close Combat, 3 strength)
- Leshen (Ranged, 4 strength)

**Abilities**:
- Some have synergy bonuses
- Devouring mechanics

**Heroes**:
- Eredin (leader)
- Monster bosses

---

## Card Availability

### In-Game Acquisition
- **Taverns**: Cards obtained through Gwent matches
- **Progression**: Card pools expand as game progresses
- **Difficulty**: Some cards locked behind difficulty/progression

### Regional Variations
- **Novigrad**: Different card pool
- **Skellige**: Faction-specific cards
- **Nilfgaard**: Faction-specific cards
- **Wild Hunt**: Late-game exclusive cards

### Deck Construction Implications
- **Early Game**: Limited card pool, starter decks necessary
- **Mid Game**: Expanded choices, more deck variety
- **End Game**: Full card pool available for optimization

---

## Card Mechanic Details

### Multiple Instances
When multiple instances of same ability exist:
- **Muster**: All copies deploy together (multiplicative effect)
- **Morale**: Multiple boosts stack (+1 each)
- **Resilience**: Each resilient card independently returns
- **Agile**: Each agile unit moves independently

### Ability Interactions
- **Spell + Weather**: Different mechanics coexist
- **Horn + Weather**: Both apply (-1 weather, +1 horn = 0 net)
- **Resilience + Removal**: Resilience doesn't prevent destruction, just persistence
- **Spy + Opponent Effect**: Opponent can't prevent spy mechanics

---

## Implementation Notes

For developers implementing Gwent:

1. **Card Storage**: Track card properties (name, type, strength, zone, abilities)
2. **Zone Management**: Separate strength calculations per zone
3. **Ability Resolution**: Execute abilities in priority order
4. **Persistence**: Track resilient cards between rounds
5. **Hero Handling**: Treat heroes as indestructible
6. **Spell Effects**: Apply modifiers correctly (weather -1, horn +1, etc.)

---

**Document Version**: 1.0 - Accurate W3 Gwent Cards
**Last Updated**: 2026-05-22
**Note**: Specific card pool varies by game region and progression
