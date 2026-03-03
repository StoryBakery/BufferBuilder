--[[
	커서 이동 및 복구 테스트 모듈입니다.
]]

local Assertions = require("../helpers/Assertions")
local BufferBuilder = require("../../src")

local function createBufferCursor(buf: buffer)
	local cursor = {
		_buffer = buf,
		_cursorOffset = 0,
		_bitOffset = 0,
	}

	function cursor:GetCursor(): (number, number)
		return self._cursorOffset, self._bitOffset
	end

	function cursor:SetCursor(cursorOffset: number, bitOffset: number)
		self._cursorOffset = cursorOffset
		self._bitOffset = bitOffset
	end

	function cursor:ResetCursor()
		self:SetCursor(0, 0)
	end

	function cursor:_AlignToByte()
		if self._bitOffset > 0 then
			self._bitOffset = 0
			self._cursorOffset += 1
		end
	end

	function cursor:ReadBits(bitCount: number): number
		local value =
			buffer.readbits(self._buffer, self._cursorOffset * 8 + self._bitOffset, bitCount)
		local totalBits = self._bitOffset + bitCount
		self._cursorOffset += math.floor(totalBits / 8)
		self._bitOffset = totalBits % 8
		return value
	end

	function cursor:ReadU8(): number
		self:_AlignToByte()
		local value = buffer.readu8(self._buffer, self._cursorOffset)
		self._cursorOffset += 1
		return value
	end

	function cursor:ReadU16(): number
		self:_AlignToByte()
		local value = buffer.readu16(self._buffer, self._cursorOffset)
		self._cursorOffset += 2
		return value
	end

	return cursor
end

local function testTracksCursorDuringBitReads()
	local builder = BufferBuilder.new()

	builder:WriteBits(3, 0x5)
	builder:WriteBits(5, 0x1D)
	builder:WriteU8(0x44)

	local reader = createBufferCursor(builder:Build())

	Assertions.ExpectCursor(reader, 0, 0, "tracks cursor during bit reads")
	Assertions.ExpectEqual(reader:ReadBits(3), 0x5, "tracks cursor during bit reads")
	Assertions.ExpectCursor(reader, 0, 3, "tracks cursor during bit reads")
	Assertions.ExpectEqual(reader:ReadBits(5), 0x1D, "tracks cursor during bit reads")
	Assertions.ExpectCursor(reader, 1, 0, "tracks cursor during bit reads")
	Assertions.ExpectEqual(reader:ReadU8(), 0x44, "tracks cursor during bit reads")
	Assertions.ExpectCursor(reader, 2, 0, "tracks cursor during bit reads")
end

local function testRestoresCursorWithSetCursor()
	local builder = BufferBuilder.new()

	builder:WriteU16(101)
	builder:WriteU16(202)

	local reader = createBufferCursor(builder:Build())
	Assertions.ExpectEqual(reader:ReadU16(), 101, "restores cursor with SetCursor")

	reader:SetCursor(0, 0)

	Assertions.ExpectEqual(reader:ReadU16(), 101, "restores cursor with SetCursor")
	Assertions.ExpectEqual(reader:ReadU16(), 202, "restores cursor with SetCursor")
end

local function testReadsFromManualBitOffset()
	local builder = BufferBuilder.new()

	builder:WriteBits(4, 0xA)
	builder:WriteBits(4, 0x3)
	builder:WriteBits(4, 0xC)

	local reader = createBufferCursor(builder:Build())

	reader:SetCursor(0, 4)
	Assertions.ExpectEqual(reader:ReadBits(4), 0x3, "reads from manual bit offset")
	Assertions.ExpectEqual(reader:ReadBits(4), 0xC, "reads from manual bit offset")
end

local function testResetsCursor()
	local builder = BufferBuilder.new()

	builder:WriteU8(0x11)
	builder:WriteU8(0x22)

	local reader = createBufferCursor(builder:Build())

	Assertions.ExpectEqual(reader:ReadU8(), 0x11, "resets cursor")
	reader:ResetCursor()
	Assertions.ExpectCursor(reader, 0, 0, "resets cursor")
	Assertions.ExpectEqual(reader:ReadU8(), 0x11, "resets cursor")
	Assertions.ExpectEqual(reader:ReadU8(), 0x22, "resets cursor")
