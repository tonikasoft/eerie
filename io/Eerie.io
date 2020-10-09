//metadoc Eerie category API
//metadoc Eerie author Josip Lisec
//metadoc Eerie description Eerie is the package manager for Io.
SystemCommand

System userInterruptHandler := method(Eerie Transaction releaseLock)

Eerie := Object clone do(
    //doc Eerie manifestName The name of the manifest file.
    manifestName := "eerie.json"
    //doc Eerie globalEerieDir Returns value of EERIEDIR environment variable.
    globalEerieDir := method(
        System getEnvironmentVariable("EERIEDIR"))
    //doc Eerie tmpDir Get path to temp directory.
    tmpDir ::= globalEerieDir .. "/_tmp"
    /*doc Eerie root Current working directory or value of `EERIEDIR` system's 
    environment variable if `isGlobal` is `true`.*/
    root := method(if (self isGlobal, globalEerieDir, "."))
    //doc Eerie addonsDir Path to directory where addons are installed.
    addonsDir := method(Directory with("#{self root}/_addons" interpolate))
    //doc Eerie packages Returns list of installed packages .
    //doc Eerie isGlobal Whether the global environment in use.
    isGlobal := method(self _isGlobal)
    _isGlobal := false

    //doc Eerie setIsGlobal Set whether the global environment in use. 
    setIsGlobal := method(value, 
        self _isGlobal = value
        self _reloadPackagesList
        self)

    packages := method(
        # this way we do lazy loading. When the user asks `self packages` for
        # the first time, they will be fetched and type will change to List
        # instead of method, but we still be able to reload packages list using
        # `_reloadPackagesList` method.
        _reloadPackagesList)

    _reloadPackagesList := method(
        self packages = self addonsDir directories map(d, Package with(d)))

    init := method(
        if(globalEerieDir isNil or globalEerieDir isEmpty,
            Exception raise("Error: EERIEDIR is not set")))


    /*doc Eerie sh(cmd[, logFailure=true, dir=cwd])
    Executes system command. If `logFailure` is `true` and command exists with
    non-zero value, the application will abort.
    */
    sh := method(cmd, logFailure, dir,
        self log(cmd, "console")
        prevDir := nil
        dirPrefix := ""
        if(dir != nil and dir != ".",
            dirPrefix = "cd " .. dir .. " && "
            prevDir = Directory currentWorkingDirectory
            Directory setCurrentWorkingDirectory(dir))

        cmdOut := System runCommand(dirPrefix .. cmd)
        stdOut := cmdOut stdout
        stdErr := cmdOut stderr

        prevDir isNil ifFalse(Directory setCurrentWorkingDirectory(prevDir))

        # System runCommand leaves weird files behind
        SystemCommand rmFilesContaining("-stdout")
        SystemCommand rmFilesContaining("-stderr")
        
        if(cmdOut exitStatus != 0 and logFailure == true) \
        then (
            self log("Last command exited with the following error:", "error")
            self log(stdOut, "error")
            self log(stdErr, "error")
            System exit(cmdOut exitStatus)
        ) else (
            return cmdOut exitStatus))

    _logMods := Map with(
        "info",         " - ",
        "error",        " ! ",
        "console",      " > ",
        "debug",        " # ",
        "install",      " + ",
        "transaction",  "-> ",
        "output",       "")

    /*doc Eerie log(message, mode) Displays the message to the user. Mode can be
    `"info"`, `"error"`, `"console"`, `"debug"` or `"output"`.*/
    log := method(str, mode,
        mode ifNil(mode = "info")
        ((self _logMods at(mode)) .. str) interpolate(call sender) println)

    /*doc Eerie generatePackagePath Return path for addon with the given name
    independently of its existence.*/
    generatePackagePath := method(name,
        self addonsDir path .. "/#{name}" interpolate)

    /*doc Eerie packageNamed(name) Returns package with provided name if it 
    exists, `nil` otherwise.*/
    packageNamed := method(pkgName,
        self packages detect(pkg, pkg name == pkgName))

    //doc Eerie appendPackage(package) Append a package to the packages list.
    appendPackage := method(package, self packages appendIfAbsent(package))

    //doc Eerie removePackage(package) Removes the given package.
    removePackage := method(package, self packages remove(package))

    //doc Eerie updatePackage(package)
    updatePackage := method(package,
        old := self packages detect(p, p name == package name)
        old isNil ifTrue(
            msg := "Tried to update package which is not yet installed."
            msg = msg .. " (#{package name})"
            Eerie log(msg, "debug")
            return false)

        self packages remove(old) append(package)
        true)

)

Eerie clone = Eerie do(
    //doc Eerie Exception [Exception](exception.html)
    doRelativeFile("Eerie/Error.io")
    //doc Eerie Package [Package](package.html)
    doRelativeFile("Eerie/Package.io")
    //doc Eerie PackageDownloader [PackageDownloader](packagedownloader.html)
    doRelativeFile("Eerie/PackageDownloader.io")
    //doc Eerie PackageInstaller [PackageInstaller](packageinstaller.html)
    doRelativeFile("Eerie/PackageInstaller.io")
    //doc Eerie Transaction [Transaction](transaction.html)
    doRelativeFile("Eerie/Transaction.io")
    //doc Eerie TransactionAction [TransactionAction](transactionaction.html)
    doRelativeFile("Eerie/TransactionAction.io")

    init
)
