Besides this file, there are 5 files that should always exist within this folder:

1. ui.R, which stores the code needed to craft the UI (user interface) of the App.
2. server.R, which stores all the R code needed to effect the server (back-end) portion of the App.
3. global.R, which performs all the "setup" needed for the app to start up, including loading all dependent files and libraries, as well as "pre-baking" any environmental objects needed by ui.R and/or server.R.
4. A .gitignore file. This file tells GitHub which files to ignore when pushing/committing this folder. This can be used to exclude sensitive files (like authentication tokens and proprietary data) from getting pushed to GitHub along with the app's code.
5. An .RProj file. This is the file that gets produced when an R Project folder is created (which your App's root folder should always be!). This is generated automatically when an R Project is generated in R Studio. 

Nothing else should be in this folder for tidy deployment! Put it in a subfolder. Even this file can (eventually) be deleted to prevent it being excluded from the deployment process, if desired.