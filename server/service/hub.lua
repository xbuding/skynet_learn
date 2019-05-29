local skynet = require "skynet"
local socket = require "skynet.socket"
local proxy = require "socket_proxy"	--加载范例lualib目录下的socket_proxy
local log = require "log"
local service = require "service"

local hub = {}	--保存函数
local data = { socket = {} }	--保存监听到的链接

-- 调用auth服务
local function auth_socket(fd)
	return (skynet.call(service.auth, "lua", "shakehand" , fd))
end

local function assign_agent(fd, userid)
	skynet.call(service.manager, "lua", "assign", fd, userid)
end

function new_socket(fd, addr)
	data.socket[fd] = "[AUTH]"
	proxy.subscribe(fd)	--将新链接提交给socketproxy
	local ok , userid =  pcall(auth_socket, fd)
	if ok then
		data.socket[fd] = userid
		if pcall(assign_agent, fd, userid) then
			return	-- succ
		else
			log("Assign failed %s to %s", addr, userid)
		end
	else
		log("Auth faild %s", addr)
	end
	proxy.close(fd)
	data.socket[fd] = nil
end

function hub.open(ip, port)
	log("Listen %s:%d", ip, port)
	assert(data.fd == nil, "Already open")	--判断监听是否打开
	data.fd = socket.listen(ip, port)		--新建监听端口
	data.ip = ip
	data.port = port
	socket.start(data.fd, new_socket)		--开始监听，将监听到的链接返回到new_socket函数
end

function hub.close()
	assert(data.fd)
	log("Close %s:%d", data.ip, data.port)
	socket.close(data.fd)
	data.ip = nil
	data.port = nil
end

service.init {
	command = hub,
	info = data,
	require = {
		"auth",
		"manager",
	}
}
