<?php
add_filter('acf/settings/l10n', 'mgs_acf_settings_localization');
function mgs_acf_settings_localization($localization){
	return true;
}

add_filter('acf/settings/l10n_textdomain', 'mgs_acf_settings_textdomain');
function mgs_acf_settings_textdomain($domain){
	return TEXT_DOMAIN;
}