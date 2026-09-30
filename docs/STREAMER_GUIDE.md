# Streamer guide

How to put FishyMarbleRun 2 on your stream. No coding needed. About ten minutes, once.

The game is a web page. OBS shows it as a **Browser source**, your viewers type commands in Twitch chat, and the fish race on your stream.

Game address: **<https://the127.github.io/fishygame2/>**

## What you need

- OBS (or another streaming program with browser sources).
- Your Twitch account (the one that owns the channel).
- A **Client ID** from whoever runs the game for you. It is a string of letters and numbers. It is not a password, so it is fine to paste it in a message.

## 1. Add the game to OBS

1. In OBS, add a source: **+ > Browser**.
2. URL: `https://the127.github.io/fishygame2/`
3. Width **1920**, Height **1080**.
4. Tick **Control audio via OBS**. Without it you may hear nothing on stream.
5. Leave "Shutdown source when not visible" and "Refresh browser when scene becomes active" **off**, so a scene switch does not restart the game.
6. Press OK. The source is transparent on purpose: only fish and UI show, the rest is your scene.

To click buttons inside the game, right-click the source in OBS and choose **Interact**. A window opens where your mouse works like in a normal browser.

## 2. Log in with Twitch

The game reads chat and answers in chat as **you**, so it needs your permission.

1. Open **Interact** on the source.
2. On the home screen paste the **Client ID** and press **Log in with Twitch**.
3. Twitch asks you to allow reading and writing chat. Check that the right account is shown, then accept.
4. The home screen now says "Logged in as <your name>". Press **Open lobby** (or go through the short in-game setup guide, which you can reopen later from Settings).

Good to know:

- The login is remembered by that browser source. If you delete the source and add it again, log in again.
- Twitch logins run out after a while (often within a few hours or a day). When chat stops working, the home screen says the login expired. Open Interact and log in again. Do this before you go live.
- Do not show the Interact window on stream while you are logged in.
- **Log out** on the home screen removes the login.

## 3. Run a round

1. Press **Open lobby**. Viewers type `#join` to get a fish.
2. Press **Start** (or the space bar) when enough fish have joined. Viewers can `#bet` before the start.
3. Watch the race. The podium shows the winners and pays out points. The game returns to the lobby for the next round.

The control panel is a small faint "Controls" tab at the top of the screen. F1 or the tab opens it. It has Open lobby, Start, Stop, Map, Auto mode, the sound sliders and the streamer powers. It is part of the page, so viewers see it too when it is open. Close it with F1 when you are not using it.

**Auto mode** runs rounds on its own: lobby, race, podium, lobby. Good for a stream where you do not want to click anything. Turn it on in the control panel.

## 4. Settings worth knowing

Open **Settings** on the home screen (through Interact). Changes save by themselves. The defaults are fine for a first stream. These are the ones streamers usually touch:

| Setting | Default | What it does |
| --- | --- | --- |
| Min players | 1 | Fish needed before a round can start. Raise to 2 or 3 for real races. |
| Max players | 20 | Lobby size. |
| Countdown (s) | 3 | Seconds between Start and the race. |
| Map | Random | Pick one map, or let the game choose. Random never repeats the last map. |
| Auto mode | off | Rounds run without you. |
| Auto mode join window (s) | 60 | How long the lobby stays open in auto mode. |
| Reply in chat | on | The game writes confirmations and results in your chat. Turn it off if it is too chatty. |
| Finish replay | close | Replays a close finish in slow motion. |
| Starting points | 1000 | What a new viewer begins with (for bets). |
| Streamer powers | on | See below. |
| Random events | off | A wheel before each race can change the rules (low gravity and so on). Fun, but chaotic. |
| Stream layout: Blocked left/right/top/bottom | 0 | Screen edges the game stays out of, for your webcam or chat box. The preview shows the playable area. |
| Colorblind mode | off | Fish get markings as well as colors. |

The prices and payouts (bet limits, 1st/2nd/3rd place rewards, boost and curse costs, shop prices) are in the Betting & Chaos and Shop tabs. **Reset** in Settings restores all defaults.

## 5. Streamer powers

During a race you have three free powers, rationed by a cooldown and a limit per race:

