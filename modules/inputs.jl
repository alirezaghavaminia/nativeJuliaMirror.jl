include("check_inputs.jl")

# check for input errors
input_errors = Dict{String,String}()
@info("== parsing \"configuration.toml\"...")
configuration = Pkg.TOML.parsefile(joinpath(project_root,"configuration.toml"))
@info("    <> Done.")

op = configuration["options"]


const DOWNLOAD_ALL_PACKAGES     = input(op,"download_all_packages",input_errors, def = true)
const MY_REGISTRY_NAME          = input(op,"new_registry_name",   input_errors, def = "")
const MY_REGISTRY_UUID          = input(op,"new_registry_uuid",   input_errors, def = "")
const MY_REGISTRY_UUID_OBJECT   = UUIDs.UUID(MY_REGISTRY_UUID)
const TMP_TARGET                = input(op,"prefix",              input_errors, def = "")
cd(TMP_TARGET)
const PREFIX = pwd()
cd(user_original_directory)
const MY_GIT_USER_NAME          = input(op,"git_user_name",       input_errors, def = "")
const MY_GIT_USER_EMAIL         = input(op,"git_user_email",      input_errors, def = "")
const MY_INFO                   = input(op,"your_info",           input_errors, def = "",    req = false)
const GIT_COMMIT_INFO           = input(op,"git_commit_info",     input_errors, def = "",    req = false)
const LOGGING_TO_FILE           = input(op,"log_to_file",         input_errors, def = true,  req = false)
const SILENT                    = input(op,"silent_installation", input_errors, def = false)
const UPDATE_MODE               = input(op,"update_mode",         input_errors, def = true,  req = false)
const REFRESH_CONF_FILES        = input(op,"refresh_conf_files",  input_errors, def = true,  req = false)
const MAKE_BACKUPS              = input(op,"make_backups",        input_errors, def = true,  req = false)
const CLEAN_INSTALLATION        = input(op,"clean_installation",  input_errors, def = false, req = false)

const INSTALL_ON_NETWORK        = input(op,"install_on_network",  input_errors, def = true,  req = false)
if INSTALL_ON_NETWORK
    const NETWORK_PREFIX = input(op,"network_access_address",input_errors, def = "", req = true)
end
const MAKE_LOCAL_ACCESS_REG = input(op, "make_local_access_reg", input_errors,  def = true, req = false)
const MINIMAL_REG           = input(op, "minimal_reg",           input_errors,  def = false, req = false)





# Internal constants
const HEADER_MASSAGE = """
Mirror registry"""

const SCREIPTS_DIR_NAME = "modules"
const BUILD_INFORMATION_DIR = "build_info"
const BUILD_LOG_FILE_NAME = "BUILD_LOG.log"
const PACKAGES_DIR = "packages"
const NEW_REG_DIR = "registry"
const SRC_DIR = "op_include"
const REG_DIR = "sp_registries"
const PROJECTS_DIR = "sp_projects"
const MANIFESTS_DIR = "sp_manifests"
const KEEP_ONLINE_DIR = "keep_online"
const REMOVE_FROM_REPO_DIR = "remove_from_repo"
const DATA_DIR = "META_DATA"
const REPO_PATH_EXTENTION = ".git"
const LOCAL_REG_DIR = "local_access"
const PUBLIC_REG_DIR = "public_access"
# const REPO = "repo"
# const REG = "registries"
const PACKAGES_PATH          = joinpath(PREFIX,PACKAGES_DIR)
const NEW_REG_PATH           = joinpath(PREFIX,NEW_REG_DIR)
const BUILD_INFORMATION_PATH = joinpath(PREFIX,BUILD_INFORMATION_DIR)
const META_DATA_PATH         = joinpath(PREFIX,BUILD_INFORMATION_DIR,DATA_DIR)
const SRC_PATH               = joinpath(PREFIX,SRC_DIR)
const SP_REG_PATH            = joinpath(PREFIX,SRC_DIR,REG_DIR)
const SP_PROJECTS_PATH       = joinpath(PREFIX,SRC_DIR,PROJECTS_DIR)
const SP_MANIFESTS_PATH      = joinpath(PREFIX,SRC_DIR,MANIFESTS_DIR)
const KEEP_ONLINE_PATH       = joinpath(PREFIX,SRC_DIR,KEEP_ONLINE_DIR)
const REMOVE_FROM_REPO_PATH  = joinpath(PREFIX,SRC_DIR,REMOVE_FROM_REPO_DIR)

report_errors(input_errors)



