"""
input(op, key, err; def, req = true)

checks the inputs for errors and assign the value if possible
"""
function input(op, key, err; def, req = true)
    type = typeof(def)
    @debug("    >>",key)
        if req # in case req
            @debug("============ Required Value")

            if haskey(op,key) # in case defined
                @debug("============ Key is defined")
                
                if type == typeof("") # case String
                    
                    @debug("============ Type: String")
                    if op[key] == ""
                        push!(err,key => "String")
                        @debug("============ Input is not valid, pushing error")
                    end
                
                elseif type == typeof(true) # case Boolean
                    
                    @debug("============ Type Boolean")
                    if !(op[key] == true || op[key] == false)
                        push!(err,key => "Boolean")
                        @debug("============ Input is not valid, pushing error")
                    end

                end # end typeof

                @debug("============ Returning value anyways")
                return op[key]

            else # in case not defined (commented)

                @debug("============ Key is not defined, pushing error, returning Default")
                push!(err,key => repr(type))
                return def

            end # end haskey

        else # in case not req
            @debug("============ NOT Required")

            if haskey(op,key)
                @debug("============ The key is defined. Returning the value")
                return op[key]
            else             
                @debug("============ The key is NOT defined. Returning the Default")
                return def
            end
        end
end

"""
report_errors(error_dict; fatal = true, path = homedir(), name = "Julia_repo_make_ERRORS.log", msg = false)

reports the Errors which are in the error_dict in the stdout and write them into a report file in the path 
"""
function report_errors(error_dict; fatal = true, path = homedir(), name = "Julia_repo_make_ERRORS.log", msg = false)
    mkpath(path)
    path = joinpath(path,name)
    if !msg
        if !isempty(error_dict)
            for (key,val) in error_dict
                println("ERROR in the \"configuration.toml\". You must provide a valid ",repr(val)," input to: ", repr(key), " option.")
                flush(stdout)
            end
            file = open(path,"w")
            for (key,val) in error_dict
                println(file,"ERROR in the \"configuration.toml\". You must provide a valid ",repr(val)," input to: ", repr(key), " option.")
                flush(file)
            end
            close(file)
            println("Error report is saved at: ", repr(path))
            if fatal 
                exit(1)
                println(" === THAT WAS FATAL")

            end
        end
    else
        file = open(path,"w")
        for (key,val) in error_dict
            println(file,error_dict[key])
            flush(file)
            println(error_dict[key])
            flush(stdout)
        end
        close(file)
        println("Error report is saved at: ", repr(path))
        if fatal
            exit(1)
            println(" === THAT WAS FATAL")
        end
    end

end

"""
parse_configuration(path)

Parse the TOML file located in the path and reports errors if there are any.
"""
function parse_configuration(path)
    err = Dict{String,String}()
    result =    try 
                    Pkg.TOML.parsefile(path)
                catch e
                    massage = "ERRPR: Parsing configuration file faild. Check this file for syntax errors."
                    push!(err,"configuration_file_format" => massage)
                end
        if !isempty(err)
            report_errors(err,fatal = true, msg = true)
        end
        return result
end

"""
check_prefix(path)

checks the path to see if its is a valid writable path or not. If the path is valid it creates the path. 
"""
function check_prefix(path)
    error_dict = Dict{String,String}()
    if path == ""
        @debug("============ PREFIX IS NOT A VALID STRING")
        push!(error_dict,"prefix" => "The value of \"prefix\" key in the \"configuration.toml\" file is not correct.")
        report_errors(error_dict,fatal = true, msg = true)
    end
    if isdir(path)
        @debug("============ PREFIX IS A PATH")
        try 
            mkdir(joinpath(path,"test"))
            rm(joinpath(path,"test"),force = true, recursive = true)
        catch e
            massage = "Permission denied. Can't write into the prefix."
            push!(error_dict,"prefix" => massage)
        end
    else
        @debug("============ PREFIX IS NOT A PATH")
        try 
            mkdir(path)
        catch e
            massage = "ERROR: ", repr(path), " is not a \"Writable\" directory. Please fix the \"prefix\" value in the \"configuration.toml\""
            println(massage)
            push!(error_dict,"prefix" => massage,msg = true)
        end
    end
    if !isempty(error_dict)
        report_errors(error_dict,fatal = true, msg = true)
    end
end

"""
check_uuid!(id, error_dict)

checks the id to see if it is a valid UUID and returns the UUID object if id is valid.
"""
function check_uuid!(id, error_dict)
    err = []
    result = try
        UUIDs.UUID(id)
    catch e
        @debug("============ UUID STRING IS NOT VALID, pushing error ")
        push!(err,e)
    end
    if isempty(err)
        return UUIDs.UUID(id)
    else
        push!(error_dict,"new_registry_uuid" => "UUID")
    end
end


"""
check_configuration_file(configuration)

Checks the configuration file to see if it has proper keys or not. 
"""
function check_configuration_file(configuration)
    error_dict = Dict{String,String}()

    if !haskey(configuration,"include")
        println("============ There is no include in configuration")
        massage = "ERROR: The \"configuration.toml\" file has no key \"[include]\"."
        push!(error_dict,"include" => massage)

    else # when configuration has include key
        if !haskey(configuration["include"],"registries")
            massage = "ERROR: In the \"configuration.toml\" file \"[include]\" has no key \"registries\"."
            push!(error_dict,"registries" => massage)
        else # when include has a registries key 
            if size(configuration["include"]["registries"],1) < 1
                massage = "ERROR: In the \"configuration.toml\" file, You must specify at least one registy url."
                push!(error_dict,"registries_number" => massage)
            end
        end
    end

    if !haskey(configuration,"options")
        massage = "ERROR: The \"configuration.toml\" file has no key \"[options]\"."
        push!(error_dict,"options" => massage)
    end

    if !isempty(error_dict)
        report_errors(error_dict, fatal = true, msg = true)    
    end
end