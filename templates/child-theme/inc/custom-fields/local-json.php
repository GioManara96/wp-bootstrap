<?php
/**
 * ACF Local JSON
 * sincronizzo i campi ACF
 * @link https://www.advancedcustomfields.com/resources/local-json/
 * @link https://www.advancedcustomfields.com/resources/synchronized-json/
*/
/** save point */
add_filter('acf/settings/save_json', 'mgs_acf_json_save_point');
function mgs_acf_json_save_point( $path ) {
  // update path
  $path = get_stylesheet_directory() . '/inc/custom-fields/json-data';
  // return
  return $path;
}

/** load point */
add_filter('acf/settings/load_json', 'my_acf_json_load_point');
function my_acf_json_load_point( $paths ) {
  // remove original path (optional)
  unset($paths[0]);
  // append path
  $paths[] = get_stylesheet_directory() . '/inc/custom-fields/json-data';
  // return
  return $paths;
}