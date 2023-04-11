function Disable-Role {
  # clean kube config
  $homeDir = [Environment]::GetFolderPath("UserProfile")
  $kubeDir = Join-Path $homeDir ".kube"
      
  . .\functions.ps1
  Clear-KubeConfig -homeDir $homeDir -kubeDir $kubeDir
      
  # prepare secret for authentication
  $SEC_PASSWORD = ConvertTo-SecureString $CLIENT_SECRET -AsPlainText -Force
  $MY_CREDS = New-Object System.Management.Automation.PSCredential($CLIENT_ID, $SEC_PASSWORD)
      
  # connect to azure 
  Write-Host "Connecting to Azure ... `n"
  $output = $(Connect-AzAccount -Credential $MY_CREDS -Tenant $TENANT_ID -ServicePrincipal) 2>&1
  
  if ($output -like "*Value cannot be null*") {
    Write-Host $("ERROR Output: " + $output)
    Write-Host "`n ERROR: Connection to Azure failed, check your tenant Id ! `n"
    Exit 1
  }
  elseif ($output -like "*ClientSecretCredential authentication failed*") {
    Write-Host $("ERROR Output: " + $output)
    Write-Host "`n ERROR: Connection to Azure failed, check your service principal credentials ! `n"
    Exit 1
  }
  else {
    Write-Host "`n=> SUCCESS: Connected to Azure ! `n"
  }
      
      
  # get aks cluster credentials
  Write-Host "Getting AKS Credentials ... `n"
  Import-AzAksCredential -ResourceGroupName $CLUSTER_RG -Name $CLUSTER_NAME -Admin -Force
  Write-Host "`n=> SUCCESS: Credentials updated ! `n"
      
  $output = $($AKS_ID = $(Get-AzAksCluster -ResourceGroupName $CLUSTER_RG -Name $CLUSTER_NAME).Id) 2>&1
  if ($output -like "*invalid*") {
    Write-Host "`nERROR: Your scope is invalid, Please check your cluster name and RG in config file `n It may be also permission issue, make sure that user have the right permissions `n"
    Exit  1
  }
  else {
    Write-Host "`n=> SUCCESS: Cluster Id Get Successfully ! `n"
  }

  Write-Host "Getting Azure AD Group Id ... `n"
  $GROUP_ID = $(Get-AzADGroup -DisplayName $AD_GROUP).Id
  if ($GROUP_ID -like "") {
    Write-Host "`nERROR: GroupId is empty, Group'$AD_GROUP' does not exist ! `n Check your configuration `n"
    Exit  1
  }
  else {
    Write-Host "`n=> SUCCESS: Azure AD Group Id get ! `n"
  }
      
  try {
    # delete role and rolebinding
    Write-Host "deleting role and Role Binding for '$AD_GROUP' ... `n"
    kubectl delete role $($AD_GROUP + "-user-full-access") -n $GROUP_NS
    kubectl delete rolebinding $($AD_GROUP + "-user-access") -n $GROUP_NS
    Write-Host "`n=> SUCCESS: role and Role Binding for '$AD_GROUP' Deleted Successfully ! `n"
        
        
    $output = $(Remove-AzRoleAssignment -ObjectId $GROUP_ID -RoleDefinitionName "Azure Kubernetes Service Cluster User Role" -Scope $AKS_ID) 2>&1
    $output = $output.ToString()
    if ($output -like "*'Conflict'*") {
      Write-Host "`nAzure Kubernetes Service Cluster User Role already removed from '$AD_GROUP' !  `n"  
    }
    else {
      Write-Host "`n=> SUCCESS: Azure Kubernetes Service Cluster User Role removed from '$AD_GROUP' ! `n"
    }
        
    # delete namespace
    Write-Host "deleting namespace '$GROUP_NS' ... `n"
    kubectl delete namespace $GROUP_NS
    Write-Host "`n=> SUCCESS: namespace '$GROUP_NS' Deleted Successfully ! `n"
  }
  catch {
    Write-Host "`nERROR: error occured while deleting the role of team '$AD_GROUP'!"
  }
}
    
# service principal credentials for login
# get credentials from JSON file
$Config_file = ".\deprovision.json"

Write-Host "`nStarting RBAC Role Deprovisionning`n "

# read json configuration
$json = Get-Content -Path $Config_file -Raw
$data = ConvertFrom-Json $json
# read json configuration
foreach ($config in $data.PsObject.Properties.Value) {
  # define Credentials
  $CLIENT_ID = $config.CLIENT_ID
  $CLIENT_SECRET = $config.CLIENT_SECRET
  $TENANT_ID = $config.TENANT_ID
  foreach ($group in $config.Groups.PsObject.Properties.Value) {  
    $CLUSTER_RG = $group.CLUSTER_RG
    $CLUSTER_NAME = $group.CLUSTER_NAME
    $AD_GROUP = $group.AZURE_AD_GROUP_NAME
    $GROUP_NS = $group.GROUP_NAMESPACE
    Write-Host "`n Start Removing accesses of group: '$AD_GROUP', on namespace: '$GROUP_NS', on cluster: '$CLUSTER_NAME' ...`n" 
    Disable-Role
    Write-Host "`n Finished Removing accesses of group: '$AD_GROUP', on namespace: '$GROUP_NS', on cluster: '$CLUSTER_NAME' ...`n"
  }
       
}
Write-Host "`n==> FINISHED !`n"