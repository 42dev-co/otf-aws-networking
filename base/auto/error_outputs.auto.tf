output "yaml_decode_errors" {
  description = "This will show all file names that failed to yaml decode due to syntax errors."
  value = concat(local.prefix_lists_with_err, local.settings_with_err, local.vpc_config_tuple_with_err, local.tgws_with_err, local.shared_tgws_with_err, local.tgw_route_tables_with_err)
}