//metadoc Package category API
//metadoc Package description Represents an Eerie package.
doRelativeFile("SemVer.io")

Package := Object clone do (

    //doc Package manifestName The name of the manifest file.
    manifestName := "eerie.json"
    
    //doc Package config Package's config file (the manifest) as a `Map`.
    config ::= nil

    //doc Package dir Directory of this package.
    dir ::= nil

    /*doc Package sourceDir The `source` directory. `Directory` with native
    code.*/
    sourceDir := method(self dir createSubdirectory("source"))

    /*doc Package binDir 
    The `bin` directory. `Directory` with binaries of the package.*/
    binDir := lazySlot(self dir directoryNamed("bin"))

    /*doc Package destBinDir
    Get the `_bin` directory, where binaries of dependencies are installed.*/
    destBinDir := method(self dir createSubdirectory("_bin"))

    //doc Package addonsDir Get the `_addons` `Directory`.
    addonsDir := method(self dir createSubdirectory("_addons"))

    /*doc Package tmpDir 
    Get `_tmp` `Directory`, the temporary directory used by `Downloader` to
    download dependencies into.*/
    tmpDir := method(self dir createSubdirectory("_tmp"))

    /*doc Package buildDir 
    Get `_build` `Directory`, the directory where build artifacts are stored.*/
    buildDir := method(self dir createSubdirectory("_build"))

    /*doc Package headersBuildDir
    Get the output `Directory` where all the headers of this package will be
    installed.*/
    headersBuildDir := method(self buildDir createSubdirectory("headers"))

    /*doc Package objsBuildDir
    Get the output objects (`.o`) `Directory`.*/
    objsBuildDir := method(self buildDir createSubdirectory("objs"))

    /*doc Package dllBuildDir
    Get the output `Directory` for dynamic library this package represents.*/
    dllBuildDir := method(self buildDir createSubdirectory("dll"))

    /*doc Package staticLibBuildDir
    Get the output `Directory` for static library this package represents.*/
    staticLibBuildDir := method(self buildDir createSubdirectory("lib"))

    /*doc Package dllFileName 
    Get the file name of the dynamic library provided by this package in the
    result of compilation with `lib` prefix.*/
    dllFileName := method("lib" .. self dllName .. "." .. Eerie dllExt)

    /*doc Package dllName 
    Get the name of the dynamic library provided by this package in the result
    of compilation. Note, this is the name of the library, not the name of the
    dll file (i.e. without extension and `lib` prefix). Use `Package
    dllFileName` for the DLL file name.*/
    dllName := method("Io" .. self name)

    /*doc Package staticLibFileName 
    Get the file name of the static library provided by this package in the
    result of compilation.*/
    staticLibFileName := method("lib" .. self staticLibName .. ".a")

    /*doc Package staticLibName 
    Get the name of the static library provided by this package in the result of
    compilation. Note, this is the name of the library, not the name of the dll
    file (i.e. the extension and without `lib` prefix). Use `Package
    staticLibFileName` for the static library file name.*/
    staticLibName := method("Io" .. self name)

    /*doc Package dllPath
    Get the path to the dynamic library this package represents.*/
    dllPath := method(self dllBuildDir path .. "/" .. self dllFileName)

    /*doc Package staticLibPath
    Get the path to the static library this package represents.*/
    staticLibPath := method(
        self staticLibBuildDir path .. "/" .. self staticLibFileName)

    //doc Package buildio The `build.io` file.
    buildio := lazySlot(self dir fileNamed("build.io"))

    /*doc Package packages 
    Get the `List` of installed dependencies for this package.*/
    packages := lazySlot(self addonsDir directories map(dir, Package with(dir)))

    //doc Package version Returns parsed version (`SemVer`) of the package.
    version ::= nil
    
    //doc Package name
    name := method(self config at("name"))

    //doc Package setName(name)
    setName := method(v,
        self config atPut("name", v)
        self)

    //doc Package downloader Instance of [[Downloader]] for this package.
    downloader ::= nil

    /*doc Package uri 
    Either local path or git url. Parsed from `path` field of `eerie.json`.*/
    uri := method(
        dir := self config at("path") at("dir")
        if (dir isNil not, 
            dir,
            self config at("path") at("git") at("url")))

    /*doc Package with(dir) 
    Creates new package from provided `Directory`. Raises `NotPackageError` if
    the directory is not an Eerie package. Use this to initialize a `Package`.*/
    with := method(dir,
        _checkDirectoryPackage(dir)

        klone := self clone setDir(dir)
        manifest := File with(
            dir path .. "/#{Package manifestName}" interpolate) 
        klone setConfig(manifest contents parseJson)
        klone setVersion(SemVer fromSeq(klone config at("version")))
        # call to init the list
        klone packages
        klone)

    _checkDirectoryPackage := method(dir,
        ioDir := dir directoryNamed("io")
        manifest := File with(
            dir path .. "/#{Package manifestName}" interpolate)
        if ((dir exists and manifest exists and ioDir exists) not,
            Exception raise(NotPackageError with(dir path)))

        ManifestValidator with(manifest) validate)

    /*doc Package global 
    Initializes the global Eerie package (i.e. the Eerie itself).*/
    global := method(Package with(Directory with(Eerie root)))

    /*doc Package appendPackage 
    Add a `Package` to the list of installed packages.*/
    appendPackage := method(package, self packages appendIfAbsent(package))

    /*doc Package packageNamed 
    Get the dependency package with the provided name (`Sequence`) if it's
    installed. Otherwise it returns `nil`.*/ 
    packageNamed := method(name, self packages detect(pkg, pkg name == name))

    /*doc Eerie updatePackage(Package) 
    Replaces package with the given name with the given package.

    Return `true` if package was found and replaced and `false` otherwise.*/
    updatePackage := method(package,
        old := self packageNamed(package name)
        old isNil ifTrue(
            msg := "Tried to update package which is not yet installed."
            msg = msg .. " (#{package name})"
            Eerie log(msg, "debug")
            return false)

        self packages remove(old) append(package)
        true)

    //doc Package removePackage(`Package`) Removes the given package.
    removePackage := method(package, self packages remove(package))

    /*doc Package hasNativeCode 
    Returns `true` if the package has native code and `false` otherwise.*/
    hasNativeCode := method(
        self sourceDir files isEmpty not or(self sourceDir directories isEmpty
            not))

    /*doc Package hasBinaries
    Returns `true` if the `Package binDir` has files and `false` otherwise.*/
    hasBinaries := method(self binDir exists and self binDir files isEmpty not)

    //doc Package providesProtos Returns list of protos this package provides.
    providesProtos := method(
        p := self config at("protos")
        if(p isNil, list(), p))

    /*doc Package dependencies([category])
    Returns list of dependencies this package has. <code>category</code> can be 
    <code>protos</code>, <code>packages</code>, <code>headers</code> or 
    <code>libs</code>.*/
    dependencies := method(category,
        d := self config at("dependencies")
        if(category and d and d isEmpty not, d = d at(category))
        if(d isNil, list(), d))

    /*doc Package runHook(hookName) 
    Runs Io script with hookName in package's `hooks` directory if it exists.*/
    runHook := method(hook,
        f := File with("#{self dir}/hooks/#{hook}.io" interpolate)
        f exists ifTrue(
            Eerie log("Launching #{hook} hook for #{self name}", "debug")
            ctx := Object clone
            e := try(ctx doFile(f path))
            e catch(
                Eerie log("#{hook} failed.", "error")
                Eerie log(e message, "debug"))
            f close))

)

