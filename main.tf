resource "azurerm_storage_account" "storage_account" {
  name                = var.storage_account_name
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location

  account_tier              = var.storage_account.account_tier
  account_replication_type  = var.storage_account.account_replication_type
  enable_https_traffic_only = var.enable_https_traffic_only
  access_tier               = var.access_tier
  account_kind              = var.account_kind

  dynamic "static_website" {
    for_each = local.static_website
    content {
      index_document     = static_website.value.index_document
      error_404_document = static_website.value.error_404_document
    }
  }

  dynamic "blob_properties" {
    # Valid only for account_kind = BlockBlobStorage or StorageV2
    for_each = ((var.account_kind == "BlockBlobStorage" || var.account_kind == "StorageV2") ? [1] : [])
    content {
      versioning_enabled       = var.blob_versioning_enabled
      change_feed_enabled      = var.blob_change_feed_enabled
      last_access_time_enabled = var.blob_last_access_time_enabled

      dynamic "container_delete_retention_policy" {
        for_each = (var.blob_container_delete_retention_policy == 0 ? [] : [1])
        content {
          days = var.blob_container_delete_retention_policy
        }
      }

      dynamic "delete_retention_policy" {
        for_each = (var.blob_delete_retention_policy == 0 ? [] : [1])
        content {
          days = var.blob_delete_retention_policy
        }
      }

      dynamic "cors_rule" {
        for_each = (var.blob_cors_rule == null ? {} : var.blob_cors_rule)
        content {
          allowed_headers    = cors_rule.value.allowed_headers
          allowed_methods    = cors_rule.value.allowed_methods
          allowed_origins    = cors_rule.value.allowed_origins
          exposed_headers    = cors_rule.value.exposed_headers
          max_age_in_seconds = cors_rule.value.max_age_in_seconds
        }
      }
    }
  }


  tags = var.storage_account.tags
}

resource "azurerm_storage_container" "storage_containers" {
  for_each             = var.storage_containers
  name                 = each.value.name
  storage_account_name = azurerm_storage_account.storage_account.name

  container_access_type = each.value.container_access_type
}

resource "azurerm_storage_share" "storage_shares" {
  for_each             = var.storage_shares
  name                 = each.value.name
  storage_account_name = azurerm_storage_account.storage_account.name
  quota                = each.value.quota
}

resource "azurerm_storage_queue" "storage_queues" {
  for_each             = var.storage_queues
  name                 = each.value.name
  storage_account_name = azurerm_storage_account.storage_account.name
}

resource "azurerm_cdn_profile" "cdn-profile" {
  count               = var.enable_cdn_profile ? 1 : 0
  name                = var.cdn_profile_name
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location
  sku                 = var.cdn_sku
}

resource "azurerm_cdn_endpoint" "cdn-endpoint" {
  count                         = var.enable_cdn_profile ? 1 : 0
  name                          = var.cdn_endpoint_name
  profile_name                  = azurerm_cdn_profile.cdn-profile.0.name
  resource_group_name           = var.resource_group.name
  location                      = var.resource_group.location
  origin_host_header            = azurerm_storage_account.storage_account.primary_web_host
  querystring_caching_behaviour = "IgnoreQueryString"

  origin {
    name      = var.cdn_origin_name
    host_name = azurerm_storage_account.storage_account.primary_web_host
  }

}