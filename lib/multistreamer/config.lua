local config = require'lapis.config'
local lyaml  = require'lyaml'
local posix  = require'posix'
local langs = require'multistreamer.lang'
local gsub = string.gsub
local len = string.len

local config_loaded = false

local function find_static_dir()
  local static_dir
  static_dir = os.getenv('MULTISTREAMER_STATIC_DIR')
  if static_dir then
    return static_dir
  end
  pcall(function()
    local search = require'luarocks.search'
    local path = require'luarocks.path'
    local name, ver, tree = search.pick_installed_rock('multistreamer')
    if not name then
      return
    end
    static_dir = path.install_dir(name,ver,tree)
  end)
  if static_dir then
    return static_dir .. '/share/multistreamer/html'
  end
end

local function find_conf_file(filename)
  filename = posix.stdlib.realpath(filename or '') or '/etc/multistreamer/config.yaml'

  local search_filenames = { filename }
  local stat = require'posix.sys.stat'.stat

  pcall(function()
    local search = require'luarocks.search'
    local path = require'luarocks.path'
    local name, ver, tree = search.pick_installed_rock('multistreamer')
    if not name then
      return
    end
    table.insert(search_filenames,
      path.conf_dir(name,ver,tree) .. '/config.yaml')
  end)


  for _,v in ipairs(search_filenames) do
    if stat(v) then
      return v
    end
  end

  return nil, search_filenames
end

