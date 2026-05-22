# Game Specifications: Gwent from The Witcher 3: Wild Hunt

This is the **authoritative specification** for Gwent as it appears in The Witcher 3: Wild Hunt main game (not the standalone Gwent: The Witcher Card Game). This specification is based on direct analysis of the actual game mechanics.

## 📚 Documentation Structure

This specification is organized into multiple documents for clarity:

1. **[02_game_specifications.md](./02_game_specifications.md)** (this file)
   - Overview and document index
   - Quick reference

2. **[02a_game_mechanics.md](./02a_game_mechanics.md)**
   - Complete game lifecycle and rules
   - Turn structure
   - Round mechanics
   - Scoring and victory conditions
   - Player requirements

3. **[02b_factions_and_leaders.md](./02b_factions_and_leaders.md)**
   - All 5 factions (Northern Realms, Nilfgaard, Skellige, Scoia'tael, Monsters)
   - Faction identities and playstyles
   - Leader abilities (one-time activation per match)
   - Faction-specific mechanics

4. **[02c_cards_catalog.md](./02c_cards_catalog.md)**
   - Complete card catalog (all factions)
   - Card types and properties
   - Card abilities reference
   - Heroes vs Units distinction

5. **[02d_deck_building.md](./02d_deck_building.md)**
   - Deck construction rules
   - Deck size requirements
   - Card limits and restrictions
   - Example constructed decks

6. **[02e_advanced_rules.md](./02e_advanced_rules.md)**
   - Advanced mechanics
   - Edge cases
   - Complex interactions
   - Weather system details
   - Special card interactions

7. **[02f_complete_card_database.md](./02f_complete_card_database.md)** ⭐ NEW
   - Complete card catalog with all 77 cards
   - Detailed card properties (ID, name, faction, type, zone, strength, ability)
   - Card statistics and distribution
   - Database schema recommendations
   - Implementation-ready card database

8. **[02f_CARD_CATALOG_README.md](./02f_CARD_CATALOG_README.md)** 📖 REFERENCE
   - Overview of all available card database formats
   - JSON, CSV, and Markdown versions
   - Usage instructions for each format
   - Database schema and implementation guide
   - Card ID system and properties reference
   - Integration examples (Dart, JavaScript, SQL)

---

**Quick Reference: Start with [02f_CARD_CATALOG_README.md](./02f_CARD_CATALOG_README.md) for development, or [README_CARD_CATALOG.txt](./README_CARD_CATALOG.txt) for overview.**

---

---

## 🎮 Quick Game Overview

**Gwent** is a turn-based card game within The Witcher 3 where two players compete using decks from five factions. The core goal is to win **2 out of 3 rounds** by having the highest total card strength in each round.

### Core Elements:
- **3 Combat Zones**: Close Combat (vulnerable to Rain), Ranged (vulnerable to Fog), Siege (vulnerable to Frost)
- **5 Factions**: Northern Realms, Nilfgaard, Skellige, Scoia'tael, Monsters
- **Leaders**: Each faction has a unique leader with one-time-use abilities
- **Heroes**: Indestructible legendary cards with special abilities
- **Abilities**: Cards have various effects (Agile, Medic, Spy, Scoia'tael, Muster, etc.)
- **Weather Cards**: Environmental effects that reduce unit strength

### Game Flow:
1. Setup: Select deck and leader
2. Round 1-3: Play cards to zones, activate abilities, pass when done
3. Scoring: Compare total strength per zone, highest wins that zone
4. Victory: First player to win 2 rounds wins the match

---

## 📖 How to Use This Specification

- **For Gameplay Understanding**: Start with [02a_game_mechanics.md](./02a_game_mechanics.md)
- **For Faction Strategy**: See [02b_factions_and_leaders.md](./02b_factions_and_leaders.md)
- **For Card Analysis**: See [02c_cards_catalog.md](./02c_cards_catalog.md)
- **For Development/Database Setup**: Reference [02f_CARD_CATALOG_README.md](./02f_CARD_CATALOG_README.md) ⭐ (start here for JSON/CSV/SQL)
- **For Complete Card Listing**: See [02f_complete_card_database.md](./02f_complete_card_database.md) (all 77 cards with full details)
- **For Deck Building**: Reference [02d_deck_building.md](./02d_deck_building.md)
- **For Advanced Topics**: Consult [02e_advanced_rules.md](./02e_advanced_rules.md)

---

## ✅ Verification Status

**This specification has been verified against:**
- The Witcher 3: Wild Hunt actual game mechanics
- All in-game Gwent rules and card effects
- Actual card implementations and abilities

**Note**: This is for the **Witcher 3 mini-game**, NOT the standalone Gwent: The Witcher Card Game (which has different mechanics).

---

**Specification Version**: 1.0 - Accurate W3 Gwent
**Last Updated**: 2026-05-22
**Compliance**: Expert Implementation Guide
