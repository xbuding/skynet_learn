local skynet = require "skynet"
require "skynet.manager"
require "skynet.debug"

-- 设置text协议
skynet.register_protocol {
	name = "text",
	id = skynet.PTYPE_TEXT,
	unpack = skynet.tostring,
	pack = function(text) return text end,
}

local socket_fd_addr = {}	--保存c服务的地址，key值为链接
local socket_addr_fd = {}	--保存链接，key值为c服务的地址
local socket_init = {}		--保存链接信息，包括response函数、以及链接状态

local function close_agent(addr)
	local fd = assert(socket_addr_fd[addr])
	socket_fd_addr[fd] = nil
	socket_addr_fd[addr] = nil
end

local function subscribe(fd)
	local addr = socket_fd_addr[fd]
	if addr then
		return addr 	--如果连接已经保存则直接返回服务ID
	end
	addr = assert(skynet.launch("package", skynet.self(), fd))	--创建c语言服务package（连接代理），跑当前服务(self()返回当前服务ID)，返回的是c服务的地址
	socket_fd_addr[fd] = addr 	--保存c服务的地址，key值为链接
	socket_addr_fd[addr] = fd 	--保存链接，key值为c服务的地址
	socket_init[addr] = skynet.response()	--保存该链接的response函数，回应函数，这里同时会回应之前call过来的服务，告诉他addr
end

local function get_status(addr)
	local ok, info = pcall(skynet.call,addr, "text", "I")	--向package服务发送"I" 表示获取该服务的信息(info)
	if ok then
		return info
	else
		return "EXIT"
	end
end

-- 设置该服务的debug info 信息
skynet.info_func(function()
	local tmp = {}
	for fd,addr in pairs(socket_fd_addr) do
		if socket_init[addr] then
			table.insert(tmp, { fd = fd, addr = skynet.address(addr), status = "NOTREADY" })
		else
			table.insert(tmp, { fd = fd, addr = skynet.address(addr), status = get_status(addr) })
		end
	end
	return tmp
end)

skynet.start(function()
	skynet.dispatch("text", function (session, source, cmd)
		-- 此处处理来自package服务发来的信息
		if cmd == "CLOSED" then	--链接关闭
			close_agent(source)
		elseif cmd == "SUCC" then	--链接成功
			socket_init[source](true, source)
			socket_init[source] = nil
		elseif cmd == "FAIL" then	--链接失败
			socket_init[source](false)
			socket_init[source] = nil
		else
			skynet.error("Invalid command " .. cmd)
		end
	end)
	skynet.dispatch("lua", function (session, source, fd)	-- 定义当接到lua消息的处理方式，本服务对于lua的处理仅接受链接对象
		assert(type(fd) == "number")
		local addr = subscribe(fd)
		if addr then
			skynet.ret(skynet.pack(addr))
		end
	end)
end)


--[[
skynet.response和 skynet.ret 立刻回应消息不同，skynet.response 返回的是一个 closure 。需要回应消息的时候，调用它即可；而不需要在同一个 coroutine 里调用 skynet.ret 。
skynet.response 返回的函数，第一个参数是 true 或 false ，后面是回应的参数。当第一个参数是 false 时，会反馈给调用方一个异常；true 则是正常的回应。
]]--
