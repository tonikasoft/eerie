Importer addSearchPath("io/Eerie/Builder/")
    
InitFileGeneratorTest := UnitTest clone do (

    testGenerate := method(
        package := Package with("tests/_packs/CFakePack")
        generator := InitFileGenerator with(package)
        generator generate
        
        result := package sourceDir fileNamed("IoCFakePackInit.c") 
        expected := if (Eerie isWindows, 
            knownBug("expected file on windows doesn't exist")
            package dir directoryNamed("tests") fileNamed("ExpectedInitWin.c"),
            package dir directoryNamed("tests") fileNamed("ExpectedInitUnix.c"))

        assertEquals(result contents, expected contents)

        result remove)
)
