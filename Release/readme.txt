Description
===================
Anidb Tool is a simple command-line tool to hash files and add them to anidb mylist.


Features
===================
- Minimal number of requests to anidb (basically, 1 UDP packet per file, login information is preserved between application runs)
- Strict compliance with AniDB UDP API short-term messaging timeout rules. No message is sent in less than two seconds after the previous one. Even if you restart the application.


Syntax
===================
Usage: anidb <command> <params>

Available commands:
> - hash <filename> [/s] [filename] [filename]...
Hashes file and prints it's ed2k hash and file size in bytes.

> - mylistadd <filename> [configuration flags] [operation flags] [/s] [filename] [filename]...
Hashes file and adds it to anidb.

Here:
- <filename> stands for file or directory name, or file mask (for example, K:\Anime\*.avi)
- /s activates subdirectory parsing. With /s enabled (K:\Anime\*.avi) will enumerate all files with avi extension in K:\Anime and it's subdirectories.

Operation flags control the operation to perform on the files:
- /state <state> marks every parsed file with this storage state. Available states: unknown, hdd, cd, deleted.
- /watched marks every parsed file as watched.
- /edit[mode] activates edit mode. In edit mode files will me MYLIST EDIT-ed by default instead of being MYLIST ADD-ed. Read more in the configuration section.
- /-edit[mode] disables edit mode if it have been enabled through configuration file.

Configuration flags are used to redefine/change settings:
- /noerrors forces application to continue with the next file even if a serious problem (such as a lack of internet connectivity) was encountered with this one.
- /errors or /-noerrors disables /noerrors if it have been enabled through configuration file.
- /autoedit[existing] instructs anidb tool to automatically retry the operation in edit mode if MYLIST ADD request returned 311 FILE ALREADY IN MYLIST. Works only when edit mode is disabled.
- /-autoedit[existing] disables /autoeditexisting if it have been enabled through configuration file.


How to use
===================
First, configure the application according to the "Configuration" section. Basically, you'll only need to specify your username and password.
Now check that everything is working properly. Chose any file known to AniDB (some anime episode, for example) and execute "anidb mylistadd <filename>" from the command line. File will be hashed and added to your mylist. Verify that the answer from server is "mylist entry added", "mylist entry edited" or at least "already in mylist".

Now you can use this tool from the command line.

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
By default, with EditMode and AutoEditExisting disabled, anidb tool will issue a MYLIST ADD command for every file it parses. This command adds a file to MYLIST only if it wasn't there before. If the file have already been registered before, then the request will fail with error 311 FILE ALREADY IN MYLIST and file data will not be changed.
Anidb tool considers this to be a successful result because in most cases this is what one wants. If you just want to register all your files in anidb, then certainly knowing that the file is already registered should be enough for you.

If, on the other hand, you want to change the file data, for example, to mark the file as watched, you'll need to issue a MYLIST EDIT request. For that, specify /edit in the command-line or set EditMode in the configuration file to True. According to documentation, MYLIST EDIT changes the data if the file is already in MYLIST or adds the file if it wasn't there yet.

Naturally, you might want to always MYLIST EDIT files instead of MYLIST ADDing them, because that way you transparently update those files you have already added before. But there's a trick. Documentation lies: in fact MYLIST EDIT does not add new files, although it certainly reports them as "MYLIST ENTRY EDITED". In other words, with /edit enabled you will only edit those files you have already added and will not add those you haven't added yet. What's worse, you won't even know which files were successfully edited, and which were ignored because they weren't in MYLIST: they will all just return "MYLIST ENTRY EDITED".

The solution is to use /autoedit or set AutoEditExisting in the configuration file to True. In this case anidb tool will first issue a MYLIST ADD request for every file, and if it returns "FILE ALREADY IN MYLIST", another request to MYLIST EDIT the file will be issued. This, of course, comes with a cost of having an additional two second wait delay for every file you re-send to anidb.


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

Session information is stored in "session.cfg". This file is not required, you can delete it and it'll be recreated automatically on the next application run. However, session information will be lost and the application will automatically re-logon to AniDB.
In fact, it might be useful to try delete this file if you encounter problems with AniDB.


Version Info
===================
24.10.2009 - Added AutoEditExisting.
27.12.2008 - Fixed another stupid error with int32 used for file size calculations. Now files of more than 2.xx GB in size should at last be hashed correctly.
30.11.2008 - Fixed a stupid error with int32 used for file size calculations. Now files of more than 2.xx GB in size should be hashed correctly.
11.10.2008 - Now tool allows specifying multiple file masks, in random order with switches. Fixed an issue with incorrect hashes for files less than ed2k chunk in size. Added a few options (/edit, /noerrors). All the selected files are parsed in a single run now.
09.14.2008 - Parsing of multiple files by mask, parsing of directories and subdirectories, options to define file storage and watched state. If the file is already in mylist, then it's updated. Retry count in addition to timeout in config.
07.09.2008 - Initial release.


Planned Features
===================
- Hash cache (if hash of first, say, 4096 bytes of the file is in cache, then do not hash file further and use complete file hash stored in cache)
- Mylist cache (to reduce number of requests to anidb and speedup process further)
- "Known files" and an option to ignore files already added to anidb.