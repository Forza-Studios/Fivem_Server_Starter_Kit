# Audio sources and attribution

The bundled one-shots are edited derivatives of the following public field
recordings. Source licensing was checked on the creator's Freesound page on
2026-09-28. The public HQ MP3 previews were used, not a paid sound library,
game rip, or an authenticated download. Attribution applies to the sound
assets and does not change the license of the resource's code.

## snap_01–03.wav, crackle_01–03.wav, bang_01–03.wav

- Work: **Motorbike Driveby and Backfire**
- Creator: **Yoyodaman234**
- Source: https://freesound.org/people/Yoyodaman234/sounds/667592/
- Download used: https://cdn.freesound.org/previews/667/667592_2792951-hq.mp3
- License: **Creative Commons CC0 1.0 Universal**
- License text: https://creativecommons.org/publicdomain/zero/1.0/legalcode

The creator describes a real motorbike drive-by/backfire recorded in Brisbane
with a BP4025 microphone and Zoom F6. Credit is retained voluntarily.

## burble_01–03.wav

- Work: **Rally Car Pulls away comes back.wav**
- Creator: **luminadii**
- Source: https://freesound.org/people/luminadii/sounds/336797/
- Download used: https://cdn.freesound.org/previews/336/336797_4040987-hq.mp3
- License: **Creative Commons Attribution 4.0 International (CC BY 4.0)**
- License text: https://creativecommons.org/licenses/by/4.0/legalcode

The burble derivatives remain available under CC BY 4.0. Keep this attribution
and license notice when redistributing them. Neither creator endorses Oxlyn.

## Changes made

Selected short exhaust transients, decoded/resampled to 48 kHz, downmixed to
mono, aligned the pressure onset, varied pitch/filters, suppressed underlying
engine spectrum in snap/bang, applied a short exponential tail gate, normalized
peaks, and tapered edges. The snap/bang assets are variations of one prominent
backfire in the source, not independently recorded explosions. Crackles
also use smaller engine pressure pulses and burbles use rally exhaust texture.
Output is PCM16 WAV. These are edited game effects derived from field
recordings, not raw isolated studio backfire measurements. Exact source
offsets, pitch ratios, lengths and SHA-256 checksums are in `bank.json`.

The Web Audio fallback synthesis is original procedural code; it does not
use these recordings or any third-party recording.

## Isolated ALS attacks and pressure bodies — v3.4

- Work: Car Antilag (No cleanup, 32float)
- Creator: modusmogulus
- Source: https://freesound.org/people/modusmogulus/sounds/797835/
- Download used: https://cdn.freesound.org/previews/797/797835_15956618-hq.mp3
- Licence: CC0 1.0 — https://creativecommons.org/publicdomain/zero/1.0/

Six different pressure attacks were cropped to 96 ms, onset-aligned, mono-downmixed, filtered and given short decaying envelopes. Stationary surrounding motor spectrum was attenuated. The six pressure bodies are low-frequency derivatives of those matching attacks, not six additional recordings. Runtime plays finite grains at active shared ignition times. The historical als_engine filenames now contain isolated exhaust attacks, never looped motors. All generated continuous engine assets from v3.2 have been replaced. Checksums and source offsets appear in bank.json. Automated speech checks do not certify perfect separation or subjective realism.

## v4.0

The v4 bank layers the recordings above, unchanged in origin and licence, under original procedural synthesis written for this resource (tools/build-bank.js). bank.json records which recording each file uses: the als_engine/als_pressure takes are the recorded layer of als_hit/als_bang. The turbo_* files contain no recording. The CC BY 4.0 attribution for the burble recordings still applies to burble_01-06.wav.

## v4.1 — additional recordings

bank.json lists, per file, which of these recordings it contains. All were taken
from the public HQ MP3 previews, decoded, resampled to 48 kHz mono, onset
aligned, pitch shifted, given a decay envelope and layered.

| Source file | Work | Creator | Page | Licence |
| --- | --- | --- | --- | --- |
| real_backfire_a.wav | S012_Engine_Backfire_Mono.wav | Pól | https://freesound.org/people/P%C3%B3l/sounds/385935/ | CC0 1.0 |
| real_bang_b1.wav, real_bang_b2.wav, real_bang_b3.wav, real_bang_b4.wav | Bang Pop Crack Whoomph | uEffects | https://freesound.org/people/uEffects/sounds/207868/ | CC0 1.0 |
| real_pop_d.wav | Bang, Pop | DigitalDominic | https://freesound.org/people/DigitalDominic/sounds/178474/ | CC0 1.0 |
| real_backfire_c.wav | Backfire | JustInvoke | https://freesound.org/people/JustInvoke/sounds/446101/ | CC BY 4.0 |
| real_boosted_e.wav | Boosted Bang | moodyfingers | https://freesound.org/people/moodyfingers/sounds/719206/ | CC BY 4.0 |