# Error types
Package do (

    //doc Package NotPackageError
    NotPackageError := Eerie Error clone setErrorMsg(
        "The directory '#{call evalArgAt(0)}' is not recognised as an Eerie "..
        "package.")

)

Package do (
    
    ManifestValidator := Object clone do (

        _manifest := nil

        _config := nil
        
        Map squareBrackets := method(key, self at(key))
    

        //doc ManifestValidator InsufficientManifestError
        InsufficientManifestError := Eerie Error clone setErrorMsg(
            "The manifest at '#{call evalArgAt(0)}' doesn't satisfy " ..
            "all requirements." .. 
            "#{if(call evalArgAt(1) isNil, " ..
                "\"\", \"\\n\" .. call evalArgAt(1))}")

    )

)

Package ManifestValidator with := method(manifest,
    klone := self clone
    klone _manifest := manifest
    klone _config := manifest contents parseJson
    klone)

Package ManifestValidator validate := method(
        parsed := self _config

        self _checkRequired("name")
        self _checkRequired("version")
        self _checkRequired("author")
        self _checkRequired("path")
        self _checkEither("path.dir", "path.git")

        if (self _config at("path") at("git") isNil not,
            self _checkRequired(
                "path.git.url", 
                """"path.git.url" is required for "path.git"."""))


        self _checkField(self _config at("protos") isNil,
            "The \"protos\" field is required.")

        self _checkField(self _config at("protos") type != List type,
            "The \"protos\" field should be an array.")

        deps := self _config at("dependencies")

        self _checkField(deps type != Map type, 
            "The \"dependencies\" field should be an object.")

        if (deps ?at("packages") isNil not and deps ?at("packages") isEmpty not,

            test := deps at("packages") type != List type
            self _checkField(test,
                "The 'dependencies.packages' field should be an array.")

            deps at("packages") ?foreach(p,
                test = p at("name") isNil
                test = test or p at("name") isEmpty
                self _checkField(test,
                    "The 'dependencies.packages[n].name' is required.")

                test = test or p at("version") isNil
                self _checkField(test,
                    "The 'dependencies.packages[n].version' is required.")

                test = test or p at("path") isNil
                test = test or p at("path") isEmpty
                self _checkField(test,
                    "The 'dependencies.packages[n].path' is required.")))

)

# check's whether a field is not nil and not empty
# the `field` argument is key with subfields separated by dot:
# `foo.bar.baz`
# the optional `msg` argument is the message, which will be shown on invalid
# test
Package ManifestValidator _checkRequired := method(field, msg,
    value := self _valueForKey(field)
    msg := msg ifNilEval("The \"#{field}\" field is required." interpolate)

    if (value isNil or value isEmpty,
        Exception raise(
            InsufficientManifestError with(self _manifest path, msg))))

# get config value for key of type `foo.bar.baz`
Package ManifestValidator _valueForKey := method(key,
    split := key split(".")
    value := self _config
    split foreach(key, value = value at(key))
    value)

Package ManifestValidator _checkEither := method(first, second,
    valueA := self _valueForKey(first)
    valueB := self _valueForKey(second)
    msg := "Either \"#{first}\" or \"#{second}\" field is required." interpolate

    if ((valueA isNil or valueA isEmpty) and (valueB isNil or valueB isEmpty),
        Exception raise(
            InsufficientManifestError with(self _manifest path, msg))))

# the first argument is a boolean. If it's `true`,
# `InsufficientManifestError` will raise with the message at the second
# argument.
# The third argument is the manifest path.
Package ManifestValidator _checkField := method(test, msg,
    test ifTrue(
        Exception raise(
            InsufficientManifestError with(self _manifest path, msg))))


