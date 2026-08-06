<?php
add_action('acf/init', 'my_acf_op_init');
function my_acf_op_init() {

	if( function_exists('acf_add_options_sub_page') ) {

		/** aggiunga una pagina nelle impostazioni */
		$child = acf_add_options_sub_page(array(
			'page_title'  => get_bloginfo('name').__(' Options', 'mgs'),
			'menu_title'  => __('Theme Options', 'mgs'),
			'parent_slug' => 'options-general.php',
		));
	}
}