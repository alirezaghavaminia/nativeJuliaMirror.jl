function safeName(input::AbstractString)
    chars = ["/", "\\", "\"", "?", "<", ">", "*", ":","\'", "|"]
    output = input
    for mchar in chars
        output = replace(output,mchar=>"_")
    end
    if output[1] == '.'
        output = replace(output,"."=>"_",count=1)
    end
    len = length(output)
    if len > 240 
        output = output[len - 240, len]
    end
    return output
end

function logprint(Arg...; log = LOGGING_TO_FILE, path = BUILD_INFORMATION_PATH)
    if log
        if !isdir(BUILD_INFORMATION_PATH)
            mkpath(BUILD_INFORMATION_PATH)
        end
        io = open(joinpath(path,BUILD_LOG_FILE_NAME),"a")  
        for component in Arg
            print(io,component)
        end
        close(io)
    end
    for component in Arg
        print(component)
    end
    flush(stdout)
end

logprintln(Args...;log = LOGGING_TO_FILE , path = BUILD_INFORMATION_PATH) = logprint(Args...,'\n';log=log , path = path)

function julia_version_compatibility_check()
    logprintln("== Checking Julia version...")
    if VERSION < v"1.2.0"
        logprintln("ERROR: Incompatible Julia version: At least julia 1.2.0 is required")
    else 
        logprintln("    <> Julia VERSION $(VERSION) is enaugh.")
    end
    return nothing
end


"""
making or use the build directory and append the new date and time to that.
"""
function Saving_the_build_information(path,type)
    logprintln("== Saving the build information...")
    mkpath(path)  
    Build_Spec_File = open(joinpath(path,BUILD_TIME_FILE_NAME), "a")
    if type == :start
        write(Build_Spec_File, "Started at: $(repr(Dates.now()))\n",)
    end
    if type == :finish
        write(Build_Spec_File, "  Ended at: $(repr(Dates.now()))\n",)
    end
    close(Build_Spec_File)
    logprintln("    <> Saved build time at: $(path)/$(BUILD_TIME_FILE_NAME)")
end

function remove_dir!(path, info="";force = true, recursive = true) 
    if !SILENT
        logprintln("Do you confirm removing \"$(path)\": [type \"y\" and Enter to remove or press any other keys to decline]")
        answer = lowercase(readline())
    else
        answer = "y" 
    end
    if answer == "y" || answer == "Y"
        if info ==""
            logprintln("Removing $(path)")
        else
            logprintln(info)
        end
        rm(
            path,
            force = force,
            recursive = recursive,
        )
    end
    return nothing
end

function download_a_file(url::AbstractString,target_directory::AbstractString,file_name::AbstractString)
    mkpath(target_directory)
    path = joinpath(target_directory,file_name)
    file_name_and_address = download(url,path)
    return file_name_and_address
end 

function handle_files(op,key,target;backup = MAKE_BACKUPS)
    target_directory = joinpath(target)
    downloaded_files_pathes = String[]
    if haskey(op, key)
        for item in op[key]
            url = item["url"]
            logprintln("* downloading $(repr(url))...")
            file_name = safeName(url)
            file_name_and_address = joinpath(target_directory,file_name)
            if isfile(file_name_and_address) && !REFRESH_CONF_FILES
                logprintln("    >> The specified file $(repr(url)) already exists at $(joinpath(target_directory,file_name)). skipping download ...")
                push!(downloaded_files_pathes,file_name_and_address)
            else
                mkpath(target_directory)
                handle_dublicate_file(file_name_and_address)
                try   # =================================== TODO: make it a function 
                file_name_and_address = download_a_file(url,target_directory,file_name)
                push!(downloaded_files_pathes,file_name_and_address)
                catch e
                    logprintln(e)
                end
            end
        end
    end   
    return downloaded_files_pathes
end

function maketempdir()::String
    dir::String = mktempdir()
    atexit(() -> rm(dir; force = true, recursive = true,))
    return dir
end

function git_clone(url::AbstractString, path::AbstractString)
    if path ==  nothing
        tmp = maketempdir()
    else 
        tmp = path
    end
    mkpath(tmp)
    Base.shred!(LibGit2.CachedCredentials()) do creds
        LibGit2.with(
            Pkg.GitTools.clone(
                url,
                tmp;
                header = "registry from $(repr(url))",
                credentials = creds,
                )
            ) do repo
        end
    end
    return tmp
