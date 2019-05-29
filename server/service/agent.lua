local skynet = require "skynet"
local service = require "service"
local client = require "client"
local log = require "log"

local agent = {}
local data = {}
local cli = client.handler()

function cli:ping()
	assert(self.login)
	log "ping"
end

function cli:login()
	assert(not self.login)
	if data.fd then	--重复登入
		log("login fail %s fd=%d", data.userid, self.fd)
		return { ok = false }
	end
	data.fd = self.fd
	self.login = true
	log("login succ %s fd=%d", data.userid, self.fd)
	client.push(self, "push", { text = "welcome" })	-- push message to client
	return { ok = true }
end

local function new_user(fd)
	local ok, error = pcall(client.dispatch , { fd = fd })	--进入客户端消息循环，若此处客户端长时间没有任何操作，而报超时错误返回
	log("fd=%d is gone. error = %s", fd, error)
	client.close(fd)	--关闭客户端链接服务
	if data.fd == fd then
		data.fd = nil
		skynet.sleep(1000)	-- exit after 10s 等待10秒若还没有重连则正式销毁当前服务
		if data.fd == nil then
			-- double check
			if not data.exit then
				data.exit = true	-- mark exit
				skynet.call(service.manager, "lua", "exit", data.userid)	-- report exit 从manage中剔除当前agent
				log("user %s afk", data.userid)
				skynet.exit()	--销毁服务
			end
		end
	end
end

function agent.assign(fd, userid)
	if data.exit then
		return false
	end
	if data.userid == nil then
		data.userid = userid
	end
	assert(data.userid == userid)
	skynet.fork(new_user, fd)
	return true
end

service.init {
	command = agent,
	info = data,
	require = {
		"manager",
	},
	init = client.init "proto",
}

