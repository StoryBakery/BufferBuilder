--[=[
	@class BufferBuilder
	
	비트/바이트 단위로 쓰기 작업을 기록해 최종 buffer 객체를 생성하는 빌더입니다.
	정수, 실수, 비트 플래그 등을 순서대로 작성하고 Build 단계에서 buffer를 만듭니다.
]=]

local TRACE_BACK = false

pcall(function()
	TRACE_BACK = if game ~= nil then game:GetService("RunService"):IsStudio() else true
end)

local BufferBuilder = {}
BufferBuilder.__index = BufferBuilder
BufferBuilder.__type = "BufferBuilder"

export type BufferBuilder = setmetatable<{
	_cursorOffset: number,
	_bitOffset: number,
	_maxLength: number,
	_ops: { any },
	_tracebacks: { any },
}, typeof(BufferBuilder)>

function BufferBuilder.new(): BufferBuilder
	local self = setmetatable({}, BufferBuilder)
	self._cursorOffset = 0
	self._bitOffset = 0
	self._maxLength = 0
	self._ops = {}
	self._tracebacks = {}

	return self
end

--[=[
	현재 바이트 위치와 비트 오프셋을 반환합니다.
	@return number - 바이트 오프셋.
	@return number - 비트 오프셋.
]=]
function BufferBuilder:GetCursor(): (number, number)
	return self._cursorOffset, self._bitOffset
end

local function getByteLength(cursorOffset: number, bitOffset: number): number
	return cursorOffset + math.ceil(bitOffset / 8)
end

local function updateMaxLength(builder: BufferBuilder)
	local length = getByteLength(builder._cursorOffset, builder._bitOffset)
	if builder._maxLength < length then
		builder._maxLength = length
	end
end

--[=[
	현재까지 기록된 데이터의 전체 바이트 길이를 반환합니다.
	@return number - 최종 buffer 바이트 길이.
]=]
function BufferBuilder:GetLength(): number
	return self._maxLength
end

local function alignToNextByte(builder: BufferBuilder)
	if builder._bitOffset > 0 then
		builder._bitOffset = 0
		builder._cursorOffset += 1
	end
end

local function insertOp(builder: BufferBuilder, operation)
	table.insert(builder._ops, operation)
end

if TRACE_BACK then
	function insertOp(builder: BufferBuilder, operation)
		table.insert(builder._ops, operation)
		table.insert(builder._tracebacks, debug.traceback(nil, 2))
	end
end

--[=[
	쓰기 커서를 임의 위치로 이동합니다.
	@param cursorOffset - 이동할 바이트 오프셋.
	@param bitOffset - 이동할 비트 오프셋.
]=]
function BufferBuilder:SetCursor(cursorOffset: number, bitOffset: number)
	if self._cursorOffset == cursorOffset and self._bitOffset == bitOffset then
		return
	end

	self._cursorOffset = cursorOffset
	self._bitOffset = bitOffset

	local operations = self._ops
	local lastIndex = #operations
	local lastOperation = operations[lastIndex]

	-- 연속된 seek는 마지막 위치만 의미가 있으므로 덮어씁니다.
	if lastOperation ~= nil and lastOperation[1] == "seek" then
		lastOperation[2] = cursorOffset
		lastOperation[3] = bitOffset

		if TRACE_BACK then
			self._tracebacks[lastIndex] = debug.traceback(nil, 2)
		end
	else
		insertOp(self, { "seek", cursorOffset, bitOffset })
	end

	updateMaxLength(self)
end

--[=[
	부호 있는 8비트 정수를 기록합니다.
	@param value - [-128, 127] 범위 값.
]=]
function BufferBuilder:WriteI8(value)
	alignToNextByte(self)
	insertOp(self, { "i8", value })
	self._cursorOffset += 1
	updateMaxLength(self)
end

--[=[
	부호 있는 16비트 정수를 기록합니다.
	@param value
]=]
function BufferBuilder:WriteI16(value)
	alignToNextByte(self)
	insertOp(self, { "i16", value })
	self._cursorOffset += 2
	updateMaxLength(self)
end

