--[[
	테스트 스펙 실행 모듈입니다.
]]

local BitsAndAlignmentSpec = require("@self/BitsAndAlignmentSpec")
local CursorSpec = require("@self/CursorSpec")
local CustomAndTypeSpec = require("@self/CustomAndTypeSpec")
local ScalarValuesSpec = require("@self/ScalarValuesSpec")

local function runSpec(testCases)
	for _, testCase in testCases do
		testCase.Callback()
		print(`PASS {testCase.Name}`)
	end
end

runSpec(ScalarValuesSpec)
runSpec(BitsAndAlignmentSpec)
runSpec(CursorSpec)
runSpec(CustomAndTypeSpec)

print("All tests passed.")

return nil
