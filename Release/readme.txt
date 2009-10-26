Description
===================
Anidb Tool is a simple command-line tool to hash files and add them to anidb mylist.


Features
===================
- Minimal number of requests to anidb (basically, 1 UDP packet per file, login information is preserved between application runs)
- Strict compliance with AniDB UDP API short-term messaging timeout rules. No message is sent in less than two seconds after the previous one. Even if you restart the application.


Issues
===================
Last-minute issues:
- DO NOT run several instances of anidb tool at once. NEVER. EVER. DO THIS. Just don't, okay?
- Anidb tool does not handle unicode characters in file names well. Lovers of As with accents, Us with tildes and everything else that does not fit into the default system code page, beware.


Syntax
===================
Usage: anidb <command> [configuration flags] <params>

Available commands:
> hash <filename> [/s] [filename] [filename]...
Hashes file and prints it's ed2k hash and file size in bytes.

> mylistadd <filename> [operation flags] [/s] [filename] [filename]...
Hashes file and adds it to anidb.

Here:
- <filename> stands for file or directory name or file mask (for example, K:\Anime\*.avi)
- /s activates subdirectory parsing. With /s enabled (K:\Anime\*.avi) will enumerate all files with avi extension in K:\Anime and it's subdirectories.

Operation flags control the operation to perform on the files:
- /state <state> marks every parsed file with this storage state. Available states: unknown, hdd, cd, deleted.
- /watched marks every parsed file as watched.
- /edit[mode] activates edit mode. In edit mode files will me MYLIST EDIT-ed by default instead of being MYLIST ADD-ed. Read more in the configuration section.
- /-edit[mode] disables edit mode if it have been enabled through configuration file.

Configuration flags are used to redefine/change settings:
- /noerrors forces application to continue with the next file even if a serious problem (such as a lack of internet connectivity) was encountered with this one.
- /errors or /-noerrors disables /noerrors if it have been enabled through configuration file.
- /autoedit[existing] instructs anidb tool to automatically retry the operation in edit mode if MYLIST ADD request returned 310 FILE ALREADY IN MYLIST. Works only when edit mode is disabled.
- /-autoedit[existing] disables /autoeditexisting if it have been enabled through configuration file.
- /usecachedhashes enables the use of partial hashing scheme as described in the File Cache section of this documentation
- /-usecachedhashes disables the use of partial hashing scheme
- /updatecache enables updates to the File Cache.
- /-updatecache disables all updates to the File Cache.
- /ignoreunchangedfiles enables skipping Anidb requests for files which weren't changed. See "File Cache".
- /-ignoreunchangedfiles or /forceunchangedfiles forces requests to Anidb even if the file state wasn't chagned since last time.
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

EditMode: Enables issuing MYLIST EDIT instead of MYLIST ADD for all files by default. Can be disabled with /-editmode from command-line.
AutoEditExisting: Enables sending MYLIST EDIT after each MYLIST ADD which returns FILE ALREADY IN MYLIST. Can be disabled with /-autoedit from command-line.

DontStopOnErrors: Specifies whether the application should stop when it encounters serious and probably non-recoverable error (such as a loss of internet connectivity or ban on anidb). Sometimes it's useful to force application to continue, for example, if you're adding a whole bunch (say, 1000) of files and do not want to retry the whole process AND you're sure any possible loss of connectivity should not last long. In this case anidb tool will add most of the files on the fly and present a list of files which weren't added for you to add them manually.
That's still better than when your connection drops dead in the middle of hashing 1000+ files and anidb tool encounters a critical error, dropping the whole task. With DontStopOneErrors disabled you'll either have to re-hash all the 1000+ files or to select the remaining say 500+ files for hashing manually.
Can be disabled with /-noerrors from command-line.

UseCachedHashes: controls the use of partial hashing scheme as described in the File Cache section of this documentation

UpdateCache: enables/disables updates to the File Cache. Enabling updates does not imply forcing them: if the update is unnecessary, File Cache will not be written to, thus minimizing the chance of screwing something up and destroying the cache. Not like it's a big loss, of course. Disabling updates effectively means making the File Cache read-only. This includes partial hash updates and file state updates.

IgnoreUnchangedFiles: controls suppressing Anidb requests for files which weren't changed. See "File Cache".

Verbose: controls printing additional information which isn't really needed but can be helpful when solving problems. If disabled, the tool will not print verbose data, although will keep printing important messages.

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
  IgnoreExtensions=ass, mp3, sfv, nfo //ignores ". mp3" instead of ".mp3"
  IgnoreExtensions=txt, //works, but still wrong
 
UseOnlyExtensions: if set, limits the extensions allowed to only those specified in this list. The format is the same as for the IgnoreExtensions parameter. Empty string means allowing every extension except those ignored explicilty through IgnoreExtensions.


Session information
====================
Session information is stored in "session.cfg". This file is not required, you can delete it and it'll be recreated automatically on the next application run. However, session information will be lost and the application will automatically re-logon to AniDB.
In fact, it might be useful to try delete this file if you encounter problems with AniDB.


How to use
===================
First, configure the application according to the "Configuration" section. Basically, you'll only need to specify your username and password.
Now verify that everything is working properly. Choose any file known to AniDB (some anime episode, for example) and run "anidb mylistadd <filename>" from the command line. If evernything is fine, the file will be hashed and added to your mylist. Check that the answer from server is "mylist entry added", "mylist entry edited" or at least "already in mylist".
Like this, you can use the tool from the command-line.

