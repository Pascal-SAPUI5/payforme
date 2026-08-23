# PayForMe
iOS client for Cospend on Nextcloud & iHateMoney.org

Download from the [Apple App Store](https://apps.apple.com/us/app/payforme/id1500428306?l=de&ls=1).

Open beta with new features via [TestFlight](https://testflight.apple.com/join/nCDuHtjh).

Using SwiftUI and Combine.
Inspired by [Moneybuster](https://gitlab.com/eneiluj/moneybuster).

## Open Source
PayForMe is an open source project, which means the code is freely available and anyone can contribute to its development. The project is developed in my free time and contributions are always welcome!

Ways to contribute:
* Report bugs or suggest features via [GitHub Issues](https://github.com/InteractionEngineer/PayForMe/issues)
* Help with localization (see below)
* Submit code improvements through Pull Requests
* Share the app with others who might find it useful

## Screenshots

<img src="/screenshots/lightmode/en-US/iPhone%2016-Bill%20List_framed.png?raw=true" width="200"/> <img src="/screenshots/lightmode/en-US/iPhone%2016-Balance%20List_framed.png?raw=true" width="200"/> <img src="/screenshots/lightmode/en-US/iPhone%2016-Known%20Projects_framed.png?raw=true" width="200"/> <img src="/screenshots/lightmode/en-US/iPhone%2016-Add%20Bill_framed.png?raw=true" width="200"/>
<img src="/screenshots/darkmode/en-US/iPhone%2016-Bill%20List_framed.png?raw=true" width="200"/> <img src="/screenshots/darkmode/en-US/iPhone%2016-Balance%20List_framed.png?raw=true" width="200"/> <img src="/screenshots/darkmode/en-US/iPhone%2016-Known%20Projects_framed.png?raw=true" width="200"/> <img src="/screenshots/darkmode/en-US/iPhone%2016-Add%20Bill_framed.png?raw=true" width="200"/>

## Features
* Show listed bills
* Create new bills
* Balance of project members
* Handling several projects
* Colorcodes to differentiate users
* Update bills
* Delete bills
* Clearing debt of single members
* ~Creating new projects on iHateMoney~
* Adding new members to a project
* Statistics: totals, per-member paid/spent/balance, monthly trend, category
  breakdown and a settlement plan
* Three themes, each with a light and a dark variant, switchable under
  Projects > Appearance

## Statistics

The Statistics tab answers the questions a shared project actually raises:
where the money went, who is carrying the group, and what the shortest way back
to zero is.

* **Totals** for the selected period — spend, number of expenses, average
  expense, average per participating member
* **Balances** as diverging bars around a zero line, using the same split rule
  as the Members tab so the two can never disagree
* **Settle up** — a greedy plan that clears every debt in at most one transfer
  fewer than there are members
* **Monthly spending**, including months with no spending, so a gap reads as
  "nobody spent anything" rather than as missing data
* **Categories** and the currency label, read from the Cospend project itself.
  iHateMoney has no categories, so the section hides itself there.

Date ranges are this month, the last three or six months, this year, or all
time. Charts are built from SwiftUI primitives rather than Swift Charts, which
would raise the deployment target from iOS 15 to iOS 16.

## Appearance

Colour, elevation and shape come from a token set rather than being hardcoded
per screen, so the whole app restyles at once. Three directions ship:

* **Aurora** — deep indigo, vivid gradients, soft glass. The default.
* **Graphite** — editorial monochrome with hairlines instead of shadows; only
  money carries colour.
* **Mint** — warm paper, mint and coral, generous rounding.

Each has a hand-stepped light and dark palette, and light/dark can be forced
independently of the system setting. The categorical chart palette is shared by
all three and was validated for colour-blind separation and contrast against
every theme surface in both modes — its ordering is what makes neighbouring
series distinguishable, so reordering it is not a cosmetic change.


## How to contribute Localization

If you want to localize PayForMe into your language you are very welcome! If unfamiliar, here is a short guide:

To add a new localization, fork the project on github, download it, open it in XCode and then navigate to the Project/Info settings, and add a new localization file there. It is recommended but not necessary to use [iOSLocalizationEditor](https://github.com/igorkulman/iOSLocalizationEditor) then to easily translate all strings. Afterwards, commit and push you changes and open a pull request to the main repository.
