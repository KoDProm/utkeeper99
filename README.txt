 ___  __    ___  ___       ___       _______   ________  ________           ________  ________           ________  _______   _____ ______   ________  ________   ________     
|\  \|\  \ |\  \|\  \     |\  \     |\  ___ \ |\   __  \|\   ____\         |\   __  \|\   ___  \        |\   ___ \|\  ___ \ |\   _ \  _   \|\   __  \|\   ___  \|\   ___ \    
\ \  \/  /|\ \  \ \  \    \ \  \    \ \   __/|\ \  \|\  \ \  \___|_        \ \  \|\  \ \  \\ \  \       \ \  \_|\ \ \   __/|\ \  \\\__\ \  \ \  \|\  \ \  \\ \  \ \  \_|\ \   
 \ \   ___  \ \  \ \  \    \ \  \    \ \  \_|/_\ \   _  _\ \_____  \        \ \  \\\  \ \  \\ \  \       \ \  \ \\ \ \  \_|/_\ \  \\|__| \  \ \   __  \ \  \\ \  \ \  \ \\ \  
  \ \  \\ \  \ \  \ \  \____\ \  \____\ \  \_|\ \ \  \\  \\|____|\  \        \ \  \\\  \ \  \\ \  \       \ \  \_\\ \ \  \_|\ \ \  \    \ \  \ \  \ \  \ \  \\ \  \ \  \_\\ \ 
   \ \__\\ \__\ \__\ \_______\ \_______\ \_______\ \__\\ _\ ____\_\  \        \ \_______\ \__\\ \__\       \ \_______\ \_______\ \__\    \ \__\ \__\ \__\ \__\\ \__\ \_______\
    \|__| \|__|\|__|\|_______|\|_______|\|_______|\|__|\|__|\_________\        \|_______|\|__| \|__|        \|_______|\|_______|\|__|     \|__|\|__|\|__|\|__| \|__|\|_______|
                                                           \|_________|                                                                        http://killersondemand.ddns.net                         


