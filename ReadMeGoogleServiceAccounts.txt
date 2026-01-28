1. Log in to Google Cloud w/ umn account.
2. Click the Console button (I think).
3. Create a new project, then "select Project"
4. Go to IAM & Admin/IAM
5. Go to Service Accounts, then Create Service Account
6. Make the service account have editor Role--make yourself the owner account. 
7. Have it generate a new json key, which will download. Move it to your tokens subfolder.
8. Take the email address of the service account and grant it share/edit access to all relevant folders and files.
9. Search for Enabled APIs and Services, then find Google Drive and/or Google Sheets and enable the APIs