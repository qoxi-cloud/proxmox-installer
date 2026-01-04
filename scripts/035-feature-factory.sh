# shellcheck shell=bash
# Feature wrapper factory functions

# Create configure_* wrapper checking INSTALL_* flag. $1=feature, $2=flag_var
# shellcheck disable=SC2086,SC2154
make_feature_wrapper() {
  local feature="$1"
  local flag_var="$2"
  eval "configure_${feature}() { [[ \${${flag_var}:-} != \"yes\" ]] && return 0; _config_${feature}; }"
}

# Create configure_* wrapper checking VAR==value. $1=feature, $2=var, $3=expected
# shellcheck disable=SC2086,SC2154
make_condition_wrapper() {
  local feature="$1"
  local var_name="$2"
  local expected_value="$3"
  eval "configure_${feature}() { [[ \${${var_name}:-} != \"${expected_value}\" ]] && return 0; _config_${feature}; }"
}