end


function git_update(path)
    errors = Tuple{String, String}[]
    if isdir(joinpath(path,REPO_PATH_EXTENTION))
        repo = nothing
        try 
            repo = LibGit2.GitRepo(path)
            if LibGit2.isdirty(repo)
                push!(errors, (path, "repo is dirty"))
                @goto done
            end
            if !LibGit2.isattached(repo)
                push!(errors,(path, "registry detached"))
                @goto done
            end
            branch = LibGit2.headname(repo)
            try
                GitTools.fetch(repo; refspecs=["+refs/heads/$branch:refs/remotes/origin/$branch"])
            catch e
                push!(errors, (path, "failed to fetch from repo"))
                @goto done
            end
            ff_succeeded = try
                LibGit2.merge!(repo; branch="refs/remotes/origin/$branch", fastforward=true)
            catch e 
                e isa LibGit2.GitError && e.code == LibGit2.Error.ENOTFOUND || rethrow()
                push!(errors, (repo.path, "branch origin/$branch not found"))
                @goto done
            end
            if !ff_succeeded
                try LibGit2.rebase!(repo, "origin/$branch")
                catch e
                    e isa LibGit2.GitError || rethrow()
                    push!(errors, (repo.path, "registry failed to rebase on origin/$branch"))
                    @goto done
                end
            end
            @label done
        finally
            if repo isa LibGit2.GitRepo
                close(repo)
            end # end if 
        end
    end # end if 
    if !isempty(errors) # TODO: Add instructions in case of package failure 
        warn_str = "Failed to update the repo."
        @warn warn_str
        logprintln("WARNING: ",warn_str)
    end # end if 
    return 
end # end function 

function handle_a_git_repo(url, path; update = UPDATE_MODE)
    errors = Tuple{String,String}[]
    if isdir(joinpath(path,REPO_PATH_EXTENTION)) && update
        logprintln("    >> repo already exists at: \"",path,"\"")
        logprintln("    >> Trying to update...")

        update_errors = Tuple{String,String}[]
        try
            git_update(path)
        catch e
            logprintln("    >> Error in update...")
            logprintln(e)
            push!(update_errors,(path,"Error in update"))
        end
        if !isempty(update_errors)
            logprintln("    >> Try cloning...")
            logprintln("    >> Macking a backup from old repo...")
            try
                cp(joinpath(path),joinpath(path*"(backup)"))
            catch e
                rm(joinpath(path*"(backup)"),
                recursive = true,
                force = true)
                cp(joinpath(path),joinpath(path*"(backup)"))
            end
            rm(joinpath(path),recursive = true, force = true)
            newclown = Tuple{String,String}[]
            try 
                git_clone(url, path)
            catch e 
                push!(errors, (url,"Cloning repo faild"))
                logprintln(e)
            end
            if isempty(errors)
                rm(joinpath(path*"(backup)"),
                recursive = true,
                force = true)
            end

        end
        # logprintln("    >> updated successfully.")
    elseif isdir(joinpath(path,REPO_PATH_EXTENTION)) && !update
        logprintln("    >> repo already exists at: \"",path,"\"")
        logprintln("    >> skipping the update...")
    else
        try 
            git_clone(url, path)
        catch e
            push!(errors, (url,"Cloning repo faild"))
            logprintln(e)
        end
    end
    if !isempty(errors)
        warn_str = "Faild to clone a repo from: " * url
        @warn warn_str
        logprintln("WARNING: ",warn_str)
        return "failed"
    else
        return "success"
    end
end

function cloning_registeries(op,key,target)
    cloned_registeries_path = String[]
    for registery in op[key]
        url = registery["url"]
        save_at = safeName(url)
        path = joinpath(target,save_at)
        logprintln("* Handling repo: ",repr(url))
        handle_a_git_repo(url,path)
        push!(cloned_registeries_path,path)
    end
    return cloned_registeries_path
end

function save_data(vector::Vector,path::String,name::String)
    mkpath(path)
    file = open(joinpath(path,name),"w")
    writedlm(file,vector)
    close(file)
end

read_vector(file_path) = vec(readdlm(file_path))

