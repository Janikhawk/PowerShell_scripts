####################################################################
#Copy/Replace items from one list to another list with Attachments
#Original Author: Zhangeldy Kuldeyev
#Enhancements - Author: Zhangeldy Kuldeyev
####################################################################

Remove-PSSnapin Microsoft.SharePoint.PowerShell -erroraction SilentlyContinue
Add-PSSnapin Microsoft.SharePoint.PowerShell -erroraction SilentlyContinue 

$currentSite = "" #type url of site with your lists here
$Web = Get-SPWeb -site $currentSite
$List = $Web.Lists
$stop = 0
$srcTask=""
$finalcount=0;
for($i=0; $i -lt $List.Count; $i++)#used for loop because foreach doesn't work in this situation
{
    if($List[$i].DefaultView.Url -like "*gantt*")
    {
        $srcTask = $List[$i].DefaultView.Url.Substring(0,$List[$i].DefaultView.Url.Length-11)
        try
        {   
            $SourceList = $Web.GetList($Web.url + "/" + $srcTask)
            if($SourceList -eq $null){continue}

            $DestinationList = $Web.GetList($Web.url + "/Lists/testDestinationList")
            $keyColumnInternalName = "Title" 
            #Filtering Items based on the Date as we do not want to archive all items in the list                  
            $filterQuery =
                        '<Where><And><Gt><FieldRef Name = "Created" /> <Value IncludeTimeValue="TRUE" Type="DateTime">2018-09-25T00:00:00Z</Value></Gt>           
                            <Lt><FieldRef Name = "Created" /> <Value IncludeTimeValue="TRUE" Type="DateTime">2019-10-21T00:00:00Z</Value></Lt></And></Where>'     

            $CategoryQuery = new-object Microsoft.SharePoint.SPQuery
            $CategoryQuery.Query = $filterQuery
                
            $sourceSPListItemCollection = $SourceList.GetItems($CategoryQuery);
           
            if( $sourceSPListItemCollection.Count -gt 9)
            {
                $defaultValue = "Имя подзадачи отсутсвует"
                $count=0;
                foreach($SourceListItem in $sourceSPListItemCollection)
                {   
                    #write-host $sourceSPListItemCollection[8].Title
                    $SourceListItem
                    $keyValue = $SourceListItem[$keyColumnInternalName]
                        
                    if($keyValue -ne "Согласование перехода на следующий этап" -and $keyValue -ne "Согласование завершения" -and !($keyValue -like "Стадия DOI*") ) #except them
                    {   
                        $idValue = $SourceListItem["ID"]
                        if($idValue -eq 9)
                        {
                            #$defaultValue=$keyValue
                            #$count++                 
                            continue
                        }
                                    
                        
                        $camlQuery =
                                   '<Where> 
                                        <And>
                                            <Eq>
                                                <FieldRef Name="Title"/>
                                                <Value Type="Text">'+$SourceList.Title+'</Value>                                                
                                            </Eq>                                                                                
                                            <And>
                                                <Eq>
                                                    <FieldRef Name="subTaskTitle"/>
                                                    <Value Type="Text">'+$defaultValue+'</Value>                                                
                                                </Eq>                                                
                                                <And>
                                                    <Eq>
                                                        <FieldRef Name="manualTask"/>
                                                        <Value Type="Text">'+$keyValue+'</Value>
                                                    </Eq>
                                                    <Eq>
                                                        <FieldRef Name="subTaskID"/>
                                                        <Value Type="Text">'+$idValue+'</Value>
                                                    </Eq>                                            
                                                </And>
                                            </And>
                                        </And>
                                    </Where>'
                        $spQuery = new-object Microsoft.SharePoint.SPQuery
                        $spQuery.Query = $camlQuery
                        #$spQuery.RowLimit = 1

                        #check if the item is already present in destination list
                        $destItemCollection = $DestinationList.GetItems($spQuery)
                        write-host $destItemCollection.Count
                        if($destItemCollection.Count -gt 0)
                        {
                            $finalcount++
                            write-host "***List item already exists***"
                            write-host $keyValue  
                        }
                        else
                        {   
                            write-host "Adding new item"
                            write-host $keyValue                                     

                            $newSPListItem = $DestinationList.AddItem();
                                                              
                            $newSPListItem["Title"] = $SourceList.Title;
                            $newSPListItem["subTaskTitle"] = $sourceSPListItemCollection[8].Title; 
                            $newSPListItem["manualTask"] = $keyValue; 
                            $newSPListItem["StartDate"] = $SourceListItem["StartDate"]; 
                            $newSPListItem["DueDate"] = $SourceListItem["DueDate"];
                            $newSPListItem["AssignedTo"] = $SourceListItem["AssignedTo"]; 
                            $newSPListItem["PercentComplete"] = $SourceListItem["PercentComplete"]; 
                            $defaultURL = $currentSite + "/" + $SourceList.DefaultView.Url
                            $newSPListItem["taskURL"] = $defaultURL; 
                            $newSPListItem["subTaskID"] = $SourceListItem["ID"];
                                                           
                            $newSPListItem.Update()

                            #start of permission copy#
                            foreach($roleAssignment in $SourceList.RoleAssignments) 
                            { 
                                if(-not [string]::IsNullOrEmpty($roleAssignment.Member.Xml)) 
                                { 
                                    foreach($roleDefinBindings in $roleAssignment.RoleDefinitionBindings)
                                    {
                                        if ($roleDefinBindings.Name -eq "Limited Access") { continue; }
                                        "$($roleAssignment.Member.Name) | $($roleDefinBindings.Name)"

                                        $permissionLevel = $roleDefinBindings.Name
                                        $groupName = $roleAssignment.Member.Name  
                                        "$permissionLevel $groupName"                                  
                                                
                                        if ($newSPListItem.HasUniqueRoleAssignments -eq $false)
                                        {
                                            $newSPListItem.BreakRoleInheritance($false)
                                        }
                                        $newSPListItem.RoleAssignments.Add($roleAssignment)
                                        $newSPListItem.SystemUpdate($true)
                                    } 
                                } 
                            }  #end of permission copy#                                    
                        }#end else 
                    }                                                        
                }#end of for loop   
            }            
        }
        catch 
        { 
            write-host $_.exception 
        } 
        finally
        {        
            if($sourceListWeb -ne $null){$sourceListWeb.Dispose()}
            if($dstListWeb -ne $null){$dstListWeb.Dispose()}
        }
    }    
}

write-host $finalcount + "matches were found"