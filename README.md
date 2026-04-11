
# Spreax Motel

A simple motel script for qbcore/qbox, maybe I'll make it for esx too but I need to see if someone need it...
Please mind that is a SIMPLE script and I can add some features later but it's not anything like ingame creator or something like that.

## COMMENTS IN THE ENTIRE CODE ARE MADE BY AI FOR PEOPLE WHO DON'T UNDERSTAND ALOT OF CODING!

# Discord -> [Join Here](https://discord.gg/PKygX7tsRc)
# Preview -> [Watch Here](https://youtu.be/i9_H37dJWY4)


![Motel Screenshot](https://i.imgur.com/N75W39Q.jpeg)


## Features

- Buy a motel room for a fixed price
- Stash and wardrobre menus
- If you leave, when you load again you can interact in your bucket again
- Anti buckets exploit
- Every player have one specific bucket
- MLO or IPL settings, you can choose


## Installation

- Download the last build and drag it into your server
- Change the config and locales
- Add into your server.cfg

```cfg
  ensure spreaxMotel
```
### NOT MANDATORY (AUTO ADD WHEN THE SCRIPT RUNS)
- Add the sql code bellow:

```sql
CREATE TABLE IF NOT EXISTS motel_rooms (
            id              INT AUTO_INCREMENT PRIMARY KEY,
            citizenid       VARCHAR(50) UNIQUE NOT NULL,
            room_bucket     INT NOT NULL,
            entry_door_index INT DEFAULT 1,
            is_inside       BOOLEAN DEFAULT FALSE,
            purchased_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_citizenid (citizenid),
            INDEX idx_bucket    (room_bucket)
)
```
## Dependecies
- qb-core/qbx_core
- ox_inventory
- ox_lib

### ENJOY

## FAQ

#### ESX Available?

Not yet, maybe later contact me in my discord if you'ld like the ESX version

#### Can you make a ingame creator?

Nope

