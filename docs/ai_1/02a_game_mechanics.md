# Gwent Game Mechanics - The Witcher 3: Wild Hunt

**Master Reference**: [02_game_specifications.md](./02_game_specifications.md)

This document describes the complete game mechanics of Gwent as implemented in The Witcher 3: Wild Hunt.

## Table of Contents
1. [Game Lifecycle](#game-lifecycle)
2. [Combat Zones](#combat-zones)
3. [Turn Structure](#turn-structure)
4. [Card Abilities](#card-abilities)
5. [Scoring System](#scoring-system)
6. [Victory Conditions](#victory-conditions)

---

## Game Lifecycle

### Pre-Game Setup

1. **Deck Selection**: Player selects a constructed deck (25+ cards minimum)
2. **Leader Selection**: Leader is bound to faction
3. **Starting Hand**: Draw 10 cards from deck
4. **First Player**: Determined by coin flip or game rules

### Mulligan (Optional)

Before Round 1 begins, each player may optionally:
- Return any number of cards from hand to deck
- Deck is shuffled
- Draw the same number of cards back

**Note**: Mulligan can only be done once per game, before Round 1.

### Round Structure

Each round follows this sequence:

#### Start of Round
- Clear battlefield (heroes and indestructible cards remain)
- Reset card play status
- Refill hand (for rounds 2+):
  - Winner of previous round: draws until 10 cards
  - Loser of previous round: draws until 11 cards
  - This is the "catch-up" mechanic

#### During Round - Player Turns
While neither player has passed:

1. **Active Player's Turn**:
   - Draw 1 card from deck (if deck not empty)
   - Play up to 1 card from hand (deploy to zone or play special)
   - Card effects resolve
   - Pass turn or declare done (opponent now plays)

2. **Card Deployment**:
   - Units go to one of 3 combat zones
   - Special cards activate immediately
   - Weather cards are placed and affect entire zone
   - Card abilities trigger on deployment

3. **Pass Decision**:
   - Player can pass (lock in current board state)
   - After one player passes, opponent gets final turn
   - If both pass, round ends

#### End of Round - Scoring
1. **Calculate Zone Strength**: Sum all card values in each zone
2. **Apply Modifiers**: 
   - Weather effects (-1 to all cards in zone)
   - Horn effects (+1 to all cards in zone)
   - Other ability modifiers
3. **Determine Zone Winner**: Highest strength wins that zone
4. **Calculate Round Winner**: 
   - Option 1: Sum all zones, highest total wins round
   - Option 2: Win majority of zones (2/3)
5. **Remove Non-Resilient Cards**: Cards without resilience/scoia'tael are discarded
6. **Card Discards**: Removed cards go to "used" pile, not to hand

### Mulligan System (One-Time)

The mulligan phase can only happen:
- Before Round 1 starts
- One time per game
- Not available for Rounds 2-3

Players decide independently whether to mulligan.

---

## Combat Zones

Gwent has three distinct combat zones, each with specific mechanics:

### Close Combat (Melee)
- **Vulnerability**: Susceptible to **Rain** weather
- **Cards**: Close Combat units
- **Strategy**: Balanced strength zone
- **Weather Effect**: Rain reduces all units by 1 strength

### Ranged Combat
- **Vulnerability**: Susceptible to **Fog** weather
- **Cards**: Ranged units, ranged combatants
- **Strategy**: Support and distance units
- **Weather Effect**: Fog reduces all units by 1 strength

### Siege
- **Vulnerability**: Susceptible to **Frost** weather
- **Cards**: Siege units, heavy weapons, artillery
- **Strategy**: High-power units with special effects
- **Weather Effect**: Frost reduces all units by 1 strength

### Hero Zone (Not a Combat Zone)
- **Placement**: Heroes are placed above/separate from combat zones
- **Properties**: 
  - Cannot be destroyed or targeted by effects
  - Have one-time abilities that activate during game
  - Remain in play even after round ends
  - Cannot be played again after ability is used

---

## Turn Structure

### Phase 1: Resource Phase
- **Draw**: Active player draws 1 card from deck
- If deck is empty, draw 0 cards (no effect)

### Phase 2: Action Phase
- **Play 1 Card**: Choose card from hand and:
  - Deploy unit to a combat zone, OR
  - Play special card (immediate effect), OR
  - Play weather card (persistent effect)

### Card Deployment Details
- **Units**: Go to chosen zone, add strength to that zone
- **Special Cards**: Activate immediately (Spy, Decoy, Scoia'tael, etc.)
- **Weather**: Affects entire zone until cleared or weather ends
- **Heroes**: Cannot be deployed by players (only appear as leaders)

### Phase 3: Continuation Decision
- **Continue**: Play another card (back to Phase 2)
  - Only if hand has cards and valid plays exist
- **Pass**: End turn, pass to opponent
  - Locks in current board state
  - Opponent gets final turn option
  - If both pass, round ends

---

## Card Abilities

### Ability Categories

#### Movement/Zone Abilities
- **Agile**: Unit can move freely between any combat zones
  - Useful for weather avoidance or strategic positioning
  - Can move multiple times in a single turn (if multiple Agile cards exist)

#### Effect Abilities
- **Medic**: When deployed, restore a random allied unit from discard pile
  - Used for card recovery strategy
  - Can restore heroes or units

- **Decoy**: Can be used to return target allied card to hand
  - Draws a new card to replace it
  - Combo tool for deck manipulation

- **Horn**: Adds +1 strength to all cards in target zone
  - Can only affect one zone
  - Persists for entire round unless cleared

- **Scoia'tael** (Agents): Units placed on opponent's side, opponent doesn't control them
  - When depleted or passed, these stay with opponent but don't grant strength
  - After opponent passes/ends, they switch to player's side
  - Useful for "stealing" opponent's board state

- **Spy**: Card deployed on opponent's side
  - Opponent immediately draws 2 cards
  - After draw, card switches to player's side
  - Gives opponent resource but gains board position

#### Card Multiplication
- **Muster**: When card is deployed, all copies of that card in deck are also deployed
  - Example: Deploy "Infantry" → all 3 "Infantry" cards deploy
  - Useful for rapidly building strength

#### Resilience/Persistence
- **Resilience** (Skellige): Card remains after round ends, doesn't get discarded
  - Can be reused in next round
  - Persists in player's hand for deployment later

- **Scoia'tael** (agents): Similar to Resilience, stay in play between rounds
  - Can be replayed or remain permanently
  - Faction-specific persistence mechanic

#### Strength Modification
- **Morale Boost**: All allied cards gain +1 strength
- **Tight Bondage**: Card gets +1 if another specific card type is nearby
- Various unit-specific bonuses

---

## Scoring System

### Strength Calculation

For each combat zone:
```
Zone Strength = SUM(all unit values in zone) + modifiers

Where modifiers include:
- Weather effects: -1 per weather card
- Horn effects: +1 per horn card
- Ability bonuses: Various (+1, +2, etc.)
```

### Example Calculation
```
Close Combat Zone has:
- Soldier (2 strength)
- Knight (4 strength)
- Medic (3 strength)
- Horn card effect: +1
- Rain weather: -1

Total = 2 + 4 + 3 + 1 - 1 = 9 strength
```

### Round Scoring

After both players pass:

1. **Calculate each zone strength** for both players
2. **Compare totals**:
   - Highest zone strength wins that zone
   - Equal strength = tie (no point for either player)
3. **Determine round winner**:
   - **Primary Method**: Player with highest total strength across all zones wins round
   - Alternative: Win 2 of 3 zones (if playing with zone-based rules)
4. **Award points**: 1 point to round winner

### Tiebreaker Rules

**Tied Round**:
- If both players have identical total strength
- Round is considered a tie
- Neither player gets a round win point
- Game continues to next round

**Tied Match (after Round 3)**:
- Very rare, indicates very close game
- If still tied: Could result in draw or go to Round 3 tiebreaker
- Tournament rules determine final outcome

---

## Victory Conditions

### Immediate Victory
Player wins the match when they reach **2 round wins**:
- 2-0: After Round 2, if one player won both
- 2-1: Most common, decided in Round 3

### Game Ending Scenarios

#### Scenario 1: 2-0 Victory
- Player A wins Round 1
- Player A wins Round 2
- **Match ends immediately** - Player A wins 2-0
- Round 3 is not played

#### Scenario 2: 1-1 After Round 2
- Player A wins Round 1
- Player B wins Round 2
- **Round 3 must be played** to determine match winner

#### Scenario 3: Round 3 Victory
- After Round 3, player with 2 round wins is declared match winner
- If still 1-1 after Round 3: Draw (extremely rare)

### Player Forfeit
- Player can choose to forfeit current round to preserve cards
- Opponent awarded 1 round win
- Game continues to next round if applicable

### Resource Depletion
- If player runs out of cards and hand, forced to pass on next turn
- If already down in round, losing position becomes worse
- Opponent can win by resource advantage

---

## Special Rules

### Card Interaction Priority

When multiple effects activate:
1. **Immediate effects** (spells, instant actions)
2. **Deployment abilities** (on-play effects)
3. **Passive abilities** (continuous bonuses)
4. **Recalculation** (update all strength totals)

### Weather Mechanics

**Weather Cards**:
- **Rain**: Reduces Close Combat zone by 1
- **Fog**: Reduces Ranged zone by 1
- **Frost**: Reduces Siege zone by 1

**Weather Properties**:
- Persist for entire round unless removed
- Can be stacked with other effects (but multiple same weather = still -1)
- Removed by clearing effect (if any)

### Hero Properties

**Heroes** (special characters, not units):
- Cannot be destroyed by any means
- Have unique one-time abilities
- Abilities activate during game play
- Once ability used, hero becomes inert but remains
- Cannot be played multiple times

### Card Discard Rules

**When cards are removed**:
- Non-resilient units: Sent to discard pile, cannot be recovered
- Resilient units: Return to hand, available for next round
- Scoia'tael units: Persist or return to hand per ability
- Special cards: Go to discard pile

**Discard Pile**:
- Not hand
- Medic ability can recover cards from discard
- Cards in discard do not count toward strength

---

## Implementation Notes

This specification is suitable for:
- Game engine implementation
- AI opponent development
- Deck building tools
- Tournament rule enforcement
- Player education

**Key Implementation Considerations**:
- Weather effects are -1, not debuff
- Leaders have one-time abilities
- Heroes cannot be destroyed
- Resilience/Scoia'tael cards return to hand, not stay on board
- Turn structure is strict (draw → play → pass)
- Passing is mandatory when no legal plays available

---

**Document Version**: 1.0 - Accurate W3 Gwent Mechanics
**Last Updated**: 2026-05-22
**Source**: The Witcher 3: Wild Hunt official game rules
