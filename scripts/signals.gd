extends Node

signal update_counter(value, max_value)
signal update_visibility_ui

class SortNatural:
	static var table:Dictionary = {} # string : RegExMatch[]
	static var regex_num:RegEx = RegEx.create_from_string("([0-9]+)")
	
	static func part_compare(a:String, b:String) -> bool:
		if not a.is_valid_int() or not b.is_valid_int():
			return a < b
		return a.to_int() < b.to_int()
	
	static func sort_natural(a:String, b:String) -> bool:
		if a == b: return false
		var a1:Array
		var b1:Array
		
		if table.has(a): a1 = table[a]
		else:
			a1 = regex_num.search_all(a)
			table[a] = a1
		if table.has(b): b1 = table[b]
		else:
			b1 = regex_num.search_all(b)
			table[b] = b1
		
		for i in min(len(a1), len(b1)):
			if a1[i].get_string() != b1[i].get_string():
				return part_compare(a1[i].get_string(), b1[i].get_string())
		
		if len(b1) > len(a1): 
			return true
		return false

