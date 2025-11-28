-- 복잡한 테스트 스크립트 예제 - 확장판
-- 이 스크립트는 BufferBuilder와 BufferReader 모듈의 다양한 기능 및 경계 조건을 꼬아서 테스트합니다.
-- 비트/바이트 경계, 혼합된 비트 쓰기, 커스텀 데이터 기록 및 읽기, 커서 재조정 등을 포함합니다.

local BufferBuilder = require("../roblox_packages/BufferBuilder")
local BufferReader = require("../roblox_packages/BufferReader")

print("=== 복잡한 BufferBuilder / BufferReader 테스트 시작 ===")

----------------------------------------------------------------
-- (1) Buffer 작성 단계: 다양한 타입과 혼합된 쓰기
----------------------------------------------------------------
local builder = BufferBuilder.new()

-- 1. 부호 없는 16비트 정수 (U16)
builder:WriteU16(12345)  -- 2바이트

-- 2. 비트 작업: 단일 비트와 여러 비트 필드를 혼합
builder:WriteBit(1)		-- _bitOffset: 0 -> 1
builder:WriteBits(4, 0xF)	-- 다음 4비트: 0xF, _bitOffset: 1+4 = 5
builder:WriteBit(0)		-- 한 비트: _bitOffset: 6
builder:WriteBits(2, 0x2)	-- 2비트: 총 _bitOffset = 6+2 = 8 → 한 바이트 완성

-- 3. 부호 없는 8비트 정수 (U8)
builder:WriteU8(255)	   -- 남은 비트는 _alignToNextByte로 보정

-- 4. 32비트 부동소수점 (F32)
builder:WriteF32(3.14)	 -- 4바이트

-- 5. 64비트 부동소수점 (F64)
builder:WriteF64(2.71828)  -- 8바이트

-- 6. 문자열 기록: "Complex Test"
local testString = "Complex Test"
builder:WriteString(testString)  -- 문자열 길이 + 2바이트 소비

-- 7. 사용자 정의 데이터: Vector3 (x, y, z 모두 F32, 총 12바이트)
local function writeVector3(buf, offset, vec)
	buffer.writef32(buf, offset, vec.x)
	buffer.writef32(buf, offset + 4, vec.y)
	buffer.writef32(buf, offset + 8, vec.z)
end
local function getVector3Size(vec)
	return 12
end
local vector3a = { x = 1.1, y = 2.2, z = 3.3 }
builder:WriteCustom(writeVector3, getVector3Size(vector3a), vector3a)

-- 8. 추가 비트 작업: 다양한 비트 조합으로 커서 업데이트 테스트
builder:WriteBit(0)		  -- 단일 비트
builder:WriteBits(7, 0x55)	 -- 7비트, 값 0x55; 만약 _bitOffset==0이면 1바이트 증가, 그렇지 않으면 누적
builder:WriteBit(1)		  -- 단일 비트
builder:WriteBits(8, 0xAA)	 -- 8비트, 정확히 1바이트

-- 9. 또 다른 사용자 정의 데이터: 커스텀 구조체 (예: 2개의 U16와 1 U8, 총 5바이트)
local function writeCustomStruct(buf, offset, data)
	buffer.writeu16(buf, offset, data.val1)
	buffer.writeu16(buf, offset + 2, data.val2)
	buffer.writeu8(buf, offset + 4, data.flag)
end
local function getCustomStructSize(data)
	return 5
end
local customData = { val1 = 100, val2 = 200, flag = 1 }
builder:WriteCustom(writeCustomStruct, getCustomStructSize(customData), customData)

-- 10. 혼합된 비트와 일반 데이터: 비트 작업 후 U16
builder:WriteBit(1)		  -- 단일 비트
builder:WriteBits(3, 0x3)	  -- 3비트, 값 0x3
builder:WriteU16(54321)		-- U16 정수

----------------------------------------------------------------
-- (2) 버퍼 생성
----------------------------------------------------------------
local buf = builder:Build()
print("생성된 버퍼의 크기:", buffer.len(buf))

