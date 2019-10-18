#### Automatically responds to item price check messages using pricing information from auction database addons.
You must have at least one supported auction database addon installed for this addon to work:
- TradeSkillMaster (`TSM`)
- Auctioneer aka Auc-Advanced (`AUC`)
- BootyBayGazette / TheUndermineJournal (`BBG`)


##### Usage
This addon listens to whispers, guild chat, officer chat, party chat, and raid chat for messages containing `!price` and one or more item links.

The response will include certain pricing information depending on the sources you have enabled:
- TradeSkillMaster: Realm and region market value and minimum buyout.  Region information is only available via the TSM helper application.
- Auctioneer: Realm market value and minimum buyout.
- BootyBayGazette / TheUndermineJournal: Realm and global market value and standard deviation.


##### Customization
On first use, AHQuery chooses a 'private' and a 'public' price source to query.  Private sources are ones that provide accurate pricing data from locally obtained scans in-game.  Public sources are community aggregated data that updates less frequently, such as BootyBayGazette.

AHQuery will select the first available source for each category:
- Private: TSM, AUC
- Public: BBG/TUJ

You can enable or disable a price source by using `/ahquery toggle <some source>`, or revert to the automatically selected sources with `/ahquery reset`.
To list available sources, use `/ahquery sources`.


##### Links
- CurseForge: https://www.curseforge.com/wow/addons/ahquery
- GitHub: https://github.com/icheatatlan/AHQuery
