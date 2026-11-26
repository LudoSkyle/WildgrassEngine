extends GdUnitTestSuite

const C := WgExperience.Growth


func test_each_curve_at_level_100() -> void:
	var at_100: Array[int] = []
	for curve: int in [C.FAST, C.NORMAL, C.SLOW, C.PARABOLIC, C.ERRATIC, C.FLUCTUATING]:
		at_100.append(WgExperience.total(curve, 100))
	assert_array(at_100).is_equal([800000, 1000000, 1250000, 1059860, 600000, 1640000])


func test_the_parabolic_curve_starts_at_1_then_follows_its_formula() -> void:
	assert_int(WgExperience.total(C.PARABOLIC, 1)).is_equal(1)
	assert_int(WgExperience.total(C.PARABOLIC, 2)).is_equal(9)


func test_the_erratic_curve_changes_formula_at_50_68_98_and_100() -> void:
	var levels: Array[int] = [50, 51, 68, 69, 70, 99, 101]
	assert_array(levels.map(func(level: int) -> int: return WgExperience.total(C.ERRATIC, level))).is_equal([125000, 131324, 257834, 267406, 276458, 591882, 730124])


func test_the_fluctuating_curve_changes_formula_at_15_and_35() -> void:
	var levels: Array[int] = [15, 16, 35, 36]
	assert_array(levels.map(func(level: int) -> int: return WgExperience.total(C.FLUCTUATING, level))).is_equal([1957, 2457, 42017, 46656])


func test_divisions_round_down_at_each_step() -> void:
	assert_int(WgExperience.total(C.FAST, 2)).is_equal(6)
	assert_int(WgExperience.total(C.SLOW, 3)).is_equal(33)


func test_an_unknown_curve_counts_as_normal() -> void:
	assert_int(WgExperience.total(9, 5)).is_equal(125)
	assert_int(WgExperience.total(-1, 5)).is_equal(125)
