# Special cards table schema
## special_cards_table
- primary key id text
- name text
- description text
- tag text
- ability_id text references to special_card_abilities.id
- fraction_id text references to fractions.id
- count int