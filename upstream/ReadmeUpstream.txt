This subfolder is for storing code (and files) that is related to the Shiny App, but that ISN'T essential enough to that App to deploy along with the app's files. Generally, I refer to such code as "upstream code." It includes code that needs to run to process inputs to then be fed into the app (and stored in the inputs subfolder). 

The subfolders here distinguish between types of upstream code/files:
-Admin: This is for code that performs essential administrative functions for the app. For example, if data must be QA/QCed before it can be used as inputs for the app, files to perform that QA/QC may be stored here.
-Legacy: This is a "dumping ground" for old or experimental code that is no longer essential to the App but that may contain parts that may be useful or may need to be referenced in the future.
-Reference: This is important code that may only have need to be used once to perform its function and now is only needed to be preserved for posterity.
-UpstreamInputs: This folder stores code needed specifically to yield inputs the app must deploy with. 

The idea of putting all this code in one folder is to be able to easily exclude this code from the deployment process because it's all in a single folder that is easy to "uncheck" at the deployment stage, since nothing inside this folder should be essential to include with the app's bundle because its functions aren't needed while the app is actually running.