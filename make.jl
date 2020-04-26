using Dates
using LibGit2
using Pkg
using Pkg: GitTools
using UUIDs
using DelimitedFiles
using SHA
# using Logging


user_original_directory = pwd()                 # where are we right now (this is the place that we have opend our terminal)
project_root = @__DIR__                         # this is the root directory of the program.

# cd(project_root)

# Internal constants

# =========================================> change to the better version ================
include("./modules/inputs.jl")
# include(joinpath(project_root,SCREIPTS_DIR_NAME,"inputs.jl"))
include("./modules/functions.jl")
# include(joinpath(project_root,SCREIPTS_DIR_NAME,"functions.jl"))




if CLEAN_INSTALLATION
    remove_dir!(PREFIX)
end

mkpath(PREFIX)

handle_dublicate_file(joinpath(BUILD_INFORMATION_PATH,"BUILD_LOG.log"))
julia_version_compatibility_check()
if LOGGING_TO_FILE
logprintln("== In case of crash, build log is available at: $(joinpath(BUILD_INFORMATION_PATH,"BUILD_LOG.log")).")
end

Saving_the_build_information(BUILD_INFORMATION_PATH)
if SILENT
    logprintln("== Silent installation mode.")
end
logprintln("WARNING: DO NOT type your password into this program.")
@warn("DO NOT type your password into this program.")

# ====================== PHASE 1 ======================= 
# reading configuration.toml
# downloading files provided in configuration.toml
# saving the metadata

logprintln("== downloading Project.toml and Manifest.toml files...")
special_project_files = handle_files(configuration["include"],"projects",SP_PROJECTS_PATH)
@debug("DEBUG: Project Addresses: ", special_project_files)
special_manifest_files = handle_files(configuration["include"],"manifests",SP_MANIFESTS_PATH)
@debug("DEBUG: Manifest Addresses: ", special_manifest_files)
keep_online_files = handle_files(configuration["include"],"keep_online",KEEP_ONLINE_PATH) 
remove_from_repo_files = handle_files(configuration["include"],"remove_from_repo",REMOVE_FROM_REPO_PATH) 

logprintln("    >> Saving metadata...")

if !isempty(special_manifest_files) save_data(special_manifest_files,META_DATA_PATH,"SPMANIFESTS_PATH.DATA") end
if !isempty(special_project_files)  save_data(special_project_files,META_DATA_PATH,"SPPROJECTS_PATH.DATA")   end
if !isempty(keep_online_files)  save_data(keep_online_files,META_DATA_PATH,"KEEPONLINE_PATH.DATA")   end
if !isempty(remove_from_repo_files)  save_data(remove_from_repo_files,META_DATA_PATH,"REMOVEFROMREPO_PATH.DATA")   end
# logprintln("<> all done. successfully downloaded all Project.toml and Manifest.toml files")
logprintln("<> Done.")

logprintln("== Cloning registeries...")
cloned_registeries_path = cloning_registeries(configuration["include"],"registries",SP_REG_PATH)
@debug("DEBUG: cloned_registeries_path: ",cloned_registeries_path)
logprintln("    >> Saving metadata...")
save_data(cloned_registeries_path,META_DATA_PATH,"CLONED_REGISTERIES_PATH.DATA")
logprintln("<> Done.")



# ======================== PHASE TWO ==========================
# Reading metadata
# Preparing a download list

spr_path, spm_path, spp_path, ko_path, rm_path = read_meta_data_phase2()

# I found more conviniet to work with a simpler dictionary structure.
# reconstruction of packages metadata.
all_packages_names_dict = Dict{String,String}()
all_packages_addresses_dict = Dict{String,String}()
all_packages_urls_dict = Dict{String,String}()
download_list = String[]
download_list_urls_dict = Dict{String,String}()

logprintln("== Preparing metadata...")
fetch_packages_names_and_addresses!(all_packages_names_dict, all_packages_addresses_dict, spr_path)
packages_metadata = Dict("names" => all_packages_names_dict, "addresses" => all_packages_addresses_dict)
get_urls!(all_packages_urls_dict,packages_metadata["addresses"])
if rm_path != nothing
    remove_from_repo_packages = read_remove_from_repo_packages(rm_path,packages_metadata)
else
    remove_from_repo_packages = nothing
end

if configuration["options"]["download_all_packages"]
    logprintln("== All repo mode ...")
    download_list = collect(keys(packages_metadata["names"]))
else
    logprintln("== Partial repo mode ...")
    if spp_path != nothing
        read_packages_in_projects!(download_list,spp_path)
    end
    if spm_path != nothing
        read_packages_in_manifests!(download_list,spm_path)
    end
    remove_stdlib_packages!(download_list)
end

logprintln("    >> Preparing download list ...")
if remove_from_repo_packages != nothing
    remove!(download_list,remove_from_repo_packages)
end
if ko_path != nothing
    remove_keep_online_packages!(download_list,ko_path)
end
make_download_list!(download_list_urls_dict,download_list,all_packages_urls_dict)



# ============== Phase 3 [Downloading] ==========

logprintln("== Downloading packages...")
broken_packages_dict , downloaded_packages_path_dict, downloaded_packages_rel_path_dict = make_repo(download_list_urls_dict,packages_metadata)

handel_brocken_packages_metadata(broken_packages_dict,packages_metadata)

# =========== Phase 4 [Making new repo] =========

if MAKE_LOCAL_ACCESS_REG
    logprintln("== Making new registry for local access ...")
    type = "local"
    reg_root = joinpath(NEW_REG_PATH, LOCAL_REG_DIR)
    make_reg(packages_metadata,
                download_list_urls_dict,
                broken_packages_dict,
                reg_root,
                type,
                downloaded_packages_path_dict,
                downloaded_packages_rel_path_dict)
end

if INSTALL_ON_NETWORK
    logprintln("== Making new registry for public access ...")
    type = "public_access"
    reg_root = joinpath(NEW_REG_PATH, PUBLIC_REG_DIR)
        make_reg(packages_metadata,
        download_list_urls_dict,
        broken_packages_dict,
        reg_root,
        type,
        downloaded_packages_path_dict,
        downloaded_packages_rel_path_dict)
end


logprintln("""
==========================================
               Finished                     
==========================================
""")