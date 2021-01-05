resource "azurerm_kubernetes_cluster" "cluster" {
  # General configurations:
  # Location is set to the variable if specified,
  # otherwise it is set to the location of the resource group.
  name                = format("%s-aks-cluster", var.name)
  location            = var.location == "not_set" ? data.azurerm_resource_group.aks.location : var.location
  resource_group_name = var.resource_group
  dns_prefix          = var.name

  # If no Kubernetes version is set, use the latest non-preview version.
  # See the local value for more information.
  kubernetes_version = local.kubernetes_version

  addon_profile {
    kube_dashboard {
      enabled = var.enable_kube_dashboard
    }

    azure_policy {
      enabled = var.enable_azure_policy
    }

    oms_agent {
      enabled                    = var.enable_oms_agent
      log_analytics_workspace_id = var.enable_oms_agent == true ? var.log_analytics_workspace_id : null
    }
  }

  network_profile {
    network_plugin     = var.network_plugin
    network_policy     = var.network_policy
    outbound_type      = var.outbound_type
    service_cidr       = var.service_cidr
    dns_service_ip     = var.dns_service_ip
    docker_bridge_cidr = var.docker_bridge_cidr
    pod_cidr           = var.network_plugin == "kubenet" ? var.pod_cidr : null
  }

  role_based_access_control {
    enabled = var.role_based_access_control
    azure_active_directory {
      managed                = var.azure_ad_managed
      admin_group_object_ids = var.azure_ad_managed == true ? var.admin_groups : null
      # If managed is set to false, then the following properties needs to be set
      client_app_id     = var.azure_ad_managed == false ? var.rbac_client_app_id : null
      server_app_id     = var.azure_ad_managed == false ? var.rbac_server_app_id : null
      server_app_secret = var.azure_ad_managed == false ? var.rbac_server_app_secret : null
    }
  }

  default_node_pool {
    name           = var.default_node_pool[0].name
    vnet_subnet_id = var.subnet_id
    vm_size        = var.default_node_pool[0].vm_size
    node_count     = var.default_node_pool[0].node_count

    enable_auto_scaling = var.default_node_pool[0].enable_auto_scaling
    min_count           = var.default_node_pool[0].min_count
    max_count           = var.default_node_pool[0].max_count

    #node_taints = [var.default_node_pool[0].node_taints]
  }

  # One of either identity or service_principal blocks must be specified.
  # We can control which by using dynamic blocks.
  ## If a Service Principal is not present
  dynamic "identity" {
    for_each = var.sp_client_id == null ? ["SystemAssigned"] : []
    content {
      type = "SystemAssigned"
    }
  }
  ## If a Service Principal is present
  dynamic "service_principal" {
    for_each = var.sp_client_id != null ? [var.sp_client_id] : []
    content {
      client_id     = var.sp_client_id
      client_secret = var.sp_client_secret
    }
  }
}
resource "azurerm_kubernetes_cluster_node_pool" "additional_cluster" {
  for_each = { for np in var.additional_node_pools : np.name => np }

  kubernetes_cluster_id = azurerm_kubernetes_cluster.cluster.id
  name                  = each.value.name
  vm_size               = each.value.vm_size
  node_count            = each.value.node_count
  vnet_subnet_id        = var.subnet_id

  enable_auto_scaling = each.value.enable_auto_scaling
  min_count           = each.value.min_count
  max_count           = each.value.max_count

  node_labels = each.value.node_labels
  node_taints = each.value.node_taints

  tags = each.value.tags
}