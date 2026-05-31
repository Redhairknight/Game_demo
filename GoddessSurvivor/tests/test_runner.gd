## 轻量级测试运行器
## 用于 Nikki Survivors 项目的单元测试框架
## 使用方法：将此脚本附加到一个Node场景，运行场景即可执行所有测试
extends Node

class_name TestRunner

# ========== 统计 ==========
var _total_tests: int = 0
var _passed_tests: int = 0
var _failed_tests: int = 0
var _current_test_name: String = ""
var _test_suites: Array[Node] = []
var _suite_results: Dictionary = {}  # suite_name -> {passed, failed, errors}

# ========== 颜色常量（用于编辑器输出） ==========
const COLOR_PASS = "green"
const COLOR_FAIL = "red"
const COLOR_INFO = "cyan"
const COLOR_WARN = "yellow"

# ========== 生命周期 ==========
func _ready() -> void:
	print("")
	print("╔══════════════════════════════════════════════════╗")
	print("║     Nikki Survivors - Test Runner v1.0          ║")
	print("╚══════════════════════════════════════════════════╝")
	print("")

	# 自动发现子节点中的测试套件
	_discover_test_suites()

	# 运行所有测试
	run_all()

	# 打印总结
	_print_summary()


# ========== 测试发现 ==========
func _discover_test_suites() -> void:
	for child in get_children():
		if child.has_method("get_test_methods"):
			_test_suites.append(child)
		else:
			# 自动发现以 test_ 开头的方法
			_test_suites.append(child)


# ========== 运行测试 ==========
func run_all() -> void:
	for suite in _test_suites:
		_run_suite(suite)


func _run_suite(suite: Node) -> void:
	var suite_name = suite.get_script().resource_path.get_file() if suite.get_script() else suite.name
	var suite_passed: int = 0
	var suite_failed: int = 0
	var errors: Array[String] = []

	print("┌─────────────────────────────────────────────────")
	print("│ Suite: %s" % suite_name)
	print("├─────────────────────────────────────────────────")

	# 获取所有 test_ 方法
	var methods: Array[String] = []
	if suite.has_method("get_test_methods"):
		methods = suite.call("get_test_methods")
	else:
		# 通过脚本反射获取方法列表
		var script = suite.get_script()
		if script:
			for method in script.get_script_method_list():
				if method["name"].begins_with("test_"):
					methods.append(method["name"])

	# 执行 setup（如果存在）
	if suite.has_method("before_all"):
		suite.call("before_all")

	for method_name in methods:
		# 执行 before_each（如果存在）
		if suite.has_method("before_each"):
			suite.call("before_each")

		_current_test_name = method_name
		_total_tests += 1

		var test_passed = true
		# 执行测试方法
		if suite.has_method(method_name):
			var result = suite.call(method_name)
			# 如果方法返回 false 表示失败
			if result is bool and result == false:
				test_passed = false

		# 检查套件是否记录了失败
		if suite.has_method("_get_last_assertion_failed"):
			if suite.call("_get_last_assertion_failed"):
				test_passed = false

		if test_passed:
			suite_passed += 1
			_passed_tests += 1
			print("│  ✓ %s" % method_name)
		else:
			suite_failed += 1
			_failed_tests += 1
			print("│  ✗ %s [FAILED]" % method_name)

		# 执行 after_each（如果存在）
		if suite.has_method("after_each"):
			suite.call("after_each")

	# 执行 teardown（如果存在）
	if suite.has_method("after_all"):
		suite.call("after_all")

	print("│  Result: %d passed, %d failed" % [suite_passed, suite_failed])
	print("└─────────────────────────────────────────────────")
	print("")

	_suite_results[suite_name] = {
		"passed": suite_passed,
		"failed": suite_failed,
		"errors": errors
	}


# ========== 总结输出 ==========
func _print_summary() -> void:
	print("")
	print("══════════════════════════════════════════════════")
	print("  TOTAL RESULTS")
	print("══════════════════════════════════════════════════")
	print("  Total Tests:  %d" % _total_tests)
	print("  Passed:       %d ✓" % _passed_tests)
	print("  Failed:       %d ✗" % _failed_tests)

	if _total_tests > 0:
		var pass_rate = float(_passed_tests) / float(_total_tests) * 100.0
		print("  Pass Rate:    %.1f%%" % pass_rate)

		if _failed_tests == 0:
			print("")
			print("  ★ ALL TESTS PASSED! ★")
		else:
			print("")
			print("  ⚠ SOME TESTS FAILED!")
	else:
		print("  No tests found.")

	print("══════════════════════════════════════════════════")
	print("")


