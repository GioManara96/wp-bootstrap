const gulp           = require('gulp');
const gulpIf         = require('gulp-if');
const browserSync    = require('browser-sync').create();
const sass           = require('gulp-sass')(require('sass'));
const htmlmin        = require('gulp-htmlmin');
const cssmin         = require('gulp-cssmin');
const terser         = require('gulp-terser');
const imagemin       = require('gulp-imagemin');
const concat         = require('gulp-concat');
const jsImport       = require('gulp-js-import');
const sourcemaps     = require('gulp-sourcemaps');
const htmlPartial    = require('gulp-html-partial');
const clean          = require('gulp-clean');
const cssbeautify    = require('gulp-cssbeautify');
const htmlbeautify   = require('gulp-html-beautify');
const isProd         = process.env.NODE_ENV === 'prod';

var options = { };

/** enviroments constants */
const proxy_url  = 'local-domain-name';
			theme_name = 'theme-name';

function style() {
	return gulp.src('assets/sass/style.scss')
		.pipe(gulpIf(!isProd, sourcemaps.init()))
		.pipe(sass({
			includePaths: ['node_modules']
		}).on('error', sass.logError))
		.pipe(cssbeautify({
			indent: '	',
			openbrace: 'end-of-line',
			autosemicolon: true
		}))
		.pipe(gulpIf(!isProd, sourcemaps.write()))
		.pipe(gulpIf(isProd, cssmin()))
		.pipe(gulp.dest('../wp-content/themes/' + theme_name))
		.pipe(browserSync.reload({ stream: true }));
}

function js() {
	return gulp.src('assets/js/*.js')
		.pipe(jsImport({
			hideConsole: true
		}))
		.pipe(concat('theme.js'))
		.pipe(gulpIf(isProd, terser()))
		.pipe(gulp.dest('../wp-content/themes/'+theme_name+'/assets/js'));
}

function img() {
	return gulp.src('assets/img/*')
		.pipe(gulpIf(isProd, imagemin()))
		.pipe(gulp.dest('../wp-content/themes/' + theme_name + '/assets/img/'));
}

function serve(done) {
	browserSync.init({
		proxy: proxy_url,
		ui: {
			port: 8080
		},
	});
	done();
}

function browserSyncReload(done) {
	browserSync.reload();
	done();
}


function watchFiles() {
	gulp.watch('../wp-content/themes/' + theme_name + '/**/*.php', gulp.series(browserSyncReload));
	gulp.watch('../wp-content/themes/' + theme_name + '/**/*.js', gulp.series(browserSyncReload));
	gulp.watch('./assets/sass/**/*.scss', gulp.series(style));
	gulp.watch('./assets/js/**/*.js', gulp.series(browserSyncReload, js));
	gulp.watch('./assets/img/**/*.*', gulp.series(img));

	return;
}

// function del() {
// 	return gulp.src('../wp-content/themes/' + theme_name + '/assets/**/*', {read: false})
// 		.pipe(clean({force:true}));
// }

exports.style   = style;
exports.js      = js;
exports.serve   = gulp.parallel(style, js, img, watchFiles, serve);
exports.default = gulp.series(style, js, img);

// exports.del                 = del;
// exports.serve = gulp.parallel(style, js, img, watchFiles, serve);
// exports.default = gulp.series(del, style, js, img);