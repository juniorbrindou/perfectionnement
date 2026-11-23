@tool
extends EditorPlugin
## Ajoute le greffon Android « GoogleSignIn » (android_plugin/, compilé dans bin/) et ses
## dépendances à l'APK. Demande l'export Android avec build Gradle.

var _export: AndroidExport


func _enter_tree() -> void:
	_export = AndroidExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class AndroidExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "GoogleSignIn"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["google_sign_in/bin/GoogleSignIn.aar"])

	## Mêmes versions que android_plugin/build.gradle.
	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([
			"androidx.credentials:credentials:1.6.0",
			"androidx.credentials:credentials-play-services-auth:1.6.0",
			"com.google.android.libraries.identity.googleid:googleid:1.2.0",
		])