CC BY 4.0: https://creativecommons.org/licenses/by/4.0/legalcode — keep this
attribution when redistributing the files that contain real_backfire_c.wav or
real_boosted_e.wav. No creator endorses Oxlyn.

## v4.3 — gunshot and firecracker recordings

Single gunshot reports and firecrackers, used for booms, the stronger bangs,
snaps, crackles and anti-lag reports. All CC0 1.0, verified on each page on
2026-09-28; previews decoded, resampled to 48 kHz mono, onset aligned.

| Source file | Work | Creator | Page |
| --- | --- | --- | --- |
| real_gun_a.wav | Single Gunshot 5.2.wav | morganpurkis | https://freesound.org/s/386845/ |
| real_gun_b.wav | Single Gunshot 4.2.wav | morganpurkis | https://freesound.org/s/384687/ |
| real_gun_c.wav | Single Gunshot 5.3.wav | morganpurkis | https://freesound.org/s/391180/ |
| real_gun_d.wav | Single Gunshot 5.4.wav | morganpurkis | https://freesound.org/s/391847/ |
| real_gun_e.wav | Single Gunshot 4.3.wav | morganpurkis | https://freesound.org/s/390970/ |
| real_gun_f.wav | Single Gunshot 6 HP.wav | morganpurkis | https://freesound.org/s/388273/ |
| real_gun_g.wav | Single Gunshot.wav | morganpurkis | https://freesound.org/s/369782/ |
| real_gun_h.wav | Rifle Gun Shot 01.wav | LilMati | https://freesound.org/s/433858/ |
| real_gun_i.wav | Heavy Artillery Shot | LilMati | https://freesound.org/s/441373/ |
| real_gun_j.wav | Reddit Gunshot | qubodup | https://freesound.org/s/826162/ |
| real_gun_k.wav | Single Pistol Gunshot 2.wav | morganpurkis | https://freesound.org/s/371440/ |
| real_gun_l.wav | Layered Gunshot 8.wav | Xenonn | https://freesound.org/s/128302/ |
| real_crack_a.wav | gun lee enfield 303 rifle fire shot loud badass crispy.wav | kyles | https://freesound.org/s/450852/ |
| real_crack_b.wav | Homeade gun shot1 (NO ECHO).wav | Noah_Fletcher | https://freesound.org/s/200245/ |
| real_crack_c.wav | 50 cal shot.wav | ajhartman42295 | https://freesound.org/s/668071/ |
| real_crack_d.wav | Pistol Shot | Kodack | https://freesound.org/s/253736/ |
| real_fire_a.wav | EXPLODE_FIRECRACKER.wav | keng-wai-chane-chick-te | https://freesound.org/s/462363/ |
| real_fire_b.wav | firecracker | grobbd | https://freesound.org/s/263536/ |
| real_fire_c.wav | Pop.wav | Joedozer | https://freesound.org/s/396422/ |
| real_fire_d.wav | Firecracker Mat Indoors | modusmogulus | https://freesound.org/s/752625/ |
| real_fire_e.wav | Rifle gunshot, one shot | felix.blume | https://freesound.org/s/710084/ |
| real_fire_f.wav | Cap_Gunshot | SunBanana | https://freesound.org/s/860182/ |

License text: https://creativecommons.org/publicdomain/zero/1.0/legalcode.
Credit is retained voluntarily; no creator endorses Oxlyn.

## v4.4 — further gunshot and firecracker recordings

Used by the takes added in 4.4 (snap/crackle/bang 17-24, burble and boom 13-16).
All CC0 1.0, verified on each page on 2026-09-28; previews decoded, resampled
to 48 kHz mono, onset aligned. bank.json lists which file contains which.

