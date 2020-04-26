function input(op,key,err;def,req = true)
    type = typeof(def)
    get(op,key) do
        if req # in case req
            if haskey(op,key) # in case defined
                if type == typeof("")
                    if op[key] ==""
                        push!(err,key => "String")
                    end
                elseif type == typeof(true)
                    if !(op[key] == true || op[key] == false)
                        push!(err,key => "Boolean")
                    end
                end # end typeof  
                return op[key]
            else # in case not defined (commented)
                push!(err,key => repr(type))
                return def
            end # end haskey
        else # in case not req
            if haskey(op,key)
                return op[key]
            else             
                return def
            end
        end
    end # end get 
end

function report_errors(error_dict; fatal = true, path = homedir(), name = "Julia_repo_make_ERRORS.log")
    if !isempty(error_dict)
        path = joinpath(path,name)
        for (key,val) in error_dict
            println("ERROR in \"configuration.toml\". You must provide a valid ",repr(val)," input to: ", repr(key), " option.")
            flush(stdout)
        end
        file = open(path,"w")
        for (key,val) in error_dict
            println(file,"ERROR in \"configuration.toml\". You must provide a valid ",repr(val)," input to: ", repr(key), " option.")
            flush(file)
        end
        close(file)
        println("Errors are saved at: ", repr(path))
        if fatal 
            exit(1)
        end
    end
end