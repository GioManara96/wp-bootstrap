<?php
/**
 * Clean up WordPress defaults
 *
 * @package Astra Child
 * @since 1.0.0
 */

add_action( 'after_setup_theme', 'mgs_start_cleanup' );
function mgs_start_cleanup() {
  // Launching operation cleanup.
  add_action( 'init', 'mgs_cleanup_head' );
  // Remove WP version from RSS.
  add_filter( 'the_generator', 'mgs_remove_rss_version' );
  // Remove pesky injected css for recent comments widget.
  add_filter( 'wp_head', 'mgs_remove_wp_widget_recent_comments_style', 1 );
  // Clean up comment styles in the head.
  add_action( 'wp_head', 'mgs_remove_recent_comments_style', 1 );
}

// clean up head
function mgs_cleanup_head() {
  // EditURI link.
  remove_action( 'wp_head', 'rsd_link' );
  // Category feed links.
  remove_action( 'wp_head', 'feed_links_extra', 3 );
  // Post and comment feed links.
  remove_action( 'wp_head', 'feed_links', 2 );
  // Windows Live Writer.
  remove_action( 'wp_head', 'wlwmanifest_link' );
  // Index link.
  remove_action( 'wp_head', 'index_rel_link' );
  // Previous link.
  remove_action( 'wp_head', 'parent_post_rel_link', 10 );
  // Start link.
  remove_action( 'wp_head', 'start_post_rel_link', 10 );
  // Canonical.
  remove_action( 'wp_head', 'rel_canonical', 10 );
  // Shortlink.
  remove_action( 'wp_head', 'wp_shortlink_wp_head', 10 );
  // Links for adjacent posts.
  remove_action( 'wp_head', 'adjacent_posts_rel_link_wp_head', 10 );
  // WP version.
  remove_action( 'wp_head', 'wp_generator' );
  // Emoji detection script.
  remove_action( 'wp_head', 'print_emoji_detection_script', 7 );
  remove_action( 'admin_print_scripts', 'print_emoji_detection_script' );
  // Emoji styles.
  remove_action( 'wp_print_styles', 'print_emoji_styles' );
  remove_action( 'admin_print_styles', 'print_emoji_styles' );

}
// Remove WP version from RSS.
function mgs_remove_rss_version() {
  return '';
}

// Remove injected CSS for recent comments widget.
function mgs_remove_wp_widget_recent_comments_style() {
  if ( has_filter( 'wp_head', 'wp_widget_recent_comments_style' ) ) {
    remove_filter( 'wp_head', 'wp_widget_recent_comments_style' );
  }
}

// Remove injected CSS from recent comments widget.
function mgs_remove_recent_comments_style() {
  global $wp_widget_factory;
  if ( isset( $wp_widget_factory->widgets['WP_Widget_Recent_Comments'] ) ) {
    remove_action( 'wp_head', array( $wp_widget_factory->widgets['WP_Widget_Recent_Comments'], 'recent_comments_style' ) );
  }
}

/**
 * add contact form 7 style css e js only in page with shortcode CF7
 */
function mgs_theme_contactform_css_js() {
  global $post;
  if( is_a( $post, 'WP_Post' ) && has_shortcode( $post->post_content, 'contact-form-7' ) ) :
    wp_enqueue_script( 'contact-form-7' );
    wp_enqueue_style( 'contact-form-7' );
  else:
    wp_dequeue_script( 'contact-form-7' );
    wp_dequeue_style( 'contact-form-7' );
  endif;
}
add_action( 'wp_enqueue_scripts', 'mgs_theme_contactform_css_js' );

/**
 * Remove api.w.org relation link
 */
remove_action( 'wp_head', 'rest_output_link_wp_head', 10 );
remove_action( 'wp_head', 'wp_oembed_add_discovery_links', 10 );
remove_action( 'template_redirect', 'rest_output_link_header', 11 );

/**
 * Remove query strings from all static resources
 */
function mgs_theme_cleanup_query_string( $src ){
  $parts = explode( '?ver', $src );
  return $parts[0];
}
add_filter( 'script_loader_src', 'mgs_theme_cleanup_query_string', 15, 1 );
add_filter( 'style_loader_src', 'mgs_theme_cleanup_query_string', 15, 1 );

/**
 * remove WP 4.9+ dns-prefetch nonsense
 */
remove_action( 'wp_head', 'wp_resource_hints', 2 );

/**
 * remove WP embed.js
 */
function mgs_theme_deregister_scripts(){
  wp_deregister_script( 'wp-embed' );
}
add_action( 'wp_footer', 'mgs_theme_deregister_scripts' );

/**
 * REMOVE WP VERSION
 */
function remove_wordpress_version() { return ''; }
add_filter( 'the_generator', 'remove_wordpress_version' );