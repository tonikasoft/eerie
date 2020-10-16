# This proto manages dependencies
DependencyManager := Object clone do (
    package := nil

    _headers := list()
    
    _headerSearchPaths := list(".")

    _searchPrefixes := list(
        System installPrefix,
        "/opt/local",
        "/usr",
        "/usr/local",
        "/usr/pkg",
        "/sw",
        "/usr/X11R6",
        "/mingw"
    )

    _libSearchPaths := list()

    _frameworkSearchPaths := list(
        "/System/Library/Frameworks",
        "/Library/Frameworks",
        "~/Library/Frameworks" stringByExpandingTilde
    )

    _libs := list()
    
    _frameworks := list()
    
    _syslibs := list()
    
    _linkOptions := list()

    _addons := list()

    init := method(
        self _searchPrefixes foreach(prefix,
            self appendHeaderSearchPath(prefix .. "/include"))

        self appendHeaderSearchPath(
            Path with(System installPrefix, "include", "io"))

        self _searchPrefixes foreach(prefix, 
            self appendLibSearchPath(prefix .. "/lib")))

    with := method(pkg, 
        klone := self clone
        klone package := pkg
        klone)

    appendHeaderSearchPath := method(path, 
        dir := self _dirForPath(path)
        if(dir exists, 
            self _headerSearchPaths appendIfAbsent(dir path)))

    appendLibSearchPath := method(path, 
        dir := self _dirForPath(path)
        if(dir exists,
            self _libSearchPaths appendIfAbsent(dir path)))

    # returns directory relative to package's directory if path relative and
    # just a directory if path is absolute
    _dirForPath := method(path,
        if (self _isPathAbsolute(path),
            Directory with(path),
            self package dir directoryNamed(path)))

    # whether the path is absolute
    _isPathAbsolute := method(path,
        if (Builder platform == "windows",
            path containsSeq(":\\") or path containsSeq(":/"),
            path beginsWithSeq("/")))

    dependsOnBinding := method(v, self _addons appendIfAbsent(v))

    dependsOnHeader := method(v, self _headers appendIfAbsent(v))

    dependsOnLib := method(v,
        self _libs contains(v) ifFalse(
            pkgLibs := self _pkgConfigLibs(v)
            if(pkgLibs isEmpty,
                self _libs appendIfAbsent(v),
                pkgLibs map(l, self _libs appendIfAbsent(l)))
            self _searchPrefixes appendIfAbsent(v)
            self _pkgConfigCFlags(v) select(containsSeq("/")) foreach(p,
                self appendHeaderSearchPath(p))))

    _pkgConfigLibs := method(pkg,
        self _pkgConfig(pkg, "--libs") splitNoEmpties(linkLibFlag) map(strip))

    _pkgConfigCFlags := method(pkg,
        self _pkgConfig(pkg, "--cflags") splitNoEmpties("-I") map(strip))

    _pkgConfig := method(pkg, flags,
        (Builder platform == "windows") ifTrue(return "")

        date := Date now asNumber asHex
        resFile := (self package dir path) .. "/_build/_pkg_config" .. date
        # System runCommand (Eerie sh) doesn't allow pipes (?), 
        # so here we use System system instead
        statusCode := System system(
            "pkg-config #{pkg} #{flags} --silence-errors > #{resFile}" \
                interpolate)

        if(statusCode == 0) then (
            resFile := File with(resFile) openForReading
            flags := resFile contents asMutable strip
            resFile close remove
            return flags
        ) else (
            return ""))

    dependsOnSysLib := method(v, self _syslibs appendIfAbsent(v))

    optionallyDependsOnLib := method(v, 
        a := self _pathForLib(v) != nil
        if(a, self dependsOnLib(v))
        a)

    _pathForLib := method(name,
        name containsSeq("/") ifTrue(return(name))
        libNames := list("." .. Builder _dllSuffix, ".a", ".lib") map(suffix, 
            "lib" .. name .. suffix)
        self _libSearchPaths detect(path,
            libDirectory := Directory with(path)
            libNames detect(libName, libDirectory fileNamed(libName) exists)))

    dependsOnFramework := method(v, self _frameworks appendIfAbsent(v))

    optionallyDependsOnFramework := method(v, 
        a := self _pathForFramework(v) != nil
        if(a, self dependsOnFramework(v))
        a)

    _pathForFramework := method(name,
        frameworkname := name .. ".framework"
        self _frameworkSearchPaths detect(path,
            Directory with(path .. "/" .. frameworkname) exists))

    dependsOnFrameworkOrLib := method(v, w,
        path := self _pathForFramework(v)
        if(path != nil) then (
            self dependsOnFramework(v)
            self appendHeaderSearchPath(path .. "/" .. v .. ".framework/Headers")
        ) else (
            self dependsOnLib(w)))

    dependsOnLinkOption := method(v, 
        self _linkOptions appendIfAbsent(v))

    # actually this will never be raise an exception, because we check the
    # existence of a path when we use append methods
    checkMissing := method(
        missing := self _missingHeaders
        if (missing isEmpty not,
            Exception raise(MissingHeadersError with(missing)))

        missing := self _missingLibs
        if (missing isEmpty not,
            Exception raise(MissingLibsError with(missing)))

        missing := self _missingFrameworks
        if (missing isEmpty not,
            Exception raise(MissingFrameworksError with(missing))))

    _missingHeaders := method(
        self _headers select(h, self _pathForHeader(p) isNil))

    _pathForHeader := method(name,
        self _headerSearchPaths detect(path,
            File with(path .. "/" .. name) exists))

    _missingLibs := method(self _libs select(p, self _pathForLib(p) isNil))

    _missingFrameworks := method(
        self _frameworks select(p, self _pathForFramework(p) isNil))
)

# error types
DependencyManager do (
    MissingHeadersError := Eerie Error clone setErrorMsg(
        """Header(s) #{call evalArgAt(0) join(", ")} not found.""")

    MissingLibsError := Eerie Error clone setErrorMsg(
        """Library(s) #{call evalArgAt(0) join(", ")} not found.""")

    MissingFrameworksError := Eerie Error clone setErrorMsg(
        """Framework(s) #{call evalArgAt(0) join(", ")} not found.""")
)