You can also configure your system to use this tool from Explorer. There's a batch file called "Add to Anidb.cmd" in the distribution packet. Create a shortcut to this file in your profile's SendTo folder. Now you can right-click any file, directory or a bunch of files, choose "SendTo> Add to Anidb", and these files or all files from the selected directory and it's subdirectories will be added to your mylist.
You can customize the batch file to change command-line params.


Multiple files
===================
Using andib's mask functionality you can make anidb parse multiple files at once. For example,
> anidb mylistadd "K:\Anime\*.*" /S
will make the utility parse every single file under \Anime folder and it's subfolders. 

In cases where there are multiple files to parse, Anidb parses them all and does not stop on non-critical errors (i.e. on errors related to anidb, such as "FILE NOT FOUND"). Instead, the utility records all the errors and displays a summary at the end.
> Some files failed:
>   K:\Anime\Gundam Seed\Gundam Seed The Unknown Series 01.avi
>   K:\Anime\Gundam Seed\Gundam Seed The Unknown Series 02.avi
> ...

You can scroll command window up to determine the causes of errors.


Editing versus adding
========================
By default, with EditMode and AutoEditExisting disabled, anidb tool will issue a MYLIST ADD command for every file it parses. This command adds a file to MYLIST only if it wasn't there before. If the file have already been registered before, then the request will fail with error 310 FILE ALREADY IN MYLIST and file data will not be changed.
Anidb tool considers this to be a successful result because in most cases this is what one wants. If you just want to register all your files in anidb, then certainly knowing that the file is already registered should be enough for you.

If, on the other hand, you want to change the file data, for example, to mark the file as watched, you'll need to issue a MYLIST EDIT request. For that, specify /edit in the command-line or set EditMode in the configuration file to True. According to documentation, MYLIST EDIT changes the data if the file is already in MYLIST or adds the file if it wasn't there yet.

Naturally, you might want to always MYLIST EDIT files instead of MYLIST ADDing them, because that way you transparently update those files you have already added before. But there's a trick. Documentation lies: in fact MYLIST EDIT does not add new files, although it certainly reports them as "MYLIST ENTRY EDITED". In other words, with /edit enabled you will only edit those files you have already added and will not add those you haven't added yet. What's worse, you won't even know which files were successfully edited, and which were ignored because they weren't in MYLIST: they will all just return "MYLIST ENTRY EDITED".

The solution is to use /autoedit or set AutoEditExisting in the configuration file to True. In this case anidb tool will first issue a MYLIST ADD request for every file, and if it returns "FILE ALREADY IN MYLIST", another request to MYLIST EDIT the file will be issued. This, of course, comes with a cost of having an additional two second wait delay for every file you re-send to anidb.


File Cache
===================
Anidb tool supports File Cache. This feature drastically reduces the number of requests to Anidb and the time spent in hashing if you rehash the files you've hashed already. Basically, with File Cache enabled, for files you've already hashed and whose state weren't changed since that time, Anidb tool will only hash the first chunk (~10Mb) of the file and will not issue any requests to Anidb.

More specifically, the partial hashing scheme works by hashing only the first chunk of the file (this is called the Lead Hash) and then looking in the File Cache for files with the same Lead Hash. If such files are found, their complete hash is taken from the File Cache instead of recalculating it from the scratch.

This scheme has a potential drawback: if you leave the first chunk of the file unchanged but still change the subsequent chunks, the file will still hash to the same Lead Hash and thus resolve to the same File Cache record. In other words, anidb tool will NOT see the changes you introduced to the file, and will continue to believe this is the same old file which hashes to the same old complete hash.

This situation is rare with video files though, since it's rare for an end user to edit a video file you hash for anidb anyway, and even if you edit the file, you usually change it's header too, thus changing the first chunk and making it clear to anidb the file was changed. But still, keep this in mind. If you REALLY, POSITIVELY need a true hash of the file, use the "/-usecachedhashes" option as described in the Syntax section.

File Cache can also reduce the number of requests to anidb. This is done in the following way. When you MYLIST ADD or MYLIST EDIT a file first, if UpdateCache is enabled as described in the Configuration section, anidb tool will save a record in the file cache, keeping track of anidb's State and Watched params. If, on the next occasion, you try to MYLIST ADD or MYLIST EDIT the same file again and you have IgnoreUnchangedFiles enabled, anidb tool will compare your new State and Watched params to the ones it saved, and if the tool sees no changes, it will not issue the same request again.

This is quite useful if you want to add some new files you haven't added before, but they're in the folder with a lot of files you HAVE already added before. You can just MYLIST ADD the whole folder and with IgnoreUnchangedFiles enabled anidb will MYLIST ADD only those files which weren't added before.

This, again, has some drawbacks. If, by the will of God or other not so godly forces, the anidb tool comes to believe that the file was successfully added while it wasn't, next time you try to add it with IgnoreUnchangedFiles enabled, anidb tool will just nod without actually doing anything, which is obviously not what you want. You can force anidb tool to add/edit even those files which weren't change since last time by setting "/forceunchangedfiles" key as described in Syntax section.

The File Cache is kept in "file.db" in the program folder; it's format is undocumented and is subject to change. The format might, in fact, change in the following versions, even to the degree that the following versions will not be able to import the file, so you should not think of "file.db" as of something to care about and backup properly. If the file is not found, it will be recreated, but you'll lose all your cache of course - just rehash everything if you care. You can try solving problems with File Cache by deleting it.


About renaming
===================
You can rename files as much as you want. Anidb tool identifies files by their hashes, that is, basically, by their contents. As long as the contents remains unchanged, no mattter which name you give to your file, Anidb tool will still know this is the same file as before.



Version Info
===================
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
- Mylistedit instead of editmode
- Ability to recognize command verb even if it's not the first parameter in the command line.