function read_meta_data_phase2()
    spr_path = nothing
    spm_path = nothing
    spp_path = nothing
    ko_path = nothing
    rm_path = nothing
    spr_metadata = joinpath(META_DATA_PATH,"CLONED_REGISTERIES_PATH.DATA")
    if isfile(spr_metadata)
        spr_path = read_vector(spr_metadata)
    end
    spm_metadata = joinpath(META_DATA_PATH,"SPMANIFESTS_PATH.DATA")
    if isfile(spm_metadata)
        spm_path = read_vector(spm_metadata)
    end
    spp_metadata = joinpath(META_DATA_PATH,"SPPROJECTS_PATH.DATA")
    if isfile(spp_metadata)
        spp_path = read_vector(spp_metadata)
    end
    keep_online = joinpath(META_DATA_PATH,"KEEPONLINE_PATH.DATA")
    if isfile(keep_online)
        ko_path = read_vector(keep_online)
    end
    remove_from_repo = joinpath(META_DATA_PATH,"REMOVEFROMREPO_PATH.DATA")
    if isfile(remove_from_repo)
        rm_path = read_vector(remove_from_repo)
    end
    return spr_path, spm_path, spp_path, ko_path, rm_path
end

"""
    fetch_packages_names_and_addresses!(packages_names_dict, packages_addresses_dict, spr_path)
To handle the cases whith several Registry input, this function records all the names and addresses
of every package available in the provided registries. 
This absolute addresses can be handy in the last step which is coping the packages metadata.
"""
function fetch_packages_names_and_addresses!(packages_names_dict, packages_addresses_dict, spr_path)
    for reg_path in spr_path
        reg_file_name_and_address = joinpath(reg_path,"Registry.toml")
        parsed_registery = Dict{String,Any}()
        try
            parsed_registery = Pkg.TOML.parsefile(reg_file_name_and_address)
        catch e
            logprintln(e)
        end
        for uuid in keys(parsed_registery["packages"])
            push!(packages_names_dict,uuid=>parsed_registery["packages"][uuid]["name"])
            push!(packages_addresses_dict,uuid=>joinpath(reg_path,splitpath(parsed_registery["packages"][uuid]["path"])...))
        end
    end    
end


has(x::AbstractString, y) = x == y

has(x::AbstractArray, y) = any(has(i, y) for i in x)

"""
Returns a vector of UUIDs if there are several maches.
"""
function get_uuid(name::String,d::Dict)
    [k for (k,v) in d if has(v, name)]
end

"""
    get_address(input::String, type = :uuid, packages_metadata = packages_metadata)

returns an array of addresses of specified package.
Default input type is `:uuid` if type `:name` specitied,
returns an array of all matches to the input type `:name`
    
#Example:

```julia_repel
julia> get_address("Example",:name)
```
"""
function get_address(input::String, type = :uuid, packages_metadata = packages_metadata)
    uuid = input
    out = []
    if type == :name
        uuid = get_uuid(input,packages_metadata["names"])
    end
    for id in uuid
        push!(out,packages_metadata["addresses"][id])
    end
    return out
end

"""
Reads a project file (in the format of julia ```Project.toml```)
and returns the UUIDs for packages in that file.
"""
function read_packages_in_projects!(download_list,spp_path)
    for path in spp_path
        push!(download_list,values(Pkg.TOML.parsefile(path)["deps"])...)
    end
    unique!(download_list)
end

"""
Reads a manifest file (in the format of julia ```Manifest.toml```)
and returns the UUIDs for packages in that file.
"""
function read_packages_in_manifests!(download_list,spm_path)
    for path in spm_path
        p = Pkg.TOML.parsefile(path)
        for key in keys(p)
            for i = 1:size(p[key],1) 
                push!(download_list,p[key][1]["uuid"])
            end
        end
    end
    unique!(download_list)
end

function read_remove_from_repo_packages(rm_path,packages_metadata = packages_metadata)
    rm_packages = String[]
    rm_packages_uuid = String[]
    for file in rm_path
        rm_packages = push!(Pkg.TOML.parsefile(file)["packages"]["name"])
    end
    unique!(rm_packages)
    for name in rm_packages
        push!(rm_packages_uuid, get_uuid(name,packages_metadata["names"])...)
    end
    unique!(rm_packages_uuid)
