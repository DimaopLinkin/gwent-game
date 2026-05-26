# Fractions table schema
## fractions_table
- primary key id text
- name text
- tag text
- ability_id nullable text references to fraction_abilities.id
- is_deck boolean