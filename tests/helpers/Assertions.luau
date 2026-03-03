--[[
	테스트 공통 검증 헬퍼 모듈입니다.
]]

local Assertions = {}

function Assertions.ExpectEqual(actual: any, expected: any, testName: string)
	if actual ~= expected then
		error(`{testName}: expected "{expected}" but got "{actual}"`)
	end
end

function Assertions.ExpectClose(actual: number, expected: number, precision: number, testName: string)
	local tolerance = 10 ^ -precision
	if math.abs(actual - expected) > tolerance then
		error(`{testName}: expected "{expected}" but got "{actual}"`)
	end
end

function Assertions.ExpectCursor(reader, expectedOffset: number, expectedBitOffset: number, testName: string)
	local cursorOffset, bitOffset = reader:GetCursor()
	if cursorOffset ~= expectedOffset or bitOffset ~= expectedBitOffset then
		error(`{testName}: expected cursor ({expectedOffset}, {expectedBitOffset}) but got ({cursorOffset}, {bitOffset})`)
	end
end

return Assertions
