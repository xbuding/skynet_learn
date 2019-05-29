local skynet = require "skynet"

local proxyd
--此处调用skynet的“初始化”函数，并不是初始化skynet，而是将要初始化的内容增加到初始化列队
skynet.init(function()
    proxyd = skynet.uniqueservice "socket_proxyd"   --挂起socket_proxyd
end)

local proxy = {}    --保存函数
local map = {}      --保存所有连接的服务地址，key为连接对象
-- 注册文本协议
skynet.register_protocol {
    name = "text",  -- 协议名
    id = skynet.PTYPE_TEXT, --协议ID
    pack = function(text) return text end,  --发送消息的打包函数
    unpack = function(buf, sz) return skynet.tostring(buf,sz) end,  --接收消息的拆包函数
}
--注册客户端协议
skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT,
    pack = function(buf, sz) return buf, sz end,
}
--通过链接返回一个服务地址
local function get_addr(fd)
    return assert(map[fd], "subscribe first")
end

function proxy.subscribe(fd)
    local addr = map[fd]
    if not addr then
        addr = skynet.call(proxyd, "lua", fd)   --向proxyd 发送命令，创建基于fd链接的服务，详见socket_proxyd.lua
        map[fd] = addr  --保存服务地址
    end
end

function proxy.read(fd)
    local ok,msg,sz = pcall(skynet.rawcall , get_addr(fd), "text", "R") --匿名向get_addr(fd)这个地址的服务，发送text协议请求
    if ok then
        return msg,sz
    else
        error "disconnect"
    end
end

function proxy.write(fd, msg, sz)
    skynet.send(get_addr(fd), "client", msg, sz)
end

function proxy.close(fd)
    skynet.send(get_addr(fd), "text", "K")
end

function proxy.info(fd)
    return skynet.call(get_addr(fd), "text", "I")
end

return proxy

--[[
skynet.register_protocol 

注册协议：

协议名(name)

协议ID(id)

发送消息的打包函数(pack)

接收消息的拆包函数(unpack)

接收消息的(分发)处理函数(dispatch)

已注册的协议记录在lualib/skynet.lua:proto这个数据结构上

每个服务会默认初始化lua/response/error这几种协议
]]--



