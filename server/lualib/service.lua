local skynet = require "skynet"
local log = require "log"

local service = {}
-- 初始化服务，主要功能为：1：注册服务info 2：注册服务的命令函数 3：启动服务
function service.init(mod)
	local funcs = mod.command
	if mod.info then
		skynet.info_func(function()	--
			return mod.info
		end)
		-- 这里仅作调试用，当在调试模式下，输入 “info 服务ID” 就会打印上面返回的信息
		-- 调试模式的启动方法为 nc 127.0.0.1 8000
	end
	skynet.start(function()
		if mod.require then
			local s = mod.require
			for _, name in ipairs(s) do
				service[name] = skynet.uniqueservice(name)	--启动服务，并将该服务器保存在service下
			end
		end
		if mod.init then
			mod.init()
		end
		skynet.dispatch("lua", function (_,_, cmd, ...)	-- 修改lua协议的dispatch函数，对当前调用init的服务注册函数
														-- skynet.dispatch函数也是服务启动的结束标示
			local f = funcs[cmd]	--获取命令函数
			if f then
				skynet.ret(skynet.pack(f(...)))	--返回命令调用结果，所有通过ret的返回值都要用pack打包
			else
				log("Unknown command : [%s]", cmd)
				skynet.response()(false)
			end
		end)
	end)
end

--[[skynet.ret 在当前协程(为处理请求方消息而产生的协程)中给请求方(消息来源)的消息做回应

skynet.retpack 跟skynet.ret的区别是向请求方作回应时要用skynet.pack打包]]--

return service
