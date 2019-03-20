--[[----------------------------------------------------------
    gsql - Facilitate SQL programming for GmodLua

    @author Gabriel Santamaria <gaby.santamaria@outlook.fr>
------------------------------------------------------------]]
require('mysqloo') -- Based on MySQLOO module https://github.com/FredyH/MySQLOO

gsql = gsql or {
    -- [database] MYSQLOO Database object
    connection = nil,
    -- [table][Query] Queries
    queries = {},
    -- [table][PreparedQuery] Prepared queries
    prepared = {},
    -- [number] Number of affected rows in the last query
    affectedRows = nil
}

--[[----------------------------------------------------------
    gsql constructor
    Creates the new gsql object
------------------------------------------------------------]]
function gsql:new(obj, dbhost, dbname, dbuser, dbpass, port)
    obj = obj or {}
    port = port or 3306
    setmetatable(obj, self)
    -- Creating log file if doesn't already exists
    if not file.Exists('gsql_logs.txt', 'DATA') then
        file.Write('gsql_logs.txt', '')
    end
    self.__index = self
    -- Creating a new Database object
    self.connection = mysqloo.connect(dbhost, dbuser, dbpass, dbname, port)
    function self.connection.onError(err)
        file.Append('gsql_logs.txt', '[gsql][new] : ' .. err)
        error('[gsql] A fatal error appenned while connecting to the database, please check your logs for more informations!')
    end
    self.connection:connect()

    return self
end

--[[----------------------------------------------------------
    HELPER function : parse parameters in the query
    gsql.replace([string] queryStr, [table] parameters)
------------------------------------------------------------]]
function gsql.replace(queryStr, name, value)
    local pattern = '{{' .. name .. '}}'
    return string.gsub(queryStr, pattern, value)
end

--[[----------------------------------------------------------
    gsql:query([string] query, [function] callback, [, [table] parameters])
    function callback([bool]status, [string] reason, [, [table] data])
    Returns [table] data OR [bool] false
------------------------------------------------------------]]
function gsql:query(queryStr, callback, parameters)
    if (queryStr == nil) then error('[gsql] An error occured while trying to query : Argument \'queryStr\' is missing!') end
    parameters = parameters or {}
    -- By using this instead of a table in string.gsub, we avoid nil-related errors
    for k, v in pairs(parameters) do
        v = self.connection:escape(v)
        queryStr = self.replace(queryStr, k, v)
    end
    local i = #self.queries + 1
    self.queries[i] = self.connection:query(queryStr) -- Doing the query
    self.queries[i].onSuccess = function(query, data)
        callback(true, 'success', data)
    end
    self.queries[i].onAborted = function(query)
        callback(false, 'aborted')
    end
    self.queries[i].onError = function(query, err)
        file.Append('gsql_logs.txt', '[gsql][query] : ' .. err)
        callback(false, 'error')
    end
    self.queries[i]:start()
    self.affectedRows = query:affectedRows()
end

--[[----------------------------------------------------------
    Add a prepared query to the prepared queries table
    gsql:prepare([string] query)
    Returns [number] index of the prepared query
------------------------------------------------------------]]
function gsql:prepare(queryStr)
    if (queryStr == nil) then
        file.Append('gsql_logs.txt', '[gsql][prepare] : Argument \'queryStr\' is missing. ')
        error('[gsql] An error occured when preparing a query!')
    elseif (type(queryStr) ~= 'string') then
        file.Append('gsql_logs.txt', '[gsql][prepare] : Incorrect type of \'queryStr\'.')
        error('[gsql] An error occured when preparing a query!')
    end
    self.prepared[#self.prepared + 1] = self.connexion:prepare(queryStr)

    return #self.prepared + 1
end

--[[----------------------------------------------------------
    Delete a prepared query from the prepared queries table
    gsql:delete([number] index)
    Returns [bool] status of deleting
------------------------------------------------------------]]
function gsql:delete(index)
    index = index or 1 -- First prepared query by default
    if (type(index) ~= 'number') then
        file.Append('gsql_logs.txt', '[gsql][delete] : Invalid type of \'index\'. It must be a number.')
        error('[gsql] An error occured while trying to delete a prepared query!')
    end
    if not self.prepared[index] then -- Checking if the index is correct
        file.Append('gsql_logs.txt', '[gsql][delete] : Invalid \'index\'. Requested deletion of prepared query number ' .. index .. ' as failed. Prepared query doesn\'t exist')
        error('[gsql] An error occured while trying to delete a prepared query! See logs for more informations')
        return false
    end
    -- Setting the PreparedQuery object to nil
    self.prepared[index] = nil
    return true
end

--[[----------------------------------------------------------
    Execute all prepared queries by their order of preparation
    Delete the executed prepared query
    gsql:execute([number] index, [function] callback, [table] parameters)
    function callback([bool]status, [string] reason, [, [table] data])
    Returns [table] data OR [bool] false
------------------------------------------------------------]]
function gsql:execute(index, callback, parameters)
    parameters = parameters or {}
    local i = 1
    for _, v in pairs(parameters) do
        if (type(v) == 'number') then -- Thanks Lua for the absence of a switch statement
            self.prepared[index]:setNumber(i, v)
        elseif (type(v) == 'string') then
            self.prepared[index]:setString(i, v)
        elseif (type(v) == 'bool') then
            self.prepared[index]:setBool(i, v)
        elseif (type(v) == 'nil') then
            self.prepared[index]:setNull(i)
        else
            file.Append('gsql_logs.txt', '[gsql][execute] : Invalid type of parameter (parameter : ' .. k .. ' value : ' .. v .. ')')
            error('[gsql] : An error appears while preparing the query. See the logs for more informations!')
            return false
        end
        i = i + 1
    end
    self.prepared[index].onSuccess = function (query, data)
        callback(true, 'success', data)
    end
    self.prepared[index].onAborted = function(query)
        callback(false, 'aborted')
    end
    self.prepared[index].onError = function(query, err)
        file.Append('gsql_logs.txt', '[gsql][execute] : ' .. err)
        callback(false, 'error')
    end
    self.prepared[index]:start()
end