# ========== 断言方法（供测试套件使用的静态辅助） ==========
# 注意：测试套件应继承 TestSuite 基类来使用这些断言


## 测试套件基类 - 所有测试文件应继承此类
class TestSuite extends Node:
	var _assertion_failed: bool = false
	var _assertion_errors: Array[String] = []

	func _get_last_assertion_failed() -> bool:
		var result = _assertion_failed
		_assertion_failed = false
		return result

	## 断言两个值相等
	func assert_eq(actual, expected, message: String = "") -> bool:
		if actual != expected:
			var msg = "assert_eq FAILED: expected '%s' but got '%s'" % [str(expected), str(actual)]
			if message != "":
				msg += " | " + message
			_fail(msg)
			return false
		return true

	## 断言条件为真
	func assert_true(condition: bool, message: String = "") -> bool:
		if not condition:
			var msg = "assert_true FAILED: condition is false"
			if message != "":
				msg += " | " + message
			_fail(msg)
			return false
		return true

	## 断言条件为假
	func assert_false(condition: bool, message: String = "") -> bool:
		if condition:
			var msg = "assert_false FAILED: condition is true"
			if message != "":
				msg += " | " + message
			_fail(msg)
			return false
		return true

	## 断言浮点数近似相等（默认精度0.01）
	func assert_near(actual: float, expected: float, tolerance: float = 0.01, message: String = "") -> bool:
		if abs(actual - expected) > tolerance:
			var msg = "assert_near FAILED: expected ~%.4f but got %.4f (tolerance: %.4f)" % [expected, actual, tolerance]
			if message != "":
				msg += " | " + message
			_fail(msg)
			return false
		return true

	## 断言值大于
	func assert_gt(actual, expected, message: String = "") -> bool:
		if actual <= expected:
			var msg = "assert_gt FAILED: expected '%s' > '%s'" % [str(actual), str(expected)]
			if message != "":
				msg += " | " + message
			_fail(msg)
			return false
		return true

	## 断言值小于
	func assert_lt(actual, expected, message: String = "") -> bool:
		if actual >= expected:
			var msg = "assert_lt FAILED: expected '%s' < '%s'" % [str(actual), str(expected)]
			if message != "":
				msg += " | " + message
			_fail(msg)
			return false
		return true

	## 断言值大于等于
	func assert_gte(actual, expected, message: String = "") -> bool:
		if actual < expected:
			var msg = "assert_gte FAILED: expected '%s' >= '%s'" % [str(actual), str(expected)]
			if message != "":
				msg += " | " + message
			_fail(msg)
			return false
		return true

	## 断言值小于等于
	func assert_lte(actual, expected, message: String = "") -> bool:
		if actual > expected:
			var msg = "assert_lte FAILED: expected '%s' <= '%s'" % [str(actual), str(expected)]
			if message != "":
				msg += " | " + message
			_fail(msg)
			return false
		return true

	## 断言值不为null
	func assert_not_null(value, message: String = "") -> bool:
		if value == null:
			var msg = "assert_not_null FAILED: value is null"
			if message != "":
				msg += " | " + message
			_fail(msg)
			return false
		return true

	## 断言值为null
	func assert_null(value, message: String = "") -> bool:
		if value != null:
			var msg = "assert_null FAILED: value is '%s', expected null" % str(value)
			if message != "":
				msg += " | " + message
			_fail(msg)
			return false
		return true

	## 断言值在范围内
	func assert_in_range(value: float, min_val: float, max_val: float, message: String = "") -> bool:
		if value < min_val or value > max_val:
			var msg = "assert_in_range FAILED: %.4f not in [%.4f, %.4f]" % [value, min_val, max_val]
			if message != "":
				msg += " | " + message
			_fail(msg)
			return false
		return true

	## 内部失败处理
	func _fail(msg: String) -> void:
		_assertion_failed = true
		_assertion_errors.append(msg)
		print("│      ↳ " + msg)

	## 获取测试方法列表（自动反射）
	func get_test_methods() -> Array[String]:
		var methods: Array[String] = []
		var script = get_script()
		if script:
			for method in script.get_script_method_list():
				if method["name"].begins_with("test_"):
					methods.append(method["name"])
		return methods
