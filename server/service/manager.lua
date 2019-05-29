local skynet = require "skynet"
local service = require "service"
local log = require "log"

local manager = {}
local users = {}	--保存用户服务，

local function new_agent()
	-- todo: use a pool
	return skynet.newservice "agent"
end

local function free_agent(agent)
	-- kill agent, todo: put it into a pool maybe better
	skynet.kill(agent)
end

function manager.assign(fd, userid)
	local agent
	repeat
		agent = users[userid]	--判断是否有当前用户的服务
		if not agent then		--若没有则创建一个
			agent = new_agent()
			if not users[userid] then
				-- double check
				users[userid] = agent
			else
				free_agent(agent)
				agent = users[userid]
			end
		end
	until skynet.call(agent, "lua", "assign", fd, userid)	--此处返回ture，跳出循环
	log("Assign %d to %s [%s]", fd, userid, agent)
end
--关闭名为userid的agent服务
function manager.exit(userid)
	users[userid] = nil
end

service.init {
	command = manager,
	info = users,
}