#############################################################################
#                                                                           #
#               UTKeeper99 (UTK) by [KoD]Prom in 2026                       #
#             >>> Killers on demand <<< Clan since 1999                     #
#                                                                           #
#############################################################################
#
# UTKeeper99 (UTK) is free GNU General public licence and comes with 
# ABSOLUTELY NO WARRANTY! RUN AT YOUR OWN RISK!
# Forged on Debian 12 Trixie
#
# READ this FIRST!
# Dont trust me...always run SmartBackup-Tool first!
# Modify freely, keep original credits. NO commercial use!
# Keep this archive always intact! Thank you!
#
# I really dont know if i will update the code later for bugfixing or 
# expanding. Possible not and then this will be my final version. 
# I wont perceive Issues or Push requests. So please just take it as it is.
# 
#
# Credits:
# uzip 1.0 by [es]Rush Copyright 2005
# ASH 0.6 by abfackeln @ abfackeln.com Copyright 2001, 2002
# 
# 
# NOTE: Well what should i say. Be careful. I did my best for
# complience but this tool might be fucking up your whole System.
# Do not run any parts of the Tool you dont understand. I tried
# to be as specific as i could be, but iam just a human. I have to admit, 
# I reviewed the code in claude .ai(01/2026) scanning only for syntax and
# some parts of my brain. Damn...due that i lost all my funny coding coments :/ 
# But instead you got a best practise 2026.
# And here we are.(for me its working :) ("any famouse last words?" )
# During coding and testing i messed up my VM more than one time and
# lost about 30gb unrecoverable data, iǘe done everything in my mind to 
# prevent this from ever happen again. Lesson learned, mbee. mbee not.
# Critical scripts distribution.sh, snafu_fix.sh. and orphan.sh
# 
# I put some example services files in the ./example folder you might need 
# for installing services. You can run this without services and just use
# Maptools or Backup function.
#
# REQUIREMENTS: 
# - some linux, some GPU and RAM, Bash 4.x (sudo, coreutils, grep, sed...)
# - enough space left on drive for backup operations.
# - A local running 32bit Unreal Tournament 1999 Server (sry, I was too lazy to
#   redo everything. Some Parts are already integrated some parts not!!)
# - and if you got a local WebRedirect you can use that too. If you
#    dont have that, some functions wont work well. 
# 
#
# ZIP and ExtractionTools 
# Debianlike: 
# sudo apt install zip unzip p7zip-full p7zip-rar unrar
#
#
# What this Script supports and does. 
# It needs sudo for work! But you dont need it nesseary as installation in 
# /usr/local/bin/utkeeper99 or /opt/utkeeper99 you can also put it on your 
# User Desktop should run fine as well. Remember setting chmod +x and chown.
# Usage default path /utkeeper/upload...just drop all files in that path. 
# Otherwise the script has got nothing to do.
#
#  Features Highlights:
#  - First-Run Auto-Config Detection (should reject critical system paths)
#  - DryRun Mode for safe testing
#  - Recursive Archive Extraction (up to 10 levels deep)
#  - Smart File Collection (gathers all UT files from subdirs)
#  - Disk Space Validation before Backup
#  - Backup Management (List, Delete by age, etc.)
#  - Distribution of Maps to UT Server and Webserver
#  - Cloning Maps (you like CTF-Face? or a MH Map ? now play that as DM/TDM map)
#  - Name fixes (case sensitive for Linux) + chmod/chown defaults for UT/Web
#  - Advanced UT and Webserver Orphan Cleaning Tool
#  - Modular design for easy expansion/customization.
#
#
# On the first start of the script you have to define AutoConfig feature. 
# And if you have to change these setting please consider running 8.Configuration!
# IMPORTANT! IN ANY CASE DO NOT ENTER '/' WITHOUT PATH! it will screw you up!
# IF you are running a VM consider to remove exchange paths if there are valid
# Unreal Tournament Structures. But you will get it in the moment after 
# AutoDetection, right?
#   - Auto-Detection Paths
#   - Auto-Detection Services
#   - Smart Ownership Detection
#
# Main Menu
# 1- Start UT and Apache redirect as a service (check /examples folder should be also possible for Nginx)
# 2- Stop UT Server and Apache as a service
# 3- System wide Logs in realtime (Systemlog, WebLog, ErrorLog, AuthLog, Fail2ban)
# 4- UT.log in realtime (watch out for your variables at startup service defind a default .ini and .log)
# 5- Complete System and UT Log Overview
# 6. Deletes and Trunk Systemwide and UT Logs (Systemlog, WebLog, ErrorLog, AuthLog, Fail2ban Log, UT log)
# 7. MapTools (featuring Extract most packed tools make .uz compress and deploy to UT and WebRedirect, 
#     corrects names case sensitive. Just put every zip, rar, 7zip, tar.balls into the the ./upload path you 
#     want to install. cleares up all files after done. Verifying installation Status.
#     And if you have fucked up your Linux things with wrong user or groups you got a fire-and-forget tool with 
#     the name 'snafu_fix".     
#     But you can run this menu also as Dry-Run first! (strongly recommended!) 
# 8. Configuration the most importent part of the whole Script. *should be fixed with the current first run autoconfig
#    (you should NOT edit the utkeeper\.config file!)
# 9. Toggle DryRun for the MapTools file and path actions. you should try it after setting up the config file.
# s- SmartBackup (choose between UT Server or Webredirect or both into a zip file with date to the main path of the script.
#     Also featured: Show Backups, Delete backups or backup this script including /upload/installed path.
#     All .zip Files will be found in the script root/Backups path.
#     - Disk Space Check
#     - Size Estimation
#     - Permission Checks
#     - List/Delete Functions
#     - Timestamp Format (YYMMDD-HHMM)
#
# r- this README.txt
#
# Additional Info for MapTools Menu 
# (THIS IS THE DRYRUN Toggle logic which is implemented):
# For useage drop all your zip,rar,7zip,tar files you will handle into the script /upload path.
# 1- for decompressing all Files that are there. After that we move old zips into /installed path for Backups.
#     All Files will be gatherd in den /upload path. 
#     - Recursive Extraction (max depth 10)
#     - collect_ut_files() Funktion
#     - Move to files to /installed after extract
# 2- Compress all files in /upload to .uz format (looks easy, but you should take care of your ucc file.
#     Leave it if its your UnrealClient, but if you got a Server you may update the ucc file from /examples/ucc.txt
#     for using the ucc file compression.
# 3- Distribution will collect all .uz moving to redirect path on the webserver, Maps, Textures, Sounds, Music, System
#     files will be moved to your UT Server and after all that moving checking chmod and chown which comes from
#     the config.
# 4- Cleanup the whole /upload root path without the /upload/installed and /Backups dir.
# 5- SNAFU_Fix will fix all chown and chmod on web and ut server! including 755,644 +x on /System/ucc* /System64/ucc*
#     (supports Map prefix DM-|CTF-|DOM-|AS-|MH-|MA-|RA-|BR-|). It also includes Features
#     renaming case sensitive on web and ut server for maps.
# 6- Verify UT installation (find corrupt files or 0Byte files)
# 7- Making DM-Map clones from CTF,DOM,AS,RA,BR,MH,MA maps in /upload folder
# 8- Scanning for Orphans on UT Server and Webredirect.
# 
# The Orphans we all know they exist and possible ever will be. You get a chance to check each Map in your
# Server dependencies on .uax, .utx, .umx related files. Save that information, add some WhiteLists and 
# check out what you ve got left. Choose what and if you want delete some things manually. I didnt really care 
# about GameMods (/System files). So I trust in the Server admin abilities to say NO to packages. 
# If you are not sure, consider SmartBackup or Dryrun first! 
#
# 1- Extract Map Dependencies (scan all .unr files) that will take a while if you have a lot of Maps. But
#     I think its nessesary to do that. Run it each time if you removed Maps from Server!
#     It creates a all_map_dependencies.txt file in /libs )(you should NOT edit this file!)
# 2 - Generate Whitelist (create protection list) super nasty hardcoded stuff I thought the server might needs
#     [1/4] Added system packages (hardcoded)
#     [2/4] Added map dependencies (packages)
#     [3/4] Parsing ServerPackages from: ut.ini (or UnrealTournament.ini)
#     [4/4] Added pattern-based packages
#     It creates a dependency_whitelist.txt in /libs (you should NOT edit this file!)
# 3 - Detect & Delete Orphaned Packages (.utx/.uax/.umx) and just finish the job. Choose wisely.
#      Options:
#       a) Delete ALL orphaned packages
#       s) Select numbers to DELETE (comma-separated, e.g. 1,5,8)
#       k) Select numbers to KEEP (comma-separated, everything else deleted)
# 4 - Clean Orphan .uz files on Webserver.  If there are .uz files it will compare 
#      Server /Maps /Textures /Sounds /Music even if its a redirectet /System/*.u file it should
#      be found. *checkmate*
#
#
########################################################################################################################
#
# Greetings to: BBWG, THCO, ASN, UTClanDortmund, Baumkuschler, MercedesBenzClan, UnrealAdmin.org, OldUnreal.com,
#               UnrealArchive.org, ut99.org, utzone.de, ut99maps.net i cant name you all guys...
#               and to all these ppl still running MasterServers TY!
#
# And last not least i wanna say thank you to my dead clan, we had a lot of good times at a lot of lan parties 
# and "Blauer-Klaus". "blue-Klaus" was a drink made out of blue menthol candy and some 40%+ local clear schnaps.
# Was the best thing to start into day 2 after a nosleep day 1. on lans. 2-3 shoots, coffee and a cigarette :)
# Miss you boyz!
#
# Thanks to the whole community who kept this running for such a long time!
# 
# This is script is done, just for fun. It simply started with a small bash to start, stop and restart the
# services...and its a bit outgrown maybe, so may somebody else might find it helpful too. At least it will go into
# someones else databases and its a proof...i was alive in some parts of my life.
# You cant kill an idea. Ideas are bulletproof!
#
# And now, stay healthy and smash some faschists!
# >>> GL & HF! <<<
#
# [KoD]Prom
#
#
# Further Readmes included:
#
###########################################################
# Unreal Tournament Package Compression Utility For Linux #
#                        > uzip <                         #
#        Author: [es]Rush        Copyright 2005           #
#                     Unreal Zip 1.0                      #
#   You can modify and redistribute this script as long   #
#        as you do not change the original author.        #
###########################################################

The primary goal of this script was to help my clanmates
to admin the server, I didn't want to explain them for hours
how to compress new packages they upload so I've just decided
to make a script. During writing I thought that it would
be also useful for the community, and so the next few hours
were spend on making it more usable. ;) Enjoy.

(Contact)
PM Rush on unrealadmin.org
Email me on rush@u.one.pl

###########################################################
#
# asu.sh
#
# abfackeln's server utilities
# for unreal tournament
#
# Copyright (C) 2001,2002 abfackeln@abfackeln.com
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
# 
###########################################################
