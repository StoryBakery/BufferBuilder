--[[
	Custom/Type 직렬화 테스트 모듈입니다.
]]

local Assertions = require("../helpers/Assertions")
local BufferBuilder = require("../../src")

type Vector3Value = {
	x: number,
	y: number,
	z: number,
}

local function writeVector3(buf: buffer, offset: number, value: Vector3Value)
	buffer.writef32(buf, offset, value.x)
	buffer.writef32(buf, offset + 4, value.y)
	buffer.writef32(buf, offset + 8, value.z)
end

local function readVector3(buf: buffer, offset: number): Vector3Value
	return {
		x = buffer.readf32(buf, offset),
		y = buffer.readf32(buf, offset + 4),
		z = buffer.readf32(buf, offset + 8),
	}
end

local function getVector3Size(_value: Vector3Value): number
	return 12
end

local function testSupportsCustomPayloads()
	local builder = BufferBuilder.new()
	local vector3 = {
		x = 1.1,
		y = 2.2,
		z = 3.3,
	}

	builder:WriteCustom(writeVector3, getVector3Size(vector3), vector3)

	local builtBuffer = builder:Build()
	local decoded = readVector3(builtBuffer, 0)

	Assertions.ExpectClose(decoded.x, vector3.x, 5, "supports custom payloads")
	Assertions.ExpectClose(decoded.y, vector3.y, 5, "supports custom payloads")
	Assertions.ExpectClose(decoded.z, vector3.z, 5, "supports custom payloads")
end

local function testSupportsTypePayloads()
	local builder = BufferBuilder.new()
	local typeInfo = {
		Serialize = function(buf: buffer, offset: number, value: number)
			buffer.writeu16(buf, offset, value)
		end,
		Deserialize = function(buf: buffer, offset: number): number
			return buffer.readu16(buf, offset)
		end,
		GetSize = function(_value: number): number
			return 2
		end,
	}

	builder:WriteType(typeInfo, 513)

	local builtBuffer = builder:Build()
	local decoded = typeInfo.Deserialize(builtBuffer, 0)

	Assertions.ExpectEqual(decoded, 513, "supports type payloads")
end

local function testAlignsCustomAndTypeWithBits()
	local builder = BufferBuilder.new()
	local typeInfo = {
		Serialize = function(buf: buffer, offset: number, value: number)
			buffer.writeu16(buf, offset, value)
		end,
		Deserialize = function(buf: buffer, offset: number): number
			return buffer.readu16(buf, offset)
		end,
		GetSize = function(_value: number): number
			return 2
		end,
	}

	builder:WriteBits(3, 0x5)
	builder:WriteCustom(function(buf: buffer, offset: number, value: string)
		buffer.writestring(buf, offset, value)
	end, 2, "OK")
	builder:WriteBit(1)
	builder:WriteType(typeInfo, 0x2345)

	local builtBuffer = builder:Build()

	Assertions.ExpectEqual(
		buffer.readbits(builtBuffer, 0, 3),
		0x5,
		"aligns custom and type with bits"
	)
	Assertions.ExpectEqual(
		buffer.readstring(builtBuffer, 1, 2),
		"OK",
		"aligns custom and type with bits"
	)
	Assertions.ExpectEqual(
		buffer.readbits(builtBuffer, 24, 1),
		1,
		"aligns custom and type with bits"
	)
	Assertions.ExpectEqual(
		typeInfo.Deserialize(builtBuffer, 4),
		0x2345,
		"aligns custom and type with bits"
	)
end

return {
	{
		Name = "supports custom payloads",
		Callback = testSupportsCustomPayloads,
	},
	{
		Name = "supports type payloads",
		Callback = testSupportsTypePayloads,
	},
	{
		Name = "aligns custom and type with bits",
		Callback = testAlignsCustomAndTypeWithBits,
	},
}
