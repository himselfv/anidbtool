Description
===================
Anidb Tool is a simple command-line tool to hash files and add them to anidb mylist.


Features
===================
- Minimal number of requests to anidb (basically, 1 UDP packet per file, login information is preserved between application runs)
- Strict compliance with AniDB UDP API short-term messaging timeout rules. No message is sent in less than two seconds after the previous one. Even if you restart the application.
- Hash and file caches (no requests and rehashings for files you've added already). 
- Kind of optimized for multithreading (there's only so much you can do with AniDB timeouts though). 


Issues
===================
Last-minute issues:
- None as of yet.


Syntax
===================
Usage: anidb <command> <params>

General-purpose params:
- <filename> stands for file or directory name or file mask (for example, K:\Anime\*.avi)
- /s activates subdirectory parsing. With /s enabled (K:\Anime\*.avi) will enumerate all files with avi extension in K:\Anime and its subdirectories.


Available commands:
> hash [hashing params] [/s] <filename> [filename] [filename]...
Hashes the file and prints its ed2k hash and file size in bytes.

Hashing flags:
- /ed2k prints edonkey link to the file (ed2k://|file|Filename.avi|size|ed2k-hash|/)

> myliststats
Prints your AniDB stats (anime count, size, etc).

> mylistadd [operation flags] [file state flags] [/s] <filename> [filename] [filename]...
Hashes the file and adds it to anidb. If the file was there and /autoedit is on, it's updated.

Operation flags control the operation to perform:
- /edit forces editing: mylistadd+/edit=mylistedit
- /-edit disables edit mode if it has been enabled through configuration file.
- /autoedit makes the app first try to add the file, then if it's known, to update it.
- /-autoedit disables /autoedit if it has been enabled through configuration file.
- /ignoreunchangedfiles skips Anidb requests for files which weren't changed. See "File Cache".
- /forceunchangedfiles or /-ignoreunchangedfiles forces updates to Anidb even if the file state wasn't chagned.

File state flags:
- /state <state> sets file state (unknown/hdd/cd/deleted)
- /watched marks file as watched
- /watchdate sets the date you watched this episode/series
- /source <source> sets file source (any string)
- /storage <storage> sets file storage (any string)
- /other <other> sets other remarks (any string)
If you're editing a file, only those flags you specify will be changed. The rest will remain as they were.

> mylistedit [same flags as mylistadd]
Instead of adding the file, edits it on the anidb. If the file wasn't there, it's not added (although AniDB might report a success).


General-purpose settings (apply to all commands where reasonable):
- /noerrors forces application to continue to the next file even if a serious problem was encountered (such as a lack of internet connectivity).
- /errors or /-noerrors disables /noerrors if it have been enabled through configuration file.
- /usecachedhashes enables the use of quick hashing as described in the "File Cache" section of this document.
- /forcerehash or /-usecachedhashes forces full rehashing of everything
- /updatecache saves new data (hashes, file state) to the cache.
- /-updatecache makes the cache read-only.
- /savefailed <filename> saves a list of files which weren't recognized by AniDB or otherwise failed to be added or edited, into a file. See "Multiple files".
 If the path is relative, it's assumed to be relative to the program's folder.
- /verbose enables printing additional information which isn't really needed but can be helpful when solving problems.
- /-verbose suppresses verbose log.




Configuration
===================
Configuration is stored in "anidb.cfg" (or, more specifically, in %appname%.cfg, so if you rename anidb.exe to MYCRAZYAPP.exe, it'll look for configuration in MYCRAZYAPP.cfg).

Available parameters:
Host: AniDB API server name or IPv4 address. Use default (api.anidb.info)
Port: AniDB API server port. Use default (9000)
User: Your AniDB account username
Pass: Your AniDB account password. Username/password information is sent to AniDB server in plaintext, if this is unacceptable for you - don't use the application until this behaviour changes.
Timeout: Time in milliseconds the application will wait for answer from AniDB server. If no answer comes in this interval, request will be considered failed.
RetryCount: Number of times the utility will try to re-query the anidb without getting an answer. Each time it'll wait for Timeout milliseconds before considering request failed.

EditMode: Enables using MYLIST EDIT instead of MYLIST ADD for all files by default. Can be disabled with /-edit[mode] from command-line.
AutoEditExisting: Enables sending MYLIST EDIT after each MYLIST ADD which returns FILE ALREADY IN MYLIST. Can be disabled with /-autoedit from command-line.

DontStopOnErrors: Specifies whether the application should stop when it encounters a critical error (such as a loss of connectivity or ban on anidb).
If you're adding a bunch of files at once you might want to try to continue, hoping that the problems are temporary. In this case the app will present a list of failed files at the end.

UseCachedHashes: controls the use of quick hashing. See "File Cache".

UpdateCache: enables/disables updates (partial hashes, file state) to the cache. Disabling updates makes the cache read-only.

IgnoreUnchangedFiles: suppresses Anidb requests for files which weren't changed. See "File Cache".

Verbose: print verbose information / only important messages.

IgnoreExtensions: allows you to set the extensions which you want anidb tool to ignore when adding files to anidb. These restrictions will apply to MYLIST ADD/MYLIST EDITS commands but not to HASH command though.
Extensions to ignore are separated by comma. Do not use whitespaces after commas, they'll be treated like they're parts of extensions. Wildcards are not allowed. Empty extension is written as ".".
Good examples:
  IgnoreExtensions=ass,mp3,sfv,nfo
  IgnoreExtensions=txt,my extension,cfg
  IgnoreExtensions=pdf
  IgnoreExtensions= //ignores nothing
  IgnoreExtensions=. //ignores empty extension
  IgnoreExtensions=txt,pdf,.,nfo
Bad examples:
  IgnoreExtensions=ass, mp3, sfv, nfo//ignores ". mp3" instead of ".mp3"
  IgnoreExtensions=txt,//works, but still wrong
 
UseOnlyExtensions: if set, limits the extensions allowed to only those specified in this list. The format is the same as for the IgnoreExtensions parameter. Empty string means allowing every extension except those ignored explicilty through IgnoreExtensions.


Session information
====================
TLDR: Delete "session.cfg" if there are problems.

Session information is stored in "session.cfg". This file is not required, you can delete it and it'll be recreated automatically. However, session information will be lost and the application will automatically re-login to AniDB.
In fact, it might be useful to try delete this file if you encounter problems with AniDB.


How to use
===================
TLDR: Edit "anidb.cfg" to set your password. Create links to "Add to Mylist" in SendTo folder.

First configure the application according to the "Configuration" section. Usually you'll only need to specify your username and password.
Verify that everything is working properly. Choose any file known to AniDB (some anime episode, for example) and run "anidb mylistadd <filename>" from the command line. If evernything is fine, the file will be hashed and added to your mylist. Check that the answer from server is "mylist entry added", "mylist entry edited" or "already in mylist".

You can also configure your system to use this tool from Explorer. There are batch files called "Add to Anidb (HDD).cmd" etc in the distribution packet. Create shortcuts to these in your profile's SendTo folder. Now you can right-click any file, directory or a bunch of files, choose "SendTo > Add to Anidb (HDD)" and they will be added to your mylist.
You can customize the batch files to change command-line params.


Multiple files
===================
You can make anidb parse multiple files at once. For example,
> anidb mylistadd "K:\Anime\*.*" /S
will parse every single file under \Anime folder and it's subfolders. 

In cases where there are multiple files to parse, Anidb parses them all and does not stop on non-critical errors (i.e. on errors related to anidb, such as "FILE NOT FOUND"). Instead, the utility records all the errors and displays a summary at the end.
> Some files failed:
>   Gundam Seed The Unknown Series 01.avi
>   Gundam Seed The Unknown Series 02.avi
> ...

Scroll the command window up to determine the causes of errors.

You can save the list of failed files to a file:
> anidb mylistadd /failedlist "c:\temp\failed.txt" ...
Failed.txt will contain the list of full paths:
> K:\Anime\Gundam Seed\Gundam Seed The Unknown Series 01.avi
> K:\Anime\Gundam Seed\Gundam Seed The Unknown Series 02.avi
> ...
This way you can later feed it to other tools, such as hash checker or avdump:
> for /F "delims=" %i IN (c:\temp\failed.txt) DO anidb hash /ed2k "%i" >>links.txt
(generates ed2k links for all failed files: use the links to register the files in anidb)
> for /F "delims=" %i IN (c:\temp\failed.txt) DO avdump -ac:username:password "%i"
(feeds all files to avdump to automatically add their data to anidb. You'll still need to register the files. Read more on avdump: http://wiki.anidb.net/w/Avdump)



Editing versus adding
========================
TLDR: Leave everything as is for the best behaviour.

By default mylistadd command issues a MYLIST ADD request, and then a MYLIST EDIT request if the file was already in MyList. This is usually what you want, since this way new files will be added and existing files updated.

What's more, if you're using cache and the file wasn't changed, no requests will be issued at all.

When not using cache, you might want to minimize the number of requests since each one takes 2 seconds.
- Disable EditMode AND AutoEditExisting to only issue MYLIST ADD requests. If the file is already in your MyList, it will not be updated with the params you set in the command line.
- Disable AutoEditExisting to only issue MYLIST EDIT requests. This way only files already in your MyList will be updated, and files not yet in your MyList will be skipped (although AniDB will report them as MYLIST ENTRY EDITED too)


File Cache
===================
TLDR: Known files are rehashed fast and ignored. If something fails, delete "file.db".

Anidb tool supports File Cache. This feature drastically reduces the number of requests to Anidb and the time spent in hashing if you rehash the files you've hased already. With File Cache enabled, Anidb tool will only hash the first chunk (~10Mb) of the file and will not issue any requests to Anidb for files you've already hashed before.

More specifically, the partial hashing scheme works by hashing only the first chunk of the file (this is called the Lead Hash) and then looking in the File Cache for files with the same Lead Hash. If such files are found, their complete hash is taken from the File Cache instead of recalculating it from the scratch.

This scheme has a potential drawback: if you leave the first chunk of the file unchanged but still change the subsequent chunks, the file will still hash to the same Lead Hash and thus resolve to the same File Cache record. In other words, anidb tool will NOT see the changes you have introduced to the file, and will continue to believe this is the same old file which hashes to the same old complete hash.

This situation is rare with video files though, since it's uncommon for anyone to edit a video file you hash for anidb, and even if you edit the file you usually change it's header too, thus changing the first chunk and making it clear to anidb tool that the file was changed. Still, keep this in mind. If you really, POSITIVELY need a true hash of the file, use the "/-usecachedhashes" option as described in the Syntax section.

File Cache can also reduce the number of requests to anidb. This is done in the following way. When you MYLIST ADD or MYLIST EDIT a file first, if UpdateCache is enabled as described in the Configuration section, anidb tool will save a record in the file cache, keeping track of anidb's State and Watched params. If, on the next occasion, you try to MYLIST ADD or MYLIST EDIT the same file again and you have IgnoreUnchangedFiles enabled, anidb tool will compare your new State and Watched params to the ones it saved, and if the tool sees no changes, it will not issue the same request again.

This is quite useful if you want to add some new files you haven't added before, but they're in the folder with a lot of files you HAVE already added before. You can just MYLIST ADD the whole folder and with IgnoreUnchangedFiles enabled anidb will MYLIST ADD only those files which weren't added before.

This, again, has some drawbacks. If, by the will of God or other not so godly forces, the anidb tool comes to believe that the file was successfully added while it wasn't, next time you try to add it with IgnoreUnchangedFiles enabled, anidb tool will just nod without actually doing anything, which is obviously not what you want. You can force anidb tool to add/edit even those files which weren't change since last time by setting "/forceunchangedfiles" key as described in Syntax section.

The File Cache is kept in "file.db" in the program folder; it's format is undocumented and is subject to change. The format might, in fact, change in the following versions, even to the degree that the following versions will not be able to import the file, so you should not think of "file.db" as of something to care about and backup properly. If the file is not found, it will be recreated, but you'll lose all your cache of course - just rehash everything if you care. You can try solving problems with File Cache by deleting it.


About renaming
===================
You can rename files as much as you want. Anidb tool identifies files by their hashes, that is by their contents. As long as the contents remains unchanged, no mattter which name you give to your file, Anidb tool will still know it's the same file as before.



Version Info
===================
18.06.2012 - Numerous bugfixes (files being wrongly hashed, not cached), empty edits are now not sent (no point, save time), hashed files are cached even on abort, hashing/adding/editing stats, disables auto-sleep while running.
28.12.2011 - Added /source, /storage, /other, /watchdate settings. Fields which weren't changed are now kept as they are on server. File Cache format changed, please purge the cache.
05.09.2011 - Optimized hasher for multithreading.
25.10.2009 - Added file cache, hash cache. Improved network stability.
24.10.2009 - Added AutoEditExisting.
27.12.2008 - Fixed another stupid error with int32 used for file size calculations. Now files of more than 2.xx GB in size should at last be hashed correctly.
30.11.2008 - Fixed a stupid error with int32 used for file size calculations. Now files of more than 2.xx GB in size should be hashed correctly.
11.10.2008 - Now tool allows specifying multiple file masks, in random order with switches. Fixed an issue with incorrect hashes for files less than ed2k chunk in size. Added a few options (/edit, /noerrors). All the selected files are parsed in a single run now.
09.14.2008 - Parsing of multiple files by mask, parsing of directories and subdirectories, options to define file storage and watched state. If the file is already in mylist, then it's updated. Retry count in addition to timeout in config.
07.09.2008 - Initial release.


Planned Features
===================
- Ability to look into File Cache from the command-line
- Ability to recognize command verb even if it's not the first parameter in the command line.
- Send the password encrypted (only possible when encrypting all data, not recommended by AniDB)
- MYLIST GET
- MYLIST ADD by Anime/Group/Episode scheme