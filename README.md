<div align="center">

# 🪙 CraftOrBuy

**Should you craft it, or just buy it?**
A World of Warcraft 3.3.5a addon that compares the cost of crafting every profession item with its Auction House price, and keeps a price history by day, month and year.

![WoW](https://img.shields.io/badge/WoW-3.3.5a%20(WotLK)-blue)
![Interface](https://img.shields.io/badge/Interface-30300-informational)
![Requires](https://img.shields.io/badge/requires-Auctionator-orange)
![Version](https://img.shields.io/badge/version-0.4.2-success)
![License](https://img.shields.io/badge/license-GPL--2.0-lightgrey)

Made for private servers such as **Warmane**.

</div>

---

## ✨ Features

- **Every profession recipe**: 3,500+ recipes across Alchemy, Blacksmithing, Cooking, Enchanting, Engineering, First Aid, Inscription, Jewelcrafting, Leatherworking, Mining and Tailoring, with reagents and how many items each craft makes.
- **Craft vs buy at a glance**: mats cost, AH price and how much crafting saves you, in green when crafting is cheaper and red when buying is.
- **Best deals**: one list of every recipe, ranked by how much you save by crafting.
- **AtlasLoot-style browser**: professions and categories on the left, items grouped by slot (Head, Chest, Legs, Feet…) or type (gems by colour, potions, flasks…), Epic first, then Rare, Uncommon and Common.
- **Recipe details**: each reagent with its price and where it comes from (AH, vendor or crafted), a **CRAFT IT / BUY IT** verdict, and your profit if you sell after the 5% AH cut.
- **Price history**: after every Auctionator full scan the day's prices are saved. See them as a chart by **days, months or years** (low, average and high).
- **Smart mat prices**: the cheaper of vendor and AH price. Mats that are not on the AH (Cured Rugged Hide, Jadefire Ink…) are priced by their own crafting cost.
- **Item tooltips**: craft cost and AH price on any craftable item.
- **Minimap button**, **settings window** (size, font, price mode and more) and an **error log** you can copy from.

## 📦 Requirements

- World of Warcraft **3.3.5a** (build 12340), e.g. Warmane
- [**Auctionator for WotLK**](https://github.com/ljamov/WotLK-Auctionator) (2.6.x for 3.3.5, with fixes). CraftOrBuy reads its scan data.

## 🔧 Installation

1. Download this repository (**Code → Download ZIP**).
2. Extract it and rename the folder to exactly **`CraftOrBuy`** (remove `-main` from the name).
3. Move it to `World of Warcraft\Interface\AddOns\`, so you have `Interface\AddOns\CraftOrBuy\CraftOrBuy.toc`.
4. Start WoW (a full restart, not `/reload`) and make sure **CraftOrBuy** and **Auctionator** are enabled on the character select screen.

## 🚀 Getting started

1. At the Auction House, run an **Auctionator full scan**. CraftOrBuy saves that day's prices to its history.
2. Click the **coin icon** on the minimap, or type `/cob`.
3. Pick a profession and a category on the left, or open **Best deals**.
4. Click an item to see its reagents, the verdict and its price history.

For the most accurate numbers:

- Open each of your **profession windows** once. CraftOrBuy then uses their exact reagents and marks recipes you know with a green `*`.
- Visit a **trade goods vendor** once so vials, thread, flux etc. use your server's real vendor prices.

## 💰 How prices work

| Price | Meaning |
|---|---|
| **AH lowest** | The cheapest buyout per item at your last Auctionator full scan. |
| **AH median** | The middle of the lowest prices from Auctionator's recent full scans (up to 15). Less affected by a single cheap or overpriced listing. |
| **Mats** | The sum of all reagents, each at the cheaper of its vendor or AH price, divided by the number of items one craft makes. |
| **Craft saves** | AH price − mats cost. Positive (green) means crafting is cheaper. |
| **Profit if sold** | AH price minus the 5% AH cut, minus mats cost. |

Switch between **lowest** and **median** with the button at the top of the window or in Settings.

## ⌨️ Commands

| Command | What it does |
|---|---|
| `/cob` | Open or close the window |
| `/cob settings` | Open the settings |
| `/cob log` | Open the error log |
| `/cob status` | Show addon and Auctionator data status |
| `/cob price <item>` | Print the lowest and median AH price of an item |
| `/cob scale <0.5–2>` | Make the window bigger or smaller |
| `/cob minimap` | Show or hide the minimap button |

## ⚙️ Settings

Open with the **Settings** button, a right-click on the minimap icon, or `/cob settings`:

- Window size and font size
- Compare with the median instead of the lowest AH price
- Price mats that are not on the AH by their crafting cost
- Show prices in item tooltips
- Show the minimap button

## 🐞 Reporting problems

Click **Log** in the window. It collects Lua errors (a repeating error is counted, not duplicated). Use **Select all**, then **Ctrl+C**, and paste it into a GitHub issue. **Clear log** empties it, for example after an update.

> **Tip:** after updating the addon, restart WoW completely. `/reload` does not load newly added files.

## 🗂️ Project structure

```
CraftOrBuy/
├── CraftOrBuy.toc     addon manifest
├── Log.lua            error log and log window
├── Data.lua           generated recipe, reagent, item and vendor data
├── Core.lua           prices, buy vs craft calculation, slash commands
├── Reagents.lua       reagents, profession window and vendor scanning
├── History.lua        daily price snapshots rolled up into months and years
├── UI.lua             main window and item tooltips
├── Settings.lua       settings window and minimap button
└── tools/             scripts that generate Data.lua
```

### Rebuilding `Data.lua`

The recipe data is generated, not hand-written. The scripts in `tools/` combine:

- the recipe lists and categories of **AtlasLoot_Crafting** (WotLK),
- reagents and items made per craft from the 3.3.5a client **Spell.dbc**,
- item names, qualities, slots and vendor prices from the **AzerothCore** world database (`item_template`, `npc_vendor`).

```bash
cd tools
mkdir -p build
# put item_template.sql, npc_vendor.sql and dbc/Spell.dbc into tools/build/
python fetch_spell_dbc.py <url of a 3.3.5 client data zip> Spell.dbc   # optional helper
python extract_game_data.py
python build_recipes.py path/to/AtlasLoot_Crafting/crafting.lua ../Data.lua
```

## 🙏 Credits

- Recipe lists and categories from [AtlasLoot Enhanced](https://www.curseforge.com/wow/addons/atlasloot-enhanced) (GPL-2.0)
- Item and vendor data from [AzerothCore](https://www.azerothcore.org)
- Price data from [Auctionator](https://github.com/ljamov/WotLK-Auctionator) by Zirco

## 👤 Creator

**Kristijan Ljamov** · [ljamov.com](https://ljamov.com)

## 📄 License

CraftOrBuy is released under the [GNU General Public License v2.0](LICENSE) or later.