- **Rod (1):** yanks the nearest fish back up the track.
- **Net (2):** holds fish in an area for a moment.
- **Blast (3):** shoves nearby fish away.

Press 1, 2 or 3 (or the panel button), then left-click the spot on the track. Right-click or the same key cancels. Using a power shows a notice and a chat line, so viewers know it was you. Turn powers off or change the cooldown in Settings > Streamer powers.

## 6. Chat commands for viewers

Post this list in a panel or pinned message. `#help` in chat also shows it.

| Command | What it does |
| --- | --- |
| `#join` | Join the open lobby with a fish. |
| `#bet <name> <amount>` | Bet points on a fish by its name (the viewer name on it). `#bet <name> all` bets everything. One bet per round. Winning bets share the pool. |
| `#boost <name>` | Costs points. Gives that fish a push during the race. Not on your own fish. |
| `#curse <name>` | Costs points. Hinders that fish. Not on your own fish. |
| `#points` | Shows your points. |
| `#stats` | Shows your record. `#stats @name` shows someone else's. |
| `#top` | The points leaderboard. |
| `#shop` | What the shop sells. |
| `#fish <species>` | Buy and switch your fish species (trout, puffer, pike, angelfish). |
| `#color <name>` | Buy and switch your fish color. |
| `#hat <name>` | Buy and switch an accessory. `#hat none` takes it off. |
| `#help` | The command list in chat. |

Also:

- **Cheering is free.** During a race, a chat message that names a fish (or `@name`) and contains an emote gives that fish a small push forward. Each viewer has a cooldown, so it cannot decide a race alone.
- **Points** come from winning: 100 / 50 / 25 for 1st, 2nd and 3rd, plus any treasure (coin, pearl, chest) the fish picks up on the way. New viewers start with 1000 points. Points are saved in the browser source.
- **`#meow`** is a hidden extra. During a race, your own fish meows. It is not in `#help`, so viewers have to find it.

## 7. Debug mode (testing without viewers)

To try everything alone, add `?debug=1` to the address: `https://the127.github.io/fishygame2/?debug=1`. The control panel then has **+1 player** and **+5 players** buttons that add fake fish, plus fake chat.

Use it in a private test source, **never on the source you stream with**: fake players and fake chat would show up on stream.

## 8. Before you go live

1. Open the game, log in if the home screen asks for it.
2. Check the version tag in the corner of the control panel (see "Stale version" below).
3. Start a test round with `?debug=1` on a separate source, or just `#join` yourself.
4. Check that you hear the music in the OBS audio mixer.

## Troubleshooting

### No sound

1. On the source, tick **Control audio via OBS** (right-click the source > Properties).
2. In the OBS **Audio Mixer** the source should appear and not be muted. Move its slider up.
3. Browsers only start sound after a click or key press. Open **Interact** on the source and click anywhere once, for example on **Open lobby**.
4. In the game's control panel, check that **Mute all sound** is off and the Master, Music and Effects sliders are up.
5. Still nothing: right-click the source and choose **Refresh cache of current page**, then click once more.

### Old version after an update

OBS keeps the page in a cache, so you can keep seeing an old version after the game was updated. To check, look at the version tag in the control panel (for example `v1.0.0 · a1b2c3d · 2026-10-01 12:00 UTC`) and ask whoever runs the game what the current one is. To update: right-click the source > Properties > **Refresh cache of current page**. Afterwards log in again if the home screen asks.

### White flash or white background

The game paints a dark background while it loads and then turns transparent. A short dark flash at start is normal. A white page or a white box means an old cached version. Refresh the cache as above. If it stays white, check that the source uses the game address above and that you did not add custom CSS that sets a background color.

### Chat does nothing

- Are you logged in? The home screen says so. Twitch logins expire: log in again.
- Is the lobby open? `#join` only works in an open lobby.
- Commands start with `#` and have no space after it.
- If the game does not answer in chat but does react to commands, **Reply in chat** is off in Settings > Chat.

### The login button does nothing

The Twitch login only works in the real web page (not a file on your disk) and needs the Client ID. Ask whoever runs the game to check the Client ID and that Twitch knows the game address.

### A round is stuck or something looks wrong

Press **Stop** in the control panel. The round ends and bets are refunded. If it is still wrong, refresh the source (Properties > Refresh cache of current page) and log in again.
