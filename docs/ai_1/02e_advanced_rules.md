# Gwent Advanced Rules & Edge Cases - The Witcher 3: Wild Hunt

**Master Reference**: [02_game_specifications.md](./02_game_specifications.md)

This document covers advanced game mechanics, edge cases, and special situations in Witcher 3 Gwent.

---

## Table of Contents
1. [Weather System Details](#weather-system-details)
2. [Card Interaction Edge Cases](#card-interaction-edge-cases)
3. [Ability Priority](#ability-priority)
4. [Special Mechanics](#special-mechanics)
5. [Rare Situations](#rare-situations)

---

## Weather System Details

### Weather Types & Effects

#### Rain
- **Zone**: Affects Close Combat zone
- **Effect**: All units in Close Combat zone get -1 strength
- **Persistence**: Remains until round end or cleared
- **Stacking**: Multiple Rain cards in same zone = still -1 (not -2)

#### Fog
- **Zone**: Affects Ranged zone
- **Effect**: All units in Ranged zone get -1 strength
- **Persistence**: Remains until round end or cleared
- **Stacking**: Multiple Fog cards = still -1

#### Frost
- **Zone**: Affects Siege zone
- **Effect**: All units in Siege zone get -1 strength
- **Persistence**: Remains until round end or cleared
- **Stacking**: Multiple Frost cards = still -1

### Weather Interaction Rules

**Weather + Horn Interaction**:
```
Zone Strength = Base + Horn(+1) + Weather(-1) = Base (net zero)
```

**Example**:
- Close Combat has Knight (4 strength) and Soldier (2 strength) = 6
- Player plays Horn on Close Combat = 6 + 1 = 7
- Opponent plays Rain on Close Combat = 7 - 1 = 6

**Weather + Units**:
- Weather affects ALL units in zone equally
- No unit is immune to weather (except specific hero cards)
- Cannot target specific units

**Multiple Weather**:
- Only one weather effect per zone type
- Rain on Close Combat: -1
- Rain + Rain on Close Combat: still -1 (not stacking)
- Rain on Close Combat + Fog on Ranged: both apply separately

### Weather Removal

**Methods to Clear Weather**:
1. **Specific Weather Clear Card**: Remove all weather (if available)
2. **Round End**: Weather persists ENTIRE round, cleared at round end
3. **Zone Change**: Agile unit can move to weather-free zone
4. **No Removal**: Cannot be directly removed mid-round

---

## Card Interaction Edge Cases

### Spy Mechanics - Advanced

**Standard Spy Deployment**:
```
1. Player plays Spy on opponent's side
2. Opponent draws 2 cards (forced)
3. After draw, Spy becomes player's card
4. Spy now counts toward player's zone strength
```

**Edge Case 1: Spy Destroyed Before Draw**:
- If opponent plays removal before draw triggers
- Opponent still draws (mechanism completed)
- Spy doesn't switch sides (destroyed)

**Edge Case 2: Opponent at Hand Cap**:
- Opponent has 10 cards (full hand)
- Spy triggers draw → maximum 2 cards drawn
- If opponent has 10+, cannot draw (draw blocked)
- Spy mechanism still triggers (draw attempted)

**Edge Case 3: Multiple Spies**:
- Player plays multiple spies in one round
- Each forces opponent to draw 2
- Opponent draws 4+ cards total
- Each spy can switch to player's side

### Muster Mechanics - Advanced

**Standard Muster**:
```
Player plays Muster card (e.g., Infantry)
All 3 copies of Infantry in deck deploy to battlefield
```

**Edge Case 1: Muster Already Played**:
- If Infantry already deployed earlier in round
- Muster plays, remaining copies deploy
- Example: 1 Infantry deployed, 2 more play from deck = 3 total

**Edge Case 2: Muster with Deck Limit**:
- If only 1 Infantry left in deck (drew 2 already)
- Muster plays, 1 Infantry deploys
- Other copies don't exist to deploy

**Edge Case 3: Multiple Muster Cards**:
- Play Muster on Infantry (deploys all 3)
- Later play Muster on Archer (deploys all archers)
- Both sets deploy in same turn (possible explosive turn)

### Medic Mechanics - Advanced

**Standard Medic**:
```
Medic deploys → restore random unit from discard
```

**Edge Case 1: No Cards in Discard**:
- Medic deploys with empty discard
- No unit to restore
- Medic ability triggers but no effect
- Round continues normally

**Edge Case 2: Resilient Card in Discard**:
- Resilient card was discarded from previous round
- Medic restores it to hand
- Card can be replayed
- Resilience still applies next round

**Edge Case 3: Hero Medic**:
- Hero with medic ability
- Deploys and restores unit
- Hero remains indestructible
- Effect resolution normal

### Resilience Mechanics - Advanced

**Standard Resilience**:
```
At round end: Resilient unit returns to hand (not removed)
```

**Edge Case 1: Resilient Unit Destroyed**:
- Resilient unit hit by removal spell during round
- Unit destroyed (goes to discard immediately)
- Resilience doesn't prevent mid-round destruction
- Only prevents round-end removal

**Edge Case 2: Resilient Unit + Muster**:
- Resilient card with Muster ability
- Plays, deploys all copies
- Round ends, all copies return to hand
- Can redeploy all next round

**Edge Case 3: Resilient + Medic**:
- Medic has Resilience
- Restores unit from discard
- Round ends, Medic returns to hand
- Can replay Medic and restore another unit

### Agile Mechanics - Advanced

**Standard Agile**:
```
Unit can move between any combat zone
Timing: Can move during player's turn
```

**Edge Case 1: Agile Unit Destroyed While Moving**:
- Agile unit targets to move zones
- Opponent plays removal before move completes
- Unit destroyed before move
- Unit dies in original zone

**Edge Case 2: Multiple Agile Units**:
- Deploy 2 Agile units to Close Combat
- Move both to Ranged
- Both now count in Ranged
- Original zone loses strength

**Edge Case 3: Agile + Weather Avoidance**:
- Deploy Agile unit to Close Combat
- Rain plays on Close Combat (-1)
- Move Agile unit to Ranged
- Unit no longer affected by Rain
- Unit gains strength back

### Agent (Scoia'tael) Mechanics - Advanced

**Standard Agent**:
```
Deploy on opponent's side → don't count for opponent
At appropriate time → switch to player's side
```

**Edge Case 1: Agent Destroyed**:
- Agent on opponent's side
- Opponent plays removal on agent
- Agent destroyed (doesn't switch)
- Player loses the agent permanently

**Edge Case 2: Multiple Agents**:
- Multiple agents on opponent's side
- Don't count for opponent
- Each can switch independently
- Can create board control advantage

**Edge Case 3: Agent vs Spy**:
- Spy: Forces draw, then switches (gives opponent resource)
- Agent: Deploys quietly, switches later (no opponent resource)
- Different strategic implications

---

## Ability Priority

### Resolution Order

When multiple abilities trigger in same turn:

**Priority Hierarchy**:
1. **Immediate Effects** (instant spells, direct removal)
2. **Deployment Abilities** (on-play effects like Medic, Muster)
3. **Persistent Abilities** (Horn, passive bonuses)
4. **Card Resolution** (all updates apply, then recalculate)

**Example Resolution**:
```
Player plays Card A (has on-deploy effect)
Effect 1: Card A deploys to zone
Effect 2: Medic ability triggers (if present) → restore card
Effect 3: All strength recalculated
Effect 4: Opponent responds (if any response available)
```

### Simultaneous Ability Stacking

**Multiple Cards, Same Ability**:
- Muster appears 3 times in deck
- Player plays one Muster card
- All 3 copies deploy simultaneously
- Strength added all at once
- Recalculation happens once

**Example Stacking**:
```
Play Morale Boost (all units +1)
3 units on board:
- Unit A: 3 + 1 = 4
- Unit B: 2 + 1 = 3
- Unit C: 4 + 1 = 5
Total = 12 (applied simultaneously, not sequentially)
```

---

## Special Mechanics

### Weather + Card Type Interactions

**Weather + Siege Units**:
- Siege units strong but weather-vulnerable
- Frost reduces all siege by -1
- Example: Ballista (4) - Frost (-1) = 3

**Weather + Special Units**:
- Some units may be immune (rare)
- Most units affected uniformly
- No exceptions for specific units typically

### Horn + Zone Interaction

**Horn Effect**:
- +1 to ALL units in target zone
- Only affects one zone
- Persists entire round
- Can be deployed multiple times on different zones

**Multiple Horns**:
- Two horns on same zone = +1 each (total +2)
- Stacking allowed for horns
- Each horn +1 effect

### Resilience + Round End

**End of Round Mechanics**:
```
For each unit on board:
  IF has Resilience:
    Return to hand
  ELSE:
    Go to discard pile
```

**Exception - Heroes**:
- Heroes never discarded
- Heroes never removed
- Heroes stay on board permanently
- Heroes don't return to hand

---

## Rare Situations

### Deck Out

**When Deck Becomes Empty**:
- Player can no longer draw cards
- If forced to draw: draw 0 cards (no effect)
- Player can still play cards from hand
- When hand empty + deck empty: forced to pass next turn

**Rare Scenario**:
```
Round 3, both players low on cards
Player runs out of deck
Can still play remaining hand cards
But will eventually be forced to pass
```

### Hand Cap

**Maximum Hand Size**:
- Maximum 10 cards (typical)
- If would draw over limit: capped at maximum
- Excess cards cannot be drawn
- Forced to play or discard to draw

### No Legal Plays

**Forced Pass**:
- If player has no legal plays (hand empty or no valid targets)
- Player must pass
- Cannot continue turn
- Opponent gets next turn

### Infinite Loops

**Unlikely but Possible**:
- Card A triggers Card B
- Card B triggers Card A
- Creates infinite loop

**Resolution**:
- Resolve loop one complete cycle
- After one full resolution, loop stops
- Board state locks, continue game

---

## Common Mistake Clarifications

### Weather ≠ Debuff
- Weather is -1 strength, not damage
- Doesn't remove units, just reduces strength
- Can be compensated by Horn (+1)

### Resilience ≠ Indestructible
- Resilience only prevents round-end removal
- Can be destroyed by spells/effects during round
- Heroes are indestructible, units are not

### Spy ≠ Bad
- Spy forces opponent to draw
- But gives player board advantage
- Can be strategic if managed well

### Agent ≠ Automatic Win
- Agents give unpredictability
- But give opponent awareness
- Can be countered or removed

### Muster = Powerful
- Multiple units deploy simultaneously
- Creates explosive turns
- Can swing game dramatically

---

## Advanced Strategies

### Weather Prediction
- Play weather on opponent's likely strong zone
- Force opponent to adapt
- Can swing round calculation

### Spy Timing
- Use spy early to disrupt opponent's hand
- Or late to secure board advantage
- Timing determines effectiveness

### Resilience Stacking
- Build deck around resilience
- Reuse same cards multiple rounds
- Create long-term advantage

### Agent Placement
- Deploy agents strategically
- Switch at optimal moments
- Create tactical surprises

### Horn Placement
- Play horn on zone with most units
- Or zone with highest-value units
- Affects final calculation significantly

---

## Implementation Notes

For developers implementing advanced mechanics:

1. **Weather Tracking**: Track which zones have weather
2. **Resilience Handling**: Separate return-to-hand from discarding
3. **Ability Stacking**: Execute abilities in priority order
4. **Deck Out Check**: Verify deck size before draws
5. **Hand Cap Enforcement**: Limit hand to maximum
6. **Loop Detection**: Prevent infinite ability loops
7. **State Validation**: Verify legal game states

---

**Document Version**: 1.0 - Accurate W3 Gwent Advanced Rules
**Last Updated**: 2026-05-22
**Difficulty**: Advanced players and implementers
