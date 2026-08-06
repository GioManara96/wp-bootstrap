<?php
/**
 * Hide the ACF menu from users outside the agency email domain.
 * Replace the allowlist with your own domain(s).
*/

add_action( 'admin_menu', 'mgs_remove_acf_menu', 999);
function mgs_remove_acf_menu() {
	$current_user = wp_get_current_user();
	$allowed      = array('example.com');
	$parts        = explode('@', $current_user->user_email);
	$domain       = array_pop($parts);
	if( ! in_array($domain, $allowed) ):
		remove_menu_page('edit.php?post_type=acf-field-group');
	endif;
}