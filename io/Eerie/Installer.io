//metadoc Installer category API
/*metadoc Installer description 
This object is used to install and build packages. Use `Installer
with(package)` to initialize it. You should `setDestination` right after
initialization, otherwise it will raise an exception when you'll try to install
a package. You should also `setDestBinName` if you to install binaries from the
`Package`.*/

Installer := Object clone do (
    _compileFlags := if(System platform split first asLowercase == "windows",
        "-MD -Zi -DWIN32 -DNDEBUG -DIOBINDINGS -D_CRT_SECURE_NO_DEPRECATE",
        "-Os -g -Wall -pipe -fno-strict-aliasing -DSANE_POPEN -DIOBINDINGS")

    /*doc Installer destination The root `Directory` where `Package` will
    be installed.*/
    destination ::= nil

    /*doc Installer destBinName The name of the directory, where binaries
    (if any) will be installed.*/
    destBinName ::= nil

    //doc Installer package `Package` which the `Installer` will install.
    package ::= nil

    //doc Installer with(package) Initializes installer with the given package.
    with := method(pkg, self clone setPackage(pkg))

    /*doc Installer install(installBin)
    Installs `Installer package` into `Installer destination`/`package name`. If
    `installBin` is `true`, the binaries from the package's `bin` directory will
    also be installed. 

    Returns `true` if the package installed successfully.*/
    install := method(includeBin,
        self _checkPackageSet
        self _checkDestinationSet

        pkgDestination := self _packageDestination
        if (pkgDestination exists, 
            Exception raise(DirectoryExistsError with(
                self package name, pkgDestination path)))

        self build

        pkgDestination createIfAbsent

        Directory cp(self package dir, pkgDestination)

        if(includeBin, self _installBinaries)

        true)

    _checkPackageSet := method(
        if (self package isNil,
            Exception raise(PackageNotSetError clone)))

    _checkDestinationSet := method(
        if (self destination isNil, 
            Exception raise(DestinationNotSetError clone)))

    # this is the directory inside `destination` which represents the package
    # and contains its sources
    _packageDestination := method(
        self destination directoryNamed(self package name))

    /*doc Installer build(Package) Compiles the `Package` if it has
    native code. Returns `true` if the package was compiled and `false`
    otherwise. Note, the return value doesn't mean whether the compilation was
    successful or not, it's just about whether it's went through the compilation
    process.

    To customize compilation you can modify `build.io` file at the root of your
    package. This file is evaluated in the context of `Builder` so you can treat
    it as an ancestor of `Builder`. If you want to link a library `foobar`, for
    example, your `build.io` file would look like:

    ```Io
    dependsOnLib("foobar")
    ```

    Look `Builder`'s documentation for more methods you can use in `build.io`.
    */
    build := method(
        self _checkPackageSet

        if(self package hasNativeCode not, return false)

        self package buildio create

        # keep currentWorkingDirectory to return later
        wd := Directory currentWorkingDirectory
        Directory setCurrentWorkingDirectory(self package dir path)

        Eerie log("Compiling #{self package name}")

        builder := Builder with(self package)
        builder doFile("build.io")
        builder folder := Directory at(".")
        builder build(self _compileFlags)

        # change directory back
        Directory setCurrentWorkingDirectory(wd)

        true)

    # For global packages, creates symlinks (UNIX-like) or .cmd files (Windows)
    # for files of the package's `bin` directory in destination's `destBinName`
    # directory.
    # This method is called only after the package is copied to destination
    # folder. It works in the package's destination folder.
    _installBinaries := method(
        self _checkPackageSet
        self _checkDestBinNameSet
        if (self package hasBinaries not, return)

        isWindows := System platform containsAnyCaseSeq("windows") or(
            System platform containsAnyCaseSeq("mingw"))

        binDest := self _binInstallDir
        # this is directory at destination - i.e. where binaries copied to
        binDir := self _packageDestination directoryNamed(
            self package binDir name)
        binDir files foreach(f, if(isWindows, 
            self _createCmdForBin(f, binDest),
            self _createLinkForBin(f, binDest))))

    _checkDestBinNameSet := method(
        if (self destBinName isNil or self destBinName isEmpty,
            Exception raise(DestinationBinNameNotSetError clone)))

    # binaries will be installed in this directory
    _binInstallDir := method(
        self destination directoryNamed(self package name) \
            directoryNamed(self binDestName))

    # This method is used on Windows to create .cmd file to be able to execute a
    # package binary as a normal command (i.e. `eerie` instead of
    # `io /path/to/eerie/bin`)
    _createCmdForBin := method(bin, binDest,
        cmd := binDest fileNamed(bin name .. ".cmd")
        cmd open setContents("io #{bin path} %*" interpolate) close)

    # We just create a link for binary on unix-like system
    _createLinkForBin := method(bin, binDest,
        # make sure it's executable
        Eerie sh("chmod u+x #{bin path}" interpolate)
        # create the link
        link := binDest fileNamed(bin name)
        link exists ifFalse(SystemCommand lnFile(bin path, link path))
        link close)
)

# Errors
Installer do (
    //doc Installer PackageNotSetError
    PackageNotSetError := Eerie Error clone setErrorMsg("Package didn't set.")

    //doc Installer DirectoryExistsError
    DirectoryExistsError := Eerie Error clone setErrorMsg("Can't install " ..
        "the package #{call evalArgAt(0)}. The destination directory " ..
        "'#{call evalArgAt(1)}' already exists.")

    //doc Installer DestinationNotSetError
    DestinationNotSetError := Eerie Error clone setErrorMsg(
        "Package installer destination directory didn't set.")

    //doc Installer DestinationBinNameNotSetError
    DestinationBinNameNotSetError := Eerie Error clone setErrorMsg(
        "Name of the destination directory where binaries will be installed " ..
        "didn't set.")
)

//doc Directory cp Copy the content of source `Directory` to a `Destination`.
Directory cp := method(source, destination,
    destination createIfAbsent
    absoluteDest := Path absolute(destination path)

    # keep path to the current directory to return when we're done
    wd := Directory currentWorkingDirectory
    # change directory, to copy only what's inside the source
    Directory setCurrentWorkingDirectory(source path)


    Directory at(".") walk(item,
        newPath := absoluteDest .. "/" .. item path
        if (item type == File type) then (
            Directory with(newPath pathComponent) createIfAbsent 
            # `File copyToPath` has rights issues, `File setPath` too, so we
            # just create a new file here and copy the content of the source
            # into it
            File with(newPath) create setContents(item contents) close
        ) else (
            Directory createIfAbsent(newPath)))

    Directory setCurrentWorkingDirectory(wd))
