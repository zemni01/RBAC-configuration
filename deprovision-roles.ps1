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
      Connect-AzAccount -Credential $MY_CREDS -Tenant $TENANT_ID -ServicePrincipal
      Write-Host "=> SUCCESS: Connected to Azure ! `n"
      
      # get aks cluster credentials
      Write-Host "Getting AKS Credentials ... `n"
      az aks get-credentials -g $CLUSTER_RG -n $CLUSTER_NAME --admin
      Write-Host "=> SUCCESS: Credentials updated ! `n"
      
      $AKS_ID = $(az aks show --resource-group $CLUSTER_RG --name $CLUSTER_NAME --query id -o tsv)
      $GROUP_ID = $(az ad group show -g $AD_GROUP --query id -o tsv)
      
      try {
        # delete role and rolebinding
        Write-Host "deleting role and Role Binding for '$AD_GROUP' ... `n"
        kubectl delete role $($AD_GROUP + "-user-full-access") -n $GROUP_NS
        kubectl delete rolebinding $($AD_GROUP + "-user-access") -n $GROUP_NS
        Write-Host "=> SUCCESS: role and Role Binding for '$AD_GROUP' Deleted Successfully ! `n"
        
        az role assignment delete --assignee $GROUP_ID --role "Azure Kubernetes Service Cluster User Role" --scope $AKS_ID
        
        # delete namespace
        Write-Host "deleting namespace '$GROUP_NS' ... `n"
        kubectl delete namespace $GROUP_NS
        Write-Host "=> SUCCESS: namespace '$GROUP_NS' Deleted Successfully ! `n"
      }
      catch {
        Write-Host "ERROR: error occured while deleting the role of team '$AD_GROUP'!"
      }
    }
    
# service principal credentials for login
# get credentials from JSON file
$Config_file = ".\deprovision-roles.json"

Write-Host "`n==> Starting RBAC Role Deprovisionning`n "

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

        Disable-Role
    }
       
}
Write-Host "`n==> FINISHED !`n"