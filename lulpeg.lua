print("LOCAL")
do local sources, priorities = {}, {};assert(not sources["util"])sources["util"]=([===[-- <pack util> --

-- A collection of general purpose helpers.

--[[DGB]] local debug = require"debug"

local getmetatable, setmetatable, load, loadstring, next
    , pairs, pcall, print, rawget, rawset, select, tostring
    , type, unpack
    = getmetatable, setmetatable, load, loadstring, next
    , pairs, pcall, print, rawget, rawset, select, tostring
    , type, unpack

local m, s, t = require"math", require"string", require"table"

local m_max, s_match, s_gsub, t_concat, t_insert
    = m.max, s.match, s.gsub, t.concat, t.insert

local compat = require"compat"


-- No globals definition:

local
function nop () end

local noglobals, getglobal, setglobal if pcall and not compat.lua52 and not release then
    local function errR (_,i)
        error("illegal global read: " .. tostring(i), 2)
    end
    local function errW (_,i, v)
        error("illegal global write: " .. tostring(i)..": "..tostring(v), 2)
    end
    local env = setmetatable({}, { __index=errR, __newindex=errW })
    noglobals = function()
        pcall(setfenv, 3, env)
    end
    function getglobal(k) rawget(env, k) end
    function setglobal(k, v) rawset(env, k, v) end
else
    noglobals = nop
end



local _ENV = noglobals() ------------------------------------------------------



local util = {
    nop = nop,
    noglobals = noglobals,
    getglobal = getglobal,
    setglobal = setglobal
}

util.unpack = t.unpack or unpack
util.pack = t.pack or function(...) return { n = select('#', ...), ... } end


if compat.lua51 then
    local old_load = load

   function util.load (ld, source, mode, env)
     -- We ignore mode. Both source and bytecode can be loaded.
     local fun
     if type (ld) == 'string' then
       fun = loadstring (ld)
     else
       fun = old_load (ld, source)
     end
     if env then
       setfenv (fun, env)
     end
     return fun
   end
else
    util.load = load
end

if compat.luajit and compat.jit then
    function util.max (ary)
        local max = 0
        for i = 1, #ary do
            max = m_max(max,ary[i])
        end
        return max
    end
elseif compat.luajit then
    local t_unpack = util.unpack
    function util.max (ary)
     local len = #ary
        if len <=30 or len > 10240 then
            local max = 0
            for i = 1, #ary do
                local j = ary[i]
                if j > max then max = j end
            end
            return max
        else
            return m_max(t_unpack(ary))
        end
    end
else
    local t_unpack = util.unpack
    local safe_len = 1000
    function util.max(array)
        -- Thanks to Robert G. Jakabosky for this implementation.
        local len = #array
        if len == 0 then return -1 end -- FIXME: shouldn't this be `return -1`?
        local off = 1
        local off_end = safe_len
        local max = array[1] -- seed max.
        repeat
            if off_end > len then off_end = len end
            local seg_max = m_max(t_unpack(array, off, off_end))
            if seg_max > max then
                max = seg_max
            end
            off = off + safe_len
            off_end = off_end + safe_len
        until off >= len
        return max
    end
end


local
function setmode(t,mode)
    local mt = getmetatable(t) or {}
    if mt.__mode then
        error("The mode has already been set on table "..tostring(t)..".")
    end
    mt.__mode = mode
    return setmetatable(t, mt)
end

util.setmode = setmode

function util.weakboth (t)
    return setmode(t,"kv")
end

function util.weakkey (t)
    return setmode(t,"k")
end

function util.weakval (t)
    return setmode(t,"v")
end

function util.strip_mt (t)
    return setmetatable(t, nil)
end

local getuniqueid
do
    local N, index = 0, {}
    function getuniqueid(v)
        if not index[v] then
            N = N + 1
            index[v] = N
        end
        return index[v]
    end
end
util.getuniqueid = getuniqueid

do
    local counter = 0
    function util.gensym ()
        counter = counter + 1
        return "___SYM_"..counter
    end
end

function util.passprint (...) print(...) return ... end

local val_to_str_, key_to_str, table_tostring, cdata_to_str, t_cache
local multiplier = 2

local
function val_to_string (v, indent)
    indent = indent or 0
    t_cache = {} -- upvalue.
    local acc = {}
    val_to_str_(v, acc, indent, indent)
    local res = t_concat(acc, "")
    return res
end
util.val_to_str = val_to_string

function val_to_str_ ( v, acc, indent, str_indent )
    str_indent = str_indent or 1
    if "string" == type( v ) then
        v = s_gsub( v, "\n",  "\n" .. (" "):rep( indent * multiplier + str_indent ) )
        if s_match( s_gsub( v,"[^'\"]",""), '^"+$' ) then
            acc[#acc+1] = t_concat{ "'", "", v, "'" }
        else
            acc[#acc+1] = t_concat{'"', s_gsub(v,'"', '\\"' ), '"' }
        end
    elseif "cdata" == type( v ) then
            cdata_to_str( v, acc, indent )
    elseif "table" == type(v) then
        if t_cache[v] then
            acc[#acc+1] = t_cache[v]
        else
            t_cache[v] = tostring( v )
            table_tostring( v, acc, indent )
        end
    else
        acc[#acc+1] = tostring( v )
    end
end

function key_to_str ( k, acc, indent )
    if "string" == type( k ) and s_match( k, "^[_%a][_%a%d]*$" ) then
        acc[#acc+1] = s_gsub( k, "\n", (" "):rep( indent * multiplier + 1 ) .. "\n" )
    else
        acc[#acc+1] = "[ "
        val_to_str_( k, acc, indent )
        acc[#acc+1] = " ]"
    end
end

function cdata_to_str(v, acc, indent)
    acc[#acc+1] = ( " " ):rep( indent * multiplier )
    acc[#acc+1] = "["
    print(#acc)
    for i = 0, #v do
        if i % 16 == 0 and i ~= 0 then
            acc[#acc+1] = "\n"
            acc[#acc+1] = (" "):rep(indent * multiplier + 2)
        end
        acc[#acc+1] = v[i] and 1 or 0
        acc[#acc+1] = i ~= #v and  ", " or ""
    end
    print(#acc, acc[1], acc[2])
    acc[#acc+1] = "]"
end

function table_tostring ( tbl, acc, indent )
    -- acc[#acc+1] = ( " " ):rep( indent * multiplier )
    acc[#acc+1] = t_cache[tbl]
    acc[#acc+1] = "{\n"
    for k, v in pairs( tbl ) do
        local str_indent = 1
        acc[#acc+1] = (" "):rep((indent + 1) * multiplier)
        key_to_str( k, acc, indent + 1)

        if acc[#acc] == " ]"
        and acc[#acc - 2] == "[ "
        then str_indent = 8 + #acc[#acc - 1]
        end

        acc[#acc+1] = " = "
        val_to_str_( v, acc, indent + 1, str_indent)
        acc[#acc+1] = "\n"
    end
    acc[#acc+1] = ( " " ):rep( indent * multiplier )
    acc[#acc+1] = "}"
end

function util.expose(v) print(val_to_string(v)) return v end
-------------------------------------------------------------------------------
--- Functional helpers
--

function util.map (ary, func, ...)
    if type(ary) == "function" then ary, func = func, ary end
    local res = {}
    for i = 1,#ary do
        res[i] = func(ary[i], ...)
    end
    return res
end

function util.selfmap (ary, func, ...)
    if type(ary) == "function" then ary, func = func, ary end
    for i = 1,#ary do
        ary[i] = func(ary[i], ...)
    end
    return ary
end

local
function map_all (tbl, func, ...)
    if type(tbl) == "function" then tbl, func = func, tbl end
    local res = {}
    for k, v in next, tbl do
        res[k]=func(v, ...)
    end
    return res
end

util.map_all = map_all

local
function fold (ary, func, acc)
    local i0 = 1
    if not acc then
        acc = ary[1]
        i0 = 2
    end
    for i = i0, #ary do
        acc = func(acc,ary[i])
    end
    return acc
end
util.fold = fold

local
function foldr (ary, func, acc)
    local offset = 0
    if not acc then
        acc = ary[#ary]
        offset = 1
    end
    for i = #ary - offset, 1 , -1 do
        acc = func(ary[i], acc)
    end
    return acc
end
util.foldr = foldr

local
function map_fold(ary, mfunc, ffunc, acc)
    local i0 = 1
    if not acc then
        acc = mfunc(ary[1])
        i0 = 2
    end
    for i = i0, #ary do
        acc = ffunc(acc,mfunc(ary[i]))
    end
    return acc
end
util.map_fold = map_fold

local
function map_foldr(ary, mfunc, ffunc, acc)
    local offset = 0
    if not acc then
        acc = mfunc(ary[#acc])
        offset = 1
    end
    for i = #ary - offset, 1 , -1 do
        acc = ffunc(mfunc(ary[i], acc))
    end
    return acc
end
util.map_foldr = map_fold

function util.zip(a1, a2)
    local res, len = {}, m_max(#a1,#a2)
    for i = 1,len do
        res[i] = {a1[i], a2[i]}
    end
    return res
end

function util.zip_all(t1, t2)
    local res = {}
    for k,v in pairs(t1) do
        res[k] = {v, t2[k]}
    end
    for k,v in pairs(t2) do
        if res[k] == nil then
            res[k] = {t1[k], v}
        end
    end
    return res
end

function util.filter(ary,func)
    local res = {}
    for i = 1,#ary do
        if func(ary[i]) then
            t_insert(res, ary[i])
        end
    end

end

local
function id (...) return ... end
util.id = id



local function AND (a,b) return a and b end
local function OR  (a,b) return a or b  end

function util.copy (tbl) return map_all(tbl, id) end

function util.all (ary, mfunc)
    if mfunc then
        return map_fold(ary, mfunc, AND)
    else
        return fold(ary, AND)
    end
end

function util.any (ary, mfunc)
    if mfunc then
        return map_fold(ary, mfunc, OR)
    else
        return fold(ary, OR)
    end
end

function util.get(field)
    return function(tbl) return tbl[field] end
end

function util.lt(ref)
    return function(val) return val < ref end
end

-- function util.lte(ref)
--     return function(val) return val <= ref end
-- end

-- function util.gt(ref)
--     return function(val) return val > ref end
-- end

-- function util.gte(ref)
--     return function(val) return val >= ref end
-- end

function util.compose(f,g)
    return function(...) return f(g(...)) end
end

function util.extend (destination, ...)
    for i = 1, select('#', ...) do
        for k,v in pairs((select(i, ...))) do
            destination[k] = v
        end
    end
    return destination
end

function util.setify (t)
    local set = {}
    for i = 1, #t do
        set[t[i]]=true
    end
    return set
end

function util.arrayify (...) return {...} end


local
function _checkstrhelper(s)
    return s..""
end

function util.checkstring(s, func)
    local success, str = pcall(_checkstrhelper, s)
    if not success then 
        if func == nil then func = "?" end
        error("bad argument to '"
            ..tostring(func)
            .."' (string expected, got "
            ..type(s)
            ..")",
        2)
    end
    return str
end



return util

--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The PureLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["compiler"])sources["compiler"]=([===[-- <pack compiler> --
local assert, error, pairs, print, rawset, select, setmetatable, tostring, type
    = assert, error, pairs, print, rawset, select, setmetatable, tostring, type

--[[DBG]] local debug, print = debug, print

local s, t, u = require"string", require"table", require"util"



local _ENV = u.noglobals() ----------------------------------------------------



local s_byte, s_sub, t_concat, t_insert, t_remove, t_unpack
    = s.byte, s.sub, t.concat, t.insert, t.remove, u.unpack

local   load,   map,   map_all, t_pack
    = u.load, u.map, u.map_all, u.pack

local expose = u.expose

return function(Builder, LL)
local evaluate, LL_ispattern =  LL.evaluate, LL.ispattern
local charset = Builder.charset



local compilers = {}


local
function compile(pt, ccache)
    -- print("Compile", pt.pkind)
    if not LL_ispattern(pt) then
        --[[DBG]] expose(pt)
        error("pattern expected")
    end
    local typ = pt.pkind
    if typ == "grammar" then
        ccache = {}
    elseif typ == "ref" or typ == "choice" or typ == "sequence" then
        if not ccache[pt] then
            ccache[pt] = compilers[typ](pt, ccache)
        end
        return ccache[pt]
    end
    if not pt.compiled then
        -- [[DBG]] print("Not compiled:")
        -- [[DBG]] LL.pprint(pt)
        pt.compiled = compilers[pt.pkind](pt, ccache)
    end

    return pt.compiled
end
LL.compile = compile


local
function clear_captures(ary, ci)
    -- [[DBG]] print("clear caps, ci = ", ci)
    -- [[DBG]] print("TRACE: ", debug.traceback(1))
    -- [[DBG]] expose(ary)
    for i = ci, #ary do ary[i] = nil end
    -- [[DBG]] expose(ary)
    -- [[DBG]] print("/clear caps --------------------------------")
end


local LL_compile, LL_evaluate, LL_P
    = LL.compile, LL.evaluate, LL.P

local function computeidex(i, len)
    if i == 0 or i == 1 or i == nil then return 1
    elseif type(i) ~= "number" then error"number or nil expected for the stating index"
    elseif i > 0 then return i > len and len + 1 or i
    else return len + i < 0 and 1 or len + i + 1
    end
end


------------------------------------------------------------------------------
--- Match

--[[DBG]] local dbgcapsmt = {__newindex = function(self, k,v) 
--[[DBG]]     if k ~= #self + 1 then 
--[[DBG]]         print("Bad new cap", k, v)
--[[DBG]]         expose(self)
--[[DBG]]         error""
--[[DBG]]     else
--[[DBG]]         rawset(self,k,v)
--[[DBG]]     end
--[[DBG]] end}

--[[DBG]] local
--[[DBG]] function dbgcaps(t) return setmetatable(t, dbgcapsmt) end
local function newcaps()
    return {
        kind = {}, 
        bounds = {},
        openclose = {},
        aux = -- [[DBG]] dbgcaps
            {}
    }
end

local
function _match(dbg, pt, sbj, si, ...)
        if dbg then -------------
            print("@!!! Match !!!@", pt)
        end ---------------------

    pt = LL_P(pt)

    assert(type(sbj) == "string", "string expected for the match subject")
    si = computeidex(si, #sbj)

        if dbg then -------------
            print(("-"):rep(30))
            print(pt.pkind)
            LL.pprint(pt)
        end ---------------------

    local matcher = compile(pt, {})
    -- capture accumulator
    local caps = newcaps()
    local matcher_state = {grammars = {}, args = {n = select('#',...),...}, tags = {}} 

    local  success, final_si, ci = matcher(sbj, si, caps, 1, matcher_state)

        if dbg then -------------
            print("!!! Done Matching !!! success: ", success, 
                "final position", final_si, "final cap index", ci,
                "#caps", #caps.openclose)
        end----------------------

    if success then
            -- if dbg then -------------
                -- print"Pre-clear-caps"
                -- expose(caps)
            -- end ---------------------

        clear_captures(caps.kind, ci)
        clear_captures(caps.aux, ci)

            if dbg then -------------
            print("trimmed cap index = ", #caps + 1)
            -- expose(caps)
            LL.cprint(caps, sbj, 1)
            end ---------------------

        local values, _, vi = LL_evaluate(caps, sbj, 1, 1)

            if dbg then -------------
                print("#values", vi)
                expose(values)
            end ---------------------

        if vi == 0
        then return final_si
        else return t_unpack(values, 1, vi) end
    else
        if dbg then print("Failed") end
        return nil
    end
end

function LL.match(...)
    return _match(false, ...) 
end

-- With some debug info.
function LL.dmatch(...)
    return _match(true, ...) 
end

------------------------------------------------------------------------------
----------------------------------  ,--. ,--. ,--. |_  ,  , ,--. ,--. ,--.  --
--- Captures                        |    .--| |__' |   |  | |    |--' '--,
--                                  `--' `--' |    `-- `--' '    `--' `--'


-- These are all alike:


for _, v in pairs{ 
    "C", "Cf", "Cg", "Cs", "Ct", "Clb",
    "div_string", "div_table", "div_number", "div_function"
} do
    compilers[v] = load(([=[
    local compile, expose, type, LL = ...
    return function (pt, ccache)
        -- [[DBG]] print("Compiling", "XXXX")
        -- [[DBG]] expose(LL.getdirect(pt))
        -- [[DBG]] LL.pprint(pt)
        local matcher, this_aux = compile(pt.pattern, ccache), pt.aux
        return function (sbj, si, caps, ci, state)
            -- [[DBG]] print("XXXX: ci = ", ci, "             ", "", ", si = ", si, ", type(this_aux) = ", type(this_aux), this_aux)
            -- [[DBG]] expose(caps)

            local ref_ci = ci

            local kind, bounds, openclose, aux 
                = caps.kind, caps.bounds, caps.openclose, caps.aux

            kind      [ci] = "XXXX"
            bounds    [ci] = si
            -- openclose = 0 ==> bound is lower bound of the capture.
            openclose [ci] = 0
            caps.aux       [ci] = (this_aux or false)

            local success

            success, si, ci
                = matcher(sbj, si, caps, ci + 1, state)
            if success then
                -- [[DBG]] print("/XXXX: ci = ", ci, ", ref_ci = ", ref_ci, ", si = ", si)
                if ci == ref_ci + 1 then
                    -- [[DBG]] print("full", si)
                    -- a full capture, ==> openclose > 0 == the closing bound.
                    caps.openclose[ref_ci] = si
                else
                    -- [[DBG]] print("closing", si)
                    kind      [ci] = "XXXX"
                    bounds    [ci] = si
                    -- a closing bound. openclose < 0 
                    -- (offset in the capture stack between open and close)
                    openclose [ci] = ref_ci - ci
                    aux       [ci] = this_aux or false
                    ci = ci + 1
                end
                -- [[DBG]] expose(caps)
            else
                ci = ci - 1
                -- [[DBG]] print("///XXXX: ci = ", ci, ", ref_ci = ", ref_ci, ", si = ", si)
                -- [[DBG]] expose(caps)
            end
            return success, si, ci
        end
    end]=]):gsub("XXXX", v), v.." compiler")(compile, expose, type, LL)
end




compilers["Carg"] = function (pt, ccache)
    local n = pt.aux
    return function (sbj, si, caps, ci, state)
        if state.args.n < n then error("reference to absent argument #"..n) end
        caps.kind      [ci] = "value"
        caps.bounds    [ci] = si
        -- trick to keep the aux a proper sequence, so that #aux behaves.
        -- if the value is nil, we set both openclose and aux to
        -- +infinity, and handle it appropriately when it is eventually evaluated.
        -- openclose holds a positive value ==> full capture.
        if state.args[n] == nil then
            caps.openclose [ci] = 1/0
            caps.aux       [ci] = 1/0
        else
            caps.openclose [ci] = si
            caps.aux       [ci] = state.args[n]
        end
        return true, si, ci + 1
    end
end

for _, v in pairs{ 
    "Cb", "Cc", "Cp"
} do
    compilers[v] = load(([=[
    -- [[DBG]]local expose = ...
    return function (pt, ccache)
        local this_aux = pt.aux
        return function (sbj, si, caps, ci, state)
            -- [[DBG]] print("XXXX: ci = ", ci, ", aux = ", this_aux, ", si = ", si)

            caps.kind      [ci] = "XXXX"
            caps.bounds    [ci] = si
            caps.openclose [ci] = si
            caps.aux       [ci] = this_aux or false

            -- [[DBG]] expose(caps)
            return true, si, ci + 1
        end
    end]=]):gsub("XXXX", v), v.." compiler")(expose)
end


compilers["/zero"] = function (pt, ccache)
    local matcher = compile(pt.pattern, ccache)
    return function (sbj, si, caps, ci, state)
        local success, nsi = matcher(sbj, si, caps, ci, state)

        clear_captures(caps.aux, ci)

        return success, nsi, ci
    end
end


local function pack_Cmt_caps(i,...) return i, t_pack(...) end

-- [[DBG]] local MT = 0
compilers["Cmt"] = function (pt, ccache)
    local matcher, func = compile(pt.pattern, ccache), pt.aux
    -- [[DBG]] local mt, n = MT, 0
    -- [[DBG]] MT = MT + 1
    return function (sbj, si, caps, ci, state)
        -- [[DBG]] n = n + 1
        -- [[DBG]] print("\nCmt start, si = ", si, ", ci = ", ci, ".....",  (" <"..mt.."> "..n):rep(8))
        -- [[DBG]] expose(caps)

        local success, Cmt_si, Cmt_ci = matcher(sbj, si, caps, ci, state)
        if not success then 
            -- [[DBG]] print("/Cmt No match", ".....",  (" -"..mt.."- "..n):rep(12))
            -- [[DBG]] n = n - 1
            clear_captures(caps.aux, ci)
            -- [[DBG]] expose(caps)

            return false, si, ci
        end
        -- [[DBG]] print("Cmt match! ci = ", ci, ", Cmt_ci = ", Cmt_ci)
        -- [[DBG]] expose(caps)

        local final_si, values 

        if Cmt_ci == ci then
            -- [[DBG]] print("Cmt: simple capture: ", si, Cmt_si, s_sub(sbj, si, Cmt_si - 1))
            final_si, values = pack_Cmt_caps(
                func(sbj, Cmt_si, s_sub(sbj, si, Cmt_si - 1))
            )
        else
            -- [[DBG]] print("Cmt: EVAL: ", ci, Cmt_ci)
            clear_captures(caps.aux, Cmt_ci)
            clear_captures(caps.kind, Cmt_ci)
            local cps, _, nn = evaluate(caps, sbj, ci)
            -- [[DBG]] print("POST EVAL ncaps = ", nn)
            -- [[DBG]] expose(cps)
            -- [[DBG]] print("----------------------------------------------------------------")
                        final_si, values = pack_Cmt_caps(
                func(sbj, Cmt_si, t_unpack(cps, 1, nn))
            )
        end
        -- [[DBG]] print("Cmt values ..."); expose(values)
        -- [[DBG]] print("Cmt, final_si = ", final_si, ", Cmt_si = ", Cmt_si)
        -- [[DBG]] print("SOURCE\n",sbj:sub(Cmt_si-20, Cmt_si+20),"\n/SOURCE")
        if not final_si then 
            -- [[DBG]] print("/Cmt No return", ".....",  (" +"..mt.."- "..n):rep(12))
            -- [[DBG]] n = n - 1
            -- clear_captures(caps.aux, ci)
            -- [[DBG]] expose(caps)
            return false, si, ci
        end

        if final_si == true then final_si = Cmt_si end

        if type(final_si) == "number"
        and si <= final_si 
        and final_si <= #sbj + 1 
        then
            -- [[DBG]] print("Cmt Success", values, values and values.n, ci)
            local kind, bounds, openclose, aux 
                = caps.kind, caps.bounds, caps.openclose, caps.aux
            for i = 1, values.n do
                kind      [ci] = "value"
                bounds    [ci] = si
                -- See Carg for the rationale of 1/0.
                if values[i] == nil then
                    caps.openclose [ci] = 1/0
                    caps.aux       [ci] = 1/0
                else
                    caps.openclose [ci] = final_si
                    caps.aux       [ci] = values[i]
                end

                ci = ci + 1
            end
        elseif type(final_si) == "number" then
            error"Index out of bounds returned by match-time capture."
        else
            error("Match time capture must return a number, a boolean or nil"
                .." as first argument, or nothing at all.")
        end
            -- [[DBG]] print("/Cmt success - si = ", si,  ", ci = ", ci, ".....",  (" +"..mt.."+ "..n):rep(8))
            -- [[DBG]] n = n - 1
            -- [[DBG]] expose(caps)
        return true, final_si, ci
    end
end


------------------------------------------------------------------------------
------------------------------------  ,-.  ,--. ,-.     ,--. ,--. ,--. ,--. --
--- Other Patterns                    |  | |  | |  | -- |    ,--| |__' `--.
--                                    '  ' `--' '  '    `--' `--' |    `--'


compilers["string"] = function (pt, ccache)
    local S = pt.aux
    local N = #S
    return function(sbj, si, caps, ci, state)
         -- [[DBG]] print("String    ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
        local in_1 = si - 1
        for i = 1, N do
            local c
            c = s_byte(sbj,in_1 + i)
            if c ~= S[i] then
         -- [[DBG]] print("%FString    ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
                return false, si, ci
            end
        end
         -- [[DBG]] print("%SString    ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
        return true, si + N, ci
    end
end


compilers["char"] = function (pt, ccache)
    return load(([=[
        local s_byte, s_char = ...
        return function(sbj, si, caps, ci, state)
            -- [[DBG]] print("Char "..s_char(__C0__).." ", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
            local c, nsi = s_byte(sbj, si), si + 1
            if c ~= __C0__ then
                return false, si, ci
            end
            return true, nsi, ci
        end]=]):gsub("__C0__", tostring(pt.aux)))(s_byte, ("").char)
end


local
function truecompiled (sbj, si, caps, ci, state)
     -- [[DBG]] print("True    ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
    return true, si, ci
end
compilers["true"] = function (pt)
    return truecompiled
end


local
function falsecompiled (sbj, si, caps, ci, state)
     -- [[DBG]] print("False   ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
    return false, si, ci
end
compilers["false"] = function (pt)
    return falsecompiled
end


local
function eoscompiled (sbj, si, caps, ci, state)
     -- [[DBG]] print("EOS     ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
    return si > #sbj, si, ci
end
compilers["eos"] = function (pt)
    return eoscompiled
end


local
function onecompiled (sbj, si, caps, ci, state)
    -- [[DBG]] print("One", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
    local char, _ = s_byte(sbj, si), si + 1
    if char
    then return true, si + 1, ci
    else return false, si, ci end
end

compilers["one"] = function (pt)
    return onecompiled
end


compilers["any"] = function (pt)
    local N = pt.aux
    if N == 1 then
        return onecompiled
    else
        N = pt.aux - 1
        return function (sbj, si, caps, ci, state)
            -- [[DBG]] print("Any", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
            local n = si + N
            if n <= #sbj then
                -- [[DBG]] print("/Any success", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
                return true, n + 1, ci
            else
                -- [[DBG]] print("/Any fail", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
                return false, si, ci
            end
        end
    end
end


do
    local function checkpatterns(g)
        for k,v in pairs(g.aux) do
            if not LL_ispattern(v) then
                error(("rule 'A' is not a pattern"):gsub("A", tostring(k)))
            end
        end
    end

    compilers["grammar"] = function (pt, ccache)
        checkpatterns(pt)
        local gram = map_all(pt.aux, compile, ccache)
        local start = gram[1]
        return function (sbj, si, caps, ci, state)
             -- [[DBG]] print("Grammar ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
            t_insert(state.grammars, gram)
            local success, nsi, ci = start(sbj, si, caps, ci, state)
            t_remove(state.grammars)
             -- [[DBG]] print("%Grammar ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
            return success, nsi, ci
        end
    end
end

local dummy_acc = {kind={}, bounds={}, openclose={}, aux={}}
compilers["behind"] = function (pt, ccache)
    local matcher, N = compile(pt.pattern, ccache), pt.aux
    return function (sbj, si, caps, ci, state)
         -- [[DBG]] print("Behind  ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
        if si <= N then return false, si, ci end

        local success = matcher(sbj, si - N, dummy_acc, ci, state)
        -- note that behid patterns cannot hold captures.
        dummy_acc.aux = {}
        return success, si, ci
    end
end

compilers["range"] = function (pt)
    local ranges = pt.aux
    return function (sbj, si, caps, ci, state)
         -- [[DBG]] print("Range   ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
        local char, nsi = s_byte(sbj, si), si + 1
        for i = 1, #ranges do
            local r = ranges[i]
            if char and r[char]
            then return true, nsi, ci end
        end
        return false, si, ci
    end
end

compilers["set"] = function (pt)
    local s = pt.aux
    return function (sbj, si, caps, ci, state)
        -- [[DBG]] print("Set, Set!, si = ",si, ", ci = ", ci)
        -- [[DBG]] expose(s)
        local char, nsi = s_byte(sbj, si), si + 1
        -- [[DBG]] print("Set, Set!, nsi = ",nsi, ", ci = ", ci, "char = ", char, ", success = ", (not not s[char]))
        if s[char]
        then return true, nsi, ci
        else return false, si, ci end
    end
end

-- hack, for now.
compilers["range"] = compilers.set

compilers["ref"] = function (pt, ccache)
    local name = pt.aux
    local ref
    return function (sbj, si, caps, ci, state)
         -- [[DBG]] print("Reference",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
        if not ref then
            if #state.grammars == 0 then
                error(("rule 'XXXX' used outside a grammar"):gsub("XXXX", tostring(name)))
            elseif not state.grammars[#state.grammars][name] then
                error(("rule 'XXXX' undefined in given grammar"):gsub("XXXX", tostring(name)))
            end
            ref = state.grammars[#state.grammars][name]
        end
        -- [[DBG]] print("Ref - <"..tostring(name)..">, si = ", si, ", ci = ", ci)
        -- [[DBG]] LL.cprint(caps, 1, sbj)
            local success, nsi, nci = ref(sbj, si, caps, ci, state)
        -- [[DBG]] print("/ref - <"..tostring(name)..">, si = ", si, ", ci = ", ci)
        -- [[DBG]] LL.cprint(caps, 1, sbj)
        return success, nsi, nci
    end
end



-- Unroll the loop using a template:
local choice_tpl = [=[
             -- [[DBG]] print(" Choice XXXX, si = ", si, ", ci = ", ci)
            success, si, ci = XXXX(sbj, si, caps, ci, state)
             -- [[DBG]] print(" /Choice XXXX, si = ", si, ", ci = ", ci, ", success = ", success)
            if success then
                return true, si, ci
            else
                --clear_captures(aux, ci)
            end]=]

local function flatten(kind, pt, ccache)
    if pt[2].pkind == kind then
        return compile(pt[1], ccache), flatten(kind, pt[2], ccache)
    else
        return compile(pt[1], ccache), compile(pt[2], ccache)
    end
end

compilers["choice"] = function (pt, ccache)
    local choices = {flatten("choice", pt, ccache)}
    local names, chunks = {}, {}
    for i = 1, #choices do
        local m = "ch"..i
        names[#names + 1] = m
        chunks[ #names  ] = choice_tpl:gsub("XXXX", m)
    end
    names[#names + 1] = "clear_captures"
    choices[ #names ] = clear_captures
    local compiled = t_concat{
        "local ", t_concat(names, ", "), [=[ = ...
        return function (sbj, si, caps, ci, state)
             -- [[DBG]] print("Choice ", ", si = "..si, ", ci = "..ci, sbj:sub(1, si-1)) --, sbj)
            local aux, success = caps.aux, false
            ]=],
            t_concat(chunks,"\n"),[=[--
             -- [[DBG]] print("/Choice ", ", si = "..si, ", ci = "..ci, sbj:sub(1, si-1)) --, sbj)
            return false, si, ci
        end]=]
    }
    -- print(compiled)
    return load(compiled, "Choice")(t_unpack(choices))
end



local sequence_tpl = [=[
            -- [[DBG]] print(" Seq XXXX , si = ",si, ", ci = ", ci)
            success, si, ci = XXXX(sbj, si, caps, ci, state)
            -- [[DBG]] print(" /Seq XXXX , si = ",si, ", ci = ", ci, ", success = ", success)
            if not success then
                -- clear_captures(caps.aux, ref_ci)
                return false, ref_si, ref_ci
            end]=]
compilers["sequence"] = function (pt, ccache)
    local sequence = {flatten("sequence", pt, ccache)}
    local names, chunks = {}, {}
    -- print(n)
    -- for k,v in pairs(pt.aux) do print(k,v) end
    for i = 1, #sequence do
        local m = "seq"..i
        names[#names + 1] = m
        chunks[ #names  ] = sequence_tpl:gsub("XXXX", m)
    end
    names[#names + 1] = "clear_captures"
    sequence[ #names ] = clear_captures
    local compiled = t_concat{
        "local ", t_concat(names, ", "), [=[ = ...
        return function (sbj, si, caps, ci, state)
            local ref_si, ref_ci, success = si, ci
             -- [[DBG]] print("Sequence ", ", si = "..si, ", ci = "..ci, sbj:sub(1, si-1)) --, sbj)
            ]=],
            t_concat(chunks,"\n"),[=[
             -- [[DBG]] print("/Sequence ", ", si = "..si, ", ci = "..ci, sbj:sub(1, si-1)) --, sbj)
            return true, si, ci
        end]=]
    }
    -- print(compiled)
   return load(compiled, "Sequence")(t_unpack(sequence))
end


compilers["at most"] = function (pt, ccache)
    local matcher, n = compile(pt.pattern, ccache), pt.aux
    n = -n
    return function (sbj, si, caps, ci, state)
         -- [[DBG]] print("At most   ",caps, caps and caps.kind or "'nil'", si) --, sbj)
        local success = true
        for i = 1, n do
            success, si, ci = matcher(sbj, si, caps, ci, state)
            if not success then 
                -- clear_captures(caps.aux, ci)
                break
            end
        end
        return true, si, ci
    end
end

compilers["at least"] = function (pt, ccache)
    local matcher, n = compile(pt.pattern, ccache), pt.aux
    if n == 0 then
        return function (sbj, si, caps, ci, state)
            -- [[DBG]] print("Rep  0", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
            local last_si, last_ci
            while true do
                local success
                -- [[DBG]] print(" rep  0", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
                -- [[DBG]] N=N+1
                last_si, last_ci = si, ci
                success, si, ci = matcher(sbj, si, caps, ci, state)
                if not success then                     
                    si, ci = last_si, last_ci
                    break
                end
            end
            -- [[DBG]] print("/rep  0", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
            -- clear_captures(caps.aux, ci)
            return true, si, ci
        end
    elseif n == 1 then
        return function (sbj, si, caps, ci, state)
            -- [[DBG]] print("At least 1 ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sbj)
            local last_si, last_ci
            local success = true
            -- [[DBG]] print("Rep  1", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci)
            success, si, ci = matcher(sbj, si, caps, ci, state)
            if not success then
            -- [[DBG]] print("/Rep  1 Fail")
                -- clear_captures(caps.aux, ci)
                return false, si, ci
            end
            while true do
                local success
                -- [[DBG]] print(" rep  1", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
                -- [[DBG]] N=N+1
                last_si, last_ci = si, ci
                success, si, ci = matcher(sbj, si, caps, ci, state)
                if not success then                     
                    si, ci = last_si, last_ci
                    break
                end
            end
            -- [[DBG]] print("/rep  1", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
             -- clear_captures(caps.aux, ci)
            return true, si, ci
        end
    else
        return function (sbj, si, caps, ci, state)
            -- [[DBG]] print("At least "..n.." ", caps and caps.kind or "'nil'", ci, si, state) --, sbj)
            local last_si, last_ci
            local success = true
            for _ = 1, n do
                success, si, ci = matcher(sbj, si, caps, ci, state)
                if not success then
                    -- clear_captures(caps.aux, ci)
                    return false, si, ci
                end
            end
            while true do
                local success
                -- [[DBG]] print(" rep  "..n, caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
                last_si, last_ci = si, ci
                success, si, ci = matcher(sbj, si, caps, ci, state)
                if not success then                     
                    si, ci = last_si, last_ci
                    break
                end
            end
            -- [[DBG]] print("/rep  "..n, caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
            -- clear_captures(caps.aux, ci)
            return true, si, ci
        end
    end
end

compilers["unm"] = function (pt, ccache)
    -- P(-1)
    if pt.pkind == "any" and pt.aux == 1 then
        return eoscompiled
    end
    local matcher = compile(pt.pattern, ccache)
    return function (sbj, si, caps, ci, state)
         -- [[DBG]] print("Unm     ", caps, caps and caps.kind or "'nil'", ci, si, state)
        -- Throw captures away
        local success, _, _ = matcher(sbj, si, caps, ci, state)
        -- clear_captures(caps.aux, ci)
        return not success, si, ci
    end
end

compilers["lookahead"] = function (pt, ccache)
    local matcher = compile(pt.pattern, ccache)
    return function (sbj, si, caps, ci, state)
        -- [[DBG]] print("Look ", caps.kind[ci - 1], ", si = "..si, ", ci = "..ci, sbj:sub(1, si - 1))
        -- Throw captures away
        local success, _, _ = matcher(sbj, si, caps, ci, state)
         -- [[DBG]] print("Look, success = ", success, sbj:sub(1, si - 1))
         -- clear_captures(caps.aux, ci)
        return success, si, ci
    end
end

end

--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["datastructures"])sources["datastructures"]=([===[-- <pack datastructures> --
local getmetatable, pairs, setmetatable, type
    = getmetatable, pairs, setmetatable, type

--[[DBG]] local debug, print = debug, print

local m, t , u = require"math", require"table", require"util"


local compat = require"compat"
local ffi if compat.luajit then
    ffi = require"ffi"
end



local _ENV = u.noglobals() ----------------------------------------------------



local   extend,   load, u_max
    = u.extend, u.load, u.max

--[[DBG]] local expose = u.expose

local m_max, t_concat, t_insert, t_sort
    = m.max, t.concat, t.insert, t.sort

local structfor = {}

--------------------------------------------------------------------------------
--- Byte sets
--

-- Byte sets are sets whose elements are comprised between 0 and 255.
-- We provide two implemetations. One based on Lua tables, and the
-- other based on a FFI bool array.

local byteset_new, isboolset, isbyteset

local byteset_mt = {}

local
function byteset_constructor (upper)
    local set = setmetatable(load(t_concat{
        "return{ [0]=false",
        (", false"):rep(upper),
        " }"
    })(),
    byteset_mt)
    return set
end

if compat.jit then
    local struct, boolset_constructor = {v={}}

    function byteset_mt.__index(s,i)
        -- [[DBG]] print("GI", s,i)
        -- [[DBG]] print(debug.traceback())
        -- [[DBG]] if i == "v" then error("FOOO") end
        if i == nil or i > s.upper then return nil end
        return s.v[i]
    end
    function byteset_mt.__len(s)
        return s.upper
    end
    function byteset_mt.__newindex(s,i,v)
        -- [[DBG]] print("NI", i, v)
        s.v[i] = v
    end

    boolset_constructor = ffi.metatype('struct { int upper; bool v[?]; }', byteset_mt)

    function byteset_new (t)
        -- [[DBG]] print ("Konstructor", type(t), t)
        if type(t) == "number" then
            local res = boolset_constructor(t+1)
            res.upper = t
            --[[DBG]] for i = 0, res.upper do if res[i] then print("K", i, res[i]) end end
            return res
        end
        local upper = u_max(t)

        struct.upper = upper
        if upper > 255 then error"bool_set overflow" end
        local set = boolset_constructor(upper+1)
        set.upper = upper
        for i = 1, #t do set[t[i]] = true end

        return set
    end

    function isboolset(s) return type(s)=="cdata" and ffi.istype(s, boolset_constructor) end
    isbyteset = isboolset
else
    function byteset_new (t)
        -- [[DBG]] print("Set", t)
        if type(t) == "number" then return byteset_constructor(t) end
        local set = byteset_constructor(u_max(t))
        for i = 1, #t do set[t[i]] = true end
        return set
    end

    function isboolset(s) return false end
    function isbyteset (s)
        return getmetatable(s) == byteset_mt
    end
end

local
function byterange_new (low, high)
    -- [[DBG]] print("Range", low,high)
    high = ( low <= high ) and high or -1
    local set = byteset_new(high)
    for i = low, high do
        set[i] = true
    end
    return set
end


local tmpa, tmpb ={}, {}

local
function set_if_not_yet (s, dest)
    if type(s) == "number" then
        dest[s] = true
        return dest
    else
        return s
    end
end

local
function clean_ab (a,b)
    tmpa[a] = nil
    tmpb[b] = nil
end

local
function byteset_union (a ,b)
    local upper = m_max(
        type(a) == "number" and a or #a,
        type(b) == "number" and b or #b
    )
    local A, B
        = set_if_not_yet(a, tmpa)
        , set_if_not_yet(b, tmpb)

    local res = byteset_new(upper)
    for i = 0, upper do
        res[i] = A[i] or B[i] or false
        -- [[DBG]] print(i, res[i])
    end
    -- [[DBG]] print("BS Un ==========================")
    -- [[DBG]] print"/// A ///////////////////////  "
    -- [[DBG]] expose(a)
    -- [[DBG]] expose(A)
    -- [[DBG]] print"*** B ***********************  "
    -- [[DBG]] expose(b)
    -- [[DBG]] expose(B)
    -- [[DBG]] print"   RES   "
    -- [[DBG]] expose(res)
    clean_ab(a,b)
    return res
end

local
function byteset_difference (a, b)
    local res = {}
    for i = 0, 255 do
        res[i] = a[i] and not b[i]
    end
    return res
end

local
function byteset_tostring (s)
    local list = {}
    for i = 0, 255 do
        -- [[DBG]] print(s[i] == true and i)
        list[#list+1] = (s[i] == true) and i or nil
    end
    -- [[DBG]] print("BS TOS", t_concat(list,", "))
    return t_concat(list,", ")
end



structfor.binary = {
    set ={
        new = byteset_new,
        union = byteset_union,
        difference = byteset_difference,
        tostring = byteset_tostring
    },
    Range = byterange_new,
    isboolset = isboolset,
    isbyteset = isbyteset,
    isset = isbyteset
}

--------------------------------------------------------------------------------
--- Bit sets: TODO? to try, at least.
--

-- From Mike Pall's suggestion found at
-- http://lua-users.org/lists/lua-l/2011-08/msg00382.html

-- local bit = require("bit")
-- local band, bor = bit.band, bit.bor
-- local lshift, rshift, rol = bit.lshift, bit.rshift, bit.rol

-- local function bitnew(n)
--   return ffi.new("int32_t[?]", rshift(n+31, 5))
-- end

-- -- Note: the index 'i' is zero-based!
-- local function bittest(b, i)
--   return band(rshift(b[rshift(i, 5)], i), 1) ~= 0
-- end

-- local function bitset(b, i)
--   local x = rshift(i, 5); b[x] = bor(b[x], lshift(1, i))
-- end

-- local function bitclear(b, i)
--   local x = rshift(i, 5); b[x] = band(b[x], rol(-2, i))
-- end



-------------------------------------------------------------------------------
--- General case:
--

-- Set
--

local set_mt = {}

local
function set_new (t)
    -- optimization for byte sets.
    -- [[BS]] if all(map_all(t, function(e)return type(e) == "number" end))
    -- and u_max(t) <= 255
    -- or #t == 0
    -- then
    --     return byteset_new(t)
    -- end
    local set = setmetatable({}, set_mt)
    for i = 1, #t do set[t[i]] = true end
    return set
end

local -- helper for the union code.
function add_elements(a, res)
    -- [[BS]] if isbyteset(a) then
    --     for i = 0, 255 do
    --         if a[i] then res[i] = true end
    --     end
    -- else
    for k in pairs(a) do res[k] = true end
    return res
end

local
function set_union (a, b)
    -- [[BS]] if isbyteset(a) and isbyteset(b) then
    --     return byteset_union(a,b)
    -- end
    a, b = (type(a) == "number") and set_new{a} or a
         , (type(b) == "number") and set_new{b} or b
    local res = set_new{}
    add_elements(a, res)
    add_elements(b, res)
    return res
end

local
function set_difference(a, b)
    local list = {}
    -- [[BS]] if isbyteset(a) and isbyteset(b) then
    --     return byteset_difference(a,b)
    -- end
    a, b = (type(a) == "number") and set_new{a} or a
         , (type(b) == "number") and set_new{b} or b

    -- [[BS]] if isbyteset(a) then
    --     for i = 0, 255 do
    --         if a[i] and not b[i] then
    --             list[#list+1] = i
    --         end
    --     end
    -- elseif isbyteset(b) then
    --     for el in pairs(a) do
    --         if not byteset_has(b, el) then
    --             list[#list + 1] = i
    --         end
    --     end
    -- else
    for el in pairs(a) do
        if a[el] and not b[el] then
            list[#list+1] = el
        end
    end
    -- [[BS]] end
    return set_new(list)
end

local
function set_tostring (s)
    -- [[BS]] if isbyteset(s) then return byteset_tostring(s) end
    local list = {}
    for el in pairs(s) do
        t_insert(list,el)
    end
    t_sort(list)
    return t_concat(list, ",")
end

local
function isset (s)
    return (getmetatable(s) == set_mt)
        -- [[BS]] or isbyteset(s)
end


-- Range
--

-- For now emulated using sets.

local
function range_new (start, finish)
    local list = {}
    for i = start, finish do
        list[#list + 1] = i
    end
    return set_new(list)
end

-- local
-- function range_overlap (r1, r2)
--     return r1[1] <= r2[2] and r2[1] <= r1[2]
-- end

-- local
-- function range_merge (r1, r2)
--     if not range_overlap(r1, r2) then return nil end
--     local v1, v2 =
--         r1[1] < r2[1] and r1[1] or r2[1],
--         r1[2] > r2[2] and r1[2] or r2[2]
--     return newrange(v1,v2)
-- end

-- local
-- function range_isrange (r)
--     return getmetatable(r) == range_mt
-- end

structfor.other = {
    set = {
        new = set_new,
        union = set_union,
        tostring = set_tostring,
        difference = set_difference,
    },
    Range = range_new,
    isboolset = isboolset,
    isbyteset = isbyteset,
    isset = isset,
    isrange = function(a) return false end
}



return function(Builder, LL)
    local cs = (Builder.options or {}).charset or "binary"
    if type(cs) == "string" then
        cs = (cs == "binary") and "binary" or "other"
    else
        cs = cs.binary and "binary" or "other"
    end
    return extend(Builder, structfor[cs])
end


--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["re"])sources["re"]=([===[-- <pack re> --

-- re.lua by Roberto Ierusalimschy. see LICENSE in the root folder.

return function(Builder, LL)

-- $Id: re.lua,v 1.44 2013/03/26 20:11:40 roberto Exp $

-- imported functions and modules
local tonumber, type, print, error = tonumber, type, print, error
local setmetatable = setmetatable
local m = LL

-- 'm' will be used to parse expressions, and 'mm' will be used to
-- create expressions; that is, 're' runs on 'm', creating patterns
-- on 'mm'
local mm = m

-- pattern's metatable
local mt = getmetatable(mm.P(0))



-- No more global accesses after this point
local version = _VERSION
if version == "Lua 5.2" then _ENV = nil end


local any = m.P(1)


-- Pre-defined names
local Predef = { nl = m.P"\n" }


local mem
local fmem
local gmem


local function updatelocale ()
  mm.locale(Predef)
  Predef.a = Predef.alpha
  Predef.c = Predef.cntrl
  Predef.d = Predef.digit
  Predef.g = Predef.graph
  Predef.l = Predef.lower
  Predef.p = Predef.punct
  Predef.s = Predef.space
  Predef.u = Predef.upper
  Predef.w = Predef.alnum
  Predef.x = Predef.xdigit
  Predef.A = any - Predef.a
  Predef.C = any - Predef.c
  Predef.D = any - Predef.d
  Predef.G = any - Predef.g
  Predef.L = any - Predef.l
  Predef.P = any - Predef.p
  Predef.S = any - Predef.s
  Predef.U = any - Predef.u
  Predef.W = any - Predef.w
  Predef.X = any - Predef.x
  mem = {}    -- restart memoization
  fmem = {}
  gmem = {}
  local mt = {__mode = "v"}
  setmetatable(mem, mt)
  setmetatable(fmem, mt)
  setmetatable(gmem, mt)
end


updatelocale()



--[[DBG]] local I = m.P(function (s,i) print(i, s:sub(1, i-1)); return i end)


local function getdef (id, defs)
  local c = defs and defs[id]
  if not c then error("undefined name: " .. id) end
  return c
end


local function patt_error (s, i)
  local msg = (#s < i + 20) and s:sub(i)
                             or s:sub(i,i+20) .. "..."
  msg = ("pattern error near '%s'"):format(msg)
  error(msg, 2)
end

local function mult (p, n)
  local np = mm.P(true)
  while n >= 1 do
    if n%2 >= 1 then np = np * p end
    p = p * p
    n = n/2
  end
  return np
end

local function equalcap (s, i, c)
  if type(c) ~= "string" then return nil end
  local e = #c + i
  if s:sub(i, e - 1) == c then return e else return nil end
end


local S = (Predef.space + "--" * (any - Predef.nl)^0)^0

local name = m.R("AZ", "az", "__") * m.R("AZ", "az", "__", "09")^0

local arrow = S * "<-"

local seq_follow = m.P"/" + ")" + "}" + ":}" + "~}" + "|}" + (name * arrow) + -1

name = m.C(name)


-- a defined name only have meaning in a given environment
local Def = name * m.Carg(1)

local num = m.C(m.R"09"^1) * S / tonumber

local String = "'" * m.C((any - "'")^0) * "'" +
               '"' * m.C((any - '"')^0) * '"'


local defined = "%" * Def / function (c,Defs)
  local cat =  Defs and Defs[c] or Predef[c]
  if not cat then error ("name '" .. c .. "' undefined") end
  return cat
end

local Range = m.Cs(any * (m.P"-"/"") * (any - "]")) / mm.R

local item = defined + Range + m.C(any)

local Class =
    "["
  * (m.C(m.P"^"^-1))    -- optional complement symbol
  * m.Cf(item * (item - "]")^0, mt.__add) /
                          function (c, p) return c == "^" and any - p or p end
  * "]"

local function adddef (t, k, exp)
  if t[k] then
    error("'"..k.."' already defined as a rule")
  else
    t[k] = exp
  end
  return t
end

local function firstdef (n, r) return adddef({n}, n, r) end


local function NT (n, b)
  if not b then
    error("rule '"..n.."' used outside a grammar")
  else return mm.V(n)
  end
end


local exp = m.P{ "Exp",
  Exp = S * ( m.V"Grammar"
            + m.Cf(m.V"Seq" * ("/" * S * m.V"Seq")^0, mt.__add) );
  Seq = m.Cf(m.Cc(m.P"") * m.V"Prefix"^0 , mt.__mul)
        * (m.L(seq_follow) + patt_error);
  Prefix = "&" * S * m.V"Prefix" / mt.__len
         + "!" * S * m.V"Prefix" / mt.__unm
         + m.V"Suffix";
  Suffix = m.Cf(m.V"Primary" * S *
          ( ( m.P"+" * m.Cc(1, mt.__pow)
            + m.P"*" * m.Cc(0, mt.__pow)
            + m.P"?" * m.Cc(-1, mt.__pow)
            + "^" * ( m.Cg(num * m.Cc(mult))
                    + m.Cg(m.C(m.S"+-" * m.R"09"^1) * m.Cc(mt.__pow))
                    )
            + "->" * S * ( m.Cg((String + num) * m.Cc(mt.__div))
                         + m.P"{}" * m.Cc(nil, m.Ct)
                         + m.Cg(Def / getdef * m.Cc(mt.__div))
                         )
            + "=>" * S * m.Cg(Def / getdef * m.Cc(m.Cmt))
            ) * S
          )^0, function (a,b,f) return f(a,b) end );
  Primary = "(" * m.V"Exp" * ")"
            + String / mm.P
            + Class
            + defined
            + "{:" * (name * ":" + m.Cc(nil)) * m.V"Exp" * ":}" /
                     function (n, p) return mm.Cg(p, n) end
            + "=" * name / function (n) return mm.Cmt(mm.Cb(n), equalcap) end
            + m.P"{}" / mm.Cp
            + "{~" * m.V"Exp" * "~}" / mm.Cs
            + "{|" * m.V"Exp" * "|}" / mm.Ct
            + "{" * m.V"Exp" * "}" / mm.C
            + m.P"." * m.Cc(any)
            + (name * -arrow + "<" * name * ">") * m.Cb("G") / NT;
  Definition = name * arrow * m.V"Exp";
  Grammar = m.Cg(m.Cc(true), "G") *
            m.Cf(m.V"Definition" / firstdef * m.Cg(m.V"Definition")^0,
              adddef) / mm.P
}

local pattern = S * m.Cg(m.Cc(false), "G") * exp / mm.P * (-any + patt_error)


local function compile (p, defs)
  if mm.type(p) == "pattern" then return p end   -- already compiled
  local cp = pattern:match(p, 1, defs)
  if not cp then error("incorrect pattern", 3) end
  return cp
end

local function match (s, p, i)
  local cp = mem[p]
  if not cp then
    cp = compile(p)
    mem[p] = cp
  end
  return cp:match(s, i or 1)
end

local function find (s, p, i)
  local cp = fmem[p]
  if not cp then
    cp = compile(p) / 0
    cp = mm.P{ mm.Cp() * cp * mm.Cp() + 1 * mm.V(1) }
    fmem[p] = cp
  end
  local i, e = cp:match(s, i or 1)
  if i then return i, e - 1
  else return i
  end
end

local function gsub (s, p, rep)
  local g = gmem[p] or {}   -- ensure gmem[p] is not collected while here
  gmem[p] = g
  local cp = g[rep]
  if not cp then
    cp = compile(p)
    cp = mm.Cs((cp / rep + 1)^0)
    g[rep] = cp
  end
  return cp:match(s)
end


-- exported names
local re = {
  compile = compile,
  match = match,
  find = find,
  gsub = gsub,
  updatelocale = updatelocale,
}

-- if compat.lua51 or compat.luajit then _G.re = re end

return re

end
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["charsets"])sources["charsets"]=([===[-- <pack charsets> --

-- Charset handling


-- FIXME:
-- Currently, only
-- * `binary_get_int()`,
-- * `binary_split_int()` and
-- * `binary_validate()`
-- are effectively used by the client code.

-- *_next_int, *_split_, *_get_ and *_next_char should probably be disposed of.



-- We provide:
-- * utf8_validate(subject, start, finish) -- validator
-- * utf8_split_int(subject)               --> table{int}
-- * utf8_split_char(subject)              --> table{char}
-- * utf8_next_int(subject, index)         -- iterator
-- * utf8_next_char(subject, index)        -- iterator
-- * utf8_get_int(subject, index)          -- Julia-style iterator
--                                            returns int, next_index
-- * utf8_get_char(subject, index)         -- Julia-style iterator
--                                            returns char, next_index
--
-- See each function for usage.


local s, t, u = require"string", require"table", require"util"



local _ENV = u.noglobals() ----------------------------------------------------



local copy = u.copy

local s_char, s_sub, s_byte, t_concat, t_insert
    = s.char, s.sub, s.byte, t.concat, t.insert

-------------------------------------------------------------------------------
--- UTF-8
--

-- Utility function.
-- Modified from code by Kein Hong Man <khman@users.sf.net>,
-- found at http://lua-users.org/wiki/SciteUsingUnicode.

local
function utf8_offset (byte)
    if byte < 128 then return 0, byte
    elseif byte < 192 then
        error("Byte values between 0x80 to 0xBF cannot start a multibyte sequence")
    elseif byte < 224 then return 1, byte - 192
    elseif byte < 240 then return 2, byte - 224
    elseif byte < 248 then return 3, byte - 240
    elseif byte < 252 then return 4, byte - 248
    elseif byte < 254 then return 5, byte - 252
    else
        error("Byte values between 0xFE and OxFF cannot start a multibyte sequence")
    end
end


-- validate a given (sub)string.
-- returns two values:
-- * The first is either true, false or nil, respectively on success, error, or
--   incomplete subject.
-- * The second is the index of the last byte of the last valid char.
local
function utf8_validate (subject, start, finish)
    start = start or 1
    finish = finish or #subject

    local offset, char
        = 0
    for i = start,finish do
        local b = s_byte(subject,i)
        if offset == 0 then
            char = i
            success, offset = pcall(utf8_offset, b)
            if not success then return false, char - 1 end
        else
            if not (127 < b and b < 192) then
                return false, char - 1
            end
            offset = offset -1
        end
    end
    if offset ~= 0 then return nil, char - 1 end -- Incomplete input.
    return true, finish
end

-- Usage:
--     for finish, start, cpt in utf8_next_int, "˙†ƒ˙©√" do
--         print(cpt)
--     end
-- `start` and `finish` being the bounds of the character, and `cpt` being the UTF-8 code point.
-- It produces:
--     729
--     8224
--     402
--     729
--     169
--     8730
local
function utf8_next_int (subject, i)
    i = i and i+1 or 1
    if i > #subject then return end
    local c = s_byte(subject, i)
    local offset, val = utf8_offset(c)
    for i = i+1, i+offset do
        c = s_byte(subject, i)
        val = val * 64 + (c-128)
    end
  return i + offset, i, val
end


-- Usage:
--     for finish, start, cpt in utf8_next_char, "˙†ƒ˙©√" do
--         print(cpt)
--     end
-- `start` and `finish` being the bounds of the character, and `cpt` being the UTF-8 code point.
-- It produces:
--     ˙
--     †
--     ƒ
--     ˙
--     ©
--     √
local
function utf8_next_char (subject, i)
    i = i and i+1 or 1
    if i > #subject then return end
    local offset = utf8_offset(s_byte(subject,i))
    return i + offset, i, s_sub(subject, i, i + offset)
end


-- Takes a string, returns an array of code points.
local
function utf8_split_int (subject)
    local chars = {}
    for _, _, c in utf8_next_int, subject do
        t_insert(chars,c)
    end
    return chars
end

-- Takes a string, returns an array of characters.
local
function utf8_split_char (subject)
    local chars = {}
    for _, _, c in utf8_next_char, subject do
        t_insert(chars,c)
    end
    return chars
end

local
function utf8_get_int(subject, i)
    if i > #subject then return end
    local c = s_byte(subject, i)
    local offset, val = utf8_offset(c)
    for i = i+1, i+offset do
        c = s_byte(subject, i)
        val = val * 64 + ( c - 128 )
    end
    return val, i + offset + 1
end

local
function split_generator (get)
    if not get then return end
    return function(subject)
        local res = {}
        local o, i = true
        while o do
            o,i = get(subject, i)
            res[#res] = o
        end
        return res
    end
end

local
function merge_generator (char)
    if not char then return end
    return function(ary)
        local res = {}
        for i = 1, #ary do
            t_insert(res,char(ary[i]))
        end
        return t_concat(res)
    end
end


local
function utf8_get_int2 (subject, i)
    local byte, b5, b4, b3, b2, b1 = s_byte(subject, i)
    if byte < 128 then return byte, i + 1
    elseif byte < 192 then
        error("Byte values between 0x80 to 0xBF cannot start a multibyte sequence")
    elseif byte < 224 then
        return (byte - 192)*64 + s_byte(subject, i+1), i+2
    elseif byte < 240 then
            b2, b1 = s_byte(subject, i+1, i+2)
        return (byte-224)*4096 + b2%64*64 + b1%64, i+3
    elseif byte < 248 then
        b3, b2, b1 = s_byte(subject, i+1, i+2, 1+3)
        return (byte-240)*262144 + b3%64*4096 + b2%64*64 + b1%64, i+4
    elseif byte < 252 then
        b4, b3, b2, b1 = s_byte(subject, i+1, i+2, 1+3, i+4)
        return (byte-248)*16777216 + b4%64*262144 + b3%64*4096 + b2%64*64 + b1%64, i+5
    elseif byte < 254 then
        b5, b4, b3, b2, b1 = s_byte(subject, i+1, i+2, 1+3, i+4, i+5)
        return (byte-252)*1073741824 + b5%64*16777216 + b4%64*262144 + b3%64*4096 + b2%64*64 + b1%64, i+6
    else
        error("Byte values between 0xFE and OxFF cannot start a multibyte sequence")
    end
end


local
function utf8_get_char(subject, i)
    if i > #subject then return end
    local offset = utf8_offset(s_byte(subject,i))
    return s_sub(subject, i, i + offset), i + offset + 1
end

local
function utf8_char(c)
    if     c < 128 then
        return                                                                               s_char(c)
    elseif c < 2048 then
        return                                                          s_char(192 + c/64, 128 + c%64)
    elseif c < 55296 or 57343 < c and c < 65536 then
        return                                         s_char(224 + c/4096, 128 + c/64%64, 128 + c%64)
    elseif c < 2097152 then
        return                      s_char(240 + c/262144, 128 + c/4096%64, 128 + c/64%64, 128 + c%64)
    elseif c < 67108864 then
        return s_char(248 + c/16777216, 128 + c/262144%64, 128 + c/4096%64, 128 + c/64%64, 128 + c%64)
    elseif c < 2147483648 then
        return s_char( 252 + c/1073741824,
                   128 + c/16777216%64, 128 + c/262144%64, 128 + c/4096%64, 128 + c/64%64, 128 + c%64)
    end
    error("Bad Unicode code point: "..c..".")
end

-------------------------------------------------------------------------------
--- ASCII and binary.
--

-- See UTF-8 above for the API docs.

local
function binary_validate (subject, start, finish)
    start = start or 1
    finish = finish or #subject
    return true, finish
end

local
function binary_next_int (subject, i)
    i = i and i+1 or 1
    if i >= #subject then return end
    return i, i, s_sub(subject, i, i)
end

local
function binary_next_char (subject, i)
    i = i and i+1 or 1
    if i > #subject then return end
    return i, i, s_byte(subject,i)
end

local
function binary_split_int (subject)
    local chars = {}
    for i = 1, #subject do
        t_insert(chars, s_byte(subject,i))
    end
    return chars
end

local
function binary_split_char (subject)
    local chars = {}
    for i = 1, #subject do
        t_insert(chars, s_sub(subject,i,i))
    end
    return chars
end

local
function binary_get_int(subject, i)
    return s_byte(subject, i), i + 1
end

local
function binary_get_char(subject, i)
    return s_sub(subject, i, i), i + 1
end


-------------------------------------------------------------------------------
--- The table
--

local charsets = {
    binary = {
        name = "binary",
        binary = true,
        validate   = binary_validate,
        split_char = binary_split_char,
        split_int  = binary_split_int,
        next_char  = binary_next_char,
        next_int   = binary_next_int,
        get_char   = binary_get_char,
        get_int    = binary_get_int,
        tochar    = s_char
    },
    ["UTF-8"] = {
        name = "UTF-8",
        validate   = utf8_validate,
        split_char = utf8_split_char,
        split_int  = utf8_split_int,
        next_char  = utf8_next_char,
        next_int   = utf8_next_int,
        get_char   = utf8_get_char,
        get_int    = utf8_get_int
    }
}

return function (Builder)
    local cs = Builder.options.charset or "binary"
    if charsets[cs] then
        Builder.charset = copy(charsets[cs])
        Builder.binary_split_int = binary_split_int
    else
        error("NYI: custom charsets")
    end
end


--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["evaluator"])sources["evaluator"]=([===[-- <pack evaluator> --

-- Capture eval

local select, tonumber, tostring, type
    = select, tonumber, tostring, type

local s, t, u = require"string", require"table", require"util"
local s_sub, t_concat
    = s.sub, t.concat

local t_unpack
    = u.unpack

--[[DBG]] local debug, rawset, setmetatable, error, print, expose 
--[[DBG]]     = debug, rawset, setmetatable, error, print, u.expose


local _ENV = u.noglobals() ----------------------------------------------------



return function(Builder, LL) -- Decorator wrapper

--[[DBG]] local cprint = LL.cprint

-- The evaluators and the `insert()` helper take as parameters:
-- * caps: the capture array
-- * sbj:  the subject string
-- * vals: the value accumulator, whose unpacked values will be returned
--         by `pattern:match()`
-- * ci:   the current position in capture array.
-- * vi:   the position of the next value to be inserted in the value accumulator.

local eval = {}

local
function insert (caps, sbj, vals, ci, vi)
    local openclose, kind = caps.openclose, caps.kind
    -- [[DBG]] print("Insert - kind = ", kind[ci])
    while kind[ci] and openclose[ci] >= 0 do
        -- [[DBG]] print("Eval, Pre Insert, kind:", kind[ci], ci)
        ci, vi = eval[kind[ci]](caps, sbj, vals, ci, vi)
        -- [[DBG]] print("Eval, Post Insert, kind:", kind[ci], ci)
    end

    return ci, vi
end

function eval.C (caps, sbj, vals, ci, vi)
    if caps.openclose[ci] > 0 then
        vals[vi] = s_sub(sbj, caps.bounds[ci], caps.openclose[ci] - 1)
        return ci + 1, vi + 1
    end

    vals[vi] = false -- pad it for now
    local cj, vj = insert(caps, sbj, vals, ci + 1, vi + 1)
    vals[vi] = s_sub(sbj, caps.bounds[ci], caps.bounds[cj] - 1)
    return cj + 1, vj
end


local
function lookback (caps, label, ci)
    -- [[DBG]] print("lookback( "..tostring(label).." ), ci = "..ci) --.." ..."); --expose(caps)
    -- [[DBG]] if ci == 9 then error() end
    local aux, openclose, kind= caps.aux, caps.openclose, caps.kind

    repeat
        -- [[DBG]] print("Lookback kind: ", kind[ci], ", ci = "..ci, "oc[ci] = ", openclose[ci], "aux[ci] = ", aux[ci])
        ci = ci - 1
        local auxv, oc = aux[ci], openclose[ci]
        if oc < 0 then ci = ci + oc end
        if oc ~= 0 and kind[ci] == "Clb" and label == auxv then
            -- found.
            return ci
        end
    until ci == 1

    -- not found.
    label = type(label) == "string" and "'"..label.."'" or tostring(label)
    error("back reference "..label.." not found")
end

function eval.Cb (caps, sbj, vals, ci, vi)
    -- [[DBG]] print("Eval Cb, ci = "..ci)
    local Cb_ci = lookback(caps, caps.aux[ci], ci)
    -- [[DBG]] print(" Eval Cb, Cb_ci = "..Cb_ci)
    Cb_ci, vi = eval.Cg(caps, sbj, vals, Cb_ci, vi)
    -- [[DBG]] print("/Eval Cb next kind, ", caps.kind[ci + 1], "Values = ..."); expose(vals)

    return ci + 1, vi
end


function eval.Cc (caps, sbj, vals, ci, vi)
    local these_values = caps.aux[ci]
    -- [[DBG]] print"Eval Cc"; expose(these_values)
    for i = 1, these_values.n do
        vi, vals[vi] = vi + 1, these_values[i]
    end
    return ci + 1, vi
end



eval["Cf"] = function() error("NYI: Cf") end

function eval.Cf (caps, sbj, vals, ci, vi)
    if caps.openclose[ci] > 0 then
        error"No First Value"
    end

    local func, Cf_vals, Cf_vi = caps.aux[ci], {}
    ci = ci + 1
    ci, Cf_vi = eval[caps.kind[ci]](caps, sbj, Cf_vals, ci, 1)

    if Cf_vi == 1 then
        error"No first value"
    end

    local result = Cf_vals[1]

    while caps.kind[ci] and caps.openclose[ci] >= 0 do
        ci, Cf_vi = eval[caps.kind[ci]](caps, sbj, Cf_vals, ci, 1)
        result = func(result, t_unpack(Cf_vals, 1, Cf_vi - 1))
    end
    vals[vi] = result
    return ci +1, vi + 1
end



function eval.Cg (caps, sbj, vals, ci, vi)
    -- [[DBG]] print("Gc - caps", ci, caps.openclose[ci]) expose(caps)
    if caps.openclose[ci] > 0 then
        -- [[DBG]] print("Cg - closed")
        vals[vi] = s_sub(sbj, caps.bounds[ci], caps.openclose[ci] - 1)
        return ci + 1, vi + 1
    end
        -- [[DBG]] print("Cg - open ci = ", ci)

    local cj, vj = insert(caps, sbj, vals, ci + 1, vi)
    if vj == vi then 
        -- [[DBG]] print("Cg - no inner values")        
        vals[vj] = s_sub(sbj, caps.bounds[ci], caps.bounds[cj] - 1)
        vj = vj + 1
    end
    return cj + 1, vj
end


function eval.Clb (caps, sbj, vals, ci, vi)
    local oc = caps.openclose
    if oc[ci] > 0 then
        return ci + 1, vi 
    end

    local depth = 0
    repeat
        if oc[ci] == 0 then depth = depth + 1
        elseif oc[ci] < 0 then depth = depth - 1
        end
        ci = ci + 1
    until depth == 0
    return ci, vi
end


function eval.Cp (caps, sbj, vals, ci, vi)
    vals[vi] = caps.bounds[ci]
    return ci + 1, vi + 1
end


function eval.Ct (caps, sbj, vals, ci, vi)
    local aux, openclose, kind = caps. aux, caps.openclose, caps.kind
    local tbl_vals = {}
    vals[vi] = tbl_vals

    if openclose[ci] > 0 then
        return ci + 1, vi + 1
    end

    local tbl_vi, Clb_vals = 1, {}
    ci = ci + 1

    while kind[ci] and openclose[ci] >= 0 do
        if kind[ci] == "Clb" then
            local label, Clb_vi = aux[ci], 1
            ci, Clb_vi = eval.Cg(caps, sbj, Clb_vals, ci, 1)
            if Clb_vi ~= 1 then tbl_vals[label] = Clb_vals[1] end
        else
            ci, tbl_vi =  eval[kind[ci]](caps, sbj, tbl_vals, ci, tbl_vi)
        end
    end
    return ci + 1, vi + 1
end

local inf = 1/0

function eval.value (caps, sbj, vals, ci, vi)
    local val 
    -- nils are encoded as inf in both aux and openclose.
    if caps.aux[ci] ~= inf or caps.openclose[ci] ~= inf
        then val = caps.aux[ci]
        -- [[DBG]] print("Eval value = ", val)
    end

    vals[vi] = val
    return ci + 1, vi + 1
end


function eval.Cs (caps, sbj, vals, ci, vi)
    -- [[DBG]] print("Eval Cs - ci = "..ci..", vi = "..vi)
    if caps.openclose[ci] > 0 then
        vals[vi] = s_sub(sbj, caps.bounds[ci], caps.openclose[ci] - 1)
    else
        local bounds, kind, openclose = caps.bounds, caps.kind, caps.openclose
        local start, buffer, Cs_vals, bi, Cs_vi = bounds[ci], {}, {}, 1, 1
        local last
        ci = ci + 1
        -- [[DBG]] print"eval.CS, openclose: "; expose(openclose)
        -- [[DBG]] print("eval.CS, ci =", ci)
        while openclose[ci] >= 0 do
            -- [[DBG]] print(" eval Cs - ci = "..ci..", bi = "..bi.." - LOOP - Buffer = ...")
            -- [[DBG]] u.expose(buffer)
            -- [[DBG]] print(" eval - Cs kind = "..kind[ci])

            last = bounds[ci]
            buffer[bi] = s_sub(sbj, start, last - 1)
            bi = bi + 1

            ci, Cs_vi = eval[kind[ci]](caps, sbj, Cs_vals, ci, 1)
            -- [[DBG]] print("  Cs post eval ci = "..ci..", Cs_vi = "..Cs_vi)
            if Cs_vi > 1 then
                buffer[bi] = Cs_vals[1]
                bi = bi + 1
                start = openclose[ci-1] > 0 and openclose[ci-1] or bounds[ci-1]
            else
                start = last
            end

        -- [[DBG]] print("eval.CS while, ci =", ci)
        end
        buffer[bi] = s_sub(sbj, start, bounds[ci] - 1)

        vals[vi] = t_concat(buffer)
    end
    -- [[DBG]] print("/Eval Cs - ci = "..ci..", vi = "..vi)

    return ci + 1, vi + 1
end


local
function insert_divfunc_results(acc, val_i, ...)
    local n = select('#', ...)
    for i = 1, n do
        val_i, acc[val_i] = val_i + 1, select(i, ...)
    end
    return val_i
end

function eval.div_function (caps, sbj, vals, ci, vi)
    local func = caps.aux[ci]
    local params, divF_vi

    if caps.openclose[ci] > 0 then
        params, divF_vi = {s_sub(sbj, caps.bounds[ci], caps.openclose[ci] - 1)}, 2
    else
        params = {}
        ci, divF_vi = insert(caps, sbj, params, ci + 1, 1)
    end

    ci = ci + 1 -- skip the closed or closing node.
    vi = insert_divfunc_results(vals, vi, func(t_unpack(params, 1, divF_vi - 1)))
    return ci, vi
end


function eval.div_number (caps, sbj, vals, ci, vi)
    local this_aux = caps.aux[ci]
    local divN_vals, divN_vi

    if caps.openclose[ci] > 0 then
        divN_vals, divN_vi = {s_sub(sbj, caps.bounds[ci], caps.openclose[ci] - 1)}, 2
    else
        divN_vals = {}
        ci, divN_vi = insert(caps, sbj, divN_vals, ci + 1, 1)
    end
    ci = ci + 1 -- skip the closed or closing node.

    if this_aux >= divN_vi then error("no capture '"..this_aux.."' in /number capture.") end
    vals[vi] = divN_vals[this_aux]
    return ci, vi + 1
end


local function div_str_cap_refs (caps, ci)
    local opcl = caps.openclose
    local refs = {open=caps.bounds[ci]}

    if opcl[ci] > 0 then
        refs.close = opcl[ci]
        return ci + 1, refs, 0
    end

    local first_ci = ci
    local depth = 1
    ci = ci + 1
    repeat
        local oc = opcl[ci]
        -- [[DBG]] print("/''refs", caps.kind[ci], ci, oc, depth)
        if depth == 1  and oc >= 0 then refs[#refs+1] = ci end
        if oc == 0 then 
            depth = depth + 1
        elseif oc < 0 then
            depth = depth - 1
        end
        ci = ci + 1
    until depth == 0
    -- [[DBG]] print("//''refs", ci, ci - first_ci)
    -- [[DBG]] expose(refs)
    -- [[DBG]] print"caps"
    -- [[DBG]] expose(caps)
    refs.close = caps.bounds[ci - 1]
    return ci, refs, #refs
end

function eval.div_string (caps, sbj, vals, ci, vi)
    -- [[DBG]] print("div_string ci = "..ci..", vi = "..vi )
    local n, refs
    local cached
    local cached, divS_vals = {}, {}
    local the_string = caps.aux[ci]

    ci, refs, n = div_str_cap_refs(caps, ci)
    -- [[DBG]] print("  REFS div_string ci = "..ci..", n = ", n, ", refs = ...")
    -- [[DBG]] expose(refs)
    vals[vi] = the_string:gsub("%%([%d%%])", function (d)
        if d == "%" then return "%" end
        d = tonumber(d)
        if not cached[d] then
            if d > n then
                error("no capture at index "..d.." in /string capture.")
            end
            if d == 0 then
                cached[d] = s_sub(sbj, refs.open, refs.close - 1)
            else
                local _, vi = eval[caps.kind[refs[d]]](caps, sbj, divS_vals, refs[d], 1)
                if vi == 1 then error("no values in capture at index"..d.." in /string capture.") end
                cached[d] = divS_vals[1]
            end
        end
        return cached[d]
    end)
    -- [[DBG]] u.expose(vals)
    -- [[DBG]] print("/div_string ci = "..ci..", vi = "..vi )
    return ci, vi + 1
end


function eval.div_table (caps, sbj, vals, ci, vi)
    -- [[DBG]] print("Div_table ci = "..ci..", vi = "..vi )
    local this_aux = caps.aux[ci]
    local key

    if caps.openclose[ci] > 0 then
        key =  s_sub(sbj, caps.bounds[ci], caps.openclose[ci] - 1)
    else
        local divT_vals, _ = {}
        ci, _ = insert(caps, sbj, divT_vals, ci + 1, 1)
        key = divT_vals[1]
    end

    ci = ci + 1
    -- [[DBG]] print("/div_table ci = "..ci..", vi = "..vi )
    -- [[DBG]] print(type(key), key, "...")
    -- [[DBG]] expose(this_aux)
    if this_aux[key] then
        -- [[DBG]] print("/{} success")
        vals[vi] = this_aux[key]
        return ci, vi + 1
    else
        return ci, vi
    end
end



function LL.evaluate (caps, sbj, ci)
    -- [[DBG]] print("*** Eval", caps, sbj, ci)
    -- [[DBG]] expose(caps)
    -- [[DBG]] cprint(caps, sbj, ci)
    local vals = {}
    -- [[DBG]] vals = setmetatable({}, {__newindex = function(self, k,v) 
    -- [[DBG]]     print("set Val, ", k, v, debug.traceback(1)) rawset(self, k, v) 
    -- [[DBG]] end})
    local _,  vi = insert(caps, sbj, vals, ci, 1)
    return vals, 1, vi - 1
end


end  -- Decorator wrapper


--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["printers"])sources["printers"]=([===[-- <pack printers> --
return function(Builder, LL)

-- Print

local ipairs, pairs, print, tostring, type
    = ipairs, pairs, print, tostring, type

local s, t, u = require"string", require"table", require"util"
local S_tostring = Builder.set.tostring


local _ENV = u.noglobals() ----------------------------------------------------



local s_char, s_sub, t_concat
    = s.char, s.sub, t.concat

local   expose,   load,   map
    = u.expose, u.load, u.map

local escape_index = {
    ["\f"] = "\\f",
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t",
    ["\v"] = "\\v",
    ["\127"] = "\\ESC"
}

local function flatten(kind, list)
    if list[2].pkind == kind then
        return list[1], flatten(kind, list[2])
    else
        return list[1], list[2]
    end
end

for i = 0, 8 do escape_index[s_char(i)] = "\\"..i end
for i = 14, 31 do escape_index[s_char(i)] = "\\"..i end

local
function escape( str )
    return str:gsub("%c", escape_index)
end

local
function set_repr (set) 
    return s_char(load("return "..S_tostring(set))())
end


local printers = {}

local
function LL_pprint (pt, offset, prefix)
    -- [[DBG]] print("PRINT -", pt)
    -- [[DBG]] print("PRINT +", pt.pkind)
    -- [[DBG]] expose(pt)
    -- [[DBG]] expose(LL.proxycache[pt])
    return printers[pt.pkind](pt, offset, prefix)
end

function LL.pprint (pt0)
    local pt = LL.P(pt0)
    print"\nPrint pattern"
    LL_pprint(pt, "", "")
    print"--- /pprint\n"
    return pt0
end

for k, v in pairs{
    string       = [[ "P( \""..escape(pt.as_is).."\" )"       ]],
    char         = [[ "P( \""..escape(to_char(pt.aux)).."\" )"]],
    ["true"]     = [[ "P( true )"                     ]],
    ["false"]    = [[ "P( false )"                    ]],
    eos          = [[ "~EOS~"                         ]],
    one          = [[ "P( one )"                      ]],
    any          = [[ "P( "..pt.aux.." )"             ]],
    set          = [[ "S( "..'"'..escape(set_repr(pt.aux))..'"'.." )" ]],
    ["function"] = [[ "P( "..pt.aux.." )"             ]],
    ref = [[
        "V( ",
            (type(pt.aux) == "string" and "\""..pt.aux.."\"")
                          or tostring(pt.aux)
        , " )"
        ]],
    range = [[
        "R( ",
            escape(t_concat(map(
                pt.as_is,
                function(e) return '"'..e..'"' end)
            , ", "))
        ," )"
        ]]
} do
    printers[k] = load(([==[
        local k, map, t_concat, to_char, escape, set_repr = ...
        return function (pt, offset, prefix)
            print(t_concat{offset,prefix,XXXX})
        end
    ]==]):gsub("XXXX", v), k.." printer")(k, map, t_concat, s_char, escape, set_repr)
end


for k, v in pairs{
    ["behind"] = [[ LL_pprint(pt.pattern, offset, "B ") ]],
    ["at least"] = [[ LL_pprint(pt.pattern, offset, pt.aux.." ^ ") ]],
    ["at most"] = [[ LL_pprint(pt.pattern, offset, pt.aux.." ^ ") ]],
    unm        = [[LL_pprint(pt.pattern, offset, "- ")]],
    lookahead  = [[LL_pprint(pt.pattern, offset, "# ")]],
    choice = [[
        print(offset..prefix.."+")
        -- dprint"Printer for choice"
        local ch, i = {}, 1
        while pt.pkind == "choice" do
            ch[i], pt, i = pt[1], pt[2], i + 1
        end
        ch[i] = pt

        map(ch, LL_pprint, offset.." :", "")
        ]],
    sequence = [=[
        -- print("Seq printer", s, u)
        -- u.expose(pt)
        print(offset..prefix.."*")
        local acc, p2 = {}
        offset = offset .. " |"
        while true do
            if pt.pkind ~= "sequence" then -- last element
                if pt.pkind == "char" then
                    acc[#acc + 1] = pt.aux
                    print(offset..'P( "'..s.char(u.unpack(acc))..'" )')
                else
                    if #acc ~= 0 then
                        print(offset..'P( "'..s.char(u.unpack(acc))..'" )')
                    end
                    LL_pprint(pt, offset, "")
                end
                break
            elseif pt[1].pkind == "char" then
                acc[#acc + 1] = pt[1].aux
            elseif #acc ~= 0 then
                print(offset..'P( "'..s.char(u.unpack(acc))..'" )')
                acc = {}
                LL_pprint(pt[1], offset, "")
            else
                LL_pprint(pt[1], offset, "")
            end
            pt = pt[2]
        end
        ]=],
    grammar   = [[
        print(offset..prefix.."Grammar")
        -- dprint"Printer for Grammar"
        for k, pt in pairs(pt.aux) do
            local prefix = ( type(k)~="string"
                             and tostring(k)
                             or "\""..k.."\"" )
            LL_pprint(pt, offset.."  ", prefix .. " = ")
        end
    ]]
} do
    printers[k] = load(([[
        local map, LL_pprint, pkind, s, u, flatten = ...
        return function (pt, offset, prefix)
            XXXX
        end
    ]]):gsub("XXXX", v), k.." printer")(map, LL_pprint, type, s, u, flatten)
end

-------------------------------------------------------------------------------
--- Captures patterns
--

-- for _, cap in pairs{"C", "Cs", "Ct"} do
-- for _, cap in pairs{"Carg", "Cb", "Cp"} do
-- function LL_Cc (...)
-- for _, cap in pairs{"Cf", "Cmt"} do
-- function LL_Cg (pt, tag)
-- local valid_slash_type = newset{"string", "number", "table", "function"}


for _, cap in pairs{"C", "Cs", "Ct"} do
    printers[cap] = function (pt, offset, prefix)
        print(offset..prefix..cap)
        LL_pprint(pt.pattern, offset.."  ", "")
    end
end

for _, cap in pairs{"Cg", "Clb", "Cf", "Cmt", "div_number", "/zero", "div_function", "div_table"} do
    printers[cap] = function (pt, offset, prefix)
        print(offset..prefix..cap.." "..tostring(pt.aux or ""))
        LL_pprint(pt.pattern, offset.."  ", "")
    end
end

printers["div_string"] = function (pt, offset, prefix)
    print(offset..prefix..'/string "'..tostring(pt.aux or "")..'"')
    LL_pprint(pt.pattern, offset.."  ", "")
end

for _, cap in pairs{"Carg", "Cp"} do
    printers[cap] = function (pt, offset, prefix)
        print(offset..prefix..cap.."( "..tostring(pt.aux).." )")
    end
end

printers["Cb"] = function (pt, offset, prefix)
    print(offset..prefix.."Cb( \""..pt.aux.."\" )")
end

printers["Cc"] = function (pt, offset, prefix)
    print(offset..prefix.."Cc(" ..t_concat(map(pt.aux, tostring),", ").." )")
end


-------------------------------------------------------------------------------
--- Capture objects
--

local cprinters = {}

local padding = "   "
local function padnum(n)
    n = tostring(n)
    n = n .."."..((" "):rep(4 - #n))
    return n
end

local function _cprint(caps, ci, indent, sbj, n)
    local openclose, kind = caps.openclose, caps.kind
    indent = indent or 0
    while kind[ci] and openclose[ci] >= 0 do
        if caps.openclose[ci] > 0 then 
            print(t_concat({
                            padnum(n),
                            padding:rep(indent),
                            caps.kind[ci],
                            ": start = ", tostring(caps.bounds[ci]),
                            " finish = ", tostring(caps.openclose[ci]),
                            caps.aux[ci] and " aux = " or "",
                            caps.aux[ci] and (
                                type(caps.aux[ci]) == "string" 
                                    and '"'..tostring(caps.aux[ci])..'"'
                                or tostring(caps.aux[ci])
                            ) or "",
                            " \t", s_sub(sbj, caps.bounds[ci], caps.openclose[ci] - 1)
                        }))
            if type(caps.aux[ci]) == "table" then expose(caps.aux[ci]) end
        else
            local kind = caps.kind[ci]
            local start = caps.bounds[ci]
            print(t_concat({
                            padnum(n),
                            padding:rep(indent), kind,
                            ": start = ", start,
                            caps.aux[ci] and " aux = " or "",
                            caps.aux[ci] and (
                                type(caps.aux[ci]) == "string" 
                                    and '"'..tostring(caps.aux[ci])..'"'
                                or tostring(caps.aux[ci])
                            ) or ""
                        }))
            ci, n = _cprint(caps, ci + 1, indent + 1, sbj, n + 1)
            print(t_concat({
                            padnum(n),
                            padding:rep(indent),
                            "/", kind,
                            " finish = ", tostring(caps.bounds[ci]),
                            " \t", s_sub(sbj, start, (caps.bounds[ci] or 1) - 1)
                        }))
        end
        n = n + 1
        ci = ci + 1
    end

    return ci, n
end

function LL.cprint (caps, ci, sbj)
    ci = ci or 1
    print"\nCapture Printer:\n================"
    -- print(capture)
    -- [[DBG]] expose(caps)
    _cprint(caps, ci, 0, sbj, 1)
    print"================\n/Cprinter\n"
end




return { pprint = LL.pprint,cprint = LL.cprint }

end -- module wrapper ---------------------------------------------------------


--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["analizer"])sources["analizer"]=([===[-- <pack analizer> --

-- A stub at the moment.

local u = require"util"
local nop, weakkey = u.nop, u.weakkey

local hasVcache, hasCmtcache , lengthcache
    = weakkey{}, weakkey{},    weakkey{}

return {
    hasV = nop,
    hasCmt = nop,
    length = nop,
    hasCapture = nop
}


--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The PureLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["locale"])sources["locale"]=([===[-- <pack locale> --

-- Locale definition.

local extend = require"util".extend



local _ENV = require"util".noglobals() ----------------------------------------



-- We'll limit ourselves to the standard C locale for now.
-- see http://wayback.archive.org/web/20120310215042/http://www.utas.edu.au...
-- .../infosys/info/documentation/C/CStdLib.html#ctype.h

return function(Builder, LL) -- Module wrapper {-------------------------------

local R, S = LL.R, LL.S

local locale = {}
locale["cntrl"] = R"\0\31" + "\127"
locale["digit"] = R"09"
locale["lower"] = R"az"
locale["print"] = R" ~" -- 0x20 to 0xee
locale["space"] = S" \f\n\r\t\v" -- \f == form feed (for a printer), \v == vtab
locale["upper"] = R"AZ"

locale["alpha"]  = locale["lower"] + locale["upper"]
locale["alnum"]  = locale["alpha"] + locale["digit"]
locale["graph"]  = locale["print"] - locale["space"]
locale["punct"]  = locale["graph"] - locale["alnum"]
locale["xdigit"] = locale["digit"] + R"af" + R"AF"


function LL.locale (t)
    return extend(t or {}, locale)
end

end -- Module wrapper --------------------------------------------------------}


--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["match"])sources["match"]=([===[-- <pack match> --

]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["factorizer"])sources["factorizer"]=([===[-- <pack factorizer> --
local ipairs, pairs, print, setmetatable
    = ipairs, pairs, print, setmetatable

--[[DBG]] local debug = require "debug"
local u = require"util"

local   id,   nop,   setify,   weakkey
    = u.id, u.nop, u.setify, u.weakkey

local _ENV = u.noglobals() ----------------------------------------------------



---- helpers
--

-- handle the identity or break properties of P(true) and P(false) in
-- sequences/arrays.
local
function process_booleans(a, b, opts)
    local id, brk = opts.id, opts.brk
    if a == id then return true, b
    elseif b == id then return true, a
    elseif a == brk then return true, brk
    else return false end
end

-- patterns where `C(x) + C(y) => C(x + y)` apply.
local unary = setify{
    "unm", "lookahead", "C", "Cf",
    "Cg", "Cs", "Ct", "/zero"
}

local unary_aux = setify{
    "behind", "at least", "at most", "Clb", "Cmt",
    "div_string", "div_number", "div_table", "div_function"
}

-- patterns where p1 + p2 == p1 U p2
local unifiable = setify{"char", "set", "range"}


local hasCmt; hasCmt = setmetatable({}, {__mode = "k", __index = function(self, pt)
    local kind, res = pt.pkind, false
    if kind == "Cmt"
    or kind == "ref"
    then
        res = true
    elseif unary[kind] or unary_aux[kind] then
        res = hasCmt[pt.pattern]
    elseif kind == "choice" or kind == "sequence" then
        res = hasCmt[pt[1]] or hasCmt[pt[2]]
    end
    hasCmt[pt] = res
    return res
end})



return function (Builder, LL) --------------------------------------------------

if Builder.options.factorize == false then
    return {
        choice = nop,
        sequence = nop,
        lookahead = nop,
        unm = nop
    }
end

local constructors, LL_P =  Builder.constructors, LL.P
local truept, falsept
    = constructors.constant.truept
    , constructors.constant.falsept

local --Range, Set,
    S_union
    = --Builder.Range, Builder.set.new,
    Builder.set.union

local mergeable = setify{"char", "set"}


local type2cons = {
    ["/zero"] = "__div",
    ["div_number"] = "__div",
    ["div_string"] = "__div",
    ["div_table"] = "__div",
    ["div_function"] = "__div",
    ["at least"] = "__exp",
    ["at most"] = "__exp",
    ["Clb"] = "Cg",
}

local
function choice (a, b)
    do  -- handle the identity/break properties of true and false.
        local hasbool, res = process_booleans(a, b, { id = falsept, brk = truept })
        if hasbool then return res end
    end
    local ka, kb = a.pkind, b.pkind
    if a == b and not hasCmt[a] then
        return a
    elseif ka == "choice" then -- correct associativity without blowing up the stack
        local acc, i = {}, 1
        while a.pkind == "choice" do
            acc[i], a, i = a[1], a[2], i + 1
        end
        acc[i] = a
        for j = i, 1, -1 do
            b = acc[j] + b
        end
        return b
    elseif mergeable[ka] and mergeable[kb] then
        return constructors.aux("set", S_union(a.aux, b.aux))
    elseif mergeable[ka] and kb == "any" and b.aux == 1
    or     mergeable[kb] and ka == "any" and a.aux == 1 then
        -- [[DBG]] print("=== Folding "..ka.." and "..kb..".")
        return ka == "any" and a or b
    elseif ka == kb then
        -- C(a) + C(b) => C(a + b)
        if (unary[ka] or unary_aux[ka]) and ( a.aux == b.aux ) then
            return LL[type2cons[ka] or ka](a.pattern + b.pattern, a.aux)
        elseif ( ka == kb ) and ka == "sequence" then
            -- "ab" + "ac" => "a" * ( "b" + "c" )
            if a[1] == b[1]  and not hasCmt[a[1]] then
                return a[1] * (a[2] + b[2])
            end
        end
    end
    return false
end



local
function lookahead (pt)
    return pt
end


local
function sequence(a, b)
    -- [[DBG]] print("Factorize Sequence")
    -- A few optimizations:
    -- 1. handle P(true) and P(false)
    do
        local hasbool, res = process_booleans(a, b, { id = truept, brk = falsept })
        if hasbool then return res end
    end
    -- 2. Fix associativity
    local ka, kb = a.pkind, b.pkind
    if ka == "sequence" then -- correct associativity without blowing up the stack
        local acc, i = {}, 1
        while a.pkind == "sequence" do
            acc[i], a, i = a[1], a[2], i + 1
        end
        acc[i] = a
        for j = i, 1, -1 do
            b = acc[j] * b
        end
        return b
    elseif (ka == "one" or ka == "any") and (kb == "one" or kb == "any") then
        return LL_P(a.aux + b.aux)
    end
    return false
end

local
function unm (pt)
    -- [[DP]] print("Factorize Unm")
    if     pt == truept            then return falsept
    elseif pt == falsept           then return truept
    elseif pt.pkind == "unm"       then return #pt.pattern
    elseif pt.pkind == "lookahead" then return -pt.pattern
    end
end

return {
    choice = choice,
    lookahead = lookahead,
    sequence = sequence,
    unm = unm
}
end

--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["API"])sources["API"]=([===[-- <pack API> --

-- API.lua

-- What follows is the core LPeg functions, the public API to create patterns.
-- Think P(), R(), pt1 + pt2, etc.
local assert, error, ipairs, pairs, pcall, print
    , require, select, tonumber, tostring, type
    = assert, error, ipairs, pairs, pcall, print
    , require, select, tonumber, tostring, type

local t, u = require"table", require"util"

--[[DBG]] local debug = require"debug"



local _ENV = u.noglobals() ---------------------------------------------------



local t_concat = t.concat

local   checkstring,   copy,   fold,   load,   map_fold,   map_foldr,   setify, t_pack, t_unpack
    = u.checkstring, u.copy, u.fold, u.load, u.map_fold, u.map_foldr, u.setify, u.pack, u.unpack

--[[DBG]] local expose = u.expose

local
function charset_error(index, charset)
    error("Character at position ".. index + 1
            .." is not a valid "..charset.." one.",
        2)
end


------------------------------------------------------------------------------
return function(Builder, LL) -- module wrapper -------------------------------
------------------------------------------------------------------------------


local cs = Builder.charset

local constructors, LL_ispattern
    = Builder.constructors, LL.ispattern

local truept, falsept, Cppt
    = constructors.constant.truept
    , constructors.constant.falsept
    , constructors.constant.Cppt

local    split_int,    validate
    = cs.split_int, cs.validate

local Range, Set, S_union, S_tostring
    = Builder.Range, Builder.set.new
    , Builder.set.union, Builder.set.tostring

-- factorizers, defined at the end of the file.
local factorize_choice, factorize_lookahead, factorize_sequence, factorize_unm


local
function makechar(c)
    return constructors.aux("char", c)
end

local
function LL_P (...)
    local v, n = (...), select('#', ...)
    if n == 0 then error"bad argument #1 to 'P' (value expected)" end
    local typ = type(v)
    if LL_ispattern(v) then
        return v
    elseif typ == "function" then
        return 
            --[[DBG]] true and 
            LL.Cmt("", v)
    elseif typ == "string" then
        local success, index = validate(v)
        if not success then
            charset_error(index, cs.name)
        end
        if v == "" then return truept end
        return 
            --[[DBG]] true and 
            map_foldr(split_int(v), makechar, Builder.sequence)
    elseif typ == "table" then
        -- private copy because tables are mutable.
        local g = copy(v)
        if g[1] == nil then error("grammar has no initial rule") end
        if not LL_ispattern(g[1]) then g[1] = LL.V(g[1]) end
        return
            --[[DBG]] true and
            constructors.none("grammar", g)
    elseif typ == "boolean" then
        return v and truept or falsept
    elseif typ == "number" then
        if v == 0 then
            return truept
        elseif v > 0 then
            return
                --[[DBG]] true and
                constructors.aux("any", v)
        else
            return
                --[[DBG]] true and
                - constructors.aux("any", -v)
        end
    else
        error("bad argument #1 to 'P' (lpeg-pattern expected, got "..typ..")")
    end
end
LL.P = LL_P

local
function LL_S (set)
    if set == "" then
        return
            --[[DBG]] true and
            falsept
    else
        local success
        set = checkstring(set, "S")
        return
            --[[DBG]] true and
            constructors.aux("set", Set(split_int(set)), set)
    end
end
LL.S = LL_S

local
function LL_R (...)
    if select('#', ...) == 0 then
        return LL_P(false)
    else
        local range = Range(1,0)--Set("")
        -- [[DBG]]expose(range)
        for _, r in ipairs{...} do
            r = checkstring(r, "R")
            assert(#r == 2, "bad argument #1 to 'R' (range must have two characters)")
            range = S_union ( range, Range(t_unpack(split_int(r))) )
        end
        -- [[DBG]] local p = constructors.aux("set", range, representation)
        return
            --[[DBG]] true and
            constructors.aux("set", range)
    end
end
LL.R = LL_R

local
function LL_V (name)
    assert(name ~= nil)
    return
        --[[DBG]] true and
        constructors.aux("ref",  name)
end
LL.V = LL_V



do
    local one = setify{"set", "range", "one", "char"}
    local zero = setify{"true", "false", "lookahead", "unm"}
    local forbidden = setify{
        "Carg", "Cb", "C", "Cf",
        "Cg", "Cs", "Ct", "/zero",
        "Clb", "Cmt", "Cc", "Cp",
        "div_string", "div_number", "div_table", "div_function",
        "at least", "at most", "behind"
    }
    local function fixedlen(pt, gram, cycle)
        -- [[DP]] print("Fixed Len",pt.pkind)
        local typ = pt.pkind
        if forbidden[typ] then return false
        elseif one[typ]  then return 1
        elseif zero[typ] then return 0
        elseif typ == "string" then return #pt.as_is
        elseif typ == "any" then return pt.aux
        elseif typ == "choice" then
            local l1, l2 = fixedlen(pt[1], gram, cycle), fixedlen(pt[2], gram, cycle)
            return (l1 == l2) and l1
        elseif typ == "sequence" then
            local l1, l2 = fixedlen(pt[1], gram, cycle), fixedlen(pt[2], gram, cycle)
            return l1 and l2 and l1 + l2
        elseif typ == "grammar" then
            if pt.aux[1].pkind == "ref" then
                return fixedlen(pt.aux[pt.aux[1].aux], pt.aux, {})
            else
                return fixedlen(pt.aux[1], pt.aux, {})
            end
        elseif typ == "ref" then
            if cycle[pt] then return false end
            cycle[pt] = true
            return fixedlen(gram[pt.aux], gram, cycle)
        else
            print(typ,"is not handled by fixedlen()")
        end
    end

    function LL.B (pt)
        pt = LL_P(pt)
        -- [[DP]] print("LL.B")
        -- [[DP]] LL.pprint(pt)
        local len = fixedlen(pt)
        assert(len, "A 'behind' pattern takes a fixed length pattern as argument.")
        if len >= 260 then error("Subpattern too long in 'behind' pattern constructor.") end
        return
            --[[DBG]] true and
            constructors.both("behind", pt, len)
    end
end


local function nameify(a, b)
    return tostring(a)..tostring(b)
end

-- pt*pt
local
function choice (a, b)
    local name = tostring(a)..tostring(b)
    local ch = Builder.ptcache.choice[name]
    if not ch then
        ch = factorize_choice(a, b) or constructors.binary("choice", a, b)
        Builder.ptcache.choice[name] = ch
    end
    return ch
end
function LL.__add (a, b)
    return 
        --[[DBG]] true and
        choice(LL_P(a), LL_P(b))
end


 -- pt+pt,

local
function sequence (a, b)
    local name = tostring(a)..tostring(b)
    local seq = Builder.ptcache.sequence[name]
    if not seq then
        seq = factorize_sequence(a, b) or constructors.binary("sequence", a, b)
        Builder.ptcache.sequence[name] = seq
    end
    return seq
end

Builder.sequence = sequence

function LL.__mul (a, b)
    -- [[DBG]] print("mul", a, b)
    return 
        --[[DBG]] true and
        sequence(LL_P(a), LL_P(b))
end


local
function LL_lookahead (pt)
    -- Simplifications
    if pt == truept
    or pt == falsept
    or pt.pkind == "unm"
    or pt.pkind == "lookahead"
    then
        return pt
    end
    -- -- The general case
    -- [[DB]] print("LL_lookahead", constructors.subpt("lookahead", pt))
    return
        --[[DBG]] true and
        constructors.subpt("lookahead", pt)
end
LL.__len = LL_lookahead
LL.L = LL_lookahead

local
function LL_unm(pt)
    -- Simplifications
    return
        --[[DBG]] true and
        factorize_unm(pt)
        or constructors.subpt("unm", pt)
end
LL.__unm = LL_unm

local
function LL_sub (a, b)
    a, b = LL_P(a), LL_P(b)
    return LL_unm(b) * a
end
LL.__sub = LL_sub

local
function LL_repeat (pt, n)
    local success
    success, n = pcall(tonumber, n)
    assert(success and type(n) == "number",
        "Invalid type encountered at right side of '^'.")
    return constructors.both(( n < 0 and "at most" or "at least" ), pt, n)
end
LL.__pow = LL_repeat

-------------------------------------------------------------------------------
--- Captures
--
for _, cap in pairs{"C", "Cs", "Ct"} do
    LL[cap] = function(pt)
        pt = LL_P(pt)
        return
            --[[DBG]] true and
            constructors.subpt(cap, pt)
    end
end


LL["Cb"] = function(aux)
    return
        --[[DBG]] true and
        constructors.aux("Cb", aux)
end


LL["Carg"] = function(aux)
    assert(type(aux)=="number", "Number expected as parameter to Carg capture.")
    assert( 0 < aux and aux <= 200, "Argument out of bounds in Carg capture.")
    return
        --[[DBG]] true and
        constructors.aux("Carg", aux)
end


local
function LL_Cp ()
    return Cppt
end
LL.Cp = LL_Cp

local
function LL_Cc (...)
    return
        --[[DBG]] true and
        constructors.none("Cc", t_pack(...))
end
LL.Cc = LL_Cc

for _, cap in pairs{"Cf", "Cmt"} do
    local msg = "Function expected in "..cap.." capture"
    LL[cap] = function(pt, aux)
    assert(type(aux) == "function", msg)
    pt = LL_P(pt)
    return
        --[[DBG]] true and
        constructors.both(cap, pt, aux)
    end
end


local
function LL_Cg (pt, tag)
    pt = LL_P(pt)
    if tag ~= nil then
        return
            --[[DBG]] true and
            constructors.both("Clb", pt, tag)
    else
        return
            --[[DBG]] true and
            constructors.subpt("Cg", pt)
    end
end
LL.Cg = LL_Cg


local valid_slash_type = setify{"string", "number", "table", "function"}
local
function LL_slash (pt, aux)
    if LL_ispattern(aux) then
        error"The right side of a '/' capture cannot be a pattern."
    elseif not valid_slash_type[type(aux)] then
        error("The right side of a '/' capture must be of type "
            .."string, number, table or function.")
    end
    local name
    if aux == 0 then
        name = "/zero"
    else
        name = "div_"..type(aux)
    end
    return
        --[[DBG]] true and
        constructors.both(name, pt, aux)
end
LL.__div = LL_slash

if Builder.proxymt then
    for k, v in pairs(LL) do
        if k:match"^__" then
            Builder.proxymt[k] = v
        end
    end
else
    LL.__index = LL
end

local factorizer
    = Builder.factorizer(Builder, LL)

-- These are declared as locals at the top of the wrapper.
factorize_choice,  factorize_lookahead,  factorize_sequence,  factorize_unm =
factorizer.choice, factorizer.lookahead, factorizer.sequence, factorizer.unm

end -- module wrapper --------------------------------------------------------


--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["constructors"])sources["constructors"]=([===[-- <pack constructors> --

-- Constructors

-- Patterns have the following, optional fields:
--
-- - type: the pattern type. ~1 to 1 correspondance with the pattern constructors
--     described in the LPeg documentation.
-- - pattern: the one subpattern held by the pattern, like most captures, or
--     `#pt`, `-pt` and `pt^n`.
-- - aux: any other type of data associated to the pattern. Like the string of a
--     `P"string"`, the range of an `R`, or the list of subpatterns of a `+` or
--     `*` pattern. In some cases, the data is pre-processed. in that case,
--     the `as_is` field holds the data as passed to the constructor.
-- - as_is: see aux.
-- - meta: A table holding meta information about patterns, like their
--     minimal and maximal width, the form they can take when compiled,
--     whether they are terminal or not (no V patterns), and so on.


local getmetatable, ipairs, newproxy, print, setmetatable
    = getmetatable, ipairs, newproxy, print, setmetatable

local t, u, compat
    = require"table", require"util", require"compat"

--[[DBG]] local debug = require"debug"

local t_concat = t.concat

local   copy,   getuniqueid,   id,   map
    ,   weakkey,   weakval
    = u.copy, u.getuniqueid, u.id, u.map
    , u.weakkey, u.weakval



local _ENV = u.noglobals() ----------------------------------------------------



--- The type of cache for each kind of pattern:
--
-- Patterns are memoized using different strategies, depending on what kind of
-- data is associated with them.


local patternwith = {
    constant = {
        "Cp", "true", "false"
    },
    -- only aux
    aux = {
        "string", "any",
        "char", "range", "set",
        "ref", "sequence", "choice",
        "Carg", "Cb"
    },
    -- only sub pattern
    subpt = {
        "unm", "lookahead", "C", "Cf",
        "Cg", "Cs", "Ct", "/zero"
    },
    -- both
    both = {
        "behind", "at least", "at most", "Clb", "Cmt",
        "div_string", "div_number", "div_table", "div_function"
    },
    none = "grammar", "Cc"
}



-------------------------------------------------------------------------------
return function(Builder, LL) --- module wrapper.
--


local S_tostring = Builder.set.tostring


-------------------------------------------------------------------------------
--- Base pattern constructor
--

local newpattern, pattmt
-- This deals with the Lua 5.1/5.2 compatibility, and restricted
-- environements without access to newproxy and/or debug.setmetatable.

if compat.proxies and not compat.lua52_len then 
    -- Lua 5.1 / LuaJIT without compat.
    local proxycache = weakkey{}
    local __index_LL = {__index = LL}

    local baseproxy = newproxy(true)
    pattmt = getmetatable(baseproxy)
    Builder.proxymt = pattmt

    function pattmt:__index(k)
        return proxycache[self][k]
    end

    function pattmt:__newindex(k, v)
        proxycache[self][k] = v
    end

    function LL.getdirect(p) return proxycache[p] end

    function newpattern(cons)
        local pt = newproxy(baseproxy)
        setmetatable(cons, __index_LL)
        proxycache[pt]=cons
        return pt
    end
else
    -- Fallback if neither __len(table) nor newproxy work
    -- for example in restricted sandboxes.
    if LL.warnings and not compat.lua52_len then
        print("Warning: The `__len` metatethod won't work with patterns, "
            .."use `LL.L(pattern)` for lookaheads.")
    end
    pattmt = LL
    function LL.getdirect (p) return p end

    function newpattern(pt)
        return setmetatable(pt,LL)
    end
end

Builder.newpattern = newpattern

local
function LL_ispattern(pt) return getmetatable(pt) == pattmt end
LL.ispattern = LL_ispattern

function LL.type(pt)
    if LL_ispattern(pt) then
        return "pattern"
    else
        return nil
    end
end


-------------------------------------------------------------------------------
--- The caches
--

local ptcache, meta
local
function resetcache()
    ptcache, meta = {}, weakkey{}
    Builder.ptcache = ptcache
    -- Patterns with aux only.
    for _, p in ipairs(patternwith.aux) do
        ptcache[p] = weakval{}
    end

    -- Patterns with only one sub-pattern.
    for _, p in ipairs(patternwith.subpt) do
        ptcache[p] = weakval{}
    end

    -- Patterns with both
    for _, p in ipairs(patternwith.both) do
        ptcache[p] = {}
    end

    return ptcache
end
LL.resetptcache = resetcache

resetcache()


-------------------------------------------------------------------------------
--- Individual pattern constructor
--

local constructors = {}
Builder.constructors = constructors

constructors["constant"] = {
    truept  = newpattern{ pkind = "true" },
    falsept = newpattern{ pkind = "false" },
    Cppt    = newpattern{ pkind = "Cp" }
}

-- data manglers that produce cache keys for each aux type.
-- `id()` for unspecified cases.
local getauxkey = {
    string = function(aux, as_is) return as_is end,
    table = copy,
    set = function(aux, as_is)
        return S_tostring(aux)
    end,
    range = function(aux, as_is)
        return t_concat(as_is, "|")
    end,
    sequence = function(aux, as_is)
        return t_concat(map(getuniqueid, aux),"|")
    end
}

getauxkey.choice = getauxkey.sequence

constructors["aux"] = function(typ, aux, as_is)
     -- dprint("CONS: ", typ, pt, aux, as_is)
    local cache = ptcache[typ]
    local key = (getauxkey[typ] or id)(aux, as_is)
    if not cache[key] then
        cache[key] = newpattern{
            pkind = typ,
            aux = aux,
            as_is = as_is
        }
    end
    return cache[key]
end

-- no cache for grammars
constructors["none"] = function(typ, aux)
    -- [[DBG]] print("CONS: ", typ, _, aux)
    -- [[DBG]] print(debug.traceback(1))
    return newpattern{
        pkind = typ,
        aux = aux
    }
end

constructors["subpt"] = function(typ, pt)
    -- [[DP]]print("CONS: ", typ, pt, aux)
    local cache = ptcache[typ]
    if not cache[pt] then
        cache[pt] = newpattern{
            pkind = typ,
            pattern = pt
        }
    end
    return cache[pt]
end

constructors["both"] = function(typ, pt, aux)
    -- [[DBG]] print("CONS: ", typ, pt, aux)
    local cache = ptcache[typ][aux]
    if not cache then
        ptcache[typ][aux] = weakval{}
        cache = ptcache[typ][aux]
    end
    if not cache[pt] then
        cache[pt] = newpattern{
            pkind = typ,
            pattern = pt,
            aux = aux,
            cache = cache -- needed to keep the cache as long as the pattern exists.
        }
    end
    return cache[pt]
end

constructors["binary"] = function(typ, a, b)
    -- [[DBG]] print("CONS: ", typ, pt, aux)
    return newpattern{
        a, b;
        pkind = typ,
    }
end

end -- module wrapper

--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["compat"])sources["compat"]=([===[-- <pack compat> --

-- compat.lua

local _, debug, jit

_, debug = pcall(require, "debug")

_, jit = pcall(require, "jit")
jit = _ and jit

local compat = {
    debug = debug,

    lua51 = (_VERSION == "Lua 5.1") and not jit,
    lua52 = _VERSION == "Lua 5.2",
    luajit = jit and true or false,
    jit = jit and jit.status(),

    -- LuaJIT can optionally support __len on tables.
    lua52_len = not #setmetatable({},{__len = function()end}),

    proxies = pcall(function()
        local prox = newproxy(true)
        local prox2 = newproxy(prox)
        assert (type(getmetatable(prox)) == "table" 
                and (getmetatable(prox)) == (getmetatable(prox2)))
    end),
    _goto = not not(loadstring or load)"::R::"
}


return compat

--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
assert(not sources["optimizer"])sources["optimizer"]=([===[-- <pack optimizer> --
-- Nothing for now.
]===]):gsub('\\([%]%[]===)\\([%]%[])','%1%2')
local add
if not pcall(function() add = require"aioruntime".add end) then
        local loadstring=loadstring; local preload = require"package".preload
        add = function(name, rawcode)
		if not preload[name] then
		        preload[name] = function(...) return loadstring(rawcode)(...) end
		else
			print("WARNING: overwrite "..name)
		end
        end
end
for name, rawcode in pairs(sources) do add(name, rawcode, priorities[name]) end
end;

-- LuLPeg.lua


-- a WIP LPeg implementation in pure Lua, by Pierre-Yves Gérardy
-- released under the Romantic WTF Public License (see the end of the file).

-- remove the global tables from the environment
-- they are restored at the end of the file.
-- standard libraries must be require()d.

--[[DBG]] local debug, print_ = require"debug", print
--[[DBG]] local print = function(...)
--[[DBG]]    print_(debug.traceback(2))
--[[DBG]]    print_("RE print", ...)
--[[DBG]]    return ...
--[[DBG]] end

--[[DBG]] local tmp_globals, globalenv = {}, _ENV or _G
--[[DBG]] if false and not release then
--[[DBG]] for lib, tbl in pairs(globalenv) do
--[[DBG]]     if type(tbl) == "table" then
--[[DBG]]         tmp_globals[lib], globalenv[lib] = globalenv[lib], nil
--[[DBG]]     end
--[[DBG]] end
--[[DBG]] end

--[[DBG]] local pairs = pairs

local getmetatable, setmetatable, pcall
    = getmetatable, setmetatable, pcall

local u = require"util"
local   copy,   map,   nop, t_unpack
    = u.copy, u.map, u.nop, u.unpack

-- The module decorators.
local API, charsets, compiler, constructors
    , datastructures, evaluator, factorizer
    , locale, printers, re
    = t_unpack(map(require,
    { "API", "charsets", "compiler", "constructors"
    , "datastructures", "evaluator", "factorizer"
    , "locale", "printers", "re" }))

local _, package = pcall(require, "package")



local _ENV = u.noglobals() ----------------------------------------------------



-- The LPeg version we emulate.
local VERSION = "0.12"

-- The LuLPeg version.
local LuVERSION = "0.1.0"

local function global(self, env) setmetatable(env,{__index = self}) end
local function register(self, env)
    pcall(function()
        package.loaded.lpeg = self
        package.loaded.re = self.re
    end)
--    if env then
--        env.lpeg, env.re = self, self.re
--    end
    return self
end

local
function LuLPeg(options)
    options = options and copy(options) or {}

    -- LL is the module
    -- Builder keeps the state during the module decoration.
    local Builder, LL
        = { options = options, factorizer = factorizer }
        , { new = LuLPeg
          , version = function () return VERSION end
          , luversion = function () return LuVERSION end
          , setmaxstack = nop --Just a stub, for compatibility.
          }

    LL.util = u
    LL.global = global
    LL.register = register
    ;-- Decorate the LuLPeg object.
    charsets(Builder, LL)
    datastructures(Builder, LL)
    printers(Builder, LL)
    constructors(Builder, LL)
    API(Builder, LL)
    evaluator(Builder, LL)
    ;(options.compiler or compiler)(Builder, LL)
    locale(Builder, LL)
    LL.re = re(Builder, LL)

    return LL
end -- LuLPeg

local LL = LuLPeg()

-- restore the global libraries
--[[DBG]] for lib, tbl in pairs(tmp_globals) do
--[[DBG]]     globalenv[lib] = tmp_globals[lib]
--[[DBG]] end


return LL

--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg library
--
--                                             \
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work,
--                  I _cannot_ provide any warranty regarding
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
