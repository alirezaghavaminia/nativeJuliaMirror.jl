This program helps you to make a mirror repository to be used on a git server or your local machine. This program works with the Pkg3 Julia package manager.

## Description:

This program will clone packages that you specify to that through the `configuration.toml` file. Then it will make new registries for the user to use the cloned packages. 
### some features are: 

* can get multiple official or unofficial registries at the same time

* can update and maintain the cloned packages

* can create new registries for users who have access to the packages repo by local paths or through a network

* can make partial registries 

* can exclude some packages from the new registry 

* can preserve the original link to the package on the GitHub servers in the new registry 


## Prerequisites: 

A Julia language version 1.1.0 or higher is required.


## installation:

Just clone this repository from the GitHub.


## How to use (making the mirror depository):


1. Make the path that you want to be the location for your new packages depot. 

1. Change the `configuration.toml` file located in the program directory as you wish.

1. Run the program with `julia make.jl` command.


## How to use (using the mirror depository):

When the `julia make.jl` command finished making the mirror depository, regarding your choice of the installation (Installation on the network or local), You must have one or two new registry directories. These new registries will be located in the `prefix/registry` address. You may find one of the `local_access`, `public_access`, or both of those directories in the `registry` directory. 

If you want to use the mirror repository using local addresses in your local machine, use the `local_access` registry. If you're going to use the mirror repository through a network, you should use the `public_access`registry. This registry must be accessible through the network, or the users will face errors.

Open a Julia session and use this code:

```julia 
using Pkg
address = "The/URL/or/path/to/the/newly/created/registries"
Pkg.Registry.add(RegistrySpec(url = address))
```

You can remove the `General` registry by:

```julia 
using Pkg
Pkg.Registry.rm("General")
```

Removing the General registry may be necessary if the Julia program throws a conflict error when adding or updating packages. 

You can add the General registry back with:

```julia 
using Pkg
Pkg.Registry.add("General")
```

## Configuration:

There is a configuration file in the root directory of this script. This file contains all the configuration parameters for this program, as well as some necessary input values that you must provide for the program. 
 
The configuration file has two parts one is marked by `[include]`, and the other is marked by `[options]`. 

### [include] 

