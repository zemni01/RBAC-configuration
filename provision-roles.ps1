function Enable-Role {
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

  Write-Host "Getting AKS Cluster Id ... `n"
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
 
  # Check if namespace exists in AKS Cluster
  . .\functions.ps1
  Test-Namespace -AKS_CLUSTER $CLUSTER_NAME -NAMESPACE $GROUP_NS

  # Assign Cluster User Role to the Group
  Write-Host "Assigning Azure Kubernetes Service Cluster User Role to Group ... `n"
  $output = $(New-AzRoleAssignment -ObjectId $GROUP_ID -RoleDefinitionName "Azure Kubernetes Service Cluster User Role" -Scope $AKS_ID) 2>&1
  $output = $output.ToString()
  if ($output -like "*'Conflict'*") {
    Write-Host "`nAzure Kubernetes Service Cluster User Role already Assigned to '$AD_GROUP' !  `n"  
  }
  else {
    Write-Host "`n=> SUCCESS: Azure Kubernetes Service Cluster User Role Assigned to '$AD_GROUP' ! `n"
  }



  # Create namespace role to the Group
  Write-Host "Assigning full accesses to Group: '$AD_GROUP' On namespace '$GROUP_NS' ... `n"
  $role = @"
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: $($AD_GROUP + "-user-full-access")
  namespace: $GROUP_NS
rules:
- apiGroups: ["", "extensions", "apps"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["batch"]
  resources:
  - jobs
  - cronjobs
  verbs: ["*"]
"@

  $role | kubectl apply -f -
  Write-Host "=> SUCCESS: full access role to Group: '$AD_GROUP' On namespace '$GROUP_NS' created !`n"

  # Bind role of the Group to the namespace
  Write-Host "Binding created role to namespace '$GROUP_NS' ... `n"
  $role_binding = @"
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: $($AD_GROUP+"-user-access")
  namespace: $GROUP_NS
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: $($AD_GROUP +"-user-full-access")
subjects:
- kind: Group
  namespace: $GROUP_NS
  name: $GROUP_ID
"@

  $role_binding | kubectl apply -f -
  Write-Host "`n=> SUCCESS: Role Binding created !`n"
  
}

# service principal credentials for login
# get credentials from JSON file
$Config_file = ".\provision.json"
#Get Storage Account context
Write-Host "`nStarting RBAC Role Provisionning`n "
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
        
    Write-Host "`n Start Configuring accesses of group: '$AD_GROUP', on namespace: '$GROUP_NS', on cluster: '$CLUSTER_NAME' ...`n" 
    Enable-Role
    Write-Host "`n Finished Configuring accesses of group: '$AD_GROUP', on namespace: '$GROUP_NS', on cluster: '$CLUSTER_NAME' ...`n" 
  }
       
}
  
Write-Host "==> FINISHED !"




