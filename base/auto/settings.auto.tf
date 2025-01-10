# Settings (region wide)
locals {
  ### Settings (Region wide)
  # 1. we decode the yaml files and return null with the filename if yaml has an error
  # 2. we filter out settings that have errors which return a list of files with errors
  # 3. we create a boolean if there are errors
  # 4. if there are no errors, we merge the settings into a map
  settings_array = [for f in fileset(path.module, "./resources/settings/*.yaml"): [try(yamldecode(file(f)), null), f]]
  settings_with_err = [ for setting in local.settings_array: setting[1] if setting[0] == null ]
  settings_has_err = length(local.settings_with_err) > 0
  settings =  local.settings_has_err ? {} : { for k, v in merge([ for setting in local.settings_array: setting[0]]...): k => v if try(v.create, true) } 
}

resource "aws_vpc_block_public_access_options" "this_account" {
  count = try(local.settings.enable_aws_vpc_block_public_access_options, false)  ? 1 : 0

  internet_gateway_block_mode = try(local.settings.internet_gateway_block_mode, "off")
}