--[=[
	부호 있는 32비트 정수를 기록합니다.
	@param value
]=]
function BufferBuilder:WriteI32(value)
	alignToNextByte(self)
	insertOp(self, { "i32", value })
	self._cursorOffset += 4
	updateMaxLength(self)
end

--[=[
	부호 없는 8비트 정수를 기록합니다.
	@param value
]=]
function BufferBuilder:WriteU8(value)
	alignToNextByte(self)
	insertOp(self, { "u8", value })
	self._cursorOffset += 1
	updateMaxLength(self)
end

--[=[
	부호 없는 16비트 정수를 기록합니다.
	@param value
]=]
function BufferBuilder:WriteU16(value)
	alignToNextByte(self)
	insertOp(self, { "u16", value })
	self._cursorOffset += 2
	updateMaxLength(self)
end

--[=[
	부호 없는 32비트 정수를 기록합니다.
	@param value
]=]
function BufferBuilder:WriteU32(value)
	alignToNextByte(self)
	insertOp(self, { "u32", value })
	self._cursorOffset += 4
	updateMaxLength(self)
end

--[=[
	32비트 부동소수(float)를 기록합니다.
	@param value
]=]
function BufferBuilder:WriteF32(value)
	alignToNextByte(self)
	insertOp(self, { "f32", value })
	self._cursorOffset += 4
	updateMaxLength(self)
end

--[=[
	64비트 부동소수(double)를 기록합니다.
	@param value
]=]
function BufferBuilder:WriteF64(value)
	alignToNextByte(self)
	insertOp(self, { "f64", value })
	self._cursorOffset += 8
	updateMaxLength(self)
end

--[=[
	단일 비트를 순차적으로 기록합니다.
	@param bit - 0 또는 1.
]=]
function BufferBuilder:WriteBit(bit)
	insertOp(self, { "bit", bit })
	self._bitOffset += 1
	if self._bitOffset == 8 then
		self._bitOffset = 0
		self._cursorOffset += 1
	end
	updateMaxLength(self)
end

--[=[
	여러 비트를 한 번에 기록합니다.
	@param bitCount - 기록할 비트 수.
	@param bitValue - 하위 비트부터 채울 값.
]=]
function BufferBuilder:WriteBits(bitCount, bitValue)
	insertOp(self, { "bits", bitCount, bitValue })

	local totalBits = self._bitOffset + bitCount
	local additionalBytes = math.floor(totalBits / 8)
	self._cursorOffset += additionalBytes
	self._bitOffset = totalBits % 8
	updateMaxLength(self)
end

--[=[
	불리언 값을 비트 하나로 기록합니다.
	@param bool - 기록할 값.
]=]
function BufferBuilder:WriteBoolBit(bool: boolean)
	self:WriteBit(bool and 1 or 0)
end

--[=[
	불리언 값을 1바이트로 기록합니다.
	@param bool - 기록할 값.
]=]
function BufferBuilder:WriteBool(bool: boolean)
	self:WriteU8(bool and 1 or 0)
end

--[=[
	문자열 UTF-8 바이트를 현재 위치에 기록합니다.
	문자열 길이는 별도로 관리해야 합니다.
	@param value
]=]
function BufferBuilder:WriteString(value: string)
	alignToNextByte(self)
	insertOp(self, { "string", value })
	self._cursorOffset += #value
	updateMaxLength(self)
end

--[=[
	사용자 정의 직렬화 함수를 이용해 값과 크기를 기록합니다.
	@param serializeFn, offset, value)->() - 직렬화 함수.
	@param byteSize - 기록할 바이트 길이.
	@param value - 직렬화할 값.
]=]
function BufferBuilder:WriteCustom<T>(
	callback: (buf: buffer, offset: number, value: T) -> (),
	size: number,
	value: T
)
	alignToNextByte(self)
	insertOp(self, { "custom", callback, size, value })
	self._cursorOffset += size
	updateMaxLength(self)
end

