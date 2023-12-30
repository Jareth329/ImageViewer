extends Node

signal update_counter(value:int, max_value:int)
signal update_visibility_ui

class SortNatural:
	static var regex_num:RegEx = RegEx.create_from_string("([0-9]+)")
	
	static func compare(a:String, b:String) -> bool:
		if not a.is_valid_int() or not b.is_valid_int():
			return a < b
		return a.to_int() < b.to_int()
	
	static func split(string:String, matches:Array[RegExMatch]) -> Array[String]:
		var arr:Array[String] = []
		var start:int = 0
		for mat:RegExMatch in matches:
			if start < mat.get_start(): # string first
				arr.append(string.substr(start, mat.get_start() - start))
			arr.append(mat.get_string())
			start = mat.get_end()
		return arr
	
	static func sort(a:String, b:String) -> bool:
		if a == b: return false
		var a1:Array[RegExMatch] = regex_num.search_all(a)
		var b1:Array[RegExMatch] = regex_num.search_all(b)
		if a1.is_empty() or b1.is_empty(): return a < b
		
		var a2:Array[String] = split(a, a1)
		var b2:Array[String] = split(b, b1)
		
		for i:int in min(a2.size(), b2.size()):
			if a2[i] != b2[i]:
				return compare(a2[i], b2[i])

		if len(b1) > len(a1): 
			return true
		return false