local function loadconfig(filename)
  local f, yaml_string, yaml_config

  filename = find_conf_file(filename)

  if not filename then
    return nil, 'Unable to find config file'
  end

  f = io.open(filename,'r')

  if not f then
    return nil, 'Error loading config: unable to open ' .. filename
  end

  yaml_string = f:read('*all')
  f:close()

  local _, err = pcall(function()
    yaml_config = lyaml.load(yaml_string)
  end)

  if err then
    return nil, 'Error parsing ' .. filename .. ': ' .. err
  end

  if not yaml_config.work_dir then
    yaml_config.work_dir = os.getenv('HOME') .. '/.multistreamer'
  end

  if not yaml_config.static_dir or len(yaml_config.static_dir) == 0 then
    local static_dir = find_static_dir()
    if not static_dir then
      return nil, 'Unable to find static files directory, set static_dir'
    end
    yaml_config.static_dir = static_dir
  end

  if not yaml_config.log_level or yaml_config.log_level:len() == 0 then
    yaml_config.log_level = 'debug'
  end

  if not yaml_config.redis_prefix or yaml_config.redis_prefix:len() == 0 then
    yaml_config.redis_prefix = 'multistreamer/'
  end

  if not yaml_config.redis_host or yaml_config.redis_host:len() == 0 then
    yaml_config.redis_host = '127.0.0.1'
  end

  local redis_i = yaml_config.redis_host:find(':')
  if redis_i then
    yaml_config.redis_port = yaml_config.redis_host:sub(redis_i+1)
    yaml_config.redis_host = yaml_config.redis_host:sub(1,redis_i-1)
  end

  if not yaml_config.redis_port or yaml_config.redis_port:len() == 0 then
    yaml_config.redis_port = 6379
  else
    yaml_config.redis_port = tonumber(yaml_config.redis_port)
  end

  if not yaml_config.rtmp_prefix or yaml_config.rtmp_prefix:len() == 0 then
    yaml_config.rtmp_prefix = 'multistreamer'
  end

  if not yaml_config.http_prefix then
    yaml_config.http_prefix = ''
  end

  if not yaml_config.http_listen then
    yaml_config.http_listen = '127.0.0.1:8081'
  end

  if not yaml_config.rtmp_listen then
    yaml_config.rtmp_listen = '127.0.0.1:1935'
  end

  if not yaml_config.irc_listen then
    yaml_config.irc_listen = '127.0.0.1:6667'
  end

  if type(yaml_config.http_listen) == 'string' then
    yaml_config.http_listen = { yaml_config.http_listen }
  end

  if type(yaml_config.rtmp_listen) == 'string' then
    yaml_config.rtmp_listen = { yaml_config.rtmp_listen }
  end

  if type(yaml_config.irc_listen) == 'string' then
    yaml_config.irc_listen = { yaml_config.irc_listen }
  end

  if not yaml_config.irc_hostname then
    yaml_config.irc_hostname = 'localhost'
  end

  if not yaml_config.public_http_url then
    yaml_config.public_http_url = 'http://127.0.0.1:8081'
  end
  if not yaml_config.public_rtmp_url then
    yaml_config.public_rtmp_url = 'rtmp://127.0.0.1:1935'
  end
  if not yaml_config.private_http_url then
    yaml_config.private_http_url = 'http://127.0.0.1:8081'
  end
  if not yaml_config.private_rtmp_url then
    yaml_config.private_rtmp_url = 'rtmp://127.0.0.1:1935'
  end
  if not yaml_config.public_irc_hostname then
    yaml_config.public_irc_hostname = 'localhost'
  end
  if not yaml_config.public_irc_hostname then
    yaml_config.public_irc_port = '6667'
  end
  if not yaml_config.public_irc_ssl then
    yaml_config.public_irc_ssl = false
  end
  if not yaml_config.irc_motd then
    yaml_config.irc_motd = [[Welcome to Multistreamer!]]
  end

  if not yaml_config.lua_shared_dict_streams_size then
    yaml_config.lua_shared_dict_streams_size = '1m'
  end

  if not yaml_config.lua_shared_dict_writers_size then
    yaml_config.lua_shared_dict_writers_size = '1m'
  end

  if yaml_config.allow_transcoding == nil then
    yaml_config.allow_transcoding = true
  end

  if yaml_config.allow_custom_puller == nil then
    yaml_config.allow_custom_puller = true
  end

  if yaml_config.ffmpeg_max_attempts == nil then
    yaml_config.ffmpeg_max_attempts = 3
  else
    yaml_config.ffmpeg_max_attempts = tonumber(yaml_config.ffmpeg_max_attempts)
  end

  if yaml_config.ping == nil then
    yaml_config.ping = '1m';
  end

  if yaml_config.ping_timeout == nil then
    yaml_config.ping_timeout = '30s';
  end

  if yaml_config.show_version == nil then
    yaml_config.show_version = true
  end

  if yaml_config.lang_id == nil or len(yaml_config.lang_id) == 0 or langs[yaml_config.lang_id] == nil then
    yaml_config.lang_id = 'en_us'
  end

  yaml_config.lang = langs[yaml_config.lang_id]
  yaml_config.langs = langs

  yaml_config.http_prefix      = gsub(yaml_config.http_prefix,'/+$','')
  yaml_config.public_http_url  = gsub(yaml_config.public_http_url,'/+$','')
  yaml_config.public_rtmp_url  = gsub(yaml_config.public_rtmp_url,'/+$','')
  yaml_config.private_http_url = gsub(yaml_config.private_http_url,'/+$','')
  yaml_config.private_rtmp_url = gsub(yaml_config.private_rtmp_url,'/+$','')

  if type(yaml_config.networks.beam) == 'table' and not yaml_config.networks.mixer then
    yaml_config.networks.mixer = {
      client_secret = yaml_config.networks.beam.client_secret,
      client_id     = yaml_config.networks.beam.client_id,
      ingest_server = gsub(yaml_config.networks.beam.ingest_server,'beam.pro','mixer.com'),
    }
    yaml_config.networks.beam = nil
  end

  for _,network in ipairs({ 'mixer', 'facebook', 'youtube', 'twitch' }) do
    if type(yaml_config.networks[network]) == 'table' and yaml_config.networks[network].debug == nil then
      -- default to true to preserve old behavior
      yaml_config.networks[network].debug = true
    end
  end

  -- default to true to preserve old behavior
  if yaml_config.redis_debug == nil then
    yaml_config.redis_debug = true
  end
  if yaml_config.rtmp_debug == nil then
    yaml_config.rtmp_debug = true
  end
  if yaml_config.websocket_debug == nil then
    yaml_config.websocket_debug = true
  end
  if yaml_config.process_manager_debug == nil then
    yaml_config.process_manager_debug = true
  end

  config('default',yaml_config)

  package.loaded['lapis_environment'] = 'default'
  yaml_config['_filename'] = filename
  local sani_config = lyaml.load(lyaml.dump({yaml_config}))
  sani_config.postgres = nil
  yaml_config['_raw'] = lyaml.dump({sani_config})
  config_loaded = true

  return true

end

local function get()
  if not config_loaded then
    loadconfig()
  end
  return config.get()
end

return {
  find_conf_file = find_conf_file,
  loadconfig = loadconfig,
  get = get,
}