--[=[
	TypeInfo 기반 직렬화 함수를 이용해 값을 기록합니다.
	@param typeInfo - 직렬화 정보를 담은 객체.
	@param value - 기록할 값.
]=]
function BufferBuilder:WriteType<T>(
	info: {
		Serialize: (buf: buffer, offset: number, value: T) -> (),
		GetSize: (value: T) -> number,
	} & any,
	value: T
)
	self:WriteCustom(info.Serialize, info.GetSize(value), value)
end

local WRITE_FUNCTIONS_BY_OPERATION_TYPE = {
	i8 = function(buf, offset, op)
		buffer.writei8(buf, offset, op[2])
		return 1
	end,
	i16 = function(buf, offset, op)
		buffer.writei16(buf, offset, op[2])
		return 2
	end,
	i32 = function(buf, offset, op)
		buffer.writei32(buf, offset, op[2])
		return 4
	end,
	u8 = function(buf, offset, op)
		buffer.writeu8(buf, offset, op[2])
		return 1
	end,
	u16 = function(buf, offset, op)
		buffer.writeu16(buf, offset, op[2])
		return 2
	end,
	u32 = function(buf, offset, op)
		buffer.writeu32(buf, offset, op[2])
		return 4
	end,
	f32 = function(buf, offset, op)
		buffer.writef32(buf, offset, op[2])
		return 4
	end,
	f64 = function(buf, offset, op)
		buffer.writef64(buf, offset, op[2])
		return 8
	end,
	string = function(buf, offset, op)
		local str = op[2]
		buffer.writestring(buf, offset, str)
		return #str
	end,
	bit = function(buf, offset, op, bitOffset)
		local value = op[2]
		local globalBitOffset = offset * 8 + bitOffset
		buffer.writebits(buf, globalBitOffset, 1, value)
		bitOffset += 1
		local extra = 0
		if bitOffset == 8 then
			bitOffset = 0
			extra = 1
		end
		return extra, bitOffset
	end,
	bits = function(buf, offset, op, bitOffset)
		local bitCount = op[2]
		local value = op[3]
		local globalBitOffset = offset * 8 + bitOffset
		buffer.writebits(buf, globalBitOffset, bitCount, value)
		local totalBits = bitOffset + bitCount
		local addBytes = math.floor(totalBits / 8)
		local newOffset = totalBits % 8
		return addBytes, newOffset
	end,
}

local function buildOperation(buf, op, offset, bitOffset)
	local opType = op[1]

	if opType == "seek" then
		offset = op[2]
		bitOffset = op[3]
	elseif opType == "custom" then
		local callback = op[2]
		local size = op[3]
		local val = op[4]

		if 0 < bitOffset then
			offset += 1
			bitOffset = 0
		end

		callback(buf, offset, val)
		offset = offset + size
	else
		local fn = WRITE_FUNCTIONS_BY_OPERATION_TYPE[opType]

		local offInc, newBitOffset
		if opType == "bit" or opType == "bits" then
			offInc, newBitOffset = fn(buf, offset, op, bitOffset)
			bitOffset = newBitOffset
		else
			-- 비트 단위 연산이 아니면 바이트 경계로 정렬합니다.
			if 0 < bitOffset then
				offset += 1
				bitOffset = 0
			end
			offInc = fn(buf, offset, op)
		end
		offset = offset + offInc
	end

	return offset, bitOffset
end

--[=[
	누적된 연산을 실행해 최종 buffer 객체를 생성합니다.
]=]
function BufferBuilder:Build(): buffer
	local buf = buffer.create(self:GetLength())
	local offset = 0
	local bitOffset = 0 -- [0, 7]
	local operations = self._ops
	local opsLen = #operations

	for i = 1, opsLen do
		local op = operations[i]
		if TRACE_BACK then
			local suc
			suc, offset, bitOffset = pcall(buildOperation, buf, op, offset, bitOffset)
			if not suc then
				error(`Error occurred while building \z
					BufferBuilder from the inserted operation:\n\z
					{self._tracebacks[i]}\n\z
					Error: \n\z
					{offset}`)
			end
		else
			offset, bitOffset = buildOperation(buf, op, offset, bitOffset)
		end
	end

	return buf
end

return BufferBuilder