end

local function testTracksBuilderCursorDuringWrites()
	local builder = BufferBuilder.new()
	local cursorOffset, bitOffset = builder:GetCursor()
	Assertions.ExpectEqual(cursorOffset, 0, "tracks builder cursor during writes")
	Assertions.ExpectEqual(bitOffset, 0, "tracks builder cursor during writes")
	Assertions.ExpectEqual(builder:GetLength(), 0, "tracks builder cursor during writes")

	builder:WriteBits(5, 0x12)
	cursorOffset, bitOffset = builder:GetCursor()
	Assertions.ExpectEqual(cursorOffset, 0, "tracks builder cursor during writes")
	Assertions.ExpectEqual(bitOffset, 5, "tracks builder cursor during writes")
	Assertions.ExpectEqual(builder:GetLength(), 1, "tracks builder cursor during writes")

	builder:WriteU8(0xAB)
	cursorOffset, bitOffset = builder:GetCursor()
	Assertions.ExpectEqual(cursorOffset, 2, "tracks builder cursor during writes")
	Assertions.ExpectEqual(bitOffset, 0, "tracks builder cursor during writes")
	Assertions.ExpectEqual(builder:GetLength(), 2, "tracks builder cursor during writes")

	builder:WriteBit(1)
	cursorOffset, bitOffset = builder:GetCursor()
	Assertions.ExpectEqual(cursorOffset, 2, "tracks builder cursor during writes")
	Assertions.ExpectEqual(bitOffset, 1, "tracks builder cursor during writes")
	Assertions.ExpectEqual(builder:GetLength(), 3, "tracks builder cursor during writes")
end

local function testSupportsBuilderSetCursor()
	local builder = BufferBuilder.new()

	builder:WriteU8(0x11)
	builder:SetCursor(3, 0)
	builder:WriteU8(0x22)
	builder:SetCursor(1, 0)
	builder:WriteU16(0xAABB)

	local cursorOffset, bitOffset = builder:GetCursor()
	Assertions.ExpectEqual(cursorOffset, 3, "supports builder SetCursor")
	Assertions.ExpectEqual(bitOffset, 0, "supports builder SetCursor")
	Assertions.ExpectEqual(builder:GetLength(), 4, "supports builder SetCursor")

	local builtBuffer = builder:Build()
	Assertions.ExpectEqual(buffer.readu8(builtBuffer, 0), 0x11, "supports builder SetCursor")
	Assertions.ExpectEqual(buffer.readu16(builtBuffer, 1), 0xAABB, "supports builder SetCursor")
	Assertions.ExpectEqual(buffer.readu8(builtBuffer, 3), 0x22, "supports builder SetCursor")
end

local function testCoalescesConsecutiveBuilderSetCursor()
	local builder = BufferBuilder.new()

	builder:SetCursor(4, 0)
	builder:SetCursor(2, 3)
	builder:SetCursor(2, 3)
	builder:WriteBit(1)

	Assertions.ExpectEqual(#builder._ops, 2, "coalesces consecutive builder SetCursor")
	Assertions.ExpectEqual(builder:GetLength(), 4, "coalesces consecutive builder SetCursor")

	local builtBuffer = builder:Build()
	Assertions.ExpectEqual(buffer.readbits(builtBuffer, 2 * 8 + 3, 1), 1, "coalesces consecutive builder SetCursor")
end

return {
	{
		Name = "tracks cursor during bit reads",
		Callback = testTracksCursorDuringBitReads,
	},
	{
		Name = "restores cursor with SetCursor",
		Callback = testRestoresCursorWithSetCursor,
	},
	{
		Name = "reads from manual bit offset",
		Callback = testReadsFromManualBitOffset,
	},
	{
		Name = "resets cursor",
		Callback = testResetsCursor,
	},
	{
		Name = "tracks builder cursor during writes",
		Callback = testTracksBuilderCursorDuringWrites,
	},
	{
		Name = "supports builder SetCursor",
		Callback = testSupportsBuilderSetCursor,
	},
	{
		Name = "coalesces consecutive builder SetCursor",
		Callback = testCoalescesConsecutiveBuilderSetCursor,
	},
}
