# Bonus XP Add-On [![Build Status](https://travis-ci.com/peterwooley/bonusxp.svg?branch=master)](https://travis-ci.com/peterwooley/bonusxp)

How much Bonus XP are you earning? Are you using Recruit-a-Friend? Is there a Bonus XP event taking place?

Now you'll know!

Open the Character screen (C) and find your Bonus XP percentage at the bottom of the Character Stats pane. Hover over to see the buffs contributing to your bonus.

<img src="screenshots/raf.png" alt="Bonus XP Add-On with Recruit-a-Friend active">
<img src="screenshots/inactive.png" alt="Bonus XP Add-On with inactive section headers">

## API
This add-on exposes a global function to get the current Bonus XP.

```lua
GetBonusXP(); -- Returns a string of the bonus XP, such as: "170%"
```

## Thanks
Thanks to the folks who help test:

* [Kezri](https://worldofwarcraft.com/en-us/character/us/silver-hand/Kezri)
* [Lithiana](https://worldofwarcraft.com/en-us/character/us/silver-hand/lithiana/)
* [Keyaenlord](https://worldofwarcraft.com/en-us/character/us/silver-hand/Keyaenlord)

## Credits
This add-on is based on [evilWizard's XP Bonus Counter](https://www.curseforge.com/wow/addons/xp-bonus-counter). The calcuations used to determine bonus XP are quite tricky, so a huge thanks to evilWizard for their work.
