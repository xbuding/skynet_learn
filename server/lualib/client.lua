local skynet = require "skynet"
local proxy = require "socket_proxy"
local sprotoloader = require "sprotoloader"
local log = require "log"

local client = {}	--函数保存
local host 			--接到客户端消息时，使用该函数解包
local sender		--服务器主动向客户端发送消息使用该函数进行包装
local handler = {}	--消息处理回调函数

function client.handler()
	return handler
end
--消息处理
function client.dispatch( c )
	local fd = c.fd
	proxy.subscribe(fd)
	local ERROR = {}
	while true do
		local msg, sz = proxy.read(fd)	--读取连接发来的数据
		local type, name, args, response = host:dispatch(msg, sz)	--sproto解析数据
		assert(type == "REQUEST")	--此处保证连接数据为请求
		if c.exit then	--exit参数为退出循环标志
			return c
		end
		local f = handler[name]		--通过sproto解析出来的数据，获取回调函数
		if f then
			-- f may block , so fork and run
			-- 此处创建一个协程运行回调函数
			skynet.fork(function()
				local ok, result = pcall(f, c, args)	-- 回调函数具体详见agent，auth，回调函数在那边实现
														-- 此处回调函数都为显式传参，将c显式传到回调函数中
				if ok then
					proxy.write(fd, response(result))	-- 使用sproto解析出来的response函数包装返回值，并发送数据
				else
					log("raise error = %s", result)
					proxy.write(fd, response(ERROR, result))
				end
			end)
		else
			-- unsupported command, disconnected
			error ("Invalid command " .. name)
		end
	end
end

function client.close(fd)
	proxy.close(fd)
end

function client.push(c, t, data)
	proxy.write(c.fd, sender(t, data))
end

function client.init(name)
	return function ()
		local protoloader = skynet.uniqueservice "protoloader"
		local slot = skynet.call(protoloader, "lua", "index", name .. ".c2s")
		host = sprotoloader.load(slot):host "package"
		local slot2 = skynet.call(protoloader, "lua", "index", name .. ".s2c")
		sender = host:attach(sprotoloader.load(slot2))
	end
end

return client