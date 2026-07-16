# Coin persistence baseline

`CoinManager` declares `user://coins.sav`, but current `_load_coins()` resets in-memory totals and `save_coins()` is disabled for authoritative server synchronization. No fabricated file fixture is committed.
