# Squad cards table schema
## squad_cards_table
- primary key id text
- name text
- description text
- tag text
- zone text references to zones.id
- strength int
- is_hero boolean
- ability_id text references to leader_card_abilities.id
- fraction_id text references to fractions.id
- count int