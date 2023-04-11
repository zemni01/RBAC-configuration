Requirements: 
    - Azure AKS cluster should have: 
        * Azure AD integration enabled 
        * Kubernetes RBAC enabled (Azure AD authentication with Kubernetes RBAC)
        * local accounts enabled
        * service principal should be granted owner role
    - service principal created with the required permissions: (https://learn.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal)
        * create service principal 
        * assign to it owner role on AKS cluster 
    - Az powershell module & Kubectl should be installed on the Environment (https://learn.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-9.6.0) 

steps: 
    - update the JSON configuration file (provision/deprovision) with the right credentials: 
        * service principal credentials
        * AKS Cluster name and resource group
        * Azure AD group that will have the permissions
        * Cluster namespace to be granted access to
    - launch provision-roles.ps1 to deploy the accesses for the desired group
    - launch deprovision-roles.ps1 to delete the provisionned roles and the namespace