end

"""
    is_stdlib(id::String)

returns `true` if the id belongs to any Julia standard library
"""
is_stdlib(id::String) = Pkg.Operations.is_stdlib(UUID(id))

"""
    remove_stdlib_packages!(list)

removes all standard library uuids from the list which must contain a list of packages uuids. 
"""
function remove_stdlib_packages!(list)
    deleteat!(list,[is_stdlib(item) for item in list])
end


function remove_keep_online_packages!(list,ko_path,packages_metadata = packages_metadata)
    ko_packages = String[]
    ko_packages_uuid = String[]
    for file in ko_path
        ko_packages = push!(Pkg.TOML.parsefile(file)["packages"]["name"])
    end
    unique!(ko_packages)
    for name in ko_packages
        push!(ko_packages_uuid, get_uuid(name,packages_metadata["names"])...)
    end
    unique!(ko_packages_uuid)
    setdiff!(list,ko_packages_uuid)
end

function get_urls!(urls, dict = packages_metadata["addresses"])
    for id in keys(dict)
        path = joinpath(dict[id],"Package.toml")
        p = Pkg.TOML.parsefile(path)
        if id != p["uuid"]
            logprintln("WARNING: The \"",id,"\" uuid doesn't mach the UUID in the registery metadata.")
        end
        push!(urls,id => p["repo"])
    end
end


function make_download_list!(out::Dict{String,String},list::Array{String},d::Dict)
    for id in list
        push!(out, id => d[id])
    end
end

"""
    remove!(d::Dict,keys::Vector)

Removes keys from dictionary d.

    remove!(a::Array,b::Array)

Removes all members of b from the a
"""
function remove!(d::Dict,keys::Vector) 
    for key in keys
        delete!(d,key)
    end
    return d
end

function remove!(a::Array,b::Array)
    setdiff!(a,b)
end

function remove!(d::Dict{String,Dict{String,String}},list::Array{String,1})
    remove!(d["names"],list)
    remove!(d["addresses"],list)        
end

function remove!(a::Dict{String,Dict{String,String}},b::Dict{String,Dict{String,String}})
    list = collect(keys(b))
    remove!(a,b)
end


"""
    generate_path(uuid,packages_metadata = packages_metadata,; prefix = PREFIX, repo = REG_DIR)

Creates a path based on the package UUID,name.
path = joinpath(prefix,repo,first capital leter of the name,name,uuid,name*".jl.git")
"""
function generate_path(uuid,packages_metadata = packages_metadata; prefix = PACKAGES_PATH)
    name = packages_metadata["names"][uuid]
    rel_path = joinpath(string(uppercase(name[1])),name,uuid,name*".jl$(REPO_PATH_EXTENTION)")
    path = joinpath(prefix,rel_path)
    return path, rel_path
end

"""
    make_repo(download_list_urls_dict,packages_metadata = packages_metadata)

Gets all packages listed in \"download_list_urls_dict\".
The function will try to update a packages if it finds 
an older version. returns the list of packages that could not be cloned. 
being unable to update is not considered an error. 
"""
function make_repo(download_list_urls_dict,packages_metadata = packages_metadata)
    brokenPackages = Dict{String,String}()
    downloaded_packages_path_dict = Dict{String,String}()
    downloaded_packages_rel_path_dict = Dict{String,String}()
    ll = size(collect(keys(download_list_urls_dict)),1)
    for (i,id) in enumerate(keys(download_list_urls_dict))
        logprintln("* ",i,"/",ll," ",packages_metadata["names"][id],".jl")
        url = download_list_urls_dict[id]
        path, rel_path = generate_path(id,packages_metadata)
        push!(downloaded_packages_path_dict,id => path)
        push!(downloaded_packages_rel_path_dict,id => rel_path)
        println(path)
        mkpath(path)
        result = handle_a_git_repo(url,path)
        if result == "failed"
            push!(brokenPackages,id => url)
            delete!(downloaded_packages_path_dict,id)
            rm(
                path,
                force = true,
                recursive = true,
            )
        end
    end
    return brokenPackages, downloaded_packages_path_dict, downloaded_packages_rel_path_dict
end 

