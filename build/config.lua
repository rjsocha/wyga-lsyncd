function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end
function base64_decode(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

configs = os.getenv("CONFIGS")
if not configs then error('missing CONFINGS environmental variable ...') end
syncus = {}
idx = 1
for config in string.gmatch(configs,"[^,]+") do
  cnf = os.getenv(config)
  if not cnf then error(string.format('missing configuration named "%s"',config)) end
  syncus[idx]={}
  syncus[idx].exclude={}
  syncus[idx].delay=15
  syncus[idx].maxdelays=1000
  for _entry in string.gmatch(cnf,"%S+") do
    if string.find(string.lower(_entry),"^src:(.+)") then
      syncus[idx].src=string.sub(_entry,5)
    elseif string.find(string.lower(_entry),"^dst:(.+)") then
      syncus[idx].dst=string.sub(_entry,5)
    elseif string.find(string.lower(_entry),"^key:(.+)") then
      syncus[idx].ssh_key=string.sub(_entry,5)
    elseif string.find(string.lower(_entry),"^delay:([0-9]+)") then
      syncus[idx].delay=tonumber(string.sub(_entry,7))
    elseif string.find(string.lower(_entry),"^max%-delays:([0-9]+)") then
      syncus[idx].maxdelays=tonumber(string.sub(_entry,12))
    elseif string.find(string.lower(_entry),"^exclude:(.+)") then
      _exclude=string.sub(_entry,9)
      for _ex in string.gmatch(_exclude,"[^,]+") do
        table.insert(syncus[idx].exclude,_ex)
      end
    end
  end

  -- check required tags
  if not syncus[idx].src then error(string.format('missing "SRC" tag for configuration "%s"',config)) end
  if not syncus[idx].dst then error(string.format('missing "DST" tag for configuration "%s"',config)) end

  -- parse dst:
  _dst=syncus[idx].dst
  if string.find(string.lower(_dst),"^env:") then
    _dst_env_name=string.sub(_dst,5)
    _dst_env=os.getenv(_dst_env_name)
    if not _dst_env then error(string.format('missing environment variable (%s) for configuration "%s"',_dst_env_name,config)) end
    syncus[idx].dst=_dst_env
    _dst=_dst_env
  end
  if string.find(string.lower(_dst),"^ssh://(.+)") then
    syncus[idx].mode="SSH"
    _dst=string.sub(_dst,7)
  elseif string.find(string.lower(_dst),"^rsync://(.+)") then
    syncus[idx].mode="RSYNC"
    _dst=string.sub(_dst,9)
    error('only SSH mode supported at the moment ...')
  else
    error(string.format('unsupported sync mode for configuration "%s"',config))
  end

  if not string.find(_dst,"@") then
    error(string.format('missing user name in "DST" tag for configuration "%s"',config))
  end

  _idx,_len,_user = string.find(_dst,"^([^@]+)")
  if not _user then
    error(string.format('empty user name in "DST" tag for configuration "%s"',config))
  end
  syncus[idx].user=_user
  _dst=string.sub(_dst,1+_len+1)

  _idx,_len,_host = string.find(_dst,"^([^/]+)")
  if not _host then
    error(string.format('missing hostname in "DST" tag for configuration "%s"',config))
  end
  _dst=string.sub(_dst,1+_len)

  syncus[idx].port=22
  if string.find(_host,":") then
    _,_,_host,_port = string.find(_host,"([^:]+):(.+)")
    if not string.find(_port,"^[0-9]+$") then
      error(string.format('incorrect port in "DST" tag for configuration "%s"',config))
    end
    syncus[idx].port=tonumber(_port)
  end
  syncus[idx].host=_host

  if string.len(_dst) < 1 then
    error(string.format('missing destination path in "DST" tag for configuration "%s"',config))
  end

  syncus[idx].target=_dst

  if syncus[idx].mode == "SSH" then
    if not syncus[idx].ssh_key then
      error(string.format('missing SSH KEY for configuration "%s"',config))
    end
    _ssh_key=syncus[idx].ssh_key
    if string.find(string.lower(_ssh_key),"^env:") then
      _ssh_key_env_name = string.sub(_ssh_key,5)
      _key_env = os.getenv(_ssh_key_env_name)
      if not _key_env then error(string.format('unable to locate SSH KEY environment variable (%s) for configuration "%s"',_ssh_key_env_name,config)) end
      math.randomseed(os.time())
      random_file_name = tostring(math.random(1000000,9999999))
      file_path = "/tmp/lsyncd-ssh-key-" .. random_file_name .. ".key"
      file = io.open(file_path, "w")
      if not file then error(string.format('unable to save SSH KEY to "%s" for configuration "%s"',file_path,config)) end
      data = base64_decode(_key_env)
      file:write(data)
      file:close()
      os.execute("chmod 400 " .. file_path)
      _ssh_key=file_path
    elseif not file_exists(_ssh_key) then
      error(string.format('unable to locate SSH KEY (%s) for configuration "%s"',_ssh_key,config))
    end
  end
  syncus[idx].ssh_key_file=_ssh_key

  idx=idx + 1
end
print("CONFIGS:",idx-1)
for i,v in ipairs(syncus) do
  print(i,v.src,v.dst,v.mode,v.delay,v.maxdelays)
  if #v.exclude > 0 then
    print("EXCLUDES")
    for n,v in ipairs(v.exclude) do
      print("  " .. v)
    end
  end
end

settings {
--   statusFile = "/sync/.status",
   nodaemon   = true,
   insist = true
}

for i,v in ipairs(syncus) do
  sync {
    default.rsyncssh,
    ssh = {
      port = v.port,
      identityFile = v.ssh_key_file,
      options = {
        User = v.user,
        LogLevel = 'QUIET',
        StrictHostKeyChecking = 'no',
        UserKnownHostsFile = '/dev/null'
      }
    },
    delay = v.delay,
    maxDelays = v.maxdelays,
    source = v.src,
    host = v.host,
    targetdir = v.target,
    exclude = v.exclude
  }
end
