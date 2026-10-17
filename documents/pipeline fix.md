It's probably several problems stacking up, and some of them come from my pipeline design, not your execution. Here they are, roughly from most to least likely.

Likely causes

1. Octave folding and a narrow range destroy the melody's shape. Recognizing a tune depends on the contour: which notes go up, which go down, and by how much. My mapping squeezes everything into about 1.5 octaves (MIDI 64-82) by folding outliers up or down an octave. Vivaldi's violin line spans well over two octaves, so folding turns rising phrases into falling ones. The first version of the pipeline was worse, because it folded every note into the nearest octave of a root.

2. Thinning removes notes from the melody. The min_gap_ms filter (180-350 ms) deletes any note that comes too soon after the previous one. In fast pieces like Spring, that drops a large share of the notes. If the player only hears the notes left in the chart, the tune is incomplete, and it also loses its rhythm.

3. Meows are bad pitch carriers. This is a real limit of the concept. Meows glide and have vowel-like, noisy timbres, so the ear struggles to hear a clear pitch. Their attacks are also soft, so the rhythm blurs. A piano note is pitch plus a sharp onset. A meow is mostly texture.

4. Cross-sample intervals are wrong if the roots are off. Within one sample, every note keeps correct intervals. But a jump from the "mid" sample to the "high" sample is only correct if both roots were measured exactly. A root that's a quarter-tone off puts every note using that sample slightly out of tune, which is audible against the backing track. Because meows glide, the measured "root" is itself ambiguous.

5. Five different timbres break the melody into pieces. When each note jumps between different recordings (different cats, different glides), the ear hears separate sounds instead of one voice singing a line. Melody is easiest to follow when one consistent timbre carries it.

6. Pitch shifting by playback speed also changes the length. A note shifted down by 3 semitones is about 19% longer, and one shifted up is shorter. The rhythm gets uneven, and the meow's vowel character changes too (the chipmunk and monster effect).

7. Wrong track or wrong notes. The "track with the most notes" is often the accompaniment, not the melody. And "keep the highest note in each chord" can pick ornaments or harmony over the actual tune.

Quick tests to find your cause

Run these in order. Each takes a few minutes.

Piano test. Render the chart's notes with a normal piano sound, using the same thinning, folding, and transposition. If that isn't recognizable, the problem is in the chart (causes 1, 2, 7). If it is, the problem is in the meows (3-6).
One-sample test. Play the full chart using only the mid sample, with all the pitch shifting. If it's recognizable, the cross-sample jumps (4, 5) are the issue.
No-thinning test. Run the full melody with no thinning and no folding, on a simple tune like Ode to Joy. If this works, your meows can carry a melody, and your processing was the problem.
Fixes
Start with simple melodies. Ode to Joy has a range of only about a sixth, plus stepwise motion and slow notes. It's the best case for meows. Also try Twinkle Twinkle, Happy Birthday, Greensleeves, and the Canon in D melody. Save Vivaldi for later, or use only the famous opening motif instead of the whole piece.
Stop folding. Choose a transposition so the melody fits in the available range without folding. If a piece doesn't fit, pick another piece, or limit the chart to a section that fits.
Never drop melody notes from the audio. If the chart is thinned for playability, auto-play the skipped notes as quiet meows so the tune is complete, and the player's taps add the main notes. Alternatively, for the MVP, choose slow pieces and don't thin at all.
Pre-render one file per semitone instead of shifting at runtime. Use a proper pitch shifter that preserves duration, such as Rubber Band (pyrubberband), librosa, or Audacity's tools. Generate one file per semitone across your range, about 25 small files. This fixes the duration problem (6) and lets you tune any bad note by hand. The game then plays meow_72.ogg and does no shifting at all.
Use one consistent voice. Pick one good meow, and make it more tonal and steady. Choose a stable middle section, shorten it to 150-250 ms, and optionally correct its pitch glide with Melodyne or an autotune plugin. Give it a sharp attack. Then derive all semitone files from that one recording. You can still use a second voice for a different register, as long as both sound like the same cat.
Make the pitch clearer and add structure. Pitch correction on the sample makes the notes read as notes. Keep the backing track simple and clearly in tune, so the ear has a reference.
Check the melody track by ear before generating anything else, and use pretty_midi to see which instrument holds the tune.

The core tension is that the more "cat-like" the meow, the less "note-like" it is. You need to find the balance by making the meows slightly more tonal than a real cat would be.

If you tell me which piece you tested and what you hear (for example, the rhythm is recognizable but the pitches aren't, or the reverse), I can narrow it down further. I can also write an offline preview script that renders any chart into a meow-only WAV, so you can iterate on the sound without opening the game, and update the pipeline doc for the per-semitone approach.