# NBSVisuals
View Note Block Studio(NBS) file with nice keyboard and dropping notes!
### Requirements
Minecraft with OpenComputers mod installed (Emulator also works fine, too.)
OpenOS installed on HDD(Hard Disk Drive, in OpenComputers).
### Installation
* Of course, you need to download NBSVisuals first. Click "Clone or download" and click "Download ZIP", or clone using git utility if you want.

If you are using emulator, just put this file inside home folder in virtual HDD of emulator.
But if you are trying on actual mod, you may need to edit config file of mod.
By default, OpenComputers keeps filesystem contents on RAM, and actual writing happens later. This makes putting files from outside harder. So, to install NBSVisuals, you need to disable this feature.
If you disabled "bufferChanges" in filesystem, you don't need to do this. If you didn't, here's how you can disable it:
1. Go to the Minecraft folder(Windows: %appdata%\\.minecraft, Linux: ~/.minecraft, or the folder you set in the launcher).
2. Go to config folder in Minecraft folder.
3. Go to opencomputers folder in config folder.
4. Open settings.conf with your favorite text editor.
5. Find the line "filesystem {". Then find "bufferChanges" option.
6. If bufferChanges is true(bufferChanges=true), change to false. I suggest you read the comments above t he option.
7. Save the file.
8. If you were running Minecraft, you need to restart to apply changes.
NOTE: If I uploaded this on Pastebin, installation would be much easier, but I just wanted to use GitHub instead. Also, you still need to manually put Note Block Studio files even if I used Pastebin.

Now it's ready to install NBSVisuals.
First of all, you have to find the UUID of hard disk. But it's simple. In your Minecraft world, open inventory or computer case which contains your HDD, and move mouse pointer to the HDD.
And find something looks like this.
3c30ba2a-610a...
This is part of UUID. Note these numbers and alphabets.
And now, you have to find where HDD contents are stored.
1. Go to Minecraft folder
2. Go to saves folder in Minecraft folder
3. Find your save folder and go to the folder.
- If you can't, in Minecraft world selection screen, select your world and click edit. You can open the folder in there.
4. Open opencomputers folder in your save folder.
5. Now you have to find your HDD. Find the folder which name starts with what you noted.
6. If you found your HDD, go to home folder.
7. Put NBSVisuals.lua inside home folder. Put Note Block Studio files you want to open as well.

### How to launch
Boot your OpenComputers computer, and type
```
nbsvisuals [NBS File name]
```
Then, press enter. After short loading, note starts to fall down! There are no sounds at all, but you can record this using some software and use it for your video.
[Here's how I used this thing in my video!](https://youtu.be/AkU-aAIgmUQ)

### Just keep in mind...
There's no warranty that speed of this thing is 100% accurate.