"""
    handle_dublicate_file(file, backup = true)

if backup is true,make a copy of the \"file\" with the \"backup_\" prefix and removes the original file. Otherwise removes the file
"""
function handle_dublicate_file(file; backup = MAKE_BACKUPS)
    sp = splitpath(file)
    dest = joinpath(sp[1:end-1]...,"backup_"*sp[end])
    if isfile(file)
        if backup == true
            cp(file,dest,force = true)
            logprintln("    >> creating a backup from: ",file,"\n       to: ",dest)
        end
        rm(file,force = true)
    end
end

"""
    save_broken_packages(d,md = packages_metadata)
gets the dictionary \"d\" and makes two \"TOML\" file. One with the 
format of julia \"Project.toml\" file format which can be used as an input
to special projects key in \"configuration.toml\" and one with the acceptable
format for the \"keep_online\" and \"remove_from_repo\" format in the
\"configuration.toml\"

Note: The function keeps one (and only one) backup from previous build if 
Clean installation has been set to false. 
"""
function save_broken_packages(d,md = packages_metadata)
    mkpath(BUILD_INFORMATION_PATH)
    path = joinpath(BUILD_INFORMATION_PATH,"broken_packages.toml")
    logprintln("== saving broken packages names to: ", path)
    logprintln("   you can feed this file to exclude packages.")
    handle_dublicate_file(path)
    file = open(path,"w")
    println(file,"[packages]\nname = [")
    for id in keys(d)
        println(file,"\t",repr(packages_metadata["names"][id]),",")
    end
    println(file,"]")
    close(file)

    path = joinpath(BUILD_INFORMATION_PATH,"broken_packages_Project.toml")
    logprintln("== saving broken packages names to: ", path)
    logprintln("   This file is in the format of julia \"Project.toml\".")
    handle_dublicate_file(path)
    file = open(path,"w")
    println(file,"[deps]")
    for id in keys(d)
        println(file,packages_metadata["names"][id], " = ",repr(id))
    end
    close(file)
end

function handel_brocken_packages_metadata(broken_packages_dict,packages_metadata)
    if !isempty(broken_packages_dict) 
        save_broken_packages(broken_packages_dict,packages_metadata)
    else
        logprintln("== There are no broken packages.")
        logprintln("   >> making backup from the old broken packages lists if there are any.")
        path = joinpath(BUILD_INFORMATION_PATH,"broken_packages.toml")
        handle_dublicate_file(path)
        path = joinpath(BUILD_INFORMATION_PATH,"broken_packages_Project.toml")
        handle_dublicate_file(path)
    end
end


# ======================= PHASE 4 functions ==============================
function copy_package_metadata_to_new_reg(uuid,packages_metadata,new_reg_root_path)
    original_reg_metadata_path = packages_metadata["addresses"][uuid]
    name = packages_metadata["names"][uuid]
    target = joinpath(new_reg_root_path,string(uppercase(name[1])),name) # following julia registry pattern here. I dont know what will happen in case of similarities in the names.
    mkpath(target)
    cp(original_reg_metadata_path,target,force = true)
    return target
end

function change_url_in_package_metadata(package_metadata_root,
        type,
        abs_path_to_package_git,
        rel_path_to_package_git)
    path = joinpath(package_metadata_root,"Package.toml") # following julia registry pattern here. I dont know what will happen in case of similarities in the names.
    if isfile(path)
        p = Pkg.TOML.parsefile(path)
        p["repo"] = get_new_url(type,abs_path_to_package_git,        rel_path_to_package_git)
        rm(path,force = true)
        file = open(path,"w")
        Pkg.TOML.print(file, p)
        close(file)
    else
        logprintln("No Package.toml for this package has been found.")
    end
end

function get_new_url(type,abs_path_to_package_git,rel_path_to_package_git)
    if type == "public_access"
        url = NETWORK_PREFIX
        while url[end] == '/'
            url = url[1:end-1]
        end
        url = url *"/" * PACKAGES_DIR
        for comp in splitpath(rel_path_to_package_git)
            url = url*"/"*comp
        end
    elseif type == "local"
        url = abs_path_to_package_git
    end
    return url
end


