local skynet = require "skynet"
local sprotoparser = require "sprotoparser" --加载skynet/lualib下的sproto解析器
local sprotoloader = require "sprotoloader" --sproto加器器
local service = require "service"           --加载范例根目录lualib下的service
local log = require "log"                   --加载范例根目录lualib下的log

local loader = {}   --保存函数
local data = {}     --保存加载后的sproto协议在skynet sprotoparser里的序号，key值为文件名

local function load(name)
    local filename = string.format("proto/%s.sproto", name)
    local f = assert(io.open(filename), "Can't open " .. name)
    local t = f:read "a"
    f:close()                       --以上为读取文件内容
    return sprotoparser.parse(t)    --调用skynet的sprotoparser解析sproto协议
end

function loader.load(list)
    for i, name in ipairs(list) do
        local p = load(name)    --加载sproto协议
        log("load proto [%s] in slot %d", name, i)
        data[name] = i
        sprotoloader.save(p, i) --保存解析后的sproto协议
    end
end

function loader.index(name)
    return data[name]   --返回sproto协议在skynet sprotoloader里序号
end

-- 初始化服务的info信息和函数
service.init {
    command = loader,
    info = data
}
