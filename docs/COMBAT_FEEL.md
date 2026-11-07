# Combat feel: team combos

- Enemies are few and tanky by default; swarms of small enemies are an occasional variety wave.
- A lone player can chain short combos; bouncing an enemy between players (relay) extends them far further.
- Damage grows with combo length (`Coop.combo_mult`), which is what makes tanky enemies killable quickly.
- When a combo ends (timer runs out) a long combo pays coins into the shared wallet.
- Frame data goal: every class can chain a starter into itself (hitstun >= next move's startup + 4 frames), solo
  juggles last 5–7 hits but with weaker launches than relays.
