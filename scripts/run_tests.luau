--[[
	로컬/CI 공용 테스트 실행 스크립트입니다.
]]

local process = require("@lune/process")

local result = process.exec("lune", {
	"run",
	"tests/test.luau",
}, {
	cwd = process.cwd,
	env = process.env,
	stdio = "forward",
})

if not result.ok then
	process.exit(result.code)
end
