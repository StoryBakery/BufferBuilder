--[[
	정수/실수/문자열 및 bool 헬퍼 테스트 모듈입니다.
]]

local Assertions = require("../helpers/Assertions")
local BufferBuilder = require("../../src")

local function testWritesAndReadsScalarValues()
	local builder = BufferBuilder.new()

	builder:WriteI8(-12)
	builder:WriteI16(-1_234)
	builder:WriteI32(-123_456_789)
	builder:WriteU8(255)
	builder:WriteU16(12_345)
	builder:WriteU32(3_000_000_000)
	builder:WriteF32(3.14)
	builder:WriteF64(2.71828)
	builder:WriteString("Hello Buffer")

	local builtBuffer = builder:Build()
	local offset = 0

	Assertions.ExpectEqual(
		buffer.readi8(builtBuffer, offset),
		-12,
		"writes and reads scalar values"
	)
	offset += 1
	Assertions.ExpectEqual(
		buffer.readi16(builtBuffer, offset),
		-1_234,
		"writes and reads scalar values"
	)
	offset += 2
	Assertions.ExpectEqual(
		buffer.readi32(builtBuffer, offset),
		-123_456_789,
		"writes and reads scalar values"
	)
	offset += 4
	Assertions.ExpectEqual(
		buffer.readu8(builtBuffer, offset),
		255,
		"writes and reads scalar values"
	)
	offset += 1
	Assertions.ExpectEqual(
		buffer.readu16(builtBuffer, offset),
		12_345,
		"writes and reads scalar values"
	)
	offset += 2
	Assertions.ExpectEqual(
		buffer.readu32(builtBuffer, offset),
		3_000_000_000,
		"writes and reads scalar values"
	)
	offset += 4
	Assertions.ExpectClose(
		buffer.readf32(builtBuffer, offset),
		3.14,
		5,
		"writes and reads scalar values"
	)
	offset += 4
	Assertions.ExpectClose(
		buffer.readf64(builtBuffer, offset),
		2.71828,
		5,
		"writes and reads scalar values"
	)
	offset += 8
	Assertions.ExpectEqual(
		buffer.readstring(builtBuffer, offset, 12),
		"Hello Buffer",
		"writes and reads scalar values"
	)
end

local function testWritesAndReadsBoolHelpers()
	local builder = BufferBuilder.new()

	builder:WriteBoolBit(true)
	builder:WriteBoolBit(false)
	builder:WriteBool(true)
	builder:WriteBool(false)

	local builtBuffer = builder:Build()

	Assertions.ExpectEqual(
		buffer.readbits(builtBuffer, 0, 1) == 1,
		true,
		"writes and reads bool helpers"
	)
	Assertions.ExpectEqual(
		buffer.readbits(builtBuffer, 1, 1) == 1,
		false,
		"writes and reads bool helpers"
	)
	Assertions.ExpectEqual(
		buffer.readu8(builtBuffer, 1) ~= 0,
		true,
		"writes and reads bool helpers"
	)
	Assertions.ExpectEqual(
		buffer.readu8(builtBuffer, 2) ~= 0,
		false,
		"writes and reads bool helpers"
	)
end

return {
	{
		Name = "writes and reads scalar values",
		Callback = testWritesAndReadsScalarValues,
	},
	{
		Name = "writes and reads bool helpers",
		Callback = testWritesAndReadsBoolHelpers,
	},
}
