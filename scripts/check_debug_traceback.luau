--[[
	TRACE_BACK 경로의 디버깅 에러 메시지 구성을 검증하는 스크립트입니다.
]]

local process = require("@lune/process")

_G.game = {
	GetService = function(_, serviceName)
		if serviceName == "RunService" then
			return {
				IsStudio = function()
					return true
				end,
			}
		end

		error(`unexpected service: {serviceName}`)
	end,
}

local BufferBuilder = require("../src")
local builder = BufferBuilder.new()

builder:WriteU8(0x12)
builder:WriteCustom(function(_buf, _offset, _value)
	error("INTENTIONAL_DEBUG_ERROR")
end, 1, 123)

local ok, err = pcall(function()
	builder:Build()
end)

if ok then
	print("FAIL debug traceback check: Build() should throw an error")
	process.exit(1)
end

local errorText = tostring(err)
local requiredPatterns = {
	"Error occurred while building BufferBuilder from the inserted operation:",
	"WriteCustom",
	"INTENTIONAL_DEBUG_ERROR",
}

print("Error Text:", errorText)
for _, pattern in requiredPatterns do
	if string.find(errorText, pattern, 1, true) == nil then
		print(`FAIL debug traceback check: missing "{pattern}"`)
		process.exit(1)
	end
end

print("PASS debug traceback check")

return nil
