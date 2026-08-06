<?php


add_filter('use_block_editor_for_post_type', 'disable_editor_block', 10, 2);

function disable_editor_block($use_block_editor, $post_type) {
  $disable_block_editor_post_types = [];

  if (in_array($post_type, $disable_block_editor_post_types, true)) {
    return false;
  }

  return $use_block_editor;
}
