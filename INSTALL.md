# Installing Tideline on your watch

**Easiest way:** open the **Connect IQ** app on your phone, search for **Tideline** and tap Install
([Store page](https://apps.garmin.com/apps/6e213c6c-8bf1-495e-abd1-91b7030b9f1e)). Updates then arrive automatically. Skip the rest of this page.

**USB install** (no phone app needed): takes about 5 minutes. You need the watch, its charging cable and a computer.

## Windows

1. **Download the app.** Go to the [latest release](https://github.com/edleeman17/tideline/releases/latest)
   and click **`Tideline.prg`** under *Assets*. It saves to your *Downloads* folder.
2. **Plug the watch in** to the computer with the Garmin charging cable.
   Wait about 10 seconds for it to connect.
3. **Open File Explorer** (the yellow folder icon on the taskbar, or press `Windows key + E`).
4. In the left-hand list, click **This PC**, then double-click **fēnix 8**.
   - If it isn't there, unplug the cable and plug it back in, or try a different USB port.
5. Double-click **Internal Storage**, then **GARMIN**, then **Apps**.
6. **Drag `Tideline.prg`** from your *Downloads* folder into the **Apps** folder.
   - Or right-click the file and choose *Copy*, then right-click inside *Apps* and choose *Paste*.
7. **Unplug the watch.** It takes a few seconds to set the app up.

## Mac

1. Download **`Tideline.prg`** from the [latest release](https://github.com/edleeman17/tideline/releases/latest).
2. Install [OpenMTP](https://openmtp.ganeshrvel.com) (free). Macs can't open Garmin watches without it.
3. Plug the watch in and open OpenMTP. On the right-hand side, open **GARMIN → Apps**.
4. Drag `Tideline.prg` from the left side (your Mac) into **Apps** on the right.
5. Unplug the watch.

## Opening it on the watch

- From the watch face, press **START** (top right). Scroll down to **Tideline** and press START.
- First time: it looks for GPS. Go outside, or press **START** and choose *Nearby spots*.
- **Make it a glance** (the wind and tide summary when you scroll from the watch face):
  hold **UP** → *Settings* → *Appearance* → *Glances* → *Add New* → **Tideline**.

## Using it

| Button | What it does |
|---|---|
| **UP / DOWN** | Switch screens: Now, Tide, Next 12h, Weather |
| **START** | Spots menu: GPS, nearby spots, favourites, pick on map, refresh |
| **BACK** | Close the app |

**Pick on map:** UP/DOWN moves the white target. **Hold UP** to switch between
north-south, east-west and zoom. **START** picks the spot.

**Canals:** away from the sea, Tideline shows wind and weather only. Next to a
tidal harbour, choose *Tide: OFF here* in the START menu.

## It says "WEATHER -300" or won't load

The watch gets data through the **Garmin Connect** app on your phone:

- Check your phone has signal and Bluetooth is on.
- Open Garmin Connect on the phone and check the watch shows as connected.
- Press **START → Refresh** on the watch.

The last data stays on screen, with how old it is shown at the bottom.

## Updating

Store installs update themselves. For a USB copy, download the new `Tideline.prg` and repeat the steps. Replace the old file when asked.

## Removing

Plug in, open **GARMIN → Apps**, delete `Tideline.prg`.
