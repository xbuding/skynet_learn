local skynet = require "skynet"
local service = require "service"
local client = require "client"
local log = require "log"

local auth = {}
local users = {}	--保存已经注册的用户信息
local cli = client.handler()

local SUCC = { ok = true }
local FAIL = { ok = false }

-- signup注册账号请求回调
function cli:signup(args)
	log("signup userid = %s", args.userid)
	if users[args.userid] then
		return FAIL
	else
		users[args.userid] = true
		return SUCC
	end
end

-- signin登入请求回调
function cli:signin(args)
	log("signin userid = %s", args.userid)
	if users[args.userid] then
		self.userid = args.userid	--self为修改隐式参数
		self.exit = true	--退出client中dispatch循环，表示登入成功，退出auth服务，进入下一个服务
		return SUCC
	else
		return FAIL
	end
end

-- ping回调
function cli:ping()
	log("ping")
end

function auth.shakehand(fd)
	local c = client.dispatch { fd = fd }	--将链接交给client对信息进行处理
	return c.userid
end

service.init {
	command = auth,
	info = users,
	init = client.init "proto",
}
