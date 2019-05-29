local skynet = require "skynet"

skynet.start(function()
    skynet.error("Server start")    -- 打印Server start
    
    if not skynet.getenv "daemon" then
        local console = skynet.newservice("console")    -- 创建控制台
    end
    skynet.newservice("debug_console",8000)             -- 启动控制台服务

    local proto = skynet.uniqueservice "protoloader"    -- 启动封装的protoloader服务
    skynet.call(proto, "lua", "load", {                 -- 调用protoloader服务的load接口
        "proto.c2s",   -- 客户端 to 服务器
        "proto.s2c",   -- 服务器 to 客户端
    })

    local hub = skynet.uniqueservice "hub"              -- 启动hub服务
    skynet.call(hub, "lua", "open", "0.0.0.0", 5678)    -- 调用hub服务中的open接口，监听5678网络端口
    skynet.exit()
end)
