--[[
	비트 및 바이트 정렬 테스트 모듈입니다.
]]

local Assertions = require("../helpers/Assertions")
local BufferBuilder = require("../../src")

local function testWritesAndReadsBitsInOrder()
	local builder = BufferBuilder.new()

	builder:WriteBit(1)
	builder:WriteBits(4, 0xF)
	builder:WriteBit(0)
	builder:WriteBits(2, 0x2)
	builder:WriteBit(0)
	builder:WriteBits(7, 0x55)
	builder:WriteBit(1)
	builder:WriteBits(8, 0xAA)

	local builtBuffer = builder:Build()
	local bitCursor = 0

	local function readBits(bitCount: number): number
		local value = buffer.readbits(builtBuffer, bitCursor, bitCount)
		bitCursor += bitCount
		return value
	end

	local function readBit(): number
		return readBits(1)
	end

	Assertions.ExpectEqual(readBit(), 1, "writes and reads bits in order")
	Assertions.ExpectEqual(readBits(4), 0xF, "writes and reads bits in order")
	Assertions.ExpectEqual(readBit(), 0, "writes and reads bits in order")
	Assertions.ExpectEqual(readBits(2), 0x2, "writes and reads bits in order")
	Assertions.ExpectEqual(readBit(), 0, "writes and reads bits in order")
	Assertions.ExpectEqual(readBits(7), 0x55, "writes and reads bits in order")
	Assertions.ExpectEqual(readBit(), 1, "writes and reads bits in order")
	Assertions.ExpectEqual(readBits(8), 0xAA, "writes and reads bits in order")
end

local function testAlignsBitsAndBytes()
	local builder = BufferBuilder.new()

	builder:WriteBit(1)
	builder:WriteBit(0)
	builder:WriteU16(0xABCD)
	builder:WriteBits(6, 0x2D)
	builder:WriteU8(0x7F)

	local builtBuffer = builder:Build()

	Assertions.ExpectEqual(buffer.readbits(builtBuffer, 0, 1), 1, "aligns bits and bytes")
	Assertions.ExpectEqual(buffer.readbits(builtBuffer, 1, 1), 0, "aligns bits and bytes")
	Assertions.ExpectEqual(buffer.readu16(builtBuffer, 1), 0xABCD, "aligns bits and bytes")
	Assertions.ExpectEqual(buffer.readbits(builtBuffer, 24, 6), 0x2D, "aligns bits and bytes")
	Assertions.ExpectEqual(buffer.readu8(builtBuffer, 4), 0x7F, "aligns bits and bytes")
end

local function testHandlesBitBoundaryWithScalarWrites()
	local builder = BufferBuilder.new()

	builder:WriteBits(5, 0x12)
	builder:WriteU8(0x5A)
	builder:WriteBits(4, 0xA)
	builder:WriteU16(0x789A)

	local builtBuffer = builder:Build()

	Assertions.ExpectEqual(
		buffer.readbits(builtBuffer, 0, 5),
		0x12,
		"handles bit boundary with scalar writes"
	)
	Assertions.ExpectEqual(
		buffer.readu8(builtBuffer, 1),
		0x5A,
		"handles bit boundary with scalar writes"
	)
	Assertions.ExpectEqual(
		buffer.readbits(builtBuffer, 16, 4),
		0xA,
		"handles bit boundary with scalar writes"
	)
	Assertions.ExpectEqual(
		buffer.readu16(builtBuffer, 3),
		0x789A,
		"handles bit boundary with scalar writes"
	)
end

return {
	{
		Name = "writes and reads bits in order",
		Callback = testWritesAndReadsBitsInOrder,
	},
	{
		Name = "aligns bits and bytes",
		Callback = testAlignsBitsAndBytes,
	},
	{
		Name = "handles bit boundary with scalar writes",
		Callback = testHandlesBitBoundaryWithScalarWrites,
	},
}
