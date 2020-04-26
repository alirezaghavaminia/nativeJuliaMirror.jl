using Pkg
using UUIDs

userpath = pwd()
rootdir = @__DIR__
cd(rootdir)
reg_reg_path = joinpath(rootdir,"registries","NHPCC_Julia_Packages_Repo","Registry.toml")
reg_path = joinpath(rootdir)
reg = Pkg.TOML.parsefile(reg_reg_path)
reg_name = reg["name"]
reg_uuid = reg["uuid"]
reg_uuid_id = UUIDs.UUID(reg_uuid)

pushfirst!(Base.DEPOT_PATH,reg_path)
pushfirst!(Base.DEPOT_PATH,joinpath(homedir(),".julia.isolated",reg_name, reg_uuid))


filter!((x) -> !(Base.Filesystem.samefile(expanduser(x),expanduser("~/.julia")) || lowercase(strip(abspath(expanduser(x)))) == lowercase(strip(abspath(expanduser("~/.julia")))) || Base.Filesystem.samefile(x,"~/.julia") || lowercase(strip(abspath(x))) == lowercase(strip(abspath("~/.julia"))) || Base.Filesystem.samefile(expanduser(x),expanduser(joinpath(homedir(), ".julia"))) || lowercase(strip(abspath(expanduser(x)))) == lowercase(strip(abspath(expanduser(joinpath(homedir(), ".julia"))))) || Base.Filesystem.samefile(x,joinpath(homedir(), ".julia")) || lowercase(strip(abspath(x))) == lowercase(strip(abspath(joinpath(homedir(), ".julia"))))), Base.DEPOT_PATH)

unique!(Base.DEPOT_PATH)

try
    if !any(
            [
                (x.name == reg_name &&
                    (x.uuid == reg_uuid ||
                        x.uuid == reg_uuid_id)) for
                            x in Pkg.Types.collect_registries()
                ]
            )
        Pkg.Registry.add(
            Pkg.RegistrySpec(path = joinpath(splitpath(@__DIR__)...),)
            );
    end
catch e
    @warn("ignoring exception: ", e,);
end

cd(userpath)