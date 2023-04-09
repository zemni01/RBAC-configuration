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
Connect-AzAccount -Credential $MY_CREDS -Tenant $TENANT_ID -ServicePrincipal
#az login --service-principal -u $CLIENT_ID -p $SEC_PASSWORD --tenant $TENANT_ID
Write-Host "=> SUCCESS: Connected to Azure ! `n"

# get aks cluster credentials
Write-Host "Getting AKS Credentials ... `n"
az aks get-credentials -g $CLUSTER_RG -n $CLUSTER_NAME --admin
Write-Host "=> SUCCESS: Credentials updated ! `n"

Write-Host "Getting AKS Cluster Id ... `n"
$AKS_ID = $(az aks show --resource-group $CLUSTER_RG --name $CLUSTER_NAME --query id -o tsv)
Write-Host "=> SUCCESS: Cluster Id Get Successfully `n"

Write-Host "Getting Azure AD Group Id ... `n"
$GROUP_ID = $(az ad group show --group $AD_GROUP --query id -o tsv)
Write-Host "=> SUCCESS: Azure AD Group Id get ! `n"

# Check if namespace exists in AKS Cluster
. .\functions.ps1
Test-Namespace -AKS_CLUSTER $CLUSTER_NAME -NAMESPACE $GROUP_NS

# Assign Cluster User Role to the Group
Write-Host "Assigning Azure Kubernetes Service Cluster User Role to Group ... `n"
az role assignment create --assignee $GROUP_ID --role "Azure Kubernetes Service Cluster User Role" --scope $AKS_ID
Write-Host "=> SUCCESS: Azure Kubernetes Service Cluster User Role Role Assigned to '$AD_GROUP' ! `n"

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
Write-Host "=> SUCCESS: Role Binding created !`n"
  
}

# service principal credentials for login
# get credentials from JSON file
$Config_file = ".\provision.json"
Write-Host "`n==> Starting RBAC Role Provisionning`n "
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

        Enable-Role
    }
       
}
  
Write-Host "==> FINISHED !"