function commit_changes(reg_root)
    logprintln("    >> Updating the registry git repo ...")
    logprintln("       *tracking files and staging changes...")

    if !isdir(joinpath(reg_root),".git")
        try
            LibGit2.init(reg_root)
        catch e
            logprintln("WARNING: Unanle to initialize git in the Registry.")
        end 
    end

    git_repo = LibGit2.GitRepo(reg_root) # Open a git repository at path.
    LibGit2.add!(git_repo, "Registry.toml",) # Add all the files with paths specified by files to the index idx (or the index of the repo).
    # for i = 'A':'Z'
    #     logprintln("        >> Tracking ",string(i),"/...")
    #     # LibGit2.add!(git_repo, joinpath(reg_root,string(i)))
    #     LibGit2.add!(git_repo,string(i))
    # end
    LibGit2.add!(git_repo,".")
    logprintln("        <> successfully tracked all files and staged all changes")

    logprintln("        * committing...")
    commit_msg = "Automated commit made on $(repr(Dates.now())). $(GIT_COMMIT_INFO)" 
    sig = LibGit2.Signature(
        MY_GIT_USER_NAME,
        MY_GIT_USER_EMAIL,
        )
    LibGit2.commit(git_repo,commit_msg;author = sig,committer = sig,) # committing the repo 
    all_project_remotes = LibGit2.remotes(git_repo)
    for project_remote in all_project_remotes
        LibGit2.remote_delete(git_repo, project_remote)
    end
    logprintln("    <> successfully committed all changes.")
end






function make_reg_toml(make_repo_for_this_packages,packages_metadata,reg_root,type)
    logprintln("    >> Writing new Registery.toml...")
    path = joinpath(reg_root,"Registry.toml")
    file = open(path,"w")
    println(file,"name = ",repr(MY_REGISTRY_NAME))
    println(file,"uuid = ",repr(MY_REGISTRY_UUID))
    if type == "local"
        println(file,"repo = ",repr(joinpath(reg_root))) # change
    end
    if type == "public_access"
        url = NETWORK_PREFIX
        while url[end] == '/'
            url = url[1:end-1]
        end
        url = url * "/" * NEW_REG_DIR * "/" * PUBLIC_REG_DIR
        println(file,"repo = ",repr(url)) # change
    end
    println(file,"\ndescription = ","\"\"\"\n$(HEADER_MASSAGE) $(MY_INFO)\n\"\"\"\n")
    println(file,"[packages]")
    for (i,id) in enumerate(keys(make_repo_for_this_packages))
        name = packages_metadata["names"][id]
        println(file,id," = { name = ",repr(name),", path = ","\"",string(uppercase(name[1])),"/",name,"\""," }")
    end
    close(file)  
end



function make_reg(packages_metadata,
    download_list_urls_dict,
    broken_packages_dict,
    reg_root,
    type,
    downloaded_packages_path_dict,
    downloaded_packages_rel_path_dict)

        if MINIMAL_REG
            make_repo_for_this_packages = download_list_urls_dict
        else
            make_repo_for_this_packages = packages_metadata["names"]
        end

        # ll = size(collect(keys(make_repo_for_this_packages)))

        for (i,id) in enumerate(keys(make_repo_for_this_packages))
            
            new_metadata_path = copy_package_metadata_to_new_reg(id,packages_metadata,reg_root)
            
            # logprint(i,"/",ll," ",packages_metadata["names"][id])
            # padding = maximum(sizeof.(collect(values(packages_metadata["names"])))) + 35
            if haskey(download_list_urls_dict,id)
                if haskey(broken_packages_dict,id)
                    # logprintln(lpad(" ==> status: Failed to clone using online repo insted",padding - sizeof(packages_metadata["names"][id]) + 29 - size(digits(i),1)," " ))
                else
                    # logprintln(lpad(" ==> status: Local repo",padding - sizeof(packages_metadata["names"][id]) -1 - size(digits(i),1)," " ))


                    change_url_in_package_metadata(new_metadata_path,type,downloaded_packages_path_dict[id],downloaded_packages_rel_path_dict[id])
                end
            else
                # logprintln(lpad(" ==> status: Online repo",padding - sizeof(packages_metadata["names"][id]) - size(digits(i),1)," "))
            end
        end # end for id in keys

        make_reg_toml(make_repo_for_this_packages,packages_metadata,reg_root,type)
        commit_changes(reg_root)
end