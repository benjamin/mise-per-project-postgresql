-- Helper function to get the full path of a directory
-- TODO: Make this work on Windows too, but for now, just use realpath on Unix-like systems
function full_path(path)
    local cmd = require("cmd")
    local strings = require("strings")
    local success, full_path = pcall(cmd.exec, "realpath " .. path)
    if success then
        return strings.trim(full_path, "\n")
    else
        return nil
    end
end

--- Returns environment variables to set when this plugin is active
--- Documentation: https://mise.jdx.dev/env-plugin-development.html#miseenv-hook
--- @param ctx {options: table} Context (options = plugin configuration from mise.toml)
--- @return table[] List of environment variable definitions with key/value pairs
function PLUGIN:MiseEnv(ctx)
    -- Access plugin options from mise.toml configuration
    -- Example mise.toml:
    --   [env_plugins.my-env-plugin]
    --   my_option = "value"
    local _options = ctx.options or {}

    -- Return list of environment variables to set
    local env_vars = {}

    local file = require("file")
    local cmd = require("cmd")

    local is_config_root = file.exists("mise.toml") or file.exists("mise.local.toml")
    if not is_config_root then
        return env_vars
    end

    local data_dir = _options.data_dir or ".postgres"
    local full_data_dir = full_path(data_dir)

    if not full_data_dir or not file.exists(full_data_dir) then
        local success, output = pcall(cmd.exec, "initdb -D " .. data_dir)

        if success then
            full_data_dir = full_path(data_dir)
            cmd.exec(
                "printf \"listen_addresses = ''\\nunix_socket_directories = '"
                    .. full_data_dir
                    .. "'\\n\" >> "
                    .. full_data_dir
                    .. "/postgresql.conf"
            )
            cmd.exec('echo "CREATE DATABASE $USER;" | postgres --single -E postgres', {
                env = { PGDATA = full_data_dir, PGHOST = full_data_dir },
            })
        else
            error("Couldn't run initdb: " .. output)
        end
    end

    table.insert(env_vars, {
        key = "PGDATA",
        value = full_data_dir,
    })
    table.insert(env_vars, {
        key = "PGHOST",
        value = full_data_dir,
    })
    table.insert(env_vars, {
        key = "DATABASE_URL",
        value = "postgresql:///?host=" .. full_data_dir,
    })

    return env_vars
end
