
if ((Get-PSSnapin "Microsoft.SharePoint.PowerShell" -ErrorAction SilentlyContinue) -eq $null) {
    Add-PSSnapin "Microsoft.SharePoint.PowerShell"
}

[Reflection.Assembly]::LoadWithPartialName("Microsoft.Office.Server")

$url = "" #URL of any site collection that is associated to the user profile service application. 

$userProfileArray = @("WorkPhone","CellPhone","StreedAddress","PictureURL","Office","Location")
$ADArray = @("telephoneNumber", "mobile", "streetAddress", "thumbnailPhoto", "physicalDeliveryOfficeName", "l")

$aboutMe = "AboutMe" #отсутствует на АД
$skypeAcc = "SkypeAccount" #отсутствует на АД

$site = Get-SPSite $url

if ($site) 
{Write-Host "Successfully obtained site reference!"} 
else 
{Write-Host "Failed to obtain site reference"}

$serviceContext = Get-SPServiceContext($site)
#$serviceContext = [Microsoft.Office.Server.ServerContext]::GetContext($site)

    
if ($serviceContext) 
{Write-Host "Successfully obtained service context!"} 
else 
{Write-Host "Failed to obtain service context"} 
$upManager = new-object Microsoft.Office.Server.UserProfiles.UserProfileConfigManager($serviceContext)

if ($upManager) 
{Write-Host "Successfully obtained user profile manager!"} 
else 
{Write-Host "Failed to obtain user profile manager"} 
$synchConnection = $upManager.ConnectionManager["ConERG"]

#Write-Host $upManager.IsSynchronizationRunning()
if ($synchConnection) 
{Write-Host "Successfully obtained synchronization connection!"} 
else 
{Write-Host "Failed to obtain user synchronization connection!"}

Write-Host "Adding the attribute mapping..." 
for($i = 0; $i<$userProfileArray.length;++$i){
    $synchConnection.PropertyMapping.AddNewExportMapping([Microsoft.Office.Server.UserProfiles.ProfileType]::User, $userProfileArray[$i].ToString(), $ADArray[$i].ToString())
}
Write-Host "Done!"
