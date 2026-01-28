Most Shiny Apps require many inputs to run. These input files should go in this folder. 

The three subfolders distinguish between inputs depending upon their frequency of change--unchanging files go in Static, regularly or constantly changing files go in Dynamic, and files that change predictably as upstream processes yield them go in MadeUpstream. 

JavaScript and CSS files as well as image and font files, do NOT go in this folder. They go in www, where the app will be looking for them.