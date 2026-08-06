<?php
/**
 * Astra Child Theme functions and definitions
 *
 * @link https://developer.wordpress.org/themes/basics/theme-functions/
 *
 * @package Astra Child
 * @since 1.0.0
 */

/**
 * Define Constants
 */
define( 'VERSION', wp_get_theme()->get( 'Version' ) );
define( 'TEXT_DOMAIN', 'mgs' );

/**
 * Enqueue styles
 */
function child_enqueue_styles() {
	wp_enqueue_style( 'child-theme-css', get_stylesheet_directory_uri() . '/style.css', array('astra-theme-css'), VERSION, 'all' );
}
add_action( 'wp_enqueue_scripts', 'child_enqueue_styles', 15 );

/** Optimization And Customization */
require_once 'inc/optimization/front-end.php';

/** ACF - Advanced Custom Fields */
require_once 'inc/custom-fields/remove-acf-menu.php';
require_once 'inc/custom-fields/local-json.php';
require_once 'inc/custom-fields/set-localization.php';

/** theme general options */
require_once 'inc/theme-options/theme-options.php';

/** theme hooks */
require 'inc/hooks.php';

/** custom post types */
include_once 'inc/post-types/disable-editor-block.php';