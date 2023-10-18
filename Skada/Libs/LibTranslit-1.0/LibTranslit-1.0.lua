--[[
Copyright (C) 2019-2022 Vardex
This file is part of LibTranslit.
LibTranslit is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
LibTranslit is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.
You should have received a copy of the GNU Lesser General Public License along with LibTranslit. If not, see <https://www.gnu.org/licenses/>. 
--]]
local MAJOR, MINOR = "LibTranslit-1.0", 4
if not LibStub then
	error(("%s requires LibStub."):format(MAJOR))
end

local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

local strlen = strlen or string.len
local strsub = strsub or string.sub
local strbyte = strbyte or string.byte
local strchar = strchar or string.char
local format = format or string.format

local cyrToLat = {
	["А"] = "A",
	["а"] = "a",
	["Б"] = "B",
	["б"] = "b",
	["В"] = "V",
	["в"] = "v",
	["Г"] = "G",
	["г"] = "g",
	["Д"] = "D",
	["д"] = "d",
	["Е"] = "E",
	["е"] = "e",
	["Ё"] = "e",
	["ё"] = "e",
	["Ж"] = "Zh",
	["ж"] = "zh",
	["З"] = "Z",
	["з"] = "z",
	["И"] = "I",
	["и"] = "i",
	["Й"] = "Y",
	["й"] = "y",
	["К"] = "K",
	["к"] = "k",
	["Л"] = "L",
	["л"] = "l",
	["М"] = "M",
	["м"] = "m",
	["Н"] = "N",
	["н"] = "n",
	["О"] = "O",
	["о"] = "o",
	["П"] = "P",
	["п"] = "p",
	["Р"] = "R",
	["р"] = "r",
	["С"] = "S",
	["с"] = "s",
	["Т"] = "T",
	["т"] = "t",
	["У"] = "U",
	["у"] = "u",
	["Ф"] = "F",
	["ф"] = "f",
	["Х"] = "Kh",
	["х"] = "kh",
	["Ц"] = "Ts",
	["ц"] = "ts",
	["Ч"] = "Ch",
	["ч"] = "ch",
	["Ш"] = "Sh",
	["ш"] = "sh",
	["Щ"] = "Shch",
	["щ"] = "shch",
	["Ъ"] = "",
	["ъ"] = "",
	["Ы"] = "Y",
	["ы"] = "y",
	["Ь"] = "",
	["ь"] = "",
	["Э"] = "E",
	["э"] = "e",
	["Ю"] = "Yu",
	["ю"] = "yu",
	["Я"] = "Ya",
	["я"] = "ya"
}

function lib:Transliterate(str, mark)
	if not str then return "" end

	mark = mark or ""
	local tstr = ""
	local tword = ""
	local mark_word = false
	local i = 1

	while i <= strlen(str) do
		local c = strsub(str, i, i)
		local b = strbyte(c)

		if b == 208 or b == 209 then
			mark_word = true
			c = strsub(str, i + 1, i + 1)
			tword = format("%s%s", tword, (cyrToLat[strchar(b, strbyte(c))] or strchar(b, strbyte(c))))

			i = i + 2
		else
			tword = format("%s%s", tword, c)

			if c == " " or c == "-" then
				tstr = format("%s%s", tstr, (mark_word and format("%s%s", mark, tword) or tword))
				tword = ""
				mark_word = false
			end

			i = i + 1
		end
	end

	return format("%s%s", tstr, (mark_word and format("%s%s", mark, tword) or tword))
end
