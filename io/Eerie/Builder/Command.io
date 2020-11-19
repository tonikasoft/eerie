# This module contains commands for compiler, static linker and dynamic linker

Command := Object clone do (

    asSeq := method(nil)

)


Command CompilerCommandWinExt := Object clone do (

    _cc := method(System getEnvironmentVariable("CC") ifNilEval("cl -nologo"))

    _ccOutFlag := "-Fo"

)

Command CompilerCommandUnixExt := Object clone do (
    
    _cc := method(System getEnvironmentVariable("CC") ifNilEval("cc"))
    
    _ccOutFlag := "-o "

)

CompilerCommand := Command clone do (

    if (Eerie platform == "windows", 
        prependProto(CompilerCommandWinExt),
        prependProto(CompilerCommandUnixExt)) 

    package := nil

    # the file this command should compile
    src ::= nil

    _depsManager := nil

    _defines := lazySlot(
        name := self package struct manifest name asUppercase
        build := "BUILDING_#{name}_Pack" interpolate 
        
        result := if(Eerie platform == "windows",
            list(
                "WIN32",
                "NDEBUG", 
                "IOBINDINGS", 
                "_CRT_SECURE_NO_DEPRECATE"),
            list("SANE_POPEN",
                "IOBINDINGS"))

        if (list("cygwin", "mingw") contains(Eerie platform),
            result append(build))

        result)

    with := method(pkg, depsManager,
        klone := self clone
        klone package = pkg
        klone _depsManager = depsManager
        klone)

    addDefine := method(def, self _defines appendIfAbsent(def))

    asSeq := method(
        if (self src isNil, Exception raise(SrcNotSetError with("")))

        objName := self src name replaceSeq(".cpp", ".o") \
            replaceSeq(".c", ".o") \
                replaceSeq(".m", ".o")

        ("#{self _cc} #{self _options} #{self _cFlags} " ..
            "#{self _definesFlags} #{self _includesFlags} " ..
            "-c #{self _ccOutFlag}" ..
            "#{self package struct build objs path}/#{objName} " ..
            "#{self package struct source path}/#{self src name}") interpolate)

    _options := lazySlot(
       if(Eerie platform == "windows",
            "-MD -Zi",
            "-Os -g -Wall -pipe -fno-strict-aliasing -fPIC"))

    _cFlags := method(System getEnvironmentVariable("CFLAGS") ifNilEval(""))

    _definesFlags := method(self _defines map(d, "-D" .. d) join(" "))

    _includesFlags := method(
        self _depsManager headerSearchPaths map(v, "-I" .. v) join(" "))

)

# CompilerCommand error types
CompilerCommand do (

    SrcNotSetError := Eerie Error clone setErrorMsg(
        "Source file to compile doesn't set.")

)

Command StaticLinkerCommandWinExt := Object clone do (

    _ar := "link -lib -nologo"

    _arFlags := "-out:"

    _ranlib := nil

)

Command StaticLinkerCommandUnixExt := Object clone do (

    _ar := method(
        System getEnvironmentVariable("AR") ifNilEval("ar"))

    _arFlags := "rc "

    _ranlib := method(
        System getEnvironmentVariable("RANLIB") ifNilEval("ranlib"))

)

StaticLinkerCommand := Command clone do (

    if (Eerie platform == "windows",
        prependProto(StaticLinkerCommandWinExt),
        prependProto(StaticLinkerCommandUnixExt)) 
    
    package := nil

    with := method(pkg,
        klone := self clone
        klone package = pkg
        klone)

    asSeq := method(
        path := self package struct root path
        result := ("#{self _ar} #{self _arFlags}" ..
            "#{self package struct staticLibPath} " ..
            "#{self package struct build objs path}/*.o") interpolate

        if (self _ranlibSeq isEmpty, return result)
        
        result .. " && " .. self _ranlibSeq)

    _ranlibSeq := method(
        if (self _ranlib isNil, return "") 

        path := self package struct root path
        "#{self _ranlib} #{self package struct staticLibPath}" interpolate)

)

Command DynamicLinkerCommandWinExt := Object clone do (

    _linkerCmd := "link -link -nologo"

    _dirPathFlag := "-libpath:"

    libFlag := ""

    _libSuffix := ".lib"

    _outFlag := "-out:"

    # TODO debug?
    _otherFlags := "-dll -debug"

)

Command DynamicLinkerCommandUnixExt := Object clone do (

    _linkerCmd := method(
        System getEnvironmentVariable("CC") ifNilEval("cc"))

    _dirPathFlag := "-L"

    libFlag := "-l"

    _libSuffix := ""

    _outFlag := "-o "

    _otherFlags := "-shared -undefined dynamic_lookup"

)

Command DynamicLinkerCommandMacOsExt := Command DynamicLinkerCommandUnixExt \
    clone do (

    _otherFlags := method(
        installName := "-install_name " .. self package struct dllPath
        "-dynamiclib -single_module -undefined dynamic_lookup #{installName}" \
            interpolate) 

)

DynamicLinkerCommand := Command clone do (

    if (Eerie platform == "darwin") then (
        prependProto(DynamicLinkerCommandMacOsExt)
    ) elseif (Eerie platform == "windows") then (
        prependProto(DynamicLinkerCommandWinExt)
    ) else (
        prependProto(DynamicLinkerCommandUnixExt)) 

    package := nil

    _depsManager := nil

    # this is for windows only
    manifestPath := method(self package struct dllPath .. ".manifest")

    with := method(pkg, depsManager,
        klone := self clone
        klone package = pkg
        klone _depsManager := depsManager
        klone)

    asSeq := method(
        links := self _linksSeq

        cflags := System getEnvironmentVariable("CFLAGS") ifNilEval("")
        result := ("#{self _linkerCmd} #{cflags} " .. 
            "#{self _otherFlags} " ..
            "#{self package struct build objs path}/*.o " ..
            "#{links} " ..
            "#{self _outFlag}#{self package struct dllPath} ") interpolate

        result .. " && " .. self _embedManifestCmd)

    # generates a `Sequence` with all needed -L and -l flags
    _linksSeq := method(
        packages := self package children select(struct hasNativeCode)
        links := packages map(pkg,
                    ("#{self _dirPathFlag}" ..
                        "#{pkg struct build dll path}") interpolate)

        links appendSeq(packages map(pkg,
            ("#{self libFlag}" ..
                "#{self _nameWithLibSuffix(pkg struct dllName)}") interpolate))

        if(Eerie platform == "windows",
            links appendSeq(self _depsManager _syslibs map(v, v .. ".lib")))

        links appendSeq(
            self _depsManager libSearchPaths map(v, 
                self _dirPathFlag .. v))

        links appendSeq(self _depsManager _libs map(v,
            if(v at(0) asCharacter == "-", 
                v,
                self libFlag .. self _nameWithLibSuffix(v))))

        links appendSeq(
            self _depsManager _frameworks map(v, "-framework " .. v))

        links appendSeq(self _depsManager _linkOptions)

        if (Eerie platform == "darwin", links append("-flat_namespace"))

        links join(" "))

    # get name of the library with lib suffix depending on platform
    _nameWithLibSuffix := method(name, name .. self _libSuffix)

    _embedManifestCmd := method(
        if((Eerie platform == "windows") not, return "")

        "mt.exe -manifest " .. self manifestPath ..
        " -outputresource:" .. self package struct dllPath)

)
