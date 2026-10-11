# Twin config table schema
## twin_config_table
- primary key id text
- squad_card_trigger_id text references to squad_cards.id
- squad_card_slave_id text references to squad_cards.id