# Base → Extension COMMAND tree (0.1)

**HARDCODE:** base = **one word**. Everything after that word = **extension** under that base.

```
ЯBOT COMMANDS
├── ping                          # companion heartbeat (≠ ICMP)
│   ├── utah                      # alias path
│   └── [host flags…]             # only via pingpong / PING -C (net-test tree)
├── pong                          # heartbeat reply
├── help                          # aliases: commands · functions · ?
├── think
├── mind
│   ├── loop
│   └── tape                      # → transcript family
├── tongue                        # dual tongue
├── teachings
│   └── forever
├── bolte                         # aliases: being · rzl being
├── rzl                           # .RZL envelope
├── revert
├── reform
├── respawn
├── evolve                        # Decider-gated
├── snapshot
├── mode
├── online                        # bonus only
├── offline                       # premier
├── search <query>                # ONLINE bonus
├── nearby [query]
├── place
│   ├── set <lat>,<lon> [label]
│   └── clear
├── research <topic>              # ONLINE
├── read <url>                    # ONLINE
├── token
│   ├── blast / tokenblast
│   └── …                         # RFID unit spine
├── coin
│   ├── send [to] via bluetooth|lan|usb|qr|nfc|share
│   ├── path begin|note|report|clear|status
│   ├── dna [touch <kind> <id> [role]]
│   ├── mysteries
│   ├── bt on|off|status|clear|reset
│   ├── carriers
│   ├── lan on|off|clear
│   ├── usb drain
│   ├── qr eat <json|path>
│   ├── nfc eat
│   └── share eat
├── mint
│   ├── unit
│   ├── twin prepare solana | paste | status
│   └── (bot mint → prefer bot)
├── yacode                        # aliases: languages
├── cos
├── voice
├── triangle
├── heart
│   └── status
├── ghost
│   ├── status
│   ├── establish
│   └── claim
├── essence
│   ├── mint
│   ├── transfer
│   ├── settle
│   └── clear clog
├── teach […]
├── lock […]
├── remember […]
├── transcript                    # aliases: mind tape · tape
├── lab
│   ├── chamber
│   └── scout                     # → scout
├── wallet
├── home                          # aliases: ghost · ghost home
├── scout
│   ├── walis                     # offline tidy only
│   └── (lab scout)
├── shot
│   ├── macos | ios
│   ├── select | window
│   └── (screenshot · lab shot)
├── walis                         # also under scout
├── who                           # U · Я · guests / next ЯBOT#N
├── bot
│   ├── mint | create | new [Name]
│   ├── enter [Name]
│   └── leave
├── labels                        # also: label teach
└── pingpong                      # net-test ROOT (extension family of ping probes)
    ├── ping [-c N] <host>        # ICMP — NOT bare companion ping
    ├── nslookup <host>
    ├── host | dig <host>
    └── help
```

## Flat extension map (manual quick)

| Base | Extensions |
|------|------------|
| ping | utah; (ICMP only via pingpong/PING) |
| help | commands · functions · ? |
| mind | loop · tape |
| teachings | forever |
| place | set · clear |
| token | blast |
| coin | send · path · dna · mysteries · bt · carriers · lan · usb · qr · nfc · share |
| mint | unit · twin |
| heart | status |
| ghost | status · establish · claim |
| essence | mint · transfer · settle · clear |
| lab | chamber · scout |
| home | ghost |
| scout | walis |
| shot | macos · ios · select · window |
| bot | mint · create · new · enter · leave |
| labels | teach |
| pingpong | ping · nslookup · host · dig · help |

Contract siblings: `BASE-COMMANDS-ONE-WORD-0.1.md` (definitions + proficiency).