The files specified in the include section will be downloaded by the Julia language `download` command. As it has mentioned in [the Julia documentation for the `download` command]((https://docs.julialang.org/en/v1/base/file/#Base.download)), " this function relies on the availability of external tools such as `curl`, `wget` or `fetch` to download". So if your Julia download command works with the local addresses (like in the Windows 10), you can use the local addresses in this section.

#### registries

In the include section, you must provide the program with at least one registry (e.g., General registry). You can specify multiple registries by using the bellow format. All the specified registries must be a valid git rego.

```toml
[include]
registries = [
	{ url = "path/to/the/first/reg"},
	{ url = "path/to/the/second/reg"},
]
```

#### projects and manifests

If you choose not to download all the packages in the specified registries, you must specify at least one of these two files. These files contain information about the packages that you want to have locally. Note that this program is unable to resolve the package dependencies. You can resolve dependencies by adding packages using your Julia language and providing the program with the generated Project and Manifest TOML files. There are examples of these files in the `example` directory of the program.

```toml
projects = [
	{ url = "path/to/the/first/project.toml"},
	{ url = "path/to/the/second/project.toml"},
]
manifests = [
	{ url = "path/to/the/first/manifest.toml"},
	{ url = "path/to/the/second/manifest.toml"},
]
```

#### keep_online

This optional input can get one or multiple TOML files. The packages specified in these files will not be downloaded into the local repo. Still, they will be included in the created new registries, and their original URL in the provided registries will be kept intact.

The file format for this option differs from the Julia TOML files. You can see an example of this file format in the example directory of this program.

```toml
keep_online = [
    {url = "https://raw.githubusercontent.com/alirezamecheng/example/master/keep_online.toml"},
    {url = "C:\\Users\\montazer\\Desktop\\Julia_Repo\\v2\\keep_online.toml"}, # Windows OS example
    {url = ".\\examples\\keep_online.toml"}, # Windows OS example relative path
]
```

#### remove_from_repo

This optional input can get one or multiple TOML files. The packages specified in these files will not be downloaded, nor will they be included in the new registries that will be created by the program.

The file format for this option differs from the Julia TOML files. You can see an example of this file format in the example directory of this program.

```toml
remove_from_repo = [
    { url = "https://raw.githubusercontent.com/alirezamecheng/example/master/remove_from_repo.toml"},
    # {url = "C:\\Users\\montazer\\Desktop\\Julia_Repo\\v2\\remove_from_repo.toml"},
    # {url = ".\\examples\\remove_from_repo.toml"}, # Windows OS example relative path
]
```

### [options]


#### new_registry_name

You must provide a name for your new registry. This name will be shown to Julia users when performing actions on the packages in the Julia language.


#### new_registry_uuid

You must provide a valid UUID for your new registry. This UUID must be unique and will be shown and used when performing actions on the packages in the Julia language.

You can use Julia UUID package or Linux `uuidgen` command or any other program whatever you prefer to generate a UUID.

You should not change this UUID after releasing the registry because it will cause errors for Julia users who use your registry.


#### prefix

You must provide an ***existing*** and ***writable*** path to the program. This path will be used to make packages repo and registries as well as other necessary metadata for the program.

Note that in case you choose the clean installation option, all contents of this path will be removed.

In case you want to use the package repo with a git server, you must read and pay attention to the instructions in the install on the server options too.


#### git_user_name

You must provide a git username. This username will be used to commit changes in the new registries that will be created by the program.


#### git_user_email

You must provide an Email. This username will be used to commit changes in the new registries that will be created by the program.


#### your_info

Optional. The contents of this option will be added to the info section of the new registries.


#### git_commit_info

Optional. Additional information that appears in git commits.


#### install_on_network

Optional, If you want to make a mirror repo that can be accessed through a network, you need to change the value of this option to `true`. Then you should modify the `network_access_address` and `prefix` too.

Assuming that your domain address is "mydomain.com" and you have made a path for the Julia repo at "/var/www/newRepo".  If you clone a package into that directory and that package can be accessed by "https://mydomain.com/newRepo/package.jl.git". You should set the prefix to "/var/www/newRepo" and the network_access_address" to "https://www.mydomain.com/newRepo"

NOTE: Any "/" at the end of the "network_access_address" will be omitted.


#### download_all_packages

Optional. With this option, you can tell the program to download all the packages in the registry or not.

If set to `false`, you need to set the `projects` or `manifests` in the `[include]` section. Standard Julia libraries that appear in the `manifest` or `project` files will be excluded from the local repo, and their link to the original address will be kept intact.

Default value is `true`.


#### make_local_access_reg

Optional. If set to `true`, the program will make a registry that provides access to the mirrored packages for users of the server machine locally.

Default value is = `true`.


#### minimal_reg

Optional. If set to `true`, the program will make make a registry exclusively for packages that are included in the download list. The standard library packages will not be included in that list and if a package can not be downloaded, the original URL of the package will be kept intact.

Default value is = `false`.


#### clean_installation

Optional. If `true`, the program will remove every content of the `prefix` directory before the beginning of the installation. ***Before using this option, make sure you have a backup.***
Default value is = `false`.


#### update_mode

Optional. If set to `true`, the program will try to update Julia packages git repositories. If set to `false`, it will skip the update if it finds the git repository. Otherwise, the program will try to clone the git repository.

Default value is = `true`.


#### refresh_conf_file

Optional. This option, if set to `true`, will force the program to download the files specified in the `[include]` section of the `configuration.toml` file every time you run the `make.jl`, whether they already exist or not.

Default value is = `true`.


#### log_to_file

log_to_file: Optional. If `true`, it will make a log file and record the events in that file.

Default value is = `true`.


#### make_backups
Optional. When set to `true`, if the program wants to change a file that already exists, it will make a copy of that file and store it with the `backup_` prefix. ***This backup will be overwritten in the next run and will not be preserved.*** Files that are in a git repository will not be affected by this option. 

Default value is = `true`.


#### silent_installation

Optional. If `true`, the program will not ask for confirmation when it is needed (for example, when removing a file or directory).

Note: The git may ask for credentials even when setting this option to true.

Default value is = `false`.