| Source file | Work | Creator | Page |
| --- | --- | --- | --- |
| real_gun_m.wav | 9mm pistol shot | michorvath | https://freesound.org/s/427592/ |
| real_gun_n.wav | AR15 pistol shot | michorvath | https://freesound.org/s/427598/ |
| real_gun_p.wav | gunshot | JeffPearson | https://freesound.org/s/849844/ |
| real_gun_r.wav | handgun-one-shot.wav | DeltaCode | https://freesound.org/s/668348/ |
| real_gun_s.wav | Pistol Shot | LeMudCrab | https://freesound.org/s/163456/ |
| real_gun_t.wav | Rifle Shot (M1 Garand) | Rijam | https://freesound.org/s/385785/ |
| real_gun_v.wav | Realistic gunshot | DELTA_12 | https://freesound.org/s/336157/ |
| real_crack_e.wav | Centerfire Rifle Gun Shot 01.wav | LilMati | https://freesound.org/s/411567/ |
| real_crack_f.wav | Sniper Shot in Field 2 (M2010 Enhanced Sniper Rifle ESR) | qubodup | https://freesound.org/s/855607/ |
| real_crack_g.wav | Single Gunshot | freemusicpromo | https://freesound.org/s/512942/ |
| real_fire_g.wav, real_fire_h.wav, real_fire_i.wav | Firecracker Mat Indoors | modusmogulus | https://freesound.org/s/752625/ |
| real_fire_j.wav, real_fire_k.wav | firecracker tablet.aif | ikbenraar | https://freesound.org/s/126566/ |

License text: https://creativecommons.org/publicdomain/zero/1.0/legalcode.
Credit is retained voluntarily; no creator endorses Oxlyn.

## v4.6 — air, flame, steam and cooling metal

Used by whoosh_01-08 (the rush of the flame), hiss_01-06 (rain on a hot pipe),
tick_01-10 (the pipe cooling) and turbo_flutter_03-10 and turbo_bov_03-10 (the
turbo one-shots made from recordings; 01-02 of each remain procedural). All
CC0 1.0, verified on each page on 2026-09-28; previews decoded, resampled to
48 kHz mono, levelled and given an envelope. bank.json lists which file
contains which.

| Source file | Work | Creator | Page |
| --- | --- | --- | --- |
| real_air_a.wav | Compressed Air-Short-9 | wavecal22 | https://freesound.org/s/753138/ |
| real_air_b.wav | Air compressor valve | soneproject | https://freesound.org/s/185515/ |
| real_air_c.wav | release_air_pffft.wav | reg7783 | https://freesound.org/s/131302/ |
| real_air_d.wav, real_air_e.wav, real_air_f.wav, real_air_g.wav, real_air_h.wav, real_air_i.wav, real_air_j.wav, real_air_k.wav | AIRBrst_Air Pump Release Variations_PF_265 DAYS OF SOUND | itmightgetloud | https://freesound.org/s/751354/ |
| real_air_l.wav | Air (or steam) pressure release | brunoboselli | https://freesound.org/s/457294/ |
| real_air_m.wav | air_brakes_loud_fade_out.wav | rabbydaw | https://freesound.org/s/504865/ |
| real_flame_a.wav | Fire Burst Flash | Za-Games | https://freesound.org/s/539972/ |
| real_flame_b.wav | Flamethrower | 1bob | https://freesound.org/s/831929/ |
| real_flame_c.wav | Fireball | NearTheAtmoshphere | https://freesound.org/s/683179/ |
| real_flame_d.wav | Flame Burst | magnuswaker | https://freesound.org/s/592572/ |
| real_flame_e.wav | Combust.wav | GrimGrum | https://freesound.org/s/412558/ |
| real_flame_f.wav | Basic Fire Whoosh 2 | LookIMadeAThing | https://freesound.org/s/260555/ |
| real_flame_g.wav | Basic Fire whoosh | LookIMadeAThing | https://freesound.org/s/260554/ |
| real_flame_h.wav | Flamethrower_Weapon_Short_Medium_Bursts.wav | AslakHostaker | https://freesound.org/s/395038/ |
| real_flame_i.wav | Blast + Flamethrower cooldown | Breviceps | https://freesound.org/s/447941/ |
| real_steam_a.wav | steam_burst.wav | pengo_au | https://freesound.org/s/90143/ |
| real_steam_b.wav | Steam/hiss | wubitog | https://freesound.org/s/234782/ |
| real_steam_c.wav, real_steam_d.wav | metal_hissing.wav | vibe_crc | https://freesound.org/s/50620/ |
| real_steam_e.wav, real_steam_f.wav | ShovelSizzle8_mod.MP3 | rabban625 | https://freesound.org/s/436470/ |
| real_tick_a.wav, real_tick_b.wav, real_tick_c.wav, real_tick_d.wav, real_tick_e.wav, real_tick_f.wav, real_tick_g.wav | Clicking Engine Cooldown | CmdRobot | https://freesound.org/s/539514/ |

License text: https://creativecommons.org/publicdomain/zero/1.0/legalcode.
Credit is retained voluntarily; no creator endorses Oxlyn.
