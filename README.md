# devchacha-farming (VORP Core Edition)

A premium, highly interactive, and persistent farming system for RedM VORPCore. Players can purchase seeds and tools from NPC merchants, plant crops in soil using a ghost placement visualizer, water and fertilize them, monitor progress using a status UI, and harvest them for rewards.

---

## Features
- 🪵 **Ghost Placement System**: Fine-tuned placement of crops with real-time controls (`W`/`A`/`S`/`D` to move, `Q`/`E` to rotate, `ENTER` to plant, `BACKSPACE` to cancel).
- 💧 **Watering & Hydration**: Plants decay in water over time. Players must water them (~3 times per cycle) using buckets. Includes a water interaction menu to fill buckets, wash, or drink from natural water sources (lakes, rivers) and pumps.
- 💩 **Fertilization**: Applying fertilizer boosts growth rate by **35%**.
- 🪴 **60 Supported Crops**: Features a massive variety of wild plants, herbs, vegetables, grains, and fruit trees.
- 📦 **Resource Box & Item Images**: Support for inventory images. Harvested crops display as resource box items (for relevant crops) or standard raw herbs.
- 🖥️ **Status UI**: Open the NUI menu on any plant to inspect its Water Level, Growth percentage, Health status, and dynamic crop image/artwork in the header.
- 💾 **Persistence**: Database integration ensures plants, locations, and growth levels persist through server restarts.
- 🛑 **Town Safezones**: Banned zones prevent farming inside populated city areas (Valentine, Saint Denis, Rhodes, Blackwater, etc.).

---

## Installation

### 1. Database Setup
Execute the queries in [farming.sql](file:///c:/Redm%20vorp/server-data/resources/devchacha-farming/farming.sql) on your server database. This will create the `devchacha_farming` table and register all seeds, crops, and tools in your VORP `items` table.

### 2. Add to Server Config
Add the following line to your `server.cfg`:
```cfg
ensure devchacha-farming
```
*Note: Ensure this resource starts after `vorp_core`, `vorp_inventory`, and `vorp_progressbar`.*

---

## Supported Crops & Seeds

Below is the complete list of crops registered in the system:

| Crop / Plant Name | Seed Item | Harvested Reward |
| :--- | :--- | :--- |
| **Alaskan Ginseng** | `alaskan_ginseng_seed` | `alaskan_ginseng` |
| **American Ginseng** | `american_ginseng_seed` | `american_ginseng` |
| **Pumpkin** | `pumpkin_seed` | `pumpkin` |
| **Hop** | `hop_seed` | `hop` |
| **Pepper** | `pepper_seed` | `pimenta` |
| **Black Currant** | `black_currant_seed` | `black_currant` |
| **Blood Flower** | `blood_flower_seed` | `Blood_Flower` |
| **Choc Daisy** | `choc_daisy_seed` | `Choc_Daisy` |
| **Coffee** | `coffee_seed` | `coffeebeans` |
| **Creekplum** | `creekplum_seed` | `creekplum` |
| **Creeking Thyme** | `Creeking_Thyme_Seed` | `Creeking_Thyme` |
| **Crows Garlic** | `crows_garlic_seed` | `crows_garlic` |
| **English Mace** | `English_Mace_Seed` | `English_Mace` |
| **Tobacco** | `tobacco_seed` | `tobacco` |
| **Milk Weed** | `milk_weed_seed` | `milk_weed` |
| **Oleander Sage** | `oleander_sage_seed` | `oleander_sage` |
| **Oregano** | `Oregano_Seed` | `Oregano` |
| **Parasol Mushroom** | `parasol_mushroom_seed` | `parasol_mushroom` |
| **Prairie Poppy** | `prairie_poppy_seed` | `prairie_poppy` |
| **Red Raspberry** | `red_raspberry_seed` | `red_raspberry` |
| **Red Sage** | `red_sage_seed` | `red_sage` |
| **Tea** | `teaseeds` | `tealeaf` |
| **Carrot** | `carrot_seed` | `carrot` |
| **Wild Mint** | `wild_mint_seed` | `wild_mint` |
| **Wintergreen Berry** | `wintergreen_berry_seed` | `wintergreen_berry` |
| **Yarrow** | `yarrow_seed` | `yarrow` |
| **Corn** | `corn_seed` | `Corn` |
| **Apple** | `apple_seed` | `Apple` |
| **Potato** | `potato_seed` | `Potato` |
| **Wheat** | `wheat_seed` | `wheat` |
| **Peach** | `peachseeds` | `consumable_peach` |
| **Cherry** | `cherry_seed` | `cherry` |
| **Lemon** | `lemon_seed` | `lemon` |
| **Barley** | `barley_seed` | `barley` |
| **Banana** | `banana_seed` | `banana` |
| **Tomato** | `tomato_seed` | `tomato` |
| **Lettuce** | `lettuce_seed` | `lettuce` |
| **Broccoli** | `broccoli_seed` | `broccoli` |
| **Sugar / Sugarcane** | `sugarcaneseed` | `cana` |
| **Agarita** | `agarita_seed` | `agarita` |
| **Bay Bolete** | `bay_bolete_seed` | `bay_bolete` |
| **Blackberry** | `blackberry_seed` | `blackberry` |
| **Evergreen Huckleberry**| `evergreen_huckleberry_seed`| `evergreen_huckleberry` |
| **Strawberry** | `strawberry_seed` | `strawberry` |
| **Onion** | `onion_seed` | `onion` |
| **Artichoke** | `artichoke_seed` | `artichoke` |
| **Beans** | `beans_seed` | `beans` |
| **Beetroot** | `beetroot_seed` | `beetroot` |
| **Cabbage** | `cabbage_seed` | `cabbage` |
| **Celery** | `celery_seed` | `celery` |
| **Cucumber** | `cucumber_seed` | `cucumber` |
| **Grapes** | `grapes_seed` | `grapes` |
| **Lime** | `lime_seed` | `lime` |
| **Mango** | `mango_seed` | `mango` |
| **Orange** | `orange_seed` | `orange` |
| **Pear** | `pear_seed` | `pear` |
| **Watermelon** | `watermelon_seed` | `watermelon` |
| **Peanuts** | `peanut_seed` | `raw_peanuts` |
| **Rice** | `rice_seed` | `rice` |
| **Squash** | `squash_seed` | `squash` |

---

## Configuration Settings
Modify [config.lua](file:///c:/Redm%20vorp/server-data/resources/devchacha-farming/config.lua) to customize:
- `Config.Debug`: Enable developer debug prints.
- `Config.PlantSpace`: The minimum distance between plants (default: `1.5` meters).
- `Config.ShopNPCs`: Coords, heading, models, and map blips for merchant vendors.
- `Config.BannedZones`: Boundaries where players are forbidden to plant.
- `Config.Seeds`: Custom times to growth, water intervals, props/visual stages, and rewards.

---

## License & Credits
- Created by **devchacha**.
- Licensed under the MIT License.
