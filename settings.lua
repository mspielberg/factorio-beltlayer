data:extend{
  {
    type = "bool-setting",
    name = "beltlayer-deconstruction-warning",
    setting_type = "runtime-per-user",
    default_value = true,
  },

  {
    type = "int-setting",
    name = "beltlayer-connector-capacity",
    setting_type = "startup",
    minimum_value = 1,
    default_value = 10,
  },
}