----------------------------------------------------------------
-- (3) 직접 buffer 라이브러리 사용 테스트 (일부 데이터만 확인)
----------------------------------------------------------------
print("=== 직접 buffer 라이브러리 사용 테스트 ===")
local direct_u16 = buffer.readu16(buf, 0)  -- 첫 U16 값 (12345)
print("직접 읽은 U16:", direct_u16)

----------------------------------------------------------------
-- (4) BufferReader를 이용한 읽기 테스트
----------------------------------------------------------------
print("=== BufferReader를 이용한 읽기 테스트 ===")
local reader = BufferReader.fromBuffer(buf)

local r_u16 = reader:ReadU16()	   -- 읽은 값: 12345

-- 비트 읽기: 순서대로 읽음
local r_bit1 = reader:ReadBit()		-- should be 1 (from WriteBit(1))
local r_bits4 = reader:ReadBits(4)	   -- should be 0xF (15) (from WriteBits(4, 0xF))
local r_bit0 = reader:ReadBit()		  -- should be 0 (from WriteBit(0))
local r_bits2 = reader:ReadBits(2)	   -- should be 0x2 (2) (from WriteBits(2, 0x2))

local r_u8 = reader:ReadU8()			 -- 255

local r_f32 = reader:ReadF32()		   -- 3.14
local r_f64 = reader:ReadF64()		   -- 2.71828

local r_str = reader:ReadString(#testString)  -- "Complex Test"

-- 사용자 정의 Vector3 읽기
local r_vector3 = reader:ReadCustom(function(buf, offset)
	return {
		x = buffer.readf32(buf, offset),
		y = buffer.readf32(buf, offset + 4),
		z = buffer.readf32(buf, offset + 8),
	}
end, getVector3Size)

-- 추가 비트 데이터 읽기
local r_bit0b = reader:ReadBit()		  -- from WriteBit(0)
local r_bits7 = reader:ReadBits(7)		  -- from WriteBits(7, 0x55)
local r_bit1b = reader:ReadBit()		  -- from WriteBit(1)
local r_bits8 = reader:ReadBits(8)		  -- from WriteBits(8, 0xAA)

-- 사용자 정의 Custom Struct 읽기 (5바이트)
local r_custom = reader:ReadCustom(function(buf, offset)
	return {
		val1 = buffer.readu16(buf, offset),
		val2 = buffer.readu16(buf, offset + 2),
		flag = buffer.readu8(buf, offset + 4)
	}
end, getCustomStructSize)

-- 혼합된 비트 작업 후 일반 데이터 읽기
local r_bit_after = reader:ReadBit()	  -- from WriteBit(1)
local r_bits3 = reader:ReadBits(3)		  -- from WriteBits(3, 0x3)
local r_u16_2 = reader:ReadU16()			-- from WriteU16(54321)

print("BufferReader 결과:")
print(" U16:", r_u16)
print(" Bit1:", r_bit1)
print(" Bits4:", r_bits4)
print(" Bit0:", r_bit0)
print(" Bits2:", r_bits2)
print(" U8:", r_u8)
print(" F32:", r_f32)
print(" F64:", r_f64)
print(" String:", r_str)
print(" Vector3: x=" .. r_vector3.x .. ", y=" .. r_vector3.y .. ", z=" .. r_vector3.z)
print(" Additional Bit Test -> Bit0:", r_bit0b, "Bits7:", r_bits7, "Bit1:", r_bit1b, "Bits8:", r_bits8)
print(" Custom Struct: val1=" .. r_custom.val1 .. ", val2=" .. r_custom.val2 .. ", flag=" .. r_custom.flag)
print(" Mixed Bit/U16 -> Bit:", r_bit_after, "Bits3:", r_bits3, "U16:", r_u16_2)

----------------------------------------------------------------
-- (5) 커서 수동 조정 및 재읽기 테스트
----------------------------------------------------------------
print("=== 커서 재설정 테스트 ===")
reader:SetCursor(0, 0)
local r_u16_re = reader:ReadU16()  -- 처음 U16 다시 읽음
print("커서 재설정 후 U16 재읽기:", r_u16_re)

print("=== BufferBuilder / BufferReader 복합 테스트 종료 ===")
