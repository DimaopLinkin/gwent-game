# Mardrem config table schema
## mardrem_config_table
- primary key id text
- squad_card_before_id text references to squad_cards.id
- squad_card_after_id text references to squad_cards.id