module "kubernetes" {
  source  = "roberthstrand/kubernetes/azurerm"
  version = "1.1.0"

  name           = "demo"
  resource_group = azurerm_resource_group.cluster.name
  subnet_id      = azurerm_subnet.aks.id

  # The default deployment is managed, with RBAC. This means that you have to define a group or groups
  # that will have admin rights to the cluster. Check settings.tf to see how we can more easily refer to
  # group names, rather than object IDs. To refer to more than one group at the time, you can use the
  # azuread_groups data source like we do here.
  admin_groups = data.azuread_groups.admins.object_ids

  service_principal = {
    client_id     = var.client_id
    client_secret = var.client_secret
  }

  depends_on = [azurerm_resource_group.cluster]
}
