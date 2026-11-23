extends SceneTree
## Lance les tests : godot --headless --path . --script res://tests/run_tests.gd
## Argument optionnel après "--" : nom d'un fichier de test (ex. -- test_duel).

const TEST_DIR := "res://tests/"


func _initialize() -> void:
	var only := ""
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		only = args[0]
	var total := 0
	var failed := 0
	for file in DirAccess.get_files_at(TEST_DIR):
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		if not only.is_empty() and not file.begins_with(only):
			continue
		var script: GDScript = load(TEST_DIR + file)
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			var case: TestCase = script.new()
			case._current = "%s::%s" % [file.get_basename(), name]
			case.call(name)
			total += 1
			if case.failures.is_empty():
				print("  ok   ", case._current)
			else:
				failed += 1
				for f in case.failures:
					print("  ÉCHEC ", f)
	print("\n%d tests, %d échec(s)" % [total, failed])
	quit(1 if failed > 0 else 0)
