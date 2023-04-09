# function that checks if the namespace exists
function Test-Namespace {
    param (
      [string]$AKS_CLUSTER,
      [string]$NAMESPACE
    )
    $output = $(kubectl get namespaces $NAMESPACE) 2>&1
    $output=$output.ToString()
    if ($output.Contains("not found")) {
        kubectl create namespace $NAMESPACE
        Write-Host "=> SUCCESS: Namespace '$NAMESPACE' Exists in AKS Cluster '$AKS_CLUSTER' `n"
    }else {
        Write-Host "=> Namespace '$NAMESPACE' Already Exists in AKS Cluster '$AKS_CLUSTER' `n"
    }
}

  function Clear-KubeConfig {
    param(
        [string]$homeDir,
        [string]$kubeDir
    )
    if (Test-Path $kubeDir -PathType Container){
        Write-Host "Deleting .kube folder ... `n"
        Remove-Item $kubeDir -Recurse -Force
        Write-Host ".kube folder deleted `n"
    } else {
        Write-Host "=> SUCCESS: .kube folder not found. `n"
    }
  }

  function Get-Creds {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Config_file
    )

    # read json configuration
    $json = Get-Content -Path $Config_file -Raw
    $data = ConvertFrom-Json $json

    $CLIENT_ID=$data.CLIENT_ID
    $CLIENT_SECRET=$data.CLIENT_SECRET
    $TENANT_ID=$data.TENANT_ID
    $CLUSTER_RG=$data.CLUSTER_RG
    $CLUSTER_NAME=$data.CLUSTER_NAME
    $AD_GROUP=$data.AZURE_AD_GROUP_NAME
    $GROUP_NS=$data.GROUP_NAMESPACE 

    # return the values
    return @{
        CLIENT_ID=$CLIENT_ID
        CLIENT_SECRET=$CLIENT_SECRET
        TENANT_ID=$TENANT_ID
        CLUSTER_RG=$CLUSTER_RG
        CLUSTER_NAME=$CLUSTER_NAME
        AD_GROUP=$AD_GROUP
        GROUP_NS=$GROUP_NS
    }
  }